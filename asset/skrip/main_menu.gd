extends CanvasLayer

enum MenuState {
	IDLE,
	WAITING_INPUT,
	CHOOSING_DIFFICULTY,
	STARTING
}

var state := MenuState.IDLE

@onready var label_press_any: Label = $MarginContainer/VBox/LabelPressAny
@onready var label_title: Label = $LabelTitle
@onready var label_difficulty: Label = $MarginContainer/VBox/LabelDifficulty
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var blink_timer := 0.0
var blink_interval := 0.6
var is_visible_blink := true
var input_cooldown := 0.5
var cooldown_elapsed := 0.0

var difficulty_index := 1
var difficulty_names := ["EASY", "NORMAL", "HARD"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

	state = MenuState.IDLE
	cooldown_elapsed = 0.0

	if label_press_any:
		label_press_any.visible = false

	if label_difficulty:
		label_difficulty.visible = false
		update_difficulty_label()

func _process(delta: float) -> void:
	match state:
		MenuState.IDLE:
			cooldown_elapsed += delta
			if cooldown_elapsed >= input_cooldown:
				state = MenuState.WAITING_INPUT
				if label_press_any:
					label_press_any.visible = true

		MenuState.WAITING_INPUT:
			blink_timer += delta
			if blink_timer >= blink_interval:
				blink_timer = 0.0
				is_visible_blink = !is_visible_blink
				if label_press_any:
					label_press_any.visible = is_visible_blink

		MenuState.CHOOSING_DIFFICULTY:
			pass

		MenuState.STARTING:
			pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	if event is InputEventJoypadMotion and abs(event.axis_value) < 0.8:
		return

	match state:
		MenuState.WAITING_INPUT:
			show_difficulty_menu()

		MenuState.CHOOSING_DIFFICULTY:
			handle_difficulty_input(event)

func show_difficulty_menu() -> void:
	state = MenuState.CHOOSING_DIFFICULTY

	if label_press_any:
		label_press_any.visible = false

	if label_difficulty:
		label_difficulty.visible = true
		update_difficulty_label()

func handle_difficulty_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		difficulty_index -= 1
		if difficulty_index < 0:
			difficulty_index = difficulty_names.size() - 1
		update_difficulty_label()
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		difficulty_index += 1
		if difficulty_index >= difficulty_names.size():
			difficulty_index = 0
		update_difficulty_label()
		return

	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton or event is InputEventKey:
		apply_selected_difficulty()
		_start_game()

func update_difficulty_label() -> void:
	if label_difficulty == null:
		return

	label_difficulty.text = "Pilih Difficulty: [ " + difficulty_names[difficulty_index] + " ]\nKiri/Kanan untuk ubah\nEnter untuk mulai"

func apply_selected_difficulty() -> void:
	match difficulty_index:
		0:
			GameSettings.set_difficulty(GameSettings.Difficulty.EASY)
		1:
			GameSettings.set_difficulty(GameSettings.Difficulty.NORMAL)
		2:
			GameSettings.set_difficulty(GameSettings.Difficulty.HARD)

func _start_game() -> void:
	if state == MenuState.STARTING:
		return

	state = MenuState.STARTING
	$AudioStreamPlayer2D.play()
	await $AudioStreamPlayer2D.finished

	if label_difficulty:
		label_difficulty.text = "Loading..."
		label_difficulty.visible = true

	if anim_player and anim_player.has_animation("fade_out"):
		anim_player.play("fade_out")
		await anim_player.animation_finished

	get_tree().change_scene_to_file("res://asset/scene/main.tscn")
