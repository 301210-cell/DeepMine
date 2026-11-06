extends Control
## Compact, non-blocking event notice. Sits at the top of the right-hand notice column (under the
## HUD buttons, above toasts), draws above any open panel, ignores the mouse, never covers the
## middle of the screen. Slides in, shows for a few seconds, then shrinks into the HUD event chip.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const SHOW_TIME := 5.0
const WIDTH := 192.0

var ui: Node = null
var _box: PanelContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _time: Label
var _t := 0.0
var _showing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	_box = Kit.panel("PanelPurple")
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_box)
	var h := Kit.hbox(5)
	_box.add_child(h)
	_icon = Kit.icon(null)
	_icon.custom_minimum_size = Vector2(28, 28)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_icon)
	var v := Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = Kit.label("", "LabelGold")
	_name.clip_text = true
	_name.custom_minimum_size.x = WIDTH - 52
	v.add_child(_name)
	_desc = Kit.wrap_label("", WIDTH - 52, "LabelSmall")
	v.add_child(_desc)
	var th := Kit.hbox(3)
	th.add_child(Kit.ui_icon(34))
	_time = Kit.label("05:00", "", Color("ffd35a"))
	_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_time)
	v.add_child(th)
	visible = false
	Events.world_event_started.connect(show_event)

func show_event(event_id: String) -> void:
	var ev: Dictionary = {}
	for e in ResourceDatabase.events:
		if e.id == event_id:
			ev = e
	if ev.is_empty():
		return
	_icon.texture = ResourceDatabase.event_icon(int(ev.icon))
	_name.text = "EVENT: " + String(ev.name)
	_desc.text = _short(String(ev.desc))
	_update_time()
	visible = true
	_box.modulate.a = 0.0
	_box.scale = Vector2.ONE
	_t = SHOW_TIME
	_showing = true
	AudioManager.play("event_start", -2.0)
	await get_tree().process_frame
	_box.reset_size()
	custom_minimum_size = _box.size
	_box.position = Vector2(_box.size.x + 12.0, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "modulate:a", 1.0, 0.2)
	_icon.pivot_offset = Vector2(14, 14)
	var tw2 := create_tween().set_loops(3)
	tw2.tween_property(_icon, "scale", Vector2(1.12, 1.12), 0.3)
	tw2.tween_property(_icon, "scale", Vector2.ONE, 0.3)

func _short(s: String) -> String:
	## First sentence only, so the notice stays one short line.
	var i := s.find("!")
	var j := s.find(".")
	var k := i if i >= 0 and (j < 0 or i < j) else j
	return s.substr(0, k + 1) if k > 0 else s

func _update_time() -> void:
	_time.text = "Time Left: " + ResourceDatabase.fmt_time(float(GameState.event_state.get("time_left", 0.0)))

func _process(delta: float) -> void:
	if not _showing:
		return
	_update_time()
	_t -= delta
	if _t <= 0.0:
		_showing = false
		_collapse()

func _collapse() -> void:
	## Shrink and fly toward the HUD event chip, then free the column slot.
	var target := _box.global_position + Vector2(-80, -20)
	if ui and ui.get("hud") and ui.hud.has_method("event_chip_center"):
		target = ui.hud.event_chip_center()
	var start := _box.global_position
	_box.pivot_offset = Vector2.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "scale", Vector2(0.15, 0.15), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_box, "global_position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_box, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tw.chain().tween_callback(func():
		visible = false
		custom_minimum_size = Vector2.ZERO
		_box.scale = Vector2.ONE
		_box.position = Vector2.ZERO
		if ui and ui.get("fx"):
			ui.fx.burst(target, "sparkle", 8, Color("c98bff")))
	var _unused := start
