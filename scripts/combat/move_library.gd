class_name MoveLibrary
extends RefCounted

const FPS := 60.0
const MOVE_PATHS := {
	&"jab": "res://data/moves/jab.tres",
	&"cross": "res://data/moves/cross.tres",
	&"left_hook": "res://data/moves/left_hook.tres",
	&"right_hook": "res://data/moves/right_hook.tres",
	&"uppercut": "res://data/moves/uppercut.tres",
}
const VARIANT_SPECS := {
	&"jab_body": {"base": &"jab", "target_level": "body", "damage": 0.86, "stun": 0.8},
	&"cross_body": {"base": &"cross", "target_level": "body", "damage": 0.9, "stun": 0.85},
	&"left_hook_body": {"base": &"left_hook", "target_level": "body", "damage": 0.92, "stun": 0.9},
	&"right_hook_body": {"base": &"right_hook", "target_level": "body", "damage": 0.92, "stun": 0.9},
	&"uppercut_body": {"base": &"uppercut", "target_level": "body", "damage": 0.88, "stun": 0.86},
	&"overhand": {"base": &"right_hook", "attack_type": "overhand", "damage": 1.08, "stun": 1.06, "recovery_frames": 1.12},
	&"double_jab": {"base": &"jab", "damage": 1.34, "stun": 1.18, "stamina_cost": 1.55, "recovery_frames": 1.24},
	&"feint": {"base": &"jab", "attack_type": "feint", "damage": 0.0, "stun": 0.0, "stamina_cost": 0.35, "recovery_frames": 0.45},
}


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in MOVE_PATHS.keys():
		ids.append(id)
	for id in VARIANT_SPECS.keys():
		ids.append(id)
	return ids


static func attack_data(id: StringName) -> Dictionary:
	var move := _load_move(id)
	if move == null:
		return _variant_attack_data(id)
	return move.to_attack_data(FPS)


static func validate() -> Array[String]:
	var errors: Array[String] = []
	for id in MOVE_PATHS.keys():
		var path := String(MOVE_PATHS[id])
		if not ResourceLoader.exists(path):
			errors.append("%s missing resource at %s" % [id, path])
			continue
		var move := _load_move(id)
		if move == null:
			errors.append("%s did not load as MoveData" % id)
			continue
		if move.id != id:
			errors.append("%s resource id mismatch: %s" % [id, move.id])
		errors.append_array(move.validate())
	return errors


static func _load_move(id: StringName) -> Resource:
	if not MOVE_PATHS.has(id):
		return null
	var resource := load(String(MOVE_PATHS[id]))
	if resource == null or not resource.has_method("to_attack_data"):
		return null
	return resource


static func _variant_attack_data(id: StringName) -> Dictionary:
	if not VARIANT_SPECS.has(id):
		return {}
	var spec: Dictionary = VARIANT_SPECS[id]
	var data := attack_data(StringName(spec.base))
	if data.is_empty():
		return {}
	data = data.duplicate(true)
	data.attack_name = str(id)
	data.id = id
	data.animation_name = str(spec.get("animation_name", data.animation_name))
	data.attack_type = str(spec.get("attack_type", data.attack_type))
	data.target_level = str(spec.get("target_level", data.target_level))
	for key in ["damage", "stun", "stamina_cost", "recovery_frames"]:
		if spec.has(key):
			data[key] = float(data[key]) * float(spec[key])
	if data.has("recovery_frames"):
		data.recovery = float(data.recovery_frames) / FPS
		data.active = data.active_time
		data.cost = data.stamina_cost
		data.zone = data.target_level
	return data
