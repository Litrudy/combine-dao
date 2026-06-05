extends CanvasLayer
## 构筑页（Tab）—— M2-4E 模块化重构
## 左侧模块按钮切换，右侧 ContentContainer 动态重建对应模块内容。
## 只读展示与调用玩家已有方法（set_primary_attack / equip_skill_to_slot），不直接改玩家内部变量。

## 当前模块（overview / primary_attack / skill_slot / school / boon）
var current_module: String = "overview"
## 目标玩家
var _player: Node = null

## 左侧模块按钮
@onready var _overview_button: Button = $Panel/Margin/VBox/HBox/ModuleList/OverviewButton
@onready var _primary_attack_button: Button = $Panel/Margin/VBox/HBox/ModuleList/PrimaryAttackButton
@onready var _skill_slot_button: Button = $Panel/Margin/VBox/HBox/ModuleList/SkillSlotButton
@onready var _school_button: Button = $Panel/Margin/VBox/HBox/ModuleList/SchoolButton
@onready var _boon_button: Button = $Panel/Margin/VBox/HBox/ModuleList/BoonButton
## 右侧内容容器
@onready var _content_container: VBoxContainer = $Panel/Margin/VBox/HBox/ContentPanel/ContentContainer

## 模块名 -> 左侧按钮（用于高亮当前模块）
var _module_buttons: Dictionary = {}

## 品阶颜色兜底
const DEFAULT_COLOR: String = "#FFFFFF"


func _ready() -> void:
	# 暂停时仍可处理输入与按钮
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("build_panel")

	# 建立模块名 -> 按钮映射，并设为同组互斥的开关按钮（高亮当前模块）
	_module_buttons = {
		"overview": _overview_button,
		"primary_attack": _primary_attack_button,
		"skill_slot": _skill_slot_button,
		"school": _school_button,
		"boon": _boon_button,
	}
	var group := ButtonGroup.new()
	for module_name in _module_buttons:
		var btn: Button = _module_buttons[module_name]
		btn.toggle_mode = true
		btn.button_group = group
		# 关闭键盘焦点：避免 Tab 在面板内切换按钮焦点（鼠标点击不受影响）
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(switch_module.bind(module_name))

	# 延迟一帧连接玩家
	_connect_player.call_deferred()


## 统一处理 Tab / ESC。
## 用 _input（而非 _unhandled_input）拦截：Tab 默认绑定 ui_focus_next，
## 会在 GUI 焦点导航阶段被消费，早于 _unhandled_input；在 _input 中提前
## 标记已处理，才能阻止 Tab 切换按钮焦点。
func _input(event: InputEvent) -> void:
	# Tab：开关构筑页（机缘面板打开时不开）
	if event.is_action_pressed("open_build_panel"):
		toggle_panel()
		get_viewport().set_input_as_handled()
		return
	# ESC：仅在构筑页打开时关闭
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


# ===== 玩家连接 =====

## 查找玩家并连接状态信号
func _connect_player() -> void:
	set_player(get_tree().get_first_node_in_group("player"))


## 设置目标玩家并连接其状态变化信号
func set_player(player_node: Node) -> void:
	_player = player_node
	if _player != null and _player.has_signal("stats_changed"):
		if not _player.stats_changed.is_connected(_on_stats_changed):
			_player.stats_changed.connect(_on_stats_changed)


## 玩家状态变化时，若构筑页可见则刷新当前模块
func _on_stats_changed() -> void:
	if visible:
		refresh()


# ===== 开关与暂停 =====

## 切换显隐
func toggle_panel() -> void:
	if visible:
		close_panel()
	elif not _is_boon_panel_open():
		# 机缘三选一打开时不允许打开构筑页
		open_panel()


## 打开：默认显示角色总览，并暂停游戏
func open_panel() -> void:
	if _player == null:
		_connect_player()
	visible = true
	get_tree().paused = true
	switch_module("overview")


## 关闭：若没有其它阻塞性 UI（机缘三选一）打开，则恢复游戏
func close_panel() -> void:
	visible = false
	if not _is_boon_panel_open():
		get_tree().paused = false


## 机缘选择面板是否打开
func _is_boon_panel_open() -> bool:
	# 机缘面板或事件选择面板打开时，均视为阻塞（Tab 不开构筑页 / 关闭时保持暂停）
	for group_name in ["boon_choice_panel", "event_choice_panel"]:
		var panel: Node = get_tree().get_first_node_in_group(group_name)
		if panel != null and panel.visible:
			return true
	return false


# ===== 模块切换 =====

## 切换到指定模块并重建右侧内容
func switch_module(module_name: String) -> void:
	current_module = module_name
	# 高亮当前模块按钮（同组开关，自动取消其它按钮）
	if _module_buttons.has(module_name):
		_module_buttons[module_name].button_pressed = true
	refresh()


## 刷新当前模块（清空右侧并按 current_module 重建）
func refresh() -> void:
	if not visible:
		return
	if not is_instance_valid(_player) or not _player.has_method("get_build_data"):
		return
	clear_content()
	match current_module:
		"primary_attack":
			show_primary_attack_module()
		"skill_slot":
			show_skill_slot_module()
		"school":
			show_school_module()
		"boon":
			show_boon_module()
		_:
			show_overview_module()


## 清空右侧内容容器（立即移除，避免与新内容重叠）
func clear_content() -> void:
	for child in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()


# ===== 模块一：角色总览 =====

func show_overview_module() -> void:
	var preview: Dictionary = _player.get_combat_preview_data()
	var sword_root: int = preview.get("sword_root", 0)
	var poison_root: int = preview.get("poison_root", 0)
	var beast_root: int = preview.get("beast_root", 0)

	_add_heading("灵根")
	_add_text("剑灵根：%d" % sword_root)
	_add_text("毒灵根：%d" % poison_root)
	_add_text("兽灵根：%d" % beast_root)
	_add_text("总和：%d" % (sword_root + poison_root + beast_root))

	_add_heading("战斗数值预览")
	_add_text("剑气伤害：%d" % preview.get("sword_damage", 0))
	_add_text("毒伤基础：%d" % preview.get("poison_damage", 0))
	_add_text("灵狼血量：%d" % preview.get("wolf_max_hp", 0))
	_add_text("灵狼攻击：%d" % preview.get("wolf_damage", 0))
	_add_text("驭兽鞭伤害：%d" % preview.get("beast_whip_damage", 0))

	_add_heading("当前基础攻击")
	_add_text(preview.get("primary_attack_name", "-"))

	_add_heading("当前技能栏")
	var slots: Dictionary = preview.get("skill_slots_display", {})
	for key in ["Q", "E", "F"]:
		_add_text("%s：%s" % [key, slots.get(key, "空")])


# ===== 模块二：基础攻击 =====

func show_primary_attack_module() -> void:
	var data: Dictionary = _player.get_build_data()
	var preview: Dictionary = _player.get_combat_preview_data()
	var current_attack: String = data["primary_attack_type"]

	_add_heading("当前基础攻击")
	_add_text(_player.get_primary_attack_display_name(current_attack))

	_add_heading("说明")
	_add_text(preview.get("primary_attack_description", ""))

	_add_heading("已解锁基础攻击")
	var unlocked: Array = data["unlocked_primary_attacks"]
	# 固定展示三种基础攻击：未解锁的按钮置灰不可点击
	for attack_id in ["sword_qi", "poison_dart", "beast_whip"]:
		var is_unlocked: bool = attack_id in unlocked
		var button := Button.new()
		var label: String = _player.get_primary_attack_display_name(attack_id)
		if attack_id == current_attack:
			label += "（当前）"
		elif not is_unlocked:
			label += "（未解锁）"
		button.text = label
		button.disabled = not is_unlocked
		button.focus_mode = Control.FOCUS_NONE
		if is_unlocked:
			# 调用玩家方法切换基础攻击（仅切换已解锁项）
			button.pressed.connect(_player.set_primary_attack.bind(attack_id))
		_content_container.add_child(button)


# ===== 模块三：技能栏 =====

func show_skill_slot_module() -> void:
	var data: Dictionary = _player.get_build_data()
	var preview: Dictionary = _player.get_combat_preview_data()
	var slots_display: Dictionary = preview.get("skill_slots_display", {})

	_add_heading("当前技能栏")
	for key in ["Q", "E", "F"]:
		_add_text("%s：%s" % [key, slots_display.get(key, "空")])

	_add_heading("已解锁技能")
	var unlocked_skills: Array = data["unlocked_skills"]
	if unlocked_skills.is_empty():
		_add_text("暂无已解锁技能")
		return
	# 逐个技能：名称 + 说明 + 装备到 Q/E/F 按钮
	for skill_id in unlocked_skills:
		_add_text("%s：%s" % [
			_player.get_skill_display_name(skill_id),
			_player.get_skill_description(skill_id),
		])
		var row := HBoxContainer.new()
		for slot_key in ["Q", "E", "F"]:
			var button := Button.new()
			button.text = "装备到 " + slot_key
			button.focus_mode = Control.FOCUS_NONE
			# 调用玩家方法装备技能（同一技能不会占多个键位，由玩家方法保证）
			button.pressed.connect(_player.equip_skill_to_slot.bind(skill_id, slot_key))
			row.add_child(button)
		_content_container.add_child(row)


# ===== 模块四：流派专精 =====

func show_school_module() -> void:
	var data: Dictionary = _player.get_build_data()
	var sc: Dictionary = data["school_counts"]

	_add_heading("流派数量")
	_add_text("剑气：%d" % sc.get("sword", 0))
	_add_text("御兽：%d" % sc.get("beast", 0))
	_add_text("毒蛊：%d" % sc.get("poison", 0))

	_add_heading("已激活专精")
	var specs: Array = data["active_specialization_names"]
	if specs.is_empty():
		_add_text("暂无专精")
	else:
		for spec_name in specs:
			_add_text("· %s" % spec_name)

	_add_heading("流派说明")
	_add_text("剑气流：强化剑气伤害、穿透和斩杀。")
	_add_text("御兽流：强化灵狼数量、伤害、生存与协同。")
	_add_text("毒蛊流：强化毒伤、叠毒和毒爆。")


# ===== 模块五：已获机缘 =====

func show_boon_module() -> void:
	var data: Dictionary = _player.get_build_data()
	var records: Array = data["acquired_boon_records"]

	_add_heading("已获得机缘")
	if records.is_empty():
		_add_text("暂无机缘")
		return
	for record in records:
		# 标题行按品阶颜色显示
		var color := Color(record.get("grade_color", DEFAULT_COLOR))
		_add_text(_format_record(record), color)
		var desc: String = record.get("description", "")
		if desc != "":
			_add_text("描述：%s" % desc)


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


# ===== 内容构建辅助 =====

## 添加一行普通文本（自动换行、可选颜色），返回该 Label
func _add_text(text: String, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	_content_container.add_child(label)
	return label


## 添加一行小标题（带空行分隔感，使用淡色）
func _add_heading(text: String) -> Label:
	var label := _add_text("【%s】" % text, Color(0.7, 0.85, 1.0))
	return label
