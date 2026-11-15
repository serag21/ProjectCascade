# 09 — Validation plan

Two kinds of evidence, never mixed in a report:

- **A — Automated (offline):** logic, security, data, computable budgets. Run by agents: `python3 tools/run_checks.py` (which also runs `python3 design/fable/tools/validate.py`).
- **S — Studio (owner, hands on):** feel, readability, looks, sound, real performance. Per `AGENTS.md`, agents do not run Studio.

A green offline suite means the rules are implemented as written. It says nothing about whether the game is enjoyable.

## 1. Automated requirements

| Id | Requirement | Method |
| --- | --- | --- |
| T-DATA1 | Design data, vectors, round model and document references are consistent | `design/fable/tools/validate.py` exits 0 |
| T-DATA2 | Generated Luau equals the JSON | `design-data-fresh` check |
| T-L1 | `Loop.luau` matches the reference | All 59 vectors in `data/test_vectors.json` |
| T-L2 | No catch without physically encircling | Adversarial set (`10` §6) through `LoopService`: 0 catches, 0 score, telemetry incremented |
| T-L3 | A stationary input-spamming bot scores 0 in a full round | Headless scenario |
| T-L4 | A bot walking a 6-stud circle around the starter pod catches all 3 within 5 s | Headless scenario |
| T-L5 | Two simultaneous loops over one creature: one catch, the other ASSIST | Headless 2-player scenario |
| T-L6 | Lag compensation: catch evaluated at the view clock, clamped to 0.35 s | Resolution vectors through `LoopService` |
| T-L7 | Level rule: a ring on one level never catches on another | `layer_rule` vector; repeated in the built canyon (stage 2) |
| T-P0 | Farming singles does not beat competent herding; expert herding ≥ 2.5 × expert single-farming | `validate.py` round-model assertions |
| T-D1 | Dash motion starts in the input frame; no server-created constraint | Unit test + grep for `LinearVelocity` under `S/` |
| T-D2 | Dash charges, buffer, recharge match tuning | Unit test, fake clock |
| T-D3 | Server budget accepts a legal dash and rejects twice the distance | `SparkRules.spec` |
| T-H1 | Each species honours its telegraph and uncatchable windows (± one server step) | `SparkHerd.spec` |
| T-H2 | No flee speed ≥ walk speed except runner and charge | `validate.py` + spec |
| T-H3 | Base creatures ≤ 14, with events ≤ 30, pods ≥ 24 apart, over a 20-cycle soak | Headless soak |
| T-N1 | Herd traffic ≤ 1.2 KB/s average, ≤ 3.6 KB/s peak per client | Headless byte counter |
| T-N2 | Server creates zero creature Instances | Headless census |
| T-W1 | Every arena feature exists with collision where solid | `SparkWorldData.spec` |
| T-W2 | Arena parts ≤ 2,600 including client decor; creature ≤ 9 parts | Census |
| T-FX1 | Effect **parts** ≤ 80 at worst case | Pool sizes (manifest sums to 75) |
| T-UI1 | HUD rects equal `ui_layout.json` at three viewports; no overlap; persistent coverage ≤ 9 % | Layout smoke test |
| T-E1 | Events fire at `events.json` times with the specified telegraph lead | `SparkDepth.spec` |
| T-E2 | Shared wraps: every contributor rewarded, 50 % floor | Spec (stage 2) |
| T-E3 | First Spark: UTC schedule, winner and tie rules, photo finish, cap | `SparkFirstSpark.spec` (stage 2) |
| T-S0 | Slice scope: everything `off` in `slice.json` is unreachable, everything `in` is present | Spec driven by `Design.Slice` |
| T-P1 | Profile v1–v3 load into v4 with nothing lost; v5 refused | `SparkProfile.spec` (stage 2) |
| T-P2 | 500-request flood and malformed payloads on `Loop`/`Dash` change nothing | Scenario H ported |
| T-S1 | 4 players × 20 cycles: no error, flat non-herd instances, flat threads | Scenario L ported (stage 3) |

## 2. Studio measurements

How to take them: `11` §6 (F8 overlay v2; a separate server and client, not Play Solo; MicroProfiler for causes).

| Id | Measure | Target | Baseline on `b1b62fd` |
| --- | --- | --- | --- |
| M1 | Client frame time, Meadow, solo, desktop | p50 ≤ 12.5 ms, p95 ≤ 16.7 ms | 32.8 ms average, taken with the old overlay; cause not established. Re-take with the same method as the new build for a fair comparison |
| M2 | Frame time during the Stampede | p95 ≤ 20 ms | — |
| M3 | Effect parts (visible `BasePart`s under `SparkFx`) | ≤ 80 | Unknown: the old 124 counted all descendants |
| M4 | Effect instances (beams, trails, emitters, billboards) | Record; provisional ≤ 120 | Unknown |
| M5 | Herd receive rate | ≤ 1.2 KB/s average | 1.7 KB/s (within the old ≤ 6 budget) |
| M6 | Time to first loop / first bank / round end, first-time player | ≤ 10 s / ≤ 30 s / ≤ 2:00 | — |
| M7 | Dash input to motion | Same frame at 60 fps (frame-step a recording) | Visibly delayed |
| M8 | Server start to playable with Terrain | ≤ 5 s | — |
| M9 | `claimDeviation` p99 over five rounds | Record; sets `serverPathTolerance` | — |
| M10 | One mid-range phone, frame time | p50 ≤ 25 ms | Checkpoint 2 |

If M1 misses with Terrain on, repeat with `worldPartsOnly = true` and report both.

## 3. Checkpoint 1 — is the core worth building on?

**Scope:** the Meadow slice (`data/slice.json`), solo. **One question:** are movement, herding and ring closure enjoyable enough to build the rest around? World, events and HUD are present so the verb is judged in context, but they are not what passes or fails.

**Not judged here:** sound (no audio is uploaded), Canyon and Aurora, rares, progression, multiplayer, balance of scores and medals.

### 3.1 What is and is not in the build

| Present | Absent or hidden |
| --- | --- |
| The full Meadow; Pip, Bunvolt, Cubloom, Flutterwink | Canyon, Aurora (locked) |
| Ribbon loops, snap, cinch; SNAP, TIGHT, MEDLEY; chain; two bank rings | PINCH (walls block creatures but do not close ribbons yet) |
| Predicted dash with two charges; chase camera with preset keys | Upgrades, perks, Heat (hidden; fixed values for everyone) |
| Bloom Burst at 30 s, Stampede at 55 s, finale ×1.5 from 85 s | Golden Runaway, Legends, First Spark, Static Puff |
| Slice results sheet: score, provisional medal, best loop size | Best Loop card, next goal, CLAIM, Daily Stampede |
| F8 overlay v2, F9 tuning panel | Final audio (placeholders or silence) |

### 3.2 Script (about 25 minutes)

1. **Round 1, cold.** Do not read anything first. Note the seconds to your first catch and whether you understood why it worked.
2. **Rounds 2–3, play.** Ring whole pods. Try the Cubloom flock near the pens. Use both bank rings. Be at the Bloom bud at 30 s and on the Stampede route at 55 s.
3. **Round 4, dash.** Close rings with a dash (SNAP). Shove a straggler back into a ring. Try to catch a Bunvolt between hops.
4. **Round 5, camera.** Press `[` and `]` to try the three pitches mid-round. Open F9 and try camera distance 32 and 44, creature scale 1.15 and 1.45. Leave it where it feels best and note the values.
5. **Round 6, tuning (optional).** In F9 try ribbon lifetime 3.4 and 5.0, snap radius 3.5 and 6, dash distance 12 and 18. Note anything clearly better.
6. **Measure.** F8 overlay: write down M1–M5 and M9 during round 3. Record 10 s of dashing at 60 fps for M7.
7. **Once:** look at one Pip up close and confirm it is an ellipsoid, not a sphere (`11` §2).

### 3.3 Questions (1 = no, 5 = yes, plus a sentence)

**Ring closure**
1. Did you catch something within the first 15 s without instructions?
2. Does closing a ring and watching it cinch feel good — and still good by round 5?
3. Could you tell when a ring was about to close, and roughly how large a ring you could still make?
4. When a ring missed, did you know why?

**Herding**
5. Did the Sparks react to you in a way you could predict and use?
6. Did you find yourself choosing — which group, how big, from which side — rather than repeating one motion?
7. Was ringing a whole pod clearly better and more satisfying than picking off singles?

**Movement and camera**
8. Is the dash immediate and smooth, with no stutter, snap-back or slide?
9. Could you see the Sparks and your ribbon well enough at the default camera? Which preset did you end on?
10. Is simply running around pleasant?

**Verdict**
11. After five rounds, did you want another?
12. Most fun moment; most boring 20 seconds.

Context questions (recorded, not part of the pass rule): did the Bloom Burst and Stampede read as events; does the Meadow feel like a place; was the HUD in the way.

### 3.4 What the answers trigger

**Pass:** Q2, Q6, Q8 and Q11 at 4 or more; no question in 1–10 below 3; M1 and M3 in target. → Stage 2, with the F9 values the owner settled written into `tuning.json`.

Otherwise, find the first matching row:

| Feedback | Response | Specific action |
| --- | --- | --- |
| Q8 ≤ 3: dash stutters, snaps back or slides | **Tune**, then code | Check M7. If motion starts late → implementation defect in `Movement` (fix, not tune). If it starts on time but feels wrong → `dash.speedCurve`, `duration`, `distance`, exit blend |
| Q3 ≤ 3 or Q4 ≤ 3: cannot judge closing or misses | **Tune** | `ribbon.snapRadius` up (to 6); stronger snap preview; ribbon length cue. If misses come with a late result → check latency handling against `10` §5.7 |
| Q9 ≤ 3: cannot see Sparks or ribbon | **Camera change** | Step 1: adopt the owner's preferred preset/distance/scale. Step 2: add the ground guide ring (`01` §6). Step 3: fixed three-quarter camera. Re-test after each step |
| Q5 ≤ 3: Sparks feel random or annoying | **Tune** | `awareness`, flee speed, the 0.6 pod-cohesion weight in `03` §2; lengthen telegraphs. Bunvolt specifically: hop interval 2.6 → 3.2 s |
| Q7 ≤ 3: singles feel as good as pods | **Tune** | Pod spread tighter, `sizeMultiplier` steeper, pop ladder and ROUNDUP effects stronger |
| Q10 ≤ 3: running feels dull or sluggish | **Tune** | `walkSpeed` (to 27), camera look-ahead and smoothing |
| Q6 ≤ 3 but Q2 ≥ 4: closing feels good, no decisions | **Tune content, limited** | More varied pod formations and positions; bring PINCH forward from stage 2. One iteration only |
| Q2 ≤ 3 after one tuning pass, or Q11 ≤ 2 with Q8 and Q9 ≥ 4 | **Rethink the core verb** | The mechanics work and the owner still does not enjoy drawing rings. Stop. Do not build stage 2. Options to weigh, in order: (a) loops that must be *held* briefly to catch (timing skill), (b) herding into the existing pens and bank rings as the catch, with the ribbon as a herding tool, (c) a different concept |
| M1 or M3 out of target, answers good | **Engineering** | MicroProfiler top three labels; Terrain off; decor budget. Does not block stage 2 planning but must be closed before Checkpoint 2 |

At most two tune-and-retest cycles. If the pass rule is still not met after two, treat it as a rethink.

## 4. Checkpoint 2 — content and co-op

All three arenas solo, then a two-client session. Audio should be uploaded by now.

13. Do the three arenas play differently? One sentence each.
14. Is ice gliding fun or frustrating? Is the wind lane worth using?
15. Did intercepting a Zip Tail feel clever? How many tries to learn?
16. Which species was most satisfying to beat? Which was a chore?
17. Do walls finishing a ring (PINCH) feel fair and useful?
18. With two players: did you help each other without planning to? Did anything feel stolen?
19. Did the Legend feel like an event? Was the shared reward fair?
20. First Spark: exciting or stressful? Was the winner rule clear without explanation? Is three rings alone achievable?
21. Does the Static Puff add tension or just annoyance?
22. Any catch or miss you could not explain? (Level rule under the Arch, latency.)
23. Do the sounds make catching more satisfying? Does the music tell you the Stampede is coming? Anything irritating?

Observer checks: each species named correctly at 60 studs; ribbon visible on every ground type including ice at night; each telegraph noticed before its effect at least 4 times in 5.

## 5. Checkpoint 3 — release-candidate criteria

All of §1 green; M1–M10 in target; Checkpoints 1 and 2 passed; the first-session script (`07`) observed with at least one first-time player other than the owner, recording M6; 10 consecutive rounds per arena without a softlock; a 4-client session without desync; Daily Stampede and weekly Gauntlet parity between two clients; economy recalibrated from real rounds (WP-14); a First Spark observed on two servers at the same UTC mark. Publishing remains the owner's separate decision.

## 6. What no test here can establish

Whether players return the next day, whether the loop holds for weeks, whether an hourly contest is a draw or a stressor, and whether the game stands out on the platform. Those need a private beta with real players after Checkpoint 3.
