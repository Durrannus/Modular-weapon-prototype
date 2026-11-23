# Pip, his cage and Nib, version 1 (23 November 2026)

First drafts for the faster milestone 8 build. Darren has not reacted to them yet.
The same form as highlands-enemies-v1: everything faces RIGHT (mirror for left), strips run left to right, every frame of
a strip is the same size, the 1 px #19142a outline is drawn in, there are no shadows and no glow layers.
1 art px = 1 screen px at 640x360, sized against the 16x27 player.

Files: `folk.png` (512x168), `folk.json` ("actors": name, then `frame`, `origin_feet`, `note` and `strips` with `frames`,
`fps` and `box`), `folk_preview.png` (the board Darren is shown), `code/hl_folk.py` (`python3 hl_folk.py` writes this
folder; it needs `hl_enemies.py` beside it, and the Art builder's hl3 kit for the preview only).

## pip (32x32, feet (15, 28))

| strip | frames | what |
|---|---|---|
| idle | 4 | stands, the lantern on his pack swings a pixel |
| move | 6 | walks |
| talk | 4 | waves a hand while he speaks (loop while his words are up) |
| work | 4 | taps with his hammer: frames 0 and 1 up, 2 and 3 down |
| cheer | 2 | both arms up and a hop, WITHOUT the pack: the moment he is out of the cage |
| bare_idle | 4 | idle without the pack, if you want him at a bench with the pack put down |

He is a goblin like the slingers (the same ash skin and build), told apart by a leather cap with goggles, a pale eye
where theirs is ember, a linen shirt under a leather apron, and a tinker's pack with a bedroll, a pot and a lantern on a pole.

## pip_cage (48x56, feet (8, 52) = the foot of the post)

The cage's middle is 20 px right of the feet and 27 px up (aim hits there). Pip lands 20 px right of the feet.

| strip | frames | what |
|---|---|---|
| idle | 4 | hangs with Pip inside, a slow one pixel sway (3 frames a second) |
| hit | 2 | struck: the cage jolts and Pip throws his arms up |
| break | 3 | a bar cracks; two bars fly out, the floor swings down and Pip drops; the cage hangs empty |
| empty | 2 | what stays: the broken cage, its floor hanging, two bits of bar on the ground (slow sway) |

After `break`, put `pip` at the landing spot with `cheer`, then `idle`. Only the post should stop the player
(about 6 px wide at the feet).

## nib (24x24, feet (11, 20))

| strip | frames | what |
|---|---|---|
| idle | 4 | stands, wags |
| move | 6 | trots |
| sit | 2 | sits (two frames the same, for a later blink) |
| bark | 2 | a hop and a bark: "something is buried here" |
| dig | 4 | rear up, nose down, earth flying |
| sleep | 2 | curled up, breathing (1 frame a second) |

A Cliff Hound pup in the hounds' grey: a big head, big ears, short legs, a stump of a tail, and a dark eye where the grown
hounds' is ember, so he never reads as one of them.

## The Art builder's choices (not Darren's)

- Pip's cap, goggles, apron, pack and lantern; that he has no pack while caged.
- The cage hangs from a wooden post with a beam (the Bible says only "a hanging scrap cage"); it is made of a pot lid,
  bronze bands gone green and four bars that do not match.
- Nib has no collar.
- If any shape changes later, the names, sizes and feet stay the same.
