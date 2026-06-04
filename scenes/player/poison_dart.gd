extends Area2D
## 毒镖（毒蛊流基础攻击）
## M2-3E —— 朝鼠标方向飞行，命中妖兽造成低伤害并施加可叠加的中毒。

## 命中基础伤害（低于剑气）
@export var damage: int = 5
## 飞行速度
@export var speed: float = 600.0
## 存活时间（秒）
@export var life_time: float = 0.6
## 中毒每跳伤害
@export var poison_tick_damage: int = 2
## 中毒持续时间
@export var poison_duration: float = 3.0
## 中毒结算间隔
@export var poison_tick_interval: float = 1.0
## 中毒最大叠层
@export var poison_max_stack: int = 3

## 飞行方向（由玩家释放时传入，需为单位向量）
var direction: Vector2 = Vector2.RIGHT

## 已命中过的目标，避免同一毒镖重复命中
var _hit_targets: Array = []


func _ready() -> void:
	# 朝向与飞行方向一致
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 超时自动销毁
	get_tree().create_timer(life_time).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## 尝试命中目标：造成基础伤害并施加中毒
func _try_hit(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return
	# 同一毒镖不重复命中同一目标
	if target in _hit_targets:
		return
	_hit_targets.append(target)

	# 基础伤害
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null and not enemy_vitals.is_dead():
		enemy_vitals.take_damage(damage)

	# 施加中毒（通过 StatusEffects 组件）
	var status: Node = target.get_node_or_null("StatusEffects")
	if status != null and status.has_method("apply_poison"):
		status.apply_poison(poison_tick_damage, poison_duration, poison_tick_interval, poison_max_stack)

	# 命中后消失
	queue_free()
