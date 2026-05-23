# GodotLine TODO — 冰焰模板 V4.7.6 对照表

与 `D:\Code\dl\MTPIDM001-Introduction\Assets\#Template\`（Unity 冰焰模板 V4.7.6）逐项对比。

| 优先级 | 分类 | 功能 | Unity | Godot | 备注 |
|--------|------|------|:-----:|:-----:|------|
| P0 | Trigger | KillPlayer | ✓ | ✗ | 接触即死触发器（落水/出图/撞墙三种模式） |
| P0 | Level | AudioManager | ✓ | ✗ | 音乐管理、音效池、音量控制、淡入淡出 |
| P0 | Trigger | Teleport | ✓ | ⚠️ | `LocalTeleportTrigger.gd` 缺少 ForceCameraFollow、Turn 模式 |
| P0 | Trigger | SetActive | ✓ | ⚠️ | `SetActiveTrigger.gd` 需验证 revive 恢复逻辑 |
| P1 | Level | FakePlayer 系统 | ✓ | ✗ | 假线（含 FakePlayer.cs + FakePlayerTransport + FakePlayerTrigger） |
| P1 | Trigger | FakePlayerTrigger | ✓ | ✗ | 三种模式：Turn / ChangeDirection / SetState |
| P1 | Trigger | GravityTrigger | ✓ | ✗ | 更改场景重力 |
| P1 | Trigger | KillPlayer | ✓ | ✗ | 落水/出图/撞墙死亡方式 |
| P1 | Trigger | PlayAudioClip | ✓ | ✗ | 触发播放音效（支持 Trigger 和事件两种模式） |
| P1 | Trigger | FadeOutMusic | ✓ | ✗ | 淡出背景音乐 |
| P1 | Trigger | SetFog / FogTrigger | ✓ | ⚠️ | `FogColorChanger.gd` 是 Node3D 非 Area3D，缺少 Trigger 模式 |
| P1 | Trigger | SetLight | ✓ | ✗ | 更改定向光源（Rotation/Color/Intensity/ShadowStrength） |
| P1 | Trigger | SetAmbient | ✓ | ✗ | 更改环境光源类型 |
| P1 | Trigger | SetImageColor | ✓ | ✗ | 更改 UI Image 颜色 |
| P1 | Trigger | Gem / Crystal | ✓ | ⚠️ | 有 `Gem.tscn` 和 `Diamond.gd`，但缺少 Crystal 和 Gem 的自定义模型/效果路径 |
| P1 | Level | FollowPlayer | ✓ | ✗ | 物体跟随玩家的辅助组件 |
| P1 | Animator | LocalScaleAnimator | ✓ | ✗ | 缩放时间动画 |
| P1 | Animator | TimerLight (定向光源) | ✓ | ✗ | 时间驱动的光源动画 |
| P1 | Animator | TimerAmbient (环境光) | ✓ | ✗ | 时间驱动的环境光动画 |
| P1 | Animator | TimerFog (雾气) | ✓ | ⚠️ | `FogColorChanger.gd` 只改颜色，缺少 Start/End 动画 |
| P1 | Animator | TimerImageColor | ✓ | ✗ | 时间驱动的 Image 颜色动画 |
| P2 | GUI | StartPage | ✓ | ✗ | 开始页面 UI |
| P2 | GUI | LoadingPage | ✓ | ✗ | 加载页面 UI |
| P2 | GUI | LevelUI | ✓ | ✗ | 关卡内 UI（包含游戏内信息显示） |
| P2 | GUI | SetQuality | ✓ | ✗ | 画质设置菜单 |
| P2 | GUI | SetLatency | ✓ | ✗ | 延迟设置菜单 |
| P2 | GUI | KeyBoardFunctionsDisplay | ✓ | ✗ | 按键功能提示显示 |
| P2 | GUI | GuidanceEnabled | ✓ | ✗ | 引导线启用按钮 |
| P2 | GUI | HideCanvas / ShowCanvas | ✓ | ✗ | 画布显隐控制 |
| P2 | Level | ObjectPool | ✓ | ✗ | 通用对象池（线身、粒子等复用） |
| P2 | Trigger | ParticleSystemPlay | ✓ | ✗ | 触发位置播放粒子效果 |
| P2 | Trigger | Henshin | ✓ | ✗ | 变身（模型/材质切换） |
| P2 | Trigger | AchievementTrigger | ✓ | ✗ | 成就系统触发器 |
| P2 | Trigger | ACChanger | ✓ | ✗ | 音频配置切换（需先有 AudioManager） |
| P2 | Level | TimeScale | ✓ | ✗ | 全局时间倍速控制（仅编辑器可用） |
| P2 | Level | ActiveByQuality | ✓ | ✗ | 根据画质等级启用/禁用对象 |
| P2 | Level | DisableInPlaymode | ✓ | ✗ | 运行时隐藏编辑器辅助对象 |
| P2 | Editor | TrailRenderer (路径高亮) | ✓ | ✗ | 编辑器内路径高亮 + 点击时间显示 |
| P2 | Player | C 键输出音乐时间 | ✓ | ✗ | 编辑器快捷键，在控制台输出当前音乐时间 |
| P2 | Player | 事件系统 | ✓ | ⚠️ | Player.gd 缺少部分事件（OnGameAwake, OnPlayerStart, OnLeaveGround, OnTouchGround, OnGetGem, OnPlayerJump） |
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

## 优先级说明

| 优先级 | 含义 | 工作量估计 |
|--------|------|-----------|
| **P0** | 功能缺失导致关卡制作受限或流程卡死 | 小 |
| **P1** | 重要功能，模板核心差异 | 中 ~ 大 |
| **P2** | 增强体验和完善性，非必须 | 中 |
| **P3** | 素材资产补充 | 视素材来源而定 |
| **—** | 已对齐，无需处理 | 0 |

## 完成统计

| 类别 | 总计 | ✓ 已完成 | ⚠️ 部分/待验证 | ✗ 未实现 |
|------|:---:|:--------:|:-------------:|:--------:|
| Trigger | 21 | 10 | 4 | 7 |
| Level | 7 | 2 | 0 | 5 |
| Animator | 6 | 3 | 1 | 2 |
| GUI | 8 | 0 | 0 | 8 |
| Player | 1 | 0 | 1 | 0 |
| Editor | 1 | 0 | 1 | 0 |
| Assets | 2 | 0 | 0 | 2 |
| **已对齐系统** | 25 | 25 | 0 | 0 |
