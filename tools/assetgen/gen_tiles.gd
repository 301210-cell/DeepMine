## Generates terrain.png, ores.png, backwalls.png, special.png, crack.png
extends SceneTree

const PX = preload("res://px.gd")
const L = preload("res://tilelib.gd")

var P := {} # palettes
var pts_cache := {}

func _init() -> void:
	_palettes()
	gen_terrain()
	gen_ores()
	gen_backwalls()
	gen_special()
	gen_crack()
	quit()

func _palettes() -> void:
	P.stone = L.pal(["1c1822", "2f2833", "4a3f45", "655650", "837160", "a08b72"])
	P.hard = L.pal(["141722", "232838", "363c50", "4e566b", "6a7488", "8e98aa"])
	P.dirt = L.pal(["1e130e", "34211a", "4f3222", "6b4630", "8a5d3c", "a8774c"])
	P.grass = L.pal(["0f2a1a", "1b4626", "2a672e", "418d38", "66b443", "9edb5e"])
	P.dark = L.pal(["111015", "1d1b22", "2b2830", "3c3841", "514b54", "686068"])
	P.rust = L.pal(["3a1a0e", "5e2a14", "8a4520", "b8652c", "d88a48"])
	P.basalt = L.pal(["100d10", "1c1619", "2a2124", "3b2f30", "50403c", "68564c"])
	P.crys = L.pal(["0a0c22", "121836", "1b234c", "263162", "34447c", "475a98"])
	P.gemrock = L.pal(["120a24", "1f143a", "2e1d54", "40296e", "553888", "6e4ea4"])
	P.frost = L.pal(["131b2b", "1f2e45", "304464", "476086", "6582a8", "8eaccb"])
	P.ice = L.pal(["17366a", "214f94", "306cbc", "4a90da", "79b8ef", "b8e2ff"])
	P.snow = L.pal(["7c98bc", "9cb6d6", "bcd2ea", "d8e6f6", "ecf4fc", "ffffff"])
	P.volc = L.pal(["140909", "241010", "381814", "4e2219", "662e1f", "84402e"])
	P.scorch = L.pal(["0d0b0d", "181416", "252022", "352e30", "473d3d", "5c4f4b"])
	P.crust = L.pal(["0f0707", "1d0e0d", "2c1512", "3d1c16", "52261b"])
	P.glow = L.pal(["5a1206", "a82a08", "f05a12", "ffa030", "fff0a0"])
	P.abrick = L.pal(["0d1517", "172427", "223538", "2f4749", "3f5d5b", "54766e"])
	P.gold = L.pal(["5a3606", "9a6410", "d29a22", "f6cc48", "fff0a0"])
	P.teal = L.pal(["0a3a38", "10706a", "1fb4a2", "4ff0d0", "c8fff4"])
	P.ruin = L.pal(["191715", "2b2723", "3e3832", "544c42", "6c6253", "867a66"])
	P.metal = L.pal(["18110a", "2c1e11", "443019", "604422", "84602e", "aa8444", "d4b464"])
	P.bed = L.pal(["06040b", "0e0a16", "181122", "231831", "302143", "432f5c"])
	P.steel = L.pal(["13161d", "212631", "323a48", "485264", "647084", "8b97aa"])
	P.iron = L.pal(["231e20", "3a3235", "565055", "766e72", "989094", "bab4b6"])
	P.wood = L.pal(["26150b", "40240f", "5a3617", "7a4b21", "99632f", "b67e42"])
	P.purple = L.pal(["2a0f4e", "4a1f86", "7036c6", "9c66f0", "cfaeff"])
	P.cyan = L.pal(["0a4a6e", "1088b0", "2cc8e8", "5ff2ff", "d8ffff"])
	P.blue = L.pal(["0c1a5a", "163aa0", "2a66e0", "5a9cff", "b8dcff"])

func pts(key: String, grid: int, seed: int, jit: float = 0.85) -> Array[Vector2]:
	var k := "%s_%d_%d" % [key, grid, seed]
	if not pts_cache.has(k):
		pts_cache[k] = L.jitter_points(grid, seed, jit)
	return pts_cache[k]

# -------------------------------------------------------------------- base patterns
func cobble(x: int, y: int, grid: int, seed: int, ramp: Array[Color], mortar: float = 0.9, mortar_col: int = 0) -> Color:
	var r := L.vor(Vector2(x + 0.5, y + 0.5), pts("cob", grid, seed))
	var d1: float = r[0]
	var d2: float = r[1]
	var idx: int = r[2]
	var q: Vector2 = r[3]
	var edge := d2 - d1
	if edge < mortar:
		return ramp[mortar_col]
	var base := 2 + int(L.h01(idx, 3, seed) * 2.0)
	var off := Vector2(x + 0.5, y + 0.5) - q
	var lit := (-off.x * 0.6 - off.y * 0.8) / maxf(off.length(), 0.001)
	var i := base
	if edge < mortar + 1.4:
		if lit > 0.3:
			i += 1
		elif lit < -0.3:
			i -= 1
	var n := L.h01(x, y, seed + 5)
	if n > 0.94:
		i += 1
	elif n < 0.05:
		i -= 1
	return L.ri(ramp, i)

func facets(x: int, y: int, grid: int, seed: int, ramp: Array[Color]) -> Color:
	var r := L.vor(Vector2(x + 0.5, y + 0.5), pts("fac", grid, seed, 0.95))
	var d1: float = r[0]
	var d2: float = r[1]
	var idx: int = r[2]
	var q: Vector2 = r[3]
	if d2 - d1 < 0.8:
		return ramp[0]
	var off := Vector2(x + 0.5, y + 0.5) - q
	var ang := L.h01(idx, 9, seed) * TAU
	var side := off.dot(Vector2(cos(ang), sin(ang)))
	var i := 2 + int(L.h01(idx, 4, seed) * 1.99)
	if side > 0.0:
		i += 1
	if d2 - d1 < 1.6 and (off.x + off.y) < 0.0:
		i += 1
	return L.ri(ramp, i)

func noisy(x: int, y: int, seed: int, ramp: Array[Color], lo: int = 1, hi: int = 3) -> Color:
	var v := 0.65 * PX.vnoise_wrap(x, y, 5.0, 16, seed) + 0.35 * L.h01(x, y, seed + 1)
	return L.ri(ramp, lo + int(v * (hi - lo + 1)))

func slab(x: int, y: int, seed: int, ramp: Array[Color]) -> Color:
	var r := L.vor(Vector2(x + 0.5, y + 0.5), pts("slab", 2, seed, 0.9))
	var edge: float = float(r[1]) - float(r[0])
	if edge < 0.8:
		return ramp[1]
	var idx: int = r[2]
	var q: Vector2 = r[3]
	var off := Vector2(x + 0.5, y + 0.5) - q
	var i := 2 + int(L.h01(idx, 3, seed) * 1.6)
	if edge < 1.9 and off.x + off.y < -1.0:
		i += 1
	elif edge < 1.6 and off.x + off.y > 1.0:
		i -= 1
	var n := PX.vnoise_wrap(x, y, 4.0, 16, seed + 1)
	if n > 0.72:
		i -= 1
	if L.h01(x, y, seed + 2) > 0.95:
		i += 1
	return L.ri(ramp, i)

# -------------------------------------------------------------------- materials
func mat_pixel(m: int, x: int, y: int) -> Color:
	match m:
		0, 1: # dirt / grass base
			var c := noisy(x, y, 11, P.dirt, 1, 3)
			var r := L.vor(Vector2(x + 0.5, y + 0.5), pts("peb", 3, 12))
			if float(r[0]) < 1.15 and L.h01(int(r[2]), 1, 12) > 0.35:
				var q: Vector2 = r[3]
				return P.stone[4] if (y + 0.5) < q.y else P.stone[2]
			return c
		2:
			return cobble(x, y, 3, 21, P.stone)
		3:
			var c3 := cobble(x, y, 2, 31, P.hard, 1.0)
			return c3
		4:
			var c4 := cobble(x, y, 3, 41, P.dark)
			var rs := PX.vnoise_wrap(x, y, 6.0, 16, 42)
			if rs > 0.66 and c4 != P.dark[0]:
				return L.mix(c4, P.rust[2 + int(L.h01(x, y, 43) * 1.5)], 0.6)
			return c4
		5: # basalt columns
			var widths := [5, 5, 6]
			var starts := [0, 5, 10]
			var col := 0
			for i in 3:
				if x >= starts[i]:
					col = i
			var lx: int = x - int(starts[col])
			var joints := [[4, 12], [0, 8], [6, 14]]
			var j: Array = joints[col]
			if lx == 0:
				return P.basalt[0]
			if y == int(j[0]) or y == int(j[1]):
				return P.basalt[1]
			var i5 := 3
			if lx == 1:
				i5 = 4
			elif lx >= int(widths[col]) - 1:
				i5 = 2
			if y == int(j[0]) + 1 or y == int(j[1]) + 1:
				i5 += 1
			if L.h01(x, y, 51) > 0.93:
				i5 -= 1
			return L.ri(P.basalt, i5)
		6:
			var c6 := cobble(x, y, 3, 61, P.crys)
			var g := L.h01(x, y, 62)
			if g > 0.986:
				return P.cyan[3]
			if g > 0.975:
				return P.purple[3]
			return c6
		7:
			return facets(x, y, 2, 71, P.gemrock)
		8:
			var r8 := L.vor(Vector2(x + 0.5, y + 0.5), pts("cob", 3, 81))
			var c8 := cobble(x, y, 3, 81, P.frost)
			var q8: Vector2 = r8[3]
			var off8 := Vector2(x + 0.5, y + 0.5) - q8
			if float(r8[1]) - float(r8[0]) > 0.9 and float(r8[1]) - float(r8[0]) < 2.2 and off8.y < -0.5:
				return L.mix(c8, Color.html("e8f6ff"), 0.55)
			return c8
		9: # ice
			var d := posmod(x - y, 16)
			var v9 := PX.vnoise_wrap(x, y, 6.0, 16, 91)
			var i9 := 2 + int(v9 * 1.6)
			if d == 3 or d == 4:
				i9 = 4
			elif d == 5 or d == 11:
				i9 = 3
			var r9 := L.vor(Vector2(x + 0.5, y + 0.5), pts("ice", 2, 92))
			if float(r9[1]) - float(r9[0]) < 0.7:
				i9 = 4 if d < 8 else 1
			return L.ri(P.ice, i9)
		10:
			var v10 := PX.vnoise_wrap(x, y, 4.0, 16, 101)
			var i10 := 2 + int(v10 * 2.5)
			var r10 := L.vor(Vector2(x + 0.5, y + 0.5), pts("snow", 3, 102))
			if float(r10[0]) < 1.0:
				i10 = 1
			elif float(r10[0]) < 1.8:
				var q10: Vector2 = r10[3]
				i10 = 4 if (y + 0.5) > q10.y else 1
			return L.ri(P.snow, i10)
		11: # volcanic: porous
			var c11 := noisy(x, y, 111, P.volc, 2, 4)
			var r11 := L.vor(Vector2(x + 0.5, y + 0.5), pts("pore", 4, 112))
			var q11: Vector2 = r11[3]
			var dd: float = r11[0]
			if dd < 0.95:
				return P.volc[0]
			if dd < 1.9:
				return P.volc[5] if (y + 0.5) > q11.y and (x + 0.5) > q11.x else P.volc[1]
			return c11
		12:
			var r12 := L.vor(Vector2(x + 0.5, y + 0.5), pts("cob", 3, 121))
			var c12 := cobble(x, y, 3, 121, P.scorch)
			if float(r12[1]) - float(r12[0]) < 0.9 and L.h01(int(r12[2]), 5, 122) > 0.5:
				return P.glow[0]
			return c12
		13: # magma crust: plates + glowing seams
			var r13 := L.vor(Vector2(x + 0.5, y + 0.5), pts("crust", 2, 131, 0.9))
			var e: float = float(r13[1]) - float(r13[0])
			if e < 0.75:
				return P.glow[4] if L.h01(x, y, 132) > 0.5 else P.glow[3]
			if e < 1.5:
				return P.glow[2]
			if e < 2.3:
				return P.glow[1]
			if e < 3.0:
				return P.glow[0]
			var q13: Vector2 = r13[3]
			var off13 := Vector2(x + 0.5, y + 0.5) - q13
			var i13 := 2 + (1 if off13.x + off13.y < -1.0 else 0) - (1 if off13.x + off13.y > 2.5 else 0)
			if L.h01(x, y, 133) > 0.92:
				i13 += 1
			return L.ri(P.crust, i13)
		14: # ancient bricks 8x4, offset rows
			var row := y / 4
			var ox := 4 if row % 2 == 1 else 0
			var bx := posmod(x + ox, 16)
			var ly := y % 4
			var lx := bx % 8
			if ly == 3 or lx == 7:
				return P.abrick[0]
			var bid := row * 2 + bx / 8
			var i14 := 2 + int(L.h01(bid, 1, 141) * 2.0)
			if ly == 0:
				i14 += 1
			if lx == 6 or ly == 2:
				i14 -= 1
			if (bid == 1 or bid == 6) and ly == 1 and lx >= 1 and lx <= 5:
				return P.gold[2] if lx % 2 == 0 else P.gold[3]
			if L.h01(x, y, 142) > 0.95:
				i14 -= 1
			return L.ri(P.abrick, i14)
		15: # ruin block
			var i15 := 3
			if x == 0 or y == 0:
				i15 = 4
			if x == 15 or y == 15:
				i15 = 1
			if (x == 1 or y == 1) and x < 15 and y < 15:
				i15 = 4 if (x == 1 and y < 15) or y == 1 else i15
			var v15 := PX.vnoise_wrap(x, y, 4.0, 16, 151)
			if i15 == 3:
				i15 = 2 + int(v15 * 2.0)
			if L.h01(x, y, 152) > 0.94:
				i15 -= 1
			return L.ri(P.ruin, i15)
		16: # ancient metal panel
			var i16 := 3
			if x == 0 or y == 0:
				i16 = 5
			elif x == 15 or y == 15:
				i16 = 1
			elif x == 1 or y == 1:
				i16 = 4
			elif x == 14 or y == 14:
				i16 = 2
			if y == 7:
				i16 = 1
			elif y == 8:
				i16 = 5
			if (x == 3 or x == 12) and (y == 3 or y == 12):
				i16 = 6
			if (x == 4 or x == 13) and (y == 4 or y == 13):
				i16 = 1
			if i16 == 3 and L.h01(x, y, 161) > 0.85:
				i16 = 4
			return L.ri(P.metal, i16)
		17:
			var c17 := facets(x, y, 3, 171, P.bed)
			if L.h01(x, y, 172) > 0.985:
				return P.purple[2]
			return c17
		18: # shaft wall
			var i18 := 2
			if x == 0 or y == 0:
				i18 = 3
			if x == 15 or y == 15:
				i18 = 0
			if x >= 5 and x <= 10:
				i18 = 3
				if x == 5:
					i18 = 4
				if x == 10:
					i18 = 1
				if x == 7 or x == 8:
					i18 = 2
			if (x == 2 or x == 13) and (y == 2 or y == 13):
				i18 = 5
			if (x == 3 or x == 14) and (y == 3 or y == 14):
				i18 = 0
			if (x == 7 or x == 8) and (y == 4 or y == 11):
				i18 = 5
			return L.ri(P.steel, i18)
		19: # seal_1 reinforced stone: iron cross bands
			return band_pixel(x, y, cobble(x, y, 3, 191, P.stone), P.iron, 6, 9, false)
		20: # seal_2 iron-bound: thick rusty straps + bolts
			var base20 := cobble(x, y, 3, 201, P.dark)
			return band_pixel(x, y, base20, P.rust, 5, 10, true)
		21: # seal_3 crystal barrier lattice
			var a := posmod(x + y, 16)
			var b := posmod(x - y, 16)
			if a == 0 or b == 0:
				return P.cyan[4] if (x + y) % 2 == 0 else P.cyan[3]
			if a == 1 or b == 1 or a == 15 or b == 15:
				return P.cyan[2]
			var v21 := PX.vnoise_wrap(x, y, 5.0, 16, 211)
			var i21 := 1 + int(v21 * 2.5)
			if a < 8 and b < 8:
				i21 += 1
			return L.ri(P.purple, i21)
		22: # seal_4 permafrost wall
			var i22 := 1 + int(PX.vnoise_wrap(x, y, 5.0, 16, 221) * 2.0)
			var d22 := posmod(x - y, 16)
			if d22 == 2 or d22 == 3:
				i22 = 3
			var c22 := L.ri(P.blue, i22)
			if x == 0 or y == 0 or x == 15 or y == 15:
				c22 = Color.html("cfeeff") if (x + y) % 3 != 0 else P.cyan[2]
			elif x == 1 or y == 1 or x == 14 or y == 14:
				c22 = P.blue[0]
			return c22
		23: # seal_5 magma shell: obsidian plates, iron frame
			var c23 := facets(x, y, 2, 231, L.pal(["050308", "0e0816", "1a1026", "281a3a", "3c2a58", "5a4080"]))
			if x == 0 or y == 0 or x == 15 or y == 15:
				c23 = P.iron[1]
				if (x == 0 or x == 15) and (y % 5 == 2):
					c23 = P.iron[4]
				if (y == 0 or y == 15) and (x % 5 == 2):
					c23 = P.iron[4]
			elif x == 1 or y == 1:
				c23 = P.iron[3] if (x == 1 and y > 0) or (y == 1) else c23
			elif x == 14 or y == 14:
				c23 = P.iron[0]
			return c23
		24: # wood planks
			var ly24 := y % 8
			if ly24 == 7:
				return P.wood[0]
			var plank := y / 8
			var i24 := 3
			if ly24 == 0:
				i24 = 4
			elif ly24 == 6:
				i24 = 2
			var grain := PX.vnoise_wrap(x * 0.35, y * 3.0 + plank * 5, 3.0, 16, 241)
			if grain > 0.68:
				i24 -= 1
			elif grain < 0.2:
				i24 += 1
			return L.ri(P.wood, clampi(i24, 1, 5))
		25: # sealed ancient
			var c25 := L.ri(P.abrick, 2 + int(PX.vnoise_wrap(x, y, 4.0, 16, 251) * 1.8))
			if x == 0 or y == 0 or x == 15 or y == 15:
				c25 = P.gold[2]
				if x == 0 or y == 0:
					c25 = P.gold[3]
			elif x == 1 or y == 1 or x == 14 or y == 14:
				c25 = P.gold[0]
			return c25
	return Color.MAGENTA

func band_pixel(x: int, y: int, base: Color, ramp: Array[Color], a: int, b: int, bolts: bool) -> Color:
	var in_h := y >= a and y <= b
	var in_v := x >= a and x <= b
	if not in_h and not in_v:
		# shadow under band
		if y == b + 1 or x == b + 1:
			return L.darken(base, 0.45)
		return base
	var i := 2
	if in_h and not in_v:
		if y == a:
			i = 4
		elif y == a + 1:
			i = 3
		elif y == b:
			i = 0
		elif y == b - 1:
			i = 1
	elif in_v and not in_h:
		if x == a:
			i = 4
		elif x == a + 1:
			i = 3
		elif x == b:
			i = 0
		elif x == b - 1:
			i = 1
	else:
		i = 3
		if x == a or y == a:
			i = 4
		if x == b or y == b:
			i = 1
	var rivet_pos := [2, 13]
	if in_h and not in_v and x in rivet_pos and y == (a + b) / 2:
		return Color.html("f0f0f0") if not bolts else ramp[4]
	if in_v and not in_h and y in rivet_pos and x == (a + b) / 2:
		return Color.html("f0f0f0") if not bolts else ramp[4]
	if bolts and in_h and in_v:
		var cxp := (a + b) / 2
		if absi(x - cxp) <= 1 and absi(y - cxp) <= 1:
			return ramp[4] if (x - cxp) + (y - cxp) < 0 else ramp[1]
	if L.h01(x, y, 777) > 0.9:
		i = maxi(0, i - 1)
	return L.ri(ramp, i)

# details unique per variant, interior only (3..12)
func mat_details(m: int, img: Image, v: int) -> void:
	var c := PX.Canvas.new(16, 16)
	c.img = img
	var ramp: Array[Color]
	match m:
		0, 1: ramp = P.dirt
		2: ramp = P.stone
		3: ramp = P.hard
		4: ramp = P.dark
		5: ramp = P.basalt
		6: ramp = P.crys
		7: ramp = P.gemrock
		8: ramp = P.frost
		11: ramp = P.volc
		12: ramp = P.scorch
		17: ramp = P.bed
		_: ramp = []
	if m in [14, 16, 18, 24]:
		return
	if m == 15: # glyph engraving
		var glyph_a := [[5, 5], [5, 6], [5, 7], [5, 8], [5, 9], [6, 5], [7, 5], [8, 5], [8, 6], [8, 7], [7, 7], [10, 8], [10, 9], [10, 10], [9, 10], [8, 10]]
		var glyph_b := [[7, 4], [7, 5], [7, 6], [6, 7], [8, 7], [5, 8], [9, 8], [7, 9], [7, 10], [7, 11], [5, 11], [9, 11]]
		var g: Array = glyph_a if v == 0 else glyph_b
		for p in g:
			c.px(p[0], p[1], P.ruin[0])
			c.px(p[0] + 1, p[1] + 1, P.ruin[5])
		if v == 1:
			for p in g:
				c.px(p[0], p[1], P.teal[2])
		return
	if m == 21: # rune in crystal barrier
		var rune := [[7, 5], [8, 5], [6, 6], [9, 6], [7, 7], [8, 7], [7, 8], [8, 8], [6, 9], [9, 9], [7, 10], [8, 10]]
		if v == 1:
			rune = [[7, 4], [8, 4], [7, 5], [8, 5], [5, 7], [6, 7], [9, 7], [10, 7], [7, 9], [8, 9], [7, 10], [8, 10]]
		for p in rune:
			c.px(p[0], p[1], Color.html("ffffff"))
		return
	if m == 22:
		var flake := [[8, 4], [8, 5], [8, 6], [8, 7], [8, 8], [8, 9], [8, 10], [8, 11], [5, 7], [6, 7], [7, 7], [9, 7], [10, 7], [11, 7], [6, 5], [10, 5], [6, 10], [10, 10], [7, 6], [9, 6], [7, 9], [9, 9]]
		if v == 1:
			flake = [[8, 3], [8, 4], [8, 5], [8, 6], [8, 9], [8, 10], [8, 11], [8, 12], [4, 8], [5, 8], [6, 8], [10, 8], [11, 8], [12, 8], [7, 7], [9, 7], [7, 9], [9, 9], [8, 7], [8, 8], [7, 8], [9, 8]]
		for p in flake:
			c.px(p[0], p[1], Color.html("e8faff"))
		c.px(8, 8 if v == 0 else 7, P.cyan[3])
		return
	if m == 23:
		var lines := [[4, 7], [5, 7], [6, 6], [7, 6], [8, 6], [9, 7], [10, 7], [11, 8], [7, 7], [7, 8], [7, 9], [8, 10], [6, 10]]
		if v == 1:
			lines = [[5, 5], [6, 6], [7, 7], [8, 8], [9, 9], [10, 10], [10, 5], [9, 6], [6, 9], [5, 10]]
		for p in lines:
			c.px(p[0], p[1], P.glow[3])
		return
	if m == 25:
		# big glyph circle
		for yy in range(3, 13):
			for xx in range(3, 13):
				var d := Vector2(xx + 0.5 - 8, yy + 0.5 - 8).length()
				if d > 3.6 and d < 4.6:
					c.px(xx, yy, P.teal[3])
				elif d > 4.6 and d < 5.3:
					c.px(xx, yy, P.teal[1])
		var core := [[8, 6], [7, 7], [8, 7], [9, 7], [8, 8], [8, 9]] if v == 0 else [[7, 6], [9, 6], [8, 7], [7, 8], [9, 8], [8, 9]]
		for p in core:
			c.px(p[0], p[1], P.teal[4])
		return
	if m == 13:
		if v == 1:
			c.px(6, 6, P.glow[4])
			c.px(10, 9, P.glow[3])
		return
	if m == 9:
		if v == 1:
			for p in [[5, 9], [6, 8], [7, 8], [8, 7], [9, 7]]:
				c.px(p[0], p[1], Color.html("e8f8ff"))
		else:
			c.px(9, 5, Color.html("ffffff"))
			c.px(10, 5, Color.html("dff4ff"))
		return
	if m == 10:
		if v == 1:
			c.px(6, 9, P.snow[1])
			c.px(7, 9, P.snow[1])
			c.px(7, 8, P.snow[5])
		return
	if m == 19 or m == 20:
		if v == 1:
			c.px(3, 3, L.darken(c.get_px(3, 3), 0.4))
			c.px(12, 12, L.darken(c.get_px(12, 12), 0.4))
		return
	if ramp.is_empty():
		return
	if v == 0:
		# embedded pebble
		var px0 := 5 + int(L.h01(m, 1, 9) * 5)
		var py0 := 5 + int(L.h01(m, 2, 9) * 5)
		c.px(px0, py0, L.ri(ramp, 5))
		c.px(px0 + 1, py0, L.ri(ramp, 4))
		c.px(px0, py0 + 1, L.ri(ramp, 4))
		c.px(px0 + 1, py0 + 1, L.ri(ramp, 1))
		c.px(px0 + 2, py0 + 1, L.ri(ramp, 0))
		c.px(px0 + 1, py0 + 2, L.ri(ramp, 0))
	else:
		# hairline crack
		var sx := 4 + int(L.h01(m, 3, 9) * 4)
		var sy := 4 + int(L.h01(m, 4, 9) * 3)
		var pts_c := [[0, 0], [1, 1], [1, 2], [2, 3], [3, 3], [3, 4], [4, 5]]
		for p in pts_c:
			c.px(sx + p[0], sy + p[1], L.ri(ramp, 0))
		c.px(sx + 1, sy, L.ri(ramp, 5))
		c.px(sx + 4, sy + 4, L.ri(ramp, 5))

func outline_for(m: int) -> Color:
	match m:
		0, 1: return Color.html("120a07")
		9: return Color.html("0e2450")
		10: return Color.html("5a7aa0")
		13: return Color.html("0a0404")
		21: return Color.html("1a0838")
		22: return Color.html("08104a")
		24: return Color.html("180c05")
		25: return Color.html("3a2404")
	return Color.html("0b0a12")

func apply_edges(src: Image, mask: int, m: int, v: int) -> Image:
	var img := src.duplicate() as Image
	var top := (mask & 1) != 0
	var right := (mask & 2) != 0
	var bottom := (mask & 4) != 0
	var left := (mask & 8) != 0
	var ol := outline_for(m)
	var lipf := 0.42
	if m == 9 or m == 22:
		lipf = 0.5
	if top:
		if m == 1:
			_grass_top(img, v)
		else:
			for x in 16:
				img.set_pixel(x, 1, L.lighten(img.get_pixel(x, 1), lipf))
				img.set_pixel(x, 2, L.lighten(img.get_pixel(x, 2), lipf * 0.4))
				img.set_pixel(x, 0, ol)
	if left:
		for y in 16:
			if m == 1 and top and y < 6:
				pass
			img.set_pixel(1, y, L.lighten(img.get_pixel(1, y), 0.12))
	if right:
		for y in 16:
			img.set_pixel(14, y, L.darken(img.get_pixel(14, y), 0.22))
	if bottom:
		for x in 16:
			img.set_pixel(x, 14, L.darken(img.get_pixel(x, 14), 0.32))
			img.set_pixel(x, 13, L.darken(img.get_pixel(x, 13), 0.12))
			img.set_pixel(x, 15, ol)
	if left:
		for y in 16:
			if img.get_pixel(0, y).a > 0.0:
				img.set_pixel(0, y, ol)
	if right:
		for y in 16:
			if img.get_pixel(15, y).a > 0.0:
				img.set_pixel(15, y, ol)
	var clear := Color(0, 0, 0, 0)
	if top and left:
		img.set_pixel(0, 0, clear)
		img.set_pixel(1, 0, clear)
		img.set_pixel(0, 1, clear)
		img.set_pixel(1, 1, ol)
		img.set_pixel(2, 0, ol)
		img.set_pixel(0, 2, ol)
	if top and right:
		img.set_pixel(15, 0, clear)
		img.set_pixel(14, 0, clear)
		img.set_pixel(15, 1, clear)
		img.set_pixel(14, 1, ol)
		img.set_pixel(13, 0, ol)
		img.set_pixel(15, 2, ol)
	if bottom and left:
		img.set_pixel(0, 15, clear)
		img.set_pixel(1, 15, clear)
		img.set_pixel(0, 14, clear)
		img.set_pixel(1, 14, ol)
		img.set_pixel(2, 15, ol)
		img.set_pixel(0, 13, ol)
	if bottom and right:
		img.set_pixel(15, 15, clear)
		img.set_pixel(14, 15, clear)
		img.set_pixel(15, 14, clear)
		img.set_pixel(14, 14, ol)
		img.set_pixel(13, 15, ol)
		img.set_pixel(15, 13, ol)
	return img

func _grass_top(img: Image, v: int) -> void:
	for x in 16:
		var tip := L.h01(x, 7, 300 + v) > 0.45
		var top_y := 0 if tip else 1
		var drip := 1 if L.h01(x, 8, 301 + v) > 0.6 else 0
		if L.h01(x, 9, 302 + v) > 0.85:
			drip = 2
		var bot := 4 + drip
		for y in range(0, top_y):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		img.set_pixel(x, top_y, P.grass[1])
		for y in range(top_y + 1, bot):
			var i := 5 if y == top_y + 1 else (4 if y == top_y + 2 else 3)
			if y == bot - 1:
				i = 2
			if L.h01(x, y, 303) > 0.88:
				i -= 1
			img.set_pixel(x, y, P.grass[i])
		img.set_pixel(x, bot, L.mix(P.grass[1], img.get_pixel(x, bot), 0.5))
	# little flowers on variant 1
	if v == 1:
		img.set_pixel(4, 1, Color.html("fff2a0"))
		img.set_pixel(11, 1, Color.html("ff9ad0"))

func gen_terrain() -> void:
	var atlas := PX.Canvas.new(256, 832)
	for m in 26:
		for v in 2:
			var base := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					base.set_pixel(x, y, mat_pixel(m, x, y))
			mat_details(m, base, v)
			var row := m * 2 + v
			for mask in 16:
				var t := apply_edges(base, mask, m, v)
				atlas.img.blit_rect(t, Rect2i(0, 0, 16, 16), Vector2i(mask * 16, row * 16))
	atlas.save("tilesets/terrain.png")
	L.save_preview(atlas.img, "terrain.png", 2)

# -------------------------------------------------------------------- ores
const LUMP_LAYOUT := [
	[[5.0, 5.0, 2.6], [11.2, 6.0, 2.2], [7.4, 11.2, 2.8], [12.6, 12.2, 1.5]],
	[[4.8, 8.2, 2.8], [10.6, 4.6, 2.4], [11.2, 11.2, 2.6]],
	[[4.8, 4.6, 2.2], [11.4, 4.8, 2.0], [4.4, 11.2, 2.2], [10.4, 10.6, 3.0]],
	[[8.0, 7.2, 3.4], [3.6, 12.2, 1.8], [12.6, 12.4, 1.8], [12.8, 3.2, 1.4]],
]
const GEM_LAYOUT := [
	[[5.6, 5.8, 3.2], [11.0, 10.6, 3.0]],
	[[8.0, 8.0, 4.4], [3.4, 12.6, 1.6], [12.6, 3.4, 1.6]],
	[[4.8, 5.0, 2.6], [11.2, 5.8, 2.4], [7.6, 11.4, 2.9]],
	[[4.8, 10.6, 3.0], [10.6, 5.4, 3.2], [12.6, 12.6, 1.4]],
]
const SPIKE_LAYOUT := [
	[[8.0, 14.0, 10.0, 4.4, 0.0], [4.5, 14.0, 6.5, 3.2, -24.0], [11.6, 14.0, 6.5, 3.2, 24.0]],
	[[6.0, 14.0, 9.0, 4.0, -12.0], [11.0, 14.0, 7.5, 3.4, 18.0]],
	[[3.8, 13.0, 6.0, 3.0, -22.0], [8.6, 14.0, 10.0, 4.2, 6.0], [13.0, 13.0, 5.0, 2.6, 30.0]],
	[[9.6, 14.0, 10.5, 4.4, 12.0], [4.6, 14.0, 6.0, 3.2, -28.0], [13.2, 6.0, 4.0, 2.4, 70.0]],
]

func ol_of(ramp: Array[Color]) -> Color:
	return L.darken(ramp[0], 0.55)

func draw_lumps(c, v: int, ramp: Array[Color], scale: float = 1.0) -> void:
	for l in LUMP_LAYOUT[v]:
		L.lump(c, l[0], l[1], l[2] * scale, l[2] * scale * 0.85, ramp, ol_of(ramp))

func draw_gems(c, v: int, ramp: Array[Color], shape: String, scale: float = 1.0) -> void:
	for g in GEM_LAYOUT[v]:
		L.gem(c, g[0], g[1], g[2] * scale, ramp, ol_of(ramp), shape)

func draw_spikes(c, v: int, ramp: Array[Color], scale: float = 1.0) -> void:
	for s in SPIKE_LAYOUT[v]:
		L.crystal(c, s[0], s[1], s[2] * scale, s[3], s[4], ramp, ol_of(ramp))

func draw_geode(c, v: int, rock: Array[Color], inner: Array[Color]) -> void:
	var lay := [[8.0, 8.5, 5.4], [7.0, 7.5, 4.6], [9.0, 9.0, 5.0], [8.0, 8.0, 5.8]]
	var g: Array = lay[v]
	var cx: float = g[0]
	var cy: float = g[1]
	var r: float = g[2]
	L.lump(c, cx, cy, r, r * 0.92, rock, ol_of(rock), false)
	# crack opening revealing crystals
	var ang: float = [-0.6, 0.3, -1.2, 2.4][v]
	var dir := Vector2(cos(ang), sin(ang))
	var center := Vector2(cx, cy) + dir * r * 0.25
	for yy in 16:
		for xx in 16:
			var p := Vector2(xx + 0.5, yy + 0.5) - center
			var along := p.dot(dir)
			var perp := absf(p.dot(Vector2(-dir.y, dir.x)))
			var jag := 0.8 + 0.6 * L.h01(xx, yy, 400 + v)
			if along > -r * 0.55 and along < r * 0.62 and perp < (r * 0.45 - absf(along) * 0.35) * jag:
				if c.get_px(xx, yy).a > 0.0:
					var i := 2 + int(L.h01(xx, yy, 410) * 2.5)
					if (xx + yy) % 3 == 0:
						i = 4
					c.px(xx, yy, L.ri(inner, i))
	L.glow(c, center.x, center.y, r * 0.7, inner[3], 0.35)
	c.px(int(center.x), int(center.y) - 1, Color(1, 1, 1))

func gen_ores() -> void:
	var atlas := PX.Canvas.new(64, 576)
	var R := {
		"coal": L.pal(["08080c", "16161c", "26262e", "3c3c48", "62627a", "8c8ca8"]),
		"copper": L.pal(["4a1e0a", "8a3a12", "c8641e", "f09040", "ffc078"]),
		"quartz": L.pal(["4e5c72", "8e9cb2", "c8d4e4", "eaf2ff", "ffffff"]),
		"iron": L.pal(["3a140c", "6e2a14", "a04a22", "c87040", "eaa070"]),
		"silver": L.pal(["40485a", "727c92", "b0bacb", "dfe6f0", "ffffff"]),
		"gold": L.pal(["6a3c08", "b06e10", "e8a820", "ffd84a", "fff3a8"]),
		"amethyst": L.pal(["2e0f4e", "5a2296", "8a44d6", "b67cf4", "e8ccff"]),
		"sapphire": L.pal(["0c1a5a", "163aa0", "2a66e0", "5a9cff", "c4e2ff"]),
		"emerald": L.pal(["06361a", "0e6a3a", "1ca85c", "48dc8a", "b8ffd6"]),
		"ruby": L.pal(["480812", "8e1024", "d0203a", "ff5a6a", "ffc8d0"]),
		"cshard": L.pal(["0a4a6e", "1088b0", "2cc8e8", "6ff6ff", "e0ffff"]),
		"topaz": L.pal(["6a2e06", "b05a0c", "e88a1a", "ffbc40", "fff0a0"]),
		"frost": L.pal(["3a6a9a", "6aa6d6", "a8d8f8", "dcf4ff", "ffffff"]),
		"fiiron": L.pal(["232338", "3e3c58", "62607e", "8e8eaa", "c0c8e0"]),
		"bsapph": L.pal(["060a44", "0c1e8a", "1840d4", "4c80ff", "d0e2ff"]),
		"opal": L.pal(["9890b0", "c4bcd8", "e4def0", "f6f2fc", "ffffff"]),
		"obsid": L.pal(["040208", "0e0816", "1c1230", "34244e", "7a5aa8"]),
		"viron": L.pal(["140a08", "2a1a14", "44302a", "624438", "8a6050"]),
		"magma": L.pal(["5a0a04", "a8200a", "f05010", "ffa030", "fff4a8"]),
		"ember": L.pal(["3a0806", "8a1a0a", "e04010", "ffa030", "fff6c0"]),
		"diamond": L.pal(["4a7a98", "98c8e0", "d4f2ff", "f2fcff", "ffffff"]),
		"ashard": P.teal,
		"relic": L.pal(["3a2410", "6e4a1e", "a87a34", "d8b058", "fff0a8"]),
		"star": L.pal(["180a44", "361a8a", "6438d4", "a080ff", "ece4ff"]),
		"agold": L.pal(["5a3006", "a06010", "e0a020", "ffd448", "fff6c0"]),
		"proto": L.pal(["3a0848", "8a1aa0", "e03ad8", "ff8af4", "ffe0ff"]),
		"meteor": L.pal(["0e1016", "1e222a", "343a46", "586070", "8a94a8"]),
		"bone": L.pal(["4a3a26", "8a7454", "c4ac84", "eadcb8", "fff8e8"]),
		"rock": L.pal(["24242a", "40404a", "626270", "8a8a98", "b4b4c0"]),
		"rrock": L.pal(["2a1a16", "4a2e24", "6e4634", "946450", "b88a70"]),
		"irock": L.pal(["3a5070", "5a7aa0", "86a8cc", "b4d0ec", "e4f2ff"]),
		"mrock": L.pal(["140a0a", "2a1414", "422222", "5e3430", "7e4a40"]),
		"lrock": L.pal(["4a3410", "7a5a20", "a88438", "d0ac58", "f0d888"]),
	}
	for row in 36:
		for v in 4:
			var c := PX.Canvas.new(16, 16)
			match row:
				0: draw_lumps(c, v, R.coal)
				1:
					draw_lumps(c, v, R.copper)
					for k in 3:
						var x := 3 + int(L.h01(v, k, 501) * 10)
						var y := 3 + int(L.h01(k, v, 502) * 10)
						if c.get_px(x, y).a > 0.0:
							c.px(x, y, Color.html("3fbe92"))
				2: draw_spikes(c, v, R.quartz, 0.85)
				3: draw_geode(c, v, R.rock, R.amethyst)
				4:
					draw_lumps(c, v, R.iron)
					for k in 4:
						var x := 3 + int(L.h01(v, k, 511) * 10)
						var y := 3 + int(L.h01(k, v, 512) * 10)
						if c.get_px(x, y).a > 0.0:
							c.px(x, y, R.iron[0])
				5:
					draw_lumps(c, v, R.silver)
					var sp: Array = LUMP_LAYOUT[v][0]
					c.px(int(sp[0]) + 1, int(sp[1]) - 1, Color(1, 1, 1))
				6: draw_geode(c, v, R.rrock, R.topaz)
				7:
					draw_lumps(c, v, R.gold, 0.9)
					var gp: Array = LUMP_LAYOUT[v][0]
					L.glow(c, gp[0], gp[1], 5.0, R.gold[4], 0.18)
				8: draw_spikes(c, v, R.amethyst)
				9: draw_gems(c, v, R.sapphire, "hex")
				10: draw_gems(c, v, R.emerald, "rect")
				11: draw_gems(c, v, R.ruby, "round")
				12:
					draw_spikes(c, v, R.cshard)
					L.glow(c, 8, 10, 7, R.cshard[3], 0.2)
				13: draw_gems(c, v, R.topaz, "diamond")
				14: draw_geode(c, v, R.rock, R.cshard)
				15:
					draw_spikes(c, v, R.frost, 0.95)
					L.glow(c, 8, 10, 6, R.frost[3], 0.15)
				16:
					draw_lumps(c, v, R.fiiron)
					for l in LUMP_LAYOUT[v]:
						for k in 3:
							c.px(int(l[0]) - 1 + k, int(l[1] - l[2] * 0.85), Color.html("eaf8ff"))
				17: draw_gems(c, v, R.bsapph, "hex", 1.1)
				18: draw_geode(c, v, R.irock, R.frost)
				19:
					draw_gems(c, v, R.opal, "round")
					var fl := [Color.html("ff8ad8"), Color.html("7affb8"), Color.html("7ad0ff"), Color.html("ffe07a")]
					for k in 8:
						var x := 2 + int(L.h01(v, k, 521) * 12)
						var y := 2 + int(L.h01(k, v, 522) * 12)
						var cc := c.get_px(x, y)
						if cc.a > 0.0 and cc != ol_of(R.opal):
							c.px(x, y, fl[k % 4])
				20: draw_spikes(c, v, R.obsid, 0.9)
				21:
					draw_lumps(c, v, R.viron)
					for l in LUMP_LAYOUT[v]:
						var cx: float = l[0]
						var cy: float = l[1]
						var rr: float = l[2]
						for k in int(rr * 2):
							var x := int(cx - rr + k)
							var y := int(cy + rr * 0.5)
							if c.get_px(x, y).a > 0.0:
								c.px(x, y, R.magma[3] if k % 2 == 0 else R.magma[2])
				22:
					draw_spikes(c, v, R.magma)
					L.glow(c, 8, 10, 7, R.magma[3], 0.25)
				23:
					draw_lumps(c, v, R.ember)
					for l in LUMP_LAYOUT[v]:
						L.glow(c, l[0], l[1], l[2] + 2.5, R.ember[3], 0.22)
						c.px(int(l[0]), int(l[1]), R.ember[4])
				24:
					draw_gems(c, v, R.diamond, "diamond", 0.95)
					for g in GEM_LAYOUT[v]:
						L.glow(c, g[0], g[1], g[2] + 3.0, Color.html("dff8ff"), 0.18)
				25:
					draw_spikes(c, v, R.ashard, 0.9)
					for s in SPIKE_LAYOUT[v]:
						c.px(int(s[0]), int(s[1] - s[2] * 0.5), P.gold[3])
				26: _relic(c, v, R.relic)
				27:
					draw_spikes(c, v, R.star)
					for k in 4:
						var x := 3 + int(L.h01(v, k, 531) * 10)
						var y := 3 + int(L.h01(k, v, 532) * 10)
						if c.get_px(x, y).a > 0.0:
							c.px(x, y, Color.html("fff6c8"))
					L.glow(c, 8, 9, 7, R.star[3], 0.22)
				28:
					_agold(c, v, R.agold)
				29: _proto(c, v, R.proto)
				30:
					draw_geode(c, v, R.lrock, R.agold)
					L.glow(c, 8, 8, 8, R.agold[4], 0.15)
				31:
					draw_lumps(c, v, R.meteor, 1.05)
					for k in 6:
						var x := 2 + int(L.h01(v, k, 541) * 12)
						var y := 2 + int(L.h01(k, v, 542) * 12)
						if c.get_px(x, y).a > 0.0:
							c.px(x, y, Color.html("6ab8ff") if k % 2 == 0 else Color.html("cfe8ff"))
				32: _fossil(c, v, R.bone)
				33: _artifact(c, v, R.agold)
				34: draw_geode(c, v, R.mrock, R.magma)
				35: _hint_crack(c, v)
			atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(v * 16, row * 16))
	atlas.save("tilesets/ores.png")
	L.save_preview(atlas.img, "ores.png", 3)

func _relic(c, v: int, ramp: Array[Color]) -> void:
	var cx: float = [8.0, 7.0, 9.0, 8.0][v]
	var cy: float = [8.0, 9.0, 7.0, 8.5][v]
	var r: float = [5.0, 4.4, 4.6, 5.2][v]
	var ol := ol_of(ramp)
	for yy in 16:
		for xx in 16:
			var p := Vector2(xx + 0.5 - cx, yy + 0.5 - cy)
			var d := p.length()
			var a := atan2(p.y, p.x)
			var teeth := 1.0 if fposmod(a * 8.0 / TAU + v * 0.25, 1.0) < 0.5 else 0.0
			var rr := r - 1.2 + teeth * 1.2
			if d < rr and d > 1.6:
				var i := 2
				if p.x + p.y < -1.5:
					i = 3
				elif p.x + p.y > 2.0:
					i = 1
				if d > rr - 1.0:
					i -= 1
				# broken fragment: cut a wedge
				var cut := fposmod(a - v * 1.3, TAU) < 1.6
				if cut:
					continue
				c.px(xx, yy, L.ri(ramp, i))
	c.outline(ol)
	c.px(int(cx), int(cy), P.teal[3])
	L.glow(c, cx, cy, 3.5, P.teal[3], 0.4)

func _agold(c, v: int, ramp: Array[Color]) -> void:
	var lay := [[3, 4, 10, 8], [4, 3, 8, 10], [2, 5, 6, 6], [5, 4, 9, 7]]
	var b: Array = lay[v]
	var x0: int = b[0]
	var y0: int = b[1]
	var w: int = b[2]
	var h: int = b[3]
	for yy in range(y0, y0 + h):
		for xx in range(x0, x0 + w):
			var i := 2
			if yy == y0 or xx == x0:
				i = 4
			elif yy == y0 + h - 1 or xx == x0 + w - 1:
				i = 1
			elif yy == y0 + 1 or xx == x0 + 1:
				i = 3
			c.px(xx, yy, L.ri(ramp, i))
	# glyph
	var gx := x0 + w / 2
	var gy := y0 + h / 2
	for p in [[0, -2], [0, -1], [0, 0], [0, 1], [-1, 0], [1, 0], [-1, 2], [1, 2]]:
		c.px(gx + p[0], gy + p[1], ramp[0])
	if v == 2:
		L.lump(c, 11.5, 11.0, 2.4, 2.0, ramp, ol_of(ramp))
	c.outline(ol_of(ramp))

func _proto(c, v: int, ramp: Array[Color]) -> void:
	var cx: float = [8.0, 7.5, 8.5, 8.0][v]
	var cy: float = [8.0, 8.5, 7.5, 8.0][v]
	var r: float = [5.2, 4.6, 4.8, 5.4][v]
	L.gem(c, cx, cy, r, ramp, ol_of(ramp), "hex")
	# circuit lines
	var cyan := Color.html("5ff2ff")
	c.px(int(cx) - 2, int(cy), cyan)
	c.px(int(cx) - 1, int(cy), cyan)
	c.px(int(cx), int(cy), Color(1, 1, 1))
	c.px(int(cx) + 1, int(cy), cyan)
	c.px(int(cx), int(cy) + 2, cyan)
	c.px(int(cx), int(cy) + 1, cyan)
	L.glow(c, cx, cy, r + 2.5, ramp[3], 0.2)
	if v >= 2:
		L.gem(c, 3.5, 12.5, 1.8, ramp, ol_of(ramp), "hex")

func _fossil(c, v: int, ramp: Array[Color]) -> void:
	var ol := ol_of(ramp)
	match v:
		0: # ammonite spiral
			for yy in 16:
				for xx in 16:
					var p := Vector2(xx + 0.5 - 8, yy + 0.5 - 8)
					var d := p.length()
					if d < 5.6:
						var a := atan2(p.y, p.x)
						var s := fposmod(d - a / TAU * 2.0, 2.0)
						var i := 3 if s < 1.0 else 1
						if p.x + p.y < -2.0:
							i += 1
						c.px(xx, yy, L.ri(ramp, i))
			c.outline(ol)
		1: # bone
			for k in 9:
				var x := 4 + k
				var y := 11 - k
				c.px(x, y, ramp[3])
				c.px(x + 1, y, ramp[2])
				c.px(x, y + 1, ramp[1])
			L.lump(c, 4.0, 11.5, 1.8, 1.6, ramp, ol, false)
			L.lump(c, 5.0, 12.5, 1.6, 1.4, ramp, ol, false)
			L.lump(c, 12.0, 3.8, 1.8, 1.6, ramp, ol, false)
			L.lump(c, 12.8, 5.0, 1.6, 1.4, ramp, ol, false)
			c.outline(ol)
		2: # trilobite
			for yy in range(3, 14):
				var hw := 4.6 - absf(yy - 7.5) * 0.45
				for xx in range(int(8 - hw), int(8 + hw) + 1):
					var i := 2
					if yy % 2 == 0:
						i = 3
					if absi(xx - 8) <= 1:
						i = 4 if yy % 2 == 0 else 3
					c.px(xx, yy, L.ri(ramp, i))
			c.outline(ol)
		3: # skull-ish
			L.lump(c, 8.0, 7.0, 5.0, 4.2, ramp, ol, false)
			c.fill_rect(5, 10, 6, 3, ramp[2])
			c.px(6, 7, ramp[0])
			c.px(7, 7, ramp[0])
			c.px(10, 7, ramp[0])
			c.px(9, 7, ramp[0])
			c.px(6, 11, ramp[1])
			c.px(8, 11, ramp[1])
			c.px(10, 11, ramp[1])
			c.outline(ol)

func _artifact(c, v: int, ramp: Array[Color]) -> void:
	var ol := ol_of(ramp)
	match v:
		0: # idol
			L.lump(c, 8.0, 5.0, 2.6, 2.4, ramp, ol, false)
			c.fill_rect(6, 7, 5, 6, ramp[2])
			c.fill_rect(6, 7, 1, 6, ramp[3])
			c.fill_rect(10, 7, 1, 6, ramp[1])
			c.fill_rect(5, 13, 7, 1, ramp[1])
			c.px(7, 5, P.teal[3])
			c.px(9, 5, P.teal[3])
		1: # medallion
			L.lump(c, 8.0, 8.0, 4.8, 4.8, ramp, ol, false)
			L.gem(c, 8.0, 8.0, 2.0, P.teal, ol_of(P.teal), "diamond")
		2: # tablet
			c.fill_rect(4, 3, 8, 11, ramp[2])
			c.fill_rect(4, 3, 8, 1, ramp[4])
			c.fill_rect(4, 3, 1, 11, ramp[3])
			c.fill_rect(11, 3, 1, 11, ramp[1])
			for p in [[6, 5], [7, 5], [9, 5], [6, 7], [8, 7], [9, 7], [7, 9], [6, 11], [9, 11], [8, 10]]:
				c.px(p[0], p[1], P.teal[3])
		3: # amulet
			for k in 7:
				c.px(4 + k, 3 + (1 if k == 0 or k == 6 else 0), ramp[3])
			L.gem(c, 8.0, 9.5, 3.4, L.pal(["480812", "8e1024", "d0203a", "ff5a6a", "ffc8d0"]), Color.html("1a0306"), "round")
	c.outline(ol)
	L.glow(c, 8, 8, 7, ramp[4], 0.12)

func _hint_crack(c, v: int) -> void:
	var col := Color(0.02, 0.02, 0.05, 0.6)
	var chip := Color(1, 1, 1, 0.22)
	var paths := [
		[[3, 4], [4, 5], [5, 5], [6, 6], [7, 7], [8, 7], [9, 8], [10, 9], [11, 9], [12, 10], [7, 8], [6, 9], [6, 10], [5, 11]],
		[[4, 12], [5, 11], [6, 10], [7, 10], [8, 9], [8, 8], [9, 7], [10, 6], [11, 5], [12, 4], [9, 9], [10, 10], [11, 11]],
		[[8, 3], [8, 4], [7, 5], [7, 6], [8, 7], [8, 8], [7, 9], [7, 10], [8, 11], [8, 12], [9, 7], [10, 7], [11, 8], [6, 9], [5, 9]],
		[[3, 8], [4, 8], [5, 7], [6, 7], [7, 8], [8, 8], [9, 7], [10, 7], [11, 8], [12, 8], [7, 9], [7, 10], [9, 6], [9, 5]],
	]
	for p in paths[v]:
		c.px(p[0], p[1], col)
	for p in [[paths[v][0][0] + 1, paths[v][0][1] - 1], [paths[v][4][0] + 1, paths[v][4][1] - 1]]:
		c.px(p[0], p[1], chip)

# -------------------------------------------------------------------- backwalls
func gen_backwalls() -> void:
	var atlas := PX.Canvas.new(64, 128)
	var dim := func(col: Color) -> Color:
		return Color(col.r * 0.4, col.g * 0.4, col.b * 0.48, 1.0)
	var walls := [P.stone, P.dark, P.crys, P.frost, P.volc, P.abrick, P.dirt, P.wood]
	for row in 8:
		var ramp: Array[Color] = []
		for col in walls[row]:
			ramp.append(dim.call(col))
		var mid: Color = ramp[2]
		for k in ramp.size():
			ramp[k] = L.mix(ramp[k], mid, 0.35)
		for v in 4:
			var c := PX.Canvas.new(16, 16)
			for y in 16:
				for x in 16:
					var col: Color
					match row:
						0: col = slab(x, y, 601, ramp)
						1:
							col = slab(x, y, 611, ramp)
							if PX.vnoise_wrap(x * 3.0, y * 0.4, 6.0, 16, 612) > 0.68:
								col = L.mix(col, dim.call(P.rust[2]), 0.45)
						2:
							col = slab(x, y, 621, ramp)
							if L.h01(x, y, 622) > 0.985:
								col = dim.call(P.cyan[3])
						3: col = slab(x, y, 631, ramp)
						4:
							col = slab(x, y, 641, ramp)
							var r := L.vor(Vector2(x + 0.5, y + 0.5), pts("slab", 2, 641, 0.9))
							if float(r[1]) - float(r[0]) < 0.9 and L.h01(int(r[2]), 2, 642) > 0.55:
								col = Color(0.30, 0.08, 0.03)
						5:
							var rr := y / 8
							var ox := 8 if rr % 2 == 1 else 0
							var bx := posmod(x + ox, 16)
							if y % 8 == 7 or bx == 15:
								col = ramp[0]
							else:
								var i := 2 + int(L.h01(rr * 2 + bx / 16, 3, 651) * 1.5)
								if y % 8 == 0:
									i += 1
								if L.h01(x, y, 652) > 0.93:
									i -= 1
								col = L.ri(ramp, i)
						6: col = noisy(x, y, 661, ramp, 1, 3)
						7:
							var lx := x % 4
							if lx == 3:
								col = ramp[0]
							else:
								var i := 3 if lx == 0 else 2
								var gr := PX.vnoise_wrap(x * 3.0, y * 0.4, 4.0, 16, 671 + x / 4)
								if gr > 0.7:
									i -= 1
								col = L.ri(ramp, i)
					c.px(x, y, col)
			# variant details
			var ox2 := 4 + int(L.h01(row, v, 690) * 7)
			var oy2 := 4 + int(L.h01(v, row, 691) * 7)
			match v:
				1:
					c.px(ox2, oy2, L.darken(c.get_px(ox2, oy2), 0.4))
					c.px(ox2 + 1, oy2 + 1, L.darken(c.get_px(ox2 + 1, oy2 + 1), 0.4))
					c.px(ox2 + 1, oy2 + 2, L.darken(c.get_px(ox2 + 1, oy2 + 2), 0.4))
				2:
					c.px(ox2, oy2, L.lighten(c.get_px(ox2, oy2), 0.12))
					c.px(ox2 + 1, oy2, L.lighten(c.get_px(ox2 + 1, oy2), 0.08))
				3:
					if row == 7:
						c.px(ox2 % 4 + 1, oy2, Color(0.35, 0.33, 0.3))
						c.px(ox2 % 4 + 1, oy2 + 6 if oy2 < 6 else oy2 - 6, Color(0.35, 0.33, 0.3))
					else:
						c.px(ox2, oy2, L.darken(c.get_px(ox2, oy2), 0.3))
						c.px(ox2 - 1, oy2 + 1, L.darken(c.get_px(ox2 - 1, oy2 + 1), 0.3))
			atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(v * 16, row * 16))
	atlas.save("tilesets/backwalls.png")
	L.save_preview(atlas.img, "backwalls.png", 4)

# -------------------------------------------------------------------- special
func gen_special() -> void:
	var atlas := PX.Canvas.new(64, 112)
	# row 0: ladder
	for col in 2:
		var c := PX.Canvas.new(16, 16)
		for y in 16:
			for rx in [3, 11]:
				if col == 1 and y < 1:
					continue
				c.px(rx, y, P.wood[4])
				c.px(rx + 1, y, P.wood[3])
				c.px(rx + 2, y, P.wood[1])
		for ry in [2, 6, 10, 14]:
			if col == 1 and ry == 2:
				continue
			for x in range(5, 11):
				c.px(x, ry, P.wood[4])
				c.px(x, ry + 1, P.wood[1])
			c.px(4, ry, P.iron[4])
			c.px(12, ry, P.iron[4])
		if col == 1:
			for rx in [3, 11]:
				c.px(rx, 1, P.wood[5])
				c.px(rx + 1, 0, P.wood[5])
				c.px(rx + 1, 1, P.wood[4])
				c.px(rx + 2, 1, P.wood[2])
		c.outline(Color.html("180c05"))
		atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(col * 16, 0))
	# row 1: rails
	for col in 3:
		var c := PX.Canvas.new(16, 16)
		for tx in [1, 6, 11]:
			c.fill_rect(tx, 13, 3, 3, P.wood[2])
			c.fill_rect(tx, 13, 3, 1, P.wood[4])
			c.px(tx + 2, 15, P.wood[0])
		for x in 16:
			c.px(x, 11, P.steel[5])
			c.px(x, 12, P.steel[3])
			if x % 5 == 2:
				c.px(x, 13, P.steel[1])
		if col == 1 or col == 2:
			var bx := 1 if col == 1 else 10
			c.fill_rect(bx, 5, 5, 6, Color.html("c8302a"))
			c.fill_rect(bx, 5, 5, 1, Color.html("ff6a5a"))
			c.fill_rect(bx, 7, 5, 1, Color.html("f0c040"))
			c.fill_rect(bx, 9, 5, 1, Color.html("f0c040"))
			c.rect_outline(bx - 1, 4, 7, 8, Color.html("1a0806"))
			c.fill_rect(bx + 2, 10, 1, 3, P.steel[2])
		atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(col * 16, 16))
	# rows 2-5: lava & water
	var lava := L.pal(["7a1404", "c02c08", "f05a10", "ff9a28", "ffd060", "fff4b0"])
	var water := L.pal(["0c2a5a", "12428a", "1c62b4", "3a8ad8", "7ac0f4", "d0f0ff"])
	for f in 4:
		for kind in 2: # 0 lava, 1 water
			var ramp: Array[Color] = lava if kind == 0 else water
			var alpha := 1.0 if kind == 0 else 0.72
			var surf := PX.Canvas.new(16, 16)
			var body := PX.Canvas.new(16, 16)
			for y in 16:
				for x in 16:
					var t := f * 4.0
					var n := PX.vnoise_wrap(x + t, y + f * 2.0, 5.0, 16, 700 + kind) * 0.6 + PX.vnoise_wrap(x - t * 0.5, y, 3.0, 16, 710 + kind) * 0.4
					var i := 1 + int(n * 3.2)
					var col := L.ri(ramp, i)
					col.a = alpha
					body.px(x, y, col)
			# surface: wave line
			for x in 16:
				var sy := 3 + int(round(sin((x / 16.0) * TAU + f * PI / 2.0) * 1.0))
				for y in range(sy, 16):
					var col := body.get_px(x, y)
					if y == sy:
						col = L.ri(ramp, 5)
						col.a = minf(1.0, alpha + 0.2)
					elif y == sy + 1:
						col = L.ri(ramp, 4)
						col.a = alpha
					surf.px(x, y, col)
			if kind == 0:
				# bubble
				var bx: int = [4, 10, 7, 12][f]
				var by: int = [8, 11, 6, 9][f]
				surf.px(bx, by, lava[5])
				body.px(bx, by, lava[5])
				body.px(bx + 1, by, lava[4])
			atlas.img.blit_rect(surf.img, Rect2i(0, 0, 16, 16), Vector2i(f * 16, (2 if kind == 0 else 4) * 16))
			atlas.img.blit_rect(body.img, Rect2i(0, 0, 16, 16), Vector2i(f * 16, (3 if kind == 0 else 5) * 16))
	# row 6: wall torch
	for f in 4:
		var c := PX.Canvas.new(16, 16)
		# bracket
		c.fill_rect(7, 9, 2, 6, P.wood[3])
		c.fill_rect(7, 9, 1, 6, P.wood[4])
		c.fill_rect(6, 13, 4, 2, P.iron[2])
		c.px(6, 13, P.iron[4])
		c.fill_rect(6, 8, 4, 2, P.wood[1])
		# flame
		var fl := L.pal(["c02c08", "f05a10", "ff9a28", "ffd060", "fff8d0"])
		var hgt: float = [6.0, 7.0, 5.5, 6.5][f]
		var sway: float = [0.0, 0.6, -0.5, 0.3][f]
		for y in range(0, 9):
			for x in range(4, 12):
				var t := (8.5 - y) / hgt
				if t < 0.0 or t > 1.0:
					continue
				var w := (1.0 - t) * 2.8 + 0.4
				var cx := 8.0 + sway * t * 2.0
				var dx := absf(x + 0.5 - cx)
				if dx < w:
					var i := int((1.0 - dx / w) * 3.0 + (1.0 - t) * 1.5)
					c.px(x, y, L.ri(fl, i))
		L.glow(c, 8, 5, 7, fl[3], 0.18)
		atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(f * 16, 96))
	atlas.save("tilesets/special.png")
	L.save_preview(atlas.img, "special.png", 4)

# -------------------------------------------------------------------- crack
func gen_crack() -> void:
	var atlas := PX.Canvas.new(80, 16)
	var lines := [
		[[8, 8], [9, 7], [10, 6], [7, 9]],
		[[6, 9], [5, 10], [11, 6], [12, 5], [8, 9], [8, 10]],
		[[4, 10], [3, 11], [13, 5], [13, 4], [8, 11], [9, 12], [9, 6], [9, 5], [10, 9], [11, 10]],
		[[2, 12], [14, 4], [15, 3], [9, 13], [8, 14], [9, 4], [8, 3], [12, 10], [13, 11], [6, 7], [5, 6], [4, 6]],
		[[1, 13], [0, 14], [7, 2], [7, 1], [14, 12], [15, 13], [3, 5], [2, 5], [10, 14], [12, 2], [5, 13], [4, 14], [11, 8], [5, 8]],
	]
	var dark := Color(0.04, 0.03, 0.07, 0.92)
	var light := Color(1, 1, 1, 0.45)
	for f in 5:
		var c := PX.Canvas.new(16, 16)
		for k in range(0, f + 1):
			for p in lines[k]:
				c.px(p[0], p[1], dark)
		# chips
		var chips := [[10, 5], [6, 10], [12, 4], [4, 11], [13, 10], [8, 2], [2, 13], [14, 13]]
		for k in range(0, mini(chips.size(), f * 2)):
			var p: Array = chips[k]
			if c.get_px(p[0], p[1]).a == 0.0:
				c.px(p[0], p[1], light)
		atlas.img.blit_rect(c.img, Rect2i(0, 0, 16, 16), Vector2i(f * 16, 0))
	atlas.save("tilesets/crack.png")
	L.save_preview(atlas.img, "crack.png", 6)
