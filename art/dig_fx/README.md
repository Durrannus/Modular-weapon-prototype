# Dig effects, first draft (22 November 2026)

What you see while a tool works on the land: cracks that grow on the tile being dug, a pine that shakes and comes down, and
small bursts of stone and wood. Made by the Art builder for the tools version (game version 40), after the Overseer's review.
Darren has not seen these yet. Every colour is from the Game Bible's ramps (stone st, wood wd, tin ln, copper cu, plants pt).

- `dig_fx.png`: the sheet. `dig_fx.json`: the box of every picture, plus the rules below in short. `dig_fx_preview.png`: the
  board shown to Darren. `code/dig_fx.py`: how it is all made (`python3 dig_fx.py` writes this folder).

## Cracks (`crack_rock_1..3`, `crack_tin_1..3`, `crack_copper_1..3`, each 16x16)

Draw the picture over the tile's own 16x16, above the land and under the player. There is ONE set for the dark top and the
lit face: a crack is a line of #19142a with a paler lip on its lower right. On the lit face you read the dark line, on the
dark top you read the lip, so the game chooses nothing. Rock takes 3 blows: show `crack_rock_1` after the first and
`crack_rock_3` after the second. Ore takes 4: show its three pictures after blows 1, 2, 3; a few pixels of the metal show in
the break, so a player who hits sealed ore sees what it is. Mirror left to right on every other tile if you want variety.

## Pine (`pine_<0..5>_shake_r`, `_shake_l`, `_fall_r0..5`, `_fall_l0..5`)

Made from the game's own baked pine pictures (things.png and kit.json of version 40), so they line up to the pixel. Each
picture has a `foot`: put it on the pine's foot. For a pine that stands mirrored, mirror the picture and its foot and swap
`r` and `l`.

- A blow from the left: `shake_r` for 50 ms, `shake_l` for 60 ms, then the pine itself. From the right, `shake_l` first.
- The last blow: put the stump down at once, hide the pine, play `fall_r0..5` (70, 70, 70, 60, 60, 110 ms) so it falls away
  from the player (`fall_l` to the left). The fall frames hold only the tree above the cut, 9 px above the foot (the top of
  tools-v1's `pine_stump`), turned 5, 14, 28, 47, 68 and 88 degrees about the cut. After the last frame the tree is gone: play
  `burst_wood` at its middle and drop the wood. Fade the pine's shadow out over the fall.
- `dig_fx.pine_frames(picture, foot)` makes the frames for any pine picture, if the kit's pines are baked again.

## Bursts (`burst_rock`, `burst_tin`, `burst_copper`: 6 frames; `burst_wood`: 5 frames; each frame 32x28)

Strips of frames side by side, 60 ms a frame. The frame's `origin` (16, 17) goes on the middle of the tile that breaks, or on
the point of the blow for wood. Rock, tin and copper are for a tile (or a boulder) breaking up; wood is chips and a few pine
needles for each axe blow and for where the crown lands.

## Not in this folder

- The brighter copper veins and the softer shadow on dug floor are rules in `hl3.py` (art/highlands-concept/v3/code/).
