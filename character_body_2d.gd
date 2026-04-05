extends CharacterBody2D

const SPEED := 300.0
const FIRE_RATE := 0.15
const MAX_AMMO := 120
const RELOAD_TIME := 1.0

@onready var sprite = $Pivot/AnimatedSprite2D
@onready var gun_point = $Pivot/GunPoint

var bullet_scene = preload("res://bullet_tscn.tscn")

var can_shoot := true
var ammo := MAX_AMMO
var is_reloading := false

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	var mouse_pos = get_global_mouse_position()

	if input_x < 0:
		sprite.flip_h = true
	elif input_x > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = mouse_pos.x < global_position.x

	if input_vector != Vector2.ZERO:
		if sprite.animation != "Run":
			sprite.play("Run")
	else:
		if sprite.animation != "Idle":
			sprite.play("Idle")

	if Input.is_action_pressed("shoot"):
		shoot()

func shoot() -> void:
	if not can_shoot:
		return
	if is_reloading:
		return
	if ammo <= 0:
		reload_weapon()
		return

	can_shoot = false
	ammo -= 1

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - gun_point.global_position).normalized()

	bullet.global_position = gun_point.global_position + dir * 20.0
	bullet.direction = dir
	bullet.rotation = dir.angle()
	bullet.shooter = self

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true
func reload_weapon() -> void:
	if is_reloading:
		return
	if ammo == MAX_AMMO:
		return

	is_reloading = true
	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo = MAX_AMMO
	is_reloading = false
