# Mainline Script 文档

<cite>
**本文档中引用的文件**
- [MainLine.gd](file://#Template/[Scripts]/Level/MainLine.gd)
- [GameManager.gd](file://#Template/[Scripts]/GameManager.gd)
- [State.gd](file://#Template/[Scripts]/State.gd)
- [RoadMaker.gd](file://#Template/[Scripts]/Level/RoadMaker.gd)
- [gameui.gd](file://#Template/[Scripts]/Level/gameui.gd)
- [Percentage.gd](file://#Template/[Scripts]/Level/Percentage.gd)
- [BaseTrigger.gd](file://#Template/[Scripts]/Trigger/BaseTrigger.gd)
- [Crown.gd](file://#Template/[Scripts]/Trigger/Crown.gd)
- [Diamond.gd](file://#Template/[Scripts]/Trigger/Diamond.gd)
- [Trigger.gd](file://#Template/[Scripts]/Trigger/Trigger.gd)
- [Checkpoint.gd](file://#Template/[Scripts]/Trigger/Checkpoint.gd)
- [CameraFollower.gd](file://#Template/[Scripts]/CameraScripts/CameraFollower.gd)
</cite>

## 更新摘要
**变更内容**
- 新增Singleton模式实现章节，详细介绍MainLine.instance静态实例变量
- 更新核心组件分析，增加Singleton模式的使用说明
- 新增跨脚本访问模式章节，展示如何通过MainLine.instance访问主玩家角色
- 更新依赖关系分析，反映Singleton模式对系统架构的影响

## 目录
1. [简介](#简介)
2. [项目结构](#项目结构)
3. [核心组件](#核心组件)
4. [架构概览](#架构概览)
5. [详细组件分析](#详细组件分析)
6. [Singleton模式实现](#singleton模式实现)
7. [跨脚本访问模式](#跨脚本访问模式)
8. [依赖关系分析](#依赖关系分析)
9. [性能考虑](#性能考虑)
10. [故障排除指南](#故障排除指南)
11. [结论](#结论)

## 简介

Mainline Script 是一个基于 Godot 引擎开发的 3D 平台游戏的核心脚本系统。该项目实现了流畅的玩家控制、动态道路生成、检查点系统、动画同步和音效管理等功能。系统采用模块化设计，通过信号机制实现组件间的松耦合通信。**最新更新**：系统现已实现Singleton模式，通过MainLine.instance静态实例变量提供全局访问接口，简化了跨脚本的角色访问。

## 项目结构

项目采用分层架构设计，主要包含以下核心模块：

```mermaid
graph TB
subgraph "核心游戏逻辑"
ML[MainLine.gd - 主线角色<br/>Singleton模式]
GM[GameManager.gd - 游戏管理器]
ST[State.gd - 游戏状态]
end
subgraph "环境生成"
RM[RoadMaker.gd - 道路生成器]
PERC[Percentage.gd - 百分比显示]
end
subgraph "用户界面"
GUI[gameui.gd - 游戏界面]
end
subgraph "触发器系统"
BT[BaseTrigger.gd - 基础触发器]
CT[Crown.gd - 皇冠触发器]
DT[Diamond.gd - 钻石触发器]
TR[Trigger.gd - 通用触发器]
CP[Checkpoint.gd - 检查点系统]
end
subgraph "相机系统"
CF[CameraFollower.gd - 相机跟随器<br/>Singleton模式]
end
ML --> RM
ML --> ST
ML --> GM
RM --> ML
CT --> ST
DT --> ST
GUI --> ST
BT --> TR
CP --> CF
CP --> ML
```

**图表来源**
- [MainLine.gd:1-230](file://#Template/[Scripts]/Level/MainLine.gd#L1-L230)
- [GameManager.gd:1-50](file://#Template/[Scripts]/GameManager.gd#L1-L50)
- [State.gd:1-190](file://#Template/[Scripts]/State.gd#L1-L190)
- [Checkpoint.gd:1-218](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L1-L218)
- [CameraFollower.gd:1-150](file://#Template/[Scripts]/CameraScripts/CameraFollower.gd#L1-L150)

**章节来源**
- [MainLine.gd:1-230](file://#Template/[Scripts]/Level/MainLine.gd#L1-L230)
- [GameManager.gd:1-50](file://#Template/[Scripts]/GameManager.gd#L1-L50)
- [State.gd:1-190](file://#Template/[Scripts]/State.gd#L1-L190)

## 核心组件

### 主线角色系统 (MainLine)

主线角色是游戏的核心控制器，负责玩家输入处理、物理运动计算、视觉效果管理和检查点保存。**最新特性**：实现了Singleton模式，通过静态实例变量提供全局访问接口。

**主要特性：**
- 实时物理模拟和碰撞检测
- 动态轨迹生成和可视化
- 飞行动画和着陆特效
- 死亡处理和粒子效果
- **Singleton模式实现**：通过MainLine.instance提供全局访问

### 游戏管理器 (GameManager)

提供全局游戏控制功能，包括相机跟随、位置管理和动画时间计算。

**核心功能：**
- 相机跟随器访问
- 原点位置设置和获取
- 动画开始时间计算
- 因子调节机制

### 状态管理系统 (State)

实现完整的检查点系统，支持游戏进度持久化和恢复。

**存储内容：**
- 主线角色变换矩阵
- 相机跟随器检查点
- 运行时数据缓存
- 游戏统计信息

**章节来源**
- [MainLine.gd:43-117](file://#Template/[Scripts]/Level/MainLine.gd#L43-L117)
- [GameManager.gd:33-49](file://#Template/[Scripts]/GameManager.gd#L33-L49)
- [State.gd:46-66](file://#Template/[Scripts]/State.gd#L46-L66)

## 架构概览

系统采用信号驱动的事件架构，通过松耦合的设计实现模块间的交互。**新增**：Singleton模式为跨模块访问提供了统一接口。

```mermaid
sequenceDiagram
participant Player as 主线角色
participant Road as 道路生成器
participant Trigger as 触发器系统
participant State as 状态管理器
participant UI as 用户界面
participant Singleton as Singleton访问
Player->>Road : new_line1信号
Road->>Road : 创建新道路段
Player->>Trigger : 碰撞检测
Trigger->>State : 保存检查点
Trigger->>State : 更新游戏统计
State->>UI : 更新界面显示
UI->>Singleton : 通过MainLine.instance访问
Singleton-->>UI : 返回主线角色实例
UI->>Player : 显示结果
Note over Player,State : 检查点系统工作流程
Note over Singleton,Player : Singleton模式简化访问
```

**图表来源**
- [MainLine.gd:4-7](file://#Template/[Scripts]/Level/MainLine.gd#L4-L7)
- [RoadMaker.gd:14-27](file://#Template/[Scripts]/Level/RoadMaker.gd#L14-L27)
- [Crown.gd:16-21](file://#Template/[Scripts]/Trigger/Crown.gd#L16-L21)
- [gameui.gd:13-27](file://#Template/[Scripts]/Level/gameui.gd#L13-L27)

## 详细组件分析

### 主线角色类分析

```mermaid
classDiagram
class MainLine {
+static MainLine instance
+float speed
+float rot
+Color color
+bool fly
+bool noclip
+AnimationPlayer animation_node
+bool is_turn
+Vector3 v
+bool is_live
+MeshInstance3D line
+MeshInstance3D[] floor_segment_lines
+reload() void
+turn() void
+die() void
+new_line() void
}
class RoadMaker {
+PackedScene base_floor
+float road_width
+StaticBody3D road
+Node3D roads
+new_road() void
+on_sky() void
}
class GameManager {
+Camera3D Camera
+CharacterBody3D Mainline
+float factor
+calculate_anim_start_time() float
}
class CameraFollower {
+static CameraFollower instance
+Node3D line
+Vector3 add_position
+Vector3 rotation_offset
+lerp_to() void
}
MainLine --> RoadMaker : "连接信号"
MainLine --> GameManager : "查询状态"
MainLine --> CameraFollower : "Singleton访问"
RoadMaker --> MainLine : "响应事件"
CameraFollower --> MainLine : "相机跟随"
```

**图表来源**
- [MainLine.gd:8-41](file://#Template/[Scripts]/Level/MainLine.gd#L8-L41)
- [RoadMaker.gd:3-10](file://#Template/[Scripts]/Level/RoadMaker.gd#L3-L10)
- [GameManager.gd:5-8](file://#Template/[Scripts]/GameManager.gd#L5-L8)
- [CameraFollower.gd:1-150](file://#Template/[Scripts]/CameraScripts/CameraFollower.gd#L1-L150)

#### 物理处理流程

主线角色的物理处理采用分步算法，确保稳定性和准确性：

```mermaid
flowchart TD
Start([物理帧开始]) --> CheckLive{"角色是否存活"}
CheckLive --> |否| End([结束])
CheckLive --> |是| CheckFloor{"是否在地面上"}
CheckFloor --> |是| ApplyGravity["应用重力"]
CheckFloor --> |否| NoGravity["无重力"]
ApplyGravity --> SetVelocity["设置水平速度"]
NoGravity --> SetVelocity
SetVelocity --> MoveAndSlide["移动并滑动"]
MoveAndSlide --> CheckWall{"是否碰到墙壁"}
CheckWall --> |是| Die["角色死亡"]
CheckWall --> |否| CheckFly{"是否飞行模式"}
CheckFly --> |是| FixY["固定Y坐标"]
CheckFly --> |否| Normal["正常处理"]
FixY --> End
Normal --> End
Die --> End
```

**图表来源**
- [MainLine.gd:53-62](file://#Template/[Scripts]/Level/MainLine.gd#L53-L62)
- [MainLine.gd:185-214](file://#Template/[Scripts]/Level/MainLine.gd#L185-L214)

#### 转向机制分析

转向系统实现了流畅的3D旋转和动画同步：

```mermaid
sequenceDiagram
participant Player as 主线角色
participant Animation as 动画播放器
participant Music as 音乐播放器
participant State as 状态管理器
Player->>Player : 检测转向输入
Player->>Animation : 播放转向动画
Animation->>State : 获取动画开始时间
State-->>Animation : 返回动画时间
Player->>Music : 同步音乐播放
Music->>Music : 设置播放起始位置
Player->>Player : 更新旋转状态
Player->>Player : 重新计算速度向量
```

**图表来源**
- [MainLine.gd:150-172](file://#Template/[Scripts]/Level/MainLine.gd#L150-L172)
- [GameManager.gd:33-49](file://#Template/[Scripts]/GameManager.gd#L33-L49)

**章节来源**
- [MainLine.gd:53-104](file://#Template/[Scripts]/Level/MainLine.gd#L53-L104)
- [MainLine.gd:150-172](file://#Template/[Scripts]/Level/MainLine.gd#L150-L172)

### 触发器系统分析

触发器系统采用继承和多态设计，提供灵活的游戏事件处理机制。

```mermaid
classDiagram
class BaseTrigger {
+bool one_shot
+bool debug_mode
+bool _used
+bool _signal_connected
+triggered(body) signal
+_setup_trigger() void
+_on_body_entered(body) void
+_on_triggered(body) void
}
class Crown {
+float speed
+int tag
+_get_camera_follower() Node3D
+_process(delta) void
+_on_Crown_body_entered(body) void
}
class Diamond {
+float speed
+_on_Diamond_body_entered(body) void
+_process(delta) void
}
class Trigger {
+hit_the_line signal
+_on_triggered(body) void
}
class Checkpoint {
+Direction direction
+CameraSettings camera_new
+OldCameraSettings camera_old
+revive() void
}
BaseTrigger <|-- Crown
BaseTrigger <|-- Diamond
BaseTrigger <|-- Trigger
Checkpoint --> MainLine : "通过Singleton访问"
Checkpoint --> CameraFollower : "通过Singleton访问"
```

**图表来源**
- [BaseTrigger.gd:1-38](file://#Template/[Scripts]/Trigger/BaseTrigger.gd#L1-L38)
- [Crown.gd:1-22](file://#Template/[Scripts]/Trigger/Crown.gd#L1-L22)
- [Diamond.gd:1-15](file://#Template/[Scripts]/Trigger/Diamond.gd#L1-L15)
- [Trigger.gd:1-10](file://#Template/[Scripts]/Trigger/Trigger.gd#L1-L10)
- [Checkpoint.gd:1-218](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L1-L218)

#### 检查点保存流程

```mermaid
flowchart TD
Enter([触发器进入]) --> CheckType{"检查触发器类型"}
CheckType --> |皇冠| SaveCheckpoint["保存检查点"]
CheckType --> |钻石| UpdateStats["更新游戏统计"]
CheckType --> |通用触发器| EmitSignal["发射信号"]
CheckType --> |检查点| CaptureSettings["捕获环境设置"]
SaveCheckpoint --> UpdateCrown["增加皇冠数量"]
UpdateCrown --> GetCamera["获取相机跟随器"]
GetCamera --> StoreTime["存储音乐时间"]
StoreTime --> PlayAnim["播放动画"]
PlayAnim --> FreeNode["释放节点"]
UpdateStats --> PlayCollectAnim["播放收集动画"]
PlayCollectAnim --> EmitParticles["发射粒子效果"]
EmitParticles --> FreeNode
CaptureSettings --> MainLineAccess["通过MainLine.instance访问"]
MainLineAccess --> LoadCheckpoint["加载检查点"]
LoadCheckpoint --> Revive["复活角色"]
Revive --> FreeNode
EmitSignal --> End([结束])
FreeNode --> End
```

**图表来源**
- [Crown.gd:16-21](file://#Template/[Scripts]/Trigger/Crown.gd#L16-L21)
- [Diamond.gd:6-11](file://#Template/[Scripts]/Trigger/Diamond.gd#L6-L11)
- [Checkpoint.gd:90-175](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L90-L175)

**章节来源**
- [BaseTrigger.gd:18-38](file://#Template/[Scripts]/Trigger/BaseTrigger.gd#L18-L38)
- [Crown.gd:16-21](file://#Template/[Scripts]/Trigger/Crown.gd#L16-L21)
- [Diamond.gd:6-11](file://#Template/[Scripts]/Trigger/Diamond.gd#L6-L11)

### 界面系统分析

游戏界面系统提供直观的用户反馈和操作控制。

```mermaid
stateDiagram-v2
[*] --> 隐藏状态
隐藏状态 --> 显示状态 : 角色死亡或到达终点
显示状态 --> 隐藏状态 : 用户选择继续或退出
state 显示状态 {
[*] --> 结果界面
结果界面 --> 继续游戏 : 点击继续
结果界面 --> 退出游戏 : 点击退出
继续游戏 --> [*]
退出游戏 --> [*]
}
```

**图表来源**
- [gameui.gd:13-27](file://#Template/[Scripts]/Level/gameui.gd#L13-L27)
- [gameui.gd:45-68](file://#Template/[Scripts]/Level/gameui.gd#L45-L68)

**章节来源**
- [gameui.gd:13-27](file://#Template/[Scripts]/Level/gameui.gd#L13-L27)
- [gameui.gd:30-43](file://#Template/[Scripts]/Level/gameui.gd#L30-L43)

## Singleton模式实现

**更新**：MainLine脚本新增了静态实例变量（instance），实现了Singleton模式，允许其他脚本通过MainLine.instance访问主玩家角色，无需直接节点路径引用。

### Singleton模式设计

```mermaid
classDiagram
class MainLine {
+static MainLine instance
+static var instance : MainLine
+func _ready() -> void
+{
+ instance = self
+}
}
class SingletonPattern {
<<pattern>>
+static_access() MainLine
+global_access() MainLine
+single_instance() MainLine
}
MainLine ..|> SingletonPattern : implements
```

**图表来源**
- [MainLine.gd:5](file://#Template/[Scripts]/Level/MainLine.gd#L5)
- [MainLine.gd:46-47](file://#Template/[Scripts]/Level/MainLine.gd#L46-L47)

### Singleton初始化流程

```mermaid
sequenceDiagram
participant Scene as 场景加载
participant MainLine as 主线角色
participant InstanceVar as 静态实例变量
Scene->>MainLine : 创建实例
MainLine->>MainLine : _ready()函数执行
MainLine->>InstanceVar : instance = self
InstanceVar-->>MainLine : 初始化完成
Note over MainLine,InstanceVar : Singleton模式建立
```

**图表来源**
- [MainLine.gd:46-47](file://#Template/[Scripts]/Level/MainLine.gd#L46-L47)

### Singleton模式优势

1. **全局访问**：任何脚本都可以通过MainLine.instance获取主线角色实例
2. **简化代码**：避免复杂的节点路径查找
3. **性能优化**：减少节点树遍历开销
4. **类型安全**：编译时类型检查确保访问安全性

**章节来源**
- [MainLine.gd:5](file://#Template/[Scripts]/Level/MainLine.gd#L5)
- [MainLine.gd:46-47](file://#Template/[Scripts]/Level/MainLine.gd#L46-L47)

## 跨脚本访问模式

**更新**：通过Singleton模式，多个脚本可以安全地访问主线角色实例，无需直接依赖节点树结构。

### 访问模式对比

```mermaid
graph TB
subgraph "传统访问模式"
Traditional["直接节点路径访问<br/>find_node()/get_node()"]
Traditional --> PathFinding["节点树遍历<br/>性能开销大"]
Traditional --> ErrorHandling["空节点检查<br/>运行时错误风险"]
end
subgraph "Singleton访问模式"
Singleton["MainLine.instance访问<br/>静态实例变量"]
Singleton --> DirectAccess["直接实例访问<br/>零性能开销"]
Singleton --> TypeSafe["类型安全访问<br/>编译时检查"]
Singleton --> GlobalAccess["全局可用性<br/>任何脚本均可访问"]
end
```

**图表来源**
- [gameui.gd:13-14](file://#Template/[Scripts]/Level/gameui.gd#L13-L14)
- [gameui.gd:55-65](file://#Template/[Scripts]/Level/gameui.gd#L55-L65)
- [Checkpoint.gd:91](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L91)

### 常见访问场景

#### 游戏界面访问
```gdscript
# 传统方式（不推荐）
var main_line = get_tree().current_scene.find_node("MainLine")
if main_line and main_line.is_alive:
    # 处理逻辑

# Singleton方式（推荐）
if MainLine.instance and MainLine.instance.is_live:
    # 处理逻辑
```

#### 检查点系统访问
```gdscript
# 传统方式
var main_line = get_tree().current_scene.find_node("MainLine")
if main_line:
    State.load_checkpoint_to_main_line(main_line)

# Singleton方式
var main_line = MainLine.instance
if main_line:
    State.load_checkpoint_to_main_line(main_line)
```

**章节来源**
- [gameui.gd:13-14](file://#Template/[Scripts]/Level/gameui.gd#L13-L14)
- [gameui.gd:55-65](file://#Template/[Scripts]/Level/gameui.gd#L55-L65)
- [Checkpoint.gd:91](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L91)
- [Checkpoint.gd:164](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L164)

## 依赖关系分析

**更新**：Singleton模式的引入改变了系统的依赖关系，为跨模块访问提供了统一接口。

```mermaid
graph TD
subgraph "底层依赖"
GDScript[GDScript引擎]
Physics[物理引擎]
Rendering[渲染引擎]
end
subgraph "核心层"
MainLine[主线角色<br/>Singleton模式]
GameManager[游戏管理器]
State[状态管理]
CameraFollower[相机跟随器<br/>Singleton模式]
end
subgraph "功能层"
RoadMaker[道路生成]
Triggers[触发器系统]
UI[用户界面]
Checkpoint[检查点系统]
end
subgraph "工具层"
SaveKit[SaveKit插件]
Audio[音频系统]
Particles[粒子系统]
end
GDScript --> MainLine
Physics --> MainLine
Rendering --> MainLine
MainLine --> RoadMaker
MainLine --> State
MainLine --> GameManager
MainLine --> CameraFollower
RoadMaker --> Physics
Triggers --> Physics
UI --> Rendering
Checkpoint --> MainLine
Checkpoint --> CameraFollower
State --> SaveKit
MainLine --> Audio
MainLine --> Particles
```

**图表来源**
- [MainLine.gd:28-31](file://#Template/[Scripts]/Level/MainLine.gd#L28-L31)
- [State.gd:102-117](file://#Template/[Scripts]/State.gd#L102-L117)
- [Checkpoint.gd:40-46](file://#Template/[Scripts]/Trigger/Checkpoint.gd#L40-L46)

**章节来源**
- [MainLine.gd:28-31](file://#Template/[Scripts]/Level/MainLine.gd#L28-L31)
- [State.gd:102-117](file://#Template/[Scripts]/State.gd#L102-L117)

## 性能考虑

### 内存管理优化

系统实现了智能的对象池和资源复用机制：
- 道路段实例化后自动添加到父节点
- 粒子效果使用预加载资源
- 材质和网格资源共享使用
- **Singleton模式优化**：静态实例变量避免重复查找开销

### 渲染性能优化

- 动态轨迹生成采用批量更新策略
- 地面段只在需要时创建和销毁
- 粒子系统使用GPU加速

### 物理计算优化

- 分离式物理处理避免重复计算
- 缓存常用计算结果减少CPU负载
- 优化的碰撞检测算法

### Singleton模式性能优势

**更新**：Singleton模式相比传统节点查找具有显著性能优势：

```mermaid
graph LR
A[传统节点查找] --> B[节点树遍历]
B --> C[字符串匹配]
C --> D[类型转换]
D --> E[返回结果]
F[Singleton访问] --> G[静态变量读取]
G --> H[直接返回实例]
H --> I[零开销访问]
```

**章节来源**
- [MainLine.gd:5](file://#Template/[Scripts]/Level/MainLine.gd#L5)
- [MainLine.gd:46-47](file://#Template/[Scripts]/Level/MainLine.gd#L46-L47)

## 故障排除指南

### 常见问题及解决方案

**问题1：角色无法转向**
- 检查输入映射配置
- 验证动画播放器状态
- 确认飞行模式设置

**问题2：检查点不生效**
- 验证状态序列化配置
- 检查SaveKit插件版本
- 确认节点所有权设置

**问题3：道路生成异常**
- 检查基础地面场景资源
- 验证主线路线跟踪
- 确认缩放因子设置

**问题4：Singleton访问失败**
- **新增**：确认MainLine实例已初始化
- 检查场景中是否存在MainLine节点
- 验证_engine.is_editor_hint()条件判断
- 确认instance变量未被意外修改

**问题5：跨脚本访问异常**
- **新增**：验证MainLine.instance是否为空
- 检查脚本加载顺序
- 确认Singleton模式正确实现
- 验证类型安全访问

**章节来源**
- [MainLine.gd:106-110](file://#Template/[Scripts]/Level/MainLine.gd#L106-L110)
- [State.gd:154-167](file://#Template/[Scripts]/State.gd#L154-L167)
- [RoadMaker.gd:22-27](file://#Template/[Scripts]/Level/RoadMaker.gd#L22-L27)

## 结论

Mainline Script 系统展现了优秀的游戏架构设计，通过模块化组件和信号驱动的事件系统实现了高度的可维护性和扩展性。**最新更新**：Singleton模式的引入进一步提升了系统的易用性和性能。

系统的关键优势包括：

1. **模块化设计**：清晰的职责分离和接口定义
2. **状态持久化**：完整的检查点系统确保游戏体验连续性
3. **性能优化**：智能的资源管理和计算优化
4. **扩展性强**：灵活的触发器系统支持多种游戏元素
5. **Singleton模式**：提供统一的全局访问接口，简化跨脚本交互
6. **类型安全**：编译时类型检查确保访问安全性

该系统为类似3D平台游戏开发提供了良好的参考模板，其设计理念和实现方式值得进一步研究和学习。Singleton模式的成功集成展示了现代游戏架构中全局访问模式的最佳实践。