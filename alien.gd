extends CharacterBody2D

func take_damage(amount: int) -> void:
	print("TARGET KENA")
	queue_free()
