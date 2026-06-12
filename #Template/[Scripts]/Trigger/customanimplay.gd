@tool
extends BaseTrigger
## @deprecated: 推荐使用 PlayAnimatorBehavior 作为 BaseTrigger 的子节点
## CustomAnimPlayTrigger - 自定义动画播放触发器（向后兼容包装）

@export var animations: Array[AnimationPlayer] = []
@export var animation_names: Array[StringName] = []

signal hit_the_line

# ==================== 编辑器按钮 ====================
@export var 预览动画: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_play_animations()
			# 自动复位，表现得像按钮
			await get_tree().create_timer(0.1).timeout
			预览动画 = false

@export var 停止预览: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_stop_animations()
			await get_tree().create_timer(0.1).timeout
			停止预览 = false

# ==================== 核心逻辑 ====================
func _on_triggered(_body: Node3D) -> void:
	hit_the_line.emit()
	_play_animations()

func _play_animations() -> void:
	for i in range(animations.size()):
		var player = animations[i]
		if not is_instance_valid(player):
			continue
		
		var anim_name: StringName = _get_animation_name(player, i)
		if not anim_name.is_empty():
			if Engine.is_editor_hint():
				print("编辑器播放: ", player.name, " -> ", anim_name)
			player.play(anim_name)

func _stop_animations() -> void:
	for player in animations:
		if is_instance_valid(player):
			player.stop()

func _get_animation_name(player: AnimationPlayer, index: int) -> StringName:
	# 优先使用指定名称
	if index < animation_names.size() and not animation_names[index].is_empty():
		return animation_names[index]
	
	# 否则使用当前或第一个动画
	var current = player.current_animation
	if not current.is_empty():
		return current
	
	var list = player.get_animation_list()
	if list.size() > 0:
		return list[0]
	
	return &""

func _ready() -> void:
	super._ready()
	_stop_animations()
