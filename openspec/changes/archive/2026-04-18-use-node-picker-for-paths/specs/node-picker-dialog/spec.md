## ADDED Requirements

### Requirement: Node picker dialog replaces manual path input
The plugin SHALL use a scene tree dialog for selecting nodes instead of requiring manual text input via LineEdit.

#### Scenario: User selects animations_root via scene tree
- **WHEN** user clicks "设置 animations_root" in the MPM导入 menu
- **THEN** a SceneTreeDialog opens showing the current scene's node tree
- **AND** user can click a node to select it
- **AND** upon selection the path is stored in `animations_root_path`

#### Scenario: User selects default_camera via scene tree
- **WHEN** user clicks "设置 default_camera" in the MPM导入 menu
- **THEN** a SceneTreeDialog opens showing the current scene's node tree
- **AND** user can click a node to select it
- **AND** upon selection the path is stored in `default_camera_path`

#### Scenario: User cancels node selection
- **WHEN** user closes the SceneTreeDialog without selecting a node
- **THEN** the dialog closes and no path is changed

#### Scenario: Selected path is printed to console
- **WHEN** user confirms a node selection
- **THEN** the selected NodePath is printed to the console (e.g., "animations_root 已设置为: Player/Camera3D")
