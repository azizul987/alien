extends Node2D

@onready var sprite_pintu:=$Sprite2D
#@onready var colliion:=$StaticBody2D/CollisionShape2D
var isVisible:=true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func show_or_hide():
	isVisible=!isVisible
	if(isVisible):
		sprite_pintu.show()
	else: 
		sprite_pintu.hide()
	
	
