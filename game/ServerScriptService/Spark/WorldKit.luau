-- Data-driven arena builders (WP-05). One builder per feature type in
-- design/fable/data/asset_manifest.json (featureBuilders), driven by
-- Design.Arenas. Positions are arena-relative; ground comes from the same
-- GroundMap.surface the Terrain is carved from. Solid features get collision
-- parts named "<featureId>_Col". Client-only dressing (grass, flowers, reeds,
-- lily pads, leaves, lighting) lives in C/Decor.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Spark")
local GroundMap = require(Shared:WaitForChild("GroundMap"))

local WorldKit = {}

local WHITE = Color3.fromRGB(255, 249, 231)
local INK = Color3.fromRGB(27, 36, 64)
local GOLD = Color3.fromRGB(255, 217, 90)
local TAU = math.pi * 2

local function rgb(v) return Color3.fromRGB(v[1], v[2], v[3]) end

-- A deterministic generator so every server builds the identical arena.
local function rng(seed)
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
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
WorldKit.part = part

-- Ellipsoids are a Part with a SpecialMesh of type Sphere sized to the part.
local function ellipsoid(parent, name, size, cf, color, material)
	local p = part(parent, name, size, cf, color, material, false)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
WorldKit.ellipsoid = ellipsoid

-- Upright cylinder (Roblox cylinders run along X; rotate onto Y).
local function column(parent, name, diameter, height, base, color, material, collide)
	local p = part(parent, name, Vector3.new(height, diameter, diameter),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end
WorldKit.column = column

-- Invisible collision that matches a visible solid (never an unexplained wall).
local function collider(parent, featureId, size, cf, cylinder)
	local p = part(parent, featureId .. "_Col", size, cf, WHITE, nil, true)
	p.Transparency = 1
	p.CastShadow = false
	if cylinder then p.Shape = Enum.PartType.Cylinder end
	return p
end

local function ground(def, origin, x, z)
	return origin + Vector3.new(x, GroundMap.surface(def, x, z), z)
end

local function featureModel(arenaModel, f)
	local model = Instance.new("Model")
	model.Name = f.id
	model:SetAttribute("FeatureType", f.type)
	model:SetAttribute("Solid", f.solid == true)
	model:SetAttribute("CreatureBlock", f.creatureBlock == true or f.solid == true)
	model:SetAttribute("Pinch", f.pinch == true)
	model.Parent = arenaModel
	return model
end

---------------------------------------------------------------- builders
local B = {}

B.landmark_tree = function(m, f, def, origin, pal)
	local base = ground(def, origin, f.x, f.z)
	local trunk = Color3.fromRGB(156, 108, 92)
	local r = f.r or 5
	column(m, "Trunk", r * 1.1, 14, base, trunk, Enum.Material.Wood)
	column(m, "TrunkMid", r * 0.78, 12, base + Vector3.new(0.3, 14, 0), trunk, Enum.Material.Wood)
	column(m, "TrunkTop", r * 0.55, 6, base + Vector3.new(0.6, 26, 0), trunk, Enum.Material.Wood)
	collider(m, f.id, Vector3.new(30, r * 1.6, r * 1.6),
		CFrame.new(base + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2), true)
	local leafLow, leafHigh = rgb(pal.ground):Lerp(Color3.fromRGB(104, 214, 138), 0.5), Color3.fromRGB(150, 240, 160)
	for tier = 0, 1 do
		for k = 0, 3 do
			local a = k * math.pi / 2 + tier * math.pi / 4
			local reach = if tier == 1 then 6.5 else 10.5
			local y = if tier == 1 then 37 else 30
			local size = if tier == 1 then Vector3.new(8, 4.2, 8) else Vector3.new(12.5, 5.6, 12.5)
			local side = if tier == 1 then 2.2 else 3.4
			for _, s in ipairs({-1, 1}) do
				local p = base + Vector3.new(math.cos(a) * reach + math.cos(a + math.pi / 2) * s * side, y,
					math.sin(a) * reach + math.sin(a + math.pi / 2) * s * side)
				ellipsoid(m, "Leaf", size, CFrame.new(p), if tier == 1 then leafHigh else leafLow)
			end
			-- Heart point: a wedge under each lobe pair.
			local tip = base + Vector3.new(math.cos(a) * (reach + 4), y - 1, math.sin(a) * (reach + 4))
			local w = part(m, "LeafTip", Vector3.new(if tier == 1 then 6 else 9, 2, 4),
				CFrame.lookAt(tip, base + Vector3.new(0, y - 1, 0)), if tier == 1 then leafHigh else leafLow)
			w.Shape = Enum.PartType.Wedge
		end
	end
	ellipsoid(m, "CanopyHeart", Vector3.new(13, 6, 13), CFrame.new(base + Vector3.new(0, 31, 0)), Color3.fromRGB(120, 226, 150))
	for k = 0, 4 do
		local a = k * 1.26
		local reach = 6 + (k % 3) * 3.5
		ellipsoid(m, "GlowBud", Vector3.new(1.1, 1.3, 1.1),
			CFrame.new(base + Vector3.new(math.cos(a) * reach, 25.5 - (k % 2), math.sin(a) * reach)), GOLD, Enum.Material.Neon)
	end
	m:SetAttribute("Occluder", true)
end

B.landmark_windmill = function(m, f, def, origin, _pal)
	local base = ground(def, origin, f.x, f.z)
	local cream = Color3.fromRGB(255, 244, 222)
	column(m, "Tower1", 10, 7, base, cream, Enum.Material.SmoothPlastic)
	column(m, "Tower2", 8.8, 7, base + Vector3.new(0, 7, 0), cream)
	column(m, "Tower3", 7.6, 7, base + Vector3.new(0, 14, 0), cream)
	column(m, "Tower4", 6.4, 5, base + Vector3.new(0, 21, 0), cream)
	ellipsoid(m, "Cap", Vector3.new(8.4, 7, 8.4), CFrame.new(base + Vector3.new(0, 27.5, 0)), Color3.fromRGB(255, 150, 186))
	part(m, "Door", Vector3.new(2.6, 5, 0.6), CFrame.new(base + Vector3.new(0, 2.5, 4.9)), Color3.fromRGB(150, 104, 84))
	collider(m, f.id, Vector3.new(28, 10, 10), CFrame.new(base + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.pi / 2), true)
	-- Sails: a client-animated sub-model (Decor spins it; 6 rpm, faster in STAMPEDE).
	local sails = Instance.new("Model")
	sails.Name = "Sails"
	sails.Parent = m
	local hubPos = base + Vector3.new(-2.2, 24, 3.4)
	local facing = CFrame.lookAt(hubPos, hubPos + Vector3.new(-math.sin(0.55), 0, math.cos(0.55)))
	local hub = ellipsoid(sails, "Hub", Vector3.new(2, 2, 2), facing, GOLD)
	sails.PrimaryPart = hub
	local cloths = {{255, 214, 72}, {150, 232, 220}, {255, 150, 186}, {255, 249, 231}}
	for k = 0, 3 do
		local spin = facing * CFrame.Angles(0, 0, k * math.pi / 2 + 0.5)
		part(sails, "SailFrame", Vector3.new(0.6, 15, 0.5), spin * CFrame.new(0, 7.5, 0), Color3.fromRGB(150, 104, 84))
		part(sails, "SailCloth", Vector3.new(3.4, 10, 0.25), spin * CFrame.new(1.9, 9, 0), rgb(cloths[k + 1]))
	end
	m:SetAttribute("Occluder", true)
end

B.water = function(m, f, def, origin, _pal)
	-- Terrain water (carved by WorldKit.carveTerrain); 12 pebbles ring the bank.
	local r = rng(31)
	for k = 1, 12 do
		local a = k * TAU / 12 + r() * 0.2
		local x, z = f.x + math.cos(a) * (f.rx + 1.6), f.z + math.sin(a) * (f.rz + 1.6)
		local p = ground(def, origin, x, z)
		ellipsoid(m, "Pebble", Vector3.new(1.4 + r(), 0.7, 1.2 + r()), CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, r() * TAU, 0),
			Color3.fromRGB(214, 206, 196))
	end
	m:SetAttribute("WaterLevel", GroundMap.WATER_LEVEL)
end

B.water_band = function(m, _f, _def, _origin, _pal)
	m:SetAttribute("WaterLevel", GroundMap.WATER_LEVEL)
end

B.prop_bridge = function(m, f, def, origin, _pal)
	local y = math.max(GroundMap.surface(def, f.x, f.z - 5), GroundMap.surface(def, f.x, f.z + 5))
	local center = origin + Vector3.new(f.x, y + 0.3, f.z)
	local log = part(m, "Log", Vector3.new(12, 2.4, 2.4), CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0.1, 0, 0),
		Color3.fromRGB(150, 104, 84), Enum.Material.Wood, true)
	log.Shape = Enum.PartType.Cylinder
	for _, s in ipairs({-1, 1}) do
		local cap = part(m, "LogEnd", Vector3.new(0.3, 2.2, 2.2), CFrame.new(center + Vector3.new(0, 0, s * 6)) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(214, 176, 130))
		cap.Shape = Enum.PartType.Cylinder
		ellipsoid(m, "Moss", Vector3.new(1.8, 0.6, 2.4), CFrame.new(center + Vector3.new(0.4 * s, 1.1, s * 2.5)), Color3.fromRGB(112, 196, 126))
	end
end

B.prop_stones = function(m, f, def, origin, _pal)
	for k = -2, 2 do
		local x, z = f.x + k * 0.4, f.z + k * 1.7
		local base = origin + Vector3.new(x, math.max(GroundMap.WATER_LEVEL, GroundMap.surface(def, x, z)), z)
		column(m, "Stone", 2.4, 0.6, base - Vector3.new(0, 0.1, 0), Color3.fromRGB(214, 206, 196), Enum.Material.Slate, true)
	end
end

B.bounce_ring = function(m, f, def, origin, pal)
	for k = 0, 4 do
		local a = k * TAU / 5
		local x, z = f.x + math.cos(a) * 6.5, f.z + math.sin(a) * 6.5
		local base = ground(def, origin, x, z)
		column(m, "Stem", 2.2, 3, base, WHITE, nil, true)
		local cap = ellipsoid(m, "BounceCap", Vector3.new(5, 2.4, 5), CFrame.new(base + Vector3.new(0, 3.6, 0)),
			if k % 2 == 1 then rgb(pal.accent2) else Color3.fromRGB(255, 120, 110))
		cap.CanCollide = true; cap.CanQuery = true
		cap:SetAttribute("BounceHeight", 22)
		for d = 0, 1 do
			local da = a + d * 2.2
			ellipsoid(m, "Dot", Vector3.new(0.9, 0.3, 0.9),
				CFrame.new(base + Vector3.new(math.cos(da) * 1.4, 4.65, math.sin(da) * 1.4)), WHITE)
		end
	end
end

B.wall_u = function(m, f, def, origin, pal)
	local r = rng(#f.id * 97)
	local stone = rgb(pal.wall)
	local pts = f.points
	for i = 1, #pts - 1 do
		local a, b = Vector3.new(pts[i][1], 0, pts[i][2]), Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local n = 6
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = a + (b - a) * t
			local y = GroundMap.surface(def, p.X, p.Z)
			part(m, "Stone", Vector3.new(length / n + 0.25, 4.6 + r() * 0.5, 2.1 + r() * 0.3),
				CFrame.lookAt(origin + Vector3.new(p.X, y + 2.3, p.Z), origin + Vector3.new(p.X, y + 2.3, p.Z) + Vector3.new(-dir.Z, 0, dir.X))
					* CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, (r() - 0.5) * 0.08, 0),
				stone:Lerp(Color3.fromRGB(186, 172, 160), r() * 0.8), Enum.Material.Slate)
		end
		local mid = (a + b) / 2
		local y = GroundMap.surface(def, mid.X, mid.Z)
		local cf = CFrame.lookAt(origin + Vector3.new(mid.X, y + (f.h or 5) / 2, mid.Z), origin + Vector3.new(b.X, y + (f.h or 5) / 2, b.Z))
		part(m, "MossCap", Vector3.new(2.5, 0.5, length + 0.6), cf * CFrame.new(0, (f.h or 5) / 2, 0), Color3.fromRGB(112, 196, 126))
		collider(m, f.id, Vector3.new(2.4, f.h or 5, length + 1.2), cf)
	end
end

B.cover = function(m, f, _def, _origin, _pal)
	-- Client decor (C/Decor.luau) draws the tall grass; the server only names the area.
	m:SetAttribute("Radius", f.r)
end

B.bloom_bud = function(m, f, def, origin, _pal)
	local base = ground(def, origin, f.x, f.z)
	column(m, "Stem", 1.6, 3, base, Color3.fromRGB(86, 176, 120))
	collider(m, f.id, Vector3.new(f.h or 9, (f.r or 3) * 2, (f.r or 3) * 2),
		CFrame.new(base + Vector3.new(0, (f.h or 9) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), true)
	local core = ellipsoid(m, "Core", Vector3.new(2.4, 3, 2.4), CFrame.new(base + Vector3.new(0, 6, 0)), GOLD, Enum.Material.Neon)
	core:SetAttribute("BaseY", 6)
	for k = 0, 5 do
		local a = k * TAU / 6
		local petal = ellipsoid(m, "Petal", Vector3.new(2.8, 7, 2.6),
			CFrame.new(base + Vector3.new(math.cos(a) * 2.1, 5.6, math.sin(a) * 2.1)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 0.12),
			Color3.fromRGB(255, 160, 196))
		petal:SetAttribute("Angle", a)
	end
	m:SetAttribute("Base", base)
	m:SetAttribute("Occluder", false)
end

B.perch_flower = function(m, f, def, origin, _pal)
	local base = ground(def, origin, f.x, f.z)
	local h = f.h or 6
	column(m, "Stem", 0.5, h, base, Color3.fromRGB(86, 176, 120))
	for k = 0, 3 do
		local a = k * TAU / 4 + 0.4
		ellipsoid(m, "Petal", Vector3.new(1.9, 0.5, 1.9), CFrame.new(base + Vector3.new(math.cos(a) * 1.3, h + 0.1, math.sin(a) * 1.3)),
			if k % 2 == 1 then WHITE else Color3.fromRGB(255, 200, 222))
	end
	local glow = ellipsoid(m, "PerchGlow", Vector3.new(1.3, 0.7, 1.3), CFrame.new(base + Vector3.new(0, h + 0.3, 0)), GOLD, Enum.Material.Neon)
	glow.Transparency = 0.15
end

B.records_board = function(m, f, def, origin, pal)
	local base = ground(def, origin, f.x, f.z)
	local at = base + Vector3.new(0, 6, 0)
	local board = part(m, "RecordsBoard", Vector3.new(12, 8, 0.6), CFrame.lookAt(at, at + Vector3.new(0.35, 0, -1)), INK)
	part(m, "RecordsBoardTrim", Vector3.new(12.6, 0.4, 0.7), board.CFrame * CFrame.new(0, 4.1, 0), rgb(pal.accent), Enum.Material.Neon)
	part(m, "RecordsBoardPost", Vector3.new(0.8, 2.2, 0.8), CFrame.new(base + Vector3.new(0, 1.1, 0)), WHITE)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Records"; surface.Face = Enum.NormalId.Front; surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40; surface.LightInfluence = 0; surface.MaxDistance = 140; surface.Parent = board
	for row = 0, 7 do
		local label = Instance.new("TextLabel")
		label.Name = if row == 0 then "Heading" else "Row" .. row
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, 0.04 + row * 0.115)
		label.Size = UDim2.fromScale(0.9, if row == 0 then 0.14 else 0.1)
		label.Font = if row == 0 then Enum.Font.GothamBlack else Enum.Font.GothamMedium
		label.TextScaled = true
		label.TextColor3 = if row == 0 then rgb(pal.accent):Lerp(WHITE, 0.4) else WHITE
		label.TextXAlignment = if row == 0 then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		label.Text = if row == 0 then "POP MEADOW RECORDS" elseif row == 1 then "Finish a round to set the first record!" else ""
		label.Parent = surface
	end
	return surface
end

-- Upright bank ring: 12 segments (inner diameter 10) on two posts, facing +z.
function WorldKit.bankRing(parent, ring, def, origin, pal)
	local m = Instance.new("Model")
	m.Name = ring.id
	m:SetAttribute("FeatureType", "bank_ring")
	m:SetAttribute("Radius", ring.r)
	m.Parent = parent
	local base = ground(def, origin, ring.x, ring.z)
	local center = base + Vector3.new(0, 6.2, 0)
	local radius = (ring.r or 5) + 0.55
	local segment = 2 * radius * math.sin(math.pi / 12) + 0.3
	for k = 0, 11 do
		local a = k * TAU / 12
		local cf = CFrame.new(center + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)) * CFrame.Angles(0, 0, a + math.pi / 2)
		part(m, "RingSegment", Vector3.new(segment, 1.1, 1.1), cf, if k % 2 == 0 then GOLD else rgb(pal.accent):Lerp(WHITE, 0.3),
			if k % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	end
	for _, s in ipairs({-1, 1}) do
		column(m, "Post", 1.4, 2.4, base + Vector3.new(s * 3.4, 0, 0), WHITE)
	end
	local label = Instance.new("BillboardGui")
	label.Name = "BankLabel"; label.Size = UDim2.fromOffset(120, 30); label.StudsOffsetWorldSpace = Vector3.new(0, radius + 2.4, 0)
	label.MaxDistance = 120; label.LightInfluence = 0
	label.Parent = m:FindFirstChild("RingSegment")
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1); text.BackgroundTransparency = 1; text.Font = Enum.Font.GothamBlack
	text.TextScaled = true; text.Text = "BANK"; text.TextColor3 = GOLD; text.TextStrokeColor3 = INK; text.TextStrokeTransparency = 0.2
	text.Parent = label
	return m, center
end

-- 3.5-stud flowering hedge along the bounds ring, with one collision slab per edge.
-- The slab is taller than the hedge so a jump can't leave the arena; the hedge
-- itself is the visible boundary (no unexplained invisible wall in open ground).
function WorldKit.hedge(parent, def, origin, pal)
	local m = Instance.new("Model")
	m.Name = "boundary_hedge"
	m:SetAttribute("FeatureType", "boundary")
	m:SetAttribute("Occluder", true)
	m:SetAttribute("Pinch", true)
	m.Parent = parent
	local r = rng(5)
	local poly = def.bounds
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		local pa, pb = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local length = (pb - pa).Magnitude
		local n = math.ceil(length / 7)
		for k = 0, n - 1 do
			local p = pa + (pb - pa) * ((k + 0.5) / n)
			local y = GroundMap.surface(def, p.X, p.Z)
			local h = 3.5 + r() * 0.6
			ellipsoid(m, "Hedge", Vector3.new(length / n + 2.2, h, 5.2),
				CFrame.lookAt(origin + Vector3.new(p.X, y + h / 2 - 0.3, p.Z), origin + Vector3.new(pb.X, y + h / 2 - 0.3, pb.Z)) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(52, 150, 100):Lerp(Color3.fromRGB(80, 184, 116), r()))
			if k % 2 == 0 then
				ellipsoid(m, "Blossom", Vector3.new(0.9, 0.9, 0.9), CFrame.new(origin + Vector3.new(p.X + (r() - 0.5) * 3, y + h, p.Z + (r() - 0.5) * 2)),
					if r() < 0.5 then rgb(pal.accent2) else WHITE)
			end
		end
		local mid = (pa + pb) / 2
		local y = GroundMap.surface(def, mid.X, mid.Z)
		collider(m, "boundary", Vector3.new(2, 14, length + 2),
			CFrame.lookAt(origin + Vector3.new(mid.X, y + 6, mid.Z), origin + Vector3.new(pb.X, y + 6, pb.Z)))
	end
	return m
end

---------------------------------------------------------------- terrain
local MAT_GRASS = Enum.Material.Grass
local MAT_RIM = Enum.Material.LeafyGrass
local MAT_SAND = Enum.Material.Sand
local MAT_WATERBED = Enum.Material.Mud

-- Carves the arena's ground, hills, water basins, trail and rim into Terrain from
-- GroundMap.surface. Clears only the arena's own region first. Yields every
-- `yieldEvery` operations so server start stays responsive.
function WorldKit.carveTerrain(terrain, def, origin, palette, yieldEvery)
	yieldEvery = yieldEvery or 250
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(def.bounds) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	local cell = GroundMap.CELL
	minX, maxX = math.floor((minX - 24) / cell) * cell, math.ceil((maxX + 24) / cell) * cell
	minZ, maxZ = math.floor((minZ - 24) / cell) * cell, math.ceil((maxZ + 24) / cell) * cell
	local width, depth = maxX - minX, maxZ - minZ
	local center = origin + Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	local ops = 0
	local function tick()
		ops += 1
		if ops % yieldEvery == 0 then task.wait() end
	end
	terrain:FillBlock(CFrame.new(center + Vector3.new(0, 8, 0)), Vector3.new(width, 44, depth), Enum.Material.Air); tick()
	terrain:FillBlock(CFrame.new(center + Vector3.new(0, -7, 0)), Vector3.new(width, 12, depth), MAT_GRASS); tick()
	pcall(function()
		terrain:SetMaterialColor(MAT_GRASS, rgb(palette.ground))
		terrain:SetMaterialColor(MAT_RIM, rgb(palette.groundDark))
		terrain:SetMaterialColor(MAT_SAND, rgb(palette.path))
		terrain.WaterColor = rgb(palette.water)
		terrain.WaterTransparency = 0.35
		terrain.WaterWaveSize = 0.05
	end)
	local trail = GroundMap.TRAILS[def.id]
	for x = minX, maxX - cell, cell do
		for z = minZ, maxZ - cell, cell do
			local cx, cz = x + cell / 2, z + cell / 2
			local h = GroundMap.surface(def, cx, cz)
			local water = GroundMap.waterFactor(def, cx, cz)
			local inside = GroundMap.inPolygon(def.bounds, cx, cz)
			local material = MAT_GRASS
			if not inside then material = MAT_RIM
			elseif water > 0 and water < 1 then material = MAT_SAND
			elseif water >= 1 then material = MAT_WATERBED
			elseif trail and GroundMap.polylineDistance(trail, cx, cz, false) < 3 then material = MAT_SAND end
			if math.abs(h) > 0.05 or material ~= MAT_GRASS then
				local bottom = -13
				local top = math.max(h, bottom + 1)
				if h < 0 then
					terrain:FillBlock(CFrame.new(origin + Vector3.new(cx, h / 2 - 0.0, cz)), Vector3.new(cell, -h + 0.02, cell), Enum.Material.Air); tick()
				end
				terrain:FillBlock(CFrame.new(origin + Vector3.new(cx, (bottom + top) / 2, cz)), Vector3.new(cell, top - bottom, cell), material); tick()
				if h < GroundMap.WATER_LEVEL then
					local wTop = GroundMap.WATER_LEVEL
					terrain:FillBlock(CFrame.new(origin + Vector3.new(cx, (h + wTop) / 2, cz)), Vector3.new(cell, wTop - h, cell), Enum.Material.Water); tick()
				end
			end
		end
	end
	return ops
end

-- Parts-only fallback (tuning.features.worldPartsOnly): one ground slab, stacked
-- hill tiers and translucent water sheets. Same layout; coarser silhouettes.
function WorldKit.partsGround(parent, def, origin, palette)
	local m = Instance.new("Model")
	m.Name = "GroundParts"
	m.Parent = parent
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(def.bounds) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	part(m, "GroundSlab", Vector3.new(maxX - minX + 40, 4, maxZ - minZ + 40),
		CFrame.new(origin + Vector3.new((minX + maxX) / 2, -2, (minZ + maxZ) / 2)), rgb(palette.ground), Enum.Material.Grass, true)
	for _, e in ipairs(def.elevation or {}) do
		for tier = 1, 3 do
			local frac = tier / 3
			local diameter = e.r * 2 * (1 - frac * 0.62)
			column(m, "HillTier", diameter, e.y * frac, origin + Vector3.new(e.x, 0, e.z), rgb(palette.ground):Lerp(INK, 0.04 * tier),
				Enum.Material.Grass, true)
		end
	end
	for _, f in ipairs(def.features) do
		if f.type == "water" then
			local sheet = column(m, "WaterSheet", 2, 0.2, origin + Vector3.new(f.x, -0.15, f.z), rgb(palette.water), Enum.Material.Glass)
			sheet.Size = Vector3.new(0.2, f.rz * 2, f.rx * 2)
			sheet.Transparency = 0.25
		elseif f.type == "water_band" then
			for i = 1, #f.points - 1 do
				local a, b = Vector3.new(f.points[i][1], 0, f.points[i][2]), Vector3.new(f.points[i + 1][1], 0, f.points[i + 1][2])
				local sheet = part(m, "WaterSheet", Vector3.new(f.width or 6, 0.2, (b - a).Magnitude + 1),
					CFrame.lookAt(origin + (a + b) / 2 + Vector3.new(0, 0.05, 0), origin + b + Vector3.new(0, 0.05, 0)), rgb(palette.water), Enum.Material.Glass)
				sheet.Transparency = 0.25
			end
		end
	end
	return m
end

---------------------------------------------------------------- arena
-- Circle approximations of creature blockers, for any legacy steering code.
local function blockerCircles(def)
	local out = {}
	for _, f in ipairs(def.features) do
		if f.solid or f.creatureBlock then
			if f.points then
				for i = 1, #f.points - 1 do
					local a, b = f.points[i], f.points[i + 1]
					local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
					local n = math.max(1, math.ceil(length / 4))
					for k = 0, n do
						local t = k / n
						table.insert(out, {x = a[1] + (b[1] - a[1]) * t, z = a[2] + (b[2] - a[2]) * t, r = (f.width or 2) / 2, id = f.id})
					end
				end
			elseif f.rx then
				table.insert(out, {x = f.x, z = f.z, r = math.max(f.rx, f.rz), id = f.id})
			else
				table.insert(out, {x = f.x, z = f.z, r = f.r or 2, id = f.id})
			end
		end
	end
	return out
end
WorldKit.blockerCircles = blockerCircles

-- Builds one data-driven arena. Returns the World arena entry.
function WorldKit.buildArena(parent, def, index, origin, options)
	options = options or {}
	local arena = Instance.new("Model")
	arena.Name = def.id
	arena:SetAttribute("BiomeIndex", index)
	arena:SetAttribute("DataDriven", true)
	arena.Parent = parent
	local pal = def.palette
	local terrainOps = 0
	if options.partsOnly or not options.terrain then
		WorldKit.partsGround(arena, def, origin, pal)
		arena:SetAttribute("Ground", "parts")
	else
		terrainOps = WorldKit.carveTerrain(options.terrain, def, origin, pal)
		arena:SetAttribute("Ground", "terrain")
	end
	local records
	for n, f in ipairs(def.features) do
		local builder = B[f.type]
		local m = featureModel(arena, f)
		if builder then
			local result = builder(m, f, def, origin, pal)
			if f.type == "records_board" then records = result end
		else
			m:SetAttribute("Unbuilt", true)
		end
		if n % 4 == 0 then task.wait() end
	end
	local bankRings = {}
	for _, ring in ipairs(def.bankRings) do
		local _, center = WorldKit.bankRing(arena, ring, def, origin, pal)
		table.insert(bankRings, {id = ring.id, x = ring.x, z = ring.z, r = ring.r, position = center})
	end
	WorldKit.hedge(arena, def, origin, pal)
	local spawnGround = GroundMap.surface(def, def.spawn.x, def.spawn.z)
	local pad = column(arena, "SpawnPad", 6, 0.3, origin + Vector3.new(def.spawn.x, spawnGround - 0.05, def.spawn.z), WHITE)
	pad.CastShadow = false
	local facing = if def.spawn.facing == "north" then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
	local spawn = origin + Vector3.new(def.spawn.x, spawnGround + 3, def.spawn.z)
	return {
		origin = origin, spawn = spawn, spawnLook = spawn + facing * 10,
		bank = bankRings[1] and (origin + Vector3.new(bankRings[1].x, 0, bankRings[1].z)) or spawn,
		bankRings = bankRings, radius = 120, records = records, obstacles = blockerCircles(def),
		layout = 0, def = def, bounds = def.bounds, dataDriven = true, maxYOffset = 48, model = arena,
		terrainOps = terrainOps,
	}
end

return WorldKit
