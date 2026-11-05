## Generates effects: particles.png, impact.png, meteor.png, geode_open.png
extends SceneTree

const PX = preload("res://px.gd")
const L = preload("res://tilelib.gd")

var OL := Color.html("0b0a12")

func _init() -> void:
	particles()
	impact()
	meteor()
	geode_open()
	quit()

func soft_dot(c, ox: int, oy: int, cx: float, cy: float, r: float, col: Color, levels: int = 4) -> void:
	for yy in range(int(cy - r - 1), int(cy + r + 2)):
		for xx in range(int(cx - r - 1), int(cx + r + 2)):
			var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var a := ceilf((1.0 - d) * levels) / levels
			c.blend(ox + xx, oy + yy, Color(col.r, col.g, col.b, a))

func particles() -> void:
	var c := PX.Canvas.new(64, 64)
	var dust := L.pal(["8a7a6a", "b0a090", "d4c8b8", "efe8dc"])
	# row 0: dust x4
	var dr := [1.6, 2.4, 3.0, 3.4]
	for f in 4:
		var ox := f * 8
		var r: float = dr[f]
		for k in 3:
			var px_ := 4.0 + (k - 1) * r * 0.55
			var py_ := 4.5 - (0.6 if k == 1 else 0.0)
			for yy in 8:
				for xx in 8:
					var d := Vector2(xx + 0.5 - px_, yy + 0.5 - py_).length()
					if d < r * (0.75 if k != 1 else 0.95):
						var i := 2 if yy < 4 else 1
						if f == 3 and (xx + yy) % 2 == 0:
							continue
						c.px(ox + xx, yy, dust[i + (1 if f < 2 else 0)])
	# row 0 cols 4-7: glow dots (white)
	var gr := [1.6, 2.4, 3.1, 3.9]
	for f in 4:
		soft_dot(c, (4 + f) * 8, 0, 4, 4, gr[f], Color.WHITE, 4)
	# row 1: debris x4 (white-ish so it can be tinted)
	var deb := L.pal(["4a4a52", "8a8a94", "c8c8d0", "ffffff"])
	var shapes := [
		[[3, 3], [4, 3], [3, 4], [4, 4], [5, 4], [4, 5]],
		[[2, 3], [3, 3], [4, 3], [3, 4], [4, 4], [5, 4], [5, 5], [4, 5]],
		[[3, 2], [4, 2], [3, 3], [4, 3], [5, 3], [3, 4], [4, 4], [5, 4], [4, 5], [5, 5]],
		[[3, 3], [4, 3], [4, 4]],
	]
	for f in 4:
		var ox := f * 8
		for p in shapes[f]:
			var i := 2
			if p[1] == shapes[f][0][1]:
				i = 3
			elif p[0] >= 5 or p[1] >= 5:
				i = 1
			c.px(ox + p[0], 8 + p[1], deb[i])
	var tmp := PX.Canvas.new(32, 8)
	tmp.img.blit_rect(c.img, Rect2i(0, 8, 32, 8), Vector2i.ZERO)
	tmp.outline(Color.html("1a1a22"))
	c.img.blit_rect(tmp.img, Rect2i(0, 0, 32, 8), Vector2i(0, 8))
	# row 1 cols 4-7: sparks
	var sp := L.pal(["ff8a20", "ffc040", "fff0a0", "ffffff"])
	var spark_shapes := [
		[[2, 5, 1], [3, 4, 2], [4, 3, 3], [5, 2, 2]],
		[[4, 1, 1], [4, 2, 2], [1, 4, 1], [2, 4, 2], [4, 4, 3], [6, 4, 2], [7, 4, 1], [4, 6, 2], [4, 7, 1]],
		[[3, 3, 3], [4, 3, 2], [3, 4, 2], [4, 4, 3], [2, 2, 0], [5, 5, 0]],
		[[4, 4, 3], [3, 4, 1], [4, 3, 1]],
	]
	for f in 4:
		for p in spark_shapes[f]:
			c.px((4 + f) * 8 + p[0], 8 + p[1], sp[p[2]])
	# row 2: sparkle x4
	var tw := [[1, 0], [2, 1], [3, 2], [2, 1]]
	for f in 4:
		var ox := f * 8
		var arm: int = tw[f][0]
		c.px(ox + 4, 16 + 4, Color.WHITE)
		for k in range(1, arm + 1):
			var col := Color.WHITE if k < arm else Color.html("bff4ff")
			c.px(ox + 4 + k, 20, col)
			c.px(ox + 4 - k, 20, col)
			c.px(ox + 4, 20 + k, col)
			c.px(ox + 4, 20 - k, col)
		if tw[f][1] >= 2:
			c.px(ox + 3, 19, Color(1, 1, 1, 0.6))
			c.px(ox + 5, 21, Color(1, 1, 1, 0.6))
			c.px(ox + 5, 19, Color(1, 1, 1, 0.6))
			c.px(ox + 3, 21, Color(1, 1, 1, 0.6))
	# row 2 cols 4-7: smoke
	var smoke := L.pal(["4a4a56", "6a6a78", "8e8e9c", "b4b4c0"])
	var sr := [1.8, 2.6, 3.2, 3.6]
	for f in 4:
		var ox := (4 + f) * 8
		var r: float = sr[f]
		var a := 1.0 - f * 0.18
		for yy in 8:
			for xx in 8:
				var d := Vector2(xx + 0.5 - 4, yy + 0.5 - 4.2).length()
				if d < r:
					var i := 3 if (xx + yy) < 7 else (2 if d < r * 0.7 else 1)
					var col: Color = smoke[i]
					if f == 3 and (xx * 3 + yy) % 3 == 0:
						continue
					c.px(ox + xx, 16 + yy, Color(col.r, col.g, col.b, a))
	# row 3: star x4 (twinkling 5-point pixel star)
	var gold := L.pal(["8a5a08", "d29a22", "ffd048", "fff4b0"])
	var star_big := ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", ".#...#."]
	var star_small := [".......", "...#...", "..###..", ".#####.", "..###..", "..#.#..", "......."]
	for f in 4:
		var ox := f * 8
		var pat: Array = star_small if f == 2 else star_big
		var sub := PX.Canvas.new(8, 8)
		for yy in 7:
			for xx in 7:
				if pat[yy][xx] == "#":
					var i := 2
					if yy <= 2 and xx <= 3:
						i = 3
					if yy >= 5:
						i = 1
					if f == 1 and xx == 3 and yy == 3:
						i = 3
					sub.px(xx, yy + 1, gold[i])
		if f == 3:
			sub.px(3, 3, Color.WHITE)
		sub.outline(gold[0])
		c.img.blit_rect(sub.img, Rect2i(0, 0, 8, 8), Vector2i(ox, 24))
	# row 3 cols 4-7: coin spin
	var cw := [3.4, 2.4, 0.8, 2.4]
	for f in 4:
		var ox := (4 + f) * 8
		var sub := PX.Canvas.new(8, 8)
		var w: float = cw[f]
		for yy in 8:
			for xx in 8:
				var nx := (xx + 0.5 - 4) / maxf(w, 0.6)
				var ny := (yy + 0.5 - 4) / 3.4
				if nx * nx + ny * ny <= 1.0:
					var i := 2
					if nx < -0.3 or ny < -0.5:
						i = 3
					elif nx > 0.4:
						i = 1
					if f == 2:
						i = 1 if xx >= 4 else 2
					sub.px(xx, yy, gold[i])
		if f == 0:
			sub.px(4, 3, gold[1])
			sub.px(4, 4, gold[1])
			sub.px(4, 5, gold[1])
		sub.outline(gold[0])
		c.img.blit_rect(sub.img, Rect2i(0, 0, 8, 8), Vector2i(ox, 24))
	c.save("sprites/effects/particles.png")
	L.save_preview(c.img, "fx_particles.png", 6)

func impact() -> void:
	var c := PX.Canvas.new(64, 16)
	var flash := L.pal(["ffb040", "ffe080", "fff8d0", "ffffff"])
	for f in 4:
		var ox := f * 16
		var sub := PX.Canvas.new(16, 16)
		match f:
			0:
				sub.circle(8, 8, 3.2, flash[3])
				for k in 8:
					var a := k * TAU / 8.0
					var len := 6.0 if k % 2 == 0 else 4.5
					sub.line(8, 8, int(8 + cos(a) * len), int(8 + sin(a) * len), flash[2] if k % 2 == 0 else flash[1])
				sub.circle(8, 8, 2.0, Color.WHITE)
			1:
				sub.ellipse(8, 8, 5.2, 5.2, flash[2], false)
				sub.circle(8, 8, 2.4, flash[3])
				for k in 4:
					var a := k * TAU / 4.0 + PI / 4.0
					sub.line(int(8 + cos(a) * 3), int(8 + sin(a) * 3), int(8 + cos(a) * 7), int(8 + sin(a) * 7), flash[1])
			2:
				sub.ellipse(8, 8, 6.5, 6.5, flash[1], false)
				sub.px(8, 8, flash[2])
				for k in 6:
					var a := k * TAU / 6.0
					sub.px(int(8 + cos(a) * 4.5), int(8 + sin(a) * 4.5), flash[2])
			3:
				for k in 6:
					var a := k * TAU / 6.0 + 0.4
					sub.px(int(8 + cos(a) * 7), int(8 + sin(a) * 7), Color(flash[0].r, flash[0].g, flash[0].b, 0.7))
		c.img.blit_rect(sub.img, Rect2i(0, 0, 16, 16), Vector2i(ox, 0))
	c.save("sprites/effects/impact.png")
	L.save_preview(c.img, "fx_impact.png", 6)

func meteor() -> void:
	var c := PX.Canvas.new(32, 16)
	var fire := L.pal(["a02008", "f05a12", "ffa030", "ffe080", "fffbe0"])
	var rock := L.pal(["120c0e", "2a1e20", "4a3638", "6e5450", "94786a"])
	for f in 2:
		var ox := f * 16
		var sub := PX.Canvas.new(16, 16)
		# trail toward top-left
		for t in 12:
			var x := 10 - t
			var y := 10 - t
			var w := (1.0 - t / 12.0) * 2.6
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					if absf(dx + dy) * 0.5 + absf(dx - dy) * 0.5 > w + (0.6 if (t + f) % 2 == 0 else 0.0):
						continue
					var i := clampi(4 - int(t / 3.0) - absi(dx - dy) / 2, 0, 4)
					sub.px(x + dx, y + dy, fire[i])
		L.lump(sub, 11.0, 11.0, 3.2, 3.0, rock, OL, false)
		sub.px(12, 13, fire[2])
		sub.px(13, 12, fire[2])
		sub.px(13, 13, fire[3])
		c.img.blit_rect(sub.img, Rect2i(0, 0, 16, 16), Vector2i(ox, 0))
	c.save("sprites/effects/meteor.png")
	L.save_preview(c.img, "fx_meteor.png", 6)

func geode_shell(sub, cx: float, cy: float, r: float, half: int, sep: float, glow_amt: float) -> void:
	# half: 0 = whole closed, -1 left half, 1 right half (open, showing inside)
	var rock := L.pal(["24242a", "42424c", "666672", "8e8e9c", "b8b8c4"])
	var quartz := L.pal(["9aa0b8", "d0d6e8", "f4f6ff"])
	var crys := L.pal(["3a1474", "6a2ab8", "9a5cf0", "c8a0ff", "f4e8ff"])
	for yy in 48:
		for xx in 48:
			var px_ := xx + 0.5 - cx
			var py_ := yy + 0.5 - cy
			if half == -1:
				px_ += sep
				if px_ > 0.5:
					continue
			elif half == 1:
				px_ -= sep
				if px_ < -0.5:
					continue
			var nx := px_ / r
			var ny := py_ / (r * 0.92)
			var d := sqrt(nx * nx + ny * ny)
			if d > 1.0:
				continue
			var col: Color
			if half == 0 or d > 0.78 or absf(px_) < 0.5 and false:
				var lit := -nx * 0.6 - ny * 0.8
				var i := clampi(int((0.45 + lit * 0.4 + (1.0 - d) * 0.2) * 4.0 + 0.5), 0, 4)
				var bump := L.h01(xx, yy, 7)
				if bump > 0.85:
					i = maxi(0, i - 1)
				col = rock[i]
			elif d > 0.66:
				col = quartz[1] if (yy % 2 == 0) else quartz[2]
			else:
				# crystal interior: radial points
				var a := atan2(py_, px_)
				var spike := fposmod(a * 9.0 / TAU, 1.0)
				var depth := (0.66 - d) / 0.66
				var i2 := 2
				if spike < 0.35:
					i2 = 3
				elif spike > 0.75:
					i2 = 1
				if depth > 0.55:
					i2 = 4
				col = crys[i2]
			sub.px(xx, yy, col)
	if half != 0:
		# flat cut edge highlight
		var ex := int(cx + (-sep if half == -1 else sep))
		for yy in range(int(cy - r), int(cy + r) + 1):
			if sub.get_px(ex, yy).a > 0.0:
				sub.px(ex, yy, Color.html("f4e8ff"))

func geode_open() -> void:
	var c := PX.Canvas.new(288, 48)
	for f in 6:
		var sub := PX.Canvas.new(48, 48)
		var cx := 24.0
		var cy := 27.0
		var r := 13.0
		match f:
			0:
				geode_shell(sub, cx, cy, r, 0, 0, 0)
			1:
				geode_shell(sub, cx + 2, cy, r, 0, 0, 0)
				for p in [[26, 18], [26, 19], [27, 20], [27, 21], [26, 22]]:
					sub.px(p[0], p[1], OL)
			2:
				geode_shell(sub, cx - 1, cy, r, 0, 0, 0)
				var crack := [[23, 15], [23, 16], [24, 17], [24, 18], [23, 19], [23, 20], [24, 21], [24, 22], [25, 23], [24, 24], [24, 25], [25, 26]]
				for p in crack:
					sub.px(p[0], p[1], Color.html("e0c8ff"))
					sub.px(p[0] + 1, p[1], OL)
				L.glow(sub, 24, 21, 12, Color.html("c8a0ff"), 0.35)
			3:
				geode_shell(sub, cx, cy, r, 0, 0, 0)
				for k in 26:
					var y := 14 + k
					var x := 24 + (1 if (k / 2) % 2 == 0 else 0)
					sub.px(x, y, Color.WHITE)
					sub.px(x - 1, y, Color.html("c8a0ff"))
				L.glow(sub, 24, 27, 18, Color.html("e0c8ff"), 0.45)
				for k in 6:
					var a := k * TAU / 6.0 - PI / 2.0
					sub.line(24, 27, int(24 + cos(a) * 20), int(27 + sin(a) * 20), Color(1, 0.95, 1, 0.5))
			4, 5:
				var sep := 4.0 if f == 4 else 7.0
				L.glow(sub, 24, 27, 22, Color.html("ffe8a0"), 0.35 if f == 4 else 0.5)
				geode_shell(sub, cx, cy, r, -1, sep, 1.0)
				geode_shell(sub, cx, cy, r, 1, sep, 1.0)
				var stars := [[24, 9], [12, 14], [36, 13], [8, 30], [41, 32], [24, 44]]
				for k in (3 if f == 4 else 6):
					var s: Array = stars[k]
					sub.px(s[0], s[1], Color.WHITE)
					sub.px(s[0] - 1, s[1], Color(1, 1, 0.8, 0.6))
					sub.px(s[0] + 1, s[1], Color(1, 1, 0.8, 0.6))
					sub.px(s[0], s[1] - 1, Color(1, 1, 0.8, 0.6))
					sub.px(s[0], s[1] + 1, Color(1, 1, 0.8, 0.6))
		sub.outline(OL, 0.9)
		c.img.blit_rect(sub.img, Rect2i(0, 0, 48, 48), Vector2i(f * 48, 0))
	c.save("sprites/effects/geode_open.png")
	L.save_preview(c.img, "fx_geode_open.png", 3)
