extends Node2D
## A resource drop. Pops out of a broken block with a little physics, bobs and glints,
## then magnets smoothly into the player within the pickup radius.
## If the backpack is full it stays on the ground (never deleted) and is saved.

const WD = preload("res://scripts/world/world_data.gd")

var item_id := ""
var amount := 1
var vel := Vector2.ZERO
var world = null
var player = null
var game = null
var _age := 0.0
var _resting := false
var _magnet := false
var _refuse_t := 0.0
var _bob := 0.0
var _sprite: Sprite2D
var _glint: Sprite2D
var _rarity := 0
var _spin := 0.0
var _trail: Array[Vector2] = []

func setup(id: String, n: int, pos: Vector2, v: Vector2) -> void:
	item_id = id
	amount = n
	global_position = pos
	vel = v
	_rarity = ResourceDatabase.item_rarity(id)

func _ready() -> void:
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.texture = ResourceDatabase.item_icon(item_id)
	_sprite.scale = Vector2(0.75, 0.75)
	add_child(_sprite)
	if _rarity >= 1:
		_glint = Sprite2D.new()
		_glint.texture = preload("res://scripts/world/world_renderer.gd").make_radial_texture(32, 0.0)
		var col := ResourceDatabase.rarity_color(_rarity)
		_glint.modulate = Color(col.r, col.g, col.b, 0.5)
		_glint.scale = Vector2(0.7, 0.7)
		_glint.show_behind_parent = true
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_glint.material = mat
		add_child(_glint)
	_bob = randf() * TAU
	_spin = randf_range(-6.0, 6.0)
	scale = Vector2(0.2, 0.2)

func _physics_process(delta: float) -> void:
	_age += delta
	_refuse_t -= delta
	scale = scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	var radius := GameState.stat(&"pickup_radius")
	var target: Vector2 = player.global_position + Vector2(0, -14) if player else global_position
	var d := global_position.distance_to(target)
	if player and _age > 0.28 and _refuse_t <= 0.0 and d < radius:
		_magnet = true
	if _magnet and player:
		_trail.push_front(global_position)
		if _trail.size() > 5:
			_trail.pop_back()
		queue_redraw()
		var dir := (target - global_position).normalized()
		var spd := lerpf(120.0, 420.0, clampf(1.0 - d / maxf(radius, 1.0), 0.0, 1.0)) + _age * 40.0
		vel = vel.lerp(dir * spd, 1.0 - exp(-10.0 * delta))
		global_position += vel * delta
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, 0.2)
		if d < 9.0:
			_collect()
		elif d > radius * 1.8:
			_magnet = false
		return
	# simple tile physics
	if not _resting:
		vel.y = minf(vel.y + 620.0 * delta, 420.0)
		var np := global_position + vel * delta
		if world and world.is_solid_at_pos(np + Vector2(0, 5)):
			if absf(vel.y) > 90.0:
				vel.y = -vel.y * 0.35
				vel.x *= 0.6
				np.y = global_position.y
			else:
				vel = Vector2.ZERO
				_resting = true
				np.y = floor((np.y + 5) / 16.0) * 16.0 - 5.0
		if world and world.is_solid_at_pos(np + Vector2(signf(vel.x) * 5, 0)):
			vel.x = -vel.x * 0.4
			np.x = global_position.x
		global_position = np
		_sprite.rotation += _spin * delta
		_spin = lerpf(_spin, 0.0, 2.0 * delta)
	else:
		if world and not world.is_solid_at_pos(global_position + Vector2(0, 6)):
			_resting = false
		_bob += delta * 3.0
		_sprite.position.y = sin(_bob) * 1.5 - 1.0
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, 0.1)
	if _glint:
		_glint.scale = Vector2.ONE * (0.6 + 0.12 * sin(_age * 5.0))

func _collect() -> void:
	var left := GameState.add_item(item_id, amount)
	if left == amount:
		_refuse()
		return
	var got := amount - left
	if _rarity >= 3:
		AudioManager.play("legendary" if _rarity >= 4 else "rare_discovery", -2.0)
		if game: game.hitstop(0.05)
	elif _rarity >= 2:
		AudioManager.play("pickup_rare", -4.0, 0.06, 0.06)
	else:
		AudioManager.play("pickup", -6.0, 0.12, 0.03)
	if game:
		game.effects.pickup_pop(global_position, ResourceDatabase.rarity_color(_rarity))
		if player and player.has_method("play_oneshot") and _rarity >= 2:
			player.play_oneshot("collect")
	if left > 0:
		amount = left
		_refuse()
	else:
		if game: game.pickups_changed(self, true)
		queue_free()

func _refuse() -> void:
	_magnet = false
	_refuse_t = 2.5
	vel = Vector2(randf_range(-40, 40), -120)
	_resting = false
	if game: game.backpack_full_warning(item_id)

func to_dict() -> Dictionary:
	return {"id": item_id, "n": amount, "x": global_position.x, "y": global_position.y}

func _draw() -> void:
	## Short glowing trail while the drop flies into the backpack.
	if not _magnet or _trail.size() < 2:
		return
	var col := ResourceDatabase.rarity_color(_rarity).lightened(0.35)
	for i in _trail.size() - 1:
		var a := 0.45 * (1.0 - float(i) / _trail.size())
		draw_line(_trail[i] - global_position, _trail[i + 1] - global_position, Color(col.r, col.g, col.b, a), 2.0 - i * 0.3)
