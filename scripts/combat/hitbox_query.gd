class_name HitboxQuery
extends RefCounted

var hurtboxes: Array[Dictionary] = []
var environment_bodies: Array[Dictionary] = []
var _active_hits := {}


func add_hurtbox(zone_id: int, zone: String, center: Vector3, radius: float, bone := "") -> void:
	hurtboxes.append({
		"zone_id": zone_id,
		"zone": zone,
		"center": center,
		"radius": radius,
		"bone": bone,
	})


func configure_default_zones() -> void:
	hurtboxes.clear()
	add_hurtbox(1, "head", Vector3(0.0, 1.55, 0.0), 0.22, "mixamorig_Head")
	add_hurtbox(2, "jaw", Vector3(0.0, 1.42, -0.03), 0.16, "mixamorig_Head")
	add_hurtbox(3, "torso", Vector3(0.0, 1.12, 0.0), 0.30, "mixamorig_Spine2")
	add_hurtbox(4, "liver_left", Vector3(0.19, 1.02, 0.0), 0.18, "mixamorig_Spine1")
	add_hurtbox(5, "liver_right", Vector3(-0.19, 1.02, 0.0), 0.18, "mixamorig_Spine1")
	add_hurtbox(6, "left_arm", Vector3(0.34, 1.22, 0.0), 0.16, "mixamorig_LeftArm")
	add_hurtbox(7, "right_arm", Vector3(-0.34, 1.22, 0.0), 0.16, "mixamorig_RightArm")


func hurtboxes_by_bone() -> Dictionary:
	var by_bone := {}
	for hurtbox in hurtboxes:
		by_bone[str(hurtbox.bone)] = hurtbox
	return by_bone


func add_environment_body(kind: String, center: Vector3, radius: float) -> void:
	environment_bodies.append({"kind": kind, "center": center, "radius": radius})


func sweep_hit(prev_pos: Vector3, cur_pos: Vector3, glove_radius: float, substeps := 3) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen := {}
	var steps := maxi(1, substeps)
	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var sample := prev_pos.lerp(cur_pos, t)
		for hurtbox in hurtboxes:
			var zone_id := int(hurtbox.zone_id)
			if seen.has(zone_id):
				continue
			var center: Vector3 = hurtbox.center
			var radius := float(hurtbox.radius) + glove_radius
			if sample.distance_to(center) <= radius:
				seen[zone_id] = true
				results.append({
					"zone_id": zone_id,
					"zone": str(hurtbox.zone),
					"point": sample,
					"impact_dir": (center - sample).normalized(),
				})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.zone_id) < int(b.zone_id)
	)
	return results


func register_active_hit(attack_id: String, zone_id: int) -> bool:
	var key := "%s:%d" % [attack_id, zone_id]
	if _active_hits.has(key):
		return false
	_active_hits[key] = true
	return true


func reset_active_phase(attack_id := "") -> void:
	if attack_id == "":
		_active_hits.clear()
		return
	for key in _active_hits.keys():
		if str(key).begins_with(attack_id + ":"):
			_active_hits.erase(key)
