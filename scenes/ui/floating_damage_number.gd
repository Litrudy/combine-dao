extends Node2D
## 漂浮伤害数字：短暂上浮 + 淡出后自销毁。纯表现，不参与碰撞 / 结算。

@onready var _label: Label = $Label


## 由生成方调用（在设置好位置之后）：设置数值与颜色，并从当前位置启动上浮淡出
func setup(amount: int, color: Color) -> void:
	# _label 可能在 _ready 前被调用，做安全获取
	if _label == null:
		_label = $Label
	_label.text = str(amount)
	_label.modulate = color
	# 随机左右微偏，避免多段伤害完全重叠；从当前 position 起算
	var dx: float = randf_range(-10.0, 10.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", position + Vector2(dx, -36.0), 0.6)
	t.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)
