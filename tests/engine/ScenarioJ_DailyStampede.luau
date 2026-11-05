--!nocheck
-- (j) Daily Stampede: two players on the production (non-Studio) path unlock the
-- trial after two rounds, run the SAME seeded course with normalized rules,
-- get the once-per-day reward, retry, leave mid-run back into the shared cycle,
-- and land on the daily OrderedDataStore board in score order. Real Main + remotes.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot({studio = false})
local e = h.engine
local TRIAL_X = 900

local p1, p2 = h:join(9201), h:join(9202)
check(h:awaitPlaying({p1, p2}, 130), "Both players reach a scored round")
local first = h:state(p1)
check(type(first.trial) == "table" and first.trial.available == false and first.mode == "cycle", "Daily Stampede locked before round 2")
h:send(p1, "Trial", "start"); e.step(0.3)
check(h:state(p1).mode == "cycle", "Locked trial refuses to start")

-- Two rounds each unlock the trial (bots catch plenty; round credit needs 3+).
for round = 1, 2 do
	check(h:awaitPlaying({p1, p2}, 130), "Round " .. round .. " starts")
	if round == 2 then
		h:send(p1, "Trial", "start"); e.step(0.3)
		check(h:state(p1).mode == "cycle" and h:state(p1).phase == "Playing", "Trial cannot start in the middle of a scored round")
	end
	h:playRounds({p1, p2}, {timeout = 125})
end
e.step(0.6)
local before1, before2 = h:state(p1), h:state(p2)
check(before1.phase == "Results" and before1.profile.rounds >= 2 and before2.profile.rounds >= 2, "Two rounds recorded each")
check(before1.trial.available == true and before1.trial.runsToday == 0 and before1.trial.rewardedToday == false, "Trial available after round 2")
local banked1, coins1 = before1.profile.totalBanked, before1.profile.coins
local album1 = 0
for _ in pairs(before1.profile.collection or {}) do album1 += 1 end

-- Both start today's course.
h:send(p1, "Trial", "start"); h:send(p2, "Trial", "start")
e.step(0.15)
local t1, t2 = h:state(p1), h:state(p2)
check(t1.mode == "trial" and t1.phase == "Playing" and t1.biome == 4 and t2.mode == "trial", "Both runners are in the Trial Grounds")
check(t1.remaining >= 73 and t1.remaining <= 75, "75-second run (" .. tostring(t1.remaining) .. ")")
check(t1.stats.captureRadius == 11.5 and t1.stats.capacity == 10 and t1.stats.heat == 0 and #t1.stats.perks == 0, "Normalized rules ignore upgrades, perks and heat")
check(t1.rally == nil and t1.cycle == nil and t1.podium == nil, "Trial is outside the shared cycle (no rally/cycle/podium)")
local root = h:position(p1)
check(math.abs(root.X - TRIAL_X) < 60, "Runner teleported to the Trial Grounds")
local slots = {[9201] = {}, [9202] = {}}
for _, model in ipairs(h:creatures(function(m) return m:GetAttribute("Trial") == true end)) do
	local owner, slot = model:GetAttribute("StarterOwnerId"), model:GetAttribute("TrialSlot")
	if slots[owner] and slot then slots[owner][slot] = model end
end
local count1, count2, same = 0, 0, true
for slot = 1, 20 do
	local a, b = slots[9201][slot], slots[9202][slot]
	if a then count1 += 1 end
	if b then count2 += 1 end
	if not a or not b or a:GetAttribute("Species") ~= b:GetAttribute("Species")
		or (a:GetPivot().Position - b:GetPivot().Position).Magnitude > 4 then same = false end
end
check(count1 == 20 and count2 == 20, "20 private Sparks per runner (" .. count1 .. "/" .. count2 .. ")")
check(same, "Identical seeded course for both players (species and positions per slot)")
h:send(p1, "Biome", 2); e.step(0.3)
check(h:state(p1).biome == 4, "Arena travel refused during a trial")

-- Run both courses to the end.
h:playRounds({p1, p2}, {timeout = 80})
e.step(0.6)
local r1, r2 = h:state(p1), h:state(p2)
check(r1.phase == "Results" and r1.mode == "trial" and r1.lastResult and r1.lastResult.trial, "Run settles into trial results")
check(r1.nextRoundIn == nil, "Trial results never auto-start a shared round")
check(r1.lastResult.score > 0 and r1.profile.trial.best == r1.lastResult.score and r1.profile.trial.runsToday == 1, "Score, today's best and run count recorded")
check(r1.lastResult.glow == 40 and r1.profile.coins >= coins1 + 40, "First daily completion pays +40 glow")
check(r1.lastResult.xp >= 80, "First run XP includes the +80 bonus (" .. tostring(r1.lastResult.xp) .. ")")
check(r1.profile.totalBanked == banked1, "Trial banks never pay glow or album progress (no farming)")
local album1After = 0
for _ in pairs(r1.profile.collection or {}) do album1After += 1 end
check(album1After == album1, "Album unchanged by trial runs")
check(r1.profile.daily.progress.d_trial == 1, "Daily goal 'Finish today's Daily Stampede' progressed")
local coinsBeforeClaim = r1.profile.coins
h:send(p1, "ClaimAll"); e.step(0.3)
local claimed = h:state(p1)
check(claimed.profile.daily.claimed.d_trial == true and claimed.profile.coins > coinsBeforeClaim, "Claim-on-results claims the finished Daily Stampede goal")
r1 = claimed
check(#h:creatures(function(m) return m:GetAttribute("StarterOwnerId") == 9201 end) == 0, "Trial Sparks cleaned up after the run")

-- Retry: same course again; a second finish pays XP but never the daily glow twice.
h:send(p2, "Trial", "retry"); e.step(0.3)
check(h:state(p2).phase == "Playing" and h:state(p2).mode == "trial", "Instant retry")
h:playRounds({p2}, {timeout = 80})
e.step(0.6)
local again = h:state(p2)
check(again.lastResult.trial and again.lastResult.glow == 0 and again.profile.trial.runsToday == 2, "Reward once per day; second run counted")
check(again.lastResult.xp > 0 and again.lastResult.xpRunsLeft == 3, "Later runs still earn capped XP")

-- Leave mid-run: back into the shared cycle; the abandoned run counts for nothing.
h:send(p1, "Trial", "retry"); e.step(0.3)
check(h:state(p1).phase == "Playing" and h:state(p1).mode == "trial", "Second run started")
e.step(5)
h:send(p1, "Trial", "leave"); e.step(0.3)
local back = h:state(p1)
check(back.mode == "cycle" and back.biome == 1 and (back.phase == "Playing" or back.phase == "Warmup"), "Leaving returns to the arena cycle (" .. tostring(back.phase) .. ")")
check(back.profile.trial.runsToday == 1, "Abandoned run is not counted")
check(#h:creatures(function(m) return m:GetAttribute("StarterOwnerId") == 9201 and m:GetAttribute("Trial") == true end) == 0, "Leaving removes the private course")
check(math.abs(h:position(p1).X) < 80, "Teleported back to the shared arena")

-- Daily board: production OrderedDataStore, one store per UTC day, best score per player.
e.advance(20)
local board
for key, store in pairs(e.stores) do
	if string.find(key, "ordered:SparkDaily_", 1, true) then board = e.recOf(store).internal.values end
end
check(board ~= nil, "Daily board written to SparkDaily_<day>_v1")
check(board["9201"] == r1.profile.trial.best and board["9202"] == again.profile.trial.best, "Board holds each player's best run today")
local recordsRow
for _, d in ipairs(h.world:GetDescendants()) do
	if d.Name == "Row1" and d:IsA("TextLabel") then recordsRow = d.Text; break end
end
check(type(recordsRow) == "string" and string.find(recordsRow, "1. ", 1, true) == 1, "Records boards show today's top runs (" .. tostring(recordsRow) .. ")")
print(string.format("INFO trial scores (scripted bots, superhuman): p1=%d %s • p2=%d then %d %s • board=%s",
	r1.lastResult.score, tostring(r1.lastResult.medal), r2.lastResult.score, again.lastResult.score, tostring(again.lastResult.medal), tostring(recordsRow)))
h:assertClean("daily stampede")
h:report("daily-stampede")
print("PASS ScenarioJ_DailyStampede: " .. Harness.count() .. " checks")
