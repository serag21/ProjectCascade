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
-- Drive a short session end to end with the REAL client modules: the client's own
-- Ribbon draws from the character position every frame, closes with
-- Loop.tryClose and sends the claim; the bot only walks a circle (WP-03/04).
local dashAction
for name, binding in pairs(e.boundActions) do
	for _, input in ipairs(binding.inputs) do
		if tostring(input) == "Enum.KeyCode.E" then dashAction = name end
	end
end
check(dashAction == "SparkDash", "KeyCode.E is bound to dash, not catch (" .. tostring(dashAction) .. ")")
local catchBinding = false
for name in pairs(e.boundActions) do if string.find(string.lower(name), "capture", 1, true) then catchBinding = true end end
check(not catchBinding, "No catch binding exists")
local mine = function(m) return m:GetAttribute("StarterOwnerId") == p.UserId end
local centre = Harness.Vector3.new(0, 0, 0)
local starters = h:creatures(mine)
check(#starters == 3, "three starters")
for _, m in ipairs(starters) do centre += m:GetPivot().Position / #starters end
local radius = 6
h:walkTo(p, Harness.Vector3.new(centre.X + radius, 3, centre.Z), 6)
local angle, dt = 0, 1 / 30
for _ = 1, 120 do
	angle += 21 * dt / radius
	e.walkToward(p, Harness.Vector3.new(centre.X + math.cos(angle) * radius, 3, centre.Z + math.sin(angle) * radius), 22, dt)
	e.step(dt)
	if (h:state(p).carry or 0) >= 3 then break end
end
e.advance(0.6)
s = h:state(p)
check(s.carry == 3, "The client's own ribbon caught the starter pod (" .. s.carry .. ")")
local claims = 0
for _, entry in ipairs(e.remoteLog) do
	if entry.remote == "Action" and entry.args and entry.args[1] == "Loop" then claims += 1 end
end
-- Dash through the client's own binding (motion is client-side; server budgets it).
e.asClient(p, function() e.pressAction(dashAction) end)
e.advance(0.3)
local ring = s.bankPosition
h:runThroughRing(p, ring)
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
-- Daily Stampede is off in the Checkpoint 1 slice (tuning.features.trialEnabled
-- = false, WP-04 until WP-15): a start request is refused and changes nothing.
h:send(p, "Play"); e.advance(0.3)
check(h:awaitPlaying({p}, 20), "Round 2 starts (" .. tostring(h:state(p).phase) .. ")")
h:playRound(p, {timeout = 125})
e.advance(1)
h:send(p, "Trial", "start"); e.advance(1)
check(h:state(p).mode ~= "trial", "Daily Stampede stays off in the slice")
h:assertClean("client round 2")
-- T-FX1: effect parts are pooled; the whole SparkFx folder (every pool, visible or
-- not) stays within the 80-part budget after a full session of loops and banks.
local fx = e.workspace:FindFirstChild("SparkFx")
local fxParts = 0
if fx then for _, d in ipairs(fx:GetDescendants()) do if d:IsA("BasePart") then fxParts += 1 end end end
check(fx ~= nil and fxParts <= 80, "Effect parts within budget (" .. fxParts .. " <= 80)")
local creaturesFolder = e.workspace:FindFirstChild("SparkCreatures")
check(creaturesFolder ~= nil and #creaturesFolder:GetChildren() > 0, "Client built creatures from HerdNet v2 (" .. (creaturesFolder and #creaturesFolder:GetChildren() or 0) .. ")")
print("INFO client fx parts " .. fxParts)
h:report("client-boot")
print("PASS ScenarioG_ClientBoot: " .. Harness.count() .. " checks")
