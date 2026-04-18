## Context

The MPM Importer plugin (`addons/mpm_importer/`) provides animation import from MPM files via `AnimatorPlayerImportRoot.gd`. Separately, a standalone `#Template\[Scripts]\PortTookits\animationcut.gd` EditorScript splits an AnimationPlayer into individual AnimationPlayer nodes (one per animation), filtering tracks to keep only the first node's tracks. The user wants these two features unified in one place.

## Goals / Non-Goals

**Goals:**
- Add animation splitting functionality to `AnimatorPlayerImportRoot.gd` as a new `@export_tool_button`
- Reuse the splitting logic from `animationcut.gd`: for each animation, create a child AnimationPlayer with that single animation, tracks filtered to the first node
- The splitting operates on the node pointed to by `animations_root` (must be an AnimationPlayer)
- Retain all existing MPM import behavior unchanged

**Non-Goals:**
- Changing MPM import logic or parsers
- Modifying `CameraTriggerImportRoot.gd`
- Adding UI dialogs for the split operation (it's a simple button click)

## Decisions

**Decision 1: Integrate as a new `@export_tool_button`**
- Rationale: Matches the existing pattern (`import_action`). No need for a separate script or node.
- Alternative: Keep as a separate EditorScript — rejected because the user wants them merged.

**Decision 2: Operate on `animations_root` node**
- The `animations_root` NodePath already points to the target AnimationPlayer used for imports. Reusing it avoids adding another export variable and keeps the UX simple.
- If `animations_root` is not set or not an AnimationPlayer, the split operation should print a warning and return.

**Decision 3: Reproduce `animationcut.gd` logic faithfully**
- The splitting logic (create one AnimationPlayer per animation, filter tracks to first node, copy AnimationLibrary) will be ported as-is into a `_split_animations()` method.
- The method will be called by the new tool button.

**Decision 4: New nodes under a new Node3D parent**
- All split AnimationPlayer nodes will be added as children of a **new Node3D** node (not as siblings of the original AnimationPlayer).
- The new Node3D will be created under the original AnimationPlayer's parent.
- This keeps the split results organized under a single container node.

## Risks / Trade-offs

- [Risk] If the user points `animations_root` to a node that is not an AnimationPlayer, the split will fail → Mitigation: check type before proceeding, print clear warning.
- [Risk] After splitting, the original AnimationPlayer remains in the scene → This is acceptable; the user can manually delete it if desired.
