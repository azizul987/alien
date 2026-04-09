extends CharacterBody2D

const SPEED := 300.0
const FIRE_RATE := 0.5
const MAX_AMMO := 9
const RELOAD_TIME := 1.0
const RELOAD_REMINDER_INTERVAL := 0.5

@onready var detector: Node2D = $TileDetector
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var gun_point: Marker2D = $Pivot/GunPoint
@onready var gun_sound: AudioStreamPlayer2D = $GunSound
@onready var deteksi: Area2D = $Deteksi
@onready var kacamata: PointLight2D = $kacamata
@onready var step_sound: AudioStreamPlayer2D = $Footstep
@onready var petunjuk: TileMapLayer = $"../Petunjuk"
@onready var tanda_tanya: Node2D = $"Tanda Tanya"

var bullet_scene = preload("res://asset/node/bullet_tscn.tscn")
const FLOATING_DAMAGE_TEXT_TSCN = preload("uid://bucnhf80vdpqa")

var can_shoot := true
var ammo := MAX_AMMO
var is_reloading := false
var is_shooting := false
var dekat_pintu := false
var use_tranq: bool = false

var is_using_kacamata := false
var facing_direction := Vector2.DOWN

var reload_reminder_cooldown := 0.0
var total_score := 0

func _ready() -> void:
	tanda_tanya.visible = false

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	update_tanda_tanya()

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

	if Input.is_action_just_pressed("reload_weapon"):
		reload_weapon()

	if Input.is_action_just_pressed("swap_weapon"):
		use_tranq = !use_tranq
		print("Senjata sekarang:", "BIUS" if use_tranq else "BIASA")

	if Input.is_action_just_pressed("toggle_kacamata"):
		is_using_kacamata = !is_using_kacamata
		kacamata.enabled = is_using_kacamata
		print("Kacamata digunakan" if is_using_kacamata else "Kacamata dimatikan")

	var input_dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if input_dir != Vector2.ZERO:
		facing_direction = input_dir.normalized()

	kacamata.rotation = facing_direction.angle()

	if ammo <= 0 and !is_reloading:
		reload_reminder_cooldown -= delta
		if reload_reminder_cooldown <= 0.0:
			show_floating_text("BUTUH RELOAD - TEKAN Z", Color.ORANGE)
			reload_reminder_cooldown = RELOAD_REMINDER_INTERVAL
	else:
		reload_reminder_cooldown = 0.0

func update_tanda_tanya() -> void:
	if petunjuk == null:
		tanda_tanya.visible = false
		return

	var local_pos = petunjuk.to_local(detector.global_position)
	var tile_pos = petunjuk.local_to_map(local_pos)
	var tile_data = petunjuk.get_cell_tile_data(tile_pos)

	if tile_data == null:
		tanda_tanya.visible = false
		return

	var nilai_petunjuk = tile_data.get_custom_data("Petunjuk")
	tanda_tanya.visible = (nilai_petunjuk == true)

func shoot() -> void:
	if !can_shoot:
		return
	if is_reloading:
		return
	if ammo <= 0:
		return

	can_shoot = false
	is_shooting = true
	ammo -= 1

	sprite.play("Shoot")
	gun_sound.play()

	var bullet = bullet_scene.instantiate()

	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - gun_point.global_position).normalized()

	bullet.is_tranq = use_tranq
	bullet.shooter = self
	bullet.direction = dir
	bullet.rotation = dir.angle()
	bullet.global_position = gun_point.global_position + dir * 20.0

	if use_tranq:
		bullet.bullet_color = Color.CYAN
		bullet.damage = 1
	else:
		bullet.bullet_color = Color.YELLOW
		bullet.damage = 1

	show_floating_text("-" + str(ammo), Color.DODGER_BLUE)

	get_tree().current_scene.add_child(bullet)

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
	show_floating_text("RELOADING...", Color.WHITE)

	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo = MAX_AMMO
	is_reloading = false

func show_floating_text(text_value: String, color: Color = Color.WHITE) -> void:
	var text_instance = FLOATING_DAMAGE_TEXT_TSCN.instantiate()
	get_tree().current_scene.add_child(text_instance)

	text_instance.global_position = global_position + Vector2(
		randf_range(-20.0, 20.0),
		randf_range(-30.0, -10.0)
	)

	if text_instance.has_method("setup"):
		text_instance.setup(text_value, color)

func add_score(amount: int) -> void:
	total_score += amount
	print("TOTAL SCORE:", total_score)
	var ui = get_tree().current_scene.get_node("Menu Pause")
	if ui and ui.has_method("set_score"):
		ui.set_score(total_score)
