# Studio and source integrity — 2026-10-25

Canonical source: Git-tracked `game/`. The old Cascade Script Sync trees remain preserved at `src/` and are not reused as Spark source. Spark deployment is a deterministic, explicit Edit-mode source install produced by `tools/build_studio_install.py`, with path/hash manifest. Do not edit production source in Studio independently of these files. Import changes back into Git before rebuilding if an intentional Studio fix is made.

Verified Studio: `Project Cascade [DEV]`, place 127090454461830, universe 10769277416, Studio ID ec0f5394-bf5e-44ef-8784-457cf593fa2b. Re-list on subsequent runs; IDs can change. Never publish as part of deployment.

`InstanceFileSyncService:GetSyncedInstance` and `GetStatus` verified SyncedAsRoot for all absolute folders:

- C:/Users/serag/source/repos/ProjectCascade/src/ReplicatedStorage/Cascade
- C:/Users/serag/source/repos/ProjectCascade/src/ServerScriptService/Cascade
- C:/Users/serag/source/repos/ProjectCascade/src/StarterPlayer/StarterPlayerScripts/Cascade

The tested C:/Windows/System32/Cascade path returned no mapping. Do not infer all arbitrary System32 paths are ruled out; all three actual roots were positively identified in the repo.

Two-way disposable probe performed: created ReplicatedStorage.Cascade.SparkSyncProbe with `return "studio-to-disk-20261025"` through MCP; read exact file content at the mapped repo path; rewrote file to `return "disk-to-studio-20261025"`; MCP read that exact source from the instance. Destroyed disposable instance; verified local file was removed by sync. No gameplay source was changed in this probe.

Recovery: archive remote branch remains at bcaabc660d98619716cd51fbc99bd38c053635f2. Before pivot, four live LuaSourceContainers were exported verbatim under `backups/cascade-studio-20261025/` with path/class/RunContext metadata. Runtime world was absent in Edit mode (Cascade is generated on Play). The explicit installer disables legacy active scripts and relocates baseplate/spawn into a local recovery folder; it does not delete archive data or publish the experience.

Spark source will be **not Script Synced**. This is intentional: explicit Git → generated installer → Studio is the sole write direction. Installer rejects an unexpected PlaceId or Play mode. Readback checks verify exact source after installation. Native Script Sync is retained for recovery and was verified in both directions before pivot.
