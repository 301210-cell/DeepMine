extends RefCounted
## Loads a game for the loading screen: threaded Game scene load + world generation
## (new game) or save loading (continue), with real progress.
##   const GameLoader = preload("res://scripts/main/game_loader.gd")
##   GameLoader.start("new" | "continue"); each frame GameLoader.poll() -> 0..1
##   when GameLoader.is_done(): get_tree().change_scene_to_packed(GameLoader.game_scene())

const GAME_SCENE := "res://scenes/main/Game.tscn"

static var _thread: Thread = null
static var _gen = null
static var _mode := "new"
static var _world_done := false
static var _scene: PackedScene = null
static var _error := ""
static var _scene_progress := 0.0
static var _status := ""

static func start(mode: String) -> void:
	_mode = mode
	_world_done = false
	_scene = null
	_error = ""
	_scene_progress = 0.0
	_status = "Preparing"
	GameState.world = null
	ResourceLoader.load_threaded_request(GAME_SCENE)
	var wd_script = load("res://scripts/world/world_data.gd")
	if mode == "continue":
		_status = "Loading save"
		if not SaveManager.load_game():
			_error = SaveManager.last_error
			return
		if not SaveManager.pending_world.is_empty():
			var wd = wd_script.deserialize(SaveManager.pending_world)
			SaveManager.pending_world = {}
			if wd != null:
				GameState.world = wd
				_world_done = true
				return
		# Save had no usable world: regenerate from its seed (progress is kept in GameState).
	else:
		GameState.new_game()
		SaveManager.pending_world = {}
	_gen = load("res://scripts/world/world_gen.gd").new()
	_thread = Thread.new()
	_thread.start(_gen.generate.bind(GameState.world_seed))

static func poll() -> float:
	if _error != "":
		return 0.0
	if not _world_done and _thread != null and not _thread.is_alive():
		GameState.world = _thread.wait_to_finish()
		_thread = null
		_world_done = GameState.world != null
		if not _world_done:
			_error = "World generation failed."
	var arr := []
	var st := ResourceLoader.THREAD_LOAD_LOADED if _scene != null else ResourceLoader.load_threaded_get_status(GAME_SCENE, arr)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		_scene_progress = 1.0
		if _scene == null:
			_scene = ResourceLoader.load_threaded_get(GAME_SCENE)
	elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS and arr.size() > 0:
		_scene_progress = float(arr[0])
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_error = "Could not load the game scene."
	var world_p := 1.0 if _world_done else (float(_gen.progress) if _gen != null else 0.0)
	return clampf(world_p * 0.8 + _scene_progress * 0.2, 0.0, 1.0)

static func status_text() -> String:
	if _gen != null and not _world_done:
		return String(_gen.status)
	return _status if not _world_done else "Entering the mine"

static func is_done() -> bool:
	return _world_done and _scene != null and _error == ""

static func error_text() -> String:
	return _error

static func game_scene() -> PackedScene:
	return _scene
