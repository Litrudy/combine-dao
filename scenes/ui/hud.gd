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
@onready var _dash_label: Label = $Panel/VBoxContainer/DashLabel
@onready var _dash_cooldown_bar: ProgressBar = $Panel/VBoxContainer/DashCooldownBar

## 目标玩家
var _player: Node = null


func _ready() -> void:
	# 延迟一帧再查找玩家，确保玩家已进入场景树
	_connect_player.call_deferred()


## 身法冷却持续变化，单独每帧刷新（不重建整个 HUD）
func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not _player.has_method("get_hud_data"):
		return
	_update_dash(_player.get_hud_data())


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

	# 身法冷却（开局 / 状态变化时也刷新一次）
	_update_dash(data)


## 刷新身法冷却条与文本（供 _refresh 与 _process 共用）
func _update_dash(data: Dictionary) -> void:
	if _dash_label == null or _dash_cooldown_bar == null:
		return
	var progress: float = data.get("dash_cooldown_progress", 1.0)
	_dash_cooldown_bar.value = progress * 100.0
	if data.get("dash_ready", true):
		_dash_label.text = "身法：可用"
	else:
		_dash_label.text = "身法：冷却中 %.1f 秒" % data.get("dash_cooldown_timer", 0.0)
