## Why

The Unity C# Player.cs has keyboard shortcuts for restarting (R), quick death (K), and debug mode toggle (D) that improve developer and player workflow. These shortcuts need to be ported to the Godot GDScript Player.gd to maintain feature parity during the engine migration.

## What Changes

- Add keyboard shortcut `R` to restart/reload the current scene (matching Unity `KeyCode.R`)
- Add keyboard shortcut `K` to instantly kill the player during gameplay (matching Unity `KeyCode.K`)
- Add keyboard shortcut `D` to toggle debug information display (matching Unity editor-only `KeyCode.D`)
- All shortcuts use `KeyBoardManager` equivalent in Godot via `_input()` handler or input actions

## Capabilities

### New Capabilities
- `keyboard-shortcuts`: Keyboard input handling for player actions (restart, death, debug toggle)

### Modified Capabilities
- None (no existing spec changes required)

## Impact

- `Player.gd`: Add `_input()` handling for R, K, D keys
- `project.godot`: May need input action definitions for restart/death/debug
- Debug overlay or debug state variable needed for D key toggle
