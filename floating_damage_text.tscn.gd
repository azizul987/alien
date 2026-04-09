extends Node2D

@onready var label: Label = $Label

var velocity := Vector2.ZERO
var lifetime := 0.8

func setup(text_value: String, color: Color = Color.WHITE) -> void:
	label.text = text_value
	label.modulate = color

func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity = Vector2(
			randf_range(-20.0, 20.0),
			randf_range(-50.0, -30.0)
		)

func _process(delta: float) -> void:
	position += velocity * delta
	label.modulate.a -= delta / lifetime

	if label.modulate.a <= 0.0:
		queue_free()
