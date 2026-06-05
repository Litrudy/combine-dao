extends Node2D
## 测试地图控制器
## 负责「清空普通小怪 → 召唤 Boss 境界考验」的流程。
## 不含正式 Boss UI / 关卡胜利结算。

## 预加载场景
const BOSS_SCENE: PackedScene = preload("res://scenes/enemy/boss_guardian.tscn")
const BEAST_SCENE: PackedScene = preload("res://scenes/enemy/beast.tscn")

## Boss 是否已召唤（保证只召唤一次）
var boss_spawned: bool = false
## 本局是否已通关（避免重复触发）
var run_completed: bool = false
## 精英怪出现概率
const ELITE_CHANCE: float = 0.2

## 通关提示面板
@onready var _clear_panel: CanvasLayer = $ClearPanel


func _ready() -> void:
	# 通关提示默认隐藏
	_clear_panel.visible = false
	# 加入分组，供玩家判断是否处于通关状态（通关后禁止召唤灵狼）
	_clear_panel.add_to_group("clear_panel")
	# 收集开局普通小怪，连接离场信号并随机指定精英怪
	var normal_enemies: Array = get_tree().get_nodes_in_group("normal_enemy")
	var elite_count: int = 0
	for enemy in normal_enemies:
		enemy.tree_exited.connect(_on_normal_enemy_exited)
		# 20% 概率成为精英怪
		if enemy.has_method("make_elite") and randf() < ELITE_CHANCE:
			enemy.make_elite()
			elite_count += 1
	# 小怪数量较少时确保至少有 1 只精英怪用于测试
	if elite_count == 0 and normal_enemies.size() > 0:
		var pick = normal_enemies[randi() % normal_enemies.size()]
		if pick.has_method("make_elite"):
			pick.make_elite()


func _unhandled_input(event: InputEvent) -> void:
	# 通关后按 Enter 重新开始本局
	if run_completed and event.is_action_pressed("ui_accept"):
		# 暂停状态会跨场景重载保留，重开前先恢复，避免新局一开始即暂停
		get_tree().paused = false
		get_tree().reload_current_scene()


## 普通小怪离开场景树时回调
func _on_normal_enemy_exited() -> void:
	# 延迟一帧再统计，确保离场节点已从分组中移除
	_check_normal_enemies.call_deferred()


## 检查剩余普通小怪数量，清空则召唤 Boss
func _check_normal_enemies() -> void:
	if boss_spawned:
		return
	if get_tree().get_nodes_in_group("normal_enemy").size() == 0:
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

	# 生成两个护卫小怪（虽是 normal_enemy，但 boss_spawned 已为 true，不会再次触发）
	_spawn_guard(Vector2(-140, -420))
	_spawn_guard(Vector2(140, -420))

	print("小怪已清空，守墟妖王降临")


## 通用妖兽生成（供事件调用）
## count_as_normal_enemy=false 时移出 normal_enemy 组，避免事件怪影响 Boss 触发判断
func spawn_beast_at(pos: Vector2, is_elite: bool = false, count_as_normal_enemy: bool = false) -> Node:
	var beast := BEAST_SCENE.instantiate()
	# 入场景前设置 is_elite，确保 _ready 时应用精英强化
	beast.is_elite = is_elite
	add_child(beast)
	beast.global_position = pos
	if not count_as_normal_enemy:
		# 事件召唤怪不计入小怪清空判断
		beast.remove_from_group("normal_enemy")
	return beast


## 生成一个护卫小怪（20% 概率为精英怪）
func _spawn_guard(pos: Vector2) -> void:
	var beast := BEAST_SCENE.instantiate()
	# 入场景前设置 is_elite，确保 _ready 时应用精英强化
	if randf() < ELITE_CHANCE:
		beast.is_elite = true
	add_child(beast)
	beast.position = pos


## Boss 离开场景树（被击败）时触发通关
func _on_boss_defeated() -> void:
	# 避免重复触发
	if run_completed:
		return
	run_completed = true
	print("秘境试炼完成")
	# 通关时确保游戏未处于暂停（防止此前面板暂停残留），以便 Enter 重开
	get_tree().paused = false
	# 显示通关提示
	_clear_panel.visible = true
