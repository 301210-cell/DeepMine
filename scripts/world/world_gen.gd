extends RefCounted
## Procedural world generator. Deterministic for a given seed.
## Runs on a worker thread from the loading screen; `progress` (0..1) can be polled.
##   var gen = load("res://scripts/world/world_gen.gd").new()
##   var wd = gen.generate(seed)

const WD = preload("res://scripts/world/world_data.gd")

const AIR := 0
const DIRT := 1
const GRASS := 2
const STONE := 3
const HARD_STONE := 4
const ICE := 10
const MAGMA_CRUST := 14
const ANCIENT_METAL := 17
const BEDROCK := 18
const SHAFT := 19
const WOOD := 25
const SEALED_ANCIENT := 26
const CRACKED := 75
const LADDER := 90
const RAIL := 91
const LAVA := 92
const WATER := 93
const TORCH := 94

const W := WD.W
const H := WD.H

var progress: float = 0.0
var status: String = ""
var wd
var rng := RandomNumberGenerator.new()
var n_cave := FastNoiseLite.new()
var n_tunnel := FastNoiseLite.new()
var n_hard := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var biomes: Array = []
var row_biome := PackedInt32Array()

func generate(seed: int):
	wd = WD.new()
	wd.world_seed = seed
	rng.seed = seed
	biomes = ResourceDatabase.biomes
	row_biome.resize(H)
	for y in H:
		row_biome[y] = ResourceDatabase.biome_index_for_row(y)
	_setup_noise(seed)
	status = "Shaping the mountain"
	_fill_and_caves()            # 0.00 - 0.45
	status = "Flooding caverns"
	_pools_and_surfaces()        # 0.45 - 0.55
	status = "Sealing the depths"
	_seals()
	status = "Growing ore veins"
	_ores()                      # 0.55 - 0.70
	status = "Building the mine"
	_shaft_and_stations()
	_entrance_and_tutorial()
	_descent_path()
	_rail_tunnels()
	status = "Hiding treasure"
	_hidden_caches()
	_chambers()
	_loot_carts()
	progress = 0.8
	status = "Decorating caves"
	_decorate()                  # 0.80 - 0.97
	_bedrock()
	progress = 1.0
	status = "Done"
	return wd

# ================================================================ helpers
func _setup_noise(seed: int) -> void:
	n_cave.seed = seed
	n_cave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_cave.frequency = 0.034
	n_cave.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_cave.fractal_octaves = 3
	n_tunnel.seed = seed + 11
	n_tunnel.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_tunnel.frequency = 0.018
	n_tunnel.fractal_type = FastNoiseLite.FRACTAL_NONE
	n_hard.seed = seed + 23
	n_hard.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_hard.frequency = 0.07
	n_detail.seed = seed + 37
	n_detail.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	n_detail.frequency = 0.15

func _g(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return BEDROCK
	return wd.blocks[y * W + x]

func _s(x: int, y: int, id: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	wd.blocks[y * W + x] = id

func _solid(x: int, y: int) -> bool:
	return ResourceDatabase.is_solid(_g(x, y))

func _is_rock(id: int) -> bool:
	## Natural rock that ores / structures may replace.
	return (id >= 1 and id <= 16) and id != ICE

func _biome(y: int) -> Dictionary:
	return biomes[row_biome[clampi(y, 0, H - 1)]]

func _in_shaft_zone(x: int, margin: int = 1) -> bool:
	return x >= WD.SHAFT_X0 - margin and x <= WD.SHAFT_X1 + margin

func _carve_rect(x0: int, y0: int, w: int, h: int, id: int = AIR) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if x > 0 and x < W - 1 and not _in_shaft_zone(x, 0):
				_s(x, y, id)

func _carve_ellipse(cx: int, cy: int, rx: int, ry: int, id: int = AIR) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / rx
			var ny := float(y - cy) / ry
			var wob := n_detail.get_noise_2d(x * 3.0, y * 3.0) * 0.18
			if nx * nx + ny * ny <= 1.0 + wob and x > 1 and x < W - 2 and not _in_shaft_zone(x, 0):
				_s(x, y, id)

# ================================================================ terrain + caves
func _fill_and_caves() -> void:
	for y in H:
		var b: Dictionary = _biome(y)
		var bi: int = row_biome[y]
		var base: int = int(b.base)
		var hard: int = int(b.hard)
		var extra: int = int(b.get("extra", 0))
		var density: float = float(b.get("cave_density", 0.4))
		var thr := 0.5 - density * 0.8
		var fs := 1.0
		if bi == 2:
			fs = 0.72 # bigger crystal chambers
		elif bi == 5:
			fs = 0.85
		var row := y * W
		for x in W:
			var id := base
			if y == 0:
				id = GRASS
			elif y <= 9:
				# smooth dirt -> stone transition using noise patches
				var dn := n_detail.get_noise_2d(x * 0.55, y * 0.9) * 0.5 + 0.5
				id = STONE if dn < (y - 2) * 0.13 else DIRT
			else:
				var hn := n_hard.get_noise_2d(x, y)
				if hn > 0.32:
					id = hard
				elif extra != 0 and hn < (-0.56 if extra == MAGMA_CRUST else -0.45) and extra != ANCIENT_METAL:
					id = extra
				if extra == ANCIENT_METAL and n_detail.get_noise_2d(x * 0.6, y * 0.6) > 0.55:
					id = ANCIENT_METAL
			# caves
			if y >= 10:
				var under_camp := x <= WD.CAMP_MAX_X + 3 and y < 18
				if not under_camp:
					var c := n_cave.get_noise_2d(x * fs, y * fs * 1.25)
					var t := absf(n_tunnel.get_noise_2d(x, y * 1.6))
					var fade := clampf((y - 10) / 12.0, 0.0, 1.0)
					if c > thr + (1.0 - fade) * 0.3 or t < 0.028 * fade:
						id = AIR
			wd.blocks[row + x] = id
		if y % 16 == 0:
			progress = 0.45 * float(y) / H

func _pools_and_surfaces() -> void:
	# Liquids in basins, ice floors (frozen), magma crust (magma).
	for y in range(H - 10, 12, -1):
		var b: Dictionary = _biome(y)
		var bi: int = row_biome[y]
		var water_c: float = float(b.get("water", 0.0))
		var lava_c: float = float(b.get("lava", 0.0))
		var liquid := WATER if water_c >= lava_c else LAVA
		var chance := maxf(water_c, lava_c)
		if chance > 0.0:
			var x := 1
			while x < W - 1:
				if _g(x, y) == AIR and _solid(x - 1, y):
					var x1 := x
					var ok := true
					while x1 < W - 1 and _g(x1, y) == AIR:
						var below := _g(x1, y + 1)
						if not (ResourceDatabase.is_solid(below) or below == liquid):
							ok = false
							break
						x1 += 1
					var length := x1 - x
					if ok and _solid(x1, y) and length >= 3 and length <= 16:
						if n_detail.get_noise_2d(x * 0.5, y * 0.5) * 0.5 + 0.5 < chance * 0.6:
							for xx in range(x, x1):
								_s(xx, y, liquid)
					x = x1 + 1
				else:
					x += 1
		if y % 64 == 0:
			progress = 0.45 + 0.05 * float(H - y) / H
	for y in range(12, H - 10):
		var bi: int = row_biome[y]
		if bi != 3 and bi != 4:
			continue
		for x in range(1, W - 1):
			var id := _g(x, y)
			if not ResourceDatabase.is_solid(id) or not _is_rock(id):
				continue
			if _g(x, y - 1) != AIR:
				continue
			if bi == 3 and rng.randf() < 0.55:
				_s(x, y, ICE)
			elif bi == 4 and rng.randf() < 0.22:
				_s(x, y, MAGMA_CRUST)
	progress = 0.55

func _seals() -> void:
	for b in biomes:
		var seal := int(b.get("seal", 0))
		if seal == 0 or seal == BEDROCK:
			continue
		var bottom: int = int(b.rows[1])
		for y in range(bottom - 2, bottom + 1):
			for x in range(1, W - 1):
				_s(x, y, seal)

# ================================================================ ores
func _ores() -> void:
	var bi := 0
	for b in biomes:
		var r0: int = maxi(int(b.rows[0]), 10)
		var r1: int = int(b.rows[1]) - 3
		var cells := (r1 - r0) * W
		for o in b.get("ores", []):
			var veins := int(round(float(o.per_1k) * cells / 1000.0))
			var min_r := r0
			var max_r := r1
			if o.has("min_m"):
				min_r = maxi(min_r, int(o.min_m) / 2)
			if o.has("max_m"):
				max_r = mini(max_r, int(o.max_m) / 2)
			if max_r <= min_r:
				continue
			for v in veins:
				var x := rng.randi_range(2, W - 3)
				var y := rng.randi_range(min_r, max_r)
				var size := rng.randi_range(int(o.size[0]), int(o.size[1]))
				for i in size:
					if _is_rock(_g(x, y)) and not _in_shaft_zone(x):
						_s(x, y, int(o.block))
					match rng.randi() % 4:
						0: x += 1
						1: x -= 1
						2: y += 1
						3: y -= 1
					x = clampi(x, 2, W - 3)
					y = clampi(y, min_r, max_r)
		bi += 1
		progress = 0.55 + 0.15 * float(bi) / biomes.size()

# ================================================================ shaft, stations, entrance
func _shaft_and_stations() -> void:
	for y in range(0, H):
		for x in range(WD.SHAFT_X0, WD.SHAFT_X1 + 1):
			_s(x, y, SHAFT)
	var i := 0
	for st in ResourceDatabase.stations:
		var depth := int(st.depth)
		if i == 0:
			wd.entities.append({"type": "station", "index": 0, "x": WD.SHAFT_X0 + 1, "y": -1})
			wd.markers["elevator_0"] = Vector2i(WD.SHAFT_X0 + 1, -1)
			i += 1
			continue
		var r := depth / 2  # floor row
		# Cage interior inside the shaft
		for y in range(r - 4, r):
			for x in range(WD.SHAFT_X0, WD.SHAFT_X1 + 1):
				_s(x, y, AIR)
		# Floor under cage + room
		for x in range(WD.SHAFT_X0, WD.SHAFT_X1 + 10):
			_s(x, r, WOOD if x > WD.SHAFT_X1 else SHAFT)
		# Station room to the right
		for y in range(r - 4, r):
			for x in range(WD.SHAFT_X1 + 1, WD.SHAFT_X1 + 10):
				_s(x, y, AIR)
		# Ceiling planks
		for x in range(WD.SHAFT_X1 + 1, WD.SHAFT_X1 + 10):
			if ResourceDatabase.is_solid(_g(x, r - 5)) or _g(x, r - 5) == AIR:
				_s(x, r - 5, WOOD)
		# Corridor to the right so the station connects with caves.
		var cx := WD.SHAFT_X1 + 10
		var length := rng.randi_range(10, 18)
		for x in range(cx, cx + length):
			for y in range(r - 3, r):
				if _g(x, y) != BEDROCK:
					_s(x, y, AIR)
			if not ResourceDatabase.is_solid(_g(x, r)):
				_s(x, r, int(_biome(r).base))
		_s(WD.SHAFT_X1 + 2, r - 3, TORCH)
		_s(WD.SHAFT_X1 + 8, r - 3, TORCH)
		wd.set_decor(WD.SHAFT_X1 + 5, r - 1, 35)
		wd.entities.append({"type": "station", "index": i, "x": WD.SHAFT_X0 + 1, "y": r - 1})
		wd.markers["elevator_%d" % i] = Vector2i(WD.SHAFT_X0 + 1, r - 1)
		i += 1

func _entrance_and_tutorial() -> void:
	# Surface: grass row with the entrance opening.
	var ex := WD.ENTRANCE_X
	wd.markers["entrance"] = Vector2i(ex + 1, -1)
	wd.markers["spawn"] = Vector2i(WD.SPAWN_X, -1)
	# The surface stays solid under the MINE portal (no open pit). Entering the mine plays a short
	# cutscene: the miner appears in the timbered entrance hall (the 20m elevator station room)
	# and walks through into the tutorial cave to the first stone blocks.
	for xx in range(ex - 3, ex + 4):
		_s(xx, 0, GRASS)
		for yy in range(1, 4):
			_s(xx, yy, DIRT)
	wd.markers["mine_inside"] = Vector2i(WD.SHAFT_X1 + 3, 9)
	wd.set_decor(WD.SHAFT_X1 + 2, 9, 34)
	# Tutorial cave: rows 6..9 from the station room to x ~132, floor at row 10.
	var cave_x0 := WD.SHAFT_X1 + 1
	var cave_x1 := 132
	for xx in range(cave_x0, cave_x1):
		var top := 6 - int(round((n_detail.get_noise_2d(xx * 2.0, 3.0) * 0.5 + 0.5) * 2.0))
		for yy in range(top, 10):
			_s(xx, yy, AIR)
		_s(xx, 10, STONE if _g(xx, 10) == AIR or _g(xx, 10) == DIRT else _g(xx, 10))
		_s(xx, 11, STONE)
	# Make the cave walls/floor guaranteed stone with ore for the tutorial.
	for xx in range(108, cave_x1 + 2):
		for yy in range(3, 13):
			if _solid(xx, yy) and _g(xx, yy) != SHAFT:
				_s(xx, yy, STONE if (xx + yy) % 5 != 0 else HARD_STONE)
	var copper_cells := [Vector2i(112, 9), Vector2i(113, 9), Vector2i(118, 5), Vector2i(119, 5),
		Vector2i(124, 10), Vector2i(125, 10), Vector2i(128, 9), Vector2i(129, 9)]
	# Carve a pocket so deposits sit in the walls: (112-113,9) floor-level bumps etc.
	for c in copper_cells:
		_s(c.x, c.y, 41)
	_s(121, 10, 40)
	_s(122, 10, 40)
	_s(116, 4, 40)
	_s(131, 8, 43)
	# A few loose stone boulders on the cave floor (easy to mine).
	for c in [Vector2i(106, 9), Vector2i(107, 9), Vector2i(110, 9), Vector2i(115, 9)]:
		_s(c.x, c.y, STONE)
	wd.markers["tutorial_stone"] = Vector2i(106, 9)
	wd.markers["tutorial_copper"] = Vector2i(112, 9)
	_s(WD.SHAFT_X1 + 4, 7, TORCH)
	_s(115, 7, TORCH)
	_s(126, 7, TORCH)
	wd.set_decor(104, 9, 19)
	wd.set_decor(120, 9, 34)
	wd.set_decor(127, 6, 30)

func _descent_path() -> void:
	## A guaranteed winding route from the tutorial cave down through the Stone Caverns.
	var x := 130
	var y := 10
	var dir := 1
	while y < 140:
		var seg := rng.randi_range(3, 9)
		if rng.randf() < 0.55:
			# go down (vertical shaft with ladder)
			for i in seg:
				for xx in range(x, x + 2):
					_s(xx, y, AIR)
				_s(x, y, LADDER)
				y += 1
		else:
			for i in seg:
				for yy in range(y - 2, y + 1):
					_s(x, yy, AIR)
					_s(x + 1, yy, AIR)
				if not _solid(x, y + 1):
					_s(x, y + 1, STONE)
				x += dir
				if x < 100 or x > W - 8:
					dir = -dir
					x += dir * 2
		if rng.randf() < 0.3:
			dir = -dir
	wd.markers["descent_end"] = Vector2i(x, y)

func _rail_tunnels() -> void:
	var per_biome := [2, 3, 2, 2, 2, 2]
	for bi in biomes.size():
		var b: Dictionary = biomes[bi]
		var r0: int = maxi(int(b.rows[0]) + 12, 24)
		var r1: int = int(b.rows[1]) - 10
		for k in per_biome[bi]:
			var length := rng.randi_range(36, 70)
			var y := rng.randi_range(r0, r1)
			var left_side := rng.randf() < 0.45
			var x0: int
			if left_side:
				x0 = rng.randi_range(3, maxi(4, WD.SHAFT_X0 - 3 - length))
			else:
				x0 = rng.randi_range(WD.SHAFT_X1 + 4, W - 4 - length)
			var x1 := x0 + length
			if left_side and x1 >= WD.SHAFT_X0 - 1:
				x1 = WD.SHAFT_X0 - 2
			if x1 - x0 < 24:
				continue
			for x in range(x0, x1):
				for yy in range(y - 2, y + 1):
					_s(x, yy, AIR)
				_s(x, y, RAIL)
				if not _solid(x, y + 1):
					_s(x, y + 1, WOOD)
				if (x - x0) % 7 == 3:
					wd.set_decor(x, y, 34)
				if (x - x0) % 14 == 7:
					_s(x, y - 2, TORCH)
			wd.entities.append({"type": "cart", "x": x0 + 1, "y": y, "x0": x0 + 1, "x1": x1 - 2})

func _room_fits(x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if not _is_rock(_g(x, y)) or _in_shaft_zone(x, 2):
				return false
	return true

func _hidden_caches() -> void:
	for bi in biomes.size():
		var b: Dictionary = biomes[bi]
		var r0: int = maxi(int(b.rows[0]) + 6, 16)
		var r1: int = int(b.rows[1]) - 8
		var want := 5 + bi
		var placed := 0
		var tries := 0
		while placed < want and tries < 400:
			tries += 1
			var x0 := rng.randi_range(3, W - 10)
			var y0 := rng.randi_range(r0, r1)
			if not _room_fits(x0, y0, 7, 5):
				continue
			for y in range(y0 + 1, y0 + 4):
				for x in range(x0 + 1, x0 + 6):
					_s(x, y, AIR)
			var gold := rng.randf() < 0.12
			wd.entities.append({"type": "chest", "x": x0 + 3, "y": y0 + 3, "biome": bi, "gold": gold})
			wd.set_decor(x0 + 1, y0 + 3, 30 if bi < 2 else 4)
			# Hidden passage of cracked wall toward the nearest open cave on this row.
			for dir in [-1, 1]:
				var found := -1
				for d in range(1, 12):
					var tx: int = (x0 + 3) + dir * (3 + d)
					if _g(tx, y0 + 3) == AIR and _g(tx, y0 + 2) == AIR:
						found = d
						break
				if found > 0:
					for d in range(0, found + 1):
						var tx2: int = (x0 + 3) + dir * (3 + d)
						for yy in [y0 + 2, y0 + 3]:
							if _solid(tx2, yy) and _g(tx2, yy) != SHAFT and _g(tx2, yy) != BEDROCK:
								_s(tx2, yy, CRACKED)
					break
			placed += 1

func _chambers() -> void:
	var defs := [
		{"name": "Old Miner's Camp", "biome": 0, "rx": 8, "ry": 4, "kind": "camp"},
		{"name": "Rusted Foundry", "biome": 1, "rx": 10, "ry": 5, "kind": "foundry"},
		{"name": "Crystal Cathedral", "biome": 2, "rx": 16, "ry": 9, "kind": "crystal"},
		{"name": "Frozen Lake", "biome": 3, "rx": 14, "ry": 6, "kind": "frozen"},
		{"name": "The Caldera", "biome": 4, "rx": 13, "ry": 7, "kind": "magma"},
		{"name": "Hall of the Ancients", "biome": 5, "rx": 15, "ry": 6, "kind": "ancient"},
	]
	for d in defs:
		var b: Dictionary = biomes[d.biome]
		var rx: int = d.rx
		var ry: int = d.ry
		var cy := rng.randi_range(int(b.rows[0]) + ry + 40, int(b.rows[1]) - ry - 10)
		var cx := rng.randi_range(rx + 4, W - rx - 5)
		if absi(cx - WD.SHAFT_X0) < rx + 4:
			cx = WD.SHAFT_X1 + rx + 6
		_build_chamber(d, cx, cy)
	# The Heart: bottom of the Ancient Core (3150m = row 1575).
	var hc := Vector2i(140, 1574)
	_build_chamber({"name": "The Heart of the Mountain", "biome": 5, "rx": 14, "ry": 6, "kind": "heart"}, hc.x, hc.y)

func _build_chamber(d: Dictionary, cx: int, cy: int) -> void:
	var rx: int = d.rx
	var ry: int = d.ry
	var kind: String = d.kind
	_carve_ellipse(cx, cy, rx, ry)
	var floor_y := cy + ry - 1
	# flatten floor
	for x in range(cx - rx + 2, cx + rx - 1):
		if _g(x, floor_y + 1) == AIR:
			_s(x, floor_y + 1, int(_biome(cy).base))
	match kind:
		"camp":
			for x in range(cx - 5, cx + 6):
				_s(x, floor_y + 1, WOOD)
			wd.set_decor(cx - 4, floor_y, 19)
			wd.set_decor(cx - 3, floor_y, 20)
			wd.set_decor(cx + 4, floor_y, 35)
			wd.set_decor(cx + 2, floor_y, 21)
		"foundry":
			for i in range(-6, 7, 3):
				wd.set_decor(cx + i, floor_y, 24)
			wd.set_decor(cx - 7, floor_y, 18)
		"crystal":
			for y in range(cy - ry - 2, cy + ry + 3):
				for x in range(cx - rx - 2, cx + rx + 3):
					if _is_rock(_g(x, y)) and rng.randf() < 0.12:
						_s(x, y, [52, 48, 49, 50][rng.randi() % 4])
			for x in range(cx - 6, cx + 7):
				if _g(x, floor_y) == AIR:
					_s(x, floor_y, WATER)
		"frozen":
			for x in range(cx - rx + 1, cx + rx):
				if _g(x, floor_y) == AIR:
					_s(x, floor_y, ICE)
					_s(x, floor_y + 1, ICE)
		"magma":
			for x in range(cx - rx + 3, cx + rx - 2):
				_s(x, floor_y, LAVA)
				if _g(x, floor_y - 1) == AIR and absi(x - cx) > 4:
					pass
			for y in range(cy - ry - 2, cy + ry + 2):
				for x in range(cx - rx - 2, cx + rx + 3):
					if _is_rock(_g(x, y)) and rng.randf() < 0.07:
						_s(x, y, [51, 62, 63][rng.randi() % 3])
		"ancient", "heart":
			for i in range(-rx + 3, rx - 2, 5):
				for y in range(floor_y - 3, floor_y + 1):
					_s(cx + i, y, ANCIENT_METAL)
			for i in range(-rx + 5, rx - 4, 5):
				wd.set_decor(cx + i, floor_y, 16)
			if kind == "heart":
				for i in [-8, -4, 4, 8]:
					_s(cx + i, cy - ry + 1, 67)
	var chest_kind := "chamber"
	wd.entities.append({"type": "chest", "x": cx, "y": floor_y, "biome": int(d.biome), "gold": true, "chamber": d.name, "heart": kind == "heart"})
	wd.entities.append({"type": "chamber", "name": d.name, "x": cx, "y": cy, "r": maxi(rx, ry) + 2, "kind": kind})
	_s(cx - 3, cy - 1, TORCH) if kind in ["camp", "foundry"] else null

func _loot_carts() -> void:
	for bi in biomes.size():
		var b: Dictionary = biomes[bi]
		var placed := 0
		var tries := 0
		while placed < 2 and tries < 300:
			tries += 1
			var x := rng.randi_range(3, W - 4)
			var y := rng.randi_range(int(b.rows[0]) + 15, int(b.rows[1]) - 6)
			if _g(x, y) == AIR and _g(x + 1, y) == AIR and _solid(x, y + 1) and _solid(x + 1, y + 1) and _g(x, y - 1) == AIR and not _in_shaft_zone(x, 3):
				wd.entities.append({"type": "loot_cart", "x": x, "y": y, "biome": bi})
				placed += 1

# ================================================================ decor
func _decorate() -> void:
	for y in range(1, H - 9):
		var b: Dictionary = _biome(y)
		var chance: float = float(b.get("decor_chance", 0.2))
		var floor_list: Array = b.get("decor_floor", [])
		var ceil_list: Array = b.get("decor_ceiling", [])
		var row := y * W
		for x in range(1, W - 1):
			if wd.blocks[row + x] != AIR or wd.decor[row + x] != 0:
				continue
			if x >= WD.SHAFT_X0 - 1 and x <= WD.SHAFT_X1 + 10 and y < 14:
				continue
			var below: int = wd.blocks[row + W + x] if y + 1 < H else BEDROCK
			var above: int = wd.blocks[row - W + x]
			var r := rng.randf()
			if ResourceDatabase.is_solid(below) and r < chance:
				# avoid crowding: skip if neighbour has decor
				if wd.decor[row + x - 1] == 0:
					wd.decor[row + x] = _pick(floor_list)
			elif ResourceDatabase.is_solid(above) and r < chance * 0.8:
				if wd.decor[row + x - 1] == 0:
					wd.decor[row + x] = _pick(ceil_list)
		if y % 32 == 0:
			progress = 0.8 + 0.17 * float(y) / H

func _pick(list: Array) -> int:
	if list.is_empty():
		return 0
	var total := 0.0
	for e in list:
		total += float(e[1])
	var r := rng.randf() * total
	for e in list:
		r -= float(e[1])
		if r <= 0.0:
			return int(e[0])
	return int(list[0][0])

func _bedrock() -> void:
	for y in H:
		_s(0, y, BEDROCK)
		_s(W - 1, y, BEDROCK)
	for y in range(H - 8, H):
		for x in W:
			_s(x, y, BEDROCK)
