## Main menu art: menu_far.png (opaque), menu_main.png (transparent), menu_cart.png, logo.png.
## Composition mirrors the loading-screen reference: snowy peak top-centre inside a cave arch,
## stone+timber mine portal centre, blue crystals left, purple crystals right, track + gem cart bottom-right.
## Track centre-line (for animating menu_cart, bottom-centre anchor): cubic Bezier
##   P0 (320,303) P1 (340,322) P2 (450,345) P3 (650,356)
extends SceneTree

const PX = preload("res://px.gd")
const K = preload("res://campkit.gd")

const TRACK := [Vector2(320, 303), Vector2(340, 322), Vector2(450, 345), Vector2(650, 356)]

func _init() -> void:
	var far = menu_far()
	far.save("backgrounds/menu_far.png")
	var main = menu_main()
	main.save("backgrounds/menu_main.png")
	var cart = menu_cart()
	cart.save("backgrounds/menu_cart.png")
	var logo = make_logo()
	logo.save("backgrounds/logo.png")
	# composite preview
	var comp := far.img.duplicate() as Image
	comp.blend_rect(main.img, Rect2i(0, 0, 640, 360), Vector2i.ZERO)
	var cp := bez(0.72)
	comp.blend_rect(cart.img, Rect2i(0, 0, 64, 48), Vector2i(int(cp.x) - 32, int(cp.y) - 46))
	comp.blend_rect(logo.img, Rect2i(0, 0, 400, 128), Vector2i(120, 6))
	K.preview(comp, "camp_menu_composite", 2, Color.BLACK)
	K.preview(cart.img, "camp_menu_cart", 4)
	quit()

func bez(t: float) -> Vector2:
	var a: Vector2 = TRACK[0]; var b: Vector2 = TRACK[1]; var c: Vector2 = TRACK[2]; var d: Vector2 = TRACK[3]
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t

# =================================================================== FAR LAYER
func ridge(x: float) -> float:
	var peaks := [[320.0, 38.0, 0.78], [205.0, 112.0, 0.7], [440.0, 96.0, 0.72], [560.0, 150.0, 0.6], [95.0, 150.0, 0.6], [270.0, 92.0, 0.9], [372.0, 84.0, 0.85]]
	var best := 999.0
	for p in peaks:
		var y: float = p[1] + absf(x - p[0]) * p[2]
		best = minf(best, y)
	return best + (PX.vnoise(x, 0.0, 6.0, 11) - 0.5) * 5.0 + (PX.vnoise(x, 3.0, 2.0, 12) - 0.5) * 2.0

func nearest_peak_x(x: float) -> float:
	var peaks := [[320.0, 38.0, 0.78], [205.0, 112.0, 0.7], [440.0, 96.0, 0.72], [560.0, 150.0, 0.6], [95.0, 150.0, 0.6], [270.0, 92.0, 0.9], [372.0, 84.0, 0.85]]
	var best := 999.0
	var bx := 0.0
	for p in peaks:
		var y: float = p[1] + absf(x - p[0]) * p[2]
		if y < best:
			best = y
			bx = p[0]
	return bx

func menu_far():
	var c = PX.Canvas.new(640, 360)
	var SKY := K.pal(["070a22", "0c1232", "141c4a", "222a62", "33357a", "4a3e8a"])
	var MT := K.pal(["0e1430", "18204a", "222e64", "30407e", "44589c", "6a84c0"])
	var SNOW := K.pal(["5a6ea8", "7e94cc", "a8bce6", "d2e0f6", "f2f8ff"])
	var RK := K.pal(["05070f", "0a0d1c", "10152c", "171e3c", "212a50", "2e3a6a", "44568e"])
	for y in 360:
		var t := float(y) / 230.0
		var sky: Color = SKY[0].lerp(SKY[2], clampf(t * 1.6, 0.0, 1.0)).lerp(SKY[5], clampf((t - 0.55) * 1.6, 0.0, 1.0))
		for x in 640:
			c.px(x, y, sky)
	# stars
	for i in 420:
		var sx := int(PX.hash01(i, 1, 70) * 640)
		var sy := int(pow(PX.hash01(i, 2, 70), 1.4) * 200)
		var b := PX.hash01(i, 3, 70)
		c.px(sx, sy, Color(0.75, 0.85, 1.0, 0.35 + b * 0.6))
		if b > 0.93:
			K.sparkle(c, sx, sy, Color(0.7, 0.9, 1.0, 0.7))
	# faint aurora band
	for x in 640:
		var ay := 70.0 + sin(x * 0.012) * 18.0 + sin(x * 0.031) * 6.0
		for k in 22:
			var a := 0.12 * (1.0 - k / 22.0) * (0.5 + 0.5 * sin(x * 0.02 + k * 0.2))
			c.blend(x, int(ay) + k, Color(0.3, 0.95, 0.85, floor(a * 30.0) / 30.0))
	# mountains
	for x in 640:
		var ry := ridge(float(x))
		var px_ := nearest_peak_x(float(x))
		var lit := x < px_
		var snow_line := 132.0 + (PX.vnoise(float(x), 9.0, 9.0, 13) - 0.5) * 26.0
		for y in range(int(ry), 260):
			var depth := y - ry
			var col: Color
			if y < snow_line and depth < 60.0:
				var si := 4 if lit else 2
				if depth < 2.0:
					si = 4 if lit else 3
				elif PX.vnoise(float(x), float(y), 3.0, 14) > 0.7:
					si -= 1
				col = SNOW[si]
			else:
				var mi := 4 if lit else 2
				if PX.vnoise(float(x), float(y), 4.0, 15) > 0.62:
					mi -= 1
				mi -= int(clampf((y - 150.0) / 40.0, 0.0, 2.0))
				col = MT[clampi(mi, 0, 5)]
			# atmospheric haze toward base
			col = col.lerp(SKY[4], clampf((y - 170.0) / 120.0, 0.0, 0.45))
			c.px(x, y, col)
	# near hills with pines
	for x in 640:
		var hy := 205.0 + sin(x * 0.02) * 8.0 + (PX.vnoise(float(x), 0.0, 10.0, 16) - 0.5) * 14.0
		var tree := PX.hash01(int(x / 7), 5, 17) > 0.45
		var th := 0.0
		if tree:
			var cx_ := int(x / 7) * 7 + 3
			th = maxf(0.0, 14.0 - absf(x - cx_) * 3.2) * (0.6 + PX.hash01(int(x / 7), 6, 17) * 0.6)
		for y in range(int(hy - th), 360):
			c.px(x, y, MT[1] if y < hy + 6 else MT[0])
	# cave mouth rock framing
	for y in 360:
		for x in 640:
			var nx := (x - 320.0) / 262.0
			var ny := (y - 190.0) / 182.0
			var n := (PX.vnoise(float(x), float(y), 14.0, 21) - 0.5) * 0.28 + (PX.vnoise(float(x), float(y), 4.0, 22) - 0.5) * 0.08
			var d := nx * nx + ny * ny + n
			var inside := d < 1.0 and y < 250
			if y >= 250:
				inside = absf(x - 320.0) < 262.0 * sqrt(maxf(0.0, 1.0 - ny * ny * 0.4)) + n * 120.0
			if inside:
				continue
			var rim := d < 1.09 and y < 250
			var tex := PX.vnoise(float(x), float(y) * 0.6, 12.0, 23)
			var ri := 2 + (1 if tex > 0.6 else 0) + (1 if tex > 0.86 else 0)
			if rim:
				ri = 5 if d < 1.04 else 4
			var dist_edge := absf(x - 320.0) / 320.0
			ri -= int(dist_edge * 2.2)
			c.px(x, y, RK[clampi(ri, 0, 6)])
	# stalactites from the arch
	for i in 26:
		var sx := 70.0 + i * 19.0 + PX.hash01(i, 0, 30) * 10.0
		var nx2 := (sx - 320.0) / 262.0
		var edge_y := 190.0 - 182.0 * sqrt(maxf(0.0, 1.0 - nx2 * nx2)) + 4.0
		var ln := 8.0 + PX.hash01(i, 1, 30) * 22.0
		var w := 3.0 + PX.hash01(i, 2, 30) * 4.0
		c.polygon(PackedVector2Array([Vector2(sx - w, edge_y - 4), Vector2(sx + w, edge_y - 4), Vector2(sx + 0.5, edge_y + ln)]), RK[3])
		c.line(int(sx - w + 1), int(edge_y - 3), int(sx), int(edge_y + ln - 2), RK[5])
	# glowing wall crystals in the far corners
	for g in [[60, 70, K.BLUE, -0.6], [96, 38, K.BLUE, 0.4], [586, 58, K.PURP, 0.5], [610, 120, K.PURP, -0.4], [40, 160, K.BLUE, 0.9]]:
		var gr: Array[Color] = g[2]
		K.glow(c, g[0], g[1], 22.0, gr[4], 0.35)
		K.crystal(c, g[0], g[1] + 8, 16.0, 7.0, g[3], gr)
		K.crystal(c, g[0] + 5, g[1] + 8, 10.0, 5.0, g[3] + 0.5, gr)
	return c

# =================================================================== MAIN LAYER
func big_crystal(c, bx: float, by: float, L: float, W: float, ang: float, r: Array[Color]) -> void:
	var u := Vector2(sin(ang), -cos(ang))
	var v := Vector2(cos(ang), sin(ang))
	var base := Vector2(bx, by)
	var sh := L * 0.74
	var P := func(s: float, t: float) -> Vector2: return base + u * s + v * t
	var hw := W * 0.5
	var t1 := -W / 6.0
	var t2 := W / 6.0
	var tip: Vector2 = P.call(L, W * 0.04)
	c.polygon(PackedVector2Array([P.call(0, -hw), P.call(sh, -hw), P.call(sh, t1), P.call(0, t1)]), r[4])
	c.polygon(PackedVector2Array([P.call(0, t1), P.call(sh, t1), P.call(sh, t2), P.call(0, t2)]), r[3])
	c.polygon(PackedVector2Array([P.call(0, t2), P.call(sh, t2), P.call(sh, hw), P.call(0, hw)]), r[2])
	c.polygon(PackedVector2Array([P.call(sh, -hw), tip, P.call(sh, t1)]), r[5])
	c.polygon(PackedVector2Array([P.call(sh, t1), tip, P.call(sh, t2)]), r[4])
	c.polygon(PackedVector2Array([P.call(sh, t2), tip, P.call(sh, hw)]), r[3])
	# facet edges
	var e1: Vector2 = P.call(0, t1); var e2: Vector2 = P.call(sh, t1)
	c.line(int(e1.x), int(e1.y), int(e2.x), int(e2.y), r[5])
	c.line(int(e2.x), int(e2.y), int(tip.x), int(tip.y), r[6])
	var e3: Vector2 = P.call(0, t2); var e4: Vector2 = P.call(sh, t2)
	c.line(int(e3.x), int(e3.y), int(e4.x), int(e4.y), r[2].darkened(0.2))
	# inner light streak
	var s1: Vector2 = P.call(L * 0.1, -hw * 0.6); var s2: Vector2 = P.call(L * 0.62, -hw * 0.6)
	c.line(int(s1.x), int(s1.y), int(s2.x), int(s2.y), r[5])
	c.px(int(tip.x), int(tip.y), Color.WHITE)

func crystal_cluster(c, cx: float, cy: float, r: Array[Color], mirror: float, scale: float) -> void:
	K.glow(c, cx + 10 * mirror, cy - 70 * scale, 95.0 * scale, r[4], 0.32)
	K.glow(c, cx, cy - 10, 60.0 * scale, r[5], 0.25)
	var spec := [
		[-34, 2, 92, 30, -0.42], [40, 4, 80, 26, 0.5], [-14, 4, 120, 30, -0.2], [26, 0, 104, 30, 0.22],
		[0, 6, 168, 42, 0.04], [-50, 8, 54, 20, -0.75], [56, 8, 50, 18, 0.8], [12, 10, 60, 20, 0.45], [-24, 10, 64, 22, -0.5],
	]
	for s in spec:
		big_crystal(c, cx + s[0] * mirror * scale, cy + s[1], s[2] * scale, s[3] * scale, s[4] * mirror, r)
	# base rubble
	for i in 14:
		var rx := cx + (PX.hash01(i, 0, 41) - 0.5) * 140.0 * scale
		var ry := cy + 6 + PX.hash01(i, 1, 41) * 8.0
		c.ellipse(rx, ry, 6.0, 4.0, K.NAVY[3])
		c.px(int(rx) - 2, int(ry) - 2, K.NAVY[5])
	for i in 6:
		var sx := int(cx + (PX.hash01(i, 3, 42) - 0.5) * 110.0 * scale)
		var sy := int(cy - PX.hash01(i, 4, 42) * 140.0 * scale)
		K.sparkle(c, sx, sy, r[5], i % 2 == 0)

func track(c) -> void:
	# sleepers
	var steps := 90
	for i in range(0, steps):
		var t := float(i) / steps
		var p := bez(t)
		var tn := (bez(minf(1.0, t + 0.01)) - bez(maxf(0.0, t - 0.01))).normalized()
		var n := Vector2(-tn.y, tn.x)
		var g := lerpf(9.0, 30.0, pow(t, 1.2))
		var spacing := int(lerpf(3.0, 6.0, t))
		if i % maxi(1, spacing) != 0:
			continue
		var a := p - n * g * 0.75
		var b := p + n * g * 0.75
		var thick := int(lerpf(2.0, 5.0, t))
		for k in thick:
			c.line(int(a.x), int(a.y) + k, int(b.x), int(b.y) + k, K.WOOD[4] if k == 0 else K.WOOD[2])
	# rails
	for side in [-1.0, 1.0]:
		var prev := Vector2.ZERO
		for i in range(0, 200):
			var t := float(i) / 199.0
			var p := bez(t)
			var tn := (bez(minf(1.0, t + 0.005)) - bez(maxf(0.0, t - 0.005))).normalized()
			var n := Vector2(-tn.y, tn.x)
			var g := lerpf(9.0, 30.0, pow(t, 1.2))
			var q: Vector2 = p + n * g * 0.5 * side
			if i > 0:
				var w := int(lerpf(2.0, 4.0, t))
				for k in w:
					c.line(int(prev.x), int(prev.y) + k - 1, int(q.x), int(q.y) + k - 1, K.METAL[5] if k == 0 else K.METAL[2])
			prev = q

func menu_main():
	var c = PX.Canvas.new(640, 360)
	var FL := K.pal(["0a0c1a", "141830", "1e2444", "2a3258", "3a446e", "4e5a88"])
	# cave floor
	for x in 640:
		var fy := 300.0 + (PX.vnoise(float(x), 0.0, 18.0, 50) - 0.5) * 10.0 + (absf(x - 320.0) / 320.0) * -6.0
		for y in range(int(fy), 360):
			var tex := PX.vnoise(float(x), float(y), 5.0, 51)
			var fi := 3 if y < fy + 3 else (2 if tex > 0.45 else 1)
			if tex > 0.82:
				fi += 1
			c.px(x, y, FL[clampi(fi, 0, 5)])
	# cobbles
	for i in 140:
		var cx := PX.hash01(i, 0, 52) * 640.0
		var cy := 308.0 + PX.hash01(i, 1, 52) * 52.0
		var s := 2.0 + (cy - 300.0) / 18.0
		c.ellipse(cx, cy, s * 1.5, s, FL[3])
		c.px(int(cx - s * 0.6), int(cy - s * 0.5), FL[5])
	# coloured floor light (crystals + warm entrance)
	K.light(c, 80, 330, 120.0, K.CYAN[3], 0.45)
	K.light(c, 580, 330, 110.0, K.PURP[4], 0.45)
	K.light(c, 320, 306, 60.0, K.FIRE[4], 0.22)

	building(c)
	track(c)
	crystal_cluster(c, 78.0, 330.0, K.BLUE, 1.0, 1.0)
	crystal_cluster(c, 580.0, 328.0, K.PURP, -1.0, 0.85)
	# small foreground rocks + scattered gems
	for g in [[170, 340, K.BLUE], [470, 352, K.PURP], [250, 350, K.BLUE], [520, 318, K.PURP]]:
		var gr: Array[Color] = g[2]
		K.glow(c, g[0], g[1] - 6, 14.0, gr[4], 0.3)
		big_crystal(c, g[0], g[1], 16.0, 7.0, -0.3, gr)
		big_crystal(c, g[0] + 5, g[1], 11.0, 5.0, 0.5, gr)
	c.outline(K.OUT)
	return c

func building(c) -> void:
	var SL := K.pal(["10142a", "1a2040", "262e58", "343e72", "48548e", "6a78b0"])
	# --- left scaffold tower
	K.beam(c, 172, 182, 6, 123, false, 61)
	K.beam(c, 214, 182, 6, 123, false, 62)
	for py in [212, 252]:
		K.planks(c, 166, py, 60, 5, K.WOOD, 6, false, py, 3)
		c.fill_rect(166, py, 60, 1, K.WOOD[5])
	for seg in [[184, 212], [217, 252], [257, 300]]:
		c.line(178, seg[0], 214, seg[1] - 1, K.WOOD[3]); c.line(214, seg[0], 178, seg[1] - 1, K.WOOD[2])
	# ladder
	for lx in [190, 199]:
		c.fill_rect(lx, 217, 2, 88, K.WOOD[4])
	for ly in range(220, 304, 6):
		c.fill_rect(190, ly, 11, 1, K.WOOD[3])
	K.shingle_roof(c, PackedVector2Array([Vector2(164, 184), Vector2(176, 170), Vector2(218, 170), Vector2(230, 184)]), SL, 3, 6, 63)
	K.lantern(c, 206, 217, 1)
	K.lantern(c, 172, 257, 2)
	# --- right stone tower
	K.bricks(c, 418, 204, 48, 101, K.STONE, 9, 6, 64)
	K.shingle_roof(c, PackedVector2Array([Vector2(412, 206), Vector2(442, 174), Vector2(472, 206)]), SL, 3, 6, 65)
	K.window(c, 434, 222, 14, 16, true)
	K.window(c, 434, 262, 14, 14, true)
	# --- main hall upper floor (half-timbered)
	K.planks(c, 236, 194, 168, 48, K.WOOD, 4, true, 66, 3)
	for by in [194, 240]:
		K.beam(c, 232, by, 176, 5, true, by)
	for bx in [236, 278, 316, 358, 398]:
		K.beam(c, bx, 196, 6, 46, false, bx)
	for w in [[250, 200], [290, 200], [332, 200], [372, 200]]:
		K.window(c, w[0], w[1], 16, 14, true)
		K.light(c, w[0] + 8, w[1] + 7, 16.0, K.FIRE[5], 0.25)
	# roof
	K.shingle_roof(c, PackedVector2Array([Vector2(226, 197), Vector2(262, 162), Vector2(378, 162), Vector2(414, 197)]), SL, 4, 8, 67)
	c.fill_rect(258, 160, 124, 3, K.WOOD[2]); c.fill_rect(258, 160, 124, 1, K.WOOD[4])
	# gable with round emblem
	K.fill_poly_fn(c, PackedVector2Array([Vector2(288, 168), Vector2(320, 142), Vector2(352, 168)]), func(x: int, y: int) -> Color:
		return K.WOOD[3] if x < 320 else K.WOOD[2])
	c.line(288, 168, 320, 142, K.WOOD[5]); c.line(320, 142, 352, 168, K.WOOD[1])
	c.circle(320.0, 157.0, 7.0, K.GOLD[2])
	c.circle(320.0, 157.0, 5.5, K.FIRE[5])
	c.line(316, 160, 324, 153, K.WOOD[1]); c.line(318, 153, 325, 156, K.METAL[4])
	K.glow(c, 320.0, 157.0, 12.0, K.FIRE[5], 0.3)
	# chimney + smoke
	K.bricks(c, 386, 146, 10, 22, K.STONE, 5, 3, 68)
	for i in 4:
		K.glow(c, 391.0 + i * 3.0, 138.0 - i * 9.0, 5.0 + i * 1.5, Color(0.7, 0.72, 0.85), 0.25)
	# --- stone ground floor
	K.bricks(c, 222, 242, 196, 63, K.STONE, 10, 6, 69)
	c.fill_rect(222, 242, 196, 2, K.STONE[1])
	K.window(c, 240, 258, 18, 16, true)
	K.window(c, 382, 258, 18, 16, true)
	# entrance tunnel
	for y in range(250, 305):
		for x in range(286, 354):
			var dx := absf(x - 320.0) / 34.0
			var t := float(y - 250) / 55.0
			var glow_core := clampf(1.0 - Vector2(dx, (y - 278.0) / 26.0).length(), 0.0, 1.0)
			var col: Color = Color.html("06070f").lerp(K.FIRE[2], glow_core * 0.55).lerp(K.FIRE[4], pow(glow_core, 3.0) * 0.8)
			col = col.lerp(K.NAVY[1], t * 0.15)
			c.px(x, y, col)
	for k in 3:
		var inset := 8 + k * 7
		var top := 254 + k * 5
		var bc: Color = K.WOOD[2].darkened(0.35 + k * 0.15)
		c.fill_rect(286 + inset, top, 3, 305 - top, bc)
		c.fill_rect(354 - inset - 3, top, 3, 305 - top, bc)
		c.fill_rect(286 + inset, top, 68 - inset * 2, 3, bc)
	# timber portal
	K.beam(c, 277, 244, 10, 61, false, 70)
	K.beam(c, 353, 244, 10, 61, false, 71)
	K.beam(c, 268, 236, 104, 10, true, 72)
	c.polygon(PackedVector2Array([Vector2(287, 246), Vector2(299, 246), Vector2(287, 258)]), K.WOOD[3])
	c.polygon(PackedVector2Array([Vector2(353, 246), Vector2(341, 246), Vector2(353, 258)]), K.WOOD[2])
	for bx in [279, 355]:
		c.fill_rect(bx, 238, 6, 2, K.METAL[3])
	# lanterns + warm light
	K.light(c, 274, 250, 34.0, K.FIRE[4], 0.4)
	K.light(c, 366, 250, 34.0, K.FIRE[4], 0.4)
	K.lantern(c, 272, 247, 0)
	K.lantern(c, 368, 247, 2)
	c.fill_rect(270, 246, 4, 1, K.METAL[2]); c.fill_rect(366, 246, 4, 1, K.METAL[2])
	# crates & barrels by the right tower
	for cr in [[468, 289, 16], [484, 293, 12], [472, 275, 12]]:
		K.planks(c, cr[0], cr[1], cr[2], cr[2], K.WOOD, 3, false, cr[0], 3)
		c.rect_outline(cr[0], cr[1], cr[2], cr[2], K.WOOD[0])
		c.line(cr[0] + 1, cr[1] + 1, cr[0] + cr[2] - 2, cr[1] + cr[2] - 2, K.WOOD[2])
	# post with lantern along the track
	K.beam(c, 498, 262, 5, 50, false, 73)
	c.fill_rect(498, 262, 12, 3, K.WOOD[3])
	K.lantern(c, 508, 265, 1)

# =================================================================== CART
func menu_cart():
	var c = PX.Canvas.new(128, 48)
	for f in 2:
		var t = PX.Canvas.new(64, 48)
		K.glow(t, 32.0, 14.0, 26.0, K.PURP[5], 0.35)
		# gem heap
		var gems := [[14, 16, K.PURP, 6], [24, 11, K.PURP, 7], [34, 9, K.BLUE, 6], [44, 12, K.PURP, 7], [52, 17, K.PURP, 5], [20, 18, K.GOLD, 4], [30, 16, K.PURP, 6], [40, 18, K.BLUE, 5], [47, 20, K.PURP, 5]]
		for g in gems:
			var gr: Array[Color] = g[2]
			var gx: float = g[0]
			var gy: float = g[1]
			var s: float = g[3]
			t.polygon(PackedVector2Array([Vector2(gx - s, gy + 2), Vector2(gx - s * 0.5, gy - s), Vector2(gx + s * 0.5, gy - s), Vector2(gx + s, gy + 2), Vector2(gx, gy + s)]), gr[3])
			t.polygon(PackedVector2Array([Vector2(gx - s * 0.5, gy - s), Vector2(gx + s * 0.5, gy - s), Vector2(gx, gy + 1)]), gr[5])
			t.polygon(PackedVector2Array([Vector2(gx, gy + 1), Vector2(gx + s, gy + 2), Vector2(gx, gy + s)]), gr[2])
			t.px(int(gx - s * 0.3), int(gy - s + 1), Color.WHITE)
		# bucket body (slight 3/4 view)
		K.fill_poly_fn(t, PackedVector2Array([Vector2(4, 20), Vector2(60, 20), Vector2(55, 40), Vector2(9, 40)]), func(x: int, y: int) -> Color:
			var u := float(x - 4) / 56.0
			var b := 4 if u < 0.15 else (3 if u < 0.7 else 2)
			if (x - 4) % 11 == 0:
				b -= 1
			var col: Color = K.METAL[b]
			if PX.vnoise(float(x), float(y), 3.0, 80) > 0.74:
				col = K.RUST[b]
			return col)
		t.fill_rect(2, 18, 60, 4, K.METAL[4]); t.fill_rect(2, 18, 60, 1, K.METAL[6])
		t.fill_rect(8, 29, 48, 2, K.METAL[2]); t.fill_rect(8, 29, 48, 1, K.METAL[5])
		for rx in [8, 19, 30, 41, 52]:
			t.px(rx, 24, K.METAL[6]); t.px(rx, 35, K.METAL[6])
		t.fill_rect(8, 39, 48, 3, K.METAL[1])
		K.wheel(t, 17.0, 41.0, 6.0, f * PI / 8.0)
		K.wheel(t, 47.0, 41.0, 6.0, f * PI / 8.0)
		var sp := [Vector2i(28, 4), Vector2i(50, 8)] if f == 0 else [Vector2i(16, 8), Vector2i(40, 3)]
		for p in sp:
			K.sparkle(t, p.x, p.y, K.PURP[6], true)
		t.outline(K.OUT)
		c.blit(t.img, f * 64, 0)
	return c

# =================================================================== LOGO
func letter_mask(m, ch: String, ox: int, oy: int) -> int:
	var V := func(x: float, y: float) -> Vector2: return Vector2(ox + x, oy + y)
	var W := Color.WHITE
	var Z := Color(0, 0, 0, 0)
	match ch:
		"D":
			m.polygon(PackedVector2Array([V.call(0, 0), V.call(30, 0), V.call(42, 12), V.call(42, 40), V.call(30, 52), V.call(0, 52)]), W)
			m.polygon(PackedVector2Array([V.call(13, 13), V.call(25, 13), V.call(29, 17), V.call(29, 35), V.call(25, 39), V.call(13, 39)]), Z)
			return 42
		"E":
			m.fill_rect(ox, oy, 13, 52, W); m.fill_rect(ox, oy, 36, 12, W); m.fill_rect(ox, oy + 20, 30, 12, W); m.fill_rect(ox, oy + 40, 36, 12, W)
			return 36
		"P":
			m.polygon(PackedVector2Array([V.call(0, 0), V.call(30, 0), V.call(40, 10), V.call(40, 24), V.call(30, 34), V.call(13, 34), V.call(13, 52), V.call(0, 52)]), W)
			m.polygon(PackedVector2Array([V.call(13, 12), V.call(24, 12), V.call(27, 15), V.call(27, 20), V.call(24, 23), V.call(13, 23)]), Z)
			return 40
		"M":
			m.fill_rect(ox, oy, 13, 52, W); m.fill_rect(ox + 41, oy, 13, 52, W)
			m.polygon(PackedVector2Array([V.call(0, 0), V.call(14, 0), V.call(27, 16), V.call(40, 0), V.call(54, 0), V.call(54, 9), V.call(27, 39), V.call(0, 9)]), W)
			return 54
		"I":
			m.fill_rect(ox, oy, 26, 11, W); m.fill_rect(ox + 6, oy, 14, 52, W); m.fill_rect(ox, oy + 41, 26, 11, W)
			return 26
		"N":
			m.fill_rect(ox, oy, 13, 52, W); m.fill_rect(ox + 31, oy, 13, 52, W)
			m.polygon(PackedVector2Array([V.call(0, 0), V.call(14, 0), V.call(44, 52), V.call(30, 52)]), W)
			return 44
	return 0

func make_logo():
	var c = PX.Canvas.new(400, 128)
	var mask_deep = PX.Canvas.new(400, 128)
	var mask_mine = PX.Canvas.new(400, 128)
	var x := 22
	var top := 14
	for ch in "DEEP":
		x += letter_mask(mask_deep, ch, x, top) + 5
	x += 7
	for ch in "MINE":
		x += letter_mask(mask_mine, ch, x, top) + 5
	# pickaxe accent behind top-right
	var pk = PX.Canvas.new(400, 128)
	for k in 3:
		pk.line(352 + k, 50, 384 + k, 6, K.WOOD[4 - k])
	for i in 30:
		var a := lerpf(-2.5, -0.3, i / 29.0)
		var r := 16.0
		var hx := 386.0 + cos(a) * r
		var hy := 18.0 + sin(a) * r
		pk.fill_rect(int(hx) - 1, int(hy) - 1, 3, 3, K.METAL[5] if i < 15 else K.METAL[4])
		pk.px(int(hx), int(hy) - 1, K.METAL[6])
	pk.circle(386.0, 6.0, 3.0, K.METAL[3])
	c.blit(pk.img, 0, 0)
	var DEEP := K.pal(["e8ffff", "9ef4ff", "5fd0ff", "3f8cff", "2a5ad8", "1e3ea8"])
	var MINE := K.pal(["fff8d0", "ffe27a", "ffc23a", "f8962a", "ee6a1e", "c8461a"])
	var EXT_D := Color.html("0e1d5a")
	var EXT_M := Color.html("5a200c")
	# extrusion
	for dy in range(1, 6):
		for y in 128:
			for xx in 400:
				if y - dy >= 0:
					if mask_deep.get_px(xx, y - dy).a > 0.5 and mask_deep.get_px(xx, y).a < 0.5:
						c.px(xx, y, EXT_D.lightened(0.08 * (5 - dy)))
					elif mask_mine.get_px(xx, y - dy).a > 0.5 and mask_mine.get_px(xx, y).a < 0.5:
						c.px(xx, y, EXT_M.lightened(0.08 * (5 - dy)))
	# faces
	for y in 128:
		for xx in 400:
			var isd: bool = mask_deep.get_px(xx, y).a > 0.5
			var ism: bool = mask_mine.get_px(xx, y).a > 0.5
			if not (isd or ism):
				continue
			var m = mask_deep if isd else mask_mine
			var r: Array[Color] = DEEP if isd else MINE
			var t := clampf(float(y - top) / 52.0, 0.0, 1.0)
			var idx := int(t * 4.99)
			var col: Color = r[clampi(idx, 0, 5)]
			var above: bool = m.get_px(xx, y - 1).a > 0.5
			var above2: bool = m.get_px(xx, y - 2).a > 0.5
			var below: bool = m.get_px(xx, y + 1).a > 0.5
			var left: bool = m.get_px(xx - 1, y).a > 0.5
			if not above or not above2:
				col = r[0]
			elif not below:
				col = r[5].darkened(0.15)
			elif not left:
				col = col.lightened(0.25)
			# diagonal shine band
			var sb := posmod(xx - int(y * 0.7), 46)
			if sb < 3 and t < 0.55:
				col = col.lightened(0.45)
			c.px(xx, y, col)
	# subtitle
	var sub := "UNDERGROUND MINING SIMULATOR"
	var sw := K.text_width(sub, K.F57, 5, 2)
	var sx := (400 - sw) / 2
	var sy := 86
	var subc = PX.Canvas.new(400, 128)
	K.text(subc, sub, sx, sy, Color.WHITE, K.F57, 2)
	for y in range(sy, sy + 14):
		var t2 := float(y - sy) / 13.0
		var col2: Color = MINE[1].lerp(MINE[3], t2)
		for xx in 400:
			if subc.get_px(xx, y).a > 0.5:
				c.px(xx, y, col2 if subc.get_px(xx, y - 1).a > 0.5 else MINE[0])
	# subtitle drop shadow
	for y in range(sy, sy + 14):
		for xx in 400:
			if subc.get_px(xx, y).a > 0.5 and subc.get_px(xx, y + 2).a < 0.5:
				if c.get_px(xx, y + 2).a < 0.5:
					c.px(xx, y + 2, EXT_M)
	# side diamonds
	for dx in [sx - 14, sx + sw + 8]:
		c.polygon(PackedVector2Array([Vector2(dx, sy + 7), Vector2(dx + 4, sy + 2), Vector2(dx + 8, sy + 7), Vector2(dx + 4, sy + 12)]), K.BLUE[4])
		c.px(dx + 4, sy + 4, Color.WHITE)
	c.outline(K.OUT)
	c.outline(K.OUT)
	# sparkles
	K.sparkle(c, 40, 16, Color(0.8, 1.0, 1.0), true)
	K.sparkle(c, 175, 60, Color(0.8, 1.0, 1.0), true)
	K.sparkle(c, 330, 18, Color(1.0, 0.95, 0.7), true)
	return c
