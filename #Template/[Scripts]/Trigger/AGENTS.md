# Trigger/ — 触发器系统

## 概览

15 个触发器脚本，基于 `BaseTrigger`（Area3D）的继承体系。用于游戏关卡中的交互逻辑。

## 继承结构

```
BaseTrigger (Area3D)
├── Trigger           # 通用触发器，发射 hit_the_line 信号
├── Checkpoint        # 检查点
├── HeartCheckpoint   # 爱心检查点
├── Crown             # 皇冠
├── Diamond           # 钻石
├── Jump              # 跳跃触发
├── ChangeSpeedTrigger # 变速
├── ChangeTurn        # 变向
├── LocalTeleportTrigger # 本地传送
├── FogColorChanger   # 雾色变换
├── Pyramid           # 金字塔
├── PyramidTrigger    # 金字塔触发
├── animplay          # 动画播放
└── customanimplay    # 自定义动画播放
```

## BaseTrigger 模式

```gdscript
extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export var one_shot: bool = false  # 单次触发
@export var debug_mode: bool = false

func _on_triggered(_body: Node3D) -> void:
    pass  # 子类重写
```

- **自动连接**：`_ready()` 中连接 `body_entered` 信号
- **类型过滤**：只响应 `CharacterBody3D`
- **单次触发**：`one_shot` 控制是否可重复触发

## 开发规则

- 新触发器继承 `BaseTrigger`，重写 `_on_triggered()`
- 不要直接连接 `body_entered`，用父类的 `_setup_trigger()`
- 调试时开启 `debug_mode` 查看触发日志