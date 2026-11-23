# Highlands enemies, first drafts (23 November 2026)

Made by the Art builder for the faster Milestone 8 build. Darren has not seen these yet. They follow the Art principles: the
Game Bible's ramps only, 1 art px = 1 screen px, a 1 px #19142a outline drawn in, hard steps lit from the upper left, sized
against the 16x27 player.

- `enemies.png`: the sheet. `enemies.json`: every strip's box. `enemies_preview.png`: the board shown to Darren.
- `code/hl_enemies.py` makes all of it (`python3 hl_enemies.py`); it needs `dig_fx.py` beside it for the rock burst.

## Form

The same as the cave's enemies. Every enemy faces RIGHT: mirror for left. A strip is its frames left to right, all the same
size. `enemies.json` gives each enemy's `frame` size and `origin_feet`, and for each strip its `box` on the sheet, `frames`
and a suggested `fps`. There are no glow layers: the Highlands are in daylight. The game should put its own soft ground
shadow under each (the preview uses the land's cast shadow).

| Enemy | Frame, feet | Strips (frames) |
|---|---|---|
| `hound`, `hound_elite` | 40x32, (19, 28) | idle 4, move 6, crouch 2, lunge 3, hit 2, death 4; elite: howl 3 |
| `slinger`, `slinger_elite` | 32x32, (15, 28) | idle 4, move 6, windup 2, throw 3, hit 2, death 4 |
| `brute`, `brute_elite` (the game's scrap_brute) | 48x48, (21, 44) | idle 4, move 6, windup 2, swing 3, open 2, block 2, hit 2, death 4; elite: bash_windup 2, bash 3 |

- hound: `crouch` is the warning before the `lunge`; lunge frame 1 is the bite, frame 2 the landing. Circling uses `move`.
- slinger: `windup` loops while the sling goes round; `throw` frame 0 is the release. The elite carries its rock overhead in
  idle and move; its `throw` frame 1 is the release.
- brute: `swing` frame 1 is the blow. `open` is the second after the swing: the shield hangs edge-on at its side and the
  cleaver is on the ground, so the front is plainly bare. `block` is a blow landing on the shield (it flashes a step paler
  and chips fly). The elite's `bash` frame 0 is the blow.
- `hit`: frame 0 is the pale flash, frame 1 a stagger. `death`: flash, stagger, lying, then thinned to hatching (fade it out
  over the last frame).

## Elites

They differ by shape and material, not by a glow: the pack leader is white, scarred and has a ruff; the elite slinger has a
spiked cap and a rock as big as its head; the elite brute has a plated bronze shield, a horned helm and a shoulder plate.
For the Bible's "glow faintly", every elite strip has a twin `<strip>_rim` (marked `"rim": true`): a hard 1 px amber line
(cu5 f0c070) just outside the outline on the up and left sides. Draw it under the enemy, steady or pulsing slowly, or not at
all. No blur.

## What the slingers throw (`shots` in the JSON)

`pebble` (6x6, 4 frames, spinning), `rock` (10x8, 4 frames), `shard` (8x5, 2 frames, pointing right: turn it to its heading),
`pebble_puff` (14x6, 4 frames, dust where a pebble lands, no outline), `rock_burst` (32x28, 6 frames, origin (16, 17): the
same burst as a rock tile breaking). Each has an `origin` to put on the shot's position.

`pebble_mark` (28x14, 4 frames, origin (14, 7)): the spot where a pebble will land, flat on the floor, no outline. Redrawn 23 Nov
in the game's own warning colours (the red edge, orange ring and dark red hatching of art/fx/warn_circle_*), because the grey
first draft was hard to see in play. An orange ring closes in from the edge over frames 0 to 2: spread them over the pebble's
flight. Frame 3 is the landing flash. Same name and box as before. Draw it under everything that stands.

## Colours

Goblin skin is the kit's "ash" ramp (2a2434, 4a4458, 6e6a7c, 8c8894), worn a step up from its darkest so a goblin still
reads on dark dug floor. Hide and wood are wd, scrap is bronze cu with verdigris pt, hounds are gy, bone, cord and loose
stone are ln, scars rd, the one eye em5.

## Shaman, bats and the ward (added 23 Nov, second hand-over)

| Enemy | Frame, origin | Strips (frames) |
|---|---|---|
| `shaman`, `shaman_elite` | 32x32, feet (14, 28) | idle 4, move 6, cast 3, hit 2, death 4; elite: ward 3 |
| `bat` | 16x16, middle (8, 8) | fly 4, dive 2, puff 3 |
| `ward` | 32x32, feet (15, 28) | back 4, front 4, loop 4 |
| `ward_big` | 48x48, feet (21, 44) | back 4, front 4, loop 4 |

- shaman: a goblin in a dark wine robe and a skull mask, with a staff that ends in an old bronze ring. `cast` frame 1 is the
  moment the ring sounds (the bats come). The elite has a crown of bone spikes and a bronze collar; its `ward` levels the
  staff at the goblin it shields (frame 1 is the moment).
- bat: faces right in `dive` (mirror for left); `fly` is head on. `puff` is the bat scattering when the shaman dies (the last
  two frames have no outline).
- ward: three small scrap shields circling the goblin, as "this one cannot be hurt". Put the ward's feet on the goblin's
  feet. Draw `back` under the goblin and `front` over it; or draw only `loop` (both together) over it. `ward` fits the
  slinger, shaman and their elites, `ward_big` the brute. 6 fps.
