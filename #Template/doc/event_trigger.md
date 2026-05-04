# EventTrigger 使用文档

## 概述

`EventTrigger` 是一个通用触发器节点，当玩家进入其碰撞区域时发射 `triggered` 信号。支持三种触发模式，适用于需要精确控制触发时机的场景。

**脚本路径：** `#Template/[Scripts]/Trigger/EventTrigger.gd`
**继承：** `Area3D`

---

## 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `invoke_on_awake` | `bool` | `false` | 场景加载时立即触发（一次性） |
| `invoke_on_click` | `bool` | `false` | 玩家进入区域后，等待点击转弯才触发 |

---

## 触发模式

### 1. 默认模式（碰撞触发）

两个属性都为 `false` 时，玩家进入碰撞区域立即触发。

```
玩家进入 Area3D → triggered.emit()
```

### 2. Awake 模式

`invoke_on_awake = true` 时，场景加载时立即触发，忽略碰撞。

```
_ready() → triggered.emit()
```

### 3. Click 模式

`invoke_on_click = true` 时，玩家进入区域后等待点击转弯才触发。离开区域则取消等待。

```
玩家进入 Area3D → 等待玩家点击转弯 → triggered.emit()
玩家离开 Area3D → 取消等待
```

---

## 复活重置

触发后自动注册复活监听，记录当前检查点索引 `_trigger_index`。

玩家死亡复活时，通过 `LevelManager.CompareCheckpointIndex` 校验：

- 复活点在触发器**之后**（已过去）→ **不重置**，保持 `_invoked = true`
- 复活点在触发器**之前或相同** → **重置** `_invoked = false`，允许再次触发

```
检查点A → EventTrigger1 (index=0) → Animator1
检查点B → EventTrigger2 (index=1) → Animator2

玩家在检查点B复活：
  EventTrigger1: index=0 < checkpoint_count → 不重置
  EventTrigger2: index=1 >= checkpoint_count → 重置
```

AnimatorBase 同理，`_trigger_index` 记录触发时的检查点索引，复活时校验后决定是否重置 `_finished`。

---

## 连接 AnimatorBase

在 Godot 编辑器中，选中 `EventTrigger` 节点，在信号面板将 `triggered` 信号连接到 `AnimatorBase` 节点，选择 `Trigger()` 方法。

```
EventTrigger (Area3D)
	│
	│ signal: triggered
	▼
AnimatorBase.Trigger()
	│
	▼
物体开始 Tween 动画
```

### 示例场景结构

```
Level
├── EventTrigger          ← Area3D + EventTrigger.gd
│   └── CollisionShape3D  ← 碰撞区域
├── MovingPlatform        ← Node3D + LocalPosAnimator.gd
└── Player
```

**Inspector 设置：**

1. `EventTrigger` 节点 → 配置触发模式
2. `EventTrigger` 信号面板 → `triggered` 连接到 `MovingPlatform` 的 `Trigger()`
3. `MovingPlatform` → 配置 `start_value`、`end_offset`、`duration`

---

## 完整触发链

```
┌─────────────────────────────────────────────────────┐
│  时间触发（AnimatorBase 自身）                         │
│  triggered_by_time = true                            │
│  _process() 检查音乐时间 > trigger_time              │
│         │                                            │
│         ▼                                            │
│  AnimatorBase.Trigger()                              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  事件触发（EventTrigger → AnimatorBase）              │
│  玩家进入碰撞区域                                     │
│         │                                            │
│         ▼                                            │
│  EventTrigger.triggered.emit()                       │
│         │                                            │
│         ▼ (Inspector 信号连接)                       │
│  AnimatorBase.Trigger()                              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Trigger.gd → AnimatorBase（旧方式兼容）              │
│  玩家进入碰撞区域                                     │
│         │                                            │
│         ▼                                            │
│  Trigger.hit_the_line.emit()                         │
│         │                                            │
│         ▼ (代码连接或 Inspector)                      │
│  AnimatorBase.Trigger()                              │
└─────────────────────────────────────────────────────┘
```

---

## 与其他触发器的区别

| 触发器 | 信号 | 特点 |
|--------|------|------|
| `EventTrigger` | `triggered` | 三种模式，支持复活重置 |
| `Trigger` | `hit_the_line` | 简单碰撞触发，无模式选择 |
| `BaseTrigger` | `triggered(body)` | 基类，传递 body 参数 |

---

## 代码中手动连接

```gdscript
# 在场景脚本中
@onready var event_trigger: EventTrigger = $EventTrigger
@onready var animator: AnimatorBase = $MovingPlatform

func _ready() -> void:
	event_trigger.triggered.connect(animator.Trigger)
```
