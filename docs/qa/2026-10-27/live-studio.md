# Studio recovery and solo progression evidence — October 27, 2026

Historical report, superseded for current operating status by [the incident audit](../../GAME1_WORKFLOW_CORRECTION.md). A later befffcf local server/two-client partial run and third join were left without verified shutdown; four-client QA was not completed. Unattended testing is now disabled. The later dash fix was committed as befffcf; its final source includes actuator cleanup and compact onboarding labels beyond the intermediate hash below.

User-local report date: October 27 PDT. Continuation heartbeat: 2026-10-27T23:49:01.941Z. Session actions span continuations; absolute UTC times for each input were not retained in this report. Funnel values below are the actual recorded elapsed seconds after server join. They must not be interpreted as independently timed visible-spawn or human-comprehension results.

## Environment and scope

- Windows local Roblox Studio, native Studio MCP plus native Windows UI input. Official local Luau toolchain is 0.744; do not infer a newly refreshed Studio binary version from the toolchain version.
- Intended development instance: `4273c080-67ba-410b-ad51-3522335b16b1`, Project Cascade [DEV], PlaceId `127090454461830`, UniverseId `10769277416`.
- Installed source: commit `862e91a`, eight Spark sources read back matching repository source after line-ending normalization. Includes lease fixes `b191aa8`/`862e91a`, finite starter fix `e0e90a2`, earlier lifecycle and responsive UI fixes.
- One real solo client/server per run, fresh isolated Studio memory profiles. No production DataStore writes, public publication, Robux spending, monetization or account changes.
- The initial two runs below exclude client starter-visibility changes. The later dash retest uses 45144f8 plus an uncommitted Main fix; exact source hashes are recorded separately below.

## Recoverability and source synchronization

The failed `pre-refresh-place-20261026.rbxl` save attempt remained absent. The distinct evening backup was verified at `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl`:

| Property | Observed value |
| --- | --- |
| Bytes | 136,090 |
| SHA256 | `81596f787935f27ca2edf661f5eed4486dac2a71ba559b19f16ef916eb572254` |
| Filesystem last-write UTC | 2026-10-27T05:46:23.8077187Z |
| Local recovery instance | `9198099a-cc34-49ee-b49a-5a1b27082b61` |
| Reopened local identity | PlaceId 0 / UniverseId 0 |

Reproduction of the performed rollback rehearsal: open the verified backup as a local copy; snapshot all LuaSourceContainer source/SourceSHA attributes and BaseScript enabled states; generate the transactional installer; override expected PlaceId to 0 only in the test invocation; replace the final source payload with a table; execute. The final assignment failed after earlier source writes:

```text
Install failed: Unable to assign property Source. ProtectedString expected, got table; rollback failures=0
```

All twelve saved script snapshots matched after rollback. The copy was closed without saving, and the backup hash remained unchanged. This is evidence for that partial-source-write failure path, not every possible installer error, crash or filesystem recovery. [Committed backup metadata](../../../backups/cascade-studio-20261025/full-place-backup.json).

All three current native Script Sync roots returned `SyncedAsRoot` and the expected Cascade folders:

```text
C:/Users/serag/source/repos/ProjectCascade/src/ReplicatedStorage/Cascade
C:/Users/serag/source/repos/ProjectCascade/src/ServerScriptService/Cascade
C:/Users/serag/source/repos/ProjectCascade/src/StarterPlayer/StarterPlayerScripts/Cascade
```

Disposable `ReplicatedStorage.Cascade.SparkSyncProbe` source `return "studio-probe-20261027"` arrived on disk exactly; changing the `.luau` file to `return "disk-probe-20261027"` was observed exactly in Studio. Destroying the probe removed its disk file. No System32 root was observed. These roots preserve Cascade; Spark's sole source is Git `game/` → generated installer → Edit-mode Studio. No competing Spark sync mapping was introduced.

## Actual solo input and round results

Keyboard actions used native MCP client `keyDown` → wait → `keyUp`; they were not direct reward/remote injection. E capture holds were approximately 150ms. Native viewport focus was required when the tool reported successful actions without observable game response. A tool success alone was not counted as a gameplay pass.

| Recorded telemetry | Run 1 | Run 2 |
| --- | ---: | ---: |
| first_action | 0.464s | 36.196s |
| first_catch | 0.464s | 36.197s |
| first_bank | 0.514s | 36.198s |
| first_round | 110.009s | 110.046s |

Run 1 reached two banked catches, 9 glow and two species. Ten further stationary E pulses (approximately 120ms held, 650ms gap) left banked count and glow unchanged. One starter remained until round cleanup. Navigation tool calls that returned success without an additional observed catch are not counted as verified movement objectives. The inspected console window reported no game errors; a permanent full raw console export is not attached here.

Run 2 initially lacked viewport focus. The delay remains in the recorded timing sample; it is not rewritten as a pass. After a native click focused the gameplay viewport, actual W/E/S input reached three banked catches, 12 glow, three species, zero remaining starters and an empty carry inventory. M opened the album. The fast Run 1 sample meets the numeric action/reward targets from server join, but neither run establishes independent objective comprehension, emotional satisfaction or visible-spawn timing. Two 110-second round completions are not a ten-round soak.

## Actual quest and upgrade UI transactions

In Run 2, with 12 glow after its three catches, native clicks on observed quest/upgrade controls produced:

| Action | Before | Observed after | Conclusion |
| --- | --- | --- | --- |
| Claim `first_haul` | 12 glow | 22 glow | Reward credited once |
| Repeat first-haul click | 22 glow | 22 glow | No duplicate reward in this UI case |
| Claim `first_round` | 22 glow | 37 glow | Round quest credited |
| Buy boots | 37 glow / level 0 | 17 glow / level 1 | Correct 20-glow debit and level increment |
| Try unaffordable next boots purchase | 17 glow / level 1 | 17 glow / level 1 | No debit or level change |

Rendered evidence: [claimed quests](quests-claimed.png), [boots upgrade](boots-upgrade.png). These were actual UI transactions followed by state inspection, not pure Profile helper calls. These checks do not prove malformed-remote rejection or persistent restore after a new server.

## Replay and a blocking dash defect

An actual native click on Chase Again hid Results and entered Playing; the inspected timer showed 1:48. State retained 17 glow, three species, three banked catches, zero starters and one completed round. Client state confirmed boots level 1, dash cooldown 2.65 and both `first_haul`/`first_round` claimed. Replay did not replenish starters. Telemetry recorded first_upgrade 28,167.895s and replay 28,212.321s after join; these include long idle interruptions and are **not** meaningful time-to-upgrade or replay-pacing measurements.

The subsequent actual Shift input was accepted and displayed dash feedback, but a five-second client motion sample (69 observations) showed z min=max=38 and maximum speed approximately 0.0000065254. No meaningful displacement occurred. Prior observed dash feedback was therefore insufficient evidence for movement.

### Dash fix and actual engine retest

The follow-up source uses Git 45144f8 plus an uncommitted Main server planar LinearVelocity actuator fix. All eight installed sources were read back. Changed source hashes:

```text
Main.server.luau e8e0a470e9a27623199ad8942672017435009ce68a0790f4d13cf6e34a06f21d
Client.client.luau a5c898c3ed46978a28c1e0c2734977b5e3c43e08da384ecedf295f1e96baa4be
```

In a fresh focused solo client, an actual Shift down/150ms/up produced visible displacement. The 61 motion samples available at inspection showed z 38→27.259985 and peak speed 65.8760; two samples observed the actuator. Subsequent actual E/S capture/bank input awarded 4 glow and one catch. Server inspection found z 37.69128 and no remaining SparkDashVelocity or attachment. The inspected console reported no game errors.

This resolves the reproduced zero-displacement defect in that solo case. It does not establish collision safety, high-latency behavior, repeated-dash cleanup, multiplayer behavior or a complete fresh-loop regression on the revised source. Diagnostic-run telemetry recorded first_action 13.070s, first_catch 30.772s and first_bank 33.758s, including focus/instrumentation delays; it is not a fresh-hook pass.

## Additional engine diagnostics on the dash-fix build

These tests used explicit play-session script injection through MCP. They supplement actual input tests and must not be confused with natural gameplay, separate clients or full security coverage.

- **Foreign starter visibility:** server cloned one starter into `QA_ForeignStarter` with `StarterOwnerId=-999`. The real client observed all 15 parts with `LocalTransparencyModifier=1` and its one billboard disabled. The disposable model was removed. This exercises the installed client visibility handler on a replicated injected model; it is not a two-player test.
- **Fall rescue:** server set the player's root CFrame to `(0,-30,38)`. After heartbeat, root position was `(0,2.998046875,38)`, health 100, with glow 4 / banked 1 unchanged. This verifies recovery from that injected fall, not death/respawn or carry-at-round-end policy.
- **Malformed/unearned actions:** client injection sent a table-valued Action, Biome NaN/infinity, unknown Upgrade and Quest IDs, and 100 unearned `first_haul` requests. Before/after values stayed at glow 4 / banked 1; inspected console reported no errors. Subsequent real E down/150ms/up succeeded and reached 7 glow / two banked catches, showing ordinary capture remained usable afterward. This is a bounded rejection/rate-limit case, not exhaustive remote security proof.

## Remaining tests and practical limits

- Dash repair needs broader collision/latency/repetition regression. Arena unlock/navigation, death/respawn, carrying through rescue, broader remote abuse and upgraded movement comparisons remain outstanding.
- There are no actual two-/four-client results, late-join/disconnect engine results or ten-round soak results in this report. Pure contender simulation is a different evidence class.
- Isolated memory persistence does not verify production DataStore access, cross-server lease behavior or cross-session restore. New lease fixes have focused pure tests only for those failure paths.
- Audio catalog asset IDs remain blank. Authored WAV validation is not audible engine review. Mobile/gamepad rendering/input and representative device performance remain unverified.
- Some MCP mouse-by-instance and capture requests stalled and were canceled. Native observed UI focus/input was used to resume; stalled requests are not counted as successful interactions or screenshots.
- The source archive, full backup and current installed source are distinct recovery artifacts. Save a separate candidate copy after further testing; do not overwrite the recovery backup.

G4 remains **NOT READY**. No owner release-candidate playtest or publication approval is requested by this report.
