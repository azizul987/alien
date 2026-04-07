extends Area2D

var near_door=null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("interact") and near_door):
		near_door. open_or_close()


func _on_body_entered(body: Node2D) -> void:
	if(body.is_in_group("pintu")):
		near_door=body
		print(near_door.name)

func _on_body_exited(body: Node2D) -> void:
	if near_door!=null:
		near_door=null
		
