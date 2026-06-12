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
| P1 | Animator | TimerFog (雾气) | ✓ | ⚠️ | `FogColorChanger.gd` 只改颜色，缺 Start/End 动画 |
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

## 四、详细任务列表（按优先级排序）

### P0 — 关键修复
- [ ] **Trigger 组件化重构** — 见 `Comp.md`

### P1 — 核心功能补齐
- [ ] **GravityTrigger** — 更改场景重力，revive 恢复
- [ ] **PlayAudioClip** — 触发播放音效，支持 Trigger/事件模式
- [ ] **FadeOutMusic** — 淡出背景音乐，revive 恢复音量
- [ ] **FogTrigger** — Area3D 触发模式 + Start/End 动画
- [ ] **SetLight** — 更改定向光源 Rotation/Color/Intensity/Shadow
- [ ] **SetAmbient** — 更改环境光源类型
- [ ] **SetImageColor** — 更改 UI Image 颜色
- [ ] **FollowPlayer** — 物体跟随玩家辅助组件
- [ ] **noDeath 标志** — Player.gd 添加 `no_death` 字段，KillPlayer 检查跳过
- [ ] **Henshin 变身系统** — Player.gd 双材质切换

### P1 — Animator 补齐
- [ ] **LocalScaleAnimator** — 缩放时间动画
- [ ] **TimerLight** — 时间驱动定向光源动画
- [ ] **TimerAmbient** — 时间驱动环境光动画
- [ ] **TimerFog** — 时间驱动雾效 Start/End 动画
- [ ] **TimerImageColor** — 时间驱动 Image 颜色动画

### P2 — 体验增强
- [ ] **LoadingPage** — 加载页面 UI
- [ ] **LevelUI** — 关卡内 UI
- [ ] **GuidanceEnabled** — 引导线启用 UI 按钮
- [ ] **ParticleSystemPlay** — 触发位置播放粒子效果
- [ ] **AchievementTrigger** — 成就系统触发器
- [ ] **ACChanger** — 音频配置切换
- [ ] **TimeScale** — 编辑器全局时间倍速控制
- [ ] **ActiveByQuality** — 根据画质等级启用/禁用对象
- [ ] **DisableInPlaymode** — 运行时隐藏编辑器辅助对象
- [ ] **TrailRenderer** — 编辑器路径高亮 + 点击时间显示
- [ ] **C 键输出音乐时间** — 编辑器快捷键
- [ ] **sceneCamera / sceneLight 直接引用** — Player.gd 缓存引用
- [ ] **playedAnimators / playedTimelines** — 跟踪已播放动画器用于存档恢复
- [ ] **Editor 工具** — GetStartPosition 按钮、OnDrawGizmos、GetFrame FPS

### P3 — 资产补充
- [ ] **3D 模型/材质补充** — 水、自然包、云、环、BonusBox、Fragment、Heart 等
- [ ] **音乐文件补充** — Phigros_Intro, SampleTrack, Shake_It_Up, nevva
- [ ] **TTFCheckPoint 系列** — 主题化存档点

---

## 五、性能优化计划

### 5.1 性能现状分析

| 严重程度 | 问题领域 | 具体问题 |
|----------|----------|----------|
| **高** | 物理 | `_physics_process` 中 `move_and_slide()` 调用顺序错误 |
| **高** | 渲染 | Player 尾线每段独立 `MeshInstance3D`，Draw Call 线性增长 |
| **高** | 渲染 | RoadMaker 每帧缩放 `StaticBody3D.scale` 触发物理重建 |
| **高** | 内存 | AudioManager 每次播放新建 `AudioStreamPlayer` |
| **中** | CPU | Crown/HeartCheckpoint 每帧旋转，无可见性检查 |
| **中** | CPU | GuidanceBox 每帧两次距离计算 |
| **低** | CPU | OldCameraFollower 每帧 3 次 `lerp_angle` |

### 5.2 优化方案

#### Phase 1：紧急优化（P0）
- [ ] 修复 `move_and_slide()` 调用顺序
- [ ] RoadMaker 视觉/碰撞分离
- [ ] AudioManager 对象池
- [ ] 可见性检查

#### Phase 2：渲染优化（P1）
- [ ] 尾线 MultiMesh
- [ ] floor_segment_lines 脏标记
- [ ] 死亡粒子对象池

#### Phase 3：CPU 优化（P1）
- [ ] GuidanceBox 分层更新
- [ ] DebugOverlay 脏标记
- [ ] gameui 信号驱动
- [ ] OldCameraFollower Quaternion slerp

---

*最后更新：2025-06-12*
