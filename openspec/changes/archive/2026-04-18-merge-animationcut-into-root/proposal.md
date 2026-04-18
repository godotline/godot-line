## Why

Currently, `AnimatorPlayerImportRoot.gd` imports MPM animation files into an `animations_root` node, but there is a separate `#Template\[Scripts]\PortTookits\animationcut.gd` script that splits a single AnimationPlayer's animations into individual AnimationPlayer nodes (one per animation, filtering tracks to keep only the first node's tracks). These two features are disconnected. The user wants to merge them so that after importing MPM files, the import root can also perform the animation splitting operation as part of its workflow.

## What Changes

- Add animation splitting functionality from `animationcut.gd` into `AnimatorPlayerImportRoot.gd`
- Add a new `@export_tool_button` ("Split Animations") that performs the splitting operation on the configured `animations_root` node
- The splitting operation: for each animation in the target AnimationPlayer, create a new AnimationPlayer child node containing only that animation (with tracks filtered to the first node)
- Retain all existing MPM import functionality unchanged

## Capabilities

### New Capabilities

- `animation-split`: Split an AnimationPlayer into individual AnimationPlayer nodes, one per animation, filtering tracks to keep only the first node's tracks

### Modified Capabilities

None — existing MPM import behavior remains unchanged.

## Impact

- `addons/mpm_importer/AnimatorPlayerImportRoot.gd` — new `_split_animations()` method and `@export_tool_button`
- `#Template\[Scripts]\PortTookits\animationcut.gd` — may become redundant (can be removed after merge)
