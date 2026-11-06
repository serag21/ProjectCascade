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
-- Frozen launch funnel (plan §6.13): steps carry their fixed numbers.
local expected = {join = 1, first_catch = 2, first_bank = 3, first_round_complete = 5}
for step, number in pairs(expected) do
	check(funnel[step] == number, "Funnel step " .. step .. " = " .. number .. " (" .. tostring(funnel[step]) .. ")")
end
check(funnel.first_action == nil and funnel.replay == nil, "Retired funnel names are no longer sent")
check(economy > 0 and custom > 0, "Economy/custom analytics logged (" .. economy .. "/" .. custom .. ")")
-- D16: normal-round scores never reach a public board; only the Daily Stampede
-- board is read (production OrderedDataStore path) and shown on records boards.
e.advance(125)
local wroteNormal, dailyOpened = false, false
for key, store in pairs(e.stores) do
	if string.find(key, "SparkBest_", 1, true) or string.find(key, "SparkWeekly_", 1, true) then
		if e.recOf(store).internal.values["6001"] ~= nil then wroteNormal = true end
	end
	if string.find(key, "ordered:SparkDaily_", 1, true) then dailyOpened = true end
end
check(not wroteNormal, "Normal-round score stays off public boards (D16)")
check(dailyOpened, "Daily Stampede board refreshed from the production ordered store")
local latest = h:state(p)
check(type(latest.trial) == "table" and (latest.trial.board == nil or type(latest.trial.board) == "table"), "Daily board payload shape")
-- Exploit telemetry (plan §6.12): junk requests are counted, then reported once at leave.
for _ = 1, 3 do h:send(p, "GiveGlow", 9999); e.advance(0.1) end
local analyticsBefore = #e.analytics
-- Leave: final release clears the lease so another server may load at once.
e.removePlayer(p)
e.advance(3)
h:assertClean("release")
local exploitEvents = {}
for index = analyticsBefore + 1, #e.analytics do
	local event = e.analytics[index]
	if event.method == "LogCustomEvent" and type(event.args[1]) == "string" and string.sub(event.args[1], 1, 8) == "exploit_" then
		exploitEvents[event.args[1]] = event.args[2]
	end
end
check(exploitEvents.exploit_malformed ~= nil and exploitEvents.exploit_malformed >= 3, "Malformed requests reported once at leave (" .. tostring(exploitEvents.exploit_malformed) .. ")")
record = e.recOf(profiles).internal.values["player:6001"]
check(record.lease == nil or record.lease.expiresAt <= e.os.time(), "Lease released on leave")
check(record.data.lastSeen > 0, "lastSeen stamped")
h:report("production-path")
print("PASS ScenarioF_ProductionPath: " .. Harness.count() .. " checks")
