extends CharacterBody2D
## 灵狼（御兽流召唤物）
## M1 任务 7C —— 自动寻找最近妖兽攻击；无妖兽时跟随玩家。
## 仅含追踪 / 攻击 / 跟随逻辑，不含召唤数量上限等复杂机制。

## 移动速度（像素 / 秒）
@export var move_speed: float = 140.0
## 单次攻击伤害
@export var attack_damage: int = 8
## 攻击范围（像素），进入此范围内攻击妖兽
@export var attack_range: float = 35.0
## 基础攻击冷却（秒）
@export var base_attack_cooldown: float = 1.0

## 攻击速度倍率（由「灵兽攻速提升」机缘修改，越大冷却越短）
var attack_speed_multiplier: float = 1.0
## 召唤它的玩家
var owner_player: Node2D = null

## 跟随玩家时保持的距离（像素），过近则不再靠近
const FOLLOW_DISTANCE: float = 60.0

## 当前攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0


func _ready() -> void:
	# 漂浮模式，适合俯视角无重力移动
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 加入 ally 分组
	add_to_group("ally")


## 由玩家调用，绑定主人
func setup(player: Node2D) -> void:
	owner_player = player


func _physics_process(delta: float) -> void:
	# 攻击冷却递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# 寻找最近的妖兽
	var target: Node2D = _find_nearest_enemy()

	if is_instance_valid(target):
		# 有妖兽：靠近并在范围内攻击
		var distance: float = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			# 进入攻击范围：停下并攻击
			velocity = Vector2.ZERO
			_try_attack(target)
		else:
			# 朝妖兽移动
			velocity = global_position.direction_to(target.global_position) * move_speed
	else:
		# 没有妖兽：跟随玩家，保持一定距离
		_follow_owner()

	move_and_slide()


## 寻找最近的 "enemy" 分组妖兽
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


## 跟随玩家，超出保持距离时靠近，否则停下
func _follow_owner() -> void:
	if not is_instance_valid(owner_player):
		velocity = Vector2.ZERO
		return

	var distance: float = global_position.distance_to(owner_player.global_position)
	if distance > FOLLOW_DISTANCE:
		velocity = global_position.direction_to(owner_player.global_position) * move_speed
	else:
		velocity = Vector2.ZERO


## 尝试攻击妖兽（受冷却限制）
func _try_attack(target: Node2D) -> void:
	# 冷却未结束则不攻击
	if _attack_timer > 0.0:
		return

	# 调用妖兽的 Vitals 子节点造成伤害
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null:
		enemy_vitals.take_damage(attack_damage)

	# 重置冷却：实际冷却 = 基础冷却 / 攻速倍率
	var effective_cooldown: float = base_attack_cooldown / max(attack_speed_multiplier, 0.01)
	_attack_timer = effective_cooldown
