extends CanvasLayer

const STEP_DURATION := 8.0

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton

var _steps: Array = []
var _index: int = -1
var _timer: float = 0.0

func _ready() -> void:
    visible = false
    set_process(false)
    continue_button.pressed.connect(_advance_step)

func setup(steps: Array) -> void:
    _steps = steps.duplicate(true)
    if _steps.is_empty():
        return
    _index = -1
    visible = true
    _advance_step()

func _advance_step() -> void:
    _index += 1
    if _index >= _steps.size():
        _finish()
        return
    var step := _steps[_index]
    title_label.text = step.get("title", "Tutorial")
    body_label.text = step.get("body", "")
    _timer = 0.0
    set_process(true)

func _process(delta: float) -> void:
    _timer += delta
    if _timer >= STEP_DURATION:
        _advance_step()

func _finish() -> void:
    set_process(false)
    visible = false
