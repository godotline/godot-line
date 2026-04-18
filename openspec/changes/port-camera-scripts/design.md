## Context

Godot 项目 (`godot-line`) 是从 Unity 项目 (`MTPIDM001-Introduction`) 移植而来的。项目中已有早期移植的 Camera 脚本，但与 Unity 源项目的最新版本存在功能差异。Unity 源项目的 Camera 脚本使用 DOTween 实现动画，而 Godot 版本使用 Tween。

现有 Godot Camera 脚本（CameraFollower.gd、CameraTrigger.gd、CameraShakeTrigger.gd）已被多个场景和脚本引用。为了保持向后兼容性，需要将现有脚本重命名为 Old 版本，然后创建新的移植版本。

## Goals / Non-Goals

**Goals:**
- 将 Unity Camera 脚本移植到 Godot GDScript，保持功能一致性
- 保留旧版脚本以供参考和向后兼容
- 更新所有引用旧版脚本的文件，确保项目完整性
- 遵循项目的移植原则：逐文件移植、保留命名、理解意图

**Non-Goals:**
- 不修改 Unity 源项目
- 不优化现有 Camera 功能（仅移植）
- 不修改非 Camera 相关的脚本

## Decisions

### 1. 重命名策略

**决策**: 将现有 Godot Camera 脚本重命名为 Old 版本，然后创建新的移植版本。

**理由**:
- 保留旧版脚本作为参考，方便对照 Unity 源项目
- 避免直接覆盖导致功能丢失
- 符合项目中已存在的 OldCameraSettings.gd 命名模式

**替代方案**:
- 直接覆盖：会导致旧版代码丢失，不推荐
- 创建新目录：会增加目录结构复杂度，不推荐

### 2. 移植顺序

**决策**: 先重命名旧版脚本，再移植新版本。

**理由**:
- 避免命名冲突
- 确保引用更新的一致性
- 符合 Git 工作流，便于追踪变更

### 3. 引用更新策略

**决策**: 使用全局搜索和替换更新所有引用。

**理由**:
- Godot 的 .gd 和 .tscn 文件都包含脚本路径引用
- 需要同时更新 class_name 引用和文件路径引用
- 确保项目完整性

### 4. UID 文件处理

**决策**: 为重命名的脚本创建新的 .uid 文件，保留旧的 .uid 文件。

**理由**:
- Godot 使用 .uid 文件跟踪资源引用
- 重命名文件需要新的 UID
- 保留旧 UID 便于追溯

## Risks / Trade-offs

### 风险 1: 引用更新不完整

**风险**: 可能遗漏某些引用，导致运行时错误。

**缓解措施**:
- 使用全局搜索验证所有引用
- 运行 Godot 项目检查编译错误
- 测试关键场景功能

### 风险 2: 新旧版本功能差异

**风险**: 新移植版本可能与旧版本功能不完全一致。

**缓解措施**:
- 仔细对照 Unity 源项目和 Godot 旧版本
- 保留旧版本作为参考
- 测试新版本功能

### 风险 3: Tween 实现差异

**风险**: Unity DOTween 和 Godot Tween 的 API 和行为可能有差异。

**缓解措施**:
- 理解 DOTween 的意图，在 Godot 中用最地道的方式实现
- 测试动画效果
- 参考 Godot Tween 文档

## Migration Plan

### 步骤 1: 重命名旧版脚本

1. 重命名文件：
   - `CameraFollower.gd` → `OldCameraFollower.gd`
   - `CameraTrigger.gd` → `OldCameraTrigger.gd`
   - `CameraShakeTrigger.gd` → `OldCameraShakeTrigger.gd`
   - `CameraSettings.gd` 已存在 `OldCameraSettings.gd`，无需重复创建

2. 更新 class_name：
   - `CameraFollower` → `OldCameraFollower`
   - `CameraTrigger` → `OldCameraTrigger`
   - `CameraShakeTrigger` → `OldCameraShakeTrigger`
   - `CameraSettings` 已存在 `OldCameraSettings`

3. 更新所有引用：
   - .gd 文件中的 class_name 引用
   - .tscn 文件中的脚本路径引用

### 步骤 2: 移植新版本

1. 逐文件移植 Unity Camera 脚本：
   - `CameraFollower.cs` → `CameraFollower.gd`
   - `CameraTrigger.cs` → `CameraTrigger.gd`
   - `CameraShakeTrigger.cs` → `CameraShakeTrigger.gd`
   - `CameraColorFromSprite.cs` → `CameraColorFromSprite.gd`

2. 遵循移植原则：
   - 逐文件移植，理解功能后重写
   - 保留命名，方便对照
   - 用 Godot 最地道的方式实现

### 步骤 3: 验证

1. 运行 Godot 项目，检查编译错误
2. 测试关键场景功能
3. 验证新旧版本功能一致性

### 回滚策略

如果新版本出现问题，可以：
1. 删除新移植的脚本
2. 恢复旧版脚本的原始名称
3. 恢复所有引用
4. 使用 Git 回滚到移植前状态
