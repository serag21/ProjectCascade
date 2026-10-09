export type WorldState = {
    power: boolean,
    pump: boolean,
    arrayActive: boolean,
    signalSent: boolean,
    escaped: boolean,
    environment: string,
    objective: string,
}

export type ActionResult = {
    ok: boolean,
    events: {string},
    message: string?,
}

local CascadeState = {}

function CascadeState.new(): WorldState
    return {
        power = false,
        pump = false,
        arrayActive = false,
        signalSent = false,
        escaped = false,
        environment = "Dark",
        objective = "Restore the observation array's signal and get out.",
    }
end

function CascadeState.apply(state: WorldState, action: string): ActionResult
    if action == "RestorePower" then
        if state.power then
            return {ok = false, events = {}, message = "The primary grid is already online."}
        end
        state.power = true
        state.environment = "Powered"
        return {
            ok = true,
            events = {"PowerRestored", "MaintenanceDoorOpened", "PumpsStarted"},
            message = "The primary grid has come alive. Something heavy is running below.",
        }
    end

    if action == "StabilizePump" then
        if not state.power then
            return {ok = false, events = {}, message = "The pump controller is dead."}
        end
        if state.pump then
            return {ok = false, events = {}, message = "The drain cycle is already running."}
        end
        state.pump = true
        state.environment = "Draining"
        return {
            ok = true,
            events = {"DrainageStarted", "ArrayRouteOpened"},
            message = "The water level drops. A sealed route groans open.",
        }
    end

    if action == "ActivateArray" then
        if not state.power or not state.pump then
            return {ok = false, events = {}, message = "The array is responding, but the service route is still flooded."}
        end
        if state.arrayActive then
            return {ok = false, events = {}, message = "The array is already active."}
        end
        state.arrayActive = true
        state.environment = "Cascade"
        return {
            ok = true,
            events = {"ArrayActivated", "CascadeStarted", "ContainmentReleased", "SignalRoomOpened"},
            message = "The array locks onto something. The whole facility answers.",
        }
    end

    if action == "TransmitSignal" then
        if not state.arrayActive then
            return {ok = false, events = {}, message = "The signal console has no carrier to transmit."}
        end
        if state.signalSent then
            return {ok = false, events = {}, message = "The recovery signal has already been transmitted."}
        end
        state.signalSent = true
        state.environment = "Emergency"
        return {
            ok = true,
            events = {"SignalTransmitted", "EmergencyExitOpened"},
            message = "Signal away. The facility has begun its emergency purge.",
        }
    end

    if action == "Escape" then
        if not state.signalSent then
            return {ok = false, events = {}, message = "The outer seal is still locked."}
        end
        state.escaped = true
        return {
            ok = true,
            events = {"RunCompleted"},
            message = "You made it out. Something is still moving inside.",
        }
    end

    if action == "ReadArchive" then
        return {
            ok = true,
            events = {"ArchiveRead"},
            message = "INCIDENT 07: The array did not create the signal. It answered one.",
        }
    end

    return {ok = false, events = {}, message = "Unknown action: " .. action}
end

return CascadeState
