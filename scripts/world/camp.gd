extends Node2D
## The surface mining camp: buildings, Mara, machines, lamps, props and the mine entrance.
## Ground line is y = 0. The camp grows (more props/lamps/flags) as the player levels up.

const Interactable = preload("res://scripts/world/interactable.gd")
const MachineNode = preload("res://scripts/machines/machine_node.gd")
const WD = preload("res://scripts/world/world_data.gd")

const ELEVATOR_X := 1464.0
const ENTRANCE_X := 1576.0
const MARA_X := 930.0
const SPAWN_X := 990.0

## building id -> [texture, center x, frames, interact prompt, action]
var game = null
var targets: Dictionary = {}      # highlight name -> world position (for tutorial arrows)
var mara: Sprite2D
var mara_bubble: Label
var _mara_t := 0.0
var _lamps: Array[PointLight2D] = []
var _fire_lights: Array[PointLight2D] = []
var _anim_sprites: Array = []     # [Sprite2D, frames, fps, offset_frame]
var _t := 0.0
var _growth: Array = []           # [Node2D, required_level]
var _skill_board: Sprite2D
var _font: Font

func build(p_game) -> void:
	game = p_game
	_font = load("res://assets/fonts/pixel.fnt") if ResourceLoader.exists("res://assets/fonts/pixel.fnt") else null
	var light_tex: Texture2D = load("res://scripts/world/world_renderer.gd").make_radial_texture(256, 0.0)

	# --- scenery behind buildings (trees, fences)
	for x in [40.0, 200.0, 1720.0, 1800.0, 1900.0, 2050.0, 2240.0, 2400.0, 2600.0, 2780.0, 2950.0]:
		_tree(x)
	for x in range(1700, 3060, 90):
		_prop(17 if (x / 90) % 5 == 0 else (9 if (x / 90) % 3 == 0 else 8), float(x) + 30.0, 0)
	# --- buildings
	_building("mara_tent", "res://assets/sprites/world/mara_tent.png", 860.0, 1, "", Callable())
	_building("shop", "res://assets/sprites/world/shop.png", 1360.0, 1, "Open Shop", func(_p): Events.open_panel_requested.emit("shop", null))
	_building("storage", "res://assets/sprites/world/storage.png", 1250.0, 1, "Open Storage", func(_p): Events.open_panel_requested.emit("storage", null))
	_skill_board = _building("skill_board", "res://assets/sprites/world/skill_board.png", 1020.0, 2, "Open Skill Tree", func(_p): Events.open_panel_requested.emit("skills", null))
	_building("mining_board", "res://assets/sprites/world/mining_board.png", 770.0, 1, "Read Mining Board", func(_p): Events.open_panel_requested.emit("journal", "quests"))
	_building("museum", "res://assets/sprites/world/museum.png", 680.0, 1, "Mineral Collection", func(_p): Events.open_panel_requested.emit("journal", "collection"))
	# Mine entrance (decorative portal over the stair opening)
	var ent := _sprite("res://assets/sprites/world/mine_entrance.png", Vector2(ENTRANCE_X, 0), 1)
	ent.z_index = 1
	targets["entrance"] = Vector2(ENTRANCE_X, -40)
	_lamp(ENTRANCE_X - 40, -60, light_tex, Color("ffc070"), 0.8)
	_lamp(ENTRANCE_X + 40, -60, light_tex, Color("ffc070"), 0.8)
	# Elevator (surface station) with winch housing
	var top := _sprite("res://assets/sprites/world/elevator_top.png", Vector2(ELEVATOR_X, -64), 1)
	top.z_index = 1
	targets["elevator_0"] = Vector2(ELEVATOR_X, -40)

	# --- machines: smelter + crusher near storage, the rest on pads to the left
	var machine_x := {"smelter": 1160.0, "crusher": 1090.0, "gem_polisher": 590.0, "auto_drill": 515.0, "ore_sorter": 440.0,
		"advanced_smelter": 365.0, "crystal_extractor": 290.0, "mining_robot": 215.0, "deep_core_drill": 140.0}
	for mid in ResourceDatabase.machine_order:
		var mn := MachineNode.new()
		mn.setup(mid, game)
		mn.position = Vector2(machine_x.get(mid, 100.0), 0)
		add_child(mn)
		targets[mid] = Vector2(mn.position.x, -60)

	# --- Mara
	mara = Sprite2D.new()
	mara.texture = ResourceDatabase.tex("res://assets/sprites/player/mara.png")
	mara.hframes = 4
	mara.vframes = 3
	mara.position = Vector2(MARA_X, -24)
	mara.z_index = 2
	add_child(mara)
	var ia := Interactable.new()
	ia.setup("Talk to Mara", Vector2(30, 44), Vector2(0, 0), func(_p): _mara_talk())
	mara.add_child(ia)
	targets["mara"] = Vector2(MARA_X, -56)
	# campfire
	var fire := _anim_prop(0, 4, 10.0, Vector2(MARA_X + 34, 0))
	var fl := _lamp(MARA_X + 34, -10, light_tex, Color("ff9040"), 0.9)
	_fire_lights.append(fl)
	_prop(13, MARA_X + 62, 0) # bench

	# --- props & lamps
	for x in [300.0, 620.0, 900.0, 1210.0, 1420.0]:
		_prop(4, x, 0)
		_lamp(x, -42, light_tex, Color("ffd08a"), 0.75)
	_prop(17, 1196.0, 0)    # ore pile by smelter
	_prop(18, 1052.0, 0)    # anvil
	_prop(10, 1300.0, 0, 2) # crate stack (level 2)
	_prop(14, 1408.0, 0, 3) # barrels
	_prop(22, 1222.0, 0, 4) # sacks
	_prop(16, 1124.0, 0, 5) # wheelbarrow
	_prop(19, 720.0, 0, 6)  # tool rack
	_prop(23, 800.0, 0, 7)  # water barrel
	_prop(20, 960.0, 0, 8)  # ground lantern
	_prop(21, 640.0, 0, 12) # crystal rock display
	for i in 4:
		_flag(250.0 + i * 260.0, 3 + i * 2)
	_prop(15, ENTRANCE_X + 70, 0) # MINE sign
	for x in range(40, 120, 16):
		_prop(5, float(x), 0)
	_update_growth()
	Events.level_up.connect(func(_l): _update_growth())

func _sprite(path: String, bottom_center: Vector2, hframes: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex(path)
	s.hframes = hframes
	var h := s.texture.get_height()
	s.position = bottom_center + Vector2(0, -h * 0.5)
	add_child(s)
	return s

func _building(id: String, path: String, cx: float, frames: int, prompt: String, action: Callable) -> Sprite2D:
	var s := _sprite(path, Vector2(cx, 0), frames)
	var tex_w := s.texture.get_width() / frames
	var tex_h := s.texture.get_height()
	if prompt != "":
		var ia := Interactable.new()
		ia.setup(prompt, Vector2(tex_w * 0.8, 40), Vector2(0, tex_h * 0.5 - 20), action)
		s.add_child(ia)
	targets[id] = Vector2(cx, -tex_h - 8)
	if frames > 1:
		_anim_sprites.append([s, frames, 2.0, 0])
	return s

func _prop(index: int, x: float, y: float, level_req: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ResourceDatabase.tex("res://assets/sprites/world/props.png")
	s.hframes = 8
	s.vframes = 4
	s.frame = index
	s.position = Vector2(x, y - 16)
	add_child(s)
	if level_req > 0:
		_growth.append([s, level_req])
	return s

func _anim_prop(first: int, frames: int, fps: float, bottom: Vector2) -> Sprite2D:
	var s := _prop(first, bottom.x, bottom.y)
	_anim_sprites.append([s, frames, fps, first])
	return s

func _tree(x: float) -> void:
	var bottom := _prop(7, x, 0)
	var t := _prop(6, x, -32)
	bottom.z_index = -1
	t.z_index = -1

func _flag(x: float, level_req: int) -> void:
	var f := _anim_prop(11, 2, 3.0, Vector2(x, 0))
	_growth.append([f, level_req])

func _lamp(x: float, y: float, tex: Texture2D, col: Color, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = scale
	l.color = col
	l.energy = 0.0
	l.position = Vector2(x, y)
	add_child(l)
	_lamps.append(l)
	return l

func _update_growth() -> void:
	for g in _growth:
		var node: Node2D = g[0]
		var want: bool = GameState.level >= int(g[1])
		if want and not node.visible:
			node.visible = true
			node.scale = Vector2(0.2, 0.2)
			create_tween().tween_property(node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not want:
			node.visible = false

func _mara_talk() -> void:
	var tut = get_tree().get_first_node_in_group("tutorial")
	if tut and tut.has_method("on_mara_talk"):
		tut.on_mara_talk()

## night: 0 (day) .. 1 (night)
func set_night(night: float) -> void:
	for l in _lamps:
		l.energy = lerpf(0.15, 1.05, night)
	for l in _fire_lights:
		l.energy = lerpf(0.4, 1.2, night) + 0.12 * sin(_t * 13.0) + 0.08 * sin(_t * 7.3)

func _process(delta: float) -> void:
	_t += delta
	for a in _anim_sprites:
		var s: Sprite2D = a[0]
		s.frame = int(a[3]) + int(_t * float(a[2])) % int(a[1])
	# Mara idle / talk / wave animation
	_mara_t += delta
	var row := 0
	var player = game.player if game else null
	if player and absf(player.global_position.x - MARA_X) < 70.0 and absf(player.global_position.y) < 40.0:
		row = 2 if _mara_t < 1.2 else 1
		mara.flip_h = player.global_position.x > MARA_X
	else:
		_mara_t = 0.0
		mara.flip_h = false
	var fps := 5.0 if row == 0 else 8.0
	mara.frame = row * 4 + int(_t * fps) % 4
