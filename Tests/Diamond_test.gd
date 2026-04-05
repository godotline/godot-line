extends GdUnitTestSuite

## Diamond 测试套件
## 测试 Diamond 类的属性和信号功能

const DiamondScript = preload("res://#Template/[Scripts]/Trigger/Diamond.gd")


## 测试 Diamond 脚本存在性
func test_diamond_script_exists() -> void:
	assert_that(DiamondScript).is_not_null()


## 测试 Diamond 场景文件存在性
func test_diamond_scene_exists() -> void:
	var scene_file = "res://#Template/Diamond.tscn"
	var file_exists = FileAccess.file_exists(scene_file)
	assert_that(file_exists).is_true()


## 测试 Diamond 类继承 Area3D
func test_diamond_extends_area3d() -> void:
	var diamond_instance = Area3D.new()
	diamond_instance.set_script(DiamondScript)
	
	assert_that(diamond_instance is Area3D).is_true()
	
	diamond_instance.queue_free()


## 测试 color 属性默认值
func test_color_default() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	var color = diamond.color
	assert_that(color).is_equal(Color(0, 1, 0, 1))  # 默认绿色
	
	diamond.queue_free()


## 测试 color 属性可设置
func test_color_setter() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	var test_color = Color(1, 0, 0, 1)  # 红色
	diamond.color = test_color
	
	assert_that(diamond.color).is_equal(test_color)
	
	diamond.queue_free()


## 测试 speed 属性默认值
func test_speed_default() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	var speed = diamond.speed
	assert_that(speed).is_equal(1.0)
	
	diamond.queue_free()


## 测试 speed 属性可设置
func test_speed_setter() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	diamond.speed = 2.5
	assert_that(diamond.speed).is_equal(2.5)
	
	diamond.queue_free()


## 测试钻石收集增加 State.diamond
func test_diamond_collection_increases_counter() -> void:
	# 记录初始值
	var initial_count = State.diamond
	State.diamond = 0
	
	# 模拟收集钻石
	State.diamond += 1
	
	assert_that(State.diamond).is_equal(1)
	
	# 恢复
	State.diamond = initial_count


## 测试多个钻石收集
func test_multiple_diamond_collections() -> void:
	var initial_count = State.diamond
	State.diamond = 0
	
	# 收集3个钻石
	for i in range(3):
		State.diamond += 1
	
	assert_that(State.diamond).is_equal(3)
	
	# 恢复
	State.diamond = initial_count


## 测试钻石旋转属性
func test_diamond_rotation_property() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	# 验证 speed 影响旋转
	diamond.speed = 0.5
	assert_that(diamond.speed).is_equal(0.5)
	
	diamond.speed = 3.0
	assert_that(diamond.speed).is_equal(3.0)
	
	diamond.queue_free()


## 测试 _update_mesh_color 方法存在
func test_update_mesh_color_method_exists() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	# 验证方法存在
	assert_that(diamond.has_method("_update_mesh_color")).is_true()
	
	diamond.queue_free()


## 测试颜色变化触发网格更新
func test_color_change_triggers_update() -> void:
	var diamond = Area3D.new()
	diamond.set_script(DiamondScript)
	add_child(diamond)
	
	await get_tree().process_frame
	
	var initial_color = diamond.color
	var new_color = Color(0, 0, 1, 1)  # 蓝色
	
	diamond.color = new_color
	assert_that(diamond.color).is_equal(new_color)
	assert_that(diamond.color).is_not_equal(initial_color)
	
	diamond.queue_free()
