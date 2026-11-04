# SPARK STAMPEDE — economy and progression model

Generated 2026-11-04 from `tools/economy_model.luau`, which drives the **real production modules** (Challenge, Profile, Loadout, Progression) with synthetic players. Reproduce with `.tools/luau/luau tests/SparkEconomy.spec.luau` (prints this table and asserts the pacing bounds). **These are balance hypotheses, not player data.** Replace with live telemetry after launch.

## Assumptions (per 110 s round + ~12 s results/replay = 2.03 min)

| Archetype | Catches | Precision | Dash catches | Multi-dash events | Herded | Pops | Zaps | Golden chance | Miss rate | Banks every | Rounds/day | Max Heat |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| novice | 14 | 20% | 10% | 0.3 | 0.4 | 0.3 | 2 | 12% | 25% | 5 | 8 | 0 |
| regular | 24 | 40% | 25% | 2 | 2 | 2 | 1 | 40% | 12% | 7 | 12 | 2 |
| expert | 36 | 65% | 45% | 5 | 4 | 5 | 0.4 | 80% | 5% | 9 | 20 | 5 |

Players buy the cheapest upgrade when affordable, then trails by list order; claim quests and daily/weekly goals whenever complete; rotate through unlocked arenas favouring the newest; use their archetype's perks as soon as ranks allow and the highest unlocked Heat up to their comfort ceiling.

## Result (1,500 rounds per archetype)

| Milestone | novice | regular | expert |
| --- | --- | --- | --- |
| rank2 | 1 rounds (0.0 h) | 1 rounds (0.0 h) | 1 rounds (0.0 h) |
| rank5 | 8 rounds (0.3 h) | 3 rounds (0.1 h) | 2 rounds (0.1 h) |
| rank10 | 34 rounds (1.2 h) | 20 rounds (0.7 h) | 7 rounds (0.2 h) |
| rank15 | 96 rounds (3.3 h) | 56 rounds (1.9 h) | 29 rounds (1.0 h) |
| rank20 | 179 rounds (6.1 h) | 115 rounds (3.9 h) | 71 rounds (2.4 h) |
| rank30 | 436 rounds (14.8 h) | 288 rounds (9.8 h) | 196 rounds (6.6 h) |
| rank40 | 805 rounds (27.3 h) | 554 rounds (18.8 h) | 383 rounds (13.0 h) |
| rank50 | 1283 rounds (43.5 h) | 903 rounds (30.6 h) | 614 rounds (20.8 h) |
| canyon | 3 rounds (0.1 h) | 2 rounds (0.1 h) | 1 rounds (0.0 h) |
| aurora | 8 rounds (0.3 h) | 4 rounds (0.1 h) | 3 rounds (0.1 h) |
| allUpgrades | 14 rounds (0.5 h) | 7 rounds (0.2 h) | 4 rounds (0.1 h) |
| album12 | 10 rounds (0.3 h) | 5 rounds (0.2 h) | 4 rounds (0.1 h) |
| allPrism | 21 rounds (0.7 h) | 12 rounds (0.4 h) | 9 rounds (0.3 h) |
| allRadiant | 126 rounds (4.3 h) | 75 rounds (2.5 h) | 57 rounds (1.9 h) |
| gilded12 | not reached | 255 rounds (8.6 h) | 138 rounds (4.7 h) |
| allTrails | 606 rounds (20.5 h) | 415 rounds (14.1 h) | 282 rounds (9.6 h) |
| heat1 | 82 rounds (2.8 h) | 1 rounds (0.0 h) | 1 rounds (0.0 h) |
| heat5 | not reached | not reached | 6 rounds (0.2 h) |
| median score | 642 | 2668 | 8246 |
| p90 score | 876 | 4427 | 13488 |
| achievements after run | 13 | 17 | 20 |
| glow balance after run | 229213 | 457575 | 598305 |

## Calibration decisions (2026-11-04)

The first model run exposed runaway inflation: regular players reached rank 50 in ~3.5 h, maxed all upgrades in 3 rounds, and median scores were 4× the old medal thresholds. Changes:

1. **Chain tiers every 5 catches** in live rules (x2 from a 6-chain, x3 from 11, x4 STAMPEDE from 16). Legacy callers keep the old 3-step for test stability.
2. **Medals rescaled** in `Config.Medals`: Bronze 300, Silver 1,000, Gold 2,500, Radiant 5,000. Model medians: novice ≈ Bronze/Silver, regular ≈ Gold, experts reach Radiant at Heat.
3. **Round XP = 4·√score + 60** (experts progress ~2× faster, not 10×), **rank r needs 100·(r−1)²** XP. Rank 2 (first perks) after any 100-point first round; rank 15 (third perk slot) ≈ 2 h regular; rank 50 ≈ 30 h regular / 43 h novice / 21 h expert.
4. **Upgrade costs** 40/160/450, 50/180/500, 40/150/420 (1,990 total). First upgrade after round 1; all upgrades ≈ 15–30 min.
5. **Collection depth**: Radiant tier at 50 banked; any species can appear as the golden finale, creating a 12-entry **Gilded** set (≈ 8.6 h regular).
6. **Cosmetic sink** expanded to 21 trails (≈ 43,300 glow of guaranteed prices plus rank/achievement trails), lasting ≈ 14 h for a regular player.

## Known risk: glow surplus after ~14 h

Glow income for a regular player is ≈ 300 per round (≈ 9,000/h). After upgrades and all trails are bought, glow accumulates with nothing to spend it on (model balance ≈ 450,000 after 1,500 rounds). This does not break gameplay (glow buys no power), but it makes glow meaningless for dedicated players. **Post-launch plan:** add earned seasonal cosmetic sets (trails, parade auras, title frames) and possibly species "parade skins" priced 2,000–15,000; review real glow/h telemetry before choosing prices. Do **not** fix this with paid currency, random paid rewards or glow-for-power purchases.

## Acceptance bounds enforced by `tests/SparkEconomy.spec.luau`

Rank 2 after the first round for every archetype; second arena within 30 min; rank 50 ≥ 15 h for everyone and 25–80 h for regulars; skill speeds progress but experts are never more than 3× faster than novices; novices max upgrades in 15 min–2 h; regular rank 10 in 0.4–3 h and rank 15 in 1–5 h; Radiant album ≥ 1.5 h; Gilded set ≥ 3 h; cosmetic sink ≥ 3 h; novice median Bronze–Silver; regular median Silver–Gold; experts reach Radiant; novices never reach Heat 5.
