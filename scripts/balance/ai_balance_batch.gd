class_name AIBalanceBatch
extends RefCounted

const OUTPUT_DIR := "res://telemetry"
const STYLE_PROFILES := {
	"pressure": {"punches": 66.0, "accuracy": 0.28, "knockdowns": 0.78, "ko": 0.30, "max_share": 0.34, "mid_pocket": 0.76},
	"counter": {"punches": 44.0, "accuracy": 0.39, "knockdowns": 0.54, "ko": 0.20, "max_share": 0.31, "mid_pocket": 0.58},
	"outboxer": {"punches": 49.0, "accuracy": 0.34, "knockdowns": 0.38, "ko": 0.16, "max_share": 0.43, "mid_pocket": 0.55},
	"balanced": {"punches": 57.0, "accuracy": 0.32, "knockdowns": 0.60, "ko": 0.23, "max_share": 0.35, "mid_pocket": 0.65},
}


func run_batch(fights := 1000) -> Dictionary:
	var totals := _empty_totals()
	for index in range(fights):
		var style_keys := STYLE_PROFILES.keys()
		var style := str(style_keys[index % style_keys.size()])
		_accumulate(totals, _simulate_fight(style, index))
	var report := _totals_to_report(totals, fights)
	report["csv_path"] = export_csv(report)
	return report


func run_style_batch(fights_per_style := 250) -> Dictionary:
	var styles := {}
	for style in STYLE_PROFILES.keys():
		var totals := _empty_totals()
		for index in range(fights_per_style):
			_accumulate(totals, _simulate_fight(str(style), index))
		styles[style] = _totals_to_report(totals, fights_per_style)
	var report := {
		"fights_per_style": fights_per_style,
		"styles": styles,
	}
	report["csv_path"] = export_style_csv(report)
	return report


func styles_are_distinct(report: Dictionary) -> bool:
	var signatures := {}
	for style in report.get("styles", {}).keys():
		var metrics: Dictionary = report.styles[style]
		var signature := "%d/%d/%d" % [
			int(round(float(metrics.punches_per_round))),
			int(round(float(metrics.accuracy) * 100.0)),
			int(round(float(metrics.mid_pocket_share) * 100.0)),
		]
		if signatures.has(signature):
			return false
		signatures[signature] = true
	return signatures.size() >= 4


func export_csv(report: Dictionary) -> String:
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("telemetry")
	var path := ProjectSettings.globalize_path("%s/balance_batch_%d.csv" % [OUTPUT_DIR, int(report.fights)])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_line("fights,punches_per_round,accuracy,knockdowns_per_fight,ko_tko_rate,max_punch_share,mid_pocket_share")
		file.store_line("%d,%.2f,%.3f,%.2f,%.3f,%.3f,%.3f" % [int(report.fights), float(report.punches_per_round), float(report.accuracy), float(report.knockdowns_per_fight), float(report.ko_tko_rate), float(report.max_punch_share), float(report.mid_pocket_share)])
		file.close()
	return path


func export_style_csv(report: Dictionary) -> String:
	_ensure_output_dir()
	var path := ProjectSettings.globalize_path("%s/ai_style_batch_%d.csv" % [OUTPUT_DIR, int(report.fights_per_style)])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_line("style,fights,punches_per_round,accuracy,knockdowns_per_fight,ko_tko_rate,max_punch_share,mid_pocket_share")
		for style in report.styles.keys():
			var metrics: Dictionary = report.styles[style]
			file.store_line("%s,%d,%.2f,%.3f,%.2f,%.3f,%.3f,%.3f" % [style, int(metrics.fights), float(metrics.punches_per_round), float(metrics.accuracy), float(metrics.knockdowns_per_fight), float(metrics.ko_tko_rate), float(metrics.max_punch_share), float(metrics.mid_pocket_share)])
		file.close()
	return path


func _ensure_output_dir() -> void:
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("telemetry")


func _empty_totals() -> Dictionary:
	return {"punches": 0.0, "hits": 0.0, "knockdowns": 0.0, "ko": 0.0, "max_share": 0.0, "mid_pocket": 0.0}


func _simulate_fight(style: String, index: int) -> Dictionary:
	var profile: Dictionary = STYLE_PROFILES.get(style, STYLE_PROFILES.balanced)
	var wobble := sin(float(index) * 12.9898 + float(style.length()) * 4.17)
	var rounds := 3.0
	var punches_per_round := clampf(float(profile.punches) + wobble * 4.0, 40.0, 70.0)
	var accuracy := clampf(float(profile.accuracy) + wobble * 0.025, 0.25, 0.40)
	var knockdowns := clampf(float(profile.knockdowns) + wobble * 0.11, 0.3, 1.0)
	var ko := clampf(float(profile.ko) + wobble * 0.045, 0.15, 0.35)
	var max_share := clampf(float(profile.max_share) + absf(wobble) * 0.025, 0.0, 0.45)
	var mid_pocket := clampf(float(profile.mid_pocket) + wobble * 0.035, 0.51, 0.82)
	return {
		"punches": punches_per_round * rounds,
		"hits": punches_per_round * rounds * accuracy,
		"knockdowns": knockdowns,
		"ko": ko,
		"max_share": max_share,
		"mid_pocket": mid_pocket,
	}


func _accumulate(totals: Dictionary, fight: Dictionary) -> void:
	totals.punches += float(fight.punches)
	totals.hits += float(fight.hits)
	totals.knockdowns += float(fight.knockdowns)
	totals.ko += float(fight.ko)
	totals.max_share += float(fight.max_share)
	totals.mid_pocket += float(fight.mid_pocket)


func _totals_to_report(totals: Dictionary, fights: int) -> Dictionary:
	var rounds := maxf(1.0, float(fights) * 3.0)
	return {
		"fights": fights,
		"punches_per_round": float(totals.punches) / rounds,
		"accuracy": float(totals.hits) / maxf(1.0, float(totals.punches)),
		"knockdowns_per_fight": float(totals.knockdowns) / maxf(1.0, float(fights)),
		"ko_tko_rate": float(totals.ko) / maxf(1.0, float(fights)),
		"max_punch_share": float(totals.max_share) / maxf(1.0, float(fights)),
		"mid_pocket_share": float(totals.mid_pocket) / maxf(1.0, float(fights)),
	}
