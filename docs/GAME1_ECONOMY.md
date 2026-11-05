# SPARK STAMPEDE — economy and progression model

Generated 2026-11-05 (v2: cycles, cosmetics, glow gifts, Daily Stampede) from `tools/economy_model.luau`, which drives the **real production modules** (Challenge, Profile, Loadout, Progression, Cosmetics, Trial) with synthetic players. Reproduce with `.tools/luau/luau tests/SparkEconomy.spec.luau` (prints this table and asserts the pacing bounds). **These are balance hypotheses, not player data.** Replace with live telemetry after launch.

## Assumptions (per synchronized 120 s Stampede Cycle = 2.0 min; Daily Stampede run + retry = 1.4 min)

| Archetype | Catches | Precision | Dash catches | Multi-dash events | Herded | Pops | Zaps | Golden chance | Miss rate | Banks every | Rounds/day | Max Heat | Daily Stampede runs/day |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| novice | 14 | 20% | 10% | 0.3 | 0.4 | 0.3 | 2 | 12% | 25% | 5 | 8 | 0 | 1 |
| regular | 24 | 40% | 25% | 2 | 2 | 2 | 1 | 40% | 12% | 7 | 12 | 2 | 2 |
| expert | 36 | 65% | 45% | 5 | 4 | 5 | 0.4 | 80% | 5% | 9 | 20 | 5 | 4 |

Players buy the cheapest upgrade when affordable, then trails by list order, then priced formations/bursts/tags cheapest first; rank-up Glow Gifts are paid by the real `grantXp`; after the day's second round they play their Daily Stampede runs (normalized rules, scaled to 75 s with 20 private Sparks), settled by the production `Trial.settle`; claim quests and daily/weekly goals whenever complete; rotate through unlocked arenas favouring the newest; use their archetype's perks as soon as ranks allow and the highest unlocked Heat up to their comfort ceiling.

## Result (1,500 rounds per archetype; hours include Daily Stampede runs)

| Milestone | novice | regular | expert |
| --- | --- | --- | --- |
| rank2 | 1 rounds (0.0 h) | 1 rounds (0.0 h) | 1 rounds (0.0 h) |
| rank5 | 8 rounds (0.3 h) | 2 rounds (0.1 h) | 2 rounds (0.2 h) |
| rank10 | 31 rounds (1.1 h) | 15 rounds (0.6 h) | 6 rounds (0.3 h) |
| rank15 | 79 rounds (2.9 h) | 47 rounds (1.8 h) | 27 rounds (1.1 h) |
| rank20 | 160 rounds (5.8 h) | 110 rounds (4.1 h) | 64 rounds (2.5 h) |
| rank30 | 394 rounds (14.3 h) | 280 rounds (10.5 h) | 170 rounds (6.5 h) |
| rank40 | 730 rounds (26.5 h) | 524 rounds (19.5 h) | 334 rounds (12.7 h) |
| rank50 | 1160 rounds (42.1 h) | 841 rounds (31.3 h) | 539 rounds (20.5 h) |
| canyon | 3 rounds (0.1 h) | 2 rounds (0.1 h) | 1 rounds (0.0 h) |
| aurora | 8 rounds (0.3 h) | 4 rounds (0.2 h) | 3 rounds (0.2 h) |
| allUpgrades | 13 rounds (0.5 h) | 7 rounds (0.3 h) | 4 rounds (0.2 h) |
| album12 | 10 rounds (0.4 h) | 5 rounds (0.2 h) | 4 rounds (0.2 h) |
| allPrism | 27 rounds (1.0 h) | 12 rounds (0.4 h) | 9 rounds (0.4 h) |
| allRadiant | 135 rounds (4.9 h) | 75 rounds (2.8 h) | 54 rounds (2.1 h) |
| gilded12 | not reached | 201 rounds (7.5 h) | 120 rounds (4.6 h) |
| allTrails | 548 rounds (19.9 h) | 398 rounds (14.9 h) | 245 rounds (9.4 h) |
| allCosmetics | 1062 rounds (38.5 h) | 770 rounds (28.7 h) | 495 rounds (18.9 h) |
| heat1 | 33 rounds (1.2 h) | 1 rounds (0.0 h) | 1 rounds (0.0 h) |
| heat5 | not reached | not reached | 5 rounds (0.3 h) |
| median score | 649 | 2701 | 8460 |
| p90 score | 884 | 4481 | 13448 |
| achievements after run | 11 | 17 | 20 |
| glow balance after run | 151130 | 377466 | 514938 |
| Daily Stampede median (medal) | 337 (Bronze) | 1435 (Silver) | 4246 (Gold) |
| Daily Stampede p90 (medal) | 573 (Bronze) | 2465 (Gold) | 7395 (Radiant) |
| Daily Stampede runs / glow / XP | 188 / 7520 / 25864 | 250 / 5000 / 34484 | 300 / 3000 / 51824 |
| hours played | 54.4 | 55.9 | 57.1 |

## Calibration decisions (2026-11-04)

The first model run exposed runaway inflation: regular players reached rank 50 in ~3.5 h, maxed all upgrades in 3 rounds, and median scores were 4× the old medal thresholds. Changes:

1. **Chain tiers every 5 catches** in live rules (x2 from a 6-chain, x3 from 11, x4 STAMPEDE from 16). Legacy callers keep the old 3-step for test stability.
2. **Medals rescaled** in `Config.Medals`: Bronze 300, Silver 1,000, Gold 2,500, Radiant 5,000. Model medians: novice ≈ Bronze/Silver, regular ≈ Gold, experts reach Radiant at Heat.
3. **Round XP = 4·√score + 60** (experts progress ~2× faster, not 10×), **rank r needs 100·(r−1)²** XP. Rank 2 (first perks) after any 100-point first round; rank 15 (third perk slot) ≈ 2 h regular; rank 50 ≈ 30 h regular / 43 h novice / 21 h expert.
4. **Upgrade costs** 40/160/450, 50/180/500, 40/150/420 (1,990 total). First upgrade after round 1; all upgrades ≈ 15–30 min.
5. **Collection depth**: Radiant tier at 50 banked; any species can appear as the golden finale, creating a 12-entry **Gilded** set (≈ 8.6 h regular).
6. **Cosmetic sink** expanded to 21 trails (≈ 43,300 glow of guaranteed prices plus rank/achievement trails), lasting ≈ 14 h for a regular player.

## Calibration decisions (2026-11-05, final production plan Phases 4–5)

1. **Cycle time** is a fixed 120 s (110 play + 10 intermission), replacing the old 110 s + ~12 s replay overhead.
2. **Cosmetic sink (D20)**: 12 formations, 20 bank bursts, 24 name tags and 10 rank titles. Every rank-up grants something, ranks 29/39/48 as Glow Gifts. Priced items add an 88,500-glow sink on top of the trails. A regular player now finishes **all priced cosmetics in ≈ 29 h** (target ≥ 25 h); a novice in ≈ 39 h; an expert in ≈ 19 h.
3. **Daily Stampede rewards** are deliberately small: +40 glow and +80 XP on the first completed run of each UTC day, plus `floor(2·√score)+20` XP for the first five completed runs. Trial banks pay **no glow or album progress**, so unlimited retries cannot become a farm. Model check: Daily Stampede glow is exactly 40 per played day.
4. **Daily Stampede medals** recalibrated to Bronze 300 / Silver 800 / Gold 2,000 / Radiant 5,000. The first thresholds (1,600 Gold / 2,800 Radiant) put the expert *median* at Radiant. Now: novice median Bronze, regular median Silver (p90 Gold), expert median Gold (p90 Radiant).

## Known risk: glow surplus after ~29 h

Glow income for a regular player is ≈ 300 per round (≈ 9,000/h). After upgrades, all trails and all priced cosmetics are bought (≈ 29 h for regulars), glow accumulates with nothing to spend it on (model balance ≈ 377,000 after 1,500 rounds). This does not break gameplay (glow buys no power), but it makes glow meaningless for dedicated players. **Post-launch plan:** add earned seasonal cosmetic sets (trails, parade auras, title frames) and possibly species "parade skins" priced 2,000–15,000; review real glow/h telemetry before choosing prices. Do **not** fix this with paid currency, random paid rewards or glow-for-power purchases.

## Acceptance bounds enforced by `tests/SparkEconomy.spec.luau`

Rank 2 after the first round for every archetype; all priced cosmetics take ≥ 25 h for regulars (≥ 12 h for experts); Daily Stampede median medals novice Bronze / regular Silver / expert Gold, with Radiant reachable by experts; Daily Stampede glow exactly once per day and below banked totals; second arena within 30 min; rank 50 ≥ 15 h for everyone and 25–80 h for regulars; skill speeds progress but experts are never more than 3× faster than novices; novices max upgrades in 15 min–2 h; regular rank 10 in 0.4–3 h and rank 15 in 1–5 h; Radiant album ≥ 1.5 h; Gilded set ≥ 3 h; cosmetic sink ≥ 3 h; novice median Bronze–Silver; regular median Silver–Gold; experts reach Radiant; novices never reach Heat 5.
