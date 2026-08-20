# AGENTS.md — Godot Line

## 项目概览

- **引擎版本**：Godot 4.7（Dancing Line / 跳舞的线 游戏模板，GDScript）。`project.godot` 为准。
- **物理与渲染**：Jolt Physics（独立线程运行）；渲染器为 Mobile。
- **开发方式**：无 CLI 自动化测试/构建/Lint，所有开发与调试以 Godot 编辑器为准。

## 调研与开发工具规则

- **网络搜索**：使用 Tavily 工具查询 Godot API 与已知问题。**严禁通过 curl/下载引擎源码文件**，优先使用文档与搜索结果。
- **源码与架构查询**：使用 **DeepWiki MCP**（`godotengine/godot` 等）查询引擎内部实现细节（如 `ScriptServer`、`can_instantiate()` 机制）。
- **编辑器实时检查**：优先使用 `gdmcp` 工具（端口 9080）与正在运行的 Godot 编辑器交互（检查脚本状态、Expression 求值、查看日志、分析脚本语法）。

## 项目目录结构

```
#Template/             — 核心模板：场景、脚本、资源、材质
  [Scripts]/           — GDScript 源码目录（全部带有显式静态类型）
  [Resources]/         — PackedScene、LevelData、模型、UI
  [Materials]/         — .tres 材质资源
  [Music]/             — 音频文件
  [Scenes]/            — 模板关卡场景（DefaultScene/、Sample/，供"新建关卡"插件克隆）
  *.tscn               — 核心通用场景（Player、Trigger、Gem 等直接位于 #Template/ 根目录）
[Scenes]/              — 用户创建的关卡（由"新建关卡"插件生成至此）
addons/
  godot_mcp/           — MCP 服务插件（非必要请勿修改）
  template/            — 编辑器插件：顶部工具栏菜单与"新建关卡"对话框
```

## 触发器系统 (Trigger System)

项目中存在三种触发器模式，**所有新触发器必须采用模式 1（纯组件）**：

| 模式 | 基类 | 碰撞检测负责者 | 示例 |
|------|------|---------------|------|
| **模式 1：纯组件（推荐）** | `extends Node` / `Node3D` | 父级 `BaseTrigger` 节点 | `Jump.gd`, `Gem.gd`, `Checkpoint.gd`, `Speed.gd` |
| **模式 2：自包含** | `extends BaseTrigger` (Area3D) | 自身 | `OldCameraShakeTrigger.gd` |
| **模式 3：遗留模式** | `extends Area3D` | 自身监听 `body_entered` | `OldCameraTrigger.gd`, `CameraShakeTrigger.gd`, `GuidanceBox.gd` |

### 模式 1 规范
- 实现 `trigger(body)` 方法即可。
- 作为 `BaseTrigger`（或 `Trigger.tscn` 实例）的子节点放置。
- `BaseTrigger` 采用鸭子类型（`has_method("trigger")`）自动遍历并调用子节点。
- `BaseTrigger` 参数：`one_shot`（单次触发）、`require_playing`（需游戏运行中）、`track_exit`、`debug_mode`。

## 通用添加组件面板 (Inspector 插件)

- 位于 `addons/template/component_inspector_plugin.gd`，在每个 Node 的 Inspector 底部注册"组件"面板。
- 点击调用 `EditorInterface.popup_quick_open` 选择脚本并作为子节点挂载，支持 Undo/Redo 并自动维护节点 owner。
- **注意**：在 Godot 4.7 编辑器中，非 `@tool` 脚本的 `Script.can_instantiate()` 设计上返回 `false`（因编辑器禁用了非工具脚本实例化环境），但 `script.new()` 可正常使用。工具脚本中切勿使用 `can_instantiate()` 作为合法性校验守卫。

## 核心单例与架构

所有核心管理器均为 **`RefCounted` 静态类**（非 Node，不可使用传统生命周期 `_process` 或节点信号）：

- **`LevelManager`** (`class_name LevelManager`)：游戏状态机（`GameStatus` 枚举）、检查点数据、复活监听器分发（`add_revive_listener` / `emit_revive`）。
- **`AudioManager`** (`class_name AudioManager`)：音频管理（`PlayClip`, `PlayTrack`, `FadeOut`, `Stop` 等）。从 `Player.instance.get_node("MusicPlayer")` 获取播放器。注意：时间属性名为 `time`（小写，避免遮蔽 Godot 内置 `Time` 类）。
- **`SetLatency`** (`class_name SetLatency`)：延迟与音量配置，持久化至 `user://settings.cfg`。
- **`Player.instance`**：Player（`CharacterBody3D`）上的静态单例引用，在 `Player._ready()` 中注册，在编辑器环境中为 `null`（使用前必须判空）。

## 检查点与皇冠 (Checkpoint / Crown)

与 Unity 原版逻辑保持一致，保留两处符合 Godot 特性的有意设计（请勿修改）：
1. **`trackProgress` 按秒存储**：Godot 中以 `AnimationPlayer` 的秒数记录时间轴进度（Unity 为百分比）。
2. **`LevelManager.checkpointCount` 计入皇冠**：皇冠与检查点统一推进计数，钻石收集状态与检查点索引对齐恢复。
3. **复活屏幕淡入淡出**：`Checkpoint.revive()` 在复活重置场景时调用 `LevelUI.HideScreen(...)` 进行雾色全屏遮罩过渡，并在渐隐完成后恢复 `allowTurn = true`。

## GDScript 编码规范

- **命名规范**：
  - 方法名与变量名：**严格使用 `lowerCamelCase` / `PascalCase`**。**除非调用 Godot 引擎内置 API/虚函数（如 `_ready()`、`_process()`、`is_action_pressed()` 等），否则一律严禁使用 `snake_case`**。
- **强静态类型**：`#Template/[Scripts]` 下的所有变量声明、函数形参及返回值必须附带显式类型注解（`var x: int = 0`，避免无标注或容易出错的推断）。
- **`@tool` 脚本规范**：
  - 工具脚本中任何通过按钮/属性修改场景数据的逻辑，必须接入 `EditorUndoRedoManager` 并调用 `notify_property_list_changed()`，否则无法撤销且 Inspector 易出现脏数据。

## 关键场景与输入映射

### 核心场景
- 默认关卡模板：`#Template/[Scenes]/DefaultScene/Default.tscn`
- 玩家：`#Template/Player.tscn`（置于关卡 `BasicOBJ_Group/Player` 下）
- 触发器容器：`#Template/Trigger.tscn`（可复用 `BaseTrigger` 预制体）
- 界面组件：`StartPage.tscn`、`DebugOverlay.tscn`（D 键切换）、`LevelUI.tscn`（结算/复活界面）

### 输入按键（`project.godot`）
- **转向 (`turn`)**：鼠标左键 / 空格键
- **R**：重载当前关卡
- **K**：自杀 / 强制死亡
- **D**：切换 Debug 性能监控面板（仅 Debug 构建）

## 常见陷阱与避坑指南

1. **Godot 4.7 编辑器丢失 `[editable path="..."]` 子节点属性覆盖**：
   - 编辑器重新加载场景时不会保留子场景实例的节点属性重写（容易导致碰撞体 Scale 变 0 问题）。
   - **解决方案**：避免在复杂触发器上使用 `instance=Trigger.tscn` 嵌套重写；采用**内联本地节点**（如 `Area3D` + 挂载 `BaseTrigger.gd` + 本地 `CollisionShape3D`）。`CrownCheckPoint.tscn` 和 `HeartCheckPoint.tscn` 已采用此模式。
2. **禁止循环递归创建 `SceneTreeTimer`**：
   - 严禁在 `SceneTreeTimer` 回调中反复创建新 Timer（会导致频繁 GC 和掉帧）。周期性轮询必须使用持久化 `Timer` 节点。
3. **节点引用缓存**：
   - 避免在 `_process` 等每帧执行的方法中频繁调用 `get_viewport().get_camera_3d()`，应在 `_ready()` 缓存。
4. **物理碰撞层划分**：
   - Layer 1: Player / Layer 2: BaseFloor / Layer 3: BaseWall。
