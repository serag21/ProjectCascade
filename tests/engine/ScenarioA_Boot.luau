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
-- Living herd (D13): the server never moves creature models (no CFrame
-- replication); with nobody in the game no herd packets are sent at all.
local first = creatures[1]:GetPivot().Position
e.advance(5)
h:assertClean("idle herd")
check((creatures[1]:GetPivot().Position - first).Magnitude < 1e-6, "Server does not move creature models")
check((h.herdPackets or 0) == 0, "No herd packets without players")
-- A player receives compact snapshots of their arena; the harness applies them
-- like a client would, so models follow the authoritative herd.
local p = h:join(1501)
local before = creatures[1]:GetPivot().Position
e.advance(3)
h:collect()
check((h.herdPackets or 0) >= 20, "Herd snapshots arrive at ~10 Hz (" .. tostring(h.herdPackets) .. ")")
check(h.herdBytes / h.herdPackets <= 900, "Every packet within the unreliable payload limit")
check(e.unreliableDropped == 0, "No unreliable packet dropped")
local moved = 0
for _, model in ipairs(h:creatures()) do
	if model:GetPivot().Position.X < 150 and (model:GetPivot().Position - before).Magnitude > 0 then moved += 1 end
end
check(moved >= 10, "Arena creatures follow the snapshots (" .. moved .. ")")
print(string.format("INFO herd: packets=%d avgBytes=%.0f bytesPerSecond=%.0f", h.herdPackets, h.herdBytes / h.herdPackets, h.herdBytes / 3))
for _, model in ipairs(h:creatures()) do
	local biome = 1
	local p = model:GetPivot().Position
	local ox = math.floor((p.X + 150) / 300) * 300
	local flat = math.sqrt((p.X - ox) ^ 2 + p.Z ^ 2)
	check(flat <= 49, "Creature within herd radius (" .. flat .. ")")
end
h:report("boot")
print("PASS ScenarioA_Boot: " .. Harness.count() .. " checks; world parts=" .. e.countInstances(h.world))
