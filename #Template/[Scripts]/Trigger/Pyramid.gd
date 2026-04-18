class_name Pyramid
extends Node3D
## Pyramid - 金字塔管理节点
## 处理开门动画、关卡结束、停止播放等状态转换

enum TriggerType {
	Open,
	Final,
	Waiting,
	Stop
}

@export var waiting_time := 5.0

var left: Node3D
var right: Node3D
var width := 1.8
var duration := 2.0

func _ready() -> void:
	left = get_node_or_null("Left") as Node3D
	right = get_node_or_null("Right") as Node3D

func trigger(type: TriggerType) -> void:
	if LevelManager.game_state != LevelManager.GameStatus.Died:
		match type:
			TriggerType.Open:
				_open_door()
			TriggerType.Final:
				_final()
			TriggerType.Waiting:
				_waiting()
			TriggerType.Stop:
				_stop()

func _open_door() -> void:
	if left:
		var tween_left := create_tween().set_trans(Tween.TRANS_LINEAR)
		tween_left.tween_property(left, "position:x", -width, duration)
	if right:
		var tween_right := create_tween().set_trans(Tween.TRANS_LINEAR)
		tween_right.tween_property(right, "position:x", width, duration)
	LevelManager.add_revive_listener(_reset_door)

func _final() -> void:
	if OldCameraFollower.instance:
		OldCameraFollower.instance.following = false
	LevelManager.game_state = LevelManager.GameStatus.Moving

func _waiting() -> void:
	get_tree().create_timer(waiting_time).timeout.connect(_complete)

func _stop() -> void:
	LevelManager.game_state = LevelManager.GameStatus.Completed
	if Player.instance:
		Player.instance.velocity = Vector3.ZERO

func _complete() -> void:
	print("关卡结束")
	LevelManager.game_over_normal(true)

func stop_player() -> void:
	if LevelManager.game_state != LevelManager.GameStatus.Completed:
		get_tree().create_timer(1.0).timeout.connect(_complete)
		LevelManager.game_state = LevelManager.GameStatus.Completed
		if Player.instance:
			Player.instance.velocity = Vector3.ZERO

func _reset_door() -> void:
	LevelManager.remove_revive_listener(_reset_door)
	if left:
		left.position.z = 0
	if right:
		right.position.z = 0

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_door)
