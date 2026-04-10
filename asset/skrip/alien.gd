extends CharacterBody2D

@export var isMoving: bool = true
@export var speed: float = 38.0
@export var chase_speed: float = 170.0
@export var chase_acceleration: float = 30.0
@export var max_chase_speed: float = 350.0
@export var isJahat: bool = true
@export var score_value: int = 100
@export var max_hp: int = 8

@onready var kiri: Marker2D = $Kiri
@onready var kanan: Marker2D = $Kanan
@onready var animasi: AnimatedSprite2D = $AnimatedSprite2D
@onready var kaki_kiri: Marker2D = $KakiKiri
@onready var kaki_kanan: Marker2D = $KakiKanan

var target_pos: Vector2
var left_pos: Vector2
var right_pos: Vector2

var jejak_scene = preload("res://asset/scene/jejak.tscn")
const FLOATING_DAMAGE_TEXT_TSCN = preload("uid://bucnhf80vdpqa")

var giliran_kaki_kiri: bool = true
var is_dead := false
var current_hp: int
var is_alien_mode := false
var player: Node2D = null
var has_triggered_game_over := false
var current_chase_speed: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	left_pos = kiri.global_position
	right_pos = kanan.global_position
	target_pos = right_pos
	current_chase_speed = chase_speed

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D

func take_damage(amount: int, attacker = null) -> void:
	if is_dead:
		return

	if isJahat:
		current_hp -= amount
		current_hp = max(current_hp, 0)

		if current_hp > 0:
			show_floating_text("-" + str(amount), Color.RED)

			if isJahat:
				enter_alien_mode()
			return

		die(attacker)
		
	else:
		die(attacker)

func enter_alien_mode() -> void:
	if is_alien_mode:
		return

	is_alien_mode = true
	isMoving = true
	current_chase_speed = chase_speed

	if animasi.sprite_frames.has_animation("Alien"):
		animasi.play("Alien")
		$"Suara Ngejar".play()
	
func die(attacker = null) -> void:
	if is_dead:
		return

	is_dead = true
	isMoving = false
	velocity = Vector2.ZERO

	if isJahat:
		show_floating_text("+" + str(score_value), get_random_floating_color())

		if attacker != null and attacker.has_method("add_score"):
			attacker.add_score(score_value)
	else:
		if attacker.use_tranq:
			show_floating_text("+" + str(score_value), get_random_floating_color())
			attacker.add_score(score_value)
		else:
			show_floating_text("-" + str(score_value), Color.RED)
			attacker.add_score(-score_value)
		
	if animasi.sprite_frames.has_animation("Death"):
		animasi.play("Death")
		await animasi.animation_finished

	$"Suara Mati".play()
	await $"Suara Mati".finished
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_alien_mode and player != null:
		var direction = (player.global_position - global_position).normalized()

		current_chase_speed += chase_acceleration * delta
		current_chase_speed = min(current_chase_speed, max_chase_speed)

		velocity = direction * current_chase_speed
		move_and_slide()
		update_flip()
		check_player_collision()
		return

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
	update_flip()

func check_player_collision() -> void:
	if has_triggered_game_over:
		return

	if !can_attack_player():
		return

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider != null and collider.is_in_group("player"):
			has_triggered_game_over = true

			if collider.has_method("game_over"):
				collider.game_over()
			else:
				get_tree().reload_current_scene()

			return

func can_attack_player() -> bool:
	if is_dead:
		return false

	if is_alien_mode:
		return true

	if animasi.animation == "Alien":
		return true

	return false

func update_flip() -> void:
	if velocity.x > 0:
		animasi.flip_h = false
	elif velocity.x < 0:
		animasi.flip_h = true

func _on_timer_timeout() -> void:
	if velocity.length() > 0:
		if isJahat:
			buat_jejak()

func buat_jejak() -> void:
	var jejak_baru = jejak_scene.instantiate()
	get_parent().add_child(jejak_baru)

	var marker_aktif: Marker2D
	if giliran_kaki_kiri:
		marker_aktif = kaki_kiri
	else:
		marker_aktif = kaki_kanan

	jejak_baru.global_position = marker_aktif.global_position
	giliran_kaki_kiri = !giliran_kaki_kiri

func show_floating_text(text_value: String, color: Color = Color.WHITE) -> void:
	var text_instance = FLOATING_DAMAGE_TEXT_TSCN.instantiate()
	get_tree().current_scene.add_child(text_instance)

	text_instance.global_position = global_position + Vector2(
		randf_range(-12.0, 12.0),
		randf_range(-24.0, -8.0)
	)

	if text_instance.has_method("setup"):
		text_instance.setup(text_value, color)

func get_random_floating_color() -> Color:
	var colors := [
		Color.YELLOW,
		Color.GREEN,
		Color.CYAN,
		Color.BLUE,
		Color.MAGENTA,
		Color.ORANGE,
		Color.PINK,
		Color.WHITE
	]
	return colors[randi() % colors.size()]
