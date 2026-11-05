extends Node
## Timed world events (Crystal Surge, Geode Fever, Ore Rush, Meteor Shower, Abandoned Cart,
## Double Extraction, Ancient Discovery, Rare Expedition). Each has an announcement,
## duration, visual + gameplay effect, an optional challenge, reward and completion notice.
## GameState.event_state = {"id","time_left","progress","count","quest_text","next_in"}

const WD = preload("res://scripts/world/world_data.gd")

var game = null
var _spawned: Array = []      # [Vector2i, original_block] to revert when the event ends
var _meteor_t := 0.0

func _ready() -> void:
	var es := GameState.event_state
	if not es.has("next_in"):
		es["next_in"] = 150.0  # first event a few minutes in
		es["id"] = ""
	Events.block_mined.connect(_on_block)
	Events.item_collected.connect(func(id, n): _on("collect", id, n))
	Events.cache_found.connect(func(_c): _on("find_cache", "", 1))
	Events.loot_cart_found.connect(func(): _on("loot_cart", "", 1))
	if String(es.get("id", "")) != "":
		_apply_mods(_def(String(es.id)))

func _def(id: String) -> Dictionary:
	for e in ResourceDatabase.events:
		if e.id == id:
			return e
	return {}

func _process(delta: float) -> void:
	var es := GameState.event_state
	if not GameState.tutorial.get("done", false):
		return
	if String(es.get("id", "")) == "":
		es.next_in = float(es.get("next_in", 200.0)) - delta
		if float(es.next_in) <= 0.0:
			_start_random()
	else:
		es.time_left = float(es.time_left) - delta
		if String(es.id) == "meteor_shower":
			_meteor_t -= delta
			if _meteor_t <= 0.0:
				_meteor_t = randf_range(2.0, 4.0)
				_meteor_visual()
		if float(es.time_left) <= 0.0:
			_end(false)

func _start_random() -> void:
	var night: bool = game and game.night_factor() > 0.5
	var deepest := GameState.deepest_biome()
	var pool: Array = []
	var total := 0.0
	for e in ResourceDatabase.events:
		if e.get("night_only", false) and not night:
			continue
		if int(e.get("min_biome", 0)) > deepest:
			continue
		pool.append(e)
		total += float(e.weight)
	if pool.is_empty():
		GameState.event_state.next_in = 60.0
		return
	var r := randf() * total
	for e in pool:
		r -= float(e.weight)
		if r <= 0.0:
			start(String(e.id))
			return
	start(String(pool[0].id))

func start(id: String) -> void:
	var e := _def(id)
	if e.is_empty():
		return
	var es := GameState.event_state
	es.id = id
	es.time_left = float(e.duration)
	es.progress = 0
	es.count = int(e.get("quest", {}).get("count", 0))
	es.quest_text = String(e.get("quest", {}).get("text", ""))
	es.done = false
	_apply_mods(e)
	_spawn_effect(e)
	Events.world_event_started.emit(id)
	Events.notify.emit("EVENT! %s" % e.name, "epic")

func _apply_mods(e: Dictionary) -> void:
	GameState.event_mods = {}
	var eff: Dictionary = e.get("effect", {})
	match String(eff.get("type", "")):
		"geode_mult": GameState.event_mods["geode_mult"] = float(eff.value)
		"ore_bonus": GameState.event_mods["ore_bonus"] = float(eff.value)
		"drop_mult": GameState.event_mods["drop_mult"] = float(eff.value)
	Events.stats_changed.emit()

func _end(forced: bool) -> void:
	var es := GameState.event_state
	var e := _def(String(es.id))
	var completed: bool = es.get("done", false)
	# revert unmined temporary deposits
	if game:
		for pair in _spawned:
			var c: Vector2i = pair[0]
			if game.world.get_blockv(c) == int(pair[2]):
				game.world.set_block(c.x, c.y, int(pair[1]))
	_spawned.clear()
	GameState.event_mods = {}
	Events.stats_changed.emit()
	es.id = ""
	es.next_in = randf_range(float(ResourceDatabase.event_interval[0]), float(ResourceDatabase.event_interval[1]))
	AudioManager.play("event_end", -2.0)
	Events.world_event_ended.emit(String(e.get("id", "")), completed)
	if not forced:
		Events.notify.emit("%s has ended." % e.get("name", "Event") + ("" if completed else " Better luck next time!"), "info")

func _complete_quest() -> void:
	var es := GameState.event_state
	if es.get("done", false):
		return
	es.done = true
	var e := _def(String(es.id))
	var mult := 1.0 + GameState.deepest_biome()
	var coins := int(float(e.get("reward_coins", 0)) * mult)
	GameState.add_coins(coins)
	GameState.add_xp(float(e.get("reward_xp", 0)) * mult)
	GameState.add_counter("event_complete", 1)
	AudioManager.play("quest_complete", 0.0)
	Events.notify.emit("Event challenge complete! +$%s" % ResourceDatabase.fmt_num(coins), "legendary")

# ---------------------------------------------------------------- quest tracking
func _on_block(id: int, _c: Vector2i) -> void:
	var b := ResourceDatabase.block(id)
	_on("mine_any", "", 1)
	if ResourceDatabase.is_deposit(id):
		_on("mine_ore", "", 1)
		if b.get("sound", "") == "crystal":
			_on("mine_gem", "", 1)

func _on(type: String, target: String, n: int) -> void:
	var es := GameState.event_state
	if String(es.get("id", "")) == "" or es.get("done", false):
		return
	var q: Dictionary = _def(String(es.id)).get("quest", {})
	if String(q.get("type", "")) != type:
		return
	var want := String(q.get("target", ""))
	if want != "" and target != "" and not ResourceDatabase.item_matches(target, want):
		return
	es.progress = int(es.progress) + n
	Events.quest_progress.emit("event")
	if int(es.progress) >= int(es.count):
		_complete_quest()

# ---------------------------------------------------------------- spawned effects
func _player_cell() -> Vector2i:
	return WD.cell_of(game.player.global_position + Vector2(0, -8))

func _rare_blocks_for(bi: int) -> Array:
	var b := ResourceDatabase.biome(maxi(bi, 0))
	var ores: Array = b.get("ores", []).duplicate()
	ores.sort_custom(func(a, c): return float(a.per_1k) < float(c.per_1k))
	var out: Array = []
	for o in ores:
		var id := int(o.block)
		if id != 72 and id != 73:
			out.append(id)
		if out.size() >= 4:
			break
	return out

func _spawn_effect(e: Dictionary) -> void:
	if game == null:
		return
	var eff: Dictionary = e.get("effect", {})
	var pc := _player_cell()
	var wd = game.world
	var bi: int = maxi(0, wd.biome_at_row(maxi(pc.y, 12)))
	match String(eff.get("type", "")):
		"spawn_deposits":
			var list := _rare_blocks_for(bi)
			if bi == 0:
				list = [42, 52, 48, 43]  # quartz + crystal shards + amethyst surge near the surface
			_scatter(list, int(eff.get("count", 14)), pc, 6, 28, true)
		"meteor":
			_scatter([71], int(eff.get("count", 8)), pc, 6, 30, true)
		"cart":
			var spot := _find_floor_spot(pc, 12, 40)
			if spot != Vector2i(-1, -1):
				var ent := {"type": "loot_cart", "x": spot.x, "y": spot.y, "biome": bi, "event": true}
				wd.entities.append(ent)
				game.entities.add_entity(ent)
				Events.notify.emit("A glowing cart appeared %s of you!" % ("east" if spot.x > pc.x else "west"), "rare")
		"ancient_chamber":
			_make_chamber(pc, bi)
		"expedition":
			_make_expedition(pc, bi)

func _scatter(list: Array, count: int, pc: Vector2i, rmin: int, rmax: int, exposed_pref: bool) -> void:
	var wd = game.world
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 60:
		tries += 1
		var ang := randf() * TAU
		var r := randf_range(rmin, rmax)
		var c := pc + Vector2i(int(cos(ang) * r), int(sin(ang) * r * 0.7))
		if c.y < 8:
			continue
		var id: int = wd.get_blockv(c)
		if not (id >= 1 and id <= 16 and id != 10):
			continue
		if exposed_pref and wd.is_solid(c.x, c.y - 1) and wd.is_solid(c.x, c.y + 1) and wd.is_solid(c.x - 1, c.y) and wd.is_solid(c.x + 1, c.y):
			continue
		var nid: int = list[randi() % list.size()]
		_spawned.append([c, id, nid])
		wd.set_block(c.x, c.y, nid)
		placed += 1

func _find_floor_spot(pc: Vector2i, rmin: int, rmax: int) -> Vector2i:
	var wd = game.world
	for i in 400:
		var c := pc + Vector2i(randi_range(-rmax, rmax), randi_range(-rmax / 2, rmax / 2))
		if absi(c.x - pc.x) < rmin or c.y < 10:
			continue
		if wd.get_blockv(c) == 0 and wd.get_block(c.x + 1, c.y) == 0 and wd.is_solid(c.x, c.y + 1) and wd.is_solid(c.x + 1, c.y + 1) and wd.get_block(c.x, c.y - 1) == 0:
			return c
	return Vector2i(-1, -1)

func _make_chamber(pc: Vector2i, bi: int) -> void:
	var wd = game.world
	var dir := 1 if randf() < 0.5 else -1
	var cx := clampi(pc.x + dir * randi_range(16, 26), 8, WD.W - 9)
	if absi(cx - WD.SHAFT_X0) < 8:
		cx = WD.SHAFT_X1 + 12
	var cy := clampi(pc.y + randi_range(-4, 6), 14, WD.H - 20)
	for y in range(cy - 3, cy + 1):
		for x in range(cx - 4, cx + 5):
			wd.set_block(x, y, 0)
	for x in range(cx - 5, cx + 6):
		if not wd.is_solid(x, cy + 1):
			wd.set_block(x, cy + 1, 15)
	# cracked-wall entrance toward the player
	var ex := cx - dir * 5
	for x in range(mini(ex, pc.x), maxi(ex, pc.x) + 1):
		for y in [cy - 1, cy]:
			if wd.is_solid(x, y) and wd.get_block(x, y) not in [18, 19]:
				wd.set_block(x, y, 75)
	var ent := {"type": "chest", "x": cx, "y": cy, "biome": mini(bi + 1, 5), "gold": true, "chamber": "Ancient Chamber"}
	wd.entities.append(ent)
	game.entities.add_entity(ent)
	wd.set_decor(cx - 3, cy, 16)
	wd.set_decor(cx + 3, cy, 16)
	Events.notify.emit("Follow the cracked wall %s!" % ("east" if dir > 0 else "west"), "rare")

func _make_expedition(pc: Vector2i, bi: int) -> void:
	var wd = game.world
	var x := pc.x
	var y := pc.y
	var dir := 1 if pc.x < WD.W / 2 else -1
	var rare := _rare_blocks_for(bi)
	for i in 48:
		for yy in range(y - 2, y + 1):
			var c := Vector2i(x, yy)
			if wd.get_blockv(c) not in [18, 19] and WD.in_bounds(x, yy):
				wd.set_block(x, yy, 0)
		for side in [y - 3, y + 1]:
			if randf() < 0.3 and wd.is_solid(x, side) and wd.get_block(x, side) not in [18, 19]:
				var nid: int = rare[randi() % rare.size()]
				_spawned.append([Vector2i(x, side), wd.get_block(x, side), nid])
				wd.set_block(x, side, nid)
		x += dir
		if randf() < 0.25:
			y += 1 if randf() < 0.6 else -1
		if x < 3 or x > WD.W - 4 or absi(x - WD.SHAFT_X0 - 1) < 3:
			break
	Events.notify.emit("A rich expedition route opened to the %s!" % ("east" if dir > 0 else "west"), "rare")

func _meteor_visual() -> void:
	if game == null:
		return
	Events.screen_shake.emit(1.2, 0.3)
	AudioManager.play("explosion", -14.0)
	if GameState.at_surface:
		var p: Vector2 = game.player.global_position + Vector2(randf_range(-260, 260), -260)
		game.effects.explosion(p + Vector2(randf_range(-60, 60), 230))
