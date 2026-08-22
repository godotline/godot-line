class_name GameEvents
extends Node

## 玩家游戏事件枢纽（对应 Unity 版 DancingLineFanmade.Level.GameEvents 组件）。
## 作为 Player 的子节点存在，供关卡作者在编辑器"节点 → 信号"面板中
## 将下列信号连接到任意节点的方法（等价 UnityEvent 的 Inspector 接线）；
## 游戏代码也可通过 invoke(index) 按索引触发（与 Unity 的 Invoke(int) 一致）。

signal onGameAwake			## 游戏初始化完成
signal onPlayerStart		## 玩家开始移动（第一次转向）
signal onChangeDirection	## 玩家转向
signal onLeaveGround		## 玩家离开地面
signal onTouchGround		## 玩家落地
signal onGameOver			## 玩家死亡
signal onGetGem				## 收集宝石
signal onPlayerJump			## 玩家跳跃

## 按索引触发事件（索引顺序对齐 Unity GameEvents.Invoke(int index)）
func invoke(index: int) -> void:
	match index:
		0: onGameAwake.emit()
		1: onPlayerStart.emit()
		2: onChangeDirection.emit()
		3: onLeaveGround.emit()
		4: onTouchGround.emit()
		5: onGameOver.emit()
		6: onGetGem.emit()
		7: onPlayerJump.emit()
		_:
			push_warning("GameEvents.gd: Target event is not exist (%d)" % index)
