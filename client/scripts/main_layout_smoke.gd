extends SceneTree


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	var app_tablecloth := main.find_child("AppTableclothBackground", true, false) as Control
	_require(app_tablecloth != null and app_tablecloth.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main scene renders a tiled tablecloth outside the table panel")

	var original_window_size := root.size
	root.size = Vector2i(360, 740)
	await process_frame
	main.call("_show_online_setup")
	await process_frame
	main.call("_refresh_connection_buttons", {})
	await process_frame
	var phone_viewport_width := root.get_viewport().get_visible_rect().size.x
	var online_setup_panel := _control_from_property(main, "_online_setup_panel")
	var server_option := _control_from_property(main, "_server_option")
	var code_input := _control_from_property(main, "_code_input")
	var generate_button := _control_from_property(main, "_generate_code_button")
	_require(online_setup_panel != null and online_setup_panel.visible, "phone create/join setup is visible")
	_require(online_setup_panel != null and online_setup_panel.get_global_rect().end.x <= phone_viewport_width + 1.0, "phone create/join setup fits viewport width; panel=%s viewport=%s" % [online_setup_panel.get_global_rect(), phone_viewport_width])
	_require(server_option != null and server_option.get_global_rect().end.x <= phone_viewport_width + 1.0, "phone server chooser fits viewport width; option=%s viewport=%s" % [server_option.get_global_rect(), phone_viewport_width])
	_require(code_input != null and generate_button != null and generate_button.get_global_rect().position.x > code_input.get_global_rect().position.x and generate_button.get_global_rect().end.x <= phone_viewport_width + 1.0, "phone invite code row keeps Generate inside the viewport")
	main.call("_return_to_main_menu")
	root.size = original_window_size
	await process_frame

	var online_waiting_snapshot := _online_lobby_snapshot(false)
	_require(str(main.call("_host_lobby_start_label", online_waiting_snapshot)) == "Waiting for Cooks", "online host lobby waits for another cook before start")
	_require(not bool(main.call("_host_lobby_start_enabled", online_waiting_snapshot)), "online host lobby disables start before another cook joins")
	main.call("_refresh_connection_buttons", online_waiting_snapshot)
	main.call("_refresh_controls", online_waiting_snapshot)
	await process_frame
	var back_to_setup := _control_from_property(main, "_back_to_online_setup_button")
	var main_menu_button := _control_from_property(main, "_main_menu_button")
	_require(back_to_setup != null and main_menu_button != null and back_to_setup.get_parent() == main_menu_button.get_parent() and back_to_setup.get_index() + 1 == main_menu_button.get_index(), "Back to Create/Join Table sits directly above Main Menu")
	_require(back_to_setup != null and back_to_setup.visible, "Back to Create/Join Table is visible in online lobby")
	var start_button := _current_start_button(main)
	_require(start_button != null and start_button.disabled and start_button.text == "Waiting for Cooks", "online host Start Cooking button is disabled and relabeled before another cook joins")
	var online_ready_snapshot := _online_lobby_snapshot(true)
	_require(str(main.call("_host_lobby_start_label", online_ready_snapshot)) == "Start Cooking", "online host lobby start label restores after another cook joins")
	_require(bool(main.call("_host_lobby_start_enabled", online_ready_snapshot)), "online host lobby enables start after another cook joins")
	var idle_overlay := _control_from_property(main, "_idle_prompt_dialog")
	_require(idle_overlay != null and idle_overlay.name == "IdlePromptOverlay", "idle cooking prompt is a themed in-tree overlay")
	var idle_prompt_snapshot := online_ready_snapshot.duplicate(true)
	idle_prompt_snapshot["idlePrompt"] = {
		"id": "idle_test",
		"message": "Are you still cooking?"
	}
	main.call("_handle_idle_prompt_snapshot", idle_prompt_snapshot)
	await process_frame
	var idle_panel := idle_overlay.find_child("IdlePromptPanel", true, false) as Control
	var idle_message := idle_overlay.find_child("IdlePromptMessage", true, false) as Label
	var idle_yes := idle_overlay.find_child("IdlePromptYesButton", true, false) as Button
	var idle_no := idle_overlay.find_child("IdlePromptNoButton", true, false) as Button
	_require(idle_overlay.visible and idle_panel != null, "idle cooking prompt opens as a centered themed panel")
	_require(idle_message != null and idle_message.text == "Are you still cooking?", "idle cooking prompt shows the server message")
	_require(idle_yes != null and idle_yes.text == "Yes" and idle_yes.get_global_rect().size.x >= 120.0, "idle cooking prompt has a clear Yes button")
	_require(idle_no != null and idle_no.text == "No" and idle_no.get_global_rect().size.x >= 120.0, "idle cooking prompt has a clear No button")
	idle_overlay.hide()

	var recipes_client := root.get_node("/root/RecipesClient")
	recipes_client.latest_snapshot = online_waiting_snapshot.duplicate(true)
	main.call("_remember_lobby_seat_name_edit", "p1", "FastHost")
	var name_publish_timer := main.get("_lobby_name_publish_timer") as Timer
	var pending_fast_names: Dictionary = main.get("_lobby_pending_seat_names")
	_require(pending_fast_names.has("p1") and name_publish_timer != null and not name_publish_timer.is_stopped(), "typing a lobby name schedules a quick online publish")
	main.call("_clear_lobby_edit_state")
	main.call("_remember_lobby_seat_name_edit", "p1", "")
	var pending_names: Dictionary = main.get("_lobby_pending_seat_names")
	_require(not pending_names.has("p1"), "blank Android lobby name edits are not retained as pending renames")
	var blank_name_input := LineEdit.new()
	blank_name_input.text = ""
	main.call("_rename_lobby_seat", "p1", blank_name_input)
	_require(blank_name_input.text == "SmallHost", "blank submitted lobby names fall back to the current server name")

	var missing_prepare_append := {"transactionHistory": [{"action": "Prepare", "participantId": "p1"}]}
	var complete_prepare_patch := {"ownFoodParts": [{"id": "dish_1_part_1", "dishId": "dish_1"}]}
	_require(bool(recipes_client.call("debug_delta_missing_viewer_prepare_food_parts", _prepare_delta_snapshot_fixture(), {}, missing_prepare_append)), "online client requests a fresh snapshot when a viewer prepare delta omits ownFoodParts")
	_require(not bool(recipes_client.call("debug_delta_missing_viewer_prepare_food_parts", _prepare_delta_snapshot_fixture(), complete_prepare_patch, missing_prepare_append)), "online client accepts prepare deltas that include prepared food parts")
	_require(not bool(recipes_client.call("debug_delta_missing_viewer_prepare_food_parts", _prepare_delta_snapshot_fixture(), {}, {"transactionHistory": [{"action": "Prepare", "participantId": "p2"}]})), "online client does not freshen for other cooks' prepare deltas")
	_require(str(recipes_client.call("debug_socket_watchdog_action", _online_playing_snapshot(), true, 21000, false, 0)) == "fresh_snapshot", "online active table watchdog requests a full snapshot after a quiet socket")
	_require(str(recipes_client.call("debug_socket_watchdog_action", _online_playing_snapshot(), true, 21000, true, 9000)) == "reconnect", "online active table watchdog reconnects when a full snapshot request gets no response")
	_require(str(recipes_client.call("debug_socket_watchdog_action", online_waiting_snapshot, true, 21000, false, 0)) == "none", "online lobby watchdog does not poll active-game snapshots")
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
	var history_controls := VBoxContainer.new()
	root.add_child(history_controls)
	main.call("_add_transaction_history_controls", _long_transaction_fixture(100), history_controls, short_popup_rows)
	await process_frame
	var history_scroller := history_controls.find_child("TransactionHistoryScroller", true, false) as ScrollContainer
	_require(history_scroller != null, "long history popup uses a transaction scroller")
	_require(history_scroller != null and history_scroller.get_combined_minimum_size().y <= float((30 + 6) * short_popup_rows) + 1.0, "long history scroller keeps a fixed visible height instead of forcing popup overflow")
	history_controls.queue_free()
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
	root.size = Vector2i(1600, 900)
	await process_frame
	main.call("_fit_table_visual_to_window")
	await process_frame
	_require(str(visual.call("debug_layout_mode")) == "landscape", "main scene switches to horizontal table layout immediately on a wide window")
	var landscape_viewport_width := root.get_viewport().get_visible_rect().size.x
	var landscape_visual_rect := visual.get_global_rect()
	_require(landscape_visual_rect.position.x >= 8.0 and landscape_visual_rect.end.x <= landscape_viewport_width - 8.0, "landscape table keeps an outer horizontal gutter; visual=%s viewport_width=%s" % [landscape_visual_rect, landscape_viewport_width])
	root.size = original_window_size
	await process_frame
	main.call("_fit_table_visual_to_window")
	await process_frame

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


func _current_start_button(main: Node) -> Button:
	var phase_controls := _control_from_property(main, "_phase_controls")
	if phase_controls == null:
		return null
	var current: Button = null
	for child in phase_controls.get_children():
		if child is Button and child.name == "StartCookingButton":
			current = child
	return current


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


func _online_lobby_snapshot(joined_cook: bool) -> Dictionary:
	var ingredients := ["herbs", "rice", "eggs", "vegetables", "flour", "spices", "cheese", "beans"]
	var names := ["SmallHost", "BenB", "Nia_b", "Luc_b", "Ava_b", "Leo_b", "Mia_b", "Yan_b"]
	var participants: Array = []
	for index in range(8):
		var is_host := index == 0
		var is_joined := joined_cook and index == 1
		participants.append({
			"id": "p%s" % (index + 1),
			"name": names[index],
			"role": "active",
			"kind": "human" if is_host or is_joined else "bot",
			"isHost": is_host,
			"connected": is_host or is_joined,
			"ingredientId": ingredients[index],
			"dishCount": 0,
			"depositedInitial": false,
			"openingOfferingsCount": 0
		})
	return {
		"tableCode": "JOINME",
		"phase": "lobby",
		"turn": 0,
		"version": 1,
		"offline": false,
		"viewerParticipantId": "p1",
		"connectionParticipantId": "p1",
		"viewerCanUseHostControls": true,
		"hostParticipantId": "p1",
		"controlledParticipantIds": [],
		"participants": participants,
		"ingredients": [
			{"id": "cheese", "name": "Cheese"},
			{"id": "flour", "name": "Flour"},
			{"id": "herbs", "name": "Herbs"},
			{"id": "vegetables", "name": "Vegetables"},
			{"id": "rice", "name": "Rice"},
			{"id": "beans", "name": "Beans"},
			{"id": "spices", "name": "Spices"},
			{"id": "eggs", "name": "Eggs"}
		],
		"platter": [],
		"ownHand": [],
		"ownFoodParts": [],
		"platterFoodParts": [],
		"offers": [],
		"transactionHistory": []
	}


func _prepare_delta_snapshot_fixture() -> Dictionary:
	return {
		"viewerParticipantId": "p1",
		"ownFoodParts": []
	}


func _online_playing_snapshot() -> Dictionary:
	var snapshot := _online_lobby_snapshot(true)
	snapshot["phase"] = "playing"
	snapshot["version"] = 12
	snapshot["currentTurnParticipantId"] = "p2"
	snapshot["viewerParticipantId"] = "p1"
	snapshot["connectionParticipantId"] = "p1"
	return snapshot


func _long_transaction_fixture(count: int) -> Dictionary:
	var rows: Array = []
	for index in range(count):
		rows.append({
			"turn": index + 1,
			"name": "Cook_%s" % index,
			"action": "Redeem" if index % 2 == 0 else "Swap",
			"counterparty": "Amina1234567" if index % 3 == 0 else "Platter",
			"itemOut": "Cheese",
			"itemBack": "Real Cheese"
		})
	return {
		"transactionHistory": rows,
		"transactionHistoryComplete": false,
		"transactionHistoryTotal": count + 187
	}


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
