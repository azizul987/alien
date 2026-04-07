extends Node2D
class_name TileDetector

@export var tilemap_layer_path: NodePath
@export var check_radius: int = 1

var tilemap_layer: TileMapLayer

func _ready() -> void:
	tilemap_layer = get_node(tilemap_layer_path)

func get_center_cell(world_pos: Vector2) -> Vector2i:
	return tilemap_layer.local_to_map(tilemap_layer.to_local(world_pos))

func is_near_type(world_pos: Vector2, target_type: String) -> bool:
	var center_cell = get_center_cell(world_pos)

	for y in range(-check_radius, check_radius + 1):
		for x in range(-check_radius, check_radius + 1):
			var cell = center_cell + Vector2i(x, y)
			var tile_data = tilemap_layer.get_cell_tile_data(cell)

			if tile_data:
				var tile_type = tile_data.get_custom_data("type")
				if tile_type == target_type:
					return true

	return false
