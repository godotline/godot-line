## Why

项目需要从Unity的DancingLineFanmade框架移植LevelManager.cs和Pyramid.cs到Godot。当前Godot项目中State.gd只处理检查点数据持久化，缺少完整的游戏状态机管理。同时Ending.gd只做简单标记，无法处理金字塔开门/结束等待等复杂触发流程。

## What Changes

- **BREAKING**: 删除`State.gd`，创建`LevelManager.gd`替代所有功能
  - 移植`GameStatus`枚举（Waiting/Playing/Moving/Died/Completed）
  - 移植`Direction`枚举（First/Second）
  - 移植游戏状态管理：`GameState`、`Clicked`、`defaultGravity`
  - 移植玩家死亡处理：`PlayerDeath()`、`GameOverNormal()`、`GameOverRevive()`
  - 移植辅助方法：`InitPlayerPosition()`、`DestroyRemain()`、`CompareCheckpointIndex()`、`SetFPSLimit()`、`IsPointedOnUI()`、`CreateTrigger()`、`GetColorByContent()`
  - 保留State.gd中已有的检查点保存/加载逻辑，整合为LevelManager的静态方法
- **BREAKING**: 删除`Ending.gd`，创建`Pyramid.gd`替代
  - 移植`TriggerType`枚举（Open/Final/Waiting/Stop）
  - 移植金字塔门开关动画逻辑（使用Godot Tween替代DOTween）
  - 移植关卡结束流程：Final → Waiting → Stop/Complete
  - 集成`LevelManager.revivePlayer`信号用于门重置
- 修改`CameraFollower.gd`添加单例模式（`static var instance`）
- 更新所有引用`State`的脚本改为引用`LevelManager`

## Capabilities

### New Capabilities
- `level-manager`: 完整的游戏状态机管理，包含GameStatus状态流转、玩家死亡/复活流程、检查点数据持久化
- `pyramid-trigger`: 金字塔触发器，处理开门动画、关卡结束等待、停止播放等状态转换

### Modified Capabilities
- `camera-follower`: 添加单例访问模式，支持`CameraFollower.instance`全局访问

## Impact

- 删除文件：`State.gd`、`Ending.gd`
- 新增文件：`LevelManager.gd`、`Pyramid.gd`
- 修改文件：`CameraFollower.gd`、`Player.gd`、`gameui.gd`、`Checkpoint.gd`、`Crown.gd`、所有引用State的脚本
- 场景文件：可能需要更新Ending.tscn引用改为Pyramid
