extends Node2D
## A physical machine in the camp. Ticks MachineLogic, animates while working,
## shows a progress bar and a "ready" bubble, glows and hums. Unbuilt machines show a pad.

const MachineLogic = preload("res://scripts/machines/machine_logic.gd")
const Interactable = preload("res://scripts/world/interactable.gd")

var mid := ""
var game = null
var _sprite: Sprite2D
var _pad: Sprite2D
var _light: PointLight2D
var _interact: Area2D
var _anim_t := 0.0
var _bubble_t := 0.0
var _sfx: AudioStreamPlayer2D
var _was_owned := false
var _font: Font

func setup(machine_id: String, p_game) -> void:
	mid = machine_id
	game = p_game

func _ready() -> void:
	_font = load("res://assets/fonts/pixel.fnt") if ResourceLoader.exists("res://assets/fonts/pixel.fnt") else null
	_pad = Sprite2D.new()
	_pad.texture = ResourceDatabase.tex("res://assets/sprites/world/machine_pad.png")
	_pad.position = Vector2(0, -12)
	add_child(_pad)
	_sprite = Sprite2D.new()
	_sprite.texture = ResourceDatabase.tex("res://assets/sprites/machines/%s.png" % mid)
	_sprite.hframes = 5
	_sprite.position = Vector2(0, -32)
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = load("res://scripts/world/world_renderer.gd").make_radial_texture(128, 0.0)
	_light.texture_scale = 0.9
	_light.color = Color("ff9a4a") if mid in ["smelter", "advanced_smelter"] else Color("7ac8ff")
	_light.energy = 0.0
	_light.position = Vector2(0, -22)
	add_child(_light)
	_interact = Interactable.new()
	_interact.setup("", Vector2(60, 56), Vector2(0, -28), _on_interact)
	add_child(_interact)
	_sfx = AudioStreamPlayer2D.new()
	_sfx.bus = "SFX"
	_sfx.max_distance = 260.0
	_sfx.volume_db = -10.0
	var m := ResourceDatabase.machine(mid)
	var snd := "res://assets/audio/sfx/%s.wav" % m.get("sound", "crusher")
	if ResourceLoader.exists(snd):
		var s: AudioStream = load(snd)
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_sfx.stream = s
	add_child(_sfx)
	_was_owned = GameState.machine_state(mid).owned
	_refresh()
	Events.machine_changed.connect(func(id): if id == mid: _refresh())

func _refresh() -> void:
	var owned: bool = GameState.machine_state(mid).owned
	_sprite.visible = owned
	_pad.visible = not owned
	var m := ResourceDatabase.machine(mid)
	_interact.prompt = ("Use " + m.name) if owned else ("%s: build in Shop ($%s)" % [m.name, ResourceDatabase.fmt_num(int(m.price))])
	if owned and not _was_owned:
		_was_owned = true
		_sprite.scale = Vector2(0.3, 1.6)
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.15, 0.85), 0.16).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if game:
			game.effects.dust(global_position + Vector2(0, -4), 18)
			game.effects.sparkle_burst(global_position + Vector2(0, -32), Color("ffd35a"))
		AudioManager.play("machine_done", -2.0)
	queue_redraw()

func _on_interact(_player) -> void:
	if GameState.machine_state(mid).owned:
		Events.open_panel_requested.emit("machine", mid)
	else:
		Events.open_panel_requested.emit("shop", {"tab": "machines"})

func _process(delta: float) -> void:
	MachineLogic.tick(mid, delta)
	var owned: bool = GameState.machine_state(mid).owned
	if not owned:
		return
	var working := MachineLogic.is_working(mid)
	if working:
		_anim_t += delta * 8.0
		_sprite.frame = 1 + int(_anim_t) % 4
		_light.energy = lerpf(_light.energy, 0.85 + 0.15 * sin(_anim_t * 1.7), 0.1)
		if not _sfx.playing and _sfx.stream:
			_sfx.play()
		# subtle vibration
		_sprite.position = Vector2(randf_range(-0.4, 0.4) if mid in ["crusher", "auto_drill", "deep_core_drill", "ore_sorter"] else 0.0, -32)
	else:
		_sprite.frame = 0
		_light.energy = lerpf(_light.energy, 0.0, 0.08)
		_sprite.position = Vector2(0, -32)
		if _sfx.playing:
			_sfx.stop()
	_bubble_t += delta
	queue_redraw()

func _draw() -> void:
	var st := GameState.machine_state(mid)
	if not st.owned:
		return
	var p := MachineLogic.current_progress(mid)
	var working := MachineLogic.is_working(mid)
	if working:
		var w := 40.0
		var r := Rect2(-w * 0.5, -70, w, 4)
		draw_rect(r.grow(1), Color(0.04, 0.05, 0.12, 0.85))
		draw_rect(Rect2(r.position, Vector2(w * p, 4)), Color("4aa3ff"))
		draw_rect(Rect2(r.position, Vector2(w * p, 1)), Color("b8e0ff"))
	var out := MachineLogic.output_total(mid)
	if out > 0:
		var bob := sin(_bubble_t * 4.0) * 2.0
		var c := Vector2(0, -82 + bob)
		draw_circle(c, 7.0, Color(0.05, 0.06, 0.14, 0.9))
		draw_arc(c, 7.0, 0.0, TAU, 20, Color("ffd35a"), 1.0)
		var first: String = st.output.keys()[0]
		draw_texture_rect(ResourceDatabase.item_icon(first), Rect2(c - Vector2(5, 5), Vector2(10, 10)), false)
		if _font:
			draw_string(_font, c + Vector2(8, 4), "x%d" % out, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffe9a0"))
