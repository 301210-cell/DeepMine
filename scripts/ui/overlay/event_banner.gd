extends Control
## "EVENT!" banner (matches the Crystal Surge reference): purple panel with gold corners,
## large event icon left, gold "EVENT!", pink-red event name, description, stopwatch "Time Left: 05:00".

const Kit = preload("res://scripts/ui/ui_kit.gd")
const SHOW_TIME := 6.5

var _box: PanelContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _time: Label
var _t := 0.0
var _showing := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Kit.panel("PanelPurple")
	_box.custom_minimum_size = Vector2(250, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	var h := Kit.hbox(8)
	_box.add_child(h)
	_icon = Kit.icon(null)
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_icon)
	var v := Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Kit.label("EVENT!", "LabelTitle"))
	_name = Kit.label("", "LabelHeader", Color("ff4f7b"))
	v.add_child(_name)
	_desc = Kit.wrap_label("", 160)
	v.add_child(_desc)
	var tb := Kit.panel("PanelDark")
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Kit.hbox(4)
	tb.add_child(th)
	th.add_child(Kit.ui_icon(34))
	th.add_child(Kit.label("Time Left:", "LabelGold"))
	_time = Kit.label("05:00")
	th.add_child(_time)
	v.add_child(tb)
	Events.world_event_started.connect(show_event)

func show_event(event_id: String) -> void:
	var ev: Dictionary = {}
	for e in ResourceDatabase.events:
		if e.id == event_id:
			ev = e
	if ev.is_empty():
		return
	_icon.texture = ResourceDatabase.event_icon(int(ev.icon))
	_name.text = ev.name
	_desc.text = ev.desc
	_update_time()
	_box.visible = true
	_t = SHOW_TIME
	_showing = true
	AudioManager.play("event_start")
	await get_tree().process_frame
	var x := (size.x - _box.size.x) / 2.0
	_box.position = Vector2(x, -_box.size.y - 10)
	var tw := create_tween()
	tw.tween_property(_box, "position:y", 54.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icon.pivot_offset = Vector2(32, 32)
	var tw2 := create_tween().set_loops(4)
	tw2.tween_property(_icon, "scale", Vector2(1.08, 1.08), 0.35)
	tw2.tween_property(_icon, "scale", Vector2.ONE, 0.35)

func _update_time() -> void:
	_time.text = ResourceDatabase.fmt_time(float(GameState.event_state.get("time_left", 0.0)))

func _process(delta: float) -> void:
	if not _showing:
		return
	_update_time()
	_t -= delta
	if _t <= 0.0:
		_showing = false
		var tw := create_tween()
		tw.tween_property(_box, "position:y", -_box.size.y - 10, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _box.visible = false)
