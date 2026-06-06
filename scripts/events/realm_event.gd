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
## 默认即时结算事件（灵泉 / 宝匣 / 残碑）；风险事件可重写本方法改为打开选择面板。
func trigger_event(player: Node) -> bool:
	# 已使用或无玩家则不触发
	if used or player == null:
		return false
	mark_used()
	# 应用子类效果
	apply_event_effect(player)
	return true


## 标记事件为已使用、发出触发信号并置灰
## （即时事件经 trigger_event 调用；风险事件在玩家确认提交选项后调用，取消则不调用）
func mark_used() -> void:
	used = true
	current_player = null
	event_triggered.emit(event_id)
	_apply_used_visual()


## 虚方法：实际事件效果，由子类重写
func apply_event_effect(_player: Node) -> void:
	pass


## 触发后切换为「已使用」外观并停止范围检测
## 双帧素材（Sprite2D，hframes/vframes>1）切到最后一帧表示失效；
## 无双帧素材的占位事件（Polygon2D）则退回整体置灰。
func _apply_used_visual() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual is Sprite2D:
		var spr: Sprite2D = visual as Sprite2D
		var frame_count: int = maxi(spr.hframes, 1) * maxi(spr.vframes, 1)
		if frame_count > 1:
			# 切到最后一帧（frame 1）：已使用 / 失效状态
			spr.frame = frame_count - 1
		else:
			modulate = Color(0.4, 0.4, 0.4, 0.5)
	else:
		modulate = Color(0.4, 0.4, 0.4, 0.5)
	# 延迟关闭监测，避免在信号回调中修改物理状态
	set_deferred("monitoring", false)
