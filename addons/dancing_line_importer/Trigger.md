# ARPhros 触发器系统与 GodotLine 映射对照文档 (Trigger.md)

本文档详细记录 ARPhros 关卡工程包（`level.arproj` 中 `type: 4`）所有触发器类型、参数结构及在 GodotLine（模式 1 纯组件架构）下的映射规则与动画实现。

---

## 🏗 架构模式：模式 1（纯组件架构）

GodotLine 采用父子解耦的触发器模式：
- **父节点**：原生 `Area3D` 挂载 `BaseTrigger.gd`（负责物理碰撞检测与分发）。
- **子节点**：无碰撞体的纯逻辑组件（实现 `trigger(body: Node3D)` 方法）。

---

## 🎯 触发器对照与参数解析明细

### 1. 相机触发器 (CameraTrigger / FovTrigger)
- **ARPhros Type**: `0` (`CameraTrigger`) / `13` (`FovTrigger`)
- **GodotLine 脚本**: `res://#Template/[Scripts]/Camera/CameraTrigger.gd`
- **原版数据格式**:
  ```
  "True|15, 45, 0|True|0, 3, 0|True|25|True|5000|linear|0|True|True|0"
  ```
- **参数切分与映射**:
  | 索引 | 含义 | ARPhros 示例值 | GodotLine 属性 | 映射逻辑 |
  | :---: | :--- | :--- | :--- | :--- |
  | `[0]` | 是否改变旋转 | `True` | - | 决定是否触发旋转补间 |
  | `[1]` | 目标欧拉角 (Pitch, Yaw, Roll) | `15, 45, 0` | `CameraTrigger.rotation` | 解析为弧度 `Vector3(rad(x), rad(-y), rad(z))` |
  | `[2]` | 是否改变 Pivot 偏移 | `True` | - | 决定是否改变跟随偏移 |
  | `[3]` | 目标 Pivot 偏移 (X, Y, Z) | `0, 3, 0` | `CameraTrigger.offset` | 注入 `Vector3(x, y, z)` |
  | `[4]` | 是否改变 FOV / 距离 | `True` | - | 决定是否修改 FOV 与相机距离 |
  | `[5]` | 目标 FOV / 视野大小 | `25` | `CameraTrigger.fieldOfView` | 赋值给摄像机的 `fov` |
  | `[6]` | 是否平滑过渡 | `True` | - | 决定是否平滑过渡 |
  | `[7]` | 平滑速度 (Smooth Factor) | `5000` | `duration` (备用) | 当未提供明确时长时：`duration = clamp(5000.0 / smoothFactor, 0.1, 10.0)` |
  | `[8]` | 缓动曲线类型 (Ease) | `easeInOutSine` | `CameraTrigger.ease` | 映射为 DOTween `CameraFollower.Ease` 枚举 |
  | `[9]` | 补间动画时长 (Duration) | `1.0` / `3.95` | `CameraTrigger.duration` | 明确指定的过渡秒数（优先使用） |

---

### 2. 跳跃触发器 (JumpTrigger)
- **ARPhros Type**: `1`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/Jump.gd`
- **原版数据格式**:
  ```
  "0, 660, 0|False|True|True"
  ```
- **参数切分与映射**:
  | 索引 | 含义 | 映射目标 | 说明 |
  | :---: | :--- | :--- | :--- |
  | `[0]` | 3D 弹跳冲量向量 | `Jump.power = 660.0` | 提取 Y 轴弹跳力度（对应 Player.velocity.y） |
  | `[1]` | 是否在空中强制转向 | `Jump.changeDirection` | 是否随跳跃改变运动方向 |

---

### 3. 速度改变触发器 (SpeedTrigger)
- **ARPhros Type**: `2`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/Speed.gd`
- **原版数据格式**:
  ```
  "3" 或 "12.0"
  ```
- **映射规则**: 纯数值，直接写入 `Speed.speed = float(data)`，在玩家进入时修改 `Player.Speed`。

---

### 4. 冻结玩家触发器 (FreezePlayer) —— 未实现
- **ARPhros Type**: `3`（`TriggerType.FreezePlayer`，游戏源码实证；并非死亡触发器）
- **Data 字段**: `duration: float`（冻结时长）、`freezeGravity: bool`
- **现状**: 未实现，导入时告警并保留裸碰撞触发器（此前误映射为 KillPlayer，已修正）。

---

### 5. 相机震动触发器 (ShakeCameraTrigger)
- **ARPhros Type**: `4`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Camera/CameraShakeTrigger.gd`
- **原版数据格式**:
  ```
  "0|0.5|linear|0|Tweened"
  ```
- **映射规则**: 调用 `CameraFollower.instance.DoShake(power, duration)` 触发屏幕抖动。

---

### 6. 环境与雾气触发器 (EnvironmentTrigger / FogTrigger)
- **ARPhros Type**: `19` (`EnvironmentTrigger`) / `22` (`FogTrigger`)
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/SetFog.gd`
- **原版数据格式**:
  ```
  "0.01|0.1254902, 0, 0, 1|True|2.5|linear"
  "True|Color|True|0.1254902, 0, 0, 1|True|True|1, 1, 1, 1|2.5|linear"
  ```
- **参数映射**:
  - `fogDensity`: `0.01` (动态计算 `fogSetting.end = 100.0 / density`)
  - `fogColor`: `Color(0.125, 0, 0, 1)`
  - `duration`: `2.5` 秒
  - `transType`: `Tween.TRANS_LINEAR`

---

### 7. 重力覆盖触发器 (GravityTrigger)
- **ARPhros Type**: `24`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/GravityTrigger.gd`
- **原版数据格式**:
  ```
  "0, -50, 0"
  ```
- **映射规则**: 提取 X, Y, Z 三轴重力向量 `Vector3(0.0, -50.0, 0.0)`，调用 `Player.set_gravity_override(gravity)`。

---

### 8. 转向与方向触发器 (DirectionTrigger)
- **ARPhros Type**: `11`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/ChangeDirection.gd`
- **原版数据格式**:
  ```
  "0, 45, 0|0, 45, 0"
  ```
- **映射规则**: 提取一向与二向欧拉角向量 `firstDirection` 与 `secondDirection`，进入时重设玩家左右转向向量。

---

### 9. 通关触发器 (FinishTrigger)
- **ARPhros Type**: `12`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/FadeOutMusic.gd`
- **原版数据格式**:
  ```
  "True|5|0, 45, 0"
  ```
- **映射规则**: 提取 `[1]` 位的秒数（`5.0` 秒），调用 `AudioManager.FadeOut(0.0, duration)`。

---

### 10. 区域显隐触发器 (VisibilityTrigger)
- **ARPhros Type**: `18`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/SetActive.gd`
- **原版数据格式**:
  ```
  "Gone|9372|False|" 或 "Active|9515|False|"
  ```
- **参数映射**:
  - `Gone` / `Hidden` → `SingleActive.active = false` (隐藏对应场景)
  - `Active` / `Appear` → `SingleActive.active = true` (显示对应场景)
  - `target` → 关联目标场景容器 ID
  - `dontRevive` → 是否禁止复活时恢复原状
- **已知局限**: 数据中目标为裸对象 ID，而生成的节点命名为 `<名称>_<id>`，`SingleActive.target` 的相对路径可能无法命中——沿用旧行为，待后续以延迟链接（同 type 5/6/7 的后处理模式）修正。

---

### 11. 变换触发器 (MoveTrigger / RotateTrigger / ScaleTrigger)
- **ARPhros Type**: `5` (`Move` 位移) / `6` (`Rotate` 旋转) / `7` (`Scale` 缩放)
- **GodotLine 脚本**: `res://#Template/[Scripts]/Animator/LocalPosAnimator.gd` / `LocalRotAnimator.gd` / `LocalScaleAnimator.gd`
- **原版数据格式**（三者布局一致，按段位置解析；示例取自真实关卡工程）:
  ```
  "1, 1, 1|easeSpring|3|False|True||23|False"     # Move
  "40, 45, 1|easeOutBounce|3|True|False||1|False" # Rotate
  "10, 1, 10|linear|3|True|False||1|False"        # Scale
  ```
- **参数切分与映射**:
  | 索引 | 含义 | 示例 | 映射逻辑 |
  | :---: | :--- | :--- | :--- |
  | `[0]` | 目标值向量 (X, Y, Z) | `1, 1, 1` | 动画目标值；reverse 时成为起点。Rotate 单位为度，导入时转弧度 |
  | `[1]` | 缓动曲线 (Ease) | `easeSpring` | 经 `TriggerTypeMap.getAnimatorEase` 映射为 Tween 枚举（见第 12 节） |
  | `[2]` | 目标对象数字 ID | `3` | 导入后处理阶段经 nodeMap 解析为目标节点（如 `Ground_3`） |
  | `[3]` | asOffset（变换类型） | `True`=Add / `False`=New | Add=相对当前位姿的偏移；New=绝对值（对应 `MoveRotateScale_Data.asOffset`） |
  | `[4]` | useGroup | `True` / `False` | 是否按组定位目标（对应 Trigger 基类字段，暂不使用） |
  | `[5]` | groups 列表 | （空） | 组内对象 ID 列表，空组序列化为空段，按位置跳过 |
  | `[6]` | 补间时长 (秒) | `23` | 写入 `Animator.duration`；无效或 ≤0 时回退 2.0 |
  | `[7]` | 反向播放 (Reverse) | `False` | True 时交换 start/end：由目标值动画回当前位姿 |

- **导入实现**:
  - 触发器本体 = Area3D(BaseTrigger) + `EventTrigger` 子组件；进入触发体积时 BaseTrigger 鸭子调用 `trigger(body)` → `_invoke()` 发出 `triggered`。
  - 所有对象实例化完成后（`_createObjects` 末尾），`_linkTriggerAnimators` 按 `[2]` 的 ID 找到目标节点，把对应 `Local*Animator` 挂为其**子节点**（`AnimatorBase` tween 父节点），并以导入时刻的目标局部位姿**烘焙绝对值**：Add 先换算为绝对终点，再依 `[7]` 决定 start/end 归属；运行时 `transformType` 恒为 New、`triggeredByTime = false`。
  - 连接方式：`eventComp.triggered.connect(animator.Trigger, CONNECT_PERSIST)` —— **必须带 CONNECT_PERSIST**，否则 `PackedScene.pack()` 不会把该连接写入 .scn。
  - 已知语义限制：Add 在导入期已烘焙为绝对值，因此同一目标的链式先后触发使用的是导入时刻位姿，而非上一触发结束后的位姿。
  - Rotate 使用默认 `rotateMode = Fast`（最短路径）。

---

### 12. 缓动词表与未实现类型

- **动画 ease 词表**（`TriggerTypeMap.ANIMATOR_EASE_MAP`，独立于相机通道的 `CameraFollower.Ease`）：可选 `ease` 前缀 + 可选修饰符（`inout`/`outin`/`out`/`in` 按最长前缀优先 → 对应 `Tween.EaseType`；裸名 → `EASE_IN_OUT`）+ 基曲线名：`linear/sine/quad/cubic/quart/quint/expo/circ/back/elastic/bounce/spring` → 同名 `Tween.TRANS_*`。未知基名回退 linear 并 push_warning。
- **映射表架构**：触发器类型 → 组件与解析规格集中维护于 `addons/dancing_line_importer/scripts/trigger_type_map.gd`（`TRIGGER_CONFIG` / `TRIGGER_FIELD_MAP` / `ANIMATOR_EASE_MAP`）；`LevelLoader._createTriggerObject` 仅做查表分发（special 构建器 + 通用 field-kind 规格）。
- **未实现类型**：`3(FreezePlayer), 9(Teleport), 10(Sequence), 14(Stop), 15(Tail), 16(AnalogGlitch), 17(Material), 20(Code), 21(LegacyCamera), 23(Light), 25(Tap)` 记录于 `TriggerTypeMap.UNMAPPED_TRIGGER_TYPES`，命中时仅告警并保留裸碰撞触发器。

---

### 13. 颜色触发器 (ColorTrigger)
- **ARPhros Type**: `8`（`Trigger.Color_Data.targetColor`）
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/SetColor3D.gd`（模式 1 纯组件，多目标）
- **原版数据格式**（6 段）:
  ```
  "1, 0.8156863, 0, 0.6901961|easeInOutSine|-1|True|179|0"
  "1, 1, 1, 0|linear|15032|False||0.1"
  ```
- **参数切分与映射**:
  | 索引 | 含义 | 映射逻辑 |
  | :---: | :--- | :--- |
  | `[0]` | 目标颜色 RGBA | `SetColor3D.color` |
  | `[1]` | 缓动曲线 (LeanTweenType 成员名) | `getAnimatorEase` → Tween 枚举 |
  | `[2]` | 直连目标对象 ID | `useGroup=false` 时经 nodeMap 解析 |
  | `[3]` | useGroup | `true` 时按 `[4]` 组定位 |
  | `[4]` | groups 列表（逗号分隔） | 匹配对象的 `groupId` 字段 |
  | `[5]` | duration (秒) | 0 = 直接赋值不渐变 |

- **导入实现**: 触发器本体 = Area3D(BaseTrigger) + EventTrigger + SetColor3D 子组件；`_linkColorTrigger` 后处理解析目标集合填入 `targetNodes`。运行时首次触发将目标活动材质复制为 material_override，再 tween 其 albedo_color（避免污染共享模板材质）。已知限制：不做复活时颜色恢复。

---

## 📖 枚举参考（来源：游戏源码，2026-08 实证）

### TriggerType（`customData.type`）
| 值 | 名称 | 状态 |
| :---: | :--- | :--- |
| 0 | Camera | ✅ 已实现 |
| 1 | Jump | ✅ 已实现 |
| 2 | Speed | ✅ 已实现 |
| 3 | **FreezePlayer**（duration/freezeGravity） | ❌ 未实现（曾误映射为死亡） |
| 4 | ShakeCamera | ✅ 已实现 |
| 5 / 6 / 7 | Move / Rotate / Scale | ✅ 已实现（第 11 节） |
| 8 | Color（targetColor） | ✅ 已实现（SetColor3D，第 13 节） |
| 9 | Teleport（followImmediate） | ❌ 未实现 |
| 10 | Sequence（preInstance + delay） | ❌ 未实现（春节关 152 个） |
| 11 | Direction | ✅ 已实现 |
| 12 | Finish | ✅ 已实现 |
| 13 | Fov | ✅ 已实现 |
| 14 | Stop | ❌ 未实现 |
| 15 | Tail（clearTailData） | ❌ 未实现 |
| 16 | AnalogGlitch | ❌ 未实现 |
| 17 | Material（material/mainColor/emissionColor） | ❌ 未实现 |
| 18 | Visibility | ✅ 已实现 |
| 19 | Environment | ✅ 已实现 |
| 20 | Code | ❌ 未实现（脚本触发器） |
| 21 | LegacyCamera | ❌ 未实现 |
| 22 | Fog | ✅ 已实现 |
| 23 | Light | ❌ 未实现 |
| 24 | Gravity | ✅ 已实现 |
| 25 | Tap（triggerDuration/haltControl/onlyOnce/allowWhileFlying） | ❌ 未实现 |

### 其他关键枚举
- **ObstacleType**: `None=0 / Wall=1 / PassThrough=2 / Water=3`。当前映射取舍：Wall → Layer 4（玩家触碰即死，近似原版撞墙判定）；其余 → Layer 2。
- **VisibilityType**: `Shown=0 / Hidden=1 / Gone=2`。Hidden 仅自身不渲染（保留碰撞与子树）；Gone 隐藏整个子树待 VisibilityTrigger 激活。**待办**：Gone 应同时禁用碰撞，激活时恢复（当前 SetActive 仅操作 visible）。
- **ObjectType**（objects[].type）: `Primitive=0 / Model=1 / Sprite=2 / Light=3 / Trigger=4 / Road=5 / Particle=6 / Player=7 / MainCamera=8 / Empty=9 / Text=10 / Tail=11 / StartPos=12 / Unspecified=256`。注意 9/10/11 不是路线——Empty/Tail 按空容器导入，Text 映射为 Label3D。
- **Unity PrimitiveType**（type 0 的 `customData.type`）: `Sphere=0 / Cube=3 / Plane=4`。

### 变换触发器 ease 词表来源
ease 字符串为 **LeanTweenType 枚举成员名**（如 `linear`、`easeOutBounce`、`easeSpring`）。`easeSpring`(32)/`easeShake`(33) 无 in/out 修饰；Godot 侧映射见 `TriggerTypeMap.ANIMATOR_EASE_MAP`（Spring→TRANS_SPRING；shake/punch/pingPong 等无对应曲线，回退 linear 并告警）。

### Move/Rotate/Scale 参数段与游戏字段对应
管道串字段顺序对应 `Trigger` 基类 + `Trigger.MoveRotateScale_Data`：
`targetVector | ease(LeanTweenType) | target(ObjectInfo id) | asOffset | useGroup | groups列表(空→空段) | duration | reverse`
