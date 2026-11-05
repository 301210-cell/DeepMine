## Self-review previews for the UI kit and fonts (not game assets).
## Writes 4x nearest-neighbour mockups to the scratchpad previews folder.
extends SceneTree

const PX = preload("res://px.gd")
const PREVIEW_DIR := "C:/Users/Jeremy/AppData/Local/Temp/claude/8bd127b22df0a1ed/aa2076d7-1a4a-41ce-aca4-0aa005bd01b8/scratchpad/previews"

var fonts := {}

func img(rel: String) -> Image:
	var i := Image.load_from_file(PX.out_root().path_join(rel))
	if i == null:
		push_error("missing " + rel)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	i.convert(Image.FORMAT_RGBA8)
	return i

func put(dst: Image, x: int, y: int, c: Color, additive: bool = false) -> void:
	if x < 0 or y < 0 or x >= dst.get_width() or y >= dst.get_height() or c.a <= 0.0:
		return
	var d := dst.get_pixel(x, y)
	if additive:
		dst.set_pixel(x, y, Color(minf(d.r + c.r * c.a, 1.0), minf(d.g + c.g * c.a, 1.0), minf(d.b + c.b * c.a, 1.0), 1.0))
	else:
		dst.set_pixel(x, y, d.blend(c))

func draw(dst: Image, src: Image, x: int, y: int, tint: Color = Color.WHITE, additive: bool = false, sx: int = 0, sy: int = 0, sw: int = -1, sh: int = -1) -> void:
	if sw < 0:
		sw = src.get_width()
	if sh < 0:
		sh = src.get_height()
	for yy in sh:
		for xx in sw:
			var c := src.get_pixel(sx + xx, sy + yy) * tint
			put(dst, x + xx, y + yy, c, additive)

## StyleBoxTexture-like 9-slice with stretch.
func nine(dst: Image, src: Image, x: int, y: int, w: int, h: int, ml: int, mt: int, mr: int, mb: int, tint: Color = Color.WHITE) -> void:
	var sw := src.get_width()
	var sh := src.get_height()
	for yy in h:
		var sy: int
		if yy < mt:
			sy = yy
		elif yy >= h - mb:
			sy = sh - (h - yy)
		else:
			var cin := h - mt - mb
			var sin := sh - mt - mb
			sy = mt + int(float(yy - mt) / float(cin) * sin)
		for xx in w:
			var sx: int
			if xx < ml:
				sx = xx
			elif xx >= w - mr:
				sx = sw - (w - xx)
			else:
				var cinx := w - ml - mr
				var sinx := sw - ml - mr
				sx = ml + int(float(xx - ml) / float(cinx) * sinx)
			put(dst, x + xx, y + yy, src.get_pixel(sx, sy) * tint)

func load_font(name: String) -> void:
	var path := PX.out_root().path_join("fonts/" + name + ".fnt")
	var f := FileAccess.open(path, FileAccess.READ)
	var chars := {}
	var line_h := 10
	var base := 8
	while not f.eof_reached():
		var line := f.get_line()
		var kv := {}
		for tok in line.split(" ", false):
			if tok.contains("="):
				var p := tok.split("=")
				kv[p[0]] = p[1]
		if line.begins_with("common"):
			line_h = int(kv.lineHeight)
			base = int(kv.base)
		elif line.begins_with("char "):
			chars[int(kv.id)] = {"x": int(kv.x), "y": int(kv.y), "w": int(kv.width), "h": int(kv.height), "yo": int(kv.yoffset), "adv": int(kv.xadvance)}
	fonts[name] = {"chars": chars, "img": img("fonts/" + name + "_0.png"), "lh": line_h, "base": base}

func text_width(font: String, s: String, scale: int = 1) -> int:
	var fd: Dictionary = fonts[font]
	var w := 0
	for i in s.length():
		var code := s.unicode_at(i)
		if fd.chars.has(code):
			w += int(fd.chars[code].adv) * scale
	return w

func text(dst: Image, font: String, s: String, x: int, y: int, col: Color, scale: int = 1, shadow: bool = true) -> void:
	var fd: Dictionary = fonts[font]
	var cx := x
	for i in s.length():
		var code := s.unicode_at(i)
		if not fd.chars.has(code):
			continue
		var ch: Dictionary = fd.chars[code]
		var src: Image = fd.img
		for yy in int(ch.h):
			for xx in int(ch.w):
				var a := src.get_pixel(int(ch.x) + xx, int(ch.y) + yy).a
				if a > 0.5:
					for sy in scale:
						for sx in scale:
							var px := cx + xx * scale + sx
							var py := y + (int(ch.yo) + yy) * scale + sy
							if shadow:
								put(dst, px + scale, py + scale, Color(0.02, 0.03, 0.08, 0.9))
							put(dst, px, py, col)
		cx += int(ch.adv) * scale

func button(dst: Image, kind: String, label: String, x: int, y: int, w: int, state: String = "normal") -> void:
	nine(dst, img("ui/button_%s_%s.png" % [kind, state]), x, y, w, 24, 8, 8, 8, 10)
	var tw := text_width("pixel", label)
	var dy := 2 if state == "pressed" else 0
	text(dst, "pixel", label, x + (w - tw) / 2, y + 7 + dy, Color.WHITE)

func window_mock() -> void:
	var W := 340
	var H := 282
	var dst := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# cave-ish backdrop
	for y in H:
		for x in W:
			var n := PX.vnoise(x, y, 18.0, 3)
			dst.set_pixel(x, y, PX.hex("1a1430").lerp(PX.hex("2a2050"), n * 0.6))
	nine(dst, img("ui/panel.png"), 8, 8, 324, 214, 12, 12, 12, 12)
	# title ribbon + close
	nine(dst, img("ui/panel_title.png"), 16, 14, 120, 20, 10, 6, 10, 6)
	text(dst, "pixel_big", "Shop", 26, 17, PX.hex("ffc93c"))
	draw(dst, img("ui/close_normal.png"), 308, 15)
	draw(dst, img("ui/close_hover.png"), 290, 15)
	draw(dst, img("ui/close_pressed.png"), 272, 15)
	# tabs
	var tab := img("ui/tab_active.png")
	nine(dst, tab, 16, 40, 52, 20, 8, 8, 8, 4)
	text(dst, "pixel", "Tools", 28, 46, Color.WHITE)
	var bx := 70
	for t in ["Upgrades", "Machines", "Decor"]:
		var tw := text_width("pixel", t) + 16
		nine(dst, img("ui/button_dark_normal.png"), bx, 40, tw, 20, 8, 8, 8, 10)
		text(dst, "pixel", t, bx + 8, 45, PX.hex("aab4d4"))
		bx += tw + 2
	# item rows
	var rows := [["Better Pickaxe", "$1,000"], ["Large Backpack", "$1,500"], ["Lantern", "$500"]]
	var ry := 64
	var rarities := ["8a93a8", "4fdc6a", "3f8dff", "a65cff", "ffc93c"]
	for i in rows.size():
		nine(dst, img("ui/panel_dark.png"), 16, ry, 200, 30, 6, 6, 6, 6)
		nine(dst, img("ui/slot.png"), 20, ry + 3, 24, 24, 6, 6, 6, 6)
		nine(dst, img("ui/slot_rarity.png"), 20, ry + 3, 24, 24, 6, 6, 6, 6, PX.hex(rarities[i + 1]))
		text(dst, "pixel", rows[i][0], 50, ry + 6, Color.WHITE)
		text(dst, "pixel", rows[i][1], 50, ry + 17, PX.hex("ffd34a"))
		button(dst, "green", "Buy", 168, ry + 3, 44, "hover" if i == 1 else ("pressed" if i == 2 else "normal"))
		ry += 33
	# right column: slots
	var sx := 224
	nine(dst, img("ui/slot.png"), sx, 64, 24, 24, 6, 6, 6, 6)
	nine(dst, img("ui/slot_hover.png"), sx + 26, 64, 24, 24, 6, 6, 6, 6)
	nine(dst, img("ui/slot_selected.png"), sx + 52, 64, 24, 24, 6, 6, 6, 6)
	nine(dst, img("ui/slot.png"), sx + 78, 64, 24, 24, 6, 6, 6, 6)
	nine(dst, img("ui/slot_rarity.png"), sx + 78, 64, 24, 24, 6, 6, 6, 6, PX.hex("ffc93c"))
	text(dst, "pixel", "24", sx + 13, 79, Color.WHITE)
	# bars
	var by := 94
	var fills := ["blue", "red", "green", "gold", "orange", "purple"]
	for i in fills.size():
		nine(dst, img("ui/bar_bg.png"), sx, by, 100, 10, 5, 4, 5, 4)
		var fw := int(100 * (0.25 + 0.13 * i))
		nine(dst, img("ui/bar_fill_%s.png" % fills[i]), sx, by, fw, 10, 5, 4, 5, 4)
		by += 12
	text(dst, "pixel", "120 / 500 XP", sx + 26, 95, Color.WHITE)
	# buttons row
	button(dst, "blue", "Next " + char(8594), 16, 166, 60)
	button(dst, "blue", "Travel", 80, 166, 60, "hover")
	button(dst, "gold", "UNLOCK", 144, 166, 60)
	button(dst, "red", "Reset", 208, 166, 50)
	button(dst, "gold", "Locked", 262, 166, 60, "disabled")
	button(dst, "blue", "Pressed", 220, 260, 60, "pressed")
	button(dst, "dark", "Back", 284, 260, 44)
	# hud chip, tooltip, hotbar, keycap, cursor
	nine(dst, img("ui/hud_box.png"), 16, 194, 76, 22, 8, 8, 8, 8)
	text(dst, "pixel", "12,450", 40, 200, Color.WHITE)
	nine(dst, img("ui/tooltip.png"), 96, 192, 110, 26, 6, 6, 6, 6)
	text(dst, "pixel", "Quick Swing 2/5", 102, 196, PX.hex("ffb36b"))
	text(dst, "pixel", "+10% mining speed", 102, 206, PX.hex("c3cad8"))
	for i in 4:
		var hs := img("ui/hotbar_selected.png" if i == 1 else "ui/hotbar_slot.png")
		draw(dst, hs, 212 + i * 27, 192)
	draw(dst, img("ui/keycap.png"), 12, 260)
	text(dst, "pixel", "E", 18, 263, PX.hex("1e2650"), 1, false)
	text(dst, "pixel", "Interact", 32, 264, Color.WHITE)
	draw(dst, img("ui/cursor.png"), 180, 260)
	draw(dst, img("ui/crosshair.png"), 200, 260)
	var arrow := img("ui/arrow_bounce.png")
	for f in 4:
		draw(dst, arrow, 90 + f * 18, 260, Color.WHITE, false, f * 16, 0, 16, 16)
	# sample sentences
	text(dst, "pixel", "The quick brown fox jumps over 12,450 lazy miners!", 12, 228, Color.WHITE)
	text(dst, "pixel", "THE QUICK BROWN FOX: 0123456789 ?!.,;:'\"()[]{}<>/+-=*%$#&@~^_|", 12, 242, PX.hex("b8fbff"))
	save(dst, "ui_window_mock.png", 4)

func font_sheet() -> void:
	var W := 330
	var H := 150
	var dst := Image.create(W, H, false, Image.FORMAT_RGBA8)
	dst.fill(PX.hex("141a3a"))
	text(dst, "pixel_big", "GAME LOOP: EVENT! Crystal Surge", 6, 6, PX.hex("ff9a3c"))
	text(dst, "pixel_big", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 6, 26, Color.WHITE)
	text(dst, "pixel_big", "abcdefghijklmnopqrstuvwxyz", 6, 46, Color.WHITE)
	text(dst, "pixel_big", "0123456789 $12,450 Lv.5 +25%", 6, 66, PX.hex("ffd34a"))
	text(dst, "pixel_big", "!?.,:;'\"()[]<>/+-=*%#&@~_", 6, 86, PX.hex("b8fbff"))
	text(dst, "pixel", "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789", 6, 108, Color.WHITE)
	var ex := ""
	for code in [8226, 215, 8594, 8592, 8593, 8595, 10003, 9733, 8230]:
		ex += char(code) + " "
	text(dst, "pixel", "Extras: " + ex + " Pickaxe x3  Depth: 120m", 6, 120, PX.hex("ffc93c"))
	text(dst, "pixel", "Great! You found some ore. Mine it with your pickaxe and collect the resources!", 6, 132, Color.WHITE)
	save(dst, "font_sheet.png", 4)

func skill_mock() -> void:
	var W := 360
	var H := 260
	var dst := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bg := img("ui/skilltree_bg.png")
	for y in H:
		for x in W:
			dst.set_pixel(x, y, bg.get_pixel(x % 128, y % 128))
	var frame := img("ui/hex_frame.png")
	var fill := img("ui/hex_fill.png")
	var glow := img("ui/hex_glow.png")
	var sel := img("ui/hex_select.png")
	var core := img("ui/hex_core.png")
	var lock := img("ui/hex_lock.png")
	var mx := img("ui/hex_max.png")
	var icons: Image = null
	if FileAccess.file_exists(PX.out_root().path_join("sprites/items/skill_icons.png")):
		icons = img("sprites/items/skill_icons.png")
	var orange := PX.hex("ff7a2f")
	var green := PX.hex("4fdc6a")
	var blue := PX.hex("3f8dff")
	var purple := PX.hex("a65cff")
	var gold := PX.hex("ffd35a")
	var cx := 180
	var cy := 128
	# real layout spacing from ARCHITECTURE (pointy-top axial, R = 34)
	var ax := func(q: int, r: int) -> Vector2i:
		return Vector2i(cx + int(round(34.0 * sqrt(3.0) * (q + r / 2.0))), cy + int(round(34.0 * 1.5 * r)))
	var nodes := [
		{"p": ax.call(1, 0), "c": orange, "s": "unlocked", "label": ""},
		{"p": ax.call(2, 0), "c": orange, "s": "maxed", "label": "MAXED"},
		{"p": ax.call(3, -1), "c": orange, "s": "available", "label": "AVAILABLE"},
		{"p": ax.call(0, -1), "c": green, "s": "selected", "label": ""},
		{"p": ax.call(-1, 0), "c": blue, "s": "available", "label": ""},
		{"p": ax.call(-2, 0), "c": blue, "s": "locked", "label": "LOCKED"},
		{"p": ax.call(0, 1), "c": purple, "s": "unlocked", "label": ""},
		{"p": ax.call(0, 2), "c": purple, "s": "locked", "label": ""},
		{"p": ax.call(0, -2), "c": green, "s": "locked", "label": ""},
	]
	# connections
	var links := [[Vector2i(cx, cy), 0], [0, 1], [0, 2], [Vector2i(cx, cy), 3], [Vector2i(cx, cy), 4], [4, 5], [Vector2i(cx, cy), 6], [6, 7], [3, 8]]
	for l in links:
		var a: Vector2i = l[0] if l[0] is Vector2i else nodes[l[0]].p
		var bn: Dictionary = nodes[l[1]]
		var b: Vector2i = bn.p
		var active: bool = bn.s != "locked"
		var col: Color = bn.c if active else PX.hex("2a3150")
		for t in 200:
			var p := Vector2(a).lerp(Vector2(b), t / 199.0)
			for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				put(dst, int(p.x) + o.x, int(p.y) + o.y, col.darkened(0.2) if active else col)
			if active and t % 40 == 0:
				put(dst, int(p.x), int(p.y), Color.WHITE)
	# core
	draw(dst, glow, cx - 42, cy - 46, gold * Color(1, 1, 1, 0.55), true)
	draw(dst, core, cx - 36, cy - 41)
	if icons:
		draw_icon2x(dst, icons, 0, cx - 16, cy - 16)
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var p: Vector2i = n.p
		var col: Color = n.c
		var st: String = n.s
		var x0 := p.x - 26
		var y0 := p.y - 30
		match st:
			"locked":
				draw(dst, fill, x0, y0, PX.hex("1c2240"))
				draw(dst, frame, x0, y0, PX.hex("4a5272"))
				draw(dst, lock, p.x - 8, p.y - 8)
			"available":
				draw(dst, glow, x0 - 16, y0 - 16, col * Color(1, 1, 1, 0.28), true)
				draw(dst, fill, x0, y0, col.darkened(0.62))
				draw(dst, frame, x0, y0, col.lightened(0.15))
			"unlocked", "selected":
				draw(dst, glow, x0 - 16, y0 - 16, col * Color(1, 1, 1, 0.5), true)
				draw(dst, fill, x0, y0, col)
				draw(dst, frame, x0, y0, col.lightened(0.45))
			"maxed":
				draw(dst, glow, x0 - 16, y0 - 16, gold * Color(1, 1, 1, 0.55), true)
				draw(dst, fill, x0, y0, col)
				draw(dst, frame, x0, y0, gold)
		if st != "locked" and icons:
			draw_icon2x(dst, icons, 1 + i, p.x - 16, p.y - 16, Color.WHITE if st != "available" else Color(0.75, 0.75, 0.75))
		if st == "maxed":
			draw(dst, mx, p.x - 12, p.y + 20)
		if st == "selected":
			draw(dst, sel, x0 - 4, y0 - 4)
		var label: String = n.label
		if label != "":
			text(dst, "pixel", label, p.x - text_width("pixel", label) / 2, p.y + 33, PX.hex("e6ecff"))
	text(dst, "pixel_big", "SKILL TREE", 8, 6, PX.hex("ffd35a"))
	text(dst, "pixel", "AVAILABLE SKILL POINTS: 3", 8, 26, Color.WHITE)
	save(dst, "skill_mock.png", 3)

func draw_icon2x(dst: Image, icons: Image, idx: int, x: int, y: int, tint: Color = Color.WHITE) -> void:
	var sx := (idx % 16) * 16
	var sy := (idx / 16) * 16
	for yy in 32:
		for xx in 32:
			put(dst, x + xx, y + yy, icons.get_pixel(sx + xx / 2, sy + yy / 2) * tint)

func save(dst: Image, name: String, scale: int) -> void:
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIR)
	var big := dst.duplicate() as Image
	big.resize(dst.get_width() * scale, dst.get_height() * scale, Image.INTERPOLATE_NEAREST)
	big.save_png(PREVIEW_DIR.path_join(name))
	print("preview ", name)

func _init() -> void:
	load_font("pixel")
	load_font("pixel_big")
	font_sheet()
	window_mock()
	skill_mock()
	quit()
