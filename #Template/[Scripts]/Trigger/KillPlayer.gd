@tool
extends Node
## KillPlayer - 接触即死触发器
## 当玩家进入触发区域时立即死亡
## 三种模式：Hit（撞墙）/ Drowned（落水）/ Border（出图）

enum DieReason {
	Hit,       # 撞墙 — 播放碎片特效 + Hit 音效
	Drowned,   # 落水 — 播放水花声
	Border,    # 出图 — 无音效
}

const DROWNED_CLIP: AudioStream = preload("res://#Template/[Resources]/WaterDie.wav")

@export var reason: DieReason = DieReason.Drowned

## 启用后玩家死亡无法通过检查点复活
@export var no_revive: bool = false

## 自定义死亡音效（留空则使用 reason 默认音效）
@export var custom_death_clip: AudioStream

func trigger(body: Node3D) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	var player: Player = body as Player
	if player and player.is_live and not player.noDeath:
		if no_revive:
			LevelManager.checkpoint_count = 0
			LevelManager.crown = 0
			LevelManager.current_checkpoint = null
		match reason:
			DieReason.Hit:
				# 对齐 Unity：Hit 音效由 die() 内的 $AudioStreamPlayer（Hit.wav）统一播放，避免重复
				player.die(true, LevelManager.GameStatus.Died)
			DieReason.Drowned, DieReason.Border:
				_play_death_sound()
				player.die(false, LevelManager.GameStatus.Moving)

## Drowned/Border 死亡音效；Hit 由 die() 内的 $AudioStreamPlayer（Hit.wav）统一播放
func _play_death_sound() -> void:
	if custom_death_clip:
		AudioManager.play_clip(custom_death_clip)
		return

	if reason == DieReason.Drowned:
		AudioManager.play_clip(DROWNED_CLIP)
