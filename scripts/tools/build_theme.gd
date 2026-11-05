extends SceneTree
## Saves the DeepMine UI theme to res://assets/ui/theme.tres (for the editor and gui/theme/custom).
## Run: Godot_console.exe --headless --path . --script res://scripts/tools/build_theme.gd
func _initialize() -> void:
	var UiTheme = load("res://scripts/ui/ui_theme.gd")
	var t: Theme = UiTheme.build()
	var err := ResourceSaver.save(t, "res://assets/ui/theme.tres")
	print("theme saved err=", err)
	quit()
