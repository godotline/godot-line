# trigger_type_map.gd
# ARPhros 触发器类型 → GodotLine（模式 1 纯组件）映射表，单一数据源。
#
# 由 LevelLoader 接管使用：
#   - 已映射类型走 TRIGGER_CONFIG（组件注册） + TRIGGER_FIELD_MAP（参数解析规则）。
#   - 未映射 / 待核对类型登记在 UNMAPPED_TRIGGER_TYPES（占位 dictionary），
#     导入时由 LevelLoader 打印警告，接入真实关卡补充 component 与规则后即可移入上面两张表。
#
# 数据格式与逐类型说明见 addons/dancing_line_importer/Trigger.md

# ==================== 组件脚本预加载 ====================
const JumpClass: Script = preload("res://#Template/[Scripts]/Trigger/Jump.gd")
const KillPlayerClass: Script = preload("res://#Template/[Scripts]/Trigger/KillPlayer.gd")
const CameraTriggerClass: Script = preload("res://#Template/[Scripts]/Camera/CameraTrigger.gd")
const SpeedClass: Script = preload("res://#Template/[Scripts]/Trigger/Speed.gd")
const GravityTriggerClass: Script = preload("res://#Template/[Scripts]/Trigger/GravityTrigger.gd")
const SetFogClass: Script = preload("res://#Template/[Scripts]/Trigger/SetFog.gd")
const CameraShakeClass: Script = preload("res://#Template/[Scripts]/Camera/CameraShakeTrigger.gd")
const ChangeDirectionClass: Script = preload("res://#Template/[Scripts]/Trigger/ChangeDirection.gd")
const FadeOutMusicClass: Script = preload("res://#Template/[Scripts]/Trigger/FadeOutMusic.gd")
const SetActiveClass: Script = preload("res://#Template/[Scripts]/Trigger/SetActive.gd")
const EventTriggerClass: Script = preload("res://#Template/[Scripts]/Trigger/EventTrigger.gd")

# ==================== 变换 Animator 组件预加载（Move/Rotate/Scale 共用） ====================
const LocalPosAnimatorClass: Script = preload("res://#Template/[Scripts]/Animator/LocalPosAnimator.gd")
const LocalRotAnimatorClass: Script = preload("res://#Template/[Scripts]/Animator/LocalRotAnimator.gd")
const LocalScaleAnimatorClass: Script = preload("res://#Template/[Scripts]/Animator/LocalScaleAnimator.gd")

# ==================== ANIMATOR_EASE_MAP（transform 触发器 ease 字符串 → Tween 映射） ====================
# ARPhros/DOTween 的 ease 名（可带 "ease" 前缀，如 "easeOutBounce" → "outbounce"）映射到
# Tween.TransitionType + Tween.EaseType。get_animator_ease() 会先去掉前导 "ease" 再查表，
# 未命中回退到 linear（TRANS_LINEAR + EASE_IN_OUT）。
const ANIMATOR_EASE_MAP: Dictionary = {
	"linear":      {"trans": Tween.TRANS_LINEAR,  "ease": Tween.EASE_IN_OUT},
	"insine":      {"trans": Tween.TRANS_SINE,   "ease": Tween.EASE_IN},
	"outsine":     {"trans": Tween.TRANS_SINE,   "ease": Tween.EASE_OUT},
	"inoutsine":   {"trans": Tween.TRANS_SINE,   "ease": Tween.EASE_IN_OUT},
	"inquad":      {"trans": Tween.TRANS_QUAD,   "ease": Tween.EASE_IN},
	"outquad":     {"trans": Tween.TRANS_QUAD,   "ease": Tween.EASE_OUT},
	"inoutquad":   {"trans": Tween.TRANS_QUAD,   "ease": Tween.EASE_IN_OUT},
	"incubic":     {"trans": Tween.TRANS_CUBIC,  "ease": Tween.EASE_IN},
	"outcubic":    {"trans": Tween.TRANS_CUBIC,  "ease": Tween.EASE_OUT},
	"inoutcubic":  {"trans": Tween.TRANS_CUBIC,  "ease": Tween.EASE_IN_OUT},
	"inquart":     {"trans": Tween.TRANS_QUART,  "ease": Tween.EASE_IN},
	"outquart":    {"trans": Tween.TRANS_QUART,  "ease": Tween.EASE_OUT},
	"inoutquart":  {"trans": Tween.TRANS_QUART,  "ease": Tween.EASE_IN_OUT},
	"inexpo":      {"trans": Tween.TRANS_EXPO,   "ease": Tween.EASE_IN},
	"outexpo":     {"trans": Tween.TRANS_EXPO,   "ease": Tween.EASE_OUT},
	"inoutexpo":   {"trans": Tween.TRANS_EXPO,   "ease": Tween.EASE_IN_OUT},
	"inback":      {"trans": Tween.TRANS_BACK,   "ease": Tween.EASE_IN},
	"outback":     {"trans": Tween.TRANS_BACK,   "ease": Tween.EASE_OUT},
	"inoutback":   {"trans": Tween.TRANS_BACK,   "ease": Tween.EASE_IN_OUT},
	"inbounce":    {"trans": Tween.TRANS_BOUNCE, "ease": Tween.EASE_IN},
	"outbounce":   {"trans": Tween.TRANS_BOUNCE, "ease": Tween.EASE_OUT},
	"inoutbounce": {"trans": Tween.TRANS_BOUNCE, "ease": Tween.EASE_IN_OUT},
	"inelastic":   {"trans": Tween.TRANS_ELASTIC,"ease": Tween.EASE_IN},
	"outelastic":  {"trans": Tween.TRANS_ELASTIC,"ease": Tween.EASE_OUT},
	"inoutelastic":{"trans": Tween.TRANS_ELASTIC,"ease": Tween.EASE_IN_OUT},
	"spring":      {"trans": Tween.TRANS_ELASTIC,"ease": Tween.EASE_OUT},
}

# 解析 ARPhros ease 名 → {"trans": Tween.TransitionType, "ease": Tween.EaseType}
# 兼容 "ease" 前缀（easeOutBounce → outbounce）与裸名（insine / linear）。
static func get_animator_ease(name: String) -> Dictionary:
	var key: String = name.to_lower().strip_edges()
	if key.begins_with("ease"):
		key = key.substr(4)
	if ANIMATOR_EASE_MAP.has(key):
		return ANIMATOR_EASE_MAP[key]
	return {"trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT}

# ==================== TRIGGER_CONFIG ====================
# 键为 ARPhros 导出的 triggerType（整型），值为：
#   name          - 触发器根节点名称前缀
#   component     - 组件脚本类（模式 1 纯组件，挂载到 BaseTrigger 下）
#   componentName - 组件子节点名称
const TRIGGER_CONFIG: Dictionary = {
	0:  {"name": "CameraTrigger",       "component": CameraTriggerClass,   "componentName": "CameraTrigger"},
	1:  {"name": "JumpTrigger",         "component": JumpClass,            "componentName": "Jump"},
	2:  {"name": "SpeedTrigger",        "component": SpeedClass,           "componentName": "Speed"},
	3:  {"name": "DeathTrigger",        "component": KillPlayerClass,      "componentName": "KillPlayer"},
	4:  {"name": "CameraShakeTrigger",  "component": CameraShakeClass,     "componentName": "CameraShakeTrigger"},
	11: {"name": "DirectionTrigger",    "component": ChangeDirectionClass, "componentName": "ChangeDirection"},
	12: {"name": "FinishTrigger",       "component": FadeOutMusicClass,    "componentName": "FadeOutMusic"},
	13: {"name": "FovTrigger",          "component": CameraTriggerClass,   "componentName": "CameraTrigger"},
	18: {"name": "VisibilityTrigger",   "component": SetActiveClass,       "componentName": "SetActive"},
	19: {"name": "EnvironmentTrigger",  "component": SetFogClass,          "componentName": "SetFog"},
	22: {"name": "FogTrigger",          "component": SetFogClass,          "componentName": "SetFog"},
	24: {"name": "GravityTrigger",      "component": GravityTriggerClass,  "componentName": "GravityTrigger"},
	# genius idea: Move/Rotate/Scale 统一走 EventTrigger(只发事件) + 目标节点 Local*Animator(执行动画)，不再各自写移动逻辑。
	# 三者共用 _buildTransformTrigger 构建器（按 animatorClass 区分 LocalPosAnimator/LocalRotAnimator/LocalScaleAnimator），
	# 参数解析规则见 TRIGGER_FIELD_MAP 的 special 构建器；运行时由 LevelLoader._link_trigger_animators 挂载并链接 triggered -> Trigger()。
	5:  {"name": "MoveTrigger",         "component": EventTriggerClass,    "componentName": "EventTrigger"},
	6:  {"name": "RotateTrigger",       "component": EventTriggerClass,    "componentName": "EventTrigger"},
	7:  {"name": "ScaleTrigger",        "component": EventTriggerClass,    "componentName": "EventTrigger"},
}

# ==================== TRIGGER_FIELD_MAP ====================
# 键为 ARPhros 导出的 triggerType，值为参数解析规则数组。
# 每条规则字段：
#   seg        - custom.data 按 "|" 切分后的段索引（如整段按 "," 取向量，则 seg=0 且 sub=","）
#   sub        - 对当前段二次切分的分隔符（如 ","），可省略
#   n          - 子段所需最小数量（默认 3）
#   prop       - 写入的组件属性名
#   kind       - 解析类型：vec3_raw | vec3_rad | float | fov | bool | ease | speed | jump_power | duration_cam | const | special
#   default    - float/fov 类型在缺失或非法时的默认值
#   value      - const 类型写入的常量值
#   special    - special 类型调用的构建函数名（签名 (dataStr: String, comp: Node)，在 LevelLoader 中定义）
#   placeholder- true 表示导出位含义待确认（占位），接入真实关卡前需核对
const TRIGGER_FIELD_MAP: Dictionary = {
	# type 0: CameraTrigger
	# 数据格式: "True|15, 45, 0|True|0, 3, 0|True|25|True|5000|linear|0|True|True|0"
	# [0]enableRotation [1]rotation [2]enableOffset [3]offset [4]enableFov [5]fov
	# [6]enableSmooth [7]smoothFactor [8]ease [9]duration [10]follow(占位) [11]useCurve(占位) [12]canBeTriggered(占位)
	0: [
		{"seg": 1, "sub": ",", "n": 3, "prop": "rotation", "kind": "vec3_rad"},
		{"seg": 3, "sub": ",", "n": 3, "prop": "offset", "kind": "vec3_raw"},
		{"seg": 5, "prop": "fieldOfView", "kind": "fov", "default": 80.0},
		{"seg": 9, "prop": "duration", "kind": "duration_cam"},
		{"seg": 8, "prop": "ease", "kind": "ease"},
		{"seg": 10, "prop": "follow", "kind": "bool", "placeholder": true},
		{"seg": 11, "prop": "useCurve", "kind": "bool", "placeholder": true},
		{"seg": 12, "prop": "canBeTriggered", "kind": "bool", "placeholder": true},
	],
	# type 1: JumpTrigger — 数据格式: "0, 660, 0|False|True|True"
	1: [
		{"seg": 0, "sub": ",", "n": 2, "prop": "power", "kind": "jump_power"},
	],
	# type 2: SpeedTrigger
	2: [
		{"seg": 0, "prop": "speed", "kind": "speed"},
	],
	# type 3: DeathTrigger
	3: [
		{"prop": "reason", "kind": "const", "value": 1}, # Drowned / Hit
	],
	# type 4: CameraShakeTrigger — 无参数
	# type 5/6/7: MoveTrigger / RotateTrigger / ScaleTrigger — 同一模式（genius idea）
	# 不直接变换节点，改由 EventTrigger 发事件；导入后处理器在目标节点(按 targetId)挂载对应
	# Local*Animator 并链接 triggered -> Trigger()。三者共用 _buildTransformTrigger（animatorClass 区分）。
	# 数据格式: "dx, dy, dz|ease|targetId|useOffset|flag||tweenTime|reverse"
	#   [0]endOffset(目标值/增量) [1]ease(见 ANIMATOR_EASE_MAP，可带 ease 前缀) [2]targetId(目标节点 id)
	#   [3]useOffset(true=TransformType.Add / false=New) [4]占位(含义待确认) [5]空(两个|之间)
	#   [6]tween 时长 [7]reverse(调换 start/end)
	5: [
		{"kind": "special", "special": "_buildMoveTrigger"},
	],
	6: [
		{"kind": "special", "special": "_buildRotateTrigger"},
	],
	7: [
		{"kind": "special", "special": "_buildScaleTrigger"},
	],
	# type 11: DirectionTrigger — 数据格式: "0, 45, 0|0, 45, 0"
	11: [
		{"seg": 0, "sub": ",", "n": 3, "prop": "firstDirection", "kind": "vec3_raw"},
		{"seg": 1, "sub": ",", "n": 3, "prop": "secondDirection", "kind": "vec3_raw"},
	],
	# type 12: FinishTrigger — 数据格式: "..|duration"
	12: [
		{"seg": 1, "prop": "duration", "kind": "float", "default": 0.0},
	],
	# type 13: FovTrigger
	13: [
		{"seg": 0, "prop": "fieldOfView", "kind": "fov", "default": 80.0},
		{"seg": 1, "prop": "duration", "kind": "float", "default": 1.0},
	],
	# type 18: VisibilityTrigger — 数据格式: "Mode|TargetObjId|DontRevive|"
	18: [
		{"kind": "special", "special": "_buildVisibilityTrigger"},
	],
	# type 19: EnvironmentTrigger — 数据格式: "True|Color|True|r,g,b,a|True|True|r,g,b,a|2.5|linear"
	19: [
		{"kind": "special", "special": "_buildEnvironmentTrigger"},
	],
	# type 22: FogTrigger — 数据格式: "density|r,g,b,a|True|2.5|linear"
	22: [
		{"kind": "special", "special": "_buildFogTrigger"},
	],
	# type 24: GravityTrigger — 数据格式: "0, -50, 0"
	24: [
		{"seg": 0, "sub": ",", "n": 3, "prop": "gravity", "kind": "vec3_raw"},
	],
}

# ==================== UNMAPPED_TRIGGER_TYPES（占位 dictionary） ====================
# 未映射 / 待核对类型登记处。字段：
#   name          - 触发器名称
#   component     - 对应组件脚本（未实现时为 null）
#   componentName - 组件子节点名称（未实现时为 null）
#   dataFormat    - 原始 custom.data 样本（用于核对参数结构）
#   notes         - 待确认项与当前状态
# 接入真实关卡、确认参数后：创建对应组件脚本，并将其移入 TRIGGER_CONFIG / TRIGGER_FIELD_MAP。
const UNMAPPED_TRIGGER_TYPES: Dictionary = {
	# RotateTrigger(type 6) / ScaleTrigger(type 7) 已按 genius idea 接入 EventTrigger + 目标节点
	# LocalRotAnimator / LocalScaleAnimator（与 MoveTrigger type 5 同一模式）。此处保留空占位 dictionary，
	# 供后续新增的、尚无样本/未确认参数的触发器类型登记。
}

# ==================== 运行时辅助 ====================

static func is_mapped(triggerType: int) -> bool:
	return TRIGGER_CONFIG.has(triggerType)

static func get_config(triggerType: int) -> Variant:
	return TRIGGER_CONFIG.get(triggerType, null)

static func get_field_rules(triggerType: int) -> Array:
	return TRIGGER_FIELD_MAP.get(triggerType, [])

static func is_placeholder(triggerType: int) -> bool:
	return UNMAPPED_TRIGGER_TYPES.has(triggerType)

# 未映射类型收集器：导入期间累计（类型 -> 名称），由 LevelLoader 汇总打印后清空。
static var collected_unmapped: Dictionary = {}

static func record_unmapped(triggerType: int, triggerName: String) -> void:
	collected_unmapped[triggerType] = triggerName

static func take_unmapped_summary() -> Dictionary:
	var summary: Dictionary = collected_unmapped.duplicate()
	collected_unmapped.clear()
	return summary
