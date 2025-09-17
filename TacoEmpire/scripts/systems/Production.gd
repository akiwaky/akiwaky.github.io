extends Node
class_name Production

signal module_state_changed(instance_id, state)
signal queue_updated(instance_id, queue_size)

var economy: Economy
var modules_library: Dictionary = {}
var module_states: Dictionary = {}
var _sales_budget: float = 0.0
var _sales_rate_per_second: float = 0.0
var _current_price_multiplier: float = 1.0

func _ready() -> void:
    set_process(true)

func setup(economy_ref: Economy, module_definitions: Array) -> void:
    economy = economy_ref
    modules_library.clear()
    for definition in module_definitions:
        modules_library[definition.get("id")] = definition

func set_demand_snapshot(snapshot: Dictionary) -> void:
    _sales_rate_per_second = float(snapshot.get("customers_per_min", 0.0)) * float(snapshot.get("conversion_rate", 0.0)) / 60.0
    _current_price_multiplier = float(snapshot.get("price_multiplier", 1.0))

func add_module(instance_data: Dictionary) -> void:
    var instance_id := instance_data.get("instance_id", "")
    if instance_id == "":
        return
    var module_id := instance_data.get("module_id", "")
    var definition := modules_library.get(module_id, {})
    if definition.is_empty():
        return
    module_states[instance_id] = {
        "definition": definition,
        "timer": 0.0,
        "state": "idle",
        "queue": 0
    }
    emit_signal("module_state_changed", instance_id, "idle")

func remove_module(instance_id: String) -> void:
    if module_states.has(instance_id):
        module_states.erase(instance_id)

func clear_modules() -> void:
    module_states.clear()

func _process(delta: float) -> void:
    if economy == null:
        return
    _sales_budget = min(999.0, _sales_budget + _sales_rate_per_second * delta)
    for instance_id in module_states.keys():
        var state := module_states[instance_id]
        var definition := state.get("definition", {})
        if definition.is_empty():
            continue
        var module_id := definition.get("id", "")
        var process_time := float(definition.get("process_seconds", 1.0))
        var speed_multiplier := economy.get_module_speed_multiplier(module_id)
        process_time = process_time / max(speed_multiplier, 0.01)
        var input_resource := definition.get("input_resource", "")
        var output_resource := definition.get("output_resource", "")

        if state["state"] == "processing":
            state["timer"] -= delta
            if state["timer"] <= 0.0:
                _complete_cycle(instance_id, definition, output_resource)
                state["state"] = "idle"
                emit_signal("module_state_changed", instance_id, "idle")
            module_states[instance_id] = state
            continue

        var can_start := true
        if input_resource != "":
            can_start = economy.can_consume(input_resource, 1)
        if output_resource == "cash":
            can_start = can_start and _sales_budget >= 1.0 and economy.can_consume("taco_basic", 1)
        if not can_start:
            state["state"] = "waiting"
            emit_signal("module_state_changed", instance_id, state["state"])
            module_states[instance_id] = state
            continue
        if output_resource == "cash":
            if not economy.consume("taco_basic", 1):
                state["state"] = "waiting"
                module_states[instance_id] = state
                continue
            _sales_budget = max(0.0, _sales_budget - 1.0)
            state["reserved_product"] = 1
        elif input_resource != "":
            economy.consume(input_resource, 1)
            state["reserved_product"] = 0
        else:
            state["reserved_product"] = 0
        state["state"] = "processing"
        state["timer"] = process_time
        emit_signal("module_state_changed", instance_id, "processing")
        module_states[instance_id] = state

func _complete_cycle(instance_id: String, definition: Dictionary, output_resource: String) -> void:
    if output_resource == "cash":
        economy.register_sale("taco_basic", 1, _current_price_multiplier, true)
    elif output_resource != "":
        economy.add_inventory(output_resource, 1)
    emit_signal("queue_updated", instance_id, 0)

func serialize() -> Dictionary:
    return {
        "modules": module_states.keys()
    }
