# SPARK STAMPEDE — owner Studio install and supervised playtest guide (v2)

For the owner, or a supervised local agent session the owner explicitly approves. Version 2 (2026-11-05) covers the **final production plan build** (Phases 1–8, offline-verified). **Nothing below has been run in Studio for this build.** Follow `AGENTS.md`: no unattended play sessions, no public publishing, no monetization, and no force-killing processes.

The V-numbers match the engine-validation table in `BACKLOG.md` (V1–V12).

## 0. Before you start (5 min)

1. Fetch the branch:
   ```bash
   git fetch origin
   ```
   ```bash
   git checkout claude/awesome-brown-27rwqo
   ```
   Then confirm the tip matches `RUN_STATE.json` → `push_status`.
2. Leave the protected backup untouched: `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl` (SHA256 `81596f78…eb572254`). Save a fresh copy of the dev place (File → Save to File As…) before installing.
3. Optional offline checks on Windows: put official Luau 0.744 in `.tools/luau/`, then run:
   ```bash
   python tools/run_checks.py
   ```
   The cloud run's result is in `docs/qa/latest-checks.json`.

## 1. Install the build (Edit mode only) — V1

1. Generate the installer:
   ```bash
   python tools/build_studio_install.py
   ```
   It writes `build/install-spark.luau` and `build/spark-manifest.json` (every `game/**` script, including the new `Cycle`, `HerdNet`, `Trial`, `Cosmetics`, `Remix`, `CreatureView` and `Podium`).
2. Open Project Cascade [DEV] (place 127090454461830) in **Edit** mode. Paste the installer into the Command Bar, or run it via Studio MCP `run_code`. It preflights, writes, reads back every source and rolls back on any failure.
3. Expected: every manifest entry reports a matching SHA256 and Output shows no red errors. Git is the source of truth, so do not hand-edit scripts in Studio.
4. **Audio (V7, optional at this stage).** Upload the 21 new WAVs from `assets/audio/` through the Asset Manager (steps in `docs/GAME1_AUDIO.md`), then fill in the IDs:
   ```bash
   python tools/set_audio_ids.py --dry-run ids.json
   ```
   Re-install after the IDs are set. Until then, built-in placeholder sounds play where they exist; the rest of the cues stay silent.

## 2. Solo checklist (one client, ~20 minutes)

Record times from Output `[SparkMetric]` lines. **F8** shows the Studio-only performance overlay; **H** toggles photo mode.

| # | Do | Expect | V |
| --- | --- | --- | --- |
| 1 | Press Play. | HUD, three starters in front of you, objective "CATCH your first Sparks". No red Output errors. | V1 |
| 2 | Catch the starters (E / tap CATCH) and walk to the BANK ring. | First bank in ≤ 20 s. A **dash practice line** of three slow sparks appears with the hint "DASH THROUGH THE LINE!". | V4 |
| 3 | Run at the line and press **Shift**. | Usually a MULTI x2/x3. Try ten deliberate lines; target ≥ 8 lines catching 2 or more. | **V2** |
| 4 | Watch the sparks for 30 s. | They move smoothly with no teleport stutter; they hop, flee, startle and blink. F8 herd traffic stays under 6 KB/s. | **V3** |
| 5 | Let the round end. | At the **shared buzzer**: "TIME!", results with **NEXT UP: …**, a podium of positive awards, a CLAIM button if a goal finished, and "NEXT STAMPEDE IN n". The next round starts by itself with 3-2-1 STAMPEDE! | V5 |
| 6 | Round 2. | A sweep appears (round-2 hint). Statics start only in round 3. | V4 |
| 7 | After round 2: Menu → Play → **DAILY STAMPEDE → START**. | Trial Grounds (x = 900), a 75 s solo run, 20 private sparks, the day's encounter, a golden at 50 s, statics from 15 s. Results show **RETRY** and **LEAVE**. RETRY restarts instantly; LEAVE returns you to the shared cycle. The Records tab and every arena board show today's top runs. | **V6** |
| 8 | Catch a Bunvolt with a dash, a Flutterwink up close and facing, herd a Cubloom through the gate, and catch a Pip Pop at x2. | The aim cue names each signature ("◆ DASH IT!" …) and SIGNATURE tags appear. The Album shows signature counts and stars at 10/25/50. | V4 |
| 9 | Bank 90 sparks, then travel to Aurora Arcade. At 53–80 s of the cycle… | **Aurora Starfall**: a violet ring with "STAR LANDING", then impact. Sparks inside spin, dazed for 3 s; catching one shows STARSTRUCK. The crystal pillars never trap you or the camera. | V4, V10 |
| 10 | Fizz Canyon. | Six rock pillars frame both Stampede Run lanes. A run passes cleanly between them. | V4 |
| 11 | Menu → Style. | Formations, Bank Bursts, Name Tags and Titles. Equip one; your parade follows the formation and banking plays your burst. | V4 |
| 12 | Settings. | Reduced motion removes floating tag motion, bursts, ambience and bobbing. Hold-to-catch works while the aim cue shows a target. UI scale, music/SFX volume, high contrast and podium opt-out all apply immediately. | V9 |
| 13 | Play tab. | A **THIS WEEK'S REMIX** card. The intermission event line names the remix. | — |

## 3. Two- and four-client checklist (Studio Test → Clients and Servers) — V5, V11

- Everyone in an arena shares one countdown, one buzzer and one podium. A player who joins mid-round gets a **partial** round with no records; one who joins with under 40 s left gets a **warm-up**.
- Two players dash at the same spark: only one catches it. Catching a spark another player was chasing gives them a teamwork **ASSIST**.
- Players never collide or block each other at the bank or gate.
- Two players start the Daily Stampede at the same time: identical layouts, neither sees the other's sparks, and their scores land on one board.
- SIT OUT during an intermission keeps you out of the next round; PLAY rejoins. Two idle rounds trigger Sit out automatically.
- One player leaves mid-round and rejoins: progress is restored and nobody else's round gets stuck.
- **V11 soak (supervised):** 4 clients for 20 cycles (about 40 min). Watch F8 instance counts; they should stay flat. Stop the session normally and confirm Studio returns to Edit mode. Never force-kill.

## 4. What to report back

- Times to first catch, first bank and first full round.
- Dash-through success rate (V2).
- Herd smoothness on a weak connection (V3).
- Whether the first 30 s feel exciting (V4).
- Starfall and Stampede Run readability.
- Whether the Daily Stampede plays the same for two players (V6).
- Audio balance after upload (V7).
- Phone-sized UI readability and gamepad navigation (V9).
- F8 numbers at the busiest moment of a four-player finale (V10).
- Any Output errors, copied verbatim.

File results in `docs/qa/<date>/` and update `docs/GAME1_ISSUES.md`. Real DataStore behaviour (V8) needs a private test universe; Studio uses memory saves.
