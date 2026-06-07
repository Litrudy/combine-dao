extends CanvasLayer
## 战斗 HUD
## M2-4 —— 只保留战斗必要信息：气血 / 修为 / 突破 / 天道石 / 基础攻击 / 技能栏。
## 流派数量 / 已获得机缘 / 已激活专精 已移至构筑页（Tab）。

@onready var _hp_label: Label = $Panel/VBoxContainer/HpLabel
@onready var _cultivation_label: Label = $Panel/VBoxContainer/CultivationLabel
@onready var _breakthrough_label: Label = $Panel/VBoxContainer/BreakthroughLabel
@onready var _stone_label: Label = $Panel/VBoxContainer/StoneRow/StoneLabel
@onready var _primary_attack_label: Label = $Panel/VBoxContainer/PrimaryAttackLabel
@onready var _skill_slot_label: Label = $Panel/VBoxContainer/SkillSlotLabel
@onready var _dash_label: Label = $Panel/VBoxContainer/DashLabel
@onready var _dash_cooldown_bar: ProgressBar = $Panel/VBoxContainer/DashCooldownBar
@onready var _skill_slot_nodes: Dictionary = {
	"Q": $Panel/VBoxContainer/SkillCooldownRow/SlotQ,
	"E": $Panel/VBoxContainer/SkillCooldownRow/SlotE,
	"F": $Panel/VBoxContainer/SkillCooldownRow/SlotF,
}

## 技能 id -> 图标路径（48px，构筑/HUD 通用）
const SKILL_ICON_PATHS: Dictionary = {
	"summon_wolf": "res://art/icons/skill_summon_wolf_48.png",
	"poison_mist": "res://art/icons/skill_poison_mist_48.png",
}
## 已加载技能图标缓存
var _skill_icon_cache: Dictionary = {}
@onready var _realm_enemy_label: Label = $Panel/VBoxContainer/RealmEnemyLabel
@onready var _realm_event_label: Label = $Panel/VBoxContainer/RealmEventLabel
@onready var _realm_boss_label: Label = $Panel/VBoxContainer/RealmBossLabel

## 目标玩家
var _player: Node = null


func _ready() -> void:
	# 延迟一帧再查找玩家，确保玩家已进入场景树
	_connect_player.call_deferred()


## 身法冷却 / 秘境目标持续变化，单独每帧刷新（不重建整个 HUD）
func _process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.has_method("get_hud_data"):
		var data: Dictionary = _player.get_hud_data()
		_update_dash(data)
		_update_skill_cooldowns(data)
	_update_realm_target()


## 刷新 Q/E/F 技能冷却槽（读取玩家冷却快照，仅展示）
func _update_skill_cooldowns(data: Dictionary) -> void:
	var cd_data: Dictionary = data.get("skill_slots_cooldown", {})
	for key in ["Q", "E", "F"]:
		var slot: Control = _skill_slot_nodes.get(key, null)
		if slot == null or not slot.has_method("set_data"):
			continue
		var entry: Dictionary = cd_data.get(key, {})
		var skill_id: String = entry.get("skill_id", "")
		var has_skill: bool = skill_id != ""
		var cd: Dictionary = entry.get("cooldown", {})
		var is_ready: bool = cd.get("ready", true)
		var remaining: float = cd.get("remaining", 0.0)
		slot.set_data(_get_skill_icon(skill_id), key, is_ready, remaining, has_skill)


## 取技能图标：按需 load 并缓存；无配置 / 未导入返回 null
func _get_skill_icon(skill_id: String) -> Texture2D:
	if not SKILL_ICON_PATHS.has(skill_id):
		return null
	if _skill_icon_cache.has(skill_id):
		return _skill_icon_cache[skill_id]
	var path: String = SKILL_ICON_PATHS[skill_id]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_skill_icon_cache[skill_id] = tex
	return tex


## 刷新秘境目标显示（剩余小怪 / 剩余事件 / Boss 状态）
func _update_realm_target() -> void:
	if _realm_enemy_label == null:
		return
	var map: Node = get_tree().current_scene
	if map == null or not map.has_method("get_realm_hud_data"):
		return
	var data: Dictionary = map.get_realm_hud_data()
	_realm_enemy_label.text = "剩余小怪：%d" % data.get("initial_enemy_remaining", 0)
	_realm_event_label.text = "剩余事件：%d" % data.get("event_remaining", 0)
	_realm_boss_label.text = "Boss：%s" % data.get("boss_status", "未降临")


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
	# 多段冲刺时附带显示当前/最大次数
	var charges: int = int(data.get("dash_charges", 1))
	var charge_max: int = int(data.get("dash_charge_max", 1))
	var charge_suffix: String = "（%d/%d）" % [charges, charge_max] if charge_max > 1 else ""
	if data.get("dash_ready", true):
		_dash_label.text = "身法：可用%s" % charge_suffix
	else:
		_dash_label.text = "身法：冷却中 %.1f 秒%s" % [data.get("dash_cooldown_timer", 0.0), charge_suffix]
