# PROJECT CHARTER — SPARK STAMPEDE (Game #1)

This file is the short entry point. It does not replace the detailed documents it links to.

- **Product:** SPARK STAMPEDE, an original bright creature-chasing, dash-catching and collection arcade game for Roblox. 110-second rounds, 1–4 players, always solo-completable. Full charter: [docs/GAME1_PRODUCT_CHARTER.md](docs/GAME1_PRODUCT_CHARTER.md).
- **Final production plan (executable blueprint, 2026-11-05):** [FINAL_PRODUCTION_PLAN.md](FINAL_PRODUCTION_PLAN.md) — launch scope, system specs, acceptance tests and implementation order. Takes precedence over the design spec where they differ.
- **Design specification (v2, mastery and retention):** [docs/GAME1_DESIGN_SPEC.md](docs/GAME1_DESIGN_SPEC.md).
- **Operating rules:** [AGENTS.md](AGENTS.md) (takes precedence), [docs/GAME1_WORKFLOW_CORRECTION.md](docs/GAME1_WORKFLOW_CORRECTION.md). Offline by default; no unattended Studio; no publishing, monetization, Robux or account actions without explicit owner approval.
- **Preservation:** `archive/cascade-pre-game1-pivot-20261024` (original Project Cascade) is immutable. The protected backup `backups/cascade-studio-20261025/pre-refresh-place-20261026-evening.rbxl` must not be moved or overwritten.
- **Source of truth:** Git `game/`. Deploy to Studio with `python tools/build_studio_install.py` (explicit Edit-mode installer) — see [docs/GAME1_STUDIO_WORKFLOW.md](docs/GAME1_STUDIO_WORKFLOW.md).
- **State tracking:** [BACKLOG.md](BACKLOG.md) (what is left), [DECISIONS.md](DECISIONS.md) (why), [RUN_STATE.json](RUN_STATE.json) (machine-readable session state), [docs/GAME1_PROGRESS.md](docs/GAME1_PROGRESS.md) (dated log), [docs/GAME1_ISSUES.md](docs/GAME1_ISSUES.md) (defects), [docs/GAME1_RELEASE_CHECKLIST.md](docs/GAME1_RELEASE_CHECKLIST.md) (gates).
- **Gates:** G0 source integrity → G1 loop → G2 full game → G3 QA matrix → G4 owner candidate playtest → G5 publish (owner only).
