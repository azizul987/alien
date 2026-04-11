extends Node2D

@export var alien_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_alive_aliens: int = 8
@export var spawn_enabled: bool = true
@export var use_spawn_points: bool = true

@export var min_spawn_distance_to_player: float = 220.0
@export var min_spawn_distance_to_other_aliens: float = 40.0
@export var max_spawn_position_attempts: int = 8

@export_range(0.0, 1.0) var base_direct_chase_chance: float = 0.20
@export_range(0.0, 1.0) var direct_chance_step: float = 0.10
@export_range(0.0, 1.0) var max_direct_chase_chance: float = 0.80
@export var direct_chance_increase_interval: float = 40.0

@export var max_direct_chasers_alive: int = 1
@export var force_min_one_direct_chaser: bool = true

# ===== ANIMASI SPAWN =====
@export var spawn_animation_name: String = "spawn"
@export var delay_after_animation: float = 2.0

# kalau false dan animasi tidak ada, tetap spawn setelah delay
@export var require_animation_before_spawn: bool = false

var current_aliens: Array[Node] = []
var player: Node2D = null

var elapsed_battle_time: float = 0.0
var current_direct_chase_chance: float = 0.20
var is_spawn_sequence_running: bool = false
var spawn_request_pending: bool = false

@onready var timer: Timer = $Timer
@onready var spawn_points_root: Node = $SpawnPoints
@onready var anim_player: AnimationPlayer = $"../AnimationPlayer"

func _ready() -> void:
	add_to_group("endless_spawner")

	if timer == null:
		push_error("Timer tidak ditemukan pada EndlessSpawner")
		return

	var players_untyped: Array = get_tree().get_nodes_in_group("player")
	if players_untyped.size() > 0:
		player = players_untyped[0] as Node2D

	current_direct_chase_chance = base_direct_chase_chance

	timer.wait_time = spawn_interval
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

	print("[ENDLESS SPAWNER] siap | interval=", spawn_interval, " | max=", max_alive_aliens)
	print("[ENDLESS SPAWNER] peluang direct awal = ", current_direct_chase_chance)

	if anim_player == null:
		print("[ENDLESS SPAWNER] AnimationPlayer tidak ditemukan, spawn pakai delay saja")
	else:
		print("[ENDLESS SPAWNER] pakai AnimationPlayer: ", anim_player.name)

func _process(delta: float) -> void:
	cleanup_current_aliens()

	if !spawn_enabled:
		if timer != null and !timer.is_stopped():
			timer.stop()
		return

	elapsed_battle_time += delta
	update_direct_chase_chance()

func cleanup_current_aliens() -> void:
	var cleaned: Array[Node] = []
	for alien in current_aliens:
		if alien != null and is_instance_valid(alien):
			cleaned.append(alien)
	current_aliens = cleaned

func update_direct_chase_chance() -> void:
	var step_count: int = int(floor(elapsed_battle_time / direct_chance_increase_interval))
	var new_chance: float = base_direct_chase_chance + (float(step_count) * direct_chance_step)
	new_chance = min(new_chance, max_direct_chase_chance)

	if !is_equal_approx(new_chance, current_direct_chase_chance):
		current_direct_chase_chance = new_chance
		print("[ENDLESS SPAWNER] peluang direct naik jadi ", current_direct_chase_chance, " | waktu=", int(elapsed_battle_time))

func _on_timer_timeout() -> void:
	if !spawn_enabled:
		return
	if is_spawn_sequence_running:
		return
	if alien_scene == null:
		push_error("alien_scene belum diisi di inspector")
		return

	cleanup_current_aliens()

	if current_aliens.size() >= max_alive_aliens:
		print("[ENDLESS SPAWNER] batas alien aktif tercapai: ", current_aliens.size())
		return

	spawn_request_pending = true
	start_spawn_sequence()

func start_spawn_sequence() -> void:
	if is_spawn_sequence_running:
		return
	if !spawn_request_pending:
		return

	is_spawn_sequence_running = true

	if timer != null and !timer.is_stopped():
		timer.stop()

	await play_spawn_animation_and_delay()

	if spawn_request_pending:
		spawn_alien()
		spawn_request_pending = false

	is_spawn_sequence_running = false

	if spawn_enabled and timer != null:
		timer.start()

func play_spawn_animation_and_delay() -> void:
	var played_animation: bool = false

	if anim_player != null and anim_player.has_animation(spawn_animation_name):
		played_animation = true
		print("[SPAWNER] animasi spawn mulai")
		anim_player.play(spawn_animation_name)

		while anim_player.current_animation == spawn_animation_name and anim_player.is_playing():
			await get_tree().process_frame

		print("[SPAWNER] animasi spawn selesai")

	if !played_animation:
		if require_animation_before_spawn:
			print("[SPAWNER] spawn dibatalkan: animasi spawn tidak ditemukan")
			spawn_request_pending = false
			return
		else:
			print("[SPAWNER] animasi spawn tidak ada, lanjut pakai delay biasa")

	if delay_after_animation > 0.0:
		print("[SPAWNER] tunggu ", delay_after_animation, " detik")
		await get_tree().create_timer(delay_after_animation).timeout

func spawn_alien() -> void:
	if !spawn_enabled:
		return

	var alien: Node = alien_scene.instantiate()
	if alien == null:
		print("[ENDLESS SPAWNER] gagal spawn: alien_scene null")
		return

	var spawn_position: Variant = get_valid_spawn_position()
	if spawn_position == null:
		print("[ENDLESS SPAWNER] gagal spawn: tidak ada titik aman")
		return

	if alien is Node2D:
		var alien2d: Node2D = alien as Node2D
		alien2d.global_position = spawn_position as Vector2

	var direct_chasers_alive: int = get_direct_chasers_alive_count()
	var become_direct_chaser: bool = false

	if direct_chasers_alive < max_direct_chasers_alive:
		if force_min_one_direct_chaser and direct_chasers_alive <= 0:
			become_direct_chaser = true
		else:
			become_direct_chaser = randf() < current_direct_chase_chance

	if "spawned_direct_chase" in alien:
		alien.set("spawned_direct_chase", become_direct_chaser)

	if "is_alien_mode" in alien and become_direct_chaser:
		alien.set("is_alien_mode", true)

	get_tree().current_scene.add_child(alien)
	current_aliens.append(alien)

	print(
		"[ENDLESS SPAWNER] alien spawn | aktif=",
		current_aliens.size(),
		" | direct=",
		become_direct_chaser,
		" | direct_alive=",
		get_direct_chasers_alive_count(),
		" | chance=",
		current_direct_chase_chance
	)

func get_direct_chasers_alive_count() -> int:
	var count: int = 0

	for alien in current_aliens:
		if alien == null or !is_instance_valid(alien):
			continue
		if "spawned_direct_chase" in alien and alien.get("spawned_direct_chase") == true:
			count += 1

	return count

func get_valid_spawn_position() -> Variant:
	if !use_spawn_points or spawn_points_root == null or spawn_points_root.get_child_count() == 0:
		if is_spawn_position_safe(global_position):
			return global_position
		return null

	var points: Array[Node2D] = []
	for child_untyped in spawn_points_root.get_children():
		if child_untyped is Node2D:
			var child: Node2D = child_untyped as Node2D
			points.append(child)

	if points.is_empty():
		if is_spawn_position_safe(global_position):
			return global_position
		return null

	for i in range(max_spawn_position_attempts):
		var idx: int = randi() % points.size()
		var point: Node2D = points[idx]
		if is_spawn_position_safe(point.global_position):
			return point.global_position

	return null

func is_spawn_position_safe(pos: Vector2) -> bool:
	if player != null and is_instance_valid(player):
		if pos.distance_to(player.global_position) < min_spawn_distance_to_player:
			return false

	for alien in current_aliens:
		if alien != null and is_instance_valid(alien) and alien is Node2D:
			var alien2d: Node2D = alien as Node2D
			if pos.distance_to(alien2d.global_position) < min_spawn_distance_to_other_aliens:
				return false

	return true

func stop_endless_spawn() -> void:
	spawn_enabled = false
	spawn_request_pending = false

	if timer != null:
		timer.stop()

	print("[ENDLESS SPAWNER] spawn dihentikan karena boss mati")

func start_endless_spawn() -> void:
	spawn_enabled = true

	if timer != null and !is_spawn_sequence_running:
		timer.start()

	print("[ENDLESS SPAWNER] spawn dimulai lagi")
