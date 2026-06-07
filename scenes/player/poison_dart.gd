extends Area2D
## 毒镖（毒蛊流基础攻击）
## M2-3E —— 朝鼠标方向飞行，命中妖兽造成低伤害并施加可叠加的中毒。

## 命中直接伤害（由释放者设置：3 + 毒灵根 * 50%）
@export var damage: int = 5
## 飞行速度
@export var speed: float = 600.0
## 存活时间（秒）
@export var life_time: float = 0.6

## 飞行方向（由玩家释放时传入，需为单位向量）
var direction: Vector2 = Vector2.RIGHT

## 致命毒镖：施加 / 叠毒概率（0 表示无该机缘，仅对已中毒目标叠层；机缘「致命毒镖」）
var poison_chance: float = 0.0
## 施加中毒所需参数（由释放者传入，与毒雾一致）
var source_poison_root: int = 0
var poison_bonus_per_tick: int = 0
var poison_ratio_bonus: float = 0.0
## 毒蛊联动：减速（沉疴）/ 蛊咒配置，随中毒下发到目标 StatusEffects
var poison_slow_enabled: bool = false
var poison_slow_multiplier: float = 1.0
var poison_curse_enabled: bool = false
var poison_curse_multiplier: float = 1.0
## 天品「毒爆余烬」：毒爆后留小毒云
var poison_spore_enabled: bool = false
## 机缘「毒孢爆裂」：毒爆附加晕眩
var poison_spore_stun_enabled: bool = false
var poison_spore_stun_duration: float = 0.0
## 天品「蛊咒传播」
var poison_curse_spread_enabled: bool = false
## 中毒 DOT 持续时间（含毒灵根精通天品；0 表示用默认）
var poison_dot_duration: float = 0.0

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
	# 命中环境（墙体 / 地图障碍 / 事件阻挡体，均为 StaticBody2D）：销毁毒镖，不造成伤害
	if _is_environment(body):
		queue_free()
		return
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## 是否为环境阻挡物（墙体 / 障碍 / 事件阻挡体）
func _is_environment(node: Node) -> bool:
	return node is StaticBody2D or node.is_in_group("map_wall") or node.is_in_group("map_obstacle")


## 尝试命中目标：造成基础伤害并施加中毒
func _try_hit(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return
	# 同一毒镖不重复命中同一目标
	if target in _hit_targets:
		return
	_hit_targets.append(target)

	# 直接伤害（3 + 毒灵根 * 50%）
	var enemy_vitals: Vitals = target.get_node_or_null("Vitals") as Vitals
	if enemy_vitals != null and not enemy_vitals.is_dead():
		enemy_vitals.take_damage(damage)

	var status: Node = target.get_node_or_null("StatusEffects")
	if status != null:
		# 致命毒镖：按概率施加第一层毒；未触发时退回“仅对已中毒目标叠层”的原行为
		var applied: bool = false
		var dur: float = poison_dot_duration if poison_dot_duration > 0.0 else 5.0
		if poison_chance > 0.0 and status.has_method("apply_poison") and randf() < poison_chance:
			status.apply_poison(source_poison_root, poison_bonus_per_tick, poison_ratio_bonus, dur)
			applied = true
		if not applied and status.has_method("add_poison_stack_if_present"):
			status.add_poison_stack_if_present()
		# 毒蛊联动：下发减速 / 蛊咒承伤 / 余烬 / 晕眩 / 传播配置
		if status.has_method("configure_poison_slow"):
			status.configure_poison_slow(poison_slow_enabled, poison_slow_multiplier)
		if status.has_method("configure_poison_curse"):
			status.configure_poison_curse(poison_curse_enabled, poison_curse_multiplier)
		if status.has_method("configure_poison_spore"):
			status.configure_poison_spore(poison_spore_enabled)
		if status.has_method("configure_poison_spore_stun"):
			status.configure_poison_spore_stun(poison_spore_stun_enabled, poison_spore_stun_duration)
		if status.has_method("configure_poison_curse_spread"):
			status.configure_poison_curse_spread(poison_curse_spread_enabled)

	# 命中后消失
	queue_free()
