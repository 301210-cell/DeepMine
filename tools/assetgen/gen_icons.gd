## Generates items.png (resource icons) — index = "icon" in data/resources/resources.json
extends SceneTree
const PX = preload("res://px.gd")
const L = preload("res://chlib.gd")
const I = preload("res://ch_iconlib.gd")

func R(n: String) -> Array:
	return I.R(n)

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# ------------------------------------------------------------------ rocks
func rock_icon(ramp: Array, seed: int, extra: String = "") -> PX.Canvas:
	var cv := I.icon()
	I.lump(cv, ramp, 8.0, 9.0, 6.6, 5.4, seed)
	L.autoshade(cv, [ramp], 2)
	I.speckle(cv, ramp, seed, 0.1, 0.05)
	match extra:
		"rust":
			for p in [V(5, 8), V(9, 10), V(11, 7)]:
				cv.px(p.x, p.y, R("rust")[2])
				cv.px(p.x + 1, p.y, R("rust")[1])
		"sparkle":
			for p in [V(5, 7), V(10, 9), V(8, 12), V(11, 6)]:
				cv.px(p.x, p.y, R("cyan")[3])
		"frost":
			for x in range(3, 13):
				var top := -1
				for y in 16:
					if cv.get_px(x, y).a > 0.5:
						top = y
						break
				if top >= 0:
					cv.px(x, top, Color.WHITE)
					if PX.hash01(x, 2, seed) > 0.4:
						cv.px(x, top + 1, R("frost")[4])
		"lava":
			var cr := R("magma")
			cv.line(5, 9, 7, 11, cr[3])
			cv.line(7, 11, 10, 10, cr[2])
			cv.line(10, 10, 11, 8, cr[3])
			cv.px(6, 6, cr[2])
	cv.outline(L.OUTLINE)
	return cv

func ice_chunk() -> PX.Canvas:
	var cv := I.icon()
	var f := R("frost")
	var top := PackedVector2Array([Vector2(8, 2), Vector2(14, 5), Vector2(8, 8), Vector2(2, 5)])
	var left := PackedVector2Array([Vector2(2, 5), Vector2(8, 8), Vector2(8, 15), Vector2(2, 12)])
	var right := PackedVector2Array([Vector2(8, 8), Vector2(14, 5), Vector2(14, 12), Vector2(8, 15)])
	cv.polygon(left, f[2])
	cv.polygon(right, f[1])
	cv.polygon(top, f[3])
	cv.line(4, 6, 6, 6, Color.WHITE)
	cv.line(3, 8, 3, 10, f[4])
	cv.px(11, 9, f[2])
	cv.px(10, 11, f[2])
	cv.outline(L.OUTLINE)
	return cv

func ancient_rubble() -> PX.Canvas:
	var cv := I.icon()
	var s := R("sand")
	var p := PackedVector2Array([Vector2(2, 5), Vector2(11, 3), Vector2(14, 6), Vector2(13, 13), Vector2(3, 14), Vector2(1, 9)])
	cv.polygon(p, s[2])
	L.autoshade(cv, [s], 2)
	# carved glyph groove
	var g := R("teal")
	cv.line(5, 7, 10, 7, g[1])
	cv.line(7, 7, 7, 11, g[1])
	cv.line(5, 11, 10, 11, g[1])
	cv.px(10, 9, g[3])
	cv.outline(L.OUTLINE)
	return cv

# ------------------------------------------------------------------ ores
func coal_icon() -> PX.Canvas:
	var cv := I.icon()
	var c := R("coal")
	I.lump(cv, c, 6.0, 9.5, 4.4, 4.0, 3)
	I.lump(cv, c, 10.5, 10.0, 4.2, 3.6, 8)
	I.lump(cv, c, 8.5, 6.0, 3.4, 3.0, 13)
	L.autoshade(cv, [c], 2)
	for p in [V(5, 7), V(9, 4), V(11, 8), V(7, 11)]:
		cv.px(p.x, p.y, c[4])
	cv.outline(L.OUTLINE)
	return cv

func ancient_gold_icon() -> PX.Canvas:
	var cv := I.icon()
	var g := R("gold")
	var p := PackedVector2Array([Vector2(3, 6), Vector2(8, 2), Vector2(13, 5), Vector2(14, 11), Vector2(9, 14), Vector2(3, 12)])
	I.facet_poly(cv, p, g, Vector2(8, 8), 6)
	var t := R("glyph")
	cv.line(6, 6, 6, 10, t[2])
	cv.line(6, 8, 10, 8, t[2])
	cv.px(10, 6, t[3])
	cv.px(10, 10, t[3])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.4, 1, 0.95, 0.5), 1)
	return cv

func meteorite_icon() -> PX.Canvas:
	var cv := I.icon()
	var r := R("darkrock")
	I.lump(cv, r, 8.0, 8.6, 6.4, 5.8, 21, 0.25, false)
	L.autoshade(cv, [r], 2)
	# craters
	for p in [V(5, 6), V(10, 9), V(7, 11)]:
		cv.px(p.x, p.y, r[0])
		cv.px(p.x + 1, p.y, r[1])
		cv.px(p.x, p.y - 1, r[3])
	var m := R("cyan")
	cv.line(4, 9, 7, 8, m[2])
	cv.line(7, 8, 9, 5, m[3])
	cv.line(9, 11, 12, 10, R("magma")[3])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.5, 0.9, 1.0, 0.45), 1)
	return cv

func obsidian_icon() -> PX.Canvas:
	var cv := I.icon()
	var o := R("obsidian")
	var p := PackedVector2Array([Vector2(7, 1), Vector2(12, 5), Vector2(14, 12), Vector2(9, 15), Vector2(3, 13), Vector2(2, 7)])
	I.facet_poly(cv, p, o, Vector2(8, 8), 6)
	cv.line(6, 3, 4, 8, o[4])
	cv.px(11, 6, o[4])
	cv.outline(L.OUTLINE)
	return cv

func emberstone_icon() -> PX.Canvas:
	var cv := I.icon()
	var e := R("ember")
	cv.circle(8, 8.5, 5.6, e[2])
	L.autoshade(cv, [e], 2)
	cv.circle(7.5, 8.0, 2.6, e[3])
	cv.circle(7.0, 7.5, 1.3, e[4])
	cv.px(10, 11, e[1])
	cv.px(4, 10, e[1])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(1.0, 0.55, 0.1, 0.7), 2)
	return cv

func relic_icon() -> PX.Canvas:
	var cv := I.icon()
	var b := R("bronze")
	var p := PackedVector2Array([Vector2(2, 4), Vector2(9, 2), Vector2(14, 6), Vector2(12, 13), Vector2(5, 14), Vector2(2, 10)])
	cv.polygon(p, b[2])
	L.autoshade(cv, [b], 2)
	# rivets and slot
	cv.px(4, 5, b[4])
	cv.px(12, 7, b[4])
	cv.px(5, 12, b[4])
	cv.fill_rect(6, 7, 5, 3, L.c("0a1a2a"))
	cv.fill_rect(7, 8, 3, 1, R("glyph")[2])
	cv.px(8, 8, Color.WHITE)
	cv.outline(L.OUTLINE)
	return cv

func prototype_icon() -> PX.Canvas:
	var cv := I.icon()
	var c := R("cyan")
	var s := R("steel")
	var top := PackedVector2Array([Vector2(8, 1.5), Vector2(14, 4.5), Vector2(8, 7.5), Vector2(2, 4.5)])
	var left := PackedVector2Array([Vector2(2, 4.5), Vector2(8, 7.5), Vector2(8, 14.5), Vector2(2, 11.5)])
	var right := PackedVector2Array([Vector2(8, 7.5), Vector2(14, 4.5), Vector2(14, 11.5), Vector2(8, 14.5)])
	cv.polygon(left, s[2])
	cv.polygon(right, s[1])
	cv.polygon(top, s[3])
	# circuitry
	cv.line(4, 7, 4, 10, c[2])
	cv.line(4, 10, 6, 11, c[2])
	cv.line(10, 9, 12, 8, c[3])
	cv.line(10, 9, 10, 12, c[2])
	cv.px(8, 4, c[4])
	cv.px(7, 4, c[3])
	cv.px(9, 4, c[3])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.4, 0.95, 1.0, 0.5), 1)
	return cv

func ancient_shard_icon() -> PX.Canvas:
	var cv := I.icon()
	var t := R("teal")
	I.crystal(cv, 8, 15, 13, 3.2, 1.5, t)
	cv.outline(L.OUTLINE)
	var g := R("glyph")
	cv.px(7, 8, g[4])
	cv.px(7, 9, g[3])
	cv.px(8, 10, g[3])
	cv.px(7, 11, g[3])
	L.glow(cv, Color(0.3, 1, 0.9, 0.5), 1)
	return cv

func emberish_magma_crystal() -> PX.Canvas:
	var m := R("magma")
	var cv := I.crystal_cluster(m, [[5, 14, 8, 2.2, -1.0], [11, 14, 9, 2.2, 1.0], [8, 15, 13, 2.8, 0.0]], R("volcrock"), Color(1.0, 0.45, 0.1, 0.6))
	return cv

func star_crystal_icon() -> PX.Canvas:
	var s := R("star")
	var cv := I.crystal_cluster(s, [[4, 14, 7, 2.0, -1.5], [12, 14, 8, 2.0, 1.5], [8, 15, 13, 2.8, 0.0]], null, Color(1.0, 0.95, 0.6, 0.7))
	I.big_star(cv, 13, 3, Color.WHITE)
	I.star4(cv, 3, 6, Color(1, 1, 0.8))
	return cv

# ------------------------------------------------------------------ fossils & artifacts
func fern_fossil() -> PX.Canvas:
	var cv := I.slab(R("stone2"))
	var d: Color = R("stone2")[0]
	cv.line(5, 13, 10, 3, d)
	for i in range(0, 5):
		var y := 11 - i * 2
		var x := 6 + i
		cv.line(x, y, x - 3, y - 1, d)
		cv.line(x, y, x + 3, y + 0, d)
	cv.outline(L.OUTLINE)
	return cv

func trilobite_fossil() -> PX.Canvas:
	var cv := I.icon()
	var b := R("sand")
	cv.ellipse(8, 8.5, 5.2, 6.6, b[2])
	L.autoshade(cv, [b], 2)
	# head shield
	for x in range(4, 13):
		cv.px(x, 5, b[1])
	# segments
	for y in range(7, 14, 2):
		for x in range(4, 13):
			if cv.get_px(x, y).a > 0.5:
				cv.px(x, y, b[1])
	# axial lobe
	for y in range(3, 15):
		if cv.get_px(8, y).a > 0.5:
			cv.px(8, y, b[3])
	cv.px(6, 4, L.c("2a1a10"))
	cv.px(10, 4, L.c("2a1a10"))
	cv.outline(L.OUTLINE)
	return cv

func ammonite_fossil() -> PX.Canvas:
	var cv := I.icon()
	var b := R("bronze")
	cv.circle(8, 8.5, 6.4, b[2])
	L.autoshade(cv, [b], 2)
	# spiral
	var prev := Vector2(8, 8.5)
	for i in range(0, 60):
		var t := float(i) / 59.0
		var a := t * TAU * 2.2
		var r := 0.6 + t * 5.4
		var p := Vector2(8 + cos(a) * r, 8.5 + sin(a) * r)
		cv.line(int(prev.x), int(prev.y), int(p.x), int(p.y), b[0])
		prev = p
	cv.px(5, 5, b[4])
	cv.px(6, 4, b[4])
	cv.outline(L.OUTLINE)
	return cv

func skull_fossil() -> PX.Canvas:
	var cv := I.icon()
	var b := R("bone")
	# cranium + snout (side view facing right) and a horn
	cv.ellipse(6.5, 7, 4.8, 4.4, b[2])
	cv.fill_rect(8, 7, 7, 4, b[2])
	cv.fill_rect(3, 9, 8, 4, b[2])
	L.thick(cv, [Vector2(5, 3), Vector2(3, 1)], 0.8, b[2])
	L.autoshade(cv, [b], 2)
	# eye socket, nostril, teeth
	cv.fill_rect(6, 6, 3, 2, L.c("2a1a10"))
	cv.px(13, 8, L.c("2a1a10"))
	for x in [9, 11, 13]:
		cv.px(x, 11, b[4])
		cv.px(x, 12, b[1])
	cv.line(8, 11, 14, 11, b[0])
	cv.outline(L.OUTLINE)
	return cv

func idol_artifact() -> PX.Canvas:
	var cv := I.icon()
	var g := R("gold")
	var p := R("amethyst")
	cv.fill_rect(4, 12, 8, 3, g[2])
	cv.ellipse(8, 5, 2.6, 2.8, p[2])
	cv.fill_rect(6, 7, 4, 5, p[2])
	cv.fill_rect(5, 8, 1, 3, p[2])
	cv.fill_rect(10, 8, 1, 3, p[2])
	L.autoshade(cv, [g, p], 2)
	cv.px(7, 5, Color.WHITE)
	cv.px(9, 5, L.c("5ff2ff"))
	cv.px(7, 5, L.c("5ff2ff"))
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.7, 0.5, 1.0, 0.5), 1)
	return cv

func gear_artifact() -> PX.Canvas:
	var cv := I.icon()
	var b := R("bronze")
	for i in 8:
		var a := i * TAU / 8.0
		var p := Vector2(8 + cos(a) * 6.0, 8 + sin(a) * 6.0)
		L.disc(cv, p.x, p.y, 1.4, b[2])
	cv.circle(8, 8, 5.0, b[2])
	L.autoshade(cv, [b], 2)
	cv.circle(8, 8, 2.2, L.c("0a1a2a"))
	cv.circle(8, 8, 1.2, R("glyph")[2])
	cv.px(8, 8, Color.WHITE)
	cv.outline(L.OUTLINE)
	return cv

func tablet_artifact() -> PX.Canvas:
	var cv := I.icon()
	var s := R("darkrock")
	cv.fill_rect(3, 5, 10, 10, s[2])
	cv.ellipse(8, 5, 5, 3.5, s[2])
	L.autoshade(cv, [s], 2)
	var g := R("glyph")
	cv.line(5, 5, 7, 5, g[2])
	cv.line(9, 4, 11, 6, g[2])
	cv.line(5, 8, 5, 10, g[2])
	cv.line(6, 9, 8, 9, g[3])
	cv.line(10, 8, 10, 12, g[2])
	cv.line(5, 12, 8, 12, g[2])
	cv.px(8, 10, g[4])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.3, 1.0, 1.0, 0.5), 1)
	return cv

func core_artifact() -> PX.Canvas:
	var cv := I.icon()
	var s := R("steel")
	var c := R("cyan")
	cv.circle(8, 8, 6.4, s[2])
	L.autoshade(cv, [s], 2)
	cv.circle(8, 8, 4.0, c[1])
	cv.circle(7.5, 7.5, 2.8, c[2])
	cv.circle(7, 7, 1.5, c[4])
	# brackets
	cv.fill_rect(1, 7, 2, 2, s[3])
	cv.fill_rect(13, 7, 2, 2, s[1])
	cv.fill_rect(7, 1, 2, 2, s[3])
	cv.fill_rect(7, 13, 2, 2, s[1])
	cv.outline(L.OUTLINE)
	L.glow(cv, Color(0.4, 0.95, 1, 0.6), 2)
	return cv

# ------------------------------------------------------------------ processed & consumables
func pile_icon(ramp: Array, sparkle: bool) -> PX.Canvas:
	var cv := I.icon()
	var pts := [V(3, 12), V(6, 12), V(9, 12), V(12, 12), V(4, 10), V(7, 10), V(10, 10), V(6, 8), V(9, 8), V(7, 6)]
	var i := 0
	for p in pts:
		var rr := 1.6 + PX.hash01(i, 2, 7) * 0.6
		L.disc(cv, p.x + 0.5, p.y + 0.5, rr, ramp[2])
		i += 1
	L.autoshade(cv, [ramp], 2)
	I.speckle(cv, ramp, 11, 0.2, 0.15)
	cv.outline(L.OUTLINE)
	if sparkle:
		for p in [V(5, 9), V(9, 6), V(11, 11), V(7, 12)]:
			cv.px(p.x, p.y, Color.WHITE)
		L.glow(cv, Color(0.5, 0.9, 1.0, 0.4), 1)
	return cv

func ladder_icon() -> PX.Canvas:
	var cv := I.icon()
	var w := R("wood")
	cv.fill_rect(4, 1, 2, 15, w[2])
	cv.fill_rect(10, 1, 2, 15, w[2])
	for y in [3, 7, 11]:
		cv.fill_rect(6, y, 4, 2, w[2])
	L.autoshade(cv, [w], 2)
	cv.outline(L.OUTLINE)
	return cv

func dynamite_icon() -> PX.Canvas:
	var cv := I.icon()
	var r := R("red")
	for k in 3:
		var ox := 3 + k * 3
		cv.fill_rect(ox, 6, 3, 9, r[2])
	L.autoshade(cv, [r], 2)
	cv.fill_rect(3, 9, 9, 2, R("canvas")[2])
	cv.fill_rect(3, 10, 9, 1, R("canvas")[1])
	for k in 3:
		cv.px(4 + k * 3, 6, r[4])
	cv.outline(L.OUTLINE)
	# fuse + spark
	cv.line(7, 5, 9, 2, L.c("3a2a1a"))
	L.sparkle(cv, 10, 1, L.c("fff060"), 1)
	cv.px(10, 1, Color.WHITE)
	return cv

func torch_icon() -> PX.Canvas:
	var cv := I.icon()
	var w := R("wood")
	L.thick(cv, [Vector2(6.5, 14.5), Vector2(9.5, 7.5)], 1.0, w[2])
	L.autoshade(cv, [w], 2)
	cv.fill_rect(8, 6, 3, 2, R("leather")[1])
	cv.outline(L.OUTLINE)
	var f := I.icon()
	var fl := R("flame")
	f.ellipse(10, 3.5, 2.6, 3.4, fl[2])
	L.autoshade(f, [fl], 2)
	f.px(10, 4, fl[4])
	f.px(10, 3, fl[4])
	f.outline(L.c("8a2a04"))
	cv.blit(f.img, 0, 0)
	return cv

func potion_icon() -> PX.Canvas:
	var cv := I.vial(R("red"), Color(1.0, 0.86, 0.86))
	cv.px(8, 11, L.c("ffd0d0"))
	return cv

func flare_icon() -> PX.Canvas:
	var cv := I.icon()
	var r := R("red")
	L.thick(cv, [Vector2(4.5, 14.0), Vector2(10.0, 6.5)], 1.4, r[2])
	L.autoshade(cv, [r], 2)
	cv.line(5, 12, 7, 10, Color.WHITE)
	cv.outline(L.OUTLINE)
	var f := I.icon()
	f.circle(11.5, 4.5, 2.6, R("pink")[2])
	L.autoshade(f, [R("pink")], 2)
	f.px(11, 4, Color.WHITE)
	f.outline(L.c("a83a7a"))
	cv.blit(f.img, 0, 0)
	L.glow(cv, Color(1, 0.5, 0.8, 0.45), 1)
	return cv

func polished(ramp: Array, cut: String, legendary: bool = false) -> PX.Canvas:
	var cv := I.gem_cut(ramp, cut)
	I.big_star(cv, 12, 3, Color.WHITE)
	cv.px(6, 6, Color.WHITE)
	if legendary:
		L.glow(cv, Color(1, 1, 1, 0.5), 1)
		I.star4(cv, 3, 12, Color(1, 1, 0.85))
	return cv

func opal_rough() -> PX.Canvas:
	var cv := I.icon()
	var o := R("opal")
	cv.ellipse(8, 8.5, 6, 5.4, o[2])
	L.autoshade(cv, [o], 2)
	var flecks := [["ff6a8a", V(5, 7)], ["6af0a0", V(9, 6)], ["6aa8ff", V(10, 10)], ["ffd06a", V(6, 11)], ["c08aff", V(8, 9)]]
	for f in flecks:
		cv.px(f[1].x, f[1].y, L.c(f[0]))
		cv.px(f[1].x + 1, f[1].y, L.c(f[0]).lerp(o[3], 0.4))
	cv.px(5, 5, Color.WHITE)
	cv.outline(L.OUTLINE)
	I.star4(cv, 13, 3, Color.WHITE)
	return cv

func opal_polished() -> PX.Canvas:
	var cv := opal_rough()
	I.big_star(cv, 3, 12, Color.WHITE)
	return cv

# ------------------------------------------------------------------ dispatcher
func item_icon(id: String) -> PX.Canvas:
	match id:
		"stone": return rock_icon(R("rock"), 1)
		"dark_stone": return rock_icon(R("darkrock"), 2, "rust")
		"crystalline_stone": return rock_icon(R("navyrock"), 3, "sparkle")
		"frostrock": return rock_icon(R("frostrock"), 4, "frost")
		"ice_chunk": return ice_chunk()
		"volcanic_rock": return rock_icon(R("volcrock"), 6, "lava")
		"ancient_rubble": return ancient_rubble()
		"coal": return coal_icon()
		"copper_ore": return I.ore_lump(L.r5("4a1a08", "8a3a14", "c8642a", "ea8a44", "ffc080"), 11)
		"quartz": return I.crystal_cluster(L.r5("6a7a90", "aab8cc", "dce6f2", "ffffff", "ffffff"), [[5, 14, 8, 2.0, -1.0], [11, 14, 9, 2.0, 1.2], [8, 15, 13, 2.6, 0.0]], R("rock"))
		"iron_ore": return I.ore_lump(L.r5("2a2e3c", "4a5062", "6e7488", "9aa0b4", "c8ccda"), 13)
		"silver_ore": return I.ore_lump(L.r5("5a6274", "8a94a8", "bcc4d4", "e4e8f2", "ffffff"), 14, true)
		"gold_ore": return I.ore_lump(R("gold"), 15, true)
		"amethyst": return I.gem_cluster(R("amethyst"))
		"sapphire": return I.gem_cluster(R("sapphire"))
		"emerald": return I.gem_cluster(R("emerald"))
		"ruby": return I.gem_cluster(R("ruby"))
		"topaz": return I.gem_cluster(R("topaz"))
		"opal": return opal_v2()
		"diamond":
			var d := I.diamond_profile(L.r5("0a5a7a", "1aa0c8", "5ae0f8", "b0f8ff", "ffffff"))
			L.glow(d, Color(1, 1, 1, 0.45), 1)
			return d
		"crystal_shard": return I.crystal_cluster(R("shard"), [[5, 14, 8, 2.0, -1.5], [11, 14, 7, 1.8, 1.5], [8, 15, 13, 2.6, 0.5]], null, Color(0.4, 0.8, 1.0, 0.55))
		"frost_crystal": return I.crystal_cluster(R("frost"), [[4, 15, 9, 2.0, -2.0], [12, 15, 10, 2.0, 2.0], [8, 15, 14, 2.6, 0.0]], null, Color(0.8, 0.95, 1.0, 0.6))
		"frozen_iron": return frozen_iron_icon()
		"blue_sapphire":
			var bs := I.orb(R("bluesap"), 6.0)
			I.star4(bs, 13, 3, Color.WHITE)
			return bs
		"obsidian": return I.orb(L.r5("05040a", "100c1c", "1e1830", "3a2c5a", "8a6ac8"))
		"volcanic_iron": return volcanic_iron_icon()
		"magma_crystal": return magma_v2()
		"emberstone": return emberstone_icon()
		"ancient_shard": return ancient_shard_icon()
		"relic_fragment": return relic_v2()
		"star_crystal": return star_crystal_v2()
		"ancient_gold": return ancient_gold_v2()
		"prototype_mineral": return prototype_icon()
		"meteorite_ore": return meteorite_v2()
		"geode_small": return I.geode(R("rock"), R("shard"), 1)
		"geode_iron": return I.geode(R("rust"), R("silver"), 2)
		"geode_rare": return I.geode(R("navyrock"), R("amethyst"), 3)
		"geode_ice": return I.geode(R("frostrock"), R("frost"), 4)
		"geode_magma": return I.geode(R("volcrock"), R("magma"), 5)
		"geode_legendary":
			var gl := I.geode(R("gold"), R("star"), 6)
			L.glow(gl, Color(1, 0.9, 0.4, 0.6), 1)
			I.star4(gl, 13, 2, Color.WHITE)
			return gl
		"fossil_fern": return fern_fossil()
		"fossil_trilobite": return trilobite_fossil()
		"fossil_ammonite": return ammonite_fossil()
		"fossil_skull": return skull_fossil()
		"artifact_idol": return idol_v2()
		"artifact_gear": return gear_artifact()
		"artifact_tablet": return tablet_artifact()
		"artifact_core": return core_artifact()
		"copper_bar": return I.ingot(R("copper"))
		"iron_bar": return I.ingot(R("iron"))
		"silver_bar": return I.ingot(R("silver"))
		"gold_bar": return I.ingot(R("gold"))
		"frozen_iron_bar":
			var fb := I.ingot(R("frost"))
			fb.px(12, 6, Color.WHITE)
			return fb
		"volcanic_iron_bar":
			var vb := I.ingot(L.r5("1a0a0a", "3a1a16", "5a2a22", "8a4030", "ff8a3a"))
			vb.line(5, 10, 9, 9, R("magma")[3])
			return vb
		"ancient_gold_bar":
			var ab := I.ingot(R("gold"))
			ab.line(7, 9, 10, 9, R("glyph")[2])
			L.glow(ab, Color(1, 0.9, 0.4, 0.55), 1)
			I.star4(ab, 13, 3, Color.WHITE)
			return ab
		"gravel": return pile_icon(R("rock"), false)
		"crystal_dust": return pile_icon(R("shard"), true)
		"polished_amethyst": return polished(R("amethyst"), "oval")
		"polished_sapphire": return polished(R("sapphire"), "round")
		"polished_emerald": return polished(R("emerald"), "emerald")
		"polished_ruby": return polished(R("ruby"), "heart")
		"polished_topaz": return polished(R("topaz"), "pear")
		"polished_opal": return opal_polished()
		"polished_blue_sapphire": return polished(R("bluesap"), "cushion")
		"polished_diamond": return polished_diamond_v2()
		"crystal_essence": return I.vial(R("shard"))
		"frost_essence": return I.vial(R("frost"))
		"magma_essence": return I.vial(R("magma"), Color(1.0, 0.9, 0.8))
		"star_essence":
			var se := I.vial(R("star"), Color(1.0, 0.98, 0.85))
			I.big_star(se, 12, 3, Color.WHITE)
			return se
		"ladder": return ladder_icon()
		"dynamite": return dynamite_v2()
		"torch": return torch_icon()
		"health_potion": return potion_icon()
		"recall_flare": return flare_icon()
		"polished_quartz": return polished(L.r5("4a5a70", "8a9ab0", "c4d0e0", "eef4ff", "ffffff"), "emerald")
	push_warning("no icon for " + id)
	var cv := I.icon()
	cv.fill_rect(2, 2, 12, 12, Color.MAGENTA)
	return cv

func _init() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../../data/resources/resources.json"), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var items: Array = data["items"]
	var maxi_icon := 0
	for it in items:
		maxi_icon = maxi(maxi_icon, int(it["icon"]))
	var rows := int(ceil((maxi_icon + 1) / 16.0))
	var sheet := Image.create(256, rows * 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for it in items:
		var idx := int(it["icon"])
		var cv := item_icon(it["id"])
		sheet.blit_rect(cv.img, Rect2i(0, 0, 16, 16), Vector2i((idx % 16) * 16, (idx / 16) * 16))
	L.save(sheet, "sprites/items/items.png")
	L.preview(sheet, "ch_items.png", 5, Vector2i(16, 16))
	quit()

# ------------------------------------------------------------------ reference-matched variants
func frozen_iron_icon() -> PX.Canvas:
	var cv := I.ore_lump(L.r5("2a3a52", "4a6688", "7a9ac0", "b4d4f0", "f0faff"), 22)
	for p in [V(6, 8), V(10, 10)]:
		cv.px(p.x, p.y, R("rust")[2])
		cv.px(p.x + 1, p.y, R("rust")[1])
	cv.px(5, 5, Color.WHITE)
	cv.px(9, 4, Color.WHITE)
	return cv

func volcanic_iron_icon() -> PX.Canvas:
	var cv := I.ore_lump(L.r5("1a0a0a", "3a1a16", "5a2c26", "844238", "b06050"), 25)
	var m := R("magma")
	cv.line(5, 10, 7, 8, m[3])
	cv.line(7, 8, 10, 9, m[2])
	cv.line(10, 9, 11, 12, m[3])
	L.glow(cv, Color(1, 0.4, 0.1, 0.45), 1)
	return cv

func meteorite_v2() -> PX.Canvas:
	var cv := I.ore_lump(L.r5("1a1412", "322620", "4e3c30", "6e5644", "927660"), 31)
	for p in [V(5, 7), V(10, 9), V(7, 11)]:
		cv.px(p.x, p.y, L.c("1a1412"))
		cv.px(p.x - 1, p.y - 1, L.c("927660"))
	cv.line(8, 6, 10, 5, R("magma")[3])
	return cv

func ancient_gold_v2() -> PX.Canvas:
	var cv := I.ore_lump(L.r5("5a4418", "8a7034", "b8a060", "d8c48a", "f4e8b8"), 28)
	var g := R("gold")
	for p in [V(5, 8), V(9, 6), V(10, 11), V(6, 11)]:
		cv.px(p.x, p.y, g[3])
		cv.px(p.x + 1, p.y, g[2])
	cv.px(8, 9, R("glyph")[3])
	cv.px(8, 8, R("glyph")[2])
	return cv

func star_crystal_v2() -> PX.Canvas:
	var s := L.r5("0a2a7a", "2a5ad0", "5a9aff", "a8d8ff", "ffffff")
	var cv := I.crystal_cluster(s, [[4, 15, 8, 2.0, -1.5], [12, 15, 9, 2.0, 1.5], [8, 15, 14, 2.8, 0.0]], null, Color(0.6, 0.8, 1.0, 0.65))
	I.big_star(cv, 13, 3, L.c("fff6b0"))
	I.star4(cv, 3, 5, Color.WHITE)
	return cv

func relic_v2() -> PX.Canvas:
	# ornate bronze wheel (reference "Relic")
	var cv := I.icon()
	var b := R("bronze")
	cv.circle(8, 8, 6.6, b[2])
	L.autoshade(cv, [b], 2)
	cv.circle(8, 8, 4.0, b[1])
	for i in 6:
		var a := i * TAU / 6.0
		cv.line(8, 8, int(round(8 + cos(a) * 5.2)), int(round(8 + sin(a) * 5.2)), b[3])
	cv.circle(8, 8, 1.6, L.c("6a3aa8"))
	cv.px(8, 8, L.c("d0b0ff"))
	for i in 6:
		var a2 := PI / 6.0 + i * TAU / 6.0
		cv.px(int(round(8 + cos(a2) * 6.0)), int(round(8 + sin(a2) * 6.0)), b[4])
	cv.outline(L.OUTLINE)
	return cv

func idol_v2() -> PX.Canvas:
	# golden idol figure (reference "Artifact")
	var cv := I.icon()
	var g := R("gold")
	cv.circle(8, 4, 2.6, g[2])
	cv.fill_rect(6, 6, 5, 6, g[2])
	cv.fill_rect(4, 7, 2, 3, g[2])
	cv.fill_rect(11, 7, 2, 3, g[2])
	cv.fill_rect(5, 12, 7, 3, g[2])
	L.autoshade(cv, [g], 2)
	cv.px(7, 4, L.c("3a1a08"))
	cv.px(9, 4, L.c("3a1a08"))
	cv.px(8, 8, R("amethyst")[3])
	cv.px(8, 9, R("amethyst")[2])
	cv.fill_rect(5, 13, 7, 1, g[1])
	cv.outline(L.OUTLINE)
	I.star4(cv, 13, 3, Color.WHITE)
	return cv

func magma_v2() -> PX.Canvas:
	var m := L.r5("5a0a04", "a8240a", "e8501a", "ff8a3a", "ffd070")
	return I.crystal_cluster(m, [[5, 14, 8, 2.2, -1.0], [11, 14, 9, 2.2, 1.0], [8, 15, 13, 2.8, 0.0]], R("volcrock"), Color(1.0, 0.45, 0.1, 0.6))

func opal_v2() -> PX.Canvas:
	var cv := I.icon()
	cv.circle(8, 8.5, 6.2, Color.WHITE)
	var cols := ["8a6ad8", "6a8ae8", "d87ac8", "7ad8e0", "a890f0"]
	for y in 16:
		for x in 16:
			if cv.get_px(x, y).a < 0.5:
				continue
			var n := PX.vnoise(x * 1.0, y * 1.0, 3.0, 17)
			var col := L.c(cols[int(n * cols.size()) % cols.size()])
			var dx := x + 0.5 - 8.0
			var dy := y + 0.5 - 8.5
			if dx + dy > 5.0:
				col = col.darkened(0.3)
			elif dx + dy < -5.0:
				col = col.lightened(0.3)
			cv.px(x, y, col)
	cv.px(5, 5, Color.WHITE)
	cv.px(6, 5, Color.WHITE)
	cv.px(5, 6, Color.WHITE)
	cv.outline(L.OUTLINE)
	I.star4(cv, 13, 3, Color.WHITE)
	return cv

func polished_diamond_v2() -> PX.Canvas:
	var cv := I.diamond_profile(L.r5("2a5a8a", "6aa8e0", "c0e8ff", "eef8ff", "ffffff"))
	L.glow(cv, Color(1, 1, 1, 0.5), 1)
	I.star4(cv, 2, 12, Color(1, 1, 0.85))
	return cv

func dynamite_v2() -> PX.Canvas:
	var cv := dynamite_icon()
	var r := R("red")
	for x in [6, 9]:
		for y in range(7, 15):
			if y < 9 or y > 10:
				cv.px(x, y, r[0])
	return cv
