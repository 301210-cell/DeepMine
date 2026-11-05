## Generates surface + cave parallax backgrounds (all tile horizontally; cave_*_far tiles both ways).
extends SceneTree

const PX = preload("res://px.gd")
const L = preload("res://tilelib.gd")

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

func _init() -> void:
	var only := OS.get_cmdline_user_args()
	if only.is_empty() or "surface" in only:
		mountains_far()
		mountains_near()
		clouds()
	for key in ["stone", "iron", "crystal", "frozen", "magma", "ancient"]:
		if only.is_empty() or key in only:
			cave_far(key)
			cave_near(key)
	quit()

func dith(v: float, x: int, y: int, ramp: Array[Color]) -> Color:
	var n := ramp.size()
	var f := clampf(v, 0.0, 0.9999) * (n - 1)
	var i := int(f)
	var frac := f - i
	var th: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
	if frac > th:
		i += 1
	return ramp[clampi(i, 0, n - 1)]

# ------------------------------------------------------------------ surface
func ridge(x: float, period: float, seed: int, amps: Array, freqs: Array) -> float:
	var v := 0.0
	for k in amps.size():
		var ph := L.h01(k, 1, seed) * TAU
		v += sin(x / period * TAU * float(freqs[k]) + ph) * float(amps[k])
	return v

func mountains_far() -> void:
	var W := 640
	var H := 220
	var c := PX.Canvas.new(W, H)
	var rock := L.pal(["141a3a", "1e2650", "2a3466", "38447e", "4a5a98", "6274b0"])
	var snow := L.pal(["8aa0d0", "b4c8ec", "dce8fa", "ffffff"])
	var back := L.pal(["1a2048", "222a5a", "2c366c"])
	# back pale range
	for x in W:
		var hb := 95.0 + ridge(x, W, 3, [22, 12, 6, 3], [2, 3, 7, 13])
		for y in range(int(hb), H):
			var t := float(y - hb) / (H - hb)
			c.px(x, y, dith(0.2 + t * 0.6, x, y, back))
	# main snowy range
	var hs := PackedFloat32Array()
	hs.resize(W)
	for x in W:
		var hh := 70.0 + ridge(x, W, 7, [34, 18, 9, 4.5, 2], [1, 3, 5, 9, 17])
		# sharpen peaks
		hs[x] = hh - absf(sin(x / float(W) * TAU * 4.0 + 1.2)) * 14.0
	for x in W:
		var slope := hs[(x + 1) % W] - hs[(x - 1 + W) % W]
		for y in range(int(hs[x]), H):
			var depth := y - hs[x]
			var lit := clampf(0.5 - slope * 0.25, 0.0, 1.0)
			var v := 0.25 + lit * 0.45 - depth / H * 0.45
			# crevices
			var cr := L.wnoise(x * 1.0, y * 0.18, 9.0, W, 512, 11)
			if cr > 0.72:
				v -= 0.18
			var col := dith(v, x, y, rock)
			var snowline := 52.0 + L.wnoise(x, 0, 18.0, W, 64, 12) * 26.0
			if y < snowline + L.wnoise(x, y, 4.0, W, 256, 13) * 10.0 and depth < 60:
				var sv := 0.35 + lit * 0.6 - depth / 120.0
				col = dith(sv, x, y, snow)
			if depth < 1.0:
				col = rock[0] if lit < 0.4 else (snow[2] if y < snowline + 6.0 else rock[5])
			c.px(x, y, col)
	c.save("backgrounds/surface_mountains_far.png")
	L.save_preview(c.img, "bg_mountains_far.png", 2)

func mountains_near() -> void:
	var W := 640
	var H := 170
	var c := PX.Canvas.new(W, H)
	var hill := L.pal(["0a0e20", "0f1530", "141c3c", "1a2448"])
	var pine := L.pal(["060a14", "0a1220", "0e1a2c", "132438"])
	var hs := PackedFloat32Array()
	hs.resize(W)
	for x in W:
		hs[x] = 95.0 + ridge(x, W, 21, [14, 8, 4, 2], [2, 3, 7, 11])
	for x in W:
		for y in range(int(hs[x]), H):
			var v := 0.75 - (y - hs[x]) / 80.0
			c.px(x, y, dith(v, x, y, hill))
		c.px(x, int(hs[x]), hill[3])
	# pines along the ridge
	var k := 0
	var x0 := 3.0
	while x0 < W:
		var ph := 16.0 + L.h01(k, 1, 22) * 26.0
		var pw := ph * 0.42
		var bx := x0
		var by := hs[int(bx) % W] + 4.0
		for yy in range(int(by - ph), int(by) + 1):
			var t := (by - yy) / ph
			var tier := fposmod(t * 4.0, 1.0)
			var hw := pw * (1.0 - t) * (0.55 + 0.45 * (1.0 - tier))
			for xx in range(int(bx - hw), int(bx + hw) + 1):
				var wx := posmod(xx, W)
				if yy >= 0 and yy < H:
					var i := 2 if xx < bx else 1
					if tier < 0.15:
						i = 3
					c.px(wx, yy, pine[i])
		c.fill_rect(int(bx), int(by), 1, 4, pine[0])
		x0 += 7.0 + L.h01(k, 2, 22) * 16.0
		k += 1
	c.save("backgrounds/surface_mountains_near.png")
	L.save_preview(c.img, "bg_mountains_near.png", 2)

func clouds() -> void:
	var W := 640
	var H := 120
	var c := PX.Canvas.new(W, H)
	var cl := L.pal(["9aa8d0", "c4cfea", "e6ecfa", "ffffff"])
	for k in 9:
		var cx := k * 71.0 + L.h01(k, 1, 31) * 40.0
		var cy := 30.0 + L.h01(k, 2, 31) * 60.0
		var size := 14.0 + L.h01(k, 3, 31) * 16.0
		var puffs := 4 + int(L.h01(k, 4, 31) * 4)
		for p in puffs:
			var px_ := cx + (p - puffs / 2.0) * size * 0.55
			var py_ := cy - sin(float(p) / max(1, puffs - 1) * PI) * size * 0.35
			var r := size * (0.45 + 0.35 * sin(float(p) / max(1, puffs - 1) * PI))
			for yy in range(int(py_ - r), int(py_ + r) + 1):
				for xx in range(int(px_ - r), int(px_ + r) + 1):
					var d := Vector2(xx + 0.5 - px_, yy + 0.5 - py_).length()
					if d > r or yy > cy + size * 0.25 or yy < 0 or yy >= H:
						continue
					var wx := posmod(xx, W)
					var shade := 1.0 - (yy - (cy - size)) / (size * 1.5) * 0.8
					var cur: Color = c.get_px(wx, yy)
					var col := dith(clampf(shade, 0.0, 1.0), wx, yy, cl)
					if cur.a == 0.0 or col.v > cur.v:
						c.px(wx, yy, Color(col.r, col.g, col.b, 0.92))
	c.save("backgrounds/surface_clouds.png")
	L.save_preview(c.img, "bg_clouds.png", 2)

# ------------------------------------------------------------------ caves
func biome_pal(key: String) -> Dictionary:
	match key:
		"stone":
			return {"rock": L.pal(["0d0b10", "17131a", "221c24", "2e262e", "3c3238", "4c4044"]), "void": L.pal(["06050a", "0b090f", "100d14"]), "accent": Color.html("5aa8ff")}
		"iron":
			return {"rock": L.pal(["0b0a0d", "141216", "1d1a1f", "28232a", "352e34", "443a3e"]), "void": L.pal(["050407", "09080b", "0e0c10"]), "accent": Color.html("b8652c")}
		"crystal":
			return {"rock": L.pal(["070820", "0c0f2e", "121840", "1a2252", "232e66", "2e3c7c"]), "void": L.pal(["030414", "06081c", "0a0c26"]), "accent": Color.html("5ff2ff")}
		"frozen":
			return {"rock": L.pal(["0a1222", "101c32", "172846", "20365a", "2c4870", "3c5e8a"]), "void": L.pal(["040810", "070d1a", "0b1424"]), "accent": Color.html("bfefff")}
		"magma":
			return {"rock": L.pal(["0c0505", "160909", "220d0c", "2e1210", "3c1914", "4e2218"]), "void": L.pal(["080303", "100505", "1a0806"]), "accent": Color.html("ff6a1a")}
		"ancient":
			return {"rock": L.pal(["070c0e", "0c1416", "121d20", "19282a", "223436", "2c4244"]), "void": L.pal(["030607", "060b0c", "0a1112"]), "accent": Color.html("4ff0d0")}
	return {}

func cave_far(key: String) -> void:
	var W := 640
	var H := 360
	var c := PX.Canvas.new(W, H)
	var pal := biome_pal(key)
	var rock: Array[Color] = pal.rock
	var voidp: Array[Color] = pal.void
	var accent: Color = pal.accent
	var seed := key.hash() & 0xffff
	var field := PackedFloat32Array()
	field.resize(W * H)
	for y in H:
		for x in W:
			var n := L.fbm(x, y, 96.0, W, H, seed, 4)
			# vertical pillar bias
			var pil := L.wnoise(x, 0, 80.0, W, 64, seed + 9)
			n += (pil - 0.5) * 0.35
			field[y * W + x] = n
	var th := 0.5
	for y in H:
		for x in W:
			var n := field[y * W + x]
			var col: Color
			if n > th:
				var above := field[posmod(y - 3, H) * W + x]
				var left := field[y * W + posmod(x - 3, W)]
				var v := 0.35 + (n - th) * 1.2
				if above <= th:
					v += 0.35
				if left <= th:
					v += 0.18
				var strata := L.wnoise(x * 0.25, y * 1.0, 6.0, W, H, seed + 3)
				if strata > 0.7:
					v -= 0.12
				col = dith(v, x, y, rock)
			else:
				var v2 := 0.3 + L.fbm(x, y, 40.0, W, H, seed + 5, 2) * 0.7 - (th - n) * 1.5
				col = dith(v2, x, y, voidp)
			c.px(x, y, col)
	# biome accents
	match key:
		"stone":
			_far_specks(c, field, th, W, H, seed, Color.html("4a9cff"), 70, 1)
		"iron":
			for y in H:
				for x in W:
					if field[y * W + x] > th and L.wnoise(x * 4.0, y * 0.25, 10.0, W, H, seed + 21) > 0.78:
						c.px(x, y, L.mix(c.get_px(x, y), accent, 0.35))
		"crystal":
			_far_crystals(c, field, th, W, H, seed, [Color.html("5ff2ff"), Color.html("b07cff")], 160)
			_far_specks(c, field, -1.0, W, H, seed + 3, Color.html("5ff2ff"), 60, 1)
		"frozen":
			for y in H:
				for x in W:
					if field[y * W + x] > th and field[posmod(y - 1, H) * W + x] <= th:
						c.px(x, y, Color.html("5a7ca8"))
						for k in int(L.h01(x, y, seed) * 6.0):
							if L.h01(x, 0, seed + 1) > 0.6:
								c.px(x, (y + k + 1) % H, Color.html("44628c"))
			_far_specks(c, field, th, W, H, seed, Color.html("cfefff"), 40, 1)
		"magma":
			_far_lava(c, field, th, W, H, seed)
		"ancient":
			_far_ruins(c, W, H, seed)
			_far_specks(c, field, th, W, H, seed, accent, 50, 1)
	c.save("backgrounds/cave_%s_far.png" % key)
	L.save_preview(c.img, "bg_cave_%s_far.png" % key, 2)

func _far_specks(c, field: PackedFloat32Array, th: float, W: int, H: int, seed: int, col: Color, count: int, size: int) -> void:
	for k in count:
		var x := int(L.h01(k, 1, seed + 40) * W)
		var y := int(L.h01(k, 2, seed + 40) * H)
		if field[y * W + x] > th:
			L.glow(c, x, y, 4.0, col, 0.35)
			c.px(x, y, col)

func _far_crystals(c, field: PackedFloat32Array, th: float, W: int, H: int, seed: int, cols: Array, count: int) -> void:
	for k in count:
		var x := int(L.h01(k, 1, seed + 50) * W)
		var y := int(L.h01(k, 2, seed + 50) * H)
		# find a floor: rock below air
		for s in 140:
			var yy := (y + s) % H
			if field[yy * W + x] > th and field[posmod(yy - 1, H) * W + x] <= th:
				var col: Color = cols[k % cols.size()]
				var dimc := Color(col.r * 0.55, col.g * 0.55, col.b * 0.7)
				L.glow(c, x, yy - 3, 9.0, col, 0.25)
				var hgt := 4 + int(L.h01(k, 3, seed) * 7)
				for t in hgt:
					var hw := int((1.0 - float(t) / hgt) * 2.0)
					for dx in range(-hw, hw + 1):
						c.px(posmod(x + dx, W), posmod(yy - t, H), dimc if dx >= 0 else col)
				break

func _far_lava(c, field: PackedFloat32Array, th: float, W: int, H: int, seed: int) -> void:
	var lava := L.pal(["4a0c04", "8a1c06", "d0420c", "ff8a24"])
	# glowing lava veins along rock edges + a couple of distant falls
	for y in H:
		for x in W:
			var n := field[y * W + x]
			if n > th and n < th + 0.025:
				c.px(x, y, lava[1])
			if n <= th and n > th - 0.02 and L.wnoise(x, y, 30.0, W, H, seed + 7) > 0.6:
				c.px(x, y, lava[2])
	for k in 3:
		var fx := int(L.h01(k, 9, seed) * W)
		for y in H:
			var wv := int(sin(y * 0.15 + k) * 1.0)
			for dx in range(-4, 5):
				var cur: Color = c.get_px(posmod(fx + dx + wv, W), y)
				var lc: Color = lava[3] if absi(dx) < 1 else (lava[2] if absi(dx) < 3 else lava[1])
				c.px(posmod(fx + dx + wv, W), y, L.mix(cur, lc, 0.75 if absi(dx) < 3 else 0.4))

func _far_ruins(c, W: int, H: int, seed: int) -> void:
	var stonec := L.pal(["0e1719", "152226", "1c2d31", "243a3e"])
	for k in 4:
		var ax := int(k * 160 + L.h01(k, 1, seed) * 60)
		var ay := int(60 + L.h01(k, 2, seed) * 220)
		var aw := 50 + int(L.h01(k, 3, seed) * 30)
		var ah := 40 + int(L.h01(k, 4, seed) * 30)
		# two columns + arch
		for side in [0, 1]:
			var cx: int = ax + int(side) * aw
			for y in range(ay, ay + ah):
				for dx in 6:
					c.px(posmod(cx + dx, W), y % H, stonec[2] if dx < 2 else stonec[1])
				if y % 6 == 0:
					for dx in 6:
						c.px(posmod(cx + dx, W), y % H, stonec[0])
		for dx in range(0, aw + 6):
			var t := float(dx) / (aw + 6)
			var yy := ay - int(sin(t * PI) * 14.0)
			for dy in 5:
				c.px(posmod(ax + dx, W), posmod(yy + dy, H), stonec[3] if dy == 0 else stonec[1])
		c.px(posmod(ax + aw / 2 + 3, W), posmod(ay - 8, H), Color.html("4ff0d0"))
		L.glow(c, posmod(ax + aw / 2 + 3, W), posmod(ay - 8, H), 5.0, Color.html("4ff0d0"), 0.3)

func cave_near(key: String) -> void:
	var W := 640
	var H := 360
	var c := PX.Canvas.new(W, H)
	var pal := biome_pal(key)
	var src: Array[Color] = pal.rock
	var rock: Array[Color] = []
	for col in src:
		rock.append(L.lighten(col, 0.06))
	var accent: Color = pal.accent
	var seed := (key.hash() & 0xffff) + 1000
	var ol := L.darken(rock[0], 0.6)
	var mask := PackedByteArray()
	mask.resize(W * H)
	# pillars
	var pillars := []
	for k in 4:
		pillars.append([k * 160.0 + 30.0 + L.h01(k, 1, seed) * 90.0, 18.0 + L.h01(k, 2, seed) * 22.0, L.h01(k, 3, seed) > 0.35])
	for y in H:
		var ty := absf(y / float(H) - 0.5) * 2.0
		for x in W:
			var solid := false
			for p in pillars:
				if not p[2]:
					continue
				var w: float = p[1] * (0.55 + 0.6 * pow(ty, 2.2))
				w += (L.wnoise(x, y, 12.0, W, H, seed + 4) - 0.5) * 8.0
				var dx := absf(fposmod(x - float(p[0]) + W * 0.5, W) - W * 0.5)
				if dx < w:
					solid = true
					break
			if not solid:
				# stalactites / stalagmites (cones from top & bottom)
				var colw := 20.0
				var ci := int(x / colw)
				var lx := fposmod(x, colw) - colw * 0.5 - (L.h01(ci, 7, seed) - 0.5) * 6.0
				var len_top := (14.0 + L.h01(ci, 5, seed) * 64.0) * (0.0 if L.h01(ci, 8, seed) < 0.28 else 1.0)
				var len_bot := (10.0 + L.h01(ci, 6, seed) * 40.0) * (0.0 if L.h01(ci, 9, seed) < 0.3 else 1.0)
				var wf := 0.3 + L.h01(ci, 10, seed) * 0.25
				var w_top := colw * wf * pow(maxf(0.0, 1.0 - y / maxf(len_top, 1.0)), 1.3)
				var w_bot := colw * wf * pow(maxf(0.0, 1.0 - (H - 1 - y) / maxf(len_bot, 1.0)), 1.3)
				if (y < len_top and absf(lx) < w_top) or ((H - 1 - y) < len_bot and absf(lx) < w_bot):
					solid = true
				if y < 10 + int(L.wnoise(x, 0, 16.0, W, 64, seed + 8) * 10.0) or H - 1 - y < 8 + int(L.wnoise(x, 0, 14.0, W, 64, seed + 9) * 10.0):
					solid = true
			mask[y * W + x] = 1 if solid else 0
	for y in H:
		for x in W:
			if mask[y * W + x] == 0:
				continue
			var lft := mask[y * W + posmod(x - 1, W)] == 0
			var rgt := mask[y * W + posmod(x + 1, W)] == 0
			var up := y > 0 and mask[(y - 1) * W + x] == 0
			var dn := y < H - 1 and mask[(y + 1) * W + x] == 0
			if lft or rgt or up or dn:
				c.px(x, y, ol)
				continue
			var lft2 := mask[y * W + posmod(x - 3, W)] == 0
			var rgt2 := mask[y * W + posmod(x + 3, W)] == 0
			var v := 0.42 + L.wnoise(x, y, 10.0, W, H, seed + 2) * 0.25
			if lft2:
				v += 0.3
			if rgt2:
				v -= 0.25
			if up or (y > 2 and mask[(y - 2) * W + x] == 0):
				v += 0.25
			if L.wnoise(x * 0.3, y, 5.0, W, H, seed + 3) > 0.75:
				v -= 0.12
			var cc := dith(v, x, y, rock)
			if lft2 and key in ["crystal", "frozen", "magma", "ancient"]:
				cc = L.mix(cc, accent, 0.22)
			c.px(x, y, cc)
	_near_accents(c, key, mask, W, H, seed, accent)
	c.save("backgrounds/cave_%s_near.png" % key)
	L.save_preview(c.img, "bg_cave_%s_near.png" % key, 2)

func _floor_points(mask: PackedByteArray, W: int, H: int, seed: int, count: int, ceiling: bool = false) -> Array:
	var out := []
	for k in count * 4:
		if out.size() >= count:
			break
		var x := int(L.h01(k, 1, seed + 70) * W)
		var y0 := 1 if ceiling else int(L.h01(k, 2, seed + 70) * (H - 20)) + 1
		for y in range(y0, H - 1):
			if ceiling:
				if mask[(y - 1) * W + x] == 1 and mask[y * W + x] == 0:
					out.append(Vector2i(x, y))
					break
			elif mask[y * W + x] == 0 and mask[(y + 1) * W + x] == 1:
				out.append(Vector2i(x, y))
				break
	return out

func _scan_floor(mask: PackedByteArray, W: int, H: int, x: int, from_y: int) -> int:
	for y in range(from_y, H - 1):
		if mask[y * W + x] == 0 and mask[(y + 1) * W + x] == 1:
			return y
	return -1

func _near_accents(c, key: String, mask: PackedByteArray, W: int, H: int, seed: int, accent: Color) -> void:
	match key:
		"stone":
			for k in 18:
				var x := int(L.h01(k, 1, seed + 80) * W)
				var fy := _scan_floor(mask, W, H, x, int(H * 0.55))
				if fy > 0:
					L.glow(c, x, fy - 4, 9.0, Color.html("5aaeff"), 0.22)
					_spikes(c, x, fy, [Color.html("0f4a8a"), Color.html("2a7ad0"), Color.html("5aaeff"), Color.html("aee0ff")], 11, W)
		"iron":
			# rusty girder across
			var gy := 150
			for x in W:
				for dy in 7:
					var col := Color.html("4a2414") if dy in [0, 6] else Color.html("6a3418")
					if dy == 1:
						col = Color.html("8a4a22")
					if (x % 24) < 2 and dy > 0 and dy < 6:
						col = Color.html("2a140a")
					c.px(x, gy + dy, col)
				if x % 24 == 12:
					c.px(x, gy + 3, Color.html("c08048"))
		"crystal":
			for k in 22:
				var x := int(L.h01(k, 1, seed + 81) * W)
				var fy := _scan_floor(mask, W, H, x, int(H * 0.5) if k < 12 else int(L.h01(k, 2, seed) * H * 0.5))
				if fy > 0:
					var col := [Color.html("1a5a9a"), Color.html("2a9ad8"), Color.html("5ff2ff"), Color.html("d8ffff")] if k % 2 == 0 else [Color.html("4a1e8a"), Color.html("7a3ed0"), Color.html("b07cff"), Color.html("f0dcff")]
					L.glow(c, x, fy - 10, 26.0 if k < 12 else 14.0, col[2], 0.32)
					_spikes(c, x, fy, col, 40 if k < 12 else 16, W, 2.2 if k < 12 else 1.0)
			for p in _floor_points(mask, W, H, seed + 5, 10, true):
				var colh := [Color.html("1a5a9a"), Color.html("2a9ad8"), Color.html("5ff2ff"), Color.html("d8ffff")]
				L.glow(c, p.x, p.y + 8, 14.0, colh[2], 0.3)
				var hl := 8 + int(L.h01(p.x, p.y, 3) * 14)
				for t in hl:
					var hw := int((1.0 - float(t) / hl) * 3.0)
					for dx in range(-hw, hw + 1):
						c.px(posmod(p.x + dx, W), p.y + t, colh[2] if dx < 0 else colh[1])
		"frozen":
			# frozen waterfall
			var fx := int(L.h01(1, 1, seed) * W)
			for y in H:
				for dx in range(-9, 10):
					var x := posmod(fx + dx, W)
					if mask[y * W + x] == 1:
						continue
					var stripe := posmod(dx + int(y * 0.15), 4)
					var col := Color.html("6aa6d6") if stripe == 0 else Color.html("3a6a9a")
					if absi(dx) > 7:
						col = Color.html("2a4a72")
					c.px(x, y, Color(col.r, col.g, col.b, 0.85))
			# icicles on ceilings
			for p in _floor_points(mask, W, H, seed, 40, true):
				var ln := 4 + int(L.h01(p.x, p.y, seed) * 12)
				for t in ln:
					c.px(p.x, p.y + t, Color.html("a8d8f8") if t < ln - 2 else Color.html("dcf4ff"))
					if t < ln / 2:
						c.px(p.x + 1, p.y + t, Color.html("4a7aa8"))
		"magma":
			var lava := [Color.html("8a1c06"), Color.html("d0420c"), Color.html("ff8a24"), Color.html("ffd060")]
			var fx := int(L.h01(2, 1, seed) * W)
			for y in H:
				for dx in range(-8, 9):
					var x := posmod(fx + dx + int(sin(y * 0.08) * 2.0), W)
					if mask[y * W + x] == 1:
						continue
					var i := 3 - absi(dx) / 3
					if posmod(y + dx * 3, 9) == 0:
						i = mini(3, i + 1)
					c.px(x, y, lava[clampi(i, 0, 3)])
			L.glow(c, fx, H - 20, 40.0, lava[2], 0.3)
			# glowing cracks on pillars
			for y in H:
				for x in W:
					if mask[y * W + x] == 1 and absf(L.wnoise(x, y, 14.0, W, H, seed + 31) - 0.5) < 0.018:
						c.px(x, y, lava[2] if L.h01(x, y, 3) > 0.5 else lava[1])
		"ancient":
			# carved bands + glyphs on solid areas
			for y in H:
				for x in W:
					if mask[y * W + x] == 1:
						if y % 40 == 0 or y % 40 == 1:
							c.px(x, y, Color.html("2c4244") if y % 40 == 0 else Color.html("0c1416"))
						elif y % 40 == 20 and x % 9 < 4 and L.h01(x / 9, y, seed) > 0.6:
							c.px(x, y, accent)
			for k in 10:
				var x := int(L.h01(k, 1, seed + 82) * W)
				var y := int(L.h01(k, 2, seed + 82) * H)
				if mask[y * W + x] == 1:
					L.glow(c, x, y, 7.0, accent, 0.35)
					c.px(x, y, Color.html("c8fff4"))

func _spikes(c, x: int, fy: int, col: Array, maxh: int, W: int, wmul: float = 1.0) -> void:
	for s in 3:
		var bx := x + int((s - 1) * 4 * wmul)
		var hgt := maxh * (0.5 + 0.5 * L.h01(x, s, 5)) * (1.0 if s == 1 else 0.6)
		for t in int(hgt):
			var hw := int((1.0 - float(t) / hgt) * 2.4 * wmul)
			for dx in range(-hw, hw + 1):
				var cc: Color = col[2] if dx < 0 else col[1]
				if dx == -hw + 1 and hw > 0:
					cc = col[3]
				c.px(posmod(bx + dx, W), fy - t, cc)
		c.px(posmod(bx, W), fy - int(hgt), col[3])
