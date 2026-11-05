extends Node
## Autoload "SkillManager": skill tree rules (prerequisites, costs, ranks, reset) and the
## per-stat bonus totals that GameState.stat() combines with equipment and events.
## Skill definitions live in data/skills/skills.json; ranks are stored in GameState.skills.

enum State { HIDDEN, LOCKED, AVAILABLE, AFFORDABLE, UNLOCKED, MAXED }

const RESET_REFUND := 0.9

var _bonus_cache: Dictionary = {}

func _ready() -> void:
	Events.skill_ranked.connect(func(_a, _b): _bonus_cache.clear())
	Events.skills_reset.connect(func(_a): _bonus_cache.clear())

func invalidate() -> void:
	_bonus_cache.clear()

func rank(id: String) -> int:
	return int(GameState.skills.get(id, 0))

func max_rank(id: String) -> int:
	return int(ResourceDatabase.skill(id).get("max_rank", 1))

func cost_for_next(id: String) -> int:
	var s := ResourceDatabase.skill(id)
	var r := rank(id)
	var costs: Array = s.get("costs", [1])
	if r >= costs.size():
		return int(costs[costs.size() - 1]) if costs.size() > 0 else 1
	return int(costs[r])

func is_branch_revealed(branch_id: String) -> bool:
	var br := ResourceDatabase.branch(branch_id)
	if br.is_empty():
		return false
	if branch_id == "core" or branch_id == "mining":
		return true
	if GameState.level >= int(br.get("reveal_level", 1)):
		return true
	# A branch is also revealed if any of its skills already has ranks (e.g. old save).
	for sid in ResourceDatabase.skill_order:
		if ResourceDatabase.skill(sid).branch == branch_id and rank(sid) > 0:
			return true
	return false

func requirements_met(id: String) -> bool:
	var s := ResourceDatabase.skill(id)
	var reqs: Array = s.get("requires", [])
	if reqs.is_empty():
		return true
	var any: bool = s.get("req_any", false)
	var met_count := 0
	for req in reqs:
		if rank(req[0]) >= int(req[1]):
			met_count += 1
	return met_count > 0 if any else met_count == reqs.size()

func level_met(id: String) -> bool:
	return GameState.level >= int(ResourceDatabase.skill(id).get("level", 1))

func state(id: String) -> int:
	var s := ResourceDatabase.skill(id)
	if not is_branch_revealed(s.get("branch", "")):
		return State.HIDDEN
	var r := rank(id)
	if r >= max_rank(id):
		return State.MAXED
	if r > 0:
		return State.UNLOCKED
	if not requirements_met(id) or not level_met(id):
		return State.LOCKED
	if GameState.skill_points >= cost_for_next(id):
		return State.AFFORDABLE
	return State.AVAILABLE

## Returns "" if the next rank can be bought, otherwise the reason.
func can_rank_up(id: String) -> String:
	var s := ResourceDatabase.skill(id)
	if s.is_empty():
		return "Unknown skill"
	if not is_branch_revealed(s.branch):
		return "Branch unlocks at level %d" % int(ResourceDatabase.branch(s.branch).get("reveal_level", 1))
	if rank(id) >= max_rank(id):
		return "Maxed out"
	if not requirements_met(id):
		return "Requires: " + requirement_text(id)
	if not level_met(id):
		return "Requires level %d" % int(s.get("level", 1))
	if GameState.skill_points < cost_for_next(id):
		return "Not enough skill points"
	return ""

func rank_up(id: String) -> bool:
	if can_rank_up(id) != "":
		return false
	var cost := cost_for_next(id)
	GameState.skill_points -= cost
	GameState.skills[id] = rank(id) + 1
	_bonus_cache.clear()
	GameState.add_counter("skills_spent", cost)
	GameState.set_counter_max("skills", total_spent())
	if ResourceDatabase.skill(id).get("capstone", false):
		GameState.set_counter_max("capstone", 1)
	Events.skill_points_changed.emit(GameState.skill_points)
	Events.skill_ranked.emit(id, rank(id))
	Events.stats_changed.emit()
	return true

func total_spent() -> int:
	var total := 0
	for id in GameState.skills:
		var s := ResourceDatabase.skill(id)
		var costs: Array = s.get("costs", [])
		for i in mini(int(GameState.skills[id]), costs.size()):
			total += int(costs[i])
	return total

func refund_amount() -> int:
	return int(round(total_spent() * RESET_REFUND))

func ranked_skills() -> Array[String]:
	var out: Array[String] = []
	for id in ResourceDatabase.skill_order:
		if id != "miners_core" and rank(id) > 0:
			out.append(id)
	return out

## Resets every skill except the core. Refunds 90% of spent points (rounded down).
## Player level, XP, equipment, coins, collection and discoveries are NOT touched.
func reset_all() -> int:
	var refund := refund_amount()
	GameState.skills = {"miners_core": 1}
	GameState.skill_points += refund
	_bonus_cache.clear()
	Events.skill_points_changed.emit(GameState.skill_points)
	Events.skills_reset.emit(refund)
	Events.stats_changed.emit()
	return refund

# ---------------------------------------------------------------- effects
func effect_value(effect: Dictionary, r: int) -> float:
	if r <= 0:
		return 0.0
	if effect.has("values"):
		var vals: Array = effect.values
		return float(vals[mini(r, vals.size()) - 1])
	return float(effect.get("per_rank", 0.0)) * r

## Sum of one stat across every ranked skill (cached).
func bonus(stat_name: String) -> float:
	if _bonus_cache.is_empty():
		_rebuild_cache()
	return float(_bonus_cache.get(stat_name, 0.0))

func _rebuild_cache() -> void:
	_bonus_cache["__built"] = 1.0
	for id in GameState.skills:
		var r := int(GameState.skills[id])
		var s := ResourceDatabase.skill(id)
		for e in s.get("effects", []):
			_bonus_cache[e.stat] = float(_bonus_cache.get(e.stat, 0.0)) + effect_value(e, r)

func effect_text(id: String, r: int) -> String:
	var s := ResourceDatabase.skill(id)
	if r <= 0:
		return "Not learned yet"
	var fmt: String = s.get("fmt", "")
	var vals: Array = []
	for e in s.get("effects", []):
		var v := effect_value(e, r)
		vals.append(_num(v))
	for i in vals.size():
		fmt = fmt.replace("{%d}" % i, vals[i])
	return fmt

func _num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return ("%.1f" % v)

func requirement_text(id: String) -> String:
	var s := ResourceDatabase.skill(id)
	var parts: Array[String] = []
	for req in s.get("requires", []):
		var rs := ResourceDatabase.skill(req[0])
		parts.append("%s Rank %d" % [rs.get("name", req[0]), int(req[1])])
	var joiner := " or " if s.get("req_any", false) else ", "
	return joiner.join(parts)

func branch_progress(branch_id: String) -> Vector2i:
	var have := 0
	var total := 0
	for id in ResourceDatabase.skill_order:
		var s := ResourceDatabase.skill(id)
		if s.branch == branch_id:
			have += rank(id)
			total += max_rank(id)
	return Vector2i(have, total)
