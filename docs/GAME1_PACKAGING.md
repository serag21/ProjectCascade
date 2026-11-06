# SPARK STAMPEDE — candidate packaging

Drafted 2026-10-25. Text and art direction are ready for implementation review. **This is not a completed media package and is not approved for publication.** No Roblox upload, paid asset acquisition or monetization is authorized by this document.

## Product promise

**Working title:** SPARK STAMPEDE

**Short pitch:** Dash, chase and collect a parade of sparks in colorful two-minute rounds.

**Proposed store description — publish only after corresponding features pass QA:**

> A herd of sparks is on the loose! Dash into bright arenas, catch mischievous creatures and bring your haul home.
>
> Chase moving herds, time your dash and discover a route that works for you. Catch twelve different sparks, fill your collection and earn upgrades for your next run. Explore three arenas with changing events and new creatures to master.
>
> Play solo or team up with up to three other players. Every round is a fresh chance to build your parade.
>
> Move. Dash. Catch. Bank. Go again!

### Revised description draft v2 (2026-11-04) — reflects the mastery/progression build

Use this only after the named features pass live QA (dash-through, statics, Spark Gate, Stampede Run, golden finale, perks, Heat, daily goals). Otherwise fall back to v1 above.

> A herd of sparks is on the loose! Dash into bright arenas, catch mischievous creatures and bring your haul home before the buzzer.
>
> Dash straight through a herd to catch several at once. Keep a chain going for bigger multipliers, pop fizzy static puffs, steer sparks through the drifting Spark Gate and race for the Golden Spark in the finale.
>
> Collect twelve sparks and their Glow, Prism, Radiant and Gilded forms. Rank up to unlock perks that change how you play, turn up the Heat for tougher runs, and chase your personal best in three arenas. Fresh daily and weekly goals — no streaks to lose.
>
> Play solo or team up with up to three friends: flank a herd together, share Arena Rallies, or opt in to compare scores.
>
> Move. Dash. Catch. Bank. Go again!

Monetization statement for the store page: none at launch. If the owner later approves monetization, only guaranteed, clearly priced cosmetics are proposed (see `GAME1_MONETIZATION_PLAN.md`); no paid random items, no paid power.

Do not add unsupported superlatives, scarcity claims, free-Robux implications, competitor names, fake review quotes or unverified performance claims. Replace the numeric claims if the approved candidate differs. Category/tag selection must reflect Roblox's available current fields at release, not a guessed API enum.

### Store description v3 (2026-11-05): reflects the final production plan build

**Status: draft.** Every sentence names a mechanic that is implemented and covered by offline tests (`docs/qa/latest-checks.json`). None of it has been played in Studio since Phase 1, so publish only after the named features pass Checkpoint C (V1–V12 in `BACKLOG.md`); otherwise fall back to v2.

> **A herd of sparks is on the loose, and everyone in the arena is chasing it.**
>
> Every two minutes a new stampede starts for the whole server. Dash *through* lines of sparks to catch three at once, keep your chain alive for x2, x3, x4 STAMPEDE, and bank your parade before the shared buzzer.
>
> Each of the 12 sparks has its own signature move: dash the bolters, get close to the zigzaggers, herd the huddlers, keep the rhythm for the wanderers. Earn signature stars, Prism and Radiant tiers, and golden versions of every spark.
>
> Three arenas, each with its own twist: herd sparks through the Spark Gate in Pop Meadow, dash the Stampede Runs in Fizz Canyon, and catch sparks dazed by the Aurora Starfall. Every round ends in a golden finale and a podium of fun awards.
>
> New every day: the **Daily Stampede**, one seeded course that is the same for everyone, with fair rules and a daily leaderboard. New every week: a **Remix** that shakes up every arena.
>
> Play solo or with up to three friends. No energy timers, no streaks, no pay-to-win. Move. Dash. Catch. Bank. Go again!

**Claims deliberately left out:** no trading, no pets with stats, no paid boosts, no "limited time only" pressure, no claimed player counts, and nothing about monetization (not authorized).

### Trailer storyboard v3 (30 s; capture in Studio with photo mode, `H`)

| Time | Shot | Proof on screen |
| --- | --- | --- |
| 0–3 s | Wide aerial of Pop Meadow as the countdown beats "3-2-1 STAMPEDE!" | Shared round start |
| 3–7 s | Third-person dash THROUGH a line of three sparks: "MULTI x3" tag, chain aura turns gold | Dash-through skill |
| 7–10 s | The parade trails behind in a Comet Vee formation, then a bank fountain and Bank Burst confetti | Visible flex |
| 10–14 s | Fizz Canyon Stampede Run: a dash timed into the lane | Arena identity |
| 14–18 s | Aurora Starfall: the telegraph ring, impact, dazed sparks spinning, "STARSTRUCK" | Arena identity |
| 18–22 s | Four players chase the shared golden finale; the buzzer hits "TIME!" | Social moment |
| 22–26 s | Intermission podium: Top Parade, Longest Chain, Golden Catcher | Positive competition |
| 26–30 s | Daily Stampede card and board ("Same course for everyone today"), then the logo | Return reason |

### Thumbnail and icon shot list (photo mode hides the HUD)

1. **Icon:** one Bunvolt mid-leap toward the camera on a soft meadow background, with a gold chain aura ring under it. Bright, a single subject, readable at 50 px.
2. **Thumbnail A (action):** a player avatar mid-dash, three sparks in a line with motion trails, and a "MULTI x3" tag.
3. **Thumbnail B (social):** four avatars around a golden spark at the finale, each with a different parade formation.
4. **Thumbnail C (arena):** Aurora Arcade during Starfall, the crystal pentagon and violet telegraph ring framing dazed sparks.

Use only original in-game captures, with no third-party characters or logos, and test legibility at 150 × 150 and 50 × 50 before upload (owner).

## Visual identity

Use luminous toy-like forms and rounded geometry, with a consistent face/eye language. Favor saturated coral, warm yellow and cyan separated by dark navy outlines or backing surfaces. Bright bank gates, a clear creature silhouette and a readable avatar should remain distinguishable in a small tile. Reserve bloom for local accents; do not wash out targets. Character poses and trails should communicate motion without flashing or implied violence.

The key composition is a player making a lateral dash around an expressive spark herd, with the bright banking gate visible. This communicates active skill, collection and destination in one frame. A pet close-up by itself risks advertising an idle collection game. Competitor characters, recognizable map arrangements and copied branding are prohibited.

## Candidate media inventory

| Artifact | Planned content | Current status |
| --- | --- | --- |
| Square icon master | One original expressive spark, two smaller distinct sparks, curved dash trail; minimal lettering | NOT CREATED |
| Wide thumbnail A | Actual arena, avatar mid-dash, three escaping silhouettes, visible bank landmark | NOT CREATED |
| Wide thumbnail B | Four players approaching a herd from different sides; actual multiplayer scene | NOT CREATED; requires multiplayer test |
| Wide thumbnail C | Three arena panels plus verified collection display; actual game materials | NOT CREATED |
| Gameplay stills | Spawn view, first capture, bank, full HUD, collection, each arena | NOT CAPTURED |
| 20–30 second trailer | Real gameplay sequence below | STORYBOARD ONLY |
| Audio provenance sheet | Every SoundId/file origin, license, uploader, usage, engine availability check | NOT COMPLETED |
| Release manifest | Commit, place identity, build file, hashes, test reports, known issues, rollback | NOT COMPLETED |

Author high-resolution square and wide masters; confirm the current [Roblox promotion documentation](https://create.roblox.com/docs/production/promotion) before final export/upload. Specific current image-file limits were not verified in this pass, so no guessed platform dimensions are treated as acceptance requirements. Do not confuse an attractive concept illustration with captured playable quality.

## Trailer storyboard (25 seconds)

| Time | Picture and actual action to capture | Sound / minimal overlay |
| --- | --- | --- |
| 0–3s | Spawn-facing herd; a spark reacts immediately; player begins moving | One inviting creature sound. “CHASE THE SPARKS” |
| 3–7s | Player lines up a herd and dashes THROUGH it: MULTI x2 tag, chain meter climbs | Actual dash/capture sounds; preserve readable controls. “DASH THROUGH” |
| 7–11s | Carry display grows; bank gate rewards the group | Actual reward sound and collection addition. “BANK YOUR HAUL” |
| 11–16s | Fizz Canyon Stampede Run lane crossing; Spark Gate herding in Pop Meadow; a static POP | Music rises gently; no strobe editing or artificial impact flashes |
| 16–18s | Golden finale: player catches the Golden Spark just before the buzzer | “GOLDEN FINALE” |
| 18–20s | Two/four real clients flank a herd through the gate (ASSIST tag) | “SOLO OR TOGETHER” only after multiplayer verification |
| 20–23s | Results: medal, rank-up, perk unlock; album gains a Gilded mark | Actual UI tick. “BUILD YOUR PARADE” |
| 23–25s | Replay pressed; another run begins; final title | “SPARK STAMPEDE” and one short music resolution |

Footage must come from the candidate commit. Do not speed up tedious progression to imply a false first reward time. Do not stage unsupported moves or show synthetic players as verified multiplayer. Use original/licensed music only, with actual audio review and an attribution entry.

## Capture procedure

1. Record commit, Studio/place identity, input mode and graphics settings. Use a disposable QA profile and remove identifying account details from public footage.
2. Capture the spawn view before input, first approach/capture, first bank and full round continuously for QA; keep this unedited evidence separate from edited promotional footage.
3. Capture each biome under its default and event lighting; check narrowest routes and highest-VFX moment.
4. Capture collection, upgrades, quests, settings and results at desktop and touch resolutions. Check text clipping, control overlap, contrast and safe areas.
5. Capture a true 2/4-client coordinated scene only after multiplayer cases pass. Preserve raw evidence with run IDs.
6. Review final thumbnails at tile scale and compare the depicted action/quality with playable build. Owner candidate review precedes upload.

## Release manifest fields

```text
candidate_name:
git_commit:
build_timestamp_utc:
place_id_and_owner:
studio_id_and_version:
source_of_truth_and_sync_method:
place_backup_path_and_hash:
reproducible_build_or_deploy_command:
qa_report_paths:
media_paths_and_hashes:
asset_provenance_path:
known_nonblocking_issues:
rollback_procedure:
owner_playtest_result:
public_publish_authorization:
monetization_authorization: disabled / not authorized
```

Packaging completion requires actual files, verified media and owner review. This document intentionally leaves unavailable artifacts unclaimed.
