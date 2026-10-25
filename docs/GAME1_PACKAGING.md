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

Do not add unsupported superlatives, scarcity claims, free-Robux implications, competitor names, fake review quotes or unverified performance claims. Replace the numeric claims if the approved candidate differs. Category/tag selection must reflect Roblox's available current fields at release, not a guessed API enum.

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
| 3–7s | Player flanks a moving group, dashes and captures | Actual dash/capture sounds; preserve readable controls |
| 7–11s | Carry display grows; bank gate rewards the group | Actual reward sound and collection addition. “BANK YOUR HAUL” |
| 11–16s | One distinct event in each of two other arenas; targets remain readable | Music rises gently; no strobe editing or artificial impact flashes |
| 16–20s | Two/four real clients corral a herd together, then show separate rewards | “SOLO OR TOGETHER” only after multiplayer verification |
| 20–23s | Album gains a new silhouette; earned upgrade changes the next run | Actual UI tick. “BUILD YOUR PARADE” |
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
