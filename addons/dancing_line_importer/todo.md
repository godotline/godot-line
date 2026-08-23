# TODO — Dancing Line Importer

导入器待办聚合：组件能力缺口、未实现触发器类型、已实现的已知语义限制。
优先级：高 = 影响通用关卡正确性；中 = 特定字段/类型缺失；低 = 边界情况或降级可接受。

---

## 1. Animatable 组件能力缺口

位置通道 + 一次性触发门控已实现；以下字段/通道缺失（来源：游戏源码 `Animatable` / `AnimatableHost` 字段表）。

| 缺口 | 对应字段 | 说明 | 优先级 |
| :--- | :--- | :--- | :---: |
| 旋转通道 | `animateRotation`, `rotationValue`, `rotationValueType`, `asOffsetRotation`, `startRotationValue`, `endRotationValue` | 整组未实现，当前仅 `push_warning` 跳过 | 中 |
| 缩放通道 | `animateScale`, `scaleValue`, `scaleValueType`, `asOffsetScale`, `startScaleValue`, `endScaleValue` | 整组未实现 | 中 |
| 颜色通道 | `animateColor`, `colorValue`, `colorValueType`, `onlyColorThisObject`, `startColorValue`, `endColorValue` | 整组未实现 | 低 |
| 位置·终点 | `endPositionValue` | 绝对模式未读取终点，仅用 `positionValue` 当终点（应为 start→end 插值） | 中 |
| 位置·反向 | `reverseAnimation` | 未实现反向播放 | 低 |
| 位置·原点 | `basedOnOrigin` | 未读取，当前恒用节点 local position 作基准 | 低 |
| 位置·碰撞体 | `animateCollider` | 未读取，依赖 `target.position` 整体位移兜底 | 低 |
| 位置·随机 | `positionValueType=Random` | 仅告警按 Fixed 处理，未真正随机取值 | 低 |

---

## 2. 未实现触发器类型

`TriggerTypeMap.UNMAPPED_TRIGGER_TYPES` 中登记、导入时仅告警并保留裸碰撞触发器：

| type | 名称 | 缺口 | 优先级 |
| :---: | :--- | :--- | :---: |
| 3 | FreezePlayer | 冻结玩家 `duration` 秒，可选冻结重力（曾误映射为死亡，已修正映射但功能未做） | 高 |
| 15 | Tail | `clearTailData`: TailMode | 低 |
| 16 | AnalogGlitch | 模拟故障效果 | 低 |
| 17 | Material | material / mainColor / emissionColor | 中 |
| 20 | Code | 脚本触发器 | 中 |
| 21 | LegacyCamera | 旧版相机 | 低 |
| 23 | Light | 灯光 | 中 |
| 25 | Tap | `triggerDuration` / `haltControl` / `onlyOnce` / `allowWhileFlying` | 中 |

---

## 3. 已实现的已知语义限制

| 区域 | 限制 | 建议修正 | 优先级 |
| :--- | :--- | :--- | :---: |
| VisibilityTrigger | 目标按裸对象 ID 定位，而生成节点命名为 `<名称>_<id>`，`SingleActive.target` 相对路径可能不命中 | 改为延迟链接（同 type 5/6/7 后处理模式） | 中 |
| StopTrigger | 目标已启动、进行中的补间不会被冻结（自然播完） | 触发时 kill 目标进行中的 tween | 低 |
| ColorTrigger | 不做复活时颜色恢复 | 接入 revive 监听恢复初始色 | 低 |
| SetActive/可见性停用未禁用碰撞 | `SetNodeActive`（`SetActive.gd`）仅置 `visible=false` + `process_mode=DISABLED`，碰撞体仍生效（隐藏物体仍可碰撞）；影响 VisibilityTrigger(type 18)、StopTrigger(type 14)，以及导入期 `visibility=2` 初始隐藏子树（裸 `visible=false`，未走 SetActive） | `SetNodeActive` 停用时应禁用其下 `CollisionShape3D` / `PhysicsBody`，激活时恢复；导入期 `visibility=2` 复用同一逻辑而非裸 `visible=false` | 高 |
| 变换触发器 ease | 名含 `shake` / `punch` / `pingPong` 等运行时特型回退 linear | 补充对应映射或显式降级并报字段名 | 低 |
