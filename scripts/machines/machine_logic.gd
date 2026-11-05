extends RefCounted
## Pure machine processing logic operating on GameState.machine_state(mid).
## Used by the physical machine nodes in the camp (tick) and by the Machine UI panel.
##   const MachineLogic = preload("res://scripts/machines/machine_logic.gd")
##
## Processor state: queue = [{"r": recipe_index, "n": remaining_count}], progress = seconds into current item,
##                  output = {item_id: count} waiting to be collected.
## Drill/auto state: timer, output, biome.

const Loot = preload("res://scripts/progression/loot.gd")
const QUEUE_LIMIT_BASE := 20

static func kind(mid: String) -> String:
	return ResourceDatabase.machine(mid).get("kind", "processor")

static func recipes(mid: String) -> Array:
	return ResourceDatabase.machine(mid).get("recipes", [])

static func queue_limit(mid: String) -> int:
	return QUEUE_LIMIT_BASE + (int(GameState.machine_state(mid).level) - 1) * 10

static func queued_total(mid: String) -> int:
	var t := 0
	for q in GameState.machine_state(mid).queue:
		t += int(q.n)
	return t

static func output_total(mid: String) -> int:
	var t := 0
	var out: Dictionary = GameState.machine_state(mid).output
	for id in out:
		t += int(out[id])
	return t

static func capacity(mid: String) -> int:
	return int(ResourceDatabase.machine(mid).get("capacity", 999)) + (int(GameState.machine_state(mid).level) - 1) * 20

## Seconds for one item of a recipe, after skill/level speed bonuses.
static func recipe_time(mid: String, r: int) -> float:
	var rec: Dictionary = recipes(mid)[r]
	return float(rec.time) / GameState.machine_speed_mult(mid)

## How many times the recipe could be queued with what the player has (backpack + storage).
static func max_batches(mid: String, r: int) -> int:
	var rec: Dictionary = recipes(mid)[r]
	var have := GameState.count_available(rec["in"])
	return int(have / int(rec.in_n))

## Queue `count` batches. Consumes inputs immediately (backpack first, then storage).
## Returns "" on success or a reason.
static func queue_recipe(mid: String, r: int, count: int) -> String:
	var st := GameState.machine_state(mid)
	if not st.owned:
		return "Machine not built"
	if r < 0 or r >= recipes(mid).size():
		return "Invalid recipe"
	var room := queue_limit(mid) - queued_total(mid)
	if room <= 0:
		return "Queue is full"
	count = mini(count, room)
	count = mini(count, max_batches(mid, r))
	if count <= 0:
		return "Not enough materials"
	var rec: Dictionary = recipes(mid)[r]
	if not GameState.consume_available(rec["in"], int(rec.in_n) * count):
		return "Not enough materials"
	var q: Array = st.queue
	if not q.is_empty() and int(q[q.size() - 1].r) == r:
		q[q.size() - 1].n = int(q[q.size() - 1].n) + count
	else:
		q.append({"r": r, "n": count})
	Events.machine_changed.emit(mid)
	if mid in ["crusher", "ore_sorter"]:
		GameState.add_counter("crush", int(rec.in_n) * count)
	return ""

## Cancel the whole queue and return unprocessed inputs to the backpack (overflow -> storage).
static func cancel_queue(mid: String) -> void:
	var st := GameState.machine_state(mid)
	for q in st.queue:
		var rec: Dictionary = recipes(mid)[int(q.r)]
		var n := int(rec.in_n) * int(q.n)
		var left := GameState.add_item(rec["in"], n, false)
		if left > 0:
			GameState.put_in_storage_forced(rec["in"], left)
	st.queue = []
	st.progress = 0.0
	Events.machine_changed.emit(mid)

static func current_progress(mid: String) -> float:
	var st := GameState.machine_state(mid)
	match kind(mid):
		"processor":
			if st.queue.is_empty():
				return 0.0
			return clampf(float(st.progress) / recipe_time(mid, int(st.queue[0].r)), 0.0, 1.0)
		_:
			return clampf(float(st.timer) / interval(mid), 0.0, 1.0)

static func is_working(mid: String) -> bool:
	var st := GameState.machine_state(mid)
	if not st.owned:
		return false
	match kind(mid):
		"processor":
			return not st.queue.is_empty()
		"auto":
			if output_total(mid) >= capacity(mid):
				return false
			for id in ResourceDatabase.machine(mid).get("inputs", []):
				if GameState.storage_count(id) > 0:
					return true
			return false
		_:
			return output_total(mid) < capacity(mid)

static func interval(mid: String) -> float:
	return float(ResourceDatabase.machine(mid).get("interval", 10.0)) / GameState.machine_speed_mult(mid)

## Advance the machine by delta seconds. Returns true if output changed.
static func tick(mid: String, delta: float) -> bool:
	var st := GameState.machine_state(mid)
	if not st.owned:
		return false
	match kind(mid):
		"processor":
			return _tick_processor(mid, st, delta)
		"drill":
			return _tick_drill(mid, st, delta)
		"auto":
			return _tick_auto(mid, st, delta)
	return false

static func _tick_processor(mid: String, st: Dictionary, delta: float) -> bool:
	if st.queue.is_empty():
		return false
	st.progress = float(st.progress) + delta
	var changed := false
	var guard := 0
	while not st.queue.is_empty() and guard < 50:
		guard += 1
		var q: Dictionary = st.queue[0]
		var t := recipe_time(mid, int(q.r))
		if float(st.progress) < t:
			break
		st.progress = float(st.progress) - t
		var rec: Dictionary = recipes(mid)[int(q.r)]
		var n := int(rec.out_n)
		var bonus_stat: String = ResourceDatabase.machine(mid).get("bonus_stat", "")
		if bonus_stat != "" and randf() * 100.0 < GameState.skill_bonus(bonus_stat):
			n += 1
		_add_output(st, rec.out, n)
		var chance_mult := 1.0 + GameState.skill_bonus(ResourceDatabase.machine(mid).get("chance_stat", "")) / 100.0 if ResourceDatabase.machine(mid).has("chance_stat") else 1.0
		for ex in rec.get("extra", []):
			if randf() < float(ex[1]) * chance_mult:
				_add_output(st, ex[0], 1)
		Events.machine_output.emit(mid, rec.out, n)
		q.n = int(q.n) - 1
		if int(q.n) <= 0:
			st.queue.pop_front()
		changed = true
	if st.queue.is_empty():
		st.progress = 0.0
	if changed:
		Events.machine_changed.emit(mid)
	return changed

static func _tick_drill(mid: String, st: Dictionary, delta: float) -> bool:
	if output_total(mid) >= capacity(mid):
		return false
	st.timer = float(st.timer) + delta
	var iv := interval(mid)
	if float(st.timer) < iv:
		return false
	st.timer = float(st.timer) - iv
	var tables: Dictionary = ResourceDatabase.machine(mid).get("tables", {})
	var key := str(int(st.biome))
	if not tables.has(key):
		key = tables.keys()[0]
	var id := Loot.weighted_item(tables[key])
	var mult := GameState.machine_output_mult(mid)
	var n := int(floor(mult))
	if randf() < mult - floor(mult):
		n += 1
	_add_output(st, id, maxi(n, 1))
	Events.machine_output.emit(mid, id, n)
	Events.machine_changed.emit(mid)
	return true

static func _tick_auto(mid: String, st: Dictionary, delta: float) -> bool:
	if not is_working(mid):
		return false
	st.timer = float(st.timer) + delta
	var iv := interval(mid)
	if float(st.timer) < iv:
		return false
	st.timer = float(st.timer) - iv
	var m := ResourceDatabase.machine(mid)
	var batch := int(m.get("batch", 4))
	var crusher_recipes := recipes("crusher")
	for id in m.get("inputs", []):
		var have := GameState.storage_count(id)
		if have <= 0:
			continue
		var take := GameState.take_from_storage(id, mini(batch, have))
		# Same yields as the crusher, scaled per rock.
		var rec: Dictionary = {}
		for cr in crusher_recipes:
			if cr["in"] == id:
				rec = cr
		if rec.is_empty():
			_add_output(st, "gravel", take)
		else:
			var gravel := int(round(float(rec.out_n) / float(rec.in_n) * take * GameState.machine_output_mult(mid)))
			_add_output(st, rec.out, maxi(gravel, 1))
			for ex in rec.get("extra", []):
				for i in take:
					if randf() < float(ex[1]):
						_add_output(st, ex[0], 1)
		GameState.add_counter("crush", take)
		Events.machine_changed.emit(mid)
		return true
	return false

static func _add_output(st: Dictionary, id: String, n: int) -> void:
	st.output[id] = int(st.output.get(id, 0)) + n

## Move all output into the backpack; anything that doesn't fit goes to storage (never lost).
## Returns number of items collected.
static func collect(mid: String) -> int:
	var st := GameState.machine_state(mid)
	var total := 0
	for id in st.output.keys():
		var n := int(st.output[id])
		var left := GameState.add_item(id, n)
		if left > 0:
			GameState.put_in_storage_forced(id, left)
			GameState.record_collected(id, left)
		total += n
	st.output = {}
	Events.machine_changed.emit(mid)
	return total

static func set_biome(mid: String, b: int) -> void:
	GameState.machine_state(mid).biome = b
	Events.machine_changed.emit(mid)
