# Game sprites (milestone 2, Pixel forge)

Everything here is sized for a **640x360** base resolution. All files are PNG with transparency and should be imported with nearest filtering. Frames in a strip run left to right in one row, and every frame in a strip is the same size. The full numbers, including the hand point for every body frame, are in `anchors.json`.

The sprites are unlit base colours. The darker forge-lit look in `mockup_arena.png` comes from lights: `CanvasModulate` around (0.6, 0.62, 0.8), plus warm `PointLight2D`s on the torches and the forge bench. The fire, water and lightning shard edges are meant to stay bright, so draw the sword on a layer the CanvasModulate doesn't darken, or give it its own light.

For the outline shader to be exactly one game pixel, use stretch mode `viewport` (640x360 viewport, window 1280x720).

## Sword parts: `parts/`

| File | Size |
|---|---|
| `<part id>_hand.png` | 5 px per grid cell, used in hand |
| `<part id>_grid.png` | 18 px per grid cell, used on the forge screen |

Each image covers exactly the part's bounding box on the grid, with the tip at the top. To build the sword, place every part at `(col * cell, row * cell)` of its top-left grid cell. The parts then join up as they do on the grid:

```
bbb     rows 0-2 blade area (shards 1x3, Wooden Blade 1x3, Iron Longblade 2x3)
bbb
bbb
hhh     row 3 hilt (Wooden and Cross Hilt 3x1, Spin Hilt 1x1 in the centre column)
cgc     row 4 charms either side of the handle (1x1, they hang from the hilt on a cord)
.g.     rows 4-5 handle (1x2)
.p.     row 6 pommel (1x1)
```

| Part id | Cells (w x h) | In hand | Grid |
|---|---|---|---|
| wooden_blade, fire_shard, water_shard, lightning_shard | 1 x 3 | 5 x 15 | 18 x 54 |
| iron_longblade | 2 x 3 | 10 x 15 | 36 x 54 |
| wooden_hilt, cross_hilt | 3 x 1 | 15 x 5 | 54 x 18 |
| spin_hilt | 1 x 1 | 5 x 5 | 18 x 18 |
| wooden_handle, wrapped_handle, long_handle | 1 x 2 | 5 x 10 | 18 x 36 |
| wooden_pommel, curved_pommel, spike_pommel | 1 x 1 | 5 x 5 | 18 x 18 |
| swift_charm, keen_charm | 1 x 1 | 5 x 5 | 18 x 18 |

- **The whole sword in hand** is 15 x 35 px, with the tip at the top.
- **Pivot (where the hand holds it):** cell (1.5, 5.0), which is the joint between the two handle cells. In hand that's pixel (7.5, 25).
- **Rotation:** rotate the sword around the pivot with `rotation = aim_angle + PI / 2`, because it's drawn pointing up.
- **Outline:** the parts have no outline, so they butt together cleanly. Put them all under one `CanvasGroup` with `shaders/outline.gdshader` to give the assembled sword one dark outline.
- **Hand:** draw `body/hand.png` (7x7, centred) on the pivot, on top of the sword. That puts the fist on the grip in every direction.
- **Examples:** `parts/examples/` has three assembled swords for reference (wooden, steam and heavy), at both sizes.

## Crew body: `body/`

The body has no weapon. It's Ivy, in blue to match the prototype's player.

| Strip | Frames | Suggested fps |
|---|---|---|
| `ivy_idle_<dir>.png` | 4 | 6 |
| `ivy_walk_<dir>.png` | 6 | 10 |
| `ivy_dodge_<dir>.png` | 3 | 24, so it fits the 0.12 s dodge |

- **Directions** (`<dir>`): `down`, `up`, `right`, `left`. Left is right mirrored, already flipped for you.
- **Frame:** 56 x 56. The origin (the feet, where the node's position is) is at **(28, 52)** in every frame.
- **Dodge:** frame 1 is a crouch, frame 2 is the dash with a faint after-image and speed lines (these use partial alpha), and frame 3 is the recovery.
- **Choosing the direction:** pick it from the aim, so the sword always points roughly the way the body faces.
- **Draw order:** the sword goes in front of the body, except when facing **up**, where it goes behind.

**Hand anchor (where the sword pivot goes), in frame pixels.** Idle and walk bob by a pixel, and the exact point for every frame is in `anchors.json` under `body.strips.<anim>_<dir>.hand`.

| Direction | Idle / walk | Dodge frames 1, 2, 3 |
|---|---|---|
| down | (21, 38) | (21, 38) (21, 39) (21, 40) |
| up | (35, 38) | (35, 40) (35, 37) (35, 38) |
| right | (33, 38) | (33, 39) (36, 38) (33, 39) |
| left | (22, 38) | (22, 39) (19, 38) (22, 39) |

## Enemies: `enemies/`

All of them face right. `<kind>.png` is a single still frame (the first idle frame), for the game as it is now.

| Kind | Frame | Origin (feet) | Strips (frames, fps) |
|---|---|---|---|
| slime | 32 x 32 | (16, 28) | idle 4 @6, move 6 @10 (a hop), hit 2 @12 (white flash), death 4 @8 (splat, fades out) |
| charger | 32 x 32 | (16, 28) | same as slime; red, with horns and angry brows |
| brute | 52 x 48 | (26, 44) | same as slime; big purple, scarred, with a jagged mouth |
| dummy | 34 x 50 | (16, 46) | idle 1, hit 4 @14 (flash, then wobbles back) |

Strip files are `<kind>_<anim>.png`. The death strip's last frames use partial alpha.

## Tiles: `tiles/` (16x16, seamless)

| File | What it is |
|---|---|
| `floor.png` | Packed earth, the main floor |
| `floor_1.png`, `floor_2.png` | Pebbles and moss variants, to scatter at random |
| `floor_3.png` | Flagstone. A patch of these joins into one paved area (paths, the forge corner) |
| `wall.png` | Brick wall face, works on all four sides |
| `wall_top.png` | Capstones seen from above, for the top edge of the north wall if you want depth |

## Props: `props/`

| File | Size | Origin (feet) | Notes |
|---|---|---|---|
| `forge_bench.png` | 46 x 32 | (23, 30) | Anvil, tools, a hot blade blank and a lantern |
| `torch.png` | 9 x 36 | (4, 34) | Flame at about (4, 4); put a warm light there |

## Other files

- `mockup_arena.png` (1280x720, the 640x360 view at 2x) and `mockup_arena_640x360.png` (native size).
- `overview.png` shows everything on one sheet.
- The generator code is in `art/concept-art-2/` (`gs_parts.py`, `gs_body.py`, `gs_world.py`, `gs_export.py`). Rerun `python3 gs_export.py` there to rebuild every file.
