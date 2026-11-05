extends Node2D
## Screen-space layered background (lives in a CanvasLayer behind the world):
## sky gradient with day/night, stars, sun & moon, drifting clouds, parallax mountains above
## the ground line; per-biome parallax cave layers below it (crossfaded near biome borders).

var camera: Camera2D
var day_time := 0.3          # 0..1
var night := 0.0             # 0 day .. 1 night
var biome_tint := Color(1, 1, 1)
var _t := 0.0
var _far: Texture2D
var _near: Texture2D
var _clouds: Texture2D
var _cave_far: Dictionary = {}
var _cave_near: Dictionary = {}
var _stars: PackedVector2Array = PackedVector2Array()
var _star_tw: PackedFloat32Array = PackedFloat32Array()
var _sun: Texture2D

const SKY := {
	"night_top": Color("070b22"), "night_bottom": Color("1c2350"),
	"dawn_top": Color("2a3a7a"), "dawn_bottom": Color("ff9a6a"),
	"day_top": Color("3a78d8"), "day_bottom": Color("a8d8ff"),
	"dusk_top": Color("2a2060"), "dusk_bottom": Color("ff7a5a"),
}

func _ready() -> void:
	_far = ResourceDatabase.tex("res://assets/backgrounds/surface_mountains_far.png")
	_near = ResourceDatabase.tex("res://assets/backgrounds/surface_mountains_near.png")
	_clouds = ResourceDatabase.tex("res://assets/backgrounds/surface_clouds.png")
	for b in ResourceDatabase.biomes:
		_cave_far[b.index] = ResourceDatabase.tex("res://assets/backgrounds/cave_%s_far.png" % b.key)
		_cave_near[b.index] = ResourceDatabase.tex("res://assets/backgrounds/cave_%s_near.png" % b.key)
	_sun = load("res://scripts/world/world_renderer.gd").make_radial_texture(64, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		_stars.append(Vector2(rng.randf() * 640.0, rng.randf() * 220.0))
		_star_tw.append(rng.randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

static func sky_colors(t: float) -> Array:
	## Returns [top, bottom] sky colours for a time of day (0..1).
	var h := t * 24.0
	var keys := [[0.0, "night"], [5.0, "night"], [6.5, "dawn"], [8.5, "day"], [17.0, "day"], [19.0, "dusk"], [20.5, "night"], [24.0, "night"]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var f := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			f = f * f * (3.0 - 2.0 * f)
			return [(SKY[a[1] + "_top"] as Color).lerp(SKY[b[1] + "_top"], f), (SKY[a[1] + "_bottom"] as Color).lerp(SKY[b[1] + "_bottom"], f)]
	return [SKY.night_top, SKY.night_bottom]

func _draw() -> void:
	if camera == null:
		return
	var vp := get_viewport_rect().size
	var zoom := camera.zoom.x
	var view := vp / zoom
	var cam := camera.get_screen_center_position()
	var top_left := cam - view * 0.5
	# screen y of the ground line (world y = 0), in screen pixels
	var ground_y := (0.0 - top_left.y) * zoom
	var under_tint := biome_tint
	# ---- underground layers
	if ground_y < vp.y:
		var depth_px := maxf(cam.y, 0.0)
		var row := int(depth_px / 16.0)
		var bi := maxi(0, ResourceDatabase.biome_index_for_row(row))
		var bnext := bi
		var blend := 0.0
		var b := ResourceDatabase.biome(bi)
		if not b.is_empty():
			var bottom_row: int = int(b.rows[1])
			if row > bottom_row - 18 and bi < ResourceDatabase.biomes.size() - 1:
				bnext = bi + 1
				blend = clampf(float(row - (bottom_row - 18)) / 24.0, 0.0, 1.0)
		var y0 := maxf(ground_y, 0.0)
		_draw_cave(bi, top_left, zoom, vp, y0, under_tint, 1.0 - blend)
		if blend > 0.0:
			_draw_cave(bnext, top_left, zoom, vp, y0, under_tint, blend)
	# ---- sky
	if ground_y > 0.0:
		var sc := sky_colors(day_time)
		var h := minf(ground_y, vp.y)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, h), Vector2(0, h)])
		var horizon_t := clampf(h / maxf(ground_y, 1.0), 0.0, 1.0)
		var bottom_col: Color = (sc[0] as Color).lerp(sc[1], horizon_t)
		draw_polygon(pts, PackedColorArray([sc[0], sc[0], bottom_col, bottom_col]))
		# stars
		if night > 0.05:
			for i in _stars.size():
				var sp := _stars[i] + Vector2(-top_left.x * 0.02, 0)
				sp.x = fposmod(sp.x, vp.x)
				sp.y = sp.y * (ground_y / 260.0)
				if sp.y < ground_y - 40.0:
					var a := night * (0.5 + 0.5 * sin(_t * 2.0 + _star_tw[i]))
					var sz := 1.0 if i % 7 != 0 else 2.0
					draw_rect(Rect2(floor(sp.x), floor(sp.y), sz, sz), Color(1, 1, 0.95, a))
		# sun / moon arc
		var ang := (day_time - 0.25) * TAU
		var arc_c := Vector2(vp.x * 0.5, ground_y + 40.0)
		var arc_r := Vector2(vp.x * 0.55, maxf(ground_y - 30.0, 40.0) + 40.0)
		var sun_p := arc_c + Vector2(cos(ang + PI) * arc_r.x, -sin(ang) * arc_r.y)
		if sin(ang) > -0.1:
			draw_texture_rect(_sun, Rect2(sun_p - Vector2(40, 40), Vector2(80, 80)), false, Color(1, 0.85, 0.5, 0.45))
			draw_circle(sun_p, 9.0, Color("fff1b0"))
			draw_circle(sun_p, 7.0, Color("ffe070"))
		var moon_p := arc_c + Vector2(cos(ang) * arc_r.x, sin(ang) * arc_r.y)
		if -sin(ang) > -0.1:
			draw_texture_rect(_sun, Rect2(moon_p - Vector2(30, 30), Vector2(60, 60)), false, Color(0.7, 0.8, 1.0, 0.25))
			draw_circle(moon_p, 7.0, Color("e8ecff"))
			draw_circle(moon_p + Vector2(3, -2), 6.0, (sc[0] as Color).lerp(sc[1], 0.3))
		var day_tint := Color(1, 1, 1).lerp(Color(0.42, 0.48, 0.78), night)
		if day_time > 0.72 and day_time < 0.85:
			day_tint = day_tint.lerp(Color(1.0, 0.78, 0.7), 0.4 * (1.0 - night))
		# clouds (drift), far mountains, near hills — anchored to the ground line
		_tile_h(_clouds, top_left.x * 0.06 - _t * 4.0, ground_y - 250.0, zoom, vp, Color(day_tint.r, day_tint.g, day_tint.b, 0.85))
		_tile_h(_far, top_left.x * 0.12, ground_y - _far.get_height() + 30.0, zoom, vp, day_tint)
		_tile_h(_near, top_left.x * 0.3, ground_y - _near.get_height() + 22.0, zoom, vp, day_tint.darkened(0.08))

func _tile_h(tex: Texture2D, scroll_x: float, y: float, zoom: float, vp: Vector2, tint: Color) -> void:
	var w := tex.get_width()
	var off := -fposmod(scroll_x, float(w))
	var x := off
	while x < vp.x:
		draw_texture(tex, Vector2(floor(x), floor(y)), tint)
		x += w

func _draw_cave(bi: int, top_left: Vector2, zoom: float, vp: Vector2, y0: float, tint: Color, alpha: float) -> void:
	var far: Texture2D = _cave_far.get(bi)
	var near: Texture2D = _cave_near.get(bi)
	if far == null:
		return
	var c := Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.85, alpha)
	_tile_both(far, top_left * 0.25, y0, vp, c)
	if near:
		var c2 := Color(tint.r * 1.1, tint.g * 1.1, tint.b * 1.15, alpha)
		_tile_both(near, top_left * 0.5, y0, vp, c2)

func _tile_both(tex: Texture2D, scroll: Vector2, y0: float, vp: Vector2, tint: Color) -> void:
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var ox := -fposmod(scroll.x, w)
	var oy := -fposmod(scroll.y, h)
	var y := oy
	while y < vp.y:
		if y + h > y0:
			var x := ox
			while x < vp.x:
				var dst := Rect2(floor(x), floor(y), w, h)
				if dst.position.y < y0:
					var cut := y0 - dst.position.y
					draw_texture_rect_region(tex, Rect2(dst.position.x, y0, w, h - cut), Rect2(0, cut, w, h - cut), tint)
				else:
					draw_texture(tex, dst.position, tint)
				x += w
		y += h
