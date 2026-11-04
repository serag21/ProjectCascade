--!nocheck
-- (a) Server boot: the real Main.server.luau builds the world and herd with no
-- API validation errors (classes, properties, enums, attributes).
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine
h:assertClean("boot")
check(h.remotes ~= nil, "Remotes folder created")
for _, name in ipairs({"Action", "State", "Feedback"}) do
	check(h.remotes:FindFirstChild(name) and h.remotes[name]:IsA("RemoteEvent"), name .. " RemoteEvent")
end
check(h.world ~= nil and h.world:IsA("Model"), "SparkWorld built")
local arenas = 0
for _, child in ipairs(h.world:GetChildren()) do if child:GetAttribute("BiomeIndex") then arenas += 1 end end
check(arenas == 3, "Three arenas (" .. arenas .. ")")
local creatures = h:creatures()
check(#creatures == 54, "54 herd creatures (" .. #creatures .. ")")
local species = {}
for _, model in ipairs(creatures) do
	check(model.PrimaryPart ~= nil and model:GetAttribute("CreatureId") ~= nil, "Creature has root + id")
	species[model:GetAttribute("Species")] = true
end
local count = 0; for _ in pairs(species) do count += 1 end
check(count == 12, "All 12 species present (" .. count .. ")")
check(h.world:FindFirstChild("Statics") ~= nil, "Statics folder")
local booted = false
for _, line in ipairs(e.output) do if string.find(line, "Staged build booted", 1, true) then booted = true end end
check(booted, "Main reached end of boot")
-- Creatures keep moving without players (herd loop runs) and stay in arena bounds.
local first = creatures[1]:GetPivot().Position
e.advance(5)
h:assertClean("idle herd")
check((creatures[1]:GetPivot().Position - first).Magnitude > 0.5, "Herd moves")
for _, model in ipairs(h:creatures()) do
	local biome = 1
	local p = model:GetPivot().Position
	local ox = math.floor((p.X + 150) / 300) * 300
	local flat = math.sqrt((p.X - ox) ^ 2 + p.Z ^ 2)
	check(flat <= 49, "Creature within herd radius (" .. flat .. ")")
end
h:report("boot")
print("PASS ScenarioA_Boot: " .. Harness.count() .. " checks; world parts=" .. e.countInstances(h.world))
