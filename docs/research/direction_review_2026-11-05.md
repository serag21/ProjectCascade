# Direction review research — 2026-11-05

Supports `FINAL_PRODUCTION_PLAN.md`. Read-only web research; no accounts, purchases or Studio. Builds on `market_research_2026-11-04.md` (paid-random-item policy, maturity labels, academic monetization critique).

**Method limits (important):** direct page fetches of `roblox.com`, `create.roblox.com`, `about.roblox.com`, `devforum.roblox.com`, `reddit.com`, `bloxgamer.com` and `rostats.io` are blocked by this cloud session's network policy, so every finding below comes from **web-search result summaries** of the cited pages, not full reads. Player counts are third-party tracker snapshots (sampled concurrency), never revenue. No competitor was personally playtested. No retention or revenue data exists for any game, including ours. Allow those hosts in the environment's network settings to verify primary sources.

Evidence labels: **[E-official]** Roblox's own statements (via search summary) · **[E-tracker]** third-party charts · **[E-press]** established outlets · **[E-community]** forums, guides, player comments · **[weak]** SEO/mirror pages. Design inferences are marked **[H]** in the plan.

## 1. Platform direction

| # | Finding | Label | Source |
| --- | --- | --- | --- |
| P1 | In 2026 Roblox re-weighted Recommended For You toward long-term retention: lookback widened from 7 to 28 days, with play-through and first-play bounce signals; Roblox describes favouring highly retentive games at the expense of near-term monetization. | E-official (via press) | [Roblox newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) (not fetchable), [godisageek](https://godisageek.com/2026/08/roblox-9-billion-algorithm-change/), [chartmill](https://www.chartmill.com/news/external/33360/rblx-s-discovery-shift-targets-retention-can-monetization-hold-up) |
| P2 | Press framed the change as deprioritising low-retention "brain rot"/monetization-heavy games; the CEO "filter" quote is unverified. | weak | [creation.dev](https://www.creation.dev/learn/roblox-algorithm-update-filtering-brain-rot-games-april-2026) |
| P3 | Official onboarding guidance: teach essentials, reach the fun quickly, end the first session with a reason to return; the dashboard tracks per-minute first-session retention. Community guides add: teach through play, spread advanced systems across sessions; session-2 churn reflects expectations set in session 1. | E-official (via summary), E-community | [Roblox onboarding docs](https://create.roblox.com/docs/production/game-design/onboarding), [engagement analytics](https://create.roblox.com/docs/production/analytics/engagement), [RoWatcher sessions 2–5](https://rowatcher.com/news/why-your-roblox-game-bleeds-players-between-sessions-2-and-5) |
| P4 | Paid random items need odds disclosure and eligibility checks (May 2026); earned-only randomness is exempt; selling luck boosts pulls earned rolls into scope. | E-official (prior report) | `market_research_2026-11-04.md` §4 |

## 2. What is popular now (snapshots, early November 2026)

| # | Finding | Label | Source |
| --- | --- | --- | --- |
| C1 | Top Earning (third-party mirrors; official chart unreadable here): RIVALS most often #1; others named include Anime Adventures, Moped Drag, Steal An Egg, Adopt Me!, Blox Fruits, Pet Simulator 99, Fish It!. Sources disagree below #1. | E-tracker | [Bloxrant](https://bloxrant.com/roblox-top-earning-games), [Statroblox](https://statroblox.com/leaderboards/chart) |
| C2 | Fastest-growing new games (Nov 2 list): DONT SPLASH (obby, released Oct 17, ~118M visits), Cat Battles (physics cat brawler, Oct 5), Turbo Soccer (car soccer, beta Sept), RoWorld, Sell Fries!, Fake an Egg. | E-tracker | [GGRecon](https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/), [RoTrends DONT SPLASH](https://www.rotrends.com/game/10771421858/DONT-SPLASH), [RoWatcher Cat Battles](https://rowatcher.com/games/10769543567/cat-battles), [RoWatcher Turbo Soccer](https://rowatcher.com/games/10767012496/new-turbo-soccer-beta-1-0) |
| C3 | Most-played live: Steal An Egg, Steal a Brainrot, Brookhaven, Blox Fruits, Adopt Me!. | E-tracker | [livecounts](https://livecounts.nl/roblox-charts/), [endgametools](https://endgametools.com/en/roblox/charts) |
| C4 | RIVALS: short first-to-5 duels; progression through keys, contracts, streaks and cosmetic skins that do not affect combat; separate ranked ladder. | E-community | [RoWatcher RIVALS](https://rowatcher.com/news/rivals-how-roblox-s-top-shooter-built-a-nearly-million-player-empire), [PixelTwelve](https://pixeltwelve.com/games/roblox-rivals) |
| C5 | Fisch: skill-based reeling minigame; each fish has a "Resilience" stat changing difficulty; the bestiary is the long-term completion goal; the developer built it because other fishing games felt unengaging. | E-official (DevForum spotlight) | [DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481/11), [Roblox wiki](https://roblox.fandom.com/wiki/Fisching/Fisch) |
| C6 | Fish It!: dominance attributed to AFK auto-fishing and luck-based simplicity; described as its "most polarizing feature". | E-community | [RoWatcher Fish It!](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026) |
| C7 | 99 Nights in the Forest (14.2M peak CCU): co-op works through role-splitting and a short day/dangerous night loop; solo remains viable. | E-press, E-community | [PC Gamer](https://www.pcgamer.com/games/survival-crafting/with-a-peak-player-count-of-14-2-million-99-nights-in-the-forest-has-an-audience-other-multiplayer-games-would-kill-for-to-find-these-behemoth-playerbases-you-need-to-be-on-a-platform-like-roblox/), [PC Gamer tips](https://www.pcgamer.com/games/roblox/99-nights-in-the-forest-tips) |
| C8 | Weekly or bi-weekly content drops are common; events supplement rather than replace cadence. | weak | [rolearn cadence](https://rolearn.dev/guidance/update-cadence-content-planning) |

## 3. What players complain about

| # | Finding | Label | Source |
| --- | --- | --- | --- |
| N1 | Grow a Garden's decline is blamed on pay-to-win concerns, crowded gardens and repetitive gameplay; Garden Horizons collapsed within two weeks amid exploits, performance problems and developer departures. | E-community | [Roonby](https://roonby.com/2026/01/13/grow-a-garden-is-losing-players-is-it-finally-dead/), [allthings.how](https://allthings.how/garden-horizons-player-count-drop-what-happened-and-is-the-game-dead/) |
| N2 | Steal a Brainrot: players hated griefers deleting rare items in transit; an anti-griefing update followed. Parents report intense emotional reactions to losing rare characters and pressure to spend. | E-community, E-press | [nerdschalk](https://nerdschalk.com/anti-griefing-system-in-steal-a-brainrot-stealing/), [UT Daily Beacon opinion](https://utdailybeacon.com/206768/opinion/opinion-what-steal-a-brainrot-means-for-the-future-of-youth-entertainment/) |
| N3 | Login-streak rewards draw FOMO and "punished for missing a day" complaints; a platform design guide says short daily play quests retain better than login rewards. | E-community | [Steam discussion](https://steamcommunity.com/app/2429640/discussions/0/4693405245806829936), [War Thunder forum](https://forum.warthunder.com/t/fix-the-daily-login-streak-rewards/308510), [Horizon Worlds guide](https://developers.meta.com/horizon-worlds/learn/videos/worlds-that-bring-players-back) |
| N4 | General Roblox sentiment pieces: games feel "pay-to-win", simulators get repetitive, players report boredom. | weak | [The Howler](https://thehowleronline.org/12464/viewpoint/roblox-should-be-fun-but-it-isnt-anymore/), [gameranx](https://gameranx.com/updates/id/543816/article/roblox-grow-a-garden-gets-scathing-review-from-uk-publication/) |
| N5 | Kill stealing: when the last hit takes the whole reward, players who did the work feel robbed; it is common where rewards are prized. | weak | [wiki mirror](https://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq.ipfs.4everland.io/wiki/Kill_stealing.html) |
| N6 | Timing games draw latency complaints (a 200 ms ping makes a parry window harder); spam-click penalties push play toward timing skill. | weak | [allthings.how Blade Ball](https://allthings.how/roblox-blade-ball-how-to-play-full-guide/) |

## 4. Mastery and daily-return evidence

| # | Finding | Label | Source |
| --- | --- | --- | --- |
| M1 | Seeded daily challenges (Spelunky Daily, Slay the Spire Daily Climb) give every player the same run, keep leaderboards meaningful, and let the server re-verify scores; called "one of the highest-value-per-line-of-code features" for games with RNG. | E-community | [Spelunky wiki](https://spelunky.fandom.com/wiki/Daily_Challenge_Mode_(HD)), [Daily Climb write-up](https://saschb2b.github.io/game-mechanics/games/slay-the-spire/daily-climb), [dev.to seeded dailies](https://dev.to/gowtham_r_2002/one-seed-same-puzzle-for-everyone-seeded-rng-for-a-fair-daily-challenge-1h7d) |
| M2 | Successful skill games keep progression cosmetic and separate from competitive power (RIVALS), and vary challenge per target (Fisch Resilience). | E-community, E-official | C4, C5 |

## 5. What this means for SPARK STAMPEDE (summary; full reasoning in the plan)

- Retention is now the discovery currency (P1), so session-2 to day-28 reasons to return matter more than monetization or virality.
- The market's skill-plus-collection exemplar (Fisch) succeeds on a *felt* catch skill with per-target variety (C5). Our catch moment lacks that feel today; our differentiator must live in the moment, not only in systems.
- AFK/luck collectors earn big (C6) but are exactly what our charter rejects and what P1 appears to deprioritize; we stay active-skill.
- Social chaos and short readable premises are rising (C2: DONT SPLASH, Cat Battles, Turbo Soccer) [H: shared, laughable moments; one-line hooks].
- Avoid every documented failure: pay-to-win, crowding, repetition, exploits, performance collapse, griefing loss, streak FOMO (N1–N5).
- A seeded daily trial gives fair competition and a non-chore daily return (M1).
