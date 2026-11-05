## DeepMine chiptune / SNES-style music. Each track is a seamless stereo loop (22050 Hz, -6 dBFS peak).
## Notes, release tails, echoes and reverb all wrap around the loop end so the file loops sample-perfectly.
extends RefCounted

const A = preload("res://audio_lib.gd")
const SR := 22050
const PEAK := 0.5 # -6 dBFS

const SINE := A.SINE
const PULSE := A.PULSE
const SAW := A.SAW
const TRI := A.TRI
const NESTRI := A.NESTRI
const BELL := A.BELL

const NOTE_PC := {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
const QUAL := {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "sus2": [0, 2, 7], "sus4": [0, 5, 7], "dim": [0, 3, 6], "add9": [0, 4, 7, 14], "5": [0, 7], "m9": [0, 3, 7, 10, 14]}

# ------------------------------------------------------------------ patches
const P_LEAD_PWM := {"wave": PULSE, "duty": 0.3, "pwm_rate": 0.7, "pwm_depth": 0.14, "a": 0.006, "d": 0.2, "s": 0.7, "r": 0.1, "vib_rate": 5.2, "vib_depth": 0.2, "vib_delay": 0.2, "lp": 5000.0, "vol": 0.26}
const P_STRINGS_LEAD := {"wave": SAW, "a": 0.03, "d": 0.3, "s": 0.75, "r": 0.15, "lp": 2000.0, "detune": 9.0, "vib_rate": 5.0, "vib_depth": 0.12, "vol": 0.13}
const P_FLUTE := {"wave": PULSE, "duty": 0.5, "lp": 1700.0, "a": 0.03, "d": 0.2, "s": 0.8, "r": 0.12, "vib_rate": 5.0, "vib_depth": 0.22, "vib_delay": 0.12, "vol": 0.34}
const P_RECORDER := {"wave": TRI, "a": 0.02, "d": 0.2, "s": 0.8, "r": 0.1, "vib_rate": 5.5, "vib_depth": 0.15, "vol": 0.24}
const P_PLUCK := {"wave": SAW, "pluck": true, "a": 0.002, "d": 7.0, "r": 0.06, "lp": 2200.0, "vol": 0.13}
const P_STONE_LEAD := {"wave": PULSE, "duty": 0.25, "a": 0.003, "d": 0.12, "s": 0.5, "r": 0.05, "lp": 4500.0, "vib_rate": 5.5, "vib_depth": 0.12, "vib_delay": 0.2, "vol": 0.27}
const P_MARIMBA := {"wave": BELL, "partials": [[1.0, 0.7, 9.0], [4.0, 0.2, 18.0], [10.0, 0.04, 30.0]], "a": 0.001, "s": 1.0, "d": 0.01, "r": 0.05, "vol": 0.2}
const P_SAW_LEAD := {"wave": SAW, "a": 0.01, "d": 0.25, "s": 0.7, "r": 0.12, "lp": 2400.0, "detune": 8.0, "vib_rate": 5.0, "vib_depth": 0.15, "vol": 0.2}
const P_PULSE_DOUBLE := {"wave": PULSE, "duty": 0.5, "a": 0.01, "d": 0.2, "s": 0.7, "r": 0.1, "lp": 1500.0, "vol": 0.13}
const P_BELL := {"wave": BELL, "partials": [[1.0, 0.6, 2.2], [2.0, 0.25, 3.5], [3.01, 0.14, 5.0], [4.2, 0.08, 7.0], [5.43, 0.05, 9.0]], "a": 0.002, "s": 1.0, "d": 0.01, "r": 0.45, "vol": 0.3}
const P_MUSICBOX := {"wave": BELL, "partials": [[1.0, 0.6, 3.0], [2.0, 0.3, 4.5], [3.0, 0.12, 6.0], [4.07, 0.06, 8.0]], "a": 0.002, "s": 1.0, "d": 0.01, "r": 0.5, "vol": 0.3}
const P_BELL_HI := {"wave": BELL, "partials": [[1.0, 0.6, 4.0], [2.76, 0.18, 7.0], [5.4, 0.06, 11.0]], "a": 0.002, "s": 1.0, "d": 0.01, "r": 0.3, "vol": 0.11}
const P_GLASS_ARP := {"wave": SINE, "pluck": true, "a": 0.002, "d": 6.0, "r": 0.1, "vol": 0.1}
const P_ARP12 := {"wave": PULSE, "duty": 0.125, "pluck": true, "a": 0.002, "d": 9.0, "r": 0.04, "lp": 4500.0, "vol": 0.085}
const P_BASS_TRI := {"wave": NESTRI, "a": 0.003, "d": 0.1, "s": 0.85, "r": 0.04, "vol": 0.42}
const P_BASS_SQ := {"wave": PULSE, "duty": 0.5, "a": 0.003, "d": 0.12, "s": 0.7, "r": 0.04, "lp": 700.0, "vol": 0.38, "sub": 0.4}
const P_BASS_SAW := {"wave": SAW, "a": 0.002, "d": 0.08, "s": 0.6, "r": 0.03, "lp": 900.0, "vol": 0.3, "sub": 0.55}
const P_BASS_SOFT := {"wave": TRI, "a": 0.25, "d": 0.5, "s": 0.8, "r": 0.7, "vol": 0.42, "sub": 0.25}
const P_PAD_STRINGS := {"wave": SAW, "a": 0.35, "d": 0.4, "s": 0.8, "r": 0.6, "lp": 1400.0, "detune": 12.0, "vol": 0.065, "vib_rate": 4.5, "vib_depth": 0.08}
const P_PAD_AIRY := {"wave": PULSE, "duty": 0.5, "pwm_rate": 0.4, "pwm_depth": 0.2, "a": 0.6, "d": 0.5, "s": 0.85, "r": 0.9, "lp": 1100.0, "vol": 0.06, "detune": 7.0}
const P_PAD_DARK := {"wave": SAW, "a": 0.4, "d": 0.4, "s": 0.8, "r": 0.5, "lp": 700.0, "detune": 10.0, "vol": 0.085}
const P_CHOIR := {"wave": SAW, "a": 0.5, "d": 0.5, "s": 0.85, "r": 0.8, "lp": 900.0, "detune": 14.0, "vib_rate": 5.0, "vib_depth": 0.12, "vib_delay": 0.3, "vol": 0.085}
const P_HORN := {"wave": SAW, "a": 0.05, "d": 0.3, "s": 0.75, "r": 0.2, "lp": 1600.0, "detune": 6.0, "vib_rate": 4.8, "vib_depth": 0.18, "vib_delay": 0.25, "vol": 0.22}
const P_MAGMA_LEAD := {"wave": SAW, "a": 0.004, "d": 0.18, "s": 0.6, "r": 0.06, "lp": 3200.0, "detune": 10.0, "vib_rate": 6.0, "vib_depth": 0.12, "vol": 0.2}


static func tracks() -> Array:
	return [
		{
			"name": "menu", "bpm": 112.0, "beats": 4,
			"lead": P_LEAD_PWM, "harm": P_STRINGS_LEAD, "harm_interval": -12,
			"bass": P_BASS_TRI, "bass_style": "root_oct",
			"arp": P_ARP12, "arp_style": "up16", "arp_base": 72,
			"pad": P_PAD_STRINGS,
			"echo": [3, 0.32, 0.28], "reverb": 0.15,
			"sections": {
				"A": {"chords": ["D", "A", "Bm", "G", "D", "A", "G", "A"],
					"melody": "F#5:4 A5:4 D6:6 C#6:2 | B5:2 A5:2 E5:4 A5:8 | F#5:4 B5:4 D6:4 C#6:2 B5:2 | D6:6 B5:2 G5:8 | A5:4 F#5:2 A5:2 D6:4 E6:4 | F#6:4 E6:2 C#6:2 A5:8 | B5:4 D6:4 G6:4 F#6:2 E6:2 | E6:8 C#6:4 A5:4"},
				"B": {"chords": ["Bm", "G", "D", "A", "Bm", "G", "Em", "A7"], "drums": "B",
					"melody": "D6:2 C#6:2 B5:4 F#5:4 B5:4 | G5:4 B5:2 D6:2 G6:6 F#6:2 | F#6:4 E6:2 D6:2 A5:8 | C#6:4 E6:4 A6:6 G6:2 | F#6:6 E6:2 D6:4 B5:4 | D6:4 B5:2 G5:2 B5:4 D6:4 | E6:4 G6:4 B5:4 E6:4 | C#6:4 E6:2 G6:2 A6:8"},
			},
			"form": [["A", {}], ["B", {}], ["A", {"harm": true, "drums": "B"}]],
			"drums": {
				"A": {"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.o.x.o.x.o.x.o."},
				"B": {"kick": "x.....x.x.....x.", "snare": "....x.......x...", "hat": "xoxoxoxoxoxoxoxo", "ohat": "..............x."},
				"fill": {"kick": "x.......x.......", "snare": "....x...x.x.xxxx", "hat": "x.o.x.o.........", "tom": "..........x.....", "ltom": "............x..."},
			},
		},
		{
			"name": "camp", "bpm": 120.0, "beats": 3,
			"lead": P_FLUTE, "harm": P_RECORDER, "harm_interval": -12,
			"bass": P_BASS_TRI, "bass_style": "waltz",
			"arp": P_PLUCK, "arp_style": "waltz_chord", "arp_base": 60,
			"pad": {},
			"echo": [4, 0.25, 0.22], "reverb": 0.12, "drum_vol": 0.45,
			"sections": {
				"A": {"chords": ["G", "C", "G", "D", "G", "C", "D", "G"],
					"melody": "B4:4 D5:4 G5:4 | E5:6 D5:2 C5:4 | D5:4 B4:4 G4:4 | A4:4 F#4:4 A4:4 | B4:4 D5:4 G5:4 | A5:6 G5:2 E5:4 | F#5:4 A5:4 F#5:4 | G5:12"},
				"B": {"chords": ["Em", "C", "G", "D", "Em", "Am", "D7", "G"], "drums": "B",
					"melody": "G5:4 B5:4 G5:4 | E5:6 G5:2 E5:4 | D5:4 G5:4 B5:4 | A5:8 R:4 | B5:4 G5:4 E5:4 | C6:6 B5:2 A5:4 | F#5:4 A5:4 C6:4 | B5:8 G5:4"},
			},
			"form": [["A", {}], ["A", {"harm": true, "drums": "B"}], ["B", {}], ["A", {"harm": true}]],
			"drums": {
				"A": {"kick": "x...........", "shaker": "o.o.x.o.x.o."},
				"B": {"kick": "x.....o.....", "shaker": "o.o.x.o.x.o.", "rim": "....x...x..."},
			},
		},
		{
			"name": "stone", "bpm": 104.0, "beats": 4,
			"lead": P_STONE_LEAD, "harm": P_MARIMBA, "harm_interval": 12,
			"bass": P_BASS_TRI, "bass_style": "walk",
			"arp": P_MARIMBA, "arp_style": "broken", "arp_base": 60, "arp_vol": 0.5,
			"pad": P_PAD_STRINGS, "pad_vol": 0.7,
			"echo": [3, 0.3, 0.25], "reverb": 0.15,
			"sections": {
				"A": {"chords": ["Am", "Am", "F", "G", "Am", "Am", "Dm", "E"],
					"melody": "A4:2 R:2 C5:2 E5:2 R:2 D5:2 C5:2 R:2 | B4:2 C5:2 A4:4 R:4 E4:4 | F4:2 A4:2 C5:2 F5:2 E5:4 C5:4 | D5:2 R:2 B4:2 G4:2 R:2 B4:2 D5:4 | A5:2 R:2 G5:2 E5:2 R:2 C5:2 D5:2 E5:2 | C5:4 A4:4 R:4 B4:2 C5:2 | D5:4 F5:4 A5:4 G5:2 F5:2 | E5:6 D5:2 B4:4 G#4:4"},
				"B": {"chords": ["F", "G", "Em", "Am", "F", "G", "E", "E7"], "drums": "B",
					"melody": "C6:4 A5:2 F5:2 A5:4 C6:4 | B5:4 G5:2 D5:2 G5:4 B5:4 | G5:4 E5:2 B4:2 E5:4 G5:2 A5:2 | A5:8 E5:4 C5:4 | F5:2 G5:2 A5:4 C6:4 A5:4 | G5:2 A5:2 B5:4 D6:4 B5:4 | G#5:4 B5:4 E6:4 D6:2 B5:2 | G#5:6 E5:2 D5:4 B4:4"},
			},
			"form": [["A", {}], ["B", {}], ["A", {"harm": true, "drums": "B"}]],
			"drums": {
				"A": {"kick": "x.....x...x.....", "snare": "....x.......x...", "hat": "x.o.x.o.x.o.x.o."},
				"B": {"kick": "x.....x...x.....", "snare": "....x.......x...", "shaker": "xoxoxoxoxoxoxoxo", "ohat": "......x.......x."},
				"fill": {"kick": "x.....x.........", "snare": "....x.....x.x.xx", "hat": "x.o.x.o.x.......", "tom": "........x.x.....", "ltom": "............x..."},
			},
		},
		{
			"name": "iron", "bpm": 92.0, "beats": 4,
			"lead": P_SAW_LEAD, "harm": P_PULSE_DOUBLE, "harm_interval": -12,
			"bass": P_BASS_SQ, "bass_style": "drive8",
			"arp": P_ARP12, "arp_style": "none", "arp_base": 64,
			"pad": P_PAD_DARK,
			"echo": [4, 0.28, 0.22], "reverb": 0.12,
			"sections": {
				"A": {"chords": ["Em", "Em", "C", "D", "Em", "Em", "C", "B"],
					"melody": "E5:6 G5:2 F#5:4 E5:4 | B4:8 R:4 D5:2 E5:2 | G5:6 E5:2 C5:4 E5:4 | F#5:6 D5:2 A4:8 | E5:4 F#5:4 G5:4 B5:4 | A5:6 G5:2 F#5:4 E5:4 | E5:4 G5:4 C6:6 B5:2 | B5:8 F#5:4 D#5:4"},
				"B": {"chords": ["Am", "Em", "C", "B", "Am", "Em", "F", "B7"], "drums": "B", "arp": "broken",
					"melody": "C6:4 B5:2 A5:2 E5:8 | G5:4 F#5:2 E5:2 B4:8 | E5:2 G5:2 C6:4 B5:4 G5:4 | F#5:6 D#5:2 B4:8 | A5:4 C6:4 E6:4 D6:2 C6:2 | B5:8 G5:4 E5:4 | F5:4 A5:4 C6:4 A5:4 | B5:6 A5:2 F#5:4 D#5:4"},
			},
			"form": [["A", {}], ["B", {}], ["A", {"harm": true, "drums": "B", "arp": "broken"}]],
			"drums": {
				"A": {"kick": "x.....x.x.......", "snare": "....x.......x...", "metal": "..o...o...o...o.", "hat": "o.o.o.o.o.o.o.o."},
				"B": {"kick": "x.....x.x.....x.", "snare": "....x.......x...", "metal": "..x..o....x..o.x", "hat": "o.o.o.o.o.o.o.o."},
				"fill": {"kick": "x.....x.........", "snare": "....x.......xxxx", "metal": "..o.............", "ltom": "........x.x....."},
			},
		},
		{
			"name": "crystal", "bpm": 80.0, "beats": 4,
			"lead": P_BELL, "harm": P_BELL_HI, "harm_interval": 12,
			"bass": P_BASS_SOFT, "bass_style": "drone_oct",
			"arp": P_GLASS_ARP, "arp_style": "up16", "arp_base": 72,
			"pad": P_PAD_AIRY, "pad_vol": 1.2,
			"echo": [3, 0.45, 0.33], "reverb": 0.35, "drum_vol": 0.38, "legato": 1.0,
			"sections": {
				"A": {"chords": ["Fmaj7", "Em7", "Dm7", "Cmaj7", "Fmaj7", "Em7", "Dm7", "Cmaj7"],
					"melody": "A5:4 C6:4 E6:8 | D6:4 B5:4 G5:8 | F5:4 A5:4 C6:6 D6:2 | E6:8 G5:4 B5:4 | C6:2 E6:2 A6:8 G6:4 | E6:4 D6:4 B5:8 | A5:4 C6:4 F6:4 E6:4 | G5:16"},
				"B": {"chords": ["Bbmaj7", "Am7", "Gm7", "Csus4", "Bbmaj7", "Am7", "Dm7", "C"], "drums": "B",
					"melody": "D6:4 F6:4 A6:8 | G6:4 E6:4 C6:8 | Bb5:4 D6:4 F6:6 G6:2 | F6:8 C6:8 | D6:2 F6:2 A6:4 C7:8 | A6:4 G6:4 E6:8 | F6:4 D6:4 A5:8 | E6:8 C6:8"},
			},
			"form": [["A", {}], ["B", {"harm": true}]],
			"drums": {
				"A": {"kick": "x.......o.......", "shaker": ".o.o.o.o.o.o.o.o"},
				"B": {"kick": "x.......o.......", "shaker": ".o.o.o.o.o.o.o.o", "rim": "........o......."},
			},
		},
		{
			"name": "frozen", "bpm": 72.0, "beats": 4,
			"lead": P_MUSICBOX, "harm": P_BELL_HI, "harm_interval": 12,
			"bass": P_BASS_SOFT, "bass_style": "drone",
			"arp": P_BELL_HI, "arp_style": "bell_sparse", "arp_base": 84,
			"pad": P_PAD_AIRY, "pad_vol": 1.3,
			"echo": [6, 0.45, 0.35], "reverb": 0.4, "drum_vol": 0.3, "legato": 1.0,
			"sections": {
				"A": {"chords": ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "C", "A"],
					"melody": "A5:4 R:2 F5:2 D6:8 | R:4 D6:2 C6:2 Bb5:8 | G5:4 Bb5:4 D6:4 R:4 | C#6:8 E6:4 R:4 | F6:4 E6:2 D6:2 A5:8 | R:4 F5:4 Bb5:4 D6:4 | E6:6 D6:2 C6:4 G5:4 | A5:16"},
				"B": {"chords": ["Gm", "Dm", "Bb", "A", "Gm", "Dm", "Eb", "A"],
					"melody": "D6:4 G6:4 F6:2 D6:2 Bb5:4 | A5:8 R:4 F5:4 | D6:4 F6:4 Bb6:8 | A6:4 G6:2 E6:2 C#6:8 | Bb5:4 D6:4 G6:4 F6:4 | E6:2 F6:2 D6:4 A5:8 | G6:4 Eb6:4 Bb5:8 | C#6:4 E6:4 A6:8"},
			},
			"form": [["A", {}], ["B", {}]],
			"drums": {
				"A": {"ltom": "x.......o......."},
			},
		},
		{
			"name": "magma", "bpm": 132.0, "beats": 4,
			"lead": P_MAGMA_LEAD, "harm": P_PULSE_DOUBLE, "harm_interval": -12,
			"bass": P_BASS_SAW, "bass_style": "drive16", "bass_oct": -12,
			"arp": P_ARP12, "arp_style": "up16", "arp_base": 72, "arp_vol": 0.7,
			"pad": P_PAD_DARK,
			"echo": [3, 0.2, 0.15], "reverb": 0.08, "drum_vol": 0.6,
			"sections": {
				"A": {"chords": ["Cm", "Cm", "Ab", "Bb", "Cm", "Cm", "Ab", "G"], "arp": "none",
					"melody": "C5:2 C5:2 Eb5:2 G5:4 F5:2 Eb5:2 D5:2 | C5:4 G4:4 C5:2 D5:2 Eb5:4 | Ab5:4 G5:2 F5:2 Eb5:4 C5:4 | D5:2 Eb5:2 F5:4 Bb5:6 Ab5:2 | G5:2 G5:2 Ab5:2 G5:4 F5:2 Eb5:2 F5:2 | G5:4 C6:4 Bb5:2 Ab5:2 G5:4 | F5:2 Ab5:2 C6:4 Eb6:4 D6:2 C6:2 | B5:8 G5:4 D5:4"},
				"B": {"chords": ["Fm", "Cm", "Ab", "G", "Fm", "Cm", "Db", "G7"], "drums": "B",
					"melody": "F5:4 Ab5:4 C6:4 F6:4 | Eb6:6 D6:2 C6:4 G5:4 | Ab5:4 C6:4 Eb6:4 C6:4 | D6:6 B5:2 G5:8 | F6:4 Eb6:2 C6:2 Ab5:4 F5:4 | G5:4 C6:4 Eb6:4 G6:4 | F6:4 Db6:4 Ab5:4 F5:4 | G5:2 B5:2 D6:2 F6:2 G6:8"},
			},
			"form": [["A", {}], ["B", {}], ["A", {"harm": true, "drums": "B", "arp": "up16"}]],
			"drums": {
				"A": {"kick": "x...x...x...x..x", "snare": "....x.......x...", "hat": "x.o.x.o.x.o.x.o."},
				"B": {"kick": "x..x..x.x..x..x.", "snare": "....x.......x..o", "hat": "xoxoxoxoxoxoxoxo", "ohat": "......x.......x."},
				"fill": {"kick": "x...x...x.......", "snare": "....x...x.xxxxxx", "tom": "........x.x.....", "ltom": "............x.x."},
			},
		},
		{
			"name": "ancient", "bpm": 84.0, "beats": 4,
			"lead": P_HORN, "harm": P_CHOIR, "harm_interval": -12,
			"bass": P_BASS_TRI, "bass_style": "drone_oct",
			"arp": P_BELL_HI, "arp_style": "broken", "arp_base": 72, "arp_vol": 0.9,
			"pad": P_CHOIR,
			"echo": [4, 0.35, 0.28], "reverb": 0.35, "drum_vol": 0.55,
			"sections": {
				"A": {"chords": ["Dm", "C", "G", "Dm", "Dm", "F", "G", "Am"],
					"melody": "D5:8 A5:8 | G5:4 E5:4 C5:8 | B5:6 A5:2 G5:4 D5:4 | F5:4 E5:4 D5:8 | A5:8 D6:8 | C6:4 A5:4 F5:8 | G5:4 B5:4 D6:6 C6:2 | A5:16"},
				"B": {"chords": ["Bb", "Am", "Gm", "A", "Bb", "C", "Dm", "A"], "drums": "B",
					"melody": "D6:4 F6:4 Bb5:8 | C6:4 E6:4 A5:8 | Bb5:4 D6:4 G6:6 F6:2 | E6:6 C#6:2 A5:8 | F6:8 D6:4 Bb5:4 | E6:4 G6:4 C6:8 | A5:4 D6:4 F6:4 E6:4 | C#6:4 E6:4 A6:8"},
			},
			"form": [["A", {}], ["B", {"harm": true}]],
			"drums": {
				"A": {"taiko": "x.....x...x.....", "rim": "....o.......o...", "shaker": "..o...o...o...o."},
				"B": {"taiko": "x.....x...x...o.", "rim": "....x.......x...", "shaker": "o.o.o.o.o.o.o.o.", "ltom": "..........o....."},
				"fill": {"taiko": "x.....x...x.x.xx", "rim": "....x...........", "tom": "........o.o....."},
			},
		},
	]


static func run(names: Array) -> void:
	for d in tracks():
		if names.is_empty() or names.has(d["name"]):
			var t0 := Time.get_ticks_msec()
			render_track(d)
			print("  rendered music/%s in %.1fs" % [d["name"], (Time.get_ticks_msec() - t0) / 1000.0])


# ------------------------------------------------------------------ parsing

static func parse_note(s: String) -> int:
	var name := s.substr(0, 1)
	var i := 1
	if s.length() > 2 and (s[1] == "#" or s[1] == "b"):
		name += s[1]
		i = 2
	var octave := int(s.substr(i))
	return 12 * (octave + 1) + int(NOTE_PC[name])


## Returns [[start_step, len_steps, midi_or_-1], ...]
static func parse_melody(s: String) -> Array:
	var out: Array = []
	var step := 0
	for tok in s.split(" ", false):
		if tok == "|":
			continue
		var parts := tok.split(":")
		var ln := int(parts[1])
		if parts[0] != "R":
			out.append([step, ln, parse_note(parts[0])])
		step += ln
	return out


static func melody_len(s: String) -> int:
	var step := 0
	for tok in s.split(" ", false):
		if tok == "|":
			continue
		step += int(tok.split(":")[1])
	return step


static func parse_chord(name: String) -> Array:
	var root := name.substr(0, 1)
	var rest := name.substr(1)
	if rest.length() > 0 and (rest[0] == "#" or rest[0] == "b"):
		root += rest[0]
		rest = rest.substr(1)
	return [int(NOTE_PC[root]), QUAL[rest]]


# ------------------------------------------------------------------ rendering

static func _mix(L: PackedFloat32Array, R: PackedFloat32Array, S: PackedFloat32Array, note: PackedFloat32Array, start: int, pan: float, send: float, gain: float = 1.0) -> void:
	var n := L.size()
	var gl := cos((pan + 1.0) * PI / 4.0) * gain
	var gr := sin((pan + 1.0) * PI / 4.0) * gain
	var sg := send * gain
	for j in note.size():
		var idx := (start + j) % n
		var v := note[j]
		L[idx] += v * gl
		R[idx] += v * gr
		S[idx] += v * sg


static func _h(a: int, b: int) -> float:
	var x: int = (a * 73856093) ^ (b * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65536.0


static func bass_events(style: String, root: int, ivs: Array, spb: int, bar: int) -> Array:
	var ev: Array = []
	var third: int = root + int(ivs[1]) if ivs.size() > 1 else root + 7
	var fifth: int = root + int(ivs[2]) if ivs.size() > 2 else root + 7
	match style:
		"root_oct":
			for s in range(0, spb, 2):
				ev.append([s, 2, root + (12 if (s / 2) % 2 == 1 else 0), 1.0 if s % 4 == 0 else 0.8])
		"walk":
			var tones := [root, third, fifth, third]
			for q in spb / 4:
				ev.append([q * 4, 4, tones[q % 4], 1.0 if q == 0 else 0.85])
		"drive8":
			for s in range(0, spb, 2):
				ev.append([s, 2, root + (12 if s % 8 == 6 else 0), 1.0 if s % 8 == 0 else 0.78])
		"drive16":
			for s in spb:
				ev.append([s, 1, root + (12 if s % 4 == 2 else 0), 1.0 if s % 4 == 0 else 0.68])
		"drone":
			ev.append([0, spb, root, 1.0])
		"drone_oct":
			ev.append([0, spb / 2, root, 1.0])
			ev.append([spb / 2, spb / 2, root + 12 if bar % 2 == 0 else fifth, 0.85])
		"waltz":
			ev.append([0, 4, root if bar % 2 == 0 else fifth - 12, 1.0])
		_:
			ev.append([0, spb, root, 1.0])
	return ev


static func arp_events(style: String, base: int, pc: int, ivs: Array, spb: int, bar: int) -> Array:
	var ev: Array = []
	var root := base + pc
	if root > base + 7:
		root -= 12
	var tones: Array = []
	for iv in ivs:
		if int(iv) < 12:
			tones.append(root + int(iv))
	match style:
		"up16":
			var seq := tones.duplicate()
			for t in tones:
				seq.append(t + 12)
			for s in spb:
				ev.append([s, 1, seq[s % seq.size()], 1.0 if s % 4 == 0 else 0.75])
		"updown8":
			var seq2 := tones.duplicate()
			seq2.append(tones[0] + 12)
			for k in range(tones.size() - 1, 0, -1):
				seq2.append(tones[k])
			for s in range(0, spb, 2):
				ev.append([s, 2, seq2[(s / 2) % seq2.size()], 0.85])
		"broken":
			var pat := [0, 2, 1, 2]
			var ext := tones.duplicate()
			ext.append(tones[0] + 12)
			for s in range(0, spb, 2):
				var k: int = pat[(s / 2) % 4]
				ev.append([s, 2, ext[mini(k, ext.size() - 1)], 0.9 if s % 4 == 0 else 0.7])
		"bell_sparse":
			for s in range(0, spb, 2):
				if _h(bar * 31 + 7, s) < 0.3:
					var t2: int = tones[int(_h(bar, s * 3 + 1) * tones.size()) % tones.size()]
					ev.append([s, 5, t2 + (12 if _h(s, bar) > 0.6 else 0), 0.6 + 0.4 * _h(bar + 3, s)])
		"waltz_chord":
			for s in [4, 8]:
				for t3 in tones:
					ev.append([s, 3, t3, 0.8])
		_:
			pass
	return ev


static func apply_echo(L: PackedFloat32Array, R: PackedFloat32Array, S: PackedFloat32Array, D: int, fb: float, wet: float, damp_hz: float = 3000.0) -> void:
	var n := L.size()
	var el := PackedFloat32Array()
	el.resize(n)
	el.fill(0.0)
	var er := PackedFloat32Array()
	er.resize(n)
	er.fill(0.0)
	var a := 1.0 - exp(-TAU * damp_hz / SR)
	var zl := 0.0
	var zr := 0.0
	for i in 2 * n:
		var idx := i % n
		var j := posmod(idx - D, n)
		zl += a * (er[j] - zl)
		zr += a * (el[j] - zr)
		el[idx] = S[j] + fb * zl
		er[idx] = fb * zr
	for i in n:
		L[i] += wet * el[i]
		R[i] += wet * er[i]


static func apply_reverb(L: PackedFloat32Array, R: PackedFloat32Array, S: PackedFloat32Array, amount: float) -> void:
	var n := L.size()
	var delays := [594, 678, 745, 808]
	var a := 1.0 - exp(-TAU * 2500.0 / SR)
	var g := 0.8
	for c in 4:
		var y := PackedFloat32Array()
		y.resize(n)
		y.fill(0.0)
		var d: int = delays[c]
		var z := 0.0
		for i in 2 * n:
			var idx := i % n
			z += a * (y[posmod(idx - d, n)] - z)
			y[idx] = S[idx] + g * z
		var gl := amount * (0.32 if c % 2 == 0 else 0.12)
		var gr := amount * (0.12 if c % 2 == 0 else 0.32)
		for i in n:
			L[i] += y[i] * gl
			R[i] += y[i] * gr


static func render_track(def: Dictionary) -> void:
	var bpm: float = def["bpm"]
	var beats: int = def.get("beats", 4)
	var spb := beats * 4
	var step_s := 60.0 / bpm / 4.0
	var sections: Dictionary = def["sections"]
	var bars: Array = []
	var mel: Array = []
	for entry in def["form"]:
		var key: String = entry[0]
		var ov: Dictionary = entry[1] if entry.size() > 1 else {}
		var sec: Dictionary = sections[key]
		var chords: Array = sec["chords"]
		var off := bars.size() * spb
		var ml := melody_len(sec["melody"])
		if ml != chords.size() * spb:
			push_warning("%s section %s melody is %d steps, expected %d" % [def["name"], key, ml, chords.size() * spb])
		for ev in parse_melody(sec["melody"]):
			mel.append([off + int(ev[0]), int(ev[1]), int(ev[2]), ov])
		for bi in chords.size():
			bars.append({"chord": chords[bi], "sec": sec, "ov": ov, "bi": bi, "n": chords.size()})
	var total_steps := bars.size() * spb
	var N := int(round(total_steps * step_s * SR))
	var L := PackedFloat32Array()
	L.resize(N)
	L.fill(0.0)
	var R := L.duplicate()
	var S := L.duplicate()
	var fr := func(step: int) -> int: return int(round(step * step_s * SR))

	# ---- lead melody (+ harmony doubling)
	var lead: Dictionary = def["lead"]
	var legato: float = def.get("legato", 0.9)
	for ev in mel:
		var ov2: Dictionary = ev[3]
		var midi: int = int(ev[2]) + int(ov2.get("oct", 0))
		var gate := maxf(0.05, ev[1] * step_s * legato)
		var vel := 0.9 + 0.1 * _h(int(ev[0]), midi)
		var note := A.render_note(A.mtof(midi), gate, lead, vel)
		_mix(L, R, S, note, fr.call(int(ev[0])), float(def.get("lead_pan", 0.0)), 0.6)
		if ov2.get("harm", false):
			var hn := A.render_note(A.mtof(midi + int(def.get("harm_interval", -12))), gate, def["harm"], vel)
			_mix(L, R, S, hn, fr.call(int(ev[0])), -0.25, 0.5)

	# ---- per bar parts
	var drum_kit := {
		"kick": A.drum_kick(), "snare": A.drum_snare(), "hat": A.drum_hat(), "ohat": A.drum_hat(SR, true),
		"shaker": A.drum_shaker(), "tom": A.drum_tom(180.0), "ltom": A.drum_tom(115.0), "metal": A.drum_metal(),
		"rim": A.drum_rim(), "taiko": A.drum_tom(68.0, SR, 0.9),
	}
	var drum_mix := {
		"kick": [0.9, 0.0, 0.0], "snare": [0.55, 0.05, 0.15], "hat": [0.22, 0.3, 0.05], "ohat": [0.18, 0.3, 0.1],
		"shaker": [0.22, -0.35, 0.1], "tom": [0.45, -0.25, 0.2], "ltom": [0.5, 0.25, 0.2], "metal": [0.28, 0.25, 0.25],
		"rim": [0.3, -0.15, 0.15], "taiko": [0.85, 0.0, 0.15],
	}
	var drum_vol: float = def.get("drum_vol", 0.55)
	var bass_p: Dictionary = def["bass"]
	var arp_p: Dictionary = def["arp"]
	var pad_p: Dictionary = def.get("pad", {})
	var pad_vol: float = def.get("pad_vol", 1.0)
	var arp_vol: float = def.get("arp_vol", 1.0)
	var drums: Dictionary = def.get("drums", {})
	for b in bars.size():
		var bar: Dictionary = bars[b]
		var ov3: Dictionary = bar["ov"]
		var sec2: Dictionary = bar["sec"]
		var ch := parse_chord(bar["chord"])
		var pc: int = ch[0]
		var ivs: Array = ch[1]
		var bar_step := b * spb
		# bass
		var broot := 48 + pc
		if broot > 52:
			broot -= 12
		broot += int(def.get("bass_oct", 0))
		for e in bass_events(def["bass_style"], broot, ivs, spb, b):
			var bn := A.render_note(A.mtof(int(e[2])), maxf(0.04, int(e[1]) * step_s * 0.92), bass_p, float(e[3]))
			_mix(L, R, S, bn, fr.call(bar_step + int(e[0])), 0.0, 0.05)
		# arp
		var astyle: String = ov3.get("arp", sec2.get("arp", def.get("arp_style", "none")))
		for e in arp_events(astyle, int(def.get("arp_base", 72)), pc, ivs, spb, b):
			var an := A.render_note(A.mtof(int(e[2])), maxf(0.03, int(e[1]) * step_s * 0.85), arp_p, float(e[3]) * arp_vol)
			_mix(L, R, S, an, fr.call(bar_step + int(e[0])), 0.35 if (int(e[0]) / 2) % 2 == 0 else -0.35, 0.7)
		# pad
		if not pad_p.is_empty():
			var voices: Array = []
			for iv in ivs:
				if voices.size() >= 4:
					break
				var t := 60 + pc + int(iv)
				while t < 55:
					t += 12
				while t > 70:
					t -= 12
				voices.append(t)
			for k in voices.size():
				var pn := A.render_note(A.mtof(int(voices[k])), spb * step_s * 0.98, pad_p, pad_vol)
				_mix(L, R, S, pn, fr.call(bar_step), -0.45 + 0.9 * float(k) / maxf(1.0, voices.size() - 1), 0.4)
		# drums
		var dkey: String = ov3.get("drums", sec2.get("drums", "A"))
		if drums.has("fill") and int(bar["bi"]) == int(bar["n"]) - 1:
			dkey = "fill"
		if drums.has(dkey):
			var pat: Dictionary = drums[dkey]
			for inst in pat:
				var line: String = pat[inst]
				var m: Array = drum_mix[inst]
				for s in mini(line.length(), spb):
					var c := line[s]
					if c == "x" or c == "o":
						var v := (1.0 if c == "x" else 0.55) * float(m[0]) * drum_vol
						_mix(L, R, S, drum_kit[inst], fr.call(bar_step + s), float(m[1]), float(m[2]), v)

	# ---- space
	var echo: Array = def.get("echo", [3, 0.3, 0.25])
	apply_echo(L, R, S, fr.call(int(echo[0])), float(echo[1]), float(echo[2]))
	var rv: float = def.get("reverb", 0.0)
	if rv > 0.0:
		apply_reverb(L, R, S, rv)
	A.loop_dc_block(L)
	A.loop_dc_block(R)
	# ---- master: joint normalize to -6 dBFS, interleave
	var pk := maxf(A.peak_of(L), A.peak_of(R))
	var g := PEAK / maxf(pk, 0.00001)
	var out := PackedFloat32Array()
	out.resize(N * 2)
	for i in N:
		out[i * 2] = L[i] * g
		out[i * 2 + 1] = R[i] * g
	A.save_wav("music/%s.wav" % def["name"], out, SR, true)
