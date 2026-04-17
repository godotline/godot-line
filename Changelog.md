# Changelog

所有显著的项目变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0-stable] - 2026-04-12

### Changed
- 移除多个3D场景资源并优化主场景依赖
  - 删除 Crown、CrownSet、DeathParticle、GAMEUI、GuideTap 和 RoadMaker 场景文件
  - 在 Player 场景中引入 DeathParticle 预制资源
  - 更新 Sample 场景引用，迁移资源路径至 #Template/[Resources] 文件夹
  - 将原有 Crown 和 CrownSet 资源拆解为脚本和纹理等单独资源重新管理
  - 添加 StandardMaterial3D 和相应的动画资源到 Sample 场景，保持视觉效果一致

---

## [v1] - 2026-04-11

### Added
- 相机变换类型支持 (`Camera transtype`)

---

## [0.0.1] - 2026-04-11

### Added
- 角色旋转角度四舍五入量化功能

### Changed
- 引导线游戏内音乐资源和多种难度关卡
- 优化相机跟随逻辑，新增平滑插值(lerp)跟随功能
- 替换CamShaker基类为BaseTrigger，改进摄像机抖动机制
- 重构检查点保存与加载逻辑，清理冗余代码
- 优化场景结构及移除未使用组件
- 重构状态管理逻辑和补间动画实现

---

## [Unreleased]

### Added
- 预备检查点还原动画功能

### Changed
- 文档更新 (6d29353)

### Removed
- 删除 report_1 相关的 HTML 报告页面、CSS 样式文件和面包屑导航样式
- 删除报告中使用的 logo 图片资源及其导入配置
- 删除 report_1 的测试结果 XML 文件
- 清除所有与 report_1 报告生成相关的静态资源和数据

### Fixed
- 完善复活逻辑
- 修复模板导入冲突
- 实现音画同步及死亡粒子效果优化

## [1.0.0] - 2026-03-21

### Added
- 初始项目提交
- 基础游戏框架搭建
- ShinnLine功能导入
- 相机复活视角功能
- 基础场景和脚本结构

### Changed
- 项目初始化配置
- 模板系统建立
- 核心游戏循环实现

## 提交类型说明

- **Added**: 新增功能
- **Changed**: 现有功能的变更
- **Deprecated**: 即将废弃的功能
- **Removed**: 已移除的功能
- **Fixed**: 修复的bug
- **Security**: 安全相关的修复或改进