extends RefCounted
class_name BoonManager
## 机缘管理器
## M1 任务 6/7 + M2-3 —— 内置机缘数据并提供带权重的随机抽取。
## 仅负责数据与抽取，不负责效果应用（效果由玩家 apply_boon 处理）。
##
## 每个机缘为一个 Dictionary，字段：
##   id            机缘唯一标识
##   boon_name     机缘名称（显示）
##   description   简短描述
##   school_tags   所属流派标签（sword / beast / poison）
##   effect_type   效果类型
##   effect_value  效果数值
##   prerequisites 前置机缘 id 列表，需全部已获得才会出现
##   rarity        稀有度：common / rare / epic
##   base_weight   基础权重（common=100 / rare=45 / epic=15）
##   max_stacks    最大可叠加次数（不可重复为 1）
##   current_stacks 占位字段，实际叠加次数由玩家 acquired_boon_counts 计算

## 基础机缘（未获得时提高出现权重）
const BASE_BOONS: Array[String] = ["sword_qi_basic", "beast_summon_wolf", "poison_mist"]

## 机缘品阶定义（按概率抽取，倍率不超过 1.38）
const GRADES: Array[Dictionary] = [
	{"id": "fan", "name": "凡品", "color_name": "white", "color": "#FFFFFF", "probability": 55, "multiplier": 1.00},
	{"id": "huang", "name": "黄品", "color_name": "green", "color": "#58D66D", "probability": 25, "multiplier": 1.08},
	{"id": "xuan", "name": "玄品", "color_name": "blue", "color": "#4AA3FF", "probability": 13, "multiplier": 1.16},
	{"id": "di", "name": "地品", "color_name": "purple", "color": "#B065FF", "probability": 5, "multiplier": 1.25},
	{"id": "tian", "name": "天品", "color_name": "red", "color": "#FF4B4B", "probability": 2, "multiplier": 1.38},
]

## 机缘星级定义（1-5 星，倍率不超过 1.38）
const STAR_TIERS: Array[Dictionary] = [
	{"stars": 1, "probability": 40, "multiplier": 1.00},
	{"stars": 2, "probability": 28, "multiplier": 1.08},
	{"stars": 3, "probability": 18, "multiplier": 1.16},
	{"stars": 4, "probability": 10, "multiplier": 1.26},
	{"stars": 5, "probability": 4, "multiplier": 1.38},
]


## 按概率随机返回一个品阶 Dictionary
func roll_grade() -> Dictionary:
	return _pick_by_probability(GRADES)


## 按概率随机返回一个星级 Dictionary
func roll_stars() -> Dictionary:
	return _pick_by_probability(STAR_TIERS)


## 按各项 probability 加权随机选择一个条目
func _pick_by_probability(tiers: Array) -> Dictionary:
	var total: float = 0.0
	for tier in tiers:
		total += float(tier["probability"])
	var r: float = randf() * total
	var acc: float = 0.0
	for tier in tiers:
		acc += float(tier["probability"])
		if r <= acc:
			return tier
	return tiers[tiers.size() - 1]


## 返回全部 18 个机缘数据（每次返回新数组，避免外部修改污染）
func get_all_boons() -> Array[Dictionary]:
	return [
		# ===== 剑气流 =====
		{
			"id": "sword_qi_basic",
			"boon_name": "基础剑气",
			"description": "剑气伤害 +6。",
			"school_tags": ["sword"],
			"effect_type": "sword_damage_bonus",
			"effect_value": 6,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "sword_qi_pierce",
			"boon_name": "剑气穿透",
			"description": "剑气可额外穿透 2 个敌人。",
			"school_tags": ["sword"],
			"effect_type": "sword_pierce_bonus",
			"effect_value": 2,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "sword_execute",
			"boon_name": "残血斩杀",
			"description": "斩杀气血低于 20% 的敌人。",
			"school_tags": ["sword"],
			"effect_type": "sword_execute",
			"effect_value": 0.2,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "sword_qi_fast_cast",
			"boon_name": "御剑疾发",
			"description": "剑气攻击冷却减少 0.1 秒。",
			"school_tags": ["sword"],
			"effect_type": "attack_cooldown_bonus",
			"effect_value": -0.1,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "sword_qi_heavy",
			"boon_name": "重剑气",
			"description": "剑气伤害 +10，但攻击冷却 +0.1 秒。",
			"school_tags": ["sword"],
			"effect_type": "sword_heavy",
			"effect_value": 10,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 2,
			"current_stacks": 0,
		},
		{
			"id": "sword_qi_wide",
			"boon_name": "剑气扩幅",
			"description": "剑气碰撞范围变宽。",
			"school_tags": ["sword"],
			"effect_type": "sword_width_bonus",
			"effect_value": 1,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 2,
			"current_stacks": 0,
		},
		# ===== 御兽流 =====
		{
			"id": "beast_summon_wolf",
			"boon_name": "召唤灵狼",
			"description": "召唤一只灵狼协助攻击妖兽。",
			"school_tags": ["beast"],
			"effect_type": "summon_wolf",
			"effect_value": 1,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "beast_attack_speed",
			"boon_name": "灵兽攻速提升",
			"description": "所有灵兽攻击速度提升 30%。",
			"school_tags": ["beast"],
			"effect_type": "beast_attack_speed",
			"effect_value": 0.3,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "beast_guard",
			"boon_name": "灵兽护主",
			"description": "拥有灵兽时，玩家受到的部分伤害由灵兽分担。",
			"school_tags": ["beast"],
			"effect_type": "beast_guard",
			"effect_value": 0.4,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "beast_wolf_damage",
			"boon_name": "灵狼利爪",
			"description": "灵狼伤害 +4。",
			"school_tags": ["beast"],
			"effect_type": "wolf_damage_bonus",
			"effect_value": 4,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "beast_wolf_speed",
			"boon_name": "灵狼迅捷",
			"description": "灵狼移动速度 +20%。",
			"school_tags": ["beast"],
			"effect_type": "wolf_move_speed_bonus",
			"effect_value": 0.2,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "beast_extra_wolf",
			"boon_name": "双狼同行",
			"description": "额外召唤一只灵狼。",
			"school_tags": ["beast"],
			"effect_type": "extra_wolf",
			"effect_value": 1,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		# ===== 毒蛊流 =====
		{
			"id": "poison_mist",
			"boon_name": "毒雾",
			"description": "按 Q 在鼠标位置释放毒雾，对范围内妖兽持续造成毒伤。",
			"school_tags": ["poison"],
			"effect_type": "poison_mist",
			"effect_value": 1,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "poison_stack",
			"boon_name": "叠毒",
			"description": "毒伤可叠加层数，最多 5 层。",
			"school_tags": ["poison"],
			"effect_type": "poison_stack",
			"effect_value": 5,
			"prerequisites": ["poison_mist"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "poison_explosion",
			"boon_name": "毒爆",
			"description": "中毒目标死亡时爆开，对附近妖兽造成毒伤。",
			"school_tags": ["poison"],
			"effect_type": "poison_explosion",
			"effect_value": 120,
			"prerequisites": ["poison_mist"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "poison_mist_duration",
			"boon_name": "毒雾延绵",
			"description": "毒雾持续时间 +1 秒。",
			"school_tags": ["poison"],
			"effect_type": "poison_duration_bonus",
			"effect_value": 1.0,
			"prerequisites": ["poison_mist"],
			"rarity": "common",
			"base_weight": 100,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "poison_mist_radius",
			"boon_name": "毒域扩张",
			"description": "毒雾范围扩大。",
			"school_tags": ["poison"],
			"effect_type": "poison_radius_bonus",
			"effect_value": 20,
			"prerequisites": ["poison_mist"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "poison_corrosion",
			"boon_name": "蚀骨毒",
			"description": "毒雾每跳额外伤害 +2。",
			"school_tags": ["poison"],
			"effect_type": "poison_damage_bonus",
			"effect_value": 2,
			"prerequisites": ["poison_mist"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
		},
	]


## 带权重的随机抽取（M2-3B：所有机缘只能获得一次）
## acquired_boon_ids：玩家已获得机缘 id 列表
## school_counts：各流派已获得数量 { sword/beast/poison -> count }
## count：期望抽取数量（可选机缘不足时返回实际数量）
func roll_boons(acquired_boon_ids: Array, school_counts: Dictionary, count: int = 3) -> Array:
	# 收集候选：未获得过 + 满足前置
	var candidates: Array = []
	for boon in get_all_boons():
		# 已获得过的机缘不再出现（机缘唯一获得）
		if boon["id"] in acquired_boon_ids:
			continue
		if not _prerequisites_met(boon, acquired_boon_ids):
			continue
		candidates.append({
			"boon": boon,
			"weight": _compute_weight(boon, acquired_boon_ids, school_counts),
		})

	# 加权不放回抽取，保证不重复、不死循环
	var result: Array = []
	var amount: int = min(count, candidates.size())
	for _i in amount:
		var idx: int = _weighted_pick(candidates)
		var boon: Dictionary = candidates[idx]["boon"]
		# 为本次出现的机缘附加临时品阶 / 星级数据
		_attach_quality(boon)
		result.append(boon)
		candidates.remove_at(idx)
	return result


## 为机缘附加品阶 / 星级 / 倍率 / 最终数值字段（不修改原始 effect_value）
## M2-3A：每次出现随机品质；M2-3B 再做“选择后锁定品质”
func _attach_quality(boon: Dictionary) -> void:
	var grade: Dictionary = roll_grade()
	var star: Dictionary = roll_stars()
	var final_multiplier: float = float(grade["multiplier"]) * float(star["multiplier"])

	boon["grade_id"] = grade["id"]
	boon["grade_name"] = grade["name"]
	boon["grade_color"] = grade["color"]
	boon["grade_multiplier"] = grade["multiplier"]
	boon["stars"] = star["stars"]
	boon["star_text"] = "★".repeat(int(star["stars"]))
	boon["star_multiplier"] = star["multiplier"]
	boon["final_multiplier"] = final_multiplier
	boon["final_effect_value"] = _compute_final_value(boon.get("effect_value", 0), final_multiplier)


## 根据当前品阶 id 返回下一个品阶；已是天品则返回天品本身
func get_next_grade(current_grade_id: String) -> Dictionary:
	var index: int = -1
	for i in GRADES.size():
		if GRADES[i]["id"] == current_grade_id:
			index = i
			break
	# 未找到则返回最低品阶兜底
	if index == -1:
		return GRADES[0]
	# 已是最高品阶（天品）则保持
	if index >= GRADES.size() - 1:
		return GRADES[index]
	return GRADES[index + 1]


## 根据当前 grade_multiplier 与 star_multiplier 重算最终倍率与最终数值
func recalculate_boon_quality(boon: Dictionary) -> Dictionary:
	var grade_multiplier: float = float(boon.get("grade_multiplier", 1.0))
	var star_multiplier: float = float(boon.get("star_multiplier", 1.0))
	var final_multiplier: float = grade_multiplier * star_multiplier
	boon["final_multiplier"] = final_multiplier
	boon["final_effect_value"] = _compute_final_value(boon.get("effect_value", 0), final_multiplier)
	return boon


## 将单个机缘的品阶提升一级并重算数值（星级不变）
func upgrade_boon_grade(boon: Dictionary) -> Dictionary:
	var next_grade: Dictionary = get_next_grade(boon.get("grade_id", "fan"))
	boon["grade_id"] = next_grade["id"]
	boon["grade_name"] = next_grade["name"]
	boon["grade_color"] = next_grade["color"]
	boon["grade_multiplier"] = next_grade["multiplier"]
	return recalculate_boon_quality(boon)


## 计算最终数值：int 取整、float 保留两位小数、非数字原样返回
func _compute_final_value(base_value, final_multiplier: float):
	if base_value is int:
		return int(round(base_value * final_multiplier))
	elif base_value is float:
		return snappedf(base_value * final_multiplier, 0.01)
	else:
		return base_value


## 前置条件是否全部满足（前置机缘需已在 acquired_boon_ids 中）
func _prerequisites_met(boon: Dictionary, acquired_boon_ids: Array) -> bool:
	for prereq in boon.get("prerequisites", []):
		if not prereq in acquired_boon_ids:
			return false
	return true


## 计算机缘权重
func _compute_weight(boon: Dictionary, acquired_boon_ids: Array, school_counts: Dictionary) -> float:
	var weight: float = float(boon.get("base_weight", 100))
	var id: String = boon["id"]

	# 基础机缘未获得时大幅提高权重
	if id in BASE_BOONS and not id in acquired_boon_ids:
		weight *= 3.0

	# 流派倾向：所属流派数量 >= 2 时权重 +50%
	for tag in boon.get("school_tags", []):
		if int(school_counts.get(tag, 0)) >= 2:
			weight *= 1.5
			break

	return weight


## 按权重从候选中挑选一个，返回索引
func _weighted_pick(candidates: Array) -> int:
	var total: float = 0.0
	for entry in candidates:
		total += entry["weight"]
	# 防御：总权重无效时退回首个
	if total <= 0.0:
		return 0
	var r: float = randf() * total
	var acc: float = 0.0
	for i in candidates.size():
		acc += candidates[i]["weight"]
		if r <= acc:
			return i
	return candidates.size() - 1
