## DeepMine sound effects (22050 Hz mono, -3 dBFS peak). Called from gen_audio.gd.
extends RefCounted

const A = preload("res://audio_lib.gd")
const SR := 22050
const PEAK := 0.708 # -3 dBFS

const SINE := A.SINE
const PULSE := A.PULSE
const SAW := A.SAW
const TRI := A.TRI
const NESTRI := A.NESTRI
const LOW := A.LOW
const BAND := A.BAND
const HIGH := A.HIGH


static func run() -> void:
	var t0 := Time.get_ticks_msec()
	swing()
	for v in 3:
		hit_rock(v)
	hit_ore()
	hit_crystal()
	hit_ice()
	hit_metal()
	for v in 2:
		break_rock(v)
	break_crystal()
	pickup()
	pickup_rare()
	coin()
	sell()
	buy()
	geode_crack()
	geode_reveal()
	elevator_move()
	elevator_ding()
	minecart()
	smelter()
	crusher()
	machine_done()
	ui_click()
	ui_hover()
	ui_open()
	ui_close()
	ui_error()
	skill_unlock()
	skill_max()
	level_up()
	event_start()
	event_end()
	rare_discovery()
	legendary()
	for v in 2:
		step(v)
	jump()
	land()
	ladder()
	hurt()
	fuse()
	explosion()
	chest_open()
	quest_complete()
	notify()
	splash()
	lava_bubble()
	place()
	print("SFX done in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))


static func _finish(name: String, b: PackedFloat32Array, loop: bool = false) -> void:
	var out := b
	if not loop:
		A.fade(out, 0.0015, 0.0)
		out = A.trim_tail(out)
	A.normalize(out, PEAK)
	# Loudness cap: sustained buzzy sounds would be far louder than transient ones at the same peak.
	var sum := 0.0
	for v in out:
		sum += v * v
	var rms := sqrt(sum / maxf(1.0, out.size()))
	var cap := db_to_linear(-13.0)
	if rms > cap:
		var g := cap / rms
		for i in out.size():
			out[i] *= g
	A.save_wav("sfx/%s.wav" % name, out, SR, false)


## Short debris grains (gravel ticks).
static func _grains(b: PackedFloat32Array, r: RandomNumberGenerator, count: int, t0: float, t1: float, amp: float, f_lo: float, f_hi: float, with_thump: bool = false) -> void:
	for k in count:
		var st := r.randf_range(t0, t1)
		var fall := 1.0 - (st - t0) / maxf(0.001, (t1 - t0)) * 0.6
		var fc := r.randf_range(f_lo, f_hi)
		A.noise_burst(b, st, r.randf_range(0.018, 0.045), amp * r.randf_range(0.5, 1.0) * fall, 0.0004, 90.0, BAND, fc, fc * 0.85, 2.2, r)
		if with_thump:
			var tf := r.randf_range(260.0, 620.0)
			A.tone(b, st, 0.035, tf, tf * 0.6, amp * 0.35 * fall, SINE, 0.0005, 70.0)


## Generic rock impact used by several sounds.
static func _rock_hit(b: PackedFloat32Array, r: RandomNumberGenerator, p: float, amp: float) -> void:
	A.tone(b, 0.0, 0.2, 155.0 * p, 58.0 * p, 0.95 * amp, SINE, 0.0008, 21.0)
	A.noise_burst(b, 0.0, 0.17, 0.95 * amp, 0.0006, 30.0, LOW, 3800.0 * p, 650.0 * p, 0.9, r)
	A.noise_burst(b, 0.0, 0.012, 0.55 * amp, 0.0003, 220.0, HIGH, 3200.0, 3200.0, 0.7, r)
	_grains(b, r, 4, 0.02, 0.15, 0.3 * amp, 1500.0, 3600.0)


# ------------------------------------------------------------------ mining

static func swing() -> void:
	var b := A.make_buf(0.3)
	var r := A.rng(11)
	A.noise_burst(b, 0.0, 0.26, 0.9, 0.085, 17.0, BAND, 420.0, 2600.0, 1.4, r)
	A.noise_burst(b, 0.02, 0.2, 0.35, 0.06, 20.0, BAND, 250.0, 900.0, 1.0, r)
	_finish("swing", b)

static func hit_rock(v: int) -> void:
	var p: float = [1.0, 0.86, 1.13][v]
	var b := A.make_buf(0.32)
	var r := A.rng(100 + v * 7)
	_rock_hit(b, r, p, 1.0)
	_finish("hit_rock_%d" % (v + 1), b)

static func hit_ore() -> void:
	var b := A.make_buf(0.55)
	var r := A.rng(120)
	_rock_hit(b, r, 1.05, 0.75)
	A.partials(b, 0.004, 1180.0, [1.0, 2.76, 5.40, 8.93], [0.5, 0.3, 0.16, 0.08], [9.0, 13.0, 18.0, 26.0], 0.5, 0.55)
	_finish("hit_ore", b)

static func hit_crystal() -> void:
	var b := A.make_buf(0.95)
	var r := A.rng(130)
	A.tone(b, 0.0, 0.09, 320.0, 150.0, 0.35, SINE, 0.0006, 30.0)
	A.noise_burst(b, 0.0, 0.015, 0.45, 0.0003, 160.0, HIGH, 4500.0, 4500.0, 0.8, r)
	A.partials(b, 0.002, 1760.0, [1.0, 2.01, 3.03, 4.22, 5.41], [0.5, 0.35, 0.25, 0.18, 0.12], [5.0, 7.0, 9.0, 12.0, 15.0], 0.9, 0.6, 0.0008, 3.5)
	A.partials(b, 0.03, 2637.0, [1.0, 2.0], [0.25, 0.12], [8.0, 12.0], 0.6, 0.35)
	_finish("hit_crystal", b)

static func hit_ice() -> void:
	var b := A.make_buf(0.45)
	var r := A.rng(140)
	A.tone(b, 0.0, 0.12, 210.0, 90.0, 0.45, SINE, 0.0006, 25.0)
	A.noise_burst(b, 0.0, 0.12, 0.6, 0.0004, 38.0, HIGH, 2600.0, 1800.0, 0.8, r)
	for k in 7:
		var st := 0.004 + r.randf() * 0.08
		var fc := r.randf_range(3000.0, 6500.0)
		A.noise_burst(b, st, 0.02, 0.45 * r.randf_range(0.5, 1.0), 0.0003, 140.0, BAND, fc, fc, 3.0, r)
	A.partials(b, 0.003, 2400.0, [1.0, 2.31, 3.72], [0.4, 0.25, 0.15], [20.0, 26.0, 32.0], 0.35, 0.4)
	_finish("hit_ice", b)

static func hit_metal() -> void:
	var b := A.make_buf(0.95)
	var r := A.rng(150)
	A.noise_burst(b, 0.0, 0.025, 0.55, 0.0003, 120.0, BAND, 2200.0, 2200.0, 1.1, r)
	A.partials(b, 0.001, 520.0, [1.0, 1.58, 2.36, 3.15, 4.43, 5.9], [0.55, 0.4, 0.3, 0.22, 0.14, 0.1], [5.0, 6.0, 8.0, 10.0, 12.0, 15.0], 0.9, 0.6, 0.0006, 1.3)
	A.tone(b, 0.0, 0.12, 180.0, 110.0, 0.35, SINE, 0.0006, 25.0)
	_finish("hit_metal", b)

static func break_rock(v: int) -> void:
	var p: float = [1.0, 0.88][v]
	var b := A.make_buf(0.75)
	var r := A.rng(160 + v * 13)
	A.tone(b, 0.0, 0.45, 115.0 * p, 38.0 * p, 1.0, SINE, 0.001, 8.5)
	A.noise_burst(b, 0.0, 0.5, 0.85, 0.002, 9.0, LOW, 3000.0 * p, 380.0 * p, 0.9, r)
	A.noise_burst(b, 0.0, 0.015, 0.5, 0.0003, 200.0, HIGH, 3000.0, 3000.0, 0.7, r)
	_grains(b, r, 12, 0.04, 0.55, 0.42, 800.0, 2900.0, true)
	_finish("break_rock_%d" % (v + 1), b)

static func break_crystal() -> void:
	var b := A.make_buf(1.1)
	var r := A.rng(170)
	A.noise_burst(b, 0.0, 0.5, 0.55, 0.001, 10.0, HIGH, 3200.0, 2400.0, 0.8, r)
	A.tone(b, 0.0, 0.2, 210.0, 100.0, 0.4, SINE, 0.0008, 18.0)
	for k in 18:
		var st := r.randf() * 0.45
		var f := r.randf_range(1800.0, 5200.0)
		A.partials(b, st, f, [1.0, 2.71], [0.6, 0.25], [r.randf_range(7.0, 14.0), 18.0], 0.55, 0.26 * (1.0 - st), 0.0005)
	_finish("break_crystal", b)


# ------------------------------------------------------------------ economy & pickups

static func pickup() -> void:
	var b := A.make_buf(0.22)
	A.tone(b, 0.0, 0.13, 620.0, 1500.0, 0.7, TRI, 0.002, 16.0)
	A.tone(b, 0.0, 0.1, 620.0, 1500.0, 0.18, PULSE, 0.002, 22.0, 0.25)
	A.tone(b, 0.045, 0.13, 1975.0, 1975.0, 0.2, SINE, 0.001, 24.0)
	_finish("pickup", b)

static func pickup_rare() -> void:
	var b := A.make_buf(0.75)
	var r := A.rng(210)
	var notes := [1047.0, 1319.0, 1568.0, 2093.0]
	for i in notes.size():
		A.tone(b, 0.055 * i, 0.25, notes[i], notes[i], 0.38, PULSE, 0.002, 9.0, 0.125)
		A.tone(b, 0.055 * i, 0.25, notes[i] * 2.0, notes[i] * 2.0, 0.12, SINE, 0.002, 12.0)
	A.noise_burst(b, 0.0, 0.5, 0.12, 0.05, 6.0, BAND, 5500.0, 7500.0, 1.5, r)
	A.partials(b, 0.22, 2093.0, [1.0, 2.0, 3.0], [0.5, 0.25, 0.12], [4.0, 6.0, 8.0], 0.5, 0.35)
	_finish("pickup_rare", b)

static func coin() -> void:
	var b := A.make_buf(0.45)
	A.tone(b, 0.0, 0.075, 988.0, 988.0, 0.45, PULSE, 0.001, 0.0, 0.5)
	A.tone(b, 0.07, 0.36, 1319.0, 1319.0, 0.45, PULSE, 0.001, 8.0, 0.5)
	A.partials(b, 0.07, 2637.0, [1.0, 2.41], [0.4, 0.2], [12.0, 18.0], 0.35, 0.25)
	_finish("coin", b)

static func sell() -> void:
	var b := A.make_buf(0.9)
	var r := A.rng(230)
	A.noise_burst(b, 0.0, 0.035, 0.7, 0.0004, 80.0, BAND, 1800.0, 1600.0, 2.0, r)
	A.noise_burst(b, 0.05, 0.035, 0.6, 0.0004, 80.0, BAND, 2300.0, 2000.0, 2.0, r)
	A.partials(b, 0.08, 2093.0, [1.0, 2.0, 2.76, 4.07], [0.6, 0.3, 0.22, 0.12], [5.0, 6.0, 9.0, 12.0], 0.8, 0.6)
	for k in 7:
		var st := 0.1 + r.randf() * 0.32
		A.partials(b, st, r.randf_range(3000.0, 5500.0), [1.0, 1.5], [0.6, 0.3], [20.0, 26.0], 0.2, 0.2)
	_finish("sell", b)

static func buy() -> void:
	var b := A.make_buf(0.7)
	var r := A.rng(240)
	A.tone(b, 0.0, 0.09, 784.0, 784.0, 0.4, PULSE, 0.002, 6.0, 0.25)
	A.tone(b, 0.08, 0.09, 1047.0, 1047.0, 0.4, PULSE, 0.002, 6.0, 0.25)
	A.tone(b, 0.16, 0.4, 1568.0, 1568.0, 0.42, PULSE, 0.002, 7.0, 0.25)
	A.tone(b, 0.16, 0.4, 784.0, 784.0, 0.25, TRI, 0.002, 6.0)
	for k in 4:
		A.partials(b, 0.18 + r.randf() * 0.2, r.randf_range(3200.0, 5200.0), [1.0, 1.5], [0.6, 0.3], [18.0, 24.0], 0.25, 0.16)
	_finish("buy", b)

static func geode_crack() -> void:
	var b := A.make_buf(0.7)
	var r := A.rng(250)
	A.noise_burst(b, 0.0, 0.07, 0.9, 0.0003, 50.0, BAND, 1500.0, 1200.0, 1.4, r)
	A.tone(b, 0.0, 0.14, 170.0, 80.0, 0.5, SINE, 0.0006, 22.0)
	A.noise_burst(b, 0.08, 0.22, 0.25, 0.05, 10.0, BAND, 600.0, 450.0, 1.5, r)
	A.tone(b, 0.08, 0.22, 95.0, 72.0, 0.12, SAW, 0.04, 6.0, 0.5, false, 0.0, 0.0, 600.0, 400.0)
	A.noise_burst(b, 0.3, 0.06, 0.9, 0.0003, 55.0, BAND, 2300.0, 1800.0, 1.4, r)
	A.tone(b, 0.3, 0.14, 230.0, 100.0, 0.45, SINE, 0.0006, 22.0)
	_grains(b, r, 5, 0.32, 0.5, 0.3, 1800.0, 3800.0)
	_finish("geode_crack", b)

static func geode_reveal() -> void:
	var b := A.make_buf(1.6)
	var r := A.rng(260)
	A.noise_burst(b, 0.0, 0.65, 0.35, 0.4, 6.0, BAND, 800.0, 6200.0, 1.6, r)
	for f in [523.0, 659.0, 784.0, 988.0, 1047.0]:
		A.tone(b, 0.35, 1.2, f, f, 0.2, TRI, 0.05, 2.4)
		A.tone(b, 0.35, 1.2, f * 2.0, f * 2.0, 0.06, SINE, 0.05, 3.0)
	var pent := [2093.0, 2349.0, 2637.0, 3136.0, 3520.0, 4186.0]
	for k in 11:
		var st := 0.35 + k * 0.07 + r.randf() * 0.03
		A.partials(b, st, pent[r.randi() % pent.size()], [1.0, 2.0], [0.5, 0.2], [9.0, 14.0], 0.45, 0.2)
	_finish("geode_reveal", b)


# ------------------------------------------------------------------ transport & machines (loops)

static func elevator_move() -> void:
	var L := 2.0
	var b := A.make_buf(L)
	var n := b.size()
	var r := A.rng(270)
	var f1 := A.qfreq(55.0, L)
	var f2 := A.qfreq(110.0, L)
	var hum := A.make_buf(L)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var dt := f1 / SR
		hum[i] = (2.0 * ph - 1.0 - A.polyblep(ph, dt)) * 0.5 + (1.0 - 4.0 * absf(ph2 - 0.5)) * 0.35
		ph = fmod(ph + dt, 1.0)
		ph2 = fmod(ph2 + f2 / SR, 1.0)
	A.loop_lowpass(hum, 320.0)
	A.add_scaled(b, hum, 0.8)
	var whir := A.loop_noise(n, BAND, 950.0, 2.2, r)
	for i in n:
		var t := float(i) / SR
		b[i] += whir[i] * (0.45 + 0.3 * sin(TAU * 8.0 * t / L))
	for k in 8:
		A.noise_burst(b, k * 0.25, 0.03, 0.18, 0.0005, 90.0, BAND, 2500.0, 2300.0, 2.0, r, true)
	_finish("elevator_move", b, true)

static func elevator_ding() -> void:
	var b := A.make_buf(1.5)
	A.partials(b, 0.0, 1319.0, [1.0, 2.0, 3.0, 4.2], [0.6, 0.25, 0.12, 0.06], [3.5, 5.0, 7.0, 9.0], 1.5, 0.6)
	A.partials(b, 0.0, 2637.0, [1.0], [0.15], [6.0], 1.0, 0.6)
	_finish("elevator_ding", b)

static func minecart() -> void:
	var L := 1.6
	var b := A.make_buf(L)
	var n := b.size()
	var r := A.rng(280)
	var rum := A.loop_noise(n, LOW, 230.0, 0.8, r)
	for i in n:
		var t := float(i) / SR
		b[i] += rum[i] * (1.1 + 0.25 * sin(TAU * 2.0 * t / L))
	var clack := A.loop_noise(n, BAND, 1700.0, 1.4, r)
	for i in n:
		b[i] += clack[i] * 0.06
	for st in [0.0, 0.09, 0.8, 0.89]:
		A.noise_burst(b, st, 0.045, 0.6, 0.0004, 70.0, BAND, 1200.0, 1000.0, 2.0, r, true)
		A.tone(b, st, 0.06, 130.0, 70.0, 0.45, SINE, 0.0005, 45.0, 0.5, true)
	A.partials(b, 0.4, 2350.0, [1.0, 1.5], [0.05, 0.03], [3.0, 4.0], 1.2, 1.0, 0.2, 2.0, true)
	_finish("minecart", b, true)

static func smelter() -> void:
	var L := 2.0
	var b := A.make_buf(L)
	var n := b.size()
	var r := A.rng(290)
	var roar := A.loop_noise(n, LOW, 380.0, 0.8, r)
	var whoosh := A.loop_noise(n, BAND, 700.0, 0.7, r)
	for i in n:
		var t := float(i) / SR
		var am := 0.75 + 0.22 * sin(TAU * t / L) + 0.1 * sin(TAU * 3.0 * t / L + 1.3)
		b[i] += roar[i] * 1.3 * am + whoosh[i] * 0.22 * (1.2 - am)
	for k in 16:
		var st := r.randf() * L
		var fc := r.randf_range(2500.0, 6000.0)
		A.noise_burst(b, st, r.randf_range(0.006, 0.016), r.randf_range(0.18, 0.5), 0.0003, 260.0, BAND, fc, fc, 1.5, r, true)
	_finish("smelter", b, true)

static func crusher() -> void:
	var L := 1.5
	var b := A.make_buf(L)
	var n := b.size()
	var r := A.rng(300)
	var drone := A.make_buf(L)
	var f := A.qfreq(73.0, L)
	var ph := 0.0
	for i in n:
		var dt := f / SR
		drone[i] = (1.0 if ph < 0.5 else -1.0) + A.polyblep(ph, dt) - A.polyblep(fposmod(ph + 0.5, 1.0), dt)
		ph = fmod(ph + dt, 1.0)
	A.loop_lowpass(drone, 260.0)
	A.add_scaled(b, drone, 0.45)
	var grind := A.loop_noise(n, BAND, 1100.0, 1.2, r)
	for i in n:
		var t := float(i) / SR
		b[i] += grind[i] * 0.55 * (0.45 + 0.55 * absf(sin(TAU * 4.5 * t / L)))
	for k in 3:
		A.tone(b, k * 0.5, 0.16, 95.0, 48.0, 0.65, SINE, 0.001, 22.0, 0.5, true)
		A.noise_burst(b, k * 0.5, 0.08, 0.4, 0.0005, 40.0, LOW, 1400.0, 500.0, 0.8, r, true)
	_finish("crusher", b, true)

static func machine_done() -> void:
	var b := A.make_buf(0.8)
	A.tone(b, 0.0, 0.06, 1568.0, 1568.0, 0.2, PULSE, 0.001, 20.0, 0.25)
	A.partials(b, 0.0, 784.0, [1.0, 2.0, 3.01], [0.5, 0.25, 0.12], [5.0, 7.0, 9.0], 0.6, 0.55)
	A.partials(b, 0.14, 1047.0, [1.0, 2.0, 3.01], [0.5, 0.25, 0.12], [5.0, 7.0, 9.0], 0.65, 0.6)
	_finish("machine_done", b)


# ------------------------------------------------------------------ UI

static func ui_click() -> void:
	var b := A.make_buf(0.05)
	var r := A.rng(310)
	A.tone(b, 0.0, 0.045, 1600.0, 900.0, 0.6, TRI, 0.0004, 60.0)
	A.noise_burst(b, 0.0, 0.005, 0.3, 0.0002, 400.0, HIGH, 4000.0, 4000.0, 0.7, r)
	_finish("ui_click", b)

static func ui_hover() -> void:
	var b := A.make_buf(0.04)
	A.tone(b, 0.0, 0.035, 2400.0, 2300.0, 0.5, SINE, 0.0008, 90.0)
	_finish("ui_hover", b)

static func ui_open() -> void:
	var b := A.make_buf(0.25)
	var r := A.rng(330)
	A.noise_burst(b, 0.0, 0.2, 0.28, 0.06, 18.0, BAND, 600.0, 2300.0, 1.2, r)
	A.tone(b, 0.0, 0.06, 660.0, 660.0, 0.35, PULSE, 0.001, 20.0, 0.25)
	A.tone(b, 0.055, 0.12, 990.0, 990.0, 0.38, PULSE, 0.001, 24.0, 0.25)
	_finish("ui_open", b)

static func ui_close() -> void:
	var b := A.make_buf(0.22)
	var r := A.rng(340)
	A.noise_burst(b, 0.0, 0.18, 0.25, 0.04, 20.0, BAND, 2200.0, 600.0, 1.2, r)
	A.tone(b, 0.0, 0.06, 990.0, 990.0, 0.35, PULSE, 0.001, 20.0, 0.25)
	A.tone(b, 0.055, 0.1, 660.0, 660.0, 0.35, PULSE, 0.001, 26.0, 0.25)
	_finish("ui_close", b)

static func ui_error() -> void:
	var b := A.make_buf(0.32)
	A.tone(b, 0.0, 0.11, 247.0, 247.0, 0.45, PULSE, 0.002, 4.0, 0.5, false, 0.0, 0.0, 2500.0, 2500.0)
	A.tone(b, 0.12, 0.18, 196.0, 190.0, 0.45, PULSE, 0.002, 5.0, 0.5, false, 12.0, 0.4, 2500.0, 1500.0)
	_finish("ui_error", b)


# ------------------------------------------------------------------ progression

static func skill_unlock() -> void:
	var b := A.make_buf(1.2)
	var r := A.rng(360)
	A.tone(b, 0.0, 0.26, 130.0, 260.0, 0.3, SINE, 0.02, 6.0)
	var notes := [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for i in notes.size():
		A.tone(b, 0.045 * i, 0.2, notes[i], notes[i], 0.32, PULSE, 0.002, 10.0, 0.125)
		A.tone(b, 0.045 * i, 0.2, notes[i] * 2.0, notes[i] * 2.0, 0.1, SINE, 0.002, 12.0)
	A.noise_burst(b, 0.0, 0.7, 0.2, 0.25, 5.0, BAND, 1500.0, 7000.0, 1.4, r)
	for f in [1047.0, 1319.0, 1568.0]:
		A.partials(b, 0.22, f, [1.0, 2.0, 3.0], [0.35, 0.15, 0.06], [3.0, 4.0, 5.0], 0.95, 0.4)
	_finish("skill_unlock", b)

static func skill_max() -> void:
	var b := A.make_buf(1.5)
	var r := A.rng(370)
	var notes := [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0, 2093.0]
	for i in notes.size():
		A.tone(b, 0.035 * i, 0.16, notes[i], notes[i], 0.3, PULSE, 0.002, 12.0, 0.125)
	for f in [1047.0, 1568.0, 2093.0]:
		A.tone(b, 0.26, 0.75, f, f, 0.24, PULSE, 0.01, 2.2, 0.25, false, 6.0, 0.25)
		A.partials(b, 0.26, f, [1.0, 2.0, 3.0], [0.3, 0.12, 0.05], [2.5, 3.5, 5.0], 1.1, 0.45)
	A.tone(b, 0.26, 0.6, 262.0, 262.0, 0.3, TRI, 0.01, 2.5)
	A.noise_burst(b, 0.2, 0.9, 0.18, 0.15, 4.0, BAND, 3000.0, 8000.0, 1.5, r)
	for k in 8:
		A.partials(b, 0.3 + r.randf() * 0.8, r.randf_range(3000.0, 6000.0), [1.0, 2.0], [0.5, 0.2], [10.0, 14.0], 0.3, 0.15)
	_finish("skill_max", b)

static func level_up() -> void:
	var b := A.make_buf(1.6)
	var r := A.rng(380)
	var notes := [784.0, 1047.0, 1319.0, 1568.0]
	for i in notes.size():
		A.tone(b, 0.085 * i, 0.1, notes[i], notes[i], 0.42, PULSE, 0.002, 4.0, 0.25)
		A.tone(b, 0.085 * i, 0.1, notes[i] * 0.5, notes[i] * 0.5, 0.18, TRI, 0.002, 4.0)
	A.tone(b, 0.34, 0.85, 2093.0, 2093.0, 0.42, PULSE, 0.004, 2.2, 0.25, false, 6.5, 0.3)
	A.tone(b, 0.34, 0.85, 1319.0, 1319.0, 0.2, SINE, 0.004, 2.0, 0.5, false, 6.5, 0.3)
	A.tone(b, 0.34, 0.6, 262.0, 262.0, 0.32, TRI, 0.004, 3.0)
	A.noise_burst(b, 0.34, 0.4, 0.3, 0.001, 8.0, HIGH, 5000.0, 4000.0, 0.8, r)
	for k in 10:
		A.partials(b, 0.36 + r.randf() * 0.9, r.randf_range(2600.0, 6000.0), [1.0, 2.0], [0.5, 0.2], [9.0, 14.0], 0.35, 0.15)
	_finish("level_up", b)

static func event_start() -> void:
	var b := A.make_buf(1.6)
	var r := A.rng(390)
	A.tone(b, 0.0, 0.9, 82.0, 55.0, 0.75, SINE, 0.002, 3.6)
	A.noise_burst(b, 0.0, 0.25, 0.4, 0.001, 14.0, LOW, 1200.0, 300.0, 0.8, r)
	for f in [293.7, 370.0, 440.0, 587.3]:
		A.tone(b, 0.05, 1.4, f, f, 0.18, SAW, 0.14, 1.6, 0.5, false, 5.0, 0.15, 400.0, 3200.0)
	A.partials(b, 0.32, 1175.0, [1.0, 2.0, 3.0], [0.4, 0.15, 0.06], [2.5, 3.5, 5.0], 1.2, 0.45)
	A.noise_burst(b, 0.1, 1.2, 0.14, 0.4, 3.0, BAND, 2500.0, 7000.0, 1.3, r)
	_finish("event_start", b)

static func event_end() -> void:
	var b := A.make_buf(1.3)
	var notes := [1760.0, 1480.0, 1175.0, 880.0]
	for i in notes.size():
		A.partials(b, 0.12 * i, notes[i], [1.0, 2.0, 3.0], [0.45, 0.18, 0.07], [3.5, 5.0, 7.0], 1.0, 0.5)
	A.tone(b, 0.36, 0.8, 293.7, 293.7, 0.2, TRI, 0.05, 2.5)
	_finish("event_end", b)

static func rare_discovery() -> void:
	var b := A.make_buf(1.4)
	var r := A.rng(410)
	var notes := [1047.0, 1175.0, 1319.0, 1568.0, 1760.0, 2093.0]
	for i in notes.size():
		A.partials(b, 0.06 * i, notes[i], [1.0, 2.0, 3.0], [0.45, 0.18, 0.08], [4.0, 6.0, 8.0], 0.9, 0.42)
	for f in [523.0, 659.0, 784.0]:
		A.tone(b, 0.3, 1.0, f, f, 0.15, TRI, 0.08, 2.4)
	A.noise_burst(b, 0.0, 1.0, 0.16, 0.3, 3.5, BAND, 4000.0, 8000.0, 1.6, r)
	_finish("rare_discovery", b)

static func legendary() -> void:
	var b := A.make_buf(1.7)
	var r := A.rng(420)
	A.tone(b, 0.0, 1.2, 65.0, 40.0, 0.8, SINE, 0.003, 2.8)
	A.noise_burst(b, 0.0, 0.5, 0.35, 0.002, 6.0, LOW, 2000.0, 250.0, 0.8, r)
	for f in [261.6, 392.0, 523.3, 659.3]:
		A.tone(b, 0.0, 1.6, f, f, 0.16, SAW, 0.2, 1.4, 0.5, false, 5.0, 0.12, 400.0, 3500.0)
	var casc := [2093.0, 1568.0, 1319.0, 1047.0, 1319.0, 1568.0, 2093.0, 2637.0]
	for i in casc.size():
		A.partials(b, 0.25 + 0.07 * i, casc[i], [1.0, 2.0, 3.0], [0.4, 0.15, 0.06], [4.0, 6.0, 8.0], 0.9, 0.36)
	A.noise_burst(b, 0.2, 1.3, 0.18, 0.3, 2.6, BAND, 3000.0, 8500.0, 1.5, r)
	for k in 10:
		A.partials(b, 0.4 + r.randf() * 1.0, r.randf_range(3000.0, 6500.0), [1.0, 2.0], [0.5, 0.2], [9.0, 14.0], 0.35, 0.14)
	_finish("legendary", b)


# ------------------------------------------------------------------ player

static func step(v: int) -> void:
	var b := A.make_buf(0.1)
	var r := A.rng(430 + v)
	var fc: float = [900.0, 1150.0][v]
	A.noise_burst(b, 0.0, 0.08, 0.7, 0.002, 45.0, LOW, fc, fc * 0.6, 0.8, r)
	A.tone(b, 0.0, 0.07, [95.0, 82.0][v], 58.0, 0.5, SINE, 0.001, 40.0)
	A.noise_burst(b, 0.01, 0.02, 0.1, 0.0005, 120.0, BAND, 3000.0, 3000.0, 2.0, r)
	_finish("step_%d" % (v + 1), b)

static func jump() -> void:
	var b := A.make_buf(0.18)
	var r := A.rng(440)
	A.tone(b, 0.0, 0.15, 300.0, 640.0, 0.32, PULSE, 0.003, 16.0, 0.5, false, 0.0, 0.0, 3000.0, 3000.0)
	A.noise_burst(b, 0.0, 0.14, 0.3, 0.03, 20.0, BAND, 1200.0, 2600.0, 1.2, r)
	_finish("jump", b)

static func land() -> void:
	var b := A.make_buf(0.2)
	var r := A.rng(450)
	A.tone(b, 0.0, 0.16, 115.0, 46.0, 0.9, SINE, 0.001, 20.0)
	A.noise_burst(b, 0.0, 0.14, 0.6, 0.001, 28.0, LOW, 1300.0, 380.0, 0.8, r)
	_finish("land", b)

static func ladder() -> void:
	var b := A.make_buf(0.14)
	var r := A.rng(460)
	A.partials(b, 0.0, 420.0, [1.0, 2.3, 3.9], [0.5, 0.3, 0.15], [30.0, 40.0, 50.0], 0.13, 0.6)
	A.noise_burst(b, 0.0, 0.03, 0.5, 0.0004, 80.0, BAND, 900.0, 800.0, 2.0, r)
	_finish("ladder", b)

static func hurt() -> void:
	var b := A.make_buf(0.38)
	var r := A.rng(470)
	A.tone(b, 0.0, 0.32, 330.0, 150.0, 0.45, SAW, 0.003, 7.0, 0.5, false, 0.0, 0.0, 1400.0, 500.0)
	A.tone(b, 0.0, 0.2, 140.0, 60.0, 0.6, SINE, 0.001, 16.0)
	A.noise_burst(b, 0.0, 0.12, 0.3, 0.001, 25.0, BAND, 800.0, 600.0, 1.0, r)
	_finish("hurt", b)

static func fuse() -> void:
	var L := 1.5
	var b := A.make_buf(L)
	var n := b.size()
	var r := A.rng(480)
	var hiss := A.loop_noise(n, HIGH, 3500.0, 0.8, r)
	for i in n:
		var t := float(i) / SR
		var am := 0.55 + 0.2 * sin(TAU * 21.0 * t / L) + 0.15 * sin(TAU * 34.0 * t / L + 0.7) + 0.1 * sin(TAU * 55.0 * t / L + 2.1)
		b[i] += hiss[i] * am * 0.6
	for k in 26:
		var st := r.randf() * L
		var fc := r.randf_range(1500.0, 5000.0)
		A.noise_burst(b, st, r.randf_range(0.004, 0.012), r.randf_range(0.2, 0.5), 0.0002, 300.0, BAND, fc, fc, 1.5, r, true)
	_finish("fuse", b, true)

static func explosion() -> void:
	var b := A.make_buf(1.7)
	var r := A.rng(490)
	A.tone(b, 0.0, 1.4, 72.0, 28.0, 1.0, SINE, 0.002, 3.4)
	A.noise_burst(b, 0.0, 1.6, 1.0, 0.003, 3.2, LOW, 3200.0, 170.0, 0.8, r)
	A.noise_burst(b, 0.0, 0.6, 0.5, 0.002, 6.0, BAND, 650.0, 400.0, 0.9, r)
	_grains(b, r, 22, 0.1, 1.2, 0.35, 700.0, 3200.0, true)
	_finish("explosion", b)

static func chest_open() -> void:
	var b := A.make_buf(1.0)
	var r := A.rng(500)
	A.noise_burst(b, 0.0, 0.03, 0.6, 0.0003, 90.0, BAND, 2500.0, 2300.0, 2.0, r)
	A.tone(b, 0.03, 0.36, 140.0, 215.0, 0.32, SAW, 0.05, 0.0, 0.5, false, 17.0, 1.2, 900.0, 1200.0)
	A.partials(b, 0.38, 2093.0, [1.0, 2.0], [0.4, 0.15], [6.0, 9.0], 0.6, 0.35)
	A.partials(b, 0.45, 2637.0, [1.0, 2.0], [0.4, 0.15], [6.0, 9.0], 0.55, 0.35)
	A.noise_burst(b, 0.38, 0.5, 0.14, 0.1, 5.0, BAND, 5000.0, 7500.0, 1.5, r)
	_finish("chest_open", b)

static func quest_complete() -> void:
	var b := A.make_buf(1.4)
	var r := A.rng(510)
	for i in 3:
		A.tone(b, 0.09 * i, 0.07, 784.0, 784.0, 0.4, PULSE, 0.002, 6.0, 0.25)
	A.tone(b, 0.27, 0.7, 1047.0, 1047.0, 0.4, PULSE, 0.004, 2.0, 0.25, false, 6.0, 0.25)
	A.tone(b, 0.27, 0.7, 1319.0, 1319.0, 0.28, PULSE, 0.004, 2.0, 0.5, false, 6.0, 0.25)
	A.tone(b, 0.27, 0.6, 262.0, 262.0, 0.3, TRI, 0.004, 3.0)
	A.partials(b, 0.27, 2093.0, [1.0, 2.0, 3.0], [0.3, 0.12, 0.05], [3.0, 4.5, 6.0], 1.0, 0.35)
	for k in 6:
		A.partials(b, 0.3 + r.randf() * 0.7, r.randf_range(3000.0, 6000.0), [1.0, 2.0], [0.5, 0.2], [10.0, 14.0], 0.3, 0.12)
	_finish("quest_complete", b)

static func notify() -> void:
	var b := A.make_buf(0.6)
	A.partials(b, 0.0, 1319.0, [1.0, 2.0, 3.0], [0.45, 0.15, 0.05], [6.0, 8.0, 10.0], 0.5, 0.5)
	A.partials(b, 0.1, 1976.0, [1.0, 2.0, 3.0], [0.45, 0.15, 0.05], [6.0, 8.0, 10.0], 0.5, 0.5)
	_finish("notify", b)

static func splash() -> void:
	var b := A.make_buf(0.6)
	var r := A.rng(530)
	A.noise_burst(b, 0.0, 0.5, 0.8, 0.004, 9.0, BAND, 1600.0, 650.0, 0.9, r)
	for k in 7:
		var st := 0.05 + r.randf() * 0.3
		var f := r.randf_range(500.0, 1200.0)
		A.tone(b, st, 0.045, f, f * 1.6, 0.3, SINE, 0.002, 30.0)
	for k in 4:
		A.partials(b, 0.08 + r.randf() * 0.25, r.randf_range(2000.0, 3200.0), [1.0], [0.5], [35.0], 0.1, 0.2)
	_finish("splash", b)

static func lava_bubble() -> void:
	var b := A.make_buf(0.42)
	var r := A.rng(540)
	A.tone(b, 0.0, 0.2, 90.0, 210.0, 0.7, SINE, 0.03, 6.0)
	A.noise_burst(b, 0.0, 0.18, 0.2, 0.03, 8.0, LOW, 500.0, 400.0, 0.8, r)
	A.noise_burst(b, 0.18, 0.03, 0.5, 0.0003, 90.0, BAND, 900.0, 800.0, 1.5, r)
	A.tone(b, 0.18, 0.08, 300.0, 120.0, 0.4, SINE, 0.0008, 30.0)
	_finish("lava_bubble", b)

static func place() -> void:
	var b := A.make_buf(0.16)
	var r := A.rng(550)
	A.tone(b, 0.0, 0.12, 220.0, 110.0, 0.7, SINE, 0.0008, 38.0)
	A.partials(b, 0.0, 600.0, [1.0, 2.4], [0.5, 0.25], [35.0, 45.0], 0.14, 0.4)
	A.noise_burst(b, 0.0, 0.01, 0.4, 0.0003, 200.0, BAND, 2000.0, 2000.0, 1.5, r)
	_finish("place", b)
