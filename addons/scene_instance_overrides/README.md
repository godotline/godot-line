# Scene Instance Overrides

Scene Instance Overrides is a Godot 4.7.1 editor plugin for reviewing changes on external scene instances and applying them to the base scene or reverting them locally.

- Author: **bakacandy**
- Version: **1.0.0**
- License: **MIT**

## Installation

1. Copy `addons/scene_instance_overrides/` into the project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Scene Instance Overrides**.

The plugin is editor-only. It adds no autoload or runtime dependency.

## Usage

1. Select an external scene instance or one of its editable children.
2. Open `Overrides (N)` in the Inspector or click the override button in the Scene dock.
3. Select a node or property, then use `Apply` or `Revert`.

`Apply All` and `Revert All` process every supported entry. Inspector properties and locally added scene-tree nodes also provide right-click actions.

After a disk Apply, **Tools > Undo Last Scene Instance Apply** can restore the latest operation while its file hashes still match.

## Editor Settings

Open **Tools > Scene Instance Overrides Settings...**.

- **Show Overrides button for child nodes**: show Inspector and Scene dock buttons on affected children. Default: on.
- **Show override buttons in Scene dock**: enable Scene dock row buttons. Default: on.
- **When the parent scene is unsaved**:
  - **Ask every time**: show the save choice. Default.
  - **Save Parent and Apply**: save the parent scene before Apply.
  - **Apply to Base Only**: keep the parent dirty and apply property overrides only to the base scene.

Added-node overrides cannot use **Apply to Base Only**. They require the parent scene to be saved so the local node record can be removed safely.

The parent-save choice window also lets you change this default for future Applies.

## Supported

- Stored properties on the instance root, except root placement properties.
- Existing child properties edited through Editable Children.
- Locally added regular node subtrees.
- External resource assignments.

The nearest external scene instance is always used as the target.

## Not Supported

- Instance-root Transform or Control layout placement.
- Internal edits to built-in subresources.
- Deleting, renaming, reparenting, or reordering existing base nodes.
- Signal or group changes on existing nodes.
- Persistent signal connections in or targeting locally added node subtrees.
- NodePaths outside the instance.
- Nested PackedScene instances inside added subtrees.
- Imported scenes, inherited scene roots, or base scenes under `res://addons/`.

Unsupported entries are shown for review but cannot be applied or reverted.

## Save Safety

Apply can write the base scene and the parent scene. Commit or back up scene files before using it.

- Dirty base scenes and dirty open dependent scenes block Apply.
- Disk Apply stores backups in `.godot/scene_instance_overrides/` and keeps the latest ten sets.
- Backup restoration is allowed only while the affected files still match their post-Apply hashes.
- Revert changes only the current scene and supports normal editor Undo.
- **Apply to Base Only** keeps unrelated parent edits and Undo history, but does not create an **Undo Last Apply** record.

## Compatibility

- Tested with Godot **4.7.1**.
- Core scanning, Apply, Revert, and backup operations use public editor APIs.
- Scene dock row buttons use a guarded Godot 4.7.1 editor adapter because no public row-button extension API is available. Disable the Scene dock option if a later Godot version changes that UI.

## License

Copyright (c) 2026 bakacandy. See [LICENSE](LICENSE).
