# UGC 功能运作机制文档

本文档描述了当前项目中 UGC（用户生成内容）功能的运作方式，涵盖了从关卡几何体生成到元数据配置及最终集成的完整流程。

## 1. 核心组件概览

- **MainLine (主线/玩家)**: 负责处理移动、转向和碰撞逻辑。在移动过程中会发出 `new_line1` 和 `on_sky` 信号。
- **RoadMaker (路点记录器)**: 监听 `MainLine` 的信号，根据移动轨迹动态生成地面模型（Roads），并支持将其序列化为场景文件。
- **LevelPatchMeta (关卡元数据)**: 一种自定义资源（Resource），用于定义关卡的显示名称、作者、音乐、难度等信息。
- **GenerateLevelPatch (补丁生成脚本)**: 一个编辑器脚本（EditorScript），负责将散落在项目中的关卡元数据汇总并生成最终游戏可识别的 `LevelData` 资源。

---

## 2. 运作流程详解

### 步骤 A：关卡几何体录制与生成
1. **实时生成**: 当玩家在场景中控制 `MainLine` 移动并按下转向键时，`MainLine` 会发射 `new_line1` 信号。
2. **模型铺设**: `RoadMaker.gd` 接收到信号后，会在当前位置实例化 `base_floor`。在 `_physics_process` 中，它会根据 `MainLine` 的实时位移拉伸模型，确保地面始终紧跟主线。
3. **保存场景**: 用户触发绑定的 `save` 输入动作（默认为按键触发）后，`RoadMaker` 会调用 `ResourceSaver.save()` 将所有生成的道路节点打包保存为 `res://Roads.tscn`。

### 步骤 B：定义关卡元数据
1. **创建 Meta 资源**: 在编辑器中创建 `LevelPatchMeta` 资源文件（通常存放在 `res://#Template/level_patches/` 目录下）。
2. **配置信息**:
   - `name`: 关卡英文名。
   - `chinese_name`: 关卡中文名。
   - `star`: 难度星级（0-6）。
   - `level_maker` / `music_maker`: 关卡与音乐制作者。
   - `tiny_levels`: 包含一组 `TinyLevelMeta`，每个 Meta 指向一个具体的场景路径（例如之前录制的 `res://Roads.tscn`）。

### 步骤 C：集成到游戏系统
1. **运行脚本**: 在 Godot 编辑器中选中 `GenerateLevelPatch.gd` 并运行（或通过快捷键）。
2. **自动汇总**: 脚本会扫描 `res://#Template/level_patch_meta.tres` 以及 `res://#Template/level_patches/` 目录下的所有元数据。
3. **输出资源**: 脚本会根据元数据内容，在 `res://patches/levels/` 目录下生成对应的 `.tres` 文件（类型为 `LevelData`）。
4. **UI 加载**: 游戏 UI 系统会自动读取 `res://patches/levels/` 目录下的 `LevelData` 资源，从而在关卡选择列表中显示新的 UGC 关卡。

---

## 3. 关键文件参考

- [RoadMaker.gd](file:///d:/Code/dl/godot-line/%23Template/%5BScripts%5D/RoadMaker.gd): 处理几何体录制的核心逻辑。
- [LevelPatchMeta.gd](file:///d:/Code/dl/godot-line/%23Template/%5BScripts%5D/LevelPatchMeta.gd): 定义关卡元数据的结构。
- [GenerateLevelPatch.gd](file:///d:/Code/dl/godot-line/%23Template/%5BScripts%5D/GenerateLevelPatch.gd): 编辑器脚本，用于自动化集成流程。
- [MainLine.gd](file:///d:/Code/dl/godot-line/%23Template/%5BScripts%5D/MainLine.gd): 玩家控制逻辑与信号发射源。

---

## 4. 替代方案构思

除了当前的“录制式”生成方案，以下是几种可供选择的 UGC 实现方向：

### 方案 A：路径点数据驱动 (Data-Driven Path)
- **机制**: 不保存整个 `PackedScene`，而是只记录转向点的坐标、速度变化、道具位置等核心数据（JSON 或自定义 Resource）。
- **优点**: 
    - **极小文件体积**: 仅存储关键坐标点，相比 `.tscn` 文件极小。
    - **高度灵活性**: 可以在运行时根据数据动态生成地面模型，便于调整视觉风格（例如更换地表材质）。
    - **易于分享**: 数据可以轻易通过剪贴板或小型 API 传输。
- **缺点**: 需要编写更完善的“数据到模型”的重建逻辑。

### 方案 B：实时 3D 关卡编辑器 (In-Game 3D Editor)
- **机制**: 提供一个 3D 编辑界面，允许玩家在网格上点击放置转向点、道具（钻石、皇冠）和触发器。
- **优点**: 
    - **设计精准**: 玩家可以精确控制关卡的每一个细节，无需通过反复“跑酷”来录制。
    - **即时反馈**: 编辑时可以直接预览视角和难度。
- **缺点**: 开发成本高，需要完善的 UI、撤销/重做系统以及 3D 交互逻辑。

### 方案 C：基于配置文件的关卡定义 (Config-Based DSL)
- **机制**: 允许用户编写简单的文本文件（如 `.json` 或 `.txt`）来定义关卡流，例如：`{"action": "forward", "length": 10}, {"action": "turn", "direction": "left"}`。
- **优点**: 
    - **极简集成**: 非常适合高级用户和批量生成。
    - **跨平台一致性**: 纯文本逻辑在任何平台表现一致。
- **缺点**: 对普通用户不友好，缺乏直观感。

---

## 5. 方案对比与建议

| 特性 | 当前方案 (录制式) | 方案 A (数据驱动) | 方案 B (编辑器) |
| :--- | :--- | :--- | :--- |
| **易用性** | 极高 (跑一遍就行) | 中 | 高 |
| **存储开销** | 高 (Scene 文件) | 极低 | 极低 |
| **扩展性** | 低 | 极高 | 极高 |
| **开发难度** | 低 | 中 | 高 |

**建议**: 
如果希望建立玩家社区并实现关卡分享，推荐向 **方案 A (数据驱动)** 转型。可以将当前的录制逻辑保留，但其输出不再是 `.tscn`，而是转换后的路径点数据，这样既保留了“跑酷即生成”的直观感，又获得了数据驱动的灵活性。
