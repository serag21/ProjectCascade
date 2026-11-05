--!nocheck
-- (g) Client LocalScript boots against the fake engine alongside the real
-- server: HUD construction, Ready handshake, state/feedback handling, bound
-- actions and panels. Structure-tolerant (UI is in active development); strict
-- on script errors and API misuse. No rendering, layout or input-device proof.
local Harness = require("./Harness")
local check = Harness.check
local h = Harness.boot()
local e = h.engine
local p = e.addPlayer(7001)
e.spawnCharacter(p)
e.startClient(p)
e.advance(3)
h:assertClean("client boot")
local gui = p.PlayerGui:FindFirstChildWhichIsA("ScreenGui")
check(gui ~= nil, "Client created a ScreenGui")
local s = h:state(p)
check(s and s.phase == "Playing", "Client Ready handshake started the round (" .. tostring(s and s.phase) .. ")")
local guiObjects = 0
for _, d in ipairs(p.PlayerGui:GetDescendants()) do if d:IsA("GuiObject") then guiObjects += 1 end end
check(guiObjects > 20, "HUD built (" .. guiObjects .. " GuiObjects)")
-- State payloads reached the client: some label shows the round timer.
local timerShown = false
for _, d in ipairs(p.PlayerGui:GetDescendants()) do
	if d:IsA("TextLabel") and string.match(d.Text, "^%d:%d%d") then timerShown = true end
end
check(timerShown, "Client rendered a round timer from server State")
-- Bound actions route to the server through the real remote.
local actions = {}
for name in pairs(e.boundActions) do table.insert(actions, name) end
table.sort(actions)
print("INFO bound actions: " .. table.concat(actions, ", "))
check(#actions >= 3, "Gameplay actions bound")
-- Drive a short session: walk to starters and use the client's own bindings.
local captureAction
for name, binding in pairs(e.boundActions) do
	for _, input in ipairs(binding.inputs) do
		if tostring(input) == "Enum.KeyCode.E" then captureAction = name end
	end
end
check(captureAction ~= nil, "A binding uses KeyCode.E for catch")
local mine = function(m) return m:GetAttribute("StarterOwnerId") == p.UserId end
for _ = 1, 3 do
	local target = h:nearest(h:position(p), mine)
	if not target then break end
	h:walkTo(p, target:GetPivot().Position, 4)
	e.asClient(p, function() e.pressAction(captureAction) end)
	e.advance(0.8)
end
h:walkTo(p, Harness.Vector3.new(0, 3, 40), 6)
e.advance(1)
h:assertClean("client session")
s = h:state(p)
check(s.profile.totalBanked >= 1, "Client-driven catches banked (" .. s.profile.totalBanked .. ")")
-- Open every menu panel via any bound menu action, then let state refreshes run.
for name in pairs(e.boundActions) do
	if string.find(string.lower(name), "menu", 1, true) then
		e.asClient(p, function() e.pressAction(name) end); e.advance(0.6)
		e.asClient(p, function() e.pressAction(name) end); e.advance(0.6)
	end
end
-- Click every visible TextButton once (Activated), as a smoke for handlers.
local clicked = 0
for _, d in ipairs(p.PlayerGui:GetDescendants()) do
	if d:IsA("TextButton") or d:IsA("ImageButton") then
		e.asClient(p, function() e.fire(e.eventSignal(d, "Activated")) end)
		clicked += 1
		e.advance(0.1)
	end
end
e.advance(2)
h:assertClean("button smoke")
print("INFO client: buttons activated=" .. clicked .. " guiObjects=" .. guiObjects)
-- Play out the round with the server bot logic while the client renders state.
h:playRound(p, {timeout = 125})
e.advance(2)
h:assertClean("client full round")
check(h:state(p).phase == "Results", "Results reached with client attached")
-- Daily Stampede with the client attached: unlock (round 2), run the trial
-- (arena 4 herd packets, trial HUD/results), then LEAVE through the client's button.
-- (The button smoke above pressed SIT OUT; PLAY clears it.)
h:send(p, "Play"); e.advance(0.3)
check(h:awaitPlaying({p}, 20), "Round 2 starts (" .. tostring(h:state(p).phase) .. ")")
h:playRound(p, {timeout = 125})
e.advance(1)
check(h:state(p).profile.rounds >= 2 and h:state(p).trial.available == true, "Trial unlocked with client attached")
h:send(p, "Trial", "start"); e.advance(1)
check(h:state(p).mode == "trial", "Trial run started")
h:playRound(p, {timeout = 80})
e.advance(1.5)
h:assertClean("client trial run")
local r = h:state(p)
check(r.phase == "Results" and r.lastResult and r.lastResult.trial, "Trial results reached with client attached")
local leave, title
for _, d in ipairs(p.PlayerGui:GetDescendants()) do
	if d.Name == "TrialLeaveButton" then leave = d end
	if d.Name == "Title" and d:IsA("TextLabel") and d.Parent and d.Parent.Name == "Results" then title = d.Text end
end
check(leave ~= nil and leave.Visible, "Trial results show LEAVE")
print("INFO client trial results title: " .. tostring(title))
e.asClient(p, function() e.fire(e.eventSignal(leave, "Activated")) end)
e.advance(1)
h:assertClean("client trial leave")
check(h:state(p).mode == "cycle" and h:state(p).biome == 1, "Client LEAVE returns to the shared cycle")
h:report("client-boot")
print("PASS ScenarioG_ClientBoot: " .. Harness.count() .. " checks")
