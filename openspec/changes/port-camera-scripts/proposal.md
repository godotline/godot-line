## Why

Godot 项目中现有的 Camera 脚本（CameraFollower.gd、CameraTrigger.gd、CameraShakeTrigger.gd）是早期移植版本，功能与 Unity 源项目当前版本存在差异。需要将 Unity 源项目的最新 Camera 脚本移植到 Godot，同时保留旧版脚本以供参考和向后兼容。

## What Changes

- 将 Unity 源项目 `Assets/#Template/[Scripts]/Camera/` 中的非 Old 脚本移植到 Godot GDScript
  - `CameraFollower.cs` → 新的 `CameraFollower.gd`
  - `CameraTrigger.cs` → 新的 `CameraTrigger.gd`
  - `CameraShakeTrigger.cs` → 新的 `CameraShakeTrigger.gd`
  - `CameraColorFromSprite.cs` → 新的 `CameraColorFromSprite.gd`
- 将 Godot 项目中现有的 Camera 脚本添加 "Old" 后缀
  - `CameraFollower.gd` → `OldCameraFollower.gd`
  - `CameraTrigger.gd` → `OldCameraTrigger.gd`
  - `CameraShakeTrigger.gd` → `OldCameraShakeTrigger.gd`
  - `CameraSettings.gd` 已存在 `OldCameraSettings.gd`，无需重复创建
- 更新所有引用旧版脚本的文件（.gd、.tscn）

## Capabilities

### New Capabilities

- `camera-port`: 将 Unity Camera 脚本移植到 Godot GDScript，包括 CameraFollower、CameraTrigger、CameraShakeTrigger、CameraColorFromSprite

### Modified Capabilities

- 无

## Impact

- 受影响的脚本文件：
  - `#Template/[Scripts]/Trigger/Pyramid.gd`（引用 CameraFollower）
  - `#Template/[Scripts]/Level/DebugOverlay.gd`（引用 CameraFollower）
  - `#Template/[Scripts]/Trigger/Checkpoint.gd`（引用 CameraFollower、CameraSettings、OldCameraSettings）
  - `#Template/[Scripts]/Level/LevelManager.gd`（引用 CameraFollower）
  - `#Template/[Scripts]/Trigger/PreEnding.gd`（引用 CameraFollower）
  - `addons/mpm_importer/cameratrigger_importer.gd`（引用 CameraTrigger）
- 受影响的场景文件：
  - `#Template/[Scenes]/Sample/Sample.tscn`（引用 CameraFollower.gd、CameraTrigger.gd）
  - `#Template/[Scenes]/DefaultScene/Default.tscn`（引用 CameraFollower.gd）
- 需要为旧版脚本创建新的 .uid 文件
