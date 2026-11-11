extends Node
## Background music. Tracks are looping Ogg files in art/music/, made from scratch
## by the Python scripts beside them, and loaded at runtime like the art so they
## need no import step.
## Two players crossfade, so switching tracks never cuts dead.
## Usage: music.play("cave_calm") / music.play("cave_boss", 1.5) / music.stop()
## Music is local to each screen; it never touches the game state, so it is safe online.

const DIR := "res://art/music/"
## How loud each track sits under the sound effects, in dB.
const VOLUME := {"cave_calm": -9.0, "cave_boss": -10.0}
const SILENT := -60.0

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tweens: Array = [null, null]
static var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing under the pause menu
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT
		add_child(p)
		_players.append(p)


## Fade from whatever is playing to this track over `fade` seconds.
## Asking for the track that is already playing does nothing.
func play(track: String, fade := 2.0) -> void:
	if track == current:
		return
	var stream := _load(track)
	if stream == null:
		return
	current = track
	_fade(_active, SILENT, fade, true)
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = SILENT
	p.play()
	_fade(_active, float(VOLUME.get(track, -10.0)), fade, false)


func stop(fade := 2.0) -> void:
	current = ""
	_fade(_active, SILENT, fade, true)


func _fade(i: int, to_db: float, seconds: float, stop_after: bool) -> void:
	if _tweens[i] != null:
		_tweens[i].kill()
	var p := _players[i]
	if not p.playing:
		return
	var tw := create_tween()
	# Fade in loudness, not in dB, so the crossfade doesn't dip in the middle.
	tw.tween_method(func(v: float): p.volume_db = linear_to_db(maxf(v, 0.001)),
			db_to_linear(p.volume_db), db_to_linear(to_db), maxf(seconds, 0.01))
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[i] = tw


static func _load(track: String) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var path := DIR + track + ".ogg"
	var s: AudioStreamOggVorbis = null
	if FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
		if s != null:
			s.loop = true
	_streams[track] = s
	return s
