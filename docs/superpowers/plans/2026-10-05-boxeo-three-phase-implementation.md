# Boxeo Three Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the boxing game roadmap as three gated production phases: stable playable base, master combat, and final production.

**Architecture:** The project now exposes the three phases through `CombatPhasePlan`, so tests, telemetry, and future UI can reference the same contract. Each phase is advanced by focused runners and exit criteria rather than by broad rewrites.

**Tech Stack:** Godot 4.7, GDScript, existing headless runner scripts under `tests/`, event-driven fight stack with `FightManager`, `Events`, `MoveData`, `MoveLibrary`, `FightTelemetry`, and `BoxerController`.

**Spec:** `E:\boxeo-ssjj\Manual_Tecnico_Maestro_Combate_Boxeo_Godot_3_Fases_COMPLETO.docx`

## Global Constraints

- Scope remains boxing only.
- Do not rename public nodes, animation names, signals, input actions, or fighter scene paths without updating tests.
- Each phase must end with a playable build, focused runners, and documented warnings.
- Presentation and telemetry may read combat facts; they must not change the logical fight result.
- Leave unrelated dirty worktree changes alone.

## Review Focus

- Phase telemetry ids must stay stable so CSV history is comparable across builds.
- A runner may belong to only one primary phase gate to keep pass/fail reports readable.
- Fase 1 must not depend on deep career features.
- Fase 2 combat changes must keep existing Quick Fight flow working.
- Fase 3 production work must not weaken combat gates from Fase 1 and Fase 2.

---

## Task 1: Phase Contract

**Files:**
- Create: `scripts/managers/combat_phase_plan.gd`
- Create: `tests/three_phase_plan_runner.gd`
- Modify: `scripts/managers/fight_manager.gd`

**Interfaces:**
- Produces: `CombatPhasePlan.all_phases() -> Array`, `CombatPhasePlan.phase(number: int) -> Dictionary`, `CombatPhasePlan.telemetry_id_for_phase(number: int) -> String`, and `CombatPhasePlan.phase_for_runner(runner_path: String) -> int`.
- Consumes: `FightTelemetry.start_fight(p_version_id := "")`.

- [x] **Step 1: Write the failing phase contract runner**

Add `tests/three_phase_plan_runner.gd` asserting exactly three phases, stable telemetry ids, runner ownership, exit criteria, and `FightManager` use of the phase 1 telemetry id.

- [x] **Step 2: Implement `CombatPhasePlan`**

Create `scripts/managers/combat_phase_plan.gd` with phase metadata for Base jugable solida, Combate maestro, and Produccion final.

- [x] **Step 3: Connect fight telemetry**

Modify `scripts/managers/fight_manager.gd` so Quick Fight telemetry starts with `CombatPhasePlan.telemetry_id_for_phase(1)`.

- [ ] **Step 4: Run the focused runner**

Run: `Godot.exe --headless --path . --script res://tests/three_phase_plan_runner.gd`

Expected: PASS.

## Task 2: Phase 1 Gate

**Files:**
- Create: `scripts/run_phase_gate.ps1`
- Modify: `docs/CODEX_RULES.md`

**Interfaces:**
- Consumes: `CombatPhasePlan.required_runners` values.
- Produces: A repeatable phase gate command for phase 1 runners.

- [ ] **Step 1: Write a gate runner script**

Create a PowerShell script that accepts `-Phase 1`, reads the runner list from `CombatPhasePlan` or mirrors its paths, runs each Godot runner, and reports failed runner names.

- [ ] **Step 2: Run phase 1 gate**

Run: `.\scripts\run_phase_gate.ps1 -Phase 1`

Expected: all phase 1 runners pass, or the script reports a concise failed list.

## Task 3: Phase 2 Gate

**Files:**
- Modify: `scripts/run_phase_gate.ps1`

**Interfaces:**
- Consumes: phase 2 runner paths.
- Produces: `.\scripts\run_phase_gate.ps1 -Phase 2`.

- [ ] **Step 1: Add phase 2 runner support**

Include phase 2 combat and systems runners in the gate command.

- [ ] **Step 2: Run phase 2 gate**

Run: `.\scripts\run_phase_gate.ps1 -Phase 2`

Expected: all phase 2 runners pass before new advanced combat work is accepted.

## Task 4: Phase 3 Gate

**Files:**
- Modify: `scripts/run_phase_gate.ps1`

**Interfaces:**
- Consumes: phase 3 runner paths.
- Produces: `.\scripts\run_phase_gate.ps1 -Phase 3`.

- [ ] **Step 1: Add phase 3 runner support**

Include settings, career, live flow, and integration runners in the gate command.

- [ ] **Step 2: Run phase 3 gate**

Run: `.\scripts\run_phase_gate.ps1 -Phase 3`

Expected: production-facing systems pass without weakening earlier gates.
