extends Area2D
## Anything the player can press [E] on. The player's InteractArea finds the nearest one.

var prompt: String = "Interact"
var action: Callable
var enabled: bool = true
var highlight_name: String = ""

func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true

func setup(p_prompt: String, size: Vector2, offset: Vector2, p_action: Callable) -> void:
	prompt = p_prompt
	action = p_action
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = offset
	add_child(cs)

func can_interact() -> bool:
	return enabled

func get_prompt() -> String:
	return prompt

func interact(player) -> void:
	if action.is_valid():
		action.call(player)
