# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本仓库的完整协作规范以 @AGENTS.md 为准（项目概览、目录结构、触发器三种模式及其规范、核心单例架构、GDScript 命名与强类型要求、常见陷阱）。开始任何工作前先阅读它；以下仅补充 Claude Code 环境下的工具映射与覆盖项。

## Claude Code

### 工具映射

- **编辑器实时交互**：使用项目自带 CLI `.gdmcp/bin/gdmcp`（需 Godot 编辑器正在运行且 godot_mcp 插件已启用，默认 HTTP `127.0.0.1:9080`）：

  ```bash
  .gdmcp/bin/gdmcp --json doctor        # 连接自检
  .gdmcp/bin/gdmcp --json editor state  # 编辑器状态
  ```

  用于检查脚本状态、Expression 求值、查看编辑器日志、分析脚本语法。连接失败通常意味着编辑器未运行——告知用户打开编辑器即可，不要反复盲试。
