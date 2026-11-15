# 01 — Core loop and controls

Numbers come from `data/tuning.json`; that file is authoritative and marks each value `fixed` or `hyp` (hypothesis with a tuning range). Picture: `mockups/loop_anatomy.svg`.

## 1. Inputs (complete list)

| Action | Keyboard | Gamepad | Touch | Notes |
| --- | --- | --- | --- | --- |
| Move | WASD | Left stick | Roblox thumbstick | Walk speed 24 |
| Dash | Shift **or** E | B / RT | DASH button (84 px, bottom right) | E is kept as a dash key so existing muscle memory does something |
| Jump | Space | A | Roblox jump | Default height; clears 5-stud walls and the creek |
| Camera yaw | RMB drag | Right stick | Drag on empty screen | Pitch is clamped (§6) |
| Menu | M / Tab | Start | Menu icon | Never opens itself during a round |

There is no catch input. `Capture` is removed from the client and rejected by the server.

## 2. The ribbon

- **Always on** during a round. Emitted at foot level from the moment the round starts; no button, no resource.
- **Lifetime 4.2 s, maximum length 100 studs.** The tail fades out; faded ribbon cannot close a loop. Walking a full circle of radius ~16 is the largest possible solo loop.
- **Sampled every 2 studs** of travel into a polyline (≤ 56 vertices).
- **Readable length:** the ribbon hum rises in pitch as the ribbon grows, and the head-end is fully opaque while the tail thins to 30 %.
- **Other players' ribbons** are drawn at 50 % opacity and never interact with yours.
- Creatures do not collide with the ribbon. It is a drawing, not a fence.

### Closing a loop

A loop closes when **either**:

1. **Crossing:** the newest ribbon segment intersects an older segment (ignoring the most recent 16 studs of path), or
2. **Snap:** the head comes within the snap radius (4.5 studs) of a ribbon point at least 16 studs back along the path. A dashed preview line appears inside twice that distance, with two rising ticks.
3. **Pinch (stage 2):** both ends of the live ribbon are within 3 studs of the *same* pinch wall (`02`): the wall forms the missing side.

Rejections (no penalty): perimeter < 16 studs or area < 18 studs². These stop accidental micro-loops from wiggling.

### What gets caught

At closure the client sends the polygon; the server (`08` §3) validates it against the path it observed and catches every eligible creature whose position is inside the polygon grown by 0.75 studs, **except** creatures in an *uncatchable state* (`03`: airborne, flying, burrowed, floating, blinking, charging). Creatures with `wraps > 1` gain one wrap instead.

### The cinch (reward feedback, 0.30 s)

1. Frame 0: ribbon inside the loop flashes white; `loop_close` thwip; creatures inside freeze with a surprised pose (client prediction).
2. 0–0.30 s: the ring contracts to its centroid (`loop_cinch` whoosh). This covers the server round trip.
3. On the server result: each caught creature pops 0.06 s apart on a rising pentatonic scale, squashes, and arcs into the parade behind the player. An escaped creature (uncatchable state) does a visible "nope" hop out of the ring so the miss is legible.
4. A payout tag rises from the centroid: score, then technique tags.
5. Empty loop: soft fizz, ring evaporates. No penalty.

The ribbon restarts from the player's feet immediately, so loops can be chained without a gap.

## 3. Dash

| Property | Value | Why |
| --- | --- | --- |
| Authority | Client starts it on the input frame; server only budgets it | Fixes the "glitchy" root cause |
| Charges | 2, each recharging in 2.4 s | A rhythm resource, not a spam button and not a long lockout |
| Motion | 0.26 s, ~15 studs, speed 24 → 70 → 58 → 30, blend to walk over 0.10 s | An ease-out curve reads as a lunge, not a teleport |
| Steering | 40 % of live input bends the direction | Lets players draw arcs with a dash |
| Buffer | A press up to 0.12 s before a charge is ready fires when it is | No dropped inputs |
| Air | Allowed | Dash off the shelf, off a bounce cap |
| Camera | +5° FOV for 0.08 s, back over 0.25 s (off in reduced motion) | Speed without shake |
| Empty | Soft thud, button dims | No error buzzer |

Dash has three uses, and choosing between them is the moment-to-moment skill:

1. **SNAP:** close a loop within 0.35 s of a dash start → +25 % and it beats hop/blink escapes.
2. **Boop:** creatures within 5 studs of the dash line are shoved 6 studs sideways and startled. Push a straggler into the ring, split a herd, bowl a Sunshell.
3. **Reach:** cover ground to a telegraphed event.

Spending both charges on travel leaves none for the SNAP. That is the intended tension.

## 4. Scoring

```
loopScore = round( Σ creature.value × sizeMult(n) × (1 + 0.25 × techCount) × chainMult × finaleMult )
```

| Term | Rule |
| --- | --- |
| `sizeMult(n)` | 1 → 1.0, 2 → 1.2, 3 → 1.5, 4 → 1.8, 5–7 → 2.2 (ROUNDUP), 8+ → 3.0 (STAMPEDE!) |
| Techniques | **SNAP** (dash close) · **TIGHT** (area ≤ 60 + 45·n) · **PINCH** (wall close) · **MEDLEY** (3+ species) |
| `chainMult` | Consecutive successful loops within 7 s of each other: 1 loop x1, 2 loops x2, 4 loops x3, 6 loops x4 |
| `finaleMult` | 1.5 during the Golden Finale (85–110 s) |
| Bank | Banked glow = carried values × bank multiplier: 1–3 → 1.0, 4–7 → 1.25, 8–11 → 1.5, full parade → 2.0 |

TIGHT and size pull against each other, as do SNAP and saving dash for travel, and banking now against going for a full parade. Those three tensions are the mastery space.

## 5. Parade, banking, failure and recovery

- Caught creatures follow the player in a parade (existing). Capacity 12 (+3 per Parade Pack level).
- **Bank rings:** two per arena (`02`). Run through one to bank; no stop, no button. Parade members arc through the ring one by one.
- **Overflow:** creatures beyond capacity score at 50 % and are released. A full parade is a prompt to bank, never a dead end.
- **Failure states and their cost:**

| Failure | Cost | Recovery |
| --- | --- | --- |
| Loop closes on nothing | None; chain timer keeps running | Draw again |
| Creature escapes (hop, blink…) | That creature only | Its cooldown is the retry window (`03`) |
| Ribbon cut (Prickle, Static Puff, Antlume charge) | The ribbon behind the cut | Ribbon regrows from the feet at once |
| Zapped by own Static Puff | Last 2 parade members scatter, recatchable | Loop them again |
| Chain expires | Multiplier back to x1 | Next loop starts a new chain |
| Buzzer with a parade | Auto-bank at x1.0 (existing auto-bank) | — |

Nothing ever removes saved glow, album entries or records.

## 6. Camera

Loop size must be judgeable, so the default camera is a raised chase camera, not Roblox's free default:

- Pitch 52° (clamped 42–62), distance 44, FOV 68, look-ahead 5 studs toward movement, +6 distance while the ribbon is longer than 55 studs.
- Yaw is the player's. Position smoothing 0.12 s; never rolls, never shakes.
- Occluders between camera and player (arch deck, canopy, crystals) fade to 60 % transparency.
- Setting **Camera: Classic** restores the Roblox camera with zoom clamped to 28–55.

**Fallback if H7 fails in Studio:** raise pitch to 60° and distance to 50 and add a faint ground ring showing the largest loop the current ribbon can still close. If loops are still hard to judge, switch default to a fixed-north top-down 3/4 camera before any further content work.

## 7. Difficulty progression inside the loop

| Layer | Introduced | Asked of the player |
| --- | --- | --- |
| Ring one slow creature | Round 1, first 10 s | Walk a circle |
| Ring a pod | Round 1 | Bigger circle; notice bunching |
| Bank at a ring | Round 1 | Route choice |
| Escaping creatures | Round 1–2 (Bunvolt) | Timing; SNAP |
| Events | Round 1 (Bloom Burst, Stampede) | Positioning ahead of a telegraph |
| Pinch walls | Round 2–3 (hint once) | Herd toward terrain |
| Static Puff | Round 3+ (existing rule) | Ribbon management |
| Multi-wrap rares, Legends | Round 3+ | Sustained execution |
| Heat 1–5 | After Silver (existing) | Shorter ribbon, shorter chain, more hazards |

## 8. Acceptance criteria for the core loop (automatable parts)

- A scripted bot that only presses buttons and never moves scores 0.
- A scripted bot that walks a 6-stud-radius circle around a Pip pod catches all three within 5 s of round start.
- Dash start is applied in the same client frame as the input (unit test on the Movement module with a fake clock).
- Loop validation rejects every polygon in the adversarial set (`08` §3).
- Empty-loop, cut and escape cases produce their distinct feedback events exactly once.
