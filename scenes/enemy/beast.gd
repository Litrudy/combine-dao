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

## 目标玩家节点
var _player: Node2D
## 当前攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0

## 自身气血组件（子节点 Vitals）
@onready var vitals: Vitals = $Vitals


func _ready() -> void:
	# 漂浮模式，适合俯视角无重力移动
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 气血归零时妖兽消失
	vitals.died.connect(_on_died)
	# 寻找 "player" 组中的玩家节点
	_acquire_player()


func _physics_process(delta: float) -> void:
	# 冷却计时递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# 没有目标则尝试重新获取（玩家可能尚未就绪）
	if not is_instance_valid(_player):
		_acquire_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 计算与玩家的距离
	var distance: float = global_position.distance_to(_player.global_position)

	if distance <= attack_range:
		# 进入攻击范围：停止移动并尝试攻击
		velocity = Vector2.ZERO
		_try_attack()
	else:
		# 否则朝玩家方向移动
		var direction: Vector2 = global_position.direction_to(_player.global_position)
		velocity = direction * move_speed

	move_and_slide()


## 从 "player" 组中获取玩家节点
func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


## 尝试攻击玩家（受冷却限制）
func _try_attack() -> void:
	# 冷却未结束则不攻击
	if _attack_timer > 0.0:
		return

	# 获取玩家的 Vitals 子节点并造成伤害
	var player_vitals: Vitals = _player.get_node_or_null("Vitals") as Vitals
	if player_vitals != null:
		player_vitals.take_damage(attack_damage)

	# 重置冷却
	_attack_timer = attack_cooldown


## 妖兽受到攻击（由剑气等外部来源调用）
func take_damage(amount: int) -> void:
	vitals.take_damage(amount)


## 气血归零回调：妖兽消失
func _on_died() -> void:
	queue_free()
