extends RealmEvent
## 灵泉：触发后回复玩家 30% 最大气血

func apply_event_effect(player: Node) -> void:
	var v: Vitals = player.get_node_or_null("Vitals") as Vitals
	if v == null:
		return
	var amount: int = int(round(v.get_max_qi_blood() * 0.3))
	v.heal(amount)
	print("灵泉涌动，恢复气血：", amount)
