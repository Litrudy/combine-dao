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
## 灵狼场景，召唤时实例化
const SPIRIT_WOLF_SCENE: PackedScene = preload("res://scenes/ally/spirit_wolf.tscn")
## 毒雾场景，释放时实例化
const POISON_MIST_SCENE: PackedScene = preload("res://scenes/player/poison_mist.tscn")

var qi_blood: int
var mana: int

## 当前修为
var cultivation_exp: int = 0
## 突破所需修为
var cultivation_exp_required: int = 3
## 修炼层数
var cultivation_level: int = 1

## 剑气流：剑气伤害加成（由机缘累加）
var sword_damage_bonus: int = 0
## 剑气流：剑气额外穿透次数
var sword_pierce_bonus: int = 0
## 剑气流：是否启用残血斩杀
var sword_execute_enabled: bool = false

## 御兽流：已召唤的灵狼列表
var summoned_wolves: Array[Node] = []
## 御兽流：灵兽攻速倍率
var beast_attack_speed_multiplier: float = 1.0
## 御兽流：是否启用灵兽护主
var beast_guard_enabled: bool = false
## 御兽流：灵兽护主减伤比例（40%）
var beast_guard_ratio: float = 0.4

## 毒蛊流：是否解锁毒雾（Q 释放）
var poison_mist_unlocked: bool = false
## 毒蛊流：是否启用叠毒
var poison_stack_enabled: bool = false
## 毒蛊流：是否启用毒爆
var poison_explosion_enabled: bool = false
## 毒蛊流：毒伤加成
var poison_damage_bonus: int = 0
## 毒蛊流：叠毒最大层数
var poison_max_stack: int = 1
## 毒雾释放冷却（秒）
@export var poison_cast_cooldown: float = 3.0

## 攻击冷却剩余时间，<=0 时可再次攻击
var _attack_timer: float = 0.0
## 毒雾释放冷却剩余时间，<=0 时可再次释放
var _poison_cast_timer: float = 0.0
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
	# 毒雾冷却递减
	if _poison_cast_timer > 0.0:
		_poison_cast_timer -= delta

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

	# Q 键：在鼠标位置释放毒雾
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		cast_poison_mist()
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
	# 叠加剑气流机缘效果：伤害、穿透、斩杀
	sword_qi.damage += sword_damage_bonus
	sword_qi.pierce_remaining = sword_pierce_bonus
	sword_qi.execute_enabled = sword_execute_enabled
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
	# 应用效果（具体效果与提示由 apply_boon 处理）
	apply_boon(boon)

	# 突破：层数 +1，修为清零（所需修为暂保持不变，方便测试）
	cultivation_level += 1
	cultivation_exp = 0

	# 恢复移动与攻击
	_choosing_boon = false


## 根据机缘 id 应用效果（M1 任务 7：实现剑气流三个机缘）
func apply_boon(boon: Dictionary) -> void:
	var id: String = boon.get("id", "")

	match id:
		# ===== 剑气流 =====
		"sword_qi_basic":
			# 基础剑气：剑气伤害 +6
			sword_damage_bonus += 6
			print("已获得机缘：基础剑气，剑气伤害 +6")
		"sword_qi_pierce":
			# 剑气穿透：额外穿透次数 +2
			sword_pierce_bonus += 2
			print("已获得机缘：剑气穿透，穿透次数 +2")
		"sword_execute":
			# 残血斩杀：开启斩杀低血敌人
			sword_execute_enabled = true
			print("已获得机缘：残血斩杀，剑气可斩杀低于 20% 气血的敌人")
		# ===== 御兽流 =====
		"beast_summon_wolf":
			# 召唤灵狼：实例化一只灵狼协助作战
			summon_spirit_wolf()
			print("已获得机缘：召唤灵狼，灵狼加入战斗")
		"beast_attack_speed":
			# 灵兽攻速提升：倍率 +0.3 并同步到已有灵狼
			beast_attack_speed_multiplier += 0.3
			update_wolf_attack_speed()
			print("已获得机缘：灵兽攻速提升，灵兽攻速 +30%")
		"beast_guard":
			# 灵兽护主：开启减伤
			beast_guard_enabled = true
			print("已获得机缘：灵兽护主，灵兽为玩家分担 40% 伤害")
		# ===== 毒蛊流 =====
		"poison_mist":
			# 毒雾：解锁 Q 键释放毒雾
			poison_mist_unlocked = true
			poison_damage_bonus += 0
			print("已获得机缘：毒雾，按 Q 可在鼠标位置释放毒雾")
		"poison_stack":
			# 叠毒：开启叠毒，最多 5 层
			poison_stack_enabled = true
			poison_max_stack = 5
			print("已获得机缘：叠毒，毒伤最多叠加 5 层")
		"poison_explosion":
			# 毒爆：中毒目标死亡时扩散毒伤
			poison_explosion_enabled = true
			print("已获得机缘：毒爆，中毒目标死亡时扩散毒伤")
		_:
			# 未知机缘，兜底提示
			print("已获得机缘：", boon.get("boon_name", "?"), "（效果未实现）")


# ===== 御兽流 =====

## 召唤一只灵狼
func summon_spirit_wolf() -> void:
	var wolf := SPIRIT_WOLF_SCENE.instantiate()
	# 添加到当前场景（玩家的父节点下）
	get_parent().add_child(wolf)
	# 位置设在玩家附近，带一点随机偏移避免多只重叠
	wolf.global_position = global_position + Vector2(
		randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)
	)
	# 绑定主人
	if wolf.has_method("setup"):
		wolf.setup(self)
	# 记录并按当前攻速倍率更新
	summoned_wolves.append(wolf)
	update_wolf_attack_speed()


## 把当前攻速倍率同步到所有存活灵狼
func update_wolf_attack_speed() -> void:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			wolf.attack_speed_multiplier = beast_attack_speed_multiplier


## 是否还有存活的灵狼
func has_alive_wolf() -> bool:
	for wolf in summoned_wolves:
		if is_instance_valid(wolf):
			return true
	return false


## 玩家统一受伤入口（妖兽攻击经此处理，便于灵兽护主减伤）
func receive_damage(amount: int) -> void:
	var final_damage: int = amount
	# 灵兽护主：拥有存活灵狼时分担部分伤害
	if beast_guard_enabled and has_alive_wolf():
		var reduced: int = int(round(amount * beast_guard_ratio))
		final_damage = amount - reduced
		print("灵兽护主，减免伤害：", reduced)
	vitals.take_damage(final_damage)


# ===== 毒蛊流 =====

## 在鼠标位置释放毒雾（Q 键），受冷却限制
func cast_poison_mist() -> void:
	# 未解锁毒雾则不释放
	if not poison_mist_unlocked:
		return
	# 冷却未结束则不释放
	if _poison_cast_timer > 0.0:
		return

	# 实例化毒雾并放到鼠标世界坐标
	var mist := POISON_MIST_SCENE.instantiate()
	get_parent().add_child(mist)
	mist.global_position = get_global_mouse_position()
	# 传入当前毒蛊参数
	mist.damage_per_second = 3 + poison_damage_bonus
	mist.poison_stack_enabled = poison_stack_enabled
	mist.max_poison_stack = poison_max_stack
	mist.poison_explosion_enabled = poison_explosion_enabled

	# 重置冷却
	_poison_cast_timer = poison_cast_cooldown


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
