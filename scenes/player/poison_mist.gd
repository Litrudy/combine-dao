extends Area2D
## 毒雾（毒蛊流区域控制）
## 在范围内对妖兽施加 / 刷新「中毒」状态（统一由 StatusEffects 结算 DOT）。
## 毒雾自身不再直接造成伤害，避免与中毒 DOT 重复计算。

## 毒雾持续时间（秒）
@export var duration: float = 4.0
## 施加间隔（秒）：每隔此时间为范围内妖兽叠加 / 刷新一次中毒
@export var tick_interval: float = 1.0

## 中毒来源（施加者）的毒灵根，传给 StatusEffects 计算每跳毒伤
var source_poison_root: int = 0
## 中毒每跳额外固定毒伤（毒蛊机缘加成）
var poison_bonus_per_tick: int = 0
## 中毒第一层比例加成（机缘「毒性强化」）
var poison_ratio_bonus: float = 0.0

## 是否启用毒爆
var poison_explosion_enabled: bool = false
## 毒爆范围（像素，可由玩家释放时传入，含专精加成）
var explosion_radius: float = 120.0
## 毒爆对其他妖兽造成的毒伤（可由玩家释放时传入，含专精加成）
var explosion_damage: int = 8

## 存活计时（剩余持续时间）
var _life_timer: float = 0.0
## 距离下次施加的剩余时间
var _tick_timer: float = 0.0

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
## 天品「蛊咒传播」：诅咒目标死亡向附近传毒
var poison_curse_spread_enabled: bool = false
## 中毒 DOT 持续时间（含毒灵根精通天品；0 表示用默认）
var poison_dot_duration: float = 0.0

## 毒雾范围加成（机缘「毒域扩张」，由玩家释放时传入）
var radius_bonus: int = 0
## 毒雾基础范围（与场景碰撞圆半径一致）
const BASE_RADIUS: float = 80.0


func _ready() -> void:
	_life_timer = duration
	# 第一次施加等待一个 tick_interval
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

	# 按 tick_interval 周期为范围内妖兽施加 / 刷新中毒
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_poison_tick()


## 对范围内所有妖兽施加 / 刷新一次中毒（DOT 由各自 StatusEffects 结算）
func _apply_poison_tick() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("enemy"):
			continue
		var status: Node = body.get_node_or_null("StatusEffects")
		if status == null or not status.has_method("apply_poison"):
			continue
		# 施加 / 叠加中毒（来源毒灵根 = 施加者；附带毒蛊机缘固定加成与可选时长）
		var dur: float = poison_dot_duration if poison_dot_duration > 0.0 else 5.0
		status.apply_poison(source_poison_root, poison_bonus_per_tick, poison_ratio_bonus, dur)
		# 配置毒爆（中毒目标死亡时由 StatusEffects 触发）
		if status.has_method("configure_poison_explosion"):
			status.configure_poison_explosion(poison_explosion_enabled, explosion_radius, explosion_damage)
		# 配置沉疴减速 / 蛊咒承伤（无对应机缘时为默认 1.0，等价于不生效）
		if status.has_method("configure_poison_slow"):
			status.configure_poison_slow(poison_slow_enabled, poison_slow_multiplier)
		if status.has_method("configure_poison_curse"):
			status.configure_poison_curse(poison_curse_enabled, poison_curse_multiplier)
		# 配置毒爆余烬（天品）/ 毒孢晕眩 / 蛊咒传播
		if status.has_method("configure_poison_spore"):
			status.configure_poison_spore(poison_spore_enabled)
		if status.has_method("configure_poison_spore_stun"):
			status.configure_poison_spore_stun(poison_spore_stun_enabled, poison_spore_stun_duration)
		if status.has_method("configure_poison_curse_spread"):
			status.configure_poison_curse_spread(poison_curse_spread_enabled)
