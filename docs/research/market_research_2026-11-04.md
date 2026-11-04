# SPARK STAMPEDE: Market Research Snapshot

**Date of research:** 2026-11-04 (all sources below accessed 2026-11-04 unless noted)
**Method:** read-only web research. No accounts, no purchases.
**Important method caveat:** direct page fetching (WebFetch) failed for every host I tried (`bloxgamer.com`, `rostats.io`: DNS failure because they are outside this cloud session's allowed network domains). As the tool advised, I stopped trying further hosts. **Everything below therefore comes from web-search result summaries, not from full reads of the pages.** Search summaries can compress, misdate or misattribute figures. Treat every number as "reported by the cited page via search snippet" and re-verify before quoting it externally. See **Limitations**.

Evidence labels used throughout:
- **[OFFICIAL]**: Roblox Creator Hub docs, Roblox newsroom, DevForum staff announcements, Roblox earnings.
- **[CREDIBLE]**: established press or academic sources (Bloomberg, TechCrunch, University of Sydney).
- **[TRACKER]**: third-party CCU or revenue trackers (RoWatcher, Bloxrant, StudioKrew/GGAID, RoStats). These are modeled or sampled, not Roblox-reported.
- **[WEAK]**: blogs, SEO guides, fan wikis. Directional only.
- **[SPECULATION]**: my own inference.

---

## 1. Roblox Top Earning chart ordering

- **Official chart:** https://www.roblox.com/charts/top-earning (and `?SortFilter=default&TimeFilter=0`). Not fetched: it is a JS shell, and fetching was blocked anyway.
- **bloxgamer.com/charts/top-earning/:** **failed to load** (host not reachable from this session).
- **Best available proxy:** Bloxrant, "Top Earning Roblox Games List (November 2026)" https://bloxrant.com/roblox-top-earning-games **[TRACKER]**. The page says it orders games by Roblox's official Top Earning chart. Its **top three, in order, are RIVALS, [UPD 21] Anime Adventures, and Moped Drag [BIG UPDATE]**. I could not retrieve positions 4 and below.
  - The same page shows RIVALS at about 126K concurrent and Anime Adventures at about 78K. A companion Bloxrant page (https://bloxrant.com/roblox-game-revenue-calculator) shows about 105K and 79.5K. The two snapshots differ. Bloxrant's "$/30 days" figures are **modeled estimates, not revenue**. Roblox game revenue is private.
- **Corroborating context:**
  - RoWatcher, "The 10 Highest-Earning Roblox Games in 2026" https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform **[TRACKER/WEAK]** says a Call of Duty-style FPS (RIVALS) led PC and mobile revenue rankings in January 2026. It also lists Pet Simulator 99 (#5) and Steal a Brainrot (#6) using estimated ranges.
  - PCGamesN https://www.pcgamesn.com/roblox/highest-revenue-jan-2026 **[CREDIBLE press]** says the same about January 2026.
- **Takeaway:** a skill-based competitive game (RIVALS) appears to sit at or near #1 of the earning-ordered chart going into November 2026. An anime tower-defense game and a vehicle drag game follow it. This chart orders by Roblox's internal earnings signal. It does not publish revenue, and **player counts shown alongside it are not revenue**.

## 2. Recent popularity (October 2026 and early November 2026)

- **https://rostats.io/charts/2026-10 and https://rostats.io/charts/2026-11:** **failed to load** (host not reachable from this session). The full October and November monthly tables are **not available** in this report.
- **What search surfaced instead** (all **[TRACKER]**, point-in-time samples):
  - **Steal An Egg** was the dominant title of September and October 2026.
    - StudioKrew, "Top Roblox Games September 2026" (published 2026-10-01) https://studiokrew.com/blog/top-roblox-games-september-2026/: about 1.6M concurrent on 2026-09-30 (GGAID tracker), roughly 5x the 329.6K of #2, Brookhaven RP.
    - A StudioKrew October board snapshot (2026-10-29), as reported in search: about 713K concurrent, still #1.
    - The record peak is **unsettled**. One source reports 14.3M CCU on 2026-09-19. RoWatcher's game page (https://rowatcher.com/games/10563114921/steal-an-egg) reportedly lists 2.2M (August 2026). I did not resolve the conflict, so do not cite either figure.
    - RoWatcher's "dying" page (https://rowatcher.com/games/10563114921/steal-an-egg/dying) reports about 926K current and a 1.4M 7-day average, with an undated refresh. Direction: **declining from peak but still very large.**
  - **Murder Mystery 2** led some late-October snapshots.
    - Endgame Tools (2026-10-25 reading) https://endgametools.com/en/roblox/news/roblox-most-popular-games: about 1.54M.
    - LiveCounts https://livecounts.nl/roblox-charts/: peak about 2.24M on 2026-10-25. This is likely a seasonal or Halloween-event surge **[SPECULATION]**.
  - **Fast riser:** **DONT SPLASH** (a horror obby where a blind monster hunts by sound, released around 2026-10-17).
    - RoStats Top Trending, as captured 2026-11-03 via search (https://rostats.io/top/top-trending): #1 trending, about 78K playing and about 94.6K 7-day average.
    - Description from https://axeetech.com/dont-splash-vs-dont-spill-the-water/ **[WEAK]**.
  - **Seasonal events in October** (StudioKrew): Adopt Me! Halloween (10/3), Steal a Brainrot "Haunted Fuse" (10/3–7), Dress To Impress (10/10), Fisch "FischFright 3" (10/17–11/9). Live events cluster around holidays.
  - **"Steal a ___ Egg" clones:** RoWatcher lists many (Steal a Dino Egg, Steal a Fish Egg, Jump To Steal An Egg, and others), which confirms the template is saturated.
- **Platform context [OFFICIAL via press]:** Roblox Q3 2026 results (reported 2026-10-29/30) as summarized by https://gaming.net/roblox-q3-revenue-rises-16-as-bookings-fall-12-to-1-7-billion and https://www.tikr.com/blog/robloxs-daily-users-fell-9-from-a-year-ago-but-it-says-retention-is-the-best-since-2021-heres-what-that-means-for-the-stock:
  - DAU about 138M (−9% YoY, +12% QoQ).
  - Bookings about $1.7B (about −12% YoY).
  - Monthly unique payers about 30M (−16% YoY).
  - Management says platform retention is the best since 2021.
  - Implication: spend per user is concentrating, and the platform is optimizing for retention.
- **Caveat:** sampled concurrency is not revenue and not retention. A CCU spike says nothing about D7/D28 return rates, which now drive Recommended For You (Section 4).

## 3. What makes comparable games work

| Game / genre | First-minute satisfaction | Long-term replay supports | Evidence quality |
|---|---|---|---|
| **RIVALS** (competitive FPS duels) | Instant 1v1 duels, very short matches, immediate win/lose feedback | Ranked ELO queues (1v1/2v2/3v3) launched Update 17 (Dec 2025), **gated** behind 10 duels + level 30 + 14-day account age; seasons with battle pass (2026); weapon skins/wraps; won Best Shooter at Roblox Innovation Awards 2025 | Ranked gating and seasons: **[WEAK]** guides (https://geekchamp.com/?p=233562; https://rowatcher.com/news/rivals-how-roblox-s-top-shooter-built-a-nearly-million-player-empire). No developer interview found. |
| **Steal a Brainrot / Steal An Egg** | Buy a unit, earn income immediately, see others' giant units across the map; rounds of grab/defend/chase take minutes | Rebirth; rarity tiers; **low-punishment** theft (steal it back); limited/admin events; social visibility | Bloomberg (Mar 2026, imitators and lawsuits) https://www.bloomberg.com/news/articles/2026-03-24/roblox-s-hit-game-steal-a-brainrot-battles-its-many-imitators **[CREDIBLE]**. Loop analysis: https://medium.com/@emtertoszef/steal-a-brainrot-phenomenon-6af7b49081e0, https://teknobird.com/?p=46152, https://seaislenews.com/news/2025/nov/13/inside-steal-a-brainrot-what-makes-this-roblox-game-so-addictive **[WEAK]**. Peak 25.4M CCU Oct 2025 per Wikipedia https://en.wikipedia.org/wiki/Steal_a_Brainrot. |
| **Grow a Garden** | Plant, watch it grow, sell; zero skill barrier | Weather events and mutations; timed "admin abuse" events tied to updates; weekly updates. A Roblox spokesperson credited retention, social play with friends and purchase engagement. | Spokesperson attribution via a Game File repost **[CREDIBLE, secondhand]**. Critique that admin-event spikes are short-lived: https://beebom.com/admin-abuse-might-save-dying-roblox-games-but-hurts-them-in-the-long-run **[WEAK/opinion]**. |
| **Fisch** | Cast, then a **skill-gated reeling minigame** (keep the bar inside a moving zone; timing tap on bite) | **Bestiary** cataloguing every fish by rarity/location/bait/conditions; timed event-only pools; Bestiary completion grants XP, currency and a badge | Roblox fandom wiki https://roblox.fandom.com/wiki/Fisching/Fisch; https://deltiasgaming.com/?p=194530 **[WEAK but mechanical facts are consistent]**. No retention data found. |
| **Dandy's World** (co-op survival) | Pick a Toon, cooperate on tasks | Collectible playable characters with distinct abilities and lore; randomized floors; fan art and lore community | https://rowatcher.com/games/5569032992 (about 157K CCU snapshot) **[TRACKER]**; explanations **[WEAK]**. |
| **Parkour / speedrun / movement** | Smooth locomotion, immediate mastery feel | Time trials, personal bests, global/friend leaderboards | **[WEAK]** only. Small tracked titles show low CCU (e.g. a parkour game at about 2K peak, https://rowatcher.com/games/10512890487/1-speed-parkour-escape). Pure movement is a **niche** on its own. |

**Patterns supported by more than one source:**
1. **Immediate reward and visible progress** in the first session. This is also Roblox's official FTUE guidance (Section 4).
2. **Collections with explicit completion targets** (Fisch Bestiary, pet indexes, rarity tiers).
3. **Timed and live events** produce large CCU spikes. One credible-ish critique says those spikes do not translate into long-term retention.
4. **Skill ceilings with competitive structure** (RIVALS) correlate with top earning-chart position. Ranked play is gated until players have experience.
5. **Social visibility and low-stakes rivalry** (Steal a ___) without harsh loss.

**I did not find** developer postmortems with retention numbers for any of these games. The links between specific features and retention are inference.

## 4. Roblox platform guidance and constraints (2025–2026)

**Discovery and recommendations [OFFICIAL]**
- Sources: Roblox newsroom (June 2026), "Optimizing Discovery: How Great Games Reach Millions of Players on Roblox" https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox, plus Creator Hub Discovery https://create.roblox.com/docs/discovery and FAQ https://create.roblox.com/docs/discovery-faq.
- Recommended For You moved from a **7-day to a 28-day retention view** (buckets: D1, D2–7, D8–28), rolling out from about June 15, 2026. Roblox's stated reason is that short-term engagement had been overvalued, favoring flashy thumbnails over long-term value.
- Signals are **per-user averages**. Users acquired via ads, curation, friends, search or social **are excluded** from the ranking stage.
- Third-party coverage says qualified play-through rate was replaced by **play-through rate + first-play bounce**. Example: https://zehn-studio26.com/news/recommended-for-you-retention-update/ **[WEAK, unverified against official text]**.
- **Implication:** the thumbnail must honestly reflect gameplay, and the first session must not bounce.

**Onboarding [OFFICIAL]**
- Creator Hub onboarding https://create.roblox.com/docs/production/game-design/onboarding: "teach the essentials, reach the fun quickly, leave players wanting more."
- Onboarding techniques https://create.roblox.com/docs/production/game-design/onboarding-techniques: **contextual tutorials** triggered on first interaction.
- Engagement analytics https://create.roblox.com/docs/production/analytics/engagement: don't gate fun behind progression; use the **New User First Session Retention** chart.
- There is **no official numeric "time-to-fun" benchmark**. Third-party figures such as "15% D1" or a "3–5 minute aha" are heuristics.

**Analytics [OFFICIAL]**
- `AnalyticsService` reference: https://create.roblox.com/docs/reference/engine/classes/AnalyticsService. Event types: https://create.roblox.com/docs/production/analytics/event-types (mirror: https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/event-types.md).
- Available calls:
  - `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)`. Skipped steps count as completed.
  - `LogFunnelStepEvent`.
  - `LogProgressionEvent` / `LogProgressionCompleteEvent`.
  - Economy events (sources and sinks).
  - Custom events.
- Reported limits:
  - 10 funnels, 100 steps each.
  - 100 custom events.
  - 3 custom fields, which must use `Enum.AnalyticsCustomFieldKeys`.
  - About 24 hours latency and 90-day rolloff.
  - Rate limit 120 + 20×CCU requests per minute.

**Paid random items [OFFICIAL]: hard constraint**
- Sources: https://create.roblox.com/docs/production/monetization/paid-random-items; DevForum "Clarifying Requirements for Paid Random Items" (about 2026-05-26) https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622; TechTimes (Korea driver) https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm **[CREDIBLE]**.
- Requirements:
  - Show **all outcomes with numerical odds before purchase**. This includes purchases made indirectly with Robux-bought currency.
  - Disclose luck boosts and pity systems, and update the displayed odds while they are active.
  - Gate eligibility with **`PolicyService` `ArePaidRandomItemsRestricted`**.
  - **Earned-only randomness is out of scope.**
- **Implication:** SPARK STAMPEDE's decision to avoid paid randomness removes a major compliance burden. Do not add paid "luck" multipliers, because they would bring earned rolls into scope.

**Maturity labels and Roblox Kids / Select [OFFICIAL]**
- Sources: content maturity https://create.roblox.com/docs/production/promotion/content-maturity; Kids and Select https://create.roblox.com/docs/production/publishing/kids-and-select; newsroom (Apr 2026) https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts; TechCrunch https://techcrunch.com/2026/04/13/roblox-introduces-kids-and-select-accounts-for-age-appropriate-access-to-games-and-chat/ **[CREDIBLE]**.
- Label tiers:
  - Minimal/Mild: eligible for **Roblox Kids (5–8)** and **Roblox Select (9–15)**.
  - Moderate: Select and 16+.
  - Restricted: 18+ age-verified.
- Under-16 distribution requires:
  - an age-checked, **verified creator account** with 2SV;
  - **one** of: a refundable 1,000 Robux fee, a Plus/Premium subscription, or purchase-history criteria;
  - passing an engagement evaluation by age-checked 16+ users. Reported thresholds conflict: **250 vs 500** unique engaged plays in a 30 or 60-day window. Verify.
- Social hangouts and free-form drawing are excluded by default.
- **This is an owner/account action.** It is flagged here, not performed.

**Monetization-ethics pressure [CREDIBLE]**
- University of Sydney, "Misleading and Deceptive Monetisation in Roblox" (15 top-earning games, Oct 2025–Feb 2026) https://ses.library.usyd.edu.au/handle/2123/35033; news: https://www.sydney.edu.au/news-opinion/news/2026/05/17/inside-the-pay-to-play-world-of-roblox-targeting-children-.html.
  - Found 14 deceptive or unfair practices, present in 14 of the 15 games.
  - Named practices include **countdown timers creating false urgency** and **near-miss visuals**.
- A May 2026 FTC complaint by advocacy groups (EPIC, Fairplay, NCOSE) targets Robux pricing opacity. Source: https://instreamly.com/posts/loot-boxes-fomo-and-fake-scarcity-8-dark-patterns-brands-must-audit-before-launching-in-roblox/ **[WEAK secondary]**.
- **I found no explicit Roblox rule on daily-login streaks.** The regulatory and academic direction clearly disfavors false urgency and loss-framed pressure.

**Season passes [OFFICIAL]**
- Season pass design https://create.roblox.com/docs/production/game-design/season-pass-design and package https://create.roblox.com/docs/resources/feature-packages/season-passes.
- Roblox's own docs recommend **missions that unlock daily**, so engaged players can't finish a season early.

## 5. Differentiation opportunities and risks

**Opportunities [SPECULATION grounded in Sections 1–4]**
- **Skill-based collection is thinly served.** The top collection games (Grow a Garden, Steal a ___, pet sims) are low-skill and idle-leaning. The top earner (RIVALS) is high-skill but combat. Fisch shows that a **skill-gated capture moment plus a bestiary** can sustain a hit. SPARK STAMPEDE's dash-capture is the same structural idea in a faster, more social wrapper.
- **Short-session arcade with mastery** suits the 28-day retention signal *if* each round creates a reason to return: a personal best, an almost-complete album, a rotating event. A 110-second round naturally supports several sessions per day. A third-party claim that top games average more than 3.5 sessions/day is **[WEAK]**.
- **Co-op herding** (positioning, corralling, combined dashes) is not prominent among current top titles in the data I could see. It offers the "amplify chaos together" fantasy without the PvP toxicity of theft games.
- **Kids/Select eligibility:** a bright, non-violent, Minimal-label game with no paid randomness and no social-hangout core fits under-16 distribution. That audience is now gated, which limits competition for it. It requires verified-creator setup (owner action).

**Risks**
- **"Steal a ___" / brainrot saturation:** new clones launch daily, many are asset flips, and the originator is litigating against imitators (Bloomberg). RoWatcher's analysis (https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals **[TRACKER]**) describes viral spike, steep decline, then a plateau. Steal An Egg is already declining from its peak. **Do not adopt the theft or brainrot framing or naming.** Borrowing only "light, recoverable social rivalry" is fine.
- **Event-spike dependency:** admin-style events inflate CCU but may not retain players. With the 28-day signal, a launch spike without D8–28 return could hurt.
- **Skill-gap churn:** a skill game can lose casual and young players if misses feel punishing. Recoverable misses and assist tuning are essential.
- **Movement niche is small** on its own. Mastery has to be wrapped in collection and social play, not sold as "parkour".
- **Monetization scrutiny:** pressure tactics carry growing regulatory and reputational risk, and may affect Kids/Select standing **[SPECULATION]**.

## 6. Prioritized recommendations for SPARK STAMPEDE

1. **Instrument the hook funnel from day one** with `LogOnboardingFunnelStepEvent`: spawn → first move → first dash → first catch → first combo → round end → round 2 start → album opened. Add `LogProgressionEvent` for arenas and economy events for currency. *Evidence:* [OFFICIAL] AnalyticsService/event-types docs; 28-day RFY signals. **Confidence: High.**
2. **Guarantee a catch within about 20 s with no blocking tutorial.** Spawn near easy creatures and use contextual prompts that appear on first interaction. Never gate fun behind progression. *Evidence:* [OFFICIAL] onboarding and engagement docs; first-play bounce reportedly a discovery signal [WEAK]. **Confidence: High.**
3. **Make the capture moment a readable skill check** (dash timing window with Perfect/Good grades, combo multiplier, recoverable misses). Fisch's reeling minigame is the closest successful analogue. *Evidence:* [WEAK but consistent] Fisch mechanics; RIVALS skill leadership [TRACKER]. **Confidence: Medium-High.**
4. **Build a creature album/bestiary** of about 12 silhouettes × rarity, with per-arena and per-condition entries, completion badges and rewards. Show progress (e.g. "9/12") on the end-of-round screen. *Evidence:* Fisch Bestiary completion rewards; collection/rarity tiers in Steal a ___ and pet games. **Confidence: Medium-High.**
5. **Optimize for D2–7 and D8–28 return, not the launch spike.** Plan a weekly or biweekly content cadence (new event, creature variant, arena modifier) and a thumbnail that honestly shows the dash-catch. *Evidence:* [OFFICIAL] June 2026 discovery change; Grow a Garden weekly updates [WEAK]. **Confidence: High (direction).**
6. **Personal bests first, leaderboards second:** per-arena PB score, best combo, fastest full herd; friends/server boards; daily and weekly boards that reset. **Defer ranked/ELO** until population exists, and gate it behind experience as RIVALS does (10 duels / level 30). *Evidence:* RIVALS ranked gating [WEAK]; movement games' PB/leaderboard loops [WEAK]. **Confidence: Medium.**
7. **Rotating, scheduled, earned arena events** (e.g. a "golden stampede" or weather modifier every few rounds, plus a published weekly event). These are predictable and never purchasable. *Evidence:* Grow a Garden weather/mutations and admin events [CREDIBLE/WEAK]; seasonal events across top games (StudioKrew). Caution: spikes alone don't retain. **Confidence: Medium.**
8. **Opt-in, low-punishment rivalry:** a competitive mode where players can "bump" creatures away from rivals' herds, with full recovery possible within the round and no persistent loss. *Evidence:* Steal a Brainrot's low-punishment social tension [WEAK]; owner constraint that competition never blocks progress. **Confidence: Medium.**
9. **Co-op herding verbs that reward positioning** (pincer corrals, shared combo, revive/assist). These are the core differentiator from saturated idle collectors. *Evidence:* [SPECULATION] gap analysis; Grow a Garden "social play" spokesperson attribution [CREDIBLE, secondhand]. **Confidence: Low-Medium. Validate in playtest.**
10. **Free season track with daily-unlocking missions;** an optional premium track only of direct cosmetics. No pay-to-win, no paid boosts to rarity. *Evidence:* [OFFICIAL] season pass design docs. **Confidence: Medium.**
11. **No paid random items at all.** Monetize with guaranteed cosmetics (trails, dash VFX, herd skins) and possibly a non-power private-server option. Never sell luck multipliers, which would pull earned rolls into PRI scope. *Evidence:* [OFFICIAL] PRI policy (May 2026 clarification), PolicyService requirement. **Confidence: High.**
12. **Ban pressure patterns:** no countdown-timer shop offers, no near-miss reveal animations, no streak *loss* (use cumulative, non-expiring login rewards or "welcome back" bonuses). *Evidence:* [CREDIBLE] University of Sydney study; FTC complaint [WEAK secondary]. **Confidence: High.**
13. **Target a Minimal/Mild maturity label and prepare for Kids/Select eligibility.** No violence or gore framing and no free-form social hangout core. The owner must complete creator verification, 2SV and the fee/subscription path, then the engagement threshold must be met. *Evidence:* [OFFICIAL] content-maturity and Kids/Select docs. **Confidence: High (relevance); Medium (thresholds).**
14. **"One more round" end screen:** show PB delta, album progress, next unlock, and a 1-tap requeue under 5 s. *Evidence:* [OFFICIAL] "leave players wanting more"; session-frequency heuristics [WEAK]. **Confidence: Medium.**
15. **Re-run this research with direct chart access** (rostats monthly tables, the official Top Earning chart) before locking the launch plan, and log the week-over-week ordering. **Confidence: n/a (process).**

## Limitations

- **No direct page reads.** WebFetch failed with DNS/allowlist errors for `bloxgamer.com` and `rostats.io`, and I stopped trying other hosts as the tool instructed. All facts come from search-engine result summaries, which can be inaccurate, misdated or merged across sources. **To enable direct verification, `bloxgamer.com`, `rostats.io`, `www.roblox.com`, `create.roblox.com` and `devforum.roblox.com` must be allowed in the session's network settings.**
- **Top Earning chart:** only the top three positions (RIVALS, Anime Adventures, Moped Drag) were recovered, from one third-party mirror (Bloxrant) claiming to follow the official chart. Positions 4+ are unknown. The official chart was not viewed.
- **October/November 2026 monthly popularity tables were not retrieved.** The figures cited are scattered point-in-time snapshots from different trackers with different methods and timestamps. The Steal An Egg peak figures conflict (14.3M vs 2.2M) and are unresolved.
- **Revenue:** no revenue figures here are Roblox-reported. Tracker "$/30 days" values are models. CCU is not revenue or retention.
- **Retention causality:** no developer postmortem or retention dataset was found for RIVALS, Steal a ___, Grow a Garden, Fisch or Dandy's World. Feature-to-retention links are inference.
- **Policy:** I found no explicit Roblox rule on daily streak mechanics. Kids/Select engagement thresholds are reported inconsistently (250 vs 500 plays; 30 vs 60 days). Third-party claims about discovery signal changes (first-play bounce, 60-minute caps) are unverified against official text.
- **Search was US-only.** Regional chart differences were not examined.
