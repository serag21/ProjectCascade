--!nocheck
-- Proves the fake engine rejects what real Roblox rejects; otherwise a passing
-- boot would be meaningless.
local Fake = require("./FakeRoblox")
local n = 0
local function check(ok, message) n += 1; if not ok then error("CHECK FAILED: " .. message, 2) end end
local function rejects(fn, pattern, message)
	local ok, err = pcall(fn)
	check(not ok, message .. " (accepted)")
	if pattern then check(string.find(tostring(err), pattern, 1, true) ~= nil, message .. " (wrong error: " .. tostring(err) .. ")") end
end
local e = Fake.new()
local env = {}
e.mount({["ServerScriptService/Probe.server.luau"] = [[
	_G.probe = {Instance = Instance, Enum = Enum, game = game, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3,
		UDim2 = UDim2, typeof = typeof, workspace = workspace, task = task, type = type}
]]})
e.startServer()
local g = e.globals.server.probe
local I, Enum, game = g.Instance, g.Enum, g.game
check(g.typeof(I.new("Part")) == "Instance" and g.typeof(g.Vector3.zero) == "Vector3" and g.typeof(Enum.Material.Neon) == "EnumItem", "typeof")
check(g.type(g.Vector3.zero) == "vector" and g.type(I.new("Part")) == "userdata" and g.type(Enum.Material.Neon) == "userdata" and g.type({}) == "table", "Roblox type() semantics")
rejects(function() I.new("Partt") end, "Unable to create", "Unknown class")
rejects(function() I.new("Workspace") end, "Unable to create", "Service not creatable")
rejects(function() I.new("Terrain") end, "Unable to create", "NotCreatable")
local p = I.new("Part")
rejects(function() p.Bogus = 1 end, "not a valid member", "Unknown property write")
rejects(function() return p.Bogus end, "not a valid member", "Unknown property read")
rejects(function() p.Material = Enum.Font.Gotham end, "Material", "Wrong enum type")
rejects(function() p.Size = 5 end, "Vector3 expected", "Wrong datatype")
rejects(function() p.Anchored = "yes" end, "bool expected", "Wrong primitive")
rejects(function() p.Color = g.Vector3.zero end, "Color3", "Wrong datatype 2")
rejects(function() p.AssemblyMass = 5 end, "read only", "Read-only")
rejects(function() p.ClassName = "X" end, "read only", "ClassName read-only")
rejects(function() game:GetService("Lighting").Technology = Enum.Technology.Future end, nil, "Security-restricted property")
rejects(function() return Enum.Material.Nope end, "not a valid member", "Unknown enum item")
rejects(function() return Enum.NotAnEnum end, "not a valid member", "Unknown enum")
rejects(function() p:SetAttribute("Bad", {}) end, "not a supported attribute type", "Table attribute")
rejects(function() p:SetAttribute("bad name", 1) end, "invalid", "Attribute name")
rejects(function() p:NotAMethod() end, "not a valid member", "Unknown method")
rejects(function() game:GetService("NotAService") end, "not a valid Service", "Unknown service")
p.Material = "Neon"; check(p.Material == Enum.Material.Neon, "Enum string coercion")
p.Material = Enum.Material.Glass; p.Name = "Probe"; p.Parent = g.workspace
check(g.workspace.Probe == p and g.workspace:FindFirstChild("Probe") == p, "Child lookup by name")
p.Position = g.Vector3.new(1, 2, 3); check(p.CFrame.Position == g.Vector3.new(1, 2, 3), "Position/CFrame coupling")
local m = I.new("Model"); p.Parent = m; m.PrimaryPart = p; m.Parent = g.workspace
m:PivotTo(g.CFrame.new(10, 0, 0)); check((p.Position - g.Vector3.new(10, 0, 0)).Magnitude < 1e-9, "PivotTo moves parts")
rejects(function() m.PrimaryPart = I.new("Folder") end, "BasePart", "Class-typed property")
for i = 1, 20000 do m:PivotTo(g.CFrame.lookAt(g.Vector3.new(i % 7, 2, 0), g.Vector3.new(i % 7 + math.cos(i), 2, math.sin(i))) * g.CFrame.Angles(0, 0, math.sin(i) * 0.08)) end
local drift = p.CFrame
check(drift.Position.X == drift.Position.X and math.abs(drift.LookVector.Magnitude - 1) < 1e-6, "20000 PivotTo calls stay orthonormal and finite")
p:Destroy(); check(p.Parent == nil, "Destroy unparents")
rejects(function() p.Parent = g.workspace end, "locked", "Destroyed parent locked")
rejects(function() m.Parent = m end, nil, "Own parent")
local f = I.new("Folder"); local f2 = I.new("Folder", f)
rejects(function() f.Parent = f2 end, "circular", "Circular parent")
local ui = I.new("TextLabel"); ui.Font = Enum.Font.GothamBold; ui.TextXAlignment = Enum.TextXAlignment.Left
rejects(function() ui.TextXAlignment = Enum.TextYAlignment.Top end, nil, "Similar enum type rejected")
-- Remote payload validation records issues.
local remote = I.new("RemoteEvent"); remote.Parent = game:GetService("ReplicatedStorage")
local player = e.addPlayer(77)
e.spawn(function() remote:FireClient(player, {1, 2, x = 3}, {[1] = 1, [3] = 3}, function() end) end, e.serverContext)
check(#e.remoteIssues == 3, "Mixed/sparse/function remote payload issues: " .. #e.remoteIssues)
-- Scheduler: task.wait/delay advance on virtual time only.
local woke, delayed = nil, false
e.spawn(function() g.task.wait(2); woke = e.now end, e.serverContext)
g.task.delay(1, function() delayed = true end)
e.advance(0.9); check(not delayed and woke == nil, "Nothing early")
e.advance(1.3); check(delayed and woke and woke >= 2 and woke < 2.1, "Timers fire on virtual time")
check(#e.errors == 0, "No stray errors: " .. tostring(e.errors[1]))
print("PASS Scenario0_EngineSelfTest: " .. n .. " checks (fake engine rejects invalid API usage)")
