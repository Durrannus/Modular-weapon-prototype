# Levelling art, first drafts (23 November 2026)

Made by the Art builder for version 45 (levelling), because the Prototype builder asked whether a Memory bar, a level-up
look and a death marker existed. Darren has asked for none of the details and has not seen these.

- `levelling.png` and `levelling.json`: the sheet, in the loot sheet's form (`sprites`: name to `box`; strips run left to
  right). `levelling_preview.png`: how each looks in place. `code/hl_levelling.py` makes all of it (it needs `hl_enemies.py`).

| Name | Size | Use |
|---|---|---|
| `memory_frame` | 92x9 | The bar's frame: the mana bar's layout, one pixel thicker, with a Memory mote in its left cap (changed 23 Nov after the review of version 45). `fill_at` (6, 2). |
| `memory_fill` | 80x4 | What is carried. Cut it from the left, as the mana fill is. |
| `memory_empty` | 80x4 | The empty bar, drawn under the fill. |
| `level_badge` | 15x13 | A bronze roundel for the squad's level. Write the number on its dark middle (9x7 at (3, 3)) in the HUD's amber. |
| `memory_marker` | 6 frames of 16x34, origin (8, 31), 6 fps | Left where a player fell. A slow loop. Origin on the ground under it. No shadow: it is a light. |
| `memory_marker_take` | 4 frames of 16x34, origin (8, 31), 12 fps | Played once when the marker is collected; then fly `memory_mote` to the player as a chest does. |
| `level_up` | 8 frames of 40x60, origin at the feet (20, 54), 10 fps | Played once over every player when the squad gains a level. Draw it over the player. Frame 4 is the moment the level lands. |

## The look, and why

The Bible: Memory "fills a bar on your character", is poured into the forge so "everyone levels up at once", and half of
what is unbanked is "left as a glowing marker you or a teammate can collect" when you die.

Memory already has a look in the game: the amber mote of the loot sheet (bronze cu3 edge, cu5, cu6, no outline). Everything
here is made from that mote, so a player who has picked one up knows what the bar counts, what is waiting where they fell
and what rises at a level-up.

- The bar is the game's own mana bar recoloured in the mote's bronze, with a small mote on each cap in place of the blue
  stone and quarter marks cut into the fill and the empty bar, so it differs from mana by shape as well as colour.
- The marker is one big mote hanging at waist height with two small ones going round it and a thin hatched thread rising
  from it, so it can be found from a distance. Its edge is a step darker (cu2) than a mote's so it shows on the ochre moor.
- The level-up follows the game's own revive and pickup effects (hard pixels, hatching for what fades, no blur): six motes
  lift off the ground round the feet, climb and close in, meet over the head as one star, and the star rings once.

## Checked against the Art principles

Game size beside the player on moor and dug floor (preview). Every colour is from the Bible's cu ramp or the HUD frame's own
colours; alpha is only 0 or 255; nothing scaled, blurred or graded. The effects carry no outline, as the game's own effects
and the mote do not; the HUD pieces carry the HUD's 0f0b18 outline. Nothing neon: bronze and pale bronze only.

## Not confirmed by Darren (the Art builder's choices)

All of it: that Memory's bar is bronze-amber with quarter marks, the roundel for the level, the marker as a hanging mote
with a thread, and the shape and length (0.8 s) of the level-up. No art is drawn yet for banking at the forge (the game can
fly `memory_mote` from the player to the forge) or for the forge's spoken line.
