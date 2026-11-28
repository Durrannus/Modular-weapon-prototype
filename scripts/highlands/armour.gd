extends RefCounted
## Armour (version 71): what each piece is, where it is worn, and how much it guards.
##
## Darren, 28 November 2026: "i want an equipment screen to be visible from inventory too, so you can unequip armour
## and wepons etc, and see your stats". There was no armour in the game, so a decision card asked him, and he chose
## "First scrap armour set now": a helm, a jerkin and boots of goblin scrap, found in chests and sold by Pip, each
## with some defence. Its look on the character comes later; the icons are the Art builder's (equipment-icons-v1).
##
## A piece lies in the inventory (bag.gd) one to a slot, and guards only while it is worn, in its place on the
## inventory's Equipment page (gear.gd keeps what each character wears). Claude's choices, until Darren says
## otherwise: each point of defence takes DEFENCE_SHARE off every hit (never more than DEFENCE_MOST in all); the
## helm guards 2, the jerkin 3 and the boots 1; Pip's prices; two of the same piece do no more than one, so a chest
## gives coins in place of a piece you have.
##
## Nothing in here is random, and it knows nothing about the screen.

## Where armour is worn, top first.
const SLOTS := ["head", "body", "feet"]
const SLOT_NAMES := {"head": "Head", "body": "Body", "feet": "Feet"}

const PIECES := {
	"scrap_helm": {"name": "Scrap helm", "slot": "head", "text": "A dented goblin pot helm with a spike. Worn on your head, it guards you."},
	"scrap_jerkin": {"name": "Scrap jerkin", "slot": "body", "text": "Leather with goblin iron plates on it. Worn on your body, it guards you."},
	"scrap_boots": {"name": "Scrap boots", "slot": "feet", "text": "Leather boots with rusty shin plates. Worn on your feet, they guard you."},
}
## The order lists show them in.
const ORDER := ["scrap_helm", "scrap_jerkin", "scrap_boots"]

## The numbers (the lab's page "Inventory").
static var DEFENCE := {"scrap_helm": 2, "scrap_jerkin": 3, "scrap_boots": 1}
static var DEFENCE_SHARE := 0.03      # each point of defence takes this share off every hit
static var DEFENCE_MOST := 0.6        # and all of it together never more than this
static var PRICE := {"scrap_helm": 30, "scrap_jerkin": 45, "scrap_boots": 25}


static func has(id) -> bool:
	return id is String and PIECES.has(id)


static func name_of(id: String) -> String:
	return str(PIECES[id]["name"]) if PIECES.has(id) else id.capitalize()


static func text_of(id: String) -> String:
	return str(PIECES[id]["text"]) if PIECES.has(id) else ""


## Where it is worn: "head", "body" or "feet" ("" if it is not armour).
static func slot_of(id: String) -> String:
	return str(PIECES[id]["slot"]) if PIECES.has(id) else ""


static func defence_of(id: String) -> int:
	return maxi(int(DEFENCE.get(id, 0)), 0)


## What a hit comes to through this much defence.
static func cut(amount: float, defence: int) -> float:
	return amount * (1.0 - clampf(float(defence) * float(DEFENCE_SHARE), 0.0, clampf(float(DEFENCE_MOST), 0.0, 1.0)))


## How much less a hit does through this much defence, as a whole percent.
static func less(defence: int) -> int:
	return roundi(clampf(float(defence) * float(DEFENCE_SHARE), 0.0, clampf(float(DEFENCE_MOST), 0.0, 1.0)) * 100.0)
