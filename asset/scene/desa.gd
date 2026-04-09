extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("INtro")
	await  $AnimationPlayer.animation_finished
	$AnimationPlayer.queue_free()
	$Camera2D.queue_free()
	print("wkwkwk")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
