# Focused competitor comparison — 2026-11-05 (plan Phase 8)

**Scope.** This is the single focused comparison the execution brief asked for after core implementation. It compares SPARK STAMPEDE with the two closest successful "skill-catch + collection" games on Roblox: **Fisch** and **Fish It!**. The broad market scan is in [direction_review_2026-11-05.md](direction_review_2026-11-05.md).

**Evidence quality.** Third-party guides and trackers only; no revenue, retention or survey data. Several result pages looked auto-generated, so treat numbers as approximate. Claims marked *inference* are my reading of the evidence.

## What the comparables do

| Topic | Fisch | Fish It! | Sources |
| --- | --- | --- | --- |
| Core catch | Skill reeling minigame; each fish's "Resilience" changes the difficulty. | Hold-to-cast with a luck-meter timing; relaxed pace. | [DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481/11), [Deltia's beginner guide](https://deltiasgaming.com/?p=247875) |
| Collection | Bestiary as the long-term goal; mutations (multipliers) and event-only bestiaries. | Wide fish variety with tiered rarities up to extremely rare "Secret/Forgotten" fish. | [allthings.how mutations](https://allthings.how/fisch-mutations-explained-every-multiplier-and-how-to-trigger-them/), [droidgamers bestiary](https://www.droidgamers.com/guides/fisch-new-years-bestiary/), [findingdulcinea wiki guide](https://findingdulcinea.com/roblox-fish-it-wiki-guide/) |
| Variety over time | Weather and seasons change which fish and mutations appear; short, unannounced "Admin Abuse" events with rare mutations. | Weekly Sunday updates. | [Beebom weather/admin events](https://beebom.com/fisch-weather-and-admin-events), [Pocket Tactics seasons](https://www.pockettactics.com/fisch-seasons), [inkl admin event schedule](https://www.inkl.com/news/fisch-admin-abuse-event-schedule-countdown-november-2025), [RoWatcher Fish It!](https://rowatcher.com/games/6701277882/6-hrs-fish-it) |
| Monetization | Event bundles; some mutations reintroduced in bundles. | Rod skins and event passes, plus luck-boost machines and Robux-only gacha pet eggs, some of which auto-catch. | [hablamosdegamers mutations](https://hablamosdegamers.com/en/guides/fisch-all-about-fish-mutations-and-how-to-get-them-roblox), [narcosis pets guide](https://www.narcosis-the-game.com/all-pets-fish-it-guide-how-to-get-every-pet/) |

## How SPARK STAMPEDE compares (as built today, offline-verified)

| Lesson | Comparable | SPARK STAMPEDE now | Verdict |
| --- | --- | --- | --- |
| Per-target catch skill | Fisch Resilience | **Species Signatures**: each family has its own technique (DASH, PRECISE, TOGETHER, RHYTHM), shown on the aim cue, scored, with album stars | Matched, in an arcade form |
| A felt catch moment | Fisch reeling | Dash-through multi-catches, chain tiers with aura, catch flight to the parade, bank fountain | Different and more physical; feel still needs Studio judgment (V2/V4) |
| Completion goals | Bestiary + mutations | Album (12 species), Prism/Radiant tiers, 12 Gilded variants, signature stars (36), achievements | Comparable depth, all earned in play |
| Changing conditions | Weather, seasons, events | In-cycle rhythm shifts, the per-arena encounter (gate / run / Starfall), golden finale, **Weekly Remix** | Comparable cadence with zero scarcity pressure |
| Rare spikes | Admin Abuse windows | Shared golden finale in every round; Golden Rush remix weeks | Predictable instead of FOMO, which is deliberate (AGENTS rules) |
| Fair comparison | — | **Daily Stampede**: same seeded course, normalized rules, daily board | Something neither comparable offers |
| Social | Mostly parallel play | Shared buzzer, positive podium, contested-catch assists, rally, visible formations/bursts | Stronger shared moments |
| Monetization risk | Event-only items; Fish It! luck boosts and paid gacha | No paid randomness, no paid power, guaranteed cosmetics only (owner-gated) | Safer, and a deliberate trade-off |

## Gaps the comparison exposed, and the small improvements adopted

1. **No "one more" nudge at the moment a round ends.** Comparables keep a completion target in view: the next bestiary entry, the next mutation. Our results screen showed scores but not *the closest thing you are about to finish*.
   → **Adopted:** a results **"Next up"** line that names the nearest earned milestone: an undiscovered species in an unlocked arena, the next Prism/Radiant tier, or the next signature star (pure `Profile.nextMilestone`).
2. **Return reasons were buried in menus.** Comparables surface what is new right away.
   → **Adopted:** while today's reward is unclaimed, the results screen carries a teaser: "DAILY STAMPEDE ready • first finish +40 glow". It is shown only when the trial is unlocked and today's reward is still unclaimed, and it uses no timers or pressure.
3. **This week's conditions were invisible.** Fisch players read the weather; ours had no readable "conditions" until Phase 7.
   → **Already addressed in Phase 7:** the remix name sits on the intermission event line and in the Play-tab card.

**Rejected on purpose:** event-only collectibles (limited bestiaries), unannounced rare windows, luck boosts and auto-catch helpers. They work for retention but conflict with the charter: no deceptive scarcity, no passive collection, no paid randomness.

## Answers this comparison feeds into the final assessment

- *Why does it feel different?* Catching is a movement skill (dash lines, chains, herding) in a shared, timed stampede, not a solitary minigame against a meter.
- *Why another round?* A 2-minute cycle with a shared finale, a podium, personal-best splits, and now a named "next up" goal on every results screen.
- *Why tomorrow?* A new Daily Stampede course and board every day, three goals with a reroll, the weekly Remix, and long-tail cosmetics (≈29 h for a regular player, modelled).
