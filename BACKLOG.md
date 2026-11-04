# BACKLOG — SPARK STAMPEDE

Priority-ordered remaining work. Updated 2026-11-04 by the cloud production session. "Offline done" means implemented with offline tests; it is **not** engine-verified. Engine items need the owner's local Studio (see `docs/GAME1_WORKFLOW_CORRECTION.md` — no unattended Studio).

## P0 — release blockers that need local Studio (cannot be done in cloud)

| ID | Item | Acceptance evidence |
| --- | --- | --- |
| B-01 | Install current build (`python tools/build_studio_install.py`, run installer in Edit mode) and read back all sources | Manifest hashes match; no output errors on Play |
| B-02 | Solo round with new mechanics: dash-through multi-catch, statics pop/zap, Spark Gate herding, Stampede Run, golden finale, buzzer | Timed log + screenshots; no server/client errors |
| B-03 | Verify every `rbxasset://sounds/*` placeholder exists in the client, or replace with owner-uploaded original WAVs | Audible playback; provenance sheet |
| B-04 | 2- and 4-client sessions (same-target race, gate assist, golden contest, scramble recatch, leave/rejoin) | Per-client evidence, no duplicate rewards |
| B-05 | Real DataStore persistence (v1→v2 migration on a test profile, rejoin restore, leaderboards OrderedDataStore) in a test universe | Before/after values |
| B-06 | Mobile/touch + gamepad pass of the new menus (Play/Goals/Style/Records tabs, results) | Device screenshots, no clipping/overlap |
| B-07 | Performance: busiest moment (4 players, statics, goldens, stampede) frame time and instance counts over a 10-round soak | Numbers vs budget |
| B-08 | Owner hands-on release-candidate playtest (G4) | Owner notes |

## P1 — offline work remaining

| ID | Item | State |
| --- | --- | --- |
| B-10 | Client UI overhaul for new systems (combo meter, encounter visuals, results breakdown, Play/Goals/Style/Records tabs) | In progress (this session) |
| B-11 | Headless fake-engine harness booting real Main/World/Client scripts with API-validated instances | In progress (this session) |
| B-12 | Glow surplus after ~14 h (see `docs/GAME1_ECONOMY.md`): add seasonal earned cosmetic sets | Planned post-launch |
| B-13 | Replace primitive creature animation (bob/tilt) with per-behavior hop/squash and catch pop on the client | Not started |
| B-14 | Per-arena lighting/ColorCorrection tint on the client when travelling | Not started |
| B-15 | Thumbnail/icon/trailer capture from the candidate build (needs Studio) | Blocked on B-01 |
| B-16 | Roblox badges for achievements (needs owner-created badge IDs; `Progression.Achievements` ready) | Blocked on owner |

## Done this session (offline)

Merged interrupted WIP; perks/heat/loadout; Challenge v2 (x4, dash-through, herd, golden, pops, assists, haul, finale, buzzer, Radiant); encounters (gate, stampede run, golden, statics); progression (rank, achievements, daily/weekly goals, trails/titles, profile v2 + migration); server integration; services (analytics, leaderboards); economy model + calibration; canyon lanes, records boards; lint gate; portable runner; Rojo mapping; packaging v2 copy; monetization proposal (not enabled).
