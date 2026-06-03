extends CanvasLayer
## 机缘选择面板
## M1 任务 6 —— 修为满时弹出，展示 3 个机缘供玩家选择。
## 仅负责展示与发信号，不负责效果应用。

## 玩家选择某机缘后发出（携带机缘数据）
signal boon_selected(boon: Dictionary)

## 标题
@onready var _title: Label = $Panel/VBoxContainer/TitleLabel
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


func _ready() -> void:
	# 默认隐藏
	visible = false
	# 设置标题文本
	_title.text = "请选择突破方向"
	# 加入分组，方便玩家脚本查找
	add_to_group("boon_choice_panel")

	# 连接每个按钮，按索引绑定回调
	for i in _buttons.size():
		_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buttons[i].pressed.connect(_on_button_pressed.bind(i))

	# 连接刷新 / 升品按钮
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)


## 展示一组机缘并显示面板（每次打开重置刷新 / 升品消耗）
func show_boons(boons: Array) -> void:
	_current_boons = boons
	_refresh_cost = 1
	_upgrade_cost = 6
	_acquire_player()
	_render()
	visible = true


## 查找玩家对象
func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


## 重新渲染三个机缘按钮与刷新 / 升品按钮文字
func _render() -> void:
	for i in _buttons.size():
		var button: Button = _buttons[i]
		if i < _current_boons.size():
			_setup_button(button, _current_boons[i])
			button.visible = true
		else:
			button.visible = false
	_refresh_button.text = "刷新机缘（消耗 %d 天道石）" % _refresh_cost
	_upgrade_button.text = "提升品阶（消耗 %d 天道石）" % _upgrade_cost


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

	# 效果行：基础值 → 最终值（仅当效果值为数字时显示）
	var effect_line: String = ""
	var base_value = boon.get("effect_value", null)
	var final_value = boon.get("final_effect_value", null)
	if final_value != null and (base_value is int or base_value is float):
		effect_line = "\n效果：%s → %s" % [str(base_value), str(final_value)]

	button.text = "%s\n%s%s" % [title_line, description, effect_line]

	# 按钮文字颜色使用品阶颜色（缺失时用白色）
	var color_hex: String = boon.get("grade_color", "#FFFFFF")
	button.add_theme_color_override("font_color", Color(color_hex))
	button.add_theme_color_override("font_hover_color", Color(color_hex))
	button.add_theme_color_override("font_pressed_color", Color(color_hex))


## 按钮点击：发出选择信号并隐藏面板
func _on_button_pressed(index: int) -> void:
	if index >= _current_boons.size():
		return
	var boon: Dictionary = _current_boons[index]
	# 先隐藏再发信号，避免重复点击
	visible = false
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
	# 天道石不足则不升品
	if not is_instance_valid(_player) or _player.heavenly_stones < _upgrade_cost:
		print("天道石不足，无法提升品阶")
		return
	_player.spend_heavenly_stones(_upgrade_cost)

	# 对当前每个机缘提升一级品阶并重算数值
	for boon in _current_boons:
		_boon_manager.upgrade_boon_grade(boon)
	# 升品消耗递增
	_upgrade_cost += 6
	_render()
