## Generates equipment.png — index = "icon" in data/tools/equipment.json (+ 23-31 machines, 32-35 cosmetics)
extends SceneTree
const PX = preload("res://px.gd")
const L = preload("res://chlib.gd")
const I = preload("res://ch_iconlib.gd")

func R(n: String) -> Array:
	return I.R(n)

func drill16(body: Array, bit: Array, big: bool = false) -> PX.Canvas:
	var cv := I.icon()
	var g := I.icon()
	L.thick(g, [Vector2(2.5, 13.5), Vector2(5.0, 11.0)], 1.3, R("steel")[2])
	L.thick(g, [Vector2(4.5, 11.5), Vector2(9.0, 7.0)], 2.4 if big else 2.1, body[2])
	L.autoshade(g, [body, R("steel")], 2)
	g.outline(L.OUTLINE)
	cv.blit(g.img, 0, 0)
	var b := I.icon()
	for i in 9:
		var t := float(i) / 8.0
		var p := Vector2(9.5, 6.5).lerp(Vector2(14.5, 1.5), t)
		L.disc(b, p.x, p.y, lerpf(2.2 if big else 1.8, 0.5, t), bit[2])
	L.autoshade(b, [bit], 2)
	for i in 3:
		var p2 := Vector2(10.5, 5.5).lerp(Vector2(13.5, 2.5), i / 2.0)
		b.px(int(p2.x) + 1, int(p2.y) + 1, bit[0])
	b.outline(L.OUTLINE)
	cv.blit(b.img, 0, 0)
	return cv

func backpack16(body: Array, trim: Array, big: int, roll = null) -> PX.Canvas:
	var cv := I.icon()
	var x0 := 4 - big
	var w := 8 + big * 2
	var y0 := 4 - big
	cv.fill_rect(x0, y0 + 1, w, 15 - y0 - 1 - 1, body[2])
	cv.fill_rect(x0 + 1, y0, w - 2, 1, body[2])
	L.autoshade(cv, [body], 2)
	# flap
	cv.fill_rect(x0, y0 + 1, w, 3, body[3])
	for x in range(x0, x0 + w):
		cv.px(x, y0 + 4, body[1])
	# pocket
	cv.fill_rect(x0 + 2, y0 + 7, w - 4, 4, body[1])
	cv.fill_rect(x0 + 2, y0 + 7, w - 4, 1, body[3])
	cv.px(x0 + w / 2, y0 + 5, trim[3])
	cv.px(x0 + w / 2, y0 + 8, trim[2])
	# straps
	cv.line(x0 + 1, y0 + 5, x0 + 1, 13, trim[1])
	cv.line(x0 + w - 2, y0 + 5, x0 + w - 2, 13, trim[1])
	if roll != null:
		cv.fill_rect(x0 - 1, y0 - 2, w + 2, 3, roll[2])
		cv.px(x0 - 1, y0 - 2, roll[3])
		cv.line(x0 + 2, y0 - 2, x0 + 2, y0, roll[1])
		cv.line(x0 + w - 3, y0 - 2, x0 + w - 3, y0, roll[1])
	cv.outline(L.OUTLINE)
	return cv

func lantern16(frame: Array, light: Array, glow: Color, rays: bool = false) -> PX.Canvas:
	var cv := I.icon()
	# handle ring
	cv.line(6, 1, 9, 1, frame[2])
	cv.px(5, 2, frame[2])
	cv.px(10, 2, frame[2])
	# cap, glass, base
	cv.fill_rect(4, 3, 8, 2, frame[2])
	cv.fill_rect(5, 5, 6, 7, light[2])
	cv.fill_rect(4, 12, 8, 2, frame[2])
	cv.fill_rect(5, 14, 6, 1, frame[1])
	# bars
	cv.line(5, 5, 5, 11, frame[1])
	cv.line(10, 5, 10, 11, frame[1])
	L.autoshade(cv, [frame], 2)
	cv.fill_rect(7, 6, 2, 5, light[3])
	cv.px(7, 7, light[4])
	cv.px(8, 8, light[4])
	cv.px(4, 3, frame[4])
	cv.outline(L.OUTLINE)
	L.glow(cv, glow, 2)
	if rays:
		for p in [Vector2i(1, 8), Vector2i(14, 8), Vector2i(2, 3), Vector2i(13, 3), Vector2i(8, 15)]:
			cv.blend(p.x, p.y, Color(1, 1, 0.8, 0.8))
	return cv

func scanner16(screen: Array, big: bool) -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(3, 3, 10, 12, s[2])
	L.autoshade(cv, [s], 2)
	cv.fill_rect(4, 4, 8, 6, screen[1])
	cv.fill_rect(5, 5, 6, 4, screen[2])
	# radar arcs + blip
	cv.line(5, 8, 7, 6, screen[3])
	cv.line(7, 6, 10, 6, screen[3])
	cv.px(9, 7, screen[4])
	cv.px(8, 7, Color.WHITE)
	cv.px(5, 12, L.c("ff5a4a"))
	cv.px(7, 12, L.c("ffd84a"))
	cv.px(9, 12, L.c("5ae08a"))
	if big:
		cv.line(11, 3, 13, 0, s[3])
		cv.px(13, 0, L.c("ff5a4a"))
	else:
		cv.line(10, 3, 11, 1, s[3])
	cv.outline(L.OUTLINE)
	return cv

func boots16(ramp: Array, sole: Array, accent = null, glow = null) -> PX.Canvas:
	var cv := I.icon()
	for k in 2:
		var b := I.icon()
		var ox := 5 if k == 0 else 1
		var oy := -1 if k == 0 else 1
		var r: Array = ramp
		b.fill_rect(ox + 2, oy + 3, 5, 8, r[2])
		b.fill_rect(ox + 2, oy + 9, 9, 4, r[2])
		b.px(ox + 10, oy + 9, Color(0, 0, 0, 0))
		b.fill_rect(ox + 2, oy + 13, 9, 1, sole[2])
		L.autoshade(b, [r, sole], 2)
		b.fill_rect(ox + 1, oy + 3, 7, 2, r[3])
		b.px(ox + 10, oy + 12, sole[1])
		b.px(ox + 4, oy + 6, r[1])
		b.px(ox + 5, oy + 7, r[1])
		if accent != null:
			b.line(ox + 3, oy + 10, ox + 8, oy + 10, accent)
		b.outline(L.OUTLINE)
		if k == 0:
			b.shade_rect(0, 0, 16, 16, 0.72)
		cv.blit(b.img, 0, 0)
	if glow != null:
		L.glow(cv, glow, 1)
	return cv

# ---------------------------------------------------------------- machines (mini)
func m_smelter() -> PX.Canvas:
	var cv := I.icon()
	var st := R("stone2")
	cv.fill_rect(2, 5, 12, 10, st[2])
	cv.fill_rect(10, 1, 3, 4, st[2])
	L.autoshade(cv, [st], 2)
	for y in [7, 10, 13]:
		for x in range(2, 14, 4):
			cv.px(x + (y % 2) * 2, y, st[1])
	cv.fill_rect(5, 9, 6, 5, L.c("3a1208"))
	cv.fill_rect(6, 10, 4, 4, R("flame")[2])
	cv.px(7, 11, R("flame")[4])
	cv.px(8, 12, R("flame")[3])
	cv.outline(L.OUTLINE)
	cv.blend(11, 0, Color(0.7, 0.7, 0.75, 0.6))
	return cv

func m_crusher() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(2, 6, 12, 9, s[2])
	cv.polygon(PackedVector2Array([Vector2(1, 2), Vector2(15, 2), Vector2(12, 6), Vector2(4, 6)]), s[2])
	L.autoshade(cv, [s], 2)
	for x in range(3, 13, 2):
		cv.px(x, 6, Color.WHITE)
		cv.px(x + 1, 7, s[0])
	for x in range(2, 14):
		cv.px(x, 12, L.c("ffd84a") if (x / 2) % 2 == 0 else L.c("1b1424"))
	cv.px(5, 3, R("rock")[2])
	cv.px(9, 3, R("rock")[3])
	cv.outline(L.OUTLINE)
	return cv

func m_drill_rig(deep: bool) -> PX.Canvas:
	var cv := I.icon()
	var f := R("rust") if not deep else R("steel")
	cv.line(3, 14, 8, 1, f[2])
	cv.line(13, 14, 8, 1, f[2])
	cv.line(5, 9, 11, 9, f[2])
	cv.line(4, 12, 12, 12, f[2])
	cv.fill_rect(6, 3, 5, 3, R("gold")[2] if not deep else R("red")[2])
	L.thick(cv, [Vector2(8.5, 6), Vector2(8.5, 14.5)], 0.9, R("steel")[3])
	L.autoshade(cv, [f, R("steel"), R("gold"), R("red")], 2)
	cv.fill_rect(1, 14, 14, 2, R("rock")[1])
	cv.outline(L.OUTLINE)
	if deep:
		cv.px(7, 4, L.c("ff5a4a"))
		cv.px(9, 4, L.c("5ff2ff"))
	return cv

func m_adv_smelter() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(2, 4, 12, 11, s[2])
	cv.fill_rect(11, 1, 2, 3, s[2])
	cv.fill_rect(3, 1, 2, 3, s[2])
	L.autoshade(cv, [s], 2)
	cv.fill_rect(4, 8, 8, 5, L.c("0a1a3a"))
	cv.fill_rect(5, 9, 6, 3, R("cyan")[2])
	cv.px(6, 10, Color.WHITE)
	cv.px(7, 5, L.c("ffd84a"))
	cv.px(9, 5, L.c("5ae08a"))
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.4, 0.9, 1, 0.35), 1)
	return cv

func m_polisher() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(3, 11, 10, 4, R("wood")[2])
	cv.circle(8, 6.5, 4.6, s[2])
	L.autoshade(cv, [s, R("wood")], 2)
	cv.circle(8, 6.5, 1.4, s[0])
	cv.outline(L.OUTLINE)
	var gem := I.gem_cut(R("ruby"), "round")
	var small := gem.img.duplicate() as Image
	small.resize(8, 8, Image.INTERPOLATE_NEAREST)
	cv.blit(small, 9, 7)
	I.star4(cv, 14, 7, Color.WHITE)
	return cv

func m_extractor() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(3, 1, 10, 2, s[2])
	cv.fill_rect(3, 13, 10, 2, s[2])
	cv.fill_rect(4, 3, 8, 10, L.c("1a3a5a"))
	L.autoshade(cv, [s], 2)
	I.crystal(cv, 8, 12, 8, 2.0, 0.0, R("shard"))
	cv.line(4, 3, 4, 12, L.c("8ad8ff"))
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.4, 0.8, 1, 0.4), 1)
	return cv

func m_sorter() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	cv.fill_rect(1, 4, 14, 2, s[1])
	cv.fill_rect(2, 6, 1, 3, s[1])
	cv.fill_rect(13, 6, 1, 3, s[1])
	var cols := [R("copper"), R("silver"), R("gold")]
	for i in 3:
		var c: Array = cols[i]
		cv.fill_rect(1 + i * 5, 9, 4, 6, c[2])
	L.autoshade(cv, [s, R("copper"), R("silver"), R("gold")], 2)
	for x in range(2, 14, 3):
		cv.px(x, 4, s[3])
	cv.px(4, 3, R("rock")[2])
	cv.px(9, 3, R("gold")[3])
	cv.outline(L.OUTLINE)
	return cv

func m_robot() -> PX.Canvas:
	var cv := I.icon()
	var y := R("gold")
	cv.fill_rect(4, 2, 8, 6, y[2])
	cv.fill_rect(5, 8, 6, 5, y[2])
	cv.fill_rect(4, 13, 3, 2, R("steel")[2])
	cv.fill_rect(9, 13, 3, 2, R("steel")[2])
	L.autoshade(cv, [y, R("steel")], 2)
	cv.fill_rect(5, 4, 6, 2, L.c("0a1a2a"))
	cv.px(6, 4, R("cyan")[3])
	cv.px(9, 4, R("cyan")[3])
	cv.line(8, 0, 8, 2, R("steel")[3])
	cv.px(8, 0, L.c("ff5a4a"))
	# drill arm
	L.thick(cv, [Vector2(11.5, 9.5), Vector2(14.5, 9.5)], 0.8, R("steel")[3])
	cv.px(15, 9, R("steel")[4])
	cv.outline(L.OUTLINE)
	return cv

func crown16() -> PX.Canvas:
	var cv := I.icon()
	var g := R("gold")
	cv.polygon(PackedVector2Array([Vector2(2, 5), Vector2(5, 9), Vector2(8, 3), Vector2(11, 9), Vector2(14, 5), Vector2(13, 13), Vector2(3, 13)]), g[2])
	L.autoshade(cv, [g], 2)
	cv.fill_rect(3, 11, 10, 2, g[1])
	cv.px(5, 11, R("ruby")[3])
	cv.px(8, 11, R("sapphire")[3])
	cv.px(11, 11, R("emerald")[3])
	cv.outline(L.OUTLINE)
	I.star4(cv, 8, 2, Color.WHITE)
	return cv

func charm16() -> PX.Canvas:
	var cv := I.icon()
	cv.line(3, 1, 8, 6, R("gold")[3])
	cv.line(13, 1, 8, 6, R("gold")[3])
	var gem := I.gem_cut(R("ruby"), "heart")
	var sm := gem.img.duplicate() as Image
	sm.resize(10, 10, Image.INTERPOLATE_NEAREST)
	cv.blit(sm, 3, 6)
	I.star4(cv, 12, 8, Color.WHITE)
	return cv

func equip_icon(i: int) -> PX.Canvas:
	match i:
		0: return I.pickaxe16(L.r5("2e1e14", "4e3424", "7a5440", "9e7258", "c09478"), R("wood"))
		1: return I.pickaxe16(L.r5("5a2008", "9a4418", "d8742e", "f8a050", "ffd090"), R("wood"))
		2: return I.pickaxe16(L.r5("1e2028", "3a3e4a", "5e6472", "8a92a2", "c0c8d6"), R("darkwood"))
		3: return I.pickaxe16(L.r5("2a3a54", "4e6488", "7a94b8", "b0c8e4", "eef6ff"), L.r5("2a1a12", "4a2a1a", "6a3a24", "8a5034", "aa6a44"))
		4: return I.pickaxe16(L.r5("2a1060", "4a2aa8", "6a5aff", "8ab8ff", "c8f4ff"), R("steel"), Color(0.5, 0.7, 1.0, 0.6))
		5: return drill16(R("gold"), L.r5("0a4a6a", "1a90c0", "5ae0f8", "b0f8ff", "ffffff"), true)
		6: return I.pickaxe16(L.r5("3a0a6a", "6a1ab0", "a64cff", "d8a0ff", "ffffff"), L.r5("0e1020", "1e2238", "343a58", "565e84", "8a92b8"), Color(0.75, 0.45, 1.0, 0.7))
		7: return drill16(L.r5("5a1a08", "a83a10", "ff6a1f", "ff9a4a", "ffc890"), R("steel"))
		8: return drill16(R("purple"), R("silver"), true)
		9: return backpack16(R("leather"), R("darkwood"), 0)
		10: return backpack16(R("canvas"), R("leather"), 1)
		11: return backpack16(R("wood"), R("gold"), 1, R("red"))
		12: return backpack16(R("green"), R("leather"), 2, R("red"))
		13: return lantern16(R("iron"), R("flame"), Color(1, 0.6, 0.2, 0.55))
		14: return lantern16(R("gold"), R("flame"), Color(1, 0.8, 0.3, 0.7))
		15: return lantern16(R("silver"), R("cyan"), Color(0.5, 0.95, 1, 0.7))
		16: return lantern16(R("gold"), L.r5("b08a20", "f0d040", "fff080", "fffbd0", "ffffff"), Color(1, 0.95, 0.6, 0.85), true)
		17: return scanner16(R("blue"), false)
		18: return scanner16(R("emerald"), true)
		19: return boots16(R("leather"), R("darkwood"))
		20: return boots16(L.r5("2a3040", "4a5470", "6a7a9c", "98a8c8", "c8d4ec"), R("coal"), L.c("c3cad8"))
		21: return boots16(R("red"), R("coal"), R("flame")[3], Color(1, 0.5, 0.1, 0.4))
		22: return boots16(R("purple"), R("steel"), R("cyan")[3], Color(0.5, 0.9, 1, 0.5))
		23: return m_smelter()
		24: return m_crusher()
		25: return m_drill_rig(false)
		26: return m_adv_smelter()
		27: return m_polisher()
		28: return m_extractor()
		29: return m_drill_rig(true)
		30: return m_sorter()
		31: return m_robot()
		32: return crown16()
		33:
			var a := lantern16(R("silver"), R("emerald"), Color(0.5, 1, 0.7, 0.6))
			L.glow(a, Color(0.8, 0.5, 1, 0.5), 2)
			return a
		34: return charm16()
		35:
			var gp := I.pickaxe16(R("gold"), R("gold"), Color(1, 0.85, 0.3, 0.6))
			I.star4(gp, 13, 9, Color.WHITE)
			return gp
	var cv := I.icon()
	cv.fill_rect(2, 2, 12, 12, Color.MAGENTA)
	return cv

func _init() -> void:
	var sheet := Image.create(256, 48, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in 36:
		var cv := equip_icon(i)
		sheet.blit_rect(cv.img, Rect2i(0, 0, 16, 16), Vector2i((i % 16) * 16, (i / 16) * 16))
	L.save(sheet, "sprites/items/equipment.png")
	L.preview(sheet, "ch_equipment.png", 5, Vector2i(16, 16))
	quit()
