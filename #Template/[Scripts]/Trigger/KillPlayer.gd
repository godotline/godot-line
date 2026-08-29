extends Node

## KillPlayer - 接触即死触发器
## 当玩家进入触发区域时立即死亡
## 三种模式：Hit（撞墙）/ Drowned（落水）/ Border（出图）

@export var reason: LevelManager.DieReason = LevelManager.DieReason.Drowned

## 启用后玩家死亡无法通过检查点复活
@export var noRevive: bool = false

func trigger(body: Node3D) -> bool:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return false
	var player: Player = body as Player
	if not player or player.noDeath:
		return false
	var revive: bool = not noRevive and (LevelManager.checkpointCount > 0 or LevelManager.crown > 0)
	player.PlayerDeath(reason, revive, reason == LevelManager.DieReason.Hit, false)
	return true
