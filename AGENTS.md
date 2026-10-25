# AGENTS.md — Project Cascade repository / Game #1 production

## Current decision (2026-10-24)
The owner has pivoted the FIRST ROBLOX RELEASE away from atmospheric horror/puzzle Project Cascade to a bright, immediately gratifying, social/solo arcade collection game. Existing Cascade is NOT a failed code experiment and MUST NOT be deleted: exact snapshot preserved on `archive/cascade-pre-game1-pivot-20261024`. Existing `main` is the working branch for Game #1. Read `docs/GAME1_PRODUCT_CHARTER.md` before editing. The existing `docs/MVP.md`, `docs/BUILD_PLAN.md`, and `docs/ARCHITECTURE.md` describe the archived Cascade idea, not current Game #1.

## You are the autonomous lead, not a micro-task assistant
Deliver a genuinely release-candidate-quality ROBLOX EXPERIENCE end to end. Do not stop after a scaffold, a tutorial, a script-only graybox, a single player action, or a green unit-test report. Continue through world art, satisfying player loop, UI, sounds, progression, save/load, 1–4 multiplayer, multiplayer/edge-case tests, optimization, game packaging and store metadata. Implement, run, critique, fix and re-test. The owner should only be involved for truly essential credentials/Studio connection and a substantial release candidate playtest, final product approval and publishing.

Maintain a long-term durable issue tracker and `docs/GAME1_PROGRESS.md`. Each work session should independently inspect progress, choose the highest-impact next tasks, execute substantial coherent batches, update tests, commit, and continue where supported. Never invent completed tests or claim playability without verified results. Delegate independent, non-conflicting tasks to subagents if available; don't require subagents for progress.

## Research-led design, not generic clones
Reference the Roblox Top Earning chart and prior one/two months of sampled active-player charts (links in charter). Revenue is private; do not label player counts as revenue or claim game sales. Extract proven hooks and retention loops; do not clone names, characters, assets, branding, maps, scripting, specific art, or near-identical monetization. Product direction: `SPARK STAMPEDE` (working title; see charter), a luminous high-energy creature-herding, dash-capture and collection game with real player agency. If fresh market evidence or instrumented playtests disprove the concept, document a proposed concrete pivot with test evidence; do not silently change products.

## First 60 seconds are existential
No loading-time lectures, mandatory lobby wait, dark mazes, hard-to-locate objectives, first-hour grind or large obscure control map. Initial interactive feedback <=10 seconds after spawn; first collectible / rewarding outcome target <=20 seconds; comprehensible solo loop <=60 seconds; complete satisfying first round <=2 minutes. All subjective targets must be investigated via actual play, not merely assumed. Time-to-fun is higher priority than breadth.

## Hard gameplay constraints
- Solo-completable every time, with 2–4-player cooperation and optional competition that AMPLIFIES chaos but never blocks progress.
- Join-in-progress and disconnect gracefully handled; no required chat, voice, purchases, or friend invitations.
- Desktop and mobile controls, with camera/navigation appropriate for bright arcade action (not the old zoom-out horror problem), gamepad where feasible.
- Real skill and choice layered onto collecting: readable targets, dash/magnet/herding/positioning, varied arena events, meaningful progression; not passive click-spamming.
- Stable landmarks; legible contrast; player can always tell next action and destination; avoid collision dead ends and invisible walls.
- Satisfying VFX/SFX feedback without disruptive flashing, ear-splitting audio, excessive screen shake, visual clutter or tricks designed to exploit minors.
- NO real-money gambling, paid random rewards, deceptive scarcity, or high-pressure spend mechanics. Random earned collectibles are acceptable; if random paid features are ever proposed, they require fresh Roblox policy review and separate explicit approval. Prefer direct guaranteed cosmetic products.
- Preserve sustainable solo/multiplayer performance and security; server-authoritative gameplay, validate RemoteEvents, rate limit, protect saves, never trust client balances.

## Repo and Roblox Studio integration
- Project folder: `C:\Users\serag\source\repos\ProjectCascade`; GitHub: `serag21/ProjectCascade`.
- Existing Studio Script Sync was configured to local `src/ReplicatedStorage/Cascade`, `src/ServerScriptService/Cascade`, and `src/StarterPlayer/StarterPlayerScripts/Cascade`. Server script mapping previously unpredictably pointed to System32. Inspect and validate actual mapping; DO NOT blindly assume sync is healthy or tell the owner to repeatedly remap it.
- Roblox now provides a native Studio MCP server. In Studio: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server; Quick connect > Codex CLI (if present). Official docs: https://create.roblox.com/docs/ai/accelerated-workflows and https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/mcp.md .
- First task: establish Studio MCP connection, select the intended Studio `studio_id`, inspect current place, verify file synchronization in BOTH directions on a disposable object/file, and explicitly choose/document a single source of truth. Do not modify Studio and repo in parallel without an intentional sync strategy. Preserve the existing working place, scripts and versioned work before destructive pivot.
- Work in this repo; owner should NOT have to create a new Roblox experience, change project location, or manually transfer many scripts. Replace active game source IN PLACE once archive branch and safe recovery are confirmed. Generate and own all needed Luau and art/config/asset pipelines.
- Use Studio MCP to create/edit scenes, playtest, simulate player input, inspect errors and investigate visual/navigation problems. Document any MCP limitations accurately. Supplement with automated Luau/lint/test tools and Studio scripted multi-client testing. If GUI Computer Use is enabled and legitimately available, use it for screenshots/inspection; otherwise don't pretend to see the rendering.
- If local Studio unavailable, do useful offline work and tests. Cloud coding can continue offline, but live Studio tests require a reachable Studio host; never claim otherwise.
- No paid asset purchases, Roblox public publishing, monetization enablement, account actions, or irreversible platform operations without owner approval. Private/unpublished local Studio testing is allowed. Do not commit credentials.

## Release quality bar
Expected Game #1 target within 30–45 days, 60-day hard decision gate (not a guarantee). Explicitly cover:
- Clear 10s/20s/60s hook, 2-minute active-round loop, game-wide replay/collection goals.
- Designed luminous cohesive themed map(s), characters, 3D props, obstacle collision, animation, particle systems, music and positional audio with provenance.
- Entire HUD/tutorial/controller UI/storefront/readable mobile displays/settings/reduced-motion toggle and an unmistakable path through the game.
- ~12 curated collectible creature silhouettes, rarity/readable trait system, 3 progressively richer arenas/biomes, several timed hazards/chaos events, upgrade paths, quest/milestone and album/index, save/load.
- Solo, 2-player, and 4-player simulated functionality, server-authoritative capture, anti-duplication and race-condition handling, late-join and disconnect support.
- Usable game thumbnail/icon/trailer storyboard/store description, analytics instrumentation for first action/reward, first match completion, return and monetization conversion (real data after launch).
- Performance: stable frame rate on representative mobile target, no runaway instance growth, bounded VFX/network activity.
- Automated test report with REPRODUCIBLE commands, timestamp, exact environment, tests run and failed/blocked, error/log excerpts, measured hook times, screenshots where available. Never fabricate numbers.
- Final `docs/GAME1_RELEASE_CHECKLIST.md` and honest blockers, and ONE owner's actual release-candidate hands-on playtest before public publication.

## Autonomous work cadence
1. Read charter, previous progress, current repo, MCP state.
2. Research uncertain current facts from reliable sources before choosing implementations.
3. Break into independent modules and parallelize only when there is no contention for files/Studio instance.
4. Produce meaningful tested slices that integrate into the full playable product; keep working toward release checklist, not isolated demos.
5. Run automated unit/integration tests and Studio real playtests when connected; inspect server/client errors, visual readability, movement/camera, objectives, UI, save/load, multiplayer.
6. Log measured quality, compare against gates; improve weak spots proactively.
7. Commit frequently in recoverable milestones, update progress file, resume next most important task without requesting user to copy logs back and forth.
8. Stop only on genuine external blocker, budget/tool limit, or for owner approval at release candidate. State exactly what is complete versus not tested.

Remember: the owner's stated goal is to release several distinct games over time and rapidly learn what players actually return to. Game #1 must be a serious release, not endless prototyping.
