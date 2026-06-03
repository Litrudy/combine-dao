extends CharacterBody2D

## 修士（玩家）移动脚本
## M1 任务 1 —— 仅实现俯视角 WASD 移动，不含战斗 / 升级 / 机缘等系统。

@export var speed: float = 200.0
@export var max_qi_blood: int = 100
@export var max_mana: int = 50

## 剑气攻击冷却（秒）
@export var attack_cooldown: float = 0.4

## 剑气场景，释放时实例化
const SwordQiScene: PackedScene = preload("res://scenes/player/sword_qi.tscn")

var qi_blood: int
var mana: int

## 当前修为
var cultivation_exp: int = 0
## 突破所需修为
var cultivation_exp_required: int = 3
## 修炼层数
var cultivation_level: int = 1

## 攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0

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


func _physics_process(delta: float) -> void:
	# 攻击冷却递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	velocity = direction * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标左键（attack_primary）释放剑气
	if event.is_action_pressed("attack_primary"):
		_release_sword_qi()
		return

	# ===== 临时调试输入：K 受伤 10 点，H 回血 10 点 =====
	# TODO: M1 调试用，正式战斗系统接入后移除
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_K:
				vitals.take_damage(10)
			KEY_H:
				vitals.heal(10)


## 释放剑气（鼠标左键），受攻击冷却限制
func _release_sword_qi() -> void:
	# 冷却未结束则不释放
	if _attack_timer > 0.0:
		return

	# 方向：玩家当前位置 → 鼠标世界坐标
	var direction: Vector2 = (get_global_mouse_position() - global_position).normalized()
	# 若鼠标恰好与玩家重合导致方向为零，则跳过本次释放
	if direction == Vector2.ZERO:
		return

	# 实例化剑气，从玩家当前位置生成，朝鼠标方向飞行
	var sword_qi := SwordQiScene.instantiate()
	sword_qi.global_position = global_position
	sword_qi.direction = direction
	# 添加到场景树（挂到父节点下，使剑气独立于玩家移动）
	get_parent().add_child(sword_qi)

	# 重置冷却
	_attack_timer = attack_cooldown


# ===== 修为 =====

## 获得修为（由妖兽死亡等外部来源调用）
func gain_cultivation_exp(amount: int) -> void:
	cultivation_exp += amount
	print("获得修为：", amount, "，当前修为：", cultivation_exp, " / ", cultivation_exp_required)

	# 修为达到突破所需值，暂时只提示（突破面板留待 M1 任务 6）
	if cultivation_exp >= cultivation_exp_required:
		print("修为已满，可以突破")


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
