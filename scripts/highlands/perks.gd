extends RefCounted
## The four role trees and their perks (version 45), as the Game Bible has them under "Role trees (agreed 12 Nov)".
## Darren approved the trees on 12 November and named the Delver capstone himself. Every perk's words here are the
## Bible's own.
##
## The rules, from the Bible:
##   - Eight perks a tree, one point each. One point for every level of the squad.
##   - The shape: one signature perk, three rows of two, one capstone. A row opens once you own one perk from the
##     row above. The capstone needs 6 points in its tree first.
##   - One capstone per character.
##   - The level belongs to the world, the tree choices to the character.
##
## Claude's choice, until Darren says otherwise: a character who walks into a world whose forge is at a lower level
## than the perks they have learnt keeps them all, but only the first so many are AWAKE there, in the order they
## were learnt (Darren, 21 November, of threads and parts: "the world's forge decides what is awake").
##
## NOT EVERYTHING IS BUILT. Version 45 builds the four signature perks, version 53 the rest of the Striker's tree,
## version 54 the rest of the Warden's (BUILT below). The others are in the tree to be read, and say that they are not built yet: nobody can spend a
## point on a perk that does nothing.

const TREES := ["warden", "striker", "mender", "delver"]
const TREE_NAMES := {"warden": "Warden", "striker": "Striker", "mender": "Mender", "delver": "Delver"}
const TREE_DOES := {"warden": "protect", "striker": "damage", "mender": "support", "delver": "mining, forge, finds"}
const TREE_WORD := {"warden": "Challenged", "striker": "Open", "mender": "Sparks", "delver": "Shimmer"}

## Which row each of a tree's eight places is in: the signature, three rows of two, the capstone.
const ROWS := [0, 1, 1, 2, 2, 3, 3, 4]
const ROW_NAMES := ["Signature", "Row 2", "Row 3", "Row 4", "Capstone"]
const CAPSTONE := 4
const CAPSTONE_NEEDS := 6

const TREE := {
	"warden": ["challenge", "unmoved", "bodyguard", "payback", "tempered", "shoulder_charge", "plate", "unbroken"],
	"striker": ["punish", "close_call", "flank", "keep_the_chain", "sharp", "kill_rush", "expose", "execution"],
	"mender": ["kindle", "helping_hand", "banked_warmth", "hearth", "drift", "bolster", "flare", "rekindle"],
	"delver": ["ore_sense", "vein_breaker", "recall", "field_anvil", "laden", "second_look", "deep_pockets", "forge_prophet"],
}

## The perks that do something in this version of the game.
const BUILT := ["challenge", "punish", "kindle", "ore_sense",
		"close_call", "flank", "keep_the_chain", "sharp", "kill_rush", "expose", "execution",
		"unmoved", "bodyguard", "payback", "tempered", "shoulder_charge", "plate", "unbroken"]

const PERKS := {
	"challenge": {"name": "Challenge", "text": "Your finisher Challenges every enemy it hits for 5 s. They turn on you, and their hits on you do a quarter less. Bosses turn for 3 s, then can't be Challenged again for 10 s."},
	"unmoved": {"name": "Unmoved", "text": "While you are swinging or using an active rune, hits can't knock you back or cut the move short. You still take the damage."},
	"bodyguard": {"name": "Bodyguard", "text": "Co-op only. Teammates inside your ring (about three body lengths) take a third less damage, and that third lands on you. A knocked-down teammate inside your ring stops bleeding out."},
	"payback": {"name": "Payback", "text": "Damage you take fills a Payback meter under your health. Your next finisher spends it all as a burst where the finisher lands."},
	"tempered": {"name": "Tempered", "text": "No single hit can take more than a third of your health."},
	"shoulder_charge": {"name": "Shoulder Charge", "text": "Dodging into enemies shoves them back and Challenges them. Small enemies are knocked flat for a moment, which makes them Open."},
	"plate": {"name": "Plate", "text": "A bronze plate soaks the next hit you take, completely. It grows back 8 s after it breaks."},
	"unbroken": {"name": "Unbroken", "text": "A blow that would knock down you, or a teammate inside your ring, leaves them on 1 health and untouchable for 2 s instead. Once every 90 s."},

	"punish": {"name": "Punish", "text": "Enemies are Open while they recover from a missed attack, a stun or being knocked flat. Your hits on Open enemies always crit."},
	"close_call": {"name": "Close Call", "text": "Dodge through an attack at the last moment and that enemy is Open for 2 s."},
	"flank": {"name": "Flank", "text": "Hitting an enemy from behind counts as hitting it Open."},
	"keep_the_chain": {"name": "Keep the Chain", "text": "Dodging no longer resets your combo. Your next swing carries on where you left off."},
	"sharp": {"name": "Sharp", "text": "Go 6 s without being hit and your weapon glints. Your next finisher hits twice as hard. Taking a hit loses the glint."},
	"kill_rush": {"name": "Kill Rush", "text": "A kill gives you back one dodge charge."},
	"expose": {"name": "Expose", "text": "Your crits on a boss or elite leave it Exposed for 4 s. Everyone's hits on it do 15% more. Two Strikers' Exposes don't stack."},
	"execution": {"name": "Execution", "text": "Your finisher on an Open enemy is an Execution. It hits three times as hard, and normal enemies below a third of their health die outright."},

	"kindle": {"name": "Kindle", "text": "Your finisher knocks a Spark out of the enemy it hits (one every 4 s at most). Walking over a Spark heals 10% of your health. Sparks last 10 s."},
	"helping_hand": {"name": "Helping Hand", "text": "Co-op only. Hold Use next to a hurt teammate to pour your health into theirs. Your revives take half the time, and friends get up at 60% health."},
	"banked_warmth": {"name": "Banked Warmth", "text": "A Spark taken at full health becomes a shield, up to a quarter of your health."},
	"hearth": {"name": "Hearth", "text": "Stand still for 2 s and a hearth circle lights around you. While you stay, everyone inside heals slowly and their active runes recharge a quarter faster."},
	"drift": {"name": "Drift", "text": "Your Sparks float towards the most hurt player nearby, and last twice as long."},
	"bolster": {"name": "Bolster", "text": "Whoever takes one of your Sparks also deals 25% more damage for 6 s."},
	"flare": {"name": "Flare", "text": "A Spark bursts when it's taken, hurting enemies around that player and shoving them back."},
	"rekindle": {"name": "Rekindle", "text": "Your Sparks fly to knocked-down teammates, and three Sparks get a friend up while you keep fighting. Once every two minutes, if you go down yourself, you get straight back up at half health."},

	"ore_sense": {"name": "Ore Sense", "text": "Ore, buried chests and hidden rooms near you shimmer through rock and ground. The whole squad sees it."},
	"vein_breaker": {"name": "Vein Breaker", "text": "Breaking one ore node cracks every node touching it, so a whole vein comes out in a few swings."},
	"recall": {"name": "Recall", "text": "Out of combat, hold Use for 3 s to send the Memory you're carrying to the forge from anywhere."},
	"field_anvil": {"name": "Field Anvil", "text": "You can build a small anvil anywhere with the mallet. Anyone in the squad can change fittings or load a preset there. One at a time."},
	"laden": {"name": "Laden", "text": "The more unbanked Memory you carry, the harder you hit: up to a quarter more with a full bar. Dying still drops half of it."},
	"second_look": {"name": "Second Look", "text": "When an elite or boss drops a part for you, the game rolls twice and you keep the better one."},
	"deep_pockets": {"name": "Deep Pockets", "text": "Your Accessory Satchel has one extra row."},
	"forge_prophet": {"name": "Forge Prophet", "text": "Darren's idea. While a Forge Prophet is in the squad, every player's weapon has one extra slot, on top of the normal cap. Two Prophets don't give two slots. If the Prophet leaves the game or respecs away, the slot goes cold: what is fitted in it stays put but does nothing until a Prophet is back. Solo, you are your own Prophet."},
}


static func known(id) -> bool:
	return id is String and PERKS.has(id)


static func built(id: String) -> bool:
	return id in BUILT


static func name_of(id: String) -> String:
	return str(PERKS.get(id, {}).get("name", id))


static func text_of(id: String) -> String:
	return str(PERKS.get(id, {}).get("text", ""))


## Which tree a perk is in ("" if there is no such perk).
static func tree_of(id: String) -> String:
	for tree in TREES:
		if id in TREE[tree]:
			return tree
	return ""


## Its row: 0 the signature, 1 to 3 the rows of two, 4 the capstone (-1 if there is no such perk).
static func row_of(id: String) -> int:
	var tree := tree_of(id)
	return int(ROWS[(TREE[tree] as Array).find(id)]) if tree != "" else -1


## How many of these perks are in a tree.
static func in_tree(perks: Array, tree: String) -> int:
	var n := 0
	for id in perks:
		if id in TREE.get(tree, []):
			n += 1
	return n


## The capstone among these perks ("" if there is none).
static func capstone_in(perks: Array) -> String:
	for id in perks:
		if row_of(str(id)) == CAPSTONE:
			return str(id)
	return ""


## Why this perk cannot be learnt by somebody who has `perks` and `points` to spend, in words; "" if it can.
## `as_if_built` leaves out the rule that a perk has to be built (the checks try the trees' shape with it).
static func why_not(id: String, perks: Array, points: int, as_if_built := false) -> String:
	if not known(id):
		return "There is no such perk."
	if id in perks:
		return "You have learnt this."
	if not built(id) and not as_if_built:
		return "Not built yet: it comes in a later version of the game."
	var tree := tree_of(id)
	var row := row_of(id)
	if row == CAPSTONE:
		var have := in_tree(perks, tree)
		if have < CAPSTONE_NEEDS:
			return "Needs %d points in this tree first (you have %d)." % [CAPSTONE_NEEDS, have]
		var other := capstone_in(perks)
		if other != "":
			return "Only one capstone is yours, and you have %s." % name_of(other)
	elif row > 0:
		var above := false
		for other in perks:
			if tree_of(str(other)) == tree and row_of(str(other)) == row - 1:
				above = true
		if not above:
			return "Needs %s first." % name_of(str(TREE[tree][0])) if row == 1 else "Needs one perk from the row above first."
	if points <= 0:
		return "No point to spend: the squad gains one with every level."
	return ""


## A list of perks as it may be kept: only perks there are, each once, in the order they were learnt.
static func clean(list) -> Array:
	var out: Array = []
	if list is Array:
		for id in list:
			if known(id) and not (id in out):
				out.append(id)
	return out


## The perks that are awake in a world whose forge is at `level`: the first so many, in the order they were learnt.
static func awake(perks: Array, level: int) -> Array:
	return perks.slice(0, maxi(level, 0))
