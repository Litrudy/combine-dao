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

## 当前展示的机缘列表
var _current_boons: Array = []


func _ready() -> void:
	# 默认隐藏
	visible = false
	# 加入分组，方便玩家脚本查找
	add_to_group("boon_choice_panel")

	# 连接每个按钮，按索引绑定回调
	for i in _buttons.size():
		_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buttons[i].pressed.connect(_on_button_pressed.bind(i))


## 展示一组机缘并显示面板
func show_boons(boons: Array) -> void:
	_current_boons = boons
	for i in _buttons.size():
		var button: Button = _buttons[i]
		if i < boons.size():
			var boon: Dictionary = boons[i]
			# 按钮显示：机缘名称 + 简短描述
			button.text = "%s\n%s" % [boon.get("boon_name", "?"), boon.get("description", "")]
			button.visible = true
		else:
			button.visible = false
	visible = true


## 按钮点击：发出选择信号并隐藏面板
func _on_button_pressed(index: int) -> void:
	if index >= _current_boons.size():
		return
	var boon: Dictionary = _current_boons[index]
	# 先隐藏再发信号，避免重复点击
	visible = false
	boon_selected.emit(boon)
