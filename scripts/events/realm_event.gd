extends Area2D
class_name RealmEvent
## 秘境事件点基类
## 玩家进入范围后按 F 触发一次性事件，具体效果由子类重写 apply_event_effect。

## 事件被触发时发出（携带 event_id）
signal event_triggered(event_id: String)

## 事件唯一标识
@export var event_id: String = ""
## 事件显示名（交互提示用）
@export var event_name: String = "未知事件"
## 事件描述
@export var description: String = ""
## 是否已使用（true 时不可再触发）
@export var used: bool = false
## 交互范围（应与 CollisionShape2D 半径一致）
@export var interact_range: float = 80.0

## 当前处于范围内的玩家（进入时记录，离开时清空）
var current_player: Node = null


func _ready() -> void:
	# 加入分组，供玩家与交互提示查找
	add_to_group("realm_event")
	# 检测玩家进出范围
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 若初始即为已使用，直接置灰
	if used:
		_apply_used_visual()


## 玩家进入范围
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		current_player = body


## 玩家离开范围
func _on_body_exited(body: Node) -> void:
	if body == current_player:
		current_player = null


## 是否可交互：未使用且玩家在范围内
func can_interact() -> bool:
	return not used and is_instance_valid(current_player)


## 触发事件（玩家按 F 时调用）。成功返回 true
func trigger_event(player: Node) -> bool:
	# 已使用或无玩家则不触发
	if used or player == null:
		return false
	used = true
	# 应用子类效果
	apply_event_effect(player)
	event_triggered.emit(event_id)
	# 触发后置灰并停止检测
	_apply_used_visual()
	current_player = null
	return true


## 虚方法：实际事件效果，由子类重写
func apply_event_effect(_player: Node) -> void:
	pass


## 触发后视觉变灰并停止范围检测
func _apply_used_visual() -> void:
	modulate = Color(0.4, 0.4, 0.4, 0.5)
	# 延迟关闭监测，避免在信号回调中修改物理状态
	set_deferred("monitoring", false)
