extends CharacterBody2D

const SPEED := 300.0
const FIRE_RATE := 0.5
const MAX_AMMO := 120
const RELOAD_TIME := 1.0

@onready var detector: Node2D = $TileDetector
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var gun_point: Marker2D = $Pivot/GunPoint
@onready var gun_sound:AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var deteksi:Area2D = $Deteksi
@onready var kacamata:PointLight2D = $kacamata

var bullet_scene = preload("res://node/bullet_tscn.tscn")

var can_shoot := true
var ammo := MAX_AMMO
var is_reloading := false
var is_shooting := false
var dekat_pintu := false
var use_tranq :bool


var is_using_kacamata=false;
var facing_direction := Vector2.DOWN

@onready var step_sound:AudioStreamPlayer2D=$Footstep

func _physics_process(delta: float) -> void:
	#ini adalah conoth pakai detecor nah disini aku mau simpan biar ingat
	#var ada_pintu = detector.is_near_type(global_position, "door")

	
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()
	var mouse_pos := get_global_mouse_position()

	if input_x < 0:
		sprite.flip_h = true
	elif input_x > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = mouse_pos.x < global_position.x

	if !is_shooting and !is_reloading:
		if input_vector != Vector2.ZERO:
			if sprite.animation != "Run":
				sprite.play("Run")

			if !step_sound.playing:
				step_sound.play()
		else:
			if sprite.animation != "Idle":
				sprite.play("Idle")

			if step_sound.playing:
				step_sound.stop()

	if Input.is_action_just_pressed("shoot"):
		shoot()

	if Input.is_action_just_pressed("swap_weapon"):
		use_tranq = !use_tranq
		print("Senjata sekarang:", "BIUS" if use_tranq else "BIASA")
		
	if Input.is_action_just_pressed("toggle_kacamata"):
		if is_using_kacamata == false:
			is_using_kacamata = true
			kacamata.enabled = true
			print("Kacamata digunakan")
		else:
			is_using_kacamata = false
			kacamata.enabled = false
			print("Kacamata dimatikan")
		
	var input_dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if input_dir != Vector2.ZERO:
		facing_direction = input_dir.normalized()

	# putar node cahaya ke arah karakter
	kacamata.rotation = facing_direction.angle()

func shoot() -> void:
	if !can_shoot:
		return
	if is_reloading:
		return
	if ammo <= 0:
		reload_weapon()
		return

	can_shoot = false
	is_shooting = true
	ammo -= 1

	sprite.play("Shoot")
	gun_sound.play()

	var bullet = bullet_scene.instantiate()

	bullet.is_tranq = use_tranq
	if use_tranq:
		bullet.bullet_color = Color.CYAN
		bullet.damage = 1
	else:
		bullet.bullet_color = Color.YELLOW
		bullet.damage = 3

	get_tree().current_scene.add_child(bullet)

	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - gun_point.global_position).normalized()

	bullet.global_position = gun_point.global_position + dir * 20.0
	bullet.direction = dir
	bullet.rotation = dir.angle()
	bullet.shooter = self

	await sprite.animation_finished
	is_shooting = false

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true

func reload_weapon() -> void:
	if is_reloading:
		return
	if ammo == MAX_AMMO:
		return

	is_reloading = true
	sprite.play("Idle")

	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo = MAX_AMMO
	is_reloading = false
