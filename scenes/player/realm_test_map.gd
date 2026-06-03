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

## 通关提示面板
@onready var _clear_panel: CanvasLayer = $ClearPanel


func _ready() -> void:
	# 通关提示默认隐藏
	_clear_panel.visible = false
	# 给当前所有普通小怪连接离场信号，用于检测全部死亡
	for enemy in get_tree().get_nodes_in_group("normal_enemy"):
		enemy.tree_exited.connect(_on_normal_enemy_exited)


func _unhandled_input(event: InputEvent) -> void:
	# 通关后按 Enter 重新开始本局
	if run_completed and event.is_action_pressed("ui_accept"):
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

	# 生成 Boss，放在地图右侧
	var boss := BOSS_SCENE.instantiate()
	add_child(boss)
	boss.position = Vector2(300, 0)
	# Boss 离场（被击败）时触发通关
	boss.tree_exited.connect(_on_boss_defeated)

	# 生成两个护卫小怪（虽是 normal_enemy，但 boss_spawned 已为 true，不会再次触发）
	_spawn_guard(Vector2(230, -80))
	_spawn_guard(Vector2(230, 80))

	print("小怪已清空，守墟妖王降临")


## 生成一个护卫小怪
func _spawn_guard(pos: Vector2) -> void:
	var beast := BEAST_SCENE.instantiate()
	add_child(beast)
	beast.position = pos


## Boss 离开场景树（被击败）时触发通关
func _on_boss_defeated() -> void:
	# 避免重复触发
	if run_completed:
		return
	run_completed = true
	print("秘境试炼完成")
	# 显示通关提示
	_clear_panel.visible = true
