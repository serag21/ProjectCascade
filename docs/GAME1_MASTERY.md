# Mastery loop — staged offline, October 28 PDT

The player now has two clearly separate rewards: permanent glow/collection and a round skill score. This slice is source-integrated and offline-tested; it has not been installed or rendered in Studio. No new playtest is authorized by this document.

- Catch within 4 studs while facing the creature (dot >=0.7): precision bonus.
- Catch within 0.55 seconds of a server-approved dash: dash-catch bonus.
- Catch ordinary creatures no more than 6 seconds apart to build a chain. Multipliers rise after three and six catches, capped at x3. Waiting expires the chain without deleting carried points.
- A missed capture or orange sweep breaks the chain and removes carried style bonus. Base catch points, banked score, collected creatures and glow remain safe. Full-pack prompts are not aiming misses. Recover on the next catch.
- Bank to secure score and the current challenge. Three goals rotate by completed round: precision catches, a six-catch chain, and banking a group. Later cycles increase targets up to difficulty 3. Each goal pays 100 skill once, never purchased currency.
- Gold/silver/bronze thresholds are 800/400/150 skill. Saved best score, best chain, per-arena records and completed-goal count provide long-term mastery targets. Old profiles get safe defaults without resetting collection.
- After 25 seconds, eligible players encounter a circular infield sweep: 2 seconds of warning, 4 active seconds, 8 rest seconds. Bumps interrupt catching for 0.8 seconds; dash remains available. One marker, no flashes, no camera shake. The bank and spawn remain outside its orbit. Onboarding players below three banked catches are exempt.
- Session scores are opt-in and limited to four participating players, clearly labeled current-round scores. No global leaderboard, public data upload, monetization or required competition is implied. Solo play retains all goals.

Round-end and departure still bank legitimate carry. A failed attempt never removes saved progress. Arena selection is between rounds so per-arena records have an honest origin. Final summary and records are server-owned; no client score parameter or reward RemoteEvent was added.

## Validation and next design questions

Pure tests cover precision/timing edges, chain expiry/caps, duplicate capture IDs, malformed numbers, banking/finish idempotence, recovery, starter exclusions, deterministic goals, profile migration and bounded hazard paths. Tests do not establish feel, visual warning readability, collision, touch aiming, comparative upgrade fairness or actual persistence. A later explicitly authorized supervised session must measure those before changing G1/G2 acceptance.

Open improvements: active enemy variety, richer arena-specific obstacles and events, co-op scoring, audio binding, target highlighting and practice guidance. Tune thresholds from actual play rather than inflate grind or use excessive effects. Current score weights and targets are hypotheses to test, not proven balance.
