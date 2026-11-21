--!nocheck
-- (d) 2 and 4 concurrent bot players, same-target contention, mid-round leave
-- with final save, rejoin restore, late join, and BindToClose.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine

-- Contention (WP-04): two players ring the same creature from opposite sides and
-- their claims arrive together. Removed models must equal the total carried
-- increase (atomic claims: never a double catch).
local a = h:join(3001)
local b = h:join(3002)
h:send(a, "Replay"); h:send(b, "Replay")
local ordinary = function(m) return m:GetAttribute("StarterOwnerId") == nil and math.abs(m:GetPivot().Position.X) < 90 end
local caughtTotal = 0
for attempt = 1, 8 do
	local target = h:nearest(h:position(a), ordinary)
	local before = {}
	for _, m in ipairs(h:creatures()) do before[m] = true end
	local carryA, carryB = h:state(a).carry, h:state(b).carry
	h:pairRing(a, b, target:GetPivot().Position, 6)
	e.advance(0.6)
	local removed, now = 0, {}
	for _, m in ipairs(h:creatures()) do now[m] = true end
	for m in pairs(before) do if not now[m] and not m:GetAttribute("StarterOwnerId") then removed += 1 end end
	local gained = (h:state(a).carry - carryA) + (h:state(b).carry - carryB)
	check(gained <= removed, "No duplicate: gained " .. gained .. " vs removed " .. removed)
	caughtTotal += gained
end
print("INFO contention: shared-ring catches " .. caughtTotal)
h:assertClean("contention")

-- Late joiners: four players total, play concurrently for a full round.
local c = h:join(3003)
local d = h:join(3004)
local all = {a, b, c, d}
local result = h:playRounds(all, {timeout = 125})
h:assertClean("four players")
local totals = {}
for _, player in ipairs(all) do
	local s = h:state(player)
	check(s.phase == "Results", player.Name .. " reached Results (" .. s.phase .. ")")
	table.insert(totals, string.format("%s:c%d/b%d/score%d", player.Name, result[player].captures, result[player].banks, s.mastery.score))
end
print("INFO four-player round: " .. table.concat(totals, " "))

-- Mid-round leave: player c leaves while carrying; final save banks the carry.
check(h:awaitPlaying({c, d}, 15), "Both players start the next shared round together")
h:playRounds({c, d}, {timeout = 25, bankAt = 99})
local carrying = h:state(c).carry
local bankedBefore = h:state(c).profile.totalBanked
e.removePlayer(c)
-- Wait past the 4s spook window: Main credits gate herding by UserId, so a
-- same-user rejoin inside it can inherit the departed session's spooks (reported).
e.advance(5)
h:assertClean("leave")
check(h:state(d).phase == "Playing", "Remaining player unaffected by departure")
-- Rejoin the same user on this server: Studio memory store must restore the save.
local c2 = h:join(3003)
local restored = h:state(c2)
check(restored and restored.profile.totalBanked == bankedBefore + carrying,
	string.format("Rejoin restores banked=%d (+%d carried at departure) got %s", bankedBefore, carrying, tostring(restored and restored.profile.totalBanked)))
check(restored.profile.rounds >= 1, "Rounds restored")
check(restored.startersRemaining == 0, "No starter refill for returning player")
-- Kick path / leave during load is covered by pure lifecycle tests; here BindToClose:
local ok, seconds = e.shutdown(30)
check(ok, "BindToClose completed")
print(string.format("INFO shutdown: completed in %.2fs virtual", seconds))
h:assertClean("shutdown")
h:report("multiplayer")
print("PASS ScenarioD_Multiplayer: " .. Harness.count() .. " checks")
