# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GodotLine** — A Dancing Line game template for Godot 4.6. Lets users build levels and publish via GodotLineCollection. MIT license. Mobile renderer, Jolt Physics.

## Running / Testing

- Open `project.godot` in Godot Engine 4.6, press F5 to run
- Sample scene: `#Template/[Scenes]/Sample/Sample.tscn`
- Default export scene: `#Template/[Scenes]/DefaultScene/Default.tscn`
- Editor plugin enabled: `addons/template/plugin.cfg`
- No automated test suite exists; testing is manual via the editor

### Input Reference

| Key | Action |
|-----|--------|
| Mouse click / Space | Turn |
| R | Retry |
| K | Die (triggers death) |
| D | Toggle debug overlay (FPS, position, game state, diamonds, crowns, camera) |
| S | Save procedural road geometry to `res://Roads.tscn` |
| Q | Reload scene |
| W | Save taper (savetaper action) |

### Editor Tool Workflow

Both **NoteReader** and **BeatmapReader** use the same `@tool` pattern:
1. Attach the script to any node in your scene (or a new empty node)
2. Set exported parameters in the Inspector (`.osu` file path, route config, etc.)
3. Tick the **execute** checkbox — the getter always returns `false` but the setter triggers generation
4. Delete the node after generation completes

## Core Gameplay

The player (a `CharacterBody3D`) auto-moves along a **line** in 3D space, switching between two alternating forward directions (`forward1` → `forward2` → `forward1` ...). Each mouse click or Space press toggles the direction. The game is about timing these turns correctly.

- **RoadMaker** (Node3D child of the main line): procedurally generates floor segments (`StaticBody3D`) between successive player positions in `_physics_process()`. Road segments scale to fill the gap between position changes. The generated road can be saved to a scene via the S key (`RoadMaker.save()` → `res://Roads.tscn`).
- **Triggers** (Area3D-based): placed along the path, detect when the player passes through them. `Trigger` emits `hit_the_line` on contact. Specialized triggers modify camera, speed, fog, colors, play animations, teleport, etc.
- **AutoPlayController**: generates turn triggers at runtime from `GuidanceBox` positions (data-driven auto-play).
- **Collision layers**: Player (layer 1) collides with BaseFloor (layer 2, `collision_mask`) and BaseWall (layer 3, via an Area3D child with `collision_mask = 4`).

## Core Architecture

### Game State Machine (LevelManager.gd)

All game state lives in `LevelManager` (a static `RefCounted` — not a Node). The state machine drives the entire game:

```
Waiting → Playing → Moving → Died → Completed
```

- **Waiting**: initial state, first click transitions to Playing
- **Playing**: normal gameplay, player can turn
- **Died**: player hit obstacle, shows game over
- **Moving**: camera animation phase (e.g., level completion sequence)
- **Completed**: level finished

Key static variables: `GameState`, `main_line_transform`, `revive_position`, `anim_time`, `music_checkpoint_time`, `camera_checkpoint` (dict), `crowns`, `diamond`, `player_direction_index`.

### Singleton Pattern (instance-based)

Many key nodes use `class_name` + `static var instance` + `instance = self` in `_ready()`:
- `Player` (CharacterBody3D)
- `CameraFollower` / `OldCameraFollower` (Node3D)
- `GuidanceController` / `AutoPlayController`

### Revive / Checkpoint System

- **Checkpoint** (Area3D, class_name): captures full state — player transform, camera (new or old system), fog, light, ambient, material colors, music position, animation time
- **Crown** extends Checkpoint: adds particle effects
- **HeartCheckpoint** extends Checkpoint: animated checkpoint
- On death: `Checkpoint.revive()` restores everything — camera tweens are killed, music is seeked + paused, animation is seeked + paused, state returns to Waiting

### Trigger System (Area3D-based)

- **BaseTrigger** (class_name, extends Area3D): base with `one_shot` support, `triggered` signal, `_on_triggered()` virtual
- **Trigger**: emits `hit_the_line` signal on player contact
- **Checkpoint** / **Crown** / **HeartCheckpoint**: capture/restore full game state on revive
- **Diamond**: collectible counting toward `LevelManager.diamond`
- **ChangeTurn**: changes the player's turn direction
- **ChangeSpeedTrigger**: modifies player movement speed
- **Jump**: applies an upward impulse to the player
- **JumpPredictor / FallPredictor**: helper triggers for jump/fall trajectory visualization
- **CameraTrigger / CameraShakeTrigger**: camera position/rotation changes and shake effects
- **FogColorChanger**: modifies fog color/atmosphere
- **EventTrigger**: invokes a configurable event/callable
- **LocalTeleportTrigger / FakePlayerTransport**: teleport the player or a fake-player indicator
- **FakePlayerTrigger**: spawns/manages a fake player for visual guidance
- **KillPlayer**: triggers death (also bound to the K key)
- **customanimplay / PlayAnimator**: triggers animation playback
- **PyramidTrigger / Pyramid**: generates pyramid-shaped geometry as obstacles

### Camera Systems (two coexist)

- **CameraFollower** (new): Node3D hierarchy (CameraRoot > Rotator > Scale > Camera3D), Tween-based transitions, shake support
- **OldCameraFollower** (legacy): simpler follow with slerp/lerp, `RotateMode` enum

### RoadMaker (Procedural Road Generation)

Extends Node3D, attached as child of the main line. Generates floor segments in real-time:
- `new_line1` signal from parent → starts a new road segment
- `on_sky` signal from parent → stops generating (sets `road = null`)
- Each physics frame: positions and scales a single `StaticBody3D` to bridge the gap between past and current position
- Press **S** to pack all generated roads into `res://Roads.tscn` via `ResourceSaver.save()`

### Animator System

- **AnimatorBase** (class_name, extends Node3D): base with `trigger_by_time`, `@export_tool_button` for editor preview
- Concrete: `PosAnimator`, `LocalPosAnimator`, `LocalRotAnimator`, `MovingPosMax`

### Auto Play & Guidance

- **AutoPlayController**: generates turn triggers at runtime from GuidanceBox positions (data-driven auto-play)
- **GuidanceController**: spawns guidance boxes along the player path
- **SetAutoPlay**: teleports the player through a level while recording their inputs

### Beatmap Import (.osu → Level Geometry)

Two `@tool` editor-only scripts convert [osu!](https://osu.ppy.sh/) beatmap files into level geometry:

- **NoteReader**: Parses `.osu` hit times → generates road segments (BoxMesh) + optional auto-play Area3D triggers along alternating directions. Configurable speed, road width, colors, and trigger size.
- **BeatmapReader**: Parses `.osu` hit times → generates a sequence of **GuidanceBox** instances. Reads `Player` parameters (speed, direction, position) from the scene or uses manual overrides. Creates a `GuidelineTapHolder-BeatmapCreated` container node.

Both use the **`@export var execute: bool` checkbox pattern** (getter returns `false`, setter triggers generation when set to `true`).

### Event System

`LevelManager` has a static callable-listener pattern:
```gdscript
LevelManager.add_revive_listener(callable)
LevelManager.emit_revive()
```
Triggers and animators register with this to reset on revive. They also check `LevelManager.GameState` to decide behavior.

## Key Conventions

- **Naming**: `lowerCamelCase` for vars/funcs, `PascalCase` for class_name, `UPPER_SNAKE_CASE` for constants
- **Tool scripts**: `@tool` annotation used extensively — many scripts run in editor for preview
- **Resources**: Settings stored as `extends Resource` classes: `LevelData`, `CameraSettings`, `FogSettings`, `LightSettings`, `AmbientSettings`, `SingleColor`, `OldCameraSettings`
- **Physics layers**: 1=Player, 2=BaseFloor, 3=BaseWall
- **Player collision**: `collision_mask = 2` (floors), Area3D child has `collision_mask = 4` (walls)
- **Default speed**: 12.0, **Gravity**: Vector3(0, -9.3, 0)
- **Music latency**: `AudioServer.get_output_latency()` compensates for Bluetooth headphone delay

## Template Structure (all game content in `#Template/`)

```
#Template/
  [Scripts]/
    Level/         — Player.gd, LevelManager.gd, gameui.gd, RoadMaker.gd, death_particle.gd, Percentage.gd, DebugOverlay.gd
    Trigger/       — BaseTrigger.gd, Trigger.gd, Checkpoint.gd, Crown.gd, HeartCheckpoint.gd, Jump.gd, ChangeTurn.gd, ... (14+)
    CameraScripts/ — CameraFollower.gd, OldCameraFollower.gd, CameraTrigger.gd, CameraShakeTrigger.gd, FogTrigger.gd, CamTargetPoint.gd
    Animator/      — AnimatorBase.gd, PosAnimator.gd, LocalPosAnimator.gd, LocalRotAnimator.gd, MovingPosMax.gd
    Auto/          — AutoPlay.gd, AutoPlayController.gd, SetAutoPlay.gd
    Guidance/      — GuidanceController.gd, GuidanceBox.gd
    Editor/        — BeatmapReader.gd, NoteReader.gd
    Settings/      — LevelData.gd, CameraSettings.gd, FogSettings.gd, etc. (8 Resource scripts)
    PortTookits/   — Unity-to-Godot migration helpers
  [Scenes]/        — Sample/Sample.tscn, DefaultScene/Default.tscn
  [Resources]/     — Textures, models, shaders, UI assets, level data .tres files
  [Materials]/.tres files
  [Music]/
  *.tscn           — Root-level reusable scenes (Player, CameraRoot, Ground, CrownCheckPoint, etc.)
```

## Important Gotchas

- `move_and_slide()` must be called **before** `is_on_floor()` check, or floor detection always returns false
- `@tool` scripts run in editor — `_ready()` may fire before the tree is fully loaded; guard with `Engine.is_editor_hint()`
- When renaming/deleting a script, **must** update `.tscn` references or the scene breaks
- The `LevelManager` is `RefCounted` (not Node), so it has no `_ready()`, no tree access — use `Player.instance.get_tree()` instead
- Crown cost: revive at a checkpoint consumes 1 crown (`LevelManager.crown -= 1`)
- New camera (CameraFollower) and old camera (OldCameraFollower) are mutually exclusive per checkpoint, selected by `UsingOldCameraFollower` on the Checkpoint node
- **RoadMaker**: `new_road()` must be called via signal before `_physics_process()` starts tracking, otherwise road stays null and nothing generates
- **SetMaterialColor.gd**: part of the checkpoint restore chain — restores material colors on revive; changes trigger on `revive_notification`
- **`@export var execute: bool`** with a getter returning `false` is used by editor tools (NoteReader, BeatmapReader) as a one-shot trigger. The setter runs the generation, and the getter always shows unchecked.
- **The `_delay_applied` flag**: music delay must only be applied once on revive; guard with a flag to prevent re-application if `revive()` is called multiple times
- **Jolt Physics** (`physics/3d/physics_engine="Jolt Physics"`) runs physics on a separate thread (`3d/run_on_separate_thread=true`) — be mindful of thread safety when accessing physics state from non-physics callbacks
