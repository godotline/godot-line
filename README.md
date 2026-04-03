# Godot Line - 3D 线条跑酷游戏

基于 Godot Engine 4.6 开发的 3D 线条跑酷游戏，玩家控制一条不断延伸的线条在赛道上奔跑，通过转向来避开障碍物并收集道具。

![Godot Version](https://img.shields.io/badge/Godot-4.6-green.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 🎮 游戏特色

- **独特的线条移动机制**：玩家控制一条 3D 线条在赛道上奔跑，通过点击或按键实现转向
- **动态道路生成**：线条移动时会自动生成地面道路，创造属于自己的赛道
- **丰富的收集要素**：收集钻石和皇冠，解锁不同成就
- **流畅的动画系统**：转向时播放平滑的动画效果
- **粒子特效**：落地时触发精美的粒子效果
- **完整的 UI 系统**：包含关卡选择、结算界面、进度显示等

## 📁 项目结构

```
godot-line/
├── #Template/                    # 核心模板资源
│   ├── [Materials]/              # 材质资源（地板、墙壁等）
│   ├── [Music]/                  # 背景音乐
│   ├── [Resources]/              # 模型、贴图、音效等资源
│   │   ├── Models/               # 3D 模型（钻石、皇冠等）
│   │   └── ui/                   # UI 贴图
│   ├── [Scenes]/                 # 场景模板
│   ├── [Scripts]/                # 核心脚本
│   │   ├── CameraScripts/        # 摄像机控制脚本
│   │   ├── GuideLine/            # 引导线脚本
│   │   ├── Trigger/              # 各类触发器脚本
│   │   └── ...                   # 其他功能脚本
│   └── level_patch_meta.tres     # 关卡元数据模板
├── .godot/                       # Godot 编辑器缓存（已忽略）
├── .vscode/                      # VSCode 配置
├── UGC.md                        # UGC 功能详细文档
├── base.pck                      # 基础资源包
├── export_presets.cfg            # 导出预设配置
└── project.godot                 # 项目配置文件
```

## 🎯 核心系统

### 1. 玩家控制 (MainLine)

**文件**: `#Template/[Scripts]/MainLine.gd`

玩家控制的核心逻辑，负责：
- 移动和转向控制
- 碰撞检测
- 信号发射（`new_line1`、`on_sky`、`onturn`）
- 死亡判定

**操作方式**：
- **转向**：鼠标左键 / 空格键
- **重试**：R 键
- **保存赛道**：S 键
- **快速重载**：Q 键
- **保存锥形**：W 键

### 2. 道路生成 (RoadMaker)

**文件**: `#Template/[Scripts]/RoadMaker.gd`

监听玩家移动信号，动态生成地面道路：
- 实时跟随玩家位置生成地面
- 自动拉伸模型以匹配移动距离
- 支持将生成的道路保存为场景文件

### 3. 摄像机系统

**脚本集合**: `#Template/[Scripts]/CameraScripts/`
- **CameraFollower**: 摄像机跟随逻辑
- **CameraTrigger**: 区域触发器切换摄像机
- **CamTransitionTrigger**: 摄像机过渡触发
- **CamShaker**: 摄像机震动效果

### 4. 触发器系统

**目录**: `#Template/[Scripts]/Trigger/`

包含多种游戏逻辑触发器：
- **Crown**: 皇冠收集
- **Diamond**: 钻石收集
- **Jump**: 跳跃触发
- **PosAnimator/LocalPosAnimator**: 位置动画
- **RotAnimator**: 旋转动画
- **FogColorChanger**: 雾效颜色变更
- **Ending**: 结局触发
- **animplay/customanimplay**: 动画播放触发

### 5. 游戏 UI (gameui)

**文件**: `#Template/[Scripts]/gameui.gd`

完整的用户界面系统：
- 关卡名称显示
- 钻石/皇冠计数
- 完成度百分比
- 重试/返回/回放功能

### 6. 状态管理 (State)

**文件**: `#Template/[Scripts]/State.gd`

全局单例状态管理（Autoload）：
- 游戏状态持久化
- 玩家数据（钻石、皇冠数量）
- 摄像机状态
- 重生标志

## 🛠️ UGC（用户生成内容）系统

项目支持完整的 UGC 功能，允许玩家创建和分享自定义关卡。

### 运作流程

1. **录制关卡**：玩家在编辑器模式下控制角色移动，自动生成道路
2. **保存场景**：按下保存键将录制的道路保存为 `.tscn` 文件
3. **配置元数据**：创建 `LevelPatchMeta` 资源定义关卡信息
4. **生成补丁**：运行 `GenerateLevelPatch.gd` 编辑器脚本集成到游戏

### 元数据字段

```gdscript
- name: 关卡英文名
- chinese_name: 关卡中文名
- star: 难度星级 (0-6)
- level_maker: 关卡制作者
- music_maker: 音乐制作者
- tiny_levels: 关联的场景路径数组
```

详细的 UGC 机制说明请查看 [UGC.md](UGC.md)

## ⚙️ 技术规格

### 引擎配置
- **Godot 版本**: 4.6
- **渲染器**: Mobile（移动端优化）
- **物理引擎**: Jolt Physics
- **3D 物理线程**: 独立运行

### 输入映射
| 动作名 | 绑定按键 | 功能描述 |
|--------|----------|----------|
| `turn` | 鼠标左键 / 空格 | 转向 |
| `retry` | R | 重试当前关卡 |
| `save` | S | 保存赛道 |
| `reload` | Q | 快速重载 |
| `savetaper` | W | 保存锥形数据 |

### 物理层设置
- **Layer 1**: MainLine（玩家主线）
- **Layer 2**: BaseFloor（基础地面）
- **Layer 3**: BaseWall（基础墙壁）

## 🚀 快速开始

### 前置要求
- Godot Engine 4.6+
- .NET 8.0 SDK（可选，用于 C# 支持）

### 安装步骤

1. 克隆仓库
```bash
git clone <repository-url>
cd godot-line
```

2. 使用 Godot 4.6+ 打开项目根目录的 `project.godot` 文件

3. 首次运行前，确保已安装 Jolt Physics 插件（如未内置）

4. 点击运行按钮或按 F5 启动游戏

### 构建发布

1. 打开 Godot 编辑器
2. 进入菜单：**项目** → **导出**
3. 选择目标平台预设（Windows/Linux/macOS）
4. 点击 **导出项目** 按钮

## 📝 开发指南

### 添加新关卡

1. 在 `#Template/level_patches/` 目录创建新的 `LevelPatchMeta` 资源
2. 配置关卡元数据信息
3. 运行 `GenerateLevelPatch.gd` 编辑器脚本
4. 新生成的关卡将自动出现在关卡选择列表

### 创建新触发器

参考现有触发器脚本（如 `Crown.gd`、`Diamond.gd`）的结构：

```gdscript
extends Area3D

@export var some_property: Type

func _on_body_entered(body: Node3D) -> void:
    # 处理碰撞逻辑
    pass
```

### 自定义材质

在 `#Template/[Materials]/` 中添加新的材质资源：
- 右键 → 创建新资源 → StandardMaterial3D
- 配置材质属性（颜色、粗糙度、金属度等）
- 保存为 `.tres` 文件

## 🔧 常见问题

### Q: 游戏运行时物理性能不佳？
A: 检查 `project.godot` 中是否启用了 `3d/run_on_separate_thread=true`

### Q: 导出的游戏缺少资源？
A: 确保所有资源都在导出预设中包含，或打包到 `.pck` 文件中

### Q: 如何修改玩家速度？
A: 调整 `MainLine.tscn` 场景中 `MainLine` 节点的 `speed` 导出变量

### Q: 摄像机不跟随玩家？
A: 检查 `CameraFollower.gd` 是否正确连接到玩家节点

## 📄 许可证

本项目采用 MIT 许可证（除非另有说明）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系方式

如有问题或建议，请通过以下方式联系：
- 提交 GitHub Issue
- 发送邮件至：<your-email@example.com>

---

**Made with ❤️ using Godot Engine**
