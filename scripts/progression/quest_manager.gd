extends Node
## Main quest chain + 3 rotating optional challenges. Listens to gameplay signals and
## keeps GameState.quest_state (incl. the "hud" objective line) up to date.
## quest_state = {"main_index", "main_progress", "challenges": [{"id","progress"}], "hud": {...}, "done": {}}

var _check_t := 0.0

func _ready() -> void:
	var qs := GameState.quest_state
	if not qs.has("main_index"):
		qs["main_index"] = 0
		qs["main_progress"] = 0
		qs["challenges"] = []
		qs["done"] = {}
	Events.item_collected.connect(func(id, n): _on("collect", id, n))
	Events.block_mined.connect(_on_block)
	Events.machine_output.connect(_on_machine)
	Events.sold.connect(func(v): _on("sell", "", 1); _on("sell_value", "", v))
	Events.geode_opened.connect(func(_g, _r, _c): _on("open_geodes", "", 1))
	Events.cache_found.connect(func(_c): _on("find_cache", "", 1))
	Events.cart_ridden.connect(func(): _on("cart_ride", "", 1))
	Events.world_event_ended.connect(func(_id, ok): if ok: _on("event_complete", "", 1))
	_fill_challenges()
	_update_hud()

func _main_def() -> Dictionary:
	var main: Array = ResourceDatabase.quests.get("main", [])
	var i := int(GameState.quest_state.get("main_index", 0))
	return main[i] if i < main.size() else {}

func _on_block(id: int, _cell: Vector2i) -> void:
	var b := ResourceDatabase.block(id)
	_on("mine_any", "", 1)
	_on("mine_block", String(b.get("key", "")), 1)
	if ResourceDatabase.is_deposit(id):
		_on("mine_ore", "", 1)
		if b.get("sound", "") == "crystal":
			_on("mine_gem", "", 1)

func _on_machine(mid: String, item: String, n: int) -> void:
	_on("smelt_item", item, n)
	if mid in ["crusher", "ore_sorter"]:
		_on("crush", "", n)

static func matches(def: Dictionary, type: String, target: String) -> bool:
	if String(def.get("type", "")) != type:
		return false
	var want := String(def.get("target", ""))
	if want == "" or target == "":
		return want == "" or type in ["sell", "sell_value", "mine_any", "mine_ore", "mine_gem", "open_geodes", "find_cache", "cart_ride", "event_complete", "crush"]
	if type == "collect":
		return ResourceDatabase.item_matches(target, want)
	if type == "mine_block" and want == "stone":
		return target == "stone" or target == "hard_stone"
	return target == want

func _on(type: String, target: String, amount: int) -> void:
	if not GameState.tutorial.get("done", false):
		return
	var qs := GameState.quest_state
	var m := _main_def()
	if not m.is_empty() and matches(m, type, target):
		qs.main_progress = int(qs.main_progress) + amount
		_check_main()
	for ch in qs.challenges:
		var def := _challenge_def(String(ch.id))
		if not def.is_empty() and matches(def, type, target):
			ch.progress = int(ch.progress) + amount
	_check_challenges()
	_update_hud()

func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		if GameState.tutorial.get("done", false):
			_check_main()
			_update_hud()

## Progress for state-based objectives (depth, equipment, unique gems...).
static func state_progress(def: Dictionary, stored: int) -> int:
	match String(def.get("type", "")):
		"reach_depth":
			return GameState.max_depth
		"own_equipment":
			return 1 if GameState.owns(String(def.target)) else 0
		"unique_gems":
			var n := 0
			for id in GameState.collection:
				if ResourceDatabase.item_category(id) == "gem":
					n += 1
			return n
		"skill_rank":
			return SkillManager.rank(String(def.target))
		"level":
			return GameState.level
	return stored

func _check_main() -> void:
	var qs := GameState.quest_state
	var m := _main_def()
	if m.is_empty():
		return
	var prog := state_progress(m, int(qs.main_progress))
	if prog >= int(m.count):
		_reward(m)
		qs.done[m.id] = true
		qs.main_index = int(qs.main_index) + 1
		qs.main_progress = 0
		Events.quest_completed.emit(m.id, m.title)
		Events.notify.emit("Quest complete: %s!" % m.title, "epic")
		AudioManager.play("quest_complete", 0.0)
		SaveManager.save_game()

func _reward(def: Dictionary, mult: float = 1.0) -> void:
	var c := int(round(float(def.get("reward_coins", 0)) * mult))
	if c > 0:
		GameState.add_coins(c)
	var x := float(def.get("reward_xp", 0)) * mult
	if x > 0.0:
		GameState.add_xp(x)
	var sp := int(def.get("reward_sp", 0))
	if sp > 0:
		GameState.add_skill_points(sp)
		Events.notify.emit("+%d Skill Point%s!" % [sp, "s" if sp > 1 else ""], "legendary")

# ---------------------------------------------------------------- challenges
func _challenge_def(id: String) -> Dictionary:
	for c in ResourceDatabase.quests.get("challenges", []):
		if c.id == id:
			return c
	return {}

func _fill_challenges() -> void:
	var qs := GameState.quest_state
	var deepest := GameState.deepest_biome()
	var active: Array = []
	for ch in qs.challenges:
		active.append(String(ch.id))
	var pool: Array = []
	for c in ResourceDatabase.quests.get("challenges", []):
		if active.has(c.id):
			continue
		if int(c.get("min_biome", 0)) > deepest:
			continue
		if c.has("max_biome") and deepest > int(c.max_biome):
			continue
		pool.append(c.id)
	pool.shuffle()
	while qs.challenges.size() < 3 and not pool.is_empty():
		qs.challenges.append({"id": pool.pop_back(), "progress": 0})

func _check_challenges() -> void:
	var qs := GameState.quest_state
	var finished: Array = []
	for ch in qs.challenges:
		var def := _challenge_def(String(ch.id))
		if def.is_empty():
			finished.append(ch)
			continue
		if int(ch.progress) >= int(def.count):
			finished.append(ch)
			var mult := 1.0 + GameState.level * 0.04
			_reward(def, mult)
			Events.quest_completed.emit(def.id, def.title)
			Events.notify.emit("Challenge complete: %s!" % def.title, "rare")
			AudioManager.play("quest_complete", -2.0)
	for f in finished:
		qs.challenges.erase(f)
	if not finished.is_empty():
		_fill_challenges()

func _update_hud() -> void:
	var qs := GameState.quest_state
	if not GameState.tutorial.get("done", false):
		return # tutorial sets the HUD line itself
	var m := _main_def()
	if m.is_empty():
		qs["hud"] = {"title": "Main Quest", "text": "All main quests complete!", "progress": ""}
	else:
		var prog := state_progress(m, int(qs.main_progress))
		var count := int(m.count)
		var ptxt := "%s/%s" % [ResourceDatabase.fmt_num(mini(prog, count)), ResourceDatabase.fmt_num(count)]
		if m.type == "reach_depth":
			ptxt = "%dm/%dm" % [mini(prog, count), count]
		elif m.type == "own_equipment":
			ptxt = ""
		qs["hud"] = {"title": "Main Quest", "text": m.title + ": " + m.text, "progress": ptxt, "short": String(m.get("short", m.title))}
	Events.quest_progress.emit("hud")
