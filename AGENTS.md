# AGENTS.md — Godot Line

## Project Overview

Godot 4.7 Dancing Line game template (GDScript). No CLI build/test/lint — all development is in the Godot editor. Physics: Jolt Physics on separate thread. Renderer: mobile.

**README says 4.6 but `project.godot` config/features is 4.7.** Trust `project.godot`.

## Project Structure

```
#Template/           — Core template: scenes, scripts, resources, materials
  [Scripts]/         — All GDScript source (10 subdirectories)
  [Resources]/       — PackedScenes, LevelData, models, UI
  [Materials]/       — .tres material resources
  [Music]/           — Audio files
  *.tscn             — Template scenes (Player, trigger, Gem, etc.) — directly in #Template/ root, NOT in a [Scenes] subfolder
[Scenes]/            — Level scenes only
  DefaultScene/      — Default.tscn (the main playable scene)
  Sample/            — Sample.tscn
addons/
  godot_mcp/         — MCP server plugin (do not modify unless asked)
  template/          — Editor plugin: toolbar menu, "新建关卡" dialog
```

**Bracket-named directories** (`[Scripts]`, `[Resources]`, etc.) are a project convention, not Godot special syntax.

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
| **Pure component** (Mode 1) | `extends Node3D` | Parent `BaseTrigger` node | `Jump.gd`, `KillPlayer.gd`, `Speed.gd` |
| **Self-contained** (Mode 2) | `extends BaseTrigger` (Area3D) | Itself | `PyramidTrigger.gd`, `PropertyModifierTrigger.gd` |
| **Legacy** (Mode 3) | `extends Area3D` | Itself via `body_entered` | `Gem.gd`, `Checkpoint.gd`, `CameraTrigger.gd` |

**Mode 1 (pure component):** Implement `trigger(body: Node3D)` method. Place as child of a `BaseTrigger` node (or `trigger.tscn` instance). `BaseTrigger` uses duck typing — it calls `trigger(body)` on any child that has that method. No inheritance required.

**BaseTrigger** (`#Template/[Scripts]/Trigger/Single/BaseTrigger.gd`): `class_name BaseTrigger extends Area3D`. Exports: `one_shot`, `require_playing`, `track_exit`, `debug_mode`. Collects behaviors in `_ready()` via `_collect_behaviors()`.

## Core Singletons (All Static / RefCounted)

- **`LevelManager`** — `class_name LevelManager extends RefCounted`. All static. Game state machine (`GameStatus` enum), checkpoint data, revive listener system (`add_revive_listener`/`emit_revive`). NOT a Node — cannot use `_process` or signals in the traditional sense.
- **`AudioManager`** — `class_name AudioManager extends RefCounted`. All static. `play_clip()`, `play_track()`, `fade_out()`, `stop()`. Gets music player from `Player.instance.get_node("MusicPlayer")`.
- **`SetLatency`** — `class_name SetLatency extends RefCounted`. Persists delay/volume to ConfigFile at `user://settings.cfg`.
- **`Player.instance`** — Static var on Player (CharacterBody3D). Set in `_ready()`.

## Key Scenes and Entrypoints

- **Default scene:** `[Scenes]/DefaultScene/Default.tscn` (not Sample — Sample exists but Default is the primary)
- **Player scene:** `#Template/Player.tscn` — instantiated inside level scenes under `BasicOBJ_Group/Player`
- **Trigger container:** `#Template/trigger.tscn` — reusable BaseTrigger scene, add component children to it
- **Start page:** `#Template/[Resources]/StartPage.tscn` — dynamically instantiated by `Player._ready()`
- **Debug overlay:** `#Template/[Resources]/DebugOverlay.tscn` — dynamically instantiated by `Player._ready()`, toggle with D key (debug builds only)
- **Game UI:** `#Template/[Resources]/GAMEUI.tscn` — game over screen with revive/replay

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

New triggers use `CameraFollower.instance.trigger(...)`. Old triggers modify `OldCameraFollower` properties directly.

## Level Creation

Use the editor plugin: **Template > 新建关卡** in the toolbar. Creates `[Scenes]/<name>/<name>.tscn` + `<name>.tres` (LevelData) from template. The plugin deep-copies LevelData and assigns unique saveID.

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
