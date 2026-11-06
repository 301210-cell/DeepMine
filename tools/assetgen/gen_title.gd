## Title / loading screen art for DeepMine (original pixel art, 640x360 native):
##   backgrounds/title_bg.png      opaque cave + stone & timber mine entrance, crystals, rails
##   backgrounds/title_plaque.png  title plaque: UNDERGROUND / MINING SIMULATOR + crystal & moss crest
##   backgrounds/title_pickaxe.png one pickaxe (left side; code mirrors it for the right)
##   ui/title_bar_frame.png / ui/title_bar_fill.png / ui/title_btn_*.png  bottom UI pieces
##   backgrounds/title_meta.json   positions for the animated layers (glows, glints, sparkles, pickaxes)
## Run: Godot_console --headless --path tools/assetgen --script res://gen_title.gd
extends SceneTree

const PX = preload("res://px.gd")
const K = preload("res://campkit.gd")
const T = preload("res://tilelib.gd")

const W := 640
const H := 360
const VP := Vector2(320, 262)          # tunnel vanishing point
const PORTAL := Rect2i(262, 200, 116, 112)   # timber portal opening (x, y, w, h)
const FLOOR_Y := 312

var ROCK: Array[Color] = K.pal(["05060f", "0a0c1c", "10142c", "171d3c", "20284e", "2c3664", "3e4a82"])
var FRAME: Array[Color] = K.pal(["020307", "05060e", "090b18", "0f1326", "18203e", "28386a", "4a64a8"])
var BACK: Array[Color] = K.pal(["070818", "0b0d22", "10132e", "161a3a", "1e2248", "282e5a"])
var MSTONE: Array[Color] = K.pal(["15131f", "24202f", "373044", "4b4359", "625874", "807493", "a597b4"])
var MOSS: Array[Color] = K.pal(["0e2414", "18401e", "28642a", "3e8c36", "62b648", "9ee070"])
var GOLDT: Array[Color] = K.pal(["fff6c0", "ffe27a", "ffc838", "ffa424", "f47c1c", "d2561a"])
var BLUET: Array[Color] = K.pal(["eefcff", "a8f0ff", "62d2ff", "3aa2ff", "2a76f0", "1f52c8"])

var meta := {"crystals": [], "glows": [], "sparkle_zones": [], "lanterns": []}

func _init() -> void:
	var bg = make_bg()
	bg.save("backgrounds/title_bg.png")
	var plaque = make_plaque()
	plaque.save("backgrounds/title_plaque.png")
	var pick = make_pickaxe()
	pick.save("backgrounds/title_pickaxe.png")
	make_ui_pieces()
	var f := FileAccess.open(PX.out_root().path_join("backgrounds/title_meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	# composite preview (static)
	var comp := bg.img.duplicate() as Image
	var pp: Array = meta.plaque_pos
	_blit_rot(comp, pick.img, Vector2(meta.pick_left.pivot[0], meta.pick_left.pivot[1]), deg_to_rad(float(meta.pick_left.angle)), false)
	_blit_rot(comp, pick.img, Vector2(meta.pick_right.pivot[0], meta.pick_right.pivot[1]), deg_to_rad(float(meta.pick_right.angle)), true)
	comp.blend_rect(plaque.img, Rect2i(0, 0, plaque.w, plaque.h), Vector2i(int(pp[0]), int(pp[1])))
	var pv := "C:/Users/Jeremy/AppData/Local/Temp/claude/48adf191a57bedc9/aa2076d7-1a4a-41ce-aca4-0aa005bd01b8/scratchpad/shots"
	DirAccess.make_dir_recursive_absolute(pv)
	var big := comp.duplicate() as Image
	big.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	big.save_png(pv.path_join("title_composite.png"))
	quit()

# ============================================================== helpers
func _blit_rot(dst: Image, src: Image, pivot: Vector2, ang: float, mirror: bool) -> void:
	## Preview helper: nearest-neighbour rotate src around its pivot (meta.pickaxe_pivot).
	var pv: Array = meta.pickaxe_pivot
	var sp := Vector2(float(pv[0]), float(pv[1]))
	if mirror:
		sp.x = src.get_width() - 1 - sp.x
	var r := maxi(src.get_width(), src.get_height()) * 2
	for yy in range(-r, r):
		for xx in range(-r, r):
			var d := Vector2(xx, yy).rotated(-ang)
			var sx := int(round(sp.x + d.x))
			var sy := int(round(sp.y + d.y))
			if sx < 0 or sy < 0 or sx >= src.get_width() or sy >= src.get_height():
				continue
			var c := src.get_pixel(src.get_width() - 1 - sx if mirror else sx, sy)
			if c.a < 0.5:
				continue
			var tx := int(pivot.x) + xx
			var ty := int(pivot.y) + yy
			if tx >= 0 and ty >= 0 and tx < dst.get_width() and ty < dst.get_height():
				dst.set_pixel(tx, ty, c)

func rock_shade(x: int, y: int, ramp: Array[Color], base: int, seed: int) -> Color:
	## Chunky cave-rock texture: voronoi-ish plates with lit top-left edges.
	var n := T.fbm(float(x), float(y), 18.0, 640, 360, seed, 3)
	var n2 := PX.vnoise(float(x), float(y), 5.0, seed + 9)
	var i := base + (1 if n > 0.58 else 0) - (1 if n < 0.36 else 0)
	var e := PX.vnoise(float(x) - 1.0, float(y) - 1.0, 5.0, seed + 9)
	if n2 - e > 0.07:
		i += 1
	elif e - n2 > 0.09:
		i -= 1
	return ramp[clampi(i, 0, ramp.size() - 1)]

func big_crystal(c, bx: float, by: float, L: float, Wd: float, ang: float, r: Array[Color], record: bool = true) -> void:
	var u := Vector2(sin(ang), -cos(ang))
	var v := Vector2(cos(ang), sin(ang))
	var base := Vector2(bx, by)
	var sh := L * 0.74
	var hw := Wd * 0.5
	var t1 := -Wd / 6.0
	var t2 := Wd / 6.0
	var P := func(s: float, t: float) -> Vector2: return base + u * s + v * t
	var tip: Vector2 = P.call(L, Wd * 0.04)
	c.polygon(PackedVector2Array([P.call(0, -hw), P.call(sh, -hw), P.call(sh, t1), P.call(0, t1)]), r[4])
	c.polygon(PackedVector2Array([P.call(0, t1), P.call(sh, t1), P.call(sh, t2), P.call(0, t2)]), r[3])
	c.polygon(PackedVector2Array([P.call(0, t2), P.call(sh, t2), P.call(sh, hw), P.call(0, hw)]), r[2])
	c.polygon(PackedVector2Array([P.call(sh, -hw), tip, P.call(sh, t1)]), r[5])
	c.polygon(PackedVector2Array([P.call(sh, t1), tip, P.call(sh, t2)]), r[4])
	c.polygon(PackedVector2Array([P.call(sh, t2), tip, P.call(sh, hw)]), r[3])
	var e1: Vector2 = P.call(0, t1)
	var e2: Vector2 = P.call(sh, t1)
	c.line(int(e1.x), int(e1.y), int(e2.x), int(e2.y), r[5])
	c.line(int(e2.x), int(e2.y), int(tip.x), int(tip.y), r[6])
	var e3: Vector2 = P.call(0, t2)
	var e4: Vector2 = P.call(sh, t2)
	c.line(int(e3.x), int(e3.y), int(e4.x), int(e4.y), r[2].darkened(0.25))
	var s1: Vector2 = P.call(L * 0.1, -hw * 0.6)
	var s2: Vector2 = P.call(L * 0.62, -hw * 0.6)
	c.line(int(s1.x), int(s1.y), int(s2.x), int(s2.y), r[5])
	c.px(int(tip.x), int(tip.y), Color.WHITE)
	if record and L >= 26.0:
		var lit: Vector2 = P.call(L * 0.05, -hw * 0.45)
		var top: Vector2 = P.call(L * 0.86, -hw * 0.2)
		meta.crystals.append({"a": [lit.x, lit.y], "b": [top.x, top.y], "col": r[5].to_html(false), "w": Wd})

func cluster(c, cx: float, cy: float, r: Array[Color], mirror: float, scale: float, spec: Array, glow_r: float = 90.0) -> void:
	K.glow(c, cx + 8.0 * mirror, cy - 50.0 * scale, glow_r * scale, r[4], 0.30)
	for s in spec:
		big_crystal(c, cx + float(s[0]) * mirror * scale, cy + float(s[1]) * scale, float(s[2]) * scale, float(s[3]) * scale, float(s[4]) * mirror, r)
	for i in 10:
		var rx := cx + (PX.hash01(i, int(cx), 41) - 0.5) * 110.0 * scale
		var ry := cy + 4.0 + PX.hash01(i, 1, 41) * 6.0
		T.lump(c, rx, ry, 5.0 * scale + 1.0, 3.5 * scale + 1.0, ROCK.slice(1, 7), ROCK[0], false)
	meta.glows.append([cx + 8.0 * mirror, cy - 45.0 * scale, glow_r * 0.85 * scale, r[4].to_html(false), 0.30, 0])
	meta.sparkle_zones.append([cx - 55.0 * scale, cy - 120.0 * scale, 110.0 * scale, 120.0 * scale, r[5].lightened(0.3).to_html(false), 3.0])

# ============================================================== background
func make_bg():
	var c = PX.Canvas.new(W, H)
	# --- cave interior: back wall with depth gradient
	for y in H:
		for x in W:
			var col := rock_shade(x, y, BACK, 2, 7)
			# brighter, bluer haze toward the centre behind the mine
			var d := Vector2((x - 320.0) / 300.0, (y - 200.0) / 190.0).length()
			var haze := clampf(1.0 - d, 0.0, 1.0)
			col = col.lerp(Color("2a2c64"), haze * 0.35)
			c.px(x, y, col)
	# distant glowing specks in the back wall
	for i in 90:
		var sx := int(PX.hash01(i, 3, 91) * W)
		var sy := int(40 + PX.hash01(i, 4, 91) * 220)
		var blue := PX.hash01(i, 5, 91) > 0.4
		var col2: Color = K.BLUE[4] if blue else K.PURP[4]
		c.px(sx, sy, K.ci(col2, 0.35 + PX.hash01(i, 6, 91) * 0.4))
	# far rock pillars (silhouettes) for depth
	for p in [[150.0, 70.0, 26.0], [492.0, 60.0, 30.0], [205.0, 110.0, 18.0], [440.0, 105.0, 20.0]]:
		var px_: float = p[0]
		for y in range(int(p[1]), FLOOR_Y):
			var wv := float(p[2]) * (0.75 + 0.25 * sin(y * 0.05 + px_)) + (PX.vnoise(px_, float(y), 6.0, 33) - 0.5) * 6.0
			for x in range(int(px_ - wv), int(px_ + wv)):
				c.px(x, y, rock_shade(x, y, BACK, 3 if x < px_ else 1, 35))
	# --- side walls and ceiling (foreground rock frame)
	for y in H:
		for x in W:
			var nx := (x - 320.0) / 300.0
			var ny := (y - 210.0) / 205.0
			var n := (T.fbm(float(x), float(y), 26.0, 640, 360, 51, 3) - 0.5) * 0.36
			var dd := nx * nx * 1.05 + ny * ny * 0.9 + n
			var ceil_y := 26.0 + (PX.vnoise(float(x), 0.0, 22.0, 52) - 0.5) * 30.0 + absf(nx) * 40.0
			var wall := dd > 0.84 or y < ceil_y
			if not wall:
				continue
			var rim := (dd > 0.84 and dd < 0.9) or (y >= ceil_y - 3.0 and y < ceil_y)
			var col := rock_shade(x, y, FRAME, 2, 57)
			if rim:
				col = (FRAME[4] if y < ceil_y + 2.0 else (FRAME[6] if x < 320 else FRAME[5]))
			elif (dd > 0.9 and dd < 0.94):
				col = FRAME[4]
			var edge_dark := clampf((dd - 0.9) * 1.4, 0.0, 0.6)
			col = col.darkened(edge_dark)
			c.px(x, y, col)
	# stalactites
	for i in 30:
		var sx := 20.0 + i * 21.0 + PX.hash01(i, 0, 61) * 10.0
		var top := 30.0 + (PX.vnoise(sx, 0.0, 22.0, 52) - 0.5) * 30.0 + absf((sx - 320.0) / 300.0) * 40.0
		var ln := 8.0 + PX.hash01(i, 1, 61) * 24.0
		var wv := 3.0 + PX.hash01(i, 2, 61) * 4.0
		c.polygon(PackedVector2Array([Vector2(sx - wv, top - 3), Vector2(sx + wv, top - 3), Vector2(sx + 0.5, top + ln)]), ROCK[3])
		c.line(int(sx - wv + 1), int(top - 2), int(sx), int(top + ln - 2), ROCK[5])
		c.px(int(sx), int(top + ln - 1), ROCK[2])
	# wall crystals (mid height, both sides)
	for g in [[34, 196, K.BLUE, 0.55, 0.55], [70, 150, K.BLUE, -0.3, 0.38], [606, 190, K.PURP, -0.5, 0.5], [574, 140, K.BLUE, 0.4, 0.36], [120, 70, K.PURP, 0.8, 0.28], [520, 76, K.BLUE, -0.7, 0.3]]:
		var gr: Array[Color] = g[2]
		var sc: float = g[4]
		K.glow(c, float(g[0]), float(g[1]) - 10.0, 34.0 * sc + 8.0, gr[4], 0.35)
		big_crystal(c, float(g[0]), float(g[1]), 60.0 * sc, 20.0 * sc, float(g[3]), gr, sc > 0.45)
		big_crystal(c, float(g[0]) + 7.0, float(g[1]) + 2.0, 38.0 * sc, 14.0 * sc, float(g[3]) + 0.5, gr, false)
		meta.glows.append([float(g[0]), float(g[1]) - 14.0, 30.0 * sc + 8.0, gr[4].to_html(false), 0.28, 0])
		meta.sparkle_zones.append([float(g[0]) - 12.0, float(g[1]) - 50.0 * sc, 24.0, 50.0 * sc, gr[5].to_html(false), 1.0])
	# --- cave floor
	for y in range(FLOOR_Y - 6, H):
		for x in W:
			var fy := float(FLOOR_Y) - 4.0 + (PX.vnoise(float(x), 0.0, 14.0, 71) - 0.5) * 8.0
			if y < int(fy):
				continue
			var col := rock_shade(x, y, ROCK, 3, 73)
			if y < int(fy) + 2:
				col = ROCK[5]
			col = col.darkened(clampf((y - FLOOR_Y) / 70.0, 0.0, 0.45))
			c.px(x, y, col)
	# --- mine entrance
	mine(c)
	# --- rails out of the tunnel toward the viewer
	rails(c)
	# --- foreground crystal clusters
	var spec_l := [[-30, 0, 70, 24, -0.42], [34, 2, 60, 20, 0.45], [-10, 2, 96, 26, -0.18], [18, 0, 84, 24, 0.2], [0, 4, 128, 32, 0.04], [-46, 6, 40, 16, -0.75], [48, 6, 38, 14, 0.8]]
	cluster(c, 58.0, 352.0, K.BLUE, 1.0, 0.95, spec_l, 100.0)
	cluster(c, 132.0, 350.0, K.PURP, -1.0, 0.45, [[-10, 0, 60, 20, -0.3], [12, 0, 74, 22, 0.25], [0, 2, 46, 16, 0.0]], 70.0)
	cluster(c, 586.0, 352.0, K.BLUE, -1.0, 0.8, spec_l, 90.0)
	cluster(c, 520.0, 350.0, K.PURP, 1.0, 0.5, [[-12, 0, 70, 22, -0.25], [12, 0, 56, 18, 0.3], [0, 2, 40, 14, 0.0]], 70.0)
	# bottom vignette (helps the UI read)
	for y in range(270, H):
		var a := clampf((y - 270.0) / 90.0, 0.0, 1.0)
		a = floor(a * a * 0.55 * 10.0) / 10.0
		for x in W:
			c.blend(x, y, Color(0.02, 0.02, 0.06, a))
	meta["floor_y"] = FLOOR_Y
	return c

func mine(c) -> void:
	var fx0 := 168
	var fx1 := 472
	var fy0 := 166
	# stone facade with irregular rocky top
	for x in range(fx0, fx1):
		var top := fy0 + int((PX.vnoise(float(x), 0.0, 9.0, 81) - 0.5) * 12.0) + int(absf(x - 320.0) / 152.0 * 18.0)
		for y in range(top, FLOOR_Y + 2):
			c.px(x, y, MSTONE[0])
	K.bricks(c, fx0 + 2, fy0 + 4, fx1 - fx0 - 4, FLOOR_Y - fy0 - 2, MSTONE, 12, 7, 83)
	# re-cut the rocky top silhouette over the bricks
	for x in range(fx0, fx1):
		var top := fy0 + int((PX.vnoise(float(x), 0.0, 9.0, 81) - 0.5) * 12.0) + int(absf(x - 320.0) / 152.0 * 18.0)
		for y in range(fy0 - 12, top):
			pass
		c.px(x, top, MSTONE[6])
		c.px(x, top + 1, MSTONE[5])
	# side shading (light from the tunnel): darken the facade edges
	for y in range(fy0 - 10, FLOOR_Y + 2):
		for x in range(fx0, fx1):
			var p: Color = c.get_px(x, y)
			if p.a < 0.5:
				continue
			var k := clampf(absf(x - 320.0) / 160.0, 0.0, 1.0)
			c.px(x, y, p.darkened(k * 0.35))
	# moss on the stones
	for i in 160:
		var mx := fx0 + int(PX.hash01(i, 1, 85) * (fx1 - fx0))
		var my := fy0 + int(pow(PX.hash01(i, 2, 85), 2.2) * 120.0)
		if c.get_px(mx, my).a < 0.5:
			continue
		var mc: Color = MOSS[2 + int(PX.hash01(i, 3, 85) * 3.0)]
		c.px(mx, my, mc)
		c.px(mx + 1, my, MOSS[2])
		if PX.hash01(i, 4, 85) > 0.5:
			c.px(mx, my - 1, MOSS[4])
	# tunnel interior: receding timber frames toward the vanishing point
	var o := PORTAL
	c.fill_rect(o.position.x, o.position.y, o.size.x, o.size.y, Color("080610"))
	var frames := 6
	for f in range(frames, 0, -1):
		var t := float(f) / frames            # 1 = front, small = deep
		var s := pow(t, 1.35)
		var fw := o.size.x * s
		var fh := o.size.y * s
		var cx := lerpf(VP.x, o.position.x + o.size.x * 0.5, t)
		var by := lerpf(VP.y + 6.0, float(o.position.y + o.size.y), t)
		var x0 := cx - fw * 0.5
		var y0 := by - fh
		# inner darkness gradient + warm light near the vanishing point
		var warm := 1.0 - t
		var fill := Color("0a0712").lerp(Color("3a1c10"), warm * 0.9)
		c.fill_rect(int(x0), int(y0), int(fw), int(fh), fill)
		var post := maxi(2, int(7.0 * s))
		var dark := 1.0 - t * 0.85
		var wood: Color = K.WOOD[3].darkened(0.15 + dark * 0.55)
		var wood_hi: Color = K.WOOD[5].darkened(0.1 + dark * 0.55)
		c.fill_rect(int(x0), int(y0), post, int(fh), wood)
		c.fill_rect(int(x0 + fw) - post, int(y0), post, int(fh), wood)
		c.fill_rect(int(x0), int(y0), int(fw), maxi(2, int(8.0 * s)), wood)
		c.fill_rect(int(x0), int(y0), int(fw), 1, wood_hi)
		c.fill_rect(int(x0) + 1, int(y0), 1, int(fh), wood_hi)
		# diagonal braces on the nearer frames
		if t > 0.5:
			c.line(int(x0 + post), int(y0 + 10.0 * s), int(x0 + post + 14.0 * s), int(y0 + 1), wood)
			c.line(int(x0 + fw - post), int(y0 + 10.0 * s), int(x0 + fw - post - 14.0 * s), int(y0 + 1), wood)
	# warm light at the end of the tunnel
	K.glow(c, VP.x, VP.y, 30.0, K.FIRE[5], 0.55)
	K.glow(c, VP.x, VP.y + 4, 14.0, K.FIRE[6], 0.5)
	meta.glows.append([VP.x, VP.y, 46.0, K.FIRE[5].to_html(false), 0.30, 1])
	meta["tunnel_light"] = [VP.x, VP.y]
	# big front timber frame
	K.beam(c, o.position.x - 12, o.position.y - 4, 13, o.size.y + 6, false, 87)
	K.beam(c, o.position.x + o.size.x - 1, o.position.y - 4, 13, o.size.y + 6, false, 88)
	K.beam(c, o.position.x - 22, o.position.y - 16, o.size.x + 44, 14, true, 89)
	K.beam(c, o.position.x - 6, o.position.y - 2, o.size.x + 12, 7, true, 90)
	# corner braces
	for side in [-1, 1]:
		var bx := o.position.x - 1 if side < 0 else o.position.x + o.size.x
		for k in 14:
			var px_: int = bx + side * -k
			c.fill_rect(px_ - 1 if side < 0 else px_, o.position.y + 5 + 14 - k, 3, 3, K.WOOD[3])
		c.line(bx - (0 if side < 0 else 0), o.position.y + 19, bx + side * -14, o.position.y + 5, K.WOOD[5])
	# plank roof over the facade
	K.planks(c, 196, 170, 248, 8, K.WOOD, 5, false, 91, 3)
	c.rect_outline(196, 170, 248, 8, K.WOOD[0])
	# side wall posts and lintels on the facade wings
	for wx in [186, 446]:
		K.beam(c, wx, 176, 8, FLOOR_Y - 176, false, wx)
	# hanging lanterns either side of the portal
	for lx in [236, 404]:
		lantern(c, lx, 214)
		meta.lanterns.append([lx, 226])
		meta.glows.append([lx, 226.0, 30.0, K.FIRE[5].to_html(false), 0.42, 1])
	# small purple crystals on the facade's upper corners (like the reference)
	for g in [[178, 176, 0.4], [462, 176, -0.4]]:
		K.glow(c, float(g[0]), float(g[1]) - 8.0, 16.0, K.PURP[4], 0.4)
		big_crystal(c, float(g[0]), float(g[1]), 26.0, 10.0, float(g[2]), K.PURP)
		big_crystal(c, float(g[0]) + 6.0, float(g[1]) + 1.0, 16.0, 7.0, float(g[2]) + 0.5, K.PURP, false)
		meta.glows.append([float(g[0]), float(g[1]) - 10.0, 18.0, K.PURP[4].to_html(false), 0.35, 0])
		meta.sparkle_zones.append([float(g[0]) - 8.0, float(g[1]) - 24.0, 18.0, 24.0, K.PURP[5].to_html(false), 1.5])
	# lantern light pooling on the stone
	for lx in [236, 404]:
		K.light(c, lx + 0.5, 228.0, 40.0, Color(1.0, 0.6, 0.25), 0.35)
	K.light(c, 320.0, 300.0, 70.0, Color(1.0, 0.55, 0.2), 0.22)

func lantern(c, cx: int, top: int) -> void:
	K.glow(c, cx + 0.5, top + 12.5, 26.0, K.FIRE[5], 0.45)
	c.line(cx, top - 10, cx, top, K.METAL[2])            # chain
	for k in range(top - 10, top, 2):
		c.px(cx, k, K.METAL[4])
	c.fill_rect(cx - 3, top + 1, 7, 2, K.METAL[1])          # cap
	c.fill_rect(cx - 4, top + 3, 9, 2, K.METAL[2])
	c.px(cx, top + 1, K.METAL[4])
	c.fill_rect(cx - 4, top + 5, 9, 12, K.METAL[1])         # cage
	c.fill_rect(cx - 3, top + 5, 7, 12, K.FIRE[4])           # glass
	c.fill_rect(cx - 2, top + 7, 5, 8, K.FIRE[5])
	c.fill_rect(cx - 1, top + 9, 3, 5, K.FIRE[6])            # flame core
	c.px(cx, top + 8, K.FIRE[6])
	c.fill_rect(cx, top + 5, 1, 12, K.METAL[2])              # bars
	c.fill_rect(cx - 4, top + 17, 9, 2, K.METAL[2])          # base
	c.fill_rect(cx - 3, top + 19, 7, 1, K.METAL[1])
	c.px(cx - 3, top + 6, Color(1, 1, 1, 0.8))

func rails(c) -> void:
	var front_y := float(H)
	var back_y := VP.y + 10.0
	# sleepers
	for i in 18:
		var t := pow(float(i) / 17.0, 1.7)
		var y := lerpf(back_y, front_y, t)
		var half := lerpf(5.0, 54.0, t)
		var th := maxi(1, int(lerpf(1.0, 6.0, t)))
		var x0 := int(VP.x - half * 1.25)
		var x1 := int(VP.x + half * 1.25)
		c.fill_rect(x0, int(y), x1 - x0, th, K.WOOD[2])
		c.fill_rect(x0, int(y), x1 - x0, 1, K.WOOD[4])
	# rails
	for side in [-1.0, 1.0]:
		for i in 240:
			var t := float(i) / 239.0
			var y := lerpf(back_y, front_y, t)
			var tt := (y - back_y) / (front_y - back_y)
			var half := lerpf(5.0, 54.0, tt)
			var x: float = VP.x + side * half
			var wv := maxi(1, int(lerpf(1.0, 4.0, tt)))
			for k in wv:
				c.px(int(x) + k * int(side), int(y), K.METAL[5] if k == 0 else K.METAL[2])
			c.px(int(x), int(y) + 1, K.METAL[1])

# ============================================================== plaque + title text
func load_font() -> Dictionary:
	var glyphs := {}
	var fnt := FileAccess.get_file_as_string(PX.out_root().path_join("fonts/pixel_big.fnt"))
	for line in fnt.split("\n"):
		if not line.begins_with("char "):
			continue
		var g := {}
		for part in line.split(" ", false):
			var kv := part.split("=")
			if kv.size() == 2 and kv[1].is_valid_int():
				g[kv[0]] = int(kv[1])
		glyphs[int(g.get("id", 0))] = g
	var page := Image.load_from_file(PX.out_root().path_join("fonts/pixel_big_0.png"))
	page.convert(Image.FORMAT_RGBA8)
	return {"g": glyphs, "page": page}

func text_mask(font: Dictionary, s: String, k: int) -> Image:
	var gl: Dictionary = font.g
	var page: Image = font.page
	var w := 0
	for ch in s:
		var g: Dictionary = gl.get(ch.unicode_at(0), {})
		w += (int(g.get("xadvance", 6)) + 1) * k
	var m := Image.create(w + 2, 16 * k + 2, false, Image.FORMAT_RGBA8)
	m.fill(Color(0, 0, 0, 0))
	var cx := 0
	for ch in s:
		var g: Dictionary = gl.get(ch.unicode_at(0), {})
		if not g.is_empty():
			for gy in int(g.height):
				for gx in int(g.width):
					if page.get_pixel(int(g.x) + gx, int(g.y) + gy).a > 0.5:
						m.fill_rect(Rect2i(cx + (int(g.xoffset) + gx) * k, (int(g.yoffset) + gy) * k, k, k), Color.WHITE)
		cx += (int(g.get("xadvance", 6)) + 1) * k
	return _bolden(m, k - 1)

## Chunkier letters: grow each stroke by `n` px to the right and down (logo weight).
func _bolden(m: Image, n: int) -> Image:
	var o := Image.create(m.get_width() + n, m.get_height() + n, false, Image.FORMAT_RGBA8)
	o.fill(Color(0, 0, 0, 0))
	for y in m.get_height():
		for x in m.get_width():
			if m.get_pixel(x, y).a > 0.5:
				o.fill_rect(Rect2i(x, y, n + 1, n + 1), Color.WHITE)
	return o

func _mask_bounds(m: Image) -> Rect2i:
	var minx := m.get_width()
	var miny := m.get_height()
	var maxx := -1
	var maxy := -1
	for y in m.get_height():
		for x in m.get_width():
			if m.get_pixel(x, y).a > 0.5:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

func draw_title_text(c, m: Image, ox: int, oy: int, ramp: Array[Color], outline_a: Color, outline_b: Color) -> void:
	var b := _mask_bounds(m)
	var on := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height() and m.get_pixel(x, y).a > 0.5
	# drop shadow
	for y in range(-3, m.get_height() + 3):
		for x in range(-3, m.get_width() + 3):
			var near := false
			for oy2 in range(-2, 3):
				for ox2 in range(-2, 3):
					if on.call(x + ox2, y + oy2 - 4):
						near = true
			if near:
				c.blend(ox + x, oy + y, Color(0.0, 0.0, 0.04, 0.55))
	# thick outline (2px: outer darker, inner dark)
	for y in range(-3, m.get_height() + 3):
		for x in range(-3, m.get_width() + 3):
			if on.call(x, y):
				continue
			var d1: bool = on.call(x + 1, y) or on.call(x - 1, y) or on.call(x, y + 1) or on.call(x, y - 1) or on.call(x + 1, y + 1) or on.call(x - 1, y - 1) or on.call(x + 1, y - 1) or on.call(x - 1, y + 1)
			if d1:
				c.px(ox + x, oy + y, outline_a)
				continue
			var d2: bool = on.call(x + 2, y) or on.call(x - 2, y) or on.call(x, y + 2) or on.call(x, y - 2) or on.call(x + 2, y + 1) or on.call(x - 2, y + 1) or on.call(x + 1, y + 2) or on.call(x - 1, y + 2) or on.call(x + 2, y - 1) or on.call(x - 2, y - 1)
			if d2:
				c.px(ox + x, oy + y, outline_b)
	# gradient fill + bevel
	for y in m.get_height():
		for x in m.get_width():
			if not on.call(x, y):
				continue
			var t := float(y - b.position.y) / maxf(1.0, b.size.y - 1)
			var i := clampi(int(t * (ramp.size() - 0.01)), 0, ramp.size() - 1)
			var col: Color = ramp[i]
			if not on.call(x, y - 1):
				col = ramp[0].lerp(Color.WHITE, 0.4)
			elif not on.call(x, y - 2):
				col = ramp[0]
			elif not on.call(x, y + 1):
				col = ramp[ramp.size() - 1].darkened(0.35)
			elif not on.call(x - 1, y):
				col = col.lightened(0.18)
			elif not on.call(x + 1, y):
				col = col.darkened(0.18)
			c.px(ox + x, oy + y, col)
	# glossy highlight stripe across the upper third
	for y in range(b.position.y + int(b.size.y * 0.22), b.position.y + int(b.size.y * 0.30)):
		for x in m.get_width():
			if on.call(x, y) and on.call(x, y - 1) and on.call(x, y + 1):
				c.blend(ox + x, oy + y, Color(1, 1, 1, 0.22))

func make_plaque():
	var font := load_font()
	var l1 := text_mask(font, "UNDERGROUND", 3)
	var l2 := text_mask(font, "MINING SIMULATOR", 2)
	var b1 := _mask_bounds(l1)
	var b2 := _mask_bounds(l2)
	var tw := maxi(b1.size.x, b2.size.x)
	var pw := tw + 52
	var ph := b1.size.y + b2.size.y + 34
	var cw := pw + 20
	var crest_h := 44
	var ch := ph + crest_h + 10
	var c = PX.Canvas.new(cw, ch)
	var px0 := 10
	var py0 := crest_h
	# plaque body: rounded stone rim + dark teal inner panel
	var rim := K.pal(["0c0e1a", "1a1e30", "2a3048", "3e4664", "58628a", "7a86b0", "a4b0d4"])
	for y in range(py0, py0 + ph):
		for x in range(px0, px0 + pw):
			var dx := minf(x - px0, px0 + pw - 1 - x)
			var dy := minf(y - py0, py0 + ph - 1 - y)
			var corner := 9.0
			if dx < corner and dy < corner and Vector2(corner - dx, corner - dy).length() > corner:
				continue
			var edge := minf(dx, dy)
			var col: Color
			if edge < 7.0:
				# chunky stone rim
				var n := PX.vnoise(float(x), float(y), 4.0, 101)
				var ri := 3 + (1 if n > 0.6 else 0) - (1 if n < 0.3 else 0)
				if y - py0 < 3 or x - px0 < 3:
					ri += 1
				if py0 + ph - 1 - y < 3 or px0 + pw - 1 - x < 3:
					ri -= 1
				col = rim[clampi(ri, 0, 6)]
				if edge < 1.0:
					col = rim[0]
			else:
				var t := float(y - py0) / ph
				col = Color("0f2236").lerp(Color("081420"), t)
				var n2 := PX.vnoise(float(x), float(y), 6.0, 103)
				if n2 > 0.72:
					col = col.lightened(0.06)
				if edge < 9.0:
					col = Color("06101a")
			c.px(x, y, col)
	# chunky rocks along the rim (irregular stone frame like the reference)
	var rock_r := K.pal(["0c0e1a", "1c2034", "2c324c", "424a6a", "5e688e", "828eb6", "aab4d8"])
	var perim: Array[Vector2] = []
	var step := 9.0
	var xs := float(px0 + 4)
	while xs < px0 + pw - 4:
		perim.append(Vector2(xs, py0 + 3))
		perim.append(Vector2(xs + 4.0, py0 + ph - 4))
		xs += step
	var ys := float(py0 + 8)
	while ys < py0 + ph - 6:
		perim.append(Vector2(px0 + 3, ys))
		perim.append(Vector2(px0 + pw - 4, ys + 3.0))
		ys += step
	for i in perim.size():
		var p: Vector2 = perim[i]
		var rx := 4.0 + PX.hash01(i, 1, 121) * 3.0
		var ry := 3.5 + PX.hash01(i, 2, 121) * 2.5
		rock(c, p.x + (PX.hash01(i, 3, 121) - 0.5) * 2.0, p.y + (PX.hash01(i, 4, 121) - 0.5) * 2.0, rx, ry, rock_r)
	# rivet-like gem studs on the rim corners
	for p in [Vector2(px0 + 9, py0 + 9), Vector2(px0 + pw - 10, py0 + 9), Vector2(px0 + 9, py0 + ph - 10), Vector2(px0 + pw - 10, py0 + ph - 10)]:
		T.gem(c, p.x, p.y, 3.0, K.pal(["4e2c06", "80520e", "b8821c", "f0b830", "ffd86a", "fff4c4"]), Color("0c0e1a"), "round")
	# title text
	var x1 := px0 + (pw - b1.size.x) / 2 - b1.position.x
	var y1 := py0 + 12 - b1.position.y
	draw_title_text(c, l1, x1, y1, GOLDT, Color("1a0a06"), Color("3a1a0a"))
	var x2 := px0 + (pw - b2.size.x) / 2 - b2.position.x
	var y2 := py0 + 12 + b1.size.y + 8 - b2.position.y
	draw_title_text(c, l2, x2, y2, BLUET, Color("06102a"), Color("0e2248"))
	# moss along the top rim and spilling at the corners
	for x in range(px0 + 4, px0 + pw - 4):
		var mh := int(PX.vnoise(float(x), 0.0, 7.0, 107) * 5.0) - 1
		var near_crest := absf(x - (px0 + pw * 0.5)) < 60.0
		if near_crest:
			mh += 3
		for k in mh:
			c.px(x, py0 + 1 - k, MOSS[clampi(2 + k, 0, 5)])
		if mh > 0 and PX.hash01(x, 3, 109) > 0.86:
			c.px(x, py0 + 2, MOSS[2])
			c.px(x, py0 + 3, MOSS[1])
	# crest: crystal cluster on top centre
	var ccx := px0 + pw * 0.5
	var cby := float(py0) + 4.0
	K.glow(c, ccx, cby - 18.0, 40.0, K.BLUE[4], 0.38)
	var crest := [[-20, 0, 24, 10, -0.55], [20, 0, 22, 10, 0.55], [-9, 0, 34, 12, -0.22], [10, 0, 32, 12, 0.24], [0, 0, 44, 15, 0.0]]
	for s in crest:
		big_crystal(c, ccx + float(s[0]), cby + float(s[1]), float(s[2]), float(s[3]), float(s[4]), K.BLUE, false)
	# small gems in the moss beside the crest
	T.gem(c, ccx - 34, cby - 1, 3.5, K.pal(["3e0a12", "6e121e", "a6202e", "d8384a", "ff6c78", "ffb0b4"]), Color("0c0e1a"), "round")
	T.gem(c, ccx + 36, cby - 1, 3.0, K.pal(["0c2416", "164226", "236a34", "3a9a42", "6ccc5a", "b0f08a"]), Color("0c0e1a"), "hex")
	T.gem(c, ccx - 50, cby + 1, 2.5, K.PURP, Color("0c0e1a"), "diamond")
	T.gem(c, ccx + 52, cby + 1, 2.5, K.BLUE, Color("0c0e1a"), "diamond")
	# moss mound under the crest
	for i in 60:
		var mx := ccx + (PX.hash01(i, 1, 111) - 0.5) * 70.0
		var my := cby + 2.0 - PX.hash01(i, 2, 111) * 5.0
		c.px(int(mx), int(my), MOSS[2 + int(PX.hash01(i, 3, 111) * 4.0)])
	# position on the 640x360 stage
	var stage_x := 320 - cw / 2
	var stage_y := 6
	meta["plaque_pos"] = [stage_x, stage_y]
	meta["plaque_size"] = [cw, ch]
	# crest crystals for glints and sparkles (stage coords)
	for s in crest:
		var a := deg_to_rad(0.0) + float(s[4])
		var base := Vector2(stage_x + ccx + float(s[0]), stage_y + cby + float(s[1]))
		var up := Vector2(sin(a), -cos(a))
		var lv := Vector2(cos(a), sin(a))
		var la := base + lv * (-float(s[3]) * 0.2)
		var lb := base + up * float(s[2]) * 0.85
		meta.crystals.append({"a": [la.x, la.y], "b": [lb.x, lb.y], "col": K.BLUE[5].to_html(false), "w": float(s[3])})
	meta.glows.append([stage_x + ccx, stage_y + cby - 18.0, 34.0, K.BLUE[4].to_html(false), 0.32, 0])
	meta.sparkle_zones.append([stage_x + ccx - 26.0, stage_y + cby - 42.0, 52.0, 42.0, "d8f8ff", 4.0])
	meta.sparkle_zones.append([stage_x + px0 + 20.0, stage_y + py0 + 10.0, pw - 40.0, b1.size.y, "fff1b8", 1.6])
	meta.sparkle_zones.append([stage_x + px0 + 30.0, stage_y + py0 + 20.0 + b1.size.y, pw - 60.0, b2.size.y, "d8f4ff", 1.0])
	# pickaxes: pivots tucked behind the plaque's upper corners, heads poking out above
	meta["pick_left"] = {"pivot": [stage_x + px0 + 24, stage_y + py0 + 60], "angle": 0.0}
	meta["pick_right"] = {"pivot": [stage_x + px0 + pw - 24, stage_y + py0 + 60], "angle": 0.0}
	return c

# ============================================================== pickaxe
func make_pickaxe():
	## Large pickaxe drawn with solid filled polygons (no gaps). Head at the upper-left, handle
	## running down-right to the grip end, which is the rotation pivot (meta.pickaxe_pivot).
	var S := 112
	var c = PX.Canvas.new(S, S)
	var hand := K.pal(["2a1408", "4a260e", "6e3c18", "945626", "bc7a3a", "dca060", "f2c88a"])
	var a := Vector2(38, 38)           # top of the handle (inside the head socket)
	var b := Vector2(104, 104)         # grip end
	var dirv := (b - a).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)  # points down-left (shadow side)
	# handle body
	var hw := 2.6
	c.polygon(PackedVector2Array([a - nrm * hw, b - nrm * hw, b + nrm * hw, a + nrm * hw]), hand[3])
	# light on the upper-right side, shadow on the lower-left side
	for k in [[-2.0, hand[5]], [-1.0, hand[4]], [1.0, hand[2]], [2.0, hand[1]]]:
		var o: Vector2 = nrm * float(k[0])
		c.line(int(round(a.x + o.x)), int(round(a.y + o.y)), int(round(b.x + o.x)), int(round(b.y + o.y)), k[1])
	# wood grain flecks
	for i in 14:
		var t := 0.08 + PX.hash01(i, 1, 141) * 0.55
		var p := a + (b - a) * t + nrm * (PX.hash01(i, 2, 141) - 0.5) * 2.0
		c.px(int(round(p.x)), int(round(p.y)), hand[2])
	# leather grip with wrap bands
	var g0 := a + (b - a) * 0.66
	var g1 := a + (b - a) * 0.97
	var gw := 3.2
	c.polygon(PackedVector2Array([g0 - nrm * gw, g1 - nrm * gw, g1 + nrm * gw, g0 + nrm * gw]), Color("7a3222"))
	c.line(int(round(g0.x - nrm.x * 2.0)), int(round(g0.y - nrm.y * 2.0)), int(round(g1.x - nrm.x * 2.0)), int(round(g1.y - nrm.y * 2.0)), Color("b05a3c"))
	c.line(int(round(g0.x + nrm.x * 2.4)), int(round(g0.y + nrm.y * 2.4)), int(round(g1.x + nrm.x * 2.4)), int(round(g1.y + nrm.y * 2.4)), Color("4a1a12"))
	for i in 7:
		var t2 := float(i) / 6.0
		var p2 := g0.lerp(g1, t2)
		var q1 := p2 - nrm * gw + dirv * 1.5
		var q2 := p2 + nrm * gw - dirv * 1.5
		c.line(int(round(q1.x)), int(round(q1.y)), int(round(q2.x)), int(round(q2.y)), Color("d07a52"))
	# pommel
	c.circle(b.x - 0.5, b.y - 0.5, 3.6, K.METAL[3])
	c.px(int(b.x) - 2, int(b.y) - 3, K.METAL[5])
	# curved steel blade, perpendicular to the handle, convex side away from it
	var steel := K.pal(["10141f", "232a3e", "3a4560", "566484", "7e8eb0", "aebcd8", "e4ecfa"])
	var along := Vector2(1, -1).normalized()
	var outv := Vector2(-1, -1).normalized()
	var centre := a + outv * 3.0
	var L := 38.0
	var top_pts := PackedVector2Array()
	var bot_pts := PackedVector2Array()
	var mid_pts: Array[Vector2] = []
	var steps := 32
	for i in steps + 1:
		var s := lerpf(-1.0, 1.0, float(i) / steps)
		var bend := (1.0 - s * s) * 9.0
		var p := centre + along * (s * L) + outv * bend
		var th := lerpf(6.0, 0.6, pow(absf(s), 1.5))
		top_pts.append(p + outv * th)
		bot_pts.append(p - outv * th * 0.8)
		mid_pts.append(p)
	var poly := PackedVector2Array()
	poly.append_array(top_pts)
	var rb := bot_pts.duplicate()
	rb.reverse()
	poly.append_array(rb)
	c.polygon(poly, steel[3])
	# shading bands: bright top edge, darker underside
	for i in steps:
		var u0: Vector2 = top_pts[i]
		var u1: Vector2 = top_pts[i + 1]
		c.line(int(round(u0.x)), int(round(u0.y)), int(round(u1.x)), int(round(u1.y)), steel[5])
		var v0: Vector2 = bot_pts[i]
		var v1: Vector2 = bot_pts[i + 1]
		c.line(int(round(v0.x)), int(round(v0.y)), int(round(v1.x)), int(round(v1.y)), steel[1])
		var m0: Vector2 = (mid_pts[i] + top_pts[i]) * 0.5
		var m1: Vector2 = (mid_pts[i + 1] + top_pts[i + 1]) * 0.5
		c.line(int(round(m0.x)), int(round(m0.y)), int(round(m1.x)), int(round(m1.y)), steel[4])
	# polished edge glints near both points
	for i in [3, 4, 5, steps - 5, steps - 4, steps - 3]:
		var tp: Vector2 = top_pts[i]
		c.px(int(round(tp.x)), int(round(tp.y)), steel[6])
	c.outline(steel[0])
	# socket collar (rotated square) with rivets
	var cs := 6.0
	var collar := PackedVector2Array([a + along * cs, a + outv * cs * 0.9, a - along * cs, a - outv * cs * 0.9])
	c.polygon(collar, steel[2])
	c.line(int(round((a + outv * cs * 0.9).x)), int(round((a + outv * cs * 0.9).y)), int(round((a + along * cs).x)), int(round((a + along * cs).y)), steel[5])
	c.px(int(a.x) - 2, int(a.y) + 1, steel[6])
	c.px(int(a.x) + 1, int(a.y) - 2, steel[6])
	var tip_a := centre + along * L
	var tip_b := centre - along * L
	meta["pickaxe_pivot"] = [int(b.x) - 2, int(b.y) - 2]
	meta["pickaxe_tips"] = [[tip_a.x + outv.x * 2.0, tip_a.y + outv.y * 2.0], [tip_b.x + outv.x * 2.0, tip_b.y + outv.y * 2.0]]
	return c

func rock(c, cx: float, cy: float, rx: float, ry: float, r: Array[Color]) -> void:
	## Small shaded stone with a dark outline (lit from the top-left).
	var x0 := int(floor(cx - rx - 1))
	var x1 := int(ceil(cx + rx + 1))
	var y0 := int(floor(cy - ry - 1))
	var y1 := int(ceil(cy + ry + 1))
	var inside := func(xx: int, yy: int) -> bool:
		var nx := (xx + 0.5 - cx) / rx
		var ny := (yy + 0.5 - cy) / ry
		return nx * nx + ny * ny <= 1.0
	for yy in range(y0 - 1, y1 + 2):
		for xx in range(x0 - 1, x1 + 2):
			if inside.call(xx, yy):
				var nx := (xx + 0.5 - cx) / rx
				var ny := (yy + 0.5 - cy) / ry
				var l := -nx * 0.6 - ny * 0.8
				var i := clampi(int(3.0 + l * 2.2 + 0.5), 1, r.size() - 1)
				c.px(xx, yy, r[i])
			elif inside.call(xx + 1, yy) or inside.call(xx - 1, yy) or inside.call(xx, yy + 1) or inside.call(xx, yy - 1):
				c.px(xx, yy, r[0])

# ============================================================== UI pieces (bar + buttons)
func make_ui_pieces() -> void:
	# loading bar frame 48x16, 9-slice margins 6
	var f = PX.Canvas.new(48, 16)
	_rounded(f, 0, 0, 48, 16, 4, Color("070912"))
	_rounded(f, 1, 1, 46, 14, 3, Color("4a4f6a"))
	_rounded(f, 2, 2, 44, 12, 3, Color("1a1d2e"))
	_rounded(f, 3, 3, 42, 10, 2, Color("0a0c16"))
	f.fill_rect(4, 2, 40, 1, Color("8a90b0"))
	f.save("ui/title_bar_frame.png")
	# gold fill 24x10, margins 4
	var g = PX.Canvas.new(24, 10)
	var gr := K.pal(["b4560e", "e4861a", "f8b02c", "ffd456", "fff0a8"])
	for y in 10:
		var col: Color = gr[3] if y < 2 else (gr[2] if y < 5 else (gr[1] if y < 8 else gr[0]))
		for x in 24:
			g.px(x, y, col)
	g.fill_rect(0, 1, 24, 1, gr[4])
	_round_alpha(g, 2)
	g.save("ui/title_bar_fill.png")
	# buttons 48x22, margins 8: dark stone with gold trim (primary) or steel trim
	for kind in ["gold", "steel"]:
		for state in ["normal", "hover", "pressed"]:
			var b = PX.Canvas.new(48, 22)
			var trim: Color = Color("e0a83a") if kind == "gold" else Color("7c86a8")
			var trim_hi: Color = Color("fff0a0") if kind == "gold" else Color("c8d2ea")
			var body := Color("141a30") if state == "normal" else (Color("1e2848") if state == "hover" else Color("0c1022"))
			var body_hi := body.lightened(0.12)
			var oy := 1 if state == "pressed" else 0
			_rounded(b, 0, 0, 48, 22, 4, Color("05060c"))
			_rounded(b, 1, 1 + oy, 46, 20 - oy, 3, trim)
			_rounded(b, 2, 2 + oy, 44, 18 - oy, 3, body)
			b.fill_rect(4, 2 + oy, 40, 1, trim_hi)
			b.fill_rect(3, 3 + oy, 42, 6, body_hi)
			if state == "hover":
				b.fill_rect(4, 1, 40, 1, Color(1, 1, 1, 0.9))
			b.save("ui/title_btn_%s_%s.png" % [kind, state])

func _rounded(c, x: int, y: int, w: int, h: int, r: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var dx := mini(xx - x, x + w - 1 - xx)
			var dy := mini(yy - y, y + h - 1 - yy)
			if dx < r and dy < r and Vector2(r - dx - 0.5, r - dy - 0.5).length() > r:
				continue
			c.px(xx, yy, col)

func _round_alpha(c, r: int) -> void:
	for yy in c.h:
		for xx in c.w:
			var dx := mini(xx, c.w - 1 - xx)
			var dy := mini(yy, c.h - 1 - yy)
			if dx < r and dy < r and Vector2(r - dx - 0.5, r - dy - 0.5).length() > r:
				c.px(xx, yy, Color(0, 0, 0, 0))
