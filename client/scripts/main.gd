extends Control

const TRANSACTION_VISIBLE_ROWS := 20
const TRANSACTION_ROW_HEIGHT := 30
const TRANSACTION_ROW_GAP := 6

var _status_label: Label
var _server_input: LineEdit
var _name_input: LineEdit
var _seed_input: LineEdit
var _code_input: LineEdit
var _timer_input: LineEdit
var _target_dish_count_input: LineEdit
var _stock_input: LineEdit
var _create_table_button: Button
var _join_table_button: Button
var _leave_table_button: Button
var _summary_label: Label
var _participants_label: Label
var _participants_option: OptionButton
var _participant_detail_label: Label
var _hand_label: Label
var _platter_label: Label
var _participants_area: VBoxContainer
var _table_section: VBoxContainer
var _hand_section: VBoxContainer
var _recipe_section: VBoxContainer
var _platter_section: VBoxContainer
var _offer_section: VBoxContainer
var _dish_section: VBoxContainer
var _transaction_section: VBoxContainer
var _phase_controls: VBoxContainer
var _hand_controls: VBoxContainer
var _recipe_controls: VBoxContainer
var _platter_controls: VBoxContainer
var _offer_controls: VBoxContainer
var _dish_controls: VBoxContainer
var _transaction_controls: VBoxContainer
var _confirm_bot_dialog: ConfirmationDialog
var _confirm_leave_dialog: ConfirmationDialog
var _confirm_close_dialog: ConfirmationDialog
var _csv_file_dialog: FileDialog
var _csv_export_status_label: Label
var _select_popup: PopupPanel
var _select_popup_scroller: ScrollContainer
var _select_popup_list: VBoxContainer
var _csv_http_request: HTTPRequest

var _selected_hand_voucher_id := ""
var _selected_platter_voucher_id := ""
var _selected_give_asset_key := ""
var _selected_take_asset_key := ""
var _selected_offer_target_id := ""
var _selected_offer_card_id := ""
var _selected_participant_id := ""
var _pending_bot_participant_id := ""
var _pending_csv := ""
var _pending_csv_filename := ""
var _csv_download_filename := ""
var _last_csv_export_status := ""
var _left_table_codes := {}
var _active_select_key := ""


func _ready() -> void:
	_csv_http_request = HTTPRequest.new()
	add_child(_csv_http_request)
	_csv_http_request.request_completed.connect(_on_csv_download_completed)
	_build_ui()
	RecipesClient.snapshot_received.connect(_on_snapshot_received)
	RecipesClient.error_received.connect(_on_error_received)
	RecipesClient.connection_changed.connect(_on_connection_changed)


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var title := Label.new()
	title.text = "Recipes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	_status_label = _wrapped_label("Connect to a local Recipes server.")
	root.add_child(_status_label)

	_server_input = _labeled_line_edit(root, "Server URL", "http://127.0.0.1:3000", "http://127.0.0.1:3000")
	_name_input = _labeled_line_edit(root, "Your name", "Leave blank for an auto name", "")
	_seed_input = _labeled_line_edit(root, "Table seed", "demo", "demo")
	_code_input = _labeled_line_edit(root, "Invite code", "Required to join an existing table", "")

	var connect_row := _button_row()
	root.add_child(connect_row)
	_create_table_button = _button("Create Table", _on_create_pressed)
	_join_table_button = _button("Join", _on_join_pressed)
	_leave_table_button = _button("Leave Table", _confirm_leave_table)
	connect_row.add_child(_create_table_button)
	connect_row.add_child(_join_table_button)
	connect_row.add_child(_leave_table_button)
	_refresh_connection_buttons({})

	_summary_label = _wrapped_label("")
	root.add_child(_summary_label)
	_summary_label.visible = false
	_participants_area = VBoxContainer.new()
	_participants_area.add_theme_constant_override("separation", 6)
	_participants_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_participants_area.visible = false
	root.add_child(_participants_area)
	_participants_label = _wrapped_label("")
	_participants_area.add_child(_participants_label)
	_participants_option = _option_button()
	_participants_option.item_selected.connect(_on_participant_selected)
	_participants_area.add_child(_participants_option)
	_participant_detail_label = _wrapped_label("")
	_participants_area.add_child(_participant_detail_label)

	_table_section = _section(root, "Table")
	_phase_controls = _section_controls(_table_section)
	_hand_section = _section(root, "Hand")
	_hand_controls = _section_controls(_hand_section)
	_recipe_section = _section(root, "Recipe")
	_recipe_controls = _section_controls(_recipe_section)
	_platter_section = _section(root, "Central Platter")
	_platter_controls = _section_controls(_platter_section)
	_offer_section = _section(root, "Offers")
	_offer_controls = _section_controls(_offer_section)
	_dish_section = _section(root, "Dishes")
	_dish_controls = _section_controls(_dish_section)
	_transaction_section = _section(root, "Successful Transactions")
	_transaction_controls = _section_controls(_transaction_section)

	_platter_label = _wrapped_label("")
	root.add_child(_platter_label)
	_platter_label.visible = false
	_hand_label = _wrapped_label("")
	root.add_child(_hand_label)
	_hand_label.visible = false

	_confirm_bot_dialog = ConfirmationDialog.new()
	_confirm_bot_dialog.title = "Switch to bot?"
	_confirm_bot_dialog.dialog_text = "Switch this player seat to a mixed bot?"
	_confirm_bot_dialog.confirmed.connect(_on_confirm_switch_to_bot)
	add_child(_confirm_bot_dialog)
	_confirm_bot_dialog.get_ok_button().text = "Yes"
	_confirm_bot_dialog.get_cancel_button().text = "No"

	_confirm_leave_dialog = ConfirmationDialog.new()
	_confirm_leave_dialog.title = "Leave table?"
	_confirm_leave_dialog.dialog_text = "Are you sure you want to leave?\n\nYou will not be able to rejoin as a player, but you can rejoin as a witness."
	_confirm_leave_dialog.confirmed.connect(_on_confirm_leave_table)
	add_child(_confirm_leave_dialog)
	_confirm_leave_dialog.get_ok_button().text = "Yes"
	_confirm_leave_dialog.get_cancel_button().text = "No"

	_confirm_close_dialog = ConfirmationDialog.new()
	_confirm_close_dialog.title = "Close table?"
	_confirm_close_dialog.dialog_text = "Are you sure you want to end this table?"
	_confirm_close_dialog.confirmed.connect(_on_confirm_close_table)
	add_child(_confirm_close_dialog)
	_confirm_close_dialog.get_ok_button().text = "Yes"
	_confirm_close_dialog.get_cancel_button().text = "No"

	_csv_file_dialog = FileDialog.new()
	_csv_file_dialog.title = "Save Transaction CSV"
	_csv_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_csv_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_csv_file_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	_csv_file_dialog.file_selected.connect(_on_csv_file_selected)
	_csv_file_dialog.canceled.connect(_on_csv_save_canceled)
	add_child(_csv_file_dialog)

	_select_popup = PopupPanel.new()
	_select_popup.add_theme_stylebox_override("panel", _select_popup_style())
	_select_popup_scroller = ScrollContainer.new()
	_select_popup_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_select_popup_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_select_popup_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_select_popup_list = VBoxContainer.new()
	_select_popup_list.add_theme_constant_override("separation", 6)
	_select_popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_select_popup_scroller.add_child(_select_popup_list)
	_select_popup.add_child(_select_popup_scroller)
	_select_popup.popup_hide.connect(func() -> void:
		_active_select_key = ""
	)
	add_child(_select_popup)

	_set_lobby_ui_visible(false)
	_set_gameplay_ui_visible(false)


func _section(root: VBoxContainer, title_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(section)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	section.add_child(title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(box)
	return section


func _section_controls(section: VBoxContainer) -> VBoxContainer:
	return section.get_child(1) as VBoxContainer


func _button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _labeled_line_edit(root: VBoxContainer, label_text: String, placeholder: String, value: String) -> LineEdit:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(field)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	field.add_child(label)

	var input := _line_edit(placeholder, value)
	field.add_child(input)
	return input


func _line_edit(placeholder: String, value: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = value
	input.custom_minimum_size = Vector2(0, 44)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_stylebox_override("focus", _control_focus_style())
	return input


func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(112, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("focus", _control_focus_style())
	button.pressed.connect(callback)
	return button


func _control_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.88, 0.88, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style


func _select_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.13, 1.0)
	style.border_color = Color(0.78, 0.78, 0.78, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _option_button() -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 44)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	option.add_theme_stylebox_override("focus", _control_focus_style())
	return option


func _select_button(label: String, select_key: String) -> Button:
	var button := Button.new()
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(112, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("focus", _control_focus_style())
	button.pressed.connect(func() -> void:
		_open_select_popup(select_key, button)
	)
	return button


func _wrapped_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _colored_label(text: String, background: Color, foreground := Color(1, 1, 1)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := _wrapped_label(text)
	label.add_theme_color_override("font_color", foreground)
	panel.add_child(label)
	return panel


func _transaction_header_row() -> HBoxContainer:
	var row := _transaction_row_container()
	row.add_child(_transaction_cell("Name", 80, true))
	row.add_child(_transaction_cell("Action", 76, true))
	row.add_child(_transaction_cell("Counterparty", 88, true))
	row.add_child(_transaction_cell("Item out", 88, true))
	row.add_child(_transaction_cell("Item back", 88, true))
	return row


func _transaction_row(transaction: Dictionary) -> HBoxContainer:
	var row := _transaction_row_container()
	row.add_child(_transaction_cell(str(transaction.get("name", "?")), 80))
	row.add_child(_action_badge(str(transaction.get("action", "?"))))
	row.add_child(_transaction_cell(str(transaction.get("counterparty", "?")), 88))
	row.add_child(_transaction_cell(str(transaction.get("itemOut", "-")), 88))
	row.add_child(_transaction_cell(str(transaction.get("itemBack", "-")), 88))
	return row


func _transaction_row_container() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _transaction_cell(text: String, min_width: int, bold := false) -> Label:
	var label := _wrapped_label(text)
	label.custom_minimum_size = Vector2(min_width, 30)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if bold:
		label.add_theme_font_size_override("font_size", 15)
	return label


func _action_badge(action: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(76, 30)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = _action_color(action)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = action
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", _action_text_color(action))
	panel.add_child(label)
	return panel


func _action_color(action: String) -> Color:
	match action:
		"Redeem":
			return Color(0.45, 0.24, 0.74)
		"Swap":
			return Color(0.12, 0.55, 0.28)
		"Settlement Swap":
			return Color(0.14, 0.58, 0.42)
		"Exchange":
			return Color(0.95, 0.78, 0.22)
		"Deposit":
			return Color(0.18, 0.40, 0.82)
		"Prepare":
			return Color(0.63, 0.34, 0.12)
		"Eat":
			return Color(0.70, 0.26, 0.42)
		_:
			return Color(0.32, 0.32, 0.32)


func _action_text_color(action: String) -> Color:
	if action == "Exchange":
		return Color(0.08, 0.08, 0.08)
	return Color(1, 1, 1)


func _on_create_pressed() -> void:
	RecipesClient.server_url = _server_input.text.strip_edges()
	if _current_viewer_is_host():
		RecipesClient.send_intent({"type": "reset_table"})
		return
	RecipesClient.create_table(_name_input.text.strip_edges(), _seed_input.text.strip_edges())


func _on_join_pressed() -> void:
	RecipesClient.server_url = _server_input.text.strip_edges()
	if _current_viewer_is_host():
		_confirm_close_table()
		return
	var code := _code_input.text.strip_edges().to_upper()
	if RecipesClient.has_table_session(code):
		RecipesClient.connect_socket()
		return
	RecipesClient.join_table(code, _name_input.text.strip_edges(), bool(_left_table_codes.get(code, false)))


func _confirm_leave_table() -> void:
	if RecipesClient.table_code == "":
		return
	if not RecipesClient.is_socket_connected():
		RecipesClient.connect_socket()
		return
	_confirm_leave_dialog.popup_centered()


func _on_confirm_leave_table() -> void:
	var code := RecipesClient.table_code
	if code == "":
		return
	_left_table_codes[code] = true
	RecipesClient.leave_table()
	_code_input.text = code
	_status_label.text = "Left table %s. You can rejoin it as a witness." % code
	_refresh_connection_buttons({})


func _confirm_close_table() -> void:
	if RecipesClient.table_code == "":
		return
	_confirm_close_dialog.popup_centered()


func _on_confirm_close_table() -> void:
	RecipesClient.send_intent({"type": "close_table"})


func _download_transactions_csv() -> void:
	var snapshot := RecipesClient.latest_snapshot
	var transactions: Array = snapshot.get("transactionHistory", [])
	if transactions.is_empty():
		_status_label.text = "No transaction history to download."
		return
	var table_code := str(snapshot.get("tableCode", "table")).to_lower()
	var filename := "recipes-transactions-%s.csv" % table_code
	if RecipesClient.table_code != "" and RecipesClient.seat_token != "":
		var endpoint := "%s/tables/%s/transactions.csv?seatToken=%s" % [
			RecipesClient.server_url,
			RecipesClient.table_code.uri_encode(),
			RecipesClient.seat_token.uri_encode()
		]
		_csv_download_filename = filename
		var err := _csv_http_request.request(endpoint)
		if err == OK:
			_set_csv_export_status("Requesting full transaction CSV...")
			return
		_set_csv_export_status("Could not request full CSV, using visible history: %s" % err)
	var csv := _transactions_csv(transactions)
	if _download_csv_in_browser(filename, csv):
		_set_csv_export_status("Transaction CSV save/download started.")
		return
	_pending_csv = csv
	_pending_csv_filename = filename
	_open_csv_save_dialog(filename)


func _on_csv_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _csv_download_filename == "":
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_csv_export_status("Full CSV download failed. Using visible transaction history.")
		var transactions: Array = RecipesClient.latest_snapshot.get("transactionHistory", [])
		_pending_csv = _transactions_csv(transactions)
		_pending_csv_filename = _csv_download_filename
		_open_csv_save_dialog(_csv_download_filename)
		_csv_download_filename = ""
		return
	var csv := body.get_string_from_utf8()
	var filename := _csv_download_filename
	_csv_download_filename = ""
	if _download_csv_in_browser(filename, csv):
		_set_csv_export_status("Transaction CSV save/download started.")
		return
	_pending_csv = csv
	_pending_csv_filename = filename
	_open_csv_save_dialog(filename)


func _open_csv_save_dialog(filename: String) -> void:
	if _csv_file_dialog == null:
		_save_csv_to_user_path(filename, _pending_csv)
		return
	_csv_file_dialog.current_file = filename
	_csv_file_dialog.current_path = _default_csv_save_path(filename)
	_csv_file_dialog.popup_centered_ratio(0.85)
	if not _csv_file_dialog.visible:
		_save_csv_to_user_path(filename, _pending_csv)
		return
	_set_csv_export_status("Choose where to save the transaction CSV.")


func _default_csv_save_path(filename: String) -> String:
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads != "":
		return downloads.path_join(filename)
	return ProjectSettings.globalize_path("user://%s" % filename)


func _on_csv_file_selected(path: String) -> void:
	if _pending_csv == "":
		_set_csv_export_status("No transaction CSV is waiting to be saved.")
		return
	_save_csv_to_path(path, _pending_csv)


func _on_csv_save_canceled() -> void:
	if _pending_csv_filename != "":
		_set_csv_export_status("CSV save canceled.")
	_pending_csv = ""
	_pending_csv_filename = ""


func _save_csv_to_user_path(filename: String, csv: String) -> void:
	_save_csv_to_path("user://%s" % filename, csv)


func _save_csv_to_path(path: String, csv: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		if not path.begins_with("user://") and _pending_csv_filename != "":
			var fallback_path := "user://%s" % _pending_csv_filename
			var fallback_file := FileAccess.open(fallback_path, FileAccess.WRITE)
			if fallback_file != null:
				fallback_file.store_string(csv)
				fallback_file.close()
				_pending_csv = ""
				_pending_csv_filename = ""
				_set_csv_export_status("Could not write to %s, so CSV was saved to %s." % [
					path,
					ProjectSettings.globalize_path(fallback_path)
				])
				return
		_set_csv_export_status("Could not save CSV: %s" % FileAccess.get_open_error())
		return
	file.store_string(csv)
	file.close()
	_pending_csv = ""
	_pending_csv_filename = ""
	var visible_path := path
	if path.begins_with("user://"):
		visible_path = ProjectSettings.globalize_path(path)
	_set_csv_export_status("Transaction CSV saved to %s" % visible_path)


func _download_csv_in_browser(filename: String, csv: String) -> bool:
	if OS.get_name() != "Web":
		return false
	var script := "\n".join([
		"const filename = %s;" % JSON.stringify(filename),
		"const csv = %s;" % JSON.stringify(csv),
		"const saveCsv = async () => {",
		"  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });",
		"  if (window.showSaveFilePicker) {",
		"    try {",
		"      const handle = await window.showSaveFilePicker({",
		"        suggestedName: filename,",
		"        types: [{ description: 'CSV files', accept: { 'text/csv': ['.csv'] } }]",
		"      });",
		"      const writable = await handle.createWritable();",
		"      await writable.write(blob);",
		"      await writable.close();",
		"      return;",
		"    } catch (error) {",
		"      if (error && error.name === 'AbortError') return;",
		"    }",
		"  }",
		"  const url = URL.createObjectURL(blob);",
		"  const link = document.createElement('a');",
		"  link.href = url;",
		"  link.download = filename;",
		"  document.body.appendChild(link);",
		"  link.click();",
		"  link.remove();",
		"  URL.revokeObjectURL(url);",
		"};",
		"void saveCsv();"
	])
	JavaScriptBridge.eval(script, true)
	return true


func _set_csv_export_status(message: String) -> void:
	_last_csv_export_status = message
	_status_label.text = message
	if is_instance_valid(_csv_export_status_label):
		_csv_export_status_label.text = message
		_csv_export_status_label.visible = message != ""


func _transactions_csv(transactions: Array) -> String:
	var lines: Array[String] = []
	lines.append(",".join(["Name", "Action", "Counterparty", "Item out", "Item back"]))
	for raw_transaction in transactions:
		var transaction: Dictionary = raw_transaction
		lines.append(",".join([
			_csv_field(transaction.get("name", "")),
			_csv_field(transaction.get("action", "")),
			_csv_field(transaction.get("counterparty", "")),
			_csv_field(transaction.get("itemOut", "")),
			_csv_field(transaction.get("itemBack", ""))
		]))
	return "\n".join(lines) + "\n"


func _csv_field(value: Variant) -> String:
	var text := str(value)
	var escaped := text.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\n") or escaped.contains("\""):
		return "\"%s\"" % escaped
	return escaped


func _on_snapshot_received(snapshot: Dictionary) -> void:
	_render_snapshot(snapshot)


func _render_snapshot(snapshot: Dictionary) -> void:
	_code_input.text = str(snapshot.get("tableCode", RecipesClient.table_code))
	_status_label.text = "Connected as %s" % RecipesClient.participant_id
	var table_exists := _table_exists(snapshot)
	var game_started := _game_started(snapshot)
	_refresh_connection_buttons(snapshot)
	_set_lobby_ui_visible(table_exists)
	_set_gameplay_ui_visible(game_started)
	_summary_label.text = "Table %s\n%s%s. %s active seats. Turn %s.\nGoal: %s dishes each\nStock: %s units each\nTimer: %s\nWinners: %s" % [
		snapshot.get("tableCode", ""),
		_phase_label(str(snapshot.get("phase", "unknown"))),
		" - paused" if bool(snapshot.get("paused", false)) else "",
		_active_count(snapshot),
		int(snapshot.get("turn", 0)),
		int(snapshot.get("targetDishCount", 4)),
		int(snapshot.get("stockPerIngredient", 30)),
		_timer_label(snapshot),
		_winners_label(snapshot.get("winners", []))
	]
	_refresh_participants(snapshot)
	_platter_label.text = "%s:\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]
	_hand_label.text = "Your inventory:\n%s" % _format_inventory_assets(snapshot)
	_refresh_controls(snapshot)
	_refresh_active_select_popup(snapshot)


func _on_error_received(error: Dictionary) -> void:
	var description := str(error.get("description", JSON.stringify(error)))
	_status_label.text = "Error: %s" % description
	_summary_label.text = "Last error: %s" % description


func _on_connection_changed(status: String) -> void:
	if status == "open":
		_status_label.text = "Connection open."
		_refresh_connection_buttons(RecipesClient.latest_snapshot)
		_set_lobby_ui_visible(_table_exists(RecipesClient.latest_snapshot))
		_set_gameplay_ui_visible(_game_started(RecipesClient.latest_snapshot))
	elif status == "closed":
		var snapshot := RecipesClient.latest_snapshot
		if _table_exists(snapshot):
			_status_label.text = "Connection closed. Showing last table state."
			_refresh_connection_buttons(snapshot)
			_set_lobby_ui_visible(true)
			_set_gameplay_ui_visible(_game_started(snapshot))
		else:
			_status_label.text = "Connection: %s" % status
			_set_lobby_ui_visible(false)
			_set_gameplay_ui_visible(false)
			_refresh_connection_buttons({})
	elif status == "reconnecting":
		var close_detail := RecipesClient.last_close_description
		var detail := "" if close_detail == "" else " (%s)" % close_detail
		_status_label.text = "Connection lost%s. Reconnecting, attempt %s..." % [detail, RecipesClient.reconnect_attempt()]
		var snapshot := RecipesClient.latest_snapshot
		if _table_exists(snapshot):
			_refresh_connection_buttons(snapshot)
			_set_lobby_ui_visible(true)
			_set_gameplay_ui_visible(_game_started(snapshot))
	else:
		_status_label.text = "Connection: %s" % status


func _table_exists(snapshot: Dictionary) -> bool:
	return str(snapshot.get("tableCode", "")) != ""


func _game_started(snapshot: Dictionary) -> bool:
	var phase := str(snapshot.get("phase", "lobby"))
	return phase != "lobby" and phase != ""


func _current_viewer_is_host() -> bool:
	var snapshot := RecipesClient.latest_snapshot
	if not _table_exists(snapshot):
		return false
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	return bool(viewer.get("isHost", false))


func _refresh_connection_buttons(snapshot: Dictionary) -> void:
	var has_table := _table_exists(snapshot)
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	var is_host := has_table and bool(viewer.get("isHost", false))

	_create_table_button.visible = not has_table or is_host
	_join_table_button.visible = not has_table or is_host
	_leave_table_button.visible = has_table and not is_host

	if is_host:
		_create_table_button.text = "Start New Table"
		_join_table_button.text = "Close Table"
	elif has_table and not RecipesClient.is_socket_connected():
		_create_table_button.text = "Create Table"
		_join_table_button.text = "Join"
		_leave_table_button.text = "Reconnect"
	else:
		_create_table_button.text = "Create Table"
		_join_table_button.text = "Join"
		_leave_table_button.text = "Leave Table"

	_create_table_button.disabled = false
	_join_table_button.disabled = false
	_leave_table_button.disabled = false


func _set_lobby_ui_visible(visible: bool) -> void:
	_summary_label.visible = visible
	_participants_area.visible = visible
	_table_section.visible = visible


func _set_gameplay_ui_visible(visible: bool) -> void:
	_hand_section.visible = visible
	_recipe_section.visible = visible
	_platter_section.visible = visible
	_offer_section.visible = visible
	_dish_section.visible = visible
	_transaction_section.visible = visible
	_platter_label.visible = false
	_hand_label.visible = false


func _on_participant_selected(index: int) -> void:
	_selected_participant_id = str(_participants_option.get_item_metadata(index))
	_refresh_participant_detail(RecipesClient.latest_snapshot)
	_refresh_controls(RecipesClient.latest_snapshot)


func _refresh_participants(snapshot: Dictionary) -> void:
	var participants: Array = snapshot.get("participants", [])
	var active_count := _active_count(snapshot)
	_participants_label.text = "Participants: %s total, %s active" % [participants.size(), active_count]
	_participants_option.clear()

	if participants.is_empty():
		_selected_participant_id = ""
		_participants_option.add_item("No participants")
		_participants_option.set_item_metadata(0, "")
		_participants_option.disabled = true
		_participant_detail_label.text = ""
		return

	_participants_option.disabled = false
	var viewer_id := str(snapshot.get("viewerParticipantId", ""))
	if _selected_participant_id == "" or _participant_by_id(snapshot, _selected_participant_id).is_empty():
		_selected_participant_id = viewer_id
	if _selected_participant_id == "" or _participant_by_id(snapshot, _selected_participant_id).is_empty():
		var first_participant: Dictionary = participants[0]
		_selected_participant_id = str(first_participant.get("id", ""))

	for raw_participant in participants:
		var participant: Dictionary = raw_participant
		var item_index := _participants_option.item_count
		var participant_id := str(participant.get("id", ""))
		_participants_option.add_item(_participant_dropdown_label(snapshot, participant))
		_participants_option.set_item_metadata(item_index, participant_id)
		if participant_id == _selected_participant_id:
			_participants_option.select(item_index)

	_refresh_participant_detail(snapshot)


func _refresh_participant_detail(snapshot: Dictionary) -> void:
	var participant := _participant_by_id(snapshot, _selected_participant_id)
	if participant.is_empty():
		_participant_detail_label.text = ""
		return
	_participant_detail_label.text = _participant_detail_text(snapshot, participant)


func _refresh_controls(snapshot: Dictionary) -> void:
	_clear(_phase_controls)
	_clear(_hand_controls)
	_clear(_recipe_controls)
	_clear(_platter_controls)
	_clear(_offer_controls)
	_clear(_dish_controls)
	_clear(_transaction_controls)

	var phase := str(snapshot.get("phase", "lobby"))
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	if bool(viewer.get("isHost", false)):
		_add_host_admin_controls(snapshot)
	if _game_started(snapshot):
		_phase_controls.add_child(_wrapped_label(_stock_accounting_label(snapshot)))
		_add_dish_summary_controls(snapshot)
		_add_transaction_history_controls(snapshot)
	if bool(snapshot.get("paused", false)):
		_phase_controls.add_child(_wrapped_label("Game paused by host. Waiting for resume."))
		return
	if not _viewer_can_act(snapshot) and not _viewer_is_witness(snapshot):
		_phase_controls.add_child(_wrapped_label("This seat is now controlled by a bot."))
		return
	if phase == "lobby":
		_add_lobby_controls(snapshot)
	elif _viewer_is_witness(snapshot):
		_add_witness_controls(snapshot)
	elif phase == "deposit":
		_add_deposit_controls(snapshot)
	elif phase == "playing":
		_add_playing_controls(snapshot)
	elif phase == "settlement":
		_add_settlement_controls(snapshot)
	elif phase == "eating" or phase == "complete":
		_add_eating_controls(snapshot)


func _add_lobby_controls(snapshot: Dictionary) -> void:
	var active_count := _active_count(snapshot)
	_phase_controls.add_child(_wrapped_label("Active seats: %s. Timer: %s." % [active_count, _timer_label(snapshot)]))

	var viewer_id := str(snapshot.get("viewerParticipantId", ""))
	var viewer := _participant_by_id(snapshot, viewer_id)
	if not bool(viewer.get("isHost", false)):
		_phase_controls.add_child(_wrapped_label("Waiting for the host to start the table."))
		return
	var next_role := "witness"
	if str(viewer.get("role", "active")) == "witness":
		next_role = "active"
	_phase_controls.add_child(_button("Toggle My Role To %s" % next_role.capitalize(), func() -> void:
		RecipesClient.send_intent({"type": "set_role", "participantId": viewer_id, "role": next_role})
	))

	var bot_row := _button_row()
	_phase_controls.add_child(bot_row)
	bot_row.add_child(_button("Add Pool Bot", func() -> void:
		RecipesClient.send_intent({"type": "add_bot", "botType": "pool_only"})
	))
	bot_row.add_child(_button("Add Barter Bot", func() -> void:
		RecipesClient.send_intent({"type": "add_bot", "botType": "barter_only"})
	))
	bot_row.add_child(_button("Add Mixed Bot", func() -> void:
		RecipesClient.send_intent({"type": "add_bot", "botType": "mixed"})
	))

	var timer_row := _button_row()
	_phase_controls.add_child(timer_row)
	_timer_input = _line_edit("No limit", "" if not snapshot.has("timer") else str(int(snapshot.get("timer", {}).get("seconds", 0))))
	timer_row.add_child(_timer_input)
	timer_row.add_child(_button("Set Timer", _set_timer))
	timer_row.add_child(_button("No Limit", func() -> void:
		RecipesClient.send_intent({"type": "set_timer", "seconds": null})
	))

	var target_row := _button_row()
	_phase_controls.add_child(target_row)
	_target_dish_count_input = _line_edit("Dishes to finish", str(int(snapshot.get("targetDishCount", 4))))
	target_row.add_child(_target_dish_count_input)
	target_row.add_child(_button("Set Dish Goal", _set_target_dish_count))

	var stock_row := _button_row()
	_phase_controls.add_child(stock_row)
	_stock_input = _line_edit("Stock units", str(int(snapshot.get("stockPerIngredient", 30))))
	stock_row.add_child(_stock_input)
	stock_row.add_child(_button("Set Stock", _set_stock))

	var start_button := _button("Start Game", func() -> void:
		RecipesClient.send_intent({"type": "start"})
	)
	start_button.disabled = active_count < 7 or active_count > 20
	if active_count < 7:
		start_button.text = "Waiting for %s Players" % (7 - active_count)
	else:
		start_button.text = "Start Game"
	_phase_controls.add_child(start_button)


func _add_deposit_controls(snapshot: Dictionary) -> void:
	var hand: Array = snapshot.get("ownHand", [])
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	if str(viewer.get("role", "")) != "active":
		_hand_controls.add_child(_wrapped_label("Witnessing the table offering."))
		return
	if bool(viewer.get("depositedInitial", false)):
		_hand_controls.add_child(_wrapped_label("Offering given. Waiting for the table."))
		return
	if hand.is_empty():
		_hand_controls.add_child(_wrapped_label("No offering is available. Waiting for the table."))
		return

	var voucher: Dictionary = hand[0]
	_hand_controls.add_child(_wrapped_label("Give your offering to the table."))
	_hand_controls.add_child(_button("Give %s" % _ingredient_display(snapshot, str(voucher.get("ingredientId", ""))), func(v: Dictionary = voucher) -> void:
		RecipesClient.send_intent({"type": "deposit", "voucherId": v.get("id", "")})
	))


func _add_playing_controls(snapshot: Dictionary) -> void:
	_add_prepare_control(snapshot)
	_add_hand_place_controls(snapshot)
	_add_platter_swap_controls(snapshot)
	_add_offer_controls(snapshot)


func _add_settlement_controls(snapshot: Dictionary) -> void:
	_phase_controls.add_child(_wrapped_label("Settlement: clear the central platter before eating."))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_hand_controls.add_child(_wrapped_label("Your inventory\n%s" % _format_inventory_assets(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_add_platter_asset_swap_controls(snapshot)


func _add_host_admin_controls(snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", "lobby"))
	var paused := bool(snapshot.get("paused", false))
	if phase != "lobby" and phase != "complete":
		var game_row := _button_row()
		_phase_controls.add_child(game_row)
		game_row.add_child(_button("Resume Game" if paused else "Pause Game", func() -> void:
			RecipesClient.send_intent({"type": "set_pause", "paused": not bool(RecipesClient.latest_snapshot.get("paused", false))})
		))
		if not paused:
			game_row.add_child(_button("End Game", func() -> void:
				RecipesClient.send_intent({"type": "stop"})
			))

	var selected := _participant_by_id(snapshot, _selected_participant_id)
	if _can_switch_to_bot(snapshot, selected):
		_phase_controls.add_child(_button("Switch %s To Bot" % selected.get("name", "Player"), func(id := str(selected.get("id", "")), name := str(selected.get("name", "Player"))) -> void:
			_confirm_switch_to_bot(id, name)
		))


func _add_witness_controls(snapshot: Dictionary) -> void:
	var viewer_id := str(snapshot.get("viewerParticipantId", ""))
	var selected := _participant_by_id(snapshot, _selected_participant_id)
	if selected.is_empty() or str(selected.get("id", "")) == viewer_id or str(selected.get("role", "")) == "witness":
		_add_witness_overview(snapshot)
		return
	_add_witness_player_view(snapshot, selected)


func _add_witness_overview(snapshot: Dictionary) -> void:
	_phase_controls.add_child(_wrapped_label("Witness overview. Select an active participant to view their board without actions."))
	_hand_controls.add_child(_wrapped_label(_all_hands_label(snapshot)))
	_hand_controls.add_child(_wrapped_label(_all_card_locations_label(snapshot)))
	_hand_controls.add_child(_wrapped_label(_all_food_part_locations_label(snapshot)))
	_recipe_controls.add_child(_wrapped_label("Select an active participant to view their current recipe."))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_offer_controls.add_child(_wrapped_label(_open_offers_label(snapshot)))


func _add_witness_player_view(snapshot: Dictionary, participant: Dictionary) -> void:
	var participant_id := str(participant.get("id", ""))
	_phase_controls.add_child(_wrapped_label("Viewing %s as a read-only witness." % _participant_name(snapshot, participant_id)))
	_hand_controls.add_child(_wrapped_label("Current Inventory\n%s" % _format_participant_inventory(snapshot, participant_id)))
	_add_recipe_view(_recipe_controls, snapshot, _recipe_for_participant(snapshot, participant_id))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_offer_controls.add_child(_wrapped_label(_open_offers_label(snapshot, participant_id)))


func _add_prepare_control(snapshot: Dictionary) -> void:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	if recipe.is_empty():
		_recipe_controls.add_child(_wrapped_label("No recipe yet."))
		return
	_add_recipe_view(_recipe_controls, snapshot, recipe)
	_recipe_controls.add_child(_wrapped_label(_recipe_progress_label(recipe)))
	var prepare_button := _button("Prepare Dish", func() -> void:
		RecipesClient.send_intent({"type": "prepare"})
	)
	prepare_button.disabled = not _recipe_ready(recipe)
	_recipe_controls.add_child(prepare_button)


func _add_eating_controls(snapshot: Dictionary) -> void:
	_recipe_controls.add_child(_wrapped_label("Dish goal reached."))
	_hand_controls.add_child(_wrapped_label("Your inventory\n%s" % _format_inventory_assets(snapshot)))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_offer_controls.add_child(_wrapped_label("Offers are closed during eating."))
	if snapshot.get("phase", "") == "complete":
		_dish_controls.add_child(_wrapped_label("All food parts have been eaten."))
		return
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	if not bool(viewer.get("cleared", false)):
		_dish_controls.add_child(_wrapped_label("Clear your central platter account before eating."))
		_dish_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	for raw_dish in snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		var parts := int(dish.get("partsRemaining", dish.get("bitesRemaining", 0)))
		var unit := _unit_for_count(dish, parts)
		var label := "%s: %s %s left" % [dish.get("name", "Dish"), parts, unit]
		if parts > 0:
			var can_bite := _viewer_can_bite_dish(snapshot, dish)
			var bite_button := _button("Eat %s" % label, func(d: Dictionary = dish) -> void:
				RecipesClient.send_intent({"type": "bite", "dishId": d.get("id", "")})
			)
			bite_button.disabled = not can_bite
			if not can_bite:
				bite_button.text = "Cannot eat yet: %s" % label
			_dish_controls.add_child(bite_button)
		else:
			_dish_controls.add_child(_wrapped_label(label))


func _add_dish_summary_controls(snapshot: Dictionary) -> void:
	_dish_controls.add_child(_wrapped_label(_dish_summary_label(snapshot)))


func _add_transaction_history_controls(snapshot: Dictionary) -> void:
	var has_history := snapshot.has("transactionHistory")
	var transactions: Array = []
	if has_history:
		transactions = snapshot.get("transactionHistory", [])
	var history_complete := bool(snapshot.get("transactionHistoryComplete", true))
	var export_button := _button("Download CSV" if history_complete else "Download Visible CSV", _download_transactions_csv)
	export_button.disabled = not has_history or transactions.is_empty()
	_transaction_controls.add_child(export_button)
	_csv_export_status_label = _wrapped_label(_last_csv_export_status)
	_csv_export_status_label.visible = _last_csv_export_status != ""
	_transaction_controls.add_child(_csv_export_status_label)

	if not snapshot.has("transactionHistory"):
		_transaction_controls.add_child(_wrapped_label("Transaction history is not available from this server. Rebuild and restart the server, then create a new table."))
		return
	if transactions.is_empty():
		_transaction_controls.add_child(_wrapped_label("No successful transactions yet. Deposits, swaps, exchanges, redemptions, preparation, settlement, and eating will appear here."))
		return
	if not history_complete:
		_transaction_controls.add_child(_wrapped_label("Showing latest %s of %s transactions in this live witness view." % [
			transactions.size(),
			int(snapshot.get("transactionHistoryTotal", transactions.size()))
		]))
	_transaction_controls.add_child(_transaction_header_row())
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(0, (TRANSACTION_ROW_HEIGHT + TRANSACTION_ROW_GAP) * TRANSACTION_VISIBLE_ROWS)
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", TRANSACTION_ROW_GAP)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(rows)
	for raw_transaction in transactions:
		var transaction: Dictionary = raw_transaction
		rows.add_child(_transaction_row(transaction))
	_transaction_controls.add_child(scroller)


func _add_hand_place_controls(snapshot: Dictionary) -> void:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var requirements: Array = recipe.get("requirements", [])
	var hand: Array = snapshot.get("ownHand", [])
	var food_parts: Array = snapshot.get("ownFoodParts", [])
	var food_part_group_labels := _food_part_group_labels(snapshot.get("ownFoodPartGroups", []))
	if not food_part_group_labels.is_empty():
		_hand_controls.add_child(_wrapped_label("Food parts you hold\n%s" % "\n".join(food_part_group_labels)))
	elif not food_parts.is_empty():
		_hand_controls.add_child(_wrapped_label("Food parts you hold\n%s" % _format_food_parts(food_parts)))
	if hand.is_empty():
		_hand_controls.add_child(_wrapped_label("Your hand is empty."))
		return
	for raw_voucher in hand:
		var voucher: Dictionary = raw_voucher
		var voucher_id := str(voucher.get("id", ""))
		var ingredient_id := str(voucher.get("ingredientId", ""))
		var ingredient_label := _ingredient_display(snapshot, ingredient_id)
		var needed_requirement: Dictionary = {}
		for raw_requirement in requirements:
			var requirement: Dictionary = raw_requirement
			if str(requirement.get("ingredientId", "")) != ingredient_id:
				continue
			var placed_ids: Array = requirement.get("placedVoucherIds", [])
			var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - placed_ids.size()
			if outstanding <= 0:
				continue
			needed_requirement = requirement
			break
		var voucher_label := _voucher_label(voucher)
		var card_button := _button(voucher_label, func(req: Dictionary = needed_requirement, id: String = voucher_id, label: String = ingredient_label, card_label: String = voucher_label) -> void:
			RecipesClient.send_intent({"type": "redeem_from_hand", "voucherId": id, "requirementId": req.get("id", "")})
			_status_label.text = "Redeeming %s for %s." % [card_label, label]
		)
		if needed_requirement.is_empty():
			card_button.disabled = true
			card_button.text = "Held %s" % voucher_label
		else:
			card_button.text = "Redeem %s for %s" % [voucher_label, ingredient_label]
		_hand_controls.add_child(card_button)


func _add_platter_swap_controls(snapshot: Dictionary) -> void:
	var hand: Array = snapshot.get("ownHand", [])
	var platter: Array = snapshot.get("platter", [])
	_prune_swap_selection(hand, platter)
	if hand.is_empty() or platter.is_empty():
		_platter_controls.add_child(_wrapped_label("Swap needs one hand voucher and one platter voucher."))
		return
	_platter_controls.add_child(_wrapped_label("Giving: %s\nTaking: %s" % [
		_voucher_label_by_id(hand, _selected_hand_voucher_id),
		_voucher_label_by_id(platter, _selected_platter_voucher_id)
	]))
	_platter_controls.add_child(_wrapped_label("Give"))
	_platter_controls.add_child(_select_button(
		_voucher_label_by_id(hand, _selected_hand_voucher_id) if _selected_hand_voucher_id != "" else "Select card to give",
		"platter_give"
	))
	_platter_controls.add_child(_wrapped_label("Take"))
	_platter_controls.add_child(_select_button(
		_voucher_label_by_id(platter, _selected_platter_voucher_id) if _selected_platter_voucher_id != "" else "Select card to take",
		"platter_take"
	))

	var swap_button := _button("Swap Selected", func() -> void:
		if _selected_hand_voucher_id == "" or _selected_platter_voucher_id == "":
			_on_error_received({"description": "Select one hand voucher and one platter voucher."})
			return
		var latest := RecipesClient.latest_snapshot
		var latest_hand: Array = latest.get("ownHand", [])
		var latest_platter: Array = latest.get("platter", [])
		if not _contains_voucher_id(latest_hand, _selected_hand_voucher_id):
			_on_error_received({"description": "The card selected to give is no longer in your hand. Choose again."})
			_selected_hand_voucher_id = ""
			_refresh_controls(latest)
			return
		if not _contains_voucher_id(latest_platter, _selected_platter_voucher_id):
			_on_error_received({"description": "The card selected to take is no longer in the platter. Choose again."})
			_selected_platter_voucher_id = ""
			_refresh_controls(latest)
			return
		var give_label := _voucher_label_by_id(latest_hand, _selected_hand_voucher_id)
		var take_label := _voucher_label_by_id(latest_platter, _selected_platter_voucher_id)
		if RecipesClient.send_intent({"type": "platter_swap", "giveVoucherId": _selected_hand_voucher_id, "takeVoucherId": _selected_platter_voucher_id}):
			_status_label.text = "Swapping %s for %s..." % [give_label, take_label]
	)
	swap_button.disabled = _selected_hand_voucher_id == "" or _selected_platter_voucher_id == "" or not RecipesClient.is_socket_connected()
	if swap_button.disabled:
		swap_button.text = "Reconnect To Swap" if not RecipesClient.is_socket_connected() else "Choose Cards To Swap"
	_platter_controls.add_child(swap_button)


func _add_platter_asset_swap_controls(snapshot: Dictionary) -> void:
	var give_assets := _inventory_asset_options(snapshot)
	var take_assets := _platter_asset_options(snapshot)
	_prune_asset_selection(give_assets, take_assets)
	if give_assets.is_empty() or take_assets.is_empty():
		_platter_controls.add_child(_wrapped_label("Settlement swaps need one held card or food part and one platter card or food part."))
		return

	_platter_controls.add_child(_wrapped_label("Giving: %s\nTaking: %s" % [
		_asset_label_by_key(give_assets, _selected_give_asset_key),
		_asset_label_by_key(take_assets, _selected_take_asset_key)
	]))

	_platter_controls.add_child(_wrapped_label("Give"))
	_platter_controls.add_child(_select_button(
		_asset_label_by_key(give_assets, _selected_give_asset_key) if _selected_give_asset_key != "" else "Select asset to give",
		"asset_give"
	))
	_platter_controls.add_child(_wrapped_label("Take"))
	_platter_controls.add_child(_select_button(
		_asset_label_by_key(take_assets, _selected_take_asset_key) if _selected_take_asset_key != "" else "Select asset to take",
		"asset_take"
	))

	var swap_button := _button("Swap Selected", func() -> void:
		var give_ref := _asset_ref_from_key(_selected_give_asset_key)
		var take_ref := _asset_ref_from_key(_selected_take_asset_key)
		if give_ref.is_empty() or take_ref.is_empty():
			_on_error_received({"description": "Select one held asset and one platter asset."})
			return
		if RecipesClient.send_intent({"type": "platter_asset_swap", "give": give_ref, "take": take_ref}):
			_status_label.text = "Swapping selected assets..."
	)
	swap_button.disabled = _selected_give_asset_key == "" or _selected_take_asset_key == "" or not RecipesClient.is_socket_connected()
	if swap_button.disabled:
		swap_button.text = "Reconnect To Swap" if not RecipesClient.is_socket_connected() else "Choose Assets To Swap"
	_platter_controls.add_child(swap_button)


func _add_offer_controls(snapshot: Dictionary) -> void:
	var incoming_count := 0
	var outgoing_count := 0
	_offer_controls.add_child(_wrapped_label("Incoming Offers"))
	for raw_offer in snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		if str(offer.get("toParticipantId", "")) == str(snapshot.get("viewerParticipantId", "")):
			incoming_count += 1
			_add_incoming_offer(snapshot, offer)
	if incoming_count == 0:
		_offer_controls.add_child(_wrapped_label("No incoming offers."))

	_offer_controls.add_child(_wrapped_label("Your Open Offers"))
	for raw_offer in snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		if str(offer.get("fromParticipantId", "")) == str(snapshot.get("viewerParticipantId", "")):
			outgoing_count += 1
			_offer_controls.add_child(_wrapped_label(_outgoing_offer_label(snapshot, offer)))
			_offer_controls.add_child(_button("Cancel Offer", func(o: Dictionary = offer) -> void:
				RecipesClient.send_intent({"type": "cancel_offer", "offerId": o.get("id", "")})
			))
	if outgoing_count == 0:
		_offer_controls.add_child(_wrapped_label("No open offers."))

	_add_create_offer_controls(snapshot)


func _add_incoming_offer(snapshot: Dictionary, offer: Dictionary) -> void:
	var requested: Dictionary = offer.get("requested", {})
	var ingredient_id := str(requested.get("ingredientId", ""))
	var quantity := int(requested.get("quantity", 1))
	var from_name := _participant_name(snapshot, str(offer.get("fromParticipantId", "")))
	var wanted := "%s x%s" % [_ingredient_display(snapshot, ingredient_id), quantity]
	var matching: Array = []
	for voucher in snapshot.get("ownHand", []):
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			matching.append(voucher.get("id", ""))
		if matching.size() >= quantity:
			break
	_offer_controls.add_child(_wrapped_label("%s offers %s for your %s." % [
		from_name,
		_offer_cards_label(offer),
		wanted
	]))
	if matching.size() >= quantity:
		_offer_controls.add_child(_button("Accept Offer", func(ids := matching.duplicate(), o := offer) -> void:
			RecipesClient.send_intent({"type": "respond_offer", "offerId": o.get("id", ""), "response": "accept", "voucherIds": ids})
		))
	_offer_controls.add_child(_button("Refuse Offer", func(o := offer) -> void:
		RecipesClient.send_intent({"type": "respond_offer", "offerId": o.get("id", ""), "response": "refuse"})
	))


func _add_create_offer_controls(snapshot: Dictionary) -> void:
	var hand: Array = snapshot.get("ownHand", [])
	if hand.is_empty():
		return
	_prune_offer_selection(snapshot, hand)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	_offer_controls.add_child(form)
	form.add_child(_wrapped_label("Create Offer"))

	var target_option := _option_button()
	target_option.add_item("Select player")
	target_option.set_item_metadata(0, "")
	for participant in snapshot.get("participants", []):
		if str(participant.get("id", "")) == str(snapshot.get("viewerParticipantId", "")):
			continue
		if str(participant.get("role", "")) != "active":
			continue
		if not _participant_can_receive_offer(participant):
			continue
		var target_index := target_option.item_count
		target_option.add_item("%s - %s" % [participant.get("name", ""), _ingredient_display(snapshot, str(participant.get("ingredientId", "")))])
		target_option.set_item_metadata(target_index, participant.get("id", ""))
		if str(participant.get("id", "")) == _selected_offer_target_id:
			target_option.select(target_index)
	target_option.item_selected.connect(func(index: int) -> void:
		_selected_offer_target_id = str(target_option.get_item_metadata(index))
		_refresh_controls(RecipesClient.latest_snapshot)
	)

	var card_option := _option_button()
	card_option.add_item("Select card to offer")
	card_option.set_item_metadata(0, "")
	for voucher in hand:
		var card_index := card_option.item_count
		card_option.add_item(_voucher_label(voucher))
		card_option.set_item_metadata(card_index, voucher.get("id", ""))
		if str(voucher.get("id", "")) == _selected_offer_card_id:
			card_option.select(card_index)
	card_option.item_selected.connect(func(index: int) -> void:
		_selected_offer_card_id = str(card_option.get_item_metadata(index))
		_refresh_controls(RecipesClient.latest_snapshot)
	)

	var request_ingredient_id := _offer_requested_ingredient_id(snapshot)

	form.add_child(_wrapped_label("Send offer to"))
	form.add_child(target_option)
	if target_option.item_count <= 1:
		form.add_child(_wrapped_label("No players have their own ingredient available for exchange."))
	form.add_child(_wrapped_label("You give"))
	form.add_child(card_option)
	form.add_child(_wrapped_label("You ask for"))
	form.add_child(_wrapped_label(_offer_request_label(snapshot, request_ingredient_id)))

	var create_button := _button("Create Offer", func() -> void:
		var ingredient_id := _offer_requested_ingredient_id(RecipesClient.latest_snapshot)
		if _selected_offer_target_id == "" or _selected_offer_card_id == "" or ingredient_id == "":
			_on_error_received({"description": "Offer needs a player and a card."})
			return
		RecipesClient.send_intent({
			"type": "create_offer",
			"toParticipantId": _selected_offer_target_id,
			"offeredVoucherIds": [_selected_offer_card_id],
			"requested": {"ingredientId": ingredient_id, "quantity": 1}
		})
		_selected_offer_card_id = ""
	)
	create_button.disabled = _selected_offer_target_id == "" or _selected_offer_card_id == "" or request_ingredient_id == ""
	form.add_child(create_button)


func _set_timer() -> void:
	if _timer_input.text.strip_edges() == "":
		RecipesClient.send_intent({"type": "set_timer", "seconds": null})
		return
	var seconds := int(_timer_input.text)
	if seconds <= 0:
		_on_error_received({"description": "Timer must be a positive number of seconds."})
		return
	RecipesClient.send_intent({"type": "set_timer", "seconds": seconds})


func _set_target_dish_count() -> void:
	var count := int(_target_dish_count_input.text)
	if count < 1 or count > 4:
		_on_error_received({"description": "Dish goal must be between 1 and 4."})
		return
	RecipesClient.send_intent({"type": "set_target_dish_count", "count": count})


func _set_stock() -> void:
	var count := int(_stock_input.text)
	if count < 1:
		_on_error_received({"description": "Stock must be at least 1."})
		return
	RecipesClient.send_intent({"type": "set_stock", "count": count})


func _participant_by_id(snapshot: Dictionary, participant_id: String) -> Dictionary:
	for participant in snapshot.get("participants", []):
		if str(participant.get("id", "")) == participant_id:
			return participant
	return {}


func _participant_name(snapshot: Dictionary, participant_id: String) -> String:
	var participant := _participant_by_id(snapshot, participant_id)
	if participant.is_empty():
		return "Someone"
	return str(participant.get("name", "Someone"))


func _viewer_can_act(snapshot: Dictionary) -> bool:
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	return str(viewer.get("kind", "human")) == "human" and bool(viewer.get("connected", true))


func _viewer_is_witness(snapshot: Dictionary) -> bool:
	if str(snapshot.get("viewerRole", "")) == "witness":
		return true
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	return str(viewer.get("role", "")) == "witness"


func _viewer_can_bite_dish(snapshot: Dictionary, dish: Dictionary) -> bool:
	if str(snapshot.get("phase", "")) != "eating":
		return false
	var viewer_id := str(snapshot.get("viewerParticipantId", ""))
	var viewer := _participant_by_id(snapshot, viewer_id)
	if not bool(viewer.get("cleared", false)):
		return false
	var dish_id := str(dish.get("id", ""))
	for raw_group in snapshot.get("ownFoodPartGroups", []):
		var group: Dictionary = raw_group
		if str(group.get("dishId", "")) == dish_id and int(group.get("count", 0)) > 0:
			return true
	for raw_part in snapshot.get("ownFoodParts", []):
		var part: Dictionary = raw_part
		if str(part.get("dishId", "")) == dish_id:
			return true
	return false


func _can_switch_to_bot(snapshot: Dictionary, participant: Dictionary) -> bool:
	if participant.is_empty():
		return false
	if str(participant.get("kind", "human")) == "bot":
		return false
	if str(participant.get("role", "")) != "active":
		return false
	if bool(participant.get("isHost", false)):
		return false
	return bool(_participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", ""))).get("isHost", false))


func _confirm_switch_to_bot(participant_id: String, participant_name: String) -> void:
	if participant_id == "":
		return
	_pending_bot_participant_id = participant_id
	_confirm_bot_dialog.dialog_text = "Switch %s to a mixed bot?\n\nThis seat will stop accepting that player's current connection token." % participant_name
	_confirm_bot_dialog.popup_centered()


func _on_confirm_switch_to_bot() -> void:
	if _pending_bot_participant_id == "":
		return
	RecipesClient.send_intent({"type": "convert_to_bot", "participantId": _pending_bot_participant_id, "botType": "mixed"})
	_pending_bot_participant_id = ""


func _hand_for_participant(snapshot: Dictionary, participant_id: String) -> Array:
	var all_hands = snapshot.get("allHands", {})
	if typeof(all_hands) == TYPE_DICTIONARY:
		var hands: Dictionary = all_hands
		if hands.has(participant_id):
			return hands.get(participant_id, [])
	var all_vouchers: Array = snapshot.get("allVouchers", [])
	if not all_vouchers.is_empty():
		var hand: Array = []
		for raw_voucher in all_vouchers:
			var voucher: Dictionary = raw_voucher
			var location: Dictionary = voucher.get("location", {})
			if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id:
				hand.append(voucher)
		return hand
	if participant_id == str(snapshot.get("viewerParticipantId", "")):
		return snapshot.get("ownHand", [])
	return []


func _voucher_summary_labels_for_participant(snapshot: Dictionary, participant_id: String) -> Array[String]:
	var labels: Array[String] = []
	for raw_summary in snapshot.get("voucherLocationSummary", []):
		var summary: Dictionary = raw_summary
		var location: Dictionary = summary.get("location", {})
		if str(location.get("type", "")) != "hand" or str(location.get("participantId", "")) != participant_id:
			continue
		var count := int(summary.get("count", 0))
		var ingredient := _ingredient_display(snapshot, str(summary.get("ingredientId", "")))
		labels.append("%s x%s" % [ingredient, count])
	return labels


func _recipe_for_participant(snapshot: Dictionary, participant_id: String) -> Dictionary:
	var all_recipes = snapshot.get("allRecipes", {})
	if typeof(all_recipes) == TYPE_DICTIONARY:
		var recipes: Dictionary = all_recipes
		if recipes.has(participant_id):
			return recipes.get(participant_id, {})
	if participant_id == str(snapshot.get("viewerParticipantId", "")):
		return snapshot.get("ownRecipe", {})
	return {}


func _all_hands_label(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["Player Hands"]
	var count := 0
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		count += 1
		var participant_id := str(participant.get("id", ""))
		lines.append("%s (%s)" % [
			_participant_name(snapshot, participant_id),
			_participant_ingredient_label(snapshot, participant)
		])
		lines.append(_format_participant_inventory(snapshot, participant_id))
	if count == 0:
		lines.append("No active player hands.")
	return "\n".join(lines)


func _all_card_locations_label(snapshot: Dictionary) -> String:
	var summaries: Array = snapshot.get("voucherLocationSummary", [])
	if not summaries.is_empty():
		return _all_card_location_summary_label(snapshot, summaries)

	var all_vouchers: Array = snapshot.get("allVouchers", [])
	var lines: Array[String] = ["Ingredient Card Locations"]
	if all_vouchers.is_empty():
		lines.append("Card location audit is only available to witnesses.")
		return "\n".join(lines)

	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var owner_id := str(participant.get("id", ""))
		var ingredient := _participant_ingredient_label(snapshot, participant)
		var owner_hand := 0
		var other_hands := 0
		var platter := 0
		var placed := 0
		var inactive := 0
		var offer := 0
		var unknown := 0
		var other_hand_labels: Array[String] = []
		var placed_labels: Array[String] = []
		var inactive_labels: Array[String] = []
		var stock_label := "stock %s" % int(participant.get("realIngredientStock", 0)) if participant.has("realIngredientStock") else "stock -"

		for raw_voucher in all_vouchers:
			var voucher: Dictionary = raw_voucher
			if str(voucher.get("ownerParticipantId", "")) != owner_id:
				continue
			var location: Dictionary = voucher.get("location", {})
			var location_type := str(location.get("type", "unknown"))
			match location_type:
				"hand":
					var holder_id := str(location.get("participantId", ""))
					if holder_id == owner_id:
						owner_hand += 1
					else:
						other_hands += 1
						other_hand_labels.append("%s has %s" % [_participant_name(snapshot, holder_id), _voucher_label(voucher)])
				"platter":
					platter += 1
				"placed":
					placed += 1
					placed_labels.append("%s on %s's recipe" % [
						_voucher_label(voucher),
						_participant_name(snapshot, str(location.get("recipeOwnerId", "")))
					])
				"holding":
					inactive += 1
					var redeemed_by_id := str(location.get("recipeOwnerId", ""))
					var redeemed_by := "unknown player from an older table" if redeemed_by_id == "" else _participant_name(snapshot, redeemed_by_id)
					inactive_labels.append("%s last redeemed by %s" % [
						_voucher_label(voucher),
						redeemed_by
					])
				"offer_lock":
					offer += 1
				_:
					unknown += 1

		var total := owner_hand + other_hands + platter + placed + inactive + offer + unknown
		var total_label := "" if total == 7 else ", total %s" % total
		lines.append("%s (%s, %s): owner hand %s, other hands %s, platter %s, placed %s, inactive %s, offer %s%s" % [
			_participant_name(snapshot, owner_id),
			ingredient,
			stock_label,
			owner_hand,
			other_hands,
			platter,
			placed,
			inactive,
			offer,
			total_label
		])
		if not other_hand_labels.is_empty():
			lines.append("Other hands: %s" % "; ".join(other_hand_labels))
		if not placed_labels.is_empty():
			lines.append("Placed: %s" % "; ".join(placed_labels))
		if not inactive_labels.is_empty():
			lines.append("Inactive cards: %s" % "; ".join(inactive_labels))

	return "\n".join(lines)


func _all_card_location_summary_label(snapshot: Dictionary, summaries: Array) -> String:
	var lines: Array[String] = ["Ingredient Card Locations"]
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var owner_id := str(participant.get("id", ""))
		var owner_hand := 0
		var other_hands := 0
		var platter := 0
		var placed := 0
		var inactive := 0
		var offer := 0
		var unknown := 0
		var other_hand_labels: Array[String] = []
		var placed_labels: Array[String] = []
		var inactive_labels: Array[String] = []
		var ingredient := _participant_ingredient_label(snapshot, participant)
		var stock_label := "stock %s" % int(participant.get("realIngredientStock", 0)) if participant.has("realIngredientStock") else "stock -"

		for raw_summary in summaries:
			var summary: Dictionary = raw_summary
			if str(summary.get("ownerParticipantId", "")) != owner_id:
				continue
			var count := int(summary.get("count", 0))
			var location: Dictionary = summary.get("location", {})
			var location_type := str(location.get("type", "unknown"))
			match location_type:
				"hand":
					var holder_id := str(location.get("participantId", ""))
					if holder_id == owner_id:
						owner_hand += count
					else:
						other_hands += count
						other_hand_labels.append("%s has %s x%s" % [
							_participant_name(snapshot, holder_id),
							_ingredient_display(snapshot, str(summary.get("ingredientId", ""))),
							count
						])
				"platter":
					platter += count
				"placed":
					placed += count
					placed_labels.append("%s x%s on %s's recipe" % [
						_ingredient_display(snapshot, str(summary.get("ingredientId", ""))),
						count,
						_participant_name(snapshot, str(location.get("recipeOwnerId", "")))
					])
				"holding":
					inactive += count
					var redeemed_by_id := str(location.get("recipeOwnerId", ""))
					var redeemed_by := "unknown player from an older table" if redeemed_by_id == "" else _participant_name(snapshot, redeemed_by_id)
					inactive_labels.append("%s x%s last redeemed by %s" % [
						_ingredient_display(snapshot, str(summary.get("ingredientId", ""))),
						count,
						redeemed_by
					])
				"offer_lock":
					offer += count
				_:
					unknown += count

		var total := owner_hand + other_hands + platter + placed + inactive + offer + unknown
		var total_label := "" if total == 7 else ", total %s" % total
		lines.append("%s (%s, %s): owner hand %s, other hands %s, platter %s, placed %s, inactive %s, offer %s%s" % [
			_participant_name(snapshot, owner_id),
			ingredient,
			stock_label,
			owner_hand,
			other_hands,
			platter,
			placed,
			inactive,
			offer,
			total_label
		])
		if not other_hand_labels.is_empty():
			lines.append("Other hands: %s" % "; ".join(other_hand_labels))
		if not placed_labels.is_empty():
			lines.append("Placed: %s" % "; ".join(placed_labels))
		if not inactive_labels.is_empty():
			lines.append("Inactive cards: %s" % "; ".join(inactive_labels))

	return "\n".join(lines)


func _open_offers_label(snapshot: Dictionary, participant_id := "") -> String:
	var lines: Array[String] = ["Open Offers for Exchange"]
	var count := 0
	for raw_offer in snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		var from_id := str(offer.get("fromParticipantId", ""))
		var to_id := str(offer.get("toParticipantId", ""))
		if participant_id != "" and from_id != participant_id and to_id != participant_id:
			continue
		var requested: Dictionary = offer.get("requested", {})
		count += 1
		lines.append("%s offers %s to %s for %s x%s." % [
			_participant_name(snapshot, from_id),
			_offer_cards_label(offer),
			_participant_name(snapshot, to_id),
			_ingredient_display(snapshot, str(requested.get("ingredientId", ""))),
			int(requested.get("quantity", 1))
		])
	if count == 0:
		lines.append("No open offers.")
	return "\n".join(lines)


func _dish_summary_label(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["Finished Dishes By Player"]
	var active_count := 0
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		active_count += 1
		var participant_id := str(participant.get("id", ""))
		var dish_names := _dish_names_for_participant(snapshot, participant_id)
		var names_label := "none" if dish_names.is_empty() else ", ".join(dish_names)
		lines.append("%s: %s finished - %s" % [
			participant.get("name", "?"),
			int(participant.get("dishCount", 0)),
			names_label
		])
	if active_count == 0:
		lines.append("No active players.")
	return "\n".join(lines)


func _dish_names_for_participant(snapshot: Dictionary, participant_id: String) -> Array[String]:
	var names: Array[String] = []
	for raw_dish in snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		if str(dish.get("ownerParticipantId", "")) == participant_id:
			names.append(str(dish.get("name", "Dish")))
	return names


func _transaction_history_label(snapshot: Dictionary) -> String:
	if not snapshot.has("transactionHistory"):
		return "Transaction history is not available from this server. Rebuild and restart the server, then create a new table."
	var transactions: Array = snapshot.get("transactionHistory", [])
	if transactions.is_empty():
		return "No successful transactions yet. Deposits, swaps, exchanges, redemptions, preparation, settlement, and eating will appear here."
	var lines: Array[String] = ["Name | Action | Counterparty | Item out | Item back"]
	for raw_transaction in transactions:
		var transaction: Dictionary = raw_transaction
		lines.append("%s | %s | %s | %s | %s" % [
			transaction.get("name", "?"),
			transaction.get("action", "?"),
			transaction.get("counterparty", "?"),
			transaction.get("itemOut", "-"),
			transaction.get("itemBack", "-")
		])
	return "\n".join(lines)


func _finished_plates_label(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["Finished Plates"]
	var dishes: Array = snapshot.get("dishes", [])
	if dishes.is_empty():
		lines.append("No finished plates yet.")
		return "\n".join(lines)
	for raw_dish in dishes:
		var dish: Dictionary = raw_dish
		var owner_id := str(dish.get("ownerParticipantId", ""))
		var remaining := int(dish.get("partsRemaining", dish.get("bitesRemaining", 0)))
		var total := int(dish.get("totalParts", dish.get("totalBites", 0)))
		lines.append("%s by %s, %s/%s %s left" % [
			dish.get("name", "Dish"),
			_participant_name(snapshot, owner_id),
			remaining,
			total,
			_unit_for_count(dish, remaining)
		])
	return "\n".join(lines)


func _prune_offer_selection(snapshot: Dictionary, hand: Array) -> void:
	if _selected_offer_target_id != "":
		var target := _participant_by_id(snapshot, _selected_offer_target_id)
		if target.is_empty() or not _participant_can_receive_offer(target):
			_selected_offer_target_id = ""
	if _selected_offer_card_id != "" and not _contains_voucher_id(hand, _selected_offer_card_id):
		_selected_offer_card_id = ""


func _participant_can_receive_offer(participant: Dictionary) -> bool:
	if str(participant.get("role", "")) != "active":
		return false
	if str(participant.get("ingredientId", "")) == "":
		return false
	return int(participant.get("offerableOwnIngredientQty", 1)) > 0


func _offer_requested_ingredient_id(snapshot: Dictionary) -> String:
	if _selected_offer_target_id == "":
		return ""
	var target := _participant_by_id(snapshot, _selected_offer_target_id)
	if target.is_empty():
		return ""
	return str(target.get("ingredientId", ""))


func _offer_request_label(snapshot: Dictionary, ingredient_id: String) -> String:
	if ingredient_id == "":
		return "Select a player first."
	return "%s x1" % _ingredient_display(snapshot, ingredient_id)


func _ingredient_display(snapshot: Dictionary, ingredient_id: String) -> String:
	if ingredient_id == "":
		return "Unknown"
	for ingredient in snapshot.get("ingredients", []):
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.capitalize()


func _offer_cards_label(offer: Dictionary) -> String:
	var offered: Array = offer.get("offeredVouchers", [])
	if not offered.is_empty():
		var labels: Array[String] = []
		for raw_voucher in offered:
			var voucher: Dictionary = raw_voucher
			labels.append(_voucher_label(voucher))
		return ", ".join(labels)
	var ids: Array = offer.get("offeredVoucherIds", [])
	if ids.is_empty():
		return "nothing"
	return ", ".join(ids)


func _outgoing_offer_label(snapshot: Dictionary, offer: Dictionary) -> String:
	var requested: Dictionary = offer.get("requested", {})
	var to_name := _participant_name(snapshot, str(offer.get("toParticipantId", "")))
	var wanted := "%s x%s" % [
		_ingredient_display(snapshot, str(requested.get("ingredientId", ""))),
		int(requested.get("quantity", 1))
	]
	return "You offer %s to %s for %s." % [
		_offer_cards_label(offer),
		to_name,
		wanted
	]


func _active_count(snapshot: Dictionary) -> int:
	var count := 0
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active":
			count += 1
	return count


func _timer_label(snapshot: Dictionary) -> String:
	var raw_timer = snapshot.get("timer", {})
	if typeof(raw_timer) != TYPE_DICTIONARY:
		return "none"
	var timer: Dictionary = raw_timer
	if timer.is_empty():
		return "none"
	var seconds := int(timer.get("seconds", 0))
	if timer.has("expiredAtMs"):
		return "%ss expired" % seconds
	if timer.has("pausedRemainingMs"):
		return "%ss paused, ~%ss left" % [seconds, int(ceil(float(timer.get("pausedRemainingMs", 0)) / 1000.0))]
	if timer.has("endsAtMs"):
		var now_ms := Time.get_unix_time_from_system() * 1000.0
		var remaining := maxi(0, int(ceil((float(timer.get("endsAtMs", 0)) - now_ms) / 1000.0)))
		return "%ss running, ~%ss left" % [seconds, remaining]
	return "%ss set" % seconds


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _participant_dropdown_label(snapshot: Dictionary, participant: Dictionary) -> String:
	return "%s - %s %s - %s dishes%s" % [
		participant.get("name", "?"),
		participant.get("role", "?"),
		_participant_kind_label(participant),
		int(participant.get("dishCount", 0)),
		_participant_stock_label(participant)
	]


func _participant_detail_text(snapshot: Dictionary, participant: Dictionary) -> String:
	var ingredient := _participant_ingredient_label(snapshot, participant)
	var connected := "online" if bool(participant.get("connected", false)) else "offline"
	var account := "cleared" if bool(participant.get("cleared", false)) else "debt %s, shortfall %s" % [
		int(participant.get("platterDebt", 0)),
		int(participant.get("platterShortfall", 0))
	]
	return "%s\n%s %s, %s dishes, ingredient: %s%s, %s, %s" % [
		participant.get("name", "?"),
		participant.get("role", "?"),
		_participant_kind_label(participant),
		int(participant.get("dishCount", 0)),
		ingredient,
		_participant_stock_label(participant),
		connected,
		account
	]


func _participant_kind_label(participant: Dictionary) -> String:
	return "bot" if str(participant.get("kind", "human")) == "bot" else "player"


func _participant_stock_label(participant: Dictionary) -> String:
	if not participant.has("realIngredientStock"):
		return ""
	return ", stock %s" % int(participant.get("realIngredientStock", 0))


func _participant_ingredient_label(snapshot: Dictionary, participant: Dictionary) -> String:
	var ingredient_id := str(participant.get("ingredientId", ""))
	if ingredient_id == "":
		return "-"
	return _ingredient_display(snapshot, ingredient_id)


func _format_vouchers(vouchers: Array) -> String:
	if vouchers.is_empty():
		return "-"
	var labels: Array[String] = []
	for voucher in vouchers:
		labels.append(_voucher_label(voucher))
	return "\n".join(labels)


func _format_food_parts(parts: Array) -> String:
	if parts.is_empty():
		return "-"
	var labels: Array[String] = []
	for raw_part in parts:
		var part: Dictionary = raw_part
		labels.append(_food_part_label(part))
	return "\n".join(labels)


func _food_part_group_labels(groups: Array) -> Array[String]:
	var labels: Array[String] = []
	for raw_group in groups:
		var group: Dictionary = raw_group
		var count := int(group.get("count", 0))
		if count <= 0:
			continue
		var unit := str(group.get("unitSingular", "part")) if count == 1 else str(group.get("unitPlural", "parts"))
		labels.append("%s: %s %s" % [group.get("dishName", "Dish"), count, unit])
	return labels


func _food_part_group_count(groups: Array) -> int:
	var count := 0
	for raw_group in groups:
		var group: Dictionary = raw_group
		count += int(group.get("count", 0))
	return count


func _format_platter_assets(snapshot: Dictionary) -> String:
	var labels: Array[String] = []
	for raw_voucher in snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		labels.append(_voucher_label(voucher))
	var food_group_labels := _food_part_group_labels(snapshot.get("platterFoodPartGroups", []))
	if not food_group_labels.is_empty():
		labels.append_array(food_group_labels)
	else:
		for raw_part in snapshot.get("platterFoodParts", []):
			var part: Dictionary = raw_part
			labels.append(_food_part_label(part))
	if labels.is_empty():
		return "-"
	return "\n".join(labels)


func _platter_title(snapshot: Dictionary) -> String:
	var platter_vouchers: Array = snapshot.get("platter", [])
	var platter_food_parts: Array = snapshot.get("platterFoodParts", [])
	var voucher_count := platter_vouchers.size()
	var food_part_count := _food_part_group_count(snapshot.get("platterFoodPartGroups", []))
	if food_part_count == 0:
		food_part_count = platter_food_parts.size()
	var total := int(voucher_count + food_part_count)
	if total == 1:
		return "Central platter (1 asset)"
	return "Central platter (%s assets)" % total


func _format_inventory_assets(snapshot: Dictionary) -> String:
	var labels: Array[String] = []
	for raw_voucher in snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		labels.append(_voucher_label(voucher))
	var food_group_labels := _food_part_group_labels(snapshot.get("ownFoodPartGroups", []))
	if not food_group_labels.is_empty():
		labels.append_array(food_group_labels)
	else:
		for raw_part in snapshot.get("ownFoodParts", []):
			var part: Dictionary = raw_part
			labels.append(_food_part_label(part))
	if labels.is_empty():
		return "-"
	return "\n".join(labels)


func _format_participant_inventory(snapshot: Dictionary, participant_id: String) -> String:
	var labels: Array[String] = []
	var hand := _hand_for_participant(snapshot, participant_id)
	for raw_voucher in hand:
		var voucher: Dictionary = raw_voucher
		labels.append(_voucher_label(voucher))
	if hand.is_empty():
		labels.append_array(_voucher_summary_labels_for_participant(snapshot, participant_id))
	for raw_part in _food_parts_for_participant(snapshot, participant_id):
		var part: Dictionary = raw_part
		labels.append(_food_part_label(part))
	for summary_label in _food_part_summary_labels_for_participant(snapshot, participant_id):
		labels.append(summary_label)
	if labels.is_empty():
		return "-"
	return "\n".join(labels)


func _inventory_asset_options(snapshot: Dictionary) -> Array:
	var assets: Array = []
	for raw_voucher in snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		assets.append(_asset_option("voucher", str(voucher.get("id", "")), _voucher_label(voucher)))
	for raw_part in snapshot.get("ownFoodParts", []):
		var part: Dictionary = raw_part
		assets.append(_asset_option("dish_part", str(part.get("id", "")), _food_part_label(part)))
	return assets


func _platter_asset_options(snapshot: Dictionary) -> Array:
	var assets: Array = []
	for raw_voucher in snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		assets.append(_asset_option("voucher", str(voucher.get("id", "")), _voucher_label(voucher)))
	for raw_part in snapshot.get("platterFoodParts", []):
		var part: Dictionary = raw_part
		assets.append(_asset_option("dish_part", str(part.get("id", "")), _food_part_label(part)))
	return assets


func _asset_option(kind: String, id: String, label: String) -> Dictionary:
	return {"kind": kind, "id": id, "key": "%s:%s" % [kind, id], "label": label}


func _asset_ref_from_key(key: String) -> Dictionary:
	var separator := key.find(":")
	if separator <= 0:
		return {}
	return {"kind": key.substr(0, separator), "id": key.substr(separator + 1)}


func _asset_label_by_key(assets: Array, key: String) -> String:
	if key == "":
		return "nothing selected"
	for raw_asset in assets:
		var asset: Dictionary = raw_asset
		if str(asset.get("key", "")) == key:
			return str(asset.get("label", "nothing selected"))
	return "nothing selected"


func _open_select_popup(select_key: String, anchor: Control) -> void:
	_active_select_key = select_key
	_refresh_active_select_popup(RecipesClient.latest_snapshot, true)
	var width := maxi(280, int(anchor.size.x))
	var content_height := int(ceil(_select_popup_list.get_combined_minimum_size().y))
	var panel_padding: int = 20
	var min_height: int = 58
	var max_height: int = 360
	var height: int = clampi(content_height + panel_padding, min_height, max_height)
	var position := Vector2i(int(anchor.global_position.x), int(anchor.global_position.y + anchor.size.y + 4))
	_select_popup.popup(Rect2i(position, Vector2i(width, height)))


func _refresh_active_select_popup(snapshot: Dictionary, force := false) -> void:
	if _active_select_key == "" or not is_instance_valid(_select_popup):
		return
	if not force and not _select_popup.visible:
		return
	_clear(_select_popup_list)
	var options := _select_options(snapshot, _active_select_key)
	if options.is_empty():
		_select_popup_list.add_child(_wrapped_label("No options available."))
		return
	for raw_option in options:
		var option: Dictionary = raw_option
		var option_label := str(option.get("label", ""))
		var option_value := str(option.get("value", ""))
		var item_button := _button(option_label, func(key := _active_select_key, value := option_value) -> void:
			_select_option_value(key, value)
		)
		_select_popup_list.add_child(item_button)


func _select_options(snapshot: Dictionary, select_key: String) -> Array:
	var options: Array = []
	match select_key:
		"platter_give":
			for raw_voucher in snapshot.get("ownHand", []):
				var voucher: Dictionary = raw_voucher
				options.append({"label": _voucher_label(voucher), "value": str(voucher.get("id", ""))})
		"platter_take":
			for raw_voucher in snapshot.get("platter", []):
				var voucher: Dictionary = raw_voucher
				options.append({"label": _voucher_label(voucher), "value": str(voucher.get("id", ""))})
		"asset_give":
			for raw_asset in _inventory_asset_options(snapshot):
				var asset: Dictionary = raw_asset
				options.append({"label": str(asset.get("label", "")), "value": str(asset.get("key", ""))})
		"asset_take":
			for raw_asset in _platter_asset_options(snapshot):
				var asset: Dictionary = raw_asset
				options.append({"label": str(asset.get("label", "")), "value": str(asset.get("key", ""))})
	return options


func _select_option_value(select_key: String, value: String) -> void:
	match select_key:
		"platter_give":
			_selected_hand_voucher_id = value
		"platter_take":
			_selected_platter_voucher_id = value
		"asset_give":
			_selected_give_asset_key = value
		"asset_take":
			_selected_take_asset_key = value
	_select_popup.hide()
	_active_select_key = ""
	_refresh_controls(RecipesClient.latest_snapshot)


func _prune_asset_selection(give_assets: Array, take_assets: Array) -> void:
	if _selected_give_asset_key != "" and not _contains_asset_key(give_assets, _selected_give_asset_key):
		_selected_give_asset_key = ""
	if _selected_take_asset_key != "" and not _contains_asset_key(take_assets, _selected_take_asset_key):
		_selected_take_asset_key = ""


func _contains_asset_key(assets: Array, key: String) -> bool:
	for raw_asset in assets:
		var asset: Dictionary = raw_asset
		if str(asset.get("key", "")) == key:
			return true
	return false


func _food_part_label(part: Dictionary) -> String:
	var dish_name := str(part.get("dishName", "Dish"))
	var unit := str(part.get("unitSingular", "part"))
	var part_id := str(part.get("id", ""))
	var pieces := part_id.split("_")
	var number := ""
	if pieces.size() > 0:
		number = str(pieces[pieces.size() - 1])
	if number == "":
		return "%s %s" % [dish_name, unit]
	return "%s %s %s" % [dish_name, unit, number]


func _food_parts_for_participant(snapshot: Dictionary, participant_id: String) -> Array:
	var result: Array = []
	var all_parts: Array = snapshot.get("allFoodParts", [])
	if all_parts.is_empty() and str(snapshot.get("viewerRole", "")) == "witness":
		all_parts = snapshot.get("dishParts", [])
	if not all_parts.is_empty():
		for raw_part in all_parts:
			var part: Dictionary = raw_part
			var location: Dictionary = part.get("location", {})
			if str(location.get("type", "")) == "inventory" and str(location.get("participantId", "")) == participant_id:
				result.append(part)
		return result
	if participant_id == str(snapshot.get("viewerParticipantId", "")):
		return snapshot.get("ownFoodParts", [])
	return result


func _food_part_summary_labels_for_participant(snapshot: Dictionary, participant_id: String) -> Array[String]:
	var labels: Array[String] = []
	var summaries: Array = snapshot.get("foodPartLocationSummary", [])
	for raw_summary in summaries:
		var summary: Dictionary = raw_summary
		var location: Dictionary = summary.get("location", {})
		if str(location.get("type", "")) != "inventory" or str(location.get("participantId", "")) != participant_id:
			continue
		labels.append(_food_part_summary_label(summary))
	return labels


func _food_part_summary_label(summary: Dictionary) -> String:
	var count := int(summary.get("count", 0))
	var unit := str(summary.get("unitSingular", "part")) if count == 1 else str(summary.get("unitPlural", "parts"))
	return "%s: %s %s" % [summary.get("dishName", "Dish"), count, unit]


func _all_food_part_locations_label(snapshot: Dictionary) -> String:
	var summary_rows: Array = snapshot.get("foodPartLocationSummary", [])
	var lines: Array[String] = ["Dish Part Locations"]
	if not summary_rows.is_empty():
		for raw_summary in summary_rows:
			var summary: Dictionary = raw_summary
			var location: Dictionary = summary.get("location", {})
			var holder := "unknown"
			match str(location.get("type", "")):
				"inventory":
					holder = _participant_name(snapshot, str(location.get("participantId", "")))
				"platter":
					holder = "Central Platter"
				"eaten":
					holder = "Eaten by %s" % _participant_name(snapshot, str(location.get("participantId", "")))
				_:
					holder = str(location.get("type", "unknown"))
			lines.append("%s - %s" % [_food_part_summary_label(summary), holder])
		return "\n".join(lines)

	var all_parts: Array = snapshot.get("allFoodParts", [])
	if all_parts.is_empty() and str(snapshot.get("viewerRole", "")) == "witness":
		all_parts = snapshot.get("dishParts", [])
	if all_parts.is_empty():
		lines.append("No dish parts yet, or this audit is only available to witnesses.")
		return "\n".join(lines)
	for raw_part in all_parts:
		var part: Dictionary = raw_part
		var location: Dictionary = part.get("location", {})
		var holder := "unknown"
		match str(location.get("type", "")):
			"inventory":
				holder = _participant_name(snapshot, str(location.get("participantId", "")))
			"platter":
				holder = "Central Platter"
			"eaten":
				holder = "Eaten by %s" % _participant_name(snapshot, str(location.get("participantId", "")))
			_:
				holder = str(location.get("type", "unknown"))
		lines.append("%s: %s" % [_food_part_label(part), holder])
	return "\n".join(lines)


func _stock_accounting_label(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["Stock Accounting"]
	var starting_stock := int(snapshot.get("stockPerIngredient", 0))
	var participants: Array = snapshot.get("participants", [])
	if participants.is_empty() or starting_stock <= 0:
		lines.append("Stock accounting starts when the game starts.")
		return "\n".join(lines)
	for raw_participant in participants:
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		var remaining := int(participant.get("realIngredientStock", starting_stock))
		var issued := starting_stock - remaining
		var redeem_log_count := _redeem_count_for_counterparty(snapshot, participant_id)
		var status := "OK" if redeem_log_count == issued else "check log"
		lines.append("%s (%s): started %s, issued %s, remaining %s, redeem rows %s - %s" % [
			_participant_name(snapshot, participant_id),
			_participant_ingredient_label(snapshot, participant),
			starting_stock,
			issued,
			remaining,
			redeem_log_count,
			status
		])
	if lines.size() == 1:
		lines.append("No active player stock yet.")
	return "\n".join(lines)


func _redeem_count_for_counterparty(snapshot: Dictionary, participant_id: String) -> int:
	var count := 0
	for raw_transaction in snapshot.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == "Redeem" and str(transaction.get("counterpartyParticipantId", "")) == participant_id:
			count += 1
	return count


func _accountability_label(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["Central Platter Accounts"]
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var status := "cleared" if bool(participant.get("cleared", false)) else "not cleared"
		lines.append("%s: target 1 own card, current %s, debt %s, shortfall %s - %s" % [
			participant.get("name", "?"),
			int(participant.get("ownCardsInPlatter", 0)),
			int(participant.get("platterDebt", 0)),
			int(participant.get("platterShortfall", 0)),
			status
		])
	if lines.size() == 1:
		lines.append("No active player accounts yet.")
	return "\n".join(lines)


func _unit_for_count(dish: Dictionary, count: int) -> String:
	if count == 1:
		return str(dish.get("unitSingular", "part"))
	return str(dish.get("unitPlural", "parts"))


func _prune_swap_selection(hand: Array, platter: Array) -> void:
	if _selected_hand_voucher_id != "" and not _contains_voucher_id(hand, _selected_hand_voucher_id):
		_selected_hand_voucher_id = ""
	if _selected_platter_voucher_id != "" and not _contains_voucher_id(platter, _selected_platter_voucher_id):
		_selected_platter_voucher_id = ""


func _contains_voucher_id(vouchers: Array, voucher_id: String) -> bool:
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return true
	return false


func _voucher_label_by_id(vouchers: Array, voucher_id: String) -> String:
	if voucher_id == "":
		return "nothing selected"
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return _voucher_label(voucher)
	return "nothing selected"


func _voucher_label(voucher: Dictionary) -> String:
	var ingredient_id := str(voucher.get("ingredientId", "?"))
	var voucher_id := str(voucher.get("id", "?"))
	var parts := voucher_id.split("_")
	var card_number := ""
	if parts.size() > 0:
		card_number = str(parts[parts.size() - 1])
	if card_number == "" or card_number == "?":
		return "%s card" % ingredient_id.capitalize()
	return "%s card #%s" % [ingredient_id.capitalize(), card_number]


func _format_recipe(snapshot: Dictionary, recipe: Dictionary) -> String:
	if recipe.is_empty():
		return "-"
	var lines: Array[String] = [str(recipe.get("name", "Recipe"))]
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var placed_ids: Array = requirement.get("placedVoucherIds", [])
		var placed_count: int = placed_ids.size()
		lines.append("%s: %s/%s redeemed, %s placed" % [
			_ingredient_display(snapshot, str(requirement.get("ingredientId", ""))),
			requirement.get("redeemedQty", 0),
			requirement.get("requiredQty", 0),
			placed_count
		])
	return "\n".join(lines)


func _add_recipe_view(root: VBoxContainer, snapshot: Dictionary, recipe: Dictionary) -> void:
	if recipe.is_empty():
		root.add_child(_wrapped_label("-"))
		return
	root.add_child(_wrapped_label(str(recipe.get("name", "Recipe"))))
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		root.add_child(_recipe_requirement_row(snapshot, requirement))


func _recipe_requirement_row(snapshot: Dictionary, requirement: Dictionary) -> Control:
	var text := _recipe_requirement_text(snapshot, requirement)
	var required_qty := int(requirement.get("requiredQty", 0))
	var redeemed_qty := int(requirement.get("redeemedQty", 0))
	var placed_ids: Array = requirement.get("placedVoucherIds", [])
	var placed_qty := placed_ids.size()
	if required_qty > 0 and redeemed_qty >= required_qty:
		return _colored_label(text, Color(0.14, 0.52, 0.25))
	if redeemed_qty > 0 or placed_qty > 0:
		return _colored_label(text, Color(0.88, 0.45, 0.10), Color(0.08, 0.08, 0.08))
	return _wrapped_label(text)


func _recipe_requirement_text(snapshot: Dictionary, requirement: Dictionary) -> String:
	var placed_ids: Array = requirement.get("placedVoucherIds", [])
	return "%s: %s/%s redeemed, %s placed" % [
		_ingredient_display(snapshot, str(requirement.get("ingredientId", ""))),
		requirement.get("redeemedQty", 0),
		requirement.get("requiredQty", 0),
		placed_ids.size()
	]


func _ingredient_list_label(snapshot: Dictionary, ingredient_ids: Array) -> String:
	var labels: Array[String] = []
	for raw_ingredient_id in ingredient_ids:
		labels.append(_ingredient_display(snapshot, str(raw_ingredient_id)))
	return ", ".join(labels)


func _phase_label(phase: String) -> String:
	match phase:
		"lobby":
			return "Lobby"
		"deposit":
			return "Deposit round"
		"playing":
			return "Cooking and trading"
		"settlement":
			return "Settlement"
		"eating":
			return "Eating"
		"complete":
			return "Complete"
		_:
			return phase.capitalize()


func _winners_label(winners: Array) -> String:
	if winners.is_empty():
		return "none yet"
	return ", ".join(winners)


func _recipe_ready(recipe: Dictionary) -> bool:
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return false
	return not recipe.is_empty()


func _recipe_progress_label(recipe: Dictionary) -> String:
	var total_required := 0
	var total_redeemed := 0
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		total_required += int(requirement.get("requiredQty", 0))
		total_redeemed += int(requirement.get("redeemedQty", 0))
	if total_required == 0:
		return "No recipe loaded."
	if total_redeemed >= total_required:
		return "Recipe ready."
	return "Recipe progress: %s/%s redeemed." % [total_redeemed, total_required]
