extends CharacterBody2D

@export var isMoving: bool = true
@export var speed: float = 20.0

@onready var kiri: Marker2D = $Kiri
@onready var kanan: Marker2D = $Kanan
@onready var animasi:AnimatedSprite2D=$AnimatedSprite2D
var target_pos: Vector2
var left_pos: Vector2
var right_pos: Vector2

func take_damage(amount: int) -> void:
	print("TARGET KENA")
	animasi.play("Death")
	await animasi.animation_finished
	queue_free()

func _ready() -> void:
	left_pos = kiri.global_position
	right_pos = kanan.global_position
	target_pos = right_pos

func _physics_process(delta: float) -> void:
	if !isMoving:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target = target_pos - global_position
	var distance = to_target.length()
	var step = speed * delta

	if distance <= step:
		global_position = target_pos

		if target_pos == right_pos:
			target_pos = left_pos
		else:
			target_pos = right_pos

		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * speed

	move_and_slide()
