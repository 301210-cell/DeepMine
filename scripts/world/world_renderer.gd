extends Node2D
## Streams 32x32-cell chunks of WorldData into TileMapLayers around the camera.
## Layers: BackWall (cave walls next to rock), Special (ladders/rails/liquids/torches),
## Main (terrain with collision, edge-masked), Ore (deposit overlays), plus per-chunk decor
## drawers, glow halos (in GlowLayer, unaffected by darkness) and pooled PointLight2Ds.

const WD = preload("res://scripts/world/world_data.gd")
const CHUNK := 32
const TILE := 16
const LOADS_PER_FRAME := 2
const MAX_LIGHTS := 48

const SRC_TERRAIN := 0
const SRC_ORE := 1
const SRC_WALL := 2
const SRC_SPECIAL := 3

const GLOW_DECOR := {
	3: Color("5ad8ff"), 4: Color("5ab8ff"), 5: Color("4aa3ff"), 6: Color("b46bff"), 7: Color("4fe07a"),
	10: Color("a8f0ff"), 14: Color("ff8a3a"), 16: Color("4af0d0"), 17: Color("fff1a8"), 29: Color("6ac8ff"),
	30: Color("ffc870"), 33: Color("ff6a2a"), 35: Color("ffc870"),
}
const LIGHT_DECOR := {30: 0.9, 35: 0.9, 14: 0.7, 5: 0.5, 6: 0.5, 17: 0.8, 16: 0.45}
const CEILING_DECOR := [26, 27, 28, 29, 30, 31, 32, 33]

var wd = null
var tileset: TileSet
var back: TileMapLayer
var special: TileMapLayer
var main: TileMapLayer
var ore: TileMapLayer
var water: TileMapLayer
var lava: TileMapLayer
var decor_root: Node2D
var glow_root: Node2D            # lives in the GlowLayer CanvasLayer
var light_root: Node2D
var loaded: Dictionary = {}      # Vector2i -> {"decor": Node2D, "glow": Node2D, "lights": Array}
var _queue: Array[Vector2i] = []
var _tex_decor: Texture2D
var _tex_ores: Texture2D
var _light_tex: Texture2D
var _halo_tex: Texture2D
var _lights_in_use := 0
var highlight_cells: Dictionary = {} # Vector2i -> Color (cave sense / scanner / hidden passages)

func setup(world_data, glow_parent: Node2D) -> void:
	wd = world_data
	tileset = _build_tileset()
	back = _layer("BackWall", false)
	special = _layer("Special", false)
	main = _layer("Main", true)
	ore = _layer("Ore", false)
	water = _layer("Water", false)
	water.z_index = 3
	water.modulate = Color(0.85, 0.95, 1.0, 0.62)
	lava = _layer("Lava", false)
	lava.z_index = 3
	var lava_mat := CanvasItemMaterial.new()
	lava_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lava.material = lava_mat
	decor_root = Node2D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	move_child(decor_root, 2) # behind main terrain, in front of walls/specials
	light_root = Node2D.new()
	light_root.name = "Lights"
	add_child(light_root)
	glow_root = Node2D.new()
	glow_root.name = "WorldGlow"
	glow_parent.add_child(glow_root)
	_tex_decor = ResourceDatabase.tex("res://assets/tilesets/decor.png")
	_tex_ores = ResourceDatabase.tex("res://assets/tilesets/ores.png")
	_light_tex = make_radial_texture(256, 0.0)
	_halo_tex = make_radial_texture(64, 0.0)
	wd.cell_changed.connect(_on_cell_changed)

func _layer(n: String, collide: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = tileset
	l.collision_enabled = collide
	l.rendering_quadrant_size = 16
	add_child(l)
	return l

static func make_radial_texture(size: int, inner: float) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(clampf(inner + 0.35, 0.0, 0.95), Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t

# ================================================================ tileset
func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var terrain := TileSetAtlasSource.new()
	terrain.texture = ResourceDatabase.tex("res://assets/tilesets/terrain.png")
	terrain.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(terrain, SRC_TERRAIN)
	var rows := int(terrain.texture.get_height() / TILE)
	var cols := int(terrain.texture.get_width() / TILE)
	var poly := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for r in rows:
		for c in cols:
			var co := Vector2i(c, r)
			terrain.create_tile(co)
			var td := terrain.get_tile_data(co, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, poly)

	var ores := TileSetAtlasSource.new()
	ores.texture = ResourceDatabase.tex("res://assets/tilesets/ores.png")
	ores.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(ores, SRC_ORE)
	for r in int(ores.texture.get_height() / TILE):
		for c in int(ores.texture.get_width() / TILE):
			ores.create_tile(Vector2i(c, r))

	var walls := TileSetAtlasSource.new()
	walls.texture = ResourceDatabase.tex("res://assets/tilesets/backwalls.png")
	walls.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(walls, SRC_WALL)
	for r in int(walls.texture.get_height() / TILE):
		for c in int(walls.texture.get_width() / TILE):
			walls.create_tile(Vector2i(c, r))

	var sp := TileSetAtlasSource.new()
	sp.texture = ResourceDatabase.tex("res://assets/tilesets/special.png")
	sp.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(sp, SRC_SPECIAL)
	if sp.texture.get_height() >= 112:
		for co in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
			sp.create_tile(co)
		for r in [2, 3, 4, 5, 6]:
			var co := Vector2i(0, r)
			sp.create_tile(co)
			sp.set_tile_animation_columns(co, 4)
			sp.set_tile_animation_frames_count(co, 4)
			for f in 4:
				sp.set_tile_animation_frame_duration(co, f, 0.16 if r != 6 else 0.12)
	else:
		sp.create_tile(Vector2i(0, 0))
	return ts

# ================================================================ streaming
func update_view(cam_center: Vector2, view_size: Vector2) -> void:
	var half := view_size * 0.5
	var c0 := Vector2i(int(floor((cam_center.x - half.x) / (CHUNK * TILE))) - 1, int(floor((cam_center.y - half.y) / (CHUNK * TILE))) - 1)
	var c1 := Vector2i(int(floor((cam_center.x + half.x) / (CHUNK * TILE))) + 1, int(floor((cam_center.y + half.y) / (CHUNK * TILE))) + 1)
	var need: Dictionary = {}
	for cy in range(maxi(c0.y, 0), mini(c1.y, int(ceil(float(WD.H) / CHUNK)) - 1) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, int(ceil(float(WD.W) / CHUNK)) - 1) + 1):
			var k := Vector2i(cx, cy)
			need[k] = true
			if not loaded.has(k) and not _queue.has(k):
				_queue.append(k)
	# include the surface row of chunks when near the top (sky row has no data but chunk 0 holds row 0)
	for k in loaded.keys():
		if not need.has(k) and (absi(k.x - (c0.x + c1.x) / 2) > (c1.x - c0.x) / 2 + 1 or absi(k.y - (c0.y + c1.y) / 2) > (c1.y - c0.y) / 2 + 1):
			_unload_chunk(k)
	# nearest first
	var center_chunk := Vector2i(int(cam_center.x / (CHUNK * TILE)), int(cam_center.y / (CHUNK * TILE)))
	_queue.sort_custom(func(a, b): return (a - center_chunk).length_squared() < (b - center_chunk).length_squared())
	var n := 0
	while not _queue.is_empty() and n < LOADS_PER_FRAME:
		var k2: Vector2i = _queue.pop_front()
		if need.has(k2) and not loaded.has(k2):
			_load_chunk(k2)
			n += 1

func force_load_around(pos: Vector2, view_size: Vector2) -> void:
	_queue.clear()
	var half := view_size * 0.5 + Vector2(CHUNK * TILE, CHUNK * TILE)
	for cy in range(int(floor((pos.y - half.y) / (CHUNK * TILE))), int(floor((pos.y + half.y) / (CHUNK * TILE))) + 1):
		for cx in range(int(floor((pos.x - half.x) / (CHUNK * TILE))), int(floor((pos.x + half.x) / (CHUNK * TILE))) + 1):
			var k := Vector2i(cx, cy)
			if cx < 0 or cy < 0 or cx * CHUNK >= WD.W or cy * CHUNK >= WD.H:
				continue
			if not loaded.has(k):
				_load_chunk(k)

func unload_all() -> void:
	for k in loaded.keys():
		_unload_chunk(k)

func _load_chunk(k: Vector2i) -> void:
	var x0 := k.x * CHUNK
	var y0 := k.y * CHUNK
	for y in range(y0, mini(y0 + CHUNK, WD.H)):
		for x in range(x0, mini(x0 + CHUNK, WD.W)):
			_render_cell(x, y)
	var dn := DecorChunk.new()
	dn.renderer = self
	dn.chunk = k
	dn.glow = false
	decor_root.add_child(dn)
	var gn := DecorChunk.new()
	gn.renderer = self
	gn.chunk = k
	gn.glow = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gn.material = mat
	glow_root.add_child(gn)
	var info := {"decor": dn, "glow": gn, "lights": []}
	loaded[k] = info
	_spawn_chunk_lights(k, info)

func _unload_chunk(k: Vector2i) -> void:
	var info: Dictionary = loaded.get(k, {})
	if info.is_empty():
		return
	var x0 := k.x * CHUNK
	var y0 := k.y * CHUNK
	for y in range(y0, mini(y0 + CHUNK, WD.H)):
		for x in range(x0, mini(x0 + CHUNK, WD.W)):
			var c := Vector2i(x, y)
			main.erase_cell(c)
			ore.erase_cell(c)
			back.erase_cell(c)
			special.erase_cell(c)
			water.erase_cell(c)
			lava.erase_cell(c)
	info.decor.queue_free()
	info.glow.queue_free()
	for l in info.lights:
		l.queue_free()
		_lights_in_use -= 1
	loaded.erase(k)

func is_cell_loaded(c: Vector2i) -> bool:
	return loaded.has(Vector2i(int(c.x / CHUNK), int(c.y / CHUNK)))

# ================================================================ cell rendering
static func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

func _material_row(id: int, y: int) -> int:
	var b := ResourceDatabase.block(id)
	if b.has("material"):
		return int(b.material)
	var base: int = wd.base_block_for_row(y)
	return int(ResourceDatabase.block(base).get("material", 2))

func _wall_row(x: int, y: int) -> int:
	if x >= WD.SHAFT_X0 and x <= WD.SHAFT_X1 + 9:
		return 7
	if y < 9:
		return 6
	return maxi(0, wd.biome_at_row(y))

func _needs_wall(x: int, y: int) -> bool:
	if y < 1:
		return false
	if x >= WD.SHAFT_X0 and x <= WD.SHAFT_X1 + 9 and y < 1300:
		return true
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if wd.is_solid(x + dx, y + dy):
				return true
	return false

func _render_cell(x: int, y: int) -> void:
	var c := Vector2i(x, y)
	var id: int = wd.get_block(x, y)
	var solid := ResourceDatabase.is_solid(id)
	var h := _hash(x, y)
	if solid:
		back.erase_cell(c)
		var mask := 0
		if not wd.is_solid(x, y - 1): mask |= 1
		if not wd.is_solid(x + 1, y): mask |= 2
		if not wd.is_solid(x, y + 1): mask |= 4
		if not wd.is_solid(x - 1, y): mask |= 8
		water.erase_cell(c)
		lava.erase_cell(c)
		main.set_cell(c, SRC_TERRAIN, Vector2i(mask, _material_row(id, y) * 2 + (h & 1)))
		var b := ResourceDatabase.block(id)
		if b.has("ore"):
			ore.set_cell(c, SRC_ORE, Vector2i((h >> 3) & 3, int(b.ore)))
		else:
			ore.erase_cell(c)
		special.erase_cell(c)
	else:
		main.erase_cell(c)
		ore.erase_cell(c)
		if id != ResourceDatabase.WATER:
			water.erase_cell(c)
		if id != ResourceDatabase.LAVA:
			lava.erase_cell(c)
		if _needs_wall(x, y):
			back.set_cell(c, SRC_WALL, Vector2i((h >> 2) & 3, _wall_row(x, y)))
		else:
			back.erase_cell(c)
		match id:
			ResourceDatabase.LADDER:
				var top: bool = wd.get_block(x, y - 1) != ResourceDatabase.LADDER
				special.set_cell(c, SRC_SPECIAL, Vector2i(1 if top else 0, 0))
			ResourceDatabase.RAIL:
				var l: bool = wd.get_block(x - 1, y) != ResourceDatabase.RAIL
				var r: bool = wd.get_block(x + 1, y) != ResourceDatabase.RAIL
				special.set_cell(c, SRC_SPECIAL, Vector2i(1 if l else (2 if r else 0), 1))
			ResourceDatabase.LAVA:
				special.erase_cell(c)
				lava.set_cell(c, SRC_SPECIAL, Vector2i(0, 2 if wd.get_block(x, y - 1) != ResourceDatabase.LAVA else 3))
			ResourceDatabase.WATER:
				special.erase_cell(c)
				water.set_cell(c, SRC_SPECIAL, Vector2i(0, 4 if wd.get_block(x, y - 1) != ResourceDatabase.WATER else 5))
			ResourceDatabase.TORCH:
				special.set_cell(c, SRC_SPECIAL, Vector2i(0, 6))
			_:
				special.erase_cell(c)

func _on_cell_changed(c: Vector2i) -> void:
	if not is_cell_loaded(c):
		return
	for o in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + o
		if WD.in_bounds(n.x, n.y):
			_render_cell(n.x, n.y)
	# walls within radius 2 may change
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var n2 := c + Vector2i(dx, dy)
			if WD.in_bounds(n2.x, n2.y) and not wd.is_solid(n2.x, n2.y):
				if _needs_wall(n2.x, n2.y):
					back.set_cell(n2, SRC_WALL, Vector2i((_hash(n2.x, n2.y) >> 2) & 3, _wall_row(n2.x, n2.y)))
				else:
					back.erase_cell(n2)
	# decor supported by this cell disappears
	var above := c + Vector2i(0, -1)
	if wd.get_decor(above.x, above.y) != 0 and not CEILING_DECOR.has(wd.get_decor(above.x, above.y)) and not wd.is_solid(c.x, c.y):
		wd.set_decor(above.x, above.y, 0)
	var below := c + Vector2i(0, 1)
	if CEILING_DECOR.has(wd.get_decor(below.x, below.y)) and not wd.is_solid(c.x, c.y):
		wd.set_decor(below.x, below.y, 0)
	if wd.get_decor(c.x, c.y) != 0 and wd.is_solid(c.x, c.y):
		wd.set_decor(c.x, c.y, 0)
	redraw_chunk_of(c)
	if wd.get_block(c.x, c.y) == ResourceDatabase.TORCH:
		var k := Vector2i(int(c.x / CHUNK), int(c.y / CHUNK))
		_add_light(loaded[k], WD.cell_center(c), Color("ffb860"), 0.85, 0.9)

func redraw_chunk_of(c: Vector2i) -> void:
	var k := Vector2i(int(c.x / CHUNK), int(c.y / CHUNK))
	var info: Dictionary = loaded.get(k, {})
	if info.is_empty():
		return
	info.decor.queue_redraw()
	info.glow.queue_redraw()

func redraw_all_glow() -> void:
	for k in loaded:
		loaded[k].glow.queue_redraw()

# ================================================================ lights
func _spawn_chunk_lights(k: Vector2i, info: Dictionary) -> void:
	var x0 := k.x * CHUNK
	var y0 := k.y * CHUNK
	var lava_count := 0
	for y in range(y0, mini(y0 + CHUNK, WD.H)):
		for x in range(x0, mini(x0 + CHUNK, WD.W)):
			var id: int = wd.get_block(x, y)
			if id == ResourceDatabase.TORCH:
				_add_light(info, WD.cell_center(Vector2i(x, y)), Color("ffb860"), 0.85, 0.9)
			elif id == ResourceDatabase.LAVA and wd.get_block(x, y - 1) != ResourceDatabase.LAVA:
				lava_count += 1
				if lava_count % 4 == 1:
					_add_light(info, WD.cell_center(Vector2i(x, y)), Color("ff6a2a"), 1.0, 0.75)
			var d: int = wd.get_decor(x, y)
			if LIGHT_DECOR.has(d):
				_add_light(info, WD.cell_center(Vector2i(x, y)) + Vector2(0, -6 if not CEILING_DECOR.has(d) else 6), GLOW_DECOR.get(d, Color.WHITE), float(LIGHT_DECOR[d]), 0.6)

func _add_light(info: Dictionary, pos: Vector2, color: Color, scale: float, energy: float) -> void:
	if _lights_in_use >= MAX_LIGHTS:
		return
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = scale
	l.color = color
	l.energy = energy
	l.position = pos
	l.shadow_enabled = false
	light_root.add_child(l)
	info.lights.append(l)
	_lights_in_use += 1

# ================================================================ decor drawing
class DecorChunk:
	extends Node2D
	var renderer
	var chunk: Vector2i
	var glow: bool = false
	var t := 0.0

	func _ready() -> void:
		if glow:
			set_process(true)

	func _process(delta: float) -> void:
		t += delta
		if Engine.get_process_frames() % 6 == (chunk.x + chunk.y) % 6:
			queue_redraw()

	func _draw() -> void:
		var wd = renderer.wd
		var x0: int = chunk.x * 32
		var y0: int = chunk.y * 32
		var tex: Texture2D = renderer._tex_decor
		var halo: Texture2D = renderer._halo_tex
		var ores_tex: Texture2D = renderer._tex_ores
		for y in range(y0, mini(y0 + 32, 1608)):
			for x in range(x0, mini(x0 + 32, 192)):
				var d: int = wd.get_decor(x, y)
				if d > 0:
					var src := Rect2((d % 8) * 32, int(d / 8) * 32, 32, 32)
					var px := x * 16 + 8 - 16
					var py := (y + 1) * 16 - 32
					if renderer.CEILING_DECOR.has(d):
						py = y * 16
					if not glow:
						draw_texture_rect_region(tex, Rect2(px, py, 32, 32), src)
					elif renderer.GLOW_DECOR.has(d):
						var col: Color = renderer.GLOW_DECOR[d]
						var pulse := 0.75 + 0.25 * sin(t * 2.0 + x * 0.7 + y * 0.3)
						var cy := py + (10 if renderer.CEILING_DECOR.has(d) else 22)
						draw_texture_rect(halo, Rect2(px - 8, cy - 24, 48, 48), false, Color(col.r, col.g, col.b, 0.28 * pulse))
						draw_texture_rect_region(tex, Rect2(px, py, 32, 32), src, Color(1, 1, 1, 0.55))
				if glow:
					var id: int = wd.get_block(x, y)
					if id >= 40 and id < 90:
						var b: Dictionary = ResourceDatabase.block(id)
						var hl: Color = renderer.highlight_cells.get(Vector2i(x, y), Color(0, 0, 0, 0))
						if b.has("glow") and (not wd.is_solid(x, y - 1) or not wd.is_solid(x + 1, y) or not wd.is_solid(x, y + 1) or not wd.is_solid(x - 1, y)):
							var gc := Color(String(b.glow))
							var p2 := 0.7 + 0.3 * sin(t * 2.6 + x + y * 1.3)
							draw_texture_rect(halo, Rect2(x * 16 - 8, y * 16 - 8, 32, 32), false, Color(gc.r, gc.g, gc.b, 0.22 * p2))
							var h: int = renderer._hash(x, y)
							draw_texture_rect_region(ores_tex, Rect2(x * 16, y * 16, 16, 16), Rect2(((h >> 3) & 3) * 16, int(b.ore) * 16, 16, 16), Color(1, 1, 1, 0.45 * p2))
						if hl.a > 0.0:
							var p3 := 0.6 + 0.4 * sin(t * 4.0 + x * 0.5)
							draw_texture_rect(halo, Rect2(x * 16 - 6, y * 16 - 6, 28, 28), false, Color(hl.r, hl.g, hl.b, 0.35 * p3))
							draw_rect(Rect2(x * 16 + 1, y * 16 + 1, 14, 14), Color(hl.r, hl.g, hl.b, 0.55 * p3), false, 1.0)
							var h2: int = renderer._hash(x, y)
							draw_texture_rect_region(ores_tex, Rect2(x * 16, y * 16, 16, 16), Rect2(((h2 >> 3) & 3) * 16, int(b.ore) * 16, 16, 16), Color(1, 1, 1, 0.8 * p3))
