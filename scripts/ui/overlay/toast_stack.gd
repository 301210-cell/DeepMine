extends VBoxContainer
## Notification toasts (Events.notify). Lives in the right-hand notice column under the HUD buttons
## (below the event notice). Each toast slides in from the right, stays briefly, then fades out.
## Text wraps inside a fixed max width so it can never spill out of its box.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const MAX := 4
const MAX_W := 150.0
const KINDS := {
	"info": [28, "eef2ff", "ui_click"],
	"good": [15, "7dff8a", "notify"],
	"warn": [42, "ffb04a", "ui_error"],
	"rare": [41, "6fb6ff", "rare_discovery"],
	"epic": [41, "c98bff", "rare_discovery"],
	"legendary": [52, "ffd35a", "legendary"],
	"coin": [0, "ffd35a", "coin"],
	"xp": [3, "5ff2ff", ""],
}

var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 3)
	_font = load("res://scripts/ui/ui_theme.gd").font()
	Events.notify.connect(push)

func push(text: String, kind: String = "info") -> void:
	if text.begins_with("EVENT!") or text.begins_with("EVENT:"):
		return  # the compact event notice above already announces it
	var k: Array = KINDS.get(kind, KINDS.info)
	var p := Kit.panel("PanelPurple" if kind in ["epic", "legendary"] else "PanelDark")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Kit.hbox(4)
	p.add_child(h)
	var ic := Kit.ui_icon(int(k[0]))
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var l := Kit.label(text, "", Color(k[1]))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tw_px := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if _font else text.length() * 5.2
	l.custom_minimum_size.x = clampf(tw_px + 2.0, 24.0, MAX_W)
	h.add_child(l)
	# Plain Control wrapper: the VBox lays out the wrapper, so the panel inside can slide freely.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	wrap.add_child(p)
	add_child(wrap)
	if String(k[2]) != "" and kind != "info":
		AudioManager.play(k[2], -4.0, 0.03, 0.2)
	while get_child_count() > MAX:
		var c := get_child(0)
		remove_child(c)
		c.queue_free()
	p.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.reset_size()
	wrap.custom_minimum_size = p.size
	p.position = Vector2(28.0, 0.0)
	var life := 5.0 if kind in ["legendary", "epic"] else 3.6
	var slide := p.create_tween().set_parallel(true)
	slide.tween_property(p, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(p, "modulate:a", 1.0, 0.16)
	var tw := p.create_tween()
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.45)
	tw.tween_callback(wrap.queue_free)
