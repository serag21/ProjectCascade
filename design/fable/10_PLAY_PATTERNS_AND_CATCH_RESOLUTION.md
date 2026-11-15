# 10 — Play patterns and catch resolution

Two questions are settled here so the implementer does not have to guess:

1. **Does repetitive low-skill play win?** Tested with a round model; the first-pass rules failed and were changed.
2. **Exactly how does a ring become a catch?** The server's reconstruction, the height and obstacle rules, and what happens under latency, with test vectors.

Executable sources: `tools/loop_reference.py` (the rules), `tools/play_model.py` (the round model), `data/test_vectors.json` (59 vectors with expected results), `data/play_model_results.json` (model output). `tools/validate.py` re-runs all of them.

## 1. The round model

`tools/play_model.py` plays 400 simulated Meadow-slice rounds per archetype. It uses the real habitat and bank-ring coordinates, real species values, real respawn times and the real scoring functions. **Player behaviour is assumed**, not measured:

| Archetype | Assumed behaviour |
| --- | --- |
| **Beginner** — circles one Spark at a time | Takes 1 creature per loop (2 on 30 % of Pip loops); wide 9-stud rings; 3.5 s of hesitation per loop; 25 % of loops miss; cannot catch a Flutterwink; banks at 3; gets 3 from the Bloom Burst and 3 from the Stampede |
| **Competent** — rounds up whole pods | One loop per pod; 1.2 s between loops; 8 % miss; SNAP 30 %, TIGHT 35 %; banks at 8; 6 from the Bloom; 6 + 3 from the Stampede |
| **Optimizer A** — expert hands, farms singles | One creature per loop on purpose, 4-stud rings, 0.4 s between loops, SNAP whenever a charge is ready; splits pods, the Bloom and the Stampede into singles |
| **Optimizer B** — expert hands, herds | Whole pods, merges neighbouring pods (3.5 s herding cost), SNAP 80 %, TIGHT 60 %, banks only at a full parade, rings all 8 of the Bloom, 9 + 5 from the Stampede |

It is a model. It shows which strategies the *rules* favour; it cannot show what is fun.

## 2. Result: the first-pass rules rewarded farming singles

Mean score per round (p10–p90):

| Archetype | Rules as published in `db5dd1b` | Current rules |
| --- | --- | --- |
| Beginner | 97 (61–130) | **124** (67–171) |
| Competent herding | 885 (605–1169) | **1131** (795–1452) |
| Optimizer A: singles | **1121** (1024–1214) | **901** (776–995) |
| Optimizer B: herding | 1540 (1312–1683) | **2911** (2546–3194) |

Under the first-pass rules an expert who never herded — 44 tiny identical loops a round — out-scored a competent player who did, and reached 73 % of the best herding score. Three rules caused it:

1. **One chain link per loop.** Tiny loops are the fastest way to make loops, so singles hit x4 soonest and held it for 45 s of the round.
2. **TIGHT on any small ring.** A 4-stud circle around one creature was always TIGHT.
3. **A fixed 7 s chain window.** Herding two pods together takes longer than 7 s, so the best play *lost* its chain while single-farming never did (herders spent 0 s at x4).

## 3. Rule changes (now in `data/tuning.json`)

| Rule | Was | Now |
| --- | --- | --- |
| Chain links per loop | 1 | n + bonus: 1→1, 2→2, 3→4, 4→5, 5→7, 8→10 |
| Chain tiers | x2/x3/x4 at 2/4/6 loops | x2/x3/x4 at **4/10/18 links** (one pod of three reaches x2; a single reaches it on the fourth) |
| Chain window | 7 s | 7 s + 0.75 s per extra creature in the loop, max 12 s; **banking and wraps also refresh it** |
| Size multiplier | 1.0 / 1.2 / 1.5 / 1.8 / 2.2 / 3.0 | 1.0 / **1.3 / 1.6 / 1.9 / 2.3** / 3.0 |
| TIGHT | area ≤ 60 + 45n, any n | **n ≥ 2** and area ≤ 40 + 36n; a lone creature only if its species has `soloTightArea` (Flutterwink 330, Prickle 60, Ribbubble 90) |
| TIGHT measured on | client polygon | **server-reconstructed area** (§4.4) |
| Bank | "glow × multiplier" | bank points = carried base values × tier (1.0 / 1.25 / 1.5 / 2.0 at 1 / 4 / 8 / 12), added to score **and** paid as glow |

Per creature, a bigger loop now wins on every axis — score, chain links and time — so gathering always beats splitting. Single-farming with expert hands now earns less than competent herding and 31 % of expert herding. `tools/validate.py` fails if a future tuning change reverses either relationship.

## 4. A round, by play pattern (current rules, Meadow slice)

| | Beginner | Competent | Optimizer A (singles) | Optimizer B (herding) |
| --- | --- | --- | --- | --- |
| Loops attempted | 13 | 22 | 44 | 18 |
| Sparks caught | 12 | 43 | 42 | 67 |
| Mean loop size | 1.5 | 2.9 | 1.0 | 4.1 |
| Banks (excluding the buzzer auto-bank) | 3.0 | 4.3 | 3.0 | 4.7 |
| Score 0–25 s (GRAZE) | 14 | 155 | 97 | 359 |
| Score 25–55 s (Bloom Burst) | 37 | 398 | 303 | 908 |
| Score 55–85 s (Stampede) | 56 | 300 | 153 | 915 |
| Score 85–110 s (finale ×1.5) | 18 | 279 | 347 | 694 |
| **Round score** | **124** | **1131** | **901** | **2911** |
| Glow earned (bank points) | 42 | 235 | 264 | 441 |
| Provisional medal | Bronze (80) | Silver (600) | Silver | Gold (1800); Radiant (3000) on a good run |

What each round looks like:

- **Beginner.** First loop at about 8 s for 3 points. Roughly one catch every 9 s. The Stampede is their best half-minute. They finish with a Bronze, about 40 glow (the first upgrade costs 40) and a visible next step: "ring the whole pod".
- **Competent.** One pod every 5 s. A Pip pod is 29 points at x2; the Cubloom flock arriving at 10 links is about 140; a six-creature Bloom ring about 200. Chain sits at x2–x3 with short spells at x4.
- **Optimizer A.** Constant motion, 44 near-identical loops, most of the round at x3–x4, but each loop is worth 6–18 points. Busy and unrewarding by design.
- **Optimizer B.** Fewer loops than the competent player, each two to three times larger. Banks only full parades (×2). The Bloom (270+) and two Stampede loops (up to ~900 for nine at x4 in the finale) are more than half the score.

Provisional medals (`tuning.scoring.medalsProvisional`): Bronze 80, Silver 600, Gold 1800, Radiant 3000. They replace `Config.Medals` for the slice and are recalibrated from real rounds in WP-14. The spread between beginner and competent is wide; if real beginners sit far below Bronze the first lever is Bronze, not the rules.

**Known limits of the model:** no Golden Runaway or rares beyond Flutterwink (slice scope); no co-op; travel ignores obstacles; success rates are guesses. The absolute numbers will move. The ordering is the finding.

## 5. Catch resolution

### 5.1 Who decides what

| Step | Client | Server |
| --- | --- | --- |
| Draw the ribbon | From its own character position every frame | Records its own path from validated positions |
| Detect closure | `Loop.tryClose(ribbon, tuning, liveHead)` | Does not detect closure; it proves a claim |
| Predict the catch | Same containment test on the creatures it is rendering; plays the cinch | — |
| Decide the catch | — | Validates the claimed polygon against its path, tests creatures where they were at the client's view clock, claims atomically |
| Techniques, score | Never sent | Computed from server data only |

### 5.2 Closing (client)

`Loop.tryClose` with the **live head** (the current position, not the last stored sample):

1. **Snap.** If the head is within the snap radius (4.5) of any ribbon *segment* at least 16 studs back along the path, the loop is: nearest point on that segment → the ribbon points after it → the head.
2. **Crossing** (fallback when a fast or laggy step jumps over the ribbon without ever being within 4.5 of it): the intersection point → the points after it.
3. Reject if perimeter < 16 or area < 18. No penalty.

In practice snap fires first almost always; touching *any* older part of your ribbon closes the part between. Containment uses the **non-zero winding rule**, so a ring walked twice around one Spark still contains it.

### 5.3 The claim

Client → server, action `Loop`: `Loop.encode(polygon)` (≤ 56 vertices, arena-relative, 0.1-stud precision), `kind`, and `viewClock` — the herd clock the client was rendering creatures at when it closed.

### 5.4 Reconstruction and validation (server)

**Server path.** Per player, a 6 s ring buffer of `(x, z, t, g)`: appended each time a heartbeat position passes `Rules.movement`, when it is ≥ 2 studs from the last sample. `g` is the ground height of the layer under the player (`GroundMap.height(arena, x, z, rootY)`), so jumps, bounces and launches do not change it. `ribbonStart` = latest of round start, last accepted loop, last ribbon cut.

**Deferral.** The claim usually arrives before the server has seen the last stretch of the run. The server holds the claim until its path's newest sample is within tolerance of the polygon's last vertex, for at most 0.25 s, then validates.

**`Loop.validate(polygon, path, now, ribbonStart)`** rejects with a reason unless all hold (reasons are the strings in the vectors):

| # | Check | Reason on failure |
| --- | --- | --- |
| 1 | 3–56 vertices, finite, inside arena bounds | `vertex-count`, `not-finite`, `out-of-bounds` |
| 2 | 16 ≤ perimeter ≤ maxLength + snapRadius + 6; area ≥ 18 | `perimeter-small`, `perimeter-large`, `area-small` |
| 3 | Path since `max(ribbonStart, now − lifetime − 0.6)` has ≥ 2 samples and no hole > 1.0 s | `no-path`, `path-gap` |
| 4 | Last vertex within 4.0 of the newest path sample | `head-not-reached` |
| 5 | Every vertex within 4.0 of the path | `off-path` |
| 6 | Every path sample between the earliest and latest matched times within 4.0 of the polygon boundary | `path-leaves-polygon` |

Vertex order does not matter; the corridor in both directions (5 and 6) is what proves the polygon is the run.

**Server area.** The path samples between the earliest and latest matched times, closed, form the server's own polygon. Its area decides TIGHT. A client that shrinks its claim to fake TIGHT gains nothing (vector `corner_cut_allowed_not_tight`).

**Exploit bound.** A dishonest client can claim a ring at most 4 studs wider than the one it ran (vector `inflated_r11`), and cannot enclose anywhere it has not been. Rejected claims feed the existing exploit telemetry. Tolerance is a hypothesis: the overlay shows `claimDeviation` (largest vertex-to-path distance of each accepted claim); set tolerance to its p99 + 1.

### 5.5 Which creatures are caught

For each creature in the arena, using a 0.5 s server history of `(clock, x, z, g, catchable)` at the 10 Hz snapshot ticks:

1. **Rewind.** Evaluate at `clamp(viewClock, now − 0.35, now)`, interpolating position between ticks; `catchable` is taken from the tick at or before that clock.
2. **Inside.** `Loop.contains(polygon, x, z, 0.75)` on the *client* polygon — what the player saw.
3. **Same level.** `|g_creature − g_nearest polygon vertex| ≤ 6`.
4. **State.** If the state at that clock is uncatchable (airborne, flying, burrowed, floating, blinking, charging) the creature is reported in `escaped`, not caught.
5. **Claim.** Existing atomic `claim`, in pop order (nearest to the centroid last). First validated claim wins a contested creature; the other player gets ASSIST if they qualify.

### 5.6 Obstacles and heights

| Situation | Resolution |
| --- | --- |
| Ring drawn around a tree, bud or pen | Fine. The polygon is only an outline; solid objects inside it do not matter |
| Creatures on the far side of a wall but inside the outline | Caught. You encircled them |
| Snap chord passes through a thin wall | Allowed; harmless |
| Player jumps a pen wall or the creek mid-ring | Path is continuous in x,z; `g` unchanged |
| Bounce cap (22 studs up) or geyser launch (34) | Ribbon keeps drawing at ground level under the player; `g` is the layer below |
| Shelf (g = 12) ring with floor creatures inside the outline | Not caught: level rule (vector `layer_rule`) |
| Under the Arch | `GroundMap` has two layers there; the player on the floor has `g = 0`, on the deck `g = 12`; creatures match by level |
| Ring that starts on the floor and ends on the shelf | Each creature is compared with its nearest vertex's level, so each half catches its own level |
| Pinch walls (stage 2) | `Loop.tryPinch`: both ribbon ends within 3 studs of the same wall; the wall polyline between them completes the polygon. Server re-derives it from its path and `Design.Arenas.pinchWalls` |

### 5.7 Latency

The client sees its own character now and creatures about `0.1 s + latency` in the past. The rewind in §5.5 evaluates the catch in the client's frame of reference, up to 0.35 s.

| Round trip | What the player experiences |
| --- | --- |
| 0–60 ms | Result arrives inside the 0.30 s cinch. Prediction and result agree almost always |
| 60–250 ms | Result still inside or just after the cinch; the ring holds its tightened shape until it arrives. Rewind makes the catch match what was seen |
| 250–400 ms | Rewind is clamped at 0.35 s: a creature that fled out of the ring in the last moments may be missed. It plays the "nope" hop so the miss is legible |
| No result within 0.8 s | The ring releases as a harmless "slip": no catch, no penalty, chain untouched |

Prediction resolution: creatures the client predicted but the server did not catch un-freeze with the "nope" hop; creatures the server caught that the client did not predict join the pop sequence. The server result is always final.

Related rules:

- **SNAP** compares the server arrival times of `Dash` and `Loop`. Both carry the same latency, so the interval is preserved; 0.35 s window + 0.15 s slack.
- **Ribbon cuts** are decided on the server path with cut radii 0.5 stud *smaller* than the radius drawn on the client, so a ribbon that looked clear is not cut by latency. A claim that uses ribbon older than a cut fails `off-path` and the client plays `ribbon_cut` at the cut point.
- **Two players, one creature:** arrival order after rewind. No tie rule is needed in normal play; the First Spark has its own photo-finish rule (`12`).

## 6. Test vectors (`data/test_vectors.json`)

Generated from the reference by `tools/gen_test_vectors.py`; every vector carries its full input and expected output. WP-02 converts the file into a Luau table and asserts every one.

| Group | Count | Covers |
| --- | --- | --- |
| `closure` | 13 | Pod ring, single ring, double-wound tiny ring, largest ring, too long (length expiry), too slow (time expiry), straight line, out-and-back (area reject), square return, fast crossing, figure-eight (first lobe only), snap just inside / just outside the radius |
| `containment` | 9 | Inside, edge, inflate boundary at 0.7 / 0.8, corners, double-wound centre |
| `validation` | 14 | Honest exact / wobbling / 3-stud shifted; 5-stud shift; 3-stud and 5-stud inflated rings; fabricated; reversed order (accepted); path hole; head not reached; corner cut (accepted, not TIGHT); after a ribbon cut; too many vertices; too small |
| `resolution` | 7 | 150 ms rewind catches; 600 ms request clamped to 350 ms; zero-lag miss; hopper airborne → escaped; hopper crouching → caught; level rule; edge inflate |
| `scoring` | 9 | First single (3), first pod (29), pod with two techniques (43), fourth single (6), flock at x3 (143), Full Bloom (270), nine in the finale at x4 (918), overflow, empty loop |
| `bank`, `chain` | 7 + tables | Bank tiers at 1/3/4/8/11/12/15; links per loop size; multiplier at link counts; window per loop size |

**Adversarial set for `LoopService` (WP-04)** — each must grant nothing and increment telemetry: the six rejected validation vectors; a replay of an accepted polygon (fails on `ribbonStart`); a polygon after a server-authorised teleport; NaN and ±huge coordinates; 500 claims in one second; a claim during intermission; a claim for another arena's coordinates; a `viewClock` in the future (clamped to now) and 10 s in the past (clamped to now − 0.35).
