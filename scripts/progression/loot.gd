extends RefCounted
## Loot table rolling (geodes, fossils, artifacts, caches, carts). Use via:
##   const Loot = preload("res://scripts/progression/loot.gd")
##   var result := Loot.roll(table_dict, depth_m, luck)  -> {"items": [[id, n], ...], "coins": int}

static func roll(table: Dictionary, depth_m: int = 0, luck: float = 0.0) -> Dictionary:
	var out_items: Dictionary = {}
	var rolls: Array = table.get("rolls", [1, 1])
	var count := randi_range(int(rolls[0]), int(rolls[1]))
	var entries: Array = []
	for e in table.get("entries", []):
		if e.size() >= 5 and depth_m < int(e[4]):
			continue
		entries.append(e)
	if entries.is_empty():
		return {"items": [], "coins": 0}
	for i in count:
		var e: Array = _pick(entries, luck)
		var n := randi_range(int(e[2]), int(e[3]))
		out_items[e[0]] = int(out_items.get(e[0], 0)) + n
	var coins_range: Array = table.get("coins", [0, 0])
	var coins := randi_range(int(coins_range[0]), int(coins_range[1]))
	coins = int(coins * (1.0 + luck))
	var list: Array = []
	for id in out_items:
		list.append([id, out_items[id]])
	return {"items": list, "coins": coins}

## Weighted pick. luck > 0 flattens weights so rarer entries come up more often.
static func _pick(entries: Array, luck: float) -> Array:
	var total := 0.0
	var weights: Array[float] = []
	for e in entries:
		var w := float(e[1])
		if luck > 0.0:
			w = pow(w, 1.0 / (1.0 + luck))
		weights.append(w)
		total += w
	var r := randf() * total
	for i in entries.size():
		r -= weights[i]
		if r <= 0.0:
			return entries[i]
	return entries[entries.size() - 1]

static func weighted_item(pairs: Array) -> String:
	## pairs: [[id, weight], ...]
	var total := 0.0
	for p in pairs:
		total += float(p[1])
	var r := randf() * total
	for p in pairs:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return pairs[pairs.size() - 1][0]
