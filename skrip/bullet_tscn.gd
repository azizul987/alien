extends Area2D

const SPEED := 3000.0
const MAX_DISTANCE := 1200.0

var direction := Vector2.ZERO
var damage := 1
var shooter: Node = null
var start_position := Vector2.ZERO

func _ready() -> void:
	start_position = global_position

func _process(delta: float) -> void:
	global_position += direction * SPEED * delta

	if global_position.distance_to(start_position) >= MAX_DISTANCE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	print("KENA BODY:", body.name)

	if body == shooter:
		return

	if body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
