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
