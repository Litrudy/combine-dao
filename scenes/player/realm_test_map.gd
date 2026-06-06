extends Node2D
## 测试地图控制器
## M2-5A-4 —— 从预设点位随机生成小怪与事件；初始小怪清空后召唤 Boss，Boss 死亡通关。

## 预加载场景
const BOSS_SCENE: PackedScene = preload("res://scenes/enemy/boss_guardian.tscn")
const BEAST_SCENE: PackedScene = preload("res://scenes/enemy/beast.tscn")

## 事件池：scene / 唯一 id / 每局上限（cap 较大表示基本不限）
const EVENT_POOL: Array[Dictionary] = [
	{"scene": preload("res://scenes/events/spirit_spring.tscn"), "id": "spirit_spring", "cap": 1},
	{"scene": preload("res://scenes/events/heavenly_chest.tscn"), "id": "heavenly_chest", "cap": 99},
	{"scene": preload("res://scenes/events/heavenly_stele.tscn"), "id": "heavenly_stele", "cap": 1},
	{"scene": preload("res://scenes/events/broken_sword_tomb.tscn"), "id": "broken_sword_tomb", "cap": 99},
	{"scene": preload("res://scenes/events/beast_bone_altar.tscn"), "id": "beast_bone_altar", "cap": 1},
]

## ===== 随机生成参数 =====
## 初始小怪数量
@export var initial_enemy_count: int = 8
## 精英怪概率
@export var elite_enemy_chance: float = 0.2
## 是否保证至少一只精英怪
@export var ensure_at_least_one_elite: bool = true
## 事件数量
@export var event_count: int = 4

## 秘境阶段
enum RealmPhase { EXPLORE, BOSS_SPAWNED, CLEARED }
var realm_phase: RealmPhase = RealmPhase.EXPLORE

## Boss 是否已召唤（保证只召唤一次）
var boss_spawned: bool = false
## Boss 是否已击败
var boss_defeated: bool = false
## 本局是否已通关（避免重复触发）
var run_completed: bool = false
## 剩余初始小怪数量（仅初始小怪计入 Boss 召唤判断，事件怪 / Boss 护卫不计入）
var initial_enemy_remaining: int = 0
## 剩余可触发事件数量
var event_remaining: int = 0

## 通关提示面板与生成点 / 运行时容器
@onready var _clear_panel: CanvasLayer = $ClearPanel
@onready var _enemy_spawn_points: Node2D = $SpawnPoints/EnemySpawnPoints
@onready var _event_spawn_points: Node2D = $SpawnPoints/EventSpawnPoints
@onready var _runtime_enemies: Node2D = $RuntimeEnemies
@onready var _runtime_events: Node2D = $RuntimeEvents


func _ready() -> void:
	# 每局随机
	randomize()
	# 通关提示默认隐藏并加入分组
	_clear_panel.visible = false
	_clear_panel.add_to_group("clear_panel")
	# 随机生成初始小怪与事件
	_spawn_initial_enemies()
	_spawn_events()


# ===== 初始小怪随机生成 =====

## 从 EnemySpawnPoints 随机取点生成初始小怪
func _spawn_initial_enemies() -> void:
	var points: Array = _enemy_spawn_points.get_children()
	points.shuffle()
	var count: int = min(initial_enemy_count, points.size())
	var spawned: Array = []
	var elite_count: int = 0

	for i in count:
		var point: Node2D = points[i]
		var is_elite: bool = randf() < elite_enemy_chance
		var beast: Node = spawn_beast_at(point.global_position, is_elite, true)
		if beast == null:
			continue
		spawned.append(beast)
		if is_elite:
			elite_count += 1
		# 仅初始小怪计入 Boss 召唤判断
		initial_enemy_remaining += 1
		beast.tree_exited.connect(_on_initial_enemy_exited)

	# 保证至少一只精英怪
	if ensure_at_least_one_elite and elite_count == 0 and not spawned.is_empty():
		var pick: Node = spawned[randi() % spawned.size()]
		if pick.has_method("make_elite"):
			pick.make_elite()
			elite_count += 1

	print("本局生成小怪数量：", spawned.size())
	print("本局生成精英怪数量：", elite_count)

	# 兜底：若没有初始小怪，直接进入 Boss 环节
	if initial_enemy_remaining == 0:
		spawn_boss_encounter()


# ===== 事件随机生成 =====

## 从 EventSpawnPoints 随机取点生成事件（同类事件受 cap 限制）
func _spawn_events() -> void:
	var points: Array = _event_spawn_points.get_children()
	points.shuffle()
	var target: int = min(event_count, points.size())
	var spawned_counts: Dictionary = {}
	var made: int = 0

	for point in points:
		if made >= target:
			break
		var entry: Dictionary = _pick_event_entry(spawned_counts)
		if entry.is_empty():
			# 没有可用事件（都达上限）则停止
			break
		var event: Node = entry["scene"].instantiate()
		_runtime_events.add_child(event)
		event.global_position = point.global_position
		# 事件真正触发后更新剩余事件数（取消不触发、不发信号、不减少）
		if event.has_signal("event_triggered"):
			event.event_triggered.connect(_on_event_triggered)
		spawned_counts[entry["id"]] = int(spawned_counts.get(entry["id"], 0)) + 1
		made += 1
		print("生成事件：", event.event_name, "，位置：", point.global_position)

	event_remaining = made
	print("本局生成事件数量：", made)


## 事件触发回调：剩余事件数 -1
func _on_event_triggered(_event_id: String) -> void:
	event_remaining = max(0, event_remaining - 1)


## 从事件池随机挑选一个未达上限的事件条目；都达上限返回空字典
func _pick_event_entry(spawned_counts: Dictionary) -> Dictionary:
	var candidates: Array = []
	for entry in EVENT_POOL:
		if int(spawned_counts.get(entry["id"], 0)) < int(entry["cap"]):
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]


# ===== Boss 流程 =====

func _unhandled_input(event: InputEvent) -> void:
	# 通关后按 Enter 重新开始本局
	if run_completed and event.is_action_pressed("ui_accept"):
		# 暂停状态会跨场景重载保留，重开前先恢复，避免新局一开始即暂停
		get_tree().paused = false
		get_tree().reload_current_scene()


## 初始小怪离场（死亡）回调：全部清空后召唤 Boss
func _on_initial_enemy_exited() -> void:
	# 通关 / 场景重载期间不再触发
	if run_completed or not is_inside_tree():
		return
	initial_enemy_remaining = max(0, initial_enemy_remaining - 1)
	if not boss_spawned and initial_enemy_remaining <= 0:
		spawn_boss_encounter()


## 召唤 Boss 与两个护卫小怪（只执行一次）
func spawn_boss_encounter() -> void:
	if boss_spawned:
		return
	boss_spawned = true

	# 生成 Boss，放在地图上方预留的 Boss 区域
	var boss := BOSS_SCENE.instantiate()
	add_child(boss)
	boss.position = Vector2(0, -500)
	# Boss 离场（被击败）时触发通关
	boss.tree_exited.connect(_on_boss_defeated)

	# 生成两个护卫小怪（不计入初始小怪，不会再次触发 Boss）
	spawn_beast_at(Vector2(-140, -420), randf() < elite_enemy_chance, false)
	spawn_beast_at(Vector2(140, -420), randf() < elite_enemy_chance, false)

	# 进入 Boss 阶段并提示
	realm_phase = RealmPhase.BOSS_SPAWNED
	print("小怪已清空，守墟妖王降临")
	_show_notice("小怪已清空，守墟妖王降临")


## 通用妖兽生成（供事件 / Boss 护卫调用）
## count_as_normal_enemy=false 时移出 normal_enemy 组，避免影响 Boss 触发判断
func spawn_beast_at(pos: Vector2, is_elite: bool = false, count_as_normal_enemy: bool = false) -> Node:
	var beast := BEAST_SCENE.instantiate()
	# 入场景前设置 is_elite，确保 _ready 时应用精英强化
	beast.is_elite = is_elite
	var parent: Node = _runtime_enemies if is_instance_valid(_runtime_enemies) else self
	parent.add_child(beast)
	beast.global_position = pos
	if not count_as_normal_enemy:
		beast.remove_from_group("normal_enemy")
	return beast


## Boss 离开场景树（被击败）时触发通关
func _on_boss_defeated() -> void:
	# 避免重复触发
	if run_completed:
		return
	run_completed = true
	boss_defeated = true
	realm_phase = RealmPhase.CLEARED
	print("秘境试炼完成")
	# 通关时确保游戏未处于暂停（防止此前面板暂停残留），以便 Enter 重开
	get_tree().paused = false
	# 短提示 + 通关页面（两者并存）
	_show_notice("秘境试炼完成")
	_clear_panel.visible = true


## 显示阶段短提示（找到 RealmNotice 节点调用）
func _show_notice(text: String) -> void:
	var notice: Node = get_tree().get_first_node_in_group("realm_notice")
	if notice != null and notice.has_method("show_notice"):
		notice.show_notice(text)


## Boss 状态文本
func _boss_status_text() -> String:
	if boss_defeated:
		return "已击败"
	if boss_spawned:
		return "已降临"
	return "未降临"


## 提供给 HUD 的秘境目标数据
func get_realm_hud_data() -> Dictionary:
	var phase_name: String = "explore"
	match realm_phase:
		RealmPhase.BOSS_SPAWNED:
			phase_name = "boss_spawned"
		RealmPhase.CLEARED:
			phase_name = "cleared"
		_:
			phase_name = "explore"
	return {
		"initial_enemy_remaining": initial_enemy_remaining,
		"event_remaining": event_remaining,
		"boss_status": _boss_status_text(),
		"realm_phase": phase_name,
	}
