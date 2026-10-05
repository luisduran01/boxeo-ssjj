# Boxing Animation Catalog

## MVP Required Per Fighter

Every selectable boxer scene must expose these clips in the `Boxing` animation library:

- `boxing_idle`
- `step_forward`
- `step_backward`
- `step_left`
- `step_right`
- `jab`
- `cross`
- `left_hook`
- `right_hook`
- `uppercut`
- `block_left`
- `block_right`
- `block_body`
- `get_up`

Every selectable boxer scene must also expose the shared `UnarmedSupport` library. The current shared support source is `fighters/boxer_02/animations/unarmed_support/`.

Required `UnarmedSupport` clips:

- `block`
- `block_get_hit_1`
- `block_get_hit_2`
- `dodge_backward`
- `dodge_left`
- `dodge_right`
- `get_hit_back`
- `get_hit_front`
- `get_hit_left`
- `get_hit_right`
- `get_up`
- `idle_injured`
- `knockdown`
- `stunned`

## Future Canonical Names

Base and fatigue:
- `idle_guard`
- `idle_tired`
- `idle_hurt`
- `breathe_add`

Locomotion:
- `move_forward`
- `move_backward`
- `strafe_left`
- `strafe_right`
- `diagonal_forward_left`
- `diagonal_forward_right`
- `diagonal_backward_left`
- `diagonal_backward_right`
- `pivot_left`
- `pivot_right`
- `step_in`
- `step_out`

Punches to head:
- `jab`
- `jab_long`
- `cross`
- `hook_left`
- `hook_right`
- `uppercut_left`
- `uppercut_right`
- `overhand`

Punches to body:
- `jab_body`
- `cross_body`
- `hook_body_left`
- `hook_body_right`
- `uppercut_body`

Defense:
- `block_head`
- `block_body`
- `slip_left`
- `slip_right`
- `duck`
- `lean_back`
- `pivot_escape`
- `parry`

Reactions:
- `hit_head_left_light`
- `hit_head_center_light`
- `hit_head_right_light`
- `hit_head_left_heavy`
- `hit_head_center_heavy`
- `hit_head_right_heavy`
- `hit_body_left_light`
- `hit_body_center_light`
- `hit_body_right_light`
- `hit_body_left_heavy`
- `hit_body_center_heavy`
- `hit_body_right_heavy`
- `counter_hit`
- `guard_hit`
- `guard_break`

States:
- `stun`
- `wobble_in`
- `wobble_loop`
- `wobble_out`

Knockdown and get-up:
- `knockdown_front`
- `knockdown_back`
- `knockdown_side`
- `down_loop`
- `getup_slow`
- `getup_normal`
- `getup_fast`

Clinch:
- `clinch_enter`
- `clinch_hold`
- `clinch_push`
- `clinch_break`
- `clinch_hit`

Presentation:
- `entrance_walk`
- `ring_salute`
- `taunt`
- `corner_sit`
- `victory_a`
- `victory_b`
- `defeat`

## Rules

Do not rename an existing public animation without updating all three fighter scenes and every runner that references it.

Root motion stays disabled for shared locomotion and support clips. Character translation belongs to `BoxerController`.

The `AnimationTree` must be active after `_ready()` and start in `Footwork`.
