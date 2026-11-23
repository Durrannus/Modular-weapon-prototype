# Highlands chest and loot, version 1 (23 November 2026)

First drafts, drawn for the faster milestone 8 build. Darren has not reacted to them yet.
Everything is 1 art px = 1 screen px at 640x360, in the Game Bible's ramps, lit from the upper left,
with the 1 px #19142a outline drawn in (the HUD coin uses the HUD's 0f0b18).

Files: `loot.png` (256x65, every picture), `loot.json` (the box of each picture and its feet, frames and notes),
`loot_preview.png` (the board Darren is shown), `code/hl_loot.py` (how it was made: `python3 hl_loot.py`
writes this folder; it needs `hl_enemies.py` and `dig_fx.py` beside it, and the Art builder's hl3 kit for the preview only).

## The chest

- `chest`: 5 frames of 18x20, foot (9, 20) at the middle of its base, solid part 16x5 at the base. 10 frames a second.
  Frame 0 is the closed chest. Play 0 to 4 when it opens: unlatched, lifting, thrown open, settled open with its loot showing.
- `chest_empty`: 18x20, same foot. Open and emptied: what an opened chest stays as.
- Wooden planks with two iron straps and a bronze lock. It carries no ground of its own, so it stands on grass
  and on dug floor alike; give it the same soft ground shadow as the other Highlands things.

## What lies on the ground and in the bag

Each thing has `item_<name>` (16x16 bag icon, the same form as tools-v1's item_tin_ore and friends) and
`drop_<name>` (2 frames of 12x12, foot (6, 12); frame 1 has a small pale glint: show it for a moment every second or two).

coins, tin_bar, copper_bar, blank_rune, part_bundle (one picture for any weapon part), accessory_pouch (one picture for any
accessory), hide_small, hide_large, feather, horn, meat, horn_body, horn_bell, horn_mouthpiece (the three pieces of the
Rusted Warhorn: elite Scrap Brute, elite Cliff Hound, elite Pebble Slinger) and cellar_key (an extra nobody has asked for yet).

## Memory and the HUD coin

- `memory_mote`: 4 frames of 7x7, origin (3, 3), 10 frames a second. The forge's amber with a bronze edge and no outline.
  Loop it while it flies to the player. Colour is reserved for elements, so it is amber and bronze only.
- `hud_coin`: 12x12, in the HUD glyphs' amber (f0c070, shade cf8a48) with their 0f0b18 outline.

## The Art builder's choices (not Darren's)

- The chest is a keeper's chest of planks, iron straps and a bronze lock, not goblin scrap.
- Bars are plain ingots: tin pale silver, copper in the copper ramp.
- The blank rune stone is a smooth round stone in the hill-stone ramp with nothing cut into it yet.
- A weapon part is a cloth bundle tied with cord; an accessory is a small leather pouch.
- The Warhorn pieces are bronze with a touch of verdigris, so they read as old and as belonging together.
- If any shape changes later, the names, sizes and feet stay the same.
