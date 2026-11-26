extends "res://scripts/game_base.gd"
## The Greystone Highlands: the land outside the cave (milestone 8).
##
## The land is a map made from a seed (scripts/highlands/world_gen.gd), painted
## from the approved Highlands art (land_painter.gd, land_view.gd), which you walk
## out onto from the cave mouth. The base clearing and the inner ring are there.
## Since version 40 everyone carries the basic tools (tools.gd): a pickaxe that
## digs the rock and mines the ore in it, an axe that fells pines, and a mallet
## with nothing to build yet. What they win goes in a materials bag (bag.gd).
## Since version 43 the land has its enemies (foes.gd; scripts/foes/): packs of
## Cliff Hounds, Pebble Slingers, the odd Scrap Brute, Goblin Shamans with their
## bats, and an elite of each. Nothing lives near the cave. Since version 44
## there are chests to find, enemies leave Memory when they fall, and the elites
## leave loot and the pieces of the Rusted Warhorn (loot.gd, loot_plan.gd): coins
## and bars go in the bag. Since version 45 Memory is a bar under your health, the
## forge down the cave mouth takes it and raises the SQUAD'S LEVEL, every level is
## a point for each character's role trees, and falling costs something (levels.gd,
## perks.gd, scripts/ui/forge_hall.gd). Since version 46 Pip hangs in a cage at the
## Slinger Roost, the first quests are listed on the screen, Pip keeps a shop at the
## cave mouth once he is free, and the Watchpost's waystone can be mended and
## travelled by (folk.gd, folk_plan.gd, scripts/ui/shop.gd). Since version 47 the
## materials bag is ONE INVENTORY for everything (bag.gd), accessories are found in
## chests and worn in the Accessory Satchel, where their shapes have to fit and only
## what is in it works (gear.gd, accessories.gd), and Tab or a click of the left
## stick opens the screen for both (scripts/ui/pack_screen.gd).
##
## SAVING (version 42; Darren, 21 November: "It works like terraria, player is
## saved"). Every player is a saved CHARACTER and the land is a saved WORLD
## (scripts/save.gd): the character keeps its weapons, runes, threads, presets,
## tool belt, inventory, backpack, satchel and what is worn in it, coins, Memory,
## the Warhorn's pieces and its perks, and goes into any world; the world keeps its
## number, what was dug, mined and felled in it, which of its chests have been
## opened, the squad's level, what the forge holds towards the next, the Memory
## left lying where somebody fell, how things stand with Pip, the quests and the
## waystones, and which of its places the squad has walked into. There is no save button: the
## game saves every AUTOSAVE seconds, when the pause menu opens, when the forge's
## screens close, and when you leave (back to the title, "Quit game", or the
## window closing).
##
## You get here from the title screen by picking a character and a world
## (scripts/ui/save_pick.gd; a new character carries the arena's four test weapons
## and B swaps between them), or by climbing the stairs at the end of the tutorial
## cave (then each player becomes a new character with the weapon they built, in a
## new world).
##
## To see one map again without saving anything, give its number:
##   godot --path . -- highlands seed=123456

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const LandView := preload("res://scripts/highlands/land_view.gd")
const Tools := preload("res://scripts/highlands/tools.gd")
const Foes := preload("res://scripts/highlands/foes.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const Levels := preload("res://scripts/highlands/levels.gd")
const Gear := preload("res://scripts/highlands/gear.gd")
const PackScreen := preload("res://scripts/ui/pack_screen.gd")
const Folk := preload("res://scripts/highlands/folk.gd")
const Charts := preload("res://scripts/highlands/charts.gd")
const FolkPlan := preload("res://scripts/highlands/folk_plan.gd")
const Crown := preload("res://scripts/highlands/crown.gd")
const CrownPlan := preload("res://scripts/highlands/crown_plan.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const ForgeHall := preload("res://scripts/ui/forge_hall.gd")
const CaveUi := preload("res://scripts/cave/cave_ui.gd")
const Music := preload("res://scripts/music.gd")
const Save := preload("res://scripts/save.gd")
const Version := preload("res://scripts/version.gd")

## Seconds of play between two saves the game makes by itself. Short on purpose: a game stopped from the Godot editor's
## Stop button is killed where it stands and cannot save, so this is the most that can ever be lost.
const AUTOSAVE := 60.0
const SAVE_APART := 30.0        # leaving writes the clock too, unless the same save was written less than this long ago
const SAVE_NOTE := 2.0          # how long the word "Saved" stays on the screen
const NOTE_Y := 21.0            # where it is: top middle, under the squad's level

var world_seed := 0             # 0 = a new one every time
var carry := {}                 # from the cave: {builds: [a weapon each], owned: [part ids each], spirit: [bool each]}
var map: LandMap
var land
var snowfall                    # the snow falling round the Hound Den, and where the snow lies (snow.gd)
var tools                       # the tool belts and the materials bags (tools.gd)
var foes                        # the land's enemies (foes.gd)
var with_foes := true           # false: the land is empty of enemies (the tests of other things)
var loot                        # chests, drops, coins and Memory (loot.gd)
var chest_plan: Array = []      # where this land's chests stand and what is in them (loot_plan.gd)
var levels                      # Memory, the squad's level, the role trees' perks, what falling costs (levels.gd)
var hall                        # the forge's screen: give your Memory, the role trees (scripts/ui/forge_hall.gd)
var gear                        # the Accessory Satchel and what is worn in it (gear.gd); null online
var packs                       # the inventory's screen (scripts/ui/pack_screen.gd); null online
var folk                        # Pip, his cage, the quests and the waystone (folk.gd); null online
var charts                      # the small map in the corner and the whole map on M (charts.gd); null online
var folk_plan := {}             # where they stand on this land (folk_plan.gd)
var crown                       # Rattlecrown's fight, the Scrapyard gate and the Rusted Warhorn (crown.gd); null online
var crown_plan := {}            # where his Throne Room, the way to it and the gate are on this land (crown_plan.gd)
var ui
var owned: Array = []           # per player: the part ids they can use at the forge (null = all of them)
var interactables: Array = []   # [{at, radius, text, lift, can: Callable(i), use: Callable(i), words: Callable(i) or none}]
var was_busy := false
var welcome := true             # show the arrival card (tests switch it off)
var music                       # the calm cave tune, standing in until the Highlands have one of their own
var characters: Array = []      # each player's saved character (scripts/save.gd); {} = that player is not saved
var world_save := {}            # the saved world; {} = this land is not saved (the tests, and `-- highlands`)
var swaps: Array = []           # per player: carries all four weapons, and B swaps between them
var new_world := false          # this world has never been played before
var relaid := false             # this world was saved on a land that is made differently now: it was laid out again
var unreadable: Array = []      # what a character's save held that this game could not read, in words
var save_clock := 0.0           # seconds of play since the game last saved by itself
var save_note := 0.0            # seconds the word on the screen still has
var save_word := ""             # "Saved", or what went wrong
var save_failed := false
var saves_written := 0          # how many files have been written (the tests count them)
var note_panel: Control
var _saved_text := {}           # a save's name -> what was last written for it, without the clock
var _saved_at := {}             # a save's name -> when


func _ready() -> void:
	_rules()
	Art.solid_backings = true          # (the HUD's backings are solid over the Highlands' busy ground: version 66)
	randomize()
	if not Net.online():
		Sim.shuffle()
	if not world_save.is_empty():
		world_seed = int(world_save.get("seed", 0))
		new_world = bool(world_save.get("unsaved", false)) or world_seed <= 0
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("seed="):
				world_seed = int(a.substr(5))
	if world_seed <= 0:
		world_seed = 100000 + randi() % 900000     # six figures: easy to read out
	map = WorldGen.make(world_seed)
	# Where the chests stand is worked out from the land as it was made, before a save's digging and felling are
	# done to it again: the same world always has the same chests in the same places.
	var groups := FoePlan.make(map)
	chest_plan = LootPlan.make(map, groups)
	folk_plan = FolkPlan.make(map, groups, chest_plan)
	# The Scrapyard in the outer ring, its four rooms and Rattlecrown's Throne Room at the top, are cut into the land
	# here, every time it is opened: after the plans, which read the land as it was made, and before a save's digging
	# is done to it again. No save holds them. Its two side rooms' chests join the land's. (Online, which is on hold,
	# has no Rattlecrown.)
	if not Net.online():
		crown_plan = CrownPlan.make(map)
		CrownPlan.stamp(map, crown_plan)
		if crown_plan.get("ok", false):
			chest_plan.append_array(crown_plan["chests"])
	# The snowy section round the Hound Den (version 62): its mouth, trodden ground and paw prints are put on the land
	# the same way, clear of the chests. The snow itself is only paint: nothing on the land changes.
	var chest_tiles: Array = []
	for c in chest_plan:
		if c.get("tile") is Vector2i:
			chest_tiles.append(c["tile"])
	Snow.stamp(map, chest_tiles)
	if not world_save.is_empty() and not new_world:
		# The land is made again from its number, and then what was dug, mined and felled is done to it again. If
		# this game makes the land differently from the one that saved it, the old changes would not fit: they are
		# left off (the pick screen said so before the world was opened).
		if int(world_save.get("land", 0)) == WorldGen.GEN:
			map.apply_changes(world_save)
		else:
			relaid = true
	_make_world()
	land = LandView.new()
	land.map = map
	land.world = world
	land.rig = rig
	add_child(land)
	snowfall = Snow.new()
	snowfall.name = "Snowfall"
	snowfall.map = map
	snowfall.rig = rig
	add_child(snowfall)
	_add_players(map.spawn * TILE)
	land.players = players
	for i in players.size():
		players[i].face_dir = Vector2.DOWN
		players[i].auto_respawn = true
		players[i].spawn_point = players[i].position
		players[i].light.enabled = false      # the small light everyone carries in the cave: it is daylight out here
	_arm()
	tools = Tools.new()
	tools.game = self
	tools.map = map
	tools.land = land
	tools.players = players
	add_child(tools)
	for p in players:
		p.input.tools = true                  # F and the left trigger use the tool, C and Select pick the next
	foes = Foes.new()
	foes.game = self
	foes.map = map
	foes.world = world
	foes.players = players
	foes.on = with_foes
	add_child(foes)
	foes.setup()
	if crown_plan.get("ok", false):
		# Who lives in the Scrapyard's rooms joins the land's groups. They wake only while somebody is inside its walls.
		for g in crown_plan["groups"]:
			var its: Dictionary = (g as Dictionary).duplicate()
			its["id"] = foes.plan.size()
			foes.plan.append(its)
		var yard: Rect2i = crown_plan["yard"]
		foes.yard = Rect2(Vector2(yard.position) * TILE, Vector2(yard.size) * TILE)
		# The Crane Yard's scrap piles, for its slingers to throw from behind: [their middle (world units), half wide].
		for c in crown_plan["cover"]:
			foes.cover_extra.append([((c[0] as Vector2) - Vector2(0, 6)) * Art.PIXEL, float(c[1]) * Art.PIXEL])
	loot = Loot.new()
	loot.game = self
	loot.map = map
	loot.world = world
	loot.players = players
	loot.tools = tools
	loot.nav = foes.nav
	add_child(loot)
	loot.setup(chest_plan)
	if not world_save.is_empty() and not new_world and not relaid:
		loot.set_opened(world_save.get("chests"))
		loot.set_left(world_save.get("chest_left"))
	if not world_save.is_empty() and not new_world:
		loot.set_blanks_found(world_save.get("blanks"))
	levels = Levels.new()
	levels.game = self
	levels.map = map
	levels.players = players
	levels.loot = loot
	add_child(levels)
	if not world_save.is_empty() and not new_world:
		# The squad's level is the world's whatever has become of its land. The Memory that lay where somebody fell
		# stays only if the land is still the land they fell on.
		var kept := world_save.duplicate()
		if relaid:
			kept.erase("markers")
		levels.set_world_data(kept)
	# The Accessory Satchel. (Online, which is on hold, has no accessories yet.)
	if not Net.online():
		gear = Gear.new()
		gear.game = self
		gear.map = map
		gear.players = players
		gear.tools = tools
		gear.levels = levels
		add_child(gear)
		if not world_save.is_empty() and not new_world and not relaid:
			gear.set_world_data(world_save)
	# Pip, his cage, the quests and the waystone. (Online, which is on hold, has none of them yet.)
	if not Net.online():
		folk = Folk.new()
		folk.game = self
		folk.map = map
		folk.world = world
		folk.players = players
		folk.tools = tools
		folk.loot = loot
		folk.foes = foes
		add_child(folk)
		folk.setup(folk_plan)
		if not world_save.is_empty() and not new_world:
			folk.set_world_data(world_save)
		# Rattlecrown: his gate, his throne, the horn and the fight.
		crown = Crown.new()
		crown.game = self
		crown.map = map
		crown.world = world
		crown.players = players
		crown.tools = tools
		crown.loot = loot
		crown.foes = foes
		crown.folk = folk
		add_child(crown)
		crown.setup(crown_plan)
		if not world_save.is_empty() and not new_world:
			crown.set_world_data(world_save)
	# Which free ground hangs together, for the enemies' way-finding: worked out now, with every gate and barred door
	# in place, while the world is still being opened, and not in the middle of the first fight (it takes a tenth of
	# a second on a land this big).
	if not foes.nav.labels_ok:
		foes.nav.labels()
	# The map: the small one in the corner, the whole one on M (version 56). (Online, on hold, has none yet.)
	if not Net.online():
		charts = Charts.new()
		charts.game = self
		charts.map = map
		charts.players = players
		charts.rig = rig
		charts.can_swap = can_swap
		charts.nav = foes.nav
		if not world_save.is_empty() and not new_world and not relaid:
			charts.set_world_data(world_save)
		add_child(charts)
		if folk != null:
			folk.chart = charts
	rig.set_limits(Rect2(Vector2(map.region.position) * TILE, Vector2(map.region.size) * TILE), 0.0)
	rig.snap()
	land.prime()
	# The cave mouth, set into the hill north of the clearing.
	var mouth_feet := Vector2(map.mouth.x * 16 + 8, (map.mouth.y + 1) * 16)
	land.stand("cave_mouth", mouth_feet)
	interactables.append({"at": mouth_feet * Art.PIXEL + Vector2(0, 26), "radius": 74.0, "lift": 86.0, "text": "Go down to the forge",
		"words": func(i): return forge_words(i), "can": func(_i): return true, "use": func(i): _use_forge(i)})
	_make_ui()
	hud.mode = "highlands"
	hud.under_bar = Levels.BAR_DROP           # the Memory bar is right under the health bar
	hud.under_more = levels.bar_extra         # (and a Warden's Payback meter under that)
	hall = ForgeHall.new()
	hall.levels = levels
	hall.folk = folk
	hall.loot = loot
	hall.weapon_name = func(i): return str(builds[i].weapon()) if i >= 0 and i < builds.size() else "weapon"
	hall.players = players
	add_child(hall)
	hall.weapons.connect(_open_weapons)
	hall.closed.connect(_hall_closed)
	hall.travel.connect(_hall_travel)
	if gear != null:
		packs = PackScreen.new()
		packs.game = self
		packs.gear = gear
		packs.tools = tools
		packs.loot = loot
		packs.players = players
		add_child(packs)
		packs.closed.connect(_packs_closed)
	music = Music.new()
	add_child(music)
	music.play("cave_calm", 4.0)
	hud.show_weapon = can_swap
	build_menu.hotkey = false
	build_menu.sandbox = false
	pause_menu.pad_start = true
	ui = CaveUi.new()
	add_child(ui)
	ui.cam = rig.camera
	ui.hint_w = Crown.TIP_W                   # a tip stays between the corners' bars and the quests
	ui.covered = _covered
	_load_hands()
	_make_note()
	pause_menu.opened.connect(save_now)
	pause_menu.quitting.connect(save_now.bind(true))
	if welcome:
		ui.fade = 1.0
		ui.fade_color = Color(1.0, 0.98, 0.9)
		ui.fade_in(1.2)
		if relaid:
			ui.card(str(world_save.get("name", "This world")), "This world was saved by an older version of the game, which made the land differently. %s\nIts land has been laid out again from its number: what was dug and felled in it before is gone, and its chests are full again.\nYour character has kept everything: inventory, satchel, threads and coins. So has the squad's level.\n\nWorld number %d" % [WorldGen.NEWS, world_seed])
		elif world_save.is_empty() or new_world:
			ui.card("The Greystone Highlands", welcome_text())
	# A new character and a new world are on the disk from the first moment, not from the first autosave. A save
	# that was just read is not written again until something in it changes, or until you leave.
	for pair in _saves_now():
		if not (pair[1] as Dictionary).get("unsaved", false):
			_saved_text[str(pair[1].get("id", ""))] = _meat(pair[1])
	save_now(false, false)
	if not unreadable.is_empty():
		save_word = "Some of a saved weapon could not be read: " + ", ".join(unreadable)
		save_failed = true
		save_note = 8.0


## What the card you arrive to says.
func welcome_text() -> String:
	var pad: bool = players[0].input.on_pad()
	var kept := "A new land, laid out differently every time."
	if not world_save.is_empty():
		kept = "A new land. The game saves by itself: your character, and what you dig and fell here."
	return "%s\nYou carry a pickaxe, an axe and a mallet. %s uses the one you have picked, on what you aim at. %s picks the next. %s opens your inventory.\nThe hills round the cave are safe. Farther out, hounds and goblins have made the land theirs, and there are chests to find.\nWhat you kill, mine and chop gives Memory. Take it down the cave mouth to your forge: it raises the squad's level.\n\nWorld number %d" \
		% [kept, "The left trigger" if pad else "F", "Select" if pad else "C", "A click of the left stick" if pad else "Tab", world_seed]


## Leaving, whichever way (back to the title, or the game closing): everything is saved. And the players' controls
## go on to other places (back down to the cave): there, F and the left trigger are not tools.
## Version 56, after Darren's first long play (24 November): "player is far too big, bigger than the walls atm",
## "damage is also too high across the board and character speed seems quite fast so kiting is easy". Claude's
## reading and numbers: the player drawn three quarters the size (their swing reaches as much less, their body
## takes up as much less room), walking three quarters as fast (a hound running at you now catches you), and
## every blow doing 70% of what it did, the squad's and the enemies' alike (traps and falls too), so fights last
## longer both ways. Here only: the cave and the arena keep what they had.
static var PLAYER_SIZE := 0.75
static var PLAYER_PACE := 0.75
static var DAMAGE_DEALT := 0.7
static var DAMAGE_TAKEN := 0.7


func _rules() -> void:
	PlayerScript.SIZE = PLAYER_SIZE
	PlayerScript.PACE = PLAYER_PACE
	PlayerScript.HURT_SHARE = DAMAGE_TAKEN
	SwingBuild.DAMAGE_SHARE = DAMAGE_DEALT


func _exit_tree() -> void:
	Art.solid_backings = false
	PlayerScript.SIZE = 1.0
	PlayerScript.PACE = 1.0
	PlayerScript.HURT_SHARE = 1.0
	SwingBuild.DAMAGE_SHARE = 1.0
	save_now(true, false)
	for p in players:
		if is_instance_valid(p) and p.input != null:
			p.input.tools = false


## What everyone holds. A saved character: what its save says. Straight from the cave: the weapon they built there.
## A new character made on the pick screen (and anyone who is not saved): the arena's test weapons, all four.
func _arm() -> void:
	var got: Array = carry.get("builds", [])
	while characters.size() < players.size():
		characters.append({})
	for i in players.size():
		var c: Dictionary = characters[i]
		if c.get("weapons") is Dictionary:
			for problem in builds[i].from_save(c["weapons"]):
				unreadable.append(str(problem))
			builds[i].changed.emit()
			var parts = c.get("owned")
			owned.append((parts as Array).filter(func(id): return id is String) if parts is Array else null)
			players[i].with_spirit = bool(c.get("spirit", true))
			swaps.append(bool(c.get("swap", false)))
		elif i < got.size() and SwingBuild.valid_data(got[i]):
			builds[i].set_data(got[i])
			builds[i].changed.emit()
			owned.append((carry.get("owned", []) as Array)[i] if i < (carry.get("owned", []) as Array).size() else null)
			players[i].with_spirit = bool((carry.get("spirit", []) as Array)[i]) if i < (carry.get("spirit", []) as Array).size() else true
			swaps.append(false)
		else:
			builds[i].load_test("D")
			builds[i].stowed["bow"] = SwingBuild.TEST_BOW.duplicate(true)
			builds[i].stowed["hammer"] = SwingBuild.TEST_HAMMER.duplicate(true)
			builds[i].stowed["staff"] = SwingBuild.TEST_STAFF.duplicate(true)
			owned.append(null)
			swaps.append(true)
	can_swap = true in swaps


## Only somebody who carries all four weapons swaps between them.
func swap_weapon(i: int, to := "") -> void:
	if i >= 0 and i < swaps.size() and swaps[i]:
		super.swap_weapon(i, to)


## Each saved character's tool belt, picked tool, inventory and backpack, its coins, Memory and kept things, its
## perks, and its satchel with what is worn in it (last: a satchel's size can hang on a perk, and what does not fit
## goes into the inventory).
func _load_hands() -> void:
	for i in players.size():
		if not characters[i].is_empty():
			tools.set_hand_data(i, characters[i])
			loot.set_purse_data(i, characters[i])
			levels.set_perks_data(i, characters[i])
			if gear != null:
				gear.set_kit_data(i, characters[i])


# --- Saving -----------------------------------------------------------------------

## Player i's character as it is at this moment, for its save.
func _character_now(i: int) -> Dictionary:
	var c: Dictionary = characters[i]
	c["weapons"] = builds[i].to_save()
	c["owned"] = (owned[i] as Array).duplicate() if owned[i] is Array else null
	c["spirit"] = bool(players[i].with_spirit)
	c["swap"] = bool(swaps[i])
	c.merge(tools.hand_data(i), true)
	c.merge(loot.purse_data(i), true)
	c.merge(levels.perks_data(i), true)
	if gear != null:
		c.merge(gear.kit_data(i), true)
	if not world_save.is_empty():
		c["world"] = str(world_save.get("id", ""))
	c["game"] = Version.NUMBER
	return c


## The world as it is at this moment, for its save: its number, what has been changed on its land, which of its
## chests have been opened, the squad's level, what the forge holds, the Memory lying where somebody fell, and how
## things stand with Pip, the quests and the waystone.
func _world_now() -> Dictionary:
	world_save["seed"] = world_seed
	world_save["land"] = WorldGen.GEN
	world_save.merge(map.changes(), true)
	world_save["chests"] = loot.opened_ids()
	world_save["chest_left"] = loot.left_data()
	world_save["blanks"] = loot.blanks_found
	world_save.merge(levels.world_data(), true)
	if gear != null:
		world_save.merge(gear.world_data(), true)
	if folk != null:
		world_save.merge(folk.world_data(), true)
	if crown != null:
		world_save.merge(crown.world_data(), true)
	if charts != null:
		world_save.merge(charts.world_data(), true)
	world_save["game"] = Version.NUMBER
	return world_save


## Every save in play, as it is at this moment: [[Save.WORLDS, the world], [Save.CHARACTERS, a character] ...].
func _saves_now() -> Array:
	var out: Array = []
	if not world_save.is_empty():
		out.append([Save.WORLDS, _world_now()])
	for i in mini(characters.size(), players.size()):
		if not characters[i].is_empty() and is_instance_valid(players[i]):
			out.append([Save.CHARACTERS, _character_now(i)])
	return out


## A save as it would be written, without its clock (when it was last played, and for how long): two of these are
## the same when nothing that matters has changed.
static func _meat(d: Dictionary) -> String:
	var meat := d.duplicate()
	meat.erase("played")
	meat.erase("seconds")
	return Save.text_of(meat)


## Writes the world and everybody's character: each one only if something in it has changed since it was last
## written, so the one backup is never pushed out by a copy of the same thing. `leaving` (back to the title, the
## game closing) also writes the clock, how long it has been played, unless that save was written a moment ago.
## Returns false if something could not be written (the screen then says so, and the file that was there is left
## as it was).
func save_now(leaving := false, tell := true) -> bool:
	if Net.online() or tools == null or loot == null or levels == null or map == null:
		return true
	var now := Time.get_unix_time_from_system()
	var wrote := false
	var failed := false
	for pair in _saves_now():
		var d: Dictionary = pair[1]
		var id := str(d.get("id", ""))
		var text := _meat(d)
		var same: bool = _saved_text.get(id, "") == text
		if same and not (leaving and now - float(_saved_at.get(id, 0.0)) >= SAVE_APART):
			continue
		d["played"] = now
		if Save.write(pair[0], d):
			_saved_text[id] = text
			_saved_at[id] = now
			saves_written += 1
			wrote = true
		else:
			failed = true
	save_clock = 0.0
	if failed:
		save_word = "Could not save: the disk may be full"
		save_failed = true
		save_note = 6.0
	elif wrote and tell:
		save_word = "Saved"
		save_failed = false
		save_note = SAVE_NOTE
	return not failed


## The clock: how long each save has been played, and the autosave.
func _process(delta: float) -> void:
	if note_panel != null and (save_note > 0.0 or note_panel.visible):
		save_note = maxf(save_note - delta, 0.0)
		note_panel.visible = save_note > 0.0
		note_panel.queue_redraw()
	if world_save.is_empty() and characters.all(func(c): return (c as Dictionary).is_empty()):
		return
	for d in [world_save] + characters:
		if not (d as Dictionary).is_empty():
			d["seconds"] = float(d.get("seconds", 0.0)) + delta
	save_clock += delta
	if save_clock >= AUTOSAVE:
		save_now()


## The window is being closed: save before the game goes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now(true, false)


func _forge_done(i: int) -> void:
	super._forge_done(i)
	save_now()


## One word at the top of the screen, under the squad's level, when the game has saved (or a sentence if it could not).
func _make_note() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	note_panel = Control.new()
	note_panel.size = Vector2(640, 360)
	note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_panel.visible = false
	layer.add_child(note_panel)
	note_panel.draw.connect(_draw_note)


func _draw_note() -> void:
	if save_note <= 0.0 or save_word == "":
		return
	# (While Rattlecrown's bar is up, the word "Saved" is left out: the bar has its place. A save that failed is said.)
	if crown != null and crown.fighting() and not save_failed:
		return
	var f := Art.font("Silkscreen-Regular") if not save_failed else Art.font(Art.TEXT)
	var size := 8 if not save_failed else Art.TEXT_SIZE
	var words := save_word.to_upper() if not save_failed else save_word
	var w := ceilf(f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var alpha := clampf(save_note / 0.4, 0.0, 1.0)
	var x := floorf((640.0 - w) * 0.5)
	note_panel.draw_rect(Rect2(x - 6.0, NOTE_Y, w + 12.0, 14.0), Color(0.098, 0.078, 0.165, 0.6 * alpha))
	note_panel.draw_string(f, Vector2(x, NOTE_Y + 10.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Color("#f06a40") if save_failed else Color("#8ba688"), alpha))


## The forge is down the stairs. Until the base is built, using the cave mouth opens the forge's screen where you
## stand (scripts/ui/forge_hall.gd): give your Memory, the role trees, and the way on to the weapons and runes.
## (Online, which is on hold, there are no levels yet: the cave mouth opens the weapons as it always did.)
func _use_forge(i: int) -> void:
	if Net.online():
		_open_weapons(i)
	elif not hall.is_open and not build_menu.is_open:
		hall.open(i)


## The forge screen there has always been: weapons, runes and threads.
func _open_weapons(i: int) -> void:
	if not Net.online() or i == Net.me():
		build_menu.owned = owned[i]
	players[i].with_spirit = true
	open_forge(i)


## The forge's screen has closed: what was given and learnt there is saved. (If it closed to open the weapons, the
## save comes when those close.)
func _hall_closed(_i: int) -> void:
	_swallow_presses()
	if not build_menu.is_open:
		save_now()


## Is a controller's left stick clicked in?
func _left_stick_down() -> bool:
	for device in 8:
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK):
			return true
	return false


## Is a screen open over the game (an inventory or a chest's, the whole map, the forge, Pip's shop)? Then the cave
## UI draws no "press E" prompt, which would show under its panel (the Overseer's note on version 60).
func _covered() -> bool:
	return (packs != null and packs.any_open()) or (charts != null and charts.is_open) or (hall != null and hall.is_open) \
		or (folk != null and folk.shop != null and folk.shop.is_open)


## Somebody has closed their inventory: what was moved is saved.
func _packs_closed(_i: int) -> void:
	_swallow_presses()
	save_now()


## Numbers were changed in the lab: what the accessories do and how big everything is follow at once.
func lab_changed() -> void:
	_rules()           # (the Highlands' own: the player's size and pace, and how hard every blow lands)
	for p in players:
		if is_instance_valid(p):
			p.resized()
	super.lab_changed()
	if gear != null:
		for i in players.size():
			gear.settle(i)
			gear.refresh(i)


## The forge's screen sent the squad off by waystone (folk.gd does the going).
func _hall_travel(i: int) -> void:
	_swallow_presses()
	if folk != null:
		folk.go_to_stone(i)


## What the cave mouth's prompt says to player i: it tells them when they have something to do down there.
func forge_words(i: int) -> String:
	if levels == null or Net.online():
		return "Go down to the forge"
	if levels.points(i) > 0:
		return "Go down to the forge: %s to spend" % ("1 point" if levels.points(i) == 1 else "%d points" % levels.points(i))
	if levels.share(i) >= 1.0:
		return "Go down to the forge: you carry enough for a level"
	if loot != null and loot.any_blank(i):
		return "Go down to the forge: a blank stone to infuse"
	return "Go down to the forge"


## Somebody fell: half the Memory they carried stays where they fell, and some of their coins are gone (levels.gd).
func _on_player_down(p) -> void:
	if levels != null and not Net.online():
		levels.fell(players.find(p), p.fell_at)


## A hound answering its pack leader's howl (scripts/foes/hound.gd asks the game for it).
func call_foe(by, kind: String):
	return foes.call_in(by, kind)


func _swap_key_player() -> int:
	for i in players.size():
		var inp = players[i].input
		if inp.kind == "pad" and Input.is_joy_button_pressed(inp.device, JOY_BUTTON_RIGHT_STICK):
			return i
		if inp.kind == "kbm" and Input.is_physical_key_pressed(KEY_B):
			return i
	return 0


func _physics_process(delta: float) -> void:
	var pressed := false
	for p in players:
		var inp = p.input
		if inp.attack_pressed or inp.interact_pressed or (inp.using_pad and inp.dash_pressed):
			pressed = true
	ui.advance(pressed, delta)
	_tick_players()
	var busy: bool = ui.busy()
	for i in players.size():
		var p = players[i]
		p.frozen = busy or is_forging(i) or (folk != null and folk.travelling())
		if was_busy and not busy:
			p.need_release = true
	was_busy = busy
	if packs != null:
		packs.allowed = not busy and not (folk != null and folk.travelling()) and not hall.is_open and not build_menu.is_open
	if charts != null:
		charts.allowed = not busy and not (folk != null and folk.travelling()) and not hall.is_open and not build_menu.is_open
		charts.tick(delta)
	tools.tick(delta, busy)
	foes.tick(delta)
	loot.tick(delta)
	levels.tick(delta)
	if gear != null:
		gear.tick(delta)
	if folk != null:
		folk.tick(delta)
	if crown != null:
		crown.tick(delta)
	ui.prompts = []
	for p in players:
		p.interact_ready = false
	if busy:
		return
	if not Net.online():
		if can_swap and Input.is_action_just_pressed("swap_weapon"):
			swap_weapon(_swap_key_player())
		# (The lab's other button, a click of the left stick, is the inventory's here: the lab is on L and in the
		# pause menu.)
		if Input.is_action_just_pressed("lab") and not _left_stick_down() and lab_screen != null and not lab_screen.just_closed():
			open_lab()
	_update_interactions()


func _update_interactions() -> void:
	var shown := {}
	for i in players.size():
		var p = players[i]
		if p.is_down:
			continue
		var best := -1
		var best_d := INF
		for k in interactables.size():
			var it: Dictionary = interactables[k]
			var d: float = p.global_position.distance_to(it["at"])
			if d < float(it["radius"]) and d < best_d and it["can"].call(i):
				best = k
				best_d = d
		if best < 0:
			continue
		var it: Dictionary = interactables[best]
		p.interact_ready = true
		var pad: bool = p.input.using_pad
		if not shown.has(best) and (not Net.online() or i == Net.me()):
			shown[best] = true
			var words: String = it["words"].call(i) if it.has("words") else it["text"]
			ui.prompts.append({"at": it["at"] - Vector2(0, float(it.get("lift", 0.0))), "text": words, "pad": pad, "side": 0})
		if p.input.interact_pressed or (pad and p.input.dash_pressed):
			it["use"].call(i)
			return


func net_state() -> Array:
	return super.net_state() + [world_seed, ui.busy()]
