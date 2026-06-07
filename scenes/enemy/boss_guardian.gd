extends CharacterBody2D
## 守墟妖王（M1 Boss）
## M1 任务 8 —— 缓慢追踪玩家，循环释放冲撞 / 震地技能，残血进入狂暴。
## 保持简单稳定，不写复杂寻路 / 正式特效 / 关卡结算。

## ===== 基础移动 =====
## 追踪移动速度
@export var move_speed: float = 70.0
## 与玩家保持的距离（小于此距离不再靠近，进入技能循环）
@export var keep_distance: float = 120.0

## ===== 技能 1：冲撞 =====
## 突进速度
@export var charge_speed: float = 500.0
## 突进持续时间（秒）
@export var charge_duration: float = 0.4
## 突进命中伤害
@export var charge_damage: int = 15

## ===== 技能 2：震地 =====
## 震地半径
@export var quake_radius: float = 150.0
## 震地伤害
@export var quake_damage: int = 20

## ===== 技能循环 =====
## 技能间冷却（秒）
@export var skill_cooldown: float = 2.0
## 距离阈值：大于此值优先冲撞，小于则优先震地
@export var charge_range: float = 200.0

## ===== 警戒 / 激活 =====
## 玩家进入此范围后 Boss 苏醒
@export var boss_detection_range: float = 900.0
## 激活范围（与侦测范围共同决定触发距离）
@export var boss_activation_range: float = 900.0
## 是否已激活（激活后保持战斗，不脱战）
@export var boss_activated: bool = false
## 调试：显示警戒范围圈
@export var debug_show_detection_range: bool = false

## ===== 天道石掉落 =====
## 击败 Boss 掉落天道石的最小 / 最大数量
@export var boss_heavenly_stone_min: int = 8
@export var boss_heavenly_stone_max: int = 12

## 冲撞命中判定半径
const CHARGE_HIT_RADIUS: float = 45.0

## Boss 状态
enum State { CHASE, CHARGE }

var _state: State = State.CHASE
## 目标玩家
var _player: Node2D = null
## 技能冷却剩余时间
var _skill_timer: float = 0.0
## 冲撞剩余时间
var _charge_time_left: float = 0.0
## 冲撞锁定方向
var _charge_direction: Vector2 = Vector2.ZERO
## 本次冲撞是否已命中玩家（避免重复造成伤害）
var _charge_hit: bool = false
## 本次冲撞已命中过的灵狼（避免重复造成伤害）
var _charge_hit_wolves: Array = []
## 是否已进入狂暴（只触发一次）
var _berserk_triggered: bool = false

## 自身气血组件
@onready var vitals: Vitals = $Vitals
## 动画显示节点
@onready var _anim: AnimatedSprite2D = $Visual


func _ready() -> void:
	# 漂浮模式，适合俯视角无重力移动
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 确保加入 enemy 分组
	add_to_group("enemy")
	# 死亡回调
	vitals.died.connect(_on_died)
	# 寻找玩家
	_acquire_player()
	# 调试范围圈
	if debug_show_detection_range:
		queue_redraw()


func _physics_process(delta: float) -> void:
	# 没有目标则尝试重新获取
	if not is_instance_valid(_player):
		_acquire_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 未激活：原地待命，玩家进入警戒范围后苏醒（激活前不追击、不放技能）
	if not boss_activated:
		velocity = Vector2.ZERO
		var trigger_range: float = min(boss_detection_range, boss_activation_range)
		if global_position.distance_to(_player.global_position) <= trigger_range:
			boss_activated = true
			print("守墟妖王苏醒")
		move_and_slide()
		return

	# 晕眩（毒孢爆裂；Boss 仅吃 30% 时长）：暂停移动与技能
	if _is_stunned():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 残血狂暴检测
	_check_berserk()

	# 状态机
	match _state:
		State.CHASE:
			_process_chase(delta)
		State.CHARGE:
			_process_charge(delta)

	# 根据水平移动方向翻转朝向（boss_guardian_walk 素材默认朝左，故向右移动时翻转）
	if _anim != null and absf(velocity.x) > 1.0:
		_anim.flip_h = velocity.x > 0.0

	move_and_slide()


## 是否被晕眩（读取同级 StatusEffects，无则 false）
func _is_stunned() -> bool:
	var status: Node = get_node_or_null("StatusEffects")
	return status != null and status.has_method("is_stunned") and status.is_stunned()


## 从 "player" 组获取玩家
func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


## 追踪状态：缓慢靠近玩家，冷却结束后释放技能
func _process_chase(delta: float) -> void:
	# 技能冷却递减
	if _skill_timer > 0.0:
		_skill_timer -= delta

	var distance: float = global_position.distance_to(_player.global_position)

	# 超出保持距离则缓慢靠近，否则停下
	if distance > keep_distance:
		velocity = global_position.direction_to(_player.global_position) * move_speed
	else:
		velocity = Vector2.ZERO

	# 冷却结束则根据距离选择技能
	if _skill_timer <= 0.0:
		if distance > charge_range:
			_start_charge()
		else:
			_do_quake()


## 技能 1：开始冲撞
func _start_charge() -> void:
	print("守墟妖王发动冲撞")
	_state = State.CHARGE
	_charge_time_left = charge_duration
	# 锁定冲撞方向为当前玩家方向
	_charge_direction = global_position.direction_to(_player.global_position)
	_charge_hit = false
	_charge_hit_wolves.clear()


## 冲撞状态：高速突进并判定命中
func _process_charge(delta: float) -> void:
	_charge_time_left -= delta
	velocity = _charge_direction * charge_speed

	# 命中判定：靠近玩家且本次冲撞未命中过
	if not _charge_hit:
		var distance: float = global_position.distance_to(_player.global_position)
		if distance <= CHARGE_HIT_RADIUS:
			_charge_hit = true
			_damage_player(charge_damage)

	# 冲撞也会撞到灵狼（每只本次冲撞只受伤一次）
	for wolf in get_tree().get_nodes_in_group("ally"):
		if not is_instance_valid(wolf) or wolf in _charge_hit_wolves:
			continue
		if global_position.distance_to(wolf.global_position) <= CHARGE_HIT_RADIUS:
			_charge_hit_wolves.append(wolf)
			_damage_wolf(wolf, charge_damage)

	# 冲撞结束：回到追踪状态并重置冷却
	if _charge_time_left <= 0.0:
		_state = State.CHASE
		_skill_timer = skill_cooldown


## 技能 2：震地（原地圆形范围攻击）
func _do_quake() -> void:
	print("守墟妖王发动震地")
	velocity = Vector2.ZERO
	# 玩家在范围内则受伤
	if global_position.distance_to(_player.global_position) <= quake_radius:
		_damage_player(quake_damage)
	# 范围内的灵狼也受伤
	for wolf in get_tree().get_nodes_in_group("ally"):
		if not is_instance_valid(wolf):
			continue
		if global_position.distance_to(wolf.global_position) <= quake_radius:
			_damage_wolf(wolf, quake_damage)
	# 重置冷却
	_skill_timer = skill_cooldown


## 技能 3：狂暴（残血一次性强化）
func _check_berserk() -> void:
	if _berserk_triggered:
		return
	# 当前气血低于最大气血 40% 时触发
	if float(vitals.get_current_qi_blood()) < float(vitals.get_max_qi_blood()) * 0.4:
		_berserk_triggered = true
		move_speed *= 1.5
		skill_cooldown *= 0.7
		print("守墟妖王进入狂暴状态")


## 对灵狼造成伤害
func _damage_wolf(wolf: Node, amount: int) -> void:
	var wolf_vitals: Vitals = wolf.get_node_or_null("Vitals") as Vitals
	if wolf_vitals != null and not wolf_vitals.is_dead():
		wolf_vitals.take_damage(amount)


## 对玩家造成伤害（优先走 receive_damage 入口，便于护主等机制）
func _damage_player(amount: int) -> void:
	if _player.has_method("receive_damage"):
		_player.receive_damage(amount)
	else:
		var player_vitals: Vitals = _player.get_node_or_null("Vitals") as Vitals
		if player_vitals != null:
			player_vitals.take_damage(amount)


## 死亡回调：掉落天道石、消失并提示
func _on_died() -> void:
	# 掉落 8-12 个天道石（直接加到玩家身上）
	var player: Node = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_heavenly_stones"):
		var amount: int = randi_range(boss_heavenly_stone_min, boss_heavenly_stone_max)
		player.gain_heavenly_stones(amount)
		print("守墟妖王掉落天道石：", amount)
	print("守墟妖王已被击败")
	_play_death_then_free()


## 死亡表现：停止追击 / 碰撞 / 目标性，缩小淡出后再销毁
func _play_death_then_free() -> void:
	set_physics_process(false)
	remove_from_group("enemy")
	remove_from_group("boss")
	var col: Node = get_node_or_null("CollisionShape2D")
	if col != null:
		col.set_deferred("disabled", true)
	if _anim != null:
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_anim, "modulate:a", 0.0, 0.3)
		t.tween_property(_anim, "scale", _anim.scale * 0.6, 0.3)
		t.chain().tween_callback(queue_free)
	else:
		queue_free()


## 调试：绘制警戒范围圈
func _draw() -> void:
	if debug_show_detection_range:
		draw_arc(Vector2.ZERO, boss_detection_range, 0.0, TAU, 72, Color(1, 0.4, 0.4, 0.35), 2.0)
