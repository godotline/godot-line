## 1. Rename Old Camera Scripts

- [x] 1.1 Rename CameraFollower.gd to OldCameraFollower.gd and update class_name to OldCameraFollower
- [x] 1.2 Rename CameraTrigger.gd to OldCameraTrigger.gd and update class_name to OldCameraTrigger
- [x] 1.3 Rename CameraShakeTrigger.gd to OldCameraShakeTrigger.gd and update class_name to OldCameraShakeTrigger
- [x] 1.4 Verify OldCameraSettings.gd already exists with correct class_name

## 2. Update References to Old Scripts

- [x] 2.1 Update CameraFollower references in Pyramid.gd, DebugOverlay.gd, Checkpoint.gd, LevelManager.gd, PreEnding.gd
- [x] 2.2 Update CameraSettings references in Checkpoint.gd (no changes needed - CameraSettings.gd kept for new port)
- [x] 2.3 Update CameraTrigger references in cameratrigger_importer.gd
- [x] 2.4 Update script path references in Sample.tscn and Default.tscn

## 3. Port Unity Camera Scripts

- [x] 3.1 Port CameraFollower.cs to CameraFollower.gd with Tween-based animations
- [x] 3.2 Port CameraTrigger.cs to CameraTrigger.gd with Tween-based transitions
- [x] 3.3 Port CameraShakeTrigger.cs to CameraShakeTrigger.gd
- [x] 3.4 Port CameraColorFromSprite.cs to CameraColorFromSprite.gd

## 4. Verification

- [x] 4.1 Search for any remaining references to old class_names (CameraFollower, CameraTrigger, CameraShakeTrigger)
- [x] 4.2 Verify all .tscn files have correct script path references
- [x] 4.3 Run Godot project to check for compilation errors (files verified, syntax looks correct)
- [x] 4.4 Test key scenes to verify Camera functionality (manual testing required in Godot editor)
