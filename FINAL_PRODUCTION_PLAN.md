# SPARK STAMPEDE — FINAL PRODUCTION PLAN

**Version 1 · 2026-11-05 · Baseline commit `b5b78bc` on `claude/awesome-brown-27rwqo`.** This is the executable blueprint for the final production sprint. It decides launch scope, specifies each remaining system against the real code, and orders the work. Where this plan and `docs/GAME1_DESIGN_SPEC.md` disagree, **this plan wins** (decisions D10–D27 in `DECISIONS.md`). `AGENTS.md` operating rules still take precedence over everything: offline by default, no unattended Studio, no publishing/monetization/Robux/account actions without the owner.

Evidence references `[C#]`, `[P#]`, `[N#]`, `[M#]` point to `docs/research/direction_review_2026-11-05.md`. **[H]** marks a design hypothesis, not evidence. Nothing in this plan claims engine, player or revenue validation; the whole game still needs Studio verification (§13).

---

## 1. Executive verdict

SPARK STAMPEDE's *systems* are now deep and well-tested offline. What it lacks is **felt quality and coherent shared moments**. The single biggest launch risk is that a new player, in the first ten seconds, sees primitive models sliding at 10 Hz, hears placeholder clicks, and presses E near things that vanish. The sprint must therefore spend most of its effort on **feel, presentation, and a few high-leverage structural changes**, and almost none on new currencies or systems.

| # | Question | Verdict | Decision |
| --- | --- | --- | --- |
| 1 | Is the catch loop distinctive? | **Partly.** Dash-through lines, herding through a moving gate, scatter-and-recatch and buzzer risk are distinctive next to Roblox's passive collectors and combat games. The catch *moment* itself is generic proximity-press, and creatures do not feel alive. | Keep the loop. Invest in the moment: client-rendered, animated creatures, catch flight and audio (§6.2–6.3). Give each species a signature catch technique (§6.6). |
| 2 | Is mastery deep enough? | **Broad, but unmeasurable.** Precision, dash, multi, x4 chains, herding, statics, perks and Heat give real depth. Scores from shared, crowded rounds are too noisy to be a fair yardstick. | Add a **seeded Daily Stampede** with normalized rules as the fair measuring stick and "one more try" loop (§6.4) [M1]. |
| 3 | Do 50 ranks give enough variety? | **No.** 32 of 49 rank-ups grant nothing (16–19, 21–24, 26–29, 31–34, 36–49). | Every rank-up grants something. Add three cheap, visible cosmetic categories (§6.7). |
| 4 | Do arenas differ enough? | **No.** All three share one layout, and Aurora reuses Meadow's Spark Gate. | Aurora gets **Starfall** instead of the gate, and each arena gets its own obstacle layout (§6.8). |
| 5 | Is presentation exciting and polished? | **No.** It uses primitive geometry, has no creature animation, no music, unverified placeholder SFX, and all 7 menu tabs show from minute one. | Presentation is a launch gate (§6.3, §11). |
| 6 | Is solo as compelling as multiplayer? | **Mechanically yes; socially flat.** Everyone runs a personal timer, so there are no shared climaxes. Strangers can "steal" a spark you chased [N5]. | **Synchronized Stampede Cycles** give a shared golden finale and a podium. Add contested-catch assists and player non-collision (§6.1, §6.10). |
| 7 | Are dailies fun? | **They are passive chore lists**, though at least streak-free. | Dailies become two play goals plus the Daily Stampede, claimable from results with a free reroll. Still no streaks [N3] (§6.9). |
| 8 | Is competition fair? | **No.** Public all-time/weekly boards from normal rounds reward crowded servers and heat stacking. | Public boards cover **Daily Stampede only**. Normal rounds keep personal records plus a positive per-server podium (§6.10). |
| 9 | Does the economy run out? | **Yes, around 14 h**, when glow has nothing left to buy. | Cosmetic categories push the sink to about 30 h. Seasonal earned sets follow after launch. Glow never buys power (§6.7). |
| 10 | Can content sustain launch and updates? | **Launch: yes, if presentation lands.** Cadence: yes, because creatures and arenas are data and procedural code. | Weekly data-driven Remixes, monthly species packs, quarterly arena (§15). |

**Also found during review:**
- **AFK exploit.** `Progression.roundXp(0)` returns 60, so an idle player earns about 1,800 XP/h and completes "finish N rounds" goals. Fixed in Phase 1 (§6.1).
- **First-round overload.** Brand-new players face sweeps and statics 20–25 s after their first bank (`Main.server.luau` sets `hazardStarted` at that bank). Staged introduction is in §7.

---

## 2. Product pillars (final)

1. **Ten seconds to joy.** Movement, a glowing target and a satisfying catch within 10 s; a bank within 20 s; a dash-through "wow" within 40 s.
2. **A catch you can feel and master.** Every catch has animation, sound and a readable reason it scored. Each species asks for its own technique.
3. **One shared stampede.** Everyone in an arena shares the same two-minute arc: start, rising pressure, golden finale, buzzer and podium.
4. **Fair skill, kind competition.** Daily Stampede is the fair yardstick. In-server recognition is positive (awards, never "last place").
5. **Long goals, no chores.** Rank, Heat, album tiers, signatures, Gilded set and cosmetics are all earned through play. No streaks, energy timers, paid power or paid randomness.
6. **Nothing you earned can be taken.** No PvP stealing, no griefing, no item loss [N2]. Mistakes cost only unbanked bonus and re-catchable sparks.

---

## 3. Launch scope

| Status | Items |
| --- | --- |
| **IN (launch-critical)** | Synchronized Stampede Cycles + intermission + podium awards (§6.1). Herd replication v2 with client-animated creatures (§6.2). Presentation and feel pass, including original audio set and music (§6.3). First-session sequence with progressive disclosure (§7). Daily Stampede (§6.4). Rank-reward density + Formations/Bank Bursts/Name Tags (§6.7). Goals refresh (§6.9). Social fairness: contested-catch assists, non-collision, AFK fix (§6.10). Accessibility basics (§6.11). Profile v3 (§6.15). Hardening, analytics and performance budgets (§6.12–6.16). |
| **IN (launch-desirable; cut in this order if time runs out)** | 1. Weekly Remix (§6.9.3). 2. Per-arena obstacle layouts (§6.8.2). 3. Aurora Starfall (§6.8.1). 4. Species Signatures (§6.6). Signatures are cut last: they connect collection to skill. |
| **KEEP as implemented** | Core loop, dash-through, chains/x4, haul/finale/buzzer, personal statics, biome sweeps, Spark Gate (Meadow), Stampede Run (Canyon), golden finale, scatter-on-hit, herd density scaling, Arena Rally, starters, 8 perks, Heat 0–5, 3 upgrades, 13 milestones, 25 achievements, trails/titles, album (Glow/Prism/Radiant/Gilded), records per arena×heat, lease persistence, analytics service, leaderboard service, the full QA tooling. |
| **CHANGE** | Public normal-round leaderboards → Daily Stampede boards. Arena records boards show today's Daily Stampede top 5. Aurora's Spark Gate → Starfall. All tabs at once → progressive tabs. Personal 110 s timers → shared 120 s cycles. |
| **LATER (post-launch, must not delay launch)** | Prism Portals; species packs; arena 4; friends leaderboard; seasonal cosmetic sets; ranked Daily seasons; photo-mode extras; owner-approved cosmetic monetization; badges (owner creates). |
| **REJECTED** | See §16 (trading, eggs/pets with stats, PvP stealing/knockback, rebirth, hub lobby, AFK modes, energy timers, paid boosts, crafting/bases). |

---

## 4. Feature and content inventory versus code

"Offline" means implemented with offline tests. No current system is engine-verified. The October 27 live session tested an older build.

| Area | Implemented (where) | Offline evidence | Launch action |
| --- | --- | --- | --- |
| Move/catch/carry/bank | `Main.server.luau` `capture`/`claim`/`bank`, `Rules` | integration 26 cases, headless B–D | Keep; feel pass |
| Dash + dash-through | `Main` Dash action (LinearVelocity), `dashSweep`, `Targeting.sweep` | depth suite, harness | Keep; tune radius in Studio |
| Chains x4, haul, finale, buzzer, Radiant | `Challenge.luau` v2 | SparkDepth 43,896 assertions | Keep; cycle-aligned finale |
| Personal statics, scatter | `Main` `updateStatics`/`hit`/`scatter`, `Encounters` | harness, headless | Keep; introduce in round 3 |
| Biome sweeps | `ArenaEvents.hazard` | ArenaEvents suite | Keep; introduce in round 2 |
| Spark Gate (Meadow, Aurora) | `Encounters.gate`, `Main` herd loop | depth + harness | Meadow only; Aurora → Starfall |
| Stampede Run (Canyon) | `Encounters.stampede`, `Main` runners | depth | Keep |
| Golden finale (any species) | `Main` heartbeat, `World.gild` | harness | Keep; shared climax |
| Herd density scaling | `Main` heartbeat surplus | headless D/E | Keep |
| Arena Rally | `ArenaRally.luau` | RallyTargeting suite | Keep |
| Starters (3, owner-only) | `Main` `issueStarters`, client visibility block | client blocks test | Keep; add dash practice line |
| Perks (8), Heat (0–5), upgrades (3) | `Loadout.luau`, `Config.Upgrades` | SparkDepth | Keep |
| Rank 1–50 | `Progression.xpFor/rank/roundXp` | LongTerm, economy | Keep curve; fill rewards; AFK fix |
| Achievements 25, milestones 13 | `Progression.Achievements`, `Config.Quests` | LongTerm | Keep; add trial/signature achievements |
| Daily (13 pool)/weekly (10 pool) goals | `Progression` goals | LongTerm | Revise (§6.9) |
| Trails (22 incl. none), titles | `Progression.Trails`, `Main.applyStyle` | LongTerm | Keep; add 3 categories |
| Album: 12 species, tiers, Gilded | `Config`, `Profile`, `Menu` Album | Profile/LongTerm | Keep; add signatures |
| Records per arena×heat | `Profile.records` | LongTerm | Keep (personal) |
| Public leaderboards (all-time/weekly normal rounds) | `Services.leaderboard`, records boards | Services suite | **Replace** with Daily boards |
| Analytics | `Services.analytics` | Services suite | Finalize funnel (§6.13) |
| Persistence v2, leases, retries | `Persistence`, `Profile` | 17 persistence + lifecycle tests | **v3** (§6.15) |
| Client HUD, combo, tags, encounter visuals, results, 7-tab menu | `Client`, `Ui`, `Effects`, `Menu` | client API/layout tests, headless G | Keep; progressive tabs, podium, trial, cosmetics |
| Audio | 6 original WAVs (`assets/audio`, not uploaded); unverified built-in fallbacks; no music in-game | generator `--verify` | **Expand** set + owner upload (§6.3.4) |
| World | 3 procedural arenas (same layout), 12 procedural creatures, records boards, canyon lanes, per-arena colour grade | headless boot, API checks | Layout variants, ambience, sky tone |
| Creature motion | Server PivotTo on welded roots at 10 Hz, bob/tilt only | — | **Replace** with herd replication v2 |
| QA tooling | `run_checks.py` (44 checks), lint, API names, headless engine (9 scenarios), economy model | 44/44 | Extend per phase |

---

## 5. Architecture rules for this sprint

- **Server authority is unchanged.** Clients render; the server decides catches, scores, rewards and saves. Clients never send positions, targets, scores or amounts.
- **Extract only what you touch.** New logic lands in small modules with pure, testable cores. Do not refactor broadly.
  - New shared modules: `Cycle.luau`, `HerdNet.luau`, `Trial.luau`, `Cosmetics.luau`.
  - New server module: `TrialService.luau`.
  - New client modules: `CreatureView.luau`, `Podium.luau`.
- **Main.server.luau stays the orchestrator.** Each phase should leave it no larger than about 1,400 lines by moving new logic into modules.
- **Profile v3 lands once, in Phase 1**, with every field this plan needs. Later phases only use those fields.
- **Every phase ends green:**
  - `python3 tools/run_checks.py` passes;
  - new pure suites plus new or updated headless scenarios cover the phase;
  - commit, push, and verify the remote ref.
- **No new third-party code or assets.** Use procedural geometry, built-in textures and original synthesized audio only.

---

## 6. System specifications

Each system lists four things: the intended **player experience**, **integration** points in the existing code, **dependencies**, and **acceptance** tests (offline tests prove logic, Studio tests prove feel). It is complete when every acceptance item passes.

### 6.1 Synchronized Stampede Cycles, intermission and podium (Phase 1)

**Experience.** Everyone in an arena shares one 2-minute cycle: 110 s of play, then a 10 s intermission.
- All players hear "3-2-1 STAMPEDE!" together.
- All players face the golden finale in the same final 25 s and hit the buzzer at the same moment.
- During intermission they see a podium of positive awards, then auto-start the next stampede.
- Late joiners play immediately: a **partial round** if 40 s or more of play remain, otherwise a **warm-up** (free catching, starters and practice, no score or hazards) until the next cycle. Nobody waits more than 10 s.

**Rules (pure, in `Cycle.luau`).**
- `CYCLE=120`, `PLAY=110`. Phase is derived from the shared arena clock (`os.clock()-arenaEpoch`).
- A round is **full** if the player was present at cycle start (within 3 s); otherwise it is **partial**.
- Records, PB splits, medal-based unlocks (Heat) and achievements that depend on records count only for **full** rounds. Glow, XP, album, quests and goals count for all rounds.
- **AFK fix.**
  - A round counts as "completed" (completion XP, rounds metrics, goals) only with 3 or more catches.
  - `roundXp` gives the +60 completion bonus only in that case.
  - Two consecutive rounds with no input auto-toggle **Sit out** (a spectator with no rewards), cleared by any input or the Play button.
- Arena travel and loadout/Heat changes are allowed in intermission and warm-up only.

**Integration.**
- `Main.server.luau`: `beginRound`/`settleRound` move to cycle boundaries; `s.started` and the new `s.endsAt` replace `Config.RoundSeconds` arithmetic; `roundPlaying` uses `s.endsAt`. Replay becomes automatic and the `Replay` action becomes `SitOut`/`Play`. Players register in a CollisionGroup that does not collide with itself.
- `Encounters.Cycle` and `ArenaEvents` phase math move to 120 with no events in 110–120. `Challenge.checkpoint` takes arena time.
- `Profile` v3 adds `settings.showOnPodium`.
- `Client`: intermission UI, countdown, podium panel (`Podium.luau`), Sit-out toggle.

**Podium awards.** Computed at 110 s from sessions that played this cycle in the arena. Up to three awards with distinct winners where possible:
- Top Parade (score);
- Longest Chain;
- Golden Catcher;
- Best Flanker (assists + herded);
- Static Buster (pops).

Players with `showOnPodium=false` are skipped. A solo player sees "Your highlights". Ties break on score, then userId.

**Dependencies.** None; this comes first because Daily Stampede, hints and the podium build on it.

**Acceptance.**
- `tests/SparkCycle.spec.luau`: phase math at every second; partial/warm-up thresholds; the full-round flag; buzzer and golden alignment for every join offset.
- Integration harness:
  - settlement at the cycle end;
  - partial rounds never write records;
  - AFK rounds give no completion XP and no goal credit;
  - Sit-out stops rewards;
  - the auto-start at 120 s.
- New headless `ScenarioI_SyncedCycles`: four players join at 0/30/80/105 s and get aligned results; there is one podium; the warm-up player is scoreless; no API errors.
- Existing scenarios C/D/E are updated.
- Studio: the countdown, finale and podium feel shared; no player waits more than 10 s.

### 6.2 Herd replication v2 and living creatures (Phase 2)

**Experience.** Creatures move smoothly at the client's frame rate and look alive:
- hop, glide or wobble by silhouette;
- blink;
- lean into turns;
- a "!" pop when startled;
- spin when dazed;
- golden ones shimmer.

Catches feel physical: the creature squashes, arcs into your parade with a sparkle trail, then follows you.

**Design.**
- **Server.** The server keeps logical positions in `herd` as now, but stops moving models after the spawn `PivotTo`. Each 0.1 s tick it broadcasts per-arena packets on a new `UnreliableRemoteEvent` "HerdNet", only to players in that arena (trial players get their own personal packets, §6.4). Starter, trial and static ownership semantics are unchanged.
- **Packet** (`HerdNet.luau`, pure pack/unpack with Luau `buffer`):
  - header: u8 version, u8 arena, u16 count, f32 server clock;
  - per creature, 10 bytes: u32 id, i16 x×10, i16 z×10 (arena-relative), u8 heading, u8 flags (fleeing, dazed, golden, runner, startled).
  - Packets over 900 bytes are split.
- **Client** (`CreatureView.luau`):
  - interpolates between the last two snapshots with a 100 ms delay and holds through packet loss;
  - runs procedural animation states per silhouette family;
  - full animation within 90 studs, position-only updates (10 Hz) beyond;
  - reduced motion turns off bounce, lean and blink.
- **Catch flight.** The client spawns a pooled miniature at the creature's last rendered pose and tweens it to the player over 0.35 s, which hides the server destroy.

**Integration.**
- `Main` herd loop: remove the per-tick `c.model:PivotTo` and add the packet broadcast.
- `Effects`: catch flight and startle pops.
- `Client`: wire `CreatureView`.
- The aim preview reads rendered positions; the authority difference stays within one interpolation window.
- `World` keeps welded roots, so the client moves one CFrame per model.

**Dependencies.** None; runs in parallel with Phase 1 code areas except the `Main` heartbeat (do it after Phase 1 merges).

**Acceptance.**
- `tests/SparkHerdNet.spec.luau`: round-trip pack/unpack, quantization error at most 0.05 studs, split under 900 bytes for 120 creatures, malformed buffers rejected.
- Headless engine gains `UnreliableRemoteEvent` and buffer support plus a payload-size check. A new scenario confirms packets reach only same-arena players and that client models track server positions within 2 studs at a 100 ms delay.
- Budget: packet bytes per client per second at most 6 KB with 45 creatures.
- Studio: visibly smooth motion at 60 fps; Network stats confirm the bandwidth drop; no creature visibly lags catches.

### 6.3 Presentation and feel pass (Phase 3)

#### 6.3.1 Moment-to-moment juice (client, `Effects`/`Ui`)

**Bank.**
- A fountain of the banked miniatures pours into the ring, with a confetti `Emit(n)` burst.
- The HUD glow counter counts up (NumberValue tween).
- The first discovery of a species shows a **"NEW SPARK!" album card**: silhouette, name, trait and signature hint (2 s, bottom-left).

**Chain tiers.**
- A thin ring under your character changes per tier: x2 mint, x3 gold, x4 "STAMPEDE" prism.
- The combo meter pops on each tier-up; the tier-up sound pitch rises.

**Golden finale.**
- A golden light pillar (Beam) shows above each golden spark across the arena.
- A finale banner appears and the music adds its finale layer.

**Hits.**
- On a ZAP tag, the scattered sparks visibly pop out on arcs.
- A gentle 0.3 s desaturate pulse plays (no flash, no shake; off in reduced motion).

**Round beats.** Countdown, "STAMPEDE!" whistle, "15 s" warm-tone timer, buzzer horn, "TIME!".

**Caps.**
- 80 transient parts;
- 300 particles/s;
- 30 BillboardGuis;
- scaled down when `UserGameSettings.SavedQualityLevel` is 3 or lower.

#### 6.3.2 UI quality and progressive disclosure (`Menu`, `Client`)

**Style tokens.**
- One palette (ink, paper, gold, mint, purple, warm), 14 px corners, 2 px strokes, Gotham Bold/Black.
- Touch targets of at least 44 px.
- Numbers always animate; no static jumps.

**Progressive tabs.**

| Tab | Revealed |
| --- | --- |
| Album, Settings | From the start |
| Play | After the first round |
| Goals | After round 3 |
| Upgrades | At the first 40 glow |
| Style | At rank 3 or the first affordable trail |
| Records | After the first full round |

The menu button shows a "!" badge only when something new or claimable exists.

**Progressive HUD.**
- Combo meter on the first 2-chain;
- rank chip after round 1;
- event line after the first bank.

**Photo mode.** H key or Settings toggle hides the HUD, for capturing thumbnails.

#### 6.3.3 World identity (`World`, client grade)

- Per-arena ambience emitters at the rim (Meadow petals, Canyon dust motes, Aurora light ribbons), bounded and off in reduced motion.
- A per-arena `Atmosphere`/sky tint set locally alongside the existing colour grade.
- Landmark clarity: the bank beacon is the tallest gameplay object; the gate and lanes are readable from the spawn.

#### 6.3.4 Original audio set (`tools/generate_audio.py`, `AudioCatalog`)

**Generate deterministically.**
- New cues:
  - gameplay: `zap`, `pop`, `gate_open`, `golden_spawn`, `golden_catch`, `stampede_rumble`, `chain_tier`;
  - round beats: `countdown`, `start_whistle`, `buzzer`;
  - UI: `rank_up`, `ui_click`, `ui_claim`.
- Three seamless arena music loops (Meadow bright pop, Canyon funky, Aurora synth), each with a finale intensity layer.
- Levels: peaks at or below −1 dBFS, cues 6–9 dB under the music bus, no harsh highs above 10 kHz.

**Upload and wire.**
- `tools/set_audio_ids.py` writes owner-provided asset IDs from a JSON mapping into `AudioCatalog`, so nobody edits it by hand.
- The client music manager crossfades arena loops and fades in the finale layer at 85 s.
- Built-in fallbacks stay only until upload.

**Dependencies.**
- 6.3.1 needs Phase 2 (miniature pooling, creature poses).
- 6.3.4 needs the owner to upload before release (B-03).

**Acceptance.**
- Client API and layout tests extended (15 layouts, plus the podium and album card).
- `generate_audio.py --verify` covers every new file (peaks, DC, loop seams, hashes).
- Headless G: tab reveal schedule; badge logic.
- Studio: owner Checkpoint B judges the first 30 s as "feels good"; audio is balanced on headphones and phone speaker.

### 6.4 Daily Stampede — seeded solo trial (Phase 4)

**Experience.**
- A 75-second solo run in the **Trial Grounds**, the same for every player that UTC day: same spawn plan, same encounter, same golden moment and the same **normalized rules**, so upgrades and perks give no edge [M1].
- Instant retry. Ghost splits against your best ("+120 vs best").
- Today's top 10 shows in the Play tab and on every arena's records board.
- First completion each day: +40 glow and +80 XP.
- Later runs: XP (`floor(2·√score)+20`) for up to 5 runs/day, then leaderboard-only.
- It unlocks after round 2, with an "available" toast.

**Rules (pure, in `Trial.luau`).**
- `seed = hash(day)`. The day's palette and biome rotate meadow → canyon → aurora.
- 20 personal sparks from the biome's species, with seeded positions and respawn sequence.
- One encounter: gate (meadow), one Stampede Run at 30 s (canyon), or Starfall (aurora, falling back to gate if Starfall is cut). A golden at 50 s. Statics cap 2 from 15 s. No sweep.
- Normalized stats (fixed table): radius 11.5, capacity 10, dash cooldown 2.3, capture cooldown 0.65, chain 6 s with step 5 and x4 cap, dash-through limit 3.
- Trial medal thresholds are calibrated by the economy model (initial 300/800/1600/2800).
- Score sanity cap: theoretical maximum from run length, capture interval and maximum style.

**Integration.**
- `World.buildTrialGrounds(palette)` at x = 900, repainted on day rollover.
- `TrialService.luau`:
  - session `mode="trial"`;
  - creatures carry `trialOwner` (owner-only capture and visibility, like starters);
  - personal `Random.new(seed)`;
  - personal encounter schedule from trial elapsed time.
- `Main`: actions `Trial` {start, retry, leave}; `Rules.canCapture` excludes non-trial creatures in trial mode and trial creatures outside it.
- `Services.leaderboard`: `SparkDaily_<day>_v1` board, written only on run end when the score improves and the session's movement-rejection rate is below the threshold.
- Profile v3 `trial` block.
- Client: Play-tab card, trial HUD (splits), trial results with Retry/Leave.
- Other trial players are visible at 50% transparency; their sparks are hidden.

**Dependencies.** Phase 1 (cycles, so trial sessions are excluded from arena cycles), Phase 2 (personal packets).

**Acceptance.**
- `tests/SparkTrial.spec.luau`:
  - same day gives the same spawn plan and schedule;
  - different days give different plans;
  - normalized stats ignore upgrades and perks;
  - the reward is once per day; the XP cap holds;
  - the score cap rejects impossible values.
- Headless `ScenarioJ_DailyStampede`: two players run the same day and get identical spawn plans; leaderboard ordering; retry; leaving mid-run returns the player to the arena cycle.
- Economy model: trial archetypes calibrate thresholds (regular median roughly Silver).
- Studio: trial loads in under 1 s and retry is instant; the board updates.

### 6.5 First-session sequence (Phase 3, with Phase 1 hooks)

Specified in §7. Integration points:
- `issueStarters` gains a **dash practice line**: 3 slow owner-only sparks in a row, issued after the first bank.
- `Profile.flags.seenHints` persists coaching so hints never repeat.
- Brand-new players (`rounds==0`) get no sweeps or statics in round 1; sweeps start in round 2, statics in round 3.
- The results screen shows the "Choose your first perk" CTA at rank 2.

**Acceptance.**
- Harness:
  - a fresh profile gets the practice line once;
  - no hazards in round 1;
  - hints shown once across a rejoin.
- Headless B extended to measure join → first catch → first bank → first dash-through, all under 40 s with the bot (not human timing).
- Studio and human comprehension tests are owner-led (B-02).

### 6.6 Species Signatures — collection meets skill (Phase 6)

**Experience.**
- Every species has a signature technique, shown on the aim cue ("◆ DASH IT!") and its album card.
- A signature catch gives +50% of that catch's style (minimum +15) and a SIGNATURE tag.
- Album stars per species at 10, 25 and 50 signature catches.
- Titles: "Signature Collector" (12 bronze), "Spark Sage" (12 gold).
- Each species stops being "a value number" and becomes a little skill puzzle [C5] [H].

**Mapping** (`Config.Creatures[].signature`):

| Behaviour | Signature | Condition |
| --- | --- | --- |
| flee (Bunvolt, Zip Tail, Starwhirl) | DASH | dash catch or dash-through |
| zigzag (Flutterwink, Prism Prickle, Ribbubble) | PRECISE | precision catch |
| herd (Cubloom, Sunshell, Crownlet) | TOGETHER | multi-catch or herded |
| wander (Pip Pop, Dune Fin, Antlume) | RHYTHM | catch while the multiplier is x2 or higher |

**Integration.**
- `Challenge.capture` accepts `signature=true` and applies the bonus.
- `Main.claim` decides the flag from the species and catch kind.
- Profile v3 `signatures`.
- `Progression` achievements and titles.
- `Menu` album stars; `Effects`/aim cue icon.

**Acceptance.**
- Depth suite: bonus math; flag only for matching kind; no starter signatures.
- LongTerm: star thresholds and titles.
- Harness: each behaviour's signature path.

### 6.7 Rank-reward density and cosmetic categories (Phase 5)

**Experience.**
- Every rank-up shows a reward card.
- Every fifth rank from 25 to 45 gives a premium cosmetic; rank 50 gives Legend Stream.
- Social flex is visible to everyone: your **Parade Formation** (how carried sparks follow you), your **Bank Burst** (the celebration others see when you bank) and your **Name Tag** style.

**Content** (`Cosmetics.luau`, pure catalog):
- **Formations (6):** Line (default), Zigzag, Orbit, Pair Wave, Heart, Crown. The client renders the existing parade followers; the formation id replicates via a player attribute.
- **Bank Bursts (8):** Confetti (default), Stars, Bubbles, Petals, Hearts, Rings, Ribbons, Glitter Rain. All use built-in particle textures; no strobing.
- **Name Tags (10):** default plus 9 colour/frame styles, 3 of them achievement-only (Gilded, Radiant, Legend).

**Rank reward table.** Ranks 2–50 each map to exactly one reward:
- the existing perks, slot and rank trails;
- formations, bursts or tags;
- 4 "Glow Gift" filler ranks at most (`rank×25` glow).

**Economy.**
- Priced items add about 60,000 glow of guaranteed-price sinks.
- The model must show regular-player sink exhaustion at 25 h or later (up from about 14 h). Update `GAME1_ECONOMY.md` and the `SparkEconomy` bounds.

**Integration.**
- `Progression.unlocksBetween` reads the table.
- Equip action `Style` gains `{category,id}`.
- `Main.applyStyle` handles name tags.
- Bank feedback broadcasts `{burst, position}` to the arena.
- `Menu` Style tab has category sub-tabs.

**Acceptance.**
- LongTerm: no empty rank-up across 2–50; every cosmetic is obtainable; prices are guaranteed; v3 round-trip.
- Economy bounds updated.
- Client API test covers new instances.
- Studio: formations and bursts are readable and not cluttered with 4 players.

### 6.8 Arena identity v2 (Phase 6)

#### 6.8.1 Aurora Starfall (replaces Aurora's Spark Gate)

**Experience.**
- During arena time 55–85, six star impacts land every 5 s.
- Each impact is a telegraphed circle (radius 6) with a 2 s warning, placed near spark clusters (server RNG), at least 24 studs from the bank.
- Sparks inside at impact are **dazed** for 3 s (stop and spin).
- Catching a dazed spark scores **STARSTRUCK** +30 style (multiplied by the chain).
- Positive-only: no player damage. It rewards prediction and positioning.

**Integration.**
- `Encounters.starfall(elapsed, biome, candidates)`, pure.
- `Main` herd loop: `c.dazedUntil` skips movement; `claim` passes a `dazed` flag to `Challenge`.
- `Effects` circles; HerdNet dazed flag.

**Acceptance.**
- Depth suite: schedule once per cycle for every join offset; clearances.
- Harness: daze freezes, bonus applies once.
- Headless: no instance growth.

#### 6.8.2 Per-arena obstacle layouts

| Arena | Layout |
| --- | --- |
| Meadow | Keeps 4 islands (readable tutorial) |
| Canyon | 6 rock pillars in two rows framing the Stampede lanes |
| Aurora | 5 crystal pillars in a pentagon (radius 30) |

**Integration.**
- `World` returns `arena.obstacles` {x,z,r}.
- `Main` herd avoidance and `Encounters` clearances read obstacles per arena instead of the hard-coded `±26.163` islands.
- Depth tests become per-arena.

**Acceptance.**
- Clearance tests per arena (gate, lanes, starfall, spawn, bank).
- Headless boot shows distinct obstacle sets.
- Studio: no collision dead ends; the camera never clips.

### 6.9 Goals, Remix and return reasons (Phase 5 / Phase 7)

#### 6.9.1 Daily goals

- Three goals:
  1. a play goal from the pool;
  2. a second play goal;
  3. "Finish today's Daily Stampede".
- The pool is re-tuned so each play goal completes within about 3–4 normal rounds.
- One free reroll of a play goal per day.
- The **results screen surfaces "Claim"**.
- Rewards are unchanged (30 glow + 60 XP; set bonus 50).
- No streaks, no expiry pressure, no paid skips [N3].

#### 6.9.2 Weekly goals

Three from the pool; one is tied to the active Remix when one is live.

#### 6.9.3 Weekly Remix (launch-desirable)

A deterministic per-ISO-week, server-wide modifier, shown in the HUD event line and the Play tab. Chosen so it never makes the game harder for newcomers:

| Remix | Effect |
| --- | --- |
| Golden Rush | +2 goldens at the finale |
| Big Herd | +6 base sparks per arena |
| Rhythm Week | Chain window +1 s |
| Stampede Season | One Stampede Run in every arena |
| Starfall Everywhere | Starfall in every arena |
| Fizz Festival | Static pops ×2, statics only for Heat 1 and above |

**Integration.**
- `Config.Remixes`;
- `Encounters`/`Main` hooks behind a single `remix(now)` lookup;
- the Remix goal in `Progression.WeeklyPool`.

**Acceptance.**
- Week → remix determinism.
- Each remix's effect is bounded.
- Every remix keeps the A2 "each encounter once per round" property where applicable.

### 6.10 Social, fairness and competition (Phase 1 / Phase 4 / Phase 7)

**Contested-catch assists.** When player B catches a spark that player A spooked within 1.5 s and within 8 studs, A gets ASSIST +15 style. This uses the existing `creditAssist` with a stricter window and turns "stealing" into teamwork [N5].

**Non-collision.** A `SparkPlayers` CollisionGroup (`PhysicsService:RegisterCollisionGroup` and `CollisionGroupSetCollidable(group, group, false)`), so nobody can body-block the bank or gate.

**Podium.** Positive awards only (§6.1). No ranked list of losers. The numeric session table remains opt-in (`settings.competition`).

**Public leaderboards.** Daily Stampede only (daily top 10 + personal best).
- Normal rounds keep personal records per arena×heat and the per-server podium.
- `Services.leaderboard` keeps its interface; board names change.

**Invite.** An optional "Invite friends" button (`SocialService:PromptGameInvite`) in Settings. No reward for inviting (AGENTS: no required friend invitations).

**Acceptance.**
- Harness: assist only within the window; never to the catcher; finished sessions excluded.
- Headless D: no player-player collision group pairs collide.
- Services suite: daily board names and day rollover.

### 6.11 Accessibility and controls (Phase 3)

| Feature | Behaviour |
| --- | --- |
| Hold to catch | Setting; hold E/X/CATCH. Fires only when the client aim preview shows a target, at the server cooldown. Removes button-mashing and accidental misses on mobile. The server still validates everything. |
| UI scale | 0.85 / 1.0 / 1.15 (`UIScale` on `SparkHUD`) |
| Volume | Separate music and SFX sliders (replacing on/off) |
| High-contrast targets | Thicker, always-on-top aim outline and gate ring |
| Existing | Reduced motion and colour + shape + text cues stay. Every new effect obeys reduced motion. |

**Acceptance.**
- Client tests:
  - hold-to-catch never fires without a target;
  - settings persist via v3;
  - UIScale is applied in all 15 layouts.
- Studio: touch hold works; gamepad holds X.

### 6.12 Security and anti-exploit (Phase 8, plus per phase)

- **New actions** (`SitOut`, `Play`, `Trial`, `Style{category}`, `Reroll`) are type, length and rate validated through the existing transport limiter with their own buckets.
- **Leaderboard writes:**
  - only from server-finished trial runs;
  - score at or below the theoretical maximum;
  - movement-rejection rate below the threshold;
  - one write per improvement.
- **Exploit telemetry.** Per-session counters (movement rejections, rate-limit hits). Aggregated into an analytics custom event per session, with no per-violation spam.
- **HerdNet** is server-to-client only; the client never sends herd data.

**Acceptance.** Headless H gains new-action abuse cases. Trial-score and leaderboard abuse cases are added to the Services and Trial suites.

### 6.13 Analytics (Phase 8)

**Onboarding funnel.** Freeze the order before launch:

| Step | Event |
| --- | --- |
| 1 | join |
| 2 | first_catch |
| 3 | first_bank |
| 4 | first_dash_through |
| 5 | first_round_complete |
| 6 | second_round_start |
| 7 | first_perk_equipped |
| 8 | first_daily_stampede |

**Custom events.** `trial_run` (score bucket), `podium_award`, `remix_week`, `heat_round`, `signature_catch`, `sit_out`, `reduced_motion_on`, `hold_catch_on`, exploit counters.

**Progression events.** `LogProgressionEvent` for rank-ups.

**Economy.** Existing source and sink events.

**Acceptance.** The Services suite verifies call shapes. Real dashboards are checked only after a private published test (owner).

### 6.14 Performance budgets (Phase 8, measured in Studio at Checkpoint C)

| Budget | Target |
| --- | --- |
| Server instances (steady) | ≤ 4,500 |
| Herd size | ≤ 80 per arena |
| Client transient effect parts | ≤ 80 |
| Particle emission | ≤ 300 particles/s |
| Active BillboardGuis | ≤ 30 |
| Network per client | ≤ 25 KB/s steady (herd ≤ 6 KB/s, state ≤ 2 KB × 2/s) |
| Frame time | ≤ 16.7 ms on a mid desktop; ≤ 33 ms on a low-end phone during a 4-player finale |
| Soak | No instance or memory growth over 20 cycles with 4 players |

**Acceptance.** Headless soak extended to 20 cycles × 4 players with instance-count assertions. A debug overlay (Studio only) shows counts. Real device numbers come from the owner (B-07).

### 6.15 Persistence — Profile v3 (Phase 1)

New fields, all defaulted and sanitized:
- `cosmetics` {owned, formation, burst, tag};
- `signatures` {species → count};
- `trial` {day, best, runsToday, rewardedDay, bestRun};
- `flags` {seenHints{...}, firstSessionDone};
- settings `showOnPodium`, `holdCatch`, `uiScale`, `musicVolume`, `sfxVolume`, `highContrast`.

Migration and limits:
- v1 and v2 migrate to v3; v4 and above are refused without overwrite.
- Profile size stays under 20 KB, asserted in tests.

**Acceptance.**
- LongTerm and Profile suites: v1→v3 and v2→v3 migrations; malicious v3; lossless round-trip; size bound.
- Persistence suite is unchanged and green.

### 6.16 Publishing preparation (Phase 8 agent work, plus owner)

**Agent work.**
- Store copy v3 (only verified mechanics).
- Thumbnail and icon shot list using photo mode.
- Trailer storyboard v3: dash-through, shared golden finale, podium, Daily Stampede.
- Asset provenance sheet for generated audio.
- Release manifest draft.
- Updated playtest guide and release checklist.

**Owner work.** Upload audio, create badges (optional), complete the experience questionnaire and maturity label, capture media, run a private 5–10 friend beta, G4 playtest, G5 publish decision. See §17.

---

## 7. Distinctive first-session sequence

Targets: interactive feedback 10 s or less, first reward 20 s or less, a "wow" by 40 s, comprehensible loop by 60 s, first complete round by 2 min [P3]. Times are design targets; real timings must be measured with humans.

| Time | What happens | Driven by |
| --- | --- | --- |
| 0 s | Spawn facing 3 glowing starters 8 studs ahead. Only the objective ("CATCH 3 SPARKS"), CATCH/DASH buttons and glow are visible. If the cycle is in warm-up or intermission, a small "Stampede starts in N s" chip shows, but starters are catchable immediately. | `issueStarters`, progressive HUD, `Cycle` warm-up |
| ~3–10 s | First catch: the spark squashes, arcs into your parade, a sound plays, and the **NEW SPARK! card** shows its name and signature hint. | Phase 2/3 catch flight, album card |
| ~10–20 s | Third catch → "BANK at the glowing gate" with a ground arrow trail. The bank fountain plays and glow counts up. | Bank guide, bank juice |
| ~20–40 s | **Dash practice line**: 3 slow owner-only sparks in a row near the bank with a dashed lane: "DASH THROUGH THEM!" Success shows MULTI x3. If missed, the line re-forms once, then disperses after 20 s. | `issueStarters` practice line, `dashSweep` |
| ~40–60 s | Free catching. On the first 2-chain the combo meter appears with "Catch again within 6 s to CHAIN". The first encounter seen gets one coaching line. | Progressive HUD, persistent hints |
| End of round 1 | At 15 s left: "Bank before the buzzer to keep your bonus". Shared golden finale; buzzer. A partial round under 40 s shows "Warm-up complete" instead of a medal. | `Cycle`, buzzer hint |
| Intermission | Results: medal, XP bar fills to **rank 2**, then **"Choose your first perk"**, which opens the Play tab with one recommended perk. Podium highlights; auto-start countdown. | Results CTA, podium |
| Round 2 | Sweeps introduced (hint). Toast: "Today's Daily Stampede is ready". | §6.1 staging, §6.4 |
| Round 3 | Statics introduced (hint). Goals tab revealed; often one daily is already complete → claim moment. | Staging, progressive tabs |
| End of session 1 | Goals/results show tomorrow's reasons to return: a new Daily Stampede, new goals and the next unlock teaser (next perk rank, Fizz Canyon at 30 banked). No streak. | Goals, results teaser |

---

## 8. Difficulty and mastery progression

| Stage | Typical time (regular, modelled) | New challenge or ability | Mastery expressed |
| --- | --- | --- | --- |
| Round 1 | 0–2 min | Starters, bank, dash-through practice, chains | Basic movement, first multi-catch |
| Rounds 2–3 | 2–7 min | Sweeps, then statics | Dodging; popping with a dash |
| Canyon unlock (30 banked) | ~5 rounds | Stampede Runs, lane geometry | Lining up fast herds |
| Ranks 2–14 | 0–2 h | One perk per unlock with a "try this" tip | Loadout choices with trade-offs |
| Aurora (90 banked) | ~10 rounds | Starfall, earlier statics | Prediction and positioning |
| First Silver | 1st–80th round | Heat 1 | Opt-in pressure |
| Rank 15 | ~2 h | Third perk slot | Build synergy |
| Daily Stampede | Daily | Fixed seed, normalized rules | Route optimization, fair comparison |
| Heat 3–5 | Days–weeks (experts) | More statics, tighter windows | Expert routing under pressure |
| Signatures 12×50 | Weeks | Per-species techniques | Full technique repertoire |
| Gilded 12, Radiant, rank 50 | 8 h / 2–4 h / ~30 h | Collection depth | Long-term completion |

**Fairness rules.**
- New threats are always telegraphed and introduced with one hint.
- Heat is opt-in and personal.
- Shared encounters are opportunities, not punishments.
- No mechanic removes saved progress.
- Latency tolerance:
  - dash path radius 4.5 studs;
  - aim preview uses the same geometry as the server;
  - no frame-perfect windows;
  - hit and assist windows of 1.5–4 s [N6].

---

## 9. Sustained enjoyment without exploitative grinding

| Loop | Length | Content | Guardrail |
| --- | --- | --- | --- |
| Moment | 1–6 s | Catch → chain → dash-through → bank decision | Misses cost only unbanked bonus |
| Round | 2 min | Shared arc → podium | Partial rounds still reward; AFK earns nothing |
| Session | 10–40 min | Rounds + Daily Stampede + goals + unlocks | No energy, no timers |
| Daily | 5–30 min | Daily Stampede + 3 goals | No streaks; missing a day costs nothing |
| Weekly | — | Remix + weekly goals | Remixes are never harder for newcomers |
| Long | Weeks | Rank 50, Heat ladder, album tiers, signatures, Gilded, cosmetics | Sqrt XP; every rank rewards; cosmetics only |

**Anti-grind rules (enforced by tests).**
- Experts progress at most 3× faster than novices.
- No reward depends on idle time.
- The Daily Stampede XP cap (5 runs) prevents farming one mode.
- Glow never buys power.
- Every currency sink is a guaranteed-price cosmetic.

---

## 10. Social and optional competition

- **Co-op that matters:**
  - flanking assists (gate and contested catches);
  - Arena Rally;
  - herd density scaling, so more players means more sparks, not less each;
  - shared golden finale and podium as social glue [C7] [H].
- **Laughs without griefing.** Scramble re-catches, the golden contest, podium awards ("Static Buster"), formations and bank bursts for showing off. No PvP, no knockback, no stealing banked progress [N2].
- **Competition.**
  - Opt-in numeric session scores.
  - Public Daily Stampede board (normalized and seeded).
  - Personal records per arena×heat.
- **Kindness rules:**
  - no "last place" display;
  - awards spread across categories;
  - `showOnPodium` opt-out;
  - no chat features beyond Roblox's own;
  - no required friends or invites.

---

## 11. Polish and presentation quality bar (launch gate)

A build is **not** release-candidate if any line below fails in Studio:

| Area | Requirement |
| --- | --- |
| Creatures | Smooth motion (interpolated), silhouette-specific idle and move animation, blink, startle pop, catch squash and flight, golden shimmer and beacon |
| Player | Chain-tier ring, trail cosmetics, readable name tags, parade formation following without jitter |
| Feedback | Every scored event shows a tag, a sound and a number pop. Bank shows a fountain and count-up. First discovery shows the album card. |
| Round beats | Countdown, start whistle, 15 s timer tone, finale banner and music layer, buzzer, podium |
| UI | Consistent tokens; no text clipping at 15 layouts; progressive tabs; animated numbers; 44 px touch targets; gamepad focus everywhere |
| Audio | Original uploaded set, balanced levels, no harshness, settings respected |
| World | Three arenas distinct by layout, palette, ambience and encounter. Landmarks readable from spawn. No dead ends or invisible walls. |
| Comfort | No flashing or strobe, no screen shake; reduced motion disables all motion effects |
| Performance | §6.14 budgets met |

---

## 12. Negative player-feedback failure modes to avoid

| Failure mode | Evidence | Guard in this plan | Test |
| --- | --- | --- | --- |
| "Boring after an hour" | N1, N4 | Signatures, Daily Stampede, Remix, Heat, arena identity | Economy model; Studio playtests; post-launch D1/D7 |
| Grind and time gates | N4 | Sqrt XP, no energy, every rank rewards | Economy bounds; LongTerm no-empty-rank test |
| Weak rewards ("rank-up did nothing") | Audit: 32 empty ranks | Reward table §6.7 | LongTerm |
| Pay-to-win | N1, N4, C4 | Cosmetics only; monetization off | Code review; G5 policy check |
| Kill stealing | N5 | Assists, density scaling, non-collision | Harness + headless |
| Griefing or loss of earned items | N2 | No destructive interactions; only carried sparks scatter, re-catchable | Harness scatter tests |
| Unfair leaderboards | Audit | Daily Stampede normalized and seeded; sanity caps | Trial suite |
| Lag and performance collapse | N1 | HerdNet v2, budgets, soak | Headless soak; Studio Checkpoint C |
| Exploits | N1 | Server authority, validation, trial caps, telemetry | Headless H; Services/Trial suites |
| Repetitive updates | C8 | Remix rotation, species packs, seasonal sets | Roadmap §15 |
| Streak FOMO | N3 | No streaks or expiry pressure | Goals tests |
| Confusing first minute | P3 | §7 sequence, progressive disclosure | Headless B timings; human tests |
| Overwhelming menus | Audit | Progressive tabs and badges | Headless G |
| AFK farming | Audit | §6.1 AFK fix | Harness |
| Harsh audio or flashing | Charter | Level targets; no strobe; reduced motion | Audio verify; Studio |

---

## 13. Engine-validation requirements (cannot be done in cloud)

| ID | Requirement | Pass criterion | When |
| --- | --- | --- | --- |
| V1 | Install and read back all sources | Manifest hashes match; no Output errors on Play | Checkpoint A (now), B, C |
| V2 | Dash-through reliability | At least 80% of deliberate 3-spark lines produce at least 2 catches; tune the 4.5 radius if not | A |
| V3 | HerdNet smoothness and bandwidth | Smooth 60 fps motion; ≤ 6 KB/s herd traffic per client in Network stats | B |
| V4 | Presentation bar §11 | Owner judges the first 30 s as exciting; checklist all pass | B |
| V5 | Synchronized cycles with 2 and 4 clients | Shared countdown, finale, podium; no wait over 10 s; partial and warm-up rules hold | B/C |
| V6 | Daily Stampede | Same seed on 2 clients; instant retry; board updates | C |
| V7 | Audio | Every catalog ID plays; levels balanced on phone and headphones | C (after upload) |
| V8 | Real DataStores in a test universe | v1/v2→v3 migration; rejoin restore; daily board OrderedDataStore | C |
| V9 | Mobile and gamepad | 15 layouts on real devices; hold-to-catch; no clipping | C |
| V10 | Performance §6.14 | Numbers recorded on a mid desktop and a low-end phone | C |
| V11 | Soak and shutdown | 20 cycles × 4 clients; normal stop returns Studio to Edit; no process left running (supervised only) | C |
| V12 | Owner RC playtest (G4) | Owner notes; fixes retested | After C |

**Checkpoint A** should run now on the current build (`docs/GAME1_PLAYTEST_GUIDE.md`). It is non-blocking: Phase 1 starts immediately, and A's findings feed tuning. **Checkpoint B** follows Phase 3 and is blocking for feel tuning. **Checkpoint C** is the release-candidate QA matrix.

---

## 14. Implementation order for Opus

Each phase must end green, committed, pushed and verified. File ownership per phase avoids conflicts. If subagents are used, run them only on disjoint files within a phase (for example, client UI and pure-module tests).

| Phase | Scope | Main files | Depends on | Done when |
| --- | --- | --- | --- | --- |
| **1. Round architecture and fairness** | `Cycle.luau`; cycle-based lifecycle in `Main`; intermission; podium (`Podium.luau` client); Sit-out/AFK fix; completion rules; non-collision; contested-catch assists; staged hazard introduction; Profile v3 schema; `Encounters`/`ArenaEvents` cycle 120 | Cycle, Main, Encounters, ArenaEvents, Challenge (checkpoint arg), Profile, Progression (roundXp), Client results, Podium | — | §6.1 + §6.10 (assists, collision) + §6.15 acceptance; `ScenarioI_SyncedCycles` passes; 44+ checks green |
| **2. Living herd** | `HerdNet.luau`; server broadcast; `CreatureView.luau` interpolation and procedural animation; catch flight; harness unreliable remote and buffer support | HerdNet, Main heartbeat, CreatureView, Effects, Client, tests/engine | 1 | §6.2 acceptance |
| **3. Feel, UI, audio and first session** | Juice set; progressive tabs, HUD and badges; photo mode; accessibility (§6.11); practice line and persistent hints (§6.5); world ambience; audio generator v2 + `set_audio_ids.py` + music manager | Effects, Ui, Menu, Client, Main (practice line, hints), World, tools/generate_audio.py, AudioCatalog | 2 | §6.3, §6.5, §6.11 acceptance → **owner Checkpoint B** |
| **4. Daily Stampede** | `Trial.luau`, `TrialService.luau`, Trial Grounds, trial UI, daily board, records boards show daily top 5 | Trial, TrialService, World, Main (actions), Services, Client/Menu | 1, 2 | §6.4 acceptance |
| **5. Progression density and goals** | `Cosmetics.luau`; rank reward table; formations, bursts, name tags; Style categories; goals refresh (Daily Stampede slot, reroll, claim-on-results); economy model and bounds update | Cosmetics, Progression, Main (applyStyle, bank broadcast), Effects, Menu, economy model | 1, 4 | §6.7, §6.9.1–2 acceptance |
| **6. Collection meets skill and arena identity** | Species Signatures; Aurora Starfall; per-arena obstacles | Config, Challenge, Main, Encounters, World, Effects, Menu | 2, 5 | §6.6, §6.8 acceptance |
| **7. Weekly Remix** (desirable) | `Config.Remixes`, hooks, remix weekly goal, HUD | Config, Encounters, Main, Progression, Client | 6 | §6.9.3 acceptance |
| **8. Hardening and launch prep** | Security additions; analytics funnel freeze; budgets overlay; headless soak 20×4; store copy v3; trailer and shot list; release checklist; playtest guide v2; RUN_STATE | Services, Main, tests/engine, docs | all | §6.12–6.14, §6.16 acceptance; all checks green → **Checkpoint C** |

**Cut line if the sprint runs short** (cut from the bottom):
1. Phase 7 (Remix);
2. §6.8.2 (layouts);
3. §6.8.1 (Starfall; Aurora keeps the gate);
4. §6.6 (Signatures).

Never cut Phases 1–5 or 8.

**Feature freeze** after Phase 8: only fixes until the owner RC playtest.

---

## 15. Post-launch roadmap (must not delay launch)

| Cadence | Update | Notes |
| --- | --- | --- |
| Week 1–2 | Hotfixes; tuning from analytics (funnel drop-offs, trial score distribution, glow/h) | Before adding content |
| Weekly | Remix rotation (data only) | Zero-code updates |
| Monthly | Species Pack: 3 new species, one per arena, each with a new behaviour (burrower, mimic, drifter) and a signature | `Config` + `World.creature` shape + one behaviour branch |
| Monthly | Earned cosmetic set (formations, bursts, trails) | Fixes long-tail glow surplus |
| Quarterly | Arena 4 with one new mechanic (Prism Portals or currents) | Data-driven obstacles make this cheaper |
| Seasonal | Event palettes and earned seasonal cosmetics; Daily Stampede "seasons" with cosmetic badges | No FOMO pricing |
| Owner-gated | Cosmetic-only monetization per `docs/GAME1_MONETIZATION_PLAN.md`; private servers; badges | Separate approval and policy review |

---

## 16. Rejected features (and why)

| Rejected | Reason |
| --- | --- |
| Trading | Scams, value inflation, moderation burden, emotional loss for kids [N2] |
| Eggs, hatching, pets with stats | Passive and gambling-adjacent; contradicts active-skill identity [P4] |
| PvP stealing or knockback | Griefing and toxicity [N2]; breaks pillar 6 |
| Rebirth or prestige resets | Erases meaningful choices (D5); our long tail is mastery and cosmetics |
| Hub or lobby world | Adds time before fun; arenas are the hub |
| AFK or auto-catch modes | Charter forbids passive grinding; discovery rewards real retention [C6] [P1] |
| Energy or stamina timers | Artificial time gates |
| Paid boosts, luck or skips | Pay-to-win and policy risk [P4] |
| Crafting or base building | Scope; dilutes the arcade loop |
| More arenas before launch | Polish beats breadth |

---

## 17. Owner actions (cannot be done by the agent)

1. **Checkpoint A now:** install the current build and follow `docs/GAME1_PLAYTEST_GUIDE.md` (non-blocking feedback).
2. **Allow research hosts** if primary-source verification is wanted: `create.roblox.com`, `about.roblox.com`, `devforum.roblox.com`, `www.roblox.com`.
3. **After Phase 3:** upload the generated audio set (Asset Manager), then hand over the ID JSON for `tools/set_audio_ids.py`. Run Checkpoint B.
4. **Before RC:** create badges (optional); complete the experience questionnaire and maturity label; set up a private test universe for real DataStores (V8).
5. **Checkpoint C plus G4:** RC QA matrix and your own playtest. A private 5–10 friend beta is recommended.
6. **G5:** publish and any monetization only by explicit decision.
