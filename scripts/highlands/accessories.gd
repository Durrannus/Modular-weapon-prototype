extends RefCounted
## The accessories: what each one is, the cells it takes in the Accessory Satchel, and what it does (version 47).
##
## Darren, 23 November 2026: "I want to be able to put accessories in normal inventory with everything else but have
## an accessories equip satchel and when they are put there they are in use. This is where the rows and size
## matters". So an accessory lies in the inventory (bag.gd) like anything else, one to a slot whatever its shape,
## and does nothing there. It works only while it is in the satchel (gear.gd), and there its shape matters.
##
## These are the twelve "found anywhere" accessories Darren approved on 17 November (the Game Bible's table: the
## names, shapes and effects are its own). Their numbers are first guesses for playtesting, and are in the lab.
## The Dowsing Rod is listed but not handed out yet: the land has no buried caches for it to find.
##
## Nothing in here is random, and it knows nothing about the screen.

## cells: [column, row] inside the piece's own box, as it lies unturned (the art's accessories.json agrees).
const ITEMS := {
	"tinkers_thimble": {"name": "Tinker's Thimble", "cells": [[0, 0]], "text": "Your dodge recharges 20% faster."},
	"hearthstone_pebble": {"name": "Hearthstone Pebble", "cells": [[0, 0]], "text": "After 4 seconds without taking or dealing damage, you slowly heal."},
	"ashen_locket": {"name": "Ashen Locket", "cells": [[0, 0]], "text": "Falling leaves a quarter of your Memory behind, not half."},
	"lucky_copper": {"name": "Lucky Copper", "cells": [[0, 0]], "text": "Chests and elites give you about 20% more coins."},
	"banner_pin": {"name": "Banner Pin", "cells": [[0, 0]], "text": "You and teammates near you take 5% less damage."},
	"thorn_charm": {"name": "Thorn Charm", "cells": [[0, 0]], "text": "Enemies that hit you up close take a small hit back."},
	"iron_bracer": {"name": "Iron Bracer", "cells": [[0, 0]], "text": "Enemy hits knock you back half as far."},
	"wayfinders_compass": {"name": "Wayfinder's Compass", "cells": [[0, 0]], "text": "An arrow at the screen's edge points to the nearest place you have not explored."},
	"dowsing_rod": {"name": "Dowsing Rod", "cells": [[0, 0], [0, 1]], "text": "Buried caches glint when you are close. (There are none to find yet.)"},
	"prospectors_sieve": {"name": "Prospector's Sieve", "cells": [[0, 0], [1, 0]], "text": "Each ore you mine has a 1 in 4 chance to give one more."},
	"bandolier": {"name": "Bandolier", "cells": [[0, 0], [0, 1], [0, 2]], "text": "Your active runes recharge 10% faster."},
	"field_rations": {"name": "Field Rations", "cells": [[0, 0], [0, 1], [1, 1]], "text": "15% more health."},
}
## The order lists show them in.
const ORDER := ["tinkers_thimble", "hearthstone_pebble", "ashen_locket", "lucky_copper", "banner_pin", "thorn_charm", "iron_bracer", "wayfinders_compass",
	"dowsing_rod", "prospectors_sieve", "bandolier", "field_rations"]
## The ones that do what they say, and so can be found: every one but the Dowsing Rod.
const POOL := ["tinkers_thimble", "hearthstone_pebble", "ashen_locket", "lucky_copper", "banner_pin", "thorn_charm", "iron_bracer", "wayfinders_compass",
	"prospectors_sieve", "bandolier", "field_rations"]

## The numbers (the lab's page "Inventory and accessories").
static var THIMBLE_DODGE := 1.2       # how much faster the dodge comes back
static var PEBBLE_WAIT := 4.0         # seconds out of the fight before the pebble warms
static var PEBBLE_HEAL := 0.02        # the share of your health it gives back each second
static var LOCKET_SHARE := 0.25       # the share of your carried Memory that stays where you fell
static var LUCKY_COINS := 1.2         # what chests and elites give in coins, times this
static var PIN_SOFTEN := 0.05         # the share taken off every hit
static var PIN_REACH := 190.0         # how near the pin's wearer a teammate must be (world units; a tile is 32)
static var THORN_DAMAGE := 2.0        # about a quarter of a tin sword's hit
static var THORN_REACH := 76.0        # "up close": how near you the enemy that hit you must be
static var BRACER_KNOCK := 0.5        # how far a hit still throws you
static var SIEVE_CHANCE := 0.25
static var BANDOLIER_RUNES := 1.1     # how much faster active runes come back
static var RATIONS_HEALTH := 1.15


static func has(id) -> bool:
	return id is String and ITEMS.has(id)


static func name_of(id: String) -> String:
	return str(ITEMS[id]["name"]) if ITEMS.has(id) else id.capitalize()


static func text_of(id: String) -> String:
	return str(ITEMS[id]["text"]) if ITEMS.has(id) else ""


## Can it be turned? A piece of one cell looks and fits the same whichever way it lies, so it stays as drawn.
static func turns(id: String) -> bool:
	return ITEMS.has(id) and (ITEMS[id]["cells"] as Array).size() > 1


## How many columns and rows its box has, turned `rot` quarter turns clockwise.
static func box(id: String, rot := 0) -> Vector2i:
	var w := 0
	var h := 0
	for c in ITEMS.get(id, {}).get("cells", []):
		w = maxi(w, int(c[0]) + 1)
		h = maxi(h, int(c[1]) + 1)
	return Vector2i(h, w) if posmod(rot, 2) == 1 else Vector2i(w, h)


## The cells it takes inside its own box, turned `rot` quarter turns clockwise: [Vector2i(column, row)].
static func cells(id: String, rot := 0) -> Array:
	var out: Array = []
	var size := box(id, 0)
	for c in ITEMS.get(id, {}).get("cells", []):
		var at := Vector2i(int(c[0]), int(c[1]))
		var w := size.x
		var h := size.y
		for n in posmod(rot, 4):
			# A quarter turn clockwise: what was at (column, row) in a box w wide and h tall is at (h - 1 - row, column).
			at = Vector2i(h - 1 - at.y, at.x)
			var was := w
			w = h
			h = was
		out.append(at)
	return out
