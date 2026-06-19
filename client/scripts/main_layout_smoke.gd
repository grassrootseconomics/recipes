extends SceneTree


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame

	var recipes_client := root.get_node("/root/RecipesClient")
	recipes_client.start_offline_table("", "")
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

	holder.size = Vector2(480, holder.size.y)
	main.call("_fit_table_visual_to_window")
	var narrow_visual_rect := visual.get_global_rect()
	_require(narrow_visual_rect.size.x <= 481.0, "table visual scales down for a 480px desktop debug width")

	main.call("_return_to_main_menu")
	await process_frame
	_require(post_controls != null and not post_controls.visible, "post-table End Game controls hide on the title screen")
	var table_menu_button := visual.find_child("TableMenuButton", true, false) as Control
	_require(table_menu_button != null and not table_menu_button.visible, "table hamburger menu hides on the title screen")
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
