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
| **Pure component** (Mode 1) | `extends Node` / `Node3D` | Parent `BaseTrigger` node | `Jump.gd`, `Gem.gd`, `Checkpoint.gd` |
| **Self-contained** (Mode 2) | `extends BaseTrigger` (Area3D) | Itself | `OldCameraShakeTrigger.gd` |
| **Legacy** (Mode 3) | `extends Area3D` | Itself via `body_entered` | `OldCameraTrigger.gd`, `CameraShakeTrigger.gd`, `GuidanceBox.gd` |

**Mode 1 (pure component):** Implement `trigger(body: Node3D)` method. Place as child of a `BaseTrigger` node (or `trigger.tscn` instance). `BaseTrigger` uses duck typing — it calls `trigger(body)` on any child that has that method. No inheritance required.

**BaseTrigger** (`#Template/[Scripts]/Trigger/BaseTrigger.gd`): `class_name BaseTrigger extends Area3D`. Exports: `one_shot`, `require_playing`, `track_exit`, `debug_mode`. Collects behaviors in `_ready()` via `_collect_behaviors()`.

## Core Singletons (All Static / RefCounted)

- **`LevelManager`** — `class_name LevelManager extends RefCounted`. All static. Game state machine (`GameStatus` enum), checkpoint data, revive listener system (`add_revive_listener`/`emit_revive`). NOT a Node — cannot use `_process` or signals in the traditional sense.
- **`AudioManager`** — `class_name AudioManager extends RefCounted`. All static. `play_clip()`, `play_track()`, `fade_out()`, `stop()`. Gets music player from `Player.instance.get_node("MusicPlayer")`.
- **`SetLatency`** — `class_name SetLatency extends RefCounted`. Persists delay/volume to ConfigFile at `user://settings.cfg`.
- **`Player.instance`** — Static var on Player (CharacterBody3D). Set in `_ready()`.

## Key Scenes and Entrypoints

- **Default scene:** `[Scenes]/DefaultScene/Default.tscn` (not Sample — Sample exists but Default is the primary)
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
- **Unity parity ports:** Preserve the Unity source's serialized field and runtime variable names exactly when they are valid GDScript identifiers (for example, `activeOnAwake`, `dontRevive`, and `showInLow`). Do not translate them to `snake_case`; retain Unity method names too when a serialized callback or external call depends on them.
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

## Timeline System (`addons/timeline/` + `#Template/[Scripts]/TimeLineExpand/`)

A Unity Timeline clone: editor dock + runtime director + **custom track extension API**.

### Architecture

| Layer | Files | Role |
|-------|-------|------|
| Core | `addons/timeline/core/timeline_asset.gd` | `TimelineAsset` — tracks array, duration, deep-duplicate |
| Core | `addons/timeline/core/timeline_track.gd` | `TimelineTrack` — abstract base; **the extension API** |
| Core | `addons/timeline/core/timeline_clip.gd` | `TimelineClip` — start/duration/blend_in/blend_out/template |
| Core | `addons/timeline/core/timeline_behaviour.gd` | `TimelineBehaviour` — per-clip serialized data |
| Core | `addons/timeline/core/timeline_mixer.gd` | `TimelineMixer` — Unity MixerBehaviour (first-frame cache → blend → restore) |
| Core | `addons/timeline/core/timeline_director.gd` | `TimelineDirector` (Node) — playback: play/pause/stop/seek, per-track evaluation, clip weights, enter/exit |
| Core | `addons/timeline/core/timeline_registry.gd` | `TimelineRegistry` (static) — auto-discovers track subclasses via EditorFileSystem |
| Editor | `addons/timeline/plugin.cfg` + `plugin.gd` | Registers dock (`DOCK_SLOT_BOTTOM`) + inspector plugin |
| Editor | `addons/timeline/editor/timeline_dock.gd` | Dock UI: toolbar, track rows, ruler, playhead, add-track menu |
| Demo | `addons/timeline/tracks/*.gd` | Signal/Animation/Transform tracks — proof of extension API |
| Ports | `#Template/[Scripts]/TimeLineExpand/` | 9 Unity `#TimeLine_ExpandTrack` ports: Fog, Environment, Material, Bloom, DepthOfField, MotionBlur, ColorGrading, Vignette, AmbientOcclusion (each = Track/Clip/Behaviour/Mixer, 36 files) |

### Writing a custom track (extension API)

Create one `.gd` subclassing `TimelineTrack`. The editor's **Add Track** menu picks it up automatically via `TimelineRegistry.discover_editor` (runs in `_enter_tree`; any script whose instance `is TimelineTrack` gets registered; category = parent dir name). No plugin-source changes needed.

```gdscript
@tool
class_name MyTrack
extends TimelineTrack

class MyBehaviour extends TimelineBehaviour:
	@export var my_value: float = 1.0

class MyClip extends TimelineClip:
	func _init() -> void:
		template = MyBehaviour.new()

func _init() -> void:
	track_color = Color(0.2, 0.8, 0.6)

func get_clip_class() -> Script:
	return MyClip          # inner-class reference — used by "Add Clip"

func has_mixer() -> bool:
	return true            # mixer path (Unity CreateTrackMixer) …

func create_mixer() -> TimelineMixer:
	return MyMixer.new()   # … or use process_clip/on_clip_entered (no mixer)
```

Mixer contract: `TimelineMixer extends RefCounted`, director sets `mixer.bound` then calls `on_first_frame()` once (guarded by `_first_frame_done`) and `process_frame(inputs, time, delta)` each frame. `inputs` = `Array[Dictionary]` of `{clip, behaviour, weight, clip_time}` (weights ramp via `blend_in`/`blend_out`). `on_playable_destroy()` restores defaults (Unity `OnPlayableDestroy`).

### Director usage

- `TimelineDirector` is a plain Node; `@export var timeline: TimelineAsset` + `autoplay`/`loop`. Dock transport finds the first `TimelineDirector` in the edited scene (add via the dock's "添加 TimelineDirector" button).
- The director keeps its own `time`; the game's canonical clock is `LevelManager.anim_time`. Tracks may read it for game-sync.

### Godot 4.7 vs Unity port mapping (IMPORTANT — verified)

- **Fog** → `Environment.fog_*`; `FogMode.Linear` ↔ `fog_mode = DEPTH` (fog_depth_begin/end), `Exponential` ↔ `fog_mode = EXPONENTIAL` (fog_density).
- **Environment (ambient)** → `ambient_light_source` (AmbientSource: BG=0, DISABLED=1, COLOR=2, SKY=3). **No Trilight** — Trilight averages Sky/Equator/Ground into one color.
- **Material** → bound `GeometryInstance3D` → `material_override` (`StandardMaterial3D`): `albedo_color` + `emission` (HDR native). Unity `[TrackBindingType(typeof(Material))]` → `validate_binding(bound is GeometryInstance3D)`.
- **Bloom** → **Glow** (`glow_*` on Environment): `glow_intensity`, `glow_hdr_threshold`, `glow_hdr_scale`, `glow_bloom`. No `bloom_*` props exist.
- **DepthOfField** → **NOT on Environment**; lives on `CameraAttributesPractical` (assigned to `Camera3D.attributes`): `dof_blur_amount`, `dof_blur_far_*`, `dof_blur_near_*`. Mixer creates it if absent.
- **MotionBlur / Vignette** → **removed in Godot 4** — ports are deliberate no-ops (data preserved, `process_frame` does nothing; comment documents it).
- **ColorGrading** → `adjustment_*` (+ `tonemap_mode` ToneMapper: LINEAR=0, REINHARDT=1, FILMIC=2, ACES=3, AGX=4). `white_balance_*` does NOT exist (temperature/tint kept as data, not applied).
- **AmbientOcclusion** → **`ssao_*`** on Environment (`ssao_intensity`, `ssao_radius`, `ssao_enabled`). No `ambient_occlusion_*` props.
- All mixers resolve the target Environment via: bound `WorldEnvironment` → bound `Camera3D` → `Player.instance.get_scene_camera()` (null-guarded), mirroring `SetFog.gd`.

### Editor plugin notes

- plugin.cfg lives at the **addon root** (`addons/timeline/plugin.cfg`), not in `editor/`.
- Dock removal uses `remove_control_from_docks` (plural — no singular method in 4.7). Dock slot `DOCK_SLOT_BOTTOM`.
- All dock mutations are undo-wrapped via `EditorInterface.get_editor_undo_redo()` (AGENTS.md `@tool` convention).
- Acceptance test asset: `addons/timeline/test/TestTimeline.tres` (TimelineAsset with Fog + Environment tracks and clips — proves ported-track serialization).
- Demo scene: `addons/timeline/test/TimelineDemo.tscn` + `TimelineDemo.tres` — WorldEnvironment + DemoCamera + DemoCube + TimelineDirector (autoplay) with 4 tracks: Fog (mixer), Environment (mixer), Bloom (mixer, bound to camera), Transform (non-mixer process_clip path, moves/rotates DemoCube). Run it with **F6 (Run Current Scene)** or open it in the editor to see the dock's transport drive the director.
- Demo track structure: the 3 demo tracks in `addons/timeline/tracks/` use the **4-file layout** (Track/Clip/Behaviour as separate files with `class_name`) so they serialize in `.tres` — inner classes (e.g. `class TransformClip` inside the track file) do NOT deserialize correctly from `.tres` (typed arrays reject them), so keep Clip/Behaviour as standalone `class_name` files.
- GDScript gotcha: `Color.TRANSPARENT` is `(1,1,1,0)` in Godot, not `(0,0,0,0)` — always init blend accumulators with `Color(0, 0, 0, 0)`.

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
