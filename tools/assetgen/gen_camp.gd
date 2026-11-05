## Generates surface camp buildings and world objects into assets/sprites/world/.
extends SceneTree

const PX = preload("res://px.gd")
const K = preload("res://campkit.gd")

var SLATE: Array[Color]
var ROOFRED: Array[Color]

func _init() -> void:
	SLATE = K.pal(["141a30", "222a48", "303c64", "425086", "5a6aa6", "8090c8"])
	ROOFRED = K.pal(["2e1010", "4e1a16", "70261e", "94382a", "b8523a", "d8764e"])
	var imgs := {
		"mara_tent": mara_tent(),
		"shop": shop(),
		"skill_board": skill_board(),
		"storage": storage(),
		"mining_board": mining_board(),
		"museum": museum(),
		"mine_entrance": mine_entrance(),
		"elevator": elevator(),
		"elevator_top": elevator_top(),
		"machine_pad": machine_pad(),
		"minecart": minecart(false),
		"minecart_loot": minecart(true),
		"chest": chest(),
		"props": props(),
	}
	for k in imgs:
		var c = imgs[k]
		c.save("sprites/world/%s.png" % k)
		K.preview(c.img, "world_" + k, 4)
	quit()

# ------------------------------------------------------------------ helpers
func ground_shadow(c, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1):
		c.blend(x, y, Color(0, 0, 0, 0.35))

func crate(c, x: int, y: int, s: int) -> void:
	K.planks(c, x, y, s, s, K.WOOD, 3, false, x * 7 + y, 3)
	c.rect_outline(x, y, s, s, K.WOOD[0])
	c.rect_outline(x + 1, y + 1, s - 2, s - 2, K.WOOD[5])
	c.line(x + 1, y + 1, x + s - 2, y + s - 2, K.WOOD[2])
	c.line(x + s - 2, y + 1, x + 1, y + s - 2, K.WOOD[2])
	c.line(x + 2, y + 1, x + s - 2, y + s - 3, K.WOOD[4])
	c.px(x + 1, y + 1, K.METAL[5])
	c.px(x + s - 2, y + 1, K.METAL[5])

func barrel(c, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		var t := float(yy - y) / float(h - 1)
		var bulge := int(round(sin(t * PI) * 1.5))
		for xx in range(x - bulge, x + w + bulge):
			var u := float(xx - (x - bulge)) / float(w + bulge * 2 - 1)
			var b := 2 if u < 0.2 else (4 if u < 0.45 else (3 if u < 0.75 else 2))
			c.px(xx, yy, K.WOOD[b])
	for band in [y + 1, y + h / 2, y + h - 2]:
		var t2 := float(band - y) / float(h - 1)
		var bul := int(round(sin(t2 * PI) * 1.5))
		for xx in range(x - bul, x + w + bul):
			c.px(xx, band, K.METAL[3] if xx < x + w / 2 else K.METAL[2])
	c.fill_rect(x, y, w, 1, K.WOOD[1])

# ------------------------------------------------------------------ Mara tent 64x48
func mara_tent():
	var c = PX.Canvas.new(64, 48)
	var C := K.CLOTH
	var T := K.TEAL
	# back/side roof (depth to the right)
	K.fill_poly_fn(c, PackedVector2Array([Vector2(30, 6), Vector2(42, 4), Vector2(63, 44), Vector2(55, 48)]), func(x: int, y: int) -> Color:
		var stripe := (x + y / 2) % 9 == 0
		var col: Color = C[1] if stripe else C[2]
		if y > 40:
			col = T[2]
		return col)
	# front face
	K.fill_poly_fn(c, PackedVector2Array([Vector2(4, 48), Vector2(30, 5), Vector2(56, 48)]), func(x: int, y: int) -> Color:
		var left := x < 30
		var col: Color = C[4] if left else C[3]
		if (x - 30) % 8 == 0 and x != 30:
			col = C[2] if left else C[1]
		if y >= 42 and y <= 44:
			col = T[4] if left else T[3]
		elif y == 45:
			col = T[1]
		if x == 30 or x == 29:
			col = C[5] if left else C[3]
		return col)
	# opening with flaps
	K.fill_poly_fn(c, PackedVector2Array([Vector2(22, 48), Vector2(30, 20), Vector2(38, 48)]), func(x: int, y: int) -> Color:
		var t := float(y - 20) / 28.0
		var col: Color = K.WOOD[0].lerp(K.FIRE[2], clampf((t - 0.45) * 1.4, 0.0, 0.8))
		return col)
	K.glow(c, 30, 44, 9.0, K.FIRE[4], 0.5)
	# interior lantern + bedroll
	K.lantern(c, 30, 28, 1, false, false)
	c.fill_rect(24, 44, 6, 3, K.RED[2]); c.fill_rect(24, 44, 6, 1, K.RED[4])
	# flaps tied back
	c.polygon(PackedVector2Array([Vector2(22, 48), Vector2(29, 22), Vector2(25, 40), Vector2(18, 48)]), C[5])
	c.polygon(PackedVector2Array([Vector2(38, 48), Vector2(31, 22), Vector2(35, 40), Vector2(42, 48)]), C[2])
	c.line(18, 48, 25, 38, C[3]); c.line(42, 48, 35, 38, C[1])
	c.px(25, 38, T[3]); c.px(35, 38, T[3]); c.px(24, 38, T[4]); c.px(36, 38, T[2])
	# pole + pennant
	c.fill_rect(29, 0, 2, 7, K.WOOD[3]); c.px(29, 0, K.WOOD[5])
	c.polygon(PackedVector2Array([Vector2(31, 0), Vector2(39, 2), Vector2(31, 4)]), T[4])
	c.line(31, 3, 37, 2, T[2])
	# guy ropes + stakes
	c.line(4, 47, 0, 47, C[1]); c.line(56, 47, 63, 47, C[1])
	c.line(10, 38, 1, 47, C[2]); c.fill_rect(0, 45, 2, 3, K.WOOD[2])
	# crate & lantern stand to the right
	crate(c, 50, 38, 9)
	K.lantern(c, 54, 28, 2)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Shop 96x80
func shop():
	var c = PX.Canvas.new(96, 80)
	# walls
	K.planks(c, 5, 30, 86, 43, K.WOOD, 4, true, 11, 3)
	# foundation
	K.bricks(c, 2, 72, 92, 8, K.STONE, 7, 4, 4)
	# roof
	K.shingle_roof(c, PackedVector2Array([Vector2(1, 33), Vector2(12, 13), Vector2(84, 13), Vector2(95, 33)]), SLATE, 3, 6, 21)
	c.fill_rect(10, 12, 76, 2, K.WOOD[2]); c.fill_rect(10, 12, 76, 1, K.WOOD[4])
	c.fill_rect(0, 32, 96, 2, K.WOOD[1])
	# corner posts
	K.beam(c, 4, 33, 5, 40, false, 2)
	K.beam(c, 87, 33, 5, 40, false, 3)
	# shop window + counter
	K.window(c, 12, 47, 38, 15, true)
	# goods silhouettes in window
	for i in 4:
		var gx := 15 + i * 9
		var cols := [K.PURP, K.BLUE, K.GREEN, K.RED]
		var g: Array[Color] = cols[i]
		c.polygon(PackedVector2Array([Vector2(gx, 57), Vector2(gx + 2, 53), Vector2(gx + 4, 57), Vector2(gx + 2, 59)]), g[3])
		c.px(gx + 2, 54, g[5])
	c.line(36, 49, 42, 55, K.WOOD[1]); c.fill_rect(40, 48, 5, 2, K.METAL[3])
	K.bevel_rect(c, 9, 63, 44, 9, K.WOOD, 3)
	c.fill_rect(9, 63, 44, 1, K.WOOD[6])
	# coins & gem on counter
	c.fill_rect(14, 61, 3, 2, K.GOLD[4]); c.px(15, 61, K.GOLD[5])
	c.fill_rect(46, 60, 3, 3, K.BLUE[4]); c.px(46, 60, K.BLUE[6])
	# door
	K.bevel_rect(c, 62, 46, 18, 26, K.WOOD, 2)
	c.fill_rect(61, 45, 20, 1, K.WOOD[1])
	K.window(c, 66, 49, 10, 7, true)
	c.fill_rect(76, 60, 2, 2, K.GOLD[4])
	c.fill_rect(64, 64, 14, 1, K.WOOD[1])
	# awning stripes
	for x in range(1, 95):
		var stripe := int((x - 1) / 8) % 2 == 0
		var r: Array[Color] = K.RED if stripe else K.CLOTH
		for y in range(33, 43):
			var b := 3 if stripe else 4
			if y == 33:
				b += 1
			elif y >= 40:
				b -= 1
			c.px(x, y, r[clampi(b, 0, r.size() - 1)])
		# scallop
		var local := (x - 1) % 8
		var depth := int(round(sin(float(local + 0.5) / 8.0 * PI) * 3.0))
		for y in range(43, 43 + depth):
			c.px(x, y, r[2])
		c.px(x, 43 + depth, r[1])
	c.fill_rect(1, 32, 94, 1, K.RED[1])
	# lantern by door
	K.lantern(c, 85, 44, 0)
	# sign
	c.fill_rect(30, 1, 2, 12, K.WOOD[2]); c.fill_rect(64, 1, 2, 12, K.WOOD[2])
	K.planks(c, 24, 2, 48, 13, K.WOOD, 3, false, 5, 4)
	c.rect_outline(24, 2, 48, 13, K.WOOD[0])
	c.rect_outline(25, 3, 46, 11, K.WOOD[2])
	K.text(c, "SHOP", 33, 4, K.GOLD[4], K.F35, 2, K.WOOD[0])
	K.sparkle(c, 28, 8, K.GOLD[4])
	K.sparkle(c, 67, 8, K.GOLD[4])
	# barrel outside
	barrel(c, 82, 62, 8, 10)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Skill board 128x64 (2 frames)
func hexagon(c, cx: int, cy: int, col: Color, inner: Color) -> void:
	# 7x8 pointy hex
	var rows := ["..###..", ".#####.", "#######", "#######", "#######", "#######", ".#####.", "..###.."]
	for y in rows.size():
		for x in 7:
			if rows[y][x] == "#":
				var edge := y == 0 or y == 7 or x == 0 or x == 6 or (y == 1 and (x == 1 or x == 5)) or (y == 6 and (x == 1 or x == 5))
				c.px(cx - 3 + x, cy - 4 + y, col if edge else inner)

func small_hex(c, cx: int, cy: int, col: Color, inner: Color) -> void:
	var rows := [".###.", "#####", "#####", "#####", ".###."]
	for y in 5:
		for x in 5:
			if rows[y][x] == "#":
				var edge := y == 0 or y == 4 or x == 0 or x == 4
				c.px(cx - 2 + x, cy - 2 + y, col if edge else inner)
	c.px(cx - 1, cy - 1, col.lightened(0.4))

func skill_board():
	var c = PX.Canvas.new(128, 64)
	for f in 2:
		var ox := f * 64
		var bright := f == 1
		# plinth
		K.bricks(c, ox + 10, 56, 44, 8, K.STONE, 6, 4, 8)
		c.fill_rect(ox + 8, 55, 48, 2, K.STONE[4]); c.fill_rect(ox + 8, 55, 48, 1, K.STONE[5])
		# legs
		K.plate(c, ox + 12, 46, 5, 10, K.METAL, 2, false)
		K.plate(c, ox + 47, 46, 5, 10, K.METAL, 2, false)
		# frame
		K.plate(c, ox + 4, 8, 56, 40, K.METAL, 3)
		c.fill_rect(ox + 4, 8, 56, 2, K.GOLD[3]); c.fill_rect(ox + 4, 8, 56, 1, K.GOLD[5])
		# screen
		for y in range(12, 45):
			for x in range(8, 56):
				var col: Color = K.NAVY[1].lerp(K.NAVY[3], float(y - 12) / 33.0 * 0.5)
				if (x + y) % 6 == 0 and (y % 3 == 0):
					col = K.NAVY[3]
				c.px(ox + x, y, col)
		c.rect_outline(ox + 7, 11, 50, 35, K.NAVY[0])
		# hex network: core + 4 branches (small 5x5 hexes, 2px links)
		var core := Vector2i(ox + 32, 28)
		var nodes := {
			"o": [Vector2i(42, 28), Vector2i(50, 23), Vector2i(50, 33)],
			"g": [Vector2i(28, 20), Vector2i(33, 14)],
			"b": [Vector2i(22, 28), Vector2i(14, 23), Vector2i(14, 33)],
			"p": [Vector2i(36, 36), Vector2i(31, 41)],
		}
		var cols := {"o": [K.FIRE[3], K.FIRE[5]], "g": [K.GREEN[3], K.GREEN[5]], "b": [K.BLUE[3], K.BLUE[5]], "p": [K.PURP[3], K.PURP[5]]}
		var lit_count := 3 if bright else 2
		for key in nodes:
			var lst: Array = nodes[key]
			var cc: Array = cols[key]
			for i in lst.size():
				var n: Vector2i = lst[i]
				var from: Vector2i = Vector2i(32, 28) if i == 0 else lst[0]
				var on := i < lit_count
				var lc: Color = cc[0] if on else K.NAVY[4]
				c.line(ox + from.x, from.y, ox + n.x, n.y, lc)
				c.line(ox + from.x, from.y + 1, ox + n.x, n.y + 1, lc.darkened(0.35))
		for key in nodes:
			var lst2: Array = nodes[key]
			var cc2: Array = cols[key]
			for i in lst2.size():
				var n2: Vector2i = lst2[i]
				var on2 := i < lit_count
				if on2:
					K.glow(c, ox + n2.x + 0.5, n2.y + 0.5, 5.0, cc2[1], 0.3 if bright else 0.18)
				small_hex(c, ox + n2.x, n2.y, cc2[1] if on2 else K.NAVY[5], cc2[0] if on2 else K.NAVY[3])
		K.glow(c, core.x + 0.5, core.y + 0.5, 8.0, K.GOLD[4], 0.4 if bright else 0.28)
		hexagon(c, core.x, core.y, K.GOLD[5], K.GOLD[3])
		c.px(core.x, core.y - 1, Color.WHITE)
		# scanline
		var sl := 18 if not bright else 34
		for x in range(8, 56):
			c.blend(ox + x, sl, Color(0.37, 0.95, 1.0, 0.18))
		# screen glass glint
		c.line(ox + 9, 13, ox + 14, 13, K.CYAN[4])
		c.px(ox + 9, 14, K.CYAN[3])
		# console under screen
		K.plate(c, ox + 18, 48, 28, 7, K.METAL, 2, false)
		for i in 5:
			var bcol: Color = [K.RED[3], K.GOLD[4], K.GREEN[4], K.BLUE[4], K.PURP[4]][i]
			c.px(ox + 21 + i * 5, 51, bcol if (bright or i % 2 == 0) else bcol.darkened(0.5))
			c.px(ox + 22 + i * 5, 51, bcol.darkened(0.3))
		# crest + antenna
		c.polygon(PackedVector2Array([Vector2(ox + 22, 8), Vector2(ox + 26, 3), Vector2(ox + 38, 3), Vector2(ox + 42, 8)]), K.METAL[3])
		c.line(ox + 26, 3, ox + 37, 3, K.METAL[5])
		c.fill_rect(ox + 31, 4, 3, 3, K.CYAN[3] if bright else K.CYAN[1])
		c.fill_rect(ox + 50, 0, 1, 8, K.METAL[4])
		c.px(ox + 50, 0, K.RED[5] if bright else K.RED[2])
		if bright:
			K.glow(c, ox + 50.5, 0.5, 4.0, K.RED[4], 0.5)
		# side lamps (cyan)
		for sx in [ox + 2, ox + 61]:
			c.fill_rect(sx, 20, 2, 6, K.METAL[2])
			c.px(sx, 22, K.CYAN[4]); c.px(sx + 1, 22, K.CYAN[3])
		c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Storage 80x64
func storage():
	var c = PX.Canvas.new(80, 64)
	K.planks(c, 5, 22, 70, 42, K.WOOD, 4, false, 31, 2)
	# corrugated roof
	K.fill_poly_fn(c, PackedVector2Array([Vector2(0, 25), Vector2(9, 8), Vector2(71, 8), Vector2(80, 25)]), func(x: int, y: int) -> Color:
		var m := x % 4
		var col: Color = K.METAL[[4, 3, 2, 3][m]]
		if PX.vnoise(float(x), float(y * 3), 3.0, 77) > 0.86 and m == 1:
			col = K.RUST[3] if m < 2 else K.RUST[2]
		if y == 24 or y == 23:
			col = K.METAL[1]
		return col)
	c.fill_rect(8, 8, 64, 1, K.METAL[5])
	# door frame & open doors
	K.beam(c, 23, 30, 4, 34, false, 4)
	K.beam(c, 53, 30, 4, 34, false, 5)
	K.beam(c, 23, 30, 34, 4, true, 6)
	for y in range(34, 64):
		for x in range(27, 53):
			var t := float(y - 34) / 30.0
			c.px(x, y, K.NAVY[1].lerp(K.WOOD[1], t * 0.6))
	# crates inside
	crate(c, 29, 50, 10)
	crate(c, 40, 52, 8)
	crate(c, 31, 42, 8)
	c.shade_rect(29, 42, 22, 22, 0.55)
	# hanging bulb inside
	c.line(40, 34, 40, 38, K.METAL[2])
	K.glow(c, 40.5, 40.5, 8.0, K.FIRE[5], 0.35)
	c.fill_rect(39, 39, 3, 3, K.FIRE[5]); c.px(40, 40, K.FIRE[6])
	# swung-open door leaves
	for side in [0, 1]:
		var dx := 15 if side == 0 else 57
		K.planks(c, dx, 34, 8, 30, K.WOOD, 4, true, 40 + side, 3)
		c.line(dx, 35, dx + 7, 62, K.WOOD[5]); c.line(dx + 7, 35, dx, 62, K.WOOD[5])
		c.rect_outline(dx, 34, 8, 30, K.WOOD[1])
	# sign
	K.planks(c, 21, 24, 38, 7, K.WOOD, 3, false, 3, 4)
	c.rect_outline(21, 24, 38, 7, K.WOOD[0])
	K.text(c, "STORAGE", 27, 25, K.CLOTH[5], K.F35, 1, K.WOOD[1])
	# crates outside left + barrel right
	crate(c, 1, 52, 12)
	crate(c, 12, 55, 9)
	crate(c, 4, 41, 11)
	barrel(c, 68, 52, 9, 12)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Mining board 48x48
func mining_board():
	var c = PX.Canvas.new(48, 48)
	K.beam(c, 6, 10, 4, 38, false, 1)
	K.beam(c, 38, 10, 4, 38, false, 2)
	K.shingle_roof(c, PackedVector2Array([Vector2(1, 13), Vector2(8, 6), Vector2(40, 6), Vector2(47, 13)]), ROOFRED, 2, 4, 3)
	c.fill_rect(1, 13, 46, 1, K.WOOD[1])
	K.planks(c, 4, 14, 40, 22, K.WOOD, 4, true, 8, 3)
	c.rect_outline(3, 14, 42, 23, K.WOOD[1])
	c.fill_rect(3, 14, 42, 1, K.WOOD[5])
	# notes
	var notes := [Rect2i(7, 17, 9, 11), Rect2i(18, 18, 10, 8), Rect2i(30, 16, 10, 12), Rect2i(19, 27, 9, 7)]
	var i := 0
	for n in notes:
		var paper: Color = K.CLOTH[5] if i != 2 else K.GOLD[5]
		c.fill_rect(n.position.x, n.position.y, n.size.x, n.size.y, paper)
		c.fill_rect(n.position.x, n.position.y + n.size.y - 1, n.size.x, 1, K.CLOTH[2])
		c.fill_rect(n.position.x + n.size.x - 1, n.position.y, 1, n.size.y, K.CLOTH[3])
		for ly in range(n.position.y + 3, n.position.y + n.size.y - 2, 2):
			c.fill_rect(n.position.x + 2, ly, n.size.x - 4 - (ly % 3), 1, K.CLOTH[2])
		c.px(n.position.x + n.size.x / 2, n.position.y, K.RED[4])
		c.px(n.position.x + n.size.x / 2, n.position.y + 1, K.RED[2])
		i += 1
	# star on gold note
	c.px(35, 20, K.FIRE[3]); c.px(34, 21, K.FIRE[3]); c.px(35, 21, K.FIRE[4]); c.px(36, 21, K.FIRE[3]); c.px(35, 22, K.FIRE[2])
	# quest "!" badge
	c.circle(24, 3.5, 3.6, K.GOLD[3])
	c.circle(24, 3.0, 2.6, K.GOLD[4])
	c.fill_rect(23, 1, 2, 3, K.WOOD[0]); c.fill_rect(23, 5, 2, 1, K.WOOD[0])
	K.glow(c, 24, 4, 7.0, K.GOLD[5], 0.3)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Museum 80x72
func museum():
	var c = PX.Canvas.new(80, 72)
	var M := K.pal(["2a2a38", "434458", "626479", "8a8ca2", "b4b6c8", "dcdeea", "f4f4fa"])
	# back wall
	K.bricks(c, 6, 30, 68, 34, K.STONE, 8, 5, 12)
	c.shade_rect(6, 30, 68, 34, 0.8)
	# doorway arch
	for y in range(40, 64):
		for x in range(32, 48):
			var dx := (x - 39.5) / 8.0
			var dy := (y - 46.0) / 8.0
			if y < 46 and dx * dx + dy * dy > 1.0:
				continue
			var t := float(y - 40) / 24.0
			c.px(x, y, K.FIRE[5].lerp(K.FIRE[2], t))
	c.fill_rect(36, 54, 8, 10, K.WOOD[1]); c.fill_rect(36, 54, 8, 1, K.WOOD[3])
	# display windows with gems on pedestals
	for wx in [14, 56]:
		c.fill_rect(wx - 1, 39, 12, 17, K.WOOD[1])
		for y in range(40, 55):
			for x in range(wx, wx + 10):
				c.px(x, y, K.NAVY[3].lerp(K.NAVY[5], float(y - 40) / 15.0))
		var gems: Array = [K.PURP, K.BLUE] if wx == 14 else [K.GREEN, K.RED]
		for gi in 2:
			var g: Array[Color] = gems[gi]
			var gx: int = wx + 2 + gi * 5
			c.fill_rect(gx - 1, 50, 4, 5, M[4]); c.fill_rect(gx - 1, 50, 4, 1, M[6])
			c.polygon(PackedVector2Array([Vector2(gx - 1, 48), Vector2(gx + 1, 43), Vector2(gx + 3, 48), Vector2(gx + 1, 50)]), g[3])
			c.px(gx + 1, 44, g[g.size() - 1]); c.px(gx, 46, g[5])
			K.glow(c, gx + 1.0, 46.0, 4.0, g[5], 0.35)
		c.line(wx, 40, wx + 3, 40, Color(1, 1, 1, 0.5))
	# columns
	for colx in [6, 24, 50, 68]:
		for y in range(31, 64):
			for x in range(colx, colx + 6):
				var u: int = x - colx
				var b: int = [3, 5, 6, 5, 4, 2][u]
				c.px(x, y, M[b])
		c.fill_rect(colx - 1, 29, 8, 3, M[5]); c.fill_rect(colx - 1, 29, 8, 1, M[6])
		c.fill_rect(colx - 1, 61, 8, 3, M[4]); c.fill_rect(colx - 1, 63, 8, 1, M[2])
	# entablature
	c.fill_rect(2, 26, 76, 4, M[4]); c.fill_rect(2, 26, 76, 1, M[6]); c.fill_rect(2, 29, 76, 1, M[2])
	K.text(c, "COLLECTION", 21, 31, K.GOLD[4], K.F35, 1, Color(0, 0, 0, 0))
	c.fill_rect(19, 30, 42, 7, Color(0, 0, 0, 0)) # placeholder clear (re-draw after)
	K.bevel_rect(c, 18, 30, 44, 7, K.NAVY, 3)
	K.text(c, "COLLECTION", 21, 31, K.GOLD[4], K.F35, 1, K.NAVY[0])
	# pediment
	K.fill_poly_fn(c, PackedVector2Array([Vector2(1, 26), Vector2(40, 9), Vector2(79, 26)]), func(x: int, y: int) -> Color:
		var col: Color = M[4] if x < 40 else M[3]
		if y >= 24:
			col = M[2]
		return col)
	c.line(1, 26, 40, 9, M[6]); c.line(40, 9, 79, 26, M[3])
	# gem emblem in pediment
	c.polygon(PackedVector2Array([Vector2(36, 20), Vector2(40, 15), Vector2(44, 20), Vector2(40, 24)]), K.BLUE[3])
	c.line(40, 15, 40, 23, K.BLUE[5]); c.px(39, 17, K.BLUE[6])
	# steps
	c.fill_rect(0, 64, 80, 3, M[4]); c.fill_rect(0, 64, 80, 1, M[6])
	c.fill_rect(0, 67, 80, 3, M[3]); c.fill_rect(0, 67, 80, 1, M[5])
	c.fill_rect(0, 70, 80, 2, M[2]); c.fill_rect(0, 70, 80, 1, M[4])
	# rooftop crystal
	K.glow(c, 40.0, 5.0, 11.0, K.PURP[5], 0.45)
	K.crystal(c, 40.0, 10.0, 10.0, 6.0, 0.0, K.PURP)
	K.crystal(c, 36.0, 10.0, 6.0, 4.0, -0.5, K.BLUE)
	K.crystal(c, 44.0, 10.0, 6.0, 4.0, 0.5, K.BLUE)
	K.sparkle(c, 46, 2, K.PURP[5])
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Mine entrance 112x96
var ROCK: Array[Color] = K.pal(["141218", "221f28", "322d38", "453f4a", "5c5560", "786e76", "978a8a"])

func boulder(c, cx: float, cy: float, rx: float, ry: float, seed: int) -> void:
	var R := ROCK
	for y in range(int(cy - ry - 1), int(cy + ry + 2)):
		for x in range(int(cx - rx - 1), int(cx + rx + 2)):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny + (PX.vnoise(float(x), float(y), 2.5, seed) - 0.5) * 0.45
			if d > 1.0:
				continue
			var light := -nx * 0.6 - ny * 0.8 + (PX.vnoise(float(x), float(y), 2.0, seed + 3) - 0.5) * 0.5
			var b := 2
			if light > 0.62:
				b = 5
			elif light > 0.2:
				b = 4
			elif light > -0.3:
				b = 3
			if d > 0.8:
				b = 1 if light < 0.35 else 3
			if PX.hash01(x, y, seed) > 0.92:
				b = maxi(b - 1, 1)
			elif PX.hash01(x, y, seed + 1) > 0.97 and light > 0.0:
				b = 6
			c.px(x, y, R[b])
	# a crack
	var sx := int(cx - rx * 0.2)
	var sy := int(cy - ry * 0.3)
	for i in int(rx * 0.6):
		c.px(sx + i, sy + int(i * 0.5) + (i % 2), R[1])

func mine_entrance():
	var c = PX.Canvas.new(112, 96)
	# rock mass behind frame (back layer darker, then foreground boulders)
	for y in range(8, 96):
		for x in 112:
			var top := 26.0 - 18.0 * (1.0 - absf(x - 56.0) / 56.0) + (PX.vnoise(float(x), 0.0, 5.0, 2) - 0.5) * 10.0
			var side_ok := true
			if y < 60:
				side_ok = absf(x - 56.0) < 30.0 + (y - 8.0) * 0.9 + PX.vnoise(float(y), 1.0, 4.0, 3) * 8.0
			if y >= top and side_ok:
				var b := 2 if PX.vnoise(float(x), float(y), 3.0, 4) > 0.5 else 1
				c.px(x, y, ROCK[b])
	var stones := [
		[10, 86, 12, 10], [24, 90, 10, 6], [6, 70, 8, 9], [16, 60, 10, 9], [9, 48, 7, 7], [22, 44, 9, 8],
		[18, 30, 8, 7], [30, 20, 10, 8], [44, 13, 9, 6], [58, 11, 11, 7], [72, 14, 9, 6], [84, 21, 10, 8],
		[95, 31, 8, 7], [90, 44, 9, 8], [103, 50, 7, 7], [96, 60, 10, 9], [106, 72, 7, 9], [100, 86, 12, 10],
		[88, 91, 10, 5], [26, 72, 6, 7], [88, 72, 6, 7], [36, 10, 6, 5], [66, 7, 6, 4],
	]
	var s := 0
	for st in stones:
		boulder(c, st[0], st[1], st[2], st[3], 40 + s)
		s += 1
	# small blue crystals in rocks
	K.glow(c, 12.0, 46.0, 7.0, K.CYAN[3], 0.35)
	K.crystal(c, 12.0, 50.0, 7.0, 3.0, -0.3, K.BLUE)
	K.crystal(c, 15.0, 50.0, 5.0, 3.0, 0.2, K.BLUE)
	K.glow(c, 101.0, 44.0, 6.0, K.PURP[4], 0.35)
	K.crystal(c, 101.0, 48.0, 6.0, 3.0, 0.3, K.PURP)
	# opening interior
	for y in range(36, 96):
		for x in range(35, 77):
			var t := float(y - 36) / 60.0
			var col: Color = Color.html("05060e").lerp(K.NAVY[2], clampf(1.0 - absf(x - 56) / 22.0, 0.0, 1.0) * 0.25 + t * 0.15)
			c.px(x, y, col)
	# receding support frames
	for k in 3:
		var inset := 6 + k * 5
		var top := 40 + k * 4
		var col: Color = K.WOOD[2].darkened(0.45 + k * 0.15)
		c.fill_rect(35 + inset, top, 2, 96 - top, col)
		c.fill_rect(77 - inset - 2, top, 2, 96 - top, col)
		c.fill_rect(35 + inset, top, 42 - inset * 2, 2, col)
	# rails converging
	for y in range(78, 96):
		var t := float(y - 78) / 17.0
		var half := 3.0 + t * 12.0
		c.px(int(56 - half), y, K.METAL[3].darkened(0.4 - t * 0.3))
		c.px(int(56 + half), y, K.METAL[3].darkened(0.4 - t * 0.3))
		if y % 4 == 0:
			c.fill_rect(int(56 - half - 1), y, int(half * 2 + 3), 1, K.WOOD[1].darkened(0.3 - t * 0.2))
	# timber frame
	K.beam(c, 28, 34, 8, 62, false, 7)
	K.beam(c, 76, 34, 8, 62, false, 8)
	K.beam(c, 22, 28, 68, 8, true, 9)
	K.beam(c, 34, 36, 3, 10, false, 10)
	c.line(36, 36, 44, 36, K.WOOD[2])
	c.polygon(PackedVector2Array([Vector2(36, 36), Vector2(44, 36), Vector2(36, 44)]), K.WOOD[3])
	c.polygon(PackedVector2Array([Vector2(76, 36), Vector2(68, 36), Vector2(76, 44)]), K.WOOD[2])
	c.line(36, 44, 44, 36, K.WOOD[1]); c.line(76, 44, 68, 36, K.WOOD[1])
	# metal brackets
	for bx in [29, 77]:
		c.fill_rect(bx, 30, 6, 2, K.METAL[3]); c.px(bx + 1, 30, K.METAL[5]); c.px(bx + 4, 30, K.METAL[5])
	# sign
	c.fill_rect(46, 23, 2, 6, K.METAL[2]); c.fill_rect(64, 23, 2, 6, K.METAL[2])
	K.planks(c, 39, 11, 34, 13, K.WOOD, 3, false, 12, 4)
	c.rect_outline(39, 11, 34, 13, K.WOOD[0])
	c.rect_outline(40, 12, 32, 11, K.WOOD[2])
	K.text(c, "MINE", 45, 15, K.WOOD[0], K.F57, 1)
	K.text(c, "MINE", 46, 15, K.WOOD[0], K.F57, 1)
	K.text(c, "MINE", 44, 14, K.GOLD[4], K.F57, 1)
	K.text(c, "MINE", 45, 14, K.GOLD[3], K.F57, 1)
	# lanterns + light on rocks/beams
	K.light(c, 31, 44, 18.0, K.FIRE[4], 0.35)
	K.light(c, 81, 44, 18.0, K.FIRE[4], 0.35)
	K.lantern(c, 26, 37, 0)
	K.lantern(c, 86, 37, 2)
	c.fill_rect(26, 36, 3, 1, K.METAL[2]); c.fill_rect(84, 36, 3, 1, K.METAL[2])
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Elevator 240x64 (5 frames)
func hazard_stripe(c, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var on := int((xx + yy) / 3) % 2 == 0
			c.px(xx, yy, K.GOLD[4] if on else K.NAVY[0])

func elevator():
	var c = PX.Canvas.new(240, 64)
	var opens := [0.0, 0.3, 0.6, 0.88, 1.0]
	for f in 5:
		var ox := f * 48
		var open: float = opens[f]
		# interior
		for y in range(10, 60):
			for x in range(6, 42):
				var col: Color = K.NAVY[2]
				if (x - 6) % 6 == 0:
					col = K.NAVY[1]
				elif (x - 6) % 6 == 1:
					col = K.NAVY[3]
				c.px(ox + x, y, col)
		# interior light + cable
		c.fill_rect(ox + 20, 10, 8, 2, K.METAL[2])
		c.fill_rect(ox + 21, 12, 6, 1, K.FIRE[5] if open > 0.5 else K.FIRE[3])
		if open > 0.5:
			K.light(c, ox + 24, 14, 20.0, K.FIRE[5], 0.25)
		c.fill_rect(ox + 6, 56, 36, 4, K.METAL[2]); c.fill_rect(ox + 6, 56, 36, 1, K.METAL[4])
		# doors (accordion gate)
		var half_w := 18
		var visible := int(round(half_w * (1.0 - open))) + 3
		for side in 2:
			var x0 := ox + 6 if side == 0 else ox + 42 - visible
			for y in range(11, 56):
				for x in range(x0, x0 + visible):
					var lx := x - x0
					var bar := lx % 4 == 0
					var diag := (lx + y) % 8 == 0 or (lx - y + 400) % 8 == 0
					if bar:
						c.px(x, y, K.METAL[4] if side == 0 else K.METAL[3])
					elif diag:
						c.px(x, y, K.METAL[3] if side == 0 else K.METAL[2])
			c.fill_rect(x0, 11, visible, 2, K.METAL[3])
			c.fill_rect(x0, 54, visible, 2, K.METAL[3])
			var handle_x := x0 + visible - 2 if side == 0 else x0 + 1
			c.fill_rect(handle_x, 30, 1, 6, K.GOLD[4])
		# frame posts
		K.plate(c, ox + 1, 2, 5, 62, K.METAL, 3, false)
		K.plate(c, ox + 42, 2, 5, 62, K.METAL, 3, false)
		for ry in range(6, 62, 8):
			c.px(ox + 3, ry, K.METAL[6]); c.px(ox + 44, ry, K.METAL[6])
		# header
		K.plate(c, ox + 1, 1, 46, 10, K.METAL, 3)
		hazard_stripe(c, ox + 6, 6, 36, 3)
		var lamp_col: Color = K.GREEN[5] if f == 4 else (K.GOLD[4] if f > 0 else K.RED[4])
		c.fill_rect(ox + 22, 2, 4, 3, lamp_col)
		c.px(ox + 22, 2, Color.WHITE)
		K.glow(c, ox + 24.0, 3.5, 5.0, lamp_col, 0.45)
		# floor sill
		K.plate(c, ox + 1, 60, 46, 4, K.METAL, 2, false)
		hazard_stripe(c, ox + 6, 61, 36, 2)
		# cable above (through header)
		c.fill_rect(ox + 23, 0, 2, 1, K.METAL[1])
	c.outline(K.OUT)
	return c

func elevator_top():
	var c = PX.Canvas.new(48, 32)
	# roof
	c.polygon(PackedVector2Array([Vector2(2, 14), Vector2(8, 9), Vector2(40, 9), Vector2(46, 14)]), K.METAL[2])
	c.line(8, 9, 40, 9, K.METAL[4])
	# housing
	K.plate(c, 3, 14, 42, 18, K.METAL, 3)
	hazard_stripe(c, 4, 27, 40, 3)
	# pulley wheel
	K.gear(c, 24.0, 12.0, 8.0, 10, 0.2, K.METAL)
	c.circle(24.0, 12.0, 3.0, K.METAL[1])
	c.px(24, 12, K.GOLD[4])
	# cables
	c.fill_rect(16, 12, 1, 20, K.METAL[1]); c.fill_rect(31, 12, 1, 20, K.METAL[1])
	c.fill_rect(17, 12, 1, 20, K.METAL[4]); c.fill_rect(32, 12, 1, 20, K.METAL[4])
	# motor box + warning light
	K.plate(c, 36, 17, 7, 8, K.METAL, 2, false)
	c.px(39, 20, K.GREEN[5]); c.px(39, 22, K.RED[4])
	c.fill_rect(5, 17, 6, 5, K.NAVY[2]); c.fill_rect(6, 18, 4, 1, K.CYAN[3])
	c.fill_rect(42, 4, 3, 5, K.METAL[2])
	c.fill_rect(42, 2, 3, 2, K.FIRE[4]); c.px(42, 2, K.FIRE[6])
	K.glow(c, 43.5, 3.0, 5.0, K.FIRE[4], 0.4)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Machine pad 64x24
func machine_pad():
	var c = PX.Canvas.new(64, 24)
	var Cc := K.pal(["2e3240", "4a4e5c", "6a6e7c", "8a8e9a", "aeb2bc", "d0d2d8"])
	for y in range(17, 24):
		for x in range(0, 64):
			var b := 3
			if y == 17:
				b = 5
			elif y == 18:
				b = 4
			elif y == 23:
				b = 1
			if PX.hash01(x, y, 3) > 0.88:
				b -= 1
			c.px(x, y, Cc[b])
	c.line(18, 19, 22, 22, Cc[1]); c.line(22, 22, 25, 21, Cc[1])
	hazard_stripe(c, 0, 17, 4, 7); hazard_stripe(c, 60, 17, 4, 7)
	# cone
	c.polygon(PackedVector2Array([Vector2(8, 17), Vector2(11, 9), Vector2(14, 17)]), K.FIRE[3])
	c.fill_rect(9, 13, 4, 1, K.CLOTH[5])
	c.fill_rect(7, 16, 9, 1, K.FIRE[2])
	c.line(11, 9, 9, 15, K.FIRE[4])
	# sign
	c.fill_rect(46, 9, 2, 8, K.WOOD[2])
	K.bevel_rect(c, 36, 2, 22, 9, K.GOLD, 3)
	c.rect_outline(36, 2, 22, 9, K.GOLD[1])
	K.text(c, "SOON", 40, 4, K.NAVY[1], K.F35, 1)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Minecart
func cart_body(c, ox: int, oy: int, phase: float) -> void:
	var poly := PackedVector2Array([Vector2(ox + 2, oy + 6), Vector2(ox + 30, oy + 6), Vector2(ox + 27, oy + 19), Vector2(ox + 5, oy + 19)])
	K.fill_poly_fn(c, poly, func(x: int, y: int) -> Color:
		var u := float(x - ox - 2) / 28.0
		var b := 3
		if u < 0.12:
			b = 4
		elif u > 0.8:
			b = 2
		var col: Color = K.RUST[b] if PX.vnoise(float(x), float(y), 3.0, 55) > 0.7 else K.METAL[b]
		if (x - ox) % 7 == 3:
			col = K.METAL[maxi(b - 1, 1)]
		return col)
	# rim
	c.fill_rect(ox + 1, oy + 5, 30, 2, K.METAL[4]); c.fill_rect(ox + 1, oy + 5, 30, 1, K.METAL[5])
	c.fill_rect(ox + 3, oy + 4, 26, 1, K.NAVY[0])
	# rivets
	for rx in [ox + 6, ox + 13, ox + 20, ox + 26]:
		c.px(rx, oy + 9, K.METAL[5]); c.px(rx, oy + 16, K.METAL[5])
	c.fill_rect(ox + 5, oy + 18, 22, 2, K.METAL[1])
	K.wheel(c, ox + 9.5, oy + 20.0, 3.5, phase)
	K.wheel(c, ox + 22.5, oy + 20.0, 3.5, phase)

func minecart(loot: bool):
	if loot:
		var c = PX.Canvas.new(32, 24)
		# gem heap
		var gems := [[8, 5, K.PURP], [13, 3, K.BLUE], [18, 4, K.PURP], [23, 5, K.GOLD], [11, 6, K.GREEN], [20, 6, K.BLUE], [16, 5, K.PURP]]
		K.glow(c, 16.0, 5.0, 12.0, K.PURP[5], 0.35)
		for g in gems:
			var r: Array[Color] = g[2]
			var gx: int = g[0]
			var gy: int = g[1]
			c.polygon(PackedVector2Array([Vector2(gx - 3, gy + 2), Vector2(gx, gy - 3), Vector2(gx + 3, gy + 2), Vector2(gx, gy + 4)]), r[3])
			c.px(gx, gy - 2, r[5]); c.px(gx - 1, gy, r[4]); c.px(gx + 1, gy + 1, r[2])
		cart_body(c, 0, 0, 0.0)
		K.sparkle(c, 14, 1, K.PURP[5])
		K.sparkle(c, 25, 2, K.GOLD[5])
		c.outline(K.OUT)
		return c
	var c2 = PX.Canvas.new(96, 24)
	for f in 3:
		cart_body(c2, f * 32, 0 if f != 2 else -1, f * PI / 6.0)
	c2.outline(K.OUT)
	return c2

# ------------------------------------------------------------------ Chest 64x16
func chest_box(c, ox: int, r: Array[Color], band: Array[Color], lid_up: int, open: bool, gem: bool) -> void:
	# body
	K.bevel_rect(c, ox + 1, 8, 14, 8, r, 3)
	c.fill_rect(ox + 1, 8, 14, 1, r[1])
	if open:
		# open lid behind
		K.bevel_rect(c, ox + 2, 1, 12, 5, r, 2)
		c.fill_rect(ox + 2, 5, 12, 1, r[0])
		# inner glow + coins
		c.fill_rect(ox + 2, 6, 12, 3, K.GOLD[4])
		c.fill_rect(ox + 3, 6, 10, 1, K.GOLD[5])
		c.px(ox + 5, 6, Color.WHITE); c.px(ox + 10, 7, Color.WHITE)
		K.glow(c, ox + 8.0, 5.0, 8.0, K.GOLD[5], 0.45)
	else:
		var ly := 3 - lid_up
		c.polygon(PackedVector2Array([Vector2(ox + 1, ly + 5), Vector2(ox + 3, ly), Vector2(ox + 13, ly), Vector2(ox + 15, ly + 5)]), r[4])
		c.fill_rect(ox + 1, ly + 4, 14, 2, r[3])
		c.line(ox + 3, ly, ox + 12, ly, r[5])
		if lid_up > 0:
			c.fill_rect(ox + 2, 8 - lid_up, 12, lid_up, K.GOLD[5])
			K.glow(c, ox + 8.0, 7.0, 7.0, K.GOLD[5], 0.4)
	# bands
	for bx in [ox + 4, ox + 11]:
		c.fill_rect(bx, 8, 1, 8, band[3])
		if not open:
			c.fill_rect(bx, 3 - lid_up, 1, 6, band[4])
	# lock
	c.fill_rect(ox + 7, 9, 3, 3, band[4])
	c.px(ox + 8, 10, K.BLUE[4] if gem else band[1])

func chest():
	var c = PX.Canvas.new(64, 16)
	chest_box(c, 0, K.WOOD, K.GOLD, 0, false, false)
	chest_box(c, 16, K.WOOD, K.GOLD, 2, false, false)
	chest_box(c, 32, K.WOOD, K.GOLD, 0, true, false)
	chest_box(c, 48, K.GOLD, K.TEAL, 0, false, true)
	c.outline(K.OUT)
	return c

# ------------------------------------------------------------------ Props 256x128 (32x32 grid)
func cell(i: int) -> Vector2i:
	return Vector2i((i % 8) * 32, (i / 8) * 32)

func props():
	var c = PX.Canvas.new(256, 128)
	# 0-3 campfire
	for f in 4:
		var o := cell(f)
		var t = PX.Canvas.new(32, 32)
		K.glow(t, 16.0, 22.0, 14.0, K.FIRE[4], 0.35)
		# stones ring
		for i in 6:
			var sx := 7 + i * 3.6
			t.circle(sx, 29.5, 2.2, K.STONE[3])
			t.px(int(sx) - 1, 28, K.STONE[5])
		# logs
		t.line(9, 28, 23, 24, K.WOOD[2]); t.line(9, 27, 23, 23, K.WOOD[4])
		t.line(23, 28, 9, 24, K.WOOD[3]); t.line(23, 27, 9, 23, K.WOOD[5])
		# flames
		var h: int = [12, 14, 11, 13][f]
		var sway: int = [0, 1, 0, -1][f]
		for k in 3:
			var fx := 13 + k * 3 + sway * (1 if k == 1 else 0)
			var fh := h - absi(k - 1) * 4
			t.polygon(PackedVector2Array([Vector2(fx - 2.5, 25), Vector2(fx + sway, 25 - fh), Vector2(fx + 2.5, 25)]), K.FIRE[3])
			t.polygon(PackedVector2Array([Vector2(fx - 1.5, 25), Vector2(fx + sway * 0.5, 25 - fh * 0.65), Vector2(fx + 1.5, 25)]), K.FIRE[5])
			t.px(fx, 24, K.FIRE[6])
		t.px(16 + sway, 25 - h - 2 - f % 2, K.FIRE[4])
		t.px(12 - sway, 25 - h, K.FIRE[5])
		t.outline(K.OUTW)
		c.blit(t.img, o.x, o.y)
	# 4 lamp post
	var o4 := cell(4)
	var lp = PX.Canvas.new(32, 32)
	lp.fill_rect(15, 8, 2, 23, K.METAL[2]); lp.fill_rect(15, 8, 1, 23, K.METAL[4])
	lp.fill_rect(13, 29, 6, 3, K.METAL[2]); lp.fill_rect(13, 29, 6, 1, K.METAL[4])
	lp.fill_rect(15, 6, 6, 1, K.METAL[3])
	K.lantern(lp, 20, 6, 1)
	lp.outline(K.OUT)
	c.blit(lp.img, o4.x, o4.y)
	# 5 fence (tileable)
	var o5 := cell(5)
	var fe = PX.Canvas.new(32, 32)
	for px_ in [3, 19]:
		K.beam(fe, px_, 16, 4, 16, false, px_)
		fe.polygon(PackedVector2Array([Vector2(px_, 16), Vector2(px_ + 2, 13), Vector2(px_ + 4, 16)]), K.WOOD[4])
	K.beam(fe, 0, 19, 32, 3, true, 1)
	K.beam(fe, 0, 25, 32, 3, true, 2)
	c.blit(fe.img, o5.x, o5.y)
	# 6/7 pine tree (top + bottom)
	var tree = PX.Canvas.new(32, 64)
	var PG := K.pal(["0a1e1a", "123228", "1c4a34", "286640", "3a8450", "5aa864"])
	for tier in 5:
		var top_y := 2 + tier * 10
		var half := 5 + tier * 2.6
		var bot_y := top_y + 15
		K.fill_poly_fn(tree, PackedVector2Array([Vector2(16 - half, bot_y), Vector2(16, top_y), Vector2(16 + half, bot_y)]), func(x: int, y: int) -> Color:
			var b := 3
			if x < 15:
				b = 4
			if x > 18:
				b = 2
			if y >= bot_y - 1:
				b = 1
			if PX.hash01(x, y, 91) > 0.82:
				b = maxi(b - 1, 1)
			return PG[b])
		# snow caps
		tree.line(int(16 - half * 0.5), top_y + 8, 16, top_y, Color.html("e8f2ff"))
		tree.px(16, top_y, Color.WHITE)
		for sx in range(int(16 - half) + 1, int(16 - half) + 4):
			tree.px(sx, bot_y - 1, Color.html("c8d8f0"))
	tree.fill_rect(14, 54, 4, 10, K.WOOD[2]); tree.fill_rect(14, 54, 1, 10, K.WOOD[4])
	tree.outline(K.OUT)
	c.blit(tree.img, cell(6).x, cell(6).y, 0, 0, 32, 32)
	c.blit(tree.img, cell(7).x, cell(7).y, 0, 32, 32, 32)
	# 8 bush
	var bu = PX.Canvas.new(32, 32)
	for b in [[10, 25, 7], [20, 24, 8], [15, 21, 7]]:
		bu.circle(b[0], b[1], b[2], PG[2])
	for y in 32:
		for x in 32:
			if bu.get_px(x, y).a > 0.5:
				var l := -(x - 16) * 0.05 - (y - 22) * 0.12 + PX.hash01(x, y, 4) * 0.4
				bu.px(x, y, PG[4] if l > 0.75 else (PG[3] if l > 0.25 else PG[2]))
	bu.fill_rect(4, 31, 24, 1, PG[1])
	for fl in [Vector2i(10, 20), Vector2i(19, 18), Vector2i(23, 24)]:
		bu.px(fl.x, fl.y, K.RED[4]); bu.px(fl.x + 1, fl.y, K.GOLD[4])
	bu.outline(K.OUT)
	c.blit(bu.img, cell(8).x, cell(8).y)
	# 9 rocks
	var ro = PX.Canvas.new(32, 32)
	boulder(ro, 12.0, 26.0, 8.0, 6.0, 3)
	boulder(ro, 22.0, 27.0, 6.0, 5.0, 4)
	boulder(ro, 17.0, 29.0, 4.0, 3.0, 5)
	ro.fill_rect(0, 31, 32, 1, Color(0, 0, 0, 0))
	boulder(ro, 12.0, 25.0, 8.0, 6.0, 3)
	ro.outline(K.OUT)
	c.blit(ro.img, cell(9).x, cell(9).y)
	# 10 crate stack
	var cs = PX.Canvas.new(32, 32)
	crate(cs, 2, 18, 14)
	crate(cs, 16, 20, 12)
	crate(cs, 7, 6, 12)
	cs.outline(K.OUT)
	c.blit(cs.img, cell(10).x, cell(10).y)
	# 11/12 flags
	for f in 2:
		var fl = PX.Canvas.new(32, 32)
		fl.fill_rect(6, 2, 2, 30, K.WOOD[3]); fl.fill_rect(6, 2, 1, 30, K.WOOD[5])
		fl.circle(7, 2, 1.5, K.GOLD[4])
		for x in range(8, 28):
			var wave := sin(float(x) * 0.45 + f * PI) * 1.6
			for y in range(4, 16):
				var yy := int(round(y + wave * float(x - 8) / 20.0))
				var col: Color = K.TEAL[3] if y < 14 else K.GOLD[3]
				if x > 25:
					col = col.darkened(0.15)
				if y == 4:
					col = K.TEAL[4]
				fl.px(x, yy, col)
		# pickaxe emblem
		var ey := int(round(sin(16.0 * 0.45 + f * PI) * 0.6))
		fl.line(14, 12 + ey, 20, 6 + ey, K.WOOD[5])
		fl.line(16, 6 + ey, 21, 9 + ey, K.GOLD[5])
		fl.outline(K.OUT)
		c.blit(fl.img, cell(11 + f).x, cell(11 + f).y)
	# 13 bench
	var be = PX.Canvas.new(32, 32)
	K.beam(be, 2, 22, 28, 3, true, 3)
	K.beam(be, 2, 15, 28, 3, true, 4)
	be.fill_rect(5, 25, 2, 7, K.WOOD[2]); be.fill_rect(25, 25, 2, 7, K.WOOD[2])
	be.fill_rect(5, 18, 2, 4, K.WOOD[2]); be.fill_rect(25, 18, 2, 4, K.WOOD[2])
	be.outline(K.OUT)
	c.blit(be.img, cell(13).x, cell(13).y)
	# 14 barrel stack
	var bs = PX.Canvas.new(32, 32)
	barrel(bs, 3, 19, 11, 13)
	barrel(bs, 17, 19, 11, 13)
	barrel(bs, 10, 6, 11, 13)
	bs.outline(K.OUT)
	c.blit(bs.img, cell(14).x, cell(14).y)
	# 15 sign MINE (arrow right)
	var sg = PX.Canvas.new(32, 32)
	sg.fill_rect(14, 14, 3, 18, K.WOOD[2]); sg.fill_rect(14, 14, 1, 18, K.WOOD[4])
	K.planks(sg, 3, 6, 22, 10, K.WOOD, 3, false, 2, 4)
	sg.polygon(PackedVector2Array([Vector2(25, 5), Vector2(30, 11), Vector2(25, 17)]), K.WOOD[4])
	sg.line(25, 5, 30, 11, K.WOOD[5])
	sg.rect_outline(3, 6, 22, 10, K.WOOD[1])
	K.text(sg, "MINE", 6, 8, K.CLOTH[5], K.F35, 1, K.WOOD[1])
	sg.outline(K.OUT)
	c.blit(sg.img, cell(15).x, cell(15).y)
	# --- extras 16-23
	# 16 wheelbarrow
	var wb = PX.Canvas.new(32, 32)
	wb.polygon(PackedVector2Array([Vector2(6, 16), Vector2(24, 16), Vector2(21, 25), Vector2(9, 25)]), K.METAL[3])
	wb.fill_rect(6, 16, 18, 1, K.METAL[5])
	for g in [[10, 14, K.STONE], [14, 13, K.FIRE], [18, 14, K.STONE]]:
		var gr: Array[Color] = g[2]
		wb.circle(g[0], g[1], 2.6, gr[3]); wb.px(g[0] - 1, g[1] - 1, gr[5])
	wb.line(22, 22, 30, 26, K.WOOD[3]); wb.line(22, 23, 30, 27, K.WOOD[2])
	K.wheel(wb, 9.0, 27.0, 4.0, 0.3, K.METAL)
	wb.outline(K.OUT)
	c.blit(wb.img, cell(16).x, cell(16).y)
	# 17 ore pile
	var op = PX.Canvas.new(32, 32)
	for i in 14:
		var ox2 := 6 + PX.hash01(i, 0, 5) * 20
		var oy2 := 30 - PX.hash01(i, 1, 5) * 8 * (1.0 - absf(ox2 - 16) / 12.0)
		var rr: Array[Color] = [K.STONE, K.RUST, K.STONE, K.GOLD][i % 4]
		op.circle(ox2, oy2, 2.5, rr[3]); op.px(int(ox2) - 1, int(oy2) - 1, rr[rr.size() - 1])
	op.outline(K.OUT)
	c.blit(op.img, cell(17).x, cell(17).y)
	# 18 anvil
	var an = PX.Canvas.new(32, 32)
	an.fill_rect(11, 24, 10, 8, K.WOOD[2]); an.fill_rect(11, 24, 10, 1, K.WOOD[4])
	an.polygon(PackedVector2Array([Vector2(4, 16), Vector2(26, 16), Vector2(26, 19), Vector2(21, 21), Vector2(11, 21), Vector2(8, 19), Vector2(2, 17)]), K.METAL[2])
	an.fill_rect(5, 16, 21, 1, K.METAL[4])
	an.fill_rect(12, 21, 8, 3, K.METAL[1])
	an.line(14, 15, 22, 10, K.WOOD[3]); an.fill_rect(20, 8, 5, 3, K.METAL[3])
	an.outline(K.OUT)
	c.blit(an.img, cell(18).x, cell(18).y)
	# 19 tool rack
	var tr = PX.Canvas.new(32, 32)
	K.beam(tr, 3, 8, 3, 24, false, 1); K.beam(tr, 26, 8, 3, 24, false, 2)
	K.beam(tr, 3, 10, 26, 3, true, 3)
	for i in 3:
		var tx := 9 + i * 7
		tr.line(tx, 12, tx, 28, K.WOOD[4])
		tr.fill_rect(tx - 3, 12, 7, 2, [K.METAL[4], K.RUST[3], K.METAL[5]][i])
	tr.outline(K.OUT)
	c.blit(tr.img, cell(19).x, cell(19).y)
	# 20 ground lantern
	var gl = PX.Canvas.new(32, 32)
	K.lantern(gl, 16, 20, 0, true, false)
	gl.fill_rect(13, 30, 7, 2, K.METAL[2])
	gl.outline(K.OUT)
	c.blit(gl.img, cell(20).x, cell(20).y)
	# 21 crystal rock
	var cr = PX.Canvas.new(32, 32)
	boulder(cr, 16.0, 27.0, 10.0, 5.0, 8)
	K.glow(cr, 16.0, 18.0, 10.0, K.CYAN[3], 0.35)
	K.crystal(cr, 15.0, 25.0, 12.0, 5.0, -0.15, K.BLUE)
	K.crystal(cr, 19.0, 25.0, 8.0, 4.0, 0.45, K.BLUE)
	K.crystal(cr, 11.0, 26.0, 6.0, 3.0, -0.6, K.BLUE)
	cr.outline(K.OUT)
	c.blit(cr.img, cell(21).x, cell(21).y)
	# 22 sacks
	var sk = PX.Canvas.new(32, 32)
	for s in [[10, 25], [21, 25], [15, 18]]:
		sk.ellipse(s[0], s[1], 6.0, 6.5, K.CLOTH[2])
		sk.ellipse(s[0] - 1, s[1] - 1, 4.0, 4.5, K.CLOTH[3])
		sk.px(s[0] - 2, s[1] - 3, K.CLOTH[4])
		sk.fill_rect(s[0] - 1, s[1] - 7, 3, 2, K.CLOTH[1])
	sk.outline(K.OUT)
	c.blit(sk.img, cell(22).x, cell(22).y)
	# 23 water pump / well bucket
	var wp = PX.Canvas.new(32, 32)
	barrel(wp, 9, 18, 14, 14)
	wp.fill_rect(9, 18, 14, 2, K.BLUE[3]); wp.fill_rect(10, 18, 6, 1, K.BLUE[5])
	wp.outline(K.OUT)
	c.blit(wp.img, cell(23).x, cell(23).y)
	return c
