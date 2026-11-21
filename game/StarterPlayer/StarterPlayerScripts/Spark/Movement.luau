-- Client-predicted dash (WP-03). The client starts the dash in the SAME frame as
-- the input and moves its own character with one persistent plane-mode
-- LinearVelocity that is enabled only while dashing; the server never moves the
-- character, it only budgets the burst (Rules.movement with dashPeak) and counts
-- charges. Also: bounce caps (mushroom ring launch) and wading speed.
--
-- Movement.newDash(tuning) is a pure state machine (fake-clock testable):
--   charges, recharge one at a time, 0.12 s input buffer, speedCurve sampling,
--   40 % steering, exit blend to walk speed.
local Movement = {}

local function lerp(a, b, t) return a + (b - a) * t end
-- Vector3 when running in Roblox; a plain {X, Y, Z} table in offline tests.
local function flat(x, z)
	if Vector3 then return Vector3.new(x, 0, z) end
	return {X = x, Y = 0, Z = z}
end

-- Integral of the speed curve (studs) for a duration-normalised curve.
function Movement.curveDistance(curve)
	local total = 0
	for i = 1, #curve - 1 do
		local a, b = curve[i], curve[i + 1]
		total += (b[1] - a[1]) * (a[2] + b[2]) / 2
	end
	return total
end

-- dash: {charges, recharge, duration, curve, buffer, steer, blend, walk, scale}
function Movement.newDash(dashTuning, walkSpeed, overrides)
	overrides = overrides or {}
	local curve = dashTuning.speedCurve
	local base = Movement.curveDistance(curve)
	local wantDistance = overrides.distance or dashTuning.distance
	return {
		maxCharges = overrides.charges or dashTuning.charges,
		charges = overrides.charges or dashTuning.charges,
		recharge = overrides.recharge or dashTuning.rechargeSeconds,
		duration = dashTuning.duration,
		curve = curve,
		buffer = dashTuning.inputBuffer,
		steer = dashTuning.steerFraction,
		blend = 0.10,
		walk = walkSpeed,
		-- F9 "dash distance" scales the curve; the shipped curve is the reference.
		scale = if wantDistance and base > 0 and overrides.distance then wantDistance / base else 1,
		rechargeAt = nil, startedAt = nil, bufferedAt = nil, direction = nil,
		dashes = 0,
	}
end

function Movement.refill(d, now)
	while d.charges < d.maxCharges and d.rechargeAt and now >= d.rechargeAt do
		d.charges += 1
		d.rechargeAt = if d.charges < d.maxCharges then d.rechargeAt + d.recharge else nil
	end
end

function Movement.dashing(d, now)
	return d.startedAt ~= nil and now < d.startedAt + d.duration + d.blend
end

-- The motion phase of a dash (excluding the exit blend): a new dash waits for it.
local function busy(d, now)
	return d.startedAt ~= nil and now < d.startedAt + d.duration
end

-- Seconds until the next charge (0 when one is ready).
function Movement.nextChargeIn(d, now)
	Movement.refill(d, now)
	if d.charges > 0 then return 0 end
	return math.max(0, (d.rechargeAt or now) - now)
end

local function start(d, now, direction)
	d.charges -= 1
	if d.rechargeAt == nil then d.rechargeAt = now + d.recharge end
	d.startedAt = now
	d.direction = direction
	d.bufferedAt = nil
	d.dashes += 1
	return true
end

-- Input. -> "start" | "buffered" | "empty". Never blocks: an early press is held
-- for `buffer` seconds and fires on the first update where a charge is ready.
function Movement.press(d, now, direction)
	Movement.refill(d, now)
	if d.charges > 0 and not busy(d, now) then
		start(d, now, direction)
		return "start"
	end
	d.bufferedAt = now
	d.bufferedDirection = direction
	return if d.charges > 0 or (d.rechargeAt and d.rechargeAt - now <= d.buffer) then "buffered" else "empty"
end

-- Per frame. -> "start" when a buffered press fires now, else nil.
function Movement.update(d, now)
	Movement.refill(d, now)
	if d.bufferedAt then
		if now - d.bufferedAt > d.buffer then
			d.bufferedAt = nil
		elseif d.charges > 0 and not busy(d, now) then
			start(d, now, d.bufferedDirection)
			return "start"
		end
	end
	return nil
end

-- Speed (studs/s) at time `now`; nil when not dashing. Exit blends to walk speed.
function Movement.speedAt(d, now)
	if not d.startedAt then return nil end
	local t = now - d.startedAt
	if t < 0 then return nil end
	local curve = d.curve
	if t <= d.duration then
		for i = 1, #curve - 1 do
			local a, b = curve[i], curve[i + 1]
			if t <= b[1] then
				local u = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 1
				return lerp(a[2], b[2], u) * d.scale
			end
		end
		return curve[#curve][2] * d.scale
	end
	if t <= d.duration + d.blend then
		return lerp(curve[#curve][2] * d.scale, d.walk, (t - d.duration) / d.blend)
	end
	return nil
end

-- Steering: the dash direction bends toward live input by `steer` (40 %).
function Movement.steerDirection(d, input)
	local dir = d.direction
	if not dir then return nil end
	if input and (input.X * input.X + input.Z * input.Z) > 0.01 then
		local x = dir.X * (1 - d.steer) + input.X * d.steer
		local z = dir.Z * (1 - d.steer) + input.Z * d.steer
		local m = math.sqrt(x * x + z * z)
		if m > 1e-4 then return flat(x / m, z / m) end
	end
	return dir
end

---------------------------------------------------------------- Roblox side
-- ctx: {player, tuning = Design.Tuning, camera = SparkCamera (optional),
--       onDash(started: boolean, result), sound(name, speed), reduced(), canDash(),
--       groundMap = function() -> map, GroundMap}
function Movement.new(ctx)
	local RunService = game:GetService("RunService")
	local Tuning = ctx.tuning
	local self = {dash = Movement.newDash(Tuning.dash, Tuning.movement.walkSpeed), overrides = {}}
	local velocity, attachment, root, humanoid
	local bounceParams, bounceList, bounceAt = nil, nil, 0
	local wading = false

	local function bind(character)
		root = character and character:WaitForChild("HumanoidRootPart", 10)
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root then return end
		attachment = Instance.new("Attachment")
		attachment.Name = "SparkDashAttachment"
		attachment.Parent = root
		velocity = Instance.new("LinearVelocity")
		velocity.Name = "SparkDashVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		velocity.ForceLimitsEnabled = true
		velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		velocity.MaxForce = math.max(1, root.AssemblyMass) * 4000
		velocity.Enabled = false
		velocity.Parent = root
	end
	ctx.player.CharacterAdded:Connect(bind)
	if ctx.player.Character then task.spawn(bind, ctx.player.Character) end

	local function inputDirection()
		local move = humanoid and humanoid.MoveDirection
		if move and move.Magnitude > 0.1 then return Vector3.new(move.X, 0, move.Z).Unit end
		return nil
	end

	local function apply(now)
		if not velocity or not root then return end
		local speed = Movement.speedAt(self.dash, now)
		if speed then
			local dir = Movement.steerDirection(self.dash, inputDirection()) or self.dash.direction
			self.dash.direction = dir
			velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
			velocity.Enabled = true
		elseif velocity.Enabled then
			velocity.Enabled = false
		end
	end

	-- Input frame: start and apply motion immediately (M7: same-frame response).
	function self.press()
		if ctx.canDash and not ctx.canDash() then return "blocked" end
		if not root then return "blocked" end
		local now = os.clock()
		local dir = inputDirection()
		if not dir then
			local look = root.CFrame.LookVector
			dir = Vector3.new(look.X, 0, look.Z)
			dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
		end
		local result = Movement.press(self.dash, now, dir)
		if result == "start" then
			apply(now)
			if ctx.onDash then ctx.onDash(true, self.dash) end
		elseif result == "empty" and ctx.onDash then
			ctx.onDash(false, self.dash)
		end
		return result
	end

	-- Retune from the F9 panel (Studio only, session only).
	function self.retune(overrides)
		for k, v in pairs(overrides) do self.overrides[k] = v end
		local charges, rechargeAt = self.dash.charges, self.dash.rechargeAt
		self.dash = Movement.newDash(Tuning.dash, self.overrides.walk or Tuning.movement.walkSpeed, self.overrides)
		self.dash.charges, self.dash.rechargeAt = math.min(charges, self.dash.maxCharges), rechargeAt
	end

	-- Bounce caps: landing on one launches the player bounceHeight studs up.
	local function bounce(now)
		if not root or now < bounceAt then return end
		if not bounceList then
			bounceList = {}
			local world = workspace:FindFirstChild("SparkWorld")
			if world then
				for _, item in ipairs(world:GetDescendants()) do
					if item:IsA("BasePart") and item:GetAttribute("BounceHeight") then table.insert(bounceList, item) end
				end
			end
			bounceParams = RaycastParams.new()
			bounceParams.FilterType = Enum.RaycastFilterType.Include
			bounceParams.FilterDescendantsInstances = bounceList
			if #bounceList == 0 then bounceAt = now + 2; bounceList = nil; return end
		end
		if root.AssemblyLinearVelocity.Y > 1 then return end
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.2, 0), bounceParams)
		if hit and hit.Instance then
			local height = hit.Instance:GetAttribute("BounceHeight") or 22
			local gravity = workspace.Gravity
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * gravity * height), v.Z)
			bounceAt = now + 0.4
			if ctx.sound then ctx.sound("bounce_cap") end
		end
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if Movement.update(self.dash, now) == "start" then
			if ctx.onDash then ctx.onDash(true, self.dash) end
		end
		apply(now)
		bounce(now)
		-- Wading: water slows walking to waterSpeedScale (GroundMap water factor).
		if humanoid and root and ctx.GroundMap and ctx.groundMap then
			local map = ctx.groundMap()
			local def = ctx.arenaDef and ctx.arenaDef()
			local inWater = def ~= nil and ctx.GroundMap.waterFactor(def, root.Position.X, root.Position.Z) > 0.6
			local walk = self.overrides.walk or Tuning.movement.walkSpeed
			local want = if inWater then walk * Tuning.movement.waterSpeedScale else walk
			if map and (inWater ~= wading or math.abs(humanoid.WalkSpeed - want) > 0.01) and humanoid.WalkSpeed <= walk + 0.01 then
				wading = inWater
				humanoid.WalkSpeed = want
			end
		end
	end)
	return self
end

return Movement
