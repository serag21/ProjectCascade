# Operating correction and incident audit

Owner instruction received October 27 PDT; corrective work continues October 28 PDT. Unattended Studio testing is disabled. Scheduling remains PAUSED, confirmed through its configuration and update response. Its prompt now explicitly forbids GUI testing and treats queued heartbeats as offline only. Do not resume it without the owner.

## What happened

Native Studio MCP handled source installation/readback, Luau queries, play start/stop, console reads, character navigation and virtual keyboard input. Foreground `@oai/sky` Computer Use also activated Studio windows, clicked gameplay menus, focused the viewport, opened backup dialogs and launched Server and Clients/Add Clients. Those focus and UI fallbacks interfered with desktop use and were used too broadly. Routine development now uses files, CLI and structured APIs. MCP virtual input is distinct from OS input; focus-dependent failures are failures to investigate, not permission to take over the desktop.

The local server `a018c177-8cbf-4aba-a313-8c575991029b` was launched from the native Test menu. Two separate clients received input and a third joined. No fourth-client test completed. The transcript ends that batch with three players still present, no normal stop and no verification of stopped state. An agent usage-limit error is recorded. There was no independent supervisor, deadline or cleanup worker: cleanup depended on the agent taking another turn. This was the workflow failure. Earlier interrupted solo sessions also remained idle in Results; game/world simulation continued even after the round finished.

Local log evidence: `0.744.0.7441077_20261027T235657Z_Studio_FA0EF_last.log` records server boot at 2026-10-27 23:57:31Z, Player1/2/3 joins, first round times 110.176/110.236/110.121 seconds, a 409.9ms D3D frame-query warning at 2026-10-28 01:57:23Z, and `StudioHangMonitor: Hang In Progress` at 01:58:28Z. That spans approximately two hours after boot. The owner reports force-closing Studio. These observations support the abandoned-session/hang report; they do not establish the cause of later display instability. No GPU utilization history or causal display-driver diagnosis was collected. Do not infer one.

## Preserved state

- Owner-saved evening backup remains in its original path, 136,090 bytes, SHA256 `81596f787935f27ca2edf661f5eed4486dac2a71ba559b19f16ef916eb572254`; rehashed without modification.
- Cascade archive remains untouched. `codex/playable-before-workflow-correction-20261027` preserves the last installed gameplay source `befffcf`.
- Existing uncommitted reports/screenshots are preserved and committed with their historical limitations, not discarded.
- Read-only MCP during this correction found intended place 127090454461830 in instance `f45da579-dc54-4292-b9ff-9cfe9a3c8aa2`, **Edit** mode. No play start, source activation, desktop control or GPU job was performed in the corrective session.

## New working procedure

1. Read AGENTS/charter/progress, inspect git and preserve local work. Build and test offline. `game/` remains the source of truth; generating an installer does not execute it.
2. No foreground UI calls, window activation, physical input or GUI launch without task-specific permission. No local GPU inference by default. Never stop unrelated applications or processes.
3. Keep unattended play disabled until an independent supervisor is engine-proven and the owner authorizes it. Cleanup-only subprocess tests are not certification. See GAME1_TEST_SUPERVISOR.md.
4. Any future approved engine test must have explicit identity, bounded resources, deadline, independent stop and stopped-state verification **before** launch. A hung MCP or ambiguous process binding fails closed. No blanket kill and no automatic force-kill fallback.
5. Save test evidence and stop verification before declaring a test completed. A successful input call, mock suite, model timing or incomplete server/client run is not a live gameplay pass.

The scheduler's paused state stops future scheduled deliveries; it is not a substitute for external application cleanup. [Official scheduled-task documentation](https://learn.chatgpt.com/docs/automations?surface=app). No automatic resumption is configured by this correction.
