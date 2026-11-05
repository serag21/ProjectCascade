--!nocheck
-- (f) Non-Studio code path: real DataStoreService/OrderedDataStore/
-- AnalyticsService calls against fake platform services, with injected
-- transient DataStore failures. Not real platform latency, quotas or limits.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot({studio = false})
local e = h.engine
h:assertClean("boot (production path)")
-- Two transient failures during the first load: Persistence must retry.
e.storeFailures = 2
local p = h:join(6001)
e.advance(2)
h:assertClean("join with retries")
local s = h:state(p)
check(s and s.phase == "Playing", "Join survives transient DataStore failures")
check(e.storeFailures == 0, "Injected failures consumed by retries")
local profiles = e.stores["global:SparkStampedeProfiles_v1:global"]
check(profiles ~= nil, "Production profile DataStore opened")
h:playRound(p, {timeout = 125})
h:assertClean("production round")
s = h:state(p)
check(s.phase == "Results" and s.profile.rounds == 1, "Round recorded on production path")
-- Autosave runs every 30s; give it a cycle, then inspect the stored envelope.
e.advance(31)
local record = e.recOf(profiles).internal.values["player:6001"]
check(type(record) == "table" and record.kind == "SparkProfile" and record.version == 1 and type(record.data) == "table", "Envelope saved")
check(record.data.version == 3 and record.data.rounds == 1 and record.data.totalBanked == s.profile.totalBanked, "Saved profile matches session")
check(type(record.lease) == "table" and record.lease.expiresAt > e.os.time(), "Live session lease held")
-- Analytics funnel and economy events carry valid argument shapes.
local funnel, economy, custom = {}, 0, 0
for _, event in ipairs(e.analytics) do
	if event.method == "LogOnboardingFunnelStepEvent" then funnel[event.args[2]] = event.args[1]
	elseif event.method == "LogEconomyEvent" then economy += 1
	elseif event.method == "LogCustomEvent" then custom += 1 end
end
for _, step in ipairs({"join", "first_action", "first_catch", "first_bank", "first_round"}) do
	check(funnel[step] ~= nil, "Funnel step " .. step)
end
check(economy > 0 and custom > 0, "Economy/custom analytics logged (" .. economy .. "/" .. custom .. ")")
-- Leaderboard write on the new record and periodic refresh.
e.advance(125)
local board = e.stores["ordered:SparkBest_meadow_v1:global"]
check(board ~= nil and e.recOf(board).internal.values["6001"] == s.mastery.score, "All-time leaderboard written with round score")
local weeklyFound = false
for key in pairs(e.stores) do if string.find(key, "SparkWeekly_meadow_", 1, true) then weeklyFound = true end end
check(weeklyFound, "Weekly leaderboard written")
local latest = h:state(p)
check(latest.boards == nil or type(latest.boards) == "table", "Boards payload shape")
-- Leave: final release clears the lease so another server may load at once.
e.removePlayer(p)
e.advance(3)
h:assertClean("release")
record = e.recOf(profiles).internal.values["player:6001"]
check(record.lease == nil or record.lease.expiresAt <= e.os.time(), "Lease released on leave")
check(record.data.lastSeen > 0, "lastSeen stamped")
h:report("production-path")
print("PASS ScenarioF_ProductionPath: " .. Harness.count() .. " checks")
