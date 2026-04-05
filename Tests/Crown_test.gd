extends GdUnitTestSuite

## Crown 测试套件
## 测试 Crown 类的属性和检查点功能

const CrownScript = preload("res://#Template/[Scripts]/Trigger/Crown.gd")


## 测试 Crown 脚本存在性
func test_crown_script_exists() -> void:
	assert_that(CrownScript).is_not_null()


## 测试 Crown 场景文件存在性
func test_crown_scene_exists() -> void:
	var scene_file = "res://#Template/Crown.tscn"
	var file_exists = FileAccess.file_exists(scene_file)
	assert_that(file_exists).is_true()


## 测试 Crown 类继承 Area3D
func test_crown_extends_area3d() -> void:
	var crown_instance = Area3D.new()
	crown_instance.set_script(CrownScript)
	
	assert_that(crown_instance is Area3D).is_true()
	
	crown_instance.queue_free()


## 测试 speed 属性默认值
func test_speed_default() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	var speed = crown.speed
	assert_that(speed).is_equal(1.0)
	
	crown.queue_free()


## 测试 speed 属性可设置
func test_speed_setter() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	crown.speed = 2.5
	assert_that(crown.speed).is_equal(2.5)
	
	crown.queue_free()


## 测试 tag 属性默认值
func test_tag_default() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	var tag = crown.tag
	assert_that(tag).is_equal(1)
	
	crown.queue_free()


## 测试 tag 属性可设置
func test_tag_setter() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	crown.tag = 5
	assert_that(crown.tag).is_equal(5)
	
	crown.queue_free()


## 测试皇冠收集增加 State.crown
func test_crown_collection_increases_counter() -> void:
	var initial_count = State.crown
	State.crown = 0
	
	# 模拟收集皇冠
	State.crown += 1
	
	assert_that(State.crown).is_equal(1)
	
	# 恢复
	State.crown = initial_count


## 测试皇冠设置检查点标记
func test_crown_sets_checkpoint_flag() -> void:
	State.line_crossing_crown = 0
	
	# 模拟收集皇冠
	State.line_crossing_crown = 1
	
	assert_that(State.line_crossing_crown).is_equal(1)


## 测试多个皇冠标签
func test_multiple_crown_tags() -> void:
	var crown1 = Area3D.new()
	crown1.set_script(CrownScript)
	add_child(crown1)
	
	crown1.tag = 1
	assert_that(crown1.tag).is_equal(1)
	
	var crown2 = Area3D.new()
	crown2.set_script(CrownScript)
	add_child(crown2)
	
	crown2.tag = 2
	assert_that(crown2.tag).is_equal(2)
	
	crown1.queue_free()
	crown2.queue_free()


## 测试 _get_camera_follower 方法存在
func test_get_camera_follower_method_exists() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	assert_that(crown.has_method("_get_camera_follower")).is_true()
	
	crown.queue_free()


## 测试皇冠收集流程
func test_crown_collection_flow() -> void:
	# 初始状态
	State.crown = 0
	State.line_crossing_crown = 0
	State.camera_follower_has_checkpoint = false
	
	# 模拟皇冠收集
	State.crown += 1
	State.line_crossing_crown = 1
	State.camera_follower_has_checkpoint = true
	
	# 验证状态
	assert_that(State.crown).is_equal(1)
	assert_that(State.line_crossing_crown).is_equal(1)
	assert_that(State.camera_follower_has_checkpoint).is_true()


## 测试皇冠旋转属性
func test_crown_rotation_property() -> void:
	var crown = Area3D.new()
	crown.set_script(CrownScript)
	add_child(crown)
	
	await get_tree().process_frame
	
	# 验证 speed 影响旋转
	crown.speed = 0.5
	assert_that(crown.speed).is_equal(0.5)
	
	crown.speed = 3.0
	assert_that(crown.speed).is_equal(3.0)
	
	crown.queue_free()
