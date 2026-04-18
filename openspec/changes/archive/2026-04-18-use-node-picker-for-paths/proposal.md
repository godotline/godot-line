## Why

MPM importer 插件的 toolbar 菜单中，设置 `defaultcamera` 和 `animationsroot` 时使用 `LineEdit` 手动输入节点路径，用户体验差。用户必须记住并准确输入完整节点路径，容易出错。应改为使用 Godot 编辑器内置的节点选择器（scene tree picker），让用户通过点击场景树来选择节点。

## What Changes

- 将 `importer_plugin.gd` 中 `_show_node_path_dialog` 方法的 `LineEdit` 替换为场景树节点选择器
- 用户点击菜单后弹出场景树选择对话框，直接点击节点即可设置路径，无需手输
- 保留键盘输入作为备选方式（可选）
- **BREAKING**: 无破坏性变更，仅 UI 交互方式改进

## Capabilities

### New Capabilities

- `node-picker-dialog`: 场景树节点选择对话框，替代 `LineEdit` 手动输入节点路径

### Modified Capabilities

- 无

## Impact

- 受影响文件: `addons/mpm_importer/importer_plugin.gd`
- `_show_node_path_dialog` 方法需重写
- `_set_animations_root` 和 `_set_default_camera` 调用方式可能微调
- 无外部依赖变更
