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

## ===== 寻敌 / 警戒 AI =====
enum AIState { IDLE, CHASE, ATTACK, RETURN }
## 进入追击的侦测范围
@export var detection_range: float = 420.0
## 脱战范围（必须大于 detection_range）
@export var lose_target_range: float = 650.0
## 脱战后是否返回出生点
@export var return_to_spawn: bool = true
## IDLE 是否游走（本阶段保留参数，未实现游走）
@export var idle_move_enabled: bool = false
## 调试：显示侦测范围圈
@export var debug_show_detection_range: bool = false

## 当前 AI 状态
var ai_state: AIState = AIState.IDLE
## 出生点（首个物理帧记录，兼容运行时动态生成的护卫）
var spawn_position: Vector2 = Vector2.ZERO
## 交战时指向玩家，否则为 null（供外部 / 调试参考）
var target_player: Node2D = null
## 当前实际作战目标（玩家或更近的灵狼）
var _current_target: Node2D = null
## 出生点是否已记录
var _spawn_recorded: bool = false

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
	# 自动修正：脱战范围必须大于侦测范围
	if lose_target_range <= detection_range:
		lose_target_range = detection_range + 200.0
	# 精英怪强化
	if is_elite:
		_apply_elite_buff()
	# 气血归零时妖兽消失
	vitals.died.connect(_on_died)
	# 寻找 "player" 组中的玩家节点
	_acquire_player()
	# 调试范围圈
	if debug_show_detection_range:
		queue_redraw()


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
	# 首个物理帧记录出生点（此时位置已被生成方设置完毕）
	if not _spawn_recorded:
		spawn_position = global_position
		_spawn_recorded = true

	# 冷却计时递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	if not is_instance_valid(_player):
		_acquire_player()

	# 先更新 AI 状态，再按状态执行行为
	_update_ai_state()

	match ai_state:
		AIState.CHASE:
			# 追击：朝当前目标移动
			if is_instance_valid(_current_target):
				velocity = global_position.direction_to(_current_target.global_position) * move_speed
			else:
				velocity = Vector2.ZERO
		AIState.ATTACK:
			# 攻击：停下并按冷却出手
			velocity = Vector2.ZERO
			if is_instance_valid(_current_target):
				_try_attack(_current_target)
		AIState.RETURN:
			# 返回出生点
			if global_position.distance_to(spawn_position) > 20.0:
				velocity = global_position.direction_to(spawn_position) * move_speed
			else:
				velocity = Vector2.ZERO
		_:
			# IDLE：原地待命，不追击不攻击
			velocity = Vector2.ZERO

	move_and_slide()


## 根据玩家距离与目标更新 AI 状态（侦测 / 脱战 / 攻击距离判定）
func _update_ai_state() -> void:
	var has_player: bool = is_instance_valid(_player)
	var player_dist: float = global_position.distance_to(_player.global_position) if has_player else INF

	match ai_state:
		AIState.IDLE:
			# 玩家进入侦测范围才开始追击
			if has_player and player_dist <= detection_range:
				_enter_combat()
		AIState.CHASE, AIState.ATTACK:
			# 玩家离开脱战范围则脱战
			if not has_player or player_dist > lose_target_range:
				_disengage()
			else:
				# 交战中：选择实际作战目标（玩家或更近的灵狼）
				_current_target = _select_target()
				target_player = _player
				if is_instance_valid(_current_target) \
						and global_position.distance_to(_current_target.global_position) <= attack_range:
					ai_state = AIState.ATTACK
				else:
					ai_state = AIState.CHASE
		AIState.RETURN:
			# 返程途中玩家再次靠近则重新交战
			if has_player and player_dist <= detection_range:
				_enter_combat()
			elif global_position.distance_to(spawn_position) <= 20.0:
				ai_state = AIState.IDLE


## 进入交战状态
func _enter_combat() -> void:
	_current_target = _select_target()
	target_player = _player
	ai_state = AIState.CHASE


## 脱战：返回出生点或转入待机
func _disengage() -> void:
	_current_target = null
	target_player = null
	ai_state = AIState.RETURN if return_to_spawn else AIState.IDLE


## 调试：绘制侦测范围圈
func _draw() -> void:
	if debug_show_detection_range:
		draw_arc(Vector2.ZERO, detection_range, 0.0, TAU, 64, Color(1, 1, 0, 0.35), 2.0)


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
