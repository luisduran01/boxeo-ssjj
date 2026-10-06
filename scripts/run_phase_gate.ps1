param(
    [ValidateSet(1, 2, 3)]
    [int] $Phase = 1,

    [string] $GodotExe = "Godot.exe",

    [switch] $ListOnly
)

$ErrorActionPreference = "Stop"

$phaseRunners = @{
    1 = @(
        "res://tests/three_phase_plan_runner.gd",
        "res://tests/fight_lifecycle_runner.gd",
        "res://tests/fight_system_runner.gd",
        "res://tests/events_runner.gd",
        "res://tests/all_fighters_animation_runner.gd",
        "res://tests/move_data_runner.gd",
        "res://tests/presentation_feedback_runner.gd"
    )
    2 = @(
        "res://tests/phase_gameplay_runner.gd",
        "res://tests/phase_systems_runner.gd",
        "res://tests/technical_combat_runner.gd",
        "res://tests/boxing_footwork_controller_runner.gd",
        "res://tests/gameplay_completion_runner.gd",
        "res://tests/presentation_feedback_runner.gd"
    )
    3 = @(
        "res://tests/settings_application_runner.gd",
        "res://tests/settings_menu_runner.gd",
        "res://tests/career_menu_runner.gd",
        "res://tests/character_creator_runner.gd",
        "res://tests/live_flow_runner.gd",
        "res://tests/integration_runner.gd"
    )
}

$phaseNames = @{
    1 = "Base jugable solida"
    2 = "Combate maestro"
    3 = "Produccion final"
}

Write-Host "Phase $Phase gate: $($phaseNames[$Phase])"

if ($ListOnly) {
    $phaseRunners[$Phase] | ForEach-Object { Write-Host $_ }
    exit 0
}

$godotCommand = Get-Command $GodotExe -ErrorAction SilentlyContinue
if ($null -eq $godotCommand) {
    Write-Error "Godot executable not found: $GodotExe. Pass -GodotExe with the full path or use -ListOnly."
    exit 127
}

$failed = @()
foreach ($runner in $phaseRunners[$Phase]) {
    Write-Host "Running $runner"
    & $godotCommand.Source --headless --path . --script $runner
    if ($LASTEXITCODE -ne 0) {
        $failed += $runner
    }
}

if ($failed.Count -gt 0) {
    Write-Error "Phase $Phase failed runners: $($failed -join ', ')"
    exit 1
}

Write-Host "Phase $Phase gate passed"
exit 0
