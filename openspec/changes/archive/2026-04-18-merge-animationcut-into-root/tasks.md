## 1. Add animation splitting to AnimatorPlayerImportRoot

- [x] 1.1 Add new `@export_tool_button("Split Animations")` that calls `_split_animations()`
- [x] 1.2 Implement `_split_animations()` method with logic ported from `animationcut.gd`, creating a new Node3D as parent for split AnimationPlayers
- [x] 1.3 Implement `_filter_animation_to_first_node(anim: Animation)` helper method

## 2. Validate and test

- [x] 2.1 Verify the tool button appears in the inspector for AnimatorPlayerImportRoot nodes
- [x] 2.2 Test with a sample AnimationPlayer containing multiple animations
- [x] 2.3 Test edge cases: empty animations_root, non-AnimationPlayer node, empty animation list
