# Basic tools, the pine stump and the first materials

Drawn by the Art builder thread on 22 November 2026 for Darren's "put in basic tools" (the hand-over, its preview
picture and the code that draws them are in the project files under `art/tools-v1/`).

`tools.png` is the sheet and `tools.json` says where every picture is on it (`box`: x, y, width, height).

| Picture | Size | What |
|---|---|---|
| `hand_pickaxe`, `hand_axe`, `hand_mallet` | 15 x 20, 11 x 18, 11 x 15 | In the hand: pointing up, no outline (the weapon's outline shader draws it). `pivot` is where the fist holds it; `strike` the points that hit. The axe's blade faces +x. |
| `belt_<tool>` | 16 x 16 | The tool belt's pictures, in colour. |
| `glyph_<tool>` | 12 x 12 | The same three in the HUD's amber. |
| `item_<id>` | 16 x 16 | In the bag: tin_ore, copper_ore, stone, wood. |
| `drop_<id>` | 9 x 7 (wood 10 x 6) | The same thing as a small piece (the game uses these for what flies to you). |
| `pine_stump` | 13 x 10 | What a felled pine leaves, stood where the pine's foot was. |

The game reads them in `scripts/highlands/tools.gd` and `scripts/highlands/land_view.gd`.
