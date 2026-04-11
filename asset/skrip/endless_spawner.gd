extends Node2D

@export var alien_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_alive_aliens: int = 3
@export var min_distance_from_player: float = 220.0
@export var max_distance_from_player: float = 420.0

@export var direct_chase_on_spawn: bool = true
@export_range(0.0, 1.0, 0.01) var base_direct_chase_chance: float = 0.35
@export_range(0.0, 1.0, 0.01) var chance_increase_on_fail: float = 0.15

@export var require_animation_before_spawn: bool = false
@export var spawn_animation_name: String = "spawn"
@export var delay_after_animation: float = 0.0

@onready var timer: Timer = $Timer
@onready var anim_player: AnimationPlayer = $"../AnimationPlayer"

var player: Node2D = null
var alive_aliens: Array[Node] = []

var current_direct_chase_chance: float = 0.0
var spawn_request_pending: bool = false
var is_spawn_sequence_running: bool = false


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


func _process(_delta: float) -> void:
	_cleanup_invalid_aliens()


func _on_timer_timeout() -> void:
	_cleanup_invalid_aliens()

	if !spawn_enabled():
		return

	if spawn_request_pending:
		return

	if alive_aliens.size() >= max_alive_aliens:
		return

	spawn_request_pending = true
	start_spawn_sequence()


func spawn_enabled() -> bool:
	return alien_scene != null and player != null


func start_spawn_sequence() -> void:
	if is_spawn_sequence_running:
		return

	is_spawn_sequence_running = true

	if timer != null and !timer.is_stopped():
		timer.stop()

	await play_spawn_animation_and_delay()

	if spawn_request_pending:
		spawn_alien()

	spawn_request_pending = false
	is_spawn_sequence_running = false

	if timer != null:
		timer.start()


func play_spawn_animation_and_delay() -> void:
	var played_animation: bool = false

	if anim_player != null:
		# Tunggu animasi lain yang sedang berjalan selesai dulu
		while anim_player.is_playing():
			print("[SPAWNER] menunggu animasi aktif selesai: ", anim_player.current_animation)
			await anim_player.animation_finished

		# Setelah player idle, baru mainkan animasi spawn
		if anim_player.has_animation(spawn_animation_name):
			played_animation = true
			print("[SPAWNER] animasi spawn mulai: ", spawn_animation_name)
			anim_player.play(spawn_animation_name)
			await anim_player.animation_finished
			print("[SPAWNER] animasi spawn selesai: ", spawn_animation_name)

	if !played_animation:
		if require_animation_before_spawn:
			print("[SPAWNER] spawn dibatalkan: animasi spawn tidak ditemukan")
			spawn_request_pending = false
			return
		else:
			print("[SPAWNER] animasi spawn tidak ada, lanjut tanpa animasi")

	if delay_after_animation > 0.0:
		print("[SPAWNER] tunggu delay setelah animasi: ", delay_after_animation)
		await get_tree().create_timer(delay_after_animation).timeout


func spawn_alien() -> void:
	if alien_scene == null:
		return

	if player == null or !is_instance_valid(player):
		var players_untyped: Array = get_tree().get_nodes_in_group("player")
		if players_untyped.size() > 0:
			player = players_untyped[0] as Node2D

	if player == null:
		print("[ENDLESS SPAWNER] player tidak ditemukan, spawn dibatalkan")
		return

	var alien_instance: Node = alien_scene.instantiate()
	if alien_instance == null:
		print("[ENDLESS SPAWNER] gagal instantiate alien_scene")
		return

	var alien_node := alien_instance as Node2D
	if alien_node == null:
		print("[ENDLESS SPAWNER] alien_scene bukan Node2D")
		alien_instance.queue_free()
		return

	alien_node.global_position = get_random_spawn_position()

	var use_direct_chase := false
	if direct_chase_on_spawn:
		var roll := randf()
		use_direct_chase = roll <= current_direct_chase_chance

		if use_direct_chase:
			current_direct_chase_chance = base_direct_chase_chance
			print("[SPAWNER] direct chase AKTIF | roll=", roll, " | reset chance=", current_direct_chase_chance)
		else:
			current_direct_chase_chance = min(current_direct_chase_chance + chance_increase_on_fail, 1.0)
			print("[SPAWNER] direct chase gagal | roll=", roll, " | chance naik jadi=", current_direct_chase_chance)

	if alien_instance.has_method("set"):
		alien_instance.set("spawned_direct_chase", use_direct_chase)

	get_parent().add_child(alien_instance)
	alive_aliens.append(alien_instance)

	if alien_instance.tree_exited.is_connected(_on_alien_exited) == false:
		alien_instance.tree_exited.connect(_on_alien_exited.bind(alien_instance))

	print("[ENDLESS SPAWNER] alien spawn di ", alien_node.global_position, " | alive=", alive_aliens.size())


func get_random_spawn_position() -> Vector2:
	if player == null:
		return global_position

	var angle := randf() * TAU
	var distance := randf_range(min_distance_from_player, max_distance_from_player)
	var offset := Vector2.RIGHT.rotated(angle) * distance
	return player.global_position + offset


func _on_alien_exited(alien: Node) -> void:
	alive_aliens.erase(alien)
	print("[ENDLESS SPAWNER] alien keluar | alive=", alive_aliens.size())


func _cleanup_invalid_aliens() -> void:
	var valid_aliens: Array[Node] = []
	for alien in alive_aliens:
		if is_instance_valid(alien):
			valid_aliens.append(alien)
	alive_aliens = valid_aliens
