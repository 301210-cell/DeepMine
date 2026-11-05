extends Control
## Modal confirmation: title, message, Cancel + Confirm. Esc cancels.

signal closed

const Kit = preload("res://scripts/ui/ui_kit.gd")

var _box: PanelContainer
var _title: Label
var _msg: Label
var _yes: Button
var _no: Button
var _on_yes: Callable

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_box = Kit.panel()
	_box.custom_minimum_size = Vector2(250, 0)
	add_child(_box)
	var v := Kit.vbox(6)
	_box.add_child(v)
	_title = Kit.label("", "LabelTitle")
	v.add_child(_title)
	_msg = Kit.wrap_label("", 230)
	v.add_child(_msg)
	var row := Kit.hbox(6)
	row.add_child(Kit.spacer())
	_no = Kit.button("Cancel", "ButtonDark", func(): _finish(false), 64, "ui_close")
	_yes = Kit.button("Confirm", "ButtonRed", func(): _finish(true), 72)
	row.add_child(_no)
	row.add_child(_yes)
	v.add_child(row)

func is_open() -> bool:
	return visible

func ask(title: String, text: String, on_yes: Callable, yes_text: String = "Confirm", danger: bool = true) -> void:
	_title.text = title
	_msg.text = text
	_yes.text = yes_text
	_yes.theme_type_variation = "ButtonRed" if danger else "ButtonGreen"
	_on_yes = on_yes
	visible = true
	AudioManager.play("ui_open", -4.0)
	await get_tree().process_frame
	_box.position = (size - _box.size) / 2.0

func _finish(ok: bool) -> void:
	visible = false
	closed.emit()
	if ok and _on_yes.is_valid():
		_on_yes.call()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_finish(false)
		get_viewport().set_input_as_handled()
