@tool
extends TriggerBehavior
class_name KillBehavior

## KillBehavior - 接触即死行为组件
## 当父 BaseTrigger 被触发时杀死玩家
## 三种模式：Hit（撞墙）/ Drowned（落水）/ Border（出图）

enum DieReason {
	Hit,       ## 撞墙 — 播放碎片特效 + Hit 音效
	Drowned,   ## 落水 — 播放水花声
	Border,    ## 出图 — 无音效
}

const HIT_CLIP := preload("res://#Template/[Resources]/Hit.wav")
const DROWNED_CLIP := preload("res://#Template/[Resources]/WaterDie.wav")

@export var reason: DieReason = DieReason.Drowned

## 启用后玩家死亡无法通过检查点复活
@export var no_revive: bool = false

## 自定义死亡音效（留空则使用 reason 默认音效）
@export var custom_death_clip: AudioStream

func _on_triggered(body: Node3D) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	var player := body as Player
	if player and player.is_live:
		if no_revive:
			LevelManager.checkpoint_count = 0
			LevelManager.crown = 0
		_play_death_sound()
		match reason:
			DieReason.Hit:
				player.die(true, LevelManager.GameStatus.Died)
			DieReason.Drowned, DieReason.Border:
				player.die(false, LevelManager.GameStatus.Moving)

func _play_death_sound() -> void:
	if custom_death_clip:
		AudioManager.play_clip(custom_death_clip)
		return

	match reason:
		DieReason.Drowned:
			AudioManager.play_clip(DROWNED_CLIP)
		DieReason.Hit:
			AudioManager.play_clip(HIT_CLIP)
		DieReason.Border:
			pass
