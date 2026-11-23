# The keepers' waystone, version 1 (23 November 2026)

First draft for the faster milestone 8 build. Darren has not reacted to it yet.
1 art px = 1 screen px at 640x360, the Game Bible's ramps, lit from the upper left, the 1 px #19142a outline drawn in, no shadow.

Files: `waystone.png` (384x96), `waystone.json` (frame, foot, solid, and "sprites": name, then box, frames, fps, note),
`waystone_preview.png` (the board Darren is shown), `code/hl_waystone.py` (`python3 hl_waystone.py` writes this folder;
it needs `hl_enemies.py` beside it, and the Art builder's hl3 kit for the preview only).

Every frame is 48x48 with the foot at (13, 46): the middle of the base's bottom edge. The stone stands 38 px above the
foot (the player is 27). The solid part is the base, 18 wide and 5 deep, centred on the foot. The fallen top is not solid.

| name | frames | what |
|---|---|---|
| waystone_broken | 1 | as it is found: snapped below the socket, the top lying to its right, the socket empty, moss on both |
| waystone_repair | 4 | played once when the copper bars go in (4 frames a second): the top set back with the break dark; copper half way along the break; copper in the break, the ring and the groove; the ring catching |
| waystone_lit | 4 | the slow loop of a working stone (3 frames a second): a brighter ring round a small ember, a glint running down the groove |
| waystone_repaired | 1 | mended but not lit, in case the game ever wants a stone that is asleep |

## The Art builder's choices (not Darren's)

- A plain standing stone a little taller than the player, so it is a landmark without being a giant relic.
- The repair is visible: copper fills the break, like a mended pot, as well as the ring and the groove.
- The light is the forge's amber (every stone links to the forge), a few hard pixels, nothing blurred. If Darren wants
  the light in another colour or none at all, only the four lit frames change.
- If the shape changes later, the names, the frame and the foot stay the same.
