extends Area2D
## 近战命中框（灵力冲击 / 击剑）
## 短暂存在，对前方范围内的妖兽造成一次直接伤害。
## 带视线检测：攻击原点到目标之间若被墙体 / 障碍（StaticBody2D）挡住则不命中，避免隔墙打怪。

## 命中伤害（由释放者设置）
@export var damage: int = 0
## 存活时间（秒），短暂存在后消失
@export var life_time: float = 0.15

## 视线检测使用的环境碰撞层（与墙体 / 障碍一致，默认世界层 1）
const ENVIRONMENT_MASK: int = 1

## 本次攻击已命中过的目标，避免重复造成伤害
var _hit_targets: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 短暂存在后自动消失
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


## 尝试命中目标：仅命中 "enemy" 组、未命中过、且视线未被环境阻挡的目标
func _try_hit(target: Node) -> void:
	if target == null or not target.is_in_group("enemy"):
		return
	if target in _hit_targets:
		return
	if not _has_line_of_sight(target):
		return
	_hit_targets.append(target)

	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null and not enemy_vitals.is_dead():
		enemy_vitals.take_damage(damage)


## 攻击原点（命中框位置）到目标之间是否有视线：被环境 StaticBody2D 阻挡则无视线
func _has_line_of_sight(target: Node) -> bool:
	if not target is Node2D:
		return true
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		global_position, (target as Node2D).global_position, ENVIRONMENT_MASK
	)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return true
	# 射线第一个命中物若是环境实体（StaticBody2D，如墙体 / 障碍 / 事件阻挡体）则视线被阻断
	return not (hit.get("collider") is StaticBody2D)
