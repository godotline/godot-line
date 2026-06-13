# GodotLine TODO — 冰焰模板 V4.7.6 对照表（修订版）

与 `D:\Code\dl\MTPIDM001-Introduction\Assets\#Template\`（Unity 冰焰模板 V4.7.6）逐项对比。

---

## 一、功能对齐总览

| 优先级 | 分类 | 功能 | Unity | Godot | 备注 |
|--------|------|------|:-----:|:-----:|------|
| P0 | Trigger | KillPlayer | ✓ | ✓ | 纯组件模式，接触即死触发器（Hit/Drowned/Border 三种模式 + 自定义音效） |
| P0 | Level | AudioManager | ✓ | ✓ | 静态类，音效池 `play_clip()`、音乐控制 `play_track()/fade_out()/stop()`、音量/进度/音高 |
| P0 | Trigger | Teleport | ✓ | ✓ | Target/Position 两种模式，ForceCameraFollow，Turn 转向 |
| P0 | Trigger | SetActive | ✓ | ✓ | `SetActive.gd`（纯组件），revive 恢复逻辑，支持 `active_on_awake` |
| P1 | Level | FakePlayer 系统 | ✓ | ✓ | 假线（FakePlayer.gd + FakePlayerTransport + FakePlayerTrigger） |
| P1 | Trigger | FakePlayerTrigger | ✓ | ✓ | 三种模式：Turn / ChangeDirection / SetState，旧模式 Area3D |
| P1 | Trigger | GravityTrigger | ✓ | ✗ | **未实现** — 更改场景重力 |
| P1 | Trigger | PlayAudioClip | ✓ | ✗ | **未实现** — 触发播放音效（支持 Trigger 和事件两种模式） |
| P1 | Trigger | FadeOutMusic | ✓ | ⚠️ | AudioManager 已有 `fade_out()`，缺 Trigger 封装组件 |
| P1 | Trigger | SetFog / FogTrigger | ✓ | ✓ | `SetFog.gd` 已使用 FogSettings 资源，Tween 过渡 |
| P1 | Trigger | SetLight | ✓ | ✗ | **未实现** — 更改定向光源（Rotation/Color/Intensity/ShadowStrength） |
| P1 | Trigger | SetAmbient | ✓ | ✗ | **未实现** — 更改环境光源类型 |
| P1 | Trigger | SetImageColor | ✓ | ✗ | **未实现** — 更改 UI Image 颜色 |
| P1 | Trigger | Gem / Crystal | ✓ | ✓ | `Gem.gd`（旧模式 Area3D），使用 `LevelManager.gem` 计数，支持 fake 属性和复活恢复 |
| P1 | Level | FollowPlayer | ✓ | ✗ | **未实现** — 物体跟随玩家的辅助组件 |
| P1 | Animator | LocalScaleAnimator | ✓ | ✗ | **未实现** — 缩放时间动画 |
| P1 | Animator | TimerLight (定向光源) | ✓ | ✗ | **未实现** — 时间驱动的光源动画 |
| P1 | Animator | TimerAmbient (环境光) | ✓ | ✗ | **未实现** — 时间驱动的环境光动画 |
| P1 | Animator | TimerFog (雾气) | ✓ | ✓ | SetFog.gd + FogSettings 已支持时间驱动的完整雾设置 |
| P1 | Animator | TimerImageColor | ✓ | ✗ | **未实现** — 时间驱动的 Image 颜色动画 |
| P2 | GUI | StartPage | ✓ | ✓ | 开始页面 UI（含 About 面板动画、延迟/音量/画质/抗锯齿设置、Autoplay/Shadow/Post 开关） |
| P2 | GUI | LoadingPage | ✓ | ✗ | **未实现** — 加载页面 UI |
| P2 | GUI | LevelUI | ✓ | ✗ | **未实现** — 关卡内 UI（包含游戏内信息显示） |
| P2 | GUI | SetQuality | ✓ | ⚠️ | UI 完成（AntiAliasing + Quality 循环选项），信号接口暴露，待接入 QualitySettings |
| P2 | GUI | SetLatency | ✓ | ✓ | SetLatency.gd 完成，延迟语义对齐 Unity StartGame，ConfigFile 持久化 |
| P2 | GUI | KeyBoardFunctionsDisplay | ✓ | ✓ | 顶部提示栏 "R/K/D" 快捷键显示 |
| P2 | GUI | SettingItem 排版优化 | — | ✓ | 两行排版（标题在上，◄ 数值 ► 在下），◄/► 箭头符号 |
| P2 | GUI | GuidanceEnabled | ✓ | ✗ | **未实现** — 引导线启用按钮（AutoPlay 开关已有，缺 UI 按钮） |
| P2 | GUI | HideCanvas / ShowCanvas | ✓ | ✓ | About 面板动画显隐（ShowCanvas/HideCanvas 等效） |
| P2 | Level | ObjectPool | ✓ | ✓ | 通用对象池（线身、粒子等复用），含 TailPool 256 容量 |
| P2 | Trigger | ParticleSystemPlay | ✓ | ✗ | **未实现** — 触发位置播放粒子效果 |
| P2 | Trigger | Henshin | ✓ | ✗ | **未实现** — 变身（模型/材质切换） |
| P2 | Trigger | AchievementTrigger | ✓ | ✗ | **未实现** — 成就系统触发器 |
| P2 | Trigger | ACChanger | ✓ | ✗ | **未实现** — 音频配置切换（需先有 AudioManager） |
| P2 | Level | TimeScale | ✓ | ⚠️ | LevelData 已有 `timeScale` 字段并在 `apply_to()` 中应用 `Engine.time_scale`，但缺编辑器 UI 控制 |
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
| — | 系统 | BaseTrigger | ✓ | ✓ | Area3D 触发器基类，含 one_shot、require_playing、track_exit、debug_mode |
| — | 系统 | Trigger | ✓ | ✗ | 原 `Trigger.gd`（`hit_the_line` 信号）已删除，由 BaseTrigger 替代 |
| — | 系统 | Checkpoint | ✓ | ✓ | 检查点（全状态记录 + 恢复），含相机/雾/光/环境光/材质颜色 |
| — | 系统 | CrownCheckpoint | ✓ | ✓ | 皇冠检查点（粒子特效 + 精灵过渡动画） |
| — | 系统 | HeartCheckpoint | ✓ | ✓ | 爱心检查点（旋转动画 + 缩放弹跳） |
| — | 系统 | Jump | ✓ | ✓ | 跳跃触发器（纯组件模式），含 JumpPredictor/FallPredictor |
| — | 系统 | ChangeTurn / ChangeDirection | ✓ | ✓ | Direction/Turn 两种模式（纯组件） |
| — | 系统 | ChangeSpeed / Speed | ✓ | ✓ | 速度改变触发器（纯组件 `Speed.gd`），即时同步速度向量 |
| — | 系统 | EventTrigger | ✓ | ✓ | 事件分发触发器（纯组件），支持 onclick 模式和复活恢复 |
| — | 系统 | PlayAnimator / CustomAnimPlay | ✓ | ✓ | 播放帧动画（纯组件），含进度记录和复活恢复 |
| — | 系统 | SetMaterialColor | ✓ | ✓ | 材质颜色动画（纯组件），Tween 过渡 + emission 支持 |
| — | 系统 | SetActiveTrigger | ✓ | ✓ | 激活/禁用节点（纯组件 `SetActive.gd`），revive 恢复 |
| — | 系统 | Pyramid / PyramidTrigger | ✓ | ✓ | 金字塔关卡结尾系统（Pyramid 管理节点 + PyramidTrigger 自容器） |
| — | 系统 | FallPredictor / JumpPredictor | ✓ | ✓ | 下落/跳跃轨迹预测 |
| — | 系统 | CameraFollower | ✓ | ✓ | 新相机跟随系统（Tween 驱动，offset/rotation/scale/fov/shake） |
| — | 系统 | OldCameraFollower | ✓ | ✓ | 旧相机跟随系统（lerp/slerp 驱动，多种旋转模式） |
| — | 系统 | CameraTrigger | ✓ | ✓ | 视角变换触发器（Area3D，新相机系统） |
| — | 系统 | OldCameraTrigger | ✓ | ✓ | 旧视角变换触发器（Area3D，旧相机系统，4 种旋转模式） |
| — | 系统 | CameraShakeTrigger | ✓ | ✓ | 相机震动（新相机系统，Area3D） |
| — | 系统 | OldCameraShakeTrigger | ✓ | ✓ | 旧相机震动（BaseTrigger 自容器） |
| — | 系统 | CameraColorFromSprite | ✓ | ✓ | 从贴图采样相机背景色 |
| — | 系统 | PropertyModifierTrigger | — | ✓ | **Godot 新增** — 通用属性修改触发器（自容器模式），支持 Tween + 复活恢复 |
| — | 系统 | AnimatorBase | ✓ | ✓ | 时间动画基类，含 editor 预览按钮和复活恢复 |
| — | 系统 | LocalPosAnimator | ✓ | ✓ | 位移时间动画 |
| — | 系统 | LocalRotAnimator | ✓ | ✓ | 旋转时间动画 |
| — | 系统 | PosAnimator | ✓ | ✓ | 全局位移动画 |
| — | 系统 | MovingPosMax | ✓ | ✓ | 路径点序列动画 |
| — | 系统 | LevelData | ✓ | ✓ | 关卡信息资源文件（含 timeScale/gravity/authors/colors） |
| — | 系统 | CameraSettings / OldCameraSettings | ✓ | ✓ | 相机配置 |
| — | 系统 | FogSettings | ✓ | ✓ | 雾气配置 |
| — | 系统 | LightSettings | ✓ | ✓ | 光源配置 |
| — | 系统 | AmbientSettings | ✓ | ✓ | 环境光配置 |
| — | 系统 | SingleColor | ✓ | ✓ | 材质颜色覆盖资源 |
| — | 系统 | SingleActive | — | ✓ | **Godot 新增** — 激活配置资源（target/active/dont_revive） |
| — | 系统 | AuthorInfo | — | ✓ | **Godot 新增** — 作者信息资源（name/page_url） |
| — | 系统 | SetLatency | — | ✓ | **Godot 新增** — 音画延迟/音量持久化工具（ConfigFile） |
| — | 系统 | GuidanceBox / GuidanceController | ✓ | ✓ | 引导线系统 |
| — | 系统 | AutoPlay / AutoPlayController | ✓ | ✓ | 自动播放系统（SetAutoPlay 开关） |
| — | 系统 | BeatmapReader / NoteReader | ✓ | ✓ | .osu 谱面导入 |
| — | 系统 | Player | ✓ | ✓ | 玩家角色（CharacterBody3D），含 land_effect 粒子 |
| — | 系统 | LevelManager | ✓ | ✓ | 游戏状态机（静态 RefCounted），含 revive 监听器系统 |
| — | 系统 | Percentage | ✓ | ✓ | 百分比标记（编辑器工具） |
| — | 系统 | RoadMaker | ✓ | ✓ | 路径生成（S 键保存） |
| — | 系统 | GameUI | ✓ | ✓ | 游戏结束 UI（皇冠/宝石统计 + 复活/重玩） |
| — | 系统 | DeathParticle | ✓ | ✓ | 死亡粒子（8 段碎片 + 随机冲量/扭矩） |
| — | 系统 | DebugOverlay | ✓ | ✓ | 调试信息覆盖层（FPS/坐标/朝向/状态/宝石/皇冠/相机） |
| — | 系统 | MPM Importer 插件 | — | ✓ | **Godot 新增** — .mpm 格式导入器（CameraTrigger/AnimatorPlayer/MovingPosMax） |
| — | 系统 | PortTookits | — | ✓ | **Godot 新增** — Unity 迁移辅助工具集 |

**图例**: ✓ = 已完成, ⚠️ = 需验证/部分完成/命名不同, ✗ = 未实现, — = Godot 新增或 Unity 无此功能

---

## 二、优先级说明

| 优先级 | 含义 | 工作量估计 |
|--------|------|-----------|
| **P0** | 功能缺失导致关卡制作受限或流程卡死 | 小 |
| **P1** | 重要功能，模板核心差异 | 中 ~ 大 |
| **P2** | 增强体验和完善性，非必须 | 中 |
| **P3** | 素材资产补充 | 视素材来源而定 |
| **—** | 已对齐或 Godot 新增，无需处理 | 0 |

---

## 三、完成统计

| 类别 | 总计 | ✓ 已完成 | ⚠️ 部分/待验证 | ✗ 未实现 |
|------|:---:|:--------:|:-------------:|:--------:|
| Trigger | 29 | 14 | 1 | 9 |
| Level | 10 | 5 | 1 | 4 |
| Animator | 6 | 3 | 1 | 2 |
| GUI | 9 | 5 | 1 | 2 |
| Player | 9 | 3 | 0 | 6 |
| Editor | 1 | 0 | 0 | 1 |
| Assets | 2 | 0 | 0 | 2 |
| **已对齐系统** | 33 | 33 | 0 | 0 |

> 注：Trigger 统计包含 Godot 新增的 PropertyModifierTrigger；已对齐系统包含 Godot 新增的 SingleActive/AuthorInfo/SetLatency/MPM Importer/PortTookits

---

## 四、详细任务列表（按优先级排序）

### P0 — 关键修复
- [x] ~~**Trigger 系统组件化重构**~~ — 已完成，见 `Comp.md`。三种模式共存（纯组件/自容器/旧模式），稳定运行

### P1 — 核心功能补齐
- [ ] **GravityTrigger** — 更改场景重力，revive 恢复（LevelData 已有 gravity 字段和 apply_to，缺 Trigger 组件封装）
- [ ] **PlayAudioClip** — 触发播放音效，支持 Trigger/事件模式
- [ ] **FadeOutMusic** — 淡出背景音乐 Trigger 组件封装（AudioManager.fade_out 已有，缺 Node3D 组件）
- [ ] **SetLight** — 更改定向光源 Rotation/Color/Intensity/Shadow（Checkpoint 已有 _capture_light/_restore_light，缺独立 Trigger）
- [ ] **SetAmbient** — 更改环境光源类型（Checkpoint 已有 _capture_ambient/_restore_ambient，缺独立 Trigger）
- [ ] **SetImageColor** — 更改 UI Image 颜色
- [ ] **FollowPlayer** — 物体跟随玩家辅助组件
- [ ] **noDeath 标志** — Player.gd 添加 `no_death` 字段，KillPlayer 检查跳过
- [ ] **Henshin 变身系统** — Player.gd 双材质切换

### P1 — Animator 补齐
- [ ] **LocalScaleAnimator** — 缩放时间动画
- [ ] **TimerLight** — 时间驱动定向光源动画
- [ ] **TimerAmbient** — 时间驱动环境光动画
- [x] ~~**TimerFog**~~ — 已由 SetFog.gd + FogSettings 覆盖
- [ ] **TimerImageColor** — 时间驱动 Image 颜色动画

### P2 — 体验增强
- [ ] **LoadingPage** — 加载页面 UI
- [ ] **LevelUI** — 关卡内 UI
- [ ] **GuidanceEnabled** — 引导线启用 UI 按钮
- [ ] **ParticleSystemPlay** — 触发位置播放粒子效果
- [ ] **AchievementTrigger** — 成就系统触发器
- [ ] **ACChanger** — 音频配置切换
- [ ] **TimeScale** — 编辑器全局时间倍速 UI 控制（LevelData.timeScale 已实现运行时缩放）
- [ ] **ActiveByQuality** — 根据画质等级启用/禁用对象
- [ ] **DisableInPlaymode** — 运行时隐藏编辑器辅助对象
- [ ] **TrailRenderer** — 编辑器路径高亮 + 点击时间显示
- [ ] **C 键输出音乐时间** — 编辑器快捷键
- [ ] **sceneCamera / sceneLight 直接引用** — Player.gd 缓存引用
- [ ] **playedAnimators / playedTimelines** — 跟踪已播放动画器用于存档恢复
- [ ] **Editor 工具** — GetStartPosition 按钮、OnDrawGizmos、GetFrame FPS

### P3 — 资产补充
- [ ] **3D 模型/材质补充** — 水、自然包、云、环、BonusBox、Fragment、Heart 等（当前 3 模型 + 5 材质）
- [ ] **音乐文件补充** — Phigros_Intro, SampleTrack, Shake_It_Up, nevva（当前 1 首 Sample.mp3）
- [ ] **TTFCheckPoint 系列** — 主题化存档点

---

## 五、Trigger 系统架构（当前状态）

### 5.1 三种共存模式

| 模式 | 基类 | 碰撞由谁处理 | 文件数 |
|------|------|-------------|--------|
| **纯组件** | `extends Node3D` | 父节点 BaseTrigger | 14 |
| **自容器** | `extends BaseTrigger` (即 Area3D) | 自身继承 BaseTrigger | 2 |
| **旧模式** | `extends Area3D` | 自身处理 body_entered | 6 (+2 继承 Checkpoint) |

### 5.2 纯组件列表

作为 BaseTrigger 的子节点，通过 `trigger(body)` 方法被调用：

| 文件 | 入口方法 | 备注 |
|------|---------|------|
| `Jump.gd` | `trigger(body)` | 跳跃 + JumpPredictor/FallPredictor |
| `SetFog.gd` | `trigger(body)` | FogSettings + Tween 过渡 |
| `Pyramid.gd` | 无（管理节点） | 由 PyramidTrigger 调用 |
| `EventTrigger.gd` | `trigger(body)` + `on_exit(body)` | 多目标调用 + onclick 模式 |
| `PlayAnimator.gd` | `trigger(body)` | AnimationPlayer 播放 + 复活恢复 |
| `SetActive.gd` | `trigger(body)` | 激活/禁用节点 + revive 恢复 |
| `SetMaterialColor.gd` | `trigger(body)` | material_override + Tween |
| `Teleport.gd` | `trigger(body)` | Target/Position 传送 + 转向 |
| `KillPlayer.gd` | `trigger(body)` | Hit/Drowned/Border + 自定义音效 |
| `ChangeDirection.gd` | `trigger(body)` | Direction/Turn 两种模式 |
| `Speed.gd` | `trigger(body)` | 修改 speed + 即时同步速度向量 |
| `JumpPredictor.gd` | 无（工具类） | 跳跃轨迹预测可视化 |
| `FallPredictor.gd` | 无（工具类） | 下落轨迹预测可视化 |

### 5.3 自容器列表

| 文件 | class_name | 备注 |
|------|-----------|------|
| `PyramidTrigger.gd` | — | 调用父节点 Pyramid 的 `trigger(type)` |
| `PropertyModifierTrigger.gd` | `PropertyModifierTrigger` | 通用属性修改 + Tween + 复活恢复 |
| `OldCameraShakeTrigger.gd` | — | 旧相机系统震动（BaseTrigger 自容器） |

### 5.4 旧模式列表

| 文件 | class_name | 备注 |
|------|-----------|------|
| `Gem.gd` | — | 宝石收集 + fake 属性 + 复活恢复 |
| `Checkpoint.gd` | `Checkpoint` | 全状态存档点（符合单一职责，无需迁移） |
| `Crown.gd` | — | 继承 Checkpoint，皇冠粒子动画 |
| `HeartCheckpoint.gd` | — | 继承 Checkpoint，旋转动画 + 弹跳 |
| `FakePlayerTransport.gd` | `FakePlayerTransport` | 传送 FakePlayer |
| `FakePlayerTrigger.gd` | `FakePlayerTrigger` | 控制 FakePlayer 转向/方向/状态 |
| `CameraTrigger.gd` | `CameraTrigger` | 新相机视角变换 |
| `OldCameraTrigger.gd` | — | 旧相机视角变换 |
| `CameraShakeTrigger.gd` | `CameraShakeTrigger` | 新相机震动 |

---

## 六、性能优化计划

### 6.1 性能现状分析

| 严重程度 | 问题领域 | 具体问题 |
|----------|----------|----------|
| **高** | 物理 | ~~`_physics_process` 中 `move_and_slide()` 调用顺序错误~~ 已修复（先 gravity 再 move_and_slide） |
| **高** | 渲染 | Player 尾线每段独立 `MeshInstance3D`，Draw Call 线性增长 |
| **高** | 渲染 | RoadMaker 每帧缩放 `StaticBody3D.scale` 触发物理重建 |
| **中** | 内存 | AudioManager 每次播放新建 `AudioStreamPlayer`（播放完自动 queue_free） |
| **中** | CPU | Crown/HeartCheckpoint 每帧旋转，无可见性检查 |
| **中** | CPU | GuidanceBox 每帧两次距离计算 |
| **低** | CPU | OldCameraFollower 每帧 3 次 `lerp_angle` |
| **低** | CPU | DebugOverlay 使用定时器轮询 debug 状态（0.5s 间隔） |

### 6.2 优化方案

#### Phase 1：紧急优化（P0）
- [x] ~~修复 `move_and_slide()` 调用顺序~~ — 已修复
- [ ] RoadMaker 视觉/碰撞分离
- [ ] AudioManager 对象池
- [ ] 可见性检查

#### Phase 2：渲染优化（P1）
- [ ] 尾线 MultiMesh
- [ ] floor_segment_lines 脏标记
- [ ] 死亡粒子对象池

#### Phase 3：CPU 优化（P1）
- [ ] GuidanceBox 分层更新
- [ ] DebugOverlay 脏标记（已用定时器轮询替代 _process 空跑）
- [ ] gameui 信号驱动
- [ ] OldCameraFollower Quaternion slerp

---

## 七、已删除/重命名的文件

| 旧文件 | 新文件 | 说明 |
|--------|--------|------|
| `Trigger.gd` | — | 已删除，由 BaseTrigger 替代 |
| `jump.gd` | `Jump.gd` | 从 Area3D 迁移到 Node3D 纯组件 |
| `ChangeSpeedTrigger.gd` | `Speed.gd` | 重命名，纯组件模式 |
| `SetActiveTrigger.gd` | `SetActive.gd` | 重命名，纯组件模式 |
| `customanimplay.gd` | — | 已删除（功能由 PlayAnimator.gd 覆盖） |

---

## 八、Godot 新增功能（Unity 模板无对应）

| 文件/功能 | 类型 | 说明 |
|-----------|------|------|
| `PropertyModifierTrigger.gd` | 自容器触发器 | 通用属性修改，支持 Tween 和复活恢复 |
| `SingleActive.gd` | Resource | 激活配置（target/active/dont_revive） |
| `AuthorInfo.gd` | Resource | 作者信息（name/page_url），LevelData 使用 |
| `SetLatency.gd` | RefCounted 工具 | 音画延迟/音量 ConfigFile 持久化 |
| `addons/mpm_importer/` | Editor 插件 | .mpm 格式导入器（CameraTrigger/AnimatorPlayer/MovingPosMax） |
| `#Template/[Scripts]/PortTookits/` | Editor 工具集 | Unity 迁移辅助（addcol/addtap/alladdcol/animationcut/animfix/animloopfix） |
| `docs/superpowers/` | 文档 | Trigger Actions 重构计划和设计规格 |

---

## 九、待定重构计划

Trigger Actions 重构计划（`docs/superpowers/plans/2026-06-06-trigger-actions-refactor.md`）已编写但**尚未执行**。计划将现有三种触发器模式统一为 `BaseTrigger + TriggerAction child nodes` 架构，并包含编辑器迁移脚本。

- [ ] **评估是否执行 Trigger Actions 重构** — 当前三种模式稳定运行，重构优先级较低

---

*最后更新：2026-06-13*
