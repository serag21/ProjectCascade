# 01 — Core loop and controls

Numbers come from `data/tuning.json`, which marks each value `fixed` or `hyp` (hypothesis with a tuning range). The exact rules are executable in `tools/loop_reference.py`; where prose and reference differ, the reference wins. Pictures: `mockups/loop_anatomy.svg`, `mockups/meadow_gameplay_frame.png`, `mockups/cinch_storyboard.png`.

## 1. Inputs (complete list)

| Action | Keyboard | Gamepad | Touch | Notes |
| --- | --- | --- | --- | --- |
| Move | WASD | Left stick | Roblox thumbstick | Walk speed 24 |
| Dash | Shift **or** E | B / RT | DASH button (84 px, bottom right) | E stays a dash key so old muscle memory does something |
| Jump | Space | A | Roblox jump | Default height; clears 5-stud walls and the creek |
| Camera yaw | RMB drag | Right stick | Drag on empty screen | Pitch clamped (§6) |
| Menu | M / Tab | Start | Menu icon | Never opens itself during a round |

There is no catch input. `Capture` is removed from the client and ignored by the server.

## 2. The ribbon

- **Always on** during a round, at foot level. No button, no resource.
- **Lifetime 4.2 s, maximum length 100 studs.** The tail fades; expired ribbon cannot close a loop. The largest solo ring is about 15 studs in radius.
- **Sampled every 2 studs** (≤ 56 vertices).
- **Length is readable:** the head is opaque and the tail thins to 30 %; the ribbon hum rises in pitch as it grows.
- **Other players' ribbons** are drawn at 50 % and never interact with yours.
- Creatures do not collide with the ribbon. It is a drawing, not a fence.
- Rendered as two Trails on the same foot attachments: a *travel* trail and a *loop* trail, so the loop can be cleared at closure without erasing the travel tail.

### Closing a loop

Tested every frame with the player's **current position** as the head:

1. **Snap:** the head is within the snap radius (4.5 studs) of any ribbon segment at least 16 studs back along the path. The loop is the ribbon from that point to the head. A dashed preview and a ring marker appear inside twice that distance, with two rising ticks.
2. **Crossing** (fallback for a fast step that jumps over the ribbon): the newest movement segment intersects an older one.
3. **Pinch (stage 2):** both ends of the live ribbon are within 3 studs of the same pinch wall (`02`); the wall forms the missing side.

Touching *any* older part of your ribbon closes the part in between. Rejected without penalty: perimeter < 16 studs or area < 18 studs².

### What gets caught

The client sends the polygon and the herd clock it was rendering. The server proves the polygon against the path it observed and catches every eligible creature that was inside it (grown by 0.75 studs) at that clock, on the same ground level, and not in an uncatchable state (`03`). Creatures with `wraps > 1` gain a wrap instead. Full procedure, latency and height rules: `10` §5.

### The cinch (0.30 s) — `data/models/cinch_effect.json`

1. Frame 0: the loop flashes white; `loop_close`; creatures predicted inside freeze, wide-eyed.
2. 0–0.30 s: the ring contracts toward its centroid. This covers the server round trip; if the result is late the ring holds, and at 0.8 s it releases as a harmless slip.
3. Result: each caught creature pops 0.06 s apart on a rising scale and arcs into the parade. A creature that escaped does a visible "nope" hop so the miss is legible.
4. A payout tag rises from the centroid: score, then technique tags.
5. Empty loop: soft fizz. No penalty.

The ribbon restarts from the feet at once, so loops chain without a gap.

## 3. Dash

| Property | Value | Why |
| --- | --- | --- |
| Authority | Client starts it on the input frame; the server only budgets it | Fixes the "glitchy" root cause |
| Charges | 2, each recharging in 2.4 s | A rhythm resource, not a spam button |
| Motion | 0.26 s, ~15 studs, speed 24 → 70 → 58 → 30, blend to walk over 0.10 s | An ease-out curve reads as a lunge |
| Steering | 40 % of live input bends the direction | Dashes can draw arcs |
| Buffer | A press up to 0.12 s early fires when the charge is ready | No dropped inputs |
| Air | Allowed | Off the shelf, off a bounce cap |
| Camera | +5° FOV for 0.08 s (off in reduced motion) | Speed without shake |
| Empty | Soft thud, button dims | No error buzzer |

Three uses compete for the same two charges:

1. **SNAP:** close a loop within 0.35 s of a dash start → +25 %, and it beats hop and blink escapes.
2. **Boop:** creatures within 5 studs of the dash line are shoved 6 studs sideways and startled.
3. **Reach:** cover ground to a telegraphed event.

## 4. Scoring

```
loopScore = round( Σ value × sizeMult(n) × (1 + 0.25 × techniques) × chainMult × finaleMult )
bankScore = round( Σ carried value × bankMult )          -- also paid as glow
```

| Term | Rule |
| --- | --- |
| `sizeMult(n)` | 1 → 1.0, 2 → 1.3, 3 → 1.6, 4 → 1.9, 5–7 → 2.3 (ROUNDUP), 8+ → 3.0 (STAMPEDE!) |
| Techniques (+25 % each) | **SNAP** dash close · **TIGHT** two or more creatures in a ring of area ≤ 40 + 36·n (server-measured), or a lone creature whose species has a solo threshold · **PINCH** wall close · **MEDLEY** three or more species |
| Chain links | A loop of n adds n links, +1 for 3–4, +2 for 5 or more: 1→1, 2→2, 3→4, 5→7, 8→10 |
| `chainMult` | x2 at 4 links, x3 at 10, x4 at 18. The loop that reaches a tier is scored at it |
| Chain window | 7 s + 0.75 s per extra creature in the last loop (max 12 s). A bank or a landed wrap also refreshes it |
| `finaleMult` | 1.5 from 85 s |
| `bankMult` | 1–3 carried → 1.0, 4–7 → 1.25, 8–11 → 1.5, 12 or more → 2.0 |
| Overflow | Creatures beyond parade capacity score at 50 % and are released |

Worked examples (all in `data/test_vectors.json`): first Pip alone = 3; first Pip pod = 29 (reaches x2); the same with SNAP and TIGHT = 43; a Cubloom flock arriving at x3 with TIGHT = 143; all eight from a Bloom Burst at x3 = 270; nine from a Stampede with SNAP and MEDLEY at x4 in the finale = 918; a full parade of twelve value-4 Sparks banks for 96.

These rules replace the first-pass ones, which a round model showed rewarded farming single creatures (`10` §2–3). Bigger loops now win per creature on score, chain and time. The three live tensions: TIGHT against size; dash for SNAP against dash for travel; bank now against a full parade.

## 5. Parade, banking, failure and recovery

- Caught creatures follow in a parade. Capacity 12 (+3 per Parade Pack level).
- **Bank rings:** two per arena. Run through one to bank; no stop, no button.
- A full parade is a prompt to bank, never a dead end (overflow rule).

| Failure | Cost | Recovery |
| --- | --- | --- |
| Loop closes on nothing | None; chain timer keeps running | Draw again |
| Creature escapes (hop, blink…) | That creature only | Its cooldown is the retry window |
| Ribbon cut (Prickle, Static Puff, Antlume charge) | The ribbon behind the cut | Regrows from the feet at once |
| Zapped by own Static Puff | Last 2 parade members scatter, recatchable | Loop them again |
| Chain expires | Multiplier back to x1 | Next loop starts a new chain |
| Buzzer with a parade | Auto-bank at ×1.0 | — |
| No server result in 0.8 s | The ring slips; nothing else | Draw again |

Nothing ever removes saved glow, album entries or records.

## 6. Camera

Loop size must be judgeable and the Sparks must be visible, so the default is a raised chase camera:

- Pitch 46° (clamped 38–54), distance 38, FOV 68, look-ahead 5 studs, +6 distance while the ribbon is longer than 55 studs.
- Yaw is the player's. Position smoothing 0.12 s; never rolls, never shakes.
- Occluders between camera and player (hedge, canopy, arch deck, crystals) fade to 70 % transparency.
- Setting **Camera: Classic** restores the Roblox camera with zoom clamped to 28–55.
- Slice debug: `[` and `]` step the presets 54° / 46° / 38° (`mockups/camera_pitch_comparison.png`).

These values were changed from 52° / 44 after rendering the real Meadow (`11` §1): Sparks were too small and no landmark was on screen.

**Fallback ladder if loops or Sparks are hard to read in Studio** (apply one step, re-test):
1. Adopt whichever preset, distance and creature scale the owner preferred.
2. Add a faint ground ring showing the largest loop the current ribbon can still close.
3. Switch the default to a fixed-north three-quarter camera (pitch 60°, no yaw).

## 7. Difficulty progression inside the loop

| Layer | Introduced | Asked of the player |
| --- | --- | --- |
| Ring one slow creature | Round 1, first 10 s | Walk a circle |
| Ring a pod | Round 1 | Bigger circle; notice bunching |
| Bank at a ring | Round 1 | Route choice |
| Escaping creatures | Round 1–2 (Bunvolt) | Timing; SNAP |
| Events | Round 1 (Bloom Burst, Stampede) | Positioning ahead of a telegraph |
| Pinch walls | Stage 2: round 2–3, hint once | Herd toward terrain |
| Static Puff | Stage 2: round 3+ | Ribbon management |
| Multi-wrap rares, Legends, First Spark | Stage 2 | Sustained execution |
| Heat 1–5 | After Silver | Shorter ribbon, shorter chain, more hazards |

## 8. Automatable acceptance criteria

- A bot that only presses buttons and never moves scores 0.
- A bot walking a 6-stud circle around the starter pod catches all three within 5 s.
- Dash motion is applied in the same client frame as the input.
- Every vector in `data/test_vectors.json` passes; the adversarial set grants nothing.
- Empty-loop, cut, escape and slip each produce their distinct feedback exactly once.
