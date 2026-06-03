extends RefCounted
class_name BoonManager
## 机缘管理器
## M1 任务 6 —— 内置机缘数据并提供随机抽取。
## 仅负责数据与抽取，不负责效果应用（效果由玩家 apply_boon 处理）。
##
## 每个机缘为一个 Dictionary，字段：
##   id            机缘唯一标识
##   boon_name     机缘名称（用于显示）
##   description   简短描述
##   school_tags   所属流派标签（剑修 / 御兽 / 毒道）
##   effect_type   效果类型（玩家据此修改属性）
##   effect_value  效果数值
##
## 说明：M1 仅实现 sword_damage_bonus / speed_bonus / max_hp_bonus /
## attack_cooldown_bonus 四种基础效果，其余效果（穿透、斩杀、御兽、毒系）
## 为占位，留待后续里程碑深化。


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
		},
		{
			"id": "sword_qi_pierce",
			"boon_name": "剑气穿透",
			"description": "剑气可额外穿透 2 个敌人。",
			"school_tags": ["剑气流"],
			"effect_type": "sword_pierce_bonus",
			"effect_value": 2,
		},
		{
			"id": "sword_execute",
			"boon_name": "残血斩杀",
			"description": "斩杀气血低于 20% 的敌人。",
			"school_tags": ["剑气流"],
			"effect_type": "sword_execute",
			"effect_value": 0.2,
		},
		# ===== 御兽流 =====
		{
			"id": "beast_summon_wolf",
			"boon_name": "召唤灵狼",
			"description": "召唤一只灵狼协助攻击妖兽。",
			"school_tags": ["beast"],
			"effect_type": "summon_wolf",
			"effect_value": 1,
		},
		{
			"id": "beast_attack_speed",
			"boon_name": "灵兽攻速提升",
			"description": "所有灵兽攻击速度提升 30%。",
			"school_tags": ["beast"],
			"effect_type": "beast_attack_speed",
			"effect_value": 0.3,
		},
		{
			"id": "beast_guard",
			"boon_name": "灵兽护主",
			"description": "拥有灵兽时，玩家受到的部分伤害由灵兽分担。",
			"school_tags": ["beast"],
			"effect_type": "beast_guard",
			"effect_value": 0.4,
		},
		# ===== 毒蛊流 =====
		{
			"id": "poison_mist",
			"boon_name": "毒雾",
			"description": "释放毒雾持续伤害。",
			"school_tags": ["毒蛊流"],
			"effect_type": "poison_mist",
			"effect_value": 2,
		},
		{
			"id": "poison_stack",
			"boon_name": "叠毒",
			"description": "中毒可叠加层数。",
			"school_tags": ["毒蛊流"],
			"effect_type": "poison_stack",
			"effect_value": 1,
		},
		{
			"id": "poison_explosion",
			"boon_name": "毒爆",
			"description": "引爆毒层造成爆发伤害。",
			"school_tags": ["毒蛊流"],
			"effect_type": "poison_explosion",
			"effect_value": 1,
		},
	]


## 从机缘池随机抽取 count 个不重复机缘（默认 3 个）
func roll_boons(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = get_all_boons()
	# 洗牌后取前 count 个，天然保证不重复
	pool.shuffle()
	var amount: int = min(count, pool.size())
	return pool.slice(0, amount)
