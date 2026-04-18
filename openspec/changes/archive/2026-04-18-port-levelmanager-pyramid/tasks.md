## 1. 创建LevelManager.gd

- [x] 1.1 创建`#Template/[Scripts]/Level/LevelManager.gd`，定义GameStatus枚举（Waiting/Playing/Moving/Died/Completed）和Direction枚举（First/Second）
- [x] 1.2 实现静态属性：GameState、getInput、Clicked、defaultGravity、PlayerPosition、CameraPosition
- [x] 1.3 移植State.gd的检查点数据持久化：静态变量（main_line_transform、revive_position、camera_checkpoint字典等）
- [x] 1.4 移植State.gd的save_checkpoint和load_checkpoint_to_main_line静态方法
- [x] 1.5 移植State.gd的load_to_camera_follower静态方法
- [x] 1.6 移植State.gd的reset_to_defaults和reset_camera_checkpoint静态方法
- [x] 1.7 实现revivePlayer信号（替代Unity delegate）和ResetRevivePlayer方法
- [x] 1.8 移植PlayerDeath方法（处理Hit/Drowned/Border三种死亡原因）
- [x] 1.9 移植GameOverNormal和GameOverRevive方法
- [x] 1.10 移植辅助方法：DestroyRemain、CompareCheckpointIndex、SetFPSLimit、CreateTrigger、GetColorByContent

## 2. 创建Pyramid.gd

- [x] 2.1 创建`#Template/[Scripts]/Trigger/Pyramid.gd`，继承BaseTrigger，定义TriggerType枚举（Open/Final/Waiting/Stop）
- [x] 2.2 实现Start逻辑：获取Left和Right子节点引用
- [x] 2.3 实现Trigger方法：根据type执行Open/Final/Waiting/Stop逻辑
- [x] 2.4 实现Open触发：使用Godot Tween移动Left/Right子节点，订阅revivePlayer信号
- [x] 2.5 实现Final触发：停止CameraFollower跟随，设置GameState为Moving
- [x] 2.6 实现Waiting触发：使用Timer等待后调用Complete
- [x] 2.7 实现Stop触发：设置GameState为Completed
- [x] 2.8 实现Complete方法：显示游戏结束UI
- [x] 2.9 实现StopPlayer方法：外部调用停止玩家
- [x] 2.10 实现ResetDoor方法：重置门位置，取消订阅revivePlayer
- [x] 2.11 实现_on_destroy清理：取消订阅revivePlayer

## 3. 更新CameraFollower.gd

- [x] 3.1 更新CameraFollower.gd中所有`State.`引用改为`LevelManager.`
- [x] 3.2 更新`State.camera_checkpoint`引用改为`LevelManager.camera_checkpoint`
- [x] 3.3 更新`State.is_end`引用改为`LevelManager.is_end`

## 4. 更新引用State的脚本

- [x] 4.1 更新Player.gd中所有`State.`引用改为`LevelManager.`
- [x] 4.2 更新gameui.gd中所有`State.`引用改为`LevelManager.`
- [x] 4.3 更新Checkpoint.gd中所有`State.`引用改为`LevelManager.`
- [x] 4.4 更新Crown.gd中所有`State.`引用改为`LevelManager.`
- [x] 4.5 更新Diamond.gd中`State.`引用改为`LevelManager.`
- [x] 4.6 更新DebugOverlay.gd中`State.`引用改为`LevelManager.`
- [x] 4.7 更新CameraTrigger.gd中`State.`引用改为`LevelManager.`
- [x] 4.8 更新LevelData.gd中`State.`引用改为`LevelManager.`

## 5. 删除旧文件并更新场景

- [x] 5.1 删除State.gd
- [x] 5.2 删除Ending.gd
- [x] 5.3 更新Ending.tscn场景脚本引用指向Pyramid.gd
- [x] 5.4 验证所有.gd文件中无残留`State.`引用
