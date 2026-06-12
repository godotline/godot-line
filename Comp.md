# Trigger 组件化重构方案

## 核心思路

不引入新的 Behavior 类，直接让现有 Trigger 脚本支持两种模式：
1. **独立模式**：作为 BaseTrigger 直接使用
2. **组件模式**：作为子节点挂载到其他 BaseTrigger 下

## 架构设计

```
BaseTrigger (Area3D) — 容器，收集子 BaseTrigger 并分发
├── Checkpoint (BaseTrigger) — 组件模式：禁用自身碰撞，只响应父级分发
├── CameraTrigger (BaseTrigger) — 组件模式
├── FogTrigger (BaseTrigger) — 组件模式
└── KillPlayer (BaseTrigger) — 组件模式
```

## BaseTrigger 改动

```gdscript
extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true

var _used: bool = false
var _behaviors: Array[BaseTrigger] = []
var _is_behavior: bool = false  # 是否作为组件模式运行

func _ready() -> void:
    # 如果父节点是 BaseTrigger，则以组件模式运行
    if get_parent() is BaseTrigger:
        _is_behavior = true
        monitoring = false      # 禁用碰撞检测
        monitorable = false
        return
    
    body_entered.connect(_on_body_entered)
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child is BaseTrigger:
            _behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
    if one_shot and _used: return
    if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing: return
    if not body is CharacterBody3D: return
    
    _used = true
    triggered.emit(body)
    
    # 分发给所有子组件
    for behavior in _behaviors:
        behavior._on_triggered(body)
    
    # 自身的触发逻辑
    _on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
    pass
```

## 各 Trigger 改动

### 原则

每个 Trigger 脚本保持不变，只是：
1. 可以作为独立 BaseTrigger 使用
2. 可以作为子节点挂载到其他 BaseTrigger（自动进入组件模式）

### Checkpoint

当前代码已经支持，无需改动。作为组件时：
- 父级 BaseTrigger 检测碰撞
- 父级调用 `Checkpoint._on_triggered()`
- Checkpoint 执行状态记录逻辑

### KillPlayer

当前代码已经支持，无需改动。

### Diamond

需要小改：组件模式下不能依赖自身的 `body_entered` 信号。

```gdscript
# 当前问题：Diamond 有自己的碰撞检测和动画播放
# 组件模式下：碰撞由父级处理，Diamond 只负责收集逻辑

func _on_triggered(_body: Node3D) -> void:
    if _collected: return
    _collected = true
    LevelManager.diamond += 1
    # 播放动画（从父节点查找）
    ...
```

## 使用方式

### 独立使用（不变）

```
[KillPlayer] (BaseTrigger)
  └── CollisionShape3D
```

### 组合使用（新）

```
[BaseTrigger] (容器)
  ├── Checkpoint (组件模式)
  ├── CameraTrigger (组件模式)
  ├── FogTrigger (组件模式)
  └── CollisionShape3D
```

编辑器操作：
1. 创建 BaseTrigger 作为容器
2. 添加子节点，选择需要的 Trigger 类型
3. 子 Trigger 自动进入组件模式（禁用碰撞，只响应父级分发）

## 拆分 Checkpoint

当前 Checkpoint 包含太多职责，拆分为多个独立 Trigger：

| 新 Trigger | 职责 |
|------------|------|
| Checkpoint | 只负责记录/恢复玩家状态 |
| CameraTrigger | 只负责相机设置捕获/恢复 |
| FogTrigger | 只负责雾设置捕获/恢复 |
| LightTrigger | 只负责光照设置捕获/恢复 |
| AmbientTrigger | 只负责环境光设置 |
| MaterialColorTrigger | 只负责材质颜色 |

拆分后，完整检查点的组合：
```
[BaseTrigger]
  ├── Checkpoint
  ├── CameraTrigger
  ├── FogTrigger
  └── RevivePosition
```

## 实施步骤

1. 修改 BaseTrigger — 支持组件模式（_is_behavior）
2. 拆分 Checkpoint 为多个独立 Trigger
3. 修改 Diamond 等需要适配的 Trigger
4. 删除 Behavior/ 文件夹（不使用）
5. 更新场景文件

## 优势

1. **无新类**：复用现有 Trigger 脚本
2. **向后兼容**：独立使用的场景无需修改
3. **灵活组合**：编辑器中拖拽组合
4. **渐进迁移**：可以逐步从独立模式迁移到组件模式
