# Professional Boxing Footwork Design

## Objective

Build a professional, opponent-relative boxing locomotion foundation for
`boxer_green` and `boxer_02`. Both fighters must remain in boxing stance,
face one another smoothly, move with distinct forward/backward/lateral
character, control range, pivot, and avoid overlap while preserving all
existing combat, collision, hitbox, hurtbox, HUD, menu, model, material,
camera, and ring behavior.

The player remains the only fighter that reads user input. The rival uses the
same locomotion pipeline but supplies an AI movement intention that is held for
a short decision interval.

## Existing Project Constraints

- Godot target: 4.7.2, Forward Plus, Jolt Physics.
- Both fighter scenes already use `BoxerController`, `CharacterBody3D`, an
  active `AnimationTree`, `AnimationPlayer2`, a capsule body collider,
  hitboxes, and hurtboxes.
- The current animation flow is `Start -> Boxing_fight_enter -> Footwork`.
- Existing attacks, blocks, hit reactions, knockdowns, stamina behavior, and
  punch movement must continue working.
- `boxer_green` is player-controlled and `boxer_02` is AI-controlled.
- Fighter models and their visual child transforms are not replaced. Their
  current 180-degree visual correction remains on the model child rather than
  reversing `CharacterBody3D` movement.
- `Zombie Punching` is never used.
- Existing uncommitted FBX imports and `.res` resources are user-owned and
  must be preserved.

## Asset Inventory and Fallback Policy

The implementation resolves assets by their real project paths and validates
the corresponding `AnimationPlayer` library names. The verified forward
library contains Short, Medium, and Long Step Forward clips, and the attack
library contains Cross Punch for both fighters.

At design time, the filesystem contains only Short Left Side Step and Long
Right Side Step among the named lateral clips. If no additional lateral files
exist at implementation time, the available left/right clips will populate
all lateral intensity samples with conservative playback-speed adjustment.
No clip will be fabricated, renamed deceptively, or replaced with an unrelated
animation. The final report will list every fallback.

Animation resources remain authored/imported resources; they are not rebuilt
every frame or loaded repeatedly during gameplay.

## Architecture

### Shared locomotion pipeline

`BoxerController` remains the integration point for combat and the two fighter
scenes. Pure calculations that benefit from deterministic tests are extracted
to a focused boxing movement model/script. The shared pipeline accepts a
normalized `Vector2` movement intention and does not know whether it came from
the player or AI.

Each physics tick follows this order:

1. Update timers, action state, and range state.
2. Smoothly face the opponent around world Y.
3. Obtain player or AI movement intention.
4. Apply deadzone and determine Short/Medium/Long movement tier.
5. Convert intention to opponent-relative planar movement.
6. Apply directional speed, acceleration/deceleration, close-range blocking,
   separation, and existing collision response.
7. Move with `move_and_slide()`.
8. Update the AnimationTree blend, playback speed, pivot state, and optional
   debug snapshot.

No per-frame node searches, resource loading, or AnimationTree construction is
permitted.

### Target lock and model orientation

The planar direction from fighter to opponent defines combat forward. The
fighter body interpolates toward that yaw using `lerp_angle` with a configurable
turn responsiveness. Pitch and roll are not introduced.

The authoritative body uses Godot's conventional forward basis. Any imported
mesh-facing correction is confined to the existing visual/model child. A
headless facing assertion verifies that both bodies face each other after
settling, and a runtime/debug dot product exposes orientation mistakes without
silently reversing locomotion.

### Opponent-relative movement

For a fighter and its opponent:

- `forward` is the normalized horizontal direction toward the opponent.
- `backward` is `-forward`.
- `right` is the horizontal perpendicular derived from `Vector3.UP` and
  `forward` using the project's established handedness.
- `left` is `-right`.

Input Y moves toward/away from the rival while input X circles. Diagonals are
limited to unit length. Backward motion never rotates the body away from the
opponent.

Directional speeds are independently exported. Forward is slightly faster
than backward; lateral motion is controlled. Velocity approaches its target
using exported acceleration and deceleration instead of snapping. Existing
stamina scaling remains part of the final target speed.

### Stick intensity and deliberate Long Step

The input deadzone and tier thresholds are exported. Initial defaults are:

- below `0.25`: idle;
- `0.25` through `0.64`: Short;
- `0.65` through `0.89`: Medium;
- `0.90` through `1.00`: Long-eligible.

Crossing into the Long band can trigger one deliberate Long Step when the
fighter is allowed to move forward and the cooldown has expired. Holding the
stick does not retrigger Long Step. After the initial pulse, a held full input
settles to Medium until it is released below the re-arm threshold. Keyboard
input follows the same edge/re-arm rule, avoiding continuous Long Step loops.

The physical speed remains authoritative. Animation playback speed is adjusted
within a conservative exported range to match travel without visibly deforming
the motion.

### AnimationTree

The existing state machine and `FightEnter -> Footwork` flow are retained.
`Footwork` becomes an intensity-aware 2D blend layout:

- center: Boxing Idle;
- forward ray: Short, Medium, Long Step Forward;
- backward ray: Step Backward samples;
- left ray: Left Side Step samples;
- right ray: Right Side Step samples;
- interpolated regions: natural diagonals.

Blend positions are smoothed exponentially. The tree is never restarted every
frame. Idle is reached by returning the blend to zero.

Pivot Left and Pivot Right are added as explicit state-machine actions with
soft entry/exit transitions back to Footwork. Existing attacks, blocks, and
reactions continue through their proven `AnimationPlayer` path for this phase,
because replacing the combat playback layer would risk hit timing and pose
regressions. Their current locomotion allowance remains active, and the
controller exposes a clean movement-intention/blend interface for a later
upper-body OneShot layer. Cross is registered in the existing animation
library and attack mapping without changing unrelated controls.

### Root motion and foot sliding

`CharacterBody3D` remains authoritative for locomotion. Global root motion is
not enabled. Imported root translation is inspected; locomotion clips are
treated as in-place for gameplay so animation translation cannot double the
scripted displacement.

Foot sliding is reduced by matching each movement tier to an exported physical
speed band, smoothing acceleration and blend transitions, and applying a
bounded AnimationTree playback multiplier. Tuning values remain per-controller
exports so the two differently scaled scenes can be calibrated without
changing model assets.

## Range Model

A central enum/string representation exposes these ordered horizontal ranges:

- `OUTSIDE`
- `LONG_RANGE`
- `MID_RANGE`
- `POCKET`
- `TOO_CLOSE`

Four strictly increasing exported thresholds define the boundaries. The
calculation uses XZ distance only, never vertical separation. Range is updated
once per physics tick and is available to AI, movement limiting, attacks, and
debugging. Threshold validation prevents an invalid inspector configuration
from producing contradictory states.

## Anti-overlap and Ring Collision

Body collision remains enabled and existing capsule configuration is retained.
The movement layer adds controlled boxing separation:

- at `minimum_fighter_distance`, inward velocity is progressively damped;
- backward and tangential velocity remain available;
- below `hard_separation_distance`, a small capped outward correction is
  added using `soft_separation_strength`;
- zero-distance fallback uses a stable cached direction, avoiding random or
  alternating pushes;
- hysteresis and capped correction prevent jitter and launches.

The separation calculation modifies velocity only; it never teleports either
fighter. Ring posts, floor, and boundaries continue to be handled by
`move_and_slide()` and existing collision masks. Existing coordinate clamps
may remain only as a last-resort safety boundary if their values agree with the
built ring; they must not bypass physics contacts.

## Pivots

A pivot is an action, not ordinary side walking. It can start when lateral
intent is strong, the rival is within the configured pivot range, the angle
condition is met, and pivot/reaction/attack cooldowns permit it. AI may request
the same action through its movement intention/controller API.

During the brief action, the fighter follows a capped tangential velocity
around the opponent, keeps target lock, respects collision and separation, and
plays the corresponding pivot state. Completion returns smoothly to Footwork.
No position snapping or root-motion displacement is used.

## AI Footwork

The rival never reads `Input`. At variable decision intervals it chooses and
holds one intention based on range, ring position, recent lateral direction,
and pivot cooldown:

- approach from OUTSIDE/LONG_RANGE;
- make small forward/backward corrections around ideal MID_RANGE;
- retreat from TOO_CLOSE;
- circle in either direction with a bias against immediate reversal;
- occasionally pivot when close enough and tactically valid;
- add small quiet intervals without remaining permanently static.

Randomness occurs only at decision boundaries. Range hysteresis and a minimum
decision duration stop rapid forward/backward oscillation.

Existing combat AI decisions stay functional. The footwork change isolates
movement choice so later combat AI can request the same locomotion API.

## Player Input and Combat Compatibility

The existing keyboard and left-stick actions remain. A radial deadzone is
applied after `Input.get_vector`, preserving analog magnitude. No second input
path is added to the AI.

Existing punch and guard mappings remain intact. Cross Punch is connected to
the currently reserved right straight input path and added to combat data only
after tests pin the previous jab/hook/uppercut behavior. Hitbox activation,
hurtbox attachment, attack timing, reaction playback, and damage calculations
are not redesigned in this phase.

## Debugging

An exported `debug_boxing_movement := false` controls a cached debug snapshot
containing:

- horizontal distance and range state;
- raw/filtered input vector and movement intensity;
- active movement tier and locomotion/pivot state;
- target identity;
- current horizontal speed and target speed;
- facing alignment and separation correction.

When disabled it produces no periodic Output logging. The existing HUD debug
path may display the snapshot only if debug is enabled; the normal HUD layout
and menus are not changed.

## Error Handling and Safe Degradation

- A missing opponent produces idle movement and no target rotation.
- Missing optional animation tiers fall back to the nearest verified clip and
  are reported once during validation, not every frame.
- Missing required Footwork, idle, collider, hitbox, or hurtbox resources is a
  test failure rather than a silent runtime reconstruction.
- Animation playback changes check state validity and never travel to a state
  every frame.
- User-owned imported resources are reused and never deleted or regenerated
  destructively.

## Verification Strategy

Implementation follows test-first development using a dedicated headless
footwork runner plus the existing combat/integration runners.

Automated checks cover:

1. Horizontal range classification at every boundary.
2. Opponent-relative forward, backward, lateral, and diagonal direction.
3. Analog deadzone and Short/Medium/Long tier selection.
4. Long Step edge triggering, held-input suppression, cooldown, and re-arm.
5. Acceleration/deceleration and directional speed differences.
6. Stable target-lock yaw and face-to-face orientation.
7. Player input affects only `boxer_green`.
8. AI decisions are held between decision boundaries.
9. AI approaches, retreats, circles, and can request pivots.
10. Inward movement is blocked while backward/tangential movement remains.
11. Penetration correction is capped and stable at zero distance.
12. Pivot movement is tangential, collision-aware, and returns to Footwork.
13. AnimationTree is active and exposes valid FightEnter, Footwork, and pivot
    states with all available tier resources.
14. Both fighters retain body colliders, hitboxes, and hurtboxes.
15. Existing punches, blocks, reactions, knockdowns, and round-flow tests pass.
16. Cross uses its real animation and the reserved right-straight input.
17. The project starts headlessly with no parser or broken-resource errors.

Final validation runs the complete existing suite, the new footwork runner,
an editor/headless project parse, and a short live-scene simulation. Any
visual-only limitation such as residual foot sliding is reported honestly if
it cannot be proven headlessly.

## Files Expected to Change

Exact paths are finalized in the implementation plan after resource
validation, but the intended scope is:

- `fighters/boxer_green/boxer_controller.gd`
- `fighters/boxer_green/boxer_green.tscn`
- `fighters/boxer_02/boxer_02.tscn`
- existing verified animation `.res` and import mappings only where necessary
- `scripts/combat/combat_rules.gd` only for the Cross attack mapping
- `scripts/fight/fight_scene.gd` only for debug integration if required
- a focused movement calculation script under `scripts/combat/`
- a new headless footwork test runner under `tests/`
- existing integration tests where their assertions must cover Cross or the
  expanded AnimationTree

HUD, menus, camera behavior, models, materials, lighting, referee, audience,
health/stamina bars, and round timer remain out of scope.
