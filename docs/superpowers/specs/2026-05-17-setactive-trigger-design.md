# SetActive Trigger 移植设计

## 概述

将 Unity 的 `SetActive.cs` 脚本移植到 Godot 项目，创建 `SetActiveTrigger` 脚本，用于在触发时激活/禁用指定节点，并支持复活时恢复状态。

## 设计方案

### 架构选择

**方案：继承 BaseTrigger**

- 继承 `BaseTrigger`（Area3D），符合现有 Trigger 系统架构
- 使用 `@export` 导出配置，支持编辑器可视化设置
- 通过 `LevelManager.add_revive_listener` 注册复活回调
- 遵循项目命名规范：`lowerCamelCase` 变量/函数，`PascalCase` 类名

### 功能需求

1. **触发激活/禁用**
   - 支持多个目标节点配置
   - 每个目标可独立设置激活/禁用状态
   - 支持 `active_on_awake` 选项（Start 时立即激活）

2. **复活恢复**
   - 记录触发前的节点状态
   - 复活时恢复到触发前状态
   - 支持 `dont_revive` 选项（某些节点复活时不恢复）

3. **单次触发**
   - 继承 BaseTrigger 的 `one_shot` 功能

### 数据结构

```gdscript
class_name SetActiveTrigger
extends BaseTrigger

## 单个激活配置
struct SingleActive:
    var target: Node
    var active: bool
    var dont_revive: bool

## 导出配置
@export var active_on_awake: bool = false
@export var actives: Array[Dictionary] = []  # [{target: NodePath, active: bool, dont_revive: bool}]

## 内部状态
var _revive_states: Array[Dictionary] = []  # 记录复活前状态
var _checkpoint_index: int = 0
```

### 核心逻辑

#### 1. 初始化

```gdscript
func _ready() -> void:
    super._ready()  # 调用 BaseTrigger._ready
    
    if active_on_awake:
        _apply_all_actives()
    
    # 注册复活监听
    LevelManager.add_revive_listener(_on_revive)
```

#### 2. 触发处理

```gdscript
func _on_triggered(_body: Node3D) -> void:
    if active_on_awake:
        return  # 已在 Start 时激活，忽略触发
    
    _checkpoint_index = LevelManager.checkpoint_count
    _save_revive_states()
    _apply_all_actives()
```

#### 3. 应用激活/禁用

```gdscript
func _apply_all_actives() -> void:
    for active_config in actives:
        var target = get_node_or_null(active_config.target)
        if target:
            target.visible = active_config.active
            # 如果是 Node3D，也设置 visible
            # 如果需要禁用物理，可额外处理
```

#### 4. 复活恢复

```gdscript
func _on_revive() -> void:
    LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
        for state in _revive_states:
            if not state.dont_revive:
                var target = get_node_or_null(state.target)
                if target:
                    target.visible = state.original_visible
    )
```

### 文件位置

```
#Template/[Scripts]/Trigger/SetActiveTrigger.gd
```

### 与现有系统的集成

1. **BaseTrigger 继承**
   - 使用 `_on_triggered` 虚方法
   - 继承 `one_shot` 单次触发功能
   - 自动连接 `body_entered` 信号

2. **LevelManager 复活系统**
   - 使用 `add_revive_listener` 注册回调
   - 使用 `CompareCheckpointIndex` 检查检查点索引
   - 遵循复活时序（在 `emit_revive` 时调用）

3. **Checkpoint 系统**
   - 与现有检查点系统兼容
   - 不需要修改 Checkpoint.gd

### 编辑器支持

- 使用 `@export` 导出配置，支持编辑器可视化设置
- 支持 `NodePath` 选择目标节点
- 支持布尔值配置激活/禁用状态

### 测试场景

创建测试场景验证：
1. 触发时激活/禁用节点
2. 复活时恢复状态
3. 单次触发功能
4. 多个目标节点配置

## 实现步骤

1. 创建 `SetActiveTrigger.gd` 脚本
2. 继承 `BaseTrigger`
3. 实现 `SingleActive` 结构
4. 实现触发逻辑
5. 实现复活恢复逻辑
6. 创建测试场景验证功能
7. 更新 AGENTS.md 文档

## 风险与注意事项

1. **节点引用问题**
   - 使用 `NodePath` 而非直接引用，避免场景加载顺序问题
   - 使用 `get_node_or_null` 安全获取节点

2. **复活时序**
   - 确保在 `emit_revive` 时正确恢复状态
   - 使用 `CompareCheckpointIndex` 检查检查点索引

3. **性能考虑**
   - 避免每帧更新，只在触发时处理
   - 使用数组存储配置，支持批量操作

## 后续扩展

1. 支持更多节点类型（MeshInstance3D、CollisionShape3D 等）
2. 支持动画过渡效果
3. 支持条件触发（如需要特定道具）
