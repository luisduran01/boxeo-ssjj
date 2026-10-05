# Boxeo 3D Architecture

## Scope

This project is a boxing game. Do not add MMA ground game, submissions, licensed brands, or real league content. The current production target is a polished Quick Fight vertical slice before deep career work.

## Runtime Flow

`scripts/fight/fight_scene.gd` builds the fight scene: ring, selected fighters, camera, HUD, audio, referee, and `FightManager`.

`scripts/managers/fight_manager.gd` owns the fight lifecycle:
- round setup and transitions through `RoundManager`
- knockdown count and KO or TKO resolution through `FightRules`
- scorecards through `Judges`
- per-round and total stats through `FightStats`
- local fight signals and global `Events` emissions

`fighters/shared/boxer_controller.gd` is the shared behavior authority for fighters. Treat it as high risk: movement, attacks, defense, stamina, damage, AI adapter, animation, and knockdown behavior all live there today.

## Event Flow

Use the `Events` autoload for cross-system listeners. HUD, audio, camera, presentation, statistics overlays, and future replay systems should listen to `Events` instead of reaching into fighter internals.

Current global signals:
- `fight_started`
- `round_started(round_number: int)`
- `round_ended(round_number: int, cards: Array)`
- `punch_landed(attacker: Node, defender: Node, result: Dictionary)`
- `knockdown_started(fallen: Node, standing: Node)`
- `fight_finished(result: Dictionary)`

Local signals on `FightManager` and `BoxerController` remain valid for direct ownership boundaries. Emit global events from central manager handlers so each gameplay fact is broadcast once.

## Data Ownership

`CombatRules` currently contains attack tuning and hit calculation. The next combat architecture step is to move attack tuning into `MoveData` resources and keep calculation logic in code.

`FighterData` resources describe selectable fighters. Scene-specific model, material, and animation details stay inside each fighter scene until the shared animation contract is complete.

## Test Gates

Run focused runners after every behavioral change:
- fight lifecycle: `res://tests/fight_lifecycle_runner.gd`
- fight systems: `res://tests/fight_system_runner.gd`
- combat integration: `res://tests/combat_runner.gd`
- live/menu flow as affected: `res://tests/live_flow_runner.gd`

Known environmental warnings may appear for Windows certificate store reads and invalid `boxer_green.tscn` animation UIDs. They are not pass/fail signals unless a task explicitly targets them.
