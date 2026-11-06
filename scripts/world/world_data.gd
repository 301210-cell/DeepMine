extends RefCounted
## The world grid: block ids, decorations, map fog, partial block damage and entities.
## Created by world_gen.gd (new game) or deserialize() (continue). Shared via GameState.world.

const TILE := 16
const W := 192
const H := 1608
const SHAFT_X0 := 90
const SHAFT_X1 := 92
const CAMP_MAX_X := 88
const ENTRANCE_X := 97
const SPAWN_X := 74

var blocks := PackedByteArray()
var decor := PackedByteArray()
var seen := PackedByteArray()
var damage: Dictionary = {}       # Vector2i -> damage taken so far (float)
var entities: Array = []          # {"type","x","y",...}
var markers: Dictionary = {}      # name -> Vector2i (tutorial highlights, entrance...)
var world_seed: int = 0
var dirty_cells: Array[Vector2i] = [] # changed since last renderer sync

# Terrain above ground level (the rocky hill the mine entrance is dug into).
# hill_top[x] = topmost solid row (negative) for that column, or 0 when there is no hill.
const SKY_ROWS := 28
var hill_top := PackedInt32Array()
var hill_mods: Dictionary = {}   # Vector2i -> block id for mined/changed hill cells

signal cell_changed(cell: Vector2i)

func _init() -> void:
	blocks.resize(W * H)
	decor.resize(W * H)
	seen.resize(W * H)
	hill_top.resize(W)
	hill_top.fill(0)

static func idx(x: int, y: int) -> int:
	return y * W + x

static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

## Like in_bounds, but includes the above-ground hill rows (for rendering and mining).
static func in_cells(x: int, y: int) -> bool:
	return x >= 0 and y >= -SKY_ROWS and x < W and y < H

func hill_block(x: int, y: int) -> int:
	var c := Vector2i(x, y)
	if hill_mods.has(c):
		return int(hill_mods[c])
	var top: int = hill_top[x]
	if top >= 0 or y < top:
		return 0
	var d := y - top
	if d == 0:
		return ResourceDatabase.GRASS
	if d <= 2:
		return ResourceDatabase.DIRT
	var h := ((x * 73856093) ^ (y * 19349663)) & 0xff
	return 4 if h < 40 else ResourceDatabase.STONE

func get_block(x: int, y: int) -> int:
	if y < 0:
		if x < 0 or x >= W:
			return ResourceDatabase.BEDROCK
		if y < -SKY_ROWS:
			return 0
		return hill_block(x, y)
	if not in_bounds(x, y):
		return ResourceDatabase.BEDROCK
	return blocks[y * W + x]

func get_blockv(c: Vector2i) -> int:
	return get_block(c.x, c.y)

func set_block(x: int, y: int, id: int) -> void:
	if y < 0 and in_cells(x, y):
		hill_mods[Vector2i(x, y)] = id
		damage.erase(Vector2i(x, y))
		cell_changed.emit(Vector2i(x, y))
		return
	if not in_bounds(x, y):
		return
	blocks[y * W + x] = id
	damage.erase(Vector2i(x, y))
	cell_changed.emit(Vector2i(x, y))

func get_decor(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	return decor[y * W + x]

func set_decor(x: int, y: int, d: int) -> void:
	if in_bounds(x, y):
		decor[y * W + x] = d

func is_solid(x: int, y: int) -> bool:
	return ResourceDatabase.is_solid(get_block(x, y))

func is_solid_at_pos(p: Vector2) -> bool:
	return is_solid(int(floor(p.x / TILE)), int(floor(p.y / TILE)))

static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))

static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)

static func depth_m_for_y(y_px: float) -> int:
	return maxi(0, int(floor(y_px / TILE)) * 2)

func biome_at_row(y: int) -> int:
	return ResourceDatabase.biome_index_for_row(y)

## Base material block id used to draw deposits/hidden cracks at this row.
func base_block_for_row(y: int) -> int:
	if y < 6:
		return ResourceDatabase.STONE
	var b := ResourceDatabase.biome(biome_at_row(y))
	return int(b.get("base", ResourceDatabase.STONE))

func reveal(cx: int, cy: int, r: int) -> bool:
	## Marks cells around (cx,cy) as seen. Returns true if anything new was revealed.
	var changed := false
	var r2 := r * r
	for y in range(maxi(0, cy - r), mini(H, cy + r + 1)):
		var dy := y - cy
		for x in range(maxi(0, cx - r), mini(W, cx + r + 1)):
			var dx := x - cx
			if dx * dx + dy * dy <= r2:
				var i := y * W + x
				if seen[i] == 0:
					seen[i] = 1
					changed = true
	return changed

func is_seen(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	return seen[y * W + x] != 0

func entities_of(type: String) -> Array:
	return entities.filter(func(e): return e.type == type)

func entity_at(x: int, y: int, type: String = "") -> Dictionary:
	for e in entities:
		if int(e.x) == x and int(e.y) == y and (type == "" or e.type == type):
			return e
	return {}

# ---------------------------------------------------------------- persistence
func serialize() -> Dictionary:
	var dmg := []
	for c in damage:
		dmg.append([c.x, c.y, damage[c]])
	var mk := {}
	for k in markers:
		mk[k] = [markers[k].x, markers[k].y]
	return {
		"w": W, "h": H, "seed": world_seed,
		"blocks": Marshalls.raw_to_base64(blocks.compress(FileAccess.COMPRESSION_DEFLATE)),
		"decor": Marshalls.raw_to_base64(decor.compress(FileAccess.COMPRESSION_DEFLATE)),
		"seen": Marshalls.raw_to_base64(seen.compress(FileAccess.COMPRESSION_DEFLATE)),
		"damage": dmg, "entities": entities, "markers": mk,
		"hill_top": Array(hill_top), "hill_mods": _hill_mods_list(),
	}

func _hill_mods_list() -> Array:
	var out := []
	for c in hill_mods:
		out.append([c.x, c.y, int(hill_mods[c])])
	return out

static func deserialize(d: Dictionary):
	if int(d.get("w", 0)) != W or int(d.get("h", 0)) != H:
		return null
	var wd = load("res://scripts/world/world_data.gd").new()
	wd.world_seed = int(d.get("seed", 0))
	var b := Marshalls.base64_to_raw(String(d.get("blocks", ""))).decompress(W * H, FileAccess.COMPRESSION_DEFLATE)
	var dc := Marshalls.base64_to_raw(String(d.get("decor", ""))).decompress(W * H, FileAccess.COMPRESSION_DEFLATE)
	var sn := Marshalls.base64_to_raw(String(d.get("seen", ""))).decompress(W * H, FileAccess.COMPRESSION_DEFLATE)
	if b.size() != W * H:
		return null
	wd.blocks = b
	if dc.size() == W * H:
		wd.decor = dc
	if sn.size() == W * H:
		wd.seen = sn
	for e in d.get("damage", []):
		wd.damage[Vector2i(int(e[0]), int(e[1]))] = float(e[2])
	wd.entities = d.get("entities", [])
	for e in wd.entities:
		e.x = int(e.x)
		e.y = int(e.y)
	var mk: Dictionary = d.get("markers", {})
	for k in mk:
		wd.markers[k] = Vector2i(int(mk[k][0]), int(mk[k][1]))
	var ht: Array = d.get("hill_top", [])
	if ht.size() == W:
		for i in W:
			wd.hill_top[i] = int(ht[i])
	for m in d.get("hill_mods", []):
		wd.hill_mods[Vector2i(int(m[0]), int(m[1]))] = int(m[2])
	return wd
