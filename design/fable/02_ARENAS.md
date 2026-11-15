# 02 — The three arenas

Authoritative data: `data/arenas/{meadow,canyon,aurora}.json` (coordinates, features, habitats, pods, routes, lighting, palette). Maps rendered from that data: `maps/*.svg`. Builder recipes per feature type: `data/asset_manifest.json`. This document explains intent; where it and the JSON disagree, the JSON wins.

Conventions: arena-relative studs, +x east, +z south (toward the hub), y up. Arena origins stay at `((index-1)*300, 0, 0)`. Boundaries are polygons, not circles; the boundary of every arena is a pinch wall.

## Shared rules for every arena

| Rule | Value |
| --- | --- |
| First sight from spawn | A bank ring 8–10 studs ahead, one pod within 25 studs, and at least two mid-distance features. At the gameplay camera (46°) there is no skyline: landmarks are recognised by their bases and found by turning the camera (`11` §1) |
| Landmarks | 3–4 per arena, each ≥ 30 studs tall or uniquely shaped, with a distinctive base and a long shadow; visible from anywhere in bounds when the camera is turned toward them |
| Bank rings | Exactly 2, ≥ 100 studs apart: one at the spawn gate, one deep in the arena |
| Habitats | Each species lives at a named habitat; pods spawn there and nowhere else. ≥ 24 studs between habitat centres |
| Live creatures | ≤ 14 base (meadow 13, canyon 13, aurora 12); ≤ 30 with event extras |
| Stampede routes | Exactly 2, alternating per cycle, never through a bank ring or within 12 studs of spawn |
| First Spark glints | Exactly 5 per arena, 30–60 studs apart, drawn on the maps as numbered circles (`12`) |
| Walls | ≤ 5 studs high are player-jumpable; creatures never cross walls or water. Boundary hedge 3.5 studs; hedge, canopy and arch deck fade when between camera and player |
| Collision | No invisible walls. Every blocker is a visible feature in the JSON. Fall damage is off |
| Navigation | Any two points are reachable in ≤ 12 s on foot; no dead ends narrower than 10 studs |

## Arena 1 — POP MEADOW: "The Clover Bowl"

**Role:** teach the loop, herding and pinch walls. Baseline movement. This is the Checkpoint 1 slice arena; reference frame `mockups/meadow_gameplay_frame.png`.
**Size:** 172 × 150. **Feel:** warm morning, soft hills, a toy-farm pasture.

| Zone | Where (x, z) | What it is | What it teaches |
| --- | --- | --- | --- |
| South lawn | (12, 46) | Pip pod in front of spawn, bank ring at the gate | First loop within 10 s |
| Tall grass | (−14, 26) | Waist-high grass; only ears show | Reading partial silhouettes |
| Stone pens | (−52..−16, 30..54) | Two U-shaped dry-stone pens, open to the north | Drive Cublooms in; the walls finish the loop (PINCH) |
| Mirror Pond + creek | pond (−50, −10); creek to (82, 6) | Water splits the meadow; creatures cannot cross, players wade or jump | Water as a herding wall |
| Flower field | (38, 44) | Three tall perch flowers | Flutterwink perch timing |
| Windmill hill | (64, 34), +7 | Turning sails; overlook | Landmark, vantage |
| Clover Tree knoll | (4, −30), +6 | House-sized four-leaf clover, falling leaves | Central landmark; north bank ring behind it at (−2, −64) |
| Mushroom ring | (50, −36) | Five bounce caps; Bunvolt pod in the middle | A 22-stud bounce gives an aerial view of your own ribbon |
| Bloom buds | (22, 26), (−28, −48), (62, −8) | Giant closed buds | Bloom Burst sites (`04`) |

**Routes:** from spawn, the obvious path runs lawn → grass → pens (west) or lawn → flowers → windmill (east). Crossing the creek (log bridge at (0, 1), stepping stones at (46, 5), or a jump anywhere) opens the tree, the far ring and the mushrooms. The far ring makes "bank here or run back" a real choice.

**Creature distribution:** Pip ×3 south lawn, Pip ×3 tall grass, Cubloom ×4 pens field, Bunvolt ×2 mushroom ring, Flutterwink ×1 flower field. Spare habitat: north lawn (used by respawn rotation and events).

**Environmental story:** an abandoned shepherd's pasture. Pens, a windmill, a well overgrown by the clover. Sparks graze where sheep used to.

## Arena 2 — FIZZ CANYON: "The Switchback"

**Role:** interception, verticality, chokepoints. You cannot chase here; you must predict.
**Size:** 208 × 120, long east–west. **Feel:** late-afternoon orange light down the canyon axis, teal fizz seams, long shadows.

| Zone | Where | What it is | What it teaches |
| --- | --- | --- | --- |
| THE RUN | Closed circuit around the central butte | A worn racetrack on the canyon floor; Zip Tails lap it at 32 | Intercept loops; rest-stone timing |
| West / East chokes | (−52, −10), (54, −12) | The Run squeezes between the shelf cliff and a rock tooth (22–24 wide) | Trap loops; pinch |
| The Arch | (0, −24) → (0, 5), deck at +12 | Stone bridge from the north shelf to the butte, over the Run | Vantage; drop-in loops from above |
| North shelf | z < −24, +12 | Wide ledge with ramps at x = −62 and 58; second bank ring at (0, −36) | High ground; Sunshell bowling off the edge |
| Central butte | (0, 16) r 12, +12 | Flat-topped lookout reached by the Arch | Read the whole Run |
| Geysers | 5 sites | Two under the shelf launch you onto it; three on the floor | Vertical shortcuts; Fizz Geysers event |
| Sand Flats | (−66, 28) r 16 | Rippled sand with four surfacing mounds | Dune Fin prediction |
| Candy-cactus garden | (58, 30) | Three solid cacti in tight spacing | Threading a ribbon near Prickles |
| Soda Falls | (94, −12) | 40-stud teal waterfall | Landmark, audio beacon |

**Routes:** spawn (0, 58) → south ring → the Run's south leg is 12 studs ahead. Left to the sand, right to the cacti, straight on under the Arch. Up: either ramp or either shelf geyser. Down: jump anywhere.

**Creature distribution:** Zip Tail ×2 on the Run; Sunshell ×2 shelf west, ×2 shelf east, ×2 butte top; Prickle ×2 cactus garden, ×2 tooth garden (−86, −16); Dune Fin ×1 Sand Flats.

**Environmental story:** a soda spring cut the canyon; generations of Zip Tails wore the racetrack. Bottle-cap geysers, striped strata like layered candy.

## Arena 3 — AURORA ARCADE: "The Frozen Dial"

**Role:** momentum and restraint. The arena draws big loops for you if you can control the glide, and two species punish speed.
**Size:** 172 × 152. **Feel:** night under an aurora; a frozen fairground boating lake; everything self-lit.

| Zone | Where | What it is | What it teaches |
| --- | --- | --- | --- |
| Frost Lake | ellipse (0, 2) 46 × 32 | Mirror ice: speed 29, turning inertia 0.45 s | Wide sweeping loops; committing to a line |
| Lantern islet | (0, 2) | The Aurora Lantern (30 studs); its flame colour is the round clock | Landmark; phase readout in the world |
| Lake ring | (0, 18) | Bank ring on the ice | Banking at full glide |
| Wind lanes | West arc (south→north), east arc (north→south) | One-way currents, speed ×1.45 | Fast travel; drawing long arcs; **startles Ribbubbles** |
| Crystal spires | 5 sites | Solid, 16–24 tall | Starwhirl orbits; pinch pillars |
| North terrace | z < −40, +8 | Raised promenade with stairs at x = ±46; the Observatory dome | Antlume patrol; charge lines along a narrow space |
| South rim | (−10, 48) | Snowy shore by the spawn | First Crownlet court |

**Routes:** spawn (0, 73) → south ring → Crownlet court in view. Straight on: the lake. Left: west wind lane, which carries you up to the terrace stairs in about four seconds. The east lane brings you back.

**Creature distribution:** Crownlet court ×3 south rim, ×3 terrace west; Ribbubble ×2 east shore, ×2 west shore; Starwhirl ×1 orbiting the north-east spire (north-west spire is the spare); Antlume ×1 terrace east.

**Environmental story:** a winter fair that packed up and left. Marquee lanterns still pulse around the rim, the observatory still tracks falling stars, and a tiny royal court still parades the promenade.

## What makes them three places rather than three colours

| | Meadow | Canyon | Aurora |
| --- | --- | --- | --- |
| Shape | Rounded bowl split by water | Long two-level trench | Ring around a lake |
| Movement rule | Baseline + bounce | Vertical: launch up, drop down | Glide + one-way currents |
| How you catch | Circle and squeeze | Predict and intercept | Sweep, or slow down |
| Terrain tool | Pens, water edge | Chokes, cliff base | Spires, crater rims |
| Light | Morning, soft shadow | Low sun, long shadow | Night, emissive |
| Skyline | Clover tree, windmill | Arch, falls | Lantern, observatory, aurora |
| Signature event | Bloom Burst | Fizz Geysers | Starfall |

## Lighting and atmosphere

Per-arena lighting is applied **on the client** when the player enters an arena (1.5 s tween), because all arenas share one `Lighting` service. Values are in each arena's `lighting` block. Aurora's ambient floor is deliberate: night must never reduce creature or ribbon contrast (`05`, `09`).

## Hub and Trial Grounds

The existing arrival flow (menu teleport, intermission) is unchanged. The Trial Grounds for the Daily Stampede are redesigned in stage 3 (WP-15): a flat, symmetric 120 × 120 "practice paddock" with authored pod slots and one stampede route, so daily scores compare loop skill, not arena knowledge.
