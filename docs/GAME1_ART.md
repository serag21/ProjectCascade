# Spark Stampede — environment and creature art

Date: 2026-10-25. Status: implemented offline; Roblox rendering, animation feel, camera, navigation, lighting and mobile performance are **not verified**. This is an authored procedural art foundation, not a visual acceptance sign-off.

## Authored direction

One family of soft vinyl creatures inhabits three bright floating arenas. Strong silhouettes carry identity; yellow goal landmarks, dark sign panels, pale paths and low scenery carry navigation. Neon is confined to bank rings, beacons, mineral cores and plinth trim. There is no world strobe, automatic screen shake, or particle spam. Creature faces share rounded white eyes, dark pupils, glints, cheeks and little feet.

The primary chase floor is open and readable. Four low circular islands provide flanking choices. Tall scenery stays outside the chase boundary. The south opening reaches a small arrival/showcase plaza; banking always stays at the south side. Separate maps preserve the same landmark vocabulary while changing color and shapes.

| Arena | Identity | Landmark and scenery |
| --- | --- | --- |
| Pop Meadow | Mint floor, butter-yellow accents, blush canopies | Rounded cloud trees, oversized three-leaf clovers, pale glow-bud islands |
| Fizz Canyon | Apricot floor, cyan accents | Three-tier sandstone mesas, teal mineral crowns, square mineral island markers |
| Aurora Arcade | Lavender floor, orchid accents | Leaning glass crystal clusters, steady pale cores, pearl-topped islands |

All environment and creature geometry is original code-authored Roblox primitive geometry. No marketplace model, texture, external mesh, third-party character, paid asset, or copyrighted game art is embedded. Built-in Roblox materials and Gotham fonts are used. This module does not provide music or sound IDs; audio requires its own provenance and listening pass. This implementation does not depend on ImageGen.

## Twelve silhouette specifications

| Species | Shape key | Distinctive geometry |
| --- | --- | --- |
| Pip Pop | orb | Round body and paired sprout buds |
| Bunvolt | ears | Tall slanted ears with light inset |
| Cubloom | cube | Square body, pale sugar cap and sprinkles |
| Flutterwink | moth | Broad paired wings, eye spots, tipped antennae |
| Sunshell | shell | Raised back shell with layered spiral discs |
| Zip Tail | comet | Tapering three-bubble comet tail |
| Prism Prickle | prism | Diamond body, crest, detached side crystals |
| Dune Fin | fin | Wide side flippers and prominent dorsal fin |
| Crownlet | crown | Five-point golden crown and circular ruff |
| Ribbubble | ribbon | Long body, large bow loops and trailing ribbons |
| Starwhirl | star | Five elongated radial lobes |
| Antlume | antler | Branching golden antlers with pale buds |

Every creature has a stable invisible `Root` PrimaryPart at its origin. The face points toward local negative Z. Parts named `Wing`, `Ear`, `Foot`, `RibbonTail`, and similar are available to a later animation pass. Currently the module itself is static: movement/bob animation belongs to runtime code. Do not call model generation “animated” without testing the runtime. Each model carries `Species` and `Silhouette` attributes. Gameplay assigns `CreatureId`.

## Source and API

Canonical source: `game/ServerScriptService/Spark/World.luau` until the verified deployment workflow activates it. `World.build(Config)` builds and mounts a new `Workspace.SparkWorld` Model, with a `Creatures` Folder and one Model per biome. It returns:

```luau
{
    root = Model,
    arenas = {
        { origin = Vector3.new(0, 0, 0),   spawn = Vector3.new(0, 3, 38),   bank = Vector3.new(0, 0, 44),   radius = 65 },
        { origin = Vector3.new(300, 0, 0), spawn = Vector3.new(300, 3, 38), bank = Vector3.new(300, 0, 44), radius = 65 },
        { origin = Vector3.new(600, 0, 0), spawn = Vector3.new(600, 3, 38), bank = Vector3.new(600, 0, 44), radius = 65 },
    },
    hub = Vector3.new(0, 3, 62),
}
```

Floor top is exactly Y=0. The visible bank pad radius is 9 studs; its glow ring radius is 10.5. Spawn is six horizontal studs from the bank center. Bank pillars at offsets `(±10, 6, 48)` leave a clear central path. Steering islands are radius 4.5, height 2.2, with centers at all four `(±26.163, 0, ±26.163)` combinations relative to each arena. Creature AI should avoid these circles; creature models have collisions disabled. The visible boundary is radius 69 with an open south entrance. The plaza extends to radius 76; a player movement bounds rule must allow that space. Creatures can remain inside radius 65.

`World.creature(def, parent)` returns an anchored, non-colliding `Model`. Call `PivotTo` to position it. Definitions use Config's RGB byte triples and the twelve shape keys above. Construction has no perpetual loops, event subscriptions, remote endpoints or external asset requests. All decoration has `CanTouch=false`; only intentional obstacles, floors and boundaries have `CanCollide=true` and `CanQuery=true`.

The world builder yields between rim batches and arenas. It modifies Lighting (daylight, ambient, fog) and adds `SparkAtmosphere` if absent. It does not delete any prior world, Terrain, lighting effects or archive. The caller is responsible for intentionally removing/replacing the previous active scene after the source-integrity gate. Calling it repeatedly without removing previous worlds is unsupported and would duplicate geometry. Existing non-Spark lighting effects must be inspected during integration so archived horror post-processing does not contaminate the new art.

## Reproducible offline checks

Executed on Windows PowerShell, official Luau CLI 0.744, 2026-10-25:

```powershell
.tools/luau/luau-compile.exe --null game/ServerScriptService/Spark/World.luau
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SparkWorldSmoke.ps1
```

Both final commands exited 0. Constructor smoke output:

```text
PASS offline constructor smoke: 3 arenas, 12 distinct shape ids, 609 world instances, 565 world parts, 123 colliders, 206 creature parts, 27 construction yields
NOT TESTED: Roblox rendering, physics, camera, client FPS, device scaling, live navigation, gameplay, sound
```

The harness executes current Config and World source against a deliberately limited mock of Vector3, CFrame, Color3, Instance, Lighting and task.wait. It checks positive part sizes, anchored/no-touch geometry, floor cylinder orientation and top height, tree trunk cylinder orientation, bank/spawn geometry contract, all twelve shape branches, creature collision flags, construction yielding and a world budget below 1,000 Parts. Its `CFrame.lookAt` mock retains position only, so beam orientation is **not** established by this test. Mock enums accept arbitrary strings and cannot verify Roblox API support. Count is construction count, not a measured live instance count, memory estimate or frame-rate claim.

The first smoke run failed a test expectation that required 17 parts per creature: Pip Pop intentionally has 15. The lower bound was corrected to 15 after inspecting the authored face/body/bud structure, and the final smoke passed. A manual source pass also found and fixed an incorrectly oriented cylinder tree trunk before the recorded passing run.

## Live art acceptance still required

- Capture all three arenas at character eye level and intended maximum camera zoom; inspect floor seams, horizon, shadows, canopy obstruction and bank label size.
- Walk and dash every lane and bank entrance; traverse the arrival plaza and confirm no bounds correction, camera clipping or scenery dead end.
- Check twelve silhouette contact sheets at normal chase distance and on a mobile viewport; verify distinction and forward-facing expressions.
- Test silhouette motion, wing/ear animation, capture anticipation, banking effects and reduced-motion behavior. This module has no particle or animation system.
- Confirm AI routes around low islands and cannot leave a creature inside a collider or below the floor.
- Review rendered color contrast and billboard text on narrow devices; fixed billboard sizes need actual device review.
- Measure representative mobile performance at configured maximum creatures and four players. Anchored multi-part moving models may need mesh consolidation or lower replication frequency after profiling.
- Populate showcase plinths with the player's earned collection; static plinths alone do not establish a working showcase system.
- Review music and positional audio using verified permissible assets; no audio listening evidence exists in this art document.

No Studio screenshot or first-person observation is available for this offline batch. Do not describe this batch as artistically polished or release-ready until those checks are performed and weaknesses corrected.
