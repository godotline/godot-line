# SetActiveTrigger 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 SetActiveTrigger 脚本，用于在触发时激活/禁用指定节点，并支持复活时恢复状态

**Architecture:** 继承 BaseTrigger，使用 @export 导出配置，通过 LevelManager 复活系统恢复状态

**Tech Stack:** GDScript, Godot 4.6, Area3D 触发器系统

---

## 文件结构

```
#Template/[Scripts]/Trigger/SetActiveTrigger.gd  # 主脚本
```

## 实现任务

### Task 1: 创建 SetActiveTrigger 基础结构

**Files:**
- Create: `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

- [ ] **Step 1: 创建脚本文件**

```gdscript
extends BaseTrigger
class_name SetActiveTrigger

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var active_on_awake: bool = false
@export var actives: Array[Dictionary] = []

var _revive_states: Array[Dictionary] = []
var _checkpoint_index: int = 0
```

- [ ] **Step 2: 验证脚本语法**

在 Godot 编辑器中打开脚本，检查是否有语法错误

- [ ] **Step 3: 提交初始脚本**

```bash
git add "#Template/[Scripts]/Trigger/SetActiveTrigger.gd"
git commit -m "feat: create SetActiveTrigger base structure"
```

### Task 2: 实现触发逻辑

**Files:**
- Modify: `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

- [ ] **Step 1: 添加 _ready 方法**

```gdscript
func _ready() -> void:
    super._ready()
    
    if active_on_awake:
        _apply_all_actives()
    
    LevelManager.add_revive_listener(_on_revive)
```

- [ ] **Step 2: 添加 _on_triggered 方法**

```gdscript
func _on_triggered(_body: Node3D) -> void:
    if active_on_awake:
        return
    
    _checkpoint_index = LevelManager.checkpoint_count
    _save_revive_states()
    _apply_all_actives()
```

- [ ] **Step 3: 添加 _apply_all_actives 方法**

```gdscript
func _apply_all_actives() -> void:
    for active_config in actives:
        var target_path = active_config.get("target", "")
        var target = get_node_or_null(target_path)
        if target:
            var active_state = active_config.get("active", true)
            if target is Node3D:
                target.visible = active_state
            elif target is CanvasItem:
                target.visible = active_state
```

- [ ] **Step 4: 验证触发逻辑**

创建测试场景，添加 SetActiveTrigger 节点，配置目标节点，测试触发功能

- [ ] **Step 5: 提交触发逻辑**

```bash
git add "#Template/[Scripts]/Trigger/SetActiveTrigger.gd"
git commit -m "feat: implement trigger logic for SetActiveTrigger"
```

### Task 3: 实现复活恢复逻辑

**Files:**
- Modify: `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

- [ ] **Step 1: 添加 _save_revive_states 方法**

```gdscript
func _save_revive_states() -> void:
    _revive_states.clear()
    for active_config in actives:
        var target_path = active_config.get("target", "")
        var target = get_node_or_null(target_path)
        if target:
            var original_visible = false
            if target is Node3D:
                original_visible = target.visible
            elif target is CanvasItem:
                original_visible = target.visible
            
            _revive_states.append({
                "target": target_path,
                "original_visible": original_visible,
                "dont_revive": active_config.get("dont_revive", false)
            })
```

- [ ] **Step 2: 添加 _on_revive 方法**

```gdscript
func _on_revive() -> void:
    LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
        for state in _revive_states:
            if not state.get("dont_revive", false):
                var target_path = state.get("target", "")
                var target = get_node_or_null(target_path)
                if target:
                    var original_visible = state.get("original_visible", false)
                    if target is Node3D:
                        target.visible = original_visible
                    elif target is CanvasItem:
                        target.visible = original_visible
    )
```

- [ ] **Step 3: 添加 _exit_tree 方法清理监听**

```gdscript
func _exit_tree() -> void:
    LevelManager.remove_revive_listener(_on_revive)
```

- [ ] **Step 4: 验证复活恢复功能**

测试触发后死亡，检查节点状态是否正确恢复

- [ ] **Step 5: 提交复活恢复逻辑**

```bash
git add "#Template/[Scripts]/Trigger/SetActiveTrigger.gd"
git commit -m "feat: implement revive recovery logic for SetActiveTrigger"
```

### Task 4: 完善脚本和测试

**Files:**
- Modify: `#Template/[Scripts]/Trigger/SetActiveTrigger.gd`

- [ ] **Step 1: 添加调试支持**

```gdscript
@export_group("调试设置")
@export var debug_mode: bool = false

func _apply_all_actives() -> void:
    for active_config in actives:
        var target_path = active_config.get("target", "")
        var target = get_node_or_null(target_path)
        if target:
            var active_state = active_config.get("active", true)
            if target is Node3D:
                target.visible = active_state
            elif target is CanvasItem:
                target.visible = active_state
            
            if debug_mode:
                print("[SetActiveTrigger] ", name, " 设置 ", target_path, " 可见性为 ", active_state)
```

- [ ] **Step 2: 添加完整脚本内容**

```gdscript
extends BaseTrigger
class_name SetActiveTrigger

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var active_on_awake: bool = false
@export var actives: Array[Dictionary] = []

@export_group("调试设置")
@export var debug_mode: bool = false

var _revive_states: Array[Dictionary] = []
var _checkpoint_index: int = 0

func _ready() -> void:
    super._ready()
    
    if active_on_awake:
        _apply_all_actives()
    
    LevelManager.add_revive_listener(_on_revive)

func _on_triggered(_body: Node3D) -> void:
    if active_on_awake:
        return
    
    _checkpoint_index = LevelManager.checkpoint_count
    _save_revive_states()
    _apply_all_actives()

func _apply_all_actives() -> void:
    for active_config in actives:
        var target_path = active_config.get("target", "")
        var target = get_node_or_null(target_path)
        if target:
            var active_state = active_config.get("active", true)
            if target is Node3D:
                target.visible = active_state
            elif target is CanvasItem:
                target.visible = active_state
            
            if debug_mode:
                print("[SetActiveTrigger] ", name, " 设置 ", target_path, " 可见性为 ", active_state)

func _save_revive_states() -> void:
    _revive_states.clear()
    for active_config in actives:
        var target_path = active_config.get("target", "")
        var target = get_node_or_null(target_path)
        if target:
            var original_visible = false
            if target is Node3D:
                original_visible = target.visible
            elif target is CanvasItem:
                original_visible = target.visible
            
            _revive_states.append({
                "target": target_path,
                "original_visible": original_visible,
                "dont_revive": active_config.get("dont_revive", false)
            })

func _on_revive() -> void:
    LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
        for state in _revive_states:
            if not state.get("dont_revive", false):
                var target_path = state.get("target", "")
                var target = get_node_or_null(target_path)
                if target:
                    var original_visible = state.get("original_visible", false)
                    if target is Node3D:
                        target.visible = original_visible
                    elif target is CanvasItem:
                        target.visible = original_visible
    )

func _exit_tree() -> void:
    LevelManager.remove_revive_listener(_on_revive)
```

- [ ] **Step 3: 创建测试场景**

创建测试场景，包含：
- SetActiveTrigger 节点
- 目标节点（MeshInstance3D 或 Sprite3D）
- 玩家节点
- 检查点节点

测试功能：
1. 触发时激活/禁用节点
2. 复活时恢复状态
3. 单次触发功能
4. 多个目标节点配置

- [ ] **Step 4: 提交完整实现**

```bash
git add "#Template/[Scripts]/Trigger/SetActiveTrigger.gd"
git commit -m "feat: complete SetActiveTrigger implementation with debug support"
```

### Task 5: 更新文档

**Files:**
- Modify: `#Template/[Scripts]/Trigger/AGENTS.md`

- [ ] **Step 1: 更新 AGENTS.md**

在 AGENTS.md 的继承结构中添加 SetActiveTrigger：

```
BaseTrigger (Area3D)
├── Trigger           # 通用触发器，发射 hit_the_line 信号
├── SetActiveTrigger  # 激活/禁用触发器
├── Checkpoint        # 检查点
├── HeartCheckpoint   # 爱心检查点
├── Crown             # 皇冠
├── Diamond           # 钻石
├── Jump              # 跳跃触发
├── ChangeSpeedTrigger # 变速
├── ChangeTurn        # 变向
├── LocalTeleportTrigger # 本地传送
├── FogColorChanger   # 雾色变换
├── Pyramid           # 金字塔
├── PyramidTrigger    # 金字塔触发
├── animplay          # 动画播放
└── customanimplay    # 自定义动画播放
```

- [ ] **Step 2: 提交文档更新**

```bash
git add "#Template/[Scripts]/Trigger/AGENTS.md"
git commit -m "docs: add SetActiveTrigger to trigger system documentation"
```

## 验证清单

- [ ] 脚本语法正确，无错误
- [ ] 触发时正确激活/禁用节点
- [ ] 复活时正确恢复状态
- [ ] 单次触发功能正常
- [ ] 调试输出正常工作
- [ ] 文档已更新

## 注意事项

1. **节点引用安全**
   - 使用 `get_node_or_null` 避免空引用
   - 检查节点类型再设置可见性

2. **复活时序**
   - 确保在 `emit_revive` 时正确恢复状态
   - 使用 `CompareCheckpointIndex` 检查检查点索引

3. **性能考虑**
   - 只在触发时处理，避免每帧更新
   - 使用数组存储配置，支持批量操作

4. **编辑器支持**
   - 使用 `@export` 导出配置
   - 支持 `NodePath` 选择目标节点
