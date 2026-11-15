# 11 — Meadow production reference

Everything the first slice needs to look and sound like, with what exists now and what is still production work.

## 1. The gameplay frame

`mockups/meadow_gameplay_frame.png` — the first ten seconds of a first round: the player about to snap a ring shut around the south-lawn Pip pod.

It is a **reference render**, built by `tools/render_refs.js` (three.js in headless Chromium) from the same data the game will use: `data/arenas/meadow.json` for every position, `data/tuning.json` for the camera, `data/models/meadow_creatures.json` for the creatures, `data/ui_layout.json` for the HUD rectangles. Primitives are the Roblox-equivalent shapes. It is not a screenshot of the game and shows nothing about performance or feel.

What to read from it:

| Element | In the frame | Build target |
| --- | --- | --- |
| Camera | Pitch 46°, distance 38, FOV 68, 5 studs look-ahead | `tuning.camera` |
| Terrain | Rolling ground, sand path from the gate, creek and pond with sand banks, darker ground beyond the hedge rising as a rim | Terrain + `GroundMap` (WP-05) |
| Landmarks in view | Stone pens (left), tall grass with only Pip ears showing, a bloom bud, perch flowers with a Flutterwink, the log bridge, mushroom ring (top right), Clover Tree trunk (top centre) | `meadow.json` features |
| Ground dressing | Grass tufts and small flowers; none on the path or water | Client decor, ~3,300 instances in the render; budget in §6 |
| Sparks | Three Pips bunched inside the ring in ALERT pose; two earlier catches following as a parade; Cubloom flock beyond the pens | `data/models` × `creatures.globalScale` 1.3 |
| Ribbon | 1.5-stud band with a bright core and soft glow, opaque at the head, fading along the tail back toward the gate | Two Trails (§4) |
| Closure | Dashed preview from the head to the snap point, ring marker at the snap point | Beam + pooled ring |
| Bank ring | Upright gold ring at the gate, just behind the player | `bank_ring` builder |
| HUD | Parade pips and multiplier, timer, score, menu, first-round hint, two dash charges; Roblox top-bar icons shown as placeholders | `ui_layout.json` desktop rects |

`mockups/camera_pitch_comparison.png` shows the same moment at the three debug presets (54°, 46°, 38°).

### Decisions the render forced

Rendering the real layout at the first-pass camera (52°, distance 44) showed two problems that the numbers alone had hidden:

| Finding | Decision |
| --- | --- |
| A Spark was about 20 px wide on a 1280-px screen (about 12 px on a phone) | Camera distance **44 → 38**; creatures built at **1.3×** (`tuning.creatures.globalScale`). A Pip is now 3.8 studs tall with ears, 3.0 wide |
| At 52° no horizon and no landmark was on screen; the "skyline landmark" rule could not hold | Pitch **52° → 46°**. The Clover Tree trunk and far field are visible; a ring still reads as a clear ellipse (height ÷ width ≈ 0.72). Landmarks are found by their bases and by turning the camera, not by a skyline |
| The south hedge sits between camera and player at the spawn lawn | Hedge lowered to 3.5 studs and added to the occluder-fade list |

All three are still hypotheses for Studio; the slice has `[` and `]` keys to step the pitch presets, and an F9 panel for distance and creature scale.

## 2. Signature creature: Pip Pop

`mockups/pip_reference_sheet.png` (turnaround, poses, the Meadow four at one scale). Build data: `data/models/meadow_creatures.json`.

| Part | Shape | Size (studs) | Position | Rotation | Colour |
| --- | --- | --- | --- | --- | --- |
| body | ellipsoid | 2.3 × 2.1 × 2.2 | 0, 1.15, 0 | — | 255,210,65 |
| feet | ellipsoid | 1.7 × 0.4 × 1.5 | 0, 0.2, 0.05 | — | body 30 % toward ink |
| ear_l / ear_r | ellipsoid | 0.5 × 1.05 × 0.75 | ∓0.5, 2.4, 0.05 | z ±28° | 255,244,190 |
| eye_l / eye_r | ellipsoid | 0.36 × 0.52 × 0.2 | ∓0.46, 1.32, −1.0 | — | ink 27,36,64, glossy |
| *near detail:* glints ×2, cheeks ×2 | ellipsoid | 0.13 / 0.34 × 0.2 × 0.1 | see JSON | | white / blush |

Sizes are before the 1.3 global scale. Faces −Z. Six parts plus four near-detail parts that exist only for the eight creatures nearest the camera within 35 studs.

Construction rules (apply to every creature):

- **Ellipsoids are a Part with a `SpecialMesh` of type Sphere**, scaled to the listed size. `b1b62fd` builds creatures from `Shape = Ball` parts with non-uniform sizes; whether those render as ellipsoids or as spheres has not been checked in Studio, and if they render as spheres it would help explain why the current creatures look alike. Verify once at Checkpoint 1 (place one of each side by side); the SpecialMesh route is the default regardless.
- One invisible anchored `Root`; all visible parts unanchored, massless, non-colliding, welded to it.
- Movement is one `Root:PivotTo` per frame. Squash and stretch is `SpecialMesh.Scale`/`Offset` on the body (no `Size` writes). Ears rotate at their weld.
- Shadows: body only.
- Poses and their numbers (idle, alert, flee, cinched, pop, parade) are in the JSON under `poses`.

The same file holds build-ready part lists for **Bunvolt, Cubloom and Flutterwink**. Canyon and Aurora species have behaviour, silhouette and palette specs (`03`, `mockups/creature_silhouettes.svg`) but **no part lists yet**: authoring them is part of WP-10 and WP-12.

## 3. The cinch

`mockups/cinch_storyboard.png` (five beats). Timeline data: `data/models/cinch_effect.json`.

| t | What happens |
| --- | --- |
| before | Snap preview (dashed Beam + ring marker) inside 9 studs of a snap point; two rising ticks |
| 0 | Loop flashes white for one frame at width 2.2; faint ground disc; `loop_close`; creatures predicted inside switch to CINCHED; the loop Trail is cleared and replaced by the ring |
| 0–0.30 s | Ring of 24 Beam segments shrinks toward the centroid (quad-in) to 22 % or 0.6 studs outside the outermost body, whichever is larger; chevron texture scrolls inward; `loop_cinch` |
| 0.30 s → result | Ring holds. At 0.8 s with no result it releases as a slip |
| result | Pops 0.06 s apart on the pentatonic ladder: 0.12 s squash, 12 sparks, arc into the parade. Escapees do the "nope" hop. Payout tag rises 4 studs over 1.2 s |
| by size | 5–7: ground shockwave + 30 confetti. 8+: taller confetti, arena toast, 0.15 s effects-only slow-down (omitted in reduced motion) |

Part cost: 1 ring host, 1 flash disc, 1 shockwave, 1 payout-tag host. Beams, attachments, emitters and billboards are not parts (§6).

## 4. Import-ready assets and what remains

**Exists in this package**

| Asset | File | Use | Engine settings | Fallback until uploaded |
| --- | --- | --- | --- | --- |
| Ribbon | `assets/textures/ribbon_trail.png` 256×64 | `Trail.Texture` (travel and loop trails) | TextureMode Wrap, TextureLength 8, LightEmission 0.6, FaceCamera false | Untextured Trail |
| Cinch ring | `assets/textures/cinch_ring.png` 256×64 | `Beam.Texture` ×24 | TextureLength 6, TextureSpeed 1.5, LightEmission 1 | Untextured Beams |
| Snap preview | `assets/textures/snap_dash.png` 128×32 | `Beam.Texture` | TextureLength 3, width 0.5 | Untextured Beam, width 0.3 |
| Pop spark | `assets/textures/pop_spark.png` 128×128 | `ParticleEmitter.Texture` | Size 0.9→0, Lifetime 0.25–0.45, Speed 6–12 | Default particle |
| Confetti | `assets/textures/confetti.png` 64×64 | `ParticleEmitter.Texture` | RotSpeed 180–360, 4 tints | Default particle |
| Telegraph ring | `assets/textures/telegraph_ring.png` 512×512 | Decal on a flat pooled part: hop ring, ghost ring, bloom radius | Transparency tween | Flat neon ring part |
| Route chevron | `assets/textures/route_chevron.png` 128×128 | Stampede route Beam, bank chevrons | TextureLength 6, TextureSpeed 2 | Untextured Beam |
| Creature part lists | `data/models/meadow_creatures.json` | CreatureKit | — | — |
| Cinch timeline | `data/models/cinch_effect.json` | Effects | — | — |

All textures are white with alpha, tinted in engine, procedurally generated by `tools/make_textures.py` (original, no third-party source; hashes in `assets/textures/manifest.json`).

**Remaining production work**

| Item | Who | When |
| --- | --- | --- |
| Upload the 7 PNGs to Roblox and record asset ids | Owner (account action) | Before or after Checkpoint 1; fallbacks work without them |
| Upload audio and run `tools/set_audio_ids.py` | Owner | Before Checkpoint 2 |
| Generate 4 new WAVs (§5) | WP-07 | Stage 1 |
| Part lists for the 8 Canyon and Aurora species, 3 Legends, Static Puff v2 | WP-10, WP-12, WP-13 | Stage 2 |
| Feature builders: translate the recipes in `data/asset_manifest.json` to code; the render is the proportion reference for Meadow | WP-05 | Stage 1 |
| Canyon and Aurora gameplay frames | Re-run `tools/render_refs.js` with those arenas once their builders' proportions are settled (script currently Meadow only) | Stage 2 |
| Icon, thumbnails, trailer | From the real game after Checkpoint 2 | Stage 3 |
| Music stems B and C, creature voices, ambience | WP-17 | Stage 3 |

## 5. Slice cues and audio — exactly what Checkpoint 1 plays

The authoritative list is `data/slice.json` → `cues`. Summary:

- **22 SFX cues**, 18 of them reusing WAVs that already exist in `assets/audio` (several at a different `PlaybackSpeed`), 4 new.
- **Catch pops use the existing `catch.wav`**, pitch-stepped per creature: `PlaybackSpeed = 2^(s/12)` for `s` = 0, 2, 4, 7, 9, 12, 14, 16.
- **Music:** existing `music_meadow.wav` with `music_meadow_finale.wav` faded in at 85 s. No new music in the slice.
- **No creature voices** except the Bunvolt hop wind-up (it is gameplay information), on `pop.wav` at speed 0.5.

New WAVs for WP-07 (add to `tools/generate_audio.py` using its existing voices and its peak/HF rules):

| File | Length | Recipe |
| --- | --- | --- |
| `loop_close.wav` | 0.18 s | `v_kick` 180 → 70 Hz (tau 0.05) + band-passed noise hit sweeping 1.2 kHz → 400 Hz, 0.09 s; the "thwip" |
| `loop_cinch.wav` | 0.30 s | High-passed noise rising 400 Hz → 3 kHz with a sine glide 300 → 900 Hz at −9 dB; 20 ms fade in, 40 ms fade out |
| `loop_whiff.wav` | 0.25 s | Low-passed (2 kHz) noise, exponential decay, plus a sine falling 500 → 250 Hz at −12 dB |
| `ribbon_tick.wav` | 0.12 s | Two `v_bell` notes, MIDI 84 then 88, 40 ms each, 60 ms apart |

**None of this is audible as intended until the owner uploads audio**: every catalog id is empty in `b1b62fd`, and the built-in `rbxasset://` fallbacks are unverified placeholders. Checkpoint 1 therefore does not judge sound. If the owner uploads before the checkpoint, sound questions move forward from Checkpoint 2.

Visual cues in the slice (`slice.json` → `visualCues`): ribbon, snap preview, cinch ring, catch pop, payout tag, telegraph ring (hop, bloom, ghost ring), boop ring, bank fountain, dash streak.

## 6. Performance: corrected baseline and how to measure

The first pass of this package misread three of the owner's F8 numbers. Corrected against the `b1b62fd` source (`Client.client.luau` ~500–535, `CreatureView.luau`, `Main.server.luau` ~1815–1865):

| Owner's reading | What it actually measures in `b1b62fd` | Status |
| --- | --- | --- |
| Frame 32.8 ms avg | Mean `RenderStepped` dt in a Studio play session. Includes Studio's own overhead and, in Play Solo, the server simulation in the same process | A real miss against the 16.7 ms budget. **Cause not established.** The first pass blamed per-frame creature movement; in fact `b1b62fd` already animates creatures on the client from 10 Hz snapshots with one `PivotTo` per visible creature per frame, and the server does not move models |
| Local effect parts 124 [≤ 80] | `#SparkLocalEffects:GetDescendants()` — every attachment, emitter, beam, billboard and label, not parts | **Not evidence of a part-budget breach.** The true part count was never measured |
| Herd 1.7 KB/s | Bytes of HerdNet packets received per second | **Within** `b1b62fd`'s own budget (≤ 6 KB/s). Not a problem. The new 1.2 KB/s target is a tighter goal, not a fix |

What is still true: creatures are server-created, replicated Models of roughly 14–22 welded parts each (about 54 of them across three arenas), all three arenas plus the Trial Grounds exist at once, and the frame budget was missed. The redesign removes replicated creature Models and builds decor only for the current arena, but whether that is what fixes the frame time is unknown until measured.

### F8 overlay v2 (WP-07) — six counters

| Counter | Definition | Budget |
| --- | --- | --- |
| Frame ms (p50 / p95, last 5 s) | `RenderStepped` dt | 12.5 / 16.7 desktop |
| **Effect parts** | `BasePart`s under `workspace.SparkFx` with `Transparency < 1` | ≤ 80 |
| Effect instances | Beams + Trails + enabled ParticleEmitters + enabled BillboardGuis under `SparkFx` and `PlayerGui` | ≤ 120 (hypothesis; set from the first measurement) |
| Creatures / creature parts | Models under `workspace.SparkCreatures`; their `BasePart` count | ≤ 30 / ≤ 320 |
| Arena parts | `BasePart`s under the current arena model + `workspace.SparkDecor` | ≤ 2,600 |
| Herd KB/s, claim deviation p99 | HerdNet bytes received; largest vertex-to-path distance on accepted claims | ≤ 1.2 avg; informational |

### Measuring frame time properly (owner; agents do not run Studio)

1. Use Studio's local server test with one player (Test tab), not Play Solo, so the client window's frame time excludes the server. Read the client window. (Menu names move between Studio versions; use whatever starts a separate server and client.)
2. Record F8 p50/p95 over two full rounds, once with the Studio window focused and nothing else running.
3. Open the MicroProfiler in the client window (Ctrl+Alt+F6 in Studio at the time of writing; check the current shortcut) during a Stampede and note the three widest labels. That, not a guess, identifies the cause.
4. For a like-for-like comparison, take the same reading on the `b1b62fd` build with the same method before judging the new build.
5. Real device numbers come from a private test place at Checkpoint 2 (M8 in `09`).
