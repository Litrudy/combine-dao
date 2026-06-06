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

## ===== 寻敌 / 脱战 / 跟随 AI =====
enum WolfState { FOLLOW, CHASE, ATTACK, RETURN }
## 寻敌范围
@export var detection_range: float = 500.0
## 脱战范围（必须大于 detection_range）
@export var lose_target_range: float = 750.0
## 跟随玩家时保持的距离（像素），过近则不再靠近
@export var follow_distance: float = 90.0
## 跟随时超过此距离会主动靠近
@export var return_distance: float = 180.0
## 离主人最大距离，超过则强制放弃目标返回
@export var max_distance_from_owner: float = 900.0
## 调试：显示寻敌范围圈
@export var debug_show_detection_range: bool = false

## 当前 AI 状态
var wolf_state: WolfState = WolfState.FOLLOW
## 当前锁定的敌人目标
var current_target: Node2D = null
## 跟随时相对玩家的随机偏移（避免多狼堆叠）
var follow_offset: Vector2 = Vector2.ZERO

## 当前攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0

## 自身气血组件（子节点 Vitals）
@onready var vitals: Vitals = $Vitals
## 动画显示节点
@onready var _anim: AnimatedSprite2D = $Visual


func _ready() -> void:
	# 漂浮模式，适合俯视角无重力移动
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# 加入 ally 分组
	add_to_group("ally")
	# 自动修正：脱战范围必须大于寻敌范围
	if lose_target_range <= detection_range:
		lose_target_range = detection_range + 200.0
	# 气血归零时处理死亡
	vitals.died.connect(_on_died)
	# 调试范围圈
	if debug_show_detection_range:
		queue_redraw()


## 灵狼受到攻击（由妖兽 / Boss 调用）
func take_damage(amount: int) -> void:
	vitals.take_damage(amount)


## 死亡回调：通知玩家注销并消失
func _on_died() -> void:
	print("灵狼死亡")
	if is_instance_valid(owner_player) and owner_player.has_method("unregister_wolf"):
		owner_player.unregister_wolf(self)
	queue_free()


## 由玩家调用，绑定主人
func setup(player: Node2D) -> void:
	owner_player = player
	# 随机一个跟随偏移，避免多只灵狼完全堆叠
	follow_offset = Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))


func _physics_process(delta: float) -> void:
	# 攻击冷却递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# 先更新 AI 状态，再按状态执行行为
	_update_wolf_state()

	match wolf_state:
		WolfState.CHASE:
			# 追击：朝目标移动
			if is_instance_valid(current_target):
				velocity = global_position.direction_to(current_target.global_position) * move_speed
			else:
				velocity = Vector2.ZERO
		WolfState.ATTACK:
			# 攻击：停下并按冷却出手
			velocity = Vector2.ZERO
			if is_instance_valid(current_target):
				_try_attack(current_target)
		_:
			# FOLLOW / RETURN：跟随玩家
			_follow_owner()

	_update_animation()
	move_and_slide()


## 根据敌人与主人距离更新 AI 状态
func _update_wolf_state() -> void:
	var has_owner: bool = is_instance_valid(owner_player)
	var owner_dist: float = global_position.distance_to(owner_player.global_position) if has_owner else INF

	# 离主人过远：强制放弃目标并返回（避免越追越远）
	if has_owner and owner_dist > max_distance_from_owner:
		_clear_target()
		wolf_state = WolfState.RETURN

	match wolf_state:
		WolfState.FOLLOW:
			# 跟随时在寻敌范围内发现敌人则追击
			var enemy: Node2D = _find_nearest_enemy()
			if enemy != null:
				_set_target(enemy)
				wolf_state = WolfState.CHASE
		WolfState.CHASE, WolfState.ATTACK:
			# 目标无效（已释放 / 离树 / 死亡）则立即放弃，避免后续访问已释放对象
			if not _is_target_valid(current_target):
				_clear_target()
				wolf_state = WolfState.RETURN
				return
			# 目标有效后才访问其位置
			var distance: float = global_position.distance_to(current_target.global_position)
			if distance > lose_target_range:
				# 超出脱战范围
				_clear_target()
				wolf_state = WolfState.RETURN
			elif distance <= attack_range:
				wolf_state = WolfState.ATTACK
			else:
				wolf_state = WolfState.CHASE
		WolfState.RETURN:
			# 回到玩家附近转为跟随
			if not has_owner or owner_dist <= follow_distance:
				wolf_state = WolfState.FOLLOW
			# 返程途中（且未离主人过远）发现敌人可重新交战
			elif owner_dist <= max_distance_from_owner:
				var enemy: Node2D = _find_nearest_enemy()
				if enemy != null:
					_set_target(enemy)
					wolf_state = WolfState.CHASE


## 寻找 detection_range 内最近的存活 "enemy"（过滤空 / 已释放 / 离树 / 死亡）
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D or not enemy.is_inside_tree():
			continue
		# 跳过已死亡敌人
		var enemy_vitals: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		if enemy_vitals != null and enemy_vitals.is_dead():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		# 只锁定寻敌范围内、且最近的敌人
		if distance <= detection_range and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


## 锁定目标：连接其 tree_exited，目标离场即清空（避免重复连接）
func _set_target(enemy: Node2D) -> void:
	if current_target == enemy:
		return
	# 先断开旧目标的连接
	_clear_target()
	current_target = enemy
	if is_instance_valid(enemy) and not enemy.tree_exited.is_connected(_on_target_tree_exited):
		enemy.tree_exited.connect(_on_target_tree_exited)


## 清空当前目标并断开其信号
func _clear_target() -> void:
	if is_instance_valid(current_target) and current_target.tree_exited.is_connected(_on_target_tree_exited):
		current_target.tree_exited.disconnect(_on_target_tree_exited)
	current_target = null


## 目标离开场景树（死亡 / queue_free）回调：清空目标并返回主人
func _on_target_tree_exited() -> void:
	# 不访问已释放对象，直接清空
	current_target = null
	wolf_state = WolfState.RETURN


## 目标是否仍然有效（未释放、在场景树、未死亡）
## 参数用 Object（而非 Node2D）：已释放对象传入 Node2D 形参会在类型检查阶段直接报错
func _is_target_valid(target: Object) -> bool:
	# 第一步：空 / 已释放对象直接判无效（不可访问其任何成员）
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	# 确认有效后才能访问成员
	if not target.is_inside_tree():
		return false
	var target_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if target_vitals != null and target_vitals.is_dead():
		return false
	return true


## 跟随玩家（带随机偏移）：远则快靠近、中距慢靠近、近则停下
func _follow_owner() -> void:
	if not is_instance_valid(owner_player):
		velocity = Vector2.ZERO
		return

	var target_pos: Vector2 = owner_player.global_position + follow_offset
	var distance: float = global_position.distance_to(target_pos)
	if distance > return_distance:
		velocity = global_position.direction_to(target_pos) * move_speed
	elif distance > follow_distance:
		# 中距：慢速靠近，避免和玩家完全重叠
		velocity = global_position.direction_to(target_pos) * (move_speed * 0.5)
	else:
		velocity = Vector2.ZERO


## 动画：攻击播放中不打断，否则循环行走；按目标 / 速度翻转朝向
func _update_animation() -> void:
	if _anim == null:
		return
	# 朝向：优先看目标方向，其次看移动方向（素材默认朝右）
	if is_instance_valid(current_target):
		_anim.flip_h = current_target.global_position.x < global_position.x
	elif absf(velocity.x) > 1.0:
		_anim.flip_h = velocity.x < 0.0
	# 攻击动画播放中不打断
	if _anim.animation == "wolf_attack" and _anim.is_playing():
		return
	# 其余情况播放行走（攻击播放完会自动回到此处）
	if _anim.animation != "wolf_walk" or not _anim.is_playing():
		_anim.play("wolf_walk")


## 调试：绘制寻敌范围圈
func _draw() -> void:
	if debug_show_detection_range:
		draw_arc(Vector2.ZERO, detection_range, 0.0, TAU, 64, Color(0.4, 1, 0.6, 0.35), 2.0)


## 尝试攻击妖兽（受冷却限制）
func _try_attack(target: Node2D) -> void:
	# 冷却未结束则不攻击
	if _attack_timer > 0.0:
		return

	# 计算最终伤害：若目标被驭兽鞭标记，则提高伤害
	var final_damage: int = attack_damage
	var status: Node = target.get_node_or_null("StatusEffects")
	if status != null and status.has_method("get_beast_damage_multiplier"):
		final_damage = int(round(attack_damage * status.get_beast_damage_multiplier()))

	# 调用妖兽的 Vitals 子节点造成伤害
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null:
		enemy_vitals.take_damage(final_damage)

	# 重置冷却：实际冷却 = 基础冷却 / 攻速倍率
	var effective_cooldown: float = base_attack_cooldown / max(attack_speed_multiplier, 0.01)
	_attack_timer = effective_cooldown

	# 播放攻击动画（不循环，播放完由 _update_animation 回到行走）
	if _anim != null:
		_anim.play("wolf_attack")
