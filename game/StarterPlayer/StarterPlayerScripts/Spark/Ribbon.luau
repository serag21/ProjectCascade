-- The ribbon (WP-03). Always on during a round, at foot level: a local Loop
-- ribbon fed every frame from the character root (ground level g from
-- GroundMap), drawn as ONE Trail on a ground-following host part, so jumps and
-- bounce caps never lift it. Closure is Loop.tryClose with the LIVE head every
-- frame. On closure the client starts the cinch (callback), sends the claim
-- (Loop.encode polygon, kind, viewClock) and waits up to resultTimeout for the
-- server result; no result = a harmless slip. The client never sends scores,
-- techniques, creature ids or ground levels.
local Ribbon = {}

Ribbon.RGB = {255, 236, 96}
Ribbon.PREVIEW_FACTOR = 2 -- snap preview appears inside twice the snap radius

-- Pure bookkeeping (testable): pending claims, rate limit, slip timeout.
function Ribbon.newClaims(T, ratePerSecond)
	return {pending = {}, sent = {}, rate = ratePerSecond or 3, timeout = T.resultTimeout or 0.8, serial = 0}
end

-- -> claim id, or nil when the claim rate (per rolling second) is exceeded.
function Ribbon.openClaim(c, now, poly, kind)
	local recent = 0
	for i = #c.sent, 1, -1 do
		if now - c.sent[i] < 1 then recent += 1 else table.remove(c.sent, i) end
	end
	if recent >= c.rate then return nil end
	c.serial += 1
	table.insert(c.sent, now)
	c.pending[c.serial] = {id = c.serial, at = now, poly = poly, kind = kind}
	return c.serial
end

-- Result for the oldest pending claim (the server answers in order).
function Ribbon.resolveClaim(c, id)
	local claim
	if id and c.pending[id] then
		claim = c.pending[id]
	else
		for _, p in pairs(c.pending) do if claim == nil or p.id < claim.id then claim = p end end
	end
	if claim then c.pending[claim.id] = nil end
	return claim
end

-- Claims older than the timeout slip (no catch, no penalty). -> list of slipped claims.
function Ribbon.expireClaims(c, now)
	local slipped = {}
	for id, p in pairs(c.pending) do
		if now - p.at >= c.timeout then table.insert(slipped, p); c.pending[id] = nil end
	end
	table.sort(slipped, function(a, b) return a.id < b.id end)
	return slipped
end

---------------------------------------------------------------- Roblox side
-- ctx: {player, Loop, T (Loop tuning), GroundMap, groundMap() -> map, origin() -> Vector3,
--       active() -> bool, viewClock() -> number, send(payload), onClose(poly, kind, claimId),
--       onSlip(claim), onPreview(near: boolean), fxFolder, camera (SparkCamera)}
function Ribbon.new(ctx)
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Loop, T = ctx.Loop, ctx.T
	local self = {ribbon = Loop.new(), claims = Ribbon.newClaims(T, ctx.rate), closures = 0}
	local COLOR = Color3.fromRGB(Ribbon.RGB[1], Ribbon.RGB[2], Ribbon.RGB[3])
	local folder = ctx.fxFolder

	-- Ground-following host: an invisible anchored part the Trail rides on.
	local host = Instance.new("Part")
	host.Name = "RibbonHost"
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false; host.CanQuery = false; host.CanTouch = false
	host.CastShadow = false
	host.Parent = folder
	local a0 = Instance.new("Attachment"); a0.Name = "RibbonLeft"; a0.Parent = host
	local a1 = Instance.new("Attachment"); a1.Name = "RibbonRight"; a1.Parent = host
	local width = (ctx.width or 1.2) / 2
	a0.Position = Vector3.new(-width, 0, 0); a1.Position = Vector3.new(width, 0, 0)
	local trail = Instance.new("Trail")
	trail.Name = "Ribbon"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.FaceCamera = false
	trail.Lifetime = T.lifetime
	trail.MaxLength = T.maxLength
	trail.MinLength = 0.2
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(COLOR)
	-- Length is readable: opaque head, the tail thins to 30 %.
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3)})
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.55)})
	if ctx.texture and ctx.texture ~= "" then
		trail.Texture = ctx.texture; trail.TextureMode = Enum.TextureMode.Wrap; trail.TextureLength = 8
	end
	trail.Enabled = false
	trail.Parent = host
	self.trail = trail

	-- Snap preview: a dashed Beam from the head to the snap point + a ring marker.
	local marker = Instance.new("Part")
	marker.Name = "SnapMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.1, 3, 3)
	marker.Material = Enum.Material.Neon
	marker.Color = COLOR
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false; marker.CanQuery = false; marker.CanTouch = false
	marker.CastShadow = false
	marker.Parent = folder
	local markerAttachment = Instance.new("Attachment"); markerAttachment.Parent = marker
	local headAttachment = Instance.new("Attachment"); headAttachment.Parent = host
	local preview = Instance.new("Beam")
	preview.Name = "SnapPreview"
	preview.Attachment0, preview.Attachment1 = headAttachment, markerAttachment
	preview.Width0, preview.Width1 = 0.3, 0.3
	preview.FaceCamera = true
	preview.Color = ColorSequence.new(Color3.new(1, 1, 1))
	preview.LightEmission = 1
	preview.Segments = 2
	if ctx.previewTexture and ctx.previewTexture ~= "" then
		preview.Texture = ctx.previewTexture; preview.TextureLength = 3; preview.Width0, preview.Width1 = 0.5, 0.5
	end
	preview.Enabled = false
	preview.Parent = host
	local previewing = false

	local wasActive = false
	local lastHeading = 0

	function self.reset()
		self.ribbon = Loop.new()
		trail:Clear()
	end
	-- Ribbon cut (server feedback): the ribbon behind the cut is lost; it regrows
	-- from the feet at once. The slice has no cutters; this keeps the path working.
	function self.cut()
		self.reset()
	end
	function self.length()
		local r = self.ribbon
		return if #r > 1 then r[#r].d - r[1].d else 0
	end
	function self.result(id)
		return Ribbon.resolveClaim(self.claims, id)
	end
	function self.retune(newT)
		T = newT
		trail.Lifetime = T.lifetime
		trail.MaxLength = T.maxLength
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, claim in ipairs(Ribbon.expireClaims(self.claims, now)) do
			if ctx.onSlip then ctx.onSlip(claim) end
		end
		local character = ctx.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local active = root ~= nil and ctx.active()
		if not active then
			if wasActive then self.reset(); trail.Enabled = false; preview.Enabled = false; marker.Transparency = 1 end
			wasActive = false
			return
		end
		local origin = ctx.origin()
		local rel = root.Position - origin
		local map = ctx.groundMap()
		local g = ctx.GroundMap.height(map, rel.X, rel.Z, rel.Y - 2.5)
		-- The host rides the ground under the player, oriented along travel.
		local last = self.ribbon[#self.ribbon]
		if last then
			local dx, dz = rel.X - last.x, rel.Z - last.z
			if dx * dx + dz * dz > 0.04 then lastHeading = math.atan2(dx, dz) end
		end
		host.CFrame = CFrame.new(origin + Vector3.new(rel.X, g + 0.25, rel.Z)) * CFrame.Angles(0, lastHeading, 0)
		if not wasActive then
			wasActive = true
			self.reset()
			trail.Enabled = true
		end
		Loop.push(self.ribbon, rel.X, rel.Z, now, T, g)
		if ctx.camera then ctx.camera.ribbonLength = self.length() end
		local head = {x = rel.X, z = rel.Z, t = now, g = g}
		local poly, kind = Loop.tryClose(self.ribbon, T, head)
		if poly then
			self.closures += 1
			local claimId = Ribbon.openClaim(self.claims, now, poly, kind)
			if claimId then
				ctx.send({poly = Loop.encode(poly), kind = kind, viewClock = ctx.viewClock()})
			end
			if ctx.onClose then ctx.onClose(poly, kind, claimId) end
			-- The ribbon restarts from the feet at once, so loops chain without a gap.
			self.reset()
			Loop.push(self.ribbon, rel.X, rel.Z, now, T, g)
			preview.Enabled = false; marker.Transparency = 1; previewing = false
			return
		end
		-- Snap preview inside twice the snap radius, with a cue on entry.
		local sx, sz = Loop.snapPoint(self.ribbon, T, head, T.snapRadius * Ribbon.PREVIEW_FACTOR)
		if sx then
			marker.CFrame = CFrame.new(origin + Vector3.new(sx, ctx.GroundMap.height(map, sx, sz, rel.Y - 2.5) + 0.2, sz)) * CFrame.Angles(0, 0, math.pi / 2)
			marker.Transparency = 0.35
			preview.Enabled = true
			if not previewing then
				previewing = true
				if ctx.onPreview then ctx.onPreview(true) end
			end
		elseif previewing then
			previewing = false
			preview.Enabled = false; marker.Transparency = 1
			if ctx.onPreview then ctx.onPreview(false) end
		end
	end)

	-- Other players' ribbons: display-only Trails at 50 %, never interactive.
	local others = {}
	local function decorate(other)
		if other == ctx.player then return end
		local function attach(character)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if not root then return end
			local b0 = Instance.new("Attachment"); b0.Name = "SparkRibbonL"; b0.Position = Vector3.new(-width, -2.7, 0); b0.Parent = root
			local b1 = Instance.new("Attachment"); b1.Name = "SparkRibbonR"; b1.Position = Vector3.new(width, -2.7, 0); b1.Parent = root
			local t = Instance.new("Trail")
			t.Name = "SparkRibbonOther"; t.Attachment0, t.Attachment1 = b0, b1
			t.FaceCamera = false; t.Lifetime = T.lifetime; t.MaxLength = T.maxLength
			t.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255)); t.LightEmission = 0.4
			t.Transparency = NumberSequence.new(0.5, 0.85)
			t.Parent = root
			others[other] = t
		end
		other.CharacterAdded:Connect(attach)
		if other.Character then task.spawn(attach, other.Character) end
	end
	for _, other in ipairs(Players:GetPlayers()) do decorate(other) end
	Players.PlayerAdded:Connect(decorate)
	Players.PlayerRemoving:Connect(function(other) others[other] = nil end)
	return self
end

return Ribbon
