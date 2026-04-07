extends CanvasLayer

## Main Menu - Bereaksi terhadap tombol APA SAJA untuk memulai game
## Letakkan script ini di node CanvasLayer (atau Control) untuk scene menu utama


enum MenuState { IDLE, WAITING_INPUT, STARTING }
var state := MenuState.IDLE

@onready var label_press_any: Label        = $MarginContainer/VBox/LabelPressAny
@onready var label_title: Label            = $LabelTitle
@onready var anim_player: AnimationPlayer = $AnimationPlayer   # opsional

# Timer kedip teks "Press Any Key"
var blink_timer := 0.0
var blink_interval := 0.6
var is_visible_blink := true
var input_cooldown := 0.5
var cooldown_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

	state = MenuState.IDLE
	cooldown_elapsed = 0.0

	if label_press_any:
		label_press_any.visible = false   


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

		MenuState.STARTING:
			pass  



func _input(event: InputEvent) -> void:
	if state != MenuState.WAITING_INPUT:
		return

	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	if event is InputEventJoypadMotion:
		# Hanya tangkap jika stick benar-benar ditekan jauh
		if abs(event.axis_value) < 0.8:
			return

	_start_game()


func _start_game() -> void:
	if state == MenuState.STARTING:
		return
	state = MenuState.STARTING
	$AudioStreamPlayer2D.play()
	await $AudioStreamPlayer2D.finished

	if label_press_any:
		label_press_any.text = "Loading..."
		label_press_any.visible = true

	if anim_player and anim_player.has_animation("fade_out"):
		anim_player.play("fade_out")
		await anim_player.animation_finished
	
	get_tree().change_scene_to_file("res://asset/scene/main.tscn")
