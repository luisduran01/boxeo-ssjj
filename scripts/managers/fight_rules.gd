class_name FightRules
extends RefCounted


static func should_knockdown(health: float, head_health: float, stun: float, incoming_stun: float) -> bool:
	return health <= 0.0 or head_health <= 0.0 or stun + incoming_stun >= 100.0


static func can_get_up(knockdowns: int, stamina: float, count: int) -> bool:
	var threshold := 13.0 + float(maxi(0, knockdowns - 1)) * 22.0 + float(count) * 1.4
	return knockdowns < 4 and stamina >= threshold


static func should_tko(knockdowns: int, configured_limit: int) -> bool:
	return configured_limit > 0 and knockdowns >= configured_limit
