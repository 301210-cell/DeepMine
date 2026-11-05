extends Control
## Base for every UIRoot panel: full-rect Control, builds its window in build(),
## receives open(data) from UIRoot and emits close_requested.

signal close_requested

const Kit = preload("res://scripts/ui/ui_kit.gd")
const ItemSlot = preload("res://scripts/ui/components/item_slot.gd")

var ui: Node = null
var win: Dictionary = {}
var _built := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _built:
		_built = true
		build()

## Override: create the window with Kit.window(self, title, size, request_close) and its content.
func build() -> void:
	pass

## Called by UIRoot every time the panel is shown.
func open(_data: Variant = null) -> void:
	refresh()

func refresh() -> void:
	pass

func request_close() -> void:
	close_requested.emit()

func toast(text: String, kind: String = "info") -> void:
	Events.notify.emit(text, kind)

func error(text: String) -> void:
	AudioManager.play("ui_error")
	Events.notify.emit(text, "warn")

func confirm(title: String, text: String, on_yes: Callable, yes_text: String = "Confirm", danger: bool = true) -> void:
	if ui and ui.has_method("show_confirm"):
		ui.show_confirm(title, text, on_yes, yes_text, danger)
	else:
		on_yes.call()

## Toggle-button tab strip. Returns the HBox; calls on_select(name) when a tab is chosen.
func make_tabs(names: Array, on_select: Callable, selected: String = "") -> HBoxContainer:
	var h := Kit.hbox(2)
	var group := ButtonGroup.new()
	for n in names:
		var b := Kit.button(String(n), "TabButton")
		b.toggle_mode = true
		b.button_group = group
		b.name = String(n).replace(" ", "_")
		b.button_pressed = (String(n) == selected) or (selected == "" and n == names[0])
		var nn: String = n
		b.pressed.connect(func(): on_select.call(nn))
		h.add_child(b)
	return h
