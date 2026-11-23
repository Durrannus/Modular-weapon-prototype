# Modular Weapon Prototype

A Godot prototype for a co-op top-down game about building weapons from parts.

**The newest game is on the branch called `latest`.** (Until version 29 it was called `swing-path`. That name came from the first thing built on it, the swing path, and stopped fitting once the whole game lived there, so on 15 November it moved. `swing-path` stays where version 29 left it and gets no new versions.) If your copy is still on `swing-path`, switch it once: in GitHub Desktop choose **Current branch > latest**; on the command line `git fetch` then `git checkout latest`. After that, pull as before.

This branch has four things to try:

- **The tutorial cave** (Game Plan milestone 4): four rooms, from a shipwreck crate to a forge guardian, for one or two players. You choose your weapon at the crate: a sword or a bow since version 21, a hammer or a staff too since version 27. Since version 34 you can click the one you want, and each weapon goes to one player.
- **Two players on one screen.**
- **Two players online**, one on each computer (see "Playing online" below).
- **The test arena**: the sandbox for trying weapons out, with every sword part unlocked. You can't be hurt there unless you switch that off, and you can stop the enemies where they stand (see "Controls").
- **The bow** (versions 18 to 21, Game Bible milestone 6). In the test arena press **B** (or click the right stick) to swap your sword for an iron shortbow and back, and open the forge with the bow in your hand to change its limbs, grip, string and arrows and to fit its own six runes (Pierce, Ricochet, Steady Aim, Volley, Snipe, Arrow Rain). In the tutorial cave take the wooden bow from the crate and play the whole cave with it. See "The bow" below.
- **The hammer and the staff** (version 22 on, Game Bible milestone 7). In the test arena **B** now goes round four weapons: sword, bow, an iron maul and an iron staff, and since version 23 the forge changes the one in your hand: another head, haft or shaft, counterweight or cap, crystal, bands, and three presets of its own. Since version 24 the hammer has its six runes (Momentum, Stagger, Aftershock, Quake, Bulwark, Hook) and since version 25 the staff has its own (Orbit, Chain, Overflow, Nova, Lance, Spectre); since version 27 the tutorial cave's crate hands both out, and you can play the whole cave with either. See "The hammer and the staff" below.
- **The lab** (version 28). Press **L** in the test arena, or choose **Lab: change numbers** in the pause menu anywhere: about 200 of the game's numbers (damage, speeds, recharges, health, the boss) can be changed while the game runs, are in force at once in the arena and the cave, and are kept on your computer. Its **Spawn** page puts any enemy in the game into the arena, the forge guardian included, and **Copy my changes** hands your numbers back so they can become the game's own. Since version 29 it has a **search box**: type "dagger", "recharge" or "health" and every number with that word shows, from all the pages. See "The lab" below.
- **Slim runes and bands** (version 30). The bronze boxes round the sockets are gone: runes are small gems in their own colour, bands are thin rings, and the weapon runs unbroken underneath. See "Slim runes and bands" below.
- **The forge spirit** (version 31). Runes are no longer drawn on the weapon at all. A small ember, the forge spirit, floats at each player's shoulder and holds them: a mark over it for each rune on a button, and the rune's sign leaps from the spirit to the weapon when you use it. The forge screen is now the spirit with a ring of seats round it, one seat for each socket your parts give. Bands are called **threads** and slots **seats**. See "The forge spirit" below.
- **The cave's first runes** (version 32). In the tutorial cave the sword's first rune is now **Whirlwind** (it was Shockwave) and the bow's is **Volley** (it was Steady Aim), as the Game Bible decided on 17 November; the hammer keeps Quake and the staff Lance. All four are active runes, abilities on a button, so every weapon now gets the card that says which button before the guardian wakes. Shockwave and Steady Aim are still in the game, at the forge in the test arena.
- **The Greystone Highlands: the land, the basic tools and saving** (versions 35 to 42, the first steps of Game Bible milestone 8). Climb the stairs at the end of the tutorial cave and you walk out of a cave mouth onto a new land, with the weapon you built. It is different every time: the map is made from a number (the "world number" on the card you arrive to), and the same number always makes the same map. Most of it is rock, with small open places joined by gaps, footpaths and old dug tunnels. This version has the base clearing outside the cave and the inner ring round it, which since version 39 reaches about 125 tiles from the cave (Darren played the land on 22 November, found it "quite small", and chose a bigger Highlands: about 350 tiles from the cave to the edge once all three rings are built). Since version 40 you carry a pickaxe, an axe and a mallet: **F** uses the one you have picked and **C** picks the next (the left trigger and Select on a controller), so you can dig into the rock, mine the tin and copper that run through it as veins, and fell pines; what you win goes in a materials bag. Version 41 makes every blow land like one (cracks, chips, a spark, a sound, a burst) and lifts the copper veins as much as the tin. **Since version 42 it is all saved**, the way Terraria does it: each player is a saved character that keeps its weapons, tools and bag and can go into any world, and each world keeps what was dug and felled in it. **Highlands** on the title screen asks who is playing which character and in which world (or makes new ones), and the game saves by itself from then on; there is no save button. There is nothing to fight yet: that is a later version, one at a time. See "The Greystone Highlands (versions 35 to 42)" below.
- **Darren's 21 November playtest list** (version 34). Darren played version 33 and sent a list; this is all of it. The bow is slower and lighter, the hammer is a slow two-handed weapon that hits very hard, the staff's bolts are free and its runes run on mana, Quake is a crack along your aim, abilities only start on a full meter, the crate's weapons can be clicked and each goes to one player, the forge lists what each thread adds to a rune, the game has a new font, and the ability effects are redrawn in the game's own metals. **This list changes many numbers in the older sections below: where they disagree, "Version 34" is right.** See "Version 34: the 21 November playtest list" below.
- **The 19 November combat rules** (version 33). **Hook** throws one chain at one enemy, the one you aim at, and drags it to you; a boss is too heavy, so the chain pulls you a little way to it instead. **Bulwark** only blocks: it takes three hits, and when enemies break it, it bursts and stuns everyone near you (it no longer stuns whoever hits it). **Shards** burst out of the back of the enemy you hit, in a cone, and fly straight into whoever stands behind it (they used to jump to the closest enemy). The **"toughest enemy" rule** (most health left, an elite always first) is in the game too, ready for the runes that will use it. See "The 19 November combat rules" below.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

The game opens on the intro screen: a picture of the game at its best moment, alive with small movement (four players on the forge guardian at once, each with a different weapon and ability), with the buttons that start a game. For now those are **Tutorial**, **Arena**, **Highlands** (since version 35), **Play online** and **Quit**. "New game" and "Continue" will go on top of them later; the column already keeps the room.

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
| Dodge | Space or Shift | A or left trigger (in the Highlands: A only) |
| First active rune (hold for Whirlwind or Lance; hold and let go for Snipe, on whichever button it is). An ability only starts when its button is full (version 34) | Right click | RB |
| Second active rune | Q | LB |
| Third active rune | R | B |
| Use (crate, rune, forge, talk) | E or F (in the Highlands: E only; at the open crate you can also click the weapon you want) | A or Y, when the prompt shows |
| The Highlands: use the tool you have picked, on what you aim at (hold to keep working) | F | Left trigger |
| The Highlands: pick the next tool (pickaxe, axe, mallet) | C, or the mouse wheel either way | Select |
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

**At the forge** (the game pauses): drag a part onto a slot, or click a slot and then a part. Right-click or drag off to remove. Keys or controller: up and down pick a slot, left and right pick a part, Q/E or the shoulder buttons change tab, Enter or A fits it. **To leave, click BACK at the top left, or press Esc (B on a controller); Tab or Y works too.** Point at a rune and hold Alt (the left trigger on a controller) to see a picture of it firing. Since version 34 pointing at a rune on the ring also lists the threads that reach it, one line each with what it adds. Point at a blade, grip or pommel you could fit and the numbers show what it would change: gains in green with a plus, losses in red with a minus. **Presets:** A, B and C at the top right are three saved swords. Click one (or press C, or Select on a controller) and the whole sword changes to it; click the name beside them to type a name of your own.

## The tutorial cave

It follows the "Tutorial opening" in the Game Plan. You shelter from a storm in a sea cave, the entrance collapses, and the only way out is up.

It opens with a 23 second cutscene: the ship in the storm, the wreck on the rocks, and the cave mouth coming down behind the crew. With two players both are on deck. Press attack or use once and "Press again to skip" appears; press again to skip it. Online, either player's skip skips it for both. The pictures and their numbers (speed, captions, when each sound comes) are in `art/cutscene/intro/`, and `cutscene()` in `scripts/cave/cave_ui.gd` plays them. The wind, thunder and crash are placeholder sounds made in code, like the rest.

The cave has music (version 11). A calm loop starts when the cutscene ends, fight music takes over when the forge guardian wakes (and stays through a knock-out and restart), and the calm loop comes back when the guardian falls. `scripts/music.gd` plays the tracks and fades one into the other; the two Ogg files and the scripts that made them are in `art/music/`, and how loud each sits is `VOLUME` in `scripts/music.gd`. Music is each screen's own, so it never touches the game state and is safe online.

1. **The wreck.** Search the ship's crate, choose a wooden staff, sword, bow or hammer from the four plates that rise over it (click one, or stand under it and press Use; since version 34 each weapon goes to one player), then fight a few crawlers. They rear up before they bite, and a hit while they rear up stops the bite. Once the room is clear you can go back to the crate and swap, until the next fight starts.
2. **The burrows.** Burrowers travel underground, come up, flash red and lunge in a straight line. Dodge aside and hit them while they lie stunned.
3. **The nest.** A mixed fight. Clearing it lets you take your first rune (Whirlwind for a sword, Volley for a bow, Quake for a hammer, Lance for a staff; until version 32 the sword's was Shockwave and the bow's Steady Aim), which your weapon can't use yet.
4. **The forge.** The forge is a colossal sword set in the north wall, with a knight kneeling asleep in front of it. Fit the rune to your weapon there and the forge lights, molten metal runs down the floor channels, and the guardian wakes. (Every weapon's first rune is an active rune, an ability on a button, so a card first says which button, right mouse or RB, and whether to press it or hold it. Until version 32 only the hammer and the staff had one.) It has four attacks, each marked on the floor in red before it lands, and a line under its health bar names the attack and says what to do. **Slam**: a circle fills, then the hammer comes down. **Charge**: a lane shows the path, and a charge that hits a wall stuns it. **Quake**: cracks run out from it like the spokes of a wheel, so stand between them. **Rockfall**: rocks drop one after another where you stand, so keep moving, and hit it while it stands still. The first four attacks are one of each, and it never does the same one twice running. Below half health it slams three times in a row, a second ring of cracks fills the gaps of the first, and more rocks fall. The timings are at the top of `scripts/cave/guardian.gd` (`SLAM_WINDUP`, `REST` and so on). Beat it and the old smith is freed: he explains runes (round ones work by themselves, square ones are active and give you an ability on a button once slotted into the weapon) and bands, and hands over your weapon's tin parts (a blade and a grip; limbs, a grip and arrows; a head and a haft; a head, a shaft and a crystal). Forge the tin weapon and the stairs to the surface open.

Rules:

- After each room everyone is healed and anyone knocked out gets back up. There are no revives mid-fight.
- If everyone is knocked out, that room (or the boss) starts over.
- With two players there are more enemies, the guardian has more health, its rockfall is longer, and it also brings rocks down after each charge.
- The crate offers all four wooden starters (Game Bible): the sword and the bow since version 21, the staff and the hammer since version 27. **Since version 34 every player takes a different weapon** (Darren, 21 November): a weapon somebody holds can't be taken by anyone else until they swap it back. Each player gets their own weapon's rune and tin parts, and the smith's words and the hints fit whoever is there.

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
godot --headless --path . --fixed-fps 60 -s tests/active_runes.gd              # Whirlwind, Leap and Ghostwield on their buttons (and Hook, the hammer's now, put on a sword by hand), the bands on them, that a held rune only starts on a full meter, and Weak Point
godot --headless --path . --fixed-fps 60 -s tests/blade_shapes.gd              # the six blade shapes: reach, what each move hits, each lean, damage a second
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd          # plays the whole cave with a sword
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- bow   # with a bow ("swap": takes the sword, swaps it for the bow after room 1)
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 bow    # two players, a bow and a sword ("bows": two bows)
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 wipe down
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- hammer           # with a hammer, or "staff"; "players=2 hammer staff": one of each ("hammers", "staffs": two the same; "swap=staff": takes the sword, swaps it for the staff). The bots must use their first rune's button on the guardian, whatever the weapon (Whirlwind, Volley, Quake, Lance)
godot --headless --path . --fixed-fps 60 -s tests/cave_words.gd                # the cave's words for each of the four weapons and every pair of them: cards, hints, the smith's lines; each names the right weapon and rune and fits its plate ("-- show" prints them all)
godot --path . -s tests/smoke_forge.gd                                         # opens the forge, fires every rune; every word fits its plate; BACK leaves; the bow, the hammer and the staff on the anvil
godot --headless --path . --fixed-fps 60 -s tests/title_screen.gd              # the intro screen: its picture, its buttons, joining and choosing
godot --headless --path . --fixed-fps 60 -s tests/arena_switches.gd            # the arena's two switches: Invincible, and Pause enemies
godot --headless --path . --fixed-fps 60 -s tests/bow.gd                       # the bow: swapping, its numbers, the forge and presets, what an arrow hits and where it stops, the longbow, damage a second against the sword's
godot --headless --path . --fixed-fps 60 -s tests/bow_runes.gd                 # the bow's six runes: their rules, pictures and sentences, and each one with every band in the arena (takes about two minutes)
godot --headless --path . --fixed-fps 60 -s tests/hammer.gd                    # the hammer: its parts, swing, swing, slam and what each hits, that it pins and slows you, held in both hands, the warhammer, damage a second against the sword's
godot --headless --path . --fixed-fps 60 -s tests/hammer_runes.gd              # the hammer's six runes: their rules, pictures and sentences, and each one with every band in the arena
godot --headless --path . --fixed-fps 60 -s tests/staff.gd                     # the staff: its parts, three bolts and their small splash, range and walls, free casts and slow mana, the storm head, damage a second against the sword's and the bow's
godot --headless --path . --fixed-fps 60 -s tests/staff_runes.gd               # the staff's six runes: their rules, pictures and sentences, each one with every band in the arena, and a Spectre given to a teammate with a sword and with a bow
godot --headless --path . --fixed-fps 60 -s tests/lab.gd                       # the lab: every number it shows is really in the game and inside its limits, a change reaches the game and a reset takes it out, the file, online uses the game's own numbers, the screen in the arena and the cave, the spawner, the search ("-- show" prints every number)
godot --headless --path . --fixed-fps 60 -s tests/spirit.gd                    # the forge spirit: its pictures, where it floats, its marks, one sign for each rune used, that it changes nothing in the game, and that it joins you at the forge in the cave
godot --headless --path . --fixed-fps 60 -s tests/highlands.gd                 # the Highlands: thirty worlds against the map's rules, the painter, the ore veins, walking about (takes about five minutes)
godot --headless --path . --fixed-fps 60 -s tests/highlands_tools.gd           # the Highlands' basic tools: the belt, the buttons, digging, mining, felling, the materials bag
godot --headless --path . --fixed-fps 60 -s tests/highlands_foes.gd            # the Highlands' enemies: each one and each elite alone in the arena, where they live on five lands, groups waking and giving up, long fights on the land
godot --headless --path . --fixed-fps 60 -s tests/highlands_loot.gd            # chests and loot: where chests stand on twelve lands, opening one, two players, a full bag, Memory for kills and work, the elites' loot and Warhorn pieces, all of it saved
godot --headless --path . --fixed-fps 60 -s tests/saving.gd                    # saving: the files and their backups, a dug world coming back tile for tile, a character in a second world, the pick screens, the game saving by itself and when it closes
godot --headless --path . --fixed-fps 60 -s tests/combat_rules.gd              # the 19 November combat rules: the "toughest enemy" rule, Shards out of the enemy's back, and Hook on one enemy with every thread (Bulwark's are in hammer_runes.gd)
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

> **Version 34 changed this** (Darren's 21 November playtest). An arrow now flies at 800 px a second and does 70% of a sword hit (iron: 7.7); the shortbow shoots three plain arrows, and the heavy last arrow is the longbow's, after a short charge; the iron shortbow does 0.68 of the iron broadsword's damage a second. The rest of this section is as it was first built; see "Version 34: the 21 November playtest list".

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

- **The crate.** (Since version 34 the plates can be clicked and each weapon goes to one player: see "Version 34".) "Search the crate" opens it, and a row of plates rises over it: staff (locked), sword, bow, hammer (locked). The plate you stand under lights in your colour and the prompt names it; Use takes it. There are enough training weapons for everyone, so two players can both take the bow. While the room's fight is on the row is hidden (on a controller the dodge button is also Use, and a dodge beside the crate must not swap your weapon); once the room is clear it is back, and you can swap until room 2's fight starts.
- **The first rune** is each weapon's own. **Since version 32 it is Whirlwind for the sword and Volley for the bow** (Darren, 17 November, in the Game Bible: all four starter runes are active ones). Versions 21 to 31 gave the sword Shockwave and the bow Steady Aim; Steady Aim had been Claude's choice while the Bible left the bow's starter open.
- **The smith** hands a bow player tin limbs, a tin grip and tin arrows. A tin bow counts as forged when the limbs and the arrows are tin and the rune is in a slot (the arrows are a bow's damage).
- **Words.** The cards, hints, objectives and the smith's lines fit the weapons in play: one text for swords, one for bows, one when the players differ. Online they go by every player, not by your own weapon, because a line of speech must be the same length on both computers.
- **How long the fights take** with the test's scripted players (three runs each, seconds; measured in version 21, with the first runes of that time): crawlers 11.6 with the sword and 12.7 with the bow, burrowers 13.1 and 11.9, the nest 19.2 and 20.0, the guardian 24.3 and 22.3. The bow's player was hit less often. Scripted players are not people: this only says the cave is neither a slog nor a walkover with a bow.
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

> **Version 34 changed this** (Darren's 21 November playtest). The hammer is now very slow and very heavy and is held in both hands: an iron maul's swing does 30.8 and its slam 46.2, at 0.45 of a sword's speed, and it does 1.28 times the iron broadsword's damage a second. The rest of this section is as it was first built; see "Version 34: the 21 November playtest list".

- "The close-range heavy hitter: big damage in a small area, so you must get in close" (Game Bible). An iron maul's swing does **18.7** (an iron sword's 11 and seven tenths more), it swings at seven tenths of a sword's speed, reaches three quarters as far (68 px, a broadsword 91) and you walk at 80% speed while swinging. Against one enemy it does **1.19 times** the iron broadsword's damage a second (`tests/hammer.gd` measures it).
- The maul's chain is **swing, swing, slam** (Game Bible). A swing is a short blunt arc. The **slam** lands on a **patch of floor** in front of you (38 px round, a little further out than the swings reach) and hits everything on it for one and a half swings.
- **A hammer pins, a sword shoves.** A swing stuns for 0.3 s and a slam for 0.6 s (a slash 0.16 s, an overhead 0.3 s) and shoves about half as far, so what you hit is still in reach for the next blow.
- **Two heads so far.** The **maul**, and the **warhammer**: three slow crushing blows that each land on a slightly smaller patch (32 px), stun for 0.7 s, and slow you to 70%. Each blow is lighter, so the two heads do the same a second. The spiked hammer and the sledge from the Game Bible are not built.
- Parts: head (`HEADS`: wooden, tin and iron maul, iron warhammer), haft (`HAFTS`: 1 to 3 slots) and counterweight (`WEIGHTS`: the pommels' four).

### The staff

> **Version 34 changed this** (Darren's 21 November playtest). A bolt now does 60% of a sword hit (iron: 6.6), flies at 520 px a second and also hurts whatever stands right beside the enemy it hits; the apprentice head casts three plain bolts; **basic casts cost no mana, and the staff's runes do**; mana comes back at 5 a second and no faster for resting. The rest of this section is as it was first built; see "Version 34: the 21 November playtest list".

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

> **Version 34 changed this** (Darren's 21 November playtest). **Quake is a crack along your aim**, and with the heavier hammer every number below that is "a swing's worth" is bigger. Hook's hook is a forged bronze claw. The rest of this section is as it was first built; see "Version 34: the 21 November playtest list".

Three passive and three active, like the sword and the bow. The Game Bible gives each a line and Darren set Aftershock's bands on 11 November; **what the other bands do, and every number below, is Claude's design**, for Darren to overturn. In the test arena the iron maul carries Quake, Bulwark and Hook on its three buttons and Aftershock as its passive; the others are in the forge's rune tab.

- **Momentum** (passive): each swing that lands lights one of five chevrons round your feet, and each lit one makes your swings hit 8% harder, so +40% at five ("MOMENTUM +40%!"). Two seconds after your last hit they start to go out, one every half second. One swing is one step however many enemies it catches, and the bonus is for swings, not for what runes do. Twice: two steps a swing. Wider: bigger steps (+13%, up to +64%). Every Hit: every enemy a swing catches is a step. Saved Up: a step only on every third swing that lands, but +20% each, up to +100%. On Dodge: a dodge counts as a hit. A step is never worth more than +20% whatever the bands, so Momentum at its most doubles a swing.
- **Stagger** (passive): your swings fill a small meter under the enemy's health bar: a swing fills a quarter, a slam or a crushing blow a quarter and a half. Full, it breaks: the enemy takes a blow worth one more swing and is stunned for 1.5 seconds (stars turn over it), and the meter can't fill again until it wakes. Left alone for three seconds the meter empties. The meter is the enemy's own, so two hammers fill it together. What nothing can stun (the forge guardian) takes the blow and no more. Twice: fills twice as fast. Wider: the break also stuns everything within 80 px of it. Saved Up: fills a third as fast, for three times the blow and a 4.5 second stun. On Dodge: dodging past an enemy counts as a hit on it. Every Hit does nothing here, and the forge says so.
- **Aftershock** (passive; the bands are Darren's): 0.6 seconds after your finisher lands, hit or miss, the ground there rumbles: seven tenths of a swing to everything within 60 px and a short stun. A crack shows where it will be. Twice: a second rumble 0.35 seconds after the first. Wider: a bigger one (96 px). Every Hit: a small one (42 px) at half strength after every swing that lands. Saved Up: every third finisher a huge one (90 px), three times as strong. On Dodge: a dodge leaves one where you were.
- **Quake** (active, press, 5 seconds; the Bible's starter rune for the hammer): the ground erupts under the enemy you are aiming at, up to 240 px away: a swing and a half (28 from the iron maul) to it and everything within 44 px of it, and a 0.6 second stun. It picks whoever you point at before whoever is nearest; with nobody in range it erupts 120 px in front of you. Twice: then under the next enemy, 0.3 seconds later. Wider: a bigger patch (70 px). Saved Up: three times as strong, 15 seconds. On Dodge: a dodge sets one off at half strength.
- **Bulwark** (active, press, 10 seconds): a shield for 3 seconds. Nothing that comes from an enemy hurts you ("BLOCKED!"). **Since version 33 it only blocks** (Darren, 19 November): it takes three hits, and the third breaks it, so it bursts and stuns every enemy within 90 px of you for 1.5 seconds ("SHIELD BURST!"). Until version 32 it stunned and shoved whoever hit it. Its button shows a bar running down while the shield is up and starts to recharge only when it drops. It also works with the arena's Invincible switch on, so it can be tried there. Putting the hammer away or being knocked out drops it. Twice: the burst stuns twice as long. Wider: 4 seconds and four hits. Saved Up: 9 seconds and nine hits, and 30 to recharge. On Dodge: a dodge puts it up for a second, good for one hit. More under "The 19 November combat rules".
- **Hook** (active, press, 4 seconds): **since version 33 one chain on one enemy** (Darren, 19 November): it flies from the hammer's head at the enemy nearest your aim within 260 px, bites it for three tenths of a swing and drags it all the way to you. A boss is too heavy, so the chain pulls you 60 px towards it instead. Until version 32 chains pulled in every enemy within 260 px. Its threads are under "The 19 November combat rules".
- **The bands on the active three** follow the sword's rules: Every Hit takes half a second off the recharge for each swing that lands (not while a Bulwark is up), and Saved Up is three times as strong and three times as slow (Quake three times as strong, Bulwark three times as long; Hook's bite stays the same and the enemy it drags in arrives stunned for 2 seconds more).
- What a rune hits (a rumble, an eruption, a break) never crits and sets no other rune off.
- **Balance.** On one enemy Aftershock adds about a fifth to a chain (13 on top of 65), Stagger about a fifth and a 1.5 second stun every five swings or so, and Momentum up to two fifths for as long as you keep hitting. Bulwark with nothing on it is up for 3 seconds in every 13. This is the first pass.
- Where it lives: the entries in `FITTINGS` that carry `"weapon": "hammer"` and the constants under them in `scripts/weapon/swing_build.gd` (`MOMENTUM_*`, `STAGGER_*`, `AFTERSHOCK_*`, `QUAKE_*`, `BULWARK_*`); "The hammer's runes" section of `scripts/player.gd`; the meter itself in `scripts/enemy.gd` (`add_stagger()`, `stagger_break()`). Online, `net_state()` in `scripts/game_base.gd` compares every player's Momentum, rumbles and shield and every enemy's meter. The pictures are the art thread's (`art/swing/runes/`, `art/hud/`, `art/fx/`, numbers in `art/swing/hammer/hammer.json`); the stills the forge shows on Alt were taken from the game (Hook's was retaken with a hammer; Hook's, Bulwark's and Shards' were taken again in version 33 when their rules changed). `tests/hammer_runes.gd` checks every rune with every band.

### Both in the tutorial cave (version 27)

- **The crate offers all four.** The staff's and the hammer's plates hang beside the sword's and the bow's and can be taken and swapped like them. (Versions 22 to 26 had a fault here: the two plates were meant to stay locked and did not, and a run with either got stuck at the rune pedestal. `tests/cave_playthrough.gd -- hammer` found it.)
- **First runes.** The hammer's is **Quake** (the Game Bible's). The staff's was an open item: **Lance** was Claude's choice, the staff's rune for one big enemy (a starter rune must help against the guardian) and the one the staff on the title picture is using; since 17 November it is in the Game Bible's list too. Both are **active** runes, the first the cave handed out (since version 32 the sword's Whirlwind and the bow's Volley are as well), so once the rune is fitted a card says "Square runes are active: an ability on a button" and which button (right mouse or RB), before the guardian wakes; the button then sits under your health bar like in the arena. The smith's lines know which kind of stone you carry ("Square stones like yours are active...").
- **The words fit the weapon.** Its card at the crate (the staff's explains mana), the first fight's hint ("the third swing is the slam", "the third cast is the burst"), the rune's card, the forge's hints ("the slot in the haft"), the smith's lines and the tin parts: a tin head and haft for the hammer; a tin head, shaft and crystal for the staff, whose crystal is its damage as arrows are a bow's. All of it is in `WORDS` at the top of `scripts/cave/cave.gd`, one entry a weapon.
- **How long the fights take** with the test's scripted players (three runs each, seconds; measured in version 27, when the sword and the bow still had their passive first runes): crawlers 11.8 with the hammer and 12.5 with the staff, burrowers 9.0 and 10.5, the nest 16.2 and 20.5, the guardian **19.6** and 23.0 (the same day's sword run: 12.8, 10.4, 17.8 and 23.9; the bow's: 13.4, 12.0, 17.5 and 23.5). So the guardian falls about a fifth sooner to the hammer than to anything else: its swings do 1.19 times the sword's damage a second and Quake comes on top. The scripted players are never afraid to stand next to it, which a person with a slow weapon will be, so this is a number to watch and not yet a reason to change one.

### The staff's runes (versions 25 and 26)

> **Version 34 changed this** (Darren's 21 November playtest). **The staff's runes now cost mana**: Nova 25, Spectre 40, Lance 8 a pulse until the bar is empty, and Orbit, Chain and Overflow 5 each time they go off. A bolt is 6.6, not 8.8, so every number below that is "a bolt's worth" is smaller. The rest of this section is as it was first built; see "Version 34: the 21 November playtest list".

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

## The lab (version 28, 15 November; its search, version 29)

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

- **Finding one (version 29).** Darren, 15 November: "Are these just a big list or can I search?" The box at the top right searches every page at once. Click it, or press **/** (Ctrl+F works too), and type: the list changes with every letter and shows each number that has all the words you typed, under headings such as "SWORD > DAGGER". Capitals don't matter and neither does the order of the words: "sword damage" and "damage sword" find the same. A few everyday words are understood as the lab's own: "hp" finds health, "cooldown" finds recharge, "boss" finds the forge guardian, "range" finds reach and how far things fly. While you type in the box the letter L types an L (it doesn't close the lab). **Esc** empties the box and shows the page you were on; so does any page's button. **Enter** leaves the box with what was found still showing, and it is still showing when you close the lab and open it again. Over a search the first button at the bottom reads **RESET THESE** and resets only the numbers the search is showing. The search needs a keyboard; on a controller the pages are the way in.
- **Changing one.** Click **-** or **+** (hold it to keep going, hold Shift for steps five times as big), or click the number and type a new one (Enter takes it, Esc leaves the old one). A share is shown and typed as a percentage: 80% is four fifths. A changed number turns amber, the row shows the game's own number beside it ("GAME: 11") and a **RESET** button; its page's button counts the changes on it.
- **Where it is in force.** At once and everywhere: the arena and the cave, for both players on a shared screen. Weapons in the hand are worked out again when the lab closes, and everyone alive, enemies included, takes their new health (keeping the same share of it). Every number has limits, so a typed mistake can't break the game.
- **Where it is kept.** In a small file on that computer (`lab.json` in the game's own data folder), so the changes are still there the next time the game starts. While any number is changed, the bottom-left corner of every screen says so beside the version: "LAB: 3 NUMBERS CHANGED". **RESET THIS PAGE** and **RESET EVERYTHING** put the game's own numbers back.
- **Passing them back.** **COPY MY CHANGES** puts every change on the clipboard as plain lines, each with the exact number in brackets, for example `Sword > Dagger > Damage: 60% -> 70%  [build:SHAPES/dagger/damage = 0.7]`. Paste that to Claude and those become the game's own numbers in the next version (the lab then shows them as unchanged).
- **Online** the lab is not there and its numbers are switched off: both computers play with the game's own numbers, because two computers with different numbers would drift apart. They come back when you leave the online game.
- **What does not follow.** Words in the forge that spell a number out ("at half strength", "three times as strong", a part's "+8% crit chance") are fixed text. The forge's numbers plate, a rune's recharge and time in its sentence, and everything in the fight itself do follow. Saved Up's "three times, every third" is not in the lab: too many rules lean on it.

**The Spawn page** (test arena only) puts any enemy in the game into the room, near you: the three crabs, the cave crawler, the cave burrower, the forge guardian and more training dummies, one at a time or five at a time. The guardian is awake at once, keeps to the arena, shows a small health bar once he is hurt, and his empty suit is cleared away a few seconds after you beat him. **REMOVE EVERY ENEMY** empties the room (the dummy it started with stays), and a switch stops or starts enemies arriving by themselves. Pause enemies (P) and Invincible (H) work on everything you spawn.

**How it is built.** `scripts/lab.gd` is the list: each row says which page and group a number is on, what it is called, where it lives in the code, and its step and limits. The numbers themselves are still in the code where they always were (`scripts/weapon/swing_build.gd`, `scripts/player.gd`, `scripts/enemy.gd`, the cave's enemies), now as `static var` in place of `const` so they can be written to while the game runs. To put another number in the lab: make it a `static var`, add one `_add(...)` line, and `tests/lab.gd` checks it. Only the game's front door (`scripts/boot.gd`) reads the lab file, so the tests, which load a scene directly, always run on the game's own numbers. The screen is `scripts/ui/lab_screen.gd`; the spawner is `spawn_enemies` in `scripts/main.gd`. The search is `Lab.find(text)`: a number is found by its page, group and name and by its place in the code (`SLAM_DAMAGE` counts as "slam damage"), and the everyday words it also understands are the short list `Lab.ALSO`.

Which keys open it, which numbers are in it, their steps and limits, the spawner's details, and how the search works (its keys, the everyday words it understands) are Claude's choices, for Darren to change.

## The Greystone Highlands (versions 35 to 44, 21 to 23 November)

Darren said go on milestone 8 on 21 November ("let's build the highlands from it and the game doc"), one version at a time ("make one at a time for me to test"). First came **the land** (versions 35 to 39): the base clearing and the inner ring, to walk about on. Then, on 22 November, "make the pre shine a little more, put in basic tools" (the ore): **version 40** is brighter veins and the basic tools, and **version 41** is the answer to the project's own review of version 40 before Darren played it ("hits don't feel like hits", "copper hardly changed"). **Version 42** is saving (Darren, 22 November: "Ok go"). On 23 November Darren dropped the one-at-a-time rule ("Ok let's speed up creation as I can test multiple things at once"), so the steps now follow each other without waiting: **version 43** is the enemies, and **version 44** is chests, loot, coins and Memory (and the enemies' redrawn pictures). Levelling, Pip and Rattlecrown come next, each as its own version; the smelter and anvil are still to build too.

### The basic tools (versions 40 and 41)

How tools are used is Darren's, from 22 November: one **work button** uses the tool you have picked, and a **cycle button** steps through them ("would rather cycle tools to what u need rather than auto picking it"). The game never picks the tool for you. Your weapon stays your weapon: attack and it swings, and its swing path and the forge spirit never leave the screen. Tools sit on a **tool belt**, never break, and what they win goes into a **materials bag** of 20 places of 99, apart from the backpack (that one is for accessories). The belt and the bag belong to the character.

- **The buttons.** **F** uses the picked tool on what you aim at (the mouse, or the way you face); hold it to keep working. **C** picks the next tool, and so does the mouse wheel (either way). On a controller: the **left trigger** and **Select**. In the Highlands F is no longer a second "use" key and the left trigger no longer a second dodge button; E, Space, Shift, A and Y do those jobs as before. The card you arrive to says so, and the belt shows the two buttons all the time.
- **The belt and the bag on the screen.** Above your swing path: the picked tool's name, the two buttons, three small places with the pickaxe, the axe and the mallet (the picked one framed in amber, the others dimmed), and beside them a picture and a count for each material you carry. A second player's are on their side of the screen. There is no bag screen yet.
- **The pickaxe** digs rock: three blows and a tile is dug floor, with one stone for the bag. A tile with tin or copper in it takes four blows and gives two ore. It also breaks up a boulder (four blows, two stone). All of the Highlands' ore can be mined with the basic pickaxe (the Game Bible: tin, copper, iron and coal from the start; the hard gate begins at Emberite).
- **The axe** fells a pine in five blows: it leans away from each blow and back, then comes down off its stump, away from you, and its three wood drops where the crown lands.
- **The mallet** is for building, and there is nothing to build yet: swing it and it says so.
- **Seeing what you are doing.** While a tool swings, four small corners mark the tile or the trunk it will strike. They grow with every blow and would meet as it gives way. Rock and ore also crack (version 41): the cracks spread with every blow, ore shows a little of its metal in the break, and they stay for a few seconds on anything part dug and fade as it becomes whole again. Rock left alone for four seconds is whole again. (Dig up the screen from right against a rock face and your own head hides most of that tile; the corners stand outside it, which is why they are kept beside the cracks.)
- **A blow that lands (version 41).** It holds for a twentieth of a second; chips fly off in the rock's or the wood's own colours; iron strikes a spark off stone; the tile jolts a pixel (a pine leans away and back, a boulder shivers); and stone, ore and wood each have their own sound. Then the tool springs back off the work, so you see what the blow did. When the thing gives way there is a burst of rubble and the screen shakes a little; what you won hops out, lies a moment, and flies to you, lighting its count.
- **Ore as you mine it.** A mined tile takes its own part of the seam with it and the rest of the seam stays exactly where it was. Digging towards ore hidden in a hill brings its seam out of the dark, a tile ahead of you.
- **What cannot be dug.** The hill the cave mouth is set into (the way down to the forge has to stay), and the rim of the land laid out so far. The tool rings off them: "Too hard to dig".
- **A full bag.** Ore and wood are never thrown away: with no room for them the blow is not struck and you are told "Bag full". Stone is only rubble, and digging must always be possible, so with a full bag the stone is left behind.
- **Tunnels.** A tunnel dug one tile wide can be walked (rock now stands back two pixels from open ground, because you are as wide as a tile). Since version 41 dug floor in the rock's shadow is one step darker, not two, and never the black of the undug rock, so a narrow tunnel shows its floor and whoever stands in it.
- **Saved (version 42).** What you dig and fell stays dug and felled in that world, and the belt and the bag go with your character: see "Saving" below.

The pictures (the three tools in the hand, on the belt and as HUD signs, the four materials, the stump) are the Art builder thread's, in `art/tools/`. So are the cracks, the bursts and the pines' shake and fall (version 41), in `art/dig_fx/`, whose own README says how each is meant to be used. The code is `scripts/highlands/tools.gd` (the belt, the swing, what breaks and what it gives) and `scripts/highlands/bag.gd` (the bag).

### Saving (version 42)

Darren, 21 November: "It works like terraria, player is saved", and of the list that followed (the map and what was changed on it, the base, story progress, the squad's level) "Everything you just suggested". So there are two kinds of save, and they are separate:

- **A character** is one player. It keeps every weapon it has (the one in the hand and the ones put away), their runes and threads, each weapon's three presets and their names, which parts it can use at the forge, its forge spirit, its tool belt, the tool it has picked, its materials bag, and (since version 44) its coins, the Memory it carries and the pieces of the Rusted Warhorn it holds. A character can go into any world.
- **A world** keeps its number and what has been done to its land: every tile dug or mined, every pine felled (and its stump), every boulder broken, and (since version 44) which of its chests have been opened. The land itself is never written down. The same number always makes the same land, so the game makes it again and then does to it what you did. Seams of ore are worked out from the land as it was made, so what is left of a half-mined seam is exactly where it was.
- Still to come, as each is built: the backpack and accessories (the character), the base and its chests, story progress and the squad's shared level (the world).

**Picking them.** **Highlands** on the title screen opens two short screens. *Who is playing?* Every player who joined picks a character from the list, or **+ New character**, in their own column with their own controls; nobody can pick a character somebody else has picked. *Which world?* One list for everybody, or **+ New world**. Both lists have the save played last at the top, and say what each one holds (the weapon in its hand, what is in its bag, the world's number, how much was dug, when it was last played and for how long). W / S or the stick chooses, Enter or A picks, Backspace or B goes back, and the mouse works too. The screen starts on the world your character was in last, so coming back to where you were is Enter, Enter.

**There is no save button.** The game saves by itself: every minute, when you open the pause menu, when you close the forge screen, when you go back to the title, when you choose "Quit game", and when the window is closed. A small word, SAVED, shows at the top of the screen for a moment each time something was written. A save is only written when something in it has changed. You always arrive at the cave mouth.

**One way to lose a little.** The **Stop** button in the Godot editor (F8) does not close the game, it kills it where it stands, and a killed game cannot save. You then keep everything up to the last save, which is never more than a minute old. Leave by the pause menu or by closing the game's window and nothing is lost.

**Deleting.** Delete (X on a controller) on a row asks first; a second press deletes. A deleted save is not destroyed: it is moved out of the lists into a `deleted` folder beside the saves, and can be put back by hand. Its name is never given to another save.

**The files.** One small text file (JSON) for each character and each world, in the game's own data folder (on Windows `%APPDATA%\Godot\app_userdata\Modular Weapon Prototype\saves`): `characters/character_3.json`, `worlds/world_2.json`. Beside each is one **backup**, `.json.bak`: the save as it was before the last change. A save is written to a new file, read back to make sure all of it arrived, and only then swapped in, so a crash or a power cut in the middle leaves the old save or the new one, never half of each. If a save cannot be read, its backup is used and its row says so ("from its backup"). If a save cannot be written (a full disk), the screen says so and the save that was there is left alone.

**Saves from another version of the game.**
- A weapon made of a part this version does not have is left out, and the screen says which; nothing impossible is ever put in anybody's hand.
- A world only fits the land its number makes. When a later version makes the land differently (new places, a new ring), a world saved before is **laid out again from its number, without what was dug in it**; its row says so before you open it, and a card says so when you arrive. Characters are not touched by this. `WorldGen.GEN` is the number that says which making of the land a world belongs to, and `tests/saving.gd` fails if the land changes while that number does not.
- A save written by a newer version than the one you are running is shown, cannot be opened, and is never written over.

**How it is built.** `scripts/save.gd` knows only files: names, reading, the safe write, the backup, deleting. What goes into a character or a world is decided where it lives: `SwingBuild.to_save()` and `from_save()` for the weapons, `Tools.hand_data()` for the belt and the bag, `LandMap.changes()` and `apply_changes()` for the land. `scripts/highlands/highlands.gd` puts them together and decides when to save (`save_now()`); `scripts/ui/save_pick.gd` is the two screens; `scripts/boot.gd` joins them to the title screen and to the cave's stairs.

### The enemies (version 43)

The hills round the cave are safe. Farther out the land belongs to hounds and goblins. What each one is and does is the Game Bible's (Darren's decisions of 19 and 23 November); every number is Claude's and is in the lab (L, the page **Highlands enemies**).

- **Cliff Hound.** Pairs, and packs of three or four. They run up, circle you a few steps off, each its own way round, and one at a time (two in a pack of four or more) one crouches for half a second and lunges in a straight line. Step aside and it misses and stands a moment, open. A hit while it crouches or comes at you stops the lunge.
- **Pebble Slinger.** Keeps a throw away from you, backs off when you close in (slower than you run), and stands behind a boulder, cairn or standing stone when one is near. It whirls its sling and lobs a pebble over whatever is in the way, at where you are standing: keep moving and it lands behind you. A hit while it whirls spoils the throw.
- **Scrap Brute.** Slow, tough, and its shield stops every blow from the front (BLOCKED). Hit it from behind or the side, or wait: it raises its boulder on a pole, swings, and for a second afterwards its guard is down. A stun drops the shield too. It turns slowly, so running round it works. Never more than one in a group.
- **Goblin Shaman.** Stands behind the other goblins and backs away from you. Every few seconds it raises its staff and a bat comes (it keeps three). The bats hover round you and swoop to nip. Kill the shaman and its bats scatter; hit it while the staff is up and the call is spoiled.
- **The elites** are tougher, show their health from the start of a fight and have a thin rim of light. The **pack leader** (a white, scarred hound) howls and two more hounds come running (hit it to cut the howl off). The **elite slinger** throws a rock as big as its head that bursts into six shards where it lands. The **elite brute** makes every third attack a shield bash that charges at you and throws you a long way back. The **elite shaman** keeps six bats and every so often wards a goblin near it: for three seconds that goblin cannot be hurt (three scrap shields circle it, and blows on it say WARDED).

**No marks on the ground for their attacks.** Darren, 23 November: "Not every enemy has to have telegraph markers for its moves, only bosses." None of these draws a lane, a circle or a ring, the elites included. The wind-up pose and its sound are the warning: the crouch, the whirling sling, the raised boulder, the raised staff. A thrown rock has its own shadow on the ground under it, which grows as the rock comes down (version 44); that is the rock's shadow, not a mark of where it will hurt. (The tutorial cave's crawler and burrower are as they were.)

**Where they live.** `scripts/highlands/foe_plan.gd` reads the finished map and gives each open place a group or leaves it empty. The same world always has the same groups in the same places, and the land itself is not changed by it (a world saved before version 43 is still the same land).
- Nothing lives within 40 tiles of the cave. Out to 72 tiles half the open places are empty and the rest hold a pair of hounds or a pair of slingers.
- Beyond that about a third are empty; the rest hold hounds (two, three or four) or goblins (two or three slingers, a Scrap Brute leading some, a Shaman at the back of some).
- The Keeper's Watchpost is a den of three hounds. The Old Quarry is the elite brute's camp, with two slingers.
- The other three elites each hold one far open place of their own until the Hound Den and the Slinger Roost are built: the pack leader with two hounds, the elite slinger with two slingers, the elite shaman with a Scrap Brute and two slingers.
- One land has about 40 groups and about 110 enemies.

**How a group behaves.** A group stands at its home until one of it sees a player in the open within about nine tiles (rock hides you), or hears one very close, or is hit; then the whole group fights. They find their way round the rock, and through anything you dig. Go about twenty tiles from their home and they give up, walk back and get their health back. A killed enemy stays dead for five minutes, and comes back only when nobody is near enough to see it. Nothing about enemies is saved: load a world and every group is at home.

**If you fall** you wake at the cave mouth with full health, as before. (What dying costs is not decided.)

**What they leave** is in the next section (version 44). Their sounds are the game's existing ones for now. **Their pictures are second drafts** (version 44): Darren saw the first drafts and asked for better ones (23 November: "Not a huge fan of the enemies, use the design principles and make them better"), and the Art builder redrew them with the same names and sizes (`art/foes/`, with its own README). He has not seen the redraw yet.

**In the test arena** every one of them, and each elite, is in the lab's Spawn page.

**How it is built.** `scripts/foes/foe.gd` is what they share (the group, finding the way, the ward, the art); `hound.gd`, `slinger.gd`, `scrap_brute.gd`, `shaman.gd`, `bat.gd` are each one's behaviour; `rock.gd` is what the slingers throw; `pack.gd` is a group's shared state (calm or fighting). `scripts/highlands/nav.gd` is one grid of the whole land that answers "how do I walk from here to there", told at once when a tile is dug or a boulder broken. `scripts/highlands/foes.gd` puts the groups near the players on the land and takes the far ones off it, so a land of a hundred enemies only ever runs the few near you.

### Chests, loot, coins and Memory (version 44)

The Game Bible decides what there is: random chests "scattered around" holding "usually tin or copper bars, coins and Memory (straight into your bar)"; "coins are a plain counter"; bars go in the materials bag; Memory is "earned from everything: killing, mining, chopping and building"; elites give "the same kinds of loot as the chests", and three of them a piece of the Rusted Warhorn (the body from the Elite Scrap Brute, the bell from the Elite Cliff Hound, the mouthpiece from the Elite Pebble Slinger); opened chests are saved with the world. How many, where, and every number are Claude's, and the numbers are in the lab (L, the page **Chests and loot**).

- **Chests.** A land has about 34. About half the places somebody lives in have one, at the back of the place as you come from the cave, and a few of the empty places. Every **sealed place** (the ones only a pickaxe finds) has a richer one, and so have the **Keeper's Watchpost** and the **Old Quarry**. The open place nearest the cave always has a small one, so the first chest is met in the safe hills. Walk up to a chest and press use (E, or A on a controller): the lid opens, the coins, bars and Memory hop out, lie a moment and fly to you, and the chest stands open and empty from then on, in that world, for good.
- **What is in one.** 8 to 18 coins, one to three bars and 15 Memory; about a third more of each far from the cave. Near the cave the bars are mostly tin, farther out mostly copper. A richer chest holds two and a half times the coins and Memory and both kinds of bar. Accessories, blank rune stones and the unique parts are not in the chests yet, because there is no backpack or anvil to do anything with them.
- **Everyone gets a full share** of every chest and every kill, whoever opened it or struck the blow.
- **Coins and Memory** are counted beside your health bar, the coins above and the Memory under them. Both belong to the character and are in its save. There is nothing to spend coins on yet, and Memory cannot be poured into the forge yet: levelling is the next version.
- **Memory for a kill**: 4 for a hound or a slinger, 8 for a shaman, 12 for a Scrap Brute, 40 for any elite. An enemy that was called into the fight (a hound answering a howl, a shaman's bat) gives nothing, so howls and bats cannot be farmed. **Memory for work**: 1 for a tile of ore mined or a pine felled; none for digging plain rock.
- **An elite** also leaves 15 to 30 coins and two to four bars, and its piece of the Warhorn if you have not got it. The pieces are **kept things**: they sit beside your coins, take no room in the bag and cannot be lost. A line on the screen says which piece you got and how many of the three you hold. (What the Warhorn is for comes with Rattlecrown.)
- **A full bag.** A bar that does not fit lies where it fell, glinting, until you have room and walk over it. What still lies there when you leave the world is lost.
- **Falling costs nothing yet.** The Bible's price (some coins and half your unbanked Memory, left as a marker to fetch) comes with the forge's levels, when there is a way to bank Memory first.
- A world saved before version 44 gets its chests without being laid out again (the land is not changed by them: `WorldGen.GEN` is still 1), and a character saved before it starts with no coins.

**How it is built.** `scripts/highlands/loot_plan.gd` reads the finished map (before a save's digging is done to it again, so a felled pine never moves a chest) and says where each chest stands and what it holds; each chest has dice of its own started from the world's number, and its id is the number of its open place, which is what the world save keeps. `scripts/highlands/loot.gd` stands them on the land, opens them, gives things to players (`give()`), listens for the enemies' deaths (`foes.gd` tells it) and the tools' wins (`tools.gd` tells it), and draws the purse. `scripts/highlands/item_art.gd` finds a carried thing's picture on either of two sheets (the tool art's and the loot art's, `art/loot/`). The enemies' way-finding is told where the chests stand (`nav.gd`, `block()`), so nobody walks through one.

### How to get there

- **From the title screen.** **Highlands**, then pick or make a character and a world (see "Saving" above). A new character made there carries the test arena's four weapons, and **B** (or a click of the right stick) swaps between them, as in the arena.
- **From the tutorial cave.** The stairs at the end lead outside: after the "Daylight" card you are standing in front of a cave mouth with the weapon you built. Each player has become a new saved character, with that weapon and the parts won in the cave, in a new world. (Online the cave still ends at the lobby; the Highlands are not online yet.)
- **One map again, without saving anything.** Start the game with a world's number: `godot --path . -- highlands seed=123456`. The card a new world opens with, and its row on the pick screen, give the number.

### What is there

- **How big (version 39).** Darren played the land on 22 November: "The world was good, but seemed quite small as can travel one end to the other in about 2 mins". Only the inner ring was laid out, about 100 tiles from the cave. He then chose a bigger Highlands on a card: about 350 tiles from the cave to the edge (the Game Bible's "Highlands size"). The rings scale with it: the base hills to about 24 tiles, the inner ring to about 125, the middle ring to about 240, the outer ring to about 350. Version 39 widens the inner ring to its new edge, which gives about one and a half times the ground to cross and about twice as many places to find, and makes the map itself big enough for all three rings. The middle and outer rings stay solid rock until their places are built.
- **Mostly rock.** About three quarters of the inner ring is rock, drawn with the dark top the cave's walls have, so a hill hides what is inside it. Since version 40 the pickaxe digs it (all but the hill the cave mouth is in, and the rim of the land laid out so far).
- **The base.** A clearing outside the cave mouth that fits on one screen, with a trodden track from the mouth to its front gap, hills round it, and two to four gaps through the hills. Two veins of tin and two of copper run through the rock round it, most of them in the hill you look at from the clearing (see "Ore" below). Nothing is built there.
- **Open places.** About 77 of them in the inner ring. They differ in size: about a quarter are small nooks 6 to 8 tiles across, most are 10 to 14, and up to six in a world are big (16 to 20 tiles), some of them long bent glens. They are joined by gaps that sway from side to side and are anything from two to six tiles wide along their length, most with a footpath, and no way cuts straight across another. About one way in seven is an old dug tunnel with lanterns (two wide and nearly straight, because it was cut on purpose). Every one can be walked to from the cave, except seven or eight that are sealed inside the rock on purpose, for the pickaxe to find later (they always hold ore).
- **Ore (version 38).** Tin and copper are veins running through the rock, never dots stuck on it. Darren on 21 November: "No no I want it like veins through the rock", then "Make it so that it doesn't show all the way through the dark, and fades into fog of war"; on 22 November, of the art thread's sheet: "Ok on veins look". A vein is a seam two pixels wide, silver for tin and orange for copper, with small pockets and hairline forks and a dark crack along its upper side. It crosses the dark top of the rock, goes over the edge and runs down the lit face to the ground. It is bright on the face and plain near the edge of the top, then it thins, breaks up and is gone about a tile into the dark. So you see ore where rock meets open ground, and the heart of a hill shows nothing until somebody digs towards it. Besides the four by the base there is ore on the edge of under half the open places, always in a sealed one, and about two dozen clusters hidden deep in the rock (about 78 clusters in a world, about 50 of them in sight). **Brighter since version 40** (Darren, 22 November: "make the pre shine a little more"): the art thread raised the seam one step of its ramp on the lit face and near the edge of the top, gave copper a sixth, palest colour, and put small glints of the palest colour in the pockets and here and there along the seam. It still fades out a tile into the dark, and nothing moves. Version 41 is the art thread's second pass: the project's review found that copper had hardly changed, so copper is lifted again, by about as much as tin was. Since version 40 it can be mined.
- **On the land.** Grass in three tones with a tuft on nearly every tile, long grass in the hollows, against the rock and in patches of its own, and flowers in drifts (pale, pink and yellow, each drift one colour); scree, small stones lying at the foot of the rock in some stretches; heather and sage scrub as separate bushes that never touch, thick in the middle of a patch and thin at its edge; here and there a pine or two, a boulder, a gorse bush, bracken at the foot of the rock, and rarely a standing stone, a cairn, a stump or bones; a small tarn in some places, with reeds; and some life in about one place in three: a few cattle, a hare, two or three crows. Things that stand on the land are spread thin on purpose (Darren: "don't clutter it"); the richness is in the ground. Pines fade when you walk behind them.
- **Two places kept for later.** The Old Quarry (in the sector the map's number turns "west" to) has its ground and an old cut with a lantern and a barrel; the Keeper's Watchpost has its ground, a scrap of the keepers' road, two posts and a cairn. What belongs in them (the elite and the tongs, the waystone and the journal) comes in later versions.
- **The cave mouth** is the way to your forge: press **E** (or **A**) at it and the forge screen opens.
- **Not there yet:** enemies, the backpack, a bag screen, the workbench, the smelter and anvil, chests and coins, levelling, Pip, the quest, waystones, the boss, the middle and outer rings (solid rock for now), a map screen, and music of its own (the calm cave tune plays for now).

### How it is made

- **The map** is made by `scripts/highlands/world_gen.gd` from the number alone, following the Game Bible's Highlands plan and the "Highlands world and base research": rings round the cave, named places in their band and sector, mostly rock with open places, every place reachable. It checks its own work (everything not sealed can be walked to, the share of open land is right) and tries the next layout if a check fails. `scripts/highlands/land_map.gd` is the map itself: a kind for every tile, and the things standing on it.
- **The look is the art thread's own.** `tools/highlands_kit/bake.py` imports the art thread's drawing code for the approved Highlands look (it lives in the project's shared files, not in this repository) and cuts it into pieces: for every way a tile of rock, yard, water, dug floor, scree or footpath can meet its eight neighbours, four different drawings. They are in `art/highlands/` with `kit.json`. When the art changes, the tool is run again and the game follows; nothing is redrawn by hand.
- **Painting.** `scripts/highlands/land_painter.gd` lays those pieces out again for each 16 x 16 tile chunk of the map: a lit picture of the ground and one in shadow, a mask for where shadow falls, then the rock with the ore that runs through it, and lamplight on dug floors. A tile's piece is chosen from its place on the map, so chunks meet without a seam and a map always looks the same.
- **Ore veins.** In the map, ore is tiles of rock with tin or copper in them, in clusters of four to eight tiles (wider than tall, at most 6 by 4, never two run together). The seams are drawn through each whole cluster, not tile by tile. `scripts/highlands/veins.gd` holds the two rules, and both are the art thread's own, ported number for number from its drawing code: one decides where the metal is from the cluster's tiles and the world's number alone (whole-number maths and its own small dice, so the same cluster always gives the same pixels whichever chunk asks); the other gives each pixel its colour from the rock it lies in (on the lit face or on the top, how high up the face, how far in from the edge of the top). For that the kit also holds, for every rock piece, which of its pixels are face and which are top (`rock_nat_part.png`, `rock_dug_part.png`), and the ore's colours from the art's own ramps. The seams are worked out from the map each time, so a world save will hold the ore tiles and nothing more, and when rock is dug the land within three tiles is painted again, which is how a hidden vein comes out as you dig towards it. Since version 40 the seams are worked out once, from the ore the map was made with: a mined tile hides its own pixels of the seam and the rest never move.
- **Showing it.** `scripts/highlands/land_view.gd` keeps the chunks near the camera ready and lets the rest go. Pictures are painted on other threads, so walking never waits for one; the boxes that stop you are made at once.
- **Tools.** `godot --headless --path . -s tools/highlands_overview.gd -- seeds=1,2,3 out=/some/folder` draws the whole map of each seed; `tools/highlands_shots.gd` draws pictures of places on one.

### Checks

`godot --headless --path . --fixed-fps 60 -s tests/highlands_tools.gd` checks the tools (versions 40 and 41): the bag's 20 places of 99 and its saved form; that every crack, burst and pine picture the tools ask for is on the Art builder's sheet, and which crack shows after which blow; that F and the left trigger are tools only in the Highlands; the cycle button's order and that a missing tool is stepped over; three blows dig rock into dug floor, give one stone and let you walk in, and a tunnel one tile wide can be walked; rock left alone is whole again; the axe does not dig and the pickaxe does not fell (the game never picks the tool); attack always wins over a tool; four blows mine tin or copper for two ore, the mined tile's own part of the seam goes and the rest stays; five blows fell a pine for three wood and leave its stump, which gives nothing more; a boulder breaks into two stone; the hill round the cave mouth and the rim cannot be dug; a full bag leaves ore in the rock but still lets you dig; two players have their own tool and bag. With `shots=/some/folder` (and a window) it saves frames of mining into a vein, of digging sideways from inside the tunnel, of a pine coming down and of a boulder breaking; add `dense=1` for every frame of the first blows.

`godot --headless --path . --fixed-fps 60 -s tests/highlands_loot.gd` checks chests and loot (version 44): every carried thing has its pictures; on twelve lands (`-- seeds=30` for more) the same land gives the same chests, each stands on open ground clear of everything, can be walked to unless its place is sealed, every sealed place and both named places have one, and there is one first chest in the safe hills; then on a land: a chest stops you and is known to the enemies' way-finding, the use button opens it, its coins, Memory and bars are yours at once, it cannot be opened twice, two players each get a full share, bars that do not fit lie on the ground until there is room, ore gives Memory and plain rock none, each elite leaves its Memory, coins, bars and its piece of the Warhorn once, a called-in enemy leaves nothing; and all of it is in the saves and comes back, with saves from before version 44 playing on. With `shots=/some/folder` (and a window) it saves pictures of a chest opening step by step, a richer chest, a full bag, an elite falling, the purse for one and two players, and a thrown rock over its shadow.

`godot --headless --path . --fixed-fps 60 -s tests/highlands_foes.gd` checks the enemies (version 43): every picture they ask for is on the Art builder's sheet; none of them draws a warning mark; on five lands nothing lives near the cave, hounds come in twos to fours, no group has two brutes, a shaman is never alone, the Watchpost and the Quarry hold who they should, and there is one of each elite; then each one alone in the arena (a lunge bites someone standing still and misses someone who stepped aside, a hit stops it; a pebble lands on the spot and a walker is missed; the shield stops blows from the front and not from behind, after a swing, or when stunned; bats come, nip, and scatter when the shaman dies) and each elite's trick; then on a land: groups stand calm at home, wake on sight or when hit, give up and heal, a killed one comes back, far groups are taken off the land, digging changes the way at once; and last, twenty long fights with a player who keeps walking, in which nobody may end up inside rock or stand lost, and the game must keep its pace. `-- soak=6` runs only the long fights, six times with different dice. With `shots=/some/folder` (and a window) it saves pictures of every enemy and elite at work, of groups on the land and of one whole land with a dot for every group.

`godot --headless --path . --fixed-fps 60 -s tests/saving.gd` checks saving (version 42), in its own folders and never in your saves: a save's name is the only thing ever made into a file name; the first write, the backup the second one leaves, a damaged save read from its backup (and the damaged file never pushing the good backup out), a half-written file left by a crash, deleting, names never given twice, a newer game's save left alone; every weapon, preset and name coming back exactly, and what this version does not know being left out; the same land with the same changes done to it again being the same land tile for tile, thing for thing and pixel for pixel; then it plays: a new character in a new world digs rock, mines tin and fells a pine with the tools, leaves, and comes back to exactly that; takes the same character into a second world and back; the game saving by itself, on pause, at the forge, on "Quit game" and when the window closes, and writing nothing when nothing changed; a disk that will not take a save; a world from an older making of the land; two players with a character each; the pick screens with one and two players; the way in from the title screen and from the cave's stairs; and last, another copy of the game that digs a tile and closes, whose saves are then read. It also keeps a fingerprint of one land (`tests/saving_land_ref.json`): if the generator changes the land, the test fails until `WorldGen.GEN` is raised and the fingerprint written again with `-- ref`. With `shots=/some/folder/` (and a window) it saves pictures of the screens and of a world before leaving and after coming back.

`godot --headless --path . --fixed-fps 60 -s tests/highlands.gd` makes 30 worlds and checks each against the rules above (the rings and the map's size are the ones Darren chose, open land reaches about 125 tiles from the cave, the cave mouth set in rock, the clearing's size and gaps, every open place reachable and every sealed one not, no rock one tile thick, the two named places in their bands and apart, ore by the base and in a rock face there, no ore cluster too big or run into the next, some ore hidden, nothing cluttered, no two bushes touching, scree only against rock, no two ways crossing, open places of different sizes, life in about a third of them), then checks the painter (the same picture twice, a small palette), then the ore veins (the game's copy of the art thread's rules gives the art thread's own numbers, pixel for pixel, from `tests/highlands_vein_ref.json`; a seam is drawn in rock only and in the ore's own colours, crosses the top and runs down the face; ore deep in a hill shows nothing; digging in under it brings it out), then plays: two players walk about, the rock stops them, the cave mouth opens the forge, land far behind is let go, a changed tile is repainted, and the cave's stairs lead outside with the weapon that was built.

### Choices made here that nobody has confirmed

These are Claude's, and Darren can overturn any of them. **Chests and loot (version 44).** What a chest holds in kind (bars, coins, Memory), that coins are a counter, that bars go in the bag, that Memory comes from killing, mining and chopping, that elites leave chest loot and which elite carries which piece of the Warhorn, and that opened chests are saved with the world are the Game Bible's. Claude's: how many chests there are and where (half the lived-in places, a fifth of the empty ones, every sealed place, the Watchpost, the Quarry, and one small one by the cave); that a chest stands at the back of its place; every amount (in the lab); tin near the cave and copper farther out; that sealed and named places' chests are richer; that accessories, blank rune stones and unique parts are left out until there is a backpack and an anvil; that everyone gets a full share of every chest and kill; the Memory for each kind of enemy and for an elite, and that called-in enemies give none; one Memory for ore and for a pine and none for plain rock; that the Warhorn's pieces are kept things outside the bag, given once to whoever lacks one, and that the elite shaman carries none; that a bar which does not fit lies on the ground until there is room, and is lost if you leave; that falling costs nothing until Memory can be banked; that elites come back after five minutes like everything else and leave their coins and bars again; where the purse is drawn; the line "You have the Rusted Warhorn's bell (1 of 3)"; the sounds (the game's existing ones); that a chest is opened with the use button and takes about half a second; and a thrown rock's shadow growing as it falls (asked for by the project's own review of version 43). The chest, the loot pictures and the redrawn enemies are the Art builder's drafts, which Darren has not seen. **The enemies (version 43).** What each enemy and elite is and does, the group sizes, the Watchpost's hounds, the Quarry's elite brute, and "only bosses" for warning marks are Darren's. Claude's: every number (health, damage, speeds, times; all in the lab); that a hit stops a hound's lunge and spoils a slinger's throw or a shaman's call; that pebbles are lobbed over cover and aimed a little ahead of you; the words BLOCKED and WARDED; that the brute turns slowly, is open for one second after a swing, and that a stun drops its shield; the elite brute's bash on every third attack; one hound lunging at a time (two in a pack of four or more); a howl bringing two hounds, at most three howls a fight and five hounds in a pack; three bats for a shaman, six and two a call for the elite, a three-second ward every nine seconds; nothing within 40 tiles of the cave and only pairs out to 72; how many places are empty and how often a brute or a shaman is in a group; where the three elites without a place of their own live for now; a group seeing you at about nine tiles and giving up at about twenty; the dead coming back after five minutes unseen; that enemies are not saved; that the cave's crawler and burrower keep their warning marks until Darren says otherwise. **Saving (version 42).** That characters and worlds are separate saves, what each keeps, and "player is saved" are Darren's (21 November); autosaving with no save button and one backup of each save were Claude's suggestions, which he took with the rest. Claude's: saving every minute (short, because the editor's Stop button kills the game without a save) and at the five other moments listed under "Saving"; the two pick screens and their buttons; that the game gives the names ("Character 3", "World 2") and you cannot type your own yet; that there is no limit on how many characters or worlds there are; that deleting asks once and moves the save to a folder in place of destroying it; that a new character made on the pick screen starts with the four test weapons; that climbing out of the cave makes a new character and a new world every time (they can be deleted on the pick screen); that you always arrive at the cave mouth, wherever you were when you left; that the word SAVED shows each time; that a world saved by an older making of the land is laid out again without what was dug (the other way, writing the whole land into every world save, keeps old worlds exactly but leaves them without anything a later version adds to the land); and that part-dug rock, like everything else that mends itself in four seconds, is not saved. **The tools (versions 40 and 41).** How tools are used, that they never break, the belt and the separate bag of about 20 places of 99 are Darren's (22 November). Claude's: the buttons (F and C or the mouse wheel; the left trigger and Select), and that in the Highlands F and the left trigger give up their second jobs; everyone starts with the basic three on the belt, because there is no workbench to make them at yet; the numbers (rock three blows for one stone, ore four blows for two ore, a boulder four blows for two stone, a pine five blows for three wood; a swing takes 0.42 seconds, and a blow that lands holds it for 0.05 more; you reach about a tile and a half; you walk at about a third of your speed while a tool swings; part-dug rock is whole again after four seconds); the tool is in your hand in place of the weapon only while it swings, and attacking always wins over it; the corners that grow with every blow, kept beside the Art builder's cracks since version 41 because your own head hides most of a tile dug from right against it; the mallet says "Nothing to build yet"; the hill round the cave mouth and the rim of the land cannot be dug; ore and wood are never thrown away but stone is left when the bag is full; what you win goes straight into the bag (it is seen to hop out, lie a moment on the far side of where it came from, and fly to you, but nothing is left on the ground to pick up); a felled pine leaves a stump and does not grow back; boulders can be broken up, standing stones and cairns cannot; no bag screen yet, only counts beside the belt; no Memory for mining until the levelling version; rock stands back two pixels from open ground so that a tunnel one tile wide can be walked; a tunnel you dig has no lantern light. In version 41: the twentieth of a second a landed blow holds, the body's small squash, the tool springing back up after the blow, the spark (the weapons' own hit spark, small), a few loose chips beside the drawn bursts, the sounds (stand-ins made from the game's own sounds until the tools have their own), the small shake of the screen when something gives way, and that a felled pine's shadow goes as the tree lands, not by fading. The cracks, the bursts, the pines' shake and fall and the softer shadow on dug floor are the Art builder's (the last is its own choice; Darren has seen none of them yet). The brighter ore is the art thread's rule; its optional slow twinkle is not built (nothing in the land moves, and Darren asked for shine, not motion). Using the cave mouth opens the forge screen where you stand. Water stops you (tarns only, never across a way; no streams yet). Heather and scrub bushes are each a plant the map knows about (so they can become something to gather), but they, the tufts and the flowers cannot be gathered yet. The sealed places and the "about one in seven ways is a tunnel" number. Which things stand where and how many (the table is in `world_gen.gd`, `_dress`). From the title screen you carry the arena's test weapons. The words on the arrival card and "Go down to the forge". The calm cave tune plays outdoors until the Highlands have music of their own. The Old Quarry's and the Watchpost's stand-in dressing. Players carry no light outdoors. A new world on every visit until saving is built. Open land is about a quarter of the inner ring. **Size (version 39).** The size is Darren's (350 tiles out, rings at 24, 125, 240 and 350, places at least 40 tiles apart). Claude's choices in version 39: the wider inner ring is filled at the same density as before, so it holds about twice as many open places, ways, things and ore clusters (not the same number spread thinner); up to six big open places in a world, where it was four; the Old Quarry is 72 to 100 tiles out and the Watchpost 90 to 108, at least 60 apart (the research's bands stretched to the new ring); the same world number makes a different map than in version 38, which costs nothing while there is no saving. **Ore (versions 36 and 38).** Version 35 drew tin as white crystals and copper as orange nuggets on the rock. Darren turned that look down in the art thread the same evening ("I want it like veins through the rock"), so version 36 took the dots out, and version 38 draws the veins he accepted on 22 November ("Ok on veins look"). The look of a vein is the art thread's and his. Claude's choices in version 38: ore clusters are four to eight tiles, wider than tall; the four by the base go first into rock whose lit face you see from the clearing (the Game Bible: "tin and copper veins in the hill above the forge"); two clusters never touch; ore has its own dice in the map maker, so the plants and stones moved once compared with version 37 and will not move again when ore changes; veins are shown now although they cannot be mined until the pickaxe version. **Version 37** is the answer to the project's own review of 35 and 36 before Darren played them (the ground was barer than the approved concept, the heather ran together, and the map looked ruled): the ways now sway and change width, the open places differ in size, heather and scrub are separate bushes placed the way the concept places them, the ground has more tufts, long grass, flower drifts and scree, there is more life, and the calm cave tune plays. Its numbers (how far a way sways, two to six tiles wide, a quarter of places small and up to four big, life in about a third of places, how thick the flowers are) are Claude's. Rock faces stay one tile tall with chipped edges, as the approved concept draws them; tall cliffs belong to the middle ring.

## Version 34: the 21 November playtest list

Darren played version 33 on 21 November, sent a list while he played, and then said "put these into action now". Version 34 is that whole list, built in one go. **Where this section and an older one below disagree, this one is right**: the older sections say how each thing was first built. His words are quoted. How much slower, how much weaker and so on he left open, so **every number here is Claude's choice**, and so is anything marked that way. All of it is for him to overturn, and all of the numbers are in the lab.

If you changed numbers in the lab before this version, your own numbers still win on your computer. Open the lab and reset the ones you want back, or you will not see the new ones.

### The bow

"the arrows fly too fast, its too easy to land shots. too much damage also as its ranged so too easy to stay safe with that much dmg. also dont add a heavy shot on the last arrow untill later bow parts and have it charge the last shot slightly"

- An arrow flies at **800 px a second** (it was 1300), so an enemy that moves can be missed.
- An arrow does **70% of a sword hit** in the same metal (it was 80%): 3.5 from the wooden bow, 5.6 from tin, 7.7 from iron. A crawler now takes four wooden arrows. Against one enemy the iron shortbow does **0.68** of the iron broadsword's damage a second (it was 0.85).
- **The shortbow shoots three plain arrows.** The heavy last arrow is gone from it and from the wooden bow.
- **The longbow is the "later bow part"**: shot, shot, then a **charged shot**. The last arrow takes a moment longer to draw (0.42 seconds against 0.13), then hits one and three quarter times as hard with a hard shove. The longbow's arrows still fly a third further and you walk slower while shooting it. The two bows do the same damage a second (19.7 and 19.3).
- An arrow hits one enemy "slightly harder" than a staff's bolt (7.7 against 6.6 in iron), as he asked when he talked about the staff.
- **At the forge the arrow is slim** ("the bow arrow is huge in the forge screen"): the art thread redrew the forge arrows at 45 by 5 pixels.
- Where it lives: `BOW_DAMAGE`, `BOW_FLIGHT`, `BOW_SHAPES` in `scripts/weapon/swing_build.gd`; the move `charged_shot` in `scripts/player.gd`. `tests/bow.gd` and `tests/bow_runes.gd` check it.

### The crate

"make items in chest clickable so you can click which one you want. and when one is taken remove it from being selected so each playe gets different weapon"

- With the crate open, **click a weapon's plate to take it**, from wherever you stand. Pointing at a plate lights it in your colour. Standing under a plate and pressing Use still works, and that is what a controller player does (Claude's choice).
- **Each weapon goes to one player.** A weapon somebody holds shows dim with "P1" or "P2" on its plate and nobody else can take it. If you swap, your old weapon goes back into the crate (Claude's choice), so a swap is still possible until room 2's fight starts.
- Online the click goes by the mouse as the game's simulation knows it, so both computers agree who took what.
- Where it lives: `_mouse_pick`, `_holder` and `_can_take` in `scripts/cave/cave.gd`; the plates in `scripts/cave/cave_ui.gd`.

### The hammer

"the hammer needs alot slower attack speed, and better animations as it just loks like sword, need to be two handed look and slow but good damage"

- **A lot slower, a lot heavier.** A maul swings at **0.45** of a sword's speed (it was 0.7) and a swing does **2.8** sword hits (it was 1.7): 30.8 from the iron maul, and 46.2 for the slam. A wooden maul's swing does 14, which is one crawler. Against one enemy the iron maul does **1.28 times** the iron broadsword's damage a second (it was 1.19): slow, short reach and standing still next to the enemy is what you pay for it. The warhammer is slowed the same way and the two heads still do the same a second.
- **Held in both hands, with swings of its own.** The hammer is carried across the chest with both fists on the haft. A swing is hauled right back behind the shoulder and swung through past your aim. A slam is raised straight up over the head and brought down along your aim. After a blow the head stays down where it landed for a moment before it is lifted. It is still key poses and a smear, and swinging still never moves you.
- **Quake is a crack along your aim** ("quake is too similar to aftershock"; he picked "Quake: a crack along your aim" on the card). It runs **240 px** from you the way you aim and hits **every enemy on that line** (within 16 px of it) for a swing and a half (46.2 from the iron maul) with a 0.6 second stun. Aftershock stays a rumble where your slam lands. The threads (Claude's choices): Twice sends a second crack 0.3 seconds later, Wider makes it longer and wider, Saved Up is three times as strong and three times as slow, On Dodge sets one off at half strength. The art thread drew the crack: dark split stone with ember light in it and pale stone spikes.
- **Hook's hook** ("looks like a fishing hook. make it look more in line with the game") is now a **forged bronze claw** with three steel-tipped talons, open as it flies and shut as it bites. Its rune stone, its button and its spirit sign show the same claw. The claw rather than a grapnel was the art thread's pick.
- Where it lives: `HAMMER_SHAPES`, `QUAKE_*` in `scripts/weapon/swing_build.gd`; "The hammer in both hands" and Quake in `scripts/player.gd`; the crack in `scripts/fx/rune_fx.gd` ("crack"). `tests/hammer.gd` and `tests/hammer_runes.gd` check it.

### The staff

"the staff progectiles are also too fast, lets have the auto attack from staff hit a small aoe when it hits but very small as where the bow only hits one target but slightly harder. the basic attack shouldnt use mana either but the abilities should. ... lance should be ale to build up damage until mana runs out then go on cooldown ... mana recharges too fast also, we want accessories to give that later ... passives should use mana also but not as much as actives." and "also remove the heavy like the bow until later parts"

- A bolt flies at **520 px a second** (it was 760) and does **60% of a sword hit** (it was 80%): 3 from the wooden staff, 4.8 from tin, 6.6 from iron.
- **A very small splash.** A bolt also hurts every enemy whose edge is within **18 px** of where it lands: only what stands right against the one it hit. A bolt that hits nothing pops with the same small splash where it stops (Claude's choice).
- **The apprentice head casts three plain bolts.** The burst is gone from it and from the wooden staff. The **storm head** is the later part that keeps a heavy last cast: spray, spray, orb.
- **Basic casts cost no mana.** The staff's runes do.
- **Mana comes back slowly**: 5 a second, always, and no faster for resting (it was 10 a second, and 45 more after a rest). A full bar of 100 takes 20 seconds. Accessories are to give recharge later.
- **Active runes cost mana and still have their recharge**: **Nova 25**, **Spectre 40**, **Lance 8 a pulse**. Without the mana the button is not ready. The forge says both: "Costs 25 mana and recharges in 6 seconds."
- **Lance runs on mana.** Hold it and it pulses four times a second, 8 mana a pulse, growing to twice and three times as strong as the bar goes down, **until the mana is gone**: a full bar is twelve pulses, three seconds, 118.8 damage from the iron staff. When the beam stops, by running dry or by letting go, it goes on its 8 second recharge. It needs at least one pulse of mana to start. Twice halves the cost of a pulse, so a full bar lasts about six seconds.
- **Passive runes cost 5 mana each time they go off** (Orbit, Chain, Overflow), and without the mana they do not go off. His line "once passives are in thern the basic should use mana" was read as this: the basic attack stays free, and it is the passive rune's own effect that costs a little (Claude's reading, told to him on the day). An active rune's On Dodge and the copies a Spectre makes are free.
- **Overflow** now reads: "On full mana your next bolt is bigger and hits 30% harder." It costs its 5 mana, so the bolt after it is a plain one until the bar is full again, a second later (Every Hit gives 3 back for each bolt that lands).
- **At the forge** the staff's numbers plate shows its bar ("Mana 100, +5 a second") where it showed what a chain cost.
- A cast that costs mana you do not have is still a weak spark, but since no basic cast costs anything now that only happens if you give casts a cost in the lab.
- Against one enemy the iron staff does **0.59** of the iron broadsword's damage a second from its bolts alone (it was 0.85), and a little less than the bow, because a bolt also hurts what stands beside its target and the staff's runes come on top.
- Where it lives: `STAFF_DAMAGE`, `STAFF_FLIGHT`, `BOLT_SPLASH`, `STAFF_SHAPES`, `MANA_REGEN`, `CAST_MANA`, `RUNE_MANA`, `PASSIVE_MANA` in `scripts/weapon/swing_build.gd`; "The staff" in `scripts/player.gd` (`ability_mana`, `_spend_passive`). `tests/staff.gd` and `tests/staff_runes.gd` check it.

### The sword

"sword, whirlwind doest last long enough and ghost blade ability last too long and is quite strong"

- **Whirlwind** spins for up to **six turns** on a full meter, about 1.7 seconds (it was three turns, under a second), and its meter refills in 6 seconds (it was 5). Twice makes it twelve turns.
- **Ghostwield** lasts **8 seconds** (it was 15) and its ghost copies each swing at **35%** (it was half). Wider is about 11 seconds. It still takes 45 seconds to recharge.
- **The dagger and the rapier** ("dagger blade has a weird block were slots used to sit covering half the blade") are whole blades now. The art thread redrew both without the old bronze socket block: at the forge, in the hand and on the tray. The rapier had the same block, so it was done too.

### Abilities start only on a full meter

"make active abilities not be usable until they are fully off cooldown, as getting half a second of use feels bad"

- Press runes already needed a full meter. **Held runes (Whirlwind, Lance) now do too**: you can't start one on a part-filled meter. Letting go early still keeps what is left, so the wait is shorter after a short spin, but the button is not ready again until it is completely full. A press before that shakes the button, as a press on a recharging rune always did, and when it is the mana that is missing the mana bar blinks.

### The forge screen

"i want on the forge screen when u hover a rune, any threads affecting it to show then and what they increase. rather than just a big decription", "if there is a empty seat between threads and runes but the threads still affect it then mkae the ring line light up to the rune they affect still", "if theres two runes of same type being used make a little red X on it to show its not usuable"

- **"What it does" is a list now.** Each rune has one short sentence for what the bare rune does, and under it **one line for each thread that reaches it, saying what that thread adds** ("Twice: then a second crack", "Wider: a longer, wider crack"), with the thread's name lit as it is on the ring. Point at a rune on the ring, or choose its seat with the keys or a controller, and that rune is the one written out. On a full ring only that rune is written out and the others keep to their names. Where even that can't fit (three or four threads on one long rune, on a full ring) it falls back to one joined sentence with the threads' names under it (Claude's choice).
- **The ring's line stays lit across an empty seat** when the threads before it still reach the rune after it. The rules always let threads carry over an empty seat; now the picture shows it.
- **A little red X on a second copy of a rune.** Only one of each rune works now: the first copy on the ring does its job and a second copy does nothing, shows a small red X at its top right, and "What it does" says so ("A second Hook does nothing: only one of each rune works."). Until version 33 a second copy counted like an extra Twice. **This rule is Claude's reading of his sentence**, told to him on the day. Colour is kept for elements everywhere else in the game; this red is his own ask, and the X is a shape too.
- Where it lives: `does_lines`, `thread_names`, `_plan_does`, `_draw_does`, `DOES_PLANS` and the ring's drawing in `scripts/ui/swing_forge.gd`; a thread's own line is `_thread_text()` and the duplicate rule is in `resolve()` (`"dup": true`) in `scripts/weapon/swing_build.gd`. `tests/test_swing_build.gd` freezes the lines and `tests/smoke_forge.gd` checks that they fit their plate for every combination of parts.

### The font

"the games font for text is hard to read on certian numbers etc pick a more readable one"

- The game's text is now **Galmuri** (Lee Minseo; SIL Open Font License, free to ship): Galmuri9 at 10 for text, Galmuri11 Bold at 12 for names, Galmuri7 at 8 for small print. It is a pixel font drawn for these exact sizes, so its digits come out clean (a 3, a 5, a 6 and an 8 are easy to tell apart), where Pixelify Sans at 11 was being squeezed onto a grid it was not drawn for. Damage numbers are Galmuri7 at twice its size and crits the bold at twice its size. The small capital headings and buttons stay in Silkscreen. Which font is Claude's choice.
- The files in `art/fonts/` hold only the Latin letters, digits and signs. `Art.TEXT`, `Art.TEXT_BOLD` and `Art.TEXT_SMALL` in `scripts/art.gd` name them, and each is only ever drawn at its own size or a whole multiple of it. Every "fits its plate" check was rerun with it (the forge, the cave's cards, the lab, the title).

### How the abilities look

"the abilities looks dont really fit the game they are all like neon. can we make them look and fit the game better? still clearly visible ... like for example arrow rain is like purple arrows which isnt realistic"

- The art thread redrew every rune's effect in the game's own materials: steel, bone, linen, stone dust, ember, forge gold and pale verdigris, in place of a loud colour for each rune. Arrow Rain's arrows are real arrows. Quake is pale stone with ember at its foot. Aftershock is dark cracks in the floor with fire in them. Bulwark is a cage of bronze hoops. Nova is a thin ring of forge light. The ghosts (Ghostwield, Spectre) keep their pale verdigris. Twelve button pictures and twenty-five rune gems were recoloured to match, with their shapes kept.
- Eight strips are solid things now (rock, bronze, cracks) and are drawn with normal blending where everything used to be added light; `art/blend.json` lists them and `scripts/art.gd` reads it. Adding bright colours on top of each other was most of what read as neon.
- A staff's crystal matches its bolts: sea glass stays verdigris, the tin-set one is clear rock crystal and the iron-set one is forge gold (it was purple).
- **The forge's Alt pictures** of all 24 runes were taken again from the game with the new art. `tools/take_previews.gd` is the tool that takes them: it uses each rune once in the arena with a scripted player and crops the screen round it.

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/take_previews.gd            # all 24
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/take_previews.gd -- only=quake,hook out=/tmp/stills
```

### The tutorial cave's words

- The cards and hints say the new rules: the staff's card ("Its bolts cost nothing. Runes use mana, the blue bar under your health, which fills slowly."), Whirlwind's ("It starts on a full meter, which fills again when you let go."), Quake's ("Press the button to crack the ground along your aim and hit every enemy on it."), Lance's ("It burns mana until the bar is empty."), and the bow's and staff's first-fight hints no longer speak of a heavy third shot or a burst. The wording is Claude's.
- The title screen's line for the tutorial says "pick a weapon" where it said "pick a sword or a bow".

### Not changed

- The forge guardian, the enemies, the arena's switches and online play's rules. Both online tests pass with the new rules.
- How several threads stack on one rune.
- The single Windows file for testers is still version 17.

## The 19 November combat rules (version 33)

Darren changed four combat rules on 19 November (they are in the Game Bible), and version 33 builds them. Nothing else changed: no new places, enemies or parts.

**Hook is one chain on one enemy.** Press its button and a chain flies at the enemy nearest your aim within 260 px, bites it for three tenths of a swing and drags it all the way to you; it can't act while it is dragged (half a second). Until version 32 chains pulled in every enemy near you, which was too strong. A **boss** (the forge guardian) is too heavy to drag: the chain bites it and pulls *you* 60 px towards it instead, never nearer than arm's length, and "TOO HEAVY!" shows. The training dummy, which nothing moves, does the same. With nobody in reach the chain flies out the way you aim and comes back empty, and the press is spent. The threads follow the Bible's list:

- **Twice** throws a second chain straight after at another enemy, never the same one. With only one enemy about it does nothing.
- **Wider** reaches 416 px.
- **Every Hit** takes half a second off its 4 seconds for each swing that lands.
- **Saved Up** takes 12 seconds to recharge, and the enemy arrives stunned for 2 seconds more. Its bite is no harder.
- **On Dodge** throws a quick chain as each dodge ends, at the nearest enemy, at half strength, and leaves the button's own charge alone.

**Bulwark only blocks.** The shield is up for 3 seconds and stops what comes from an enemy ("BLOCKED!"), but it no longer stuns or shoves whoever hits it. It takes **three hits**: the third breaks it, it bursts ("SHIELD BURST!"), and every enemy within 90 px of you is stunned for 1.5 seconds and pushed back a little. The burst hurts nobody, and a shield that just runs out doesn't burst. Twice: the burst stuns twice as long. Wider: 4 seconds and four hits. Saved Up: 9 seconds and nine hits, 30 to recharge. On Dodge: a dodge puts it up for a second, good for one hit. Every Hit as before.

**Shards leave by the enemy's back.** When your hit lands, three shards burst out of the far side of the enemy, 44 degrees wide, and fly straight for 130 px. They cut whoever stands behind your target for 0.6 of a blade hit, once for each enemy from one burst, and a wall stops them. They no longer jump from enemy to enemy or curve (the Bible keeps curving for a thread called Seeking, which is not built). Twice: two bursts. Wider: they fly 208 px. Every Hit: six shards at half strength. Saved Up: every third hit, three times as strong. On Dodge: a burst from you, the way you aim.

**The "toughest enemy" rule.** Wherever a rune or thread goes for the toughest enemy, that is the one with the **most health left**, and an **elite** in reach always counts as tougher than one that is not. It is in the game as one rule (`Enemy.toughest()` in `scripts/enemy.gd`, with an `elite` flag on every enemy), ready for the runes and threads that need it. **Nothing in the prototype uses it yet**: no rune here picks the toughest enemy (Seeking will) and there are no elites, so this rule changes nothing you can see in version 33.

**What is Darren's and what is Claude's.** Darren's: one chain and one enemy, the boss tug, the thread list, the shield that blocks and then bursts, the straight cone out of the back, the toughest rule. Claude's, for Darren to overturn: every number above (the 60 px tug, three hits, the 90 px burst, three shards in 44 degrees flying 130 px, the 2 second stun), that Hook goes for the enemy nearest your aim, that everything short of a boss is dragged all the way however heavy, that what nothing can move also counts as too heavy, that a Hook that misses is spent, that the shield counts hits (one for each second it was put up for), that a shield running out doesn't burst and the burst does no damage, and that one burst of shards cuts an enemy only once. All the numbers are in the lab, on the Hammer runes and Sword runes pages.

**Where it lives.** `_hook()`, `_bulwark_block()`, `_bulwark_burst()` and `_shards()` in `scripts/player.gd`, with their numbers there (`HOOK_*`, `SHARD_*`) and in `scripts/weapon/swing_build.gd` (`BULWARK_HITS`, `BULWARK_BURST`, `HOOK_SAVED_STUN`). `tests/combat_rules.gd` checks the toughest rule, Shards and Hook; `tests/hammer_runes.gd` checks Bulwark. The three stills the forge shows when you hold Alt on Hook, Bulwark or Shards were taken again from the game, so they show the new rules.

## The forge spirit (version 31, 17 November)

Darren, 16 November: the weapons looked mismatched "with all the wee bits", so "I like the idea of having a forge spirit that holds the runes and that's how the weapon gets empowered ... easier to show on the forge screen also". One spirit for each player, always there but small. Colour is kept for elements, so everything here is told apart by shape and pattern. On 17 November he chose the ringed ember (design B), the name **threads** for bands, and that a seat a part does not give is never drawn, locked or otherwise. Nothing about how the game plays changed: the same runes, the same rules, the same numbers.

**In play**

- A small ember with two rings floats behind your shoulder, on the side away from where you face (facing straight up or down, the side your weapon is not on). It crosses over your head when you turn and stays put through a spin.
- Over it is **one mark for each rune on a button** (none for a passive rune): lit when the rune is ready, half lit for the last third of its recharge, dark while it recharges, with a blink as it comes back. The full signs with their buttons are still under your health bar.
- **Using a rune** makes the spirit flare and the rune's sign leap to the weapon in about a tenth of a second, leaving sparks; the weapon lights for a moment as it lands. The rune itself goes off on the press, as before: the leap is only the picture of it. A rune you hold (Whirlwind, Lance) sends one sign when it starts; Snipe's goes as the shot is loosed.
- The ember glows when any of your runes goes off, passive ones included.
- **Weapons are clean**: no sockets, gems or rings on them, in the hand or on the anvil. (The small pictures of parts in the forge's tray keep their socket holes, because that is where you see how many seats a part gives.)
- In the test arena the spirit is with you from the start. In the tutorial cave it joins you the first time you use the forge, and the smith says a line about it.

**At the forge**

- The weapon stands on the anvil at the left of the niche and the spirit sits in the middle, with a **ring of seats** round it: one seat for every socket the fitted parts give, and never one more. A wooden sword on a wooden grip has one seat; an iron blade on a long grip has five.
- **The order is the old one.** Read the ring from the small stud at the left, the way the little arrows point: the grip's seats come first, along the bottom, then the blade's, up the right and back along the top. An arc behind the seats says which part gives them ("GRIP: 2 SEATS", "BLADE: 2 SEATS"). The Gilded Grip's ruby seat has its own picture.
- A seat holds a rune or a **thread**. A thread changes the next rune round the ring, exactly as a band changed the next rune up the sword, and its line runs along the ring to the next seat in a pattern of its own (two lines for Twice, a line that fans out for Wider, a line of beads for Every Hit, beads that swell for Saved Up, a zigzag for On Dodge). The line is lit while the thread is really changing a rune and dim when there is no rune after it.
- **Three tabs**: the weapon's parts, RUNES and THREADS (the rare Relay is at the foot of the THREADS tab). The part you point at is described under the tray; how to use the screen is written under the ring.
- **What it does**, top right, has a row for each rune. With a full ring only the rune you point at (or the chosen seat's) is written out in full and the others keep to their names, so the words never run off the plate; clicking a row chooses that rune's seat. Under it are the weapon's numbers, one to a line ("Seats 4", "Walk, swinging 80%").
- Drag, click, right-click, the keys and the controller all work as before; up and down step round the seats.

**How it is built.** `scripts/fx/forge_spirit.gd` is the spirit in play: a child of each player that only looks at what the player did (`ability_used`, `ability_charge`, `slot_flash`) and draws; it changes nothing in the game and uses no random numbers, so it cannot upset an online game (`tests/spirit.gd` plays the same presses with and without it and compares). The ring is in `scripts/ui/swing_forge.gd` (`seat_angle()`, `_ring_picture()`, `_draw_ring()`, `thread_pixel()`); the seats' places follow the art's rule in `art/spirit/spirit.json` (seat i of n at 180 - (i + 0.5) * 360 / n degrees). In the code a seat is still a `slot` and a thread is still a `band`: only the words on screen changed. The pictures are in `art/spirit/`, and the 68 weapon parts that had sockets were redrawn without them in `art/swing/`.

Darren chose the spirit's look, the name threads, one spirit a player, and no locked seats. Everything else here is Claude's choice, for Darren to change: where the spirit floats and how it changes sides; that the rune is not held back for the leap; that it joins you at the forge in the cave, and the smith's line; three tabs with Relay under THREADS; the part's words under the tray and the help under the ring; numbers one to a line; "what it does" shortening on a full ring; no colours for groups of fittings; a thread's line lit only when it is at work; the arcs' labels; the big spirit keeping still; leaving out the faint etch marks on the blade; the reworded sentences for threads and parts. Each weapon still keeps its own runes, so the ring changes with the weapon in your hand.

## Slim runes and bands (version 30, 15 November)

Darren, 15 November: "I don't like how the bands and runes look, they are so bulky and take away from the weapons look redesign them". The art thread redrew them the same evening and version 30 puts them in the game. Nothing about how the game plays changed.

- **No bronze boxes.** A socket used to sit in a bronze collar as wide as the weapon, so a sword with four sockets was half boxes. Now the blade, limb, haft or shaft runs unbroken and a socket is a small dark setting let into it.
- **Runes are small gems** in the rune's own colour: round for a passive rune, square for one on a button, a diamond for the rare Relay. A rune that fires flashes white with four sparks.
- **Bands are thin rings** round the weapon, where they used to be thick cuffs.
- **At the forge** an empty socket is no longer blacked out (the black square was bigger than the new setting), and the socket you are on has bolder amber corners with a dark edge, because the menu's thin corners were lost against a pale blade.
- The pictures in the forge's tray lost their collars too. The rune pictures in the tray (the amber stones) are as they were.

198 pictures changed (`art/swing/`: blades, grips, bow limbs and grips, hammer heads and hafts, staff heads and shafts at the forge and in the tray; every rune's forge stone and hand dot; the bands at the forge). Their sizes, the sockets' places and every number in `art/swing/swing_path.json` are the same. The 15 November pictures are kept in the project files (`art/concept-art-3/before-slim/`) and in this repository's history, should the old look be wanted back.

## The swing path

This branch began as a test of the **swing path** (design notes, 3 November), which is why it was first called `swing-path`. The swing path replaces the part grid; `main` still has the grid sword to compare against.

(Since version 31 the screen says **seat** for slot and **thread** for band, and they are shown round the forge spirit, not on the sword. The rules below are unchanged; "above" now means "next round the ring".)

- A sword is a **blade** plus a **grip**. The blade sets the basic three-hit chain (the last hit is the finisher). Grip and blade both have **slots**.
- Slots hold **runes** (effects) or **bands** (modifiers). Read the sword as one line from the bottom of the grip to the tip: a band boosts the next rune above it, bands in a row stack, and a band with nothing above it does nothing.
- Runes are **passive** or **active** (Darren, 10 November). The sword has three of each (11 November), and so has the bow (version 20, see "The bow's runes" above).
  - Passive runes fire by themselves: **Shockwave** (finisher: a rolling wave, a light hit that shoves enemies back), **Shards** (every hit sends a cone of metal shards out of the back of the enemy, into whoever stands behind it; until version 33 they jumped to the closest enemy, then the next), **Weak Point** (the finisher marks the enemy it hit, and the next sword hit on the mark is a big crit).
  - Active runes wait for a button: **Whirlwind** (hold: you spin, cutting everything around you once a turn, walking at three quarters speed) and **Leap** (press: you jump to an enemy and land at your blade's reach from it, with a strike).
  - **Hook left the sword for the hammer** (Darren, 11 November afternoon). Since version 24 it is one of the hammer's three active runes (`"weapon": "hammer"` in `FITTINGS`), so the forge offers it to a hammer and to no sword; `tests/active_runes.gd` still puts it on a sword by hand, because its band rules were first checked there.
  - **Ghostwield** (Darren, 11 November afternoon; version 13) is the third active rune: press its button (R, or B on a controller) and a see-through copy of your own sword appears in your other hand for 15 seconds (**8 seconds since version 34, and the copies are at 35%, not half**: Darren, 21 November). Every swing you make is copied 0.15 seconds later from the other side at half strength, and the copy's hits set your passive runes off again as ghosted effects: the same effect at half strength, drawn in the ghost's blue-violet (a second Shockwave, more Shards). It recharges in 45 seconds, counted from the press; the button shows a bar running down while the ghost is out, and the ghost sword blinks through its last two seconds.
    - Bands, as the Game Bible lists them: **Twice** is two copies of each swing; **Wider** keeps it for 20 seconds; **Every Hit** is the recharge rule below; **Saved Up** makes the copies full strength and the recharge three times as long (135 seconds); **On Dodge** makes the ghost cut along every dodge, through whatever you pass, for half a hit (it doesn't have to be out).
    - My own choices, to change if they feel wrong: only your ordinary swings are copied (not Whirlwind's turns or Leap's strike); a copy shoves and stuns half as hard, can crit, and never spends a Weak Point mark (the mark waits for your own sword); the copies don't count as your hits for Every Hit, and Every Hit gives nothing back to Ghostwield while its ghost is still out; a ghosted Weak Point only marks when you have a mark to spare; a Saved Up passive is copied only on the swing that set it off; two Ghostwield runes are one ghost, the second counting like a Twice (since version 34 a second copy of any rune does nothing: see "Version 34").
    - Where it lives: `ghostwield` in `FITTINGS` and `GHOST_POWER`, `ghost_time()` in `scripts/weapon/swing_build.gd`; the "Ghostwield" section of `scripts/player.gd` (`GHOST_DELAY`, `GHOST_GAP`, `GHOST_SHOVE`, `_summon_ghost`, `_ghost_swing`, `_ghost_dodge_cut`). The ghost sword is your sword's own picture run through `shaders/ghost.gdshader`; its smears, sparks and ghosted rune effects are the real pictures recoloured by `shaders/ghost_glow.gdshader`, so nothing new had to be drawn for them.
- Bands: **Twice** (the rune happens twice, a beat apart), **Wider** (bigger), **Every Hit** (a passive rune fires on every hit instead, at half strength; an active rune comes back sooner with every swing you land), **Saved Up** (every third time, three times as strong) and **On Dodge** (also when you dodge).
- **Active runes, in full.** There are three ability buttons: right click, Q and R, or RB, LB and B (the third button's keys are a first guess, to settle in testing). The first active rune on the sword, reading from the bottom of the grip, takes the first button, the next takes the second and the next the third, so the order on the sword picks the buttons. Two of the same rune share a button and go off together (until version 33; since version 34 only the first copy of a rune works). Each button has a meter, drawn under the health bar with the rune's picture and its button: it fills from the bottom as the rune recharges and gets a bright edge when it can be used.
  - Whirlwind's full meter is three turns (**six since version 34, and it only starts on a full meter**: Darren, 21 November). Each turn spends a third (now a sixth); a tap is one turn, holding keeps turning until the meter is empty or you let go. It refills in 5 seconds (now 6), starting a moment after you stop. A dodge cuts a spin short, and the sword can't swing during one.
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
- The forge screen. **Version 31 laid it out again round the forge spirit; see "The forge spirit" above for how it looks now.** What follows is how it was until version 30 (laid out for the 11 November decisions, so that nothing on it overlaps): at the top left a BACK button, the way out (it says the key that does the same: Esc, or B on a controller), then the screen's name; on the left the parts tray, with the runes in a PASSIVE group (round stones) and an ACTIVE group (square stones with a small button badge); under it a plate with the name and one plain sentence for the part under the cursor; under that how to use the screen. In the middle the sword over the anvil. On the right "what it does", a line per rune, which closes up its rows when a sword has a lot to say; and under it the sword's numbers on a plate of their own (damage, speed, reach, crit, crit hits, slots, walking while swinging). Pointing at a part you could fit shows what it would change beside each number. Holding Alt on a rune shows a still picture of it firing (`art/swing/previews/<rune>.png`, 352 x 240, taken from the game). `tests/smoke_forge.gd` checks that every sentence, every sword's "what it does" and every number with its change fit their plates.
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
scripts/ui/lab_screen.gd             The lab's screen: pages of numbers, the search box, and the arena's Spawn page
scripts/player.gd                    Movement, dodge, the swing chain, runes
scripts/player_input.gd              One player's controls (any device, keyboard, or one controller)
scripts/highlands/highlands.gd       The Greystone Highlands: the land outside the cave
scripts/highlands/world_gen.gd, land_map.gd, land_painter.gd, land_view.gd, veins.gd   Its map from a number, its painting, its ore veins
scripts/highlands/tools.gd, bag.gd   The basic tools (pickaxe, axe, mallet) on their belt, and the materials bag
scripts/camera_rig.gd                The shared camera
scripts/enemy.gd                     Enemy base: being hit, knockback, the arena's enemies
scripts/weapon/swing_build.gd        Blades, grips, fittings and the reading rule
scripts/weapon/sword_art.gd          Draws the sword
scripts/ui/swing_forge.gd            The forge screen: the spirit's ring of seats
scripts/fx/rune_fx.gd                Rune visuals
scripts/fx/forge_spirit.gd           The forge spirit at a player's shoulder: its marks, and the sign that leaps to the weapon
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
