# SPARK STAMPEDE — final competitive assessment and RC readiness (2026-11-05)

**Status: offline release-candidate build. NOT release-ready.** All eight phases of `FINAL_PRODUCTION_PLAN.md` are implemented and pass the offline suite, including 13 headless fake-engine scenarios (`docs/qa/latest-checks.json`). No part of this build has run in real Roblox Studio. Feel, rendering, audio, real replication, real DataStores and device performance are **unverified** until the owner completes V1–V12 (`BACKLOG.md`, `docs/GAME1_PLAYTEST_GUIDE.md`). Public publishing and monetization remain unauthorized.

## The six questions

### 1. Why does it feel different while playing?
- **Catching is movement, not a menu click.** You dash *through* a line of sparks for MULTI catches, keep a 6-second chain alive for x2, x3 and x4 STAMPEDE, herd sparks through a moving gate, and time dashes into Stampede Runs.
- **Every species is its own small skill puzzle.** Signatures: dash the bolters, get close to the zigzaggers, herd the huddlers, keep rhythm for the wanderers. The aim cue tells you which.
- **The herd is alive.** Creatures are client-animated: hop, flee, startle, blink, spin when dazed. They are driven by compact 10 Hz server snapshots (D13), so 54+ sparks move smoothly without server model churn.
- **Each arena plays differently.** Meadow islands and the Spark Gate; canyon pillars framing Stampede Run lanes; Aurora crystals and the Starfall, where you read the telegraph and catch dazed sparks for STARSTRUCK.
- Evidence: `SparkDepth` (signatures, Starfall, obstacles), headless ScenarioK (136 checks: telegraph, impacts, dazed sparks hold still, STARSTRUCK catch), ScenarioA (herd packets).

### 2. What makes players want another round?
- **A 2-minute shared heartbeat.** Everyone in an arena starts together (3-2-1 STAMPEDE!), races a shared golden finale, hits the same buzzer and sees a podium of *positive* awards. The next round starts by itself 10 s later.
- **Immediate, visible improvement.** Personal-best splits, medals, combo tiers, rank XP after every finished round, and every rank-up grants something.
- **A named next goal.** The results screen says what is closest: "NEXT UP: Bank 2 more Bunvolt for PRISM" or "1 more Starwhirl DASH IT! catch for ★1". Finished goals are one CLAIM tap away (competitor comparison, `docs/research/competitor_comparison_2026-11-05.md`).

### 3. What can experienced players master?
- Route efficiency (multi-dash lines, bank timing against the buzzer), chain management to x4, gate herding, Stampede Run timing, and Starfall prediction.
- Static pops versus zaps, perk side-grades with real downsides, and Heat 0–5 personal difficulty (unlocked by Silver medals).
- 36 signature stars, 12 Gilded variants and Radiant tiers.
- **The Daily Stampede**: a seeded course with normalized rules that is identical for everyone that day. Instant retries, ghost splits against your best, and a fair daily board. Calibrated medals: novice Bronze, regular Silver, expert Gold, expert p90 Radiant (economy model).

### 4. Why does multiplayer add something memorable?
- One shared stampede, finale and buzzer, so there are shared moments rather than parallel solo play.
- **Contested-catch assists** turn "stealing" into teamwork. Gate flanking credits assists. Arena Rallies reward every contributor. Players never collide, so nobody can body-block the bank or gate.
- **Visible flex without power.** Parade formations, Bank Bursts that everyone sees, name tags and titles.
- **Kind competition.** The podium celebrates Top Parade, Longest Chain, Golden Catcher, Best Flanker and Static Buster, and never ranks anyone last. Opting out is one toggle. Solo is always complete.

### 5. What motivates returning tomorrow and next week?
- **Tomorrow:** a new Daily Stampede course and board (first finish +40 glow, +80 XP), two fresh play goals plus "Finish today's Daily Stampede" (one free reroll). The results screen reminds you while today's reward is unclaimed.
- **Next week:** a new **Weekly Remix** (Golden Rush, Big Herd, Rhythm Week, Stampede Season, Starfall Everywhere, Fizz Festival) with its own weekly goal slot.
- **Long tail:** rank 50 (≈31 h regular), all priced cosmetics (≈29 h regular), signature stars, the Gilded album and Heat medals.
- **No chores, timers or streaks.** Missing a day costs nothing. No pay-to-win, no gambling, no idle rewards (two idle rounds switch a player to Sit out).

### 6. What makes the presentation feel intentional and premium?
- **One coherent identity.** Luminous primitive art with per-arena palettes, haze and ambience; client-animated creatures; catch flight into the parade; bank fountain; chain aura; golden beacons; Starfall telegraph; round beats (3-2-1, STAMPEDE!, TIME!).
- **Original audio.** 15 new cues plus 3 arena music loops, each with a finale intensity layer, from a reproducible, verified generator. They are not yet uploaded or heard (V7).
- **Respect for the player.** Progressive menu tabs with "!" only when something is new; coaching hints shown once ever; reduced motion; hold-to-catch; UI scale; volume sliders; high contrast; photo mode.
- **Not yet proven.** Premium feel can only be judged in Studio (V4). This is the largest remaining risk.

## Verification evidence (offline)

| Area | Evidence |
| --- | --- |
| Full suite | `python3 tools/run_checks.py`: result, commit and environment in `docs/qa/latest-checks.json` |
| Lifecycle and saves | `test_spark_lifecycle.py`, `SparkPersistence`, `SparkProfile` (v1/v2→v3, refuses v4+), ScenarioF (production DataStore path, lease release) |
| 1 / 2 / 4 players | ScenarioC (solo), D (two players, contention), I (four joiners, synced cycles), J (two trial runners), L (four players × 20 cycles) |
| Daily fairness | `SparkTrial` (365 days of plans, 73,000 respawns, normalized stats, settlement), ScenarioJ (identical layouts per slot, board ordering, once-per-day reward) |
| Economy | `SparkEconomy` (34 pacing bounds), `docs/GAME1_ECONOMY.md` |
| Exploits and rate limits | ScenarioH (366 malformed + 500 flood requests including the new actions: no progression, cosmetic, trial or goal change), Rules/Services specs, exploit telemetry (ScenarioF) |
| Network and leaks | ScenarioL (4 players × 20 cycles, worst client): herd 3.5 KB/s, state 1.6 KB/tick without profile, total 9 KB/s; instances ≤ 3,821 (budget 4,500); herd ≤ 43/arena (budget 80); non-herd instances flat; scheduled threads flat |
| Contracts | `test_spark_client_api.py` (Roblox API dump), `test_spark_menu.py`, `test_spark_client_blocks.py`, ScenarioG (real client boots, runs a trial, LEAVE via its button) |
| World and layouts | ScenarioA/K (per-arena obstacle sets), `SparkDepth`/`SparkRemix` clearance tests |
| Build tooling | `studio-installer-build` check; `tools/generate_audio.py --verify` / `--reproduce` |

## What remains (honest blockers)

1. **Studio validation V1–V12 (owner, supervised).** Install readback, dash reliability, herd smoothness, the presentation bar, synced cycles with real clients, Daily Stampede parity, audio, real DataStores in a test universe, mobile and gamepad, device performance, a 4-client soak, and the owner RC playtest (G4).
2. **Audio upload** of the 21 generated WAVs (`tools/set_audio_ids.py`). Until then most new cues are silent.
3. **Media:** icon, thumbnails and trailer captured from the real game (shot list in `docs/GAME1_PACKAGING.md`).
4. **Platform items (owner):** experience questionnaire and maturity label, optional badges, a private 5–10 friend beta, and the G5 publish decision.
5. **Known design risks:** glow surplus after ≈29 h (post-launch earned sets); bot scores are superhuman, so medal calibration needs real data; the Daily Stampede course stays fixed only while `Config.Creatures`/`Encounters` change at a UTC day boundary.
