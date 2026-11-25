# Highlands enemies, second drafts (23 November 2026)

Redrawn by the Art builder after Darren, 23 Nov 11:57: "Not a huge fan of the enemies, use the design principles and make
them better, review them also". These replace `highlands-enemies-v1/`, which is now only a placeholder.

- `enemies.png`: the sheet. `enemies.json`: every strip's box. `enemies_preview.png`: every enemy with its telling poses at
  game size. `enemies_before_after.png`: first drafts against these, for Darren.
- `code/hl_enemies2.py` makes all of it (`python3 hl_enemies2.py`); it needs `hl_enemies.py` and `dig_fx.py` beside it.

## For the game: nothing moves

**Every name, strip name, frame count, fps, frame size, feet point and box is the same as in v1. `enemies.png` drops in over
the old one and `enemies.json` only differs in its notes.** Everything still faces RIGHT (mirror for left), no shadows, no
glow layers, and each elite strip still has its `<strip>_rim` twin.

| Enemy | Frame, feet | Strips (frames) |
|---|---|---|
| `hound`, `hound_elite` | 40x32, (19, 28) | idle 4, move 6, crouch 2, lunge 3, hit 2, death 4; elite: howl 3 |
| `slinger`, `slinger_elite` | 32x32, (15, 28) | idle 4, move 6, windup 2, throw 3, hit 2, death 4 |
| `brute`, `brute_elite` (the game's scrap_brute) | 48x48, (21, 44) | idle 4, move 6, windup 2, swing 3, open 2, block 2, hit 2, death 4; elite: bash_windup 2, bash 3 |
| `shaman`, `shaman_elite` | 32x32, (14, 28) | idle 4, move 6, cast 3, hit 2, death 4; elite: ward 3 |
| `bat` | 16x16, middle (8, 8) | fly 4, dive 2, puff 3 |
| `ward`, `ward_big` | 32x32 and 48x48 | back 4, front 4, loop 4 |

What changed in how a strip should be used:

- **No marks on the floor for any of these** (Art principles, rule 24: only bosses get telegraph markers). Each attack is
  told by the body: the sling going round, the hound's rump-up crouch, the boulder over the brute's head, the elite brute
  dropping low with its shield hauled back, the shaman's staff thrust up with its ring lit. `pebble_mark` is still on the
  sheet so nothing that names it breaks, but it should not be drawn.
- slinger_elite: it now carries its rock at its belly in `idle` and `move`, and lifts it over its head only in `windup`
  (before, its idle already looked like a wind-up). `throw` frame 0 is still the heave, frame 1 the release.
- brute: the weapon is a boulder lashed to a pole (it was a cleaver). `open` shows the shield fallen to its side as a
  tipped slab and the whole front bare.
- brute_elite: `bash` no longer flashes the shield (that flash is `block`'s alone); the shield is driven out at arm's length.
  Frame 0 is still the blow.
- The elite `_rim` is now the palest bronze (cu6 fff0b4), because the old amber did not show on the ochre moor.

## The look, and why

One idea each, in big flat shapes like the helm crab and the pike worm:

- **Goblins** have slate-blue skin (the `sl` ramp: its own family, cool against the moor and light against dug floor), big
  ears, ember eyes under dark brows, hide clothes, and scrap gear in the game's old-metal colours (verdigris with bronze).
- **Pebble Slinger**: a big-eared head on a small body, and a leather sling with a stone in it. Elite: an old verdigris cap
  and a rock as big as its head.
- **Cliff Hound**: a lean dark-grey dog with a pale back, a ragged black mane, a long jaw and an ember eye. Elite: white,
  with a thicker ruff, two old slashes on its flank, a scar through its eye, a torn ear and its tail carried high.
- **Scrap Brute**: a wall. Its own heavy face (one brow, small eyes, tusks), eyes over a slab of verdigris scrap. Elite: a
  dark bronze plated shield with a verdigris boss, a horned bronze cap, a shoulder plate.
- **Goblin Shaman**: a horned bone skull for a face with two ember eyes in its sockets (as the helm crab's in its slit), a
  red robe, a staff whose verdigris ring (asleep) lights ember (awake) when it casts. Elite: three uneven bone spikes, a
  broad bronze collar, a bronze ring.
- Stones are weathered mid grey (ln1, ln2 with a thin ln3 edge), never near white.

## Review 1: the Art builder's own check against each principle

1. Same game: stood beside the crew, helm crab, pike worm, anvil and barrel on moor, dug floor and rock. Pass.
2. One pixel size: hand-placed pixel maps, nothing scaled, rotated or blurred. Pass.
3. Not AI-made: no gradient, blur, noise or sprinkle; every pixel is in a map you can read in the code. Pass.
4. Every detail has a reason: each is listed above (who carries what and why). Pass.
5. Outline: a script checks that every drawn pixel in every frame has outline or art on all four sides (the white hit flash
   and the dithered last death frame are the game's own exceptions). Pass.
6. Hard steps from the upper left: three or four steps per material, lit edge on the top and left, shade on the right and
   under. Pass after the independent review (see below).
7. Size against the 16x27 player: slinger 20x20, hound 28x17 (the first redraw was 36x20, longer than the chart's cow),
   shaman 20x23, brute about 24 wide and 29 tall without its boulder (a big goblin, a little over the player). Pass.
8. Own colour families: skin sl, hide hb, scrap pt with cu, stones ln, hounds gy, robe rd, eyes em. One overlap is known:
   the bone mask and loose stone share ln (the mask at its pale end, stones at its grey end). Pass with that note.
12. Readability: checked at game size on moor and on dug floor. Pass.
13. No loud colour: ember is only the eyes and the lit ring. The red robe is the Art builder's choice. Pass, unconfirmed.
24. No floor marks. Pass.
Every colour is checked by script to be on the Bible's ramps.

## Review 2: independent (a reviewer given only the pictures and the Art principles)

It began with a blind test: 22 unlabelled poses, written down before reading any names. 15 were read correctly, 4 partly, 3
not at all. What it found, and what was done:

| Finding | Done |
|---|---|
| Elite brute's bash wind-up was a 2 px shift, invisible | Redrawn: drops low, shield hauled back across its body, boulder let down |
| Elite brute's bash flashed like a block | Flash removed; the shield goes out at arm's length |
| Elite slinger's idle looked like its wind-up | Rock carried at the belly; overhead only in the wind-up |
| Hound boulder-coloured (gy2 against ln2) and cow-sized | Dark grey with a pale back; 28x17 |
| Light not clearly from the upper left ("pillow shading") on heads, legs, bat | Heads, bodies and legs re-shaded: lit left and top, two shade steps right and under; bat has a lit wing edge |
| Elite hound flat, and white like the hit flash | Cream rim (ln4) on gy3 with gy2 and gy1 shade; ruff, torn ear, raised tail |
| Elite rim invisible on the moor | Palest bronze. It stays outside the outline on purpose: it is the elite's mark, not shading |
| Elite shaman only 38 px different, comb-like crown, collar hidden | Three uneven spikes, a broad collar that shows, a bronze ring |
| Elite brute's bronze vanished on the moor | Shield, cap and plate a step darker with a bright rim |
| Sling read as a mace (stone-coloured, rigid) | Leather, with a bend in it; the stone held at the hip in idle |
| Brute `open`: the shield read as a pole | A tipped slab six wide on the ground |
| Bat dim on dug floor; ward shields tiny | Lit wing edge; shields about half as big again |
| Shield looked manufactured | Band askew, a rivet missing, a crack, a bent corner |
| Shaman's staff a black bar | Two px of wood |
| Goblins face-on and sharing one face | Faces turned to the right (eyes and nose set toward it, one ear behind); the brute has its own face |

Left as it is, knowingly: the goblins keep big heads on small bodies (the reviewer found that "cuter" than the crew), the
elite shaman's ward is still the staff levelled at its ally, and the rock burst is still the dug-rock burst.
The fixes were checked by the Art builder, not sent for a second independent pass.

## Not confirmed by Darren

Everything here: slate-blue goblins, the hound's colours, the brute's boulder, the red robe, the skull mask.

## The moor's creatures (version 63)

`moor.png` and `moor.json` are the Art builder's "Neutral moor creatures, first drafts" (25 Nov 2026,
`highlands-moor-creatures-v1/`, made by its `code/hl_moor.py`): the boar, the badger and the capercaillie, in the wildlife
sheet's form (`"actors"` by name, everything facing right, the outline drawn in, no shadows). `scripts/foes/creature.gd`
cuts their strips from it. Copied in unchanged.

## The goblins' war dog (version 64)

`hounds.png` and `hounds.json` are the Art builder's "Cliff Hounds: wild and scrap" (25 Nov 2026, `highlands-hounds-v1/`,
made by its `code/hl_hounds.py`), in the `enemies.json` form. Its "hound" is the wild hound already in `enemies.png`
(unchanged; the game still draws wild hounds from there). Its "scrap_hound" is the goblins' war dog: `scripts/foes/scrap_hound.gd`
cuts its strips from this sheet. Copied in unchanged.
