# SPARK STAMPEDE — owner Studio install and supervised playtest guide

For the owner (or a supervised local agent session). Written 2026-11-04 for the cloud-built mastery/progression build. **Everything here needs local Roblox Studio; nothing below has been run in Studio yet.** Follow `AGENTS.md`: no unattended play sessions, no public publish, no monetization.

## 0. Before you start

1. Make sure the cloud branch reached GitHub (`claude/awesome-brown-27rwqo`). If GitHub still shows only `main`, the cloud push was blocked (403); see `RUN_STATE.json`.
2. `git fetch origin && git checkout claude/awesome-brown-27rwqo`
3. Keep the protected backup untouched: `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl`. Save a fresh copy of the current dev place (File → Save to File As…) before installing.
4. Optional local checks (Windows): install official Luau 0.744 into `.tools/luau/` then run `python tools/run_checks.py` (or `tools/run_checks.ps1`). The cloud run passed 44/44 (`docs/qa/latest-checks.json`).

## 1. Install the build (Edit mode only)

1. `python tools/build_studio_install.py` → `build/install-spark.luau` and `build/spark-manifest.json` (now 19 scripts: new modules `Loadout`, `Encounters`, `Progression`, `Services`, and client `Ui`, `Effects`, `Menu`).
2. Open Project Cascade [DEV] (place 127090454461830) in **Edit** mode. Paste the installer into the Command Bar (or run it via Studio MCP `run_code`). It preflights, writes, reads back every source and rolls back on any failure.
3. Expected: all manifest entries report matching SHA256. If anything fails, the installer restores the previous sources; do not hand-edit scripts in Studio (Git is the source of truth).

Alternative (unverified): Rojo users can serve `default.project.json`.

## 2. Solo checklist (one client, ~15 minutes)

Record times from the Output `[SparkMetric]` lines and take screenshots of each tab.

| # | Do | Expect |
| --- | --- | --- |
| 1 | Press Play (Studio uses memory saves, not production). | HUD, three starters in front of you, objective "CATCH your first Sparks". No red errors in Output. |
| 2 | Catch the 3 starters (E / tap CATCH), walk to the BANK ring. | First bank ≤ 20 s from spawn is the target; glow rises; FIRST CATCH cue disappears. |
| 3 | Keep playing the round. Press **Shift** to dash straight through a group of sparks. | Floating tags (DASH, MULTI x2), combo meter climbs (x2 from a 6-chain). |
| 4 | After ~25 s look for a purple **Static Puff** drifting toward you. Dash through one, then let one touch you. | POP +40 and chain refresh; touching it → ZAP, 1–2 carried sparks scatter nearby and can be recaught. |
| 5 | Pop Meadow, when the HUD event line counts down to **SPARK GATE** (once per round): banner and ring. Chase sparks so they flee through it. | HERDED tag, spark joins your parade. Judge difficulty: is it too hard/easy? |
| 6 | Last 25 s: **GOLDEN SPARK** banner. Catch it. | GOLDEN tag, +250 style. Album later shows a Gilded mark. |
| 7 | Keep sparks carried into the last 15 s without banking. | Warm timer + "BUZZER SOON"; at 0 the style bonus is forfeited (results show "buzzer"). |
| 8 | Results screen. | Medal, breakdown, XP bar, rank-up to rank 2, perk unlock callout. "Chase Again" restarts immediately. |
| 9 | Menu → Play: equip two perks, try Heat (locked until a Silver). Menu → Goals: claim a daily goal if complete. Style: buy Sunbeam (300 glow) when affordable. Records: per-heat bests. | Server accepts/refuses with clear messages; perks/heat cannot change mid-round. |
| 10 | Travel to Fizz Canyon after 30 banked. Wait for the **STAMPEDE RUN** countdown (twice per round). | Lane arrows, six fast sparks cross the painted lane; dash through for multi-catches. |
| 11 | Settings: Reduced motion ON. | No floating tag motion, no golden sparkle/glow, no bobbing parade; colour grade switches instantly. |
| 12 | Sounds. | Built-in placeholder sounds play (catch/dash/bank/zap). If any path is missing, Output shows a load warning: note it (issue SS-27). |

## 3. Two/four-client checklist (Studio Test → Clients and Servers)

Use 2 then 4 clients. Watch for duplicate catches, wrong rewards, and errors.

- Two players dash at the same spark: only one gets it.
- Gate flank: one player chases a spark toward the gate, the other pushes it through → HERDED for one, ASSIST for the other.
- Golden contest: whoever catches it gets GOLDEN; others see "X caught a GOLDEN SPARK!".
- Zap scramble: scattered sparks can be caught by the other player.
- Herd density: with 4 players the arena should feel busier (+15 sparks), not starved.
- One player leaves mid-round, rejoins: progress restored, no stuck round for others.
- Close the session normally (Stop). Confirm Studio returns to Edit mode and no Studio process keeps running.

## 4. What to report back

Times to first action/catch/bank/round; anything confusing in the first minute; whether dash-through feels reliable (path radius 4.5 studs may need tuning for latency); static readability; gate difficulty; golden finale excitement; results clarity; menu readability on a phone-sized window; any Output errors (copy them); frame rate in the busiest moment. File results in `docs/qa/<date>/` and update `docs/GAME1_ISSUES.md`.
