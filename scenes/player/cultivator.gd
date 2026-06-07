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
## 灵力冲击（默认近战普通攻击）/ 击剑（剑体系近战）场景
const SPIRIT_IMPACT_SCENE: PackedScene = preload("res://scenes/player/spirit_impact.tscn")
const SWORD_SLASH_SCENE: PackedScene = preload("res://scenes/player/sword_slash.tscn")

var qi_blood: int
var mana: int

## ===== 灵根（开局随机，总和为 20，每项至少 2）=====
var sword_root: int = 2
var poison_root: int = 2
var beast_root: int = 2

## ===== 技能栏系统 =====
## 已解锁的基础攻击（左键）。默认为近战「灵力冲击」；剑气 / 击剑 / 毒镖 / 驭兽鞭由机缘解锁。
var unlocked_primary_attacks: Array[String] = ["spirit_impact"]
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
	"spirit_impact": "灵力冲击",
	"sword_qi": "剑气",
	"sword_slash": "击剑",
	"poison_dart": "毒镖",
	"beast_whip": "驭兽鞭",
}

## 基础攻击 id -> 说明文本（构筑页展示）
const PRIMARY_ATTACK_DESCRIPTIONS: Dictionary = {
	"spirit_impact": "灵力冲击：前方方形范围近战攻击，伤害为 5 + 灵根总和 × 25%。",
	"sword_qi": "剑气：远程直线攻击，伤害为 1 + 剑灵根 × 110%，并受剑气机缘加成（穿透 / 斩杀 / 扩幅）。",
	"sword_slash": "击剑：前方扇形范围近战攻击，伤害为 6 + 剑灵根 × 100%。",
	"poison_dart": "毒镖：远程攻击，伤害为 3 + 毒灵根 × 50%；不会使敌人中毒，但能为已中毒目标叠加 1 层并刷新中毒。",
	"beast_whip": "驭兽鞭：近距离范围攻击，伤害为 6 + 兽灵根 × 70%，命中后标记敌人，使召唤物对其伤害 +25%。",
}

## 技能 id -> 说明文本（构筑页展示）
const SKILL_DESCRIPTIONS: Dictionary = {
	"poison_mist": "毒雾：在鼠标位置释放毒雾，对范围内妖兽持续造成毒伤。毒伤受毒灵根和毒蛊机缘影响。",
	"summon_wolf": "召唤灵狼：召唤灵狼协助战斗。灵狼血量为 800% 兽灵根，攻击为 120% 兽灵根，并受到御兽机缘影响。",
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
## 剑气流：剑气连斩（机缘「剑气连斩」）—— 斩杀普通敌人后重置基础攻击冷却
var sword_chain_enabled: bool = false
## 剑气流：剑气噬血（机缘「剑气噬血」）—— 斩杀时回复气血量
var sword_lifesteal_amount: int = 0
## 剑气流：剑痕触发间隔 N（机缘「剑痕」，0 表示未拥有；每第 N 道剑气强化）
var sword_mark_interval: int = 0
## 剑痕额外伤害倍率（固定）
const SWORD_MARK_MULTIPLIER: float = 2.0
## 剑气释放计数（用于剑痕，每达到 N 后归零）
var _sword_cast_count: int = 0

## 御兽流：已召唤的灵狼列表
var summoned_wolves: Array[Node] = []
## 御兽流：灵兽攻速倍率
var beast_attack_speed_multiplier: float = 1.0
## 御兽流：灵狼伤害加成（机缘「灵狼利爪」）
var wolf_damage_bonus: int = 0
## 御兽流：灵狼移速倍率（机缘「灵狼迅捷」/ 专精「御兽协同」）
var wolf_move_speed_multiplier: float = 1.0
## 御兽流：群狼之势——每只存活灵狼提供的玩家基础攻速加成比例（机缘「群狼之势」）
var beast_pack_per_wolf: float = 0.0
## 御兽流：嗜血之怒——是否启用、攻速加成值、持续时间与当前剩余计时（机缘「嗜血之怒」）
var beast_frenzy_enabled: bool = false
var beast_frenzy_bonus: float = 0.0
@export var beast_frenzy_duration: float = 3.0
var _beast_frenzy_timer: float = 0.0
var _beast_frenzy_active: bool = false
## 基础攻击类型：spirit_impact（灵力冲击，默认）/ sword_qi（剑气）/ sword_slash（击剑）/ poison_dart（毒镖）/ beast_whip（驭兽鞭）
var primary_attack_type: String = "spirit_impact"
## 是否已解锁毒镖 / 驭兽鞭
var poison_dart_unlocked: bool = false
var beast_whip_unlocked: bool = false
## 驭兽鞭标记基础倍率与额外加成（机缘「猎物标记」beast_mark_amp）
const BEAST_MARK_BASE_MULTIPLIER: float = 1.25
var beast_mark_bonus: float = 0.0

## 御兽流：是否已解锁灵狼召唤
var wolf_unlocked: bool = false
## 御兽流：最大同时存活灵狼数量
var max_wolf_count: int = 1
## 御兽流：E 键召唤冷却（秒）与剩余冷却时间
var wolf_summon_cooldown: float = 5.0
var wolf_summon_timer: float = 0.0
## 灵狼基础移速（用于重算移速加成；灵狼伤害改由 get_wolf_damage() 灵根公式驱动）
const WOLF_BASE_MOVE_SPEED: float = 140.0
## 御兽流：是否启用灵兽护主
var beast_guard_enabled: bool = false
## 御兽流：灵兽护主减伤比例（40%）
var beast_guard_ratio: float = 0.4

## 毒蛊流：是否解锁毒雾（Q 释放）
var poison_mist_unlocked: bool = false
## 毒蛊流：是否启用毒爆
var poison_explosion_enabled: bool = false
## 毒蛊流：毒伤加成
var poison_damage_bonus: int = 0
## 毒蛊流：中毒第一层比例加成（机缘「毒性强化」，每跳比例 +此值，0.05 = +5%）
var poison_first_stack_ratio_bonus: float = 0.0
## 毒蛊流：沉疴减速（机缘「沉疴」）—— 是否启用 + 减速比例（速度 ×(1-此值)）
var poison_slow_enabled: bool = false
var poison_slow_bonus: float = 0.0
## 毒蛊流：致命毒镖（机缘「致命毒镖」）—— 毒镖施加 / 叠毒概率
var poison_dart_poison_chance: float = 0.0
## 毒蛊流：蛊咒（机缘「蛊咒」）—— 是否启用 + 满层承伤提高比例（受伤 ×(1+此值)）
var poison_curse_enabled: bool = false
var poison_curse_bonus: float = 0.0

## ===== 天品附属能力（仅天品机缘触发，布尔开关；幂等，重复调用安全）=====
## 剑气穿透：穿透末端剑气爆裂
var tian_pierce_tail_explosion: bool = false
## 御剑疾发：每 3 次剑气后下一次 +20%
var tian_fast_cast_focus: bool = false
var _sword_fast_cast_count: int = 0
## 召唤灵狼：新狼额外 20% 气血
var tian_wolf_spawn_shield: bool = false
## 剑气噬血：斩杀回血溢出转护盾
var tian_lifesteal_overheal_shield: bool = false
## 猎物标记：标记目标死亡转移标记
var tian_mark_transfer: bool = false
## 毒爆：爆后留小毒云
var tian_spore_poison_cloud: bool = false
## 毒影遁形：冲刺终点也留毒雾
var tian_dash_poison_endpoint: bool = false

## ===== 第五阶段：高复杂机缘 + 剩余天品 =====
## 狼王模式：召唤唯一狼王，召唤上限转化为强化层数
var alpha_wolf_enabled: bool = false
## 毒孢爆裂：毒爆附加晕眩
var poison_spore_stun_enabled: bool = false
const POISON_SPORE_STUN_DURATION: float = 0.5
## 灵根精通（天品）：对应灵根为三者最高时生效
var tian_sword_root_mastery: bool = false
var tian_poison_root_mastery: bool = false
var tian_beast_root_mastery: bool = false
## 剑气连斩天品：斩杀重置后下一道剑气自动瞄准
var tian_chain_auto_aim: bool = false
var _next_sword_autoaim: bool = false
## 剑痕天品：触发后给目标短暂易伤
var tian_mark_vulnerability: bool = false
## 群狼天品：满员时玩家减伤
var tian_pack_guard: bool = false
## 嗜血天品：狂热期间灵狼优先攻击低血量敌人
var tian_frenzy_target_low_hp: bool = false
## 蛊咒天品：诅咒目标死亡传播毒层
var tian_curse_spread: bool = false
## 御剑突刺天品：命中首敌后再生成一道剑气
var tian_blink_sword_wave: bool = false
## 猛兽腾跃天品：命中后灵狼集火落点
var tian_pounce_focus: bool = false
## 灵兽换位天品：换位后玩家与灵狼均获 0.3s 无敌
var tian_swap_invincible: bool = false

## ===== 临时护盾（天品「噬血溢盾」用；无护盾系统的最小实现）=====
## 当前护盾值，受伤时优先抵扣；按计时衰减
var shield_hp: int = 0
## 护盾持续时间与剩余计时
@export var shield_duration: float = 5.0
var _shield_timer: float = 0.0
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
## 本次机缘选择是否来自天道残碑（额外机缘，不结算突破）
var _bonus_boon: bool = false

## ===== 动画与冲刺（美术接入新增）=====
## 攻击动画播放窗口（独立于攻击冷却，仅用于播放 attack 动画；8 帧 / 16fps ≈ 0.5s）
@export var attack_anim_duration: float = 0.5
## 冲刺距离 / 持续时间 / 冷却 / 无敌帧时长
@export var dash_distance: float = 150.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 3.0
@export var dash_invincible_time: float = 0.15

## ===== 身法系统（可替换）=====
## 当前身法类型：normal / sword_blink / beast_pounce / beast_swap / poison_mist
var dash_type: String = "normal"
## 最大冲刺次数（机缘「连环冲刺」+1）
var dash_charge_max: int = 1
## 当前可用冲刺次数
var dash_charges: int = 1
## 冲刺次数恢复计时：距下一次充能的剩余时间（多段共享 dash_cooldown 逐次恢复）
var dash_recharge_timer: float = 0.0
## attack 动画剩余播放时间
var _attack_anim_timer: float = 0.0
## 冲刺剩余时间 / 冷却剩余时间 / 冲刺方向
var _dash_timer: float = 0.0
var _dash_cd_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
## 本次冲刺起点（供身法变体：御剑路径伤害 / 毒影遁形留雾）
var _dash_start_pos: Vector2 = Vector2.ZERO
## 无敌帧剩余时间（>0 时免疫伤害）
var _invincible_timer: float = 0.0

## ===== 定时回血（机缘「回春」basic_regen）=====
## 每跳回复气血量（0 表示未拥有），结算间隔与剩余计时
var hp_regen_per_tick: int = 0
@export var hp_regen_interval: float = 3.0
var _hp_regen_timer: float = 0.0

## ===== 表现层特效（纯视觉，不参与碰撞 / 移动 / 伤害 / 无敌计时）=====
## 冲刺残影 / 无敌闪光场景路径：运行时按需 load 并缓存；缺失或未导入则跳过
const DASH_TRAIL_SCENE_PATH: String = "res://scenes/effects/dash_trail.tscn"
const INVINCIBLE_FLASH_SCENE_PATH: String = "res://scenes/effects/invincible_flash.tscn"
var _dash_trail_scene: PackedScene = null
var _invincible_flash_scene: PackedScene = null
var _dash_trail_loaded: bool = false
var _invincible_flash_loaded: bool = false
## 当前横向朝向（"R" 右 / "L" 左）：横向移动时更新，纯纵向 / 静止时保持
var facing_dir: String = "R"
## 攻击 / 冲刺时锁定的朝向（攻击看鼠标、冲刺看冲刺方向）
var _attack_facing: String = "R"
var _dash_facing: String = "R"
## 判定是否在移动的速度阈值（避免动画抖动）
const MOVE_EPS: float = 5.0

## 机缘管理器，负责抽取机缘
var _boon_manager := BoonManager.new()
## 机缘选择面板（运行时从分组查找）
var _boon_panel: Node = null

## 气血组件（子节点 Vitals），负责气血、受伤、治疗与死亡
@onready var vitals: Vitals = $Vitals
## 角色动画显示节点（待机 / 行走 / 攻击 / 冲刺）
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	qi_blood = max_qi_blood
	mana = max_mana

	# 随机生成灵根
	_init_spiritual_roots()


## 随机生成三种灵根：各保底 2 点，剩余 14 点随机分配，总和为 20
func _init_spiritual_roots() -> void:
	# 每种灵根保底 2 点，确保任一流派不会完全过弱
	sword_root = 2
	poison_root = 2
	beast_root = 2
	# 剩余 14 点（20 - 2*3）随机分配给三种灵根
	var roots: Array[String] = ["sword", "poison", "beast"]
	for _i in 14:
		match roots[randi() % roots.size()]:
			"sword":
				sword_root += 1
			"poison":
				poison_root += 1
			"beast":
				beast_root += 1
	# 总和恒为 20，便于校验
	print("剑灵根：", sword_root, "，毒灵根：", poison_root, "，兽灵根：", beast_root, "，总和：", sword_root + poison_root + beast_root)

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
	# 攻击动画窗口 / 冲刺计时 / 冲刺冷却递减
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta
	# 冲刺计时：结束瞬间触发身法落地变体（如猛兽腾跃落点伤害）
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_on_dash_ended()
	# 冲刺次数恢复：未满时按 dash_cooldown 逐次恢复（连环冲刺多段共享冷却）
	if dash_charges < dash_charge_max:
		if dash_recharge_timer <= 0.0:
			dash_recharge_timer = dash_cooldown
		dash_recharge_timer -= delta
		if dash_recharge_timer <= 0.0:
			dash_charges += 1
			dash_recharge_timer = dash_cooldown if dash_charges < dash_charge_max else 0.0
	# 兼容旧字段：_dash_cd_timer = 距下一次充能的剩余时间（满电为 0）
	_dash_cd_timer = dash_recharge_timer if dash_charges < dash_charge_max else 0.0
	# 无敌帧递减
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	# 临时护盾（天品「噬血溢盾」）：到期清空
	if shield_hp > 0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_hp = 0
			stats_changed.emit()
	# 定时回血（机缘「回春」）：拥有时按间隔回复固定气血
	if hp_regen_per_tick > 0:
		_hp_regen_timer -= delta
		if _hp_regen_timer <= 0.0:
			_hp_regen_timer = hp_regen_interval
			if not vitals.is_dead():
				vitals.heal(hp_regen_per_tick)
	# 嗜血之怒：狂热剩余时间递减，结束后恢复灵狼攻速
	if _beast_frenzy_active:
		_beast_frenzy_timer -= delta
		if _beast_frenzy_timer <= 0.0:
			_beast_frenzy_active = false
			update_wolf_attack_speed()

	# 选择机缘 / 构筑页打开期间禁止移动
	if _choosing_boon or _is_build_panel_open():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return

	if _dash_timer > 0.0:
		# 冲刺中：沿冲刺方向匀速移动（速度 = 距离 / 时长），忽略普通输入
		velocity = _dash_dir * (dash_distance / dash_duration)
	else:
		var direction: Vector2 = Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)
		velocity = direction * speed

	move_and_slide()
	# 根据当前状态更新角色动画
	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	# 注：Tab 构筑页的开关由 BuildPanel 自身处理（其 process_mode 为 ALWAYS，
	# 暂停时仍可响应 Tab 关闭）；此处不再处理 open_build_panel。

	# 选择机缘 / 构筑页 / 通关页 打开期间禁止其他操作
	# （暂停时本回调本就不会触发，此处为额外保险）
	if _choosing_boon or _is_build_panel_open() or _is_run_cleared():
		return

	# 鼠标左键（attack_primary）：基础攻击
	if event.is_action_pressed("attack_primary"):
		cast_primary_attack()
		return

	# 冲刺（dash，默认 Space）：短暂高速位移
	if event.is_action_pressed("dash"):
		_try_dash()
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
	# F：优先与附近秘境事件交互；附近无事件时再释放 F 技能
	if event.is_action_pressed("interact"):
		if _try_interact():
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

	# 按基础攻击类型分发（默认近战灵力冲击）
	match primary_attack_type:
		"sword_qi":
			cast_sword_qi(direction)
		"sword_slash":
			cast_sword_slash(direction)
		"poison_dart":
			cast_poison_dart(direction)
		"beast_whip":
			cast_beast_whip(direction)
		_:
			cast_spirit_impact(direction)

	# 重置冷却（含群狼之势按存活灵狼数派生的攻速加成）
	_attack_timer = get_effective_attack_cooldown()
	# 攻击朝向看鼠标方向：右侧 attack_R，左侧 attack_L
	_attack_facing = "R" if direction.x >= 0.0 else "L"
	facing_dir = _attack_facing
	# 开启攻击动画窗口并立即播放一次方向攻击动画
	_attack_anim_timer = attack_anim_duration
	if _anim_sprite != null:
		_anim_sprite.play("attack_" + _attack_facing)


# ===== 冲刺与动画 =====

## 尝试冲刺（Space）：仅负责检查、求方向并分发到 _start_dash
func _try_dash() -> void:
	# 机缘选择 / 构筑页 / 通关面板打开时禁止冲刺
	if _choosing_boon or _is_build_panel_open() or _is_run_cleared():
		return
	# 正在冲刺中、或无可用冲刺次数则不冲刺
	if _dash_timer > 0.0 or dash_charges <= 0:
		return
	# 冲刺方向：玩家当前位置 → 鼠标世界坐标
	var dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	# 鼠标与玩家重合导致方向为零时，退回当前横向朝向
	if dir == Vector2.ZERO:
		dir = Vector2(1.0 if facing_dir == "R" else -1.0, 0.0)
	_start_dash(dir)


## 通用冲刺启动：扣次数、设朝向 / 计时 / 无敌帧 / 表现，再分发身法起手变体
func _start_dash(dir: Vector2) -> void:
	_dash_dir = dir
	_dash_start_pos = global_position
	# 冲刺朝向看冲刺方向：右 dash_R，左 dash_L
	_dash_facing = "R" if _dash_dir.x >= 0.0 else "L"
	facing_dir = _dash_facing
	_dash_timer = dash_duration
	# 冲刺前段获得无敌帧。注：连环冲刺仅是多一次充能，每次冲刺都只给这同一段很短的
	# 无敌（dash_invincible_time，不叠加 / 不延长），因此第二段不会带来额外强力无敌窗口。
	_invincible_timer = dash_invincible_time
	# 扣除一次冲刺次数；未满上限则确保恢复计时在进行（多段共享冷却）
	dash_charges -= 1
	if dash_charges < dash_charge_max and dash_recharge_timer <= 0.0:
		dash_recharge_timer = dash_cooldown
	# 表现层：冲刺残影 + 无敌闪光（纯视觉，不影响任何冲刺 / 无敌逻辑）
	_play_dash_trail()
	_play_invincible_flash()
	# 身法起手变体（御剑路径伤害 / 灵兽换位 / 毒影遁形留雾）
	_apply_dash_variant_on_start()


## 冲刺结束回调：触发身法落地变体（猛兽腾跃落点伤害）
func _on_dash_ended() -> void:
	_apply_dash_variant_on_end()


# ===== 身法变体 =====

## 身法起手：在冲刺开始时触发对应效果
func _apply_dash_variant_on_start() -> void:
	match dash_type:
		"sword_blink":
			_dash_sword_blink_damage()
		"beast_swap":
			_dash_beast_swap()
		"poison_mist":
			# 毒影遁形：起点留雾
			_spawn_dash_mist(_dash_start_pos)
		# beast_pounce 在落地（_on_dash_ended）时处理
		_:
			pass


## 身法落地：在冲刺结束时触发对应效果
func _apply_dash_variant_on_end() -> void:
	match dash_type:
		"beast_pounce":
			_dash_beast_pounce_land()
		"poison_mist":
			# 天品「毒影遁形·终点」：冲刺终点也留一团小毒雾
			if tian_dash_poison_endpoint:
				_spawn_dash_mist(global_position)
		_:
			pass


## 御剑突刺：对起点→落点线段附近的敌人各造成一次剑气伤害（每敌最多一次）
func _dash_sword_blink_damage() -> void:
	var seg_end: Vector2 = _dash_start_pos + _dash_dir * dash_distance
	var dmg: int = get_sword_damage()
	const HIT_RADIUS: float = 32.0
	var first_hit_pos: Vector2 = Vector2.INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if ev == null or ev.is_dead():
			continue
		if _dist_point_to_segment((enemy as Node2D).global_position, _dash_start_pos, seg_end) <= HIT_RADIUS:
			ev.take_damage(dmg)
			if first_hit_pos == Vector2.INF:
				first_hit_pos = (enemy as Node2D).global_position
	# 天品「剑波」：命中首个敌人后，从该处生成一道剑气继续前进
	if tian_blink_sword_wave and first_hit_pos != Vector2.INF:
		var wave := SwordQiScene.instantiate()
		wave.global_position = first_hit_pos
		wave.direction = _dash_dir
		wave.damage = dmg
		get_parent().add_child(wave)


## 猛兽腾跃：在冲刺落点造成一次范围伤害（伤害用驭兽鞭公式）
func _dash_beast_pounce_land() -> void:
	var center: Vector2 = global_position
	const POUNCE_RADIUS: float = 90.0
	var dmg: int = get_beast_whip_damage()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if ev == null or ev.is_dead():
			continue
		if center.distance_to((enemy as Node2D).global_position) <= POUNCE_RADIUS:
			ev.take_damage(dmg)
	# 存活灵狼支援：靠近落点（最小实现，灵狼自身寻敌 AI 会接管攻击）
	for wolf in summoned_wolves:
		if is_instance_valid(wolf) and wolf is Node2D:
			(wolf as Node2D).global_position = center + Vector2(
				randf_range(-50.0, 50.0), randf_range(-50.0, 50.0)
			)
			# 天品「集火」：让灵狼锁定落点附近目标一段时间
			if tian_pounce_focus and wolf.has_method("focus_near"):
				wolf.focus_near(center, 2.0)


## 灵兽换位：与最近存活灵狼交换位置并获得 0.2s 无敌；无灵狼则退回普通冲刺
func _dash_beast_swap() -> void:
	var wolf: Node2D = _nearest_alive_wolf()
	if wolf == null:
		# 无灵狼：保持普通方向冲刺（_start_dash 已设置好方向位移）
		return
	var my_pos: Vector2 = global_position
	global_position = wolf.global_position
	wolf.global_position = my_pos
	# 换位短暂无敌（至少 0.2s）；天品时延长到 0.3s 并让灵狼也获得无敌
	var inv: float = 0.3 if tian_swap_invincible else 0.2
	_invincible_timer = max(_invincible_timer, inv)
	if tian_swap_invincible and wolf.has_method("grant_invincible"):
		wolf.grant_invincible(0.3)
	# 瞬移换位，不再进行方向滑行
	_dash_timer = 0.0


## 毒影遁形：在指定位置留下一团小型毒雾（持续 1.5s、半径约 60%），不消耗 Q 冷却
func _spawn_dash_mist(pos: Vector2) -> void:
	if POISON_MIST_SCENE == null:
		return
	var mist := POISON_MIST_SCENE.instantiate()
	# 使用玩家当前毒灵根与毒蛊加成
	mist.source_poison_root = poison_root
	mist.poison_bonus_per_tick = poison_damage_bonus
	mist.poison_ratio_bonus = poison_first_stack_ratio_bonus
	mist.poison_explosion_enabled = poison_explosion_enabled
	mist.explosion_radius = 120.0 + poison_explosion_radius_bonus
	mist.explosion_damage = 8 + poison_explosion_damage_bonus
	# 缩短持续时间与范围（半径约 60%：48 / 80）
	mist.duration = 1.5
	mist.radius_bonus = -32
	# 毒蛊联动：减速 / 蛊咒 / 毒爆余烬
	mist.poison_slow_enabled = poison_slow_enabled
	mist.poison_slow_multiplier = get_poison_slow_multiplier()
	mist.poison_curse_enabled = poison_curse_enabled
	mist.poison_curse_multiplier = get_poison_curse_multiplier()
	mist.poison_spore_enabled = tian_spore_poison_cloud
	mist.poison_spore_stun_enabled = poison_spore_stun_enabled
	mist.poison_spore_stun_duration = POISON_SPORE_STUN_DURATION
	mist.poison_curse_spread_enabled = tian_curse_spread
	mist.poison_dot_duration = get_poison_dot_duration()
	get_parent().add_child(mist)
	mist.global_position = pos


## 最近的存活灵狼（无则返回 null）
func _nearest_alive_wolf() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for wolf in summoned_wolves:
		if not is_instance_valid(wolf) or not wolf is Node2D:
			continue
		var wv: Vitals = wolf.get_node_or_null("Vitals") as Vitals
		if wv != null and wv.is_dead():
			continue
		var d: float = global_position.distance_to((wolf as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = wolf
	return nearest


## 点到线段的最短距离（用于御剑突刺路径判定）
func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 播放冲刺残影：在世界中冲刺起点生成一次性特效，朝向冲刺方向，播放完自销毁
func _play_dash_trail() -> void:
	# 懒加载场景（缺失 / 未导入则跳过，绝不影响冲刺逻辑）
	if not _dash_trail_loaded:
		_dash_trail_loaded = true
		if ResourceLoader.exists(DASH_TRAIL_SCENE_PATH):
			_dash_trail_scene = load(DASH_TRAIL_SCENE_PATH) as PackedScene
	if _dash_trail_scene == null:
		return
	var fx: Node2D = _dash_trail_scene.instantiate() as Node2D
	if fx == null:
		return
	# 放到世界（与玩家同级）作为留在原地的残影，而非跟随玩家
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	parent.add_child(fx)
	fx.global_position = global_position
	fx.rotation = _dash_dir.angle()


## 播放无敌闪光：作为额外视觉叠加层挂在角色上，播放完自销毁（不改无敌判定）
func _play_invincible_flash() -> void:
	if not _invincible_flash_loaded:
		_invincible_flash_loaded = true
		if ResourceLoader.exists(INVINCIBLE_FLASH_SCENE_PATH):
			_invincible_flash_scene = load(INVINCIBLE_FLASH_SCENE_PATH) as PackedScene
	if _invincible_flash_scene == null:
		return
	var fx: Node2D = _invincible_flash_scene.instantiate() as Node2D
	if fx == null:
		return
	# 作为子节点跟随角色，覆盖在身上；自身播放完会 queue_free
	add_child(fx)
	fx.position = Vector2.ZERO


## 根据当前状态播放方向动画（优先级：冲刺 > 攻击 > 行走 > 待机）
func _update_animation() -> void:
	if _anim_sprite == null:
		return
	# 横向移动时更新朝向；纯纵向 / 静止保持上一次朝向
	if velocity.x > MOVE_EPS:
		facing_dir = "R"
	elif velocity.x < -MOVE_EPS:
		facing_dir = "L"

	if _dash_timer > 0.0:
		# 冲刺：方向锁定为冲刺方向
		_play_anim("dash_" + _dash_facing)
	elif _attack_anim_timer > 0.0:
		# 攻击：方向锁定为出手时的鼠标方向，不被移动 / 待机打断
		_play_anim("attack_" + _attack_facing)
	elif velocity.x > MOVE_EPS:
		_play_anim("walk_R")
	elif velocity.x < -MOVE_EPS:
		_play_anim("walk_L")
	elif velocity.length() > MOVE_EPS:
		# 仅上下移动：用当前朝向行走
		_play_anim("walk_" + facing_dir)
	else:
		# 静止：按当前朝向待机
		_play_anim("idle_" + facing_dir)


## 仅在动画名变化时切换，避免每帧重置造成闪烁
func _play_anim(anim_name: String) -> void:
	if _anim_sprite.animation != anim_name:
		_anim_sprite.play(anim_name)


## 释放灵力冲击（默认近战普通攻击）：前方方形范围一次性伤害
func cast_spirit_impact(direction: Vector2) -> void:
	var fx := SPIRIT_IMPACT_SCENE.instantiate()
	fx.global_position = global_position
	fx.rotation = direction.angle()
	fx.damage = get_spirit_impact_damage()
	get_parent().add_child(fx)


## 释放击剑（剑体系近战）：前方扇形范围一次性伤害
func cast_sword_slash(direction: Vector2) -> void:
	var fx := SWORD_SLASH_SCENE.instantiate()
	fx.global_position = global_position
	fx.rotation = direction.angle()
	fx.damage = get_sword_slash_damage()
	get_parent().add_child(fx)


## 释放剑气（远程，剑体系机缘攻击）
func cast_sword_qi(direction: Vector2) -> void:
	# 天品「连斩自瞄」：斩杀重置后的下一道剑气轻微自动瞄准最近敌人
	if _next_sword_autoaim:
		_next_sword_autoaim = false
		var aim_target: Node2D = _nearest_enemy_to(global_position)
		if aim_target != null:
			direction = global_position.direction_to(aim_target.global_position)
	var sword_qi := SwordQiScene.instantiate()
	sword_qi.global_position = global_position
	sword_qi.direction = direction
	# 剑气伤害由剑灵根驱动（含机缘加成）
	var dmg: float = float(get_sword_damage())
	var is_mark_shot: bool = false
	# 剑痕：每第 N 道剑气额外倍率伤害（sword_mark_interval>0 时启用）
	if sword_mark_interval > 0:
		_sword_cast_count += 1
		if _sword_cast_count >= sword_mark_interval:
			_sword_cast_count = 0
			dmg *= SWORD_MARK_MULTIPLIER
			is_mark_shot = true
	# 天品「御剑疾发」专注：每释放 3 次剑气，下一次（第 4 次）伤害 +20%（不永久加伤）
	if tian_fast_cast_focus:
		_sword_fast_cast_count += 1
		if _sword_fast_cast_count % 4 == 0:
			dmg *= 1.2
	sword_qi.damage = int(round(dmg))
	sword_qi.pierce_remaining = sword_pierce_bonus
	sword_qi.execute_enabled = sword_execute_enabled
	sword_qi.execute_threshold = sword_execute_threshold
	sword_qi.width_bonus = sword_width_bonus
	# 斩杀联动机缘：回调入口 + 噬血回血量 + 连斩开关（剑气在斩杀击杀时回调玩家）
	sword_qi.owner_player = self
	sword_qi.lifesteal_amount = sword_lifesteal_amount
	sword_qi.chain_enabled = sword_chain_enabled
	# 天品「穿透爆裂」：穿透末端产生一次小范围剑气爆裂
	sword_qi.tail_explosion_enabled = tian_pierce_tail_explosion
	# 天品「剑痕易伤」：剑痕触发的这一道命中时给目标挂易伤；所有剑气命中易伤目标享受额外伤害
	sword_qi.vuln_consume_enabled = tian_mark_vulnerability
	sword_qi.vuln_apply_on_hit = tian_mark_vulnerability and is_mark_shot
	# 添加到场景树（挂到父节点下，使剑气独立于玩家移动）
	get_parent().add_child(sword_qi)


## 距指定点最近的存活敌人（无则 null）
func _nearest_enemy_to(pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if ev != null and ev.is_dead():
			continue
		var d: float = pos.distance_to((enemy as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest


## 释放毒镖（毒蛊基础攻击）
func cast_poison_dart(direction: Vector2) -> void:
	var dart := POISON_DART_SCENE.instantiate()
	dart.global_position = global_position
	dart.direction = direction
	# 毒镖直接伤害 = 3 + 毒灵根 * 50%
	dart.damage = get_poison_dart_damage()
	# 致命毒镖：按概率施加第一层毒（机缘「致命毒镖」），并附带中毒结算所需参数
	dart.poison_chance = poison_dart_poison_chance
	dart.source_poison_root = poison_root
	dart.poison_bonus_per_tick = poison_damage_bonus
	dart.poison_ratio_bonus = poison_first_stack_ratio_bonus
	# 毒蛊联动：减速 / 蛊咒配置（随中毒一并下发到目标 StatusEffects）
	dart.poison_slow_enabled = poison_slow_enabled
	dart.poison_slow_multiplier = get_poison_slow_multiplier()
	dart.poison_curse_enabled = poison_curse_enabled
	dart.poison_curse_multiplier = get_poison_curse_multiplier()
	# 天品「毒爆余烬」：毒爆后留小毒云
	dart.poison_spore_enabled = tian_spore_poison_cloud
	dart.poison_spore_stun_enabled = poison_spore_stun_enabled
	dart.poison_spore_stun_duration = POISON_SPORE_STUN_DURATION
	dart.poison_curse_spread_enabled = tian_curse_spread
	dart.poison_dot_duration = get_poison_dot_duration()
	get_parent().add_child(dart)


## 释放驭兽鞭（御兽基础攻击）
func cast_beast_whip(direction: Vector2) -> void:
	var whip := BEAST_WHIP_SCENE.instantiate()
	whip.global_position = global_position
	whip.direction = direction
	# 驭兽鞭自身伤害由兽灵根驱动（主要价值是驭兽标记）
	whip.damage = get_beast_whip_damage()
	# 标记倍率 = 基础 + 猎物标记加成（机缘「猎物标记」beast_mark_amp）
	whip.beast_mark_multiplier = BEAST_MARK_BASE_MULTIPLIER + beast_mark_bonus
	# 天品「标记转移」：被标记目标死亡时把标记转移给最近敌人
	whip.beast_mark_transfer = tian_mark_transfer
	get_parent().add_child(whip)


# ===== 灵根驱动的基础数值 =====

## 灵根总和（灵力冲击等使用）
func get_total_root() -> int:
	return sword_root + poison_root + beast_root


## 灵力冲击伤害 = round(5 + 灵根总和 * 0.25)
func get_spirit_impact_damage() -> int:
	return int(round(5.0 + get_total_root() * 0.25))


## 剑气最终伤害 = round(1 + 剑灵根 * 1.10) + 剑气伤害加成（+剑灵根精通天品）
func get_sword_damage() -> int:
	var d: int = int(round(1.0 + sword_root * 1.10)) + sword_damage_bonus
	# 天品「剑灵根精通」：剑灵根为三者最高时额外 +2
	if tian_sword_root_mastery and _is_root_highest("sword"):
		d += 2
	return d


## 中毒 DOT 持续时间（含毒灵根精通天品 +0.5s）
func get_poison_dot_duration() -> float:
	var dur: float = 5.0
	if tian_poison_root_mastery and _is_root_highest("poison"):
		dur += 0.5
	return dur


## 击剑伤害 = round(6 + 剑灵根 * 1.00)
func get_sword_slash_damage() -> int:
	return int(round(6.0 + sword_root * 1.0))


## 毒镖直接伤害 = round(3 + 毒灵根 * 0.50)
func get_poison_dart_damage() -> int:
	return int(round(3.0 + poison_root * 0.5))


## 毒伤预览值（构筑页展示用）：中毒 1 层每跳伤害 = round(毒灵根 * (0.10 + 第一层比例加成)) + 毒伤加成
func get_poison_damage() -> int:
	return int(round(poison_root * (0.10 + poison_first_stack_ratio_bonus))) + poison_damage_bonus


## 灵狼最大血量 = round(兽灵根 * 8.0)
func get_wolf_max_hp() -> int:
	return int(round(beast_root * 8.0))


## 灵狼最终攻击 = round(兽灵根 * 1.2) + 灵狼伤害加成
func get_wolf_damage() -> int:
	return int(round(beast_root * 1.2)) + wolf_damage_bonus


## 驭兽鞭自身伤害 = round(6 + 兽灵根 * 0.70)
func get_beast_whip_damage() -> int:
	return int(round(6.0 + beast_root * 0.7))


# ===== 派生数值（机缘扩展：不永久修改基础值，按当前状态实时重算）=====

## 基础攻击实际冷却：基础冷却 / (1 + 存活灵狼数 × 每狼攻速加成)（机缘「群狼之势」）
func get_effective_attack_cooldown() -> float:
	var cd: float = attack_cooldown
	if beast_pack_per_wolf > 0.0:
		var wolves: int = get_alive_wolf_count()
		cd = cd / (1.0 + float(wolves) * beast_pack_per_wolf)
	return max(0.1, cd)


## 灵兽实际攻速倍率：基础倍率（+嗜血之怒激活时的临时加成）
func get_effective_beast_attack_speed() -> float:
	var m: float = beast_attack_speed_multiplier
	if _beast_frenzy_active:
		m += beast_frenzy_bonus
	return m


## 沉疴减速倍率（速度 ×此值）：未拥有返回 1.0
func get_poison_slow_multiplier() -> float:
	return 1.0 - poison_slow_bonus if poison_slow_enabled else 1.0


## 蛊咒承伤倍率（受伤 ×此值）：未拥有返回 1.0
func get_poison_curse_multiplier() -> float:
	return 1.0 + poison_curse_bonus if poison_curse_enabled else 1.0


# ===== 机缘战斗回调（由剑气 / 灵狼在击杀时调用）=====

## 剑气斩杀回血（机缘「剑气噬血」）
func on_sword_lifesteal(amount: int) -> void:
	if amount <= 0:
		return
	var before: int = vitals.get_current_qi_blood()
	vitals.heal(amount)
	# 天品「噬血溢盾」：满血后溢出的回血量转为短暂护盾
	if tian_lifesteal_overheal_shield:
		var healed: int = vitals.get_current_qi_blood() - before
		var overflow: int = amount - healed
		if overflow > 0:
			_add_shield(overflow)


## 增加临时护盾并刷新持续时间（天品「噬血溢盾」最小实现）
func _add_shield(amount: int) -> void:
	if amount <= 0:
		return
	shield_hp += amount
	_shield_timer = shield_duration
	stats_changed.emit()


## 剑气斩杀普通敌人后重置基础攻击冷却（机缘「剑气连斩」，Boss 不触发由剑气侧判定）
func on_sword_chain_kill() -> void:
	_attack_timer = 0.0
	# 天品「连斩自瞄」：标记下一道剑气自动瞄准
	if tian_chain_auto_aim:
		_next_sword_autoaim = true


## 灵狼是否应优先攻击低血量敌人（嗜血之怒天品，狂热激活期间）
func is_frenzy_lowhp_targeting() -> bool:
	return tian_frenzy_target_low_hp and _beast_frenzy_active


## 灵狼击杀敌人：刷新嗜血之怒持续时间并激活临时攻速（机缘「嗜血之怒」）
func on_wolf_kill() -> void:
	if not beast_frenzy_enabled:
		return
	_beast_frenzy_timer = beast_frenzy_duration
	if not _beast_frenzy_active:
		_beast_frenzy_active = true
		update_wolf_attack_speed()


# ===== 天品附属能力 =====

## 对一条机缘记录应用天品附属能力（带防重复：已应用则跳过，应用后标记）
func _try_apply_tian_effect(rec: Dictionary) -> void:
	if bool(rec.get("tian_effect_applied", false)):
		return
	if str(rec.get("tian_effect_type", "")) == "":
		return
	_apply_tian_boon_effect(rec)
	rec["tian_effect_applied"] = true


## 天品附属能力分发：仅设置布尔开关（幂等），具体生效在各战斗逻辑里读取这些开关
func _apply_tian_boon_effect(boon: Dictionary) -> void:
	match boon.get("tian_effect_type", ""):
		"pierce_tail_explosion":
			tian_pierce_tail_explosion = true
		"fast_cast_focus":
			tian_fast_cast_focus = true
		"wolf_spawn_shield":
			tian_wolf_spawn_shield = true
		"lifesteal_overheal_shield":
			tian_lifesteal_overheal_shield = true
		"mark_transfer":
			tian_mark_transfer = true
		"spore_poison_cloud":
			tian_spore_poison_cloud = true
		"dash_poison_endpoint":
			tian_dash_poison_endpoint = true
		# ===== 第五阶段补全天品 =====
		"sword_root_mastery":
			tian_sword_root_mastery = true
		"poison_root_mastery":
			tian_poison_root_mastery = true
		"beast_root_mastery":
			tian_beast_root_mastery = true
			update_wolf_move_speed()
		"chain_auto_aim":
			tian_chain_auto_aim = true
		"mark_vulnerability":
			tian_mark_vulnerability = true
		"pack_guard":
			tian_pack_guard = true
		"frenzy_target_low_hp":
			tian_frenzy_target_low_hp = true
		"curse_spread":
			tian_curse_spread = true
		"blink_sword_wave":
			tian_blink_sword_wave = true
		"pounce_focus":
			tian_pounce_focus = true
		"swap_invincible":
			tian_swap_invincible = true
		_:
			# 空 / 未实现的天品能力：不做任何事
			pass
	if str(boon.get("tian_effect_type", "")) != "":
		print("天品附属能力已激活：", boon.get("tian_description", boon.get("tian_effect_type", "")))


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

	# 根据已拥有机缘（升星）与流派倾向加权筛选可选机缘
	var boons: Array = _boon_manager.roll_boons(_owned_boons_dict(), school_counts, 3)
	if boons.is_empty():
		# 机缘池全部满星：不卡死游戏，给少量天道石兜底并完成突破
		print("机缘已全部满星，改为奖励天道石")
		gain_heavenly_stones(2)
		complete_breakthrough_after_boon_selected()
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
	if id == "":
		push_warning("机缘缺少 id，已跳过应用")
	else:
		var rec: Dictionary = _find_owned_record(id)
		if rec.is_empty():
			# ===== 首次获得：星级 = 1，应用完整效果（含一次性解锁 / 被动 / 数值）=====
			apply_boon(boon)
			acquired_boon_ids.append(id)
			var new_rec: Dictionary = _make_boon_record(boon)
			acquired_boon_records.append(new_rec)
			# 天品机缘：正常效果之后再应用一次天品附属能力（并记录已应用，避免重复）
			if str(boon.get("grade_id", "fan")) == "tian":
				_try_apply_tian_effect(new_rec)
			# 流派计数仅首次获得时 +1（升星不重复计入）
			for tag in boon.get("school_tags", []):
				if school_counts.has(tag):
					school_counts[tag] += 1
			check_specializations()
		else:
			# ===== 已拥有：升星（仅数值类按差值叠加，不重复触发一次性效果 / 流派计数）=====
			_upgrade_owned_boon(rec, boon)

	# 残碑额外机缘：只给机缘，不结算突破（不改层数 / 修为需求）
	if _bonus_boon:
		_bonus_boon = false
		print("天道残碑机缘已获得")
		stats_changed.emit()
	else:
		# 正常突破：完成突破结算
		complete_breakthrough_after_boon_selected()

	# 恢复移动与攻击
	_choosing_boon = false


## 天道残碑：打开一次额外机缘三选一（不消耗修为、不结算突破）
func open_bonus_boon_choice() -> void:
	# 正在选择机缘时不重复打开
	if _choosing_boon:
		return
	# 兜底连接面板
	if _boon_panel == null:
		_connect_boon_panel()
	if _boon_panel == null:
		push_warning("未找到机缘选择面板（BoonChoicePanel），无法打开残碑机缘")
		return
	# 抽取机缘（升星 + 前置 + 加权逻辑）
	var boons: Array = _boon_manager.roll_boons(_owned_boons_dict(), school_counts, 3)
	if boons.is_empty():
		# 机缘池全部满星：残碑改为奖励天道石兜底，不卡死
		print("机缘已全部满星，改为奖励天道石")
		gain_heavenly_stones(2)
		return
	# 标记为额外机缘并进入选择状态（show_boons 会暂停游戏）
	_bonus_boon = true
	_choosing_boon = true
	_boon_panel.show_boons(boons)


## 与最近的可交互秘境事件交互（F 键）。成功返回 true
func _try_interact() -> bool:
	var best: Node = null
	var best_dist: float = INF
	for event in get_tree().get_nodes_in_group("realm_event"):
		if not is_instance_valid(event) or not event.has_method("can_interact"):
			continue
		if not event.can_interact():
			continue
		var d: float = global_position.distance_to(event.global_position)
		if d < best_dist:
			best_dist = d
			best = event
	if best != null:
		return best.trigger_event(self)
	return false


## 从机缘选项构建“已拥有机缘记录”（品阶 / 星级 / 最终数值 / 已应用数值）
## 兼容性：star 缺失默认 1、max_star 缺失默认 5，并把 star 夹到 [1, max_star]
func _make_boon_record(boon: Dictionary) -> Dictionary:
	var max_star: int = int(boon.get("max_star", 5))
	var star: int = clampi(int(boon.get("star", 1)), 1, max_star)
	var final_value = boon.get("final_effect_value", boon.get("effect_value", 0))
	return {
		"id": boon.get("id", ""),
		"boon_name": boon.get("boon_name", "?"),
		"description": boon.get("description", ""),
		"school_tags": boon.get("school_tags", []),
		"effect_type": boon.get("effect_type", ""),
		"effect_value": boon.get("effect_value", 0),
		"grade_id": boon.get("grade_id", "fan"),
		"grade_name": boon.get("grade_name", ""),
		"grade_color": boon.get("grade_color", "#FFFFFF"),
		"grade_multiplier": boon.get("grade_multiplier", 1.0),
		"star": star,
		"max_star": max_star,
		# 同时保留 stars 字段以兼容仍读取 stars 的旧 UI 代码
		"stars": star,
		"star_text": "★".repeat(star),
		"final_effect_value": final_value,
		# 已实际应用到属性的数值，用于升星时按差值叠加
		"applied_value": final_value,
		# 天品附属能力（结构化保存，供显示与升品到天品时判断；默认未应用）
		"tian_effect_type": boon.get("tian_effect_type", ""),
		"tian_effect_value": boon.get("tian_effect_value", null),
		"tian_description": boon.get("tian_description", ""),
		"tian_effect_applied": false,
	}


## 已拥有机缘字典 { id -> 记录 }，供机缘抽取判断星级 / 品阶
func _owned_boons_dict() -> Dictionary:
	var d: Dictionary = {}
	for rec in acquired_boon_records:
		d[rec.get("id", "")] = rec
	return d


## 按 id 查找已拥有机缘记录，未找到返回空字典
func _find_owned_record(id: String) -> Dictionary:
	for rec in acquired_boon_records:
		if rec.get("id", "") == id:
			return rec
	return {}


## 当前某机缘的星级（未拥有返回 0）
func get_owned_boon_star(id: String) -> int:
	var rec: Dictionary = _find_owned_record(id)
	return int(rec.get("star", 0)) if not rec.is_empty() else 0


## 升星已拥有机缘：星级 +1（夹到 max_star），数值类按差值叠加，刷新记录显示
func _upgrade_owned_boon(rec: Dictionary, offer: Dictionary) -> void:
	var max_star: int = int(rec.get("max_star", 5))
	var new_star: int = int(offer.get("star", int(rec.get("star", 1)) + 1))
	if new_star > max_star:
		push_warning("机缘 %s 已达最大星级 %d，升星请求被夹取" % [rec.get("id", "?"), max_star])
		new_star = max_star

	# 数值类机缘：按“新最终值 - 已应用值”的差值叠加（解锁类 effect_type 不在映射中，自然为空操作）
	var old_value = rec.get("applied_value", 0)
	var new_value = offer.get("final_effect_value", old_value)
	if (old_value is int or old_value is float) and (new_value is int or new_value is float):
		_apply_numeric_boon_delta(str(rec.get("effect_type", "")), new_value - old_value)
		rec["applied_value"] = new_value
	elif new_value is Dictionary:
		# 复合数值（如双灵根）：每升一星按 effect_values 增量再各应用一次
		_apply_composite_root(new_value)
		rec["applied_value"] = new_value

	# 刷新记录：星级 / 显示 / 品阶（品阶通常不变；若经“升品”购买则以 offer 为准）
	rec["star"] = new_star
	rec["stars"] = new_star
	rec["star_text"] = "★".repeat(new_star)
	rec["grade_id"] = offer.get("grade_id", rec.get("grade_id", "fan"))
	rec["grade_name"] = offer.get("grade_name", rec.get("grade_name", ""))
	rec["grade_color"] = offer.get("grade_color", rec.get("grade_color", "#FFFFFF"))
	rec["grade_multiplier"] = offer.get("grade_multiplier", rec.get("grade_multiplier", 1.0))
	rec["final_effect_value"] = new_value
	# 升品到天品：若此前未应用过天品能力，则补一次（_try_apply_tian_effect 内部防重复）
	if str(rec.get("grade_id", "fan")) == "tian":
		_try_apply_tian_effect(rec)
	print("机缘升星：", rec.get("boon_name", "?"), " → ", new_star, " 星")
	stats_changed.emit()


## 数值类机缘的“差值叠加”应用（与 apply_boon 首次获得时的字段一一对应）
## 解锁 / 替换 / 开关类（max_star=1，不会走到这里）不在此映射内。
func _apply_numeric_boon_delta(effect_type: String, delta) -> void:
	match effect_type:
		"sword_damage_bonus", "sword_heavy":
			sword_damage_bonus += int(delta)
		"sword_pierce_bonus":
			sword_pierce_bonus += int(delta)
		"attack_cooldown_bonus":
			attack_cooldown = max(0.15, attack_cooldown + float(delta))
		"sword_width_bonus":
			sword_width_bonus += int(delta)
		"beast_attack_speed":
			beast_attack_speed_multiplier += float(delta)
			update_wolf_attack_speed()
		"wolf_damage_bonus":
			wolf_damage_bonus += int(delta)
			update_wolf_damage()
		"wolf_move_speed_bonus":
			wolf_move_speed_multiplier += float(delta)
			update_wolf_move_speed()
		"poison_duration_bonus":
			poison_duration_bonus += float(delta)
		"poison_radius_bonus":
			poison_radius_bonus += int(delta)
		"poison_damage_bonus":
			poison_damage_bonus += int(delta)
		"poison_first_stack_ratio":
			poison_first_stack_ratio_bonus += float(delta)
		# ===== 第一阶段新增 =====
		"attack_cooldown_bonus":
			# 基础攻击冷却减少（delta 为负），下限 0.15
			attack_cooldown = max(0.15, attack_cooldown + float(delta))
		"dash_cooldown_bonus":
			# 冲刺冷却减少（delta 为负），下限 0.8
			dash_cooldown = max(0.8, dash_cooldown + float(delta))
		"max_hp_bonus":
			# 气血上限提升，并同步把增量补到当前气血（升星时只补差值）
			var hp_delta: int = int(delta)
			if hp_delta != 0:
				vitals.set_max_qi_blood(vitals.get_max_qi_blood() + hp_delta, false)
				if hp_delta > 0:
					vitals.heal(hp_delta)
		"hp_regen":
			# 定时回血量增加（首次拥有时启动结算计时）
			var was_off: bool = hp_regen_per_tick <= 0
			hp_regen_per_tick = max(0, hp_regen_per_tick + int(delta))
			if was_off and hp_regen_per_tick > 0:
				_hp_regen_timer = hp_regen_interval
		"sword_root_bonus":
			sword_root += int(delta)
		"poison_root_bonus":
			poison_root += int(delta)
		"beast_root_bonus":
			beast_root += int(delta)
			# 兽灵根驱动灵狼攻击，刷新已存活灵狼的缓存攻击力
			update_wolf_damage()
		# ===== 第二阶段扩展机缘的数值字段 =====
		"sword_lifesteal":
			sword_lifesteal_amount += int(delta)
		"sword_mark_interval":
			# 剑痕触发间隔 N（star_values 递减 → delta 为负），下限 1
			sword_mark_interval = max(1, sword_mark_interval + int(delta))
		"beast_pack":
			beast_pack_per_wolf += float(delta)
		"beast_mark_amp":
			beast_mark_bonus += float(delta)
		"beast_frenzy":
			beast_frenzy_bonus += float(delta)
			# 若狂热正激活，立即把新攻速同步给灵狼
			if _beast_frenzy_active:
				update_wolf_attack_speed()
		"poison_slow":
			poison_slow_bonus += float(delta)
		"poison_dart_chance":
			poison_dart_poison_chance += float(delta)
		"poison_curse":
			poison_curse_bonus += float(delta)
		"dash_count":
			# 增加最大冲刺次数，并把新增的次数立即补足为可用
			var add: int = int(delta)
			dash_charge_max = max(1, dash_charge_max + add)
			if add > 0:
				dash_charges = min(dash_charges + add, dash_charge_max)
		_:
			# 未映射（解锁/替换类或未知）：升星无数值差值
			pass


## 复合灵根机缘应用（effect_values 字典，按每星增量各加一次）。
## 首次获得（升到 1 星）应用一次，之后每升一星再应用一次，累计即总加成。
func _apply_composite_root(values) -> void:
	if not values is Dictionary:
		return
	var beast_changed: bool = false
	for key in values:
		var amt: int = int(values[key])
		match key:
			"sword_root":
				sword_root += amt
			"poison_root":
				poison_root += amt
			"beast_root":
				beast_root += amt
				beast_changed = true
	if beast_changed:
		update_wolf_damage()
	stats_changed.emit()


## 抽取一组机缘候选（供机缘面板刷新调用：升星 + 前置 + 加权逻辑）
func roll_boon_options(count: int = 3) -> Array:
	return _boon_manager.roll_boons(_owned_boons_dict(), school_counts, count)


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

	# 轻量调试：获得机缘时输出一次 effect_type / 最终值 / 天品信息（不每帧刷屏）
	print("[机缘] ", boon.get("id", "?"), " type=", boon.get("effect_type", ""),
		" final=", fv, " grade=", boon.get("grade_id", "fan"),
		(" tian=" + str(boon.get("tian_effect_type", ""))) if boon.get("grade_id", "fan") == "tian" else "")

	# 替换身法：统一按 effect_type 处理，同一时间仅一个 dash_type 生效（新的替换旧的）
	if boon.get("effect_type", "") == "replace_dash":
		dash_type = str(boon.get("effect_value", "normal"))
		print("身法已替换为：", dash_type)
		return

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
			# 毒性强化：中毒第一层每跳比例 +5%（按毒灵根）
			poison_first_stack_ratio_bonus += float(fv)
			print("已获得机缘：", label, "，中毒第一层伤害 +", float(fv) * 100.0, "%")
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
			# 双狼同行：灵狼上限 +1
			max_wolf_count += 1
			if alpha_wolf_enabled:
				# 狼王模式：不召唤新狼，而是把上限转化为狼王强化层数并刷新属性
				_refresh_alpha_wolf()
			else:
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
		# ===== 基础 / 通用强化（第一阶段新增）=====
		# 标量数值类：首次获得 = 从 0 起的差值，直接复用差值应用逻辑，保证与升星对称
		"basic_atk_speed", "basic_vitality", "basic_regen", "dash_cd_reduce", \
		"root_sword_plus", "root_poison_plus", "root_beast_plus":
			_apply_numeric_boon_delta(boon.get("effect_type", ""), fv)
			print("已获得机缘：", label)
		# 复合灵根类：每次获得 / 升星按 effect_values 增量各加一次
		"root_dual_sp", "root_dual_bs", "root_dual_pb":
			_apply_composite_root(fv)
			print("已获得机缘：", label)
		# ===== 第二阶段扩展机缘 =====
		"sword_chain":
			# 剑气连斩（解锁型开关）
			sword_chain_enabled = true
			print("已获得机缘：", label, "，剑气斩杀普通敌人后重置攻击冷却")
		"beast_frenzy":
			# 嗜血之怒：解锁开关 + 攻速加成（首次为从 0 起的差值）
			beast_frenzy_enabled = true
			_apply_numeric_boon_delta("beast_frenzy", fv)
			print("已获得机缘：", label)
		"poison_slow":
			# 沉疴：解锁开关 + 减速比例
			poison_slow_enabled = true
			_apply_numeric_boon_delta("poison_slow", fv)
			print("已获得机缘：", label)
		"poison_cursed":
			# 蛊咒：解锁开关 + 承伤提高比例
			poison_curse_enabled = true
			_apply_numeric_boon_delta("poison_curse", fv)
			print("已获得机缘：", label)
		# 纯数值扩展类：首次获得 = 从 0 起的差值，复用差值逻辑保证升星对称
		"sword_lifesteal", "sword_mark", "beast_pack", "beast_mark_amp", "poison_dart_multi":
			_apply_numeric_boon_delta(boon.get("effect_type", ""), fv)
			print("已获得机缘：", label)
		# 连环冲刺：增加最大冲刺次数（max_star=1，单次获得）
		"dash_double":
			_apply_numeric_boon_delta("dash_count", fv)
			print("已获得机缘：", label, "，冲刺次数 +", int(fv))
		# ===== 第五阶段：高复杂机缘 =====
		"beast_alpha":
			# 狼王降临：开启狼王模式，回收普通灵狼并召唤唯一狼王
			alpha_wolf_enabled = true
			_clear_all_wolves()
			summon_spirit_wolf()
			print("狼王降临：进入狼王模式")
		"poison_spore":
			# 毒孢爆裂：毒爆范围 +40 并附加晕眩
			poison_explosion_radius_bonus += int(fv)
			poison_spore_stun_enabled = true
			print("已获得机缘：", label, "，毒爆附加晕眩")
		# ===== 基础攻击替换 =====
		"sword_qi_art":
			# 剑气术：解锁并切换基础攻击为剑气（远程）
			if not "sword_qi" in unlocked_primary_attacks:
				unlocked_primary_attacks.append("sword_qi")
			primary_attack_type = "sword_qi"
			print("基础攻击已替换为剑气")
		"sword_slash_art":
			# 击剑：解锁并切换基础攻击为击剑（剑体系近战）
			if not "sword_slash" in unlocked_primary_attacks:
				unlocked_primary_attacks.append("sword_slash")
			primary_attack_type = "sword_slash"
			print("基础攻击已替换为击剑")
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


## 基础攻击 id -> 说明（未知 id 返回空串）
func get_primary_attack_description(attack_id: String) -> String:
	return PRIMARY_ATTACK_DESCRIPTIONS.get(attack_id, "")


## 技能 id -> 说明（空槽返回占位说明）
func get_skill_description(skill_id: String) -> String:
	if skill_id == "":
		return "空：当前键位未绑定技能。"
	return SKILL_DESCRIPTIONS.get(skill_id, "")


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


## 召唤一只灵狼（受最大数量限制）；狼王模式下改为召唤 / 刷新唯一狼王
func summon_spirit_wolf() -> void:
	# 狼王模式：始终最多 1 只狼王
	if alpha_wolf_enabled:
		if get_alive_wolf_count() >= 1:
			_refresh_alpha_wolf()
		else:
			_summon_alpha_wolf()
		return

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
		var wolf_hp: int = get_wolf_max_hp()
		# 天品「召唤护体」：新召唤灵狼额外 +20% 气血（无护盾系统的最小实现）
		if tian_wolf_spawn_shield:
			wolf_hp = int(round(wolf_hp * 1.2))
		wolf.vitals.set_max_qi_blood(wolf_hp, true)
	wolf.attack_damage = get_wolf_damage()
	wolf.move_speed = get_wolf_move_speed()
	update_wolf_attack_speed()
	stats_changed.emit()


## 灵狼 / 狼王实际移速（含兽灵根精通天品 +10%）
func get_wolf_move_speed() -> float:
	var m: float = wolf_move_speed_multiplier
	if tian_beast_root_mastery and _is_root_highest("beast"):
		m *= 1.1
	return WOLF_BASE_MOVE_SPEED * m


## 某灵根是否为三灵根中的最高（并列最高也算）
func _is_root_highest(which: String) -> bool:
	match which:
		"sword":
			return sword_root >= poison_root and sword_root >= beast_root
		"poison":
			return poison_root >= sword_root and poison_root >= beast_root
		"beast":
			return beast_root >= sword_root and beast_root >= poison_root
	return false


# ===== 狼王（beast_alpha）=====

## 召唤唯一狼王
func _summon_alpha_wolf() -> void:
	var wolf := SPIRIT_WOLF_SCENE.instantiate()
	get_parent().add_child(wolf)
	wolf.global_position = global_position + Vector2(
		randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)
	)
	if wolf.has_method("setup"):
		wolf.setup(self)
	# 标记为狼王（放大体型 / 标志位，复用灵狼场景）
	if wolf.has_method("mark_as_alpha"):
		wolf.mark_as_alpha()
	summoned_wolves.append(wolf)
	_apply_alpha_stats(wolf, true)
	update_wolf_attack_speed()
	stats_changed.emit()


## 刷新现存狼王属性（强化层数变化时调用，不回满气血避免刷血）
func _refresh_alpha_wolf() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			_apply_alpha_stats(wolf, false)
			update_wolf_attack_speed()
			return


## 计算并套用狼王属性（稳定线性公式，layers = max_wolf_count - 1）
func _apply_alpha_stats(wolf: Node, refill: bool) -> void:
	var layers: int = max(0, max_wolf_count - 1)
	var hp: int = int(round(get_wolf_max_hp() * (1.6 + 0.25 * float(layers))))
	var dmg: int = int(round(get_wolf_damage() * (1.4 + 0.15 * float(layers))))
	if wolf.vitals != null:
		wolf.vitals.set_max_qi_blood(hp, refill)
	wolf.attack_damage = dmg
	wolf.move_speed = get_wolf_move_speed()


## 回收当前全部灵狼（获得狼王时清场）
func _clear_all_wolves() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.queue_free()
	summoned_wolves.clear()


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


## 把当前攻速倍率同步到所有存活灵狼（含嗜血之怒临时加成）
func update_wolf_attack_speed() -> void:
	var m: float = get_effective_beast_attack_speed()
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.attack_speed_multiplier = m


## 把当前伤害加成同步到所有存活灵狼
func update_wolf_damage() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.attack_damage = get_wolf_damage()


## 把当前移速倍率同步到所有存活灵狼（含兽灵根精通天品）
func update_wolf_move_speed() -> void:
	var spd: float = get_wolf_move_speed()
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.move_speed = spd


## 是否还有存活的灵狼
func has_alive_wolf() -> bool:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			return true
	return false


## 玩家统一受伤入口（妖兽攻击经此处理，便于灵兽护主减伤）
func receive_damage(amount: int) -> void:
	# 冲刺无敌帧：免疫本次伤害
	if _invincible_timer > 0.0:
		return
	var final_damage: int = amount
	# 灵兽护主：拥有存活灵狼时分担部分伤害
	if beast_guard_enabled and has_alive_wolf():
		var reduced: int = int(round(amount * beast_guard_ratio))
		final_damage = amount - reduced
		print("灵兽护主，减免伤害：", reduced)
	# 天品「群狼护持」：灵狼数量达到上限时玩家减伤
	if tian_pack_guard and get_alive_wolf_count() >= max_wolf_count and max_wolf_count > 0:
		final_damage = int(round(final_damage * (1.0 - 0.15)))
	# 临时护盾（天品「噬血溢盾」）：优先抵扣
	if shield_hp > 0 and final_damage > 0:
		var absorbed: int = min(shield_hp, final_damage)
		shield_hp -= absorbed
		final_damage -= absorbed
		stats_changed.emit()
	if final_damage > 0:
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
	# 中毒来源毒灵根 = 玩家毒灵根；附带毒蛊机缘固定加成（DOT 由 StatusEffects 按层数结算）
	mist.source_poison_root = poison_root
	mist.poison_bonus_per_tick = poison_damage_bonus
	mist.poison_ratio_bonus = poison_first_stack_ratio_bonus
	mist.poison_explosion_enabled = poison_explosion_enabled
	# 毒爆范围与伤害（含专精「万毒扩散」加成）
	mist.explosion_radius = 120.0 + poison_explosion_radius_bonus
	mist.explosion_damage = 8 + poison_explosion_damage_bonus
	# 持续时间加成（机缘「毒雾延绵」）与范围加成（机缘「毒域扩张」）
	mist.duration += poison_duration_bonus
	mist.radius_bonus = poison_radius_bonus
	# 毒蛊联动：减速（沉疴）/ 蛊咒配置，随中毒下发到目标 StatusEffects
	mist.poison_slow_enabled = poison_slow_enabled
	mist.poison_slow_multiplier = get_poison_slow_multiplier()
	mist.poison_curse_enabled = poison_curse_enabled
	mist.poison_curse_multiplier = get_poison_curse_multiplier()
	# 天品「毒爆余烬」：毒爆后留小毒云
	mist.poison_spore_enabled = tian_spore_poison_cloud
	# 毒孢爆裂晕眩 / 蛊咒传播 / 中毒时长（含毒灵根精通天品）
	mist.poison_spore_stun_enabled = poison_spore_stun_enabled
	mist.poison_spore_stun_duration = POISON_SPORE_STUN_DURATION
	mist.poison_curse_spread_enabled = tian_curse_spread
	mist.poison_dot_duration = get_poison_dot_duration()
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

## 读取某技能的冷却快照（只读现有计时器，不改冷却逻辑）
func get_skill_cooldown(skill_id: String) -> Dictionary:
	var timer: float = 0.0
	var cd: float = 0.0
	match skill_id:
		"summon_wolf":
			timer = wolf_summon_timer
			cd = wolf_summon_cooldown
		"poison_mist":
			timer = _poison_cast_timer
			cd = poison_cast_cooldown
	var progress: float = 1.0 if cd <= 0.0 else clampf(1.0 - timer / cd, 0.0, 1.0)
	return {
		"remaining": max(0.0, timer),
		"cooldown": cd,
		"ready": timer <= 0.0,
		"progress": progress,
	}


## 返回 HUD 需要的数据快照（战斗必要信息）
func get_hud_data() -> Dictionary:
	# 技能槽位显示：{ Q/E/F -> 技能名 或 "空" }
	var skill_slots_display: Dictionary = {}
	# 技能槽位冷却：{ Q/E/F -> { skill_id / name / cooldown 快照 } }
	var skill_slots_cooldown: Dictionary = {}
	for key in ["Q", "E", "F"]:
		var skill_id: String = skill_slots.get(key, "")
		skill_slots_display[key] = get_skill_display_name(skill_id) if skill_id != "" else "空"
		skill_slots_cooldown[key] = {
			"skill_id": skill_id,
			"name": get_skill_display_name(skill_id) if skill_id != "" else "",
			"cooldown": get_skill_cooldown(skill_id),
		}

	return {
		"skill_slots_cooldown": skill_slots_cooldown,
		"current_hp": vitals.get_current_qi_blood(),
		"max_hp": vitals.get_max_qi_blood(),
		"cultivation_exp": cultivation_exp,
		"cultivation_exp_required": cultivation_exp_required,
		"can_breakthrough": can_breakthrough(),
		"heavenly_stones": heavenly_stones,
		"primary_attack_name": get_primary_attack_display_name(primary_attack_type),
		"skill_slots_display": skill_slots_display,
		# 冲刺（身法）冷却数据，供 HUD 冷却条显示
		"dash_cooldown": dash_cooldown,
		"dash_cooldown_timer": dash_recharge_timer if dash_charges < dash_charge_max else 0.0,
		# 有可用次数即视为可冲刺
		"dash_ready": dash_charges > 0,
		# 充能进度：满电为 1，否则为当前充能完成度
		"dash_cooldown_progress": (1.0 if dash_charges >= dash_charge_max
			else (clampf(1.0 - dash_recharge_timer / dash_cooldown, 0.0, 1.0) if dash_cooldown > 0.0 else 1.0)),
		# 冲刺次数（供 HUD 显示，可选）
		"dash_charges": dash_charges,
		"dash_charge_max": dash_charge_max,
		"dash_type": dash_type,
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


## 返回构筑页「数值预览」需要的数据快照：灵根 / 实际战斗数值 / 基础攻击与技能说明
func get_combat_preview_data() -> Dictionary:
	# 技能槽位显示名与说明：{ Q/E/F -> 名称 / 说明 }
	var skill_slots_display: Dictionary = {}
	var skill_descriptions: Dictionary = {}
	for key in ["Q", "E", "F"]:
		var skill_id: String = skill_slots.get(key, "")
		skill_slots_display[key] = get_skill_display_name(skill_id) if skill_id != "" else "空"
		skill_descriptions[key] = get_skill_description(skill_id)

	return {
		# 灵根原始数值
		"sword_root": sword_root,
		"poison_root": poison_root,
		"beast_root": beast_root,
		# 灵根驱动的实际战斗数值（含机缘加成）
		"sword_damage": get_sword_damage(),
		"poison_damage": get_poison_damage(),
		"wolf_max_hp": get_wolf_max_hp(),
		"wolf_damage": get_wolf_damage(),
		"beast_whip_damage": get_beast_whip_damage(),
		# 狼王模式（beast_alpha）：是否开启 + 狼王属性预览
		"alpha_wolf_enabled": alpha_wolf_enabled,
		"alpha_wolf_hp": int(round(get_wolf_max_hp() * (1.6 + 0.25 * float(max(0, max_wolf_count - 1))))),
		"alpha_wolf_damage": int(round(get_wolf_damage() * (1.4 + 0.15 * float(max(0, max_wolf_count - 1))))),
		"alpha_wolf_layers": max(0, max_wolf_count - 1),
		# 当前基础攻击及其说明
		"primary_attack_type": primary_attack_type,
		"primary_attack_name": get_primary_attack_display_name(primary_attack_type),
		"primary_attack_description": get_primary_attack_description(primary_attack_type),
		# 技能栏说明
		"skill_slots_display": skill_slots_display,
		"skill_descriptions": skill_descriptions,
	}
