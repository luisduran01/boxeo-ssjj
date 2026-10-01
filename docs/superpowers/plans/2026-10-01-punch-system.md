# Punch System reconstruction

**Spec:** `C:/Users/Luis Duran/.codex/attachments/9bab6fc0-6345-4535-8f58-2a02f304dd45/Texto pegado.txt`

## Constraints

- Preserve the existing rigs, animation resources, Footwork BlendSpace and body separation.
- Use the four verified animations: `jab`, `left_hook`, `right_hook`, `uppercut`; reserve `cross` without substituting another clip.
- Both player and AI continue using `BoxerController` and `CombatRules`.

## Tasks

1. Add a central typed punch catalog with timing, movement, range, tracking, contact and feedback data; test its four real attacks and reserved cross slot.
2. Replace the attack timer with explicit STARTUP/ACTIVE/RECOVERY phases, attack instance hit registry, buffered cancel window, mobile attack locomotion and startup-only tracking; test transitions and movement.
3. Resolve hits from real head/body targets with min/max range, angle, momentum and contact quality; test miss, clean hit, block, counter and one-hit-only behavior.
4. Make AI choose from the same catalog by range with a reaction delay; expose optional punch debug data, off by default.
5. Run focused, integration, gameplay, live-flow and regression suites; launch/capture the fight for visual validation.

## Review focus

- Holding forward/back/side during jab keeps horizontal motion without bypassing body separation.
- A fist can damage a target only once per attack instance.
- Hook and uppercut cannot land at jab distance.
- Buffer executes only in late recovery and expires after 0.22 seconds.
- Missing cross animation never aliases another punch.
