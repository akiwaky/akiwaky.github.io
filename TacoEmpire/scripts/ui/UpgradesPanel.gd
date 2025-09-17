extends Control

@onready var list_container: VBoxContainer = $Panel/Margin/VBox/Scroll/UpgradeList
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton

var _upgrade_data: Array = []
var _card_lookup: Dictionary = {}

func _ready() -> void:
    visible = false
    close_button.pressed.connect(toggle_visible)

func setup(upgrades: Array) -> void:
    _upgrade_data = upgrades.duplicate(true)
    _build_cards()

func refresh_state(owned_upgrades: Array) -> void:
    for upgrade_id in _card_lookup.keys():
        var card := _card_lookup[upgrade_id]
        var button: Button = card.get_node("PurchaseButton")
        button.disabled = owned_upgrades.has(upgrade_id)
        if button.disabled:
            button.text = "Comprado ✔"
        else:
            button.text = "Comprar"

func toggle_visible() -> void:
    visible = not visible

func _build_cards() -> void:
    for child in list_container.get_children():
        child.queue_free()
    _card_lookup.clear()
    for upgrade in _upgrade_data:
        var upgrade_id := upgrade.get("id", "")
        var card := preload("res://scenes/ui/UpgradeCard.tscn").instantiate()
        card.get_node("Title").text = upgrade.get("name", "Upgrade")
        card.get_node("Description").text = upgrade.get("description", "")
        card.get_node("Price").text = "$%d" % int(upgrade.get("cost", 0))
        var button: Button = card.get_node("PurchaseButton")
        button.pressed.connect(_on_purchase.bind(upgrade_id))
        list_container.add_child(card)
        _card_lookup[upgrade_id] = card

func _on_purchase(upgrade_id: String) -> void:
    GameState.purchase_upgrade(upgrade_id)
