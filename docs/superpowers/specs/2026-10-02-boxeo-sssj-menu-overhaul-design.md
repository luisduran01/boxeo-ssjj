# BOXEO SSSJ Menu and Progression Overhaul

## Objective

Replace the current generated menu interfaces with four responsive, functional Godot 4.7.2 screens inspired by the supplied images in `res://menus/`: Main Menu, Fighter Select, Career, and Settings. The images are visual references and optional decorative backgrounds; all navigation, statistics, tabs, selectors, sliders, toggles, and buttons are native interactive Godot controls.

The work must preserve the existing combat systems, `boxing_ring.tscn`, animation trees, source animations, hitboxes, hurtboxes, footwork, referee, and opponent AI except where the fight entry point must read the selected fighter scenes.

## Confirmed Assets

- Main Menu reference: `res://menus/Menuboxeo.png`
- Fighter Select reference: `res://menus/fighterselect.png`
- Career reference: `res://menus/Menú de carrera de boxeo cinemático.png`
- Settings reference: `res://menus/Menú de ajustes de BOXEO SSSJ.png`
- Fighter 1: `res://fighters/boxer_green/boxer_green.tscn`
- Fighter 2: `res://fighters/boxer_02/boxer_02.tscn`
- Fighter 3: `res://fighters/boxer_03/boxer_03.tscn`

`boxer_03.tscn` already uses the shared boxer controller but currently identifies itself as `BOXER 02` and has empty animation/skeleton paths. Integration will correct scene metadata and validate that the shared controller resolves its animation player and skeleton without editing the FBX or source animation resources.

## Visual System

The four screens share one reusable runtime theme and component library:

- Background: `#07090D`
- Primary panel: `#0B0D12E6`
- Secondary panel: `#101319`
- Gold: `#C6A34A`
- Bright gold: `#E5CB78`
- Primary text: `#F4F4F4`
- Secondary text: `#A9ADB5`

Reusable builders create branded headings, translucent panels, numbered menu buttons, stat bars, section tabs, option rows, toggle rows, sliders, and footer prompts. Focus, hover, pressed, and disabled states use distinct native `StyleBox` resources. Focus and hover animate over roughly 0.15 seconds; screen/panel transitions remain between 0.15 and 0.40 seconds.

Reference images may be displayed behind a dark overlay or cropped to clean decorative regions. Drawn buttons and text must not remain visually legible behind functional controls. UI nodes use anchors and containers and must remain usable at 1280×720, 1600×900, 1920×1080, and 2560×1440.

## Architecture

The existing four `.tscn` scene paths remain stable. Each scene is a lightweight full-rect `Control` with a dedicated script. Scripts compose the dense responsive layout from reusable helpers rather than storing thousands of generated scene lines.

Planned shared modules:

- `scripts/ui/boxing_theme.gd`: palette, style boxes, typography, focus styling, and transitions.
- `scripts/ui/menu_components.gd`: reusable panels, buttons, stats, option rows, sliders, tabs, and footer prompts.
- `scripts/data/fighter_database.gd`: ordered access to exactly three `FighterData` resources.
- `scripts/data/career_data.gd`: defaults, normalization, training rules, calendar progression, history, and ranking view models.
- Existing `SaveSystem` remains the persistence entry point and is extended rather than replaced.

No UI control writes files directly. Screens update `SaveSystem.settings`, `SaveSystem.career`, or `SaveSystem.session`, and `SaveSystem` owns persistence and application of supported settings.

## Fighter Data

`FighterData` gains stable `id`, `style`, and `technique` fields while preserving existing fields. Three independent `.tres` resources populate the database:

- FIGHTER 1: 60 kg, 170 cm, 55 cm reach, FAJADOR
- FIGHTER 2: 60 kg, 170 cm, 55 cm reach, TÉCNICO
- FIGHTER 3: 60 kg, 170 cm, 55 cm reach, ESTILISTA

Power, speed, stamina, defense, and technique live in the resources, never in UI scripts. Existing sensible values may seed Fighter 1; Fighters 2 and 3 receive distinct balanced profiles.

## Main Menu

Main Menu recreates the reference composition with a branded left navigation column and decorative arena/fighter background. It exposes exactly:

1. QUICK FIGHT → Fighter Select in quick mode
2. CAREER → Career
3. FIGHTERS → Fighter Select in roster-browse mode
4. SETTINGS → Settings
5. EXIT → `SceneTree.quit()`

`QuickFightButton` receives focus on entry. Mouse, keyboard, and gamepad activate the same buttons. `ui_cancel` has no destructive effect on the root menu.

## Fighter Select

Fighter Select has a two-step state machine: select player, then select opponent. The center roster contains exactly three real fighters. It provides previous/next navigation, selectable fighter cards, Random, Back, and Confirm Fight.

The screen displays weight, height, reach, style, power, speed, stamina, defense, and technique from `FighterData`. Player and opponent selections are stored as stable fighter IDs and scene paths. Mirror matches are rejected; Random selects a valid different opponent.

A `SubViewport` preview stage is the primary preview implementation. It loads only the currently highlighted fighter, with a preview camera, neutral environment, lights, and pedestal. If a fighter cannot instantiate safely in preview, its supplied/imported portrait is used for that slot while retaining the same preview interface.

Confirm Fight writes `selected_player`, `selected_opponent`, `player_scene`, and `enemy_scene` to the session and opens `res://fight/fight.tscn`. Fight setup instantiates or replaces the two ring fighter nodes from those selected scenes, assigns player/AI roles, and retains the existing camera, HUD, referee, and manager wiring.

Roster-browse mode shows the same real data and previews but changes the primary action to return rather than begin a fight.

## Career

Career is a functional hub with top tabs and left sections. The first release contains:

- Summary: fighter identity, record, money, fitness, training progress, next fight, ranking excerpt, and recent history.
- Training: Power, Speed, Stamina, Defense, and Technique choices.
- Calendar: current date/week, next fight, Train, Rest, and Advance Time actions.
- Team Management: a functional informational base with locked/available staff slots; no fake purchases.
- Contracts: current or available basic fight offer derived from the three-fighter roster.
- Ranking: all three fighters, positions, wins, losses, draws, and KOs.
- News: generated career events from actual training, scheduled fights, and results.
- Statistics: complete career attributes and aggregate record.

Training consumes an available week, adds fatigue, lowers short-term fitness, and increases one attribute up to a hard cap of 100. Rest consumes a week, reduces fatigue, and restores fitness. Time cannot advance backward. Fight history stores result (`WIN`, `LOSS`, `DRAW`), method (`KO`, `TKO`, `UD`, `SD`, `MD`), round, date, and opponent.

Career persistence uses `user://career_save.json`. Existing `user://career.json` data is migrated by merging known legacy values into the new defaults once. Missing or malformed values fall back safely to defaults.

## Settings

Settings uses a category list and a content panel. Every enabled control applies real state or persists a value consumed by an existing system.

Implemented categories and behavior:

- General: AI difficulty, rounds, round duration, metric/imperial units, HUD, visible damage, replays, tips, and tutorial preferences.
- Controls: detected keyboard/gamepad status, vibration, camera inversion, punch/camera sensitivity, and restore-default action. Existing InputMap bindings remain unchanged in this release.
- Sound: Master, Music, SFX, Voice, Crowd, and UI buses with live volume updates.
- Graphics: Windowed, Fullscreen, supported Borderless mode, enumerated resolutions, VSync, FPS cap, and Low/Medium/High quality mapped to supported viewport/project properties.
- Gameplay: supported AI difficulty, damage/stamina/regeneration multipliers if the combat system already exposes safe integration points. Unsupported assistance, indicators, auto-clinch, and adaptive AI remain disabled and labeled pending.
- Camera: distance, height, FOV, and shake connect to existing camera properties. Unsupported KO zoom/replay slow motion remain disabled.
- Language: Spanish and English through Godot translation keys for new UI copy.
- Accessibility: text scale, subtitles preference, high contrast theme, and reduced camera shake. Color-vision filters remain disabled until a real post-process implementation exists.
- Credits: static project credits and version information.

Apply saves to `user://settings.cfg` and updates the running application. Back returns to `settings_return_scene` when opened from combat, otherwise Main Menu. Existing JSON settings migrate into the new configuration defaults.

## Input and Focus

All interactive controls participate in explicit focus chains. The first meaningful control grabs focus on entry and after changing categories or panels. `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, and `ui_cancel` work without a mouse. Focus uses the bright gold visual state. Mouse hover synchronizes focus where appropriate.

Gamepad detection uses connected device IDs and generic input actions; behavior never depends on an exact controller name. Physical gamepad validation is reported as unavailable if the execution environment exposes no controller.

## Error Handling

- Missing fighter data: omit the invalid roster entry, log a clear error, and disable fight confirmation unless two valid fighters remain.
- Failed preview: replace with portrait/fallback panel without blocking selection.
- Invalid saved data: merge validated values into defaults and continue.
- Unsupported display mode or resolution: retain the previous valid value.
- Missing audio bus: create it before applying volume.
- Scene transition failure: log the Godot error and keep the current screen usable.

## Performance

Only the current menu scene is loaded. Fighter Select holds at most one live 3D preview per side and frees old preview instances before replacement. Career cards use data and textures rather than live fighter scenes. Large reference images use Godot imports and are not duplicated in memory by scripts.

## Testing and Validation

Implementation follows test-first development. Automated runners will verify:

- Main Menu button labels, destinations, initial focus, and exit connection.
- Exactly three valid fighter resources and scenes.
- Player/opponent flow, Random behavior, mirror-match rejection, session values, and selected scene use in Fight.
- Career training caps, fatigue/fitness changes, calendar progression, rankings, history serialization, and migration.
- Settings persistence and live application of audio, display, FPS, VSync, and camera-supported values.
- Focus navigation and Back behavior for all four scenes.
- Layout presence and usable bounds at the four target resolutions.
- Existing combat, footwork, punch, and integration runners remain green.

Visual captures at 1280×720 and 1920×1080 will be inspected for overlap, clipping, legibility, conflicting baked text, and adherence to the reference composition. The debugger log must contain no errors introduced by this work. Pre-existing asset UID warnings will be recorded separately and not misreported as new UI defects.

## Delivery Boundaries

This work does not edit `boxing_ring.tscn`, source fighter FBXs, referee assets, combat animations, AnimationTrees, hitboxes/hurtboxes, punch rules, footwork, or opponent AI. It may correct `boxer_03.tscn` metadata and controller paths required to make the already-created scene usable. Unsupported gameplay or rendering settings are displayed only as disabled future-facing controls, never as fake working options.
