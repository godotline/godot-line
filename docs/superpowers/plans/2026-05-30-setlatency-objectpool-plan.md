# SetLatency + ObjectPool 移植实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐 SetLatency（音画延迟/音量 持久化+延迟语义接入）并将 ObjectPool 类集成到 Player.gd 尾巴对象池。

**Architecture:** 新建 `SetLatency.gd` 静态持久化工具类（ConfigFile → `user://settings.cfg`），重构 `Player.gd` 的 `turn()` 首转延迟分支（`>0` 画面先走、`<0` 音乐先走、`=0` 同步），ObjectPool 替换内联数组。

**Tech Stack:** Godot 4.6, GDScript

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| **新建** | `#Template/[Scripts]/Level/SetLatency.gd` | 延迟/音量持久化（ConfigFile 读写） |
| **修改** | `#Template/[Scripts]/Level/Player.gd` | ObjectPool 集成 + turn() 延迟分支 + setting_changed 消费 |
| **修改** | `TODO.md` | 标记 SetLatency 为完成 |

---

### Task 1: 新建 SetLatency.gd — 持久化工具类

**Files:**
- Create: `#Template/[Scripts]/Level/SetLatency.gd`

- [ ] **Step 1: 创建 SetLatency.gd**

```gdscript
class_name SetLatency
extends RefCounted

## 音画延迟/音量设置持久化工具
## 对齐 Unity SetLatency.cs 的 PlayerPrefs 行为
## Unity 用 PlayerPrefs.GetFloat/SetFloat("MusicDelay"/"MusicVolume")
## Godot 用 ConfigFile 存到 user://settings.cfg

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

## 保存当前延迟和音量设置
static func save_settings(delay: float, volume: float) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_delay", delay)
	config.set_value(SECTION, "music_volume", volume)
	config.save(SETTINGS_PATH)

## 加载已保存的设置，返回 { "delay": float, "volume": float }
## 首次使用时自动回退为默认值（delay=0.0, volume=1.0）
static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return { "delay": 0.0, "volume": 1.0 }
	return {
		"delay": config.get_value(SECTION, "music_delay", 0.0),
		"volume": config.get_value(SECTION, "music_volume", 1.0)
	}
```

- [ ] **Step 2: 提交**

```bash
git add "#Template/[Scripts]/Level/SetLatency.gd"
git commit -m "feat: add SetLatency.gd — music delay/volume persistence via ConfigFile

Aligns with Unity SetLatency.cs PlayerPrefs behavior.
Uses user://settings.cfg with audio section."
```

---

### Task 2: Player.gd — ObjectPool 集成到尾巴对象池

**Files:**
- Modify: `#Template/[Scripts]/Level/Player.gd:71-73` (变量声明)
- Modify: `#Template/[Scripts]/Level/Player.gd:205-217` (_return_to_pool + _get_from_pool)

- [ ] **Step 1: 替换 _tail_pool 变量声明**

将第 71-73 行的：
```gdscript
## ========== Tail 对象池 ==========
const TAIL_POOL_SIZE := 256
var _tail_pool: Array[MeshInstance3D] = []
```

改为：
```gdscript
## ========== Tail 对象池 ==========
const TAIL_POOL_SIZE := 256
var _tail_pool: ObjectPool = ObjectPool.new(TAIL_POOL_SIZE)
```

- [ ] **Step 2: 替换 _get_from_pool()**

将第 214-217 行的：
```gdscript
func _get_from_pool() -> MeshInstance3D:
	if _tail_pool.is_empty():
		return MeshInstance3D.new()
	return _tail_pool.pop_back()
```

改为：
```gdscript
func _get_from_pool() -> MeshInstance3D:
	var tail := _tail_pool.pop() as MeshInstance3D
	if not tail:
		return MeshInstance3D.new()
	return tail
```

- [ ] **Step 3: 替换 _return_to_pool() 中的 size 检查**

将第 209 行：
```gdscript
	if _tail_pool.size() < TAIL_POOL_SIZE:
```

改为：
```gdscript
	if not _tail_pool.is_full():
```

- [ ] **Step 4: 提交**

```bash
git add "#Template/[Scripts]/Level/Player.gd"
git commit -m "refactor: integrate ObjectPool into Player.gd tail pool

Replace inline Array[MeshInstance3D] with ObjectPool instance.
Switch from LIFO (pop_back) to FIFO (pop_front) to match Unity behavior.
Use is_full() instead of manual size comparison."
```

---

### Task 3: Player.gd — music_delay 延迟语义 + setting_changed 消费

**Files:**
- Modify: `#Template/[Scripts]/Level/Player.gd` — `_ready()`, `turn()`, 新增 `_play_music()`, 新增 `_on_setting_changed()`

- [ ] **Step 1: 修改 _ready() — 加载持久设置并连接信号**

将第 98-105 行的 StartPage 实例化部分：
```gdscript
	# 实例化 StartPage（启动界面）
	var start_page_scene := load("res://#Template/[Resources]/StartPage.tscn") as PackedScene
	if start_page_scene and not Engine.is_editor_hint():
		var page := start_page_scene.instantiate()
		add_child(page)
		page.set_setting("latency", music_delay)
		page.set_setting("volume", music_volume)
		page.start_requested.connect(_on_start_from_startpage)
```

改为：
```gdscript
	# 实例化 StartPage（启动界面）
	var start_page_scene := load("res://#Template/[Resources]/StartPage.tscn") as PackedScene
	if start_page_scene and not Engine.is_editor_hint():
		# 加载持久化的音画延迟/音量设置（对齐 Unity PlayerPrefs）
		var saved := SetLatency.load_settings()
		music_delay = saved.delay
		music_volume = saved.volume

		var page := start_page_scene.instantiate()
		add_child(page)
		page.set_setting("latency", music_delay)
		page.set_setting("volume", music_volume)
		page.start_requested.connect(_on_start_from_startpage)
		page.setting_changed.connect(_on_setting_changed)
```

*说明：`_on_start_from_startpage` 仍然调用 `turn()`，无需改动该信号连接。*

- [ ] **Step 2: 重构 turn() — 首转加入 delay 分支**

将第 252-284 行的整个 `turn()` 函数替换：

**改前** (当前完整 turn()):
```gdscript
func turn():
	if is_on_floor() or fly:
		if animation_node and not animation_node.is_playing():
			if LevelManager.line_crossing_crown == 0 and not $MusicPlayer.stream_paused:
				LevelManager.anim_time = 0
			animation_node.play("level")
			animation_node.seek(LevelManager.anim_time)
			if level_data and level_data.levelAudioClip:
				if $MusicPlayer.stream_paused:
					$MusicPlayer.stream_paused = false
				elif not $MusicPlayer.playing:
					$MusicPlayer.stream = level_data.levelAudioClip
					var music_start_time: float = level_data.get_audio_start_time()
					_start_music_with_latency(music_start_time)
		if is_start :
			emit_signal("onturn")
			emit_signal("on_change_direction")
			_currentDirection = 1 - _currentDirection
			rotation_degrees = current_direction
		else:
			is_start = true

			# 隐藏 StartPage
			var page := get_node_or_null("StartPage")
			if page and page is CanvasLayer:
				page.hide_animated()

			emit_signal("on_player_start")
			LevelManager.GameState = LevelManager.GameStatus.Playing
			rotation_degrees = current_direction
		velocity = to_global(Vector3(0,0,1) * speed) - position
		past_translation = position
		new_line()
```

**改后**:
```gdscript
func turn():
	if not (is_on_floor() or fly):
		return

	# 动画设置 — 所有路径都立即执行
	if animation_node and not animation_node.is_playing():
		if LevelManager.line_crossing_crown == 0 and not $MusicPlayer.stream_paused:
			LevelManager.anim_time = 0
		animation_node.play("level")
		animation_node.seek(LevelManager.anim_time)

	if is_start:
		# 常规转向
		emit_signal("onturn")
		emit_signal("on_change_direction")
		_currentDirection = 1 - _currentDirection
		rotation_degrees = current_direction
		velocity = to_global(Vector3(0, 0, 1) * speed) - position
		past_translation = position
		new_line()
	else:
		# —— 首次转向（游戏启动）——
		is_start = true
		var page := get_node_or_null("StartPage")
		if page and page is CanvasLayer:
			page.hide_animated()
		emit_signal("on_player_start")
		rotation_degrees = current_direction

		if music_delay > 0:
			# 正值：线立即移动，音乐延后播放（对齐 Unity delay > 0 分支）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			velocity = to_global(Vector3(0, 0, 1) * speed) - position
			past_translation = position
			new_line()
			get_tree().create_timer(music_delay).timeout.connect(_play_music_from_level_data)

		elif music_delay < 0:
			# 负值：音乐立即播放，线原地不动等待后移动（对齐 Unity delay < 0 分支）
			_play_music_from_level_data()
			get_tree().create_timer(-music_delay).timeout.connect(_start_game_after_delay)

		else:
			# 零值：音画同步启动（原行为）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			velocity = to_global(Vector3(0, 0, 1) * speed) - position
			past_translation = position
			new_line()
			_play_music_from_level_data()
```

*对比 Unity `Player.cs:StartGame(float delay)`：*
| `music_delay` | Unity | Godot |
|:---:|---|---|
| `> 0` | 立即 Playing + 移动 → `yield WaitForSeconds(delay)` → 播音乐 | 立即 Playing + 移动 → `create_timer(delay)` → 播音乐 |
| `< 0` | 立即播音乐 → `yield WaitForSeconds(\|delay\|)` → Playing + 移动 | 立即播音乐 → `create_timer(\|delay\|)` → Playing + 移动 |
| `= 0` | 立即播音乐 + Playing + 移动 | 立即播音乐 + Playing + 移动 |

- [ ] **Step 3: 新增 _play_music_from_level_data() — 从 LevelData 启动音乐**

在 `_start_music_with_latency` 之后 (约第 292 行后) 插入：

```gdscript
## 从 level_data 启动音乐播放（处理 stream_paused / not playing 两种情况）
func _play_music_from_level_data() -> void:
	if not level_data or not level_data.levelAudioClip:
		return
	if $MusicPlayer.stream_paused:
		$MusicPlayer.stream_paused = false
	elif not $MusicPlayer.playing:
		$MusicPlayer.stream = level_data.levelAudioClip
		var start_time: float = level_data.get_audio_start_time()
		_play_music(start_time)
```

- [ ] **Step 4: 重构 _start_music_with_latency 为 _play_music（加入音量控制）**

将第 286-292 行的：
```gdscript
func _start_music_with_latency(music_start_time: float) -> void:
	var latency := AudioServer.get_output_latency()
	if latency > 0.0:
		var adjusted_time = max(music_start_time - latency, 0.0)
		$MusicPlayer.play(adjusted_time)
	else:
		$MusicPlayer.play(music_start_time)
```

替换为：
```gdscript
## 播放音乐，补偿系统音频延迟（AudioServer）并应用用户音量设置
## latency: AudioServer.get_output_latency() — 系统硬件延迟自动补偿
## music_volume: 用户手动调节的音量
func _play_music(start_time: float) -> void:
	$MusicPlayer.volume_db = linear_to_db(max(music_volume, 0.001))
	var latency := AudioServer.get_output_latency()
	if latency > 0.0:
		var adjusted_time := max(start_time - latency, 0.0)
		$MusicPlayer.play(adjusted_time)
	else:
		$MusicPlayer.play(start_time)
```

- [ ] **Step 5: 新增 _start_game_after_delay() — music_delay < 0 时的延迟启动**

在 `_play_music` 之后插入：

```gdscript
## music_delay < 0 时：timer 回调，启动游戏移动（对齐 Unity delay < 0 分支的 yield 之后逻辑）
func _start_game_after_delay() -> void:
	LevelManager.GameState = LevelManager.GameStatus.Playing
	velocity = to_global(Vector3(0, 0, 1) * speed) - position
	past_translation = position
	new_line()
```

- [ ] **Step 6: 新增 _on_setting_changed() — 消费 StartPage 信号**

在文件末尾（`_random_rotation` 之后）插入：

```gdscript
## StartPage 设置变化回调：更新 Player 字段 + 立即持久化 + 实时应用音量
## 对齐 Unity SetLatency.cs 的 AddLatency/SubtractLatency/AddVolume/SubtractVolume + SetText + PlayerPrefs.SetFloat
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

- [ ] **Step 7: 提交**

```bash
git add "#Template/[Scripts]/Level/Player.gd"
git commit -m "feat: wire music_delay/volume with persistence and Unity-aligned delay semantics

- Load settings from SetLatency (ConfigFile) on _ready
- Refactor turn() first-start into 3 branches: delay>0, delay<0, delay=0
- Rename _start_music_with_latency → _play_music (add volume application)
- Add _play_music_from_level_data for level music startup
- Add _start_game_after_delay for negative delay callback
- Connect StartPage.setting_changed → _on_setting_changed → save"
```

---

### Task 4: 更新 TODO.md

**Files:**
- Modify: `TODO.md:32`

- [ ] **Step 1: 标记 SetLatency 为完成**

将第 32 行：
```
| P2 | GUI | SetLatency | ✓ | ⚠️ | UI 完成，信号接口暴露，待接入音乐延迟/音量 |
```

改为：
```
| P2 | GUI | SetLatency | ✓ | ✓ | UI 完成，延迟语义对齐 Unity StartGame，ConfigFile 持久化 |
```

- [ ] **Step 2: 提交**

```bash
git add TODO.md
git commit -m "docs: mark SetLatency as complete

UI + delay semantics + ConfigFile persistence all aligned with Unity SetLatency.cs"
```

---

### Task 5: 手动验证

- [ ] **Step 1: 在 Godot 编辑器中打开项目**

打开 `project.godot`（Godot 4.6），运行 Sample 场景：`#Template/[Scenes]/Sample/Sample.tscn`

- [ ] **Step 2: 验证 StartPage UI**

确认底部栏显示 "音画延迟" 和 "音量大小" 两个设置项：
- 延迟：显示 `0ms`，`<<` / `<` / `>` / `>>` 按钮可调
- 音量：显示 `100%`，`<` / `>` 按钮可调
- 点击开始后 UI 正常隐藏

- [ ] **Step 3: 验证持久化**

1. 调整延迟为 `50ms`，音量为 `80%`
2. 按 R 重新加载场景
3. 确认延迟/音量恢复为 `50ms` / `80%`

- [ ] **Step 4: 验证延迟行为**

1. 设置 `music_delay = 500`（500ms）→ 确认点开始后线立即移动，~0.5s 后音乐响起
2. 设置 `music_delay = -500`（-500ms）→ 确认点开始后音乐立即响起，~0.5s 后线开始移动

*注意：负延迟需要修改 `user://settings.cfg` 或代码临时设置（UI 的范围是 0~5s，不支持负值输入）。测试可通过 Godot 编辑器的远程场景树直接修改 `Player.music_delay`。*

- [ ] **Step 5: 验证 ObjectPool 集成**

1. 正常游玩，确认尾巴线正常生成
2. 长按游玩一段时间，确认 256 容量的尾巴池回收正常
3. 按 R 重新加载场景，确认无控制台错误

---

## 完成统计

| 文件 | 操作 | 变更量 |
|------|------|--------|
| `#Template/[Scripts]/Level/SetLatency.gd` | 新建 | ~25 行 |
| `#Template/[Scripts]/Level/Player.gd` | 修改 | ~50 行变更 (tail pool + turn + 3 new methods) |
| `TODO.md` | 修改 | 1 行 |
