# SetActiveTrigger 完整实现总结

## 完成的工作

成功将 Unity 的 `SetActive.cs` 脚本移植到 Godot 项目，创建了 `SetActiveTrigger` 触发器和 `SingleActive` 资源类。

## 新增文件

### 1. SingleActive 资源类
**文件位置：** `#Template/[Scripts]/Settings/SingleActive.gd`

```gdscript
@tool
class_name SingleActive
extends Resource

## 单个激活配置类

@export var target: NodePath
@export var active: bool = true
@export var dont_revive: bool = false
```

### 2. SetActiveTrigger 触发器
**文件位置：** `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

功能：
- 触发时激活/禁用指定节点
- 支持复活时恢复状态
- 继承 BaseTrigger 的所有功能

### 3. 测试场景
**文件位置：** `#Template/[Scenes]/SetActiveTriggerTest/SetActiveTriggerTest.tscn`

### 4. 文档
- 设计文档：`docs/superpowers/specs/2026-05-17-setactive-trigger-design.md`
- 实现计划：`docs/superpowers/plans/2026-05-17-setactive-trigger.md`

## 使用方法

### 1. 创建 SingleActive 资源
在编辑器中：
1. 右键点击 -> 新建资源
2. 搜索 "SingleActive"
3. 设置 target（目标节点路径）、active（激活状态）、dont_revive（是否在复活时恢复）

### 2. 配置 SetActiveTrigger
在场景中添加 SetActiveTrigger 节点：
1. 设置 `active_on_awake`：是否在 Start 时立即激活
2. 设置 `one_shot`：是否只能触发一次
3. 在 `actives` 数组中添加 SingleActive 资源

### 3. 测试场景
测试场景包含：
- Player + CameraRoot
- 3 Ground segments
- 2 target MeshInstance3D boxes (red/blue)
- Checkpoint
- 2 SetActiveTrigger 节点

## 设计决策

### 1. 使用 Resource 而非 Dictionary
- 更好的编辑器支持
- 类型安全
- 可复用的配置资源

### 2. 继承 BaseTrigger
- 遵循现有架构
- 自动获得 one_shot、debug_mode 等功能
- 自动连接 body_entered 信号

### 3. 复活恢复机制
- 使用 LevelManager 的复活系统
- 支持 dont_revive 选项
- 使用 CompareCheckpointIndex 检查检查点索引

## 提交记录

1. `4e4234e` - feat: create SetActiveTrigger base structure
2. `42c360c` - feat: implement trigger logic for SetActiveTrigger
3. `86fe32f` - feat: implement revive recovery logic for SetActiveTrigger
4. `5b3d279` - feat: complete SetActiveTrigger implementation with debug support
5. `2c55a7b` - docs: add SetActiveTrigger to trigger system documentation
6. `28036fc` - feat: add SetActiveTrigger test scene and design docs
7. `a0ddab1` - fix: remove duplicate debug_mode definition from SetActiveTrigger
8. `611ae4d` - chore: update project files and add SetActiveTrigger uid
9. `6652310` - feat: add SingleActive resource class and update SetActiveTrigger to use it

## 注意事项

1. **节点引用安全**
   - 使用 `get_node_or_null` 避免空引用
   - 检查节点类型再设置可见性

2. **复活时序**
   - 确保在 `emit_revive` 时正确恢复状态
   - 使用 `CompareCheckpointIndex` 检查检查点索引

3. **性能考虑**
   - 只在触发时处理，避免每帧更新
   - 使用数组存储配置，支持批量操作

4. **编辑器支持**
   - 使用 `@export` 导出配置
   - 支持 `NodePath` 选择目标节点
   - 使用 Resource 类型支持可视化配置
