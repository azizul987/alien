extends Control

@onready var pause_menu = $CanvasLayer
@onready var point: Label = $CanvasLayer2/Point

var score: int = 0

func _ready() -> void:
	pause_menu.visible = false
	update_point_label()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_menu.visible = false
	else:
		get_tree().paused = true
		pause_menu.visible = true

func on_press_lanjut() -> void:
	toggle_pause()

func on_press_keluar() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://asset/scene/main_menu.tscn")

func add_score(amount: int) -> void:
	score += amount
	update_point_label()

func update_point_label() -> void:
	point.text = "POINT: " + str(score)
	
func set_score(value: int) -> void:
	score = value
	point.text = "POINT: " + str(score)
