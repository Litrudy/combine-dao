extends Area2D
## 毒雾（毒蛊流区域伤害）
## M1 任务 7D —— 在范围内对妖兽按 tick 周期结算毒伤。
## 仅做区域内结算，不做复杂 DOT 状态系统。

## 每次结算的基础毒伤
@export var damage_per_second: int = 3
## 毒雾持续时间（秒）
@export var duration: float = 4.0
## 结算间隔（秒）
@export var tick_interval: float = 1.0
## 是否启用叠毒
@export var poison_stack_enabled: bool = false
## 叠毒最大层数
@export var max_poison_stack: int = 1
## 是否启用毒爆
@export var poison_explosion_enabled: bool = false

## 毒爆范围（像素，可由玩家释放时传入，含专精加成）
@export var explosion_radius: float = 120.0
## 毒爆对其他妖兽造成的毒伤（可由玩家释放时传入，含专精加成）
@export var explosion_damage: int = 8

## 存活计时（剩余持续时间）
var _life_timer: float = 0.0
## 距离下次结算的剩余时间
var _tick_timer: float = 0.0
## 每只妖兽的当前毒层数 { enemy:Node -> stack:int }
var _poison_stacks: Dictionary = {}

## 毒雾范围加成（机缘「毒域扩张」，由玩家释放时传入）
var radius_bonus: int = 0
## 毒雾基础范围（与场景碰撞圆半径一致）
const BASE_RADIUS: float = 80.0


func _ready() -> void:
	_life_timer = duration
	# 第一次结算等待一个 tick_interval
	_tick_timer = tick_interval
	# 根据范围加成缩放碰撞体与视觉（影响 get_overlapping_bodies 的检测范围）
	if radius_bonus != 0:
		var radius_scale: float = (BASE_RADIUS + radius_bonus) / BASE_RADIUS
		$CollisionShape2D.scale = Vector2(radius_scale, radius_scale)
		$Visual.scale = Vector2(radius_scale, radius_scale)


func _physics_process(delta: float) -> void:
	# 持续时间结束则销毁
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	# 按 tick_interval 周期结算，不每帧伤害
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_poison_tick()


## 对范围内所有妖兽结算一次毒伤
func _apply_poison_tick() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemy"):
			_poison_one(body)


## 对单只妖兽结算毒伤（含叠毒与毒爆判定）
func _poison_one(enemy: Node) -> void:
	var enemy_vitals: Vitals = enemy.get_node_or_null("Vitals") as Vitals
	# 妖兽无气血组件或已死亡则跳过
	if enemy_vitals == null or enemy_vitals.is_dead():
		return

	# 计算本次毒伤
	var damage: int = damage_per_second
	if poison_stack_enabled:
		# 叠毒：每次结算层数 +1，封顶 max_poison_stack；毒伤 = 基础毒伤 * 层数
		var stack: int = _poison_stacks.get(enemy, 0)
		stack = min(stack + 1, max_poison_stack)
		_poison_stacks[enemy] = stack
		damage = damage_per_second * stack

	# 记录受伤前是否存活，用于判断本次是否毒死
	var was_alive: bool = not enemy_vitals.is_dead()
	enemy_vitals.take_damage(damage)

	# 毒爆：本次结算导致妖兽死亡时触发（每只只会触发一次）
	if poison_explosion_enabled and was_alive and enemy_vitals.is_dead():
		_trigger_explosion(enemy)


## 毒爆：对死亡妖兽周围其他妖兽扩散毒伤
func _trigger_explosion(source_enemy: Node) -> void:
	print("毒爆触发")
	var source_pos: Vector2 = (source_enemy as Node2D).global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		# 跳过毒爆源、无效节点和非 2D 节点
		if enemy == source_enemy or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		# 仅影响毒爆范围内的妖兽
		if source_pos.distance_to((enemy as Node2D).global_position) > explosion_radius:
			continue
		var enemy_vitals: Vitals = enemy.get_node_or_null("Vitals") as Vitals
		# 直接造成毒伤，不再二次引爆，避免连锁递归
		if enemy_vitals != null and not enemy_vitals.is_dead():
			enemy_vitals.take_damage(explosion_damage)
