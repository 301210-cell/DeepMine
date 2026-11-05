extends Camera2D
## Smooth follow camera: critically-damped follow, look-ahead in the movement/facing
## direction, downward peek while falling, and trauma-based screen shake.

var target: Node2D
var _shake := 0.0
var _shake_t := 0.0
var _look := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _nt := 0.0

func _ready() -> void:
	position_smoothing_enabled = false
	_noise.frequency = 2.2
	limit_left = 0
	limit_right = 192 * 16
	limit_top = -420
	limit_bottom = 1608 * 16
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func shake(strength: float, duration: float) -> void:
	_shake = maxf(_shake, strength)
	_shake_t = maxf(_shake_t, duration)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var facing: int = target.facing if "facing" in target else 1
	var want_look := Vector2(facing * 22.0 + clampf(v.x * 0.12, -26.0, 26.0), 0.0)
	if v.y > 220.0:
		want_look.y = clampf((v.y - 220.0) * 0.18, 0.0, 48.0)
	_look = _look.lerp(want_look, 1.0 - exp(-2.6 * delta))
	var goal: Vector2 = target.global_position + Vector2(0, -30) + _look
	global_position = global_position.lerp(goal, 1.0 - exp(-8.5 * delta))
	# shake
	if _shake_t > 0.0:
		_shake_t -= delta
		_nt += delta * 60.0
		var s := _shake * clampf(_shake_t / 0.25, 0.0, 1.0)
		offset = Vector2(_noise.get_noise_2d(_nt, 0.0), _noise.get_noise_2d(0.0, _nt)) * s * 2.0
	else:
		_shake = 0.0
		offset = offset.lerp(Vector2.ZERO, 0.3)
