extends HSlider

var settings_key := &""
var _last_value := INF


func _set(property: StringName, new_value: Variant) -> bool:
	if property == &"value":
		set_value_no_signal(float(new_value))
		_sync_value()
		return true
	return false


func _ready() -> void:
	_last_value = value


func _process(_delta: float) -> void:
	_sync_value()


func _sync_value() -> void:
	if settings_key == &"":
		return
	if is_equal_approx(float(_last_value), value):
		return
	_last_value = value
	SaveSystem.update_setting(settings_key, value, false)
