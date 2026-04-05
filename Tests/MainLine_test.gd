extends GdUnitTestSuite

## MainLine 测试套件
## 测试 MainLine 类的基础属性和功能

const MainLineScript = preload("res://#Template/[Scripts]/MainLine.gd")


## 测试 MainLine 脚本存在性
func test_mainline_script_exists() -> void:
	assert_that(MainLineScript).is_not_null()


## 测试 MainLine 场景文件存在性
func test_mainline_scene_exists() -> void:
	var scene_file = "res://#Template/MainLine.tscn"
	var file_exists = FileAccess.file_exists(scene_file)
	assert_that(file_exists).is_true()


## 测试 MainLine 继承 CharacterBody3D
func test_mainline_extends_characterbody3d() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline_instance = scene.instantiate()
	
	assert_that(mainline_instance is CharacterBody3D).is_true()
	
	mainline_instance.queue_free()


## 测试 speed 属性
func test_speed_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.speed).is_equal(12.0)
	
	mainline.speed = 15.0
	assert_that(mainline.speed).is_equal(15.0)
	
	mainline.queue_free()


## 测试 rot 属性
func test_rot_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.rot).is_equal(-90)
	
	mainline.queue_free()


## 测试 color 属性 getter 和 setter
func test_color_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	# 测试获取颜色
	var initial_color = mainline.color
	assert_that(initial_color).is_equal(Color(0, 0, 0, 1))
	
	# 测试设置颜色
	var test_color = Color(1, 0, 0, 1)
	mainline.color = test_color
	assert_that(mainline.color).is_equal(test_color)
	
	mainline.queue_free()


## 测试 fly 属性
func test_fly_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.fly).is_false()
	
	mainline.fly = true
	assert_that(mainline.fly).is_true()
	
	mainline.queue_free()


## 测试 noclip 属性
func test_noclip_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.noclip).is_false()
	
	mainline.noclip = true
	assert_that(mainline.noclip).is_true()
	
	mainline.queue_free()


## 测试 is_turn 属性
func test_is_turn_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.is_turn).is_false()
	
	mainline.is_turn = true
	assert_that(mainline.is_turn).is_true()
	
	mainline.queue_free()


## 测试 is_live 属性
func test_is_live_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.is_live).is_true()
	
	mainline.queue_free()


## 测试信号存在性 - new_line1
func test_new_line1_signal_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_signal("new_line1")).is_true()
	
	mainline.queue_free()


## 测试信号存在性 - on_sky
func test_on_sky_signal_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_signal("on_sky")).is_true()
	
	mainline.queue_free()


## 测试信号存在性 - onturn
func test_onturn_signal_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_signal("onturn")).is_true()
	
	mainline.queue_free()


## 测试 timeout 属性
func test_timeout_property() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.timeout).is_equal(0.1)
	
	mainline.set_timeout(0.5)
	assert_that(mainline.timeout).is_equal(0.5)
	
	mainline.queue_free()


## 测试 set_timeout 方法
func test_set_timeout_method() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	mainline.set_timeout(1.0)
	assert_that(mainline.timeout).is_equal(1.0)
	
	mainline.set_timeout(0.05)
	assert_that(mainline.timeout).is_equal(0.05)
	
	mainline.queue_free()


## 测试 has_method - turn
func test_turn_method_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_method("turn")).is_true()
	
	mainline.queue_free()


## 测试 has_method - reload
func test_reload_method_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_method("reload")).is_true()
	
	mainline.queue_free()


## 测试 has_method - die
func test_die_method_exists() -> void:
	var scene = load("res://#Template/MainLine.tscn")
	var mainline = scene.instantiate()
	add_child(mainline)
	
	await get_tree().process_frame
	
	assert_that(mainline.has_method("die")).is_true()
	
	mainline.queue_free()
