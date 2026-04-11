extends CharacterBody2D

const SPEED := 250.0
const FIRE_RATE := 0.5
const RELOAD_TIME := 1.0
const RELOAD_REMINDER_INTERVAL := 0.5

const HIDE_PER_USE_DURATION := 2.0
const DEFAULT_HIDE_TOTAL_DURATION := 6.0
const HIDE_GROUP_SCAN_RADIUS := 3

const TANDA_SWAP_DURATION := 0.5
const TANDA_RELOAD_DURATION := 0.5

const HIDE_COUNTDOWN_TEXT_INTERVAL := 1.0

@onready var detector: Node2D = $TileDetector
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var gun_point: Marker2D = $Pivot/GunPoint
@onready var gun_sound: AudioStreamPlayer2D = $GunSound
@onready var deteksi: Area2D = $Deteksi
@onready var kacamata: PointLight2D = $kacamata
@onready var step_sound: AudioStreamPlayer2D = $Footstep
@onready var petunjuk: TileMapLayer = $"../Petunjuk"
@onready var hide_object: TileMapLayer = $"../HideObject"
@onready var tanda_tanya: Node2D = $"Tanda Tanya"
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@onready var tanda_peluru: CanvasItem = $"Tanda Peluru"
@onready var tanda_bius: CanvasItem = $"Tanda Bius"
@onready var tanda_sembunyi: Node2D = $"Tanda Sembunyi"

var bullet_scene = preload("res://asset/scene/bullet_tscn.tscn")
const FLOATING_DAMAGE_TEXT_TSCN = preload("uid://bucnhf80vdpqa")

var can_shoot := true
var max_ammo := 4
var ammo := 4
var is_reloading := false
var is_shooting := false
var dekat_pintu := false
var use_tranq: bool = false

var is_using_kacamata := false
var facing_direction := Vector2.DOWN

var reload_reminder_cooldown := 0.0
var total_score := 0
var current_petunjuk_id: int = 0

# ===== HIDE SYSTEM =====
var is_hiding: bool = false
var hide_timer: float = 0.0
var current_hide_group: int = -1
var current_hide_tiles: Array[Vector2i] = []
var debug_hide_enabled: bool = true
var hide_group_used_time: Dictionary = {}
var hide_group_total_time: Dictionary = {}
var hide_countdown_text_cooldown: float = 0.0

# ===== TANDA SYSTEM =====
var tanda_request_id: int = 0

var is_game_over := false

func _ready() -> void:
	max_ammo = GameSettings.get_player_ammo()
	ammo = max_ammo

	tanda_tanya.visible = false

	if tanda_peluru != null:
		tanda_peluru.visible = false
	if tanda_bius != null:
		tanda_bius.visible = false
	if tanda_sembunyi != null:
		tanda_sembunyi.visible = false

	visible = true

func _physics_process(delta: float) -> void:
	if is_game_over:
		velocity = Vector2.ZERO

		if step_sound.playing:
			step_sound.stop()

		move_and_slide()
		return

	var ui = get_ui()

	# Dokumen terbuka = player berhenti
	if ui != null and ui.is_dokumen_open():
		velocity = Vector2.ZERO
		if step_sound.playing:
			step_sound.stop()
		update_tanda_sembunyi()
		move_and_slide()
		return

	# Update sistem hide
	update_hide_state(delta)

	# Saat sedang sembunyi, player tidak bisa gerak
	if is_hiding:
		velocity = Vector2.ZERO
		if step_sound.playing:
			step_sound.stop()

		update_tanda_sembunyi()
		move_and_slide()

		if Input.is_action_just_pressed("interact"):
			exit_hide()

		return

	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	update_tanda_tanya()
	update_tanda_sembunyi()

	var mouse_pos := get_global_mouse_position()

	if input_x < 0:
		sprite.flip_h = true
	elif input_x > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = mouse_pos.x < global_position.x

	if !is_game_over and !is_shooting and !is_reloading:
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
		swap_weapon()

	if Input.is_action_just_pressed("toggle_kacamata"):
		is_using_kacamata = !is_using_kacamata
		kacamata.enabled = is_using_kacamata

	if Input.is_action_just_pressed("interact"):
		var hide_data := get_hide_tile_data()
		if !hide_data.is_empty() and hide_data["hideable"]:
			enter_hide()
			return

		if current_petunjuk_id > 0 and ui != null and !ui.is_dokumen_open():
			ui.buka_dokumen(current_petunjuk_id)

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

func get_ui():
	if get_tree() == null or get_tree().current_scene == null:
		return null

	if get_tree().current_scene.has_node("Menu Pause"):
		return get_tree().current_scene.get_node("Menu Pause")

	return null

func update_tanda_tanya() -> void:
	current_petunjuk_id = get_petunjuk_value()
	tanda_tanya.visible = current_petunjuk_id > 0 and !is_hiding and !is_game_over

func update_tanda_sembunyi() -> void:
	if tanda_sembunyi == null:
		return

	if is_hiding or is_game_over:
		tanda_sembunyi.visible = false
		return

	var hide_data := get_hide_tile_data()
	tanda_sembunyi.visible = !hide_data.is_empty() and hide_data["hideable"]

func get_petunjuk_value() -> int:
	if petunjuk == null:
		return 0

	var local_pos = petunjuk.to_local(detector.global_position)
	var tile_pos = petunjuk.local_to_map(local_pos)
	var tile_data = petunjuk.get_cell_tile_data(tile_pos)

	if tile_data == null:
		return 0

	var nilai_petunjuk = tile_data.get_custom_data("Petunjuk")
	if nilai_petunjuk == null:
		return 0

	return int(nilai_petunjuk)

# =========================
# HIDE SYSTEM
# =========================

func get_hide_tile_data() -> Dictionary:
	if hide_object == null:
		return {}

	var local_pos = hide_object.to_local(detector.global_position)
	var tile_pos = hide_object.local_to_map(local_pos)
	var tile_data = hide_object.get_cell_tile_data(tile_pos)

	if tile_data == null:
		return {}

	var hideable = tile_data.get_custom_data("Hideable")
	var group_id = tile_data.get_custom_data("HideGroup")
	var hide_total_duration = tile_data.get_custom_data("HideDuration")

	return {
		"tile_pos": tile_pos,
		"hideable": hideable == true,
		"group_id": int(group_id) if group_id != null else -1,
		"hide_total_duration": float(hide_total_duration) if hide_total_duration != null else DEFAULT_HIDE_TOTAL_DURATION
	}

func get_all_tiles_in_hide_group(center_tile: Vector2i, group_id: int, radius: int = HIDE_GROUP_SCAN_RADIUS) -> Array[Vector2i]:
	var results: Array[Vector2i] = []

	if hide_object == null or group_id < 0:
		return results

	for x in range(center_tile.x - radius, center_tile.x + radius + 1):
		for y in range(center_tile.y - radius, center_tile.y + radius + 1):
			var pos = Vector2i(x, y)
			var tile_data = hide_object.get_cell_tile_data(pos)

			if tile_data == null:
				continue

			var hideable = tile_data.get_custom_data("Hideable")
			var other_group = tile_data.get_custom_data("HideGroup")

			if hideable == true and other_group != null and int(other_group) == group_id:
				results.append(pos)

	return results

func reset_all_aliens_to_normal() -> void:
	for node in get_tree().get_nodes_in_group("alien"):
		if node != null and node.has_method("reset_to_normal_mode"):
			node.reset_to_normal_mode()

func enter_hide() -> void:
	if is_hiding or is_game_over:
		return

	var data := get_hide_tile_data()
	if data.is_empty():
		debug_hide("gagal hide: tile tidak ditemukan")
		return

	if !data["hideable"]:
		debug_hide("gagal hide: tile bukan hideable")
		return

	var tile_pos: Vector2i = data["tile_pos"]
	var group_id: int = data["group_id"]
	var total_duration: float = data["hide_total_duration"]

	if group_id < 0:
		debug_hide("gagal hide: HideGroup belum diisi")
		return

	current_hide_tiles = get_all_tiles_in_hide_group(tile_pos, group_id)

	if current_hide_tiles.is_empty():
		debug_hide("gagal hide: tile group tidak ketemu")
		return

	if !hide_group_total_time.has(group_id):
		hide_group_total_time[group_id] = total_duration

	if !hide_group_used_time.has(group_id):
		hide_group_used_time[group_id] = 0.0

	var sisa_total: float = hide_group_total_time[group_id] - hide_group_used_time[group_id]

	if sisa_total <= 0.0:
		debug_hide("objek hide sudah habis total waktunya | group=" + str(group_id))
		break_hide_tiles_by_group(group_id, tile_pos)
		return

	is_hiding = true
	hide_timer = min(HIDE_PER_USE_DURATION, sisa_total)
	current_hide_group = group_id
	hide_countdown_text_cooldown = 0.0

	velocity = Vector2.ZERO
	tanda_tanya.visible = false

	if tanda_sembunyi != null:
		tanda_sembunyi.visible = false

	if collision_shape != null:
		collision_shape.disabled = true

	if step_sound.playing:
		step_sound.stop()

	reset_all_aliens_to_normal()

	if sprite != null:
		sprite.play("hide")
		await sprite.animation_finished

		if !is_hiding or is_game_over:
			return

	visible = false
	show_hide_countdown_text()

	debug_hide(
		"masuk hide | group=" + str(current_hide_group) +
		" | dipakai=" + str(hide_group_used_time[group_id]) +
		" | total=" + str(hide_group_total_time[group_id]) +
		" | sesi=" + str(hide_timer)
	)

func exit_hide() -> void:
	if !is_hiding:
		return

	is_hiding = false
	hide_timer = 0.0
	current_hide_group = -1
	current_hide_tiles.clear()
	hide_countdown_text_cooldown = 0.0

	visible = true

	if collision_shape != null:
		collision_shape.disabled = false

	if sprite != null and !is_shooting and !is_reloading and !is_game_over:
		sprite.play("Idle")

	update_tanda_sembunyi()
	debug_hide("keluar hide")

func break_hide_tiles_by_group(group_id: int, center_tile: Vector2i) -> void:
	if hide_object == null:
		return

	var tiles := get_all_tiles_in_hide_group(center_tile, group_id)

	for tile_pos in tiles:
		hide_object.erase_cell(tile_pos)

func break_hide_object() -> void:
	if hide_object == null:
		exit_hide()
		return

	debug_hide("objek pecah | group=" + str(current_hide_group))

	for tile_pos in current_hide_tiles:
		hide_object.erase_cell(tile_pos)

	exit_hide()

func update_hide_state(delta: float) -> void:
	if !is_hiding or is_game_over:
		return

	hide_timer -= delta
	hide_countdown_text_cooldown -= delta

	if current_hide_group >= 0:
		if !hide_group_used_time.has(current_hide_group):
			hide_group_used_time[current_hide_group] = 0.0

		hide_group_used_time[current_hide_group] += delta

		var total_limit: float = hide_group_total_time.get(current_hide_group, DEFAULT_HIDE_TOTAL_DURATION)

		if hide_countdown_text_cooldown <= 0.0:
			show_hide_countdown_text()
			hide_countdown_text_cooldown = HIDE_COUNTDOWN_TEXT_INTERVAL

		if hide_group_used_time[current_hide_group] >= total_limit:
			hide_group_used_time[current_hide_group] = total_limit
			break_hide_object()
			return

	if hide_timer <= 0.0:
		exit_hide()

func get_hide_remaining_time() -> float:
	if current_hide_group < 0:
		return 0.0

	var total_limit: float = hide_group_total_time.get(current_hide_group, DEFAULT_HIDE_TOTAL_DURATION)
	var used_time: float = hide_group_used_time.get(current_hide_group, 0.0)
	return max(total_limit - used_time, 0.0)

func show_hide_countdown_text() -> void:
	if !is_hiding or is_game_over:
		return

	var sisa_total := get_hide_remaining_time()
	show_floating_text("SISA HIDE: %.1fs" % sisa_total, Color.AQUA)

func debug_hide(message: String) -> void:
	if debug_hide_enabled:
		print("[HIDE DEBUG] " + message)

# =========================
# TANDA SYSTEM
# =========================

func hide_all_tanda() -> void:
	if tanda_peluru != null:
		tanda_peluru.visible = false
	if tanda_bius != null:
		tanda_bius.visible = false

func show_tanda_temporarily(target: CanvasItem, duration: float) -> void:
	if target == null:
		return

	tanda_request_id += 1
	var current_id := tanda_request_id

	hide_all_tanda()
	target.visible = true

	await get_tree().create_timer(duration).timeout

	if current_id == tanda_request_id and target != null:
		target.visible = false

func swap_weapon() -> void:
	if is_reloading or is_hiding or is_game_over:
		return

	use_tranq = !use_tranq

	if use_tranq:
		show_tanda_temporarily(tanda_bius, TANDA_SWAP_DURATION)
	else:
		show_tanda_temporarily(tanda_peluru, TANDA_SWAP_DURATION)

# =========================
# COMBAT / UI
# =========================

func shoot() -> void:
	var ui = get_ui()
	if ui != null and ui.is_dokumen_open():
		return
	if is_hiding or is_game_over:
		return
	if !can_shoot:
		return
	if is_reloading:
		return
	if ammo <= 0:
		return

	can_shoot = false
	is_shooting = true
	ammo -= 1

	visible = true

	sprite.play("Shoot")
	gun_sound.play()

	var bullet = bullet_scene.instantiate()

	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - gun_point.global_position).normalized()

	bullet.shooter = self
	bullet.direction = dir
	bullet.rotation = dir.angle()
	bullet.global_position = gun_point.global_position + dir * 20.0

	if use_tranq:
		bullet.bullet_color = Color.CYAN
		bullet.damage = 1
	else:
		bullet.bullet_color = Color.YELLOW
		bullet.damage = 2

	show_floating_text("-" + str(ammo), Color.DODGER_BLUE)

	get_tree().current_scene.add_child(bullet)

	await sprite.animation_finished
	is_shooting = false

	if is_game_over:
		return

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true

func reload_weapon() -> void:
	$"Reload Sound".play()
	var ui = get_ui()
	if ui != null and ui.is_dokumen_open():
		return
	if is_hiding or is_game_over:
		return
	if is_reloading:
		return
	if ammo == max_ammo:
		return

	is_reloading = true
	visible = true
	sprite.play("Idle")
	show_floating_text("RELOADING...", Color.WHITE)

	show_tanda_temporarily(tanda_peluru, TANDA_RELOAD_DURATION)

	await get_tree().create_timer(RELOAD_TIME).timeout

	if is_game_over:
		return

	ammo = max_ammo
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

	var ui = get_ui()
	if ui != null and ui.has_method("set_score"):
		ui.set_score(total_score)

func get_score() -> int:
	return total_score

func game_over():
	if is_game_over:
		return
	is_game_over = true
	can_shoot = false
	is_reloading = false
	is_shooting = false

	is_hiding = false
	hide_timer = 0.0
	current_hide_group = -1
	current_hide_tiles.clear()
	hide_countdown_text_cooldown = 0.0

	visible = true
	velocity = Vector2.ZERO

	if step_sound.playing:
		step_sound.stop()

	if collision_shape != null:
		collision_shape.disabled = false

	tanda_tanya.visible = false
	update_tanda_sembunyi()

	if sprite != null:
		sprite.play("Death")
		await sprite.animation_finished
		$"death sound".play()
		await $"death sound".finished

	get_tree().change_scene_to_file("res://kalah.tscn")
