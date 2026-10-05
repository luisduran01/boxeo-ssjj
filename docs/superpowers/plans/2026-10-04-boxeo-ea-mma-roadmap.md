# Boxeo EA MMA Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current technical boxing prototype into a polished vertical slice: stable quick fight, shared fighter architecture, canonical animations across three fighters, data-driven combat, broadcast presentation, and a safe path toward career mode.

**Architecture:** Stabilize the already-present fight stack first, then split fighter behavior around shared resources and event signals. The plan preserves the current Godot 4.7 project shape, keeps the existing runners as the acceptance gate, and adds narrow runners for each new seam before touching production code.

**Tech Stack:** Godot 4.7, GDScript, Jolt Physics, LimboAI, Phantom Camera, Runtime Controls Remap, existing headless runner scripts under `tests/`.

**Spec:** `C:\Users\Luis Duran\Downloads\Boxeo3D_Brechas_hacia_EA_MMA.docx`

## Global Constraints

- Scope is boxing only; do not add MMA ground game, submissions, licensed brands, or real league content.
- Do not start career depth until Quick Fight is complete, stable, and fun without career context.
- Treat `fighters/boxer_green/boxer_controller.gd` as behaviorally authoritative until a shared controller migration has tests.
- Preserve `SaveSystem`, fighter selection, settings, controls remap, and menu flows while changing fight systems.
- Add or update tests before each behavior change, then run the focused runner and the affected integration runners.
- Leave unrelated dirty worktree changes alone, especially current `addons/godot_ai` edits.
- Avoid large asset churn in early tasks; use existing boxer, referee, ring, audio, camera, and UI assets where possible.

## Review Focus

- Short forced rounds should finish by decision without duplicate `_end_round()` calls or skipped scorecards; Task 1 adds a forced one-round test.
- Knockdown sequences should not leave fighters disabled, neutral-corner locked, or `Engine.time_scale` altered; Task 1 adds a recovery and cleanup test.
- Boxer scene migration should not regress skeleton paths, collision layers, input actions, or animation library names; Task 2 and Task 3 add all-fighter runners.
- Move data should preserve the current five-punch feel while allowing future body shots and overhands without code edits; Task 4 pins parity against current `CombatRules`.
- Presentation systems should listen to fight events without calling private fighter methods; Task 5 adds event-driven HUD/audio/camera checks.

---

## File Structure

- `docs/ARCHITECTURE.md`: New high-level project map, rules for fight flow, events, resources, and test gates.
- `docs/ANIMATION_CATALOG.md`: New canonical animation names and required per-fighter libraries.
- `docs/CODEX_RULES.md`: New task prompt rules for Codex/Godot AI workers.
- `autoload/events.gd`: New typed project event bus for fight, hit, round, knockdown, presentation, and stats signals.
- `project.godot`: Add `Events` autoload after `ControlsRemap`.
- `scripts/managers/fight_manager.gd`: Stabilize state transitions, emit events, and route fight lifecycle through explicit states.
- `scripts/managers/round_manager.gd`: Make round/break timing idempotent and safe for very short test rounds.
- `scripts/managers/judges.gd`: Support UD, SD, MD, Draw, and Majority Draw names from scorecard totals.
- `scripts/managers/fight_stats.gd`: Keep per-round and total stats as event-fed source of truth.
- `scripts/managers/fight_result.gd`: New formatter/data helper if result assembly outgrows `FightManager`.
- `fighters/shared/boxer_controller.gd`: Target home for the current `BoxerController`.
- `fighters/shared/components/*.gd`: Later extraction targets for locomotion, attacks, defense, damage, stamina, and AI adapter.
- `scripts/combat/move_data.gd`: New `Resource` class for frame data and tuning.
- `scripts/combat/move_library.gd`: New loader/validator for `.tres` moves.
- `data/moves/*.tres`: New data assets for jab, cross, hooks, uppercut, then body/overhand variants.
- `scripts/combat/combat_rules.gd`: Keep calculation logic, but read attack definitions from `MoveLibrary`.
- `scripts/presentation/hit_feedback_system.gd`: New listener for hitstop, shake, SFX cue, vibration, and optional VFX.
- `scripts/ui/fight_hud.gd`: Add broadcast scoreboard states without owning fight rules.
- `scripts/audio/audio_manager.gd`: Expand cue routing for bell, block, impact, crowd, referee, and announcer.
- `tests/run_all_tests.gd`: New single entry point or documented batch runner if the repo keeps individual scripts.
- `tests/fight_lifecycle_runner.gd`: New manager-level lifecycle coverage.
- `tests/events_runner.gd`: New event bus and decoupling coverage.
- `tests/all_fighters_animation_runner.gd`: New all-boxer version of `boxer02_animation_cleanliness_runner.gd`.
- `tests/move_data_runner.gd`: New parity and validation tests for data-driven attacks.
- `tests/presentation_feedback_runner.gd`: New event-driven presentation tests.

### Task 1: Fight Lifecycle Stabilization

**Files:**
- Modify: `scripts/managers/fight_manager.gd`
- Modify: `scripts/managers/round_manager.gd`
- Modify: `scripts/managers/judges.gd`
- Modify: `scripts/managers/fight_stats.gd`
- Create: `tests/fight_lifecycle_runner.gd`
- Modify: `tests/fight_system_runner.gd`

**Interfaces:**
- Consumes: Existing `FightManager.setup(player, enemy, hud, audio, referee)`, `RoundManager.tick(delta)`, `Judges.decide(player, enemy, cards := [])`, `FightStats.snapshot()`.
- Produces: Idempotent `FightManager._end_round()`, result dictionaries with `method`, `winner_name`, `round`, `time`, `scorecards`, `stats`, and stable state values `FIGHTING`, `KNOCKDOWN`, `ROUND_END`, `FIGHT_END`.

- [ ] **Step 1: Write fight lifecycle tests**

Add `tests/fight_lifecycle_runner.gd` with assertions for: a 1-round forced Quick Fight reaches `FightManager.State.FIGHT_END`; `_end_round()` called twice while already ending records only one score; first knockdown with enough stamina returns both fighters to `fight_enabled == true`; third knockdown ends by `TKO`; `Engine.time_scale == 1.0` after hit feedback and KO.

- [ ] **Step 2: Run the new runner and verify it fails where coverage is missing**

Run: `Godot.exe --headless --path . --script res://tests/fight_lifecycle_runner.gd`

Expected: FAIL before implementation on at least duplicate-end or missing test hook behavior.

- [ ] **Step 3: Make round endings and knockdown transitions idempotent**

In `scripts/managers/fight_manager.gd`, guard `_end_round()` and `_end_fight()` so they return immediately from `ROUND_END` and `FIGHT_END`; clear `_knockdown_in_progress` in every exit path; restore `Engine.time_scale` when the fight ends.

- [ ] **Step 4: Normalize decision method names**

In `scripts/managers/judges.gd`, return `Unanimous Decision`, `Split Decision`, `Majority Decision`, `Draw`, or `Majority Draw` from scorecard vote totals. Keep the existing `scorecards` array shape so `fight_system_runner.gd` keeps working.

- [ ] **Step 5: Run focused and affected tests**

Run: `Godot.exe --headless --path . --script res://tests/fight_lifecycle_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/fight_system_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/combat_runner.gd`

Expected: PASS for all three, with no new ObjectDB leak warnings.

- [ ] **Step 6: Commit**

```bash
git add scripts/managers/fight_manager.gd scripts/managers/round_manager.gd scripts/managers/judges.gd scripts/managers/fight_stats.gd tests/fight_lifecycle_runner.gd tests/fight_system_runner.gd
git commit -m "test: stabilize fight lifecycle"
```

### Task 2: Project Contracts and Event Bus

**Files:**
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/CODEX_RULES.md`
- Create: `autoload/events.gd`
- Modify: `project.godot`
- Modify: `scripts/managers/fight_manager.gd`
- Modify: `fighters/boxer_green/boxer_controller.gd`
- Create: `tests/events_runner.gd`

**Interfaces:**
- Consumes: Existing fighter signals `punch_thrown`, `punch_landed`, `defense_used`, `knockdown_started`.
- Produces: Autoload `Events` with signals `fight_started`, `round_started(round_number: int)`, `round_ended(round_number: int, cards: Array)`, `punch_landed(attacker: Node, defender: Node, result: Dictionary)`, `knockdown_started(fallen: Node, standing: Node)`, `fight_finished(result: Dictionary)`.

- [ ] **Step 1: Write event bus tests**

Add `tests/events_runner.gd` that instantiates `Events`, verifies all required signals exist, runs a short fight, and asserts round, hit, knockdown, and finish events can be observed without connecting directly to `BoxerController`.

- [ ] **Step 2: Run event bus tests to verify they fail**

Run: `Godot.exe --headless --path . --script res://tests/events_runner.gd`

Expected: FAIL because `Events` autoload and signal emissions do not exist yet.

- [ ] **Step 3: Add docs and the event bus**

Create `docs/ARCHITECTURE.md` with the current systems, folder ownership, signal flow, and test gates. Create `docs/CODEX_RULES.md` with the document's rules: read architecture docs first, small changes, do not rename public nodes/signals casually, run tests, report warnings. Create `autoload/events.gd` with the typed signals listed above and add it to `[autoload]` in `project.godot` as `Events`.

- [ ] **Step 4: Emit lifecycle and combat events**

In `FightManager`, emit `Events.fight_started`, `Events.round_started`, `Events.round_ended`, `Events.knockdown_started`, and `Events.fight_finished` alongside existing local signals. In `BoxerController` or the existing manager signal handlers, emit `Events.punch_landed` only once per real hit.

- [ ] **Step 5: Run event and lifecycle tests**

Run: `Godot.exe --headless --path . --script res://tests/events_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/fight_lifecycle_runner.gd`

Expected: PASS, and existing direct signals still work.

- [ ] **Step 6: Commit**

```bash
git add docs/ARCHITECTURE.md docs/CODEX_RULES.md autoload/events.gd project.godot scripts/managers/fight_manager.gd fighters/boxer_green/boxer_controller.gd tests/events_runner.gd
git commit -m "feat: add fight event bus"
```

### Task 3: Shared Fighter Controller and All-Fighter Animation Contract

**Files:**
- Create: `docs/ANIMATION_CATALOG.md`
- Move: `fighters/boxer_green/boxer_controller.gd` to `fighters/shared/boxer_controller.gd`
- Move: `fighters/boxer_green/boxer_controller.gd.uid` to `fighters/shared/boxer_controller.gd.uid`
- Modify: `fighters/boxer_green/boxer_green.tscn`
- Modify: `fighters/boxer_02/boxer_02.tscn`
- Modify: `fighters/boxer_03/boxer_03.tscn`
- Create: `tests/all_fighters_animation_runner.gd`
- Modify: `tests/boxer02_animation_cleanliness_runner.gd`

**Interfaces:**
- Consumes: Existing `BoxerController` class name, exported `animation_player_path`, exported `skeleton_path`, and `AnimationPlayer` libraries `Boxing` and `UnarmedSupport`.
- Produces: All three boxer scenes instantiate as `BoxerController`, share the same script path, expose the same required animation names, and start in `Footwork` without T-pose.

- [ ] **Step 1: Write all-fighter animation tests**

Add `tests/all_fighters_animation_runner.gd` that loops over `res://fighters/boxer_green/boxer_green.tscn`, `res://fighters/boxer_02/boxer_02.tscn`, and `res://fighters/boxer_03/boxer_03.tscn`; for each, assert the scene casts to `BoxerController`, resolves skeleton and animation player paths, has `Boxing/boxing_idle`, `step_forward`, `step_backward`, `step_left`, `step_right`, `jab`, `cross`, `left_hook`, `right_hook`, `uppercut`, `block_left`, `block_right`, `block_body`, `get_up`, and starts with active `AnimationTree`.

- [ ] **Step 2: Run all-fighter tests to verify the current gap**

Run: `Godot.exe --headless --path . --script res://tests/all_fighters_animation_runner.gd`

Expected: FAIL on any fighter that lacks shared script wiring, path resolution, or required libraries.

- [ ] **Step 3: Document the canonical animation set**

Create `docs/ANIMATION_CATALOG.md` with required names from the DOCX: base, locomotion, punches, defense, reactions, stun/wobble, knockdown/get-up, clinch placeholders, and presentation placeholders. Mark the current required MVP set separately from future placeholders.

- [ ] **Step 4: Move the controller to shared**

Move the controller script and uid to `fighters/shared/`, update scene script paths, and fix hard-coded resource paths that still assume `fighters/boxer_green/`. Keep exported paths per scene so each fighter can point to its own model node.

- [ ] **Step 5: Fix scene UID and startup animation issues**

Open the three `.tscn` files as text only for script/resource path fixes; remove invalid `uid://` references only when they point to missing resources; ensure `_ready()` activates `AnimationTree` and travels to `Footwork`.

- [ ] **Step 6: Run animation and integration tests**

Run: `Godot.exe --headless --path . --script res://tests/all_fighters_animation_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/fighter_animation_runtime_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/combat_runner.gd`

Expected: PASS, with no `couldn't resolve track` errors.

- [ ] **Step 7: Commit**

```bash
git add docs/ANIMATION_CATALOG.md fighters/shared fighters/boxer_green/boxer_green.tscn fighters/boxer_02/boxer_02.tscn fighters/boxer_03/boxer_03.tscn tests/all_fighters_animation_runner.gd tests/boxer02_animation_cleanliness_runner.gd
git commit -m "refactor: share boxer controller across fighters"
```

### Task 4: Data-Driven Move Library

**Files:**
- Create: `scripts/combat/move_data.gd`
- Create: `scripts/combat/move_library.gd`
- Create: `data/moves/jab.tres`
- Create: `data/moves/cross.tres`
- Create: `data/moves/left_hook.tres`
- Create: `data/moves/right_hook.tres`
- Create: `data/moves/uppercut.tres`
- Modify: `scripts/combat/combat_rules.gd`
- Modify: `fighters/shared/boxer_controller.gd`
- Create: `tests/move_data_runner.gd`

**Interfaces:**
- Consumes: Current attack keys `jab`, `cross`, `left_hook`, `right_hook`, `uppercut` and current `CombatRules.attack_data(attack_name: String) -> Dictionary`.
- Produces: `MoveData` resource with fields `id`, `animation_name`, `hand`, `attack_type`, `target_level`, `startup_frames`, `active_frames`, `recovery_frames`, `damage`, `stamina_cost`, `min_range`, `max_range`, `power`, `stun`, `counter_bonus`, `movement_allowed`, `tracking_strength`, `step_in`, `hitstop_frames`, `camera_feedback`, `animation_speed`, `cancel_window_frames`; `MoveLibrary.attack_data(id: StringName) -> Dictionary`.

- [ ] **Step 1: Write move data parity tests**

Add `tests/move_data_runner.gd` that validates all five current attack ids load, required numeric fields are positive, frame fields convert to seconds at 60 fps, and `CombatRules.attack_data("jab")` preserves current public keys `startup`, `active_time`, `recovery`, `range`, `hit_stop`, `camera_feedback`, `cancel_window`.

- [ ] **Step 2: Run move data tests to verify they fail**

Run: `Godot.exe --headless --path . --script res://tests/move_data_runner.gd`

Expected: FAIL because `MoveData` and `MoveLibrary` are absent.

- [ ] **Step 3: Add `MoveData` and `.tres` assets**

Create `MoveData` as a `Resource` class and five `.tres` files under `data/moves/` using the current constants from `CombatRules.ATTACKS`, converted to frames where the spec requires frame data. Use 60 fps as the conversion rule.

- [ ] **Step 4: Add `MoveLibrary` with validation**

Implement `MoveLibrary.attack_data(id: StringName) -> Dictionary`, `MoveLibrary.all_ids() -> Array[StringName]`, and `MoveLibrary.validate() -> Array[String]`. The returned dictionary must match current `CombatRules.attack_data()` keys so `BoxerController` does not change in this task.

- [ ] **Step 5: Route `CombatRules` through `MoveLibrary`**

Keep hit calculation in `CombatRules`, but replace the inline `ATTACKS` source with `MoveLibrary.attack_data()`. Leave old constants only as a temporary fallback if tests require a staged migration.

- [ ] **Step 6: Run combat parity tests**

Run: `Godot.exe --headless --path . --script res://tests/move_data_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/punch_system_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/combat_runner.gd`

Expected: PASS, and punch damage/range behavior remains equivalent.

- [ ] **Step 7: Commit**

```bash
git add scripts/combat/move_data.gd scripts/combat/move_library.gd data/moves scripts/combat/combat_rules.gd fighters/shared/boxer_controller.gd tests/move_data_runner.gd
git commit -m "feat: add data driven move library"
```

### Task 5: Hit Feedback and Broadcast Presentation Slice

**Files:**
- Create: `scripts/presentation/hit_feedback_system.gd`
- Modify: `scripts/fight/fight_scene.gd`
- Modify: `scripts/ui/fight_hud.gd`
- Modify: `scripts/audio/audio_manager.gd`
- Modify: `scripts/camera/boxing_camera.gd`
- Create: `tests/presentation_feedback_runner.gd`

**Interfaces:**
- Consumes: `Events.punch_landed`, `Events.round_started`, `Events.round_ended`, `Events.knockdown_started`, `Events.fight_finished`, `MoveLibrary.attack_data()`, existing `BoxingCamera.impact(strength)`, existing `BoxingAudio.play_cue(cue)`.
- Produces: `HitFeedbackSystem.setup(camera: BoxingCamera, audio: BoxingAudio, hud: FightHUD)`, hitstop by frames, camera feedback, audio cue routing, controller vibration, scoreboard clock/round state, and result overlay without direct private method calls.

- [ ] **Step 1: Write presentation tests**

Add `tests/presentation_feedback_runner.gd` that creates a fight scene, emits or causes one clean hit, one blocked hit, one round start, one round end, and one fight finish; assert the HUD clock/result update, audio receives appropriate cue names, camera impact is called for clean heavy hits, and `Engine.time_scale` returns to `1.0`.

- [ ] **Step 2: Run presentation tests to verify they fail**

Run: `Godot.exe --headless --path . --script res://tests/presentation_feedback_runner.gd`

Expected: FAIL because feedback is still embedded in `fight_scene.gd`.

- [ ] **Step 3: Extract hit feedback from `fight_scene.gd`**

Move hitstop, camera shake, HUD damage flash, SFX selection, and vibration into `scripts/presentation/hit_feedback_system.gd`. Instantiate it in `fight_scene.gd` after camera, HUD, and audio exist.

- [ ] **Step 4: Add broadcast HUD states**

In `scripts/ui/fight_hud.gd`, add a compact scoreboard mode with fighter names, round, timer, knockdown mode, between-round cards, and final stats summary. Keep debug text available behind the existing debug flags.

- [ ] **Step 5: Add audio cue routing**

In `scripts/audio/audio_manager.gd`, add stable cue ids for `bell`, `jab`, `cross`, `left_hook`, `right_hook`, `uppercut`, `block`, `crowd_hit`, `crowd_knockdown`, `ref_count`, and `announcer_result`; use placeholders or existing clips if assets are missing.

- [ ] **Step 6: Run presentation and fight tests**

Run: `Godot.exe --headless --path . --script res://tests/presentation_feedback_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/fight_system_runner.gd`

Run: `Godot.exe --headless --path . --script res://tests/live_flow_runner.gd`

Expected: PASS, and a clean hit, blocked hit, and miss are visually/audibly distinguishable in manual play.

- [ ] **Step 7: Commit**

```bash
git add scripts/presentation/hit_feedback_system.gd scripts/fight/fight_scene.gd scripts/ui/fight_hud.gd scripts/audio/audio_manager.gd scripts/camera/boxing_camera.gd tests/presentation_feedback_runner.gd
git commit -m "feat: add broadcast hit feedback slice"
```

### Task 6: Vertical Slice Gate and Career Freeze Line

**Files:**
- Create: `tests/run_all_tests.gd` or `scripts/run_all_tests.ps1`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CODEX_RULES.md`
- Modify: `career/character_creator/character_creator.gd`
- Modify: `scripts/menus/career_menu.gd`
- Modify: `scripts/data/career_data.gd`
- Create: `docs/VERTICAL_SLICE_GATE.md`

**Interfaces:**
- Consumes: All previous task tests and current career/creator/menu scripts.
- Produces: One documented command to run the suite, one visible vertical-slice checklist, and career screens that remain accessible but clearly treat career as blocked behind the Quick Fight gate.

- [ ] **Step 1: Write a run-all gate**

Create either a Godot runner or PowerShell script that runs: `asset_audit`, `fight_lifecycle_runner`, `events_runner`, `all_fighters_animation_runner`, `move_data_runner`, `presentation_feedback_runner`, `fight_system_runner`, `combat_runner`, `fighter_animation_runtime_runner`, `integration_runner`, `live_flow_runner`, `settings_menu_runner`, and `character_creator_runner`.

- [ ] **Step 2: Run the gate and record baseline failures**

Run the new gate command.

Expected: It reports every runner name and stops on the first failure, or prints a final failed list if implemented as a script.

- [ ] **Step 3: Add `VERTICAL_SLICE_GATE.md`**

Document the non-negotiable exit criteria: three-fighter animation pass, 3-round Quick Fight completion, KO/TKO/decision coverage, no ObjectDB leaks, hit feedback present, broadcast HUD present, audio cues present, result screen present, and no career work beyond MVP scaffolding until the gate passes.

- [ ] **Step 4: Keep career scoped**

Ensure career menu and character creator can still open, save/load basic data, and return to menus, but do not add ranking, contracts, economy, sponsors, aging, or narrative events in this task.

- [ ] **Step 5: Run full gate**

Run the new run-all command.

Expected: PASS for all listed runners, or a concise failed-runner list with logs.

- [ ] **Step 6: Commit**

```bash
git add tests/run_all_tests.gd scripts/run_all_tests.ps1 docs/ARCHITECTURE.md docs/CODEX_RULES.md docs/VERTICAL_SLICE_GATE.md career/character_creator/character_creator.gd scripts/menus/career_menu.gd scripts/data/career_data.gd
git commit -m "chore: define vertical slice gate"
```

## Self-Review

**Spec coverage:** The plan covers the DOCX's immediate priorities: technical hygiene, fight lifecycle, event decoupling, animation catalog, shared controller, data-driven moves, game feel, broadcast presentation, audio routing, testing, and the rule that career waits for the vertical slice. Deep career, creator blend shapes, online, localization, licensing, and broad content production are intentionally deferred beyond this plan.

**Step scan:** Each task starts with a failing runner, defines the target files and interfaces, implements one coherent behavior group, then runs focused verification before commit.

**Type consistency:** The plan preserves existing public classes `FightManager`, `RoundManager`, `Judges`, `FightStats`, `BoxerController`, and `CombatRules`; new names are `Events`, `MoveData`, `MoveLibrary`, and `HitFeedbackSystem`.

**Review Focus:** The five review-focus risks are pinned to tests in Tasks 1 through 5.

**Proportion:** This plan is narrower than the full 45-65 week roadmap: it is the implementation plan for the vertical-slice foundation, not the whole game.
