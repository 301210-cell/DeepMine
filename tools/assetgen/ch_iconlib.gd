## Icon drawing primitives for DeepMine (16x16 and 32x32 icons).
extends RefCounted
const PX = preload("res://px.gd")
const L = preload("res://chlib.gd")

# ---------------------------------------------------------------- material ramps
static func R(name: String) -> Array:
	match name:
		"rock": return L.r5("262634", "444458", "6a6a80", "9898ac", "c4c4d4")
		"darkrock": return L.r5("161a26", "2a3040", "444c60", "687088", "9098b0")
		"navyrock": return L.r5("0c1430", "18244e", "2a3a78", "4a5ea8", "7a90d8")
		"frostrock": return L.r5("3a4a62", "607898", "8eaac8", "c4dcf0", "f0faff")
		"volcrock": return L.r5("1a0e10", "34201e", "543230", "7a4a40", "a06a58")
		"sand": return L.r5("5a4428", "8a6a40", "b8945a", "dcc080", "f6e4b0")
		"coal": return L.r5("06060c", "12121c", "262634", "42425a", "6e6e8a")
		"copper": return L.r5("5a2008", "9a4418", "d8742e", "f8a050", "ffd090")
		"patina": return L.r5("0e4a3a", "1a7a60", "2aa888", "5ad8b0", "a8f8e0")
		"rust": return L.r5("4a1a10", "7a2e1c", "b04a2a", "d87048", "f0a070")
		"iron": return L.r5("2a2a34", "4a4c5a", "70748a", "9ea4b8", "d0d6e6")
		"silver": return L.r5("4a5262", "7a8496", "b4bccc", "dfe4ee", "ffffff")
		"gold": return L.r5("6a3a04", "b06e08", "f0b020", "ffd84a", "fff6b0")
		"amethyst": return L.r5("2a0c4a", "4a1e82", "7a3cc8", "a870f0", "dcb8ff")
		"sapphire": return L.r5("0a1a5a", "1a3aa0", "2f6ae8", "6aa8ff", "c0e0ff")
		"emerald": return L.r5("063a1e", "0e6a34", "1ea85a", "5ae08a", "b8ffd0")
		"ruby": return L.r5("4a0612", "8a1024", "d8203c", "ff5a6a", "ffb0b8")
		"topaz": return L.r5("6a3204", "b06008", "f09420", "ffc850", "fff0a0")
		"opal": return L.r5("4a5a8a", "7a8ac0", "b4c4ec", "dce6ff", "ffffff")
		"diamond": return L.r5("3a5a7a", "7aa0c8", "c4e2f8", "eef8ff", "ffffff")
		"bluesap": return L.r5("061040", "0e2a8a", "1a50d0", "4a90ff", "a8d8ff")
		"shard": return L.r5("0a2a6a", "1a5ab0", "3a9ae8", "7ad8ff", "d0f8ff")
		"frost": return L.r5("2a5a7a", "5a9ac0", "9ad8f0", "d0f4ff", "ffffff")
		"magma": return L.r5("5a0a04", "a82a08", "ff6a10", "ffaa30", "fff080")
		"ember": return L.r5("3a1008", "7a2a10", "d85a18", "ffa040", "fff0a0")
		"obsidian": return L.r5("06040c", "120c1e", "241c38", "40305e", "7a5aa8")
		"teal": return L.r5("0a2a2a", "145050", "1e8a80", "3ac8b0", "9af8e0")
		"star": return L.r5("6a5a20", "b0a050", "f0e8a0", "fffbe0", "ffffff")
		"bronze": return L.r5("3a2008", "6a4018", "a0682a", "d0a050", "f0d08a")
		"wood": return L.r5("3a1e0c", "5e3416", "8a5528", "b07038", "d0904c")
		"darkwood": return L.r5("24140a", "3e2412", "5e3a1e", "7e5030", "9e6a40")
		"leather": return L.r5("3a2010", "5e3a1c", "8a5a30", "b07a44", "cfa070")
		"canvas": return L.r5("4a3a24", "7a6440", "a88c5c", "ccb27e", "e8d4a4")
		"green": return L.r5("143a14", "235a20", "3a8a30", "5ab848", "9ae078")
		"red": return L.r5("4a0a10", "8a1420", "d02a30", "ff5a4a", "ffa090")
		"steel": return L.r5("1e2232", "3c4458", "5a6378", "8a93a8", "c3cad8")
		"blue": return L.r5("0e1e5a", "1e3a9a", "2f6ae8", "5aa0ff", "a8d4ff")
		"purple": return L.r5("1e0a3a", "3a1a6a", "6a3aa8", "9a6ae0", "d0b0ff")
		"cyan": return L.r5("0a4a6a", "1a8ab0", "40d0f0", "90f0ff", "e0ffff")
		"bone": return L.r5("5a4a3a", "8a7a62", "c0b090", "e4d8bc", "fff8e8")
		"glyph": return L.r5("0a3a4a", "1a7a8a", "3ae0e0", "a0ffff", "ffffff")
		"white": return L.r5("4a5068", "8a92ac", "dce2f2", "ffffff", "ffffff")
		"flame": return L.r5("8a2a04", "d85a08", "ffa020", "ffd860", "fff8c0")
		"pink": return L.r5("6a1a4a", "a83a7a", "f06ab0", "ff9ad0", "ffd0ec")
		"stone2": return L.r5("2e2a2a", "4a4444", "6e6662", "948a84", "b8aea6")
		"lime": return L.r5("1a4a0a", "3a7a14", "6ac020", "a0f040", "e0ffa0")
	return L.r5("000000", "333333", "777777", "aaaaaa", "ffffff")

# ---------------------------------------------------------------- basic builders
static func icon(sz: int = 16) -> PX.Canvas:
	return PX.Canvas.new(sz, sz)

static func finish(cv: PX.Canvas, ramps: Array, strength: int = 2, outline: bool = true) -> void:
	L.autoshade(cv, ramps, strength)
	if outline:
		cv.outline(L.OUTLINE)

static func lump(cv: PX.Canvas, ramp: Array, cx: float, cy: float, rx: float, ry: float, seed: int, rough: float = 0.32, flat_bottom: bool = true) -> void:
	for y in cv.h:
		for x in cv.w:
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if flat_bottom and ny > 0.0:
				ny *= 0.8
			var ang := atan2(ny, nx)
			var wob := sin(ang * 3.0 + seed) * 0.5 + sin(ang * 5.0 + seed * 1.7) * 0.5
			var thr := 1.0 + wob * rough * 0.5
			if nx * nx + ny * ny <= thr:
				cv.px(x, y, ramp[2])

## Speckle the inside of a shape with darker/lighter pixels (texture).
static func speckle(cv: PX.Canvas, ramp: Array, seed: int, dark_p: float = 0.12, light_p: float = 0.06) -> void:
	var mid: Color = ramp[2]
	for y in cv.h:
		for x in cv.w:
			var p := cv.get_px(x, y)
			if p.a < 0.5:
				continue
			var hsh := PX.hash01(x, y, seed)
			if p.is_equal_approx(mid):
				if hsh < dark_p:
					cv.px(x, y, ramp[1])
				elif hsh > 1.0 - light_p:
					cv.px(x, y, ramp[3])

static func nugget(cv: PX.Canvas, x: int, y: int, ramp: Array, big: bool = false, spec: bool = true) -> void:
	if big:
		cv.fill_rect(x, y, 3, 2, ramp[2])
		cv.px(x + 1, y + 2, ramp[1])
		cv.px(x + 2, y + 2, ramp[0])
		cv.px(x, y + 1, ramp[2])
		cv.px(x, y, ramp[3])
		cv.px(x + 1, y, ramp[4] if spec else ramp[3])
		cv.px(x + 2, y + 1, ramp[1])
	else:
		cv.px(x, y, ramp[3])
		cv.px(x + 1, y, ramp[2])
		cv.px(x, y + 1, ramp[2])
		cv.px(x + 1, y + 1, ramp[1])
		if spec:
			cv.px(x, y, ramp[4])

static func ore_rock(seed: int, rock: Array, ore: Array, spots: Array, big_spots: Array = []) -> PX.Canvas:
	var cv := icon()
	lump(cv, rock, 8.0, 8.8, 6.6, 5.6, seed)
	L.autoshade(cv, [rock], 2)
	speckle(cv, rock, seed, 0.08, 0.04)
	for s in spots:
		nugget(cv, s.x, s.y, ore, false)
	for s in big_spots:
		nugget(cv, s.x, s.y, ore, true)
	cv.outline(L.OUTLINE)
	return cv

## Faceted polygon: angular shading from a centre, optional bright table polygon.
static func facet_poly(cv: PX.Canvas, pts: PackedVector2Array, ramp: Array, center: Vector2, sectors: int = 8, table: PackedVector2Array = PackedVector2Array()) -> void:
	var tmp := PX.Canvas.new(cv.w, cv.h)
	tmp.polygon(pts, Color.WHITE)
	var light_ang := -2.3
	for y in cv.h:
		for x in cv.w:
			if tmp.get_px(x, y).a < 0.5:
				continue
			var a := atan2(y + 0.5 - center.y, x + 0.5 - center.x)
			var sec: float = floorf((a + PI) / (TAU / sectors))
			var sc := -PI + (sec + 0.5) * (TAU / sectors)
			var b := cos(sc - light_ang)
			var idx := 2
			if b > 0.55:
				idx = 3
			elif b > -0.1:
				idx = 2
			elif b > -0.7:
				idx = 1
			else:
				idx = 1
			cv.px(x, y, ramp[idx])
	if table.size() >= 3:
		var t2 := PX.Canvas.new(cv.w, cv.h)
		t2.polygon(table, Color.WHITE)
		for y in cv.h:
			for x in cv.w:
				if t2.get_px(x, y).a > 0.5:
					cv.px(x, y, ramp[3])

static func octagon(cx: float, cy: float, r: float, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := PI / 8.0 + i * TAU / 8.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * squash))
	return pts

static func ngon(cx: float, cy: float, r: float, n: int, rot: float = 0.0, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + i * TAU / n
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * squash))
	return pts

## Rough raw gem (irregular faceted lump).
static func gem_rough(ramp: Array, seed: int, sparkle: bool = false) -> PX.Canvas:
	var cv := icon()
	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var a := -PI / 2.0 + i * TAU / n + (PX.hash01(i, seed, 3) - 0.5) * 0.5
		var r := 5.6 + (PX.hash01(i, seed, 9) - 0.5) * 2.0
		pts.append(Vector2(8.0 + cos(a) * r, 8.6 + sin(a) * r * 0.92))
	facet_poly(cv, pts, ramp, Vector2(7.4, 7.6), 7, ngon(7.2, 7.2, 2.2, 5, seed * 0.3))
	cv.outline(L.OUTLINE)
	cv.px(6, 5, ramp[4])
	cv.px(5, 6, ramp[4])
	if sparkle:
		L.sparkle(cv, 12, 3, Color(1, 1, 1, 0.95), 1)
	return cv

## Cut gems for the polished set.
static func gem_cut(ramp: Array, cut: String) -> PX.Canvas:
	var cv := icon()
	match cut:
		"round":
			facet_poly(cv, octagon(8, 8.5, 6.4), ramp, Vector2(8, 8.5), 8, octagon(8, 7.6, 3.0))
		"emerald":
			var p := PackedVector2Array([Vector2(4, 3), Vector2(12, 3), Vector2(14, 5), Vector2(14, 12), Vector2(12, 14), Vector2(4, 14), Vector2(2, 12), Vector2(2, 5)])
			facet_poly(cv, p, ramp, Vector2(8, 8.5), 4, PackedVector2Array([Vector2(5, 6), Vector2(11, 6), Vector2(11, 11), Vector2(5, 11)]))
		"oval":
			facet_poly(cv, ngon(8, 8.5, 6.4, 10, 0.0, 0.8), ramp, Vector2(8, 8.5), 10, ngon(8, 7.8, 3.0, 8, 0.0, 0.8))
		"pear":
			var p2 := PackedVector2Array([Vector2(8, 1.5), Vector2(11, 5), Vector2(13.5, 9), Vector2(12.5, 13), Vector2(8, 14.8), Vector2(3.5, 13), Vector2(2.5, 9), Vector2(5, 5)])
			facet_poly(cv, p2, ramp, Vector2(8, 9), 8, ngon(8, 9.5, 2.6, 6))
		"heart":
			var p3 := PackedVector2Array([Vector2(8, 4.5), Vector2(10, 2.5), Vector2(13, 2.5), Vector2(14.5, 5), Vector2(14, 8), Vector2(8, 14.5), Vector2(2, 8), Vector2(1.5, 5), Vector2(3, 2.5), Vector2(6, 2.5)])
			facet_poly(cv, p3, ramp, Vector2(8, 7), 8, ngon(8, 7, 2.2, 5, -PI / 2))
		"cushion":
			facet_poly(cv, ngon(8, 8.5, 6.6, 8, PI / 8.0, 0.86), ramp, Vector2(8, 8.5), 8, ngon(8, 8, 2.8, 4, PI / 4))
	cv.outline(L.OUTLINE)
	return cv

static func crystal(cv: PX.Canvas, bx: float, by: float, h: float, w: float, tilt: float, ramp: Array) -> void:
	# hexagonal prism pointing up (tilted); left face light, right face dark, centre ridge
	var tipx := bx + tilt
	var tip := Vector2(tipx, by - h)
	var shoulder := minf(w * 1.2, h * 0.35)
	var lpts := PackedVector2Array([Vector2(bx - w, by), Vector2(bx - w + tilt * 0.8, by - h + shoulder), tip, Vector2(tipx, by)])
	var rpts := PackedVector2Array([Vector2(tipx, by), tip, Vector2(bx + w + tilt * 0.8, by - h + shoulder), Vector2(bx + w, by)])
	cv.polygon(lpts, ramp[3])
	cv.polygon(rpts, ramp[1])
	# ridge line
	var steps := int(h)
	for i in steps:
		var t := float(i) / float(maxi(steps, 1))
		var p := Vector2(tipx, by).lerp(tip, t)
		cv.px(int(p.x), int(p.y), ramp[2])
	cv.px(int(tip.x), int(tip.y), ramp[4])

static func crystal_cluster(ramp: Array, spikes: Array, rock = null, glow = null) -> PX.Canvas:
	var cv := icon()
	if rock != null:
		var rk := icon()
		lump(rk, rock, 8.0, 12.6, 6.4, 2.6, 5, 0.2)
		L.autoshade(rk, [rock], 2)
		cv.blit(rk.img, 0, 0)
	for s in spikes:
		crystal(cv, s[0], s[1], s[2], s[3], s[4], ramp)
	cv.outline(L.OUTLINE)
	if glow != null:
		L.glow(cv, glow, 1)
	return cv

static func ingot(ramp: Array, stamp: bool = true) -> PX.Canvas:
	var cv := icon()
	var top := PackedVector2Array([Vector2(4, 5), Vector2(13, 5), Vector2(14, 8), Vector2(3, 8)])
	var front := PackedVector2Array([Vector2(3, 8), Vector2(14, 8), Vector2(15, 12), Vector2(2, 12)])
	cv.polygon(front, ramp[2])
	cv.polygon(top, ramp[3])
	cv.fill_rect(2, 11, 13, 1, ramp[1])
	cv.line(14, 8, 15, 11, ramp[1])
	cv.line(3, 8, 2, 11, ramp[3])
	if stamp:
		cv.fill_rect(7, 6, 3, 1, ramp[2])
	cv.line(5, 6, 6, 6, ramp[4])
	cv.px(4, 9, ramp[4])
	cv.px(5, 9, ramp[3])
	cv.outline(L.OUTLINE)
	return cv

static func vial(liquid: Array, glass_tint: Color = Color(0.82, 0.9, 1.0)) -> PX.Canvas:
	var cv := icon()
	var glass := L.r5("3a4a62", "7a8ca8", glass_tint.to_html(false), "eef6ff", "ffffff")
	# body
	cv.circle(8, 10.5, 4.8, glass[2])
	cv.fill_rect(6, 3, 4, 4, glass[2])
	L.autoshade(cv, [glass], 2)
	# liquid
	for y in range(9, 16):
		for x in 16:
			var dx := x + 0.5 - 8.0
			var dy := y + 0.5 - 10.5
			if dx * dx + dy * dy <= 3.8 * 3.8:
				cv.px(x, y, liquid[2] if y > 9 else liquid[3])
	cv.px(6, 12, liquid[4])
	cv.px(10, 13, liquid[1])
	cv.px(9, 14, liquid[1])
	cv.px(10, 12, liquid[1])
	# cork
	cv.fill_rect(6, 1, 4, 2, R("wood")[2])
	cv.px(6, 1, R("wood")[3])
	cv.px(9, 2, R("wood")[1])
	cv.px(5, 8, glass[4])
	cv.px(5, 9, glass[4])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(liquid[3].r, liquid[3].g, liquid[3].b, 0.7), 1)
	return cv

static func geode(shell: Array, inner: Array, seed: int = 1) -> PX.Canvas:
	var cv := icon()
	lump(cv, shell, 8.0, 8.5, 6.6, 6.2, seed, 0.18, false)
	L.autoshade(cv, [shell], 2)
	speckle(cv, shell, seed, 0.1, 0.05)
	# cavity
	for y in 16:
		for x in 16:
			var dx := x + 0.5 - 8.2
			var dy := y + 0.5 - 8.6
			var d := sqrt(dx * dx + dy * dy)
			if d <= 4.2:
				var a := atan2(dy, dx)
				var tooth := 0.5 + 0.5 * sin(a * 7.0 + seed)
				if d > 3.0 + tooth * 0.8:
					cv.px(x, y, inner[3] if a < 0.3 and a > -2.6 else inner[2])
				elif d > 1.6:
					cv.px(x, y, inner[2] if (x + y) % 2 == 0 else inner[1])
				else:
					cv.px(x, y, inner[4])
	# rim
	for y in 16:
		for x in 16:
			var dx := x + 0.5 - 8.2
			var dy := y + 0.5 - 8.6
			var d := sqrt(dx * dx + dy * dy)
			if d > 4.2 and d <= 5.0:
				cv.px(x, y, shell[3] if dy < 0 else shell[1])
	cv.outline(L.OUTLINE)
	cv.px(7, 7, Color.WHITE)
	return cv

static func slab(ramp: Array) -> PX.Canvas:
	var cv := icon()
	var p := PackedVector2Array([Vector2(2, 4), Vector2(6, 2), Vector2(13, 3), Vector2(15, 8), Vector2(13, 14), Vector2(4, 14), Vector2(1, 10)])
	cv.polygon(p, ramp[2])
	L.autoshade(cv, [ramp], 2)
	speckle(cv, ramp, 4, 0.08, 0.05)
	return cv

## Small 4-point star sparkle drawn after outline.
static func star4(cv: PX.Canvas, x: int, y: int, col: Color = Color.WHITE) -> void:
	cv.px(x, y, col)
	cv.blend(x - 1, y, Color(col.r, col.g, col.b, 0.75))
	cv.blend(x + 1, y, Color(col.r, col.g, col.b, 0.75))
	cv.blend(x, y - 1, Color(col.r, col.g, col.b, 0.75))
	cv.blend(x, y + 1, Color(col.r, col.g, col.b, 0.75))

static func big_star(cv: PX.Canvas, x: int, y: int, col: Color = Color.WHITE) -> void:
	cv.px(x, y, col)
	for i in [1, 2]:
		var a := 0.85 if i == 1 else 0.45
		cv.blend(x - i, y, Color(col.r, col.g, col.b, a))
		cv.blend(x + i, y, Color(col.r, col.g, col.b, a))
		cv.blend(x, y - i, Color(col.r, col.g, col.b, a))
		cv.blend(x, y + i, Color(col.r, col.g, col.b, a))

## Diagonal tool helper: handle from (a) to (b)
static func handle(cv: PX.Canvas, a: Vector2, b: Vector2, ramp: Array, r: float = 0.8) -> void:
	L.thick(cv, [a, b], r, ramp[2])

static func pick_head16(cv: PX.Canvas, ramp: Array, half: float = 7.0, th: float = 1.7, curve: float = 2.0) -> void:
	var C := Vector2(10.6, 5.4)
	var u := Vector2(0.7071, 0.7071)
	var d := Vector2(-0.7071, 0.7071)
	for i in range(-6, 7):
		var t := float(i) / 6.0
		var p := C + u * (t * half) + d * (curve * t * t) - d * 0.4
		var rr := lerpf(th, 0.5, pow(absf(t), 1.3))
		L.disc(cv, p.x, p.y, rr, ramp[2])

static func pickaxe16(head: Array, handle_ramp: Array, glow = null) -> PX.Canvas:
	var cv := icon()
	var hl := icon()
	handle(hl, Vector2(2.5, 13.5), Vector2(10.5, 5.5), handle_ramp, 0.8)
	L.autoshade(hl, [handle_ramp])
	hl.outline(L.OUTLINE)
	cv.blit(hl.img, 0, 0)
	var hd := icon()
	pick_head16(hd, head)
	L.autoshade(hd, [head], 2)
	hd.outline(L.OUTLINE)
	cv.blit(hd.img, 0, 0)
	if glow != null:
		L.glow(cv, glow, 1)
	return cv

## White glyph palette for skill icons
static func W() -> Array:
	return L.r5("5a6078", "9aa2bc", "e4e8f4", "ffffff", "ffffff")

# ---------------------------------------------------------------- reference-board builders
## Bumpy solid-material lump (reference "Resources & Ores": Copper, Iron, Silver, Gold...).
static func ore_lump(ramp: Array, seed: int, sparkle: bool = false) -> PX.Canvas:
	var cv := icon()
	var bumps := [[5.5, 9.5, 3.8], [10.5, 9.8, 3.8], [8.0, 6.4, 3.6], [8.0, 11.2, 3.6], [11.5, 7.0, 2.4]]
	for b in bumps:
		var j := (PX.hash01(int(b[0] * 3), seed, 2) - 0.5) * 0.8
		cv.circle(b[0] + j, b[1], b[2], ramp[2])
	L.autoshade(cv, [ramp], 2)
	# bump crease shading + highlights so it reads as a cluster of nuggets
	for b in bumps:
		var bx := int(b[0] - b[2] * 0.45)
		var by := int(b[1] - b[2] * 0.45)
		cv.px(bx, by, ramp[3])
		cv.px(int(b[0] + b[2] * 0.5), int(b[1] + b[2] * 0.55), ramp[1])
	speckle(cv, ramp, seed, 0.1, 0.07)
	cv.outline(L.OUTLINE)
	if sparkle:
		cv.px(6, 5, ramp[4])
		star4(cv, 12, 3, Color.WHITE)
	return cv

## A faceted round nugget (gem ball) at centre c with radius r.
static func gem_ball(cv: PX.Canvas, c: Vector2, r: float, ramp: Array) -> void:
	var tmp := PX.Canvas.new(cv.w, cv.h)
	facet_poly(tmp, octagon(c.x, c.y, r), ramp, c, 8, octagon(c.x - r * 0.15, c.y - r * 0.2, r * 0.45))
	tmp.outline(L.OUTLINE)
	tmp.px(int(c.x - r * 0.45), int(c.y - r * 0.5), ramp[4])
	cv.blit(tmp.img, 0, 0)

## Cluster of three faceted nuggets (reference Amethyst / Sapphire / Emerald / Ruby / Topaz).
static func gem_cluster(ramp: Array, sparkle: bool = false) -> PX.Canvas:
	var cv := icon()
	gem_ball(cv, Vector2(8.5, 5.5), 3.6, ramp)
	gem_ball(cv, Vector2(5.0, 10.5), 3.9, ramp)
	gem_ball(cv, Vector2(11.2, 10.8), 3.7, ramp)
	if sparkle:
		star4(cv, 13, 3, Color.WHITE)
	return cv

## Classic brilliant-cut diamond profile (crown + pavilion), reference "Diamond".
static func diamond_profile(ramp: Array) -> PX.Canvas:
	var cv := icon()
	var crown := PackedVector2Array([Vector2(4, 3), Vector2(12, 3), Vector2(15, 6.5), Vector2(1, 6.5)])
	var pav := PackedVector2Array([Vector2(1, 6.5), Vector2(15, 6.5), Vector2(8, 15)])
	cv.polygon(crown, ramp[3])
	cv.polygon(pav, ramp[2])
	# facet lines
	cv.line(5, 4, 4, 6, ramp[4])
	cv.line(8, 3, 8, 6, ramp[2])
	cv.line(11, 4, 12, 6, ramp[1])
	cv.line(3, 7, 8, 14, ramp[3])
	cv.line(13, 7, 8, 14, ramp[1])
	cv.line(8, 7, 8, 13, ramp[2])
	for x in range(10, 14):
		cv.px(x, 8 + (x - 10), ramp[1])
	cv.outline(L.OUTLINE)
	big_star(cv, 12, 2, Color.WHITE)
	return cv

## Faceted sphere (reference Obsidian / Void Ore / Opal / Sunstone)
static func orb(ramp: Array, r: float = 6.2) -> PX.Canvas:
	var cv := icon()
	facet_poly(cv, octagon(8, 8.5, r), ramp, Vector2(8, 8.5), 8, octagon(7, 7.3, r * 0.42))
	cv.outline(L.OUTLINE)
	cv.px(5, 5, ramp[4])
	cv.px(6, 5, ramp[4])
	return cv
