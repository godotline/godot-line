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

将 Trigger 拆分为**触发器主体（BaseTrigger）+ 行为组件（BaseTrigger 子节点）**的组合结构：

```
BaseTrigger (Area3D)
├── CollisionShape3D
├── KillPlayer              (BaseTrigger 子行为)
├── ChangeSpeedTrigger      (BaseTrigger 子行为)
└── ...
```

一个 `BaseTrigger` 节点下挂载多个 `BaseTrigger` 子节点，触发时依次调用所有子行为的 `_on_triggered()`。

### 4.3 核心抽象

#### 4.3.1 `BaseTrigger` 改造

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
var _behaviors: Array[BaseTrigger] = []
var _is_behavior: bool = false

func _ready() -> void:
    ## 如果父节点是 BaseTrigger，则作为行为组件，不设置自己的触发器
    if get_parent() is BaseTrigger:
        _is_behavior = true
        return
    _setup_trigger()
    _collect_behaviors()

func _collect_behaviors() -> void:
    _behaviors.clear()
    for child in get_children():
        if child is BaseTrigger:
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
    
    ## 依次调用所有子行为组件
    for behavior in _behaviors:
        if is_instance_valid(behavior):
            behavior._on_triggered(body)
    
    _on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
    pass
```

### 4.4 行为组件清单（需新建）

| 组件名 | 功能 | 对应现有脚本 | revive 恢复 |
|--------|------|-------------|------------|
| 组件名 | 功能 | 对应现有脚本 | revive 恢复 |
|--------|------|-------------|------------|
| `KillPlayer` | 杀死玩家 | KillPlayer.gd | 否（死亡后自动重置） |
| `ChangeSpeedTrigger` | 改变玩家速度 | ChangeSpeedTrigger.gd | 是（恢复原始速度） |
| `ChangeTurn` | 改变玩家转向 | ChangeTurn.gd | 是（恢复方向） |
| `Jump` | 施加跳跃力 | jump.gd | 否 |
| `LocalTeleportTrigger` | 传送玩家 | LocalTeleportTrigger.gd | 是（恢复位置） |
| `SetActiveTrigger` | 激活/禁用节点 | SetActiveTrigger.gd | 是（恢复可见性） |
| `PlayAudioBehavior` | 播放音效 | **新增** | 否 |
| `FadeOutMusicBehavior` | 淡出音乐 | **新增** | 是（恢复音量） |
| `CameraTrigger` | 新相机变换 | CameraTrigger.gd | 是（恢复相机参数） |
| `OldCameraTrigger` | 旧相机变换 | OldCameraTrigger.gd | 是 |
| `CameraShakeTrigger` | 相机震动 | CameraShakeTrigger.gd | 是（停止震动） |
| `FogColorChanger` | 雾效变化 | FogColorChanger.gd | 是（恢复雾参数） |
| `LightChangeBehavior` | 定向光变化 | **新增** | 是 |
| `AmbientChangeBehavior` | 环境光变化 | **新增** | 是 |
| `SetMaterialColor` | 材质颜色变化 | SetMaterialColor.gd | 是 |
| `GravityChangeBehavior` | 重力变化 | **新增** | 是（恢复重力） |
| `ParticlePlayBehavior` | 播放粒子 | **新增** | 否 |
| `EventTrigger` | 调用目标方法 | EventTrigger.gd | 是（重置调用状态） |
| `PlayAnimator` | 播放 AnimationPlayer | PlayAnimator.gd / customanimplay.gd | 是（seek+pause） |
| `PyramidTrigger` | 金字塔触发 | PyramidTrigger.gd | 是（重置门） |
| `Diamond` | 钻石收集 | Diamond.gd | 是（重置收集状态） |
| `Checkpoint` | 检查点记录 | Checkpoint.gd | 是（完整恢复） |
| `FakePlayerTrigger` | 假线控制 | FakePlayerTrigger.gd | 是 |
| `FakePlayerTransport` | 假线传送 | FakePlayerTransport.gd | 否 |
| `PropertyModifierTrigger` | 通用属性修改 | PropertyModifierTrigger.gd | 是 |
| `SetImageColorBehavior` | UI Image 颜色 | **新增** | 是 |
| `HenshinBehavior` | 变身切换 | **新增** | 是 |
| `AchievementBehavior` | 成就触发 | **新增** | 否 |
| `ACChangerBehavior` | 音频配置切换 | **新增** | 是 |

### 4.5 迁移路线图

#### Phase 1：基础设施（1~2 天）
1. 改造 `BaseTrigger.gd` 支持收集子 `BaseTrigger` 并统一调度
2. 保持现有所有 Trigger 脚本**完全兼容**（不删除、不改名）

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
- [x] **BaseTrigger 改造**：支持子 BaseTrigger 收集和调度
- [x] **TriggerBehavior 基类**：新建 `extends Node3D` 的基类，统一行为组件生命周期
- [x] **现有 Trigger 脚本迁移到 Behavior 文件夹**：所有现有脚本移入 `Behavior/`，原位置创建同名转发脚本

### P0 — 迁移计划（现有 Trigger → Behavior）

#### 步骤
1. 新建 `TriggerBehavior.gd`（`extends Node3D`）
2. 将以下现有脚本**原封不动**移入 `#Template/[Scripts]/Trigger/Old/`（保留备份，标记 deprecated）：
   - `KillPlayer.gd`
   - `ChangeSpeedTrigger.gd`
   - `ChangeTurn.gd`
   - `jump.gd`
   - `LocalTeleportTrigger.gd`
   - `SetActiveTrigger.gd`
   - `CameraTrigger.gd`
   - `OldCameraTrigger.gd`
   - `CameraShakeTrigger.gd`
   - `FogColorChanger.gd`
   - `SetMaterialColor.gd`
   - `EventTrigger.gd`
   - `PlayAnimator.gd`
   - `customanimplay.gd`
   - `PyramidTrigger.gd`
   - `Pyramid.gd`
   - `Diamond.gd`
   - `Checkpoint.gd`
   - `Crown.gd`
   - `HeartCheckpoint.gd`
   - `FakePlayerTrigger.gd`
   - `FakePlayerTransport.gd`
   - `PropertyModifierTrigger.gd`
3. 在原位置创建同名新脚本，`extends TriggerBehavior` + `class_name`，重写逻辑（参考 Old/ 中的实现）
4. `BaseTrigger._collect_behaviors()` 改为收集 `TriggerBehavior`（`Node3D`）

### P1 — 核心功能补齐
- [x] **GravityTrigger** → `GravityChangeBehavior`（更改场景重力， revive 恢复）
- [x] **PlayAudioClip** → `PlayAudioBehavior`（触发播放音效，支持 Trigger/事件模式）
- [x] **FadeOutMusic** → `FadeOutMusicBehavior`（淡出背景音乐， revive 恢复音量）
- [x] **FogTrigger** → `FogChangeBehavior`（Area3D 触发模式 + Start/End 动画）
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
- [x] **Phase 1**：BaseTrigger 改造（支持子行为收集调度）
- [x] **Phase 2**：核心 Behavior 组件（Kill/ChangeSpeed/ChangeTurn/Jump/Teleport/SetActive/Camera/Shake/Material/Checkpoint）
- [x] **Phase 3**：新增功能 Behavior（Gravity/Audio/FadeOut/Fog）
- [ ] **Phase 4**：Animator Behavior（TimerLight/TimerAmbient/TimerFog/TimerImageColor/LocalScale）
- [x] **Phase 5**：旧脚本标记 deprecated + 场景迁移 + 文档更新

---

## 六、文件变更预期

### 新增文件（Behavior 体系）
```
#Template/[Scripts]/Trigger/Behavior/
  PlayAudioBehavior.gd
  FadeOutMusicBehavior.gd
  LightChangeBehavior.gd
  AmbientChangeBehavior.gd
  GravityChangeBehavior.gd
  ParticlePlayBehavior.gd
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

## 七、性能优化计划（对比 Unity 逻辑）

> **优先级定位**：性能优化属于 **P0~P1 级别**。其中 Phase 1（物理修复、Audio 池）为 **P0**，直接影响运行稳定性；Phase 2~5 为 **P1**，显著提升帧率和内存效率。

### 7.1 性能现状分析

通过对现有代码的全面审查，发现以下性能瓶颈（按严重程度排序）：

| 严重程度 | 问题领域 | 具体问题 | 影响 |
|----------|----------|----------|------|
| **高** | 物理 | `_physics_process` 中每帧调用 `is_on_floor()` 后再 `move_and_slide()`，顺序错误导致 floor 检测不可靠，额外调用 | 物理计算冗余，floor 状态不稳定 |
| **高** | 渲染 | `Player._process` 中每帧遍历 `floor_segment_lines` 数组更新 Y 坐标 | O(n) 每帧遍历，n 为尾线段数 |
| **高** | 渲染 | `RoadMaker._physics_process` 每帧动态缩放 `StaticBody3D` 的 `scale` | 运行时改变碰撞体 scale 触发物理重建 |
| **高** | 内存 | `AudioManager.play_clip` 每次播放新建 `AudioStreamPlayer` 节点 | GC 压力，节点树膨胀 |
| **中** | CPU | `LevelManager.Clicked` 每帧检查 4 个输入状态 | 输入轮询而非事件驱动 |
| **中** | 渲染 | `Crown._process` 每帧 `rotate_y(delta)`，即使不可见 | 无 visibility 检查 |
| **中** | 渲染 | `HeartCheckpoint._process` 每帧旋转两个子节点 | 无 visibility 检查 |
| **中** | CPU | `GuidanceBox._process` 每帧计算两次 `distance_squared_to` | 距离检查过于频繁 |
| **中** | 内存 | `FakePlayer._tail_pool` 使用 `Array` + `pop_front()` | O(n) 移动，应使用循环队列或 ObjectPool |
| **中** | 渲染 | `DebugOverlay._update_label` 每帧构造大量字符串 | 字符串拼接开销 |
| **低** | CPU | `OldCameraFollower._process` 中每帧 3 次 `lerp_angle` | 可合并为 Quaternion slerp |
| **低** | 渲染 | `CameraFollower._process` 中每帧创建临时 `Transform3D` | 临时对象分配 |
| **低** | 内存 | `Checkpoint.revive()` 中 `get_tree().get_processed_tweens()` 全量遍历 | 复活时遍历所有 tween |

### 7.2 Unity 版性能优势对照

| 优化点 | Unity 做法 | Godot 现状 | 优化方向 |
|--------|-----------|-----------|----------|
| 对象池 | `ObjectPool<T>` 预分配，零 GC | `AudioManager` 每次新建节点 | 预分配 AudioStreamPlayer 池 |
| 尾线更新 | `MeshRenderer` batch 或合并网格 | 每段独立 `MeshInstance3D` | 使用 MultiMesh 或合并网格 |
| 碰撞体 | 碰撞体尺寸固定，用视觉网格缩放 | `RoadMaker` 直接缩放 `StaticBody3D` | 分离视觉与碰撞，碰撞体固定尺寸 |
| 输入检测 | `Input.GetButtonDown` 事件式 | 每帧轮询 4 个键 | 保持事件式，但优化缓存逻辑 |
| 相机跟随 | `Transform` 直接赋值，无中间对象 | 每帧创建 `Transform3D` | 缓存变换，避免临时对象 |
| 字符串拼接 | `StringBuilder` 或缓存 | 每帧 `"%d%%" % value` | 缓存格式化字符串 |
| 粒子系统 | `ParticleSystem` 对象池复用 | `deathParticle` 每次 instantiate 8 个 | 预分配死亡粒子池 |
| 距离检测 | `sqrMagnitude` 对比，分层更新 | 每帧多次 `distance_squared_to` | 分层 LOD，远距离降低检测频率 |

### 7.3 优化方案详解

#### 7.3.1 物理优化

**问题**：`RoadMaker` 每帧改变 `StaticBody3D.scale` 导致 Jolt Physics 重建碰撞形状

**Unity 做法**：Unity 中碰撞体缩放也会触发重建，但冰焰模板使用固定尺寸的 `BoxCollider` + 视觉网格分离

**优化方案**：
```gdscript
# RoadMaker.gd 优化后
func _physics_process(_delta: float) -> void:
    if road:
        var offset := main_line.position - past_translation
        road.position = offset / 2 + past_translation
        # 不再缩放碰撞体，而是只缩放视觉网格
        var visual_mesh = road.get_node_or_null("VisualMesh") as MeshInstance3D
        if visual_mesh:
            visual_mesh.scale = offset.abs() + Vector3(road_width, 1, road_width)
        # 碰撞体保持固定尺寸，通过 position 移动
```

**问题**：`Player._physics_process` 中 `move_and_slide()` 后 `is_on_wall()` 检查

**优化方案**：确保 `move_and_slide()` 在 `_physics_process` 末尾只调用一次，将 `is_on_wall()` 检查移到调用之后

#### 7.3.2 渲染优化

**问题**：Player 尾线每段独立 `MeshInstance3D`，Draw Call 随长度线性增长

**Unity 做法**：Unity 冰焰模板使用 `LineRenderer` 或合并网格（`Mesh.CombineMeshes`）

**优化方案**：
1. **短期**：使用 `MultiMeshInstance3D` 批量渲染尾线段（1 个 Draw Call）
2. **长期**：实现网格合并，将连续尾线段合并为单一 Mesh

```gdscript
# 尾线 MultiMesh 方案
var _tail_multimesh: MultiMeshInstance3D
var _tail_multimesh_data: MultiMesh

func _init_tail_multimesh() -> void:
    _tail_multimesh = MultiMeshInstance3D.new()
    _tail_multimesh_data = MultiMesh.new()
    _tail_multimesh_data.transform_format = MultiMesh.TRANSFORM_3D
    _tail_multimesh_data.mesh = mesh  # 复用 Player 的 mesh
    _tail_multimesh.multimesh = _tail_multimesh_data
    tail_holder.add_child(_tail_multimesh)

func _update_tail_multimesh() -> void:
    _tail_multimesh_data.instance_count = floor_segment_lines.size()
    for i in floor_segment_lines.size():
        var segment = floor_segment_lines[i]
        _tail_multimesh_data.set_instance_transform(i, segment.transform)
```

**问题**：`floor_segment_lines` 每帧遍历更新 Y 坐标

**优化方案**：
```gdscript
# 当前：每 0.05 秒遍历一次，已部分优化
# 进一步优化：只在 Y 变化时更新，使用脏标记
var _floor_y_dirty: bool = false

func _process(_delta: float) -> void:
    # ...
    if abs(current_y - _last_floor_y) > 0.001:
        _floor_y_dirty = true
        _last_floor_y = current_y
    
    if _floor_y_dirty:
        _floor_y_dirty = false
        for segment in floor_segment_lines:
            if is_instance_valid(segment):
                segment.global_position.y = _last_floor_y
```

#### 7.3.3 内存优化

**问题**：`AudioManager.play_clip` 每次播放新建节点

**优化方案**：预分配 `AudioStreamPlayer` 对象池

```gdscript
# AudioManager.gd 优化
const AUDIO_POOL_SIZE := 16
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_pool_index: int = 0

func _init_audio_pool() -> void:
    for i in AUDIO_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        Player.instance.add_child(player)
        _audio_pool.append(player)

static func play_clip(clip: AudioStream, volume: float = 1.0) -> void:
    if not clip or not Player.instance:
        return
    var player := _audio_pool[_audio_pool_index]
    _audio_pool_index = (_audio_pool_index + 1) % AUDIO_POOL_SIZE
    player.stream = clip
    player.volume_db = linear_to_db(max(volume, 0.001))
    player.play()
```

**问题**：死亡粒子每次 instantiate 8 个 `RigidBody3D`

**优化方案**：使用 `ObjectPool` 预分配死亡粒子

```gdscript
# Player.gd 中添加死亡粒子池
var _death_particle_pool: ObjectPool

func _ready() -> void:
    # ...
    _death_particle_pool = ObjectPool.new(64)  # 预分配 64 个
    for i in 64:
        var particle: RigidBody3D = deathParticle.instantiate()
        particle.add_to_group("death_particles")
        _death_particle_pool.add(particle)

func die(...) -> void:
    # ...
    for i in 8:
        var deathParticle_instance := _death_particle_pool.pop() as RigidBody3D
        if not deathParticle_instance:
            deathParticle_instance = deathParticle.instantiate()
        # 重置状态后使用
```

#### 7.3.4 CPU 优化

**问题**：`LevelManager.Clicked` 每帧轮询 4 个输入键

**优化方案**：保持事件式输入，但优化缓存逻辑（当前已实现帧缓存，可进一步优化为只在输入变化时更新）

```gdscript
# LevelManager.gd 优化
static var Clicked: bool:
    get:
        if not get_input:
            return false
        var current_frame := Engine.get_process_frames()
        if current_frame != _clicked_frame:
            _clicked_cached = Input.is_anything_pressed()  # 先快速检查
            if _clicked_cached:
                _clicked_cached = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
                    or Input.is_key_pressed(KEY_SPACE) \
                    or Input.is_key_pressed(KEY_ENTER) \
                    or Input.is_key_pressed(KEY_KP_ENTER)
            _clicked_frame = current_frame
        return _clicked_cached
```

**问题**：`Crown._process` 和 `HeartCheckpoint._process` 每帧旋转，即使不可见

**优化方案**：
```gdscript
# Crown.gd 优化
func _process(delta: float) -> void:
    if not is_visible_in_tree():  # 添加可见性检查
        return
    if _crown_mesh:
        _crown_mesh.rotate_y(delta)
```

**问题**：`GuidanceBox._process` 每帧两次距离计算

**优化方案**：分层更新频率
```gdscript
# GuidanceBox.gd 优化
const APPEAR_CHECK_INTERVAL := 0.1  # 每 0.1 秒检查一次出现距离
var _appear_check_timer: float = 0.0

func _process(delta: float) -> void:
    _appear_check_timer += delta
    if _appear_check_timer >= APPEAR_CHECK_INTERVAL:
        _appear_check_timer = 0.0
        if not triggered and not _root.visible:
            var dist_sq := global_position.distance_squared_to(_player.global_position)
            if dist_sq <= appear_distance:
                _appear()
    
    # 触发距离检查保持每帧（需要精确）
    if LevelManager.Clicked and not triggered and can_be_triggered:
        var dist_sq := global_position.distance_squared_to(_player.global_position)
        if dist_sq <= trigger_distance * trigger_distance:
            _trigger()
```

#### 7.3.5 字符串与 UI 优化

**问题**：`DebugOverlay._update_label` 每帧构造大量字符串

**优化方案**：脏标记 + 缓存
```gdscript
# DebugOverlay.gd 优化
var _cached_text: String = ""
var _cache_dirty: bool = true

func _process(_delta: float) -> void:
    if _cache_dirty:
        _cache_dirty = false
        _update_label()
    # 标记脏：监听 Player 状态变化信号

func _on_player_state_changed() -> void:
    _cache_dirty = true
```

**问题**：`gameui.gd` 的 `_process` 每帧检查游戏结束状态

**优化方案**：使用信号驱动替代轮询
```gdscript
# gameui.gd 优化
func _ready() -> void:
    # ...
    # 监听游戏结束信号，替代每帧轮询
    if Player.instance:
        Player.instance.on_game_over.connect(_on_game_over)
    # LevelManager 添加游戏结束信号

func _on_game_over() -> void:
    visible()
```

#### 7.3.6 相机优化

**问题**：`OldCameraFollower._process` 每帧 3 次 `lerp_angle`

**优化方案**：使用 Quaternion slerp 替代逐轴 lerp
```gdscript
# OldCameraFollower.gd 优化
func _process(delta: float) -> void:
    # ...
    var target_rot = _get_target_rotation()
    var current_q = quaternion
    var target_q = Quaternion.from_euler(target_rot)
    quaternion = current_q.slerp(target_q, abs(follow_speed * delta))
```

**问题**：`CameraFollower._process` 每帧创建临时 `Transform3D`

**优化方案**：缓存 Basis
```gdscript
# CameraFollower.gd 优化
var _follow_basis: Basis  # 在 _ready 中初始化

func _ready() -> void:
    # ...
    _follow_basis = Basis.from_euler(Vector3(0, deg_to_rad(45), 0))

func _process(delta: float) -> void:
    # ...
    if smooth:
        position += _follow_basis * result  # 复用缓存的 Basis
```

### 7.4 项目设置优化

#### 7.4.1 project.godot 调优

```ini
[application]
run/delta_smoothing=false  # 已设置，保持

[physics]
3d/run_on_separate_thread=true  # 已设置，保持
3d/physics_engine="Jolt Physics"  # 已设置，保持

[rendering]
renderer/rendering_method="mobile"  # 已设置，保持
# 新增优化：
textures/vram_compression/import_etc2_astc=true  # 移动平台纹理压缩
lights_and_shadows/directional_shadow/size=2048  # 限制阴影分辨率
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=0  # 低质量软阴影
```

#### 7.4.2 场景优化建议

1. **LOD 系统**：远距离物体降低 Mesh 精度或切换为 Billboard
2. **遮挡剔除**：利用 Godot 4 的 Occlusion Culling（需烘焙）
3. **光照烘焙**：静态光照使用 LightmapGI 烘焙
4. **阴影距离**：限制 DirectionalLight3D 的阴影最大距离
5. **粒子限制**：限制同时存在的粒子数量

### 7.5 性能监控工具

#### 7.5.1 内置监控增强

```gdscript
# DebugOverlay.gd 添加性能指标
func _update_label() -> void:
    # ... 现有代码 ...
    
    # 新增性能指标
    var mem := OS.get_static_memory_usage() / 1024 / 1024
    lines.append("内存: %.1f MB" % mem)
    
    var obj_count := Performance.get_monitor(Performance.OBJECT_COUNT)
    lines.append("对象数: %d" % obj_count)
    
    var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    lines.append("Draw Calls: %d" % draw_calls)
    
    var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
    lines.append("物理耗时: %.2f ms" % physics_time)
```

#### 7.5.2 自定义性能分析器

```gdscript
# 新增 PerformanceProfiler.gd
class_name PerformanceProfiler
extends RefCounted

## 简单的代码块性能分析器

static var _timers: Dictionary = {}

static func begin(label: String) -> void:
    _timers[label] = Time.get_ticks_usec()

static func end(label: String) -> void:
    if not _timers.has(label):
        return
    var elapsed := (Time.get_ticks_usec() - _timers[label]) / 1000.0
    if elapsed > 1.0:  # 只打印超过 1ms 的
        print("[Profiler] %s: %.3f ms" % [label, elapsed])
    _timers.erase(label)
```

### 7.6 优化实施路线图（按优先级排序）

> 性能优化的 5 个 Phase 与功能开发的优先级交叉如下：
> - **Phase 1 = P0**：必须立即实施，否则影响稳定性和帧率
> - **Phase 2~3 = P1**：核心渲染和 CPU 优化，显著提升性能
> - **Phase 4~5 = P1/P2**：内存清理和监控工具，完善体验

#### 🔴 Phase 1：紧急优化（P0，立即实施，1~2 天）
- [ ] **修复 `move_and_slide()` 调用顺序**：确保在 `_physics_process` 中只调用一次
- [ ] **RoadMaker 碰撞体分离**：视觉网格与碰撞体分离，不再每帧缩放碰撞体
- [ ] **AudioManager 对象池**：预分配 `AudioStreamPlayer` 池
- [ ] **可见性检查**：为 `Crown`、`HeartCheckpoint` 等添加 `is_visible_in_tree()` 检查

#### 🟠 Phase 2：渲染优化（P1，1~2 天）
- [ ] **尾线 MultiMesh**：使用 `MultiMeshInstance3D` 批量渲染尾线段
- [ ] **floor_segment_lines 脏标记**：只在 Y 坐标变化时更新
- [ ] **死亡粒子对象池**：使用 `ObjectPool` 预分配

#### 🟡 Phase 3：CPU 优化（P1，1~2 天）
- [ ] **GuidanceBox 分层更新**：出现距离检查降频到 0.1 秒
- [ ] **DebugOverlay 脏标记**：只在状态变化时更新文本
- [ ] **gameui 信号驱动**：使用信号替代 `_process` 轮询
- [ ] **OldCameraFollower Quaternion slerp**：替代逐轴 lerp_angle

#### 🟢 Phase 4：内存与 GC 优化（P1，1 天）
- [ ] **FakePlayer 尾线池**：使用 `ObjectPool` 替代 `Array.pop_front()`
- [ ] **字符串缓存**：`DebugOverlay` 中缓存格式化字符串
- [ ] **临时对象消除**：`CameraFollower` 缓存 `Basis`

#### 🔵 Phase 5：项目设置与监控（P2，1 天）
- [ ] **project.godot 调优**：添加纹理压缩、阴影限制等
- [ ] **性能监控增强**：`DebugOverlay` 添加 Draw Call、对象数等指标
- [ ] **自定义 Profiler**：添加 `PerformanceProfiler` 工具类

### 7.7 预期收益

| 优化项 | 当前估算开销 | 优化后估算 | 收益 |
|--------|-------------|-----------|------|
| 尾线 Draw Call | n 段 = n Draw Calls | 1 Draw Call (MultiMesh) | **-95%** |
| 音频节点分配 | 每次播放新建节点 | 池化复用 | **-99%** |
| RoadMaker 物理重建 | 每帧重建碰撞体 | 不再重建 | **-100%** |
| floor_segment_lines 更新 | 每 0.05s O(n) | 脏标记 O(1) | **-80%** |
| GuidanceBox 距离检查 | 每帧 2 次 | 分层 0.1s + 每帧 1 次 | **-50%** |
| DebugOverlay 字符串 | 每帧构造 | 脏标记 | **-90%** |
| 不可见旋转 | 每帧旋转 | 可见时旋转 | **-50%** (非关键路径) |

---

## 八、全局优先级总览（所有计划统一排序）

### 执行顺序建议（综合功能 + 架构 + 性能）

| 顺序 | 优先级 | 任务 | 所属章节 | 预估时间 | 阻塞关系 |
|------|--------|------|----------|----------|----------|
| 1 | **P0** | BaseTrigger 改造（支持子行为收集调度） | 四、4.3 | 1~2 天 | 无 |
| 2 | **P0** | 性能 Phase 1：物理修复 + Audio 池 + 可见性检查 | 七、7.6 | 1~2 天 | 无 |
| 3 | **P1** | 核心 Behavior 组件（Kill/ChangeSpeed/ChangeTurn/Jump/Teleport/SetActive） | 四、4.5 Phase 2 | 2~3 天 | 依赖 #1 |
| 4 | **P1** | 性能 Phase 2：尾线 MultiMesh + 脏标记 + 粒子池 | 七、7.6 | 1~2 天 | 无 |
| 5 | **P1** | 新增功能 Behavior（Gravity/Audio/FadeOut/Fog/Light/Ambient/Particle/ImageColor） | 四、4.5 Phase 3 | 2~3 天 | 依赖 #3 |
| 6 | **P1** | 性能 Phase 3：CPU 优化（GuidanceBox/Overlay/gameui/Quaternion） | 七、7.6 | 1~2 天 | 无 |
| 7 | **P1** | noDeath 标志 + Henshin 变身系统 | 五、P1 | 1 天 | 无 |
| 8 | **P1** | Animator Behavior（TimerLight/TimerAmbient/TimerFog/TimerImageColor/LocalScale） | 四、4.5 Phase 4 | 1~2 天 | 依赖 #3 |
| 9 | **P1** | FollowPlayer 辅助组件 | 五、P1 | 1 天 | 无 |
| 10 | **P1** | 性能 Phase 4：内存与 GC 优化 | 七、7.6 | 1 天 | 无 |
| 11 | **P2** | LoadingPage + LevelUI + GuidanceEnabled | 五、P2 | 2~3 天 | 无 |
| 12 | **P2** | 性能 Phase 5：项目设置与监控 | 七、7.6 | 1 天 | 无 |
| 13 | **P2** | 旧脚本标记 deprecated + 场景迁移 | 四、4.5 Phase 5 | 2~3 天 | 依赖 #3, #5 |
| 14 | **P2** | TimeScale + ActiveByQuality + DisableInPlaymode + TrailRenderer | 五、P2 | 2~3 天 | 无 |
| 15 | **P2** | Editor 工具（GetStartPosition、OnDrawGizmos、GetFrame、C 键音乐时间） | 五、P2 | 1~2 天 | 无 |
| 16 | **P3** | 3D 模型/材质/音乐资产补充 | 五、P3 | 视来源 | 无 |
| 17 | **P3** | TTFCheckPoint 系列 | 五、P3 | 1~2 天 | 无 |

---

*最后更新：2025-06-08*

### 7.1 性能现状分析

通过对现有代码的全面审查，发现以下性能瓶颈（按严重程度排序）：

| 严重程度 | 问题领域 | 具体问题 | 影响 |
|----------|----------|----------|------|
| **高** | 物理 | `_physics_process` 中每帧调用 `is_on_floor()` 后再 `move_and_slide()`，顺序错误导致 floor 检测不可靠，额外调用 | 物理计算冗余，floor 状态不稳定 |
| **高** | 渲染 | `Player._process` 中每帧遍历 `floor_segment_lines` 数组更新 Y 坐标 | O(n) 每帧遍历，n 为尾线段数 |
| **高** | 渲染 | `RoadMaker._physics_process` 每帧动态缩放 `StaticBody3D` 的 `scale` | 运行时改变碰撞体 scale 触发物理重建 |
| **高** | 内存 | `AudioManager.play_clip` 每次播放新建 `AudioStreamPlayer` 节点 | GC 压力，节点树膨胀 |
| **中** | CPU | `LevelManager.Clicked` 每帧检查 4 个输入状态 | 输入轮询而非事件驱动 |
| **中** | 渲染 | `Crown._process` 每帧 `rotate_y(delta)`，即使不可见 | 无 visibility 检查 |
| **中** | 渲染 | `HeartCheckpoint._process` 每帧旋转两个子节点 | 无 visibility 检查 |
| **中** | CPU | `GuidanceBox._process` 每帧计算两次 `distance_squared_to` | 距离检查过于频繁 |
| **中** | 内存 | `FakePlayer._tail_pool` 使用 `Array` + `pop_front()` | O(n) 移动，应使用循环队列或 ObjectPool |
| **中** | 渲染 | `DebugOverlay._update_label` 每帧构造大量字符串 | 字符串拼接开销 |
| **低** | CPU | `OldCameraFollower._process` 中每帧 3 次 `lerp_angle` | 可合并为 Quaternion slerp |
| **低** | 渲染 | `CameraFollower._process` 中每帧创建临时 `Transform3D` | 临时对象分配 |
| **低** | 内存 | `Checkpoint.revive()` 中 `get_tree().get_processed_tweens()` 全量遍历 | 复活时遍历所有 tween |

### 7.2 Unity 版性能优势对照

| 优化点 | Unity 做法 | Godot 现状 | 优化方向 |
|--------|-----------|-----------|----------|
| 对象池 | `ObjectPool<T>` 预分配，零 GC | `AudioManager` 每次新建节点 | 预分配 AudioStreamPlayer 池 |
| 尾线更新 | `MeshRenderer` batch 或合并网格 | 每段独立 `MeshInstance3D` | 使用 MultiMesh 或合并网格 |
| 碰撞体 | 碰撞体尺寸固定，用视觉网格缩放 | `RoadMaker` 直接缩放 `StaticBody3D` | 分离视觉与碰撞，碰撞体固定尺寸 |
| 输入检测 | `Input.GetButtonDown` 事件式 | 每帧轮询 4 个键 | 保持事件式，但优化缓存逻辑 |
| 相机跟随 | `Transform` 直接赋值，无中间对象 | 每帧创建 `Transform3D` | 缓存变换，避免临时对象 |
| 字符串拼接 | `StringBuilder` 或缓存 | 每帧 `"%d%%" % value` | 缓存格式化字符串 |
| 粒子系统 | `ParticleSystem` 对象池复用 | `deathParticle` 每次 instantiate 8 个 | 预分配死亡粒子池 |
| 距离检测 | `sqrMagnitude` 对比，分层更新 | 每帧多次 `distance_squared_to` | 分层 LOD，远距离降低检测频率 |

### 7.3 优化方案详解

#### 7.3.1 物理优化

**问题**：`RoadMaker` 每帧改变 `StaticBody3D.scale` 导致 Jolt Physics 重建碰撞形状

**Unity 做法**：Unity 中碰撞体缩放也会触发重建，但冰焰模板使用固定尺寸的 `BoxCollider` + 视觉网格分离

**优化方案**：
```gdscript
# RoadMaker.gd 优化后
func _physics_process(_delta: float) -> void:
    if road:
        var offset := main_line.position - past_translation
        road.position = offset / 2 + past_translation
        # 不再缩放碰撞体，而是只缩放视觉网格
        var visual_mesh = road.get_node_or_null("VisualMesh") as MeshInstance3D
        if visual_mesh:
            visual_mesh.scale = offset.abs() + Vector3(road_width, 1, road_width)
        # 碰撞体保持固定尺寸，通过 position 移动
```

**问题**：`Player._physics_process` 中 `move_and_slide()` 后 `is_on_wall()` 检查

**优化方案**：确保 `move_and_slide()` 在 `_physics_process` 末尾只调用一次，将 `is_on_wall()` 检查移到调用之后

#### 7.3.2 渲染优化

**问题**：Player 尾线每段独立 `MeshInstance3D`，Draw Call 随长度线性增长

**Unity 做法**：Unity 冰焰模板使用 `LineRenderer` 或合并网格（`Mesh.CombineMeshes`）

**优化方案**：
1. **短期**：使用 `MultiMeshInstance3D` 批量渲染尾线段（1 个 Draw Call）
2. **长期**：实现网格合并，将连续尾线段合并为单一 Mesh

```gdscript
# 尾线 MultiMesh 方案
var _tail_multimesh: MultiMeshInstance3D
var _tail_multimesh_data: MultiMesh

func _init_tail_multimesh() -> void:
    _tail_multimesh = MultiMeshInstance3D.new()
    _tail_multimesh_data = MultiMesh.new()
    _tail_multimesh_data.transform_format = MultiMesh.TRANSFORM_3D
    _tail_multimesh_data.mesh = mesh  # 复用 Player 的 mesh
    _tail_multimesh.multimesh = _tail_multimesh_data
    tail_holder.add_child(_tail_multimesh)

func _update_tail_multimesh() -> void:
    _tail_multimesh_data.instance_count = floor_segment_lines.size()
    for i in floor_segment_lines.size():
        var segment = floor_segment_lines[i]
        _tail_multimesh_data.set_instance_transform(i, segment.transform)
```

**问题**：`floor_segment_lines` 每帧遍历更新 Y 坐标

**优化方案**：
```gdscript
# 当前：每 0.05 秒遍历一次，已部分优化
# 进一步优化：只在 Y 变化时更新，使用脏标记
var _floor_y_dirty: bool = false

func _process(_delta: float) -> void:
    # ...
    if abs(current_y - _last_floor_y) > 0.001:
        _floor_y_dirty = true
        _last_floor_y = current_y
    
    if _floor_y_dirty:
        _floor_y_dirty = false
        for segment in floor_segment_lines:
            if is_instance_valid(segment):
                segment.global_position.y = _last_floor_y
```

#### 7.3.3 内存优化

**问题**：`AudioManager.play_clip` 每次播放新建节点

**优化方案**：预分配 `AudioStreamPlayer` 对象池

```gdscript
# AudioManager.gd 优化
const AUDIO_POOL_SIZE := 16
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_pool_index: int = 0

func _init_audio_pool() -> void:
    for i in AUDIO_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        Player.instance.add_child(player)
        _audio_pool.append(player)

static func play_clip(clip: AudioStream, volume: float = 1.0) -> void:
    if not clip or not Player.instance:
        return
    var player := _audio_pool[_audio_pool_index]
    _audio_pool_index = (_audio_pool_index + 1) % AUDIO_POOL_SIZE
    player.stream = clip
    player.volume_db = linear_to_db(max(volume, 0.001))
    player.play()
```

**问题**：死亡粒子每次 instantiate 8 个 `RigidBody3D`

**优化方案**：使用 `ObjectPool` 预分配死亡粒子

```gdscript
# Player.gd 中添加死亡粒子池
var _death_particle_pool: ObjectPool

func _ready() -> void:
    # ...
    _death_particle_pool = ObjectPool.new(64)  # 预分配 64 个
    for i in 64:
        var particle: RigidBody3D = deathParticle.instantiate()
        particle.add_to_group("death_particles")
        _death_particle_pool.add(particle)

func die(...) -> void:
    # ...
    for i in 8:
        var deathParticle_instance := _death_particle_pool.pop() as RigidBody3D
        if not deathParticle_instance:
            deathParticle_instance = deathParticle.instantiate()
        # 重置状态后使用
```

#### 7.3.4 CPU 优化

**问题**：`LevelManager.Clicked` 每帧轮询 4 个输入键

**优化方案**：保持事件式输入，但优化缓存逻辑（当前已实现帧缓存，可进一步优化为只在输入变化时更新）

```gdscript
# LevelManager.gd 优化
static var Clicked: bool:
    get:
        if not get_input:
            return false
        var current_frame := Engine.get_process_frames()
        if current_frame != _clicked_frame:
            _clicked_cached = Input.is_anything_pressed()  # 先快速检查
            if _clicked_cached:
                _clicked_cached = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
                    or Input.is_key_pressed(KEY_SPACE) \
                    or Input.is_key_pressed(KEY_ENTER) \
                    or Input.is_key_pressed(KEY_KP_ENTER)
            _clicked_frame = current_frame
        return _clicked_cached
```

**问题**：`Crown._process` 和 `HeartCheckpoint._process` 每帧旋转，即使不可见

**优化方案**：
```gdscript
# Crown.gd 优化
func _process(delta: float) -> void:
    if not is_visible_in_tree():  # 添加可见性检查
        return
    if _crown_mesh:
        _crown_mesh.rotate_y(delta)
```

**问题**：`GuidanceBox._process` 每帧两次距离计算

**优化方案**：分层更新频率
```gdscript
# GuidanceBox.gd 优化
const APPEAR_CHECK_INTERVAL := 0.1  # 每 0.1 秒检查一次出现距离
var _appear_check_timer: float = 0.0

func _process(delta: float) -> void:
    _appear_check_timer += delta
    if _appear_check_timer >= APPEAR_CHECK_INTERVAL:
        _appear_check_timer = 0.0
        if not triggered and not _root.visible:
            var dist_sq := global_position.distance_squared_to(_player.global_position)
            if dist_sq <= appear_distance:
                _appear()
    
    # 触发距离检查保持每帧（需要精确）
    if LevelManager.Clicked and not triggered and can_be_triggered:
        var dist_sq := global_position.distance_squared_to(_player.global_position)
        if dist_sq <= trigger_distance * trigger_distance:
            _trigger()
```

#### 7.3.5 字符串与 UI 优化

**问题**：`DebugOverlay._update_label` 每帧构造大量字符串

**优化方案**：脏标记 + 缓存
```gdscript
# DebugOverlay.gd 优化
var _cached_text: String = ""
var _cache_dirty: bool = true

func _process(_delta: float) -> void:
    if _cache_dirty:
        _cache_dirty = false
        _update_label()
    # 标记脏：监听 Player 状态变化信号

func _on_player_state_changed() -> void:
    _cache_dirty = true
```

**问题**：`gameui.gd` 的 `_process` 每帧检查游戏结束状态

**优化方案**：使用信号驱动替代轮询
```gdscript
# gameui.gd 优化
func _ready() -> void:
    # ...
    # 监听游戏结束信号，替代每帧轮询
    if Player.instance:
        Player.instance.on_game_over.connect(_on_game_over)
    # LevelManager 添加游戏结束信号

func _on_game_over() -> void:
    visible()
```

#### 7.3.6 相机优化

**问题**：`OldCameraFollower._process` 每帧 3 次 `lerp_angle`

**优化方案**：使用 Quaternion slerp 替代逐轴 lerp
```gdscript
# OldCameraFollower.gd 优化
func _process(delta: float) -> void:
    # ...
    var target_rot = _get_target_rotation()
    var current_q = quaternion
    var target_q = Quaternion.from_euler(target_rot)
    quaternion = current_q.slerp(target_q, abs(follow_speed * delta))
```

**问题**：`CameraFollower._process` 每帧创建临时 `Transform3D`

**优化方案**：缓存 Basis
```gdscript
# CameraFollower.gd 优化
var _follow_basis: Basis  # 在 _ready 中初始化

func _ready() -> void:
    # ...
    _follow_basis = Basis.from_euler(Vector3(0, deg_to_rad(45), 0))

func _process(delta: float) -> void:
    # ...
    if smooth:
        position += _follow_basis * result  # 复用缓存的 Basis
```

### 7.4 项目设置优化

#### 7.4.1 project.godot 调优

```ini
[application]
run/delta_smoothing=false  # 已设置，保持

[physics]
3d/run_on_separate_thread=true  # 已设置，保持
3d/physics_engine="Jolt Physics"  # 已设置，保持

[rendering]
renderer/rendering_method="mobile"  # 已设置，保持
# 新增优化：
textures/vram_compression/import_etc2_astc=true  # 移动平台纹理压缩
lights_and_shadows/directional_shadow/size=2048  # 限制阴影分辨率
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=0  # 低质量软阴影
```

#### 7.4.2 场景优化建议

1. **LOD 系统**：远距离物体降低 Mesh 精度或切换为 Billboard
2. **遮挡剔除**：利用 Godot 4 的 Occlusion Culling（需烘焙）
3. **光照烘焙**：静态光照使用 LightmapGI 烘焙
4. **阴影距离**：限制 DirectionalLight3D 的阴影最大距离
5. **粒子限制**：限制同时存在的粒子数量

### 7.5 性能监控工具

#### 7.5.1 内置监控增强

```gdscript
# DebugOverlay.gd 添加性能指标
func _update_label() -> void:
    # ... 现有代码 ...
    
    # 新增性能指标
    var mem := OS.get_static_memory_usage() / 1024 / 1024
    lines.append("内存: %.1f MB" % mem)
    
    var obj_count := Performance.get_monitor(Performance.OBJECT_COUNT)
    lines.append("对象数: %d" % obj_count)
    
    var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    lines.append("Draw Calls: %d" % draw_calls)
    
    var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
    lines.append("物理耗时: %.2f ms" % physics_time)
```

#### 7.5.2 自定义性能分析器

```gdscript
# 新增 PerformanceProfiler.gd
class_name PerformanceProfiler
extends RefCounted

## 简单的代码块性能分析器

static var _timers: Dictionary = {}

static func begin(label: String) -> void:
    _timers[label] = Time.get_ticks_usec()

static func end(label: String) -> void:
    if not _timers.has(label):
        return
    var elapsed := (Time.get_ticks_usec() - _timers[label]) / 1000.0
    if elapsed > 1.0:  # 只打印超过 1ms 的
        print("[Profiler] %s: %.3f ms" % [label, elapsed])
    _timers.erase(label)
```

### 7.7 预期收益

| 优化项 | 当前估算开销 | 优化后估算 | 收益 |
|--------|-------------|-----------|------|
| 尾线 Draw Call | n 段 = n Draw Calls | 1 Draw Call (MultiMesh) | **-95%** |
| 音频节点分配 | 每次播放新建节点 | 池化复用 | **-99%** |
| RoadMaker 物理重建 | 每帧重建碰撞体 | 不再重建 | **-100%** |
| floor_segment_lines 更新 | 每 0.05s O(n) | 脏标记 O(1) | **-80%** |
| GuidanceBox 距离检查 | 每帧 2 次 | 分层 0.1s + 每帧 1 次 | **-50%** |
| DebugOverlay 字符串 | 每帧构造 | 脏标记 | **-90%** |
| 不可见旋转 | 每帧旋转 | 可见时旋转 | **-50%** (非关键路径) |

---

## 八、全局优先级总览（所有计划统一排序）

### 执行顺序建议（综合功能 + 架构 + 性能）

| 顺序 | 优先级 | 任务 | 所属章节 | 预估时间 | 阻塞关系 |
|------|--------|------|----------|----------|----------|
| 1 | **P0** | BaseTrigger 改造（支持子行为收集调度） | 四、4.3 | 1~2 天 | 无 |
| 2 | **P0** | 性能 Phase 1：物理修复 + Audio 池 + 可见性检查 | 七、7.6 | 1~2 天 | 无 |
| 3 | **P1** | 核心 Behavior 组件（Kill/ChangeSpeed/ChangeTurn/Jump/Teleport/SetActive） | 四、4.5 Phase 2 | 2~3 天 | 依赖 #1 |
| 4 | **P1** | 性能 Phase 2：尾线 MultiMesh + 脏标记 + 粒子池 | 七、7.6 | 1~2 天 | 无 |
| 5 | **P1** | 新增功能 Behavior（Gravity/Audio/FadeOut/Fog/Light/Ambient/Particle/ImageColor） | 四、4.5 Phase 3 | 2~3 天 | 依赖 #3 |
| 6 | **P1** | 性能 Phase 3：CPU 优化（GuidanceBox/Overlay/gameui/Quaternion） | 七、7.6 | 1~2 天 | 无 |
| 7 | **P1** | noDeath 标志 + Henshin 变身系统 | 五、P1 | 1 天 | 无 |
| 8 | **P1** | Animator Behavior（TimerLight/TimerAmbient/TimerFog/TimerImageColor/LocalScale） | 四、4.5 Phase 4 | 1~2 天 | 依赖 #3 |
| 9 | **P1** | FollowPlayer 辅助组件 | 五、P1 | 1 天 | 无 |
| 10 | **P1** | 性能 Phase 4：内存与 GC 优化 | 七、7.6 | 1 天 | 无 |
| 11 | **P2** | LoadingPage + LevelUI + GuidanceEnabled | 五、P2 | 2~3 天 | 无 |
| 12 | **P2** | 性能 Phase 5：项目设置与监控 | 七、7.6 | 1 天 | 无 |
| 13 | **P2** | 旧脚本标记 deprecated + 场景迁移 | 四、4.5 Phase 5 | 2~3 天 | 依赖 #3, #5 |
| 14 | **P2** | TimeScale + ActiveByQuality + DisableInPlaymode + TrailRenderer | 五、P2 | 2~3 天 | 无 |
| 15 | **P2** | Editor 工具（GetStartPosition、OnDrawGizmos、GetFrame、C 键音乐时间） | 五、P2 | 1~2 天 | 无 |
| 16 | **P3** | 3D 模型/材质/音乐资产补充 | 五、P3 | 视来源 | 无 |
| 17 | **P3** | TTFCheckPoint 系列 | 五、P3 | 1~2 天 | 无 |

---

*最后更新：2025-06-08*
