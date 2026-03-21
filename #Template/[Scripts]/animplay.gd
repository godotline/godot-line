extends AnimationPlayer
@export var play_amim: Array[String]

@export var trigger: Area3D

func _ready() -> void :
	if trigger.has_signal("hit_the_line"):
		trigger.connect("hit_the_line", Callable(self, "play_"))

func play_():
	if play_amim.size() > 0:
		for i in play_amim:
			play(i)
