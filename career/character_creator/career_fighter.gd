class_name CareerFighter
extends Resource

@export var first_name := "Nuevo"
@export var last_name := "Boxeador"
@export var nickname := "Prospecto"
@export_range(18, 45, 1) var age := 21
@export var country := "Chile"
@export var dominant_hand := "Right"
@export var guard := "Orthodox"
@export var height_cm := 178
@export var weight_kg := 72
@export var skin_tone := "Medium"
@export var hair_style := "Short"
@export var hair_color := "Black"
@export var beard_style := "None"
@export var beard_color := "Black"
@export var shorts := "Classic"
@export var shorts_color := "Black"
@export var gloves := "Pro"
@export var glove_color := "Red"
@export var shoes := "High Top"
@export var fight_style := "Balanced"


func to_dictionary() -> Dictionary:
	return {
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname,
		"age": age,
		"country": country,
		"dominant_hand": dominant_hand,
		"guard": guard,
		"height_cm": height_cm,
		"weight_kg": weight_kg,
		"style": fight_style,
		"appearance": {
			"skin_tone": skin_tone,
			"hair_style": hair_style,
			"hair_color": hair_color,
			"beard_style": beard_style,
			"beard_color": beard_color,
			"shorts": shorts,
			"shorts_color": shorts_color,
			"gloves": gloves,
			"glove_color": glove_color,
			"shoes": shoes,
			"guard": guard,
			"dominant_hand": dominant_hand,
			"height_cm": height_cm,
			"weight_kg": weight_kg,
		},
	}


static func from_dictionary(data: Dictionary) -> Resource:
	var script: Script = load("res://career/character_creator/career_fighter.gd")
	var fighter: Resource = script.new()
	var keys := [
		"first_name", "last_name", "nickname", "age", "country", "dominant_hand", "guard",
		"height_cm", "weight_kg", "skin_tone", "hair_style", "hair_color", "beard_style",
		"beard_color", "shorts", "shorts_color", "gloves", "glove_color", "shoes", "fight_style"
	]
	for key in data:
		if key == "appearance" and data[key] is Dictionary:
			for appearance_key in data[key]:
				if appearance_key in keys:
					fighter.set(appearance_key, data[key][appearance_key])
		elif key in keys:
			fighter.set(key, data[key])
	return fighter
