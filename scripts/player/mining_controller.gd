extends Node2D
## Mining: aims along a grid ray toward the mouse, animates an eased pickaxe swing
## (anticipation -> strike -> follow-through -> recover) synced with the body frames,
## applies damage on impact through the central stats, and spawns drops.
## Also handles right-click hotbar items: ladders, torches, dynamite, tonics.

const WD = preload("res://scripts/world/world_data.gd")
const Loot = preload("res://scripts/progression/loot.gd")

const REACH := 54.0
const BASE_GEODE_CHANCE := 0.0025
const BASE_FOSSIL_CHANCE := 0.0009
const GEODE_BY_BIOME := ["geode_small", "geode_iron", "geode_rare", "geode_ice", "geode_magma", "geode_legendary"]
const PROSPECT_GEMS := [["quartz"], ["quartz", "gold_ore", "silver_ore"], ["amethyst", "sapphire", "emerald", "ruby", "topaz"],
	["topaz", "blue_sapphire", "opal", "frost_crystal"], ["ruby", "obsidian", "emberstone"], ["ancient_shard", "ancient_gold", "relic_fragment"]]
const ORE_SPECIALIST_ITEMS := ["copper_ore", "iron_ore", "silver_ore"]
const PICK_NAMES_BY_TIER := ["", "Basic Pickaxe", "Copper Pickaxe", "Iron Pickaxe", "Steel Pickaxe", "Crystal Pickaxe", "Diamond Drill", "Plasma Mining Tool"]

var player = null
var world = null
var game = null
var target := Vector2i(-1, -1)
var has_target := false
var _swing_t := 0.0
var _swinging := false
var _impact_done := false
var _swing_cell := Vector2i(-1, -1)
var _combo := 0
var _combo_timer := 0.0
var _overflow := 0.0
var _overflow_timer := 0.0
var _deny_cooldown := 0.0
var _crack_tex: Texture2D
var _cross_tex: Texture2D
var _pulse := 0.0
var _tool_angle := -20.0
var _tool_flash := 0.0
var _use_cooldown := 0.0

func _ready() -> void:
	_crack_tex = ResourceDatabase.tex("res://assets/tilesets/crack.png")
	_cross_tex = ResourceDatabase.tex("res://assets/ui/crosshair.png")
	z_index = 5

func _process(delta: float) -> void:
	if player == null or world == null:
		return
	_pulse += delta
	_deny_cooldown -= delta
	_use_cooldown -= delta
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo = 0
	_overflow_timer -= delta
	if _overflow_timer <= 0.0:
		_overflow = 0.0
	var can: bool = not GameState.ui_blocking and player.input_enabled and not player.riding
	_find_target(can)
	var want_mine: bool = can and Input.is_action_pressed("mine") and has_target and _selected_tool() != ""
	if want_mine and not _swinging:
		_start_swing()
	if _swinging:
		_advance_swing(delta)
	else:
		player.mining = false
		_tool_angle = lerpf(_tool_angle, -20.0, 1.0 - exp(-10.0 * delta))
		player.tool_sprite.visible = false
	if can and Input.is_action_just_pressed("use_item") and _use_cooldown <= 0.0:
		_use_selected()
	if can and Input.is_action_just_pressed("quick_heal"):
		_drink_tonic()
	queue_redraw()

# ================================================================ targeting
func _chest() -> Vector2:
	return player.global_position + Vector2(0, -17)

func _find_target(can: bool) -> void:
	has_target = false
	if not can:
		return
	var ui := get_tree().get_first_node_in_group("ui_root")
	if ui and ui.has_method("is_mouse_over_ui") and ui.is_mouse_over_ui():
		return
	var from := _chest()
	var mouse := get_global_mouse_position()
	var dir := mouse - from
	var dist := minf(dir.length(), REACH)
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	# DDA grid traversal: first solid cell along the aim ray.
	var steps := int(dist / 2.0) + 1
	var last := WD.cell_of(from)
	for i in steps + 1:
		var p := from + dir * (i * 2.0)
		var c := WD.cell_of(p)
		if c == last and i > 0:
			continue
		last = c
		var id: int = world.get_blockv(c)
		if ResourceDatabase.is_solid(id):
			target = c
			has_target = true
			return
	# Removable non-solid items under the cursor (ladders, torches).
	var mc := WD.cell_of(mouse)
	if WD.cell_center(mc).distance_to(from) <= REACH + 8.0:
		var mid: int = world.get_blockv(mc)
		if mid == ResourceDatabase.LADDER or mid == ResourceDatabase.TORCH:
			target = mc
			has_target = true

func _selected_tool() -> String:
	var slot: String = GameState.HOTBAR[GameState.hotbar_index]
	if slot == "drill":
		var d: String = GameState.equipped.get("drill", "")
		return d if d != "" else GameState.equipped.get("pickaxe", "basic_pickaxe")
	return GameState.equipped.get("pickaxe", "basic_pickaxe")

# ================================================================ swing animation
func _swing_duration() -> float:
	var spd := GameState.stat(&"mining_speed")
	if _selected_tool().begins_with("portable_drill"):
		spd *= 0.85
	return 1.0 / maxf(spd, 0.2)

func _start_swing() -> void:
	_swinging = true
	_swing_t = 0.0
	_impact_done = false
	_swing_cell = target
	player.mining = true
	var tool_id := _selected_tool()
	var e := ResourceDatabase.equip(tool_id)
	player.tool_sprite.frame = int(e.get("tool_sprite", 0))
	player.tool_sprite.visible = true
	if WD.cell_center(target).x < player.global_position.x - 2:
		player.facing = -1
	elif WD.cell_center(target).x > player.global_position.x + 2:
		player.facing = 1
	AudioManager.play("swing", -12.0, 0.1, 0.05)

static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

static func _ease_in(t: float) -> float:
	return t * t * t

func _advance_swing(delta: float) -> void:
	var dur := _swing_duration()
	_swing_t += delta / dur
	var p := clampf(_swing_t, 0.0, 1.0)
	player.mine_phase = p
	# aim-dependent strike angle: down targets swing lower, up targets higher
	var to_t := WD.cell_center(_swing_cell) - _chest()
	var aim := clampf(rad_to_deg(atan2(to_t.y, absf(to_t.x))), -70.0, 80.0)
	var windup := -118.0
	var strike := 55.0 + aim * 0.5
	var ang: float
	if p < 0.42:
		ang = lerpf(-30.0, windup, _ease_out(p / 0.42))
	elif p < 0.6:
		ang = lerpf(windup, strike + 12.0, _ease_in((p - 0.42) / 0.18))
	elif p < 0.74:
		ang = lerpf(strike + 12.0, strike, _ease_out((p - 0.6) / 0.14))
	else:
		ang = lerpf(strike, -30.0, _ease_out((p - 0.74) / 0.26) * 0.6)
	_tool_angle = ang
	var f: int = player.facing
	player.tool_sprite.flip_h = f < 0
	player.tool_sprite.offset = Vector2(-25, -25) if f < 0 else Vector2(-7, -25)
	player.tool_sprite.position = Vector2(4 * f, -19)
	player.tool_sprite.rotation = deg_to_rad(ang) * f
	_tool_flash = maxf(0.0, _tool_flash - delta * 6.0)
	player.tool_sprite.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.6), _tool_flash)
	if p >= 0.6 and not _impact_done:
		_impact_done = true
		_impact()
	if _swing_t >= 1.0:
		_swinging = false
		var keep := Input.is_action_pressed("mine") and has_target and not GameState.ui_blocking
		if keep:
			_start_swing()
		else:
			player.mining = false

# ================================================================ damage
func _impact() -> void:
	var c := _swing_cell
	var id: int = world.get_blockv(c)
	if id == ResourceDatabase.AIR:
		return
	if id == ResourceDatabase.LADDER or id == ResourceDatabase.TORCH:
		_pickup_placeable(c, id)
		return
	if not ResourceDatabase.is_solid(id):
		return
	var tool_id := _selected_tool()
	var is_drill := tool_id.begins_with("portable_drill")
	var cells: Array[Vector2i] = [c]
	var mult := 1.0
	if is_drill:
		var d := ResourceDatabase.equip(tool_id)
		mult = float(d.get("power_mult", 0.6))
		var area := int(d.get("area", 1))
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			cells.append(c + o)
		if area >= 2:
			for o in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				cells.append(c + o)
	var first := true
	for cell in cells:
		var cid: int = world.get_blockv(cell)
		if not ResourceDatabase.is_solid(cid):
			continue
		_damage_cell(cell, cid, mult if not first or is_drill else 1.0, first)
		first = false

func _damage_cell(c: Vector2i, id: int, mult: float, primary: bool) -> void:
	var b := ResourceDatabase.block(id)
	var dur := float(b.get("durability", 1))
	var center := WD.cell_center(c)
	if dur < 0.0:
		if primary:
			_deny(center, "Unbreakable")
		return
	var tier := int(b.get("tier", 1))
	if tier > int(GameState.stat(&"tool_tier")):
		if primary:
			var need: String = PICK_NAMES_BY_TIER[clampi(tier, 1, 7)]
			_deny(center, "Needs %s (Tier %d)" % [need, tier])
			AudioManager.play("hit_metal", -4.0, 0.05)
			if game: game.effects.sparks(center, Color("ffd890"))
		return
	var power := GameState.stat(&"mining_power") * mult
	if dur >= 15.0:
		power *= 1.0 + GameState.skill_bonus("hard_rock_pct") / 100.0
	if primary:
		_combo = mini(_combo + 1, 5) if _combo_timer > 0.0 else 1
		_combo_timer = _swing_duration() + 0.35
		power *= 1.0 + GameState.skill_bonus("momentum_pct") / 100.0 * maxi(_combo - 1, 0)
	var crit := primary and randf() < GameState.stat(&"crit_chance")
	if crit:
		power *= 3.0
		Events.float_text.emit(center + Vector2(0, -10), "CRIT!", Color("ffd35a"))
		if game: game.hitstop(0.045)
	if primary and _overflow > 0.0:
		power += _overflow
		_overflow = 0.0
	var dmg: float = float(world.damage.get(c, 0.0)) + power
	_tool_flash = 1.0 if crit else 0.5
	_hit_feedback(c, id, b, crit)
	if dmg >= dur:
		if primary:
			_overflow = dmg - dur
			_overflow_timer = 1.0
		_break_block(c, id, b)
	else:
		world.damage[c] = dmg

func _hit_feedback(c: Vector2i, id: int, b: Dictionary, crit: bool) -> void:
	var s: String = b.get("sound", "rock")
	match s:
		"ore": AudioManager.play("hit_ore", -3.0)
		"crystal": AudioManager.play("hit_crystal", -3.0)
		"ice": AudioManager.play("hit_ice", -3.0)
		"metal": AudioManager.play("hit_metal", -3.0)
		"wood", "dirt": AudioManager.play("hit_rock", -5.0, 0.2)
		_: AudioManager.play("hit_rock", -3.0)
	if game:
		var center := WD.cell_center(c)
		var from := _chest()
		var face := center + (from - center).normalized() * 7.0
		game.effects.debris(face, game.block_color(id, c.y), 4 if not crit else 9)
		game.effects.impact(face)
	Events.screen_shake.emit(0.8 if not crit else 2.6, 0.08)

func _deny(pos: Vector2, text: String) -> void:
	if _deny_cooldown > 0.0:
		return
	_deny_cooldown = 1.2
	Events.float_text.emit(pos + Vector2(0, -12), text, Color("ff8a6a"))
	AudioManager.play("ui_error", -8.0)

func _break_block(c: Vector2i, id: int, b: Dictionary) -> void:
	world.set_block(c.x, c.y, ResourceDatabase.AIR)
	var center := WD.cell_center(c)
	var depth := c.y * 2
	var bi: int = maxi(0, world.biome_at_row(c.y))
	var drops: Dictionary = {}
	var is_deposit := ResourceDatabase.is_deposit(id)
	for d in b.get("drops", []):
		if d.has("loot"):
			var res := Loot.roll(ResourceDatabase.loot.get(d.loot, {}), depth, GameState.skill_bonus("fossil_chance_pct") / 100.0)
			for pair in res.items:
				drops[pair[0]] = int(drops.get(pair[0], 0)) + int(pair[1])
			continue
		if randf() > float(d.get("chance", 1.0)):
			continue
		var n := randi_range(int(d.get("min", 1)), int(d.get("max", 1)))
		drops[d.item] = int(drops.get(d.item, 0)) + n
	if is_deposit and not drops.is_empty():
		var main_item: String = drops.keys()[0]
		if randf() * 100.0 < GameState.skill_bonus("bonus_drop_chance"):
			drops[main_item] = int(drops[main_item]) + 1
			Events.float_text.emit(center + Vector2(0, -18), "BONUS!", Color("8affb0"))
		if main_item in ORE_SPECIALIST_ITEMS and randf() * 100.0 < GameState.skill_bonus("ore_yield_pct"):
			drops[main_item] = int(drops[main_item]) + 1
		var ob := int(GameState.stat(&"ore_bonus"))
		if ob > 0:
			drops[main_item] = int(drops[main_item]) + ob
	elif not is_deposit and c.y >= 6 and b.get("drops", []).size() > 0:
		# Plain rock: chances for geodes, fossils and prospected gems.
		if randf() < BASE_GEODE_CHANCE * GameState.stat(&"geode_mult"):
			var g: String = GEODE_BY_BIOME[bi]
			drops[g] = int(drops.get(g, 0)) + 1
		if randf() < BASE_FOSSIL_CHANCE * (1.0 + GameState.skill_bonus("fossil_chance_pct") / 100.0):
			var table := "fossil" if bi < 4 else "artifact"
			var res2 := Loot.roll(ResourceDatabase.loot.get(table, {}), depth)
			for pair in res2.items:
				drops[pair[0]] = int(drops.get(pair[0], 0)) + int(pair[1])
		if randf() * 100.0 < GameState.skill_bonus("prospect_chance"):
			var gems: Array = PROSPECT_GEMS[bi]
			var gem: String = gems[randi() % gems.size()]
			drops[gem] = int(drops.get(gem, 0)) + 1
			Events.float_text.emit(center + Vector2(0, -18), "Prospected!", Color("b9a8ff"))
	var dm := int(GameState.stat(&"drop_mult"))
	if dm > 1:
		for k in drops:
			drops[k] = int(drops[k]) * dm
	# XP and counters
	GameState.add_xp(float(b.get("xp", 1)))
	GameState.add_counter("mine_any", 1)
	GameState.add_counter("mine_block:" + String(b.get("key", "")), 1)
	if is_deposit:
		GameState.add_counter("mine_ore", 1)
		if b.get("sound", "") == "crystal":
			GameState.add_counter("mine_gem", 1)
	Events.block_mined.emit(id, c)
	# Effects
	match b.get("sound", "rock"):
		"crystal": AudioManager.play("break_crystal", -2.0)
		_: AudioManager.play("break_rock", -2.0)
	if game:
		game.effects.flash_cell(center)
		game.effects.debris(center, game.block_color(id, c.y), 12)
		game.effects.dust(center + Vector2(0, 6), 5)
		if is_deposit and int(b.get("rarity", 0)) >= 2:
			game.effects.sparkle_burst(center, ResourceDatabase.rarity_color(int(b.rarity)))
		for item_id in drops:
			game.spawn_pickup(item_id, int(drops[item_id]), center)
	Events.screen_shake.emit(1.4, 0.1)

func _pickup_placeable(c: Vector2i, id: int) -> void:
	world.set_block(c.x, c.y, ResourceDatabase.AIR)
	var item := "ladder" if id == ResourceDatabase.LADDER else "torch"
	if game:
		game.spawn_pickup(item, 1, WD.cell_center(c))
	AudioManager.play("place", -6.0)

# ================================================================ right-click items
func _use_selected() -> void:
	var slot: String = GameState.HOTBAR[GameState.hotbar_index]
	match slot:
		"ladder":
			_place(ResourceDatabase.LADDER, "ladder")
		"torch":
			_place(ResourceDatabase.TORCH, "torch")
		"dynamite":
			_throw_dynamite()
		"health_potion":
			_drink_tonic()

func _place(block_id: int, item: String) -> void:
	if GameState.count_item(item) <= 0:
		_deny(get_global_mouse_position(), "No %ss left" % ResourceDatabase.item_name(item))
		return
	var mc := WD.cell_of(get_global_mouse_position())
	if WD.cell_center(mc).distance_to(_chest()) > REACH + 10.0:
		_deny(WD.cell_center(mc), "Too far")
		return
	var cur: int = world.get_blockv(mc)
	if cur != ResourceDatabase.AIR and cur != ResourceDatabase.WATER:
		return
	if mc.y < 0:
		return
	if block_id == ResourceDatabase.TORCH:
		var supported := false
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if world.is_solid(mc.x + o.x, mc.y + o.y):
				supported = true
		if not supported:
			_deny(WD.cell_center(mc), "Place next to a wall")
			return
	# Don't trap the player inside a placed block (ladders/torches are non-solid, so fine).
	GameState.remove_item(item, 1)
	world.set_block(mc.x, mc.y, block_id)
	AudioManager.play("place", -4.0)
	_use_cooldown = 0.12
	if game: game.effects.dust(WD.cell_center(mc), 3)

func _drink_tonic() -> void:
	if GameState.count_item("health_potion") <= 0:
		return
	if GameState.hp >= GameState.MAX_HP - 0.5:
		Events.notify.emit("Health is already full", "info")
		return
	GameState.remove_item("health_potion", 1)
	GameState.heal(50.0)
	AudioManager.play("pickup_rare", -4.0)
	if game: game.effects.sparkle_burst(player.global_position + Vector2(0, -16), Color("ff6a7a"))
	_use_cooldown = 0.5

func _throw_dynamite() -> void:
	if GameState.count_item("dynamite") <= 0:
		_deny(get_global_mouse_position(), "No Dynamite left")
		return
	GameState.remove_item("dynamite", 1)
	_use_cooldown = 0.6
	var dir := (get_global_mouse_position() - _chest()).normalized()
	if game:
		game.throw_dynamite(_chest(), dir * 230.0 + Vector2(0, -80))

## Called by the game when dynamite explodes.
func explode_at(pos: Vector2, radius_tiles: float = 2.3) -> void:
	var cc := WD.cell_of(pos)
	var r := int(ceil(radius_tiles))
	var tier := int(GameState.stat(&"tool_tier"))
	for y in range(cc.y - r, cc.y + r + 1):
		for x in range(cc.x - r, cc.x + r + 1):
			var c := Vector2i(x, y)
			if WD.cell_center(c).distance_to(pos) > radius_tiles * 16.0:
				continue
			var id: int = world.get_blockv(c)
			if not ResourceDatabase.is_solid(id):
				continue
			var b := ResourceDatabase.block(id)
			if float(b.get("durability", -1)) < 0.0 or int(b.get("tier", 1)) > tier:
				continue
			_break_block(c, id, b)
	if player.global_position.distance_to(pos) < 30.0:
		GameState.damage(14.0, "explosion")

# ================================================================ drawing
func _draw() -> void:
	_draw_swing_smear()
	if not has_target:
		return
	var r := Rect2(Vector2(target.x * 16, target.y * 16), Vector2(16, 16))
	var id: int = world.get_blockv(target)
	var b := ResourceDatabase.block(id)
	var dur := float(b.get("durability", 1))
	var dmg := float(world.damage.get(target, 0.0))
	if dmg > 0.0 and dur > 0.0:
		var stage := clampi(int(dmg / dur * 5.0), 0, 4)
		draw_texture_rect_region(_crack_tex, r, Rect2(stage * 16, 0, 16, 16))
	var ok := int(b.get("tier", 1)) <= int(GameState.stat(&"tool_tier")) and dur >= 0.0
	var a := 0.55 + 0.3 * sin(_pulse * 6.0)
	var col := Color(1, 0.95, 0.7, a) if ok else Color(1, 0.4, 0.35, a)
	# pixel-crisp corner brackets
	var p := r.position
	for corner in [Vector2(0, 0), Vector2(13, 0), Vector2(0, 13), Vector2(13, 13)]:
		var q: Vector2 = p + corner
		draw_rect(Rect2(q.x if corner.x == 0 else q.x, q.y, 3, 1), col)
		draw_rect(Rect2(q.x if corner.x == 0 else q.x + 2, q.y, 1, 3), col)
	if dmg > 0.0 and dur > 0.0:
		var w := 14.0 * (1.0 - dmg / dur)
		draw_rect(Rect2(p + Vector2(1, -4), Vector2(14, 2)), Color(0.05, 0.05, 0.1, 0.8))
		draw_rect(Rect2(p + Vector2(1, -4), Vector2(w, 2)), Color("ffd35a"))

## Soft motion smear behind the pickaxe head during the strike part of the swing.
func _draw_swing_smear() -> void:
	if not _swinging or player == null:
		return
	var p := clampf(_swing_t, 0.0, 1.0)
	if p < 0.44 or p > 0.7:
		return
	var f: int = player.facing
	var pivot: Vector2 = player.global_position + Vector2(4 * f, -19)
	var a1 := deg_to_rad(-118.0)
	var a2 := deg_to_rad(_tool_angle)
	var steps := 7
	var fade := 1.0 - absf(p - 0.58) / 0.16
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var r := 21.0
		var ang0 := lerpf(a1, a2, t0) - PI * 0.25
		var ang1 := lerpf(a1, a2, t1) - PI * 0.25
		var d0 := Vector2(cos(ang0) * f, sin(ang0)) * r
		var d1 := Vector2(cos(ang1) * f, sin(ang1)) * r
		draw_line(pivot + d0, pivot + d1, Color(1, 0.97, 0.85, 0.32 * t1 * fade), 2.0)
