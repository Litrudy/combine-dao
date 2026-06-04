extends CharacterBody2D

## 修士（玩家）移动脚本
## M1 任务 1 —— 仅实现俯视角 WASD 移动，不含战斗 / 升级 / 机缘等系统。

## 玩家状态变化时发出（修为 / 突破 / 机缘 / 气血变化），供 HUD 刷新
signal stats_changed

@export var speed: float = 200.0
@export var max_qi_blood: int = 100
@export var max_mana: int = 50

## 剑气攻击冷却（秒）
@export var attack_cooldown: float = 0.4

## 剑气场景，释放时实例化
const SwordQiScene: PackedScene = preload("res://scenes/player/sword_qi.tscn")
## 灵狼场景，召唤时实例化
const SPIRIT_WOLF_SCENE: PackedScene = preload("res://scenes/ally/spirit_wolf.tscn")
## 毒雾场景，释放时实例化
const POISON_MIST_SCENE: PackedScene = preload("res://scenes/player/poison_mist.tscn")
## 毒镖 / 驭兽鞭场景（基础攻击替换）
const POISON_DART_SCENE: PackedScene = preload("res://scenes/player/poison_dart.tscn")
const BEAST_WHIP_SCENE: PackedScene = preload("res://scenes/player/beast_whip.tscn")

var qi_blood: int
var mana: int

## ===== 灵根（开局随机，总和为 10，每项至少 1）=====
var sword_root: int = 1
var poison_root: int = 1
var beast_root: int = 1

## ===== 技能栏系统 =====
## 已解锁的基础攻击（左键）
var unlocked_primary_attacks: Array[String] = ["sword_qi"]
## 已解锁的主动技能 id
var unlocked_skills: Array[String] = []
## 技能槽位绑定（Q / E / F -> 技能 id，空字符串表示空）
var skill_slots: Dictionary = {
	"Q": "",
	"E": "",
	"F": "",
}

## 技能 id -> 显示名
const SKILL_NAMES: Dictionary = {
	"poison_mist": "毒雾",
	"summon_wolf": "召唤灵狼",
}
## 基础攻击 id -> 显示名
const PRIMARY_ATTACK_NAMES: Dictionary = {
	"sword_qi": "剑气",
	"poison_dart": "毒镖",
	"beast_whip": "驭兽鞭",
}

## 当前修为
var cultivation_exp: int = 0
## 突破所需修为
var cultivation_exp_required: int = 3
## 修炼层数
var cultivation_level: int = 1
## 已获得的机缘 id 列表（机缘唯一获得，用于去重与前置筛选）
var acquired_boon_ids: Array[String] = []
## 已获得机缘的完整记录（含品阶 / 星级 / 最终数值，供 HUD 显示）
var acquired_boon_records: Array[Dictionary] = []

## 天道石（局内构筑资源，用于刷新机缘与提升品阶）
var heavenly_stones: int = 5

## 各流派已获得机缘数量
var school_counts: Dictionary = {
	"sword": 0,
	"beast": 0,
	"poison": 0,
}
## 已激活的专精 id 列表（每个专精只触发一次）
var active_specializations: Array[String] = []

## 专精 id -> 名称映射（用于 HUD 显示）
const SPECIALIZATION_NAMES: Dictionary = {
	"sword_2": "剑意初成",
	"sword_3": "剑心通明",
	"beast_2": "御兽协同",
	"beast_3": "万兽同心",
	"poison_2": "毒蛊入体",
	"poison_3": "万毒扩散",
}

## 剑气流：剑气伤害加成（由机缘累加）
var sword_damage_bonus: int = 0
## 剑气流：剑气额外穿透次数
var sword_pierce_bonus: int = 0
## 剑气流：是否启用残血斩杀
var sword_execute_enabled: bool = false
## 剑气流：斩杀气血阈值（专精「剑心通明」可提升到 0.3）
var sword_execute_threshold: float = 0.2
## 剑气流：剑气宽度加成（机缘「剑气扩幅」）
var sword_width_bonus: int = 0

## 御兽流：已召唤的灵狼列表
var summoned_wolves: Array[Node] = []
## 御兽流：灵兽攻速倍率
var beast_attack_speed_multiplier: float = 1.0
## 御兽流：灵狼伤害加成（机缘「灵狼利爪」）
var wolf_damage_bonus: int = 0
## 御兽流：灵狼移速倍率（机缘「灵狼迅捷」/ 专精「御兽协同」）
var wolf_move_speed_multiplier: float = 1.0
## 基础攻击类型：sword_qi（剑气）/ poison_dart（毒镖）/ beast_whip（驭兽鞭）
var primary_attack_type: String = "sword_qi"
## 是否已解锁毒镖 / 驭兽鞭
var poison_dart_unlocked: bool = false
var beast_whip_unlocked: bool = false

## 御兽流：是否已解锁灵狼召唤
var wolf_unlocked: bool = false
## 御兽流：最大同时存活灵狼数量
var max_wolf_count: int = 1
## 御兽流：E 键召唤冷却（秒）与剩余冷却时间
var wolf_summon_cooldown: float = 5.0
var wolf_summon_timer: float = 0.0
## 灵狼基础伤害 / 基础移速（用于重算加成）
const WOLF_BASE_DAMAGE: int = 8
const WOLF_BASE_MOVE_SPEED: float = 140.0
## 御兽流：是否启用灵兽护主
var beast_guard_enabled: bool = false
## 御兽流：灵兽护主减伤比例（40%）
var beast_guard_ratio: float = 0.4

## 毒蛊流：是否解锁毒雾（Q 释放）
var poison_mist_unlocked: bool = false
## 毒蛊流：是否启用叠毒
var poison_stack_enabled: bool = false
## 毒蛊流：是否启用毒爆
var poison_explosion_enabled: bool = false
## 毒蛊流：毒伤加成
var poison_damage_bonus: int = 0
## 毒蛊流：叠毒最大层数
var poison_max_stack: int = 1
## 毒蛊流：毒爆范围加成（专精「万毒扩散」）
var poison_explosion_radius_bonus: int = 0
## 毒蛊流：毒爆伤害加成（专精「万毒扩散」）
var poison_explosion_damage_bonus: int = 0
## 毒蛊流：毒雾持续时间加成（机缘「毒雾延绵」）
var poison_duration_bonus: float = 0.0
## 毒蛊流：毒雾范围加成（机缘「毒域扩张」）
var poison_radius_bonus: int = 0
## 毒雾释放冷却（秒）
@export var poison_cast_cooldown: float = 3.0

## 攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0
## 毒雾释放冷却剩余时间，<=0 时可再次释放
var _poison_cast_timer: float = 0.0
## 是否正在选择机缘（期间禁止移动与攻击）
var _choosing_boon: bool = false

## 机缘管理器，负责抽取机缘
var _boon_manager := BoonManager.new()
## 机缘选择面板（运行时从分组查找）
var _boon_panel: Node = null

## 气血组件（子节点 Vitals），负责气血、受伤、治疗与死亡
@onready var vitals: Vitals = $Vitals


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	qi_blood = max_qi_blood
	mana = max_mana

	# 随机生成灵根
	_init_spiritual_roots()


## 随机生成三种灵根：各保底 1 点，剩余 7 点随机分配，总和为 10
func _init_spiritual_roots() -> void:
	sword_root = 1
	poison_root = 1
	beast_root = 1
	var roots: Array[String] = ["sword", "poison", "beast"]
	for _i in 7:
		match roots[randi() % roots.size()]:
			"sword":
				sword_root += 1
			"poison":
				poison_root += 1
			"beast":
				beast_root += 1
	print("剑灵根：", sword_root, "，毒灵根：", poison_root, "，兽灵根：", beast_root)

	# 连接气血组件的三个信号
	vitals.damaged.connect(_on_vitals_damaged)
	vitals.healed.connect(_on_vitals_healed)
	vitals.died.connect(_on_vitals_died)

	# 延迟一帧连接机缘面板，确保面板已进入场景树并加入分组
	_connect_boon_panel.call_deferred()


func _physics_process(delta: float) -> void:
	# 攻击冷却递减
	if _attack_timer > 0.0:
		_attack_timer -= delta
	# 毒雾冷却递减
	if _poison_cast_timer > 0.0:
		_poison_cast_timer -= delta
	# 灵狼召唤冷却递减
	if wolf_summon_timer > 0.0:
		wolf_summon_timer -= delta

	# 选择机缘 / 构筑页打开期间禁止移动
	if _choosing_boon or _is_build_panel_open():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	velocity = direction * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# Tab：切换构筑页（机缘选择面板打开时不允许打开）
	if event.is_action_pressed("open_build_panel"):
		if not _choosing_boon:
			_toggle_build_panel()
		return

	# 选择机缘 / 构筑页 / 通关页 打开期间禁止其他操作
	if _choosing_boon or _is_build_panel_open() or _is_run_cleared():
		return

	# 鼠标左键（attack_primary）：基础攻击
	if event.is_action_pressed("attack_primary"):
		cast_primary_attack()
		return

	# R 键（breakthrough）：可突破时弹出机缘三选一
	if event.is_action_pressed("breakthrough"):
		try_breakthrough()
		return

	# Q / E / F：释放对应技能栏技能
	if event.is_action_pressed("skill_q"):
		cast_skill_from_slot("Q")
		return
	if event.is_action_pressed("skill_e"):
		cast_skill_from_slot("E")
		return
	if event.is_action_pressed("skill_f"):
		cast_skill_from_slot("F")
		return

	# ===== 临时调试输入：K 受伤 10 点，H 回血 10 点 =====
	# TODO: M1 调试用，正式战斗系统接入后移除
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_K:
				vitals.take_damage(10)
			KEY_H:
				vitals.heal(10)


## 基础攻击（鼠标左键）：根据 primary_attack_type 分发，受冷却与状态限制
func cast_primary_attack() -> void:
	# 通关后禁止攻击
	if _is_run_cleared():
		return
	# 冷却未结束则不攻击
	if _attack_timer > 0.0:
		return

	# 方向：玩家当前位置 → 鼠标世界坐标
	var direction: Vector2 = (get_global_mouse_position() - global_position).normalized()
	# 若鼠标恰好与玩家重合导致方向为零，则跳过本次攻击
	if direction == Vector2.ZERO:
		return

	# 按基础攻击类型分发
	match primary_attack_type:
		"poison_dart":
			cast_poison_dart(direction)
		"beast_whip":
			cast_beast_whip(direction)
		_:
			cast_sword_qi(direction)

	# 重置冷却
	_attack_timer = attack_cooldown


## 释放剑气（默认基础攻击）
func cast_sword_qi(direction: Vector2) -> void:
	var sword_qi := SwordQiScene.instantiate()
	sword_qi.global_position = global_position
	sword_qi.direction = direction
	# 剑气伤害由剑灵根驱动（含机缘加成）
	sword_qi.damage = get_sword_damage()
	sword_qi.pierce_remaining = sword_pierce_bonus
	sword_qi.execute_enabled = sword_execute_enabled
	sword_qi.execute_threshold = sword_execute_threshold
	sword_qi.width_bonus = sword_width_bonus
	# 添加到场景树（挂到父节点下，使剑气独立于玩家移动）
	get_parent().add_child(sword_qi)


## 释放毒镖（毒蛊基础攻击）
func cast_poison_dart(direction: Vector2) -> void:
	var dart := POISON_DART_SCENE.instantiate()
	dart.global_position = global_position
	dart.direction = direction
	# 毒镖直接伤害保持较低（自身默认值），毒伤由毒灵根驱动
	dart.poison_tick_damage = get_poison_damage()
	# 毒层上限取毒镖自身默认值与玩家叠毒上限的较大者
	dart.poison_max_stack = max(dart.poison_max_stack, poison_max_stack)
	get_parent().add_child(dart)


## 释放驭兽鞭（御兽基础攻击）
func cast_beast_whip(direction: Vector2) -> void:
	var whip := BEAST_WHIP_SCENE.instantiate()
	whip.global_position = global_position
	whip.direction = direction
	# 驭兽鞭自身伤害由兽灵根驱动（主要价值是驭兽标记）
	whip.damage = get_beast_whip_damage()
	get_parent().add_child(whip)


# ===== 灵根驱动的基础数值 =====

## 剑气最终伤害 = round(剑灵根 * 1.0) + 剑气伤害加成
func get_sword_damage() -> int:
	return int(round(sword_root * 1.0)) + sword_damage_bonus


## 毒伤最终值 = round(毒灵根 * 0.5) + 毒伤加成
func get_poison_damage() -> int:
	return int(round(poison_root * 0.5)) + poison_damage_bonus


## 灵狼最大血量 = round(兽灵根 * 8.0)
func get_wolf_max_hp() -> int:
	return int(round(beast_root * 8.0))


## 灵狼最终攻击 = round(兽灵根 * 1.2) + 灵狼伤害加成
func get_wolf_damage() -> int:
	return int(round(beast_root * 1.2)) + wolf_damage_bonus


## 驭兽鞭自身伤害 = round(兽灵根 * 0.6)
func get_beast_whip_damage() -> int:
	return int(round(beast_root * 0.6))


# ===== 修为 / 突破 / 机缘 =====

## 获得修为（由妖兽死亡等外部来源调用）
func gain_cultivation_exp(amount: int) -> void:
	# 修为可溢出，但最多只能超过当前需求 1 点
	var cap: int = cultivation_exp_required + 1
	cultivation_exp = min(cultivation_exp + amount, cap)
	print("获得修为：", amount, "，当前修为：", cultivation_exp, " / ", cultivation_exp_required)

	# 达到突破条件只提示，不自动弹面板（需玩家按 R）
	if can_breakthrough():
		print("修为已满，按 R 进行突破")

	# 通知 HUD 刷新
	stats_changed.emit()


## 是否处于可突破状态
func can_breakthrough() -> bool:
	return cultivation_exp >= cultivation_exp_required


## 尝试突破（由 R 键触发）：满足条件则弹出机缘三选一
func try_breakthrough() -> void:
	# 正在选择机缘、或修为不足时不触发
	if _choosing_boon or not can_breakthrough():
		return

	# 兜底：若尚未连接面板，再尝试查找一次
	if _boon_panel == null:
		_connect_boon_panel()
	if _boon_panel == null:
		push_warning("未找到机缘选择面板（BoonChoicePanel），无法弹出三选一")
		return

	# 根据已获得机缘（去重）与流派倾向加权筛选可选机缘
	var boons: Array = _boon_manager.roll_boons(acquired_boon_ids, school_counts, 3)
	if boons.is_empty():
		# 没有可选机缘：不卡死游戏，仅提示
		print("当前没有可选机缘")
		return

	# 进入选择状态，封锁移动 / 攻击 / 毒雾 / 再次突破
	_choosing_boon = true
	print("开始突破，选择一项机缘")
	_boon_panel.show_boons(boons)


## 查找并连接机缘选择面板
func _connect_boon_panel() -> void:
	_boon_panel = get_tree().get_first_node_in_group("boon_choice_panel")
	if _boon_panel != null and not _boon_panel.boon_selected.is_connected(_on_boon_selected):
		_boon_panel.boon_selected.connect(_on_boon_selected)


## 机缘被选择后的回调
func _on_boon_selected(boon: Dictionary) -> void:
	var id: String = boon.get("id", "")

	# 机缘唯一获得：已拥有则忽略重复效果（正常流程不会出现，仍做安全判断）
	if id != "" and id in acquired_boon_ids:
		print("机缘已获得，忽略重复效果：", boon.get("boon_name", "?"))
	else:
		# 应用效果（具体效果与提示由 apply_boon 处理）
		apply_boon(boon)
		# 记录已获得机缘 id 与完整记录
		if id != "":
			acquired_boon_ids.append(id)
			acquired_boon_records.append(_make_boon_record(boon))
		# 根据流派标签更新流派计数，并检查专精
		for tag in boon.get("school_tags", []):
			if school_counts.has(tag):
				school_counts[tag] += 1
		check_specializations()

	# 完成突破结算（无论是否重复，玩家本次突破都已完成）
	complete_breakthrough_after_boon_selected()

	# 恢复移动与攻击
	_choosing_boon = false


## 从机缘数据提取需要长期保存的字段（品阶 / 星级 / 最终数值）
func _make_boon_record(boon: Dictionary) -> Dictionary:
	return {
		"id": boon.get("id", ""),
		"boon_name": boon.get("boon_name", "?"),
		"grade_name": boon.get("grade_name", ""),
		"grade_color": boon.get("grade_color", "#FFFFFF"),
		"stars": boon.get("stars", 0),
		"star_text": boon.get("star_text", ""),
		"final_effect_value": boon.get("final_effect_value", boon.get("effect_value", 0)),
	}


## 抽取一组机缘候选（供机缘面板刷新调用，沿用去重 + 前置 + 加权逻辑）
func roll_boon_options(count: int = 3) -> Array:
	return _boon_manager.roll_boons(acquired_boon_ids, school_counts, count)


# ===== 天道石经济 =====

## 获得天道石
func gain_heavenly_stones(amount: int) -> void:
	if amount <= 0:
		return
	heavenly_stones += amount
	print("获得天道石：", amount, "，当前天道石：", heavenly_stones)
	stats_changed.emit()


## 消耗天道石：足够则扣除并返回 true，否则返回 false
func spend_heavenly_stones(amount: int) -> bool:
	if heavenly_stones < amount:
		print("天道石不足")
		return false
	heavenly_stones -= amount
	stats_changed.emit()
	return true


## 选择机缘后完成突破：层数 +1，修为不清零，需求 +3
func complete_breakthrough_after_boon_selected() -> void:
	cultivation_level += 1
	cultivation_exp_required += 3
	print("突破完成，当前修为：", cultivation_exp, " / ", cultivation_exp_required)

	# 完成突破 + 获得机缘，通知 HUD 刷新
	stats_changed.emit()


# ===== 流派专精 =====

## 检查并激活达到阈值的流派专精（每个专精只触发一次）
func check_specializations() -> void:
	# ----- 剑气流 -----
	if school_counts["sword"] >= 2 and not "sword_2" in active_specializations:
		active_specializations.append("sword_2")
		# 剑意初成：剑气伤害额外提升
		sword_damage_bonus += 4
		print("激活专精：剑意初成，剑气伤害额外提升")
	if school_counts["sword"] >= 3 and not "sword_3" in active_specializations:
		active_specializations.append("sword_3")
		# 剑心通明：斩杀阈值提升到 30%（无论是否已有残血斩杀，释放时统一使用此阈值）
		sword_execute_threshold = 0.3
		print("激活专精：剑心通明，斩杀阈值提升至 30%")

	# ----- 御兽流 -----
	if school_counts["beast"] >= 2 and not "beast_2" in active_specializations:
		active_specializations.append("beast_2")
		# 御兽协同：灵兽攻速 +0.2，灵狼移速倍率 +0.2（统一走移速倍率体系）
		beast_attack_speed_multiplier += 0.2
		wolf_move_speed_multiplier += 0.2
		update_wolf_attack_speed()
		update_wolf_move_speed()
		print("激活专精：御兽协同，灵兽行动能力提升")
	if school_counts["beast"] >= 3 and not "beast_3" in active_specializations:
		active_specializations.append("beast_3")
		# 万兽同心：灵狼上限 +1 并额外召唤一只
		max_wolf_count += 1
		summon_spirit_wolf()
		print("激活专精：万兽同心，额外灵狼加入战斗")

	# ----- 毒蛊流 -----
	if school_counts["poison"] >= 2 and not "poison_2" in active_specializations:
		active_specializations.append("poison_2")
		# 毒蛊入体：毒雾伤害提升
		poison_damage_bonus += 1
		print("激活专精：毒蛊入体，毒雾伤害提升")
	if school_counts["poison"] >= 3 and not "poison_3" in active_specializations:
		active_specializations.append("poison_3")
		# 万毒扩散：毒爆范围与伤害提升
		poison_explosion_radius_bonus += 60
		poison_explosion_damage_bonus += 4
		print("激活专精：万毒扩散，毒爆范围与伤害提升")


## 根据机缘 id 应用效果（M2-3A：数值类机缘按 final_effect_value 生效）
func apply_boon(boon: Dictionary) -> void:
	var id: String = boon.get("id", "")
	# 显示用前缀：【品阶】机缘名 星级
	var label: String = _format_boon_label(boon)
	# 实际生效数值：优先用品阶星级加成后的 final_effect_value，回退基础 effect_value
	var fv = boon.get("final_effect_value", boon.get("effect_value", 0))

	match id:
		# ===== 剑气流 =====
		"sword_qi_basic":
			# 基础剑气：剑气伤害加成
			sword_damage_bonus += int(fv)
			print("已获得机缘：", label, "，剑气伤害 +", int(fv))
		"sword_qi_pierce":
			# 剑气穿透：额外穿透次数
			sword_pierce_bonus += int(fv)
			print("已获得机缘：", label, "，穿透次数 +", int(fv))
		"sword_execute":
			# 残血斩杀（解锁型）：不使用倍率
			sword_execute_enabled = true
			print("已获得机缘：", label, "，剑气可斩杀低气血敌人")
		# ===== 御兽流 =====
		"beast_summon_wolf":
			# 召唤灵狼：解锁技能并自动入栏，立即召唤一只作为反馈
			wolf_unlocked = true
			max_wolf_count = max(max_wolf_count, 1)
			unlock_skill("summon_wolf")
			summon_spirit_wolf()
			print("已解锁技能：召唤灵狼")
		"beast_attack_speed":
			# 灵兽攻速提升
			beast_attack_speed_multiplier += float(fv)
			update_wolf_attack_speed()
			print("已获得机缘：", label, "，灵兽攻速 +", float(fv))
		"beast_guard":
			# 灵兽护主（解锁型）：不使用倍率
			beast_guard_enabled = true
			print("已获得机缘：", label, "，灵兽为玩家分担伤害")
		# ===== 毒蛊流 =====
		"poison_mist":
			# 毒雾：解锁技能并自动入栏（不再硬编码 Q）
			poison_mist_unlocked = true
			unlock_skill("poison_mist")
			print("已解锁技能：毒雾")
		"poison_stack":
			# 叠毒（解锁型）：不使用倍率
			poison_stack_enabled = true
			poison_max_stack = 5
			print("已获得机缘：", label, "，毒伤最多叠加 5 层")
		"poison_explosion":
			# 毒爆（解锁型）：不使用倍率
			poison_explosion_enabled = true
			print("已获得机缘：", label, "，中毒目标死亡时扩散毒伤")
		# ===== M2-3 新增：剑气流 =====
		"sword_qi_fast_cast":
			# 御剑疾发：攻击冷却减少（fv 为负值），下限 0.15
			attack_cooldown = max(0.15, attack_cooldown + float(fv))
			print("已获得机缘：", label, "，剑气释放更快")
		"sword_qi_heavy":
			# 重剑气：伤害加成（受倍率），冷却 +0.1（固定惩罚）
			sword_damage_bonus += int(fv)
			attack_cooldown += 0.1
			print("已获得机缘：", label, "，剑气伤害 +", int(fv), " 但释放变慢")
		"sword_qi_wide":
			# 剑气扩幅：剑气宽度加成
			sword_width_bonus += int(fv)
			print("已获得机缘：", label, "，剑气范围变宽")
		# ===== M2-3 新增：御兽流 =====
		"beast_wolf_damage":
			# 灵狼利爪：灵狼伤害加成
			wolf_damage_bonus += int(fv)
			update_wolf_damage()
			print("已获得机缘：", label, "，灵狼伤害 +", int(fv))
		"beast_wolf_speed":
			# 灵狼迅捷：灵狼移速倍率加成
			wolf_move_speed_multiplier += float(fv)
			update_wolf_move_speed()
			print("已获得机缘：", label, "，灵狼速度提升")
		"beast_extra_wolf":
			# 双狼同行：灵狼上限 +1，未达上限则立即额外召唤一只
			max_wolf_count += 1
			summon_spirit_wolf()
			print("已获得机缘：", label, "，灵狼上限 +1")
		# ===== M2-3 新增：毒蛊流 =====
		"poison_mist_duration":
			# 毒雾延绵：持续时间加成
			poison_duration_bonus += float(fv)
			print("已获得机缘：", label, "，毒雾持续时间 +", float(fv))
		"poison_mist_radius":
			# 毒域扩张：范围加成
			poison_radius_bonus += int(fv)
			print("已获得机缘：", label, "，毒雾范围扩大")
		"poison_corrosion":
			# 蚀骨毒：毒雾每跳伤害加成
			poison_damage_bonus += int(fv)
			print("已获得机缘：", label, "，毒雾伤害 +", int(fv))
		# ===== M2-3E 基础攻击替换 =====
		"poison_dart_art":
			# 毒镖术：解锁并切换基础攻击为毒镖
			poison_dart_unlocked = true
			if not "poison_dart" in unlocked_primary_attacks:
				unlocked_primary_attacks.append("poison_dart")
			primary_attack_type = "poison_dart"
			print("基础攻击已替换为毒镖")
		"beast_whip_art":
			# 驭兽鞭：解锁并切换基础攻击为驭兽鞭
			beast_whip_unlocked = true
			if not "beast_whip" in unlocked_primary_attacks:
				unlocked_primary_attacks.append("beast_whip")
			primary_attack_type = "beast_whip"
			print("基础攻击已替换为驭兽鞭")
		_:
			# 未知机缘，兜底提示
			print("已获得机缘：", label, "（效果未实现）")


## 组装机缘显示前缀：【品阶】机缘名 星级（缺字段时安全降级）
func _format_boon_label(boon: Dictionary) -> String:
	var boon_name: String = boon.get("boon_name", "?")
	var grade_name: String = boon.get("grade_name", "")
	var star_text: String = boon.get("star_text", "")
	var result: String = boon_name
	if grade_name != "":
		result = "【%s】%s" % [grade_name, boon_name]
	if star_text != "":
		result += " " + star_text
	return result


# ===== 技能栏系统 =====

## 技能 id -> 显示名
func get_skill_display_name(skill_id: String) -> String:
	return SKILL_NAMES.get(skill_id, skill_id)


## 基础攻击 id -> 显示名
func get_primary_attack_display_name(attack_id: String) -> String:
	return PRIMARY_ATTACK_NAMES.get(attack_id, attack_id)


## 切换当前基础攻击（仅限已解锁，供构筑页调用）
func set_primary_attack(attack_id: String) -> void:
	if attack_id in unlocked_primary_attacks:
		primary_attack_type = attack_id
		stats_changed.emit()


## 解锁一个主动技能，并自动装备到第一个空槽
func unlock_skill(skill_id: String) -> void:
	if skill_id in unlocked_skills:
		return
	unlocked_skills.append(skill_id)
	auto_equip_skill(skill_id)
	stats_changed.emit()


## 自动把技能装备到第一个空槽（Q→E→F），都满则不动
func auto_equip_skill(skill_id: String) -> void:
	# 已装备则不重复
	for key in skill_slots:
		if skill_slots[key] == skill_id:
			return
	for key in ["Q", "E", "F"]:
		if skill_slots[key] == "":
			skill_slots[key] = skill_id
			return


## 手动把技能装备到指定槽位（同一技能不能占多个槽，目标槽位直接覆盖）
func equip_skill_to_slot(skill_id: String, slot_key: String) -> void:
	# 未解锁技能不能装备；槽位非法则忽略
	if not skill_id in unlocked_skills or not skill_slots.has(slot_key):
		return
	# 先从其它槽位移除该技能，避免重复占用
	for key in skill_slots:
		if skill_slots[key] == skill_id:
			skill_slots[key] = ""
	skill_slots[slot_key] = skill_id
	stats_changed.emit()


## 释放某槽位绑定的技能
func cast_skill_from_slot(slot_key: String) -> void:
	var skill_id: String = skill_slots.get(slot_key, "")
	if skill_id == "":
		print("该技能栏为空")
		return
	match skill_id:
		"poison_mist":
			cast_poison_mist()
		"summon_wolf":
			_try_summon_wolf()


# ===== 构筑页（Tab）辅助 =====

## 构筑页是否打开
func _is_build_panel_open() -> bool:
	var panel: Node = get_tree().get_first_node_in_group("build_panel")
	return panel != null and panel.visible


## 切换构筑页显隐
func _toggle_build_panel() -> void:
	var panel: Node = get_tree().get_first_node_in_group("build_panel")
	if panel != null and panel.has_method("toggle"):
		panel.toggle()


# ===== 御兽流 =====

## 手动召唤灵狼（E 键），受解锁 / 状态 / 上限 / 冷却限制
func _try_summon_wolf() -> void:
	# 未解锁、选择机缘中、通关后均不可召唤
	if not wolf_unlocked or _choosing_boon or _is_run_cleared():
		return
	# 冷却未结束
	if wolf_summon_timer > 0.0:
		return
	# 达到上限
	if get_alive_wolf_count() >= max_wolf_count:
		print("灵狼数量已达上限")
		return
	summon_spirit_wolf()
	wolf_summon_timer = wolf_summon_cooldown


## 召唤一只灵狼（受最大数量限制）
func summon_spirit_wolf() -> void:
	# 达到上限则不召唤
	if get_alive_wolf_count() >= max_wolf_count:
		return

	var wolf := SPIRIT_WOLF_SCENE.instantiate()
	# 添加到当前场景（玩家的父节点下）
	get_parent().add_child(wolf)
	# 位置设在玩家附近，带一点随机偏移避免多只重叠
	wolf.global_position = global_position + Vector2(
		randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)
	)
	# 绑定主人
	if wolf.has_method("setup"):
		wolf.setup(self)
	# 记录并按当前各项加成初始化新灵狼
	summoned_wolves.append(wolf)
	# 灵狼血量与攻击由兽灵根驱动
	if wolf.vitals != null:
		wolf.vitals.set_max_qi_blood(get_wolf_max_hp(), true)
	wolf.attack_damage = get_wolf_damage()
	wolf.move_speed = WOLF_BASE_MOVE_SPEED * wolf_move_speed_multiplier
	update_wolf_attack_speed()
	stats_changed.emit()


## 清理已失效的灵狼引用
func _clean_wolves() -> void:
	var alive: Array[Node] = []
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			alive.append(wolf)
	summoned_wolves = alive


## 当前存活灵狼数量
func get_alive_wolf_count() -> int:
	_clean_wolves()
	return summoned_wolves.size()


## 注销灵狼（灵狼死亡时调用）
func unregister_wolf(wolf: Node) -> void:
	summoned_wolves.erase(wolf)
	stats_changed.emit()


## 是否处于通关状态（通关面板显示时禁止召唤）
func _is_run_cleared() -> bool:
	var panel: Node = get_tree().get_first_node_in_group("clear_panel")
	return panel != null and panel.visible


## 把当前攻速倍率同步到所有存活灵狼
func update_wolf_attack_speed() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.attack_speed_multiplier = beast_attack_speed_multiplier


## 把当前伤害加成同步到所有存活灵狼
func update_wolf_damage() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.attack_damage = get_wolf_damage()


## 把当前移速倍率同步到所有存活灵狼
func update_wolf_move_speed() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.move_speed = WOLF_BASE_MOVE_SPEED * wolf_move_speed_multiplier


## 是否还有存活的灵狼
func has_alive_wolf() -> bool:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			return true
	return false


## 玩家统一受伤入口（妖兽攻击经此处理，便于灵兽护主减伤）
func receive_damage(amount: int) -> void:
	var final_damage: int = amount
	# 灵兽护主：拥有存活灵狼时分担部分伤害
	if beast_guard_enabled and has_alive_wolf():
		var reduced: int = int(round(amount * beast_guard_ratio))
		final_damage = amount - reduced
		print("灵兽护主，减免伤害：", reduced)
	vitals.take_damage(final_damage)


# ===== 毒蛊流 =====

## 在鼠标位置释放毒雾（Q 键），受冷却限制
func cast_poison_mist() -> void:
	# 未解锁毒雾则不释放
	if not poison_mist_unlocked:
		return
	# 冷却未结束则不释放
	if _poison_cast_timer > 0.0:
		return

	# 实例化毒雾（先设参数，再入场景，确保 _ready 读到正确的持续时间与范围）
	var mist := POISON_MIST_SCENE.instantiate()
	# 传入当前毒蛊参数（毒伤由毒灵根驱动）
	mist.damage_per_second = get_poison_damage()
	mist.poison_stack_enabled = poison_stack_enabled
	mist.max_poison_stack = poison_max_stack
	mist.poison_explosion_enabled = poison_explosion_enabled
	# 毒爆范围与伤害（含专精「万毒扩散」加成）
	mist.explosion_radius = 120.0 + poison_explosion_radius_bonus
	mist.explosion_damage = 8 + poison_explosion_damage_bonus
	# 持续时间加成（机缘「毒雾延绵」）与范围加成（机缘「毒域扩张」）
	mist.duration += poison_duration_bonus
	mist.radius_bonus = poison_radius_bonus
	# 位置与入场景
	mist.position = get_global_mouse_position()
	get_parent().add_child(mist)

	# 重置冷却
	_poison_cast_timer = poison_cast_cooldown


# ===== 气血组件信号回调 =====

## 受伤时打印剩余气血
func _on_vitals_damaged(_amount: int, current_qi_blood: int) -> void:
	print("受伤，当前气血：", current_qi_blood)
	# 气血变化，通知 HUD 刷新
	stats_changed.emit()


## 治疗时打印当前气血
func _on_vitals_healed(_amount: int, current_qi_blood: int) -> void:
	print("回复，当前气血：", current_qi_blood)
	# 气血变化，通知 HUD 刷新
	stats_changed.emit()


## 死亡时打印提示
func _on_vitals_died() -> void:
	print("修士陨落")


# ===== HUD 数据 =====

## 返回 HUD 需要的数据快照（战斗必要信息）
func get_hud_data() -> Dictionary:
	# 技能槽位显示：{ Q/E/F -> 技能名 或 "空" }
	var skill_slots_display: Dictionary = {}
	for key in ["Q", "E", "F"]:
		var skill_id: String = skill_slots.get(key, "")
		skill_slots_display[key] = get_skill_display_name(skill_id) if skill_id != "" else "空"

	return {
		"current_hp": vitals.get_current_qi_blood(),
		"max_hp": vitals.get_max_qi_blood(),
		"cultivation_exp": cultivation_exp,
		"cultivation_exp_required": cultivation_exp_required,
		"can_breakthrough": can_breakthrough(),
		"heavenly_stones": heavenly_stones,
		"primary_attack_name": get_primary_attack_display_name(primary_attack_type),
		"skill_slots_display": skill_slots_display,
	}


## 返回构筑页（Tab）需要的数据快照
func get_build_data() -> Dictionary:
	# 已激活专精名称列表
	var active_specialization_names: Array[String] = []
	for spec_id in active_specializations:
		active_specialization_names.append(SPECIALIZATION_NAMES.get(spec_id, spec_id))

	return {
		"sword_root": sword_root,
		"poison_root": poison_root,
		"beast_root": beast_root,
		"unlocked_primary_attacks": unlocked_primary_attacks,
		"primary_attack_type": primary_attack_type,
		"unlocked_skills": unlocked_skills,
		"skill_slots": skill_slots,
		"school_counts": school_counts,
		"active_specialization_names": active_specialization_names,
		"acquired_boon_records": acquired_boon_records,
	}
