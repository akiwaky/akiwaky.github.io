extends Node
class_name Economy

signal cash_changed(value)
signal inventory_changed(resource_id, amount)

const STARTING_CASH := 500.0

var cash: float = STARTING_CASH
var inventory: Dictionary = {}
var resource_definitions: Dictionary = {}
var pricing: Dictionary = {
    "taco_basic": 20.0
}
var global_price_multiplier: float = 1.0
var demand_multiplier: float = 1.0
var module_speed_bonus: Dictionary = {}

func setup(resources: Array) -> void:
    resource_definitions.clear()
    inventory.clear()
    for res in resources:
        var id: String = res.get("id", "")
        if id == "":
            continue
        resource_definitions[id] = res
        inventory[id] = 0
    reset()

func reset() -> void:
    cash = STARTING_CASH
    emit_signal("cash_changed", cash)
    for id in inventory.keys():
        inventory[id] = 0
        emit_signal("inventory_changed", id, 0)
    global_price_multiplier = 1.0
    demand_multiplier = 1.0
    module_speed_bonus.clear()

func can_afford(cost: float) -> bool:
    return cash >= cost

func spend(cost: float) -> bool:
    if not can_afford(cost):
        return false
    cash -= cost
    emit_signal("cash_changed", cash)
    return true

func purchase_resource(resource_id: String, amount: int) -> bool:
    if not resource_definitions.has(resource_id):
        return false
    var unit_cost := float(resource_definitions[resource_id].get("unit_cost", 0.0))
    var total_cost := unit_cost * amount
    if not can_afford(total_cost):
        return false
    cash -= total_cost
    inventory[resource_id] = int(inventory.get(resource_id, 0)) + amount
    emit_signal("cash_changed", cash)
    emit_signal("inventory_changed", resource_id, inventory[resource_id])
    return true

func can_consume(resource_id: String, amount: int) -> bool:
    return int(inventory.get(resource_id, 0)) >= amount

func consume(resource_id: String, amount: int) -> bool:
    if not can_consume(resource_id, amount):
        return false
    inventory[resource_id] = int(inventory.get(resource_id, 0)) - amount
    emit_signal("inventory_changed", resource_id, inventory[resource_id])
    return true

func add_inventory(resource_id: String, amount: int) -> void:
    inventory[resource_id] = int(inventory.get(resource_id, 0)) + amount
    emit_signal("inventory_changed", resource_id, inventory[resource_id])

func get_resource_amount(resource_id: String) -> int:
    return int(inventory.get(resource_id, 0))

func get_sale_price(product_id: String, segment_multiplier: float) -> float:
    var base_price := float(pricing.get(product_id, 0.0))
    return base_price * segment_multiplier * global_price_multiplier

func register_sale(product_id: String, amount: int, segment_multiplier: float, already_reserved: bool = false) -> void:
    if not already_reserved:
        if not can_consume(product_id, amount):
            return
        consume(product_id, amount)
    var revenue := get_sale_price(product_id, segment_multiplier) * amount
    cash += revenue
    emit_signal("cash_changed", cash)

func apply_effect(effect: Dictionary) -> void:
    var effect_type := effect.get("type", "")
    match effect_type:
        "module_throughput":
            var target := effect.get("target", "")
            var multiplier := float(effect.get("multiplier", 1.0))
            module_speed_bonus[target] = float(module_speed_bonus.get(target, 1.0)) * multiplier
        "price_multiplier":
            global_price_multiplier *= float(effect.get("multiplier", 1.0))
        "demand_multiplier":
            demand_multiplier *= float(effect.get("multiplier", 1.0))
        _:
            push_warning("Efecto de upgrade no reconocido: %s" % effect_type)

func get_module_speed_multiplier(module_id: String) -> float:
    return float(module_speed_bonus.get(module_id, 1.0))

func serialize() -> Dictionary:
    return {
        "cash": cash,
        "inventory": inventory.duplicate(true),
        "global_price_multiplier": global_price_multiplier,
        "demand_multiplier": demand_multiplier,
        "module_speed_bonus": module_speed_bonus.duplicate(true)
    }

func deserialize(data: Dictionary) -> void:
    cash = float(data.get("cash", STARTING_CASH))
    emit_signal("cash_changed", cash)
    var inv := data.get("inventory", {})
    for key in inv.keys():
        inventory[key] = int(inv[key])
        emit_signal("inventory_changed", key, inventory[key])
    global_price_multiplier = float(data.get("global_price_multiplier", 1.0))
    demand_multiplier = float(data.get("demand_multiplier", 1.0))
    module_speed_bonus = data.get("module_speed_bonus", {}).duplicate(true)
