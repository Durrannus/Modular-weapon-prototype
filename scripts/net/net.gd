extends RefCounted
## Where the rest of the game asks "are we playing online, and which player am I?"
## The session itself is scripts/net/session.gd; this only points at it.

static var session: Node = null


## True while an online game is being played.
static func online() -> bool:
	return is_instance_valid(session) and session.playing


## Which player this computer controls (0 = the host). Always 0 offline.
static func me() -> int:
	return session.my_index if online() else 0


## Sends something this player did in a menu (changed their sword, closed the
## forge) to both computers, to happen on the same tick. Does nothing offline.
static func command(cmd: Array) -> void:
	if online():
		session.command(cmd)
