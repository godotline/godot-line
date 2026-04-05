# Godot Line 模板

基于 **Godot Engine 4.6** 开发的 Dancing Line 游戏模板框架。本项目抽离自 ShinnLine，向冰焰模板 3/4 对齐，旨在降低使用者的学习成本。通过本模板，您可以方便地将关卡从冰焰模板 3、4（WIP）迁移到此模板，或直接发布至 ShinnLine 平台。

![Godot Version](https://img.shields.io/badge/Godot-4.6-green.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

## ✨ 特性

- 🎮 **Dancing Line 核心玩法**：完整的线条游戏机制实现
- 🔄 **高兼容性**：与冰焰模板 3/4 对齐，便于关卡迁移
- 📦 **开箱即用**：内置完整的游戏框架和模板系统
- 🧪 **测试驱动**：集成 gdUnit4 测试框架，保障代码质量
- 🎯 **模块化设计**：清晰的代码结构，易于扩展和定制
- 🌐 **跨平台支持**：支持 Windows、Linux、macOS 平台

## 🚀 快速开始

### 环境要求

- **Godot Engine 4.6** 或更高版本
- GDScript 编程基础（可选，用于自定义开发）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/meny2333/godot-line.git
   cd godot-line
   ```

2. **在 Godot 中打开项目**
   - 启动 Godot Engine 4.6
   - 选择"导入"并定位到项目文件夹
   - 等待项目扫描完成

3. **运行项目**
   - 在 Godot 编辑器中按 `F5` 运行主场景
   - 或使用 `Main.tscn` 作为启动场景

### 输入控制

| 操作 | 按键 | 说明 |
|------|------|------|
| 转向 | 鼠标左键 / 空格 | 控制线条转向 |
| 重试 | R | 重新开始关卡 |
| 保存 | S | 保存当前进度 |
| 重载 | Q | 重新加载关卡 |
| 保存锥体 | W | 保存锥体配置 |

## 📁 项目结构

```
godot-line/
├── #Template/          # 核心模板系统
├── Tests/              # 单元测试文件 (gdUnit4)
├── addons/             # Godot 插件
│   └── gdUnit4/       # 测试框架
├── reports/            # 测试报告输出
├── Main.tscn          # 主场景文件
├── project.godot      # 项目配置文件
└── CONTRIBUTING.md    # 贡献指南
```

## 🧪 测试

本项目使用 **gdUnit4** 进行单元测试，确保代码质量和稳定性。

### 运行测试

```bash
# 无头模式运行所有测试
godot --headless --run-tests

# 在编辑器中运行测试
# 打开 Godot 编辑器 → 底部面板 → gdUnit4 标签页
```

### 编写测试

- 测试文件命名规范：`*_test.gd`
- 测试文件位置：`Tests/` 目录
- 继承基类：`GdUnitTestSuite`
- 测试报告输出至：`reports/` 目录

## 📖 文档

详细教程和 API 文档请访问：
👉 [https://www.cnblogs.com/mmme/p/-/tutorial](https://www.cnblogs.com/mmme/p/-/tutorial)

## 🤝 贡献

我们非常欢迎社区贡献！无论您是报告 Bug、提出功能建议，还是提交代码修复，都是对项目的宝贵支持。

### 快速贡献指南

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b GD-111`)
3. 提交您的更改 (`git commit -m 'Add: some feature'`)
4. 推送到分支 (`git push origin GD-111`)
5. 创建 Pull Request

详细的贡献指南请查阅：[CONTRIBUTING.md](./CONTRIBUTING.md)

### ⚠️ 毁灭性更改规范

如果您的修改涉及 **破坏性 API 变更**，请务必遵循：

- PR 标题标注 `[BREAKING]`
- 提供详细的迁移指南
- 更新所有相关测试用例
- 提交到指定分支（非 master）
- 在文档中明确标注不兼容变更

## 📧 联系方式

- 🐛 **问题反馈**：[GitHub Issues](https://github.com/meny2333/godot-line/issues)
- 💬 **交流群组**：[GodotLine 模板交流群](http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=NnqD9QUw7D9K3wAuCI-IT1-PNO9LB7FR&authKey=RXS5hzAQnpevmQvAZVKSt7qL9%2FDtJsvpgJmP1aWV7aC7jwlZekV8%2FW9NerB9Blqv&noverify=0&group_code=1074036493)
- 📝 **代码规范**：遵循 [Godot GDScript 编码规范](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

## 📄 许可证

本项目采用 [MIT License](./LICENSE) 开源协议。

## 🙏 致谢

- **Godot Engine** - 强大的开源游戏引擎
- **ShinnLine** - 原始项目来源
- **冰焰模板** - 设计参考与对齐标准
- **gdUnit4** - 优秀的 Godot 测试框架
- https://github.com/Ironnoob73/DancingLineGodotTemplate
- 所有贡献者和社区成员

---

**Made with ❤️ using Godot Engine 4.6**