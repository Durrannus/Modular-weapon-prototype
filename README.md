# Modular Weapon Prototype

A Godot prototype for a co-op top-down game about building weapons from parts.

This branch (`swing-path`) has four things to try:

- **The tutorial cave** (Game Plan milestone 4): four rooms, from a shipwreck crate to a forge guardian, for one or two players.
- **Two players on one screen.**
- **Two players online**, one on each computer (see "Playing online" below).
- **The test arena**: the older sandbox with every sword part unlocked.

## How to run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button at the top right).

The title screen asks who is playing and what to play.

### Which version is this?

The bottom-left corner of every screen says **Version 5** (or whatever the number is now). The number goes up by one with every change that is pushed, so after a pull you can see that you have the new one, and two people can check they have the same one.

If it says **Version 5 + changes**, the files in this folder are no longer exactly version 5's: a script or a picture was changed (or a pull stopped half way) since the number was given.

The number lives in `scripts/version.gd`. Don't edit it by hand: see "Checks" below.

## Two players

Both players share one screen. One uses the keyboard and mouse and the other a controller, or both use controllers.

1. On the title screen each player presses their own button to join: **Enter** (or a click) for keyboard and mouse, **A** for a controller. The first to press is player one.
2. Either player then picks **Tutorial cave** or **Test arena**.

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

`tests/online.sh` runs two copies against each other on one computer and compares every checksum (see "Checks").

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD or arrows | Left stick or d-pad |
| Attack | Left click (swings toward the mouse) | X or right trigger (swings the way you face, or aim with the right stick) |
| Keep attacking | Hold left click | Hold X |
| Dodge | Space or Shift | A or left trigger |
| First active rune (hold for Whirlwind) | Right click | RB |
| Second active rune | Q | LB |
| Third active rune | R | B |
| Use (crate, rune, forge, talk) | E or F | A or Y, when the prompt shows |
| Pause menu | Esc | Start (in the cave) |
| Fullscreen on or off | F11 | |
| Test arena only: open the forge anywhere | Tab | Y |
| Test arena only: pause enemy spawning | P | Start |

**At the forge** (the game pauses): drag a part onto a slot, or click a slot and then a part. Right-click or drag off to remove. Keys or controller: up and down pick a slot, left and right pick a part, Q/E or the shoulder buttons change tab, Enter or A fits it, Esc or B leaves. Point at a rune and hold Alt (the left trigger on a controller) to see a picture of it firing. Point at a blade, grip or pommel you could fit and the numbers show what it would change: gains in green with a plus, losses in red with a minus. **Presets:** A, B and C at the top right are three saved swords. Click one (or press C, or Select on a controller) and the whole sword changes to it; click the name beside them to type a name of your own.

## The tutorial cave

It follows the "Tutorial opening" in the Game Plan. You shelter from a storm in a sea cave, the entrance collapses, and the only way out is up.

It opens with a 23 second cutscene: the ship in the storm, the wreck on the rocks, and the cave mouth coming down behind the crew. With two players both are on deck. Press attack or use once and "Press again to skip" appears; press again to skip it. Online, either player's skip skips it for both. The pictures and their numbers (speed, captions, when each sound comes) are in `art/cutscene/intro/`, and `cutscene()` in `scripts/cave/cave_ui.gd` plays them. The wind, thunder and crash are placeholder sounds made in code, like the rest.

The cave has music (version 11). A calm loop starts when the cutscene ends, fight music takes over when the forge guardian wakes (and stays through a knock-out and restart), and the calm loop comes back when the guardian falls. `scripts/music.gd` plays the tracks and fades one into the other; the two Ogg files and the scripts that made them are in `art/music/`, and how loud each sits is `VOLUME` in `scripts/music.gd`. Music is each screen's own, so it never touches the game state and is safe online.

1. **The wreck.** Search the ship's crate for a wooden sword, then fight a few crawlers. They rear up before they bite, and a hit while they rear up stops the bite.
2. **The burrows.** Burrowers travel underground, come up, flash red and lunge in a straight line. Dodge aside and hit them while they lie stunned.
3. **The nest.** A mixed fight. Clearing it lets you take your first rune (Shockwave), which your sword can't use yet.
4. **The forge.** The forge is a colossal sword set in the north wall, with a knight kneeling asleep in front of it. Fit the rune to your sword there and the forge lights, molten metal runs down the floor channels, and the guardian wakes. It has four attacks, each marked on the floor in red before it lands, and a line under its health bar names the attack and says what to do. **Slam**: a circle fills, then the hammer comes down. **Charge**: a lane shows the path, and a charge that hits a wall stuns it. **Quake**: cracks run out from it like the spokes of a wheel, so stand between them. **Rockfall**: rocks drop one after another where you stand, so keep moving, and hit it while it stands still. The first four attacks are one of each, and it never does the same one twice running. Below half health it slams three times in a row, a second ring of cracks fills the gaps of the first, and more rocks fall. The timings are at the top of `scripts/cave/guardian.gd` (`SLAM_WINDUP`, `REST` and so on). Beat it and the old smith is freed: he explains runes (round ones work by themselves, square ones are active and give you an ability on a button once slotted into the sword) and bands, and hands over tin parts. Forge the tin sword and the stairs to the surface open.

Rules:

- After each room everyone is healed and anyone knocked out gets back up. There are no revives mid-fight.
- If everyone is knocked out, that room (or the boss) starts over.
- With two players there are more enemies, the guardian has more health, its rockfall is longer, and it also brings rocks down after each charge.
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
godot --headless --path . --fixed-fps 60 -s tests/active_runes.gd              # Whirlwind, Hook and Leap on their buttons, the bands on them, and Weak Point
godot --headless --path . --fixed-fps 60 -s tests/blade_shapes.gd              # the six blade shapes: reach, what each move hits, each lean, damage a second
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd          # plays the whole cave
godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- players=2 wipe down
godot --path . -s tests/smoke_forge.gd                                         # opens the forge, fires every rune
godot --headless --path . -s tests/version_check.gd                            # the version number was raised if anything changed
```

**Before every push that changes the game**, give it the next version number. This raises the number by one and records which files it belongs to (it does nothing if nothing changed):

```
godot --headless --path . -s tests/version_check.gd -- stamp
```

Online play (needs bash, so Linux, macOS or Git Bash on Windows). Each line runs two copies of the game against each other, plays the whole cave or the arena with scripted players, and checks the two games matched at every checksum:

```
tests/online.sh /path/to/godot                         # the cave, as fast as the computer can
tests/online.sh /path/to/godot fast hard drop=0.1      # with knock-outs and 10% of messages lost
tests/online.sh /path/to/godot fast arena              # the arena: forge, sword changes, pausing enemies
tests/online.sh /path/to/godot real lag=45 drop=0.05   # at normal speed with a slow, lossy connection
tests/online.sh /path/to/godot real host:slow=22       # one computer that can't keep up
```

To skip the title screen while testing: `godot --path . -- cave` or `godot --path . -- arena`.

## This branch: the swing path

This branch tests the **swing path** (design notes, 3 November). It replaces the part grid; `main` still has the grid sword to compare against.

- A sword is a **blade** plus a **grip**. The blade sets the basic three-hit chain (the last hit is the finisher). Grip and blade both have **slots**.
- Slots hold **runes** (effects) or **bands** (modifiers). Read the sword as one line from the bottom of the grip to the tip: a band boosts the next rune above it, bands in a row stack, and a band with nothing above it does nothing.
- Runes are **passive** or **active** (Darren, 10 November). The sword has three of each (11 November).
  - Passive runes fire by themselves: **Shockwave** (finisher: a rolling wave, a light hit that shoves enemies back), **Shards** (every hit sends metal shards jumping to the closest enemy, then the next), **Weak Point** (the finisher marks the enemy it hit, and the next sword hit on the mark is a big crit).
  - Active runes wait for a button: **Whirlwind** (hold: you spin, cutting everything around you once a turn, walking at three quarters speed), **Hook** (press: chains yank nearby enemies in and stun them for a moment) and **Leap** (press: you jump to an enemy and land at your blade's reach from it, with a strike).
- Bands: **Twice** (the rune happens twice, a beat apart), **Wider** (bigger), **Every Hit** (on every hit instead, at half strength), **Saved Up** (every third time, three times as strong) and **On Dodge** (also when you dodge).
- **Active runes, in full.** There are three ability buttons: right click, Q and R, or RB, LB and B (the third button's keys are a first guess, to settle in testing). The first active rune on the sword, reading from the bottom of the grip, takes the first button, the next takes the second and the next the third, so the order on the sword picks the buttons. Two of the same rune share a button and go off together. Each button has a meter, drawn under the health bar with the rune's picture and its button: it fills from the bottom as the rune recharges and gets a bright edge when it can be used.
  - Hook needs a full meter, empties it, and is back in 4 seconds.
  - Whirlwind's full meter is three turns. Each turn spends a third; a tap is one turn, holding keeps turning until the meter is empty or you let go. It refills in 5 seconds, starting a moment after you stop. A dodge cuts a spin short, and the sword can't swing during one.
  - Leap needs a full meter and is back in 3 seconds. It goes for the nearest enemy near where you aim (or else the nearest one) within about 260 pixels, and lands you so that enemy sits just inside your blade's reach: a long blade lands further out than a short one. If you are already closer than that, it hops you back out. As you land the sword cuts once in front of you (one blade hit and a short stun). With nobody in range it jumps a short way where you aim. You can't be hit during the jump. Before 11 November Leap was passive (an attack straight after a dodge) and landed on top of the enemy, which got you hit every time.
  - Bands on an active rune: **Twice** makes Hook pull twice on one press, gives Whirlwind twice the turns and makes Leap go on to a second enemy; **Wider** is a bigger reach or circle; **Saved Up** makes it three times as strong and three times as slow to recharge; **On Dodge** makes a dodge do it too (one pull, one turn or one leap) without touching the meter; **Every Hit** takes it off its button, so it fires by itself on every hit at half strength, as a passive rune.
  - The numbers are at the top of the rune's entry in `FITTINGS` (`scripts/weapon/swing_build.gd`: `recharge`, `turns`, `turn`) and in `scripts/player.gd` (`HOLD_MOVE`, `HOOK_STUN`, `SHOCKWAVE_DAMAGE`, `LEAP_RANGE`, `LEAP_DAMAGE` and their neighbours). To make another rune active, give it `"trigger": "active"` and a `"use"`; a fourth kind of active rune on one sword does nothing, because there are three buttons.
- **Weak Point, in full.** The finisher marks the nearest enemy it hit. One mark at a time: marking another enemy takes the first mark away, and a mark fades after 8 seconds. The next sword swing that hits the mark is a crit worth 2.5 ordinary hits (a pommel's crit damage adds to it), with its own burst and "WEAK POINT!". Only sword swings count, not runes, and in two-player either player's swing can strike it.
  - A small enemy glows icy white all over, and any swing that hits it counts.
  - A big enemy (the brute, the guardian) gets a bright spot on one side of its body instead, never on the side you marked it from. The swing has to reach the spot, and you have to be standing on the spot's side of the enemy (within 50 degrees round), so you step round to it.
  - Bands: **Twice** is two marks at a time (two small enemies, or two spots on a big one); **Wider** is a bigger spot that you can reach from further round; **Every Hit** marks on every hit, with a smaller crit (1.75 hits), and the hit that strikes a mark doesn't put a new one on; **Saved Up** marks on every third finisher with a huge crit (5.5 hits); **On Dodge** marks the enemy your dodge passes closest to.
  - The numbers: `WEAK_CRIT` and `WEAK_DODGE_REACH` in `scripts/player.gd`, `WEAK_BIG`, `WEAK_LIFE`, `WEAK_SPOT` and `WEAK_SIDE` in `scripts/enemy.gd`.
- Second Wind is gone (11 November).
- Rule-benders (the "rare" tab, one per sword): **Relay** hands the bands on the rune below on to the next rune above too. Mirror is parked (it overlapped Twice).
- New parts without art yet show as plain coloured stones, rings and gems.
- Effects are deliberately loud: each rune has its own visual, sound and name pop-up, the slots flash on the sword and in the HUD when they fire, and a finisher that connects gets a screen shake. Identical runes firing together merge into one bigger effect.
- **Test swords (test arena):** you start with Test sword D (Whirlwind, Hook, Leap, Weak Point: one active rune on each of the three buttons, and the new passive). The forge also has Test sword A (Twice, Shockwave, Wider, Hook: two shockwaves and a wide hook), Test sword B (Shockwave, Twice, Wider, Hook: one shockwave and a double, wide hook) and Test sword C (Whirlwind, Hook, Twice, Shockwave). Keys 1, 2, 3 and 4 at the forge load A, B, C and D.
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
- The forge screen (laid out again for the 11 November decisions, so that nothing on it overlaps): on the left the parts tray, with the runes in a PASSIVE group (round stones) and an ACTIVE group (square stones with a small button badge); under it a plate with the name and one plain sentence for the part under the cursor; under that how to use the screen. In the middle the sword over the anvil. On the right "what it does", a line per rune, which closes up its rows when a sword has a lot to say; and under it the sword's numbers on a plate of their own (damage, speed, reach, crit, crit hits, slots, walking while swinging). Pointing at a part you could fit shows what it would change beside each number. Holding Alt on a rune shows a still picture of it firing (`art/swing/previews/<rune>.png`, 352 x 240, taken from the game). `tests/smoke_forge.gd` checks that every sentence, every sword's "what it does" and every number with its change fit their plates.
- **Loadout presets** (Game Bible, 11 November): each player has three saved swords, A, B and C, and can name them. The chosen preset is always the sword in the hand, so every change at the forge is saved to it; clicking another one swaps the whole sword (blade, grip, pommel, runes and bands) in one go, and only at the forge. A preset that has never been used starts as a copy of the sword you are holding. Pointing at a preset shows the sword it holds as pictures; a part you no longer own is greyed out under a padlock and is left off when you switch to it. They live in `scripts/weapon/swing_build.gd` (`preset`, `preset_data`, `preset_names`, `use_preset()`). Not built, because the prototype has nothing to hang them on: the warning when you break down or sell a part that is in a preset (there is no breaking down or selling yet), keeping presets after you close the game (nothing is saved between sessions yet), and typing a name with a controller. Online, presets are each player's own notes: switching sends the new sword to the other computer like any other change at the forge. **T** or the button puts you next to the dummy. The forge glows: the hearth breathes behind the sword, embers drift up, every change is a hammer blow with sparks and a clang, and leaving after changes plays a short "Forged!" finish (white-hot, quench steam, a shine up the blade). Press Tab or click to skip it.
- Art and numbers for all of this are in `art/swing/` (`swing_path.md` explains how the sword is assembled; `swing_path.json` has every slot, pivot and effect strip). Fonts are Silkscreen and Pixelify Sans (OFL), in `art/fonts/`.
- Elemental blades are parked for now. Sounds are placeholders made in code (`scripts/sfx.gd`). The tutorial cave's music is the exception: real tracks in `art/music/`.

Code map:

```
scenes/boot.tscn, scripts/boot.gd    Title screen, then the mode you pick
scripts/ui/title.gd                  Who is playing, what to play
scripts/ui/online_menu.gd            The "Play online" screen: host, join, start
scripts/net/session.gd               Online play: connecting, sending controls, keeping both games in step
scripts/net/net.gd                   Where game code asks "are we online, and which player am I?"
scripts/net/port_opener.gd           Asks the home router to let the other player in
scripts/sim.gd                       Random numbers for anything that decides what happens (the same on both computers)
scripts/game_base.gd                 What both modes share: players, swords, camera, HUD, forge
scripts/cave/cave.gd                 The tutorial cave: map, rooms, stages
scripts/cave/crawler.gd, burrower.gd, guardian.gd   The cave's enemies and boss
scripts/cave/hazard.gd               Timed danger areas: the knight's slam and charge, falling rocks
scripts/fx/warn.gd                   Draws the warning lanes and circles on the floor from the art
scripts/cave/cave_ui.gd              Objective, prompts, boss bar, speech box, cards, the opening cutscene
scripts/main.gd                      The test arena
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
