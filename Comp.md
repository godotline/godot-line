# Trigger 组件化重构方案

## 目标

将当前单体 Trigger 脚本重构为组件模式，无向后兼容，直接修改现有代码。

## 架构设计

```
BaseTrigger (Area3D) — 纯容器
├── TriggerBehavior (Node3D) — 行为组件基类
│   ├── CheckpointBehavior
│   ├── CameraBehavior
│   ├── FogBehavior
│   ├── LightBehavior
│   ├── AmbientBehavior
│   ├── MaterialColorBehavior
│   ├── KillBehavior
│   ├── JumpBehavior
│   ├── DiamondBehavior
│   ├── TriggerSignalBehavior
│   ├── CrownBehavior
│   ├── HeartCheckpointBehavior
│   └── ...
└── 视觉子节点（粒子、模型、动画）
```

## 核心改动

### 1. BaseTrigger — 纯容器

```gdscript
extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true

var _used: bool = false
var _behaviors: Array[TriggerBehavior] = []

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child is TriggerBehavior:
            _behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
    if one_shot and _used: return
    if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing: return
    if not body is CharacterBody3D: return
    
    _used = true
    triggered.emit(body)
    for behavior in _behaviors:
        behavior.trigger(body)

func refresh_behaviors() -> void:
    _collect_behaviors()
```

### 2. TriggerBehavior — 行为基类

```gdscript
extends Node3D
class_name TriggerBehavior

var _triggered: bool = false
var _checkpoint_index: int = 0

func trigger(body: Node3D) -> void:
    _triggered = true
    _checkpoint_index = LevelManager.checkpoint_count
    _on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
    pass

func _on_revive() -> void:
    pass
```

## 行为组件拆分

### CheckpointBehavior — 检查点核心逻辑

从 `Checkpoint.gd` 拆出，只负责：
- 记录玩家状态（位置、方向、动画进度）
- 记录音乐位置
- revive 时恢复玩家状态

```gdscript
extends TriggerBehavior
class_name CheckpointBehavior

@export var AutoRecord: bool = false
@export var GameTime: float = 0.0
@export var PlayerSpeed: float = 12.0
@export var direction: Direction = Direction.First

signal on_revive

var _track_progress: float = 0.0
var _player_first_direction: Vector3
var _player_second_direction: Vector3

func _on_triggered(body: Node3D) -> void:
    # 记录玩家状态到 LevelManager

func revive() -> void:
    # 恢复玩家状态
```

### CameraBehavior — 相机设置

从 `Checkpoint.gd` 拆出，只负责：
- 捕获相机设置（offset, rotation, fov）
- revive 时恢复相机

```gdscript
extends TriggerBehavior
class_name CameraBehavior

@export var UsingOldCameraFollower: bool = false
@export var camera_new: CameraSettings
@export var camera_old: OldCameraSettings
@export var manual: bool = false

func _on_triggered(body: Node3D) -> void:
    # 捕获当前相机设置

func _on_revive() -> void:
    # 恢复相机设置
```

### FogBehavior — 雾设置

```gdscript
extends TriggerBehavior
class_name FogBehavior

@export var fog: FogSettings
@export var manual: bool = false

func _on_triggered(body: Node3D) -> void:
    # 捕获当前雾设置

func _on_revive() -> void:
    # 恢复雾设置
```

### LightBehavior — 光照设置

```gdscript
extends TriggerBehavior
class_name LightBehavior

@export var light: LightSettings
@export var manual: bool = false

func _on_triggered(body: Node3D) -> void:
    # 捕获当前光照设置

func _on_revive() -> void:
    # 恢复光照设置
```

### AmbientBehavior — 环境光设置

```gdscript
extends TriggerBehavior
class_name AmbientBehavior

@export var ambient: AmbientSettings
@export var manual: bool = false

func _on_triggered(body: Node3D) -> void:
    # 捕获当前环境光设置

func _on_revive() -> void:
    # 恢复环境光设置
```

### MaterialColorBehavior — 材质颜色

```gdscript
extends TriggerBehavior
class_name MaterialColorBehavior

@export var colors_auto: Array[SingleColor] = []
@export var colors_manual: Array[SingleColor] = []

func _on_triggered(body: Node3D) -> void:
    # 应用颜色

func _on_revive() -> void:
    # 恢复颜色
```

### KillBehavior — 已存在

从 `KillPlayer.gd` 拆出，保持现有实现。

### JumpBehavior — 已存在

从 `jump.gd` 拆出，保持现有实现。

### DiamondBehavior — 已存在

从 `Diamond.gd` 拆出，保持现有实现。

### TriggerSignalBehavior — 已存在

从 `Trigger.gd` 拆出，保持现有实现。

### CrownBehavior — 皇冠特效

从 `Crown.gd` 拆出，只负责：
- 皇冠粒子动画
- 皇冠网格缩放/消失

```gdscript
extends TriggerBehavior
class_name CrownBehavior

@export var aura_color: Color
@export var aura_duration: float = 1.25

var _crown_mesh: MeshInstance3D
var _crown_sprite: Sprite3D
var _aura_particles: GPUParticles3D

func _on_triggered(body: Node3D) -> void:
    # 播放皇冠特效
```

### HeartCheckpointBehavior — 爱心旋转

从 `HeartCheckpoint.gd` 拆出，只负责：
- 爱心旋转动画
- 触发时的缩放动画

```gdscript
extends TriggerBehavior
class_name HeartCheckpointBehavior

@export var rotator: Node3D

func _on_triggered(body: Node3D) -> void:
    # 播放爱心旋转动画
```

## 删除的文件

| 文件 | 原因 |
|------|------|
| `Checkpoint.gd` | 拆分为 CheckpointBehavior + CameraBehavior + ... |
| `Crown.gd` | 拆分为 CheckpointBehavior + CrownBehavior |
| `HeartCheckpoint.gd` | 拆分为 CheckpointBehavior + HeartCheckpointBehavior |
| `KillPlayer.gd` | 替换为 KillBehavior |
| `jump.gd` | 替换为 JumpBehavior |
| `Diamond.gd` | 替换为 DiamondBehavior |
| `Trigger.gd` | 替换为 TriggerSignalBehavior |
| `ChangeSpeedTrigger.gd` | 替换为 ChangeSpeedBehavior |
| `ChangeTurn.gd` | 替换为 ChangeTurnBehavior |
| `EventTrigger.gd` | 替换为 EventBehavior |
| `FogColorChanger.gd` | 替换为 FogChangeBehavior |
| `SetActiveTrigger.gd` | 替换为 SetActiveBehavior |
| `SetMaterialColor.gd` | 替换为 MaterialColorBehavior |
| `LocalTeleportTrigger.gd` | 替换为 TeleportBehavior |
| `FakePlayerTransport.gd` | 替换为 FakePlayerTransportBehavior |
| `FakePlayerTrigger.gd` | 替换为 FakePlayerTriggerBehavior |
| `PlayAnimator.gd` | 替换为 PlayAnimatorBehavior |
| `customanimplay.gd` | 替换为 PlayAnimatorBehavior |
| `Pyramid.gd` | 替换为 PyramidBehavior |
| `PyramidTrigger.gd` | 替换为 PyramidBehavior |

## 保留的文件

| 文件 | 原因 |
|------|------|
| `BaseTrigger.gd` | 重构为纯容器 |
| `FallPredictor.gd` | 工具类，不是触发器 |
| `JumpPredictor.gd` | 工具类，不是触发器 |

## 场景文件更新

所有 `.tscn` 文件需要更新：
1. 旧的 `Checkpoint` 节点 → `BaseTrigger` + 子节点 `CheckpointBehavior` + `CameraBehavior` + ...
2. 旧的 `KillPlayer` 节点 → `BaseTrigger` + 子节点 `KillBehavior`
3. 依此类推

## 实施步骤

1. ✅ 重构 BaseTrigger 为纯容器
2. 确保 TriggerBehavior 基类完整
3. 实现 CheckpointBehavior（最复杂）
4. 实现 CameraBehavior / FogBehavior / LightBehavior / AmbientBehavior
5. 实现 MaterialColorBehavior
6. 实现 CrownBehavior / HeartCheckpointBehavior
7. 删除旧的单体 Trigger 脚本
8. 更新所有 .tscn 场景文件
9. 测试验证

## 编辑器使用示例

```
# 简单检查点
[BaseTrigger]
  └── CheckpointBehavior

# 完整检查点（带相机和雾）
[BaseTrigger]
  ├── CheckpointBehavior
  ├── CameraBehavior
  ├── FogBehavior
  └── RevivePosition (Marker3D)

# 皇冠检查点
[BaseTrigger]
  ├── CheckpointBehavior
  ├── CameraBehavior
  ├── CrownBehavior
  ├── Crown (MeshInstance3D)
  ├── CrownSprite (Sprite3D)
  └── FX_CrownAura (GPUParticles3D)

# 杀死玩家
[BaseTrigger]
  └── KillBehavior

# 钻石收集
[BaseTrigger]
  ├── DiamondBehavior
  ├── Diamond (MeshInstance3D)
  ├── AnimationPlayer
  └── RemainParticle (GPUParticles3D)
```
