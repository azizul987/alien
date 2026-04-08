extends Camera2D

@export var batas_kiri: Marker2D
@export var batas_kanan: Marker2D
@export var batas_atas: Marker2D
@export var batas_bawah: Marker2D

var offset_awal: Vector2

func _ready() -> void:
	offset_awal = position

func _process(delta: float) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return

	var target_pos = parent_node.global_position + offset_awal

	if batas_kiri != null and target_pos.x < batas_kiri.global_position.x:
		target_pos.x = batas_kiri.global_position.x

	if batas_kanan != null and target_pos.x > batas_kanan.global_position.x:
		target_pos.x = batas_kanan.global_position.x

	if batas_atas != null and target_pos.y < batas_atas.global_position.y:
		target_pos.y = batas_atas.global_position.y

	if batas_bawah != null and target_pos.y > batas_bawah.global_position.y:
		target_pos.y = batas_bawah.global_position.y

	global_position = target_pos
