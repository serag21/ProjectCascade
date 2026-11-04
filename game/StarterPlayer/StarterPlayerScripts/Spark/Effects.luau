-- Bounded local presentation: floating catch tags, bursts, encounter telegraphs,
-- golden compass, foreign-static fading and audio. Nothing here is authoritative:
-- the server decides every catch, hit and reward. All pools are fixed size.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Ui = require(script.Parent.Ui)
local palette, make = Ui.palette, Ui.make

local Effects = {}
Effects.TagPool = 6
Effects.GateSegments = 16
Effects.LaneMarkers = 8

local TAG_COLORS = {
	PRECISE=palette.gold, DASH=palette.sky, HERDED=palette.mint, ASSIST=palette.mint, GOLDEN=palette.gold,
	POP=Color3.fromRGB(200,170,255), ZAP=palette.zap, BUMP=palette.warm,
}
function Effects.tagColor(text)
	if type(text) ~= "string" then return palette.paper end
	if string.sub(text, 1, 5) == "MULTI" then return palette.radiant end
	return TAG_COLORS[text] or palette.paper
end

local function anchoredPart(parent, name, size, color)
	return make("Part", parent, {Name=name, Size=size, Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false,
		CastShadow=false, Material=Enum.Material.Neon, Color=color, Transparency=1, TopSurface=Enum.SurfaceType.Smooth,
		BottomSurface=Enum.SurfaceType.Smooth})
end

-- ctx: {playerGui, gui, folder, reduced=fn()->bool, sfx=fn()->bool, catalog=table?, musicPlaying=fn()->bool, viewerId=number}
function Effects.new(ctx)
	local self = {voices={}, tagSerial=0, tagNext=1, burstCount=0, goldens={}, statics={}}
	local folder = ctx.folder

	-- Floating tags: fixed pool of BillboardGuis offset from one local anchor.
	local tagAnchor = anchoredPart(folder, "TagAnchor", Vector3.one * 0.2, palette.paper)
	tagAnchor.Position = Vector3.zero
	local tags = {}
	for index = 1, Effects.TagPool do
		local board = make("BillboardGui", ctx.playerGui, {Name="SparkTag"..index, Adornee=tagAnchor, Size=UDim2.fromOffset(170,32),
			AlwaysOnTop=true, LightInfluence=0, MaxDistance=90, Enabled=false, ResetOnSpawn=false})
		local text = Ui.label(board, "", 20, UDim2.new(), UDim2.fromScale(1,1), palette.gold)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextStrokeTransparency = 0.2; text.TextStrokeColor3 = palette.ink; text.Font = Enum.Font.GothamBlack
		tags[index] = {board=board, text=text, serial=0}
	end
	-- position: Vector3 world point; lines: array of strings (one billboard each, stacked)
	function self.tags(position, lines)
		if typeof(position) ~= "Vector3" or type(lines) ~= "table" then return end
		for order = 1, math.min(#lines, 3) do
			local slot = tags[self.tagNext]
			self.tagNext = self.tagNext % Effects.TagPool + 1
			self.tagSerial += 1
			local serial = self.tagSerial
			slot.serial = serial
			local start = position + Vector3.new(0, 3 + order * 1.1, 0)
			slot.board.StudsOffsetWorldSpace = start
			slot.text.Text = tostring(lines[order])
			slot.text.TextColor3 = Effects.tagColor(lines[order])
			slot.text.TextTransparency = 0; slot.text.TextStrokeTransparency = 0.2
			slot.board.Enabled = true
			if not ctx.reduced() then
				TweenService:Create(slot.board, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{StudsOffsetWorldSpace=start + Vector3.new(0, 2.5, 0)}):Play()
			end
			task.delay(0.75, function()
				if slot.serial ~= serial then return end
				TweenService:Create(slot.text, TweenInfo.new(0.3), {TextTransparency=1, TextStrokeTransparency=1}):Play()
			end)
			task.delay(1.1, function() if slot.serial == serial then slot.board.Enabled = false end end)
		end
	end

	-- Small radial burst; capped and skipped entirely in reduced motion.
	function self.burst(position, color)
		if typeof(position) ~= "Vector3" or self.burstCount >= 24 or ctx.reduced() then return end
		for i = 1, 8 do
			self.burstCount += 1
			local dot = make("Part", folder, {Shape=Enum.PartType.Ball, Size=Vector3.new(.35,.35,.35), Anchored=true, CanCollide=false,
				CanTouch=false, CanQuery=false, Material=Enum.Material.Neon, Color=color or palette.gold, Position=position, CastShadow=false})
			local angle = i * math.pi / 4
			TweenService:Create(dot, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position=position + Vector3.new(math.cos(angle) * 4, 2, math.sin(angle) * 4), Transparency=1, Size=Vector3.new(.05,.05,.05)}):Play()
			Debris:AddItem(dot, .6)
			task.delay(.6, function() self.burstCount -= 1 end)
		end
	end

	-- Audio: uploaded id wins; otherwise the built-in placeholder fallback.
	local function retire(cue)
		local index = table.find(self.voices, cue)
		if not index then return end
		table.remove(self.voices, index)
		cue:Destroy()
	end
	function self.clearSounds() while #self.voices > 0 do retire(self.voices[1]) end end
	function self.sound(key, speed)
		if not ctx.sfx() then return end
		local entry = ctx.catalog and ctx.catalog[key]
		if type(entry) ~= "table" then return end
		local id, volume, rate = entry.id, entry.volume, entry.fallbackSpeed or 1
		if type(id) ~= "string" or id == "" then id = entry.fallback; volume = entry.fallbackVolume or entry.volume end
		if type(id) ~= "string" or id == "" then return end
		local limit = if ctx.musicPlaying() then 5 else 6
		while #self.voices >= limit do retire(self.voices[1]) end
		local cue = make("Sound", SoundService, {Name="SparkCue_"..key, SoundId=id, Volume=math.clamp(tonumber(volume) or .25, 0, .6),
			PlaybackSpeed=math.clamp(rate * (tonumber(speed) or 1), 0.5, 2)})
		table.insert(self.voices, cue)
		cue.Ended:Connect(function() retire(cue) end)
		cue:Play()
		task.delay(math.clamp((entry.duration or 2) + 1, 1, 12), function() retire(cue) end)
	end

	-- Spark Gate ring: fixed segments, smoothed toward the server position.
	local gateParts = {}
	for index = 1, Effects.GateSegments do gateParts[index] = anchoredPart(folder, "GateSegment", Vector3.new(0.5, 0.35, 2.4), palette.mint) end
	local gateAnchor = anchoredPart(folder, "GateAnchor", Vector3.one * 0.2, palette.mint)
	local gateBoard = make("BillboardGui", gateAnchor, {Name="GateLabel", Size=UDim2.fromOffset(190,40), StudsOffset=Vector3.new(0,4,0),
		MaxDistance=140, LightInfluence=0, Enabled=false})
	local gateText = Ui.label(gateBoard, "", 15, UDim2.new(), UDim2.fromScale(1,1), palette.ink)
	gateText.TextXAlignment = Enum.TextXAlignment.Center; gateText.BackgroundColor3 = palette.mint; gateText.BackgroundTransparency = .1
	Ui.round(gateText, 10)
	local gate = {visible=false, center=nil, target=nil, radius=6, active=false}
	-- Stampede lane chevrons and countdown.
	local laneParts = {}
	for index = 1, Effects.LaneMarkers do laneParts[index] = anchoredPart(folder, "LaneMarker", Vector3.new(2.6, 0.12, 1.2), palette.warm) end
	local laneAnchor = anchoredPart(folder, "LaneAnchor", Vector3.one * 0.2, palette.warm)
	local laneBoard = make("BillboardGui", laneAnchor, {Name="LaneLabel", Size=UDim2.fromOffset(200,40), StudsOffset=Vector3.new(0,5,0),
		MaxDistance=160, LightInfluence=0, Enabled=false})
	local laneText = Ui.label(laneBoard, "", 15, UDim2.new(), UDim2.fromScale(1,1), palette.ink)
	laneText.TextXAlignment = Enum.TextXAlignment.Center; laneText.BackgroundColor3 = palette.gold; laneText.BackgroundTransparency = .1
	Ui.round(laneText, 10)

	local function hideGate()
		gate.visible = false; gateBoard.Enabled = false
		for _, segment in ipairs(gateParts) do segment.Transparency = 1 end
	end
	local function hideLane()
		laneBoard.Enabled = false
		for _, marker in ipairs(laneParts) do marker.Transparency = 1 end
	end
	hideGate(); hideLane()

	-- Called on every server state (2Hz). Pure drawing from server descriptors.
	function self.encounters(data)
		local g = data and data.gate
		if type(g) == "table" and g.visible and typeof(g.position) == "Vector3" and data.phase == "Playing" then
			gate.target = g.position; gate.radius = tonumber(g.radius) or 6; gate.active = g.active == true
			if not gate.visible or not gate.center or (gate.center - g.position).Magnitude > 20 then gate.center = g.position end
			gate.visible = true
			gateBoard.Enabled = true
			gateText.Text = if g.active then string.format("SPARK GATE • %ds\nHerd Sparks through!", math.ceil(tonumber(g.seconds) or 0))
				else string.format("SPARK GATE OPENS IN %d", math.ceil(tonumber(g.seconds) or 0))
			for _, segment in ipairs(gateParts) do
				segment.Color = if gate.active then palette.mint else palette.paper
				segment.Transparency = if gate.active then 0.15 else 0.55
			end
		elseif gate.visible then hideGate() end
		local r = data and data.stampede
		if type(r) == "table" and r.visible and typeof(r.fromPosition) == "Vector3" and typeof(r.toPosition) == "Vector3" and data.phase == "Playing" then
			local direction = r.toPosition - r.fromPosition
			if direction.Magnitude > 1 then
				local unit = direction.Unit
				for index, marker in ipairs(laneParts) do
					local point = r.fromPosition + direction * ((index - 0.5) / #laneParts) + Vector3.new(0, 0.1, 0)
					marker.CFrame = CFrame.lookAt(point, point + unit)
					marker.Transparency = if r.active then 0.55 else 0.2
				end
				laneAnchor.Position = (r.fromPosition + r.toPosition) / 2
				laneBoard.Enabled = true
				laneText.Text = if r.active then "STAMPEDE RUN • DASH THROUGH!" else string.format("STAMPEDE RUN IN %d", math.ceil(tonumber(r.seconds) or 0))
			end
		else hideLane() end
	end

	-- Golden edge-of-screen compass (only with the Golden Nose perk).
	local compass = make("TextLabel", ctx.gui, {Name="GoldenCompass", Size=UDim2.fromOffset(46,46), AnchorPoint=Vector2.new(.5,.5),
		BackgroundColor3=palette.gold, BackgroundTransparency=.05, Text="▲", TextSize=24, Font=Enum.Font.GothamBlack,
		TextColor3=palette.ink, Visible=false, ZIndex=2})
	Ui.round(compass, 23)

	-- Per frame: smooth the gate ring and place the compass. No allocation churn.
	function self.render(dt, data, root, camera)
		if gate.visible and gate.target then
			local alpha = math.clamp((dt or 0) * 4, 0, 1)
			gate.center = gate.center:Lerp(gate.target, alpha)
			local spin = if ctx.reduced() then 0 else os.clock() * 0.6
			for index, segment in ipairs(gateParts) do
				local angle = index / #gateParts * math.pi * 2 + spin
				local point = gate.center + Vector3.new(math.cos(angle) * gate.radius, 0.35, math.sin(angle) * gate.radius)
				segment.CFrame = CFrame.lookAt(point, point + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			end
			gateAnchor.Position = gate.center
		end
		local goldens = data and data.goldens
		local show = data ~= nil and data.phase == "Playing" and type(goldens) == "table" and #goldens > 0
			and Ui.get(data, "stats", "goldenCompass") == true and root ~= nil and camera ~= nil
		compass.Visible = show
		if not show then return end
		local nearest, best = nil, math.huge
		for _, position in ipairs(goldens) do
			if typeof(position) == "Vector3" then
				local d = (position - root.Position).Magnitude
				if d < best then nearest, best = position, d end
			end
		end
		if not nearest then compass.Visible = false; return end
		local viewport = camera.ViewportSize
		local point, onScreen = camera:WorldToViewportPoint(nearest)
		local center = viewport / 2
		local target = Vector2.new(point.X, point.Y)
		if onScreen then
			compass.Position = UDim2.fromOffset(target.X, math.max(30, target.Y - 50)); compass.Rotation = 180
		else
			local delta = target - center
			if point.Z < 0 then delta = -delta end
			if delta.Magnitude < 1 then delta = Vector2.new(0, -1) end
			local margin = 40
			local scale = math.min((center.X - margin) / math.max(1e-3, math.abs(delta.X)), (center.Y - margin) / math.max(1e-3, math.abs(delta.Y)))
			local edge = center + delta * scale
			compass.Position = UDim2.fromOffset(edge.X, edge.Y)
			compass.Rotation = math.deg(math.atan2(delta.Y, delta.X)) + 90
		end
	end

	-- Golden creatures: local reduced-motion switch for their sparkle/glow.
	local function applyGolden(model)
		local quiet = ctx.reduced()
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("ParticleEmitter") or item:IsA("PointLight") then item.Enabled = not quiet end
		end
	end
	function self.trackCreature(model)
		if model:GetAttribute("Golden") and not self.goldens[model] then
			self.goldens[model] = true; applyGolden(model)
		end
	end
	function self.untrackCreature(model) self.goldens[model] = nil end
	function self.setReduced()
		for model in pairs(self.goldens) do if model.Parent then applyGolden(model) else self.goldens[model] = nil end end
	end

	-- Other players' statics are faded locally (they cannot hit you).
	function self.trackStatic(model)
		if self.statics[model] then return end
		local owner = model:GetAttribute("OwnerId")
		local foreign = owner ~= nil and owner ~= ctx.viewerId
		local function apply(item)
			if foreign and item:IsA("BasePart") then item.LocalTransparencyModifier = 0.75 end
		end
		for _, item in ipairs(model:GetDescendants()) do apply(item) end
		self.statics[model] = model.DescendantAdded:Connect(apply)
	end
	function self.untrackStatic(model)
		local connection = self.statics[model]
		if connection then connection:Disconnect() end
		self.statics[model] = nil
	end

	return self
end

return Effects
