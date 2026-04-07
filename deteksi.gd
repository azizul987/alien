extends Area2D

var near_door
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if(body.is_in_group("pintu")):
		near_door=body
		if(Input.is_action_just_pressed("interact")):
			body.show_or_hide()


func _on_body_exited(body: Node2D) -> void:
	if near_door!=null:
		near_door=null
		
