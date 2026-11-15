# 12 — The single-winner contest, and what brings a skilled player back in week four

Data: `data/first_spark.json`, `data/rotation.json`. Shared Legends (`04` §3) are unchanged: everyone who contributes is rewarded. This document adds the one thing they deliberately are not — a scarce prize only one player wins.

## 1. THE FIRST SPARK

> Once an hour, in each arena, a white-gold Spark crosses the sky and touches down five times. Three rings catch it. One player wears the crown.

### Rules

| | |
| --- | --- |
| **When** | UTC wall clock, the same on every server: Meadow at :00, Canyon at :20, Aurora at :40. It starts at the mark if the arena's round clock is between 5 s and 80 s, otherwise at the first moment it is (worst case 45 s late) |
| **Telegraph** | Always: a countdown on the Play tab and every records board. 60 s before: a sky beam over the first touchdown. 10 s before: all five touchdown points ("glints") light up, numbered, joined by a line in the sky |
| **Course** | Five glints per arena, 30–60 studs apart (`first_spark_glints` in each arena file, drawn on the maps). It rests 2.6 s on each (catchable), then streaks 2.0 s to the next (uncatchable). 23 s in total |
| **Behaviour** | It does not flee and cannot be herded or shoved. The test is being at the right glint and ringing it cleanly |
| **Capture** | The first valid loop around it at a rest lands **one ring**, and it leaves at once. **Three rings** catch it |
| **Photo finish** | All valid claims reaching the server within 0.15 s of the first compete; the **smallest** server-measured loop takes the ring |
| **Winner** | When the third ring lands, the player with the **most rings** is crowned. Ties: smallest total ring area, then earliest final ring |
| **Expiry** | After the fifth rest it leaves. Fewer than three rings: no crown, ring score kept, nothing lost |
| **Eligibility** | Anyone playing the round in that arena may ring it, including a player who joined mid-window. To be crowned you must not already hold today's crown for that arena; if the top contributor does, the crown passes to the next and they take the assist reward |
| **Cap** | One crown per arena per UTC day per player |

### Rewards

| | Winner (one player) | Assist (landed a ring or lost a photo finish, on a successful capture) |
| --- | --- | --- |
| Now | +150 score; **Sparkbearer aura** — white-gold ribbon and a crown by the name, seen by everyone, until the next First Spark there; server-wide announcement | +90 score (60 %) |
| Kept | +1 **Crown** for that arena | +1 **Ember**; "Witnessed the First Spark" album stamp |
| Unlocks | 1: title *Sparkbearer* · 3: Firstlight ribbon · 10: Firstlight cinch · 25: title *First Among Sparks* and the crown count on the nameplate | 4: Emberlight ribbon · 12: Emberlight cinch · 30: title *Kindler* |

Each ring also scores 40 on the spot. No reward affects play. Nothing is purchasable, random or lost.

### Why these rules

| Decision | Reason | Evidence and its quality |
| --- | --- | --- |
| Winner is whoever landed the **most** rings, not the last | Last-hit rules make the player who did the work feel robbed. Here, finishing someone else's two rings gives *them* the crown and you the assist, so there is nothing to steal and every reason to finish | Kill-stealing complaints are long-standing (earlier research, weak source). Guild Wars 2 is described as avoiding the problem by rewarding every participant individually ([Hardstuck guide](https://hardstuck.gg/gw2/guides/general/game-systems-and-mechanics/)); players still object where contribution rules ignore support roles ([dev tracker thread](https://devtrackers.gg/guild-wars-2/p/f1aa3d3f-we-need-to-talk-about-the-enemy-tagging-system)). **Search summaries only** |
| Schedule is UTC and identical on every server | Where a rare spawn is per-server, players rejoin or hop servers to force it, and those who cannot call it unfair | Reported for The Forge's private servers on a fan site ([rosenberryrooms](https://www.rosenberryrooms.com/the-forge-raven-cave-update-why-players-are-furious/)) and for Fallout 76 event hopping on a Steam forum. **Search summaries only; anecdotal** |
| Daily cap of one crown per arena | Stops one strong player taking every crown in a regular group, and bounds private-server farming to three a day | Design reasoning; contribution systems are criticised when a large group can take the reward from smaller players (Throne and Liberty forum posts, **search summary only**) |
| No crown leaderboard | A ranking of an hourly event rewards attendance, which is the streak/FOMO pattern players resent | Earlier research (N3 in `docs/research/direction_review_2026-11-05.md`); Grow a Garden's reliance on fear of missing out is noted by a blog (**weak**) |
| Photo finish decided by loop size | Otherwise the lower ping wins every tie | Latency complaints in timing games (earlier research N6, weak) |
| Assist is a real currency with its own unlocks | "Meaningful" has to mean progress toward something visible | Design reasoning |

### Fairness cases

| Case | Outcome |
| --- | --- |
| **Solo player** | Must land all three rings: reach 3 of 5 glints with 4.6 s between touchdowns. The longest hop is 51–57 studs (2.1–2.4 s on foot), leaving about 2 s to ring. Hard, and the same for everyone. If playtests show solo crowns are far easier than contested ones, `soloRestSeconds` shortens the solo rest (2.0–2.6 s) |
| **Late joiner, mid-window** | Can ring any remaining rest and can win |
| **Late joiner, after it left** | Sees the countdown to the next one, at most an hour away, or 20 minutes in the next arena |
| **Two players, one glint, same instant** | Photo finish: tighter ring wins; the other is assist-eligible |
| **A lands two rings, B lands the third** | A is crowned. B gets the assist |
| **A, B and C land one each** | Smallest total area wins; the other two get the assist |
| **Top contributor already crowned today** | Crown passes down; they get the assist |
| **Only two rings landed** | It escapes. Ring scores kept; no crown, no Ember |
| **Griefing** | Players do not collide and ribbons do not interact; a glint cannot be blocked |
| **Private server** | Same schedule; crowns count; the daily cap applies |
| **Player in the Daily Stampede or sitting out** | Not eligible that time |

## 2. Why a skilled player is still here in week four

By week four a skilled player has all three arenas, most upgrades (their total effect is small by design) and probably Gold in each arena. What is left has to be skill, variety and prestige.

### What is different in week four

| Layer | Week 1 | Week 4 | Runs from |
| --- | --- | --- | --- |
| **Weekly Gauntlet** | First seal | A different gauntlet each week (five rotate): this week's rule, a fixed weekly seed on a rotating arena, unlimited attempts, a weekly best-score board, a permanent seal tier to raise | `rotation.json` gauntlets |
| **Weekly Remix** | First modifier | A different one (six rotate), changing normal rounds for everyone | `rotation.json` remixes (existing `Remix.luau`) |
| **Spotlight species** | — | One species per week has an extra pod and double signature credit; a reason to practise that counter | `rotation.json` weekly.spotlight |
| **Feats** | 2–4 of 21 | The hard ones remain: *Roadblock* (catch a running Zip Tail), *Before It Blinks*, *Lasso* (ring 10), *Unbroken* (x4 from Stampede to buzzer), *Heartbeat Gold* | `rotation.json` feats |
| **Heat** | Heat 0–1 | Heat 3–5 medals per arena | existing |
| **First Spark** | Probably none | Chasing crowns: three chances an hour, one per arena per day | `first_spark.json` |
| **Legends** | First stamps | Finishing token sets for the three Legend trails | `events.json` |
| **Daily Stampede** | Occasional | Daily board | existing |
| **Signature stars** | A few ★1 | ★2–★3 on favourites (10 / 25 / 50) | existing |

### The explicit rotation

Week index `w` = `Progression.week(now)` (UTC, Monday start).

| Element | Formula | Cycle |
| --- | --- | --- |
| Remix | `remixes[w mod 6]` | 6 weeks |
| Gauntlet | `gauntlets[w mod 5]` | 5 weeks |
| Gauntlet arena | `[meadow, canyon, aurora][w mod 3]` | 3 weeks |
| Spotlight | `Config.Creatures[(5w) mod 12]` | 12 weeks, visits all twelve |

The first eight week indices:

| w | Remix | Gauntlet | Arena | Spotlight |
| --- | --- | --- | --- | --- |
| 0 | Golden Rush | One Short Ribbon | Meadow | Pip Pop |
| 1 | Big Herd | Feet Only | Canyon | Zip Tail |
| 2 | Rhythm Week | Three Stampedes | Aurora | Starwhirl |
| 3 | Stampede Season | Big Game | Meadow | Flutterwink |
| 4 | Starfall Everywhere | Full Parade | Canyon | Crownlet |
| 5 | Fizz Festival | One Short Ribbon | Aurora | Bunvolt |
| 6 | Golden Rush | Feet Only | Meadow | Prism Prickle |
| 7 | Big Herd | Three Stampedes | Canyon | Antlume |

The same full combination returns after 60 weeks; any gauntlet returns on a different arena after 5.

### The five gauntlets

| Gauntlet | Rule | Tests |
| --- | --- | --- |
| One Short Ribbon | Ribbon 3.0 s / 70 studs | Tight, efficient loops |
| Feet Only | No dash | Herding and positioning without SNAP or shoves |
| Three Stampedes | No pods; Stampedes at 20, 55, 90 s | Horseshoe timing, big loops |
| Big Game | Only Uncommon and Rare species | Every species counter back to back |
| Full Parade | Bank only when full; a zap ends the run | Risk and routing |

Format: one 110 s solo run on the Trial paddock, seeded by the week (reuses the Daily Stampede machinery). Seals Bronze / Silver / Gold / Radiant at 0.5 / 1.0 / 1.6 / 2.2 × that gauntlet's par score; the best seal is permanent. Each gauntlet owns one ribbon texture set (Silver unlocks, Gold recolours, Radiant animates), available every time that gauntlet returns.

### Rules that keep this from becoming a chore

| Rule | Player criticism it answers |
| --- | --- |
| Nothing is exclusive to a date; every gauntlet and its rewards return every five weeks | Streak and FOMO complaints (earlier research N3) |
| Targets are one well-played moment or one good run, never a count of repetitions | "Fun for a few minutes, then repetitive" in DevForum feedback threads; Fisch players quitting when an update felt like restarting the grind ([Destructoid](https://destructoid.com/roblox-fisch-second-sea-removed)) — **search summary only** |
| No reward changes dash, ribbon, capacity or score | Pay-to-win and "pay-to-fast" complaints (same sources) |
| No daily login reward, no streak, no timer that punishes absence | N3 |
| Skill ladders are permanent (feats, seals, Heat medals, stars) and cannot be lost | Loss-of-progress complaints (N2) |

### Content that is data only

Adding an entry to `remixes`, `gauntlets` or `feats.list`, a species' pod to a spare habitat, a fourth-arena JSON, a Legend, or a ribbon cosmetic set changes the game without new systems (WP-21 includes a test that proves it for the three lists). That is the post-launch cadence: one list entry a week is a real update.

### What only play can settle

Whether a 23-second hourly contest is exciting or stressful; whether three rings alone is fair; whether gauntlet rules are distinct enough to feel like different games; whether anyone cares about seals. These are Checkpoint 2 and beta questions (`09`).
