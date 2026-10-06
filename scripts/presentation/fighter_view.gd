class_name FighterView
extends RefCounted

var id := 0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var facing := Vector3.FORWARD
var stance := 0
var move_id := &""
var move_frame := 0
var phase := "IDLE"
var guard_state := "HIGH"
var defense_action := ""
var stamina_ratio := 1.0
var stability := 1.0
var wobble := 0.0
var stun_frames := 0
var in_clinch := false
var hitstop_left := 0
var opp_head_pos := Vector3.ZERO
var opp_body_pos := Vector3.ZERO


static func from_fighter(fighter: BoxerController, fighter_id := 0):
	var view = load("res://scripts/presentation/fighter_view.gd").new()
	view.id = fighter_id
	view.pos = fighter.global_position
	view.vel = fighter.velocity
	view.facing = -fighter.global_basis.z.normalized()
	view.move_id = StringName(fighter._current_attack)
	view.move_frame = fighter.procedural_move_frame
	view.phase = fighter.combat_state
	view.guard_state = fighter.block_state if fighter.block_state != "" else "HIGH"
	view.defense_action = fighter.evasion_state
	view.stamina_ratio = clampf(float(fighter.stats.stamina) / maxf(float(fighter.stats.max_stamina), 0.01), 0.0, 1.0)
	view.stability = clampf(fighter.stability / maxf(fighter.max_stability, 0.01), 0.0, 1.0)
	view.wobble = 1.0 if fighter.combat_state == "WOBBLED" else 0.0
	view.in_clinch = fighter.combat_state == "CLINCH"
	if fighter.opponent is BoxerController:
		var opponent := fighter.opponent as BoxerController
		view.opp_head_pos = opponent.global_position + Vector3(0.0, opponent.body_height * 0.92, 0.0)
		view.opp_body_pos = opponent.global_position + Vector3(0.0, opponent.body_height * 0.62, 0.0)
	return view
