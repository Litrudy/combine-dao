extends CanvasLayer
## 战斗 HUD
## M2-4 —— 只保留战斗必要信息：气血 / 修为 / 突破 / 天道石 / 基础攻击 / 技能栏。
## 流派数量 / 已获得机缘 / 已激活专精 已移至构筑页（Tab）。

@onready var _hp_label: Label = $Panel/VBoxContainer/HpLabel
@onready var _cultivation_label: Label = $Panel/VBoxContainer/CultivationLabel
@onready var _breakthrough_label: Label = $Panel/VBoxContainer/BreakthroughLabel
@onready var _stone_label: Label = $Panel/VBoxContainer/StoneLabel
@onready var _primary_attack_label: Label = $Panel/VBoxContainer/PrimaryAttackLabel
@onready var _skill_slot_label: Label = $Panel/VBoxContainer/SkillSlotLabel

## 目标玩家
var _player: Node = null


func _ready() -> void:
	# 延迟一帧再查找玩家，确保玩家已进入场景树
	_connect_player.call_deferred()


## 查找玩家并连接其状态信号
func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if _player.has_signal("stats_changed") and not _player.stats_changed.is_connected(_refresh):
		_player.stats_changed.connect(_refresh)
	# 开局刷新一次
	_refresh()


## 根据玩家数据刷新显示
func _refresh() -> void:
	if not is_instance_valid(_player) or not _player.has_method("get_hud_data"):
		return
	var data: Dictionary = _player.get_hud_data()

	_hp_label.text = "气血：%d / %d" % [data["current_hp"], data["max_hp"]]
	_cultivation_label.text = "修为：%d / %d" % [data["cultivation_exp"], data["cultivation_exp_required"]]
	_breakthrough_label.text = "按 R 突破" if data["can_breakthrough"] else "继续修炼"
	_stone_label.text = "天道石：%d" % data["heavenly_stones"]
	_primary_attack_label.text = "基础攻击：%s" % data["primary_attack_name"]

	# 技能栏 Q / E / F
	var slots: Dictionary = data["skill_slots_display"]
	_skill_slot_label.text = "Q：%s  E：%s  F：%s" % [
		slots.get("Q", "空"), slots.get("E", "空"), slots.get("F", "空")
	]
