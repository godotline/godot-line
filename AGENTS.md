# AGENTS.md — Godot Line

## Project Overview

Godot 4.7 Dancing Line game template (GDScript). No CLI build/test/lint — all development is in the Godot editor. Physics: Jolt Physics on separate thread. Renderer: mobile.

**README says 4.6 but `project.godot` config/features is 4.7.** Trust `project.godot`.

## Research Rule

- Use the tavily search tool for web research (Godot API questions, known issues, docs). **Never download Godot engine source files** (e.g. via `curl` of GitHub raw files) — prefer tavily search results and official docs pages instead.
- **DeepWiki MCP** (configured in `opencode.json`, remote server `https://mcp.deepwiki.com/mcp`) provides AI-powered docs for GitHub repos — e.g. `godotengine/godot` for engine internals like `ScriptServer::set_scripting_enabled()` / `GDScript::can_instantiate()` behavior. Use it for engine source questions instead of downloading source.
- Prefer the `gdmcp` skill's CLI (port 9080) for inspecting the running Godot editor (script states, `can_instantiate()`, editor logs, expression evaluation) over static analysis alone.

## Project Structure

```
#Template/             — Core template: scenes, scripts, resources, materials
  [Scripts]/           — All GDScript source (10 subdirectories)
  [Resources]/         — PackedScenes, LevelData, models, UI
  [Materials]/         — .tres material resources
  [Music]/             — Audio files
  [Scenes]/            — Template level scenes (DefaultScene/, Sample/) used by the "新建关卡" plugin
  *.tscn               — Template scenes (Player, trigger, Gem, etc.) — directly in #Template/ root, NOT in a [Scenes] subfolder
[Scenes]/              — Created levels only (the "新建关卡" plugin writes new levels here)
addons/
  godot_mcp/           — MCP server plugin (do not modify unless asked)
  template/            — Editor plugin: toolbar menu, "新建关卡" dialog
```

**Bracket-named directories** (`[Scripts]`, `[Resources]`, etc.) are a project convention, not Godot special syntax.

## Universal Add Component Panel (Editor Inspector Plugin)

`addons/template/component_inspector_plugin.gd` (+ `component_add_panel.gd`) registers an `EditorInspectorPlugin` that shows a "组件" (Add Component) panel at the bottom of the Inspector for **every Node** — no script attachment required. The panel contains only an "Add Component" button that calls `EditorInterface.popup_quick_open(callback, [&"Script"])` — the native quick-open dialog (godot-proposals #3745 was implemented in 4.7). Adds the selected script as a child node with undo/redo, owner assignment, `mark_scene_as_unsaved`, and auto-selects the new node. If the host has a `refresh_behaviors()` method (e.g. `BaseTrigger`), it is called on add/undo. `BaseTrigger` no longer has its own `componentScript` export — use this panel instead. Also: in the editor, `Script.can_instantiate()` returns `false` for **non-@tool** scripts by design (the editor disables scripting "except for tool" scripts — `ScriptServer::set_scripting_enabled(false)` in `EditorNode`) — never use it as a validity guard in editor tooling; `script.new()` works fine for non-tool scripts in the editor.

## Deleted / Renamed Files (Do Not Recreate)

| Old name | Status |
|----------|--------|
| `Trigger.gd` | Deleted — replaced by `BaseTrigger` |
| `customanimplay.gd` | Deleted — merged into `PlayAnimator.gd` |
| `ChangeSpeedTrigger.gd` | Renamed to `Speed.gd` |
| `SetActiveTrigger.gd` | Renamed to `SetActive.gd` |
| `LocalTeleportTrigger.gd` | Renamed to `Teleport.gd` |
| `ChangeTurn.gd` | Renamed to `ChangeDirection.gd` |
| `FogColorChanger.gd` | Does not exist — use `SetFog.gd` |
| `addons/mpm_importer/` | Does not exist |

## Trigger System — Three Modes Coexist

This is the most important architectural detail. **New triggers should use Mode 1.**

| Mode | Base | Collision handled by | Example |
|------|------|---------------------|---------|
| **Pure component** (Mode 1) | `extends Node` / `Node3D` | Parent `BaseTrigger` node | `Jump.gd`, `Gem.gd`, `Checkpoint.gd` |
| **Self-contained** (Mode 2) | `extends BaseTrigger` (Area3D) | Itself | `OldCameraShakeTrigger.gd` |
| **Legacy** (Mode 3) | `extends Area3D` | Itself via `body_entered` | `OldCameraTrigger.gd`, `CameraShakeTrigger.gd`, `GuidanceBox.gd` |

**Mode 1 (pure component):** Implement `trigger(body)` method. Place as child of a `BaseTrigger` node (or `trigger.tscn` instance). `BaseTrigger` uses duck typing — it calls `trigger(body)` on any child that has that method. No inheritance required.

**BaseTrigger** (`#Template/[Scripts]/Trigger/BaseTrigger.gd`): `class_name BaseTrigger extends Area3D`. Exports: `one_shot`, `require_playing`, `track_exit`, `debug_mode`. Collects behaviors in `_ready()` via `_collect_behaviors()`.

## Checkpoint / Crown — Unity Alignment Notes

The Checkpoint/Crown system is ported 1:1 from Unity `Checkpoint.cs` / `Crown.cs`. Two intentional semantic differences from Unity (do not "fix"):

- **`trackProgress` is stored in seconds, not percent.** Unity `Checkpoint.cs` saves `(int)player.SoundTrackProgress * 100` (0–100); Godot stores the AnimationPlayer position in seconds (`Checkpoint.gd` line ~111). They are equivalent for Godot's timeline model — don't convert.
- **`LevelManager.checkpointCount` counts crowns too.** Unity keeps crowns in a separate `player.Crowns` list and only regular checkpoints in `player.Checkpoints`; Godot increments `checkpointCount` in the base `Checkpoint._enter_trigger`, so crowns also advance it. Gems use the same counter (`index >= LevelManager.checkpointCount`), so the restore math stays internally consistent. This is a deliberate Godot design for crown-as-checkpoint levels.

**Revive screen fade (Unity parity):** `Checkpoint.revive()` (and `Crown.revive()`/`TTFCheckPoint` via `super`) wraps the scene reset in `LevelUI.HideScreen(fogColor, 0.32, ...)` — the same fog-colored screen flash Unity's `Revival()` does. `revive()` kills all tweens *before* `HideScreen` creates its fade tween (mirroring `DOTween.Clear()` ordering), runs the reset (`_reset_scene`) while the screen is opaque, and only sets `allowTurn = true` (and hides the UI) after the screen fades back out. `LevelUI.gd` has `class_name LevelUI` + `static var instance` (set in `_ready()`, cleared in `_exit_tree()`). The overlay is a full-screen `ColorRect` child of `LevelUI.tscn` named `HideScreen` (mouse_filter IGNORE at rest, STOP during fade).

## Core Singletons (All Static / RefCounted)

- **`LevelManager`** — `class_name LevelManager extends RefCounted`. All static. Game state machine (`GameStatus` enum), checkpoint data, revive listener system (`add_revive_listener`/`emit_revive`). NOT a Node — cannot use `_process` or signals in the traditional sense.
- **`AudioManager`** — `class_name AudioManager extends RefCounted`. All static. `PlayClip()`, `PlayTrack()`, `FadeOut()`, `Stop()`. Gets music player from `Player.instance.get_node("MusicPlayer")`.
- **`SetLatency`** — `class_name SetLatency extends RefCounted`. Persists delay/volume to ConfigFile at `user://settings.cfg`.
- **`Player.instance`** — Static var on Player (CharacterBody3D). Set in `_ready()`.

## Key Scenes and Entrypoints

- **Default scene:** `#Template/[Scenes]/DefaultScene/Default.tscn` (not Sample — Sample exists but Default is the primary)
- **Player scene:** `#Template/Player.tscn` — instantiated inside level scenes under `BasicOBJ_Group/Player`
- **Trigger container:** `#Template/Trigger.tscn` — reusable BaseTrigger scene, add component children to it
- **Start page:** `#Template/[Resources]/StartPage.tscn` — dynamically instantiated by `Player._ready()`
- **Debug overlay:** `#Template/[Resources]/DebugOverlay.tscn` — dynamically instantiated by `Player._ready()`, toggle with D key (debug builds only)
- **Game UI:** `#Template/[Resources]/LevelUI.tscn` — game over screen with revive/replay

## Input Controls

Defined in `project.godot`:
- **turn** action: Mouse Left + Space
- **R**: Reload level (in `Player._input`)
- **K**: Kill player (in `Player._input`)
- **D**: Toggle debug overlay (debug builds only, in `Player._input`)
- **S**: Save Roads.tscn (in `RoadMaker._input`)

## GDScript Conventions

- `lowerCamelCase` for variables and functions
- `PascalCase` for class names (`class_name`)
- `UPPER_SNAKE_CASE` for constants
- `lowerCamelCase` for signals
- All GDScript under `#Template/[Scripts]` must use static type annotations for variables (`var value: Type`), including local variables and exported properties. Use explicit types instead of leaving variables untyped; inferred declarations (`:=`) should be replaced with an explicit type when the type is known. This avoids type inference errors.
- Function parameters and return values under `#Template/[Scripts]` must also be explicitly typed.
- `@tool` annotation used extensively for editor preview (animators, triggers, resources)
- **`@tool` script buttons:** Any `@tool` script that modifies data via button presses (e.g. `_set`, exported button actions) must call `EditorUndoRedoManager` to register the action AND call `notify_property_list_changed()` so the Inspector refreshes. Without this, changes are invisible to the undo system and the Inspector may show stale data.
- Follow [Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

## Camera System — Two Generations

Two camera systems coexist, toggled by `Checkpoint.UsingOldCameraFollower`:
- **New:** `CameraFollower` (class_name, static var instance) + `CameraTrigger.gd` (pure component) + `CameraShakeTrigger.gd`
- **Old:** `OldCameraFollower` (class_name, static var instance) + `OldCameraTrigger.gd` (legacy Area3D) + `OldCameraShakeTrigger.gd`

New triggers use `CameraFollower.instance.Trigger(...)`. Old triggers modify `OldCameraFollower` properties directly.

## Level Creation

Use the editor plugin: **Template > 新建关卡** in the toolbar. Creates `[Scenes]/<name>/<name>.tscn` + `<name>.tres` (LevelData) from the `#Template/[Scenes]/` templates. The plugin deep-copies LevelData and assigns unique saveID.

## Common Pitfalls

- `LevelManager` is `RefCounted`, not a `Node`. It has no `_process`, no scene tree position. All members are static.
- `Player.instance` is `null` in editor — always null-check before runtime use.
- `BaseTrigger` uses duck typing (`has_method("trigger")`), not virtual methods or inheritance for behavior dispatch.
- `Gem.gd` filename is `Gem.gd`, not `Diamond.gd`. The field is `LevelManager.gem`, not `.diamond`.
- RoadMaker visual/collision separation: `_road_visuals` (MeshInstance3D, scaled per frame) vs `_road_collisions` (CollisionShape3D, finalized once). Don't mix them up.
- Player tail (ObjectPool, 256 MeshInstance3D) and RoadMaker road are **two independent systems**.
- `FogSettings` resource drives fog, not a standalone FogColorChanger script.
- Physics layers: 1=Player, 2=BaseFloor, 3=BaseWall.

## Performance Best Practices

### Avoid Recursive SceneTreeTimer Creation
**Problem:** Using `SceneTreeTimer` in recursive patterns (creating a new timer in the timeout callback) causes frequent temporary object allocation, increasing GC pressure and causing FPS drops during gameplay.

**Example (problematic):**
```gdscript
func _poll() -> void:
    # Do something
    var timer: SceneTreeTimer = get_tree().create_timer(0.5)
    timer.timeout.connect(_poll)  # Recursive call creates new timer each time
```

**Solution:** Use persistent `Timer` nodes instead:
```gdscript
var _poll_timer: Timer

func _ready() -> void:
    _poll_timer = Timer.new()
    _poll_timer.wait_time = 0.5
    _poll_timer.one_shot = false
    _poll_timer.autostart = true
    _poll_timer.timeout.connect(_poll)
    add_child(_poll_timer)

func _poll() -> void:
    # Do something (no timer creation)
```

**Fixed example:** `DebugOverlay.gd` was causing FPS drops due to recursive SceneTreeTimer usage. Fixed by using persistent Timer nodes.

### Cache Expensive Node Lookups
**Problem:** Calling `get_viewport().get_camera_3d()` or similar lookups every frame is expensive.

**Solution:** Cache the reference once, update only when needed:
```gdscript
var _cached_camera: Camera3D

func _ready() -> void:
    _cached_camera = get_viewport().get_camera_3d()
```

**Note:** `SetFog.gd` uses `get_viewport().get_camera_3d()` but only on trigger activation (not per-frame), so it's acceptable.

## Unity Alignment Status (v2.3)

### ✅ Completed — Function Name Alignment (PascalCase)

All snake_case methods that have a direct Unity PascalCase counterpart have been renamed. Full list:

| Godot File | Renamed Methods |
|------------|----------------|
| `Player.gd` | `PlayerDeath`, `Turn`, `ResetHenshinState`, `ClearPool` (FakePlayer), `StopPlayer` (Pyramid), `Speed` (var) |
| `LevelManager.gd` | `InitPlayerPosition`, `DestroyRemain`, `CompareCheckpointIndex`, `GameOverNormal`/`GameOverRevive`, `SetFPSLimit`, `GetColorByContent` |
| `AudioManager.gd` | `PlayClip`, `PlayTrack`, `FadeOut`, `Stop`, `Play`, `Pitch`, `Volume`, `Progress` (only `Time` kept as `time` — shadows Godot native `Time` class) |
| `ObjectPool.gd` | `Add` |
| `CameraFollower.gd` / `OldCameraFollower.gd` | `DoShake`, `KillAll`, `KillAllCameraTweens`, `ResetShake`, `Trigger` |
| `AutoPlayController.gd` | `SetHolder` |
| `AutoPlay.gd` | `SetActive` |
| `Crown.gd` | `AnimateCrown` |
| `HideCanvas.gd` / `ShowCanvas.gd` | `BtnHide`, `BtnShow`, `StopTweens`, `OnClick` |
| `TTFGem.gd` | `PickUp` |
| `TTFCheckPoint.gd` | `EnterTrigger` |
| `GuidanceBox.gd` | `SetColor` |

### ✅ Completed — Remove Orphaned Assets

Deleted: `crown_get_1/2/3.wav`, `BlackCrown_Light/UnLight.png`, `PerfactCrownLight/NoLight.png`, `Models/PerfactCrown.obj`, `ui/` (6 png), `Sample.mp3`, `Shake_It_Up.ogg`, `CameraFollower3/Trigger3/Shake3.gd`, `DefaultScene3/`, `beatmap_reader.gd`, `note_reader.gd` (renamed to `NoteReader.gd`).

### ✅ Completed — Dust Particle Extraction

`#Template/[Resources]/Dust.tscn` (GPUParticles3D) created. Player.gd uses `dustParticle` preload, instantiates on land at -0.5 below player, destroys after 2s. Removed inline LandEffect node from Player.tscn.

### ✅ Completed — DeathParticle → PlayerCubes (Unity Remain.prefab)

`DeathParticle.tscn` rewritten: Node3D root + 20 Fragment (RigidBody3D, mass=100, angular_damp=0.05, default hidden+disabled). `death_particle.gd` → `PlayerCubes.gd` (`class_name PlayerCubes`). `Play()` activates fragments, random scale/rotation, `apply_central_impulse()`. `PlayerDeath()` accepts `hasCollision` param (default `true` for wall death, `false` for KillPlayer/K key).

### ❌ Not Renamed (Godot-Specific, No Unity Counterpart)

The following snake_case methods are intentionally left as-is — they are Godot-specific conventions:

- `trigger(body)` — Duck-typed Mode-1 component interface (BaseTrigger convention)
- `_on_*` / `_ready` / `_process` / `_physics_process` — Godot engine callbacks
- `set_camera`/`get_camera` — CameraSettings resource accessors (not Unity `CameraFollower.SetCamera`)
- `save_settings`/`load_settings` — SetLatency (Unity uses `AddLatency`/`SubtractLatency` — different design)
- `revive()` — Checkpoint internal method (Unity `RevivePlayer` is on Player, different)
- `reload`/`new_line`/`enable_henshin` — Player-specific (no Unity equivalent)
- `hide_animated`/`show_ui`/`reveal` — GUI-specific
- `apply_*`/`capture_*`/`restore_*`/`get_*` — Internal state management
- `destroy_all` — ObjectPool (Unity has `DestoryAll` — typo, not replicated)
- `pop` — ObjectPool (Unity `First()` — different semantics: pop vs peek)
- `refresh_tracking`/`refresh_behaviors` — AutoPlay/BaseTrigger internal
- `trigger_manually`/`trigger_animation`/`apply_tweened` — Animator-specific
- All `@export` variables (scene-binding) — left as camelCase per Godot convention

### ⚠️ Known Issues

- **Tags partially rewritten** (v2.3 release): tags v1.0-stable through v2.2 were force-pushed with rewritten author (meny2333). v1.2.0 rejected (annotated tagger email). Not restored by user choice.
- **Merge commit author**: v2.3 merge commit shows "meny" (GitHub profile name) instead of "meny2333". The work commit (40b3919) has correct author.
- **GitHub proxy**: repo uses proxy at `127.0.0.1:7897`. Must be running for git/gh operations.
- **`AudioManager.Time`**: cannot be renamed to `Time` (shadows Godot native `Time` class). Kept as `time`.
- **`OnClick`/`StopTweens`/`BtnHide`/`BtnShow`**: HideCanvas/ShowCanvas had pre-existing recursive-placeholder compatibility aliases (`func X():\n\tX()`) that were removed during rename. The real renamed methods are the sole definitions now.