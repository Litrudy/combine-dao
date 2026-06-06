extends CanvasLayer
## 秘境阶段短提示：显示一行文本，数秒后自动隐藏。
## 与通关页面 ClearPanel 不同——本提示只是临时阶段反馈。

@onready var _label: Label = $Label

## 当前隐藏用的计时器
var _timer: SceneTreeTimer = null


func _ready() -> void:
	# 暂停时也能显示 / 计时，避免阶段提示卡住
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("realm_notice")


## 显示一条提示，duration 秒后自动隐藏
func show_notice(text: String, duration: float = 2.0) -> void:
	_label.text = text
	visible = true
	# create_timer 第 4 参数 ignore_time_scale=true 保证暂停时也能计时
	_timer = get_tree().create_timer(duration, true, false, true)
	_timer.timeout.connect(_on_timeout)


## 计时结束：仅当没有更新的提示时才隐藏
func _on_timeout() -> void:
	visible = false
