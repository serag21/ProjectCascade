--!nocheck
-- (i) Synchronized Stampede Cycles: four players join at different moments of
-- the shared 120 s cycle. Warm-up vs partial vs full rounds, one shared buzzer,
-- positive podium, auto-start, Sit out and Play. Real Main + remotes; virtual time.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine

local function advanceToCycleTime(player, target)
	-- Step until this player's view of the shared cycle reaches `target` seconds.
	for _ = 1, 3000 do
		local s = h:state(player)
		local t = s and s.cycle and s.cycle.t
		-- State arrives every 0.5 s: accept the first sample inside [target, target+1).
		if t and t >= target and t < target + 1 then return true end
		e.step(1 / 10)
	end
	return false
end

local p1 = h:join(9101)
check(advanceToCycleTime(p1, 114), "Reached the intermission of the current cycle")
local p2 = h:join(9102)
local s2 = h:state(p2)
check(s2.phase == "Warmup" and s2.remaining <= 7, "Joining in the intermission starts a short warm-up (" .. tostring(s2.phase) .. ")")
check(s2.startersRemaining == 3, "Warm-up players get their starters immediately")
check(h:awaitPlaying({p1, p2}, 12), "Both players start the next shared round together")
local a1, a2 = h:state(p1), h:state(p2)
check(a1.fullRound and a2.fullRound and math.abs(a1.remaining - a2.remaining) <= 1, "Same full round, same buzzer")

check(advanceToCycleTime(p1, 30), "Reached t=30")
local p3 = h:join(9103)
local s3 = h:state(p3)
check(s3.phase == "Playing" and not s3.fullRound and math.abs(s3.remaining - h:state(p1).remaining) <= 1, "Mid-cycle join plays a partial round to the shared buzzer")

check(advanceToCycleTime(p1, 80), "Reached t=80")
local p4 = h:join(9104)
local s4 = h:state(p4)
check(s4.phase == "Warmup", "Joining with under 40 s left starts a warm-up (" .. tostring(s4.phase) .. ")")

h:playRounds({p1, p2, p3}, {timeout = 40})
e.step(0.5)
local r1, r2, r3 = h:state(p1), h:state(p2), h:state(p3)
check(r1.phase == "Results" and r2.phase == "Results" and r3.phase == "Results", "All three settle at the same buzzer")
check(r1.nextRoundIn == r2.nextRoundIn and r2.nextRoundIn == r3.nextRoundIn, "One shared intermission countdown")
check(r3.lastResult and r3.lastResult.full == false, "Late joiner's round is partial")
check(r1.lastResult and r1.lastResult.full == true and r2.lastResult.full == true, "On-time players' rounds are full")
check(r3.profile.records.meadow[1] == 0, "Partial round wrote no record")
check(type(r1.podium) == "table" and #r1.podium >= 1 and #r1.podium <= 3, "Podium shown in the intermission")
for _, award in ipairs(r1.podium) do
	check(type(award.title) == "string" and award.value > 0, "Positive award " .. tostring(award.title))
end
check(h:state(p4).phase == "Warmup", "Warm-up player keeps practising through the intermission")

-- Sit out during the intermission: p2 should not start the next round.
h:send(p2, "SitOut"); e.step(0.3)
check(h:state(p2).sitOut == true, "Sit out acknowledged")
check(h:awaitPlaying({p1, p3, p4}, 12), "Everyone else starts the next round; the warm-up player joins a full round")
check(h:state(p4).fullRound == true and h:state(p4).profile.rounds == 0, "Warm-up gave no round credit; next round is full")
check(h:state(p2).phase == "SitOut", "Sitting-out player waits")
h:send(p2, "Play"); e.step(0.3)
local back = h:state(p2)
check(back.phase == "Playing" or back.phase == "Warmup", "Play rejoins immediately (" .. tostring(back.phase) .. ")")
h:assertClean("synced cycles")
h:report("synced-cycles")
print("PASS ScenarioI_SyncedCycles: " .. Harness.count() .. " checks")
