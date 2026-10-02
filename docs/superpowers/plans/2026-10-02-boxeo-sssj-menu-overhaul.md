# BOXEO SSSJ Menu and Progression Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four existing menu screens with responsive, controller-friendly native Godot interfaces and connect real three-fighter selection, career progression, and persistent settings to the existing game.

**Architecture:** Keep the four existing scene paths as lightweight `Control` roots and build their responsive contents through focused scripts backed by reusable theme/component helpers. Centralize fighter records in resources/database code and persistence in `SaveSystem`; the fight scene consumes session selections while preserving the existing ring, combat, camera, HUD, referee, and manager systems.

**Tech Stack:** Godot 4.7.2, GDScript, `.tscn` scenes, `.tres` resources, native `Control` containers, `Theme`/`StyleBoxFlat`, `SubViewport`, JSON/ConfigFile persistence, existing headless GDScript test runners.

**Spec:** `docs/superpowers/specs/2026-10-02-boxeo-sssj-menu-overhaul-design.md`

## Global Constraints

- Preserve `res://ring/boxing_ring.tscn`, source fighter FBXs, referee assets, combat animations, AnimationTrees, hitboxes/hurtboxes, punch rules, footwork, and opponent AI.
- Correct only metadata/controller-path issues inside `boxer_03.tscn`; do not edit its FBX or animation source resources.
- Use native Godot controls for every interactive element; never use invisible hotspots or baked image buttons.
- Support 1280×720, 1600×900, 1920×1080, and 2560×1440 with anchors and containers.
- Use exactly three fighters and prevent player/opponent mirror matches.
- Enabled settings must affect a real system; unsupported options remain disabled and labeled pending.
- Preserve mouse, keyboard, and generic gamepad operation through standard `ui_*` actions.
- Do not stage or overwrite unrelated user changes already present in the dirty worktree.

## Review Focus

- Corrupt or partial saved files must merge safely into defaults; Task 3 tests malformed JSON/config and unknown keys.
- Missing/unloadable fighter resources must disable confirmation rather than crash; Task 2 tests an invalid registry entry.
- Rapid preview switching must leave only the latest preview and free the previous instance; Task 4 tests repeated selection changes.
- Unsupported resolutions/display modes must retain the last valid configuration; Task 8 tests invalid values.
- No connected gamepad must still yield complete keyboard focus navigation; Tasks 5, 6, 7, and 8 test initial focus and `ui_cancel` behavior without a device.

---

### Task 1: Shared Visual System and Responsive Shell

**Files:**
- Create: `scripts/ui/boxing_theme.gd`
- Create: `scripts/ui/menu_components.gd`
- Create: `tests/menu_visual_system_runner.gd`
- Modify: `scripts/menus/menu_style.gd`

**Interfaces:**
- Produces: `BoxingTheme.create(high_contrast: bool = false, text_scale: float = 1.0) -> Theme`
- Produces: `BoxingTheme.palette() -> Dictionary`
- Produces: `MenuComponents.create_screen(root: Control, background: Texture2D, title: String) -> Dictionary`
- Produces: `MenuComponents.action_button(text: String, index: int = -1) -> Button`
- Produces: `MenuComponents.panel(title: String = "") -> VBoxContainer`
- Produces: `MenuComponents.stat_bar(label_text: String, value: float) -> Control`
- Produces: `MenuComponents.option_row(label_text: String, values: Array[String]) -> OptionButton`
- Produces: `MenuComponents.toggle_row(label_text: String, enabled: bool) -> CheckButton`
- Produces: `MenuComponents.slider_row(label_text: String, value: float, minimum: float, maximum: float, step: float) -> HSlider`

- [ ] **Step 1: Write the visual-system test**

Create assertions for the exact palette values, distinct normal/hover/focus/pressed/disabled button styles, minimum touch target height of 48 px, full-rect screen anchors, and non-null native controls from every builder.

- [ ] **Step 2: Run the test and verify RED**

Run: `Godot.exe --headless --path . --script res://tests/menu_visual_system_runner.gd`
Expected: FAIL because `BoxingTheme` and `MenuComponents` do not exist.

- [ ] **Step 3: Implement the reusable visual APIs**

Use the spec palette verbatim, generate `StyleBoxFlat` resources, and add a short focus/hover tween helper. Keep `MenuStyle` as a compatibility facade that delegates to the new components until all callers migrate.

- [ ] **Step 4: Verify GREEN**

Run the visual-system runner at 1280×720 and 1920×1080; expected `MENU VISUAL SYSTEM TESTS PASSED` with exit 0.

- [ ] **Step 5: Commit**

Commit only the four files with message `feat: add reusable BOXEO SSSJ menu visual system`.

### Task 2: Three-Fighter Data Registry and Boxer 03 Validation

**Files:**
- Modify: `scripts/data/fighter_data.gd`
- Create: `scripts/data/fighter_database.gd`
- Modify: `data/fighters/boxer_green.tres`
- Create: `data/fighters/boxer_02.tres`
- Create: `data/fighters/boxer_03.tres`
- Modify: `fighters/boxer_03/boxer_03.tscn`
- Create: `tests/fighter_database_runner.gd`

**Interfaces:**
- Produces: `FighterData.id: StringName`, `style: String`, `technique: int`, `portrait: Texture2D`
- Produces: `FighterDatabase.all() -> Array[FighterData]`
- Produces: `FighterDatabase.by_id(id: StringName) -> FighterData`
- Produces: `FighterDatabase.valid_for_fight() -> Array[FighterData]`

- [ ] **Step 1: Write registry and scene validation tests**

Assert exactly three unique IDs, exact weight/height/reach/style copy, five stats in `0..100`, loadable `PackedScene` values, root type `BoxerController`, and Fighter 3 name `FIGHTER 3`. Add a test-only invalid entry and assert it is excluded from `valid_for_fight()`.

- [ ] **Step 2: Run and verify RED**

Expected failures: missing database/resources and missing `id`, `technique`, and `portrait` fields.

- [ ] **Step 3: Implement data resources and database**

Use stable IDs `fighter_1`, `fighter_2`, and `fighter_3`. Store all UI-visible stats in `.tres` files. Correct Boxer 03 metadata and valid controller paths based on its actual imported hierarchy without editing animation resources.

- [ ] **Step 4: Run registry test plus `tests/gameplay_upgrade_runner.gd`**

Expected: both exit 0; registry prints `FIGHTER DATABASE TESTS PASSED`.

- [ ] **Step 5: Commit**

Commit with message `feat: register three playable fighters`.

### Task 3: Settings and Career Persistence Models

**Files:**
- Modify: `scripts/managers/save_system.gd`
- Create: `scripts/data/career_data.gd`
- Create: `tests/save_models_runner.gd`

**Interfaces:**
- Produces: `SaveSystem.default_settings() -> Dictionary`
- Produces: `SaveSystem.default_career() -> Dictionary`
- Produces: `SaveSystem.update_setting(key: StringName, value: Variant, apply_now: bool = true) -> bool`
- Produces: `SaveSystem.advance_week(action: StringName) -> Dictionary`
- Produces: `SaveSystem.record_fight(result: StringName, method: StringName, round_number: int, opponent_id: StringName, date: String) -> void`
- Consumes: fighter IDs from `FighterDatabase`

- [ ] **Step 1: Write persistence/model tests**

Use temporary `user://` fixture paths. Assert settings categories and defaults, six audio buses, legacy JSON migration, malformed-file fallback, unknown-key rejection, career fields from the spec, stat cap 100, fatigue/fitness bounds `0..100`, week progression, rest recovery, and complete history serialization.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL on missing APIs and missing career/settings keys.

- [ ] **Step 3: Implement normalized models and migration**

Use `user://settings.cfg` for settings and `user://career_save.json` for career. Retain read-only migration from the current JSON paths. Apply only supported values and return `false` for invalid values without changing prior state.

- [ ] **Step 4: Run and verify GREEN**

Expected: `SAVE MODEL TESTS PASSED`, exit 0, with fixture files removed by the runner.

- [ ] **Step 5: Commit**

Commit with message `feat: add validated settings and career persistence`.

### Task 4: Fighter Preview and Selection Flow

**Files:**
- Create: `scripts/ui/fighter_preview.gd`
- Modify: `scenes/menus/fighter_select.tscn`
- Rewrite: `scripts/menus/fighter_select.gd`
- Modify: `scripts/fight/fight_scene.gd`
- Create: `tests/fighter_select_runner.gd`
- Modify: `tests/integration_runner.gd`

**Interfaces:**
- Produces: `FighterPreview.show_fighter(data: FighterData) -> void`
- Produces: `FighterPreview.clear() -> void`
- Produces: `FighterSelectMenu.select_player(id: StringName) -> bool`
- Produces: `FighterSelectMenu.select_opponent(id: StringName) -> bool`
- Produces: `FighterSelectMenu.random_opponent() -> StringName`
- Consumes: `FighterDatabase.all()`, `FighterDatabase.by_id()`
- Produces session keys: `selected_player`, `selected_opponent`, `player_scene`, `enemy_scene`

- [ ] **Step 1: Write selection and preview tests**

Assert three fighter cards; resource-driven stats; two-step player/opponent flow; mirror rejection; Random always differs; Confirm disabled until valid; repeated preview changes retain one live fighter; invalid preview uses portrait/fallback; Back returns to Main Menu; Confirm stores all four session keys.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the current menu exposes one OptionButton fighter and permits identical scenes.

- [ ] **Step 3: Build the responsive Fighter Select UI and preview stage**

Use the supplied image only as darkened decoration. Load at most the highlighted fighter into the preview SubViewport and disable its gameplay processing/collisions there.

- [ ] **Step 4: Connect Fight to selected scenes**

In `fight_scene.gd`, resolve session paths through validated `FighterData`; replace the two default ring fighter nodes with selected instances, then perform existing role/opponent/camera/HUD/referee/manager wiring. Fall back to Fighters 1 and 2 when session data is absent or invalid.

- [ ] **Step 5: Run targeted and combat integration tests**

Run Fighter Select, integration, combat, footwork integration, and professional polish runners. Expected: all exit 0 and no duplicate fighter/ring nodes.

- [ ] **Step 6: Commit**

Commit with message `feat: add three-fighter selection and fight handoff`.

### Task 5: Main Menu Reconstruction

**Files:**
- Modify: `scenes/menus/main_menu.tscn`
- Rewrite: `scripts/menus/main_menu.gd`
- Create: `tests/main_menu_runner.gd`

**Interfaces:**
- Consumes: `MenuComponents.create_screen()` and `action_button()`
- Produces named controls: `QuickFightButton`, `CareerButton`, `FightersButton`, `SettingsButton`, `ExitButton`

- [ ] **Step 1: Write Main Menu navigation/focus tests**

Assert exact numbered labels, exact scene destinations, quick mode versus roster mode session state, initial `QuickFightButton` focus, explicit neighbor chain, and `ui_cancel` safety.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL on current `SPARRING` label and missing named/focused controls.

- [ ] **Step 3: Implement reference-inspired Main Menu**

Create a darkened decorative background, branded heading, left navigation stack, footer hints, and native focus/hover/pressed states. Preserve correct quit behavior.

- [ ] **Step 4: Verify at four target resolutions**

Run the Main Menu runner with each viewport size. Expected: all controls remain within viewport and `MAIN MENU TESTS PASSED`.

- [ ] **Step 5: Commit**

Commit with message `feat: rebuild BOXEO SSSJ main menu`.

### Task 6: Functional Career Hub

**Files:**
- Modify: `scenes/menus/career.tscn`
- Rewrite: `scripts/menus/career_menu.gd`
- Create: `scripts/ui/career_sections.gd`
- Create: `tests/career_menu_runner.gd`

**Interfaces:**
- Consumes: `SaveSystem.career`, `advance_week()`, `record_fight()`, and `FighterDatabase`
- Produces: `CareerMenu.show_section(section: StringName) -> void`
- Produces section IDs: `summary`, `training`, `calendar`, `team`, `contracts`, `ranking`, `news`, `statistics`

- [ ] **Step 1: Write Career UI tests**

Assert all sections/tabs exist; first focus; summary values come from save data; five training choices alter only their target stat within caps; Rest changes fatigue/fitness; Advance changes date/week; ranking contains three fighters; history renders method/round/date/opponent; Back works without mouse.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the current screen contains only Train, Fight Offer, and Back.

- [ ] **Step 3: Implement shared Career sections and responsive hub**

Use data-driven cards, progress bars, lists, and enabled actions. Team slots without mechanics are visibly locked; contracts use actual roster data; news derives from career events.

- [ ] **Step 4: Connect career fight offer**

Write a valid player/opponent selection into session, set mode `career`, and route to Fighter Select for confirmation without bypassing mirror validation.

- [ ] **Step 5: Run model, career UI, integration, and resolution tests**

Expected: all pass at 1280×720 and 1920×1080; no clipped required control.

- [ ] **Step 6: Commit**

Commit with message `feat: add functional career hub`.

### Task 7: Settings Application Services

**Files:**
- Modify: `scripts/managers/save_system.gd`
- Modify: `scripts/camera/boxing_camera.gd`
- Create: `tests/settings_application_runner.gd`

**Interfaces:**
- Produces: `SaveSystem.available_resolutions() -> Array[Vector2i]`
- Produces: `SaveSystem.apply_display_settings() -> bool`
- Produces: `SaveSystem.apply_audio_settings() -> void`
- Produces: `SaveSystem.apply_runtime_settings() -> void`
- Consumes camera settings through existing `BoxingCamera.setup()` plus exported/runtime properties for supported distance, height, FOV, and shake.

- [ ] **Step 1: Write real-application tests**

Assert six named audio buses and volume changes; VSync mode; FPS cap values 30/60/120/144/0; valid window modes/resolutions; rejection of unsupported resolution without state loss; camera properties update; no combat InputMap action is removed or rebound.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL on missing buses/APIs and unsupported setting validation.

- [ ] **Step 3: Implement supported application services**

Separate persistence from application. Guard platform display calls during headless tests. Keep gameplay-dependent values persisted but do not connect unsupported mechanics.

- [ ] **Step 4: Run settings and existing camera/combat tests**

Expected: all pass; InputMap action count and events remain unchanged.

- [ ] **Step 5: Commit**

Commit with message `feat: apply persistent audio display and camera settings`.

### Task 8: Settings Screen Reconstruction

**Files:**
- Modify: `scenes/menus/settings.tscn`
- Rewrite: `scripts/menus/settings_menu.gd`
- Create: `scripts/ui/settings_sections.gd`
- Create: `translations/ui_es.csv`
- Create: `translations/ui_en.csv`
- Modify: `project.godot`
- Create: `tests/settings_menu_runner.gd`

**Interfaces:**
- Consumes: Task 7 `SaveSystem` application methods and Task 1 components.
- Produces: `SettingsMenu.show_category(category: StringName) -> void`
- Produces category IDs: `general`, `controls`, `sound`, `graphics`, `gameplay`, `camera`, `language`, `accessibility`, `credits`

- [ ] **Step 1: Write Settings UI tests**

Assert all nine categories; AI difficulty `Easy/Normal/Hard`; rounds `3/6/8/10/12`; duration `1/2/3` minutes; FPS `30/60/120/144/Unlimited`; exact supported display/resolution lists; live audio update; Apply persistence; Reset defaults; detected device text; disabled pending controls; initial focus; explicit category/content focus transitions; and Back return behavior. Include invalid resolution/mode retention.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the current single-column screen lacks categories and most controls.

- [ ] **Step 3: Implement category navigation and real controls**

Build only native Controls. Mark unsupported gameplay/camera/color-filter features disabled with `PENDIENTE` help text. Use Spanish/English translation keys for all new labels.

- [ ] **Step 4: Add translation catalog**

Create `translations/ui_es.csv` and `translations/ui_en.csv`, register them in `project.godot`, and switch locale through `TranslationServer.set_locale()`.

- [ ] **Step 5: Run Settings UI/application/persistence tests at target resolutions**

Expected: all pass, with required content reachable by scrolling at 1280×720.

- [ ] **Step 6: Commit**

Commit with message `feat: rebuild functional settings interface`.

### Task 9: Transitions, Global Focus, and UI Audio

**Files:**
- Modify: `scripts/ui/boxing_theme.gd`
- Modify: `scripts/ui/menu_components.gd`
- Modify: four menu scripts
- Create: `tests/menu_input_runner.gd`

**Interfaces:**
- Produces: `MenuComponents.animate_screen_in(root: Control) -> Tween`
- Produces: `MenuComponents.bind_focus_feedback(root: Control) -> void`
- Produces: `MenuComponents.play_ui_cue(cue: StringName) -> void`

- [ ] **Step 1: Write keyboard/gamepad-equivalent navigation tests**

For every screen, simulate `ui_up/down/left/right/accept/cancel`; assert focus never becomes null, actions match mouse activation, disabled controls cannot receive action, and Back works with no gamepad connected.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL on incomplete explicit neighbor links and missing shared feedback APIs.

- [ ] **Step 3: Add lightweight transitions and focus/audio feedback**

Use 0.15–0.40 second tweens and the `UI` audio bus. If no UI stream asset exists, keep calls silent without errors rather than fabricating audio.

- [ ] **Step 4: Run input and all menu runners**

Expected: all pass with mouse-independent operation.

- [ ] **Step 5: Commit**

Commit with message `feat: add menu focus transitions and input polish`.

### Task 10: Final Integration, Visual QA, and Regression Pass

**Files:**
- Modify: `tests/integration_runner.gd`
- Create: `tests/menu_visual_capture.gd`
- Modify only defects found in files owned by Tasks 1–9.

**Interfaces:**
- Consumes all prior task interfaces.
- Produces no new product API.

- [ ] **Step 1: Extend end-to-end integration coverage**

Test Main Menu → Quick Fight → player → opponent → Confirm → Fight; return paths; all Career sections/actions; all Settings categories; supported setting changes; persistence reload; and absence of debugger errors caused by the implementation.

- [ ] **Step 2: Run the complete automated suite**

Run every `tests/*_runner.gd` with Godot using per-run logs. Expected: every process exit 0 and every runner prints its PASS sentinel. Report pre-existing UID warnings separately.

- [ ] **Step 3: Capture all four screens at 1280×720 and 1920×1080**

Inspect eight images for overlap, clipping, baked-text interference, contrast, focus visibility, and similarity to the supplied composition. Correct only observed defects and recapture.

- [ ] **Step 4: Perform persistence restart check**

Change audio/display/language and one career training value, close the test process, start a fresh process, and assert all persisted values reload. Restore test fixture data afterward.

- [ ] **Step 5: Verify gamepad condition**

If a gamepad is exposed, run physical navigation checks. Otherwise record `not available` and rely on simulated `ui_*` coverage without claiming physical validation.

- [ ] **Step 6: Run final diff and scope audit**

Confirm no changes to prohibited ring/combat/animation/FBX assets, no diagnostic logs or generated captures remain modified, and `git diff --check` is clean.

- [ ] **Step 7: Request final code review and resolve findings**

Use the review workflow against the full implementation diff, then rerun affected tests after every accepted correction.

- [ ] **Step 8: Commit final integration fixes**

Commit with message `test: verify BOXEO SSSJ menu overhaul`.
