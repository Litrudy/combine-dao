extends RealmEvent
## 兽骨祭坛（风险收益事件）
## A：离开（不触发，事件保留）；B：召唤 1 只精英妖兽，击败后额外获得 8 天道石。

## 交战目标玩家（触发时记录）
var _player_ref: Node = null
## 额外奖励是否已发放
var _reward_given: bool = false


## 重写触发：打开事件选择面板（取消 / 离开不消耗事件）
func trigger_event(player: Node) -> bool:
	if used or player == null:
		return false
	_player_ref = player
	var panel: Node = get_tree().get_first_node_in_group("event_choice_panel")
	if panel == null or not panel.has_method("open_event"):
		return false
	panel.option_selected.connect(_on_option_selected, CONNECT_ONE_SHOT)
	panel.open_event(event_name, description, "离开", "激活祭坛")
	return true


## 选项回调
func _on_option_selected(option_id: String) -> void:
	if option_id == "B":
		# 激活祭坛：召唤 1 只精英妖兽
		var elite: Node = _spawn_beast(global_position + Vector2(0, -100), true)
		if elite != null:
			elite.tree_exited.connect(_on_elite_died)
		print("兽骨祭坛被激活，精英妖兽出现。")
		mark_used()
	# A（离开）/ cancel：不触发，事件保留（used 仍为 false）


## 精英妖兽死亡：额外发放 8 天道石（独立于精英自身掉落）
func _on_elite_died() -> void:
	if _reward_given:
		return
	_reward_given = true
	if is_instance_valid(_player_ref) and _player_ref.has_method("gain_heavenly_stones"):
		_player_ref.gain_heavenly_stones(8)
	print("祭坛精英妖兽被击败，额外获得天道石：8")


## 通过地图通用方法生成妖兽（不计入 normal_enemy）；缺失则本地兜底
func _spawn_beast(pos: Vector2, is_elite: bool) -> Node:
	var map: Node = get_tree().current_scene
	if map != null and map.has_method("spawn_beast_at"):
		return map.spawn_beast_at(pos, is_elite, false)
	var scene: PackedScene = load("res://scenes/enemy/beast.tscn")
	if scene == null:
		return null
	var beast: Node = scene.instantiate()
	beast.is_elite = is_elite
	get_parent().add_child(beast)
	beast.global_position = pos
	beast.remove_from_group("normal_enemy")
	return beast
