# Game #1 — Product charter and pivot brief (2026-10-24)

**Status:** Approved strategic pivot away from Project Cascade as first Roblox release; Game #1 concept selected for autonomous build. **Working title:** SPARK STAMPEDE. Titles, names, unique icons/art and theme remain original, not derived from top-game IP.

## Decision and preservation
The owner tested the procedurally built Cascade facility. They validated that an agent can create a full navigable world, but criticized dark unreadable spaces, unclear walls/pathing, third-person horror immersion, and a slow/abstract reward loop. They are not interested in treating "technical completion" as "fun." The 2026-10-24 snapshot lives on `archive/cascade-pre-game1-pivot-20261024`. Retain on GitHub and return later. Do not delete or overwrite that branch or ask the owner to create a new Studio game.

Owner's portfolio intent: ~3–5 different Roblox games over successive months; make first release fast, beautiful, thrilling, clear and commercially promising; launch once high quality, maintain and update, then move to next concept. Initial target 30–45 days, maximum 60 before explicit cut/pivot decision. Owner wants the coding agent to own design, construction, QA/iteration, fixes and packaging; user participation at final meaningful playtest and publication decisions.

## Market evidence — Oct 24, 2026 snapshot
**Be precise:** Roblox Top Earning ranking = category ORDER, NOT public revenue dollars or 30-day cash receipts. Historical top-player charts are daily-sampled simultaneous player counts, NOT unique users or sales. Avoid inference of guaranteed success from popularity alone.

Current Roblox Top Earning (order changes over time) source: https://www.roblox.com/charts?SortFilter=default&TimeFilter=0&nl=true ; third-party mirror https://bloxgamer.com/charts/top-earning/ .
Recent top-earning front-runners include RIVALS, Murder Mystery 2, Steal An Egg, Blox Fruits, Adopt Me!, Fisch, Jujutsu Shenanigans, Evade, Dress To Impress; other rankings include Bloodlines, Tower Defense Simulator, Pet Simulator 99.
October-to-date 2026 average concurrent player charts: https://rostats.io/charts/2026-10 ; September: https://rostats.io/charts/2026-09 . October leaders include Steal An Egg, Brookhaven, Murder Mystery 2, Adopt Me!, 99 Nights in the Forest, Blox Fruits, RIVALS, Jujutsu Shenanigans, Steal a Brainrot, Dandy's World. Dramatically rising games such as Break and Steal an Egg support watching growth rate, not just totals.

Observed genre patterns: collect/display/upgrade (Steal An Egg, Adopt Me, Fisch); simple instantaneous risk/reward/social tension (Murder Mystery, RIVALS, Evade); progression and identity (Blox Fruits); fast short sessions and explainable play (successful social/arcade loops). These are design hypotheses, not proof that bright colors or addictive psychology alone determine performance. Watch saturation; do not directly clone a top game's recognizable IP, layout or core gimmick.

## Chosen original game: SPARK STAMPEDE
**One-sentence pitch:** A luminous, chaotic two-minute creature-chase party game: dash into candy-colored arenas, steer and catch stampeding oddball "sparks," trigger wild arena events, bank a haul, evolve your parade, and show off a collection that actually changes how you play.

**Differentiation:** Unlike passive egg incubators/conveyors, success depends on actively steering moving herds and timing limited dash/catch abilities. Unlike pure survival/horror, the feedback is immediate and celebratory. Unlike huge grind simulators, the first catch and upgrade happen almost instantly. Social players can collaborate on herd moves and compete in opt-in mini-challenges. Creatures are not Roblox's existing recognizable pets/IP; shapes are bespoke with consistent visual grammar.

**Core minute-by-minute journey:**
- 0–5 sec: Player appears facing a vividly highlighted herd, obvious giant button/action prompt and arrow/trace to catch area. No cutscene, no lobby, no dark corridor.
- 5–15 sec: Dash / aim / catch first little Spark with pronounced satisfying animation, SFX and readable counter. On-screen feedback calls out a collectible's silhouette/trait.
- 15–30 sec: Catch a few more and bank them in a glowing goal gate; grant a free tangible new move or cosmetic preview; short goal completed.
- 30–60 sec: A stampede pulse changes herd direction and positions an irresistible high-value visible target. Teach players to position and herd, not just click.
- 60–120 sec: A short event/finale, escalating colors/music/audio; player returns to bright plaza, gets round score + album progress + upgrades and sees next objective, with instant Replay. Round never needs other players.
- Future sessions: Unlock movement/steering gadgets, mutate or fuse catches with visible deterministic combinations, fill album, tackle a fresh biome or timed rule modifier, display curated collection.

**Creature-catch mechanic:** The core input should feel responsive on mouse, touch and controller: move, dash with quick cooldown, one capture/steer action that interacts with nearby creatures, position against arena obstacles/attractor goals; a skill-based combo for banking groups. Creatures have obvious silhouettes, animation and AI behaviors that are fun to chase. Optimize herd AI/network replication. A clear collector/tracker guides target and return point.

**Visual direction:** High-saturation, premium Roblox stylization (saturated sky gradients; bright readable neon rims; cartoon/vinyl creatures; appealing rounded geometry; big animation; confetti/sound moments), *controlled* glows and no harmful repetitive flashing. Keep camera helpful and comfortable, zoom bounds for readability, no exploitative obstruction; accessibility slider for reduced motion/VFX/music, color+shape clarity.

**Solo / multiplayer:** 1–4 players, quick optional team play, no matchmaking dependency, self-completable objectives; multiplayer adds streaks, collaborative herd flanks and lively spectacle but cannot prevent solo success. Avoid mandatory voice/chat or friend bonuses required for progression. No stealing paid assets/items and no griefing permanent progress.

**Persistent goals and economy:** Index/album with ~12 authored base critters and readable earned mutations; stable progression earned from play; 3 different active arenas; 3 distinct movement/herding upgrades; replay modifiers/events; friend-safe showcase platform. Avoid millions of meaningless incremental currency digits for the first release. Pace upgrades from early first session to later progression. Any randomness used for purely PLAY-EARNED captures; transparent probabilities when sensible; monetization if enabled should be guaranteed cosmetics or quality-of-life with explicit pricing, not paid spins/gambling or forced urgency.

## Production minimum for real launch (NOT a 30-second demo)
1. Cohesive polished spawn hub, 3 visually distinct arenas, clear navigation and no invisible blockages.
2. Full server-authoritative capture and herd behavior with meaningful skill, responsive camera and movement tools, round flow, varied timed events, satisfying goal/finale, sound and visuals.
3. At least 12 bespoke cute/absurd creature base silhouettes, collection/index UI, earned trait combinations with reasonably bounded variations; visible display parade/case.
4. Early tutorial implicit in gameplay; consistent HUD, shop, quests/milestones, upgrades, settings (including VFX reduction), clean touch/gamepad adaptations.
5. Persistent profile/currency/unlocks with retry/failure handling and anti-exploit validation; offline test/mocks for datastore unavailable in Studio.
6. 1/2/4 client playtests, 10 consecutive rounds without softlocks, respawn/death/leave/rejoin tests, mobile test and rendering/perf inspection; block launch on failures.
7. Screenshot/thumbnail/icon asset plan and packaging, correct owner experience/channel/account confirmation; no public publish without explicit go-ahead.
8. Real first-session funnel event instrumentation: join, first visible action, first catch, first full round, first upgrade, replay, return. Only report observed metrics after real data.
9. Owner sees a coherent, polished, playable RELEASE CANDIDATE for meaningful feedback, not a prototype presented as done.

## Acceptance gates
- **G0 Source integrity**: archive branch exists, Studio MCP + repo sync verified, no secrets/paid asset access, exact current place identified.
- **G1 Foundation**: working full loop with server-authoritative captures, one polished arena, true 1-player Studio run and interaction proof. This is not a delivery-to-user milestone.
- **G2 Full game**: 3 arenas, curated 12 critters, upgrades, replay modifiers, real UI, audio, save/load, complete onboarding.
- **G3 QA**: 1/2/4 clients, no repeatable crashes/softlocks, actual movement/dash/catch interactions, correctly restored saves, device responsive UI, art and sound QA. All logs and evidence stored.
- **G4 Candidate**: screenshot/audio review, packaging, store metadata, hard defects closed, owner plays and decides. NO live publish until separate approval.
- **G5 Launch** (later with owner approval): private smoke/public publish, operational dashboard and first 7-day analytics + fixes. Decision whether to invest further or move Game #2.

**Metrics, not vibes alone:** First meaningful feedback target 10s, first reward <=20s, first complete round <=120s (instrument, observe, revise); UI objective comprehension by independent testers; early session completion; eventual D1/D7 only after public launch. Do not fabricate engagement or universal "hookability" scores.

## Tech architecture / agent responsibilities
Use existing ProjectCascade repository; archive is immutable. Codex agent should select straightforward modular Luau code and source-control model that stays compatible with existing Roblox Studio place and Script Sync, or establish a tested replacement process without needing owner to copy dozens of files. Use Studio MCP to test interactions and inspect rendering and client/server logs. If necessary, build a repeatable world authoring script that re-creates the beautiful world from versioned descriptors so future changes don't depend on fragile hidden Studio state.

Agent owns art direction, implementation, gameplay design, economy balancing, co-op sync, source control, tests, visual QA, packaging. Owner owns credentials if needed, large aesthetic/strategic judgment at real release-candidate stage, and consequential public publishing/monetization approval.

Document practical autonomous testing limits: computer vision/AI simulated inputs won't replicate satisfaction from a real person's emotional reaction; cloud agent cannot use a local Studio process while the PC is sleeping; no agent is expected to run indefinitely through usage caps. Maintain durable `docs/GAME1_PROGRESS.md` and resumable instructions. If fresh chart data significantly changes relative rankings, update source dates/citations and propose evidence-based refinements without derailing delivery every trend cycle.
