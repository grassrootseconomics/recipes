extends Control

const TableVisual := preload("res://scripts/table_visual.gd")
const VisualAssets := preload("res://scripts/visual_asset_registry.gd")
const TRANSACTION_VISIBLE_ROWS := 20
const TRANSACTION_ROW_HEIGHT := 30
const TRANSACTION_ROW_GAP := 6
const TRANSACTION_POPUP_MAX_ROWS := 6
const REQUIRED_ACTIVE_SEATS := 8
const APP_VERSION := "0.0.1"
const GE_LOGO_PATH := "res://art/branding/ge-logo-horizontal-text.png"
const SERVER_LIST_PATH := "res://data/servers.json"
const CLIENT_INVITE_URL := "https://recipes.grassecon.org"
const GRASSROOTS_ECONOMICS_URL := "https://grassrootseconomics.org"
const ONLINE_SESSION_STORE_PATH := "user://online-sessions.json"
const ONLINE_SESSION_STORE_TMP_PATH := "user://online-sessions.tmp"
const LOBBY_SEAT_SETUP_STORE_PATH := "user://lobby-seat-setup.json"
const LOBBY_SEAT_SETUP_STORE_TMP_PATH := "user://lobby-seat-setup.tmp"
const DESKTOP_ANDROID_PREVIEW_SIZE := Vector2i(1080, 1920)
const DESKTOP_ANDROID_PREVIEW_MARGIN := 48
const TABLE_VISUAL_BOTTOM_SAFE_MARGIN := 18.0
const LOBBY_NAME_PUBLISH_DELAY_SECONDS := 1.25
const PUBLIC_TABLES_POLL_SECONDS := 2.0

var _status_label: Label
var _server_input: LineEdit
var _server_option: OptionButton
var _name_input: LineEdit
var _seed_input: LineEdit
var _code_input: LineEdit
var _timer_input: LineEdit
var _target_dish_count_input: LineEdit
var _stock_input: LineEdit
var _create_table_button: Button
var _offline_table_button: Button
var _join_table_button: Button
var _reconnect_seat_button: Button
var _leave_table_button: Button
var _server_connect_button: Button
var _generate_code_button: Button
var _take_seat_name_input: LineEdit
var _main_menu_button: Button
var _main_menu_spacer: Control
var _home_panel: PanelContainer
var _home_sprite_layer: Control
var _online_setup_panel: VBoxContainer
var _grassroots_button: Button
var _quit_button: Button
var _version_label: Label
var _ge_logo_texture: Texture2D = null
var _summary_label: Label
var _participants_label: Label
var _participants_option: OptionButton
var _participant_detail_label: Label
var _acting_as_option: OptionButton
var _hand_label: Label
var _platter_label: Label
var _participants_area: VBoxContainer
var _table_visual_holder: Control
var _table_visual: Control
var _post_table_controls: VBoxContainer
var _root_margin: MarginContainer
var _root_container: VBoxContainer
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
var _confirm_offline_end_dialog: ConfirmationDialog
var _offline_end_popup: Control
var _history_popup: PopupPanel
var _history_popup_controls: VBoxContainer
var _csv_file_dialog: FileDialog
var _csv_export_status_label: Label
var _server_check_request: HTTPRequest
var _code_check_request: HTTPRequest
var _public_tables_request: HTTPRequest
var _public_tables_panel: VBoxContainer
var _public_tables_list: VBoxContainer
var _public_tables_status_label: Label
var _public_tables_refresh_button: Button
var _lobby_name_publish_timer: Timer
var _select_popup: PopupPanel
var _select_popup_scroller: ScrollContainer
var _select_popup_list: VBoxContainer
var _csv_http_request: HTTPRequest
var _root_scroll: ScrollContainer
var _home_sprites: Array = []
var _server_options: Array = []
var _home_animation_time := 0.0
var _home_choice := ""
var _server_connected := false
var _connected_server_url := ""
var _server_check_in_progress := false
var _server_check_target_url := ""
var _code_check_in_progress := false
var _code_check_target := ""
var _code_check_for_generation := false
var _code_generation_base := ""
var _code_generation_attempts := 0
var _suppress_invite_code_check := false
var _invite_code_unique := false
var _invite_code_joinable := false
var _invite_code_exists := false
var _ignored_online_session_keys := {}
var _dev_client_profile := ""
var _online_session_store_path := ONLINE_SESSION_STORE_PATH
var _online_session_store_tmp_path := ONLINE_SESSION_STORE_TMP_PATH
var _lobby_seat_setup_store_path := LOBBY_SEAT_SETUP_STORE_PATH
var _lobby_seat_setup_store_tmp_path := LOBBY_SEAT_SETUP_STORE_TMP_PATH

var _selected_hand_voucher_id := ""
var _selected_platter_voucher_id := ""
var _selected_give_asset_key := ""
var _selected_take_asset_key := ""
var _selected_offer_target_id := ""
var _selected_offer_ingredient_id := ""
var _selected_participant_id := ""
var _pending_bot_participant_id := ""
var _pending_csv := ""
var _pending_csv_filename := ""
var _csv_download_filename := ""
var _last_csv_export_status := ""
var _history_popup_visible_rows := TRANSACTION_VISIBLE_ROWS
var _pending_controlled_deposit_actor_id := ""
var _last_controlled_turn_participant_id := ""
var _pending_controlled_follow_participant_id := ""
var _last_popup_close_key := ""
var _last_popup_close_ms := -1
var _left_table_codes := {}
var _active_select_key := ""
var _collapsed_gameplay_for_table := ""
var _lobby_seat_name_inputs := {}
var _lobby_seat_kind_inputs := {}
var _lobby_pending_seat_names := {}
var _saved_lobby_seat_setup := {}
var _public_tables_poll_elapsed := 0.0
var _public_tables_request_quiet := false


func _ready() -> void:
	_configure_dev_client_profile()
	_configure_desktop_debug_window()
	_csv_http_request = HTTPRequest.new()
	_csv_http_request.timeout = 20.0
	add_child(_csv_http_request)
	_csv_http_request.request_completed.connect(_on_csv_download_completed)
	_replace_server_check_request()
	_code_check_request = HTTPRequest.new()
	_code_check_request.timeout = 5.0
	add_child(_code_check_request)
	_code_check_request.request_completed.connect(_on_code_check_completed)
	_public_tables_request = HTTPRequest.new()
	_public_tables_request.timeout = 8.0
	add_child(_public_tables_request)
	_public_tables_request.request_completed.connect(_on_public_tables_completed)
	_lobby_name_publish_timer = Timer.new()
	_lobby_name_publish_timer.one_shot = true
	_lobby_name_publish_timer.wait_time = LOBBY_NAME_PUBLISH_DELAY_SECONDS
	add_child(_lobby_name_publish_timer)
	_lobby_name_publish_timer.timeout.connect(_flush_pending_lobby_name_edits)
	_build_ui()
	set_process(true)
	RecipesClient.snapshot_received.connect(_on_snapshot_received)
	RecipesClient.error_received.connect(_on_error_received)
	RecipesClient.connection_changed.connect(_on_connection_changed)


func _configure_desktop_debug_window() -> void:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS" or os_name == "Web":
		return
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var max_size := usable_rect.size - Vector2i(DESKTOP_ANDROID_PREVIEW_MARGIN, DESKTOP_ANDROID_PREVIEW_MARGIN)
	var preview_size := DESKTOP_ANDROID_PREVIEW_SIZE
	if max_size.x > 0 and max_size.y > 0:
		preview_size.x = mini(preview_size.x, max_size.x)
		preview_size.y = mini(preview_size.y, max_size.y)
	DisplayServer.window_set_min_size(Vector2i(mini(360, preview_size.x), mini(640, preview_size.y)))
	DisplayServer.window_set_size(preview_size)
	if usable_rect.size.x > preview_size.x and usable_rect.size.y > preview_size.y:
		DisplayServer.window_set_position(usable_rect.position + (usable_rect.size - preview_size) / 2)


func _configure_dev_client_profile() -> void:
	var args := _dev_client_profile_args()
	var profile := ""
	for index in range(args.size()):
		var arg := str(args[index])
		if arg == "--client-profile" or arg == "--profile":
			if index + 1 < args.size():
				profile = str(args[index + 1])
				break
		elif arg.begins_with("--client-profile="):
			profile = arg.trim_prefix("--client-profile=")
			break
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
			break
	profile = _sanitize_dev_client_profile(profile)
	if profile == "":
		return
	_dev_client_profile = profile
	_online_session_store_path = "user://online-sessions-%s.json" % profile
	_online_session_store_tmp_path = "user://online-sessions-%s.tmp" % profile
	_lobby_seat_setup_store_path = "user://lobby-seat-setup-%s.json" % profile
	_lobby_seat_setup_store_tmp_path = "user://lobby-seat-setup-%s.tmp" % profile


func _dev_client_profile_args() -> Array:
	var args: Array = []
	for raw_arg in OS.get_cmdline_user_args():
		args.append(str(raw_arg))
	var raw_args := OS.get_cmdline_args()
	for raw_arg in raw_args:
		var arg := str(raw_arg)
		if not args.has(arg):
			args.append(arg)
	return args


func _sanitize_dev_client_profile(value: String) -> String:
	var result := ""
	for index in range(value.length()):
		var character := value.substr(index, 1)
		var code := character.unicode_at(0)
		var allowed := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character == "_" or character == "-"
		if allowed:
			result += character
	return result.left(32)


func _process(delta: float) -> void:
	_update_home_sprites(delta)
	_poll_public_tables_if_visible(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_home_panel_to_window()
		_fit_table_visual_to_window()


func _exit_tree() -> void:
	_home_sprites.clear()
	_ge_logo_texture = null
	VisualAssets.clear_cache()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.84, 0.78, 0.64)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	_root_scroll = scroll
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var margin := MarginContainer.new()
	_root_margin = margin
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var root := VBoxContainer.new()
	_root_container = root
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_home_panel = _build_home_panel()
	root.add_child(_home_panel)
	_fit_home_panel_to_window()

	_status_label = _wrapped_label("Choose offline pass-and-play or connect to an online Recipes server.")
	_status_label.visible = false
	root.add_child(_status_label)

	_main_menu_button = _button("Main Menu", _return_to_main_menu)
	_main_menu_button.visible = false

	_online_setup_panel = VBoxContainer.new()
	_online_setup_panel.add_theme_constant_override("separation", 6)
	_online_setup_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_setup_panel.visible = false
	root.add_child(_online_setup_panel)

	_name_input = LineEdit.new()
	_name_input.visible = false
	root.add_child(_name_input)
	_seed_input = LineEdit.new()
	_seed_input.visible = false
	root.add_child(_seed_input)
	_build_online_setup_controls(_online_setup_panel)

	var connect_row := _button_row()
	_online_setup_panel.add_child(connect_row)
	_create_table_button = _button("Create Table", _on_create_pressed)
	_join_table_button = _button("Join Table", _on_join_pressed)
	_reconnect_seat_button = _button("Reconnect Seat", _on_reconnect_seat_pressed)
	_leave_table_button = _button("Leave Table", _confirm_leave_table)
	connect_row.add_child(_create_table_button)
	connect_row.add_child(_join_table_button)
	connect_row.add_child(_reconnect_seat_button)
	connect_row.add_child(_leave_table_button)
	_build_public_tables_browser(_online_setup_panel)
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
	_acting_as_option = _option_button()
	_acting_as_option.item_selected.connect(_on_acting_as_selected)
	_acting_as_option.visible = false
	_participants_area.add_child(_acting_as_option)

	_table_section = _section(root, "Table")
	_phase_controls = _section_controls(_table_section)

	_table_visual_holder = Control.new()
	_table_visual_holder.visible = false
	_table_visual_holder.clip_contents = true
	_table_visual_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_visual_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_table_visual_holder.custom_minimum_size = Vector2(0, 620)
	root.add_child(_table_visual_holder)

	_table_visual = TableVisual.new()
	_table_visual.visible = true
	_table_visual.intent_requested.connect(_on_table_visual_intent_requested)
	_table_visual.view_requested.connect(_on_table_visual_view_requested)
	_table_visual.status_requested.connect(_on_table_visual_status_requested)
	_table_visual.menu_requested.connect(_on_table_visual_menu_requested)
	_table_visual_holder.add_child(_table_visual)

	_post_table_controls = VBoxContainer.new()
	_post_table_controls.visible = false
	_post_table_controls.add_theme_constant_override("separation", 6)
	_post_table_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_post_table_controls)

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

	_main_menu_spacer = Control.new()
	_main_menu_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_menu_spacer.visible = false
	root.add_child(_main_menu_spacer)
	root.add_child(_main_menu_button)

	_confirm_bot_dialog = ConfirmationDialog.new()
	_confirm_bot_dialog.title = "Switch to bot?"
	_confirm_bot_dialog.dialog_text = "Switch this player seat to a mixed bot?"
	_confirm_bot_dialog.confirmed.connect(_on_confirm_switch_to_bot)
	add_child(_confirm_bot_dialog)
	_configure_confirmation_dialog(_confirm_bot_dialog)

	_confirm_leave_dialog = ConfirmationDialog.new()
	_confirm_leave_dialog.title = "Leave table?"
	_confirm_leave_dialog.dialog_text = "Are you sure you want to leave?\n\nYou will not be able to rejoin as a player, but you can rejoin as a witness."
	_confirm_leave_dialog.confirmed.connect(_on_confirm_leave_table)
	add_child(_confirm_leave_dialog)
	_configure_confirmation_dialog(_confirm_leave_dialog)

	_confirm_close_dialog = ConfirmationDialog.new()
	_confirm_close_dialog.title = "Close table?"
	_confirm_close_dialog.dialog_text = "Are you sure you want to end this table?"
	_confirm_close_dialog.confirmed.connect(_on_confirm_close_table)
	add_child(_confirm_close_dialog)
	_configure_confirmation_dialog(_confirm_close_dialog)

	_confirm_offline_end_dialog = ConfirmationDialog.new()
	_confirm_offline_end_dialog.title = "Stop cooking?"
	_confirm_offline_end_dialog.dialog_text = "Are you sure you want to stop cooking?"
	_confirm_offline_end_dialog.confirmed.connect(_on_confirm_offline_end_game)
	add_child(_confirm_offline_end_dialog)
	_configure_confirmation_dialog(_confirm_offline_end_dialog)
	_confirm_offline_end_dialog.visible = false

	_offline_end_popup = _build_offline_end_popup()
	add_child(_offline_end_popup)

	_history_popup = _build_history_popup()
	_configure_persistent_popup(_history_popup)
	add_child(_history_popup)

	_csv_file_dialog = FileDialog.new()
	_csv_file_dialog.title = "Save Transaction CSV"
	_csv_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_csv_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_csv_file_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	_csv_file_dialog.file_selected.connect(_on_csv_file_selected)
	_csv_file_dialog.canceled.connect(_on_csv_save_canceled)
	add_child(_csv_file_dialog)

	_select_popup = PopupPanel.new()
	_configure_persistent_popup(_select_popup)
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
		_last_popup_close_key = _active_select_key
		_last_popup_close_ms = Time.get_ticks_msec()
	)
	add_child(_select_popup)

	_set_lobby_ui_visible(false)
	_set_gameplay_ui_visible(false)


func _build_home_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _home_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	_home_sprite_layer = Control.new()
	_home_sprite_layer.custom_minimum_size = Vector2(0, 300)
	_home_sprite_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_home_sprite_layer)
	_build_home_sprites()

	var title := Label.new()
	title.text = "Recipes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.20))
	title.add_theme_color_override("font_outline_color", Color(0.18, 0.16, 0.09))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_shadow_color", Color(0.22, 0.12, 0.04, 0.38))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Cook, trade, and share the table"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.22, 0.17, 0.10))
	box.add_child(subtitle)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(actions)

	_offline_table_button = _home_button("Offline", Color(0.25, 0.55, 0.32), Color(0.84, 0.98, 0.66), _start_offline_table)
	var online_button := _home_button("Online", Color(0.72, 0.32, 0.12), Color(1.0, 0.83, 0.46), _show_online_setup)
	actions.add_child(_offline_table_button)
	actions.add_child(online_button)

	var ge_gap := Control.new()
	ge_gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(ge_gap)

	_grassroots_button = _home_logo_button(_open_grassroots_economics)
	box.add_child(_grassroots_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(footer_spacer)

	_version_label = Label.new()
	_version_label.text = "v%s" % APP_VERSION
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_version_label.custom_minimum_size = Vector2(0, 26)
	_version_label.add_theme_font_size_override("font_size", 16)
	_version_label.add_theme_color_override("font_color", Color(0.16, 0.13, 0.08, 0.86))
	_version_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.84, 0.72))
	_version_label.add_theme_constant_override("outline_size", 2)
	box.add_child(_version_label)

	_quit_button = _home_footer_button("Quit", _quit_game)
	box.add_child(_quit_button)

	return panel


func _fit_home_panel_to_window() -> void:
	if not is_instance_valid(_home_panel):
		return
	var viewport_height := get_viewport_rect().size.y
	_home_panel.custom_minimum_size = Vector2(0, maxf(620.0, viewport_height - 40.0))


func _build_online_setup_controls(root: VBoxContainer) -> void:
	var title := _lobby_title("Online Table")
	title.custom_minimum_size = Vector2(0, 30)
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	var server_label := _wrapped_label("Server URL")
	server_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(server_label)

	_server_options = _load_server_options()
	_server_option = _option_button()
	_server_option.custom_minimum_size = Vector2(0, 34)
	for raw_server in _server_options:
		var server: Dictionary = raw_server
		var label := "%s  %s" % [str(server.get("name", "Server")), str(server.get("url", ""))]
		_server_option.add_item(label)
		_server_option.set_item_metadata(_server_option.get_item_count() - 1, str(server.get("url", "")))
	_server_option.add_item("Other")
	_server_option.set_item_metadata(_server_option.get_item_count() - 1, "")
	_server_option.item_selected.connect(_on_server_option_selected)
	root.add_child(_server_option)

	_server_input = _line_edit("Custom server URL", _first_server_url())
	_server_input.custom_minimum_size = Vector2(0, 34)
	_server_input.visible = false
	_server_input.text_changed.connect(func(_text: String) -> void:
		_mark_server_unconnected()
	)
	root.add_child(_server_input)

	_server_connect_button = _button("Connect", _connect_to_selected_server)
	_server_connect_button.custom_minimum_size = Vector2(112, 34)
	root.add_child(_server_connect_button)

	var code_label := _wrapped_label("Invite Code")
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(code_label)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	code_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(code_row)

	_code_input = _line_edit("Connect to a server first", "")
	_code_input.custom_minimum_size = Vector2(0, 34)
	_code_input.text_changed.connect(func(_text: String) -> void:
		_on_invite_code_changed()
	)
	code_row.add_child(_code_input)

	_generate_code_button = _button("Generate", func() -> void:
		_begin_unique_code_generation()
	)
	_generate_code_button.custom_minimum_size = Vector2(104, 34)
	_generate_code_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	code_row.add_child(_generate_code_button)
	_refresh_online_setup_ready_state()


func _build_public_tables_browser(root: VBoxContainer) -> void:
	_public_tables_panel = VBoxContainer.new()
	_public_tables_panel.add_theme_constant_override("separation", 6)
	_public_tables_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_public_tables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_public_tables_panel.visible = false
	root.add_child(_public_tables_panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_public_tables_panel.add_child(header)

	var title := _wrapped_label("Public Tables")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_public_tables_refresh_button = _button("Refresh", _request_public_tables)
	_public_tables_refresh_button.custom_minimum_size = Vector2(108, 32)
	_public_tables_refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(_public_tables_refresh_button)

	_public_tables_status_label = _wrapped_label("Connect to a server to see public tables.")
	_public_tables_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_public_tables_panel.add_child(_public_tables_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_public_tables_panel.add_child(scroll)

	_public_tables_list = VBoxContainer.new()
	_public_tables_list.add_theme_constant_override("separation", 6)
	_public_tables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_public_tables_list)


func _request_public_tables(quiet := false) -> void:
	if not _server_is_ready():
		if not quiet:
			_render_public_tables([])
			if is_instance_valid(_public_tables_status_label):
				_public_tables_status_label.text = "Connect to a server to see public tables."
		return
	if not is_instance_valid(_public_tables_request):
		return
	if _public_tables_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		if quiet:
			return
		_public_tables_request.cancel_request()
	_public_tables_request_quiet = quiet
	if not quiet and is_instance_valid(_public_tables_status_label):
		_public_tables_status_label.text = "Looking for public tables..."
	var err := _public_tables_request.request("%s/tables" % _connected_server_url.trim_suffix("/"))
	if err != OK:
		_public_tables_request_quiet = false
		if not quiet and is_instance_valid(_public_tables_status_label):
			_public_tables_status_label.text = "Could not load public tables."


func _on_public_tables_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var quiet := _public_tables_request_quiet
	_public_tables_request_quiet = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if not quiet:
			_render_public_tables([])
		if not quiet and is_instance_valid(_public_tables_status_label):
			_public_tables_status_label.text = "Could not load public tables."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		if not quiet:
			_render_public_tables([])
		if not quiet and is_instance_valid(_public_tables_status_label):
			_public_tables_status_label.text = "Could not load public tables."
		return
	var result_body: Dictionary = parsed.get("result", {})
	var tables: Array = result_body.get("tables", [])
	_render_public_tables(tables)


func _poll_public_tables_if_visible(delta: float) -> void:
	if not is_instance_valid(_public_tables_panel) or not _public_tables_panel.visible or not _server_is_ready():
		_public_tables_poll_elapsed = 0.0
		return
	_public_tables_poll_elapsed += delta
	if _public_tables_poll_elapsed < PUBLIC_TABLES_POLL_SECONDS:
		return
	_public_tables_poll_elapsed = 0.0
	_request_public_tables(true)


func _render_public_tables(tables: Array) -> void:
	if not is_instance_valid(_public_tables_list):
		return
	_clear(_public_tables_list)
	if tables.is_empty():
		if is_instance_valid(_public_tables_status_label):
			_public_tables_status_label.text = "No public tables are waiting."
		return
	if is_instance_valid(_public_tables_status_label):
		_public_tables_status_label.text = "Tap a table to fill its invite code."
	for raw_table in tables:
		if typeof(raw_table) != TYPE_DICTIONARY:
			continue
		var table: Dictionary = raw_table
		var code := str(table.get("code", "")).to_upper()
		if code == "":
			continue
		var host_name := str(table.get("hostName", "Host"))
		var open_seats := int(table.get("openSeats", 0))
		var human_seats := int(table.get("humanSeats", 0))
		var row := _button("%s  Host: %s  %s human, %s open" % [code, host_name, human_seats, open_seats], func(table_code := code) -> void:
			_select_public_table(table_code)
		)
		row.custom_minimum_size = Vector2(0, 38)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_public_tables_list.add_child(row)


func _select_public_table(code: String) -> void:
	if not is_instance_valid(_code_input):
		return
	_suppress_invite_code_check = true
	_code_input.text = code.strip_edges().to_upper()
	_suppress_invite_code_check = false
	_request_invite_code_status(_normalized_invite_code(), false)


func _load_server_options() -> Array:
	var fallback: Array = [{"name": "Local Test Server", "url": "http://127.0.0.1:3000"}]
	if not FileAccess.file_exists(SERVER_LIST_PATH):
		return fallback
	var file := FileAccess.open(SERVER_LIST_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	var servers: Array = parsed.get("servers", [])
	var result: Array = []
	for raw_server in servers:
		if typeof(raw_server) != TYPE_DICTIONARY:
			continue
		var server: Dictionary = raw_server
		var url := str(server.get("url", "")).strip_edges()
		if url.begins_with("http://") or url.begins_with("https://"):
			result.append({
				"name": str(server.get("name", "Server")).strip_edges(),
				"url": url
			})
	return result if not result.is_empty() else fallback


func _first_server_url() -> String:
	if _server_options.is_empty():
		return "http://127.0.0.1:3000"
	var first: Dictionary = _server_options[0]
	return str(first.get("url", "http://127.0.0.1:3000"))


func _on_server_option_selected(index: int) -> void:
	if not is_instance_valid(_server_option) or not is_instance_valid(_server_input):
		return
	var url := str(_server_option.get_item_metadata(index))
	_server_input.visible = url == ""
	if url != "":
		_server_input.text = url
	_mark_server_unconnected()


func _selected_server_url() -> String:
	if is_instance_valid(_server_input):
		return _server_input.text.strip_edges()
	return "http://127.0.0.1:3000"


func _server_is_ready() -> bool:
	return _server_connected and _connected_server_url == _selected_server_url().trim_suffix("/")


func _online_session_key(server_url: String, code: String) -> String:
	return "%s|%s" % [server_url.strip_edges().trim_suffix("/"), code.strip_edges().to_upper()]


func _online_session_ignore_key(server_url: String, code: String, seat_token: String) -> String:
	return "%s|%s" % [_online_session_key(server_url, code), seat_token]


func _load_online_sessions() -> Dictionary:
	if not FileAccess.file_exists(_online_session_store_path):
		return {"sessions": {}}
	var file := FileAccess.open(_online_session_store_path, FileAccess.READ)
	if file == null:
		return {"sessions": {}}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return {"sessions": {}}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"sessions": {}}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"sessions": {}}
	var sessions = parsed.get("sessions", {})
	if typeof(sessions) != TYPE_DICTIONARY:
		return {"sessions": {}}
	return {"sessions": sessions}


func _save_online_sessions(store: Dictionary) -> void:
	var file := FileAccess.open(_online_session_store_tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(store, "\t"))
	file.close()
	var target_path := ProjectSettings.globalize_path(_online_session_store_path)
	var tmp_path := ProjectSettings.globalize_path(_online_session_store_tmp_path)
	if FileAccess.file_exists(_online_session_store_path):
		DirAccess.remove_absolute(target_path)
	if DirAccess.rename_absolute(tmp_path, target_path) != OK:
		var fallback := FileAccess.open(_online_session_store_path, FileAccess.WRITE)
		if fallback == null:
			return
		fallback.store_string(JSON.stringify(store, "\t"))
		fallback.close()


func _load_lobby_seat_setup() -> Dictionary:
	if not FileAccess.file_exists(_lobby_seat_setup_store_path):
		return {"seats": []}
	var file := FileAccess.open(_lobby_seat_setup_store_path, FileAccess.READ)
	if file == null:
		return {"seats": []}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return {"seats": []}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"seats": []}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"seats": []}
	var seats = parsed.get("seats", [])
	if typeof(seats) != TYPE_ARRAY:
		return {"seats": []}
	return {"seats": seats}


func _save_lobby_seat_setup(store: Dictionary) -> void:
	var file := FileAccess.open(_lobby_seat_setup_store_tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(store, "\t"))
	file.close()
	var target_path := ProjectSettings.globalize_path(_lobby_seat_setup_store_path)
	var tmp_path := ProjectSettings.globalize_path(_lobby_seat_setup_store_tmp_path)
	if FileAccess.file_exists(_lobby_seat_setup_store_path):
		DirAccess.remove_absolute(target_path)
	if DirAccess.rename_absolute(tmp_path, target_path) != OK:
		var fallback := FileAccess.open(_lobby_seat_setup_store_path, FileAccess.WRITE)
		if fallback == null:
			return
		fallback.store_string(JSON.stringify(store, "\t"))
		fallback.close()
	_saved_lobby_seat_setup = store.duplicate(true)


func _online_session_candidates_for_code(code: String) -> Array:
	var normalized_code := code.strip_edges().to_upper()
	if normalized_code == "" or not _server_is_ready():
		return []
	var store := _load_online_sessions()
	var sessions: Dictionary = store.get("sessions", {})
	var raw_sessions = sessions.get(_online_session_key(_connected_server_url, normalized_code), [])
	var candidates: Array = []
	if typeof(raw_sessions) == TYPE_ARRAY:
		for raw_session in raw_sessions:
			if typeof(raw_session) == TYPE_DICTIONARY:
				candidates.append(raw_session)
	elif typeof(raw_sessions) == TYPE_DICTIONARY:
		candidates.append(raw_sessions)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if bool(left.get("isHost", false)) != bool(right.get("isHost", false)):
			return bool(left.get("isHost", false))
		return int(left.get("savedAt", 0)) > int(right.get("savedAt", 0))
	)
	return candidates


func _saved_online_session_for_code(code: String) -> Dictionary:
	var normalized_code := code.strip_edges().to_upper()
	if normalized_code == "" or not _server_is_ready():
		return {}
	for raw_session in _online_session_candidates_for_code(normalized_code):
		var saved_session: Dictionary = raw_session
		var seat_token := str(saved_session.get("seatToken", ""))
		if seat_token == "":
			continue
		if bool(_ignored_online_session_keys.get(_online_session_ignore_key(_connected_server_url, normalized_code, seat_token), false)):
			continue
		return saved_session
	return {}


func _has_saved_online_session_for_current_code() -> bool:
	return _invite_code_exists and not _saved_online_session_for_code(_normalized_invite_code()).is_empty()


func _save_current_online_session(snapshot: Dictionary) -> void:
	if bool(snapshot.get("offline", false)) or RecipesClient.offline_mode:
		return
	var code := str(snapshot.get("tableCode", RecipesClient.table_code)).strip_edges().to_upper()
	if code == "" or RecipesClient.seat_token == "" or RecipesClient.server_url == "":
		return
	var participant_id := str(snapshot.get("connectionParticipantId", RecipesClient.participant_id))
	var store := _load_online_sessions()
	var sessions: Dictionary = store.get("sessions", {})
	var session_key := _online_session_key(RecipesClient.server_url, code)
	var existing: Variant = sessions.get(session_key, [])
	var session_rows: Array = []
	if typeof(existing) == TYPE_ARRAY:
		for raw_session in existing:
			if typeof(raw_session) == TYPE_DICTIONARY:
				var row: Dictionary = raw_session
				if str(row.get("participantId", "")) != participant_id and str(row.get("seatToken", "")) != RecipesClient.seat_token:
					session_rows.append(row)
	elif typeof(existing) == TYPE_DICTIONARY:
		var existing_row: Dictionary = existing
		if str(existing_row.get("participantId", "")) != participant_id and str(existing_row.get("seatToken", "")) != RecipesClient.seat_token:
			session_rows.append(existing_row)
	var session := {
		"serverUrl": RecipesClient.server_url.strip_edges().trim_suffix("/"),
		"tableCode": code,
		"participantId": participant_id,
		"isHost": participant_id == str(snapshot.get("hostParticipantId", "")),
		"seatToken": RecipesClient.seat_token,
		"savedAt": int(Time.get_unix_time_from_system())
	}
	if bool(session.get("isHost", false)):
		session_rows.push_front(session)
	else:
		session_rows.append(session)
	while session_rows.size() > 8:
		session_rows.remove_at(session_rows.size() - 1)
	sessions[session_key] = session_rows
	store["sessions"] = sessions
	_save_online_sessions(store)


func _forget_online_session(server_url: String, code: String, seat_token := "") -> void:
	var normalized_code := code.strip_edges().to_upper()
	if server_url.strip_edges() == "" or normalized_code == "":
		return
	var store := _load_online_sessions()
	var sessions: Dictionary = store.get("sessions", {})
	var session_key := _online_session_key(server_url, normalized_code)
	if seat_token == "":
		sessions.erase(session_key)
	else:
		var existing: Variant = sessions.get(session_key, [])
		var kept: Array = []
		if typeof(existing) == TYPE_ARRAY:
			for raw_session in existing:
				if typeof(raw_session) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = raw_session
				if str(row.get("seatToken", "")) != seat_token:
					kept.append(row)
		elif typeof(existing) == TYPE_DICTIONARY:
			var existing_row: Dictionary = existing
			if str(existing_row.get("seatToken", "")) != seat_token:
				kept.append(existing_row)
		if kept.is_empty():
			sessions.erase(session_key)
		else:
			sessions[session_key] = kept
	store["sessions"] = sessions
	_save_online_sessions(store)


func _ignore_online_session_for_process(server_url: String, code: String) -> void:
	var normalized_code := code.strip_edges().to_upper()
	if server_url.strip_edges() == "" or normalized_code == "":
		return
	_ignored_online_session_keys[_online_session_ignore_key(server_url, normalized_code, RecipesClient.seat_token)] = true


func _resume_saved_online_session(code: String) -> bool:
	var session := _saved_online_session_for_code(code)
	if session.is_empty():
		return false
	var server_url := str(session.get("serverUrl", _connected_server_url)).strip_edges().trim_suffix("/")
	var table_code := str(session.get("tableCode", code)).strip_edges().to_upper()
	var participant_id := str(session.get("participantId", ""))
	var seat_token := str(session.get("seatToken", ""))
	_status_label.text = "Reconnecting to your saved seat..."
	_status_label.visible = true
	return RecipesClient.resume_online_session(server_url, table_code, participant_id, seat_token)


func _replace_server_check_request() -> void:
	if is_instance_valid(_server_check_request):
		if _server_check_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_server_check_request.cancel_request()
		if _server_check_request.request_completed.is_connected(_on_server_check_completed):
			_server_check_request.request_completed.disconnect(_on_server_check_completed)
		_server_check_request.queue_free()
	_server_check_request = HTTPRequest.new()
	_server_check_request.timeout = 5.0
	add_child(_server_check_request)
	_server_check_request.request_completed.connect(_on_server_check_completed)


func _cancel_code_check_request() -> void:
	if is_instance_valid(_code_check_request) and _code_check_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_code_check_request.cancel_request()


func _mark_server_unconnected() -> void:
	_server_check_in_progress = false
	_server_check_target_url = ""
	_cancel_code_check_request()
	if is_instance_valid(_public_tables_request) and _public_tables_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_public_tables_request.cancel_request()
	_public_tables_request_quiet = false
	_public_tables_poll_elapsed = 0.0
	_server_connected = false
	_connected_server_url = ""
	_reset_invite_code_state()
	_render_public_tables([])
	_refresh_online_setup_ready_state()


func _refresh_online_setup_ready_state() -> void:
	var ready := _server_is_ready()
	var saved_session_available := ready and _has_saved_online_session_for_current_code()
	var has_table := _table_exists(RecipesClient.latest_snapshot)
	if is_instance_valid(_code_input):
		_code_input.editable = ready
		if not ready and _code_input.text.strip_edges().to_upper() == "OFFLINE":
			_code_input.text = ""
	if is_instance_valid(_generate_code_button):
		_generate_code_button.disabled = not ready
	if is_instance_valid(_create_table_button):
		_create_table_button.disabled = _home_choice == "online" and not has_table and (not ready or not _invite_code_unique or _code_check_in_progress)
	if is_instance_valid(_join_table_button):
		_join_table_button.text = "Join Table"
		_join_table_button.disabled = _home_choice == "online" and not has_table and (not ready or _code_check_in_progress or (not _invite_code_joinable and not saved_session_available))
		_style_join_table_button((_invite_code_joinable or saved_session_available) and ready and not _code_check_in_progress)
	if is_instance_valid(_reconnect_seat_button):
		_reconnect_seat_button.visible = false
		_reconnect_seat_button.disabled = true
	if is_instance_valid(_server_connect_button):
		_server_connect_button.text = "Checking..." if _server_check_in_progress else ("Connected" if ready else "Connect")
		_server_connect_button.disabled = false
		_style_server_connect_button(ready)
	if is_instance_valid(_public_tables_panel):
		_public_tables_panel.visible = _home_choice == "online" and not has_table
	if is_instance_valid(_public_tables_refresh_button):
		_public_tables_refresh_button.disabled = not ready
	if is_instance_valid(_public_tables_status_label) and not ready:
		_public_tables_status_label.text = "Connect to a server to see public tables."


func _connect_to_selected_server() -> void:
	var url := _selected_server_url().trim_suffix("/")
	if url == "":
		_status_label.text = "Choose a server first."
		_status_label.visible = true
		return
	if not (url.begins_with("http://") or url.begins_with("https://")):
		_status_label.text = "Server URL must start with http:// or https://."
		_status_label.visible = true
		return
	_mark_server_unconnected()
	_replace_server_check_request()
	_server_check_in_progress = true
	_server_check_target_url = url
	RecipesClient.server_url = url
	_status_label.text = "Checking server..."
	_status_label.visible = true
	_refresh_online_setup_ready_state()
	var err := _server_check_request.request("%s/health" % url)
	if err != OK:
		_server_check_in_progress = false
		_server_check_target_url = ""
		_status_label.text = "The server is not found.\nPlease try another server or Offline Mode."
		_status_label.visible = true
		_refresh_online_setup_ready_state()


func _on_server_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var checked_url := _server_check_target_url
	_server_check_in_progress = false
	_server_check_target_url = ""
	if checked_url != _selected_server_url().trim_suffix("/"):
		_refresh_online_setup_ready_state()
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_status_label.text = _server_request_failure_message(result)
		_status_label.visible = true
		_mark_server_unconnected()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		_status_label.text = "That server did not look like a Recipes server.\nPlease try another server or Offline Mode."
		_status_label.visible = true
		_mark_server_unconnected()
		return
	_server_connected = true
	_connected_server_url = checked_url
	RecipesClient.server_url = _connected_server_url
	_status_label.text = "Server connected. Finding an available invite code..."
	_status_label.visible = true
	_refresh_online_setup_ready_state()
	_request_public_tables()
	_begin_unique_code_generation()


func _server_request_failure_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "The server is not found.\nPlease try another server or Offline Mode."
		_:
			return "The server could not be reached.\nPlease try another server or Offline Mode."


func _reset_invite_code_state() -> void:
	_code_check_in_progress = false
	_code_check_target = ""
	_code_check_for_generation = false
	_code_generation_base = ""
	_code_generation_attempts = 0
	_invite_code_unique = false
	_invite_code_joinable = false
	_invite_code_exists = false


func _on_invite_code_changed() -> void:
	if _suppress_invite_code_check:
		return
	if not _server_is_ready() or _home_choice != "online" or _table_exists(RecipesClient.latest_snapshot):
		return
	_request_invite_code_status(_normalized_invite_code(), false)


func _request_invite_code_status(code: String, for_generation: bool) -> void:
	_invite_code_unique = false
	_invite_code_joinable = false
	_invite_code_exists = false
	_code_check_in_progress = false
	var normalized := code.strip_edges().to_upper().replace(" ", "")
	if not _invite_code_format_is_valid(normalized):
		if normalized == "":
			_status_label.text = "Enter an invite code, or generate one."
		else:
			_status_label.text = "Invite code must be 4-24 letters, numbers, or hyphens."
		_status_label.visible = true
		_refresh_online_setup_ready_state()
		return
	_code_check_in_progress = true
	_code_check_target = normalized
	_code_check_for_generation = for_generation
	_refresh_online_setup_ready_state()
	if _code_check_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_code_check_request.cancel_request()
	var err := _code_check_request.request("%s/tables/%s/status" % [
		_connected_server_url.trim_suffix("/"),
		normalized.uri_encode()
	])
	if err != OK:
		_code_check_in_progress = false
		_status_label.text = "Could not check that invite code. Please try again."
		_status_label.visible = true
		_refresh_online_setup_ready_state()


func _on_code_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var checked_code := _code_check_target
	_code_check_in_progress = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_status_label.text = "Could not check that invite code. Please try again."
		_status_label.visible = true
		_refresh_online_setup_ready_state()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		_status_label.text = "Could not check that invite code. Please try again."
		_status_label.visible = true
		_refresh_online_setup_ready_state()
		return
	var result_body: Dictionary = parsed.get("result", {})
	var code := str(result_body.get("code", checked_code)).to_upper()
	var valid := bool(result_body.get("valid", false))
	var exists := bool(result_body.get("exists", false))
	var joinable := bool(result_body.get("joinable", false))
	if _code_check_for_generation:
		_handle_generated_code_status(code, valid, exists)
		return
	if code != _normalized_invite_code():
		_refresh_online_setup_ready_state()
		return
	_invite_code_exists = exists
	_invite_code_joinable = exists and joinable
	_invite_code_unique = valid and not exists
	var has_saved_session := exists and not _saved_online_session_for_code(code).is_empty()
	if not valid:
		_status_label.text = "Invite code must be 4-24 letters, numbers, or hyphens."
	elif _invite_code_joinable and has_saved_session:
		_status_label.text = "This client profile already has a saved seat for this table. Join Table will reconnect it."
	elif _invite_code_joinable:
		_status_label.text = "Table found. You can join."
	elif has_saved_session:
		_status_label.text = "You have a saved seat for this table. Reconnect to it."
	elif exists:
		_status_label.text = "This Table is full or has already started cooking."
	else:
		_status_label.text = "Invite code is available. You can create a new table."
	_status_label.visible = true
	_refresh_online_setup_ready_state()


func _handle_generated_code_status(code: String, valid: bool, exists: bool) -> void:
	if valid and not exists:
		_suppress_invite_code_check = true
		_code_input.text = code
		_suppress_invite_code_check = false
		_invite_code_exists = false
		_invite_code_joinable = false
		_invite_code_unique = true
		_status_label.text = "Invite code is available. You can create a new table."
		_status_label.visible = true
		_refresh_online_setup_ready_state()
		return
	_code_generation_attempts += 1
	if _code_generation_attempts >= 20:
		_status_label.text = "Could not find a unique invite code. Please type one."
		_status_label.visible = true
		_refresh_online_setup_ready_state()
		return
	var candidate := _code_generation_base + _random_code_character()
	if candidate.length() > 24:
		_code_generation_base = _generate_invite_code()
		candidate = _code_generation_base + _random_code_character()
	_request_invite_code_status(candidate, true)


func _begin_unique_code_generation() -> void:
	if not _server_is_ready():
		_status_label.text = "Connect to a server before generating an invite code."
		_status_label.visible = true
		return
	_code_generation_base = _generate_invite_code()
	_code_generation_attempts = 0
	_request_invite_code_status(_code_generation_base, true)


func _invite_code_format_is_valid(code: String) -> bool:
	if code.length() < 4 or code.length() > 24:
		return false
	for index in range(code.length()):
		var value := code.unicode_at(index)
		var is_digit := value >= 48 and value <= 57
		var is_upper := value >= 65 and value <= 90
		var is_hyphen := value == 45
		if not (is_digit or is_upper or is_hyphen):
			return false
	return true


func _random_code_character() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return alphabet.substr(rng.randi_range(0, alphabet.length() - 1), 1)


func _generate_invite_code() -> String:
	var foods := ["CHEESE", "FLOUR", "HERBS", "VEGGIES", "RICE", "BEANS", "SPICES", "EGGS"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s%s" % [foods[rng.randi_range(0, foods.size() - 1)], rng.randi_range(10, 99)]


func _normalized_invite_code() -> String:
	return _code_input.text.strip_edges().to_upper().replace(" ", "")


func _online_code_needs_generation() -> bool:
	var code := _normalized_invite_code()
	return code == "" or code == "OFFLINE"


func _build_home_sprites() -> void:
	_home_sprites = []
	if not is_instance_valid(_home_sprite_layer):
		return
	var ingredient_ids := ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
	var placements := [
		Vector2(0.16, 0.22),
		Vector2(0.50, 0.14),
		Vector2(0.82, 0.24),
		Vector2(0.28, 0.50),
		Vector2(0.68, 0.48),
		Vector2(0.14, 0.78),
		Vector2(0.50, 0.76),
		Vector2(0.84, 0.78)
	]
	for index in range(ingredient_ids.size()):
		var meta := VisualAssets.ingredient_meta(str(ingredient_ids[index]))
		var texture = meta.get("texture", null)
		var sprite := TextureRect.new()
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.custom_minimum_size = Vector2(86, 86)
		sprite.size = Vector2(86, 86)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if texture is Texture2D:
			sprite.texture = texture
		_home_sprite_layer.add_child(sprite)
		_home_sprites.append({
			"node": sprite,
			"base": placements[index],
			"phase": float(index) * 0.73,
			"speed": 0.62 + float(index % 3) * 0.12,
			"radius": 10.0 + float(index % 4) * 3.0,
			"scale": 1.00 + float(index % 2) * 0.12
		})
	_update_home_sprites(0.0)


func _update_home_sprites(delta: float) -> void:
	if not is_instance_valid(_home_panel) or not _home_panel.visible or not is_instance_valid(_home_sprite_layer):
		return
	_home_animation_time += delta
	var area := _home_sprite_layer.size
	if area.x <= 1.0 or area.y <= 1.0:
		area = Vector2(640, 330)
	for raw in _home_sprites:
		var item: Dictionary = raw
		var node := item.get("node", null) as Control
		if not is_instance_valid(node):
			continue
		var base: Vector2 = item.get("base", Vector2.ZERO)
		var phase := float(item.get("phase", 0.0))
		var speed := float(item.get("speed", 0.7))
		var radius := float(item.get("radius", 12.0))
		var pulse := sin(_home_animation_time * speed + phase)
		var drift := cos(_home_animation_time * (speed * 0.71) + phase)
		var position := Vector2(area.x * base.x, area.y * base.y)
		position += Vector2(pulse * radius, drift * radius * 0.65)
		node.position = position - node.size * 0.5
		var scale_value := float(item.get("scale", 1.0)) * (1.0 + pulse * 0.035)
		node.scale = Vector2(scale_value, scale_value)
		node.rotation = sin(_home_animation_time * speed + phase) * 0.05


func _show_online_setup() -> void:
	_home_choice = "online"
	_mark_server_unconnected()
	if is_instance_valid(_code_input):
		_code_input.text = ""
	_refresh_connection_buttons(RecipesClient.latest_snapshot)
	_status_label.text = "Choose a server, then connect before creating or joining a table."


func _return_to_main_menu() -> void:
	if RecipesClient.table_code != "":
		RecipesClient.disconnect_local()
	_home_choice = ""
	_clear_lobby_edit_state()
	_status_label.text = ""
	_status_label.visible = false
	_summary_label.visible = false
	_participants_area.visible = false
	if is_instance_valid(_table_visual):
		_table_visual.visible = true
	if is_instance_valid(_table_visual_holder):
		_table_visual_holder.visible = false
	if is_instance_valid(_post_table_controls):
		_clear(_post_table_controls)
		_post_table_controls.visible = false
	if is_instance_valid(_confirm_offline_end_dialog):
		_confirm_offline_end_dialog.hide()
	if is_instance_valid(_offline_end_popup):
		_offline_end_popup.hide()
	if is_instance_valid(_history_popup):
		_history_popup.hide()
	_set_lobby_ui_visible(false)
	_set_gameplay_ui_visible(false)
	_refresh_connection_buttons({})


func _home_button(label: String, base_bg: Color, border: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.82))
	button.add_theme_stylebox_override("normal", _home_button_style(base_bg, border, 2))
	button.add_theme_stylebox_override("hover", _home_button_style(base_bg.lightened(0.10), border.lightened(0.08), 3))
	button.add_theme_stylebox_override("pressed", _home_button_style(base_bg.darkened(0.10), border.darkened(0.10), 2))
	button.add_theme_stylebox_override("focus", _home_button_style(base_bg.lightened(0.10), Color(1, 1, 1), 4))
	button.pressed.connect(callback)
	return button


func _home_footer_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.18, 0.13, 0.08))
	button.add_theme_color_override("font_hover_color", Color(0.30, 0.20, 0.10))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.05))
	button.add_theme_stylebox_override("normal", _home_button_style(Color(0.96, 0.89, 0.67), Color(0.42, 0.33, 0.20), 1))
	button.add_theme_stylebox_override("hover", _home_button_style(Color(1.0, 0.93, 0.72), Color(0.54, 0.41, 0.23), 2))
	button.add_theme_stylebox_override("pressed", _home_button_style(Color(0.87, 0.78, 0.55), Color(0.32, 0.25, 0.16), 1))
	button.add_theme_stylebox_override("focus", _home_button_style(Color(1.0, 0.93, 0.72), Color(1, 1, 1), 3))
	button.pressed.connect(callback)
	return button


func _home_logo_button(callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = "Grassroots Economics"
	button.custom_minimum_size = Vector2(280, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _transparent_button_style())
	button.add_theme_stylebox_override("hover", _transparent_button_style())
	button.add_theme_stylebox_override("pressed", _transparent_button_style())
	button.add_theme_stylebox_override("focus", _home_button_style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.85), 3))
	button.pressed.connect(callback)

	var panel := Panel.new()
	panel.name = "GEPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _ge_logo_panel_style())
	button.add_child(panel)

	var logo := TextureRect.new()
	logo.name = "GELogo"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.offset_left = 12
	logo.offset_top = 8
	logo.offset_right = -12
	logo.offset_bottom = -8
	var texture := _get_ge_logo_texture()
	if texture is Texture2D:
		logo.texture = texture
	else:
		button.text = "Grassroots Economics"
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color(0.08, 0.16, 0.1, 1.0))
	button.add_child(logo)
	return button


func _get_ge_logo_texture() -> Texture2D:
	if is_instance_valid(_ge_logo_texture):
		return _ge_logo_texture
	var resource := ResourceLoader.load(GE_LOGO_PATH)
	if not resource is Texture2D:
		return null
	_ge_logo_texture = resource as Texture2D
	return _ge_logo_texture


func _open_grassroots_economics() -> void:
	var error := OS.shell_open(GRASSROOTS_ECONOMICS_URL)
	if error != OK and is_instance_valid(_status_label):
		_status_label.visible = true
		_status_label.text = "Could not open Grassroots Economics."


func _quit_game() -> void:
	get_tree().quit()


func _home_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.86, 0.70)
	style.border_color = Color(0.34, 0.28, 0.19)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style


func _ge_logo_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.97)
	style.border_color = Color(0.88, 0.82, 0.64, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _transparent_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = Color(1, 1, 1, 0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _warm_input_style(bg := Color(0.96, 0.91, 0.75), border := Color(0.52, 0.42, 0.28), border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	return style


func _warm_button_style(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _home_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _section(root: VBoxContainer, title_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(section)
	section.set_meta("title_text", title_text)

	var title := Button.new()
	title.text = title_text
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.flat = false
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.18, 0.12, 0.07))
	title.add_theme_color_override("font_hover_color", Color(0.24, 0.16, 0.08))
	title.add_theme_color_override("font_pressed_color", Color(0.10, 0.07, 0.04))
	title.add_theme_color_override("font_focus_color", Color(0.18, 0.12, 0.07))
	title.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.07, 0.04))
	title.add_theme_color_override("font_disabled_color", Color(0.42, 0.37, 0.29, 0.70))
	title.add_theme_stylebox_override("normal", _warm_button_style(Color(0.93, 0.86, 0.68), Color(0.43, 0.33, 0.20), 1))
	title.add_theme_stylebox_override("hover", _warm_button_style(Color(0.98, 0.91, 0.72), Color(0.52, 0.40, 0.23), 2))
	title.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.84, 0.76, 0.57), Color(0.34, 0.26, 0.17), 1))
	title.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.82, 0.76, 0.61), Color(0.43, 0.33, 0.20), 1))
	title.add_theme_stylebox_override("focus", _warm_button_style(Color(0.98, 0.91, 0.72), Color(1.0, 0.98, 0.84), 3))
	section.add_child(title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(box)
	section.set_meta("header", title)
	title.pressed.connect(func(s := section) -> void:
		_toggle_section_collapsed(s)
	)
	_set_section_collapsed(section, false)
	return section


func _section_controls(section: VBoxContainer) -> VBoxContainer:
	return section.get_child(1) as VBoxContainer


func _toggle_section_collapsed(section: VBoxContainer) -> void:
	var box := _section_controls(section)
	_set_section_collapsed(section, box.visible)


func _set_section_collapsed(section: VBoxContainer, collapsed: bool) -> void:
	if not is_instance_valid(section) or section.get_child_count() < 2:
		return
	var box := _section_controls(section)
	box.visible = not collapsed
	var header: Button = section.get_meta("header")
	var title := str(section.get_meta("title_text", "Section"))
	header.text = "%s %s" % ["+" if collapsed else "-", title]


func _set_section_header_visible(section: VBoxContainer, visible: bool) -> void:
	if not is_instance_valid(section) or section.get_child_count() < 1:
		return
	var header := section.get_child(0) as Control
	if is_instance_valid(header):
		header.visible = visible


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
	label.add_theme_color_override("font_color", Color(0.20, 0.13, 0.07))
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
	input.add_theme_color_override("font_color", Color(0.15, 0.11, 0.07))
	input.add_theme_color_override("font_uneditable_color", Color(0.28, 0.23, 0.16))
	input.add_theme_color_override("font_placeholder_color", Color(0.40, 0.34, 0.25, 0.75))
	input.add_theme_color_override("caret_color", Color(0.25, 0.14, 0.06))
	input.add_theme_stylebox_override("normal", _warm_input_style())
	input.add_theme_stylebox_override("read_only", _warm_input_style(Color(0.84, 0.79, 0.66), Color(0.55, 0.47, 0.34)))
	input.add_theme_stylebox_override("focus", _warm_input_style(Color(1.0, 0.95, 0.78), Color(0.94, 0.57, 0.14), 2))
	return input


func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(112, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
	button.add_theme_color_override("font_hover_color", Color(0.24, 0.16, 0.08))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.07, 0.04))
	button.add_theme_color_override("font_focus_color", Color(0.17, 0.12, 0.07))
	button.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.07, 0.04))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.37, 0.29, 0.70))
	button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.88, 0.80, 0.62), Color(0.47, 0.36, 0.22), 1))
	button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.96, 0.88, 0.67), Color(0.58, 0.42, 0.21), 2))
	button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.78, 0.68, 0.48), Color(0.34, 0.26, 0.17), 1))
	button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.70, 0.66, 0.55), Color(0.54, 0.48, 0.36), 1))
	button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.96, 0.88, 0.67), Color(1.0, 0.98, 0.84), 3))
	button.pressed.connect(callback)
	return button


func _configure_confirmation_dialog(dialog: ConfirmationDialog) -> void:
	_configure_persistent_popup(dialog)
	dialog.get_ok_button().text = "Yes"
	dialog.get_cancel_button().text = "No"
	dialog.add_theme_stylebox_override("panel", _confirmation_panel_style())
	dialog.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
	dialog.add_theme_color_override("title_color", Color(0.24, 0.15, 0.07))
	dialog.add_theme_font_size_override("font_size", 18)

	var label := dialog.call("get_label") as Label if dialog.has_method("get_label") else null
	if is_instance_valid(label):
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))

	_style_confirmation_button(dialog.get_ok_button(), true)
	_style_confirmation_button(dialog.get_cancel_button(), false)


func _configure_persistent_popup(window: Window) -> void:
	if not is_instance_valid(window):
		return
	window.set("popup_window", false)


func _build_offline_end_popup() -> Control:
	var overlay := Control.new()
	overlay.name = "OfflineEndOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.07, 0.04, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "StopCookingPanel"
	panel.custom_minimum_size = Vector2(320, 140)
	panel.add_theme_stylebox_override("panel", _confirmation_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title := Label.new()
	title.text = "Stop cooking?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	box.add_child(title)

	var message := Label.new()
	message.text = "Are you sure?"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 15)
	message.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
	box.add_child(message)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var yes_button := _button("Yes", func() -> void:
		overlay.hide()
		_on_confirm_offline_end_game()
	)
	yes_button.custom_minimum_size = Vector2(108, 34)
	_style_confirmation_button(yes_button, true)
	row.add_child(yes_button)

	var no_button := _button("No", func() -> void:
		overlay.hide()
	)
	no_button.custom_minimum_size = Vector2(108, 34)
	_style_confirmation_button(no_button, false)
	row.add_child(no_button)
	return overlay


func _build_history_popup() -> PopupPanel:
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", _confirmation_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header)

	var title := Label.new()
	title.text = "Successful Transactions"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	header.add_child(title)

	var close_button := _button("Close", func() -> void:
		popup.hide()
	)
	close_button.custom_minimum_size = Vector2(92, 38)
	_style_confirmation_button(close_button, false)
	header.add_child(close_button)

	_history_popup_controls = VBoxContainer.new()
	_history_popup_controls.add_theme_constant_override("separation", 6)
	_history_popup_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_popup_controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_history_popup_controls)
	return popup


func _confirmation_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.86, 0.70)
	style.border_color = Color(0.43, 0.32, 0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _style_confirmation_button(button: Button, primary: bool) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(120, 42)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70) if primary else Color(0.17, 0.12, 0.07))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82) if primary else Color(0.24, 0.16, 0.08))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.58) if primary else Color(0.10, 0.07, 0.04))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.70) if primary else Color(0.17, 0.12, 0.07))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.86, 0.58) if primary else Color(0.10, 0.07, 0.04))
	button.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.03, 0.70) if primary else Color(1.0, 0.94, 0.76, 0.45))
	button.add_theme_constant_override("outline_size", 1 if primary else 0)
	if primary:
		button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.42, 0.22, 0.10), Color(0.92, 0.68, 0.28), 2))
		button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.52, 0.28, 0.13), Color(1.0, 0.78, 0.36), 2))
		button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.30, 0.15, 0.07), Color(0.78, 0.52, 0.20), 2))
		button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.52, 0.28, 0.13), Color(1.0, 0.96, 0.78), 3))
	else:
		button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.88, 0.80, 0.62), Color(0.47, 0.36, 0.22), 1))
		button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.96, 0.88, 0.67), Color(0.58, 0.42, 0.21), 2))
		button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.78, 0.68, 0.48), Color(0.34, 0.26, 0.17), 1))
		button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.96, 0.88, 0.67), Color(1.0, 0.98, 0.84), 3))


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
	option.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
	option.add_theme_color_override("font_hover_color", Color(0.24, 0.16, 0.08))
	option.add_theme_color_override("font_pressed_color", Color(0.10, 0.07, 0.04))
	option.add_theme_color_override("font_focus_color", Color(0.17, 0.12, 0.07))
	option.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.07, 0.04))
	option.add_theme_color_override("font_disabled_color", Color(0.42, 0.37, 0.29, 0.70))
	option.add_theme_stylebox_override("normal", _warm_button_style(Color(0.88, 0.80, 0.62), Color(0.47, 0.36, 0.22), 1))
	option.add_theme_stylebox_override("hover", _warm_button_style(Color(0.96, 0.88, 0.67), Color(0.58, 0.42, 0.21), 2))
	option.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.78, 0.68, 0.48), Color(0.34, 0.26, 0.17), 1))
	option.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.70, 0.66, 0.55), Color(0.54, 0.48, 0.36), 1))
	option.add_theme_stylebox_override("focus", _warm_button_style(Color(0.96, 0.88, 0.67), Color(1.0, 0.98, 0.84), 3))
	return option


func _select_button(label: String, select_key: String) -> Button:
	var button := Button.new()
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(112, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("focus", _control_focus_style())
	button.pressed.connect(func() -> void:
		_toggle_select_popup(select_key, button)
	)
	return button


func _wrapped_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.20, 0.13, 0.07))
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
	row.add_child(_transaction_cell("Turn", 48, true))
	row.add_child(_transaction_cell("Name", 80, true))
	row.add_child(_transaction_cell("Action", 76, true))
	row.add_child(_transaction_cell("Counterparty", 88, true))
	row.add_child(_transaction_cell("Item out", 88, true))
	row.add_child(_transaction_cell("Item back", 88, true))
	return row


func _transaction_row(transaction: Dictionary) -> HBoxContainer:
	var row := _transaction_row_container()
	row.add_child(_transaction_cell(str(transaction.get("turn", "?")), 48))
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
	label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.07))
	if bold:
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
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
		"Pass Turn":
			return Color(0.30, 0.36, 0.46)
		_:
			return Color(0.32, 0.32, 0.32)


func _action_text_color(action: String) -> Color:
	if action == "Exchange":
		return Color(0.08, 0.08, 0.08)
	return Color(1, 1, 1)


func _on_create_pressed() -> void:
	RecipesClient.server_url = _selected_server_url()
	if _current_viewer_is_host():
		_clear_lobby_edit_state()
		RecipesClient.send_host_intent({"type": "reset_table"})
		return
	if _home_choice == "online" and not _server_is_ready():
		_status_label.text = "Connect to a server before creating a table."
		_status_label.visible = true
		return
	if _home_choice == "online" and not _invite_code_unique:
		_status_label.text = "Use an available invite code before creating a table."
		_status_label.visible = true
		return
	var requested_code := _normalized_invite_code()
	if requested_code == "":
		requested_code = _generate_invite_code()
		_code_input.text = requested_code
	_clear_lobby_edit_state()
	RecipesClient.create_table("", "", requested_code)


func _on_join_pressed() -> void:
	RecipesClient.server_url = _selected_server_url()
	if _current_viewer_is_host():
		_confirm_close_table()
		return
	if _home_choice == "online" and not _server_is_ready():
		_status_label.text = "Connect to a server before joining a table."
		_status_label.visible = true
		return
	var code := _normalized_invite_code()
	if code == "":
		_status_label.text = "Enter an invite code to join a table."
		_status_label.visible = true
		return
	if _home_choice == "online" and _has_saved_online_session_for_current_code():
		_resume_saved_online_session(code)
		return
	if RecipesClient.has_table_session(code):
		RecipesClient.connect_socket()
		return
	if _home_choice == "online" and not _invite_code_joinable:
		_status_label.text = "This Table is full or has already started cooking."
		_status_label.visible = true
		return
	_clear_lobby_edit_state()
	RecipesClient.join_table(code, "", bool(_left_table_codes.get(code, false)))


func _on_reconnect_seat_pressed() -> void:
	RecipesClient.server_url = _selected_server_url()
	if _home_choice == "online" and not _server_is_ready():
		_status_label.text = "Connect to a server before reconnecting."
		_status_label.visible = true
		return
	var code := _normalized_invite_code()
	if code == "":
		_status_label.text = "Enter an invite code to reconnect your saved seat."
		_status_label.visible = true
		return
	if not _resume_saved_online_session(code):
		_status_label.text = "No saved seat was found for this table on this client profile."
		_status_label.visible = true
		_refresh_online_setup_ready_state()


func _start_offline_table() -> void:
	_home_choice = "offline"
	_clear_lobby_edit_state()
	_saved_lobby_seat_setup = _load_lobby_seat_setup()
	RecipesClient.start_offline_table(_name_input.text.strip_edges(), _seed_input.text.strip_edges())
	_apply_saved_lobby_setup_to_active_table()


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
	RecipesClient.send_host_intent({"type": "close_table"})


func _confirm_offline_end_game() -> void:
	if RecipesClient.table_code == "":
		return
	if is_instance_valid(_offline_end_popup):
		_offline_end_popup.show()
		_offline_end_popup.move_to_front()
	else:
		_confirm_offline_end_dialog.popup_centered()


func _on_confirm_offline_end_game() -> void:
	_return_to_main_menu()


func _download_transactions_csv() -> void:
	var snapshot := RecipesClient.latest_snapshot
	var transactions: Array = RecipesClient.full_transaction_history()
	if transactions.is_empty():
		_status_label.text = "No transaction history to download."
		return
	var table_code := str(snapshot.get("tableCode", "table")).to_lower()
	var filename := "recipes-transactions-%s.csv" % table_code
	if not RecipesClient.offline_mode and RecipesClient.table_code != "" and RecipesClient.seat_token != "":
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
	lines.append(",".join(["Turn", "Name", "Action", "Counterparty", "Item out", "Item back"]))
	for raw_transaction in transactions:
		var transaction: Dictionary = raw_transaction
		lines.append(",".join([
			_csv_field(transaction.get("turn", "")),
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
	_save_current_online_session(snapshot)
	_sync_lobby_pending_names_with_snapshot(snapshot)
	_render_snapshot(snapshot)
	_maybe_advance_acting_as_after_deposit(snapshot)
	_maybe_follow_controlled_turn(snapshot)
	_track_last_controlled_turn(snapshot)


func _render_snapshot(snapshot: Dictionary) -> void:
	var table_exists := _table_exists(snapshot)
	var game_started := _game_started(snapshot)
	if table_exists and not bool(snapshot.get("offline", false)):
		_code_input.text = str(snapshot.get("tableCode", RecipesClient.table_code))
	elif not table_exists and _home_choice == "online" and _online_code_needs_generation() and _server_is_ready():
		_code_input.text = _generate_invite_code()
	if table_exists:
		_status_label.visible = false
	else:
		_status_label.text = "Choose offline pass-and-play or connect to an online Recipes server."
	_refresh_connection_buttons(snapshot)
	_set_lobby_ui_visible(table_exists)
	_set_gameplay_ui_visible(game_started)
	if is_instance_valid(_table_visual):
		_table_visual.render(snapshot)
	if is_instance_valid(_table_visual_holder):
		_table_visual_holder.visible = game_started
	if is_instance_valid(_table_visual):
		_table_visual.visible = true
		_fit_table_visual_to_window()
		call_deferred("_fit_table_visual_after_layout")
		if game_started:
			call_deferred("_scroll_to_visual_table")
	_summary_label.text = "Table %s\n%s%s. %s active seats. Turn %s.\nMode: %s\nWinners: %s" % [
		snapshot.get("tableCode", ""),
		_phase_label(str(snapshot.get("phase", "unknown"))),
		" - paused" if bool(snapshot.get("paused", false)) else "",
		_active_count(snapshot),
		int(snapshot.get("turn", 0)),
		str(snapshot.get("turnMode", "round_robin")).replace("_", " ").capitalize(),
		_winners_label(snapshot.get("winners", []))
	]
	_refresh_participants(snapshot)
	_update_platter_summary_label(snapshot)
	_hand_label.text = "Your inventory:\n%s" % _format_inventory_assets(snapshot)
	_apply_default_section_collapse(snapshot)
	_refresh_controls(snapshot)
	_refresh_post_table_controls(snapshot)
	_refresh_history_popup_if_open(snapshot)
	_refresh_active_select_popup(snapshot)


func _update_platter_summary_label(snapshot: Dictionary) -> void:
	_platter_label.visible = false


func _on_error_received(error: Dictionary) -> void:
	var description := str(error.get("description", JSON.stringify(error)))
	var error_code := str(error.get("errorCode", ""))
	var show_plain_message := false
	if error_code == "invalid_seat_token":
		_forget_online_session(RecipesClient.server_url, RecipesClient.table_code, RecipesClient.seat_token)
	elif error_code == "missing_table":
		_forget_online_session(RecipesClient.server_url, RecipesClient.table_code)
	elif error_code == "seat_already_connected":
		_ignore_online_session_for_process(RecipesClient.server_url, RecipesClient.table_code)
		RecipesClient.disconnect_local()
		description = "Your saved seat is already open in another client. You can join this table as another player."
		show_plain_message = true
	_status_label.text = description if show_plain_message or description.begins_with("The server") else "Error: %s" % description
	_status_label.visible = true
	_summary_label.text = "Last error: %s" % description
	_refresh_online_setup_ready_state()


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
			if is_instance_valid(_table_visual):
				_table_visual.visible = true
			if is_instance_valid(_table_visual_holder):
				_table_visual_holder.visible = false
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
	return bool(snapshot.get("viewerCanUseHostControls", false))


func _refresh_connection_buttons(snapshot: Dictionary) -> void:
	var has_table := _table_exists(snapshot)
	var is_host := has_table and bool(snapshot.get("viewerCanUseHostControls", false))
	var game_started := _game_started(snapshot)
	var is_offline := bool(snapshot.get("offline", false)) or RecipesClient.offline_mode
	_apply_layout_density(has_table, game_started)

	if is_instance_valid(_home_panel):
		_home_panel.visible = not has_table and _home_choice == ""
	if is_instance_valid(_online_setup_panel):
		_online_setup_panel.visible = _home_choice == "online" and not has_table
	if is_instance_valid(_status_label):
		_status_label.visible = _home_choice == "online" and not has_table
	if is_instance_valid(_main_menu_button):
		_main_menu_button.visible = (_home_choice != "" or has_table) and not game_started
		_main_menu_button.custom_minimum_size = Vector2(112, 34 if has_table and not game_started else 44)
	if is_instance_valid(_main_menu_spacer):
		_main_menu_spacer.visible = is_instance_valid(_main_menu_button) and _main_menu_button.visible and not (has_table and not game_started)

	_offline_table_button.visible = not has_table
	_create_table_button.visible = not has_table or is_host
	_join_table_button.visible = not has_table or is_host
	if is_instance_valid(_reconnect_seat_button):
		_reconnect_seat_button.visible = false
		_reconnect_seat_button.disabled = true
	_leave_table_button.visible = has_table and not is_host

	if is_host:
		_create_table_button.text = "Start New Table"
		_join_table_button.text = "Close Table"
	elif has_table and not RecipesClient.is_socket_connected():
		_create_table_button.text = "Create Table"
		_join_table_button.text = "Join Table"
		_leave_table_button.text = "Reconnect"
	else:
		_create_table_button.text = "Create Table"
		_join_table_button.text = "Join Table"
		_leave_table_button.text = "Leave Table"

	_offline_table_button.disabled = false
	var online_requires_server := _home_choice == "online" and not has_table
	_create_table_button.disabled = online_requires_server and not _server_is_ready()
	_join_table_button.disabled = online_requires_server and not _server_is_ready()
	_leave_table_button.disabled = false
	_refresh_online_setup_ready_state()


func _apply_layout_density(compact_table: bool, game_started := false) -> void:
	var horizontal_margin := 2 if game_started else (8 if compact_table else 20)
	var vertical_margin := 4 if compact_table else 16
	if is_instance_valid(_root_margin):
		_root_margin.add_theme_constant_override("margin_left", horizontal_margin)
		_root_margin.add_theme_constant_override("margin_top", vertical_margin)
		_root_margin.add_theme_constant_override("margin_right", horizontal_margin)
		_root_margin.add_theme_constant_override("margin_bottom", 4 if compact_table else 24)
	if is_instance_valid(_root_container):
		_root_container.add_theme_constant_override("separation", 4 if compact_table else 12)
	if is_instance_valid(_table_section):
		_table_section.add_theme_constant_override("separation", 1 if compact_table else 6)
	if is_instance_valid(_phase_controls):
		_phase_controls.add_theme_constant_override("separation", 2 if compact_table else 6)
	if is_instance_valid(_root_scroll):
		_root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if game_started else (ScrollContainer.SCROLL_MODE_DISABLED if compact_table else ScrollContainer.SCROLL_MODE_AUTO)
		if game_started:
			_root_scroll.scroll_vertical = 0


func _set_lobby_ui_visible(visible: bool) -> void:
	var game_started := _game_started(RecipesClient.latest_snapshot)
	_summary_label.visible = false
	_participants_area.visible = false
	_table_section.visible = visible and not game_started
	_table_section.size_flags_vertical = Control.SIZE_EXPAND_FILL if visible and not game_started else Control.SIZE_SHRINK_BEGIN
	_phase_controls.size_flags_vertical = Control.SIZE_EXPAND_FILL if visible and not game_started else Control.SIZE_SHRINK_BEGIN
	_set_section_header_visible(_table_section, false)
	if visible and not game_started:
		_set_section_collapsed(_table_section, false)


func _set_gameplay_ui_visible(visible: bool) -> void:
	_hand_section.visible = false
	_recipe_section.visible = false
	_platter_section.visible = false
	_offer_section.visible = false
	_dish_section.visible = false
	_transaction_section.visible = false
	_platter_label.visible = false
	_hand_label.visible = false


func _refresh_post_table_controls(snapshot: Dictionary) -> void:
	if not is_instance_valid(_post_table_controls):
		return
	_clear(_post_table_controls)
	_post_table_controls.visible = false


func _scroll_to_visual_table() -> void:
	if not is_instance_valid(_root_scroll) or not is_instance_valid(_table_visual_holder) or not _table_visual_holder.visible:
		return
	if _game_started(RecipesClient.latest_snapshot):
		_root_scroll.scroll_vertical = 0
		return
	_root_scroll.scroll_vertical = maxi(0, int(_table_visual_holder.position.y) - 12)


func _fit_table_visual_to_window() -> void:
	if not is_instance_valid(_table_visual_holder) or not is_instance_valid(_table_visual):
		return
	var design_size := _table_visual.get_combined_minimum_size()
	if _table_visual.has_method("preferred_visual_size"):
		var preferred = _table_visual.call("preferred_visual_size")
		if preferred is Vector2:
			design_size = preferred
	if design_size.x <= 1.0 or design_size.y <= 1.0:
		design_size = Vector2(616, 808)
	var available_width := _table_visual_holder.size.x
	if available_width <= 1.0:
		available_width = get_viewport_rect().size.x
		if is_instance_valid(_root_margin):
			available_width -= float(_root_margin.get_theme_constant("margin_left") + _root_margin.get_theme_constant("margin_right"))
	available_width = maxf(1.0, available_width)
	var scale_value := minf(1.0, available_width / design_size.x)
	if _game_started(RecipesClient.latest_snapshot):
		var available_height := get_viewport_rect().size.y
		if is_instance_valid(_root_margin):
			available_height -= float(_root_margin.get_theme_constant("margin_top") + _root_margin.get_theme_constant("margin_bottom"))
		available_height -= TABLE_VISUAL_BOTTOM_SAFE_MARGIN
		available_height = maxf(1.0, available_height)
		scale_value = minf(scale_value, available_height / design_size.y)
	scale_value = maxf(0.45, scale_value)
	var scaled_size := design_size * scale_value
	_table_visual.size = design_size
	_table_visual.scale = Vector2(scale_value, scale_value)
	_table_visual.position = Vector2(maxf(0.0, (available_width - scaled_size.x) * 0.5), 0.0)
	_table_visual_holder.custom_minimum_size = Vector2(0, ceil(scaled_size.y))
	_table_visual_holder.size.y = ceil(scaled_size.y)


func _fit_table_visual_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_fit_table_visual_to_window()


func _apply_default_section_collapse(snapshot: Dictionary) -> void:
	if not _table_exists(snapshot):
		_collapsed_gameplay_for_table = ""
		return
	var code := str(snapshot.get("tableCode", ""))
	if not _game_started(snapshot):
		_collapsed_gameplay_for_table = ""
		_set_section_header_visible(_table_section, false)
		_set_section_collapsed(_table_section, false)
		return
	_set_section_header_visible(_table_section, false)
	_set_section_collapsed(_table_section, false)
	if _collapsed_gameplay_for_table == code:
		return
	for section in [_transaction_section]:
		_set_section_collapsed(section, true)
	_collapsed_gameplay_for_table = code


func _on_table_visual_intent_requested(intent: Dictionary) -> void:
	if str(intent.get("type", "")) == "deposit" or str(intent.get("type", "")) == "deposit_ingredient":
		_pending_controlled_deposit_actor_id = str(RecipesClient.latest_snapshot.get("viewerParticipantId", ""))
	RecipesClient.send_intent(intent)


func _on_table_visual_view_requested(participant_id: String) -> void:
	RecipesClient.view_as(participant_id)


func _on_table_visual_status_requested(message: String) -> void:
	_status_label.text = message


func _on_table_visual_menu_requested(action: String) -> void:
	match action:
		"View History":
			_open_history_popup()
		"Main Menu":
			_return_to_main_menu()
		"End Game":
			if bool(RecipesClient.latest_snapshot.get("offline", false)) or RecipesClient.offline_mode:
				_confirm_offline_end_game()
			else:
				RecipesClient.send_host_intent({"type": "stop"})


func _open_history_popup() -> void:
	if not is_instance_valid(_history_popup) or not is_instance_valid(_history_popup_controls):
		return
	var viewport_size := get_viewport_rect().size
	var max_popup_width := maxi(1, int(viewport_size.x) - 36)
	var max_popup_height := maxi(1, int(viewport_size.y) - 84)
	var popup_size := Vector2i(
		mini(mini(660, int(viewport_size.x * 0.90)), max_popup_width),
		mini(mini(520, int(viewport_size.y * 0.58)), max_popup_height)
	)
	_history_popup_visible_rows = _history_popup_row_count_for_size(popup_size)
	_refresh_history_popup(RecipesClient.latest_snapshot)
	_history_popup.popup_centered(popup_size)


func _history_popup_row_count_for_size(popup_size: Vector2i) -> int:
	var fixed_height := 260
	var available_rows_height := maxi(0, popup_size.y - fixed_height)
	var row_stride := TRANSACTION_ROW_HEIGHT + TRANSACTION_ROW_GAP
	var rows := int(floor(float(available_rows_height) / float(row_stride)))
	return clampi(rows, 1, TRANSACTION_POPUP_MAX_ROWS)


func _refresh_history_popup(snapshot: Dictionary) -> void:
	if not is_instance_valid(_history_popup_controls):
		return
	_clear(_history_popup_controls)
	_add_transaction_history_controls(snapshot, _history_popup_controls, _history_popup_visible_rows)


func _refresh_history_popup_if_open(snapshot: Dictionary) -> void:
	if is_instance_valid(_history_popup) and _history_popup.visible:
		_refresh_history_popup(snapshot)


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
	_refresh_acting_as(snapshot)


func _refresh_acting_as(snapshot: Dictionary) -> void:
	if not is_instance_valid(_acting_as_option):
		return
	_acting_as_option.clear()
	var connection_id := str(snapshot.get("connectionParticipantId", snapshot.get("viewerParticipantId", "")))
	var controlled_ids: Array = snapshot.get("controlledParticipantIds", [])
	var available_ids: Array[String] = []
	if connection_id != "":
		available_ids.append(connection_id)
	for raw_id in controlled_ids:
		var controlled_id := str(raw_id)
		if controlled_id != "" and not available_ids.has(controlled_id):
			available_ids.append(controlled_id)
	_acting_as_option.visible = available_ids.size() > 1
	if available_ids.size() <= 1:
		return
	var viewer_id := str(snapshot.get("viewerParticipantId", connection_id))
	for participant_id in available_ids:
		var participant := _participant_by_id(snapshot, participant_id)
		if participant.is_empty():
			continue
		var item_index := _acting_as_option.item_count
		var prefix := "Acting as "
		if participant_id == connection_id:
			prefix = "Acting as self: "
		_acting_as_option.add_item("%s%s" % [prefix, participant.get("name", "Player")])
		_acting_as_option.set_item_metadata(item_index, participant_id)
		if participant_id == viewer_id:
			_acting_as_option.select(item_index)


func _on_acting_as_selected(index: int) -> void:
	var participant_id := str(_acting_as_option.get_item_metadata(index))
	if participant_id == "":
		return
	RecipesClient.view_as(participant_id)


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
	if bool(snapshot.get("viewerCanUseHostControls", false)):
		_add_host_admin_controls(snapshot)
	if _game_started(snapshot):
		_phase_controls.add_child(_wrapped_label(_turn_status_label(snapshot)))
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
	elif _round_robin_waiting(snapshot):
		_add_read_only_turn_view(snapshot)
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
	if _is_online_snapshot(snapshot):
		_add_online_lobby_invite_controls(snapshot)
	_phase_controls.add_child(_lobby_title("Who's Cooking?"))

	var host_controls := bool(snapshot.get("viewerCanUseHostControls", false))
	if not host_controls:
		if _is_online_snapshot(snapshot):
			_phase_controls.add_child(_lobby_waiting_on_host_label())
		_add_seat_setup_grid(snapshot, false)
		if _is_online_snapshot(snapshot):
			_add_lobby_footer_spacer()
			_add_back_to_online_setup_button()
		return

	_add_seat_setup_grid(snapshot, true)

	var compact := _is_compact_lobby()
	var start_button := _button("Start Cooking", func() -> void:
		_commit_lobby_seat_setup_edits()
		RecipesClient.send_host_intent({"type": "start"})
	)
	start_button.disabled = active_count != REQUIRED_ACTIVE_SEATS
	start_button.text = "Start Cooking" if active_count == REQUIRED_ACTIVE_SEATS else "Waiting for %s Seats" % (REQUIRED_ACTIVE_SEATS - active_count)
	start_button.custom_minimum_size = Vector2(112, 36 if compact else 48)
	_style_start_cooking_button(start_button)
	_phase_controls.add_child(start_button)
	if _is_online_snapshot(snapshot):
		_add_back_to_online_setup_button()


func _is_online_snapshot(snapshot: Dictionary) -> bool:
	return _table_exists(snapshot) and not bool(snapshot.get("offline", false)) and not RecipesClient.offline_mode


func _add_online_lobby_invite_controls(snapshot: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _seat_setup_row_style(false, _is_compact_lobby()))
	_phase_controls.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2 if _is_compact_lobby() else 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var server_label := _wrapped_label("Server: %s" % RecipesClient.server_url)
	server_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _is_compact_lobby():
		server_label.add_theme_font_size_override("font_size", 13)
	box.add_child(server_label)

	var code_label := _wrapped_label("Invite Code: %s" % str(snapshot.get("tableCode", RecipesClient.table_code)))
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _is_compact_lobby():
		code_label.add_theme_font_size_override("font_size", 13)
	box.add_child(code_label)

	var invite_button := _button("Invite Others", func(snap := snapshot) -> void:
		_invite_others(snap)
	)
	invite_button.custom_minimum_size = Vector2(112, 30 if _is_compact_lobby() else 44)
	box.add_child(invite_button)

	if bool(snapshot.get("viewerCanUseHostControls", false)) and str(snapshot.get("phase", "")) == "lobby":
		var is_public := bool(snapshot.get("isPublic", true))
		var visibility_button := _button("Public Table" if is_public else "Private Table", func(public_now := is_public) -> void:
			RecipesClient.send_host_intent({"type": "set_table_visibility", "isPublic": not public_now})
		)
		visibility_button.custom_minimum_size = Vector2(112, 30 if _is_compact_lobby() else 44)
		if is_public:
			visibility_button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.74, 0.91, 0.58), Color(0.34, 0.48, 0.20), 1))
			visibility_button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.82, 0.98, 0.64), Color(0.40, 0.56, 0.24), 2))
		else:
			visibility_button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.78, 0.70, 0.56), Color(0.47, 0.36, 0.22), 1))
			visibility_button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.86, 0.78, 0.62), Color(0.58, 0.42, 0.21), 2))
		box.add_child(visibility_button)


func _add_back_to_online_setup_button() -> void:
	var back_button := _button("Back to Create/Join Table", _back_to_online_setup)
	back_button.custom_minimum_size = Vector2(112, 34 if _is_compact_lobby() else 44)
	_phase_controls.add_child(back_button)


func _add_lobby_footer_spacer() -> void:
	var spacer := Control.new()
	spacer.name = "LobbyFooterSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 8)
	_phase_controls.add_child(spacer)


func _lobby_waiting_on_host_label() -> Label:
	var compact := _is_compact_lobby()
	var label := Label.new()
	label.text = "Waiting on Host to Start the Game."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 42 if compact else 64)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 24 if compact else 32)
	label.add_theme_color_override("font_color", Color(0.26, 0.14, 0.06))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.91, 0.68, 0.90))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _back_to_online_setup() -> void:
	RecipesClient.disconnect_local()
	_home_choice = "online"
	_mark_server_unconnected()
	if is_instance_valid(_code_input):
		_code_input.text = ""
	_status_label.text = "Choose a server, then connect before creating or joining a table."
	_refresh_connection_buttons({})


func _invite_others(snapshot: Dictionary) -> void:
	var message := "\n".join([
		"Let's Cook some Recipes!",
		"Client: %s" % CLIENT_INVITE_URL,
		"Server: %s" % RecipesClient.server_url,
		"Invite Code: %s" % str(snapshot.get("tableCode", RecipesClient.table_code))
	])
	if OS.get_name() == "Web":
		var script := "\n".join([
			"const text = %s;" % JSON.stringify(message),
			"if (navigator.share) {",
			"  navigator.share({ text });",
			"} else if (navigator.clipboard) {",
			"  navigator.clipboard.writeText(text);",
			"}"
		])
		JavaScriptBridge.eval(script, true)
		_status_label.text = "Invite text shared or copied."
	else:
		DisplayServer.clipboard_set(message)
		_status_label.text = "Invite text copied to clipboard."
	_status_label.visible = true


func _is_compact_lobby() -> bool:
	var snapshot := RecipesClient.latest_snapshot
	return (_table_exists(snapshot) and not _game_started(snapshot)) or get_viewport_rect().size.y <= 900.0


func _lobby_title(text: String) -> Label:
	var compact := _is_compact_lobby()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 24 if compact else 56)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20 if compact else 34)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.70, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _style_start_cooking_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 18 if _is_compact_lobby() else 24)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.58))
	button.add_theme_color_override("font_disabled_color", Color(0.76, 0.68, 0.52, 0.75))
	button.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.03, 0.80))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.42, 0.22, 0.10), Color(0.92, 0.68, 0.28), 2))
	button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.52, 0.28, 0.13), Color(1.0, 0.78, 0.36), 2))
	button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.30, 0.15, 0.07), Color(0.78, 0.52, 0.20), 2))
	button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.58, 0.50, 0.38), Color(0.48, 0.40, 0.29), 1))
	button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.52, 0.28, 0.13), Color(1.0, 0.96, 0.78), 3))


func _style_server_connect_button(connected: bool) -> void:
	if not is_instance_valid(_server_connect_button):
		return
	if connected:
		_server_connect_button.add_theme_color_override("font_color", Color(0.17, 0.11, 0.05))
		_server_connect_button.add_theme_color_override("font_hover_color", Color(0.17, 0.11, 0.05))
		_server_connect_button.add_theme_color_override("font_pressed_color", Color(0.17, 0.11, 0.05))
		_server_connect_button.add_theme_color_override("font_focus_color", Color(0.17, 0.11, 0.05))
		_server_connect_button.add_theme_color_override("font_hover_pressed_color", Color(0.17, 0.11, 0.05))
		_server_connect_button.add_theme_color_override("font_disabled_color", Color(0.25, 0.18, 0.10, 0.82))
		_server_connect_button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.98, 0.86, 0.54), Color(0.58, 0.40, 0.18), 2))
		_server_connect_button.add_theme_stylebox_override("hover", _warm_button_style(Color(1.0, 0.90, 0.60), Color(0.66, 0.46, 0.20), 2))
		_server_connect_button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.91, 0.76, 0.42), Color(0.44, 0.29, 0.12), 2))
		_server_connect_button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.90, 0.78, 0.50), Color(0.55, 0.42, 0.23), 1))
		_server_connect_button.add_theme_stylebox_override("focus", _warm_button_style(Color(1.0, 0.90, 0.60), Color(0.48, 0.32, 0.14), 3))
	else:
		_server_connect_button.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
		_server_connect_button.add_theme_color_override("font_hover_color", Color(0.24, 0.16, 0.08))
		_server_connect_button.add_theme_color_override("font_pressed_color", Color(0.10, 0.07, 0.04))
		_server_connect_button.add_theme_color_override("font_focus_color", Color(0.17, 0.12, 0.07))
		_server_connect_button.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.07, 0.04))
		_server_connect_button.add_theme_color_override("font_disabled_color", Color(0.42, 0.37, 0.29, 0.70))
		_server_connect_button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.88, 0.80, 0.62), Color(0.47, 0.36, 0.22), 1))
		_server_connect_button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.96, 0.88, 0.67), Color(0.58, 0.42, 0.21), 2))
		_server_connect_button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.78, 0.68, 0.48), Color(0.34, 0.26, 0.17), 1))
		_server_connect_button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.70, 0.66, 0.55), Color(0.54, 0.48, 0.36), 1))
		_server_connect_button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.96, 0.88, 0.67), Color(1.0, 0.98, 0.84), 3))


func _style_join_table_button(join_ready: bool) -> void:
	_style_join_like_button(_join_table_button, join_ready)


func _style_reconnect_seat_button(reconnect_ready: bool) -> void:
	_style_join_like_button(_reconnect_seat_button, reconnect_ready)


func _style_join_like_button(button: Button, join_ready: bool) -> void:
	if not is_instance_valid(button):
		return
	if join_ready:
		button.add_theme_color_override("font_color", Color(0.08, 0.20, 0.08))
		button.add_theme_color_override("font_hover_color", Color(0.08, 0.20, 0.08))
		button.add_theme_color_override("font_pressed_color", Color(0.05, 0.16, 0.05))
		button.add_theme_color_override("font_focus_color", Color(0.08, 0.20, 0.08))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.16, 0.05))
		button.add_theme_color_override("font_disabled_color", Color(0.20, 0.28, 0.16, 0.75))
		button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.64, 0.91, 0.43), Color(1.0, 0.98, 0.62), 3))
		button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.72, 0.98, 0.50), Color(1.0, 1.0, 0.76), 4))
		button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.52, 0.78, 0.33), Color(0.84, 0.78, 0.36), 3))
		button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.74, 0.82, 0.61), Color(0.50, 0.55, 0.36), 1))
		button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.72, 0.98, 0.50), Color(1.0, 1.0, 0.90), 4))
	else:
		button.add_theme_color_override("font_color", Color(0.17, 0.12, 0.07))
		button.add_theme_color_override("font_hover_color", Color(0.24, 0.16, 0.08))
		button.add_theme_color_override("font_pressed_color", Color(0.10, 0.07, 0.04))
		button.add_theme_color_override("font_focus_color", Color(0.17, 0.12, 0.07))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.07, 0.04))
		button.add_theme_color_override("font_disabled_color", Color(0.42, 0.37, 0.29, 0.70))
		button.add_theme_stylebox_override("normal", _warm_button_style(Color(0.88, 0.80, 0.62), Color(0.47, 0.36, 0.22), 1))
		button.add_theme_stylebox_override("hover", _warm_button_style(Color(0.96, 0.88, 0.67), Color(0.58, 0.42, 0.21), 2))
		button.add_theme_stylebox_override("pressed", _warm_button_style(Color(0.78, 0.68, 0.48), Color(0.34, 0.26, 0.17), 1))
		button.add_theme_stylebox_override("disabled", _warm_button_style(Color(0.70, 0.66, 0.55), Color(0.54, 0.48, 0.36), 1))
		button.add_theme_stylebox_override("focus", _warm_button_style(Color(0.96, 0.88, 0.67), Color(1.0, 0.98, 0.84), 3))


func _add_seat_setup_grid(snapshot: Dictionary, host_editable: bool) -> void:
	_lobby_seat_name_inputs.clear()
	_lobby_seat_kind_inputs.clear()
	var grid := _seat_grid_container()
	_phase_controls.add_child(grid)
	var participants: Array = snapshot.get("participants", [])
	var connection_participant_id := str(snapshot.get("connectionParticipantId", snapshot.get("viewerParticipantId", "")))
	var seat_index := 0
	for raw_participant in participants:
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		var can_edit_name := host_editable or (participant_id == connection_participant_id and str(participant.get("kind", "")) == "human")
		grid.add_child(_seat_setup_row(snapshot, participant, seat_index, can_edit_name, host_editable))
		seat_index += 1


func _seat_grid_container() -> GridContainer:
	var grid := GridContainer.new()
	var compact := _is_compact_lobby()
	grid.columns = 2 if _use_two_column_lobby_seats() else 1
	grid.add_theme_constant_override("h_separation", 8 if compact else 10)
	grid.add_theme_constant_override("v_separation", 4 if compact else 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


func _use_two_column_lobby_seats() -> bool:
	return _is_compact_lobby() and get_viewport_rect().size.x >= 980.0


func _seat_setup_row(snapshot: Dictionary, participant: Dictionary, seat_index: int, name_editable: bool, kind_editable: bool) -> PanelContainer:
	var compact := _is_compact_lobby()
	var participant_id := str(participant.get("id", ""))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 54 if compact else 78)
	panel.add_theme_stylebox_override("panel", _seat_setup_row_style(str(participant.get("kind", "")) == "bot", compact))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6 if compact else 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var ingredient_id := _seat_ingredient_id(snapshot, participant, seat_index)
	var icon_box := VBoxContainer.new()
	icon_box.custom_minimum_size = Vector2(78, 48) if compact else Vector2(108, 70)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_constant_override("separation", 0)
	row.add_child(icon_box)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(62, 35) if compact else Vector2(82, 50)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	var texture = meta.get("texture", null)
	if texture is Texture2D:
		texture_rect.texture = texture
	icon_box.add_child(texture_rect)

	var ingredient_label := Label.new()
	ingredient_label.text = _ingredient_display(snapshot, ingredient_id)
	ingredient_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ingredient_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ingredient_label.custom_minimum_size = Vector2(0, 13 if compact else 18)
	ingredient_label.add_theme_font_size_override("font_size", 10 if compact else 14)
	ingredient_label.add_theme_color_override("font_color", Color(0.20, 0.13, 0.07))
	ingredient_label.add_theme_color_override("font_outline_color", Color(1.0, 0.93, 0.72, 0.70))
	ingredient_label.add_theme_constant_override("outline_size", 1)
	icon_box.add_child(ingredient_label)

	var displayed_name := str(participant.get("name", ""))
	if _lobby_pending_seat_names.has(participant_id):
		displayed_name = str(_lobby_pending_seat_names.get(participant_id, displayed_name))
	var name_input := _line_edit("Seat name", displayed_name)
	name_input.custom_minimum_size = Vector2(130, 38) if compact else Vector2(180, 50)
	name_input.editable = name_editable
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact:
		name_input.add_theme_font_size_override("font_size", 18)
	row.add_child(name_input)

	var kind_toggle := _option_button()
	kind_toggle.custom_minimum_size = Vector2(86, 38) if compact else Vector2(112, 50)
	kind_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	if compact:
		kind_toggle.add_theme_font_size_override("font_size", 17)
	kind_toggle.add_item("Player")
	kind_toggle.add_item("Bot")
	var is_bot := str(participant.get("kind", "human")) == "bot"
	kind_toggle.select(1 if is_bot else 0)
	kind_toggle.disabled = not kind_editable or bool(participant.get("isHost", false))
	row.add_child(kind_toggle)

	_lobby_seat_name_inputs[participant_id] = name_input
	_lobby_seat_kind_inputs[participant_id] = kind_toggle
	name_input.text_changed.connect(func(text: String, target_id := participant_id) -> void:
		_remember_lobby_seat_name_edit(target_id, text)
		_save_lobby_seat_setup_from_inputs()
		_schedule_lobby_name_publish()
	)
	name_input.text_submitted.connect(func(_submitted: String, target_id := participant_id, input := name_input) -> void:
		_rename_lobby_seat(target_id, input)
		_save_lobby_seat_setup_from_inputs()
	)
	name_input.focus_exited.connect(func(target_id := participant_id, input := name_input) -> void:
		_remember_lobby_seat_name_edit(target_id, input.text)
		_save_lobby_seat_setup_from_inputs()
		_flush_pending_lobby_name_edits()
	)
	kind_toggle.item_selected.connect(func(index: int, target_id := participant_id, input := name_input) -> void:
		_save_lobby_seat_setup_from_inputs()
		_change_lobby_seat_kind(target_id, index, input)
	)
	return panel


func _seat_setup_row_style(is_bot: bool, compact := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.90, 0.80, 0.84) if is_bot else Color(0.88, 0.94, 0.84, 0.92)
	style.border_color = Color(0.43, 0.39, 0.30, 0.55)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 3 if compact else 8
	style.content_margin_top = 1 if compact else 6
	style.content_margin_right = 3 if compact else 8
	style.content_margin_bottom = 1 if compact else 6
	return style


func _seat_ingredient_id(snapshot: Dictionary, participant: Dictionary, seat_index: int) -> String:
	var assigned := str(participant.get("ingredientId", ""))
	if assigned != "":
		return assigned
	var ingredients: Array = snapshot.get("ingredients", [])
	if seat_index >= 0 and seat_index < ingredients.size():
		var ingredient: Dictionary = ingredients[seat_index]
		return str(ingredient.get("id", ""))
	return ""


func _rename_lobby_seat(participant_id: String, input: LineEdit) -> void:
	var name := input.text.strip_edges()
	if participant_id == "":
		return
	var participant := _participant_by_id(RecipesClient.latest_snapshot, participant_id)
	if not participant.is_empty() and name == str(participant.get("name", "")).strip_edges():
		_lobby_pending_seat_names.erase(participant_id)
		return
	if _send_lobby_edit_intent({"type": "rename_participant", "participantId": participant_id, "name": name}):
		_lobby_pending_seat_names.erase(participant_id)


func _remember_lobby_seat_name_edit(participant_id: String, name: String) -> void:
	if participant_id == "":
		return
	var participant := _participant_by_id(RecipesClient.latest_snapshot, participant_id)
	var trimmed := name.strip_edges()
	if not participant.is_empty() and trimmed == str(participant.get("name", "")).strip_edges():
		_lobby_pending_seat_names.erase(participant_id)
	else:
		_lobby_pending_seat_names[participant_id] = name


func _publish_lobby_seat_name_edit(participant_id: String, name: String) -> void:
	if participant_id == "":
		return
	var trimmed := name.strip_edges()
	if trimmed == "":
		return
	var participant := _participant_by_id(RecipesClient.latest_snapshot, participant_id)
	if not participant.is_empty() and trimmed == str(participant.get("name", "")).strip_edges():
		_lobby_pending_seat_names.erase(participant_id)
		return
	if _send_lobby_edit_intent({"type": "rename_participant", "participantId": participant_id, "name": trimmed}):
		_lobby_pending_seat_names.erase(participant_id)


func _schedule_lobby_name_publish() -> void:
	if is_instance_valid(_lobby_name_publish_timer):
		_lobby_name_publish_timer.start(LOBBY_NAME_PUBLISH_DELAY_SECONDS)


func _flush_pending_lobby_name_edits() -> void:
	if is_instance_valid(_lobby_name_publish_timer):
		_lobby_name_publish_timer.stop()
	var participant_ids := _lobby_pending_seat_names.keys()
	for raw_participant_id in participant_ids:
		var participant_id := str(raw_participant_id)
		if not _lobby_pending_seat_names.has(participant_id):
			continue
		var name := str(_lobby_pending_seat_names.get(participant_id, ""))
		_publish_lobby_seat_name_edit(participant_id, name)


func _sync_lobby_pending_names_with_snapshot(snapshot: Dictionary) -> void:
	for raw_participant_id in _lobby_pending_seat_names.keys():
		var participant_id := str(raw_participant_id)
		var participant := _participant_by_id(snapshot, participant_id)
		if participant.is_empty():
			_lobby_pending_seat_names.erase(participant_id)
			continue
		var pending := str(_lobby_pending_seat_names.get(participant_id, "")).strip_edges()
		var current := str(participant.get("name", "")).strip_edges()
		if pending == current:
			_lobby_pending_seat_names.erase(participant_id)
			continue
		var input := _lobby_seat_name_inputs.get(participant_id, null) as LineEdit
		if input == null or not is_instance_valid(input) or not input.has_focus():
			_lobby_pending_seat_names.erase(participant_id)


func _active_lobby_participants(snapshot: Dictionary) -> Array:
	var active: Array = []
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) == "active":
			active.append(participant)
	return active


func _capture_lobby_seat_setup_edits() -> Array:
	var edits: Array = []
	var snapshot := RecipesClient.latest_snapshot
	var participants := _active_lobby_participants(snapshot)
	for seat_index in range(participants.size()):
		var participant: Dictionary = participants[seat_index]
		var participant_id := str(participant.get("id", ""))
		if participant_id == "":
			continue
		var input := _lobby_seat_name_inputs.get(participant_id, null) as LineEdit
		var toggle := _lobby_seat_kind_inputs.get(participant_id, null) as OptionButton
		var name := str(participant.get("name", "")).strip_edges()
		if input != null and is_instance_valid(input):
			name = input.text.strip_edges()
		var kind := "bot" if str(participant.get("kind", "human")) == "bot" else "player"
		if toggle != null and is_instance_valid(toggle):
			kind = "bot" if toggle.selected == 1 else "player"
		if seat_index == 0:
			kind = "player"
		edits.append({
			"participantId": participant_id,
			"seatIndex": seat_index,
			"name": name,
			"kind": kind
		})
	return edits


func _save_lobby_seat_setup_from_inputs() -> void:
	var edits := _capture_lobby_seat_setup_edits()
	if edits.is_empty():
		return
	_save_lobby_seat_setup_from_edits(edits)


func _save_lobby_seat_setup_from_edits(edits: Array) -> void:
	var seats: Array = []
	for edit in edits:
		var kind := str(edit.get("kind", "bot"))
		if kind != "player" and kind != "bot":
			kind = "bot"
		seats.append({
			"name": str(edit.get("name", "")).strip_edges(),
			"kind": kind
		})
	if seats.is_empty():
		return
	_save_lobby_seat_setup({"seats": seats})


func _commit_lobby_seat_setup_edits() -> void:
	_flush_pending_lobby_name_edits()
	var edits := _capture_lobby_seat_setup_edits()
	if edits.is_empty():
		return
	_save_lobby_seat_setup_from_edits(edits)
	for edit in edits:
		_commit_lobby_seat_setup_edit(edit)


func _commit_lobby_seat_setup_edit(edit: Dictionary) -> void:
	var participant_id := str(edit.get("participantId", ""))
	if participant_id == "":
		return
	var desired_name := str(edit.get("name", "")).strip_edges()
	var desired_kind := str(edit.get("kind", "player"))
	if desired_kind != "player" and desired_kind != "bot":
		desired_kind = "player"
	var participant := _participant_by_id(RecipesClient.latest_snapshot, participant_id)
	if participant.is_empty():
		return
	var current_kind := "bot" if str(participant.get("kind", "human")) == "bot" else "player"
	var current_name := str(participant.get("name", "")).strip_edges()
	if desired_kind == "player" and current_kind == "bot":
		if _send_lobby_edit_intent({"type": "add_controlled_seat", "participantId": participant_id, "name": desired_name}):
			_lobby_pending_seat_names.erase(participant_id)
		return
	if desired_kind == "bot" and current_kind == "player":
		if bool(participant.get("isHost", false)):
			if desired_name != current_name and _send_lobby_edit_intent({"type": "rename_participant", "participantId": participant_id, "name": desired_name}):
				_lobby_pending_seat_names.erase(participant_id)
			return
		if desired_name != current_name:
			_send_lobby_edit_intent({"type": "rename_participant", "participantId": participant_id, "name": desired_name})
		if _send_lobby_edit_intent({"type": "convert_to_bot", "participantId": participant_id, "botType": "mixed"}):
			_lobby_pending_seat_names.erase(participant_id)
		return
	if desired_name != current_name and _send_lobby_edit_intent({"type": "rename_participant", "participantId": participant_id, "name": desired_name}):
		_lobby_pending_seat_names.erase(participant_id)


func _apply_saved_lobby_setup_to_active_table() -> void:
	var setup := _saved_lobby_seat_setup
	if setup.is_empty():
		setup = _load_lobby_seat_setup()
	var seats = setup.get("seats", [])
	if typeof(seats) != TYPE_ARRAY or seats.is_empty():
		return
	var snapshot := RecipesClient.latest_snapshot
	if not bool(snapshot.get("offline", false)) or _game_started(snapshot):
		return
	var participants := _active_lobby_participants(snapshot)
	var edits: Array = []
	var seat_count = mini(seats.size(), participants.size())
	for index in range(seat_count):
		var raw_seat = seats[index]
		if typeof(raw_seat) != TYPE_DICTIONARY:
			continue
		var seat: Dictionary = raw_seat
		var participant: Dictionary = participants[index]
		var kind := str(seat.get("kind", "bot")).to_lower()
		if kind != "player" and kind != "bot":
			kind = "bot"
		if index == 0:
			kind = "player"
		edits.append({
			"participantId": str(participant.get("id", "")),
			"seatIndex": index,
			"name": str(seat.get("name", "")).strip_edges(),
			"kind": kind
		})
	for edit in edits:
		_commit_lobby_seat_setup_edit(edit)


func _clear_lobby_edit_state() -> void:
	if is_instance_valid(_lobby_name_publish_timer):
		_lobby_name_publish_timer.stop()
	_lobby_seat_name_inputs.clear()
	_lobby_seat_kind_inputs.clear()
	_lobby_pending_seat_names.clear()


func _send_lobby_edit_intent(intent: Dictionary) -> bool:
	if bool(RecipesClient.latest_snapshot.get("viewerCanUseHostControls", false)):
		return RecipesClient.send_host_intent(intent)
	return RecipesClient.send_intent(intent)


func _change_lobby_seat_kind(participant_id: String, selected_index: int, input: LineEdit) -> void:
	if participant_id == "":
		return
	var desired_kind := "player" if selected_index == 0 else "bot"
	_commit_lobby_seat_setup_edit({
		"participantId": participant_id,
		"name": input.text.strip_edges(),
		"kind": desired_kind
	})


func _add_deposit_controls(snapshot: Dictionary) -> void:
	var hand: Array = snapshot.get("ownHand", [])
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	if str(viewer.get("role", "")) != "active":
		_hand_controls.add_child(_wrapped_label("Witnessing the table offering."))
		return
	if _opening_offering_count(viewer) >= 2:
		_hand_controls.add_child(_wrapped_label("Offering given. Waiting for the table."))
		return
	if hand.is_empty():
		_hand_controls.add_child(_wrapped_label("No offering is available. Waiting for the table."))
		return

	var voucher: Dictionary = hand[0]
	_hand_controls.add_child(_wrapped_label("Offer your ingredient to the Common Basket."))
	_hand_controls.add_child(_button("Offer %s to Common Basket" % _ingredient_display(snapshot, str(voucher.get("ingredientId", ""))), func(v: Dictionary = voucher, snap: Dictionary = snapshot) -> void:
		_pending_controlled_deposit_actor_id = str(snap.get("viewerParticipantId", ""))
		RecipesClient.send_intent({"type": "deposit", "voucherId": v.get("id", "")})
	))


func _maybe_advance_acting_as_after_deposit(snapshot: Dictionary) -> void:
	if str(snapshot.get("phase", "")) != "deposit":
		_pending_controlled_deposit_actor_id = ""
		return
	if not bool(snapshot.get("viewerCanUseHostControls", false)):
		_pending_controlled_deposit_actor_id = ""
		return
	if _pending_controlled_deposit_actor_id == "":
		return
	var pending_actor := _participant_by_id(snapshot, _pending_controlled_deposit_actor_id)
	if pending_actor.is_empty():
		_pending_controlled_deposit_actor_id = ""
		return
	if _opening_offering_count(pending_actor) < 2:
		return

	var next_actor_id := _next_controlled_undeposited_actor_id(snapshot, _pending_controlled_deposit_actor_id)
	_pending_controlled_deposit_actor_id = ""
	if next_actor_id == "":
		_maybe_follow_controlled_turn(snapshot)
		return

	var current_viewer := str(snapshot.get("viewerParticipantId", ""))
	if next_actor_id == current_viewer:
		return
	RecipesClient.view_as(next_actor_id)


func _maybe_follow_controlled_turn(snapshot: Dictionary) -> void:
	if not _should_follow_controlled_turn(snapshot):
		return
	var participant_id := str(snapshot.get("currentTurnParticipantId", ""))
	if participant_id == "" or _pending_controlled_follow_participant_id == participant_id:
		return
	_pending_controlled_follow_participant_id = participant_id
	call_deferred("_follow_controlled_turn_deferred", participant_id)


func _follow_controlled_turn_deferred(participant_id: String) -> void:
	if participant_id == "":
		_pending_controlled_follow_participant_id = ""
		return
	for _frame in range(1200):
		var snapshot := RecipesClient.latest_snapshot
		if not _should_follow_controlled_turn(snapshot):
			if _pending_controlled_follow_participant_id == participant_id:
				_pending_controlled_follow_participant_id = ""
			return
		if str(snapshot.get("currentTurnParticipantId", "")) != participant_id:
			if _pending_controlled_follow_participant_id == participant_id:
				_pending_controlled_follow_participant_id = ""
			return
		if _table_visual_ready_for_controlled_follow(participant_id):
			RecipesClient.view_as(participant_id)
			if _pending_controlled_follow_participant_id == participant_id:
				_pending_controlled_follow_participant_id = ""
			return
		await get_tree().process_frame
	var final_snapshot := RecipesClient.latest_snapshot
	if _should_follow_controlled_turn(final_snapshot) and str(final_snapshot.get("currentTurnParticipantId", "")) == participant_id:
		RecipesClient.view_as(participant_id)
	if _pending_controlled_follow_participant_id == participant_id:
		_pending_controlled_follow_participant_id = ""


func _table_visual_ready_for_controlled_follow(participant_id: String) -> bool:
	if not is_instance_valid(_table_visual):
		return true
	if _table_visual.has_method("visual_update_waiting") and bool(_table_visual.call("visual_update_waiting")):
		return false
	if _table_visual.has_method("current_visual_turn_id") and str(_table_visual.call("current_visual_turn_id")) != participant_id:
		return false
	return true


func _should_follow_controlled_turn(snapshot: Dictionary) -> bool:
	if not bool(snapshot.get("viewerCanUseHostControls", false)):
		return false
	if _viewer_is_witness(snapshot):
		return false
	var phase := str(snapshot.get("phase", ""))
	if phase != "playing" && phase != "settlement" && phase != "eating":
		return false
	var current_turn_id := str(snapshot.get("currentTurnParticipantId", ""))
	if current_turn_id == "":
		return false
	if current_turn_id == str(snapshot.get("viewerParticipantId", "")):
		return false
	if not _is_controlled_by_viewer(snapshot, current_turn_id):
		return false
	return true


func _track_last_controlled_turn(snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", ""))
	if phase != "playing" && phase != "settlement" && phase != "eating":
		_last_controlled_turn_participant_id = ""
		return
	var current_turn_id := str(snapshot.get("currentTurnParticipantId", ""))
	if current_turn_id == "":
		_last_controlled_turn_participant_id = ""
		return
	_last_controlled_turn_participant_id = current_turn_id


func _is_controlled_by_viewer(snapshot: Dictionary, participant_id: String) -> bool:
	if participant_id == "":
		return false
	var connection_id := str(snapshot.get("connectionParticipantId", snapshot.get("viewerParticipantId", "")))
	if participant_id == connection_id:
		return true
	var controlled_ids: Array = snapshot.get("controlledParticipantIds", [])
	return controlled_ids.has(participant_id)


func _next_controlled_undeposited_actor_id(snapshot: Dictionary, after_participant_id: String) -> String:
	var controlled_ids: Array = snapshot.get("controlledParticipantIds", [])
	if controlled_ids.is_empty():
		return ""

	var start_index := controlled_ids.find(after_participant_id)
	if start_index < 0:
		start_index = 0

	for offset in range(1, controlled_ids.size() + 1):
		var index := (start_index + offset) % controlled_ids.size()
		var candidate_id := str(controlled_ids[index])
		var candidate := _participant_by_id(snapshot, candidate_id)
		if candidate.is_empty():
			continue
		if str(candidate.get("role", "")) != "active":
			continue
		if _opening_offering_count(candidate) >= 2:
			continue
		return candidate_id
	return ""


func _add_playing_controls(snapshot: Dictionary) -> void:
	_add_pass_turn_button(snapshot)
	_add_recipe_status_control(snapshot)
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_add_hand_place_controls(snapshot)
	_add_platter_swap_controls(snapshot)
	if not snapshot.get("ownFoodParts", []).is_empty() or not snapshot.get("platterFoodParts", []).is_empty():
		_add_platter_asset_swap_controls(snapshot)
	_add_offer_controls(snapshot)


func _add_settlement_controls(snapshot: Dictionary) -> void:
	_add_pass_turn_button(snapshot)
	_phase_controls.add_child(_wrapped_label("Settlement: clear the central platter before eating."))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_hand_controls.add_child(_wrapped_label("Your inventory\n%s" % _format_inventory_assets(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_add_platter_asset_swap_controls(snapshot)


func _add_host_admin_controls(snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", "lobby"))
	var paused := bool(snapshot.get("paused", false))
	var is_offline := bool(snapshot.get("offline", false)) or RecipesClient.offline_mode
	if phase != "lobby" and phase != "complete":
		var game_row := _button_row()
		_phase_controls.add_child(game_row)
		if not is_offline:
			game_row.add_child(_button("Resume Game" if paused else "Pause Game", func() -> void:
				RecipesClient.send_host_intent({"type": "set_pause", "paused": not bool(RecipesClient.latest_snapshot.get("paused", false))})
			))
		if not paused or is_offline:
			game_row.add_child(_button("End Game", func() -> void:
				if bool(RecipesClient.latest_snapshot.get("offline", false)) or RecipesClient.offline_mode:
					_confirm_offline_end_game()
				else:
					RecipesClient.send_host_intent({"type": "stop"})
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


func _add_recipe_status_control(snapshot: Dictionary) -> void:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	if recipe.is_empty():
		_recipe_controls.add_child(_wrapped_label(_dish_count_summary_label(snapshot)))
		return
	_add_recipe_view(_recipe_controls, snapshot, recipe)
	_recipe_controls.add_child(_wrapped_label(_recipe_progress_label(recipe)))


func _add_eating_controls(snapshot: Dictionary) -> void:
	_add_pass_turn_button(snapshot)
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


func _add_transaction_history_controls(snapshot: Dictionary, target: VBoxContainer = null, visible_rows := TRANSACTION_VISIBLE_ROWS) -> void:
	if target == null:
		target = _transaction_controls
	if not is_instance_valid(target):
		return
	visible_rows = clampi(visible_rows, 1, TRANSACTION_VISIBLE_ROWS)
	var has_history := snapshot.has("transactionHistory")
	var transactions: Array = []
	if has_history:
		transactions = snapshot.get("transactionHistory", [])
	var history_complete := bool(snapshot.get("transactionHistoryComplete", true))
	var export_button := _button("Download CSV", _download_transactions_csv)
	export_button.disabled = not has_history or transactions.is_empty()
	target.add_child(export_button)
	_csv_export_status_label = _wrapped_label(_last_csv_export_status)
	_csv_export_status_label.visible = _last_csv_export_status != ""
	target.add_child(_csv_export_status_label)

	if not snapshot.has("transactionHistory"):
		target.add_child(_wrapped_label("Transaction history is not available from this server. Rebuild and restart the server, then create a new table."))
		return
	if transactions.is_empty():
		target.add_child(_wrapped_label("No successful transactions yet. Deposits, swaps, exchanges, redemptions, preparation, settlement, and eating will appear here."))
		return
	if not history_complete:
		target.add_child(_wrapped_label("Showing latest %s of %s transactions in this live witness view." % [
			transactions.size(),
			int(snapshot.get("transactionHistoryTotal", transactions.size()))
		]))
	target.add_child(_transaction_header_row())
	var scroller := ScrollContainer.new()
	scroller.name = "TransactionHistoryScroller"
	scroller.custom_minimum_size = Vector2(0, (TRANSACTION_ROW_HEIGHT + TRANSACTION_ROW_GAP) * visible_rows)
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", TRANSACTION_ROW_GAP)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(rows)
	for raw_transaction in _transactions_newest_first(transactions):
		var transaction: Dictionary = raw_transaction
		rows.add_child(_transaction_row(transaction))
	target.add_child(scroller)


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
	var card_group_labels := _voucher_group_labels_from_groups(snapshot, snapshot.get("ownHandGroups", []), true)
	if card_group_labels.is_empty():
		card_group_labels = _voucher_group_labels_from_vouchers(snapshot, hand, true)
	if not card_group_labels.is_empty():
		_hand_controls.add_child(_wrapped_label("Cards you hold\n%s" % "\n".join(card_group_labels)))
	if hand.is_empty():
		_hand_controls.add_child(_wrapped_label("Your hand is empty."))
		return
	var useful_count := 0
	for raw_group in _voucher_group_options(snapshot, hand, true, true, true):
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		for raw_requirement in requirements:
			var requirement: Dictionary = raw_requirement
			if str(requirement.get("ingredientId", "")) != ingredient_id:
				continue
			var placed_ids: Array = requirement.get("placedVoucherIds", [])
			var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - placed_ids.size()
			if outstanding <= 0:
				continue
			useful_count += mini(outstanding, int(group.get("count", 1)))
			break
	if useful_count > 0:
		_hand_controls.add_child(_wrapped_label("%s useful held cards will redeem when you use Redeem / Pass." % useful_count))
	else:
		_hand_controls.add_child(_wrapped_label("No held cards match the open recipe slots right now."))


func _add_platter_swap_controls(snapshot: Dictionary) -> void:
	var hand: Array = snapshot.get("ownHand", [])
	var platter: Array = snapshot.get("platter", [])
	_prune_swap_selection(snapshot, hand, platter)
	if hand.is_empty() or platter.is_empty():
		_platter_controls.add_child(_wrapped_label("Swap needs one hand voucher and one platter voucher."))
		return
	_platter_controls.add_child(_wrapped_label("Giving: %s\nTaking: %s" % [
		_voucher_group_label_by_id(snapshot, hand, _selected_hand_voucher_id, false),
		_voucher_resource_label_by_id(snapshot, platter, _selected_platter_voucher_id)
	]))
	_platter_controls.add_child(_wrapped_label("Give"))
	_platter_controls.add_child(_select_button(
		_voucher_group_label_by_id(snapshot, hand, _selected_hand_voucher_id, false) if _selected_hand_voucher_id != "" else "Select card to give",
		"platter_give"
	))
	_platter_controls.add_child(_wrapped_label("Take"))
	_platter_controls.add_child(_select_button(
		_voucher_resource_label_by_id(snapshot, platter, _selected_platter_voucher_id) if _selected_platter_voucher_id != "" else "Select card to take",
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
		var give_label := _voucher_group_label_by_id(latest, latest_hand, _selected_hand_voucher_id, false)
		var take_label := _voucher_resource_label_by_id(latest, latest_platter, _selected_platter_voucher_id)
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
		_platter_controls.add_child(_wrapped_label("Asset swaps need one held card or food part and one platter card or food part."))
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
		_offer_cards_label(snapshot, offer),
		wanted
	]))
	if matching.size() >= quantity:
		_offer_controls.add_child(_button("Accept Offer", func(ids := matching.duplicate(), o := offer) -> void:
			RecipesClient.send_intent({"type": "respond_offer", "offerId": o.get("id", ""), "response": "accept", "voucherIds": ids})
		))
	else:
		_offer_controls.add_child(_wrapped_label("You do not have enough %s to accept." % _ingredient_display(snapshot, ingredient_id)))
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
	card_option.add_item("Select ingredient to offer")
	card_option.set_item_metadata(0, "")
	for raw_group in _voucher_group_options(snapshot, hand, false, false, true):
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		var group_index := card_option.item_count
		card_option.add_item(_ingredient_display(snapshot, ingredient_id))
		card_option.set_item_metadata(group_index, ingredient_id)
		if ingredient_id == _selected_offer_ingredient_id:
			card_option.select(group_index)
	card_option.item_selected.connect(func(index: int) -> void:
		_selected_offer_ingredient_id = str(card_option.get_item_metadata(index))
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
		if _selected_offer_target_id == "" or _selected_offer_ingredient_id == "" or ingredient_id == "":
			_on_error_received({"description": "Offer needs a player and a card."})
			return
		var voucher_id := _first_voucher_id_for_ingredient(snapshot, _selected_offer_ingredient_id)
		if voucher_id == "":
			_on_error_received({"description": "No matching card available for %s." % _ingredient_display(snapshot, _selected_offer_ingredient_id)})
			return
		RecipesClient.send_intent({
			"type": "create_offer",
			"toParticipantId": _selected_offer_target_id,
			"offeredVoucherIds": [voucher_id],
			"requested": {"ingredientId": ingredient_id, "quantity": 1}
		})
		_selected_offer_ingredient_id = ""
	)
	create_button.disabled = _selected_offer_target_id == "" or _selected_offer_ingredient_id == "" or request_ingredient_id == ""
	form.add_child(create_button)


func _set_timer() -> void:
	if _timer_input.text.strip_edges() == "":
		RecipesClient.send_host_intent({"type": "set_timer", "seconds": null})
		return
	var seconds := int(_timer_input.text)
	if seconds <= 0:
		_on_error_received({"description": "Timer must be a positive number of seconds."})
		return
	RecipesClient.send_host_intent({"type": "set_timer", "seconds": seconds})


func _set_target_dish_count() -> void:
	var count := int(_target_dish_count_input.text)
	if count < 1 or count > 3:
		_on_error_received({"description": "Dish goal must be between 1 and 3."})
		return
	RecipesClient.send_host_intent({"type": "set_target_dish_count", "count": count})


func _set_stock() -> void:
	var count := int(_stock_input.text)
	if count < 1:
		_on_error_received({"description": "Stock must be at least 1."})
		return
	RecipesClient.send_host_intent({"type": "set_stock", "count": count})


func _participant_by_id(snapshot: Dictionary, participant_id: String) -> Dictionary:
	for participant in snapshot.get("participants", []):
		if str(participant.get("id", "")) == participant_id:
			return participant
	return {}


func _opening_offering_count(participant: Dictionary) -> int:
	if participant.has("openingOfferingsCount"):
		return int(participant.get("openingOfferingsCount", 0))
	return 2 if bool(participant.get("depositedInitial", false)) else 0


func _participant_name(snapshot: Dictionary, participant_id: String) -> String:
	var participant := _participant_by_id(snapshot, participant_id)
	if participant.is_empty():
		return "Someone"
	return str(participant.get("name", "Someone"))


func _voucher_has_stock(snapshot: Dictionary, voucher: Dictionary) -> bool:
	var owner := _participant_by_id(snapshot, str(voucher.get("ownerParticipantId", "")))
	return int(owner.get("realIngredientStock", 0)) > 0


func _next_turn_participant_name(snapshot: Dictionary) -> String:
	var next_id := _next_turn_participant_id(snapshot)
	return "" if next_id == "" else _participant_name(snapshot, next_id)


func _next_turn_participant_id(snapshot: Dictionary) -> String:
	var current_id := str(snapshot.get("currentTurnParticipantId", ""))
	var participants: Array = snapshot.get("participants", [])
	if participants.is_empty():
		return ""
	var current_index := -1
	for index in range(participants.size()):
		var participant: Dictionary = participants[index]
		if str(participant.get("id", "")) == current_id:
			current_index = index
			break
	for offset in range(1, participants.size() + 1):
		var candidate_index := (current_index + offset) % participants.size()
		var candidate: Dictionary = participants[candidate_index]
		if str(candidate.get("role", "")) == "active":
			return str(candidate.get("id", ""))
	return ""


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


func _turn_status_label(snapshot: Dictionary) -> String:
	var current_id := str(snapshot.get("currentTurnParticipantId", ""))
	if current_id == "":
		return "Current turn: waiting"
	return "Current turn: %s" % _participant_name(snapshot, current_id)


func _viewer_can_take_turn(snapshot: Dictionary) -> bool:
	var phase := str(snapshot.get("phase", "lobby"))
	if phase == "lobby" or phase == "deposit" or phase == "complete":
		return true
	return str(snapshot.get("viewerParticipantId", "")) == str(snapshot.get("currentTurnParticipantId", ""))


func _round_robin_waiting(snapshot: Dictionary) -> bool:
	if _viewer_is_witness(snapshot):
		return false
	var phase := str(snapshot.get("phase", "lobby"))
	if phase != "playing" and phase != "settlement" and phase != "eating":
		return false
	return not _viewer_can_take_turn(snapshot)


func _add_read_only_turn_view(snapshot: Dictionary) -> void:
	_phase_controls.add_child(_wrapped_label("Waiting for %s." % _participant_name(snapshot, str(snapshot.get("currentTurnParticipantId", "")))))
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	if not recipe.is_empty():
		_add_recipe_view(_recipe_controls, snapshot, recipe)
		_recipe_controls.add_child(_wrapped_label(_recipe_progress_label(recipe)))
	else:
		_recipe_controls.add_child(_wrapped_label(_dish_count_summary_label(snapshot)))
	_hand_controls.add_child(_wrapped_label("Your inventory\n%s" % _format_inventory_assets(snapshot)))
	_platter_controls.add_child(_wrapped_label(_accountability_label(snapshot)))
	_platter_controls.add_child(_wrapped_label("%s\n%s" % [_platter_title(snapshot), _format_platter_assets(snapshot)]))
	_offer_controls.add_child(_wrapped_label(_open_offers_label(snapshot)))


func _add_pass_turn_button(snapshot: Dictionary) -> void:
	if not _viewer_can_take_turn(snapshot):
		return
	var phase := str(snapshot.get("phase", "lobby"))
	if phase != "playing" and phase != "settlement" and phase != "eating":
		return
	var next_name := _next_turn_participant_name(snapshot)
	var is_playing := phase == "playing"
	var label := "Redeem / Pass" if is_playing else ("Pass Turn" if next_name == "" else "Pass Turn to %s" % next_name)
	_phase_controls.add_child(_button(label, func() -> void:
		if is_playing:
			_status_label.text = "Redeeming useful cards and passing turn%s." % ("" if next_name == "" else " to %s" % next_name)
			RecipesClient.send_intent({"type": "redeem_all_and_pass_turn"})
		else:
			_status_label.text = "Passing turn%s." % ("" if next_name == "" else " to %s" % next_name)
			RecipesClient.send_intent({"type": "pass_turn"})
	))


func _can_switch_to_bot(snapshot: Dictionary, participant: Dictionary) -> bool:
	if participant.is_empty():
		return false
	if str(participant.get("kind", "human")) == "bot":
		return false
	if str(participant.get("role", "")) != "active":
		return false
	if bool(participant.get("isHost", false)):
		return false
	return bool(snapshot.get("viewerCanUseHostControls", false))


func _confirm_switch_to_bot(participant_id: String, participant_name: String) -> void:
	if participant_id == "":
		return
	_pending_bot_participant_id = participant_id
	_confirm_bot_dialog.dialog_text = "Switch %s to a mixed bot?\n\nThis seat will stop accepting that player's current connection token." % participant_name
	_confirm_bot_dialog.popup_centered()


func _on_confirm_switch_to_bot() -> void:
	if _pending_bot_participant_id == "":
		return
	RecipesClient.send_host_intent({"type": "convert_to_bot", "participantId": _pending_bot_participant_id, "botType": "mixed"})
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
		labels.append(_voucher_group_label(snapshot, str(summary.get("ingredientId", "")), count, true))
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
			_offer_cards_label(snapshot, offer),
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
	var lines: Array[String] = ["Turn | Name | Action | Counterparty | Item out | Item back"]
	for raw_transaction in _transactions_newest_first(transactions):
		var transaction: Dictionary = raw_transaction
		lines.append("%s | %s | %s | %s | %s | %s" % [
			transaction.get("turn", "?"),
			transaction.get("name", "?"),
			transaction.get("action", "?"),
			transaction.get("counterparty", "?"),
			transaction.get("itemOut", "-"),
			transaction.get("itemBack", "-")
		])
	return "\n".join(lines)


func _transactions_newest_first(transactions: Array) -> Array:
	var ordered := transactions.duplicate()
	ordered.reverse()
	return ordered


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
	if _selected_offer_ingredient_id != "":
		var available := false
		for raw_voucher in hand:
			var voucher: Dictionary = raw_voucher
			if str(voucher.get("ingredientId", "")) == _selected_offer_ingredient_id and _voucher_has_stock(snapshot, voucher):
				available = true
				break
		if not available:
			_selected_offer_ingredient_id = ""
	if _selected_offer_ingredient_id == "":
		_selected_offer_ingredient_id = _default_offer_give_ingredient_id(snapshot, hand)


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


func _first_voucher_id_for_ingredient(snapshot: Dictionary, ingredient_id: String) -> String:
	if ingredient_id == "":
		return ""
	for voucher in snapshot.get("ownHand", []):
		if str(voucher.get("ingredientId", "")) == ingredient_id and _voucher_has_stock(snapshot, voucher):
			return str(voucher.get("id", ""))
	return ""


func _default_offer_give_ingredient_id(snapshot: Dictionary, hand: Array) -> String:
	var groups := _voucher_group_options(snapshot, hand, false, false, true)
	if groups.is_empty():
		return ""

	var main_ingredient_id := _viewer_main_ingredient_id(snapshot)
	if main_ingredient_id != "":
		for raw_group in groups:
			var group: Dictionary = raw_group
			if str(group.get("ingredientId", "")) == main_ingredient_id and int(group.get("count", 0)) > 0:
				return main_ingredient_id

	var best_ingredient := ""
	var best_count := -1
	for raw_group in groups:
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		var count := int(group.get("count", 0))
		if count <= 0:
			continue
		if count > best_count or (count == best_count and ingredient_id < best_ingredient):
			best_count = count
			best_ingredient = ingredient_id
	return best_ingredient


func _offer_request_label(snapshot: Dictionary, ingredient_id: String) -> String:
	if ingredient_id == "":
		return "Select a player first."
	return "%s x1" % _ingredient_display(snapshot, ingredient_id)


func _ingredient_display(snapshot: Dictionary, ingredient_id: String) -> String:
	if ingredient_id == "":
		return "Unknown"
	if ingredient_id == "vegetables":
		return "Veggies"
	for ingredient in snapshot.get("ingredients", []):
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.capitalize()


func _offer_cards_label(snapshot: Dictionary, offer: Dictionary) -> String:
	var offered: Array = offer.get("offeredVouchers", [])
	if not offered.is_empty():
		var labels: Array[String] = []
		var by_ingredient: Dictionary = {}
		for raw_voucher in offered:
			var voucher: Dictionary = raw_voucher
			var ingredient_id := str(voucher.get("ingredientId", ""))
			by_ingredient[ingredient_id] = int(by_ingredient.get(ingredient_id, 0)) + 1
		for raw_key in by_ingredient.keys():
			var key: String = str(raw_key)
			var count: int = int(by_ingredient[raw_key])
			if count <= 1:
				labels.append(_ingredient_display(snapshot, key))
			else:
				labels.append("%s x%s" % [_ingredient_display(snapshot, key), count])
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
		_offer_cards_label(snapshot, offer),
		to_name,
		wanted
	]


func _active_count(snapshot: Dictionary) -> int:
	var count := 0
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active":
			count += 1
	return count


func _available_bot_participants(snapshot: Dictionary) -> Array:
	var bots: Array = []
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) == "active" and str(participant.get("kind", "")) == "bot":
			bots.append(participant)
	return bots


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


func _voucher_group_options(snapshot: Dictionary, vouchers: Array, held_prefix := false, show_count := true, require_stock := false) -> Array:
	var by_ingredient := {}
	var order: Array[String] = []
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if require_stock and not _voucher_has_stock(snapshot, voucher):
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id == "":
			continue
		if not by_ingredient.has(ingredient_id):
			by_ingredient[ingredient_id] = {"ingredientId": ingredient_id, "voucherId": str(voucher.get("id", "")), "count": 0}
			order.append(ingredient_id)
		var group: Dictionary = by_ingredient[ingredient_id]
		group["count"] = int(group.get("count", 0)) + 1
	var options: Array = []
	for ingredient_id in order:
		var group: Dictionary = by_ingredient[ingredient_id]
		var count := int(group.get("count", 0))
		group["count"] = count
		group["label"] = _voucher_group_label(snapshot, ingredient_id, count, held_prefix) if show_count else _voucher_resource_label(snapshot, ingredient_id, held_prefix)
		options.append(group)
	return options


func _voucher_group_labels_from_groups(snapshot: Dictionary, groups: Array, held_prefix := false) -> Array[String]:
	var labels: Array[String] = []
	for raw_group in groups:
		var group: Dictionary = raw_group
		var count := int(group.get("count", 0))
		if count <= 0:
			continue
		labels.append(_voucher_group_label(snapshot, str(group.get("ingredientId", "")), count, held_prefix))
	return labels


func _voucher_group_labels_from_vouchers(snapshot: Dictionary, vouchers: Array, held_prefix := false) -> Array[String]:
	var labels: Array[String] = []
	for raw_group in _voucher_group_options(snapshot, vouchers, held_prefix):
		var group: Dictionary = raw_group
		labels.append(str(group.get("label", "")))
	return labels


func _voucher_group_label(snapshot: Dictionary, ingredient_id: String, count: int, held_prefix := false) -> String:
	var prefix := "Held " if held_prefix else ""
	return "%s%s - %s" % [
		prefix,
		_ingredient_display(snapshot, ingredient_id),
		_voucher_count_label(count)
	]


func _voucher_resource_label(snapshot: Dictionary, ingredient_id: String, held_prefix := false) -> String:
	var prefix := "Held " if held_prefix else ""
	return "%s%s Card" % [prefix, _ingredient_display(snapshot, ingredient_id)]


func _ingredient_count_label(snapshot: Dictionary, ingredient_id: String, count: int) -> String:
	return "%s: %s" % [_ingredient_display(snapshot, ingredient_id), count]


func _voucher_count_label(count: int) -> String:
	return "%s %s" % [count, "Card" if count == 1 else "Cards"]


func _food_part_group_labels(groups: Array) -> Array[String]:
	var labels: Array[String] = []
	for raw_group in groups:
		var group: Dictionary = raw_group
		var count := int(group.get("count", 0))
		if count <= 0:
			continue
		labels.append(_food_part_group_label(group, true))
	return labels


func _food_part_group_count(groups: Array) -> int:
	var count := 0
	for raw_group in groups:
		var group: Dictionary = raw_group
		count += int(group.get("count", 0))
	return count


func _food_part_group_options(parts: Array) -> Array:
	var by_dish := {}
	var order: Array[String] = []
	for raw_part in parts:
		var part: Dictionary = raw_part
		var dish_id := str(part.get("dishId", ""))
		if dish_id == "":
			continue
		if not by_dish.has(dish_id):
			by_dish[dish_id] = {
				"dishId": dish_id,
				"partId": str(part.get("id", "")),
				"dishName": str(part.get("dishName", "Dish")),
				"unitSingular": str(part.get("unitSingular", "part")),
				"unitPlural": str(part.get("unitPlural", "parts")),
				"count": 0
			}
			order.append(dish_id)
		var group: Dictionary = by_dish[dish_id]
		group["count"] = int(group.get("count", 0)) + 1
	var options: Array = []
	for dish_id in order:
		var group: Dictionary = by_dish[dish_id]
		group["label"] = _food_part_group_label(group, true)
		options.append(group)
	return options


func _food_part_group_labels_from_parts(parts: Array) -> Array[String]:
	var labels: Array[String] = []
	for raw_group in _food_part_group_options(parts):
		var group: Dictionary = raw_group
		labels.append(str(group.get("label", "")))
	return labels


func _food_part_group_label(group: Dictionary, held_prefix := false) -> String:
	var count := int(group.get("count", 0))
	var prefix := "Held " if held_prefix else ""
	return "%s%s x%s" % [prefix, VisualAssets.short_dish_name(str(group.get("dishName", "Dish"))), count]


func _format_platter_assets(snapshot: Dictionary) -> String:
	var labels: Array[String] = []
	var platter_voucher_summary: Array = snapshot.get("platterVoucherGroups", [])
	if not platter_voucher_summary.is_empty():
		for raw_summary in platter_voucher_summary:
			var summary: Dictionary = raw_summary
			labels.append(_ingredient_count_label(snapshot, str(summary.get("ingredientId", "")), int(summary.get("count", 0))))
	else:
		var grouped_vouchers := _voucher_group_options(snapshot, snapshot.get("platter", []), false, false)
		for raw_group in grouped_vouchers:
			var group: Dictionary = raw_group
			labels.append(_ingredient_count_label(snapshot, str(group.get("ingredientId", "")), int(group.get("count", 0))))
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
	var hand_group_labels := _voucher_group_labels_from_groups(snapshot, snapshot.get("ownHandGroups", []), true)
	if hand_group_labels.is_empty():
		hand_group_labels = _voucher_group_labels_from_vouchers(snapshot, snapshot.get("ownHand", []), true)
	labels.append_array(hand_group_labels)
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
	labels.append_array(_voucher_group_labels_from_vouchers(snapshot, hand, true))
	if hand.is_empty():
		labels.append_array(_voucher_summary_labels_for_participant(snapshot, participant_id))
	labels.append_array(_food_part_group_labels_from_parts(_food_parts_for_participant(snapshot, participant_id)))
	for summary_label in _food_part_summary_labels_for_participant(snapshot, participant_id):
		labels.append(summary_label)
	if labels.is_empty():
		return "-"
	return "\n".join(labels)


func _inventory_asset_options(snapshot: Dictionary) -> Array:
	var assets: Array = []
	for raw_group in _voucher_group_options(snapshot, snapshot.get("ownHand", []), true, true, true):
		var voucher_group: Dictionary = raw_group
		assets.append(_asset_option("voucher", str(voucher_group.get("voucherId", "")), str(voucher_group.get("label", ""))))
	for raw_part_group in _food_part_group_options(snapshot.get("ownFoodParts", [])):
		var part_group: Dictionary = raw_part_group
		assets.append(_asset_option("dish_part", str(part_group.get("partId", "")), str(part_group.get("label", ""))))
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
	if _select_popup.visible:
		_select_popup.hide()
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


func _toggle_select_popup(select_key: String, anchor: Control) -> void:
	var now_ms := Time.get_ticks_msec()
	if _last_popup_close_key == select_key and now_ms - _last_popup_close_ms < 200:
		_last_popup_close_key = ""
		_last_popup_close_ms = -1
		return
	if _select_popup.visible and _active_select_key == select_key:
		_select_popup.hide()
		return
	_open_select_popup(select_key, anchor)


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
			for raw_group in _voucher_group_options(snapshot, snapshot.get("ownHand", []), false, false, true):
				var group: Dictionary = raw_group
				options.append({"label": str(group.get("label", "")), "value": str(group.get("voucherId", ""))})
		"platter_take":
			var selected_give_ingredient_id := _voucher_ingredient_for_id(snapshot.get("ownHand", []), _selected_hand_voucher_id)
			for raw_group in _voucher_group_options(snapshot, snapshot.get("platter", []), false, false, true):
				var group: Dictionary = raw_group
				if selected_give_ingredient_id != "" and str(group.get("ingredientId", "")) == selected_give_ingredient_id:
					continue
				options.append({"label": str(group.get("label", "")), "value": str(group.get("voucherId", ""))})
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
	var dish_name := VisualAssets.short_dish_name(str(part.get("dishName", "Dish")))
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
		labels.append(_food_part_summary_label(summary, true))
	return labels


func _food_part_summary_label(summary: Dictionary, held_prefix := false) -> String:
	var count := int(summary.get("count", 0))
	var prefix := "Held " if held_prefix else ""
	return "%s%s x%s" % [prefix, VisualAssets.short_dish_name(str(summary.get("dishName", "Dish"))), count]


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


func _prune_swap_selection(snapshot: Dictionary, hand: Array, platter: Array) -> void:
	if _selected_hand_voucher_id != "" and not _contains_voucher_id(hand, _selected_hand_voucher_id):
		_selected_hand_voucher_id = ""
	if _selected_hand_voucher_id == "":
		_selected_hand_voucher_id = _default_swap_give_voucher_id(snapshot, hand, _voucher_ingredient_for_id(platter, _selected_platter_voucher_id))
	if _selected_platter_voucher_id != "" and not _contains_voucher_id(platter, _selected_platter_voucher_id):
		_selected_platter_voucher_id = ""
	var selected_give_ingredient_id := _voucher_ingredient_for_id(hand, _selected_hand_voucher_id)
	if _selected_platter_voucher_id != "":
		var selected_take_ingredient_id := _voucher_ingredient_for_id(platter, _selected_platter_voucher_id)
		if selected_take_ingredient_id != "" and selected_take_ingredient_id == selected_give_ingredient_id:
			_selected_platter_voucher_id = ""


func _viewer_main_ingredient_id(snapshot: Dictionary) -> String:
	var viewer_id := str(snapshot.get("viewerParticipantId", ""))
	if viewer_id == "":
		viewer_id = str(snapshot.get("connectionParticipantId", ""))
	if viewer_id == "":
		return ""
	var viewer := _participant_by_id(snapshot, viewer_id)
	return str(viewer.get("ingredientId", ""))


func _default_swap_give_voucher_id(snapshot: Dictionary, hand: Array, forbidden_ingredient_id := "") -> String:
	if hand.is_empty():
		return ""
	var groups := _voucher_group_options(snapshot, hand, false, false, true)
	if groups.is_empty():
		return ""
	var main_ingredient_id := _viewer_main_ingredient_id(snapshot)
	if main_ingredient_id != "":
		for raw_group in groups:
			var group: Dictionary = raw_group
			var group_ingredient_id := str(group.get("ingredientId", ""))
			if group_ingredient_id != main_ingredient_id:
				continue
			if int(group.get("count", 0)) <= 0:
				break
			if forbidden_ingredient_id != "" and group_ingredient_id == forbidden_ingredient_id:
				break
			return str(group.get("voucherId", ""))

	var best_id := ""
	var best_count := -1
	var best_ingredient := ""
	for raw_group in groups:
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		var count := int(group.get("count", 0))
		if ingredient_id == forbidden_ingredient_id:
			continue
		if count <= 0:
			continue
		if count > best_count or (count == best_count and ingredient_id < best_ingredient):
			best_count = count
			best_ingredient = ingredient_id
			best_id = str(group.get("voucherId", ""))
	return best_id


func _voucher_ingredient_for_id(vouchers: Array, voucher_id: String) -> String:
	if voucher_id == "":
		return ""
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return str(voucher.get("ingredientId", ""))
	return ""


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


func _voucher_group_label_by_id(snapshot: Dictionary, vouchers: Array, voucher_id: String, show_count := true) -> String:
	if voucher_id == "":
		return "nothing selected"
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) != voucher_id:
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		var count := 0
		for raw_candidate in vouchers:
			var candidate: Dictionary = raw_candidate
			if str(candidate.get("ingredientId", "")) == ingredient_id:
				count += 1
		return _voucher_group_label(snapshot, ingredient_id, count) if show_count else _voucher_resource_label(snapshot, ingredient_id)
	return "nothing selected"


func _voucher_resource_label_by_id(snapshot: Dictionary, vouchers: Array, voucher_id: String) -> String:
	if voucher_id == "":
		return "nothing selected"
	var ingredient_id := _voucher_ingredient_for_id(vouchers, voucher_id)
	if ingredient_id == "":
		return "nothing selected"
	return _voucher_resource_label(snapshot, ingredient_id)


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
		root.add_child(_wrapped_label(_dish_count_summary_label(snapshot)))
		return
	root.add_child(_wrapped_label(_recipe_title_label(snapshot, recipe)))
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		root.add_child(_recipe_requirement_row(snapshot, requirement))


func _recipe_title_label(snapshot: Dictionary, recipe: Dictionary) -> String:
	var recipe_name := str(recipe.get("name", ""))
	if recipe_name == "":
		recipe_name = str(recipe.get("dishName", "Recipe"))
	var target := int(snapshot.get("targetDishCount", 0))
	if target <= 0:
		return "Recipe: %s" % recipe_name
	var viewer := _participant_by_id(snapshot, str(snapshot.get("viewerParticipantId", "")))
	var completed := int(viewer.get("dishCount", 0)) if not viewer.is_empty() else 0
	var recipe_number := clampi(completed + 1, 1, target)
	return "Recipe %s/%s: %s" % [recipe_number, target, recipe_name]


func _dish_count_summary_label(snapshot: Dictionary) -> String:
	var target := int(snapshot.get("targetDishCount", 0))
	var lines: Array[String] = ["Dishes made"]
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var count := int(participant.get("dishCount", 0))
		var suffix := ""
		if target > 0:
			suffix = "/%s" % target
		lines.append("%s: %s%s" % [
			str(participant.get("name", "Player")),
			count,
			suffix
		])
	if lines.size() == 1:
		lines.append("No dishes made yet.")
	return "\n".join(lines)


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
