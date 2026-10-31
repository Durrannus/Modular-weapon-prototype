# Modular Weapon Prototype

A small Godot 4 prototype that answers one question: **is building a weapon from parts, and swapping them, fun?**

One arena, one wooden sword, nine parts, a sword-shaped build grid and three kinds of enemy. No world, base, story or online play yet.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (4.3 or newer should also work) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

The first time you open it, Godot takes a few seconds to import the project.

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD or arrows | Left stick or d-pad |
| Aim | Mouse | Right stick (or move direction) |
| Attack (steps through the combo) | Left click | X or right trigger |
| Dodge (only with Feather Charm) | Space, Shift or right click | A or left trigger |
| Open / close crafting table | Tab | Y |
| Pause enemy spawning | P | Start |

**At the crafting table** (the game pauses):

- Mouse: click a part in the list to pick it up, click the grid to place it, right click to rotate, click a placed part to pick it back up.
- Keys or controller: arrows or d-pad move the cursor, Q/E or LB/RB choose a part, Enter or A place or pick up, R or X rotate, Esc or B put a part back.

Swapping is free.

## How the parts work

The grid is drawn in the shape of a sword, tip at the top:

```
b b b    blade area (3 rows): blades. Two thin blades side by side make a two-pronged sword.
b b b
b b b
h h h    hilt area (2 rows): hilts. You can stack two.
h h h
  g      handle (2 cells, one wide): grips
  g
```

Each part only goes in its own area, and every part fits there without rotating. Gems are small and fit in any area. The shape is set by `SHAPE_MAP` in `scripts/weapon/weapon_build.gd`.

If you add or change a part, run this from the project folder to check it still fits its area:

```
godot --headless --script res://tests/check_parts.gd
```

The combo reads **from the bottom of the grid up to the tip**. Parts in the same row read left to right. The number on each part shows its place in the order.

| Part type | What it does here |
|---|---|
| Hilt | Adds moves to the combo (slash, stab, spin) |
| Blade | Sets damage and reach, and can add an effect (waves, fire) |
| Handle | Sets attack speed only (for now) |
| Gem | Small 1x1 parts with a special effect, sometimes with a condition |

Combining rules (all in `scripts/weapon/weapon_build.gd`, `compute()`):

1. **Hilts merge.** If two hilts both add a move at the same combo step, they merge into one move. Oak Hilt below Iron Crossguard gives `slash + stab`; swap their positions and you get `stab + slash`.
2. **Same type doesn't stack stats.** The lowest blade sets damage and the lowest handle sets speed. A second one only adds its effect.
3. **Bonus pairs.** Iron Crossguard + Ember Blade gives +20% crit. Oak Hilt + Wooden Blade gives +15% speed.
4. **Conditions.** Splitter Shard splits waves into three, but does nothing without the Tide Blade.
5. **No base dodge.** You can only dodge with the Feather Charm on the sword.

There's a training dummy near the start so you can test a build without being chased. Press P to stop enemies spawning.

## Adding a part

Parts are data files in `parts/`. Every `.tres` file in that folder is loaded automatically.

1. In Godot's FileSystem panel, right click a part (for example `parts/oak_hilt.tres`) and choose **Duplicate**.
2. Click the new file and change its values in the Inspector: name, type, shape (grid cells it covers), colour, moves, damage, speed, effects.
3. Give it a new `id`. Run the game and it's in the parts list.

Moves you can use: `slash`, `stab`, `spin` (tuned in `MOVES` in `scripts/player.gd`).
Effects you can use: `wave`, `burn`, `split`, `dodge`, `lunge` (lunge isn't on any part yet; the last combo hit dashes you forward).

New moves or effects need a little code in `scripts/player.gd`, in `_do_move()`.

## Project layout

```
project.godot            Godot project settings
scenes/main.tscn         The only scene; everything else is built in code
scripts/main.gd          Arena, spawning, wiring
scripts/player.gd        Movement, dodge, running the combo
scripts/enemy.gd         Slime, charger, brute and training dummy
scripts/projectile.gd    Waves from the Tide Blade
scripts/weapon/weapon_build.gd   The grid, its areas and the combining rules
scripts/parts/part_data.gd       What a part file contains
scripts/parts/part_library.gd    Loads every part in parts/
scripts/ui/build_menu.gd         The crafting table
scripts/ui/hud.gd                Health, kills, combo display
scripts/input_setup.gd           All key and controller bindings
parts/*.tres             The nine sword parts
tests/check_parts.gd     Checks every part fits its area
```

## Art

Everything is drawn with simple shapes for now. The project is already set up for pixel art: textures use nearest filtering (no blur) and 2D positions snap to whole pixels. When real sprites arrive, switch to a low base resolution such as 640x360 (Project Settings → Display → Window → Viewport Width/Height) and set Stretch → Scale Mode to "integer", so pixels stay sharp at 1080p (3x) and 1440p (4x). The crafting table layout would then need resizing.

When you're knocked out you respawn at the start point (the "base" for now).

## Not in this prototype yet

Online co-op (2 players next), levelling up to add grid squares, the mini boss and part reward, and a second weapon type (bow or staff). Those follow once the parts feel good.
