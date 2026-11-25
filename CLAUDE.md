# Code map for Claude

A short guide to where things are, so a session can find code without reading it all.
Keep it current: when a script is added, moved or changes job, change its line here.
The README is the long, plain-words story for Darren; this file is only for finding your way.

## Rules of the repo
- Godot 4.7, GDScript. The newest game is on the branch `latest`. `main` gets the game only when Darren says so.
  `swing-path` is frozen at version 29.
- Every pushed change to the game gets a new version: `godot --headless --path . -s tests/version_check.gd -- stamp`
  (it stamps scripts, art, parts, scenes and shaders; tests, tools and the README are not stamped). Run it with no
  arguments to check the stamp.
- Numbers Darren may tune are `static var` (not `const`) and listed in `scripts/lab.gd`. When he pastes lab lines
  (`Page > Group > Label: old -> new  [script:NAME/key = value]`), the bracket names the variable; `Lab.SCRIPTS`
  maps NAME to its script. Make those the code's own numbers and fix any check that froze the old ones.
- Every choice not made by Darren goes in the README (the version's section and "Choices made here that nobody has
  confirmed") as Claude's.

## Checks
- `tests/run.sh [area ...]` runs the suites quietly: one line each, plus only what failed. Areas: `highlands`,
  `weapons`, `cave`, `all` (the default, about five minutes), or name single suites (`tests/run.sh lab`).
  `--full` prints whole outputs; every suite's whole output is kept in `$CHECKS_LOG` (default `/tmp/checks`).
  Needs `GODOT=/path/to/godot` unless `godot` is on the PATH.
- While working, run the area you changed. Before each push run all of them, `tests/online.sh <godot> fast`
  (look for "ONLINE TEST PASSED") and the version check.
- One suite by hand: `godot --headless --path . --fixed-fps 60 -s tests/<name>.gd`.
- Pictures need a window: `xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 -s <script>`.

## Where things are
| Path | What it holds |
|---|---|
| `scripts/boot.gd` | The game's front door: title screen, then the mode picked. Only it reads the lab file. |
| `scripts/game_base.gd` | What the test arena and the tutorial cave share: players, camera, world. |
| `scripts/main.gd` | The test arena (dummy, endless enemies, forge, lab, spawner). |
| `scripts/player.gd` | The player (about 5,300 lines): moves, dodge, aiming, the combo, every rune's effect, `MOVES` (each attack step). |
| `scripts/player_input.gd`, `input_setup.gd` | One player's controls per tick; every input action registered in code. |
| `scripts/weapon/swing_build.gd` | Weapon data and rules: metals, blade/bow/hammer/staff shapes, parts, runes and threads (`FITTINGS`), `*_info()`, a rune's forge sentence. |
| `scripts/weapon/*_art.gd` | Drawing swords and bows from `art/swing/`. |
| `scripts/enemy.gd` | Arena and cave enemies (crabs, dummies), damage taking, the Stagger meter. |
| `scripts/cave/` | The tutorial cave (`cave.gd`), its crawler, burrower, forge guardian, hazards, screen furniture. |
| `scripts/highlands/highlands.gd` | The Highlands game: makes the world, players, systems, saving hooks, the Highlands-only shares. |
| `scripts/highlands/world_gen.gd`, `land_map.gd` | Making a map from a seed (rings, places, ore, dressing, pine groves); the map as tiles. Raise `WorldGen.GEN` when the land changes, then `tests/saving.gd -- ref`. |
| `scripts/highlands/land_painter.gd`, `land_view.gd`, `veins.gd` | Painting the land from the art kit; showing it near the camera; ore veins. |
| `scripts/highlands/charts.gd` | The small map, the whole map on M, the seen land, the lab's map switch. |
| `scripts/highlands/foes.gd`, `foe_plan.gd`, `nav.gd` | Who lives where (goblin ground round the Scrapyard: `SCRAP_REACH`), waking and coming back; the way round rock. |
| `scripts/foes/` | The Highlands enemies (`foe.gd` shared; hound, slinger, scrap brute, shaman, bat, rock) and Rattlecrown. |
| `scripts/highlands/crown.gd`, `crown_plan.gd` | The Scrapyard, the Throne Room fight, traps, hoard. |
| `scripts/highlands/loot.gd`, `loot_plan.gd` | Chests (each player's share waits in the chest: `left_in`, `take`, `take_all`), drops, coins, Memory. |
| `scripts/highlands/levels.gd`, `perks.gd` | Memory and the forge's levels, the four role trees and every perk. |
| `scripts/highlands/folk.gd`, `folk_plan.gd` | Pip, his cage, the quests and their list, the waystone. |
| `scripts/highlands/bag.gd`, `gear.gd`, `accessories.gd` | The inventory, the Accessory Satchel, what each accessory does. |
| `scripts/highlands/tools.gd` | Pickaxe, axe, mallet: digging, mining, felling; blows by name (`NEED`) and by make (`POWER`). |
| `scripts/save.gd` | Saved characters and worlds. |
| `scripts/lab.gd`, `scripts/ui/lab_screen.gd` | The lab's list of numbers; its screen. |
| `scripts/ui/` | Screens: forge (`swing_forge.gd`), the Highlands forge (`forge_hall.gd`), HUD, inventory and a chest's inventory (`pack_screen.gd`), shop, pause, save pick, title, online menu, version corner. |
| `scripts/net/` | Online play for two (on hold). |
| `scripts/art.gd`, `sfx.gd`, `music.gd`, `sim.gd`, `version.gd` | Loading art by name; sounds made in code; music; the game's dice; the version stamp. |
| `art/`, `parts/`, `scenes/`, `shaders/` | Pictures and their json; weapon parts as `.tres`; scenes; shaders. |
| `tools/` | Bakers and picture makers (map overviews, Rattlecrown kit, perk icons, the Windows exe). Not part of the game. |
| `tests/` | One suite per area (named after it), `run.sh`, `online.sh`, `version_check.gd`. |
