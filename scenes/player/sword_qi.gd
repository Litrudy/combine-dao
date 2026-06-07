extends Area2D
## 剑气（玩家基础攻击投射物）
## M1 任务 4 / 7 —— 朝指定方向飞行，命中妖兽造成伤害。
## 剑气流机缘：支持穿透、残血斩杀。

## 命中伤害
@export var damage: int = 12
## 飞行速度（像素 / 秒）
@export var speed: float = 500.0
## 存活时间（秒），超时自动消失
@export var life_time: float = 0.5

## 飞行方向（由生成方传入，需为单位向量）
var direction: Vector2 = Vector2.RIGHT

## 剩余可穿透敌人数（额外穿透次数，由「剑气穿透」机缘提供）
var pierce_remaining: int = 0
## 是否可斩杀残血敌人（由「残血斩杀」机缘提供）
var execute_enabled: bool = false
## 斩杀血量阈值（当前气血 / 最大气血 低于此值时斩杀，由玩家释放时传入）
var execute_threshold: float = 0.2

## 剑气宽度加成（机缘「剑气扩幅」，由玩家释放时传入）
var width_bonus: int = 0

## 释放剑气的玩家（用于斩杀联动机缘回调）
var owner_player: Node = null
## 剑气噬血：斩杀时回复气血量（0 表示未拥有，机缘「剑气噬血」）
var lifesteal_amount: int = 0
## 剑气连斩：斩杀普通敌人后重置玩家基础攻击冷却（机缘「剑气连斩」）
var chain_enabled: bool = false
## 天品「穿透爆裂」：穿透到最后一个目标后在末端产生一次小范围伤害
var tail_explosion_enabled: bool = false
## 末端爆裂半径与伤害占比（占当前剑气伤害）
const TAIL_EXPLOSION_RADIUS: float = 50.0
const TAIL_EXPLOSION_RATIO: float = 0.5

## 天品「剑痕易伤」：命中易伤目标享受额外伤害（一次性消耗）
var vuln_consume_enabled: bool = false
## 本道剑气命中后是否给目标挂易伤（仅剑痕触发的那一道）
var vuln_apply_on_hit: bool = false
## 易伤倍率与持续时间
const VULN_MULT: float = 1.5
const VULN_DURATION: float = 3.0

## 已命中过的目标，避免同一剑气对同一妖兽重复造成伤害
var _hit_targets: Array = []


func _ready() -> void:
	# 让剑气朝向与飞行方向一致
	rotation = direction.angle()
	# 根据宽度加成横向加宽（垂直于飞行方向的 y 轴）
	# 用乘法叠加，兼容 Visual 自身已设置的基础缩放（如 0.07 像素图缩放）
	if width_bonus > 0:
		var width_scale: float = 1.0 + width_bonus * 0.6
		$CollisionShape2D.scale.y *= width_scale
		$Visual.scale.y *= width_scale
	# 进入其他物体区域时触发命中判定
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 到达存活时间后自动销毁
	get_tree().create_timer(life_time).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	# 按方向匀速飞行
	global_position += direction * speed * delta


## 命中物理体（CharacterBody2D 等）
func _on_body_entered(body: Node) -> void:
	# 命中环境（墙体 / 地图障碍 / 事件阻挡体，均为 StaticBody2D）：销毁剑气（无视穿透），不造成伤害
	if _is_environment(body):
		queue_free()
		return
	_try_hit(body)


## 命中区域（Area2D），兼容妖兽用 Area 作为受击体的情况
func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## 是否为环境阻挡物（墙体 / 障碍 / 事件阻挡体）
func _is_environment(node: Node) -> bool:
	return node is StaticBody2D or node.is_in_group("map_wall") or node.is_in_group("map_obstacle")


## 尝试对目标造成伤害
func _try_hit(target: Node) -> void:
	# 只攻击 "enemy" 组的妖兽
	if not target.is_in_group("enemy"):
		return

	# 同一剑气不对同一妖兽重复造成伤害
	if target in _hit_targets:
		return
	_hit_targets.append(target)

	# 查找妖兽的 Vitals 与 StatusEffects 子节点
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	var status: Node = target.get_node_or_null("StatusEffects")
	if enemy_vitals != null:
		if execute_enabled and not target.is_in_group("boss") and _is_executable(enemy_vitals):
			# 残血斩杀：造成等于当前气血的伤害，直接击杀（Boss 免疫斩杀）
			enemy_vitals.take_damage(enemy_vitals.current_qi_blood)
			# 斩杀联动机缘（噬血回血 / 连斩重置冷却）
			_on_execute_kill(target)
		else:
			# 普通命中：造成剑气伤害（天品剑痕易伤：先消耗目标易伤获得额外伤害）
			var dmg_dealt: int = damage
			if vuln_consume_enabled and status != null and status.has_method("consume_sword_vuln"):
				var m: float = status.consume_sword_vuln()
				if m != 1.0:
					dmg_dealt = int(round(damage * m))
			enemy_vitals.take_damage(dmg_dealt)
			# 剑痕触发的这一道：命中后给目标挂上易伤（供下一道剑气消耗）
			if vuln_apply_on_hit and status != null and status.has_method("apply_sword_vuln"):
				status.apply_sword_vuln(VULN_DURATION, VULN_MULT)

	# 穿透处理：仍有穿透次数则继续飞行，否则在末端结算后消失
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		# 天品「穿透爆裂」：穿透到最后一个目标后在该处产生一次小范围爆裂
		if tail_explosion_enabled and target is Node2D:
			_do_tail_explosion((target as Node2D).global_position, target)
		queue_free()


## 末端剑气爆裂：对落点附近敌人各造成一次（伤害为当前剑气伤害的 50%）
func _do_tail_explosion(center: Vector2, exclude: Node) -> void:
	var blast: int = int(round(damage * TAIL_EXPLOSION_RATIO))
	if blast <= 0:
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == exclude or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var ev: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if ev == null or ev.is_dead():
			continue
		if center.distance_to((enemy as Node2D).global_position) <= TAIL_EXPLOSION_RADIUS:
			ev.take_damage(blast)


## 斩杀击杀后触发的联动机缘：噬血回血 + 连斩重置冷却（仅普通敌人，Boss 不触发）
func _on_execute_kill(target: Node) -> void:
	if not is_instance_valid(owner_player):
		return
	# 剑气噬血：回复气血
	if lifesteal_amount > 0 and owner_player.has_method("on_sword_lifesteal"):
		owner_player.on_sword_lifesteal(lifesteal_amount)
	# 剑气连斩：仅普通敌人重置基础攻击冷却（Boss 不触发，避免无限循环）
	if chain_enabled and not target.is_in_group("boss") and owner_player.has_method("on_sword_chain_kill"):
		owner_player.on_sword_chain_kill()


## 判断妖兽是否处于可斩杀的残血状态（气血占比低于阈值）
func _is_executable(enemy_vitals: Vitals) -> bool:
	if enemy_vitals.max_qi_blood <= 0:
		return false
	return float(enemy_vitals.current_qi_blood) / float(enemy_vitals.max_qi_blood) < execute_threshold
