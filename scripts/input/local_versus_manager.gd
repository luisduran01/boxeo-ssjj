class_name LocalVersusManager
extends Node

var _player_devices := {}
var _disconnected := {}
var _player_profiles := {}
var _fighter_selection := {}
var _rematch_requested := false


func assign_player_device(player_index: int, device_id: int) -> void:
	_player_devices[player_index] = device_id
	_disconnected.erase(device_id)
	if not _player_profiles.has(player_index):
		_player_profiles[player_index] = {"scheme": "classic", "body_modifier": "R2" if player_index == 1 else "RT"}


func device_for_player(player_index: int) -> int:
	return int(_player_devices.get(player_index, -1))


func mark_device_disconnected(device_id: int) -> void:
	_disconnected[device_id] = true


func handle_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_disconnected.erase(device_id)
	else:
		mark_device_disconnected(device_id)


func should_pause_for_disconnect() -> bool:
	for device_id in _player_devices.values():
		if bool(_disconnected.get(device_id, false)):
			return true
	return false


func set_player_profile(player_index: int, profile: Dictionary) -> void:
	_player_profiles[player_index] = profile.duplicate(true)


func profile_for_player(player_index: int) -> Dictionary:
	return _player_profiles.get(player_index, {"scheme": "classic", "body_modifier": "R2"}).duplicate(true)


func select_fighter(player_index: int, fighter_id: String) -> void:
	_fighter_selection[player_index] = fighter_id


func selected_fighter_for_player(player_index: int) -> String:
	return str(_fighter_selection.get(player_index, ""))


func request_rematch() -> void:
	_rematch_requested = true


func consume_rematch_requested() -> bool:
	var requested := _rematch_requested
	_rematch_requested = false
	return requested
