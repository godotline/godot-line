# Trigger 组件化重构方案

## 核心思路

- **BaseTrigger**：纯容器，负责碰撞检测 + 分发
- **所有 Trigger**：纯组件，`extends Node3D`，只能作为 BaseTrigger 的子节点

## BaseTrigger

```gdscript
extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export var one_shot: bool = false
@export var require_playing: bool = true

var _used: bool = false
var _behaviors: Array[Node] = []

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child.has_method("_on_triggered"):
            _behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
    if one_shot and _used: return
    if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing: return
    if not body is CharacterBody3D: return
    
    _used = true
    triggered.emit(body)
    
    for behavior in _behaviors:
        behavior._on_triggered(body)
```

## 各 Trigger 改动

### 改为 extends Node3D

```gdscript
# Before
extends BaseTrigger
class_name Checkpoint

# After
extends Node3D
class_name Checkpoint
```

### 删除碰撞相关代码

- `body_entered` 信号处理
- `monitoring` / `monitorable` 属性
- `_on_body_entered()` 方法
- `one_shot` / `require_playing` 属性
- `_ready()` 中的 `super._ready()` 调用

### 保留

- `_on_triggered(body)` 方法
- 所有业务逻辑

## 需要修改的文件

| 文件 | 改动 |
|------|------|
| BaseTrigger.gd | 改为纯容器 |
| Checkpoint.gd | extends Node3D，删除碰撞代码 |
| Crown.gd | extends Checkpoint（不变） |
| HeartCheckpoint.gd | extends Checkpoint（不变） |
| KillPlayer.gd | extends Node3D，删除碰撞代码 |
| jump.gd | extends Node3D，删除碰撞代码 |
| Diamond.gd | extends Node3D，删除碰撞代码 |
| Trigger.gd | extends Node3D，删除碰撞代码 |
| ChangeSpeedTrigger.gd | extends Node3D，删除碰撞代码 |
| ChangeTurn.gd | extends Node3D，删除碰撞代码 |
| EventTrigger.gd | extends Node3D，删除碰撞代码 |
| FogColorChanger.gd | extends Node3D，删除碰撞代码 |
| SetActiveTrigger.gd | extends Node3D，删除碰撞代码 |
| SetMaterialColor.gd | extends Node3D，删除碰撞代码 |
| LocalTeleportTrigger.gd | extends Node3D，删除碰撞代码 |
| FakePlayerTransport.gd | extends Node3D，删除碰撞代码 |
| FakePlayerTrigger.gd | extends Node3D，删除碰撞代码 |
| PlayAnimator.gd | extends Node3D，删除碰撞代码 |
| customanimplay.gd | extends Node3D，删除碰撞代码 |
| Pyramid.gd | extends Node3D，删除碰撞代码 |
| PyramidTrigger.gd | extends Node3D，删除碰撞代码 |

## 不涉及的文件

- FallPredictor.gd — 工具类，不是触发器
- JumpPredictor.gd — 工具类，不是触发器

## 使用方式

```
# 简单检查点
[BaseTrigger]
  ├── Checkpoint
  └── CollisionShape3D

# 皇冠检查点
[BaseTrigger]
  ├── Crown
  ├── Crown (MeshInstance3D)
  ├── CrownSprite (Sprite3D)
  ├── FX_CrownAura (GPUParticles3D)
  └── CollisionShape3D

# 杀死玩家
[BaseTrigger]
  ├── KillPlayer
  └── CollisionShape3D

# 钻石收集
[BaseTrigger]
  ├── Diamond
  ├── MeshInstance3D
  ├── AnimationPlayer
  ├── RemainParticle (GPUParticles3D)
  └── CollisionShape3D
```
