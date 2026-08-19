<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="icon.png">
    <img src="icon.png" alt="Godot Line" width="180">
  </picture>
  <h1 align="center">Godot Line</h1>
  <p align="center">
    <em>基于 Godot 4.7 的 Dancing Line 游戏模板框架</em>
  </p>
</p>

<p align="center">
  <a href="https://godotengine.org/">
    <img src="https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white" alt="Godot 4.7">
  </a>
  <a href="https://github.com/godotline/godot-line/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-f5de50?logo=open-source-initiative" alt="MIT License">
  </a>
  <a href="https://github.com/godotline/godot-line/releases">
    <img src="https://img.shields.io/github/v/release/godotline/godot-line?color=ff6b6b&logo=github" alt="Release">
  </a>
  <a href="https://github.com/godotline/GodotLineCollection">
    <img src="https://img.shields.io/badge/Collection-GodotLine-a29bfe?logo=github" alt="GodotLineCollection">
  </a>
  <a href="https://github.com/godotline/godot-line/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/godotline/godot-line?color=00cec9" alt="Contributors">
  </a>
</p>

<p align="center">
  <a href="#-特性">特性</a> •
  <a href="#-快速开始">快速开始</a> •
  <a href="#-输入控制">输入控制</a> •
  <a href="#-项目结构">项目结构</a> •
  <a href="#-脚本系统">脚本系统</a> •
  <a href="#-贡献">贡献</a>
</p>

- 移植自： [DLMTP-Template](https://github.com/XGames-Studio/DLMTP-Template)
- Godot版本：Godot 4.7
## 模板说明

本模板为[QiE2035/DLFM_Godot](https://gitee.com/QiE2035/DLFM_Godot)的再次修改

准确来说，本模板剥离自 [Shinnline](https://chinadlrs.com/app/67) 源工程

使用本模板制作的关卡，可以通过 PCK 包的方式直接被收录进 ShinnLine，无需将关卡源工程搬入 ShinnLine 源工程

我们修改这个模板的目的是为了减少 ShinnLine 源工程的负担，同时提高关卡制作的效率

本模板内置了一些好用的插件，例如Unidot导入、NoteReader OSU 谱面文件铺路机，请查看右上角的 模板 列表了解更多

## 模板使用前必读！
0. 请务必使用上方的 **Use This Template** 创建一个自己的 Github 仓库方便管理
- 若你不需要创建 Github 仓库，请点击上方 **绿色的 Code 按钮**，单击 **Download Zip** 下载模板文件

~~1. 首先你需要将音乐文件放入 `Assets\Resources\MusicTrack` 并命名为 `Level[场景名称].mp3/ogg/wav`~~

~~-  例如场景名称为 `Autumn` 则音乐文件的路径为 `Assets\Resources\MusicTrack\LevelAutumn.mp3`~~

**以上加载方法已废弃**
1. 音乐文件需要放入LevelData里面的LevelAudioClip，否则无法加载音乐
- 此处音乐文件格式任意，只要是 Unity 可以读取的音乐文件格式即可
2. `#Template\[Scenes]\DefaultScene` 文件夹为默认场景模板，你可以根据自己的需要修改这些文件，但请注意保持文件名字的统一性
3. 请自行修改关卡信息里的 `levelTitleKey` 为**你的关卡的英文名**
4. 请不要移动模板内任何文件的位置，推荐 使用专门的文件夹存放关卡的模型和模型包


## 投稿方式
1. 可以将关卡录制成视频给我们审核
- 你可以加入 [GodotLine 模板交流群](http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=NnqD9QUw7D9K3wAuCI-IT1-PNO9LB7FR&authKey=RXS5hzAQnpevmQvAZVKSt7qL9%2FDtJsvpgJmP1aWV7aC7jwlZekV8%2FW9NerB9Blqv&noverify=0&group_code=1074036493) 联系管理员进行投稿
2. 在你的关卡被同意收录后，你需要向我们提供你的关卡的英文名、中文名、实用(?)音乐、音乐作者、关卡作者这些信息

感谢你选择使用这个模板！

---

## ✨ 特性

- **🎮 Dancing Line 核心玩法** — 完整的游戏机制
- **🔄 高兼容性** — 与冰焰模板 3 / 4 对齐，便捷的关卡迁移体验
- **📦 开箱即用** — 内置完整游戏框架、模板系统与关卡编辑器插件
- **🧩 模块化设计** — 组件式触发器，清晰易扩展
- **🌐 跨平台** — 支持 Windows、Linux、macOS、Android
- **🔌 MCP 支持** — 内置 godot_mcp 插件，支持 AI 辅助开发
- **📤 一键发布** — 支持将关卡发布到 [GodotLineCollection](https://github.com/godotline/GodotLineCollection)

## 🚀 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| Godot Engine | **4.7** 或更高|

### 安装

```bash
git clone https://github.com/godotline/godot-line.git
cd godot-line
```

### 新建关卡

使用编辑器工具栏 **Template > 新建关卡**，自动创建关卡场景与 LevelData 资源。

## 🎮 输入控制

| 操作 | 按键 | 说明 |
|------|------|------|
| 转向 | `鼠标左键` / `Space` | 控制线条转向 |
| 重试 | `R` | 重新加载当前关卡 |
| 击杀 | `K` | 立即结束当前局 |
| 调试 | `D` | 切换调试覆盖层（仅 Debug 构建） |
| 假玩家转向 | `P` | 假玩家手动转向（`FakePlayer` 可配置） |
| 变速 | `T` | 切换游戏速度倍率（`TimeScale` 可配置） |

## 📁 项目结构

```
godot-line/
├── #Template/                  # 核心模板系统
│   ├── [Scripts]/              # GDScript 源码
│   │   ├── Animator/           #   动画控制器
│   │   ├── Auto/               #   自动播放系统
│   │   ├── CameraScripts/      #   摄像机跟随（新旧两代）
│   │   ├── Editor/             #   编辑器工具脚本
│   │   ├── GUI/                #   游戏界面逻辑
│   │   ├── Guidance/           #   引导系统
│   │   ├── Level/              #   关卡管理
│   │   ├── Settings/           #   设置与延迟配置
│   │   └── Trigger/            #   触发器组件（纯组件模式）
│   ├── [Resources]/            # 场景、模型、UI 资源
│   ├── [Materials]/            # 材质资源
│   ├── [Music]/                # 音频文件
│   ├── Player.tscn             # 玩家场景
│   ├── Trigger.tscn            # 触发器容器场景
│   ├── Gem.tscn                # 钻石场景
│   ├── Obstacle.tscn           # 障碍物场景
│   ├── Ground.tscn             # 地面场景
│   ├── Pyramid.tscn            # 金字塔场景
│   ├── Crystal.tscn            # 水晶场景
│   ├── CameraRoot.tscn         # 摄像机根节点
│   ├── CrownCheckPoint.tscn    # 皇冠检查点
│   ├── HeartCheckPoint.tscn    # 心脏检查点
│   ├── FakePlayer.tscn         # 假玩家（路点展示）
│   ├── FallPredictor.tscn      # 坠落预测器
│   └── Percentage.tscn         # 进度百分比显示
│   └── [Scenes]/                # 模板关卡场景（供新建关卡插件使用）
│       ├── DefaultScene/        # 默认主关卡模板
│       └── Sample/              # 示例关卡模板
├── [Scenes]/                    # 已创建关卡（新建关卡插件输出目录）
├── addons/
│   ├── template/               # 编辑器插件（工具栏、关卡创建）
│   └── godot_mcp/              # MCP 服务器插件（AI 辅助开发）
├── project.godot               # 项目配置
├── export_presets.cfg          # 导出预设
└── icon.png                    # 项目图标
```

## 🧩 脚本系统

### 核心单例

| 类名 | 类型 | 职责 |
|------|------|------|
| `LevelManager` | `RefCounted` | 游戏状态机、检查点、复活监听 |
| `AudioManager` | `RefCounted` | 音频播放与控制 |
| `CameraFollower` | `class_name` | 新摄像机跟随系统 |
| `OldCameraFollower` | `class_name` | 旧摄像机跟随系统 |

## 📖 文档

- 📘 [详细教程与 API 文档](https://www.cnblogs.com/mmme/p/-/tutorial)
- 📝 [贡献指南](./CONTRIBUTING.md)
- 🔧 [插件商店](https://github.com/godotline/godotline-plugin-registry)（通过 Template > 插件商店安装）

## 🤝 贡献

欢迎贡献！请遵循以下流程：

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feat/your-feature`
3. 提交更改：`git commit -m 'Add: some feature'`
4. 推送：`git push origin feat/your-feature`
5. 创建 Pull Request

> 代码规范请遵循 [Godot GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)。所有脚本需使用显式类型注解和camelCase，并给出与冰焰模板相通之处。

## 📬 联系方式

- **🐛 Bug 反馈** — [GitHub Issues](https://github.com/godotline/godot-line/issues)
- **💬 交流群** — [GodotLine 模板交流群](http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=NnqD9QUw7D9K3wAuCI-IT1-PNO9LB7FR&authKey=RXS5hzAQnpevmQvAZVKSt7qL9%2FDtJsvpgJmP1aWV7aC7jwlZekV8%2FW9NerB9Blqv&noverify=0&group_code=1074036493)
- **📦 关卡发布** — [GodotLineCollection](https://github.com/godotline/GodotLineCollection)

## 📄 许可证

本项目基于 [MIT License](./LICENSE) 开源。

## 🙏 致谢

- [Godot Engine](https://godotengine.org/) — 强大的开源游戏引擎
- [DLMTP-Template](https://github.com/XGames-Studio/DLMTP-Template) — 本项目移植自该模板
- 冰焰模板 — 对齐标准
- 所有贡献者与社区成员 ❤️

---

<p align="center">
  <sub>Made with ❤️ using Godot Engine 4.7</sub>
  <br>
  <a href="https://deepwiki.com/godotline/godot-line">
    <img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki">
  </a>
</p>
