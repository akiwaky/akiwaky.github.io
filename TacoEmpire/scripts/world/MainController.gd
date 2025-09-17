extends Node2D

@onready var placement_system: PlacementSystem = $World/PlacementSystem
@onready var production: Production = $World/Production
@onready var hud: CanvasLayer = $HUD
@onready var upgrades_panel: Control = $UpgradesPanel
@onready var tutorial: CanvasLayer = $Tutorial
@onready var ghost: Node2D = $World/Ghost

func _ready() -> void:
    GameState.register_scene(placement_system, production, hud, upgrades_panel, tutorial)
    placement_system.connect("module_preview", Callable(self, "_on_module_preview"))
    set_process(true)

func _process(_delta: float) -> void:
    var module_id := GameState.selected_module_id
    if module_id == "":
        ghost.hide_preview()
        return
    var local_mouse := placement_system.to_local(get_global_mouse_position())
    placement_system.request_preview(local_mouse, module_id)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var module_id := GameState.selected_module_id
        if module_id == "":
            return
        var local_mouse := placement_system.to_local(get_global_mouse_position())
        var placement := GameState.attempt_module_placement(module_id, local_mouse)
        if placement.is_empty():
            return
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        GameState.select_module("")
        ghost.hide_preview()

func _on_module_preview(cell: Vector2i, size: Vector2i, is_valid: bool, module_id: String) -> void:
    if module_id == "":
        ghost.hide_preview()
        return
    ghost.update_preview(placement_system, cell, size, is_valid)
