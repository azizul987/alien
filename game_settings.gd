extends Node

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

var selected_difficulty: Difficulty = Difficulty.NORMAL

func set_difficulty(diff: Difficulty) -> void:
	selected_difficulty = diff

func get_player_ammo() -> int:
	match selected_difficulty:
		Difficulty.EASY:
			return 12
		Difficulty.NORMAL:
			return 6
		Difficulty.HARD:
			return 4
	return 5

func get_enemy_speed_multiplier() -> float:
	match selected_difficulty:
		Difficulty.EASY:
			return 0.8
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.2
	return 1.0

func get_enemy_chase_multiplier() -> float:
	match selected_difficulty:
		Difficulty.EASY:
			return 0.8
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.2
	return 1.0

func get_enemy_max_speed_multiplier() -> float:
	match selected_difficulty:
		Difficulty.EASY:
			return 0.8
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.2
	return 1.0
