--!nocheck
-- (c) A full 110s virtual round driven by a scripted bot through the real
-- remotes, then settlement, progression, Results payload, replay and round 2.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
local p = h:join(2001)
local roundStart = e.now
local stats = h:playRound(p, {timeout = 125})
h:assertClean("round 1")
local s = h:state(p)
check(s.phase == "Results", "Round settled to Results (" .. tostring(s.phase) .. ")")
local length = e.now - roundStart
check(length >= 109 and length <= 112, string.format("Round length %.1fs", length))
local profile = s.profile
check(profile.rounds == 1 and profile.progressReceipt == 1, "Round recorded once")
check(profile.totalBanked >= 3, "Banked at least the starters (" .. profile.totalBanked .. ")")
check(profile.xp > 0, "XP granted " .. profile.xp)
check(s.lastResult ~= nil and s.lastResult.xp > 0 and profile.xp >= s.lastResult.xp and s.lastResult.score == s.mastery.score,
	"lastResult consistent with round (xp=" .. tostring(s.lastResult and s.lastResult.xp) .. ")")
check(profile.records.meadow[1] == s.mastery.score, "Heat-0 meadow record = round score")
check(#profile.daily.goals == 3 and #profile.weekly.goals == 3, "Daily/weekly goals rolled")
check(s.mastery.finished == true and s.mastery.medal ~= nil, "Challenge finished with medal " .. tostring(s.mastery.medal))
check(stats.captures >= 6, "Bot made several catches (" .. stats.captures .. ")")
print(string.format("INFO round1: captures=%d attempts=%d dashes=%d banks=%d score=%d medal=%s glow=%d banked=%d misses=%d zaps=%d pops=%d dashCatches=%d multi=%d golden=%d herded=%d buzzerLost=%d",
	stats.captures, stats.attempts, stats.dashes, stats.banks, s.mastery.score, s.mastery.medal, profile.coins, profile.totalBanked,
	s.mastery.misses, s.mastery.zaps, s.mastery.pops, s.mastery.dashCatches, s.mastery.multiCatches, s.mastery.golden, s.mastery.herded, s.mastery.buzzerLost))
local kinds = {}
for _, f in ipairs(h:feedbackOf(p)) do kinds[f.kind] = (kinds[f.kind] or 0) + 1 end
local summary = {}
for k, v in pairs(kinds) do table.insert(summary, k .. "=" .. v) end
table.sort(summary)
print("INFO feedback kinds: " .. table.concat(summary, " "))
-- Results phase: loadout/heat changes are allowed; then replay.
local silver = s.profile.records.meadow[1] >= 400
h:send(p, "Heat", 3); e.advance(0.2)
check(h:state(p).profile.heat == 0, "Heat 3 refused without Silver at heat 1/2")
h:send(p, "Heat", 1); e.advance(0.2)
check(h:state(p).profile.heat == (if silver then 1 else 0), "Heat 1 follows the Silver rule")
h:send(p, "Heat", 0); e.advance(0.2)
check(h:state(p).profile.heat == 0, "Heat back to 0")
h:send(p, "Replay"); e.advance(0.5)
s = h:state(p)
check(s.phase == "Playing" and s.startersRemaining == 0, "Replay starts round 2 without starter refill")
local stats2 = h:playRound(p, {timeout = 125})
h:assertClean("round 2")
s = h:state(p)
check(s.phase == "Results" and s.profile.rounds == 2 and s.profile.progressReceipt == 2, "Round 2 recorded")
print(string.format("INFO round2: captures=%d score=%d medal=%s xp=%d rank=%d zaps=%d pops=%d statics=%s",
	stats2.captures, s.mastery.score, s.mastery.medal, s.profile.xp, s.rank.rank, s.mastery.zaps, s.mastery.pops, tostring(s.statics)))
h:report("full-round")
print("PASS ScenarioC_FullRound: " .. Harness.count() .. " checks")
