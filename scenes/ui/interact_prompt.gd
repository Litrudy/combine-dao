extends CanvasLayer
## 交互提示：玩家靠近可交互秘境事件时显示「按 F 交互」。
## 每帧查找最近的可交互事件；阻塞 UI 打开时隐藏。

@onready var _label: Label = $Label


func _ready() -> void:
	# 暂停时仍运行，以便 Tab / 机缘界面打开时能隐藏自己
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_delta: float) -> void:
	# 阻塞性 UI（机缘 / 构筑页 / 通关）打开时隐藏
	if _is_blocking_ui_open():
		visible = false
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		visible = false
		return

	# 查找最近的可交互事件
	var nearest_name: String = ""
	var nearest_dist: float = INF
	for event in get_tree().get_nodes_in_group("realm_event"):
		if not is_instance_valid(event) or not event.has_method("can_interact"):
			continue
		if not event.can_interact():
			continue
		var d: float = player.global_position.distance_to(event.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_name = event.event_name

	if nearest_name != "":
		_label.text = "按 F 交互：%s" % nearest_name
		visible = true
	else:
		visible = false


## 是否有阻塞性 UI 打开
func _is_blocking_ui_open() -> bool:
	for group_name in ["boon_choice_panel", "build_panel", "clear_panel", "event_choice_panel"]:
		var panel: Node = get_tree().get_first_node_in_group(group_name)
		if panel != null and panel.visible:
			return true
	return false
