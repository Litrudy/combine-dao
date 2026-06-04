extends CanvasLayer
## 机缘选择面板
## M1 任务 6 + M2-4B —— 修为满时弹出，展示 3 个机缘供玩家选择。
## 负责展示、刷新、升品与发信号；打开时暂停游戏，选择后恢复。

## 玩家选择某机缘后发出（携带机缘数据）
signal boon_selected(boon: Dictionary)

## 标题与信息标签
@onready var _title: Label = $Panel/VBoxContainer/TitleLabel
@onready var _current_attack_label: Label = $Panel/VBoxContainer/CurrentAttackLabel
@onready var _stone_label: Label = $Panel/VBoxContainer/HeavenlyStoneLabel
@onready var _hint_label: Label = $Panel/VBoxContainer/HintLabel
## 三个机缘按钮
@onready var _buttons: Array[Button] = [
	$Panel/VBoxContainer/Button0,
	$Panel/VBoxContainer/Button1,
	$Panel/VBoxContainer/Button2,
]
## 刷新按钮 / 升品按钮
@onready var _refresh_button: Button = $Panel/VBoxContainer/RefreshButton
@onready var _upgrade_button: Button = $Panel/VBoxContainer/UpgradeGradeButton

## 当前展示的机缘列表
var _current_boons: Array = []
## 玩家对象（用于扣除天道石与重新抽取机缘）
var _player: Node = null
## 机缘工具（品阶升级等无状态计算）
var _boon_manager := BoonManager.new()

## 本次界面的刷新消耗（每次刷新后 +1，开界面重置为 1）
var _refresh_cost: int = 1
## 本次界面的升品消耗（每次升品后 +6，开界面重置为 6）
var _upgrade_cost: int = 6

## 流派标签 -> 显示名
const SCHOOL_NAMES: Dictionary = {
	"sword": "剑气",
	"beast": "御兽",
	"poison": "毒蛊",
}
## 基础攻击类型 -> 显示名
const ATTACK_NAMES: Dictionary = {
	"sword_qi": "剑气",
	"poison_dart": "毒镖",
	"beast_whip": "驭兽鞭",
}
## 解锁 / 替换类机缘的 effect_type（不显示「基础值 → 最终值」）
const UNLOCK_EFFECT_TYPES: Array[String] = [
	"summon_wolf", "poison_mist", "poison_stack", "poison_explosion",
	"sword_execute", "beast_guard", "extra_wolf", "replace_primary_attack",
]


func _ready() -> void:
	# 暂停时仍可处理按钮（刷新 / 升品 / 选择机缘）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 默认隐藏
	visible = false
	# 设置标题文本
	_title.text = "请选择机缘"
	# 加入分组，方便玩家脚本查找
	add_to_group("boon_choice_panel")

	# 连接每个按钮，按索引绑定回调
	for i in _buttons.size():
		_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buttons[i].pressed.connect(_on_button_pressed.bind(i))

	# 连接刷新 / 升品按钮
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)


## 展示一组机缘并显示面板（每次打开重置刷新 / 升品消耗并暂停游戏）
func show_boons(boons: Array) -> void:
	_current_boons = boons
	_refresh_cost = 1
	_upgrade_cost = 6
	_acquire_player()
	_render()
	visible = true
	# 选择机缘期间暂停游戏
	get_tree().paused = true


## 查找玩家对象
func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


## 构筑页是否打开（关闭本面板时用于判断是否恢复游戏）
func _is_build_panel_open() -> bool:
	var panel: Node = get_tree().get_first_node_in_group("build_panel")
	return panel != null and panel.visible


## 重新渲染三个机缘按钮、信息标签与刷新 / 升品按钮文字
func _render() -> void:
	if not is_instance_valid(_player):
		_acquire_player()

	# 当前基础攻击类型
	if is_instance_valid(_player):
		var attack_id: String = _player.primary_attack_type
		_current_attack_label.text = "当前基础攻击：%s" % ATTACK_NAMES.get(attack_id, attack_id)
	else:
		_current_attack_label.text = "当前基础攻击：未知"

	# 当前天道石
	var stones: int = _player.heavenly_stones if is_instance_valid(_player) else 0
	_stone_label.text = "天道石：%d" % stones

	# 三个机缘按钮
	for i in _buttons.size():
		var button: Button = _buttons[i]
		if i < _current_boons.size():
			_setup_button(button, _current_boons[i])
			button.visible = true
		else:
			button.visible = false

	# 刷新按钮文字（含天道石不足提示）
	_refresh_button.text = "刷新机缘（消耗 %d 天道石）" % _refresh_cost
	if stones < _refresh_cost:
		_refresh_button.text += "  天道石不足"

	# 升品按钮文字（已全部天品 / 天道石不足提示）
	if _all_boons_max_grade():
		_upgrade_button.text = "提升品阶（已达最高品阶）"
	else:
		_upgrade_button.text = "提升品阶（消耗 %d 天道石）" % _upgrade_cost
		if stones < _upgrade_cost:
			_upgrade_button.text += "  天道石不足"

	_hint_label.text = "可用天道石刷新机缘或提升当前机缘品阶"


## 根据机缘数据设置单个按钮的文字与颜色
func _setup_button(button: Button, boon: Dictionary) -> void:
	var grade_name: String = boon.get("grade_name", "")
	var boon_name: String = boon.get("boon_name", "?")
	var star_text: String = boon.get("star_text", "")
	var description: String = boon.get("description", "")

	# 第一行：【品阶】机缘名 星级
	var title_line: String = boon_name
	if grade_name != "":
		title_line = "【%s】%s" % [grade_name, boon_name]
	if star_text != "":
		title_line += " " + star_text

	# 流派行：剑气 / 御兽 / 毒蛊
	var school_text: String = _school_text(boon.get("school_tags", []))
	var school_line: String = "\n流派：%s" % school_text if school_text != "" else ""

	# 效果行：基础值 → 最终值（仅数值类机缘显示，解锁类不显示）
	var effect_line: String = ""
	if not _is_unlock_boon(boon):
		var base_value = boon.get("effect_value", null)
		var final_value = boon.get("final_effect_value", null)
		if final_value != null and (base_value is int or base_value is float):
			effect_line = "\n效果：%s → %s" % [str(base_value), str(final_value)]

	button.text = "%s%s%s\n描述：%s" % [title_line, school_line, effect_line, description]

	# 按钮文字颜色使用品阶颜色（缺失时用白色）
	var color_hex: String = boon.get("grade_color", "#FFFFFF")
	var grade_color := Color(color_hex)
	button.add_theme_color_override("font_color", grade_color)
	button.add_theme_color_override("font_hover_color", grade_color)
	button.add_theme_color_override("font_pressed_color", grade_color)
	button.add_theme_color_override("font_focus_color", grade_color)


## 是否为解锁 / 替换类机缘（不展示数值）
func _is_unlock_boon(boon: Dictionary) -> bool:
	return boon.get("effect_type", "") in UNLOCK_EFFECT_TYPES


## 流派标签数组 -> 显示文本（用 / 连接）
func _school_text(tags: Array) -> String:
	var names: Array[String] = []
	for tag in tags:
		names.append(SCHOOL_NAMES.get(tag, str(tag)))
	return " / ".join(names)


## 当前三个机缘是否全部已达最高品阶（天品）
func _all_boons_max_grade() -> bool:
	if _current_boons.is_empty():
		return false
	for boon in _current_boons:
		if boon.get("grade_id", "fan") != "tian":
			return false
	return true


## 按钮点击：恢复游戏、发出选择信号并隐藏面板
func _on_button_pressed(index: int) -> void:
	if index >= _current_boons.size():
		return
	var boon: Dictionary = _current_boons[index]
	# 先隐藏再发信号，避免重复点击
	visible = false
	# 完成选择后恢复游戏（除非构筑页仍打开）
	if not _is_build_panel_open():
		get_tree().paused = false
	boon_selected.emit(boon)


## 刷新机缘：消耗递增天道石，重新抽取候选
func _on_refresh_pressed() -> void:
	if not is_instance_valid(_player):
		_acquire_player()
	# 天道石不足则不刷新
	if not is_instance_valid(_player) or _player.heavenly_stones < _refresh_cost:
		print("天道石不足，无法刷新机缘")
		return
	_player.spend_heavenly_stones(_refresh_cost)

	# 重新抽取（仍排除已获得、满足前置）
	_current_boons = _player.roll_boon_options(_buttons.size())
	# 刷新消耗递增
	_refresh_cost += 1
	_render()


## 提升品阶：消耗递增天道石，统一提升当前所有机缘一级品阶
func _on_upgrade_pressed() -> void:
	if not is_instance_valid(_player):
		_acquire_player()
	# 三个机缘均已天品：不报错、不消耗
	if _all_boons_max_grade():
		print("当前机缘已达最高品阶，不再消耗天道石")
		return
	# 天道石不足则不升品
	if not is_instance_valid(_player) or _player.heavenly_stones < _upgrade_cost:
		print("天道石不足，无法提升品阶")
		return
	_player.spend_heavenly_stones(_upgrade_cost)

	# 对当前每个机缘提升一级品阶并重算数值（已天品的保持天品不变）
	for boon in _current_boons:
		_boon_manager.upgrade_boon_grade(boon)
	# 升品消耗递增
	_upgrade_cost += 6
	_render()
