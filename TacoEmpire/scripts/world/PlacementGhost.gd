extends Node2D

@onready var polygon: Polygon2D = $Polygon2D

func _ready() -> void:
    visible = false

func update_preview(system: PlacementSystem, cell: Vector2i, size: Vector2i, is_valid: bool) -> void:
    var world_pos := system.grid_to_world(cell)
    position = world_pos
    polygon.scale = Vector2(max(1, size.x), max(1, size.y))
    polygon.modulate = is_valid ? Color(0.3, 0.9, 0.3, 0.5) : Color(0.9, 0.2, 0.2, 0.5)
    visible = true

func hide_preview() -> void:
    visible = false
