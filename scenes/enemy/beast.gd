extends CharacterBody2D
## 妖兽
## M1 任务 3 —— 自动追踪并攻击 "player" 组中的玩家。
## 仅含追踪与攻击逻辑，不含玩家攻击 / 死亡掉落 / 机缘系统。

## 移动速度（像素 / 秒）
@export var move_speed: float = 80.0
## 攻击范围（像素），进入此范围内停止移动并攻击
@export var attack_range: float = 40.0
## 单次攻击伤害
@export var attack_damage: int = 5
## 攻击冷却时间（秒）
@export var attack_cooldown: float = 1.0
## 死亡时给予玩家的修为奖励
@export var cultivation_reward: int = 1
## 普通小怪掉落天道石的概率
@export var heavenly_stone_drop_chance: float = 0.12
## 普通小怪掉落天道石数量
@export var heavenly_stone_drop_amount: int = 1
## 是否为精英怪
@export var is_elite: bool = false
## 精英怪必掉天道石数量
@export var elite_drop_amount: int = 2

## 目标玩家节点
var _player: Node2D
## 当前攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0
## 死亡奖励是否已发放，保证只发放一次
var _reward_granted: bool = false
## 精英强化是否已应用，避免重复叠加
var _elite_applied: bool = false

## 自身气血组件（子节点 Vitals）
@onready var vitals: Vitals = $Vitals


func _ready() -> void:
	# 漂浮模式，适合俯视角无重力移动
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 精英怪强化
	if is_elite:
		_apply_elite_buff()
	# 气血归零时妖兽消失
	vitals.died.connect(_on_died)
	# 寻找 "player" 组中的玩家节点
	_acquire_player()


## 标记为精英怪并立即应用强化（供地图在 _ready 之后调用）
func make_elite() -> void:
	is_elite = true
	_apply_elite_buff()


## 精英怪基础强化：气血翻倍、伤害 +50%、移速 +10%、视觉变金色（只应用一次）
func _apply_elite_buff() -> void:
	if _elite_applied:
		return
	_elite_applied = true
	vitals.set_max_qi_blood(vitals.max_qi_blood * 2, true)
	attack_damage = int(attack_damage * 1.5)
	move_speed *= 1.1
	var visual := get_node_or_null("Visual")
	if visual != null:
		visual.color = Color(1.0, 0.84, 0.0)
	print("精英妖兽出现")


func _physics_process(delta: float) -> void:
	# 冷却计时递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# 选择攻击目标：玩家或更近的灵狼
	var target: Node2D = _select_target()
	if not is_instance_valid(target):
		_acquire_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 计算与目标的距离
	var distance: float = global_position.distance_to(target.global_position)

	if distance <= attack_range:
		# 进入攻击范围：停止移动并尝试攻击
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		# 否则朝目标方向移动
		var direction: Vector2 = global_position.direction_to(target.global_position)
		velocity = direction * move_speed

	move_and_slide()


## 选择攻击目标：默认玩家；若有更近的存活灵狼则优先攻击灵狼
func _select_target() -> Node2D:
	if not is_instance_valid(_player):
		_acquire_player()

	# 找最近的存活灵狼
	var nearest_wolf: Node2D = null
	var nearest_wolf_dist: float = INF
	for wolf in get_tree().get_nodes_in_group("ally"):
		if not is_instance_valid(wolf) or not wolf is Node2D:
			continue
		var wolf_vitals: Vitals = wolf.get_node_or_null("Vitals") as Vitals
		if wolf_vitals != null and wolf_vitals.is_dead():
			continue
		var d: float = global_position.distance_to(wolf.global_position)
		if d < nearest_wolf_dist:
			nearest_wolf_dist = d
			nearest_wolf = wolf

	if not is_instance_valid(_player):
		return nearest_wolf
	if nearest_wolf == null:
		return _player
	# 灵狼比玩家更近时优先攻击灵狼
	if nearest_wolf_dist < global_position.distance_to(_player.global_position):
		return nearest_wolf
	return _player


## 从 "player" 组中获取玩家节点
func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


## 尝试攻击目标（受冷却限制），目标可能是玩家或灵狼
func _try_attack(target: Node2D) -> void:
	# 冷却未结束则不攻击
	if _attack_timer > 0.0:
		return

	if target.is_in_group("ally"):
		# 攻击灵狼：直接对其 Vitals 造成伤害
		var wolf_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
		if wolf_vitals != null and not wolf_vitals.is_dead():
			wolf_vitals.take_damage(attack_damage)
	elif target.has_method("receive_damage"):
		# 攻击玩家：优先走统一受伤入口（便于御兽流灵兽护主减伤）
		target.receive_damage(attack_damage)
	else:
		# 退回：直接对玩家 Vitals 造成伤害
		var player_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
		if player_vitals != null:
			player_vitals.take_damage(attack_damage)

	# 重置冷却
	_attack_timer = attack_cooldown


## 妖兽受到攻击（由剑气等外部来源调用）
func take_damage(amount: int) -> void:
	vitals.take_damage(amount)


## 气血归零回调：发放修为奖励并消失
func _on_died() -> void:
	_grant_reward()
	queue_free()


## 发放死亡修为奖励，保证只发放一次
func _grant_reward() -> void:
	if _reward_granted:
		return
	_reward_granted = true

	# 找到 "player" 组中的玩家
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# 修为奖励
	if player.has_method("gain_cultivation_exp"):
		player.gain_cultivation_exp(cultivation_reward)

	# 天道石掉落：精英必掉，普通按概率掉（直接加到玩家身上，不生成地面掉落物）
	var stone_amount: int = 0
	if is_elite:
		stone_amount = elite_drop_amount
	elif randf() < heavenly_stone_drop_chance:
		stone_amount = heavenly_stone_drop_amount
	if stone_amount > 0 and player.has_method("gain_heavenly_stones"):
		player.gain_heavenly_stones(stone_amount)
