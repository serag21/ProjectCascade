# MVP Specification — Site 07

## Player-facing mission

Restore the observation array's signal. Then get out.

## Current playtest slice

This iteration is intentionally a much fuller playable slice than the first plumbing test. It is still a procedural graybox and not final art, but it is built to evaluate exploration, atmosphere, fear, causal progression, and a full pursuit/escape sequence.

### Areas
- Sealed entrance and reception
- Power distribution and maintenance room
- Pump and water-transfer service room
- Optional incident archive
- Observation chamber with view into the containment cell
- Signal-control room
- Containment wing
- Exit corridor and exterior landing

### Causal chain
1. **Restore primary power.** Lighting and machinery activate; a maintenance blast door opens; the pumps audibly begin running.
2. **Stabilize the drainage system.** Water level drops, route lights switch on, and access to the observation wing opens.
3. **Activate the observation array.** The array physically tilts/rotates; lighting, fog, alarms, and ambience shift. Containment opens and a creature is released.
4. **Transmit the recovery signal.** The outer route and surface access open.
5. **Escape.** Physically cross the exterior threshold to complete the run.

The optional archive provides story evidence without becoming a mandatory detour or another checklist task.

## Interaction and information design

- One persistent broad mission, not a step-by-step list.
- Short event notices explain major consequences; the environment carries most of the information.
- Normal ProximityPrompts on physical consoles; no giant gold target boxes.
- Room signs use consistent, readable text sizes.
- Visible machinery, water, gates, indicators, lights, and sound should make cause/effect legible.

## Atmosphere and threat experiment

- Enclosed night environment, shadowed rooms, restrained fog/color grading, practical lights, emergency state, flicker, steam vents, positional machinery/door/creature sounds, ambient hum, alarm/music on cascade, and distant random impacts.
- One contained subject visibly paces behind glass before the array is activated.
- After release, it can acquire visible players, pursue with pathfinding, retain last-known positions briefly, search/patrol after losing the trail, and damage players at close range.
- Client presentation adds proximity distortion, a restrained red edge, slight blur/FOV effects, and a short sting cue.
- These are prototype systems. Actual audio permission/load behavior, creature pathing quality, tension, and fairness must be tested in Studio; do not assume success just because code is present.

## Hard scope boundaries

Still out of scope: economy, crafting, pets, giant progression trees, full procedural map generation, multiple maps, several monster types, and monetization. We are proving one atmospheric causal loop first.
