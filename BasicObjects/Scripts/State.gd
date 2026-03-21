extends Node

var token
var id
var version = ProjectSettings.get_setting("application/config/version")
var t_version

var date = Time.get_datetime_dict_from_system()

#State.date["year"]
#以字典形式返回当前日期，包含的键为：year、month、day、weekday、hour、minute、second 以及 dst（夏令时，Daylight Savings Time）。
#print(date_dict) # 输出类似：{"year": 2025, "month": 8, "day": 25, "weekday": 6}

func time() -> String:
	var a := ""
	a = str(State.date["year"] + State.date["month"] + State.date["day"])
	return a

var level := 0

var main_line_transform
var is_turn := false
var anim_time := 0.0
var is_end := false
var percent := 0
var random := 0
var determination := " "


var line_crossing_crown := 0
var is_relive := false
var diamond := 0
var crown := 0

var firstcrown := 0
var secondcrown := 0
var thridcrown := 0

var tag := 0

var levelnumber : Array[String]

var skinname = ["nolmal","earphones","happy","invisible","crown"]

var achievement = ["真正的LOSS","我要投诉你","回忆的时光"]

var pack = ["everyday_block_pack"]

var act = ["ball","ball_date"]


func _ready() -> void:
	levelnumber.clear()
	levelnumber.append(i.name)


func crown_num() -> void:
	crown = 0
	if firstcrown == 1:
		crown += 1
	if secondcrown == 1:
		crown += 1
	if thridcrown == 1:
		crown += 1

func save() -> int:
	var head = leveldata.level_group[level]
	var coin_num : int

	if diamond == 10:
		coin_num += 1
	if crown == 3:
		coin_num += 1
	if percent == 100:
		coin_num += 2
	elif percent >= 50:
		coin_num += 1
	if diamond == 10 and crown == 3 and percent == 100:
		coin_num += head.star
		head.perfect = true


	if diamond >= head.diamond:
		head.diamond = diamond
	if crown >= head.crown:
		head.crown = crown
	if percent >= head.percent:
		head.percent = percent

	user_data.coin += coin_num

	return coin_num


func quit(line:CharacterBody3D) -> void:
	guidbox = false
	get_tree().change_scene_to_file("res://Scenes/ui/level.tscn")
	is_end = false
	is_relive = false
	speed = 1.0
	diamond = 0
	crown = 0
	percent = 0
	firstcrown = 0
	secondcrown = 0
	thridcrown = 0
	determination = " "
	line.reload()

func fuhuo(line:CharacterBody3D) -> String:
	if is_end == true:
		line.reload()
		is_end = false
		is_relive = false
		diamond = 0
		crown = 0
		percent = 0
		firstcrown = 0
		secondcrown = 0
		thridcrown = 0
		determination = " "
	else:
		if firstcrown > 1 or secondcrown > 1 or thridcrown > 1 :
			is_relive = true
			percent = 0
			diamond = 0
			determination = " "
			line.tree.reload_current_scene()
	return ""



func replay(line:CharacterBody3D) -> void:
	line.reload()
	is_end = false
	is_relive = false
	diamond = 0
	crown = 0
	percent = 0
	firstcrown = 0
	secondcrown = 0
	thridcrown = 0
	determination = " "


#setting
var autoplay := true
var guidbox := false
var score_visible := false
var skin := 1
var music_delay := 0.0
var speed := 1.0

var cdk : Dictionary = {}


#The Loss遗落1睦蕴shinnLOSS - G.one居万迷失方向，探寻梦境ea895c
#The Cloudmirage云漠2睦蕴shinnLunar Night - 付钰工作室风塑的浪，是凝驻的云9ad7da
#The War战殇3meny233（移植）The War - Cheetah Mobile Games游末殇对白蓝天，度沉寂空照虚束。
#彼乌鸦噬死夜莺，终玫瑰覆盖废墟。3f3f3f
#The Winter寒冬之疑4TG铁锅炖大鹅Winter of Doubt - TTF寒风萧萧，仍不停歇64a8ab
#The Romance心动4mney233（移植）The Romance - Cheetah Mobile Games我与清风共舞，不慕他人成双。
#孤影与我相伴，佳人自在心中。本关卡还在测试阶段
#本关卡你仍可以体验游玩，但关卡会有bug影响体验，请酌情考虑。
#The Amnesia终忆5睦蕴shinnAMNESIA - Litchee一池的星光，却拾不起一件回忆的时光……双线玩法说明
#本关有双线玩法，玩家需要用 N键(电脑端)/右半屏(手机端) 控制关卡内出现的第一根线，用 V键(电脑端)/左半屏(手机端) 控制另一根线。3f3f3f
#The Matrix矩阵5睦蕴shinnsing sing red indigo - Frums矩阵——星群以光年为尺规凿刻的几何体，冰晶在时间棱镜中延展的秩序之诗、规整的初弦。
#Coming Soon即将到来6-Do you really want to leave? - Shinn-故事永无终章-3f3f3f
var story := []
var run_story := false
var index : int


@onready var duihuaPS : PackedScene = load("res://Story/duihua.tscn")
func playduihua(duihua:DuiHuaGroup):
	run_story = true
	for i in get_children():
		if i is Control and i.name == "duihua" or i.name == "duihua2":
			i.queue_free()
	var duihua_node = duihuaPS.instantiate()
	add_child(duihua_node,true)
	duihua_node.playduihua(duihua)
