class_name FighterDatabase
extends RefCounted

const FIGHTER_1 := preload("res://data/fighters/boxer_green.tres")
const FIGHTER_2 := preload("res://data/fighters/boxer_02.tres")
const FIGHTER_3 := preload("res://data/fighters/boxer_03.tres")


static func all() -> Array[FighterData]:
	var fighters: Array[FighterData] = [FIGHTER_1, FIGHTER_2, FIGHTER_3]
	return fighters


static func by_id(id: StringName) -> FighterData:
	for fighter in all():
		if fighter.id == id:
			return fighter
	return null


static func valid_for_fight() -> Array[FighterData]:
	return filter_valid(all())


static func filter_valid(candidates: Array) -> Array[FighterData]:
	var result: Array[FighterData] = []
	var seen: Dictionary = {}
	for candidate in candidates:
		if not candidate is FighterData:
			continue
		var fighter := candidate as FighterData
		if fighter.id == &"" or fighter.scene == null or seen.has(fighter.id):
			continue
		seen[fighter.id] = true
		result.append(fighter)
	return result
