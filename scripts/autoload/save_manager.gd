extends Node
## Autoload "SaveManager": JSON save/load with backup, versioning/migration and corruption handling,
## periodic autosave, plus user settings (audio, display, key bindings) stored separately.

# Save file locations (vars so automated tests can redirect them; see use_test_saves()).
var save_dir := "user://"
var SAVE_PATH := "user://deepmine_save.json"
var BACKUP_PATH := "user://deepmine_save.bak.json"
var TEMP_PATH := "user://deepmine_save.tmp"
const SETTINGS_PATH := "user://deepmine_settings.json"
const AUTOSAVE_INTERVAL := 60.0

const DEFAULT_SETTINGS := {
	"master": 1.0, "music": 0.65, "sfx": 0.85, "ambient": 0.55, "mute": false,
	"fullscreen": false, "screen_shake": true, "show_fps": false, "keybinds": {},
}

## Actions the player can rebind, with display names.
const REBINDABLE := [
	["move_left", "Move Left"], ["move_right", "Move Right"], ["jump", "Jump"], ["climb_up", "Climb Up"],
	["climb_down", "Climb Down"], ["run", "Run"], ["interact", "Interact"], ["inventory", "Inventory"],
	["skill_tree", "Skill Tree"], ["map", "Map"], ["journal", "Journal"],
]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var last_error: String = ""
var pending_world: Dictionary = {}   # world data from the last load, consumed by the Game scene
var _autosave_timer: Timer
var _default_events: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in REBINDABLE:
		if InputMap.has_action(a[0]):
			_default_events[a[0]] = InputMap.action_get_events(a[0]).duplicate()
	load_settings()
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_on_autosave)
	add_child(_autosave_timer)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.in_game:
			save_game()
		save_settings()
		get_tree().quit()

func _on_autosave() -> void:
	if GameState.in_game and get_tree().paused == false:
		save_game()

# ================================================================ save / load
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

func save_info() -> Dictionary:
	var d := _read_json(SAVE_PATH)
	if d.is_empty():
		d = _read_json(BACKUP_PATH)
	if d.is_empty():
		return {}
	return {
		"level": int(d.get("level", 1)), "coins": int(d.get("coins", 0)),
		"depth": int(d.get("max_depth", 0)), "play_time": float(d.get("play_time", 0.0)),
		"saved_at": String(d.get("saved_at", "")),
	}

func save_game() -> bool:
	if not GameState.in_game:
		return false
	var data := GameState.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	if GameState.world != null:
		data["world"] = GameState.world.serialize()
	var json := JSON.stringify(data)
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		last_error = "Could not write save file (%s)" % error_string(FileAccess.get_open_error())
		push_error(last_error)
		return false
	f.store_string(json)
	f.close()
	# Verify the temp file before replacing anything.
	if _read_json(TEMP_PATH).is_empty():
		last_error = "Save verification failed; previous save kept."
		push_error(last_error)
		return false
	var dir := DirAccess.open(save_dir)
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			dir.remove(BACKUP_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), BACKUP_PATH.get_file())
	dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	Events.game_saved.emit()
	return true

## Loads into GameState. Returns false (and sets last_error) if nothing usable was found.
## A corrupt main save falls back to the backup; corrupt files are kept, never erased.
func load_game() -> bool:
	last_error = ""
	var d := _read_json(SAVE_PATH)
	if d.is_empty() and FileAccess.file_exists(SAVE_PATH):
		_quarantine(SAVE_PATH)
		last_error = "Your save file was damaged. Loaded the backup instead (damaged file kept)."
	if d.is_empty():
		d = _read_json(BACKUP_PATH)
		if d.is_empty():
			if last_error == "":
				last_error = "No save could be loaded."
			else:
				last_error = "Save and backup are both damaged. Files were kept in the save folder."
			return false
	d = migrate(d)
	GameState.from_dict(d)
	pending_world = d.get("world", {})
	return true

func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1:
		# v0 (pre-release) saves had no skills dictionary / tutorial block.
		if not d.has("skills"):
			d["skills"] = {"miners_core": 1}
		if not d.has("tutorial"):
			d["tutorial"] = {"step": 0, "done": false, "skipped": false}
		d["version"] = 1
	# Future migrations: if v < 2: ...
	return d

## Moves the current save aside (requires a UI confirmation before calling). Nothing is destroyed.
func reset_save() -> void:
	var dir := DirAccess.open(save_dir)
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-")
	if FileAccess.file_exists(SAVE_PATH):
		dir.rename(SAVE_PATH.get_file(), "deepmine_save.reset-%s.json" % stamp)
	if FileAccess.file_exists(BACKUP_PATH):
		dir.rename(BACKUP_PATH.get_file(), "deepmine_save.bak.reset-%s.json" % stamp)

func _quarantine(path: String) -> void:
	var dir := DirAccess.open(save_dir)
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-")
	dir.rename(path.get_file(), path.get_file().get_basename() + ".corrupt-%s.json" % stamp)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("version"):
		return {}
	return parsed

# ================================================================ settings
func load_settings() -> void:
	var d: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			d = parsed
	settings = DEFAULT_SETTINGS.duplicate(true)
	settings.merge(d, true)
	apply_settings()

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()

func apply_settings() -> void:
	AudioManager.apply_volumes(settings)
	var want_fs: bool = settings.get("fullscreen", false)
	var mode := DisplayServer.window_get_mode()
	var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_fs != is_fs and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_keybinds()

func _apply_keybinds() -> void:
	var kb: Dictionary = settings.get("keybinds", {})
	for a in REBINDABLE:
		var action: String = a[0]
		if not InputMap.has_action(action):
			continue
		var defaults: Array = _default_events.get(action, [])
		InputMap.action_erase_events(action)
		if kb.has(action):
			var ev := _event_from_dict(kb[action])
			if ev:
				InputMap.action_add_event(action, ev)
			# keep secondary defaults (arrow keys etc.)
			for i in range(1, defaults.size()):
				InputMap.action_add_event(action, defaults[i])
		else:
			for e in defaults:
				InputMap.action_add_event(action, e)

func rebind(action: String, ev: InputEvent) -> void:
	var kb: Dictionary = settings.get("keybinds", {})
	kb[action] = _event_to_dict(ev)
	settings["keybinds"] = kb
	apply_settings()
	save_settings()

func reset_keybinds() -> void:
	settings["keybinds"] = {}
	apply_settings()
	save_settings()

func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "-"
	return event_text(evs[0])

static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Left Mouse"
			MOUSE_BUTTON_RIGHT: return "Right Mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle Mouse"
		return "Mouse %d" % ev.button_index
	return ev.as_text()

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": ev.button_index}
	return {}

func _event_from_dict(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("code", 0))
			k.device = -1
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button", 1))
			m.device = -1
			return m
	return null

## Automated tests and screenshot tools call this first so they never touch the player's real saves.
func use_test_saves() -> void:
	save_dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	SAVE_PATH = save_dir + "deepmine_save.json"
	BACKUP_PATH = save_dir + "deepmine_save.bak.json"
	TEMP_PATH = save_dir + "deepmine_save.tmp"
