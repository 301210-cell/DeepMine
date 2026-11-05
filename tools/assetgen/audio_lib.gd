## Audio synthesis helpers for DeepMine asset generators (SFX, music, ambience).
## Everything renders into PackedFloat32Array buffers and is saved as 16-bit WAV.
extends RefCounted

const SR: int = 22050

# wave ids
const SINE := 0
const PULSE := 1
const SAW := 2
const TRI := 3
const NESTRI := 4
const BELL := 5

# filter modes
const LOW := 0
const BAND := 1
const HIGH := 2

static func out_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../../assets/audio").simplify_path()

static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

static func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

static func make_buf(seconds: float, sr: int = SR) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(ceil(seconds * sr)))
	b.fill(0.0)
	return b

static func polyblep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	elif t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


## Zavalishin TPT state-variable filter (stable at any cutoff).
class SVF:
	var ic1: float = 0.0
	var ic2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var a3: float = 0.0
	var k: float = 1.0
	var mode: int = 0

	func _init(m: int = 0) -> void:
		mode = m

	func set_params(fc: float, q: float, sr: int) -> void:
		var g := tan(PI * clampf(fc, 10.0, sr * 0.48) / sr)
		k = 1.0 / maxf(q, 0.05)
		a1 = 1.0 / (1.0 + g * (g + k))
		a2 = g * a1
		a3 = g * a2

	func process(x: float) -> float:
		var v3 := x - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		if mode == 0:
			return v2
		elif mode == 1:
			return v1
		return x - k * v1 - v2


## Filtered noise burst. Envelope: linear attack then exponential decay `decay` (1/s).
## Cutoff sweeps exponentially fc0 -> fc1 over the burst. wrap=true writes modulo buffer size.
static func noise_burst(buf: PackedFloat32Array, start: float, dur: float, amp: float, attack: float, decay: float, mode: int, fc0: float, fc1: float, q: float, r: RandomNumberGenerator, wrap: bool = false, sr: int = SR) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var size := buf.size()
	var f := SVF.new(mode)
	var at := maxf(attack, 0.0003)
	var fade := mini(96, n / 3 + 1)
	for i in n:
		if i % 16 == 0:
			var tt := float(i) / float(maxi(1, n))
			f.set_params(fc0 * pow(fc1 / fc0, tt), q, sr)
		var t := float(i) / sr
		var e := t / at if t < at else exp(-decay * (t - at))
		var rem := n - i
		if rem < fade:
			e *= float(rem) / float(fade)
		var y := f.process(r.randf() * 2.0 - 1.0) * e * amp
		var idx := s0 + i
		if wrap:
			idx = posmod(idx, size)
		elif idx >= size:
			break
		buf[idx] += y


## Oscillator tone with exponential pitch glide f0 -> f1, attack + exp decay (decay=0 => sustain),
## optional vibrato and one-pole lowpass sweep lp0 -> lp1 (0 = no filter).
static func tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, wave: int, attack: float, decay: float, duty: float = 0.5, wrap: bool = false, vib_rate: float = 0.0, vib_depth: float = 0.0, lp0: float = 0.0, lp1: float = 0.0, sr: int = SR) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var size := buf.size()
	var at := maxf(attack, 0.0003)
	var fmul := pow(f1 / f0, 1.0 / float(maxi(1, n)))
	var f := f0
	var ph := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var lpa := 1.0
	var fade := mini(160, n / 3 + 1)
	for i in n:
		var t := float(i) / sr
		var e := t / at if t < at else exp(-decay * (t - at))
		var rem := n - i
		if rem < fade:
			e *= float(rem) / float(fade)
		var ff := f
		if vib_rate > 0.0:
			ff *= 1.0 + vib_depth * 0.05776 * sin(TAU * vib_rate * t)
		var dt := ff / sr
		var v := 0.0
		if wave == SINE:
			v = sin(TAU * ph)
		elif wave == PULSE:
			v = (1.0 if ph < duty else -1.0) + polyblep(ph, dt) - polyblep(fposmod(ph + 1.0 - duty, 1.0), dt)
		elif wave == SAW:
			v = 2.0 * ph - 1.0 - polyblep(ph, dt)
		elif wave == TRI:
			v = 1.0 - 4.0 * absf(ph - 0.5)
		else:
			v = round((1.0 - 4.0 * absf(ph - 0.5)) * 7.5) / 7.5
		if lp0 > 0.0:
			if i % 16 == 0:
				var tt := float(i) / float(maxi(1, n))
				lpa = 1.0 - exp(-TAU * (lp0 * pow(lp1 / lp0, tt)) / sr)
			y1 += lpa * (v - y1)
			y2 += lpa * (y1 - y2)
			v = y2
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
		f *= fmul
		var idx := s0 + i
		if wrap:
			idx = posmod(idx, size)
		elif idx >= size:
			break
		buf[idx] += v * e * amp


## Sum of exponentially decaying sine partials (bells, metal, glass). detune_hz adds a second
## slightly detuned copy of every partial for shimmering beats.
static func partials(buf: PackedFloat32Array, start: float, f: float, ratios: Array, amps: Array, decays: Array, dur: float, amp: float, attack: float = 0.0008, detune_hz: float = 0.0, wrap: bool = false, sr: int = SR) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var size := buf.size()
	var at := maxf(attack, 0.0003)
	var fade := mini(200, n / 3 + 1)
	var copies := 2 if detune_hz != 0.0 else 1
	for k in ratios.size():
		for c in copies:
			var fr: float = f * float(ratios[k]) + (detune_hz * (k + 1) if c == 1 else 0.0)
			if fr >= sr * 0.47:
				continue
			var w := TAU * fr / sr
			var a: float = float(amps[k]) * amp * (0.6 if copies == 2 else 1.0)
			var mul := exp(-float(decays[k]) / sr)
			var ph := 0.0
			var env := a
			for i in n:
				var e := env
				if i < at * sr:
					e *= float(i) / (at * sr)
				var rem := n - i
				if rem < fade:
					e *= float(rem) / float(fade)
				var idx := s0 + i
				if wrap:
					idx = posmod(idx, size)
				elif idx >= size:
					break
				buf[idx] += sin(ph) * e
				ph += w
				env *= mul


## Seamless filtered noise loop of n samples (filter run circularly twice for steady state).
static func loop_noise(n: int, mode: int, fc: float, q: float, r: RandomNumberGenerator, sr: int = SR) -> PackedFloat32Array:
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = r.randf() * 2.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	var f := SVF.new(mode)
	f.set_params(fc, q, sr)
	for i in 2 * n:
		var y := f.process(src[i % n])
		if i >= n:
			out[i - n] = y
	return out


## Circular two-pole lowpass of a whole loop buffer (in place).
static func loop_lowpass(buf: PackedFloat32Array, fc: float, sr: int = SR) -> void:
	var n := buf.size()
	var a := 1.0 - exp(-TAU * fc / sr)
	var y1 := 0.0
	var y2 := 0.0
	var src := buf.duplicate()
	for i in 2 * n:
		y1 += a * (src[i % n] - y1)
		y2 += a * (y1 - y2)
		if i >= n:
			buf[i - n] = y2


## Circular DC blocker (in place).
static func loop_dc_block(buf: PackedFloat32Array) -> void:
	var n := buf.size()
	var src := buf.duplicate()
	var xp := 0.0
	var yp := 0.0
	for i in 2 * n:
		var x := src[i % n]
		var y := x - xp + 0.997 * yp
		xp = x
		yp = y
		if i >= n:
			buf[i - n] = y


## Integer-cycle frequency so an oscillator loops seamlessly over `seconds`.
static func qfreq(f: float, seconds: float) -> float:
	return maxf(1.0, round(f * seconds)) / seconds


static func add_scaled(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float) -> void:
	for i in mini(dst.size(), src.size()):
		dst[i] += src[i] * gain


static func fade(buf: PackedFloat32Array, fin: float, fout: float, sr: int = SR) -> void:
	var n := buf.size()
	var ni := int(fin * sr)
	var no := int(fout * sr)
	for i in mini(ni, n):
		buf[i] *= float(i) / float(maxi(1, ni))
	for i in mini(no, n):
		buf[n - 1 - i] *= float(i) / float(maxi(1, no))


static func peak_of(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for v in buf:
		p = maxf(p, absf(v))
	return p


static func normalize(buf: PackedFloat32Array, target: float) -> void:
	var p := peak_of(buf)
	if p < 0.000001:
		return
	var g := target / p
	for i in buf.size():
		buf[i] *= g


## Trim trailing near-silence (keeps a small tail) for one-shot SFX.
static func trim_tail(buf: PackedFloat32Array, thresh: float = 0.0006, keep: float = 0.02, sr: int = SR) -> PackedFloat32Array:
	var last := buf.size() - 1
	while last > 0 and absf(buf[last]) < thresh:
		last -= 1
	var end := mini(buf.size(), last + int(keep * sr))
	var out := buf.slice(0, end)
	fade(out, 0.0, minf(0.012, keep), sr)
	return out


static func save_wav(rel: String, data: PackedFloat32Array, sr: int = SR, stereo: bool = false) -> void:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	var peak := 0.0
	var sum := 0.0
	for i in data.size():
		var v := clampf(data[i], -1.0, 1.0)
		peak = maxf(peak, absf(v))
		sum += v * v
		bytes.encode_s16(i * 2, int(round(v * 32767.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = stereo
	w.data = bytes
	var path := out_dir().path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := w.save_to_wav(path)
	var frames := data.size() / (2 if stereo else 1)
	var rms := sqrt(sum / maxf(1.0, data.size()))
	print("%-28s %6.2fs  peak %6.1f dBFS  rms %6.1f dBFS  %s  err=%d" % [rel, float(frames) / sr, linear_to_db(maxf(peak, 0.00001)), linear_to_db(maxf(rms, 0.00001)), ("stereo" if stereo else "mono"), err])


## ---------------------------------------------------------------- music voices

static func env_value(t: float, gate: float, a: float, d: float, s: float, pluck: bool) -> float:
	var tt := minf(t, gate)
	if tt < a:
		return tt / a
	if pluck:
		return exp(-(tt - a) * d)
	if tt < a + d:
		return 1.0 - (1.0 - s) * (tt - a) / d
	return s


## Render one melodic note with a patch dictionary. Returns a mono buffer (gate + release long).
## Patch keys: wave, duty, pwm_rate, pwm_depth, a, d, s, r, pluck(bool: d = decay rate),
## vib_rate, vib_depth (semitones), vib_delay, lp (Hz), detune (cents, 2nd osc), sub (sine sub-octave mix),
## vol, glide (semitones from above/below, fast), partials [[ratio, amp, decay], ...] for BELL.
static func render_note(freq: float, gate: float, p: Dictionary, vel: float = 1.0, sr: int = SR) -> PackedFloat32Array:
	var wave: int = p.get("wave", PULSE)
	var a: float = maxf(float(p.get("a", 0.004)), 0.0005)
	var d: float = maxf(float(p.get("d", 0.12)), 0.001)
	var s: float = p.get("s", 0.6)
	var r: float = maxf(float(p.get("r", 0.08)), 0.003)
	var pluck: bool = p.get("pluck", false)
	var duty: float = p.get("duty", 0.5)
	var pwm_rate: float = p.get("pwm_rate", 0.0)
	var pwm_depth: float = p.get("pwm_depth", 0.0)
	var vib_rate: float = p.get("vib_rate", 0.0)
	var vib_depth: float = float(p.get("vib_depth", 0.0)) * 0.05776
	var vib_delay: float = p.get("vib_delay", 0.15)
	var lp: float = p.get("lp", 0.0)
	var detune: float = p.get("detune", 0.0)
	var sub: float = p.get("sub", 0.0)
	var vol: float = float(p.get("vol", 0.25)) * vel
	var glide: float = p.get("glide", 0.0)
	var n := int((gate + r) * sr)
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	var eg := env_value(gate, gate, a, d, s, pluck)
	var lpa := 1.0 if lp <= 0.0 else 1.0 - exp(-TAU * lp / sr)
	var det := pow(2.0, detune / 1200.0)
	var y1 := 0.0
	var y2 := 0.0
	var ph := 0.0
	var ph2 := 0.37
	var phs := 0.0
	# bell partial state
	var pr: Array = p.get("partials", [])
	var pw := PackedFloat32Array()
	var pa := PackedFloat32Array()
	var pm := PackedFloat32Array()
	var pp := PackedFloat32Array()
	if wave == BELL:
		for k in pr.size():
			pw.append(TAU * freq * float(pr[k][0]) / sr)
			pa.append(float(pr[k][1]))
			pm.append(exp(-float(pr[k][2]) / sr))
			pp.append(0.0)
	for i in n:
		var t := float(i) / sr
		var e: float
		if t < gate:
			if t < a:
				e = t / a
			elif pluck:
				e = exp(-(t - a) * d)
			elif t < a + d:
				e = 1.0 - (1.0 - s) * (t - a) / d
			else:
				e = s
		else:
			e = eg * (1.0 - (t - gate) / r)
		var f := freq
		if glide != 0.0:
			f *= 1.0 + (pow(2.0, glide / 12.0) - 1.0) * exp(-t * 35.0)
		if vib_rate > 0.0 and t > vib_delay:
			f *= 1.0 + vib_depth * sin(TAU * vib_rate * (t - vib_delay)) * minf(1.0, (t - vib_delay) * 3.0)
		var dt := f / sr
		var v := 0.0
		if wave == SINE:
			v = sin(TAU * ph)
		elif wave == PULSE:
			var du := duty
			if pwm_depth > 0.0:
				du = clampf(duty + pwm_depth * sin(TAU * pwm_rate * t), 0.05, 0.95)
			v = (1.0 if ph < du else -1.0) + polyblep(ph, dt) - polyblep(fposmod(ph + 1.0 - du, 1.0), dt)
			if detune != 0.0:
				var dt2 := dt * det
				v += (1.0 if ph2 < du else -1.0) + polyblep(ph2, dt2) - polyblep(fposmod(ph2 + 1.0 - du, 1.0), dt2)
				v *= 0.55
				ph2 += dt2
				if ph2 >= 1.0:
					ph2 -= 1.0
		elif wave == SAW:
			v = 2.0 * ph - 1.0 - polyblep(ph, dt)
			if detune != 0.0:
				var dt3 := dt * det
				v += 2.0 * ph2 - 1.0 - polyblep(ph2, dt3)
				v *= 0.55
				ph2 += dt3
				if ph2 >= 1.0:
					ph2 -= 1.0
		elif wave == TRI:
			v = 1.0 - 4.0 * absf(ph - 0.5)
		elif wave == NESTRI:
			v = round((1.0 - 4.0 * absf(ph - 0.5)) * 7.5) / 7.5
		else:
			for k in pw.size():
				v += sin(pp[k]) * pa[k]
				pp[k] += pw[k] * (f / freq)
				pa[k] *= pm[k]
		if sub > 0.0:
			v += sub * sin(TAU * phs)
			phs += dt * 0.5
			if phs >= 1.0:
				phs -= 1.0
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
		if lp > 0.0:
			y1 += lpa * (v - y1)
			y2 += lpa * (y1 - y2)
			v = y2
		out[i] = v * e * vol
	return out


## ---------------------------------------------------------------- drums (mono one-shots)

static func drum_kick(sr: int = SR, base: float = 44.0, punch: float = 110.0, length: float = 0.38) -> PackedFloat32Array:
	var b := make_buf(length, sr)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / sr
		var f := base + punch * exp(-t * 30.0)
		ph += TAU * f / sr
		b[i] = sin(ph) * exp(-t * 8.5) * 0.95
	var r := rng(901)
	noise_burst(b, 0.0, 0.006, 0.35, 0.0003, 400.0, HIGH, 2500.0, 2500.0, 0.7, r, false, sr)
	fade(b, 0.0, 0.03, sr)
	return b

static func drum_snare(sr: int = SR, tone_f: float = 185.0) -> PackedFloat32Array:
	var b := make_buf(0.28, sr)
	var r := rng(902)
	tone(b, 0.0, 0.12, tone_f * 1.15, tone_f, 0.55, TRI, 0.0005, 28.0, 0.5, false, 0.0, 0.0, 0.0, 0.0, sr)
	noise_burst(b, 0.0, 0.27, 0.85, 0.0005, 17.0, BAND, 3200.0, 2200.0, 0.75, r, false, sr)
	noise_burst(b, 0.0, 0.12, 0.35, 0.0005, 35.0, HIGH, 5000.0, 5000.0, 0.7, r, false, sr)
	return b

static func drum_hat(sr: int = SR, open: bool = false) -> PackedFloat32Array:
	var b := make_buf(0.32 if open else 0.07, sr)
	var r := rng(903 if open else 904)
	noise_burst(b, 0.0, b.size() / float(sr), 0.7, 0.0004, 11.0 if open else 75.0, HIGH, 7000.0, 6500.0, 0.8, r, false, sr)
	return b

static func drum_shaker(sr: int = SR) -> PackedFloat32Array:
	var b := make_buf(0.09, sr)
	var r := rng(905)
	noise_burst(b, 0.0, 0.09, 0.6, 0.012, 48.0, BAND, 5200.0, 6000.0, 1.1, r, false, sr)
	return b

static func drum_tom(f: float, sr: int = SR, length: float = 0.5) -> PackedFloat32Array:
	var b := make_buf(length, sr)
	var r := rng(906 + int(f))
	tone(b, 0.0, length, f * 1.3, f * 0.8, 0.9, SINE, 0.0008, 7.0, 0.5, false, 0.0, 0.0, 0.0, 0.0, sr)
	noise_burst(b, 0.0, 0.08, 0.25, 0.0005, 40.0, LOW, 1500.0, 600.0, 0.7, r, false, sr)
	return b

static func drum_metal(f: float = 640.0, sr: int = SR) -> PackedFloat32Array:
	var b := make_buf(0.45, sr)
	var r := rng(907)
	partials(b, 0.0, f, [1.0, 2.41, 3.93, 5.62, 7.1], [0.6, 0.35, 0.22, 0.14, 0.08], [9.0, 12.0, 16.0, 21.0, 28.0], 0.45, 0.8, 0.0005, 0.0, false, sr)
	noise_burst(b, 0.0, 0.02, 0.4, 0.0003, 120.0, BAND, 3000.0, 3000.0, 1.0, r, false, sr)
	return b

static func drum_rim(sr: int = SR) -> PackedFloat32Array:
	var b := make_buf(0.06, sr)
	var r := rng(908)
	tone(b, 0.0, 0.05, 900.0, 820.0, 0.6, TRI, 0.0003, 80.0, 0.5, false, 0.0, 0.0, 0.0, 0.0, sr)
	noise_burst(b, 0.0, 0.02, 0.4, 0.0003, 150.0, BAND, 2500.0, 2500.0, 1.2, r, false, sr)
	return b
