# Game sprites v3: Verdigris & Ember

Made 10 November 2026 by the art thread after Darren accepted the style ("update all graphics and sprites to this style and
pass to prototype, re work the rune animations etc as well so they are exaggerated like we used for testing").

This folder mirrors the prototype's `art/` folder. Copy it over `art/` and almost every file lands on the name the game already
loads. **Nothing here has been run in Godot.** The pictures in `preview/` are composed in Python with the same maths the notes
below describe, so expect tuning.

Style page: https://claude.ai/artifact/QMcYqfuC7n1db7bsUi2VGV

## Three conventions

1. **Sprites are unlit base colours.** The mood comes from a dark ambient tint plus stepped, hatched light textures.
2. **Glow layers.** Where a sprite has glowing pixels there is a `<name>_glow.png` beside it holding only those pixels (same
   size, same frames). Draw it on top of the sprite, unshaded (above the lighting, or with a light-mask the lights do not touch),
   so embers, eyes and runes stay bright in the dark. The JSON marks these with `"glow": true`. Skipping the glow layers still
   works, it just looks flatter.
3. **One palette.** Listed in `concept-art-3/code/core.py` (RAMPS). UI colours are in `swing/swing_path.json` under `ui.colours`,
   and palette versions of the rune colours in `rune_colours`.

## Update, 10 November evening: forge screen, menus, HUD and sword parts

Darren asked for these to be done properly, not only recoloured. Mock-ups: `preview/screen_forge.png`, `screen_title.png`,
`screen_hud.png`, `screen_pause.png`, `screen_talk.png`, and `preview/parts.png`. They are laid out with the numbers in
swing_forge.gd, title.gd and cave_ui.gd, so they show what the game should look like once wired.

The rule carried into the interface: **verdigris = idle, ember = live.** Plates are dark plum with a verdigris bronze edge;
whatever is selected, lit or speaking turns ember. Backgrounds are still.

- **Sword parts** (`swing/blades`, `grips`, `pommels`, `examples`): redrawn. Same image sizes, slot rects, pommel_at and
  blade outlines, so swing_path.json's anchors and the heat / shine strips still fit and **no code changes**. The sword is
  now a small copy of the forge: steel with a verdigris channel, bronze fittings, round sockets, down-swept quillons.
  Runes, bands and Relay keep their shapes in the new palette.
- **Menu kit** (`swing/ui`, `cave/ui`): redrawn at the same sizes and nine-patch margins, so they drop in.
- **Colours**: the constants at the top of swing_forge.gd, title.gd, cave_ui.gd and pause_menu.gd should take the values in
  `swing_path.json → ui.colours` (ink #e8e4bc, dim #8ba688, faint #5f8072, amber #ffc850, teal #86d4a4, focus #fff0b4,
  plate #19142a, well #0f0b18). GROUP_COLORS becomes `ui.colours.group_colours`. Player colours become madder red
  #f06a40 and sea blue #78c0cc, matching the scarves.
- **Forge screen** needs code: draw `swing/ui/forge_backdrop.png` full screen instead of the flat colour; put `panel.png`
  behind the tray (6,30,203,324) and the "what it does" column (412,34,222,302); draw the card wells with `well.png` and
  `well_selected.png`; and draw the sword at zoom 2 whenever it fits (height x 2 <= 322) so its pixels stay square.
  The current fractional zoom will smear the new detail.
- **Title screen** needs code: `swing/ui/title_backdrop.png` full screen instead of the tile strip and forge sprite, with
  `panel.png` behind the menu (28,98,276,142) and the players box (364,98,248,142); wrap the note at 252 px; hint line
  at y 348.
- **Pause menu**: `panel.png` at (230,104,180,150), buttons from `button.png` / `button_hot.png`.
- **HUD** (new folder `hud/`): pieces for a HUD drawn at 640x360 in Silkscreen 8 in place of the fallback-font one. Sizes
  are in `swing_path.json → hud`. Optional but it is what Darren will see in the mock-up.

## Drops in with no code change

Same file names, frame sizes, frame counts and anchors as before:

- `body/crew_a_*`, `body/crew_b_*`, `crew_a.json`, `crew_b.json`, `hand.png` (56x56, feet 28,52, six facings, same strips).
  The old `ivy_*` fallback strips were not redrawn.
- `swing/runes, bands, rare, forge-fx`: Darren's approved shapes, moved to the new palette (parts and menus: see the update above). `forge-fx/hearth.png` and `hearth_still.png` are new drawings (the sword forge's hearth), same sizes.
- `cave/crawler_*` (helm crab) and `cave/burrower_*` (pike worm): same frames and feet. The crab is a front view.
- `cave/smith_*`, `cave/smith_portrait.png`, `cave/dust_puff.png`.
- `swing/fx/chain_link.png`, `hook_head.png`, `hook_head_bite.png`, `dodge_pip.png`.
- The whole test arena: `enemies/` (slime is now a helm crab, charger a horned crab, brute a bell crab, dummy a post in an
  old helm), `tiles/`, `props/`. `anchors.json` is unchanged and copied here for completeness.

## Needs code changes

### Rune and hit effects (`swing/fx`, numbers in `swing/swing_path.json` → `fx`)

All strips are bigger and louder and are made for additive blending. Fades are drawn into the frames as a hatch dissolve, so
play them at full alpha. `player.gd::_strip` already reads frames, fps and origin from the JSON, so those just work. The
hardcoded ones:

| File | Old | New | Where |
|---|---|---|---|
| shockwave_wave | 6 frames 40x64, origin (0,32) | 6 frames 80x88, origin (50,44) | `rune_fx.gd` "wave": change `Vector2(0, 32)` to `Vector2(50, 44)`; drop the `fade * 2` alpha |
| slam_impact | 5 frames 64x64, origin (32,32) | 6 frames 96x96, origin (48,48), has a glow layer | `hazard.gd`: frames 6, origin (48,48). `size = radius / 56` still holds (hit circle is 28 px) |
| whirlwind_spin | 72x72, origin 36 | 96x96, origin 48 | read from JSON; the blade edge is still 36 px from the centre so the `/ (36 * PIXEL)` scale holds |

The wave's origin is now the middle of the hit line with the trail behind it, so the node position means the same thing.
`whirlwind_spin` sweeps clockwise starting at the aim direction; when the code flips it, it starts opposite the aim (the old
strip did the same). Add PI to the angle on the flipped side if that looks wrong.

The code-drawn pieces that are still code (hook reach ring, "pulse", "slash", floating text) can take their colours from
`rune_colours` in swing_path.json.

### Cave (`cave/cave.json`)

- **Ground.** `cave_ground.png` (784x1408) is the whole cave painted from cave.gd's own map: same rooms, halls, bumps and cut
  corners. Draw it once at map pixel (-64, -176) in art pixels instead of the floor, wall and lip tiles; background `#19142a`.
  Collision stays as it is. The old tile files are gone.
- **Awake floor.** `forge_floor_awake.png`: 8 frames of 464x510, drawn at map pixel (96, -110), unshaded, looping at 8 fps,
  once the forge wakes (lit channels with metal running from the hearth).
- **Lighting.** CanvasModulate about (0.31, 0.35, 0.53). Lights use `lights/light_r<radius>_s<steps>.png` at texture_scale 2
  and nothing else, or the hatch blurs; pick the radius by file. Positions, colours and energies are in
  `cave.json → lighting`. A small cool light on each player keeps them readable.
- **Forge.** Now the colossal sword, 210x192 with feet at (115,190), and it moved to the middle of the north wall: tile
  (20.5, 6.88). `forge_awake` is 4 frames at 8 fps. It rises about 80 px above map row 0, so the camera's top limit should let
  it show. Its two braziers moved to (15.75, 8.19) and (25.25, 8.19). The forge interact point moves with it.
- **Guardian.** A knight now. Frame 128x146, feet (64,136) (was 64x64, feet 32,58). `wake` has 5 frames (was 4); all other
  counts are the same. `slam_at` (0,4), `slam_radius` 30. He stands 98 px tall and blocks about 44x20 px at the feet.
  `dormant`, `wake`, `stunned` and the end of `death` are a kneeling profile facing right; fighting poses are front views.
  He starts kneeling on the casting circle at tile (20.5, 12.62). `death` ends on the empty kneeling suit, which also stands
  as a prop in the room's dark corner (`guardian_ruin` in the layout).
- **Gate.** 56x48, feet (28,47) (was 48x32, origin 24,32). `gate_open` is a flat threshold to walk over.
- **Props.** Almost every prop changed size and feet; read them from `cave.json → props` (cave.gd's `_prop` already does).
  `cage` is 36x54, feet (18,49). `collapse` is 299 px wide, feet (144,46). New optional props: anvil, trough, coal_heap(_lit),
  bellows, ingots, lantern, quillon_piece, giant_blade.
- **Layout.** `cave.json → layout_map_px` lists where everything stands in the preview pictures, with "keep", "moved" or
  "new" on each line.

## What to look at

`preview/cave_forge_awake.png`, `cave_forge_asleep.png`, `cave_room1.png` (the real map layout, composed with the lights),
`preview/effects_loop.gif` (every effect, blended additively on the cave floor), `preview/arena.png`.

## Drawing code

`/mnt/project-files/art/concept-art-3/code/`: `core.py` (palette, lighting), `cave_ground.py`, `v3_props.py`, `v3_chars.py`,
`v3_enemies.py`, `knight.py`, `v3_cave.py` (cave export), `v3_swing.py` (palette remap), `v3_fx.py`, `v3_arena.py`.

## After the first in-engine run (10 November, prototype commit 98d48db on swing-path)

The prototype thread wired both drops in and ran them in Godot 4.7. Screenshots: `/mnt/project-files/proto-shots/v3-style/`.
What it changed from the numbers above, so the two stay in step:

- Cave ambient is 15% brighter; each player's light is r64 at 0.55.
- Anvil at tile (22.9, 9.5), trough (18.1, 9.6), ingots (23.9, 10.0) to leave a walkway. Bellows and coal heap at y 6.9 so
  they draw in front of the forge step.
- The stairs and their two braziers stay dark until the way out opens.
- Whirlwind: PI added to the angle on the flipped side.
- Forge screen blade cards are 61 px wide so the longblade icon fits.
- Helm crab and pike worm were drawn 1.7x brighter in code because they sank into the floor in rooms 2 and 3. **Art fix,
  same day:** both are one palette step brighter and their top edge is now in the `_glow` layer as a thin lit rim
  (`cave/crawler_*`, `cave/burrower_*`, and the arena's `enemies/slime_*`, `charger_*`). With the glow layer drawn unshaded
  the 1.7x should not be needed.

## Gap fill, 10 November evening: everything on the prototype's "missing art" list

Darren asked what art was still missing. The prototype thread's list is `/mnt/project-files/art/requests/prototype-missing-art.md`
(A1 to A22, B1 to B7, C1, C4 and section D are done here). **`gaps.json`** at the top of this folder lists every new file
with its frame size, frame count, fps, origin, whether it has a `_glow.png`, and a note on how to draw it. Drawing code:
`v3_gaps.py`, `v3_gaps2.py`, `v3_gaps3.py`, `v3_gaps4.py`. Pictures: `preview/screen_fight.png` (a mock fight using the
pieces together), `gaps_combat.png`, `gaps_smear.png`, `gaps_cave.png`, `gaps_cards.png`, `gaps_forge_hud.png`,
`gaps_arena.png`, `gaps_crate.png`.

### Where I departed from the sizes you asked for (all in gaps.json)

| Item | You asked | Delivered | Why |
| --- | --- | --- | --- |
| A2 hit sparks | 32 x 32, crit 48 x 48 | `hit_spark` 40 x 40 (20, 20), `hit_spark_crit` 56 x 56 (28, 28) | room for the flung lines |
| A3 death burst | bronze flecks, verdigris dust | `fx/death_burst.png` as asked; it is a verdigris ring (what was awake goes back to green) with bronze flakes | |
| A5 shadows | s / m / l / xl | as asked: 16x6, 24x9, 40x14, 64x20 | |
| A8 lanes | one 16 x 24 tile stretched to 18 or 40 wide, plus a cap | two native widths, no stretching: `fx/warn_lane_thin_*` (16 long x 18) and `fx/warn_lane_wide_*` (32 long x 40), each as `_aim` and `_lock`, 4 frames, plus `_cap` (12 long) | stretching across breaks the 1 px hatch and rails |
| A9 warning circle | one 64 x 64 at radius 28, scaled | `fx/warn_circle_r92.png` (100 x 100) and `fx/warn_circle_r58.png` (66 x 66), 8 frames each, drawn 1:1 | 92 / 56 is not a whole number, so a scaled ring goes ragged |
| A10 falling rock | 32 x 64 | 48 x 64, feet (24, 60) | the break needs the width |
| A11 stun stars | 24 x 10 | 30 x 14, origin (15, 7) | |
| A19 rune pickup | 32 x 48 | 32 x 56, origin (16, 52), additive | the rune lifts 8 px |
| B5 tabs | 12 x 14 | as asked; `tab_selected` uses the full height, `tab` starts 2 px lower | the chosen tab stands proud |
| extra | | `swing/fx/hurt_burst.png` (a player takes a hit), `fx/blank_stone_pickup.png`, `fx/broken_band_pickup.png` | |

### Existing files that changed (same names)

- **`body/crew_a_*`, `body/crew_b_*` (all strips):** scarves one step brighter, and every strip now has a `_glow.png` with a thin
  lit rim along the top edges (draw it unshaded on top, like the crabs). Sizes, feet and hands unchanged. `crew_*.json` has
  `"glow": true`. New strips `crew_a_down`, `crew_b_down` (3 frames, hold the last).
- **`cave/crate_closed.png` 34 x 24, feet (17, 22), with `crate_closed_glow.png`; `cave/crate_open.png` 34 x 32, feet (17, 30).**
  Was 22 x 13 and 22 x 15. `cave.json → props` is updated.
- **`cave/cave.json → lighting`:** one more light, "roof crack over the giant blade (room 1)" at map px (380, 968), r128,
  daylight, 0.7. Move the lantern to feet (258, 984) so it clears the wider crate (`layout_map_px` is updated).
- **`enemies/brute_*`:** bell one palette step brighter and a rim in the glow layer. **`enemies/dummy*`:** rim in the glow
  layer, so `dummy_idle_glow.png` now exists.

### Not drawn, on purpose

A title wordmark (the game has no name yet), Mirror and the other parked runes, players 3 and 4, and the bow, staff and
hammer parts (C2, C3, C5): those wait for the bow to be built, as you asked.

### Fixes after the first run in the engine (10 November, 19:40)

The prototype reported three pieces that read badly. All three keep their file names.

- `swing/pommels/heavy_pommel_icon.png` is now 26 x 26 (was 41 x 26) so it fits its tray card.
- `fx/stun_stars.png` is now 6 frames of 44 x 22 with origin (22, 11) (was 30 x 14, origin (15, 7)). Four stars, bigger, each with a dark edge. `gaps.json` has the new numbers.
- `cave/ui/hint_plate.png` is a solid dark plate with a thin verdigris line (same 12 x 14 nine-patch, margin 4). Draw it at full alpha.

Preview: `preview/gaps_fixes.png`. Code: `concept-art-3/code/v3_gaps5.py`.
