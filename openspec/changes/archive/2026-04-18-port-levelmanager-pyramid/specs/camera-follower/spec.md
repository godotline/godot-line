## ADDED Requirements

### Requirement: 单例访问模式
CameraFollower SHALL通过static var instance提供全局单例访问，实例在_ready()时自动注册。

#### Scenario: 单例注册
- **WHEN** CameraFollower节点_ready执行
- **THEN** CameraFollower.instance指向当前实例

#### Scenario: 单例访问
- **WHEN** 任何脚本访问CameraFollower.instance
- **THEN** 返回当前场景中的CameraFollower实例

### Requirement: 相机跟随控制
CameraFollower SHALL提供following属性控制是否跟随玩家，支持外部脚本设置为false停止跟随。

#### Scenario: 停止跟随
- **WHEN** Pyramid.Final触发时设置CameraFollower.instance.following = false
- **THEN** 相机停止跟随玩家位置更新

#### Scenario: 关卡结束停止跟随
- **WHEN** State.is_end为true且following为true
- **THEN** following自动设为false
