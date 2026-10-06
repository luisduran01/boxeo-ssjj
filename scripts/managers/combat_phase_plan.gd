class_name CombatPhasePlan
extends RefCounted

const PHASES := [
	{
		"phase": 1,
		"name": "Base jugable solida",
		"telemetry_id": "phase_1_base_jugable",
		"goal": "Quick Fight estable con peleadores seleccionables, rounds, KO, TKO, decision, eventos y telemetria.",
		"required_runners": [
			"res://tests/fight_lifecycle_runner.gd",
			"res://tests/fight_system_runner.gd",
			"res://tests/events_runner.gd",
			"res://tests/all_fighters_animation_runner.gd",
			"res://tests/move_data_runner.gd",
			"res://tests/presentation_feedback_runner.gd",
		],
		"exit_criteria": [
			"Los tres peleadores base son seleccionables y conservan AnimationTree activo.",
			"Una pelea completa puede terminar por decision, KO o TKO.",
			"HUD, audio, camara, Events y telemetria reaccionan a los hechos principales.",
			"Los datos de golpes cargan desde MoveData sin romper CombatRules.",
		],
	},
	{
		"phase": 2,
		"name": "Combate maestro",
		"telemetry_id": "phase_2_combate_maestro",
		"goal": "Profundizar el boxeo tecnico con rangos, counters, defensa con coste, impacto direccional, footwork e IA tactica.",
		"required_runners": [
			"res://tests/phase_gameplay_runner.gd",
			"res://tests/phase_systems_runner.gd",
			"res://tests/technical_combat_runner.gd",
			"res://tests/boxing_footwork_controller_runner.gd",
			"res://tests/gameplay_completion_runner.gd",
			"res://tests/presentation_feedback_runner.gd",
		],
		"exit_criteria": [
			"Jab, cross, hooks, uppercut y variantes al cuerpo tienen lectura, coste y counterplay.",
			"Bloqueos, slips, duck, pivot y clinch tienen ventanas y riesgos claros.",
			"La IA usa rango, memoria de patrones, defensa imperfecta y modos tacticos.",
			"Los impactos limpios, bloqueados, whiffs y counters se distinguen en feedback.",
		],
	},
	{
		"phase": 3,
		"name": "Produccion final",
		"telemetry_id": "phase_3_produccion_final",
		"goal": "Cerrar experiencia jugable con carrera ligera, practica, accesibilidad, settings persistentes, optimizacion, QA y export.",
		"required_runners": [
			"res://tests/settings_application_runner.gd",
			"res://tests/settings_menu_runner.gd",
			"res://tests/career_menu_runner.gd",
			"res://tests/character_creator_runner.gd",
			"res://tests/live_flow_runner.gd",
			"res://tests/integration_runner.gd",
		],
		"exit_criteria": [
			"Settings, controles, audio, camara y accesibilidad se aplican y persisten.",
			"Carrera ligera y creador abren, guardan y vuelven al flujo principal.",
			"Modo practica permite repetir casos de distancia, defensa e impacto.",
			"La build final es reproducible y no tiene regresiones bloqueantes.",
		],
	},
]


static func all_phases() -> Array:
	return PHASES.duplicate(true)


static func phase(number: int) -> Dictionary:
	for item: Dictionary in PHASES:
		if int(item.phase) == number:
			return item.duplicate(true)
	return {}


static func telemetry_id_for_phase(number: int) -> String:
	var data := phase(number)
	return str(data.get("telemetry_id", "phase_unknown"))


static func phase_for_runner(runner_path: String) -> int:
	for item: Dictionary in PHASES:
		for candidate in Array(item.required_runners):
			if str(candidate) == runner_path:
				return int(item.phase)
	return 0
