## Generates skill_icons.png (40), event_icons.png (8 x 32px) and ui/ui_icons.png (54)
extends SceneTree
const PX = preload("res://px.gd")
const L = preload("res://chlib.gd")
const I = preload("res://ch_iconlib.gd")

func R(n: String) -> Array:
	return I.R(n)

func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

# ============================================================ glyph helpers
## Recolour an icon to the white glyph ramp by normalised luminance (outline kept).
func whiten(cv: PX.Canvas) -> PX.Canvas:
	var w := I.W()
	var lo := 1.0
	var hi := 0.0
	for y in cv.h:
		for x in cv.w:
			var p := cv.get_px(x, y)
			if p.a < 0.5 or p.is_equal_approx(L.OUTLINE):
				continue
			var l := p.get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	for y in cv.h:
		for x in cv.w:
			var p := cv.get_px(x, y)
			if p.a < 0.5 or p.is_equal_approx(L.OUTLINE):
				continue
			if p.a < 0.95:
				cv.img.set_pixel(x, y, Color(1, 1, 1, p.a * 0.6))
				continue
			var t := (p.get_luminance() - lo) / maxf(hi - lo, 0.001)
			var idx := 1
			if t > 0.75:
				idx = 3
			elif t > 0.35:
				idx = 2
			cv.img.set_pixel(x, y, w[idx])
	return cv

func crown_badge(cv: PX.Canvas, x: int, y: int) -> void:
	var b := PX.Canvas.new(cv.w, cv.h)
	var g := R("gold")
	b.polygon(PackedVector2Array([V(x, y + 1), V(x + 2, y + 3), V(x + 3.5, y), V(x + 5, y + 3), V(x + 7, y + 1), V(x + 6.5, y + 5), V(x + 0.5, y + 5)]), g[2])
	L.autoshade(b, [g])
	b.px(x + 3, y + 4, R("ruby")[3])
	b.outline(L.OUTLINE)
	cv.blit(b.img, 0, 0)

func plus_badge(cv: PX.Canvas, x: int, y: int, col: Color = Color("4fdc6a")) -> void:
	var b := PX.Canvas.new(cv.w, cv.h)
	b.fill_rect(x + 1, y, 1, 3, col)
	b.fill_rect(x, y + 1, 3, 1, col)
	b.outline(L.OUTLINE)
	b.outline(L.OUTLINE)
	cv.blit(b.img, 0, 0)

func arrow_up(cv: PX.Canvas, x: int, y: int, col: Color) -> void:
	var b := PX.Canvas.new(cv.w, cv.h)
	b.polygon(PackedVector2Array([V(x + 2.5, y), V(x + 5.5, y + 3), V(x + 3.5, y + 3), V(x + 3.5, y + 6), V(x + 1.5, y + 6), V(x + 1.5, y + 3), V(x - 0.5, y + 3)]), col)
	b.outline(L.OUTLINE)
	cv.blit(b.img, 0, 0)

func motion_lines(cv: PX.Canvas, col: Color) -> void:
	for i in 3:
		cv.line(1, 9 + i * 2, 3 + i, 9 + i * 2, col)

func shape(fn: Callable) -> PX.Canvas:
	var cv := I.icon()
	fn.call(cv)
	return cv

## Simple white shape: draw with W mid then shade + outline.
func wshape(draw: Callable, sz: int = 16) -> PX.Canvas:
	var cv := I.icon(sz)
	draw.call(cv, I.W()[2])
	L.autoshade(cv, [I.W()], 2)
	cv.outline(L.OUTLINE)
	return cv

# ============================================================ basic shapes (any colour)
func d_boot(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(5, 2, 5, 8, c)
	cv.fill_rect(5, 9, 9, 4, c)
	cv.px(13, 9, Color(0, 0, 0, 0))
	cv.fill_rect(5, 13, 9, 1, c.darkened(0.4))

func d_backpack(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(3, 4, 10, 11, c)
	cv.fill_rect(4, 3, 8, 1, c)
	cv.fill_rect(5, 1, 6, 2, c)
	cv.px(6, 1, Color(0, 0, 0, 0))
	cv.px(9, 1, Color(0, 0, 0, 0))

func d_lantern(cv: PX.Canvas, c: Color) -> void:
	cv.line(6, 1, 9, 1, c)
	cv.fill_rect(4, 3, 8, 2, c)
	cv.fill_rect(5, 5, 6, 7, c)
	cv.fill_rect(4, 12, 8, 2, c)

func d_gear(cv: PX.Canvas, c: Color, cx: float = 8, cy: float = 8, r: float = 5.0) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		L.disc(cv, cx + cos(a) * (r + 1.0), cy + sin(a) * (r + 1.0), 1.4, c)
	cv.circle(cx, cy, r, c)

func gear_hole(cv: PX.Canvas, cx: float = 8, cy: float = 8, r: float = 1.8) -> void:
	for y in cv.h:
		for x in cv.w:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				cv.px(x, y, Color(0, 0, 0, 0))

func d_chest(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(2, 7, 12, 7, c)
	cv.fill_rect(2, 4, 12, 3, c)
	cv.fill_rect(3, 3, 10, 1, c)

func d_eye(cv: PX.Canvas, c: Color) -> void:
	cv.ellipse(8, 8, 7, 4.2, c)

func d_furnace(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(2, 5, 12, 10, c)
	cv.fill_rect(10, 1, 3, 4, c)

func d_shield(cv: PX.Canvas, c: Color) -> void:
	cv.polygon(PackedVector2Array([V(2, 2), V(14, 2), V(14, 8), V(8, 15), V(2, 8)]), c)

func d_magnet(cv: PX.Canvas, c: Color) -> void:
	for y in 16:
		for x in 16:
			var dx := x + 0.5 - 8.0
			var dy := y + 0.5 - 7.0
			var d := sqrt(dx * dx + dy * dy)
			if dy >= 0 and d <= 6.5 and d >= 2.5:
				cv.px(x, y, c)
	cv.fill_rect(1, 2, 4, 5, c)
	cv.fill_rect(11, 2, 4, 5, c)

func d_feather(cv: PX.Canvas, c: Color) -> void:
	cv.polygon(PackedVector2Array([V(13, 1), V(14, 4), V(10, 10), V(5, 13), V(4, 11), V(7, 6)]), c)
	cv.line(3, 14, 11, 5, c.darkened(0.45))

func d_compass(cv: PX.Canvas, c: Color) -> void:
	cv.circle(8, 8.5, 6.5, c)

func d_drillbit(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(5, 1, 6, 4, c)
	cv.polygon(PackedVector2Array([V(4, 5), V(12, 5), V(8, 15)]), c)

func d_weight(cv: PX.Canvas, c: Color) -> void:
	cv.polygon(PackedVector2Array([V(4, 5), V(12, 5), V(14, 14), V(2, 14)]), c)
	cv.circle(8, 3.5, 2.5, c)

func d_ladder(cv: PX.Canvas, c: Color) -> void:
	cv.fill_rect(3, 1, 2, 15, c)
	cv.fill_rect(11, 1, 2, 15, c)
	for y in [3, 7, 11]:
		cv.fill_rect(5, y, 6, 2, c)

func d_map(cv: PX.Canvas, c: Color) -> void:
	cv.polygon(PackedVector2Array([V(1, 3), V(5, 2), V(10, 4), V(15, 2), V(15, 13), V(10, 15), V(5, 13), V(1, 15)]), c)

func d_hex(cv: PX.Canvas, c: Color, filled: bool) -> void:
	var pts := I.ngon(8, 8, 7.0, 6, -PI / 2.0)
	cv.polygon(pts, c)
	if not filled:
		var inner := I.ngon(8, 8, 4.4, 6, -PI / 2.0)
		var tmp := PX.Canvas.new(16, 16)
		tmp.polygon(inner, Color.WHITE)
		for y in 16:
			for x in 16:
				if tmp.get_px(x, y).a > 0.5:
					cv.px(x, y, Color(0, 0, 0, 0))

# ============================================================ skill icons
func skill_icon(i: int) -> PX.Canvas:
	var W: Array = I.W()
	var cv: PX.Canvas
	match i:
		0:
			cv = wshape(func(c, col):
				for y in range(3, 11):
					for x in range(1, 16):
						var nx := (x + 0.5 - 8.0) / 6.8
						var ny := (y + 0.5 - 10.5) / 7.5
						if nx * nx + ny * ny <= 1.0:
							c.px(x, y, col)
				c.fill_rect(0, 10, 16, 2, col))
			cv.fill_rect(6, 4, 4, 4, R("gold")[2])
			cv.px(7, 5, Color.WHITE)
			cv.px(6, 4, R("gold")[3])
			L.glow(cv, Color(1, 0.9, 0.4, 0.5), 1)
		1:
			cv = whiten(I.pickaxe16(R("steel"), R("wood")))
			for p in [Vector2i(13, 1), Vector2i(15, 3), Vector2i(14, 0), Vector2i(15, 1)]:
				cv.px(p.x, p.y, L.c("ff8a2a"))
			cv.line(12, 11, 14, 13, L.c("ff8a2a"))
			cv.line(14, 9, 15, 10, L.c("ffc93c"))
		2:
			cv = whiten(I.pickaxe16(R("steel"), R("wood")))
			motion_lines(cv, L.c("5ff2ff"))
		3:
			cv = whiten(I.ore_lump(R("rock"), 3))
			plus_badge(cv, 12, 11)
		4:
			cv = I.icon()
			I.nugget(cv, 2, 9, R("copper"), true)
			I.nugget(cv, 7, 5, R("silver"), true)
			I.nugget(cv, 11, 10, R("rust"), true)
			cv.outline(L.OUTLINE)
			var base := wshape(func(c, col): c.fill_rect(1, 13, 14, 2, col))
			base.blit(cv.img, 0, 0)
			cv = base
		5:
			cv = whiten(I.geode(R("rock"), R("amethyst"), 3))
			for y in range(4, 13):
				for x in range(5, 12):
					var p := cv.get_px(x, y)
					if p.a > 0.5 and not p.is_equal_approx(L.OUTLINE):
						var dx := x + 0.5 - 8.2
						var dy := y + 0.5 - 8.6
						if dx * dx + dy * dy < 14.0:
							cv.px(x, y, R("amethyst")[3] if (x + y) % 2 == 0 else R("amethyst")[2])
		6: cv = whiten(_ammonite())
		7:
			cv = I.icon()
			var pts := PackedVector2Array()
			for k in 16:
				var a := -PI / 2.0 + k * TAU / 16.0
				var r := 7.2 if k % 2 == 0 else 3.4
				pts.append(V(8 + cos(a) * r, 8 + sin(a) * r))
			cv.polygon(pts, L.c("ffc93c"))
			L.autoshade(cv, [R("gold")], 2)
			cv.fill_rect(7, 4, 2, 5, Color.WHITE)
			cv.fill_rect(7, 10, 2, 2, Color.WHITE)
			cv.outline(L.OUTLINE)
		8:
			cv = I.icon()
			var g := R("green")
			for o in [V(5, 5), V(11, 5), V(5, 10), V(11, 10)]:
				cv.circle(o.x, o.y, 3.2, g[2])
			L.autoshade(cv, [g], 2)
			cv.line(8, 8, 9, 15, g[1])
			cv.outline(L.OUTLINE)
			var gem := I.gem_cut(R("diamond"), "round")
			var sm := gem.img.duplicate() as Image
			sm.resize(7, 7, Image.INTERPOLATE_NEAREST)
			cv.blit(sm, 5, 5)
			I.star4(cv, 14, 1, Color.WHITE)
		9:
			cv = wshape(func(c, col):
				for k in 2:
					var ox := 1 + k * 6
					c.polygon(PackedVector2Array([V(ox, 2), V(ox + 4, 2), V(ox + 9, 8), V(ox + 4, 14), V(ox, 14), V(ox + 5, 8)]), col))
			for y in 16:
				for x in range(9, 16):
					var p := cv.get_px(x, y)
					if p.a > 0.5 and not p.is_equal_approx(L.OUTLINE):
						cv.px(x, y, L.c("ff8a2a") if p.get_luminance() > 0.7 else L.c("d85a18"))
		10:
			cv = whiten(I.ore_lump(R("rock"), 10))
			cv.line(5, 4, 8, 8, L.OUTLINE)
			cv.line(8, 8, 7, 12, L.OUTLINE)
			cv.line(8, 8, 11, 9, L.OUTLINE)
			cv.px(13, 2, L.c("ff8a2a"))
			cv.px(14, 3, L.c("ffc93c"))
		11:
			cv = whiten(I.pickaxe16(R("steel"), R("wood")))
			crown_badge(cv, 0, 1)
		12:
			cv = wshape(func(c, col): d_boot(c, col))
			for k in 3:
				cv.line(0, 5 + k * 3, 3 - (k % 2), 5 + k * 3, L.c("4fdc6a"))
		13:
			cv = wshape(func(c, col):
				c.fill_rect(1, 7, 4, 5, col)
				c.fill_rect(1, 11, 7, 3, col))
			arrow_up(cv, 9, 1, L.c("4fdc6a"))
			cv.line(10, 9, 10, 14, L.c("4fdc6a"))
			cv.line(12, 9, 12, 14, L.c("4fdc6a"))
		14: cv = wshape(func(c, col): d_feather(c, col))
		15:
			cv = wshape(func(c, col): d_lantern(c, col))
			cv.fill_rect(7, 6, 2, 5, L.c("ffc93c"))
			cv.px(7, 7, Color.WHITE)
			for p in [Vector2i(1, 8), Vector2i(14, 8), Vector2i(2, 3), Vector2i(13, 3), Vector2i(1, 13), Vector2i(14, 13)]:
				cv.px(p.x, p.y, L.c("ffe680"))
		16:
			cv = wshape(func(c, col): d_ladder(c, col))
			cv.line(1, 0, 14, 15, L.c("c8a060"))
		17:
			cv = wshape(func(c, col): d_eye(c, col))
			cv.circle(8, 8, 2.6, R("cyan")[2])
			cv.circle(8, 8, 1.2, L.c("0a1a2a"))
			cv.px(7, 7, Color.WHITE)
			I.star4(cv, 14, 2, R("cyan")[4])
		18:
			cv = wshape(func(c, col): c.fill_rect(1, 2, 14, 13, col))
			for y in [5, 9, 13]:
				cv.line(1, y, 14, y, I.W()[0])
			for y in [2, 6, 10]:
				for x in [4, 10]:
					cv.line(x + (y % 8) / 2, y, x + (y % 8) / 2, y + 2, I.W()[0])
			cv.fill_rect(6, 6, 4, 9, L.c("1b1424"))
			cv.px(8, 10, L.c("4fdc6a"))
			cv.line(9, 2, 7, 6, L.c("4fdc6a"))
		19:
			cv = wshape(func(c, col): d_chest(c, col))
			cv.fill_rect(2, 7, 12, 1, I.W()[0])
			cv.fill_rect(7, 6, 2, 3, R("gold")[2])
			I.big_star(cv, 13, 2, L.c("ffc93c"))
		20:
			cv = wshape(func(c, col): d_map(c, col))
			cv.line(5, 2, 5, 13, I.W()[1])
			cv.line(10, 4, 10, 15, I.W()[1])
			cv.line(11, 6, 13, 8, L.c("ff5a4a"))
			cv.line(13, 6, 11, 8, L.c("ff5a4a"))
			cv.px(3, 11, L.c("4fdc6a"))
			cv.px(4, 10, L.c("4fdc6a"))
			cv.px(6, 9, L.c("4fdc6a"))
			cv.px(8, 8, L.c("4fdc6a"))
		21:
			cv = wshape(func(c, col): d_compass(c, col))
			cv.circle(8, 8.5, 4.2, I.W()[1])
			cv.polygon(PackedVector2Array([V(8, 4), V(9.5, 8.5), V(6.5, 8.5)]), L.c("ff5a4a"))
			cv.polygon(PackedVector2Array([V(8, 13), V(9.5, 8.5), V(6.5, 8.5)]), I.W()[3])
			crown_badge(cv, 9, 0)
		22:
			cv = wshape(func(c, col): d_backpack(c, col))
			cv.fill_rect(3, 6, 10, 1, I.W()[1])
			cv.fill_rect(5, 9, 6, 4, I.W()[1])
			plus_badge(cv, 12, 11)
		23:
			cv = wshape(func(c, col):
				c.fill_rect(1, 8, 7, 7, col)
				c.fill_rect(8, 8, 7, 7, col)
				c.fill_rect(4, 1, 8, 7, col))
			cv.line(1, 8, 14, 8, I.W()[0])
			cv.line(8, 8, 8, 14, I.W()[0])
			cv.px(8, 4, L.c("3f8dff"))
			cv.px(4, 11, L.c("3f8dff"))
			cv.px(11, 11, L.c("3f8dff"))
		24:
			cv = whiten(I.pickaxe16(R("steel"), R("wood")))
			var wr := wshape(func(c, col):
				L.thick(c, [V(2.5, 2.5), V(13.5, 13.5)], 1.0, col)
				c.circle(3, 3, 2.6, col))
			wr.px(2, 2, Color(0, 0, 0, 0))
			wr.px(3, 2, Color(0, 0, 0, 0))
			cv.blit(wr.img, 0, 0)
			cv.px(13, 13, L.c("3f8dff"))
		25:
			cv = wshape(func(c, col): d_shield(c, col))
			var f := R("flame")
			cv.ellipse(8, 8.5, 2.8, 3.8, f[2])
			cv.px(8, 9, f[4])
			cv.px(8, 4, f[3])
		26:
			cv = wshape(func(c, col): d_magnet(c, col))
			cv.fill_rect(1, 2, 4, 5, R("red")[2])
			cv.fill_rect(11, 2, 4, 5, R("red")[2])
			cv.fill_rect(1, 2, 4, 1, R("red")[3])
			cv.fill_rect(11, 2, 4, 1, R("red")[3])
			for p in [Vector2i(3, 0), Vector2i(13, 0)]:
				cv.px(p.x, p.y, L.c("5ff2ff"))
		27:
			cv = wshape(func(c, col): d_weight(c, col))
			cv.circle(8, 3.5, 1.0, Color(0, 0, 0, 0))
			cv.line(5, 9, 6, 12, L.c("3f8dff"))
			cv.line(5, 10, 7, 9, L.c("3f8dff"))
			cv.line(7, 12, 6, 10, L.c("3f8dff"))
			cv.line(9, 9, 11, 9, L.c("3f8dff"))
			cv.line(9, 9, 9, 12, L.c("3f8dff"))
			cv.line(9, 12, 11, 12, L.c("3f8dff"))
			cv.px(11, 11, L.c("3f8dff"))
		28:
			cv = I.icon()
			var cols := [R("copper"), R("silver"), R("gold"), R("sapphire")]
			for k in 4:
				var bx := 1 + (k % 2) * 7
				var by := 1 + (k / 2) * 7
				var c4: Array = cols[k]
				cv.fill_rect(bx, by, 6, 6, I.W()[2])
				cv.fill_rect(bx + 1, by + 1, 4, 4, c4[2])
				cv.px(bx + 1, by + 1, c4[3])
			cv.outline(L.OUTLINE)
		29:
			cv = wshape(func(c, col):
				d_backpack(c, col)
				c.fill_rect(1, 1, 14, 3, col))
			cv.fill_rect(1, 1, 14, 3, R("red")[2])
			cv.fill_rect(1, 1, 14, 1, R("red")[3])
			cv.line(4, 1, 4, 3, R("red")[0])
			cv.line(11, 1, 11, 3, R("red")[0])
			cv.fill_rect(5, 8, 6, 4, I.W()[1])
		30:
			cv = wshape(func(c, col): d_backpack(c, col))
			cv.fill_rect(5, 8, 6, 4, I.W()[1])
			crown_badge(cv, 4, 0)
		31:
			cv = wshape(func(c, col): d_furnace(c, col))
			cv.fill_rect(5, 9, 6, 5, L.c("3a1208"))
			cv.fill_rect(6, 10, 4, 4, R("flame")[2])
			cv.px(7, 11, R("flame")[4])
			cv.line(0, 6, 1, 6, L.c("a65cff"))
			cv.line(0, 9, 2, 9, L.c("a65cff"))
		32:
			cv = whiten(I.ingot(R("gold")))
			plus_badge(cv, 12, 1)
		33:
			cv = I.gem_cut(L.r5("2a0c5a", "5a2aa8", "a65cff", "d6b0ff", "ffffff"), "round")
			cv.line(11, 1, 15, 5, L.c("a65cff"))
			cv.line(10, 2, 14, 6, L.c("d6b0ff"))
		34:
			cv = wshape(func(c, col):
				c.fill_rect(2, 2, 9, 4, col)
				c.fill_rect(5, 6, 3, 8, col))
			cv.fill_rect(10, 11, 3, 3, R("rock")[2])
			cv.px(13, 9, R("rock")[3])
			cv.px(14, 12, R("rock")[2])
			cv.px(11, 9, L.c("ffc93c"))
		35: cv = wshape(func(c, col): d_drillbit(c, col))
		36:
			cv = wshape(func(c, col): d_gear(c, col, 7, 9, 4.6))
			gear_hole(cv, 7, 9, 1.8)
			arrow_up(cv, 10, 0, L.c("4fdc6a"))
		37:
			cv = whiten(I.vial(R("shard")))
			for y in range(9, 15):
				for x in range(4, 13):
					var p := cv.get_px(x, y)
					if p.a > 0.9 and not p.is_equal_approx(L.OUTLINE) and y > 9:
						cv.px(x, y, R("purple")[2] if (x + y) % 3 else R("purple")[3])
		38:
			cv = wshape(func(c, col): d_drillbit(c, col))
			cv.fill_rect(1, 13, 14, 1, L.c("ff8a2a"))
			cv.fill_rect(1, 14, 14, 2, L.c("d85a18"))
		39:
			cv = wshape(func(c, col): d_gear(c, col, 8, 9.5, 4.6))
			gear_hole(cv, 8, 9.5, 1.8)
			crown_badge(cv, 4, 0)
	return cv

func _ammonite() -> PX.Canvas:
	var cv := I.icon()
	var b := R("bronze")
	cv.circle(8, 8.5, 6.4, b[2])
	L.autoshade(cv, [b], 2)
	var prev := V(8, 8.5)
	for k in range(0, 60):
		var t := float(k) / 59.0
		var a := t * TAU * 2.2
		var r := 0.6 + t * 5.4
		var p := V(8 + cos(a) * r, 8.5 + sin(a) * r)
		cv.line(int(prev.x), int(prev.y), int(p.x), int(p.y), b[0])
		prev = p
	cv.outline(L.OUTLINE)
	return cv

# ============================================================ event icons (32x32)
func ev_crystal_surge() -> PX.Canvas:
	var cv := I.icon(32)
	var rock := I.icon(32)
	I.lump(rock, R("darkrock"), 16, 27.5, 13.5, 4.5, 3, 0.2)
	L.autoshade(rock, [R("darkrock")], 2)
	I.speckle(rock, R("darkrock"), 3, 0.15, 0.08)
	rock.outline(L.OUTLINE)
	cv.blit(rock.img, 0, 0)
	var blue := L.r5("0a1a6a", "1e46c8", "3a7aff", "7ab8ff", "d8f0ff")
	var purp := L.r5("2a0a5a", "5a1ea8", "8a3ae8", "b87aff", "eed8ff")
	var cr := I.icon(32)
	I.crystal(cr, 7, 27, 12, 3.0, -3.0, purp)
	I.crystal(cr, 25, 27, 14, 3.2, 3.0, purp)
	I.crystal(cr, 11, 27, 18, 3.6, -2.0, blue)
	I.crystal(cr, 21, 27, 19, 3.6, 2.0, blue)
	I.crystal(cr, 16, 28, 26, 4.6, 0.0, blue)
	cr.outline(L.OUTLINE)
	L.glow(cr, Color(0.55, 0.5, 1.0, 0.6), 2)
	cv.blit(cr.img, 0, 0)
	I.big_star(cv, 4, 6, L.c("d8b0ff"))
	I.big_star(cv, 27, 4, Color.WHITE)
	I.star4(cv, 29, 13, L.c("b8fbff"))
	I.star4(cv, 3, 15, L.c("eed8ff"))
	return cv

func ev_geode_fever() -> PX.Canvas:
	var cv := I.icon(32)
	var sh := R("rock")
	var inner := R("amethyst")
	cv.circle(16, 17, 12.5, sh[2])
	L.autoshade(cv, [sh], 2)
	I.speckle(cv, sh, 5, 0.1, 0.06)
	for y in 32:
		for x in 32:
			var dx := x + 0.5 - 16.0
			var dy := y + 0.5 - 17.0
			var d := sqrt(dx * dx + dy * dy)
			if d <= 9.5:
				var a := atan2(dy, dx)
				var tooth := 0.5 + 0.5 * sin(a * 11.0)
				if d > 6.5 + tooth * 2.0:
					cv.px(x, y, inner[3] if dy < 0 else inner[2])
				elif d > 3.0:
					cv.px(x, y, inner[2] if (x * 3 + y) % 4 else inner[1])
				else:
					cv.px(x, y, inner[4])
			elif d <= 10.6:
				cv.px(x, y, sh[3] if dy < 0 else sh[1])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.7, 0.4, 1, 0.5), 2)
	I.big_star(cv, 26, 5, Color.WHITE)
	I.big_star(cv, 5, 8, L.c("eed8ff"))
	return cv

func ev_ore_rush() -> PX.Canvas:
	var cv := I.icon(32)
	var mats := [R("gold"), R("copper"), R("silver"), R("rust"), R("gold")]
	var pos := [V(9, 23), V(17, 24), V(24, 22), V(13, 17), V(20, 16)]
	for k in 5:
		var l := I.icon(32)
		var m: Array = mats[k]
		I.lump(l, m, pos[k].x, pos[k].y, 5.2, 4.4, k + 3)
		L.autoshade(l, [m], 2)
		I.speckle(l, m, k, 0.1, 0.1)
		l.px(int(pos[k].x) - 2, int(pos[k].y) - 2, m[4])
		l.outline(L.OUTLINE)
		cv.blit(l.img, 0, 0)
	for ax in [4, 14, 24]:
		var a := I.icon(32)
		a.polygon(PackedVector2Array([V(ax + 2.5, 1), V(ax + 6, 5), V(ax + 4, 5), V(ax + 4, 10), V(ax + 1, 10), V(ax + 1, 5), V(ax - 1, 5)]), L.c("4fdc6a"))
		a.outline(L.OUTLINE)
		cv.blit(a.img, 0, 0)
	return cv

func ev_meteor() -> PX.Canvas:
	var cv := I.icon(32)
	var tr := I.icon(32)
	var fl := R("flame")
	for k in 14:
		var t := float(k) / 13.0
		var p := V(6, 6).lerp(V(19, 19), t)
		L.disc(tr, p.x, p.y, lerpf(1.2, 5.0, t), fl[1] if t < 0.4 else (fl[2] if t < 0.75 else fl[3]))
	cv.blit(tr.img, 0, 0)
	var rk := I.icon(32)
	I.lump(rk, R("volcrock"), 21.5, 21.5, 6.2, 6.0, 9, 0.3, false)
	L.autoshade(rk, [R("volcrock")], 2)
	rk.line(19, 22, 23, 20, R("magma")[3])
	rk.px(20, 19, R("magma")[2])
	rk.outline(L.OUTLINE)
	cv.blit(rk.img, 0, 0)
	L.glow(cv, Color(1, 0.5, 0.2, 0.5), 2)
	I.star4(cv, 26, 5, Color.WHITE)
	I.star4(cv, 6, 24, Color.WHITE)
	I.big_star(cv, 14, 3, L.c("fff1a8"))
	return cv

func ev_cart() -> PX.Canvas:
	var cv := I.icon(32)
	var cart := I.icon(32)
	var s := R("steel")
	cart.polygon(PackedVector2Array([V(3, 13), V(29, 13), V(26, 25), V(6, 25)]), s[2])
	L.autoshade(cart, [s], 2)
	cart.fill_rect(3, 13, 26, 2, s[3])
	cart.fill_rect(5, 18, 22, 1, s[1])
	for wx in [10, 22]:
		cart.circle(wx, 26.5, 3.0, R("coal")[2])
		cart.px(wx, 26, s[3])
	cart.outline(L.OUTLINE)
	var gems := I.icon(32)
	var gl := [[R("amethyst"), V(9, 10)], [R("sapphire"), V(16, 8)], [R("emerald"), V(23, 10)], [R("gold"), V(13, 11)], [R("ruby"), V(20, 11)]]
	for g in gl:
		I.gem_ball(gems, g[1], 3.4, g[0])
	cv.blit(gems.img, 0, 0)
	cv.blit(cart.img, 0, 0)
	I.big_star(cv, 27, 4, Color.WHITE)
	return cv

func ev_double() -> PX.Canvas:
	var cv := I.icon(32)
	var t := I.icon(32)
	var g := R("gold")
	# "x"
	L.thick(t, [V(3, 10), V(12, 22)], 1.8, g[2])
	L.thick(t, [V(12, 10), V(3, 22)], 1.8, g[2])
	# "2"
	L.thick(t, [V(16, 11), V(19, 8), V(25, 8), V(28, 11), V(27, 15), V(16, 24), V(29, 24)], 1.8, g[2])
	L.autoshade(t, [g], 2)
	t.outline(L.OUTLINE)
	t.outline(L.c("5a2a08"))
	cv.blit(t.img, 0, 0)
	I.big_star(cv, 5, 4, Color.WHITE)
	I.big_star(cv, 28, 28, L.c("fff1a8"))
	I.star4(cv, 15, 3, Color.WHITE)
	return cv

func ev_ancient() -> PX.Canvas:
	var cv := I.icon(32)
	var s := R("sand")
	var dr := I.icon(32)
	dr.fill_rect(3, 8, 6, 22, s[2])
	dr.fill_rect(23, 8, 6, 22, s[2])
	dr.fill_rect(1, 3, 30, 6, s[2])
	L.autoshade(dr, [s], 2)
	for y in [13, 19, 25]:
		dr.line(3, y, 8, y, s[1])
		dr.line(23, y, 28, y, s[1])
	dr.outline(L.OUTLINE)
	cv.fill_rect(9, 9, 14, 21, L.c("0a1a2a"))
	cv.circle(16, 19, 5.0, L.c("145050"))
	cv.circle(16, 19, 3.0, R("glyph")[2])
	cv.circle(16, 19, 1.4, Color.WHITE)
	L.glow(cv, Color(0.3, 1, 0.9, 0.5), 2)
	cv.blit(dr.img, 0, 0)
	var g := R("glyph")
	for p in [V(6, 5), V(11, 5), V(16, 5), V(21, 5), V(26, 5)]:
		cv.px(int(p.x), int(p.y), g[3])
		cv.px(int(p.x), int(p.y) + 1, g[2])
	return cv

func ev_expedition() -> PX.Canvas:
	var cv := I.icon(32)
	var m := I.icon(32)
	var c := R("canvas")
	m.polygon(PackedVector2Array([V(2, 6), V(10, 3), V(20, 7), V(30, 3), V(30, 26), V(20, 30), V(10, 26), V(2, 30)]), c[2])
	L.autoshade(m, [c], 2)
	m.line(10, 3, 10, 26, c[1])
	m.line(20, 7, 20, 30, c[1])
	for k in 6:
		m.px(5 + k * 3, 22 - k * 2, L.c("c0402a"))
	m.line(23, 9, 27, 13, L.c("c0402a"))
	m.line(27, 9, 23, 13, L.c("c0402a"))
	m.outline(L.OUTLINE)
	cv.blit(m.img, 0, 0)
	var cp := I.icon(32)
	cp.circle(9, 23, 6.5, R("gold")[2])
	L.autoshade(cp, [R("gold")], 2)
	cp.circle(9, 23, 4.5, L.c("f4f0e0"))
	cp.polygon(PackedVector2Array([V(9, 18.5), V(10.5, 23), V(7.5, 23)]), L.c("e83a3a"))
	cp.polygon(PackedVector2Array([V(9, 27.5), V(10.5, 23), V(7.5, 23)]), L.c("3a4458"))
	cp.outline(L.OUTLINE)
	cv.blit(cp.img, 0, 0)
	I.big_star(cv, 27, 18, Color.WHITE)
	return cv

# ============================================================ UI icons
func col_shape(draw: Callable, ramp: Array) -> PX.Canvas:
	var cv := I.icon()
	draw.call(cv, ramp[2])
	L.autoshade(cv, [ramp], 2)
	cv.outline(L.OUTLINE)
	return cv

func arrow_icon(dir: int) -> PX.Canvas:
	var cv := col_shape(func(c, col):
		c.polygon(PackedVector2Array([V(2, 6), V(9, 6), V(9, 2), V(15, 8), V(9, 14), V(9, 10), V(2, 10)]), col), R("gold"))
	var img := cv.img
	match dir:
		1: img.flip_x()
		2: img.rotate_90(COUNTERCLOCKWISE)
		3: img.rotate_90(CLOCKWISE)
	return cv

func ui_icon(i: int) -> PX.Canvas:
	var cv: PX.Canvas
	match i:
		0:
			cv = col_shape(func(c, col): c.circle(8, 8, 7.0, col), R("gold"))
			var g := R("gold")
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 8.0
					var dy := y + 0.5 - 8.0
					var d := sqrt(dx * dx + dy * dy)
					if d > 4.2 and d < 5.2:
						cv.px(x, y, g[1] if dx + dy > 0 else g[3])
			var st := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * TAU / 10.0
				var r := 3.2 if k % 2 == 0 else 1.4
				st.append(V(8 + cos(a) * r, 8.2 + sin(a) * r))
			cv.polygon(st, g[3])
			cv.px(4, 3, g[4])
			cv.px(3, 4, g[4])
		1:
			cv = I.icon()
			var p := R("purple")
			var pts := PackedVector2Array([V(8, 0.5), V(14.5, 6), V(8, 15.5), V(1.5, 6)])
			cv.polygon(pts, p[2])
			cv.polygon(PackedVector2Array([V(8, 0.5), V(14.5, 6), V(8, 6)]), p[1])
			cv.polygon(PackedVector2Array([V(8, 0.5), V(8, 6), V(1.5, 6)]), p[4])
			cv.polygon(PackedVector2Array([V(1.5, 6), V(8, 6), V(8, 15.5)]), p[3])
			cv.outline(L.OUTLINE)
			cv.px(5, 4, Color.WHITE)
		2:
			cv = col_shape(func(c, col):
				var st := PackedVector2Array()
				for k in 10:
					var a := -PI / 2.0 + k * TAU / 10.0
					var r := 7.6 if k % 2 == 0 else 3.4
					st.append(V(8 + cos(a) * r, 8.6 + sin(a) * r))
				c.polygon(st, col), R("gold"))
			cv.px(6, 6, R("gold")[4])
		3:
			cv = col_shape(func(c, col): c.circle(8, 8, 7.0, col), R("blue"))
			var t: Color = Color.WHITE
			cv.line(3, 5, 6, 10, t)
			cv.line(6, 5, 3, 10, t)
			cv.fill_rect(8, 5, 1, 6, t)
			cv.fill_rect(9, 5, 3, 1, t)
			cv.fill_rect(9, 7, 3, 1, t)
			cv.px(12, 6, t)
		4:
			cv = col_shape(func(c, col):
				c.circle(5, 6, 3.6, col)
				c.circle(11, 6, 3.6, col)
				c.polygon(PackedVector2Array([V(1.5, 7), V(14.5, 7), V(8, 14.5)]), col), R("red"))
			cv.px(4, 4, Color.WHITE)
			cv.px(3, 5, R("red")[4])
		5:
			cv = col_shape(func(c, col): c.circle(8, 8, 7, col), R("gold"))
			cv.circle(8, 8, 5.2, L.c("f4f0e0"))
			cv.line(8, 8, 8, 4, L.c("1b1424"))
			cv.line(8, 8, 11, 9, L.c("1b1424"))
		6:
			cv = I.icon()
			var g := R("gold")
			for k in 8:
				var a := k * TAU / 8.0
				L.thick(cv, [V(8 + cos(a) * 5.0, 8 + sin(a) * 5.0), V(8 + cos(a) * 7.2, 8 + sin(a) * 7.2)], 0.7, g[3])
			cv.circle(8, 8, 4.2, g[2])
			L.autoshade(cv, [g], 2)
			cv.outline(L.OUTLINE)
		7:
			cv = col_shape(func(c, col): c.circle(8, 8, 6.5, col), L.r5("8a7a3a", "c8b870", "f0e8b0", "fffbe0", "ffffff"))
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 11.0
					var dy := y + 0.5 - 6.0
					if dx * dx + dy * dy < 30.0:
						cv.px(x, y, Color(0, 0, 0, 0))
			cv.outline(L.OUTLINE)
		8:
			cv = col_shape(func(c, col): d_backpack(c, col), L.r5("6a2a08", "b04a14", "ef7a22", "ffa040", "ffd080"))
			cv.fill_rect(5, 9, 6, 4, L.c("b04a14"))
			cv.fill_rect(3, 6, 10, 1, L.c("b04a14"))
			cv.px(8, 7, R("gold")[3])
		9:
			cv = col_shape(func(c, col): d_gear(c, col), L.r5("0e2a6a", "1e4ab0", "3a7ae8", "6aa8ff", "b0d8ff"))
			gear_hole(cv)
			cv.outline(L.OUTLINE)
		10:
			cv = col_shape(func(c, col): d_map(c, col), L.r5("1a4a2a", "2a7a44", "4aa868", "7ad890", "b8f8c8"))
			cv.line(5, 2, 5, 13, L.c("2a7a44"))
			cv.line(10, 4, 10, 15, L.c("2a7a44"))
			cv.line(3, 11, 8, 8, L.c("ffc93c"))
			cv.line(8, 8, 12, 9, L.c("ffc93c"))
			cv.px(12, 8, L.c("e83a3a"))
		11:
			cv = col_shape(func(c, col): c.fill_rect(2, 1, 12, 14, col), R("leather"))
			cv.fill_rect(12, 2, 2, 12, L.c("f4f0e0"))
			cv.fill_rect(2, 1, 2, 14, L.c("5e3a1c"))
			cv.fill_rect(6, 5, 5, 2, R("gold")[2])
		12:
			cv = col_shape(func(c, col): d_hex(c, col, false), R("cyan"))
			cv.circle(8, 8, 1.6, R("gold")[3])
		13:
			cv = I.icon()
			var s := L.r5("0e2a6a", "1e4ab0", "3a7ae8", "6aa8ff", "b0d8ff")
			cv.polygon(PackedVector2Array([V(3, 4), V(15, 4), V(13, 10), V(5, 10)]), s[2])
			cv.line(0, 2, 3, 2, s[2])
			cv.line(3, 2, 5, 11, s[2])
			cv.line(5, 11, 13, 11, s[2])
			L.autoshade(cv, [s], 2)
			cv.circle(6, 13.5, 1.5, R("coal")[3])
			cv.circle(12, 13.5, 1.5, R("coal")[3])
			cv.outline(L.OUTLINE)
		14:
			cv = I.icon()
			var g := R("gold")
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 8.0
					var dy := y + 0.5 - 6.5
					var d := sqrt(dx * dx + dy * dy)
					if dy < 1.0 and d <= 4.6 and d >= 2.6:
						cv.px(x, y, R("steel")[3])
			cv.fill_rect(3, 7, 10, 8, g[2])
			L.autoshade(cv, [g, R("steel")], 2)
			cv.fill_rect(7, 9, 2, 3, L.c("3a1a08"))
			cv.outline(L.OUTLINE)
		15:
			cv = col_shape(func(c, col):
				L.thick(c, [V(2.5, 8.5), V(6.5, 12.5), V(13.5, 3.5)], 1.3, col), R("green"))
		16:
			cv = col_shape(func(c, col):
				L.thick(c, [V(3.5, 3.5), V(12.5, 12.5)], 1.4, col)
				L.thick(c, [V(12.5, 3.5), V(3.5, 12.5)], 1.4, col), R("red"))
		17: cv = arrow_icon(0)
		18: cv = arrow_icon(1)
		19: cv = arrow_icon(2)
		20: cv = arrow_icon(3)
		21: cv = col_shape(func(c, col):
				c.fill_rect(6, 2, 4, 12, col)
				c.fill_rect(2, 6, 12, 4, col), R("green"))
		22: cv = col_shape(func(c, col): c.fill_rect(2, 6, 12, 4, col), R("red"))
		23:
			cv = I.icon()
			var w := I.W()
			for k in 4:
				var sx := 1 if k % 2 == 0 else 10
				var sy := 1 if k < 2 else 10
				cv.fill_rect(sx, sy, 5, 2, w[2])
				cv.fill_rect(sx + (0 if k % 2 == 0 else 3), sy + (0 if k < 2 else -3), 2, 5, w[2])
			cv.fill_rect(10, 10, 5, 2, Color(0, 0, 0, 0))
			cv.fill_rect(1, 13, 5, 2, w[2])
			cv.fill_rect(10, 13, 5, 2, w[2])
			cv.fill_rect(13, 10, 2, 5, w[2])
			cv.fill_rect(1, 10, 2, 5, w[2])
			cv.outline(L.OUTLINE)
		24:
			cv = I.icon()
			var w2 := I.W()
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 8.0
					var dy := y + 0.5 - 8.0
					var d := sqrt(dx * dx + dy * dy)
					if d <= 6.5 and d >= 4.8:
						cv.px(x, y, w2[2])
			cv.fill_rect(7, 0, 2, 5, w2[2])
			cv.fill_rect(7, 11, 2, 5, w2[2])
			cv.fill_rect(0, 7, 5, 2, w2[2])
			cv.fill_rect(11, 7, 5, 2, w2[2])
			cv.fill_rect(7, 7, 2, 2, L.c("ff5a4a"))
			cv.outline(L.OUTLINE)
		25:
			cv = I.icon()
			var w3 := I.W()
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 8.0
					var dy := y + 0.5 - 8.5
					var d := sqrt(dx * dx + dy * dy)
					var a := atan2(dy, dx)
					if d <= 6.6 and d >= 4.4 and not (a > -1.9 and a < -0.9):
						cv.px(x, y, w3[2])
			cv.polygon(PackedVector2Array([V(9, 0), V(14, 3), V(9, 7)]), w3[2])
			L.autoshade(cv, [w3], 1)
			cv.outline(L.OUTLINE)
		26:
			cv = col_shape(func(c, col):
				c.polygon(PackedVector2Array([V(3, 1), V(13, 1), V(12, 6), V(9, 9), V(7, 9), V(4, 6)]), col)
				c.fill_rect(7, 9, 2, 3, col)
				c.fill_rect(4, 12, 8, 3, col)
				c.line(1, 2, 2, 5, col)
				c.line(14, 2, 13, 5, col), R("gold"))
			cv.px(5, 3, R("gold")[4])
		27:
			cv = col_shape(func(c, col): c.fill_rect(2, 1, 12, 14, col), R("gold"))
			cv.fill_rect(7, 3, 2, 7, L.c("1b1424"))
			cv.fill_rect(7, 11, 2, 2, L.c("1b1424"))
		28:
			cv = col_shape(func(c, col): c.circle(8, 8, 7, col), R("blue"))
			cv.fill_rect(7, 3, 2, 2, Color.WHITE)
			cv.fill_rect(7, 6, 2, 7, Color.WHITE)
		29:
			cv = I.icon()
			var hd := I.icon()
			hd.fill_rect(3, 2, 10, 5, R("steel")[2])
			L.autoshade(hd, [R("steel")], 2)
			hd.outline(L.OUTLINE)
			var hn := I.icon()
			hn.fill_rect(7, 7, 2, 8, R("wood")[2])
			L.autoshade(hn, [R("wood")], 2)
			hn.outline(L.OUTLINE)
			cv.blit(hn.img, 0, 0)
			cv.blit(hd.img, 0, 0)
		30:
			cv = I.icon()
			var f := R("flame")
			cv.ellipse(8, 10, 5.2, 5.0, f[2])
			cv.polygon(PackedVector2Array([V(3, 9), V(6, 1), V(8, 5), V(11, 2), V(13, 9)]), f[2])
			L.autoshade(cv, [f], 2)
			cv.ellipse(8, 11, 2.4, 2.6, f[4])
			cv.outline(L.OUTLINE)
		31:
			cv = col_shape(func(c, col): d_gear(c, col), R("bronze"))
			gear_hole(cv)
			cv.outline(L.OUTLINE)
		32:
			cv = I.icon()
			var b := L.r5("0e2a6a", "1e4ab0", "3a7ae8", "6aa8ff", "d8f0ff")
			cv.polygon(PackedVector2Array([V(0, 15), V(6, 4), V(9, 8), V(11, 6), V(16, 15)]), b[2])
			L.autoshade(cv, [b], 2)
			cv.polygon(PackedVector2Array([V(6, 4), V(7.5, 7), V(4.5, 7)]), Color.WHITE)
			cv.outline(L.OUTLINE)
		33:
			cv = col_shape(func(c, col):
				c.fill_rect(3, 1, 10, 14, col), R("steel"))
			cv.fill_rect(4, 2, 8, 12, L.c("0a1a2a"))
			cv.polygon(PackedVector2Array([V(8, 3), V(11, 6.5), V(5, 6.5)]), R("gold")[3])
			cv.polygon(PackedVector2Array([V(8, 13), V(11, 9.5), V(5, 9.5)]), R("gold")[3])
		34:
			cv = col_shape(func(c, col):
				c.circle(8, 9, 6.0, col)
				c.fill_rect(6, 0, 4, 2, col)
				c.fill_rect(7, 2, 2, 1, col), R("gold"))
			cv.circle(8, 9, 4.2, L.c("f4f0e0"))
			cv.line(8, 9, 8, 6, L.c("1b1424"))
			cv.line(8, 9, 10, 10, L.c("e83a3a"))
		35:
			cv = col_shape(func(c, col):
				c.circle(8, 10, 5.5, col)
				c.fill_rect(5, 3, 6, 3, col), R("leather"))
			cv.line(5, 5, 10, 5, R("gold")[3])
			cv.line(7, 7, 7, 13, R("gold")[3])
			cv.line(6, 8, 9, 8, R("gold")[3])
			cv.line(6, 10, 9, 10, R("gold")[3])
			cv.line(6, 12, 9, 12, R("gold")[3])
		36:
			cv = I.icon()
			var w4 := I.W()
			for k in 4:
				cv.fill_rect(1 + k * 4, 12 - k * 3, 3, 3 + k * 3, w4[2])
			cv.outline(L.OUTLINE)
		37: cv = col_shape(func(c, col):
				c.polygon(PackedVector2Array([V(1, 2), V(15, 2), V(9.5, 8), V(9.5, 14), V(6.5, 12), V(6.5, 8)]), col), I.W())
		38:
			cv = col_shape(func(c, col):
				c.fill_rect(3, 4, 10, 11, col)
				c.fill_rect(2, 2, 12, 2, col)
				c.fill_rect(6, 0, 4, 2, col), R("steel"))
			for x in [5, 8, 11]:
				cv.line(x, 6, x, 13, R("steel")[1])
		39: cv = I.pickaxe16(R("steel"), R("wood"))
		40:
			cv = col_shape(func(c, col): d_chest(c, col), R("wood"))
			cv.fill_rect(2, 7, 12, 1, R("gold")[1])
			cv.fill_rect(2, 4, 1, 10, R("gold")[2])
			cv.fill_rect(13, 4, 1, 10, R("gold")[2])
			cv.fill_rect(7, 6, 2, 3, R("gold")[3])
		41:
			cv = I.icon()
			I.big_star(cv, 6, 9, L.c("ffe680"))
			I.big_star(cv, 12, 4, Color.WHITE)
			I.star4(cv, 12, 12, L.c("b8fbff"))
			L.glow(cv, Color(1, 1, 0.7, 0.4), 1)
		42:
			cv = col_shape(func(c, col):
				c.polygon(PackedVector2Array([V(8, 0.5), V(15.5, 14.5), V(0.5, 14.5)]), col), R("gold"))
			cv.fill_rect(7, 5, 2, 5, L.c("1b1424"))
			cv.fill_rect(7, 11, 2, 2, L.c("1b1424"))
		43:
			cv = col_shape(func(c, col):
				c.fill_rect(1, 5, 4, 6, col)
				c.polygon(PackedVector2Array([V(5, 5), V(10, 1), V(10, 15), V(5, 11)]), col), I.W())
			cv.line(12, 5, 13, 7, I.W()[3])
			cv.line(13, 8, 12, 10, I.W()[3])
		44:
			cv = col_shape(func(c, col):
				c.circle(4.5, 12.5, 2.8, col)
				c.circle(11.5, 10.5, 2.8, col)
				c.fill_rect(6, 2, 2, 10, col)
				c.fill_rect(13, 1, 2, 9, col)
				c.polygon(PackedVector2Array([V(6, 1), V(15, -1), V(15, 3), V(6, 5)]), col), R("cyan"))
		45:
			cv = col_shape(func(c, col): c.fill_rect(0, 4, 16, 9, col), R("steel"))
			for y in [5, 7, 9]:
				for x in range(1, 15, 2):
					cv.px(x, y, I.W()[2])
			cv.fill_rect(4, 11, 8, 1, I.W()[2])
		46:
			cv = col_shape(func(c, col): c.ellipse(8, 8.5, 5.0, 7.0, col), I.W())
			cv.line(8, 2, 8, 7, I.W()[0])
			cv.fill_rect(3, 2, 5, 5, L.c("ff8a2a"))
			cv.outline(L.OUTLINE)
		47:
			cv = col_shape(func(c, col): c.fill_rect(1, 3, 14, 12, col), R("wood"))
			cv.line(1, 3, 14, 14, R("wood")[1])
			cv.line(14, 3, 1, 14, R("wood")[1])
			cv.rect_outline(1, 3, 14, 12, R("wood")[1])
		48:
			cv = col_shape(func(c, col): d_lantern(c, col), R("gold"))
			cv.fill_rect(6, 5, 4, 7, R("flame")[3])
			cv.px(7, 7, Color.WHITE)
			L.glow(cv, Color(1, 0.8, 0.3, 0.5), 1)
		49:
			cv = col_shape(func(c, col): d_compass(c, col), R("gold"))
			cv.circle(8, 8.5, 4.6, L.c("f4f0e0"))
			cv.polygon(PackedVector2Array([V(8, 4), V(9.5, 8.5), V(6.5, 8.5)]), L.c("e83a3a"))
			cv.polygon(PackedVector2Array([V(8, 13), V(9.5, 8.5), V(6.5, 8.5)]), L.c("3a4458"))
		50: cv = _ammonite()
		51: cv = I.geode(R("rock"), R("amethyst"), 3)
		52:
			cv = I.icon()
			var g2 := R("gold")
			cv.polygon(PackedVector2Array([V(1, 4), V(4.5, 8), V(8, 2), V(11.5, 8), V(15, 4), V(14, 13), V(2, 13)]), g2[2])
			L.autoshade(cv, [g2], 2)
			cv.fill_rect(2, 11, 12, 2, g2[1])
			cv.px(5, 11, R("ruby")[3])
			cv.px(8, 11, R("sapphire")[3])
			cv.px(11, 11, R("emerald")[3])
			cv.outline(L.OUTLINE)
		53:
			cv = col_shape(func(c, col): c.fill_rect(1, 1, 14, 14, col), R("blue"))
			cv.fill_rect(4, 1, 8, 5, I.W()[2])
			cv.fill_rect(9, 2, 2, 3, R("blue")[1])
			cv.fill_rect(3, 9, 10, 6, L.c("f4f0e0"))
			cv.line(4, 11, 11, 11, R("steel")[3])
			cv.line(4, 13, 11, 13, R("steel")[3])
	if cv == null:
		cv = I.icon()
		cv.fill_rect(2, 2, 12, 12, Color.MAGENTA)
	return cv

func _init() -> void:
	var sk := Image.create(256, 48, false, Image.FORMAT_RGBA8)
	sk.fill(Color(0, 0, 0, 0))
	for i in 40:
		var cv := skill_icon(i)
		sk.blit_rect(cv.img, Rect2i(0, 0, 16, 16), Vector2i((i % 16) * 16, (i / 16) * 16))
	L.save(sk, "sprites/items/skill_icons.png")
	L.preview(sk, "ch_skills.png", 5, Vector2i(16, 16), Color("6b3fa8"))

	var ev := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	ev.fill(Color(0, 0, 0, 0))
	var evs := [ev_crystal_surge(), ev_geode_fever(), ev_ore_rush(), ev_meteor(), ev_cart(), ev_double(), ev_ancient(), ev_expedition()]
	for i in evs.size():
		var c2: PX.Canvas = evs[i]
		ev.blit_rect(c2.img, Rect2i(0, 0, 32, 32), Vector2i(i * 32, 0))
	L.save(ev, "sprites/items/event_icons.png")
	L.preview(ev, "ch_events.png", 4, Vector2i(32, 32), Color("2a1a4a"))

	var ui := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	ui.fill(Color(0, 0, 0, 0))
	for i in 54:
		var c3 := ui_icon(i)
		ui.blit_rect(c3.img, Rect2i(0, 0, 16, 16), Vector2i((i % 16) * 16, (i / 16) * 16))
	L.save(ui, "ui/ui_icons.png")
	L.preview(ui, "ch_ui_icons.png", 5, Vector2i(16, 16))
	quit()
