# Game #1 — durable production log

Updated 2026-11-04 (cloud production session, branch `claude/awesome-brown-27rwqo`). **OFFLINE ONLY (cloud container, no Studio). SCHEDULING PAUSED. UNATTENDED STUDIO TESTS DISABLED. Not a release candidate. Commits NOT pushed: GitHub returned 403 for both git and the connector (issue SS-23).**

## Final direction review — 2026-11-05

- Branch preserved: all 19 session commits pushed and verified on GitHub (`claude/awesome-brown-27rwqo`, tip `b5b78bc` before this review).
- Research (search-summary based; Roblox sites, chart trackers and Reddit not fetchable here): `research/direction_review_2026-11-05.md`. Key evidence: Roblox discovery now weights 28-day retention; Fisch shows a felt catch skill plus bestiary works; seeded dailies keep leaderboards fair; documented failures to avoid (pay-to-win, crowding, repetition, exploits, performance collapse, griefing loss, streak FOMO).
- Code audit findings: 32 of 49 rank-ups grant nothing; Aurora reuses Meadow's gate and all arenas share one layout; creatures move at 10 Hz with no animation; no music; all 7 tabs visible at minute one; new players meet hazards 20–25 s after their first bank; **AFK exploit** (`roundXp(0)=60`).
- Output: `FINAL_PRODUCTION_PLAN.md` (launch scope, inventory, 16 system specs with acceptance tests, first-session sequence, mastery curve, failure-mode table, engine-validation matrix V1–V12, phased implementation order with cut line), decisions D10–D27, restructured `BACKLOG.md`. No code changed in this review.

## Cloud production session — 2026-11-04

Scope: autonomous milestone work requested by the owner (mastery depth, long-term progression, presentation, QA). No Studio, desktop control, GPU work, publishing, monetization or account actions. Protected backup and Cascade archive untouched.

- **Merged** `wip/spark-interrupted-20261103` (biome arena events, PB split checkpoints) after review; completed its interrupted supervisor change (25 supervisor tests pass).
- **Design spec v2** (`GAME1_DESIGN_SPEC.md`): critique of v1, pillars, verbs, round arc, arena identities, progression, acceptance criteria A1–A12. Durable `PROJECT_CHARTER.md`, `BACKLOG.md`, `DECISIONS.md`, `RUN_STATE.json` at repo root. Market snapshot `research/market_research_2026-11-04.md` (search-summary based; chart sites blocked by network policy).
- **Mastery depth (server-authoritative):** dash-through multi-catch on the movement-validated dash path; x4 STAMPEDE chain tier (tiers every 5 catches); personal Static Puffs (pop with dash, zap otherwise); zaps/sweeps scatter carried sparks back into the arena (recatchable, no saved progress lost); Spark Gate herding with flank ASSIST (Meadow/Aurora); Stampede Run lanes (Canyon); golden finale (any species → Gilded collection); haul and finale bank bonuses; buzzer forfeits unbanked style; herd density scales with players; first-encounter coaching hints.
- **Choices and difficulty:** eight perk side-grades (each with upside and downside), 2–3 slots by rank; Heat 0–5 personal difficulty ladder unlocked by Silver medals; loadout/heat locked during a round.
- **Long-term progression:** rank 1–50 (sqrt-score XP), 25 achievements with titles, daily (3) and weekly (3) goals with no streaks, 21 earned/guaranteed-price trails, records per arena × heat, optional all-time/weekly leaderboards (OrderedDataStore; memory doubles in Studio), AnalyticsService funnel/economy events. Profile schema v2 with v1 migration.
- **Economy calibrated** by `tools/economy_model.luau` driving the real modules; first run showed runaway inflation (rank 50 in 3.5 h, upgrades maxed in 3 rounds). Rebalanced medals (300/1,000/2,500/5,000), XP curve, upgrade costs, trail prices; 22 pacing bounds in `tests/SparkEconomy.spec.luau`. Known post-14 h glow surplus documented (`GAME1_ECONOMY.md`).
- **Client overhaul:** combo meter, floating tags, encounter visuals, golden compass, results breakdown with XP/rank/unlocks, seven-tab menu (Play/Goals/Album/Upgrades/Style/Records/Settings), per-arena colour grade, unverified built-in placeholder SFX.
- **World:** canyon lane landmarks, records boards; creature/static parts welded to one anchored root (≈20× fewer replicated CFrames, to be confirmed in Studio).
- **QA tooling:** `tools/run_checks.py` (portable fail-closed runner), `tools/lint_luau.py` (official luau-analyze undefined-global gate + module-member check), `tools/check_api_names.py` and a headless fake-Roblox engine (`tests/engine`, `docs/qa/HEADLESS_ENGINE.md`) that boots the real server and client scripts with API-dump validation. It found and we fixed: rejoin inheriting herding credit, scattered sparks never expiring, Replay swallowed by the shared rate limiter. The economy model and runner also caught balance-test drift and a NaN analytics guard.
- **Evidence:** `python3 tools/run_checks.py` → **44/44 passed**, sources unchanged during run (`qa/latest-checks.json`, Linux, Luau 0.744). Includes 9/9 headless scenarios (boot, onboarding, full round, 4-player contention/leave/rejoin, 10-round soak with flat instance counts, production DataStore path with injected failures, client boot, remote abuse). **None of this is Studio, physics, rendering, audio, device or human evidence.**
- **Next:** owner fixes GitHub write access; then follow `GAME1_PLAYTEST_GUIDE.md` (install, solo, 2/4 clients) and report; tune dash path radius, gate difficulty and static readability from real play.

## Previous state (2026-10-29)

Updated 2026-10-29 PDT. **OFFLINE ONLY. SCHEDULING PAUSED. UNATTENDED STUDIO TESTS DISABLED. New mastery gameplay is staged, not activated. Not a release candidate.**

## Latest manual offline batch — October 28–29 PDT

- Reviewed commits 0d178b2, 7ad1bca and 0f65326, complete AGENTS/charter/progress and incident report. Three independent agents audited transactions, added mastery progression, and hardened cleanup. No Studio MCP call, desktop control, graphical simulation or GPU workload was used. The protected backup hash and Cascade archive SHA match recorded values; last installed playable source remains befffcf.
- Fixed two integration defects: stale Playing state accepted actions past the exact 110-second deadline; a late first bank could enable an already-active sweep without warning. Actions now check the deadline directly; settlement precedes movement/hazards. Hazard eligibility starts a fresh grace/warning timeline. Settlement banks/records once, with persistent round receipts preventing duplicate mastery counters.
- Added Arena Rally: six ordinary Sparks banked at the gate in a 45-second arena window, solo or together. Each still-active contributor earns eight glow once at completion; no personal-skill inflation, starter/automatic-bank credit or repeat payout. Disconnect retains team progress but removes award eligibility. Arenas have independent windows. Values remain balance hypotheses, not measured fun.
- Added one bounded advisory catch outline/label using the server's pure targeting geometry and stable tie-breaking. Precision has shape/text cues, no extra flashing. A chain countdown clarifies six-second timing. Rally status and five finite skill milestone quests are integrated into menus/HUD. Persistent precision/dash counters, chain/challenge goals and per-arena medals extend mastery progression without resetting collection.
- Offline QA: **28 checks passed**, zero failed; 11 game scripts plus installer compile, exact Main-function integration **16 cases** (engine objects mocked), targeting/rally **8,461 assertions**, progression **265**, existing suites, and supervisor **19 tests**. [Commands, timestamps, environment and source hashes](qa/latest-checks.json). Installer generated locally only. Runner failure propagation was already verified in the previous batch and was not redundantly rerun.
- Supervisor milestone **87bdfb2** fixes telemetry/log-write cleanup bypasses, validates identity at observation and stop, propagates launcher deadlines, and reports startup/report failures. Live entry remains hard-disabled. MCP delivery, real OS identity binding, GPU sampling, multiplayer ownership, hung-Studio containment and total-storage-failure/readiness safeguards remain unverified. [Requirement matrix](GAME1_TEST_SUPERVISOR.md).
- Scheduling initially read PAUSED. After queued heartbeats arrived, configuration read ACTIVE on October 29; evidence does not establish who or what changed it. Restored PAUSED through the supported automation tool under the owner's standing instruction, preserving the restrictive prompt and schedule fields. Tool response confirmed PAUSED; no resumption is authorized.
- Remaining engine work: render/occlusion/mobile readability, input/physics/latency, hazard feel, actual 1/2/4-client rally/contention, platform persistence, audio binding/playback and device performance. G3/G4 remain open. This is an integrated offline candidate, not a release candidate or live cleanup certification.

## Owner correction and current work — takes precedence over historical testing notes

- Owner reported the abandoned simulation consumed resources for hours, Studio hung, and they force-closed it. The transcript has an unclosed local server/three-client session followed by a usage-limit error, with no independent cleanup. Local server logs span 23:57:31Z boot to a 01:58:28Z hang report. A graphics warning does not prove the cause of later display instability. [Incident audit](GAME1_WORKFLOW_CORRECTION.md).
- No foreground Computer Use, window focus, physical input, Studio launch/play or GPU-heavy work in this corrective session. Native MCP inventory/state reads found the intended place in **Edit**, instance f45da579-dc54-4292-b9ff-9cfe9a3c8aa2. No new activation. Do not use earlier Studio IDs without rechecking.
- Owner's protected evening backup rehashed unchanged: 81596f787935f27ca2edf661f5eed4486dac2a71ba559b19f16ef916eb572254, 136090 bytes. Never overwrite/move/delete it. Cascade archive is intact. Branch codex/playable-before-workflow-correction-20261027 preserves befffcf, the last installed source milestone.
- 0d178b2 commits the operating rules and audit, preserving pending historical reports/screenshots. 7ad1bca adds an independent cleanup-only worker and ten offline fault tests, including launcher exit/termination, timeout, identity mismatch, resource ceilings and stop verification. **Live mode is hard-disabled.** Real MCP/PID binding, GPU monitoring and hung-engine containment are not proven; this is not authorization for unattended tests. [Supervisor limits](GAME1_TEST_SUPERVISOR.md).
- New staged gameplay: server-owned precision/dash timing score, six-second chains with x3 cap, recoverable misses, rotating challenges, bronze/silver/gold results, persistent personal/per-arena bests, opt-in session scores, and a telegraphed infield sweep. Saved collection/glow are unaffected by mistakes. UI explains the loop; all code remains offline. [Mastery design](GAME1_MASTERY.md).
- Offline evidence: **24 checks passed, zero failed**, 2026-10-28 15:12:48–15:13:04 UTC, tested dirty 7ad1bca snapshot with exact source hashes and no source changes during the run. Includes Challenge 3970 assertions, mastery/profile/hazard integration 2246 assertions and supervisor ten tests. The deliberate runner failure returned exit 1 as expected. [Exact report](qa/latest-checks.json). No new live gameplay, audio, mobile, actual DataStore or device-performance result is claimed.
- The owner-paused automation was confirmed PAUSED and its stale prompt replaced with explicit offline-only/no-launch/no-desktop restrictions. Queued heartbeats do not authorize resumption. Only the owner can authorize scheduling again.

### Prior multiplayer batch, now accurately recorded

Build befffcf was installed with eight readbacks (Main f912bb57c605d70e205e79a41deda9de01bb5bf540a2182b0bcee5bd85a6f897). Local server a018c177-8cbf-4aba-a313-8c575991029b hosted Player1/Player2 plus a later Player3. The first two independently caught/banked one Bunvolt through real MCP E input (4 glow each), and each hid the other's private starters. Mixed Playing/Results phases and replay were observed. A scripted chase captured six distinct normal creature IDs for Player1; Player2's round ended during that diagnostic, so it did not prove same-target contention. The third client joined, but no four-client test completed. Normal shutdown was NOT verified. These partial results do not close G3 and must not be repeated unattended.

## Recovery and source

- Initial tree clean; main safely fast-forwarded from bcaabc6 to origin/main 6e8c535. Safety branch codex/safety-before-spark-sync-20261025 retained.
- Local and remote archive archive/cascade-pre-game1-pivot-20261024 remain bcaabc660d98619716cd51fbc99bd38c053635f2. Never rewrite them.
- Four live Cascade scripts exported verbatim into backups/cascade-studio-20261025/ with path/class/RunContext manifest. Original source remains in src/. In the tested Studio session, legacy scripts were disabled and Baseplate/SpawnLocation/hello script moved into ServerStorage.CascadeRecovery, not destroyed.
- Verified development place 127090454461830, universe 10769277416, title Project Cascade [DEV]. Initial Studio ID ec0f5394-bf5e-44ef-8784-457cf593fa2b; re-list each session.
- All three Cascade Script Sync roots positively mapped to absolute repository paths. Disposable ModuleScript synced Studio→disk then disk→Studio; cleanup propagated. See GAME1_STUDIO_WORKFLOW.md.
- **Git game/ is Spark's source of truth.** Run python tools/build_studio_install.py for compiled explicit Edit-mode installer and hash manifest in ignored build/. Spark is deliberately not Script Synced. All eight initial deployed scripts read back matching repository source exactly. No public publish performed.

## Implemented milestones

- 73ff312: 12 creatures, 3 biomes, 3 upgrades, quests, deterministic earned mutations, sanitized profiles, retry/session-lease persistence.
- 4a5c616: current top-earning mirror and Sep/Oct sampled concurrency research; release gates; draft store copy/storyboard. Revenue not inferred from concurrency.
- 0ae6852: six original synthesized WAVs, generator/provenance/hashes. **IDs blank: authored soundtrack not audible in game yet.**
- e39c3e6: three themed procedural arenas, twelve silhouettes, reproducible mock constructor smoke.
- 0321166 / 6fd5a1d: authoritative captures/banking, 110s rounds, shared events, herd behavior/obstacle avoidance, movement validation, serialized final saves, responsive HUD/menu/controls/parades/settings.
- bd23b31: live backup, installer/workflow, pure 1/2/4-contender simulation.
- 7b0cf69/da87ae0: rescue, starter placement, QA attributes and stable UI paths. The later bounded injected-fall test below verified one rescue case, not death/rejoin coverage.

## Latest completed implementation batch — 2026-10-26/27

- f1bc3f5: pending loads and detached departure saves remain tracked through shutdown; late loads release their leases; closing stops new progression. Save status acknowledges only the persisted revision, so an older write cannot mark newer rewards Saved. Eleven extracted-production-helper tests pass; actual engine shutdown/DataStore latency remains unverified.
- 3e8b28a: mobile action buttons avoid reserved thumbstick/jump areas; narrow titles/tabs scale; gamepad menus/results receive focus and restore selection after refresh. Eleven canvas-size cases pass geometric checks, not rendering or actual touch/gamepad interaction. See GAME1_CLIENT_QA.md.
- 4bf1556 and subsequent installer hardening: complete preflight before source writes, duplicate/class/sync/stale-source checks, readback, Edit-mode rechecks, transactional source/attribute/parent/enabled restoration on failure. Forty-five mocked assertions pass, including deliberate rollback failure reporting. A partial-source-write rollback has now also been rehearsed in a reopened local Studio backup; details below.
- tools/run_checks.ps1 now includes compilation, all Spark Luau suites, production lifecycle harness, world/layout mock smoke and audio checks, with timestamp/HEAD/dirty/source hashes/exit codes. Final run at 2026-10-27 05:22:53–05:23:35UTC passed all19 checks (0failed); intentional child failure returned exit1 and was correctly recorded as failed. No tested source changed during the run. See docs/qa/latest-checks.json for exact commands, hashes and outputs.
- b191aa8 and 862e91a: reject expired lease acknowledgments after delayed DataStore responses; Main gates progression on the last acknowledged absolute lease deadline. Seventeen persistence tests and twelve lifecycle helper tests pass. Real platform latency/takeover remains unverified.
- e0e90a2: finite owner-only first catches, no replay refill, and ordinary herd clearance from the bank prevent stationary starter farming. Rules suite expanded to 2,045 assertions. Current solo input evidence supports the limited camping case below; multiplayer ownership and overlapping starter visuals still need live review.
- 45144f8: client visibility hides other players' private starter creatures; eleven event-double assertions and later two-client visibility checks passed. See current correction notes for the incomplete multiplayer batch.
- Latest complete runner: **20 checks passed**, zero failures, 2026-10-27T23:53:27.7074851Z–23:53:32.0634716Z. Report records dirty HEAD 862e91a with client visibility changes, exact source hashes and no source changes during the run; intentional child failure returned exit 1 as expected. This is the tested snapshot subsequently committed as the visibility milestone, not a claim that later dash edits passed.
- Durable issue ledger: docs/GAME1_ISSUES.md. Offline fixes are not marked engine-verified closure.

### Studio recovery and latest source activation

On October26, opened Project Cascade [DEV] in Studio a9042237-c870-4f83-ab86-16e43de5712d and verified place127090454461830/universe10769277416. Initial Spark sources were still present; newer patches were not installed. The local Download a Copy dialog became unresponsive while naming pre-refresh-place-20261026.rbxl. The target file does not exist; **no full-place backup success is claimed**. Escape timed out, process64196 reported Responding=False, and a read-only MCP state query remained stalled and was canceled. No forced process termination or public save/publish was performed.

At 2026-10-27 05:22UTC MCP returned an empty studios array. That temporary blocker is superseded by the following verified recovery; the failed filename above must not be confused with the successful evening backup.

- Full local backup `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl` exists: 136,090 bytes, SHA256 `81596f787935f27ca2edf661f5eed4486dac2a71ba559b19f16ef916eb572254`. Its filesystem last-write time is 2026-10-27T05:46:23.8077187Z. Metadata is committed in `backups/cascade-studio-20261025/full-place-backup.json`.
- Reopened that file in Studio `9198099a-cc34-49ee-b49a-5a1b27082b61` as a local PlaceId/UniverseId 0 copy. Injecting a table into the installer's final Source assignment produced `ProtectedString expected, got table; rollback failures=0`. All twelve saved source snapshots, SourceSHA attributes and BaseScript enabled states matched after rollback. Closed without saving; backup hash unchanged. This proves the tested partial-write failure path, not process-crash recovery or every rollback failure mode.
- Current development instance `4273c080-67ba-410b-ad51-3522335b16b1` is Project Cascade [DEV], PlaceId 127090454461830 / UniverseId 10769277416. Reverified all three absolute Cascade sync roots, then a disposable `SparkSyncProbe` passed Studio→disk and disk→Studio exact-string checks and deletion cleanup. No System32 mapping observed.
- Generated and installed commit **862e91a**, then read back all eight Spark sources matching repository source with normalized line endings. Git `game/` remains the single source of truth. No public publish or production DataStore writes performed.
- Detailed actions, constraints and screenshots: [October 27 live report](qa/2026-10-27/live-studio.md).

## Tests actually performed

Official Luau 0.744 under ignored .tools/luau. Reproducible commands:

```
.tools/luau/luau.exe tests/SparkProfile.spec.luau
.tools/luau/luau.exe tests/SparkPersistence.spec.luau
.tools/luau/luau.exe tests/SparkRules.spec.luau
.tools/luau/luau.exe tests/SparkSessionSimulation.spec.luau
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SparkWorldSmoke.ps1
python tools/generate_audio.py --verify
python tools/build_studio_install.py
```

- Profile8 tests; latest focused Persistence17 tests, Rules2,045 assertions and Lifecycle12 tests passed. Pure failure injection, sanitization, lease exclusion and duplicate protection covered; see commit-specific scope above.
- Pure 1/2/4-contender simulation: 12,456 assertions, 70 player-rounds, 1,680 unique captures passed. **Not separate Studio clients or Main engine orchestration.** See docs/qa/SparkSessionSimulation.md.
- Mock construction: 609 instances / 565 Parts / 123 colliders for world; 206 Parts for one of each species; 27 yields. **Not rendering/performance evidence.**
- Six audio format/peak/DC/edge/hash checks pass; 3,218,682 bytes. **No audible QA/platform playback yet.**
- Eight production scripts compile; initial deployed source readback matched. Compilation is not runtime proof.

### Actual solo Studio run — 2026-10-25

Studio0.744, verified place, build bd23b31 (Main0321166, Client6fd5a1d), isolated memory persistence, no production DataStore writes.

- MCP Play exposed Client/Server. HUD, three arenas, 54 moving creatures booted. Inspected client/server console contained no reported game errors in this run.
- Actual MCP W/E and character_navigation: Bunvolt caught/carried, return to bank awarded exactly4 glow, dash feedback observed. Album opened with real pointer input and showed1/12 discovered, Bunvolt1 banked.
- Observed log after join: first_action11.091s; first_catch20.456s; first_bank38.853s; first_round110.184s. **Action10s/reward20s gates were missed in this first test**, which included tool-inspection delays. Starter placement then tightened; retest pending.
- Rendered album screenshot saved at docs/qa/2026-10-25/album.png; other inline screenshots inspected but not all saved.
- Instant MCP clicks/keyPress did not reliably activate UI. Explicit mouseButtonDown→150ms wait→mouseButtonUp→200ms wait successfully fired MouseButton1Click/Activated. Use stable GUI paths from da87ae0. Temporary QA instance renames/signals were play-only diagnostics.
- Quests tab click issued; claim/upgrade/replay not verified. No real multi-client/mobile/DataStore/audio/ten-round soak/physical-device performance tests yet.

### Actual solo Studio runs — October 27 continuation, build 862e91a

Two fresh solo sessions used isolated memory profiles. Inputs were actual MCP keyboard actions; menu transactions below used observed native UI clicks. Reported funnel times are telemetry elapsed from server join, not an independently measured visible-spawn or human-comprehension benchmark.

- Run 1: first_action 0.464s, first_catch 0.464s, first_bank 0.514s; first_round 110.009s. Reached two banked catches / 9 glow; ten additional stationary E pulses left both values unchanged. This bounded case supports the camping fix, not every exploit scenario. No game errors were reported in the inspected console window.
- Run 2: viewport focus delayed input; first_action 36.196s, first_catch 36.197s, first_bank 36.198s; first_round 110.046s. After focusing the game viewport, movement/capture pulses reached three banked catches, 12 glow, three discovered species and zero remaining starters. The delayed run is retained as a failed timing sample, not discarded as a pass.
- Native quest UI: first-haul claim changed 12→22 glow; repeated click left 22 unchanged. First-round claim changed 22→37. Native upgrade UI: boots purchase changed 37→17 glow and level 0→1; another unaffordable purchase attempt left 17 / level 1 unchanged. Screenshots: [quests](qa/2026-10-27/quests-claimed.png), [boots](qa/2026-10-27/boots-upgrade.png).
- Actual native Chase Again click hid Results and started Playing with timer 1:48; 17 glow, three species, three banked, zero starters and one completed round were retained. Client state confirmed boots level 1, dash cooldown 2.65 and both quests claimed. The replay did not refill starter allowance. First-upgrade/replay telemetry at 28,167.895s / 28,212.321s reflects a long interrupted idle session, not first-session pacing.
- **Historical dash defect:** accepted Shift feedback produced no meaningful movement (69 observations, z min=max=38). The subsequent planar-actuator test below demonstrated displacement; befffcf committed that fix and cleanup on correction/teleport. Broader regression is pending.
- Follow-up live build: 45144f8 plus uncommitted Main planar LinearVelocity dash fix, all eight source readbacks matched. Actual Shift input moved the character from z 38 to 27.259985, with peak speed 65.8760 across 61 inspected samples; two samples observed the actuator. Subsequent E/S capture/bank awarded 4 glow / one catch, and server inspection found no remaining SparkDashVelocity or attachment. Inspected console reported no game errors. This closes the reproduced zero-displacement case; high-latency, collision, multiplayer and repeated-dash lifecycle tests remain open. Exact hashes and scope are in the live report.
- Diagnostic-run first_action 13.070s / first_catch 30.772s / first_bank 33.758s include focus/instrumentation delays and are not a fresh-hook success sample. Actual 2/4-client, platform persistence, device/audio and ten-round engine tests remain outstanding.
- Explicit engine-script diagnostics on that follow-up build: replicated foreign-starter probe hid all 15 parts and one billboard in the real client; injected fall from y=-30 rescued to y=2.998046875 with health 100 and unchanged 4 glow / one banked catch; malformed/unearned request batch (including 100 first-haul requests) left progression unchanged, and subsequent actual E input reached 7 glow / two catches. Probes were removed. This is single-client script injection, not actual two-player or death/rejoin coverage; detailed inputs are in the live report.

## Gates and next work

| Gate | Status |
| --- | --- |
| G0 | Identity/archive/full local backup/mappings/two-way probe verified; local-copy partial-write rollback rehearsed; eight-source activation readback verified |
| G1 | Live captures/banking, 110s rounds, quest idempotence, boots debit, replay and repaired dash displacement observed; broader movement regression and independent comprehension pending |
| G2 | Broad implementation exists; audio binding, gameplay/art polish and complete live audit pending |
| G3 | Offline suites and partial solo/two-client evidence; four clients, contention, cleanup, soak, device and engine persistence incomplete. Live testing disabled |
| G4 | NOT READY; no owner candidate playtest requested |
| G5 | NOT AUTHORIZED |

1. Continue offline game development and integration tests: creature variety, arena-specific challenges, animation/readability, co-op scoring and progression balance.
2. Keep engine tests and new source activation queued. No GUI launch or play mode during the initial correction. Independent cleanup prototype is not live certification.
3. Future owner-approved supervised test must first prove exact process ownership, independent normal stop, stopped-state verification and resource monitoring. Keep unattended use disabled if hang cleanup cannot be made safe.
4. Prepare original audio bindings and packaging offline; audible/mobile/performance/soak tests remain pending. No publication, account changes, Robux or monetization.

## Continuation

Desktop heartbeat continue-spark-stampede-production is **PAUSED BY OWNER**. Confirmed and retained paused; prompt now prohibits queued launches or desktop control. No automatic resumption. Manual offline work may continue under the corrected rules. Subagent usage limits interrupted this correction too; root completed the supervisor prototype and gameplay integration without launching Studio. No credentials, Robux spending, monetization or public publishing.
