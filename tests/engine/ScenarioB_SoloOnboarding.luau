--!nocheck
-- (b) Solo onboarding through the real remotes: join, Ready, private starters,
-- capture, bank, state payloads and analytics funnel steps.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine
local p = h:join(1001)
h:assertClean("join")
local s = h:state(p)
check(s ~= nil and s.phase == "Playing" and s.ready == true, "Round started after Ready (" .. tostring(s and s.phase) .. ")")
check(s.profile ~= nil and s.profile.version == 2, "Profile v2 delivered")
check(s.startersRemaining == 3, "Three private starters")
check(p:GetAttribute("SparkPhase") == "Playing", "Public phase attribute")
local spawnPos = h:position(p)
check((spawnPos - Vector3.new(0, 3, 38)).Magnitude < 0.01, "Teleported to arena spawn " .. tostring(spawnPos))
local mine = function(m) return m:GetAttribute("StarterOwnerId") == p.UserId end
check(#h:creatures(mine) == 3, "Three starter models owned by player")
local joinedAt = e.now
for i = 1, 3 do
	check(h:chaseAndCatch(p, mine, 8), "Caught starter " .. i)
end
local caughtAt = e.now
s = h:state(p)
check(s.carry == 3 and s.startersRemaining == 0, "Carrying 3, no starters left")
check(p:GetAttribute("SparkParade") ~= "", "Parade attribute replicated")
-- Walk to the bank gate; the heartbeat auto-banks within 10 studs.
check(h:walkTo(p, Vector3.new(0, 3, 40), 6), "Reached bank")
e.advance(0.5)
s = h:state(p)
check(s.carry == 0 and s.profile.totalBanked == 3, "Banked three (carry=" .. s.carry .. ", banked=" .. s.profile.totalBanked .. ")")
check(s.profile.coins > 0 and p:GetAttribute("SparkGlow") == s.profile.coins, "Glow awarded " .. s.profile.coins)
check(#h:creatures(mine) == 0, "Starters cleared after onboarding")
local banks = h:feedbackOf(p, "Bank")
check(#banks >= 1, "Bank feedback")
local catches = h:feedbackOf(p, "Catch")
check(#catches == 3 and catches[1].extra ~= nil, "Catch feedback with extra payload")
-- After onboarding the hazard timeline starts fresh; statics need 25s more.
check(s.objective ~= nil and s.rank ~= nil and s.stats ~= nil and s.encounter ~= nil, "v2 HUD fields present")
print(string.format("INFO onboarding: join->3 starters caught %.2fs, ->bank %.2fs (scripted walker, not human timing)", caughtAt - joinedAt, e.now - joinedAt))
h:assertClean("onboarding")
h:report("solo-onboarding")
print("PASS ScenarioB_SoloOnboarding: " .. Harness.count() .. " checks")
