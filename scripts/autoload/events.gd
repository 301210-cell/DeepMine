extends Node
## Global signal bus (autoload "Events").
## Gameplay systems emit here; UI and other systems listen. Keeps systems decoupled.

# Economy / progression
signal coins_changed(total: int, delta: int)
signal xp_changed(xp: int, xp_needed: int, level: int)
signal xp_gained(amount: int)
signal level_up(level: int)
signal skill_points_changed(points: int)
signal sold(value: int)

# Inventory
signal inventory_changed
signal storage_changed
signal hotbar_changed
signal item_collected(item_id: String, amount: int)
signal item_discovered(item_id: String)
signal inventory_full(item_id: String)
signal collection_changed
signal geode_opened(geode_id: String, rewards: Array, coins: int)

# Mining / world
signal block_mined(block_id: int, cell: Vector2i)
signal depth_changed(depth_m: int, biome: int)
signal biome_entered(biome: int)
signal station_unlocked(index: int)
signal elevator_used(station_index: int)
signal cache_found(cell: Vector2i)
signal cart_ridden
signal chamber_discovered(name: String)

# Equipment / skills / machines
signal equipment_changed
signal skill_ranked(skill_id: String, rank: int)
signal skills_reset(refund: int)
signal stats_changed
signal machine_changed(machine_id: String)
signal machine_output(machine_id: String, item_id: String, amount: int)

# Quests / events / achievements
signal quest_progress(quest_id: String)
signal quest_completed(quest_id: String, title: String)
signal tutorial_changed
signal world_event_started(event_id: String)
signal world_event_ended(event_id: String, completed: bool)
signal achievement_unlocked(id: String)

# Player
signal player_hurt(amount: float)
signal player_health_changed(hp: float, max_hp: float)
signal player_died

# UI / presentation
signal notify(text: String, kind: String) # kind: info, good, warn, rare, epic, legendary, coin, xp
signal float_text(world_pos: Vector2, text: String, color: Color)
signal open_panel_requested(panel: String, data: Variant)
signal panel_opened(panel: String)
signal panel_closed(panel: String)
signal mara_dialog(lines: Array, title: String)
signal day_phase_changed(phase: String)
signal game_saved
signal screen_shake(strength: float, duration: float)

# Requests from UI to the game world
signal elevator_travel_requested(station_index: int)
signal drop_item_requested(item_id: String, amount: int)
signal use_item_requested(item_id: String)
signal dialog_finished
signal recall_requested
signal loot_cart_found
signal mara_talked
signal mine_entered
signal mine_exited
