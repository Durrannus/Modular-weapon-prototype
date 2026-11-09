# Modular Weapon Prototype

A Godot prototype for a co-op top-down game about building weapons from parts.

This branch (`swing-path`) has three things to try:

- **The tutorial cave** (Game Plan milestone 4): four rooms, from a shipwreck crate to a forge guardian, for one or two players.
- **Two players on one screen.**
- **The test arena**: the older sandbox with every sword part unlocked.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

The title screen asks who is playing and what to play.

## Two players

Both players share one screen. One uses the keyboard and mouse and the other a controller, or both use controllers.

1. On the title screen each player presses their own button to join: **Enter** (or a click) for keyboard and mouse, **A** for a controller. The first to press is player one.
2. Either player then picks **Tutorial cave** or **Test arena**.

Player one is blue and player two is orange (the ring under their feet and the bar by their health). The camera stays between you, and you can't walk further apart than one screen.

To play with someone who isn't in the room, share your screen with a tool that passes their controller through, such as [Parsec](https://parsec.app) or Steam Remote Play Together. To the game they are just a second controller. Real online play is planned for later (after milestone 5 in the Game Plan).

With one player, every device works at once, so you can swap between mouse and controller freely.

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD or arrows | Left stick or d-pad |
| Attack | Left click (swings toward the mouse) | X or right trigger (swings the way you face, or aim with the right stick) |
| Keep attacking | Hold left click | Hold X |
| Dodge | Space, Shift or right click | A or left trigger |
| Use (crate, rune, forge, talk) | E or F | A or Y, when the prompt shows |
| Pause menu | Esc | Start (in the cave) |
| Fullscreen on or off | F11 | |
| Test arena only: open the forge anywhere | Tab | Y |
| Test arena only: pause enemy spawning | P | Start |

**At the forge** (the game pauses): drag a part onto a slot, or click a slot and then a part. Right-click or drag off to remove. Keys or controller: up and down pick a slot, left and right pick a part, Q/E or the shoulder buttons change tab, Enter or A fits it, Esc or B leaves.

## The tutorial cave

It follows the "Tutorial opening" in the Game Plan. You shelter from a storm in a sea cave, the entrance collapses, and the only way out is up.

1. **The wreck.** Search the ship's crate for a wooden sword, then fight a few crawlers. They rear up before they bite, and a hit while they rear up stops the bite.
2. **The burrows.** Burrowers travel underground, come up, flash red and lunge in a straight line. Dodge aside and hit them while they lie stunned.
3. **The nest.** A mixed fight. Clearing it lets you take your first rune (Shockwave), which your sword can't use yet.
4. **The forge.** Fit the rune to your sword at the forge and the guardian statue wakes. It slams (a red circle fills first) and charges (a red lane shows the path). A charge that hits a wall stuns it. Below half health it slams three times in a row. Beat it and the old smith is freed: he explains runes and bands and hands over tin parts. Forge the tin sword and the stairs to the surface open.

Rules:

- After each room everyone is healed and anyone knocked out gets back up. There are no revives mid-fight.
- If everyone is knocked out, that room (or the boss) starts over.
- With two players there are more enemies, the guardian has more health, and it also brings rocks down after each charge.
- Only the sword exists so far, so every player takes a sword from the crate (the Game Plan's bow, staff and hammer come later).

## How the movement and sword feel (9 November pass)

Tuned against Core Keeper and similar top-down games:

- You face the way you walk. Attacking turns you to the aim for a moment, then you turn back.
- One press is one swing. A press during a swing queues exactly one more. Holding attack keeps the chain going at a steady beat.
- Hits never freeze the game. The enemy freezes for a few frames, flashes, is knocked back and reels. Only a finisher that connects plants you for a moment.
- Walking has a few frames of acceleration and stopping, and the legs keep pace with the ground.
- The end of each swing is held while you keep attacking, so slashes flow into each other.
- A standing dodge goes the way you face.
- Movement is smoothed between physics ticks, so it looks the same on 60, 120 and 144 Hz screens.

The numbers are at the top of `scripts/player.gd` (`MOVE_SPEED`, `ACCEL`, `MOVES` and so on).

## Checks

Run these after changes (they need no window):

```
godot --headless --path . -s tests/test_swing_build.gd                         # the sword rules
godot --headless --path . --fixed-fps 60 -s tests/feel_check.gd                # movement and swing feel
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd          # plays the whole cave
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 wipe down
godot --path . -s tests/smoke_forge.gd                                         # opens the forge, fires every rune
```

To skip the title screen while testing: `godot --path . -- cave` or `godot --path . -- arena`.

## This branch: the swing path

This branch tests the **swing path** (design notes, 3 November). It replaces the part grid; `main` still has the grid sword to compare against.

- A sword is a **blade** plus a **grip**. The blade sets the basic three-hit chain (the last hit is the finisher). Grip and blade both have **slots**.
- Slots hold **runes** (effects) or **bands** (modifiers). Read the sword as one line from the bottom of the grip to the tip: a band boosts the next rune above it, bands in a row stack, and a band with nothing above it does nothing.
- Runes: **Shockwave** (finisher: a rolling wave), **Hook** (finisher: chains yank enemies in), **Shards** (every hit sends metal shards jumping to the closest enemy, then the next), **Whirlwind** (finisher: a full spin cutting everything around you), **Leap** (an attack straight after a dodge jumps you to the nearest enemy).
- Bands: **Twice** (the rune happens twice, a beat apart), **Wider** (bigger), **Every Hit** (on every hit instead, at half strength), **Saved Up** (every third time, three times as strong) and **On Dodge** (also when you dodge).
- Rule-benders (the "rare" tab, one per sword): **Relay** hands the bands on the rune below on to the next rune above too. Mirror is parked (it overlapped Twice).
- New parts without art yet show as plain coloured stones, rings and gems.
- Effects are deliberately loud: each rune has its own visual, sound and name pop-up, the slots flash on the sword and in the HUD when they fire, and a finisher that connects gets a screen shake. Identical runes firing together merge into one bigger effect.
- **Order test (test arena):** the forge has Test sword A (Twice, Shockwave, Wider, Hook: two shockwaves and a wide hook) and Test sword B (Shockwave, Twice, Wider, Hook: one shockwave and a double, wide hook). Keys 1 and 2 switch between them.
- **Pause enemies:** the button at the top right, or P / Start.
- Parts: iron shortblade / blade / longblade (1, 2, 3 slots) and wooden / wrapped / long grips (1, 2, 3 slots), and pommels (no slots, stats only: Plain, Keen +8% crit chance, Heavy +40% crit damage, Light +10% swing speed). The Ringed Grip is a special grip whose built-in band makes every rune a bit bigger; the Gilded Grip's ruby top slot doubles whatever is in it (a rune fires twice, a band counts as two, caps still apply).
- The forge follows the art thread's design: parts tray on the left, the sword over the anvil with slot numbers and band brackets, and "what this sword does" on the right. **T** or the button puts you next to the dummy. The forge glows: the hearth breathes behind the sword, embers drift up, every change is a hammer blow with sparks and a clang, and leaving after changes plays a short "Forged!" finish (white-hot, quench steam, a shine up the blade). Press Tab or click to skip it.
- Art and numbers for all of this are in `art/swing/` (`swing_path.md` explains how the sword is assembled; `swing_path.json` has every slot, pivot and effect strip). Fonts are Silkscreen and Pixelify Sans (OFL), in `art/fonts/`.
- Elemental blades are parked for now. Sounds are placeholders made in code (`scripts/sfx.gd`).

Code map:

```
scenes/boot.tscn, scripts/boot.gd    Title screen, then the mode you pick
scripts/ui/title.gd                  Who is playing, what to play
scripts/game_base.gd                 What both modes share: players, swords, camera, HUD, forge
scripts/cave/cave.gd                 The tutorial cave: map, rooms, stages
scripts/cave/crawler.gd, burrower.gd, guardian.gd   The cave's enemies and boss
scripts/cave/hazard.gd               Red warning circles and lanes
scripts/cave/cave_ui.gd              Objective, prompts, boss bar, speech box, cards
scripts/main.gd                      The test arena
scripts/player.gd                    Movement, dodge, the swing chain, runes
scripts/player_input.gd              One player's controls (any device, keyboard, or one controller)
scripts/camera_rig.gd                The shared camera
scripts/enemy.gd                     Enemy base: being hit, knockback, the arena's enemies
scripts/weapon/swing_build.gd        Blades, grips, fittings and the reading rule
scripts/weapon/sword_art.gd          Draws the sword with its slots
scripts/ui/swing_forge.gd            The forge screen
scripts/fx/rune_fx.gd                Rune visuals
art/cave/                            Cave art (cave.md lists every file, cave.json has the numbers)
```

## Older notes: the grid sword on `main`

Everything below describes the first prototype (the part grid), which is still on the `main` branch. It is kept for reference.

### Running it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

### Controls (grid sword)

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

### The sword

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

### Adding a part

Parts are data files in `parts/`. Every `.tres` file in that folder is loaded automatically.

1. In Godot's FileSystem panel, right click a part (for example `parts/cross_hilt.tres`) and choose **Duplicate**.
2. Click the new file and change its values in the Inspector: name, type, material, shape, colour, move, and stats.
3. Give it a new `id`. Run the game and it's in the parts list.

Then check it still fits its spot on the sword:

```
godot --headless --script res://tests/check_parts.gd
```

### Project layout (grid sword)

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

### Art

The game runs at **640x360**, doubled to a 1280x720 window (integer scaling). The HUD and forge are laid out at 1280x720 and drawn at half size, so text stays sharp.

Sprites live in `art/` and are named by what they show. `art/sprites.md` lists every file, its frame size and anchor points, and `art/anchors.json` has the same numbers for code.

- **The sword is built at runtime.** Each part has `art/parts/<part id>_hand.png` (5 px per grid cell) and `<part id>_grid.png` (18 px per grid cell for the forge). The game places every part on its grid cells, rotates the lot to the aim around the grip, holds it at Ivy's hand, and outlines the assembled sword with `shaders/outline.gdshader`. A new part only needs its two images.
- **Ivy** faces the nearest of 4 directions to the aim, with idle, walk and dodge animations. The sword goes behind her when she faces up.
- **Enemies** play idle, move, hit and death animations.
- **Lighting:** a cool darkening over the arena with warm lights on the torches and forge bench, and a soft light on Ivy.
- **Missing art falls back** to the old shapes, so you can add a part before its sprites exist.

`art/` has a `.gdignore` file, so Godot doesn't import it and the game also runs from a fresh copy (handy on Steam Deck). Before making an exported build, remove `.gdignore` and switch `scripts/art.gd` to `load()`.

When you're knocked out you respawn at the start point.

### Not in the grid prototype

Online co-op, the mini boss and part drop, rarity and affixes, a second weapon type.
