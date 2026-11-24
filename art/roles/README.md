# Role tree art, first drafts (23 November 2026)

Asked for by the Prototype builder for version 45. Darren has asked for none of the details: every look here is the Art
builder's choice and a first draft until he has seen it.

The Game Bible, "Role trees (agreed 12 Nov)": "Each tree teaches one word with one clear look on screen: Challenged, Open,
Sparks, Shimmer."

## Files

- `roles.png`, `roles.json`: the sheet, in the loot sheet's form (`sprites`: name to `box`, strips left to right).
- `roles_preview.png`: each look where it will be seen, at game size and bigger.
- `code/hl_roles.py`: draws all of it (imports `hl_enemies.py` for the colour ramps).

## What is on the sheet

| Name | Frames | Frame | Origin | Speed | Use |
|---|---|---|---|---|---|
| `challenged` | 4 | 24x12 | (12, 11) | 6 fps loop | Over the head of a Challenged enemy. Drawn WHITE and grey: multiply it by the challenger's scarf colour. |
| `open` | 4 | 19x18 | (9, 17) | 10 fps loop | Over the head of an Open enemy. Any single frame reads on its own. |
| `spark` | 6 | 14x18 | (7, 16) | 6 fps loop | The Mender's Spark on the ground. Origin on the ground under it. |
| `spark_fade` | 6 | 14x18 | (7, 16) | 6 fps loop | The same loop hatched, for its last 2 s. |
| `spark_take` | 4 | 14x18 | (7, 16) | 12 fps once | When a Spark is walked over. |
| `shimmer_tin` | 6 | 16x16 | (0, 0) | 4 fps loop | Over the undug rock of a hidden tin tile. |
| `shimmer_copper` | 6 | 16x16 | (0, 0) | 4 fps loop | The same for copper. |
| `shimmer_chest` | 6 | 16x16 | (0, 0) | 4 fps loop | A chest in a sealed place or under open ground. |
| `emblem_warden`, `emblem_striker`, `emblem_mender`, `emblem_delver` | 1 | 16x16 | | | Column heads of the trees screen. |

## Notes for the build

- **challenged** uses only white (ffffff), one grey (bcbcbc) and the HUD outline (0f0b18). Setting the sprite's `modulate`
  to `Art.PLAYER_COLORS[i]` gives the ring in that player's scarf colour with its own shade; the outline stays dark. It is
  the ring under each player's feet (`hud/ring_a`) made smaller, so the colour already means "that player".
- **open** and stun stars can show together (a stunned enemy is Open). Put `open` a few pixels above where the stars sit,
  or leave the stars out while `open` shows.
- **shimmer**: start each tile on a different frame (for example by tile x + y) so a vein does not blink as one. The
  glints are single pale pixels and small crosses, never more than 5 px across. No floor marks.
- **spark** has no outline and no shadow, like the Memory mote. It is a green square cross; the mote is an amber diamond.
- Nothing here glows or blurs. Every colour is on the Game Bible's ramps (checked by script), bar the white and grey of
  `challenged`, which exist only to be tinted.

## The Art builder's choices (not confirmed by Darren)

- Challenged is a ring floating over the head (the Bible says the enemy "wears a ring in your scarf colour"), with one
  bead running round it.
- Open is a guard (a flat topped plate) cut in two on a slant with the bright stroke still in the gap. A first try split
  down the middle read as a broken heart, which the game already uses for a player who is down, so it was changed.
- A Spark is a square cross in the game's verdigris green (the colour of the HUD pips), because the amber is taken by Memory.
- Shimmer is a few glints that come and go in the metal's own colours (tin pale, copper orange); a chest is a dotted box
  outline in amber with a glint on its latch.
- Each emblem is its tree's own look drawn bigger: a guard wearing the ring, the cut guard, the Spark, a pickaxe and a glint.

## Not drawn

- A shimmer for hidden rooms (the Bible names them beside ore and chests).
- Looks for the later perks of each tree (for example Sparks flying to a knocked-down teammate).

## 24 Nov: two Striker marks for version 53 (asked for by the Prototype builder)

- `sharp_glint`: 6 frames of 11x11, origin (5, 5) = its middle, on the weapon's tip, 6 fps (a 1 s loop). A small pale gold
  cross with a white heart that breathes, flaring to an eight-point star on frame 3. Hard pixels with the HUD's ink edge, no
  glow, so it reads mid-fight on the moor and on dug floor without looking neon.
- `exposed`: 4 frames of 15x14, origin (7, 13) = just over the enemy's head, stacked above `challenged` and `open`, 6 fps.
  Four bone corner brackets round an empty middle, like a mark chalked on the target, closing in a pixel and opening again.
  One shape of its own: not a ring, not a cut guard. The code blinks it in its last half second.
Both are the Art builder's choices; Darren has not seen them. `sharp_glint()` and `exposed()` in code/hl_roles.py.

## 24 Nov: the Warden's tree pieces for version 54 (asked for by the Prototype builder)

The sheet is now 700 wide, so every box moved: read them from roles.json.
- `warden_ring`: 165x105, origin (82, 52) at the Warden's feet. A dashed ellipse 80 px out each way, squashed 0.62. White
  near half, grey far half, for the game to tint with the player's colour (as `challenged`); each dash two pixels thick
  with the HUD's ink round it so it reads on pale sand and on dark dug floor. Still.
- `plate_edge`: 98x18, origin (3, 3) = the 92x12 health bar's top left. A riveted bronze rim, lit top and left.
- `plate_break`: 5 frames of 98x26 at 12 fps, once: a white crack, the rim in pieces, the pieces dropping away, hatched out.
- `payback_frame` (92x6, fill_at (6, 2)), `payback_empty`, `payback_fill` (80x2), `payback_full` (2 frames at 4 fps): the
  Memory bar's own caps and teal, its motes turned to embers.
- `payback_burst`: 5 frames of 137x87 at 15 fps, origin (68, 43) on the ground. An ember ring running out to 66 px with
  chips off its edge; only the ring, never a filled disc, so it hides nobody. A small star at the middle on frame 0.
All are the Art builder's choices (the ember for Payback follows the Prototype builder's stand-in); Darren has not seen them.
