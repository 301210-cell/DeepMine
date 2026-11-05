extends Node2D
## Builds and runs world entities from WorldData.entities: elevator stations, treasure chests,
## rideable mine carts, abandoned loot carts and special chambers (discovery triggers).

const WD = preload("res://scripts/world/world_data.gd")
const Interactable = preload("res://scripts/world/interactable.gd")
const Loot = preload("res://scripts/progression/loot.gd")

var game = null
var world = null
var stations: Dictionary = {}   # index -> Sprite2D cage
var chests: Array = []          # [{"e": dict, "s": Sprite2D}]
var carts: Array = []
var chambers: Array = []
var _light_tex: Texture2D

func build(p_game, p_world) -> void:
	game = p_game
	world = p_world
	_light_tex = load("res://scripts/world/world_renderer.gd").make_radial_texture(128, 0.0)
	for e in world.entities:
		add_entity(e)

func add_entity(e: Dictionary) -> void:
	match e.type:
		"station": _make_station(e)
		"chest": _make_chest(e)
		"cart": _make_cart(e)
		"loot_cart": _make_loot_cart(e)
		"chamber": chambers.append(e)

func _key(e: Dictionary) -> String:
	return "%d,%d" % [int(e.x), int(e.y)]

# ---------------------------------------------------------------- stations
func _make_station(e: Dictionary) -> void:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex("res://assets/sprites/world/elevator.png")
	s.hframes = 5
	var floor_y := (int(e.y) + 1) * 16.0
	s.position = Vector2(WD.SHAFT_X0 * 16 + 24, floor_y - 32)
	s.z_index = 0
	add_child(s)
	var idx := int(e.index)
	var ia := Interactable.new()
	ia.setup("Ride Elevator", Vector2(48, 60), Vector2(0, 0), func(_p): Events.open_panel_requested.emit("elevator", {"current": idx}))
	s.add_child(ia)
	stations[idx] = s
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = 0.8
	l.color = Color("ffd8a0")
	l.energy = 0.7
	l.position = Vector2(0, -26)
	s.add_child(l)

func station_position(idx: int) -> Vector2:
	## Where the player stands after arriving (just right of the cage, on the floor).
	var s: Sprite2D = stations.get(idx)
	if s == null:
		return Vector2.ZERO
	return Vector2(s.position.x + 38, s.position.y + 32 - 0.5)

func animate_doors(idx: int, opening: bool) -> void:
	var s: Sprite2D = stations.get(idx)
	if s == null:
		return
	var tw := s.create_tween()
	var frames := [0, 1, 2, 3, 4] if opening else [4, 3, 2, 1, 0]
	for f in frames:
		tw.tween_callback(func(): s.frame = f)
		tw.tween_interval(0.07)

# ---------------------------------------------------------------- chests
func _make_chest(e: Dictionary) -> void:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex("res://assets/sprites/world/chest.png")
	s.hframes = 4
	var opened: bool = GameState.opened.get(_key(e), false)
	s.frame = 2 if opened else (3 if e.get("gold", false) else 0)
	s.position = Vector2(int(e.x) * 16 + 8, (int(e.y) + 1) * 16 - 8)
	s.z_index = 1
	add_child(s)
	var ia := Interactable.new()
	ia.setup("Open Chest", Vector2(20, 18), Vector2.ZERO, func(_p): _open_chest(e, s, ia))
	ia.enabled = not opened
	s.add_child(ia)
	if e.get("gold", false) and not opened:
		var l := PointLight2D.new()
		l.texture = _light_tex
		l.texture_scale = 0.5
		l.color = Color("ffd35a")
		l.energy = 0.6
		s.add_child(l)
	chests.append({"e": e, "s": s})

func _open_chest(e: Dictionary, s: Sprite2D, ia: Area2D) -> void:
	var k := _key(e)
	if GameState.opened.get(k, false):
		return
	GameState.opened[k] = true
	ia.enabled = false
	AudioManager.play("chest_open", -2.0)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.2, 0.8), 0.08)
	tw.tween_callback(func(): s.frame = 1)
	tw.tween_property(s, "scale", Vector2(0.9, 1.15), 0.08)
	tw.tween_callback(func(): s.frame = 2)
	tw.tween_property(s, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var bi := clampi(int(e.get("biome", 0)), 0, 5)
	var table: Dictionary = ResourceDatabase.loot.get("chests", [])[bi]
	var luck := GameState.skill_bonus("treasure_loot_pct") / 100.0
	var res := Loot.roll(table, int(e.y) * 2, luck)
	if e.get("gold", false):
		var extra := Loot.roll(table, int(e.y) * 2, luck + 0.3)
		res.items.append_array(extra.items)
		res.coins = int(res.coins) + int(extra.coins)
	if e.get("heart", false):
		res.items.append(["artifact_core", 1])
		res.items.append(["star_crystal", 2])
	var pos := s.global_position + Vector2(0, -10)
	for pair in res.items:
		game.spawn_pickup(pair[0], int(pair[1]), pos)
	if int(res.coins) > 0:
		GameState.add_coins(int(res.coins))
		Events.float_text.emit(pos + Vector2(0, -12), "+$%s" % ResourceDatabase.fmt_num(int(res.coins)), Color("ffd35a"))
		AudioManager.play("coin", -4.0)
	game.effects.sparkle_burst(pos, Color("ffd35a"))
	GameState.add_counter("find_cache", 1)
	GameState.add_xp(30.0 * (bi + 1) * (1.0 + GameState.skill_bonus("explore_xp_pct") / 100.0))
	Events.cache_found.emit(Vector2i(int(e.x), int(e.y)))
	Events.notify.emit("Hidden cache found!" if not e.has("chamber") else "%s treasure!" % e.chamber, "rare")

# ---------------------------------------------------------------- rideable carts
func _make_cart(e: Dictionary) -> void:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex("res://assets/sprites/world/minecart.png")
	s.hframes = 3
	var at_x0: bool = e.get("at", 0) == 0
	var cx := int(e.x0) if at_x0 else int(e.x1)
	s.position = Vector2(cx * 16 + 8, (int(e.y) + 1) * 16 - 12)
	s.z_index = 2
	add_child(s)
	var ia := Interactable.new()
	ia.setup("Ride Mine Cart", Vector2(32, 26), Vector2.ZERO, func(p): _ride_cart(e, s, ia, p))
	s.add_child(ia)
	carts.append({"e": e, "s": s})

func _ride_cart(e: Dictionary, s: Sprite2D, ia: Area2D, player) -> void:
	if player.riding:
		return
	var at_x0: bool = int(e.get("at", 0)) == 0
	var dest_cell := int(e.x1) if at_x0 else int(e.x0)
	var dest := Vector2(dest_cell * 16 + 8, s.position.y)
	ia.enabled = false
	player.set_riding(true)
	player.global_position = s.global_position + Vector2(0, -2)
	var dist := absf(dest.x - s.position.x)
	var dur := dist / 260.0
	AudioManager.play("minecart", -4.0)
	var tw := create_tween()
	tw.tween_property(s, "position", dest, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t_frames := create_tween().set_loops(int(dur / 0.1) + 1)
	t_frames.tween_callback(func(): s.frame = 1 if s.frame != 1 else 2)
	t_frames.tween_interval(0.1)
	var follow := func(_v):
		player.global_position = s.global_position + Vector2(0, -2)
		player.facing = 1 if dest.x > s.position.x else -1
	tw.parallel().tween_method(follow, 0.0, 1.0, dur)
	tw.tween_callback(func():
		s.frame = 0
		t_frames.kill()
		e["at"] = 1 if at_x0 else 0
		player.global_position = s.global_position + Vector2(-20 if at_x0 else 20, -2)
		player.set_riding(false)
		ia.enabled = true
		GameState.add_counter("cart_ride", 1)
		Events.cart_ridden.emit()
		game.effects.dust(s.global_position + Vector2(0, 10), 8))

# ---------------------------------------------------------------- abandoned loot carts
func _make_loot_cart(e: Dictionary) -> void:
	var opened: bool = GameState.opened.get(_key(e), false)
	if opened and not e.get("event", false):
		var s0 := Sprite2D.new()
		s0.texture = ResourceDatabase.tex("res://assets/sprites/world/minecart.png")
		s0.hframes = 3
		s0.position = Vector2(int(e.x) * 16 + 16, (int(e.y) + 1) * 16 - 12)
		add_child(s0)
		return
	if opened:
		return
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex("res://assets/sprites/world/minecart_loot.png")
	s.position = Vector2(int(e.x) * 16 + 16, (int(e.y) + 1) * 16 - 12)
	s.z_index = 2
	add_child(s)
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = 0.7
	l.color = Color("c89aff")
	l.energy = 0.8
	s.add_child(l)
	var ia := Interactable.new()
	ia.setup("Search Abandoned Cart", Vector2(32, 26), Vector2.ZERO, func(_p): _loot_cart(e, s, ia))
	s.add_child(ia)
	e["_node"] = s

func _loot_cart(e: Dictionary, s: Sprite2D, ia: Area2D) -> void:
	var k := _key(e)
	if GameState.opened.get(k, false):
		return
	GameState.opened[k] = true
	ia.enabled = false
	var bi := clampi(int(e.get("biome", 0)), 0, 5)
	var table: Dictionary = ResourceDatabase.loot.get("chests", [])[bi]
	var res := Loot.roll(table, int(e.y) * 2, 0.4 + GameState.skill_bonus("treasure_loot_pct") / 100.0)
	res.items.append([["geode_small", "geode_iron", "geode_rare", "geode_ice", "geode_magma", "geode_legendary"][bi], 1])
	var pos := s.global_position + Vector2(0, -12)
	for pair in res.items:
		game.spawn_pickup(pair[0], int(pair[1]), pos)
	GameState.add_coins(int(res.coins))
	AudioManager.play("chest_open", -2.0)
	game.effects.sparkle_burst(pos, Color("c89aff"))
	GameState.add_counter("loot_cart", 1)
	Events.loot_cart_found.emit()
	Events.notify.emit("You looted the abandoned cart!", "rare")
	var tw := s.create_tween()
	tw.tween_property(s, "modulate", Color(0.6, 0.6, 0.6), 0.6)

# ---------------------------------------------------------------- chambers
func check_chambers(player_cell: Vector2i) -> void:
	for c in chambers:
		var n: String = c.name
		if GameState.chambers.get(n, false):
			continue
		var d := Vector2(player_cell.x - int(c.x), player_cell.y - int(c.y)).length()
		if d <= float(c.r):
			GameState.chambers[n] = true
			GameState.add_counter("chambers", 1)
			var xp: float = 120.0 * (1 + world.biome_at_row(int(c.y))) * (1.0 + GameState.skill_bonus("explore_xp_pct") / 100.0)
			GameState.add_xp(xp)
			Events.chamber_discovered.emit(n)
			Events.notify.emit("Discovered: %s!" % n, "epic")
			AudioManager.play("rare_discovery", -2.0)
