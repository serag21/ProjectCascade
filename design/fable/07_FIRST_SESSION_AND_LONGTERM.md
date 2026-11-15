# 07 — First session and long-term enjoyment

Timings are targets to measure with the existing funnel metrics (`first_action`, `first_catch`, first full round…), not claims. The **Slice** column says what exists at Checkpoint 1 (`data/slice.json`); anything marked "stage 2" or "stage 3" is absent from the first playable build, and the Checkpoint 1 script (`09` §3) asks only about what is present.

## 1. First session

### 0–10 seconds

| Beat | Slice |
| --- | --- |
| Spawn at the Meadow gate facing north. No menu, no text wall. Camera pulls back for 1.2 s | Yes |
| In view (`mockups/meadow_gameplay_frame.png`): a bank ring 8 studs ahead, three Pips 20 studs ahead on the lawn, the pens and tall grass beyond, the Clover Tree trunk in the distance. The ribbon is already trailing behind the player | Yes |
| A dotted **ghost ring** on the ground around the Pips with a marker tracing it (first round only). Hint: "Run a circle around the Sparks" | Yes |
| The three starter Pips are slowed and cannot be taken by others (existing starter allowance) | Yes |

**Target:** first feedback ≤ 2 s (the ribbon), first loop closed ≤ 10 s.

### 10–30 seconds

| Beat | Slice |
| --- | --- |
| First cinch: three pops on a rising scale, "+29", Pips join the parade | Yes (pops on placeholder audio until upload) |
| The gate bank ring pulses; a ground chevron points to it. Running through banks three | Yes |
| Hint (once): "Bigger ring, bigger score" | Yes |
| A Cubloom flock and the stone pens to the west; a second Pip pod in the tall grass | Yes |

**Target:** first bank ≤ 30 s.

### 30 seconds – 2 minutes (first round)

| Beat | Slice |
| --- | --- |
| 25–30 s: a bloom bud swells; at 30 s it opens — first eight-creature opportunity | Yes |
| First Bunvolt hop out of a ring triggers the hint "Dash to snap a ring shut" (once) | Yes |
| 49 s: rumble, route chevrons, horn. 55 s: the first Stampede | Yes (placeholder horn) |
| 82–85 s: Golden Runaway beam and spawn | **Stage 2.** In the slice the finale is the ×1.5 multiplier and the music layer only |
| 110 s: buzzer, auto-bank | Yes |
| Results sheet: score, medal, best loop | Yes: score, provisional medal, best loop *size*, countdown |
| Best Loop card drawing, one named next goal with CLAIM | **Stage 3** |

**Target:** round done by 2:00 with ≥ 4 loops closed and ≥ 1 loop of 3 or more.

### 2–10 minutes (rounds 2–5)

| Round | New thing | Slice |
| --- | --- | --- |
| 2 | Flutterwink perch timing | Yes |
| 2 | Pinch walls; hint "Walls can finish your ring" | **Stage 2.** In the slice, pens still hold Cublooms in, but the ribbon does not close on walls |
| 2 | First upgrade affordable (Dash Boots) | **Stage 2.** Upgrades are hidden in the slice so everyone tests the same feel; glow still accrues |
| 3 | First Legend (guaranteed), Static Puff | **Stage 2** |
| 3 | Fizz Canyon unlock progress | **Stage 2** (arena travel locked in the slice) |
| 4–5 | Chain bar appears once x2 is first reached | Yes |

In the slice, rounds 2–5 therefore repeat the same content deliberately: the question at Checkpoint 1 is whether the verb holds up over five rounds *without* new systems propping it up.

### 10 minutes – first hour (full game)

- Fizz Canyon unlocks (existing threshold; revisit in WP-14): a different way to play.
- Signature stars appear in the Album; each species' counterplay tip unlocks after its first catch.
- First perk slot (rank 2); Heat after a Silver.
- Daily Stampede offered on the results sheet after round 5, never before.
- First First Spark seen (at most an hour away); probably an assist, not a crown.
- Aurora Arcade is a visible goal for session two.
- **End-of-session hooks:** the results sheet's next goal; "Legend in N rounds" and "First Spark: Canyon in 12:40" on the records board.

### What the first hour must not contain

Loading lectures, forced tutorials, a locked camera, more than one new idea per round, any purchase prompt, any penalty for leaving.

## 2. Long-term enjoyment

The detailed week-four design, the weekly rotation and the single-winner contest are in `12`. Summary:

### Mastery ladder

| Tier | Skill | Evidence the game shows |
| --- | --- | --- |
| 1 | Close loops reliably | Bronze |
| 2 | Ring whole pods; bank at the right ring | ROUNDUP tags, bank ×1.5 |
| 3 | SNAP and TIGHT on demand; beat each species' escape | Signature stars (10 / 25 / 50) |
| 4 | Herd to terrain; merge pods; PINCH; MEDLEY | Technique counts, feats |
| 5 | Stampede horseshoes; 8+ loops; full-parade banks | STAMPEDE! tag, Best Loop card |
| 6 | Hold x4 through a round | Gold / Radiant |
| 7 | Heat 3–5; Gauntlet seals; First Spark crowns | Heat medals, seals, crown count |

The round model (`10`) puts expert herding at about 2.5 × competent play and 23 × a beginner under the same rules, with no stat advantage: the full upgrade set changes dash recharge by 0.9 s, snap radius by 3 studs and capacity by 9.

### What changes week to week (all from `data/rotation.json`)

- **Weekly Gauntlet:** five rule sets rotating, a fixed weekly seed, a board, permanent seals.
- **Weekly Remix:** six modifiers on normal rounds (existing system, re-keyed to loops).
- **Spotlight species:** one per week.
- **Feats:** 21 authored mastery cards, each a single well-played moment.
- **Always on:** Daily Stampede, Heat ladder, signature stars, Legends every fourth cycle, the First Spark hourly per arena.

### Rewards that mean something

Cosmetics that change the **ribbon** (colour, texture, cinch effect, pop sound set), titles, parade formations, crown and ember unlocks. None changes power. Nothing is sold that affects score.

### Social motivation

Shared Legends and Goldens (everyone who helps is rewarded); the First Spark (one crown, real assists); herding assists; arena-wide STAMPEDE! call-outs; a positive-only podium; records boards; the Best Loop card as a screenshot.

### Grind guards

No daily chores, streaks or login rewards; nothing exclusive to a date; goals are play-shaped and rerollable; the album is 12 + 12 gilded + 3 Legends; stars cap at 50 catches; one crown per arena per day.
