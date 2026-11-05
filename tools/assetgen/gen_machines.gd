## Generates the 9 camp machines (320x64 strips: idle + 4 working frames) into assets/sprites/machines/.
extends SceneTree

const PX = preload("res://px.gd")
const K = preload("res://campkit.gd")

func _init() -> void:
	var ids := ["smelter", "crusher", "auto_drill", "advanced_smelter", "gem_polisher", "crystal_extractor", "deep_core_drill", "ore_sorter", "mining_robot"]
	for id in ids:
		var strip = PX.Canvas.new(320, 64)
		for f in 5:
			var t = PX.Canvas.new(64, 64)
			call("draw_" + id, t, f)
			t.outline(K.OUT)
			strip.blit(t.img, f * 64, 0)
		strip.save("sprites/machines/%s.png" % id)
		K.preview(strip.img, "machine_" + id, 3)
	quit()

# --------------------------------------------------------------- shared
func base_slab(c, x0: int = 4, x1: int = 60) -> void:
	for y in range(58, 64):
		for x in range(x0, x1):
			var b := 3
			if y == 58:
				b = 5
			elif y == 59:
				b = 4
			elif y == 63:
				b = 1
			if PX.hash01(x, y, 9) > 0.9:
				b -= 1
			c.px(x, y, K.STONE[b])

func smoke(c, x: float, y: float, r: float, a: float) -> void:
	var S := K.pal(["4a4e5c", "6e7282", "9498a6", "c2c6d0"])
	for yy in range(int(y - r - 1), int(y + r + 2)):
		for xx in range(int(x - r - 1), int(x + r + 2)):
			var d := Vector2(xx + 0.5 - x, yy + 0.5 - y).length()
			if d <= r:
				var l := -(xx - x) * 0.3 - (yy - y) * 0.5
				var col: Color = S[3] if l > r * 0.3 else (S[2] if l > -r * 0.2 else S[1])
				c.blend(xx, yy, K.ci(col, a))

func dust(c, x: int, y: int, f: int, col: Color) -> void:
	for i in 5:
		var dx := int(PX.hash01(i, f, 3) * 10) - 5
		var dy := -int(PX.hash01(i, f, 4) * 6)
		c.px(x + dx, y + dy, K.ci(col, 0.8))

func flame(c, cx: float, base_y: float, h: float, w: float, f: int, hot: Array[Color]) -> void:
	var sway: float = [0.0, 1.0, -0.5, 0.5, -1.0][f]
	for k in 3:
		var fx := cx - w * 0.4 + k * w * 0.4
		var fh := h * (1.0 - absf(k - 1) * 0.35) * (0.85 + PX.hash01(k, f, 7) * 0.3)
		c.polygon(PackedVector2Array([Vector2(fx - w * 0.35, base_y), Vector2(fx + sway, base_y - fh), Vector2(fx + w * 0.35, base_y)]), hot[3])
		c.polygon(PackedVector2Array([Vector2(fx - w * 0.2, base_y), Vector2(fx + sway * 0.6, base_y - fh * 0.62), Vector2(fx + w * 0.2, base_y)]), hot[5])
	c.fill_rect(int(cx - w * 0.6), int(base_y) - 1, int(w * 1.2), 2, hot[6])

# --------------------------------------------------------------- 1 smelter
func draw_smelter(c, f: int) -> void:
	var on := f > 0
	base_slab(c)
	# chimney
	K.bricks(c, 40, 8, 9, 17, K.STONE, 5, 3, 31)
	c.fill_rect(38, 6, 13, 3, K.METAL[3]); c.fill_rect(38, 6, 13, 1, K.METAL[5])
	# dome + body
	K.fill_poly_fn(c, PackedVector2Array([Vector2(7, 58), Vector2(7, 26), Vector2(12, 18), Vector2(22, 14), Vector2(34, 14), Vector2(44, 18), Vector2(49, 26), Vector2(49, 58)]), func(x: int, y: int) -> Color:
		var row := y / 4
		var off := (row % 2) * 3
		var col := (x + off) / 6
		var v := PX.hash01(col, row, 17)
		var b := 3 if v > 0.4 else 2
		if v > 0.85:
			b = 4
		if y % 4 == 0 or (x + off) % 6 == 0:
			b = 1
		if x < 12 and y % 4 != 0:
			b += 1
		if x > 44:
			b = maxi(b - 1, 1)
		return K.STONE[b])
	# rim band
	c.fill_rect(6, 30, 44, 3, K.METAL[3]); c.fill_rect(6, 30, 44, 1, K.METAL[5])
	# fire mouth
	for y in range(37, 56):
		for x in range(17, 39):
			var dx := (x - 27.5) / 10.5
			var dy := (y - 44.0) / 8.0
			if y < 44 and dx * dx + dy * dy > 1.0:
				continue
			c.px(x, y, K.FIRE[1] if on else Color.html("1a0806"))
	if on:
		K.glow(c, 28.0, 50.0, 16.0, K.FIRE[4], 0.45)
		flame(c, 28.0, 54.0, 14.0 + (f % 2) * 2.0, 14.0, f, K.FIRE)
	else:
		for i in 7:
			c.px(19 + i * 3, 54 - (i % 2), K.FIRE[2])
			c.px(20 + i * 3, 54, K.FIRE[1])
	# mouth arch stones
	for a in range(0, 13):
		var ang := PI + a * PI / 12.0
		var ax := 27.5 + cos(ang) * 11.5
		var ay := 44.0 + sin(ang) * 9.0
		c.fill_rect(int(ax), int(ay), 2, 2, K.STONE[5] if a < 6 else K.STONE[4])
	c.fill_rect(15, 55, 26, 3, K.STONE[4]); c.fill_rect(15, 55, 26, 1, K.STONE[5])
	# output tray + ingots
	K.plate(c, 50, 48, 12, 10, K.METAL, 3, false)
	c.fill_rect(51, 48, 10, 2, K.FIRE[4] if on else K.METAL[1])
	if on:
		c.fill_rect(46 + 0, 44, 5, 2, K.FIRE[5])
		c.px(52, 46 + (f % 2), K.FIRE[5])
	for i in 2:
		c.fill_rect(51 + i * 5, 44 - i * 0, 4, 3, K.GOLD[3] if i == 0 else K.RUST[4])
		c.px(51 + i * 5, 44, K.GOLD[5] if i == 0 else K.RUST[4].lightened(0.3))
	# smoke
	if on:
		for i in 3:
			var t := fposmod((f - 1) * 0.25 + i * 0.33, 1.0)
			smoke(c, 44.5 + sin(t * 6.0) * 1.5, 4.0 - t * 4.0, 1.8 + t * 2.2, 0.85 - t * 0.45)
	K.light(c, 28, 46, 20.0, K.FIRE[4], 0.3 if on else 0.08)

# --------------------------------------------------------------- 2 crusher
func draw_crusher(c, f: int) -> void:
	var on := f > 0
	var ph := (f - 1) * PI / 8.0 if on else 0.0
	base_slab(c)
	# legs
	K.plate(c, 10, 46, 5, 12, K.METAL, 2, false)
	K.plate(c, 47, 46, 5, 12, K.METAL, 2, false)
	# body
	K.plate(c, 8, 26, 46, 22, K.METAL, 3)
	# window into rollers
	c.fill_rect(13, 29, 36, 16, K.NAVY[1])
	K.gear(c, 24.0, 37.0, 7.0, 9, ph, K.METAL)
	K.gear(c, 38.0, 37.0, 7.0, 9, -ph + 0.35, K.RUST)
	if on:
		for i in 4:
			var rx := 29 + int(PX.hash01(i, f, 2) * 4)
			var ry := 30 + int(PX.hash01(i, f, 3) * 6)
			c.px(rx, ry, K.STONE[4])
	c.rect_outline(12, 28, 38, 18, K.METAL[1])
	# hopper
	c.polygon(PackedVector2Array([Vector2(4, 9), Vector2(58, 9), Vector2(48, 27), Vector2(14, 27)]), K.METAL[3])
	c.polygon(PackedVector2Array([Vector2(4, 9), Vector2(12, 9), Vector2(18, 27), Vector2(14, 27)]), K.METAL[4])
	c.polygon(PackedVector2Array([Vector2(52, 9), Vector2(58, 9), Vector2(48, 27), Vector2(45, 27)]), K.METAL[2])
	c.fill_rect(3, 8, 56, 2, K.METAL[5])
	K.plate(c, 20, 15, 22, 5, K.GOLD, 3, false)
	for x in range(21, 41):
		if int((x + 15) / 3) % 2 == 0:
			c.fill_rect(x, 16, 1, 3, K.NAVY[0])
	# rocks heap in hopper
	for i in 9:
		var rx := 9.0 + i * 5.2
		var ry := 7.0 - (1.0 if i % 2 == 0 else 0.0) - (float(f % 2) if on and i % 3 == f % 3 else 0.0)
		c.circle(rx, ry, 2.8, K.STONE[3])
		c.px(int(rx) - 1, int(ry) - 1, K.STONE[5])
	# chute + gravel pile
	c.polygon(PackedVector2Array([Vector2(8, 44), Vector2(16, 44), Vector2(8, 54), Vector2(2, 54)]), K.METAL[2])
	for i in 10:
		var gx := 2 + int(PX.hash01(i, 0, 8) * 10)
		var gy := 57 - int(PX.hash01(i, 1, 8) * 3)
		c.fill_rect(gx, gy, 2, 1, K.STONE[3 + (i % 2)])
	if on:
		for i in 3:
			c.px(5 + i, 54 + ((f + i) % 3), K.STONE[4])
		dust(c, 6, 54, f, K.STONE[5])
	# motor + belt
	K.plate(c, 50, 30, 10, 12, K.METAL, 2)
	c.px(55, 33, K.GREEN[5] if on else K.RED[3])
	c.line(54, 36, 38, 30, K.NAVY[0])
	K.light(c, 55, 33, 4.0, K.GREEN[5] if on else K.RED[3], 0.4)

# --------------------------------------------------------------- 3 auto drill
func draw_auto_drill(c, f: int) -> void:
	var on := f > 0
	var bob: int = [0, 1, 2, 1, 0][f]
	base_slab(c)
	# derrick legs
	c.line(16, 58, 28, 2, K.METAL[2]); c.line(17, 58, 29, 2, K.METAL[4])
	c.line(48, 58, 36, 2, K.METAL[2]); c.line(47, 58, 35, 2, K.METAL[3])
	for y in range(10, 56, 8):
		var t := float(y - 2) / 56.0
		var lx := int(28.0 - t * 12.0)
		var rx := int(36.0 + t * 12.0)
		c.line(lx, y, rx, y, K.METAL[3])
		c.line(lx, y, rx, y + 8, K.METAL[2])
	c.fill_rect(25, 1, 14, 3, K.GOLD[3]); c.fill_rect(25, 1, 14, 1, K.GOLD[5])
	# drill shaft + bit
	c.fill_rect(31, 4, 2, 40, K.METAL[4])
	for y in range(44 + bob, 63):
		var w := int(maxf(1.0, 6.0 - (y - 44 - bob) * 0.3))
		for x in range(32 - w, 32 + w):
			var stripe := int((y + x * 0.5 + (f * 2 if on else 0))) % 4 < 2
			c.px(x, y, K.METAL[5] if stripe else K.METAL[2])
	c.fill_rect(26, 58, 12, 6, K.NAVY[0])
	for y in range(58, 64):
		var w2 := int(maxf(1.0, 6.0 - (y - 44 - bob) * 0.3))
		for x in range(32 - w2, 32 + w2):
			c.px(x, y, K.METAL[3].darkened(0.4))
	# motor block (bobs)
	K.plate(c, 24, 18 + bob, 16, 12, K.RUST, 3)
	c.fill_rect(27, 21 + bob, 10, 3, K.NAVY[1])
	c.px(28, 22 + bob, K.GREEN[5] if on and f % 2 == 1 else K.GREEN[2])
	c.px(31, 22 + bob, K.GOLD[4] if on else K.GOLD[1])
	# engine box left
	K.plate(c, 2, 42, 16, 16, K.METAL, 3)
	c.circle(8.0, 48.0, 3.0, K.CLOTH[5]); c.line(8, 48, 10 if on else 7, 46 if on else 46, K.RED[3])
	c.fill_rect(12, 46, 4, 8, K.NAVY[1])
	c.fill_rect(13, 38, 3, 5, K.METAL[2])
	if on:
		smoke(c, 14.5, 35.0 - (f % 2), 2.0 + (f % 3) * 0.5, 0.7)
		dust(c, 32, 58, f, K.STONE[5])
		for i in 3:
			c.px(26 + int(PX.hash01(i, f, 1) * 12), 56 - int(PX.hash01(i, f, 2) * 3), K.GOLD[5])

# --------------------------------------------------------------- 4 advanced smelter
func draw_advanced_smelter(c, f: int) -> void:
	var on := f > 0
	base_slab(c, 2, 62)
	# pipes / chimneys
	for px_ in [12, 46]:
		K.plate(c, px_, 8, 6, 12, K.METAL, 2, false)
		c.fill_rect(px_ - 1, 8, 8, 2, K.METAL[4])
	# body
	K.plate(c, 4, 16, 56, 42, K.METAL, 3)
	for x in range(6, 58, 10):
		c.fill_rect(x, 18, 1, 38, K.METAL[2])
	c.fill_rect(4, 16, 56, 2, K.GOLD[3]); c.fill_rect(4, 16, 56, 1, K.GOLD[5])
	# porthole
	c.circle(32.0, 33.0, 12.0, K.METAL[1])
	c.circle(32.0, 33.0, 10.5, K.METAL[4])
	c.circle(32.0, 33.0, 9.0, Color.html("0a0e22") if not on else K.CYAN[1])
	if on:
		K.glow(c, 32.0, 33.0, 16.0, K.CYAN[3], 0.35)
		var hot := K.pal(["0a3a6a", "1a6ab0", "2aa8e0", "5ff2ff", "a8fbff", "e0ffff", "ffffff"])
		flame(c, 32.0, 40.0, 12.0 + (f % 2) * 2.0, 12.0, f, hot)
	else:
		c.fill_rect(26, 39, 12, 2, K.FIRE[1])
	c.line(26, 27, 29, 25, Color(1, 1, 1, 0.6))
	# bolts around porthole
	for i in 8:
		var a := i * TAU / 8.0
		c.px(int(32 + cos(a) * 11.0), int(33 + sin(a) * 11.0), K.METAL[6])
	# molten channel + mold
	c.fill_rect(8, 50, 48, 4, K.METAL[1])
	for x in range(9, 55):
		var flow := on and int((x - f * 3) / 3) % 3 != 0
		c.px(x, 51, K.FIRE[5] if flow else (K.FIRE[3] if on else K.FIRE[1]))
		c.px(x, 52, K.FIRE[4] if on else K.FIRE[1])
	if on:
		K.glow(c, 32.0, 52.0, 12.0, K.FIRE[4], 0.25)
	# gauges
	for gx in [10, 50]:
		c.circle(gx + 0.5, 24.5, 3.0, K.CLOTH[5])
		c.circle(gx + 0.5, 24.5, 3.0, K.METAL[1], false)
		c.line(gx, 24, gx + (2 if on else -1), 22, K.RED[3])
	# steam
	if on:
		for i in 2:
			var t := fposmod((f - 1) * 0.25 + i * 0.5, 1.0)
			smoke(c, 15.0 + i * 34.0, 5.0 - t * 4.0, 1.6 + t * 1.8, 0.8 - t * 0.4)

# --------------------------------------------------------------- 5 gem polisher
func draw_gem_polisher(c, f: int) -> void:
	var on := f > 0
	var ph := (f - 1) * PI / 10.0 if on else 0.0
	base_slab(c)
	# table
	K.planks(c, 3, 40, 58, 5, K.WOOD, 4, false, 6, 4)
	c.fill_rect(3, 40, 58, 1, K.WOOD[6])
	K.beam(c, 6, 45, 4, 13, false, 2); K.beam(c, 54, 45, 4, 13, false, 3)
	c.fill_rect(10, 52, 44, 2, K.WOOD[2])
	# wheel stand
	K.plate(c, 20, 28, 8, 12, K.METAL, 2, false)
	# wheel (blue gem stone)
	var W := K.pal(["0c1a40", "17337e", "2560e0", "3f96ff", "5fe6ff", "b8fbff"])
	c.circle(24.0, 22.0, 13.0, W[1])
	c.circle(24.0, 22.0, 12.0, W[3])
	for i in 6:
		var a := ph + i * TAU / 6.0
		c.line(24, 22, int(24 + cos(a) * 11.0), int(22 + sin(a) * 11.0), W[2])
	for yy in range(10, 34):
		for xx in range(12, 37):
			var d := Vector2(xx + 0.5 - 24.0, yy + 0.5 - 22.0)
			if d.length() < 12.0 and d.length() > 10.0 and d.y < -2.0:
				c.px(xx, yy, W[5])
	c.circle(24.0, 22.0, 3.0, K.METAL[2]); c.px(24, 22, K.METAL[6])
	# motor + belt
	K.plate(c, 44, 28, 12, 12, K.METAL, 3)
	c.circle(50.0, 34.0, 3.0, K.METAL[1]); c.px(50, 34, K.GOLD[4])
	c.line(26, 20, 50, 31, K.NAVY[0]); c.line(26, 24, 50, 37, K.NAVY[0])
	c.px(53, 30, K.GREEN[5] if on else K.RED[3])
	# gem holder + gem against wheel
	c.fill_rect(36, 30, 6, 3, K.WOOD[3])
	c.polygon(PackedVector2Array([Vector2(35, 28), Vector2(37, 25), Vector2(39, 28), Vector2(37, 30)]), K.PURP[4])
	c.px(37, 26, K.PURP[6])
	# polished gems tray
	K.bevel_rect(c, 6, 36, 12, 4, K.WOOD, 2)
	var gcols := [K.RED, K.GREEN, K.BLUE]
	for i in 3:
		var g: Array[Color] = gcols[i]
		c.fill_rect(7 + i * 4, 35, 3, 2, g[4]); c.px(7 + i * 4, 35, g[g.size() - 1])
	if on:
		for i in 6:
			var t := PX.hash01(i, f, 21)
			var sx := 36 + int(t * 10)
			var sy := 24 - int(PX.hash01(i, f, 22) * 10)
			c.px(sx, sy, K.CYAN[4] if i % 2 == 0 else Color.WHITE)
		K.sparkle(c, 40 + f, 18 - f, K.CYAN[4])

# --------------------------------------------------------------- 6 crystal extractor
func arc(c, a: Vector2, b: Vector2, f: int, col: Color) -> void:
	var prev := a
	for i in range(1, 7):
		var t := i / 6.0
		var p := a.lerp(b, t)
		if i < 6:
			p += Vector2(0, (PX.hash01(i, f, 31) - 0.5) * 7.0)
		c.line(int(prev.x), int(prev.y), int(p.x), int(p.y), col)
		prev = p

func draw_crystal_extractor(c, f: int) -> void:
	var on := f > 0
	base_slab(c)
	# base housing
	K.plate(c, 14, 48, 36, 10, K.METAL, 3)
	c.fill_rect(18, 52, 28, 2, K.CYAN[2] if on else K.NAVY[3])
	# tank
	var pulse: float = [0.0, 0.2, 0.45, 0.3, 0.1][f]
	for y in range(10, 48):
		for x in range(20, 44):
			var u := (x - 20) / 24.0
			var shade := 0.6 + sin(u * PI) * 0.4
			var liquid := y > 16
			var col: Color
			if liquid:
				col = K.PURP[2].lerp(K.CYAN[2], float(y - 16) / 32.0)
				col = col.lightened((pulse if on else 0.0) * 0.35)
				col = col.darkened(1.0 - shade)
			else:
				col = K.GLASS[1].darkened(1.0 - shade)
			c.px(x, y, col)
	# glass highlights
	c.fill_rect(22, 12, 1, 34, Color(1, 1, 1, 0.45))
	c.fill_rect(24, 12, 1, 34, Color(1, 1, 1, 0.2))
	c.fill_rect(41, 12, 1, 34, Color(0, 0, 0, 0.3))
	# floating crystal
	var fy := 30.0 - (f % 2 if on else 0)
	K.glow(c, 32.0, fy - 4.0, 12.0, K.CYAN[4], 0.35 + pulse)
	K.crystal(c, 32.0, fy + 6.0, 14.0, 7.0, 0.0, K.BLUE)
	K.crystal(c, 32.0, fy + 6.0, 9.0, 6.0, PI, K.BLUE)
	# bubbles
	if on:
		for i in 5:
			var bx := 23 + int(PX.hash01(i, 0, 5) * 18)
			var by := 46 - int(fposmod(PX.hash01(i, 1, 5) * 30.0 + f * 7.0, 30.0))
			c.px(bx, by, K.CYAN[5])
	# caps
	K.plate(c, 17, 6, 30, 6, K.METAL, 3)
	K.plate(c, 17, 45, 30, 4, K.METAL, 2, false)
	c.fill_rect(30, 2, 4, 4, K.METAL[2]); c.fill_rect(31, 0, 2, 2, K.GOLD[4])
	# tesla coils
	for cx in [7, 56]:
		K.plate(c, cx - 3, 46, 7, 12, K.METAL, 2, false)
		for y in range(30, 46, 2):
			c.fill_rect(cx - 2, y, 5, 1, K.RUST[4])
			c.fill_rect(cx - 2, y + 1, 5, 1, K.RUST[2])
		c.circle(cx + 0.5, 27.5, 3.5, K.METAL[4])
		c.px(cx - 1, 26, K.METAL[6])
		if on:
			K.glow(c, cx + 0.5, 27.5, 6.0, K.PURP[5], 0.4)
	if on:
		arc(c, Vector2(10, 27), Vector2(20, 22 + f), f, K.PURP[6])
		arc(c, Vector2(54, 27), Vector2(43, 24 - f), f + 9, K.CYAN[5])

# --------------------------------------------------------------- 7 deep core drill
func draw_deep_core_drill(c, f: int) -> void:
	var on := f > 0
	var pulse: float = [0.0, 0.3, 0.6, 0.4, 0.15][f]
	var A := K.pal(["10141c", "1e2632", "2e3a4a", "445468", "607890", "8aa4bc"])
	# hole
	c.fill_rect(20, 58, 24, 6, K.NAVY[0])
	base_slab(c, 2, 20); base_slab(c, 44, 62)
	# tri-cone bit
	for y in range(44, 64):
		var w := int(maxf(1.0, 9.0 - (y - 44) * 0.4))
		for x in range(32 - w, 32 + w):
			var stripe := int(x + y + (f * 2 if on else 0)) % 5 < 2
			var col: Color = K.GOLD[4] if stripe else K.GOLD[2]
			if y >= 58:
				col = col.darkened(0.5)
			c.px(x, y, col)
	# heavy frame
	K.plate(c, 6, 14, 52, 32, A, 3)
	K.plate(c, 2, 38, 10, 20, A, 2)
	K.plate(c, 52, 38, 10, 20, A, 2)
	# glowing circuit lines
	var glowc: Color = K.TEAL[5].lerp(Color.WHITE, pulse * 0.4) if on else K.TEAL[2]
	for y in [20, 40]:
		c.fill_rect(8, y, 48, 1, glowc)
	c.fill_rect(10, 20, 1, 20, glowc); c.fill_rect(53, 20, 1, 20, glowc)
	for gx in [16, 24, 40, 48]:
		c.fill_rect(gx, 22, 1, 4, K.FIRE[4] if on else K.FIRE[1])
	# reactor core
	K.glow(c, 32.0, 28.0, 14.0 + pulse * 4.0, K.FIRE[4] if on else K.FIRE[1], 0.35 + pulse * 0.3)
	c.circle(32.0, 28.0, 8.0, A[1])
	c.circle(32.0, 28.0, 6.0, K.FIRE[3] if on else K.FIRE[1])
	c.circle(32.0, 28.0, 3.5, K.FIRE[5] if on else K.FIRE[2])
	c.px(31, 26, Color.WHITE if on else K.FIRE[3])
	# top housing
	c.polygon(PackedVector2Array([Vector2(12, 14), Vector2(20, 5), Vector2(44, 5), Vector2(52, 14)]), A[3])
	c.line(20, 5, 44, 5, A[5])
	c.fill_rect(28, 1, 8, 4, A[2]); c.fill_rect(29, 1, 6, 1, K.TEAL[4] if on else K.TEAL[1])
	for x in range(14, 50):
		if x % 6 == 0:
			c.fill_rect(x, 8, 2, 4, A[1])
	if on:
		dust(c, 32, 58, f, K.STONE[5])
		for i in 3:
			c.px(22 + int(PX.hash01(i, f, 4) * 20), 56 - int(PX.hash01(i, f, 5) * 4), K.FIRE[5])

# --------------------------------------------------------------- 8 ore sorter
func draw_ore_sorter(c, f: int) -> void:
	var on := f > 0
	base_slab(c)
	# legs
	for lx in [6, 30, 54]:
		c.fill_rect(lx, 46, 3, 12, K.METAL[2]); c.fill_rect(lx, 46, 1, 12, K.METAL[4])
	# bins under belt (right side)
	var bins := [[36, K.RED], [46, K.BLUE], [56, K.GOLD]]
	# belt
	c.fill_rect(2, 40, 60, 6, K.METAL[1])
	for x in range(3, 61):
		var seg := int(x + (f * 2 if on else 0)) % 4
		c.px(x, 40, K.NAVY[2] if seg == 0 else K.NAVY[3])
		c.px(x, 41, K.NAVY[1])
	for rx in range(5, 62, 8):
		var r := 2.0
		c.circle(rx + 0.5, 43.5, r, K.METAL[3])
		var a := (f * 0.8) + rx
		c.px(int(rx + cos(a) * 1.5), int(43 + sin(a) * 1.5), K.METAL[6])
	# ore items on belt
	var ores := [K.RUST, K.STONE, K.GOLD, K.BLUE, K.STONE]
	for i in 5:
		var ix := fposmod(4.0 + i * 11.0 + (f * 3.0 if on else 0.0), 58.0) + 2.0
		var r2: Array[Color] = ores[i]
		c.fill_rect(int(ix), 37, 4, 3, r2[3]); c.px(int(ix), 37, r2[5])
	# scanner arch
	K.plate(c, 20, 16, 4, 24, K.METAL, 3, false)
	K.plate(c, 38, 16, 4, 24, K.METAL, 3, false)
	K.plate(c, 18, 12, 26, 7, K.METAL, 3)
	c.fill_rect(22, 14, 18, 2, K.NAVY[1])
	for i in 3:
		c.px(24 + i * 6, 14, [K.RED[4], K.GREEN[5], K.BLUE[4]][i] if on else K.NAVY[4])
	if on:
		var beam_a := 0.25 if f % 2 == 0 else 0.4
		for y in range(19, 40):
			for x in range(25, 37):
				c.blend(x, y, Color(1.0, 0.3, 0.3, beam_a * (1.0 - absf(x - 30.5) / 6.0)))
		c.fill_rect(30, 19, 1, 21, K.RED[5])
	# chutes to bins
	for b in bins:
		var bx: int = b[0]
		var br: Array[Color] = b[1]
		K.bevel_rect(c, bx - 4, 48, 9, 10, br, 3)
		c.fill_rect(bx - 4, 48, 9, 1, br[5])
		c.fill_rect(bx - 2, 49, 5, 2, K.NAVY[1])
	# control box
	K.plate(c, 2, 22, 14, 14, K.METAL, 3)
	c.fill_rect(4, 24, 10, 5, K.NAVY[1])
	c.fill_rect(5, 26, 1 + (f * 2 if on else 0), 1, K.GREEN[5])
	c.px(5, 32, K.RED[4]); c.px(9, 32, K.GOLD[4] if on else K.GOLD[1]); c.px(13, 32, K.GREEN[5] if on else K.GREEN[2])

# --------------------------------------------------------------- 9 mining robot
func draw_mining_robot(c, f: int) -> void:
	var on := f > 0
	var arm_ang: float = [0.2, -0.5, 0.1, 0.7, 0.1][f]
	var hop := 1 if (on and f % 2 == 0) else 0
	base_slab(c)
	var Y := K.pal(["4a2a06", "7a4a0a", "b07414", "e0a020", "ffcc44", "fff0a0"])
	# treads
	K.plate(c, 12, 50 - hop + hop, 40, 8, K.METAL, 1, false)
	for wx in [16, 24, 32, 40, 48]:
		c.circle(wx + 0.5, 54.5, 2.6, K.METAL[3])
		var a: float = (f * 0.9) + wx
		c.px(int(wx + cos(a) * 1.6), int(54 + sin(a) * 1.6), K.METAL[6])
	for x in range(12, 52):
		if int(x + (f * 2 if on else 0)) % 3 == 0:
			c.px(x, 50, K.METAL[4])
	# body
	var by := 26 - hop
	K.plate(c, 16, by, 32, 24, Y, 3)
	for x in range(17, 47):
		if int((x + 0) / 3) % 2 == 0:
			c.fill_rect(x, by + 19, 1, 3, K.NAVY[0])
	c.fill_rect(20, by + 4, 12, 9, K.NAVY[1])
	for i in 3:
		c.fill_rect(22, by + 6 + i * 2, 2 + (i * 3 + f) % 8, 1, K.GREEN[5] if on else K.GREEN[2])
	c.circle(40.0, by + 8.0, 3.0, K.METAL[2]); c.px(40, by + 8, K.RED[4] if on else K.RED[2])
	# ore bin on back
	K.plate(c, 8, by + 6, 9, 12, K.METAL, 2, false)
	for i in 3:
		c.fill_rect(9 + i * 2, by + 4 - (i % 2), 3, 3, [K.RUST[3], K.STONE[4], K.GOLD[4]][i])
	# head
	K.plate(c, 22, by - 15, 20, 15, Y, 4)
	c.fill_rect(25, by - 12, 14, 8, K.NAVY[0])
	var blink := f == 3
	if blink:
		c.fill_rect(27, by - 8, 4, 1, K.CYAN[4]); c.fill_rect(33, by - 8, 4, 1, K.CYAN[4])
	else:
		c.fill_rect(27, by - 10, 4, 3, K.CYAN[4]); c.fill_rect(33, by - 10, 4, 3, K.CYAN[4])
		c.px(27, by - 10, Color.WHITE); c.px(33, by - 10, Color.WHITE)
	K.glow(c, 32.0, by - 8.0, 8.0, K.CYAN[4], 0.2)
	# antenna
	c.fill_rect(31, by - 21, 1, 6, K.METAL[4])
	c.fill_rect(30, by - 23, 3, 2, K.RED[5] if (on and f % 2 == 1) else K.RED[2])
	if on and f % 2 == 1:
		K.glow(c, 31.5, by - 22.0, 4.0, K.RED[4], 0.5)
	# arm with drill
	var sh := Vector2(48, by + 6)
	var dir := Vector2(cos(arm_ang), sin(arm_ang))
	var elbow := sh + dir * 6.0
	var hand := elbow + Vector2(dir.x * 0.6 + 0.5, dir.y * 0.6 + 0.8).normalized() * 5.0
	for t in 3:
		c.line(int(sh.x), int(sh.y) + t - 1, int(elbow.x), int(elbow.y) + t - 1, K.METAL[3 + (1 if t == 0 else 0)])
		c.line(int(elbow.x), int(elbow.y) + t - 1, int(hand.x), int(hand.y) + t - 1, K.METAL[3 + (1 if t == 0 else 0)])
	c.circle(sh.x, sh.y, 2.5, Y[2])
	c.circle(elbow.x, elbow.y, 2.0, K.METAL[2])
	# drill bit cone pointing down-right
	var tip := hand + Vector2(4, 6)
	c.polygon(PackedVector2Array([hand + Vector2(-3, 0), hand + Vector2(3, -2), tip]), K.METAL[5])
	c.line(int(hand.x), int(hand.y), int(tip.x), int(tip.y), K.METAL[3])
	if on and f != 2:
		for i in 4:
			c.px(int(tip.x) + int(PX.hash01(i, f, 6) * 6) - 2, int(tip.y) + int(PX.hash01(i, f, 7) * 4) - 1, K.GOLD[5] if i % 2 else Color.WHITE)
