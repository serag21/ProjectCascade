local CascadeState = require(game.ReplicatedStorage.Cascade.CascadeState)

local state = CascadeState.new()
assert(state.objective == "RestorePower")

local power = CascadeState.apply(state, "RestorePower")
assert(power.ok)
assert(state.power == true)
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

print("CascadeState.spec PASS")
