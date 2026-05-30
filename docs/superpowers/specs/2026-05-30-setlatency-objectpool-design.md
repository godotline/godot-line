# SetLatency + ObjectPool 移植设计

- **日期**: 2026-05-30
- **项目**: GodotLine (冰焰模板 V4.7.6 移植)
- **Unity 源文件**: `[Scripts]/GUI/SetLatency.cs`, `[Scripts]/Level/ObjectPool.cs`
- **Godot 目标**: 完成 SetLatency 接入 + ObjectPool 集成到 Player.gd

---

## 一、ObjectPool 集成到 Player.gd

### 现状

`ObjectPool.gd` 类已存在且功能完整（FIFO 队列，`add/pop/is_full/destroy_all`），但 `Player.gd` 和 `FakePlayer.gd` 的尾巴对象池是独立的内联 `Array[MeshInstance3D]` 实现，未使用 `ObjectPool`。

### 改动

将 `Player.gd` 的尾巴池从内联数组改为 `ObjectPool` 实例，对齐 Unity `Player.cs` 的 `ObjectPool<Transform> tailPool`。

**变量替换:**
```gdscript
# 改前
const TAIL_POOL_SIZE := 256
var _tail_pool: Array[MeshInstance3D] = []

# 改后
const TAIL_POOL_SIZE := 256
var _tail_pool: ObjectPool = ObjectPool.new(TAIL_POOL_SIZE)
```

**方法替换:**

| 原方法 | 新方法 |
|---|---|
| `_tail_pool.pop_back()` → LIFO | `_tail_pool.pop() as MeshInstance3D` → FIFO (对齐 Unity) |
| `_tail_pool.size() < TAIL_POOL_SIZE → append` | `not _tail_pool.is_full() → add` |
| size 超标 → `queue_free()` | is_full → `queue_free()` |
| `_tail_pool.clear()` 在 destroy | `_tail_pool.destroy_all()` |

### 与 Unity 差异

| 差异 | Unity | Godot | 接受理由 |
|------|-------|-------|----------|
| 泛型 | `ObjectPool<Transform>` | `Array[Node]` | GDScript 无泛型 |
| 默认容量 | `poolSize=100` | `TAIL_POOL_SIZE=256` | 不改已有关卡行为 |
| Size setter | `tailPool.Size = poolSize` | `_init(size)` 仅构造 | 不影响功能 |

---

## 二、SetLatency 补完

### 现状

- `SettingItem.gd` — UI 部件完整，含 `Mode.LATENCY`（粗调 10ms + 细调 1ms）和 `Mode.RANGE`（音量 10% 步进）
- `StartPage.gd` — 配置了延迟/音量 Item，发出 `setting_changed` 信号
- `Player.gd` — 有 `music_delay`/`music_volume` 字段，但未连接信号、未持久化、未用于播控

### 缺口对照

| 功能 | Unity `SetLatency.cs` | Godot 改造前 | Godot 改造后 |
|------|----------------------|-------------|-------------|
| UI 显示延迟(ms) + 音量(%) | `SetText()` 更新两个 Text | `SettingItem` 自动处理 | ✅ 已有 |
| UI 按钮调整 | `Add/SubtractLatency(step)` + `Add/SubtractVolume(step)` | `SettingItem` 箭头按钮 | ✅ 已有 |
| 启动时从存储加载 | `PlayerPrefs.GetFloat(...)` | 无 | ✅ 新增 `SetLatency.load_settings()` |
| 关闭时/变化时保存 | `PlayerPrefs.SetFloat(...)` | 无 | ✅ 新增 `SetLatency.save_settings()` |
| 信号连接 → 更新 Player | `SetLatency.Start()` 直接赋值 | signal 无人消费 | ✅ 连接 `setting_changed` |
| 延迟语义 | `StartGame(musicDelay)` 协程控制 | 无 | ✅ 首转延迟分支 |
| 音量应用 | `AudioManager.PlayTrack(..., musicVolume)` | 无 | ✅ `_play_music()` 设置 volume_db |

### 新增文件: `SetLatency.gd`

`#Template/[Scripts]/Level/SetLatency.gd` — 静态工具类 (RefCounted)

```gdscript
class_name SetLatency
extends RefCounted

## 音画延迟/音量设置持久化工具
## 对齐 Unity SetLatency.cs 的 PlayerPrefs 行为

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

static func save_settings(delay: float, volume: float) -> void:
    var config := ConfigFile.new()
    config.set_value(SECTION, "music_delay", delay)
    config.set_value(SECTION, "music_volume", volume)
    config.save(SETTINGS_PATH)

static func load_settings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return { "delay": 0.0, "volume": 1.0 }
    return {
        "delay": config.get_value(SECTION, "music_delay", 0.0),
        "volume": config.get_value(SECTION, "music_volume", 1.0)
    }
```

### 修改文件: `Player.gd` — 4 处改动

#### 1. `_ready()` — 启动加载 + 信号连接

```gdscript
# 加载持久设置
var saved = SetLatency.load_settings()
music_delay = saved.delay
music_volume = saved.volume

# StartPage 实例化后...
page.set_setting("latency", music_delay)
page.set_setting("volume", music_volume)
page.setting_changed.connect(_on_setting_changed)
```

#### 2. `turn()` — 首转延迟分支

```
turn()
├── Animation 设置 (始终执行)
├── Music 流设置 (始终执行)
├── is_start == true:
│   └── 常规转向 (方向切换 + 移动)
└── is_start == false (首转):
    ├── music_delay > 0:
    │   ├── GameState = Playing
    │   ├── 立即旋转 + 移动 (画面先走)
    │   └── timer → 延迟后 _play_music()
    ├── music_delay < 0:
    │   ├── 立即 _play_music() (声音先走)
    │   ├── GameState = Waiting (保持)
    │   └── timer → 延迟后 GameState = Playing + 移动
    └── music_delay == 0:
        └── 正常流程 (音画同时)
```

#### 3. 新增 `_play_music(start_time)` — 解耦音乐播放

```gdscript
func _play_music(start_time: float) -> void:
    if not level_data or not level_data.levelAudioClip: return
    $MusicPlayer.stream = level_data.levelAudioClip
    var latency := AudioServer.get_output_latency()
    var adjusted_time = max(start_time - latency, 0.0)
    $MusicPlayer.volume_db = linear_to_db(max(music_volume, 0.001))
    $MusicPlayer.play(adjusted_time)
```

**说明**: `AudioServer.get_output_latency()` 与 `music_delay` 保持独立。前者是系统音频硬件延迟自动补偿，后者是用户手动调节的 AV 同步偏移——两个不同概念，同时存在。

#### 4. 新增 `_on_setting_changed(key, value)` — 响应 + 持久化

```gdscript
func _on_setting_changed(key: String, value) -> void:
    match key:
        "latency":
            music_delay = value
        "volume":
            music_volume = value
            if $MusicPlayer.playing:
                $MusicPlayer.volume_db = linear_to_db(max(music_volume, 0.001))
    SetLatency.save_settings(music_delay, music_volume)
```

### 延迟行为对照表

| `music_delay` | Unity 行为 | Godot 行为 |
|:---:|---|---|
| `-0.1` | 音乐先播 100ms → 线开始移动 | 音乐先播 100ms → `await` → `GameState=Playing` + 移动 |
| `0` | 音画同时开始 | 正常流程，不变 |
| `0.1` | 画面先走 100ms → 音乐播放 | 画面先走 100ms → `await` → `_play_music()` |

### 不改动的文件

- `SettingItem.gd` — UI 部件已完整
- `StartPage.gd` — 信号和接口已完整
- `AudioManager.gd` — 不涉及
- `SettingItem.tscn` / `StartPage.tscn` — 无需改场景

---

## 三、TODO.md 更新

| 行 | 当前 | 改后 |
|----|------|------|
| L32 (SetLatency) | `✓ | ⚠️` | `✓ | ✓` |
| L36 (ObjectPool) | `✓ | ✓` | 不变 |

---

## 四、文件清单

| 操作 | 文件 | 说明 |
|------|------|------|
| **新增** | `#Template/[Scripts]/Level/SetLatency.gd` | 持久化工具类 |
| **修改** | `#Template/[Scripts]/Level/Player.gd` | 4 处改动（加载/首转延迟/播放/信号） |
| **修改** | `TODO.md` | SetLatency 标记完成 |
