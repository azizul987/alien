extends CharacterBody2D

const SPEED := 300.0

@onready var pivot = $Pivot
@onready var sprite = $Pivot/AnimatedSprite2D

func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	pivot.look_at(get_global_mouse_position())
