# 13 — The route: first integrated slice to release candidate

One ordered path for the lead implementer (Opus). Machine-readable version with dependencies and acceptance lists: `data/work_packages.json` (`order` field). Interfaces: `08`. Catch resolution and vectors: `10`. Slice contents: `data/slice.json`. Checkpoint scripts and pass rules: `09`.

## 1. Before starting

- Read `AGENTS.md`. Agents do not run Studio, a local server, or any GUI automation. Everything below is verified offline with `python3 tools/run_checks.py`; the owner runs Studio at the three checkpoints.
- Branch from `claude/awesome-brown-27rwqo` (`b1b62fd`). Do not touch `archive/*`, `backups/`, or `main`. This design branch is reference only.
- All numbers come from the generated `R/Design/*` modules. Never retype a number from a document.
- One package at a time, in order. A package is done when its `accept` list holds and `run_checks.py` is green. A legacy test for behaviour a package removes is ported or deleted in that package, and the report says so.
- Report what was built and what passed. Do not report that anything is fun, smooth or readable; only the owner's play can say that.

## 2. Defaults for every open choice

When the documents leave something open, use this and move on.

| Question | Default | Change it when |
| --- | --- | --- |
| Terrain or parts for the ground | Roblox Terrain | Server start > 5 s or M1 fails in Studio → set `features.worldPartsOnly` |
| Camera | Raised chase, pitch 46°, distance 38 | Checkpoint 1 decision table (`09` §3.4) |
| Creature size | `creatures.globalScale` 1.3 | Checkpoint 1 Q9 |
| Ellipsoid construction | Part + SpecialMesh (Sphere) | Never, unless Studio shows a cheaper equivalent renders identically |
| Textures | Untextured fallbacks | Owner supplies asset ids → `Design.Slice` |
| Audio | Catalog fallbacks; silent where none | Owner uploads → `tools/set_audio_ids.py` |
| Medals | `scoring.medalsProvisional` | WP-14 |
| Snap vs crossing priority | Snap first, crossing as fallback | Never (vectors depend on it) |
| Tolerance, rewind, deferral | 4.0 studs, 0.35 s, 0.25 s | `claimDeviation` p99 from Checkpoint 1 |
| A tuning value seems wrong while implementing | Implement it as written; note the concern in the report | Owner tunes at the checkpoint with the F9 panel |
| A rule is ambiguous | `tools/loop_reference.py` and the vectors win over prose | — |
| Something in `slice.json` → `off` is needed for a later feature to compile | Keep the code path, gate it on the `Design.Slice` flag | Stage 2 |
| Multiplayer in stage 1 | Keep the shared clock and atomic claims working; do not polish | Stage 2 |

## 3. Stage 1 — the core feel slice

Goal: the smallest build that lets the owner judge **movement, herding and ring closure**. Contents are exactly `data/slice.json`.

| # | Package | Build | Pass (all automated) |
| --- | --- | --- | --- |
| 1 | **WP-01** Data pipeline *(delegable)* | `tools/gen_design_data.py` → `R/Design/{Tuning,Creatures,Arenas,Events,Models,Slice}.luau`; `design-data-fresh` and `design-validate` checks | Byte-identical regeneration; ids resolve; checks fail on drift |
| 2 | **WP-02** `Loop.luau` | Port `tools/loop_reference.py` function for function (`08` §2.1). Convert `data/test_vectors.json` to a Luau table | All 59 vectors pass; 1,000 random walks without error |
| 3 | **WP-05** Meadow world *(delegable)* | `WorldKit` builders for the Meadow feature types; Terrain; layered `GroundMap`; client `Decor` + lighting; hedge fade | Every feature id present; `GroundMap` within 0.5 stud of raycasts; ≤ 2,600 parts |
| 4 | **WP-03** Client feel | `Movement` (predicted dash, charges), `SparkCamera` (presets on `[` `]`), `Ribbon` (two Trails, `tryClose` with live head, snap preview, cinch start, claim send). Delete the server dash constraint | No server-created constraint; dash unit tests; ribbon closure matches vectors |
| 5 | **WP-04** Server claims | `LoopService`: path buffer, deferral, `validate`, `resolve` with rewind and level rule, techniques from server data, `Challenge.loop`, overflow, bank rings | Validation/resolution vectors through the service; adversarial set grants nothing; circling bot catches, button bot scores 0 |
| 6 | **WP-06** Herd and creatures | `Herd` state machines for the four Meadow species; `Habitat` pods; 0.5 s creature history; HerdNet v2; `CreatureKit` from `data/models` | No server creature Instances; behaviour specs; traffic budget in the soak |
| 7 | **WP-07** HUD, effects, slice audio, overlay *(delegable)* | `Hud` from `ui_layout.json`; cinch per `cinch_effect.json`; payout tags; the 22 slice cues; 4 new WAVs; F8 overlay v2; F9 tuning panel | Layout smoke test; cue wiring test; generator `--verify` |
| 8 | **WP-08** Events and slice shell | Stampede on arena routes; Bloom Burst; slice results sheet; first-round coaching (ghost ring, three hints); everything in `slice.json` → `off` unreachable | Event timing spec; slice-scope spec; headless run of the Checkpoint 1 script |

**First integrated slice = after step 6.** From then on every package must leave a build the owner could install. **Checkpoint 1 = after step 8.** Hand over: the installer build (existing `tools/build_studio_install.py` flow), `09` §3 as the owner's script, and a one-page report: packages done, checks passed, tests ported or deleted, anything implemented against your better judgment.

Stage 1 is expected to reduce offline coverage temporarily (the old suite tests proximity capture). Say how much in the report.

## 4. Stage 2 — full content

Start only after Checkpoint 1 passes (`09` §3.4). Apply the tuning the owner settled first.

| # | Package | Build | Pass |
| --- | --- | --- | --- |
| 9 | **WP-09** Canyon world *(delegable)* | From `canyon.json`; two `GroundMap` layers under the Arch; arch fade | As WP-05 |
| 10 | **WP-10** Canyon species, geysers | Sunshell, Zip Tail, Prickle, Dune Fin; author `data/models/canyon_creatures.json`; ribbon cuts; launches; movement budget for height | Behaviour specs; cut margin; level-rule vector in the built canyon |
| 11 | **WP-11** Aurora world *(delegable)* | From `aurora.json` | As WP-05; contrast ratios |
| 12 | **WP-12** Ice, wind, Aurora species, Starfall | Glide and wind in `Movement`; per-surface speed budget; four species; author `aurora_creatures.json`; Starfall on arena anchors | Budget accepts on-surface speed and rejects it elsewhere; behaviour specs |
| 13 | **WP-13** Pinch, wraps, Golden, Legends, Static Puff, Profile v4, Loadout | `Loop.tryPinch`; shared wraps; Golden Runaway; three Legends; Puff as ribbon-cutter; Profile v4; perk/Heat re-key; re-enable upgrades, Heat, perks, arena travel | Wrap credit spec; v1–v3 → v4 migration; v5 refused |
| 14 | **WP-20** First Spark | `FirstSpark` service on UTC; glint course; photo finish; winner and tie rules; daily cap; crowns and embers | Two simulated servers agree on the mark; 1–4-player winner specs; photo-finish spec |

**Checkpoint 2** after step 14: `09` §4.

## 5. Stage 3 — re-integration

| # | Package | Build | Pass |
| --- | --- | --- | --- |
| 15 | **WP-14** Progression and economy | Quests, signatures, medals from real rounds + the round model; remove legacy capture kinds | Economy spec; no saved field dropped |
| 16 | **WP-15** Daily Stampede for loops | Trial paddock, seeded pods and stampede, new board key | Trial spec; flag back on |
| 17 | **WP-21** Rotation from data *(delegable)* | Remix re-key, weekly Gauntlet, spotlight, feats, seals | 120-week formula spec; data-only-addition spec |
| 18 | **WP-16** Results, Album, menus, first session *(delegable)* | Full results sheet with Best Loop card; Album tips and feats; menu restyle; first-session script | Layout and funnel instrumentation |
| 19 | **WP-17** Full audio *(delegable)* | Stems B and C, voices, ambience, the real horn | Every `audio_events.json` id has an asset |
| 20 | **WP-18** Tests and performance | Port or remove legacy tests; headless 1/2/4-player scenarios; soak; budget assertions | Suite green with the new scenarios |
| 21 | **WP-19** Docs *(delegable)* | Playtest guide, release checklist, progress file | No unverified feel claims |

**Checkpoint 3** after step 21: `09` §5. Publishing is a separate owner decision.

## 6. What each stage must not do

- **Stage 1:** no Canyon or Aurora work, no Profile changes, no new progression, no tuning by taste. Do not polish multiplayer. Do not add features to make the slice "feel complete".
- **Stage 2:** no economy or menu work beyond re-enabling what the slice hid.
- **Stage 3:** no new mechanics.

## 7. If Checkpoint 1 does not pass

`09` §3.4 maps the owner's answers to one of three responses. The implementer's part in each:

| Response | Implementer does |
| --- | --- |
| **Tune** | Change values in `design/fable/data/tuning.json` within their ranges (the owner will usually have found them with the F9 panel), regenerate, re-run `tools/validate.py` and `run_checks.py`, rebuild. No code change. Re-test |
| **Camera change** | Apply the camera fallback ladder in `01` §6 (preset, then guide ring, then fixed three-quarter camera). `SparkCamera` only |
| **Rethink** | Stop. Do not start stage 2. Write up what the owner reported against the hypotheses in `00` §3 and wait for a design decision |
