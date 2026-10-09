# Architecture

## Authority
The server owns the run state, interactions, facility generation, environmental transitions, exit condition, and creature AI. The client owns presentation-only HUD, local tint/blur/FOV/shake, and short UI flashes.

## State sequence
1. RestorePower → lighting online, maintenance door opens, pump machinery starts.
2. StabilizePump → flood level falls, lower route lighting activates, transfer gate opens.
3. ActivateArray → array rotates, emergency state starts, containment opens, signal room opens, creature AI becomes active.
4. TransmitSignal → outer route gate and exit door open, route lights activate.
5. Escape → reaching the exterior threshold completes the run.

Optional ReadArchive returns a transcript but does not gate progression.

## Event architecture
The server emits named events to the client for status, world cues, evidence, proximity threat and completion. Physical systems respond to named state events. The mission text stays broad; feedback and environment teach the intermediate steps.

## Creature
The contained subject is a server-owned humanoid rig. It moves inside containment before release, then uses PathfindingService to pursue visible living players, retains the last visible player position briefly, searches/patrols after losing them, and damages targets at close range. One player's death does not reset the run state.

## Script Sync mapping
Sync each Studio folder to the parent directory that contains its matching folder on disk:

- Studio `ReplicatedStorage/Cascade` ↔ disk `src/ReplicatedStorage`
- Studio `ServerScriptService/Cascade` ↔ disk `src/ServerScriptService`
- Studio `StarterPlayer/StarterPlayerScripts/Cascade` ↔ disk `src/StarterPlayer/StarterPlayerScripts`

The folder itself is named `Cascade`, so syncing to the *parent* keeps the disk hierarchy from becoming `Cascade/Cascade`.

Script Sync maps `.luau` to ModuleScript, `.server.luau` to server Script, and `.client.luau` to client Script. Source changes from Git must reach the local directory first; Script Sync then applies them to Studio.

## Future automation
Add Roblox Open Cloud Luau Execution for state-transition, escape-availability, and multiplayer-resilience tests once the current playtest loop is stable.
