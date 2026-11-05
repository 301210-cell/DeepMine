extends CharacterBody2D
## The miner. Responsive platforming (coyote time, jump buffer, variable jump, smooth step-up),
## ladders, ice, water, lava/heat hazards, fall damage, interaction and layered animation:
## sprite-sheet frames + procedural squash/stretch, lean, bob and speed-matched cycles.

const WD = preload("res://scripts/world/world_data.gd")

const GRAVITY := 980.0
const FALL_MULT := 1.35
const MAX_FALL := 560.0
const ACCEL := 1000.0
const DECEL := 1300.0
const AIR_ACCEL := 720.0
const ICE_ACCEL := 230.0
const ICE_DECEL := 120.0
const RUN_MULT := 1.5
const COYOTE := 0.11
const JUMP_BUFFER := 0.13
const JUMP_CUT := 0.45
const HALF_W := 5.0
const HEIGHT := 28.0
const SAFE_FALL_PX := 112.0

## name -> [row, frames, fps, loop]
const ANIMS := {
	"idle": [0, 4, 5.0, true], "walk": [1, 8, 12.0, true], "run": [2, 8, 15.0, true],
	"jump": [3, 2, 10.0, false], "fall": [4, 2, 8.0, true], "land": [5, 2, 16.0, false],
	"mine": [6, 4, 10.0, true], "collect": [7, 4, 12.0, false], "climb": [8, 4, 8.0, true],
	"interact": [9, 3, 12.0, false],
}

@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var tool_sprite: Sprite2D = $Visual/Tool
@onready var lantern: PointLight2D = $Lantern
@onready var interact_area: Area2D = $InteractArea

var world = null              # WorldData
var game = null               # Game node (for effects/ui helpers)
var facing := 1
var input_enabled := true
var climbing := false
var swimming := false
var riding := false           # on a mine cart / elevator
var mining := false           # set by MiningController
var mine_phase := 0.0         # 0..1 swing phase from MiningController

var _anim := "idle"
var _anim_t := 0.0
var _coyote := 0.0
var _jump_buf := 0.0
var _jumping := false
var _land_t := 0.0
var _oneshot_t := 0.0
var _oneshot := ""
var _peak_y := 0.0
var _was_on_floor := true
var _hazard_t := 0.0
var _scale_vel := Vector2.ZERO
var _squash := Vector2.ONE       # spring-driven squash/stretch (applied to visual.scale)
var depth_scale := 1.0           # cutscenes: < 1 makes the miner recede into a doorway
var walk_target := INF           # cutscenes: auto-walk toward this x
var _lean := 0.0
var _step_offset := 0.0
var _last_cell := Vector2i(-999, -999)
var _step_sfx_frame := -1
var _flicker_t := 0.0
var _moved_dirs := {}
var _turn_squash := 0.0

signal moved_cell(cell: Vector2i)
signal interact_pressed(target)
signal walk_arrived

func _ready() -> void:
	add_to_group("player")
	lantern.texture = load("res://scripts/world/world_renderer.gd").make_radial_texture(256, 0.0)
	_apply_lantern()
	Events.stats_changed.connect(_apply_lantern)
	Events.equipment_changed.connect(_apply_lantern)
	tool_sprite.visible = false
	_peak_y = global_position.y

func _apply_lantern() -> void:
	var r := GameState.stat(&"lantern_radius")
	lantern.texture_scale = r / 128.0 * 1.6
	var lan := ResourceDatabase.equip(GameState.equipped.get("lantern", "lantern_basic"))
	var col := Color(String(lan.get("color", "ffd89a")))
	if GameState.cosmetics.get("lantern_skin_aurora", false):
		col = Color("bfffe8")
	lantern.color = col

# ================================================================ physics
func _physics_process(delta: float) -> void:
	if riding:
		velocity = Vector2.ZERO
		_update_anim(delta)
		return
	var can_input := input_enabled and not GameState.ui_blocking
	var ix := 0.0
	var iy := 0.0
	if can_input:
		ix = Input.get_axis("move_left", "move_right")
		iy = Input.get_axis("climb_up", "climb_down")
		if ix != 0.0:
			_moved_dirs[signf(ix)] = true
	if walk_target < INF:
		var dx := walk_target - global_position.x
		ix = clampf(dx / 6.0, -1.0, 1.0) if absf(dx) > 1.5 else 0.0
		if ix == 0.0:
			walk_target = INF
			walk_arrived.emit()
	var on_floor := is_on_floor()
	var feet := global_position + Vector2(0, -2)
	var center := global_position + Vector2(0, -HEIGHT * 0.5)
	var cell_center := WD.cell_of(center)
	var cell_feet := WD.cell_of(feet)

	# --- ladders
	var on_ladder := _is_ladder(cell_center) or _is_ladder(cell_feet)
	if on_ladder and absf(iy) > 0.1 and not climbing:
		climbing = true
		_jumping = false
	if climbing and (not on_ladder or (on_floor and iy > 0.1 and not _is_ladder(WD.cell_of(feet + Vector2(0, 6))))):
		climbing = false

	# --- water
	var in_water: bool = world != null and world.get_blockv(cell_center) == ResourceDatabase.WATER
	if in_water and not swimming:
		AudioManager.play("splash", -6.0)
		if game: game.effects.splash(global_position)
	swimming = in_water

	# --- horizontal movement
	var speed := GameState.stat(&"move_speed")
	if can_input and Input.is_action_pressed("run") and not climbing:
		speed *= RUN_MULT
	speed *= _heavy_mult()
	if swimming:
		speed *= 0.6
	var floor_block := _floor_block()
	var on_ice := on_floor and floor_block == 10
	var grip := GameState.stat(&"ice_grip")
	var target_vx := ix * speed
	if climbing:
		target_vx = ix * speed * 0.45
	var acc := ACCEL if on_floor else AIR_ACCEL
	var dec := DECEL if on_floor else AIR_ACCEL * 0.6
	if on_ice:
		acc = lerpf(ICE_ACCEL, ACCEL, grip)
		dec = lerpf(ICE_DECEL, DECEL, grip)
	if absf(target_vx) > 0.01:
		velocity.x = move_toward(velocity.x, target_vx, acc * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, dec * delta)

	# --- vertical movement
	if on_floor:
		_coyote = COYOTE
		_jumping = false
	else:
		_coyote -= delta
	_jump_buf -= delta
	if can_input and Input.is_action_just_pressed("jump"):
		_jump_buf = JUMP_BUFFER
	if climbing:
		velocity.y = iy * GameState.stat(&"climb_speed")
		if _jump_buf > 0.0:
			climbing = false
			_do_jump(0.8)
	elif swimming:
		velocity.y = minf(velocity.y + GRAVITY * 0.35 * delta, 90.0)
		if _jump_buf > 0.0:
			_jump_buf = 0.0
			velocity.y = -170.0
	else:
		var g := GRAVITY * (FALL_MULT if velocity.y > 0.0 else 1.0)
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)
		if _jump_buf > 0.0 and _coyote > 0.0:
			_do_jump(1.0)
		if _jumping and velocity.y < 0.0 and can_input and not Input.is_action_pressed("jump"):
			velocity.y *= JUMP_CUT
			_jumping = false

	if not on_floor and velocity.y < 0.0:
		_peak_y = global_position.y
	elif on_floor or climbing or swimming:
		_peak_y = global_position.y
	_peak_y = minf(_peak_y, global_position.y)

	var prev_vy := velocity.y
	move_and_slide()
	_try_step_up(ix)

	# --- landing
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		_on_land(prev_vy)
	if not now_floor and _was_on_floor and velocity.y >= 0.0:
		_peak_y = global_position.y
	_was_on_floor = now_floor

	# --- facing
	if not mining and absf(ix) > 0.1 and not climbing:
		var nf := 1 if ix > 0.0 else -1
		if nf != facing:
			facing = nf
			_turn_squash = 1.0
	_hazards(delta, floor_block)
	_track_cell()
	_update_interaction(can_input)
	_update_anim(delta)

func _do_jump(mult: float) -> void:
	velocity.y = -GameState.stat(&"jump_velocity") * mult
	_jumping = true
	_coyote = 0.0
	_jump_buf = 0.0
	_peak_y = global_position.y
	_scale_vel = Vector2(-2.4, 3.4)
	_squash = Vector2(0.82, 1.18)
	AudioManager.play("jump", -8.0, 0.08)
	if game: game.effects.dust(global_position, 4)

func _on_land(impact_vy: float) -> void:
	var fall := global_position.y - _peak_y
	var strength := clampf(impact_vy / MAX_FALL, 0.0, 1.0)
	if strength > 0.25:
		_squash = Vector2(1.0 + 0.32 * strength, 1.0 - 0.28 * strength)
		_land_t = 0.12
		AudioManager.play("land", -6.0 + strength * 4.0, 0.1)
		if game: game.effects.dust(global_position, int(4 + 8 * strength))
	if fall > SAFE_FALL_PX and not swimming:
		var dmg := (fall - SAFE_FALL_PX) / 16.0 * 6.0 * (1.0 - GameState.stat(&"fall_reduction"))
		if dmg >= 1.0:
			GameState.damage(dmg, "fall")
			Events.screen_shake.emit(minf(dmg / 10.0, 5.0), 0.25)
	_peak_y = global_position.y

func _try_step_up(ix: float) -> void:
	## Smoothly climb single-tile ledges while walking (visual offset eases back).
	if absf(ix) < 0.1 or not is_on_floor() or not is_on_wall() or climbing or world == null:
		return
	var dir := 1 if ix > 0.0 else -1
	var fx := int(floor((global_position.x + dir * (HALF_W + 2.0)) / 16.0))
	var fy := int(floor((global_position.y - 1.0) / 16.0))
	if not world.is_solid(fx, fy):
		return
	if world.is_solid(fx, fy - 1) or world.is_solid(fx, fy - 2):
		return
	var hx := int(floor(global_position.x / 16.0))
	var head_y := int(floor((global_position.y - HEIGHT - 4.0) / 16.0))
	if world.is_solid(hx, head_y):
		return
	var new_y := float(fy * 16)
	var dy := global_position.y - new_y
	if dy <= 0.0 or dy > 17.0:
		return
	global_position = Vector2(global_position.x + dir * 2.0, new_y - 0.01)
	_step_offset += dy
	velocity.y = 0.0

func _heavy_mult() -> float:
	var used := float(GameState.used_slots())
	var cap := maxf(1.0, float(GameState.inventory_capacity()))
	var fill := clampf((used / cap - 0.75) / 0.25, 0.0, 1.0)
	return 1.0 - GameState.stat(&"heavy_penalty") * fill

func _is_ladder(c: Vector2i) -> bool:
	return world != null and world.get_blockv(c) == ResourceDatabase.LADDER

func _floor_block() -> int:
	if world == null:
		return 0
	return world.get_block(int(floor(global_position.x / 16.0)), int(floor((global_position.y + 2.0) / 16.0)))

func _hazards(delta: float, floor_block: int) -> void:
	if world == null:
		return
	_hazard_t -= delta
	var c := WD.cell_of(global_position + Vector2(0, -8))
	var in_lava: bool = world.get_blockv(c) == ResourceDatabase.LAVA or world.get_blockv(WD.cell_of(global_position + Vector2(0, -2))) == ResourceDatabase.LAVA
	var heat_proof := GameState.stat(&"heat_proof") > 0.5
	if in_lava:
		var dps := 32.0 * (0.5 if heat_proof else 1.0)
		GameState.damage(dps * delta, "lava")
		velocity.y = minf(velocity.y, -230.0)
		if _hazard_t <= 0.0:
			_hazard_t = 0.35
			AudioManager.play("hurt", -4.0)
			if game: game.effects.embers(global_position)
	elif is_on_floor() and floor_block == 14 and not heat_proof:
		GameState.damage(10.0 * delta, "heat")
		if _hazard_t <= 0.0:
			_hazard_t = 0.6
			AudioManager.play("lava_bubble", -8.0)
			Events.notify.emit("Magma Crust burns! Thermal Boots protect you.", "warn")
			if game: game.effects.embers(global_position)

func _track_cell() -> void:
	var c := WD.cell_of(global_position + Vector2(0, -8))
	if c != _last_cell:
		_last_cell = c
		GameState.player_pos = global_position
		moved_cell.emit(c)

func has_moved_both_ways() -> bool:
	return _moved_dirs.has(1.0) and _moved_dirs.has(-1.0)

# ================================================================ interaction
var _focus = null

func _update_interaction(can_input: bool) -> void:
	if not input_enabled or riding:
		# cutscenes / rides: no prompts
		if _focus != null:
			_focus = null
			var ui0 := get_tree().get_first_node_in_group("ui_root")
			if ui0 and ui0.has_method("hide_prompt"):
				ui0.hide_prompt()
		return
	var best = null
	var best_d := INF
	for a in interact_area.get_overlapping_areas():
		if a.has_method("can_interact") and not a.can_interact():
			continue
		if not a.has_method("interact"):
			continue
		var d := a.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = a
	if best != _focus:
		_focus = best
		var ui := get_tree().get_first_node_in_group("ui_root")
		if ui:
			if best and ui.has_method("show_prompt"):
				ui.show_prompt(best.get_prompt() if best.has_method("get_prompt") else "Interact")
			elif ui.has_method("hide_prompt"):
				ui.hide_prompt()
	if can_input and best and Input.is_action_just_pressed("interact"):
		play_oneshot("interact")
		best.interact(self)
		interact_pressed.emit(best)

func refresh_prompt() -> void:
	_focus = null

# ================================================================ animation
func play_oneshot(n: String) -> void:
	_oneshot = n
	_oneshot_t = 0.0

func _update_anim(delta: float) -> void:
	var on_floor := is_on_floor()
	var want := "idle"
	var rate := 1.0
	if riding:
		want = "idle"
	elif mining:
		want = "mine"
	elif climbing:
		want = "climb"
		rate = absf(velocity.y) / 60.0
	elif not on_floor and not swimming:
		want = "jump" if velocity.y < -30.0 else "fall"
	elif _land_t > 0.0:
		want = "land"
	elif absf(velocity.x) > 8.0:
		var running := absf(velocity.x) > GameState.stat(&"move_speed") * 1.15
		want = "run" if running else "walk"
		var base := GameState.stat(&"move_speed") * (RUN_MULT if running else 1.0)
		rate = clampf(absf(velocity.x) / maxf(base, 1.0), 0.35, 1.6)
	if _oneshot != "" and not mining and on_floor and absf(velocity.x) < 8.0:
		want = _oneshot
	_land_t -= delta
	if want != _anim:
		_anim = want
		_anim_t = 0.0
	var a: Array = ANIMS[_anim]
	var row: int = a[0]
	var frames: int = a[1]
	var fps: float = a[2]
	var loop: bool = a[3]
	var frame := 0
	if _anim == "mine":
		# frames follow the swing phase exactly: windup, raised, strike, follow-through
		frame = clampi(int(mine_phase * frames), 0, frames - 1)
	else:
		_anim_t += delta * fps * rate
		frame = int(_anim_t)
		if loop:
			frame = frame % frames
		else:
			frame = mini(frame, frames - 1)
			if _anim == _oneshot and _anim_t >= frames + 1:
				_oneshot = ""
	body.frame = row * 8 + frame
	# footsteps on contact frames
	if (_anim == "walk" or _anim == "run") and (frame == 0 or frame == 4) and frame != _step_sfx_frame:
		AudioManager.play("step", -14.0 if _anim == "walk" else -11.0, 0.12, 0.12)
		if _anim == "run" and game:
			game.effects.dust(global_position + Vector2(-facing * 4, 0), 2)
	_step_sfx_frame = frame if (_anim == "walk" or _anim == "run") else -1

	# --- procedural layers (smooth): spring squash/stretch, lean, step-up ease, turn squash
	var k := 260.0
	var damp := 18.0
	var disp := Vector2.ONE - _squash
	_scale_vel += (disp * k - _scale_vel * damp) * delta
	_squash += _scale_vel * delta
	visual.scale = _squash * depth_scale
	_turn_squash = move_toward(_turn_squash, 0.0, delta * 9.0)
	var target_lean := 0.0
	if on_floor and absf(velocity.x) > 40.0 and not mining:
		target_lean = clampf(velocity.x / 900.0, -0.09, 0.09)
	elif not on_floor and not climbing:
		target_lean = clampf(velocity.x / 1400.0, -0.06, 0.06)
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-12.0 * delta))
	visual.rotation = _lean
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - exp(-18.0 * delta))
	visual.position = Vector2(0, _step_offset)
	body.flip_h = facing < 0
	body.scale.x = 1.0 - 0.22 * sin(_turn_squash * PI)
	# lantern flicker
	_flicker_t += delta
	lantern.energy = 1.0 + 0.04 * sin(_flicker_t * 11.0) + 0.03 * sin(_flicker_t * 23.7)
	lantern.position = Vector2(facing * 3, -34)

func set_riding(on: bool) -> void:
	riding = on
	velocity = Vector2.ZERO
	climbing = false

## Cutscene helper: walks (and falls down steps) toward world x, with a safety timeout.
func walk_to(x: float, timeout: float = 6.0) -> void:
	walk_target = x
	var t := 0.0
	while walk_target < INF and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	walk_target = INF
	velocity.x = 0.0
