extends Node
class_name Vitals
## 气血组件
## M1 任务 2 —— 负责管理气血值、受伤、治疗与死亡。
## 通过信号对外通知，不直接处理攻击 / 妖兽 AI / UI / 升级。

## 受伤时发出：本次伤害量、剩余气血
signal damaged(amount: int, current_qi_blood: int)
## 治疗时发出：本次治疗量、当前气血
signal healed(amount: int, current_qi_blood: int)
## 气血归零时发出（仅触发一次）
signal died

## 气血上限
@export var max_qi_blood: int = 100

## 当前气血
var current_qi_blood: int

## 是否已死亡，用于保证 died 信号只触发一次
var _is_dead: bool = false

## 最近一次受伤的类型（"normal" / "poison" / "summon"），供反馈系统着色伤害数字。
## 仅作展示用，不影响任何伤害结算。
var last_damage_type: String = "normal"


func _ready() -> void:
	# 运行时将当前气血初始化为上限
	current_qi_blood = max_qi_blood


## 受到伤害。damage_type 仅用于反馈着色（默认 "normal"），不参与任何结算。
func take_damage(amount: int, damage_type: String = "normal") -> void:
	# 已死亡或伤害无效（<=0）时忽略
	if _is_dead or amount <= 0:
		return

	# 承伤倍率（如蛊咒）：读取同级 StatusEffects，无则为 1.0；作用于所有伤害源
	var final_amount: int = amount
	var mult: float = _get_damage_taken_multiplier()
	if mult != 1.0:
		final_amount = max(1, int(round(amount * mult)))

	# 记录伤害类型（供反馈系统读取）
	last_damage_type = damage_type
	# 扣除气血，并限制不低于 0
	current_qi_blood = max(current_qi_blood - final_amount, 0)
	damaged.emit(final_amount, current_qi_blood)

	# 气血归零则判定死亡
	if current_qi_blood == 0:
		_die()


## 读取同级 StatusEffects 的承伤倍率（无该组件 / 无该方法时为 1.0）
func _get_damage_taken_multiplier() -> float:
	var host: Node = get_parent()
	if host == null:
		return 1.0
	var status: Node = host.get_node_or_null("StatusEffects")
	if status != null and status.has_method("get_damage_taken_multiplier"):
		return status.get_damage_taken_multiplier()
	return 1.0


## 治疗回复
func heal(amount: int) -> void:
	# 已死亡或治疗无效（<=0）时忽略
	if _is_dead or amount <= 0:
		return

	# 回复气血，并限制不超过上限
	current_qi_blood = min(current_qi_blood + amount, max_qi_blood)
	healed.emit(amount, current_qi_blood)


## 内部：处理死亡，保证 died 只发出一次
func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit()


## 是否已死亡（供毒爆等外部逻辑判断死亡状态）
func is_dead() -> bool:
	return _is_dead


## 获取当前气血
func get_current_qi_blood() -> int:
	return current_qi_blood


## 获取气血上限
func get_max_qi_blood() -> int:
	return max_qi_blood


## 设置气血上限；refill 为 true 时同步补满当前气血到新上限
func set_max_qi_blood(value: int, refill: bool = true) -> void:
	max_qi_blood = max(1, value)
	if refill:
		current_qi_blood = max_qi_blood
	else:
		current_qi_blood = min(current_qi_blood, max_qi_blood)
