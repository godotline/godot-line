# 贡献指南 - GodotLine

**感谢您考虑为 GodotLine 项目做出贡献！**<br>
我们非常欢迎您的参与，并致力于让贡献流程尽可能简单透明。无论您是想报告 Bug、讨论代码改进、提交修复、提议新功能，还是成为项目维护者，我们都热烈欢迎。

## 报告 Bug

如果您遇到任何 Bug 或问题，请使用 GitHub 的问题跟踪系统。您可以通过[创建新 Issue](https://github.com/meny2333/godot-line/issues/new) 来报告 Bug。
提交 Bug 报告时，请提供详细信息，包括：
- 重现问题的步骤
- 相关背景信息
- 示例代码或场景（如果可能）
- Godot 引擎版本（本项目使用 Godot 4.6）

## 在 GitHub 上开发

我们使用 GitHub 托管代码、跟踪问题和功能请求，以及接受 Pull Request。
我们遵循 [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow) 进行代码修改。
这意味着所有代码修改都应通过 Pull Request 提出。Pull Request 提供了一种结构化和协作式的方式来审查和讨论代码变更。

**如果您想贡献代码，请遵循以下步骤：**

1. 选择一个开放的 Issue 进行开发，或创建新 Issue
   - 将 Issue 分配给自己，并设置状态为 "In Progress"
2. Fork 仓库并从 `master` 分支创建新分支
   - 使用 Issue 编号作为分支名称，例如：GD-111
4. 如果修改了 API，请确保同步更新相关文档
5. 创建 Pull Request 并在 "Why" 和 "What" 部分提供详细说明：
   - 将 Pull Request 关联到对应的 Issue
   - 将 Pull Request 分配给自己
   - 确保每个 Pull Request 只关联一个 Issue
   - 如果 Pull Request 仍在开发中，请标记为 Draft
   - 确保代码遵循[代码规范](#代码规范)
6. 提交 Pull Request！

## 毁灭性更改规范

如果修改涉及 **破坏性 API 变更**，请遵循以下规范：

1. 在 Pull Request 标题标注 `[BREAKING]`
2. 提供详细的迁移指南
3. 更新所有相关测试用例
4. 提交到指定分支（非 master 主分支）
5. 在文档中明确标注不兼容的变更

## 许可证

通过为本项目做出贡献，您同意您的贡献将遵循与项目相同的 [MIT 许可证](https://github.com/meny2333/godot-line/blob/master/LICENSE)。
如有任何疑问，请联系项目维护者。

## 代码规范

为保持代码一致性，请遵循以下代码规范：

- [Godot GDScript 编码规范](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- 使用 `snake_case` 命名变量和函数
- 类名使用 `PascalCase`
- 常量使用 `UPPER_SNAKE_CASE`
- 信号使用 `snake_case`

### GDScript 示例

```gdscript
# 类名使用 PascalCase
class_name GameManager
extends Node

# 常量使用大写
const MAX_PLAYERS = 4

# 变量使用 snake_case
var player_score: int = 0

# 函数使用 snake_case
func add_score(points: int) -> void:
	player_score += points
	score_changed.emit(player_score)

# 信号使用 snake_case
signal score_changed(new_score: int)
```
