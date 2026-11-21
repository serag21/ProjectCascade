--!nocheck
-- (b) Solo onboarding through the real remotes: join, Ready, private starters,
-- one ring around the starter pod (loop claim), run-through bank, state payloads.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine
local p = h:join(1001)
h:assertClean("join")
local s = h:state(p)
check(s ~= nil and s.phase == "Playing" and s.ready == true, "Round started after Ready (" .. tostring(s and s.phase) .. ")")
check(s.profile ~= nil and s.profile.version == 3, "Profile v3 delivered")
check(s.cycle ~= nil and s.cycle.phase == "Play" and s.remaining > 0, "Shared cycle state delivered")
check(s.startersRemaining == 3, "Three private starters")
check(p:GetAttribute("SparkPhase") == "Playing", "Public phase attribute")
local spawnPos = h:position(p)
-- Meadow spawn from design/fable/data/arenas/meadow.json (x=0, z=66), 3 studs above the ground.
check(math.abs(spawnPos.X) < 0.01 and math.abs(spawnPos.Z - 66) < 0.01 and spawnPos.Y > 2 and spawnPos.Y < 4.5, "Teleported to arena spawn " .. tostring(spawnPos))
local mine = function(m) return m:GetAttribute("StarterOwnerId") == p.UserId end
check(#h:creatures(mine) == 3, "Three starter models owned by player")
local joinedAt = e.now
-- T-L4 (WP-04): a bot walking a 6-stud circle around the starter pod catches all
-- three within 5 s of starting the circle. Loops are the only way to catch.
local centre = Vector3.new(0, 0, 0)
for _, m in ipairs(h:creatures(mine)) do centre += m:GetPivot().Position / 3 end
local circleStarted
do
	local here = h:position(p)
	local angle = math.atan2(here.Z - centre.Z, here.X - centre.X)
	h:walkTo(p, Vector3.new(centre.X + math.cos(angle) * 6, 3, centre.Z + math.sin(angle) * 6), 6)
	circleStarted = e.now
end
local poly = h:ringAround(p, centre, 6)
check(poly ~= nil, "Ring around the starter pod closed")
local caughtAt = e.now
s = h:state(p)
check(s.carry == 3 and s.startersRemaining == 0, "One ring caught all three starters (carry " .. s.carry .. ")")
check(caughtAt - circleStarted <= 5, string.format("Caught within 5 s of starting the circle (%.2f s)", caughtAt - circleStarted))
local results = h:loopResults(p)
check(#results >= 1 and #results[1].extra.caught == 3, "Loop result lists the three caught Sparks")
check(results[1].extra.points >= 1 and type(results[1].extra.techs) == "table", "Loop result carries server points and techniques")
check(p:GetAttribute("SparkParade") ~= "", "Parade attribute replicated")
-- Bank by running THROUGH the south gate ring (no button, no stop).
local ring = s.bankPosition
check(ring ~= nil and math.abs(ring.Z - 58) < 0.5, "Bank ring position delivered (south gate)")
h:runThroughRing(p, ring)
e.advance(0.5)
s = h:state(p)
check(s.carry == 0 and s.profile.totalBanked == 3, "Banked three (carry=" .. s.carry .. ", banked=" .. s.profile.totalBanked .. ")")
check(s.profile.coins > 0 and p:GetAttribute("SparkGlow") == s.profile.coins, "Glow awarded " .. s.profile.coins)
check(#h:creatures(mine) == 0, "Starters cleared after onboarding")
local banks = h:feedbackOf(p, "Bank")
check(#banks >= 1 and banks[#banks].extra.ring == "south_gate" and banks[#banks].extra.multiplier == 1, "Bank feedback names the ring and tier")
check((s.mastery and s.mastery.score or 0) > 0, "Round score includes loop and bank points")
-- After onboarding the hazard timeline starts fresh; statics need 25s more.
check(s.objective ~= nil and s.rank ~= nil and s.stats ~= nil and s.encounter ~= nil, "v2 HUD fields present")
print(string.format("INFO onboarding: join->3 starters caught %.2fs (circle %.2fs), ->bank %.2fs (scripted walker, not human timing)", caughtAt - joinedAt, caughtAt - circleStarted, e.now - joinedAt))
h:assertClean("onboarding")
h:report("solo-onboarding")
print("PASS ScenarioB_SoloOnboarding: " .. Harness.count() .. " checks")
