# Game #1 — durable production log

Updated 2026-10-27 PDT. **STUDIO RECONNECTED; RECOVERY REHEARSED; SOLO QUEST/UPGRADE/REPLAY VERIFIED; DASH MOVEMENT FIX ENGINE-RETESTED. Not a release candidate.**

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
- 7b0cf69: fallen-player rescue, starter targets near spawn, public QA attributes. da87ae0: stable GUI paths, M menu key, player-list overlap prevention. Included in the current installed build; rescue still awaits an engine test.

## Latest completed implementation batch — 2026-10-26/27

- f1bc3f5: pending loads and detached departure saves remain tracked through shutdown; late loads release their leases; closing stops new progression. Save status acknowledges only the persisted revision, so an older write cannot mark newer rewards Saved. Eleven extracted-production-helper tests pass; actual engine shutdown/DataStore latency remains unverified.
- 3e8b28a: mobile action buttons avoid reserved thumbstick/jump areas; narrow titles/tabs scale; gamepad menus/results receive focus and restore selection after refresh. Eleven canvas-size cases pass geometric checks, not rendering or actual touch/gamepad interaction. See GAME1_CLIENT_QA.md.
- 4bf1556 and subsequent installer hardening: complete preflight before source writes, duplicate/class/sync/stale-source checks, readback, Edit-mode rechecks, transactional source/attribute/parent/enabled restoration on failure. Forty-five mocked assertions pass, including deliberate rollback failure reporting. A partial-source-write rollback has now also been rehearsed in a reopened local Studio backup; details below.
- tools/run_checks.ps1 now includes compilation, all Spark Luau suites, production lifecycle harness, world/layout mock smoke and audio checks, with timestamp/HEAD/dirty/source hashes/exit codes. Final run at 2026-10-27 05:22:53–05:23:35UTC passed all19 checks (0failed); intentional child failure returned exit1 and was correctly recorded as failed. No tested source changed during the run. See docs/qa/latest-checks.json for exact commands, hashes and outputs.
- b191aa8 and 862e91a: reject expired lease acknowledgments after delayed DataStore responses; Main gates progression on the last acknowledged absolute lease deadline. Seventeen persistence tests and twelve lifecycle helper tests pass. Real platform latency/takeover remains unverified.
- e0e90a2: finite owner-only first catches, no replay refill, and ordinary herd clearance from the bank prevent stationary starter farming. Rules suite expanded to 2,045 assertions. Current solo input evidence supports the limited camping case below; multiplayer ownership and overlapping starter visuals still need live review.
- 45144f8: client visibility hides other players' private starter creatures; eleven assertions with event doubles pass. Not installed in the current live 862e91a session, and not yet multiplayer-rendered.
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
- **New live dash defect:** accepted Shift feedback produced no meaningful character movement. A five-second client sample contained 69 observations with z min=max=38 and maximum speed approximately 0.0000065254. Earlier dash feedback alone did not prove displacement. Fix and engine retest are in progress; current dash movement fails acceptance.
- Follow-up live build: 45144f8 plus uncommitted Main planar LinearVelocity dash fix, all eight source readbacks matched. Actual Shift input moved the character from z 38 to 27.259985, with peak speed 65.8760 across 61 inspected samples; two samples observed the actuator. Subsequent E/S capture/bank awarded 4 glow / one catch, and server inspection found no remaining SparkDashVelocity or attachment. Inspected console reported no game errors. This closes the reproduced zero-displacement case; high-latency, collision, multiplayer and repeated-dash lifecycle tests remain open. Exact hashes and scope are in the live report.
- Diagnostic-run first_action 13.070s / first_catch 30.772s / first_bank 33.758s include focus/instrumentation delays and are not a fresh-hook success sample. Actual 2/4-client, platform persistence, device/audio and ten-round engine tests remain outstanding.
- Explicit engine-script diagnostics on that follow-up build: replicated foreign-starter probe hid all 15 parts and one billboard in the real client; injected fall from y=-30 rescued to y=2.998046875 with health 100 and unchanged 4 glow / one banked catch; malformed/unearned request batch (including 100 first-haul requests) left progression unchanged, and subsequent actual E input reached 7 glow / two catches. Probes were removed. This is single-client script injection, not actual two-player or death/rejoin coverage; detailed inputs are in the live report.

## Gates and next work

| Gate | Status |
| --- | --- |
| G0 | Identity/archive/full local backup/mappings/two-way probe verified; local-copy partial-write rollback rehearsed; eight-source activation readback verified |
| G1 | Live captures/banking, 110s rounds, quest idempotence, boots debit, replay and repaired dash displacement observed; broader movement regression and independent comprehension pending |
| G2 | Broad implementation exists; audio binding, gameplay/art polish and complete live audit pending |
| G3 | Pure tests and additional solo interaction evidence; actual 2/4 clients, soak, device, security and engine persistence pending |
| G4 | NOT READY; no owner candidate playtest requested |
| G5 | NOT AUTHORIZED |

1. Commit and broaden regression coverage for the engine-verified dash fix; continue arena navigation/unlocks, fall/death recovery and invalid-remote tests. Re-list Studio and inspect current mode before actions. Do not assume a successful input tool response means the viewport received input.
2. Rerun the complete check runner for the latest committed sources; integrate staged client fixes through the same stop/build/install/readback workflow, then retest affected behavior.
3. Save a separate local candidate copy without overwriting the recovery backup. Use Studio Test Server/Clients for actual 2/4-client contention, ownership, late-join/disconnect and mixed-phase tests; MCP start_stop_play only exposes solo.
4. Bind original audio through supported free permitted workflow and audit playback/permissions. Create real marketing artifacts. No Robux/public publishing/monetization.
5. Fix observed weaknesses, measure performance and run10 genuine rounds; append evidence and update release checklist.

## Continuation

Desktop heartbeat continue-spark-stampede-production is ACTIVE every4 hours in this chat, notifying only meaningful changes. Local work requires awake host/app and reachable Studio. Some subagent turns hit account usage limits; commits survived. Scheduling is not unlimited compute. No credentials committed, Robux spent, monetization or public publication enabled.
