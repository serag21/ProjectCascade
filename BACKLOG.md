# BACKLOG — SPARK STAMPEDE

Updated 2026-11-05 after the final direction review. **Execution order and acceptance criteria live in [FINAL_PRODUCTION_PLAN.md](FINAL_PRODUCTION_PLAN.md)**; this file is the checklist view. "Offline done" means implemented with offline tests; it is not engine-verified.

## Next implementation priority

**Phase 1, step 1 — `Cycle.luau` + cycle-based round lifecycle in `Main.server.luau`** (partial/warm-up rules, full-round flag, intermission, auto-start, Sit out, AFK completion rule), with `tests/SparkCycle.spec.luau` and headless `ScenarioI_SyncedCycles`. Then the rest of Phase 1.

## Phases (cloud-executable)

| Phase | Items | State |
| --- | --- | --- |
| 1 Round architecture & fairness | Synchronized Stampede Cycles; intermission; podium awards; Sit out + AFK fix; completion rule (≥3 catches); player non-collision; contested-catch assists; staged hazards for new players; Profile v3 schema; Encounters/ArenaEvents cycle 120 | Not started |
| 2 Living herd | `HerdNet` buffers over UnreliableRemoteEvent; `CreatureView` interpolation + procedural animation; catch flight; harness support | Not started |
| 3 Feel, UI, audio, first session | Juice set (bank fountain, chain ring, golden beacon, album card, round beats); progressive tabs/HUD/badges; photo mode; accessibility (hold-to-catch, UI scale, volume sliders, high contrast); dash practice line + persistent hints; arena ambience; audio generator v2 + `set_audio_ids.py` + music manager | Not started |
| 4 Daily Stampede | `Trial`/`TrialService`; Trial Grounds; trial UI with splits; daily board; arena records boards show daily top 5 | Not started |
| 5 Progression density & goals | `Cosmetics` (formations, bank bursts, name tags); rank reward table (no empty rank-up); Style categories; goals refresh (Daily slot, reroll, claim-on-results); economy model + bounds | Not started |
| 6 Collection × skill, arena identity | Species Signatures; Aurora Starfall; per-arena obstacle layouts | Not started (desirable; cut order 4→3→2) |
| 7 Weekly Remix | Data-driven modifiers, weekly remix goal, HUD | Not started (desirable; first to cut) |
| 8 Hardening & launch prep | Security additions; analytics funnel freeze; perf budget overlay; headless soak 20 cycles × 4; store copy v3; trailer/shot list; release checklist; playtest guide v2 | Not started |

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

Checkpoint A on the current build · allow research hosts if primary-source verification is wanted · upload generated audio after Phase 3 · badges (optional) · experience questionnaire/maturity label · test universe for DataStores · Checkpoint C + G4 · G5 publish/monetization decisions.

## Post-launch (must not delay launch)

Remix rotation (weekly) · species packs (monthly) · earned cosmetic sets (monthly) · arena 4 with Prism Portals or currents (quarterly) · seasonal events and Daily seasons · friends leaderboard · owner-gated cosmetic monetization, private servers, badges.

## Completed before this review (offline)

Merged interrupted WIP; perks/heat/loadout; Challenge v2; encounters (gate, stampede run, golden, statics); progression (rank, achievements, daily/weekly goals, trails/titles, profile v2 + migration); server integration; analytics and leaderboard services; economy model + calibration; canyon lanes; records boards; client overhaul; headless engine harness (9 scenarios) + 3 bug fixes; welded creature roots; herd density scaling; first-encounter hints; 44/44 offline checks; owner playtest guide.
