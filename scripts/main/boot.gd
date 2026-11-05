extends Control
## Boot splash: short studio-style logo fade, then the main menu (preloaded in the background).
## Any key / click skips.

const MENU := "res://scenes/main/MainMenu.tscn"

@onready var logo: TextureRect = %Logo
@onready var made_with: Label = %MadeWith
@onready var shine: ColorRect = %Shine

var _done := false

func _ready() -> void:
	if theme == null and ResourceLoader.exists("res://scripts/ui/ui_theme.gd"):
		theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	ResourceLoader.load_threaded_request(MENU)
	logo.modulate.a = 0.0
	made_with.modulate.a = 0.0
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2(0.96, 0.96)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(logo, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(made_with, "modulate:a", 1.0, 0.7).set_delay(0.3)
	tw.tween_callback(func(): AudioManager.play("rare_discovery", -8.0))
	tw.tween_property(shine, "position:x", logo.size.x + 40, 0.6).from(-60.0)
	tw.tween_interval(0.9)
	tw.tween_callback(_go)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_go()

func _go() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 0.0, 0.35)
	tw.tween_property(made_with, "modulate:a", 0.0, 0.35)
	await tw.finished
	var packed: PackedScene = ResourceLoader.load_threaded_get(MENU) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(MENU)
