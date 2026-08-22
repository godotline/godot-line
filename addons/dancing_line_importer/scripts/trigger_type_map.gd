@tool
extends RefCounted
class_name TriggerTypeMap

## ARPhros 触发器类型映射表 —— 触发器组件脚本、构造描述、参数解析规格与动画缓动映射的集中维护处。
## 仅含常量与静态函数；LevelLoader 按路径 preload 本脚本后查表分发（见 _createTriggerObject）。

# ==================== 组件脚本 preload（唯一出处，LevelLoader 一律引用此处） ====================

const CAMERA_TRIGGER_SCRIPT: Script = preload("res://#Template/[Scripts]/Camera/CameraTrigger.gd")
const CAMERA_SHAKE_SCRIPT: Script = preload("res://#Template/[Scripts]/Camera/CameraShakeTrigger.gd")
const JUMP_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/Jump.gd")
const SPEED_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/Speed.gd")
const GRAVITY_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/GravityTrigger.gd")
const CHANGE_DIRECTION_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/ChangeDirection.gd")
const FADE_OUT_MUSIC_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/FadeOutMusic.gd")
const SET_ACTIVE_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/SetActive.gd")
const SET_FOG_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/SetFog.gd")
const EVENT_TRIGGER_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/EventTrigger.gd")
const SET_COLOR_SCRIPT: Script = preload("res://#Template/[Scripts]/Trigger/SetColor3D.gd")
const LOCAL_POS_ANIMATOR_SCRIPT: Script = preload("res://#Template/[Scripts]/Animator/LocalPosAnimator.gd")
const LOCAL_ROT_ANIMATOR_SCRIPT: Script = preload("res://#Template/[Scripts]/Animator/LocalRotAnimator.gd")
const LOCAL_SCALE_ANIMATOR_SCRIPT: Script = preload("res://#Template/[Scripts]/Animator/LocalScaleAnimator.gd")

# ==================== triggerType → 构造描述 ====================
## 键说明：
##   "label"        String – 触发器根命名前缀（"<Label>_<objId>"）
##   "childName"    String – 组件子节点名
##   "component"    Script – 通用型组件脚本（special 构建器型不带）
##   "fixedProps"   Dictionary – 实例化后立即写入的固定属性（与数据段无关）
##   "animatorKind" String – 仅 5/6/7："pos" / "rot" / "scale"
const TRIGGER_CONFIG: Dictionary = {
	0: {"label": "CameraTrigger", "childName": "CameraTrigger", "component": CAMERA_TRIGGER_SCRIPT},
	1: {"label": "JumpTrigger", "childName": "Jump", "component": JUMP_SCRIPT},
	2: {"label": "SpeedTrigger", "childName": "Speed", "component": SPEED_SCRIPT},
	4: {"label": "CameraShakeTrigger", "childName": "CameraShakeTrigger", "component": CAMERA_SHAKE_SCRIPT},
	5: {"label": "MoveTrigger", "childName": "EventTrigger", "animatorKind": "pos"},
	6: {"label": "RotateTrigger", "childName": "EventTrigger", "animatorKind": "rot"},
	7: {"label": "ScaleTrigger", "childName": "EventTrigger", "animatorKind": "scale"},
	8: {"label": "ColorTrigger", "childName": "EventTrigger"},
	11: {"label": "DirectionTrigger", "childName": "ChangeDirection", "component": CHANGE_DIRECTION_SCRIPT},
	12: {"label": "FinishTrigger", "childName": "FadeOutMusic", "component": FADE_OUT_MUSIC_SCRIPT},
	13: {"label": "FovTrigger", "childName": "CameraTrigger", "component": CAMERA_TRIGGER_SCRIPT},
	18: {"label": "VisibilityTrigger", "childName": "SetActive", "component": SET_ACTIVE_SCRIPT},
	19: {"label": "EnvironmentTrigger", "childName": "SetFog", "component": SET_FOG_SCRIPT},
	22: {"label": "FogTrigger", "childName": "SetFog", "component": SET_FOG_SCRIPT},
	24: {"label": "GravityTrigger", "childName": "GravityTrigger", "component": GRAVITY_SCRIPT},
}

# ==================== triggerType → 参数解析规格 ====================
## 每型要么 {"builder": "_buildXxx"}（special 构建器，位于 LevelLoader，经 call() 调用），
## 要么 {"fields": Array}（通用 field-kind 规格，由 LevelLoader._applyGenericFields 应用）。
## field-kind 词表：
##   floatAt    – parts[i] 严格 is_valid_float；越界直接跳过（不套 default）；无效时取 default（若有）；可选 minValue 排他下界
##   wholeFloat – 整串严格浮点，default / minValue 语义同上
##   vecAt      – parts[i] 逗号切分 ≥3 分量，宽式 float() 写入 Vector3
##   vecWhole   – 整串逗号切分 ≥3 分量，宽式 float() 写入 Vector3
const TRIGGER_FIELD_MAP: Dictionary = {
	0: {"builder": "_buildCameraTrigger"},
	1: {"builder": "_buildJumpTrigger"},
	2: {"fields": [
		{"kind": "wholeFloat", "prop": "speed", "default": 12.0, "minValue": 0.0},
	]},
	5: {"builder": "_buildAnimatorTrigger"},
	6: {"builder": "_buildAnimatorTrigger"},
	7: {"builder": "_buildAnimatorTrigger"},
	8: {"builder": "_buildColorTrigger"},
	11: {"fields": [
		{"kind": "vecAt", "part": 0, "prop": "firstDirection"},
		{"kind": "vecAt", "part": 1, "prop": "secondDirection"},
	]},
	12: {"fields": [
		{"kind": "floatAt", "part": 1, "prop": "duration"}, # 无 default：仅有效时写入（与旧逻辑一致）
	]},
	13: {"fields": [
		{"kind": "floatAt", "part": 0, "prop": "fieldOfView", "default": 80.0},
		{"kind": "floatAt", "part": 1, "prop": "duration", "default": 1.0},
	]},
	18: {"builder": "_buildVisibilityTrigger"},
	19: {"builder": "_buildEnvironmentTrigger"},
	22: {"builder": "_buildFogTrigger"},
	24: {"fields": [
		{"kind": "vecWhole", "prop": "gravity"},
	]},
}

# ==================== 动画器脚本（Transform 触发器 type 5/6/7 用） ====================
## AnimatorBase tween 的是父节点，因此链接阶段把动画器实例挂到目标节点之下。
const ANIMATOR_SCRIPTS: Dictionary = {
	"pos": LOCAL_POS_ANIMATOR_SCRIPT,
	"rot": LOCAL_ROT_ANIMATOR_SCRIPT,
	"scale": LOCAL_SCALE_ANIMATOR_SCRIPT,
}
const ANIMATOR_NODE_NAMES: Dictionary = {
	"pos": "LocalPosAnimator",
	"rot": "LocalRotAnimator",
	"scale": "LocalScaleAnimator",
}

# ==================== 动画 ease 映射 ====================
## 基曲线名 → Tween.TransitionType；修饰符 in/out/inout/outin → Tween.EaseType。
## 与相机通道的 _parseEaseType（CameraFollower.Ease）相互独立。
const ANIMATOR_EASE_MAP: Dictionary = {
	"linear": Tween.TRANS_LINEAR,
	"sine": Tween.TRANS_SINE,
	"quad": Tween.TRANS_QUAD,
	"cubic": Tween.TRANS_CUBIC,
	"quart": Tween.TRANS_QUART,
	"quint": Tween.TRANS_QUINT,
	"expo": Tween.TRANS_EXPO,
	"circ": Tween.TRANS_CIRC,
	"back": Tween.TRANS_BACK,
	"elastic": Tween.TRANS_ELASTIC,
	"bounce": Tween.TRANS_BOUNCE,
	"spring": Tween.TRANS_SPRING,
}


## 解析 ARPhros/DOTween 风格的 ease 名称为 Tween 枚举。
## 返回 {"trans": Tween.TransitionType, "ease": Tween.EaseType}。
## "ease" 前缀可选；修饰符按最长前缀优先匹配（inout/outin 先于 in/out）；
## 裸名（如 "linear"/"easeSpring"）→ EASE_IN_OUT；空串静默回 linear；
## 未知基名回 TRANS_LINEAR 并 push_warning。
static func getAnimatorEase(easeName: String) -> Dictionary:
	var lower: String = easeName.to_lower().strip_edges()
	if lower.begins_with("ease"):
		lower = lower.trim_prefix("ease")
	if lower.is_empty():
		return {"trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT}
	var easeMode: Tween.EaseType = Tween.EASE_IN_OUT
	if lower.begins_with("inout"):
		easeMode = Tween.EASE_IN_OUT
		lower = lower.trim_prefix("inout")
	elif lower.begins_with("outin"):
		easeMode = Tween.EASE_OUT_IN
		lower = lower.trim_prefix("outin")
	elif lower.begins_with("out"):
		easeMode = Tween.EASE_OUT
		lower = lower.trim_prefix("out")
	elif lower.begins_with("in"):
		easeMode = Tween.EASE_IN
		lower = lower.trim_prefix("in")
	if ANIMATOR_EASE_MAP.has(lower):
		return {"trans": ANIMATOR_EASE_MAP[lower], "ease": easeMode}
	push_warning("TriggerTypeMap: 未知动画 ease '%s'，回退 linear。" % easeName)
	return {"trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT}


# ==================== 已知但未实现的 triggerType 备注表 ====================
## 枚举语义来自游戏源码（Arphros.TriggerType）。分发器命中时仅 push_warning
## 并保留裸碰撞触发器。新实现某类型时请将其移入上方 TRIGGER_CONFIG / TRIGGER_FIELD_MAP。
const UNMAPPED_TRIGGER_TYPES: Dictionary = {
	3: "FreezePlayer（冻结玩家 duration 秒，可选冻结重力）",
	9: "Teleport（followImmediate）",
	10: "Sequence（preInstance + delay）",
	14: "Stop",
	15: "Tail（clearTailData: TailMode）",
	16: "AnalogGlitch",
	17: "Material（material/mainColor/emissionColor）",
	20: "Code（脚本触发器）",
	21: "LegacyCamera",
	23: "Light",
	25: "Tap（triggerDuration/haltControl/onlyOnce/allowWhileFlying）",
}
