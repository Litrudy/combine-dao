extends RefCounted
class_name BoonManager
## 机缘管理器
## M1 任务 6 / 7 —— 内置机缘数据并提供随机抽取。
## 仅负责数据与抽取，不负责效果应用（效果由玩家 apply_boon 处理）。
##
## 每个机缘为一个 Dictionary，字段：
##   id            机缘唯一标识
##   boon_name     机缘名称（用于显示）
##   description   简短描述
##   school_tags   所属流派标签（剑气流 / 御兽 / 毒蛊）
##   effect_type   效果类型（玩家据此修改属性）
##   effect_value  效果数值
##   prerequisites 前置机缘 id 列表，需全部已获得才会出现


## 返回 M1 全部 9 个机缘数据（每次返回新数组，避免外部修改污染）
func get_all_boons() -> Array[Dictionary]:
	return [
		# ===== 剑气流 =====
		{
			"id": "sword_qi_basic",
			"boon_name": "基础剑气",
			"description": "剑气伤害 +6。",
			"school_tags": ["剑气流"],
			"effect_type": "sword_damage_bonus",
			"effect_value": 6,
			"prerequisites": [],
		},
		{
			"id": "sword_qi_pierce",
			"boon_name": "剑气穿透",
			"description": "剑气可额外穿透 2 个敌人。",
			"school_tags": ["剑气流"],
			"effect_type": "sword_pierce_bonus",
			"effect_value": 2,
			"prerequisites": ["sword_qi_basic"],
		},
		{
			"id": "sword_execute",
			"boon_name": "残血斩杀",
			"description": "斩杀气血低于 20% 的敌人。",
			"school_tags": ["剑气流"],
			"effect_type": "sword_execute",
			"effect_value": 0.2,
			"prerequisites": ["sword_qi_basic"],
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
		},
		{
			"id": "beast_attack_speed",
			"boon_name": "灵兽攻速提升",
			"description": "所有灵兽攻击速度提升 30%。",
			"school_tags": ["beast"],
			"effect_type": "beast_attack_speed",
			"effect_value": 0.3,
			"prerequisites": ["beast_summon_wolf"],
		},
		{
			"id": "beast_guard",
			"boon_name": "灵兽护主",
			"description": "拥有灵兽时，玩家受到的部分伤害由灵兽分担。",
			"school_tags": ["beast"],
			"effect_type": "beast_guard",
			"effect_value": 0.4,
			"prerequisites": ["beast_summon_wolf"],
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
		},
		{
			"id": "poison_stack",
			"boon_name": "叠毒",
			"description": "毒伤可叠加层数，最多 5 层。",
			"school_tags": ["poison"],
			"effect_type": "poison_stack",
			"effect_value": 5,
			"prerequisites": ["poison_mist"],
		},
		{
			"id": "poison_explosion",
			"boon_name": "毒爆",
			"description": "中毒目标死亡时爆开，对附近妖兽造成毒伤。",
			"school_tags": ["poison"],
			"effect_type": "poison_explosion",
			"effect_value": 120,
			"prerequisites": ["poison_mist"],
		},
	]


## 根据玩家已获得的机缘，从「未获得且前置满足」的机缘中随机抽取
## acquired_boon_ids：玩家已获得的机缘 id 列表
## count：期望抽取数量（可选机缘不足时返回实际数量）
func roll_boons(acquired_boon_ids: Array[String], count: int = 3) -> Array:
	var available: Array[Dictionary] = []
	for boon in get_all_boons():
		var id: String = boon.get("id", "")
		# 已获得过的机缘不再出现
		if id in acquired_boon_ids:
			continue
		# 前置条件未全部满足则跳过
		if not _prerequisites_met(boon, acquired_boon_ids):
			continue
		available.append(boon)

	# 洗牌后取前 count 个，天然保证不重复
	available.shuffle()
	var amount: int = min(count, available.size())
	return available.slice(0, amount)


## 判断机缘的前置条件是否全部满足
func _prerequisites_met(boon: Dictionary, acquired_boon_ids: Array[String]) -> bool:
	var prerequisites: Array = boon.get("prerequisites", [])
	for prereq in prerequisites:
		if not prereq in acquired_boon_ids:
			return false
	return true
