extends Node

## KillPlayer - 接触即死触发器
## 当玩家进入触发区域时立即死亡
## 三种模式：Hit（撞墙）/ Drowned（落水）/ Border（出图）

enum DieReason {
	Hit,       # 撞墙 — 播放碎片特效 + Hit 音效
	Drowned,   # 落水 — 播放水花声
	Border,    # 出图 — 无音效
}

const HIT_CLIP: AudioStream = preload("res://#Template/[Resources]/Hit.wav")
const DROWNED_CLIP: AudioStream = preload("res://#Template/[Resources]/WaterDie.wav")

@export var reason: DieReason = DieReason.Drowned

## 启用后玩家死亡无法通过检查点复活
@export var noRevive: bool = false

## 自定义死亡音效（留空则使用 reason 默认音效）
@export var customDeathClip: AudioStream

func trigger(body: Node3D) -> bool:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return false
	var player: Player = body as Player
	if player and player.isLive and not player.noDeath:
		if noRevive:
			LevelManager.checkpointCount = 0
			LevelManager.crown = 0
			LevelManager.currentCheckpoint = null
		_play_death_sound()
		match reason:
			DieReason.Hit:
				player.PlayerDeath(true, LevelManager.GameStatus.Died, false)
			DieReason.Drowned, DieReason.Border:
				player.PlayerDeath(false, LevelManager.GameStatus.Moving)
		return true
	return false

func _play_death_sound() -> void:
	if customDeathClip:
		AudioManager.PlayClip(customDeathClip)
		return

	match reason:
		DieReason.Drowned:
			AudioManager.PlayClip(DROWNED_CLIP)
		DieReason.Hit:
			AudioManager.PlayClip(HIT_CLIP)
		DieReason.Border:
			pass
