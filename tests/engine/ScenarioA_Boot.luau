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
check(arenas == 4, "Three shared arenas + Trial Grounds (" .. arenas .. ")")
local trialGrounds = h.world:FindFirstChild("trials")
check(trialGrounds ~= nil and trialGrounds:GetAttribute("BiomeIndex") == 4, "Trial Grounds is arena 4 (x=900)")
-- WP-06: creatures are server data only (T-N2). The Meadow holds its pods from
-- meadow.json (13, <= the 14 base cap); Canyon/Aurora are unreachable in the slice.
local serverModels = 0
for _, d in ipairs(e.workspace:GetDescendants()) do
	if d:IsA("Model") and (d:GetAttribute("CreatureId") ~= nil or string.sub(d.Name, 1, 6) == "Spark_") then serverModels += 1 end
end
check(serverModels == 0, "Server creates zero creature Instances (" .. serverModels .. ")")
local booted = false
for _, line in ipairs(e.output) do if string.find(line, "Staged build booted", 1, true) then booted = true end end
check(booted, "Main reached end of boot")
e.advance(5)
h:assertClean("idle herd")
check((h.herdPackets or 0) == 0, "No herd packets without players")
local p = h:join(1501)
e.advance(3)
h:collect()
check((h.herdPackets or 0) >= 20, "Herd snapshots arrive at ~10 Hz (" .. tostring(h.herdPackets) .. ")")
check(h.herdBytes / h.herdPackets <= 900, "Every packet within the unreliable payload limit")
check(e.unreliableDropped == 0, "No unreliable packet dropped")
local creatures = h:creatures()
local species, shared, private = {}, 0, 0
for _, model in ipairs(creatures) do
	species[model:GetAttribute("Species")] = (species[model:GetAttribute("Species")] or 0) + 1
	if model:GetAttribute("StarterOwnerId") == p.UserId then private += 1 else shared += 1 end
end
check(shared == 13, "Meadow pods: 3+3 Pip, 2 Bunvolt, 4 Cubloom, 1 Flutterwink (" .. shared .. ")")
check(private == 3, "Three private starter Pips, sent only to their owner (" .. private .. ")")
check(species.pip == 9 and species.bunvolt == 2 and species.cubloom == 4 and species.flutter == 1, "Species mix")
local Arenas = e.requireSource("ReplicatedStorage/Spark/Design/Arenas.luau")
for _, model in ipairs(creatures) do
	local pos = model:GetPivot().Position
	check(Arenas.inBounds("meadow", pos.X, pos.Z), "Creature inside the Meadow bounds")
end
print(string.format("INFO herd: packets=%d avgBytes=%.0f bytesPerSecond=%.0f", h.herdPackets, h.herdBytes / h.herdPackets, h.herdBytes / 3))
h:report("boot")
print("PASS ScenarioA_Boot: " .. Harness.count() .. " checks; world parts=" .. e.countInstances(h.world))
