# SPARK STAMPEDE — Fable design package (revision 2)

Build-ready production design for the transformation of Spark Stampede after the failed owner playtest. **Design only: nothing under `game/` is changed by this package.** Baseline: `claude/awesome-brown-27rwqo` @ `b1b62fd`.

**The identity in one line:** *you catch Sparks by running a glowing ring around them — no catch button.*

Nothing here proves the game is fun. Stage 1 ends at a playable Meadow slice that the owner judges in Studio (`09` §3) before anything else is built.

## Start here

| You are | Read |
| --- | --- |
| **Owner** | `00`, `mockups/meadow_gameplay_frame.png`, `mockups/loop_anatomy.svg`, then `09` §3 (the Checkpoint 1 script) |
| **Opus (lead implementer)** | `13` (the route), `08` (interfaces), `10` (catch resolution and vectors), `data/slice.json`, then `01`, `03` |
| **Sonnet (delegated package)** | The package's row in `13`, its brief in `08` §6 if it has one, the matching data file, `05`, `11` |

## Documents

| File | Contents | Depends on |
| --- | --- | --- |
| `00_VERDICT_AND_VISION.md` | Verdict on the current build (corrected baseline), the identity, research, hypotheses | — |
| `01_CORE_LOOP_AND_CONTROLS.md` | Inputs, ribbon, closing, dash, scoring, failure and recovery, camera | `data/tuning.json`, `tools/loop_reference.py` |
| `02_ARENAS.md` | Three arenas: zones, routes, landmarks, distributions, lighting | `data/arenas/*.json`, `maps/*.svg` |
| `03_CREATURES.md` | Behaviour model, 12 species, rarity, congestion rules | `data/creatures.json`, `data/models/` |
| `04_EVENTS_AND_RARES.md` | Round beats, events, Golden, Legends, multiplayer rules | `data/events.json` |
| `05_VISUAL_DIRECTION.md` | Composition, materials, palettes, animation, VFX, camera, UI hierarchy | `data/asset_manifest.json`, `data/ui_layout.json`, `mockups/` |
| `06_AUDIO.md` | Cue timing, music stems, voices, mix limits, slice audio | `data/audio_events.json` |
| `07_FIRST_SESSION_AND_LONGTERM.md` | First 10 s / 30 s / 2 min / 10 min / hour, with what exists in the slice; mastery ladder | `data/slice.json` |
| `08_IMPLEMENTATION_CONTRACT.md` | Module map, interfaces, security summary, perk/upgrade re-key, risks, first five briefs | all |
| `09_VALIDATION_PLAN.md` | Automated requirements, Studio measurements, three checkpoints, feedback → action table | all |
| `10_PLAY_PATTERNS_AND_CATCH_RESOLUTION.md` | Round model for four play patterns, the rule changes it forced, server reconstruction, heights, latency, test vectors | `tools/`, `data/test_vectors.json` |
| `11_MEADOW_PRODUCTION_REFERENCE.md` | The gameplay frame, Pip construction, cinch, textures, slice cues and audio, remaining production work, corrected performance baseline and how to measure | `mockups/`, `assets/`, `data/models/` |
| `12_CONTEST_AND_ROTATION.md` | The First Spark (single-winner contest), week-four design, weekly rotation, feats | `data/first_spark.json`, `data/rotation.json` |
| `13_OPUS_ROUTE.md` | One ordered route through all 21 packages with pass criteria, defaults, and what to do if Checkpoint 1 fails | `data/work_packages.json` |

## Structured data (`data/`)

| File | Contents |
| --- | --- |
| `tuning.json` | Every gameplay number (`fixed` or `hyp` with a range), camera, performance budgets with corrected baselines, feature flags, provisional medals |
| `creatures.json` | 12 species (behaviour, telegraph, counterplay, pods, silhouette, solo TIGHT thresholds), golden variant, 3 Legends, hazard |
| `models/meadow_creatures.json` | Build-ready part lists and poses for Pip, Bunvolt, Cubloom, Flutterwink |
| `models/cinch_effect.json` | The capture celebration as a timeline |
| `arenas/{meadow,canyon,aurora}.json` | Bounds, elevation, features, bank rings, habitats, pods, routes (incl. First Spark glints), event anchors, lighting, palette |
| `events.json` | Round beats and six events; removed systems |
| `first_spark.json` | The single-winner contest: schedule, course, capture, winner, eligibility, rewards, fairness |
| `rotation.json` | Weekly remix / gauntlet / spotlight formulas, 5 gauntlets, 21 feats |
| `slice.json` | Exactly what Checkpoint 1 contains: in / stubbed / off, 22 audio cues, visual cues, defaults |
| `audio_events.json` | 37 SFX events, creature voices, music stems and states, ambience, comfort limits |
| `ui_layout.json` | HUD elements and rectangles for three viewports |
| `asset_manifest.json` | Naming, 27 feature builders with part budgets, creature models, VFX budget, textures |
| `work_packages.json` | 21 packages with `order`, stage, dependencies, files touched, acceptance |
| `test_vectors.json` | 59 generated vectors: closure, containment, validation, resolution, scoring, bank, chain |
| `play_model_results.json` | Round-model output for four play patterns under old and current rules |

## Visual references and assets

| Kind | Files |
| --- | --- |
| Rendered (three.js from the data; not game screenshots) | `mockups/meadow_gameplay_frame.png`, `mockups/camera_pitch_comparison.png`, `mockups/pip_reference_sheet.png`, `mockups/cinch_storyboard.png` |
| Schematic | `maps/meadow.svg`, `maps/canyon.svg`, `maps/aurora.svg`, `mockups/hud_desktop.svg`, `mockups/hud_phone.svg`, `mockups/creature_silhouettes.svg`, `mockups/loop_anatomy.svg` |
| Import-ready textures (not yet uploaded to Roblox) | `assets/textures/*.png` + `manifest.json` |

## Tools

```bash
python3 design/fable/tools/validate.py
```

Checks everything against everything: species vs the live `Config.luau`, arena geometry and clearances, pod caps, glint spacing, event timing, HUD overlap and coverage, VFX budget, model part lists vs silhouettes, audio keys vs the live `AudioCatalog.luau`, slice scope references, contest and rotation data, work-package order, file and package references inside the documents; regenerates and verifies the test vectors; re-runs the round model and asserts that farming singles does not beat herding; re-renders the maps and HUD mockups.

| Tool | Purpose |
| --- | --- |
| `tools/loop_reference.py` | Executable spec for ribbon, closure, validation, resolution and scoring |
| `tools/gen_test_vectors.py` | Regenerates `data/test_vectors.json` from the reference |
| `tools/play_model.py` | Round model (`--write` refreshes the results file) |
| `tools/mockups.py` | Silhouette sheet and loop diagram |
| `tools/make_textures.py` | Effect textures (Pillow + numpy) |
| `tools/render_refs.js` | Rendered references (needs Playwright's Chromium and `three@0.160` — pass the path to `three.min.js`) |

## Status of numbers

`hyp` values are starting points chosen by reasoning, a model or a reference render — not by play. They are expected to move inside their ranges at Checkpoint 1. `fixed` values are contracts other files depend on.
