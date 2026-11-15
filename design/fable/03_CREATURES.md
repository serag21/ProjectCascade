# 03 — Creatures, behaviour and rarity

Authoritative data: `data/creatures.json`. Silhouettes: `mockups/creature_silhouettes.svg`. Build-ready part lists for the four Meadow species: `data/models/meadow_creatures.json` (reference: `mockups/pip_reference_sheet.png`). Species ids, names, colours, values, rarity and signature keys are unchanged from `Config.Creatures`, so albums, mutations, signature stars and quests carry over.

## 1. Principles

1. **One behaviour, one telegraph, one counter.** A player who has seen a species twice can say what it does and how to beat it.
2. **Every escape is announced.** Minimum telegraph 0.3 s for movement, 0.5 s for anything that defeats a loop. Each has a sound as well as a pose.
3. **Never faster than the player in open flight** (walk 24), except species that are not chased at all (Zip Tail on its lane, Antlume's telegraphed charge).
4. **Bunch, do not scatter.** The default reaction to a circling player is to move away from the player *and* toward podmates. Circling makes loops easier, not harder.
5. **Few and distinct.** At most 14 base creatures per arena, in pods of 1–4 at named habitats, at least 24 studs apart.

## 2. Shared behaviour model (server, `Herd.luau`)

Each creature runs a small state machine at the existing server step. States common to all:

| State | Entry | Behaviour | HerdNet state code |
| --- | --- | --- | --- |
| `graze` | default | Wander within the habitat radius at idle speed | 0 |
| `alert` | player enters `awareness` | Telegraph pose for the species' delay | 1 |
| `flee` | after alert | Move along `normalize(away_from_player × 1.0 + toward_pod_centroid × 0.6 + obstacle_avoid)` at flee speed | 2 |
| `special` | species rule | Hop / perch / slide / burrow / float / blink / charge | 3–9 (per species) |
| `dazed` | event | Still, spinning, catchable | 10 |
| `cinched` | inside a validated loop | Frozen until the result | 11 |

The server keeps each creature's last 0.5 s of `(clock, x, z, ground level, catchable)` at the snapshot ticks; loop claims are resolved against that history at the client's view clock (`10` §5.5). "Uncatchable" below means `catchable = false` at that clock.

Common rules: obstacle, water and boundary avoidance with a 2.5-stud margin; a dash boop applies a 6-stud sideways impulse and 0.8 s of `alert`; a creature returning to its habitat walks, never teleports; respawn happens at the habitat only when no player is within 22 studs, with a small "pop out of a burrow" animation.

## 3. Species

Difficulty: ● easy, ●● moderate, ●●● hard. Full parameters are in the JSON.

### Pop Meadow

| Species | Rarity · value | Behaviour | Telegraph | Counterplay | Diff. |
| --- | --- | --- | --- | --- | --- |
| **Pip Pop** | Common · 3 | **Clump:** trio that squeezes together when circled | Ears flatten, one squeak | Any closed loop | ● |
| **Bunvolt** | Common · 4 | **Hopper:** every 2.6 s under pressure, a 12-stud hop directly away (0.7 s airborne, uncatchable) | 0.5 s crouch + shrinking ground ring + spring twang | Close between hops, SNAP during the crouch, or stand opposite the gap so it hops back inside | ●● |
| **Cubloom** | Uncommon · 5 | **Flock:** four move as one heavy block with a 0.4 s turn delay | All four lean before turning | Drive the block into a pen or against water; ring all four | ●● |
| **Flutterwink** | Rare · 7 | **Percher:** flies between flower perches (uncatchable), lands 4.0 s; leaves 0.6 s after a player comes within 9 studs | Next perch glows 1.5 s early; wings fold over the 4 s | Lay a wide ring outside 9 studs around the glowing perch, close while it sits. TIGHT if the ring is under 330 studs² (radius ≤ ~10.2) | ●●● |

### Fizz Canyon

| Species | Rarity · value | Behaviour | Telegraph | Counterplay | Diff. |
| --- | --- | --- | --- | --- | --- |
| **Sunshell** | Common · 6 | **Anchor:** tucks when you are within 8 studs (immovable, catchable). A dash boop sends it sliding 14 studs, bowling others along | Head pulls in 0.3 s; hollow "tok" | Use it as a fixed anchor for a mixed loop, or bowl it into a group | ● |
| **Zip Tail** | Uncommon · 8 | **Runner:** laps THE RUN at 32, resting 1.5 s at three stones. Ignores players; a frontal boop reverses it | Dust line 20 studs ahead; glowing rest stone | Intercept: pre-lay a horseshoe on the lane and SNAP it shut, pinch at a choke, or ring a rest stone | ●●● |
| **Prism Prickle** | Uncommon · 9 | **Cutter:** spines cut any ribbon within 2.5 studs; spines retract for 2.0 s after every third turn | Glowing spines; tick-tick-TOCK | Keep the ribbon wide, or close TIGHT in the retracted window | ●● |
| **Dune Fin** | Rare · 12 | **Burrower:** swims under the Sand Flats (uncatchable), breaches at a mound for 3.0 s, fixed mound order per round | Mound bubbles and bulges 1.5 s; fin heads for it | Have the ring nearly drawn around the next mound before it breaches | ●●● |

### Aurora Arcade

| Species | Rarity · value | Behaviour | Telegraph | Counterplay | Diff. |
| --- | --- | --- | --- | --- | --- |
| **Crownlet** | Common · 9 | **Leader:** a court of three in single file. Take only followers and the leader bolts; take only the leader and the followers freeze 3 s | Leader's crown is twice as tall | Ring the whole court, or leader first then the frozen followers to extend a chain | ●● |
| **Ribbubble** | Uncommon · 11 | **Floater:** if a player dashes or moves faster than 26 within 14 studs, it floats 10 studs up for 2.5 s (uncatchable) | Cheeks puff 0.35 s; landing shadow on the ground | Walk the loop. Or bait a float and ring the shadow | ●● |
| **Starwhirl** | Rare · 14 | **Blinker:** orbits a spire. When a ribbon encloses > 70 % of the angle around it, it blinks 9 studs toward the widest gap (4 s cooldown) | 0.5 s spin-up + a faint blink line | Close the last 30 % in under 0.5 s (SNAP), or bait the blink and loop during the cooldown | ●●● |
| **Antlume** | Rare · 16 | **Charger:** needs 2 wraps. After the first it rears 0.8 s then charges 40 studs, cutting ribbons, then stands winded 3 s | Antlers light; charge line on the ground | Wrap, sidestep, wrap again while winded. A second player's loop counts | ●●● |

The four signature techniques map onto the existing keys with no data change: `DASH` → **SNAP!**, `PRECISE` → **TIGHT!**, `TOGETHER` → **ROUNDUP!** (loop of 3+), `RHYTHM` → **ON RHYTHM!** (chain x2+). TIGHT normally needs two or more creatures; the three PRECISE species that are often caught alone have their own solo thresholds (`soloTightArea`: Flutterwink 330, Prism Prickle 60, Ribbubble 90).

## 4. Rarity and encounter frequency

Rarity is **how often and how hard**, never a random roll at catch time.

| Tier | Presence | Respawn | Per-round expectation (solo, hyp.) |
| --- | --- | --- | --- |
| Common | Always: 2–3 pods | 6–10 s after the pod is cleared | 12–25 caught |
| Uncommon | Always: 1–2 pods | 6–14 s | 4–10 |
| Rare | One individual | 26–34 s | 0–3 |
| Golden Runaway | Exactly one per round at 85 s | — | 0–1 |
| Legend | Every 4th arena cycle, plus a guaranteed first meeting in a player's 3rd round | — | 1 per ~8 minutes |

No creature despawns on a timer while a player is engaging it. Event creatures leave at the end of their event by hopping into a burrow puff, and never while inside a live cinch.

## 5. Congestion control

- Base cap 14 per arena, event cap 30 (`tuning.density`).
- Pods never spawn within 24 studs of another pod's habitat centre (validated).
- Multiple players do **not** increase the base cap. Instead pod respawn time scales `×(1 / (0.6 + 0.4·players))`, so more players refill pods faster rather than crowding the field. (Hypothesis; tune at Checkpoint 2.)
- A creature caught by one player is gone for everyone (existing atomic claim), which is why respawn scaling matters.

## 6. Visual identity rules

- One shared face kit on every species — two glossy ink eyes, no whites; glints and cheeks only on the nearest creatures — so the set reads as one family.
- All creatures are built at 1.3× their model size (`tuning.creatures.globalScale`), decided after the reference render showed them too small on screen. In-game heights run 2.3 → 6.8 studs (a Pip is 3.8 with ears; the player is 5). No two species in an arena share both a height band and a gait.
- ≤ 9 parts per creature (was roughly 14–22). Built on the client from `data/models` part lists; ellipsoids are a Part with a Sphere SpecialMesh (`11` §2).
- Each species' *state* must be readable from silhouette alone (tucked shell, folded wings, flared spines, raised antlers). Colour and glow are secondary cues.
- Golden variant: gold body, Foil material, sparse sparkle, gold trail. The silhouette is unchanged.
