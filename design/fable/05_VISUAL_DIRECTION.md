# 05 — Visual direction

Reference images produced in this package (all original, all generated from the design data): `maps/*.svg`, `mockups/hud_desktop.svg`, `mockups/hud_phone.svg`, `mockups/creature_silhouettes.svg`, `mockups/loop_anatomy.svg`. They are schematic references for layout, proportion and hierarchy, not renders of the game. No 3D render was produced; none is claimed.

## 1. The look in one line

**A sunlit toy diorama with one thing that glows: your ribbon.** Chunky rounded forms, flat saturated colour, soft real shadows, almost no emissive surfaces — so the ribbon, the creatures' telegraphs and the bank rings are the brightest things on screen.

## 2. Rules of composition

1. **Value hierarchy.** Ground is mid-value and low-contrast. Landmarks are light against the sky. Creatures are the most saturated objects. The ribbon is the only near-white emissive line.
2. **Three scales.** Every view should contain a skyline landmark (30+ studs), mid props (5–12 studs) and ground detail (< 2 studs, client-only decor). The current build has only the middle scale.
3. **No flat disc.** Ground is Terrain with gentle hills (≤ 7 studs), a water or ice feature, and a path colour that leads from spawn toward the first pod and the first bank ring.
4. **Rounded, thick, slightly squashed.** Minimum prop thickness 1 stud; corners read as soft. No thin poles, no text signs in the play space.
5. **Neon budget:** ≤ 40 emissive parts per arena. Emission means "interactive or imminent".
6. **Shadows on, small shadows off.** Landmarks, players and creature bodies cast shadows; nothing under 3 studs does.

## 3. Materials and palettes

Materials: Terrain (Grass, Sand, Sandstone, Snow, Glacier, Water) for ground; SmoothPlastic for props; Glass for crystal and lantern; Foil for the golden variant; Neon only inside the budget. Part-material noise (Slate, Grass, Sandstone on parts) is not used.

| Arena | Ground | Ground dark | Path | Water/ice | Wall | Accent | Accent 2 | Sky / light |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pop Meadow | 108,214,142 | 72,176,128 | 236,222,170 | 96,212,232 | 226,214,196 | 255,214,72 | 255,150,186 | Morning, 10:30, soft cumulus |
| Fizz Canyon | 236,170,116 | 196,112,92 | 255,214,160 | 94,234,239 | 214,120,96 | 94,234,239 | 255,240,150 | 16:40, low sun down the axis |
| Aurora Arcade | 206,214,250 | 126,118,220 | 170,180,240 | 150,236,255 | 168,183,243 | 244,146,226 | 120,255,220 | Night, aurora curtains |

Global constants: ink 27,36,64 · paper 255,249,231 · gold 255,217,90 · ribbon default 255,243,107.

Contrast requirements (checked in `09`): creature body vs local ground ≥ 3:1 luminance ratio in every arena; ribbon vs ground ≥ 4.5:1; hazards are identified by shape as well as colour.

## 4. Creatures

See `mockups/creature_silhouettes.svg` and `03` §6.

- **Silhouette first.** Each species passes the black-shape test at 60 studs.
- **Proportions:** head-body in one mass, features oversized (ears, wings, shell, antlers) and at least 40 % of the height for the "tall" species.
- **Animation (client, CFrame offsets only; no Humanoids or Motor6D):**

| Layer | Spec |
| --- | --- |
| Gait | Per species (hop, waddle, strut, skitter, glide, roll). 2–4 Hz, squash 10–15 % on contact |
| Anticipation | Every telegraph is a pose held for its duration: crouch, puff, spin-up, rear |
| Look-at | Eyes (pupil offset ≤ 0.12 stud) track the nearest player within awareness |
| Startle | 0.15 s stretch + a single pooled "!" (existing bang pool) |
| Cinched | Wide eyes, arms-in, 5° wobble |
| Caught | 0.12 s squash → 0.2 s pop scale 1.25 → arc into the parade |
| Parade | Follows in file with a 0.25 s lag per place, bobbing in time with the music beat |
| LOD | Full pose within 90 studs; position only beyond; nothing outside the player's arena |

## 5. The ribbon and capture celebration

| Element | Spec |
| --- | --- |
| Ribbon | 1.2 studs wide, flat on the ground, soft-edged; head opaque, tail 30 %; a brighter core line; player's cosmetic trail sets its colour |
| Length cue | The last 25 % of remaining length pulses gently (static in reduced motion) |
| Snap preview | Dashed white line from head to the snap point + a small ring at the snap point |
| Close | Whole loop flashes to white for one frame, then cinches |
| Pops | 12 species-coloured particles per creature, 0.06 s apart, rising pitch |
| Payout tag | World-space, at the centroid: score 36 px equivalent, tags beneath in gold; rises 4 studs over 1.2 s |
| ROUNDUP (5–7) | Adds a ring shockwave on the ground and confetti (30 particles) |
| STAMPEDE! (8+) | Adds a brief 0.15 s time-scale dip to 0.85 on effects only, a tall confetti column, and an arena-wide toast |
| Bank | Creatures arc through the ring one by one; ring flares; fountain burst sized to the parade |

Limits: no full-screen flashes, no screen shake, no strobing. Largest luminance change is the one-frame ribbon flash, confined to the ribbon. Reduced-motion mode removes FOV kick, pulses, time-scale dip and confetti columns and keeps every informational cue.

## 6. Camera presentation

Raised chase camera (`01` §6). Additional presentation beats:

- **Round start:** 1.2 s pull-back from the player to gameplay distance while 3-2-1 plays.
- **Stampede telegraph:** no camera take-over; an edge chevron points to the entry.
- **Legend arrival:** 1.0 s gentle 4-stud zoom-out, never a cut.
- **Results:** camera orbits the player and parade slowly behind the bottom sheet.

The camera is never taken away from the player during play.

## 7. Interface

Layout data and exact rectangles: `data/ui_layout.json`; mockups: `mockups/hud_*.svg`.

Hierarchy, in order of importance:
1. **The world** — ribbon, creatures, telegraphs, payout tags.
2. **Timer** (top centre) and **parade pips** (top left).
3. **Score + chain** (top right), **dash charges** (bottom centre).
4. Transient one-line **toast**; first-session **hint**.

Rules:
- Persistent HUD ≤ 9 % of the safe area (2.5 % desktop, 7.3 % phone in the reference layout).
- No panel is opaque, stroked or larger than 240 × 32 on desktop.
- One typeface for display, one for body; numbers tabular. Minimum 11 px on phone.
- Everything informational has a non-colour cue (label, shape or position).
- Menus are a right-hand drawer; results are a bottom sheet with a **Best Loop card** (a top-down drawing of the player's best loop of the round with its tags) — the shareable image of the round.
- Removed from the HUD: brand logo, objective paragraph, rank chip, glow balance, save status, event label, album card, CATCH button.

## 8. Recognisability

The thumbnail and icon should show exactly one idea: a character mid-dash closing a glowing ring around a cluster of wide-eyed Sparks, the Clover Tree behind. That image is the game.
