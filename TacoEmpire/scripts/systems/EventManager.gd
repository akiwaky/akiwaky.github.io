extends Node
class_name EventManager

signal event_started(event_data)
signal event_ended(event_data)

var _active_events: Dictionary = {}

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    var completed: Array = []
    for event_id in _active_events.keys():
        var info := _active_events[event_id]
        info["remaining"] = max(0.0, float(info.get("remaining", 0.0)) - delta)
        _active_events[event_id] = info
        if info["remaining"] <= 0.0:
            completed.append(event_id)
    for event_id in completed:
        var info := _active_events.get(event_id, {})
        if info.has("data"):
            emit_signal("event_ended", info["data"])
        _active_events.erase(event_id)

func trigger_event(event_data: Dictionary) -> void:
    var event_id: String = event_data.get("id", "")
    if event_id == "" or _active_events.has(event_id):
        return
    _active_events[event_id] = {
        "data": event_data,
        "remaining": float(event_data.get("duration_seconds", 0.0))
    }
    emit_signal("event_started", event_data)

func is_active(event_id: String) -> bool:
    return _active_events.has(event_id)

func clear() -> void:
    _active_events.clear()
