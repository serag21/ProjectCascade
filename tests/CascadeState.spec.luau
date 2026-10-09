local CascadeState = require(game.ReplicatedStorage.Cascade.CascadeState)

local state = CascadeState.new()
assert(state.power == false)
assert(state.pump == false)
assert(state.arrayActive == false)
assert(state.signalSent == false)
assert(state.escaped == false)

local earlyArray = CascadeState.apply(state, "ActivateArray")
assert(not earlyArray.ok)
assert(not state.arrayActive)

local power = CascadeState.apply(state, "RestorePower")
assert(power.ok)
assert(state.power)
assert(table.find(power.events, "PumpsStarted") ~= nil)

local repeatPower = CascadeState.apply(state, "RestorePower")
assert(not repeatPower.ok)

local pumpBeforePower = CascadeState.new()
local earlyPump = CascadeState.apply(pumpBeforePower, "StabilizePump")
assert(not earlyPump.ok)
assert(not pumpBeforePower.pump)

local pump = CascadeState.apply(state, "StabilizePump")
assert(pump.ok)
assert(state.pump)
assert(table.find(pump.events, "ArrayRouteOpened") ~= nil)

local array = CascadeState.apply(state, "ActivateArray")
assert(array.ok)
assert(state.arrayActive)
assert(state.environment == "Cascade")
assert(table.find(array.events, "ContainmentReleased") ~= nil)
assert(table.find(array.events, "SignalRoomOpened") ~= nil)

local signal = CascadeState.apply(state, "TransmitSignal")
assert(signal.ok)
assert(state.signalSent)
assert(table.find(signal.events, "EmergencyExitOpened") ~= nil)

local escape = CascadeState.apply(state, "Escape")
assert(escape.ok)
assert(state.escaped)

local evidence = CascadeState.apply(state, "ReadArchive")
assert(evidence.ok)
assert(evidence.events[1] == "ArchiveRead")

print("CascadeState.spec PASS")
