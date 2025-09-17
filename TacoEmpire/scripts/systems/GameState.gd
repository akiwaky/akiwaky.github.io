extends Node
class_name GameState

signal time_updated(hour, minute)
signal upgrades_changed(owned_upgrades)
signal module_selected(module_id)

const DATA_DIR := "res://data/"
const START_HOUR := 8.0
const REAL_SECONDS_PER_GAME_MINUTE := 1.0
const STARTING_CORN := 15

var economy: Economy
var demand_simulator: DemandSimulator
var placement_system: PlacementSystem
var production: Production
var hud: Node
var upgrades_ui: Node
var tutorial_controller: Node

var modules_data: Array = []
var upgrades_data: Array = []
var tutorial_steps: Array = []

var owned_upgrades: Array = []
var game_minutes: float = START_HOUR * 60.0
var is_running: bool = false
var _last_snapshot: Dictionary = {}
var selected_module_id: String = ""
var _is_loading: bool = false

func _ready() -> void:
    economy = Economy.new()
    demand_simulator = DemandSimulator.new()
    add_child(economy)
    add_child(demand_simulator)
    _load_data()
    SaveLoad.register_provider(self)
    set_process(true)

func register_scene(
        placement: PlacementSystem,
        production_node: Production,
        hud_node: Node,
        upgrades_node: Node,
        tutorial_node: Node
    ) -> void:
    placement_system = placement
    production = production_node
    hud = hud_node
    upgrades_ui = upgrades_node
    tutorial_controller = tutorial_node
    placement_system.set_module_definitions(modules_data)
    production.setup(economy, modules_data)
    placement_system.connect("module_placed", Callable(self, "_on_module_placed"))
    placement_system.connect("module_removed", Callable(self, "_on_module_removed"))
    economy.connect("cash_changed", Callable(hud, "update_cash"))
    economy.connect("inventory_changed", Callable(hud, "update_inventory"))
    demand_simulator.connect("demand_snapshot", Callable(self, "_on_demand_snapshot"))
    EventManager.connect("event_started", Callable(hud, "show_event_banner"))
    EventManager.connect("event_ended", Callable(hud, "hide_event_banner"))
    connect("module_selected", Callable(hud, "update_selected_module"))
    if hud != null:
        hud.call("build_module_palette", get_modules_catalog())
        if selected_module_id != "":
            emit_signal("module_selected", selected_module_id)
    if upgrades_ui != null:
        upgrades_ui.call("setup", upgrades_data)
        upgrades_ui.call("refresh_state", owned_upgrades)
    if tutorial_controller != null:
        tutorial_controller.call("setup", tutorial_steps)
    _start_or_load()

func _process(delta: float) -> void:
    if not is_running:
        return
    game_minutes += delta / REAL_SECONDS_PER_GAME_MINUTE
    if game_minutes >= 24.0 * 60.0:
        game_minutes = fmod(game_minutes, 24.0 * 60.0)
    var hour := int(game_minutes / 60.0)
    var minute := int(game_minutes) % 60
    emit_signal("time_updated", hour, minute)
    if hud != null:
        hud.call("update_time", hour, minute)
    var snapshot := demand_simulator.update(delta, hour + float(minute) / 60.0, economy)
    production.set_demand_snapshot(snapshot)
    _last_snapshot = snapshot

func _load_data() -> void:
    var recipes := _load_json("recipes.json")
    economy.setup(recipes.get("resources", []))
    var modules_json := _load_json("modules.json")
    modules_data = modules_json.get("modules", [])
    upgrades_data = _load_json("upgrades.json").get("upgrades", [])
    tutorial_steps = _load_json("tutorial.json").get("steps", [])
    var demand_json := _load_json("demand.json")
    demand_simulator.setup(demand_json)
    if not modules_data.is_empty():
        selected_module_id = modules_data[0].get("id", "")

func _load_json(file_name: String) -> Dictionary:
    var path := DATA_DIR + file_name
    if not FileAccess.file_exists(path):
        push_error("No se encontró %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("No se pudo leer %s" % path)
        return {}
    var content := file.get_as_text()
    file.close()
    var parsed := JSON.parse_string(content)
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {}

func _start_or_load() -> void:
    var saved := SaveLoad.load_game()
    if saved.is_empty():
        start_new_game()
    else:
        _apply_save(saved)

func start_new_game() -> void:
    is_running = false
    game_minutes = START_HOUR * 60.0
    EventManager.clear()
    economy.reset()
    economy.add_inventory("corn", STARTING_CORN)
    owned_upgrades.clear()
    emit_signal("upgrades_changed", owned_upgrades)
    if upgrades_ui != null:
        upgrades_ui.call("refresh_state", owned_upgrades)
    placement_system.clear()
    production.clear_modules()
    is_running = true
    SaveLoad.save_game()

func _apply_save(save_data: Dictionary) -> void:
    is_running = false
    _is_loading = true
    economy.reset()
    economy.deserialize(save_data.get("economy", {}))
    owned_upgrades = save_data.get("owned_upgrades", [])
    var placements := save_data.get("placements", [])
    placement_system.restore_instances(placements)
    production.clear_modules()
    for instance in placement_system.get_all_instances():
        production.add_module(instance)
    game_minutes = float(save_data.get("game_minutes", START_HOUR * 60.0))
    emit_signal("upgrades_changed", owned_upgrades)
    if upgrades_ui != null:
        upgrades_ui.call("refresh_state", owned_upgrades)
    is_running = true
    _is_loading = false
    SaveLoad.save_game()

func serialize_state() -> Dictionary:
    var placements: Array = []
    if placement_system != null:
        for instance in placement_system.get_all_instances():
            var cell: Vector2i = instance.get("cell", Vector2i.ZERO)
            placements.append({
                "instance_id": instance.get("instance_id", ""),
                "module_id": instance.get("module_id", ""),
                "cell": {"x": cell.x, "y": cell.y}
            })
    return {
        "economy": economy.serialize(),
        "placements": placements,
        "owned_upgrades": owned_upgrades,
        "game_minutes": game_minutes
    }

func attempt_module_placement(module_id: String, world_position: Vector2) -> Dictionary:
    if placement_system == null:
        return {}
    var preview := placement_system.request_preview(world_position, module_id)
    if preview.is_empty() or not preview.get("is_valid", false):
        return {}
    var definition := _find_module(module_id)
    if definition.is_empty():
        return {}
    var cost := float(definition.get("base_cost", 0.0))
    if not economy.spend(cost):
        return {}
    return placement_system.confirm_placement(module_id)

func purchase_upgrade(upgrade_id: String) -> bool:
    if owned_upgrades.has(upgrade_id):
        return false
    var upgrade := _find_upgrade(upgrade_id)
    if upgrade.is_empty():
        return false
    var cost := float(upgrade.get("cost", 0.0))
    if not economy.spend(cost):
        return false
    for effect in upgrade.get("effects", []):
        economy.apply_effect(effect)
    owned_upgrades.append(upgrade_id)
    emit_signal("upgrades_changed", owned_upgrades)
    if upgrades_ui != null:
        upgrades_ui.call("refresh_state", owned_upgrades)
    SaveLoad.save_game()
    return true

func buy_corn(amount: int) -> bool:
    var success := economy.purchase_resource("corn", amount)
    if success:
        SaveLoad.save_game()
    return success

func select_module(module_id: String) -> void:
    selected_module_id = module_id
    emit_signal("module_selected", module_id)

func get_modules_catalog() -> Array:
    return modules_data.duplicate(true)

func get_module_definition(module_id: String) -> Dictionary:
    return _find_module(module_id)

func _on_module_placed(instance_data: Dictionary) -> void:
    if _is_loading:
        return
    production.add_module(instance_data)
    SaveLoad.save_game()

func _on_module_removed(instance_id: String) -> void:
    if _is_loading:
        return
    production.remove_module(instance_id)
    SaveLoad.save_game()

func _on_demand_snapshot(snapshot: Dictionary) -> void:
    if hud != null:
        hud.call("update_demand", snapshot)

func _find_module(module_id: String) -> Dictionary:
    for module in modules_data:
        if module.get("id") == module_id:
            return module
    return {}

func _find_upgrade(upgrade_id: String) -> Dictionary:
    for upgrade in upgrades_data:
        if upgrade.get("id") == upgrade_id:
            return upgrade
    return {}
