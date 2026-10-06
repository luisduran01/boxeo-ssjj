class_name ProceduralDebugOverlay
extends Label


func update_from_debug(data: Dictionary) -> void:
	if data.is_empty():
		text = ""
		visible = false
		return
	visible = true
	var curve_count := Array(data.get("curve", [])).size()
	text = "PROC JAB strength %.2f\nframe %d active %s\npunch %s\ncurve pts %d\nimpact %s\nhead reaction %s" % [
		float(data.get("procedural_strength", 0.0)),
		int(data.get("frame", 0)),
		str(data.get("active", false)),
		str(data.get("punch_target", Vector3.ZERO)),
		curve_count,
		str(data.get("impact_vector", Vector3.ZERO)),
		str(data.get("head_reaction", Vector3.ZERO)),
	]
