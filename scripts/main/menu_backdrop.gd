extends Control
## Animated title backdrop shared by the Main Menu and the Loading Screen.
## Shows the mine-entrance artwork (assets/backgrounds/menu_bg_ref.png, built from the
## reference picture by tools/assetgen/gen_menu_ref.gd) and layers subtle animation on top:
## pulsing crystal glows, flickering lanterns and doorway light, twinkling star sparkles
## (mostly on the still mine cart's gems), and drifting dust motes.
## All coordinates below are in the 640x360 artwork space.

const BG_PATH := "res://assets/backgrounds/menu_bg_ref.png"

## [position, radius, colour, pulse speed, base alpha, kind] kind: 0 steady pulse, 1 flame flicker
const GLOWS := [
	[Vector2(36, 228), 78.0, Color("4aa8ff"), 1.1, 0.30, 0],   # big blue crystal (left)
	[Vector2(70, 292), 46.0, Color("5ac8ff"), 1.5, 0.22, 0],   # lower blue crystals
	[Vector2(607, 226), 74.0, Color("b86bff"), 0.9, 0.30, 0],  # big purple crystal (right)
	[Vector2(568, 262), 44.0, Color("d07aff"), 1.3, 0.22, 0],  # smaller purple crystals
	[Vector2(486, 276), 40.0, Color("b45cff"), 1.7, 0.30, 0],  # gems in the cart
	[Vector2(240, 172), 22.0, Color("5ad8ff"), 2.1, 0.30, 0],  # roof crystals
	[Vector2(470, 180), 20.0, Color("5ad8ff"), 1.8, 0.26, 0],
	[Vector2(515, 160), 20.0, Color("6ae0ff"), 2.4, 0.24, 0],
	[Vector2(87, 180), 18.0, Color("6ae0ff"), 1.6, 0.20, 0],
	[Vector2(365, 268), 58.0, Color("ffab4a"), 1.0, 0.26, 1],  # mine doorway
	[Vector2(220, 240), 20.0, Color("ffc56a"), 1.0, 0.42, 1],  # lanterns
	[Vector2(289, 250), 20.0, Color("ffc56a"), 1.0, 0.42, 1],
	[Vector2(325, 235), 16.0, Color("ffc56a"), 1.0, 0.36, 1],
	[Vector2(434, 245), 20.0, Color("ffc56a"), 1.0, 0.42, 1],
	[Vector2(181, 270), 16.0, Color("ffc56a"), 1.0, 0.36, 1],
]

## Sparkle spawn regions: [rect, colour, weight]
const SPARKLE_ZONES := [
	[Rect2(452, 262, 64, 22), Color("f2c8ff"), 7.0],   # cart gem pile (shiny gems)
	[Rect2(14, 180, 54, 120), Color("c8f0ff"), 3.0],   # blue crystal
	[Rect2(578, 182, 48, 110), Color("f0d0ff"), 3.0],  # purple crystal
	[Rect2(80, 66, 500, 56), Color("fff1b8"), 1.4],    # MINING SIMULATOR lettering
	[Rect2(135, 16, 350, 40), Color("d8f4ff"), 1.0],   # UNDERGROUND lettering
	[Rect2(486, 2, 60, 26), Color("ffffff"), 0.8],     # pickaxe head
	[Rect2(215, 160, 320, 30), Color("bff4ff"), 1.2],  # roof crystals
	[Rect2(390, 292, 60, 18), Color("ffe6a0"), 0.6],   # rails / gold glints
]

var stage: Control
var picture: TextureRect
var _fx_glow: Node2D
var _fx_spark: Node2D
var _dust: CPUParticles2D
var _halo: Texture2D
var _t := 0.0
var _sparkles: Array = []   # {"p": Vector2, "life": float, "max": float, "size": float, "col": Color}
var _spawn_t := 0.0
var _zone_total := 0.0
var _flicker: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("070a1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = Control.new()
	stage.size = Vector2(640, 360)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture = ResourceDatabase.tex(BG_PATH)
	picture.custom_minimum_size = Vector2.ZERO
	picture.position = Vector2.ZERO
	picture.size = Vector2(640, 360)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(picture)
	_halo = load("res://scripts/world/world_renderer.gd").make_radial_texture(128, 0.0)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx_glow = Node2D.new()
	_fx_glow.material = add_mat
	_fx_glow.draw.connect(_draw_glows)
	stage.add_child(_fx_glow)
	_dust = _make_dust()
	stage.add_child(_dust)
	_fx_spark = Node2D.new()
	_fx_spark.material = add_mat
	_fx_spark.draw.connect(_draw_sparkles)
	stage.add_child(_fx_spark)
	for z in SPARKLE_ZONES:
		_zone_total += float(z[2])
	# start with a few sparkles already alive so the first frame isn't empty
	for i in 10:
		_spawn_sparkle()
		_sparkles[-1].life = randf() * float(_sparkles[-1].max)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	## Cover the whole window with the 640x360 stage, keeping the aspect ratio.
	var s := maxf(size.x / 640.0, size.y / 360.0)
	stage.scale = Vector2(s, s)
	stage.position = (size - Vector2(640, 360) * s) * 0.5

func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 42
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(320, 200)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(330, 170)
	p.direction = Vector2(0.3, -1)
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector2(0, -1)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	var at := AtlasTexture.new()
	at.atlas = ResourceDatabase.tex("res://assets/sprites/effects/particles.png")
	at.region = Rect2(32, 0, 8, 8)
	p.texture = at
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.6, 0.0))
	ramp.add_point(0.3, Color(1, 0.9, 0.7, 0.45))
	ramp.add_point(0.7, Color(0.7, 0.85, 1.0, 0.4))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.8, 1.0, 0.0))
	p.color_ramp = ramp
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p

func _process(delta: float) -> void:
	_t += delta
	# flame flicker noise per glow (smoothed random walk)
	for i in GLOWS.size():
		if int(GLOWS[i][5]) == 1:
			var cur: float = _flicker.get(i, 1.0)
			_flicker[i] = lerpf(cur, randf_range(0.78, 1.12), 0.18)
	_spawn_t -= delta
	while _spawn_t <= 0.0:
		_spawn_t += randf_range(0.05, 0.16)
		_spawn_sparkle()
	for s in _sparkles:
		s.life += delta
	_sparkles = _sparkles.filter(func(s): return s.life < s.max)
	_fx_glow.queue_redraw()
	_fx_spark.queue_redraw()

func _spawn_sparkle() -> void:
	if _sparkles.size() > 40:
		return
	var r := randf() * _zone_total
	var zone: Array = SPARKLE_ZONES[0]
	for z in SPARKLE_ZONES:
		r -= float(z[2])
		if r <= 0.0:
			zone = z
			break
	var rect: Rect2 = zone[0]
	_sparkles.append({
		"p": rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y),
		"life": 0.0, "max": randf_range(0.6, 1.3), "size": randf_range(2.5, 5.5),
		"col": (zone[1] as Color), "rot": randf() < 0.3,
	})

func _draw_glows() -> void:
	for i in GLOWS.size():
		var g: Array = GLOWS[i]
		var pos: Vector2 = g[0]
		var rad: float = g[1]
		var col: Color = g[2]
		var spd: float = g[3]
		var a: float = g[4]
		var k: float
		if int(g[5]) == 1:
			k = float(_flicker.get(i, 1.0))
		else:
			k = 0.75 + 0.25 * sin(_t * spd + i * 1.7)
		var rr := rad * (0.92 + 0.08 * k)
		_fx_glow.draw_texture_rect(_halo, Rect2(pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col.r, col.g, col.b, a * k))

func _draw_sparkles() -> void:
	for s in _sparkles:
		var f: float = s.life / s.max
		var k := sin(f * PI)          # grow then shrink
		var sz: float = s.size * k
		var c: Color = s.col
		var p: Vector2 = s.p
		_fx_spark.draw_texture_rect(_halo, Rect2(p - Vector2(sz * 2.2, sz * 2.2), Vector2(sz * 4.4, sz * 4.4)), false, Color(c.r, c.g, c.b, 0.35 * k))
		var a := Color(c.r, c.g, c.b, 0.95 * k)
		# 4-point star; "rot" sparkles get short diagonal rays too (8-point twinkle)
		_fx_spark.draw_line(p - Vector2(sz, 0), p + Vector2(sz, 0), a, 1.0)
		_fx_spark.draw_line(p - Vector2(0, sz), p + Vector2(0, sz), a, 1.0)
		if s.rot:
			var d := sz * 0.35
			var a2 := Color(a.r, a.g, a.b, a.a * 0.6)
			_fx_spark.draw_line(p - Vector2(d, d), p + Vector2(d, d), a2, 1.0)
			_fx_spark.draw_line(p - Vector2(d, -d), p + Vector2(d, -d), a2, 1.0)
		_fx_spark.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, k))
