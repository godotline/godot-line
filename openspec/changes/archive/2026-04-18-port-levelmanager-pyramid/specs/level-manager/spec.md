## ADDED Requirements

### Requirement: GameStatus状态机
LevelManager SHALL提供完整的游戏状态机，包含Waiting、Playing、Moving、Died、Completed五个状态。

#### Scenario: 初始状态
- **WHEN** 场景加载完成
- **THEN** GameState为Waiting

#### Scenario: 开始游戏
- **WHEN** 玩家首次点击转向
- **THEN** GameState从Waiting变为Playing

#### Scenario: 玩家死亡
- **WHEN** 玩家撞墙或掉落
- **THEN** GameState变为Died

#### Scenario: 关卡结束
- **WHEN** 触发Final状态
- **THEN** GameState变为Moving

#### Scenario: 完成关卡
- **WHEN** 触发Stop状态
- **THEN** GameState变为Completed

### Requirement: 玩家死亡处理
LevelManager SHALL提供PlayerDeath静态方法，处理不同死亡原因（Hit、Drowned、Border）并触发相应音效和UI。

#### Scenario: 撞墙死亡
- **WHEN** Player调用PlayerDeath且reason为Hit
- **THEN** 播放Hit音效，停止动画和时间轴，显示GameOverUI

#### Scenario: 溺水死亡
- **WHEN** Player调用PlayerDeath且reason为Drowned
- **THEN** 播放Drowned音效，GameState变为Moving

### Requirement: 检查点数据持久化
LevelManager SHALL提供save_checkpoint和load_checkpoint_to_main_line静态方法，保存和恢复玩家位置、方向、速度、动画时间、相机状态。

#### Scenario: 保存检查点
- **WHEN** Crown触发器触发
- **THEN** 保存玩家transform、方向、速度、动画时间、相机offset/rotation/distance

#### Scenario: 加载检查点
- **WHEN** 玩家复活
- **THEN** 恢复玩家transform、方向、速度、动画时间、相机状态

### Requirement: revivePlayer信号
LevelManager SHALL提供revivePlayer信号，支持+=订阅和-=取消订阅，用于复活时重置相关状态（如金字塔门）。

#### Scenario: 订阅复活信号
- **WHEN** 金字塔门打开时
- **THEN** 订阅LevelManager.revivePlayer += ResetDoor

#### Scenario: 触发复活信号
- **WHEN** 玩家复活时
- **THEN** 所有订阅者收到信号并执行重置逻辑

### Requirement: 辅助方法
LevelManager SHALL提供以下辅助方法：DestroyRemain、CompareCheckpointIndex、SetFPSLimit、IsPointedOnUI、CreateTrigger、GetColorByContent。

#### Scenario: 重置游戏状态
- **WHEN** 调用DestroyRemain
- **THEN** GameState恢复为Waiting，清理死亡碎片

#### Scenario: 设置帧率限制
- **WHEN** 调用SetFPSLimit(60)
- **THEN** 目标帧率设为60，关闭垂直同步
