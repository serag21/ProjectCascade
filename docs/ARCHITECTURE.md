# Architecture

The MVP treats the facility as a state-driven system.

World state is represented by a small typed state machine:

- power
- access
- environment
- lighting
- security
- objective
- cascade

Interactions request state transitions. The server owns authoritative progression.

State transitions emit named events such as:

- PowerRestored
- DoorOpened
- EnvironmentChanged
- CascadeStarted
- ObjectiveAdvanced
- RunCompleted

The presentation layer consumes those events for HUD toasts, objective updates, lighting, doors, audio/effects, and later analytics.

The initial prototype generates its test facility from server Luau. This keeps iteration fast and makes it possible to test world-state behavior independently of hand-authored geometry.

## Script Sync layout

The repository's `src` tree mirrors three Studio roots:

- `src/ReplicatedStorage/Cascade` → `ReplicatedStorage/Cascade`
- `src/ServerScriptService/Cascade` → `ServerScriptService/Cascade`
- `src/StarterPlayer/StarterPlayerScripts/Cascade` → `StarterPlayer/StarterPlayerScripts/Cascade`

The three `Cascade` folders are **not siblings under one Studio root**. They belong under their respective Roblox services.

## Future automation

Roblox Open Cloud Luau Execution will eventually run state-transition and multiplayer-resilience scenarios headlessly.
