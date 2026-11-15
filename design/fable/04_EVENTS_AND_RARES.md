# 04 — World events, rare encounters and multiplayer

Authoritative data: `data/events.json` (times, rules, telegraphs), `data/creatures.json` (`variants`, `legends`, `hazards`) and `data/first_spark.json`. Only the Stampede and Bloom Burst are in the Checkpoint 1 slice (`data/slice.json`).

## 1. The round as a three-act piece

The shared 110 s clock and its phase boundaries (0 / 25 / 55 / 85) are unchanged, so `Cycle`, `Encounters`, music and late-join behaviour keep working.

| Time | Beat | What the player does |
| --- | --- | --- |
| 0–25 | **GRAZE** | Warm-up loops on calm pods; start a chain |
| 25 | Telegraph of the arena's signature event | Reposition |
| 30–46 | **Signature event** (Bloom Burst / Fizz Geysers / Starfall) | First big-loop opportunity |
| 49 | Stampede telegraph: rumble, route chevrons | Bank if full; get to the route; lay a horseshoe |
| 55–69 | **STAMPEDE** | The jackpot loop(s) |
| 68–108 | *(every 4th cycle)* **Legend** | Shared multi-wrap encounter |
| 82 | Golden beam | Find it |
| 85–110 | **GOLDEN FINALE** (loops ×1.5) | Golden Runaway; last bank before the buzzer |

Each round has three scheduled peaks with quiet between them. The quiet is where chain-building and species play happen.

## 2. Events

### STAMPEDE (all arenas, 55 s) — the title moment
A column of 12–18 native creatures charges along one of the arena's two authored routes at 26 studs/s, three abreast. They ignore players (swerving up to 4 studs around a body) and are caught by loops like anything else.
- **Telegraph (6 s):** rumble, dust at the entry, the full route drawn in marching chevrons, a horn at 53 s.
- **Skill:** lay an open horseshoe across the route before the column arrives and SNAP it shut as it fills. Late loops catch stragglers only.
- **Per arena:** Meadow routes sweep the open north and south fields. Canyon routes are the two legs of THE RUN, so the chokes are the prize positions. Aurora's ice route sends the herd *sliding* across the lake.
- **Fairness:** the route never crosses a bank ring or spawn; each player's loop is their own.

### BLOOM BURST (Meadow, 30 s)
One of three giant buds swells for 5 s and opens: 5 Pips and 3 Cublooms tumble out and feed in a 7-stud cluster for 6 s, then scatter away from the nearest player. Ring all eight for **FULL BLOOM** (+40 style). Rushing inside 5 studs scatters them early.

### FIZZ GEYSERS (Canyon, 30 s)
Three of five geysers erupt 4 s apart. Creatures within 9 studs are launched and land together, dazed for 3 s. A player on the geyser is launched 34 studs with air control. Herd a pod (or bowl a Sunshell) into the ring before it blows, then loop the landing cluster. Dazed catches carry the **FIZZED** tag.

### STARFALL (Aurora, 30 s) — kept and extended
The existing Starfall choreography, retargeted to six authored impact points. Impacts daze creatures within 8 studs for 3 s (**STARSTRUCK**). New: each impact leaves a glowing crater rim for 10 s that works as a temporary pinch wall. Players are pushed, never penalised.

## 3. Rare encounters

### Golden Runaway (every round, 85 s)
A gilded member of a native species spawns at the habitat farthest from all players, 35 % faster, needing one more wrap than its species (minimum 2). Wrap progress is shared and lasts 8 s. **Every player who landed a wrap receives the catch** — triple value, the Gilded album mark, and the GOLDEN tag. There is no last hit to steal.

### Legends (one per arena)
| Legend | Arena | Wraps | Behaviour | What it tests |
| --- | --- | --- | --- | --- |
| **Grandbloom** | Meadow | 4 | Hill-sized grazer on a slow walk; each wrap shakes loose 3 Pips and speeds it up | Large clean loops (≥ 60 perimeter) under time |
| **Thunderhoof** | Canyon | 3 | Leads its own stampede of 8 Zip Tails around THE RUN at 28 | Intercept loops at the chokes |
| **Borealynx** | Aurora | 3 | Glides between three lake markers, pausing 3 s on each; blinks on when wrapped | Ice-glide loops timed to a pause |

- **Schedule:** deterministic — every fourth arena cycle at 68 s, announced from 58 s. The records board shows "Legend in N rounds". A player's third-ever round always contains one (first-session wow moment).
- **Window:** 40 s. Solo-completable with clean play; designed to be finished comfortably by 2–4.
- **Reward:** every contributor gets the Legend album stamp, score proportional to their wraps with a 50 % floor, and one Legend Token. Three tokens unlock that Legend's cosmetic trail. No random drop, nothing purchasable, failure costs nothing.

### The First Spark (hourly per arena; one winner)
The scarce, single-winner contest: a UTC-scheduled Spark that touches down five times; three rings catch it; the player who landed the most rings is crowned and the other ring-landers earn a real assist. Full rules, fairness cases and evidence: `12` §1.

### Static Puff (existing hazard, re-purposed)
Still per-player and still from the third round. It now drifts toward its owner's **ribbon**: touching the ribbon cuts it (no score penalty). Touching the owner scatters two parade members, recatchable. Dash through it to pop it. It gives the ribbon something to be defended from, and makes long greedy loops a risk.

## 4. Multiplayer design

| Goal | Mechanism |
| --- | --- |
| Co-operation that is felt | Shared wraps (Antlume, Golden, Legends): everyone who contributes is rewarded. Herding assists: if a creature you were pushing within the last 1.5 s is caught by someone else, you get **ASSIST** points and full album credit (existing `creditAssist`, extended to album) |
| Competition without theft | Loops are personal. Podium awards (existing) are re-keyed: Biggest Loop, Longest Chain, Golden Wrangler, Best Herder (assists), Static Buster. Nobody is ranked last. The one single-winner prize is the First Spark, decided by contribution, not last hit |
| Spectacle | An 8+ loop announces STAMPEDE! to the arena; Legends dim the sky; bank fountains are visible to all |
| No griefing | Players do not collide. Ribbons do not interact. Nobody can cut another's ribbon, block a ring, or take anything from a parade. Scattered parade members are recatchable by their owner first for 2 s |
| Solo always complete | Every multi-wrap target is achievable alone within its window; no event requires a second player |
| Late join / leave | Joiners enter on the shared clock (existing `Cycle.joinPlan`); a leaver's wraps stay on the target until they expire |

**Considered and rejected:** linking two players' ribbons into one joint loop. It is appealing but needs general planar closure across independently validated paths, and it lets a careless partner waste your ribbon. Shared wraps deliver the same "we did that together" outcome with far less risk. Revisit only if co-op playtests ask for it.

## 5. Systems removed

| Removed | Reason |
| --- | --- |
| Arena sweeps (`ArenaEvents.hazard`) | A dodge hazard unrelated to the loop; pure clutter |
| Spark Gate | Herding is now the core; replaced by Bloom Burst |
| Arena Rally | Replaced by Legends (reward path reused) |
| CATCH button, proximity capture, dash-through capture | Replaced by loops |
