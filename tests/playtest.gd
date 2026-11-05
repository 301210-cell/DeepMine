extends Node
## Automated playtest: plays through the tutorial loop with simulated input and checks results.
## Run: bash tools/capture.sh res://tests/Playtest.tscn <out.png> 4000
## (the capture tool waits; this script quits itself when finished)

const WD = preload("res://scripts/world/world_data.gd")
var game: Node
var results: Array[String] = []
var fails := 0
var shot_dir := ""

func _ready() -> void:
	shot_dir = OS.get_cmdline_user_args()[1].get_base_dir() if OS.get_cmdline_user_args().size() > 1 else "user://"
	GameState.new_game(777)
	GameState.world = load("res://scripts/world/world_gen.gd").new().generate(777)
	game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	game.get_node("Systems/Tutorial").skip_dialogs = true
	_run()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout

func dialog_node() -> Node:
	for n in game.ui.find_children("*", "", true, false):
		if n.has_method("start") and n.has_method("_advance") and n.has_method("is_open"):
			return n
	return null

func dismiss_dialogs() -> void:
	var d := dialog_node()
	for i in 40:
		await frames(3)
		if d == null or not d.is_open():
			return
		d._advance()

func send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func hold(action: String, n: int) -> void:
	send(action, true)
	for i in n:
		await get_tree().physics_frame
	send(action, false)

func shot(name: String) -> void:
	await frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join("pt_" + name + ".png"))

func step_id() -> String:
	var t: Array = ResourceDatabase.quests.tutorial
	var i := int(GameState.tutorial.step)
	return t[i].id if i < t.size() else "done"

func teleport(p: Vector2) -> void:
	game.player.global_position = p
	game.player.velocity = Vector2.ZERO
	game.renderer.force_load_around(p, Vector2(700, 400))
	game.camera.global_position = p
	game._on_player_cell(WD.cell_of(p + Vector2(0, -8)))

func _run() -> void:
	await secs(1.0)
	var p = game.player
	check("player spawned on floor", p.is_on_floor(), str(p.global_position))
	check("tutorial starts at t_meet", step_id() == "t_meet", step_id())
	# 1. Talk to Mara
	game.get_node("Systems/Tutorial").on_mara_talk()
	await dismiss_dialogs()
	await secs(0.3)
	await dismiss_dialogs()
	check("talked to Mara -> t_move", step_id() == "t_move", step_id())
	# 2. Move both ways
	var x0: float = p.global_position.x
	await hold("move_left", 25)
	await hold("move_right", 45)
	check("walking moves the player", absf(p.global_position.x - x0) > 10.0, "dx=%.1f" % (p.global_position.x - x0))
	var y0: float = p.global_position.y
	send("jump", true)
	for i in 10:
		await get_tree().physics_frame
	var jumped: bool = p.global_position.y < y0 - 8.0
	send("jump", false)
	check("jump works", jumped)
	await secs(0.6)
	await dismiss_dialogs()
	check("moved -> t_entrance", step_id() == "t_entrance", step_id())
	await secs(0.3)
	await dismiss_dialogs()
	# 2b. World edges: walking off either side of the surface must be blocked
	teleport(Vector2(70, -0.5))
	await secs(0.3)
	await hold("move_left", 120)
	check("left world edge blocks the player", p.global_position.x >= 15.0 and p.global_position.y < 8.0, str(p.global_position))
	teleport(Vector2(WD.W * 16 - 70, -0.5))
	await secs(0.3)
	await hold("move_right", 120)
	check("right world edge blocks the player", p.global_position.x <= WD.W * 16 - 15.0 and p.global_position.y < 8.0, str(p.global_position))
	# 3. Enter the mine through the portal (cutscene)
	teleport(Vector2(game.camp.ENTRANCE_X - 70, -0.5))
	await secs(0.4)
	check("no pit under the mine portal", game.world.is_solid(WD.ENTRANCE_X, 0) and game.world.is_solid(WD.ENTRANCE_X + 1, 1))
	game.enter_mine()
	await secs(1.4)
	await shot("cut_doorway")
	await secs(1.6)
	await shot("cut_inside")
	await secs(4.0)
	await shot("cut_arrived")
	await dismiss_dialogs()
	check("entered mine -> t_mine", step_id() == "t_mine", step_id())
	check("arrived at first blocks", p.global_position.y > 100.0 and absf(p.global_position.x - (game.world.markers["tutorial_stone"].x * 16 - 10.0)) < 24.0, str(p.global_position))
	check("input restored after cutscene", p.input_enabled)
	await dismiss_dialogs()
	# 4. Mine stone in the tutorial cave
	var stone_cell: Vector2i = game.world.markers["tutorial_stone"]
	teleport(Vector2(stone_cell.x * 16 - 12, (stone_cell.y + 1) * 16 - 0.5))
	await secs(0.4)
	var mined := 0
	var mc = game.mining
	for c in [stone_cell, stone_cell + Vector2i(1, 0), Vector2i(110, 9), Vector2i(115, 9), Vector2i(108, 10), Vector2i(109, 10)]:
		for i in 12:
			var id: int = game.world.get_blockv(c)
			if not ResourceDatabase.is_solid(id):
				break
			mc._damage_cell(c, id, 1.0, true)
			await frames(2)
		if game.world.get_blockv(c) == 0:
			mined += 1
	check("mined blocks", mined >= 3, "mined=%d" % mined)
	await secs(1.2)
	check("pickups collected into backpack", GameState.count_item("stone") > 0, "stone=%d" % GameState.count_item("stone"))
	await dismiss_dialogs()
	await shot("mining")
	# swing animation check
	mc._swing_cell = stone_cell + Vector2i(2, 0)
	check("tool sprite exists", p.tool_sprite != null)
	# 5. Collect 10 stone
	await dismiss_dialogs()
	GameState.add_item("stone", 10)
	await secs(0.6)
	await dismiss_dialogs()
	check("collected -> t_elevator", step_id() == "t_elevator", step_id())
	# 6. Elevator back to camp
	await dismiss_dialogs()
	Events.elevator_travel_requested.emit(0)
	await secs(2.2)
	check("elevator to surface", p.global_position.y < 10.0, str(p.global_position))
	await dismiss_dialogs()
	check("elevator -> t_smelt", step_id() == "t_smelt", step_id())
	# 7. Smelt copper
	var ML = load("res://scripts/machines/machine_logic.gd")
	await dismiss_dialogs()
	var q: String = ML.queue_recipe("smelter", 0, 2)
	check("smelter queue", q == "", q)
	await secs(9.5)
	check("smelter produced bars", ML.output_total("smelter") >= 1, str(GameState.machine_state("smelter").output))
	ML.collect("smelter")
	await secs(0.4)
	await dismiss_dialogs()
	check("smelt -> t_sell", step_id() == "t_sell", step_id())
	# 8. Sell
	await dismiss_dialogs()
	var v: int = GameState.sell_from_inventory("copper_bar", 1)
	check("sold bar", v > 0, "value=%d" % v)
	await secs(0.4)
	await dismiss_dialogs()
	check("sell -> t_board", step_id() == "t_board", step_id())
	# 9. Open skill tree
	await dismiss_dialogs()
	Events.open_panel_requested.emit("skills", null)
	await secs(0.8)
	await shot("skills_tutorial")
	await dismiss_dialogs()
	check("opened skills -> t_skill", step_id() == "t_skill", step_id())
	check("level 2+ for first skill point", GameState.level >= 2 and GameState.skill_points >= 1, "lvl=%d sp=%d" % [GameState.level, GameState.skill_points])
	await dismiss_dialogs()
	var power_before := GameState.stat(&"mining_power")
	SkillManager.rank_up("strong_swing")
	check("strong swing raises mining power", GameState.stat(&"mining_power") > power_before, "%.2f -> %.2f" % [power_before, GameState.stat(&"mining_power")])
	await secs(0.6)
	game.ui.close_panel()
	await dismiss_dialogs()
	check("skill -> t_pickaxe", step_id() == "t_pickaxe", step_id())
	# 10. Buy pickaxe
	await dismiss_dialogs()
	var why: String = GameState.buy_equipment("copper_pickaxe")
	check("bought copper pickaxe", why == "", why + " coins=%d" % GameState.coins)
	await secs(0.5)
	await dismiss_dialogs()
	check("pickaxe -> t_next", step_id() == "t_next", step_id())
	check("station 2 unlocked", GameState.stations[2])
	# 11. Ride to Old Workings
	await dismiss_dialogs()
	Events.elevator_travel_requested.emit(2)
	await secs(2.2)
	await dismiss_dialogs()
	await secs(0.5)
	await dismiss_dialogs()
	check("tutorial complete", GameState.tutorial.get("done", false), step_id())
	check("depth ~150m", GameState.current_depth >= 140, "depth=%d" % GameState.current_depth)
	await shot("old_workings")
	# 12. Panels open without errors
	for panel in ["inventory", "storage", "shop", "map", "journal", "pause", "settings", "elevator"]:
		Events.open_panel_requested.emit(panel, {"current": 2} if panel == "elevator" else null)
		await secs(0.35)
		if panel in ["inventory", "map", "journal"]:
			await shot("panel_" + panel)
		game.ui.close_panel()
		await frames(3)
	check("panels opened", true)
	# 13. Dynamite + ladder placement
	GameState.add_item("dynamite", 2)
	game.throw_dynamite(p.global_position + Vector2(0, -17), Vector2(120, -60))
	await secs(2.0)
	check("dynamite exploded (no crash)", true)
	# 14. Event start/end
	var em = game.get_node("Systems/EventManager")
	em.start("crystal_surge")
	await secs(0.8)
	await shot("event")
	check("event active", String(GameState.event_state.id) == "crystal_surge")
	GameState.event_state.time_left = 0.01
	await secs(0.5)
	check("event ended", String(GameState.event_state.id) == "")
	# 15. Save / load
	GameState.in_game = true
	var saved: bool = SaveManager.save_game()
	check("save written", saved and FileAccess.file_exists(SaveManager.SAVE_PATH))
	var coins := GameState.coins
	var lvl := GameState.level
	var ok_load: bool = SaveManager.load_game()
	check("save loads", ok_load and GameState.coins == coins and GameState.level == lvl, "coins %d/%d" % [GameState.coins, coins])
	var wd2 = WD.deserialize(SaveManager.pending_world)
	check("world restored", wd2 != null and wd2.blocks == game.world.blocks)
	# report
	print("=========== PLAYTEST ===========")
	for r in results:
		print(r)
	print("RESULT: %d checks, %d failed" % [results.size(), fails])
	get_tree().quit()
