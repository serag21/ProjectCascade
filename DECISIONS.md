# DECISIONS — SPARK STAMPEDE

Append-only design/engineering decision log. Newest last. Earlier decisions live in the charter, research and progress documents; this file starts with the 2026-11-04 cloud session.

| # | Date | Decision | Rationale | Revisit when |
| --- | --- | --- | --- | --- |
| D1 | 2026-11-04 | Merge `wip/spark-interrupted-20261103` (biome arena events, PB split checkpoints) after review; complete its interrupted supervisor change. | Useful, coherent, tested; avoids losing owner-session work. | — |
| D2 | 2026-11-04 | Deepen skill with dash-through multi-catch, personal statics, Spark Gate herding, Stampede Run lanes, golden finale, scramble-on-hit and buzzer forfeiture rather than adding new buttons. | Keeps the 3-button control scheme (mobile friendly) while adding routing, prediction, timing and risk. | Playtests show confusion or frustration. |
| D3 | 2026-11-04 | Difficulty (Heat) and statics are **personal**, not arena-wide. | Shared creatures cannot be made harder for one player without hurting a newcomer in the same arena. | — |
| D4 | 2026-11-04 | Upgrades stay as modest permanent stats; new depth comes from perk side-grades with explicit downsides. | Owner requirement: upgrades must create choices, not just larger numbers. | Telemetry shows one dominant loadout. |
| D5 | 2026-11-04 | No prestige/rebirth at launch. Long tail is rank (50), heat medals (3 arenas × 6 heats), album tiers, achievements and daily/weekly goals. | Prestige resets suit long grind economies; this economy is short by design and resets would erase meaningful choices. | Post-launch data shows players exhausting rank. |
| D6 | 2026-11-04 | Daily/weekly goals with no streak, no loss on missed days, no paid skips. | Retention value without manipulative pressure (AGENTS hard constraint). | — |
| D7 | 2026-11-04 | Glow is never multiplied by heat; heat multiplies only skill score/XP. | Prevents grinding incentives and inflation. | — |
| D8 | 2026-11-04 | Third-party dev tools (luau-lsp, selene, lune, rojo binaries) were not executed: the session's permission policy blocked running downloaded binaries other than the official Luau CLI. Offline QA uses the official Luau runtime/compiler plus purpose-built engine doubles. | Respect permission boundary. | Owner allowlists these tools. |
| D9 | 2026-11-04 | Placeholder audio uses Roblox client built-in `rbxasset://sounds/*` files until the owner uploads the original WAVs. | No account/upload action is permitted; built-ins need no permissions. Exact availability must be verified in Studio. | Owner uploads assets. |
