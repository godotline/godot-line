# AGENTS.md — Godot Line

## 项目概览

- **引擎版本**：Godot 4.7（Dancing Line / 跳舞的线 游戏模板，GDScript）。`project.godot` 为准。
- **物理与渲染**：Jolt Physics（独立线程运行）；渲染器为 Mobile。

## 代理工作准则

- **不要自作聪明**：默认严格遵循项目既有约定与 Unity 源码，不要自行"优化"、重构或添加源码中没有的逻辑 / 抽象 / 防御层。唯一允许的自主改动：能带来**更好性能或更简洁实现**的替代方案（须明确优于现状，且不影响与 Unity 的对齐）。拿不准时按现状实现，不要替用户做设计决策。

## 调研与开发工具规则

- **网络搜索**：使用 Tavily 工具查询 Godot API 与已知问题。**严禁通过 curl/下载引擎源码文件**，优先使用文档与搜索结果。
- **源码与架构查询**：使用 **DeepWiki MCP**（`godotengine/godot` 等）查询引擎内部实现细节（如 `ScriptServer`、`can_instantiate()` 机制）。
- **编辑器实时检查**：优先使用 `gdmcp` 工具（端口 9080）与正在运行的 Godot 编辑器交互。

### 编辑器内脚本测试配方（gdmcp execute_editor_script）

- 简单探查：内联语句 + `_custom_print` 返回输出，须带 `--apply --allow-open-world` 旗标。
- **MCP 侧的报错永远是笼统的（如 "Script compilation failed"），或 success 但输出缺失——真实报错看编辑器输出面板**：`get_editor_logs` 传 `source: "editor_panel"` 拉取（默认 `mcp` 源只是插件自身日志）。引擎真实报错（带行号、参数详情）都在面板里，排查脚本异常第一步先拉它；仍无线索再用 FileAccess 分步落盘探针 + bash 轮询定位死点。
- **API 签名勿凭文档记忆**（4.x 小版本间有增删）：优先 **Tavily 搜索对应版本文档**核实；编辑器正在运行时可用 **gdmcp 查运行版本的 ClassDB** 兜底（`get_class_api_metadata` 工具，或 execute_editor_script 内 `ClassDB.class_get_method_list(...)`）。签名不符时：直呼被静态检查拒绝，报笼统 "Script compilation failed"（无行号）；改用 `.call()` 动态调用能过编译，但运行时会**静默中止整个执行帧**——后续语句与 `_custom_print` 全部丢失、工具仍报 success。
- **跨帧 / 异步工作用「延迟帮手节点」两段式**：内联脚本只把一个临时 Node 挂到编辑器主根节点保活，真正逻辑接在其 `create_timer(...).timeout` 回调里（回调内可 `await` 多帧编排），随即返回；回调自行把结果写文件并清理自身，调用方轮询文件拿结论。`await` 直接写在内联顶层会被 GC（协程状态无人持有，表现为只跑到第一个 await）；挂在树上的节点回调中 await 则安全。

编程式保存等完整管线测试的已验证流程：

1. 构造临时场景，子节点**必须设 `owner = root`**（否则 `PackedScene.pack()` 得到空场景）；
2. `pack()` + `ResourceSaver.save(ps, "res://.tmp_xxx.tscn")` 落盘；
3. `open_scene_from_path(path)` 打开为编辑场景，`await process_frame` ×2；
4. 经 `get_edited_scene_root()` 拿实例做接线；
5. **零参 `EditorInterface.save_scene()`** 走完整 `EditorNode::_save_scene` 管线（`NOTIFICATION_EDITOR_PRE_SAVE/POST_SAVE` 对无 owner 内部子节点同样传播）；
6. 结果写文件 → `close_scene()` → 删临时文件 → 帮手节点自清理。

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

## 插件/Unity 移植开发规则

- **区分"Unity 移植"与"写插件"**：Godot 端口的 Unity 模板组件（如 `SetMaterialColor.cs` → `SetMaterialColor.gd`、`Jump`/`Speed`/`SetActive`/`SetFog` 等）属于 `#Template` 内容，应落在 `#Template/[Scripts]`，与既有通用触发器并列——这是移植 Unity 模板，不是"写插件"。
- **写插件（`addons/plugin_arphros_importer`）时严禁往 `#Template` 塞导入器专用 / Arphros 适配逻辑**：仅数据解析、关卡构建，以及 Arphros 特有格式组件（如 `animatable.gd`，对应 `objects[].animatable` JSON）才放插件目录。
- **判定先例**：`animatable.gd`、`sequence_trigger.gd` 为导入器专用 → 插件；`SetMaterialColor.gd` 为 `SetMaterialColor.cs` 的 Godot 移植 → `#Template`。
- **命名保真（Unity 移植）**：移植组件时**类名 / 文件名沿用 Unity 源码原名**（如 Unity `SetMaterialColor` → Godot `SetMaterialColor.gd` + `class_name SetMaterialColor`），不得自行改名（如不得叫 `SetColor3D`）。字段 / 方法**优先对齐 Unity 源码命名**（如 Unity `duration` / `material` / `hasEmission` / `SetColor` 直接沿用，不另起 GDScript 风格名）；snake_case 仅用于 Godot 引擎 API 与 `_ready`/`_process`/`trigger` 等虚函数或约定方法，如模式 1 的 `trigger(body)`）。
- **对齐 Unity 时可修正老旧命名**：移植 / 对齐 Unity 过程中，遇到旧代码中**不符合 Unity 命名、使用 `snake_case` 的标识符**（字段、方法、变量、信号），可直接改名为 Unity 对应命名（如 `set_auto_play` → `SetAuto`、`_triggered` → `triggered` 视 Unity 字段而定），无需保留旧名，并同步所有引用点。此权限仅适用于"向 Unity 对齐"时；纯 Godot 侧新增代码仍须遵守下方「GDScript 编码规范」的 `lowerCamelCase` / `PascalCase` 规则。
- **注释 / 标注克制（Unity 移植）**：DLMTP 的 `SetMaterialColor.cs` 等源文本就几乎无注释、无分组标注。移植时**不要添加原版没有的文字说明、`@export_group` 解释性标签、冗余注释**，只保留与源码对应的必要结构与 Godot 端口必需的少量约束（如 `material_override` 保护共享模板材质可一行点出）。严禁画蛇添足。
- **Unity 源码基准（DLMTP）**：移植保真度（命名、字段默认值、行为、Inspector 分组）一律以 Unity 模板源码为准，位于 `../../DLMTP-Template/Assets/#Template`（相对本仓库根目录；绝对即 `/home/meny/Code/DLMTP-Template/Assets/#Template` 下的 `Assets/#Template`）。任何"是否与 Unity 一致"的判断都回到该目录的对应 `.cs`。
- **`@export_group` 必须与 Unity `[Title]` 对齐**：Godot 端口的 Inspector 分组标签**只能保留与 Unity 源码 `[Title("...")]` 完全一致者**（如 `TrackSwitchTrigger` 的 `Timeline Track Switch Control`、`Checkpoint`/`TTFCheckPoint` 的 `Player`/`Colors`/`Event`）；Unity 无对应 `[Title]` 的标签一律删除（如 `设置`、`预测设置`、`激活设置`、`传送设置`、`转向设置`、`TTF Visuals`、`Final设置`，以及 `Checkpoint` 的 `Config`/`Camera`/`Fog`/`Light`/`Ambient`）。禁止为 Godot 端口便利自行添加分组名。
- **字段默认值 / 行为对齐 Unity**：移植组件的字段默认值、取值、触发行为须与 Unity 源码一致（如 `SetMaterialColor.duration` 默认 `2f`；`SingleColor` 按 `hasEmission` 开关 emission 且 `intensity` 生效）。运行期由导入器覆盖的字段，其编辑器默认值仍应对齐源码。
- 组件归属 / 命名变动时同步 `trigger_type_map.gd` 的 `preload` 路径、`Trigger.md` 引用与 `LevelLoader` 内的 `class_name` / 实例化代码。

## 触发器系统 (Trigger System)

项目中存在三种触发器模式，**所有新触发器必须采用模式 1（纯组件）**：

| 模式 | 基类 | 碰撞检测负责者 | 示例 |
|------|------|---------------|------|
| **模式 1：纯组件（推荐）** | `extends Node` / `Node3D` | 父级 `BaseTrigger` 节点 | `Jump.gd`, `Gem.gd`, `Checkpoint.gd`, `Speed.gd` |
| **模式 2：自包含** | `extends BaseTrigger` (Area3D) | 自身 | `OldCameraShakeTrigger.gd` |
| **模式 3：遗留模式** | `extends Area3D` | 自身监听 `body_entered` | `OldCameraTrigger.gd`, `CameraShakeTrigger.gd` |

### 模式 1 规范
- 实现 `trigger(body)` 方法即可。
- 作为 `BaseTrigger`（或 `Trigger.tscn` 实例）的子节点放置。
- `BaseTrigger` 采用鸭子类型（`has_method("trigger")`）自动遍历并调用子节点。
- `BaseTrigger` 参数：`one_shot`（单次触发）、`require_playing`（需游戏运行中）、`track_exit`、`debug_mode`。
- `KillPlayer.gd` 为模式 1 组件，仅在 `GameState == Playing` 且 `!Player.noDeath` 时调用 `Player.PlayerDeath`；死亡原因统一使用 `LevelManager.DieReason`。
- Player 的 Obstacle 探测区域负责撞障碍死亡；不要在 `_physics_process` 中用 `is_on_wall()` 作为死亡路径，以保持 Ground 与 Obstacle 的语义区分。

## 通用添加组件面板 (Inspector 插件)

- 位于 `addons/template/component_inspector_plugin.gd`，在每个 Node 的 Inspector 底部注册"组件"面板。
- 点击调用 `EditorInterface.popup_quick_open` 选择脚本并作为子节点挂载，支持 Undo/Redo 并自动维护节点 owner。
- **注意**：在 Godot 4.7 编辑器中，非 `@tool` 脚本的 `Script.can_instantiate()` 设计上返回 `false`（因编辑器禁用了非工具脚本实例化环境），但 `script.new()` 可正常使用。工具脚本中切勿使用 `can_instantiate()` 作为合法性校验守卫。

## 核心单例与架构

所有核心管理器均为 **`RefCounted` 静态类**（非 Node，不可使用传统生命周期 `_process` 或节点信号）：

- **`LevelManager`** (`class_name LevelManager`)：游戏状态机（`GameStatus` 枚举）、检查点数据、复活监听器分发（`add_revive_listener` / `emit_revive`）。
- **`AudioManager`** (`class_name AudioManager`)：音频管理（`PlayClip`, `PlayTrack`, `FadeOut`, `Stop` 等）。统一通过 `Player.SoundTrack` 获取音乐播放器；`SoundTrack` 为运行时由 `AudioManager.PlayTrack` 创建的属性，按 Unity 命名保留大写。注意：时间属性名为 `time`（小写，避免遮蔽 Godot 内置 `Time` 类）。
- **`SetLatency`** (`class_name SetLatency`)：延迟与音量配置，持久化至 `user://settings.cfg`。
- **`Player.instance`**：Player（`CharacterBody3D`）上的静态单例引用，在 `Player._ready()` 中注册，在编辑器环境中为 `null`（使用前必须判空）。

## 检查点与皇冠 (Checkpoint / Crown)

与 Unity 原版逻辑保持一致，保留两处符合 Godot 特性的有意设计（请勿修改）：
1. **复活进度由 `GameTime` 恢复**：音乐恢复到 `GameTime`，主时间轴动画恢复到 `GameTime + musicDelay`（对齐 Unity）；不再保存独立的 `trackProgress`。
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
- 界面组件：`StartPage.tscn`、`LevelUI.tscn`（结算/复活界面）

### 输入按键（`project.godot`）
- **转向 (`turn`)**：鼠标左键 / 空格键 / Enter（主键盘与小键盘）
- **R**：重载当前关卡
- **K**：自杀 / 强制死亡
- **D**：切换 Debug 性能监控面板（仅 Debug 构建）

## 常见陷阱与避坑指南
3. **节点引用缓存**：
   - 避免在 `_process` 等每帧执行的方法中频繁调用 `get_viewport().get_camera_3d()`，应在 `_ready()` 缓存。
4. **物理碰撞层划分**：
   - Layer 1: Player / Layer 2: Ground / Layer 3: Obstacle。
