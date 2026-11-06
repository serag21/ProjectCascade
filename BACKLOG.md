# BACKLOG — SPARK STAMPEDE

Updated 2026-11-05 during plan execution (Phases 1–7 offline done). **Execution order and acceptance criteria live in [FINAL_PRODUCTION_PLAN.md](FINAL_PRODUCTION_PLAN.md)**; this file is the checklist view. "Offline done" means implemented with offline tests; it is not engine-verified.

## Next implementation priority

**Owner Studio validation V1–V12** (`docs/GAME1_PLAYTEST_GUIDE.md`). All cloud-feasible plan work (Phases 1–8) is implemented offline. Next agent work is tuning from Studio findings.

## Phases (cloud-executable)

| Phase | Items | State (2026-11-05) |
| --- | --- | --- |
| 1 Round architecture & fairness | Synchronized Stampede Cycles; intermission; podium awards; Sit out + AFK fix; completion rule (≥3 catches); player non-collision; contested-catch assists; staged hazards for new players; Profile v3 schema; Encounters/ArenaEvents cycle 120 | **Offline done** (771a36b) · ScenarioI |
| 2 Living herd | `HerdNet` buffers over UnreliableRemoteEvent; `CreatureView` interpolation + procedural animation; catch flight; harness support | **Offline done** (e42f7ab) · ScenarioA herd packets ≈215 B, ≈2.8 KB/s per player (fake engine) |
| 3 Feel, UI, audio, first session | Juice set; progressive tabs/HUD/badges; photo mode; accessibility (hold-to-catch, UI scale, volumes, high contrast); practice line + persistent hints; ambience; audio generator v2 (15 cues + 3 loops with finale layers) + `set_audio_ids.py` + music manager | **Offline done** (bb33ff7, 7c829ab) · audio unheard until uploaded (V7) |
| 4 Daily Stampede | `Trial.luau` seeded plans; Trial Grounds (arena 4); Trial start/retry/leave; normalized rules; `Trial.settle`; daily board `SparkDaily_<day>_v1`; records boards show daily top 5; trial results Retry/Leave | **Offline done** (7c829ab, 49401cb) · ScenarioJ, ScenarioG trial path |
| 5 Progression density & goals | `Cosmetics` (formations, bursts, tags, rank titles); rank reward table (no empty rank-up); Style categories; d_trial slot + reroll; ClaimAll on results; economy model v2 + bounds; trial medal calibration | **Offline done** (49401cb) · all-cosmetics sink 28.7 h regular |
| 6 Collection × skill, arena identity | Species Signatures (Challenge verdict, album stars, 2 achievements, aim cue); Aurora Starfall (telegraph, daze, STARSTRUCK; personal starfall on aurora trial days); per-arena obstacle layouts (`Encounters.Obstacles`) | **Offline done** (this phase commit) · ScenarioK |
| 7 Weekly Remix | `Remix.luau` six-week rotation; hooks in Encounters/Main (goldens, density, chain, runs, starfall, statics/pops); per-cycle lock; w_remix weekly slot; HUD + Play tab card | **Offline done** (this phase commit) · SparkRemix |
| 8 Hardening & launch prep | Security additions + exploit telemetry; frozen 8-step funnel + custom/progression events; F8 perf overlay; headless soak 20 cycles × 4 with budgets; competitor comparison; store copy v3; trailer/shot list; release checklist; playtest guide v2; RC package | **Offline done** · ScenarioL, H, F |

## Engine validation (owner / supervised Studio only)

| ID | Requirement | When |
| --- | --- | --- |
| V1 | Install + readback; no Output errors | Checkpoint A (now), B, C |
| V2 | Dash-through reliability (≥80% of deliberate 3-spark lines catch ≥2) | A |
| V3 | HerdNet smoothness and ≤6 KB/s herd traffic | B |
| V4 | Presentation bar (plan §11); first 30 s judged exciting | B |
| V5 | Synchronized cycles with 2/4 clients | B/C |
| V6 | Daily Stampede seed parity, retry, board | C |
| V7 | Uploaded audio plays, balanced | C |
| V8 | Real DataStores (v1/v2→v3, rejoin, daily board) in a test universe | C |
| V9 | Mobile + gamepad on real devices | C |
| V10 | Performance budgets (plan §6.14) | C |
| V11 | 20-cycle × 4-client soak; normal stop | C |
| V12 | Owner RC playtest (G4) | After C |

## Owner actions

Checkpoint B/C playtests on the current build (A was waived by the owner) · upload the 21 generated WAVs and run `tools/set_audio_ids.py` · allow research hosts if primary-source verification is wanted · upload generated audio after Phase 3 · badges (optional) · experience questionnaire/maturity label · test universe for DataStores · Checkpoint C + G4 · G5 publish/monetization decisions.

## Post-launch (must not delay launch)

Remix rotation (weekly) · species packs (monthly) · earned cosmetic sets (monthly) · arena 4 with Prism Portals or currents (quarterly) · seasonal events and Daily seasons · friends leaderboard · owner-gated cosmetic monetization, private servers, badges.

## Completed before this review (offline)

Merged interrupted WIP; perks/heat/loadout; Challenge v2; encounters (gate, stampede run, golden, statics); progression (rank, achievements, daily/weekly goals, trails/titles, profile v2 + migration); server integration; analytics and leaderboard services; economy model + calibration; canyon lanes; records boards; client overhaul; headless engine harness (9 scenarios) + 3 bug fixes; welded creature roots; herd density scaling; first-encounter hints; 44/44 offline checks; owner playtest guide.
