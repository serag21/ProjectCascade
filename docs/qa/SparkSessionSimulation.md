# Spark pure session integration — actual execution evidence

**PASS for the pure-module simulation described below. NOT a Studio multiplayer, engine soak, visual, audio, navigation, or performance pass.**

Execution observed on 2026-10-25 America/Los_Angeles; environment captured at `2026-10-26T05:05:35.2900208Z`. Windows NT `10.0.26300.0`, PowerShell `7.6.5`, local standalone Luau executable. No Roblox process, client input, RemoteEvent, Humanoid, rendering or live DataStore is used by this test. Studio availability elsewhere in the session does not change this test's evidence class.

## Reproduce

Working directory: `C:\Users\serag\source\repos\ProjectCascade`.

```powershell
.\.tools\luau\luau.exe tests/SparkSessionSimulation.spec.luau
```

Exit code observed: **0**. Output:

```text
PASS contenders=1 rounds=10 player_rounds=10 unique_captures=240 contested_attempts=240 replay_rejections=240 reconnects=2 store_calls=69
PASS contenders=2 rounds=10 player_rounds=20 unique_captures=480 contested_attempts=960 replay_rejections=480 reconnects=3 store_calls=136
PASS contenders=4 rounds=10 player_rounds=40 unique_captures=960 contested_attempts=3840 replay_rejections=960 reconnects=5 store_calls=274
SparkSessionSimulation: 12456 assertions passed; 70 simulated player-rounds. PURE MODULES ONLY; NOT STUDIO MULTIPLAYER.
```

There are 30 simulated scenario rounds and 70 individual participant rounds. Each participant receives 240 uniquely owned captures across ten rounds, so 1,680 captures are checked overall. These are synthetic scheduled actions, not observed human gameplay, capture rates or retention metrics. The assertion count includes mock transform determinism checks; it is not a count of independent test cases.

## Actual modules exercised

- `Profile.new`, `Profile.bank`, `Profile.buy`, `Profile.claim`, `Profile.questProgress`, `Profile.speciesCount`, and sanitization through persistence.
- `Rules.canCapture`, `Rules.allow`, `Rules.roundPhase`.
- `Persistence.new`, `load`, `save`, `release` against a mock with serialization boundaries, repeated transform evaluation, lease conflicts and injected failures.
- Actual creature, upgrade, quest and biome configuration.

The harness controls carry ownership, virtual round orchestration and mock connections. **It does not import `Main.server.luau` or the client.** Consequently it cannot establish that their lifecycle, movement validation, UI or integration matches the modeled sequence. Those require separate engine testing.

## Checked scenarios and invariants

1. Independent known-value fixture: banking Pip Pop, Bunvolt and Cubloom grants 15 glow, discovers three species and records three banked creatures. Fresh profiles cannot afford boots or claim an uncompleted round.
2. Ten rounds for each of one, two and four contenders. Every target receives serialized requests in a rotating order. Exactly one owner wins, and repeated requests against a claimed target fail even after cooldown.
3. A same-frame duplicate action fails the actual cooldown rule. Successful actions happen inside the actor's personal round. Results phase rejects further capture.
4. The last participant in two/four-contender scenarios loads 15 virtual seconds later, receives a personal full-round start, and retains independent progress.
5. Mid-session departure banks modeled carry, saves/releases the profile, reacquires through a different persistence adapter and verifies exact progression, album, quests, settings and upgrades. The old adapter cannot write after release. A final reconnect repeats restoration for every participant.
6. Periodic mocked saves renew leases. A competing adapter cannot load a leased profile. Two injected transport failures are retried successfully. Mock reads/writes deep-copy tables to avoid accidental aliasing that could disguise unsaved progression.
7. All three biomes become reachable through earned bank totals, all twelve species can be banked, and all three upgrade paths reach their configured maximum. Quest rewards are exact and cannot be reclaimed.
8. Per-actor conservation: ending currency plus actual upgrade spending equals bank rewards plus claimed quest rewards. Banked count equals uniquely owned captures. Empty consumed carry never produces another bank reward.

This does not prove that any arbitrary duplicate carry list is safe: `Profile.bank` trusts server-owned carry by contract. The harness clears its carry once; real orchestration must maintain that invariant. Likewise, round-completion tokens are harness-owned, so the scenario does not prove Main cannot increment twice under an engine lifecycle race.

## Source identity at run

Repository HEAD at metadata capture: `6fd5a1da443bf15fb4df504885b92c09a7f95896`. Concurrent production work included uncommitted files, so HEAD alone does not identify the tested working tree. The exact exercised files are identified by these SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `.tools/luau/luau.exe` | `05F090AC5C2D18640337F9D3AC0F06B3A3ABC46CE93E4982E8FE7128B5026CBA` |
| `game/ReplicatedStorage/Spark/Config.luau` | `1657DB13081BCAC57EDAAB9467EC0C614F0F27E87C733E4487B3A18140D3123A` |
| `game/ReplicatedStorage/Spark/Profile.luau` | `7CE8F57F10DB2486A8F09B8BB6E7A25037AC8833D6B5471D3586206DB86154F9` |
| `game/ReplicatedStorage/Spark/Rules.luau` | `3572743D21D975A35D44F9BC832F8F45FE87434A671E3FD5D6578E48875D5346` |
| `game/ServerScriptService/Spark/Persistence.luau` | `9DC1D766A5082016A50CB3FC51E8A276C8EA9BD9943877B6BE2874D298DEF1EF` |
| `tests/SparkSessionSimulation.spec.luau` | `04872A8C24A3C24D9EDE1E54EC343D4D70DE9A1D925B75833C74B5AD38243EB0` |

Git line-ending normalization may change file hashes without changing behavior. Re-run after relevant source changes and record the new tested identity.

## Not established by this run

- Real 1/2/4-player movement, race scheduling, join/disconnect, respawn, replication or networking.
- Engine round completion across ten consecutive sessions or actual server shutdown behavior.
- Real DataStore durability, throttling budgets, network delays, yielding callbacks or crash recovery.
- Actual first action, first visible reward, first bank, objective comprehension or time-to-fun.
- Physical-device/mobile performance, UI readability, camera, geometry, animation, audio or visual effects.
- Whether collecting 24 targets per round is attainable or enjoyable. The scheduler intentionally supplies reachable targets and must not be used as an economy pacing prediction.

Separate engine tests remain mandatory. Do not check the release checklist's Studio multiplayer or ten-round engine soak boxes using this report.
