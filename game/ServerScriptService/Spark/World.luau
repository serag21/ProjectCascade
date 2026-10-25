--!strict
-- Deterministic, original primitive art. Git owns this scene; never edits Terrain.
local World = {}

local WHITE = Color3.fromRGB(255, 249, 231)
local INK = Color3.fromRGB(27, 36, 64)
local GOLD = Color3.fromRGB(255, 217, 90)
local TAU = math.pi * 2

local function rgb(value: {number}): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3,
	shape: Enum.PartType?, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.CastShadow = material ~= Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	return part(parent, name, size, CFrame.new(position), color, Enum.PartType.Ball)
end

local function disc(parent: Instance, name: string, diameter: number, height: number, position: Vector3,
	color: Color3, material: Enum.Material?, collide: boolean?): Part
	return part(parent, name, Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, material, collide)
end

local function textSign(parent: Instance, name: string, position: Vector3, title: string, subtitle: string, tint: Color3)
	local anchor = part(parent, name, Vector3.new(1, 1, 1), CFrame.new(position), tint)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(300, 86)
	gui.MaxDistance = 130
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = anchor
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.08
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 18)
	round.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = tint
	stroke.Thickness = 2
	stroke.Parent = panel
	for i, content in ipairs({title, subtitle}) do
		local label = Instance.new("TextLabel")
		label.Name = if i == 1 then "Title" else "Subtitle"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.03, if i == 1 then 0.06 else 0.57)
		label.Size = UDim2.fromScale(0.94, if i == 1 then 0.5 else 0.3)
		label.Text = content
		label.TextColor3 = if i == 1 then WHITE else tint
		label.TextSize = if i == 1 then 24 else 16
		label.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamMedium
		label.Parent = panel
	end
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3)
	return part(parent, name, Vector3.new(thickness, thickness, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b), color)
end

local function pennant(parent: Instance, position: Vector3, color: Color3, index: number)
	part(parent, "BannerPole", Vector3.new(0.35, 12, 0.35), CFrame.new(position + Vector3.new(0, 6, 0)), WHITE)
	part(parent, "Banner", Vector3.new(3.5, 4, 0.15), CFrame.new(position + Vector3.new(1.75, 10, 0)), color)
	ball(parent, "Finial", Vector3.one * 0.8, position + Vector3.new(0, 12.2, 0), GOLD)
	part(parent, "BannerStripe", Vector3.new(0.65, 4, 0.2), CFrame.new(position + Vector3.new(1 + (index % 2), 10, 0)), WHITE)
end

local function bank(parent: Instance, origin: Vector3, accent: Color3)
	local p = origin + Vector3.new(0, 0, 44)
	disc(parent, "BankHalo", 21, 0.12, p + Vector3.new(0, 0.08, 0), accent, Enum.Material.Neon)
	disc(parent, "BankPad", 18, 0.15, p + Vector3.new(0, 0.17, 0), INK)
	disc(parent, "BankCenter", 13, 0.17, p + Vector3.new(0, 0.2, 0), accent:Lerp(WHITE, 0.5))
	for _, x in ipairs({-10, 10}) do
		part(parent, "BankPillar", Vector3.new(2, 12, 2), CFrame.new(p + Vector3.new(x, 6, 4)), WHITE, nil, nil, true)
		ball(parent, "BankOrb", Vector3.one * 3, p + Vector3.new(x, 13, 4), accent)
		part(parent, "BankPillarLight", Vector3.new(0.4, 8, 2.1), CFrame.new(p + Vector3.new(x, 6, 4)), accent, nil, Enum.Material.Neon)
	end
	part(parent, "BankHeader", Vector3.new(22, 2.2, 2.5), CFrame.new(p + Vector3.new(0, 12, 4)), INK)
	textSign(parent, "BankSign", p + Vector3.new(0, 15, 4), "BANK YOUR SPARKS", "Bring your haul into the ring", accent)
	-- A persistent diamond beacon; deliberately no flashing lights or screen effects.
	part(parent, "BankBeacon", Vector3.one * 3, CFrame.new(p + Vector3.new(0, 19, 4)) * CFrame.Angles(0, 0, math.pi / 4), accent, nil, Enum.Material.Neon)
	for n = 1, 4 do
		local z = 10 + n * 5
		for _, side in ipairs({-1, 1}) do
			part(parent, "BankChevron", Vector3.new(3.8, 0.08, 0.6),
				CFrame.new(origin + Vector3.new(side * 1.3, 0.14, z)) * CFrame.Angles(0, side * math.pi / 5, 0), WHITE)
		end
	end
end

local function meadowProp(parent: Instance, p: Vector3, scale: number, index: number, accent: Color3)
	if index % 3 == 0 then
		-- Soft, oversized luminous clover; the chase area never has dense trunks.
		part(parent, "CloverStem", Vector3.new(0.65, 7 * scale, 0.65), CFrame.new(p + Vector3.new(0, 3.5 * scale, 0)), Color3.fromRGB(64, 142, 121))
		for n = 1, 3 do
			local angle = n * TAU / 3
			ball(parent, "CloverLeaf", Vector3.new(5, 2, 5) * scale,
				p + Vector3.new(math.cos(angle) * 2 * scale, 7 * scale, math.sin(angle) * 2 * scale), accent)
		end
	else
		disc(parent, "CanopyTrunk", 1.8 * scale, 8 * scale,
			p + Vector3.new(0, 4 * scale, 0), Color3.fromRGB(151, 107, 121))
		ball(parent, "CloudCanopy", Vector3.new(12, 8, 11) * scale,
			p + Vector3.new(0, 10 * scale, 0), if index % 2 == 0 then Color3.fromRGB(255, 153, 187) else Color3.fromRGB(105, 219, 173))
		ball(parent, "CloudCanopyHighlight", Vector3.new(8, 6, 8) * scale,
			p + Vector3.new(2 * scale, 13 * scale, 0), if index % 2 == 0 then Color3.fromRGB(255, 191, 208) else Color3.fromRGB(151, 242, 183))
	end
end

local function canyonProp(parent: Instance, p: Vector3, scale: number, index: number, accent: Color3)
	-- Faceted orange sandstone with teal mineral seams and broad readable profiles.
	for tier = 1, 3 do
		local width = (10 - tier * 1.6) * scale
		part(parent, "MesaTier", Vector3.new(width, 4 * scale, width),
			CFrame.new(p + Vector3.new(0, (tier * 3.5 - 1.5) * scale, 0)) * CFrame.Angles(0, index * 0.4, 0),
			Color3.fromRGB(207 + tier * 10, 104 + tier * 18, 89 + tier * 14))
	end
	part(parent, "MineralCrown", Vector3.new(1.6, 5, 1.6) * scale,
		CFrame.new(p + Vector3.new(0, 12 * scale, 0)) * CFrame.Angles(0, 0, 0.2), accent, nil, Enum.Material.Neon)
end

local function auroraProp(parent: Instance, p: Vector3, scale: number, index: number, accent: Color3)
	for shard = 1, 3 do
		local h = (7 + ((index + shard) % 4) * 2) * scale
		local cf = CFrame.new(p + Vector3.new((shard - 2) * 2.4 * scale, h / 2, 0))
			* CFrame.Angles(0, math.pi / 4, (shard - 2) * 0.16)
		local shardPart = part(parent, "AuroraCrystal", Vector3.new(3, h, 3) * Vector3.new(scale, 1, scale), cf,
			if shard == 2 then accent else Color3.fromRGB(168, 183, 243), nil, Enum.Material.Glass)
		shardPart.Transparency = 0.15
		part(parent, "CrystalCore", Vector3.new(0.7, h * 0.7, 0.7) * Vector3.new(scale, 1, scale), cf,
			WHITE:Lerp(accent, 0.5), nil, Enum.Material.Neon)
	end
end

local function buildArena(parent: Instance, biome: any, index: number)
	local arena = Instance.new("Model")
	arena.Name = biome.id
	arena.Parent = parent
	local origin = Vector3.new((index - 1) * 300, 0, 0)
	local base, accent = rgb(biome.color), rgb(biome.accent)
	arena:SetAttribute("BiomeIndex", index)
	-- Top faces at Y=0; all inlays are non-colliding and less than a stud high.
	disc(arena, "IslandUnderside", 146, 8, origin + Vector3.new(0, -5.2, 0), base:Lerp(INK, 0.35), nil, true)
	disc(arena, "ArenaFloor", 142, 2, origin + Vector3.new(0, -1, 0), base, nil, true)
	disc(arena, "ChaseRing", 112, 0.05, origin + Vector3.new(0, 0.04, 0), base:Lerp(WHITE, 0.12))
	disc(arena, "ChaseInfield", 103, 0.05, origin + Vector3.new(0, 0.08, 0), base)
	disc(arena, "StampedeMedallion", 20, 0.06, origin + Vector3.new(0, 0.12, 0), base:Lerp(WHITE, 0.22))
	for n = 1, 8 do
		local angle = n * TAU / 8
		part(arena, "MedallionRay", Vector3.new(1, 0.08, 3),
			CFrame.new(origin + Vector3.new(math.sin(angle) * 6, 0.17, math.cos(angle) * 6)) * CFrame.Angles(0, angle, 0), WHITE)
	end
	for n = 1, 32 do
		local angle = n * TAU / 32
		local position = origin + Vector3.new(math.sin(angle) * 69, 1.5, math.cos(angle) * 69)
		-- Wide southern portal opens naturally onto the hub walkway.
		if math.abs(math.sin(angle)) > 0.2 or math.cos(angle) < 0 then
			part(arena, "VisibleRim", Vector3.new(12.8, 3, 2), CFrame.new(position) * CFrame.Angles(0, angle, 0), base:Lerp(INK, 0.16), nil, nil, true)
			part(arena, "RimCap", Vector3.new(12.8, 0.28, 2.2), CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, angle, 0), accent)
		end
		if n % 4 == 0 then task.wait() end
	end
	-- Outside silhouettes frame the entire playfield without blocking the camera.
	for n = 1, 16 do
		local angle = n * TAU / 16
		if math.abs(math.sin(angle)) > 0.24 or math.cos(angle) < 0 then
			local p = origin + Vector3.new(math.sin(angle) * 77, 0, math.cos(angle) * 77)
			local scale = 0.75 + (n % 3) * 0.18
			if index == 1 then meadowProp(arena, p, scale, n, accent)
			elseif index == 2 then canyonProp(arena, p, scale, n, accent)
			else auroraProp(arena, p, scale, n, accent) end
		end
	end
	-- Four low islands create steering choices. Broad clear gaps prevent dead ends.
	for n = 1, 4 do
		local angle = math.pi / 4 + n * math.pi / 2
		local p = origin + Vector3.new(math.sin(angle) * 37, 0, math.cos(angle) * 37)
		disc(arena, "SteeringIsland", 9, 2.2, p + Vector3.new(0, 1.1, 0), base:Lerp(INK, 0.08), nil, true)
		disc(arena, "IslandTop", 8.8, 0.2, p + Vector3.new(0, 2.3, 0), accent:Lerp(WHITE, 0.35))
		if index == 1 then
			for flower = 1, 3 do
				local a = flower * TAU / 3
				ball(arena, "GlowBud", Vector3.new(1.5, 1.3, 1.5), p + Vector3.new(math.cos(a) * 2, 3, math.sin(a) * 2), WHITE)
			end
		elseif index == 2 then
			part(arena, "MineralMarker", Vector3.new(2.4, 3, 2.4), CFrame.new(p + Vector3.new(0, 3.8, 0)) * CFrame.Angles(0, math.pi / 4, 0), accent)
		else
			ball(arena, "SnowPearl", Vector3.new(3, 2, 3), p + Vector3.new(0, 3.1, 0), WHITE)
		end
	end
	for _, x in ipairs({-19, 19}) do pennant(arena, origin + Vector3.new(x, 0, 54), accent, index) end
	bank(arena, origin, accent)
	-- Chase sign faces arriving players, kept away from the bank label.
	textSign(arena, "ArenaSign", origin + Vector3.new(0, 13, -59), string.upper(biome.name), "CHASE  •  CATCH  •  BANK", accent)
	disc(arena, "ArrivalPlaza", 28, 1.6, origin + Vector3.new(0, -0.8, 62), base:Lerp(WHITE, 0.1), nil, true)
	for n = 1, 3 do
		disc(arena, "ShowcasePlinth", 5, 1.1, origin + Vector3.new((n - 2) * 9, 0.55, 68), WHITE, nil, true)
		disc(arena, "ShowcaseTrim", 5.2, 0.14, origin + Vector3.new((n - 2) * 9, 1.15, 68), accent, Enum.Material.Neon)
	end
	return {origin = origin, spawn = origin + Vector3.new(0, 3, 38), bank = origin + Vector3.new(0, 0, 44), radius = 65}
end

function World.build(config: any)
	local root = Instance.new("Model")
	root.Name = "SparkWorld"
	root:SetAttribute("ArtVersion", 1)
	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = root
	local arenas = {}
	for index, biome in ipairs(config.Biomes) do
		table.insert(arenas, buildArena(root, biome, index))
		task.wait()
	end
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 14
	lighting.Brightness = 2.5
	lighting.Ambient = Color3.fromRGB(158, 163, 195)
	lighting.OutdoorAmbient = Color3.fromRGB(178, 192, 213)
	lighting.FogColor = Color3.fromRGB(186, 222, 245)
	lighting.FogStart = 220
	lighting.FogEnd = 480
	local atmosphere = lighting:FindFirstChild("SparkAtmosphere")
	if not atmosphere then
		local newAtmosphere = Instance.new("Atmosphere")
		newAtmosphere.Name = "SparkAtmosphere"
		newAtmosphere.Density = 0.18
		newAtmosphere.Offset = 0.1
		newAtmosphere.Color = Color3.fromRGB(204, 228, 255)
		newAtmosphere.Decay = Color3.fromRGB(185, 195, 232)
		newAtmosphere.Glare = 0.12
		newAtmosphere.Haze = 0.6
		newAtmosphere.Parent = lighting
	end
	root.Parent = workspace
	return {root = root, arenas = arenas, hub = Vector3.new(0, 3, 62)}
end

function World.creature(def: any, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = def.name
	model:SetAttribute("Species", def.id)
	model:SetAttribute("Silhouette", def.shape)
	local tint = rgb(def.color)
	local light = tint:Lerp(WHITE, 0.52)
	local dark = tint:Lerp(INK, 0.35)
	local shape = def.shape
	local bodySize = if shape == "ribbon" then Vector3.new(2.1, 2.2, 3.3) else Vector3.new(2.8, 2.5, 2.7)
	local body = part(model, "Body", bodySize, CFrame.identity, tint,
		if shape == "cube" or shape == "prism" then Enum.PartType.Block else Enum.PartType.Ball)
	model.PrimaryPart = body
	if shape == "orb" then
		ball(model, "SproutBud", Vector3.new(1.2, 0.7, 0.7), Vector3.new(-0.45, 1.7, 0), light)
		ball(model, "SproutBud", Vector3.new(1.2, 0.7, 0.7), Vector3.new(0.45, 1.7, 0), light)
	elseif shape == "ears" then
		for _, side in ipairs({-1, 1}) do
			local ear = ball(model, "Ear", Vector3.new(0.8, 2.3, 0.8), Vector3.new(side * 0.7, 2, 0), tint)
			ear.CFrame *= CFrame.Angles(0, 0, -side * 0.15)
			ball(model, "EarInset", Vector3.new(0.35, 1.4, 0.25), Vector3.new(side * 0.8, 2, -0.4), light)
		end
	elseif shape == "cube" then
		part(model, "SugarCap", Vector3.new(3, 0.45, 2.9), CFrame.new(0, 1.35, 0), light)
		for _, x in ipairs({-0.6, 0.6}) do
			part(model, "SugarSprinkle", Vector3.new(0.25, 0.22, 1), CFrame.new(x, 1.67, 0) * CFrame.Angles(0, x, 0), GOLD)
		end
	elseif shape == "moth" then
		for _, side in ipairs({-1, 1}) do
			local wing = ball(model, "Wing", Vector3.new(2.9, 2, 0.45), Vector3.new(side * 2, 0.6, 0.5), light)
			wing.CFrame *= CFrame.Angles(0, 0, side * 0.4)
			ball(model, "WingSpot", Vector3.new(0.8, 0.8, 0.3), Vector3.new(side * 2.2, 0.7, 0.22), GOLD)
			beam(model, "Antenna", Vector3.new(side * 0.6, 1, 0), Vector3.new(side, 2, -0.2), 0.16, dark)
			ball(model, "AntennaTip", Vector3.one * 0.4, Vector3.new(side, 2, -0.2), GOLD)
		end
	elseif shape == "shell" then
		ball(model, "Shell", Vector3.new(3.2, 3, 2.4), Vector3.new(0, 0.7, 0.8), dark)
		ball(model, "ShellSwirl", Vector3.new(2, 1.9, 0.4), Vector3.new(0, 0.85, 2), light)
		ball(model, "ShellCenter", Vector3.new(0.9, 0.9, 0.45), Vector3.new(0.2, 0.85, 2.2), tint)
	elseif shape == "comet" then
		for n = 1, 3 do
			local size = 1.7 - n * 0.3
			ball(model, "CometTail", Vector3.new(size, size, 2), Vector3.new(0, n * 0.3, 1.2 + n * 0.9), if n % 2 == 0 then GOLD else light)
		end
	elseif shape == "prism" then
		body.CFrame = CFrame.Angles(0, 0, math.pi / 4)
		part(model, "PrismCrown", Vector3.new(1, 1.6, 1), CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 4), light)
		for _, side in ipairs({-1, 1}) do
			part(model, "PrismSatellite", Vector3.one * 0.75, CFrame.new(side * 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 4), GOLD)
		end
	elseif shape == "fin" then
		for _, side in ipairs({-1, 1}) do
			local fin = ball(model, "Fin", Vector3.new(2.3, 0.5, 1.5), Vector3.new(side * 1.8, -0.2, 0), light)
			fin.CFrame *= CFrame.Angles(0, side * 0.4, side * 0.25)
		end
		part(model, "Dorsal", Vector3.new(0.3, 1.5, 1.8), CFrame.new(0, 1.3, 0.3) * CFrame.Angles(0.3, 0, 0), dark)
	elseif shape == "crown" then
		for n = 1, 5 do
			local x = (n - 3) * 0.5
			local height = if n % 2 == 1 then 1.3 else 0.7
			part(model, "CrownPoint", Vector3.new(0.48, height, 0.6), CFrame.new(x, 1.2 + height / 2, 0), GOLD)
		end
		ball(model, "RoyalRuff", Vector3.new(3.5, 0.7, 3.2), Vector3.new(0, -0.6, 0), light)
	elseif shape == "ribbon" then
		for _, side in ipairs({-1, 1}) do
			local bow = ball(model, "RibbonLoop", Vector3.new(2, 1.5, 0.6), Vector3.new(side * 1.15, 1.3, 0.5), light)
			bow.CFrame *= CFrame.Angles(0, 0, side * 0.4)
			part(model, "RibbonTail", Vector3.new(0.55, 0.15, 2.8), CFrame.new(side * 0.8, 0.8, 2.6) * CFrame.Angles(0.1, side * 0.25, 0), dark)
		end
	elseif shape == "star" then
		for n = 1, 5 do
			local angle = n * TAU / 5
			local point = ball(model, "StarPoint", Vector3.new(0.9, 1.8, 0.9), Vector3.new(math.sin(angle) * 1.5, math.cos(angle) * 1.5, 0), light)
			point.CFrame *= CFrame.Angles(0, 0, -angle)
		end
	elseif shape == "antler" then
		for _, side in ipairs({-1, 1}) do
			beam(model, "Antler", Vector3.new(side * 0.7, 0.8, 0), Vector3.new(side * 1.3, 2.8, 0), 0.28, GOLD)
			beam(model, "AntlerBranch", Vector3.new(side, 1.8, 0), Vector3.new(side * 2, 2.3, 0), 0.22, GOLD)
			ball(model, "AntlerBud", Vector3.one * 0.55, Vector3.new(side * 1.3, 2.8, 0), light)
		end
	end
	-- Identical facial grammar makes the set read as one original collectible family.
	for _, side in ipairs({-1, 1}) do
		ball(model, "EyeWhite", Vector3.new(0.7, 0.85, 0.32), Vector3.new(side * 0.55, 0.2, -1.2), WHITE)
		ball(model, "Pupil", Vector3.new(0.29, 0.43, 0.18), Vector3.new(side * 0.55, 0.18, -1.4), INK)
		ball(model, "EyeGlint", Vector3.one * 0.1, Vector3.new(side * 0.55 - 0.05, 0.29, -1.5), WHITE)
		ball(model, "Cheek", Vector3.new(0.45, 0.2, 0.18), Vector3.new(side * 0.9, -0.35, -1.2), light)
		ball(model, "Foot", Vector3.new(0.8, 0.45, 1.1), Vector3.new(side * 0.65, -1.15, -0.15), dark)
	end
	ball(model, "Smile", Vector3.new(0.35, 0.13, 0.14), Vector3.new(0, -0.35, -1.36), INK)
	-- Root orientation stays forward even when a silhouette has a rotated body.
	local pivot = part(model, "Root", Vector3.one * 0.2, CFrame.identity, tint)
	pivot.Transparency = 1
	model.PrimaryPart = pivot
	model.Parent = parent
	return model
end

return World
