extends CanvasLayer
## 事件选择面板（风险收益事件用）
## 显示事件名 / 说明 + 两个选项 + 取消；点击后发出 option_selected。
## 打开时暂停游戏，关闭后若无其它阻塞 UI 则恢复。

## 玩家选择某选项时发出（"A" / "B" / "cancel"）
signal option_selected(option_id: String)

@onready var _title: Label = $Panel/VBoxContainer/TitleLabel
@onready var _description: Label = $Panel/VBoxContainer/DescriptionLabel
@onready var _button_a: Button = $Panel/VBoxContainer/OptionButtonA
@onready var _button_b: Button = $Panel/VBoxContainer/OptionButtonB
@onready var _cancel_button: Button = $Panel/VBoxContainer/CancelButton


func _ready() -> void:
	# 暂停时仍可点击
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("event_choice_panel")
	# 关闭键盘焦点，避免 Tab 在面板内切换焦点
	for button in [_button_a, _button_b, _cancel_button]:
		button.focus_mode = Control.FOCUS_NONE
	_button_a.pressed.connect(_on_choice.bind("A"))
	_button_b.pressed.connect(_on_choice.bind("B"))
	_cancel_button.pressed.connect(_on_choice.bind("cancel"))


## 打开事件选择：设置文本并暂停游戏
func open_event(title: String, description: String, option_a: String, option_b: String) -> void:
	_title.text = title
	_description.text = description
	_button_a.text = option_a
	_button_b.text = option_b
	visible = true
	get_tree().paused = true


## 点击选项 / 取消：关闭、恢复（若无其它阻塞 UI）、发出信号
func _on_choice(option_id: String) -> void:
	visible = false
	if not _is_other_blocking_ui_open():
		get_tree().paused = false
	option_selected.emit(option_id)


## 是否还有其它阻塞性 UI 打开
func _is_other_blocking_ui_open() -> bool:
	for group_name in ["boon_choice_panel", "build_panel", "clear_panel"]:
		var panel: Node = get_tree().get_first_node_in_group(group_name)
		if panel != null and panel.visible:
			return true
	return false
