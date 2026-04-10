extends CharacterBody2D

const SPEED := 250.0
const FIRE_RATE := 0.5
const MAX_AMMO := 4
const RELOAD_TIME := 1.0
const RELOAD_REMINDER_INTERVAL := 0.5
const HIDE_LIMIT := 3
const HIDE_GROUP_SCAN_RADIUS := 3

const TANDA_SWAP_DURATION := 0.5
const TANDA_RELOAD_DURATION := 0.5

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
var current_petunjuk_id: int = 0

# ===== HIDE SYSTEM =====
var is_hiding: bool = false
var hide_timer: float = 0.0
var current_hide_group: int = -1
var current_hide_tiles: Array[Vector2i] = []
var debug_hide_enabled: bool = true

# ===== TANDA SYSTEM =====
var tanda_request_id: int = 0

var is_game_over := false

func _ready() -> void:
	tanda_tanya.visible = false

	if tanda_peluru != null:
		tanda_peluru.visible = false
	if tanda_bius != null:
		tanda_bius.visible = false

func _physics_process(delta: float) -> void:
	var ui = get_ui()

	# Dokumen terbuka = player berhenti
	if ui != null and ui.is_dokumen_open():
		velocity = Vector2.ZERO
		if step_sound.playing:
			step_sound.stop()
		move_and_slide()
		return

	# Update sistem hide
	update_hide_state(delta)

	# Saat sedang sembunyi, player tidak bisa gerak
	if is_hiding:
		velocity = Vector2.ZERO
		if step_sound.playing:
			step_sound.stop()
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
		swap_weapon()

	if Input.is_action_just_pressed("toggle_kacamata"):
		is_using_kacamata = !is_using_kacamata
		kacamata.enabled = is_using_kacamata

	if Input.is_action_just_pressed("interact"):
		# Prioritas 1: sembunyi
		var hide_data := get_hide_tile_data()
		if !hide_data.is_empty() and hide_data["hideable"]:
			enter_hide()
			return

		# Prioritas 2: buka petunjuk
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
	tanda_tanya.visible = current_petunjuk_id > 0 and !is_hiding

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

	return {
		"tile_pos": tile_pos,
		"hideable": hideable == true,
		"group_id": int(group_id) if group_id != null else -1
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

func enter_hide() -> void:
	if is_hiding:
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

	if group_id < 0:
		debug_hide("gagal hide: HideGroup belum diisi")
		return

	current_hide_tiles = get_all_tiles_in_hide_group(tile_pos, group_id)

	if current_hide_tiles.is_empty():
		debug_hide("gagal hide: tile group tidak ketemu")
		return

	is_hiding = true
	hide_timer = HIDE_LIMIT
	current_hide_group = group_id

	velocity = Vector2.ZERO
	tanda_tanya.visible = false

	if collision_shape != null:
		collision_shape.disabled = true

	if step_sound.playing:
		step_sound.stop()

	if sprite != null:
		sprite.play("hide")
		await sprite.animation_finished

	visible = false

	debug_hide("masuk hide | group=" + str(current_hide_group) + " | total_tiles=" + str(current_hide_tiles.size()))

func exit_hide() -> void:
	if !is_hiding:
		return

	is_hiding = false
	hide_timer = 0.0
	current_hide_group = -1
	current_hide_tiles.clear()

	visible = true

	if collision_shape != null:
		collision_shape.disabled = false

	debug_hide("keluar hide")

func break_hide_object() -> void:
	if hide_object == null:
		exit_hide()
		return

	debug_hide("objek pecah | group=" + str(current_hide_group))

	for tile_pos in current_hide_tiles:
		hide_object.erase_cell(tile_pos)

	exit_hide()

func update_hide_state(delta: float) -> void:
	if !is_hiding:
		return

	hide_timer -= delta

	if hide_timer <= 0.0:
		break_hide_object()

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
	if is_reloading:
		return
	if is_hiding:
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
	if is_hiding:
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
		bullet.damage = 2

	show_floating_text("-" + str(ammo), Color.DODGER_BLUE)

	get_tree().current_scene.add_child(bullet)

	await sprite.animation_finished
	is_shooting = false

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true

func reload_weapon() -> void:
	var ui = get_ui()
	if ui != null and ui.is_dokumen_open():
		return
	if is_hiding:
		return
	if is_reloading:
		return
	if ammo == MAX_AMMO:
		return

	is_reloading = true
	sprite.play("Idle")
	show_floating_text("RELOADING...", Color.WHITE)

	show_tanda_temporarily(tanda_peluru, TANDA_RELOAD_DURATION)

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

	var ui = get_ui()
	if ui != null and ui.has_method("set_score"):
		ui.set_score(total_score)

func game_over():
	if is_game_over:
		return
	is_game_over = true
	can_shoot = false
	is_reloading = false
	is_shooting = false
	get_tree().reload_current_scene()
