# Professional Boxing Footwork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver opponent-relative, intensity-aware boxing footwork for `boxer_green` and `boxer_02`, including target lock, range control, pivots, stable anti-overlap, and AI movement without regressing the existing combat system.

**Architecture:** Keep `BoxerController` as the shared runtime integration point and extract deterministic movement math into `BoxingFootworkModel`. Enhance the two existing AnimationTrees in place, retain `CharacterBody3D` authority over position, and feed the same movement-intention interface from either player input or interval-based AI decisions.

**Tech Stack:** Godot 4.7.2, GDScript, CharacterBody3D/Jolt Physics, AnimationTree/AnimationPlayer, headless SceneTree test runners.

**Spec:** `docs/superpowers/specs/2026-10-01-professional-boxing-footwork-design.md`

## Global Constraints

- Preserve both existing fighter models, visual transforms, hitboxes, hurtboxes, body colliders, attacks, defenses, reactions, knockdowns, stamina, HUD, menus, camera, referee, ring, materials, and lighting.
- Never use `Zombie Punching`.
- `boxer_green` is the only controller that reads player input; `boxer_02` receives movement intentions exclusively from AI.
- Keep `CharacterBody3D` authoritative; do not enable global root motion.
- Extend the existing `Start -> Boxing_fight_enter -> Footwork` AnimationTree flow rather than rebuilding it at runtime.
- Resolve and reuse real FBX/`.res` assets. Never invent missing paths or replace a missing clip with an unrelated animation without reporting the fallback.
- Preserve all pre-existing uncommitted user assets/import changes. Before every commit, stage only the task's named files and inspect `git diff --cached --name-status`.
- Keep debug output silent unless `debug_boxing_movement` is true.

## Review Focus

- Two fighters starting at the same XZ position must separate in a stable direction with a capped correction and no alternating jitter; Task 1 pins the pure calculation and Task 5 pins scene behavior.
- Full analog or keyboard input held above the Long threshold must trigger Long once, settle to Medium, and re-arm only after release; Task 1 tests the latch and Task 2 tests controller state.
- Missing lateral intensity clips must select the nearest real same-direction clip without breaking AnimationTree resource loading; Task 3 audits every animation reference.
- Player and AI scaling differences must not reverse facing or produce different world-space movement semantics; Tasks 2 and 5 test both scenes.
- Attacking, blocking, receiving a hit, or recovering from knockdown must return to Footwork without losing target lock, hitboxes, or hurtboxes; Tasks 4 and 5 run existing and new regressions.

---

### Task 1: Deterministic Footwork Model

**Files:**
- Create: `scripts/combat/boxing_footwork_model.gd`
- Create: `tests/boxing_footwork_model_runner.gd`

**Interfaces:**
- Produces: `BoxingFootworkModel.RangeState { OUTSIDE, LONG_RANGE, MID_RANGE, POCKET, TOO_CLOSE }`.
- Produces: `classify_range(distance: float, long_threshold: float, mid_threshold: float, pocket_threshold: float, too_close_threshold: float) -> RangeState`.
- Produces: `apply_radial_deadzone(raw_input: Vector2, deadzone: float) -> Vector2`.
- Produces: `movement_tier(intensity: float, short_threshold: float, medium_threshold: float, long_threshold: float) -> int` with constants `TIER_IDLE`, `TIER_SHORT`, `TIER_MEDIUM`, `TIER_LONG`.
- Produces: `combat_basis(fighter_position: Vector3, opponent_position: Vector3, fallback_forward: Vector3) -> Dictionary` with normalized `forward` and `right` XZ vectors.
- Produces: `relative_velocity(input_vector: Vector2, forward: Vector3, right: Vector3, forward_speed: float, backward_speed: float, lateral_speed: float) -> Vector3`.
- Produces: `separation_velocity(base_velocity: Vector3, offset_from_opponent: Vector3, stable_fallback: Vector3, minimum_distance: float, hard_distance: float, strength: float, max_correction: float) -> Dictionary` containing `velocity` and `correction`.
- Produces: `update_long_step_latch(intensity: float, armed: bool, cooldown: float, long_threshold: float, rearm_threshold: float) -> Dictionary` containing `triggered` and `armed`.

- [ ] **Step 1: Read the testing rules before writing tests**

Read `C:/Users/Luis Duran/.codex/plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/test-driven-development/writing-good-tests.md` completely.

- [ ] **Step 2: Write failing pure-model tests**

In `tests/boxing_footwork_model_runner.gd`, assert exact boundary behavior for all five ranges, radial deadzone preservation, all four tiers, normalized combat basis, forward/back/lateral/diagonal speed semantics, stable zero-distance separation, inward-only damping, capped hard correction, and Long Step trigger/hold/re-arm behavior.

- [ ] **Step 3: Run the model test and verify RED**

Run:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/boxing_footwork_model_runner.gd
```

Expected: failure because `res://scripts/combat/boxing_footwork_model.gd` does not exist.

- [ ] **Step 4: Implement `BoxingFootworkModel`**

Use static, allocation-light calculations. Validate misordered thresholds by normalizing them locally or returning a deterministic result; never mutate inspector values from the model. Separation must preserve outward/tangential velocity and damp only the inward component.

- [ ] **Step 5: Run the model test and verify GREEN**

Run the Task 1 command. Expected: `BOXING FOOTWORK MODEL TESTS PASSED` and exit code 0.

- [ ] **Step 6: Commit Task 1**

Stage only the two Task 1 files, inspect the cached file list, and commit with `feat: add deterministic boxing footwork model`.

---

### Task 2: Shared Controller, Target Lock, Intensity, and AI Intent

**Files:**
- Modify: `fighters/boxer_green/boxer_controller.gd`
- Create: `tests/boxing_footwork_controller_runner.gd`

**Interfaces:**
- Consumes: all `BoxingFootworkModel` interfaces from Task 1.
- Produces exported tuning: `debug_boxing_movement`, `input_deadzone`, `short_step_threshold`, `medium_step_threshold`, `long_step_threshold`, `long_step_rearm_threshold`, `long_step_duration`, `long_step_cooldown`, `forward_speed`, `backward_speed`, `lateral_speed`, `acceleration`, `deceleration`, `turn_responsiveness`, `minimum_fighter_distance`, `hard_separation_distance`, `soft_separation_strength`, `maximum_separation_speed`, and four range thresholds.
- Produces runtime state: `range_state`, `movement_intensity`, `locomotion_state`, `_movement_intent`, `_long_step_armed`, `_long_step_time`, `_long_step_cooldown`, `_pivot_request`, and stable separation direction.
- Produces: `set_movement_intent(intent: Vector2) -> void` for non-player controllers/tests.
- Produces: `request_pivot(direction: float) -> bool` for player/AI pivot requests.
- Produces: `get_boxing_movement_debug() -> Dictionary` returning the spec's debug fields without printing.

- [ ] **Step 1: Write failing controller tests**

Create `tests/boxing_footwork_controller_runner.gd`. Instantiate both fighter scenes with paired opponents and assert: only the player reads injected `move_*` actions; AI movement comes from `set_movement_intent`/decision state; both bodies converge face-to-face via progressive Y rotation; forward closes distance; backward opens distance without turning away; lateral and diagonal intentions use the combat basis; acceleration/deceleration are non-instantaneous; range state updates from XZ distance; debug data is populated only when enabled; a held full input does not retrigger Long Step.

- [ ] **Step 2: Run the controller test and verify RED**

Run:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/boxing_footwork_controller_runner.gd
```

Expected: failure on missing exported/runtime footwork interfaces.

- [ ] **Step 3: Refactor movement calculations through the model**

Replace `_combat_range`, direct input-to-velocity math, and `_body_separation_velocity` internals with Task 1 calls while preserving public combat methods and current attack movement. Cache visual/model, AnimationTree, AnimationPlayer, skeleton, hitbox, hurtbox, and collider references in `_ready`; do not add per-frame `get_node` calls.

- [ ] **Step 4: Implement player intensity and velocity smoothing**

Apply the radial deadzone, direction-specific speed, acceleration/deceleration, Long Step latch/cooldown, stamina scaling, and bounded animation speed synchronization. Continue using `move_and_slide()` and ring collision masks. Remove direct position correction except for an explicitly justified emergency ring bound that cannot bypass collision.

- [ ] **Step 5: Implement stable target lock and range updates**

Use planar direction and `lerp_angle`; rotate only Y during normal combat. Preserve the existing visual child front-axis correction. Cache the last valid combat forward for coincident positions.

- [ ] **Step 6: Isolate AI footwork decisions**

Keep combat choices intact but separate footwork intent selection from input reading. Use variable decision intervals, ideal MID_RANGE correction, TOO_CLOSE retreat, lateral direction memory, ring escape, occasional pivot request, and no per-frame random choice. AI must hold its decision until the timer expires.

- [ ] **Step 7: Run controller and existing focused tests**

Run the Task 2 command, then:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/test_runner.gd
```

Expected: both pass with no parser errors or unexpected warnings.

- [ ] **Step 8: Commit Task 2**

Stage only `boxer_controller.gd` and the new runner, inspect the cached diff, and commit with `feat: add shared professional boxing locomotion`.

---

### Task 3: Intensity-Aware AnimationTrees and Pivot States

**Files:**
- Modify: `fighters/boxer_green/boxer_green.tscn`
- Modify: `fighters/boxer_02/boxer_02.tscn`
- Reuse/modify only if validation requires it: `fighters/boxer_green/animations/step_short.res`
- Reuse/modify only if validation requires it: `fighters/boxer_green/animations/medium_step.res`
- Reuse/modify only if validation requires it: `fighters/boxer_green/animations/step_forward.res`
- Reuse/modify only if validation requires it: `fighters/boxer_02/animations/step_short.res`
- Reuse/modify only if validation requires it: `fighters/boxer_02/animations/medium_step.res`
- Reuse/modify only if validation requires it: `fighters/boxer_02/animations/step_forward.res`
- Modify: `tests/boxing_footwork_controller_runner.gd`

**Interfaces:**
- Consumes: controller blend vector, locomotion tier, and pivot requests from Task 2.
- Produces AnimationTree states `Boxing_fight_enter`, `Footwork`, `PivotLeft`, and `PivotRight` for both scenes.
- Produces `parameters/Footwork/blend_position` with center idle, radial directional samples, and forward Short/Medium/Long samples.
- Produces valid `Boxing/step_short`, `Boxing/medium_step`, `Boxing/step_forward`, `Boxing/pivot_left`, and `Boxing/pivot_right` animation-library entries.

- [ ] **Step 1: Extend the test to require animation resources and state-machine nodes**

Assert for both fighters that AnimationTree is active, `FightEnter -> Footwork` remains reachable, forward tier blend samples resolve to real animations, pivot states exist, idle occupies the center, directional samples preserve sign, all animation-library references load, and no referenced animation is named `Zombie Punching`.

- [ ] **Step 2: Run the controller test and verify RED**

Run the Task 2 controller command. Expected: failure because the trees do not yet expose intensity tiers and pivot states.

- [ ] **Step 3: Audit root tracks and real animation names**

Use a temporary read-only test helper or Godot resource inspection to enumerate each selected animation's track paths and confirm loop mode. Record which lateral intensity variants truly exist. Do not activate root motion; ensure the model/root translation cannot double physical movement.

- [ ] **Step 4: Extend both existing AnimationTrees in place**

Add the real forward tier resources and explicit pivot nodes/transitions. Populate missing lateral intensity positions only with the nearest same-direction real clip, never a forward or opposite-side substitute. Preserve the existing fight-enter transition and smooth blend behavior.

- [ ] **Step 5: Connect controller playback without per-frame travel resets**

Update `boxer_controller.gd` only as needed so blend position and bounded playback speed reflect physical velocity, Long Step is a one-shot tier pulse, and pivot completion returns once to Footwork. Target lock and collision remain active during pivots.

- [ ] **Step 6: Run animation/controller tests and import validation**

Run:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --editor --quit
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/boxing_footwork_controller_runner.gd
```

Expected: clean import/parse, valid resources, and passing controller assertions.

- [ ] **Step 7: Commit Task 3**

Stage only the two scenes, any actually required animation resources, the controller delta, and the runner delta. Inspect the cached diff carefully so unrelated imported-resource changes are not swept in. Commit with `feat: expand fighter footwork animation trees`.

---

### Task 4: Cross Punch and Combat Regression Safety

**Files:**
- Modify: `scripts/combat/combat_rules.gd`
- Modify: `fighters/boxer_green/boxer_controller.gd`
- Modify: `fighters/boxer_green/boxer_green.tscn`
- Modify: `fighters/boxer_02/boxer_02.tscn`
- Reuse: `fighters/boxer_green/animations/cross.res`
- Reuse: `fighters/boxer_02/animations/cross.res`
- Modify: `tests/punch_system_runner.gd`
- Modify: `tests/combat_runner.gd`

**Interfaces:**
- Produces: `CombatRules.ATTACKS["cross"]` using animation name `cross`, right hand, straight type, and balanced startup/range/recovery values pinned by tests.
- Produces: keyboard action `cross` only if a compatible existing mapping is present or can be added without changing current keys; gamepad `punch_right` without hook/uppercut modifier requests Cross.
- Preserves: all existing attack names and behavior for jab, left hook, right hook, and uppercut.

- [ ] **Step 1: Write failing Cross and combat-regression tests**

Require non-empty Cross data, greater damage/stamina/recovery than jab but less than right hook where appropriate, real `Boxing/cross` animation in both players, right-straight gamepad routing, locomotion during allowed startup/recovery, one-hit-per-attack-instance, and return to active Footwork after Cross.

- [ ] **Step 2: Run punch and combat tests and verify RED**

Run:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/punch_system_runner.gd
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/combat_runner.gd
```

Expected: Cross-specific assertions fail while existing punch assertions remain diagnostic.

- [ ] **Step 3: Register Cross data and animations**

Add Cross to the central catalog and both AnimationPlayer libraries using the verified `.res` paths. Wire the reserved right-straight input branch to `request_attack("cross")`. Do not change hitbox/hurtbox creation or attack-phase semantics.

- [ ] **Step 4: Run punch, combat, and controller tests**

Run both Task 4 commands and the Task 2 controller command. Expected: all pass, including existing attacks and movement during attacks.

- [ ] **Step 5: Commit Task 4**

Stage only the named code, scenes, tests, and required Cross resources/import metadata. Inspect the cached diff and commit with `feat: connect cross punch without locomotion regression`.

---

### Task 5: Scene-Level Separation, Pivot, AI, and Debug Validation

**Files:**
- Create: `tests/boxing_footwork_integration_runner.gd`
- Modify: `fighters/boxer_green/boxer_controller.gd`
- Modify: `scripts/fight/fight_scene.gd` only if debug display cannot be provided without it
- Modify: `tests/combat_runner.gd` only for durable regression assertions shared with the existing suite

**Interfaces:**
- Consumes: movement model, controller tuning, AnimationTree states, and combat catalog from Tasks 1-4.
- Produces: end-to-end verification of the live `res://fight/fight.tscn` scene.
- Produces: silent-by-default movement debug snapshot; existing HUD debug text may include it only when explicitly enabled.

- [ ] **Step 1: Write failing live-scene footwork tests**

Load the fight scene and assert: FightEnter reaches Footwork; both fighters face each other; player forward/back/left/right/diagonal commands have correct relative effect; idle settles after release; AI is unaffected by injected player actions; AI approaches OUTSIDE, retreats TOO_CLOSE, holds decisions, circles without immediate repeated reversal, and can pivot; bodies do not overlap after sustained inward movement; separation has no alternating-frame jitter; ring collisions/capsules remain enabled; pivots move tangentially without teleporting; attacks, blocks, hits, and recovery return to Footwork; every hitbox/hurtbox still has a CollisionShape3D.

- [ ] **Step 2: Run the integration test and verify RED**

Run:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script tests/boxing_footwork_integration_runner.gd
```

Expected: at least the new pivot/separation/AI stability assertions fail until final integration tuning is applied.

- [ ] **Step 3: Apply minimal integration fixes and tuning**

Tune only exported defaults and focused controller behavior needed by the failing assertions. Do not alter HUD layout, cameras, models, ring geometry, or combat timing to make movement tests pass.

- [ ] **Step 4: Integrate silent debug data**

Return distance, range, input, intensity, tier/state, target, speed, target speed, facing alignment, and separation correction. Reuse the existing debug text route only when `debug_boxing_movement` is enabled; otherwise leave it empty and produce no prints.

- [ ] **Step 5: Run the integration test and verify GREEN**

Run the Task 5 command. Expected: `BOXING FOOTWORK INTEGRATION TESTS PASSED` and exit code 0.

- [ ] **Step 6: Commit Task 5**

Stage only the Task 5 files and focused deltas, inspect the cached diff, and commit with `test: validate live boxing footwork integration`.

---

### Task 6: Full Verification and Visual Calibration

**Files:**
- Modify only if a verified failure requires it: files already listed in Tasks 1-5
- Update/create evidence logs only outside Git unless the repository already tracks that exact log

**Interfaces:**
- Consumes: complete implementation.
- Produces: clean parser/import result, passing full test suite, live-scene visual evidence, and a final inventory of used/fallback animations.

- [ ] **Step 1: Read verification skill**

Read `C:/Users/Luis Duran/.codex/plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/verification-before-completion/SKILL.md` completely and follow it before making completion claims.

- [ ] **Step 2: Run project parse/import validation**

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --editor --quit
```

Expected: exit code 0 with no parser or broken-resource errors.

- [ ] **Step 3: Run every focused and existing runner**

Run, one at a time, `boxing_footwork_model_runner.gd`, `boxing_footwork_controller_runner.gd`, `boxing_footwork_integration_runner.gd`, `test_runner.gd`, `punch_system_runner.gd`, `combat_runner.gd`, `integration_runner.gd`, `gameplay_upgrade_runner.gd`, `live_flow_runner.gd`, and `professional_polish_runner.gd` with the same Godot headless command pattern.

Expected: every runner exits 0 and prints its PASS marker. Report any pre-existing or new failure by runner name; do not omit it.

- [ ] **Step 4: Capture and inspect the fight visually**

Run `tests/fight_visual_capture.gd`, inspect `tests/fight_capture.png`, and, if needed, launch the editor/game using the approved Godot executable. Verify no T-pose, reversed facing, gross foot sliding, animation snapping, frozen FightEnter, model intersection, or broken ring placement. Visual tuning may change only the exported movement/blend defaults already in scope.

- [ ] **Step 5: Re-run affected tests after any visual tuning**

Repeat the project parse, three new footwork runners, and any existing runner affected by the tuning. Expected: all pass again with fresh output.

- [ ] **Step 6: Review the final diff and asset inventory**

Confirm no HUD/menu/camera/model/material/lighting/referee files changed unexpectedly, no `Zombie Punching` reference exists, both colliders and all hitboxes/hurtboxes remain, and all AnimationTree resource paths resolve. Record exact Short/Medium/Long, lateral fallback, pivot, and Cross animation paths for the final report.

- [ ] **Step 7: Commit final tuning if necessary**

If Step 4 required changes, stage only those verified files, inspect the cached diff, and commit with `fix: calibrate boxing footwork presentation`. If no files changed, do not create an empty commit.
