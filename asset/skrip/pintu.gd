extends CharacterBody2D

@onready var sprite_pintu = $Pintuup
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var interact_area: Area2D = $Area2D

var terbuka := false
var sedang_bergerak := false
var player_dekat := false

func _process(delta: float) -> void:
	if player_dekat and Input.is_action_just_pressed("interact"):
		open_or_close()

func open_or_close():
	if sedang_bergerak:
		return
		
	sedang_bergerak = true
	
	var akan_terbuka = !terbuka
	var target_sudut = 90.0 if akan_terbuka else 0.0
	var target_rad = deg_to_rad(target_sudut)
	
	if akan_terbuka:
		body_collision.disabled = true
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_pintu, "rotation", target_rad, 0.6)
	
	tween.finished.connect(func():
		terbuka = akan_terbuka
		
		if not terbuka:
			body_collision.disabled = false
		
		sedang_bergerak = false
	)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_dekat = true
		body.get_child(5).show_tanda()

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_dekat = false
		body.get_child(5).hide_tanda()
