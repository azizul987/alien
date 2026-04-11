extends CharacterBody2D

@export var isMoving: bool = true
@export var speed: float = 38.0
@export var chase_speed: float = 170.0
@export var chase_acceleration: float = 30.0
@export var max_chase_speed: float = 350.0
@export var isJahat: bool = true
@export var score_value: int = 100
@export var max_hp: int = 8

# NPC baik bisa tidur kalau dekat alien yang SUDAH mode Alien
@export var can_sleep_from_alien: bool = true

const SLEEP_DURATION := 30.0
const SLEEP_DETECTION_RADIUS := 400.0
const SLEEP_TEXT_INTERVAL := 1.0
const DEBUG_SLEEP_INTERVAL := 1.0

# ===== BALAS TEMBAK =====
# HANYA UNTUK NPC BAIK (isJahat = false)
const RETALIATE_RADIUS := 9000.0
const RETALIATE_COOLDOWN := 1.2
const RETALIATE_FRONT_DOT := -0.2
const RETALIATE_BULLET_DAMAGE := 1
const RETALIATE_BULLET_OFFSET := 18.0

# player nembak dekat NPC walau tidak kena badan
const ALERT_SHOT_RADIUS := 220.0
const ALERT_FRONT_DOT := -0.35

@onready var kiri: Marker2D = $Kiri
@onready var kanan: Marker2D = $Kanan
@onready var animasi: AnimatedSprite2D = $AnimatedSprite2D
@onready var kaki_kiri: Marker2D = $KakiKiri
@onready var kaki_kanan: Marker2D = $KakiKanan

var target_pos: Vector2
var left_pos: Vector2
var right_pos: Vector2
var spawn_position: Vector2

var jejak_scene = preload("res://asset/scene/jejak.tscn")
var bullet_scene = preload("res://asset/scene/bullet_tscn.tscn")
const FLOATING_DAMAGE_TEXT_TSCN = preload("uid://bucnhf80vdpqa")

var giliran_kaki_kiri: bool = true
var is_dead := false
var current_hp: int
var is_alien_mode := false
var player: Node2D = null
var has_triggered_game_over := false
var current_chase_speed: float = 0.0

# ===== SLEEP SYSTEM =====
var is_sleeping: bool = false
var sleep_timer: float = 0.0
var sleep_text_cooldown: float = 0.0
var remembered_target_pos: Vector2 = Vector2.ZERO

# ===== DEBUG =====
var debug_sleep_enabled := true
var debug_sleep_cooldown := 0.0
var debug_retaliate_enabled := true

# ===== BALAS TEMBAK =====
var retaliate_cooldown: float = 0.0
var alert_shot_cooldown: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	left_pos = kiri.global_position
	right_pos = kanan.global_position
	target_pos = right_pos
	current_chase_speed = chase_speed
	spawn_position = global_position
	remembered_target_pos = target_pos

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D

	print("[READY]", name, " isJahat=", isJahat, " can_sleep_from_alien=", can_sleep_from_alien, " hp=", current_hp)
	debug_sleep("READY | isJahat=" + str(isJahat) + " | spawn=" + str(spawn_position))

func take_damage(amount: int, attacker = null) -> void:
	if is_dead:
		return

	# HANYA NPC BAIK yang boleh balas tembak
	if !isJahat:
		try_retaliate(attacker)

	current_hp -= amount
	current_hp = max(current_hp, 0)

	show_floating_text("-" + str(amount), Color.RED)
	debug_retaliate("kena damage | hp sekarang=" + str(current_hp))

	# Alien jahat masuk mode alien saat ditembak
	if isJahat and current_hp > 0:
		enter_alien_mode()

	if current_hp <= 0:
		die(attacker)

func enter_alien_mode() -> void:
	if is_alien_mode:
		return

	is_alien_mode = true
	isMoving = true
	current_chase_speed = chase_speed

	debug_sleep("MASUK ALIEN MODE")

	if animasi != null and animasi.sprite_frames.has_animation("Alien"):
		animasi.play("Alien")
		$"Suara Ngejar".play()

func reset_to_normal_mode() -> void:
	if is_dead:
		return

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

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	if animasi != null and animasi.sprite_frames.has_animation("Run"):
		animasi.play("Run")
	else:
		stop_idle_animation()

	debug_sleep("RESET KE MODE NORMAL")

func die(attacker = null) -> void:
	if is_dead:
		return

	is_dead = true
	isMoving = false
	is_sleeping = false
	velocity = Vector2.ZERO

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	debug_sleep("MATI")

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

func try_retaliate(attacker: Variant) -> void:
	# NPC jahat tidak boleh balas tembak
	if isJahat:
		debug_retaliate("gagal: npc jahat tidak boleh balas tembak")
		return

	if attacker == null:
		debug_retaliate("gagal: attacker null")
		return

	if is_dead or is_sleeping:
		debug_retaliate("gagal: npc mati atau tidur")
		return

	if retaliate_cooldown > 0.0:
		debug_retaliate("gagal: masih cooldown")
		return

	if !(attacker is Node):
		debug_retaliate("gagal: attacker bukan Node")
		return

	var attacker_node_base: Node = attacker as Node

	if !is_instance_valid(attacker_node_base):
		debug_retaliate("gagal: attacker tidak valid")
		return

	if !attacker_node_base.is_in_group("player"):
		debug_retaliate("gagal: attacker bukan player")
		return

	if !(attacker_node_base is Node2D):
		debug_retaliate("gagal: attacker bukan Node2D")
		return

	var attacker_node: Node2D = attacker_node_base as Node2D
	var to_attacker: Vector2 = attacker_node.global_position - global_position
	var distance: float = to_attacker.length()

	debug_retaliate("cek balas tembak | player=" + attacker_node.name + " | jarak=" + str(snappedf(distance, 0.1)))

	if distance > RETALIATE_RADIUS:
		debug_retaliate("gagal: player terlalu jauh")
		return

	if to_attacker == Vector2.ZERO:
		debug_retaliate("gagal: posisi sama")
		return

	var forward: Vector2 = get_forward_direction()
	var dir_to_attacker: Vector2 = to_attacker.normalized()
	var dot: float = forward.dot(dir_to_attacker)

	debug_retaliate("cek depan | forward=" + str(forward) + " | dir=" + str(dir_to_attacker) + " | dot=" + str(snappedf(dot, 0.01)))

	if dot < RETALIATE_FRONT_DOT:
		debug_retaliate("gagal: player tidak di depan")
		return

	retaliate_shoot(attacker_node)

func check_player_shoot_nearby() -> void:
	# NPC jahat tidak boleh balas tembak
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

	var player_is_shooting = false

	if "is_shooting" in player:
		player_is_shooting = player.is_shooting
	elif player.has_node("Pivot/AnimatedSprite2D"):
		var p_sprite: AnimatedSprite2D = player.get_node("Pivot/AnimatedSprite2D")
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

	debug_retaliate("cek tembakan dekat | jarak=" + str(snappedf(distance, 0.1)) + " | dot=" + str(snappedf(dot, 0.01)))

	if dot < ALERT_FRONT_DOT:
		debug_retaliate("gagal respon tembakan dekat: player tidak di depan")
		return

	alert_shot_cooldown = 0.35
	retaliate_shoot(player)

func retaliate_shoot(attacker: Node2D) -> void:
	# NPC jahat tidak boleh balas tembak
	if isJahat:
		debug_retaliate("gagal: npc jahat tidak boleh menembak")
		return

	if bullet_scene == null:
		debug_retaliate("gagal: bullet_scene null")
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
	debug_retaliate("SUKSES BALAS TEMBAK ke player")

func get_forward_direction() -> Vector2:
	if animasi != null and animasi.flip_h:
		return Vector2.LEFT
	return Vector2.RIGHT

func debug_retaliate(message: String) -> void:
	if debug_retaliate_enabled:
		print("[RETALIATE DEBUG][" + str(name) + "] " + message)

# =========================
# SLEEP SYSTEM
# =========================

func is_near_evil_alien() -> bool:
	if is_dead:
		debug_sleep("batal cek: NPC ini sudah mati")
		return false

	if isJahat:
		debug_sleep("batal cek: node ini jahat, jadi tidak bisa tidur")
		return false

	var found_any_alien := false

	for node in get_tree().get_nodes_in_group("alien"):
		if node == self:
			continue

		if node == null:
			debug_sleep("skip: ada node alien null")
			continue

		if !is_instance_valid(node):
			debug_sleep("skip: ada node alien tidak valid")
			continue

		found_any_alien = true

		var enemy_name := str(node.name)
		var node_is_jahat = node.get("isJahat")
		var node_is_dead = node.get("is_dead")
		var node_is_alien_mode = node.get("is_alien_mode")
		var node_anim := ""
		var node_distance: float = global_position.distance_to(node.global_position)

		if node.has_node("AnimatedSprite2D"):
			var sp: AnimatedSprite2D = node.get_node("AnimatedSprite2D")
			if sp != null:
				node_anim = sp.animation

		debug_sleep(
			"cek -> " + enemy_name +
			" | isJahat=" + str(node_is_jahat) +
			" | is_dead=" + str(node_is_dead) +
			" | is_alien_mode=" + str(node_is_alien_mode) +
			" | anim=" + str(node_anim) +
			" | jarak=" + str(snappedf(node_distance, 0.1))
		)

		if node_is_jahat != true:
			debug_sleep("skip " + enemy_name + ": bukan jahat")
			continue

		if node_is_dead == true:
			debug_sleep("skip " + enemy_name + ": sudah mati")
			continue

		var is_really_alien := false

		if node_is_alien_mode == true:
			is_really_alien = true

		if node_anim == "Alien":
			is_really_alien = true

		if !is_really_alien:
			debug_sleep("skip " + enemy_name + ": jahat tapi belum mode Alien")
			continue

		if node_distance <= SLEEP_DETECTION_RADIUS:
			debug_sleep("KENA DETEKSI dari " + enemy_name)
			return true
		else:
			debug_sleep("skip " + enemy_name + ": jarak terlalu jauh")

	if !found_any_alien:
		debug_sleep("tidak ada node dalam group 'alien'")

	return false

func enter_sleep() -> void:
	if is_sleeping:
		debug_sleep("enter_sleep dibatalkan: sudah sleeping")
		return

	is_sleeping = true
	sleep_timer = SLEEP_DURATION
	sleep_text_cooldown = 0.0
	remembered_target_pos = target_pos
	velocity = Vector2.ZERO
	isMoving = false

	debug_sleep("NPC MASUK MODE TIDUR selama " + str(SLEEP_DURATION) + " detik")

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
		debug_sleep("countdown tidur: " + str(int(ceil(sleep_timer))))

	if sleep_timer <= 0.0:
		debug_sleep("timer tidur habis -> hilang ingatan")
		forget_memory()
		wake_up()

func forget_memory() -> void:
	global_position = spawn_position
	target_pos = right_pos
	remembered_target_pos = target_pos
	is_alien_mode = false
	current_chase_speed = chase_speed
	has_triggered_game_over = false

	if $"Suara Ngejar".playing:
		$"Suara Ngejar".stop()

	debug_sleep("NPC HILANG INGATAN -> balik ke spawn")
	show_floating_text("HILANG INGATAN", Color.SKY_BLUE)

func wake_up() -> void:
	is_sleeping = false
	sleep_timer = 0.0
	sleep_text_cooldown = 0.0
	velocity = Vector2.ZERO
	isMoving = true

	debug_sleep("NPC BANGUN dari tidur")

	if animasi != null and animasi.sprite_frames.has_animation("Run"):
		animasi.play("Run")
	else:
		stop_idle_animation()

func show_sleep_countdown_text() -> void:
	if !is_sleeping:
		return

	var sisa := int(ceil(sleep_timer))
	show_floating_text("TIDUR: " + str(sisa), Color.DEEP_SKY_BLUE)

func debug_sleep(message: String) -> void:
	if debug_sleep_enabled:
		print("[SLEEP DEBUG][" + str(name) + "] " + message)

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
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider != null and collider.is_in_group("player"):
			has_triggered_game_over = true
			debug_sleep("MENABRAK PLAYER")

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
