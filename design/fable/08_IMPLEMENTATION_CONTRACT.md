# 08 — Implementation contract

For the implementing agents. **The order of work, per-package pass criteria and defaults are in `13`**; this document is the module map, the interfaces and the risks. Work packages: `data/work_packages.json`. Catch resolution in full: `10`. Paths: `R/` = `game/ReplicatedStorage/Spark/`, `S/` = `game/ServerScriptService/Spark/`, `C/` = `game/StarterPlayer/StarterPlayerScripts/Spark/`. Line references are to baseline `b1b62fd`.

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
| `R/Loop.luau` | **New.** Port of `tools/loop_reference.py` (§2.1); tested against `data/test_vectors.json` | 02 |
| `R/Rules.luau` | `movement`: dash constant 65 → `Tuning.dash.serverBudgetPeakSpeed`; `limits.radius` circle → arena bounds polygon; per-surface speed (ice, wind) in WP-12. `canCapture`: new kind `"loop"` skips the distance test (containment already proved). `herdSpawn`, `outsideBank` retired with pods | 03, 04, 06, 12 |
| `R/Challenge.luau` | Add `Challenge.loop` (§2.3). `capture` stays for starter credit until WP-14, then its `normal`/`dash`/`herd` kinds are removed | 04, 14 |
| `R/Encounters.luau` | `Obstacles` superseded by `Design.Arenas` features. `gate` removed. `stampede` generalised to arena routes. `starfall` impact points from arena anchors | 08, 10, 12 |
| `R/ArenaEvents.luau` | `hazard` (sweeps) removed. `herd` phase names → GRAZE / GATHER / STAMPEDE / GOLDEN FINALE, same boundaries | 08 |
| `R/ArenaRally.luau` | Retired; `Profile.rewardRally` path reused for Legend rewards | 13 |
| `S/FirstSpark.luau` | **New.** UTC-scheduled single-winner contest (`12`, `data/first_spark.json`) | 20 |
| `R/Rotation.luau`, `R/Feats.luau` | **New.** Weekly Gauntlet/spotlight selection and feat evaluation from `data/rotation.json` | 21 |
| `R/HerdNet.luau` | Version 2 (§2.4) | 06 |
| `R/Herd.luau` | **New.** Pure per-species state machines replacing `Main.server.luau:1730-1800` | 06, 10, 12 |
| `R/GroundMap.luau` | **New.** Layered ground height lookup per arena: `height(arena, x, z, nearY)` returns the layer under `nearY` (two layers under the Arch) | 05, 09 |
| `R/Loadout.luau` | Perk and Heat effects re-keyed (§4). Ids, ranks and slots unchanged | 13 |
| `R/Profile.luau` | Version 4: additive fields (§2.5) | 13, 20, 21 |
| `R/Progression.luau`, `R/Trial.luau`, `R/Remix.luau`, `R/Cosmetics.luau`, `R/Cycle.luau` | Unchanged in stage 1–2. Re-keyed in stage 3 | 14, 15 |
| `S/Main.server.luau` | `capture` (1086), `dashSweep` (1123), the Dash handler's constraint block (1300-1320), herd step (~1730-1800), `spawnCreature` (911) are replaced by calls into `LoopService`, `Herd`, `Habitat`. Lifecycle, persistence, sessions, feedback, leaderboards are untouched | 03, 04, 06 |
| `S/LoopService.luau` | **New.** Server path buffer, claim deferral, validation, lag-compensated resolution, techniques, wraps, photo finish (§3, `10` §5) | 04, 13, 20 |
| `S/Habitat.luau` | **New.** Pod spawning/respawn from arena data | 06 |
| `S/World.luau` | `buildArena` becomes data-driven via `WorldKit`. `World.creature`/`gild`/`static` move to the client (`CreatureKit`) | 05, 06 |
| `S/WorldKit.luau` | **New.** One builder per feature type in `asset_manifest.json` | 05, 09, 11 |
| `C/Client.client.luau` | Shrinks to wiring. HUD → `Hud.luau`; input/dash → `Movement.luau`; camera → `SparkCamera.luau`; ribbon → `Ribbon.luau` | 03, 07 |
| `C/CreatureView.luau` | Keeps interpolation; takes species/state from packets; poses for new states | 06 |
| `C/CreatureKit.luau`, `C/Decor.luau`, `C/Hud.luau`, `C/Movement.luau`, `C/SparkCamera.luau`, `C/Ribbon.luau` | **New.** `CreatureKit` builds `data/models/*.json` part lists at `creatures.globalScale` | 03, 05, 06, 07 |
| `C/Effects.luau` | Cinch ring, payout tags, boop ring, telegraph pool; gate/sweep/lane effects removed. Pools sized per `asset_manifest.vfx` (75 parts worst case) | 07, 08 |
| `C/Menu.luau`, `C/Podium.luau` | Restyle and re-key only | 16 |
| `tools/build_studio_install.py`, `tools/StudioInstaller.luau` | Must include every new module; covered by the existing `studio-installer-build` check | each WP that adds a file |

## 2. Interfaces and data objects

### 2.1 `Loop.luau` (pure, shared) — a port of `tools/loop_reference.py`

Ribbon point: `{x, z, t, d, g}` (time, cumulative path distance, ground level). Polygon vertex: `{x, z, g}`.

```lua
Loop.new() -> ribbon
Loop.push(ribbon, x, z, now, tuning, g) -> added      -- >= sampleSpacing from the last point; expires by lifetime and maxLength
Loop.truncate(ribbon, fromTime)                        -- ribbon cut
Loop.tryClose(ribbon, tuning, head) -> polygon?, kind  -- head = LIVE position {x,z,t,g}; kind = "snap" | "cross"; else nil, reason
Loop.tryPinch(ribbon, walls, tuning) -> polygon?, wallId   -- stage 2 (WP-13); stub returning nil until then
Loop.area(polygon), Loop.perimeter(polygon), Loop.centroid(polygon)
Loop.contains(polygon, x, z, inflate) -> boolean       -- NON-ZERO winding, or within `inflate` of an edge
Loop.layerOk(polygon, x, z, g, tuning) -> boolean      -- |g - g of nearest vertex| <= layerTolerance
Loop.enclosedFraction(ribbon, x, z) -> 0..1            -- angular coverage (Starwhirl); stage 2
Loop.nearestSegment(ribbon, x, z) -> index?, distance  -- ribbon cuts; stage 2
Loop.validate(polygon, serverPath, now, ribbonStart, tuning, bounds) -> ok, reason, serverArea
Loop.resolve(polygon, creatures, viewClock, now, tuning) -> caughtIds, escapedIds
Loop.sizeMult(n), Loop.chainLinks(n), Loop.chainMult(links), Loop.chainWindow(n), Loop.isTight(n, serverArea, soloTightArea)
Loop.scoreLoop(values, techs, linksBefore, finale, carried) -> {points, links, multiplier, kept, overflow}
Loop.bankPoints(values) -> points, multiplier
Loop.encode(polygon) -> buffer ; Loop.decode(buffer) -> polygon?   -- u8 count + i16 (x*10), i16 (z*10); g is NOT sent (server takes it from its path)
```

Snap is tested before crossing, against ribbon **segments**, with the live head. Reasons returned by `validate` are the exact strings in the vectors. Scoring lives here so client prediction of the payout and `Challenge.loop` share one implementation.

### 2.2 Remote protocol (the existing action remote; names as today)

| Direction | Action | Payload | Notes |
| --- | --- | --- | --- |
| C → S | `Dash` | none | Server opens a dash budget window if a charge is available; never moves the character |
| C → S | `Loop` | `Loop.encode(polygon)`, `kind`, `viewClock` (herd clock being rendered) | ≤ 3 per second; `viewClock` clamped to [now − 0.35, now] |
| C → S | `Capture` | — | Removed; server ignores |
| S → C | feedback `Loop` | `{id, caught = {{creatureId, species, golden}}, escaped = {creatureId}, wraps = {{creatureId, count, need}}, points, techs = {"SNAP",…}, chain, multiplier, overflow}` | Drives pops and the payout tag |
| S → C | feedback `RibbonCut` | `{at = time, by = "prickle"\|"static"\|"charge"}` | Client truncates |
| S → C | feedback `Bank` | existing, plus `ring = id`, `multiplier` | |
| S → C | state | existing snapshot minus capture cooldown, plus `dashCharges`, `dashNextAt` | |

The client never sends technique names, scores, creature ids or ground levels. The only time it sends is `viewClock`, which the server clamps.

### 2.3 `Challenge.loop`

```lua
Challenge.loop(state, now, {
  catches = { {captureId, value, signature, species, golden, dazed, starter} },   -- 1..30, in pop order
  snap = boolean, tight = boolean, pinch = boolean, speciesCount = n, finale = boolean, carried = n,
}) -> ok, { points, techs, links, multiplier, sizeMultiplier, kept, overflow, perCatch = {{captureId, signatureHit}} }
Challenge.bank(state, now, {values = {...}}) -> points, multiplier      -- existing function, new multiplier table; refreshes the chain window
```

State changes: `state.links` replaces the per-catch chain count; `state.chainUntil = now + Loop.chainWindow(n)`. Points come from `Loop.scoreLoop`. Counters it must keep feeding (names unchanged so saved goals and stats survive): `precision` += catches in a TIGHT loop; `dashCatches` += catches in a SNAP loop; `bestChain` = highest multiplier-bearing link count; plus new `loops`, `bestLoop`, `roundups`, `pinches`, `medleys`. Medal thresholds: `Tuning.scoring.medalsProvisional` until WP-14.

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

### 2.5 Profile v4 (additive; lands in stage 2, never in the slice)

```lua
legends = {grandbloom = 0, thunderhoof = 0, borealynx = 0}, legendTokens = {...same keys...},          -- WP-13
crowns = {meadow = 0, canyon = 0, aurora = 0}, crownDay = {meadow = 0, canyon = 0, aurora = 0}, embers = 0,  -- WP-20 (crownDay = UTC day index of the last crown)
seals = { [gauntletId] = 0..4 }, feats = { [featId] = true },                                         -- WP-21
stats.loops, stats.bestLoop, stats.roundups, stats.pinches, stats.medleys,                             -- integers, default 0
coaching.loopIntro, coaching.snap, coaching.pinch                                                      -- shown-once flags (the slice keeps these in memory only)
```

`Profile.sanitize` accepts versions 1–4, fills defaults, refuses 5+ without overwrite (existing rule extended).

### 2.6 Generated design modules (WP-01)

`R/Design/Tuning.luau`, `Creatures.luau`, `Arenas.luau`, `Events.luau`, `Models.luau`, `Slice.luau` (stage 1); `FirstSpark.luau`, `Rotation.luau` (when their packages start): plain Luau tables mirroring `design/fable/data/*.json` (values only; `_note` keys dropped). `Arenas` adds helpers: `inBounds(arena, x, z)`, `blockers(arena)`, `pinchWalls(arena)`. `Slice` drives feature flags: code asks `Slice.on("static_puff")` rather than hard-coding what the slice contains.

## 3. Loop claims: authority and anti-exploit (summary; full procedure in `10` §5)

The client draws the ribbon from its own positions, so what the player sees is what counts. The server never trusts the drawing; it proves it against where it saw the player, then decides the catch from its own creature history.

1. **Server path:** per session, a 6 s ring of `(x, z, t, g)` from positions that passed `Rules.movement`. `ribbonStart` = latest of round start, last accepted loop, last cut.
2. **Deferral:** hold the claim up to 0.25 s until the path reaches the polygon's last vertex.
3. **`Loop.validate`:** vertex count and bounds; perimeter and area; path continuity (no hole > 1.0 s); head reached; every vertex within 4.0 studs of the path; every path sample in the matched span within 4.0 studs of the polygon. Returns the server's own area.
4. **`Loop.resolve`:** creatures tested where they were at `clamp(viewClock, now − 0.35, now)`; inside the client polygon grown by 0.75; same ground level (±6); catchable state at that clock. Escapees are reported so the client can show them.
5. **Techniques from server data only:** SNAP from server arrival times of `Dash` and `Loop`; TIGHT from the server area; PINCH from wall proximity on the server path; MEDLEY from the caught set.
6. **Atomic `claim`** per creature (existing), in pop order.

**Exploit bound:** a ring at most 4 studs wider than the one actually run; nowhere the player has not been; no technique or score is client-supplied. Rejections feed the existing exploit telemetry. `claimDeviation` (largest vertex-to-path distance on accepted claims) is logged for tuning the tolerance.

**Ribbon cuts** are decided on the server path with radii 0.5 stud smaller than drawn on the client; the server sets `ribbonStart = now` and sends `RibbonCut`.

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
| Medal thresholds and economy (`tools/economy_model.luau`) assume old scoring | Medals/XP/glow pacing wrong | Use `scoring.medalsProvisional` (from the round model) through stages 1–2; recalibrate medals, XP and glow prices from real rounds in WP-14 before any release claim |
| Quests keyed to `precision`, `dashCatches`, `bestChain` | Targets no longer match difficulty | Counters keep their names and are fed by TIGHT/SNAP/loop chains (§2.3); retarget text and numbers in WP-14 |
| `Rules.movement` uses a circular arena radius and one speed | Rejects legal movement in non-circular arenas, on ice, in wind lanes, on launches | Polygon bounds in WP-05/06; per-surface speed and raised `maxY` in WP-10/12, with specs proving off-surface speed is still rejected |
| Runtime Terrain generation (previous rule: "never edits Terrain") | Start-up time, mobile cost, creature ground height | Generate only inside arena regions at server start; `GroundMap` from a one-time raycast grid; flag `WORLD_PARTS_ONLY` falls back to part slabs. Validate in Studio at Checkpoint 1 |
| Client-predicted dash | Server and client disagree on charges under lag | Server grants budget if its own charge count allows; on refusal it sends the true `dashNextAt` and the movement credit simply rejects extra distance (existing behaviour) — the player rubber-bands only if they are actually cheating or badly lagged |
| Client-built creatures | A client can hide/alter models | Cosmetic only; every catch is decided from server positions |
| HerdNet version bump | Old clients | Version byte already gates decoding; server and client ship together |
| Profile v4 | Rollback after a v4 save | v3 code refuses v4 saves by design (existing "future-version" rule). Do not release v4 saves until Checkpoint 2 passes; until then gate the new fields behind an in-memory default |
| Studio installer | New files missing from the install | `studio-installer-build` check must enumerate new modules |
| Camera | Custom camera fights Roblox camera scripts | `SparkCamera` sets `CameraType = Scriptable` only while in a round; Classic option restores default |
| Ellipsoid parts | `b1b62fd` uses `Shape = Ball` with non-uniform sizes; how those render is unverified | New creatures use Part + SpecialMesh (Sphere). Owner confirms once at Checkpoint 1 |
| Client/server polygon disagreement | Honest claims rejected (`off-path`) on bad connections | Tolerance 4.0 is a hypothesis; tune from `claimDeviation` p99. A rejected honest claim costs the player nothing but the loop |
| Creature history memory | 30 creatures × 5 ticks | Negligible; ring buffer per creature |
| First Spark on UTC | Server clock skew moves the mark | Use server UTC time (`os.time()`); server clocks are expected to agree closely but this is unverified: compare two live servers at Checkpoint 3. A few seconds of skew is acceptable against a 23 s window |
| Uploaded assets | Textures and audio have no asset ids | Every use has a fallback (`data/slice.json`); owner uploads when convenient |
| Runtime Terrain on the Meadow frame reference | The reference render is three.js, not Roblox: Terrain grass and lighting will differ | Treat the render as layout, scale and hierarchy reference only |

## 6. The first five assignments (ready to execute, in route order)

The route and pass criteria for all 21 packages are in `13`. These are the first five in order, with the detail needed to start without questions.

### 1 · WP-01 — Design data pipeline (delegable)
**Goal:** make `design/fable/data` the single source of gameplay numbers, layouts, models and slice scope.
**Do:** write `tools/gen_design_data.py` (stdlib) converting `tuning.json`, `creatures.json`, `events.json`, `arenas/*.json`, `models/*.json` and `slice.json` into `R/Design/{Tuning,Creatures,Events,Arenas,Models,Slice}.luau` as deterministic, sorted, comment-headed Luau tables (drop keys starting with `_`; a tuning entry collapses to its `value`, with a `Ranges` side table). Add `Arenas.inBounds/blockers/pinchWalls` and `Slice.on(id)`. Add `tests/SparkDesignData.spec.luau`. Register two checks in `tools/run_checks.py`: `design-data-fresh` (regenerate to a temp dir and diff) and `design-validate` (`python3 design/fable/tools/validate.py --no-render`).
**Done when:** checks green; two regenerations are byte-identical; no gameplay file changed.

### 2 · WP-02 — `Loop.luau`
**Goal:** the functions in §2.1, behaving exactly like `tools/loop_reference.py`.
**Do:** port function for function; keep the same order of tests inside `tryClose` (crossing candidates, then snap by segment, live head, resample above 56 vertices, perimeter then area rejection) and the same reason strings in `validate`. Write a small generator (or extend WP-01's) that turns `data/test_vectors.json` into `tests/vectors/loop_vectors.luau`. `tryPinch`, `enclosedFraction`, `nearestSegment` are stubs with pending specs.
**Tests:** every vector group (`closure`, `containment`, `validation`, `resolution`, `scoring`, `bank`, `chain`) asserted exactly; areas and perimeters to 0.1; plus 1,000 seeded random walks with no error or NaN.
**Done when:** spec green in the Luau CLI; no Roblox globals referenced.

### 3 · WP-05 — Meadow world from data (delegable)
**Goal:** the Clover Bowl exactly as `data/arenas/meadow.json` describes; `mockups/meadow_gameplay_frame.png` and `maps/meadow.svg` are the visual references for layout, scale and hierarchy.
**Do:** `S/WorldKit.luau` with one builder per Meadow feature type (recipes and part budgets in `data/asset_manifest.json`); Terrain for ground, hills, pond and creek inside the bounds polygon (clear the region first; `FillBall`/`FillBlock`/`FillCylinder`/`FillWedge`), behind the `worldPartsOnly` fallback; a 3.5-stud boundary hedge along the polygon; two bank rings; collision parts named `<featureId>_Col`. `R/GroundMap.luau`: a 4-stud grid of downward raycasts per arena at start, bilinear lookup, layered API. `C/Decor.luau`: client-only grass, flowers, reeds, lily pads, leaf particles, the arena lighting profile (1.5 s tween) and occluder fade for hedge and canopy. Keep the old `buildArena` behind `worldLegacy` for Canyon and Aurora. Spawn, hub teleport and records board keep their wiring.
**Tests:** `tests/SparkWorldData.spec.luau` in the headless engine: every feature id present; solids have collision; bank rings at their coordinates; ≤ 2,600 parts; no `ArenaFloor` disc for the Meadow.
**Cannot be verified offline:** how it looks; Terrain cost.

### 4 · WP-03 — Client feel: dash, camera, ribbon
**Goal:** the three things the owner feels first.
**Do:**
1. `C/Movement.luau`: dash state machine (2 charges, recharge, 0.12 s buffer, `Tuning.dash.speedCurve`, 40 % steering, air dash). Apply motion on the client with one persistent plane-mode `LinearVelocity` enabled only during the dash, then blend exit velocity to walk speed. Fire `Dash` on start.
2. Server Dash handler: delete the `Attachment`/`LinearVelocity`/`Debris` block (`Main.server.luau` ~1309–1320); account charges in a small bucket; keep `s.motion.dashStarted/dashUntil` so `Rules.movement` budgets the burst; replace the literal `65` with the tuning value.
3. `C/SparkCamera.luau`: `Tuning.camera` (pitch 46, distance 38); yaw from RMB drag, touch drag off UI, right stick; occluder fade; `[` `]` step `pitchPresets`; Classic toggle.
4. `C/Ribbon.luau`: local `Loop` ribbon fed each frame from the root position with `g` from `GroundMap`; travel Trail + loop Trail; snap-preview Beam; on `tryClose(ribbon, tuning, head)` start the cinch and send `Loop` with `viewClock` from `CreatureView`; handle the `Loop` result, the 0.8 s slip, and `RibbonCut`. Other players: display-only Trails at 50 %.
5. Remove the CATCH binding and button; bind E and Shift to dash.
**Tests:** dash bucket, curve sampling and buffer under the Luau CLI with a fake clock; `test_spark_client_api.py` updated.
**Cannot be verified offline:** that it feels smooth.

### 5 · WP-04 — Server loop claims, resolution, scoring, parade, bank rings
**Goal:** loops are the only way to catch, and the server proves each one.
**Do:** `S/LoopService.luau` exactly as §3 / `10` §5: path buffer at the existing movement-validation point (`Main.server.luau` ~1569), deferral, `Loop.validate`, creature history ring (stub of fixed creatures until WP-06 supplies real ones), `Loop.resolve`, techniques, overflow, existing `claim` with kind `"loop"`, `Loop` feedback. Add `Challenge.loop`; route scoring through it. `Capture` becomes a no-op; delete `capture` and `dashSweep` call sites. Bank: segment–circle test of the server path against `Design.Arenas[*].bankRings` (radius 5) calling the existing `bank` with the new multiplier table and refreshing the chain window. Starter Pips stay owner-only. Daily Stampede flagged off.
**Tests:** `tests/SparkLoopService.spec.luau`: validation and resolution vectors through the service; the adversarial set (`10` §6); simultaneous-claim case; `SparkChallenge.spec` scoring vectors. Headless: circling bot catches the starter pod within 5 s; stationary button-spam bot scores 0.
**Done when:** checks green; `Targeting` has no callers under `S/`.

Then WP-06, WP-07, WP-08 and **Checkpoint 1** (`13` §3, `09` §3).

## 7. Staged order

See `13`. In one line: `01 → 02 → 05 → 03 → 04 → 06 → 07 → 08 → [Checkpoint 1] → 09 → 10 → 11 → 12 → 13 → 20 → [Checkpoint 2] → 14 → 15 → 21 → 16 → 17 → 18 → 19 → [Checkpoint 3]`.
