# SPARK STAMPEDE — release checklist

Created 2026-10-25. **Release candidate: NO. Public publishing and monetization: NOT AUTHORIZED.**

This is a gate ledger, not a test report. An unchecked item is not passed. Implementation, static inspection, pure-module tests, scripted engine tests, real client interaction and human usability feedback are different evidence classes. When checking an item, link the dated report/artifact and exact commit. See `GAME1_PROGRESS.md` for the latest production state; this document initially records requirements without claiming tests that another agent may be running.

## G0 — recoverable source and Studio

- [ ] Local modifications preserved; `origin/main` synchronized without discarding changes; resulting commit recorded.
- [ ] `archive/cascade-pre-game1-pivot-20261024` exists locally/remotely at the expected snapshot; no archive rewriting.
- [ ] Intended Studio `studio_id`, process, place identity, local file and server state recorded.
- [ ] Existing place saved/backed up before replacing active contents; backup location/recovery procedure recorded.
- [ ] Actual Script Sync destinations inspected; no target resolves under Windows/System32 or outside the chosen repo root.
- [ ] Disposable **file → Studio → file** probe observed in both directions, with exact paths and cleanup.
- [ ] Single source of truth documented and enforced; staged implementation does not compete with live Studio edits.
- [ ] Repeatable deployment and rollback verified against that place.

## G1 — playable first loop, not a delivery milestone

- [ ] Enter solo directly into a coherent arena, facing targets and an unmistakable next action.
- [ ] Actual movement, dash, steering/capture and banking performed in a real client.
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
| Fresh solo | Default profile; move, dash, catch, bank, finish, upgrade, replay | Timed action log, client/server output, screenshots/video | NOT RUN / evidence pending |
| Two clients | Same-target race, both bank, one late joins, one disconnects | Both client views, server inventory totals, no duplicate catch | NOT RUN / evidence pending |
| Four clients | All moving/catching; mixed round phases; one disconnect/rejoin | Per-client state and objective completion; server errors | NOT RUN / evidence pending |
| Ten-round soak | Ten consecutive complete rounds, arena/events rotation, replay every round | Round count, timings, instance/memory/network trends, no softlock | NOT RUN / evidence pending |
| Death/respawn | Respawn carrying creatures and near round completion | Defined carry policy, restored HUD/control, no double reward | NOT RUN / evidence pending |
| Rejoin/save | Bank, upgrade, claim quest; leave and reconnect | Exact before/after persisted values, session-lock behavior | NOT RUN / evidence pending |
| Failure injection | Failed load, throttled save, transient retry, shutdown, competing session | Reproducible pure/integration commands and assertions | NOT RUN / evidence pending |
| Remote abuse | Wrong types, NaN/infinity, floods, invalid IDs, out-of-range capture/bank | Rejection evidence; legitimate controls remain usable | NOT RUN / evidence pending |
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

At creation, this checklist has **no attached completed engine/player/performance evidence**. Research and packaging copy are prepared separately. Read the latest production log and append verified evidence before changing any gate. Unavailable Studio must lead to useful offline implementation and queued engine cases; it must never lead to fabricated playtest success.
