--!nocheck
-- (e) Ten consecutive virtual rounds with two bot players: detect runaway growth
-- of instances, herd extras, statics, scheduled threads and remote traffic.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
local a = h:join(5001)
local b = h:join(5002)
local baseline = e.countInstances()
local samples = {}
local scores = {}
for round = 1, 10 do
	if round > 1 then h:send(a, "Replay"); h:send(b, "Replay"); e.advance(0.3) end
	h:playRounds({a, b}, {timeout = 125})
	h:assertClean("round " .. round)
	-- Let delayed respawns and Debris cleanups settle before sampling.
	e.advance(3)
	local sa, sb = h:state(a), h:state(b)
	check(sa.phase == "Results" and sb.phase == "Results", "Round " .. round .. " settled for both")
	check(sa.profile.rounds == round and sb.profile.rounds == round, "Round count " .. round)
	local herd = #h:creatures()
	local statics = #h.world.Statics:GetChildren()
	local herdInstances = e.countInstances(h.world.Creatures)
	table.insert(samples, {instances = e.countInstances(), other = e.countInstances() - herdInstances, herd = herd, statics = statics, sleepers = e.sleepers()})
	table.insert(scores, sa.mastery.score .. "/" .. sb.mastery.score)
	check(statics == 0, "No statics left between rounds (" .. statics .. ")")
	check(herd >= 54 and herd <= 54 + 12, "Herd bounded after settle (" .. herd .. ")")
end
local first, last = samples[1], samples[#samples]
local lines = {}
for i, s in ipairs(samples) do table.insert(lines, string.format("r%d:%d/%d/%d/%d", i, s.instances, s.other, s.herd, s.sleepers)) end
print("INFO samples total/nonHerd/herd/sleepers: " .. table.concat(lines, " "))
print("INFO scores: " .. table.concat(scores, " "))
check(last.other - first.other <= 10, string.format("No non-herd instance growth (%d -> %d)", first.other, last.other))
local maxOther = 0
for _, sample in ipairs(samples) do maxOther = math.max(maxOther, sample.other) end
check(maxOther - first.other <= 10, "Non-herd instances stable every round (max " .. maxOther .. ")")
check(last.sleepers <= first.sleepers + 10, string.format("Scheduled threads bounded (%d -> %d)", first.sleepers, last.sleepers))
h:report("soak")
print("PASS ScenarioE_Soak: " .. Harness.count() .. " checks; 20 player-rounds")
