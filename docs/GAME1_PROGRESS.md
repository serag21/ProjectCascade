# Game #1 — durable production log

Updated 2026-10-26 PDT / 2026-10-27 UTC. **INTEGRATED BUILD + SAVE/INSTALL/UI HARDENING; LIVE QA BLOCKED BY STUDIO AVAILABILITY. Not a release candidate.**

## Recovery and source

- Initial tree clean; main safely fast-forwarded from bcaabc6 to origin/main 6e8c535. Safety branch codex/safety-before-spark-sync-20261025 retained.
- Remote archive archive/cascade-pre-game1-pivot-20261024 remains bcaabc660d98619716cd51fbc99bd38c053635f2. Never rewrite it.
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
- 7b0cf69: fallen-player rescue, starter targets near spawn, public QA attributes. da87ae0: stable GUI paths, M menu key, player-list overlap prevention. **These last two revisions are not yet live-tested at this checkpoint.**

## Latest completed implementation batch — 2026-10-26/27

- f1bc3f5: pending loads and detached departure saves remain tracked through shutdown; late loads release their leases; closing stops new progression. Save status acknowledges only the persisted revision, so an older write cannot mark newer rewards Saved. Eleven extracted-production-helper tests pass; actual engine shutdown/DataStore latency remains unverified.
- 3e8b28a: mobile action buttons avoid reserved thumbstick/jump areas; narrow titles/tabs scale; gamepad menus/results receive focus and restore selection after refresh. Eleven canvas-size cases pass geometric checks, not rendering or actual touch/gamepad interaction. See GAME1_CLIENT_QA.md.
- 4bf1556 and subsequent installer hardening: complete preflight before source writes, duplicate/class/sync/stale-source checks, readback, Edit-mode rechecks, transactional source/attribute/parent/enabled restoration on failure. Forty-five mocked assertions pass, including deliberate rollback failure reporting. Real Studio rollback rehearsal remains pending.
- tools/run_checks.ps1 now includes compilation, all Spark Luau suites, production lifecycle harness, world/layout mock smoke and audio checks, with timestamp/HEAD/dirty/source hashes/exit codes. Final run at 2026-10-27 05:22:53–05:23:35UTC passed all19 checks (0failed); intentional child failure returned exit1 and was correctly recorded as failed. No tested source changed during the run. See docs/qa/latest-checks.json for exact commands, hashes and outputs.
- Durable issue ledger: docs/GAME1_ISSUES.md. Offline fixes are not marked engine-verified closure.

### Studio availability and backup attempt

On October26, opened Project Cascade [DEV] in Studio a9042237-c870-4f83-ab86-16e43de5712d and verified place127090454461830/universe10769277416. Initial Spark sources were still present; newer patches were not installed. The local Download a Copy dialog became unresponsive while naming pre-refresh-place-20261026.rbxl. The target file does not exist; **no full-place backup success is claimed**. Escape timed out, process64196 reported Responding=False, and a read-only MCP state query remained stalled and was canceled. No forced process termination or public save/publish was performed.

On 2026-10-27 at the 05:22UTC continuation, MCP returned an empty studios array. No new live gameplay, multiplayer, audio or performance tests were run in this batch. Earlier script exports/archive remain preserved. Reconnect/re-list before touching Studio; pending build must not be assumed installed.

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

- Profile8 tests, Persistence11 tests, Rules111 assertions passed. Pure failure injection, sanitization, lease exclusion and duplicate protection covered.
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

## Gates and next work

| Gate | Status |
| --- | --- |
| G0 | Identity/archive/script backup/mappings/two-way probe verified; full local place backup and rollback rehearsal pending |
| G1 | Live chase/catch/bank/dash and first round observed; revised hook, replay, upgrade and independent comprehension tests pending |
| G2 | Broad implementation exists; audio binding, gameplay/art polish and complete live audit pending |
| G3 | Pure tests passed, initial solo run only;2/4 clients,soak,device,security,engine persistence pending |
| G4 | NOT READY; no owner candidate playtest requested |
| G5 | NOT AUTHORIZED |

1. Re-list Studio (latest inventory empty). Open/reconnect Project Cascade [DEV], verify identity, backup and absolute mappings; repeat disposable two-way probe. Save a full local copy and rehearse recovery before refreshing source. Never assume prior unsaved edits survived.
2. Build/install the latest committed source and read back every file. Include starter/rescue, lifecycle, mobile/controller and transactional-installer revisions. Test fresh catch timing, three-catch haul, quest idempotence, upgrade debit/effect,110s results, Replay, fall/death recovery and invalid remotes.
3. Safely save full local place/candidate and rehearse rollback. Studio Test Server/Clients UI needed for2/4 actual clients; MCP start_stop_play only exposes solo.
4. Bind original audio through supported free permitted workflow and audit playback/permissions. Create real marketing artifacts. No Robux/public publishing/monetization.
5. Fix observed weaknesses, measure performance and run10 genuine rounds; append evidence and update release checklist.

## Continuation

Desktop heartbeat continue-spark-stampede-production is ACTIVE every4 hours in this chat, notifying only meaningful changes. Local work requires awake host/app and reachable Studio. Some subagent turns hit account usage limits; commits survived. Scheduling is not unlimited compute. No credentials committed, Robux spent, monetization or public publication enabled.
