extends RealmEvent
## 天道残碑：触发后打开一次额外机缘三选一（不消耗修为、不结算突破）

func apply_event_effect(player: Node) -> void:
	if player.has_method("open_bonus_boon_choice"):
		player.open_bonus_boon_choice()
	print("参悟天道残碑，获得一次机缘选择。")
