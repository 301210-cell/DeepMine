extends Node
## Checks achievements against GameState counters and unlocks them with rewards.

var _t := 0.0

static func progress(a: Dictionary) -> int:
	match String(a.type):
		"mine_any": return GameState.counter("mine_any")
		"mine_ore": return GameState.counter("mine_ore")
		"biome": return GameState.deepest_biome()
		"open_geodes": return GameState.counter("open_geodes")
		"earned": return GameState.total_earned
		"skills": return SkillManager.total_spent()
		"capstone": return GameState.counter("capstone")
		"level": return GameState.level
		"find_cache": return GameState.counter("find_cache")
		"collect":
			var t := String(a.get("target", ""))
			if t.begins_with("@"):
				return GameState.counter("collect_cat:" + t.substr(1))
			return GameState.counter("collect:" + t)
		"legendary": return GameState.counter("legendary")
		"collection": return int(floor(GameState.collection_progress() * 100.0))
		"event_complete": return GameState.counter("event_complete")
		"machines": return GameState.owned_machine_count()
		"cart_ride": return GameState.counter("cart_ride")
		"tutorial": return 1 if GameState.tutorial.get("done", false) else 0
	return 0

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.5
	for a in ResourceDatabase.achievements:
		if GameState.achievements.get(a.id, false):
			continue
		if progress(a) >= int(a.count):
			GameState.achievements[a.id] = true
			var c := int(a.get("reward_coins", 0))
			if c > 0:
				GameState.add_coins(c)
			var sp := int(a.get("reward_sp", 0))
			if sp > 0:
				GameState.add_skill_points(sp)
			Events.achievement_unlocked.emit(a.id)
			Events.notify.emit("Achievement: %s%s" % [a.name, ("  +$" + ResourceDatabase.fmt_num(c)) if c > 0 else ""], "legendary")
			AudioManager.play("rare_discovery", -4.0)
