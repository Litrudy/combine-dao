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

## 已命中过的目标，避免同一剑气对同一妖兽重复造成伤害
var _hit_targets: Array = []


func _ready() -> void:
	# 让剑气朝向与飞行方向一致
	rotation = direction.angle()
	# 根据宽度加成横向加宽（垂直于飞行方向的 y 轴）
	if width_bonus > 0:
		var width_scale: float = 1.0 + width_bonus * 0.6
		$CollisionShape2D.scale.y = width_scale
		$Visual.scale.y = width_scale
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
	_try_hit(body)


## 命中区域（Area2D），兼容妖兽用 Area 作为受击体的情况
func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## 尝试对目标造成伤害
func _try_hit(target: Node) -> void:
	# 只攻击 "enemy" 组的妖兽
	if not target.is_in_group("enemy"):
		return

	# 同一剑气不对同一妖兽重复造成伤害
	if target in _hit_targets:
		return
	_hit_targets.append(target)

	# 查找妖兽的 Vitals 子节点
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null:
		if execute_enabled and _is_executable(enemy_vitals):
			# 残血斩杀：造成等于当前气血的伤害，直接击杀
			enemy_vitals.take_damage(enemy_vitals.current_qi_blood)
		else:
			# 普通命中：造成剑气伤害
			enemy_vitals.take_damage(damage)

	# 穿透处理：仍有穿透次数则继续飞行，否则消失
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()


## 判断妖兽是否处于可斩杀的残血状态（气血占比低于阈值）
func _is_executable(enemy_vitals: Vitals) -> bool:
	if enemy_vitals.max_qi_blood <= 0:
		return false
	return float(enemy_vitals.current_qi_blood) / float(enemy_vitals.max_qi_blood) < execute_threshold
