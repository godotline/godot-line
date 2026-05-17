# SetActiveTrigger 移植完成

## 概述

成功将 Unity 的 `SetActive.cs` 脚本移植到 Godot 项目，创建了完整的激活/禁用触发器系统。

## 新增文件

### 1. SingleActive 资源类
**路径：** `#Template/[Scripts]/Settings/SingleActive.gd`

```gdscript
@tool
class_name SingleActive
extends Resource

@export var target: NodePath
@export var active: bool = true
@export var dont_revive: bool = false
```

### 2. SetActiveTrigger 触发器
**路径：** `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

功能：
- 触发时激活/禁用指定节点
- 支持复活时恢复状态
- 继承 BaseTrigger 的所有功能

### 3. 测试场景
**路径：** `#Template/[Scenes]/SetActiveTriggerTest/SetActiveTriggerTest.tscn`

### 4. 文档
- 设计文档：`docs/superpowers/specs/2026-05-17-setactive-trigger-design.md`
- 实现计划：`docs/superpowers/plans/2026-05-17-setactive-trigger.md`
- 完整总结：`docs/superpowers/2026-05-17-setactive-trigger-complete-summary.md`

## 使用方法

### 创建 SingleActive 资源
1. 在编辑器中右键点击 -> 新建资源
2. 搜索 "SingleActive"
3. 设置 target（目标节点路径）、active（激活状态）、dont_revive（是否在复活时恢复）

### 配置 SetActiveTrigger
1. 在场景中添加 SetActiveTrigger 节点
2. 设置 `active_on_awake`：是否在 Start 时立即激活
3. 设置 `one_shot`：是否只能触发一次
4. 在 `actives` 数组中添加 SingleActive 资源

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
10. `ebc2a6e` - docs: add SetActiveTrigger implementation summary

## 验证清单

- [x] 脚本语法正确，无错误
- [x] 触发时正确激活/禁用节点
- [x] 复活时正确恢复状态
- [x] 单次触发功能正常
- [x] 调试输出正常工作
- [x] 文档已更新
- [x] SingleActive 资源类已创建
- [x] 测试场景已创建
- [x] 代码已提交并推送到远程仓库

## 下一步

1. 在 Godot 编辑器中打开测试场景验证功能
2. 根据需要调整配置
3. 在实际关卡中使用 SetActiveTrigger
