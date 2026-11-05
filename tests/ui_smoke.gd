extends SceneTree
## Headless UI smoke test: opens every core panel/tab and machine kind to catch script errors.
func _initialize() -> void:
	await process_frame
	var ui = load("res://scenes/ui/UIRoot.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var GS = root.get_node("GameState")
	GS.new_game(7)
	GS.coins = 999999
	GS.level = 30
	GS.at_surface = true
	for id in ["stone", "copper_ore", "iron_ore", "quartz", "geode_small", "health_potion", "ladder", "diamond"]:
		GS.add_item(id, 5, false)
	GS.storage = {"stone": 50, "coal": 10}
	for p in ["inventory", "storage", "shop", "elevator"]:
		ui.open_panel(p)
		await process_frame
		ui.close_panel()
	ui.open_panel("shop")
	var shop = ui.get_panel("shop")
	for t in ["Pickaxes", "Equipment", "Backpacks", "Special Items", "Machines", "Sell"]:
		shop._tab = t
		shop.refresh()
		await process_frame
	shop._buy_equipment("copper_pickaxe")
	shop._buy_item("dynamite", 5)
	shop._sell("stone", 1)
	shop._sell_all_of("coal")
	ui.close_panel()
	for mid in ["smelter", "crusher", "gem_polisher", "auto_drill", "ore_sorter", "mining_robot", "deep_core_drill", "crystal_extractor", "advanced_smelter"]:
		GS.machine_state(mid).owned = true
		ui.open_panel("machine", mid)
		await process_frame
		var mp = ui.get_panel("machine")
		mp._set_qty(-1)
		if mp._recipe >= 0:
			mp._start()
		mp._collect()
		ui.close_panel()
	ui.open_panel("inventory")
	var inv = ui.get_panel("inventory")
	inv._select(0)
	inv._store()
	inv._use()
	ui.close_panel()
	ui.show_confirm("T", "x", func(): print("confirm yes"), "Yes")
	ui.confirm._finish(true)
	ui.set_tutorial_objective("Learn to Move", "Walk with [A] / [D].", "0/1")
	GS.event_state = {"id": "ore_rush", "time_left": 30.0, "progress": 1, "count": 5}
	root.get_node("Events").world_event_started.emit("ore_rush")
	root.get_node("Events").level_up.emit(6)
	root.get_node("Events").inventory_full.emit("stone")
	for i in 10:
		await process_frame
	print("UI SMOKE OK")
	quit()
