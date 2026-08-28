@tool
class_name NewLevelDialog
extends ConfirmationDialog

## 新建关卡对话框 — 收集关卡名/模板/ID，交给 LevelFactory 创建关卡。

const LevelFactoryClass := preload("res://addons/template/level_factory.gd")

var _name_edit: LineEdit
var _template_options: OptionButton
var _id_edit: LineEdit


func _ready() -> void:
	title = "新建关卡"
	min_size = Vector2i(380, 240)
	unresizable = false
	ok_button_text = "创建"
	confirmed.connect(_onConfirmed)
	_buildUi()


func focusNameEdit() -> void:
	_name_edit.call_deferred("grab_focus")


func _buildUi() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# 关卡名称
	var nameRow := HBoxContainer.new()
	vbox.add_child(nameRow)
	var nameLabel := Label.new()
	nameLabel.text = "关卡名称："
	nameLabel.custom_minimum_size = Vector2(100, 0)
	nameRow.add_child(nameLabel)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "MyLevel"
	_name_edit.custom_minimum_size = Vector2(250, 0)
	nameRow.add_child(_name_edit)

	# 模板场景
	var tplRow := HBoxContainer.new()
	vbox.add_child(tplRow)
	var tplLabel := Label.new()
	tplLabel.text = "模板场景："
	tplLabel.custom_minimum_size = Vector2(100, 0)
	tplRow.add_child(tplLabel)
	_template_options = OptionButton.new()
	_template_options.add_item("DefaultScene", 0)
	_template_options.add_item("Sample", 1)
	_template_options.custom_minimum_size = Vector2(250, 0)
	tplRow.add_child(_template_options)

	# 关卡 ID
	var idRow := HBoxContainer.new()
	vbox.add_child(idRow)
	var idLabel := Label.new()
	idLabel.text = "关卡ID："
	idLabel.custom_minimum_size = Vector2(100, 0)
	idRow.add_child(idLabel)
	_id_edit = LineEdit.new()
	_id_edit.placeholder_text = "1"
	_id_edit.custom_minimum_size = Vector2(250, 0)
	_id_edit.text = "1"
	idRow.add_child(_id_edit)

	# 提示
	var hint := Label.new()
	hint.text = "将在 [Scenes]/<关卡名>/ 下创建场景与唯一的 LevelData 资源"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font", 12)
	vbox.add_child(hint)


func _onConfirmed() -> void:
	var levelName := _name_edit.text.strip_edges()
	var templatePath: String = LevelFactoryClass.TEMPLATE_DEFAULT if _template_options.get_selected_id() == 0 else LevelFactoryClass.TEMPLATE_SAMPLE
	var levelIdText := _id_edit.text.strip_edges()
	var levelId := 1
	if levelIdText.is_valid_int():
		levelId = levelIdText.to_int()
	if levelName.is_empty():
		_pushError("关卡名称不能为空")
		return
	var err := LevelFactoryClass.createLevel(levelName, templatePath, levelId)
	if err == OK:
		print("[NewLevel] 关卡创建成功：%s (id=%d, 模板=%s)" % [levelName, levelId, templatePath])
		hide()


func _pushError(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)