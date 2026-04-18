# Unity to Godot Porting Prompt

> 将以下 prompt 发给 AI，即可开始从 Unity C# 项目移植到 Godot GDScript 项目。

---

## Prompt

我正在将 Unity C# 项目移植到 Godot GDScript 项目。

**源项目路径**：`<Unity项目路径>`
**目标项目路径**：`<Godot项目路径>`

### 项目结构对照

| Unity | Godot |
|-------|-------|
| `.cs` 脚本 | `.gd` 脚本 |
| `MonoBehaviour` | `Node` / `Node3D` / `CharacterBody3D` |
| `static class` | `class_name` + `static var` + `extends RefCounted` |
| `[SerializeField]` | `@export` |
| `enum` | `enum`（值类型自动推断） |
| C# 委托 (`delegate`) | Godot signal |
| `FindObjectsOfType<T>()` | `get_tree().get_nodes_in_group()` 或 `get_tree().get_nodes_in_group()` |
| `Invoke("method", delay)` | `get_tree().create_timer(delay).timeout.connect(method)` |
| DOTween (`DOLocalMoveZ`) | Godot Tween (`create_tween().tween_property`) |
| `Tag` 比较 | Godot 无 Tag，用 `is` 类型检查或 group |
| `SceneManager.LoadScene` | `get_tree().reload_current_scene()` |
| `Application.targetFrameRate` | `Engine.max_fps` |
| `PlayerPrefs` | `ConfigFile` 或自定义存档系统 |

### 移植原则

1. **逐文件移植**：读取 Unity 源码，理解功能后在 Godot 中重写
2. **保留命名**：类名、方法名尽量保持一致，方便对照
3. **状态机统一管理**：用 `static var game_state` + `enum GameStatus` 管理游戏状态（Waiting/Playing/Moving/Died/Completed）
4. **singleton 模式**：用 `static var instance` 实现，`_ready()` 中赋值 `instance = self`
5. **不要无脑翻译**：理解 Unity 代码的意图，在 Godot 中用最地道的方式实现
6. **同步 .tscn 文件**：脚本改名/删除后，更新对应的 `.tscn` 中的脚本路径引用

### 重要注意事项

- `move_and_slide()` 必须在 `is_on_floor()` 检测**之前**调用，否则地面检测永远返回 `false`
- 游戏状态（如 `Playing`/`Completed`）应在 `turn()` 首次点击时设置，不要在 `_input` 的条件中过早限制
- 物理移动（`_physics_process`）与游戏逻辑状态（`game_state`）的分离要小心，避免地面检测失效
- `@tool` 注解会让脚本在编辑器中运行，可能导致 `_ready()` 时场景未加载完成而出错

### 当前状态

- [ ] 列出要移植的文件
- [ ] 确认 Godot 项目中需要替换/删除的文件
- [ ] 开始逐文件移植
- [ ] 更新所有引用（State → LevelManager 等）
- [ ] 同步 .tscn 文件
- [ ] 测试运行

### 参考

- Unity 源文件路径：`<列出需要移植的文件>`
- Godot 目标文件路径：`<列出需要修改的文件>`

---

## 使用示例

```
我正在将 Unity C# 项目 D:\Code\MTPIDM001-Introduction 移植到 Godot GDScript 项目 D:\Code\dl\godot-line。

需要移植的文件：
1. LevelManager.cs → LevelManager.gd（替换 State.gd）
2. Pyramid.cs + PyramidTrigger.cs → Pyramid.gd + PyramidTrigger.gd（替换 Ending.gd）

请先读取 Unity 源码，理解功能后开始移植。
```
