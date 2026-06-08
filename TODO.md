# GodotLine TODO — 冰焰模板 V4.7.6 对照表（修订版）

与 `D:\Code\dl\MTPIDM001-Introduction\Assets\#Template\`（Unity 冰焰模板 V4.7.6）逐项对比。

---

## 一、功能对齐总览

| 优先级 | 分类 | 功能 | Unity | Godot | 备注 |
|--------|------|------|:-----:|:-----:|------|
| P0 | Trigger | KillPlayer | ✓ | ✓ | 接触即死触发器（落水/出图/撞墙三种模式） |
| P0 | Level | AudioManager | ✓ | ✓ | 音乐管理、音效池、音量控制、淡入淡出 |
| P0 | Trigger | Teleport | ✓ | ✓ | Target/Position/Offset 三种模式，ForceCameraFollow，Turn 转向 |
| P0 | Trigger | SetActive | ✓ | ✓ | `SetActiveTrigger.gd` 已验证 revive 恢复逻辑 |
| P1 | Level | FakePlayer 系统 | ✓ | ✓ | 假线（含 FakePlayer.cs + FakePlayerTransport + FakePlayerTrigger） |
| P1 | Trigger | FakePlayerTrigger | ✓ | ✓ | 三种模式：Turn / ChangeDirection / SetState |
| P1 | Trigger | GravityTrigger | ✓ | ✗ | **未实现** — 更改场景重力 |
| P1 | Trigger | PlayAudioClip | ✓ | ✗ | **未实现** — 触发播放音效（支持 Trigger 和事件两种模式） |
| P1 | Trigger | FadeOutMusic | ✓ | ✗ | **未实现** — 淡出背景音乐（AudioManager 已有 fade_out，缺 Trigger 封装） |
| P1 | Trigger | SetFog / FogTrigger | ✓ | ⚠️ | `FogColorChanger.gd` 是 Node3D 非 Area3D，缺少 Trigger 模式；缺 Start/End 动画 |
| P1 | Trigger | SetLight | ✓ | ✗ | **未实现** — 更改定向光源（Rotation/Color/Intensity/ShadowStrength） |
| P1 | Trigger | SetAmbient | ✓ | ✗ | **未实现** — 更改环境光源类型 |
| P1 | Trigger | SetImageColor | ✓ | ✗ | **未实现** — 更改 UI Image 颜色 |
| P1 | Trigger | Gem / Crystal | ✓ | ⚠️ | 有 `Gem.tscn` 和 `Diamond.gd`，但缺少 Crystal 和 Gem 的自定义模型/效果路径 |
| P1 | Level | FollowPlayer | ✓ | ✗ | **未实现** — 物体跟随玩家的辅助组件 |
| P1 | Animator | LocalScaleAnimator | ✓ | ✗ | **未实现** — 缩放时间动画 |
| P1 | Animator | TimerLight (定向光源) | ✓ | ✗ | **未实现** — 时间驱动的光源动画 |
| P1 | Animator | TimerAmbient (环境光) | ✓ | ✗ | **未实现** — 时间驱动的环境光动画 |
| P1 | Animator | TimerFog (雾气) | ✓ | ⚠️ | `FogColorChanger.gd` 只改颜色，缺少 Start/End 动画 |
| P1 | Animator | TimerImageColor | ✓ | ✗ | **未实现** — 时间驱动的 Image 颜色动画 |
| P2 | GUI | StartPage | ✓ | ✓ | 开始页面 UI（含 About 面板动画） |
| P2 | GUI | LoadingPage | ✓ | ✗ | **未实现** — 加载页面 UI |
| P2 | GUI | LevelUI | ✓ | ✗ | **未实现** — 关卡内 UI（包含游戏内信息显示） |
| P2 | GUI | SetQuality | ✓ | ⚠️ | UI 完成，信号接口暴露，待接入 QualitySettings |
| P2 | GUI | SetLatency | ✓ | ✓ | UI 完成，延迟语义对齐 Unity StartGame，ConfigFile 持久化 |
| P2 | GUI | KeyBoardFunctionsDisplay | ✓ | ✓ | 顶部提示栏 "R/K/D" 快捷键显示 |
| P2 | GUI | SettingItem 排版优化 | — | ✓ | 两行排版（标题在上，◄ 数值 ► 在下），◄/► 箭头符号 |
| P2 | GUI | GuidanceEnabled | ✓ | ✗ | **未实现** — 引导线启用按钮（AutoPlay 开关已有，缺 UI 按钮） |
| P2 | GUI | HideCanvas / ShowCanvas | ✓ | ✓ | About 面板动画显隐（ShowCanvas/HideCanvas 等效） |
| P2 | Level | ObjectPool | ✓ | ✓ | 通用对象池（线身、粒子等复用），含 TailPool 256 容量 |
| P2 | Trigger | ParticleSystemPlay | ✓ | ✗ | **未实现** — 触发位置播放粒子效果 |
| P2 | Trigger | Henshin | ✓ | ✗ | **未实现** — 变身（模型/材质切换） |
| P2 | Trigger | AchievementTrigger | ✓ | ✗ | **未实现** — 成就系统触发器 |
| P2 | Trigger | ACChanger | ✓ | ✗ | **未实现** — 音频配置切换（需先有 AudioManager） |
| P2 | Level | TimeScale | ✓ | ✗ | **未实现** — 全局时间倍速控制（仅编辑器可用） |
| P2 | Level | ActiveByQuality | ✓ | ✗ | **未实现** — 根据画质等级启用/禁用对象 |
| P2 | Level | DisableInPlaymode | ✓ | ✗ | **未实现** — 运行时隐藏编辑器辅助对象 |
| P2 | Editor | TrailRenderer (路径高亮) | ✓ | ✗ | **未实现** — 编辑器内路径高亮 + 点击时间显示 |
| P2 | Player | C 键输出音乐时间 | ✓ | ✗ | **未实现** — 编辑器快捷键，在控制台输出当前音乐时间 |
| P2 | Player | 事件系统 | ✓ | ✓ | Player.gd 信号含 OnGameAwake, OnPlayerStart, OnChangeDirection, OnLeaveGround, OnTouchGround, OnGameOver, OnGetGem, OnPlayerJump |
| P1 | Player | noDeath 标志 | ✓ | ✗ | **未实现** — Unity KillPlayer 检查 player.noDeath 跳过死亡，Godot 无此字段 |
| P1 | Player | Tail 对象池 | ✓ | ✓ | TAIL_POOL_SIZE=256，循环复用 MeshInstance3D |
| P1 | Player | Henshin 变身系统 | ✓ | ✗ | **未实现** — 双材质切换（characterMaterial/alphaMaterial） |
| P1 | Player | playedAnimators / playedTimelines | ✓ | ✗ | **未实现** — Unity 跟踪已播放动画器/时间线用于存档恢复 |
| P2 | Player | sceneCamera / sceneLight 引用 | ✓ | ✗ | **未实现** — Unity Player 持有直接引用，Godot 靠 get_first_node_in_group 查找 |
| P2 | Player | musicVolume 独立字段 | ✓ | ✓ | `music_volume` 和 `music_delay` 已添加到 Player.gd |
| P2 | Player | Editor 工具 | ✓ | ✗ | **未实现** — GetStartPosition 按钮、OnDrawGizmos 方向绘制、GetFrame FPS 计数 |
| P3 | Level | PlayerCubes | ✓ | ✗ | 玩家轨迹方块（Godot 用 road mesh 替代） |
| P3 | Trigger | TTFCheckPoint 系列 | ✓ | ✗ | 主题化存档点（TTFCheckPoint + TTFCheckPointGem + TTFCheckPointTrigger） |
| P3 | Assets | 3D 模型 / 材质 | 28+ 模型, 35 材质 | 3 模型, 5 材质 | 水、自然包、云、环、BonusBox、Fragment、Heart 等 |
| P3 | Assets | 音乐文件 | 4 首 | 1 首 | Phigros_Intro, SampleTrack, Shake_It_Up, nevva |
| — | 系统 | BaseTrigger | ✓ | ✓ | Area3D 触发器基类，含 one_shot、signal |
| — | 系统 | Trigger | ✓ | ✓ | 通用触发器 |
| — | 系统 | Checkpoint | ✓ | ✓ | 检查点（全状态记录 + 恢复） |
| — | 系统 | CrownCheckpoint | ✓ | ✓ | 皇冠检查点（粒子特效） |
| — | 系统 | HeartCheckpoint | ✓ | ✓ | 爱心检查点（旋转动画） |
| — | 系统 | Jump | ✓ | ✓ | 跳跃触发器 |
| — | 系统 | ChangeTurn / ChangeDirection | ✓ | ✓ | 改变线转向方向 |
| — | 系统 | ChangeSpeed / Speed | ✓ | ✓ | 改变线速度 |
| — | 系统 | EventTrigger | ✓ | ✓ | 事件分发触发器 |
| — | 系统 | PlayAnimator / CustomAnimPlay | ✓ | ✓ | 播放帧动画 |
| — | 系统 | SetMaterialColor | ✓ | ✓ | 材质颜色动画 |
| — | 系统 | Pyramid / PyramidTrigger | ✓ | ✓ | 金字塔关卡结尾系统 |
| — | 系统 | FallPredictor / JumpPredictor | ✓ | ✓ | 下落/跳跃轨迹预测 |
| — | 系统 | CameraFollower | ✓ | ✓ | 新相机跟随系统（Tween 驱动） |
| — | 系统 | OldCameraFollower | ✓ | ✓ | 旧相机跟随系统（lerp 驱动） |
| — | 系统 | CameraTrigger | ✓ | ✓ | 视角变换触发器 |
| — | 系统 | OldCameraTrigger | ✓ | ✓ | 旧视角变换触发器 |
| — | 系统 | CameraShakeTrigger | ✓ | ✓ | 相机震动 |
| — | 系统 | OldCameraShakeTrigger | ✓ | ✓ | 旧相机震动 |
| — | 系统 | CameraColorFromSprite | ✓ | ✓ | 从贴图采样相机背景色 |
| — | 系统 | AnimatorBase | ✓ | ✓ | 时间动画基类 |
| — | 系统 | LocalPosAnimator | ✓ | ✓ | 位移时间动画 |
| — | 系统 | LocalRotAnimator | ✓ | ✓ | 旋转时间动画 |
| — | 系统 | PosAnimator | ✓ | ✓ | 全局位移动画 |
| — | 系统 | MovingPosMax | ✓ | ✓ | 路径点序列动画 |
| — | 系统 | LevelData | ✓ | ✓ | 关卡信息资源文件 |
| — | 系统 | CameraSettings / OldCameraSettings | ✓ | ✓ | 相机配置 |
| — | 系统 | FogSettings | ✓ | ✓ | 雾气配置 |
| — | 系统 | LightSettings | ✓ | ✓ | 光源配置 |
| — | 系统 | AmbientSettings | ✓ | ✓ | 环境光配置 |
| — | 系统 | SingleColor | ✓ | ✓ | 材质颜色覆盖资源 |
| — | 系统 | GuidanceBox / GuidanceController | ✓ | ✓ | 引导线系统 |
| — | 系统 | AutoPlay / AutoPlayController | ✓ | ✓ | 自动播放系统 |
| — | 系统 | BeatmapReader / NoteReader | ✓ | ✓ | .osu 谱面导入 |
| — | 系统 | Player | ✓ | ✓ | 玩家角色（CharacterBody3D） |
| — | 系统 | LevelManager | ✓ | ✓ | 游戏状态机 |
| — | 系统 | Percentage | ✓ | ✓ | 百分比标记 |
| — | 系统 | RoadMaker | ✓ | ✓ | 路径生成 |
| — | 系统 | GameUI | ✓ | ✓ | 游戏结束 UI（皇冠/钻石统计） |
| — | 系统 | DeathParticle | ✓ | ✓ | 死亡粒子 |
| — | 系统 | DebugOverlay | ✓ | ✓ | 调试信息覆盖层 |
| — | 系统 | Diamond | ✓ | ✓ | 钻石收集物 |

**图例**: ✓ = 已完成, ⚠️ = 需验证/部分完成/命名不同, ✗ = 未实现

---

## 二、优先级说明

| 优先级 | 含义 | 工作量估计 |
|--------|------|-----------|
| **P0** | 功能缺失导致关卡制作受限或流程卡死 | 小 |
| **P1** | 重要功能，模板核心差异 | 中 ~ 大 |
| **P2** | 增强体验和完善性，非必须 | 中 |
| **P3** | 素材资产补充 | 视素材来源而定 |
| **—** | 已对齐，无需处理 | 0 |

---

## 三、完成统计

| 类别 | 总计 | ✓ 已完成 | ⚠️ 部分/待验证 | ✗ 未实现 |
|------|:---:|:--------:|:-------------:|:--------:|
| Trigger | 28 | 13 | 3 | 12 |
| Level | 10 | 5 | 0 | 5 |
| Animator | 6 | 3 | 1 | 2 |
| GUI | 9 | 5 | 2 | 2 |
| Player | 9 | 3 | 0 | 6 |
| Editor | 1 | 0 | 1 | 0 |
| Assets | 2 | 0 | 0 | 2 |
| **已对齐系统** | 25 | 25 | 0 | 0 |

---

## 四、Trigger 节点组合模式重构计划（新增）

### 4.1 现状问题

当前 Trigger 系统存在以下架构问题：

1. **继承爆炸**：每个功能一个脚本，继承链单一（BaseTrigger → 具体Trigger），功能无法复用组合
2. **职责混杂**：`Checkpoint` 同时处理玩家状态、相机、雾、光照、环境光、材质颜色，类过于庞大
3. ** revive 逻辑重复**：几乎每个 Trigger 都手写 `_on_revive` + `CompareCheckpointIndex`，样板代码多
4. **非 Trigger 脚本混入 Trigger 目录**：`FogColorChanger.gd` 是 `Node3D` 而非 `Area3D`，`Diamond.gd` 直接继承 `Area3D` 而非 `BaseTrigger`
5. **扩展困难**：新增一个"触发时改重力+播放音效+震屏"的组合需求，需要新建一个脚本或改多个脚本

### 4.2 目标架构：节点组合模式（Component Pattern）

将 Trigger 拆分为**触发器主体（BaseTrigger）+ 行为组件（TriggerBehavior）**的组合结构：

```
BaseTrigger (Area3D)
├── CollisionShape3D
├── TriggerBehavior_A  (Node, 如 KillBehavior)
├── TriggerBehavior_B  (Node, 如 ShakeBehavior)
├── TriggerBehavior_C  (Node, 如 PlayAudioBehavior)
└── ...
```

一个 `BaseTrigger` 节点下挂载多个 `TriggerBehavior` 子节点，触发时依次调用所有行为组件。

### 4.3 核心抽象

#### 4.3.1 `TriggerBehavior` 基类

```gdscript
class_name TriggerBehavior
extends Node

## 触发行为组件基类
## 挂载在 BaseTrigger 下，由 BaseTrigger 统一调度

@export_group("基础设置")
@export var enabled: bool = true
@export var one_shot: bool = false  ## 是否只执行一次（跨复活不复位）
@export var dont_revive: bool = false  ## 复活时是否不恢复状态

var _used: bool = false
var _checkpoint_index: int = -1

## 由 BaseTrigger 在 body_entered 时调用
func execute(body: Node3D) -> void:
    if not enabled:
        return
    if one_shot and _used:
        return
    _used = true
    _checkpoint_index = LevelManager.checkpoint_count
    _on_execute(body)
    if not dont_revive and not Engine.is_editor_hint():
        LevelManager.add_revive_listener(_on_revive)

## 子类实现具体逻辑
func _on_execute(_body: Node3D) -> void:
    pass

## 复活回调
func _on_revive() -> void:
    LevelManager.remove_revive_listener(_on_revive)
    LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
        _used = false
        _on_reset()
    )

## 子类实现复位逻辑
func _on_reset() -> void:
    pass

func _exit_tree() -> void:
    if not Engine.is_editor_hint():
        LevelManager.remove_revive_listener(_on_revive)
```

#### 4.3.2 `BaseTrigger` 改造

```gdscript
extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true  ## 是否只在 Playing 状态下触发

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _signal_connected: bool = false
var _behaviors: Array[TriggerBehavior] = []

func _ready() -> void:
    _setup_trigger()
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child is TriggerBehavior:
            _behaviors.append(child)

func _setup_trigger() -> void:
    if not _signal_connected:
        if not body_entered.is_connected(_on_body_entered):
            body_entered.connect(_on_body_entered)
        _signal_connected = true

func _on_body_entered(body: Node3D) -> void:
    if one_shot and _used:
        return
    if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing:
        return
    if not body is CharacterBody3D:
        return
    
    _used = true
    if debug_mode:
        print("[BaseTrigger] ", name, " 被触发")
    
    triggered.emit(body)
    
    ## 依次调用所有行为组件
    for behavior in _behaviors:
        if is_instance_valid(behavior):
            behavior.execute(body)
    
    _on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
    pass
```

### 4.4 行为组件清单（需新建）

| 组件名 | 功能 | 对应现有脚本 | revive 恢复 |
|--------|------|-------------|------------|
| `KillBehavior` | 杀死玩家 | KillPlayer.gd | 否（死亡后自动重置） |
| `ChangeSpeedBehavior` | 改变玩家速度 | ChangeSpeedTrigger.gd | 是（恢复原始速度） |
| `ChangeTurnBehavior` | 改变玩家转向 | ChangeTurn.gd | 是（恢复方向） |
| `JumpBehavior` | 施加跳跃力 | jump.gd | 否 |
| `TeleportBehavior` | 传送玩家 | LocalTeleportTrigger.gd | 是（恢复位置） |
| `SetActiveBehavior` | 激活/禁用节点 | SetActiveTrigger.gd | 是（恢复可见性） |
| `PlayAudioBehavior` | 播放音效 | **新增** | 否 |
| `FadeOutMusicBehavior` | 淡出音乐 | **新增** | 是（恢复音量） |
| `CameraTriggerBehavior` | 新相机变换 | CameraTrigger.gd | 是（恢复相机参数） |
| `OldCameraTriggerBehavior` | 旧相机变换 | OldCameraTrigger.gd | 是 |
| `CameraShakeBehavior` | 相机震动 | CameraShakeTrigger.gd | 是（停止震动） |
| `FogChangeBehavior` | 雾效变化 | FogColorChanger.gd | 是（恢复雾参数） |
| `LightChangeBehavior` | 定向光变化 | **新增** | 是 |
| `AmbientChangeBehavior` | 环境光变化 | **新增** | 是 |
| `MaterialColorBehavior` | 材质颜色变化 | SetMaterialColor.gd | 是 |
| `GravityChangeBehavior` | 重力变化 | **新增** | 是（恢复重力） |
| `ParticlePlayBehavior` | 播放粒子 | **新增** | 否 |
| `EventInvokeBehavior` | 调用目标方法 | EventTrigger.gd | 是（重置调用状态） |
| `AnimatorPlayBehavior` | 播放 AnimationPlayer | PlayAnimator.gd / customanimplay.gd | 是（seek+pause） |
| `PyramidTriggerBehavior` | 金字塔触发 | PyramidTrigger.gd | 是（重置门） |
| `DiamondCollectBehavior` | 钻石收集 | Diamond.gd | 是（重置收集状态） |
| `CheckpointBehavior` | 检查点记录 | Checkpoint.gd（拆分） | 是（完整恢复） |
| `FakePlayerControlBehavior` | 假线控制 | FakePlayerTrigger.gd | 是 |
| `FakePlayerTeleportBehavior` | 假线传送 | FakePlayerTransport.gd | 否 |
| `PropertyModifierBehavior` | 通用属性修改 | PropertyModifierTrigger.gd | 是 |
| `SetImageColorBehavior` | UI Image 颜色 | **新增** | 是 |
| `HenshinBehavior` | 变身切换 | **新增** | 是 |
| `AchievementBehavior` | 成就触发 | **新增** | 否 |
| `ACChangerBehavior` | 音频配置切换 | **新增** | 是 |

### 4.5 迁移路线图

#### Phase 1：基础设施（1~2 天）
1. 新建 `TriggerBehavior.gd` 基类
2. 改造 `BaseTrigger.gd` 支持组件收集和调度
3. 保持现有所有 Trigger 脚本**完全兼容**（不删除、不改名）

#### Phase 2：核心行为组件（2~3 天）
1. 将高频使用的 Trigger 改写为 Behavior 组件：
   - `KillBehavior`
   - `ChangeSpeedBehavior`
   - `ChangeTurnBehavior`
   - `JumpBehavior`
   - `TeleportBehavior`
   - `SetActiveBehavior`
   - `CameraTriggerBehavior`
   - `CameraShakeBehavior`
   - `MaterialColorBehavior`
   - `CheckpointBehavior`
2. 每个 Behavior 附带 `@tool` 编辑器支持（如需要）

#### Phase 3：新增功能 Behavior（2~3 天）
1. `GravityChangeBehavior` — 对齐 Unity GravityTrigger
2. `PlayAudioBehavior` — 对齐 Unity PlayAudioClip
3. `FadeOutMusicBehavior` — 对齐 Unity FadeOutMusic
4. `FogChangeBehavior` — 扩展现有 FogColorChanger 为完整 Trigger 组件
5. `LightChangeBehavior` — 对齐 Unity SetLight
6. `AmbientChangeBehavior` — 对齐 Unity SetAmbient
7. `ParticlePlayBehavior` — 对齐 Unity ParticleSystemPlay
8. `SetImageColorBehavior` — 对齐 Unity SetImageColor

#### Phase 4：Animator 行为组件（1~2 天）
1. `TimerLightBehavior` — 时间驱动光源动画
2. `TimerAmbientBehavior` — 时间驱动环境光动画
3. `TimerFogBehavior` — 时间驱动雾效动画（Start/End）
4. `TimerImageColorBehavior` — 时间驱动 Image 颜色动画
5. `LocalScaleAnimator` — 缩放时间动画

#### Phase 5：旧脚本标记与场景迁移（2~3 天）
1. 旧 Trigger 脚本添加 `@deprecated` 注释，保留向后兼容
2. 提供迁移指南：如何将旧场景中的 Trigger 节点替换为 BaseTrigger + Behavior 组合
3. 示例场景更新（Sample.tscn、Default.tscn）

### 4.6 组合模式优势

1. **功能复用**：一个 BaseTrigger 下可组合任意多个 Behavior，无需新建脚本
2. **职责单一**：每个 Behavior 只负责一件事，易于测试和维护
3. ** revive 统一**：Behavior 基类统一处理 checkpoint 索引和复活回调
4. **编辑器友好**：Behavior 作为子节点，Inspector 中直观可见，可自由增删
5. **扩展简单**：新增功能只需新建一个 Behavior 脚本，不改动现有代码
6. **对齐 Unity**：Unity 冰焰模板大量使用 MonoBehaviour 组件组合，此模式更贴近原架构思维

---

## 五、详细任务列表（按优先级排序）

### P0 — 关键修复
- [ ] **BaseTrigger 改造**：支持 TriggerBehavior 子节点收集和调度
- [ ] **TriggerBehavior 基类**：统一 execute / revive / reset 生命周期

### P1 — 核心功能补齐
- [ ] **GravityTrigger** → `GravityChangeBehavior`（更改场景重力， revive 恢复）
- [ ] **PlayAudioClip** → `PlayAudioBehavior`（触发播放音效，支持 Trigger/事件模式）
- [ ] **FadeOutMusic** → `FadeOutMusicBehavior`（淡出背景音乐， revive 恢复音量）
- [ ] **FogTrigger** → `FogChangeBehavior`（Area3D 触发模式 + Start/End 动画）
- [ ] **SetLight** → `LightChangeBehavior`（更改定向光源 Rotation/Color/Intensity/Shadow）
- [ ] **SetAmbient** → `AmbientChangeBehavior`（更改环境光源类型）
- [ ] **SetImageColor** → `SetImageColorBehavior`（更改 UI Image 颜色）
- [ ] **FollowPlayer**（物体跟随玩家辅助组件）
- [ ] **noDeath 标志**（Player.gd 添加 `no_death` 字段，KillPlayer 检查跳过）
- [ ] **Henshin 变身系统**（Player.gd 双材质切换 + `HenshinBehavior`）

### P1 — Animator 补齐
- [ ] **LocalScaleAnimator**（缩放时间动画）
- [ ] **TimerLight**（时间驱动定向光源动画）
- [ ] **TimerAmbient**（时间驱动环境光动画）
- [ ] **TimerFog**（时间驱动雾效 Start/End 动画）
- [ ] **TimerImageColor**（时间驱动 Image 颜色动画）

### P2 — 体验增强
- [ ] **LoadingPage**（加载页面 UI）
- [ ] **LevelUI**（关卡内 UI）
- [ ] **GuidanceEnabled**（引导线启用 UI 按钮）
- [ ] **ParticleSystemPlay** → `ParticlePlayBehavior`
- [ ] **AchievementTrigger** → `AchievementBehavior`
- [ ] **ACChanger** → `ACChangerBehavior`
- [ ] **TimeScale**（编辑器全局时间倍速控制）
- [ ] **ActiveByQuality**（根据画质等级启用/禁用对象）
- [ ] **DisableInPlaymode**（运行时隐藏编辑器辅助对象）
- [ ] **TrailRenderer**（编辑器路径高亮 + 点击时间显示）
- [ ] **C 键输出音乐时间**（编辑器快捷键）
- [ ] **sceneCamera / sceneLight 直接引用**（Player.gd 缓存引用，替代 get_first_node_in_group）
- [ ] **playedAnimators / playedTimelines**（跟踪已播放动画器用于存档恢复）
- [ ] **Editor 工具**（GetStartPosition 按钮、OnDrawGizmos、GetFrame FPS）

### P3 — 资产补充
- [ ] **3D 模型/材质补充**（水、自然包、云、环、BonusBox、Fragment、Heart 等）
- [ ] **音乐文件补充**（Phigros_Intro, SampleTrack, Shake_It_Up, nevva）
- [ ] **TTFCheckPoint 系列**（主题化存档点）

### 架构重构
- [ ] **Phase 1**：TriggerBehavior 基类 + BaseTrigger 改造
- [ ] **Phase 2**：核心 Behavior 组件（Kill/ChangeSpeed/ChangeTurn/Jump/Teleport/SetActive/Camera/Shake/Material/Checkpoint）
- [ ] **Phase 3**：新增功能 Behavior（Gravity/Audio/FadeOut/Fog/Light/Ambient/Particle/ImageColor）
- [ ] **Phase 4**：Animator Behavior（TimerLight/TimerAmbient/TimerFog/TimerImageColor/LocalScale）
- [ ] **Phase 5**：旧脚本标记 deprecated + 场景迁移 + 文档更新

---

## 六、文件变更预期

### 新增文件（TriggerBehavior 体系）
```
#Template/[Scripts]/Trigger/Behavior/
  TriggerBehavior.gd          # 基类
  KillBehavior.gd
  ChangeSpeedBehavior.gd
  ChangeTurnBehavior.gd
  JumpBehavior.gd
  TeleportBehavior.gd
  SetActiveBehavior.gd
  PlayAudioBehavior.gd
  FadeOutMusicBehavior.gd
  CameraTriggerBehavior.gd
  OldCameraTriggerBehavior.gd
  CameraShakeBehavior.gd
  FogChangeBehavior.gd
  LightChangeBehavior.gd
  AmbientChangeBehavior.gd
  MaterialColorBehavior.gd
  GravityChangeBehavior.gd
  ParticlePlayBehavior.gd
  EventInvokeBehavior.gd
  AnimatorPlayBehavior.gd
  PyramidTriggerBehavior.gd
  DiamondCollectBehavior.gd
  CheckpointBehavior.gd
  FakePlayerControlBehavior.gd
  FakePlayerTeleportBehavior.gd
  PropertyModifierBehavior.gd
  SetImageColorBehavior.gd
  HenshinBehavior.gd
  AchievementBehavior.gd
  ACChangerBehavior.gd
```

### 修改文件
```
#Template/[Scripts]/Trigger/BaseTrigger.gd    # 增加 Behavior 收集和调度
#Template/[Scripts]/Level/Player.gd           # 添加 no_death, scene_camera, scene_light 等
#Template/[Scripts]/Level/LevelManager.gd     # 如有必要添加辅助方法
```

### 保留文件（向后兼容，标记 deprecated）
```
#Template/[Scripts]/Trigger/ 下所有现有脚本保留，添加注释说明推荐使用 Behavior 组合模式
```

---

*最后更新：2025-06-08*
