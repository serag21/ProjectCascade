# Project Cascade

**Current internal milestone: Site 07 — Field Playtest 03**

Project Cascade is a 1–4 player cooperative environmental horror/adventure for Roblox. The core identity is causal environmental gameplay: players change connected facility systems and must adapt to the consequences.

## Current playable slice

- A larger, enclosed, night-lit research facility with entrance hall, power distribution, maintenance/pump room, optional incident archive, observation chamber, signal control room, containment cell, exit corridor, and exterior landing.
- Power restores fixture lighting and wakes machinery.
- Stabilizing drainage lowers visible floodwater and opens the transfer gate to the observation wing.
- Activating the array starts a facility-wide cascade, opens the containment cell, changes the lighting/sound state, and releases a pathfinding creature.
- The creature can see players, pursue via pathfinding, follow last-known positions for a short period, search/patrol when it loses the trail, and damage players when it catches them.
- Transmitting the signal releases the exit route. Reaching the exterior threshold completes the run.
- An optional recovered transcript gives context without adding a mandatory side quest.
- Positional/ambient sound, system alarms, random distant impacts, localized growls/footsteps, and client-side proximity tension effects are part of the playtest.
- HUD communicates the broad mission and environmental state, not a checklist of every interaction.

## Core rule

**Stable landmarks; unstable circumstances.** The player's actions cause environmental changes. The world should communicate consequences through machinery, light, water, doors, sound, and changing routes.

## Source layout

`src/` mirrors the Roblox DataModel for Script Sync.

- `src/ReplicatedStorage/Cascade/CascadeState.luau` — authoritative transition rules.
- `src/ServerScriptService/Cascade/CascadeServer.server.luau` — procedural site construction, interactions, environmental transitions, sounds, and server-side creature AI.
- `src/StarterPlayer/StarterPlayerScripts/Cascade/CascadeUI.client.luau` — mission/status UI, evidence card, environmental feedback, and player-proximity tension effects.
- `tests/CascadeState.spec.luau` — state-transition test script.

## Scope guard

This is still a procedural graybox with placeholder/procedural geometry, not final art. Its purpose is to test a much fuller playable experience: spatial exploration, causal interactions, atmosphere, fear, and a complete chase/escape sequence. Do not add economy, crafting, pets, large progression trees, multiple maps, or monetization before the core run is fun.

## Audio assets

The prototype uses audio from Roblox Creator Store by asset ID. If Roblox reports asset permission/load errors in Studio Output, replace those IDs with suitable Creator Store sounds available to the experience rather than silently shipping a mute mix.
