extends AnimatedSprite2D
## 一次性特效：播放完当前（不循环）动画后自动销毁。
## 纯表现层节点，不参与碰撞 / 移动 / 伤害判定。

func _ready() -> void:
	# 播放结束即销毁（仅对不循环动画触发）
	animation_finished.connect(queue_free)
	# 从第一帧开始播放当前动画
	frame = 0
	play()
