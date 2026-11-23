# Smoke over the Slinger Roost, first draft (23 November 2026)

Asked for by the Prototype builder (for the Overseer): the first quest's pointer, "Smoke over the Canyon". Every choice
here is the Art builder's; Darren has not seen it.

- `smoke.png`, `smoke.json`: `smoke_puff`, 4 frames of 18x14, origin at the middle (9, 7), and `roost_fire` (added
  18:50Z, see the end). The loot sheet's form; `smoke_puff`'s box has not moved.
- `smoke_preview.png`: a plume over the rock tops and over the moor, and the four puffs close up.
- `code/hl_smoke.py`: draws it (`plume()` is the drift used in the preview).

## The form: puffs, drifted by the game

`smoke_puff` is NOT a loop. It is four ages of one puff: 0 fresh and tight, 1 opened, 2 wide, 3 breaking up (hatched).
A tall plume redrawn a few times a second would jump; a puff that climbs a pixel at a time is small, slow movement, and
the plume can be as tall as the land needs.

The preview's plume (also under `plume` in the JSON), about 78 px tall:

- A new puff at the fire every 1.0 s. It rises 6 px a second and drifts 1.5 px a second downwind, with a 1 px sway.
- It shows frame 0 until 3 s, frame 1 until 7 s, frame 2 until 11 s, frame 3 until it goes at 13 s.
- Move puffs in whole pixels. Mirror every other puff. Draw the newest puff last, and the plume over everything.

## Look

The game's own greys (a8b0a8 on top, then the ash ramp 8c8894, 6e6a7c, 4a4458 underneath), never near white. No
outline and no shadow: it is smoke. The dark underside keeps it readable on the pale moor. Nothing blurs or glows.

## The fire at its foot (added 23 Nov 18:50Z)

Asked for by the Prototype builder after version 47: the smoke had no source.

`roost_fire`: 4 frames of 20x20, a loop at 5 fps, box [1, 16, 80, 20]. Origin (10, 17) on the ground. A ring of grey
stones with a small ember flame, outlined like every object, no shadow. Start the plume at `smoke_from` (10, 7) in the
frame, which is 10 px above the origin. Sort it with the things standing on the ground. The flame is the only warm
colour; it moves by a pixel or two, never more. It is a goblin camp's fire, not a relic and not the forge.
