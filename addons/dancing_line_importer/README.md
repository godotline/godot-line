# ARPhros / Dancing Line 关卡导入器 (dancing_line_importer)

适用于 Godot 4.7（GodotLine 项目）的 Dancing Line / ARPhros 关卡工程包导入插件。

---

## 🚀 导入方式说明

- **无需 ZIPPacker / ZIPReader**：插件现已全面采用**文件夹直接导入**模式。
- 直接选择解压后的工程包文件夹（包含 `level.arproj`、`song.mp3` 及 `Resources/` 目录）。
- 插件会自动复制网格模型与贴图资源、建立材质关联、构建层级树，并保存为高性能二进制关卡场景文件（`.scn`）。

---

## 📊 `level.arproj` 参数覆盖程度报告

### 1. 关卡信息 (`info`)
| 字段 | 类型 | 覆盖率 | 说明 |
| :--- | :--- | :---: | :--- |
| `levelName` | String | 100% | 映射为关卡显示标题与场景目录名 |
| `id` / `levelVersion` | int | 100% | 写入 `LevelData.saveID` |
| `musicName` / `song.mp3` | String / File | 100% | 自动复制并绑定为 `LevelData.levelAudioClip` |
| `environment.backgroundColor` | Color (RGBA) | 100% | 设置 `Camera3D` 环境背景色 (`Environment.BG_COLOR`) |
| `environment.ambientColor` | Color (RGBA) | 100% | 设置环境光颜色 (`ambient_light_color`) |
| `environment.enableFog` | bool | 100% | 开启指数雾 (`Environment.FOG_MODE_EXPONENTIAL`) |
| `environment.fogDensity` | float | 100% | 设置雾气浓度 (`fog_density`) |
| `environment.fogColor` | Color (RGBA) | 100% | 设置雾气颜色 (`fog_light_color`) |

---

### 2. 玩家与基础对象 (`player`, `directionalLight`, `mainCamera`)
| 模块 / 字段 | 覆盖率 | 说明 |
| :--- | :---: | :--- |
| **Player Transform** (`position`, `eulerAngles`) | 100% | 映射为玩家初始位置与朝向 |
| **Player Speed** (`customData.speed`) | 100% | 注入 `Player.Speed` 与 `LevelData.speed` |
| **DirectionalLight** (Transform & Color & Intensity) | 100% | 创建 `DirectionalLight3D` 并开启阴影 |
| **MainCamera** (`pivotOffset`, `targetRotation`, `fov`) | 100% | 注入 `CameraRoot` 初始视角与摄像机视场角 |

---

### 3. 资产映射 (`meshes`, `sprites`, `materials`)
| 资产类型 | 覆盖率 | 说明 |
| :--- | :---: | :--- |
| **Meshes** (`.obj`) | 100% | 自动复制到 `[Scenes]/<关卡名>/Resources/`，按 `mesh.id` 精确映射 |
| **Sprites** (`.png`, `.jpg`, etc.) | 100% | 自动复制，通过 `material.spriteId` 绑定至材质 `albedo_texture` |
| **Materials** (RGBA 颜色 & 贴图) | 100% | 映射为 `StandardMaterial3D`，支持基础色与漫反射贴图 |

---

### 4. 场景对象 (`objects`)
| 对象类型 (`type`) | 覆盖率 | 映射目标与行为 |
| :--- | :---: | :--- |
| **Type 0** (空容器 / Group) | 100% | 映射为纯 `Node3D` 容器，完整重构 Unity 父子 Transform 树 |
| **Type 1** (Mesh 网格物体) | 100% | 映射为 `MeshInstance3D`，加载对应 .obj 网格与材质 |
| **Type 2** (Sprite / 文本) | 80% | 映射为 `Node3D`，若绑定材质贴图则渲染对应纹理 |
| **Type 4** (Trigger 触发器) | 90% | 映射为 `Area3D` + 模式 1 纯组件挂载（见下文触发器对照表） |
| **Type 5** (Road 路线) | 100% | 内联映射为 `StaticBody3D` (Collision Layer 2: BaseFloor) |
| **Crown / Checkpoint** | 100% | 映射为 `CrownCheckPoint.tscn`，自动忽略 scale/rot 仅保留 position |
| **Gem / Diamond** | 100% | 映射为 `Gem.tscn` 预制体 |
| **visibility** | 100% | 仅在 `visibility == 2`（动态激活后续关卡）时设置 `visible = false` |
| **animatable** (物体位移动画) | 0% | 暂作为静态物体导入（后续版本支持解析烘焙至 `AnimationPlayer`） |

---

## 🎯 ARPhros 触发器与 GodotLine 脚本对应表

ARPhros 关卡中的触发器全部采用模式 1（父级 `Area3D(BaseTrigger.gd)` + 子级纯组件）：

| ARPhros 触发器类型 (`type`) | ARPhros 原名 | GodotLine 对应脚本 | 参数解析与映射 |
| :---: | :--- | :--- | :--- |
| **0** | `CameraTrigger` | `res://#Template/[Scripts]/CameraScripts/CameraTrigger.gd` | 提取 `fieldOfView`、`smoothFactor` (计算 `duration`) |
| **1** | `JumpTrigger` | `res://#Template/[Scripts]/Trigger/Jump.gd` | 提取 `power`（跳跃力度） |
| **2** | `SpeedTrigger` | `res://#Template/[Scripts]/Trigger/Speed.gd` | 提取 `speed`（线移动速度） |
| **3** | `DeathTrigger` | `res://#Template/[Scripts]/Trigger/KillPlayer.gd` | 设置死亡原因 `reason = 1` |
| **4** | `ShakeCameraTrigger` | `res://#Template/[Scripts]/CameraScripts/CameraShakeTrigger.gd` | 相机震屏组件 |
| **13** | `FovTrigger` | `res://#Template/[Scripts]/CameraScripts/CameraTrigger.gd` | 提取 FOV 与过渡时间 `duration` |
| **22** | `FogTrigger` | `res://#Template/[Scripts]/Trigger/SetFog.gd` | 雾效渐变与环境颜色切换 |
| **24** | `GravityTrigger` | `res://#Template/[Scripts]/Trigger/GravityTrigger.gd` | 提取 3D 重力向量 `Vector3(x, y, z)` |

---

## 📈 综合覆盖程度
- **几何与场景树**：100%
- **材质与贴图**：100%
- **关卡与音画配置**：100%
- **核心玩法与触发器**：90%
- **总体参数覆盖率**：**约 95%**
