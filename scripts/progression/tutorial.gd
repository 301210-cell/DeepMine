extends Node
## Mara's onboarding: 12 short steps, one highlighted objective at a time, with dialogue,
## bouncing arrows over targets, key hints and saved progress. Skippable and replayable.

var game = null
var _steps: Array = []
var _progress := 0
var _busy := false
var _poll_t := 0.0
var _step_started := false
var skip_dialogs := false   # automated tests only

func _ready() -> void:
	add_to_group("tutorial")
	_steps = ResourceDatabase.quests.get("tutorial", [])
	Events.block_mined.connect(_on_block)
	Events.item_collected.connect(_on_collect)
	Events.elevator_used.connect(_on_elevator)
	Events.machine_output.connect(func(_m, item, n): _on_event("smelt_item", item, n))
	Events.sold.connect(func(_v): _on_event("sell", "", 1))
	Events.skill_ranked.connect(func(_id, _r): _poll_t = 0.0)
	Events.equipment_changed.connect(func(): _poll_t = 0.0)
	Events.tutorial_changed.connect(_on_tutorial_changed)
	await get_tree().process_frame
	await get_tree().process_frame
	if not GameState.tutorial.get("done", false):
		_enter_step()
	else:
		_clear_hud_arrow()

func active() -> bool:
	return not GameState.tutorial.get("done", false)

func step_index() -> int:
	return int(GameState.tutorial.get("step", 0))

func current() -> Dictionary:
	var i := step_index()
	return _steps[i] if i < _steps.size() else {}

func _ui():
	return game.ui if game else null

func _enter_step() -> void:
	var s := current()
	if s.is_empty():
		_finish()
		return
	_progress = 0
	_step_started = true
	_set_hud(s)
	if game:
		game.point_arrow_at(String(s.get("highlight", "")))
	# step-specific setup
	match String(s.id):
		"t_smelt":
			if GameState.count_available("copper_ore") < 2:
				GameState.add_item("copper_ore", 4, false)
				Events.notify.emit("Mara gave you 4 Copper Ore", "good")
		"t_pickaxe":
			if not GameState.tutorial.get("coins_given", false):
				GameState.tutorial["coins_given"] = true
				GameState.add_coins(int(s.get("reward_coins", 350)), false)
		"t_next":
			GameState.unlock_station(2)
	if String(s.get("type", "")) != "talk_mara":
		await _say(s.get("lines", []))
	_poll_t = 0.0

func _say(lines: Array) -> void:
	if lines.is_empty() or skip_dialogs:
		return
	var ui = _ui()
	if ui and ui.has_method("show_dialog"):
		_busy = true
		await ui.show_dialog(lines, "Mara")
		_busy = false
	else:
		for l in lines:
			Events.notify.emit("Mara: " + String(l), "info")

func _set_hud(s: Dictionary) -> void:
	var count := int(s.get("count", 1))
	var ptxt := "%d/%d" % [mini(_progress, count), count] if count > 1 else ""
	GameState.quest_state["hud"] = {"title": "Tutorial %d/%d" % [step_index() + 1, _steps.size()], "text": String(s.get("text", "")), "progress": ptxt, "short": String(s.get("title", "")), "hint": String(s.get("hint", ""))}
	Events.quest_progress.emit("hud")
	var ui = _ui()
	if ui and ui.has_method("set_tutorial_objective"):
		ui.set_tutorial_objective(String(s.get("title", "")), String(s.get("text", "")), ptxt)

func _clear_hud_arrow() -> void:
	if game:
		game.point_arrow_at("")
	var ui = _ui()
	if ui and ui.has_method("set_tutorial_objective"):
		ui.set_tutorial_objective("", "", "")

func _advance() -> void:
	if not active():
		return
	var s := current()
	AudioManager.play("quest_complete", -4.0)
	GameState.add_xp(15.0, false)
	Events.notify.emit("Done: %s" % s.get("title", ""), "good")
	if String(s.id) == "t_board" and GameState.level < 2:
		var need := GameState.xp_needed() - GameState.xp
		GameState.add_xp(need, false)
	GameState.tutorial["step"] = step_index() + 1
	Events.tutorial_changed.emit()
	SaveManager.save_game()
	if step_index() >= _steps.size():
		_finish()
	else:
		_enter_step()

func _finish() -> void:
	if GameState.tutorial.get("done", false) and not _step_started:
		return
	GameState.tutorial["done"] = true
	GameState.set_counter_max("tutorial", 1)
	_clear_hud_arrow()
	Events.tutorial_changed.emit()
	Events.notify.emit("Tutorial complete!", "legendary")
	await _say([ResourceDatabase.quests.get("tutorial_end", "There's a whole world waiting below us.")])
	_step_started = false
	Events.quest_progress.emit("hud")

func _on_tutorial_changed() -> void:
	# Skip from settings
	if GameState.tutorial.get("done", false) and GameState.tutorial.get("skipped", false) and not GameState.tutorial.get("skip_rewarded", false):
		GameState.tutorial["skip_rewarded"] = true
		if not GameState.tutorial.get("coins_given", false):
			GameState.tutorial["coins_given"] = true
			GameState.add_coins(350, false)
		GameState.unlock_station(2)
		_clear_hud_arrow()
	# Replay from settings / journal
	if not GameState.tutorial.get("done", false) and step_index() == 0 and not _busy and not _step_started:
		_enter_step()

func on_mara_talk() -> void:
	if not active():
		var lines := ["Keep digging, partner. The deeper you go, the richer the rock!", "Check the Mining Board for quests, and the Research Board for new skills."]
		if GameState.skill_points > 0:
			lines = ["You've got %d unspent Skill Point%s! Visit the Research Board." % [GameState.skill_points, "s" if GameState.skill_points > 1 else ""]]
		_say([lines[randi() % lines.size()]])
		return
	if _busy:
		return
	var s := current()
	if String(s.get("type", "")) == "talk_mara":
		await _say(s.get("lines", []))
		_advance()
	else:
		_say(s.get("lines", []))

# ---------------------------------------------------------------- progress
func _bump(amount: int) -> void:
	var s := current()
	_progress += amount
	_set_hud(s)
	if _progress >= int(s.get("count", 1)):
		_advance()

func _on_event(type: String, target: String, amount: int) -> void:
	if not active() or _busy:
		return
	var s := current()
	if String(s.get("type", "")) != type:
		return
	var want := String(s.get("target", ""))
	if want != "" and target != "" and want != target:
		return
	_bump(amount)

func _on_block(id: int, _c: Vector2i) -> void:
	var key := String(ResourceDatabase.block(id).get("key", ""))
	if key == "hard_stone":
		key = "stone"
	_on_event("mine_block", key, 1)

func _on_collect(id: String, n: int) -> void:
	_on_event("collect", id, n)

func _on_elevator(idx: int) -> void:
	var s := current()
	match String(s.get("type", "")):
		"use_elevator":
			if idx == int(String(s.get("target", "0"))):
				_bump(1)
		"ride_to_station":
			if idx == int(String(s.get("target", "2"))):
				_bump(1)

func _process(delta: float) -> void:
	if not active() or _busy:
		return
	_poll_t -= delta
	if _poll_t > 0.0:
		return
	_poll_t = 0.25
	var s := current()
	match String(s.get("type", "")):
		"move":
			if game and game.player.has_moved_both_ways():
				_bump(1)
		"reach_x":
			if game and game.player.global_position.x >= game.camp.ENTRANCE_X - 24.0:
				_bump(1)
		"collect":
			if GameState.count_item(String(s.target)) >= int(s.count):
				_progress = int(s.count) - 1
				_bump(1)
		"open_panel":
			var ui = _ui()
			if ui and ui.has_method("current_panel") and ui.current_panel() == String(s.target):
				_bump(1)
		"skill_rank":
			if SkillManager.rank(String(s.target)) >= int(s.count):
				_bump(1)
		"own_equipment":
			if GameState.owns(String(s.target)):
				_bump(1)
