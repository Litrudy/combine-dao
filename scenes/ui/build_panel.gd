extends CanvasLayer
## 构筑页（Tab）
## M2-4 —— 显示灵根 / 基础攻击 / 技能栏 / 流派 / 专精 / 已获得机缘，
## 并允许切换基础攻击与调整技能键位。只读展示与调用玩家方法，不直接改玩家数据。

@onready var _root_label: Label = $Panel/VBoxContainer/RootLabel
@onready var _primary_attack_label: Label = $Panel/VBoxContainer/PrimaryAttackLabel
@onready var _primary_attack_container: HBoxContainer = $Panel/VBoxContainer/PrimaryAttackContainer
@onready var _skill_slot_label: Label = $Panel/VBoxContainer/SkillSlotLabel
@onready var _skill_slot_container: VBoxContainer = $Panel/VBoxContainer/SkillSlotContainer
@onready var _school_count_label: Label = $Panel/VBoxContainer/SchoolCountLabel
@onready var _specialization_label: Label = $Panel/VBoxContainer/SpecializationLabel
@onready var _acquired_boon_label: Label = $Panel/VBoxContainer/AcquiredBoonLabel

## 目标玩家
var _player: Node = null


func _ready() -> void:
	# 默认隐藏并加入分组，供玩家脚本查找
	visible = false
	add_to_group("build_panel")
	# 延迟一帧连接玩家
	_connect_player.call_deferred()


## 查找玩家并连接状态信号
func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player != null and _player.has_signal("stats_changed"):
		if not _player.stats_changed.is_connected(_on_stats_changed):
			_player.stats_changed.connect(_on_stats_changed)


## 玩家状态变化时，若构筑页可见则刷新
func _on_stats_changed() -> void:
	if visible:
		_refresh()


## 切换显隐（由玩家按 Tab 调用）
func toggle() -> void:
	if visible:
		close()
	else:
		open()


## 打开并刷新
func open() -> void:
	if _player == null:
		_connect_player()
	_refresh()
	visible = true


## 关闭
func close() -> void:
	visible = false


## 根据玩家构筑数据刷新页面
func _refresh() -> void:
	if not is_instance_valid(_player) or not _player.has_method("get_build_data"):
		return
	var data: Dictionary = _player.get_build_data()

	# 灵根
	_root_label.text = "剑灵根：%d\n毒灵根：%d\n兽灵根：%d" % [
		data["sword_root"], data["poison_root"], data["beast_root"]
	]

	# 当前基础攻击
	var current_attack: String = data["primary_attack_type"]
	_primary_attack_label.text = "当前基础攻击：%s" % _player.get_primary_attack_display_name(current_attack)

	# 已解锁基础攻击按钮（点击切换）
	_clear_container(_primary_attack_container)
	for attack_id in data["unlocked_primary_attacks"]:
		var button := Button.new()
		var attack_name: String = _player.get_primary_attack_display_name(attack_id)
		button.text = attack_name + ("（当前）" if attack_id == current_attack else "")
		button.pressed.connect(_player.set_primary_attack.bind(attack_id))
		_primary_attack_container.add_child(button)

	# 技能栏当前绑定
	var slots: Dictionary = data["skill_slots"]
	_skill_slot_label.text = "技能栏：\nQ：%s   E：%s   F：%s" % [
		_slot_text(slots.get("Q", "")),
		_slot_text(slots.get("E", "")),
		_slot_text(slots.get("F", "")),
	]

	# 已解锁技能 + 装备按钮
	_clear_container(_skill_slot_container)
	var unlocked_skills: Array = data["unlocked_skills"]
	if unlocked_skills.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无已解锁技能"
		_skill_slot_container.add_child(empty_label)
	else:
		for skill_id in unlocked_skills:
			_skill_slot_container.add_child(_make_skill_row(skill_id))

	# 流派数量
	var sc: Dictionary = data["school_counts"]
	_school_count_label.text = "流派：剑气 %d   御兽 %d   毒蛊 %d" % [
		sc.get("sword", 0), sc.get("beast", 0), sc.get("poison", 0)
	]

	# 已激活专精
	var specs: Array = data["active_specialization_names"]
	if specs.is_empty():
		_specialization_label.text = "已激活专精：暂无专精"
	else:
		_specialization_label.text = "已激活专精：" + "、".join(specs)

	# 已获得机缘（带品阶星级）
	var records: Array = data["acquired_boon_records"]
	if records.is_empty():
		_acquired_boon_label.text = "已获得机缘：暂无机缘"
	else:
		var names: Array[String] = []
		for record in records:
			names.append(_format_record(record))
		_acquired_boon_label.text = "已获得机缘：\n" + "\n".join(names)


## 单个技能行：技能名 + 装备到 Q/E/F 按钮
func _make_skill_row(skill_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = _player.get_skill_display_name(skill_id) + "："
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)
	for slot_key in ["Q", "E", "F"]:
		var button := Button.new()
		button.text = "装备到 " + slot_key
		button.pressed.connect(_player.equip_skill_to_slot.bind(skill_id, slot_key))
		row.add_child(button)
	return row


## 槽位显示文本（空则显示“空”）
func _slot_text(skill_id: String) -> String:
	if skill_id == "":
		return "空"
	return _player.get_skill_display_name(skill_id)


## 机缘记录显示：【品阶】名 星级
func _format_record(record: Dictionary) -> String:
	var boon_name: String = record.get("boon_name", "?")
	var grade_name: String = record.get("grade_name", "")
	var star_text: String = record.get("star_text", "")
	var result: String = boon_name
	if grade_name != "":
		result = "【%s】%s" % [grade_name, boon_name]
	if star_text != "":
		result += " " + star_text
	return result


## 清空容器子节点
func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
