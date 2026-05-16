# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GodotLine** — A Dancing Line game template for Godot 4.6. Lets users build levels and publish via GodotLineCollection. MIT license. Mobile renderer, Jolt Physics.

## Running / Testing

- Open `project.godot` in Godot Engine 4.6, press F5 to run
- Sample scene: `#Template/[Scenes]/Sample/Sample.tscn`
- Default export scene: `#Template/[Scenes]/DefaultScene/Default.tscn`
- Input: Mouse click / Space = turn, R = retry, K = die, D = toggle debug overlay
- No automated test suite exists; testing is manual via the editor

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
- **Trigger**: emits `hit_the_line` signal
- Specialized triggers: `CameraTrigger`, `CameraShakeTrigger`, `ChangeSpeedTrigger`, `ChangeTurn`, `Jump`, `EventTrigger`, `LocalTeleportTrigger`, `FogColorChanger`, `customanimplay`, `PlayAnimator`, `PyramidTrigger`

### Camera Systems (two coexist)

- **CameraFollower** (new): Node3D hierarchy (CameraRoot > Rotator > Scale > Camera3D), Tween-based transitions, shake support
- **OldCameraFollower** (legacy): simpler follow with slerp/lerp, `RotateMode` enum

### Animator System

- **AnimatorBase** (class_name, extends Node3D): base with `trigger_by_time`, `@export_tool_button` for editor preview
- Concrete: `PosAnimator`, `LocalPosAnimator`, `LocalRotAnimator`, `MovingPosMax`

### Auto Play & Guidance

- **AutoPlayController**: generates triggers at runtime from GuidanceBox positions
- **GuidanceController**: spawns guidance boxes along the player path
- **NoteReader / BeatmapReader** (editor tools): import `.osu` beatmap files to generate level geometry

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
