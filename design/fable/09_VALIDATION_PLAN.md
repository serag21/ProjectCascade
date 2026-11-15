# 09 — Validation plan

Two kinds of evidence, never mixed in a report:

- **A — Automated (offline):** logic, security, data, budgets that can be computed. Run by agents with `python3 tools/run_checks.py`.
- **S — Studio (owner, hands on):** feel, readability, looks, sound, real performance. Only a person playing can establish these. Per `AGENTS.md`, agents do not run Studio.

A green offline suite means the rules are implemented as written. It says nothing about whether the game is enjoyable.

## 1. Automated requirements

| Id | Requirement | Method |
| --- | --- | --- |
| T-DATA1 | Design data is internally consistent | `python3 design/fable/tools/validate.py` exits 0 |
| T-DATA2 | Generated Luau equals the JSON | `design-data-fresh` check |
| T-L1 | Loop geometry correct | `SparkLoop.spec` (cases in `08` WP-02) |
| T-L2 | No catch without physically encircling | `SparkLoopService.spec` adversarial set: 0 catches, 0 score, telemetry incremented |
| T-L3 | A stationary input-spamming bot scores 0 in a full round | headless scenario |
| T-L4 | A bot walking a 6-stud circle around the starter pod catches all 3 within 5 s | headless scenario |
| T-L5 | Two simultaneous loops over one creature: exactly one catch, the other gets ASSIST | headless 2-player scenario |
| T-D1 | Dash motion starts in the input frame; no server-created constraint exists | unit test + grep check for `LinearVelocity` in `S/` |
| T-D2 | Dash charges, buffer and recharge match tuning | unit test, fake clock |
| T-D3 | Server budget accepts a legal dash and rejects 2× distance | `SparkRules.spec` |
| T-H1 | Each species' state machine honours its telegraph and uncatchable windows (±1 server step) | `SparkHerd.spec` |
| T-H2 | No flee speed ≥ walk speed except runner/charge | validator + spec |
| T-H3 | Base creatures ≤ 14, with events ≤ 30, pods ≥ 24 apart, across a 20-cycle soak | headless soak |
| T-N1 | Herd traffic ≤ 1.2 KB/s average, ≤ 3.6 KB/s peak per client | headless soak byte counter |
| T-N2 | Server creates zero creature Instances | headless instance census |
| T-W1 | Every arena feature in JSON exists in the built world with collision where solid | `SparkWorldData.spec` |
| T-W2 | Parts per arena ≤ 2,600 incl. client decor; creature ≤ 9 parts | census |
| T-FX1 | Local effect parts ≤ 80 at worst case (stampede + cinch + telegraphs) | pool-size assertion; manifest sums to 75 |
| T-UI1 | HUD rects equal `ui_layout.json` at the three reference viewports; no overlaps; persistent coverage ≤ 9 % | layout smoke test |
| T-E1 | Events fire at the times in `events.json` with telegraph lead ≥ specified | `SparkDepth.spec` |
| T-E2 | Shared wraps: every contributor rewarded, floor 50 % | spec |
| T-P1 | Profile v1–v3 load into v4 with no field lost; v5 refused | `SparkProfile.spec` |
| T-P2 | 500-request flood and malformed payloads on `Loop`/`Dash` change nothing | scenario H ported |
| T-S1 | 4 players × 20 cycles: no error, flat non-herd instance count, flat thread count | scenario L ported |

## 2. Studio measurements (owner or supervised session)

| Id | Measure | Target | How |
| --- | --- | --- | --- |
| M1 | Frame time, Meadow, solo, desktop | p50 ≤ 12.5 ms, p95 ≤ 16.7 ms (baseline 32.8 ms) | In-game perf overlay / MicroProfiler, 2 full rounds |
| M2 | Frame time during Stampede | p95 ≤ 20 ms | same |
| M3 | Local effect parts peak | ≤ 80 (baseline 124) | existing overlay counter |
| M4 | Herd receive rate | ≤ 1.2 KB/s avg (baseline 1.7) | existing overlay counter |
| M5 | Time to first loop / first bank / round end, first-time player | ≤ 10 s / ≤ 30 s / ≤ 2:00 | funnel metrics from the session |
| M6 | Dash input-to-motion | Visibly same frame at 60 fps (no perceptible delay) | 60 fps screen recording, frame step |
| M7 | Server start to playable with Terrain generation | ≤ 5 s | log timestamps |
| M8 | Mobile device frame time (one mid-range phone) | p50 ≤ 25 ms | device test at Checkpoint 2 |

If M1 misses with Terrain on, repeat with `worldPartsOnly = true` and report both.

## 3. Checkpoint 1 — the feel test (Meadow slice, solo, ~20 minutes)

The owner plays at least five rounds, then answers. Scale: 1 (no) – 5 (yes), plus a sentence.

**Core verb**
1. Did you understand how to catch without reading anything? How many seconds until your first catch?
2. Does closing a ring and watching it cinch feel good? Still good on the 30th loop?
3. Could you tell when a ring would close, and how big a ring you could still make?
4. Did you find yourself *choosing* — which group, how big, when to dash — rather than repeating one motion?
5. Did the Sparks behave in a way you could predict and use (bunching, hopping), or did they feel random or annoying?

**Movement and camera**
6. Does the dash feel immediate and smooth? Any stutter, snap-back or slide at the end?
7. Could you judge loops from the default camera? Did you fight the camera at any point?
8. Is running around simply pleasant (speed, turning, jumping the creek, the bounce caps)?

**Encounters**
9. Did the Bunvolt hop feel fair — did you see it coming, and did you want to try again?
10. Was the Stampede exciting? Did you understand what to do when the route lit up?

**World and presentation**
11. Does the Meadow feel like a place? Name the landmarks you remember.
12. Was anything on the HUD in your way? Was anything missing?
13. Could you always tell where to go next?
14. Were the Sparks easy to tell apart at a distance?
15. Do the sounds make catching more satisfying? Anything irritating?
16. Does the music help you feel the round building?

**Verdict**
17. After five rounds, did you want another? Why or why not?
18. What was the most fun moment, and the most boring 20 seconds?

**Pass rule:** Q2, Q4, Q6 and Q17 at 4 or above, none of Q1–Q8 below 3, and M1/M3 within target. Anything else: tune inside the ranges in `tuning.json`, apply the fallbacks, and repeat Checkpoint 1. Stage 2 does not start on a fail.

## 4. Checkpoint 2 — content and co-op (all arenas; solo and two clients)

19. Do the three arenas play differently? Describe each in a sentence.
20. Is ice gliding fun or frustrating? Is the wind lane worth using?
21. Did intercepting a Zip Tail feel clever? Did it take more than a few tries to learn?
22. Which species was most satisfying to beat? Which was a chore?
23. With two players: did you help each other without planning to? Did anything feel stolen?
24. Did the Legend feel like an event? Was the shared reward fair?
25. Did the Static Puff add tension or just annoyance?
26. Any moment where a creature escaped and you could not tell why?

Readability checks in the same session (observer notes, not opinions): each species identified by name at 60 studs; ribbon visible against every ground type including ice at night; every telegraph noticed before its effect at least 4 times in 5.

## 5. Checkpoint 3 — release-candidate criteria

All of §1 green; M1–M8 in target; Checkpoint 1 and 2 passed; first-session script (`07`) observed with a first-time player other than the owner (≥ 3 people if possible, recording M5); 10 consecutive rounds per arena without softlock; 4-client session without desync; Daily Stampede parity between two clients; economy recalibrated (WP-14); audio uploaded and heard. Publishing remains the owner's separate decision.

## 6. What no test here can establish

Whether players return the next day, whether the loop holds interest for weeks, and whether the game stands out on the platform. Those need a live private beta and real data, after Checkpoint 3.
