# Independent test cleanup — disabled live capability

**Unattended Studio testing remains DISABLED. No Studio play session was started to validate this prototype. Owner authorization is required before any future controlled engine test or scheduling resumption.**

`python tools/studio_supervisor.py status` reports the gate. `live` always exits 2 before any connection or process action. There is deliberately no play-start or Studio-launch operation. This restriction is a tool safeguard as well as an AGENTS instruction; it cannot intercept a person or a separate tool directly starting Studio.

## Implemented and testable offline

- Independent OS worker survives its launcher exiting. It does not rely on the agent's next turn or an agent try/finally.
- Hard maximum session budget 60 seconds, polling at most 2 seconds apart, transport calls at most 3 seconds, two normal-stop attempts with state verification. Cleanup adds a bounded call allowance after the session deadline.
- Every status and stop preparation requires exact Studio ID, PID, process creation identity, executable image, place ID and unique run token. A mismatch never authorizes a stop. A PID alone is insufficient.
- CPU/RSS sample validation and configured ceilings trigger early normal stop. Missing samples or ambiguous identity fail with an explicit unconfirmed-cleanup report.
- Append-only flushed JSONL events and atomically written final JSON report. A stop acknowledgement alone is not success: state must become Edit.
- No termination of Studio or any unrelated process. A hung protocol **fixture child created by the test** can be killed by Python's subprocess timeout; this is not a Studio kill fallback.

Reproduction: `python tests/test_studio_supervisor.py`. These are real subprocess lifecycle tests against a lightweight protocol double, plus fault cases. They prove behavior of the worker/timeout logic, **not** Roblox MCP delivery, real process binding, GPU containment or hung-Studio recovery.

## Why live use stays disabled

The installed native bridge is launched by `%LOCALAPPDATA%/Roblox/mcp.bat`, selecting `StudioMCP.exe`. Existing native tools expose Studio inventory, state, Luau execution and normal stop. Inventory does not establish an OS PID/creation-time binding. A future adapter must positively bind a unique run token in the exact test DataModel to its OS process, and enumerate every owned multiplayer process; names or newly appeared windows alone are inadequate. We have not proven independent stdio MCP cleanup delivery against a running engine.

The prototype accepts CPU/RSS samples from its adapter; no real OS/GPU monitoring adapter is certified. It therefore cannot promise protection against RTX 5090 contention. Normal MCP stop may also fail when Studio hangs. Without an approved, independently validated way to contain that specific owned test process, such a failure can leave a simulation running. The safe current outcome is **no unattended launch**, not an optimistic safety claim.

## Future proof required before enabling anything

With task-specific owner approval only: one disposable local test, <=30 seconds, one client, confirmed target/PID/start-time/token, independent worker armed first, bounded stop calls, Edit verification, CPU/RSS/GPU evidence and saved logs. Interrupt the initiating agent/launcher deliberately and observe independent cleanup. Exercise wrong identity, stopped process, bridge timeout and process reuse. Confirm no focus/input or unrelated processes affected. A failed or ambiguous case leaves the gate disabled. Multiplayer requires separate complete process-ownership/cleanup evidence. The scheduler remains paused until the owner decides otherwise.
