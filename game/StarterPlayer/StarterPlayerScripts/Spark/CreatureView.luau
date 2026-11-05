-- Client-side creature presentation from server herd snapshots (~10 Hz).
-- The server owns every position, flag and catch. This module only renders:
-- it interpolates snapshot entries ~0.1 s behind the estimated server clock and
-- layers a family gait (hop / glide / roll / walk), turn banking, blinks and a
-- pooled startle "!" on top. Nothing here is authoritative.
--
-- The pure helpers (family, pose, interpolate, blinkAt, lodRadius, seedOf) never
-- touch Roblox globals, so tests/SparkCreatureView.spec.luau runs them in the
-- Luau CLI. Roblox globals are only read inside CreatureView.new (ctx.env can
-- substitute them for offline tests).
local CreatureView = {}

local PI = math.pi
local TAU = math.pi * 2

CreatureView.Delay = 0.1 -- render this far behind the estimated server clock (s)
CreatureView.MaxExtrapolate = 0.15 -- never run ahead of the newest snapshot by more (s)
CreatureView.MaxGap = 0.6 -- snapshots further apart than this snap instead of sliding (s)
CreatureView.GroundY = 2.2 -- server creature root height above the arena origin
CreatureView.FullRadius = 90 -- full pose within this camera distance (studs)
CreatureView.BlinkRadius = 40
CreatureView.FarInterval = 0.1 -- far / masked models: at most 10 PivotTo per second
CreatureView.DistantRadius = 250 -- beyond this (other arenas, fogged out) only 2 per second
CreatureView.DistantInterval = 0.5
CreatureView.BlendSeconds = 0.18 -- state changes cross-fade instead of popping
CreatureView.BangPool = 4
CreatureView.BangSeconds = 0.6
CreatureView.StaleSeconds = 3 -- forget model-less ids / last poses after this (s)
CreatureView.Flags = {fleeing = 1, dazed = 2, golden = 4, runner = 8, startled = 16, trial = 32}

local FLAG_FLEE, FLAG_DAZED, FLAG_RUNNER, FLAG_STARTLED = 1, 2, 8, 16

local FAMILY = {
	orb = "hopper", ears = "hopper", cube = "hopper",
	moth = "glider", fin = "glider", ribbon = "glider",
	shell = "roller", comet = "roller", star = "roller",
	prism = "walker", crown = "walker", antler = "walker",
}
local KNOWN_FAMILY = {hopper = true, glider = true, roller = true, walker = true}
local STARTLE_HEIGHT = {hopper = 1.2, glider = 0.9, roller = 0.7, walker = 0.8}
local BANK = {hopper = 0.05, glider = 0.14, roller = 0.08, walker = 0.06} -- lean per rad/s of turn

local function finite(n)
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end
local function num(v, default)
	return if finite(v) then v else default
end
-- Deterministic [0,1) hash; purely visual, so platform-exact sin is not required.
local function hash01(a, b)
	local s = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return s - math.floor(s)
end
local function wrapAngle(a) -- into [-pi, pi)
	return (a + PI) % TAU - PI
end
local function sinT(x)
	return math.sin(TAU * x)
end
local function hasFlag(flags, bit)
	return bit32.band(flags, bit) ~= 0
end

-- shape (Silhouette attribute) -> "hopper" | "glider" | "roller" | "walker".
-- Unknown shapes walk: the calmest gait never looks broken.
function CreatureView.family(shape)
	return FAMILY[shape] or "walker"
end

-- Stable numeric seed from a CreatureId (number or string).
function CreatureView.seedOf(id)
	if finite(id) then return id % 100003 end
	if type(id) == "string" then
		local h = 0
		for i = 1, math.min(#id, 32) do h = (h * 31 + string.byte(id, i)) % 100003 end
		return h
	end
	return 0
end

-- Full-pose camera radius for a quality level 1..10 (low quality trims it).
function CreatureView.lodRadius(quality)
	local q = clamp(math.floor(num(quality, 10)), 1, 10)
	return clamp(54 + q * 9, 63, CreatureView.FullRadius)
end

-- Pose for one frame. family: a family name (or a shape); t: gait clock in seconds
-- (for "startled", seconds since the startle began); speed: studs/s; state:
-- "idle" | "move" | "flee" | "dazed" | "startled"; reduced: reduced motion.
-- Returns {bob (studs, 0..1.4), squash (0.8..1.2, render as y offset / tilt
-- only), lean (side roll, + = right side down, |.|<=0.35), spin (yaw added to
-- heading; dazed 0..2pi, otherwise |.|<=0.5), pitch (+ = nose down, |.|<=0.35)}.
-- Deterministic for equal inputs. `out` (optional) is filled to avoid allocation.
function CreatureView.pose(family, t, speed, state, reduced, seed, out)
	out = out or {}
	family = FAMILY[family] or (if KNOWN_FAMILY[family] then family else "walker")
	t = num(t, 0)
	speed = math.max(0, num(speed, 0))
	local ph = hash01(num(seed, 0), 0.5)
	if reduced then
		out.bob, out.squash, out.lean, out.pitch = 0, 1, 0, 0
		out.spin = if state == "dazed" then ((t * 0.12 + ph) % 1) * TAU else 0
		return out
	end
	local m = clamp(speed / 16, 0, 1)
	local bob, squash, lean, pitch, spin = 0, 1, 0, 0, 0
	if state == "dazed" then
		-- Precessing dizzy wobble plus a slow in-place twirl.
		local w = t * 0.9 + ph
		bob = 0.06 + 0.05 * (0.5 + 0.5 * sinT(w * 2))
		squash = 0.95 + 0.03 * sinT(w * 2)
		lean = 0.18 * sinT(w)
		pitch = 0.12 * sinT(w + 0.25)
		spin = ((t * 0.35 + ph) % 1) * TAU
	elseif state == "startled" then
		-- Quick alarmed hops (first hop starts on the ground at t=0), reared back.
		local u = (t / 0.55) % 1
		local s = math.sin(PI * u)
		bob = STARTLE_HEIGHT[family] * s
		squash = 0.86 + 0.3 * s
		lean = 0.05 * sinT(t * 7)
		pitch = -0.12 - 0.06 * s
	else
		local flee = state == "flee"
		local e = if flee then math.min(1, m + 0.3) else m
		local amp = if flee then 1.2 else 1
		local surge = if flee then 0.06 else 0
		if family == "hopper" then
			-- Bouncy hops: squash on landing, stretch in the air, waddle per hop.
			local u = (t * 2.2 + ph) % 1
			local s = math.sin(PI * u)
			bob = (0.07 + 0.5 * e) * amp * s
			local k = 0.04 + 0.1 * e
			squash = 1 - k * (1 - s) ^ 3 + 0.6 * k * s
			lean = (0.03 + 0.05 * e) * sinT(t * 1.1 + ph)
			pitch = e * (0.1 + 0.07 * (1 - 2 * s)) + surge
		elseif family == "glider" then
			-- Floaty hover with a wingbeat pulse and lazy banking sway.
			local w = t * 0.9 + ph
			bob = 0.22 + (0.18 + 0.14 * e) * (0.5 + 0.5 * sinT(w))
			squash = 1 + (0.03 + 0.02 * e) * sinT(w * 2.5)
			lean = (0.08 + 0.1 * e) * amp * sinT(w * 0.5)
			pitch = 0.14 * e + 0.03 * sinT(w + 0.3) + surge
		elseif family == "roller" then
			-- Low skating bumps, forward rock with speed and a little yaw wiggle.
			local w = t * 3 + ph
			bob = 0.03 + (0.03 + 0.13 * e) * amp * math.abs(math.sin(PI * w))
			squash = 1 - (0.02 + 0.06 * e) * math.abs(math.cos(PI * w))
			lean = (0.03 + 0.05 * e) * sinT(t * 0.7 + ph)
			pitch = 0.2 * e + 0.04 * sinT(t * 0.8 + ph) + surge
			spin = (0.05 + 0.1 * e) * sinT(t * 0.9 + ph)
		else
			-- Stately two-step stride: bob per step, sway toward the planted foot.
			local u = (t * 1.8 + ph) % 1
			local s = math.abs(math.sin(TAU * u))
			bob = (0.03 + 0.17 * e) * amp * s
			squash = 1 - (0.01 + 0.05 * e) * (1 - s) + 0.015 * (1 - e) * sinT(t * 0.35 + ph)
			lean = (0.04 + 0.08 * e) * math.sin(TAU * u)
			pitch = 0.09 * e + surge
		end
		if state == "idle" then
			-- Idle creatures glance around: dwell forward, quick-ish looks aside.
			local g = sinT(t * 0.13 + ph)
			spin += 0.3 * (1 - m) * g * g * g
		end
	end
	out.bob = clamp(bob, 0, 1.4)
	out.squash = clamp(squash, 0.8, 1.2)
	out.lean = clamp(lean, -0.35, 0.35)
	out.pitch = clamp(pitch, -0.35, 0.35)
	out.spin = if state == "dazed" then clamp(spin, 0, TAU) else clamp(spin, -0.5, 0.5)
	return out
end

-- Snapshot entries {id, x, z, heading, flags}. alpha 0 = a, 1 = b; alpha is
-- clamped to [0, 4]; above 1 positions extrapolate linearly while heading may
-- turn at most 0.5 rad past b. Heading takes the shortest arc. id/flags from b.
function CreatureView.interpolate(a, b, alpha, out)
	out = out or {}
	alpha = if finite(alpha) then clamp(alpha, 0, 4) else 1
	local ax, az = num(a.x, 0), num(a.z, 0)
	local bx, bz = num(b.x, ax), num(b.z, az)
	local ah = num(a.heading, 0)
	local bh = num(b.heading, ah)
	local d = wrapAngle(bh - ah)
	out.id = b.id
	out.x = ax + (bx - ax) * alpha
	out.z = az + (bz - az) * alpha
	out.heading = wrapAngle(if alpha <= 1 then ah + d * alpha else bh + clamp(d * (alpha - 1), -0.5, 0.5))
	out.flags = b.flags
	return out
end

-- ~0.12 s blinks. Time is cut into 4-5 s cells (by seed); each cell holds one
-- blink starting 1-2 s in, so gaps land between ~3 and ~6 s; 15% of cells add a
-- quick double blink. Duty cycle is about 3%.
function CreatureView.blinkAt(seed, t)
	if not finite(t) then return false end
	seed = num(seed, 0)
	local cell = 4 + hash01(seed, 1.7)
	local shifted = t + hash01(seed, 3.1) * cell
	local k = math.floor(shifted / cell)
	local u = shifted - k * cell
	local key = seed + k * 0.618
	local start = 1 + hash01(key, 5.3)
	if u >= start and u < start + 0.12 then return true end
	if hash01(key, 9.7) > 0.85 then
		local second = start + 0.26
		return u >= second and u < second + 0.1
	end
	return false
end

-- ctx = {folder=Folder of creature Models, camera=fn()->Camera?, reducedMotion=fn()->bool,
--   quality=fn()->1..10, localUserId=number, guiParent=Instance? (PlayerGui recommended;
--   defaults to the camera), env=table? (offline test doubles for Roblox globals)}
function CreatureView.new(ctx)
	-- Calls stay spelled api.Instance.new / api.Enum.<Type>.<Item> so the API
	-- name checkers still validate them; ctx.env swaps in offline doubles.
	local api = ctx.env or {Vector3 = Vector3, CFrame = CFrame, Instance = Instance, UDim2 = UDim2, UDim = UDim,
		Color3 = Color3, Enum = Enum}
	local newVector3, lookAt, angles = api.Vector3.new, api.CFrame.lookAt, api.CFrame.Angles

	local self = {}
	local creatures = {} -- CreatureId -> record (snapshot slots + render state)
	local byModel = {} -- Model -> record
	local pending = {} -- Model without a CreatureId yet -> next retry time
	local ghostCf, ghostAt = {}, {} -- last rendered CFrame of recently removed ids
	local slots = {} -- startle "!" pool, at most BangPool entries
	local scratch, poseOut = {}, {}
	local offset = nil -- smoothed (local receive time - server clock)
	local lastNow = nil
	local destroyed = false
	local bangsCreated = 0

	local function slot(x, z, heading, flags, clock, at)
		return {x = x, z = z, heading = heading, flags = flags, clock = clock, at = at}
	end
	local function newRecord(id, now)
		return {
			id = id, seed = CreatureView.seedOf(id), ready = false,
			a = slot(0, 0, 0, 0, 0, 0), b = slot(0, 0, 0, 0, 0, 0),
			origin = nil, lastSeen = now, rawSpeed = 0, rawTurn = 0,
			model = nil, root = nil, body = nil, eyes = nil, family = "walker",
			speed = 0, turn = 0, gait = 0, state = nil, wasFull = false, reducedWas = false,
			pb = 0, ps = 1, pl = 0, psp = 0, pp = 0, fb = 0, fs = 1, fl = 0, fsp = 0, fp = 0,
			blendAt = -math.huge, nextFar = 0, maskAt = 0, masked = false, blinking = false,
			lastFlags = 0, startleAt = 0, cf = nil,
		}
	end

	local function maskPart(rec)
		return rec.body or rec.root
	end
	-- Masked = another player's private starter (Client.watchStarter sets LTM=1).
	local function isMasked(rec)
		local owner = rec.model:GetAttribute("StarterOwnerId")
		if owner ~= nil and owner ~= ctx.localUserId then return true end
		local part = maskPart(rec)
		return part ~= nil and part.LocalTransparencyModifier >= 0.99
	end
	local function setEyes(rec, on)
		-- Never write over the starter mask: re-check right before every write.
		local part = maskPart(rec)
		if part ~= nil and part.LocalTransparencyModifier >= 0.99 then
			rec.masked = true
			return
		end
		local value = if on then 1 else 0
		for _, eye in ipairs(rec.eyes) do
			if eye.Parent ~= nil then eye.LocalTransparencyModifier = value end
		end
		rec.blinking = on
	end

	local function hideSlot(entry)
		entry.rec = nil
		entry.gui.Enabled = false
		entry.gui.Adornee = nil
	end
	local function makeSlot(parent)
		local gui = api.Instance.new("BillboardGui")
		gui.Name = "CreatureStartle"
		gui.Size = api.UDim2.fromOffset(30, 30)
		gui.StudsOffset = newVector3(0, 3.4, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = CreatureView.FullRadius
		gui.ResetOnSpawn = false
		gui.Enabled = false
		local label = api.Instance.new("TextLabel")
		label.Name = "Bang"
		label.Size = api.UDim2.fromScale(1, 1)
		label.BackgroundColor3 = api.Color3.fromRGB(255, 219, 90)
		label.BackgroundTransparency = 0
		label.BorderSizePixel = 0
		label.Text = "!"
		label.TextScaled = true
		label.Font = api.Enum.Font.GothamBlack
		label.TextColor3 = api.Color3.fromRGB(28, 35, 66)
		label.Parent = gui
		local corner = api.Instance.new("UICorner")
		corner.CornerRadius = api.UDim.new(0.5, 0)
		corner.Parent = label
		gui.Parent = parent
		bangsCreated += 1
		return {gui = gui, rec = nil, start = 0}
	end
	local function showBang(rec, now)
		if rec.root == nil then return end
		local pick = nil
		for _, entry in ipairs(slots) do
			if entry.rec == rec then pick = entry; break end
		end
		if not pick then
			for _, entry in ipairs(slots) do
				if entry.rec == nil then pick = entry; break end
			end
		end
		local parent = ctx.guiParent or (ctx.camera and ctx.camera())
		if not pick and #slots < CreatureView.BangPool then
			if parent == nil then return end
			pick = makeSlot(parent)
			table.insert(slots, pick)
		end
		if not pick then
			pick = slots[1]
			for _, entry in ipairs(slots) do
				if entry.start < pick.start then pick = entry end
			end
		end
		-- A replaced camera destroys its children; rebuild that slot in place.
		if pick.gui.Parent == nil then
			if parent == nil then return end
			pcall(pick.gui.Destroy, pick.gui)
			local index = table.find(slots, pick)
			pick = makeSlot(parent)
			if index then slots[index] = pick end
		end
		pick.rec = rec
		pick.start = now
		pick.gui.Adornee = rec.root
		pick.gui.Size = api.UDim2.fromOffset(18, 18)
		pick.gui.StudsOffset = newVector3(0, 3.4, 0)
		pick.gui.Enabled = true
	end

	local function unbind(rec, now)
		local model = rec.model
		if model == nil then return end
		if rec.blinking and not rec.masked then setEyes(rec, false) end
		for _, entry in ipairs(slots) do
			if entry.rec == rec then hideSlot(entry) end
		end
		if rec.cf ~= nil then ghostCf[rec.id] = rec.cf; ghostAt[rec.id] = now end
		byModel[model] = nil
		rec.model, rec.root, rec.body, rec.eyes = nil, nil, nil, nil
		rec.blinking, rec.wasFull, rec.masked = false, false, false
		rec.lastSeen = math.max(rec.lastSeen, now)
	end
	local function bind(rec, model)
		local eyes = {}
		for _, item in ipairs(model:GetChildren()) do
			local name = item.Name
			if (name == "EyeWhite" or name == "Pupil" or name == "EyeGlint") and item:IsA("BasePart") then
				table.insert(eyes, item)
			end
		end
		rec.model = model
		rec.root = model.PrimaryPart or model:FindFirstChild("Root")
		rec.body = model:FindFirstChild("Body")
		rec.eyes = eyes
		rec.family = CreatureView.family(model:GetAttribute("Silhouette"))
		rec.wasFull, rec.blinking, rec.masked = false, false, false
		rec.nextFar, rec.maskAt = 0, 0
		byModel[model] = rec
	end

	-- snapshot = {arena, origin=Vector3, clock=server seconds, receivedAt=os.clock(),
	--   entries={{id, x, z, heading, flags}, ...}} (x/z arena-relative studs).
	function self.ingest(snapshot)
		if destroyed or type(snapshot) ~= "table" or type(snapshot.entries) ~= "table" then return end
		local origin = snapshot.origin
		if typeof(origin) ~= "Vector3" and type(origin) ~= "table" then return end
		local received = num(snapshot.receivedAt, lastNow or os.clock())
		local clock = snapshot.clock
		if finite(clock) then
			-- Lowest-latency samples win quickly; latency increases are adopted slowly.
			local sample = received - clock
			if offset == nil or math.abs(sample - offset) > 1 then
				offset = sample
			elseif sample < offset then
				offset += (sample - offset) * 0.5
			else
				offset += (sample - offset) * 0.05
			end
		else
			offset = offset or 0
			clock = received - offset
		end
		local entries = snapshot.entries
		for index = 1, math.min(#entries, 512) do
			local entry = entries[index]
			local id = if type(entry) == "table" then entry.id else nil
			if (finite(id) or type(id) == "string") and finite(entry.x) and finite(entry.z) then
				local rec = creatures[id]
				if not rec then
					rec = newRecord(id, received)
					creatures[id] = rec
				end
				local b = rec.b
				-- Ignore duplicates / out-of-order packets; a big backwards jump is a reset.
				if not rec.ready or clock > b.clock or clock < b.clock - 1 then
					local backwards = rec.ready and clock < b.clock
					rec.a, rec.b = b, rec.a
					local a = rec.a
					b = rec.b
					b.x, b.z = entry.x, entry.z
					b.heading = num(entry.heading, a.heading)
					b.flags = if finite(entry.flags) then clamp(math.floor(entry.flags), 0, 2 ^ 30) else 0
					b.clock, b.at = clock, received
					local span = clock - a.clock
					local dx, dz = b.x - a.x, b.z - a.z
					local distance = math.sqrt(dx * dx + dz * dz)
					if not rec.ready or backwards or rec.origin ~= origin or span > CreatureView.MaxGap
						or span <= 0 or distance > math.max(8, 60 * span) then
						-- First sighting, long gap, arena change or teleport: snap, don't slide.
						a.x, a.z, a.heading, a.flags, a.clock, a.at = b.x, b.z, b.heading, b.flags, b.clock, b.at
						rec.rawSpeed, rec.rawTurn = 0, 0
					else
						rec.rawSpeed = distance / span
						rec.rawTurn = wrapAngle(b.heading - a.heading) / span
					end
					rec.origin = origin
					rec.ready = true
				end
				rec.lastSeen = math.max(rec.lastSeen, received)
			end
		end
	end

	function self.track(model)
		if destroyed or model == nil or byModel[model] or pending[model] or not model:IsA("Model") then return end
		local id = model:GetAttribute("CreatureId")
		if id == nil then
			pending[model] = 0 -- retried from render until the attribute replicates
			return
		end
		local rec = creatures[id]
		if not rec then
			rec = newRecord(id, lastNow or 0) -- caller time base only (render/ingest)
			creatures[id] = rec
		end
		if rec.model ~= nil and rec.model ~= model then unbind(rec, lastNow or 0) end
		bind(rec, model)
	end

	function self.untrack(model)
		if model == nil then return end
		pending[model] = nil
		local rec = byModel[model]
		if rec then unbind(rec, lastNow or 0) end
	end

	-- CFrame last rendered for a CreatureId (or tracked Model); also briefly
	-- after the model is removed, so catch effects can start from what was seen.
	function self.lastPose(key)
		local rec = creatures[key] or byModel[key]
		if rec and rec.cf ~= nil then return rec.cf end
		return ghostCf[key]
	end

	local function renderOne(rec, now, dt, frame)
		local model = rec.model
		local a, b = rec.a, rec.b
		local span = b.clock - a.clock
		local renderClock = frame.renderClock
		local alpha, held = 1, false
		if span <= 1e-4 then
			held = true
		elseif renderClock >= b.clock then
			local over = renderClock - b.clock
			held = over > CreatureView.MaxExtrapolate or span < 0.05
			alpha = if span >= 0.05 then 1 + math.min(over, CreatureView.MaxExtrapolate) / span else 1
		else
			alpha = math.max(0, (renderClock - a.clock) / span)
		end
		local e = CreatureView.interpolate(a, b, alpha, scratch)
		local origin = rec.origin
		local px, pz = origin.X + e.x, origin.Z + e.z
		local baseY = origin.Y + CreatureView.GroundY
		local flags = e.flags
		local startled = hasFlag(flags, FLAG_STARTLED)
		local rising = startled and not hasFlag(rec.lastFlags, FLAG_STARTLED)
		rec.lastFlags = flags
		if rising then rec.startleAt = now end
		if now >= rec.maskAt then
			rec.maskAt = now + 0.25
			rec.masked = isMasked(rec)
		end
		local dx, dy, dz = px - frame.camX, baseY - frame.camY, pz - frame.camZ
		local d2 = dx * dx + dy * dy + dz * dz
		local reduced = frame.reduced

		if not frame.haveCamera or rec.masked or d2 > frame.fullR2 then
			-- Position-only, throttled. Masked starters still move, with no effects.
			if rec.blinking then setEyes(rec, false) end
			rec.wasFull = false
			if now < rec.nextFar then return end
			rec.nextFar = now + (if d2 > frame.distantR2 then CreatureView.DistantInterval else frame.farInterval)
			local pos = newVector3(px, baseY, pz)
			local cf = lookAt(pos, newVector3(px + math.cos(e.heading), baseY, pz + math.sin(e.heading)))
			model:PivotTo(cf)
			rec.cf = cf
			return
		end

		local targetSpeed = if held then 0 else rec.rawSpeed
		local targetTurn = if held then 0 else rec.rawTurn
		if not rec.wasFull then
			rec.speed, rec.turn = targetSpeed, targetTurn
		else
			local k = 1 - math.exp(-dt * 8)
			rec.speed += (targetSpeed - rec.speed) * k
			rec.turn += (targetTurn - rec.turn) * k
		end
		local state
		if hasFlag(flags, FLAG_DAZED) then
			state = "dazed"
		elseif startled then
			state = "startled"
		elseif hasFlag(flags, FLAG_FLEE) or hasFlag(flags, FLAG_RUNNER) then
			state = "flee"
		elseif rec.speed > 1 or (rec.state == "move" and rec.speed > 0.6) then
			state = "move" -- hysteresis keeps slow creatures from flickering
		else
			state = "idle"
		end
		if state ~= rec.state or not rec.wasFull or reduced ~= rec.reducedWas then
			if rec.wasFull then
				rec.fb, rec.fs, rec.fl, rec.fsp, rec.fp = rec.pb, rec.ps, rec.pl, rec.psp, rec.pp
			else
				rec.fb, rec.fs, rec.fl, rec.fsp, rec.fp = 0, 1, 0, 0, 0
			end
			rec.blendAt = now
			rec.state = state
			rec.reducedWas = reduced
		end
		rec.wasFull = true
		local m = clamp(rec.speed / 16, 0, 1)
		rec.gait += dt * (0.75 + 0.75 * m) * (if state == "flee" then 1.25 else 1)
		local p = CreatureView.pose(rec.family, if state == "startled" then now - rec.startleAt else rec.gait,
			rec.speed, state, reduced, rec.seed, poseOut)
		local bob, squash, lean, spin, pitch = p.bob, p.squash, p.lean, p.spin, p.pitch
		if not reduced then
			lean = clamp(lean + clamp(rec.turn * BANK[rec.family], -0.25, 0.25), -0.35, 0.35)
		end
		local since = now - rec.blendAt
		if since < CreatureView.BlendSeconds then
			local w = since / CreatureView.BlendSeconds
			w = w * w * (3 - 2 * w)
			bob = rec.fb + (bob - rec.fb) * w
			squash = rec.fs + (squash - rec.fs) * w
			lean = rec.fl + (lean - rec.fl) * w
			pitch = rec.fp + (pitch - rec.fp) * w
			spin = rec.fsp + wrapAngle(spin - rec.fsp) * w
		end
		rec.pb, rec.ps, rec.pl, rec.psp, rec.pp = bob, squash, lean, spin, pitch
		-- Squash never resizes parts: it sinks/lifts the body and dips the nose.
		local y = baseY + bob + (squash - 1) * 0.9
		local tilt = clamp(pitch + (1 - squash) * 0.6, -0.4, 0.4)
		local heading = e.heading + spin
		local pos = newVector3(px, y, pz)
		local cf = lookAt(pos, newVector3(px + math.cos(heading), y, pz + math.sin(heading)))
			* angles(-tilt, 0, -lean)
		model:PivotTo(cf)
		rec.cf = cf
		if d2 <= frame.blinkR2 then
			local want = CreatureView.blinkAt(rec.seed, now)
			if want ~= rec.blinking then setEyes(rec, want) end
		elseif rec.blinking then
			setEyes(rec, false)
		end
		if rising and not reduced then showBang(rec, now) end
	end

	local frame = {renderClock = 0, camX = 0, camY = 0, camZ = 0, haveCamera = false, reduced = false,
		fullR2 = 0, blinkR2 = 0, distantR2 = 0, farInterval = CreatureView.FarInterval}

	-- Call once per RenderStepped with now = os.clock(). One PivotTo per visible
	-- model per frame at most; no allocations beyond CFrame/Vector3 values.
	function self.render(now)
		if destroyed then return end
		now = num(now, os.clock())
		local dt = if lastNow then clamp(now - lastNow, 0, 0.25) else 0
		lastNow = now
		local quality = clamp(num(ctx.quality and ctx.quality(), 10), 1, 10)
		local fullR = CreatureView.lodRadius(quality)
		local blinkR = if quality >= 4 then CreatureView.BlinkRadius else CreatureView.BlinkRadius * 0.7
		local camera = ctx.camera and ctx.camera()
		frame.haveCamera = camera ~= nil
		if camera ~= nil then
			local position = camera.CFrame.Position
			frame.camX, frame.camY, frame.camZ = position.X, position.Y, position.Z
		end
		frame.reduced = ctx.reducedMotion ~= nil and ctx.reducedMotion() == true
		frame.renderClock = now - (offset or 0) - CreatureView.Delay
		frame.fullR2 = fullR * fullR
		frame.blinkR2 = blinkR * blinkR
		frame.distantR2 = CreatureView.DistantRadius * CreatureView.DistantRadius
		frame.farInterval = if quality >= 4 then CreatureView.FarInterval else 0.15

		for model, retryAt in pairs(pending) do
			if model.Parent == nil then
				pending[model] = nil
			elseif now >= retryAt then
				if model:GetAttribute("CreatureId") ~= nil then
					pending[model] = nil
					self.track(model)
				else
					pending[model] = now + 0.2
				end
			end
		end

		for id, rec in pairs(creatures) do
			local model = rec.model
			if model == nil then
				if now - rec.lastSeen > CreatureView.StaleSeconds then creatures[id] = nil end
			elseif model.Parent == nil or rec.root == nil or rec.root.Parent == nil then
				unbind(rec, now) -- destroyed mid-frame; ChildRemoved may not have run yet
			elseif rec.ready then
				renderOne(rec, now, dt, frame)
			end
		end

		for _, entry in ipairs(slots) do
			local rec = entry.rec
			if rec ~= nil then
				local age = now - entry.start
				if age >= CreatureView.BangSeconds or frame.reduced or rec.model == nil or rec.masked
					or rec.root == nil or rec.root.Parent == nil then
					hideSlot(entry)
				else
					local pop = math.min(1, age / 0.08)
					entry.gui.Size = api.UDim2.fromOffset(18 + 12 * pop, 18 + 12 * pop)
					entry.gui.StudsOffset = newVector3(0, 3.4 + 0.8 * age / CreatureView.BangSeconds, 0)
				end
			end
		end

		for id, at in pairs(ghostAt) do
			if now - at > CreatureView.StaleSeconds then ghostAt[id] = nil; ghostCf[id] = nil end
		end
	end

	-- Diagnostics for tests and perf checks (allocates; do not call per frame).
	function self.stats()
		local records, tracked, waiting, ghosts, active = 0, 0, 0, 0, 0
		for _, rec in pairs(creatures) do
			records += 1
			if rec.model ~= nil then tracked += 1 end
		end
		for _ in pairs(pending) do waiting += 1 end
		for _ in pairs(ghostAt) do ghosts += 1 end
		for _, entry in ipairs(slots) do
			if entry.rec ~= nil then active += 1 end
		end
		return {records = records, tracked = tracked, pending = waiting, ghosts = ghosts,
			bangs = #slots, bangsActive = active, bangsCreated = bangsCreated, offset = offset}
	end

	function self.destroy()
		if destroyed then return end
		local now = lastNow or 0
		for _, rec in pairs(creatures) do unbind(rec, now) end
		for _, entry in ipairs(slots) do pcall(entry.gui.Destroy, entry.gui) end
		destroyed = true
		table.clear(slots)
		table.clear(creatures)
		table.clear(byModel)
		table.clear(pending)
		table.clear(ghostCf)
		table.clear(ghostAt)
	end

	return self
end

return CreatureView
