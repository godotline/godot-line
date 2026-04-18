## ADDED Requirements

### Requirement: TriggerType触发类型
Pyramid SHALL支持四种触发类型：Open（开门）、Final（结束相机跟随）、Waiting（等待后完成）、Stop（停止游戏）。

#### Scenario: Open触发 - 开门动画
- **WHEN** Trigger被调用且type为Open
- **THEN** Left子节点向Z正方向移动width距离，Right子节点向Z负方向移动width距离，动画时长为duration，缓动为Linear

#### Scenario: Final触发 - 停止相机跟随
- **WHEN** Trigger被调用且type为Final
- **THEN** CameraFollower.instance.following设为false，GameState变为Moving

#### Scenario: Waiting触发 - 等待后完成
- **WHEN** Trigger被调用且type为Waiting
- **THEN** 等待waitingTime秒后调用Complete，显示游戏结束UI

#### Scenario: Stop触发 - 停止游戏
- **WHEN** Trigger被调用且type为Stop
- **THEN** GameState变为Completed

### Requirement: 金字塔门重置
Pyramid SHALL在玩家复活时重置门的位置到初始状态。

#### Scenario: 订阅复活信号
- **WHEN** Open触发时
- **THEN** 订阅LevelManager.revivePlayer信号

#### Scenario: 门重置
- **WHEN** 玩家复活时
- **THEN** Left和Right子节点位置归零，取消订阅revivePlayer

#### Scenario: 销毁时取消订阅
- **WHEN** Pyramid节点被销毁
- **THEN** 取消订阅LevelManager.revivePlayer信号

### Requirement: StopPlayer方法
Pyramid SHALL提供StopPlayer方法，用于外部调用停止玩家并触发关卡完成。

#### Scenario: 调用StopPlayer
- **WHEN** GameState不为Completed时调用StopPlayer
- **THEN** 1秒后调用Complete，GameState变为Completed

### Requirement: 状态检查
Pyramid SHALL在触发时检查GameState，如果玩家已死亡则忽略所有触发。

#### Scenario: 死亡状态忽略触发
- **WHEN** GameState为Died时调用Trigger
- **THEN** 不执行任何操作
