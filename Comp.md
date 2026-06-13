# Trigger 系统架构（当前状态）

## 概述

当前 Trigger 系统有三种共存模式，处于渐进式重构中：

| 模式 | 基类 | 碰撞由谁处理 | 文件数 |
|------|------|-------------|--------|
| **纯组件** | `extends Node3D` | 父节点 BaseTrigger | 7 |
| **自容器** | `extends BaseTrigger` (即 Area3D) | 自身继承 BaseTrigger | 9 |
| **旧模式** | `extends Area3D` | 自身处理 body_entered | 4 (+2 继承 Checkpoint) |

## BaseTrigger（容器）

纯组件模式的容器节点。负责碰撞检测，分发给子组件（通过鸭子类型 `has_method("trigger")` 识别）。

```gdscript
extends Area3D
class_name BaseTrigger

## BaseTrigger - 触发器容器
## 负责碰撞检测和分发给子 TriggerBehavior 组件

signal triggered(body: Node3D)
signal exited(body: Node3D)  # 新增：玩家离开区域信号

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true
@export var track_exit: bool = false  # 新增：是否追踪离开事件

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _behaviors: Array[Node] = []

func _ready() -> void:
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if track_exit:
        if not body_exited.is_connected(_on_body_exited):
            body_exited.connect(_on_body_exited)
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child.has_method("trigger"):
            _behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
    if one_shot and _used:
        if debug_mode:
            print("[BaseTrigger] ", name, " 已触发过")
        return
    if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing:
        return
    if not body is CharacterBody3D:
        return

    _used = true
    if debug_mode:
        print("[BaseTrigger] ", name, " 被触发")

    triggered.emit(body)

    for behavior in _behaviors:
        if is_instance_valid(behavior):
            behavior.trigger(body)

## 新增：离开区域处理
func _on_body_exited(body: Node3D) -> void:
    if not body is CharacterBody3D:
        return
    if debug_mode:
        print("[BaseTrigger] ", name, " 玩家离开")

    exited.emit(body)

    for behavior in _behaviors:
        if is_instance_valid(behavior) and behavior.has_method("on_exit"):
            behavior.on_exit(body)

## 重新收集行为组件
func refresh_behaviors() -> void:
    _collect_behaviors()
```

**关键接口**：BaseTrigger 对子组件调用 `trigger(body)`，通过 `child.has_method("trigger")` 识别子组件。如果 `track_exit=true`，还会对子组件调用 `on_exit(body)`（通过 `child.has_method("on_exit")` 识别）。

## 模式一：纯组件（`extends Node3D`）

这些是纯逻辑组件，不处理碰撞。作为 BaseTrigger 的子节点放置，依赖父节点 BaseTrigger 分发 `trigger(body)` 调用。

**当前使用此模式的文件**：

| 文件 | class_name | 入口方法 | 备注 |
|------|-----------|---------|------|
| `Jump.gd` | — | `trigger(body)` | 施加向上速度，触发 `on_player_jump` 信号；含 `_update_predictor()` 刷新 JumpPredictor/FallPredictor |
| `SetFog.gd` | — | `trigger(body)` | 用 Tween 过渡雾设置，使用 FogSettings 资源 |
| `Pyramid.gd` | `Pyramid` | 无（管理节点） | 由 PyramidTrigger 调用 `pyramid.trigger(type)` |
| `JumpPredictor.gd` | `JumpPredictor` | 无（工具类） | 跳跃轨迹预测可视化 |
| `FallPredictor.gd` | `FallPredictor` | 无（工具类） | 跳跃下落轨迹预测可视化 |
| `EventTrigger.gd` | — | `trigger(body)` + `on_exit(body)` | 可配置多目标/多方法调用，支持 onclick 模式 |
| `PlayAnimator.gd` | — | `trigger(body)` | 播放 AnimationPlayer，支持复活恢复进度 |
| `SetActiveTrigger.gd` | — | `trigger(body)` | 激活/禁用指定节点，支持复活恢复 |
| `customanimplay.gd` | — | `trigger(body)` | 播放 AnimationPlayer 动画，含编辑器预览按钮 |
| `SetMaterialColor.gd` | — | `trigger(body)` | 通过 material_override + Tween 改变材质颜色 |
| `Teleport.gd` | — | `trigger(body)` | 两种传送模式：Target / Position |
| `KillPlayer.gd` | — | `trigger(body)` | 三种死亡模式：Hit / Drowned / Border |
| `ChangeDirection.gd` | — | `trigger(body)` | 两种模式：Direction / Turn |
| `ChangeSpeedTrigger.gd` | — | `trigger(body)` | 修改 `body.speed` |

### Jump.gd 示例

```gdscript
@tool
extends Node3D

signal height_changed(new_height: float)

@export var height: float = 1.0:
    set(value):
        height = value
        height_changed.emit(value)
        if Engine.is_editor_hint():
            _update_predictor()

func _ready() -> void:
    if Engine.is_editor_hint():
        _update_predictor()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
    var character := body as CharacterBody3D
    if character:
        var jump_speed = sqrt(2 * 9.8 * height)
        character.velocity += Vector3(0, jump_speed, 0)
        if Player.instance and Player.instance.has_signal("on_player_jump"):
            Player.instance.on_player_jump.emit()

## 通知子 JumpPredictor/FallPredictor 刷新预览
func _update_predictor() -> void:
    for child in get_children():
        if child is JumpPredictor:
            child._redraw()
        if child is FallPredictor:
            child._draw_line()
```

## 模式二：自容器（`extends BaseTrigger`）

这些触发器继承 BaseTrigger，也即自身就是 Area3D 容器。它们复用 BaseTrigger 的碰撞检测和分发逻辑，通过覆写 `_on_triggered(body)` 实现业务逻辑。

**注意**：此类触发器**不是**纯组件，不能作为其他 BaseTrigger 的子组件使用。它们是独立的 Area3D 节点，自带碰撞体。

**当前使用此模式的文件**：

| 文件 | class_name | 备注 |
|------|-----------|------|
| `PyramidTrigger.gd` | — | 调用父节点 Pyramid 的 `trigger(type)` |
| `#TimeLine_ExpandTrack/PropertyModifierTrigger.gd` | `PropertyModifierTrigger` | 通用属性修改，支持 Tween 和复活恢复 |

### KillPlayer.gd 示例

```gdscript
@tool
extends BaseTrigger

enum DieReason { Hit, Drowned, Border }

@export var reason: DieReason = DieReason.Drowned
@export var no_revive: bool = false
@export var custom_death_clip: AudioStream

func _on_triggered(body: Node3D) -> void:
    if LevelManager.GameState != LevelManager.GameStatus.Playing:
        return
    var player := body as Player
    if player and player.is_live:
        if no_revive:
            LevelManager.checkpoint_count = 0
            LevelManager.crown = 0
        _play_death_sound()
        match reason:
            DieReason.Hit:
                player.die(true, LevelManager.GameStatus.Died)
            DieReason.Drowned, DieReason.Border:
                player.die(false, LevelManager.GameStatus.Moving)
```

## 模式三：旧模式（`extends Area3D`）

这些触发器自行管理碰撞检测（直接连接 `body_entered`），尚未迁移到组件模式。

**当前使用此模式的文件**：

| 文件 | class_name | 碰撞入口 | 备注 |
|------|-----------|---------|------|
| `Gem.gd` | — | `_on_body_entered` | 宝石收集，支持 fake 属性和复活恢复 |
| `Checkpoint.gd` | `Checkpoint` | `_on_checkpoint_body_entered` | 存档点，捕获/恢复全量游戏状态（符合单一职责，无需迁移） |
| `Crown.gd` | — | 继承 Checkpoint | 皇冠收集动画（符合单一职责，无需迁移） |
| `HeartCheckpoint.gd` | — | 继承 Checkpoint | 带动画存档点（符合单一职责，无需迁移） |
| `FakePlayerTransport.gd` | `FakePlayerTransport` | `_on_body_entered` | 传送 FakePlayer（半成品，暂时忽略） |
| `FakePlayerTrigger.gd` | `FakePlayerTrigger` | `_on_body_entered` | 控制 FakePlayer 转向/方向/状态（半成品，暂时忽略） |

**注**：Gem、Checkpoint、Crown、HeartCheckpoint 均符合单一职责，无需迁移到组件模式。FakePlayer 相关触发器为半成品，暂不处理。旧模式触发器已全部确认，Trigger 系统重构完成。

### Checkpoint.gd 复杂度说明

Checkpoint 是面积最大、逻辑最复杂的旧模式触发器（~300 行）。它：
- 捕获摄像机（新旧两套系统）、雾、光、环境光、材质颜色
- 保存玩家方向、动画进度、重力
- `revive()` 方法恢复全部状态，包括音乐 seek + pause、动画 seek + pause
- 通过 `LevelManager.save_checkpoint()` / `load_checkpoint_to_main_line()` 持久化位置

迁移 Checkpoint 需要特别谨慎，因为 Crown、HeartCheckpoint 都继承它。

## 组件约定

BaseTrigger 通过 `child.has_method("trigger")` 识别子组件（鸭子类型），并调用 `trigger(body)`。子组件需定义：

```gdscript
func trigger(body: Node3D) -> void:
    pass
```

如果需要处理离开事件（`track_exit=true`），子组件还需定义：

```gdscript
func on_exit(body: Node3D) -> void:
    pass
```

## 场景结构示例

### 纯组件模式（模式一）

```
# 跳跃触发器
[BaseTrigger]
  ├── Jump (Node3D)
  └── CollisionShape3D

# 雾色变化
[BaseTrigger]
  ├── SetFog (Node3D)
  └── CollisionShape3D

# 事件触发器（需要 track_exit=true）
[BaseTrigger (track_exit=true)]
  ├── EventTrigger (Node3D)
  └── CollisionShape3D

# 动画播放触发器
[BaseTrigger]
  ├── PlayAnimator (Node3D)
  └── CollisionShape3D
```

### 自容器模式（模式二）

```
# 死亡区域 — 自身就是完整触发器
[KillPlayer (extends BaseTrigger)]
  └── CollisionShape3D

# 传送触发器（纯组件模式）
[BaseTrigger]
  ├── Teleport (Node3D)
  └── CollisionShape3D

# 金字塔 — 管理节点 + 子触发器组合
[Pyramid (Node3D)]
  ├── Left (MeshInstance3D)
  ├── Right (MeshInstance3D)
  ├── PyramidTrigger (extends BaseTrigger)  ← 子触发器
  │   └── CollisionShape3D
  └── PyramidTrigger2 (extends BaseTrigger) ← 子触发器
      └── CollisionShape3D
```

### 旧模式（模式三）

```
# 存档点 — 自身处理碰撞
[Checkpoint (extends Area3D)]
  ├── RevivePosition (Node3D)
  ├── MeshInstance3D
  └── CollisionShape3D

# 宝石 — 自身处理碰撞
[Gem (extends Area3D)]
  ├── MeshInstance3D
  ├── AnimationPlayer
  ├── RemainParticle (GPUParticles3D)
  └── CollisionShape3D
```

## 已删除的文件

| 文件 | 说明 |
|------|------|
| `Trigger.gd` | 原基础触发器（`hit_the_line` 信号），已被 BaseTrigger 替代 |
| `jump.gd` | 已重构为 `Jump.gd`（从 Area3D 迁移到 Node3D 纯组件） |
