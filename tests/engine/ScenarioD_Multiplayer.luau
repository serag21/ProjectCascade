--!nocheck
-- (d) 2 and 4 concurrent bot players, same-target contention, mid-round leave
-- with final save, rejoin restore, late join, and BindToClose.
local Harness = require("./Harness")
local check = Harness.check
local Vector3 = Harness.Vector3
local h = Harness.boot()
local e = h.engine

-- Contention: two players stand next to the same creature and press Capture in
-- the same frame. Removed models must equal total carried increase (no dupes).
local a = h:join(3001)
local b = h:join(3002)
h:send(a, "Replay"); h:send(b, "Replay")
local ordinary = function(m) return m:GetAttribute("StarterOwnerId") == nil and math.abs(m:GetPivot().Position.X) < 60 end
local contested = 0
for attempt = 1, 12 do
	local target = h:nearest(Vector3.new(0, 3, 0), ordinary)
	local position = target:GetPivot().Position
	-- Teleporting characters would trip movement validation; walk both there.
	for _ = 1, 400 do
		position = target.Parent and target:GetPivot().Position or position
		local doneA = e.walkToward(a, position + Vector3.new(1, 0, 0), 21, 1 / 30)
		local doneB = e.walkToward(b, position - Vector3.new(1, 0, 0), 21, 1 / 30)
		e.step(1 / 30)
		if (h:position(a) - position).Magnitude < 2.5 and (h:position(b) - position).Magnitude < 2.5 then break end
	end
	local before = {}
	for _, m in ipairs(h:creatures()) do before[m] = true end
	local carryA, carryB = h:state(a).carry, h:state(b).carry
	h:send(a, "Capture"); h:send(b, "Capture")
	e.step(1 / 30)
	local removed = 0
	local now = {}
	for _, m in ipairs(h:creatures()) do now[m] = true end
	for m in pairs(before) do if not now[m] then removed += 1 end end
	local gained = (h:state(a).carry - carryA) + (h:state(b).carry - carryB)
	check(gained == removed, "No duplicate: gained " .. gained .. " vs removed " .. removed)
	if gained > 0 and target.Parent == nil then contested += 1 end
	e.advance(0.8)
end
check(contested >= 1, "At least one truly contested capture resolved (" .. contested .. ")")
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
