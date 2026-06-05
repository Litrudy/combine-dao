extends RealmEvent
## 遗落宝匣：触发后随机获得 3-6 个天道石

func apply_event_effect(player: Node) -> void:
	var amount: int = randi_range(3, 6)
	if player.has_method("gain_heavenly_stones"):
		player.gain_heavenly_stones(amount)
	print("开启宝匣，获得天道石：", amount)
