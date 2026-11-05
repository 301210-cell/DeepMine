extends Control
## Pause menu (UIRoot pauses the SceneTree while this is open).

signal close_requested

const SettingsPanel = preload("res://scripts/ui/panels/settings_panel.gd")
const MENU_SCENE := "res://scenes/main/MainMenu.tscn"

@onready var window: Control = %Window
@onready var buttons: VBoxContainer = %Buttons
@onready var close_button: BaseButton = %CloseButton
@onready var info_label: Label = %InfoLabel

var _first: Button

func _ready() -> void:
	close_button.pressed.connect(func(): AudioManager.play("ui_close"); close_requested.emit())
	_add("Resume", "", func(): close_requested.emit())
	_add("Inventory", "ButtonDark", func(): Events.open_panel_requested.emit("inventory", null))
	var sk := _add("Skill Tree", "ButtonDark", func(): Events.open_panel_requested.emit("skills", null))
	if not _skill_tree_unlocked():
		sk.disabled = true
		sk.tooltip_text = "Mara will show you the Research Board first."
	_add("Map", "ButtonDark", func(): Events.open_panel_requested.emit("map", null))
	_add("Journal", "ButtonDark", func(): Events.open_panel_requested.emit("journal", "quests"))
	_add("Settings", "ButtonDark", func(): Events.open_panel_requested.emit("settings", "from_pause"))
	buttons.add_child(HSeparator.new())
	_add("Save Game", "ButtonGreen", _on_save)
	var rc := _add("Return to Camp", "ButtonDark", _on_recall)
	rc.disabled = GameState.at_surface
	_add("Main Menu", "ButtonDark", _on_main_menu)
	_add("Quit Game", "ButtonRed", _on_quit)

func _skill_tree_unlocked() -> bool:
	var tut: Dictionary = GameState.tutorial
	if bool(tut.get("done", false)) or bool(tut.get("skipped", false)):
		return true
	var steps: Array = ResourceDatabase.quests.get("tutorial", [])
	for i in steps.size():
		if steps[i].get("id", "") == "t_board":
			return int(tut.get("step", 0)) >= i
	return true

func _add(text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = StringName(variation)
	b.custom_minimum_size = Vector2(150, 22)
	b.pressed.connect(cb)
	SettingsPanel.wire_sounds(b)
	buttons.add_child(b)
	if _first == null:
		_first = b
	return b

func open(_data = null) -> void:
	var si := "Level %d  •  %dm  •  $%s" % [GameState.level, GameState.current_depth, ResourceDatabase.fmt_num(GameState.coins)]
	info_label.text = si
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.94, 0.94)
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "scale", Vector2.ONE, 0.18)
	tw.tween_property(window, "modulate:a", 1.0, 0.12)
	if _first:
		_first.grab_focus()

func _on_save() -> void:
	if SaveManager.save_game():
		Events.notify.emit("Game saved!", "good")
		info_label.text = "Game saved!"
	else:
		Events.notify.emit("Save failed: " + SaveManager.last_error, "warn")
		info_label.text = "Save failed"

func _on_recall() -> void:
	_confirm("Return to Camp?", "Mara will haul you back up to the mining camp. You keep everything in your backpack.", func():
		close_requested.emit()
		Events.recall_requested.emit())

func _on_main_menu() -> void:
	_confirm("Return to Main Menu?", "Your progress will be saved first.", func():
		SaveManager.save_game()
		GameState.in_game = false
		GameState.ui_blocking = false
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE))

func _on_quit() -> void:
	_confirm("Quit DeepMine?", "Your progress will be saved first.", func():
		SaveManager.save_game()
		SaveManager.save_settings()
		get_tree().quit())

func _confirm(title: String, text: String, on_yes: Callable) -> void:
	var n := get_parent()
	while n:
		if n.has_method("show_confirm"):
			n.show_confirm(title, text, on_yes)
			return
		n = n.get_parent()
	SettingsPanel.make_confirm(self, title, text, on_yes)

func _capture_setup(_args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	GameState.new_game(1)
	GameState.at_surface = false
	GameState.current_depth = 142
	open(null)
