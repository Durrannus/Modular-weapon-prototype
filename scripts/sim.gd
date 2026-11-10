extends RefCounted
## Random numbers for anything that decides what happens in the game: crits,
## where enemies appear, how long an enemy waits before it attacks.
##
## Online, both computers start this from the same seed and ask it the same
## questions in the same order, so they always roll the same numbers. That is
## what keeps the two games identical (see scripts/net/session.gd).
##
## Things that are only looks or sound (camera shake, sparks, the wobble on a
## damage number) keep using Godot's own randf(): those may differ between the
## two computers without anyone noticing, and they must NOT use this one, or the
## two games would drift apart.

static var rng := RandomNumberGenerator.new()


## A fresh, unpredictable start (playing on one computer).
static func shuffle() -> void:
	rng.randomize()


## The same start on both computers (playing online).
static func seed_with(value: int) -> void:
	rng.seed = value


static func chance() -> float:
	return rng.randf()


static func between(from: float, to: float) -> float:
	return rng.randf_range(from, to)
