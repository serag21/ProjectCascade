# 08 — Implementation contract

For the implementing agents (Opus, Sonnet). Work-package list with dependencies and acceptance criteria: `data/work_packages.json`. Paths: `R/` = `game/ReplicatedStorage/Spark/`, `S/` = `game/ServerScriptService/Spark/`, `C/` = `game/StarterPlayer/StarterPlayerScripts/Spark/`. Line references are to baseline `b1b62fd`.

Ground rules for every package:

- Read `AGENTS.md` first. No Studio play mode, no local server, no GUI automation. Offline checks only (`python3 tools/run_checks.py`); the owner runs Studio at checkpoints.
- Implement on a new branch from `claude/awesome-brown-27rwqo`. Do not touch `archive/*`, `backups/`, or `main`.
- Design numbers are read from the generated `R/Design/*` modules (WP-01), never retyped.
- `run_checks.py` must be green at the end of each package. A legacy test for behaviour a package removes is ported or deleted in that same package, with the reason in the commit message.
- Do not report anything as fun, smooth or readable. Report what was built and which checks passed.

## 1. Module map: current → change

| Module (baseline) | Change | Package |
| --- | --- | --- |
| `R/Config.luau` | Keep ids and saved-data tables. `CaptureRadius`, `CaptureCooldown`, `DashCooldown`, `MaxCarry`, `WalkSpeed` become reads from `Design.Tuning`. `Creatures[*].behavior/speed/shape` superseded by `Design.Creatures`. Quest text/targets revised in WP-14 | 01, 14 |
| `R/Targeting.luau` | Retired. `measure`/`sweep` have no callers after WP-04; delete with their spec in WP-18 | 04, 18 |
| `R/Loop.luau` | **New.** Pure ribbon/loop geometry (§2.1) | 02 |
| `R/Rules.luau` | `movement`: dash constant 65 → `Tuning.dash.serverBudgetPeakSpeed`; `limits.radius` circle → arena bounds polygon; per-surface speed (ice, wind) in WP-12. `canCapture`: new kind `"loop"` skips the distance test (containment already proved). `herdSpawn`, `outsideBank` retired with pods | 03, 04, 06, 12 |
| `R/Challenge.luau` | Add `Challenge.loop` (§2.3). `capture` stays for starter credit until WP-14, then its `normal`/`dash`/`herd` kinds are removed | 04, 14 |
| `R/Encounters.luau` | `Obstacles` superseded by `Design.Arenas` features. `gate` removed. `stampede` generalised to arena routes. `starfall` impact points from arena anchors | 08, 10, 12 |
| `R/ArenaEvents.luau` | `hazard` (sweeps) removed. `herd` phase names → GRAZE / GATHER / STAMPEDE / GOLDEN FINALE, same boundaries | 08 |
| `R/ArenaRally.luau` | Retired; `Profile.rewardRally` path reused for Legend rewards | 13 |
| `R/HerdNet.luau` | Version 2 (§2.4) | 06 |
| `R/Herd.luau` | **New.** Pure per-species state machines replacing `Main.server.luau:1730-1800` | 06, 10, 12 |
| `R/GroundMap.luau` | **New.** Ground height lookup per arena | 05 |
| `R/Loadout.luau` | Perk and Heat effects re-keyed (§4). Ids, ranks and slots unchanged | 13 |
| `R/Profile.luau` | Version 4: additive fields (§2.5) | 13 |
| `R/Progression.luau`, `R/Trial.luau`, `R/Remix.luau`, `R/Cosmetics.luau`, `R/Cycle.luau` | Unchanged in stage 1–2. Re-keyed in stage 3 | 14, 15 |
| `S/Main.server.luau` | `capture` (1086), `dashSweep` (1123), the Dash handler's constraint block (1300-1320), herd step (~1730-1800), `spawnCreature` (911) are replaced by calls into `LoopService`, `Herd`, `Habitat`. Lifecycle, persistence, sessions, feedback, leaderboards are untouched | 03, 04, 06 |
| `S/LoopService.luau` | **New.** Path tracking, claim validation, catch resolution, wraps (§3) | 04, 13 |
| `S/Habitat.luau` | **New.** Pod spawning/respawn from arena data | 06 |
| `S/World.luau` | `buildArena` becomes data-driven via `WorldKit`. `World.creature`/`gild`/`static` move to the client (`CreatureKit`) | 05, 06 |
| `S/WorldKit.luau` | **New.** One builder per feature type in `asset_manifest.json` | 05, 09, 11 |
| `C/Client.client.luau` | Shrinks to wiring. HUD → `Hud.luau`; input/dash → `Movement.luau`; camera → `SparkCamera.luau`; ribbon → `Ribbon.luau` | 03, 07 |
| `C/CreatureView.luau` | Keeps interpolation; takes species/state from packets; poses for new states | 06 |
| `C/CreatureKit.luau`, `C/Decor.luau`, `C/Hud.luau`, `C/Movement.luau`, `C/SparkCamera.luau`, `C/Ribbon.luau` | **New** | 03, 05, 06, 07 |
| `C/Effects.luau` | Cinch ring, payout tags, boop ring, telegraph pool; gate/sweep/lane effects removed. Pools sized per `asset_manifest.vfx` (75 parts worst case) | 07, 08 |
| `C/Menu.luau`, `C/Podium.luau` | Restyle and re-key only | 16 |
| `tools/build_studio_install.py`, `tools/StudioInstaller.luau` | Must include every new module; covered by the existing `studio-installer-build` check | each WP that adds a file |

## 2. Interfaces and data objects

### 2.1 `Loop.luau` (pure, shared)

```lua
Loop.new() -> ribbon                      -- {points = {{x,z,t,d}}, length = 0}  d = cumulative path distance
Loop.push(ribbon, x, z, now, tuning)      -- appends when >= sampleSpacing from the last point; drops points older
                                          -- than lifetime or beyond maxLength; returns true if a point was added
Loop.truncate(ribbon, fromTime)           -- ribbon cut: forget everything at or before fromTime
Loop.tryClose(ribbon, tuning) -> polygon?, kind?      -- kind = "cross" | "snap"; polygon = {{x,z}, ...} (<= maxVertices)
Loop.tryPinch(ribbon, walls, tuning) -> polygon?, wallId?   -- stage 2
Loop.area(polygon) -> number              -- shoelace, absolute
Loop.perimeter(polygon) -> number
Loop.centroid(polygon) -> x, z
Loop.contains(polygon, x, z, inflate) -> boolean      -- even-odd test; inflate = also true within `inflate` of an edge
Loop.enclosedFraction(ribbon, x, z) -> 0..1           -- angular coverage around a point (Starwhirl)
Loop.nearestSegment(ribbon, x, z) -> index?, distance -- ribbon cuts
Loop.validate(polygon, serverPath, now, limits) -> ok, reason   -- section 3
Loop.encode(polygon) -> buffer ; Loop.decode(buffer) -> polygon? -- u8 count + i16 (x*10), i16 (z*10) pairs, arena-relative
```

### 2.2 Remote protocol (the existing action remote; names as today)

| Direction | Action | Payload | Notes |
| --- | --- | --- | --- |
| C → S | `Dash` | none | Server opens a dash budget window if a charge is available; never moves the character |
| C → S | `Loop` | `Loop.encode(polygon)`, `kind` | ≤ 3 per second |
| C → S | `Capture` | — | Removed; server ignores |
| S → C | feedback `Loop` | `{id, caught = {{creatureId, species, golden}}, escaped = {creatureId}, wraps = {{creatureId, count, need}}, points, techs = {"SNAP",…}, chain, multiplier, overflow}` | Drives pops and the payout tag |
| S → C | feedback `RibbonCut` | `{at = time, by = "prickle"\|"static"\|"charge"}` | Client truncates |
| S → C | feedback `Bank` | existing, plus `ring = id`, `multiplier` | |
| S → C | state | existing snapshot minus capture cooldown, plus `dashCharges`, `dashNextAt` | |

The client never sends technique names, scores, creature ids or timestamps.

### 2.3 `Challenge.loop`

```lua
Challenge.loop(state, now, {
  catches = { {captureId, value, signature, golden, dazed, starter} },   -- 1..30
  snap = boolean, tight = boolean, pinch = boolean, species = n, finale = boolean,
}) -> ok, { points, techs, chain, multiplier, sizeMultiplier, perCatch = {{captureId, signatureHit}} }
```

Counters it must keep feeding (names unchanged so saved goals and stats survive): `precision` += catches in a TIGHT loop; `dashCatches` += catches in a SNAP loop; `bestChain` = best consecutive-loop chain; plus new `loops`, `bestLoop`, `roundups`, `pinches`, `medleys`.

### 2.4 HerdNet v2

Header 8 bytes unchanged except `version = 2`. Entry 12 bytes:

| Bytes | Field |
| --- | --- |
| 4 | u32 id |
| 2 + 2 | i16 x·10, i16 z·10 (arena-relative) |
| 1 | heading (256 steps) |
| 1 | flags (existing bits: fleeing, dazed, golden, runner, startled, trial) |
| 1 | high nibble species index (0–15: 12 species, 3 legends, static puff); low nibble state code (`03` §2) |
| 1 | height above arena ground datum in 0.25-stud steps (elevation, hops, floats) |

Send policy: creatures in `graze` with no player within 40 studs go in every third packet; all others every packet (10 Hz). Budget: ≤ 1.2 KB/s average, ≤ 3.6 KB/s peak during a stampede. The client creates a model the first time it sees an id and removes it 1.0 s after the id stops appearing (or immediately on a `Loop` result that lists it).

### 2.5 Profile v4 (additive)

```lua
legends = {grandbloom = 0, thunderhoof = 0, borealynx = 0},   -- times caught
legendTokens = {grandbloom = 0, thunderhoof = 0, borealynx = 0},
stats.loops, stats.bestLoop, stats.roundups, stats.pinches, stats.medleys,   -- integers, default 0
coaching.loopIntro, coaching.snap, coaching.pinch                             -- shown-once flags
```

`Profile.sanitize` accepts versions 1–4, fills defaults, refuses 5+ without overwrite (existing rule extended).

### 2.6 Generated design modules (WP-01)

`R/Design/Tuning.luau`, `Creatures.luau`, `Arenas.luau`, `Events.luau`: plain Luau tables mirroring `design/fable/data/*.json` (values only; `_note` keys dropped). `Arenas` adds helpers: `inBounds(arena, x, z)`, `blockers(arena)`, `pinchWalls(arena)`.

## 3. Loop claims: authority and anti-exploit

The client draws the ribbon from its own positions so that what the player sees is what counts. The server never trusts the drawing; it checks the drawing against where it saw the player.

**Server path:** per session, a ring buffer of `(x, z, t)` appended each time a heartbeat position passes `Rules.movement` (existing validation point, `Main.server.luau` ~1569). Keep 6 s. `ribbonStart` is the later of round start, the last successful loop and the last cut.

**`Loop.validate` rejects a claim unless all hold:**

1. Round is playing; player not in `hazardUntil`; ≤ 3 claims per second.
2. 3 ≤ vertices ≤ 56; all finite; all inside the arena bounds polygon.
3. 16 ≤ perimeter ≤ `maxLength` + snap radius + 6; area ≥ 18.
4. Every vertex lies within `serverPathTolerance` (5 studs) of some server path sample whose time is ≥ `ribbonStart` and ≥ `now − lifetime − 0.6`.
5. Matching sample times are non-decreasing along the polygon (1.0 s slack), i.e. the polygon follows the path in order.
6. The last vertex is within tolerance of the player's current server position.

Then: SNAP = server `dashStarted` within 0.35 s (+0.15 s latency slack); TIGHT from server-computed area; PINCH from wall proximity of the first and last vertices; creatures tested with `Loop.contains(polygon, x, z, 0.75)` against **server** creature positions and states; each catch goes through the existing atomic `claim` so two simultaneous loops cannot both take one creature (first validated claim wins; the other player gets ASSIST if they qualify).

**Exploit bounds:** a cheating client can at most inflate a real path by 5 studs and cannot enclose anywhere it has not walked. Rejected claims increment the existing exploit telemetry. Adversarial spec set (WP-04): fabricated polygon far from path; replay of an old polygon; oversized polygon; polygon after teleport; out-of-order vertices; NaN/huge values; 500-claim flood; claim during intermission; claim for another arena.

**Ribbon cuts** are decided on the server path (Prickle within 2.5 studs of a path segment with spines out; Static Puff touching; Antlume charge crossing). The server sets `ribbonStart = now` and sends `RibbonCut`.

## 4. Upgrades, perks and Heat (ids and saved data unchanged)

| Id | Old effect | New effect |
| --- | --- | --- |
| upgrade `boots` | Dash cooldown −0.35/level | Dash recharge −0.3 s/level (2.4 → 1.5) |
| upgrade `magnet` (Herd Halo) | Catch radius +1.5/level | Snap radius +1.0/level (4.5 → 7.5) |
| upgrade `basket` (Parade Pack) | Carry +2/level | Carry +3/level (12 → 21) |
| perk `reach` | +2.5 reach / stricter precision | Snap radius +1.5 / TIGHT threshold area ×0.8 |
| perk `rhythm` | Chain +2 s / cap x3 | Unchanged |
| perk `slipstream` | Wider dash-through / slower dash | Third dash charge / recharge +0.5 s |
| perk `pockets` | Carry +4 / haul cap 1.3 | Carry +4 / bank multiplier caps at ×1.5 |
| perk `breaker` | Pop +60 / +1 scatter | Unchanged |
| perk `gatekeeper` | Herd points ×2 / −1 reach | Assist points ×2 / ribbon lifetime −0.4 s |
| perk `quickpaws` | Faster catch / miss lock | Ribbon lifetime +0.8 s / an empty loop ends the chain |
| perk `goldnose` | Golden compass +50 % / dash bonus halved | Golden compass +50 % / SNAP bonus halved |
| Heat 1, 3, 5 | Statics | Unchanged |
| Heat 2, 5 | Chain −1 s each | Unchanged (applied to the 7 s loop window) |
| Heat 4 "Tight Paws" | Reach −2.5 | "Short Ribbon": lifetime −0.6 s |

Display names may change in WP-13/16; ids may not.

## 5. Compatibility and migration risks

| Risk | Impact | Handling |
| --- | --- | --- |
| Offline suite is built around proximity capture (≈ 20 specs, 13 headless scenarios) | Many tests fail the moment capture is replaced | Port or delete per package; WP-18 rebuilds the scenarios. Expect a temporary drop in coverage during stage 1 and say so in each report |
| Daily Stampede (`Trial.luau`) plans against obstacle layout 1 and capture scoring | Daily is invalid under loops | Feature-flag it off (`Design.Tuning` flag `trialEnabled=false`, menu entry hidden) from WP-04 until WP-15; WP-15 uses a new board key so old and new scores never mix |
| Medal thresholds and economy (`tools/economy_model.luau`) assume old scoring | Medals/XP pacing wrong | Keep current thresholds as provisional through stages 1–2; recalibrate in WP-14 before any release claim |
| Quests keyed to `precision`, `dashCatches`, `bestChain` | Targets no longer match difficulty | Counters keep their names and are fed by TIGHT/SNAP/loop chains (§2.3); retarget text and numbers in WP-14 |
| `Rules.movement` uses a circular arena radius and one speed | Rejects legal movement in non-circular arenas, on ice, in wind lanes, on launches | Polygon bounds in WP-05/06; per-surface speed and raised `maxY` in WP-10/12, with specs proving off-surface speed is still rejected |
| Runtime Terrain generation (previous rule: "never edits Terrain") | Start-up time, mobile cost, creature ground height | Generate only inside arena regions at server start; `GroundMap` from a one-time raycast grid; flag `WORLD_PARTS_ONLY` falls back to part slabs. Validate in Studio at Checkpoint 1 |
| Client-predicted dash | Server and client disagree on charges under lag | Server grants budget if its own charge count allows; on refusal it sends the true `dashNextAt` and the movement credit simply rejects extra distance (existing behaviour) — the player rubber-bands only if they are actually cheating or badly lagged |
| Client-built creatures | A client can hide/alter models | Cosmetic only; every catch is decided from server positions |
| HerdNet version bump | Old clients | Version byte already gates decoding; server and client ship together |
| Profile v4 | Rollback after a v4 save | v3 code refuses v4 saves by design (existing "future-version" rule). Do not release v4 saves until Checkpoint 2 passes; until then gate the new fields behind an in-memory default |
| Studio installer | New files missing from the install | `studio-installer-build` check must enumerate new modules |
| Camera | Custom camera fights Roblox camera scripts | `SparkCamera` sets `CameraType = Scriptable` only while in a round; Classic option restores default |

## 6. The first five assignments (ready to execute)

### WP-01 — Design data pipeline (Sonnet)
**Goal:** make `design/fable/data` the single source of gameplay numbers and layouts.
**Do:** write `tools/gen_design_data.py` (stdlib) that converts `tuning.json`, `creatures.json`, `events.json` and `arenas/*.json` into `R/Design/{Tuning,Creatures,Events,Arenas}.luau` as deterministic, sorted, comment-headed Luau tables (drop keys starting with `_`; tuning entries collapse to their `value` plus a `Ranges` side table). Add `Arenas.inBounds`, `Arenas.blockers`, `Arenas.pinchWalls`. Add `tests/SparkDesignData.spec.luau` (ids resolve; pods ≤ cap; phase starts = `{0,25,55,85}`). Register a `design-data-fresh` check in `tools/run_checks.py` that regenerates to a temp dir and diffs. Also run `python3 design/fable/tools/validate.py --no-render` in that check.
**Done when:** checks green; regenerating twice yields identical bytes; no gameplay file changed.
**Out of scope:** using the data anywhere.

### WP-02 — `Loop.luau` (Opus)
**Goal:** the geometry in §2.1, pure and tested.
**Do:** implement every function in §2.1 except `tryPinch` (stub returning nil, with its spec marked pending). Closure: test the newest segment against all segments older than `snapMinPathDistance`; on a hit, polygon = intersection point + the points after it + head. Snap: nearest eligible point within `snapRadius`. Simplify polygons above 56 vertices by uniform resampling. `validate` exactly as §3 items 2–6.
**Tests (`tests/SparkLoop.spec.luau`):** circle, figure-eight (closes on the first crossing only), spiral, back-and-forth line (no closure), snap at 4.4 and no snap at 4.6, min perimeter/area rejects, contains with and without inflate on edge cases, expiry by time and by length, truncate, encode/decode round trip at 0.1-stud precision, validate accept on a noisy copy (≤ 4 studs) and reject at 6, order violation reject, 1,000 seeded random walks without NaN or error.
**Done when:** spec green in the Luau CLI; no Roblox globals referenced.

### WP-03 — Client feel: dash, camera, ribbon (Opus)
**Goal:** the three things the owner will feel first.
**Do:**
1. `C/Movement.luau`: dash state machine with 2 charges, recharge, 0.12 s buffer, speed curve from `Tuning.dash.speedCurve`, 40 % steering, air dash. Apply motion on the client with one persistent `LinearVelocity` (plane mode, enabled only during the dash; `MaxForce` high; created once per character) and set the exit velocity to blend to walk speed. Fire `Dash` to the server on start. Expose `dashStartedAt()`.
2. Server: delete the `LinearVelocity`/`Attachment`/`Debris` block in the Dash handler; keep cooldown accounting but as charges (`Rules.allow` → a small charge bucket); keep `s.motion.dashStarted/dashUntil` so `Rules.movement` budgets the burst; replace literal `65` with the tuning value.
3. `C/SparkCamera.luau`: per `Tuning.camera`; yaw input from RMB drag, touch drag on non-UI, right stick; occluder fade; Classic toggle.
4. `C/Ribbon.luau`: local `Loop` ribbon fed from `HumanoidRootPart` position each frame; one `Trail` for display; snap-preview `Beam`; on `tryClose` play the cinch and send `Loop`; handle `Loop` result (WP-04) and `RibbonCut`. Other players' ribbons: one `Trail` each at 50 % opacity, display only.
5. Remove the CATCH binding and button; bind E and Shift to dash.
**Tests:** pure parts (charge bucket, curve sampling, buffer) under the Luau CLI with a fake clock; `test_spark_client_api.py` updated for new instances.
**Done when:** no server-created constraint remains (grep); checks green. **Cannot be verified offline:** that it feels smooth — list this explicitly in the report.

### WP-04 — Server loop claims, scoring, parade, bank rings (Opus)
**Goal:** loops are the only way to catch, and the server proves each one.
**Do:** `S/LoopService.luau` with the server path buffer, `Loop.validate`, containment against `herd` positions, tech detection, overflow, and calls into the existing `claim` (kind `"loop"`, `multiIndex` = position in the loop) and feedback. Add `Challenge.loop` (§2.3) and route scoring through it. Replace `capture`/`dashSweep` call sites; `Capture` action becomes a no-op. Bank: run-through detection against `Design.Arenas[*].bankRings` (segment–circle test on the server path, radius 5) calling the existing `bank`, with the new multiplier table. Starter Pips: still owner-only, caught by loops. Flag Daily Stampede off.
**Tests:** `tests/SparkLoopService.spec.luau` with the adversarial set in §3; `SparkChallenge.spec` cases for size, tech, chain and finale multipliers; headless scenario: a bot walking a circle around a pod catches it, a stationary bot pressing actions catches nothing.
**Done when:** checks green; `Targeting` has no remaining callers in `S/`.

### WP-05 — Meadow world from data (Sonnet)
**Goal:** the Clover Bowl exists exactly as `data/arenas/meadow.json` describes.
**Do:** `S/WorldKit.luau` with one builder per feature type used by the Meadow (recipes and part budgets in `asset_manifest.json`); Terrain generation for ground, hills, pond and creek inside the bounds polygon (`FillBall`/`FillBlock`/`FillCylinder`/`FillWedge`; clear the region first), behind `WORLD_PARTS_ONLY` fallback; boundary hedge along the polygon; two bank rings; collision parts named `<featureId>_Col`. `R/GroundMap.luau`: 4-stud grid of downward raycasts per arena at start, bilinear lookup. `C/Decor.luau`: client-only grass clumps, reeds, lily pads, leaf particles and the arena lighting profile with a 1.5 s tween. Keep the old `buildArena` behind `WORLD_LEGACY` for Canyon and Aurora until WP-09/11. Spawn, hub teleport and records board keep their existing wiring.
**Tests:** `tests/SparkWorldData.spec.luau` under the headless engine: every feature id present; solid features have collision; bank rings at the right coordinates; part count ≤ 2,600; no part named `ArenaFloor` disc remains for the Meadow.
**Done when:** checks green. **Cannot be verified offline:** how it looks; Terrain performance.

After WP-01…05: WP-06 (herd + client creatures), WP-07 (HUD + slice audio), WP-08 (Stampede + Bloom Burst), then **Checkpoint 1**.

## 7. Staged order

| Stage | Packages | Parallelism | Gate |
| --- | --- | --- | --- |
| 1 Core feel slice | 01 → (02, 05) → (03, 04) → 06 → (07, 08) | 02 ∥ 05; 03 ∥ 04 share `Main.server.luau` in different functions — sequence them if one agent, or merge carefully | **Checkpoint 1:** owner plays Meadow solo (`09` §3). Stop here until it passes |
| 2 Full content | (09, 11) → (10, 12) → 13 | Worlds in parallel; species per arena in parallel | **Checkpoint 2:** three arenas solo + two-client co-op |
| 3 Re-integration | 14, 15, 16, 17, 18 → 19 | Mostly parallel | **Checkpoint 3:** RC criteria |

If Checkpoint 1 fails on the core verb (Q1–Q4 in `09`), do not proceed to stage 2. Tune within the ranges in `tuning.json`, apply the camera fallback (`01` §6), and re-test. If it still fails, the loop concept is wrong for this game and the owner decides the next direction; the slice will have cost one stage, not three.
