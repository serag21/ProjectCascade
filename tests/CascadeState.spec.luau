local CascadeState = require(game.ReplicatedStorage.Cascade.CascadeState)

local state = CascadeState.new()
assert(state.objective == "RestorePower")
assert(state.power == false)
assert(state.pump == false)

local power = CascadeState.apply(state, "RestorePower")
assert(power.ok)
assert(state.power == true)
assert(state.pump == false)
assert(state.objective == "ReachArray")

local pump = CascadeState.apply(state, "StabilizePump")
assert(pump.ok)
assert(state.pump == true)
assert(state.environment == "Draining")
assert(state.objective == "ReachArray")

local array = CascadeState.apply(state, "ActivateArray")
assert(array.ok)
assert(state.environment == "Unstable")
assert(state.cascade == true)
assert(state.objective == "TransmitSignal")

local signal = CascadeState.apply(state, "TransmitSignal")
assert(signal.ok)
assert(state.objective == "Escape")

local escape = CascadeState.apply(state, "Escape")
assert(escape.ok)
assert(state.objective == "Complete")

-- Out-of-order protection.
local bad = CascadeState.new()
local earlyArray = CascadeState.apply(bad, "ActivateArray")
assert(earlyArray.ok == false)
assert(bad.objective == "RestorePower")

print("CascadeState.spec PASS")
