# Codex Rules

Read `docs/ARCHITECTURE.md` and the active plan before changing fight, fighter, animation, or UI flow code.

Every gameplay task must declare its phase:
- Phase 1: stable Quick Fight base, events, telemetry, fighter selection, MoveData, core presentation.
- Phase 2: master combat feel, defense, counters, footwork consequences, AI tactics, impact feedback.
- Phase 3: production polish, career-light flow, practice, settings, accessibility, optimization, export.

Use `scripts/managers/combat_phase_plan.gd` as the source of truth for phase names, telemetry ids, required runners, and exit criteria.

Keep changes small: one behavior per task, with a failing runner first and a passing focused runner before moving on.

Do not rename public nodes, animation names, signals, input actions, or fighter scene paths unless the task explicitly requires the migration and updates all tests.

Do not touch fighters outside the task scope. `boxer_green`, `boxer_02`, and `boxer_03` must remain selectable after every task.

Prefer manager-level event emissions over direct coupling. Presentation systems should listen to `Events`; gameplay rules should stay in managers, resources, or fighter components.

Always report:
- files changed
- runners executed
- pass/fail result
- new warnings
- known warnings that remain

If a runner fails for an unrelated pre-existing reason, record the exact failure and stop before broadening scope.
