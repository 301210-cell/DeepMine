extends SceneTree
## One-time project setup: writes the DeepMine Input Map into project.godot.
## Run: Godot_console.exe --headless --path . --script res://scripts/tools/setup_input_map.gd

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.device = -1
	return e

func _mouse(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.device = -1
	return e

func _init() -> void:
	var actions := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT)],
		"jump": [_key(KEY_SPACE)],
		"climb_up": [_key(KEY_W), _key(KEY_UP)],
		"climb_down": [_key(KEY_S), _key(KEY_DOWN)],
		"run": [_key(KEY_SHIFT)],
		"mine": [_mouse(MOUSE_BUTTON_LEFT)],
		"use_item": [_mouse(MOUSE_BUTTON_RIGHT)],
		"interact": [_key(KEY_E)],
		"inventory": [_key(KEY_I), _key(KEY_TAB)],
		"skill_tree": [_key(KEY_K)],
		"map": [_key(KEY_M)],
		"journal": [_key(KEY_J)],
		"pause": [_key(KEY_ESCAPE)],
		"hotbar_1": [_key(KEY_1)],
		"hotbar_2": [_key(KEY_2)],
		"hotbar_3": [_key(KEY_3)],
		"hotbar_4": [_key(KEY_4)],
		"hotbar_5": [_key(KEY_5)],
		"hotbar_6": [_key(KEY_6)],
		"toggle_fullscreen": [_key(KEY_F11)],
		"quick_heal": [_key(KEY_H)],
	}
	for a in actions:
		ProjectSettings.set_setting("input/" + a, {"deadzone": 0.5, "events": actions[a]})
	var err := ProjectSettings.save()
	print("Input map written, err=", err)
	quit()
