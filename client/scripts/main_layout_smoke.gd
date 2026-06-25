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
	var table_main_menu_button := visual.find_child("TableMainMenuButton", true, false) as Control
	_require(table_main_menu_button != null and not table_main_menu_button.visible, "table hides the direct Main Menu button until the game is over")
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
	_require(short_popup_rows <= 6 and short_popup_rows >= 1, "short history popup uses an internal scroller instead of overflowing the screen")
	var tall_popup_rows := int(main.call("_history_popup_row_count_for_size", Vector2i(680, 900)))
	_require(tall_popup_rows <= 6, "history popup caps visible rows even on tall screens")
	var transaction_label := str(main.call("_transaction_history_label", _transaction_order_fixture()))
	_require(transaction_label.find("3 | Cara") < transaction_label.find("1 | Amina"), "transaction history display shows newest rows first")

	var viewport_width := root.get_viewport().get_visible_rect().size.x
	var viewport_height := root.get_viewport().get_visible_rect().size.y
	var holder_rect := holder.get_global_rect()
	var visual_rect := visual.get_global_rect()
	_require(holder_rect.end.x <= viewport_width + 1.0, "table holder fits the viewport width")
	_require(visual_rect.end.x <= viewport_width + 1.0, "table visual fits the viewport width")
	_require(visual_rect.end.y <= viewport_height - 6.0, "table visual leaves a bottom safety margin; visual=%s viewport=%s" % [visual_rect, root.get_viewport().get_visible_rect()])
	_require(visual_rect.size.y < 1000.0, "table visual height follows content without a large blank bottom band")
	var basket_area := visual.find_child("BasketTableArea", true, false) as Control
	_require(visual.find_child("Title_Cooks", true, false) == null, "main scene table omits the separate Cooks title")
	_require(basket_area != null and basket_area.get_global_rect().position.y - visual_rect.position.y < 80.0, "table content is top-aligned without a large blank band")

	visual.call("debug_flush_animations")
	await process_frame
	main.set("_last_controlled_turn_participant_id", "p2")
	recipes_client.send_intent({"type": "pass_turn"})
	for _index in range(180):
		if str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p2":
			break
		await process_frame
	_require(str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p2", "main view follows a controlled current turn even if the last-turn marker is stale")
	recipes_client.view_as("p1")
	await process_frame

	main.call("_return_to_main_menu")
	await process_frame
	recipes_client.start_offline_table("", "controlled-after-bot")
	await process_frame
	recipes_client.send_host_intent({"type": "add_controlled_seat", "participantId": "p3", "name": "Nia"})
	await process_frame
	recipes_client.send_host_intent({"type": "start"})
	for _controlled_setup_frame in range(16):
		await process_frame
	visual.call("debug_flush_animations")
	await process_frame
	recipes_client.send_intent({"type": "pass_turn"})
	var saw_intervening_bot_turn := false
	for _controlled_follow_frame in range(1200):
		var stats: Dictionary = visual.get("debug_stats")
		if str(stats.get("currentTurnParticipantId", "")) == "p2":
			saw_intervening_bot_turn = true
		if str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p3":
			break
		await process_frame
	_require(saw_intervening_bot_turn, "main view shows the intervening bot turn before following the next controlled human")
	_require(str(recipes_client.latest_snapshot.get("viewerParticipantId", "")) == "p3", "main view follows a controlled human seat after an intervening bot turn")
	_require(str(recipes_client.latest_snapshot.get("currentTurnParticipantId", "")) == "p3", "controlled human seat is the active turn after the bot")
	_require(not recipes_client.latest_snapshot.get("ownHand", []).is_empty(), "controlled turn view shows that seat's own hand")
	_require(not recipes_client.latest_snapshot.get("ownRecipe", {}).is_empty(), "controlled turn view shows that seat's own recipe")

	main.call("_fit_table_visual_to_window")
	var narrow_visual_rect := visual.get_global_rect()
	_require(narrow_visual_rect.size.x <= root.get_viewport().get_visible_rect().size.x + 1.0, "table visual fits the current debug viewport; holder=%s visual=%s scale=%s" % [holder.size, narrow_visual_rect.size, visual.scale])
	var preferred_size: Vector2 = visual.call("preferred_visual_size")
	var stable_holder_height := holder.custom_minimum_size.y
	var stable_visual_scale := visual.scale
	var recipe_label := visual.find_child("RecipeName", true, false) as Control
	if recipe_label == null:
		recipe_label = visual.find_child("BasketTableArea", true, false) as Control
	var original_recipe_min := recipe_label.custom_minimum_size if recipe_label != null else Vector2.ZERO
	if recipe_label != null:
		recipe_label.custom_minimum_size = preferred_size + Vector2(240, 180)
	main.call("_fit_table_visual_to_window")
	_require(visual.scale == stable_visual_scale, "table visual fit keeps scale stable when child minimums grow; before=%s after=%s preferred=%s child_min=%s" % [stable_visual_scale, visual.scale, preferred_size, recipe_label.custom_minimum_size if recipe_label != null else Vector2.ZERO])
	_require(holder.custom_minimum_size.y == stable_holder_height, "table visual holder height stays stable when child minimums grow")
	if recipe_label != null:
		recipe_label.custom_minimum_size = original_recipe_min

	main.call("_return_to_main_menu")
	await process_frame
	_require(post_controls != null and not post_controls.visible, "post-table End Game controls hide on the title screen")
	var table_menu_button := visual.find_child("TableMenuButton", true, false) as Control
	_require(table_menu_button != null and not table_menu_button.visible, "table hamburger menu hides on the title screen")
	_require(table_main_menu_button != null and not table_main_menu_button.visible, "table Main Menu overlay hides on the title screen")

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
