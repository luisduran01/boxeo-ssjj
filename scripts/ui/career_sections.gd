class_name CareerSections
extends RefCounted

const Database = preload("res://scripts/data/fighter_database.gd")
const CareerModel = preload("res://scripts/data/career_data.gd")

static func build(section: StringName, data: Dictionary) -> VBoxContainer:
	var box := MenuComponents.panel(str(section).replace("_", " ").to_upper())
	match section:
		&"summary": _summary(box, data)
		&"training": _training(box, data)
		&"calendar": _calendar(box, data)
		&"team": _team(box)
		&"contracts": _contracts(box, data)
		&"ranking": _ranking(box)
		&"news": _news(box, data)
		&"statistics": _statistics(box, data)
	return box

static func _summary(box: VBoxContainer, data: Dictionary) -> void:
	_add_text(box, "%s\nRANKING  #%d\nRÉCORD  %d-%d-%d  (%d KO)\nDINERO  $%d\nCONDICIÓN  %d%%\nFATIGA  %d%%\nPRÓXIMA PELEA  %s — %s" % [data.name, data.ranking, data.wins, data.losses, data.draws, data.kos, data.money, data.fitness, data.fatigue, data.next_opponent, data.next_fight_date], 21)
	_add_text(box, "HISTORIAL RECIENTE", 20, true)
	if data.fight_history.is_empty(): _add_text(box, "Sin peleas registradas")
	for entry in data.fight_history.slice(0, 5):
		_add_text(box, "%s  %s · R%d  vs %s  %s" % [entry.result, entry.method, entry.round, entry.opponent, entry.date])

static func _training(box: VBoxContainer, data: Dictionary) -> void:
	_add_text(box, "Selecciona una categoría. Cada sesión avanza una semana, aumenta fatiga y mejora 2 puntos.")
	for key in CareerModel.ATTRIBUTE_KEYS: box.add_child(MenuComponents.stat_bar(str(key).to_upper(), float(data.attributes[key])))
	box.add_child(MenuComponents.stat_bar("PROGRESO", float(data.training_progress)))
	box.add_child(MenuComponents.stat_bar("CONDICIÓN", float(data.fitness)))

static func _calendar(box: VBoxContainer, data: Dictionary) -> void:
	_add_text(box, "SEMANA %d\nFECHA ACTUAL  %s\n\nPRÓXIMA PELEA\n%s\n%s\nRANKING #%d" % [data.current_week, data.current_date, data.next_opponent, data.next_fight_date, data.ranking], 20)

static func _team(box: VBoxContainer) -> void:
	_add_text(box, "ENTRENADOR PRINCIPAL — DISPONIBLE\nPREPARADOR FÍSICO — BLOQUEADO\nCUTMAN — BLOQUEADO\nMANAGER — BLOQUEADO")

static func _contracts(box: VBoxContainer, data: Dictionary) -> void:
	var opponent := Database.by_id(StringName(str(data.next_opponent)))
	_add_text(box, "OFERTA ACTUAL\nOPONENTE  %s\nFECHA  %s\nBOLSA  $650\nFORMATO  %d ROUNDS" % [opponent.display_name if opponent else data.next_opponent, data.next_fight_date, SaveSystem.settings.rounds], 20)

static func _ranking(box: VBoxContainer) -> void:
	var position := 1
	for fighter in Database.all():
		_add_text(box, "%02d   %s    0-0-0    0 KO" % [position, fighter.display_name], 19, fighter.id == &"fighter_1")
		position += 1

static func _news(box: VBoxContainer, data: Dictionary) -> void:
	if data.news.is_empty(): _add_text(box, "No hay noticias todavía. Entrena, descansa o acepta una pelea.")
	for item in data.news: _add_text(box, "• " + str(item))

static func _statistics(box: VBoxContainer, data: Dictionary) -> void:
	_add_text(box, "VICTORIAS  %d\nDERROTAS  %d\nEMPATES  %d\nKO  %d\nFANS  %d\nSEMANAS COMPLETADAS  %d" % [data.wins, data.losses, data.draws, data.kos, data.fans, data.current_week - 1], 20)
	for key in CareerModel.ATTRIBUTE_KEYS: box.add_child(MenuComponents.stat_bar(str(key).to_upper(), float(data.attributes[key])))

static func _add_text(box: VBoxContainer, text: String, size: int = 17, gold: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	if gold: label.add_theme_color_override("font_color", BoxingTheme.palette().bright_gold)
	box.add_child(label)
