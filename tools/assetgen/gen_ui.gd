## Generates the DeepMine UI kit (9-slice panels, buttons, slots, bars, cursors) and the
## pixel-art skill-tree hex sockets into assets/ui/. Sizes/margins follow ARCHITECTURE.md.
extends SceneTree

const PX = preload("res://px.gd")

const OUTL := "0b0d18"

func C(s: String, a: float = 1.0) -> Color:
	return PX.hex(s, a)

# ------------------------------------------------------------------------------------------------
# Generic bevelled frame: ring index e = inset from the (chamfered) outer edge.
# layers[e] = [light_colour, dark_colour] (light = nearer top/left edges).
# fill: Callable(x, y, w, h) -> Color  or a Color.
# open_bottom: no bottom edge (tabs).
func inset(x: int, y: int, w: int, h: int, cut: int, open_bottom: bool = false) -> int:
	var b := (h - 1 - y) if not open_bottom else 9999
	var e := mini(mini(x, y), mini(w - 1 - x, b))
	e = mini(e, x + y - cut)
	e = mini(e, (w - 1 - x) + y - cut)
	if not open_bottom:
		e = mini(e, x + (h - 1 - y) - cut)
		e = mini(e, (w - 1 - x) + (h - 1 - y) - cut)
	return e

func is_light(x: int, y: int, w: int, h: int, open_bottom: bool = false) -> bool:
	var b := (h - 1 - y) if not open_bottom else 9999
	return mini(x, y) <= mini(w - 1 - x, b)

func frame(c: PX.Canvas, ox: int, oy: int, w: int, h: int, cut: int, layers: Array, fill, open_bottom: bool = false) -> void:
	for y in h:
		for x in w:
			var e := inset(x, y, w, h, cut, open_bottom)
			if e < 0:
				continue
			var col: Color
			if e < layers.size():
				var pair: Array = layers[e]
				col = pair[0] if is_light(x, y, w, h, open_bottom) else pair[1]
			elif fill is Callable:
				col = (fill as Callable).call(x, y, w, h)
			else:
				col = fill
			if col.a > 0.0:
				c.px(ox + x, oy + y, col)

func L(light: String, dark: String = "") -> Array:
	return [C(light), C(dark if dark != "" else light)]

func rivet(c: PX.Canvas, x: int, y: int, hl: String = "e3e9f5", mid: String = "8a93a8", dk: String = "3c4458") -> void:
	c.px(x, y, C(hl))
	c.px(x + 1, y, C(mid))
	c.px(x, y + 1, C(mid))
	c.px(x + 1, y + 1, C(dk))

# ------------------------------------------------------------------------------------------------
func make_panel() -> void:
	var c := PX.Canvas.new(48, 48)
	frame(c, 0, 0, 48, 48, 2, [
		L(OUTL), L("a7b8de", "2a3350"), L("7a8cb6", "3a4668"), L("5f7099", "47557c"),
		L("4c5c86", "4c5c86"), L(OUTL), L("0b1029", "1d2554")], C("141a3a"))
	# subtle shine along the top border
	for x in range(10, 38):
		c.px(x, 1, C("c3d0ee"))
	# reinforced corner plates with a bolt (lighting from top-left)
	for p in [Vector2i(0, 0), Vector2i(38, 0), Vector2i(0, 38), Vector2i(38, 38)]:
		corner_plate(c, p.x, p.y, ["a7b8de", "8fa0c8", "5f7099", "3a4668", "2a3350"])
	c.save("ui/panel.png")

## 10x10 bolted corner plate (outline included). pal = [top, left, face, right, bottom].
func corner_plate(c: PX.Canvas, ox: int, oy: int, pal: Array) -> void:
	for y in 10:
		for x in 10:
			var px_ := ox + x
			var py_ := oy + y
			if c.get_px(px_, py_).a < 0.5:
				continue # keep chamfered corners transparent
			var col: Color
			if x == 0 or y == 0 or x == 9 or y == 9:
				col = C(OUTL)
			elif y == 1:
				col = C(pal[0])
			elif x == 1:
				col = C(pal[1])
			elif y == 8:
				col = C(pal[4])
			elif x == 8:
				col = C(pal[3])
			else:
				col = C(pal[2])
				if x + y <= 5:
					col = col.lightened(0.08)
			c.px(px_, py_, col)
	# bolt
	var bx := ox + 3
	var by := oy + 3
	c.px(bx, by, C("f2f6ff"))
	c.px(bx + 1, by, C("c3cad8"))
	c.px(bx + 2, by, C("8a93a8"))
	c.px(bx, by + 1, C("c3cad8"))
	c.px(bx + 1, by + 1, C("9aa4bc"))
	c.px(bx + 2, by + 1, C("4a5470"))
	c.px(bx, by + 2, C("8a93a8"))
	c.px(bx + 1, by + 2, C("4a5470"))
	c.px(bx + 2, by + 2, C("2a3050"))
	c.px(bx + 3, by + 1, C("1e2440"))
	c.px(bx + 3, by + 2, C("1e2440"))
	c.px(bx + 1, by + 3, C("1e2440"))
	c.px(bx + 2, by + 3, C("1e2440"))

func make_panel_dark() -> void:
	var c := PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 1, [L(OUTL), L("27315a", "3a4777"), L("080b1f", "10153a")], C("10153a"))
	c.save("ui/panel_dark.png")

func make_panel_purple() -> void:
	var c := PX.Canvas.new(48, 48)
	frame(c, 0, 0, 48, 48, 2, [
		L(OUTL), L("c08cf0", "40205f"), L("9258d2", "552a84"), L("7442b4", "62349a"),
		L("5e3296", "5e3296"), L(OUTL), L("100822", "2c1a4e")], C("1a1232"))
	for x in range(10, 38):
		c.px(x, 1, C("d8b0ff"))
	var gold_hl := C("fff1a8")
	var gold := C("ffc93c")
	var gold_dk := C("b07a10")
	# L-shaped gold corner brackets drawn on the border band
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var fx: bool = corner.x == 1
		var fy: bool = corner.y == 1
		for i in range(2, 12):
			for t in range(2, 4):
				var xa: int = i
				var ya: int = t
				var xb: int = t
				var yb: int = i
				var ca := gold if t == 2 else gold_dk
				if t == 2 and i < 5:
					ca = gold_hl
				var px1 := Vector2i(47 - xa if fx else xa, 47 - ya if fy else ya)
				var px2 := Vector2i(47 - xb if fx else xb, 47 - yb if fy else yb)
				c.px(px1.x, px1.y, ca)
				c.px(px2.x, px2.y, ca)
		# diamond stud in the corner
		var sx := 44 if fx else 3
		var sy := 44 if fy else 3
		c.px(sx, sy, gold_hl)
		c.px(sx + (-1 if fx else 1), sy, gold)
		c.px(sx, sy + (-1 if fy else 1), gold)
	c.save("ui/panel_purple.png")

func make_panel_title() -> void:
	var c := PX.Canvas.new(48, 20)
	var grad := func(x: int, y: int, w: int, h: int) -> Color:
		var t := float(y - 2) / float(h - 5)
		var top := C("34589e")
		var bot := C("1b2d6c")
		if y == 2:
			return C("5a80c8")
		return top.lerp(bot, clampf(t, 0.0, 1.0))
	frame(c, 0, 0, 48, 20, 2, [L(OUTL), L("7c9ad6", "142254")], grad)
	# gold pin-stripe along the top
	for x in range(4, 44):
		c.px(x, 3, C("ffc93c", 0.55))
	c.save("ui/panel_title.png")

func make_hud_box() -> void:
	var c := PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 2, [L(OUTL), L("7686b2", "2a3352"), L("4c5a84", "394566"), L(OUTL), L("1b2352", "0f1434")], C("0f1434"))
	c.save("ui/hud_box.png")

# ------------------------------------------------------------------------------------------------
# Buttons: 48x24, glossy face, 3px lip at the bottom.
func button_img(pal: Dictionary, state: String) -> PX.Canvas:
	var w := 48
	var h := 24
	var c := PX.Canvas.new(w, h)
	var pressed := state == "pressed"
	var hover := state == "hover"
	var hl: Color = pal.hl
	var li: Color = pal.light
	var mi: Color = pal.mid
	var dk: Color = pal.dark
	var lip: Color = pal.lip
	var lipd: Color = pal.lipd
	if hover:
		hl = hl.lightened(0.15)
		li = li.lightened(0.14)
		mi = mi.lightened(0.12)
		dk = dk.lightened(0.10)
	if pressed:
		li = li.darkened(0.08)
		mi = mi.darkened(0.08)
		dk = dk.darkened(0.08)
	var face_top := 1 if not pressed else 3
	var face_bot := 19 if not pressed else 21 # last face row
	for y in h:
		for x in w:
			var e := inset(x, y, w, h, 2)
			if e < 0:
				continue
			var col: Color
			if e == 0:
				col = C(OUTL)
			elif y > face_bot:
				col = lip if y < h - 2 else lipd
			elif y < face_top:
				col = dk.darkened(0.45) # pressed: inner shadow above face
			else:
				var fy := y - face_top
				var fh := face_bot - face_top
				if fy == 0:
					col = hl
				elif fy <= fh / 2:
					col = li.lerp(mi, float(fy) / float(fh / 2))
				else:
					col = mi.lerp(dk, float(fy - fh / 2) / float(fh - fh / 2))
				# side bevel
				if e == 1:
					if x <= 1:
						col = col.lightened(0.18)
					elif x >= w - 2:
						col = col.darkened(0.18)
				# gloss band on upper half
				if fy >= 1 and fy <= 3 and e >= 2:
					col = col.lightened(0.12 if fy == 1 else 0.06)
			c.px(x, y, col)
	if hover:
		# light rim just inside the outline
		for x in range(3, w - 3):
			c.px(x, face_top, hl.lightened(0.2))
	return c

func make_buttons() -> void:
	var pals := {
		"blue": {"hl": C("c8ecff"), "light": C("6ec0ff"), "mid": C("3a8cff"), "dark": C("2563d6"), "lip": C("1a46a8"), "lipd": C("12327a")},
		"green": {"hl": C("e0ffc8"), "light": C("8af060"), "mid": C("4ccf3c"), "dark": C("2f9c2c"), "lip": C("22752a"), "lipd": C("17521d")},
		"gold": {"hl": C("fff6c8"), "light": C("ffe066"), "mid": C("ffc22a"), "dark": C("e09400"), "lip": C("a86400"), "lipd": C("6e4000")},
		"red": {"hl": C("ffd0c8"), "light": C("ff7a6a"), "mid": C("e8443a"), "dark": C("c0261f"), "lip": C("8a1616"), "lipd": C("5e0e0e")},
		"dark": {"hl": C("7a8abc"), "light": C("46527c"), "mid": C("343f66"), "dark": C("283152"), "lip": C("1b2240"), "lipd": C("121830")},
	}
	var disabled := {"hl": C("a4aab8"), "light": C("70768a"), "mid": C("5c6274"), "dark": C("4c5264"), "lip": C("363a48"), "lipd": C("262a34")}
	for name in ["blue", "green", "gold"]:
		for st in ["normal", "hover", "pressed"]:
			button_img(pals[name], st).save("ui/button_%s_%s.png" % [name, st])
		button_img(disabled, "normal").save("ui/button_%s_disabled.png" % name)
	for name in ["red", "dark"]:
		for st in ["normal", "hover", "pressed"]:
			button_img(pals[name], st).save("ui/button_%s_%s.png" % [name, st])

func make_tab() -> void:
	var w := 48
	var h := 20
	var c := PX.Canvas.new(w, h)
	for y in h:
		for x in w:
			var e := inset(x, y, w, h, 2, true)
			if e < 0:
				continue
			var col: Color
			if e == 0:
				col = C(OUTL)
			elif y == 1:
				col = C("c8ecff")
			else:
				var t := float(y - 2) / float(h - 3)
				col = C("6ec0ff").lerp(C("2f6fe0"), t)
				if e == 1:
					col = col.lightened(0.15) if x <= 1 else col.darkened(0.15)
				if y == 2 or y == 3:
					col = col.lightened(0.08)
			c.px(x, y, col)
	c.save("ui/tab_active.png")

func make_close() -> void:
	for st in ["normal", "hover", "pressed"]:
		var c := PX.Canvas.new(16, 16)
		var pressed: bool = st == "pressed"
		var li := C("ff7a6a")
		var mi := C("e8443a")
		var dk := C("b8221c")
		if st == "hover":
			li = li.lightened(0.15)
			mi = mi.lightened(0.12)
			dk = dk.lightened(0.1)
		var face_top := 1 if not pressed else 2
		var face_bot := 12 if not pressed else 13
		for y in 16:
			for x in 16:
				var e := inset(x, y, 16, 16, 2)
				if e < 0:
					continue
				var col: Color
				if e == 0:
					col = C(OUTL)
				elif y > face_bot:
					col = C("8a1616") if y < 14 else C("5e0e0e")
				elif y < face_top:
					col = C("5e0e0e")
				else:
					var t := float(y - face_top) / float(face_bot - face_top)
					col = li.lerp(dk, t)
					if y == face_top:
						col = C("ffd0c8")
					if e == 1 and x <= 1:
						col = col.lightened(0.15)
					elif e == 1 and x >= 14:
						col = col.darkened(0.15)
				c.px(x, y, col)
		# white X with dark drop shadow
		var oy := face_top + 2
		for i in 7:
			for d in 2:
				c.px(4 + i + d + 1, oy + i + 1, C("5e0e0e"))
				c.px(10 - i + d + 1, oy + i + 1, C("5e0e0e"))
		for i in 7:
			for d in 2:
				c.px(4 + i + d, oy + i, C("f6f8ff"))
				c.px(10 - i + d, oy + i, C("f6f8ff"))
		c.save("ui/close_%s.png" % st)

# ------------------------------------------------------------------------------------------------
func make_slots() -> void:
	var c := PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 1, [L(OUTL), L("34406e", "5c6ca2"), L("070a1c", "0d1232")], C("0d1232"))
	c.save("ui/slot.png")
	c = PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 1, [L(OUTL), L("6d84c8", "9ab0ec"), L("0c1236", "182052")], C("162050"))
	c.save("ui/slot_hover.png")
	c = PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 1, [L(OUTL), L("fff1a8", "ffb000"), L("ffd34a", "c88a10"), L("3a2e5a", "2a2a60")], C("1c2254"))
	c.save("ui/slot_selected.png")
	c = PX.Canvas.new(24, 24)
	for y in 24:
		for x in 24:
			var e := inset(x, y, 24, 24, 1)
			if e == 1:
				c.px(x, y, Color(1, 1, 1, 1))
			elif e == 2:
				c.px(x, y, Color(1, 1, 1, 0.42))
	# corner sparkles
	for p in [Vector2i(2, 2), Vector2i(21, 2), Vector2i(2, 21), Vector2i(21, 21)]:
		c.px(p.x, p.y, Color(1, 1, 1, 1))
	c.save("ui/slot_rarity.png")

func make_bars() -> void:
	var c := PX.Canvas.new(24, 10)
	frame(c, 0, 0, 24, 10, 2, [L(OUTL), L("04060e", "1e2650")], C("0a0d22"))
	c.save("ui/bar_bg.png")
	var fills := {
		"blue": ["c8f0ff", "6ab8ff", "3a8cff", "2560d8", "15398c"],
		"red": ["ffc8b8", "ff7060", "f03a32", "c0201e", "6e0e0e"],
		"green": ["dcffb4", "8ef25a", "4ccf3c", "2f9c2c", "17521d"],
		"gold": ["fff8c8", "ffe066", "ffc22a", "e09400", "7a4800"],
		"orange": ["ffdcb0", "ffa64a", "ff7f1f", "d85a10", "7a2e06"],
		"purple": ["f2d6ff", "c58aff", "a05cf0", "7a3cc8", "3e1a70"],
	}
	for k in fills:
		var r: Array = fills[k]
		var f := PX.Canvas.new(24, 10)
		for y in 10:
			for x in 24:
				var e := inset(x, y, 24, 10, 2)
				if e < 0:
					continue
				var col: Color
				if e == 0:
					col = C(r[4])
				else:
					match y:
						1: col = C(r[0])
						2: col = C(r[1])
						3, 4, 5: col = C(r[2])
						6, 7: col = C(r[3])
						_: col = C(r[3]).darkened(0.15)
				f.px(x, y, col)
		f.save("ui/bar_fill_%s.png" % k)

func make_tooltip() -> void:
	var c := PX.Canvas.new(24, 24)
	frame(c, 0, 0, 24, 24, 1, [L(OUTL), L("6a80bc", "46588e"), L("0a0e26", "121838")], C("0f1433", 0.97))
	c.save("ui/tooltip.png")

func make_hotbar() -> void:
	var c := PX.Canvas.new(26, 26)
	frame(c, 0, 0, 26, 26, 2, [L(OUTL), L("8a99c4", "2c3552"), L("5a6890", "3a4668"), L(OUTL), L("070a1c", "151b3e")], C("0e1332"))
	c.save("ui/hotbar_slot.png")
	c = PX.Canvas.new(26, 26)
	frame(c, 0, 0, 26, 26, 2, [L(OUTL), L("fff1a8", "e0a020"), L("ffd34a", "c88a10"), L("5a3e06"), L("2e2c62", "1a1e48")], C("171d46"))
	c.save("ui/hotbar_selected.png")

func make_cursor() -> void:
	var c := PX.Canvas.new(16, 16)
	var pts := PackedVector2Array([Vector2(1, 1), Vector2(1, 13.5), Vector2(4.2, 10.4), Vector2(6.4, 15), Vector2(8.6, 14), Vector2(6.6, 9.4), Vector2(10.8, 9.4)])
	var shape := PX.Canvas.new(16, 16)
	shape.polygon(pts, Color.WHITE)
	shape.px(1, 1, Color.WHITE)
	for y in 16:
		for x in 16:
			if shape.get_px(x, y).a < 0.5:
				continue
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if shape.get_px(x + o.x, y + o.y).a < 0.5:
					edge = true
			if edge:
				c.px(x, y, C("ffc93c") if (x + y) % 7 != 0 else C("fff1a8"))
			else:
				c.px(x, y, C("f6f8ff") if x < 4 or y < 6 else C("d6e0f2"))
	c.outline(C(OUTL))
	c.save("ui/cursor.png")

func make_crosshair() -> void:
	var c := PX.Canvas.new(16, 16)
	var col := C("dffcff")
	for i in range(1, 5):
		for corner in [Vector2i(1, 1), Vector2i(14, 1), Vector2i(1, 14), Vector2i(14, 14)]:
			var sx := 1 if corner.x == 1 else -1
			var sy := 1 if corner.y == 1 else -1
			c.px(corner.x + (i - 1) * sx, corner.y, col)
			c.px(corner.x, corner.y + (i - 1) * sy, col)
	c.outline(C(OUTL, 0.9))
	c.save("ui/crosshair.png")

func make_arrow() -> void:
	var c := PX.Canvas.new(64, 16)
	var offs := [0, 1, 2, 1]
	for f in 4:
		var a := PX.Canvas.new(16, 16)
		var oy: int = offs[f]
		# shaft
		a.fill_rect(6, 1 + oy, 4, 6, C("ffc93c"))
		# head
		a.polygon(PackedVector2Array([Vector2(2, 7 + oy), Vector2(14, 7 + oy), Vector2(8, 13 + oy)]), C("ffc93c"))
		# shading: left highlight, right shadow
		for y in 16:
			for x in 16:
				var p := a.get_px(x, y)
				if p.a < 0.5:
					continue
				if a.get_px(x - 1, y).a < 0.5 or a.get_px(x, y - 1).a < 0.5:
					a.px(x, y, C("fff1a8"))
				elif a.get_px(x + 1, y).a < 0.5 or a.get_px(x, y + 1).a < 0.5:
					a.px(x, y, C("d08a10"))
		a.outline(C("2a1600"))
		c.blit(a.img, f * 16, 0)
	c.save("ui/arrow_bounce.png")

func make_keycap() -> void:
	var c := PX.Canvas.new(16, 16)
	for y in 16:
		for x in 16:
			var e := inset(x, y, 16, 16, 2)
			if e < 0:
				continue
			var col: Color
			if e == 0:
				col = C(OUTL)
			elif y >= 12:
				col = C("8a93a8") if y < 14 else C("5a6378")
			else:
				col = C("eef2f8").lerp(C("c3cad8"), float(y - 1) / 10.0)
				if e == 1 and x <= 1:
					col = C("ffffff")
				elif e == 1 and x >= 14:
					col = C("a8b0c2")
			c.px(x, y, col)
	c.save("ui/keycap.png")

# ------------------------------------------------------------------------------------------------
# Hex helpers (pointy-top, 2:1 pixel slopes)
func hex_mask(w: int, h: int) -> Array:
	var s := w / 4
	var m := []
	for y in h:
		var row := []
		var hw: int
		if y < s:
			hw = 1 + 2 * y
		elif y >= h - s:
			hw = 1 + 2 * (h - 1 - y)
		else:
			hw = w / 2
		for x in w:
			row.append(x >= w / 2 - hw and x <= w / 2 + hw - 1)
		m.append(row)
	return m

func erode(m: Array) -> Array:
	var h := m.size()
	var w: int = (m[0] as Array).size()
	var out := []
	for y in h:
		var row := []
		for x in w:
			var ok: bool = m[y][x]
			if ok:
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or not m[ny][nx]:
						ok = false
						break
			row.append(ok)
		out.append(row)
	return out

## ring[y][x] = inset ring index (0 = outermost) or -1 outside.
func hex_rings(w: int, h: int, depth: int) -> Array:
	var m := hex_mask(w, h)
	var ring := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(-1)
		ring.append(row)
	var cur := m
	for k in depth:
		var nxt := erode(cur)
		for y in h:
			for x in w:
				if cur[y][x] and not nxt[y][x]:
					ring[y][x] = k
		cur = nxt
	for y in h:
		for x in w:
			if cur[y][x]:
				ring[y][x] = depth
	return ring

func light_factor(x: int, y: int, w: int, h: int) -> float:
	var n := Vector2(x + 0.5 - w / 2.0, (y + 0.5 - h / 2.0) * (float(w) / float(h)))
	if n.length() < 0.001:
		return 0.5
	n = n.normalized()
	var ld := Vector2(-0.6, -0.8).normalized()
	return (n.dot(ld) + 1.0) * 0.5 # 1 = facing light

func quant(v: float, levels: int) -> float:
	return round(v * (levels - 1)) / float(levels - 1)

func boundary_points(m: Array) -> Array:
	var pts := []
	var h := m.size()
	var w: int = (m[0] as Array).size()
	for y in h:
		for x in w:
			if not m[y][x]:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or not m[ny][nx]:
					pts.append(Vector2(x + 0.5, y + 0.5))
					break
	return pts

func dist_outside(m: Array, pts: Array, x: int, y: int, ox: int, oy: int) -> float:
	var lx := x - ox
	var ly := y - oy
	var h := m.size()
	var w: int = (m[0] as Array).size()
	if lx >= 0 and ly >= 0 and lx < w and ly < h and m[ly][lx]:
		return 0.0
	var p := Vector2(lx + 0.5, ly + 0.5)
	var best := INF
	for q in pts:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)

func vertex_points(w: int, h: int, inset_px: int) -> Array:
	var s := w / 4
	return [
		Vector2i(w / 2 - 1, inset_px), Vector2i(w - 2 - inset_px, s), Vector2i(w - 2 - inset_px, h - 2 - s),
		Vector2i(w / 2 - 1, h - 2 - inset_px), Vector2i(inset_px, h - 2 - s), Vector2i(inset_px, s)]

func stud(c: PX.Canvas, p: Vector2i, hl: Color, mid: Color, dk: Color) -> void:
	c.px(p.x, p.y, hl)
	c.px(p.x + 1, p.y, mid)
	c.px(p.x, p.y + 1, mid)
	c.px(p.x + 1, p.y + 1, dk)

func make_hex_frame() -> void:
	var w := 52
	var h := 60
	var r := hex_rings(w, h, 6)
	var c := PX.Canvas.new(w, h)
	for y in h:
		for x in w:
			var k: int = r[y][x]
			if k < 0 or k > 5:
				continue
			var lf := quant(light_factor(x, y, w, h), 4)
			var v: float
			match k:
				0: v = 0.13
				1: v = lerpf(0.55, 1.0, lf)
				2: v = lerpf(0.60, 0.88, lf)
				3: v = lerpf(0.52, 0.78, lf)
				4: v = lerpf(0.86, 0.36, lf) # inset bevel (reversed)
				5: v = 0.16
			c.px(x, y, Color(v, v, v, 1.0))
	# notches at the middle of each vertical side (carved detail)
	for yy in range(h / 2 - 3, h / 2 + 3):
		c.px(2, yy, Color(0.35, 0.35, 0.35))
		c.px(w - 3, yy, Color(0.28, 0.28, 0.28))
	# bolts at the six corners
	for p in vertex_points(w, h, 2):
		stud(c, p, Color(1, 1, 1), Color(0.82, 0.82, 0.82), Color(0.38, 0.38, 0.38))
	c.save("ui/hex_frame.png")

func make_hex_fill() -> void:
	var w := 52
	var h := 60
	var r := hex_rings(w, h, 8)
	var c := PX.Canvas.new(w, h)
	var cx := w / 2.0
	var cy := h / 2.0
	var verts := [Vector2(cx, 1), Vector2(w - 1, w / 4), Vector2(w - 1, h - w / 4), Vector2(cx, h - 1), Vector2(1, h - w / 4), Vector2(1, w / 4)]
	for y in h:
		for x in w:
			var k: int = r[y][x]
			if k < 3:
				continue
			var lf := light_factor(x, y, w, h)
			var v: float
			if k == 3:
				v = lerpf(0.98, 0.50, quant(lf, 4)) # inset shadow top-left, light bottom-right
			elif k == 4:
				v = lerpf(0.90, 0.64, quant(lf, 4))
			else:
				var t := float(y) / float(h)
				v = lerpf(0.95, 0.70, t)
				var hd := Vector2(x + 0.5 - cx * 0.72, y + 0.5 - cy * 0.62).length()
				v += clampf(1.0 - hd / 16.0, 0.0, 1.0) * 0.08
				# faint facet lines from centre to vertices
				var p := Vector2(x + 0.5, y + 0.5)
				for vv in verts:
					var d := Geometry2D.get_closest_point_to_segment(p, Vector2(cx, cy), vv).distance_to(p)
					if d < 0.55:
						v += 0.06
						break
				v = quant(clampf(v, 0.0, 1.0), 9)
			c.px(x, y, Color(v, v, v, 1.0))
	c.save("ui/hex_fill.png")

func make_hex_glow() -> void:
	var w := 84
	var h := 92
	var m := hex_mask(52, 60)
	var pts := boundary_points(m)
	var c := PX.Canvas.new(w, h)
	for y in h:
		for x in w:
			var d := dist_outside(m, pts, x, y, 16, 16)
			var a: float
			if d <= 0.0:
				a = 0.85
			else:
				a = pow(clampf(1.0 - d / 16.0, 0.0, 1.0), 1.6) * 0.85
			a = round(a * 7.0) / 7.0
			if a > 0.0:
				c.px(x, y, Color(1, 1, 1, a))
	c.save("ui/hex_glow.png")

func make_hex_select() -> void:
	var w := 60
	var h := 68
	var m := hex_mask(52, 60)
	var pts := boundary_points(m)
	var c := PX.Canvas.new(w, h)
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var d := dist_outside(m, pts, x, y, 4, 4)
			if d <= 0.0:
				continue
			var ang := rad_to_deg(atan2(y + 0.5 - cy, x + 0.5 - cx))
			var near_vertex := false
			for va in [-90.0, -30.0, 30.0, 90.0, 150.0, -150.0]:
				if absf(wrapf(ang - va, -180.0, 180.0)) < 7.0:
					near_vertex = true
			if d <= 1.5:
				c.px(x, y, C(OUTL, 0.85))
			elif d <= 2.6:
				c.px(x, y, C("ffffff"))
			elif d <= 3.6:
				c.px(x, y, C("b8fbff"))
			elif d <= 4.6 and near_vertex:
				c.px(x, y, C("5ff2ff"))
	c.save("ui/hex_select.png")

func make_hex_core() -> void:
	# Canvas is 72x82 (contract) but the socket itself is 60x70 so it fits the R=34 honeycomb
	# without overlapping neighbours; gold vertex studs sit in the margin (between neighbours).
	var w := 60
	var h := 70
	var OX := 6
	var OY := 6
	var r := hex_rings(w, h, 8)
	var c := PX.Canvas.new(72, 82)
	var cx := w / 2.0
	var cy := h / 2.0
	var verts := [Vector2(cx, 1), Vector2(w - 1, w / 4), Vector2(w - 1, h - w / 4), Vector2(cx, h - 1), Vector2(1, h - w / 4), Vector2(1, w / 4)]
	var gold := [C("fff6c8"), C("ffe066"), C("ffc93c"), C("e0a020"), C("b07a10"), C("8a5200"), C("5e3800")]
	var cyan := [C("ffffff"), C("d8feff"), C("b8fbff"), C("5ff2ff"), C("2fc8ec"), C("1a8ac8"), C("12609a")]
	for y in h:
		for x in w:
			var k: int = r[y][x]
			if k < 0:
				continue
			var lf := quant(light_factor(x, y, w, h), 4)
			var col: Color
			match k:
				0: col = C("1e1200")
				1: col = (gold[0] as Color).lerp(gold[4], 1.0 - lf)
				2: col = (gold[1] as Color).lerp(gold[4], 1.0 - lf)
				3: col = (gold[2] as Color).lerp(gold[5], 1.0 - lf)
				4: col = (gold[5] as Color).lerp(gold[1], 1.0 - lf) # inset reversed
				5: col = C("0b1026")
				6: col = (cyan[5] as Color).lerp(cyan[2], 1.0 - lf)
				_:
					var p := Vector2(x + 0.5, y + 0.5)
					var hd := Vector2(x + 0.5 - cx * 0.8, y + 0.5 - cy * 0.7).length()
					var t := clampf(hd / 30.0, 0.0, 1.0)
					var idx := int(round(lerpf(1.0, 5.0, t)))
					col = cyan[idx]
					for vv in verts:
						var d := Geometry2D.get_closest_point_to_segment(p, Vector2(cx, cy), vv).distance_to(p)
						if d < 0.55:
							col = (cyan[maxi(idx - 2, 0)] as Color)
							break
			c.px(x + OX, y + OY, col)
	# gold studs on the six inner corners
	for p in vertex_points(w, h, 2):
		stud(c, p + Vector2i(OX, OY), C("ffffff"), C("ffe066"), C("8a5200"))
	# side ornaments
	for yy in range(h / 2 - 5, h / 2 + 5):
		c.px(OX + 2, OY + yy, C("fff1a8"))
		c.px(OX + w - 3, OY + yy, C("b07a10"))
	# gold diamond studs just outside each vertex (in the margin)
	var ctr := Vector2(36, 41)
	for v in [Vector2(36, 6), Vector2(66, 21), Vector2(66, 61), Vector2(36, 76), Vector2(6, 61), Vector2(6, 21)]:
		var dir: Vector2 = (v - ctr).normalized()
		var s: Vector2 = v + dir * 2.5
		diamond(c, int(round(s.x)) - (1 if dir.x > 0.1 else 0), int(round(s.y)) - (1 if dir.y > 0.5 else 0))
	# sparkles in the crystal
	for sp in [Vector2i(28, 30), Vector2i(46, 54), Vector2i(31, 60), Vector2i(48, 32)]:
		c.px(sp.x, sp.y, C("ffffff"))
		c.px(sp.x - 1, sp.y, C("d8feff"))
		c.px(sp.x + 1, sp.y, C("d8feff"))
		c.px(sp.x, sp.y - 1, C("d8feff"))
		c.px(sp.x, sp.y + 1, C("d8feff"))
	c.save("ui/hex_core.png")

func diamond(c: PX.Canvas, x: int, y: int) -> void:
	var pts := {Vector2i(0, -2): "fff6c8", Vector2i(-1, -1): "fff6c8", Vector2i(0, -1): "ffe066", Vector2i(1, -1): "ffc93c",
		Vector2i(-2, 0): "ffe066", Vector2i(-1, 0): "ffe066", Vector2i(0, 0): "ffc93c", Vector2i(1, 0): "e0a020", Vector2i(2, 0): "b07a10",
		Vector2i(-1, 1): "e0a020", Vector2i(0, 1): "b07a10", Vector2i(1, 1): "8a5200", Vector2i(0, 2): "8a5200"}
	for o in pts:
		c.px(x + o.x, y + o.y, C(pts[o]))
	for o in [Vector2i(0, -3), Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-3, 0), Vector2i(3, 0), Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 3), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(1, 2)]:
		if c.get_px(x + o.x, y + o.y).a < 0.5:
			c.px(x + o.x, y + o.y, C("1e1200"))

func make_hex_lock() -> void:
	var c := PX.Canvas.new(16, 16)
	# shackle (steel)
	for y in range(1, 9):
		for x in range(3, 13):
			var nx := (x + 0.5 - 8.0) / 4.6
			var ny := (y + 0.5 - 7.5) / 6.0
			var d := nx * nx + ny * ny
			var nx2 := (x + 0.5 - 8.0) / 2.4
			var ny2 := (y + 0.5 - 7.5) / 3.8
			if d <= 1.0 and nx2 * nx2 + ny2 * ny2 > 1.0:
				c.px(x, y, C("c3cad8") if x < 8 else C("7a8398"))
	# body (gold)
	for y in range(7, 15):
		for x in range(3, 13):
			var col := C("ffc93c")
			if y == 7:
				col = C("fff1a8")
			elif y >= 13:
				col = C("b07a10")
			elif x == 3:
				col = C("ffe066")
			elif x == 12:
				col = C("d08a10")
			c.px(x, y, col)
	# keyhole
	c.px(7, 9, C("3a2200"))
	c.px(8, 9, C("3a2200"))
	c.px(7, 10, C("3a2200"))
	c.px(8, 10, C("3a2200"))
	c.px(7, 11, C("3a2200"))
	c.px(8, 11, C("5e3800"))
	c.outline(C(OUTL))
	c.save("ui/hex_lock.png")

func make_hex_max() -> void:
	var c := PX.Canvas.new(24, 12)
	for y in 12:
		for x in 24:
			var e := inset(x, y, 24, 12, 2)
			if e < 0:
				continue
			var col: Color
			if e == 0:
				col = C("3a2200")
			elif y == 1:
				col = C("fff6c8")
			elif y >= 9:
				col = C("c88a10")
			else:
				col = C("ffe066").lerp(C("ffb000"), float(y - 2) / 6.0)
			c.px(x, y, col)
	var glyphs := {
		"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
		"A": [".#.", "#.#", "###", "#.#", "#.#"],
		"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	}
	var x0 := 5
	for ch in ["M", "A", "X"]:
		var rows: Array = glyphs[ch]
		for ry in rows.size():
			var s: String = rows[ry]
			for rx in s.length():
				if s[rx] == "#":
					c.px(x0 + rx, 3 + ry, C("4a2600"))
		x0 += String(rows[0]).length() + 1
	c.save("ui/hex_max.png")

func make_skilltree_bg() -> void:
	var w := 128
	var h := 128
	var c := PX.Canvas.new(w, h)
	for y in h:
		for x in w:
			var n := PX.vnoise_wrap(x, y, 32.0, 128, 7) * 0.6 + PX.vnoise_wrap(x, y, 16.0, 128, 11) * 0.4
			var col := C("0a0f24").lerp(C("111838"), quant(n, 5))
			c.px(x, y, col)
	# hex grid (pointy-top, 32 wide, row step 32, 2:1 slopes) - tiles every 128px
	var line_col := C("18224c")
	var dot_col := C("24326a")
	for j in range(-1, 5):
		for i in range(-1, 5):
			var hx := i * 32 + (16 if posmod(j, 2) == 1 else 0)
			var hy := j * 32 + 16
			var v := [Vector2i(hx, hy - 20), Vector2i(hx + 16, hy - 12), Vector2i(hx + 16, hy + 12), Vector2i(hx, hy + 20), Vector2i(hx - 16, hy + 12), Vector2i(hx - 16, hy - 12)]
			for k in 6:
				var a: Vector2i = v[k]
				var b: Vector2i = v[(k + 1) % 6]
				wrap_line(c, a.x, a.y, b.x, b.y, line_col)
			for p in v:
				c.px(posmod(p.x, w), posmod(p.y, h), dot_col)
	# specks and tiny stars
	for i in 70:
		var x := int(PX.hash01(i, 1, 99) * w)
		var y := int(PX.hash01(i, 2, 99) * h)
		var r := PX.hash01(i, 3, 99)
		if r < 0.08:
			c.px(x, y, C("5ff2ff", 0.85))
		elif r < 0.3:
			c.px(x, y, C("3a5aa0"))
		else:
			c.px(x, y, C("1e2a5a"))
	c.save("ui/skilltree_bg.png")

func wrap_line(c: PX.Canvas, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		c.px(posmod(x0, c.w), posmod(y0, c.h), col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

func _init() -> void:
	make_panel()
	make_panel_dark()
	make_panel_purple()
	make_panel_title()
	make_hud_box()
	make_buttons()
	make_tab()
	make_close()
	make_slots()
	make_bars()
	make_tooltip()
	make_hotbar()
	make_cursor()
	make_crosshair()
	make_arrow()
	make_keycap()
	make_hex_frame()
	make_hex_fill()
	make_hex_glow()
	make_hex_select()
	make_hex_core()
	make_hex_lock()
	make_hex_max()
	make_skilltree_bg()
	quit()
