# Modular Weapon Prototype

A small Godot prototype that answers one question: **is building a sword from parts, and swapping them, fun?**

This is **milestone 2, "Real sprites"**, built on milestone 1 ("Sword v2 feels good"): one arena, single player, a sword built from four parts plus charms, three elements, three enemy types and a training dummy that shows damage per second. It's done when you can build three swords that play clearly differently, and the wooden sword feels plain next to them. Milestone 2 swaps the placeholder shapes for real pixel art: Ivy, the slimes, the dummy, a tiled arena with a forge corner and torches, and a sword that's assembled from whatever parts you put on the grid.

## This branch: the swing path

This branch tests the **swing path** (design notes, 3 November). It replaces the part grid; `main` still has the grid sword to compare against.

- A sword is a **blade** plus a **grip**. The blade sets the basic three-hit chain (the last hit is the finisher). Grip and blade both have **slots**.
- Slots hold **runes** (effects) or **bands** (modifiers). Read the sword as one line from the bottom of the grip to the tip: a band boosts the next rune above it, bands in a row stack, and a band with nothing above it does nothing.
- Runes: **Shockwave** (finisher: a rolling wave), **Hook** (finisher: chains yank enemies in), **Cleave** (every hit also strikes an enemy behind), **Second Wind** (kills refill a dodge, up to 2).
- Bands: **Twice** (the rune happens twice, a beat apart) and **Wider** (bigger).
- Effects are deliberately loud: each rune has its own visual, sound and name pop-up, the slots flash on the sword and in the HUD when they fire, and the finisher gets a freeze-frame and screen shake. Identical runes firing together merge into one bigger effect.
- **Order test:** the forge has Test sword A (Twice, Shockwave, Wider, Hook: two shockwaves and a wide hook) and Test sword B (Shockwave, Twice, Wider, Hook: one shockwave and a double, wide hook). Keys 1 and 2 switch between them.
- **Pause enemies:** the button at the top right, or P / Start.
- Elemental blades are parked for now. Sounds are placeholders made in code (`scripts/sfx.gd`).

Code: `scripts/weapon/swing_build.gd` (blades, grips, fittings, the reading rule), `scripts/weapon/sword_art.gd` (draws the sword with its slots), `scripts/ui/swing_forge.gd` (the forge), `scripts/fx/rune_fx.gd` (rune visuals), and the rune code in `scripts/player.gd`.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD or arrows | Left stick or d-pad |
| Aim | Mouse | Right stick (or move direction) |
| Attack (steps through the combo) | Left click | X or right trigger |
| Dodge | Space, Shift or right click | A or left trigger |
| Open / close the forge | Tab | Y |
| Pause enemy spawning | P | Start |

**At the forge** (the game pauses):

- Mouse: click a part in the list to pick it up, click the grid to place it, click a placed part to pick it back up.
- Keys or controller: arrows or d-pad move the cursor, Q/E or LB/RB choose a part, Enter or A place or pick up, Esc or B put a part back.

Swapping is free.

## The sword

The grid is drawn in the shape of a sword, tip at the top:

```
b b b    blade area: one big blade, or several small blades side by side
b b b
b b b
h h h    hilt (one)
c g c    g = handle (one, 2 tall), c = charm squares (2)
  g
  p      pommel (one)
```

Each part only fits its own spot, without rotating. You can have one pommel, one handle and one hilt. Blades are the exception: several small blades can share the blade area. The shape is set by `SHAPE_MAP` in `scripts/weapon/weapon_build.gd`.

### The combo

Pommel, handle and hilt each give **one move**, set by the part's shape. Attacking plays them in order from the bottom of the sword up, then loops:

**pommel move → handle move → hilt move (finisher, short pause after it) → pommel move ...**

Stop attacking for half a second, or dodge, and it resets to the pommel move.

| Move | How it feels |
|---|---|
| slash | Quick, wide arc in front |
| stab | Quick, long and narrow |
| lunge | Dash forward, then a strong stab |
| spin | Slower, hits all around you |
| overhead | Slow wind-up, narrow, very hard hit with big knockback |

The moves are tuned in `MOVES` in `scripts/player.gd` (wind-up, total time, reach, arc, power, knockback).

### Blades and elements

- Blade damage adds up. A big blade (Iron Longblade) hits harder and reaches further but swings slower.
- Small blades (shards) do less damage each but add an element.

| Element | On hit |
|---|---|
| Fire | Burns for a few seconds |
| Water | Slows the enemy |
| Lightning | Jumps to one nearby enemy |
| **Steam** (fire + water) | Bursts and scalds enemies next to the target |
| **Electrified** (water + lightning) | Jumps to three enemies and stuns them |

Damage numbers are coloured by element and bigger for crits (with a "!"). The dummy shows damage per second for the last few seconds.

### Stats and materials

| Part | Leans towards |
|---|---|
| Blade | Damage, reach |
| Hilt | Crit chance, area |
| Handle | Attack speed |
| Pommel | Move speed, crit damage |
| Charm | One small bonus (Swift: attack speed, Keen: crit chance) |

A part's **material** multiplies its numbers: wood x1.0, iron x1.4 (`MATERIALS` in `weapon_build.gd`). So an iron part with the same shape does the same move, just better.

### Starter parts

| Part | Parts and their move |
|---|---|
| Pommel | Wooden (slash), Curved (slash, more crit damage), Spike (stab, faster movement) |
| Handle | Wooden (slash), Wrapped (stab, faster attacks), Long (lunge) |
| Hilt | Wooden (slash), Cross (overhead), Spin (spin; the future mini boss reward, unlocked for testing) |
| Blade | Wooden Blade, Iron Longblade, Fire Shard, Water Shard, Lightning Shard |
| Charm | Swift Charm, Keen Charm |

You start with the wooden sword: wooden pommel, handle, hilt and blade, so slash, slash, slash.

Some builds to try: Spin Hilt + Wrapped Handle + fire and water shards (steam); Iron Longblade + Cross Hilt + Long Handle + Curved Pommel (big slow hits); three shards (every element, both combos).

## Adding a part

Parts are data files in `parts/`. Every `.tres` file in that folder is loaded automatically.

1. In Godot's FileSystem panel, right click a part (for example `parts/cross_hilt.tres`) and choose **Duplicate**.
2. Click the new file and change its values in the Inspector: name, type, material, shape, colour, move, and stats.
3. Give it a new `id`. Run the game and it's in the parts list.

Then check it still fits its spot on the sword:

```
godot --headless --script res://tests/check_parts.gd
```

## Project layout

```
project.godot            Godot project settings
scenes/main.tscn         The only scene; everything else is built in code
scripts/main.gd          Arena, spawning, the starting sword
scripts/player.gd        Movement, dodge, the five moves, elements
scripts/enemy.gd         Slime, charger, brute and training dummy (with DPS)
scripts/weapon/weapon_build.gd   The grid, its rules, materials and element combos
scripts/parts/part_data.gd       What a part file contains
scripts/parts/part_library.gd    Loads every part in parts/
scripts/ui/build_menu.gd         The forge screen
scripts/ui/hud.gd                Health, dodge, kills, combo display
scripts/fx/                      Swing effects, damage numbers, death splats
scripts/art.gd                   Loads sprites by name, falls back when missing
art/                     Sprites (see art/sprites.md)
shaders/outline.gdshader One outline round the assembled sword
scripts/input_setup.gd           All key and controller bindings
parts/*.tres             The 16 starter parts and charms
tests/check_parts.gd     Checks every part fits its spot
```

The weapon's stats come out of `WeaponBuild.compute()` as one plain dictionary, so online play can send it across later without a rewrite.

## Art

The game runs at **640x360**, doubled to a 1280x720 window (integer scaling). The HUD and forge are laid out at 1280x720 and drawn at half size, so text stays sharp.

Sprites live in `art/` and are named by what they show. `art/sprites.md` lists every file, its frame size and anchor points, and `art/anchors.json` has the same numbers for code.

- **The sword is built at runtime.** Each part has `art/parts/<part id>_hand.png` (5 px per grid cell) and `<part id>_grid.png` (18 px per grid cell for the forge). The game places every part on its grid cells, rotates the lot to the aim around the grip, holds it at Ivy's hand, and outlines the assembled sword with `shaders/outline.gdshader`. A new part only needs its two images.
- **Ivy** faces the nearest of 4 directions to the aim, with idle, walk and dodge animations. The sword goes behind her when she faces up.
- **Enemies** play idle, move, hit and death animations.
- **Lighting:** a cool darkening over the arena with warm lights on the torches and forge bench, and a soft light on Ivy.
- **Missing art falls back** to the old shapes, so you can add a part before its sprites exist.

`art/` has a `.gdignore` file, so Godot doesn't import it and the game also runs from a fresh copy (handy on Steam Deck). Before making an exported build, remove `.gdignore` and switch `scripts/art.gd` to `load()`.

When you're knocked out you respawn at the start point.

## Not in this prototype yet

Online co-op, the mini boss and part drop, rarity and affixes, a second weapon type.
