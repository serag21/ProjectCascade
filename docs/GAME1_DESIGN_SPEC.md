# SPARK STAMPEDE — Game design specification v2 (mastery & retention)

Written 2026-11-04 by the cloud production session. Builds on `GAME1_PRODUCT_CHARTER.md` (product identity, unchanged) and `GAME1_MASTERY.md` (v1 mastery loop, retained). This document is the durable source for *what* the game should be; `BACKLOG.md` tracks *what is left*; `DECISIONS.md` records why. Every numeric value below is a **balance hypothesis** encoded in `game/ReplicatedStorage/Spark/*` and covered by offline tests. None has been validated by real players yet.

## 1. Ruthless new-player critique of the v1 build (pre-session)

| Question | v1 answer | Verdict |
| --- | --- | --- |
| What makes the opening exciting? | Three private starters 8 studs from spawn, bright arena. | Good for clarity; little *excitement* after the first bank. |
| What makes a round more intense? | Herd speed scale changes at 25/55/85 s and one slow orbit sweep. | Weak. No finale, no danger that grows, no reason the last 20 s differ. |
| What requires skill? | Close+facing precision, dash-then-catch timing, 6 s chains, miss penalty. | Real but shallow: 10-stud auto-target makes most catches "walk near, press E". No prediction, routing or tactical choice. |
| Why replay ten times? | Medals/PB, three rotating goals. | Only score chasing; goals repeat after 3 rounds; nothing new appears. |
| Why do friends laugh together? | Shared herd, rally. | Little interaction: no contested moments, no flanking payoff, no scramble. |
| Why return for weeks? | 13 quests, 3×3 upgrades, album to 15 banked. | Content exhausts in ~2–3 hours; upgrades are pure numbers. |

## 2. Design pillars (priority order)

1. **First 20 seconds stay trivial and joyful.** Starter catches and onboarding are untouched; every new system unlocks progressively (rank, banked count) so a newcomer never sees perks, heat, statics or trials before their first bank.
2. **Catching is a skill with a ceiling.** Precision, timing, routing (dash-through lines), prediction (herding into a moving gate), risk management (carry vs bank, buzzer) and threat handling (statics) layer onto one control scheme: move, dash, catch, (bank).
3. **Every round has an arc.** Warm-up → hazards → encounter → golden finale → buzzer. Each arena cycle is exactly one round long, so every personal round contains every encounter once regardless of join time.
4. **Mistakes are recoverable but consequential.** A hit scatters up to two carried sparks *back into the arena* (re-catchable by anyone) and drops the carried style bonus. Saved glow, album and banked score are never removed.
5. **Upgrades are choices.** Permanent upgrades stay modest; *perks* are side-grades with explicit downsides chosen in a 2–3 slot loadout. *Heat* is an opt-in difficulty ladder for experts.
6. **Long-term goals without pressure.** Rank, daily/weekly goals without streak loss, achievements, album tiers, per-arena/per-heat medals and earned cosmetics. No paid randomness, timers you must obey, or punitive streaks.
7. **Social play amplifies, never gates.** Shared rally, assisted gate herding, contested golden spark and scramble pickups; opt-in session scores; everything solo-completable.

## 3. Core verbs and scoring

| Verb | Rule (server-authoritative) | Skill expressed |
| --- | --- | --- |
| Catch (E / X / tap) | Nearest eligible spark in radius (10 + Herd Halo + perks − heat) within forward arc. | Positioning, facing. |
| Precision | ≤4 studs and facing ≥0.70 (0.85 with Long Reach). +15 base style. | Close approach, aim. |
| Dash catch | Catch ≤0.55 s after a dash starts. +20 style. | Timing. |
| **Dash-through** (new) | During the 0.35 s dash, sparks within 4.5 studs of the swept path are caught automatically, up to 2 per dash (4 with Slipstream). Second+ catch in one dash = MULTI +25 each. | Lining up a herd, prediction, route. |
| Chain | Catches ≤6 s apart (perk/heat adjust). Multiplier x1 (1–3), x2 (4–6), x3 (7–9), **x4 STAMPEDE** (10+). Static pops refresh the chain timer. | Rhythm, planning. |
| Miss | Catch with no valid target: chain ends, carried style bonus lost. | Discourages spam-clicking. |
| Bank | Within 12 studs of the gate (auto within 10). Secures carried points. **Haul bonus**: style ×(1 + 0.05·(N−1)), cap ×1.5. **Finale bonus**: banks in the last 25 s of your round ×1.25. | Risk vs reward of carrying. |
| **Buzzer** (new) | Round end auto-banks sparks and base points, but **forfeits carried style bonus**. HUD warns from 15 s. | Bank timing. |

Skill score per round × heat multiplier (1 + 0.2·heat). Medals: Bronze 150, Silver 400, Gold 800, **Radiant 1400** (new, expert target).

## 4. Round arc and arena encounters

Each arena runs a shared 110 s clock (phases at 0/25/55/85). Personal rounds are also 110 s, so each personal round sees each phase once.

| Phase | Shared (arena clock) | Personal |
| --- | --- | --- |
| 0–25 Warm up | Calm herd. | Starters/onboarding. |
| 25–55 | Herd rhythm change; **statics begin** (personal, per heat). | Biome hazard sweep after 25 s eligibility. |
| 55–85 | **Arena encounter** (below). | — |
| 85–110 | **Golden Spark** spawns (1 + 1 per extra 2 players). | Finale bank bonus in your last 25 s; buzzer warning in last 15 s. |

Arena identities (encounters are additive to the existing biome hazards and herd rhythms):

- **Pop Meadow — Spark Gate.** A glowing ring (radius 6) drifts slowly across the infield for 30 s. An ordinary spark that enters while recently spooked (≤4 s) by a player joins that player's parade: **HERDED** +40 style (×chain). A different player who also spooked it within 4 s gets **ASSIST** +30 style. Teaches prediction and flanking.
- **Fizz Canyon — Stampede Run.** Twice in the encounter window, a telegraphed lane (3 s warning arrows) fills with 6 fast sparks sprinting straight across. They ignore players. Dash-through them for multi-catches; catching them normally also works.
- **Aurora Arcade — Spark Gate + Starfall double golden.** The gate appears *and* the golden finale spawns one extra golden spark. Statics start at 20 s instead of 25 s.

**Statics** ("Static Puffs", original fizzing thundercloud creatures): personal to a player (others see them faded and cannot touch them). Spawn ≥30 studs from the bank and ≥16 from the owner, drift toward the owner at 8 studs/s (12.5 at Heat 5) — always slower than walking. Touch (≤3 studs) while not dashing = **ZAP**: miss, 0.8 s catch lock, up to 2 carried sparks scatter back into the arena (3 at Heat 3+). Dash through one = **POP** +40 style (+60 with Static Breaker) and refreshes the chain. Lifetime 12 s. Cap: 1 (Heat 0) … 4 (Heat 5) at once, spawn every 9 s.

**Golden Spark**: a gilded version of the arena's Rare species, value ×3, flees fast (speed ×1.35). Catch = **GOLDEN** +250 style (×chain), album credit to the species and a permanent gilded mark. Contested in multiplayer; nearby helpers who spooked it receive ASSIST.

**Scramble**: scattered sparks are ordinary herd members placed 6–10 studs away; anyone in the arena can recatch them (no duplication: carry entry is removed before the spark is respawned).

## 5. Progression and economy

### 5.1 Glow (soft currency)
Sources: banking (species value 3–16, +3 per trio, golden ×3), quests, daily/weekly goals, rally (+8). Sinks: three permanent upgrades (820 total, unchanged) and **Style** cosmetics (guaranteed prices 150–2,000). Glow is never multiplied by heat (no grind incentive to farm higher numbers).

### 5.2 Rank (XP)
XP per completed round = floor(score/4) + 50 (+ goal/achievement XP). Rank r requires `round(80·(r−1)^1.8)` cumulative XP; cap 50. Rank 2 (first perks) follows any modest first round. Rewards: perks at ranks 2,3,4,6,8,10,12,14; third perk slot at 15; cosmetic trails/titles at 5,9,13,17,20,25,30,35,40,45,50. Economy model (`tools/economy_model.py`, `docs/GAME1_ECONOMY.md`) estimates time-to-rank for novice/regular/expert archetypes.

### 5.3 Perks (side-grades, pick 2; 3 from rank 15)
| Perk | Upside | Downside |
| --- | --- | --- |
| Long Reach | +2.5 catch radius | Precision needs facing ≥0.85 |
| Rhythm Keeper | Chain window +2 s | Multiplier capped x3 |
| Slipstream | Dash-through up to 4, path radius +1 | Dash cooldown +0.5 s |
| Deep Pockets | +4 carry | Haul bonus cap ×1.3 |
| Static Breaker | Pops worth +60 (instead of +40) | Zaps scatter +1 spark |
| Gate Keeper | Herded/assist ×2 | Catch radius −1 |
| Quick Paws | Capture cooldown 0.50 s | Miss also locks catching 0.6 s |
| Golden Nose | Golden compass, golden +50% | Dash catch bonus halved |

### 5.4 Heat (opt-in difficulty)
Heat 1 unlocks after any Silver; Heat n+1 after Silver at Heat n (any arena). Cumulative personal modifiers: H1 statics cap +1 and spawn sooner; H2 chain window −1 s; H3 statics cap +1, zaps scatter 3; H4 catch radius −2.5; H5 chain window −1 s more, sweep warning 1.5 s, statics +55% speed. Score ×(1+0.2·heat). Records and medals are stored per arena per heat.

### 5.5 Goals
- **Daily Sparks**: three goals per UTC day chosen deterministically from a pool, filtered to unlocked arenas/ranks. Each: 30 glow + 60 XP; all three: +50 glow. Missing a day costs nothing.
- **Weekly Sparks**: three cumulative goals per ISO week; each 150 glow + 300 XP.
- **Milestone quests** (existing 13) remain.
- **Achievements** (24): one-time XP + titles; optional Roblox badge IDs (blank until owner creates badges).

### 5.6 Collection
Album tiers per species: Glow (5), Prism (15), **Radiant (40)**, plus a separate **Gilded** mark from golden catches. Players pick their parade **trail** cosmetic (Style tab). Collection never powers stats; it is display and goal content.

## 6. Multiplayer, security, persistence
- All new actions travel through the single validated `Action` RemoteEvent with type/length checks and the existing 0.08 s transport limiter. New payload actions: `Loadout` (array of ≤3 known perk ids), `Heat` (integer 0–5, unlocked), `Style` (known cosmetic id: equip/buy), `Claim` (daily/weekly/achievement ids). The client never sends positions, targets, scores or amounts.
- Dash-through, gate, golden, statics, scramble and buzzer are evaluated server-side from validated character positions (`Rules.movement`).
- Profile schema version 2 adds `rank`, `perks`, `heat`, `records`, `daily`, `weekly`, `achievements`, `style`, `gilded`, `stats`. Version 1 saves migrate on load; unknown keys are discarded; future versions are rejected without overwrite.
- Leaderboards: optional per-arena all-time and weekly OrderedDataStores, written only on a server-verified new personal best, read every 120 s, pcall-wrapped. Studio uses memory doubles.
- Analytics: `AnalyticsService` onboarding funnel (join → first action → first catch → first bank → first round → first upgrade → replay), economy events for glow sources/sinks, custom events for golden/heat/perk usage. pcall-wrapped; no personal data.

## 7. Presentation requirements
- Combo meter: chain count, multiplier badge colored by tier with text label (not color-only), draining timer bar.
- Floating catch tags (PRECISE, DASH, MULTI ×n, HERDED, ASSIST, GOLDEN, POP, ZAP) at world positions; capped; disabled particles in reduced motion.
- Encounter banners with direction arrows; golden compass when visible (or always with Golden Nose).
- Results: medal (incl. Radiant), breakdown, PB delta, XP bar and rank-up, unlock callouts, daily progress.
- Menu tabs: Play (arena, heat, loadout), Goals (daily/weekly/milestones/achievements), Album, Upgrades, Style, Records, Settings. Horizontally scrollable on narrow screens; gamepad focus wraps.
- Reduced motion disables particles, bobbing parade, pop-text motion and trails rendering locally.

## 8. Acceptance criteria (offline-verifiable now; engine-verifiable later)

| ID | Criterion | Offline evidence | Engine evidence still required |
| --- | --- | --- | --- |
| A1 | New player never sees perks/heat/statics/trials before first bank | Pure tests on unlock gating & encounter eligibility | Fresh-profile playthrough |
| A2 | Every personal 110 s round contains warm-up, hazard, encounter and golden phases exactly once | Schedule test across all join offsets | Timed live round |
| A3 | Dash-through catches only sparks within path radius, respects limit/capacity, never duplicates | Geometry + integration tests | Feel/latency test |
| A4 | Zap never removes saved progress; scattered sparks are recatchable and never duplicated | Integration tests on carry/herd counts | 2-client scramble |
| A5 | Buzzer forfeits only style bonus; base points/glow kept | Challenge tests | Live round end |
| A6 | Each perk has a measurable upside and downside | Perk stat tests | Player comprehension |
| A7 | Heat increases difficulty monotonically and its multiplier is bounded | Heat tests | Expert playtest |
| A8 | Daily/weekly goals deterministic per date, claim once, no streak penalty | Progression tests | Live date rollover |
| A9 | v1 profiles migrate without losing collection, glow, upgrades or quests | Profile migration tests | Real DataStore load |
| A10 | Economy: regular player reaches rank 10 in 3–6 h, all upgrades in 1.5–3 h, album complete in 4–10 h (model) | `tools/economy_model.py` output | Live telemetry after launch |
| A11 | All remotes reject malformed payloads | Abuse tests | Engine injection |
| A12 | Expert ceiling: perfect-play model reaches Radiant at Heat 5 only with ≥80% precision/dash use | Score model | Expert playtest |
