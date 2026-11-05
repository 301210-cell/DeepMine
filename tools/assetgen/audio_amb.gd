## DeepMine ambience beds: seamless 24 s mono loops (22050 Hz, -6 dBFS peak).
## Noise layers are filtered circularly, oscillators use integer cycles per loop, and one-shot
## events (drips, birds, bubbles) wrap around the loop end, so every file loops without a seam.
extends RefCounted

const A = preload("res://audio_lib.gd")
const SR := 22050
const LEN := 24.0
const PEAK := 0.5

const SINE := A.SINE
const PULSE := A.PULSE
const SAW := A.SAW
const TRI := A.TRI
const LOW := A.LOW
const BAND := A.BAND
const HIGH := A.HIGH


static func run(names: Array) -> void:
	var all := ["surface", "cave", "crystal", "frozen", "magma", "ancient"]
	for nm in all:
		if names.is_empty() or names.has(nm):
			var t0 := Time.get_ticks_msec()
			var b: PackedFloat32Array = call_gen(nm)
			A.loop_dc_block(b)
			A.normalize(b, PEAK)
			A.save_wav("ambience/%s.wav" % nm, b, SR, false)
			print("  rendered ambience/%s in %.1fs" % [nm, (Time.get_ticks_msec() - t0) / 1000.0])


static func call_gen(nm: String) -> PackedFloat32Array:
	match nm:
		"surface":
			return surface()
		"cave":
			return cave()
		"crystal":
			return crystal()
		"frozen":
			return frozen()
		"magma":
			return magma()
		_:
			return ancient()


## Periodic LFO in 0..1 with `cycles` whole cycles per loop.
static func lfo(t: float, cycles: float, phase: float = 0.0) -> float:
	return 0.5 + 0.5 * sin(TAU * cycles * t / LEN + phase)


## Sine drone with integer cycles per loop.
static func drone(b: PackedFloat32Array, f: float, amp: float, wave: int = SINE, trem_cycles: float = 0.0, trem_depth: float = 0.0, phase: float = 0.0) -> void:
	var fq := A.qfreq(f, LEN)
	var ph := 0.0
	var dt := fq / SR
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		if wave == SINE:
			v = sin(TAU * ph)
		elif wave == SAW:
			v = 2.0 * ph - 1.0 - A.polyblep(ph, dt)
		else:
			v = 1.0 - 4.0 * absf(ph - 0.5)
		var am := 1.0
		if trem_depth > 0.0:
			am = 1.0 - trem_depth * lfo(t, trem_cycles, phase)
		b[i] += v * amp * am
		ph += dt
		if ph >= 1.0:
			ph -= 1.0


## Noise layer with an amplitude curve from LFOs: amp * (base + sum(depth_k * lfo_k)).
static func noise_layer(b: PackedFloat32Array, mode: int, fc: float, q: float, amp: float, r: RandomNumberGenerator, lfos: Array = []) -> void:
	var nz := A.loop_noise(b.size(), mode, fc, q, r)
	for i in b.size():
		var t := float(i) / SR
		var am := 1.0
		if not lfos.is_empty():
			am = float(lfos[0])
			for k in range(1, lfos.size()):
				var l: Array = lfos[k]
				am += float(l[1]) * lfo(t, float(l[0]), float(l[2]) if l.size() > 2 else 0.0)
		b[i] += nz[i] * amp * am


## Resonant band-passed noise whose centre frequency sweeps along periodic LFOs (wind howl).
static func swept_band(b: PackedFloat32Array, f_lo: float, f_hi: float, q: float, amp: float, r: RandomNumberGenerator, cycles: Array) -> void:
	var n := b.size()
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = r.randf() * 2.0 - 1.0
	var f := A.SVF.new(BAND)
	for i in 2 * n:
		var idx := i % n
		var t := float(idx) / SR
		if i % 32 == 0:
			var m := 0.0
			for k in cycles.size():
				m += lfo(t, float(cycles[k]), k * 1.7) / cycles.size()
			f.set_params(f_lo * pow(f_hi / f_lo, m), q, SR)
		var y := f.process(src[idx])
		if i >= n:
			var m2 := 0.0
			for k in cycles.size():
				m2 += lfo(t, float(cycles[k]), k * 1.7) / cycles.size()
			b[idx] += y * amp * (0.35 + 0.9 * m2 * m2)


# ------------------------------------------------------------------ beds

static func surface() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7001)
	# wind bed with slow gusts
	noise_layer(b, LOW, 420.0, 0.7, 0.55, r, [0.45, [2.0, 0.35], [5.0, 0.2, 1.1]])
	swept_band(b, 500.0, 1300.0, 1.4, 0.18, r, [3.0, 7.0])
	# leaf rustle following the gusts
	noise_layer(b, HIGH, 3800.0, 0.7, 0.06, r, [0.1, [2.0, 0.6], [11.0, 0.3, 0.4]])
	# birds: little 2-4 note chirp phrases
	for k in 11:
		var st := r.randf() * LEN
		var base := r.randf_range(2600.0, 4200.0)
		var notes := r.randi_range(2, 4)
		for j in notes:
			var f0 := base * r.randf_range(0.9, 1.15)
			var dur := r.randf_range(0.05, 0.09)
			A.tone(b, st + j * r.randf_range(0.08, 0.12), dur, f0, f0 * r.randf_range(1.15, 1.45), r.randf_range(0.08, 0.16), SINE, 0.006, 22.0, 0.5, true, 38.0, 0.6)
	# distant woodpecker-ish knocks, rare
	for k in 2:
		var st2 := r.randf() * LEN
		for j in 5:
			A.partials(b, st2 + j * 0.07, 900.0, [1.0, 2.3], [0.4, 0.2], [60.0, 80.0], 0.05, 0.08, 0.0005, 0.0, true)
	return b


static func cave() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7002)
	# low room tone + faint hum
	noise_layer(b, LOW, 160.0, 0.7, 0.9, r, [0.7, [3.0, 0.3]])
	drone(b, 49.0, 0.04, SINE, 2.0, 0.5)
	# distant rumble swells
	noise_layer(b, LOW, 70.0, 0.8, 0.9, r, [0.0, [1.0, 0.6, 2.0]])
	# water drips with echo taps
	for k in 15:
		var st := r.randf() * LEN
		var f := r.randf_range(900.0, 1900.0)
		var amp := r.randf_range(0.12, 0.3)
		for tap in 3:
			var ta := st + tap * 0.21
			var g := amp * pow(0.35, tap)
			A.tone(b, ta, 0.03, f * 1.4, f * 0.75, g, SINE, 0.001, 70.0, 0.5, true)
			A.partials(b, ta + 0.012, f * 0.78, [1.0, 2.1], [0.6, 0.15], [14.0, 22.0], 0.28, g * 0.6, 0.002, 0.0, true)
	return b


static func crystal() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7003)
	# shimmering chord drone (F lydian colours) with slow beating pairs
	var chord := [174.6, 261.6, 329.6, 440.0, 493.9]
	for k in chord.size():
		var f: float = chord[k]
		drone(b, f, 0.05, SINE, 1.0 + k, 0.5, k * 1.3)
		drone(b, f + 0.5, 0.035, SINE, 2.0 + k, 0.6, k * 0.7)
	drone(b, 698.5, 0.02, TRI, 3.0, 0.8)
	# airy breath
	noise_layer(b, HIGH, 5200.0, 0.7, 0.025, r, [0.3, [2.0, 0.6]])
	# sparkles
	var pent := [1396.9, 1568.0, 1760.0, 2093.0, 2349.3, 2637.0, 3136.0, 3520.0]
	for k in 46:
		var st := r.randf() * LEN
		A.partials(b, st, pent[r.randi() % pent.size()], [1.0, 2.0, 3.01], [0.5, 0.18, 0.06], [3.5, 5.5, 8.0], 1.4, r.randf_range(0.03, 0.08), 0.004, 1.5, true)
	return b


static func frozen() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7004)
	# howling wind: resonant band sweeps + deep bed
	swept_band(b, 280.0, 950.0, 4.5, 0.5, r, [1.0, 3.0, 5.0])
	swept_band(b, 600.0, 1600.0, 6.0, 0.22, r, [2.0, 4.0])
	noise_layer(b, LOW, 240.0, 0.7, 0.5, r, [0.5, [2.0, 0.4, 0.6]])
	# whistle tones
	for k in 4:
		var st := r.randf() * LEN
		var f := r.randf_range(1100.0, 1700.0)
		A.tone(b, st, 2.2, f, f * r.randf_range(0.85, 1.12), 0.035, SINE, 0.9, 1.2, 0.5, true, 5.5, 0.4)
	# ice creaks: clustered crackle grains + low groan
	for k in 5:
		var st2 := r.randf() * LEN
		for j in 9:
			var fc := r.randf_range(2200.0, 5200.0)
			A.noise_burst(b, st2 + j * r.randf_range(0.012, 0.03), 0.018, r.randf_range(0.06, 0.15), 0.0005, 120.0, BAND, fc, fc, 3.0, r, true)
	for k in 2:
		var st3 := r.randf() * LEN
		A.tone(b, st3, 1.4, 85.0, 58.0, 0.12, SAW, 0.25, 1.5, 0.5, true, 9.0, 0.6, 300.0, 200.0)
	return b


static func magma() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7005)
	# deep volcanic rumble
	noise_layer(b, LOW, 90.0, 0.8, 1.4, r, [0.6, [2.0, 0.3], [5.0, 0.2, 1.0]])
	drone(b, 36.0, 0.08, SINE, 3.0, 0.5)
	drone(b, 54.0, 0.035, TRI, 2.0, 0.6, 1.0)
	# fire crackle
	for k in 70:
		var st := r.randf() * LEN
		var fc := r.randf_range(1800.0, 5000.0)
		A.noise_burst(b, st, r.randf_range(0.004, 0.012), r.randf_range(0.03, 0.1), 0.0002, 280.0, BAND, fc, fc, 1.5, r, true)
	# lava bubbles (blorp + pop)
	for k in 34:
		var st2 := r.randf() * LEN
		var f := r.randf_range(70.0, 170.0)
		var g := r.randf_range(0.12, 0.3)
		var d := r.randf_range(0.12, 0.22)
		A.tone(b, st2, d, f, f * r.randf_range(1.5, 2.2), g, SINE, 0.03, 6.0, 0.5, true)
		A.noise_burst(b, st2 + d, 0.025, g * 0.5, 0.0003, 90.0, BAND, 800.0, 700.0, 1.5, r, true)
	# steam hiss vents
	for k in 3:
		var st3 := r.randf() * LEN
		A.noise_burst(b, st3, 1.8, 0.12, 0.5, 1.5, HIGH, 3500.0, 4500.0, 0.8, r, true)
	return b


static func ancient() -> PackedFloat32Array:
	var b := A.make_buf(LEN)
	var r := A.rng(7006)
	# deep machine hum with slow pulse
	drone(b, 55.0, 0.18, SINE, 6.0, 0.35)
	drone(b, 55.5, 0.1, SINE, 3.0, 0.4, 1.0)
	drone(b, 110.0, 0.08, TRI, 6.0, 0.5, 0.5)
	drone(b, 165.0, 0.04, SINE, 4.0, 0.6, 2.0)
	# ghostly choir pad (D minor), heavily filtered saws
	var pad := A.make_buf(LEN)
	for f in [146.8, 174.6, 220.0, 293.7]:
		drone(pad, f, 0.06, SAW, 1.0, 0.7, f * 0.01)
		drone(pad, f * 1.004, 0.05, SAW, 2.0, 0.7, f * 0.02)
	A.loop_lowpass(pad, 520.0)
	A.add_scaled(b, pad, 1.0)
	noise_layer(b, LOW, 300.0, 0.7, 0.12, r, [0.5, [2.0, 0.5]])
	# machine clanks every 3 s, alternating pitch, with echo taps
	for k in 8:
		var st := k * 3.0 + 0.4
		var f2: float = [180.0, 135.0][k % 2]
		for tap in 3:
			A.partials(b, st + tap * 0.33, f2, [1.0, 2.41, 3.93, 5.6], [0.5, 0.3, 0.18, 0.1], [4.0, 6.0, 9.0, 12.0], 1.2, 0.14 * pow(0.4, tap), 0.001, 0.0, true)
	# mysterious high chimes
	for k in 6:
		var st2 := r.randf() * LEN
		var f3: float = [1174.7, 1396.9, 1760.0, 2093.0][r.randi() % 4]
		A.partials(b, st2, f3, [1.0, 2.0, 2.76], [0.5, 0.2, 0.1], [2.0, 3.0, 4.5], 2.0, 0.05, 0.01, 0.8, true)
	return b
