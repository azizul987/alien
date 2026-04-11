extends CharacterBody2D

@export var isMoving: bool = true

# =========================
# BASE STATS
# Nilai asli sebelum dikali difficulty
# =========================
@export var base_speed: float = 38.0
@export var base_chase_speed: float = 200.0
@export var base_chase_acceleration: float = 20.0
@export var base_max_chase_speed: float = 280.0

@export var isJahat: bool = true
@export var score_value: int = 100
@export var max_hp: int = 40
@export var isBoss: bool = false
@export var spawned_direct_chase: bool = false

# NPC baik bisa tidur kalau dekat alien yang SUDAH mode Alien
@export var can_sleep_from_alien: bool = true

const SLEEP_DURATION: float = 30.0
const SLEEP_DETECTION_RADIUS: float = 400.0
const SLEEP_TEXT_INTERVAL: float = 1.0
const DEBUG_SLEEP_INTERVAL: float = 1.0

# ===== BALAS TEMBAK =====
# HANYA UNTUK NPC BAIK (isJahat = false)
const RETALIATE_RADIUS: float = 9000.0
const RETALIATE_COOLDOWN: float = 1.2
const RETALIATE_FRONT_DOT: float = -0.2
const RETALIATE_BULLET_DAMAGE: int = 1
const RETALIATE_BULLET_OFFSET: float = 18.0

# player nembak dekat NPC walau tidak kena badan
const ALERT_SHOT_RADIUS: float = 220.0
const ALERT_FRONT_DOT: float = -0.35

@onready var kiri: Marker2D = $Kiri2
@onready var kanan: Marker2D = $Kanan2
@onready var animasi: AnimatedSprite2D = $AnimatedSprite2D
@onready var kaki_kiri: Marker2D = $KakiKiri2
@onready var kaki_kanan: Marker2D = $KakiKanan2

var target_pos: Vector2 = Vector2.ZERO
var left_pos: Vector2 = Vector2.ZERO
var right_pos: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO

var jejak_scene: PackedScene = preload("res://asset/scene/jejak.tscn")
var bullet_scene: PackedScene = preload("res://asset/scene/bullet_tscn.tscn")
const FLOATING_DAMAGE_TEXT_TSCN: PackedScene = preload("uid://bucnhf80vdpqa")

var giliran_kaki_kiri: bool = true
var is_dead: bool = false
var current_hp: int = 0
var is_alien_mode: bool = false
var player: Node2D = null
var has_triggered_game_over: bool = false
var current_chase_speed: float = 0.0

# =========================
# FINAL STATS
# Nilai hasil dari base * GameSettings
# =========================
var speed: float = 0.0
var chase_speed: float = 0.0
var chase_acceleration: float = 0.0
var max_chase_speed: float = 0.0

# ===== SLEEP SYSTEM =====
var is_sleeping: bool = false
var sleep_timer: float = 0.0
var sleep_text_cooldown: float = 0.0
var remembered_target_pos: Vector2 = Vector2.ZERO

# ===== DEBUG =====
var debug_sleep_enabled: bool = true
var debug_sleep_cooldown: float = 0.0
var debug_retaliate_enabled: bool = true

# ===== BALAS TEMBAK =====
var retaliate_cooldown: float = 0.0
var alert_shot_cooldown: float = 0.0


func _ready() -> void:
	apply_difficulty_settings()

	current_hp = max_hp
	left_pos = kiri.global_position
	right_pos = kanan.global_position
	target_pos = right_pos
	current_chase_speed = chase_speed
	spawn_position = global_position
	remembered_target_pos = target_pos

	var players_untyped: Array = get_tree().get_nodes_in_group("player")
	if players_untyped.size() > 0:
		player = players_untyped[0] as Node2D

	# Kalau hasil spawn direct chase, langsung jadi mode Alien
	if spawned_direct_chase and isJahat:
		is_alien_mode = true
		isMoving = true
		current_chase_speed = chase_speed

		if animasi != null and animasi.sprite_frames.has_animation("Alien"):
			animasi.play("Alien")
			$"Suara Ngejar".play()
	else:
		is_alien_mode = false
		isMoving = true

		if animasi != null:
			if animasi.sprite_frames.has_animation("Run"):
				animasi.play("Run")

	print(
		"[READY] ", name,
		" isJahat=", isJahat,
		" isBoss=", isBoss,
		" spawned_direct_chase=", spawned_direct_chase,
		" hp=", current_hp,
		" speed=", speed,
		" chase_speed=", chase_speed,
		" chase_acceleration=", chase_acceleration,
		" max_chase_speed=", max_chase_speed
	)


func apply_difficulty_settings() -> void:
	var walk_mult: float = 1.0
	var chase_mult: float = 1.0

	# Pastikan GameSettings sudah dijadikan AutoLoad
	if GameSettings != null:
		walk_mult = GameSettings.get_enemy_speed_multiplier()
		chase_mult = GameSettings.get_enemy_chase_multiplier()

	speed = base_speed * walk_mult
	chase_speed = base_chase_speed * chase_mult
	chase_acceleration = base_chase_acceleration * chase_mult
	max_chase_speed = base_max_chase_speed * chase_mult


func refresh_stats_from_game_settings() -> void:
	apply_difficulty_settings()

	if is_alien_mode:
		current_chase_speed = min(current_chase_speed, max_chase_speed)
	else:
		current_chase_speed = chase_speed


func take_damage(amount: int, attacker = null) -> void:
	if is_dead:
		return

	# HANYA NPC BAIK yang boleh balas tembak
	if !isJahat:
		try_retaliate(attacker)

	current_hp -= amount
	current_hp = max(current_hp, 0)

	show_floating_text("-" + str(amount), Color.RED)

	# Alien jahat masuk mode alien saat ditembak
	if isJahat and current_hp > 0:
		enter_alien_mode()

	if current_hp <= 0:
		die(attacker)


func enter_alien_mode() -> void:
	if is_alien_mode:
		return

	apply_difficulty_settings()

	is_alien_mode = true
	isMoving = true
	current_chase_speed = chase_speed

	if animasi != null and animasi.sprite_frames.has_animation("Alien"):
		animasi.play("Alien")
		$"Suara Ngejar".play()


#func pass_alien_mode_to_other() -> void:
	#var candidates: Array[Node] = []
#
	#for node_untyped in get_tree().get_nodes_in_group("alien"):
		#var node: Node = node_untyped as Node
#
		#if node == self:
			#continue
		#if node == null:
			#continue
		#if !is_instance_valid(node):
			#continue
		#if node.get("is_dead") == true:
			#continue
#
		#candidates.append(node)
#
	#if candidates.is_empty():
		#print("[ALIEN MODE] tidak ada alien lain untuk mewarisi mode Alien")
		#return
#
	#var chosen: Node = null
	#var best_distance: float = INF
#
	#if player != null and is_instance_valid(player):
		#for node in candidates:
			#if node is Node2D:
				#var node2d: Node2D = node as Node2D
				#var dist: float = node2d.global_position.distance_to(player.global_position)
				#if dist < best_distance:
					#best_distance = dist
					#chosen = node
	#else:
		#chosen = candidates[0]
#
	#if chosen != null and chosen.has_method("enter_alien_mode"):
		#print("[ALIEN MODE] diwariskan ke ", chosen.name)
		#chosen.call("enter_alien_mode")


func reset_to_normal_mode() -> void:
	if is_dead:
		return

	apply_difficulty_settings()

	is_alien_mode = false
	isMoving = true
	current_chase_speed = chase_speed
	velocity = Vector2.ZERO
	global_position = spawn_position
	target_pos = right_pos
	has_triggered_game_over = false
	is_sleeping = false
	sleep_timer = 0.0
	sleep_text_cooldown = 0.0
	retaliate_cooldown = 0.0
	alert_shot_cooldown = 0.0
	spawned_direct_chase = false

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	if animasi != null and animasi.sprite_frames.has_animation("Run"):
		animasi.play("Run")
	else:
		stop_idle_animation()


func die(attacker = null) -> void:
	if is_dead:
		return

	var was_alien_mode: bool = is_alien_mode or (animasi != null and animasi.animation == "Alien")

	is_dead = true
	isMoving = false
	is_sleeping = false
	velocity = Vector2.ZERO

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	# Kalau yang mati sedang mode Alien, wariskan ke alien lain
	#if was_alien_mode:
		#pass_alien_mode_to_other()

	# BOSS MATI = MENANG, tidak peduli isJahat true/false
	if isBoss:
		print("[BOSS] boss mati -> stop spawn dan pindah ke menang.tscn")

		var spawners_untyped: Array = get_tree().get_nodes_in_group("endless_spawner")
		for spawner_untyped in spawners_untyped:
			var spawner: Node = spawner_untyped as Node
			if spawner != null and spawner.has_method("stop_endless_spawn"):
				spawner.call("stop_endless_spawn")

		if animasi != null and animasi.sprite_frames.has_animation("Death"):
			animasi.play("Death")
			await animasi.animation_finished

		$"Suara Mati".play()
		await $"Suara Mati".finished

		get_tree().change_scene_to_file("res://menang.tscn")
		return

	if attacker != null and attacker.has_method("add_score"):
		if isJahat:
			show_floating_text("+" + str(score_value), get_random_floating_color())
			attacker.add_score(score_value)
		else:
			if attacker.use_tranq:
				show_floating_text("+" + str(score_value), get_random_floating_color())
				attacker.add_score(score_value)
			else:
				show_floating_text("-" + str(score_value), Color.RED)
				attacker.add_score(-score_value)

	if animasi != null and animasi.sprite_frames.has_animation("Death"):
		animasi.play("Death")
		await animasi.animation_finished

	$"Suara Mati".play()
	await $"Suara Mati".finished
	queue_free()


func _physics_process(delta: float) -> void:
	if retaliate_cooldown > 0.0:
		retaliate_cooldown -= delta

	if alert_shot_cooldown > 0.0:
		alert_shot_cooldown -= delta

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	update_sleep_state(delta)

	if is_sleeping:
		velocity = Vector2.ZERO
		move_and_slide()
		stop_idle_animation()
		return

	# HANYA NPC BAIK yang boleh respon saat player nembak dekat dia
	if !isJahat:
		check_player_shoot_nearby()

	if !isJahat and can_sleep_from_alien:
		debug_sleep_cooldown -= delta
		if debug_sleep_cooldown <= 0.0:
			debug_sleep_cooldown = DEBUG_SLEEP_INTERVAL

			if is_near_evil_alien():
				enter_sleep()
				velocity = Vector2.ZERO
				move_and_slide()
				stop_idle_animation()
				return

	if is_alien_mode and player != null:
		var direction: Vector2 = (player.global_position - global_position).normalized()

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
		stop_idle_animation()
		return

	var to_target: Vector2 = target_pos - global_position
	var distance: float = to_target.length()
	var step: float = speed * delta

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

	if animasi != null and !is_dead and !is_sleeping and !is_alien_mode:
		if velocity.length() > 0.1:
			if animasi.sprite_frames.has_animation("Run") and animasi.animation != "Run":
				animasi.play("Run")
		else:
			stop_idle_animation()


# =========================
# BALAS TEMBAK
# =========================

func try_retaliate(attacker) -> void:
	if isJahat:
		return
	if attacker == null:
		return
	if is_dead or is_sleeping:
		return
	if retaliate_cooldown > 0.0:
		return
	if !(attacker is Node):
		return

	var attacker_node_base: Node = attacker as Node
	if !is_instance_valid(attacker_node_base):
		return
	if !attacker_node_base.is_in_group("player"):
		return
	if !(attacker_node_base is Node2D):
		return

	var attacker_node: Node2D = attacker_node_base as Node2D
	var to_attacker: Vector2 = attacker_node.global_position - global_position
	var distance: float = to_attacker.length()

	if distance > RETALIATE_RADIUS:
		return
	if to_attacker == Vector2.ZERO:
		return

	var forward: Vector2 = get_forward_direction()
	var dir_to_attacker: Vector2 = to_attacker.normalized()
	var dot: float = forward.dot(dir_to_attacker)

	if dot < RETALIATE_FRONT_DOT:
		return

	retaliate_shoot(attacker_node)


func check_player_shoot_nearby() -> void:
	if isJahat:
		return
	if player == null:
		return
	if is_dead or is_sleeping:
		return
	if retaliate_cooldown > 0.0:
		return
	if alert_shot_cooldown > 0.0:
		return
	if !is_instance_valid(player):
		return

	var player_is_shooting: bool = false

	if "is_shooting" in player:
		player_is_shooting = player.is_shooting
	elif player.has_node("Pivot/AnimatedSprite2D"):
		var p_sprite: AnimatedSprite2D = player.get_node("Pivot/AnimatedSprite2D") as AnimatedSprite2D
		if p_sprite != null and p_sprite.animation == "Shoot":
			player_is_shooting = true

	if !player_is_shooting:
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance > ALERT_SHOT_RADIUS:
		return
	if to_player == Vector2.ZERO:
		return

	var forward: Vector2 = get_forward_direction()
	var dir_to_player: Vector2 = to_player.normalized()
	var dot: float = forward.dot(dir_to_player)

	if dot < ALERT_FRONT_DOT:
		return

	alert_shot_cooldown = 0.35
	retaliate_shoot(player)


func retaliate_shoot(attacker: Node2D) -> void:
	if isJahat:
		return
	if bullet_scene == null:
		return

	retaliate_cooldown = RETALIATE_COOLDOWN

	var bullet = bullet_scene.instantiate()
	var dir: Vector2 = (attacker.global_position - global_position).normalized()

	bullet.shooter = self
	bullet.direction = dir
	bullet.damage = RETALIATE_BULLET_DAMAGE
	bullet.is_tranq = false
	bullet.bullet_color = Color.RED
	bullet.rotation = dir.angle()
	bullet.global_position = global_position + dir * RETALIATE_BULLET_OFFSET

	get_tree().current_scene.add_child(bullet)
	show_floating_text("BALAS!", Color.ORANGE)


func get_forward_direction() -> Vector2:
	if animasi != null and animasi.flip_h:
		return Vector2.LEFT
	return Vector2.RIGHT


# =========================
# SLEEP SYSTEM
# =========================

func is_near_evil_alien() -> bool:
	if is_dead or isJahat:
		return false

	for node_untyped in get_tree().get_nodes_in_group("alien"):
		var node: Node = node_untyped as Node
		if node == self:
			continue
		if node == null or !is_instance_valid(node):
			continue
		if !(node is Node2D):
			continue

		var node_is_jahat = node.get("isJahat")
		var node_is_dead = node.get("is_dead")
		var node_is_alien_mode = node.get("is_alien_mode")

		if node_is_jahat != true:
			continue
		if node_is_dead == true:
			continue

		var node_distance: float = global_position.distance_to((node as Node2D).global_position)
		if node_is_alien_mode == true and node_distance <= SLEEP_DETECTION_RADIUS:
			return true

	return false


func enter_sleep() -> void:
	if is_sleeping:
		return

	is_sleeping = true
	sleep_timer = SLEEP_DURATION
	sleep_text_cooldown = 0.0
	remembered_target_pos = target_pos
	velocity = Vector2.ZERO
	isMoving = false

	stop_idle_animation()
	show_sleep_countdown_text()


func update_sleep_state(delta: float) -> void:
	if !is_sleeping:
		return

	sleep_timer -= delta
	sleep_text_cooldown -= delta

	if sleep_text_cooldown <= 0.0:
		show_sleep_countdown_text()
		sleep_text_cooldown = SLEEP_TEXT_INTERVAL

	if sleep_timer <= 0.0:
		forget_memory()
		wake_up()


func forget_memory() -> void:
	apply_difficulty_settings()

	global_position = spawn_position
	target_pos = right_pos
	remembered_target_pos = target_pos
	is_alien_mode = false
	current_chase_speed = chase_speed
	has_triggered_game_over = false
	spawned_direct_chase = false

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	show_floating_text("HILANG INGATAN", Color.SKY_BLUE)


func wake_up() -> void:
	is_sleeping = false
	sleep_timer = 0.0
	sleep_text_cooldown = 0.0
	velocity = Vector2.ZERO
	isMoving = true

	if animasi != null and animasi.sprite_frames.has_animation("Run"):
		animasi.play("Run")
	else:
		stop_idle_animation()


func show_sleep_countdown_text() -> void:
	if !is_sleeping:
		return

	var sisa: int = int(ceil(sleep_timer))
	show_floating_text("TIDUR: " + str(sisa), Color.DEEP_SKY_BLUE)


func stop_idle_animation() -> void:
	if animasi == null:
		return
	animasi.stop()
	animasi.frame = 0


func check_player_collision() -> void:
	if has_triggered_game_over:
		return
	if !can_attack_player():
		return

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider != null and collider.is_in_group("player"):
			has_triggered_game_over = true
			if collider.has_method("game_over"):
				collider.game_over()
			else:
				get_tree().change_scene_to_file("res://kalah.tscn")
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
	if velocity.x > 0.0:
		animasi.flip_h = false
	elif velocity.x < 0.0:
		animasi.flip_h = true


func _on_timer_timeout() -> void:
	if velocity.length() > 0.0 and isJahat:
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
	var colors: Array[Color] = [
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
