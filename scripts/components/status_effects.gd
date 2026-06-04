extends Node
class_name StatusEffects
## 状态组件
## M2-3E —— 负责中毒（可叠层）与驭兽标记。
## 挂在妖兽 / Boss 上，与 Vitals 同级。

## 同级气血组件
@onready var _vitals: Vitals = get_parent().get_node_or_null("Vitals")

# ===== 中毒状态 =====
## 当前毒层数
var _poison_stacks: int = 0
## 每层每跳毒伤
var _poison_damage_per_tick: int = 0
## 毒剩余持续时间
var _poison_time_left: float = 0.0
## 毒结算间隔
var _poison_tick_interval: float = 1.0
## 距离下次毒结算的剩余时间
var _poison_tick_timer: float = 0.0

# ===== 驭兽标记 =====
## 驭兽标记剩余时间
var _beast_mark_time_left: float = 0.0
## 驭兽标记伤害倍率
var _beast_mark_multiplier: float = 1.0


func _process(delta: float) -> void:
	_process_poison(delta)
	_process_beast_mark(delta)


## 施加中毒：刷新持续时间，毒层 +1（封顶 max_stack）
func apply_poison(damage_per_tick: int, duration: float, tick_interval: float, max_stack: int) -> void:
	# 从无毒进入中毒时，重置结算计时
	if _poison_stacks <= 0:
		_poison_tick_timer = tick_interval
	_poison_damage_per_tick = damage_per_tick
	_poison_tick_interval = tick_interval
	_poison_stacks = min(_poison_stacks + 1, max_stack)
	# 每次中毒刷新持续时间
	_poison_time_left = duration


## 每帧处理中毒结算
func _process_poison(delta: float) -> void:
	if _poison_stacks <= 0:
		return

	_poison_time_left -= delta
	_poison_tick_timer -= delta
	# 到达结算间隔则造成 每层毒伤 * 毒层数
	if _poison_tick_timer <= 0.0:
		_poison_tick_timer = _poison_tick_interval
		if is_instance_valid(_vitals) and not _vitals.is_dead():
			_vitals.take_damage(_poison_damage_per_tick * _poison_stacks)

	# 持续时间结束则清空毒层（M2 阶段稳定优先，直接清空）
	if _poison_time_left <= 0.0:
		_poison_stacks = 0


## 施加驭兽标记
func apply_beast_mark(duration: float, multiplier: float) -> void:
	_beast_mark_time_left = duration
	_beast_mark_multiplier = multiplier


## 每帧处理驭兽标记倒计时
func _process_beast_mark(delta: float) -> void:
	if _beast_mark_time_left > 0.0:
		_beast_mark_time_left -= delta


## 返回当前驭兽标记伤害倍率（无标记返回 1.0）
func get_beast_damage_multiplier() -> float:
	if _beast_mark_time_left > 0.0:
		return _beast_mark_multiplier
	return 1.0
