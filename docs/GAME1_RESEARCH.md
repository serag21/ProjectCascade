# SPARK STAMPEDE — research and product decisions

Research date: **2026-10-25, America/Los_Angeles**. This supplements the approved charter; it does not change the product. Charts below are observations, not evidence that copying their mechanics will succeed. No revenue dollars, player retention, or sales have been inferred.

## Current Top Earning observation

The [official Roblox chart](https://www.roblox.com/charts?SortFilter=default&TimeFilter=0&nl=true) returned only a JavaScript shell in the research tool. Its ordering could not be independently read. The [Bloxgamer Top Earning mirror](https://bloxgamer.com/charts/top-earning/) describes its ordering as Roblox's and exposes the following leading entries on this date:

| Rank | Experience |
| --- | --- |
| 1 | Murder Mystery 2 |
| 2 | RIVALS |
| 3 | Steal An Egg |
| 4 | Blox Fruits |
| 5 | Bloodlines |
| 6 | Jujutsu Shenanigans |
| 7 | Adopt Me! |
| 8 | Fisch |
| 9 | Anime Adventures |
| 10 | Tower Defense Simulator |

These are **mirror-reported earning ranks**, not financial disclosures. Its adjacent player numbers are concurrent activity, not earnings. Volatile live counts are deliberately omitted. Halloween labels were common at observation; that alone cannot establish an event's effect on retention or revenue. The charter's previous ordering should be treated as a dated observation, not a permanent ranking.

## Recent monthly popularity

[September 2026 RoStats](https://rostats.io/charts/2026-09) reports a complete calendar-month window. Selected sampled average concurrent players: Steal An Egg 1,815,540; Brookhaven 376,913; Blox Fruits 317,792; Murder Mystery 2 230,580; RIVALS 182,625; Adopt Me! 148,482. These are not daily active or unique monthly players.

[October 2026 RoStats](https://rostats.io/charts/2026-10) was **in progress, with data through October 24**, not a complete month. Selected comparisons:

| Experience | October sampled average concurrent players | Change vs September |
| --- | ---: | ---: |
| Steal An Egg | 1,415,318 | −22.0% |
| Brookhaven | 362,548 | −3.8% |
| Murder Mystery 2 | 337,564 | +46.4% |
| Adopt Me! | 230,235 | +55.1% |
| Blox Fruits | 177,593 | −44.1% |
| RIVALS | 164,271 | −10.1% |
| Dandy's World | 122,362 | +260.6% |
| Break and Steal an Egg | 106,263 | +2,673% |

The partial-month comparison mixes calendar days, updates, holidays and different game ages. Large percentage changes from small bases are not reliable forecasts. Activity leaders and earning-rank leaders are different sets.

[RoStats methodology](https://rostats.io/methodology) describes sampling intervals that depend on game size, incomplete coverage, and missing readings. Its modeled earnings are explicitly estimates; this project does not use them. Monthly pages describe averages of sampled daily activity, with minimum coverage. Recheck after month end before drawing longer-term conclusions.

## Primary platform guidance

[Roblox Discovery](https://create.roblox.com/docs/discovery) identifies early bounce, play-through, play days and playtime as major signals, and also considers intentional co-play and spending. [Roblox's Discovery FAQ](https://create.roblox.com/docs/discovery-faq) advises improving gameplay and retention before monetization when retention is weak. This supports measuring a clear first minute and repeatable player goals. It does not promise distribution, imply that monetization is required to test fun, or justify manipulative retention tactics.

## Decisions for this product

The following are **design hypotheses and authored production decisions**, not causal conclusions from charts. Competitor gameplay has not been personally playtested during this research pass.

| Hypothesis | SPARK STAMPEDE decision | Verification / rejection criterion |
| --- | --- | --- |
| Action and collection can coexist | Every collectible is a moving, readable creature; a dash positions the player and a short-range capture rewards approach. No idle incubator is the central loop. | Capture requires actual movement and timing; observe first catch within 20 seconds without instructions from the tester. |
| Immediate comprehension reduces avoidable early exits | Spawn looking into a nearby herd; show one objective and contextual action buttons; bank gate is the tallest gameplay landmark. | Capture first feedback time, reward time and first independent bank. Revise layout if tester searches aimlessly. |
| Mastery provides a reason to replay beyond accumulation | Distinct creature movement, readable event changes, routes through obstacles, group banking and three movement/carry upgrades. | Ten rounds must include meaningful route/event decisions; reject upgrades that are only opaque numeric inflation. |
| Social activity should amplify the base loop | Shared herds, safe permanent collection, optional cooperative positioning; personal rounds and rewards so no lobby blocks solo play. | 1, 2 and 4 clients all complete objectives; joining and leaving never resets another player's progression. |
| Collection becomes meaningful when visible | Twelve distinct silhouettes in an album and a selected parade/display; earned biome access reveals new behavior, not just recolors. | Identify all twelve at gameplay camera distance and in small album tiles; a new unlock changes the next objective. |
| Repeat visits need durable goals, not pressure | Milestones, deterministic upgrades, persistent album and rotating earned arena events. | Returning profile has a clear next attainable goal; no missed-day penalty, paid random reward, fake expiry or forced invitation. |
| Metadata should set an honest expectation | Icon depicts actual creatures; thumbnail depicts actual movement/capture; trailer uses real playable footage. | Compare every advertised action with verified release gameplay before packaging sign-off. |

Do not transplant another game's character, name, map, recognizable UI, pet silhouette, asset, code, or distinctive purchase mechanic. The title remains provisional pending normal release naming checks. Market shifts alone do not authorize a product pivot.

## Scoped production backlog

These priorities complement the durable issue tracker and are not claims of completed implementation.

1. **P0 — source integrity and first loop:** recoverable archive, exact Studio identity, disposable two-way sync proof; spawn → moving target → capture → bank → complete → replay, server authority and measurements.
2. **P0 — save safety and multiplayer correctness:** blocked progression after failed load; session conflict behavior; retry; shutdown; race-safe catches; remote validation and rate limits; late join and disconnect. Prove with injected failures and actual clients.
3. **P1 — expressive content:** three authored arenas, twelve differentiated silhouettes/behaviors, legible obstacles and bank landmarks; limited VFX and sound with provenance.
4. **P1 — progression and presentation:** album/parade, three upgrades, meaningful quests, contextual desktop/touch/gamepad controls, accessible settings, explicit save status, clear replay.
5. **P1 — end-to-end evidence:** measured first-session times, ten-round soak, 1/2/4 clients, respawn/rejoin, touch navigation, performance and sound inspection.
6. **P1 — candidate package:** verified screenshots, icon/thumbnail files, captured trailer sequence, accurate metadata, owner playtest. Public publish and monetization require separate permission.
7. **After candidate quality:** additional cosmetics, deeper deterministic combinations, optional competition and new event packs. Never trade away first-minute clarity or save safety for breadth.

## Measurement plan

Use server receipt times for join, first accepted action, first catch, first bank, first round completion, first upgrade, replay and return; record separate client-ready/visible-feedback timing to expose loading/UI delays. A server timer alone cannot prove visible feedback. Segment by new/returning profile, input type, party size and version. Identify a test run without collecting chat or unnecessary personal data. Studio/test events must be distinguishable from live events.

Target feedback ≤10 seconds, first reward ≤20 seconds, comprehensible solo loop ≤60 seconds, completed first round ≤120 seconds after spawn. State the observed sample count and exact conditions. Never substitute automation reaction speed for human comprehension or pleasure. D1/D7 retention and monetization conversion remain unavailable until appropriate real cohorts exist; monetization is disabled pending owner approval.

## Research reproducibility

Open the five chart/methodology links above and record date, source coverage and ordering. Recheck official chart through a JavaScript-capable surface when available; do not promote a mirror result to independently verified official data. Compare the same monthly metric and note partial-month bias. Research used read-only public pages; no account changes, paid tools or assets.
