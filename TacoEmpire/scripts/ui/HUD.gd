extends CanvasLayer

@onready var cash_label: Label = $Root/Content/Metrics/CashValue
@onready var time_label: Label = $Root/Content/Metrics/TimeValue
@onready var demand_label: Label = $Root/Content/Metrics/DemandValue
@onready var inventory_list: VBoxContainer = $Root/Content/Inventory/Values
@onready var event_banner: Panel = $Root/EventBanner
@onready var event_text: Label = $Root/EventBanner/EventLabel
@onready var upgrades_button: Button = $Root/Content/Actions/UpgradesButton
@onready var palette_container: HBoxContainer = $Root/Content/Palette

var _inventory_labels: Dictionary = {}
var _palette_buttons: Dictionary = {}

func _ready() -> void:
    upgrades_button.pressed.connect(_on_upgrades_pressed)
    $Root/Content/Actions/BuyCornButton.pressed.connect(_on_buy_corn)
    $Root/Content/Actions/SaveButton.pressed.connect(_on_save_pressed)
    event_banner.visible = false

func update_cash(value: float) -> void:
    cash_label.text = "$%.0f" % value

func update_time(hour: int, minute: int) -> void:
    time_label.text = "%02d:%02d" % [hour, minute]

func update_demand(snapshot: Dictionary) -> void:
    var affluence := snapshot.get("customers_per_min", 0.0)
    var conversion := snapshot.get("conversion_rate", 0.0)
    demand_label.text = "%.1f pax/min • %.0f%% hit" % [affluence, conversion * 100.0]

func update_inventory(resource_id: String, amount: int) -> void:
    if not _inventory_labels.has(resource_id):
        var label := Label.new()
        label.name = resource_id
        inventory_list.add_child(label)
        _inventory_labels[resource_id] = label
    var friendly := resource_id.capitalize()
    _inventory_labels[resource_id].text = "%s: %d" % [friendly, amount]

func show_event_banner(event_data: Dictionary) -> void:
    event_text.text = "%s ☔" % event_data.get("name", "Evento")
    event_banner.visible = true

func hide_event_banner(_event_data: Dictionary) -> void:
    event_banner.visible = false

func build_module_palette(modules: Array) -> void:
    for child in palette_container.get_children():
        child.queue_free()
    _palette_buttons.clear()
    for module in modules:
        var id := module.get("id", "")
        if id == "":
            continue
        var button := Button.new()
        button.text = module.get("name", id)
        button.toggle_mode = true
        button.pressed.connect(_on_module_button.bind(id))
        palette_container.add_child(button)
        _palette_buttons[id] = button
    _update_palette_selection(GameState.selected_module_id)

func _on_module_button(module_id: String) -> void:
    GameState.select_module(module_id)
    _update_palette_selection(module_id)

func _update_palette_selection(selected_id: String) -> void:
    for id in _palette_buttons.keys():
        var btn: Button = _palette_buttons[id]
        btn.button_pressed = id == selected_id

func update_selected_module(module_id: String) -> void:
    _update_palette_selection(module_id)

func _on_buy_corn() -> void:
    GameState.buy_corn(10)

func _on_save_pressed() -> void:
    SaveLoad.save_game()

func _on_upgrades_pressed() -> void:
    if GameState.upgrades_ui != null:
        GameState.upgrades_ui.call("toggle_visible")
