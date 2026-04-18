## Context

`importer_plugin.gd` 中 `_show_node_path_dialog` 方法使用 `ConfirmationDialog` + `LineEdit` 让用户手动输入节点路径。用户需要记住并准确键入如 `"Player/Camera3D"` 这样的路径字符串，容易出错且不直观。Godot 4.x 编辑器提供了 `SceneTreeDialog` 组件，可直接弹出场景树让用户点击选择节点。

## Goals / Non-Goals

**Goals:**
- 替换手动输入为场景树节点选择器
- 保持现有菜单项入口不变（"设置 animations_root" 和 "设置 default_camera"）
- 设置后在控制台打印已选路径，行为与现有逻辑一致

**Non-Goals:**
- 不修改 `*ImportRoot.gd` 中的 `@export var NodePath`（这些已自带节点选择器）
- 不改变导入逻辑、解析逻辑或数据格式
- 不添加新的菜单项或功能

## Decisions

### 使用 `SceneTreeDialog` 替代 `ConfirmationDialog` + `LineEdit`

Godot 4.x 提供内置的 `SceneTreeDialog`，专门用于从场景树中选择节点。

```gdscript
var dialog := SceneTreeDialog.new()
dialog.selected.connect(func(path: NodePath):
    callback.call(path)
    dialog.queue_free()
, CONNECT_ONE_SHOT)
dialog.canceled.connect(func():
    dialog.queue_free()
, CONNECT_ONE_SHOT)
get_editor_interface().get_base_control().add_child(dialog)
dialog.popup_centered()
```

**优势:**
- 内置组件，无需自定义 UI
- 用户直接点击场景树节点，路径自动填入
- 支持搜索过滤
- 代码量从 ~30 行减至 ~10 行

**替代方案考虑:**
- `EditorInterface.get_selection()` 获取当前选中节点 — 不够灵活，用户需先在场景树中选好再点菜单
- 自定义 `Tree` 控件 — 需手动构建场景树，工作量大且无必要
- `EditorProperty` + `EditorInspectorPlugin` — 过度设计，仅需两个路径选择

### 删除 `_show_node_path_dialog` 方法

该方法完全由新的 `_show_node_picker_dialog` 替代，无需保留。

## Risks / Trade-offs

- [SceneTreeDialog API 变化] → Godot 4.x 中该组件稳定，属于编辑器标准组件
- [用户场景树很大时选择不便] → SceneTreeDialog 自带搜索功能，可过滤节点
- [选中后无法编辑路径] → 若需要微调路径可后续添加 LineEdit 作为补充，当前 MVP 不需要

## Migration Plan

无需迁移。纯 UI 改进，不影响已有数据或配置。用户更新插件后即可使用新交互方式。
