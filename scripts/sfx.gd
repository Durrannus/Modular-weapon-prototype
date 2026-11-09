extends Node
## Placeholder sounds, made in code so there are no audio files to manage yet.
## Each rune has its own sound so you can hear which one fired.
## Usage: Sfx.play(self, "shockwave")

const RATE := 22050

static var _cache := {}


static func play(from: Node, kind: String, volume_db := -6.0, pitch := 1.0) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(kind)
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	from.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var s := _make(kind)
	_cache[kind] = s
	return s


static func _make(kind: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	var length := 0.25
	match kind:
		"shockwave": length = 0.55
		"hook": length = 0.35
		"cleave": length = 0.14
		"second_wind": length = 0.4
		"finisher": length = 0.2
		"swing": length = 0.09
		"click": length = 0.05
		"anvil": length = 0.45
		"forged": length = 1.0
		"hit": length = 0.07
		"hurt": length = 0.18
		"squish": length = 0.16
		"gate": length = 0.7
		"pickup": length = 0.45
		"slam": length = 0.5
		"talk": length = 0.045
		"rumble": length = 1.4
		"warn": length = 0.16
		"dodge": length = 0.12
	var n := int(RATE * length)
	data.resize(n * 2)
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / length              # 0..1 through the sound
		var v := 0.0
		match kind:
			"shockwave":  # deep boom falling in pitch, plus rumble
				phase += TAU * lerpf(140.0, 38.0, k) / RATE
				noise = lerpf(noise, randf_range(-1, 1), 0.08)
				v = (sin(phase) * 0.8 + noise * 0.5) * pow(1.0 - k, 1.6)
			"hook":  # rattling chain: square chirps rising
				phase += TAU * lerpf(300.0, 900.0, k) / RATE
				var rattle := 1.0 if int(t * 40.0) % 2 == 0 else 0.4
				v = signf(sin(phase)) * 0.35 * rattle * (1.0 - k)
			"cleave":  # sharp bright slice
				noise = randf_range(-1, 1) - noise * 0.6
				phase += TAU * 2400.0 / RATE
				v = (noise * 0.4 + sin(phase) * 0.3) * pow(1.0 - k, 3.0)
			"second_wind":  # rising chime, two notes
				var f := 660.0 if k < 0.45 else 990.0
				phase += TAU * f / RATE
				v = sin(phase) * 0.45 * (1.0 - fmod(k, 0.45) / 0.45 * 0.6) * (1.0 - k * 0.5)
			"finisher":  # heavy thump
				phase += TAU * lerpf(90.0, 45.0, k) / RATE
				v = sin(phase) * 0.9 * pow(1.0 - k, 2.0)
			"anvil":  # metal clang: two bright partials ringing out, with a hard hit
				phase += TAU / RATE
				var ring := sin(phase * 1250.0) * 0.5 + sin(phase * 1870.0) * 0.35 + sin(phase * 3020.0) * 0.15
				noise = randf_range(-1, 1)
				v = ring * pow(1.0 - k, 2.5) * 0.7 + noise * maxf(0.0, 1.0 - t * 60.0) * 0.6
			"forged":  # quench hiss plus a rising chime
				noise = lerpf(noise, randf_range(-1, 1), 0.6)
				phase += TAU * lerpf(520.0, 1040.0, minf(k * 2.0, 1.0)) / RATE
				v = noise * 0.35 * pow(1.0 - k, 1.5) + sin(phase) * 0.3 * sin(k * PI)
			"swing":
				noise = lerpf(noise, randf_range(-1, 1), 0.3)
				v = noise * 0.25 * sin(k * PI)
			"hit":  # a short dull thwack when the blade connects
				phase += TAU * lerpf(260.0, 120.0, k) / RATE
				noise = lerpf(noise, randf_range(-1, 1), 0.5)
				v = (sin(phase) * 0.6 + noise * 0.5) * pow(1.0 - k, 2.0)
			"hurt":  # you got hit: a low buzz dropping
				phase += TAU * lerpf(220.0, 90.0, k) / RATE
				v = signf(sin(phase)) * 0.4 * pow(1.0 - k, 1.5)
			"squish":  # an enemy dying
				phase += TAU * lerpf(420.0, 110.0, k) / RATE
				noise = lerpf(noise, randf_range(-1, 1), 0.25)
				v = (sin(phase) * 0.5 + noise * 0.35) * pow(1.0 - k, 1.8)
			"gate":  # stone grinding, then a clunk
				noise = lerpf(noise, randf_range(-1, 1), 0.12)
				phase += TAU * 70.0 / RATE
				var clunk := sin(phase) * maxf(0.0, 1.0 - absf(k - 0.85) * 12.0)
				v = noise * 0.7 * (1.0 - k * 0.5) * (0.6 + 0.4 * sin(t * 55.0)) + clunk * 0.8
			"pickup":  # three rising notes
				var f: float = [523.0, 659.0, 784.0][mini(int(k * 3.0), 2)]
				phase += TAU * f / RATE
				v = sin(phase) * 0.4 * (1.0 - fmod(k * 3.0, 1.0) * 0.5) * (1.0 - k * 0.3)
			"slam":  # a heavy stone impact
				phase += TAU * lerpf(110.0, 30.0, k) / RATE
				noise = lerpf(noise, randf_range(-1, 1), 0.2)
				v = (sin(phase) * 0.9 + noise * 0.6 * (1.0 - k)) * pow(1.0 - k, 1.4)
			"talk":  # one blip per few letters of speech
				phase += TAU * 330.0 / RATE
				v = signf(sin(phase)) * 0.18 * (1.0 - k)
			"rumble":  # the cave shaking
				noise = lerpf(noise, randf_range(-1, 1), 0.05)
				phase += TAU * 42.0 / RATE
				v = (noise * 1.2 + sin(phase) * 0.4) * sin(k * PI)
			"warn":  # an enemy about to strike
				phase += TAU * 880.0 / RATE
				v = signf(sin(phase)) * 0.22 * (1.0 if int(k * 4.0) % 2 == 0 else 0.0)
			"dodge":  # a quick whoosh
				noise = lerpf(noise, randf_range(-1, 1), lerpf(0.5, 0.1, k))
				v = noise * 0.3 * sin(k * PI)
			_:
				phase += TAU * 1200.0 / RATE
				v = sin(phase) * 0.3 * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
