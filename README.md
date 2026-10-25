# Game #1 — SPARK STAMPEDE (working title)

**Product pivot approved October 24, 2026.** This repository is being repurposed IN PLACE for the first production Roblox game, a bright action/collection game optimized for immediate understanding, replay, 1–4-player enjoyment and professional release quality. The original atmospheric facility game Project Cascade is preserved unchanged on [the archive branch](https://github.com/serag21/ProjectCascade/tree/archive/cascade-pre-game1-pivot-20261024).

**Codex startup:** Read [AGENTS.md](AGENTS.md), [Game #1 product charter](docs/GAME1_PRODUCT_CHARTER.md), and [progress tracker](docs/GAME1_PROGRESS.md). The files and game scripts described below are the LEGACY Cascade state until the replacement implementation is complete. Do not interpret the legacy MVP instructions as current Game #1 requirements.

---

## Historical Project Cascade README (archived idea; not current product)

**Current internal milestone: Site 07 — Field Playtest 04 (bootstrap recovery)**

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


## Site 07 startup safety (Playtest 04)

- The server resolves `CascadeState` even if an earlier Script Sync mistake left it nested under another `Cascade` folder; it warns when it has to recover from that layout.
- A safety floor remains below the site during construction and is removed only after a successful build. An initialization failure produces a visible red diagnostic sign and sets `Workspace.CascadeBuildStatus` / `Workspace.CascadeBuildError`.
- The client HUD reports a failed or incomplete server build after 12 seconds instead of leaving an unexplained flashlight-only session.
- The containment subject stays dormant without pathfinding until the array releases it, avoiding background path computations during the opening exploration phase.
- A successful session ends startup with `Workspace.CascadeBuildStatus = "Ready"` and `CascadeFacility.BuildVersion = 4`.

The actual in-Studio server/client playtest is still required to verify Roblox runtime behavior and audio asset permissions.

 
## Site 07 visibility tuning

The opening uses slightly brighter cool ambient fill, softer atmospheric attenuation, eight low-output local guide lights, and a wider/stronger flashlight. The facility is still unpowered at the start, ceiling fixtures remain off until power is restored, and the containment/cascade state retains darker lighting and alarms. Guide lights use non-shadowing point lights to keep the added cost modest.
