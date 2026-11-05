extends Node
## Autoload "GameState": all persistent player progress + the central stat calculator.
## Systems change state only through these methods; every change emits an Events signal.

const SAVE_VERSION := 1
const BASE_SWING_RATE := 2.4      # swings per second with speed 1.0
const BASE_MOVE_SPEED := 92.0     # px/s walking
const BASE_JUMP_VELOCITY := 292.0 # px/s
const BASE_PICKUP_RADIUS := 46.0
const BASE_STACK := 99
const BASE_STORAGE_SLOTS := 40
const STORAGE_STACK := 999
const MAX_HP := 100.0
const HOTBAR := ["pickaxe", "drill", "ladder", "torch", "dynamite", "health_potion"]

# ---------------------------------------------------------------- persistent state
var world_seed: int = 0
var coins: int = 0
var total_earned: int = 0
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var skills: Dictionary = {}            # skill_id -> rank
var inventory: Array = []              # slot -> {} or {"id": String, "n": int}
var storage: Dictionary = {}           # item_id -> count
var owned: Dictionary = {}             # equipment id -> true
var equipped: Dictionary = {}          # slot -> equipment id
var machines: Dictionary = {}          # machine_id -> state dict
var collection: Dictionary = {}        # item_id -> {"count": int, "best": int}
var achievements: Dictionary = {}      # id -> true
var counters: Dictionary = {}          # stat counters for quests/achievements
var stations: Array = []               # bool per elevator station
var biomes_found: Array = []           # bool per biome
var chambers: Dictionary = {}          # name -> true
var opened: Dictionary = {}            # "x,y" -> true (chests/carts looted)
var quest_state: Dictionary = {}       # see QuestManager
var tutorial: Dictionary = {"step": 0, "done": false, "skipped": false}
var event_state: Dictionary = {}       # see EventManager
var hotbar_index: int = 0
var hp: float = MAX_HP
var player_pos: Vector2 = Vector2.ZERO
var max_depth: int = 0
var day_time: float = 0.30             # 0..1, 0.25 = 6:00
var day_count: int = 1
var play_time: float = 0.0
var cosmetics: Dictionary = {}         # cosmetic id -> enabled
var collection_rewards: Dictionary = {} # "25"/"50"/"75"/"100" -> true
var ground_items: Array = []           # [{"id","n","x","y"}] dropped items that persist

# Runtime only
var world = null                       # WorldData instance (set by Game scene)
var event_mods: Dictionary = {}        # active event modifiers
var current_depth: int = 0
var current_biome: int = -1
var in_game: bool = false
var ui_blocking: bool = false          # a UI panel is open: player input disabled
var at_surface: bool = true            # player is in the surface camp (selling, storage, geodes allowed)
var _stat_cache: Dictionary = {}

func _ready() -> void:
	Events.stats_changed.connect(func(): _stat_cache.clear())
	Events.equipment_changed.connect(func(): _stat_cache.clear(); _resize_inventory())
	Events.skill_ranked.connect(func(_a, _b): _stat_cache.clear(); _resize_inventory())
	Events.skills_reset.connect(func(_a): _stat_cache.clear(); _resize_inventory())

# ================================================================ new game
func new_game(p_seed: int = -1) -> void:
	world_seed = p_seed if p_seed >= 0 else randi() % 1000000
	coins = 0
	total_earned = 0
	level = 1
	xp = 0
	skill_points = 0
	skills = {"miners_core": 1}
	storage = {}
	owned = {}
	equipped = {}
	for slot in ["pickaxe", "backpack", "lantern", "boots"]:
		var first: String = ResourceDatabase.equipment_by_slot[slot][0]
		owned[first] = true
		equipped[slot] = first
	equipped["drill"] = ""
	equipped["scanner"] = ""
	machines = {}
	for mid in ResourceDatabase.machine_order:
		var m := ResourceDatabase.machine(mid)
		machines[mid] = _new_machine_state(m)
	collection = {}
	achievements = {}
	counters = {}
	stations = []
	stations.resize(ResourceDatabase.stations.size())
	stations.fill(false)
	stations[0] = true
	stations[1] = true
	biomes_found = []
	biomes_found.resize(ResourceDatabase.biomes.size())
	biomes_found.fill(false)
	biomes_found[0] = true
	chambers = {}
	opened = {}
	quest_state = default_quest_state()
	tutorial = {"step": 0, "done": false, "skipped": false}
	event_state = {}
	hotbar_index = 0
	hp = MAX_HP
	player_pos = Vector2.ZERO
	max_depth = 0
	day_time = 0.30
	day_count = 1
	play_time = 0.0
	cosmetics = {}
	collection_rewards = {}
	ground_items = []
	event_mods = {}
	_stat_cache.clear()
	inventory = []
	_resize_inventory()
	add_item("ladder", 12, false)
	add_item("torch", 6, false)

func _new_machine_state(m: Dictionary) -> Dictionary:
	return {
		"owned": m.get("owned", false), "level": 1, "queue": [], "progress": 0.0,
		"output": {}, "biome": int(m.get("biomes", [0])[0]) if m.has("biomes") else 0, "timer": 0.0,
	}

# ================================================================ central stats
## The single place every gameplay system reads tunable numbers from.
## Combines base values + equipped gear + skill tree ranks + active event modifiers.
func stat(name: StringName) -> float:
	if _stat_cache.has(name):
		return _stat_cache[name]
	var v := _compute_stat(name)
	_stat_cache[name] = v
	return v

func skill_bonus(stat_name: String) -> float:
	return SkillManager.bonus(stat_name)

func _compute_stat(name: StringName) -> float:
	var pick := ResourceDatabase.equip(equipped.get("pickaxe", "basic_pickaxe"))
	var boots := ResourceDatabase.equip(equipped.get("boots", "boots_work"))
	match name:
		&"mining_power":
			var p: float = float(pick.get("power", 1.0)) * (1.0 + skill_bonus("mining_power_pct") / 100.0)
			if cosmetics.get("golden_pickaxe_skin", false):
				p *= 1.1
			return p
		&"mining_speed":
			return BASE_SWING_RATE * float(pick.get("speed", 1.0)) * (1.0 + skill_bonus("mining_speed_pct") / 100.0)
		&"tool_tier":
			return float(pick.get("tier", 1))
		&"move_speed":
			return BASE_MOVE_SPEED * (1.0 + skill_bonus("move_speed_pct") / 100.0 + float(boots.get("speed", 0.0)))
		&"jump_velocity":
			return BASE_JUMP_VELOCITY * sqrt(1.0 + skill_bonus("jump_pct") / 100.0 + float(boots.get("jump", 0.0)))
		&"lantern_radius":
			var lan := ResourceDatabase.equip(equipped.get("lantern", "lantern_basic"))
			return float(lan.get("radius", 88)) * (1.0 + skill_bonus("lantern_radius_pct") / 100.0)
		&"backpack_slots":
			var bp := ResourceDatabase.equip(equipped.get("backpack", "backpack_basic"))
			return float(bp.get("slots", 20)) + skill_bonus("backpack_slots")
		&"stack_limit":
			return BASE_STACK + skill_bonus("stack_limit")
		&"pickup_radius":
			return BASE_PICKUP_RADIUS + skill_bonus("pickup_radius")
		&"storage_slots":
			return BASE_STORAGE_SLOTS + skill_bonus("storage_slots")
		&"crit_chance":
			return skill_bonus("crit_chance") / 100.0
		&"ice_grip":
			return clampf(float(boots.get("grip", 0.0)) + skill_bonus("hazard_resist_pct") / 100.0, 0.0, 1.0)
		&"heat_proof":
			return 1.0 if boots.get("heat", false) else 0.0
		&"hazard_resist":
			return clampf(skill_bonus("hazard_resist_pct") / 100.0, 0.0, 0.9)
		&"fall_reduction":
			return clampf(float(boots.get("fall", 0.0)) + skill_bonus("fall_reduction_pct") / 100.0, 0.0, 1.0)
		&"climb_speed":
			return 70.0 * (1.0 + skill_bonus("climb_speed_pct") / 100.0)
		&"scanner_range":
			var sc := ResourceDatabase.equip(equipped.get("scanner", ""))
			if sc.is_empty():
				return 0.0
			return float(sc.get("range", 0)) * (1.0 + skill_bonus("scanner_range_pct") / 100.0)
		&"scanner_min_rarity":
			var sc2 := ResourceDatabase.equip(equipped.get("scanner", ""))
			return float(sc2.get("min_rarity", 9))
		&"map_reveal_radius":
			return 9.0 + skill_bonus("map_reveal_bonus")
		&"xp_mult":
			return 1.0 + skill_bonus("xp_pct") / 100.0
		&"geode_mult":
			return (1.0 + skill_bonus("geode_chance_pct") / 100.0) * float(event_mods.get("geode_mult", 1.0))
		&"drop_mult":
			return float(event_mods.get("drop_mult", 1.0))
		&"ore_bonus":
			return float(event_mods.get("ore_bonus", 0.0))
		&"tool_level_reduction":
			return skill_bonus("tool_level_reduction")
		&"heavy_penalty":
			return 0.22 * clampf(1.0 - skill_bonus("heavy_reduction_pct") / 100.0, 0.0, 1.0)
	# Raw skill stat (percentages / radii): just the skill-tree total.
	return skill_bonus(String(name))

func machine_speed_mult(mid: String) -> float:
	var m := ResourceDatabase.machine(mid)
	var pct := 0.0
	for s in m.get("speed_stats", []):
		pct += skill_bonus(s)
	var st: Dictionary = machines.get(mid, {})
	var lvl_bonus := (int(st.get("level", 1)) - 1) * float(ResourceDatabase.machine_upgrade.get("speed_per_level", 0.25))
	return (1.0 + pct / 100.0) * (1.0 + lvl_bonus)

func machine_output_mult(mid: String) -> float:
	var m := ResourceDatabase.machine(mid)
	var pct := 0.0
	for s in m.get("output_stats", []):
		pct += skill_bonus(s)
	var st: Dictionary = machines.get(mid, {})
	var lvl_bonus := (int(st.get("level", 1)) - 1) * float(ResourceDatabase.machine_upgrade.get("output_per_level", 0.2))
	return (1.0 + pct / 100.0) * (1.0 + lvl_bonus)

# ================================================================ coins / xp
func add_coins(n: int, count_as_earned: bool = true) -> void:
	if n == 0:
		return
	coins += n
	if n > 0 and count_as_earned:
		total_earned += n
		_set_counter("earned", total_earned)
	Events.coins_changed.emit(coins, n)

func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	Events.coins_changed.emit(coins, -n)
	return true

static func xp_needed_for(lvl: int) -> int:
	return int(40.0 * pow(float(lvl), 1.45)) + 20

func xp_needed() -> int:
	return xp_needed_for(level)

func add_xp(amount: float, apply_mult: bool = true) -> void:
	var a := int(round(amount * (stat(&"xp_mult") if apply_mult else 1.0)))
	if a <= 0:
		return
	xp += a
	Events.xp_gained.emit(a)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		if level >= 2:
			skill_points += 1
			Events.skill_points_changed.emit(skill_points)
		var bonus := 25 * level
		add_coins(bonus)
		Events.level_up.emit(level)
		_set_counter("level", level)
	Events.xp_changed.emit(xp, xp_needed(), level)

func add_skill_points(n: int) -> void:
	skill_points += n
	Events.skill_points_changed.emit(skill_points)

# ================================================================ inventory
func inventory_capacity() -> int:
	return int(stat(&"backpack_slots"))

func stack_limit_for(id: String) -> int:
	var it := ResourceDatabase.item(id)
	if it.has("stack"):
		var s := int(it.stack)
		if id == "ladder":
			s += int(skill_bonus("ladder_stack"))
		return s
	return int(stat(&"stack_limit"))

func _resize_inventory() -> void:
	var cap := inventory_capacity()
	while inventory.size() < cap:
		inventory.append({})
	if inventory.size() > cap:
		# Never delete: compact first, then move overflow stacks into storage.
		_compact_inventory()
		while inventory.size() > cap:
			var last: Dictionary = inventory.pop_back()
			if not last.is_empty():
				storage[last.id] = int(storage.get(last.id, 0)) + int(last.n)
				Events.notify.emit("%d %s moved to Storage (backpack shrank)" % [last.n, ResourceDatabase.item_name(last.id)], "warn")
				Events.storage_changed.emit()
	Events.inventory_changed.emit()

func _compact_inventory() -> void:
	var filled: Array = []
	for s in inventory:
		if not s.is_empty():
			filled.append(s)
	var cap := inventory.size()
	inventory = filled
	while inventory.size() < cap:
		inventory.append({})

func count_item(id: String) -> int:
	var n := 0
	for s in inventory:
		if not s.is_empty() and s.id == id:
			n += int(s.n)
	return n

func used_slots() -> int:
	var n := 0
	for s in inventory:
		if not s.is_empty():
			n += 1
	return n

func is_backpack_full_for(id: String) -> bool:
	var lim := stack_limit_for(id)
	for s in inventory:
		if s.is_empty():
			return false
		if s.id == id and int(s.n) < lim:
			return false
	return true

## Adds items; returns the amount that did NOT fit (caller must keep it, never delete).
func add_item(id: String, n: int, track: bool = true) -> int:
	if n <= 0 or not ResourceDatabase.has_item(id):
		return n
	var lim := stack_limit_for(id)
	var left := n
	for s in inventory:
		if left <= 0:
			break
		if not s.is_empty() and s.id == id and int(s.n) < lim:
			var add := mini(lim - int(s.n), left)
			s.n = int(s.n) + add
			left -= add
	for i in inventory.size():
		if left <= 0:
			break
		if inventory[i].is_empty():
			var add2 := mini(lim, left)
			inventory[i] = {"id": id, "n": add2}
			left -= add2
	var added := n - left
	if added > 0:
		if track:
			record_collected(id, added)
		Events.inventory_changed.emit()
	if left > 0:
		Events.inventory_full.emit(id)
	return left

func remove_item(id: String, n: int) -> int:
	## Removes up to n, returns how many were removed.
	var left := n
	for i in range(inventory.size() - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = inventory[i]
		if not s.is_empty() and s.id == id:
			var take := mini(int(s.n), left)
			s.n = int(s.n) - take
			left -= take
			if int(s.n) <= 0:
				inventory[i] = {}
	if left != n:
		Events.inventory_changed.emit()
	return n - left

func remove_from_slot(slot: int, n: int) -> Dictionary:
	if slot < 0 or slot >= inventory.size() or inventory[slot].is_empty():
		return {}
	var s: Dictionary = inventory[slot]
	var take := mini(n, int(s.n))
	s.n = int(s.n) - take
	var out := {"id": s.id, "n": take}
	if int(s.n) <= 0:
		inventory[slot] = {}
	Events.inventory_changed.emit()
	return out

func sort_inventory(mode: String = "value") -> void:
	var filled: Array = []
	# merge stacks first
	var totals: Dictionary = {}
	for s in inventory:
		if not s.is_empty():
			totals[s.id] = int(totals.get(s.id, 0)) + int(s.n)
	for id in totals:
		var left: int = totals[id]
		var lim := stack_limit_for(id)
		while left > 0:
			var take := mini(lim, left)
			filled.append({"id": id, "n": take})
			left -= take
	match mode:
		"value":
			filled.sort_custom(func(a, b): return ResourceDatabase.item_value(a.id) * a.n > ResourceDatabase.item_value(b.id) * b.n)
		"rarity":
			filled.sort_custom(func(a, b):
				var ra := ResourceDatabase.item_rarity(a.id)
				var rb := ResourceDatabase.item_rarity(b.id)
				return ra > rb if ra != rb else ResourceDatabase.item_name(a.id) < ResourceDatabase.item_name(b.id))
		_:
			filled.sort_custom(func(a, b): return ResourceDatabase.item_name(a.id) < ResourceDatabase.item_name(b.id))
	var cap := inventory_capacity()
	inventory = filled
	while inventory.size() < cap:
		inventory.append({})
	_resize_inventory()

# ================================================================ storage
func storage_used_slots() -> int:
	var n := 0
	for id in storage:
		n += int(ceil(float(storage[id]) / STORAGE_STACK))
	return n

func storage_capacity() -> int:
	return int(stat(&"storage_slots"))

func storage_free_for(id: String, n: int) -> int:
	## How many of `id` can still be deposited.
	var cur := int(storage.get(id, 0))
	var room_in_stack := (STORAGE_STACK - cur % STORAGE_STACK) % STORAGE_STACK if cur > 0 else 0
	var free_slots := storage_capacity() - storage_used_slots()
	return mini(n, room_in_stack + maxi(free_slots, 0) * STORAGE_STACK)

func deposit(id: String, n: int) -> int:
	var can := storage_free_for(id, mini(n, count_item(id)))
	if can <= 0:
		return 0
	remove_item(id, can)
	storage[id] = int(storage.get(id, 0)) + can
	Events.storage_changed.emit()
	return can

func deposit_all(include_consumables: bool = false) -> int:
	var total := 0
	var ids: Dictionary = {}
	for s in inventory:
		if not s.is_empty():
			if not include_consumables and ResourceDatabase.item_category(s.id) == "consumable":
				continue
			ids[s.id] = true
	for id in ids:
		total += deposit(id, count_item(id))
	return total

func withdraw(id: String, n: int) -> int:
	var have := int(storage.get(id, 0))
	var take := mini(n, have)
	if take <= 0:
		return 0
	var left := add_item(id, take, false)
	var moved := take - left
	storage[id] = have - moved
	if int(storage[id]) <= 0:
		storage.erase(id)
	Events.storage_changed.emit()
	return moved

func storage_count(id: String) -> int:
	return int(storage.get(id, 0))

func take_from_storage(id: String, n: int) -> int:
	var have := int(storage.get(id, 0))
	var take := mini(n, have)
	if take > 0:
		storage[id] = have - take
		if int(storage[id]) <= 0:
			storage.erase(id)
		Events.storage_changed.emit()
	return take

func put_in_storage_forced(id: String, n: int) -> void:
	## Used by machines' collect when backpack is full: storage may exceed capacity rather than lose items.
	storage[id] = int(storage.get(id, 0)) + n
	Events.storage_changed.emit()

## Count across backpack + storage (machines may use both).
func count_available(id: String) -> int:
	return count_item(id) + storage_count(id)

func consume_available(id: String, n: int) -> bool:
	if count_available(id) < n:
		return false
	var from_inv := mini(n, count_item(id))
	remove_item(id, from_inv)
	take_from_storage(id, n - from_inv)
	return true

# ================================================================ selling
func sell_value(id: String) -> int:
	var v := ResourceDatabase.item_value(id)
	if ResourceDatabase.item_category(id) == "polished":
		v = int(round(v * (1.0 + skill_bonus("polish_value_pct") / 100.0)))
	return v

func sell_from_inventory(id: String, n: int) -> int:
	var removed := remove_item(id, n)
	var value := removed * sell_value(id)
	if value > 0:
		add_coins(value)
		_add_counter("sell_value", value)
		_add_counter("sold_items", removed)
		Events.sold.emit(value)
	return value

func sell_from_storage(id: String, n: int) -> int:
	var removed := take_from_storage(id, n)
	var value := removed * sell_value(id)
	if value > 0:
		add_coins(value)
		_add_counter("sell_value", value)
		_add_counter("sold_items", removed)
		Events.sold.emit(value)
	return value

# ================================================================ equipment
func owns(id: String) -> bool:
	return owned.get(id, false)

func equipment_level_req(id: String) -> int:
	var e := ResourceDatabase.equip(id)
	var req := int(e.get("level", 1))
	if e.get("slot", "") in ["pickaxe", "drill"]:
		req -= int(stat(&"tool_level_reduction"))
	return maxi(1, req)

func buy_equipment(id: String) -> String:
	## Returns "" on success or a reason string.
	var e := ResourceDatabase.equip(id)
	if e.is_empty():
		return "Unknown item"
	if owns(id):
		return "Already owned"
	if level < equipment_level_req(id):
		return "Requires level %d" % equipment_level_req(id)
	var price := int(e.get("price", 0))
	if not spend_coins(price):
		return "Not enough coins"
	owned[id] = true
	equip_item(id)
	_add_counter("purchases", 1)
	return ""

func equip_item(id: String) -> void:
	var e := ResourceDatabase.equip(id)
	if e.is_empty() or not owns(id):
		return
	equipped[e.slot] = id
	_stat_cache.clear()
	Events.equipment_changed.emit()
	Events.stats_changed.emit()

func best_owned(slot: String) -> String:
	var best := ""
	for id in ResourceDatabase.equipment_by_slot.get(slot, []):
		if owns(id):
			best = id
	return best

# ================================================================ machines
func machine_state(mid: String) -> Dictionary:
	if not machines.has(mid):
		machines[mid] = _new_machine_state(ResourceDatabase.machine(mid))
	return machines[mid]

func machine_unlocked_for_purchase(mid: String) -> String:
	var m := ResourceDatabase.machine(mid)
	if level < int(m.get("level", 1)):
		return "Requires level %d" % int(m.get("level", 1))
	if m.has("requires_skill"):
		var req: Array = m.requires_skill
		if SkillManager.rank(req[0]) < int(req[1]):
			return "Requires skill: %s" % ResourceDatabase.skill(req[0]).get("name", req[0])
	return ""

func buy_machine(mid: String) -> String:
	var st := machine_state(mid)
	if st.owned:
		return "Already built"
	var why := machine_unlocked_for_purchase(mid)
	if why != "":
		return why
	if not spend_coins(int(ResourceDatabase.machine(mid).get("price", 0))):
		return "Not enough coins"
	st.owned = true
	Events.machine_changed.emit(mid)
	_set_counter("machines", owned_machine_count())
	return ""

func owned_machine_count() -> int:
	var n := 0
	for mid in machines:
		if machines[mid].owned:
			n += 1
	return n

func machine_upgrade_cost(mid: String) -> int:
	var st := machine_state(mid)
	var base := int(ResourceDatabase.machine(mid).get("upgrade_cost", 500))
	return int(base * pow(float(ResourceDatabase.machine_upgrade.get("cost_mult", 2.6)), int(st.level) - 1))

func upgrade_machine(mid: String) -> String:
	var st := machine_state(mid)
	if int(st.level) >= int(ResourceDatabase.machine_upgrade.get("max_level", 5)):
		return "Max level"
	if not spend_coins(machine_upgrade_cost(mid)):
		return "Not enough coins"
	st.level = int(st.level) + 1
	Events.machine_changed.emit(mid)
	return ""

# ================================================================ collection / discovery
func record_collected(id: String, n: int) -> void:
	var first := not collection.has(id)
	var rec: Dictionary = collection.get(id, {"count": 0, "best": 0})
	rec.count = int(rec.count) + n
	rec.best = maxi(int(rec.best), current_depth)
	collection[id] = rec
	_add_counter("collect:" + id, n)
	var cat := ResourceDatabase.item_category(id)
	_add_counter("collect_cat:" + cat, n)
	Events.item_collected.emit(id, n)
	if first and ResourceDatabase.item(id).get("collectible", false):
		var r := ResourceDatabase.item_rarity(id)
		add_xp(10 + 20 * r)
		Events.item_discovered.emit(id)
		if r >= 4:
			_set_counter("legendary", 1)
		Events.collection_changed.emit()
		_check_collection_milestones()

func collection_progress() -> float:
	var found := 0
	for id in ResourceDatabase.collectibles:
		if collection.has(id):
			found += 1
	return float(found) / maxf(1.0, ResourceDatabase.collectibles.size())

func _check_collection_milestones() -> void:
	var pct := int(floor(collection_progress() * 100.0))
	_set_counter("collection", pct)
	for m in [25, 50, 75, 100]:
		var key := str(m)
		if pct >= m and not collection_rewards.get(key, false):
			collection_rewards[key] = true
			match m:
				25:
					add_coins(2000)
					Events.notify.emit("Collection 25%! Reward: $2,000", "rare")
				50:
					owned["lantern_skin_aurora"] = true
					cosmetics["lantern_skin_aurora"] = true
					Events.notify.emit("Collection 50%! Reward: Aurora Lantern Glow", "epic")
				75:
					owned["pickaxe_charm"] = true
					cosmetics["pickaxe_charm"] = true
					Events.notify.emit("Collection 75%! Reward: Gem Charm for your pickaxe", "epic")
				100:
					owned["helmet_crown"] = true
					owned["golden_pickaxe_skin"] = true
					cosmetics["helmet_crown"] = true
					cosmetics["golden_pickaxe_skin"] = true
					add_coins(50000)
					Events.notify.emit("COLLECTION COMPLETE! Prospector's Crown + Golden Finish + $50,000", "legendary")
			_stat_cache.clear()
			Events.equipment_changed.emit()

# ================================================================ counters
func counter(key: String) -> int:
	return int(counters.get(key, 0))

func _add_counter(key: String, n: int) -> void:
	counters[key] = int(counters.get(key, 0)) + n

func add_counter(key: String, n: int = 1) -> void:
	_add_counter(key, n)

func _set_counter(key: String, v: int) -> void:
	counters[key] = maxi(int(counters.get(key, 0)), v)

func set_counter_max(key: String, v: int) -> void:
	_set_counter(key, v)

# ================================================================ world helpers
func set_depth(depth_m: int) -> void:
	current_depth = depth_m
	if depth_m > max_depth:
		max_depth = depth_m
		_set_counter("depth", depth_m)
	var b := ResourceDatabase.biome_for_depth(depth_m) if depth_m >= 0 else -1
	if b != current_biome:
		current_biome = b
		if b >= 0 and not biomes_found[b]:
			biomes_found[b] = true
			_set_counter("biome", b)
			add_xp(150 * (b + 1) * (b + 1))
			Events.notify.emit("New biome discovered: %s!" % ResourceDatabase.biome(b).name, "epic")
		Events.biome_entered.emit(b)
	# Unlock elevator stations by depth reached.
	for i in ResourceDatabase.stations.size():
		if not stations[i] and max_depth >= int(ResourceDatabase.stations[i].depth):
			stations[i] = true
			Events.station_unlocked.emit(i)
			Events.notify.emit("Elevator checkpoint unlocked: %s (%dm)" % [ResourceDatabase.stations[i].name, ResourceDatabase.stations[i].depth], "good")
	Events.depth_changed.emit(depth_m, b)

func unlock_station(i: int) -> void:
	if i >= 0 and i < stations.size() and not stations[i]:
		stations[i] = true
		Events.station_unlocked.emit(i)

func deepest_biome() -> int:
	var d := 0
	for i in biomes_found.size():
		if biomes_found[i]:
			d = i
	return d

# ================================================================ health
func damage(amount: float, kind: String = "") -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	if kind in ["lava", "heat"]:
		amount *= 1.0 - stat(&"hazard_resist")
	hp = maxf(0.0, hp - amount)
	Events.player_hurt.emit(amount)
	Events.player_health_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		Events.player_died.emit()

func heal(amount: float) -> void:
	hp = minf(MAX_HP, hp + amount)
	Events.player_health_changed.emit(hp, MAX_HP)

# ================================================================ serialization
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"seed": world_seed, "coins": coins, "total_earned": total_earned, "level": level, "xp": xp,
		"skill_points": skill_points, "skills": skills, "inventory": inventory, "storage": storage,
		"owned": owned, "equipped": equipped, "machines": machines, "collection": collection,
		"achievements": achievements, "counters": counters, "stations": stations,
		"biomes_found": biomes_found, "chambers": chambers, "opened": opened,
		"quest_state": quest_state, "tutorial": tutorial, "event_state": event_state,
		"hotbar_index": hotbar_index, "hp": hp, "player_pos": [player_pos.x, player_pos.y],
		"max_depth": max_depth, "day_time": day_time, "day_count": day_count, "play_time": play_time,
		"cosmetics": cosmetics, "collection_rewards": collection_rewards, "ground_items": ground_items,
	}

func from_dict(d: Dictionary) -> void:
	new_game(int(d.get("seed", 0)))
	coins = int(d.get("coins", 0))
	total_earned = int(d.get("total_earned", 0))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	skill_points = int(d.get("skill_points", 0))
	skills = _int_values(d.get("skills", {"miners_core": 1}))
	skills["miners_core"] = 1
	storage = _int_values(d.get("storage", {}))
	owned = d.get("owned", owned)
	equipped = d.get("equipped", equipped)
	for slot in ["pickaxe", "backpack", "lantern", "boots"]:
		if not ResourceDatabase.equipment.has(equipped.get(slot, "")):
			equipped[slot] = ResourceDatabase.equipment_by_slot[slot][0]
	var md: Dictionary = d.get("machines", {})
	for mid in machines:
		if md.has(mid):
			var st: Dictionary = md[mid]
			machines[mid].merge(st, true)
	collection = d.get("collection", {})
	achievements = d.get("achievements", {})
	counters = d.get("counters", {})
	var st_arr: Array = d.get("stations", [])
	for i in mini(st_arr.size(), stations.size()):
		stations[i] = bool(st_arr[i])
	var bf: Array = d.get("biomes_found", [])
	for i in mini(bf.size(), biomes_found.size()):
		biomes_found[i] = bool(bf[i])
	chambers = d.get("chambers", {})
	opened = d.get("opened", {})
	quest_state = default_quest_state()
	quest_state.merge(d.get("quest_state", {}), true)
	tutorial = d.get("tutorial", tutorial)
	event_state = d.get("event_state", {})
	hotbar_index = int(d.get("hotbar_index", 0))
	hp = float(d.get("hp", MAX_HP))
	var pp: Array = d.get("player_pos", [0, 0])
	player_pos = Vector2(float(pp[0]), float(pp[1]))
	max_depth = int(d.get("max_depth", 0))
	day_time = float(d.get("day_time", 0.3))
	day_count = int(d.get("day_count", 1))
	play_time = float(d.get("play_time", 0.0))
	cosmetics = d.get("cosmetics", {})
	collection_rewards = d.get("collection_rewards", {})
	ground_items = d.get("ground_items", [])
	_stat_cache.clear()
	inventory = []
	var inv: Array = d.get("inventory", [])
	for s in inv:
		if typeof(s) == TYPE_DICTIONARY and s.has("id") and ResourceDatabase.has_item(s.id):
			inventory.append({"id": s.id, "n": int(s.n)})
		else:
			inventory.append({})
	_resize_inventory()
	Events.coins_changed.emit(coins, 0)
	Events.xp_changed.emit(xp, xp_needed(), level)
	Events.skill_points_changed.emit(skill_points)

func _int_values(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[k] = int(src[k])
	return out

# ================================================================ shop consumables / geodes
const Loot = preload("res://scripts/progression/loot.gd")

## Buy n of a consumable item (items with a "price" field). Returns "" or a reason.
func buy_item(id: String, n: int = 1) -> String:
	var it := ResourceDatabase.item(id)
	if not it.has("price"):
		return "Not for sale"
	var cost := int(it.price) * n
	if coins < cost:
		return "Not enough coins"
	# Check space first so nothing is ever lost.
	var test_left := _space_for(id)
	if test_left < n:
		return "Backpack full"
	spend_coins(cost)
	add_item(id, n, false)
	return ""

func _space_for(id: String) -> int:
	var lim := stack_limit_for(id)
	var room := 0
	for s in inventory:
		if s.is_empty():
			room += lim
		elif s.id == id:
			room += maxi(0, lim - int(s.n))
	return room

func space_for(id: String) -> int:
	return _space_for(id)

## Open one geode from the backpack (or storage). Must be at the surface.
## Returns {"items": [[id, n]...], "coins": int} or {} if not possible.
func open_geode(geode_id: String) -> Dictionary:
	if not at_surface:
		return {}
	var table: Dictionary = ResourceDatabase.loot.get("geodes", {}).get(geode_id, {})
	if table.is_empty():
		return {}
	if count_item(geode_id) > 0:
		remove_item(geode_id, 1)
	elif storage_count(geode_id) > 0:
		take_from_storage(geode_id, 1)
	else:
		return {}
	var luck := skill_bonus("geode_reward_pct") / 100.0
	var res := Loot.roll(table, max_depth, luck)
	for pair in res.items:
		var left := add_item(pair[0], int(pair[1]))
		if left > 0:
			put_in_storage_forced(pair[0], left)
			record_collected(pair[0], left)
	if int(res.coins) > 0:
		add_coins(int(res.coins))
	add_counter("open_geodes", 1)
	add_xp(15 + 25 * ResourceDatabase.item_rarity(geode_id))
	Events.geode_opened.emit(geode_id, res.items, int(res.coins))
	return res

static func default_quest_state() -> Dictionary:
	return {"main_index": 0, "main_progress": 0, "challenges": [], "done": {}, "tutorial_progress": 0,
		"hud": {"title": "", "text": "", "progress": ""}}
