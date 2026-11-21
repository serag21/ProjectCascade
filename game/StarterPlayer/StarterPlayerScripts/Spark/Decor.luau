-- Client-only arena dressing (WP-05): grass tufts, tall grass, flowers, reeds,
-- lily pads and drifting clover leaves; the arena lighting profile (1.5 s
-- tween); windmill sails; and the occluder fade (hedge, canopy, windmill drop
-- to 70 % transparency while they stand between the camera and the player).
-- Nothing here affects gameplay or replicates. Budget: arena parts (server
-- features + workspace.SparkDecor) <= Tuning.performance.arenaPartsVisibleMax.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Decor = {}

-- Part counts per kind (sum 1,300; the server Meadow is ~450 parts).
Decor.COUNTS = {tuft = 760, tallGrass = 220, flower = 240, reed = 64, lily = 8}

local function rgb(v) return Color3.fromRGB(v[1], v[2], v[3]) end
local function rng(seed)
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

local function decorPart(parent, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function sphereMesh(p)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Ground dressing may not cover water, the trail, solids, bank rings or the spawn pad.
local function clearSpot(def, GroundMap, blockers, x, z, margin)
	if not GroundMap.inPolygon(def.bounds, x, z) then return false end
	if GroundMap.polylineDistance(def.bounds, x, z, true) < 3.5 then return false end
	if GroundMap.waterFactor(def, x, z) > 0 then return false end
	local trail = GroundMap.TRAILS[def.id]
	if trail and GroundMap.polylineDistance(trail, x, z, false) < 2.5 then return false end
	for _, b in ipairs(blockers) do
		if (x - b.x) ^ 2 + (z - b.z) ^ 2 < (b.r + margin) ^ 2 then return false end
	end
	for _, ring in ipairs(def.bankRings) do
		if (x - ring.x) ^ 2 + (z - ring.z) ^ 2 < 36 then return false end
	end
	if (x - def.spawn.x) ^ 2 + (z - def.spawn.z) ^ 2 < 16 then return false end
	return true
end

local function blockerCircles(def)
	local out = {}
	for _, f in ipairs(def.features) do
		if f.points and (f.solid or f.creatureBlock) then
			for i = 1, #f.points - 1 do
				local a, b = f.points[i], f.points[i + 1]
				for k = 0, 6 do
					local t = k / 6
					table.insert(out, {x = a[1] + (b[1] - a[1]) * t, z = a[2] + (b[2] - a[2]) * t, r = 1.5})
				end
			end
		elseif f.x and f.solid then
			table.insert(out, {x = f.x, z = f.z, r = f.r or 2})
		elseif f.type == "bounce_ring" or f.type == "prop_bridge" or f.type == "prop_stones" or f.type == "records_board" then
			table.insert(out, {x = f.x, z = f.z, r = (f.r or 3) * 0.9})
		end
	end
	return out
end

-- Builds the decor for one data-driven arena under `folder`. Deterministic.
function Decor.build(folder, def, origin, GroundMap, noYield)
	local r = rng(20261121)
	local blockers = blockerCircles(def)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(def.bounds) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	local function at(x, z, lift) return origin + Vector3.new(x, GroundMap.surface(def, x, z) + lift, z) end
	local function scatter(count, margin, make)
		local made, tries = 0, 0
		while made < count and tries < count * 30 do
			tries += 1
			local x, z = minX + r() * (maxX - minX), minZ + r() * (maxZ - minZ)
			if clearSpot(def, GroundMap, blockers, x, z, margin) then
				make(x, z); made += 1
				if made % 150 == 0 and not noYield then task.wait() end
			end
		end
		return made
	end
	local counts = {}
	local green1, green2 = Color3.fromRGB(84, 190, 126), Color3.fromRGB(150, 232, 150)
	counts.tuft = scatter(Decor.COUNTS.tuft, 0.8, function(x, z)
		local h = 0.8 + r() * 0.9
		decorPart(folder, Vector3.new(0.5, h, 0.7), CFrame.new(at(x, z, h / 2 - 0.1)) * CFrame.Angles(0, r() * math.pi * 2, 0),
			green1:Lerp(green2, r()), Enum.PartType.Wedge)
	end)
	-- Tall grass: waist-high blades (creatures inside show only ears and sprouts).
	for _, f in ipairs(def.features) do
		if f.type == "cover" then
			for _ = 1, Decor.COUNTS.tallGrass do
				local a, d = r() * math.pi * 2, math.sqrt(r()) * f.r
				local x, z = f.x + math.cos(a) * d, f.z + math.sin(a) * d
				local h = 2.8 + r() * 1.4
				decorPart(folder, Vector3.new(0.6, h, 0.9),
					CFrame.new(at(x, z, h / 2 - 0.2)) * CFrame.Angles((r() - 0.5) * 0.3, r() * math.pi * 2, (r() - 0.5) * 0.3),
					Color3.fromRGB(70, 176, 118):Lerp(Color3.fromRGB(140, 226, 140), r()), Enum.PartType.Wedge)
			end
			counts.tallGrass = Decor.COUNTS.tallGrass
		end
	end
	local flowerColors = {Color3.fromRGB(255, 249, 231), rgb(def.palette.accent), rgb(def.palette.accent2), Color3.fromRGB(200, 170, 255)}
	local made = 0
	counts.flower = scatter(Decor.COUNTS.flower, 1, function(x, z)
		made += 1
		sphereMesh(decorPart(folder, Vector3.new(0.75, 0.45, 0.75), CFrame.new(at(x, z, 0.35)), flowerColors[made % 4 + 1]))
	end)
	-- Reeds along the creek banks and lily pads on the pond.
	counts.reed, counts.lily = 0, 0
	for _, f in ipairs(def.features) do
		if f.type == "water_band" then
			local pts = f.points
			local per = math.ceil(Decor.COUNTS.reed / (#pts - 1))
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local dx, dz = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dz * dz)
				for k = 1, per do
					if counts.reed >= Decor.COUNTS.reed then break end
					local t = (k - 0.5) / per
					local side = if k % 2 == 0 then 1 else -1
					local off = (f.width or 6) / 2 + 0.8 + r() * 0.8
					local x = a[1] + dx * t - dz / len * off * side
					local z = a[2] + dz * t + dx / len * off * side
					local h = 2.2 + r() * 1.2
					decorPart(folder, Vector3.new(0.3, h, 0.3), CFrame.new(at(x, z, h / 2 - 0.2)) * CFrame.Angles((r() - 0.5) * 0.25, 0, (r() - 0.5) * 0.25),
						Color3.fromRGB(96, 170, 110))
					counts.reed += 1
				end
			end
		elseif f.type == "water" and f.rx then
			for _ = 1, Decor.COUNTS.lily do
				local a, d = r() * math.pi * 2, 0.2 + r() * 0.6
				local x, z = f.x + math.cos(a) * f.rx * d, f.z + math.sin(a) * f.rz * d
				local pad = decorPart(folder, Vector3.new(0.12, 2.6, 2.6),
					CFrame.new(origin + Vector3.new(x, GroundMap.WATER_LEVEL + 0.06, z)) * CFrame.Angles(0, r() * 3, math.pi / 2),
					Color3.fromRGB(120, 214, 130), Enum.PartType.Cylinder)
				pad.Name = "LilyPad"
				counts.lily += 1
			end
		end
	end
	return counts
end

-- Falling clover leaves from the landmark tree canopy (an emitter, not parts).
function Decor.leaves(arenaModel, reducedMotion)
	local tree = arenaModel:FindFirstChild("clover_tree")
	local heart = tree and tree:FindFirstChild("CanopyHeart")
	if not heart then return nil end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SparkLeaves"
	attachment.Parent = heart
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Leaves"
	emitter.Rate = if reducedMotion then 0.7 else 2
	emitter.Lifetime = NumberRange.new(7, 10)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0.6, -1.4, 0)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Size = NumberSequence.new(0.9)
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 240, 160))
	emitter.LightEmission = 0.1
	emitter.Parent = attachment
	return emitter
end

-- Lighting profile from arenas/<id>.json, tweened over 1.5 s.
function Decor.applyLighting(def, seconds)
	local look = def.lighting
	if not look then return end
	local info = TweenInfo.new(seconds or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, {
		ClockTime = look.clockTime, Brightness = look.brightness,
		Ambient = rgb(look.ambient), OutdoorAmbient = rgb(look.outdoorAmbient),
		ColorShift_Top = rgb(look.colorShiftTop or {0, 0, 0}),
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "SparkAtmosphere"
		atmosphere.Parent = Lighting
	end
	if look.atmosphere then
		TweenService:Create(atmosphere, info, {Density = look.atmosphere.density, Color = rgb(look.atmosphere.color),
			Decay = rgb(look.atmosphere.decay), Haze = look.atmosphere.haze, Glare = look.atmosphere.glare}):Play()
	end
	local bloom = Lighting:FindFirstChild("SparkBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SparkBloom"
		bloom.Parent = Lighting
	end
	if look.bloom then
		TweenService:Create(bloom, info, {Intensity = look.bloom.intensity, Size = look.bloom.size, Threshold = look.bloom.threshold}):Play()
	end
end

-- Segment vs oriented box (slab test in the part's local space).
local function segmentHitsPart(p, a, b)
	local cf = p.CFrame
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local half = p.Size / 2 + Vector3.new(0.4, 0.4, 0.4)
	local t0, t1 = 0, 1
	local d = lb - la
	for _, axis in ipairs({"X", "Y", "Z"}) do
		local s, e, h = la[axis], d[axis], half[axis]
		if math.abs(e) < 1e-6 then
			if s < -h or s > h then return false end
		else
			local u1, u2 = (-h - s) / e, (h - s) / e
			if u1 > u2 then u1, u2 = u2, u1 end
			t0, t1 = math.max(t0, u1), math.min(t1, u2)
			if t0 > t1 then return false end
		end
	end
	return true
end
Decor.segmentHitsPart = segmentHitsPart

-- Occluder fade: visible parts of features flagged Occluder fade to 70 %
-- transparency while they cut the camera-to-player line.
function Decor.occluders(arenaModel)
	local list = {}
	for _, feature in ipairs(arenaModel:GetChildren()) do
		if feature:GetAttribute("Occluder") then
			for _, item in ipairs(feature:GetDescendants()) do
				if item:IsA("BasePart") and item.Transparency < 1 then table.insert(list, item) end
			end
		end
	end
	return list
end

function Decor.fadeStep(list, faded, cameraPos, targetPos)
	for _, p in ipairs(list) do
		local hit = segmentHitsPart(p, cameraPos, targetPos)
		if hit and not faded[p] then
			faded[p] = true; p.LocalTransparencyModifier = 0.7
		elseif not hit and faded[p] then
			faded[p] = nil; p.LocalTransparencyModifier = 0
		end
	end
end

-- Start everything for the local player. `getPhase` returns the HUD phase name.
function Decor.start(options)
	local def, origin, GroundMap = options.def, options.origin, options.GroundMap
	local arenaModel = options.arenaModel
	local folder = workspace:FindFirstChild("SparkDecor") or Instance.new("Folder")
	folder.Name = "SparkDecor"
	folder.Parent = workspace
	local state = {folder = folder, counts = Decor.build(folder, def, origin, GroundMap)}
	Decor.applyLighting(def, 1.5)
	state.leaves = Decor.leaves(arenaModel, options.reducedMotion)
	local windmill = arenaModel:FindFirstChild("windmill")
	local sails = windmill and windmill:FindFirstChild("Sails")
	local sailPivot = sails and sails:GetPivot()
	local occluders = Decor.occluders(arenaModel)
	local faded = {}
	local angle, fadeAt = 0, 0
	state.connection = RunService.RenderStepped:Connect(function(dt)
		if sails and sailPivot then
			local fast = options.getPhase and options.getPhase() == "STAMPEDE"
			angle += dt * (if fast then 1.6 else 0.63) -- 6 rpm, faster during STAMPEDE
			sails:PivotTo(sailPivot * CFrame.Angles(0, 0, angle))
		end
		fadeAt += dt
		if fadeAt >= 0.1 then
			fadeAt = 0
			local camera = workspace.CurrentCamera
			local target = options.getTarget and options.getTarget()
			if camera and target then Decor.fadeStep(occluders, faded, camera.CFrame.Position, target) end
		end
	end)
	return state
end

-- Visible arena parts for the F8 overlay: arena model + SparkDecor.
function Decor.countParts(arenaModel)
	local count = 0
	for _, root in ipairs({arenaModel, workspace:FindFirstChild("SparkDecor")}) do
		if root then
			for _, item in ipairs(root:GetDescendants()) do
				if item:IsA("BasePart") and item.Transparency < 1 then count += 1 end
			end
		end
	end
	return count
end

return Decor
