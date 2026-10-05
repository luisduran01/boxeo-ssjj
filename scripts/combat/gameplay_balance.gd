class_name GameplayBalance
extends Resource

const PERFECT_DEFENSE_FRAMES := 6
const NORMAL_DEFENSE_FRAMES := 14
const GUARD_SWITCH_FRAMES := 5
const DEFENSE_SPAM_COST := 0.9
const CLINCH_SECONDS := 2.4
const CLINCH_COOLDOWN := 3.0
const CLINCH_STAMINA_RECOVERY := 7.0
const CORNER_DAMAGE_BONUS := 1.10
const ROPE_REBOUND := 0.18
const FLASH_KD_BASE_CHANCE := 0.06
const LIVER_SHOT_STUN := 22.0
const ROUND_FATIGUE := 0.04


static func range_modifier(range_name: String) -> Dictionary:
	match range_name:
		"TOO_CLOSE":
			return {"damage_mult": 0.72, "accuracy_mult": 0.78, "body_bonus": 1.1}
		"POCKET":
			return {"damage_mult": 1.08, "accuracy_mult": 1.0, "body_bonus": 1.08}
		"MID_RANGE":
			return {"damage_mult": 1.0, "accuracy_mult": 1.0, "body_bonus": 1.0}
		"LONG_RANGE":
			return {"damage_mult": 0.82, "accuracy_mult": 0.72, "body_bonus": 0.9}
	return {"damage_mult": 0.65, "accuracy_mult": 0.55, "body_bonus": 0.85}
