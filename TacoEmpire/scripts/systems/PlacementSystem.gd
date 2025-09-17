extends Node2D
class_name PlacementSystem

signal module_preview(cell, size, is_valid, module_id)
signal module_placed(instance_data)
signal module_removed(instance_id)

const GRID_SIZE := Vector2i(12, 12)
const CELL_SIZE := Vector2(64, 32)

var grid_origin: Vector2 = Vector2.ZERO
var _module_definitions: Dictionary = {}
var _occupied: Dictionary = {}
var _instances: Dictionary = {}
var _preview_state: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()

func set_module_definitions(modules: Array) -> void:
    _module_definitions.clear()
    for module in modules:
        _module_definitions[module.get("id")] = module

func clear() -> void:
    _occupied.clear()
    _instances.clear()
    _preview_state.clear()

func restore_instances(instances: Array) -> void:
    clear()
    for data in instances:
        if typeof(data) != TYPE_DICTIONARY:
            continue
        var module_id := data.get("module_id", "")
        var cell_data := data.get("cell", Vector2i.ZERO)
        var cell := cell_data if typeof(cell_data) == TYPE_VECTOR2I else Vector2i(cell_data.get("x", 0), cell_data.get("y", 0))
        var module := _module_definitions.get(module_id, null)
        if module == null:
            continue
        var size := Vector2i(module.get("size", Vector2i.ONE))
        if not _is_area_free(cell, size):
            continue
        var instance_id := data.get("instance_id", _generate_instance_id(module_id))
        var instance := {
            "instance_id": instance_id,
            "module_id": module_id,
            "cell": cell,
            "size": size,
            "config": module
        }
        _instances[instance_id] = instance
        _mark_area(cell, size, true)
        emit_signal("module_placed", instance)

func request_preview(world_position: Vector2, module_id: String) -> Dictionary:
    if not _module_definitions.has(module_id):
        return {}
    var module := _module_definitions[module_id]
    var size := Vector2i(module.get("size", Vector2i.ONE))
    var cell := world_to_grid(world_position)
    var is_valid := _is_area_free(cell, size)
    _preview_state = {
        "cell": cell,
        "module_id": module_id,
        "is_valid": is_valid
    }
    emit_signal("module_preview", cell, size, is_valid, module_id)
    return _preview_state

func confirm_placement(module_id: String) -> Dictionary:
    if _preview_state.is_empty():
        return {}
    if _preview_state.get("module_id") != module_id:
        return {}
    if not _preview_state.get("is_valid", false):
        return {}
    var module := _module_definitions[module_id]
    var size := Vector2i(module.get("size", Vector2i.ONE))
    var cell: Vector2i = _preview_state.get("cell", Vector2i.ZERO)
    var instance_id := _generate_instance_id(module_id)
    var data := {
        "instance_id": instance_id,
        "module_id": module_id,
        "cell": cell,
        "size": size,
        "config": module
    }
    _mark_area(cell, size, true)
    _instances[instance_id] = data
    emit_signal("module_placed", data)
    _preview_state.clear()
    return data

func remove_module(instance_id: String) -> void:
    if not _instances.has(instance_id):
        return
    var data := _instances[instance_id]
    _mark_area(data.get("cell", Vector2i.ZERO), data.get("size", Vector2i.ONE), false)
    _instances.erase(instance_id)
    emit_signal("module_removed", instance_id)

func get_instance(instance_id: String) -> Dictionary:
    return _instances.get(instance_id, {})

func get_all_instances() -> Array:
    return _instances.values()

func world_to_grid(world_position: Vector2) -> Vector2i:
    var local := world_position - grid_origin
    var half_w := CELL_SIZE.x * 0.5
    var half_h := CELL_SIZE.y * 0.5
    var grid_x := (local.y / half_h + local.x / half_w) * 0.5
    var grid_y := (local.y / half_h - local.x / half_w) * 0.5
    return Vector2i(round(grid_x), round(grid_y))

func grid_to_world(cell: Vector2i) -> Vector2:
    var world_x := (cell.x - cell.y) * (CELL_SIZE.x * 0.5)
    var world_y := (cell.x + cell.y) * (CELL_SIZE.y * 0.5)
    return Vector2(world_x, world_y) + grid_origin

func _is_area_free(cell: Vector2i, size: Vector2i) -> bool:
    for x in range(size.x):
        for y in range(size.y):
            var check := Vector2i(cell.x + x, cell.y + y)
            if check.x < 0 or check.y < 0 or check.x >= GRID_SIZE.x or check.y >= GRID_SIZE.y:
                return false
            if _occupied.has(check):
                return false
    return true

func _mark_area(cell: Vector2i, size: Vector2i, occupy: bool) -> void:
    for x in range(size.x):
        for y in range(size.y):
            var check := Vector2i(cell.x + x, cell.y + y)
            if occupy:
                _occupied[check] = true
            else:
                _occupied.erase(check)

func _generate_instance_id(module_id: String) -> String:
    return "%s_%d_%d" % [module_id, Time.get_ticks_msec(), _rng.randi_range(1000, 9999)]
