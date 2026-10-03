export type WorldState = {
    power: boolean,
    access: string,
    environment: string,
    lighting: string,
    security: string,
    objective: string,
    cascade: boolean,
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
        access = "Entrance",
        environment = "Normal",
        lighting = "Normal",
        security = "Idle",
        objective = "RestorePower",
        cascade = false,
    }
end

function CascadeState.apply(state: WorldState, action: string): ActionResult
    local events = {}

    if action == "RestorePower" then
        if state.power then
            return { ok = false, events = {}, message = "Power is already restored." }
        end

        state.power = true
        state.access = "Maintenance"
        state.lighting = "Facility"
        state.objective = "ReachArray"

        table.insert(events, "PowerRestored")
        table.insert(events, "DoorOpened")

        return {
            ok = true,
            events = events,
            message = "Primary power restored.",
        }
    end

    if action == "ActivateArray" then
        if not state.power then
            return { ok = false, events = {}, message = "The array has no power." }
        end

        if state.objective ~= "ReachArray" then
            return { ok = false, events = {}, message = "The array cannot be activated right now." }
        end

        state.access = "Transformed"
        state.environment = "Unstable"
        state.lighting = "Emergency"
        state.security = "Alert"
        state.objective = "TransmitSignal"
        state.cascade = true

        table.insert(events, "EnvironmentChanged")
        table.insert(events, "CascadeStarted")
        table.insert(events, "ObjectiveAdvanced")

        return {
            ok = true,
            events = events,
            message = "Observation array activated. The facility is destabilizing.",
        }
    end

    if action == "TransmitSignal" then
        if state.objective ~= "TransmitSignal" then
            return { ok = false, events = {}, message = "The signal console is not ready." }
        end

        state.objective = "Escape"
        table.insert(events, "ObjectiveAdvanced")

        return {
            ok = true,
            events = events,
            message = "Recovery signal transmitted. Escape the facility.",
        }
    end

    if action == "Escape" then
        if state.objective ~= "Escape" then
            return { ok = false, events = {}, message = "The evacuation route is not available yet." }
        end

        state.objective = "Complete"
        table.insert(events, "RunCompleted")

        return {
            ok = true,
            events = events,
            message = "Run complete.",
        }
    end

    return {
        ok = false,
        events = {},
        message = `Unknown action: {action}`,
    }
end

return CascadeState
