extends SceneTree
## Synthesizes every sound effect and the two music loops into res://assets/audio/ (16-bit mono WAV, 22.05 kHz).
## There are no recorded samples: square, triangle, sine and noise voices, simple envelopes and a little pitch sweep.
##   godot --headless --path godot -s tests/make_audio.gd
## Then run `godot --headless --path godot --import` so Godot picks the new files up.

const SR := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

# Target peak per sound: small UI sounds sit low, impacts and fanfares sit high.
const LEVELS := {
	"click": 0.4, "tick": 0.3, "choose": 0.4, "mark": 0.35, "blip": 0.35, "wheel_tick": 0.3, "deal": 0.5, "flip": 0.5,
	"swoosh": 0.45, "select": 0.5, "vs_in": 0.5, "chip_up": 0.5, "chip_down": 0.5, "push": 0.5, "win": 0.65, "lose": 0.6,
	"land": 0.6, "first_down": 0.65, "start": 0.55, "slam": 0.8, "sack": 0.7, "thud": 0.6, "turnover": 0.65, "bust": 0.75,
	"touchdown": 0.8,
}

var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------------ synthesis helpers
func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * SR))
	return b


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _midi(note: String) -> int:
	var base := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var i := 1
	var acc := 0
	if note.length() > 1 and note[1] == "#":
		acc = 1
		i = 2
	elif note.length() > 1 and note[1] == "b":
		acc = -1
		i = 2
	return 12 * (int(note.substr(i)) + 1) + int(base[note[0]]) + acc


func _wave(kind: String, ph: float, duty: float) -> float:
	var p := ph - floorf(ph)
	match kind:
		"sq": return 1.0 if p < duty else -1.0
		"tri": return 4.0 * absf(p - 0.5) - 1.0
		"saw": return 2.0 * p - 1.0
		"sine": return sin(p * TAU)
	return 0.0


## One pitched note. Frequency glides f0 -> f1; `decay` shapes an exponential fade over the note.
func _tone(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, kind: String, vol: float,
		decay: float = 3.0, duty: float = 0.5, atk: float = 0.004, rel: float = 0.02) -> void:
	var s0 := int(t0 * SR)
	var n := int(dur * SR)
	var ph := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var k := float(i) / maxf(1.0, float(n))
		var f := f0 * pow(f1 / f0, k) if f0 > 0.0 and f1 > 0.0 else f0
		ph += f / SR
		var t := float(i) / SR
		var env := minf(1.0, t / atk) * exp(-decay * k) * minf(1.0, (dur - t) / rel)
		b[idx] += _wave(kind, ph, duty) * vol * env


## Noise through a one-pole lowpass whose coefficient sweeps lp0 -> lp1 (0 = muffled, 1 = bright).
func _noise(b: PackedFloat32Array, t0: float, dur: float, vol: float, lp0: float, lp1: float, decay: float = 4.0) -> void:
	var s0 := int(t0 * SR)
	var n := int(dur * SR)
	var y := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var k := float(i) / maxf(1.0, float(n))
		var a := lerpf(lp0, lp1, k)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		b[idx] += y * vol * exp(-decay * k) * minf(1.0, float(n - i) / (0.01 * SR))


func _save(b: PackedFloat32Array, path: String, peak_target: float = 0.8) -> void:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var g := peak_target / peak                       # every file is normalized to its own target loudness
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	w.save_to_wav(ProjectSettings.globalize_path(path))
	print("%-34s %5.2fs  peak %.2f" % [path.get_file(), float(b.size()) / SR, peak])


# ------------------------------------------------------------------ sound effects
func _sfx(name: String) -> PackedFloat32Array:
	var b: PackedFloat32Array
	match name:
		"click":
			b = _buf(0.07)
			_tone(b, 0, 0.06, 1100, 700, "sq", 0.35, 6.0)
		"tick":
			b = _buf(0.04)
			_tone(b, 0, 0.03, 1500, 1500, "sq", 0.22, 4.0)
		"choose":
			b = _buf(0.09)
			_tone(b, 0, 0.08, 880, 1175, "sq", 0.3, 4.0)
		"deal":
			b = _buf(0.12)
			_noise(b, 0, 0.1, 0.5, 0.6, 0.2, 5.0)
			_tone(b, 0, 0.06, 300, 120, "tri", 0.3, 4.0)
		"flip":
			b = _buf(0.14)
			_tone(b, 0, 0.06, 420, 840, "tri", 0.35, 3.0)
			_tone(b, 0.06, 0.07, 840, 1100, "tri", 0.2, 3.0)
		"swoosh":
			b = _buf(0.26)
			_noise(b, 0, 0.24, 0.4, 0.7, 0.1, 3.0)
		"mark":
			b = _buf(0.06)
			_tone(b, 0, 0.05, 700, 520, "sq", 0.22, 5.0)
		"select":
			b = _buf(0.22)
			for i in 3:
				_tone(b, i * 0.045, 0.08, [523.0, 659.0, 784.0][i], [523.0, 659.0, 784.0][i], "sq", 0.28, 4.0, 0.25)
		"vs_in":
			b = _buf(0.34)
			_noise(b, 0, 0.32, 0.35, 0.05, 0.8, 1.5)
			_tone(b, 0, 0.3, 200, 700, "saw", 0.15, 1.5)
		"slam":
			b = _buf(0.3)
			_noise(b, 0, 0.26, 0.7, 0.5, 0.05, 6.0)
			_tone(b, 0, 0.26, 140, 45, "sine", 0.8, 5.0)
		"win":
			b = _buf(0.75)
			var f := [523.0, 659.0, 784.0, 1047.0]
			for i in 4:
				_tone(b, i * 0.075, 0.38 if i == 3 else 0.09, f[i], f[i], "sq", 0.3, 2.0 if i == 3 else 4.0, 0.25)
				_tone(b, i * 0.075, 0.38 if i == 3 else 0.09, f[i] / 2.0, f[i] / 2.0, "tri", 0.25, 2.0 if i == 3 else 4.0)
		"lose":
			b = _buf(0.85)
			var f2 := [392.0, 349.0, 330.0, 262.0]
			for i in 4:
				_tone(b, i * 0.13, 0.45 if i == 3 else 0.14, f2[i], f2[i] * 0.98, "tri", 0.4, 2.0 if i == 3 else 3.0)
		"push":
			b = _buf(0.3)
			_tone(b, 0, 0.09, 440, 440, "sq", 0.25, 3.0)
			_tone(b, 0.13, 0.09, 440, 440, "sq", 0.25, 3.0)
		"wheel_tick":
			b = _buf(0.02)
			_tone(b, 0, 0.015, 2200, 2200, "sq", 0.2, 8.0, 0.5, 0.001, 0.004)
		"land":
			b = _buf(0.6)
			_tone(b, 0, 0.55, 1319, 1319, "sine", 0.4, 3.0)
			_tone(b, 0.08, 0.5, 1760, 1760, "sine", 0.3, 3.0)
			_tone(b, 0, 0.12, 660, 660, "sq", 0.12, 5.0, 0.25)
		"chip_up":
			b = _buf(0.24)
			_tone(b, 0, 0.07, 988, 988, "sq", 0.3, 2.0, 0.25)
			_tone(b, 0.07, 0.16, 1319, 1319, "sq", 0.3, 4.0, 0.25)
		"chip_down":
			b = _buf(0.22)
			_tone(b, 0, 0.08, 600, 600, "sq", 0.28, 2.0)
			_tone(b, 0.08, 0.13, 400, 380, "sq", 0.28, 4.0)
		"first_down":
			b = _buf(0.6)
			var f3 := [392.0, 523.0, 659.0]
			for i in 3:
				_tone(b, i * 0.08, 0.09, f3[i], f3[i], "sq", 0.3, 3.0, 0.25)
			_tone(b, 0.24, 0.32, 659, 659, "sq", 0.3, 2.5, 0.25)
			_tone(b, 0.24, 0.32, 330, 330, "tri", 0.3, 2.5)
		"touchdown":
			b = _buf(1.9)
			var mel := [[0.0, 523.0, 0.12], [0.14, 523.0, 0.12], [0.28, 523.0, 0.12], [0.42, 659.0, 0.28], [0.74, 784.0, 0.28],
					[1.06, 784.0, 0.1], [1.2, 1047.0, 0.65]]
			for m in mel:
				_tone(b, m[0], m[2], m[1], m[1], "sq", 0.28, 2.0, 0.25)
				_tone(b, m[0], m[2], m[1] / 2.0, m[1] / 2.0, "tri", 0.3, 2.0)
			_noise(b, 1.2, 0.5, 0.25, 0.95, 0.5, 3.0)
			_tone(b, 1.2, 0.65, 130, 130, "tri", 0.3, 2.0)
		"turnover":
			b = _buf(0.5)
			_tone(b, 0, 0.18, 120, 110, "saw", 0.4, 2.0)
			_tone(b, 0.18, 0.28, 90, 60, "saw", 0.4, 2.0)
			_noise(b, 0, 0.3, 0.2, 0.3, 0.1, 3.0)
		"sack":
			b = _buf(0.34)
			_noise(b, 0, 0.28, 0.8, 0.3, 0.03, 5.0)
			_tone(b, 0, 0.28, 120, 50, "sine", 0.7, 4.0)
		"bust":
			b = _buf(1.2)
			_tone(b, 0, 0.95, 420, 70, "tri", 0.5, 1.0)
			_tone(b, 0, 0.95, 425, 72, "sq", 0.12, 1.0, 0.25)
			_noise(b, 0.9, 0.25, 0.5, 0.2, 0.03, 5.0)
			_tone(b, 0.9, 0.25, 90, 40, "sine", 0.7, 4.0)
		"blip":
			b = _buf(0.08)
			_tone(b, 0, 0.06, 660, 660, "sq", 0.25, 6.0, 0.25)
		"thud":
			b = _buf(0.2)
			_tone(b, 0, 0.16, 110, 55, "sine", 0.6, 4.0)
			_noise(b, 0, 0.08, 0.3, 0.2, 0.05, 5.0)
		"start":
			b = _buf(0.5)
			var f4 := [392.0, 523.0, 659.0, 784.0, 1047.0]
			for i in 5:
				_tone(b, i * 0.06, 0.2 if i == 4 else 0.07, f4[i], f4[i], "sq", 0.28, 2.5 if i == 4 else 4.0, 0.25)
	return b


# ------------------------------------------------------------------ music
## Pattern strings: 16 tokens per bar (sixteenth notes). A note starts a voice, "-" holds it, "." is a rest.
func _events(bars: Array) -> Array:
	var ev: Array = []
	var step := 0
	for bar in bars:
		var toks: PackedStringArray = String(bar).split(" ", false)
		var cur := -1
		for i in toks.size():
			var tk := toks[i]
			if tk == "-":
				if cur >= 0:
					ev[cur][2] += 1
			elif tk == ".":
				cur = -1
			else:
				ev.append([step + i, _midi(tk), 1])
				cur = ev.size() - 1
		step += 16
	return ev


func _voice(b: PackedFloat32Array, events: Array, step_s: float, kind: String, vol: float, decay: float, duty: float, octave: int = 0) -> void:
	for e in events:
		var f := _hz(float(e[1]) + 12.0 * octave)
		_tone(b, float(e[0]) * step_s, float(e[2]) * step_s, f, f, kind, vol, decay, duty, 0.004, 0.02)


func _drums(b: PackedFloat32Array, bars: int, step_s: float, kick: Array, snare: Array, hat: Array, kv: float, sv: float, hv: float) -> void:
	for bar in bars:
		for st in 16:
			var t := float(bar * 16 + st) * step_s
			if kick.has(st):
				_tone(b, t, 0.13, 150, 42, "sine", kv, 4.0)
			if snare.has(st):
				_noise(b, t, 0.12, sv, 0.55, 0.3, 4.0)
				_tone(b, t, 0.06, 220, 160, "tri", sv * 0.5, 4.0)
			if hat.has(st):
				_noise(b, t, 0.035, hv, 0.95, 0.9, 6.0)


## Arpeggio over the chord of each bar: root, third, fifth, octave (a minor or major triad as given).
func _arp(roots: Array, minor: Array, pattern: Array) -> Array:
	var ev: Array = []
	for bar in roots.size():
		var r: int = _midi(roots[bar])
		var third := 3 if minor[bar] else 4
		var tones := [r, r + third, r + 7, r + 12]
		for st in 16:
			ev.append([bar * 16 + st, tones[pattern[st]], 1])
	return ev


func _bass(roots: Array, pattern: Array) -> Array:
	var ev: Array = []
	for bar in roots.size():
		var r: int = _midi(roots[bar])
		for st in 16:
			if pattern[st] >= 0:
				ev.append([bar * 16 + st, r + 12 * int(pattern[st]), 2])
	return ev


func _music_menu() -> PackedFloat32Array:
	var bpm := 120.0
	var step := 60.0 / bpm / 4.0
	var roots := ["A2", "A2", "F2", "F2", "C3", "C3", "G2", "G2", "A2", "F2", "C3", "G2", "A2", "F2", "G2", "E2"]
	var minor := [true, true, false, false, false, false, false, false, true, false, false, false, true, false, false, false]
	var m := {
		"m1": "E5 - - - A5 - - - C6 - B5 - A5 - - -",
		"m2": "F5 - - - A5 - - - C6 - - - A5 - G5 -",
		"m3": "E5 - G5 - C6 - - - B5 - G5 - E5 - - -",
		"m4": "D5 - - - G5 - - - B5 - - - D6 - - -",
		"m5": "A5 - C6 - E6 - - - D6 - C6 - A5 - - -",
		"m6": "G#5 - - - B5 - - - E6 - - - . . . .",
	}
	var order := ["m1", "m5", "m2", "m2", "m3", "m3", "m4", "m4", "m5", "m2", "m3", "m4", "m1", "m2", "m4", "m6"]
	var mel_bars: Array = []
	for k in order:
		mel_bars.append(m[k])
	var total := 16 * 16 * step
	var b := _buf(total)
	_voice(b, _bass(roots, [0, -1, 0, -1, 1, -1, 0, -1, 0, -1, 0, -1, 1, -1, 0, -1]), step, "tri", 0.34, 1.5, 0.5)
	_voice(b, _arp(roots, minor, [0, 1, 2, 3, 2, 1, 2, 1, 0, 1, 2, 3, 2, 1, 2, 1]), step, "sq", 0.1, 3.0, 0.25, 0)
	_voice(b, _events(mel_bars), step, "sq", 0.2, 1.2, 0.5)
	_drums(b, 16, step, [0, 8, 10], [4, 12], [2, 6, 10, 14], 0.45, 0.28, 0.12)
	return b


func _music_game() -> PackedFloat32Array:
	var bpm := 108.0
	var step := 60.0 / bpm / 4.0
	var roots := ["D2", "D2", "A#1", "A#1", "G2", "G2", "A2", "A2", "D2", "D2", "A#1", "A#1", "G2", "G2", "A2", "A2"]
	var minor := [true, true, false, false, true, true, false, false, true, true, false, false, true, true, false, false]
	var rest := ". . . . . . . . . . . . . . . ."
	var l1 := "D5 - - - F5 - A5 - G5 - F5 - D5 - - -"
	var l2 := "D5 - - - A5 - - - G5 - F5 - E5 - - -"
	var l3 := "C#5 - E5 - A5 - - - G5 - E5 - C#5 - - -"
	var l4 := "F5 - - - E5 - D5 - . . . . . . . ."
	var lead_bars := [rest, rest, rest, rest, rest, rest, rest, rest, l1, l2, "Bb4 - D5 - F5 - - - D5 - Bb4 - - - . .", l4, l1, l2, l3, "A5 - - - - - - - E5 - - - . . . ."]
	var total := 16 * 16 * step
	var b := _buf(total)
	_voice(b, _bass(roots, [0, -1, 0, 0, -1, 0, 1, -1, 0, -1, 0, 0, -1, 0, 1, -1]), step, "tri", 0.36, 1.2, 0.5)
	_voice(b, _arp(roots, minor, [0, 2, 1, 2, 3, 2, 1, 2, 0, 2, 1, 2, 3, 2, 1, 2]), step, "sq", 0.09, 3.5, 0.125)
	_voice(b, _events(lead_bars), step, "sq", 0.17, 1.2, 0.25)
	_drums(b, 16, step, [0, 6, 8, 11], [4, 12], [0, 2, 4, 6, 8, 10, 12, 14], 0.45, 0.3, 0.1)
	return b


func _init() -> void:
	_rng.seed = 5
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	for name in ["click", "tick", "choose", "deal", "flip", "swoosh", "mark", "select", "vs_in", "slam", "win", "lose", "push",
			"wheel_tick", "land", "chip_up", "chip_down", "first_down", "touchdown", "turnover", "sack", "bust", "blip", "thud", "start"]:
		_save(_sfx(name), SFX_DIR + name + ".wav", float(LEVELS.get(name, 0.5)))
	_save(_music_menu(), MUSIC_DIR + "menu.wav", 0.7)
	_save(_music_game(), MUSIC_DIR + "game.wav", 0.7)
	quit()
