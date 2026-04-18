## Context

Godot项目需要从Unity的DancingLineFanmade框架移植两个核心文件：
- `LevelManager.cs`：静态游戏状态管理器，管理GameStatus状态机、玩家死亡/复活流程、检查点数据
- `Pyramid.cs`：金字塔触发器组件，处理开门动画、关卡结束、停止播放等触发类型

当前Godot项目已有：
- `State.gd`：仅处理检查点数据持久化（静态变量+save/load方法）
- `Ending.gd`：仅设置`State.is_end = true`，无任何结束流程
- `CameraFollower.gd`：已有`static var instance`单例
- `Player.gd`：已有死亡逻辑`die()`，但缺少完整的游戏状态管理
- `gameui.gd`：已有UI显示逻辑，依赖`State.is_end`、`State.is_relive`等

## Goals / Non-Goals

**Goals:**
- 创建`LevelManager.gd`作为统一的游戏状态管理中心，替代State.gd的所有功能
- 创建`Pyramid.gd`作为关卡结束触发器，替代Ending.gd的简单逻辑
- 提供完整的GameStatus状态机（Waiting→Playing→Moving→Died/Completed）
- 支持金字塔门动画、关卡结束等待、复活门重置等触发流程

**Non-Goals:**
- 不移植Unity的DOTween依赖，使用Godot内置Tween
- 不移植Unity的UI系统（DialogBox、IsPointedOnUI），Godot有独立UI框架
- 不移植Unity的EditorUtility相关代码
- 不修改Player.gd的死亡逻辑，仅整合状态管理

## Decisions

### Decision 1: LevelManager作为静态类而非Autoload
**Rationale**: 原Unity版LevelManager是纯静态类，Godot中使用`class_name`静态类更接近原始设计。所有状态通过静态变量访问，无需场景节点实例。

### Decision 2: revivePlayer使用Signal而非delegate
**Rationale**: Godot的Signal机制天然支持+=/-=订阅模式，用`signal player_revived`替代C# delegate。

### Decision 3: Pyramid继承BaseTrigger
**Rationale**: Godot项目已有BaseTrigger基类提供body_entered检测和one_shot支持，Pyramid应继承它而非直接继承Area3D。

### Decision 4: GameStatus用enum而非字符串
**Rationale**: 保持与Unity版一致的类型安全，GDScript原生支持enum。

## Risks / Trade-offs

- [大量引用修改] → 使用replaceAll批量替换`State.`为`LevelManager.`
- [camera_checkpoint字典结构保留] → 保持State中camera_checkpoint的字典设计不变，减少迁移风险
- [Ending.tscn场景引用] → 需要更新场景中脚本路径指向Pyramid.gd
