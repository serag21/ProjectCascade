# SPARK STAMPEDE — release checklist

Created 2026-10-25. **Release candidate: NO. Public publishing and monetization: NOT AUTHORIZED.**

## Operational gate added October 28 PDT

- [x] Foreground desktop control and unattended Studio launches prohibited in AGENTS; queued automation prompt corrected and kept PAUSED.
- [x] Owner's evening backup rehashed unchanged; prior playable source preserved on a recovery branch.
- [x] Independent cleanup worker tested offline, including launcher termination and bounded failure reports. Live entry point refuses execution.
- [ ] Exact Studio/process ownership, independent MCP stop and stopped-state verification proven in an explicitly approved engine test.
- [ ] GPU/CPU/resource containment and hung-engine cleanup proven without touching unrelated apps.
- [ ] Owner authorizes any future scheduling resumption. **Until then: offline only, no unattended play.**

New mastery/score/sweep, rally, target preview and skill milestone code is staged offline and has not been activated. Twenty-eight offline checks include 16 production transaction cases and 19 cleanup fixture tests; none certify live operation. Earlier checkmarks do not establish quality of these new mechanics. See [incident audit](GAME1_WORKFLOW_CORRECTION.md) and [mastery scope](GAME1_MASTERY.md).

This is a gate ledger, not a test report. An unchecked item is not passed. Implementation, static inspection, pure-module tests, scripted engine tests, real client interaction and human usability feedback are different evidence classes. When checking an item, link the dated report/artifact and exact commit. See `GAME1_PROGRESS.md` for the latest production state; this document initially records requirements without claiming tests that another agent may be running.

## G0 — recoverable source and Studio

- [x] Local modifications preserved; `origin/main` synchronized without discarding changes; resulting commit recorded. Evidence: [dated production log](GAME1_PROGRESS.md) and [sync record](GAME1_STUDIO_WORKFLOW.md); initial live build bd23b31, not the newest staged build.
- [x] `archive/cascade-pre-game1-pivot-20261024` exists locally/remotely at the expected snapshot; no archive rewriting. Evidence: [dated production log](GAME1_PROGRESS.md) and [sync record](GAME1_STUDIO_WORKFLOW.md); initial live build bd23b31, not the newest staged build.
- [x] Intended Studio `studio_id`, process, place identity, local file and server state recorded. Current instance4273c080-67ba-410b-ad51-3522335b16b1, place127090454461830, universe10769277416; see [October27 live report](qa/2026-10-27/live-studio.md).
- [x] Existing place saved/backed up before latest source refresh; backup location/recovery procedure recorded. [Backup metadata](../backups/cascade-studio-20261025/full-place-backup.json); reopened full copy136,090bytes with unchanged SHA256 after rehearsal. Initial pivot preservation used archive/script exports and in-place recovery objects.
- [x] Actual Script Sync destinations inspected; no target resolves under Windows/System32 or outside the chosen repo root. Evidence: [dated production log](GAME1_PROGRESS.md) and [sync record](GAME1_STUDIO_WORKFLOW.md); initial live build bd23b31, not the newest staged build.
- [x] Disposable **file → Studio → file** probe observed in both directions, with exact paths and cleanup. Evidence: [dated production log](GAME1_PROGRESS.md) and [sync record](GAME1_STUDIO_WORKFLOW.md); initial live build bd23b31, not the newest staged build.
- [x] Single source of truth documented and enforced; staged implementation does not compete with live Studio edits. Evidence: [dated production log](GAME1_PROGRESS.md) and [sync record](GAME1_STUDIO_WORKFLOW.md); initial live build bd23b31, not the newest staged build.
- [x] Repeatable deployment and rollback verified for the tested failure path. Eight-source862e91a readback matched the intended place; partial-source-write rollback restored12 snapshots in its reopened local backup with0 rollback failures. This does not establish crash recovery or every failure mode. [Evidence](qa/2026-10-27/live-studio.md).

## G1 — playable first loop, not a delivery milestone

- [ ] Enter solo directly into a coherent arena, facing targets and an unmistakable next action.
- [x] Actual movement, dash, steering/capture and banking performed in a real client. Initial dash feedback without movement was reproduced, then a planar actuator fix moved z 38→27.259985 with peak speed 65.8760; normal capture/bank worked afterward. Broader regression remains pending. [Live evidence and exact source hashes](qa/2026-10-27/live-studio.md).
- [ ] Visible interaction ≤10s and first reward ≤20s, measured from spawn; sample count and video/log timestamps provided.
- [ ] Independent tester understands solo objective ≤60s; record method and observation, not an invented score.
- [ ] First satisfying complete round ≤120s from spawn, including result presentation; replay works immediately.
- [ ] Captures, inventory, currency, upgrades and unlocks are server-authoritative.
- [ ] Client and server output inspected after the complete round; errors fixed and retested.

## G2 — complete launch content

- [ ] Three visually distinct arenas with coherent art, stable landmarks, obstacle routes and safe navigable boundaries.
- [ ] Twelve authored creature silhouettes visible at gameplay scale, with legible traits and differentiated behavior.
- [ ] Character/creature motion, capture animation, bank celebration and restrained finale VFX reviewed in rendering.
- [ ] Music, UI/capture/bank SFX and positional event audio audible, balanced and tracked in an asset-provenance ledger.
- [ ] No unlicensed or unapproved paid assets; no missing/deleted audio assets in actual engine output.
- [ ] Album/index, selected collection display/parade, three meaningful upgrades, milestone/quest progression and replay goals work.
- [ ] Entire HUD, onboarding, upgrade/shop display, quest view, album, results and settings are complete.
- [ ] Touch, desktop and feasible gamepad controls documented; no critical function requires hover or a physical keyboard.
- [ ] Reduced motion/VFX, music and SFX settings persist and actually alter rendering/audio.
- [ ] Persistent profiles restore coins, collection, upgrades, quests, settings and return state.
- [ ] Load errors never overwrite prior data or allow misleading permanent progression; save errors show honest UI state.
- [ ] First-session events instrumented; test telemetry separated from future live cohorts.

## G3 — required QA matrix

| Run | Minimum procedure | Required evidence | Status |
| --- | --- | --- | --- |
| Fresh solo | Default profile; move, dash, catch, bank, finish, upgrade, replay | Timed action log, client/server output, screenshots/video | PARTIAL: 862e91a catches/banks, 110s results, actual quest claims, boots debit/idempotence and replay observed. Follow-up dash fix has measured solo displacement and cleanup; complete new-build loop regression pending. [October27 report](qa/2026-10-27/live-studio.md) |
| Two clients | Same-target race, both bank, one late joins, one disconnects | Both client views, server inventory totals, no duplicate catch | NOT RUN / evidence pending |
| Four clients | All moving/catching; mixed round phases; one disconnect/rejoin | Per-client state and objective completion; server errors | NOT RUN / evidence pending |
| Ten-round soak | Ten consecutive complete rounds, arena/events rotation, replay every round | Round count, timings, instance/memory/network trends, no softlock | NOT RUN / evidence pending |
| Death/respawn | Respawn carrying creatures and near round completion | Defined carry policy, restored HUD/control, no double reward | PARTIAL: script-injected fall rescued from y=-30 to y≈3 with unchanged progression/health100; actual death, carried creatures and near-round-end cases pending |
| Rejoin/save | Bank, upgrade, claim quest; leave and reconnect | Exact before/after persisted values, session-lock behavior | NOT RUN / evidence pending |
| Failure injection | Failed load, throttled save, transient retry, shutdown, competing session | Reproducible pure/integration commands and assertions | Pure/profile/persistence/lifecycle tests passed; engine integration pending. [Report](qa/latest-checks.json) |
| Remote abuse | Wrong types, NaN/infinity, floods, invalid IDs, out-of-range capture/bank | Rejection evidence; legitimate controls remain usable | PARTIAL: engine-injected wrong Action type, NaN/infinite Biome, unknown upgrade/quest and100 unearned quest requests left progression unchanged; real E capture worked afterward. Broader security cases pending |
| Mobile | Portrait/landscape and representative low-end target; real touch controls | Device/resolution, HUD images, frame time and memory | NOT RUN / evidence pending |
| Accessibility/audio | Reduced motion, SFX/music off/on, color/shape clarity | Real rendered/audio observations, persistent settings | NOT RUN / evidence pending |

No QA row may be marked passed by checking source alone. Synthetic players do not substitute for separate running clients. An emulator result must be labeled as an emulator result; it does not establish physical-device performance.

### Every test report must include

- UTC timestamp and user-local date; exact commit, command or tool action, test environment/Studio version/place identity and profile setup.
- Expected and observed outcome; actual duration/sample count; error excerpts or explicit inspected log window.
- Evidence location: screenshot/video, structured metrics, test output or saved reproduction.
- Failed/blocked/not-run cases with reason and next action. Missing tools are blockers, not passes.
- Whether player input was actual client input, engine script injection or pure mocked logic; what that method cannot prove.

Performance acceptance is not satisfied by an unmeasured claim of stable frame rate. Establish representative device and numeric budgets, measure frame-time distribution during busiest events with four players, and compare instance count/memory before and after the soak. Record graphics quality and network conditions. Investigate growth and optimize before candidate status.

## G4 — reviewable candidate

- [ ] All P0/P1 launch blockers closed with retest evidence; durable issue tracker reflects remaining nonblocking issues.
- [ ] Icon/thumbnail files exist and match actual release quality; screenshot and trailer footage captured from current build.
- [ ] Store copy accurately describes available mechanics; no implied rewards, monetization or features that do not exist.
- [ ] Provenance, accessibility/audio review, package inventory and rollback steps complete.
- [ ] Owner experience/channel identity verified; no accidental public publish while preparing.
- [ ] **Owner actually plays the coherent release candidate** and records approval or actionable feedback.
- [ ] Feedback fixed/retested; candidate commit and archived artifacts recorded.

## G5 — separate owner authorization required

- [ ] Explicit owner confirmation for public publication recorded.
- [ ] Any Robux spending separately authorized; no paid asset purchase inferred from build authority.
- [ ] Any monetization enablement separately authorized; guaranteed cosmetics only unless policy review and additional approval permit otherwise.
- [ ] Publish/smoke check performed only after authorization; recovery candidate retained.
- [ ] Live funnel/retention dashboard verified; first seven days monitored for crashes, save failures and early exits.

## Current honest blockers

October28 PDT: foreground control and unattended play are disabled; scheduling remains paused. The cleanup worker passes ten offline fault tests but is not live-certified. Twenty-four offline checks pass for the staged mastery build; it has not been activated. Earlier solo and partial two-client results do not close contention, four-client, shutdown, soak, audio, platform persistence, device or packaging gates. No human-comprehension or candidate-quality claim is implied. See [incident audit](GAME1_WORKFLOW_CORRECTION.md), [issue ledger](GAME1_ISSUES.md) and [production log](GAME1_PROGRESS.md).
