# Independent test cleanup — disabled live capability

**Unattended Studio testing remains DISABLED. No Studio play session was started to validate this prototype. Owner authorization is required before any future controlled engine test or scheduling resumption.**

`python tools/studio_supervisor.py status` reports the gate. `live` always exits 2 before any connection or process action. There is deliberately no play-start or Studio-launch operation. This restriction is a tool safeguard as well as an AGENTS instruction; it cannot intercept a person or a separate tool directly starting Studio.

## Implemented and testable offline

- Independent OS worker survives its launcher exiting. It does not rely on the agent's next turn or an agent try/finally.
- Hard maximum session budget 60 seconds, polling between 10ms and 2 seconds, transport calls at most 3 seconds, two normal-stop attempts with state verification. The fixture launcher passes an absolute monotonic deadline, so delayed worker startup cannot reset the budget. Cleanup adds at most six transport calls (18 seconds at maximum configuration), plus scheduling/filesystem overhead; this is not a hard OS real-time guarantee.
- Every status and stop preparation requires exact Studio ID, PID, process creation identity, executable image, place ID and unique run token. A mismatch never authorizes a stop. A PID alone is insufficient.
- CPU/RSS sample validation and configured ceilings trigger early normal stop. Missing/invalid resource telemetry triggers cleanup only after exact identity is verified; unknown/mismatched identity never authorizes stop. Edit verification does not depend on the resource sampler continuing to work.
- Append-only flushed UTC/monotonic JSONL events and flushed, atomically replaced final JSON report. Log-write failure triggers cleanup instead of bypassing it. Report-write failure emits a diagnostic on stderr. Either evidence failure makes the worker exit unsuccessfully even if Edit was verified. A stop acknowledgement alone is not success: state must become Edit.
- No termination of Studio or any unrelated process. A hung protocol **fixture child created by the test** can be killed by Python's subprocess timeout; this is not a Studio kill fallback.

Reproduction: `python tests/test_studio_supervisor.py`. These are real subprocess lifecycle tests against a lightweight protocol double, plus fault cases. They prove behavior of the worker/timeout logic, **not** Roblox MCP delivery, real process binding, GPU containment or hung-Studio recovery.

## October 28 offline hardening audit

The original worker could abandon a positively identified session when resource telemetry vanished or log writes failed. It also accepted booleans as numeric limits/IDs, retained a mutable manifest reference, and started the duration budget only after worker startup. These paths are corrected. Strict identity types include unpublished PlaceId 0; immutable copied identity, deadline propagation, startup failure reports and distinct state/evidence paths improve fault handling. The fixture rechecks identity at the stop mutation itself to cover a process changing between inspection and stop. This is an adapter contract demonstrated with a file-backed fixture, **not proof of atomic identity binding inside Roblox**.

`python tests/test_studio_supervisor.py` passed **19 tests** on October 28: the prior ten cases plus strict type/limit rejection, unavailable resources, Edit with broken telemetry, log/report failures, delayed startup, manifest mutation, identity replacement at stop, and malformed worker startup. Only disposable Python fixtures are launched; no Studio or graphical application is used. The default fixture launcher discards stdout/stderr, so if both log and final-report storage fail there is no guaranteed durable evidence; a future live launcher must retain an independent diagnostic sink and readiness acknowledgement before authorizing any test.

## Why live use stays disabled

The installed native bridge is launched by `%LOCALAPPDATA%/Roblox/mcp.bat`, selecting `StudioMCP.exe`. Existing native tools expose Studio inventory, state, Luau execution and normal stop. Inventory does not establish an OS PID/creation-time binding. A future adapter must positively bind a unique run token in the exact test DataModel to its OS process, and enumerate every owned multiplayer process; names or newly appeared windows alone are inadequate. We have not proven independent stdio MCP cleanup delivery against a running engine.

The prototype accepts CPU/RSS samples from its adapter; no real OS/GPU monitoring adapter is certified. It therefore cannot promise protection against RTX 5090 contention. Normal MCP stop may also fail when Studio hangs. Without an approved, independently validated way to contain that specific owned test process, such a failure can leave a simulation running. The safe current outcome is **no unattended launch**, not an optimistic safety claim.

## Future proof required before enabling anything

With task-specific owner approval only: one disposable local test, <=30 seconds, one client, confirmed target/PID/start-time/token, independent worker armed first, bounded stop calls, Edit verification, CPU/RSS/GPU evidence and saved logs. Interrupt the initiating agent/launcher deliberately and observe independent cleanup. Exercise wrong identity, stopped process, bridge timeout and process reuse. Confirm no focus/input or unrelated processes affected. A failed or ambiguous case leaves the gate disabled. Multiplayer requires separate complete process-ownership/cleanup evidence. The scheduler remains paused until the owner decides otherwise.

## Safety requirement status after offline hardening

| Requirement | Evidence / remaining gap |
| --- | --- |
| Independent survival after initiating agent exits | Python launcher exit and termination fixtures pass; Studio bridge lifetime unverified. |
| Short bounded session | Launcher deadline + bounded fixture requests tested; real MCP deadlines and engine scheduling unverified. |
| Normal stop and observed stopped state | Fixture stop/Edit checks pass; no new real Studio stop or shutdown test. |
| Exact process ownership | Strict synthetic identity and stop-time replacement tests pass; no proven OS PID/start-time/run-token binding, no multiplayer process ownership. |
| Resource limits | CPU/RSS fault samples tested; no certified OS sampler, GPU monitor or real contention containment. |
| Failure reporting | Log/report faults handled; total storage failure needs independent diagnostic retention/readiness handshake. |
| Hung Studio containment | Unresolved. No force-kill fallback. Normal MCP stop can fail; unattended testing stays disabled. |
| No unrelated process control | Fixture only creates/bounds its own Python children. No application enumeration, Studio control or desktop input in this batch. |
| Scheduling / live permission | Paused and disabled; owner authorization remains necessary and has not been granted. |
