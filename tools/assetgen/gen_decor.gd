## Generates assets/tilesets/decor.png (8 cols x 5 rows of 32x32 cells, 36 items).
extends SceneTree

const PX = preload("res://px.gd")
const L = preload("res://tilelib.gd")

var stone := L.pal(["1c1822", "2f2833", "4a3f45", "655650", "837160", "a08b72"])
var wood := L.pal(["26150b", "40240f", "5a3617", "7a4b21", "99632f", "b67e42"])
var iron := L.pal(["231e20", "3a3235", "565055", "766e72", "989094", "bab4b6"])
var cyan := L.pal(["0a3a5e", "0f78a8", "2cc0e8", "6ff2ff", "e0ffff"])
var blue := L.pal(["0c1a5a", "1840b0", "2c74f0", "6aaaff", "d0e8ff"])
var purple := L.pal(["2a0a50", "5a1ea0", "8e44e0", "c080ff", "f0dcff"])
var green := L.pal(["063a24", "0e7044", "1cb064", "5cf09a", "d0ffe4"])
var ice := L.pal(["3a6a9a", "6aa6d6", "a8d8f8", "dcf4ff", "ffffff"])
var bone := L.pal(["4a3a26", "8a7454", "c4ac84", "eadcb8", "fff8e8"])
var volc := L.pal(["140909", "241010", "381814", "4e2219", "662e1f", "84402e"])
var glow := L.pal(["5a1206", "a82a08", "f05a12", "ffa030", "fff0a0"])
var teal := L.pal(["0a3a38", "10706a", "1fb4a2", "4ff0d0", "c8fff4"])
var abrick := L.pal(["0d1517", "172427", "223538", "2f4749", "3f5d5b", "54766e"])
var gold := L.pal(["5a3606", "9a6410", "d29a22", "f6cc48", "fff0a0"])
var leaf := L.pal(["0c2a16", "17482a", "236a34", "3c9440", "6cc050", "a8e070"])
var rust := L.pal(["2a140a", "4e2412", "7a3c1c", "a65a2a", "cc8048"])
var red := L.pal(["4a0810", "8e1420", "d02834", "ff5a5a", "ffc0b8"])
var OL := Color.html("0b0a12")

func _init() -> void:
	var sheet := PX.Canvas.new(256, 160)
	for i in 36:
		var c := PX.Canvas.new(32, 32)
		call("d%d" % i, c)
		sheet.img.blit_rect(c.img, Rect2i(0, 0, 32, 32), Vector2i((i % 8) * 32, (i / 8) * 32))
	sheet.save("tilesets/decor.png")
	L.save_preview(sheet.img, "decor.png", 3)
	quit()

func shaded_cone(c, cx: float, base_y: float, w: float, h: float, ramp: Array[Color], down: bool = false, jag_seed: int = 0) -> void:
	# floor cone pointing up (or ceiling cone pointing down)
	for yy in 32:
		for xx in 32:
			var t: float
			if down:
				t = (yy + 0.5 - base_y) / h
			else:
				t = (base_y - (yy + 0.5)) / h
			if t < 0.0 or t > 1.0:
				continue
			var hw := w * 0.5 * pow(1.0 - t, 0.85)
			hw += (L.h01(yy, jag_seed, 3) - 0.5) * 0.8
			var dx := xx + 0.5 - cx
			if absf(dx) > hw:
				continue
			var s := dx / maxf(hw, 0.5)
			var i := 3
			if s < -0.35:
				i = 4
			elif s > 0.4:
				i = 1
			elif s > 0.05:
				i = 2
			if int(yy + jag_seed) % 5 == 0 and absf(s) < 0.8:
				i -= 1
			c.px(xx, yy, L.ri(ramp, i))
	c.outline(L.darken(ramp[0], 0.5))

func crystal_cluster(c, ramp: Array[Color], spikes: Array, glow_r: float, glow_col: Color) -> void:
	L.glow(c, 16, 24, glow_r, glow_col, 0.35)
	for s in spikes:
		L.crystal(c, s[0], s[1], s[2], s[3], s[4], ramp, L.darken(ramp[0], 0.5))
	# base rocks
	L.lump(c, 11, 30.5, 3.5, 2.0, stone, OL, false)
	L.lump(c, 21, 30.5, 3.0, 1.8, stone, OL, false)

func mushroom(c, x: float, base: float, h: float, capw: float, cap: Array[Color], stem: Array[Color], dots: bool) -> void:
	c.fill_rect(int(x) - 1, int(base - h), 2, int(h), stem[3])
	c.fill_rect(int(x), int(base - h), 1, int(h), stem[2])
	for yy in range(int(base - h - capw * 0.55), int(base - h + 1)):
		for xx in range(int(x - capw), int(x + capw) + 1):
			var nx := (xx + 0.5 - x) / capw
			var ny := (yy + 0.5 - (base - h + 0.5)) / (capw * 0.6)
			if nx * nx + ny * ny <= 1.0 and yy <= int(base - h):
				var i := 3 if nx < 0.0 else 2
				if ny < -0.6:
					i = 4
				c.px(xx, yy, L.ri(cap, i))
	if dots:
		c.px(int(x - capw * 0.4), int(base - h - capw * 0.3), Color(1, 1, 1))
		c.px(int(x + capw * 0.3), int(base - h - capw * 0.15), Color(1, 1, 1))

# ---------------------------------------------------------------- floor items
func d0(c) -> void:
	L.lump(c, 10, 28, 5.2, 3.6, stone, OL)
	L.lump(c, 19, 29, 4.0, 2.8, stone, OL)
	L.lump(c, 25, 30, 2.6, 1.8, stone, OL)

func d1(c) -> void:
	for k in 9:
		var x := 3.0 + k * 3.1 + L.h01(k, 1, 7) * 1.5
		L.lump(c, x, 30.5, 1.2 + L.h01(k, 2, 7) * 0.8, 1.0, stone, OL, false)

func d2(c) -> void:
	var cap := red
	var stem := bone
	mushroom(c, 11, 32, 7, 4.5, cap, stem, true)
	mushroom(c, 19, 32, 5, 3.5, cap, stem, true)
	mushroom(c, 24, 32, 3, 2.5, cap, stem, false)
	c.outline(OL)

func d3(c) -> void:
	L.glow(c, 16, 25, 13, cyan[3], 0.35)
	mushroom(c, 12, 32, 8, 4.5, cyan, ice, true)
	mushroom(c, 20, 32, 5, 3.5, cyan, ice, true)
	mushroom(c, 7, 32, 3, 2.2, cyan, ice, false)
	c.outline(Color.html("06182a"))

func d4(c) -> void:
	crystal_cluster(c, cyan, [[14, 31, 10, 4.5, -8], [19, 31, 7, 3.5, 20]], 10, cyan[3])

func d5(c) -> void:
	crystal_cluster(c, cyan, [[16, 31, 22, 7, 0], [10, 31, 14, 5, -22], [22, 31, 15, 5.5, 18], [6, 31, 8, 3.5, -40], [26, 31, 9, 3.5, 38]], 16, cyan[3])

func d6(c) -> void:
	crystal_cluster(c, purple, [[16, 31, 21, 7, 4], [10, 31, 15, 5.5, -18], [23, 31, 12, 5, 24], [6, 31, 7, 3.5, -38]], 16, purple[3])

func d7(c) -> void:
	crystal_cluster(c, green, [[15, 31, 17, 6, -6], [21, 31, 12, 5, 16], [9, 31, 9, 4, -28]], 14, green[3])

func d8(c) -> void:
	shaded_cone(c, 16, 32, 13, 24, stone, false, 2)
	L.lump(c, 8, 30.5, 3, 2, stone, OL, false)

func d9(c) -> void:
	shaded_cone(c, 15, 32, 11, 22, ice, false, 5)
	shaded_cone(c, 23, 32, 6, 11, ice, false, 9)

func d10(c) -> void:
	L.glow(c, 16, 24, 13, ice[3], 0.3)
	for s in [[16, 31, 18, 6, 0], [10, 31, 12, 4.5, -25], [22, 31, 13, 5, 22], [5, 31, 6, 3, -45], [27, 31, 7, 3, 45]]:
		L.crystal(c, s[0], s[1], s[2], s[3], s[4], ice, Color.html("1a3a6a"))

func d11(c) -> void:
	# long bone
	for k in 16:
		c.px(7 + k, 28, bone[3])
		c.px(7 + k, 29, bone[2])
	L.lump(c, 7, 27.8, 2.0, 1.6, bone, OL, false)
	L.lump(c, 7, 29.6, 2.0, 1.6, bone, OL, false)
	L.lump(c, 23, 27.8, 2.0, 1.6, bone, OL, false)
	L.lump(c, 23, 29.6, 2.0, 1.6, bone, OL, false)
	# ribs
	for k in 3:
		var x := 12 + k * 4
		for j in 5:
			c.px(x + (1 if j < 2 else 0), 26 - j, bone[3])
	c.outline(OL)

func d12(c) -> void:
	L.lump(c, 16, 23, 6.5, 5.5, bone, OL, false)
	c.fill_rect(12, 27, 9, 4, bone[2])
	c.fill_rect(12, 27, 9, 1, bone[3])
	for x in [13, 15, 17, 19]:
		c.px(x, 29, bone[0])
		c.px(x, 30, bone[1])
	c.fill_rect(12, 22, 3, 3, Color.html("1a1208"))
	c.fill_rect(18, 22, 3, 3, Color.html("1a1208"))
	c.px(16, 26, Color.html("2a1e10"))
	c.outline(OL)

func d13(c) -> void:
	shaded_cone(c, 16, 32, 14, 28, volc, false, 13)
	for p in [[15, 12], [16, 13], [16, 14], [15, 15], [17, 20], [18, 21], [18, 22], [14, 24], [13, 25], [16, 27], [17, 28]]:
		c.px(p[0], p[1], glow[3] if p[1] % 3 == 0 else glow[2])
	L.glow(c, 16, 24, 8, glow[2], 0.15)

func d14(c) -> void:
	L.glow(c, 16, 20, 13, glow[3], 0.35)
	L.lump(c, 16, 28, 9, 4.5, volc, OL, false)
	c.fill_rect(13, 24, 6, 3, glow[2])
	c.fill_rect(14, 24, 4, 2, glow[3])
	c.fill_rect(15, 24, 2, 1, glow[4])
	for p in [[15, 18], [17, 14], [14, 10], [18, 20], [16, 7]]:
		c.px(p[0], p[1], glow[4] if p[1] < 15 else glow[3])

func d15(c) -> void:
	c.fill_rect(10, 10, 12, 22, abrick[3])
	c.fill_rect(10, 10, 2, 22, abrick[4])
	c.fill_rect(20, 10, 2, 22, abrick[1])
	for y in [14, 18, 22, 26]:
		c.fill_rect(12, y, 8, 1, abrick[2])
	c.fill_rect(9, 28, 14, 4, abrick[2])
	c.fill_rect(9, 28, 14, 1, abrick[5])
	c.fill_rect(10, 16, 12, 2, gold[2])
	c.fill_rect(10, 16, 12, 1, gold[3])
	# broken jagged top
	for x in range(10, 22):
		var cut := int(L.h01(x, 1, 15) * 5.0)
		for y in range(10, 10 + cut):
			c.px(x, y, Color(0, 0, 0, 0))
	L.lump(c, 25, 29.5, 3, 2, abrick, OL, false)
	c.outline(OL)

func d16(c) -> void:
	L.glow(c, 16, 18, 14, teal[3], 0.3)
	c.fill_rect(9, 6, 14, 26, abrick[2])
	c.fill_rect(9, 6, 14, 2, abrick[4])
	c.fill_rect(9, 6, 2, 26, abrick[3])
	c.fill_rect(21, 6, 2, 26, abrick[0])
	for p in [[13, 10], [14, 10], [15, 10], [17, 10], [18, 10], [13, 12], [15, 12], [18, 12], [14, 14], [15, 14], [16, 14], [17, 14], [13, 17], [16, 17], [18, 17], [14, 19], [15, 20], [16, 20], [17, 19], [13, 23], [14, 23], [17, 23], [18, 23], [15, 25], [16, 25]]:
		c.px(p[0], p[1], teal[3] if (p[0] + p[1]) % 3 else teal[4])
	c.outline(OL)

func d17(c) -> void:
	crystal_cluster(c, purple, [[16, 31, 20, 6.5, 0], [10, 31, 13, 5, -24], [22, 31, 14, 5, 20]], 16, Color.html("8a7aff"))
	for p in [[16, 8], [9, 17], [23, 15], [13, 4], [26, 22], [5, 24]]:
		c.px(p[0], p[1], Color.html("fff6c8"))
		c.px(p[0] - 1, p[1], Color(1, 1, 0.8, 0.5))
		c.px(p[0] + 1, p[1], Color(1, 1, 0.8, 0.5))
		c.px(p[0], p[1] - 1, Color(1, 1, 0.8, 0.5))
		c.px(p[0], p[1] + 1, Color(1, 1, 0.8, 0.5))

func d18(c) -> void:
	# tilted broken cart
	var poly := PackedVector2Array([Vector2(4, 16), Vector2(26, 19), Vector2(24, 29), Vector2(6, 27)])
	c.polygon(poly, iron[2])
	c.polygon(PackedVector2Array([Vector2(5, 17), Vector2(25, 20), Vector2(25, 21), Vector2(5, 18)]), iron[4])
	for k in 4:
		c.line(9 + k * 5, 18 + k, 8 + k * 5, 27, iron[1])
	c.circle(9, 28.5, 2.6, iron[1])
	c.circle(9, 28.5, 1.0, iron[4])
	# missing right wheel -> debris
	L.lump(c, 25, 30.5, 2.5, 1.5, stone, OL, false)
	c.px(20, 30, wood[3])
	c.px(21, 30, wood[3])
	c.px(22, 31, wood[2])
	c.outline(OL)

func d19(c) -> void:
	c.fill_rect(7, 13, 18, 19, wood[3])
	c.rect_outline(7, 13, 18, 19, wood[1])
	c.rect_outline(8, 14, 16, 17, wood[4])
	c.line(9, 15, 22, 29, wood[2])
	c.line(9, 16, 21, 29, wood[4])
	c.line(22, 15, 9, 29, wood[2])
	for p in [[9, 15], [22, 15], [9, 29], [22, 29]]:
		c.px(p[0], p[1], iron[4])
	c.outline(OL)

func d20(c) -> void:
	for y in range(11, 32):
		var t := absf((y - 21.0) / 10.5)
		var hw := 8.5 - t * t * 2.0
		for x in range(int(16 - hw), int(16 + hw) + 1):
			var s := (x + 0.5 - 16) / hw
			var i := 3
			if s < -0.45:
				i = 4
			elif s > 0.5:
				i = 1
			elif s > 0.1:
				i = 2
			c.px(x, y, L.ri(wood, i))
	for y in [13, 20, 29]:
		for x in range(7, 26):
			if c.get_px(x, y).a > 0.0:
				c.px(x, y, iron[3] if x < 14 else iron[1])
	c.fill_rect(11, 11, 10, 1, wood[1])
	c.outline(OL)

func d21(c) -> void:
	L.lump(c, 16, 29, 9, 3.5, stone, OL)
	L.lump(c, 22, 30, 5, 2.4, stone, OL)
	# handle
	c.line(13, 26, 19, 8, wood[3])
	c.line(14, 26, 20, 8, wood[2])
	# head
	c.line(12, 8, 22, 6, iron[4])
	c.line(12, 9, 23, 7, iron[3])
	c.line(11, 10, 13, 9, iron[2])
	c.line(22, 8, 25, 10, iron[2])
	c.px(26, 11, iron[1])
	c.px(10, 11, iron[1])
	c.outline(OL)

func d22(c) -> void:
	for k in 5:
		var ang := deg_to_rad(-70 + k * 35)
		var base := Vector2(16, 31)
		for t in 13 + (3 if k == 2 else 0):
			var p := base + Vector2(sin(ang), -cos(ang)) * t + Vector2(sin(ang) * t * t * 0.02, 0)
			c.px(int(p.x), int(p.y), leaf[4] if t < 6 else leaf[3])
			if t % 3 == 1 and t > 2:
				c.px(int(p.x) - 1, int(p.y) + 1, leaf[2])
				c.px(int(p.x) + 1, int(p.y) + 1, leaf[5])
	c.outline(Color.html("06140a"))

func d23(c) -> void:
	for k in 9:
		var x := 9 + k * 2
		var hgt := 4 + int(L.h01(k, 3, 23) * 6)
		for t in hgt:
			var lean := 1 if (k % 2 == 0 and t > hgt / 2) else 0
			c.px(x + lean, 31 - t, leaf[5] if t > hgt - 2 else (leaf[4] if t > 1 else leaf[2]))
	c.outline(Color.html("06140a"))

func d24(c) -> void:
	# pipe
	c.fill_rect(2, 22, 20, 6, rust[3])
	c.fill_rect(2, 22, 20, 1, rust[4])
	c.fill_rect(2, 27, 20, 1, rust[1])
	c.fill_rect(8, 21, 3, 8, rust[2])
	# gear
	for yy in 32:
		for xx in 32:
			var p := Vector2(xx + 0.5 - 22, yy + 0.5 - 22)
			var d := p.length()
			var a := atan2(p.y, p.x)
			var r := 7.0 + (1.6 if fposmod(a * 8.0 / TAU, 1.0) < 0.5 else 0.0)
			if d < r and d > 2.2:
				var i := 2
				if p.x + p.y < -3:
					i = 4
				elif p.x + p.y > 3:
					i = 1
				c.px(xx, yy, L.ri(rust, i))
	c.outline(OL)

func d25(c) -> void:
	c.fill_rect(15, 14, 3, 18, wood[2])
	c.fill_rect(15, 14, 1, 18, wood[4])
	c.fill_rect(6, 8, 21, 9, wood[3])
	c.fill_rect(6, 8, 21, 1, wood[5])
	c.fill_rect(6, 16, 21, 1, wood[1])
	# arrow
	c.fill_rect(10, 12, 11, 1, Color.html("f0e0c0"))
	c.px(20, 11, Color.html("f0e0c0"))
	c.px(20, 13, Color.html("f0e0c0"))
	c.px(21, 12, Color.html("f0e0c0"))
	c.px(19, 10, Color.html("f0e0c0"))
	c.px(19, 14, Color.html("f0e0c0"))
	c.outline(OL)

# ---------------------------------------------------------------- ceiling items
func d26(c) -> void:
	shaded_cone(c, 15, 0, 9, 12, stone, true, 26)
	shaded_cone(c, 22, 0, 5, 6, stone, true, 27)

func d27(c) -> void:
	shaded_cone(c, 16, 0, 14, 26, stone, true, 28)
	shaded_cone(c, 8, 0, 6, 9, stone, true, 29)
	shaded_cone(c, 25, 0, 5, 7, stone, true, 30)

func d28(c) -> void:
	var xs := [6, 10, 14, 18, 22, 26]
	for k in xs.size():
		var hgt := 6 + int(L.h01(k, 1, 28) * 14)
		shaded_cone(c, xs[k], 0, 3.5, hgt, ice, true, 40 + k)

func d29(c) -> void:
	L.glow(c, 16, 10, 13, cyan[3], 0.35)
	L.lump(c, 16, 1.5, 9, 2.5, stone, OL, false)
	for s in [[16, 2, 18, 6, 180], [10, 2, 11, 4.5, 200], [22, 2, 12, 4.5, 160]]:
		L.crystal(c, s[0], s[1], s[2], s[3], s[4], cyan, Color.html("06182a"))

func d30(c) -> void:
	var warm := Color.html("ffcc66")
	L.glow(c, 16, 21, 14, warm, 0.4)
	for y in range(0, 12):
		c.px(16, y, iron[3] if y % 2 == 0 else iron[1])
	# lantern
	c.fill_rect(13, 12, 7, 2, iron[2])
	c.fill_rect(12, 14, 9, 11, iron[1])
	c.fill_rect(13, 15, 7, 9, Color.html("ffd070"))
	c.fill_rect(14, 16, 5, 7, Color.html("fff0b8"))
	c.fill_rect(15, 18, 3, 3, Color.html("ffffff"))
	c.fill_rect(12, 25, 9, 2, iron[2])
	c.px(16, 11, iron[4])
	c.rect_outline(11, 13, 11, 14, OL)

func d31(c) -> void:
	for k in 6:
		var x := 4 + k * 5
		var hgt := 8 + int(L.h01(k, 1, 31) * 18)
		for t in hgt:
			var sway := int(sin(t * 0.4 + k) * 1.2)
			c.px(x + sway, t, wood[3] if k % 2 == 0 else leaf[3])
			if t % 4 == 2 and k % 2 == 1:
				c.px(x + sway + 1, t, leaf[5])
				c.px(x + sway - 1, t + 1, leaf[4])
	c.outline(Color.html("0a0806"))

func d32(c) -> void:
	for y in range(0, 28, 3):
		if (y / 3) % 2 == 0:
			c.rect_outline(15, y, 3, 4, iron[4])
			c.px(16, y + 1, Color(0, 0, 0, 0))
			c.px(16, y + 2, Color(0, 0, 0, 0))
		else:
			c.fill_rect(16, y, 1, 4, iron[2])
	c.fill_rect(13, 28, 7, 2, iron[3])
	c.outline(OL)

func d33(c) -> void:
	L.glow(c, 16, 10, 11, glow[3], 0.35)
	L.lump(c, 16, 1.5, 8, 2.5, volc, OL, false)
	shaded_cone(c, 16, 2, 7, 9, volc, true, 33)
	for y in range(9, 14):
		c.px(16, y, glow[4] if y < 11 else glow[3])
	c.px(16, 18, glow[3])
	c.px(16, 19, glow[2])
	c.px(16, 24, glow[2])

# ---------------------------------------------------------------- big supports
func d34(c) -> void:
	# posts
	for px_ in [3, 25]:
		c.fill_rect(px_, 4, 4, 28, wood[3])
		c.fill_rect(px_, 4, 1, 28, wood[5])
		c.fill_rect(px_ + 3, 4, 1, 28, wood[1])
		for y in [10, 19, 27]:
			c.px(px_ + 1, y, wood[2])
			c.px(px_ + 2, y + 1, wood[2])
	# crossbeam
	c.fill_rect(0, 0, 32, 5, wood[3])
	c.fill_rect(0, 0, 32, 1, wood[5])
	c.fill_rect(0, 4, 32, 1, wood[1])
	for x in [5, 13, 21, 28]:
		c.px(x, 2, iron[4])
	# braces
	c.line(7, 5, 11, 1, wood[2])
	c.line(24, 5, 20, 1, wood[2])
	c.outline(OL)

func d35(c) -> void:
	var warm := Color.html("ffcc66")
	L.glow(c, 21, 12, 12, warm, 0.4)
	c.fill_rect(12, 6, 3, 26, wood[3])
	c.fill_rect(12, 6, 1, 26, wood[5])
	c.fill_rect(12, 6, 11, 2, wood[2])
	c.px(21, 8, iron[3])
	c.fill_rect(18, 9, 7, 2, iron[2])
	c.fill_rect(18, 11, 7, 7, iron[1])
	c.fill_rect(19, 12, 5, 5, Color.html("ffd070"))
	c.fill_rect(20, 13, 3, 3, Color.html("fff4c8"))
	c.fill_rect(18, 18, 7, 1, iron[2])
	c.fill_rect(10, 30, 7, 2, stone[2])
	c.outline(OL)
