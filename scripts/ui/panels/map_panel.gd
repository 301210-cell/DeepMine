extends Control
## Underground map panel. Renders the discovered world at 1 px per tile (biome-coloured rock,
## bright tunnels, fog of war) with zoom/pan, biome borders, depth markers and icons for the
## player, elevator stations, caches, carts and special chambers.
## UIRoot instances this scene and calls open(data); emits close_requested when closed.

signal close_requested

const SKY_ROWS := 14
const ZOOM_LEVELS: Array[float] = [1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
const DEFAULT_ZOOM := 3
const PLAYER_TEX := "res://assets/sprites/player/player.png"
const MINECART_TEX := "res://assets/sprites/world/minecart.png"
const FOG := Color("070a18")
const FOG_ALT := Color("0a0e20")
const ICON_STATION := 33
const ICON_CHEST := 40
const ICON_GEODE := 51
const ICON_SPARKLE := 41
const ICON_DEPTH := 32
const ICON_MAP := 10

@onready var window: Control = %Window
@onready var map_view: Control = %MapView
@onready var depth_label: Label = %DepthLabel
@onready var biome_label: Label = %BiomeLabel
@onready var hint_label: Label = %HintLabel
@onready var info_label: Label = %InfoLabel
@onready var travel_button: Button = %TravelButton
@onready var close_button: BaseButton = %CloseButton
@onready var zoom_in_button: Button = %ZoomIn
@onready var zoom_out_button: Button = %ZoomOut
@onready var center_button: Button = %CenterButton
@onready var depth_icon: TextureRect = %DepthIcon
@onready var title_icon: TextureRect = %TitleIcon

var world: Object = null
var map_tex: ImageTexture
var map_size := Vector2i.ZERO
var zoom_i := DEFAULT_ZOOM
var zoom := 3.0
var pan := Vector2.ZERO          # image-pixel coordinate shown at the view centre
var dragging := false
var drag_dist := 0.0
var icons: Array = []            # {pos: Vector2 (image px), kind, tex, label, color, dim}
var hover_icon := -1
var time := 0.0
var player_head: AtlasTexture
var cart_tex: AtlasTexture
var _at_station := -1

func _ready() -> void:
	close_button.pressed.connect(func(): AudioManager.play("ui_close"); close_requested.emit())
	travel_button.pressed.connect(_on_travel)
	zoom_in_button.pressed.connect(func(): _set_zoom(zoom_i + 1, map_view.size * 0.5))
	zoom_out_button.pressed.connect(func(): _set_zoom(zoom_i - 1, map_view.size * 0.5))
	center_button.pressed.connect(_center_on_player)
	map_view.draw.connect(_draw_map)
	map_view.gui_input.connect(_on_map_input)
	map_view.mouse_exited.connect(func(): hover_icon = -1; _update_info())
	map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	depth_icon.texture = ResourceDatabase.ui_icon(ICON_DEPTH)
	title_icon.texture = ResourceDatabase.ui_icon(ICON_MAP)
	for b in [travel_button, zoom_in_button, zoom_out_button, center_button]:
		b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -10.0))
		b.pressed.connect(func(): AudioManager.play("ui_click"))
	if ResourceLoader.exists(PLAYER_TEX):
		player_head = AtlasTexture.new()
		player_head.atlas = load(PLAYER_TEX)
		player_head.region = Rect2(7, 13, 19, 15)
	if ResourceLoader.exists(MINECART_TEX):
		cart_tex = AtlasTexture.new()
		cart_tex.atlas = load(MINECART_TEX)
		cart_tex.region = Rect2(0, 0, 32, 24)

func open(_data = null) -> void:
	world = GameState.world
	if world == null:
		world = FakeWorld.new()
	_build_texture()
	_build_icons()
	zoom_i = DEFAULT_ZOOM
	zoom = ZOOM_LEVELS[zoom_i]
	_center_on_player()
	_update_readouts()
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.94, 0.94)
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "scale", Vector2.ONE, 0.18)
	tw.tween_property(window, "modulate:a", 1.0, 0.12)

func _process(delta: float) -> void:
	time += delta
	map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_EQUAL, KEY_KP_ADD:
				_set_zoom(zoom_i + 1, map_view.size * 0.5)
				accept_event()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_set_zoom(zoom_i - 1, map_view.size * 0.5)
				accept_event()
			KEY_C:
				_center_on_player()
				accept_event()

# ---------------------------------------------------------------- world texture
func _row_biome_colors(y: int) -> Array:
	## Returns [solid_int, open_int, open_edge_int] packed colours for a world row.
	## Reference style: dark navy rock, glowing blue tunnel network (lightly tinted per biome).
	var b := ResourceDatabase.biome_index_for_row(y)
	var base := Color(ResourceDatabase.biome(b).get("color", "8090a0"))
	var solid := Color("111a3c").lerp(base, 0.08)
	var open := Color("2f7bff").lerp(base, 0.14)
	var edge := Color("7cc8ff").lerp(base, 0.10)
	var rim := Color("1c3a86").lerp(base, 0.06)
	return [_pack(solid), _pack(open), _pack(edge), _pack(solid.darkened(0.35)), _pack(rim)]

static func _pack(c: Color) -> int:
	return (c.a8 << 24) | (c.b8 << 16) | (c.g8 << 8) | c.r8

func _build_texture() -> void:
	var W: int = world.W
	var H: int = world.H
	var IH := H + SKY_ROWS
	map_size = Vector2i(W, IH)
	var ints := PackedInt32Array()
	# Sky band above the surface.
	for y in SKY_ROWS:
		var t := float(y) / float(SKY_ROWS - 1)
		var row := PackedInt32Array()
		row.resize(W)
		row.fill(_pack(Color("0e1838").lerp(Color("2c4a88"), t)))
		ints.append_array(row)
	var seen: PackedByteArray = world.seen if "seen" in world else PackedByteArray()
	var has_seen := seen.size() == W * H
	var blocks: PackedByteArray = PackedByteArray()
	if "blocks" in world:
		blocks = world.blocks
	var direct := blocks.size() == W * H and _verify_direct(blocks, W, H)
	var scanner_marks := String(GameState.equipped.get("scanner", "")) == "scanner_mk2"
	var fog_a := _pack(FOG)
	var fog_b := _pack(FOG_ALT)
	var lava_c := _pack(Color("ff6a1a"))
	var water_c := _pack(Color("3f8dff"))
	var rail_c := _pack(Color("e8c070"))
	var fog_row_a := PackedInt32Array()
	fog_row_a.resize(W)
	var fog_row_b := PackedInt32Array()
	fog_row_b.resize(W)
	for x in W:
		fog_row_a[x] = fog_a if (x % 4) != 0 else fog_b
		fog_row_b[x] = fog_a if ((x + 2) % 4) != 0 else fog_b
	var cur_biome_row := -999
	var cols: Array = []
	var row_cols: Array = []           # per-row colour table (for the glow pass)
	row_cols.resize(H)
	var kind := PackedByteArray()      # 0 fog, 1 open tunnel, 2 seen rock
	kind.resize(W * H)
	var row_used := PackedByteArray()
	row_used.resize(H)
	for y in H:
		var b := ResourceDatabase.biome_index_for_row(y)
		if b != cur_biome_row:
			cur_biome_row = b
			cols = _row_biome_colors(y)
		row_cols[y] = cols
		var row: PackedInt32Array = (fog_row_a if (y % 4) < 2 else fog_row_b).duplicate()
		var i0 := y * W
		if has_seen:
			if seen.slice(i0, i0 + W).count(0) == W:
				ints.append_array(row)
				continue
		row_used[y] = 1
		for x in W:
			var i := i0 + x
			if has_seen and seen[i] == 0:
				continue
			var id: int = blocks[i] if direct else int(world.get_block(x, y))
			var c: int
			kind[i] = 2
			if id == 0 or (not ResourceDatabase.is_solid(id) and id != ResourceDatabase.LAVA and id != ResourceDatabase.WATER):
				kind[i] = 1
			if id == 0:
				c = cols[1]
			elif id == ResourceDatabase.LAVA:
				c = lava_c
			elif id == ResourceDatabase.WATER:
				c = water_c
			elif id == ResourceDatabase.RAIL:
				c = rail_c
			elif not ResourceDatabase.is_solid(id):
				c = cols[1]
			elif scanner_marks and ResourceDatabase.is_deposit(id) and int(ResourceDatabase.block(id).get("rarity", 0)) >= 1:
				c = _pack(ResourceDatabase.rarity_color(int(ResourceDatabase.block(id).get("rarity", 0))))
			elif id == ResourceDatabase.BEDROCK or id == ResourceDatabase.SHAFT_WALL:
				c = cols[3]
			else:
				c = cols[0]
			row[x] = c
		ints.append_array(row)
	# Glow pass: tunnel cells touching rock get a bright edge, rock touching tunnels a blue rim.
	for y in H:
		if row_used[y] == 0:
			continue
		var rc: Array = row_cols[y]
		var i0 := y * W
		for x in range(1, W - 1):
			var i := i0 + x
			var k := kind[i]
			if k == 0:
				continue
			var up := kind[i - W] if y > 0 else k
			var dn := kind[i + W] if y < H - 1 else k
			var lf := kind[i - 1]
			var rt := kind[i + 1]
			var o := (y + SKY_ROWS) * W + x
			if k == 1:
				if up == 2 or dn == 2 or lf == 2 or rt == 2:
					ints[o] = rc[2]
			elif k == 2 and ints[o] == rc[0]:
				if up == 1 or dn == 1 or lf == 1 or rt == 1:
					ints[o] = rc[4]
	var img := Image.create_from_data(W, IH, false, Image.FORMAT_RGBA8, ints.to_byte_array())
	map_tex = ImageTexture.create_from_image(img)

func _verify_direct(blocks: PackedByteArray, W: int, H: int) -> bool:
	if not world.has_method("get_block"):
		return true
	for p in [Vector2i(3, 5), Vector2i(W - 4, H / 2), Vector2i(W / 2, H - 3), Vector2i(17, 333)]:
		if p.y >= H or p.x >= W:
			continue
		if int(world.get_block(p.x, p.y)) != blocks[p.y * W + p.x]:
			return false
	return true

func _is_seen(x: int, y: int) -> bool:
	if not "seen" in world:
		return true
	var seen: PackedByteArray = world.seen
	var W: int = world.W
	if seen.size() != W * int(world.H):
		return true
	if x < 0 or y < 0 or x >= W or y >= int(world.H):
		return y < 0
	return seen[y * W + x] != 0

# ---------------------------------------------------------------- icons
func _build_icons() -> void:
	icons.clear()
	var ents: Array = world.entities if "entities" in world else []
	var station_order := 0
	for e in ents:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var t: String = e.get("type", "")
		var x := int(e.get("x", 0))
		var y := int(e.get("y", 0))
		var pos := Vector2(x + 0.5, y + 0.5 + SKY_ROWS)
		match t:
			"station":
				var idx := int(e.get("index", station_order))
				station_order += 1
				var unlocked: bool = idx < GameState.stations.size() and bool(GameState.stations[idx])
				if not unlocked and not _is_seen(x, y):
					continue
				var st: Dictionary = ResourceDatabase.stations[idx] if idx < ResourceDatabase.stations.size() else {}
				icons.append({"pos": pos, "kind": "station", "tex": ResourceDatabase.ui_icon(ICON_STATION),
					"label": "Elevator: %s (%dm)%s" % [st.get("name", "Station"), int(st.get("depth", y * 2)), "" if unlocked else "  [locked]"],
					"dim": not unlocked, "index": idx})
			"chest":
				if not _is_seen(x, y):
					continue
				var opened: bool = GameState.opened.has("%d,%d" % [x, y])
				icons.append({"pos": pos, "kind": "chest", "tex": ResourceDatabase.ui_icon(ICON_CHEST),
					"label": "Hidden cache (looted)" if opened else "Hidden cache", "dim": opened})
			"cart", "loot_cart":
				if not _is_seen(x, y):
					continue
				var looted: bool = GameState.opened.has("%d,%d" % [x, y])
				icons.append({"pos": pos, "kind": "cart", "tex": cart_tex,
					"label": ("Abandoned cart" + (" (looted)" if looted else "")) if t == "loot_cart" else "Mine cart",
					"dim": t == "loot_cart" and looted, "loot": t == "loot_cart"})
			"chamber":
				var nm: String = e.get("name", "Special Chamber")
				var found: bool = GameState.chambers.has(nm)
				if not found and not _is_seen(x, y):
					continue
				icons.append({"pos": pos, "kind": "chamber", "tex": ResourceDatabase.item_icon("amethyst") if found else ResourceDatabase.ui_icon(ICON_SPARKLE),
					"label": nm if found else "Unknown chamber", "dim": false})

func _player_img_pos() -> Vector2:
	return Vector2(GameState.player_pos.x / 16.0, GameState.player_pos.y / 16.0 + SKY_ROWS)

# ---------------------------------------------------------------- view math
func _to_view(img_pos: Vector2) -> Vector2:
	return map_view.size * 0.5 + (img_pos - pan) * zoom

func _to_img(view_pos: Vector2) -> Vector2:
	return pan + (view_pos - map_view.size * 0.5) / zoom

func _clamp_pan() -> void:
	pan.x = clampf(pan.x, 0.0, float(map_size.x))
	pan.y = clampf(pan.y, 0.0, float(map_size.y))

func _set_zoom(i: int, anchor_view: Vector2) -> void:
	i = clampi(i, 0, ZOOM_LEVELS.size() - 1)
	if i == zoom_i:
		return
	var before := _to_img(anchor_view)
	zoom_i = i
	zoom = ZOOM_LEVELS[i]
	pan = before - (anchor_view - map_view.size * 0.5) / zoom
	_clamp_pan()
	zoom_in_button.disabled = zoom_i >= ZOOM_LEVELS.size() - 1
	zoom_out_button.disabled = zoom_i <= 0

func _center_on_player() -> void:
	pan = _player_img_pos()
	_clamp_pan()

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(zoom_i + 1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(zoom_i - 1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
			if mb.pressed:
				drag_dist = 0.0
		map_view.accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if dragging:
			pan -= mm.relative / zoom
			drag_dist += mm.relative.length()
			_clamp_pan()
		_update_hover(mm.position)
	elif event is InputEventMagnifyGesture:
		var g := event as InputEventMagnifyGesture
		_set_zoom(zoom_i + (1 if g.factor > 1.0 else -1), g.position)
	elif event is InputEventPanGesture:
		pan += (event as InputEventPanGesture).delta * 4.0 / zoom
		_clamp_pan()

func _update_hover(mp: Vector2) -> void:
	var best := -1
	var best_d := 9.0
	for i in icons.size():
		var d: float = _to_view(icons[i].pos).distance_to(mp)
		if d < best_d:
			best_d = d
			best = i
	if _to_view(_player_img_pos()).distance_to(mp) < 8.0:
		best = -2
	if best != hover_icon:
		hover_icon = best
		_update_info()

func _update_info() -> void:
	if hover_icon == -2:
		info_label.text = "You are here  (%dm)" % GameState.current_depth
	elif hover_icon >= 0 and hover_icon < icons.size():
		info_label.text = icons[hover_icon].label
	else:
		info_label.text = "Drag to pan  •  Scroll to zoom"

# ---------------------------------------------------------------- drawing
func _font() -> Font:
	return get_theme_font("font", "Label")

func _text(pos: Vector2, s: String, col: Color, size: int = 10) -> void:
	var f := _font()
	map_view.draw_string(f, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	map_view.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw_map() -> void:
	var vs := map_view.size
	map_view.draw_rect(Rect2(Vector2.ZERO, vs), FOG)
	if map_tex == null:
		return
	var tl := _to_view(Vector2.ZERO)
	map_view.draw_texture_rect(map_tex, Rect2(tl.round(), Vector2(map_size) * zoom), false)
	# Surface line + camp label.
	var surf_y := _to_view(Vector2(0, SKY_ROWS)).y
	if surf_y > -10 and surf_y < vs.y + 10:
		map_view.draw_line(Vector2(tl.x, surf_y), Vector2(tl.x + map_size.x * zoom, surf_y), Color("7ad06a"), 1.0)
		_text(Vector2(maxf(tl.x, 0) + 4, surf_y - 4), "MINING CAMP", Color("bff0a8"))
	# Biome borders + labels.
	for b in ResourceDatabase.biomes:
		var idx := int(b.index)
		var row := int(b.rows[0])
		var y := _to_view(Vector2(0, row + SKY_ROWS)).y
		var col := Color(b.get("color", "ffffff"))
		var found: bool = idx < GameState.biomes_found.size() and bool(GameState.biomes_found[idx])
		if idx > 0 and y > -4 and y < vs.y + 4:
			var x0 := maxf(tl.x, 0.0)
			var x1 := minf(tl.x + map_size.x * zoom, vs.x)
			var x := x0
			while x < x1:
				map_view.draw_line(Vector2(x, y), Vector2(minf(x + 6, x1), y), Color(col, 0.8), 1.0)
				x += 10
		var label_y := y + 12
		var bottom_y := _to_view(Vector2(0, int(b.rows[1]) + SKY_ROWS)).y
		label_y = clampf(12.0, y + 12, maxf(y + 12, bottom_y - 4))
		if bottom_y > 0 and y < vs.y:
			var name_s: String = (String(b.name).to_upper() if found else "???")
			_text(Vector2(maxf(tl.x, 0) + 32, label_y), "%s  %dm" % [name_s, int(b.depth[0])], col.lightened(0.3) if found else Color("6a7090"))
	# Depth ticks on the right edge.
	var step_m := 100
	if zoom < 2.0:
		step_m = 250
	if zoom < 1.2:
		step_m = 500
	var m := 0
	while m <= int(world.H) * 2:
		var ty := _to_view(Vector2(0, m / 2.0 + SKY_ROWS)).y
		if ty > 6 and ty < vs.y - 2:
			map_view.draw_line(Vector2(vs.x - 6, ty), Vector2(vs.x, ty), Color("8a93a8"), 1.0)
			var s := "%dm" % m
			var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			_text(Vector2(vs.x - 8 - w, ty + 3), s, Color("8a93a8"))
		m += step_m
	# Icons.
	for i in icons.size():
		var ic: Dictionary = icons[i]
		var p := _to_view(ic.pos)
		if p.x < -12 or p.y < -12 or p.x > vs.x + 12 or p.y > vs.y + 12:
			continue
		var tint := Color(1, 1, 1, 0.45) if ic.dim else Color.WHITE
		if i == hover_icon:
			map_view.draw_circle(p, 9.0, Color(1, 1, 1, 0.18))
		if ic.kind == "chamber" and not ic.dim:
			var pulse := 0.5 + 0.5 * sin(time * 3.0)
			map_view.draw_circle(p, 6.0 + pulse * 3.0, Color(0.3, 0.95, 0.85, 0.18))
		if ic.kind == "cart" and ic.tex == null:
			_draw_cart_glyph(p, tint)
		elif ic.kind == "cart":
			map_view.draw_texture_rect(ic.tex, Rect2((p - Vector2(8, 6)).round(), Vector2(16, 12)), false, tint)
			if ic.get("loot", false) and not ic.dim:
				map_view.draw_texture_rect(ResourceDatabase.ui_icon(ICON_SPARKLE), Rect2((p + Vector2(2, -12)).round(), Vector2(10, 10)), false, Color(1, 1, 1, 0.6 + 0.4 * sin(time * 5.0)))
		elif ic.tex:
			map_view.draw_texture_rect(ic.tex, Rect2((p - Vector2(8, 8)).round(), Vector2(16, 16)), false, tint)
	# Player.
	var pp := _to_view(_player_img_pos())
	var pr := 7.0 + 2.0 * sin(time * 4.0)
	map_view.draw_arc(pp, pr + 4.0, 0, TAU, 24, Color(1.0, 0.82, 0.25, 0.55), 1.5)
	map_view.draw_circle(pp, 10.0, Color("141a3a"))
	map_view.draw_arc(pp, 10.0, 0, TAU, 24, Color("ffc93c"), 2.0)
	if player_head:
		map_view.draw_texture_rect(player_head, Rect2((pp - Vector2(9, 8)).round(), Vector2(19, 15)), false)
	else:
		map_view.draw_circle(pp, 4.0, Color("ffc93c"))
	# Off-screen player arrow.
	if pp.x < 0 or pp.y < 0 or pp.x > vs.x or pp.y > vs.y:
		var c := vs * 0.5
		var dir := (pp - c).normalized()
		var edge := c + dir * minf(absf((vs.x * 0.5 - 12) / maxf(absf(dir.x), 0.001)), absf((vs.y * 0.5 - 12) / maxf(absf(dir.y), 0.001)))
		var n := Vector2(-dir.y, dir.x)
		map_view.draw_colored_polygon(PackedVector2Array([edge + dir * 7, edge - dir * 4 + n * 5, edge - dir * 4 - n * 5]), Color("ffc93c"))
	# Frame inner shadow.
	map_view.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5), false, 2.0)

func _draw_cart_glyph(p: Vector2, tint: Color) -> void:
	map_view.draw_rect(Rect2(p + Vector2(-6, -5), Vector2(12, 7)), Color("6a4a2a") * tint)
	map_view.draw_rect(Rect2(p + Vector2(-6, -5), Vector2(12, 7)), Color("2a1a10") * tint, false, 1.0)
	map_view.draw_circle(p + Vector2(-3, 3), 2.0, Color("3a3a48") * tint)
	map_view.draw_circle(p + Vector2(3, 3), 2.0, Color("3a3a48") * tint)

# ---------------------------------------------------------------- readouts / travel
func _update_readouts() -> void:
	depth_label.text = "Depth: %dm" % GameState.current_depth
	var b := GameState.current_biome
	if GameState.at_surface or b < 0:
		biome_label.text = "Mining Camp"
		biome_label.modulate = Color("bff0a8")
	else:
		biome_label.text = String(ResourceDatabase.biome(b).get("name", ""))
		biome_label.modulate = Color(ResourceDatabase.biome(b).get("color", "ffffff")).lightened(0.25)
	_at_station = _nearby_station()
	var can_travel := GameState.at_surface or _at_station >= 0
	travel_button.modulate = Color.WHITE if can_travel else Color(0.75, 0.8, 0.95)
	hint_label.text = "" if can_travel else "Find an elevator to travel"
	_update_info()

func _nearby_station() -> int:
	if world == null or not "entities" in world:
		return -1
	var pc := Vector2(GameState.player_pos.x / 16.0, GameState.player_pos.y / 16.0)
	var order := 0
	for e in world.entities:
		if typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "station":
			var idx := int(e.get("index", order))
			order += 1
			if absf(pc.x - float(e.get("x", 0))) <= 5.0 and absf(pc.y - float(e.get("y", 0))) <= 3.5:
				return idx
	return -1

func _on_travel() -> void:
	if not (GameState.at_surface or _at_station >= 0):
		AudioManager.play("ui_error")
		hint_label.text = "You need to stand at an elevator to travel."
		var tw := create_tween()
		hint_label.modulate = Color("ff8a6a")
		for i in 3:
			tw.tween_property(hint_label, "position:x", hint_label.position.x + 3, 0.04)
			tw.tween_property(hint_label, "position:x", hint_label.position.x - 3, 0.04)
		tw.tween_property(hint_label, "modulate", Color.WHITE, 0.6)
		return
	Events.open_panel_requested.emit("elevator", {"current": _at_station if _at_station >= 0 else 0})

# ---------------------------------------------------------------- capture / fake world
func _capture_setup(_args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	GameState.new_game(7)
	GameState.player_pos = Vector2(96 * 16, 60 * 16)
	GameState.current_depth = 120
	GameState.current_biome = 0
	GameState.at_surface = false
	GameState.biomes_found[1] = true
	GameState.stations[2] = true
	GameState.chambers["Old Miner's Camp"] = true
	theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	open(null)

## Minimal stand-in with the WorldData interface, used when no game world is loaded (captures).
class FakeWorld:
	extends RefCounted
	var W := 192
	var H := 1608
	var blocks := PackedByteArray()
	var seen := PackedByteArray()
	var entities: Array = []

	func _init() -> void:
		blocks.resize(W * H)
		seen.resize(W * H)
		var n := FastNoiseLite.new()
		n.seed = 11
		n.frequency = 0.045
		var n2 := FastNoiseLite.new()
		n2.seed = 5
		n2.frequency = 0.02
		for y in 360:
			for x in W:
				var i := y * W + x
				var open := n.get_noise_2d(x, y) > 0.28 or absf(n2.get_noise_2d(x, y)) < 0.035
				blocks[i] = 0 if (open and y > 3) else (3 if y < 150 else 5)
				if x == 0 or x == W - 1:
					blocks[i] = 18
				if x >= 72 and x <= 75:
					blocks[i] = 19
				var dx := x - 96
				var dy := y - 60
				if dx * dx / 2600.0 + dy * dy / 3200.0 < 1.0 + n.get_noise_2d(x * 3, y * 3) * 0.3:
					seen[i] = 1
		for y in range(0, 12):
			for x in range(76, 100):
				seen[y * W + x] = 1
		entities = [
			{"type": "station", "x": 77, "y": 10, "index": 1},
			{"type": "station", "x": 77, "y": 75, "index": 2},
			{"type": "station", "x": 77, "y": 155, "index": 3},
			{"type": "chest", "x": 110, "y": 48},
			{"type": "loot_cart", "x": 84, "y": 92},
			{"type": "cart", "x": 120, "y": 70},
			{"type": "chamber", "x": 130, "y": 40, "name": "Old Miner's Camp"},
		]

	func get_block(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= W or y >= H:
			return 18
		return blocks[y * W + x]
