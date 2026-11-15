# SPARK STAMPEDE — Fable design package

Build-ready production design for the transformation of Spark Stampede after the failed owner playtest. **Design only: nothing under `game/` is changed by this package.** Baseline: `claude/awesome-brown-27rwqo` @ `b1b62fd`.

**The identity in one line:** *you catch Sparks by running a glowing ring around them — no catch button.*

Nothing in this package proves the game is fun. The first implementation stage ends at a playable Meadow slice that the owner judges in Studio (`09` §3) before anything else is built.

## Deliverables

| File | Contents | Depends on | Primary consumer |
| --- | --- | --- | --- |
| `00_VERDICT_AND_VISION.md` | Verdict on the current build, the identity, research (reported vs hypothesis) | — | Everyone, first |
| `01_CORE_LOOP_AND_CONTROLS.md` | Inputs, ribbon, closing rules, dash, scoring, failure/recovery, camera | `data/tuning.json` | Opus (WP-02/03/04) |
| `02_ARENAS.md` | Three arenas: zones, routes, landmarks, distributions, lighting | `data/arenas/*.json`, `maps/*.svg` | Sonnet (WP-05/09/11) |
| `03_CREATURES.md` | Behaviour model, 12 species, rarity, congestion rules | `data/creatures.json` | Opus (WP-06/10/12) |
| `04_EVENTS_AND_RARES.md` | Round beats, events, Golden, Legends, multiplayer rules | `data/events.json` | Opus (WP-08/13) |
| `05_VISUAL_DIRECTION.md` | Composition, materials, palettes, animation, VFX, camera, UI hierarchy | `data/asset_manifest.json`, `data/ui_layout.json`, `mockups/` | Sonnet (WP-05/07/16) |
| `06_AUDIO.md` | Cue timing, music stems, voices, mix limits | `data/audio_events.json` | Sonnet (WP-07/17) |
| `07_FIRST_SESSION_AND_LONGTERM.md` | 10 s / 30 s / 2 min / 10 min / 1 h script; mastery ladder; long-term | 01–04 | Sonnet (WP-16), Opus (WP-14) |
| `08_IMPLEMENTATION_CONTRACT.md` | Module map, interfaces, security, migration risks, first five briefs, staged order | all | **Start here to implement** |
| `09_VALIDATION_PLAN.md` | Automated requirements, Studio measurements, playtest questions, pass rules | all | Every package; owner at checkpoints |

### Structured data (`data/`)

| File | Contents |
| --- | --- |
| `tuning.json` | Every gameplay number, marked `fixed` or `hyp` with a tuning range; performance budgets |
| `creatures.json` | 12 species (behaviour, telegraph, counterplay, pods, silhouette), golden variant, 3 Legends, hazard |
| `arenas/meadow.json`, `canyon.json`, `aurora.json` | Bounds, elevation, features, bank rings, habitats, pods, routes, event anchors, lighting, palette |
| `events.json` | Round beats and six events with rules, telegraphs, fairness and rewards; removed systems |
| `audio_events.json` | 37 SFX events, creature voices, music stems and states, ambience, comfort limits |
| `ui_layout.json` | HUD elements and exact rectangles for three reference viewports; results and menu rules |
| `asset_manifest.json` | Naming conventions, 27 feature builders with part budgets, creature models, VFX with a part budget |
| `work_packages.json` | 19 work packages in 3 stages: agent, dependencies, files touched, acceptance |

### Visual references (generated from the data; schematic, not renders)

`maps/meadow.svg`, `maps/canyon.svg`, `maps/aurora.svg` · `mockups/hud_desktop.svg`, `mockups/hud_phone.svg` · `mockups/creature_silhouettes.svg` · `mockups/loop_anatomy.svg`

### Tools

```bash
python3 design/fable/tools/validate.py
```

Checks cross-file consistency (species vs live `Config.luau`, arena geometry and clearances, pod caps, event timing, HUD overlap and coverage, VFX budget, work-package dependencies) and regenerates the maps and HUD mockups.

```bash
python3 design/fable/tools/mockups.py
```

Regenerates the creature sheet and loop diagram.

## Reading order by role

- **Owner:** `00`, then `mockups/loop_anatomy.svg`, `maps/*.svg`, then `09` §3.
- **Opus (lead implementer):** `08`, `01`, `data/tuning.json`, `03`, `04`, `09` §1.
- **Sonnet (construction):** `08` §6 for the assigned package, the matching data file, `05`.

## Status of numbers

Values marked `hyp` are starting points chosen by reasoning, not by play. They are expected to move inside their ranges at Checkpoint 1. Values marked `fixed` are contracts other files depend on.
