class_name CareerData
extends RefCounted

const ATTRIBUTE_KEYS: Array[StringName] = [&"power", &"speed", &"stamina", &"defense", &"technique"]

static func defaults() -> Dictionary:
	return {"fighter": "fighter_1", "name": "FIGHTER 1", "wins": 0, "losses": 0, "draws": 0, "kos": 0, "ranking": 50, "money": 1200, "fans": 80, "fitness": 100, "fatigue": 0, "training_progress": 0, "training_points": 0, "current_week": 1, "current_date": "2026-10-02", "next_opponent": "fighter_2", "next_fight_date": "2026-10-12", "fight_history": [], "news": [], "attributes": {"power": 70, "speed": 70, "stamina": 70, "defense": 70, "technique": 70}}

static func normalize(source: Dictionary) -> Dictionary:
	var result := defaults()
	for key in result:
		if source.has(key): result[key] = source[key]
	for key in [&"wins", &"losses", &"draws", &"kos", &"money", &"fans", &"training_points"]: result[key] = maxi(0, int(result[key]))
	result.ranking = clampi(int(result.ranking), 1, 999)
	for key in [&"fitness", &"fatigue", &"training_progress"]: result[key] = clampi(int(result[key]), 0, 100)
	result.current_week = maxi(1, int(result.current_week))
	result.fight_history = result.fight_history if result.fight_history is Array else []
	result.news = result.news if result.news is Array else []
	var source_attributes: Dictionary = result.attributes if result.attributes is Dictionary else {}
	var attributes: Dictionary = {}
	for key in ATTRIBUTE_KEYS: attributes[key] = clampi(int(source_attributes.get(key, 70)), 0, 100)
	result.attributes = attributes
	return result

static func advance_week(source: Dictionary, action: StringName) -> Dictionary:
	var result := normalize(source)
	result.current_week += 1
	if action == &"rest":
		result.fatigue = maxi(0, int(result.fatigue) - 25)
		result.fitness = mini(100, int(result.fitness) + 15)
		result.news.push_front("Semana %d: recuperación completada" % result.current_week)
	elif action in ATTRIBUTE_KEYS:
		var attributes: Dictionary = result.attributes
		attributes[action] = mini(100, int(attributes[action]) + 2)
		result.attributes = attributes
		result.fatigue = mini(100, int(result.fatigue) + 12)
		result.fitness = maxi(0, int(result.fitness) - 6)
		result.training_progress = mini(100, int(result.training_progress) + 10)
		result.news.push_front("Semana %d: entrenamiento de %s" % [result.current_week, str(action).to_upper()])
	return normalize(result)

static func history_entry(result: StringName, method: StringName, round_number: int, opponent_id: StringName, date: String) -> Dictionary:
	return {"result": str(result), "method": str(method), "round": maxi(1, round_number), "opponent": str(opponent_id), "date": date}
