# StartPage — 游戏启动界面设计

## 概述

为 GodotLine 添加一个游戏启动界面（StartPage），参考 Unity 模板项目中的 `StartPage.prefab` 实现。该界面在场景加载后、游戏开始前显示，玩家点击任意位置后自动隐藏并开始游戏。

## 设计原则

- **UI 先行**：先完成完整的视觉布局和接口定义，功能实现留空
- **遵循项目惯例**：`lowerCamelCase` 命名，Control 节点场景，信号驱动
- **仿 Unity 行为**：加载方式、交互模式、隐藏动画参照 Unity 模板

## 场景结构

### StartPage.tscn (CanvasLayer)

```
StartPage (CanvasLayer)                      ← 始终覆盖在 3D 场景上方
├── main_panel (Panel)                       ← 全屏尺寸，半透明黑底 (0,0,0,0.39)
│                                              mouse_filter = Ignore (点击穿透)
│
├── top_bar (HBoxContainer, anchor top)
│   ├── 左: Control (size_flags_horizontal=3, 弹性留空)
│   ├── 中: Label "R: 重新开始 | K: 快速死亡 | D: 调试模式"
│   │        font_size=16, color=#FFFFFF, horizontal_alignment=center
│   │        size_flags_horizontal=3
│   └── 右: autoplay_toggle (HBoxContainer, size_flags_horizontal=1)
│       ├── CheckBox (flat, 白色勾选)
│       └── Label "AUTOPLAY" (font_size=18, color=#FF0000, 红色)
│
├── center_card (Panel, anchor center)       ← 深灰圆角信息卡片
│   ├── theme: StyleBoxFlat bg_color=#404040, corner_radius=8
│   ├── scene_title (Label)                  ← "测试场景"，font_size=32, bold
│   ├── author_label (Label)                 ← "筱夕Sushi"，font_size=20
│   ├── template_label (Label)               ← "共舞的线模板"，font_size=16
│   ├── version_label (Label)                ← "基于冰焰模板 4.3.0 修改"，font_size=14
│   └── credits_label (Label)                ← "作者：Max冰焰、筱夕Sushi、Quantumilk"，font_size=14
│   全部垂直居中排列 (VBoxContainer)
│
├── info_button (Button, anchor bottom-left) ← 圆形灰色 "i" 按钮
│   ├── theme: StyleBoxFlat bg_color=#606060, corner_radius=20
│   ├── text "i", font_size=18, bold
│   ├── custom_minimum_size = 40×40
│   └── mouse_filter = Stop                 ← 阻止点击穿透
│
├── bottom_bar (Panel, anchor bottom)        ← 半透明深灰底栏
│   ├── bg_color=#303030, alpha=180 (半透明)
│   ├── custom_minimum_height = 80
│   ├── HBoxContainer (padding=20)
│   │
│   ├── 抗锯齿 (SettingItem)                 ← ◀  Off  ▶
│   │   values = ["Off", "x2", "x4", "x8"]
│   │
│   ├── 画质等级 (SettingItem)               ← ◀  中  ▶
│   │   values = ["低", "中", "高", "极高"]
│   │
│   ├── 音画延迟 (SettingItem)               ← ◀◀  60ms  ▶▶
│   │   存储: Player.music_delay (float, 秒, 默认 0.0)
│   │   显示: round(delay * 1000) + "ms" (整数毫秒)
│   │   粗调 ±10ms (0.01s)，细调 ±1ms (0.001s)
│   │   无 clamping（同 Unity 行为）
│   │
│   ├── 音量大小 (SettingItem)               ← ◀  100%  ▶
│   │   存储: Player.music_volume (float, 0.0~1.0, 默认 1.0)
│   │   显示: round(volume * 100) + "%"
│   │   步进 ±1 (内部 ±0.1)，clamp [0, 1]
│   │
│   ├── shadow_toggle (CheckBoxItem)         ← ☐ 阴影
│   └── post_toggle (CheckBoxItem)           ← ☐ 后处理
│
└── about_panel (Panel, 覆盖层, visible=false) ← About 弹窗
    ├── 半透明遮罩 (ColorRect, #000000@60%)
    ├── content_panel (Panel, 居中)
    │   ├── StyleBoxFlat bg=#404040, corner=8
    │   ├── VBoxContainer (padding=24)
    │   │   ├── title_label (Label)          ← 关卡名称
    │   │   ├── spacer (Control)
    │   │   ├── author_container (VBox)      ← 动态填充作者列表
    │   │   ├── spacer (Control)
    │   │   └── credits_label (Label)        ← 模板版权信息
    │   └── close_button (Button)            ← 关闭
    └── mouse_filter = Stop
```

### 子场景 / 自定义控件

#### SettingItem.tscn (HBoxContainer)

```
SettingItem (HBoxContainer)
├── title_label (Label)                      ← 设置项名称（如"抗锯齿"）
├── fine_adjust (HBoxContainer)              ← 仅延迟项：粗调用 ±10
│   ├── arrow_coarse_left (Button, flat)     ← "<<" 或 "<"
│   └── arrow_fine_left (Button, flat)       ← "<"（仅延迟项）
├── arrow_left (Button, flat)                ← "<" 字符（通用）
├── value_label (Label, center)              ← 当前值
├── arrow_right (Button, flat)               ← ">" 字符（通用）
├── fine_adjust_right (HBoxContainer)        ← 仅延迟项
│   ├── arrow_fine_right (Button, flat)      ← ">"
│   └── arrow_coarse_right (Button, flat)    ← ">>" 或 ">"
```

**SettingItem 有两种模式**：

| 模式 | 适用 | 箭头行为 |
|------|------|---------|
| `cyclic`（循环） | 抗锯齿、画质等级 | ◀ ▶ 循环切换 options 列表 |
| `range`（数值范围） | 音量大小 | ◀ ▶ 按 step 增减，clamp 到 [min, max] |
| `latency`（延迟特殊模式） | 音画延迟 | ◀◀ ◀ ▶ ▶▶ 四级箭头：粗调 ±10ms，细调 ±1ms |

**SettingItem.gd 接口**：
```gdscript
signal value_changed(value)                   # 值变化时发出

# 方法
func set_options(options: Array)               # 循环模式：设置可选值列表
func set_value(val)                            # 设置当前值
func get_value() -> Variant                    # 获取当前值
func set_range(min_val: float, max_val: float, step: float)
                                               # range/latency 模式：设置范围和步进
func set_suffix(text: String)                  # 设置后缀（"ms", "%"）
func set_title(text: String)                   # 设置标题
func set_mode(mode: int)                       # cyclic / range / latency
```

#### CheckBoxItem.tscn (HBoxContainer)

```
CheckBoxItem (HBoxContainer)
├── CheckBox (flat, 白色)
└── Label (标题文字)
```

**CheckBoxItem.gd 接口**：
```gdscript
signal toggled(is_on: bool)

func set_title(text: String)
func set_is_on(value: bool)
func get_is_on() -> bool
```

## 接口定义

### StartPage.gd 暴露的信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `start_requested` | — | 游戏开始（玩家点击，StartPage 准备隐藏）|
| `info_button_pressed` | — | 信息按钮 (i) 点击 |
| `autoplay_toggled` | is_on: bool | 自动播放开关变化 |
| `setting_changed` | key: String, value | 任意设置项变化，key = "antialiasing"/"quality"/"latency"/"volume" |
| `shadow_toggled` | is_on: bool | 阴影开关变化 |
| `post_toggled` | is_on: bool | 后处理开关变化 |

### StartPage.gd 暴露的方法

| 方法 | 说明 |
|------|------|
| `show()` | 显示 StartPage |
| `hide()` | 动画隐藏 StartPage（仿 Unity DOTween）|
| `set_info_card(config: Dictionary)` | 更新信息卡片内容 |
| `set_setting(key: String, value)` | 编程设置某个值 |
| `get_setting(key: String) -> Variant` | 获取当前值 |
| `set_about_content(title: String, authors: Array[String], credits: String)` | 设置 About 面板内容 |

## Player.gd 新增变量

对应 Unity 的 `Player.Instance.musicDelay` 和 `Player.Instance.musicVolume`：

```gdscript
# 音画延迟（秒），默认 0.0。用户可配置的额外延迟补偿。
# 与 AudioServer.get_output_latency() 是不同概念，两者独立存在。
var music_delay: float = 0.0

# 音量 (0.0~1.0)，默认 1.0
var music_volume: float = 1.0
```

## 集成方式

### 实例化 —— Player.gd

参照 Unity 模板，在 `Player._ready()` 中自动加载并实例化 StartPage：

```gdscript
# Player._ready() 尾部追加
var start_page_scene = preload("res://#Template/[Resources]/StartPage.tscn")
var start_page = start_page_scene.instantiate()
add_child(start_page)
```

### 隐藏逻辑

- 玩家点击 → `Player._input()` 检测 `turn` 动作 → `Player.turn()` 首次调用
- 在 `turn()` 设置 `is_start = true` 和 `GameState = Playing` **之前或之后**，调用 `start_page.hide()`
- `hide()` 方法执行动画：顶部栏上移、信息卡片下移、底部栏下移、淡出，完成后 `queue_free()`
- 或更简单：StartPage 自身在 `_process` 中检测 `LevelManager.GameState == Playing` 时自动隐藏

### 隐藏动画

仿 Unity DOTween 效果（使用 Godot Tween）：

| 元素 | 动画 |
|------|------|
| `top_bar` | 向上平移 + 淡出 (0.3s, Quad.easeInOut) |
| `center_card` | 向下平移 + 淡出 (0.3s, Quad.easeInOut) |
| `bottom_bar` | 向下平移 + 淡出 (0.3s, Quad.easeInOut) |
| `info_button` | 向左平移 + 淡出 (0.3s) |
| `main_panel` | 整体淡出 (0.4s) |
| `autoplay_toggle` | 向右平移 + 淡出 (0.3s) |

## 布局参数

- **参考分辨率**：1920×1080（CanvasLayer 保持原样缩放）
- **顶部栏**：上边距 16px，高度 40px
- **信息卡片**：宽度 440px，内边距 32px
- **底部栏**：下边距 0，高度 80px，内边距 20px
- **信息按钮**：左下角，左边距 24px，下边距 100px

## 实现顺序

1. 创建 `SettingItem.tscn` + `SettingItem.gd`（自定义控件，最基础单元）
2. 创建 `CheckBoxItem.tscn` + `CheckBoxItem.gd`
3. 创建 `StartPage.tscn` + `StartPage.gd`（完整布局）
4. 实现隐藏动画
5. 集成到 `Player.gd`（自动实例化 + 点击隐藏）
6. 暴露信号接口
7. 测试：验证显示、点击开始、隐藏动画、设置项交互
