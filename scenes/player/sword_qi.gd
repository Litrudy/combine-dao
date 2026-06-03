extends Area2D
## 剑气（玩家基础攻击投射物）
## M1 任务 4 —— 朝指定方向飞行，命中妖兽造成伤害后消失。
## 不含穿透 / 斩杀 / 升级逻辑。

## 命中伤害
@export var damage: int = 12
## 飞行速度（像素 / 秒）
@export var speed: float = 500.0
## 存活时间（秒），超时自动消失
@export var life_time: float = 0.5

## 飞行方向（由生成方传入，需为单位向量）
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	# 让剑气朝向与飞行方向一致
	rotation = direction.angle()
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

	# 查找妖兽的 Vitals 子节点并造成伤害
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null:
		enemy_vitals.take_damage(damage)

	# 命中后剑气消失（无穿透）
	queue_free()
