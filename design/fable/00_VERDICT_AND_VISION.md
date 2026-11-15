# 00 — Verdict and creative vision

Baseline inspected: `claude/awesome-brown-27rwqo` @ `b1b62fd`. Nothing here is proven fun; it is a design to be judged by the Checkpoint 1 playtest (`09`).

## 1. Verdict on the current build

The owner's playtest is correct, and the source explains each finding.

| Owner finding | Cause in the code | Consequence |
| --- | --- | --- |
| Spam E and Shift to collect | `Config.CaptureRadius = 10`, 0.65 s cooldown, creatures flee at 7–16 against a 22 walk speed; `dashSweep` also catches anything within 4.5 studs of a dash | The optimal play is to stand near creatures and press buttons. No aim, timing or route is required. |
| Dash feels abrupt and glitchy | `Main.server.luau:1300-1320`: the **server** creates a `LinearVelocity` (65 studs/s, 0.28 s) on a character the **client** simulates | The dash starts one round trip late, at constant speed, and snaps at the end. This cannot be tuned away; the authority model is wrong. |
| Flat, empty circular field | `World.buildArena`: a 142-stud disc, four 4.5-stud islands, props only outside the rim | Nothing in the play space creates a decision. |
| Similar creatures clustered | 18 creatures per arena at random positions; every body is the same ~2.8-stud ball with an accessory; four behaviours that are all "move away" | No encounter is different from any other. |
| Catch, bank, repeat is boring | One bank pad, capacity 8, no decision attached to banking | The loop has no tension and no variation. |
| HUD oversized and overlapping | 70-px top bar, objective paragraph, menu button, combo panel, toast, album card, two action buttons, all fixed-offset | Roughly a fifth of a phone screen is panels. |
| 32.8 ms frames, 124 effect parts | Creatures are server Models of ~20 parts each moved every frame; all arenas are live at once; effects are Parts | Budget failures are structural, not tuning. |

The engineering underneath (server authority, saves, Daily Stampede, progression, cosmetics, shared round clock, tests) is sound and is kept. The game on top of it is replaced.

## 2. The identity: **RUN RINGS AROUND THEM**

> **You do not press a button to catch a Spark. You draw a loop around it with your own feet.**

Every player leaves a short-lived glowing ribbon on the ground behind them. Close the ribbon into a ring and everything inside is caught. There is no catch button. The only inputs are **move**, **dash** and **jump**.

Why this, and not a better version of the old loop:

1. **It turns the catch into a physical decision.** How big a ring, around which group, starting from which side, closed where. Those choices repeat every 3–5 seconds and never have one right answer.
2. **It makes herding the core, not an event.** Creatures shy away from the player, so walking a circle around a group squeezes it together. Real sheepdog logic, learned in the first ten seconds without a word of tutorial.
3. **It reads instantly and looks like nothing else on the platform.** A bright ring snapping shut and a cluster of creatures popping on a rising scale is recognisable in a two-second clip.
4. **It scales from one creature to twenty.** A beginner rings one slow Pip. An expert pre-lays a horseshoe across a stampede and snaps it shut around ten.
5. **Each species becomes a different loop problem** (`03`), and each arena changes how loops are drawn (`02`).
6. **It is cheap to build on what exists.** The ribbon is one `Trail`. The server check is a point-in-polygon test against a path it already validates. Carry, bank, chain, medals, album, signatures, Daily and progression all keep their data.

Loop capture is a known mechanic family (line-drawing arcade games; stylus capture games). The combination here is original: third-person body-drawn loops, herding AI that reacts to the body, species-specific counterplay, terrain used as part of the loop, and shared multi-wrap encounters.

### Intended emotions

| Moment | Feeling |
| --- | --- |
| First loop (≤ 10 s) | "Oh — I just run around it." |
| First five-creature ring | Greedy delight; the rising pop scale |
| A hopper escaping over the ribbon | "Next time I close it earlier" (a miss that teaches) |
| The Stampede | Anticipation, then a scramble, then a jackpot |
| A SNAP close with a dash | Precision, a clean click |
| Legend with other players | Shared spectacle; everyone is rewarded |

### What changes, what stays

| Changes | Stays |
| --- | --- |
| Catch button and proximity capture → ribbon loops | Server-authoritative ownership, atomic claims, rate limits |
| Server dash → client-predicted dash with charges | Movement credit budget in `Rules.movement` |
| Flat discs → three authored arenas with distinct movement | Arena origins, shared 110 s clock and phase times |
| 18 random blobs → ≤ 14 creatures in authored pods with behaviours | The 12 species ids, names, colours, values, rarity, signature keys |
| One bank pad → two run-through bank rings per arena | Carry, banking, glow, mutations, album, quests |
| Per-catch chain → per-loop chain | Chain multiplier tiers x1–x4, medals, personal bests |
| Sweeps, Spark Gate, Arena Rally → Bloom Burst, Geysers, Legends | Stampede, Starfall, Golden finale, Static Puffs (re-purposed) |
| HUD panels → five small elements; feedback in the world | Menu tabs, settings, accessibility options |
| Server creature Models → client-built models from packets | HerdNet snapshot approach, interpolation in `CreatureView` |

## 3. Research summary

Method: the previous sessions' research (`docs/research/*`) plus five targeted searches on 2026-11-15. This session's network policy blocks direct page reads of most sources, so the findings below come from **search-result summaries**, not full reads. No game was played. No revenue or retention figures exist for any title and none are claimed.

**Reported by sources (not independently verified):**

- DevForum threads on dash systems consistently report that server-created `LinearVelocity`/constraints start late and feel choppy, and recommend applying the dash on the owning client with server validation; one thread describes Strongest Battlegrounds-style dashes as client-side with an acceleration curve. ([linear velocity delay](https://devforum.roblox.com/t/linearvelocity-has-an-inherent-replication-delay-when-created-on-the-server-and-viewed-on-the-client/2334016/6), [smooth dash thread](https://devforum.roblox.com/t/very-smooth-dash-system-like-strongest-battlegrounds/2590353), [efficient dash](https://devforum.roblox.com/t/how-to-make-an-efficient-and-smooth-dash-system/3066593))
- Fisch's creator set out to avoid "rinse and repeat" simulators with a skill minigame whose difficulty varies per fish; players later pushed back hard on an update that felt like restarting the grind, and on "pay-to-fast" bundles. ([DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481), [Destructoid](https://destructoid.com/roblox-fisch-second-sea-removed))
- Reviews of herding games praise co-op chaos and smooth control, and criticise disobedient animals, too-small herding range and frustrating solo play. ([Sheepherds review](https://ladiesgamers.com/sheepherds-review/), [GameGrin](https://www.gamegrin.com/reviews/sheepherds-review/))
- DevForum feedback threads on struggling games repeat one complaint: fun for a few minutes, then repetitive with no long-term goal. ([example](https://devforum.roblox.com/t/feedback-request-yeet-battles-is-it-actually-fun/3754943))
- A November 2026 list of fast-growing new games is led by a simple social obby; trackers note that social, explainable premises spread and that discovery-dependent spikes are fragile. ([GGRecon](https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/), [RoWatcher weekly](https://rowatcher.com/news/roblox-week-in-numbers-2026-w44))
- Earlier findings still relied on: Roblox discovery now weights longer-term retention; griefing loss, streak FOMO and pay-to-win draw sustained complaints (`docs/research/direction_review_2026-11-05.md`).

**Design hypotheses drawn from them (to be tested, not assumed):**

| # | Hypothesis | Tested by |
| --- | --- | --- |
| H1 | A catch performed with the body is more satisfying than a button near a target | `09` Q1–Q4 |
| H2 | Creatures that bunch when circled avoid the "disobedient flock" frustration, including solo | `09` Q5, herd specs |
| H3 | Per-species counterplay sustains interest the way per-target difficulty does in skill collectors | `09` Q9–Q10, stage 2 |
| H4 | A client-predicted dash on a speed curve removes the "glitchy" feel | `09` Q6, T-D1..3 |
| H5 | Contribution-based shared encounters produce co-operation without theft complaints | `09` multiplayer questions |
| H6 | Three arenas with different movement rules read as three places, not three colours | `09` Q13 |
| H7 | A third-person camera at ~52° pitch makes loop size judgeable | `09` Q7 — the largest risk; fallback in `01` §6 |

## 4. What this design refuses to do

- No second catch verb, no lure, no gadget wheel. Depth comes from species, terrain and events.
- No power sold or granted that skips the loop. Upgrades stay small (`08` §4).
- No timers, streaks, chores, paid randomness or loss of saved progress.
- No claim of fun until the owner has played the slice.
