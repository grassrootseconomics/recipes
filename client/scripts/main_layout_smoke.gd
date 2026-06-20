extends SceneTree


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame

	var recipes_client := root.get_node("/root/RecipesClient")
	recipes_client.start_offline_table("", "")
	await process_frame
	recipes_client.send_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "Ben"})
	await process_frame
	recipes_client.send_host_intent({"type": "start"})
	for _index in range(12):
		await process_frame

	var holder := _control_from_property(main, "_table_visual_holder")
	var visual := _control_from_property(main, "_table_visual")
	_require(holder != null, "main scene has a table visual holder")
	_require(visual != null, "main scene has a table visual")
	_require(holder.visible, "table visual holder is visible after start")
	var transaction_section := _control_from_property(main, "_transaction_section")
	_require(transaction_section != null and not transaction_section.visible, "Successful Transactions section is hidden below the table")
	var post_controls := _control_from_property(main, "_post_table_controls")
	_require(post_controls != null and not post_controls.visible, "post-table End Game controls are hidden during play")
	var root_scroll := _control_from_property(main, "_root_scroll") as ScrollContainer
	_require(root_scroll != null and root_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "main table view disables root page scrolling during play")
	var offline_end_overlay := _control_from_property(main, "_offline_end_popup")
	_require(offline_end_overlay != null, "offline stop cooking popup is an in-tree overlay")
	_require(_window_property_false(main, "_history_popup", "popup_window"), "history popup does not auto-dismiss on focus loss")
	_require(_window_property_false(main, "_select_popup", "popup_window"), "select popup does not auto-dismiss on focus loss")
	_require(_window_property_false(main, "_confirm_leave_dialog", "popup_window"), "confirmation dialogs do not auto-dismiss on focus loss")
	main.call("_confirm_offline_end_game")
	await process_frame
	_require(offline_end_overlay != null and offline_end_overlay.visible, "offline stop cooking popup opens")
	var stop_panel := offline_end_overlay.find_child("StopCookingPanel", true, false) as Control
	_require(stop_panel != null and stop_panel.get_global_rect().size.y <= 170, "offline stop cooking popup stays compact, got %s" % [stop_panel.get_global_rect().size if stop_panel != null else Vector2.ZERO])
	offline_end_overlay.hide()
	var short_popup_rows := int(main.call("_history_popup_row_count_for_size", Vector2i(480, 520)))
	_require(short_popup_rows <= 8 and short_popup_rows >= 1, "short history popup uses an internal scroller instead of overflowing the screen")
	var tall_popup_rows := int(main.call("_history_popup_row_count_for_size", Vector2i(680, 900)))
	_require(tall_popup_rows <= 8, "history popup caps visible rows even on tall screens")
	var transaction_label := str(main.call("_transaction_history_label", _transaction_order_fixture()))
	_require(transaction_label.find("3 | Cara") < transaction_label.find("1 | Amina"), "transaction history display shows newest rows first")

	var viewport_width := root.get_viewport().get_visible_rect().size.x
	var holder_rect := holder.get_global_rect()
	var visual_rect := visual.get_global_rect()
	_require(holder_rect.end.x <= viewport_width + 1.0, "table holder fits the viewport width")
	_require(visual_rect.end.x <= viewport_width + 1.0, "table visual fits the viewport width")
	_require(visual_rect.size.y < 1000.0, "table visual height follows content without a large blank bottom band")
	var cooks_title := visual.find_child("Title_Cooks", true, false) as Control
	_require(cooks_title != null, "main scene table renders the Cooks title")
	_require(cooks_title.get_global_rect().position.y - visual_rect.position.y < 80.0, "table content is top-aligned without a large blank band")

	main.set("_last_controlled_turn_participant_id", "p2")
	recipes_client.send_intent({"type": "pass_turn"})
	for _index in range(8):
		if str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p2":
			break
		await process_frame
	_require(str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p2", "main view follows a controlled current turn even if the last-turn marker is stale")
	recipes_client.view_as("p1")
	await process_frame

	holder.size = Vector2(480, holder.size.y)
	main.call("_fit_table_visual_to_window")
	var narrow_visual_rect := visual.get_global_rect()
	_require(narrow_visual_rect.size.x <= 481.0, "table visual scales down for a 480px desktop debug width")

	main.call("_return_to_main_menu")
	await process_frame
	_require(post_controls != null and not post_controls.visible, "post-table End Game controls hide on the title screen")
	var table_menu_button := visual.find_child("TableMenuButton", true, false) as Control
	_require(table_menu_button != null and not table_menu_button.visible, "table hamburger menu hides on the title screen")

	recipes_client.start_offline_table("", "renamed-bot-visual")
	await process_frame
	recipes_client.send_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "jjj_b"})
	await process_frame
	recipes_client.send_host_intent({"type": "convert_to_bot", "participantId": "p2", "botType": "mixed"})
	await process_frame
	_require(str(recipes_client.latest_snapshot.get("participants", [])[1].get("name", "")) == "jjj_b", "visual smoke starts with toggled bot named jjj_b")
	_require(str(recipes_client.latest_snapshot.get("participants", [])[1].get("kind", "")) == "bot", "visual smoke starts with p2 as a bot")
	recipes_client.send_host_intent({"type": "start"})
	for _index in range(20):
		await process_frame
	visual.call("debug_flush_animations")
	await process_frame
	visual.call("debug_press_pass_turn_action")
	var saw_jjj_transaction := false
	var saw_bot_animation := false
	for _index in range(700):
		for raw_transaction in recipes_client.latest_snapshot.get("transactionHistory", []):
			var transaction: Dictionary = raw_transaction
			if str(transaction.get("name", "")) == "jjj_b":
				saw_jjj_transaction = true
		var stats: Dictionary = visual.get("debug_stats")
		for raw_type in stats.get("lastAnimationTypes", []):
			var animation_type := str(raw_type)
			if animation_type == "public_redeem" or animation_type == "swap" or animation_type == "turn":
				saw_bot_animation = true
		if saw_jjj_transaction and saw_bot_animation and str(recipes_client.latest_snapshot.get("currentTurnParticipantId", "")) == "p1":
			break
		await process_frame
	_require(saw_jjj_transaction, "renamed bot jjj_b produces visible transaction history after pass")
	_require(saw_bot_animation, "renamed bot jjj_b produces visual bot-turn animation events after pass")
	_require(str(recipes_client.latest_snapshot.get("currentTurnParticipantId", "")) == "p1", "renamed bot visual smoke returns turn to Amina")
	print("main layout smoke ok")
	quit(0)


func _control_from_property(node: Node, property_name: String) -> Control:
	var value = node.get(property_name)
	if value is Control:
		return value
	return null


func _window_property_false(node: Node, property_name: String, window_property_name: String) -> bool:
	var value = node.get(property_name)
	if not value is Window:
		return false
	return not bool(value.get(window_property_name))


func _transaction_order_fixture() -> Dictionary:
	return {
		"transactionHistory": [
			{"turn": 1, "name": "Amina", "action": "Deposit", "counterparty": "Platter", "itemOut": "Cheese", "itemBack": "None"},
			{"turn": 2, "name": "Ben", "action": "Swap", "counterparty": "Platter", "itemOut": "Flour", "itemBack": "Herbs"},
			{"turn": 3, "name": "Cara", "action": "Redeem", "counterparty": "Amina", "itemOut": "Cheese", "itemBack": "Real Cheese"}
		]
	}


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
