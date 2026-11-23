# Inventory art, first drafts (23 November 2026)

Asked for by the Prototype builder for version 47, after Darren's ruling of 23 Nov 15:29Z: "I want to be able to put
accessories in normal inventory with everything else but have an accessories equip satchel and when they are put there
they are in use ... also want to add craftable backpacks". Darren has asked for none of the art details: every look here
is the Art builder's choice.

- `inventory.png`, `inventory.json`: the sheet, in the loot sheet's form (`sprites`: name to `box`).
- `inventory_preview.png`: a mock inventory beside the satchel, and the pieces close up.
- `code/inventory_v1.py`: draws it.

| Name | Size | Use |
|---|---|---|
| `slot` | 24x24 | An empty inventory slot. Slots tile with no gap. |
| `slot_hover` | 24x24 | The slot under the cursor (pale corner brackets), ready made for one player. |
| `slot_cursor` | 24x24 | The brackets alone, WHITE: draw over a slot or a satchel cell and tint with a player's scarf colour when two players share the screen. |
| `pack_hide` | 24x24 | The Hide Pack, for the lab and Pip's shop. |
| `satchel_hide` | 24x24 | The Hide Satchel, for the lab and Pip's shop. |
| `item_tin_bar`, `item_copper_bar` | 16x16 | New. |
| `item_stone`, `item_wood`, `item_tin_ore`, `item_copper_ore` | 16x16 | Copied unchanged from tools-v1 (already on `art/tools/tools.png`). |

## Why the slot is 24 px and not 20 or 22

The accessory icons are 24x24 pictures and several fill all of it (the bandolier is 24x24, the thorn charm 23x23, the
banner pin 21x24). A smaller slot would crop them or need them scaled, and the game keeps one pixel size everywhere.
So the slot is the size of the satchel's cell. 24 slots are 144x96 px; eight rows are 192 px tall.

Put a 16 px material at (4, 4) in its slot (`item_at` in the JSON) and a 24 px picture at (0, 0).

The slot is plainer than the satchel cell on purpose (no teal frame, no rivets), so the satchel, where things are in
use, stays the special place.

## Turning accessories in the satchel

Turn the pack pictures by quarter turns in code. They are lit from the upper left, so a turned piece is lit from
another corner, but at this size with a dark outline that is hard to see, and it keeps every piece exactly on its
cells. If it ever looks wrong on a long piece (the bandolier, the dowsing rod), the Art builder can draw turned ones
for those few.

## Not drawn

The seven starter accessories (Miner's Lamp and so on) still have no art. Bigger backpacks than the Hide Pack.
