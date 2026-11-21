-- Loop effects (WP-07): the cinch ring from data/models/cinch_effect.json,
-- pops on the pentatonic ladder, the world-space payout tag, ROUNDUP/STAMPEDE
-- extras, the empty-loop fizz, the slip, the bank fountain and pooled telegraph
-- rings. Everything lives under workspace.SparkFx with a fixed part budget:
-- ring host, flash disc, shockwave, payout host, burst host and a small
-- telegraph pool (Beams, attachments, emitters and billboards are not parts).
local LoopFx = {}

-- Pentatonic ladder speed for the i-th pop (1-based): 2^(step/12).
local STEPS = {0, 2, 4, 7, 9, 12, 14, 16}
function LoopFx.pentatonic(i)
	return 2 ^ (STEPS[((i - 1) % #STEPS) + 1] / 12)
end

-- Pure: resample a polygon to n points by arc length.
function LoopFx.resample(poly, n)
	local m = #poly
	local lengths, total = {}, 0
	for i = 1, m do
		local a, b = poly[i], poly[i % m + 1]
		local l = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		lengths[i] = l; total += l
	end
	local out = {}
	if total <= 0 then
		for k = 1, n do out[k] = {x = poly[1].x, z = poly[1].z} end
		return out
	end
	local step = total / n
	local seg, into = 1, 0
	for k = 0, n - 1 do
		local target = k * step
		while seg <= m and into + lengths[seg] < target do into += lengths[seg]; seg += 1 end
		local i = math.min(seg, m)
		local a, b = poly[i], poly[i % m + 1]
		local u = if lengths[i] > 0 then (target - into) / lengths[i] else 0
		out[k + 1] = {x = a.x + (b.x - a.x) * u, z = a.z + (b.z - a.z) * u}
	end
	return out
end

-- Pure: keyframe sampling for {{t, v}, ...} numeric tracks.
function LoopFx.track(keys, t)
	if t <= keys[1].t then return keys[1].v end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then return a.v + (b.v - a.v) * (t - a.t) / (b.t - a.t) end
	end
	return keys[#keys].v
end

-- Pure: size tier of a loop for extras ("1-4", "5-7", "8+").
function LoopFx.sizeTier(n)
	if n >= 8 then return "8+" elseif n >= 5 then return "5-7" end
	return "1-4"
end

---------------------------------------------------------------- Roblox side
-- ctx: {fxFolder, cinch (Models.cinch_effect), sfx, creatureView, reduced(), color, groundY(x, z), origin()}
function LoopFx.new(ctx)
	local RunService = game:GetService("RunService")
	local C = ctx.cinch
	local self = {active = nil}
	local folder = ctx.fxFolder
	local function hostPart(name, size, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.Transparency = 1
		p.Material = Enum.Material.Neon
		if shape then p.Shape = shape end
		p.Parent = folder
		return p
	end
	local ringHost = hostPart("CinchRing", Vector3.new(0.2, 0.2, 0.2))
	local attachments, beams = {}, {}
	for i = 1, C.ring.segments do
		local a = Instance.new("Attachment"); a.Parent = ringHost
		attachments[i] = a
	end
	for i = 1, C.ring.segments do
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = attachments[i], attachments[i % C.ring.segments + 1]
		beam.FaceCamera = true; beam.LightEmission = C.ring.lightEmission; beam.Segments = 1
		beam.Enabled = false; beam.Parent = ringHost
		beams[i] = beam
	end
	local flash = hostPart("CinchFlash", Vector3.new(0.1, 4, 4), Enum.PartType.Cylinder)
	local shock = hostPart("CinchShockwave", Vector3.new(0.1, 4, 4), Enum.PartType.Cylinder)
	local payoutHost = hostPart("PayoutTag", Vector3.new(0.2, 0.2, 0.2))
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(240, 64); tag.LightInfluence = 0; tag.AlwaysOnTop = true; tag.Enabled = false
	tag.MaxDistance = 160; tag.Parent = payoutHost
	local line1 = Instance.new("TextLabel")
	line1.BackgroundTransparency = 1; line1.Size = UDim2.fromScale(1, 0.62); line1.Font = Enum.Font.GothamBlack
	line1.TextSize = 36; line1.TextColor3 = Color3.fromRGB(255, 249, 231); line1.TextStrokeColor3 = Color3.fromRGB(27, 36, 64)
	line1.TextStrokeTransparency = 0; line1.Parent = tag
	local line2 = line1:Clone()
	line2.Position = UDim2.fromScale(0, 0.62); line2.Size = UDim2.fromScale(1, 0.38); line2.TextSize = 15
	line2.TextColor3 = Color3.fromRGB(255, 227, 107); line2.Font = Enum.Font.GothamBold; line2.Parent = tag
	local burstHost = hostPart("PopBurst", Vector3.new(0.2, 0.2, 0.2))
	local pop = Instance.new("ParticleEmitter")
	pop.Name = "Pop"; pop.Enabled = false; pop.Rate = 0
	pop.Speed = NumberRange.new(6, 12); pop.Lifetime = NumberRange.new(0.25, 0.45); pop.SpreadAngle = Vector2.new(180, 180)
	pop.Size = NumberSequence.new(0.9, 0); pop.LightEmission = 0.8; pop.Parent = burstHost
	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"; confetti.Enabled = false; confetti.Rate = 0
	confetti.Speed = NumberRange.new(10, 18); confetti.Lifetime = NumberRange.new(0.9, 1.4); confetti.SpreadAngle = Vector2.new(30, 30)
	confetti.Acceleration = Vector3.new(0, -24, 0); confetti.RotSpeed = NumberRange.new(180, 360)
	confetti.Size = NumberSequence.new(0.45); confetti.Parent = burstHost
	confetti.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 72)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 150, 186)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 232, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 170, 255))})
	local fizz = Instance.new("ParticleEmitter")
	fizz.Name = "Fizz"; fizz.Enabled = false; fizz.Rate = 0; fizz.Speed = NumberRange.new(2, 4)
	fizz.Lifetime = NumberRange.new(0.3, 0.5); fizz.Color = ColorSequence.new(Color3.fromRGB(230, 230, 236)); fizz.Parent = burstHost
	-- Telegraph rings (ghost ring, bloom radius, hop ring, bank chevron flare): a small pool.
	local telegraphs = {}
	for i = 1, 6 do
		local t = hostPart("Telegraph" .. i, Vector3.new(0.12, 4, 4), Enum.PartType.Cylinder)
		t.Color = Color3.fromRGB(255, 236, 96)
		telegraphs[i] = {part = t, untilT = 0}
	end

	local function emitAt(emitter, position, count, color)
		burstHost.CFrame = CFrame.new(position)
		if color then emitter.Color = ColorSequence.new(color) end
		emitter:Emit(count)
	end

	local function setRing(points, centroid, scale, y, width, color)
		for i, p in ipairs(points) do
			local x = centroid.X + (p.x - centroid.X) * scale
			local z = centroid.Z + (p.z - centroid.Z) * scale
			attachments[i].WorldPosition = Vector3.new(x, y, z)
		end
		for _, beam in ipairs(beams) do
			beam.Enabled = true; beam.Width0, beam.Width1 = width, width
			beam.Color = ColorSequence.new(color)
		end
	end
	local function hideRing() for _, beam in ipairs(beams) do beam.Enabled = false end end

	-- The client closed a loop: flash, freeze predicted creatures, start the cinch.
	function self.close(poly, predictedIds, now)
		local origin = ctx.origin()
		local world = {}
		for i, p in ipairs(poly) do world[i] = {x = origin.X + p.x, z = origin.Z + p.z} end
		local points = LoopFx.resample(world, C.ring.segments)
		local cx, cz = 0, 0
		for _, p in ipairs(points) do cx += p.x / #points; cz += p.z / #points end
		local ground = ctx.groundY(cx - origin.X, cz - origin.Z)
		local centroid = Vector3.new(cx, ground, cz)
		local radius = 0
		for _, p in ipairs(points) do radius = math.max(radius, math.sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2)) end
		self.active = {start = now, points = points, centroid = centroid, y = ground + C.ring.y, radius = radius,
			predicted = predictedIds or {}, result = nil, done = false}
		for _, id in ipairs(predictedIds or {}) do
			if ctx.creatureView then ctx.creatureView.cinch(id, now + 0.8) end
		end
		if not (ctx.reduced and ctx.reduced()) then
			flash.Size = Vector3.new(0.1, radius * 2, radius * 2)
			flash.CFrame = CFrame.new(centroid + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			flash.Color = ctx.color; flash.Transparency = 0.75
		end
		ctx.sfx.play("loop_close")
		ctx.sfx.play("loop_cinch")
	end

	-- Server result (feedback kind "Loop").
	function self.result(extra, now)
		local a = self.active
		if not a or a.done then return end
		a.result = extra
		a.resultAt = math.max(now, a.start + C.ring.holdUntil)
		local caught = extra.caught or {}
		local caughtSet = {}
		for _, c in ipairs(caught) do caughtSet[c.creatureId] = true end
		-- Predicted but not caught (or reported escaped): "nope" hop and un-freeze.
		for _, id in ipairs(a.predicted) do
			if not caughtSet[id] and ctx.creatureView then ctx.creatureView.cinch(id, 0) end
		end
		for _, id in ipairs(extra.escaped or {}) do
			if ctx.creatureView and ctx.creatureView.nope then ctx.creatureView.nope(id, now) end
		end
	end

	local function finishSlip()
		local a = self.active
		if not a then return end
		for _, id in ipairs(a.predicted) do if ctx.creatureView then ctx.creatureView.cinch(id, 0) end end
	end

	-- Bank fountain at a ring position.
	function self.bank(position, count)
		ctx.sfx.play("bank_slam")
		if ctx.reduced and ctx.reduced() then return end
		emitAt(confetti, position + Vector3.new(0, 4, 0), math.min(40, 8 + count * 3))
	end

	-- Telegraph ring: a flat neon ring at a world position for `seconds`.
	function self.telegraph(position, radius, seconds, color)
		local slot = telegraphs[1]
		for _, t in ipairs(telegraphs) do if t.untilT < (slot.untilT) then slot = t end end
		slot.untilT = os.clock() + seconds
		slot.part.Size = Vector3.new(0.12, radius * 2, radius * 2)
		slot.part.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		slot.part.Color = color or Color3.fromRGB(255, 236, 96)
		slot.part.Transparency = 0.55
		slot.shrinkFrom = radius
		slot.startedAt = os.clock()
		slot.shrink = false
		return slot
	end
	-- Stampede route telegraph: marching chevron Beams along the route (no parts).
	local routeHost = hostPart("StampedeRoute", Vector3.new(0.2, 0.2, 0.2))
	local routeAttachments, routeBeams = {}, {}
	for i = 1, 16 do
		local a = Instance.new("Attachment"); a.Parent = routeHost; routeAttachments[i] = a
	end
	for i = 1, 15 do
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = routeAttachments[i], routeAttachments[i + 1]
		beam.Width0, beam.Width1 = 3, 3; beam.FaceCamera = false; beam.LightEmission = 0.8
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 214, 72)); beam.Transparency = NumberSequence.new(0.35)
		beam.TextureSpeed = 2; beam.TextureLength = 6; beam.Enabled = false; beam.Parent = routeHost
		routeBeams[i] = beam
	end
	local routeUntil = 0
	function self.route(points, seconds)
		local origin = ctx.origin()
		for i, a in ipairs(routeAttachments) do
			local p = points[math.min(i, #points)]
			a.WorldPosition = origin + Vector3.new(p[1], ctx.groundY(p[1], p[2]) + 0.3, p[2])
		end
		for i, beam in ipairs(routeBeams) do beam.Enabled = i < #points end
		routeUntil = os.clock() + seconds
	end
	RunService.Heartbeat:Connect(function()
		if routeUntil > 0 and os.clock() >= routeUntil then
			routeUntil = 0
			for _, beam in ipairs(routeBeams) do beam.Enabled = false end
		end
	end)

	function self.hopRing(position)
		local slot = self.telegraph(position, 3, 0.5, Color3.fromRGB(255, 132, 177))
		slot.shrink = true
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, t in ipairs(telegraphs) do
			if now >= t.untilT then
				if t.part.Transparency < 1 then t.part.Transparency = 1 end
			elseif t.shrink then
				local k = math.clamp((now - t.startedAt) / math.max(0.01, t.untilT - t.startedAt), 0, 1)
				local r = t.shrinkFrom * (1 - 0.66 * k)
				t.part.Size = Vector3.new(0.12, r * 2, r * 2)
			end
		end
		if flash.Transparency < 1 then flash.Transparency = math.min(1, flash.Transparency + 0.25 / 0.18 * (1 / 60)) end
		if shock.Transparency < 1 and self.shockAt then
			local k = math.clamp((now - self.shockAt) / 0.3, 0, 1)
			local r = self.shockRadius * k
			shock.Size = Vector3.new(0.1, r * 2 + 0.1, r * 2 + 0.1)
			shock.Transparency = 0.4 + 0.6 * k
		end
		if payoutHost:GetAttribute("At") then
			local k = math.clamp((now - payoutHost:GetAttribute("At")) / 1.2, 0, 1)
			payoutHost.CFrame = CFrame.new(self.payoutBase + Vector3.new(0, 4 * k, 0))
			local punch = if k < 0.1 then 0.6 + 0.4 * (k / 0.1) else 1
			tag.Size = UDim2.fromOffset(240 * punch, 64 * punch)
			line1.TextTransparency = math.max(0, (k - 0.7) / 0.3); line2.TextTransparency = line1.TextTransparency
			if k >= 1 then tag.Enabled = false; payoutHost:SetAttribute("At", nil) end
		end
		local a = self.active
		if not a or a.done then return end
		local t = now - a.start
		local color = ctx.color
		local shrinkK = math.clamp(t / C.ring.shrink["end"], 0, 1)
		local minScale = math.max(C.ring.shrink.to, if a.radius > 0 then 0.6 / a.radius else 0)
		local scale = 1 - (1 - minScale) * shrinkK * shrinkK -- quadIn
		local width = LoopFx.track(C.ring.width, t)
		if a.result then
			local r = a.result
			local caught = r.caught or {}
			local since = now - a.resultAt
			if #caught == 0 then
				-- Empty loop (or rejected claim): fade 0.2 s, fizz, whiff.
				if not a.whiffed then
					a.whiffed = true
					ctx.sfx.play("loop_whiff")
					emitAt(fizz, a.centroid + Vector3.new(0, 1, 0), 6)
				end
				local k = math.clamp(since / 0.2, 0, 1)
				setRing(a.points, a.centroid, scale, a.y, width * (1 - k), color)
				if k >= 1 then hideRing(); a.done = true end
				return
			end
			a.popped = a.popped or 0
			while a.popped < #caught and since >= a.popped * (ctx.popStagger or 0.06) do
				a.popped += 1
				local c = caught[a.popped]
				local cf = ctx.creatureView and ctx.creatureView.lastPose(c.creatureId)
				local position = if cf then cf.Position else a.centroid + Vector3.new(0, 1.5, 0)
				emitAt(pop, position + Vector3.new(0, 1, 0), 12, ctx.speciesColor and ctx.speciesColor(c.species) or color)
				ctx.sfx.play("catch_pop", LoopFx.pentatonic(a.popped))
			end
			if not a.tagged and since >= #caught * (ctx.popStagger or 0.06) + 0.05 then
				a.tagged = true
				self.payoutBase = a.centroid + Vector3.new(0, 3, 0)
				payoutHost.CFrame = CFrame.new(self.payoutBase)
				line1.Text = "+" .. tostring(r.points or 0)
				local parts = {}
				for _, tech in ipairs(r.techs or {}) do table.insert(parts, tech) end
				local n = #caught
				if n >= 8 then table.insert(parts, 1, "STAMPEDE!") elseif n >= 5 then table.insert(parts, 1, "ROUNDUP!") end
				table.insert(parts, "x" .. tostring(r.multiplier or 1))
				line2.Text = table.concat(parts, " · ")
				tag.Enabled = true
				payoutHost:SetAttribute("At", now)
				if #(r.techs or {}) > 0 then ctx.sfx.play("tech_stinger") end
				local tier = LoopFx.sizeTier(n)
				if tier ~= "1-4" then
					ctx.sfx.play(if tier == "8+" then "stampede_stinger" else "roundup_stinger")
					if not (ctx.reduced and ctx.reduced()) then
						self.shockAt, self.shockRadius = now, a.radius + 6
						shock.Color = color; shock.Transparency = 0.4
						shock.CFrame = CFrame.new(a.centroid + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
					end
					local count = if tier == "8+" then (if ctx.reduced and ctx.reduced() then 20 else 60) else 30
					emitAt(confetti, a.centroid + Vector3.new(0, 2, 0), count)
					if tier == "8+" and ctx.onStampede then ctx.onStampede(n) end
				end
			end
			-- Ring collapses to the centroid as the last creature pops (0.12 s).
			local collapseStart = math.max(0, (#caught - 1) * 0.06)
			local k = math.clamp((since - collapseStart) / 0.12, 0, 1)
			setRing(a.points, a.centroid, scale * (1 - k), a.y, width, color)
			if k >= 1 and a.tagged then hideRing(); a.done = true end
			return
		end
		if t >= (ctx.resultTimeout or 0.8) then
			-- No result: the ring releases as a harmless slip.
			finishSlip()
			hideRing(); a.done = true
			return
		end
		local tint = if t < 0.06 then Color3.new(1, 1, 1):Lerp(color, t / 0.06) else color
		setRing(a.points, a.centroid, scale, a.y, width, tint)
	end)
	return self
end

return LoopFx
