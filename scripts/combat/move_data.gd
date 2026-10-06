class_name MoveData
extends Resource

@export var id: StringName
@export var animation_name := ""
@export var hand := ""
@export var attack_type := ""
@export var target_level := "head"
@export var startup_frames := 0.0
@export var active_frames := 0.0
@export var recovery_frames := 0.0
@export var damage := 0.0
@export var stamina_cost := 0.0
@export var min_range := 0.0
@export var max_range := 0.0
@export var power := 1.0
@export var stun := 0.0
@export var counter_bonus := 1.0
@export var movement_allowed := 0.0
@export var tracking_strength := 0.0
@export var step_in := 0.0
@export var hitstop_frames := 0.0
@export var pushback := 0.0
@export var sweet_spot_min := 0.0
@export var sweet_spot_max := 0.0
@export var whiff_recovery_extra := 0.15
@export var whiff_stamina_mult := 1.5
@export var magnetism := 0.0
@export var stun_power := 0.0
@export var counter_mult := 1.28
@export var cancel_start_frame := 0.0
@export var cancel_end_frame := 0.0
@export var camera_feedback := 0.0
@export var animation_speed := 1.0
@export var cancel_window_frames := 0.0
@export_range(0.0, 1.0, 0.01) var procedural_strength := 0.0
@export var ctrl_out_1 := Vector3(0.0, 0.03, 0.28)
@export var ctrl_out_2 := Vector3(0.0, 0.0, -0.10)
@export var ctrl_back_1 := Vector3(0.0, 0.02, -0.18)
@export var ctrl_back_2 := Vector3(0.0, 0.0, 0.12)
@export var weight_transfer := 0.15
@export var shoulder_guard_bias := 0.22


func to_attack_data(fps := 60.0) -> Dictionary:
	var startup := startup_frames / fps
	var active_time := active_frames / fps
	var recovery := recovery_frames / fps
	var cancel_window := cancel_window_frames / fps
	var hit_stop := hitstop_frames / fps
	var resolved_sweet_min := sweet_spot_min if sweet_spot_min > 0.0 else min_range
	var resolved_sweet_max := sweet_spot_max if sweet_spot_max > 0.0 else max_range
	var resolved_pushback := pushback if pushback > 0.0 else power * 0.08
	var resolved_magnetism := magnetism if magnetism > 0.0 else tracking_strength
	var resolved_stun_power := stun_power if stun_power > 0.0 else stun
	var resolved_cancel_end := cancel_end_frame if cancel_end_frame > 0.0 else recovery_frames
	var resolved_cancel_start := cancel_start_frame if cancel_start_frame > 0.0 else maxf(0.0, resolved_cancel_end - cancel_window_frames)
	return {
		"attack_name": str(id),
		"animation_name": animation_name,
		"hand": hand,
		"attack_type": attack_type,
		"target_level": target_level,
		"startup_frames": startup_frames,
		"active_frames": active_frames,
		"recovery_frames": recovery_frames,
		"startup": startup,
		"active_time": active_time,
		"recovery": recovery,
		"damage": damage,
		"stamina_cost": stamina_cost,
		"min_range": min_range,
		"max_range": max_range,
		"range": max_range,
		"power": power,
		"stun": stun,
		"counter_bonus": counter_bonus,
		"movement_allowed": movement_allowed,
		"tracking_strength": tracking_strength,
		"step_in": step_in,
		"hitstop_frames": hitstop_frames,
		"pushback": resolved_pushback,
		"sweet_spot_min": resolved_sweet_min,
		"sweet_spot_max": resolved_sweet_max,
		"whiff_recovery_extra": whiff_recovery_extra,
		"whiff_stamina_mult": whiff_stamina_mult,
		"magnetism": resolved_magnetism,
		"stun_power": resolved_stun_power,
		"counter_mult": counter_mult,
		"cancel_start_frame": resolved_cancel_start,
		"cancel_end_frame": resolved_cancel_end,
		"hit_stop": hit_stop,
		"camera_feedback": camera_feedback,
		"animation_speed": animation_speed,
		"cancel_window_frames": cancel_window_frames,
		"cancel_window": cancel_window,
		"procedural_strength": procedural_strength,
		"ctrl_out_1": ctrl_out_1,
		"ctrl_out_2": ctrl_out_2,
		"ctrl_back_1": ctrl_back_1,
		"ctrl_back_2": ctrl_back_2,
		"weight_transfer": weight_transfer,
		"shoulder_guard_bias": shoulder_guard_bias,
		"active": active_time,
		"cost": stamina_cost,
		"zone": target_level,
	}


func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id is required")
	if animation_name == "":
		errors.append("%s animation_name is required" % id)
	if hand == "":
		errors.append("%s hand is required" % id)
	if attack_type == "":
		errors.append("%s attack_type is required" % id)
	for field in [
		["startup_frames", startup_frames],
		["active_frames", active_frames],
		["recovery_frames", recovery_frames],
		["damage", damage],
		["stamina_cost", stamina_cost],
		["min_range", min_range],
		["max_range", max_range],
		["power", power],
		["stun", stun],
		["counter_bonus", counter_bonus],
		["animation_speed", animation_speed],
	]:
		if float(field[1]) <= 0.0:
			errors.append("%s %s must be positive" % [id, field[0]])
	return errors
