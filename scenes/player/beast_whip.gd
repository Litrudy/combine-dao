extends Area2D
## 驭兽鞭（御兽流基础攻击）
## M2-3E —— 从玩家位置朝鼠标方向挥出的短距离范围攻击。
## 造成低伤害并给命中敌人添加“驭兽标记”，使灵狼对其伤害提升。

## 命中伤害（低）
@export var damage: int = 5
## 存活时间（秒），短暂存在后消失
@export var life_time: float = 0.15
## 驭兽标记持续时间
@export var beast_mark_duration: float = 4.0
## 驭兽标记伤害倍率
@export var beast_mark_multiplier: float = 1.3

## 朝向（由玩家释放时传入，需为单位向量）
var direction: Vector2 = Vector2.RIGHT

## 本次挥鞭已命中过的目标，避免重复造成伤害
var _hit_targets: Array = []


func _ready() -> void:
	# 朝鼠标方向旋转
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 短暂存在后消失
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	# 扫描生成瞬间已在范围内的敌人
	_scan_overlaps.call_deferred()


## 等待一个物理帧后扫描范围内敌人（捕获生成时已重叠的目标）
func _scan_overlaps() -> void:
	await get_tree().physics_frame
	if not is_instance_valid(self):
		return
	for body in get_overlapping_bodies():
		_try_hit(body)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## 尝试命中目标：造成低伤害并添加驭兽标记（一次挥鞭可命中多个敌人）
func _try_hit(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return
	# 同一次挥鞭不对同一目标重复造成伤害
	if target in _hit_targets:
		return
	_hit_targets.append(target)

	# 低伤害
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null and not enemy_vitals.is_dead():
		enemy_vitals.take_damage(damage)

	# 添加驭兽标记
	var status: Node = target.get_node_or_null("StatusEffects")
	if status != null and status.has_method("apply_beast_mark"):
		status.apply_beast_mark(beast_mark_duration, beast_mark_multiplier)
