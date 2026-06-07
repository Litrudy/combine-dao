extends Control
## 技能冷却槽（Q/E/F 各一个）：图标 + 按键 + 冷却遮罩 + 剩余秒数。
## 只显示反馈，不决定技能能否释放。

@onready var _icon: TextureRect = $Icon
@onready var _overlay: ColorRect = $Overlay
@onready var _key_label: Label = $KeyLabel
@onready var _cd_label: Label = $CdLabel


## 刷新一个槽位的显示
## icon：技能图标（可为 null）；key：按键字母；ready：是否就绪；remaining：剩余冷却秒
## has_skill：该槽是否装备了技能
func set_data(icon: Texture2D, key: String, ready: bool, remaining: float, has_skill: bool) -> void:
	_key_label.text = key
	if not has_skill:
		_icon.texture = null
		_icon.modulate = Color(1, 1, 1, 0.25)
		_overlay.visible = false
		_cd_label.text = ""
		return
	_icon.texture = icon
	if ready:
		_icon.modulate = Color.WHITE
		_overlay.visible = false
		_cd_label.text = ""
	else:
		_icon.modulate = Color(0.45, 0.45, 0.45, 1.0)
		_overlay.visible = true
		_cd_label.text = "%.1f" % remaining
