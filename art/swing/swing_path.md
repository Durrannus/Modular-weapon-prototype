# Swing path sprites (3 November)

These are the art for the swing path sword and the forge screen, in Pixel forge at a **640x360** base resolution. Import every PNG with nearest filtering. All the numbers are in `swing_path.json`.

Darren's calls (3 Nov) shape what's here:
- Iron blades only for now. Elements are parked, so there are no fire, water, lightning or poison blades yet. The code can draw them when they come back.
- Runes are glowing amber stones socketed into slots. Bands are teal metal rings that flash.
- The forge shows the sword upright over an anvil, with a parts tray and a live "what this sword does" panel.
- Blades and grips have 1 to 3 slots. There are two special grips.

## The sword

A sword is one blade plus one grip, plus whatever sits in their slots. It is read as one line from the bottom of the grip to the tip of the blade.

Every part comes at two scales:

| Scale | Suffix | Slot size | Use |
|---|---|---|---|
| hand | `_hand.png` | 3 px socket, 4 px apart | the sword in Ivy's hand |
| forge | `_forge.png` | 9 px socket, 12 px apart (3x, so long blade + long grip is 204 px) | the forge screen |

### Blades: `blades/`

| Id | Slots | Hand size | Forge size |
|---|---|---|---|
| iron_shortblade | 1 | 7 x 23 | 21 x 69 |
| iron_blade | 2 | 7 x 33 | 21 x 99 |
| iron_longblade | 3 | 7 x 45 | 21 x 135 |

The blade is 5 px of steel in a 7 px wide image (the band rings overhang it). It has a long taper and a fuller groove. The slots sit low, in a brass-edged rune plate just above the guard. (Redrawn longer on 3 Nov, after Darren found the first version stubby.)

### Grips: `grips/`

Each grip image runs, from top to bottom: the guard (3 rows), the hold where the hand goes (5 rows), the socket collar (4 rows per slot) and the pommel (3 rows). The hand sits right under the guard, and the grip slots are below it. (Changed on 3 Nov after Darren saw the sword held at the end.)

| Id | Slots | Kind | Hand size |
|---|---|---|---|
| wooden_grip | 1 | craftable | 15 x 15 |
| wrapped_grip | 2 | craftable | 15 x 19 |
| long_grip | 3 | craftable | 15 x 23 |
| ringed_grip | 2 | special: a built-in band locked into the pommel, for "boosts the whole sword" | 15 x 19 |
| gilded_grip | 2 | special: the top slot is an odd slot, with a ruby rim | 15 x 19 |

A longer grip is a longer sword, which fits "long grip swings slower".

### Putting it together

Work in a sword frame that is `15 * k` wide, with the tip at the top (k = 1 in hand, 3 on the forge):

1. **Blade:** place it at `(4 * k, 0)`.
2. **Grip:** place it at `(0, blade height)`. The blade's bottom row then sits on the guard.
3. **Slots:** read them from the bottom up. First the grip's `slot_rects`, then the blade's, each offset by its part's position. JSON lists them bottom-up, so slot 1 is the first grip entry.
4. **Rune:** put the stone's top-left on the slot rect's top-left. Stones are exactly socket-sized (3 or 9 px).
5. **Band:** use `bands/<id>_<host>_<scale>.png`, where host is `blade` or `grip`. Centre it on the slot horizontally, and line its top up with the slot's top. Bands are 7 x 3 in hand (21 x 9 on the forge), the same size on a blade and a grip. They overhang the part by one pixel (3 on the forge) on each side, so they read as a ring around it.
6. **Pivot (the hand):** the grip's `pivot` plus the grip's offset. In hand it is at grip y 5.5 (16.5 on the forge), the middle of the hold just under the guard. Rotate the sword round it with `rotation = aim_angle + PI / 2`, as before.
7. **Draw order and outline:**
   - Draw `body/hand.png` over the pivot.
   - Draw the sword behind the body when facing up.
   - Put the whole sword under one `CanvasGroup` with `shaders/outline.gdshader`, as before.

`examples/test_sword_A_*.png` and `test_sword_B_*.png` show the assembled test swords:
- A, read bottom-up: Twice, Shockwave, Wider, Hook.
- B, with slots 1 and 2 swapped: Shockwave, Twice, Wider, Hook.

### Runes and bands

| Files | What |
|---|---|
| `runes/<id>_hand.png`, `_forge.png` | stone in a slot |
| `runes/<id>_hand_lit.png`, `_forge_lit.png` | the flash when the rune fires |
| `runes/<id>_icon.png` | 26 x 26 tray icon with the glyph |
| `bands/<id>_<host>_<scale>.png`, `_lit.png` | ring on a blade or a grip, and its flash |
| `bands/<id>_icon.png` | tray icon |

- **Runes:** shockwave, hook, cleave, second_wind.
- **Bands:** twice, wider.
- **On a swing:** the slots light from grip to tip. Swap a stone or band to its `_lit` image for about 0.1 s as its turn comes up. When a rune fires, flash the band(s) below it as well, and play `fx/band_spark` on each of them.

## Effects: `fx/`

All the effects are strips that face right; rotate them to the aim. Each strip's frame count, fps and origin are in the JSON.

| Rune | Effect files | What it looks like |
|---|---|---|
| **Shockwave** | `shockwave_wave` (6 frames, 40 x 64), `shockwave_burst` (6 frames, 64 x 64) | A bright amber crescent that the game moves forward, plus a ring that bursts out at the finisher. Twice means a second wave about 0.12 s later. Wider means scaling the wave up (about 1.5x). |
| **Hook** | `hook_head` and `hook_head_bite` (16 x 16), `chain_link` (2 frames, 6 x 4: alternate them every 5 px along the chain), `hook_snag` (5 frames), `hook_yank` (4 frames of streaks on the pulled enemy) | A chain shoots out from the sword tip, the hook bites, and the enemy is yanked back. Wider means a longer chain. |
| **Cleave** | `cleave_arc` (5 frames, 56 x 64), `cleave_echo` (4 frames, an X cut on the enemy behind) | A cold steel-blue crescent, so it never reads as Shockwave's amber. |
| **Second Wind** | `wind_wisp` (4 frames, flies from the kill to the player), `wind_swirl` (8 frames, round the player's feet), `dodge_pip` (5 frames, the HUD pip refilling) | Mint green, so it reads as "breath back". |
| **Bands** | `band_spark` (4 frames, 16 x 16, teal) | Plays on a band when its rune fires. |

The effects are full-bright colours. Draw them on a layer the CanvasModulate doesn't darken, and use additive blend if you want them to glow over enemies. They are drawn in one shared amber ramp. When elements come back, an element blade can recolour Shockwave by swapping that ramp (a fire wave was tested and works). That version isn't exported while elements are parked.

## The forge screen

- `mockup_forge_A.png` and `mockup_forge_B.png` are the forge screen at 640x360, shown at 2x, holding test swords A and B:
  - **Left:** the parts tray, with tabs for blades, grips, runes and bands. Locked cards show a padlock (Lunge is shown locked). The details box shows the hovered part.
  - **Centre:** the sword upright over the anvil, drawn with the forge-scale parts.
    - Numbered slot plates run up the left, beside a "grip to tip" arrow.
    - A teal bracket on the right links each band to the rune it boosts, tagged x2 or BIG. Stacked bands get side-by-side brackets.
    - The selected slot has corner marks.
    - Below the sword are the Test sword A and B buttons and "Try at the dummy".
  - **Right:** "What this sword does", one row per slot read from the grip up.
    - A band's row names the rune it boosts.
    - An "On the finisher" summary is at the bottom.
- `mockup_in_game.png` shows test sword A in Ivy's hand mid-finisher, with two shockwaves, a Wider hook on a far slime and Second Wind wisps. The inset shows the sword in hand at 4x.
- `ui/` is the UI kit:
  - nine-patch `panel.png` and `panel_titled.png`, plus `well.png` and `well_selected.png` (item cards and rows);
  - `button.png` and `button_hot.png`;
  - `padlock.png`, `focus_corners.png` and `anvil.png`.
  - The nine-patch margins and the colour list are in the JSON under `ui`.
- **Fonts:** Silkscreen for headings (8 px, 16 px for the title) and Pixelify Sans for body text (11 px). Both are free Google Fonts under the OFL. Turn off ligatures for Pixelify Sans in Godot, or "fi" draws as one glyph. The TTFs are in `art/concept-art-2/fonts/`.

## Code

Everything here is generated by `art/concept-art-2/`:
- `sp_parts.py` for the parts;
- `sp_fx.py` for the effects;
- `sp_forge.py` for the forge screen and UI kit;
- `sp_scene.py` for the in-game shot;
- `sp_export.py` to export everything.

Run `python3 sp_export.py` there to rebuild every file.

## Forge effects: `forge-fx/`

These make the forge feel like a real forge. Frames, fps and origins are in `forge_fx.json`.

| File | What |
|---|---|
| `hearth_still.png` | One frame of the hearth, 156 x 240. Use this one: Darren wants no moving backgrounds on the forge. |
| `hearth.png` | 8 frames, 156 x 240, 10 fps, loops. An opaque fire backdrop for the arch behind the sword: firebrick wall, flames, a coal bed with breathing cracks and rising embers. Its top fades dark so it melts into the arch. |
| `heat_halo.png` | 120 x 300. A soft warm glow to put behind the sword while forging. Pulse its alpha in code. |
| `sparks.png` | 6 frames, 32 x 32. A spark burst for when a part goes into a slot. |
| `hammer_strike.png` | 8 frames, 72 x 64. The forge hammer comes down on the anvil with an impact flash and sparks. Its origin is the strike point. |
| `heat_<blade id>.png` | 8 frames, the blade's forge size. Draw it exactly over the blade: white-hot cooling through orange and red to steel, tip first. Sockets stay clear. |
| `shine_<blade id>.png` | 8 frames, the blade's forge size. A glint sweeps from the guard up to the tip and ends in a star. |
| `steam.png` | 10 frames, 96 x 96. Quench steam, rising from the base of the blade. |
| `forged_banner.png` | 6 frames, 132 x 32. A "FORGED!" plate stamps in over the top of the sword. Hold the last frame, then fade it. |

The forge-complete order is in the JSON: hammer strike, then heat and steam, then the banner with a small shake, then the shine. `mockup_forge_complete.png` shows the middle of it.

## New fittings (6 November)

These are for the sword parts on the prototype branch. They follow the same rules as above. Runes are amber stones with a carved glyph, bands are teal rings, and each effect has its own colour.

| Kind | Id | Files | Glyph / look |
|---|---|---|---|
| rune | `shards` | `runes/shards_*` | two little shard stars. It replaces Cleave. |
| rune | `leap` | `runes/leap_*` | an arrow jumping up-right |
| rune | `whirlwind` | `runes/whirlwind_*` | a spiral |
| band | `every_hit` | `bands/every_hit_*` | a grid of dots. In hand it shows 3 dots. |
| band | `saved_up` | `bands/saved_up_*` | stairs that build up. In hand it shows 1 dot. |
| band | `on_dodge` | `bands/on_dodge_*` | a double chevron (>>). In hand it shows 2 dots side by side. |
| rule-bender | `relay` | `rare/relay_hand.png`, `_forge`, `_lit`, `_icon` | a violet cut gem (#d9a6ff) with an up arrow. It is socket-sized like a rune stone, so place it the same way. |

The runes and bands have the same file set as the old ones: `_hand`, `_forge`, `_lit` and `_icon`, and for bands both `blade` and `grip` hosts.

**Effects** (in `fx/`; frames, fps and origins are in the JSON):

| Rune | Files | What |
|---|---|---|
| Whirlwind (#ff7ad9) | `whirlwind_spin` (6 frames, 72x72) | A pink blade edge sweeps one full turn round the player with a fading trail. Its origin is the player. |
| Leap (#f4e07a) | `leap_trail` (4 frames, 40x16), `leap_land` (6 frames, 48x48) | Gold streaks along the jump; it faces right, so rotate it to the jump. A flat gold ring bursts out where you land. |
| Shards (#c9d4e0) | `shards_shard` (4 frames, 9x9, loop), `shards_hit` (4 frames, 24x24) | A spinning steel shard that the game flies from enemy to enemy, plus a white-steel splinter burst on each enemy it hits. |

Parked, so they have no new art: Second Wind, Mirror and Lunge. The code is in `sp_parts.py`, with the new glyphs, `BENDERS` and `bender_gem`, and in `sp_fx.py` under `STRIPS_NEW`. Export with `python3 sp_export_nov6.py`, which only writes these files and merges their entries into swing_path.json. There is a preview sheet: `new_fittings_nov6.png`.
