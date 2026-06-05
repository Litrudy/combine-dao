extends RealmEvent
## 破损剑冢（风险收益事件）
## A：取走 5 天道石；B：唤醒 2 只守卫，全部击败后开启一次额外机缘。

## 交战目标玩家（触发时记录）
var _player_ref: Node = null
## 选项 B 召唤的守卫
var _guards: Array = []
## 机缘奖励是否已发放（守卫全灭后只发一次）
var _reward_given: bool = false


## 重写触发：打开事件选择面板（此时不立即 used，取消可再来）
func trigger_event(player: Node) -> bool:
	if used or player == null:
		return false
	_player_ref = player
	var panel: Node = get_tree().get_first_node_in_group("event_choice_panel")
	if panel == null or not panel.has_method("open_event"):
		return false
	# 一次性连接，避免与其它事件交叉
	panel.option_selected.connect(_on_option_selected, CONNECT_ONE_SHOT)
	panel.open_event(event_name, description, "取走残余灵石", "唤醒剑冢守卫")
	return true


## 选项回调
func _on_option_selected(option_id: String) -> void:
	match option_id:
		"A":
			# 取走残余灵石：获得 5 天道石
			if is_instance_valid(_player_ref) and _player_ref.has_method("gain_heavenly_stones"):
				_player_ref.gain_heavenly_stones(5)
			print("你取走剑冢残余灵石，获得天道石：5")
			mark_used()
		"B":
			# 唤醒守卫：召唤 2 只小怪（不计入 normal_enemy，避免影响 Boss 触发）
			_spawn_guards()
			print("剑冢守卫被唤醒。")
			mark_used()
		_:
			# 取消：不触发效果，事件保留（used 仍为 false）
			pass


## 召唤两只守卫并监听其死亡
func _spawn_guards() -> void:
	var positions: Array = [
		global_position + Vector2(-80, 0),
		global_position + Vector2(80, 0),
	]
	for pos in positions:
		var guard: Node = _spawn_beast(pos, false)
		if guard != null:
			_guards.append(guard)
			guard.tree_exited.connect(_on_guard_exited)


## 守卫离场（死亡）回调：全部击败后开启一次额外机缘
func _on_guard_exited() -> void:
	if _reward_given:
		return
	# 统计仍存活（仍在场景树）的守卫
	var alive: int = 0
	for guard in _guards:
		if is_instance_valid(guard) and guard.is_inside_tree():
			alive += 1
	if alive == 0:
		_reward_given = true
		if is_instance_valid(_player_ref) and _player_ref.has_method("open_bonus_boon_choice"):
			_player_ref.open_bonus_boon_choice()
		print("剑冢守卫已被击败，获得一次机缘选择")


## 通过地图通用方法生成妖兽（不计入 normal_enemy）；缺失则本地兜底
func _spawn_beast(pos: Vector2, is_elite: bool) -> Node:
	var map: Node = get_tree().current_scene
	if map != null and map.has_method("spawn_beast_at"):
		return map.spawn_beast_at(pos, is_elite, false)
	# 兜底：本地实例化
	var scene: PackedScene = load("res://scenes/enemy/beast.tscn")
	if scene == null:
		return null
	var beast: Node = scene.instantiate()
	beast.is_elite = is_elite
	get_parent().add_child(beast)
	beast.global_position = pos
	beast.remove_from_group("normal_enemy")
	return beast
