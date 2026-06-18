# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GodotLine** — A Dancing Line game template for Godot 4.6. Lets users build levels and publish via GodotLineCollection. MIT license. Mobile renderer, Jolt Physics.

**Key companion files**: `Comp.md` (trigger architecture), `TODO.md` (feature parity vs Unity冰焰模板 V4.7.6), `Changelog.md`, `CONTRIBUTING.md`.

## Running / Testing

- Open `project.godot` in Godot Engine 4.6, press F5 to run
- Sample scene: `#Template/[Scenes]/Sample/Sample.tscn`
- Default export scene: `#Template/[Scenes]/DefaultScene/Default.tscn`
- Editor plugin enabled: `addons/template/plugin.cfg` (adds `Template > Tutorial` toolbar menu; opens welcome page on first run)
- Export preset: Windows Desktop only, exports `Default.tscn` with scene filter
- No automated test suite exists; testing is manual via the editor

### Input Reference

| Key | Action |
|-----|--------|
| Mouse click / Space | Turn |

### Editor Tool Workflow

**NoteReader**, **BeatmapReader**, and other `@tool` scripts use the `@export var execute: bool` checkbox pattern:
1. Attach the script to any node in your scene (or a new empty node)
2. Set exported parameters in the Inspector (`.osu` file path, route config, etc.)
3. Tick the **execute** checkbox — the getter always returns `false` but the setter triggers generation
4. Delete the node after generation completes

## Core Gameplay

The player (a `CharacterBody3D`) auto-moves along a **line** in 3D space, switching between two alternating forward directions (`forward1` → `forward2` → `forward1` ...). Each mouse click or Space press toggles the direction. The game is about timing these turns correctly.

- **RoadMaker** (Node3D child of the main line, in `Level/`): procedurally generates floor segments (`StaticBody3D`) between successive player positions in `_physics_process()`. Road segments scale to fill the gap between position changes.
- **AutoPlayController**: generates turn triggers at runtime from `GuidanceBox` positions (data-driven auto-play).
- **Collision layers**: Player (layer 1) collides with BaseFloor (layer 2, `collision_mask`) and BaseWall (layer 3, via an Area3D child with `collision_mask = 4`).

## Core Architecture

### Game State Machine (LevelManager.gd)

All game state lives in `LevelManager` (a static `RefCounted` — **not** a Node). The state machine drives the entire game:

```
Waiting → Playing → Moving → Died → Completed
```

- **Waiting**: initial state, first click transitions to Playing
- **Playing**: normal gameplay, player can turn
- **Moving**: camera animation phase (e.g., level completion sequence)
- **Died**: player hit obstacle, shows game over
- **Completed**: level finished

Key static variables: `GameState`, `main_line_transform`, `revive_position`, `anim_time`, `music_checkpoint_time`, `camera_checkpoint` (dict), `crowns`, `diamond`, `player_direction_index`.

### Singleton Pattern (instance-based)

Many key nodes use `class_name` + `static var instance` + `instance = self` in `_ready()`:
- `Player` (CharacterBody3D)
- `CameraFollower` / `OldCameraFollower` (Node3D)
- `GuidanceController` / `AutoPlayController`
- Static RefCounted singletons: `AudioManager` (audio playback/music control), `ObjectPool` (object reuse, default 256 capacity), `SetLatency` (audio delay/volume persistence via ConfigFile)

### Revive / Checkpoint System

- **Checkpoint** (class_name, extends Area3D, in `Trigger/Single/`): captures full state — player transform, camera (new or old system), fog, light, ambient, material colors, music position, animation time
- **Crown** extends Checkpoint: adds particle effects, costs 1 crown to revive
- **HeartCheckpoint** extends Checkpoint: animated checkpoint with rotation + scale bounce
- On death: `Checkpoint.revive()` restores everything — camera tweens are killed, music is seeked + paused, animation is seeked + paused, state returns to Waiting
- Revive listeners: `LevelManager.add_revive_listener(callable)` / `LevelManager.emit_revive()` — triggers and animators register to reset on revive

### Trigger System — Three Coexistence Modes

The trigger system was progressively refactored. Three modes coexist (detailed in `Comp.md`):

| Mode | Base class | Collision handling | File count | Location |
|------|-----------|-------------------|------------|----------|
| **Pure component** | `extends Node3D` | Parent `BaseTrigger` | ~13 | `Trigger/*.gd` |
| **Self-container** | `extends BaseTrigger` (Area3D) | Inherited from BaseTrigger | ~3 | `Trigger/*.gd`, `Trigger/#TimeLine_ExpandTrack/` |
| **Old mode** | `extends Area3D` | Own `body_entered` | 6 | `Trigger/Single/*.gd` |

#### Mode 1: Pure Component (extends Node3D)

These have a `func trigger(body: Node3D)` method called by the parent **BaseTrigger** node via duck typing (`child.has_method("trigger")`). They do NOT handle collision themselves. Optionally support `func on_exit(body: Node3D)` when parent has `track_exit = true`.

Files: `Jump.gd`, `SetFog.gd`, `EventTrigger.gd`, `PlayAnimator.gd`, `SetActive.gd`, `SetMaterialColor.gd`, `Teleport.gd`, `KillPlayer.gd`, `ChangeDirection.gd`, `Speed.gd`, `JumpPredictor.gd`, `FallPredictor.gd`

**Scene structure**: `[BaseTrigger (Area3D)] → [Component (Node3D)] + [CollisionShape3D]`

#### Mode 2: Self-Container (extends BaseTrigger)

These inherit `BaseTrigger` (so they ARE an Area3D). They override `_on_triggered(body)` for business logic. NOT meant to be children of another BaseTrigger.

Files: `PyramidTrigger.gd`, `PropertyModifierTrigger.gd`, `OldCameraShakeTrigger.gd`

#### Mode 3: Old Mode (extends Area3D)

These manage their own collision via `body_entered` signal. Kept because they fulfill single-responsibility roles where migration adds no value.

Files: `BaseTrigger.gd`, `Checkpoint.gd`, `Crown.gd`, `HeartCheckpoint.gd`, `Gem.gd`, `CameraTrigger.gd`, `OldCameraTrigger.gd`, `CameraShakeTrigger.gd`, `FakePlayerTransport.gd`, `FakePlayerTrigger.gd`

**Key principle**: When adding a new trigger, use **Mode 1** (pure component). Place it as a child of a `BaseTrigger` node. The component needs only a `trigger(body)` method.

### Trigger File Map (current)

| File | Mode | Purpose |
|------|------|---------|
| `Trigger/Single/BaseTrigger.gd` | Old (Area3D) | Container: collision → dispatches to child components |
| `Trigger/Single/Checkpoint.gd` | Old | Full-state capture/restore (~300 lines, most complex trigger) |
| `Trigger/Single/Crown.gd` | Old | Extends Checkpoint, particle animation on collect |
| `Trigger/Single/HeartCheckpoint.gd` | Old | Extends Checkpoint, animated checkpoint |
| `Trigger/Single/Gem.gd` | Old | Collectible gem, `LevelManager.diamond` counting |
| `Trigger/Single/Pyramid.gd` | Old | Pyramid management node |
| `Trigger/Single/PyramidTrigger.gd` | Self-container | Calls Pyramid.trigger(type) |
| `Trigger/Jump.gd` | Pure component | Applies upward velocity, emits `on_player_jump` |
| `Trigger/SetFog.gd` | Pure component | Fog transition via FogSettings + Tween |
| `Trigger/EventTrigger.gd` | Pure component | Multi-target callable invocation, `on_exit` support |
| `Trigger/PlayAnimator.gd` | Pure component | AnimationPlayer playback with revive restore |
| `Trigger/SetActive.gd` | Pure component | Activate/deactivate target nodes, revive restore |
| `Trigger/SetMaterialColor.gd` | Pure component | Material color transition via Tween |
| `Trigger/Teleport.gd` | Pure component | Target/Position teleport modes + turn |
| `Trigger/KillPlayer.gd` | Pure component | Hit/Drowned/Border death modes, no_revive option |
| `Trigger/ChangeDirection.gd` | Pure component | Direction/Turn change modes |
| `Trigger/Speed.gd` | Pure component | Modifies `body.speed`, syncs velocity vector |
| `Trigger/JumpPredictor.gd` | Pure (tool) | Jump trajectory visualization |
| `Trigger/FallPredictor.gd` | Pure (tool) | Fall trajectory visualization |
| `Trigger/FakePlayerTransport.gd` | Old | Teleports FakePlayer |
| `Trigger/FakePlayerTrigger.gd` | Old | Controls FakePlayer turn/direction/state |
| `Trigger/#TimeLine_ExpandTrack/PropertyModifierTrigger.gd` | Self-container | Generic property modifier with Tween + revive |

**Deleted files**: `Trigger.gd` (replaced by BaseTrigger), `customanimplay.gd` (merged into PlayAnimator.gd), `ChangeSpeedTrigger.gd` → `Speed.gd`, `SetActiveTrigger.gd` → `SetActive.gd`

### Camera Systems (two coexist)

- **CameraFollower** (new): Node3D hierarchy (CameraRoot > Rotator > Scale > Camera3D), Tween-based transitions, shake support. Triggered by `CameraTrigger` / `CameraShakeTrigger`.
- **OldCameraFollower** (legacy): simpler follow with slerp/lerp, `RotateMode` enum. Triggered by `OldCameraTrigger` / `OldCameraShakeTrigger`.
- New and old camera are mutually exclusive per checkpoint, selected by `UsingOldCameraFollower` on the Checkpoint node.
- `CameraColorFromSprite`: samples camera background color from a texture.

### Audio System

- **AudioManager** (static RefCounted singleton): `play_clip(clip, volume)` for one-shot SFX (auto-cleanup), `play_track(clip, volume)` for music, `fade_out()` for music. All methods static — `AudioManager.play_clip(...)`.
- **SetLatency**: persists audio latency offset and music volume via `ConfigFile` to `user://` for Bluetooth headphone compensation.
- Music latency: `AudioServer.get_output_latency()` with `_delay_applied` flag guard to prevent double-application on revive.

### Animator System

- **AnimatorBase** (class_name, extends Node3D): base with `trigger_by_time`, `@export_tool_button` for editor preview, revive support
- Concrete: `PosAnimator`, `LocalPosAnimator`, `LocalRotAnimator`, `LocalScaleAnimator`, `MovingPosMax`

### Auto Play, Guidance & FakePlayer

- **AutoPlayController**: generates turn triggers at runtime from GuidanceBox positions
- **GuidanceController**: spawns guidance boxes along the player path
- **SetAutoPlay**: toggles auto-play mode on/off
- **FakePlayer** (class_name): ghost player for path preview. Controlled by `FakePlayerTrigger` (turn/direction/state) and `FakePlayerTransport` (teleport)

### Beatmap Import (.osu → Level Geometry)

Two `@tool` editor-only scripts convert [osu!](https://osu.ppy.sh/) beatmap files into level geometry:

- **NoteReader**: Parses `.osu` hit times → generates road segments (BoxMesh) + optional auto-play Area3D triggers. Configurable speed, road width, colors, trigger size.
- **BeatmapReader**: Parses `.osu` hit times → generates **GuidanceBox** instances. Reads Player parameters from the scene or uses manual overrides.

### MPM Importer & PortTookits

- **`addons/mpm_importer/`**: editor plugin importing `.mpm` format (CameraTrigger, AnimatorPlayer, MovingPosMax).
- **`#Template/[Scripts]/PortTookits/`**: Unity-to-Godot migration helpers — `addcol.gd`, `addtap.gd`, `alladdcol.gd`, `animationcut.gd`, `animfix.gd`, `animloopfix.gd`.

## Key Conventions

- **Naming**: `lowerCamelCase` for vars/funcs, `PascalCase` for class_name, `UPPER_SNAKE_CASE` for constants
- **Tool scripts**: `@tool` annotation used extensively — guard `_ready()` with `Engine.is_editor_hint()`
- **Resources**: Settings stored as `extends Resource` classes: `LevelData`, `CameraSettings`, `FogSettings`, `LightSettings`, `AmbientSettings`, `SingleColor`, `OldCameraSettings`, `SingleActive`, `AuthorInfo`
- **Physics layers**: 1=Player, 2=BaseFloor, 3=BaseWall
- **Player collision**: `collision_mask = 2` (floors), Area3D child has `collision_mask = 4` (walls)
- **Default speed**: 12.0, **Gravity**: Vector3(0, -9.3, 0)
- **Export**: Windows Desktop, `Default.tscn` with scene filter, Jolt Physics on separate thread
- **Gitignore**: `.*/` (hidden dirs), `docs/` — `.godot/`, `.vscode/`, and `docs/superpowers/` plans are not committed

## Template Structure (all game content in `#Template/`)

```
#Template/
  [Scripts]/
    Level/         — Player.gd, LevelManager.gd, AudioManager.gd, ObjectPool.gd, SetLatency.gd, RoadMaker.gd, gameui.gd, death_particle.gd, DebugOverlay.gd, Percentage.gd, FakePlayer.gd
    Trigger/
      Single/          — BaseTrigger.gd, Checkpoint.gd, Crown.gd, HeartCheckpoint.gd, Gem.gd, Pyramid.gd, PyramidTrigger.gd
      (root)           — Jump.gd, ChangeDirection.gd, Speed.gd, KillPlayer.gd, Teleport.gd, SetFog.gd, SetActive.gd, SetMaterialColor.gd, EventTrigger.gd, PlayAnimator.gd, JumpPredictor.gd, FallPredictor.gd, FakePlayerTransport.gd, FakePlayerTrigger.gd
      #TimeLine_ExpandTrack/ — PropertyModifierTrigger.gd
    CameraScripts/ — CameraFollower.gd, OldCameraFollower.gd, CameraTrigger.gd, OldCameraTrigger.gd, CameraShakeTrigger.gd, OldCameraShakeTrigger.gd, CameraColorFromSprite.gd
    Animator/      — AnimatorBase.gd, PosAnimator.gd, LocalPosAnimator.gd, LocalRotAnimator.gd, LocalScaleAnimator.gd, MovingPosMax.gd
    Auto/          — AutoPlay.gd, AutoPlayController.gd, SetAutoPlay.gd
    Guidance/      — GuidanceController.gd, GuidanceBox.gd
    Editor/        — BeatmapReader.gd, NoteReader.gd
    Settings/      — LevelData.gd, CameraSettings.gd, FogSettings.gd, LightSettings.gd, AmbientSettings.gd, OldCameraSettings.gd, SingleColor.gd, SingleActive.gd, AuthorInfo.gd
    PortTookits/   — addcol.gd, addtap.gd, alladdcol.gd, animationcut.gd, animfix.gd, animloop.gd (Unity→Godot migration)
    GUI/           — StartPage.gd
  [Scenes]/        — Sample/Sample.tscn, DefaultScene/Default.tscn
  [Resources]/     — Textures, models, shaders, UI assets, level data .tres files
  [Materials]/.tres files
  [Music]/
```

## Active Development Context

Recent work (June 2026): progressive **component-ization** of the trigger system — extracting behavior from monolithic Area3D triggers into pure `Node3D` components parented under `BaseTrigger`. This is the "Comp:" commit series. The Animator system is also being component-ized (`LocalScaleAnimator` was the latest addition).

A `feature/triggercomp` branch exists on the remote. Pending work tracked in `TODO.md` (P0–P3 priorities vs Unity冰焰模板 V4.7.6). Key gaps: GravityTrigger, PlayAudioClip, SetLight, SetAmbient, FollowPlayer, Henshin system, LoadingPage, LevelUI.

A Trigger Actions refactor plan exists in `docs/superpowers/plans/` (gitignored, not committed) proposing to unify the three modes into `BaseTrigger + TriggerAction child nodes`, but is NOT yet executed — current three-mode coexistence is stable.

## Important Gotchas

- `move_and_slide()` must be called **after** applying gravity but **before** `is_on_floor()` check, or floor detection always returns false
- `@tool` scripts run in editor — `_ready()` may fire before the tree is fully loaded; guard with `Engine.is_editor_hint()`
- When renaming/deleting a script, **must** update `.tscn` references or the scene breaks
- The `LevelManager` is `RefCounted` (not Node), so it has no `_ready()`, no tree access — use `Player.instance.get_tree()` instead
- Crown cost: revive at a checkpoint consumes 1 crown (`LevelManager.crown -= 1`); if no crowns remain, revive fails
- **RoadMaker**: `new_road()` must be called via signal before `_physics_process()` starts tracking, otherwise `road` stays null and nothing generates
- **SetMaterialColor.gd**: part of the checkpoint restore chain — triggers on `revive_notification` to restore material colors
- The `_delay_applied` flag: music delay must only be applied once on revive; guard to prevent re-application
- **New trigger convention**: add behavior as Node3D child of BaseTrigger, implement `func trigger(body: Node3D)`. See `Comp.md` for patterns.
- Scene files reference scripts by path; after moving/renaming a script, all `.tscn` files referencing it break and must be edited manually
- **Jolt Physics** runs on a separate thread — be mindful of thread safety when accessing physics state from non-physics callbacks
- The `@export var execute: bool` with getter returning `false` pattern is used by editor tools as a one-shot trigger
- `AudioManager.play_clip()` creates a new `AudioStreamPlayer` per call (auto-cleans via `finished.connect(queue_free)`) — not yet pooled
