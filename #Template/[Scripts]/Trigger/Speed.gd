extends Node
## Speed - 速度改变触发器
## 默认模式: 玩家进入时改变移动速度 (Unity Speed.cs: !setFakePlayer)
## setFakePlayer 模式: 假线/障碍物进入时改变目标 FakePlayer 的速度

@export var setFakePlayer: bool = false
@export var player: FakePlayer
@export var speed: float = 12.0

var container: BaseTrigger

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	container = get_parent() as BaseTrigger
	if container and not container.body_entered.is_connected(_on_container_body_entered):
		container.body_entered.connect(_on_container_body_entered)

## BaseTrigger 默认只分发 CharacterBody3D；FakePlayer 尾线/障碍物使用 StaticBody3D，
## 因此在本组件内补充专用输入。
func _on_container_body_entered(body: Node3D) -> void:
	if body is StaticBody3D or _find_fake_player(body) != null:
		trigger(body)

func trigger(body: Node3D) -> void:
	if not setFakePlayer:
		if body is Player:
			body.Speed = speed
			_sync_velocity(body)
	elif player and (_find_fake_player(body) != null or body.is_in_group("obstacle")):
		player.speed = speed

func _find_fake_player(body: Node3D) -> FakePlayer:
	var directComponent: FakePlayer = body as FakePlayer
	if directComponent:
		return directComponent
	for child: Node in body.get_children():
		var component: FakePlayer = child as FakePlayer
		if component:
			return component
	return null

func _sync_velocity(body: CharacterBody3D) -> void:
	var currentVel: Vector3 = body.velocity
	var horizontal: Vector3 = Vector3(currentVel.x, 0.0, currentVel.z)
	if horizontal.length() > 0.01:
		var direction: Vector3 = horizontal.normalized()
		body.velocity = direction * speed + Vector3(0.0, currentVel.y, 0.0)

func _exit_tree() -> void:
	if container and is_instance_valid(container):
		if container.body_entered.is_connected(_on_container_body_entered):
			container.body_entered.disconnect(_on_container_body_entered)