extends VBoxContainer
## Notification toasts (Events.notify). Stacks under the top-right HUD buttons, slides in, fades out.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const MAX := 5
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 3)
	Events.notify.connect(push)

func push(text: String, kind: String = "info") -> void:
	var k: Array = KINDS.get(kind, KINDS.info)
	var p := Kit.panel("PanelPurple" if kind in ["epic", "legendary"] else "PanelDark")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var h := Kit.hbox(4)
	p.add_child(h)
	var ic := Kit.ui_icon(int(k[0]))
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var l := Kit.label(text, "", Color(k[1]))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(200.0, 8.0 + text.length() * 5.2)
	h.add_child(l)
	add_child(p)
	if String(k[2]) != "" and kind != "info":
		AudioManager.play(k[2], -4.0, 0.03, 0.2)
	while get_child_count() > MAX:
		var c := get_child(0)
		remove_child(c)
		c.queue_free()
	p.modulate.a = 0.0
	var life := 5.0 if kind in ["legendary", "epic"] else 3.6
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.45)
	tw.tween_callback(p.queue_free)
