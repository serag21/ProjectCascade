--!nocheck
-- WP-05 (SparkWorldData): the Meadow is built from design/fable/data/arenas/meadow.json.
-- Every feature exists under its id, solids have collision named <id>_Col, both
-- bank rings stand at their coordinates, Terrain is carved (no ArenaFloor disc),
-- and arena parts + client decor stay within Tuning.performance.arenaPartsVisibleMax.
-- GroundMap is checked against the analytic surface here; real raycasts are a
-- Studio-only check (World.verifyGround) because the fake engine has no geometry.
local Harness = require("./Harness")
local Sources = require("./Sources")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
h:assertClean("boot")
local function load(path) return e.requireSource(path) end
local Arenas = load("ReplicatedStorage/Spark/Design/Arenas.luau")
local Tuning = load("ReplicatedStorage/Spark/Design/Tuning.luau")
local GroundMap = load("ReplicatedStorage/Spark/GroundMap.luau")
local def = Arenas.meadow
local meadow = h.world:FindFirstChild("meadow")
check(meadow ~= nil and meadow:GetAttribute("DataDriven") == true, "Meadow is data-driven")
check(meadow:GetAttribute("Ground") == "terrain", "Meadow ground is Terrain by default")
check(e.terrainOps.count > 200, "Terrain carved (" .. e.terrainOps.count .. " fills)")
check((e.terrainOps.materials["Enum.Material.Water"] or 0) > 10, "Terrain water for pond and creek")
for _, name in ipairs({"ArenaFloor", "IslandUnderside", "ChaseInfield"}) do
	check(meadow:FindFirstChild(name) == nil, "No legacy floor disc: " .. name)
end
local function parts(root)
	local n = 0
	for _, item in ipairs(root:GetDescendants()) do if item:IsA("BasePart") and item.Transparency < 1 then n += 1 end end
	return n
end
for _, f in ipairs(def.features) do
	local m = meadow:FindFirstChild(f.id)
	check(m ~= nil, "feature present: " .. f.id)
	check(m:GetAttribute("FeatureType") == f.type, "feature type " .. f.id)
	check(m:GetAttribute("Unbuilt") == nil, "feature has a builder: " .. f.id)
	if f.solid then
		local col = m:FindFirstChild(f.id .. "_Col")
		check(col ~= nil and col.CanCollide == true, "solid feature has collision: " .. f.id)
	end
end
for _, ring in ipairs(def.bankRings) do
	local m = meadow:FindFirstChild(ring.id)
	check(m ~= nil and m:GetAttribute("FeatureType") == "bank_ring", "bank ring " .. ring.id)
	local pivot = m:GetPivot().Position
	check(math.abs(pivot.X - ring.x) < 1.5 and math.abs(pivot.Z - ring.z) < 1.5, "bank ring at its coordinates " .. ring.id)
end
local hedge = meadow:FindFirstChild("boundary_hedge")
check(hedge ~= nil and #hedge:GetChildren() > 50, "boundary hedge built")
local boundaryCols = 0
for _, item in ipairs(hedge:GetChildren()) do if item.Name == "boundary_Col" then boundaryCols += 1 end end
check(boundaryCols == #def.bounds, "one boundary collision slab per bounds edge")
-- Records board wiring survives (World.setRecords writes to its SurfaceGui).
local board = meadow:FindFirstChild("records_board")
check(board and board:FindFirstChild("RecordsBoard", true) and board:FindFirstChild("Records", true), "records board surface")
local serverParts = parts(meadow)
-- Client decor: build it exactly as the client does, into a scratch folder.
local Decor = load("StarterPlayer/StarterPlayerScripts/Spark/Decor.luau")
local folder = e.makeInstance("Folder")
folder.Parent = e.workspace
local counts = Decor.build(folder, def, Harness.Vector3.new(0, 0, 0), GroundMap, true)
local decorParts = parts(folder)
local budget = Tuning.performance.arenaPartsVisibleMax
check(serverParts + decorParts <= budget, string.format("Meadow parts %d + decor %d <= %d", serverParts, decorParts, budget))
check(decorParts >= 1000, "decor is substantial (" .. decorParts .. ")")
-- GroundMap: grid lookup within 0.5 stud of the analytic surface everywhere inside the bounds.
local map = GroundMap.build(def)
local worst = 0
for x = -86, 86, 2 do
	for z = -76, 74, 2 do
		if GroundMap.inPolygon(def.bounds, x, z) then
			worst = math.max(worst, math.abs(GroundMap.height(map, x, z, 50) - GroundMap.surface(def, x, z)))
		end
	end
end
check(worst <= 0.5, string.format("GroundMap within 0.5 of the surface (worst %.3f)", worst))
check(GroundMap.height(map, 4, -30, 50) > 5, "clover knoll is raised")
check(GroundMap.height(map, -50, -10, 50) < -1, "pond basin is lowered")
-- Spawn is inside the bounds, on the ground, facing north.
check(Arenas.inBounds(def, def.spawn.x, def.spawn.z), "spawn inside bounds")
print(string.format("INFO meadow: serverParts=%d decorParts=%d (tufts %d, tall %d, flowers %d, reeds %d, lily %d) terrainFills=%d groundWorst=%.3f",
	serverParts, decorParts, counts.tuft, counts.tallGrass or 0, counts.flower, counts.reed, counts.lily, e.terrainOps.count, worst))
h:report("worlddata")
print("PASS ScenarioM_WorldData: " .. Harness.count() .. " checks")
