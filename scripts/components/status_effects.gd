extends Node
class_name StatusEffects
## 状态组件
## 负责中毒（可叠层 DOT）与御兽标记。挂在妖兽 / Boss 上，与 Vitals 同级。

## 中毒固定规则（按需求）：持续 5 秒、最高 5 层
const POISON_DURATION: float = 5.0
const POISON_MAX_STACK: int = 5
## 中毒结算间隔（每秒一次）
const POISON_TICK_INTERVAL: float = 1.0

## 毒云场景（天品「毒爆余烬」用，运行时实例化小毒云）
const POISON_MIST_SCENE: PackedScene = preload("res://scenes/player/poison_mist.tscn")

## 同级气血组件
@onready var _vitals: Vitals = get_parent().get_node_or_null("Vitals")

# ===== 中毒状态 =====
## 当前毒层数
var _poison_stacks: int = 0
## 毒剩余持续时间
var _poison_time_left: float = 0.0
## 距离下次毒结算的剩余时间
var _poison_tick_timer: float = 0.0
## 中毒来源（施加者）的毒灵根，用于计算每跳伤害
var _poison_source_root: int = 0
## 中毒来源附带的每跳额外固定毒伤（毒蛊机缘加成，可为 0）
var _poison_bonus_per_tick: int = 0
## 中毒第一层比例加成（机缘「毒性强化」，每跳比例额外 +此值，默认 0）
var _poison_ratio_bonus: float = 0.0
# ----- 毒爆（可选，由毒雾在施加中毒时配置）-----
var _poison_explosion_enabled: bool = false
var _poison_explosion_radius: float = 0.0
var _poison_explosion_damage: int = 0
# ----- 沉疴减速（机缘「沉疴」，中毒 >=3 层时降低移速）-----
var _poison_slow_enabled: bool = false
var _poison_slow_multiplier: float = 1.0
## 触发减速所需的最低毒层数
const POISON_SLOW_MIN_STACK: int = 3
# ----- 蛊咒承伤（机缘「蛊咒」，中毒满 5 层时受到所有伤害提高）-----
var _curse_enabled: bool = false
var _curse_damage_multiplier: float = 1.0
# ----- 毒爆余烬（天品「毒爆余烬」，毒爆后留小毒云）-----
var _spore_enabled: bool = false
# ----- 毒孢晕眩（机缘「毒孢爆裂」，毒爆对范围内敌人附加晕眩）-----
var _spore_stun_enabled: bool = false
var _spore_stun_duration: float = 0.0
# ----- 蛊咒传播（天品「蛊咒·传播」，诅咒目标死亡向附近传毒）-----
var _curse_spread_enabled: bool = false
# ----- 中毒持续时间（可由施加者覆盖，用于毒灵根精通天品 +0.5s）-----
var _poison_duration: float = POISON_DURATION
# ----- 晕眩（机缘「毒孢爆裂」）：剩余时间，Boss 仅吃 30% 时长 -----
var _stun_time_left: float = 0.0
const BOSS_STUN_RATIO: float = 0.3
# ----- 剑痕易伤（天品「剑痕易伤」）：一次性，命中后消耗 -----
var _sword_vuln_time_left: float = 0.0
var _sword_vuln_mult: float = 1.0

# ===== 御兽标记 =====
## 御兽标记剩余时间
var _beast_mark_time_left: float = 0.0
## 御兽标记伤害倍率（仅作用于召唤物伤害）
var _beast_mark_multiplier: float = 1.0
## 御兽标记是否在目标死亡时转移给最近敌人（天品「标记转移」）
var _beast_mark_transfer: bool = false


func _ready() -> void:
	# 监听宿主死亡，用于「标记转移」天品能力（多重连接无害，防御性检查）
	if is_instance_valid(_vitals) and not _vitals.died.is_connected(_on_host_died):
		_vitals.died.connect(_on_host_died)


func _process(delta: float) -> void:
	_process_poison(delta)
	_process_beast_mark(delta)
	# 晕眩 / 剑痕易伤计时递减
	if _stun_time_left > 0.0:
		_stun_time_left -= delta
	if _sword_vuln_time_left > 0.0:
		_sword_vuln_time_left -= delta


## 施加中毒（创建或叠加）：刷新持续时间、毒层 +1（封顶 5）。
## source_poison_root：施加者（攻击者）毒灵根；bonus_per_tick：每跳额外固定毒伤；
## duration：中毒持续时间（默认 POISON_DURATION，可由毒灵根精通天品延长）。
func apply_poison(source_poison_root: int, bonus_per_tick: int = 0, ratio_bonus: float = 0.0, duration: float = POISON_DURATION) -> void:
	# 从无毒进入中毒时，重置结算计时
	if _poison_stacks <= 0:
		_poison_tick_timer = POISON_TICK_INTERVAL
	_poison_source_root = source_poison_root
	_poison_bonus_per_tick = bonus_per_tick
	_poison_ratio_bonus = ratio_bonus
	_poison_duration = duration
	_poison_stacks = min(_poison_stacks + 1, POISON_MAX_STACK)
	_poison_time_left = duration


## 仅在“已中毒”时叠加并刷新（毒镖用）：不会让未中毒目标中毒。
## 已中毒返回 true（叠层 +1、刷新持续时间），未中毒返回 false（不创建）。
func add_poison_stack_if_present() -> bool:
	if _poison_stacks <= 0:
		return false
	_poison_stacks = min(_poison_stacks + 1, POISON_MAX_STACK)
	_poison_time_left = _poison_duration
	return true


## 配置毒孢晕眩（机缘「毒孢爆裂」，由毒雾 / 毒镖在施加中毒时调用，可选）
func configure_poison_spore_stun(enabled: bool, duration: float) -> void:
	_spore_stun_enabled = enabled
	_spore_stun_duration = duration


## 配置蛊咒传播（天品，由毒雾 / 毒镖在施加中毒时调用，可选）
func configure_poison_curse_spread(enabled: bool) -> void:
	_curse_spread_enabled = enabled


## 施加晕眩（Boss 仅吃 BOSS_STUN_RATIO 时长，避免无限硬控）
func apply_stun(duration: float) -> void:
	var dur: float = duration
	var host: Node = get_parent()
	if host != null and host.is_in_group("boss"):
		dur *= BOSS_STUN_RATIO
	_stun_time_left = max(_stun_time_left, dur)


## 当前是否被晕眩（供敌人移动 / 攻击逻辑读取）
func is_stunned() -> bool:
	return _stun_time_left > 0.0


## 施加剑痕易伤（一次性：命中消耗）
func apply_sword_vuln(duration: float, multiplier: float) -> void:
	_sword_vuln_time_left = duration
	_sword_vuln_mult = multiplier


## 消耗剑痕易伤：有效则返回额外倍率并清除，否则返回 1.0
func consume_sword_vuln() -> float:
	if _sword_vuln_time_left > 0.0:
		_sword_vuln_time_left = 0.0
		return _sword_vuln_mult
	return 1.0


## 配置毒爆（由毒雾在施加中毒时调用，可选）
func configure_poison_explosion(enabled: bool, radius: float, damage: int) -> void:
	_poison_explosion_enabled = enabled
	_poison_explosion_radius = radius
	_poison_explosion_damage = damage


## 配置沉疴减速（由毒雾 / 毒镖在施加中毒时调用，可选）
func configure_poison_slow(enabled: bool, multiplier: float) -> void:
	_poison_slow_enabled = enabled
	_poison_slow_multiplier = multiplier


## 配置蛊咒承伤（由毒雾 / 毒镖在施加中毒时调用，可选）
func configure_poison_curse(enabled: bool, multiplier: float) -> void:
	_curse_enabled = enabled
	_curse_damage_multiplier = multiplier


## 配置毒爆余烬（天品「毒爆余烬」，由毒雾 / 毒镖在施加中毒时调用，可选）
func configure_poison_spore(enabled: bool) -> void:
	_spore_enabled = enabled


## 当前移速倍率（沉疴：中毒 >=3 层时返回减速倍率，否则 1.0）。供宿主移动读取。
func get_move_speed_multiplier() -> float:
	if _poison_slow_enabled and _poison_stacks >= POISON_SLOW_MIN_STACK:
		return _poison_slow_multiplier
	return 1.0


## 当前承伤倍率（蛊咒：中毒满 5 层时返回增伤倍率，否则 1.0）。供 Vitals 读取，作用于所有伤害源。
func get_damage_taken_multiplier() -> float:
	if _curse_enabled and _poison_stacks >= POISON_MAX_STACK:
		return _curse_damage_multiplier
	return 1.0


## 当前是否处于中毒
func is_poisoned() -> bool:
	return _poison_stacks > 0


## 当前毒层数
func get_poison_stacks() -> int:
	return _poison_stacks


## 每帧处理中毒结算
func _process_poison(delta: float) -> void:
	if _poison_stacks <= 0:
		return

	_poison_time_left -= delta
	_poison_tick_timer -= delta
	# 到达结算间隔：每跳伤害 = 毒灵根 * (0.10 + (层数-1) * 0.05) + 额外固定毒伤
	if _poison_tick_timer <= 0.0:
		_poison_tick_timer = POISON_TICK_INTERVAL
		if is_instance_valid(_vitals) and not _vitals.is_dead():
			var ratio: float = 0.10 + _poison_ratio_bonus + float(_poison_stacks - 1) * 0.05
			var tick_damage: int = int(round(float(_poison_source_root) * ratio)) + _poison_bonus_per_tick
			var was_alive: bool = not _vitals.is_dead()
			_vitals.take_damage(tick_damage, "poison")
			# 毒爆：本跳致死时扩散（中毒 DOT 自身，不走召唤物加成）
			if _poison_explosion_enabled and was_alive and _vitals.is_dead():
				_trigger_poison_explosion()
				# 天品「毒爆余烬」：毒爆后在原地留下小毒云
				if _spore_enabled:
					_spawn_spore_cloud()

	# 持续时间结束则清空毒层
	if _poison_time_left <= 0.0:
		_poison_stacks = 0


## 毒爆：对宿主周围其他妖兽扩散一次固定毒伤
func _trigger_poison_explosion() -> void:
	var host: Node = get_parent()
	if not host is Node2D:
		return
	var source_pos: Vector2 = (host as Node2D).global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == host or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if source_pos.distance_to((enemy as Node2D).global_position) > _poison_explosion_radius:
			continue
		var enemy_vitals: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if enemy_vitals != null and not enemy_vitals.is_dead():
			enemy_vitals.take_damage(_poison_explosion_damage)
			# 毒孢爆裂：对范围内敌人附加晕眩（Boss 在其自身 apply_stun 内限制时长）
			if _spore_stun_enabled:
				var es: Node = enemy.get_node_or_null("StatusEffects")
				if es != null and es.has_method("apply_stun"):
					es.apply_stun(_spore_stun_duration)


## 施加御兽标记（仅影响召唤物伤害）。transfer：目标死亡时是否转移标记（天品）。
func apply_beast_mark(duration: float, multiplier: float, transfer: bool = false) -> void:
	_beast_mark_time_left = duration
	_beast_mark_multiplier = multiplier
	_beast_mark_transfer = transfer


## 毒爆余烬：在宿主位置生成一团短暂小毒云（不再触发毒爆，避免连锁递归）
func _spawn_spore_cloud() -> void:
	if POISON_MIST_SCENE == null:
		return
	var host: Node = get_parent()
	if not host is Node2D:
		return
	var mist := POISON_MIST_SCENE.instantiate()
	mist.source_poison_root = _poison_source_root
	mist.poison_bonus_per_tick = _poison_bonus_per_tick
	mist.poison_ratio_bonus = _poison_ratio_bonus
	# 余烬云自身不再触发毒爆 / 减速 / 蛊咒（避免连锁与额外耦合）
	mist.poison_explosion_enabled = false
	mist.duration = 1.0
	# tick 间隔需小于持续时间，否则在到期前来不及施加一次毒
	mist.tick_interval = 0.4
	mist.radius_bonus = -32
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = host.get_parent()
	if scene_root == null:
		return
	scene_root.add_child(mist)
	mist.global_position = (host as Node2D).global_position


## 宿主死亡：处理「标记转移」与「蛊咒传播」两类天品
func _on_host_died() -> void:
	var host: Node = get_parent()
	if not host is Node2D:
		return
	var source_pos: Vector2 = (host as Node2D).global_position

	# 标记转移：把御兽标记交给最近的存活敌人（保留转移标志以链式传递）
	if _beast_mark_transfer and _beast_mark_time_left > 0.0:
		var nearest: Node = _nearest_other_enemy(host, source_pos)
		if nearest != null:
			var status: Node = nearest.get_node_or_null("StatusEffects")
			if status != null and status.has_method("apply_beast_mark"):
				status.apply_beast_mark(_beast_mark_time_left, _beast_mark_multiplier, true)

	# 蛊咒传播：若死亡时处于满层诅咒，向附近敌人传播部分毒层
	if _curse_spread_enabled and _poison_stacks >= POISON_MAX_STACK:
		const SPREAD_RADIUS: float = 120.0
		const SPREAD_STACKS: int = 2
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy == host or not is_instance_valid(enemy) or not enemy is Node2D:
				continue
			var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
			if ev != null and ev.is_dead():
				continue
			if source_pos.distance_to((enemy as Node2D).global_position) > SPREAD_RADIUS:
				continue
			var es: Node = enemy.get_node_or_null("StatusEffects")
			if es != null and es.has_method("apply_poison"):
				# 传播固定层数（不传播蛊咒/晕眩等配置，避免链式失控）
				for _i in SPREAD_STACKS:
					es.apply_poison(_poison_source_root, _poison_bonus_per_tick, _poison_ratio_bonus, _poison_duration)


## 最近的其它存活敌人（排除 host）
func _nearest_other_enemy(host: Node, source_pos: Vector2) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == host or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if ev != null and ev.is_dead():
			continue
		var d: float = source_pos.distance_to((enemy as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest


## 每帧处理御兽标记倒计时
func _process_beast_mark(delta: float) -> void:
	if _beast_mark_time_left > 0.0:
		_beast_mark_time_left -= delta


## 返回当前御兽标记伤害倍率（无标记返回 1.0）。仅供召唤物伤害结算使用。
func get_beast_damage_multiplier() -> float:
	if _beast_mark_time_left > 0.0:
		return _beast_mark_multiplier
	return 1.0
