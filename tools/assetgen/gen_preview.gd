## Review-only: composes mock scenes from generated assets into the scratchpad preview folder.
extends SceneTree

const PX = preload("res://px.gd")
const L = preload("res://tilelib.gd")

var terrain: Image
var ores: Image
var walls: Image
var special: Image
var decor: Image

const MAP := [
	"########################",
	"####.....######.....####",
	"##.........##.........##",
	"#...........#..........#",
	"#......................#",
	"##.....#####.......#...#",
	"###...#######.....###..#",
	"#.....#######......#...#",
	"#.......##.............#",
	"#..............##......#",
	"##..........######...###",
	"####.....#############.#",
	"SSSSSSSSSSSSSSSSSSSSSSSS",
	"SSSSSSSSSSSSSSSSSSSSSSSS",
	"########################",
]

func _init() -> void:
	var root := PX.Canvas.PX_out()
	terrain = Image.load_from_file(root.path_join("tilesets/terrain.png"))
	ores = Image.load_from_file(root.path_join("tilesets/ores.png"))
	walls = Image.load_from_file(root.path_join("tilesets/backwalls.png"))
	special = Image.load_from_file(root.path_join("tilesets/special.png"))
	decor = Image.load_from_file(root.path_join("tilesets/decor.png"))
	var B := {
		"stone": {"base": 2, "hard": 3, "ores": [0, 1, 2, 3, 0, 1], "seal": 19, "wall": 0, "floor": [0, 1, 22, 4, 8, 19, 20, 21, 25, 23], "ceil": [26, 27, 30, 31], "support": true},
		"iron": {"base": 4, "hard": 5, "ores": [4, 5, 0, 6, 7, 4], "seal": 20, "wall": 1, "floor": [0, 18, 24, 19, 20, 11, 8, 12], "ceil": [26, 27, 32, 30], "support": true},
		"crystal": {"base": 6, "hard": 7, "ores": [8, 9, 10, 11, 12, 14, 13], "seal": 21, "wall": 2, "floor": [4, 5, 6, 7, 3, 17, 5, 6], "ceil": [29, 26, 29], "support": false},
		"frozen": {"base": 8, "hard": 9, "ores": [15, 16, 17, 18, 19, 13], "seal": 22, "wall": 3, "floor": [9, 10, 4, 9, 10, 0], "ceil": [28, 28, 26], "support": false},
		"magma": {"base": 11, "hard": 12, "ores": [20, 21, 22, 23, 11, 34, 24], "seal": 23, "wall": 4, "floor": [13, 14, 12, 11, 13, 14], "ceil": [33, 26, 33], "support": false, "lava": true},
		"ancient": {"base": 14, "hard": 15, "ores": [25, 26, 27, 28, 29, 30, 33, 31], "seal": 25, "wall": 5, "floor": [15, 16, 17, 24, 16], "ceil": [29, 32], "support": false},
	}
	for key in B.keys():
		scene(key, B[key])
	surface()
	quit()

func solid_at(x: int, y: int) -> bool:
	if y < 0 or y >= MAP.size() or x < 0 or x >= 24:
		return true
	return MAP[y][x] != "."

func scene(key: String, b: Dictionary) -> void:
	var W := 24 * 16
	var H := 15 * 16
	var c := PX.Canvas.new(W, H, Color.BLACK)
	var root := PX.Canvas.PX_out()
	var far := Image.load_from_file(root.path_join("backgrounds/cave_%s_far.png" % key))
	var near := Image.load_from_file(root.path_join("backgrounds/cave_%s_near.png" % key))
	c.img.blit_rect(far, Rect2i(100, 40, W, H), Vector2i.ZERO)
	c.blit(near, 0, 0, 50, 20, W, H)
	var lava_rows := []
	for y in 15:
		for x in 24:
			var ch: String = MAP[y][x]
			if ch == ".":
				var wv := int(L.h01(x, y, 5) * 4)
				c.blit(walls, x * 16, y * 16, wv * 16, int(b.wall) * 16, 16, 16)
	if b.get("lava", false):
		for x in range(14, 18):
			c.blit(special, x * 16, 9 * 16, ((x) % 4) * 16, 32, 16, 16)
	for y in 15:
		for x in 24:
			var ch: String = MAP[y][x]
			if ch == ".":
				continue
			var mat: int = b.base
			if ch == "S":
				mat = b.seal
			elif L.h01(x, y, 9) > 0.78:
				mat = b.hard
			var mask := 0
			if not solid_at(x, y - 1): mask |= 1
			if not solid_at(x + 1, y): mask |= 2
			if not solid_at(x, y + 1): mask |= 4
			if not solid_at(x - 1, y): mask |= 8
			var v := int(L.h01(x, y, 3) * 2)
			c.blit(terrain, x * 16, y * 16, mask * 16, (mat * 2 + v) * 16, 16, 16)
			if ch == "#" and mat == b.base and L.h01(x, y, 11) > 0.72:
				var ol: Array = b.ores
				var o: int = ol[int(L.h01(x, y, 12) * ol.size())]
				c.blit(ores, x * 16, y * 16, int(L.h01(x, y, 13) * 4) * 16, o * 16, 16, 16)
	# decor
	for y in 15:
		for x in 24:
			if solid_at(x, y):
				continue
			var fl: Array = b.floor
			var ce: Array = b.ceil
			if solid_at(x, y + 1) and L.h01(x, y, 21) > 0.55:
				var d: int = fl[int(L.h01(x, y, 22) * fl.size())]
				c.blit(decor, x * 16 - 8, y * 16 - 16, (d % 8) * 32, (d / 8) * 32, 32, 32)
			elif solid_at(x, y - 1) and L.h01(x, y, 23) > 0.6:
				var d2: int = ce[int(L.h01(x, y, 24) * ce.size())]
				c.blit(decor, x * 16 - 8, y * 16, (d2 % 8) * 32, (d2 / 8) * 32, 32, 32)
	if b.support:
		c.blit(decor, 9 * 16 - 8, 7 * 16 - 16, 2 * 32, 4 * 32, 32, 32)
		# ladder + rail + torch
		for yy in range(1, 5):
			c.blit(special, 22 * 16, yy * 16, 16 if yy == 1 else 0, 0, 16, 16)
		for xx in range(1, 7):
			c.blit(special, xx * 16, 4 * 16, (16 if xx == 1 else 0), 16, 16, 16)
		c.blit(special, 3 * 16, 2 * 16, 16, 96, 16, 16)
	L.save_preview(c.img, "scene_%s.png" % key, 2)

func surface() -> void:
	var W := 640
	var H := 360
	var c := PX.Canvas.new(W, H)
	var sky_top := Color.html("1a2a6a")
	var sky_bot := Color.html("6a8ad8")
	for y in H:
		var t := float(y) / H
		var col := L.mix(sky_top, sky_bot, t)
		for x in W:
			c.px(x, y, col)
	var root := PX.Canvas.PX_out()
	var cl := Image.load_from_file(root.path_join("backgrounds/surface_clouds.png"))
	var mf := Image.load_from_file(root.path_join("backgrounds/surface_mountains_far.png"))
	var mn := Image.load_from_file(root.path_join("backgrounds/surface_mountains_near.png"))
	c.blit(cl, 0, 10)
	c.blit(mf, 0, 70)
	c.blit(mn, 0, 140)
	# ground strip
	for x in 40:
		for yy in range(0, 5):
			var mat := 1 if yy == 0 else 0
			var mask := 1 if yy == 0 else 0
			if x == 30 and yy == 0:
				mask = 1 | 2
			if x > 30 and yy == 0:
				continue
			if x > 30 and yy == 1:
				mat = 1
				mask = 1
			var v := int(L.h01(x, yy, 3) * 2)
			c.blit(terrain, x * 16, 280 + yy * 16, mask * 16, (mat * 2 + v) * 16, 16, 16)
	c.blit(decor, 5 * 16, 280 - 32, 7 * 32, 2 * 32, 32, 32)
	c.blit(decor, 12 * 16, 280 - 32, 6 * 32, 2 * 32, 32, 32)
	L.save_preview(c.img, "scene_surface.png", 2)
