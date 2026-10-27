# SPARK STAMPEDE production issues

Updated 2026-10-26 PDT / 2026-10-27 UTC. This ledger distinguishes implemented fixes from engine-verified closure. G4 is not reached.

| ID | Priority | Issue and next acceptance evidence | State |
| --- | --- | --- | --- |
| SS-01 | P1 | Studio unavailable. Earlier Download a Copy dialog stopped responding; no local full-place copy was created. Latest MCP inventory is empty. Reconnect intended place, recheck identity, backup, mappings and disposable two-way probe before source activation. | External engine-test blocker |
| SS-02 | P1 | Detached PlayerRemoving saves and pending loads could escape shutdown waiting. f1bc3f5 tracks both through finalization. Eleven production-helper tests pass; exercise departure during slow save/load and shutdown in engine. | Fixed offline; live verification pending |
| SS-03 | P1 | A completed older save could show Saved for newer rewards. Revision-aware acknowledgments and pending feedback implemented; results no longer assert unconditional safety. Inject a concurrent bank during delayed persistence in engine. | Fixed offline; live verification pending |
| SS-04 | P1 | First measured action11.091s/catch20.456s missed targets. Starter targets now remain near spawn. Retest actual input from fresh spawn and inspect rendered feedback without inspection delays. | Placement revised; measurement pending |
| SS-05 | P1 | Music/SFX asset IDs blank. Six original WAVs exist and pass file analysis. Bind through supported permitted workflow and verify actual playback, balance, settings and asset access. | Open |
| SS-06 | P1 | Real two-/four-client tests and ten-round engine soak absent. Test same-target contention, late joins, disconnect, mixed phases, replay, death and invalid remotes; capture each client's evidence. | Open |
| SS-07 | P1 | Studio uses isolated memory profiles. Cross-session production persistence and failure behavior have no real platform evidence. Use a separate safe test store when supported; never enable production Studio writes casually. | Open |
| SS-08 | P1 | Touch controls could overlap movement/jump; narrow menus clipped and gamepad lacked menu focus. 3e8b28a fixes layout/focus; 11 usable-canvas geometry cases pass. Render and operate portrait/landscape, safe areas, gamepad selection and menu refresh. | Fixed offline; device verification pending |
| SS-09 | P1 | Installer could partially update before a late failure. Transactional runtime preflights all sources, rejects stale scripts/sync conflicts, verifies source, and rolls back on error. 45 mocked assertions pass. Rehearse real Studio failure/recovery on local copy. | Fixed offline; engine rollback pending |
| SS-10 | P1 | Latest build has not completed actual quest claim, upgrade debit/effect, results/replay and arena unlock/navigation audit. Do not substitute profile tests for end-to-end gameplay. | Open |
| SS-11 | P1 | No representative mobile performance measurements, audio review or complete art review. Measure frame-time, memory/instances/network over busiest four-player events and soak. | Open |
| SS-12 | P2 | Store copy/storyboard exist; actual candidate icon/thumbnail/trailer footage and final packaging do not. Produce after visual/feature audit so assets match the game. | Open |
| SS-13 | P1 | Independent objective-comprehension and owner candidate playtest absent. Request owner only after verified candidate; obtain separate approval before any public publication. | G4 gate pending |

Evidence: [production log](GAME1_PROGRESS.md), [offline report](qa/latest-checks.json), [client QA](GAME1_CLIENT_QA.md), [release gates](GAME1_RELEASE_CHECKLIST.md). Pure/model tests are not live Studio, audible, human usability or device-performance passes.
