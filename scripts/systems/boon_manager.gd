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

## 机缘默认最大星级（单个机缘可在定义里用 max_star 覆盖）
const DEFAULT_MAX_STAR: int = 5
## 仅 1 星（只能获得一次、不可升星）的机缘：解锁 / 替换 / 开关类
## —— 在此集中配置；未列出的机缘默认 DEFAULT_MAX_STAR 星，可在定义里单独写 max_star 覆盖。
const SINGLE_STAR_IDS: Array[String] = [
	"sword_execute", "beast_summon_wolf", "beast_guard", "beast_extra_wolf",
	"poison_mist", "poison_explosion",
	"sword_qi_art", "sword_slash_art", "poison_dart_art", "beast_whip_art",
	"sword_chain",
	"dash_double", "dash_sword_blink", "dash_beast_pounce", "dash_beast_swap", "dash_poison_mist",
	"beast_alpha", "poison_spore",
]

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
	var boons: Array[Dictionary] = [
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
			"tian_description": "穿透最后一个目标时产生一次剑气爆裂。",
			"tian_effect_type": "pierce_tail_explosion",
			"tian_effect_value": 1,
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
			"tian_description": "每释放 3 次剑气，下一次剑气伤害 +20%。",
			"tian_effect_type": "fast_cast_focus",
			"tian_effect_value": 0.2,
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
			"tian_description": "新召唤的灵狼获得额外 20% 气血。",
			"tian_effect_type": "wolf_spawn_shield",
			"tian_effect_value": 0.2,
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
			"boon_name": "毒性强化",
			"description": "中毒第一层每跳伤害 +5%（按毒灵根）。",
			"school_tags": ["poison"],
			"effect_type": "poison_first_stack_ratio",
			"effect_value": 0.05,
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
			"tian_description": "毒爆后在原地留下 1 秒小毒云，继续施加毒。",
			"tian_effect_type": "spore_poison_cloud",
			"tian_effect_value": 1,
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
		# ===== 第二阶段扩展机缘：剑气 =====
		{
			"id": "sword_chain",
			"boon_name": "剑气连斩",
			"description": "剑气斩杀普通敌人后，立刻重置基础攻击冷却（对 Boss 无效）。",
			"school_tags": ["sword"],
			"effect_type": "sword_chain",
			"grade_affects_value": false,
			"effect_value": 1,
			"max_star": 1,
			"prerequisites": ["sword_execute"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 1,
			"current_stacks": 0,
			"tian_description": "斩杀重置后，下一道剑气轻微自动瞄准最近敌人。",
			"tian_effect_type": "chain_auto_aim",
			"tian_effect_value": 1,
		},
		{
			"id": "sword_lifesteal",
			"boon_name": "剑气噬血",
			"description": "剑气斩杀敌人时回复气血（按星级递增）。",
			"school_tags": ["sword"],
			"effect_type": "sword_lifesteal",
			"grade_affects_value": false,
			"star_values": [1, 2, 3],
			"effect_value": 1,
			"max_star": 3,
			"prerequisites": ["sword_execute"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "斩杀回血溢出部分转为短暂护盾。",
			"tian_effect_type": "lifesteal_overheal_shield",
			"tian_effect_value": 1,
		},
		{
			"id": "sword_mark",
			"boon_name": "剑痕",
			"description": "每第 N 道剑气造成额外倍率伤害（星级越高 N 越小、越强）。",
			"school_tags": ["sword"],
			"effect_type": "sword_mark_interval",
			"grade_affects_value": false,
			# star_values 为触发间隔 N（每第 N 道剑气强化）；数值越小越强
			"star_values": [5, 4, 3],
			"effect_value": 5,
			"max_star": 3,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "剑痕触发后，目标短暂易伤，下一次剑气对其造成额外伤害。",
			"tian_effect_type": "mark_vulnerability",
			"tian_effect_value": 0.5,
		},
		# ===== 第二阶段扩展机缘：御兽 =====
		{
			"id": "beast_pack",
			"boon_name": "群狼之势",
			"description": "每只存活灵狼为你提供基础攻击攻速加成（按星级递增）。",
			"school_tags": ["beast"],
			"effect_type": "beast_pack",
			"grade_affects_value": false,
			# 每只灵狼提供的攻速加成比例
			"star_values": [0.05, 0.10, 0.15],
			"effect_value": 0.05,
			"max_star": 3,
			"prerequisites": ["beast_extra_wolf"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "灵狼数量达到上限时，玩家受到的伤害降低 15%。",
			"tian_effect_type": "pack_guard",
			"tian_effect_value": 0.15,
		},
		{
			"id": "beast_mark_amp",
			"boon_name": "猎物标记",
			"description": "提高驭兽鞭标记目标受到的灵狼伤害倍率（按星级递增）。",
			"school_tags": ["beast"],
			"effect_type": "beast_mark_amp",
			"grade_affects_value": false,
			"star_values": [0.15, 0.30, 0.45],
			"effect_value": 0.15,
			"max_star": 3,
			"prerequisites": ["beast_whip_art"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "被标记目标死亡时，标记转移给附近最近的敌人。",
			"tian_effect_type": "mark_transfer",
			"tian_effect_value": 1,
		},
		{
			"id": "beast_frenzy",
			"boon_name": "嗜血之怒",
			"description": "灵狼击杀敌人后，短时间提升所有灵狼攻速（按星级递增）。",
			"school_tags": ["beast"],
			"effect_type": "beast_frenzy",
			"grade_affects_value": false,
			"star_values": [0.3, 0.5, 0.7],
			"effect_value": 0.3,
			"max_star": 3,
			"prerequisites": ["beast_wolf_damage"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "嗜血之怒期间，灵狼优先攻击低血量敌人。",
			"tian_effect_type": "frenzy_target_low_hp",
			"tian_effect_value": 1,
		},
		# ===== 第二阶段扩展机缘：毒蛊 =====
		{
			"id": "poison_slow",
			"boon_name": "沉疴",
			"description": "中毒层数达到 3 层及以上的敌人移动速度降低（按星级递增）。",
			"school_tags": ["poison"],
			"effect_type": "poison_slow",
			"grade_affects_value": false,
			# 减速比例（速度 ×(1 - 此值)）
			"star_values": [0.2, 0.3, 0.4],
			"effect_value": 0.2,
			"max_star": 3,
			"prerequisites": ["poison_stack"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "poison_dart_multi",
			"boon_name": "致命毒镖",
			"description": "毒镖有概率使目标中毒 / 叠毒（按星级递增的概率）。",
			"school_tags": ["poison"],
			"effect_type": "poison_dart_chance",
			"grade_affects_value": false,
			"star_values": [0.4, 0.7, 1.0],
			"effect_value": 0.4,
			"max_star": 3,
			"prerequisites": ["poison_dart_art"],
			"rarity": "rare",
			"base_weight": 45,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "poison_cursed",
			"boon_name": "蛊咒",
			"description": "中毒叠满 5 层的敌人进入诅咒，受到的所有伤害提高（按星级递增）。",
			"school_tags": ["poison"],
			"effect_type": "poison_curse",
			"grade_affects_value": false,
			# 承伤提高比例（受伤 ×(1 + 此值)）
			"star_values": [0.15, 0.25, 0.35],
			"effect_value": 0.15,
			"max_star": 3,
			"prerequisites": ["poison_stack", "poison_explosion"],
			"rarity": "epic",
			"base_weight": 15,
			"max_stacks": 3,
			"current_stacks": 0,
			"tian_description": "诅咒目标死亡时，向附近敌人传播部分毒层。",
			"tian_effect_type": "curse_spread",
			"tian_effect_value": 2,
		},
		# ===== 基础 / 通用强化（第一阶段新增）=====
		{
			"id": "basic_atk_speed",
			"boon_name": "身轻手疾",
			"description": "基础攻击冷却减少（按星级递增）。",
			"school_tags": [],
			"effect_type": "attack_cooldown_bonus",
			# star_values 已是每星最终值（负数=减少冷却），不再乘星级 / 品阶倍率
			"grade_affects_value": false,
			"star_values": [-0.04, -0.07, -0.10, -0.13, -0.16],
			"effect_value": -0.04,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 90,
			"max_stacks": 5,
			"current_stacks": 0,
		},
		{
			"id": "basic_vitality",
			"boon_name": "淬体",
			"description": "气血上限提升（按星级递增），并立即回复等量气血。",
			"school_tags": [],
			"effect_type": "max_hp_bonus",
			"grade_affects_value": false,
			"star_values": [10, 20, 30, 40, 50],
			"effect_value": 10,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 90,
			"max_stacks": 5,
			"current_stacks": 0,
		},
		{
			"id": "basic_regen",
			"boon_name": "回春",
			"description": "每隔数秒回复固定气血（按星级递增）。",
			"school_tags": [],
			"effect_type": "hp_regen",
			"grade_affects_value": false,
			"star_values": [1, 2, 3, 4, 5],
			"effect_value": 1,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 80,
			"max_stacks": 5,
			"current_stacks": 0,
		},
		{
			"id": "dash_cd_reduce",
			"boon_name": "缩地成寸",
			"description": "冲刺冷却减少（按星级递增，存在下限）。",
			"school_tags": [],
			"effect_type": "dash_cooldown_bonus",
			"grade_affects_value": false,
			"star_values": [-0.3, -0.6, -0.9, -1.2, -1.5],
			"effect_value": -0.3,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 70,
			"max_stacks": 5,
			"current_stacks": 0,
		},
		# ===== 第三阶段：身法机缘 =====
		{
			"id": "dash_double",
			"boon_name": "连环冲刺",
			"description": "冲刺次数 +1，共享冷却逐次恢复。",
			"school_tags": [],
			"effect_type": "dash_count",
			"grade_affects_value": false,
			"effect_value": 1,
			"max_star": 1,
			"prerequisites": [],
			"rarity": "epic",
			"base_weight": 20,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "dash_sword_blink",
			"boon_name": "御剑突刺",
			"description": "身法替换：冲刺路径上的敌人受到一次剑气伤害。",
			"school_tags": ["sword"],
			"effect_type": "replace_dash",
			"grade_affects_value": false,
			"effect_value": "sword_blink",
			"max_star": 1,
			"prerequisites": ["sword_qi_basic"],
			"rarity": "rare",
			"base_weight": 35,
			"max_stacks": 1,
			"current_stacks": 0,
			"tian_description": "突刺命中首个敌人后，生成一道剑气继续前进。",
			"tian_effect_type": "blink_sword_wave",
			"tian_effect_value": 1,
		},
		{
			"id": "dash_beast_pounce",
			"boon_name": "猛兽腾跃",
			"description": "身法替换：冲刺落点附近造成一次范围伤害。",
			"school_tags": ["beast"],
			"effect_type": "replace_dash",
			"grade_affects_value": false,
			"effect_value": "beast_pounce",
			"max_star": 1,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "rare",
			"base_weight": 35,
			"max_stacks": 1,
			"current_stacks": 0,
			"tian_description": "腾跃命中后，灵狼 / 狼王集火落点附近目标 2 秒。",
			"tian_effect_type": "pounce_focus",
			"tian_effect_value": 2,
		},
		{
			"id": "dash_beast_swap",
			"boon_name": "灵兽换位",
			"description": "身法替换：与最近的存活灵狼交换位置并获得短暂无敌；无灵狼时为普通冲刺。",
			"school_tags": ["beast"],
			"effect_type": "replace_dash",
			"grade_affects_value": false,
			"effect_value": "beast_swap",
			"max_star": 1,
			"prerequisites": ["beast_summon_wolf"],
			"rarity": "rare",
			"base_weight": 35,
			"max_stacks": 1,
			"current_stacks": 0,
			"tian_description": "换位后玩家与灵狼都获得 0.3 秒无敌。",
			"tian_effect_type": "swap_invincible",
			"tian_effect_value": 0.3,
		},
		{
			"id": "dash_poison_mist",
			"boon_name": "毒影遁形",
			"description": "身法替换：冲刺起点留下一团小型毒雾。",
			"school_tags": ["poison"],
			"effect_type": "replace_dash",
			"grade_affects_value": false,
			"effect_value": "poison_mist",
			"max_star": 1,
			"prerequisites": ["poison_mist"],
			"rarity": "rare",
			"base_weight": 35,
			"max_stacks": 1,
			"current_stacks": 0,
			"tian_description": "冲刺终点也留下一团小型毒雾。",
			"tian_effect_type": "dash_poison_endpoint",
			"tian_effect_value": 1,
		},
		# ===== 第五阶段：高复杂质变机缘 =====
		{
			"id": "beast_alpha",
			"boon_name": "狼王降临",
			"description": "不再召唤普通灵狼，改为召唤唯一狼王；后续召唤上限转化为狼王强化层数。",
			"school_tags": ["beast"],
			"effect_type": "alpha_wolf",
			"grade_affects_value": false,
			"effect_value": 1,
			"max_star": 1,
			"prerequisites": ["beast_extra_wolf"],
			"rarity": "epic",
			"base_weight": 12,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "poison_spore",
			"boon_name": "毒孢爆裂",
			"description": "毒爆范围 +40，并对范围内敌人附加 0.5 秒晕眩。",
			"school_tags": ["poison"],
			"effect_type": "poison_spore",
			"grade_affects_value": false,
			"effect_value": 40,
			"max_star": 1,
			"prerequisites": ["poison_explosion"],
			"rarity": "epic",
			"base_weight": 12,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		# ===== 灵根强化（第一阶段新增）=====
		{
			"id": "root_sword_plus",
			"boon_name": "剑根淬炼",
			"description": "剑灵根提升（按星级递增）。",
			"school_tags": [],
			"effect_type": "sword_root_bonus",
			"grade_affects_value": false,
			"star_values": [1, 2, 3, 4, 5],
			"effect_value": 1,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "rare",
			"base_weight": 60,
			"max_stacks": 5,
			"current_stacks": 0,
			"tian_description": "剑灵根为三灵根最高时，剑气伤害额外 +2。",
			"tian_effect_type": "sword_root_mastery",
			"tian_effect_value": 2,
		},
		{
			"id": "root_poison_plus",
			"boon_name": "毒根淬炼",
			"description": "毒灵根提升（按星级递增）。",
			"school_tags": [],
			"effect_type": "poison_root_bonus",
			"grade_affects_value": false,
			"star_values": [1, 2, 3, 4, 5],
			"effect_value": 1,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "rare",
			"base_weight": 60,
			"max_stacks": 5,
			"current_stacks": 0,
			"tian_description": "毒灵根为三灵根最高时，中毒持续时间 +0.5 秒。",
			"tian_effect_type": "poison_root_mastery",
			"tian_effect_value": 0.5,
		},
		{
			"id": "root_beast_plus",
			"boon_name": "兽根淬炼",
			"description": "兽灵根提升（按星级递增）。",
			"school_tags": [],
			"effect_type": "beast_root_bonus",
			"grade_affects_value": false,
			"star_values": [1, 2, 3, 4, 5],
			"effect_value": 1,
			"max_star": 5,
			"prerequisites": [],
			"rarity": "rare",
			"base_weight": 60,
			"max_stacks": 5,
			"current_stacks": 0,
			"tian_description": "兽灵根为三灵根最高时，灵狼 / 狼王移速 +10%。",
			"tian_effect_type": "beast_root_mastery",
			"tian_effect_value": 0.1,
		},
		{
			"id": "root_dual_sp",
			"boon_name": "剑毒双修",
			"description": "剑灵根与毒灵根各提升（每升一星各 +1）。",
			"school_tags": [],
			"effect_type": "root_multi",
			# 复合数值：原样复制，不做乘法；每获得 / 升一星按此增量各加一次
			"grade_affects_value": false,
			"effect_values": {"sword_root": 1, "poison_root": 1},
			"effect_value": 0,
			"max_star": 3,
			"prerequisites": [],
			"rarity": "epic",
			"base_weight": 30,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "root_dual_bs",
			"boon_name": "兽剑双修",
			"description": "兽灵根与剑灵根各提升（每升一星各 +1）。",
			"school_tags": [],
			"effect_type": "root_multi",
			"grade_affects_value": false,
			"effect_values": {"beast_root": 1, "sword_root": 1},
			"effect_value": 0,
			"max_star": 3,
			"prerequisites": [],
			"rarity": "epic",
			"base_weight": 30,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		{
			"id": "root_dual_pb",
			"boon_name": "毒兽双修",
			"description": "毒灵根与兽灵根各提升（每升一星各 +1）。",
			"school_tags": [],
			"effect_type": "root_multi",
			"grade_affects_value": false,
			"effect_values": {"poison_root": 1, "beast_root": 1},
			"effect_value": 0,
			"max_star": 3,
			"prerequisites": [],
			"rarity": "epic",
			"base_weight": 30,
			"max_stacks": 3,
			"current_stacks": 0,
		},
		# ===== 基础攻击替换 =====
		{
			"id": "sword_qi_art",
			"boon_name": "剑气术",
			"description": "将左键基础攻击替换为剑气：远程直线攻击，伤害为 1 + 剑灵根 × 110%，可受剑气机缘加成。",
			"school_tags": ["sword"],
			"effect_type": "replace_primary_attack",
			"effect_value": "sword_qi",
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 80,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "sword_slash_art",
			"boon_name": "击剑",
			"description": "将左键基础攻击替换为击剑：前方扇形范围近战攻击，伤害为 6 + 剑灵根 × 100%。",
			"school_tags": ["sword"],
			"effect_type": "replace_primary_attack",
			"effect_value": "sword_slash",
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 80,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "poison_dart_art",
			"boon_name": "毒镖术",
			"description": "将左键基础攻击替换为毒镖。毒镖基础伤害较低，但可叠加毒伤。",
			"school_tags": ["poison"],
			"effect_type": "replace_primary_attack",
			"effect_value": "poison_dart",
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 80,
			"max_stacks": 1,
			"current_stacks": 0,
		},
		{
			"id": "beast_whip_art",
			"boon_name": "驭兽鞭",
			"description": "将左键基础攻击替换为驭兽鞭。驭兽鞭造成短距离范围伤害，并标记敌人，使灵狼对其伤害提升。",
			"school_tags": ["beast"],
			"effect_type": "replace_primary_attack",
			"effect_value": "beast_whip",
			"prerequisites": [],
			"rarity": "common",
			"base_weight": 80,
			"max_stacks": 1,
			"current_stacks": 0,
		},
	]
	# 填充每个机缘的最大星级：定义未显式写 max_star 时，单星类取 1，其余取默认值
	for boon in boons:
		if not boon.has("max_star"):
			boon["max_star"] = 1 if boon["id"] in SINGLE_STAR_IDS else DEFAULT_MAX_STAR
	return boons


## 带权重的随机抽取（星级版）
## owned_boons：玩家已拥有机缘 { id -> 记录(含 star / grade_* ) }
## school_counts：各流派已获得数量 { sword/beast/poison -> count }
## count：期望抽取数量（可选机缘不足时返回实际数量）
##
## 规则：
## - 未拥有机缘：作为 1 星新机缘出现（随机品阶）。
## - 已拥有未满星：作为「同品阶、星级 +1」的升级项出现。
## - 已拥有且满星：过滤，不出现。
func roll_boons(owned_boons: Dictionary, school_counts: Dictionary, count: int = 3) -> Array:
	var owned_ids: Array = owned_boons.keys()
	var candidates: Array = []
	for boon in get_all_boons():
		var id: String = boon["id"]
		var max_star: int = int(boon.get("max_star", DEFAULT_MAX_STAR))
		var is_upgrade: bool = owned_boons.has(id)
		var offer_star: int = 1
		if is_upgrade:
			var cur: int = int(owned_boons[id].get("star", 1))
			# 已满星：过滤
			if cur >= max_star:
				continue
			offer_star = cur + 1
		else:
			# 新机缘需满足前置
			if not _prerequisites_met(boon, owned_ids):
				continue
		candidates.append({
			"boon": boon,
			"is_upgrade": is_upgrade,
			"offer_star": offer_star,
			"weight": _compute_weight(boon, owned_ids, school_counts),
		})

	# 加权不放回抽取，保证不重复、不死循环
	var result: Array = []
	var amount: int = min(count, candidates.size())
	for _i in amount:
		var idx: int = _weighted_pick(candidates)
		var entry: Dictionary = candidates[idx]
		result.append(_build_offer(entry["boon"], entry["is_upgrade"], int(entry["offer_star"]), owned_boons))
		candidates.remove_at(idx)
	return result


## 星级 -> 倍率（用 STAR_TIERS 的固定倍率，按星数取；越界则夹取）
func _star_multiplier(star: int) -> float:
	var idx: int = clampi(star - 1, 0, STAR_TIERS.size() - 1)
	return float(STAR_TIERS[idx]["multiplier"])


## 组装一个机缘选项（含品阶 / 星级 / 倍率 / 最终数值 / 是否升级）
## 升级项沿用已拥有机缘的品阶（品阶不因升星改变）；新机缘随机品阶。
func _build_offer(boon_def: Dictionary, is_upgrade: bool, offer_star: int, owned_boons: Dictionary) -> Dictionary:
	var offer: Dictionary = boon_def.duplicate(true)
	var max_star: int = int(boon_def.get("max_star", DEFAULT_MAX_STAR))

	var grade_id: String
	var grade_name: String
	var grade_color: String
	var grade_multiplier: float
	if is_upgrade and owned_boons.has(boon_def["id"]):
		# 升级：沿用已拥有机缘的品阶（不变）
		var rec: Dictionary = owned_boons[boon_def["id"]]
		grade_id = str(rec.get("grade_id", "fan"))
		grade_name = str(rec.get("grade_name", "凡品"))
		grade_color = str(rec.get("grade_color", "#FFFFFF"))
		grade_multiplier = float(rec.get("grade_multiplier", 1.0))
	else:
		# 新机缘：随机品阶
		var grade: Dictionary = roll_grade()
		grade_id = grade["id"]
		grade_name = grade["name"]
		grade_color = grade["color"]
		grade_multiplier = float(grade["multiplier"])

	var star_mult: float = _star_multiplier(offer_star)
	var final_multiplier: float = grade_multiplier * star_mult

	offer["grade_id"] = grade_id
	offer["grade_name"] = grade_name
	offer["grade_color"] = grade_color
	offer["grade_multiplier"] = grade_multiplier
	offer["star"] = offer_star
	offer["max_star"] = max_star
	offer["star_text"] = "★".repeat(offer_star)
	offer["star_multiplier"] = star_mult
	offer["final_multiplier"] = final_multiplier
	offer["final_effect_value"] = _compute_offer_value(boon_def, offer_star, grade_multiplier, star_mult)
	offer["is_upgrade"] = is_upgrade
	return offer


## 计算机缘最终数值，支持新字段：
## - effect_values（Dictionary）：复合数值，原样复制，不做任何乘法。
## - star_values（Array）：按当前星级直接取对应值（已是每星最终值，不再乘星级倍率）。
## - grade_affects_value == false：不乘品阶倍率。
## - 以上均缺省时：保持旧逻辑（effect_value × 星级倍率 × 品阶倍率）。
func _compute_offer_value(boon_def: Dictionary, star: int, grade_multiplier: float, star_multiplier: float):
	# 复合数值：原样复制字典，不参与乘法
	if boon_def.has("effect_values") and boon_def["effect_values"] is Dictionary:
		return (boon_def["effect_values"] as Dictionary).duplicate(true)

	var grade_affects: bool = bool(boon_def.get("grade_affects_value", true))

	# 星级直取：star_values 已是每星最终值
	if boon_def.has("star_values") and boon_def["star_values"] is Array and not (boon_def["star_values"] as Array).is_empty():
		var arr: Array = boon_def["star_values"]
		var idx: int = clampi(star - 1, 0, arr.size() - 1)
		var mult: float = grade_multiplier if grade_affects else 1.0
		return _compute_final_value(arr[idx], mult)

	# 标量：旧逻辑（grade_affects 缺省为 true → 星级倍率 × 品阶倍率）
	var scalar_mult: float = star_multiplier
	if grade_affects:
		scalar_mult *= grade_multiplier
	return _compute_final_value(boon_def.get("effect_value", 0), scalar_mult)


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
	boon["final_multiplier"] = grade_multiplier * star_multiplier
	# 统一走 _compute_offer_value，兼容 star_values / effect_values / grade_affects_value 等新字段
	boon["final_effect_value"] = _compute_offer_value(
		boon, int(boon.get("star", 1)), grade_multiplier, star_multiplier
	)
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
