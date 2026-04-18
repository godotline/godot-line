## Context

The Godot Player.gd currently handles turn input via `_input()` using the "turn" action. The Unity Player.cs has additional keyboard shortcuts managed by `KeyBoardManager`:
- `R` - Restart scene (clears loading state, calls `SceneManager.LoadScene`)
- `K` - Quick death (calls `LevelManager.PlayerDeath` when game is Playing)
- `D` - Debug toggle (editor-only, toggles debug overlay display)

The Godot equivalent needs to replicate this behavior using Godot's input system.

## Goals / Non-Goals

**Goals:**
- Port R/K/D keyboard shortcuts to Player.gd
- Maintain same behavior: R restarts, K kills, D toggles debug (editor-only)
- Use Godot idioms (`_input()`, `Input.is_key_pressed`, `Engine.is_editor_hint()`)

**Non-Goals:**
- Refactoring existing input handling or game state management
- Adding new shortcuts beyond what Unity had
- Changing the restart/death behavior itself (only adding key triggers)

## Decisions

### Decision: Use `_input()` with `InputEventKey` directly
**Rationale**: The existing `Player.gd` already uses `_input()` for turn handling. Adding R/K/D here is consistent. Using Godot input actions would require modifying project.godot and is unnecessary for simple key bindings.

**Alternative considered**: Define input actions in project.godot for restart/death/debug. Rejected because the Unity version uses direct key codes, and these are developer shortcuts that don't need rebinding.

### Decision: Debug toggle stored as instance variable on Player
**Rationale**: The Unity version uses a private `debug` bool on Player. Godot equivalent will use `var debug := false` on Player, toggled by D key. Guarded by `OS.is_debug_build()` — available in debug builds, excluded in release exports (closest to Unity's `#if UNITY_EDITOR` compile-time behavior).

### Decision: Debug overlay as separate CanvasLayer scene
**Rationale**: Unity uses `OnGUI()` for immediate-mode debug drawing. Godot lacks this. A CanvasLayer with Labels is the idiomatic approach — always renders on top, independent of game world.

**Debug overlay contents** (matching Unity OnGUI):
- FPS counter
- Level progress (percentage + seconds elapsed)
- Game state (playing/dead/etc.)
- Player position
- Player rotation
- Camera info (offset, rotation, FOV)

### Decision: Input event handling — use `event is InputEventKey` with `keycode`
**Rationale**: Direct key codes match Unity's `KeyCode.R/K/D` behavior. Using `event.is_action_pressed()` would require defining custom actions in project.godot which is unnecessary overhead for developer shortcuts.

## Risks / Trade-offs

- **Risk**: No existing debug UI infrastructure → **Mitigation**: Create new DebugOverlay.gd as self-contained CanvasLayer
- **Risk**: `Engine.is_editor_hint()` may not perfectly match UNITY_EDITOR behavior → **Mitigation**: Test in both editor and exported builds to verify D key only works in editor
- **Risk**: `_input()` event propagation — RoadMaker also has `_input()` for save action → **Mitigation**: Use `event.pressed` checks to avoid conflicts; R/K/D keys unlikely to collide with save action
