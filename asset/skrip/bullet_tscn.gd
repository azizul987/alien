extends Area2D

const SPEED := 700.0
const MAX_DISTANCE := 1200.0

var direction := Vector2.ZERO
var damage := 1
var shooter: Node = null
var start_position := Vector2.ZERO

var is_tranq: bool = false
var bullet_color: Color = Color.YELLOW

func _ready() -> void:
	monitoring = false
	start_position = global_position
	$Sprite2D.modulate = bullet_color
	await get_tree().physics_frame
	monitoring = true

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

	if global_position.distance_to(start_position) >= MAX_DISTANCE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	print("KENA BODY:", body.name)

	if body == shooter:
		return

	if shooter != null:
		# peluru player jangan kena player
		if shooter.is_in_group("player") and body.is_in_group("player"):
			return

		# peluru alien/NPC jangan kena alien/NPC lain
		if shooter.is_in_group("alien") and body.is_in_group("alien"):
			return

	# TAMBAHAN: kalau kena player, langsung game over
	if body.is_in_group("player") and body.has_method("game_over"):
		body.game_over()
		queue_free()
		return

	# selain player, pakai damage biasa
	if body.has_method("take_damage"):
		body.take_damage(damage, shooter)

	queue_free()
