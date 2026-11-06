extends Control
## Screen-space UI effects layer (lives in UIRoot's Overlay, above panels):
## coin/sparkle bursts, icons flying into HUD buttons, rising flash text and button pulses.
## Panels reach it through `ui.fx`.

const PARTICLES := "res://assets/sprites/effects/particles.png"

var hud: Node = null
var _atlas: Texture2D
var _cells: Dictionary = {}
var _font: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atlas = ResourceDatabase.tex(PARTICLES)
	_font = load("res://scripts/ui/ui_theme.gd").font_big()

func _cell(c: Vector2i) -> Texture2D:
	if _cells.has(c):
		return _cells[c]
	var at := AtlasTexture.new()
	at.atlas = _atlas
	at.region = Rect2(c.x * 8, c.y * 8, 8, 8)
	_cells[c] = at
	return at

func mouse() -> Vector2:
	return get_viewport().get_mouse_position()

## Particle burst at a screen position. kind: coin, sparkle, star.
func burst(pos: Vector2, kind: String = "sparkle", count: int = 14, color: Color = Color.WHITE) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.75
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.color = color
	match kind:
		"coin":
			p.texture = _cell(Vector2i(4 + randi() % 4, 3))
		"star":
			p.texture = _cell(Vector2i(randi() % 4, 3))
			p.gravity = Vector2(0, 40)
		_:
			p.texture = _cell(Vector2i(randi() % 4, 2))
			p.gravity = Vector2(0, 20)
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4, true, false, true).timeout.connect(p.queue_free)

## Rising text that pops in and fades ("Purchased!", "+$120").
func flash_text(text: String, pos: Vector2, color: Color = Color("ffd35a")) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.03, 0.03, 0.09, 1))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	l.reset_size()
	l.position = pos - Vector2(l.size.x * 0.5, l.size.y + 4)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 16.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)

## An icon arcs from `from` to `to`, shrinking, then the target pulses.
func fly(tex: Texture2D, from: Vector2, to: Vector2, target: Control = null, delay: float = 0.0, scale_from: float = 2.0) -> void:
	if tex == null:
		return
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := tex.get_size()
	t.size = sz
	t.pivot_offset = sz * 0.5
	t.position = from - sz * 0.5
	t.scale = Vector2.ONE * scale_from
	t.modulate.a = 0.0
	add_child(t)
	var mid := (from + to) * 0.5 + Vector2(0, -50)
	var tw := t.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(t, "modulate:a", 1.0, 0.06)
	tw.tween_method(func(k: float):
		var a := from.lerp(mid, k)
		var b := mid.lerp(to, k)
		t.position = a.lerp(b, k) - sz * 0.5
		t.scale = Vector2.ONE * lerpf(scale_from, 0.7, k), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		t.queue_free()
		if target:
			pulse(target)
			burst(to, "sparkle", 6, Color("fff1a8")))

## Quick "boing" on a control (pivot centred).
func pulse(c: Control, amount: float = 1.18) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.07)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- composite effects
## Shop purchase: coin burst + sparkles at the button, "Purchased!" flash, icon flies to Inventory.
func purchase(icon: Texture2D, at: Vector2 = Vector2.INF, text: String = "Purchased!") -> void:
	if at == Vector2.INF:
		at = mouse()
	burst(at, "coin", 12, Color.WHITE)
	burst(at, "sparkle", 10, Color("b8fbff"))
	flash_text(text, at, Color("8affa0"))
	if hud and hud.has_method("button_center"):
		fly(icon, at, hud.button_center("inventory"), hud.get_button("inventory"), 0.12)

## Sale: a few coins fly from where you clicked to the coin chip (the counter ticks up there).
## Several sales in the same frame (e.g. "Sell all") are merged into one effect.
var _sold_acc := 0
var _sold_at := Vector2.ZERO

func sold(value: int, at: Vector2 = Vector2.INF) -> void:
	if _sold_acc == 0:
		_sold_at = at if at != Vector2.INF else mouse()
		call_deferred("_flush_sold")
	_sold_acc += value

func _flush_sold() -> void:
	var value := _sold_acc
	_sold_acc = 0
	var at := _sold_at
	if value <= 0:
		return
	flash_text("+$" + ResourceDatabase.fmt_num(value), at, Color("ffd35a"))
	burst(at, "coin", 8, Color.WHITE)
	if hud and hud.has_method("coin_center"):
		var coin := ResourceDatabase.ui_icon(0)
		var n := clampi(2 + int(log(maxf(value, 1.0)) / log(10.0)) * 2, 3, 9)
		for i in n:
			var off := Vector2(randf_range(-10, 10), randf_range(-6, 6))
			fly(coin, at + off, hud.coin_center(), hud.get_coin_chip() if i == n - 1 else null, i * 0.05, 1.2)

## Upgrade / unlock: golden star burst + flash.
func upgraded(text: String = "Upgraded!", at: Vector2 = Vector2.INF) -> void:
	if at == Vector2.INF:
		at = mouse()
	burst(at, "star", 16, Color("ffd35a"))
	burst(at, "sparkle", 10, Color("fff1a8"))
	flash_text(text, at, Color("ffd35a"))
