extends Control
## Mara's dialogue box (matches the "Tutorial" reference): portrait in an inset frame on the left,
## gold title, typewriter text, blue "Next >" button. Advances with E / Space / click / Next.

signal finished

const Kit = preload("res://scripts/ui/ui_kit.gd")
const PORTRAIT := "res://assets/sprites/player/mara_portrait.png"
const CHARS_PER_SEC := 48.0

var _lines: Array = []
var _i := 0
var _typing := false
var _shown := 0.0
var _open_time := 0.0
var _talk_t := 0.0
var _box: PanelContainer
var _portrait: TextureRect
var _title: Label
var _text: RichTextLabel
var _next: Button
var _frames: Array[Texture2D] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var base := ResourceDatabase.tex(PORTRAIT)
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = Rect2(i * 64, 0, 64, 64) if base.get_width() >= 192 else Rect2(0, 0, base.get_width(), base.get_height())
		_frames.append(at)
	_box = Kit.panel()
	_box.custom_minimum_size = Vector2(300, 98)
	add_child(_box)
	var h := Kit.hbox(8)
	_box.add_child(h)
	var frame := Kit.panel("PanelDark")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(frame)
	_portrait = Kit.icon(_frames[0])
	_portrait.custom_minimum_size = Vector2(64, 64)
	frame.add_child(_portrait)
	var v := Kit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_title = Kit.label("Tutorial", "LabelTitle")
	v.add_child(_title)
	_text = Kit.rich("", 190)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	var row := Kit.hbox(4)
	row.add_child(Kit.spacer())
	_next = Kit.button("Next >", "", _advance, 64)
	row.add_child(_next)
	v.add_child(row)
	_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_advance())

func is_open() -> bool:
	return visible

func start(lines: Array, title: String = "Mara") -> void:
	_lines = lines.duplicate()
	if _lines.is_empty():
		_lines = ["..."]
	_i = 0
	_title.text = title
	visible = true
	_open_time = 0.0
	await get_tree().process_frame
	_box.position = Vector2((size.x - _box.size.x) / 2.0, size.y - _box.size.y - 40.0)
	var target_y := _box.position.y
	_box.position.y += 30
	_box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "position:y", target_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "modulate:a", 1.0, 0.15)
	AudioManager.play("ui_open", -4.0)
	_show_line()

func _show_line() -> void:
	_text.text = Kit.key_bbcode(String(_lines[_i]))
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_next.text = "Next >"

func _advance() -> void:
	if not visible or _open_time < 0.25:
		return
	if _typing:
		_typing = false
		_text.visible_characters = -1
		return
	AudioManager.play("ui_click", -4.0)
	_i += 1
	if _i >= _lines.size():
		_close()
	else:
		_show_line()

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.12)
	await tw.finished
	visible = false
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_open_time += delta
	if _typing:
		_shown += delta * CHARS_PER_SEC
		var total := _text.get_total_character_count()
		_text.visible_characters = int(_shown)
		_talk_t += delta
		_portrait.texture = _frames[1 if int(_talk_t * 7.0) % 2 == 0 else 0]
		if int(_shown) % 3 == 0:
			AudioManager.play("ui_hover", -18.0, 0.15, 0.06)
		if int(_shown) >= total:
			_typing = false
			_text.visible_characters = -1
	else:
		_portrait.texture = _frames[2] if _i == _lines.size() - 1 else _frames[0]
