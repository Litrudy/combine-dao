extends CanvasLayer
## 基础文字 HUD
## M2-1 —— 显示玩家气血 / 修为 / 突破状态 / 流派进度 / 已获得机缘。
## 只读展示，不修改玩家数据。

@onready var _hp_label: Label = $Panel/VBoxContainer/HpLabel
@onready var _cultivation_label: Label = $Panel/VBoxContainer/CultivationLabel
@onready var _breakthrough_label: Label = $Panel/VBoxContainer/BreakthroughLabel
@onready var _stone_label: Label = $Panel/VBoxContainer/StoneLabel
@onready var _school_label: Label = $Panel/VBoxContainer/SchoolLabel
@onready var _boon_list_label: Label = $Panel/VBoxContainer/BoonListLabel
@onready var _spec_label: Label = $Panel/VBoxContainer/SpecLabel
@onready var _debug_stat_label: Label = $Panel/VBoxContainer/DebugStatLabel

## 目标玩家
var _player: Node = null


func _ready() -> void:
	# 延迟一帧再查找玩家，确保玩家已进入场景树
	_connect_player.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# 按 F1 显隐调试数值行（正式演示时可隐藏）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_debug_stat_label.visible = not _debug_stat_label.visible


## 查找玩家并连接其状态信号
func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	# 连接状态变化信号
	if _player.has_signal("stats_changed") and not _player.stats_changed.is_connected(_refresh):
		_player.stats_changed.connect(_refresh)
	# 开局刷新一次
	_refresh()


## 根据玩家数据刷新显示
func _refresh() -> void:
	if not is_instance_valid(_player) or not _player.has_method("get_hud_data"):
		return
	var data: Dictionary = _player.get_hud_data()

	# 气血
	_hp_label.text = "气血：%d / %d" % [data["current_hp"], data["max_hp"]]
	# 修为
	_cultivation_label.text = "修为：%d / %d" % [data["cultivation_exp"], data["cultivation_exp_required"]]
	# 突破状态
	_breakthrough_label.text = "按 R 突破" if data["can_breakthrough"] else "继续修炼"
	# 天道石
	_stone_label.text = "天道石：%d" % data["heavenly_stones"]
	# 流派进度
	var sc: Dictionary = data["school_counts"]
	_school_label.text = "剑气：%d\n御兽：%d\n毒蛊：%d" % [sc["sword"], sc["beast"], sc["poison"]]
	# 已获得机缘（每行一个，重复机缘带 ×N 后缀）
	var names: Array = data["acquired_boon_names"]
	if names.is_empty():
		_boon_list_label.text = "已获得机缘：暂无机缘"
	else:
		_boon_list_label.text = "已获得机缘：\n" + "\n".join(names)
	# 已激活专精（每行一个）
	var specs: Array = data["active_specialization_names"]
	if specs.is_empty():
		_spec_label.text = "已激活专精：暂无专精"
	else:
		_spec_label.text = "已激活专精：\n" + "\n".join(specs)
	# 实时调试数值：攻击冷却 / 剑气伤害加成 / 毒雾每跳伤害 / 存活灵狼数
	_debug_stat_label.text = "冷却：%.2fs  剑伤+%d  毒伤%d  灵狼%d" % [
		data["attack_cooldown"],
		data["sword_damage_bonus"],
		data["poison_tick_damage"],
		data["wolf_count"],
	]
