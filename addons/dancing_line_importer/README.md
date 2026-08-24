# ARPhros / Dancing Line 关卡导入器 (dancing_line_importer)

适用于 Godot 4.7（GodotLine 项目）的 Dancing Line / ARPhros 关卡工程包导入插件。

---

## 🚀 导入方式说明

- **无需 ZIPPacker / ZIPReader**：插件现已全面采用**文件夹直接导入**模式。
- 直接选择解压后的工程包文件夹（包含 `level.arproj`、`song.mp3` 及 `Resources/` 目录）。
- 插件会自动复制网格模型与贴图资源、建立材质关联、构建层级树，并保存为高性能二进制关卡场景文件（`.scn`）。

---

## 🪞 左右镜像说明

导入的关卡场景整体沿 **X 轴左右镜像**（由 `scripts/LevelLoader.gd` 顶部 `MIRROR_X = true` 控制，设为 `false` 恢复恒等坐标行为）：

- **Scene_001 容器作为唯一反射载体**（`scale = (-1,1,1)`）：内部所有物体的本地变换保持 arproj 原值，合成世界变换时自动取反——动画器烘焙与 meta 语义不受影响；载体必须是纯容器（物理体不支持负缩放祖先）
- 载体外的实体单独镜像：
  - 玩家出生位置取反 x、朝向旋转共轭，并同步写入 `firstDirection`（运行时朝向由它驱动，仅改节点 rotation 无效）
  - 相机枢轴 / CameraTrigger offset 取反 x；targetRotation / CameraTrigger rotation 旋转共轭（四元数 `(w,x,y,z)→(w,x,-y,-z)`）
  - 平行光方向旋转共轭
- Label3D 文本以 `scale.x = -1` 抵消字形翻转；重力触发器向量 x 分量取反

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
| **Meshes** (`.obj`) | 100% | 自动复制到 `[Scenes]/<关卡名>/Resources/`，按 `mesh.id` 精确映射；加载时在网格子节点施加 `(-sx, sy, sz)` 缩放（保留原始符号），复刻 Unity OBJ 导入器的顶点 X 取反（RH→LH）——含 `scale.x<0` 的显式镜像件，否则模型相对原版左右镜像 |
| **Sprites** (`.png`, `.jpg`, etc.) | 100% | 自动复制，通过 `material.spriteId` 绑定至材质 `albedo_texture` |
| **Materials** (RGBA 颜色 & 贴图) | 100% | 映射为 `StandardMaterial3D`，支持基础色与漫反射贴图 |

---

### 4. 场景对象 (`objects`)
| 对象类型 (`type`) | 覆盖率 | 映射目标与行为 |
| :--- | :---: | :--- |
| **Type 0** (图元 / Group) | 100% | `customData.type` 为 Unity PrimitiveType（0=Sphere / 3=Cube / 4=Plane）时映射为对应网格；`canCollide=true` 附加 `StaticBody3D`（`obstacleType=1` 为致命障碍 Layer 4，其余 Layer 2 可站立）；无 customData 时为纯 `Node3D` 容器 |
| **Type 1** (Mesh 网格物体) | 100% | 映射为 `MeshInstance3D`，加载对应 .obj 网格与材质 |
| **Type 2** (Sprite / 文本) | 80% | 映射为 `Node3D`，若绑定材质贴图则渲染对应纹理 |
| **Type 4** (Trigger 触发器) | 90% | 映射为 `Area3D` + 模式 1 纯组件挂载（详情参见 `Trigger.md`） |
| **Type 5** (Road 路线) | 100% | 内联映射为 `StaticBody3D` (Collision Layer 2: BaseFloor) |
| **Crown / Checkpoint** | 100% | 映射为 `CrownCheckPoint.tscn`，自动忽略 scale/rot 仅保留 position |
| **Gem / Diamond** | 100% | 映射为 `Gem.tscn` 预制体 |
| **visibility** | 100% | `1`=自身不渲染（仅隐藏网格表现，保留碰撞与子树，如空气墙/场景容器图元）；`2`=隐藏整个子树待 VisibilityTrigger 激活；`0`=正常可见 |
| **animatable** (物体位移动画) | 0% | 暂作为静态物体导入（后续版本支持解析烘焙至 `AnimationPlayer`） |

---

## 🎯 触发器系统文档
触发器参数结构、动画解析与 GodotLine 脚本映射明细已独立整理至：
👉 **[`Trigger.md`](./Trigger.md)**

---

## 📈 综合覆盖程度
- **几何与场景树**：100%
- **材质与贴图**：100%
- **关卡与音画配置**：100%
- **核心玩法与触发器**：90%
- **总体参数覆盖率**：**约 95%**
