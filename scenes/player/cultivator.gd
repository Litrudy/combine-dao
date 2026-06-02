extends CharacterBody2D

## 修士（玩家）移动脚本
## M1 任务 1 —— 仅实现俯视角 WASD 移动，不含战斗 / 升级 / 机缘等系统。

@export var speed: float = 200.0
@export var max_qi_blood: int = 100
@export var max_mana: int = 50

var qi_blood: int
var mana: int

## 气血组件（子节点 Vitals），负责气血、受伤、治疗与死亡
@onready var vitals: Vitals = $Vitals


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	qi_blood = max_qi_blood
	mana = max_mana

	# 连接气血组件的三个信号
	vitals.damaged.connect(_on_vitals_damaged)
	vitals.healed.connect(_on_vitals_healed)
	vitals.died.connect(_on_vitals_died)


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	velocity = direction * speed
	move_and_slide()


# ===== 临时调试输入：K 受伤 10 点，H 回血 10 点 =====
# TODO: M1 调试用，正式战斗系统接入后移除
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_K:
				vitals.take_damage(10)
			KEY_H:
				vitals.heal(10)


# ===== 气血组件信号回调 =====

## 受伤时打印剩余气血
func _on_vitals_damaged(_amount: int, current_qi_blood: int) -> void:
	print("受伤，当前气血：", current_qi_blood)


## 治疗时打印当前气血
func _on_vitals_healed(_amount: int, current_qi_blood: int) -> void:
	print("回复，当前气血：", current_qi_blood)


## 死亡时打印提示
func _on_vitals_died() -> void:
	print("修士陨落")
