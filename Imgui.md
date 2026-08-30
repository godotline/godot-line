# ImGui 使用说明

## 当前实现

本项目使用 `dear-imgui-godot` Rust GDExtension，通过 `imgui-rs` 将 Dear ImGui 接入 Godot 4.7。

插件目录为 `addons/dear-imgui-godot`，全局单例名称为 `ImGui`。项目已在 `project.godot` 中启用插件和 autoload，不要再使用已经移除的 `addons/imgui-godot` C++ 插件、`ImGuiRoot.tscn` 或大写静态 API。

| 项目 | 当前值 |
| --- | --- |
| GDScript 入口 | `ImGui.imgui_layout` |
| C# 入口 | `ImGui.OnLayout(...)` |
| 插件实现 | Rust GDExtension + `imgui-rs` |
| Android 架构 | `arm64`、`x86_64` |
| iOS 架构 | `arm64`（设备） |
| 字体 | 插件内置默认字体 |

## 基本用法

所有 ImGui 调用都应放在 `imgui_layout` 信号回调中。这个回调是同步执行的，不要在其中使用 `await`，也不要把一帧的 UI 调用拆到异步回调中。

```gdscript
extends Node

func _ready() -> void:
	if not ImGui.imgui_layout.is_connected(_onImguiLayout):
		ImGui.imgui_layout.connect(_onImguiLayout)

func _exit_tree() -> void:
	if ImGui.imgui_layout.is_connected(_onImguiLayout):
		ImGui.imgui_layout.disconnect(_onImguiLayout)

func _onImguiLayout() -> void:
	var expanded: bool = ImGui.begin("Example")
	if expanded:
		ImGui.text("Hello from Godot")
		if ImGui.button("OK", 0.0, 0.0):
			print("clicked")
	ImGui.end()
```

`begin()` 返回 `false` 时表示窗口已折叠或被裁剪，但仍然必须调用一次 `ImGui.end()`。

## 常用 API

### 窗口

| API | 说明 |
| --- | --- |
| `begin(name)` | 开始普通窗口 |
| `begin_ex(name, flags)` | 使用窗口标志开始窗口 |
| `end()` | 结束窗口 |
| `set_next_window_pos(x, y, cond)` | 设置下一个窗口的位置，必须在 `begin` 前调用 |
| `set_next_window_size(width, height, cond)` | 设置下一个窗口的大小 |
| `set_next_window_collapsed(collapsed, cond)` | 设置下一个窗口的折叠状态 |
| `set_next_window_bg_alpha(alpha)` | 设置下一个窗口背景透明度 |
| `set_window_font_scale(scale)` | 设置当前窗口的字体缩放 |
| `is_window_hovered(flags)` | 判断当前窗口是否被鼠标悬停 |

常用条件常量为 `ImGui.COND_ALWAYS`、`ImGui.COND_ONCE`、`ImGui.COND_FIRST_USE_EVER` 和 `ImGui.COND_APPEARING`。

### 控件

```gdscript
ImGui.text("文本")
ImGui.separator()
ImGui.spacing()
ImGui.same_line()

if ImGui.button("Button", 0.0, 0.0):
	pass

if ImGui.small_button("Small button"):
	pass

var enabled: bool = false
enabled = ImGui.checkbox("Enabled", enabled)

var value: float = 0.5
value = ImGui.slider_float("Value", value, 0.0, 1.0)
```

带值的控件采用“传入当前值，返回新值”的方式使用，例如 `checkbox` 和 `slider_float`。

## 窗口标志

窗口标志通过 `begin_ex` 传入，可以使用按位或组合：

| 标志 | 作用 |
| --- | --- |
| `WINDOW_NO_TITLE_BAR` | 隐藏标题栏 |
| `WINDOW_NO_RESIZE` | 禁止用户拉伸窗口 |
| `WINDOW_NO_MOVE` | 禁止用户移动窗口 |
| `WINDOW_NO_SCROLLBAR` | 隐藏滚动条 |
| `WINDOW_ALWAYS_AUTO_RESIZE` | 根据内容自动调整窗口大小 |
| `WINDOW_NO_BACKGROUND` | 隐藏窗口背景和外围边框 |
| `WINDOW_NO_MOUSE_INPUTS` | 窗口不接收鼠标输入 |
| `WINDOW_NO_INPUTS` | 窗口不接收鼠标和键盘输入 |

例如：

```gdscript
var flags: int = ImGui.WINDOW_NO_RESIZE | ImGui.WINDOW_ALWAYS_AUTO_RESIZE
var expanded: bool = ImGui.begin_ex("Fixed window", flags)
if expanded:
	ImGui.text("Content")
ImGui.end()
```

## 项目 DebugOverlay

调试面板位于 `#Template/[Scripts]/Level/DebugOverlay.gd`，运行时由 `Player` 实例化。

- 按 `D` 显示或折叠面板，仅 Debug 构建响应。
- `R` 重新加载当前关卡。
- `K` 结束当前游戏。
- 默认字体缩放为 `1.5x`。
- 窗口使用 `WINDOW_NO_BACKGROUND`、`WINDOW_NO_SCROLLBAR`、`WINDOW_NO_RESIZE` 和 `WINDOW_ALWAYS_AUTO_RESIZE`。
- Android 额外使用 `WINDOW_NO_MOVE`，避免触摸转鼠标事件导致点击空白区域时拖动窗口。

当前插件使用内置默认字体，DebugOverlay 文本使用英文。项目没有 `MiSans` 字体资源，也没有旧 C++ 插件的 `ImGuiConfig.tres` 字体配置。若要替换或全局修改字体，需要在 `dear-imgui-godot` Rust 源码中修改字体构建逻辑并重新编译对应平台库；`set_window_font_scale` 只改变当前窗口的显示比例。

## Android 支持

Android GDExtension 配置位于 `addons/dear-imgui-godot/dear-imgui-godot.gdextension`：

```text
android.debug.arm64     -> target/android/debug/arm64/libdear_imgui_godot.so
android.release.arm64   -> target/android/release/arm64/libdear_imgui_godot.so
android.debug.x86_64    -> target/android/debug/x86_64/libdear_imgui_godot.so
android.release.x86_64  -> target/android/release/x86_64/libdear_imgui_godot.so
```

导出 Android 时，导出架构必须与设备和上面的库匹配。当前仓库提供 `arm64` 和 `x86_64`，没有 `armeabi-v7a` 库。

本仓库保存已经编译好的 GDExtension 库；Rust 构建源码和构建流程位于上游仓库：

<https://github.com/meny2333/dear-imgui-godot>

不要把旧的 `addons/imgui-godot` 路径重新加入导出项目，也不要只复制一个架构的 `.so` 后把 Android 导出配置设成其他架构。

## iOS 支持

iOS GDExtension 条目位于 `addons/dear-imgui-godot/dear-imgui-godot.gdextension`：

```text
ios.debug.arm64   -> target/ios/debug/arm64/libdear_imgui_godot.dylib
ios.release.arm64 -> target/ios/release/arm64/libdear_imgui_godot.dylib
```

当前仓库不在 Linux 工作区编译 iOS 库。根目录的 `Build ImGui iOS GDExtension` GitHub Actions workflow 会在 `macos-14` runner 上从 `meny2333/dear-imgui-godot` 的 `main` 分支编译 `aarch64-apple-ios`，并上传上述 `target/ios` 目录。执行方式为 GitHub 仓库的 **Actions** -> **Build ImGui iOS GDExtension** -> **Run workflow**。

iOS 导出必须在 macOS + Xcode 环境完成；Actions 产物下载后，解压到插件目录，使两个 `.dylib` 路径与 `.gdextension` 配置一致。当前只覆盖 arm64 真机，不包含 iOS Simulator 架构。

## C# 支持

插件附带 `addons/dear-imgui-godot/dotnet/ImGui*.cs` wrapper。C# 项目可以直接调用与 GDScript 对应的 PascalCase 方法：

```csharp
using Godot;

public partial class ImGuiExample : Node
{
    public override void _Ready() => ImGui.OnLayout(OnLayout);

    private void OnLayout()
    {
        if (ImGui.Begin("Example"))
            ImGui.Text("Hello from C#");
        ImGui.End();
    }
}
```

C# wrapper 不是 Android 运行库；Android 运行库仍然由 `.gdextension` 中的 Rust `.so` 提供。使用 C# 时仍需启用 `ImGui` autoload。

## 常见问题

### 调用没有显示

确认以下项目设置存在：

1. `res://addons/dear-imgui-godot/plugin.cfg` 已启用。
2. autoload 中存在名为 `ImGui` 的项目单例。
3. UI 调用位于 `ImGui.imgui_layout` 回调中。
4. 对应平台的 GDExtension 文件存在，并且架构匹配。

安装或更新插件后，重启 Godot 编辑器；必要时在 Project Settings 的 Plugins 页面将插件和 `ImGui` autoload 分别关闭再开启。

### `begin()` 返回 `false`

这是窗口折叠或当前内容被裁剪时的正常返回值。不要因为返回 `false` 跳过 `ImGui.end()`。

### 回调中出现崩溃或后续代码不执行

不要在 `imgui_layout` 回调中使用 `await`。按钮触发的异步工作应延迟到回调结束后执行，UI 本身仍必须在同一个同步回调中完成。

### Android 提示缺少运行库

检查 `dear-imgui-godot.gdextension` 使用的是 `android.debug.*` 或 `android.release.*` 条目，并确认对应的 `libdear_imgui_godot.so` 被 Git 跟踪且未被导出过滤器排除。
