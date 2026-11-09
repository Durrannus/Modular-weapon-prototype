# Tutorial cave art (9 November)

This is the art for the four-room tutorial cave in the Game Plan. Sizes, frame counts, fps and feet points are all in `cave.json`. Everything is unlit base colour, like the rest of game-sprites/. Enemies face right or the camera, so mirror them for left. Import with nearest filtering.

## Batch 1: rooms 1 to 3

**Tiles (16x16)**
- `floor_0..3`: the cave floor. Variant 3 has a faint damp patch.
- `floor_wet_0..1`: damp sand for near the entrance.
- `rock_top_0..1`: the dark rock fill.
- `wall_face_0..2`: the rock face. Its lit top lip is already built in.
- Overlays: `lip_n`, `lip_e`, `lip_w`, `lip_ne`, `lip_nw` and `shadow_n`.

**Gate (48x32)**
- `gate_closed`, `gate_open` and `gate_opening` (4 frames).
- It has rock pillars, a lintel and an iron portcullis. The shut gate has an amber keyhole plate.

**Entrance**
- `collapse` (82x50) has boulders, ship planks and torn sail.
- `rubble_0` and `rubble_1` are loose pieces.

**Ship bits**
- `crate_closed` and `crate_open` (34x34 with the outline, feet in the JSON). The open one shows four weapon hilts.
- `planks`, `barrel` and `sail`.

**Rune**
- `pedestal_rune` has an amber Shockwave stone floating over the plinth. `light_px` in the JSON says where to put a light.
- `pedestal_empty` is the plinth after the stone is taken.

**Dressing**
- `stalagmite_small` and `stalagmite_large` block movement.
- `mushrooms_0..1` glow teal.
- `bones_0..1`.

**Crawler** (32x32, feet at (16,28)): an ochre beetle.

| Strip | Frames | What |
|---|---|---|
| `crawler_idle` | 4 | idle |
| `crawler_move` | 6 | walking |
| `crawler_attack` | 3 | rear up, bite, recover. The pincers snap out to the right on frame 1. |
| `crawler_hit` | 2 | hit flash |
| `crawler_death` | 4 | death |

**Burrower** (32x32, feet at (16,28)): a violet worm.

| Strip | Frames | What |
|---|---|---|
| `burrower_idle` | 4 | swaying out of its hole |
| `burrower_move` | 6 | burrowed, so only the mound shows |
| `burrower_warn` | 2 | loops; it flashes red |
| `burrower_lunge` | 3 | launch, stretched out, land |
| `burrower_stunned` | 2 | loops; flopped on the floor with an X eye, open to hits |
| `burrower_hit` | 2 | hit flash |
| `burrower_death` | 4 | death |

**Preview:** `preview_batch1.png` is a test room built with the grid rules from proto-needs/cave_art_needs.md.

**Code:** `art/concept-art-2/cave_art.py` and `cave_export.py`. Run `python3 cave_export.py 1`.

## Batch 2: room 4 (forge and boss)

All sizes, feet points, frame counts and fps are in `cave.json` (`enemies.guardian`, `fx`, `props`).

**Guardian** (`guardian_*`, 64x64 frames, feet (32,58), drawn facing right; mirror for left). It is a squat stone golem with an amber rune in its chest. The rune and eyes are dark while it is a statue and whenever it is helpless.

| Strip | Frames | What it shows |
|---|---|---|
| `guardian_dormant` | 1 | the statue: no eyes, dark rune |
| `guardian_wake` | 4 | rune lights, white flash, stands |
| `guardian_idle` | 4 | slow breathing |
| `guardian_move` | 6 | heavy walk |
| `guardian_telegraph` | 3 | both fists up, last frame flashes white |
| `guardian_slam` | 4 | frame 0 is the impact (spawn `slam_impact` then), dust on 1 and 2, recover |
| `guardian_charge_ready` | 2 | loops; crouched, leaning right, leading shoulder down, rune white-hot |
| `guardian_charge` | 2 | loops while sliding; hard lean with speed streaks behind |
| `guardian_stunned` | 3 | loops; slumped, eyes and rune out, stars round the head: the player's opening |
| `guardian_hit` | 2 | hit flash |
| `guardian_death` | 6 | crumbles; the last frame is the rubble pile and stays |

`slam_at` is [0, -4] from the feet and `slam_radius` is in the JSON (the fists land either side of that point).

**FX:** `slam_impact` (64x64 x5, centred on (32,32): flash, cracks and a dust ring that spreads) and `dust_puff` (16x16 x4).

**Forge:** `forge_dormant` and `forge_awake`, 98x66 with feet at (49,64). `light_px` on the awake one is where to put an amber light.

**Smith:** 56x56 frames, feet (28,52), facing down, the same size as crew_a. `smith_caged` (4, hunched and dim), `smith_idle` (4), `smith_talk` (2), and `smith_portrait.png` (48x48, already on a dark panel).

**Cage:** `cage_back`, `cage_front`, `cage_broken`, 48x56, feet (24,52). Draw cage_back, then the smith with his feet on the same point, then cage_front. When he is freed, swap cage_front for cage_broken and keep cage_back.

**Stairs:** `stairs_up`, 48x48 (3 tiles wide), feet (24,47). Put its bottom edge on the bottom edge of the north wall face row, so it covers the wall face and the rock row above it. `light_px` marks the daylight at the top.

**Brazier:** `brazier_unlit` (1 frame) and `brazier_lit` (3 frames, 6 fps), 18x34 per frame, feet (9,32).

**Preview:** `preview_batch2.png` (several guardian poses in one room, for checking only).

**Code:** `cave_art2.py` and `cave_export2.py`. Run `python3 cave_export.py 2`. The smith uses the `bald` and `extra` options added to `cb_small.py`.

## Batch 3: sword parts and the second player

These live with the other swords and crew, not in this folder.

- **Sword parts:** `wooden_blade` (0 slots), `tin_blade` (1 slot) and `tin_grip` (1 slot) are in `game-sprites/swing-path/blades/` and `grips/`, with entries in `swing_path.json`. See the last section of `swing-path/swing_path.md`. Both blades are exactly `iron_blade`'s size.
- **Second player:** `crew_b_*` and `crew_b.json` are in `game-sprites/body-crew/`. He is crew_a recoloured (blonde hair, rust shirt, khaki trousers) with identical frames and hand anchors.

## Batch 4: small UI pieces (`ui/`)

Sizes, margins and the fill rectangle are under `ui` in `cave.json`.

| File | Size | Use |
|---|---|---|
| `ui/dialogue_box.png` | 48x48 | 9-slice, margins 8. The forge panel's plate and rivets with an amber line under the top edge |
| `ui/dialogue_name.png` | 24x14 | optional name plate, 9-slice with margins 4, 2, 2, 3 (left, top, right, bottom) |
| `ui/dialogue_more.png` | 8x8 x2 | optional "continue" arrow, 3 fps |
| `ui/prompt_e.png`, `prompt_e_down.png` | 16x16 | E key, up and pressed |
| `ui/prompt_pad_a.png`, `prompt_pad_a_down.png` | 16x16 | gamepad A, up and pressed |
| `ui/boss_bar_frame.png` | 160x12 | frame with a dark window at `fill_rect` [8, 3, 144, 6] |
| `ui/boss_bar_fill.png` | 144x6 | the red fill: crop its width to health x 144 and draw at (8, 3) |
| `ui/boss_bar_lost.png` | 144x6 | optional pale bar to draw under the fill at the old width after a hit |

Text: Silkscreen 8 for names and prompts, Pixelify Sans 11 for speech, as on the forge screen. `smith_portrait.png` (48x48) sits at the left inside the box.

**Preview:** `preview_batch4.png`. **Code:** `cave_ui.py`.
