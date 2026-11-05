extends Node2D
## Game scene orchestrator. Wires the world (data, renderer, camp, entities, pickups),
## player, camera, lighting, day/night, music, highlights and UI requests together.

const WD = preload("res://scripts/world/world_data.gd")
const Pickup = preload("res://scripts/mining/pickup.gd")
const DAY_LENGTH := 24.0 * 60.0   # seconds for a full in-game day

@onready var background: Node2D = $BackgroundLayer/Background
@onready var renderer: Node2D = $World/Renderer
@onready var camp: Node2D = $World/Camp
@onready var entities: Node2D = $World/Entities
@onready var pickups_root: Node2D = $World/Pickups
@onready var player: CharacterBody2D = $World/Player
@onready var mining: Node2D = $World/Mining
@onready var effects: Node2D = $World/Effects
@onready var darkness: CanvasModulate = $Darkness
@onready var camera: Camera2D = $Camera
@onready var glow_layer: CanvasLayer = $GlowLayer
@onready var systems: Node = $Systems

var world = null
var ui = null
var _block_colors: Dictionary = {}
var _highlight_t := 0.0
var _scan_ping_t := 0.0
var _full_warn_t := 0.0
var _travelling := false
var _last_area := ""
var _arrow: Sprite2D
var _arrow_target := ""
var _hitstop_t := 0.0
var _dynamites: Array = []

func _ready() -> void:
	GameState.in_game = true
	world = GameState.world
	if world == null:
		# Direct scene run (editor F6 / tests): create a new game synchronously.
		if GameState.inventory.is_empty():
			GameState.new_game()
		world = load("res://scripts/world/world_gen.gd").new().generate(GameState.world_seed)
		GameState.world = world
	# --- world
	var glow_root := Node2D.new()
	glow_layer.add_child(glow_root)
	renderer.setup(world, glow_root)
	camp.build(self)
	entities.build(self, world)
	# --- player
	player.world = world
	player.game = self
	mining.player = player
	mining.world = world
	mining.game = self
	var spawn := Vector2(camp.SPAWN_X, -0.5)
	if GameState.player_pos != Vector2.ZERO and _valid_spot(GameState.player_pos):
		spawn = GameState.player_pos
	player.global_position = spawn
	player.moved_cell.connect(_on_player_cell)
	camera.target = player
	camera.global_position = spawn + Vector2(0, -20)
	camera.reset_smoothing()
	background.camera = camera
	renderer.force_load_around(spawn, get_viewport_rect().size)
	for g in GameState.ground_items:
		spawn_pickup(String(g.id), int(g.n), Vector2(float(g.x), float(g.y)), true)
	GameState.ground_items = []
	# --- UI
	if ResourceLoader.exists("res://scenes/ui/UIRoot.tscn"):
		ui = load("res://scenes/ui/UIRoot.tscn").instantiate()
		add_child(ui)
	# --- tutorial arrow
	_arrow = Sprite2D.new()
	_arrow.texture = ResourceDatabase.tex("res://assets/ui/arrow_bounce.png")
	_arrow.hframes = 4
	_arrow.z_index = 30
	_arrow.visible = false
	var am := CanvasItemMaterial.new()
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_arrow.material = am
	$World.add_child(_arrow)
	for s in systems.get_children():
		if "game" in s:
			s.game = self
	_patch_old_world()
	_setup_mine_entrance()
	_build_world_bounds()
	# --- signals
	Events.elevator_travel_requested.connect(_on_elevator_travel)
	Events.drop_item_requested.connect(_on_drop_item)
	Events.use_item_requested.connect(_on_use_item)
	Events.recall_requested.connect(_recall)
	Events.player_died.connect(_on_player_died)
	Events.level_up.connect(_on_level_up)
	Events.screen_shake.connect(func(s, d): if SaveManager.settings.get("screen_shake", true): camera.shake(s, d))
	Events.inventory_full.connect(func(id): backpack_full_warning(id))
	Events.item_discovered.connect(_on_discovered)
	Events.stats_changed.connect(func(): _highlight_t = 0.0)
	_compute_block_colors()
	GameState.set_depth(WD.depth_m_for_y(player.global_position.y))
	_update_area(true)
	Events.player_health_changed.emit(GameState.hp, GameState.MAX_HP)
	Events.coins_changed.emit(GameState.coins, 0)
	Events.xp_changed.emit(GameState.xp, GameState.xp_needed(), GameState.level)
	Events.skill_points_changed.emit(GameState.skill_points)
	Events.inventory_changed.emit()

func _exit_tree() -> void:
	GameState.in_game = false

func _valid_spot(p: Vector2) -> bool:
	if world == null:
		return false
	var c := WD.cell_of(p + Vector2(0, -8))
	return not world.is_solid(c.x, c.y) and not world.is_solid(c.x, c.y - 1) and p.y > -200.0 and p.y < WD.H * 16

# ================================================================ main loop
func _process(delta: float) -> void:
	if _hitstop_t > 0.0:
		_hitstop_t -= delta / maxf(Engine.time_scale, 0.01)
		if _hitstop_t <= 0.0:
			Engine.time_scale = 1.0
	GameState.play_time += delta
	renderer.update_view(camera.get_screen_center_position(), get_viewport_rect().size / camera.zoom)
	_update_day(delta)
	_update_lighting(delta)
	_highlight_t -= delta
	if _highlight_t <= 0.0:
		_highlight_t = 0.4
		_update_highlights()
	_full_warn_t -= delta
	_update_arrow(delta)
	_update_dynamite(delta)

func _on_player_cell(c: Vector2i) -> void:
	var depth := maxi(0, c.y * 2)
	if depth != GameState.current_depth:
		GameState.set_depth(depth)
	GameState.at_surface = c.y < 1
	if world.reveal(c.x, c.y, int(GameState.stat(&"map_reveal_radius"))):
		pass
	entities.check_chambers(c)
	_update_area(false)

func _update_area(force: bool) -> void:
	var area: String = "surface" if GameState.at_surface or GameState.current_depth < 4 else ResourceDatabase.biome(GameState.current_biome).get("key", "stone")
	if area == _last_area and not force:
		return
	_last_area = area
	if area == "surface":
		AudioManager.play_music("camp")
		AudioManager.play_ambience("surface")
		set_ambient("fireflies" if night_factor() > 0.5 else "dust")
	else:
		var b := ResourceDatabase.biome(GameState.current_biome)
		set_ambient(String(b.get("particles", "dust")))
		AudioManager.play_music(b.get("music", "stone"))
		AudioManager.play_ambience(b.get("ambience", "cave"))

# ================================================================ day / night & lighting
func _update_day(delta: float) -> void:
	var prev := GameState.day_time
	GameState.day_time = fposmod(GameState.day_time + delta / DAY_LENGTH, 1.0)
	if GameState.day_time < prev:
		GameState.day_count += 1
	var h := GameState.day_time * 24.0
	var phase := "night"
	if h >= 5.0 and h < 9.0: phase = "morning"
	elif h >= 9.0 and h < 17.0: phase = "afternoon"
	elif h >= 17.0 and h < 20.0: phase = "evening"
	if phase != GameState.get_meta("day_phase", ""):
		GameState.set_meta("day_phase", phase)
		if _last_area == "surface":
			set_ambient("fireflies" if phase == "night" else "dust")
		Events.day_phase_changed.emit(phase)

func night_factor() -> float:
	var h := GameState.day_time * 24.0
	if h >= 20.5 or h < 5.0:
		return 1.0
	if h >= 17.5:
		return smoothstep(17.5, 20.5, h)
	if h < 7.5:
		return 1.0 - smoothstep(5.0, 7.5, h)
	return 0.0

func _surface_light(n: float) -> Color:
	var h := GameState.day_time * 24.0
	var c := Color(1, 1, 1).lerp(Color(0.36, 0.42, 0.72), n)
	if h > 5.0 and h < 8.0:
		c = c.lerp(Color(1.0, 0.86, 0.72), 0.45 * (1.0 - n))
	elif h > 17.0 and h < 20.0:
		c = c.lerp(Color(1.0, 0.74, 0.62), 0.5 * (1.0 - n))
	return c

func _biome_light(row: int) -> Color:
	var bi := maxi(0, ResourceDatabase.biome_index_for_row(row))
	var b := ResourceDatabase.biome(bi)
	var r0: float = float(b.rows[0])
	var r1: float = float(b.rows[1])
	var t := clampf((row - r0) / maxf(1.0, r1 - r0), 0.0, 1.0)
	var c := Color(String(b.ambient_top)).lerp(Color(String(b.ambient_bottom)), t)
	# blend into the next biome near the border
	if row > r1 - 12 and bi < ResourceDatabase.biomes.size() - 1:
		var nb := ResourceDatabase.biome(bi + 1)
		c = c.lerp(Color(String(nb.ambient_top)), clampf((row - (r1 - 12)) / 16.0, 0.0, 1.0))
	return c

func _update_lighting(delta: float) -> void:
	var n := night_factor()
	var cam_row := int(camera.get_screen_center_position().y / 16.0)
	var surf := _surface_light(n)
	var target: Color
	if cam_row < 2:
		target = surf
	else:
		var under := _biome_light(cam_row)
		target = surf.lerp(under, clampf((cam_row - 2) / 14.0, 0.0, 1.0))
	darkness.color = darkness.color.lerp(target, 1.0 - exp(-3.0 * delta))
	background.day_time = GameState.day_time
	background.night = n
	background.biome_tint = _biome_light(maxi(cam_row, 10))
	camp.set_night(n)
	player.lantern.visible = cam_row > -1 or n > 0.3

# ================================================================ highlights (Cave Sense, scanner, hidden passages, treasure)
func _update_highlights() -> void:
	var hl: Dictionary = {}
	var pc := WD.cell_of(player.global_position + Vector2(0, -12))
	var sense := int(GameState.stat(&"cave_sense_radius"))
	var hidden := int(GameState.stat(&"hidden_passage_radius"))
	var scan := int(GameState.stat(&"scanner_range"))
	var scan_min := int(GameState.stat(&"scanner_min_rarity"))
	var r := maxi(sense, maxi(hidden, scan))
	var scanned_rare := false
	if r > 0:
		for y in range(pc.y - r, pc.y + r + 1):
			for x in range(pc.x - r, pc.x + r + 1):
				var id: int = world.get_block(x, y)
				if id < 40 or id >= 90:
					continue
				var d2 := (x - pc.x) * (x - pc.x) + (y - pc.y) * (y - pc.y)
				if id == ResourceDatabase.CRACKED_WALL:
					if hidden > 0 and d2 <= hidden * hidden:
						hl[Vector2i(x, y)] = Color("e8f4ff")
					continue
				var rar := int(ResourceDatabase.block(id).get("rarity", 0))
				if sense > 0 and d2 <= sense * sense:
					hl[Vector2i(x, y)] = ResourceDatabase.rarity_color(rar)
				elif scan > 0 and d2 <= scan * scan and rar >= scan_min:
					hl[Vector2i(x, y)] = ResourceDatabase.rarity_color(rar)
					scanned_rare = true
	renderer.highlight_cells = hl
	_scan_ping_t -= 0.4
	if scanned_rare and _scan_ping_t <= 0.0:
		_scan_ping_t = 12.0
		AudioManager.play("notify", -8.0)
		Events.notify.emit("Scanner: valuable deposit nearby!", "rare")
	# Treasure Finder: sparkle nearby unopened chests
	var tr := int(GameState.stat(&"treasure_radius"))
	if tr > 0:
		for c in entities.chests:
			var e: Dictionary = c.e
			if GameState.opened.get("%d,%d" % [int(e.x), int(e.y)], false):
				continue
			if Vector2(int(e.x) - pc.x, int(e.y) - pc.y).length() <= tr:
				effects.sparkle_burst(c.s.global_position, Color("ffd35a"))

# ================================================================ tutorial arrow
func point_arrow_at(name: String) -> void:
	_arrow_target = name

func _arrow_pos() -> Variant:
	if _arrow_target == "":
		return null
	if camp.targets.has(_arrow_target):
		return camp.targets[_arrow_target]
	if world.markers.has(_arrow_target):
		var m: Vector2i = world.markers[_arrow_target]
		return WD.cell_center(m) + Vector2(0, -18)
	return null

func _update_arrow(delta: float) -> void:
	var p: Variant = _arrow_pos()
	_arrow.visible = p != null
	if p != null:
		var t := GameState.play_time
		_arrow.global_position = (p as Vector2) + Vector2(0, sin(t * 5.0) * 3.0 - 6.0)
		_arrow.frame = int(t * 8.0) % 4

# ================================================================ pickups
func spawn_pickup(id: String, n: int, pos: Vector2, resting: bool = false) -> void:
	if n <= 0:
		return
	# split big stacks into a few visible drops for a nicer burst
	var parts := mini(n, 4)
	var per := n / parts
	var rem := n - per * parts
	for i in parts:
		var p := Pickup.new()
		var amt := per + (1 if i < rem else 0)
		var toward := signf(player.global_position.x - pos.x) if player else 0.0
		var v := Vector2(randf_range(-55, 55) + toward * 55.0, randf_range(-170, -95)) if not resting else Vector2.ZERO
		p.setup(id, amt, pos + Vector2(randf_range(-3, 3), 0), v)
		p.world = world
		p.player = player
		p.game = self
		pickups_root.add_child(p)

func pickups_changed(_p, _collected: bool) -> void:
	pass

func backpack_full_warning(id: String) -> void:
	if _full_warn_t > 0.0:
		return
	_full_warn_t = 6.0
	Events.notify.emit("Backpack full! Return to the surface to store or sell.", "warn")
	AudioManager.play("ui_error", -6.0)

func collect_ground_items() -> Array:
	var out: Array = []
	for p in pickups_root.get_children():
		if p.has_method("to_dict"):
			out.append(p.to_dict())
	return out

# ================================================================ requests
func _on_drop_item(id: String, n: int) -> void:
	# The UI has already removed the items from the backpack.
	var removed := n
	if removed <= 0:
		return
	var p := Pickup.new()
	p.setup(id, removed, player.global_position + Vector2(player.facing * 14, -18), Vector2(player.facing * 90, -80))
	p.world = world
	p.player = player
	p.game = self
	p._refuse_t = 2.0
	pickups_root.add_child(p)

func _on_use_item(id: String) -> void:
	match id:
		"recall_flare":
			if GameState.at_surface:
				Events.notify.emit("You're already at the camp.", "info")
				return
			if GameState.remove_item("recall_flare", 1) > 0:
				AudioManager.play("fuse", -4.0)
				effects.sparkle_burst(player.global_position + Vector2(0, -16), Color("ff7a5a"))
				_recall()
		"health_potion":
			if GameState.hp < GameState.MAX_HP and GameState.remove_item("health_potion", 1) > 0:
				GameState.heal(50.0)
				AudioManager.play("pickup_rare", -4.0)
		"ladder", "torch", "dynamite":
			GameState.hotbar_index = GameState.HOTBAR.find(id)
			Events.hotbar_changed.emit()
			Events.notify.emit("Selected %s. Right-click to use." % ResourceDatabase.item_name(id), "info")

func _recall() -> void:
	await _teleport(Vector2(camp.SPAWN_X, -0.5), "Back at camp!")

func _on_elevator_travel(idx: int) -> void:
	if _travelling or idx < 0 or idx >= GameState.stations.size() or not GameState.stations[idx]:
		return
	var from_idx := -1
	for k in entities.stations:
		if entities.station_position(k).distance_to(player.global_position) < 60.0:
			from_idx = k
	if from_idx >= 0:
		entities.animate_doors(from_idx, false)
	AudioManager.play("elevator_move", -2.0)
	var dest: Vector2 = entities.station_position(idx)
	if idx == 0:
		dest = Vector2(camp.ELEVATOR_X + 4, -0.5)
	await _teleport(dest, "", 0.55)
	entities.animate_doors(idx, true)
	AudioManager.play("elevator_ding", -2.0)
	Events.elevator_used.emit(idx)
	GameState.add_counter("elevator", 1)
	var st: Dictionary = ResourceDatabase.stations[idx]
	Events.notify.emit("%s  (%dm)" % [st.name, st.depth], "info")

func _teleport(dest: Vector2, msg: String, extra: float = 0.0) -> void:
	_travelling = true
	player.input_enabled = false
	if ui and ui.has_method("close_panel"):
		ui.close_panel()
	if ui and ui.has_method("fade_out"):
		await ui.fade_out(0.35)
	player.global_position = dest
	player.velocity = Vector2.ZERO
	renderer.force_load_around(dest, get_viewport_rect().size)
	camera.global_position = dest + Vector2(0, -20)
	camera.reset_smoothing()
	_on_player_cell(WD.cell_of(dest + Vector2(0, -8)))
	if extra > 0.0:
		await get_tree().create_timer(extra).timeout
	if ui and ui.has_method("fade_in"):
		await ui.fade_in(0.35)
	player.input_enabled = true
	_travelling = false
	if msg != "":
		Events.notify.emit(msg, "good")
	SaveManager.save_game()

func _on_player_died() -> void:
	Events.notify.emit("You passed out! Mara carried you back to camp.", "warn")
	AudioManager.play("hurt", 0.0)
	await _teleport(Vector2(camp.SPAWN_X, -0.5), "")
	GameState.heal(GameState.MAX_HP)

func _on_level_up(lvl: int) -> void:
	effects.level_up(player.global_position + Vector2(0, -20))
	camera.shake(1.5, 0.2)
	Events.notify.emit("Level %d! +1 Skill Point" % lvl, "legendary")

func _on_discovered(id: String) -> void:
	var r := ResourceDatabase.item_rarity(id)
	Events.notify.emit("New discovery: %s!" % ResourceDatabase.item_name(id), ["good", "good", "rare", "epic", "legendary"][clampi(r, 0, 4)])
	if r >= 3:
		hitstop(0.08)
		camera.shake(2.0, 0.25)

# ================================================================ dynamite
func throw_dynamite(from: Vector2, vel: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.item_icon("dynamite")
	s.global_position = from
	s.z_index = 6
	$World.add_child(s)
	_dynamites.append({"s": s, "v": vel, "t": 1.4})
	AudioManager.play("fuse", -4.0)

func _update_dynamite(delta: float) -> void:
	for d in _dynamites.duplicate():
		var s: Sprite2D = d.s
		d.v.y = minf(d.v.y + 600.0 * delta, 400.0)
		var np: Vector2 = s.global_position + d.v * delta
		if world.is_solid_at_pos(np):
			d.v = -d.v * 0.3
		else:
			s.global_position = np
		s.rotation += delta * 8.0
		d.t -= delta
		if int(d.t * 10) % 2 == 0:
			effects.sparks(s.global_position + Vector2(0, -5), Color("ffcf6a"))
		if d.t <= 0.0:
			var pos := s.global_position
			s.queue_free()
			_dynamites.erase(d)
			effects.explosion(pos)
			AudioManager.play("explosion", 0.0)
			camera.shake(6.0, 0.4)
			mining.explode_at(pos)

# ================================================================ helpers
func hitstop(t: float) -> void:
	_hitstop_t = t
	Engine.time_scale = 0.05

func block_color(id: int, row: int) -> Color:
	var b := ResourceDatabase.block(id)
	if b.has("glow"):
		return Color(String(b.glow))
	var key := id if b.has("material") else -row / 50 - 1000
	if _block_colors.has(key):
		return _block_colors[key]
	var mat := int(b.get("material", ResourceDatabase.block(world.base_block_for_row(row)).get("material", 2)))
	return _block_colors.get("mat%d" % mat, Color(0.6, 0.55, 0.5))

func _compute_block_colors() -> void:
	var tex: Texture2D = ResourceDatabase.tex("res://assets/tilesets/terrain.png")
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	for mat in int(img.get_height() / 32):
		var acc := Color(0, 0, 0, 0)
		var n := 0
		for i in 12:
			var px := 2 + (i * 5) % 12
			var py := mat * 32 + 3 + (i * 7) % 10
			if px < img.get_width() and py < img.get_height():
				acc += img.get_pixel(px, py)
				n += 1
		if n > 0:
			_block_colors["mat%d" % mat] = Color(acc.r / n, acc.g / n, acc.b / n).lightened(0.15)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if is_inside_tree() and pickups_root:
			GameState.ground_items = collect_ground_items()
			GameState.player_pos = player.global_position

func prepare_save() -> void:
	GameState.ground_items = collect_ground_items()
	GameState.player_pos = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if GameState.ui_blocking:
		return
	for i in 6:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_hotbar(i)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_hotbar((GameState.hotbar_index + 1) % 6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_hotbar((GameState.hotbar_index + 5) % 6)
	if event.is_action_pressed("toggle_fullscreen"):
		SaveManager.set_setting("fullscreen", not SaveManager.settings.get("fullscreen", false))

func _select_hotbar(i: int) -> void:
	if GameState.hotbar_index == i:
		return
	GameState.hotbar_index = i
	AudioManager.play("ui_hover", -10.0)
	Events.hotbar_changed.emit()

# ================================================================ screenshot/test hook
## Used by tools/capture.sh: args[0] = biome key (stone, iron, crystal, frozen, magma, ancient) or "surface",
## optional args[1] = "night" / "mine" / "skills" / "inventory".
func _capture_setup(args: Array) -> void:
	GameState.tutorial["done"] = true
	GameState.tutorial["step"] = 99
	if ui and ui.has_method("set_tutorial_objective"):
		ui.set_tutorial_objective("", "", "")
	var where: String = args[0] if args.size() > 0 else "surface"
	var extra: String = args[1] if args.size() > 1 else ""
	GameState.coins = 12450
	GameState.level = 5
	GameState.xp = 120
	GameState.skill_points = 3
	for id in ["copper_pickaxe", "iron_pickaxe", "steel_pickaxe", "crystal_pickaxe", "diamond_drill", "plasma_tool", "lantern_crystal", "boots_thermal"]:
		GameState.owned[id] = true
	GameState.equip_item("lantern_crystal")
	GameState.equip_item("boots_thermal")
	GameState.equip_item("plasma_tool" if where in ["magma", "ancient"] else "steel_pickaxe")
	GameState.add_item("stone", 24)
	GameState.add_item("health_potion", 3)
	GameState.add_item("dynamite", 5)
	if extra == "night":
		GameState.day_time = 0.9
	var bi := -1
	for b in ResourceDatabase.biomes:
		if b.key == where:
			bi = int(b.index)
	if where == "water":
		for y in range(20, 150):
			for x in range(20, WD.W - 20):
				if world.get_block(x, y) == ResourceDatabase.WATER and world.get_block(x, y - 1) == 0:
					var sx := -1
					for dx in range(1, 10):
						for cx in [x - dx, x + dx]:
							if sx < 0 and world.get_block(cx, y - 1) == 0 and world.get_block(cx, y - 2) == 0 and world.is_solid(cx, y):
								sx = cx
					var wp := Vector2(sx * 16 + 8, y * 16 - 0.5)
					if sx >= 0:
						player.global_position = wp
						renderer.force_load_around(wp, get_viewport_rect().size)
						camera.global_position = wp + Vector2(0, -30)
						_on_player_cell(WD.cell_of(wp + Vector2(0, -8)))
						return
	if bi >= 0:
		var b := ResourceDatabase.biome(bi)
		var mid := (int(b.rows[0]) + int(b.rows[1])) / 2
		var spot := Vector2i(-1, -1)
		for dy in range(0, 120):
			for sgn: int in [1, -1]:
				var y: int = mid + dy * sgn
				for x in range(30, WD.W - 30, 3):
					if world.get_block(x, y) == 0 and world.get_block(x, y - 1) == 0 and world.get_block(x, y - 2) == 0 and world.get_block(x + 1, y) == 0 and world.is_solid(x, y + 1) and world.is_solid(x + 1, y + 1):
						spot = Vector2i(x, y)
						break
				if spot.x >= 0: break
			if spot.x >= 0: break
		var pos := Vector2(spot.x * 16 + 8, (spot.y + 1) * 16 - 0.5)
		player.global_position = pos
		renderer.force_load_around(pos, get_viewport_rect().size)
		camera.global_position = pos + Vector2(0, -30)
		_on_player_cell(WD.cell_of(pos + Vector2(0, -8)))
	Events.coins_changed.emit(GameState.coins, 0)
	Events.xp_changed.emit(GameState.xp, GameState.xp_needed(), GameState.level)
	Events.skill_points_changed.emit(GameState.skill_points)
	if extra in ["skills", "inventory", "shop", "map", "journal", "storage"]:
		await get_tree().create_timer(0.3).timeout
		Events.open_panel_requested.emit(extra, null)

# ================================================================ ambient particles (per biome)
var _ambient: CPUParticles2D
var _ambient_kind := ""

func _ensure_ambient() -> void:
	if _ambient:
		return
	_ambient = CPUParticles2D.new()
	_ambient.local_coords = false
	_ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ambient.emission_rect_extents = Vector2(380, 230)
	_ambient.z_index = 7
	_ambient.preprocess = 4.0
	var at := AtlasTexture.new()
	at.atlas = ResourceDatabase.tex("res://assets/sprites/effects/particles.png")
	at.region = Rect2(32, 0, 8, 8)
	_ambient.texture = at
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	_ambient.color_ramp = ramp
	camera.add_child(_ambient)

func set_ambient(kind: String) -> void:
	_ensure_ambient()
	if kind == _ambient_kind:
		return
	_ambient_kind = kind
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var p := _ambient
	p.material = null
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	match kind:
		"snow":
			p.amount = 80
			p.lifetime = 9.0
			p.direction = Vector2(0.25, 1)
			p.spread = 20.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 24.0
			p.gravity = Vector2(3, 10)
			p.color = Color(0.92, 0.97, 1.0, 0.85)
			p.scale_amount_max = 0.9
		"ember":
			p.amount = 50
			p.lifetime = 5.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 18.0
			p.gravity = Vector2(0, -12)
			p.color = Color(1.0, 0.55, 0.2, 0.9)
			p.material = glow
		"sparkle":
			p.amount = 46
			p.lifetime = 3.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 5.0
			p.color = Color(0.55, 0.85, 1.0, 0.9)
			p.material = glow
		"glyph":
			p.amount = 34
			p.lifetime = 5.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 7.0
			p.gravity = Vector2(0, -4)
			p.color = Color(0.3, 0.95, 0.82, 0.8)
			p.material = glow
		"fireflies":
			p.amount = 26
			p.lifetime = 4.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 10.0
			p.color = Color(0.85, 1.0, 0.45, 0.9)
			p.material = glow
		_:
			p.amount = 36
			p.lifetime = 7.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 6.0
			p.gravity = Vector2(1, 2)
			p.color = Color(0.92, 0.86, 0.74, 0.32)
	p.restart()
	p.emitting = true

# ================================================================ mine entrance cutscenes
const Interactable = preload("res://scripts/world/interactable.gd")
var _letterbox: CanvasLayer
var _exit_door: Area2D

func _setup_mine_entrance() -> void:
	# "Exit to Surface" doorway inside the timbered entrance hall.
	if not world.markers.has("mine_inside"):
		return
	var inside: Vector2i = world.markers["mine_inside"]
	_exit_door = Interactable.new()
	_exit_door.setup("Exit to Surface", Vector2(26, 34), Vector2.ZERO, func(_p): exit_mine())
	_exit_door.position = WD.cell_center(inside) + Vector2(-16, -8)
	$World.add_child(_exit_door)

func _set_letterbox(on: bool) -> void:
	if _letterbox == null:
		_letterbox = CanvasLayer.new()
		_letterbox.layer = 11
		for i in 2:
			var bar := ColorRect.new()
			bar.color = Color(0.01, 0.01, 0.03, 1.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
			bar.custom_minimum_size = Vector2(0, 30)
			bar.size = Vector2(get_viewport_rect().size.x, 30)
			bar.position = Vector2(0, -30) if i == 0 else Vector2(0, get_viewport_rect().size.y)
			_letterbox.add_child(bar)
		add_child(_letterbox)
	var vp := get_viewport_rect().size
	var top: ColorRect = _letterbox.get_child(0)
	var bot: ColorRect = _letterbox.get_child(1)
	top.size.x = vp.x
	bot.size.x = vp.x
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(top, "position:y", 0.0 if on else -30.0, 0.45)
	tw.tween_property(bot, "position:y", vp.y - 30.0 if on else vp.y, 0.45)
	if ui and ui.get("hud"):
		create_tween().tween_property(ui.hud, "modulate:a", 0.0 if on else 1.0, 0.35)
	await tw.finished

func _show_area_title(title: String, sub: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(get_viewport_rect().size.x * 0.5 - 150, 62)
	box.size = Vector2(300, 40)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"LabelTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color("ffd35a"))
	box.add_child(t)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	box.add_child(s)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)

## Walk into the MINE portal, fade, appear in the entrance hall and walk to the first blocks.
func enter_mine() -> void:
	if _travelling or not world.markers.has("mine_inside"):
		return
	_travelling = true
	player.input_enabled = false
	if ui and ui.has_method("close_panel"):
		ui.close_panel()
	if ui and ui.has_method("hide_prompt"):
		ui.hide_prompt()
	await _set_letterbox(true)
	await player.walk_to(camp.ENTRANCE_X, 4.0)
	# step into the dark doorway: the miner shrinks and darkens as he walks into the tunnel
	player.facing = 1
	AudioManager.play("step", -8.0)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "depth_scale", 0.72, 0.9)
	tw.tween_property(player.visual, "modulate", Color(0.18, 0.16, 0.24, 1.0), 0.9)
	tw.tween_property(player, "global_position:y", player.global_position.y - 5.0, 0.9)
	await tw.finished
	if ui and ui.has_method("fade_out"):
		await ui.fade_out(0.45)
	# inside the mine
	var inside: Vector2i = world.markers["mine_inside"]
	var pos := Vector2(inside.x * 16 + 8, (inside.y + 1) * 16 - 0.5)
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.depth_scale = 1.0
	player.visual.modulate = Color.WHITE
	player.facing = 1
	renderer.force_load_around(pos, get_viewport_rect().size)
	camera.global_position = pos + Vector2(40, -30)
	camera.reset_smoothing()
	_on_player_cell(WD.cell_of(pos + Vector2(0, -8)))
	AudioManager.play("ladder", -6.0)
	if ui and ui.has_method("fade_in"):
		await ui.fade_in(0.6)
	_show_area_title("Stone Caverns", "The Mine Entrance  •  20m")
	var first_x := float(world.markers.get("tutorial_stone", Vector2i(106, 9)).x * 16) - 10.0
	await player.walk_to(first_x, 6.0)
	await _set_letterbox(false)
	player.input_enabled = true
	_travelling = false
	Events.mine_entered.emit()
	SaveManager.save_game()

## Leave through the entrance hall doorway and walk out of the MINE portal on the surface.
func exit_mine() -> void:
	if _travelling:
		return
	_travelling = true
	player.input_enabled = false
	if ui and ui.has_method("hide_prompt"):
		ui.hide_prompt()
	await _set_letterbox(true)
	if ui and ui.has_method("fade_out"):
		await ui.fade_out(0.45)
	var pos := Vector2(camp.ENTRANCE_X, -0.5)
	player.global_position = pos + Vector2(0, -5)
	player.velocity = Vector2.ZERO
	player.depth_scale = 0.72
	player.visual.modulate = Color(0.18, 0.16, 0.24, 1.0)
	player.facing = -1
	renderer.force_load_around(pos, get_viewport_rect().size)
	camera.global_position = pos + Vector2(-30, -30)
	camera.reset_smoothing()
	_on_player_cell(WD.cell_of(pos + Vector2(0, -8)))
	if ui and ui.has_method("fade_in"):
		await ui.fade_in(0.5)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "depth_scale", 1.0, 0.8)
	tw.tween_property(player.visual, "modulate", Color.WHITE, 0.8)
	await player.walk_to(camp.ENTRANCE_X - 44.0, 4.0)
	await _set_letterbox(false)
	player.input_enabled = true
	_travelling = false
	Events.mine_exited.emit()
	SaveManager.save_game()

# ================================================================ world edge walls
func _build_world_bounds() -> void:
	## Invisible walls at the left/right edges of the world (sky to bedrock) so nobody can walk off.
	var body := StaticBody2D.new()
	body.name = "WorldBounds"
	body.collision_layer = 1
	body.collision_mask = 0
	var h := float(WD.H * 16 + 4000)
	for side in [-1, 1]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(64, h)
		cs.shape = rs
		var x := -32.0 + 16.0 if side < 0 else float(WD.W * 16) + 32.0 - 16.0
		cs.position = Vector2(x, h * 0.5 - 2000.0)
		body.add_child(cs)
	$World.add_child(body)

func _patch_old_world() -> void:
	## Saves made before v1.1 had an open staircase pit under the MINE portal: seal it.
	if world.markers.has("mine_inside"):
		return
	for x in range(WD.ENTRANCE_X - 3, WD.ENTRANCE_X + 4):
		world.set_block(x, 0, ResourceDatabase.GRASS)
		for y in range(1, 4):
			if world.get_block(x, y) == ResourceDatabase.AIR:
				world.set_block(x, y, ResourceDatabase.DIRT)
	world.markers["mine_inside"] = Vector2i(WD.SHAFT_X1 + 3, 9)
	world.set_decor(WD.SHAFT_X1 + 2, 9, 34)
