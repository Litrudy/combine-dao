extends Node2D
## 战斗单位反馈组件（最小实现）
## 复用同级 Vitals 数据，提供：头顶血条 + 受击闪白 + 漂浮伤害数字。
## 纯表现层：不参与碰撞、不改伤害结算、不重写 Vitals。
## 用法：作为战斗单位（含 Vitals + Visual 子节点）的子节点挂上即可，无需改单位脚本。

## 漂浮伤害数字场景
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/floating_damage_number.tscn")

## ===== 血条外观（可在各单位场景实例上调整）=====
@export var bar_width: float = 40.0
@export var bar_height: float = 5.0
## 血条相对单位原点的纵向偏移（负值在头顶上方）
@export var bar_offset_y: float = -38.0
@export var bar_bg_color: Color = Color(0, 0, 0, 0.6)
@export var bar_fill_color: Color = Color(0.85, 0.2, 0.2, 1.0)
@export var bar_border_color: Color = Color(0, 0, 0, 0.8)

## ===== 伤害数字颜色（按类型）=====
const COLOR_NORMAL: Color = Color(1.0, 0.95, 0.6)
const COLOR_POISON: Color = Color(0.5, 0.95, 0.4)
const COLOR_SUMMON: Color = Color(0.55, 0.75, 1.0)

## 同级气血组件与显示精灵
var _vitals: Vitals = null
var _sprite: CanvasItem = null

var _max: int = 1
var _current: int = 1
## 死亡后隐藏血条
var _bar_hidden: bool = false
## 受击闪白还原用的基础 modulate 与当前闪白 tween
var _base_modulate: Color = Color.WHITE
var _flash_tween: Tween = null


func _ready() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	_vitals = host.get_node_or_null("Vitals") as Vitals
	_sprite = host.get_node_or_null("Visual") as CanvasItem
	if _vitals == null:
		return
	_vitals.damaged.connect(_on_damaged)
	_vitals.healed.connect(_on_healed)
	_vitals.died.connect(_on_died)
	# 延迟一帧初始化：等单位 _ready（如精英强化改最大气血）执行完再读取准确数值
	_init_values.call_deferred()


## 初始化血量与基础 modulate（在单位 _ready 之后）
func _init_values() -> void:
	if _vitals == null:
		return
	_max = max(1, _vitals.get_max_qi_blood())
	_current = _vitals.get_current_qi_blood()
	if _sprite != null:
		_base_modulate = _sprite.modulate
	queue_redraw()


## 受伤：刷新血条 + 闪白 + 弹出伤害数字
func _on_damaged(amount: int, current: int) -> void:
	_max = max(1, _vitals.get_max_qi_blood())
	_current = current
	queue_redraw()
	_play_flash()
	_spawn_damage_number(amount, _vitals.last_damage_type)


## 治疗：仅刷新血条
func _on_healed(_amount: int, current: int) -> void:
	_current = current
	queue_redraw()


## 死亡：隐藏血条（单位本体的死亡表现由各单位脚本处理）
func _on_died() -> void:
	_bar_hidden = true
	queue_redraw()


## 受击闪白：把 Visual 短暂提亮后还原到基础 modulate
func _play_flash() -> void:
	if _sprite == null:
		return
	# 仅在当前没有闪白进行时捕获基础 modulate，避免把"闪白色"当成基础色
	# （这样精英怪的金色等后置 modulate 也能被正确还原）
	if _flash_tween == null or not _flash_tween.is_valid():
		_base_modulate = _sprite.modulate
	else:
		_flash_tween.kill()
	_sprite.modulate = Color(3.0, 3.0, 3.0, _base_modulate.a)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", _base_modulate, 0.12)


## 生成漂浮伤害数字（加到当前场景，独立于单位，单位死亡后数字仍会播完）
func _spawn_damage_number(amount: int, damage_type: String) -> void:
	if amount <= 0:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var number: Node2D = DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	scene_root.add_child(number)
	number.global_position = global_position + Vector2(0, bar_offset_y)
	number.setup(amount, _color_for_type(damage_type))


## 按伤害类型取颜色
func _color_for_type(damage_type: String) -> Color:
	match damage_type:
		"poison":
			return COLOR_POISON
		"summon":
			return COLOR_SUMMON
		_:
			return COLOR_NORMAL


func _draw() -> void:
	if _bar_hidden:
		return
	var ratio: float = clampf(float(_current) / float(_max), 0.0, 1.0)
	var x: float = -bar_width * 0.5
	var bg := Rect2(x, bar_offset_y, bar_width, bar_height)
	# 背景 + 边框 + 血量填充
	draw_rect(bg, bar_bg_color, true)
	draw_rect(Rect2(x, bar_offset_y, bar_width * ratio, bar_height), bar_fill_color, true)
	draw_rect(bg, bar_border_color, false, 1.0)
