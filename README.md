# Modular Weapon Prototype

A Godot prototype for a co-op top-down game about building weapons from parts.

This branch (`swing-path`) has four things to try:

- **The tutorial cave** (Game Plan milestone 4): four rooms, from a shipwreck crate to a forge guardian, for one or two players. You choose your weapon at the crate: a sword or a bow since version 21, a hammer or a staff too since version 27.
- **Two players on one screen.**
- **Two players online**, one on each computer (see "Playing online" below).
- **The test arena**: the sandbox for trying weapons out, with every sword part unlocked. You can't be hurt there unless you switch that off, and you can stop the enemies where they stand (see "Controls").
- **The bow** (versions 18 to 21, Game Bible milestone 6). In the test arena press **B** (or click the right stick) to swap your sword for an iron shortbow and back, and open the forge with the bow in your hand to change its limbs, grip, string and arrows and to fit its own six runes (Pierce, Ricochet, Steady Aim, Volley, Snipe, Arrow Rain). In the tutorial cave take the wooden bow from the crate and play the whole cave with it. See "The bow" below.
- **The hammer and the staff** (version 22 on, Game Bible milestone 7). In the test arena **B** now goes round four weapons: sword, bow, an iron maul and an iron staff, and since version 23 the forge changes the one in your hand: another head, haft or shaft, counterweight or cap, crystal, bands, and three presets of its own. Since version 24 the hammer has its six runes (Momentum, Stagger, Aftershock, Quake, Bulwark, Hook) and since version 25 the staff has its own (Orbit, Chain, Overflow, Nova, Lance, Spectre); since version 27 the tutorial cave's crate hands both out, and you can play the whole cave with either. See "The hammer and the staff" below.
- **The lab** (version 28). Press **L** in the test arena, or choose **Lab: change numbers** in the pause menu anywhere: about 200 of the game's numbers (damage, speeds, recharges, health, the boss) can be changed while the game runs, are in force at once in the arena and the cave, and are kept on your computer. Its **Spawn** page puts any enemy in the game into the arena, the forge guardian included, and **Copy my changes** hands your numbers back so they can become the game's own. See "The lab" below.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

The game opens on the intro screen: a picture of the game at its best moment, alive with small movement (four players on the forge guardian at once, each with a different weapon and ability), with the buttons that start a game. For now those are **Tutorial**, **Arena**, **Play online** and **Quit**. "New game" and "Continue" will go on top of them later; the column already keeps the room.

### The intro screen

The picture is not built into the code. `art/title/title.json` lists its layers from back to front, and `scripts/ui/title.gd` draws whatever is listed, so the art can be swapped or added to without touching a script. Every layer is one picture in `art/title/`:

| Key | What it does |
|---|---|
| `file` | The picture. |
| `at` | Its top-left corner, `[x, y]`. Left out, it is the corner of the screen. |
| `frames`, `fps` | A strip of frames side by side that loops: a scarf in the wind, the sea, someone breathing. |
| `cols` | When one row of frames would be too wide a picture: the frames sit in rows of this many, read left to right and then down. |
| `scroll` | `[x, y]` pixels a second. The picture drifts a whole pixel at a time and repeats in the direction it moves (clouds, mist), so it must be drawn to tile. |
| `blend` | `"add"` for light: glows, light shafts, reflections. |
| `pulse` | `[lowest, highest, seconds]`: how see-through it is breathes between the two (a lantern's light). |
| `bob` | `[x, y, seconds]`: it sways that many pixels there and back (a boat, floating wreckage). |
| `alpha` | How see-through it is all the time. |

Beside the layers: `scale` (1 for a 640 x 360 picture, 2 for a 320 x 180 one like the opening cutscene), `embers` (sparks drawn in code that rise inside `area` `[left, top, right, bottom]`: `count`, `rise` in pixels a second, `sway`, `colors`), `logo` (`at`, and `file` if the name is a drawn picture; without one the words are set in the game's font), `menu` (`at` is the top-left of the button column, `width`, and `plate` from 0 to 1 for a dark plate behind it) and `music` (a track from `art/music/`, or nothing).

Today's picture (12 November, the art thread's second design) is the fight, frozen: the forge guardian in front of the blazing forge gate with its hammer over its head, and four players on it, each on their coloured ring with a different weapon and ability. Gold has the bow (Volley), violet the staff (Lance), blue the hammer (Quake) and red the sword (Leap). It is three layers at scale 2: the wall, gate and floor; a band of smoke that drifts under the roof; and one 48-frame loop of six seconds for everything else. Nothing travels: the trails, the beam, the cracks, the scarves, the guardian's heart and the sparks shimmer in place. The bow, staff and hammer there are first drawings for this picture only, older than the weapons in the game, and players three and four are the two crew recoloured. The calm cave music plays under it.

Darren asked for it after seeing the first design (sunrise, two of the crew on a headland looking at the colossal sword): with four players coming it made the game look like a two-player one, and he wanted something new and more exciting that remembers the different weapons and abilities. The first design was version 14 and is in the history.

Nothing in it may move the forge's flames: Darren's rule is that forge backdrops stay still. Motion is slow and small everywhere.

Every few seconds a glint of light runs along the name. The name itself is a working one ("MODULAR WEAPON / PROTOTYPE"): the game has none yet, and it is one constant, `NAME`, in `scripts/ui/title.gd`.

The bottom band of the screen says what the buttons do and who has joined; the version number sits under it. Picking a row fades the screen to black for a moment and then starts the game. `tests/title_screen.gd` checks the picture's files and numbers, that six rows fit above the bottom band, and that joining and choosing start the right game.

### One file to send to a friend (Windows)

`tools/make_exe.gd` packs the whole game into a single `.exe` that runs with a double-click: no Godot to install and nothing to unzip.

```
godot --headless --path . -s tools/make_exe.gd -- template=/path/to/windows_release_x86_64.exe out="/path/to/Modular Weapon Prototype v16.exe"
```

`template` is Godot's own empty game runner for the same Godot version (4.7). It is inside the "Export templates" download on the Godot site (a `.tpz` file, which is a zip: `templates/windows_release_x86_64.exe`).

The pack holds `project.godot` and every file of the game exactly as it is in this folder, so the packed game is the same game: the version number in the corner does not say "+ changes", and online play accepts it as the same copy as the folder run in Godot. The pack is put on the end of the runner the same way Godot's own export does with "Embed PCK" on. This is why the game's pictures, fonts and music are read through Godot's file system (`Art.image`, `Art.font`, `scripts/music.gd`) and never straight off the disk: a packed game has no folder to read from.

The file is not signed, so the first time it is run Windows shows "Windows protected your PC": click **More info**, then **Run anyway**.

### Which version is this?

The bottom-left corner of every screen says **Version 5** (or whatever the number is now). The number goes up by one with every change that is pushed, so after a pull you can see that you have the new one, and two people can check they have the same one.

If it says **Version 5 + changes**, the files in this folder are no longer exactly version 5's: a script or a picture was changed (or a pull stopped half way) since the number was given.

The number lives in `scripts/version.gd`. Don't edit it by hand: see "Checks" below.

## Two players

Both players share one screen. One uses the keyboard and mouse and the other a controller, or both use controllers.

1. On the title screen each player presses their own button to join: **Enter** (or a click) for keyboard and mouse, **A** for a controller. The first to press is player one.
2. Either player then picks **Tutorial** or **Arena**.

Player one is blue and player two is orange (the ring under their feet and the bar by their health). The camera stays between you, and you can't walk further apart than one screen.

To play with someone who isn't in the room, use **Play online** (next section).

With one player, every device works at once, so you can swap between mouse and controller freely.

## Playing online

Two players, one on each computer. One hosts and the other joins.

**You both need exactly the same copy of the game**, run with the same version of Godot (4.7): the version number in the bottom-left corner of the screen must be the same for both of you. The simplest way is to send your friend the same zip you play from. If the two copies differ, the game says so when your friend tries to join, and doesn't start.

1. Both of you start the game and pick **Play online** on the title screen.
2. One of you picks **Host a game**. The first time, Windows asks whether to let Godot through its firewall: choose **Allow**. After a few seconds the screen shows the address your friend should use.
3. Tell your friend that address. **Copy the address** puts it on the clipboard so you can paste it into a chat.
4. Your friend picks **Join a game**, types the address and presses **Join**.
5. When the host's screen says your friend has joined, the host presses **Start: Tutorial cave** or **Start: Test arena**.

Each player uses their own keyboard and mouse or controller, whichever they touched last.

What is different from sharing a screen:

- Each of you has your own camera, and you can walk as far apart as you like.
- Each of you has your own forge screen. The game carries on for your friend while you are at the forge. You can't move or be hurt while you are there, and your friend sees "AT THE FORGE" over your head.
- The pause menu no longer pauses the game. **Leave the game** in it ends the game for both of you.
- Everything you do happens a moment after you press it (usually 50 to 100 thousandths of a second, depending on the connection). That delay is what keeps the two games identical. The game measures the connection and picks the delay when a game starts.
- If one computer or connection stalls, both games wait and show "Waiting for your friend...". After 20 seconds of nothing the game gives up and returns to the title screen.

### If your friend can't connect

When you host, the game asks your router to let your friend in. Most routers agree, and the host screen then shows your internet address. If it can't, the screen says so, and one of these fixes it:

- **A free VPN app made for games** is the quickest fix and works on every kind of connection. Both of you install the same one, for example [Tailscale](https://tailscale.com) or [Radmin VPN](https://www.radmin-vpn.com), and join the same network in it. Host again, and the host screen lists the VPN address (it says "Tailscale" or "Radmin VPN" beside it). Your friend joins with that address.
- **Open the port on the host's router** (called "port forwarding"): forward **UDP port 24565** to the host's computer. The router's manual, or a search for its model and "port forwarding", shows how. This does not work if the host screen says your internet provider shares one address between several homes; use a VPN app then.
- **On the same Wi-Fi or network** nothing needs opening: use the address the host screen lists as "same Wi-Fi or network".

If joining says the connection timed out even though the address is right, the usual causes are the Windows firewall on the host's computer (check that Godot is allowed on private and public networks) or one of the above.

If a red "Out of sync" message ever appears, the two games have stopped matching, which is a bug. Leave and start again, and send both `out_of_sync_player1.txt` and `out_of_sync_player2.txt` to whoever is working on the code. Each player has one of them, in `%APPDATA%\Godot\app_userdata\Modular Weapon Prototype\`.

### How it works, and the rules it puts on the code

Both computers run the whole game. Only each player's button presses are sent, and each press takes effect a few ticks later on both computers at the same tick ("lockstep"). So the two games must stay identical on their own: every 20 ticks they compare a checksum of the game, and a difference is the "Out of sync" message. The session is `scripts/net/session.gd`.

Game code must follow these rules, or the two games drift apart:

- Anything that changes what happens in the game runs in `_physics_process`, never `_process`, a tween or a timer. (For "do this in two seconds", the cave has `_after(seconds, what)`.)
- Random numbers that decide what happens come from `scripts/sim.gd` (`Sim.chance()`, `Sim.between()`). Looks and sound may keep using `randf()`.
- Game code never reads `Input` for a player. It reads `player.input`, which the session fills in for both players.
- A choice made in a menu (changing the sword, closing the forge) is sent with `Net.command([...])` and applied in `net_command(i, cmd)`, so it happens on the same tick for both.
- Online, nothing pauses the game except the session.
- Anything new that affects the game should be added to `net_state()` so the checksum covers it.
- Both computers play with the game's own numbers: the lab's changes (see "The lab") are switched off for an online game and the lab can't be opened in one.

`tests/online.sh` runs two copies against each other on one computer and compares every checksum (see "Checks").

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD or arrows | Left stick or d-pad |
| Attack | Left click (swings, or shoots, toward the mouse) | X or right trigger (swings or shoots the way you face, or aim with the right stick) |
| Keep attacking | Hold left click | Hold X |
| Dodge | Space or Shift | A or left trigger |
| First active rune (hold for Whirlwind; hold and let go for Snipe, on whichever button it is) | Right click | RB |
| Second active rune | Q | LB |
| Third active rune | R | B |
| Use (crate, rune, forge, talk) | E or F | A or Y, when the prompt shows |
| Pause menu | Esc | Start (in the cave) |
| Fullscreen on or off | F11 | |
| Test arena only: open the forge anywhere | Tab | Y |
| Test arena only: pause the enemies, or let them go | P | Start |
| Test arena only: Invincible on or off | H | Select |
| Test arena only: the next weapon (sword, bow, hammer, staff) | B | Click the right stick |
| Test arena only: the lab (change the game's numbers, put enemies in the room) | L | Click the left stick |

**The test arena's switches.** With one player they are also buttons at the top right (the third one puts the next weapon in your hand, the fourth opens the lab), and the words under the kill count say how they stand.

- **Invincible** is on when the arena starts: nothing can hurt you, because the room is for trying swords and runes out. Switch it off for a real fight; switching it back on refills your health.
- **Pause enemies** really pauses them: nobody new arrives, and the ones in the room stand still, go dull, show a small pause mark and hurt nobody. You can still hit them, push them about and kill them, so they make good targets for a rune. (Before version 17 it only stopped new ones arriving.)

**At the forge** (the game pauses): drag a part onto a slot, or click a slot and then a part. Right-click or drag off to remove. Keys or controller: up and down pick a slot, left and right pick a part, Q/E or the shoulder buttons change tab, Enter or A fits it. **To leave, click BACK at the top left, or press Esc (B on a controller); Tab or Y works too.** Point at a rune and hold Alt (the left trigger on a controller) to see a picture of it firing. Point at a blade, grip or pommel you could fit and the numbers show what it would change: gains in green with a plus, losses in red with a minus. **Presets:** A, B and C at the top right are three saved swords. Click one (or press C, or Select on a controller) and the whole sword changes to it; click the name beside them to type a name of your own.

## The tutorial cave

It follows the "Tutorial opening" in the Game Plan. You shelter from a storm in a sea cave, the entrance collapses, and the only way out is up.

It opens with a 23 second cutscene: the ship in the storm, the wreck on the rocks, and the cave mouth coming down behind the crew. With two players both are on deck. Press attack or use once and "Press again to skip" appears; press again to skip it. Online, either player's skip skips it for both. The pictures and their numbers (speed, captions, when each sound comes) are in `art/cutscene/intro/`, and `cutscene()` in `scripts/cave/cave_ui.gd` plays them. The wind, thunder and crash are placeholder sounds made in code, like the rest.

The cave has music (version 11). A calm loop starts when the cutscene ends, fight music takes over when the forge guardian wakes (and stays through a knock-out and restart), and the calm loop comes back when the guardian falls. `scripts/music.gd` plays the tracks and fades one into the other; the two Ogg files and the scripts that made them are in `art/music/`, and how loud each sits is `VOLUME` in `scripts/music.gd`. Music is each screen's own, so it never touches the game state and is safe online.

1. **The wreck.** Search the ship's crate, choose a wooden staff, sword, bow or hammer from the four plates that rise over it (stand under one and press Use), then fight a few crawlers. They rear up before they bite, and a hit while they rear up stops the bite. Once the room is clear you can go back to the crate and swap, until the next fight starts.
2. **The burrows.** Burrowers travel underground, come up, flash red and lunge in a straight line. Dodge aside and hit them while they lie stunned.
3. **The nest.** A mixed fight. Clearing it lets you take your first rune (Shockwave for a sword, Steady Aim for a bow, Quake for a hammer, Lance for a staff), which your weapon can't use yet.
4. **The forge.** The forge is a colossal sword set in the north wall, with a knight kneeling asleep in front of it. Fit the rune to your weapon there and the forge lights, molten metal runs down the floor channels, and the guardian wakes. (Quake and Lance are active runes, abilities on a button, so with a hammer or a staff a card first says which button: right mouse or RB.) It has four attacks, each marked on the floor in red before it lands, and a line under its health bar names the attack and says what to do. **Slam**: a circle fills, then the hammer comes down. **Charge**: a lane shows the path, and a charge that hits a wall stuns it. **Quake**: cracks run out from it like the spokes of a wheel, so stand between them. **Rockfall**: rocks drop one after another where you stand, so keep moving, and hit it while it stands still. The first four attacks are one of each, and it never does the same one twice running. Below half health it slams three times in a row, a second ring of cracks fills the gaps of the first, and more rocks fall. The timings are at the top of `scripts/cave/guardian.gd` (`SLAM_WINDUP`, `REST` and so on). Beat it and the old smith is freed: he explains runes (round ones work by themselves, square ones are active and give you an ability on a button once slotted into the weapon) and bands, and hands over your weapon's tin parts (a blade and a grip; limbs, a grip and arrows; a head and a haft; a head, a shaft and a crystal). Forge the tin weapon and the stairs to the surface open.

Rules:

- After each room everyone is healed and anyone knocked out gets back up. There are no revives mid-fight.
- If everyone is knocked out, that room (or the boss) starts over.
- With two players there are more enemies, the guardian has more health, its rockfall is longer, and it also brings rocks down after each charge.
- The crate offers all four wooden starters (Game Bible): the sword and the bow since version 21, the staff and the hammer since version 27. Two players can take different weapons: each then gets their own weapon's rune and tin parts, and the smith's words and the hints fit whoever is there.

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
godot --headless --path . --fixed-fps 60 -s tests/active_runes.gd              # Whirlwind, Leap and Ghostwield on their buttons (and Hook, the hammer's now, put on a sword by hand), the bands on them, and Weak Point
godot --headless --path . --fixed-fps 60 -s tests/blade_shapes.gd              # the six blade shapes: reach, what each move hits, each lean, damage a second
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd          # plays the whole cave with a sword
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- bow   # with a bow ("swap": takes the sword, swaps it for the bow after room 1)
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 bow    # two players, a bow and a sword ("bows": two bows)
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 wipe down
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- hammer           # with a hammer, or "staff"; "players=2 hammer staff": one of each ("hammers", "staffs": two the same; "swap=staff": takes the sword, swaps it for the staff). The bots must use Quake and Lance on the guardian
godot --headless --path . --fixed-fps 60 -s tests/cave_words.gd                # the cave's words for each of the four weapons and every pair of them: cards, hints, the smith's lines; each names the right weapon and rune and fits its plate ("-- show" prints them all)
godot --path . -s tests/smoke_forge.gd                                         # opens the forge, fires every rune; every word fits its plate; BACK leaves; the bow, the hammer and the staff on the anvil
godot --headless --path . --fixed-fps 60 -s tests/title_screen.gd              # the intro screen: its picture, its buttons, joining and choosing
godot --headless --path . --fixed-fps 60 -s tests/arena_switches.gd            # the arena's two switches: Invincible, and Pause enemies
godot --headless --path . --fixed-fps 60 -s tests/bow.gd                       # the bow: swapping, its numbers, the forge and presets, what an arrow hits and where it stops, the longbow, damage a second against the sword's
godot --headless --path . --fixed-fps 60 -s tests/bow_runes.gd                 # the bow's six runes: their rules, pictures and sentences, and each one with every band in the arena (takes about two minutes)
godot --headless --path . --fixed-fps 60 -s tests/hammer.gd                    # the hammer: its parts, swing, swing, slam and what each hits, that it pins and slows you, the warhammer, damage a second against the sword's
godot --headless --path . --fixed-fps 60 -s tests/hammer_runes.gd              # the hammer's six runes: their rules, pictures and sentences, and each one with every band in the arena
godot --headless --path . --fixed-fps 60 -s tests/staff.gd                     # the staff: its parts, bolt, bolt, burst, range and walls, mana and the weak sparks without it, the storm head, damage a second against the sword's and the bow's
godot --headless --path . --fixed-fps 60 -s tests/staff_runes.gd               # the staff's six runes: their rules, pictures and sentences, each one with every band in the arena, and a Spectre given to a teammate with a sword and with a bow
godot --headless --path . --fixed-fps 60 -s tests/lab.gd                       # the lab: every number it shows is really in the game and inside its limits, a change reaches the game and a reset takes it out, the file, online uses the game's own numbers, the screen in the arena and the cave, the spawner ("-- show" prints every number)
godot --headless --path . -s tests/version_check.gd                            # the version number was raised if anything changed
```

**Before every push that changes the game**, give it the next version number. This raises the number by one and records which files it belongs to (it does nothing if nothing changed):

```
godot --headless --path . -s tests/version_check.gd -- stamp
```

Online play (needs bash, so Linux, macOS or Git Bash on Windows). Each line runs two copies of the game against each other, plays the whole cave or the arena with scripted players, and checks the two games matched at every checksum:

```
tests/online.sh /path/to/godot                         # the cave, as fast as the computer can
tests/online.sh /path/to/godot fast bow                # the cave with a bow for player one and a sword for player two (also "bows" and "swap")
tests/online.sh /path/to/godot fast hammer staff       # the cave with a hammer for player one and a staff for player two (any of the four, in player order; also "hammers", "staffs", "swap=staff")
tests/online.sh /path/to/godot fast hard drop=0.1      # with knock-outs and 10% of messages lost
tests/online.sh /path/to/godot fast arena              # the arena: forge, sword changes, the two switches, swapping to the bow, shooting, its runes (Volley, a Snipe let go on time and one held too long, Arrow Rain, Ricochet), and changing the bow at the forge. Since version 22 both players go round all four weapons, so the hammer's swings and the staff's bolts and mana are compared too; since version 23 player 1 changes a hammer at the forge and player 2 a staff, and both computers must agree on what they made; since version 24 all six of the hammer's runes must go off on both (Quake, Bulwark, Hook and Aftershock from the arena's hammer, Momentum and Stagger fitted at the forge); since version 25 all six of the staff's too (Nova, Lance, Spectre and Chain from the arena's staff, Orbit and Overflow fitted at the forge).
tests/online.sh /path/to/godot real lag=45 drop=0.05   # at normal speed with a slow, lossy connection
tests/online.sh /path/to/godot real host:slow=22       # one computer that can't keep up
```

To skip the title screen while testing: `godot --path . -- cave` or `godot --path . -- arena`.

## The bow (versions 18 to 21, 14 November)

Game Bible milestone 6 ("the bow is as fun as the sword, and you can finish the tutorial cave with it"), built a stage a version: a bow you can shoot in the test arena (18), the bow at the forge (19), its six runes (20), the tutorial cave with a bow (21). All four stages are built; whether it is as fun as the sword is for Darren to say.

- **Swap** with **B** or a click of the right stick (one player also has a SWAP button at the top right). Everyone in the arena carries test sword D and an **iron shortbow** with iron arrows on a two-slot grip, fitted since version 20 with Volley, Snipe and Arrow Rain on the three buttons and Ricochet. Whatever you change on the sword is still there when you swap back.
- **Shooting** is the same button as swinging, and holding it keeps shooting. The shortbow's chain is **quick shot, quick shot, heavy shot** (Game Bible). Each shot first draws the string (0.13 s, 0.22 s for the heavy one); the arrow leaves when the draw ends, **towards wherever you are aiming at that moment**, so you can turn while you draw. You walk at 80% speed while shooting ("you can move while shooting, slightly slowed").
- **An arrow** flies straight at 1300 px a second for 520 px (a sword reaches 91), hits the **first** enemy on its line and stops there; a wall stops it too. A spent arrow stands where it stopped for a moment and fades. Arrows never run out (Game Bible: infinite once owned).
- **Damage** (Claude's numbers, for Darren to overturn): an arrow does **80% of a sword hit** in the same metal (iron: 8.8, heavy shot 13.2), and hits one enemy where a slash hits everything in its arc. Against a single enemy the iron shortbow does 0.85 of the iron broadsword's damage a second (`tests/bow.gd` measures it). The reason is the Game Bible's rule that ranged must not beat melee. It was 75% in versions 18 to 20; version 21 raised it so that one chain of the wooden bow (4 + 4 + 6) is exactly one crawler's 14 health, as one chain of the wooden sword is, and a burrower takes four arrows, not five.
- **At the forge** (version 19): open the forge with the bow in your hand and the bow stands on the anvil. The first tab is called BOW and has four rows: **limbs** (they set the chain, the range and how fast you walk while shooting), **grip** (slots), **string** (numbers only, the pommels' four: plain, keen, heavy, light) and **arrows** (the damage: wooden, tin, iron). Pointing at a part shows what it would change on the numbers plate, which shows Range where a sword has Reach. Slots work as on a sword: the grip's are under the hand, the limbs' on the upper limb, and the line reads bottom to top. Each weapon has its own three loadout presets.
- **Two sets of limbs so far.** The **shortbow** (quick shot, quick shot, heavy shot) and the **longbow** (three long shots: a slower draw, a faster arrow, 35% more range, a hard shove on every shot, and you walk at 70% while shooting). Three heavy shots would be more damage a second, so a longbow's arrows are a tenth lighter and the two bows come out the same (`tests/bow.gd` measures it). The recurve and the hunter's bow from the Game Bible are not built.
- **Runes belong to a weapon.** The sword's runes can't be fitted to a bow and the bow's can't be fitted to a sword (`SwingBuild.fits()`); bands and rule-benders fit both. The bow's RUNES tab shows its own six (see "The bow's runes" below).
- **Not yet:** the recurve and hunter's limbs.

### The bow in the tutorial cave (version 21)

- **The crate.** "Search the crate" opens it, and a row of plates rises over it: staff (locked), sword, bow, hammer (locked). The plate you stand under lights in your colour and the prompt names it; Use takes it. There are enough training weapons for everyone, so two players can both take the bow. While the room's fight is on the row is hidden (on a controller the dodge button is also Use, and a dodge beside the crate must not swap your weapon); once the room is clear it is back, and you can swap until room 2's fight starts.
- **The first rune** is each weapon's own: Shockwave for the sword (Game Bible), **Steady Aim for the bow. That is Claude's choice**: the Bible lists the bow's starter rune as an open item, and says a starter rune must help against a single boss, which of the bow's three passive runes only Steady Aim does.
- **The smith** hands a bow player tin limbs, a tin grip and tin arrows. A tin bow counts as forged when the limbs and the arrows are tin and the rune is in a slot (the arrows are a bow's damage).
- **Words.** The cards, hints, objectives and the smith's lines fit the weapons in play: one text for swords, one for bows, one when the players differ. Online they go by every player, not by your own weapon, because a line of speech must be the same length on both computers.
- **How long the fights take** with the test's scripted players (three runs each, seconds): crawlers 11.6 with the sword and 12.7 with the bow, burrowers 13.1 and 11.9, the nest 19.2 and 20.0, the guardian 24.3 and 22.3. The bow's player was hit less often. Scripted players are not people: this only says the cave is neither a slog nor a walkover with a bow.
- Where it lives: `CRATE_WEAPONS`, `STARTER_RUNE`, `TIN_PARTS`, `WORDS` (every weapon's own words, since version 27), `_open_crate`, `_take_weapon`, `_can_take`, `_by_weapon` in `scripts/cave/cave.gd`; the plates are drawn by `scripts/cave/cave_ui.gd` (`picks`) from `art/cave/ui/pick_*.png`.

### The bow's runes (version 20)

Three passive and three active, like the sword (Game Bible). The Bible describes Steady Aim, Volley, Snipe and Arrow Rain; **Pierce and Ricochet are only names there, so what they do is Claude's design**, and so is every number below. All of it is for Darren to overturn.

- **Pierce** (passive): your finisher's arrow goes on through the enemy it hits and strikes the next one on its line at full damage. Twice: through two enemies. Wider: a wider path. Every Hit: every arrow goes through, at half damage behind the first enemy. Saved Up: every third finisher goes through three. On Dodge: the first arrow after a dodge goes through too.
- **Ricochet** (passive): an arrow that hits jumps on, as a teal arrow of its own, to the nearest other enemy within 150 px for half its damage. Twice: it jumps twice. Wider: it finds enemies further away. Every Hit: it splits in two as it jumps, a quarter of the damage each. Saved Up: every third hit, at one and a half times the arrow. On Dodge: a dodge sends one out from you.
- **Steady Aim** (passive, the Bible's numbers): while you stand still and shoot you shoot faster, 10% more each second up to +50%, shown as a ring that fills at your feet. Walking resets it; standing without shooting keeps what you have. Twice: builds twice as fast. Wider: up to +80%. Every Hit: each arrow that lands adds 5%. Saved Up: builds a third as fast, and once full every third arrow hits three times as hard. On Dodge: a dodge no longer resets it (walking still does).
- **Volley** (active, press, 4 seconds): three full arrows in a fan, so up close all three hit one enemy and from far only the middle one does. It doesn't interrupt the shot you were in. Wider: five arrows (seven with two). Twice: a second fan a beat later.
- **Snipe** (active, hold and let go, 6 seconds): holding its button draws the bow while a ring closes on you (0.7 seconds, at half walking speed). Let go as the ring closes, within a quarter of a second, and it is a PERFECT SNIPE at one and a half times the damage; let go early and it is half; hold on for 2.5 seconds and it goes by itself. The arrow flies half as far again as an ordinary one and does more the farther it flew: 2 arrows' worth up close, rising to 6 at 480 px. A dodge drops the draw without spending it. Wider: a longer perfect moment.
- **Arrow Rain** (active, press, 8 seconds): marks an oval on the ground, 112 by 80 px, and for 3 seconds arrows fall on it, ten falls of 0.35 of an arrow to everyone standing in it. With the mouse it lands on the pointer (up to 420 px away); with a controller on the enemy nearest your aim. Twice: a second shower where you are aiming as the first ends. Wider: a bigger oval. Saved Up: three times as heavy, and the arrows pin enemies in place for a moment. On Dodge: a small one-second shower where you dodged from.
- **The bands on the active three** follow the sword's rules: Every Hit takes half a second off the recharge for each arrow of yours that lands, Saved Up is three times as strong and three times as slow, and an On Dodge Volley or Snipe is at half strength.
- A rune's own arrows (the ricochet, the fan, the snipe, the rain) never crit and never set another rune off, so nothing chains for ever.
- **Balance.** Steady Aim at full is 1.5 times the bow's damage a second on one enemy, about 1.3 times the iron broadsword's (1.2 before version 21 raised an arrow's damage), for someone who has stood still and shot for five seconds. The others are area or burst on a recharge. This is the first pass; the Game Bible's rule is that ranged must not beat melee.
- Where it lives: the six entries in `FITTINGS` (they carry `"weapon": "bow"`) and the constants under them in `scripts/weapon/swing_build.gd` (`PIERCE_*`, `RICOCHET_*`, `STEADY_*`, `VOLLEY_*`, `SNIPE_*`, `RAIN_*`); "The bow's runes" section of `scripts/player.gd`; `scripts/arrow.gd` (an arrow can go through enemies, carry a rune's name and colour, and report how far it flew). Their pictures are in `art/swing/runes/`, `art/hud/` and `art/fx/`; the stills the forge shows on Alt were taken from the game. `tests/bow_runes.gd` checks every rune with every band.

How it is built:

- A bow is the same kind of thing as a sword in `scripts/weapon/swing_build.gd`: limbs in the blade's place, a bow grip, a string in the pommel's place, and arrows as a fifth part (`LIMBS`, `BOW_GRIPS`, `STRINGS`, `ARROWS`, `BOW_SHAPES`; `limb_info()` is the bow's `blade_info()`). `get_data()` is `[limbs, grip, string, slots, arrows]`. The weapon that isn't in the hand waits in `stowed`, and `take("bow")` / `take("sword")` swaps them.
- Shots are chain moves like any other (`quick_shot`, `heavy_shot` in `scripts/player.gd` `MOVES`, shape `"shot"`): the wind-up is the draw, and `_loose()` makes the arrow.
- `scripts/arrow.gd` is the arrow. It moves a whole physics tick at a time and tests the line it flew that tick, so a fast arrow can't skip through a thin enemy, and nothing in it is random: online, both computers fly the same arrow (arrows are part of the checksum, and swapping is a command sent to both).
- `scripts/weapon/bow_art.gd` draws the bow in the hand from `art/swing/bow/` (numbers in `art/swing/bow/bow.json`): the limbs are a strip of three frames (rest, half drawn, full draw) and the string is a line drawn in code through the hand that pulls it. At the forge (`draw_forge()`) the bow is three pictures hung on one axis (upper limb, grip, lower limb), a string between the tips, and an arrow across the hold.
- The forge screen (`scripts/ui/swing_forge.gd`) asks `build.weapon()` and draws whichever weapon is on the anvil: `_frame_size()`, `_slot_rect()` and `_draw_weapon()` choose between `SwordArt` and `BowArt`, `_cards()` gives the BOW tab its four rows, and `stat_rows()` its numbers.

## The hammer and the staff (version 22 on, 15 November)

Game Bible milestone 7 ("both weapons, and the cave crate offers all four wooden starters"), built a stage a version like the bow: both in the test arena (22), both at the forge (23), the hammer's six runes (24), the staff's six runes (25, with two runes' bands put right in 26), the tutorial cave with all four weapons (27). **All of them are built.** Darren asked for them on 14 November and left the design choices to Claude; every number here is Claude's first pass, for Darren to overturn.

- **Swap** with **B** or a click of the right stick: sword, bow, hammer, staff, and round again. Everyone in the arena carries an **iron maul** on a bound haft and an **iron staff** (the apprentice head on a carved shaft, with an iron-set crystal). The maul carries Quake, Bulwark and Hook on its three buttons and Aftershock as its passive rune (version 24); the staff carries Nova, Lance and Spectre on its buttons and Chain as its passive (version 25).

### The hammer

- "The close-range heavy hitter: big damage in a small area, so you must get in close" (Game Bible). An iron maul's swing does **18.7** (an iron sword's 11 and seven tenths more), it swings at seven tenths of a sword's speed, reaches three quarters as far (68 px, a broadsword 91) and you walk at 80% speed while swinging. Against one enemy it does **1.19 times** the iron broadsword's damage a second (`tests/hammer.gd` measures it).
- The maul's chain is **swing, swing, slam** (Game Bible). A swing is a short blunt arc. The **slam** lands on a **patch of floor** in front of you (38 px round, a little further out than the swings reach) and hits everything on it for one and a half swings.
- **A hammer pins, a sword shoves.** A swing stuns for 0.3 s and a slam for 0.6 s (a slash 0.16 s, an overhead 0.3 s) and shoves about half as far, so what you hit is still in reach for the next blow.
- **Two heads so far.** The **maul**, and the **warhammer**: three slow crushing blows that each land on a slightly smaller patch (32 px), stun for 0.7 s, and slow you to 70%. Each blow is lighter, so the two heads do the same a second. The spiked hammer and the sledge from the Game Bible are not built.
- Parts: head (`HEADS`: wooden, tin and iron maul, iron warhammer), haft (`HAFTS`: 1 to 3 slots) and counterweight (`WEIGHTS`: the pommels' four).

### The staff

- A bolt does what an arrow does: **80% of a sword hit** with the same tier of crystal (iron: 8.8), for the same reason (ranged must not beat melee). It flies **400 px** (an arrow 520) at 760 a second (an arrow 1300), so it is easier to see and to walk out of. You walk at 80% speed while casting, and the bolt leaves towards wherever you are aiming at that moment. A bolt is gone where it stops: nothing is left lying on the floor.
- The apprentice head's chain is **bolt, bolt, burst** (Game Bible). The **burst** is a bigger ball that hurts everything within 56 px of where it lands, or of where it stops if it hits nothing. Against one enemy the iron staff does 0.85 of the iron broadsword's damage a second, the same as the iron shortbow (`tests/staff.gd` measures it).
- **Mana** (Game Bible: "each cast costs a little and refills quickly, and at zero you still cast weak, slow bolts"). A staff holds 100. A bolt costs 6, a burst 10, a spray 6, an orb 12. It comes back at 10 a second always and at 45 a second more once you have not cast for 0.7 s. Casting without a rest runs it dry in about 13 seconds; three seconds' rest fills it. A cast you don't have the mana for is a **weak spark**: half the damage, three quarters of the casting speed, and it costs nothing. The bar under your health shows it, and flashes when a cast found too little.
- **The crystal** is the staff's damage (sea glass, tin-set, iron-set: wood, tin and iron) and tints its bolts its own colour (sea green, blue, violet).
- **Two heads so far.** The **apprentice**, and the **storm** head: **spray, spray, orb**. A spray is three small sparks in a fan, so all three only hit from close by; the orb is slow (304 px a second) and bursts 88 px wide. It reaches 280 px and up close does what the apprentice does a second. The channel and warden heads from the Game Bible are not built.
- Parts: head (`STAFF_HEADS`), shaft (`SHAFTS`: 1 to 3 slots), cap (`CAPS`: the pommels' four) and crystal (`CRYSTALS`).

How it is built:

- Both are the same kind of thing as a sword in `scripts/weapon/swing_build.gd`: a head in the blade's place, a haft or shaft in the grip's, a counterweight or cap in the pommel's, and for a staff a crystal where a bow has arrows. `heads_of()`, `grips_of()`, `butts_of()` and `shots_of()` give one weapon's parts, `weapon_of()` says whose a head is, and `WEAPON_ORDER` is the order B goes round them.
- They are drawn by the sword's own code (`scripts/weapon/sword_art.gd`), from pictures in the sword's formats in `art/swing/hammer/` and `art/swing/staff/` (numbers in `hammer.json` and `staff.json`); the crystal is one more picture, centred on the head's `crystal_at`.
- Moves are in `scripts/player.gd` `MOVES`: `maul_swing`, `maul_slam` and `crush` (shape `"impact"` is the patch of floor), and `bolt`, `burst`, `spray` and `orb` (shape `"cast"`, what each costs is in `SwingBuild.CAST_MANA`). "The staff" section there has mana and the casting. A bolt is an arrow (`scripts/arrow.gd`) with `bolt` set: it is drawn from a tinted strip, may splash where it stops, and never sticks.
- Online: mana is in the checksum (`net_state()`), and the arena test goes round all four weapons. Building this found that the third ability button was never sent to the other computer; that is fixed in version 22.

### Both at the forge (version 23)

- **F** with a hammer or a staff in your hand opens the forge on it, as it does for a sword or a bow. The first tab is named after the weapon: a hammer's has three rows (head, haft, counterweight) and a staff's four (head, shaft, cap, crystal). The arena's tray offers the two iron heads, three hafts or shafts (one, two and three slots), the four counterweights or caps, and the three crystals.
- **The numbers plate** has five rows for these two, set a little closer, because each has a number more than a sword. A hammer shows **Impact** (how big the patch of floor a slam hits is, as a share of the maul's 38 px) beside Reach. A staff shows **Range** as a share of the shortbow's, so the two can be compared (an iron staff reads 77%), **Blast** (the size of its spells: how wide a bolt is and how far a burst reaches; the storm head reads 125%) and **Mana a chain** (what one whole chain costs: 22 for bolt, bolt, burst and 24 for spray, spray, orb). Pointing at a part shows what it would change, as for a sword.
- The rune tab offers a hammer its own six runes since version 24 and a staff its own six since version 25 (see "The hammer's runes" and "The staff's runes" below). Presets A, B and C are each weapon's own, so a player now has twelve. The test-sword keys 1 to 4 do nothing while a hammer or a staff is on the anvil.
- How it is built: `scripts/ui/swing_forge.gd` no longer asks "is it a bow": `PART_ROWS` lists the first tab's rows for each weapon, `ICON_DIRS` says where a part's tray picture is, `_fit_part()` fits a head, grip, butt or shot of whatever weapon is on the anvil, and `stat_rows()` picks the numbers table. What a cast costs moved out of the moves into `SwingBuild.CAST_MANA`, so the forge can add up a chain. The art thread's forge pictures and tray icons for every part are in `art/swing/hammer/` and `art/swing/staff/`, and its pictures for the twelve runes are in already (`art/swing/runes/`, `art/fx/`, `art/hud/`), waiting for versions 24 and 25.
- `tests/hammer.gd` and `tests/staff.gd` check the forge for each (the rows offered, the numbers and what pointing at a part shows, fitting from the tray, presets of its own); `tests/smoke_forge.gd` checks that every part has its three pictures and a sentence that fits, that the cards stay inside the tray, the slots on the anvil, and every number with its change inside its column, for every combination of parts.

### The hammer's runes (version 24)

Three passive and three active, like the sword and the bow. The Game Bible gives each a line and Darren set Aftershock's bands on 11 November; **what the other bands do, and every number below, is Claude's design**, for Darren to overturn. In the test arena the iron maul carries Quake, Bulwark and Hook on its three buttons and Aftershock as its passive; the others are in the forge's rune tab.

- **Momentum** (passive): each swing that lands lights one of five chevrons round your feet, and each lit one makes your swings hit 8% harder, so +40% at five ("MOMENTUM +40%!"). Two seconds after your last hit they start to go out, one every half second. One swing is one step however many enemies it catches, and the bonus is for swings, not for what runes do. Twice: two steps a swing. Wider: bigger steps (+13%, up to +64%). Every Hit: every enemy a swing catches is a step. Saved Up: a step only on every third swing that lands, but +20% each, up to +100%. On Dodge: a dodge counts as a hit. A step is never worth more than +20% whatever the bands, so Momentum at its most doubles a swing.
- **Stagger** (passive): your swings fill a small meter under the enemy's health bar: a swing fills a quarter, a slam or a crushing blow a quarter and a half. Full, it breaks: the enemy takes a blow worth one more swing and is stunned for 1.5 seconds (stars turn over it), and the meter can't fill again until it wakes. Left alone for three seconds the meter empties. The meter is the enemy's own, so two hammers fill it together. What nothing can stun (the forge guardian) takes the blow and no more. Twice: fills twice as fast. Wider: the break also stuns everything within 80 px of it. Saved Up: fills a third as fast, for three times the blow and a 4.5 second stun. On Dodge: dodging past an enemy counts as a hit on it. Every Hit does nothing here, and the forge says so.
- **Aftershock** (passive; the bands are Darren's): 0.6 seconds after your finisher lands, hit or miss, the ground there rumbles: seven tenths of a swing to everything within 60 px and a short stun. A crack shows where it will be. Twice: a second rumble 0.35 seconds after the first. Wider: a bigger one (96 px). Every Hit: a small one (42 px) at half strength after every swing that lands. Saved Up: every third finisher a huge one (90 px), three times as strong. On Dodge: a dodge leaves one where you were.
- **Quake** (active, press, 5 seconds; the Bible's starter rune for the hammer): the ground erupts under the enemy you are aiming at, up to 240 px away: a swing and a half (28 from the iron maul) to it and everything within 44 px of it, and a 0.6 second stun. It picks whoever you point at before whoever is nearest; with nobody in range it erupts 120 px in front of you. Twice: then under the next enemy, 0.3 seconds later. Wider: a bigger patch (70 px). Saved Up: three times as strong, 15 seconds. On Dodge: a dodge sets one off at half strength.
- **Bulwark** (active, press, 10 seconds): a shield for 3 seconds. Nothing that comes from an enemy hurts you, and whoever hits the shield is stunned for 1.5 seconds and shoved back ("BLOCKED!"). Its button shows a bar running down while the shield is up and starts to recharge only when it drops. It also works with the arena's Invincible switch on, so it can be tried there. Putting the hammer away or being knocked out drops it. Twice: whoever hits it is stunned twice as long. Wider: 4 seconds. Saved Up: 9 seconds, and 30 to recharge. On Dodge: a dodge puts it up for a second.
- **Hook** (active, press, 4 seconds): the sword's old rune with its rules unchanged: chains fly from the hammer's head and pull every enemy within 260 px in to you, for three tenths of a swing and a half-second stun.
- **The bands on the active three** follow the sword's rules: Every Hit takes half a second off the recharge for each swing that lands (not while a Bulwark is up), and Saved Up is three times as strong and three times as slow.
- What a rune hits (a rumble, an eruption, a break) never crits and sets no other rune off.
- **Balance.** On one enemy Aftershock adds about a fifth to a chain (13 on top of 65), Stagger about a fifth and a 1.5 second stun every five swings or so, and Momentum up to two fifths for as long as you keep hitting. Bulwark with nothing on it is up for 3 seconds in every 13. This is the first pass.
- Where it lives: the entries in `FITTINGS` that carry `"weapon": "hammer"` and the constants under them in `scripts/weapon/swing_build.gd` (`MOMENTUM_*`, `STAGGER_*`, `AFTERSHOCK_*`, `QUAKE_*`, `BULWARK_*`); "The hammer's runes" section of `scripts/player.gd`; the meter itself in `scripts/enemy.gd` (`add_stagger()`, `stagger_break()`). Online, `net_state()` in `scripts/game_base.gd` compares every player's Momentum, rumbles and shield and every enemy's meter. The pictures are the art thread's (`art/swing/runes/`, `art/hud/`, `art/fx/`, numbers in `art/swing/hammer/hammer.json`); the stills the forge shows on Alt were taken from the game (Hook's was retaken with a hammer). `tests/hammer_runes.gd` checks every rune with every band.

### Both in the tutorial cave (version 27)

- **The crate offers all four.** The staff's and the hammer's plates hang beside the sword's and the bow's and can be taken and swapped like them. (Versions 22 to 26 had a fault here: the two plates were meant to stay locked and did not, and a run with either got stuck at the rune pedestal. `tests/cave_playthrough.gd -- hammer` found it.)
- **First runes.** The hammer's is **Quake** (the Game Bible's). The staff's was an open item: **Lance** is Claude's choice, the staff's rune for one big enemy (a starter rune must help against the guardian) and the one the staff on the title picture is using. Both are **active** runes, the first the cave hands out, so once the rune is fitted a card says "Square runes are active: an ability on a button" and which button (right mouse or RB), before the guardian wakes; the button then sits under your health bar like in the arena. The smith's lines know which kind of stone you carry ("Square stones like yours are active...").
- **The words fit the weapon.** Its card at the crate (the staff's explains mana), the first fight's hint ("the third swing is the slam", "the third cast is the burst"), the rune's card, the forge's hints ("the slot in the haft"), the smith's lines and the tin parts: a tin head and haft for the hammer; a tin head, shaft and crystal for the staff, whose crystal is its damage as arrows are a bow's. All of it is in `WORDS` at the top of `scripts/cave/cave.gd`, one entry a weapon.
- **How long the fights take** with the test's scripted players (three runs each, seconds): crawlers 11.8 with the hammer and 12.5 with the staff, burrowers 9.0 and 10.5, the nest 16.2 and 20.5, the guardian **19.6** and 23.0 (the same day's sword run: 12.8, 10.4, 17.8 and 23.9; the bow's: 13.4, 12.0, 17.5 and 23.5). So the guardian falls about a fifth sooner to the hammer than to anything else: its swings do 1.19 times the sword's damage a second and Quake comes on top. The scripted players are never afraid to stand next to it, which a person with a slow weapon will be, so this is a number to watch and not yet a reason to change one.

### The staff's runes (versions 25 and 26)

Three passive and three active. Overflow, Nova, Lance and Spectre are Darren's (11 November afternoon, in the Game Bible), and so are **Overflow's and Spectre's bands** ("Overflow bands" and "Spectre bands" there; version 25 had Claude's own for those two by mistake, version 26 put Darren's in). Orbit and Chain were only names. **What Orbit and Chain do, the bands of Orbit, Chain, Nova and Lance, and every number below is Claude's design**, for Darren to overturn. In the test arena the iron staff carries Nova, Lance and Spectre on its three buttons and Chain as its passive; Orbit and Overflow are in the forge's rune tab. The active three use their own recharge, not mana. Damage is a share of one bolt from the same staff (8.8 from the iron apprentice staff).

- **Overflow** (passive; Darren's, bands and all): a bolt cast while your mana is full is a quarter bigger and hits 30% harder (11.4 for 8.8), with a glowing halo round it, and a sign shows at the crystal while your mana is full, so you can see the next one will be one. Casting spends mana, so it is the first bolt after a rest. Twice: every other Overflow bolt is cast twice (the first, the third...), the second free of mana. Wider: an Overflow bolt bursts where it lands, 36 px wide, so it hits whoever stands beside its target too. Every Hit: each bolt that lands gives 3 mana back, so from full mana a whole chain that lands stays full (11.4, 11.4 and a 17.2 burst). Saved Up: no steady bonus; once your mana has stayed full for three seconds the crystal's sign grows and your next bolt is a huge blast, three times as strong (26.4) and bursting 64 px wide ("OVERFLOW BLAST!"). On Dodge: each dodge gives 10 mana back. The numbers (3 and 10 mana, three seconds, three times, the burst sizes) are Claude's.
- **Orbit** (passive; Claude's design): your finisher leaves an orb circling you. It waits up to eight seconds for an enemy to come within 62 px of you, then darts into the nearest one for a bolt's worth and a small shove. Three orbs at the most (a fourth takes the oldest one's place), and they strike one at a time, a quarter of a second apart. They go when you put the staff away or are knocked out. Twice: two orbs a finisher. Wider: they strike from further off. Every Hit: every bolt that hits leaves one, at half strength. Saved Up: every third finisher, three times as strong. On Dodge: a dodge leaves one too.
- **Chain** (passive; Claude's design): when your finisher's burst lands, lightning jumps from there to up to three more enemies, each within 150 px of the last, for half a bolt each (4.4). It does nothing against one enemy alone. Twice: six jumps. Wider: longer jumps. Every Hit: every bolt that hits forks, at half strength. Saved Up: every third finisher, three times as strong. On Dodge: a dodge sends it out from you.
- **Nova** (active, press, 6 seconds; "a ring burst for crowds"): a ring bursts out from your feet, 110 px to the sides and 68 up and down: 1.2 bolts (10.6) to everything inside, a 0.3 second stun and a hard shove outwards. Twice: a second ring 0.3 seconds later. Wider: a bigger ring. Saved Up: three times as strong, 18 seconds. On Dodge: a dodge sets one off where it began, at half strength.
- **Lance** (active, hold, 8 seconds; "the boss ability", and the staff's starter rune in the Bible): a beam into the first enemy on your aim, as far as the staff reaches, stopped by walls. It pulses four times a second and **builds the longer you hold**: three quarters of a bolt a pulse for the first second, twice that for the second, three times for the third ("LANCE x2!", "LANCE x3!", and the beam thickens). A full three-second hold is 158 damage from the iron staff, eighteen bolts' worth. You walk at half speed and keep aiming while it runs; a dodge or letting go ends it. Its button is a meter, like Whirlwind's: a full hold empties it and it refills in 8 seconds, and a hold started on a part-full meter runs out before the strongest pulses. Twice: a six-second hold with each step twice as long, so twice the damage. Wider: a thicker beam that is easier to keep on target. Saved Up: three times as strong, 24 seconds. On Dodge: a dodge fires one flash of it at full strength, halved (9.9).
- **Spectre** (active, press, 30 seconds; Darren's): a ghost of a player stands at their shoulder for 6 seconds and **copies their basic attacks at half strength**: a sword's or hammer's swing is swung again, an arrow or a bolt is loosed again along the same line in the ghost's pale colour, 0.15 seconds later. The copies cost no mana, crit as often as that player does and set off that player's passive runes at half strength (a copied finisher bolt forks a Chain, a copied sword hit throws Shards). They do not copy active runes. **Who gets it:** the teammate you are aiming at, within 320 px and about 20 degrees of your aim; with nobody there it comes to you. (Darren's line is "press it, then pick yourself or a teammate"; aiming is the simplest pick that needs no menu.) Its button shows a bar running down while the ghost is out, and the 30 seconds count from the press. It ends early if that player is knocked out or you put the staff away. The bands are Darren's. Twice: two ghosts, one at each shoulder, and each copies every attack. Wider: 9 seconds. Saved Up: whole copies, 90 seconds. On Dodge: the ghost dodges with its player and bursts where it stood, a bolt of your staff (8.8; two from a whole ghost) to everything within 56 px; if a teammate has your ghost, it is their dodge that sets it off.
- **The bands on the active three** follow the sword's rules: Every Hit takes half a second off the recharge for each bolt that lands (not for a Spectre that is out), and Saved Up is three times as strong and three times as slow.
- What a rune hits (an orb, a jump of lightning, a ring, the beam) never crits and sets no other rune off.
- **Balance, and what to look at.** The bare iron staff does 24.0 damage a second to one enemy and the iron broadsword 28.2 (0.85, "ranged must not beat melee"). **Lance** is where that bends: a full hold does 158 where three seconds of bolts do 72, and used every time it is back it brings the staff to about 32 a second on one enemy, a little past the bare broadsword, for standing nearly still. That seemed right for "the boss ability" (a bow's perfect far Snipe every time reaches about 33); `LANCE_DAMAGE` lowers it. **Overflow** as written is small: mana is only full until you cast, so it is one stronger bolt after each rest, and its bands are what make it worth a slot (Every Hit makes it a whole chain; Saved Up an opening blast worth three bolts after three quiet seconds). **Chain** adds 13 to a chain of 31 in a crowd and nothing against one enemy. **Orbit** adds a bolt a chain against whatever gets close. **Spectre** is out for 6 seconds in every 30, so it is worth about a tenth more damage from basic attacks for the player who has it, and most on a hammer. This is the first pass.
- Where it lives: the entries in `FITTINGS` that carry `"weapon": "staff"` and the constants under them in `scripts/weapon/swing_build.gd` (`ORBIT_*`, `CHAIN_*`, `OVERFLOW_*`, `NOVA_*`, `LANCE_*`, `SPECTRE_*`); "The staff's runes" section of `scripts/player.gd`; the halo and the ghost's colour on a bolt in `scripts/arrow.gd`. Online, `net_state()` in `scripts/game_base.gd` compares every player's orbs, Overflow count, Spectre, beam and lightning jumps. The pictures are the art thread's (`art/swing/runes/`, `art/hud/`, numbers in `art/swing/staff/staff.json`); the stills the forge shows on Alt were taken from the game. `tests/staff_runes.gd` checks every rune with every band.

## The lab (version 28, 15 November)

Darren, 15 November: "can we make a lab so I can adjust numbers myself without having to ask? Like sword damage etc", then "I want the test area lab to affect the whole game not just the arena ... also allow me to spawn any enemy to the arena I want so I can test", then "save the numbers and it passes them back to you so you auto adjust for future version".

**Opening it.** In the test arena press **L** (click the left stick on a controller) or click **LAB: CHANGE NUMBERS** at the top right. Anywhere, the tutorial cave included, it is also in the pause menu (Esc): **Lab: change numbers**. The game stops while it is open. L, Esc, B or CLOSE leaves.

**What is in it.** About 200 of the game's numbers on thirteen pages, each in plain words:

| Page | What it holds |
|---|---|
| All weapons | What one hit does in wood, tin and iron; the third hit of a chain against a normal one; how long a quick attack and a finisher take; crit chance and crit damage |
| Sword, Bow, Hammer, Staff | Each shape's damage, speed and reach (or range), walking speed while attacking, the bow's draw times and arrow speed, the hammer's slam size, the staff's mana and what each cast costs |
| Sword runes, Bow runes, Hammer runes, Staff runes | Every rune: its damage as a share of the weapon's hit, how far it reaches, how long it lasts or stuns, and its recharge |
| Bands | Twice's cap, Wider's sizes, Every Hit's strength and what it takes off a recharge |
| Players | Health, walking speed, the dodge's speed, length, count and refill |
| Enemies | How often the arena's enemies arrive and how many at once; health, speed and damage of the three crabs, the cave crawler and the cave burrower, and their warning times |
| Forge guardian | His health, what each extra player adds, his walking speed, each attack's damage and warning time, his rest between attacks |

- **Changing one.** Click **-** or **+** (hold it to keep going, hold Shift for steps five times as big), or click the number and type a new one (Enter takes it, Esc leaves the old one). A share is shown and typed as a percentage: 80% is four fifths. A changed number turns amber, the row shows the game's own number beside it ("GAME: 11") and a **RESET** button; its page's button counts the changes on it.
- **Where it is in force.** At once and everywhere: the arena and the cave, for both players on a shared screen. Weapons in the hand are worked out again when the lab closes, and everyone alive, enemies included, takes their new health (keeping the same share of it). Every number has limits, so a typed mistake can't break the game.
- **Where it is kept.** In a small file on that computer (`lab.json` in the game's own data folder), so the changes are still there the next time the game starts. While any number is changed, the bottom-left corner of every screen says so beside the version: "LAB: 3 NUMBERS CHANGED". **RESET THIS PAGE** and **RESET EVERYTHING** put the game's own numbers back.
- **Passing them back.** **COPY MY CHANGES** puts every change on the clipboard as plain lines, each with the exact number in brackets, for example `Sword > Dagger > Damage: 60% -> 70%  [build:SHAPES/dagger/damage = 0.7]`. Paste that to Claude and those become the game's own numbers in the next version (the lab then shows them as unchanged).
- **Online** the lab is not there and its numbers are switched off: both computers play with the game's own numbers, because two computers with different numbers would drift apart. They come back when you leave the online game.
- **What does not follow.** Words in the forge that spell a number out ("at half strength", "three times as strong", a part's "+8% crit chance") are fixed text. The forge's numbers plate, a rune's recharge and time in its sentence, and everything in the fight itself do follow. Saved Up's "three times, every third" is not in the lab: too many rules lean on it.

**The Spawn page** (test arena only) puts any enemy in the game into the room, near you: the three crabs, the cave crawler, the cave burrower, the forge guardian and more training dummies, one at a time or five at a time. The guardian is awake at once, keeps to the arena, shows a small health bar once he is hurt, and his empty suit is cleared away a few seconds after you beat him. **REMOVE EVERY ENEMY** empties the room (the dummy it started with stays), and a switch stops or starts enemies arriving by themselves. Pause enemies (P) and Invincible (H) work on everything you spawn.

**How it is built.** `scripts/lab.gd` is the list: each row says which page and group a number is on, what it is called, where it lives in the code, and its step and limits. The numbers themselves are still in the code where they always were (`scripts/weapon/swing_build.gd`, `scripts/player.gd`, `scripts/enemy.gd`, the cave's enemies), now as `static var` in place of `const` so they can be written to while the game runs. To put another number in the lab: make it a `static var`, add one `_add(...)` line, and `tests/lab.gd` checks it. Only the game's front door (`scripts/boot.gd`) reads the lab file, so the tests, which load a scene directly, always run on the game's own numbers. The screen is `scripts/ui/lab_screen.gd`; the spawner is `spawn_enemies` in `scripts/main.gd`.

Which keys open it, which numbers are in it, their steps and limits, and the spawner's details are Claude's choices, for Darren to change.

## This branch: the swing path

This branch tests the **swing path** (design notes, 3 November). It replaces the part grid; `main` still has the grid sword to compare against.

- A sword is a **blade** plus a **grip**. The blade sets the basic three-hit chain (the last hit is the finisher). Grip and blade both have **slots**.
- Slots hold **runes** (effects) or **bands** (modifiers). Read the sword as one line from the bottom of the grip to the tip: a band boosts the next rune above it, bands in a row stack, and a band with nothing above it does nothing.
- Runes are **passive** or **active** (Darren, 10 November). The sword has three of each (11 November), and so has the bow (version 20, see "The bow's runes" above).
  - Passive runes fire by themselves: **Shockwave** (finisher: a rolling wave, a light hit that shoves enemies back), **Shards** (every hit sends metal shards jumping to the closest enemy, then the next), **Weak Point** (the finisher marks the enemy it hit, and the next sword hit on the mark is a big crit).
  - Active runes wait for a button: **Whirlwind** (hold: you spin, cutting everything around you once a turn, walking at three quarters speed) and **Leap** (press: you jump to an enemy and land at your blade's reach from it, with a strike).
  - **Hook left the sword for the hammer** (Darren, 11 November afternoon). Since version 24 it is one of the hammer's three active runes (`"weapon": "hammer"` in `FITTINGS`), so the forge offers it to a hammer and to no sword; `tests/active_runes.gd` still puts it on a sword by hand, because its band rules were first checked there.
  - **Ghostwield** (Darren, 11 November afternoon; version 13) is the third active rune: press its button (R, or B on a controller) and a see-through copy of your own sword appears in your other hand for 15 seconds. Every swing you make is copied 0.15 seconds later from the other side at half strength, and the copy's hits set your passive runes off again as ghosted effects: the same effect at half strength, drawn in the ghost's blue-violet (a second Shockwave, more Shards). It recharges in 45 seconds, counted from the press; the button shows a bar running down while the ghost is out, and the ghost sword blinks through its last two seconds.
    - Bands, as the Game Bible lists them: **Twice** is two copies of each swing; **Wider** keeps it for 20 seconds; **Every Hit** is the recharge rule below; **Saved Up** makes the copies full strength and the recharge three times as long (135 seconds); **On Dodge** makes the ghost cut along every dodge, through whatever you pass, for half a hit (it doesn't have to be out).
    - My own choices, to change if they feel wrong: only your ordinary swings are copied (not Whirlwind's turns or Leap's strike); a copy shoves and stuns half as hard, can crit, and never spends a Weak Point mark (the mark waits for your own sword); the copies don't count as your hits for Every Hit, and Every Hit gives nothing back to Ghostwield while its ghost is still out; a ghosted Weak Point only marks when you have a mark to spare; a Saved Up passive is copied only on the swing that set it off; two Ghostwield runes are one ghost, the second counting like a Twice.
    - Where it lives: `ghostwield` in `FITTINGS` and `GHOST_POWER`, `ghost_time()` in `scripts/weapon/swing_build.gd`; the "Ghostwield" section of `scripts/player.gd` (`GHOST_DELAY`, `GHOST_GAP`, `GHOST_SHOVE`, `_summon_ghost`, `_ghost_swing`, `_ghost_dodge_cut`). The ghost sword is your sword's own picture run through `shaders/ghost.gdshader`; its smears, sparks and ghosted rune effects are the real pictures recoloured by `shaders/ghost_glow.gdshader`, so nothing new had to be drawn for them.
- Bands: **Twice** (the rune happens twice, a beat apart), **Wider** (bigger), **Every Hit** (a passive rune fires on every hit instead, at half strength; an active rune comes back sooner with every swing you land), **Saved Up** (every third time, three times as strong) and **On Dodge** (also when you dodge).
- **Active runes, in full.** There are three ability buttons: right click, Q and R, or RB, LB and B (the third button's keys are a first guess, to settle in testing). The first active rune on the sword, reading from the bottom of the grip, takes the first button, the next takes the second and the next the third, so the order on the sword picks the buttons. Two of the same rune share a button and go off together. Each button has a meter, drawn under the health bar with the rune's picture and its button: it fills from the bottom as the rune recharges and gets a bright edge when it can be used.
  - Whirlwind's full meter is three turns. Each turn spends a third; a tap is one turn, holding keeps turning until the meter is empty or you let go. It refills in 5 seconds, starting a moment after you stop. A dodge cuts a spin short, and the sword can't swing during one.
  - Leap needs a full meter and is back in 3 seconds. It goes for the nearest enemy near where you aim (or else the nearest one) within about 260 pixels, and lands you so that enemy sits just inside your blade's reach: a long blade lands further out than a short one. If you are already closer than that, it hops you back out. As you land the sword cuts once in front of you (one blade hit and a short stun). With nobody in range it jumps a short way where you aim. You can't be hit during the jump. Before 11 November Leap was passive (an attack straight after a dodge) and landed on top of the enemy, which got you hit every time.
  - Bands on an active rune: **Twice** gives Whirlwind twice the turns and makes Leap go on to a second enemy; **Wider** is a bigger reach or circle; **Saved Up** makes it three times as strong and three times as slow to recharge; **On Dodge** makes a dodge do it too (one turn or one leap) without touching the meter; **Every Hit** leaves it on its button, and every swing of yours that lands takes half a second off its recharge (Darren, 11 November afternoon; before that it turned the rune passive at half strength). A swing counts once however many enemies it catches, which is my reading of "each basic hit you land"; only your own swings count, not runes; a second Every Hit adds nothing; the button's meter blinks green when it happens. The half second is `EVERY_HIT_REFUND` in `scripts/weapon/swing_build.gd`.
  - The numbers are at the top of the rune's entry in `FITTINGS` (`scripts/weapon/swing_build.gd`: `recharge`, `turns`, `turn`) and in `scripts/player.gd` (`HOLD_MOVE`, `HOOK_STUN`, `SHOCKWAVE_DAMAGE`, `LEAP_RANGE`, `LEAP_DAMAGE` and their neighbours). To make another rune active, give it `"trigger": "active"` and a `"use"`; a fourth kind of active rune on one sword does nothing, because there are three buttons (Every Hit used to be the way round that; it no longer is).
- **Weak Point, in full.** The finisher marks the nearest enemy it hit. One mark at a time: marking another enemy takes the first mark away, and a mark fades after 8 seconds. The next sword swing that hits the mark is a crit worth 2.5 ordinary hits (a pommel's crit damage adds to it), with its own burst and "WEAK POINT!". Only sword swings count, not runes, and in two-player either player's swing can strike it.
  - A small enemy glows icy white all over, and any swing that hits it counts.
  - A big enemy (the brute, the guardian) gets a bright spot on one side of its body instead, never on the side you marked it from. The swing has to reach the spot, and you have to be standing on the spot's side of the enemy (within 50 degrees round), so you step round to it.
  - Bands: **Twice** is two marks at a time (two small enemies, or two spots on a big one); **Wider** is a bigger spot that you can reach from further round; **Every Hit** marks on every hit, with a smaller crit (1.75 hits), and the hit that strikes a mark doesn't put a new one on; **Saved Up** marks on every third finisher with a huge crit (5.5 hits); **On Dodge** marks the enemy your dodge passes closest to.
  - The numbers: `WEAK_CRIT` and `WEAK_DODGE_REACH` in `scripts/player.gd`, `WEAK_BIG`, `WEAK_LIFE`, `WEAK_SPOT` and `WEAK_SIDE` in `scripts/enemy.gd`.
- Second Wind is gone (11 November).
- Rule-benders (the "rare" tab, one per sword): **Relay** hands the bands on the rune below on to the next rune above too. Mirror is parked (it overlapped Twice).
- New parts without art yet show as plain coloured stones, rings and gems.
- Effects are deliberately loud: each rune has its own visual, sound and name pop-up, the slots flash on the sword and in the HUD when they fire, and a finisher that connects gets a screen shake. Identical runes firing together merge into one bigger effect.
- **Test swords (test arena):** you start with Test sword D (Whirlwind, Leap, Ghostwield, Weak Point: the sword's three active runes, one on each button, and a passive). The forge also has Test sword A (Twice, Shockwave, Wider, Leap: two shockwaves and a leap from further away), Test sword B (Shockwave, Twice, Wider, Leap: one shockwave and a long leap that goes on to a second enemy) and Test sword C (Whirlwind, Leap, Twice, Shockwave). Leap stands where Hook did before Hook left for the hammer. Keys 1, 2, 3 and 4 at the forge load A, B, C and D.
- **Pause enemies:** the button at the top right, or P / Start.
- **Blade shapes (11 November).** Every sword blade is one of six shapes. The shape sets the three-hit chain and how the sword feels; the metal sets the damage. The numbers are multiples of the broadsword's (iron broadsword = 11 damage):

  | Shape | Chain | Damage | Speed | Reach | Arc | Its lean |
  |---|---|---|---|---|---|---|
  | Dagger | stab, slash, stab | 0.6 (6.6) | 1.6 | 0.6 | 60, stabs are a line | You walk at full speed while attacking. A stab hits one enemy |
  | Sabre | slash, backslash, wide sweep | 0.85 (9.4) | 1.25 | 0.9 | 160 | +10% crit chance |
  | Broadsword | slash, slash, overhead | 1 (11) | 1 | 1 | 120 | None: the balanced one. Wooden and tin blades are this shape |
  | Rapier | thrust, thrust, lunge | 0.9 (9.9) | 1.1 | 1.4 | a straight line | Every thrust goes through to a second enemy. The lunge reaches a quarter further |
  | Falchion | chop, chop, cleave | 1.35 (14.9) | 0.8 | 0.9 | 110 | Big knockback; the cleave staggers (0.8 s) |
  | Greatsword | sweep, backswing, slam | 1.6 (17.6) | 0.65 | 1.5 | 180 | You walk at 70% speed while swinging |

  - Balance (the Game Bible's approach): a shape is a way of playing, not more power. Every chain is 1 + 1 + 1.5 hits and takes the same time at speed 1, and the pause when a finisher lands is shorter on a fast blade, so a shape's damage a second is exactly its damage times its speed: 0.96 to 1.08 of the broadsword's. `tests/blade_shapes.gd` measures it in the arena. (The sabre's extra crit chance is on top of that: about 1.12 with crits counted.)
  - Every iron shape has two slots: slots come from a blade's tier, never from its shape. Grips with more slots no longer swing slower (slots never make a part weaker).
  - Reach multiplies the whole hit distance (the broadsword hits out to 91 px), so Leap lands further out with a rapier than with a dagger, and Whirlwind is as big as the blade.
  - An arc hits an enemy if it touches its body, not only its middle.
  - The broadsword's finisher is 1.5 hits (it was 2.1). The tutorial's burrower (17 health) and guardian (255) were lowered to match, so those fights are as long as they were.
  - The rapier's lunge reaches further instead of moving you, because attacks never carry you into the enemy.
  - The numbers: `SHAPES`, `METALS` and `BLADES` in `scripts/weapon/swing_build.gd`; the moves (`MOVES`) and `BASE_REACH` in `scripts/player.gd`.
- Other parts: wooden / wrapped / long grips (1, 2, 3 slots), and pommels (no slots, stats only: Plain, Keen +8% crit chance, Heavy +40% crit damage, Light +10% swing speed). The Ringed Grip is a special grip whose built-in band makes every rune a bit bigger; the Gilded Grip's ruby top slot doubles whatever is in it (a rune fires twice, a band counts as two).
- The forge screen (laid out again for the 11 November decisions, so that nothing on it overlaps): at the top left a BACK button, the way out (it says the key that does the same: Esc, or B on a controller), then the screen's name; on the left the parts tray, with the runes in a PASSIVE group (round stones) and an ACTIVE group (square stones with a small button badge); under it a plate with the name and one plain sentence for the part under the cursor; under that how to use the screen. In the middle the sword over the anvil. On the right "what it does", a line per rune, which closes up its rows when a sword has a lot to say; and under it the sword's numbers on a plate of their own (damage, speed, reach, crit, crit hits, slots, walking while swinging). Pointing at a part you could fit shows what it would change beside each number. Holding Alt on a rune shows a still picture of it firing (`art/swing/previews/<rune>.png`, 352 x 240, taken from the game). `tests/smoke_forge.gd` checks that every sentence, every sword's "what it does" and every number with its change fit their plates.
- **Loadout presets** (Game Bible, 11 November): each player has three saved swords, A, B and C, and can name them (and, since version 19, three saved bows of their own: the forge shows the presets of the weapon on the anvil). The chosen preset is always the sword in the hand, so every change at the forge is saved to it; clicking another one swaps the whole sword (blade, grip, pommel, runes and bands) in one go, and only at the forge. A preset that has never been used starts as a copy of the sword you are holding. Pointing at a preset shows the sword it holds as pictures; a part you no longer own is greyed out under a padlock and is left off when you switch to it. They live in `scripts/weapon/swing_build.gd` (`preset`, `preset_data`, `preset_names`, `use_preset()`). Not built, because the prototype has nothing to hang them on: the warning when you break down or sell a part that is in a preset (there is no breaking down or selling yet), keeping presets after you close the game (nothing is saved between sessions yet), and typing a name with a controller. Online, presets are each player's own notes: switching sends the new sword to the other computer like any other change at the forge. **T** or the button puts you next to the dummy. The forge glows: the hearth breathes behind the sword, embers drift up, every change is a hammer blow with sparks and a clang, and leaving after changes plays a short "Forged!" finish (white-hot, quench steam, a shine up the blade). Press Tab or click to skip it.
- Art and numbers for all of this are in `art/swing/` (`swing_path.md` explains how the sword is assembled; `swing_path.json` has every slot, pivot and effect strip). Fonts are Silkscreen and Pixelify Sans (OFL), in `art/fonts/`.
- Elemental blades are parked for now. Sounds are placeholders made in code (`scripts/sfx.gd`). The tutorial cave's music is the exception: real tracks in `art/music/`.

Code map:

```
scenes/boot.tscn, scripts/boot.gd    Intro screen, then the mode you pick
scripts/ui/title.gd                  The intro screen: the moving picture (art/title/title.json), the buttons, who is playing
scripts/ui/online_menu.gd            The "Play online" screen: host, join, start
scripts/net/session.gd               Online play: connecting, sending controls, keeping both games in step
scripts/net/net.gd                   Where game code asks "are we online, and which player am I?"
scripts/net/port_opener.gd           Asks the home router to let the other player in
tools/make_exe.gd                    Packs the game into one Windows .exe to send to a friend
scripts/sim.gd                       Random numbers for anything that decides what happens (the same on both computers)
scripts/game_base.gd                 What both modes share: players, swords, camera, HUD, forge
scripts/cave/cave.gd                 The tutorial cave: map, rooms, stages
scripts/cave/crawler.gd, burrower.gd, guardian.gd   The cave's enemies and boss
scripts/cave/hazard.gd               Timed danger areas: the knight's slam and charge, falling rocks
scripts/fx/warn.gd                   Draws the warning lanes and circles on the floor from the art
scripts/cave/cave_ui.gd              Objective, prompts, boss bar, speech box, cards, the opening cutscene
scripts/main.gd                      The test arena, and the lab's enemy spawner
scripts/lab.gd                       The lab: which of the game's numbers can be changed while it runs, and the file that keeps the changes
scripts/ui/lab_screen.gd             The lab's screen: pages of numbers, and the arena's Spawn page
scripts/player.gd                    Movement, dodge, the swing chain, runes
scripts/player_input.gd              One player's controls (any device, keyboard, or one controller)
scripts/camera_rig.gd                The shared camera
scripts/enemy.gd                     Enemy base: being hit, knockback, the arena's enemies
scripts/weapon/swing_build.gd        Blades, grips, fittings and the reading rule
scripts/weapon/sword_art.gd          Draws the sword with its slots
scripts/ui/swing_forge.gd            The forge screen
scripts/fx/rune_fx.gd                Rune visuals
scripts/ui/hud.gd, pause_menu.gd     Health, dodge pips and swing path chips; the pause menu
scripts/glow.gd                      The glowing pixels of a sprite, kept bright in the dark
art/                                 All art, loaded at runtime (art/v3_notes.md explains the set)
art/cave/cave.json                   The cave art's numbers: sizes, feet, lights, layout
art/swing/swing_path.json            The sword, effect and menu art's numbers and colours
art/gaps.json                        The later pieces' numbers (10 Nov evening): frame size, frames, speed, anchor
art/cutscene/intro/                  The opening cutscene: 278 pictures, player two's patches in p2/, numbers in intro.json
```

## The look (10 November: "Verdigris & Ember")

All sprites, effects, menus and the HUD use the art thread's v3 set. Three rules the code follows:

- **Sprites are painted unlit.** The mood comes from a dark tint over the world (`CanvasModulate`) plus the stepped, hatched lights in `art/lights/`. Use them through `Art.stepped_light(radius)` at `texture_scale = Art.PIXEL` and nothing else, or the hatching blurs.
- **Glow layers.** A sprite with glowing pixels has a `<name>_glow.png` beside it. `scripts/glow.gd` draws it on top with an unshaded material, so embers, eyes and runes stay bright in the dark. Props (`strip_sprite.gd`), enemies (`enemy.gd`) and one-shot effects (`sprite_once.gd`) pick the glow file up by name.
- **Verdigris is idle, ember is live.** Menu plates are dark plum with a bronze-green edge; whatever is selected, lit or speaking turns ember. Menu pieces are nine-patches drawn with `Art.draw_nine`.

Readability tweaks made on top of the art's own lighting numbers: the cave's dark tint is 15% brighter (`AMBIENT_LIFT` in cave.gd), each player carries a small cool light, crawlers and burrowers carry a lit rim in their glow layer (and `lift` in enemy.gd can draw any enemy brighter than the floor if one ever sinks into it), and warnings and damage numbers ignore the lighting.

**Later pieces (10 November evening).** The art thread drew what the prototype was still drawing in code. Their numbers are in `art/gaps.json`, and the code reaches them by name: `Art.piece(name)`, `Art.draw_piece(...)` to draw a frame, and `Art.play_piece(...)` to play one once (pieces whose note says ADDITIVE are added on the bright layer above the lighting). What uses them:

- The swing smear, hit sparks, the burst when an enemy dies, when a player is hurt and when one is given something.
- Warnings on the floor (`scripts/fx/warn.gd`): a lane that reads "aim" while it follows you and "lock" once it can't turn, circles that fill up, a ring round a crab about to bite. They draw at z -5, under everyone and above the floor, so each mode's floor sits at z -10.
- Stars over a stunned enemy and a small health bar; both sit above the top of the enemy's picture, whatever its size.
- A knocked-out pose for the crew, soft shadows, the player rings, a lit rim on the crew.
- The cave: a falling rock, the cage breaking, the smith walking, the rune leaving its pedestal, pictures on the first and last cards, plates behind prompts and hints, and pictures of keys and buttons in hints (write `[space]`, `[mouse_left]`, `[pad_a]`, `[stick_l]` in the text).
- The forge: tray pictures for blades and grips, stat icons that light for a moment when a number changes, tabs, a padlock. The arena floor is one painted picture.

Drawn but not used yet, because the game has nothing for them to show: the blank rune stone and the broken band.

The 11 November pictures (asked for in the project files, `art/requests/nov11-prototype-art.md`, and drawn by the art thread the same day): the six blade shapes in the hand, on the forge screen and as tray cards, with their forge heat and shine strips; the swing smears (`art/swing/fx/sweep_smear.png`, `flick_smear.png`, `chop_smear.png`, `thrust_smear.png`, `slam_burst.png`); the Weak Point stone and its three effects (`art/fx/weak_mark.png`, `weak_mark_on.png`, `weak_break.png`); square stones for the three active runes with `art/swing/ui/active_badge.png`; the PASSIVE and ACTIVE tray headers; and the R, Q, RB and LB prompts. Sabre and falchion have one cutting edge, on the left of the picture: in the hand the picture is mirrored so the edge leads the cut.

The stat icons for slots and for walking while swinging (`art/swing/ui/stat_slots.png`, `stat_move.png` and their `_hot` versions) are the art thread's too. The six rune preview pictures are screenshots of the game, so they need retaking if a rune's effect is redrawn.

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
