# Mastery loop — staged offline, October 28 PDT

The player now has two clearly separate rewards: permanent glow/collection and a round skill score. This slice is source-integrated and offline-tested; it has not been installed or rendered in Studio. No new playtest is authorized by this document.

- Catch within 4 studs while facing the creature (dot >=0.7): precision bonus.
- Catch within 0.55 seconds of a server-approved dash: dash-catch bonus.
- Catch ordinary creatures no more than 6 seconds apart to build a chain. Multipliers rise after three and six catches, capped at x3. Waiting expires the chain without deleting carried points.
- A missed capture or orange sweep breaks the chain and removes carried style bonus. Base catch points, banked score, collected creatures and glow remain safe. Full-pack prompts are not aiming misses. Recover on the next catch.
- Bank to secure score and the current challenge. Three goals rotate by completed round: precision catches, a six-catch chain, and banking a group. Later cycles increase targets up to difficulty 3. Each goal pays 100 skill once, never purchased currency.
- Gold/silver/bronze thresholds are 800/400/150 skill. Saved best score, best chain, per-arena records and completed-goal count provide long-term mastery targets. Old profiles get safe defaults without resetting collection.
- After 25 seconds of eligibility, players encounter a circular infield sweep: 2 seconds of warning, 4 active seconds, 8 rest seconds. Reaching three banked catches mid-round starts a fresh grace/warning timeline, never an active sweep. Bumps interrupt catching for 0.8 seconds; dash remains available. One marker, no flashes, no camera shake. The bank and spawn remain outside its orbit. Onboarding players below three banked catches are exempt.
- Session scores are opt-in and limited to four participating players, clearly labeled current-round scores. No global leaderboard, public data upload, monetization or required competition is implied. Solo play retains all goals.

Round-end and departure still bank legitimate carry. A failed attempt never removes saved progress. Arena selection is between rounds so per-arena records have an honest origin. Final summary and records are server-owned; no client score parameter or reward RemoteEvent was added.

## October 29 integration additions

- **Arena Rally:** bank six ordinary creatures at the gate in a 45-second arena window. Same target solo or together. Each contributor still playing in that arena with a valid save lease receives eight glow once at completion. No personal-skill bonus, starter/auto-bank credit or spectator payout. Leaving retains team progress but removes award eligibility. Each arena has a separate rally; failed windows reset without penalties. Optional, never blocks solo progression.
- Five one-time quests reward precision/dash catches, best chain, completed goals and bronze records across arenas. Descriptions require round completion. Persistent round receipts reject repeated recording; old saves migrate without losing collection/balances. Claims remain idempotent.
- One client outline previews nearest eligible target in the same forward arc as the server, with close-range touch allowance and creature-ID tie-breaking. Diamond/text precision cue accompanies color. Preview sends no target/reward data; server checks still decide catches. Client/server positions can differ under latency; agreement needs engine testing.
- HUD chain countdown makes timing explicit. Rally progress appears after onboarding; Quests explains the rules. Menu countdown updates preserve controller selection.
- Settlement precedes hazard/movement processing. Exact-deadline captures, dashes and manual banks are rejected even before periodic Playing-to-Results updates.

## Validation and next design questions

Pure tests cover precision/timing edges, chain expiry/caps, duplicate capture IDs, malformed numbers, banking/finish idempotence, recovery, starter exclusions, deterministic goals, profile migration and bounded hazard paths. Tests do not establish feel, visual warning readability, collision, touch aiming, comparative upgrade fairness or actual persistence. A later explicitly authorized supervised session must measure those before changing G1/G2 acceptance.

Open improvements: active enemy variety, richer arena-specific obstacles/events, audio binding and practice guidance. Rallies/target highlighting are implemented but unrendered; inspect occlusion, narrow quest text, warning readability and pacing. Tune thresholds from actual play rather than inflate grind or effects. Current weights and targets are hypotheses, not proven balance.
