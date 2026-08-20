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
- **GodotLine 脚本**: `res://#Template/[Scripts]/CameraScripts/CameraTrigger.gd`
- **原版数据格式**:
  ```
  "True|15, 45, 0|True|0, 3, 0|True|25|True|5000|linear|0|True|True|0"
  ```
- **参数切分与映射**:
  | 索引 | 含义 | ARPhros 示例值 | GodotLine 属性 | 映射逻辑 |
  | :---: | :--- | :--- | :--- | :--- |
  | `[0]` | 是否改变旋转 | `True` | - | 决定是否触发旋转补间 |
  | `[1]` | 目标欧拉角 (Pitch, Yaw, Roll) | `15, 45, 0` | `targetRotation` | 传入 `CameraFollower.Trigger()` 的 `n_rotation` |
  | `[2]` | 是否改变 Pivot 偏移 | `True` | - | 决定是否改变跟随偏移 |
  | `[3]` | 目标 Pivot 偏移 (X, Y, Z) | `0, 3, 0` | `targetOffset` | 传入 `CameraFollower.Trigger()` 的 `n_offset` |
  | `[4]` | 是否改变 FOV / 距离 | `True` | - | 决定是否修改 FOV 与相机距离 |
  | `[5]` | 目标 FOV / 视野大小 | `25` | `fieldOfView` | 赋值给摄像机的 `fov` |
  | `[7]` | 平滑速度 (Smooth Factor) | `5000` | `duration` | 计算过渡时间：`duration = clamp(5000.0 / smoothFactor, 0.1, 5.0)` |
  | `[8]` | 缓动曲线类型 (Ease) | `linear` / `easeInOutSine` | `ease` | 映射为 DOTween `Ease` 枚举 (`Tween.EaseType`) |

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

### 4. 死亡/摔落触发器 (DeathTrigger)
- **ARPhros Type**: `3`
- **GodotLine 脚本**: `res://#Template/[Scripts]/Trigger/KillPlayer.gd`
- **映射规则**: 挂载 `KillPlayer.gd`，设置 `reason = 1`（Hit / Fall / Drowned）。

---

### 5. 相机震动触发器 (ShakeCameraTrigger)
- **ARPhros Type**: `4`
- **GodotLine 脚本**: `res://#Template/[Scripts]/CameraScripts/CameraShakeTrigger.gd`
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
  ```
- **参数映射**:
  - `fogDensity`: `0.01`
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

### 8. 动效与位移/旋转/缩放/显隐触发器 (Move / Rotate / Scale / Visibility)
| ARPhros Type | 名称 | 目标说明 |
| :---: | :--- | :--- |
| **5** | `MoveTrigger` | 关联目标物体在指定时间内做相对位移 |
| **6** | `RotateTrigger` | 关联目标物体在指定时间内做相对旋转 |
| **7** | `ScaleTrigger` | 关联目标物体在指定时间内做缩放动画 |
| **8** | `ColorTrigger` | 动态渐变材质颜色 |
| **10** | `SequenceTrigger` | 串联触发序列（延时执行多个触发器） |
| **18** | `VisibilityTrigger` | 动态显示/隐藏目标关卡区域（如隐藏 场景 1，激活 场景 2） |
