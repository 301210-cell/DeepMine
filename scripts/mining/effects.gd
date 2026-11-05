extends Node2D
## Pooled particle bursts and floating text in world space.
## Uses assets/sprites/effects/particles.png (8x8 cells) and impact.png (16x16 frames).

const P_DUST := Vector2i(0, 0)
const P_GLOW := Vector2i(4, 0)
const P_DEBRIS := Vector2i(0, 1)
const P_SPARK := Vector2i(4, 1)
const P_SPARKLE := Vector2i(0, 2)
const P_SMOKE := Vector2i(4, 2)
const P_STAR := Vector2i(0, 3)
const P_COIN := Vector2i(4, 3)

var _tex: Texture2D
var _impact_tex: Texture2D
var _pool: Array[CPUParticles2D] = []
var _pool_i := 0
var _atlas_cache: Dictionary = {}
var _font: Font

func _ready() -> void:
	z_index = 6
	_tex = ResourceDatabase.tex("res://assets/sprites/effects/particles.png")
	_impact_tex = ResourceDatabase.tex("res://assets/sprites/effects/impact.png")
	if ResourceLoader.exists("res://assets/fonts/pixel.fnt"):
		_font = load("res://assets/fonts/pixel.fnt")
	for i in 28:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		add_child(p)
		_pool.append(p)
	Events.float_text.connect(float_text)

func _frame_tex(cell: Vector2i) -> Texture2D:
	if _atlas_cache.has(cell):
		return _atlas_cache[cell]
	var at := AtlasTexture.new()
	at.atlas = _tex
	at.region = Rect2(cell.x * 8, cell.y * 8, 8, 8)
	_atlas_cache[cell] = at
	return at

func _next() -> CPUParticles2D:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.emitting = false
	p.restart()
	return p

func _burst(pos: Vector2, cell: Vector2i, amount: int, color: Color, cfg: Dictionary) -> void:
	var p := _next()
	p.global_position = pos
	p.texture = _frame_tex(cell)
	p.amount = maxi(1, amount)
	p.lifetime = cfg.get("life", 0.6)
	p.direction = cfg.get("dir", Vector2(0, -1))
	p.spread = cfg.get("spread", 70.0)
	p.initial_velocity_min = cfg.get("vmin", 40.0)
	p.initial_velocity_max = cfg.get("vmax", 110.0)
	p.gravity = cfg.get("gravity", Vector2(0, 420))
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = cfg.get("smin", 0.6)
	p.scale_amount_max = cfg.get("smax", 1.1)
	p.damping_min = cfg.get("damp", 10.0)
	p.damping_max = cfg.get("damp", 10.0) * 1.5
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = cfg.get("radius", 3.0)
	if cfg.get("glow", false):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = mat
	else:
		p.material = null
	p.emitting = true

func debris(pos: Vector2, color: Color, n: int) -> void:
	_burst(pos, P_DEBRIS + Vector2i(randi() % 4, 0), n, color, {"life": 0.7, "vmin": 50.0, "vmax": 140.0, "spread": 80.0, "gravity": Vector2(0, 520), "damp": 4.0})

func dust(pos: Vector2, n: int) -> void:
	_burst(pos, P_DUST + Vector2i(randi() % 4, 0), n, Color(0.85, 0.8, 0.75, 0.7), {"life": 0.55, "vmin": 10.0, "vmax": 40.0, "spread": 100.0, "gravity": Vector2(0, -20), "damp": 30.0, "smin": 0.7, "smax": 1.3})

func sparks(pos: Vector2, color: Color) -> void:
	_burst(pos, P_SPARK, 7, color, {"life": 0.35, "vmin": 70.0, "vmax": 160.0, "spread": 160.0, "gravity": Vector2(0, 300), "glow": true})

func embers(pos: Vector2) -> void:
	_burst(pos + Vector2(0, -6), P_GLOW, 8, Color("ff8a3a"), {"life": 0.9, "vmin": 20.0, "vmax": 60.0, "spread": 50.0, "gravity": Vector2(0, -60), "glow": true, "radius": 6.0})

func splash(pos: Vector2) -> void:
	_burst(pos, P_DUST, 10, Color(0.6, 0.85, 1.0, 0.8), {"life": 0.6, "vmin": 50.0, "vmax": 120.0, "spread": 40.0, "gravity": Vector2(0, 500)})

func sparkle_burst(pos: Vector2, color: Color) -> void:
	_burst(pos, P_SPARKLE + Vector2i(randi() % 4, 0), 14, color, {"life": 0.9, "vmin": 30.0, "vmax": 90.0, "spread": 180.0, "gravity": Vector2(0, -10), "damp": 40.0, "glow": true})

func pickup_pop(pos: Vector2, color: Color) -> void:
	_burst(pos, P_GLOW, 5, color.lightened(0.3), {"life": 0.35, "vmin": 20.0, "vmax": 50.0, "spread": 180.0, "gravity": Vector2.ZERO, "damp": 60.0, "glow": true, "smin": 0.5, "smax": 0.9})

func explosion(pos: Vector2) -> void:
	_burst(pos, P_GLOW, 26, Color("ffb04a"), {"life": 0.6, "vmin": 60.0, "vmax": 220.0, "spread": 180.0, "gravity": Vector2(0, 80), "glow": true, "radius": 8.0, "smin": 1.0, "smax": 2.0})
	_burst(pos, P_SMOKE + Vector2i(randi() % 4, 0), 18, Color(0.5, 0.45, 0.45, 0.85), {"life": 1.2, "vmin": 20.0, "vmax": 80.0, "spread": 180.0, "gravity": Vector2(0, -30), "damp": 20.0, "radius": 10.0, "smin": 1.2, "smax": 2.2})

func level_up(pos: Vector2) -> void:
	_burst(pos, P_STAR + Vector2i(randi() % 4, 0), 24, Color("ffd35a"), {"life": 1.2, "vmin": 60.0, "vmax": 150.0, "spread": 180.0, "gravity": Vector2(0, 120), "glow": true, "damp": 8.0})

func impact(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _impact_tex
	s.hframes = 4
	s.global_position = pos
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	add_child(s)
	var tw := s.create_tween()
	for f in 4:
		tw.tween_callback(func(): s.frame = f)
		tw.tween_interval(0.035)
	tw.tween_callback(s.queue_free)

func float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.z_index = 20
	if _font:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.04, 0.1, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	l.material = mat
	add_child(l)
	l.reset_size()
	l.global_position = pos - Vector2(l.size.x * 0.5, 0)
	l.scale = Vector2(0.4, 0.4)
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", l.global_position.y - 18.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
