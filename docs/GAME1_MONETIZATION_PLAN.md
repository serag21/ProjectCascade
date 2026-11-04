# SPARK STAMPEDE — monetization plan (PROPOSAL ONLY, NOT ENABLED)

Written 2026-11-04. **Monetization is disabled and not authorized.** No developer products, game passes or prices exist in the build. This plan exists so the owner can make an informed decision later (G5). Nothing here may be implemented or enabled without explicit owner approval and a fresh Roblox policy review.

## Principles (from AGENTS.md and current Roblox policy research)

- No real-money gambling, paid random rewards, loot boxes or "luck boosts". Roblox's 2026 paid-random-item rules (odds disclosure, eligibility checks) would apply to any paid randomness, and selling luck modifiers would pull earned randomness under them too ([research](research/market_research_2026-11-04.md) §4). We avoid the category entirely.
- No pay-for-power: no paid upgrades, perks, Heat skips, score multipliers or capacity. Leaderboards and medals stay skill-only.
- No false urgency: no countdown sales, limited-time pressure, streak loss or near-miss visuals (academic criticism cited in the research report).
- Guaranteed, clearly priced items only; everything purchasable shows exactly what you get.

## Candidate products (if approved)

| Product | Type | What the buyer gets | Notes |
| --- | --- | --- | --- |
| Supporter Parade Pack | Game pass | Three exclusive trails + a "Supporter" title + a gold name frame | Cosmetic only; no gameplay effect |
| Seasonal trail set | Developer product per set | A guaranteed themed trail set (3 trails) | Same trails also earnable later through play to avoid exclusivity pressure, or clearly labeled as cosmetic-only |
| Private server | Roblox private servers | Play with friends only | Standard platform feature; price set by owner |

## Implementation notes for a future session

- Gate any purchase UI behind a `Config.Monetization.enabled=false` flag; process receipts with `MarketplaceService.ProcessReceipt` idempotently (store receipt IDs in the profile), grant cosmetics only, and log `AnalyticsService:LogEconomyEvent` with a separate currency label ("Robux").
- Never show purchase prompts during a round, to new players before their first completed round, or as a reaction to failure.
- Test with Studio test purchases only; record evidence; owner approves before enabling.
