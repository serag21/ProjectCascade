# Checkpoint 1: Meadow core-feel slice (handoff)

Branch `claude/meadow-stage1-checkpoint1`, cut from design revision `34780fb` (which contains the `b1b62fd` game baseline). Route: `design/fable/13_OPUS_ROUTE.md` stage 1. Scope: `design/fable/data/slice.json`.

**Status:** all eight stage-1 packages are built, and the offline checks pass (see §2). **Nothing has been run in Studio.** No claim is made here that anything is fun, smooth or readable. Only your play can say that. Stage 2 has **not** started.

## 1. Install and verify the revision

1. Fetch and check out the branch (tip SHA in the final message and in `RUN_STATE.json`):
   ```bash
   git fetch origin claude/meadow-stage1-checkpoint1
   ```
   ```bash
   git checkout claude/meadow-stage1-checkpoint1
   ```
2. Save a copy of the dev place first (File → Save to File As…). Leave `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl` untouched.
3. Build the installer (needs the Luau 0.744 CLI in `.tools/luau/`):
   ```bash
   python tools/build_studio_install.py
   ```
   It prints a `buildId` and writes `build/install-spark.luau`, `build/spark-manifest.json` and `build/build-id.txt`. A prebuilt copy from the verified commit is attached to the handoff message.
4. Open Project Cascade [DEV] (place 127090454461830) in **Edit** mode. Paste `build/install-spark.luau` into the Command Bar. It preflights, writes, reads back every source by SHA256, and rolls back on any failure.
5. Start a local test (a separate server and client, not Play Solo, so the client frame time excludes the server). In the client press **F8**. The first line is `BUILD <content hash>-<commit>`, which must equal `build/build-id.txt`. A `-dirty` suffix means the installer was built with uncommitted `game/` changes.

No uploads are needed: textures use the untextured fallbacks, audio uses the built-in placeholders or stays silent (`slice.json` → `cues`), and music stays silent until uploaded. Audio is not judged at this checkpoint.

## 2. What was built (packages, commits, checks)

| # | Package | Commit | What exists now |
| --- | --- | --- | --- |
| 1 | WP-01 data pipeline | `ef8b0dd` | `tools/gen_design_data.py` → `R/Design/{Tuning,Creatures,Events,Arenas,Models,Slice,UiLayout}`; `design-data-fresh` and `design-validate` checks |
| 2 | WP-02 `Loop.luau` | `a43812a` | Port of `loop_reference.py`; all 59 vectors and 1,000 random walks pass |
| 3 | WP-05 Meadow world | `40937b5` | `WorldKit` builders, Terrain from `GroundMap`, hedge, bank rings, client `Decor`, lighting profile, occluder fade |
| 4–5 | WP-03 client feel + WP-04 claims | `b6dc2a6` | Predicted dash, chase camera with `[` `]`, ribbon; `LoopService` (path, deferral, validation, rewind, techniques), `Challenge.loop`, run-through bank rings |
| 6 | WP-06 herd | `201e12f` | `Herd` (Pip, Bunvolt, Cubloom, Flutterwink), `Habitat` pods, HerdNet v2, client-built creatures. **First integrated slice.** |
| 7 | WP-07 HUD/FX/audio/debug | `e4b0db6` | HUD v2, cinch and payout effects, 22 cues + 4 new WAVs, F8 overlay v2 with build ID, F9 tuning panel |
| 8 | WP-08 events and shell | `3315f01` | Bloom Burst, route Stampede, phase names, results sheet, coaching, slice scope end to end |

Offline evidence: `python3 tools/run_checks.py`. The latest report is in `docs/qa/latest-checks.json`, with every check, command, exit code, timestamp and source hash. Run on the handoff commit, it reports 92 checks, all passing, with no sources changed during the run. Headless measurements are scripted bots in a fake engine, not human timing:

- **Events on the shared clock:** Bloom Burst at 25.00 / 30.00 s; Stampede at 49.02 / 53.02 / 55.02 s.
- **One solo bot round:** 423 points (Bronze), best loop 8 (FULL BLOOM), live creatures peaked at 27 (cap 30).
- **Starter pod:** a 6-stud ring catches all three, 2.1 s after starting the circle.
- **4 players × 20 cycles:** herd 1,062 B/s per client (budget 1.2 KB/s), flat instances, bounded threads.
- **Effect parts:** 13 in a client session (budget 80).
- **Arena parts:** 328 for the Meadow plus 1,292 client decor parts (budget 2,600).

### Tests ported, deleted or reduced (stage 1 changes offline coverage)

| Test | Change | Why |
| --- | --- | --- |
| `test_spark_gameplay_integration.py` | Ported: 16 cases now exercise the extracted `handleLoop`/`take`/`bank`/`settleRound`. The capture, dash-through, gate-herding, statics, rally and dash-practice cases were deleted | Those behaviours were removed |
| `test_spark_client_blocks.py` | Legacy HUD layout and starter-visibility blocks deleted | The old HUD is gone, and starters are no longer sent to other clients. Replaced by `SparkHudLayout.spec` |
| Headless B, D, G | Ported to loops (B: ring the starter pod; D: shared-ring contention; G: the real client ribbon catches end to end) | Capture removed |
| Headless A, E | Ported to the new herd (13 pods + private starters; herd bound 14 + 6) | Server creature models removed |
| Headless J | Asserts the Daily Stampede is refused; the full run is kept for WP-15 | `trialEnabled = false` |
| Headless K | Live Aurora travel and Starfall check dropped; layout identity kept | Unreachable in the slice; returns in WP-12 |
| Headless C | Heat refused in the slice | `heat_and_perks` off |
| Headless L | Round-credit bound 18/20 → 8/20 | 4 greedy bots share a 13-creature base herd; measured minimum 10/20 |
| New | `SparkDesignData`, `SparkLoop`, `SparkLoopService`, `SparkMovement`, `SparkHerd`, `SparkHudLayout` specs; headless M (world data), N (loop claims), O (Checkpoint 1 script); `test_spark_slice_static.py` | — |

**Coverage that dropped for now:** proximity-capture scoring paths (removed), the live Daily Stampede run (WP-15), live Starfall/arena travel (WP-12), the legacy HUD layout smoke, and Heat/perk/upgrade effects in live rounds (off in the slice).

### Bug found and fixed during stage 1

A player who stood still for over a second and then drew a ring was rejected with `path-gap`. The server only records a path sample after 2 studs of movement, so standing still looked like lost coverage. Fix: a stationary player refreshes the time of their last path sample (`LoopService.record`). This has its own spec.

### Implemented against my better judgment, or worth your attention

- **Glow is unchanged.** The design pays bank points as glow, but the slice keeps glow on the existing `Profile.bank` formula (Profile stays v3; WP-14 recalibrates). Round **score** follows the design exactly.
- **4-player density.** With only the 13-creature base herd, the weakest of 4 greedy bots got round credit in 10 of 20 cycles. The events help. Multiplayer is not judged at Checkpoint 1, but this is the first lever for Checkpoint 2.
- **Hedge collision** is a 14-stud slab behind the 3.5-stud hedge, so jumps (7.2) cannot leave the arena. The visible hedge is the boundary, but a player who jumps at it will meet a wall taller than it looks.
- **Canyon and Aurora** are still built at server start (legacy layouts, unreachable). If start-up is slow, this is a candidate to remove.
- **Starter Pips** sit on the south lawn at (−12, 48), private and tethered. In round 1 a ghost ring is drawn around them.
- **Bunvolt hops** every 2.6 s, measured crouch to crouch (my reading of "every 2.6 s").
- **Retired modules** (`Targeting`, `Effects`, `Podium`, `ArenaRally`) are left in place without callers. The installer refuses to install over Spark scripts that a build does not manifest, so deleting them would block reinstalling over your current place. They are deleted in WP-18 with an installer step.

### Cannot be verified offline (verify at this checkpoint)

How it looks; Terrain cost and server start time (M8; the server prints a `GroundMap` raycast comparison in Output); real dash feel and input-to-motion (M7); camera readability; non-uniform ellipsoids (SpecialMesh) rendering; bounce caps; occluder fade; whether the built-in fallback sounds play; frame times (M1–M2); claim deviation (M9).

## 3. Your Checkpoint 1 playtest (about 25 minutes, solo)

One question: **are movement, herding and ring closure enjoyable enough to build the rest around?** The full script and pass rule are in `design/fable/09_VALIDATION_PLAN.md` §3.

1. **Round 1, cold.** Read nothing. Note the seconds to your first catch, and whether you understood why it worked (ghost ring + "Run a circle around the Sparks").
2. **Rounds 2–3.** Ring whole pods. Drive the Cubloom block (west, by the stone pens). Run **through** a gold bank ring: one at the south gate, one north past the clover tree. Be at the glowing bloom bud at 0:25–0:30, and on the gold route at 0:49–0:55.
3. **Round 4, dash.** Close rings with a dash (SNAP). Shove a straggler back into a ring. Catch a Bunvolt between hops or during its crouch.
4. **Round 5, camera.** Press `[` and `]` mid-round. Press **F9** and try camera distance 32 and 44, and creature scale 1.15 and 1.45. Leave it where it feels best and note the values.
5. **Round 6 (optional).** In F9 try ribbon lifetime 3.4 and 5.0, snap radius 3.5 and 6, and dash distance 12 and 18.
6. **Measure.** In round 3, read **F8** (frame p50/p95, effect parts, effect instances, creatures, arena parts, herd KB/s, claim deviation p99). Record 10 s of dashing at 60 fps to check that motion starts on the input frame.
7. **Once:** look at a Pip up close and confirm it is an ellipsoid, not a sphere.

Then answer the 12 questions in 09 §3.3 (1–5 each, plus a sentence), with the F9 values you settled on. §3.4 maps your answers to tune, camera change, or rethink. **Stage 2 does not start until you reply.**
