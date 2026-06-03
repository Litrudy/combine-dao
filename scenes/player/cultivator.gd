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

## 剑气伤害加成（由机缘累加）
var sword_damage_bonus: int = 0

## 攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0
## 是否正在选择机缘（期间禁止移动与攻击）
var _choosing_boon: bool = false

## 机缘管理器，负责抽取机缘
var _boon_manager := BoonManager.new()
## 机缘选择面板（运行时从分组查找）
var _boon_panel: Node = null

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

	# 延迟一帧连接机缘面板，确保面板已进入场景树并加入分组
	_connect_boon_panel.call_deferred()


func _physics_process(delta: float) -> void:
	# 攻击冷却递减
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# 选择机缘期间禁止移动
	if _choosing_boon:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	velocity = direction * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# 选择机缘期间禁止一切操作
	if _choosing_boon:
		return

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
	# 叠加机缘提供的剑气伤害加成
	sword_qi.damage += sword_damage_bonus
	# 添加到场景树（挂到父节点下，使剑气独立于玩家移动）
	get_parent().add_child(sword_qi)

	# 重置冷却
	_attack_timer = attack_cooldown


# ===== 修为 / 机缘 =====

## 获得修为（由妖兽死亡等外部来源调用）
func gain_cultivation_exp(amount: int) -> void:
	# 正在选择机缘时不再累计，避免重复触发
	if _choosing_boon:
		return

	cultivation_exp += amount
	print("获得修为：", amount, "，当前修为：", cultivation_exp, " / ", cultivation_exp_required)

	# 修为达到突破所需值，触发机缘三选一
	if cultivation_exp >= cultivation_exp_required:
		_trigger_boon_choice()


## 查找并连接机缘选择面板
func _connect_boon_panel() -> void:
	_boon_panel = get_tree().get_first_node_in_group("boon_choice_panel")
	if _boon_panel != null and not _boon_panel.boon_selected.is_connected(_on_boon_selected):
		_boon_panel.boon_selected.connect(_on_boon_selected)


## 触发机缘三选一
func _trigger_boon_choice() -> void:
	if _choosing_boon:
		return

	# 兜底：若尚未连接面板，再尝试查找一次
	if _boon_panel == null:
		_connect_boon_panel()
	if _boon_panel == null:
		push_warning("未找到机缘选择面板（BoonChoicePanel），无法弹出三选一")
		return

	# 进入选择状态，封锁移动与攻击
	_choosing_boon = true
	var boons: Array = _boon_manager.roll_boons(3)
	_boon_panel.show_boons(boons)


## 机缘被选择后的回调
func _on_boon_selected(boon: Dictionary) -> void:
	apply_boon(boon)
	print("已获得机缘：", boon.get("boon_name", "?"))

	# 突破：层数 +1，修为清零（所需修为暂保持不变，方便测试）
	cultivation_level += 1
	cultivation_exp = 0

	# 恢复移动与攻击
	_choosing_boon = false


## 根据机缘的 effect_type 应用效果
func apply_boon(boon: Dictionary) -> void:
	var effect_type: String = boon.get("effect_type", "")
	var value: float = float(boon.get("effect_value", 0))

	match effect_type:
		"sword_damage_bonus":
			# 增加剑气伤害
			sword_damage_bonus += int(value)
		"speed_bonus":
			# 增加移动速度
			speed += value
		"max_hp_bonus":
			# 增加气血上限，并同步补满新增的气血
			vitals.max_qi_blood += int(value)
			vitals.current_qi_blood += int(value)
			max_qi_blood = vitals.max_qi_blood
		"attack_cooldown_bonus":
			# 减少攻击冷却（下限保护，避免过低）
			attack_cooldown = max(attack_cooldown - value, 0.05)
		_:
			# 其余效果（穿透 / 斩杀 / 御兽 / 毒系）留待后续里程碑实现
			print("（机缘效果暂未实现，留待后续里程碑：", effect_type, "）")


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
