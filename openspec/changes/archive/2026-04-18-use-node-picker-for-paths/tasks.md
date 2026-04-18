## 1. 替换节点路径选择对话框

- [x] 1.1 将 `_show_node_path_dialog` 方法替换为 `_show_node_picker_dialog`，使用 `SceneTreeDialog` 实现
- [x] 1.2 更新 `_set_animations_root` 和 `_set_default_camera` 调用新的节点选择方法

## 2. 验证

- [x] 2.1 在编辑器中测试 "设置 animations_root" 菜单项，确认弹出场景树选择器
- [x] 2.2 在编辑器中测试 "设置 default_camera" 菜单项，确认弹出场景树选择器
- [x] 2.3 测试取消选择后路径不被更改
- [x] 2.4 测试选择节点后控制台正确打印路径
