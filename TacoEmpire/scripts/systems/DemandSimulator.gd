extends Node
class_name DemandSimulator

signal demand_segment_changed(segment_id)
signal demand_snapshot(snapshot)

var _segments: Array = []
var _conversion_rate: float = 0.6
var _drizzle_config: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _minute_accumulator: float = 0.0
var _current_segment_id: String = ""
var _cached_snapshot: Dictionary = {}

func setup(data: Dictionary) -> void:
    _segments = data.get("segments", [])
    _segments.sort_custom(self, "_sort_segments")
    _conversion_rate = float(data.get("conversion_rate", 0.6))
    _drizzle_config = data.get("drizzle_event", {})
    _rng.randomize()

func _sort_segments(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("start_hour", 0)) < int(b.get("start_hour", 0))

func update(delta: float, hour_of_day: float, economy: Economy) -> Dictionary:
    _minute_accumulator += delta
    while _minute_accumulator >= 60.0:
        _minute_accumulator -= 60.0
        _maybe_trigger_drizzle()
    var segment := _find_segment(hour_of_day)
    if segment.get("id", "") != _current_segment_id:
        _current_segment_id = segment.get("id", "")
        emit_signal("demand_segment_changed", _current_segment_id)
    var event_multiplier := 1.0
    if _drizzle_config and EventManager.is_active(_drizzle_config.get("id", "")):
        event_multiplier = float(_drizzle_config.get("demand_multiplier", 1.0))
    var base_customers := float(segment.get("base_customers_per_min", 0.0))
    var affluence := base_customers * economy.demand_multiplier * event_multiplier
    var price_multiplier := float(segment.get("price_multiplier", 1.0))
    var snapshot := {
        "segment_id": segment.get("id", ""),
        "customers_per_min": affluence,
        "conversion_rate": _conversion_rate,
        "price_multiplier": price_multiplier,
        "event_multiplier": event_multiplier
    }
    _cached_snapshot = snapshot
    emit_signal("demand_snapshot", snapshot)
    return snapshot

func get_cached_snapshot() -> Dictionary:
    return _cached_snapshot.duplicate(true)

func _find_segment(hour_of_day: float) -> Dictionary:
    for segment in _segments:
        var start := int(segment.get("start_hour", 0))
        var end := int(segment.get("end_hour", 24))
        if hour_of_day >= start and hour_of_day <= end:
            return segment
    if _segments.is_empty():
        return {}
    return _segments[0]

func _maybe_trigger_drizzle() -> void:
    if _drizzle_config.is_empty():
        return
    var event_id := _drizzle_config.get("id", "")
    if event_id == "":
        return
    if EventManager.is_active(event_id):
        return
    var probability := float(_drizzle_config.get("probability_per_min", 0.0))
    if probability <= 0.0:
        return
    var roll := _rng.randf()
    if roll <= probability:
        EventManager.trigger_event(_drizzle_config)
