extends PanelContainer

signal intent_requested(intent: Dictionary)
signal view_requested(participant_id: String)
signal status_requested(message: String)
signal menu_requested(action: String)

const VisualAssets := preload("res://scripts/visual_asset_registry.gd")

const TEXT_DARK := Color(0.16, 0.14, 0.11)
const TEXT_MUTED := Color(0.38, 0.35, 0.29)
const TABLE_BG := Color(0.91, 0.88, 0.80)
const PANEL_BG := Color(0.94, 0.92, 0.84)
const PANEL_BORDER := Color(0.42, 0.36, 0.27)
const DEFAULT_INGREDIENT_ORDER := ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
# Deposit order on a 4x2 grid:
# [8] [3] [4] [7]
# [5] [1] [2] [6]
const BASKET_CENTER_OUT_SLOTS := [5, 6, 1, 2, 4, 7, 3, 0]
const TABLE_CONTENT_WIDTH := 680
const TABLE_CONTENT_HEIGHT := 960
const BASKET_BACKDROP_SIZE := Vector2(668, 230)
const BASKET_SLOT_SIZE := Vector2(118, 82)
const BASKET_GRID_GAP := 7
const BASKET_GRID_SIZE := Vector2(BASKET_SLOT_SIZE.x * 4.0 + BASKET_GRID_GAP * 3.0, BASKET_SLOT_SIZE.y * 2.0 + BASKET_GRID_GAP)
const RECIPE_SLOT_SIZE := Vector2(138, 92)
const RECIPE_GRID_GAP := 6
const RECIPE_GRID_SIZE := Vector2(RECIPE_SLOT_SIZE.x * 3.0 + RECIPE_GRID_GAP * 2.0, RECIPE_SLOT_SIZE.y * 2.0 + RECIPE_GRID_GAP)
const COOK_TILE_SIZE := Vector2(152, 108)
const CARD_TILE_FADE_IN_SECONDS := 0.03
const CARD_TILE_MOVE_SECONDS := 0.42
const CARD_TILE_PULSE_SECONDS := 0.12
const CARD_TILE_FADE_OUT_SECONDS := 0.08
const CARD_TILE_LANDING_SECONDS := CARD_TILE_FADE_IN_SECONDS + CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS
const CARD_TILE_VISIBLE_START_LANDING_SECONDS := CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS
const TEXTURE_FADE_IN_SECONDS := 0.03
const TEXTURE_MOVE_SECONDS := 0.38
const TEXTURE_PULSE_SECONDS := 0.12
const TEXTURE_FADE_OUT_SECONDS := 0.08
const TEXTURE_LANDING_SECONDS := TEXTURE_FADE_IN_SECONDS + TEXTURE_MOVE_SECONDS + TEXTURE_PULSE_SECONDS
const SWAP_RETURN_DELAY_SECONDS := CARD_TILE_LANDING_SECONDS + 0.10
const SWAP_MID_SNAPSHOT_SECONDS := CARD_TILE_LANDING_SECONDS
const SWAP_TAKE_START_SECONDS := SWAP_RETURN_DELAY_SECONDS + CARD_TILE_FADE_IN_SECONDS
const SWAP_FINISH_SECONDS := SWAP_TAKE_START_SECONDS + CARD_TILE_VISIBLE_START_LANDING_SECONDS
const REDEEM_INGREDIENT_DELAY_SECONDS := CARD_TILE_LANDING_SECONDS + 0.10
const REDEEM_FINISH_SECONDS := REDEEM_INGREDIENT_DELAY_SECONDS + TEXTURE_LANDING_SECONDS


class BasketBackdrop:
	extends PanelContainer

	const BASE := Color(0.74, 0.53, 0.30)
	const WEAVE_DARK := Color(0.48, 0.30, 0.14, 0.34)
	const WEAVE_LIGHT := Color(0.92, 0.72, 0.43, 0.30)
	const RIM := Color(0.34, 0.20, 0.09)
	const RIM_LIGHT := Color(0.90, 0.68, 0.40, 0.72)
	const DRAW_SIZE := Vector2(668, 230)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if size.x <= 8.0 or size.y <= 8.0:
			return
		var draw_size := Vector2(minf(size.x, DRAW_SIZE.x), minf(size.y, DRAW_SIZE.y))
		var center := size * 0.5
		var radius := Vector2(maxf(1.0, draw_size.x * 0.5 - 4.0), maxf(1.0, draw_size.y * 0.5 - 7.0))
		var ellipse := _ellipse_points(center, radius, 72)
		draw_colored_polygon(ellipse, BASE)
		_draw_weave(center, radius, 0.34, WEAVE_DARK)
		_draw_weave(center, radius, -0.34, WEAVE_LIGHT)
		var closed := ellipse.duplicate()
		closed.append(ellipse[0])
		draw_polyline(closed, RIM_LIGHT, 2.0, true)
		draw_polyline(closed, RIM, 3.0, true)
		_draw_title()

	func _draw_title() -> void:
		var font := get_theme_default_font()
		if font == null:
			return
		var text := "Common Basket"
		var font_size := 20
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var position := Vector2((size.x - text_size.x) * 0.5, 28.0)
		draw_string(font, position + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.98, 0.90, 0.70, 0.80))
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.20, 0.13, 0.06))

	func _ellipse_points(center: Vector2, radius: Vector2, steps: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(steps):
			var angle := TAU * float(index) / float(steps)
			points.append(Vector2(center.x + cos(angle) * radius.x, center.y + sin(angle) * radius.y))
		return points

	func _draw_weave(center: Vector2, radius: Vector2, slope: float, color: Color) -> void:
		for offset in range(-int(size.y), int(size.y + size.x), 15):
			var segment_start := Vector2.ZERO
			var segment_end := Vector2.ZERO
			var inside := false
			for x in range(-24, int(size.x) + 25, 5):
				var point := Vector2(float(x), float(offset) + float(x) * slope)
				if _point_in_ellipse(point, center, radius):
					if not inside:
						segment_start = point
					segment_end = point
					inside = true
				elif inside:
					draw_line(segment_start, segment_end, color, 1.5, true)
					inside = false
			if inside:
				draw_line(segment_start, segment_end, color, 1.5, true)

	func _point_in_ellipse(point: Vector2, center: Vector2, radius: Vector2) -> bool:
		var dx := (point.x - center.x) / radius.x
		var dy := (point.y - center.y) / radius.y
		return dx * dx + dy * dy <= 1.0


class MenuBarsIcon:
	extends Control

	const BAR_COLOR := Color(0.18, 0.12, 0.07)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var left := 8.0
		var right := maxf(left + 1.0, size.x - 8.0)
		for y in [10.0, 16.0, 22.0]:
			draw_line(Vector2(left, y), Vector2(right, y), BAR_COLOR, 2.5, true)


var debug_stats := {}

var _snapshot: Dictionary = {}
var _selected_hand_voucher_id := ""
var _selected_hand_ingredient_id := ""
var _selected_inventory_asset_key := ""
var _selected_platter_asset_key := ""
var _animation_queue: Array = []
var _animation_running := false
var _animation_deadline_msec := 0
var _current_animation_event: Dictionary = {}
var _animation_actor_participant_id := ""
var _last_animation_types: Array[String] = []
var _pending_visual_snapshot: Dictionary = {}
var _has_pending_visual_snapshot := false
var _pending_visual_snapshots: Array = []

var _root: VBoxContainer
var _participant_row: VBoxContainer
var _inventory_title_label: Label
var _basket_grid: GridContainer
var _redeem_box: VBoxContainer
var _recipe_name_label: Label
var _recipe_grid: GridContainer
var _prepare_button: Button
var _hand_row: HBoxContainer
var _inventory_row: HBoxContainer
var _animation_layer: Control
var _offer_popup: PopupPanel
var _offer_popup_scroller: ScrollContainer
var _offer_popup_list: VBoxContainer
var _overlay_layer: Control
var _menu_canvas: CanvasLayer
var _menu_button: Button
var _menu_popup: PopupPanel
var _menu_popup_list: VBoxContainer
var _basket_slot_by_ingredient := {}
var _basket_slot_table_key := ""


func _ready() -> void:
	_build()
	set_process_input(true)
	set_process(true)


func _exit_tree() -> void:
	VisualAssets.clear_cache()


func render(snapshot: Dictionary) -> void:
	var previous_snapshot := _snapshot.duplicate(true)
	if _visual_update_waiting():
		if _snapshot_identity_key(snapshot) != _snapshot_identity_key(_snapshot):
			_queue_pending_visual_snapshot(snapshot)
		return
	if _is_start_setup_transition(previous_snapshot, snapshot):
		_apply_start_setup_transition(snapshot)
		return
	if _should_hold_snapshot_for_animation(previous_snapshot, snapshot):
		var events := _animation_events(previous_snapshot, snapshot)
		if not events.is_empty():
			events = _events_with_visual_milestones(previous_snapshot, snapshot, events)
			_queue_pending_visual_snapshot(snapshot)
			_record_animation_debug(events)
			_animation_queue.append_array(events)
			call_deferred("_play_next_animation")
			return

	_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	snapshot = _snapshot
	if not is_instance_valid(_root):
		return

	var has_table := str(snapshot.get("tableCode", "")) != ""
	if not has_table:
		return

	debug_stats = {
		"participantCount": snapshot.get("participants", []).size(),
		"handGroupCount": 0,
		"recipeSlotCount": 0,
		"recipeName": "",
		"dishSummaryCount": 0,
		"platterGroupCount": 0,
		"takeBiteEnabled": false,
		"completeCelebration": false,
		"completeBiteSummaryCount": 0,
		"offerPopupHeight": 0,
		"menuButtonVisible": false,
		"menuActions": [],
		"incomingOfferCount": _offer_count(true),
		"outgoingOfferCount": _offer_count(false),
		"currentTurnParticipantId": str(snapshot.get("currentTurnParticipantId", "")),
		"phase": str(snapshot.get("phase", "")),
		"animationEventCount": 0,
		"animationActorParticipantId": _animation_actor_participant_id,
		"lastAnimationTypes": [],
		"lastAnimationEvents": [],
		"lastDepositBasketSlots": [],
		"actionButtonTexts": [],
		"disabledActionButtonTexts": []
	}

	_render_menu()
	_render_turn_action()
	_render_participants()
	_render_basket()
	_render_redeem_box()
	_render_recipe()
	_render_hand()
	_render_inventory()


func debug_press_hand_ingredient(ingredient_id: String) -> void:
	var group := _hand_group_for_ingredient(ingredient_id)
	if group.is_empty():
		return
	_on_hand_group_pressed(group)


func debug_press_platter_ingredient(ingredient_id: String) -> void:
	var group := _voucher_group_for_ingredient(_snapshot.get("platter", []), ingredient_id)
	if group.is_empty():
		return
	_on_platter_voucher_group_pressed(group)


func debug_press_participant(participant_id: String) -> void:
	_on_participant_pressed(participant_id)


func debug_selected_hand_ingredient() -> String:
	return _selected_hand_ingredient_id


func debug_clear_selections() -> void:
	_clear_selections()


func debug_press_own_food_part(dish_name: String) -> void:
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) == dish_name:
			_on_inventory_food_group_pressed(group)
			return


func debug_press_first_incoming_offer_accept() -> void:
	for raw_offer in _snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("toParticipantId", "")) == _viewer_id() and str(offer.get("status", "")) == "pending":
			_accept_offer(offer)
			return


func debug_press_pass_turn_action() -> void:
	_pass_turn_action()


func debug_press_take_bite_action() -> void:
	_take_bite_action()


func debug_press_swap_selected() -> void:
	_swap_selected_playing_asset()


func debug_confirm_swap_popup() -> void:
	_confirm_swap_popup(str(_snapshot.get("phase", "")))


func debug_open_table_menu() -> void:
	_open_table_menu()


func debug_table_menu_visible() -> bool:
	return is_instance_valid(_menu_popup) and _menu_popup.visible


func debug_close_table_menu_at(global_point: Vector2) -> void:
	_close_menu_if_click_outside(global_point)


func debug_press_offer_selected_to_common_basket() -> void:
	_offer_selected_to_common_basket()


func debug_play_animation_event(event: Dictionary) -> void:
	_play_animation_event(event)


func debug_flush_animations() -> void:
	var final_pending_snapshot: Dictionary = {}
	if not _pending_visual_snapshots.is_empty():
		final_pending_snapshot = (_pending_visual_snapshots[_pending_visual_snapshots.size() - 1] as Dictionary).duplicate(true)
	elif _has_pending_visual_snapshot:
		final_pending_snapshot = _pending_visual_snapshot.duplicate(true)
	_animation_queue.clear()
	_animation_running = false
	_animation_deadline_msec = 0
	_current_animation_event = {}
	_animation_actor_participant_id = ""
	_pending_visual_snapshot = {}
	_has_pending_visual_snapshot = false
	_pending_visual_snapshots.clear()
	if not final_pending_snapshot.is_empty():
		_apply_snapshot(final_pending_snapshot)


func debug_apply_snapshot(snapshot: Dictionary) -> void:
	_animation_queue.clear()
	_animation_running = false
	_animation_deadline_msec = 0
	_current_animation_event = {}
	_animation_actor_participant_id = ""
	_pending_visual_snapshot = {}
	_has_pending_visual_snapshot = false
	_pending_visual_snapshots.clear()
	_apply_snapshot(snapshot)


func debug_apply_next_animation_milestone() -> String:
	_animation_running = false
	var event: Dictionary = {}
	if not _current_animation_event.is_empty():
		event = _current_animation_event
		_current_animation_event = {}
	elif not _animation_queue.is_empty():
		event = _animation_queue.pop_front()
	if event.is_empty():
		return ""
	_animation_actor_participant_id = ""
	_apply_animation_event_snapshot(event)
	if _animation_queue.is_empty():
		_apply_pending_visual_snapshot(false)
	return str(event.get("type", ""))


func debug_apply_current_animation_midpoint() -> String:
	return _debug_apply_current_animation_snapshot("_snapshotMid")


func debug_apply_current_animation_start() -> String:
	return _debug_apply_current_animation_snapshot("_snapshotStart")


func debug_apply_current_animation_take_start() -> String:
	return _debug_apply_current_animation_snapshot("_snapshotTakeStart")


func debug_animation_handoff_timings() -> Dictionary:
	return {
		"cardLanding": CARD_TILE_LANDING_SECONDS,
		"cardFadeOutEnd": CARD_TILE_LANDING_SECONDS + CARD_TILE_FADE_OUT_SECONDS,
		"swapMid": SWAP_MID_SNAPSHOT_SECONDS,
		"swapTakeStart": SWAP_TAKE_START_SECONDS,
		"swapReturnVisible": SWAP_TAKE_START_SECONDS,
		"swapFinish": SWAP_FINISH_SECONDS,
		"swapReturnFadeOutEnd": SWAP_FINISH_SECONDS + CARD_TILE_FADE_OUT_SECONDS,
		"redeemFinish": REDEEM_FINISH_SECONDS,
		"redeemIngredientFadeOutEnd": REDEEM_FINISH_SECONDS + TEXTURE_FADE_OUT_SECONDS
	}


func debug_current_swap_take_end_point() -> Vector2:
	var event: Dictionary = {}
	if not _current_animation_event.is_empty():
		event = _current_animation_event
	elif not _animation_queue.is_empty():
		event = _animation_queue[0]
	if event.is_empty():
		return Vector2.INF
	return _swap_point(event, "takeEndPoint", _swap_take_end_center(event))


func _debug_apply_current_animation_snapshot(snapshot_key: String) -> String:
	var event: Dictionary = {}
	if not _current_animation_event.is_empty():
		event = _current_animation_event
	elif not _animation_queue.is_empty():
		event = _animation_queue[0]
	if event.is_empty() or not event.has(snapshot_key):
		return ""
	var snapshot: Dictionary = event.get(snapshot_key, {})
	if snapshot.is_empty():
		return ""
	_apply_snapshot(snapshot)
	return str(event.get("type", ""))


func debug_visible_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func preferred_visual_size() -> Vector2:
	return Vector2(TABLE_CONTENT_WIDTH + 20.0, TABLE_CONTENT_HEIGHT)


func debug_deposit_animation_anchors() -> Array:
	var anchors: Array = []
	var events: Array = []
	if not _current_animation_event.is_empty() and str(_current_animation_event.get("type", "")) == "deposit":
		events.append(_current_animation_event)
	for raw_event in _animation_queue:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "deposit":
			events.append(event)
	for raw_event in events:
		var event: Dictionary = raw_event
		var ingredient_id := str(event.get("ingredientId", ""))
		var start = event.get("startPoint", _participant_or_hand_center(str(event.get("participantId", "")), ingredient_id))
		var end = event.get("endPoint", _platter_voucher_center(ingredient_id))
		if end == Vector2.INF:
			end = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
		anchors.append({
			"participantId": str(event.get("participantId", "")),
			"ingredientId": ingredient_id,
			"basketSlotIndex": int(event.get("basketSlotIndex", -1)),
			"start": start,
			"end": end
		})
	return anchors


func debug_animation_path_points(event: Dictionary) -> Dictionary:
	match str(event.get("type", "")):
		"swap", "settlement_swap":
			return {
				"giveStart": _swap_point(event, "giveStartPoint", _swap_give_start_center(event)),
				"giveEnd": _swap_point(event, "giveEndPoint", _swap_give_end_center(event)),
				"takeStart": _swap_point(event, "takeStartPoint", _swap_take_start_center(event)),
				"takeEnd": _swap_point(event, "takeEndPoint", _swap_take_end_center(event))
			}
		"public_redeem":
			return {
				"cardStart": _redeem_point(event, "cardStartPoint", _public_redeem_actor_center(event)),
				"cardEnd": _redeem_point(event, "ownerPoint", _redeem_owner_center(event)),
				"ingredientStart": _redeem_point(event, "ownerPoint", _redeem_owner_center(event)),
				"ingredientEnd": _redeem_point(event, "ingredientEndPoint", _public_redeem_actor_center(event))
			}
		"redeem":
			return {
				"cardStart": _redeem_point(event, "cardStartPoint", _redeem_card_start_center(str(event.get("ingredientId", "")))),
				"cardEnd": _redeem_point(event, "ownerPoint", _redeem_owner_center(event)),
				"ingredientStart": _redeem_point(event, "ownerPoint", _redeem_owner_center(event)),
				"ingredientEnd": _redeem_point(event, "recipeSlotPoint", _redeem_recipe_slot_center(str(event.get("ingredientId", "")), int(event.get("slotIndex", 0))))
			}
		"exchange":
			return _exchange_debug_path_points(event)
		_:
			return {}


func _build() -> void:
	add_theme_stylebox_override("panel", _panel_style(TABLE_BG, PANEL_BORDER, 2, 8))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH + 20, TABLE_CONTENT_HEIGHT)

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 4)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_root)

	_overlay_layer = Control.new()
	_overlay_layer.name = "TableOverlayLayer"
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay_layer)

	_animation_layer = Control.new()
	_animation_layer.name = "AnimationLayer"
	_animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_animation_layer)

	_menu_canvas = CanvasLayer.new()
	_menu_canvas.layer = 9
	add_child(_menu_canvas)
	_menu_button = _menu_button_control()
	_menu_button.pressed.connect(_open_table_menu)
	_menu_canvas.add_child(_menu_button)
	_position_menu_button()

	var participant_panel := _titled_panel("Cooks", true)
	_root.add_child(participant_panel)
	_participant_row = VBoxContainer.new()
	_participant_row.add_theme_constant_override("separation", 2)
	_participant_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	participant_panel.add_child(_center_wrap(_participant_row, 222))

	var basket_panel := VBoxContainer.new()
	basket_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(basket_panel)
	var basket_backdrop := BasketBackdrop.new()
	basket_backdrop.name = "BasketBackdrop"
	basket_backdrop.custom_minimum_size = BASKET_BACKDROP_SIZE
	basket_backdrop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	basket_backdrop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	basket_backdrop.add_theme_stylebox_override("panel", _basket_backdrop_style())
	var basket_margin := MarginContainer.new()
	basket_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basket_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	basket_margin.add_theme_constant_override("margin_left", 0)
	basket_margin.add_theme_constant_override("margin_top", 32)
	basket_margin.add_theme_constant_override("margin_right", 0)
	basket_margin.add_theme_constant_override("margin_bottom", 8)
	var basket_center := CenterContainer.new()
	basket_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basket_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_basket_grid = GridContainer.new()
	_basket_grid.columns = 4
	_basket_grid.custom_minimum_size = BASKET_GRID_SIZE
	_basket_grid.add_theme_constant_override("h_separation", BASKET_GRID_GAP)
	_basket_grid.add_theme_constant_override("v_separation", BASKET_GRID_GAP)
	_basket_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_basket_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	basket_center.add_child(_basket_grid)
	basket_margin.add_child(basket_center)
	basket_backdrop.add_child(basket_margin)
	basket_panel.add_child(basket_backdrop)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(middle)

	_redeem_box = VBoxContainer.new()
	_redeem_box.custom_minimum_size = Vector2(0, 0)
	_redeem_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redeem_box.add_theme_constant_override("separation", 5)
	var action_panel := _framed_box(_redeem_box)
	action_panel.custom_minimum_size = Vector2(226, 0)
	action_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	middle.add_child(action_panel)

	var recipe_panel := VBoxContainer.new()
	recipe_panel.add_theme_constant_override("separation", 4)
	recipe_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	middle.add_child(recipe_panel)
	_recipe_name_label = _label("")
	_recipe_name_label.add_theme_font_size_override("font_size", 16)
	_recipe_name_label.add_theme_color_override("font_color", TEXT_DARK)
	recipe_panel.add_child(_recipe_name_label)
	_recipe_grid = GridContainer.new()
	_recipe_grid.columns = 3
	_recipe_grid.custom_minimum_size = RECIPE_GRID_SIZE
	_recipe_grid.add_theme_constant_override("h_separation", RECIPE_GRID_GAP)
	_recipe_grid.add_theme_constant_override("v_separation", RECIPE_GRID_GAP)
	_recipe_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	recipe_panel.add_child(_recipe_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(bottom)

	var inventory_panel := _titled_panel("Inventory")
	_inventory_title_label = inventory_panel.get_child(0) as Label
	inventory_panel.custom_minimum_size = Vector2(150, 0)
	inventory_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom.add_child(inventory_panel)
	_inventory_row = HBoxContainer.new()
	_inventory_row.name = "InventoryRow"
	_inventory_row.add_theme_constant_override("separation", 6)
	inventory_panel.add_child(_scroll_wrap(_inventory_row, 104))

	var hand_panel := _titled_panel("Promise Cards")
	hand_panel.custom_minimum_size = Vector2(330, 0)
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hand_panel)
	_hand_row = HBoxContainer.new()
	_hand_row.name = "HandRow"
	_hand_row.add_theme_constant_override("separation", 7)
	hand_panel.add_child(_scroll_wrap(_hand_row, 104))

	_offer_popup = PopupPanel.new()
	_offer_popup.name = "OfferPopup"
	_configure_transient_popup(_offer_popup)
	_offer_popup.add_theme_stylebox_override("panel", _offer_popup_panel_style())
	_offer_popup_scroller = ScrollContainer.new()
	_offer_popup_scroller.name = "OfferPopupScroller"
	_offer_popup_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offer_popup_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_popup_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_popup_list = VBoxContainer.new()
	_offer_popup_list.add_theme_constant_override("separation", 4)
	_offer_popup_list.custom_minimum_size = Vector2(276, 0)
	_offer_popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_popup_scroller.add_child(_offer_popup_list)
	_offer_popup.add_child(_offer_popup_scroller)
	add_child(_offer_popup)

	_menu_popup = PopupPanel.new()
	_configure_persistent_popup(_menu_popup)
	_menu_popup.add_theme_stylebox_override("panel", _offer_popup_panel_style())
	_menu_popup_list = VBoxContainer.new()
	_menu_popup_list.add_theme_constant_override("separation", 4)
	_menu_popup_list.custom_minimum_size = Vector2(196, 0)
	_menu_popup.add_child(_menu_popup_list)
	add_child(_menu_popup)


func _render_menu() -> void:
	if not is_instance_valid(_menu_button):
		return
	_sync_menu_visibility()
	debug_stats["menuActions"] = _table_menu_actions()


func _process(_delta: float) -> void:
	_finish_stalled_animation_if_needed()
	_sync_menu_visibility(false)


func _menu_should_be_visible() -> bool:
	var has_table := str(_snapshot.get("tableCode", "")) != ""
	var phase := str(_snapshot.get("phase", ""))
	return has_table and phase != "lobby" and is_visible_in_tree()


func _sync_menu_visibility(update_debug := true) -> void:
	if not is_instance_valid(_menu_button):
		return
	_position_menu_button()
	var should_show := _menu_should_be_visible()
	_menu_button.visible = should_show
	if is_instance_valid(_menu_canvas):
		_menu_canvas.visible = should_show
	if not should_show and is_instance_valid(_menu_popup):
		_menu_popup.hide()
	if update_debug:
		debug_stats["menuButtonVisible"] = should_show


func _position_menu_button() -> void:
	if not is_instance_valid(_menu_button):
		return
	_menu_button.position = get_global_rect().position + Vector2(10, 10)


func _table_menu_actions() -> Array[String]:
	var actions: Array[String] = ["View History"]
	var phase := str(_snapshot.get("phase", ""))
	if bool(_snapshot.get("viewerCanUseHostControls", false)) and phase != "complete" and phase != "lobby":
		actions.append("End Game")
	return actions


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_menu_if_click_outside(mouse_event.position)


func _close_menu_if_click_outside(global_point: Vector2) -> void:
	if not is_instance_valid(_menu_popup) or not _menu_popup.visible:
		return
	if is_instance_valid(_menu_button) and _menu_button.get_global_rect().has_point(global_point):
		return
	var popup_rect := Rect2(Vector2(_menu_popup.position), Vector2(_menu_popup.size))
	if popup_rect.has_point(global_point):
		return
	_menu_popup.hide()


func _open_table_menu() -> void:
	if not is_instance_valid(_menu_popup) or not is_instance_valid(_menu_popup_list):
		return
	if _menu_popup.visible:
		_menu_popup.hide()
		return
	_clear(_menu_popup_list)
	var actions := _table_menu_actions()
	for action in actions:
		_menu_popup_list.add_child(_menu_popup_button(action))
	var width := 210
	var height := maxi(48, actions.size() * 42 + 10)
	var button_rect := _menu_button.get_global_rect()
	var popup_position := Vector2i(int(button_rect.position.x), int(button_rect.end.y + 4.0))
	_menu_popup.popup(Rect2i(popup_position, Vector2i(width, height)))


func _menu_popup_button(action: String) -> Button:
	var button := _button(action, func(selected_action := action) -> void:
		if is_instance_valid(_menu_popup):
			_menu_popup.hide()
		menu_requested.emit(selected_action)
	)
	button.custom_minimum_size = Vector2(196, 38)
	button.add_theme_font_size_override("font_size", 15)
	if action == "End Game":
		_apply_button_style(button, Color(0.62, 0.24, 0.14), Color(0.34, 0.12, 0.06), 2)
	else:
		_apply_button_style(button, Color(0.90, 0.78, 0.55), Color(0.48, 0.34, 0.18), 1)
	return button


func _configure_persistent_popup(window: Window) -> void:
	if not is_instance_valid(window):
		return
	window.set("popup_window", false)


func _configure_transient_popup(window: Window) -> void:
	if not is_instance_valid(window):
		return
	window.set("popup_window", true)


func _render_participants() -> void:
	_clear(_participant_row)
	var viewer_id := _viewer_id()
	var visual_actor_id := _current_visual_actor_id()
	var visible_participants: Array = []
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if participant_id == viewer_id or str(participant.get("role", "")) != "active":
			continue
		visible_participants.append(participant)

	for row_start in range(0, visible_participants.size(), 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_participant_row.add_child(row)

		var row_end = mini(row_start + 4, visible_participants.size())
		for index in range(row_start, row_end):
			var participant: Dictionary = visible_participants[index]
			var participant_id := str(participant.get("id", ""))
			var indicator := _offer_indicator_for_participant(participant_id)
			var name := str(participant.get("name", "Player"))
			var ingredient_id := str(participant.get("ingredientId", ""))
			var meta := VisualAssets.ingredient_meta(ingredient_id)
			var top_label := name
			var bottom_label := ""
			if ingredient_id != "":
				bottom_label = _ingredient_display(ingredient_id)
				if participant.has("realIngredientStock"):
					bottom_label = "%s x%s" % [bottom_label, int(participant.get("realIngredientStock", 0))]
			var is_visually_acting := participant_id == visual_actor_id
			var button := _player_tile(top_label, bottom_label, meta, indicator, is_visually_acting, COOK_TILE_SIZE, func(id := participant_id) -> void:
				_on_participant_pressed(id)
			)
			button.name = "Participant_%s" % participant_id
			if is_visually_acting:
				button.modulate = Color(1.05, 1.0, 0.86)
			row.add_child(button)

	if _participant_row.get_child_count() == 0:
		_participant_row.add_child(_row_message("Other players appear here."))
	debug_stats["participantCount"] = visible_participants.size()


func _render_turn_action() -> void:
	return


func _current_visual_actor_id() -> String:
	if _animation_actor_participant_id != "":
		return _animation_actor_participant_id
	return str(_snapshot.get("currentTurnParticipantId", ""))


func _viewer_is_visually_acting() -> bool:
	return _current_visual_actor_id() == _viewer_id()


func _render_basket() -> void:
	_clear(_basket_grid)
	var count := 0
	var voucher_groups_by_ingredient := _voucher_groups_by_ingredient(_snapshot.get("platter", []))
	var ingredient_by_slot := _basket_ingredient_by_visual_slot()
	var visual_order := _basket_ingredients_by_visual_slot()
	debug_stats["basketVisualOrder"] = visual_order.duplicate()
	for visual_slot_index in range(BASKET_CENTER_OUT_SLOTS.size()):
		var ingredient_id := str(ingredient_by_slot.get(visual_slot_index, ""))
		if ingredient_id == "":
			_basket_grid.add_child(_basket_empty_slot(visual_slot_index))
			continue
		var group: Dictionary = voucher_groups_by_ingredient.get(ingredient_id, {})
		if not group.is_empty():
			count += 1
		_basket_grid.add_child(_basket_ingredient_slot(ingredient_id, group, visual_slot_index))

	for raw_group in _food_part_group_options(_snapshot.get("platterFoodParts", [])):
		var group: Dictionary = raw_group
		count += 1
		var unit := str(group.get("unitSingular", "part"))
		var dish_name := str(group.get("dishName", "Dish"))
		var meta := VisualAssets.dish_meta(dish_name, unit)
		var label := "%s x%s" % [VisualAssets.short_dish_name(dish_name), int(group.get("count", 0))]
		var button := _visual_card("", label, meta, BASKET_SLOT_SIZE, func(g := group) -> void:
			_on_platter_food_group_pressed(g)
		)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.name = "PlatterFood_%s" % str(group.get("dishId", "dish"))
		if _selected_platter_asset_key == "dish_part:%s" % str(group.get("partId", "")):
			_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.08, 0.28, 0.60), 3)
		_basket_grid.add_child(button)

	debug_stats["platterGroupCount"] = count


func _basket_empty_slot(visual_slot_index: int) -> Control:
	var slot := CenterContainer.new()
	slot.name = "BasketSlot_empty_%s" % visual_slot_index
	slot.set_meta("basket_slot_index", visual_slot_index)
	slot.custom_minimum_size = BASKET_SLOT_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	return slot


func _basket_ingredient_slot(ingredient_id: String, group: Dictionary, visual_slot_index: int) -> Control:
	var slot := CenterContainer.new()
	slot.name = "BasketSlot_%s" % ingredient_id
	slot.set_meta("basket_slot_index", visual_slot_index)
	slot.custom_minimum_size = BASKET_SLOT_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	if group.is_empty():
		return slot

	var meta := VisualAssets.ingredient_meta(ingredient_id)
	var label := "%s x%s" % [
		_ingredient_display(ingredient_id),
		int(group.get("count", 0))
	]
	var button := _visual_card("", label, meta, BASKET_SLOT_SIZE, func(g := group) -> void:
		_on_platter_voucher_group_pressed(g)
	)
	button.name = "PlatterVoucher_%s" % ingredient_id
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _selected_platter_asset_key == "voucher:%s" % str(group.get("voucherId", "")):
		_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.08, 0.28, 0.60), 3)
	slot.add_child(button)
	return slot


func _voucher_groups_by_ingredient(vouchers: Array) -> Dictionary:
	var groups := {}
	for raw_group in _voucher_group_options(vouchers):
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		if ingredient_id != "":
			groups[ingredient_id] = group
	return groups


func _basket_ingredients_by_visual_slot() -> Array[String]:
	var by_slot := _basket_ingredient_by_visual_slot()
	var visual_order: Array[String] = []
	for slot_index in range(BASKET_CENTER_OUT_SLOTS.size()):
		if by_slot.has(slot_index):
			visual_order.append(str(by_slot[slot_index]))
	return visual_order


func _basket_ingredient_by_visual_slot() -> Dictionary:
	_ensure_basket_slot_mapping()
	var by_slot := {}
	for raw_ingredient_id in _basket_ingredient_order():
		var ingredient_id := str(raw_ingredient_id)
		if ingredient_id != "" and _basket_slot_by_ingredient.has(ingredient_id):
			by_slot[int(_basket_slot_by_ingredient.get(ingredient_id))] = ingredient_id
	return by_slot


func _ensure_basket_slot_mapping() -> void:
	var key := _basket_slot_mapping_key(_snapshot)
	if key != _basket_slot_table_key:
		_basket_slot_table_key = key
		_basket_slot_by_ingredient.clear()

	for raw_ingredient_id in _basket_ingredient_order():
		var ingredient_id := str(raw_ingredient_id)
		if ingredient_id == "" or _basket_slot_by_ingredient.has(ingredient_id):
			continue
		var rank := _basket_slot_by_ingredient.size()
		if rank >= BASKET_CENTER_OUT_SLOTS.size():
			return
		_basket_slot_by_ingredient[ingredient_id] = int(BASKET_CENTER_OUT_SLOTS[rank])


func _reset_basket_slot_mapping() -> void:
	_basket_slot_by_ingredient.clear()
	_basket_slot_table_key = ""


func _basket_slot_mapping_key(snapshot: Dictionary) -> String:
	var code := str(snapshot.get("tableCode", ""))
	var ingredients: Array[String] = []
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var ingredient_id := str(participant.get("ingredientId", ""))
		if ingredient_id != "":
			ingredients.append(ingredient_id)
	return "%s:%s" % [code, ",".join(ingredients)]


func _basket_ingredient_order() -> Array[String]:
	var ids: Array[String] = []
	for participant_id in _deposit_participant_order_from_transactions(_snapshot):
		var participant := _participant_from_snapshot(_snapshot, participant_id)
		var ingredient_id := str(participant.get("ingredientId", ""))
		if ingredient_id != "" and not ids.has(ingredient_id):
			ids.append(ingredient_id)

	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var ingredient_id := str(participant.get("ingredientId", ""))
		if str(participant.get("role", "")) == "active" and ingredient_id != "" and not ids.has(ingredient_id):
			ids.append(ingredient_id)

	for raw_ingredient in _snapshot.get("ingredients", []):
		var ingredient: Dictionary = raw_ingredient
		var ingredient_id := str(ingredient.get("id", ""))
		if ingredient_id != "" and not ids.has(ingredient_id):
			ids.append(ingredient_id)

	for default_id in DEFAULT_INGREDIENT_ORDER:
		if not ids.has(default_id):
			ids.append(default_id)

	for raw_group in _voucher_group_options(_snapshot.get("platter", [])):
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		if ingredient_id != "" and not ids.has(ingredient_id):
			ids.append(ingredient_id)

	return ids.slice(0, BASKET_CENTER_OUT_SLOTS.size())


func _render_redeem_box() -> void:
	_clear(_redeem_box)
	var title := _label("Actions")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	_redeem_box.add_child(title)
	var phase := str(_snapshot.get("phase", "lobby"))
	if phase == "deposit":
		_render_deposit_action_controls()
	elif phase == "playing":
		_render_playing_action_controls()
	elif phase == "settlement":
		_render_settlement_action_controls()
	elif phase == "eating":
		_render_eating_action_controls()
	elif phase == "complete":
		_redeem_box.add_child(_action_label("All bites are done."))
	else:
		_redeem_box.add_child(_action_label("Recipe actions appear during play."))
	_render_pass_turn_action()


func _render_pass_turn_action() -> void:
	if not _can_pass_turn_now():
		return
	_redeem_box.add_child(_action_button(_pass_turn_text(), func() -> void:
		_pass_turn_action()
	))


func _render_deposit_action_controls() -> void:
	if not _can_act_in_deposit():
		_redeem_box.add_child(_action_label("Offering given. Waiting for the table."))
		return
	if _selected_hand_voucher_id == "":
		_redeem_box.add_child(_action_label("Tap a promise card to select it."))
		return
	_redeem_box.add_child(_action_label("Selected: %s" % _ingredient_display(_selected_hand_ingredient_id)))
	_redeem_box.add_child(_action_button("Offer", _offer_selected_to_common_basket))


func _render_playing_action_controls() -> void:
	if _is_round_robin_off_turn("playing"):
		_redeem_box.add_child(_action_label("Wait while other cooks take their turns."))
		return
	if _selected_hand_voucher_id == "" and _selected_inventory_asset_key == "":
		_redeem_box.add_child(_action_label("Tap a promise card to select it."))
	else:
		_redeem_box.add_child(_action_label("Choose a needed card in basket or from another player."))
	_render_prepare_action_control()


func _render_prepare_action_control() -> void:
	var recipe: Dictionary = _snapshot.get("ownRecipe", {})
	if recipe.is_empty():
		return
	var ready := _recipe_ready(recipe)
	if not ready or not _can_act_now("playing"):
		_prepare_button = null
		return
	_prepare_button = _action_button("Prepare Dish", func() -> void:
		if _can_act_now("playing"):
			intent_requested.emit({"type": "prepare"})
	)
	_redeem_box.add_child(_prepare_button)


func _render_settlement_action_controls() -> void:
	var give_label := _asset_label_from_key(_selected_inventory_asset_key)
	var take_label := _asset_label_from_key(_selected_platter_asset_key)
	if give_label == "" and take_label == "":
		_redeem_box.add_child(_action_label("Tap a promise card or dish piece to select it."))
	else:
		_redeem_box.add_child(_action_label("Choose an item in the basket."))


func _render_eating_action_controls() -> void:
	var viewer := _participant_by_id(_viewer_id())
	if not bool(viewer.get("cleared", false)):
		_redeem_box.add_child(_action_label("Clear your Common Basket account before eating."))
		return
	var groups := _food_part_group_options(_snapshot.get("ownFoodParts", []))
	if groups.is_empty():
		_redeem_box.add_child(_action_label("No finished dish pieces to eat."))
		return
	var group: Dictionary = groups[0]
	_redeem_box.add_child(_action_label("Ready to eat: %s" % VisualAssets.short_dish_name(str(group.get("dishName", "Dish")))))
	var button := _action_button("Take Bite", _take_bite_action)
	button.disabled = not _can_act_now("eating")
	debug_stats["takeBiteEnabled"] = not button.disabled
	_redeem_box.add_child(button)


func _render_recipe() -> void:
	_clear(_recipe_grid)
	if str(_snapshot.get("phase", "lobby")) == "complete":
		_recipe_name_label.visible = true
		_recipe_name_label.text = "Congratulations!"
		debug_stats["recipeName"] = "Congratulations!"
		debug_stats["recipeSlotCount"] = 0
		debug_stats["completeCelebration"] = true
		_render_complete_summary()
		return
	var recipe: Dictionary = _snapshot.get("ownRecipe", {})
	var recipe_name := _recipe_name(recipe)
	debug_stats["recipeName"] = recipe_name
	_recipe_name_label.visible = true
	_recipe_name_label.text = _recipe_title(recipe_name) if recipe_name != "" else "Dishes Made"
	debug_stats["recipeTitle"] = _recipe_name_label.text
	var slots := _recipe_slots(recipe)
	debug_stats["recipeSlotCount"] = slots.size()
	if slots.is_empty():
		_recipe_grid.columns = 2
		debug_stats["dishSummaryColumns"] = _recipe_grid.columns
		_render_dish_count_summary()
	else:
		_recipe_grid.columns = 3
		for index in range(slots.size()):
			var slot: Dictionary = slots[index]
			_recipe_grid.add_child(_recipe_slot(slot, index))


func _render_dish_count_summary() -> void:
	var phase := str(_snapshot.get("phase", ""))
	if phase == "settlement" or phase == "eating":
		_render_held_piece_summary()
		return
	var target := int(_snapshot.get("targetDishCount", 0))
	var count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var line := "%s\n%s" % [
			str(participant.get("name", "Player")),
			int(participant.get("dishCount", 0))
		]
		if target > 0:
			line += "/%s" % target
		_recipe_grid.add_child(_dish_summary_cell(line))
		count += 1
	if count == 0:
		_recipe_grid.add_child(_muted_label("No dishes made yet."))
	debug_stats["dishSummaryCount"] = count


func _render_held_piece_summary() -> void:
	var count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var pieces := _held_food_part_count(participant)
		var unit := "piece" if pieces == 1 else "pieces"
		_recipe_grid.add_child(_dish_summary_cell("%s\n%s %s" % [
			str(participant.get("name", "Player")),
			pieces,
			unit
		]))
		count += 1
	if count == 0:
		_recipe_grid.add_child(_muted_label("No pieces available."))
	debug_stats["dishSummaryCount"] = count
	debug_stats["pieceSummaryCount"] = count
	debug_stats["pieceSummaryTotal"] = _held_food_part_total()


func _held_food_part_count(participant: Dictionary) -> int:
	if participant.has("heldFoodPartCount"):
		return int(participant.get("heldFoodPartCount", 0))
	var participant_id := str(participant.get("id", ""))
	if participant_id == _viewer_id():
		return _snapshot.get("ownFoodParts", []).size()
	return max(0, int(participant.get("dishCount", 0)) * 10)


func _held_food_part_total() -> int:
	var total := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		total += _held_food_part_count(participant)
	return total


func _render_complete_summary() -> void:
	_recipe_grid.columns = 2
	debug_stats["dishSummaryColumns"] = _recipe_grid.columns
	_recipe_grid.add_child(_celebration_label("Party fireworks"))
	_recipe_grid.add_child(_celebration_label("All bites are done."))

	var bite_totals := _bite_totals_by_participant()
	var count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		var bites := int(bite_totals.get(participant_id, 0))
		_recipe_grid.add_child(_dish_summary_cell("%s\n%s bites" % [str(participant.get("name", "Player")), bites]))
		count += 1
	debug_stats["completeBiteSummaryCount"] = count


func _bite_totals_by_participant() -> Dictionary:
	var totals := {}
	for raw_dish in _snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		var bite_counts: Dictionary = dish.get("biteCounts", {})
		for participant_id in bite_counts.keys():
			var key := str(participant_id)
			totals[key] = int(totals.get(key, 0)) + int(bite_counts.get(participant_id, 0))
	return totals


func _dish_summary_cell(text: String) -> Label:
	var label := _muted_label(text)
	label.custom_minimum_size = Vector2(112, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _celebration_label(text: String) -> Label:
	var label := _label(text)
	label.custom_minimum_size = Vector2(180, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label


func _render_hand() -> void:
	_clear(_hand_row)
	var count := 0
	var voucher_groups := _voucher_group_options(_snapshot.get("ownHand", []))
	voucher_groups.reverse()
	for raw_group in voucher_groups:
		var group: Dictionary = raw_group
		count += 1
		var ingredient_id := str(group.get("ingredientId", ""))
		var meta := VisualAssets.ingredient_meta(ingredient_id)
		var has_stock := _voucher_group_has_stock(group)
		var label := "%s x%s" % [
			_ingredient_display(ingredient_id),
			int(group.get("count", 0))
		]
		if not has_stock:
			label += "\nNo stock"
		var button := _visual_card("", label, meta, Vector2(96, 88), func(g := group) -> void:
			_on_hand_group_pressed(g)
		)
		button.name = "HandCard_%s" % ingredient_id
		if _selected_hand_voucher_id == str(group.get("voucherId", "")):
			_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.08, 0.28, 0.60), 3)
		elif str(_snapshot.get("phase", "lobby")) == "deposit" and _can_act_in_deposit():
			_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(1.0, 0.78, 0.12), 4)
		button.disabled = not _can_select_or_use_hand_card() or not has_stock
		_hand_row.add_child(button)
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		var unit := str(group.get("unitSingular", "part"))
		var dish_name := str(group.get("dishName", "Dish"))
		var meta := VisualAssets.dish_meta(dish_name, unit)
		var label := "%s x%s" % [VisualAssets.short_dish_name(dish_name), int(group.get("count", 0))]
		var button := _plain_asset_item(label, meta, Vector2(104, 88), func(g := group) -> void:
			_on_inventory_food_group_pressed(g)
		)
		button.name = "HandFood_%s" % str(group.get("dishId", "dish"))
		if _selected_inventory_asset_key == "dish_part:%s" % str(group.get("partId", "")):
			_apply_plain_item_highlight(button, Color(0.08, 0.28, 0.60), 2)
		_hand_row.add_child(button)
	debug_stats["handGroupCount"] = count
	if _hand_row.get_child_count() == 0:
		_hand_row.add_child(_row_message("No cards in hand."))


func _render_inventory() -> void:
	_clear(_inventory_row)
	var viewer := _participant_by_id(_viewer_id())
	if is_instance_valid(_inventory_title_label):
		var viewer_name := str(viewer.get("name", "")).strip_edges()
		_inventory_title_label.text = "%s Inv." % viewer_name if viewer_name != "" else "Inv."
		if _viewer_is_visually_acting():
			_inventory_title_label.add_theme_color_override("font_color", Color(0.34, 0.18, 0.04))
			_inventory_title_label.add_theme_color_override("font_outline_color", Color(1.0, 0.78, 0.18, 0.85))
			_inventory_title_label.add_theme_constant_override("outline_size", 2)
		else:
			_inventory_title_label.add_theme_color_override("font_color", TEXT_DARK)
			_inventory_title_label.add_theme_constant_override("outline_size", 0)
		debug_stats["inventoryTitle"] = _inventory_title_label.text
	if not viewer.is_empty() and viewer.has("realIngredientStock") and str(viewer.get("ingredientId", "")) != "" and str(_snapshot.get("phase", "lobby")) != "lobby":
		var ingredient_id := str(viewer.get("ingredientId", ""))
		var meta := VisualAssets.ingredient_meta(ingredient_id)
		var stock_label := "%s x%s" % [_ingredient_display(ingredient_id), int(viewer.get("realIngredientStock", 0))]
		var stock_item := _plain_asset_item(stock_label, meta, Vector2(96, 88), Callable(), _viewer_is_visually_acting())
		stock_item.name = "InventoryStock_%s" % ingredient_id
		stock_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory_row.add_child(stock_item)

	if _inventory_row.get_child_count() == 0:
		_inventory_row.add_child(_row_message("Stock appears here."))


func _on_hand_group_pressed(group: Dictionary) -> void:
	var phase := str(_snapshot.get("phase", "lobby"))
	var voucher_id := str(group.get("voucherId", ""))
	var ingredient_id := str(group.get("ingredientId", ""))
	if voucher_id == "":
		return
	if not _voucher_group_has_stock(group):
		status_requested.emit("%s cards have no stock behind them." % _ingredient_display(ingredient_id))
		return
	if phase == "deposit":
		if not _can_act_in_deposit():
			status_requested.emit("This seat cannot give an offering now.")
			return
		_selected_hand_voucher_id = voucher_id
		_selected_hand_ingredient_id = ingredient_id
		status_requested.emit("Selected %s for the Common Basket." % _ingredient_display(ingredient_id))
		render(_snapshot)
		return
	if not _can_act_now(phase):
		status_requested.emit("Waiting for %s." % _participant_name(str(_snapshot.get("currentTurnParticipantId", ""))))
		return
	if phase == "playing":
		_selected_hand_voucher_id = voucher_id
		_selected_hand_ingredient_id = ingredient_id
		_selected_inventory_asset_key = "voucher:%s" % voucher_id
		status_requested.emit("Selected %s for a basket swap or offer." % _ingredient_display(ingredient_id))
		render(_snapshot)
	elif phase == "settlement":
		_selected_inventory_asset_key = "voucher:%s" % voucher_id
		_selected_hand_voucher_id = voucher_id
		_selected_hand_ingredient_id = ingredient_id
		status_requested.emit("Selected %s for settlement." % _ingredient_display(ingredient_id))
		render(_snapshot)


func _on_platter_voucher_group_pressed(group: Dictionary) -> void:
	var phase := str(_snapshot.get("phase", "lobby"))
	var take_id := str(group.get("voucherId", ""))
	var take_ingredient_id := str(group.get("ingredientId", ""))
	if take_id == "":
		return
	if phase == "playing":
		if not _can_act_now("playing"):
			status_requested.emit("This is not your turn.")
			return
		if _selected_inventory_asset_key == "":
			if not _auto_select_give_asset(take_ingredient_id, "playing"):
				status_requested.emit("No swappable card or dish piece is available.")
				return
		_selected_platter_asset_key = "voucher:%s" % take_id
		if _selected_inventory_asset_key.begins_with("voucher:") and take_ingredient_id == _selected_hand_ingredient_id:
			status_requested.emit("Choose a different ingredient to take.")
			render(_snapshot)
			return
		_swap_selected_playing_asset()
	elif phase == "settlement":
		if not _can_act_now("settlement"):
			status_requested.emit("This is not your turn.")
			return
		if _selected_inventory_asset_key == "":
			if not _auto_select_give_asset(take_ingredient_id, "settlement"):
				status_requested.emit("No swappable card or dish piece is available.")
				return
		_selected_platter_asset_key = "voucher:%s" % take_id
		_try_settlement_swap()
	else:
		status_requested.emit("Basket swaps open after offerings are complete.")


func _on_platter_food_group_pressed(group: Dictionary) -> void:
	var phase := str(_snapshot.get("phase", ""))
	if phase != "playing" and phase != "settlement":
		status_requested.emit("Food parts in the basket are used after offerings are complete.")
		return
	if phase == "playing" and not _can_act_now("playing"):
		status_requested.emit("This is not your turn.")
		return
	if not _can_act_now(phase):
		status_requested.emit("This is not your turn.")
		return
	if _selected_inventory_asset_key == "":
		if not _auto_select_give_asset("", phase):
			status_requested.emit("No swappable card or dish piece is available.")
			return
	_selected_platter_asset_key = "dish_part:%s" % str(group.get("partId", ""))
	if phase == "settlement":
		_try_settlement_swap()
	else:
		_swap_selected_playing_asset()


func _pass_turn_action() -> void:
	var phase := str(_snapshot.get("phase", "lobby"))
	var next_name := _next_turn_participant_name()
	if phase == "playing":
		status_requested.emit("Redeeming useful cards and passing turn%s." % ("" if next_name == "" else " to %s" % next_name))
		intent_requested.emit({"type": "redeem_all_and_pass_turn"})
	else:
		status_requested.emit("Passing turn%s." % ("" if next_name == "" else " to %s" % next_name))
		intent_requested.emit({"type": "pass_turn"})


func _offer_selected_to_common_basket() -> void:
	if _selected_hand_voucher_id == "":
		status_requested.emit("Select a card to offer.")
		return
	if not _can_act_in_deposit():
		status_requested.emit("This seat cannot give an offering now.")
		return
	intent_requested.emit({"type": "deposit", "voucherId": _selected_hand_voucher_id})
	status_requested.emit("Offering %s to the Common Basket." % _ingredient_display(_selected_hand_ingredient_id))
	_clear_selections()
	render(_snapshot)


func _swap_selected_playing_asset() -> void:
	if _selected_inventory_asset_key.begins_with("voucher:") and _selected_platter_asset_key.begins_with("voucher:"):
		_swap_selected_platter_vouchers()
		return
	_try_asset_swap("playing")


func _swap_selected_platter_vouchers() -> void:
	if _selected_hand_voucher_id == "" or _selected_platter_asset_key == "":
		status_requested.emit("Select one card and one basket card.")
		return
	if not _can_act_now("playing"):
		status_requested.emit("This is not your turn.")
		return
	if not _selected_platter_asset_key.begins_with("voucher:"):
		_try_asset_swap("playing")
		return
	var take_id := _selected_platter_asset_key.substr("voucher:".length())
	var take_ingredient_id := _ingredient_id_for_platter_voucher(take_id)
	if take_ingredient_id == "" or take_ingredient_id == _selected_hand_ingredient_id:
		status_requested.emit("Choose a different ingredient to take.")
		render(_snapshot)
		return
	intent_requested.emit({"type": "platter_swap", "giveVoucherId": _selected_hand_voucher_id, "takeVoucherId": take_id})
	status_requested.emit("Swapping %s for %s." % [_ingredient_display(_selected_hand_ingredient_id), _ingredient_display(take_ingredient_id)])
	_clear_selections()
	render(_snapshot)


func _same_ingredient_voucher_swap_selected() -> bool:
	if not _selected_inventory_asset_key.begins_with("voucher:") or not _selected_platter_asset_key.begins_with("voucher:"):
		return false
	if _selected_hand_ingredient_id == "":
		return false
	var take_id := _selected_platter_asset_key.substr("voucher:".length())
	var take_ingredient_id := _ingredient_id_for_platter_voucher(take_id)
	return take_ingredient_id != "" and take_ingredient_id == _selected_hand_ingredient_id


func _on_inventory_food_group_pressed(group: Dictionary) -> void:
	var phase := str(_snapshot.get("phase", "lobby"))
	if phase == "playing" or phase == "settlement":
		_selected_inventory_asset_key = "dish_part:%s" % str(group.get("partId", ""))
		_selected_hand_voucher_id = ""
		_selected_hand_ingredient_id = ""
		status_requested.emit("Selected %s for a basket swap." % VisualAssets.short_dish_name(str(group.get("dishName", "Dish"))))
		render(_snapshot)
	elif phase == "eating":
		var viewer := _participant_by_id(_viewer_id())
		if not bool(viewer.get("cleared", false)):
			status_requested.emit("Clear your basket account before eating.")
			return
		intent_requested.emit({"type": "bite", "dishId": str(group.get("dishId", ""))})
		status_requested.emit("Eating %s." % VisualAssets.short_dish_name(str(group.get("dishName", "Dish"))))


func _take_bite_action() -> void:
	if not _can_act_now("eating"):
		status_requested.emit("This is not your turn.")
		return
	var viewer := _participant_by_id(_viewer_id())
	if not bool(viewer.get("cleared", false)):
		status_requested.emit("Clear your Common Basket account before eating.")
		return
	var groups := _food_part_group_options(_snapshot.get("ownFoodParts", []))
	if groups.is_empty():
		status_requested.emit("No finished dish pieces to eat.")
		return
	var group: Dictionary = groups[0]
	intent_requested.emit({"type": "bite", "dishId": str(group.get("dishId", ""))})
	status_requested.emit("Taking a bite of %s." % VisualAssets.short_dish_name(str(group.get("dishName", "Dish"))))


func _try_settlement_swap() -> void:
	_try_asset_swap("settlement")


func _try_asset_swap(phase: String) -> void:
	if not _can_act_now(phase):
		status_requested.emit("This is not your turn.")
		return
	if _selected_inventory_asset_key == "" or _selected_platter_asset_key == "":
		status_requested.emit("Select one held card or food part, then one basket asset.")
		render(_snapshot)
		return
	intent_requested.emit({
		"type": "platter_asset_swap",
		"give": _asset_ref_from_key(_selected_inventory_asset_key),
		"take": _asset_ref_from_key(_selected_platter_asset_key)
	})
	status_requested.emit("Swapping selected assets.")
	_clear_selections()
	render(_snapshot)


func _on_participant_pressed(participant_id: String) -> void:
	if participant_id == "":
		return
	if _has_visible_offer_for_participant(participant_id):
		_open_offer_popup(participant_id)
		return
	if _selected_hand_voucher_id != "" and participant_id != _viewer_id() and str(_snapshot.get("phase", "")) == "playing":
		_open_create_offer_popup(participant_id)
		return
	if participant_id != _viewer_id() and str(_snapshot.get("phase", "")) == "playing":
		if _auto_select_give_card(""):
			_open_create_offer_popup(participant_id)
			return
	if _can_view_participant(participant_id):
		view_requested.emit(participant_id)
	else:
		status_requested.emit("Select a card, then tap another player to offer it.")


func _create_offer_to_participant(participant_id: String) -> void:
	if not _can_act_now("playing"):
		status_requested.emit("This is not your turn.")
		return
	var target := _participant_by_id(participant_id)
	if target.is_empty() or not _participant_can_receive_offer(target):
		status_requested.emit("That player cannot receive an offer right now.")
		return
	var requested_ingredient_id := str(target.get("ingredientId", ""))
	if requested_ingredient_id == "":
		return
	intent_requested.emit({
		"type": "create_offer",
		"toParticipantId": participant_id,
		"offeredVoucherIds": [_selected_hand_voucher_id],
		"requested": {"ingredientId": requested_ingredient_id, "quantity": 1}
	})
	status_requested.emit("Offering %s to %s for %s." % [
		_ingredient_display(_selected_hand_ingredient_id),
		_participant_name(participant_id),
		_ingredient_display(requested_ingredient_id)
	])
	_clear_selections()


func _open_create_offer_popup(participant_id: String) -> void:
	_clear(_offer_popup_list)
	_prepare_offer_popup_content(276)
	var target := _participant_by_id(participant_id)
	if target.is_empty() or not _participant_can_receive_offer(target):
		_offer_popup_list.add_child(_offer_popup_header("Offer"))
		var unavailable := _offer_popup_text("That player cannot receive an offer right now.")
		_offer_popup_list.add_child(unavailable)
		_popup_centered_tight(228, 120)
		return
	var requested_ingredient_id := str(target.get("ingredientId", ""))
	var row := _offer_popup_button_row()
	row.add_child(_offer_popup_compact_button("Create", func(id := participant_id) -> void:
		_create_offer_to_participant(id)
		_offer_popup.hide()
	))
	row.add_child(_offer_popup_compact_button("Cancel", func() -> void:
		_offer_popup.hide()
	))
	_offer_popup_list.add_child(_offer_popup_component(
		"Offer",
		participant_id,
		_selected_hand_ingredient_id,
		1,
		requested_ingredient_id,
		1,
		"with %s" % _participant_name(participant_id),
		row
	))
	_popup_centered_tight(310, 360, false)


func _open_swap_popup(phase: String) -> void:
	_clear(_offer_popup_list)
	_offer_popup_list.custom_minimum_size = Vector2(212, 0)
	_offer_popup_list.add_theme_constant_override("separation", 3)
	var title := _offer_popup_header("Swap")
	_offer_popup_list.add_child(title)
	var give_label := _asset_label_from_key(_selected_inventory_asset_key)
	var take_label := _asset_label_from_key(_selected_platter_asset_key)
	if give_label == "" or take_label == "":
		_offer_popup_list.add_child(_offer_popup_text("Choose one item to give and one basket item to take."))
	else:
		_offer_popup_list.add_child(_offer_popup_text("Give %s\nTake %s" % [give_label, take_label]))
	var row := _offer_popup_button_row()
	var swap_button := _offer_popup_compact_button("Swap", func(selected_phase := phase) -> void:
		_confirm_swap_popup(selected_phase)
	)
	swap_button.disabled = not _swap_popup_can_confirm(phase)
	row.add_child(swap_button)
	row.add_child(_offer_popup_compact_button("Cancel", func() -> void:
		_offer_popup.hide()
	))
	_offer_popup_list.add_child(row)
	_popup_centered_tight(230, 142)


func _swap_popup_can_confirm(phase: String) -> bool:
	if _selected_inventory_asset_key == "" or _selected_platter_asset_key == "":
		return false
	if not _can_act_now(phase):
		return false
	if _selected_inventory_asset_key.begins_with("voucher:") and _selected_platter_asset_key.begins_with("voucher:"):
		return not _same_ingredient_voucher_swap_selected()
	return true


func _confirm_swap_popup(phase: String) -> void:
	if not _swap_popup_can_confirm(phase):
		if _same_ingredient_voucher_swap_selected():
			status_requested.emit("Choose a different ingredient to take.")
		else:
			status_requested.emit("Choose one item to give and one basket item to take.")
		return
	_offer_popup.hide()
	if phase == "settlement":
		_try_settlement_swap()
	else:
		_swap_selected_playing_asset()


func _prepare_offer_popup_content(width: int) -> void:
	_offer_popup_list.custom_minimum_size = Vector2(width, 0)
	_offer_popup_list.add_theme_constant_override("separation", 6)


func _offer_popup_component(title_text: String, participant_id: String, give_ingredient_id: String, give_qty: int, get_ingredient_id: String, get_qty: int, detail_text: String, action_row: Control = null) -> Control:
	var box := VBoxContainer.new()
	box.name = "OfferPanel"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_offer_popup_header(title_text))
	if detail_text != "":
		box.add_child(_offer_popup_text(detail_text))
	box.add_child(_offer_card_pair(give_ingredient_id, give_qty, get_ingredient_id, get_qty))
	if action_row != null:
		box.add_child(action_row)
	box.add_child(_offer_recipe_context(participant_id))
	return box


func _offer_card_pair(give_ingredient_id: String, give_qty: int, get_ingredient_id: String, get_qty: int) -> Control:
	var center := CenterContainer.new()
	center.name = "OfferCardPair"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	row.add_child(_offer_ingredient_card("Give", give_ingredient_id, give_qty, "OfferGiveCard"))
	var arrow := _offer_popup_text("<->")
	arrow.custom_minimum_size = Vector2(24, 72)
	row.add_child(arrow)
	row.add_child(_offer_ingredient_card("Get", get_ingredient_id, get_qty, "OfferGetCard"))
	return center


func _offer_ingredient_card(title_text: String, ingredient_id: String, quantity: int, node_prefix: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := _offer_popup_text(title_text)
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	var label := "%s x%s" % [_ingredient_display(ingredient_id), maxi(1, quantity)]
	var card := _visual_card("", label, meta, Vector2(86, 74), Callable())
	card.name = "%s_%s" % [node_prefix, ingredient_id]
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	box.add_child(card)
	return box


func _offer_recipe_context(participant_id: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "OfferRecipeContext_%s" % participant_id
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var participant := _participant_by_id(participant_id)
	var participant_name := _participant_name(participant_id)
	var recipe: Dictionary = participant.get("currentRecipe", {})
	if recipe.is_empty():
		box.add_child(_offer_popup_text("%s has no active recipe." % participant_name))
		return box
	var recipe_name := str(recipe.get("name", ""))
	box.add_child(_offer_popup_text("%s's missing ingredients" % participant_name))
	if recipe_name != "":
		box.add_child(_offer_popup_text("Recipe: %s" % recipe_name))
	var missing: Array = recipe.get("missingRequirements", [])
	if missing.is_empty():
		box.add_child(_offer_popup_text("Recipe complete."))
		return box
	var grid := GridContainer.new()
	grid.columns = 3
	grid.name = "OfferMissingIngredients"
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for raw_requirement in missing:
		var requirement: Dictionary = raw_requirement
		var ingredient_id := str(requirement.get("ingredientId", ""))
		var quantity := maxi(1, int(requirement.get("missingQty", 1)))
		var meta := VisualAssets.ingredient_meta(ingredient_id)
		var card := _visual_card("", "%s x%s" % [_ingredient_display(ingredient_id), quantity], meta, Vector2(88, 82), Callable())
		card.name = "OfferMissing_%s" % ingredient_id
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		grid.add_child(card)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(grid)
	box.add_child(center)
	return box


func _open_offer_popup(participant_id: String) -> void:
	_clear(_offer_popup_list)
	_prepare_offer_popup_content(292)

	var added := false
	for raw_offer in _snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		var from_id := str(offer.get("fromParticipantId", ""))
		var to_id := str(offer.get("toParticipantId", ""))
		if from_id != participant_id and to_id != participant_id:
			continue
		added = true
		var action_row: Control = null
		if to_id == _viewer_id():
			var row := _offer_popup_button_row()
			row.add_child(_offer_popup_button("Accept", func(o := offer) -> void:
				_accept_offer(o)
				_offer_popup.hide()
			))
			row.add_child(_offer_popup_button("Refuse", func(o := offer) -> void:
				intent_requested.emit({"type": "respond_offer", "offerId": o.get("id", ""), "response": "refuse"})
				_offer_popup.hide()
			))
			action_row = row
		elif from_id == _viewer_id():
			action_row = _offer_popup_button("Cancel Offer", func(o := offer) -> void:
				intent_requested.emit({"type": "cancel_offer", "offerId": o.get("id", "")})
				_offer_popup.hide()
			)
		var give_ingredient_id := _offer_first_offered_ingredient_id(offer)
		var give_quantity := _offer_offered_quantity(offer)
		var get_ingredient_id := _offer_requested_ingredient_id(offer)
		var get_quantity := _offer_requested_quantity(offer)
		if to_id == _viewer_id():
			give_ingredient_id = _offer_requested_ingredient_id(offer)
			give_quantity = _offer_requested_quantity(offer)
			get_ingredient_id = _offer_first_offered_ingredient_id(offer)
			get_quantity = _offer_offered_quantity(offer)
		_offer_popup_list.add_child(_offer_popup_component(
			"Offers with %s" % _participant_name(participant_id),
			participant_id,
			give_ingredient_id,
			give_quantity,
			get_ingredient_id,
			get_quantity,
			_offer_sentence(offer),
			action_row
		))
	if not added:
		var title := _offer_popup_header("Offers with %s" % _participant_name(participant_id))
		_offer_popup_list.add_child(title)
		var none_label := _offer_popup_text("No visible offers.")
		_offer_popup_list.add_child(none_label)
	if _selected_hand_voucher_id != "" and participant_id != _viewer_id() and str(_snapshot.get("phase", "")) == "playing" and _participant_can_receive_offer(_participant_by_id(participant_id)):
		_offer_popup_list.add_child(_offer_popup_button("Create New Offer", func(id := participant_id) -> void:
			_offer_popup.hide()
			_open_create_offer_popup(id)
		))

	_popup_centered_tight(332, 430, true)


func _accept_offer(offer: Dictionary) -> void:
	var requested: Dictionary = offer.get("requested", {})
	var ingredient_id := str(requested.get("ingredientId", ""))
	var quantity := int(requested.get("quantity", 1))
	var matching := _matching_hand_voucher_ids(ingredient_id, quantity)
	if matching.size() < quantity:
		status_requested.emit("You do not have enough %s to accept." % _ingredient_display(ingredient_id))
		return
	intent_requested.emit({"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "voucherIds": matching})


func _offer_requested_ingredient_id(offer: Dictionary) -> String:
	var requested: Dictionary = offer.get("requested", {})
	return str(requested.get("ingredientId", ""))


func _offer_requested_quantity(offer: Dictionary) -> int:
	var requested: Dictionary = offer.get("requested", {})
	return int(requested.get("quantity", 1))


func _offer_first_offered_ingredient_id(offer: Dictionary) -> String:
	for raw_voucher in offer.get("offeredVouchers", []):
		var voucher: Dictionary = raw_voucher
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id != "":
			return ingredient_id
	for raw_id in offer.get("offeredVoucherIds", []):
		var ingredient_id := _ingredient_id_for_voucher(str(raw_id))
		if ingredient_id != "":
			return ingredient_id
	return ""


func _offer_offered_quantity(offer: Dictionary) -> int:
	var offered: Array = offer.get("offeredVouchers", [])
	if not offered.is_empty():
		return offered.size()
	var ids: Array = offer.get("offeredVoucherIds", [])
	return maxi(1, ids.size())


func _offer_sentence(offer: Dictionary) -> String:
	return "%s offers %s x%s to %s for %s x%s." % [
		_participant_name(str(offer.get("fromParticipantId", ""))),
		_ingredient_display(_offer_first_offered_ingredient_id(offer)),
		_offer_offered_quantity(offer),
		_participant_name(str(offer.get("toParticipantId", ""))),
		_ingredient_display(_offer_requested_ingredient_id(offer)),
		_offer_requested_quantity(offer)
	]


func _offer_label(offer: Dictionary) -> Label:
	var requested: Dictionary = offer.get("requested", {})
	var text := "%s offers %s to %s for %s x%s." % [
		_participant_name(str(offer.get("fromParticipantId", ""))),
		_offer_cards_label(offer),
		_participant_name(str(offer.get("toParticipantId", ""))),
		_ingredient_display(str(requested.get("ingredientId", ""))),
		int(requested.get("quantity", 1))
	]
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", TEXT_DARK)
	return label


func _clear_selections() -> void:
	_selected_hand_voucher_id = ""
	_selected_hand_ingredient_id = ""
	_selected_inventory_asset_key = ""
	_selected_platter_asset_key = ""


func _can_select_or_use_hand_card() -> bool:
	var phase := str(_snapshot.get("phase", "lobby"))
	if phase == "deposit":
		return _can_act_in_deposit()
	if phase == "playing" or phase == "settlement":
		return _can_act_now(phase)
	return false


func _can_act_in_deposit() -> bool:
	if _visual_update_waiting():
		return false
	if bool(_snapshot.get("paused", false)):
		return false
	var viewer := _participant_by_id(_viewer_id())
	return str(viewer.get("role", "")) == "active" and str(viewer.get("kind", "human")) == "human" and not bool(viewer.get("depositedInitial", false))


func _can_act_now(phase: String) -> bool:
	if _visual_update_waiting():
		return false
	if bool(_snapshot.get("paused", false)):
		return false
	if _viewer_is_witness():
		return false
	var viewer := _participant_by_id(_viewer_id())
	if str(viewer.get("role", "")) != "active" or str(viewer.get("kind", "human")) != "human":
		return false
	if phase != "" and str(_snapshot.get("phase", "")) != phase:
		return false
	if phase == "deposit" or phase == "lobby" or phase == "complete":
		return true
	return str(_snapshot.get("currentTurnParticipantId", "")) == _viewer_id()


func _is_round_robin_off_turn(phase: String) -> bool:
	if phase != "" and str(_snapshot.get("phase", "")) != phase:
		return false
	if _viewer_is_witness():
		return false
	var viewer := _participant_by_id(_viewer_id())
	if str(viewer.get("role", "")) != "active" or str(viewer.get("kind", "human")) != "human":
		return false
	var current_turn := str(_snapshot.get("currentTurnParticipantId", ""))
	return current_turn != "" and current_turn != _viewer_id()


func _viewer_is_witness() -> bool:
	if str(_snapshot.get("viewerRole", "")) == "witness":
		return true
	var viewer := _participant_by_id(_viewer_id())
	return str(viewer.get("role", "")) == "witness"


func _can_view_participant(participant_id: String) -> bool:
	if participant_id == _viewer_id():
		return true
	if _viewer_is_witness():
		return true
	var controlled: Array = _snapshot.get("controlledParticipantIds", [])
	return controlled.has(participant_id)


func _participant_can_receive_offer(participant: Dictionary) -> bool:
	return str(participant.get("role", "")) == "active" and str(participant.get("ingredientId", "")) != "" and int(participant.get("offerableOwnIngredientQty", 1)) > 0


func _asset_ref_from_key(key: String) -> Dictionary:
	var separator := key.find(":")
	if separator <= 0:
		return {}
	return {"kind": key.substr(0, separator), "id": key.substr(separator + 1)}


func _asset_label_from_key(key: String) -> String:
	if key == "":
		return ""
	if key.begins_with("voucher:"):
		var voucher_id := key.substr("voucher:".length())
		var ingredient_id := _ingredient_id_for_voucher(voucher_id)
		if ingredient_id == "":
			ingredient_id = _ingredient_id_for_platter_voucher(voucher_id)
		return _ingredient_display(ingredient_id) if ingredient_id != "" else "Card"
	if key.begins_with("dish_part:"):
		var part_id := key.substr("dish_part:".length())
		for raw_part in _snapshot.get("ownFoodParts", []) + _snapshot.get("platterFoodParts", []):
			var part: Dictionary = raw_part
			if str(part.get("id", "")) == part_id:
				return VisualAssets.short_dish_name(str(part.get("dishName", "Food part")))
		return "Food part"
	return ""


func _ingredient_id_for_platter_voucher(voucher_id: String) -> String:
	for raw_voucher in _snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return str(voucher.get("ingredientId", ""))
	return ""


func _recipe_slots(recipe: Dictionary) -> Array:
	var slots: Array = []
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var required := int(requirement.get("requiredQty", 0))
		var redeemed := int(requirement.get("redeemedQty", 0))
		var placed: int = requirement.get("placedVoucherIds", []).size()
		for index in range(required):
			var status := "empty"
			if index < redeemed:
				status = "redeemed"
			elif index < redeemed + placed:
				status = "placed"
			slots.append({
				"ingredientId": str(requirement.get("ingredientId", "")),
				"status": status
			})
	return slots


func _recipe_slot_statuses(recipe: Dictionary) -> Dictionary:
	var statuses := {}
	var slots := _recipe_slots(recipe)
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		statuses[_recipe_slot_key(slot, index)] = str(slot.get("status", "empty"))
	return statuses


func _recipe_slot_key(slot: Dictionary, index: int) -> String:
	return "%s:%s" % [str(slot.get("ingredientId", "")), index]


func _should_hold_snapshot_for_animation(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> bool:
	if previous_snapshot.is_empty() or current_snapshot.is_empty() or not is_instance_valid(_animation_layer):
		return false
	if str(previous_snapshot.get("tableCode", "")) == "" or str(previous_snapshot.get("tableCode", "")) != str(current_snapshot.get("tableCode", "")):
		return false
	return true


func _visual_update_waiting() -> bool:
	return _animation_running or not _animation_queue.is_empty() or _has_pending_visual_snapshot or not _pending_visual_snapshots.is_empty()


func _is_start_setup_transition(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> bool:
	var previous_phase := str(previous_snapshot.get("phase", ""))
	var current_phase := str(current_snapshot.get("phase", ""))
	if current_phase != "deposit" and current_phase != "playing":
		return false
	if previous_phase == "lobby" and current_phase != "lobby" and current_phase != "":
		return true
	return _snapshot_missing_assigned_ingredients(previous_snapshot) and _snapshot_has_assigned_ingredients(current_snapshot)


func _snapshot_missing_assigned_ingredients(snapshot: Dictionary) -> bool:
	if str(snapshot.get("phase", "")) == "lobby":
		return true
	return not _snapshot_has_assigned_ingredients(snapshot)


func _snapshot_has_assigned_ingredients(snapshot: Dictionary) -> bool:
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) == "active" and str(participant.get("ingredientId", "")) != "":
			return true
	return false


func _apply_start_setup_transition(current_snapshot: Dictionary) -> void:
	_reset_basket_slot_mapping()
	var baseline := _start_setup_baseline_for_offerings(current_snapshot)
	_apply_snapshot(baseline)
	var events := _animation_events(baseline, current_snapshot)
	if events.is_empty():
		_record_animation_debug([])
		_apply_snapshot(current_snapshot)
		return
	events = _events_with_visual_milestones(baseline, current_snapshot, events)
	_queue_pending_visual_snapshot(current_snapshot)
	_record_animation_debug(events)
	_animation_queue.append_array(events)
	call_deferred("_play_next_animation_after_layout")


func _play_next_animation_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_resolve_deposit_animation_points()
	_play_next_animation()


func _resolve_deposit_animation_points() -> void:
	for index in range(_animation_queue.size()):
		var event: Dictionary = _animation_queue[index]
		if str(event.get("type", "")) != "deposit":
			continue
		var ingredient_id := str(event.get("ingredientId", ""))
		event["startPoint"] = _participant_or_hand_center(str(event.get("participantId", "")), ingredient_id)
		var end := _platter_voucher_center(ingredient_id)
		if end == Vector2.INF:
			end = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
		if end == Vector2.INF:
			end = _control_global_center(_basket_grid)
		event["endPoint"] = end
		_animation_queue[index] = event


func _start_setup_baseline_for_offerings(current_snapshot: Dictionary) -> Dictionary:
	var baseline := current_snapshot.duplicate(true)
	baseline["phase"] = "deposit"
	var deposited_participant_ids := {}
	var participants: Array = baseline.get("participants", [])
	for index in range(participants.size()):
		var participant: Dictionary = participants[index]
		if bool(participant.get("depositedInitial", false)):
			deposited_participant_ids[str(participant.get("id", ""))] = true
			participant["depositedInitial"] = false
			participants[index] = participant
	baseline["participants"] = participants

	var viewer_id := str(baseline.get("viewerParticipantId", ""))
	var hand: Array = baseline.get("ownHand", []).duplicate(true)
	var platter: Array = baseline.get("platter", [])
	var baseline_platter: Array = []
	for raw_voucher in platter:
		var voucher: Dictionary = raw_voucher
		var owner_id := str(voucher.get("ownerParticipantId", ""))
		if deposited_participant_ids.has(owner_id):
			if owner_id == viewer_id and not _voucher_array_has_id(hand, str(voucher.get("id", ""))):
				var hand_voucher := voucher.duplicate(true)
				hand_voucher["location"] = {"type": "hand", "participantId": viewer_id}
				hand.append(hand_voucher)
			continue
		baseline_platter.append(voucher.duplicate(true))
	baseline["ownHand"] = hand
	baseline["platter"] = baseline_platter
	return baseline


func _voucher_array_has_id(vouchers: Array, voucher_id: String) -> bool:
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return true
	return false


func _snapshot_identity_key(snapshot: Dictionary) -> String:
	return "%s:%s:%s:%s:%s:%s" % [
		str(snapshot.get("tableCode", "")),
		str(snapshot.get("version", "")),
		str(snapshot.get("turn", "")),
		str(snapshot.get("phase", "")),
		str(snapshot.get("currentTurnParticipantId", "")),
		str(snapshot.get("transactionTotal", ""))
	]


func _animation_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	events.append_array(_detect_deposit_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_swap_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_exchange_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_redeem_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_prepare_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_offer_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_eating_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_turn_events(previous_snapshot, current_snapshot))
	events.append_array(_detect_complete_events(previous_snapshot, current_snapshot))
	return _events_in_transaction_order(previous_snapshot, current_snapshot, events)


func _events_in_transaction_order(previous_snapshot: Dictionary, current_snapshot: Dictionary, events: Array) -> Array:
	var rows := _new_transactions(previous_snapshot, current_snapshot)
	var ordered: Array = []
	for index in range(events.size()):
		var event: Dictionary = events[index]
		var decorated := event.duplicate(true)
		decorated["_sequence"] = index
		decorated["_transactionOrder"] = _transaction_order_for_event(decorated, rows)
		_insert_ordered_animation_event(ordered, decorated)
	return ordered


func _insert_ordered_animation_event(ordered: Array, event: Dictionary) -> void:
	for index in range(ordered.size()):
		var other: Dictionary = ordered[index]
		var event_order := int(event.get("_transactionOrder", 1000000))
		var other_order := int(other.get("_transactionOrder", 1000000))
		if event_order < other_order:
			ordered.insert(index, event)
			return
		if event_order == other_order and int(event.get("_sequence", 0)) < int(other.get("_sequence", 0)):
			ordered.insert(index, event)
			return
	ordered.append(event)


func _transaction_order_for_event(event: Dictionary, rows: Array) -> int:
	var event_transaction_id := str(event.get("_transactionId", ""))
	if event_transaction_id != "":
		for index in range(rows.size()):
			var row: Dictionary = rows[index]
			if str(row.get("id", "")) == event_transaction_id:
				return index
	match str(event.get("type", "")):
		"deposit":
			return _transaction_order_by_action(rows, ["Deposit"], str(event.get("participantId", "")), "")
		"swap", "settlement_swap":
			return _transaction_order_by_action(rows, ["Swap", "Settlement Swap"], str(event.get("actorParticipantId", "")), "")
		"exchange":
			return _transaction_order_by_action(rows, ["Exchange"], str(event.get("fromParticipantId", "")), str(event.get("toParticipantId", "")))
		"redeem":
			return _transaction_order_by_action_and_ingredient(rows, ["Redeem"], _viewer_id(), str(event.get("ingredientId", "")))
		"public_redeem":
			return _transaction_order_by_action_and_ingredient(rows, ["Redeem"], str(event.get("participantId", "")), str(event.get("ingredientId", "")))
		"prepare":
			return _transaction_order_by_action(rows, ["Prepare"], _viewer_id(), "")
		"eat":
			return _transaction_order_by_action(rows, ["Eat", "Bite"], _viewer_id(), "")
		"turn":
			return _transaction_order_by_action(rows, ["Pass Turn"], "", str(event.get("participantId", "")))
		_:
			return 1000000


func _transaction_order_by_action(rows: Array, actions: Array[String], participant_id: String, counterparty_participant_id: String) -> int:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if not actions.has(str(row.get("action", ""))):
			continue
		if participant_id != "" and str(row.get("participantId", "")) != participant_id:
			continue
		if counterparty_participant_id != "" and str(row.get("counterpartyParticipantId", "")) != counterparty_participant_id:
			continue
		return index
	return 1000000


func _transaction_order_by_action_and_ingredient(rows: Array, actions: Array[String], participant_id: String, ingredient_id: String) -> int:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if not actions.has(str(row.get("action", ""))):
			continue
		if participant_id != "" and str(row.get("participantId", "")) != participant_id:
			continue
		if ingredient_id != "" and _ingredient_id_from_label(str(row.get("itemOut", ""))) != ingredient_id:
			continue
		return index
	return 1000000


func _events_with_visual_milestones(previous_snapshot: Dictionary, current_snapshot: Dictionary, events: Array) -> Array:
	var milestones: Array = []
	var working := previous_snapshot.duplicate(true)
	for raw_event in events:
		var event: Dictionary = raw_event
		var milestone := event.duplicate(true)
		var event_type := str(event.get("type", ""))
		if event_type == "deposit":
			working = _snapshot_after_deposit_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "redeem":
			working = _snapshot_after_redeem_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "public_redeem":
			working = _snapshot_after_public_redeem_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "swap" or event_type == "settlement_swap":
			var give_started := _snapshot_after_swap_give_source_step(working, current_snapshot, event)
			milestone["_snapshotStart"] = give_started.duplicate(true)
			var mid := _snapshot_after_swap_give_destination_step(give_started, current_snapshot, event)
			milestone["_snapshotMid"] = mid.duplicate(true)
			var take_started := _snapshot_after_swap_take_source_step(mid, current_snapshot, event)
			milestone["_snapshotTakeStart"] = take_started.duplicate(true)
			working = _snapshot_after_swap_take_destination_step(take_started, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "turn":
			working = _snapshot_after_turn_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		else:
			working = current_snapshot.duplicate(true)
			milestone["_snapshotAfter"] = working.duplicate(true)
		milestones.append(milestone)
	return milestones


func _snapshot_after_deposit_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	_copy_transaction_state(next, final_snapshot)
	var participant_id := str(event.get("participantId", ""))
	var ingredient_id := str(event.get("ingredientId", ""))
	_step_participant_deposit_toward_final(next, final_snapshot, participant_id)
	_step_own_hand_voucher_count_toward_final(next, final_snapshot, ingredient_id)
	_step_platter_voucher_count_toward_final(next, final_snapshot, ingredient_id)
	return next


func _snapshot_after_redeem_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	_copy_transaction_state(next, final_snapshot)
	var ingredient_id := str(event.get("ingredientId", ""))
	var owner_id := str(event.get("ownerParticipantId", ""))
	if owner_id == "":
		owner_id = _participant_id_for_ingredient_in_snapshot(next, ingredient_id)
	_step_own_hand_voucher_count_toward_final(next, final_snapshot, ingredient_id)
	_step_recipe_redeemed_count_toward_final(next, final_snapshot, ingredient_id)
	_step_participant_stock_toward_final(next, final_snapshot, owner_id)
	return next


func _snapshot_after_public_redeem_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	_copy_transaction_state(next, final_snapshot)
	var owner_id := str(event.get("ownerParticipantId", ""))
	_step_participant_stock_toward_final(next, final_snapshot, owner_id)
	return next


func _snapshot_after_swap_give_source_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	var actor_id := _swap_actor_id(event)
	var give_kind := str(event.get("giveKind", ""))
	if give_kind == "voucher":
		var give_ingredient := str(event.get("giveIngredientId", ""))
		if actor_id == _viewer_id():
			_step_own_hand_voucher_count_toward_final(next, final_snapshot, give_ingredient)
	elif give_kind == "dish_part":
		var give_dish_name := str(event.get("giveDishName", ""))
		if actor_id == _viewer_id():
			_step_own_food_part_count_toward_final(next, final_snapshot, give_dish_name)
	return next


func _snapshot_after_swap_give_destination_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	var give_kind := str(event.get("giveKind", ""))
	if give_kind == "voucher":
		_step_platter_voucher_count_toward_final(next, final_snapshot, str(event.get("giveIngredientId", "")))
	elif give_kind == "dish_part":
		_step_platter_food_part_count_toward_final(next, final_snapshot, str(event.get("giveDishName", "")))
	return next


func _snapshot_after_swap_take_source_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	var take_kind := str(event.get("takeKind", ""))
	if take_kind == "voucher":
		_step_platter_voucher_count_toward_final(next, final_snapshot, str(event.get("takeIngredientId", "")))
	elif take_kind == "dish_part":
		_step_platter_food_part_count_toward_final(next, final_snapshot, str(event.get("takeDishName", "")))
	return next


func _snapshot_after_swap_take_destination_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	_copy_transaction_state(next, final_snapshot)
	var actor_id := _swap_actor_id(event)
	var take_kind := str(event.get("takeKind", ""))
	if actor_id == _viewer_id():
		if take_kind == "voucher":
			_step_own_hand_voucher_count_toward_final(next, final_snapshot, str(event.get("takeIngredientId", "")))
		elif take_kind == "dish_part":
			_step_own_food_part_count_toward_final(next, final_snapshot, str(event.get("takeDishName", "")))
	return next


func _snapshot_after_turn_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	var participant_id := str(event.get("participantId", ""))
	if participant_id != "":
		next["currentTurnParticipantId"] = participant_id
	_copy_transaction_state(next, final_snapshot)
	return next


func _copy_transaction_state(target_snapshot: Dictionary, source_snapshot: Dictionary) -> void:
	for key in ["transactionHistory", "transactionCursor", "transactionHistoryComplete", "transactionHistoryTotal", "transactionTotal"]:
		if not source_snapshot.has(key):
			continue
		var value = source_snapshot.get(key)
		target_snapshot[key] = value.duplicate(true) if value is Array or value is Dictionary else value


func _step_participant_deposit_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, participant_id: String) -> void:
	if participant_id == "":
		return
	var final_participant := _participant_from_snapshot(final_snapshot, participant_id)
	if final_participant.is_empty():
		return
	var participants: Array = snapshot.get("participants", [])
	for index in range(participants.size()):
		var participant: Dictionary = participants[index]
		if str(participant.get("id", "")) != participant_id:
			continue
		participant["depositedInitial"] = bool(final_participant.get("depositedInitial", participant.get("depositedInitial", false)))
		participants[index] = participant
		snapshot["participants"] = participants
		return


func _step_own_hand_voucher_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, ingredient_id: String) -> void:
	var current_hand: Array = snapshot.get("ownHand", [])
	var final_hand: Array = final_snapshot.get("ownHand", [])
	var current_count := _voucher_count_for_ingredient(current_hand, ingredient_id)
	var final_count := _voucher_count_for_ingredient(final_hand, ingredient_id)
	if current_count > final_count:
		for index in range(current_hand.size()):
			var voucher: Dictionary = current_hand[index]
			if str(voucher.get("ingredientId", "")) == ingredient_id:
				current_hand.remove_at(index)
				snapshot["ownHand"] = current_hand
				return
	elif current_count < final_count:
		var existing_ids := {}
		for raw_voucher in current_hand:
			var voucher: Dictionary = raw_voucher
			existing_ids[str(voucher.get("id", ""))] = true
		for raw_voucher in final_hand:
			var voucher: Dictionary = raw_voucher
			var voucher_id := str(voucher.get("id", ""))
			if str(voucher.get("ingredientId", "")) == ingredient_id and not existing_ids.has(voucher_id):
				current_hand.append(voucher.duplicate(true))
				snapshot["ownHand"] = current_hand
				return


func _step_platter_voucher_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, ingredient_id: String) -> void:
	var current_platter: Array = snapshot.get("platter", [])
	var final_platter: Array = final_snapshot.get("platter", [])
	var current_count := _voucher_count_for_ingredient(current_platter, ingredient_id)
	var final_count := _voucher_count_for_ingredient(final_platter, ingredient_id)
	if current_count < final_count:
		var existing_ids := {}
		for raw_voucher in current_platter:
			var voucher: Dictionary = raw_voucher
			existing_ids[str(voucher.get("id", ""))] = true
		for raw_voucher in final_platter:
			var voucher: Dictionary = raw_voucher
			var voucher_id := str(voucher.get("id", ""))
			if str(voucher.get("ingredientId", "")) == ingredient_id and not existing_ids.has(voucher_id):
				current_platter.append(voucher.duplicate(true))
				snapshot["platter"] = current_platter
				return
	elif current_count > final_count:
		for index in range(current_platter.size()):
			var voucher: Dictionary = current_platter[index]
			if str(voucher.get("ingredientId", "")) == ingredient_id:
				current_platter.remove_at(index)
				snapshot["platter"] = current_platter
				return


func _step_own_food_part_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, dish_name: String) -> void:
	_step_food_part_count_toward_final(snapshot, final_snapshot, "ownFoodParts", dish_name)


func _step_platter_food_part_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, dish_name: String) -> void:
	_step_food_part_count_toward_final(snapshot, final_snapshot, "platterFoodParts", dish_name)


func _step_food_part_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, collection_key: String, dish_name: String) -> void:
	if dish_name == "":
		return
	var current_parts: Array = snapshot.get(collection_key, [])
	var final_parts: Array = final_snapshot.get(collection_key, [])
	var current_count := _food_part_count_for_dish_name(current_parts, dish_name)
	var final_count := _food_part_count_for_dish_name(final_parts, dish_name)
	if current_count < final_count:
		var existing_ids := {}
		for raw_part in current_parts:
			var part: Dictionary = raw_part
			existing_ids[str(part.get("id", ""))] = true
		for raw_part in final_parts:
			var part: Dictionary = raw_part
			var part_id := str(part.get("id", ""))
			if str(part.get("dishName", "")) == dish_name and not existing_ids.has(part_id):
				current_parts.append(part.duplicate(true))
				snapshot[collection_key] = current_parts
				return
	elif current_count > final_count:
		for index in range(current_parts.size()):
			var part: Dictionary = current_parts[index]
			if str(part.get("dishName", "")) == dish_name:
				current_parts.remove_at(index)
				snapshot[collection_key] = current_parts
				return


func _food_part_count_for_dish_name(parts: Array, dish_name: String) -> int:
	var count := 0
	for raw_part in parts:
		var part: Dictionary = raw_part
		if str(part.get("dishName", "")) == dish_name:
			count += 1
	return count


func _step_recipe_redeemed_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, ingredient_id: String) -> void:
	if not snapshot.has("ownRecipe") or not final_snapshot.has("ownRecipe"):
		return
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var final_recipe: Dictionary = final_snapshot.get("ownRecipe", {})
	var requirements: Array = recipe.get("requirements", [])
	var final_requirements: Array = final_recipe.get("requirements", [])
	for index in range(requirements.size()):
		var requirement: Dictionary = requirements[index]
		if str(requirement.get("ingredientId", "")) != ingredient_id:
			continue
		var final_redeemed := _final_redeemed_qty_for_requirement(final_requirements, ingredient_id, int(requirement.get("requiredQty", 0)))
		var current_redeemed := int(requirement.get("redeemedQty", 0))
		if current_redeemed < final_redeemed:
			requirement["redeemedQty"] = current_redeemed + 1
			requirements[index] = requirement
			recipe["requirements"] = requirements
			snapshot["ownRecipe"] = recipe
			return


func _final_redeemed_qty_for_requirement(final_requirements: Array, ingredient_id: String, required_qty: int) -> int:
	for raw_requirement in final_requirements:
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) == ingredient_id and int(requirement.get("requiredQty", 0)) == required_qty:
			return int(requirement.get("redeemedQty", 0))
	for raw_requirement in final_requirements:
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) == ingredient_id:
			return int(requirement.get("redeemedQty", 0))
	return 0


func _step_participant_stock_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, participant_id: String) -> void:
	if participant_id == "":
		return
	var participants: Array = snapshot.get("participants", [])
	var final_participant := _participant_from_snapshot(final_snapshot, participant_id)
	if final_participant.is_empty() or not final_participant.has("realIngredientStock"):
		return
	for index in range(participants.size()):
		var participant: Dictionary = participants[index]
		if str(participant.get("id", "")) != participant_id or not participant.has("realIngredientStock"):
			continue
		var current_stock := int(participant.get("realIngredientStock", 0))
		var final_stock := int(final_participant.get("realIngredientStock", current_stock))
		if current_stock > final_stock:
			participant["realIngredientStock"] = current_stock - 1
		elif current_stock < final_stock:
			participant["realIngredientStock"] = current_stock + 1
		participants[index] = participant
		snapshot["participants"] = participants
		return


func _voucher_count_for_ingredient(vouchers: Array, ingredient_id: String) -> int:
	var count := 0
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			count += 1
	return count


func _participant_id_for_ingredient_in_snapshot(snapshot: Dictionary, ingredient_id: String) -> String:
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("ingredientId", "")) == ingredient_id:
			return str(participant.get("id", ""))
	return ""


func _record_animation_debug(events: Array) -> void:
	_last_animation_types.clear()
	var deposit_slots: Array[int] = []
	var event_summaries: Array = []
	for raw_event in events:
		var event: Dictionary = raw_event
		_last_animation_types.append(str(event.get("type", "")))
		event_summaries.append(event.duplicate(true))
		if str(event.get("type", "")) == "deposit":
			deposit_slots.append(int(event.get("basketSlotIndex", -1)))
	debug_stats["animationEventCount"] = events.size()
	debug_stats["lastAnimationTypes"] = _last_animation_types.duplicate()
	debug_stats["lastAnimationEvents"] = event_summaries
	debug_stats["lastDepositBasketSlots"] = deposit_slots


func _queue_animation_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> void:
	if previous_snapshot.is_empty() or not is_instance_valid(_animation_layer):
		_record_animation_debug([])
		return
	var events := _animation_events(previous_snapshot, current_snapshot)
	events = _events_with_visual_milestones(previous_snapshot, current_snapshot, events)
	_record_animation_debug(events)
	if events.is_empty():
		return
	_animation_queue.append_array(events)
	call_deferred("_play_next_animation")


func _detect_deposit_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events_by_participant := {}
	var previous_by_id := _participant_map(previous_snapshot)
	var deposit_order := _deposit_participant_order_from_transactions(current_snapshot)
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if participant_id == "" or not previous_by_id.has(participant_id):
			continue
		var previous: Dictionary = previous_by_id[participant_id]
		if not bool(previous.get("depositedInitial", false)) and bool(participant.get("depositedInitial", false)):
			var ingredient_id := str(participant.get("ingredientId", ""))
			events_by_participant[participant_id] = {
				"type": "deposit",
				"ingredientId": ingredient_id,
				"participantId": participant_id,
				"basketSlotIndex": _basket_slot_index_for_deposit_participant(participant_id, deposit_order, events_by_participant.size())
			}
	var events: Array = []
	for participant_id in deposit_order:
		if events_by_participant.has(participant_id):
			events.append(events_by_participant[participant_id])
			events_by_participant.erase(participant_id)
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if events_by_participant.has(participant_id):
			events.append(events_by_participant[participant_id])
			events_by_participant.erase(participant_id)
	return events


func _detect_swap_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var phase := str(current_snapshot.get("phase", ""))
	var hand_delta := _count_delta(_voucher_counts(previous_snapshot.get("ownHand", [])), _voucher_counts(current_snapshot.get("ownHand", [])))
	var platter_delta := _count_delta(_voucher_counts(previous_snapshot.get("platter", [])), _voucher_counts(current_snapshot.get("platter", [])))
	var previous_food := _food_part_counts(previous_snapshot.get("ownFoodParts", []))
	var current_food := _food_part_counts(current_snapshot.get("ownFoodParts", []))
	var previous_platter_food := _food_part_counts(previous_snapshot.get("platterFoodParts", []))
	var current_platter_food := _food_part_counts(current_snapshot.get("platterFoodParts", []))
	var food_delta := _count_delta(_count_only(previous_food), _count_only(current_food))
	var platter_food_delta := _count_delta(_count_only(previous_platter_food), _count_only(current_platter_food))

	for give_ingredient in _negative_keys(hand_delta):
		if int(platter_delta.get(give_ingredient, 0)) <= 0:
			continue
		for take_ingredient in _positive_keys(hand_delta):
			if int(platter_delta.get(take_ingredient, 0)) >= 0:
				continue
			events.append({
				"type": "settlement_swap" if phase == "settlement" else "swap",
				"giveKind": "voucher",
				"giveIngredientId": str(give_ingredient),
				"takeKind": "voucher",
				"takeIngredientId": str(take_ingredient)
			})
			events[events.size() - 1] = _swap_event_with_points(events[events.size() - 1], previous_snapshot, current_snapshot)
			return events

	for give_dish_id in _negative_keys(food_delta):
		if int(platter_food_delta.get(give_dish_id, 0)) <= 0:
			continue
		for take_ingredient in _positive_keys(hand_delta):
			if int(platter_delta.get(take_ingredient, 0)) >= 0:
				continue
			var given_food: Dictionary = previous_food.get(give_dish_id, {})
			events.append({
				"type": "settlement_swap",
				"giveKind": "dish_part",
				"giveDishName": str(given_food.get("dishName", "Dish")),
				"giveUnit": str(given_food.get("unitSingular", "part")),
				"takeKind": "voucher",
				"takeIngredientId": str(take_ingredient)
			})
			events[events.size() - 1] = _swap_event_with_points(events[events.size() - 1], previous_snapshot, current_snapshot)
			return events

	for give_ingredient in _negative_keys(hand_delta):
		if int(platter_delta.get(give_ingredient, 0)) <= 0:
			continue
		for take_dish_id in _positive_keys(food_delta):
			if int(platter_food_delta.get(take_dish_id, 0)) >= 0:
				continue
			var taken_food: Dictionary = current_food.get(take_dish_id, {})
			events.append({
				"type": "settlement_swap" if phase == "settlement" else "swap",
				"giveKind": "voucher",
				"giveIngredientId": str(give_ingredient),
				"takeKind": "dish_part",
				"takeDishName": str(taken_food.get("dishName", "Dish")),
				"takeUnit": str(taken_food.get("unitSingular", "part"))
				})
			events[events.size() - 1] = _swap_event_with_points(events[events.size() - 1], previous_snapshot, current_snapshot)
			return events
	var public_swaps := _public_swap_events_from_transactions(previous_snapshot, current_snapshot)
	if not public_swaps.is_empty():
		events.append_array(public_swaps)
		return events
	var public_swap := _public_swap_event_from_platter_delta(previous_snapshot, current_snapshot, platter_delta, platter_food_delta)
	if not public_swap.is_empty():
		events.append(public_swap)
	return events


func _public_swap_events_from_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var viewer_id := _viewer_id()
	var phase := str(current_snapshot.get("phase", ""))
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		var action := str(transaction.get("action", ""))
		if action != "Swap" and action != "Settlement Swap":
			continue
		var actor_id := str(transaction.get("participantId", ""))
		if actor_id == "" or actor_id == viewer_id:
			continue
		var event := _swap_event_from_transaction(transaction, previous_snapshot, current_snapshot, phase)
		if not event.is_empty():
			events.append(event)
	return events


func _swap_event_from_transaction(transaction: Dictionary, previous_snapshot: Dictionary, current_snapshot: Dictionary, phase: String) -> Dictionary:
	var action := str(transaction.get("action", ""))
	var event := {
		"type": "settlement_swap" if action == "Settlement Swap" or phase == "settlement" else "swap",
		"actorParticipantId": str(transaction.get("participantId", "")),
		"_transactionId": str(transaction.get("id", ""))
	}
	var give := _asset_event_fields_from_label(str(transaction.get("itemOut", "")), "give", previous_snapshot, current_snapshot)
	var take := _asset_event_fields_from_label(str(transaction.get("itemBack", "")), "take", previous_snapshot, current_snapshot)
	if give.is_empty() or take.is_empty():
		return {}
	event.merge(give, true)
	event.merge(take, true)
	return _swap_event_with_points(event, previous_snapshot, current_snapshot)


func _asset_event_fields_from_label(label: String, prefix: String, previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Dictionary:
	var ingredient_id := _ingredient_id_from_label(label)
	if ingredient_id != "":
		return {
			"%sKind" % prefix: "voucher",
			"%sIngredientId" % prefix: ingredient_id
		}
	var dish := _dish_part_info_from_label(label, previous_snapshot, current_snapshot)
	if not dish.is_empty():
		return {
			"%sKind" % prefix: "dish_part",
			"%sDishName" % prefix: str(dish.get("dishName", "Dish")),
			"%sUnit" % prefix: str(dish.get("unitSingular", "part"))
		}
	return {}


func _dish_part_info_from_label(label: String, previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Dictionary:
	var normalized := label.strip_edges().to_lower()
	if normalized == "" or normalized == "none":
		return {}
	for snapshot in [previous_snapshot, current_snapshot, _snapshot]:
		for collection_key in ["platterFoodParts", "ownFoodParts"]:
			for raw_part in snapshot.get(collection_key, []):
				var part: Dictionary = raw_part
				var dish_name := str(part.get("dishName", "Dish"))
				var unit := str(part.get("unitSingular", "part"))
				if normalized == "%s %s" % [dish_name.to_lower(), unit.to_lower()] or normalized == "%s %s" % [VisualAssets.short_dish_name(dish_name).to_lower(), unit.to_lower()]:
					return {"dishName": dish_name, "unitSingular": unit}
	for unit in ["slice", "cup", "scoop", "piece", "portion", "serving", "bowl"]:
		var suffix := " %s" % unit
		if normalized.ends_with(suffix) and normalized.length() > suffix.length():
			return {
				"dishName": label.strip_edges().substr(0, label.strip_edges().length() - suffix.length()).strip_edges(),
				"unitSingular": unit
			}
	return {}


func _public_swap_event_from_platter_delta(previous_snapshot: Dictionary, current_snapshot: Dictionary, platter_delta: Dictionary, platter_food_delta: Dictionary) -> Dictionary:
	var transaction := _latest_new_transaction_by_actions(previous_snapshot, current_snapshot, ["Swap", "Settlement Swap"], _viewer_id())
	var actor_id := str(transaction.get("participantId", ""))
	var phase := str(current_snapshot.get("phase", ""))
	var event_type := "settlement_swap" if phase == "settlement" or str(transaction.get("action", "")) == "Settlement Swap" else "swap"
	if actor_id == "":
		return {}
	var base := {
		"type": event_type,
		"actorParticipantId": actor_id
	}
	for give_ingredient in _positive_keys(platter_delta):
		for take_ingredient in _negative_keys(platter_delta):
			var event := base.duplicate()
			event.merge({
				"giveKind": "voucher",
				"giveIngredientId": str(give_ingredient),
				"takeKind": "voucher",
				"takeIngredientId": str(take_ingredient)
			}, true)
			return _swap_event_with_points(event, previous_snapshot, current_snapshot)
	var previous_platter_food := _food_part_counts(previous_snapshot.get("platterFoodParts", []))
	var current_platter_food := _food_part_counts(current_snapshot.get("platterFoodParts", []))
	for give_dish_id in _positive_keys(platter_food_delta):
		for take_ingredient in _negative_keys(platter_delta):
			var given_food: Dictionary = current_platter_food.get(give_dish_id, {})
			var event := base.duplicate()
			event.merge({
				"giveKind": "dish_part",
				"giveDishName": str(given_food.get("dishName", "Dish")),
				"giveUnit": str(given_food.get("unitSingular", "part")),
				"takeKind": "voucher",
				"takeIngredientId": str(take_ingredient)
			}, true)
			return _swap_event_with_points(event, previous_snapshot, current_snapshot)
	for give_ingredient in _positive_keys(platter_delta):
		for take_dish_id in _negative_keys(platter_food_delta):
			var taken_food: Dictionary = previous_platter_food.get(take_dish_id, {})
			var event := base.duplicate()
			event.merge({
				"giveKind": "voucher",
				"giveIngredientId": str(give_ingredient),
				"takeKind": "dish_part",
				"takeDishName": str(taken_food.get("dishName", "Dish")),
				"takeUnit": str(taken_food.get("unitSingular", "part"))
			}, true)
			return _swap_event_with_points(event, previous_snapshot, current_snapshot)
	return {}


func _swap_event_with_points(event: Dictionary, _previous_snapshot: Dictionary, _current_snapshot: Dictionary) -> Dictionary:
	var enriched := event.duplicate(true)
	if not enriched.has("actorParticipantId"):
		enriched["actorParticipantId"] = _viewer_id()
	enriched["giveStartPoint"] = _swap_give_start_center(enriched)
	enriched["giveEndPoint"] = _swap_give_end_center(enriched)
	enriched["takeStartPoint"] = _swap_take_start_center(enriched)
	enriched["takeEndPoint"] = _swap_take_end_center(enriched)
	return enriched


func _detect_exchange_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Exchange":
			continue
		var from_id := str(transaction.get("participantId", ""))
		var to_id := str(transaction.get("counterpartyParticipantId", ""))
		var offered := _ingredient_ids_from_label_list(str(transaction.get("itemOut", "")))
		var requested := _ingredient_ids_from_label_list(str(transaction.get("itemBack", "")))
		if from_id == "" or to_id == "" or offered.is_empty() or requested.is_empty():
			continue
		var event := {
			"type": "exchange",
			"fromParticipantId": from_id,
			"toParticipantId": to_id,
			"offeredIngredientIds": offered,
			"requestedIngredientIds": requested
		}
		events.append(_exchange_event_with_points(event))
	return events


func _exchange_event_with_points(event: Dictionary) -> Dictionary:
	var enriched := event.duplicate(true)
	var from_id := str(enriched.get("fromParticipantId", ""))
	var to_id := str(enriched.get("toParticipantId", ""))
	var offered_legs: Array = []
	for raw_ingredient_id in enriched.get("offeredIngredientIds", []):
		var ingredient_id := str(raw_ingredient_id)
		offered_legs.append({
			"ingredientId": ingredient_id,
			"startPoint": _exchange_endpoint(from_id, ingredient_id, true),
			"endPoint": _exchange_endpoint(to_id, ingredient_id, false)
		})
	var requested_legs: Array = []
	for raw_ingredient_id in enriched.get("requestedIngredientIds", []):
		var ingredient_id := str(raw_ingredient_id)
		requested_legs.append({
			"ingredientId": ingredient_id,
			"startPoint": _exchange_endpoint(to_id, ingredient_id, true),
			"endPoint": _exchange_endpoint(from_id, ingredient_id, false)
		})
	enriched["offeredLegs"] = offered_legs
	enriched["requestedLegs"] = requested_legs
	return enriched


func _detect_redeem_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var previous_statuses := _recipe_slot_statuses(previous_snapshot.get("ownRecipe", {}))
	if not previous_statuses.is_empty():
		var slots := _recipe_slots(current_snapshot.get("ownRecipe", {}))
		for index in range(slots.size()):
			var slot: Dictionary = slots[index]
			var key := _recipe_slot_key(slot, index)
			if str(slot.get("status", "empty")) == "redeemed" and str(previous_statuses.get(key, "empty")) != "redeemed":
				var ingredient_id := str(slot.get("ingredientId", ""))
				var owner_id := _participant_id_for_ingredient_in_snapshot(previous_snapshot, ingredient_id)
				var event := {
					"type": "redeem",
					"ingredientId": ingredient_id,
					"ownerParticipantId": owner_id,
					"slotIndex": index
				}
				event["cardStartPoint"] = _redeem_card_start_center(ingredient_id)
				event["ownerPoint"] = _redeem_owner_center(event)
				event["recipeSlotPoint"] = _redeem_recipe_slot_center(ingredient_id, index)
				events.append(event)
	var public_redeems := _public_redeem_events_from_transactions(previous_snapshot, current_snapshot)
	events.append_array(public_redeems)
	return events


func _public_redeem_events_from_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Redeem":
			continue
		var actor_id := str(transaction.get("participantId", ""))
		if actor_id == "" or actor_id == _viewer_id():
			continue
		var ingredient_id := _ingredient_id_from_label(str(transaction.get("itemOut", "")))
		if ingredient_id == "":
			continue
		var owner_id := str(transaction.get("counterpartyParticipantId", ""))
		if owner_id == "":
			owner_id = _participant_id_for_ingredient_in_snapshot(previous_snapshot, ingredient_id)
		var event := {
			"type": "public_redeem",
			"participantId": actor_id,
			"ownerParticipantId": owner_id,
			"ingredientId": ingredient_id
		}
		event["cardStartPoint"] = _participant_tile_center(actor_id)
		event["ownerPoint"] = _redeem_owner_center(event)
		event["ingredientEndPoint"] = _participant_tile_center(actor_id)
		events.append(event)
	return events


func _detect_prepare_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var viewer_id := str(current_snapshot.get("viewerParticipantId", ""))
	var previous_viewer := _participant_from_snapshot(previous_snapshot, viewer_id)
	var current_viewer := _participant_from_snapshot(current_snapshot, viewer_id)
	if previous_viewer.is_empty() or current_viewer.is_empty():
		return events
	if int(current_viewer.get("dishCount", 0)) <= int(previous_viewer.get("dishCount", 0)):
		return events
	var dish_name := _recipe_name(previous_snapshot.get("ownRecipe", {}))
	var food_info := _new_food_part_info(previous_snapshot.get("ownFoodParts", []), current_snapshot.get("ownFoodParts", []))
	if dish_name == "":
		dish_name = str(food_info.get("dishName", "Dish"))
	events.append({
		"type": "prepare",
		"dishName": dish_name,
		"unit": str(food_info.get("unitSingular", "piece"))
	})
	return events


func _detect_offer_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var viewer_id := str(current_snapshot.get("viewerParticipantId", ""))
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if participant_id == "" or participant_id == viewer_id:
			continue
		var previous_indicator := _offer_indicator_for_participant_in(previous_snapshot, participant_id, viewer_id)
		var current_indicator := _offer_indicator_for_participant_in(current_snapshot, participant_id, viewer_id)
		if previous_indicator != current_indicator:
			events.append({
				"type": "offer",
				"participantId": participant_id,
				"previousIndicator": previous_indicator,
				"indicator": current_indicator
			})
	return events


func _detect_eating_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var previous_food := _food_part_counts(previous_snapshot.get("ownFoodParts", []))
	var current_food := _food_part_counts(current_snapshot.get("ownFoodParts", []))
	var delta := _count_delta(_count_only(previous_food), _count_only(current_food))
	for dish_id in _negative_keys(delta):
		var food: Dictionary = previous_food.get(dish_id, {})
		events.append({
			"type": "eat",
			"dishName": str(food.get("dishName", "Dish")),
			"unit": str(food.get("unitSingular", "part"))
		})
		return events
	return events


func _detect_turn_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var transaction_turns: Array = []
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Pass Turn":
			continue
		var next_id := str(transaction.get("counterpartyParticipantId", ""))
		if next_id == "":
			continue
		transaction_turns.append({
			"type": "turn",
			"participantId": next_id,
			"_transactionId": str(transaction.get("id", ""))
		})
	if not transaction_turns.is_empty():
		return transaction_turns
	var previous_turn := str(previous_snapshot.get("currentTurnParticipantId", ""))
	var current_turn := str(current_snapshot.get("currentTurnParticipantId", ""))
	if previous_turn != "" and current_turn != "" and previous_turn != current_turn:
		return [{"type": "turn", "participantId": current_turn}]
	return []


func _detect_complete_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	if str(previous_snapshot.get("phase", "")) != "complete" and str(current_snapshot.get("phase", "")) == "complete":
		return [{"type": "complete"}]
	return []


func _play_next_animation() -> void:
	if _animation_running or _animation_queue.is_empty() or not is_inside_tree():
		return
	_animation_running = true
	_animation_deadline_msec = 0
	var event: Dictionary = _animation_queue.pop_front()
	_current_animation_event = event
	_animation_actor_participant_id = _animation_actor_id(event)
	if _animation_actor_participant_id != "":
		_apply_snapshot(_snapshot)
	var duration := _play_animation_event(event)
	if duration <= 0.0:
		_finish_animation_event()
		return
	_animation_deadline_msec = Time.get_ticks_msec() + int(ceil((duration + 0.25) * 1000.0))
	var expected_event := event.duplicate(true)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if _animation_running and not _current_animation_event.is_empty() and _same_animation_event(_current_animation_event, expected_event):
			_finish_animation_event()
	)


func _finish_stalled_animation_if_needed() -> void:
	if not _animation_running or _animation_deadline_msec <= 0:
		return
	if Time.get_ticks_msec() < _animation_deadline_msec:
		return
	_finish_animation_event()


func _finish_animation_event() -> void:
	if not _animation_running and _current_animation_event.is_empty():
		return
	var finished_event := _current_animation_event.duplicate(true)
	_current_animation_event = {}
	_animation_running = false
	_animation_deadline_msec = 0
	_animation_actor_participant_id = ""
	_apply_animation_event_snapshot(finished_event)
	if _animation_queue.is_empty():
		_apply_pending_visual_snapshot_after_layout()
	else:
		_play_next_animation()


func _apply_pending_visual_snapshot_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_apply_pending_visual_snapshot()


func _apply_animation_event_snapshot(event: Dictionary) -> void:
	if event.has("_snapshotAfter"):
		var snapshot: Dictionary = event.get("_snapshotAfter", {})
		if not snapshot.is_empty():
			_apply_snapshot(snapshot)


func _queue_pending_visual_snapshot(snapshot: Dictionary) -> void:
	var next_snapshot := snapshot.duplicate(true)
	var next_key := _snapshot_identity_key(next_snapshot)
	if not _pending_visual_snapshots.is_empty():
		var last_snapshot: Dictionary = _pending_visual_snapshots[_pending_visual_snapshots.size() - 1]
		if _snapshot_identity_key(last_snapshot) == next_key:
			return
	elif _has_pending_visual_snapshot:
		if _snapshot_identity_key(_pending_visual_snapshot) == next_key:
			return
	elif _snapshot_identity_key(_snapshot) == next_key:
		return
	_pending_visual_snapshots.append(next_snapshot)
	_pending_visual_snapshot = next_snapshot.duplicate(true)
	_has_pending_visual_snapshot = true


func _apply_pending_visual_snapshot(defer_remaining := true) -> void:
	if _pending_visual_snapshots.is_empty() and not _has_pending_visual_snapshot:
		return
	var snapshot: Dictionary
	var remaining_snapshots: Array = []
	if not _pending_visual_snapshots.is_empty():
		snapshot = _pending_visual_snapshots.pop_front()
		remaining_snapshots = _pending_visual_snapshots.duplicate(true)
	else:
		snapshot = _pending_visual_snapshot.duplicate(true)
	_pending_visual_snapshots.clear()
	_pending_visual_snapshot = {}
	_has_pending_visual_snapshot = false
	render(snapshot)
	for raw_remaining in remaining_snapshots:
		var remaining: Dictionary = raw_remaining
		_queue_pending_visual_snapshot(remaining)
	if not _animation_running and _animation_queue.is_empty() and not _pending_visual_snapshots.is_empty():
		if defer_remaining:
			_apply_pending_visual_snapshot_after_layout()
		else:
			_apply_pending_visual_snapshot(false)


func _animation_actor_id(event: Dictionary) -> String:
	match str(event.get("type", "")):
		"deposit":
			return str(event.get("participantId", ""))
		"swap", "settlement_swap":
			return _swap_actor_id(event)
		"exchange":
			return str(event.get("fromParticipantId", ""))
		"public_redeem":
			return str(event.get("participantId", ""))
		"turn":
			return str(event.get("participantId", ""))
		"redeem", "prepare", "eat":
			return _viewer_id()
		_:
			return ""


func _play_animation_event(event: Dictionary) -> float:
	match str(event.get("type", "")):
		"deposit":
			return _animate_deposit_event(event)
		"swap", "settlement_swap":
			return _animate_swap_event(event)
		"exchange":
			return _animate_exchange_event(event)
		"redeem":
			return _animate_redeem_event(event)
		"public_redeem":
			return _animate_public_redeem_event(event)
		"prepare":
			return _animate_prepare_event(event)
		"offer":
			return _animate_offer_event(event)
		"eat":
			return _animate_eat_event(event)
		"turn":
			return _animate_turn_event(event)
		"complete":
			return _animate_complete_event()
		_:
			return 0.0


func _animate_deposit_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var start = event.get("startPoint", _participant_or_hand_center(str(event.get("participantId", "")), ingredient_id))
	var end = event.get("endPoint", _platter_voucher_center(ingredient_id))
	if end == Vector2.INF:
		end = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
	if end == Vector2.INF:
		end = _control_global_center(_basket_grid)
	_animate_voucher_card_path(ingredient_id, _valid_points([start, end]))
	return CARD_TILE_LANDING_SECONDS


func _animate_swap_event(event: Dictionary) -> float:
	var actor_id := _swap_actor_id(event)
	if actor_id == "":
		return 0.0
	var give_start := _swap_point(event, "giveStartPoint", _swap_give_start_center(event))
	var give_end := _swap_point(event, "giveEndPoint", _swap_give_end_center(event))
	if give_end == Vector2.INF:
		give_end = _control_global_center(_basket_grid)
	_apply_swap_stage_snapshot(event, "_snapshotStart")
	_animate_event_asset_tile_path(event, "give", _valid_points([give_start, give_end]))
	if event.has("_snapshotMid") and is_inside_tree():
		get_tree().create_timer(SWAP_MID_SNAPSHOT_SECONDS).timeout.connect(func() -> void:
			_apply_swap_stage_snapshot(event, "_snapshotMid")
		)
	if is_inside_tree():
		get_tree().create_timer(SWAP_TAKE_START_SECONDS).timeout.connect(func() -> void:
			var return_start := _swap_point(event, "takeStartPoint", _swap_take_start_center(event))
			_apply_swap_stage_snapshot(event, "_snapshotTakeStart")
			var return_end := _swap_point(event, "takeEndPoint", _swap_take_end_center(event))
			event["takeEndPoint"] = return_end
			_animate_event_asset_tile_path(event, "take", _valid_points([return_start, return_end]), 0.0, true)
		)
	return SWAP_FINISH_SECONDS


func _apply_swap_stage_snapshot(event: Dictionary, snapshot_key: String) -> void:
	if _current_animation_event.is_empty() or not _same_animation_event(_current_animation_event, event):
		return
	var snapshot: Dictionary = event.get(snapshot_key, {})
	if snapshot.is_empty():
		return
	_apply_snapshot(snapshot)


func _same_animation_event(left: Dictionary, right: Dictionary) -> bool:
	var left_transaction := str(left.get("_transactionId", ""))
	var right_transaction := str(right.get("_transactionId", ""))
	if left_transaction != "" or right_transaction != "":
		return left_transaction == right_transaction
	if str(left.get("type", "")) == "turn" or str(right.get("type", "")) == "turn":
		return str(left.get("type", "")) == str(right.get("type", "")) \
			and str(left.get("participantId", "")) == str(right.get("participantId", ""))
	return str(left.get("type", "")) == str(right.get("type", "")) \
		and str(left.get("actorParticipantId", "")) == str(right.get("actorParticipantId", "")) \
		and str(left.get("giveKind", "")) == str(right.get("giveKind", "")) \
		and str(left.get("giveIngredientId", "")) == str(right.get("giveIngredientId", "")) \
		and str(left.get("giveDishName", "")) == str(right.get("giveDishName", "")) \
		and str(left.get("takeKind", "")) == str(right.get("takeKind", "")) \
		and str(left.get("takeIngredientId", "")) == str(right.get("takeIngredientId", "")) \
		and str(left.get("takeDishName", "")) == str(right.get("takeDishName", ""))


func _swap_actor_id(event: Dictionary) -> String:
	var actor_id := str(event.get("actorParticipantId", ""))
	if actor_id != "":
		return actor_id
	return "" if event.has("actorParticipantId") else _viewer_id()


func _animate_exchange_event(event: Dictionary) -> float:
	var from_id := str(event.get("fromParticipantId", ""))
	var to_id := str(event.get("toParticipantId", ""))
	var delay := 0.0
	var last_start_delay := 0.0
	var offered_legs: Array = event.get("offeredLegs", [])
	if offered_legs.is_empty():
		for raw_ingredient_id in event.get("offeredIngredientIds", []):
			var ingredient_id := str(raw_ingredient_id)
			offered_legs.append({
				"ingredientId": ingredient_id,
				"startPoint": _exchange_endpoint(from_id, ingredient_id, true),
				"endPoint": _exchange_endpoint(to_id, ingredient_id, false)
			})
	for raw_leg in offered_legs:
		var leg: Dictionary = raw_leg
		var ingredient_id := str(leg.get("ingredientId", ""))
		_animate_voucher_card_path(
			ingredient_id,
			_valid_points([
				_exchange_leg_point(leg, "startPoint"),
				_exchange_leg_point(leg, "endPoint")
			]),
			delay
		)
		last_start_delay = delay
		delay += 0.08
	var requested_legs: Array = event.get("requestedLegs", [])
	if requested_legs.is_empty():
		for raw_ingredient_id in event.get("requestedIngredientIds", []):
			var ingredient_id := str(raw_ingredient_id)
			requested_legs.append({
				"ingredientId": ingredient_id,
				"startPoint": _exchange_endpoint(to_id, ingredient_id, true),
				"endPoint": _exchange_endpoint(from_id, ingredient_id, false)
			})
	for raw_leg in requested_legs:
		var leg: Dictionary = raw_leg
		var ingredient_id := str(leg.get("ingredientId", ""))
		_animate_voucher_card_path(
			ingredient_id,
			_valid_points([
				_exchange_leg_point(leg, "startPoint"),
				_exchange_leg_point(leg, "endPoint")
			]),
			delay
		)
		last_start_delay = delay
		delay += 0.08
	return last_start_delay + CARD_TILE_LANDING_SECONDS


func _animate_redeem_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var texture := _ingredient_texture(ingredient_id)
	var start := _redeem_point(event, "cardStartPoint", _redeem_card_start_center(ingredient_id))
	var owner_target := _redeem_point(event, "ownerPoint", _redeem_owner_center(event))
	var end := _redeem_point(event, "recipeSlotPoint", _redeem_recipe_slot_center(ingredient_id, int(event.get("slotIndex", 0))))
	_animate_voucher_card_path(ingredient_id, _valid_points([start, owner_target]))
	_animate_texture_path(texture, _valid_points([owner_target, end]), REDEEM_INGREDIENT_DELAY_SECONDS, Vector2(58, 58))
	_pulse_control(_redeem_recipe_slot_control(ingredient_id, int(event.get("slotIndex", 0))), Color(0.28, 0.70, 0.34))
	return REDEEM_FINISH_SECONDS


func _animate_public_redeem_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var texture := _ingredient_texture(ingredient_id)
	var actor_center := _redeem_point(event, "cardStartPoint", _public_redeem_actor_center(event))
	var owner_center := _redeem_point(event, "ownerPoint", _redeem_owner_center(event))
	var ingredient_end := _redeem_point(event, "ingredientEndPoint", _public_redeem_actor_center(event))
	_animate_voucher_card_path(ingredient_id, _valid_points([actor_center, owner_center]))
	_animate_texture_path(texture, _valid_points([owner_center, ingredient_end]), REDEEM_INGREDIENT_DELAY_SECONDS, Vector2(58, 58))
	return REDEEM_FINISH_SECONDS


func _redeem_point(event: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var point = event.get(key, Vector2.INF)
	if point is Vector2 and point != Vector2.INF:
		return point
	return fallback


func _redeem_card_start_center(ingredient_id: String) -> Vector2:
	return _hand_card_or_row_center(ingredient_id)


func _redeem_owner_center(event: Dictionary) -> Vector2:
	var ingredient_id := str(event.get("ingredientId", ""))
	var owner_id := str(event.get("ownerParticipantId", ""))
	if owner_id == _viewer_id():
		return _inventory_stock_or_row_center(ingredient_id)
	if owner_id != "":
		var participant_center := _participant_tile_center(owner_id)
		if participant_center != Vector2.INF:
			return participant_center
	return _ingredient_owner_global_center(ingredient_id)


func _redeem_recipe_slot_control(ingredient_id: String, slot_index: int) -> Control:
	return find_child("RecipeSlot_%s_%s" % [ingredient_id, slot_index], true, false) as Control


func _redeem_recipe_slot_center(ingredient_id: String, slot_index: int) -> Vector2:
	var slot_node := _redeem_recipe_slot_control(ingredient_id, slot_index)
	var center := _control_global_center(slot_node)
	return center if center != Vector2.INF else _control_global_center(_recipe_grid)


func _animate_prepare_event(event: Dictionary) -> float:
	var dish_name := str(event.get("dishName", "Dish"))
	var unit := str(event.get("unit", "piece"))
	var texture = VisualAssets.dish_meta(dish_name, unit).get("texture", null)
	if not texture is Texture2D:
		texture = VisualAssets.unit_meta(unit).get("texture", null)
	var center := _control_global_center(_recipe_grid)
	var end := _control_global_center(_hand_row)
	_glow_recipe_slots()
	_animate_prepare_ingredient_swirl(center)
	_animate_poof_burst(center, 0.86)
	_animate_large_dish(texture, dish_name, center, end, 1.02)
	_emit_sparkles(center, 24, Color(1.0, 0.76, 0.28), 0.82)
	_emit_steam_wisps(center, 1.06)
	return 2.05


func _animate_offer_event(event: Dictionary) -> float:
	var participant_node := find_child("Participant_%s" % str(event.get("participantId", "")), true, false) as Control
	var indicator := str(event.get("indicator", ""))
	if indicator.find("!") >= 0:
		_animate_offer_badge_arrival(participant_node, "!", Color(0.82, 0.12, 0.10))
	if indicator.find("?") >= 0:
		_animate_offer_badge_arrival(participant_node, "?", Color(0.06, 0.55, 0.22))
	return 0.36


func _animate_eat_event(event: Dictionary) -> float:
	var dish_name := str(event.get("dishName", "Dish"))
	var unit := str(event.get("unit", "part"))
	var texture = VisualAssets.dish_meta(dish_name, unit).get("texture", null)
	var start := _control_global_center(find_child("HandFood_%s" % _dish_id_for_name(dish_name), true, false) as Control)
	if start == Vector2.INF:
		start = _control_global_center(_hand_row)
	_pop_texture(texture, start)
	_emit_sparkles(start, 8, Color(0.95, 0.62, 0.34))
	return 0.42


func _animate_turn_event(event: Dictionary) -> float:
	return 0.36


func _animate_complete_event() -> float:
	var center := _control_global_center(_recipe_grid)
	_emit_sparkles(center, 28, Color(1.0, 0.72, 0.18))
	_pulse_control(_recipe_grid, Color(1.0, 0.76, 0.22))
	return 0.85


func _participant_or_hand_center(participant_id: String, ingredient_id: String) -> Vector2:
	if participant_id == _viewer_id():
		return _hand_card_or_row_center(ingredient_id)
	return _participant_tile_center(participant_id)


func _exchange_debug_path_points(event: Dictionary) -> Dictionary:
	var offered: Array = event.get("offeredLegs", [])
	var requested: Array = event.get("requestedLegs", [])
	var points := {}
	if not offered.is_empty():
		var leg: Dictionary = offered[0]
		points["offeredStart"] = _exchange_leg_point(leg, "startPoint")
		points["offeredEnd"] = _exchange_leg_point(leg, "endPoint")
	if not requested.is_empty():
		var leg: Dictionary = requested[0]
		points["requestedStart"] = _exchange_leg_point(leg, "startPoint")
		points["requestedEnd"] = _exchange_leg_point(leg, "endPoint")
	return points


func _exchange_leg_point(leg: Dictionary, key: String) -> Vector2:
	var value = leg.get(key, Vector2.INF)
	return value if typeof(value) == TYPE_VECTOR2 else Vector2.INF


func _exchange_endpoint(participant_id: String, ingredient_id: String, is_source: bool) -> Vector2:
	if participant_id == _viewer_id():
		if is_source:
			return _hand_card_or_row_center(ingredient_id)
		return _hand_card_or_row_center(ingredient_id)
	return _participant_tile_center(participant_id)


func _control_for_participant_or_viewer(participant_id: String) -> Control:
	if participant_id == _viewer_id():
		return _inventory_row
	return find_child("Participant_%s" % participant_id, true, false) as Control


func _participant_tile_center(participant_id: String) -> Vector2:
	if participant_id == "":
		return Vector2.INF
	if participant_id == _viewer_id():
		var inventory_center := _control_global_center(_inventory_row)
		if inventory_center != Vector2.INF:
			return inventory_center
	var participant_node := _control_for_participant_or_viewer(participant_id)
	var participant_center := _control_global_center(participant_node)
	if participant_center != Vector2.INF:
		return participant_center
	var participant := _participant_from_snapshot(_snapshot, participant_id)
	var ingredient_id := str(participant.get("ingredientId", ""))
	if ingredient_id != "":
		var ingredient_owner_center := _ingredient_owner_global_center(ingredient_id)
		if ingredient_owner_center != Vector2.INF:
			return ingredient_owner_center
	return Vector2.INF


func _hand_card_or_row_center(ingredient_id: String) -> Vector2:
	var hand_card := find_child("HandCard_%s" % ingredient_id, true, false) as Control
	var hand_center := _control_global_center(hand_card)
	if hand_center != Vector2.INF:
		return hand_center
	var hand_area := _control_global_center(_hand_row)
	if hand_area != Vector2.INF:
		return hand_area
	return _control_global_center(_inventory_row)


func _inventory_stock_or_row_center(ingredient_id: String) -> Vector2:
	var stock_item := find_child("InventoryStock_%s" % ingredient_id, true, false) as Control
	var stock_center := _control_global_center(stock_item)
	if stock_center != Vector2.INF:
		return stock_center
	var inventory_center := _control_global_center(_inventory_row)
	if inventory_center != Vector2.INF:
		return inventory_center
	return _control_global_center(_hand_row)


func _public_redeem_actor_center(event: Dictionary) -> Vector2:
	return _participant_tile_center(str(event.get("participantId", "")))


func _swap_point(event: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value = event.get(key, fallback)
	return value if typeof(value) == TYPE_VECTOR2 else fallback


func _swap_give_start_center(event: Dictionary) -> Vector2:
	return _asset_start_center(event, "give")


func _swap_give_end_center(event: Dictionary) -> Vector2:
	var end := _asset_platter_target_center(event, "give")
	return end if end != Vector2.INF else _control_global_center(_basket_grid)


func _swap_take_start_center(event: Dictionary) -> Vector2:
	var start := _asset_start_center(event, "take")
	return start if start != Vector2.INF else _control_global_center(_basket_grid)


func _swap_take_end_center(event: Dictionary) -> Vector2:
	var actor_id := _swap_actor_id(event)
	if actor_id == "":
		return Vector2.INF
	return _asset_inventory_target_center(event, "take", actor_id)


func _asset_start_center(event: Dictionary, prefix: String) -> Vector2:
	var kind := str(event.get("%sKind" % prefix, ""))
	var actor_id := str(event.get("actorParticipantId", ""))
	if kind == "voucher":
		var ingredient_id := str(event.get("%sIngredientId" % prefix, ""))
		if prefix == "give":
			if actor_id != "" and actor_id != _viewer_id():
				return _participant_tile_center(actor_id)
			return _hand_card_or_row_center(ingredient_id)
		return _platter_voucher_center(ingredient_id)
	if kind == "dish_part":
		var dish_name := str(event.get("%sDishName" % prefix, "Dish"))
		if prefix == "give":
			if actor_id != "" and actor_id != _viewer_id():
				return _participant_tile_center(actor_id)
			var hand_food_center := _hand_food_center_by_name(dish_name)
			return hand_food_center if hand_food_center != Vector2.INF else _control_global_center(_hand_row)
		return _platter_food_center_by_name(dish_name)
	return Vector2.INF


func _asset_platter_target_center(event: Dictionary, prefix: String) -> Vector2:
	var kind := str(event.get("%sKind" % prefix, ""))
	if kind == "voucher":
		return _platter_voucher_center(str(event.get("%sIngredientId" % prefix, "")))
	if kind == "dish_part":
		return _platter_food_center_by_name(str(event.get("%sDishName" % prefix, "")))
	return Vector2.INF


func _asset_inventory_target_center(event: Dictionary, prefix: String, participant_id: String) -> Vector2:
	if participant_id != "" and participant_id != _viewer_id():
		return _participant_tile_center(participant_id)
	var kind := str(event.get("%sKind" % prefix, ""))
	if kind == "voucher":
		return _hand_card_or_row_center(str(event.get("%sIngredientId" % prefix, "")))
	if kind == "dish_part":
		var dish_id := _dish_id_for_name(str(event.get("%sDishName" % prefix, "")))
		var food_node := find_child("HandFood_%s" % dish_id, true, false) as Control
		var food_center := _control_global_center(food_node)
		return food_center if food_center != Vector2.INF else _control_global_center(_hand_row)
	return _control_global_center(_hand_row)


func _platter_voucher_center(ingredient_id: String) -> Vector2:
	var slot_node := find_child("BasketSlot_%s" % ingredient_id, true, false) as Control
	var slot_center := _control_global_center(slot_node)
	if slot_center != Vector2.INF:
		return slot_center
	var platter_node := find_child("PlatterVoucher_%s" % ingredient_id, true, false) as Control
	return _control_global_center(platter_node)


func _basket_slot_center_for_visual_slot(visual_slot_index: int) -> Vector2:
	if visual_slot_index < 0 or not is_instance_valid(_basket_grid):
		return Vector2.INF
	for raw_child in _basket_grid.get_children():
		var child := raw_child as Control
		if child != null and child.has_meta("basket_slot_index") and int(child.get_meta("basket_slot_index")) == visual_slot_index:
			return _control_global_center(child)
	return Vector2.INF


func _platter_food_center_by_name(dish_name: String) -> Vector2:
	for raw_group in _food_part_group_options(_snapshot.get("platterFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) != dish_name:
			continue
		var platter_node := find_child("PlatterFood_%s" % str(group.get("dishId", "")), true, false) as Control
		return _control_global_center(platter_node)
	return _basket_food_slot_center_by_name(dish_name)


func _basket_food_slot_center_by_name(dish_name: String) -> Vector2:
	if not is_instance_valid(_basket_grid):
		return Vector2.INF
	var food_groups := _food_part_group_options(_snapshot.get("platterFoodParts", []))
	var food_rank := food_groups.size()
	for index in range(food_groups.size()):
		var group: Dictionary = food_groups[index]
		if str(group.get("dishName", "")) == dish_name:
			food_rank = index
			break
	return _basket_grid_index_center(BASKET_CENTER_OUT_SLOTS.size() + food_rank)


func _basket_grid_index_center(index: int) -> Vector2:
	if index < 0 or not is_instance_valid(_basket_grid):
		return Vector2.INF
	if index < _basket_grid.get_child_count():
		var child := _basket_grid.get_child(index) as Control
		var child_center := _control_global_center(child)
		if child_center != Vector2.INF:
			return child_center
	var columns := maxi(1, _basket_grid.columns)
	var row := index / columns
	var column := index % columns
	var rect := _basket_grid.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.INF
	var x := rect.position.x + float(column) * (BASKET_SLOT_SIZE.x + BASKET_GRID_GAP) + BASKET_SLOT_SIZE.x * 0.5
	var y := rect.position.y + float(row) * (BASKET_SLOT_SIZE.y + BASKET_GRID_GAP) + BASKET_SLOT_SIZE.y * 0.5
	return Vector2(x, y)


func _hand_food_center_by_name(dish_name: String) -> Vector2:
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) != dish_name:
			continue
		var food_node := find_child("HandFood_%s" % str(group.get("dishId", "")), true, false) as Control
		return _control_global_center(food_node)
	return Vector2.INF


func _event_asset_texture(event: Dictionary, prefix: String) -> Texture2D:
	var kind := str(event.get("%sKind" % prefix, ""))
	if kind == "voucher":
		return _ingredient_texture(str(event.get("%sIngredientId" % prefix, "")))
	if kind == "dish_part":
		var dish_name := str(event.get("%sDishName" % prefix, "Dish"))
		var unit := str(event.get("%sUnit" % prefix, "part"))
		var texture = VisualAssets.dish_meta(dish_name, unit).get("texture", null)
		return texture if texture is Texture2D else null
	return null


func _ingredient_texture(ingredient_id: String) -> Texture2D:
	var texture = VisualAssets.ingredient_meta(ingredient_id).get("texture", null)
	return texture if texture is Texture2D else null


func _control_for_ingredient_owner(ingredient_id: String) -> Control:
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("ingredientId", "")) != ingredient_id:
			continue
		return _control_for_participant_or_viewer(str(participant.get("id", "")))
	return null


func _ingredient_id_from_label(label: String) -> String:
	var normalized := label.strip_edges().to_lower()
	if normalized.begins_with("real "):
		normalized = normalized.substr("real ".length()).strip_edges()
	normalized = normalized.replace("#", " ")
	normalized = normalized.replace("promise ", "")
	normalized = normalized.replace(" vouchers", "")
	normalized = normalized.replace(" voucher", "")
	normalized = normalized.replace(" cards", "")
	normalized = normalized.replace(" card", "")
	normalized = normalized.replace("veggies", "vegetables")
	normalized = _trim_label_quantity_suffix(normalized)
	for raw_ingredient in _snapshot.get("ingredients", []):
		var ingredient: Dictionary = raw_ingredient
		var ingredient_id := str(ingredient.get("id", ""))
		var ingredient_name := _ingredient_display(ingredient_id).to_lower()
		if normalized == ingredient_id.to_lower() or normalized == ingredient_name:
			return ingredient_id
	for raw_id in ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]:
		if normalized == str(raw_id):
			return str(raw_id)
	return ""


func _trim_label_quantity_suffix(label: String) -> String:
	var normalized := label.strip_edges()
	var x_index := normalized.rfind(" x")
	if x_index > 0:
		var suffix := normalized.substr(x_index + 2).strip_edges()
		if suffix.is_valid_int():
			return normalized.substr(0, x_index).strip_edges()
	var parts := normalized.split(" ", false)
	while parts.size() > 1 and str(parts[parts.size() - 1]).is_valid_int():
		parts.remove_at(parts.size() - 1)
	return " ".join(parts).strip_edges()


func _ingredient_ids_from_label_list(label: String) -> Array[String]:
	var ids: Array[String] = []
	for raw_part in label.split(","):
		var ingredient_id := _ingredient_id_from_label(str(raw_part))
		if ingredient_id != "":
			ids.append(ingredient_id)
	return ids


func _ingredient_owner_global_center(ingredient_id: String) -> Vector2:
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("ingredientId", "")) != ingredient_id:
			continue
		var participant_id := str(participant.get("id", ""))
		if participant_id == _viewer_id():
			return _control_global_center(_inventory_row)
		var participant_node := find_child("Participant_%s" % participant_id, true, false) as Control
		if is_instance_valid(participant_node):
			return _control_global_center(participant_node)
	return Vector2.INF


func _control_global_center(control: Control) -> Vector2:
	if not is_instance_valid(control):
		return Vector2.INF
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.INF
	return rect.get_center()


func _animation_local(global_point: Vector2) -> Vector2:
	if not is_instance_valid(_animation_layer):
		return global_point
	return _animation_layer.get_global_transform_with_canvas().affine_inverse() * global_point


func _valid_points(points: Array) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	for raw_point in points:
		var point: Vector2 = raw_point
		if point != Vector2.INF:
			valid.append(point)
	return valid


func _animate_event_asset_tile_path(event: Dictionary, prefix: String, global_points: Array[Vector2], delay := 0.0, start_visible := true) -> void:
	var kind := str(event.get("%sKind" % prefix, ""))
	if kind == "voucher":
		_animate_voucher_card_path(str(event.get("%sIngredientId" % prefix, "")), global_points, delay, start_visible)
	elif kind == "dish_part":
		_animate_dish_part_card_path(
			str(event.get("%sDishName" % prefix, "Dish")),
			str(event.get("%sUnit" % prefix, "part")),
			global_points,
			delay,
			start_visible
		)


func _animate_voucher_card_path(ingredient_id: String, global_points: Array[Vector2], delay := 0.0, start_visible := true) -> void:
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	_animate_visual_tile_path(meta, _ingredient_display(ingredient_id), global_points, delay, start_visible)


func _animate_dish_part_card_path(dish_name: String, unit: String, global_points: Array[Vector2], delay := 0.0, start_visible := true) -> void:
	var meta := VisualAssets.dish_meta(dish_name, unit)
	_animate_visual_tile_path(meta, VisualAssets.short_dish_name(dish_name), global_points, delay, start_visible)


func _animate_visual_tile_path(meta: Dictionary, label: String, global_points: Array[Vector2], delay := 0.0, start_visible := true) -> void:
	if global_points.size() < 2 or not is_instance_valid(_animation_layer):
		return
	var tile_size := BASKET_SLOT_SIZE
	var tile := Button.new()
	tile.name = "AnimatedCard_%s" % label.replace(" ", "_")
	debug_stats["lastAnimatedCardSize"] = tile_size
	tile.text = ""
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_contents = true
	tile.size = tile_size
	tile.custom_minimum_size = tile_size
	tile.pivot_offset = tile_size * 0.5
	tile.scale = Vector2(0.96, 0.96)
	tile.modulate = Color(1, 1, 1, 0.98) if start_visible else Color(1, 1, 1, 0)
	var bg: Color = meta.get("color", Color(0.86, 0.78, 0.58))
	_apply_button_style(tile, bg, Color(0.30, 0.35, 0.42), 1)
	_add_visual_content(tile, "", label, meta, tile_size, _contrast_ink(bg), true)
	_animation_layer.add_child(tile)

	var local_points: Array[Vector2] = []
	for point in global_points:
		local_points.append(_animation_local(point))
	tile.position = local_points[0] - tile_size * 0.5

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	if not start_visible:
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 0.98), CARD_TILE_FADE_IN_SECONDS)
	for index in range(1, local_points.size()):
		tween.tween_property(tile, "position", local_points[index] - tile_size * 0.5, CARD_TILE_MOVE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(tile, "scale", Vector2(1.05, 1.05), CARD_TILE_PULSE_SECONDS * 0.5)
		tween.tween_property(tile, "scale", Vector2(0.96, 0.96), CARD_TILE_PULSE_SECONDS * 0.5)
	tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), CARD_TILE_FADE_OUT_SECONDS)
	tween.tween_callback(tile.queue_free)


func _animate_texture_path(texture: Texture2D, global_points: Array[Vector2], delay := 0.0, icon_size := Vector2(46, 46)) -> void:
	if global_points.size() < 2 or not is_instance_valid(_animation_layer) or not texture is Texture2D:
		return
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.size = icon_size
	icon.custom_minimum_size = icon_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 0)
	icon.scale = Vector2.ONE
	_animation_layer.add_child(icon)

	var local_points: Array[Vector2] = []
	for point in global_points:
		local_points.append(_animation_local(point))
	icon.position = local_points[0] - icon_size * 0.5

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), TEXTURE_FADE_IN_SECONDS)
	for index in range(1, local_points.size()):
		tween.tween_property(icon, "position", local_points[index] - icon_size * 0.5, TEXTURE_MOVE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "scale", Vector2(1.08, 1.08), TEXTURE_PULSE_SECONDS * 0.5)
		tween.tween_property(icon, "scale", Vector2.ONE, TEXTURE_PULSE_SECONDS * 0.5)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 0), TEXTURE_FADE_OUT_SECONDS)
	tween.tween_callback(icon.queue_free)


func _animate_large_dish(texture: Texture2D, dish_name: String, global_start: Vector2, global_end: Vector2, delay := 0.0) -> void:
	if not is_instance_valid(_animation_layer) or global_start == Vector2.INF or global_end == Vector2.INF:
		return
	var wrapper := PanelContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = Vector2(148, 162)
	wrapper.pivot_offset = wrapper.size * 0.5
	wrapper.modulate = Color(1, 1, 1, 0)
	wrapper.scale = Vector2(0.45, 0.45)
	wrapper.add_theme_stylebox_override("panel", _prepare_dish_style())
	_animation_layer.add_child(wrapper)
	wrapper.position = _animation_local(global_start) - wrapper.size * 0.5

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(box)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		icon.custom_minimum_size = Vector2(108, 108)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
	var label := _card_label(VisualAssets.short_dish_name(dish_name), TEXT_DARK, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(wrapper, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.parallel().tween_property(wrapper, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.44)
	tween.tween_property(wrapper, "position", _animation_local(global_end) - wrapper.size * 0.5, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(wrapper, "scale", Vector2(0.28, 0.28), 0.28)
	tween.parallel().tween_property(wrapper, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(wrapper.queue_free)


func _animate_prepare_ingredient_swirl(global_center: Vector2) -> void:
	if global_center == Vector2.INF or not is_instance_valid(_animation_layer):
		return
	var slots := _prepare_swirl_slots()
	var total := slots.size()
	if total == 0:
		return
	for index in range(total):
		var slot: Dictionary = slots[index]
		_animate_swirl_ingredient(
			str(slot.get("ingredientId", "")),
			slot.get("center", global_center),
			global_center,
			index,
			total
		)


func _prepare_swirl_slots() -> Array:
	var items: Array = []
	var slots := _recipe_slots(_snapshot.get("ownRecipe", {}))
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		var ingredient_id := str(slot.get("ingredientId", ""))
		if ingredient_id == "":
			continue
		var slot_node := find_child("RecipeSlot_%s_%s" % [ingredient_id, index], true, false) as Control
		var center := _control_global_center(slot_node)
		if center == Vector2.INF:
			center = _control_global_center(_recipe_grid)
		items.append({
			"ingredientId": ingredient_id,
			"center": center
		})
	return items


func _animate_swirl_ingredient(ingredient_id: String, global_start: Vector2, global_center: Vector2, index: int, total: int) -> void:
	var texture := _ingredient_texture(ingredient_id)
	if not texture is Texture2D or global_start == Vector2.INF:
		return
	var icon_size := Vector2(48, 48)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.size = icon_size
	icon.pivot_offset = icon_size * 0.5
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = _animation_local(global_start) - icon_size * 0.5
	icon.modulate = Color(1, 1, 1, 0)
	icon.scale = Vector2(0.84, 0.84)
	_animation_layer.add_child(icon)

	var center := _animation_local(global_center)
	var angle := TAU * float(index) / float(maxi(total, 1))
	var radius := 78.0
	var orbit_a := center + Vector2(cos(angle), sin(angle)) * radius
	var orbit_b := center + Vector2(cos(angle + TAU * 0.42), sin(angle + TAU * 0.42)) * (radius * 0.88)
	var orbit_c := center + Vector2(cos(angle + TAU * 0.82), sin(angle + TAU * 0.82)) * (radius * 0.48)
	var delay := float(index) * 0.035

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.05)
	tween.parallel().tween_property(icon, "scale", Vector2(1.04, 1.04), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "rotation", angle + TAU * 0.33, 0.24)
	tween.tween_property(icon, "position", orbit_a - icon_size * 0.5, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "rotation", angle + TAU * 0.82, 0.22)
	tween.tween_property(icon, "position", orbit_b - icon_size * 0.5, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "rotation", angle + TAU * 1.28, 0.20)
	tween.tween_property(icon, "position", orbit_c - icon_size * 0.5, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2(1.18, 1.18), 0.16)
	tween.parallel().tween_property(icon, "rotation", angle + TAU * 1.72, 0.18)
	tween.tween_property(icon, "position", center - icon_size * 0.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "scale", Vector2(0.20, 0.20), 0.12)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 0), 0.12)
	tween.tween_callback(icon.queue_free)


func _pop_texture(texture: Texture2D, global_center: Vector2) -> void:
	if not texture is Texture2D or global_center == Vector2.INF or not is_instance_valid(_animation_layer):
		return
	var icon_size := Vector2(54, 54)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.size = icon_size
	icon.pivot_offset = icon_size * 0.5
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = _animation_local(global_center) - icon_size * 0.5
	icon.modulate = Color(1, 1, 1, 0.95)
	_animation_layer.add_child(icon)
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2(0.2, 0.2), 0.18)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.tween_callback(icon.queue_free)


func _animate_offer_badge_arrival(participant_node: Control, text: String, color: Color) -> void:
	if not is_instance_valid(participant_node) or not is_instance_valid(_animation_layer):
		return
	var center := _control_global_center(participant_node)
	if center == Vector2.INF:
		return
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(38, 38)
	badge.pivot_offset = badge.size * 0.5
	badge.position = _animation_local(center + Vector2(26, -24)) - badge.size * 0.5
	badge.scale = Vector2(0.35, 0.35)
	badge.modulate = Color(1, 1, 1, 0)
	badge.add_theme_stylebox_override("panel", _panel_style(color, Color(1, 0.96, 0.78), 2, 19))
	_animation_layer.add_child(badge)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	var tween := create_tween()
	tween.tween_property(badge, "modulate", Color(1, 1, 1, 0.98), 0.08)
	tween.parallel().tween_property(badge, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "scale", Vector2(0.9, 0.9), 0.12)
	tween.tween_property(badge, "modulate", Color(1, 1, 1, 0), 0.16)
	tween.tween_callback(badge.queue_free)


func _pulse_control(control: Control, color: Color) -> void:
	if not is_instance_valid(control):
		return
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not is_instance_valid(_animation_layer):
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = rect.size + Vector2(10, 10)
	panel.position = _animation_local(rect.position) - Vector2(5, 5)
	panel.modulate = Color(1, 1, 1, 0)
	panel.add_theme_stylebox_override("panel", _pulse_style(color))
	_animation_layer.add_child(panel)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0.72), 0.08)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(panel.queue_free)


func _start_offer_badge_pulse(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	panel.modulate = Color(1, 1, 1, 1)
	var tween := panel.create_tween()
	tween.set_loops()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0.66), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1.0), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _glow_recipe_slots() -> void:
	for child in _recipe_grid.get_children():
		if child is Control:
			_pulse_control(child, Color(0.95, 0.68, 0.22))


func _animate_poof_burst(global_center: Vector2, delay := 0.0) -> void:
	if global_center == Vector2.INF or not is_instance_valid(_animation_layer):
		return
	var center := _animation_local(global_center)
	var label := Label.new()
	label.text = "Poof!"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.46, 0.20, 0.08))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.86, 0.42))
	label.add_theme_constant_override("outline_size", 4)
	label.size = Vector2(116, 48)
	label.pivot_offset = label.size * 0.5
	label.position = center - label.size * 0.5
	label.scale = Vector2(0.35, 0.35)
	label.modulate = Color(1, 1, 1, 0)
	_animation_layer.add_child(label)

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(46, 46)
	ring.pivot_offset = ring.size * 0.5
	ring.position = center - ring.size * 0.5
	ring.scale = Vector2(0.18, 0.18)
	ring.modulate = Color(1, 1, 1, 0)
	ring.add_theme_stylebox_override("panel", _pulse_style(Color(1.0, 0.74, 0.18)))
	_animation_layer.add_child(ring)

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.07)
	tween.parallel().tween_property(label, "scale", Vector2(1.28, 1.28), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate", Color(1, 1, 1, 0.80), 0.06)
	tween.parallel().tween_property(ring, "scale", Vector2(3.2, 3.2), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.14)
	tween.tween_property(label, "position", label.position + Vector2(0, -20), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.16)
	tween.parallel().tween_property(ring, "modulate", Color(1, 1, 1, 0), 0.16)
	tween.tween_callback(label.queue_free)
	tween.tween_callback(ring.queue_free)


func _emit_steam_wisps(global_center: Vector2, delay := 0.0) -> void:
	if global_center == Vector2.INF or not is_instance_valid(_animation_layer):
		return
	var center := _animation_local(global_center)
	for index in range(5):
		var wisp := ColorRect.new()
		wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wisp.color = Color(1.0, 0.94, 0.78, 0.70)
		wisp.size = Vector2(5, 18)
		wisp.position = center + Vector2(float(index - 2) * 15.0, 16)
		wisp.modulate = Color(1, 1, 1, 0)
		_animation_layer.add_child(wisp)
		var tween := create_tween()
		tween.tween_interval(delay + float(index) * 0.05)
		tween.tween_property(wisp, "modulate", Color(1, 1, 1, 0.72), 0.08)
		tween.parallel().tween_property(wisp, "position", wisp.position + Vector2(float((index % 2) * 2 - 1) * 10.0, -48), 0.54).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(wisp, "scale", Vector2(1.6, 1.2), 0.54)
		tween.tween_property(wisp, "modulate", Color(1, 1, 1, 0), 0.18)
		tween.tween_callback(wisp.queue_free)


func _emit_sparkles(global_center: Vector2, count: int, color: Color, delay := 0.0) -> void:
	if global_center == Vector2.INF or not is_instance_valid(_animation_layer):
		return
	var center: Vector2 = _animation_local(global_center)
	for index in range(count):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.color = color.lightened(float(index % 4) * 0.08)
		dot.size = Vector2(4 + (index % 3), 4 + (index % 3))
		dot.position = center
		dot.modulate = Color(1, 1, 1, 0)
		_animation_layer.add_child(dot)
		var angle := TAU * float(index) / float(maxi(1, count))
		var distance := 22.0 + float((index * 7) % 42)
		var target: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		var tween := create_tween()
		tween.tween_interval(delay + float(index % 5) * 0.015)
		tween.tween_property(dot, "modulate", Color(1, 1, 1, 0.95), 0.05)
		tween.parallel().tween_property(dot, "position", target, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot, "modulate", Color(1, 1, 1, 0), 0.14)
		tween.tween_callback(dot.queue_free)


func _participant_map(snapshot: Dictionary) -> Dictionary:
	var by_id := {}
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if participant_id != "":
			by_id[participant_id] = participant
	return by_id


func _new_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var previous_ids := {}
	for raw_transaction in previous_snapshot.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		var id := str(transaction.get("id", ""))
		if id != "":
			previous_ids[id] = true
	var rows: Array = []
	for raw_transaction in current_snapshot.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		var id := str(transaction.get("id", ""))
		if id != "" and previous_ids.has(id):
			continue
		rows.append(transaction)
	return rows


func _latest_new_transaction_by_actions(previous_snapshot: Dictionary, current_snapshot: Dictionary, actions: Array[String], skip_participant_id := "") -> Dictionary:
	var rows := _new_transactions(previous_snapshot, current_snapshot)
	for index in range(rows.size() - 1, -1, -1):
		var transaction: Dictionary = rows[index]
		if skip_participant_id != "" and str(transaction.get("participantId", "")) == skip_participant_id:
			continue
		if actions.has(str(transaction.get("action", ""))):
			return transaction
	return {}


func _participant_from_snapshot(snapshot: Dictionary, participant_id: String) -> Dictionary:
	if participant_id == "":
		return {}
	var by_id := _participant_map(snapshot)
	return by_id.get(participant_id, {})


func _deposit_participant_order_from_transactions(snapshot: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_transaction in snapshot.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Deposit":
			continue
		var participant_id := str(transaction.get("participantId", ""))
		if participant_id != "" and not ids.has(participant_id):
			ids.append(participant_id)
	return ids


func _basket_slot_index_for_deposit_participant(participant_id: String, deposit_order: Array[String], fallback_rank: int) -> int:
	var rank := deposit_order.find(participant_id)
	if rank < 0:
		rank = fallback_rank
	if rank < 0 or rank >= BASKET_CENTER_OUT_SLOTS.size():
		return -1
	return int(BASKET_CENTER_OUT_SLOTS[rank])


func _voucher_counts(vouchers: Array) -> Dictionary:
	var counts := {}
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id != "":
			counts[ingredient_id] = int(counts.get(ingredient_id, 0)) + 1
	return counts


func _food_part_counts(parts: Array) -> Dictionary:
	var counts := {}
	for raw_part in parts:
		var part: Dictionary = raw_part
		var dish_id := str(part.get("dishId", ""))
		if dish_id == "":
			continue
		if not counts.has(dish_id):
			counts[dish_id] = {
				"count": 0,
				"dishId": dish_id,
				"dishName": str(part.get("dishName", "Dish")),
				"unitSingular": str(part.get("unitSingular", "part"))
			}
		var row: Dictionary = counts[dish_id]
		row["count"] = int(row.get("count", 0)) + 1
	return counts


func _count_only(grouped: Dictionary) -> Dictionary:
	var counts := {}
	for key in grouped.keys():
		var row: Dictionary = grouped[key]
		counts[key] = int(row.get("count", 0))
	return counts


func _count_delta(previous: Dictionary, current: Dictionary) -> Dictionary:
	var delta := {}
	for key in previous.keys():
		delta[key] = int(current.get(key, 0)) - int(previous.get(key, 0))
	for key in current.keys():
		if not delta.has(key):
			delta[key] = int(current.get(key, 0))
	return delta


func _positive_keys(delta: Dictionary) -> Array:
	var keys: Array = []
	for key in delta.keys():
		if int(delta[key]) > 0:
			keys.append(key)
	return keys


func _negative_keys(delta: Dictionary) -> Array:
	var keys: Array = []
	for key in delta.keys():
		if int(delta[key]) < 0:
			keys.append(key)
	return keys


func _new_food_part_info(previous_parts: Array, current_parts: Array) -> Dictionary:
	var previous_counts := _food_part_counts(previous_parts)
	var current_counts := _food_part_counts(current_parts)
	var delta := _count_delta(_count_only(previous_counts), _count_only(current_counts))
	for dish_id in _positive_keys(delta):
		return current_counts.get(dish_id, {})
	return {}


func _offer_indicator_for_participant_in(snapshot: Dictionary, participant_id: String, viewer_id: String) -> String:
	var incoming := false
	var outgoing := false
	for raw_offer in snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		if str(offer.get("fromParticipantId", "")) == participant_id and str(offer.get("toParticipantId", "")) == viewer_id:
			incoming = true
		if str(offer.get("fromParticipantId", "")) == viewer_id and str(offer.get("toParticipantId", "")) == participant_id:
			outgoing = true
	var labels: Array[String] = []
	if incoming:
		labels.append("!")
	if outgoing:
		labels.append("?")
	return "".join(labels)


func _dish_id_for_name(dish_name: String) -> String:
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) == dish_name:
			return str(group.get("dishId", ""))
	return ""


func _recipe_name(recipe: Dictionary) -> String:
	if recipe.is_empty():
		return ""
	var name := str(recipe.get("name", ""))
	if name != "":
		return name
	return str(recipe.get("dishName", ""))


func _recipe_title(recipe_name: String) -> String:
	var target := int(_snapshot.get("targetDishCount", 0))
	if target <= 0:
		return "Recipe: %s" % recipe_name
	var viewer := _participant_by_id(_viewer_id())
	var completed := int(viewer.get("dishCount", 0)) if not viewer.is_empty() else 0
	var recipe_number := clampi(completed + 1, 1, target)
	return "Recipe %s/%s: %s" % [recipe_number, target, recipe_name]


func _recipe_slot(slot: Dictionary, index: int) -> Control:
	var ingredient_id := str(slot.get("ingredientId", ""))
	var status := str(slot.get("status", "empty"))
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	var bg := Color(0.76, 0.76, 0.70)
	var border := Color(0.46, 0.46, 0.42)
	if status == "redeemed":
		bg = Color(0, 0, 0, 0)
		border = Color(0, 0, 0, 0)
	elif status == "placed":
		bg = Color(0.96, 0.62, 0.28)
		border = Color(0.65, 0.34, 0.08)
	var wrapper := Control.new()
	wrapper.name = "RecipeSlot_%s_%s" % [ingredient_id, index]
	wrapper.custom_minimum_size = RECIPE_SLOT_SIZE
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.clip_contents = false
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _real_ingredient_slot_style() if status == "redeemed" else _panel_style(bg, border, 1, 8))
	wrapper.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0 if status == "redeemed" else 1)
	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(48, 36) if status == "redeemed" else Vector2(42, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1, 1, 1, 1) if status == "redeemed" else Color(0.55, 0.55, 0.55, 0.72)
		box.add_child(icon)
	var label := _label(_recipe_ingredient_display(ingredient_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT_DARK if status == "redeemed" else Color(0.30, 0.30, 0.28))
	box.add_child(label)
	panel.add_child(box)
	if status == "redeemed":
		wrapper.add_child(_recipe_checkmark_overlay(ingredient_id, index))
	return wrapper


func _recipe_checkmark_overlay(ingredient_id: String, index: int) -> Label:
	var check := _label("✓")
	check.name = "RecipeCheck_%s_%s" % [ingredient_id, index]
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.custom_minimum_size = Vector2(20, 20)
	check.size = Vector2(20, 20)
	check.anchor_left = 1.0
	check.anchor_right = 1.0
	check.anchor_top = 0.5
	check.anchor_bottom = 0.5
	check.offset_left = -22.0
	check.offset_right = -2.0
	check.offset_top = -10.0
	check.offset_bottom = 10.0
	check.add_theme_color_override("font_color", Color(0.08, 0.55, 0.18))
	check.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 0.82))
	check.add_theme_constant_override("outline_size", 2)
	check.add_theme_font_size_override("font_size", 18)
	return check


func _outstanding_requirement_for_ingredient(ingredient_id: String) -> Dictionary:
	var recipe: Dictionary = _snapshot.get("ownRecipe", {})
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) != ingredient_id:
			continue
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if outstanding > 0:
			return requirement
	return {}


func _recipe_ready(recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return false
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return false
	return true


func _voucher_group_options(vouchers: Array) -> Array:
	var by_ingredient := {}
	var order: Array[String] = []
	for raw_voucher in vouchers:
		var voucher: Dictionary = raw_voucher
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id == "":
			continue
		if not by_ingredient.has(ingredient_id):
			by_ingredient[ingredient_id] = {
				"ingredientId": ingredient_id,
				"ownerParticipantId": str(voucher.get("ownerParticipantId", "")),
				"voucherId": str(voucher.get("id", "")),
				"count": 0
			}
			order.append(ingredient_id)
		var group: Dictionary = by_ingredient[ingredient_id]
		group["count"] = int(group.get("count", 0)) + 1
	var options: Array = []
	for ingredient_id in order:
		options.append(by_ingredient[ingredient_id])
	return options


func _auto_select_give_card(forbidden_ingredient_id: String) -> bool:
	if not _can_act_now("playing"):
		return false
	var group := _default_give_card_group(forbidden_ingredient_id)
	if group.is_empty():
		return false
	_select_hand_group(group)
	return true


func _auto_select_give_asset(forbidden_ingredient_id: String, phase: String) -> bool:
	if not _can_act_now(phase):
		return false
	var group := _default_give_card_group(forbidden_ingredient_id)
	if not group.is_empty():
		_select_hand_group(group)
		return true
	var food_group := _default_give_food_part_group()
	if not food_group.is_empty():
		_select_food_part_group(food_group)
		return true
	return false


func _default_give_card_group(forbidden_ingredient_id: String) -> Dictionary:
	var groups := _voucher_group_options(_snapshot.get("ownHand", []))
	if groups.is_empty():
		return {}
	var main_ingredient_id := _viewer_main_ingredient_id()
	if main_ingredient_id != "" and main_ingredient_id != forbidden_ingredient_id:
		for raw_group in groups:
			var group: Dictionary = raw_group
			if str(group.get("ingredientId", "")) == main_ingredient_id and _voucher_group_has_stock(group):
				return group
	var best: Dictionary = {}
	for raw_group in groups:
		var group: Dictionary = raw_group
		var ingredient_id := str(group.get("ingredientId", ""))
		if ingredient_id == forbidden_ingredient_id or not _voucher_group_has_stock(group):
			continue
		if best.is_empty() or int(group.get("count", 0)) > int(best.get("count", 0)) or (
			int(group.get("count", 0)) == int(best.get("count", 0)) and ingredient_id < str(best.get("ingredientId", ""))
		):
			best = group
	return best


func _default_give_food_part_group() -> Dictionary:
	var best: Dictionary = {}
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		if best.is_empty() or int(group.get("count", 0)) > int(best.get("count", 0)) or (
			int(group.get("count", 0)) == int(best.get("count", 0)) and str(group.get("dishName", "")) < str(best.get("dishName", ""))
		):
			best = group
	return best


func _select_hand_group(group: Dictionary) -> void:
	var voucher_id := str(group.get("voucherId", ""))
	var ingredient_id := str(group.get("ingredientId", ""))
	if voucher_id == "" or ingredient_id == "":
		return
	_selected_hand_voucher_id = voucher_id
	_selected_hand_ingredient_id = ingredient_id
	_selected_inventory_asset_key = "voucher:%s" % voucher_id


func _select_food_part_group(group: Dictionary) -> void:
	var part_id := str(group.get("partId", ""))
	if part_id == "":
		return
	_selected_inventory_asset_key = "dish_part:%s" % part_id
	_selected_hand_voucher_id = ""
	_selected_hand_ingredient_id = ""


func _viewer_main_ingredient_id() -> String:
	var viewer := _participant_by_id(_viewer_id())
	return str(viewer.get("ingredientId", ""))


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
		options.append(by_dish[dish_id])
	return options


func _hand_group_for_ingredient(ingredient_id: String) -> Dictionary:
	return _voucher_group_for_ingredient(_snapshot.get("ownHand", []), ingredient_id)


func _voucher_group_for_ingredient(vouchers: Array, ingredient_id: String) -> Dictionary:
	for raw_group in _voucher_group_options(vouchers):
		var group: Dictionary = raw_group
		if str(group.get("ingredientId", "")) == ingredient_id:
			return group
	return {}


func _matching_hand_voucher_ids(ingredient_id: String, quantity: int) -> Array:
	var ids: Array = []
	for raw_voucher in _snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) != ingredient_id:
			continue
		if not _voucher_has_stock(voucher):
			continue
		ids.append(str(voucher.get("id", "")))
		if ids.size() >= quantity:
			break
	return ids


func _voucher_group_has_stock(group: Dictionary) -> bool:
	var owner_id := str(group.get("ownerParticipantId", ""))
	if owner_id == "":
		for raw_voucher in _snapshot.get("ownHand", []) + _snapshot.get("platter", []):
			var voucher: Dictionary = raw_voucher
			if str(voucher.get("id", "")) == str(group.get("voucherId", "")):
				return _voucher_has_stock(voucher)
		return true
	var owner := _participant_by_id(owner_id)
	return int(owner.get("realIngredientStock", 0)) > 0


func _voucher_has_stock(voucher: Dictionary) -> bool:
	var owner := _participant_by_id(str(voucher.get("ownerParticipantId", "")))
	return int(owner.get("realIngredientStock", 0)) > 0


func _offer_indicator_for_participant(participant_id: String) -> String:
	var incoming := false
	var outgoing := false
	for raw_offer in _snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		if str(offer.get("fromParticipantId", "")) == participant_id and str(offer.get("toParticipantId", "")) == _viewer_id():
			incoming = true
		if str(offer.get("fromParticipantId", "")) == _viewer_id() and str(offer.get("toParticipantId", "")) == participant_id:
			outgoing = true
	var labels: Array[String] = []
	if incoming:
		labels.append(" !")
	if outgoing:
		labels.append(" ?")
	return "".join(labels)


func _has_visible_offer_for_participant(participant_id: String) -> bool:
	return _offer_indicator_for_participant(participant_id) != ""


func _offer_count(incoming: bool) -> int:
	var count := 0
	for raw_offer in _snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending":
			continue
		if incoming and str(offer.get("toParticipantId", "")) == _viewer_id():
			count += 1
		elif not incoming and str(offer.get("fromParticipantId", "")) == _viewer_id():
			count += 1
	return count


func _offer_cards_label(offer: Dictionary) -> String:
	var by_ingredient := {}
	for raw_voucher in offer.get("offeredVouchers", []):
		var voucher: Dictionary = raw_voucher
		var ingredient_id := str(voucher.get("ingredientId", ""))
		by_ingredient[ingredient_id] = int(by_ingredient.get(ingredient_id, 0)) + 1
	if by_ingredient.is_empty():
		for raw_id in offer.get("offeredVoucherIds", []):
			var ingredient_id := _ingredient_id_for_voucher(str(raw_id))
			if ingredient_id != "":
				by_ingredient[ingredient_id] = int(by_ingredient.get(ingredient_id, 0)) + 1
	var labels: Array[String] = []
	for raw_key in by_ingredient.keys():
		var ingredient_id := str(raw_key)
		var count := int(by_ingredient[raw_key])
		labels.append("%s x%s" % [_ingredient_display(ingredient_id), count])
	return "nothing" if labels.is_empty() else ", ".join(labels)


func _ingredient_id_for_voucher(voucher_id: String) -> String:
	for raw_voucher in _snapshot.get("ownHand", []) + _snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return str(voucher.get("ingredientId", ""))
	return ""


func _participant_by_id(participant_id: String) -> Dictionary:
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("id", "")) == participant_id:
			return participant
	return {}


func _viewer_id() -> String:
	return str(_snapshot.get("viewerParticipantId", ""))


func _participant_name(participant_id: String) -> String:
	var participant := _participant_by_id(participant_id)
	return str(participant.get("name", "Someone")) if not participant.is_empty() else "Someone"


func _next_turn_participant_name() -> String:
	var next_id := _next_turn_participant_id()
	return "" if next_id == "" else _participant_name(next_id)


func _next_turn_participant_id() -> String:
	var current_id := str(_snapshot.get("currentTurnParticipantId", ""))
	var participants: Array = _snapshot.get("participants", [])
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


func _can_pass_turn_now() -> bool:
	var phase := str(_snapshot.get("phase", "lobby"))
	var active_phase := phase == "playing" or phase == "settlement" or phase == "eating"
	return active_phase and _can_act_now(phase)


func _pass_turn_text() -> String:
	if str(_snapshot.get("phase", "lobby")) == "playing":
		return "Redeem / Pass"
	var next_name := _next_turn_participant_name()
	return "Pass Turn" if next_name == "" else "Pass Turn to %s" % next_name


func _ingredient_display(ingredient_id: String) -> String:
	if ingredient_id == "vegetables":
		return "Veggies"
	for raw_ingredient in _snapshot.get("ingredients", []):
		var ingredient: Dictionary = raw_ingredient
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.capitalize() if ingredient_id != "" else "Unknown"


func _recipe_ingredient_display(ingredient_id: String) -> String:
	return _ingredient_display(ingredient_id)


func _titled_panel(title: String, centered := false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label := _label(title)
	title_label.name = "Title_%s" % title.replace(" ", "_")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", TEXT_DARK)
	box.add_child(title_label)
	return box


func _framed_box(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1), Color(0.58, 0.54, 0.48), 1, 8))
	panel.add_child(content)
	return panel


func _scroll_wrap(child: Control, min_height: int) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, min_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(child)
	return scroll


func _center_wrap(child: Control, min_height: int) -> CenterContainer:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, min_height)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(child)
	return center


func _visual_card(top_text: String, bottom_text: String, meta: Dictionary, minimum: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.clip_contents = true
	_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.30, 0.35, 0.42), 1)
	_add_visual_content(button, top_text, bottom_text, meta, minimum, _contrast_ink(meta.get("color", Color(0.8, 0.8, 0.8))), true)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _player_tile(top_text: String, bottom_text: String, meta: Dictionary, offer_indicator: String, is_turn: bool, minimum: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	_apply_plain_item_style(button)
	if is_turn:
		_add_turn_circle(button)
	_add_player_tile_content(button, top_text, bottom_text, meta, offer_indicator, is_turn)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _add_player_tile_content(button: Button, top_text: String, bottom_text: String, meta: Dictionary, offer_indicator: String, is_turn: bool) -> void:
	var turn_ink := Color(0.34, 0.18, 0.04)
	var turn_outline := Color(1.0, 0.78, 0.18, 0.92)
	var name := _card_label(top_text, turn_ink if is_turn else TEXT_DARK, 14)
	name.name = "CookNameLabel"
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.add_theme_color_override("font_outline_color", turn_outline if is_turn else Color(0.96, 0.90, 0.72, 0.88))
	name.add_theme_constant_override("outline_size", 2 if is_turn else 1)
	_place_overlay(name, 2, 0, -2, 24)
	button.add_child(name)

	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		_place_overlay(icon, 0, 17, 0, -13)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
	else:
		var mark := _card_label(str(meta.get("mark", "??")), TEXT_DARK, 13)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_overlay(mark, 2, 24, -2, -26)
		button.add_child(mark)

	var ingredient := _card_label(bottom_text, turn_ink if is_turn else TEXT_DARK, 14)
	ingredient.name = "CookIngredientLabel"
	ingredient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ingredient.autowrap_mode = TextServer.AUTOWRAP_OFF
	ingredient.add_theme_color_override("font_outline_color", turn_outline if is_turn else Color(0.96, 0.90, 0.72, 0.92))
	ingredient.add_theme_constant_override("outline_size", 2 if is_turn else 1)
	_place_overlay(ingredient, 0, -24, 0, 0)
	button.add_child(ingredient)

	if offer_indicator.find("!") >= 0:
		button.add_child(_offer_badge("!", Color(0.82, 0.12, 0.10), 58))
	if offer_indicator.find("?") >= 0:
		button.add_child(_offer_badge("?", Color(0.06, 0.55, 0.22), 38))


func _offer_badge(text: String, color: Color, right_offset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "OfferBadgeIncoming" if text == "!" else "OfferBadgeOutgoing"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1
	panel.anchor_top = 0
	panel.anchor_right = 1
	panel.anchor_bottom = 0
	panel.offset_left = -right_offset
	panel.offset_top = 16
	panel.offset_right = -(right_offset - 18)
	panel.offset_bottom = 34
	var style := _panel_style(color, Color(1, 0.96, 0.78), 1, 9)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_start_offer_badge_pulse(panel)
	return panel


func _plain_asset_item(text: String, meta: Dictionary, minimum: Vector2, callback: Callable, is_turn := false) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.clip_contents = true
	_apply_plain_item_style(button)
	if is_turn:
		_add_turn_circle(button)
	_add_visual_content(button, "", text, meta, minimum, TEXT_DARK, false)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _add_turn_circle(parent: Control) -> void:
	var circle := PanelContainer.new()
	circle.name = "TurnCircle"
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle.offset_left = 11
	circle.offset_top = 2
	circle.offset_right = -11
	circle.offset_bottom = -10
	var style := _panel_style(Color(1.0, 0.78, 0.18, 0.64), Color(0.95, 0.48, 0.03, 0.96), 3, 999)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	circle.add_theme_stylebox_override("panel", style)
	parent.add_child(circle)


func _add_visual_content(button: Button, top_text: String, bottom_text: String, meta: Dictionary, minimum: Vector2, ink: Color, framed: bool) -> void:
	var pad := 4 if framed else 2
	var top_band := 20 if top_text != "" else 0
	var bottom_band := 42 if bottom_text.find("\n") >= 0 else 31

	if top_text != "":
		var top := _visual_text_label(top_text, ink)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_overlay(top, pad, pad, -pad, pad + top_band)
		button.add_child(top)

	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		_place_overlay(icon, pad, pad + top_band, -pad, -(bottom_band + pad))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
	else:
		var mark := _visual_text_label(str(meta.get("mark", "??")), ink)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_overlay(mark, pad, pad + top_band, -pad, -(bottom_band + pad))
		button.add_child(mark)

	var bottom := _visual_text_label(bottom_text, ink)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_overlay(bottom, pad, -bottom_band, -pad, -pad)
	button.add_child(bottom)


func _place_overlay(control: Control, left: int, top: int, right: int, bottom: int) -> void:
	control.anchor_left = 0
	control.anchor_right = 1
	if top >= 0 and bottom >= 0:
		control.anchor_top = 0
		control.anchor_bottom = 0
	elif top < 0 and bottom <= 0:
		control.anchor_top = 1
		control.anchor_bottom = 1
	else:
		control.anchor_top = 0
		control.anchor_bottom = 1
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _visual_text_label(text: String, color: Color) -> Label:
	var label := _label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	return label


func _card_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_button_style(button: Button, bg: Color, border: Color, border_width: int) -> void:
	var ink := _contrast_ink(bg)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, border_width, 8))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.08), border.darkened(0.08), maxi(border_width, 2), 8))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.08), border.darkened(0.16), maxi(border_width, 2), 8))
	button.add_theme_stylebox_override("disabled", _panel_style(bg.darkened(0.05), Color(0.42, 0.42, 0.42), 1, 8))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", _contrast_ink(bg.darkened(0.08)))
	button.add_theme_color_override("font_disabled_color", _contrast_ink(bg.darkened(0.05)))


func _apply_plain_item_style(button: Button) -> void:
	var normal := _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	var hover := _panel_style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 0, 0)
	var pressed := _panel_style(Color(1, 1, 1, 0.18), Color(0, 0, 0, 0), 0, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_DARK)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)


func _apply_plain_item_highlight(button: Button, border: Color, border_width: int) -> void:
	var style := _panel_style(Color(1, 1, 1, 0.10), border, border_width, 8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


func _contrast_ink(bg: Color) -> Color:
	var luminance := (0.299 * bg.r) + (0.587 * bg.g) + (0.114 * bg.b)
	return TEXT_DARK if luminance > 0.55 else Color(1, 0.97, 0.90)


func _small_action_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 13)
	return button


func _action_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.42))
	button.add_theme_constant_override("outline_size", 1)
	_apply_action_button_style(button, text)
	if not debug_stats.has("actionButtonTexts"):
		debug_stats["actionButtonTexts"] = []
	var action_texts: Array = debug_stats.get("actionButtonTexts", [])
	action_texts.append(text)
	debug_stats["actionButtonTexts"] = action_texts
	return button


func _record_disabled_action_button(button: Button) -> void:
	if not button.disabled:
		return
	if not debug_stats.has("disabledActionButtonTexts"):
		debug_stats["disabledActionButtonTexts"] = []
	var disabled_texts: Array = debug_stats.get("disabledActionButtonTexts", [])
	disabled_texts.append(button.text)
	debug_stats["disabledActionButtonTexts"] = disabled_texts


func _apply_action_button_style(button: Button, text: String) -> void:
	var bg := _action_button_color(text)
	var border := _action_button_border_color(text)
	var ink := _contrast_ink(bg)
	var disabled_bg := Color(0.72, 0.68, 0.58)
	var disabled_border := Color(0.50, 0.45, 0.36)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, 2, 7))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.08), border.lightened(0.10), 2, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.10), border.darkened(0.12), 2, 7))
	button.add_theme_stylebox_override("disabled", _panel_style(disabled_bg, disabled_border, 1, 7))
	button.add_theme_stylebox_override("focus", _panel_style(bg.lightened(0.08), Color(1.0, 0.96, 0.78), 3, 7))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", _contrast_ink(bg.darkened(0.10)))
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_hover_pressed_color", _contrast_ink(bg.darkened(0.10)))
	button.add_theme_color_override("font_disabled_color", Color(0.32, 0.28, 0.21))


func _action_button_color(text: String) -> Color:
	var normalized := text.to_lower()
	if normalized.find("redeem") >= 0 or normalized.find("pass turn") >= 0:
		return Color(0.50, 0.27, 0.12)
	if normalized.find("prepare") >= 0:
		return Color(0.86, 0.45, 0.16)
	if normalized.find("offer") >= 0:
		return Color(0.96, 0.72, 0.24)
	if normalized.find("settlement") >= 0:
		return Color(0.30, 0.58, 0.50)
	if normalized.find("swap") >= 0:
		return Color(0.36, 0.62, 0.33)
	if normalized.find("bite") >= 0:
		return Color(0.73, 0.28, 0.20)
	if normalized.find("clear") >= 0:
		return Color(0.65, 0.59, 0.48)
	return Color(0.88, 0.75, 0.48)


func _action_button_border_color(text: String) -> Color:
	var bg := _action_button_color(text)
	return bg.darkened(0.28)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	button.pressed.connect(callback)
	return button


func _menu_button_control() -> Button:
	var button := Button.new()
	button.name = "TableMenuButton"
	button.text = ""
	button.tooltip_text = "Menu"
	button.custom_minimum_size = Vector2(40, 32)
	button.size = Vector2(40, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(button, Color(0.91, 0.80, 0.58), Color(0.46, 0.32, 0.18), 1)
	var icon := MenuBarsIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT_DARK)
	return label


func _muted_label(text: String) -> Label:
	var label := _label(text)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	return label


func _action_label(text: String) -> Label:
	var label := _muted_label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _offer_popup_title(text: String) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DARK)
	return label


func _offer_popup_header(text: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "OfferPopupHeader"
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 24)
	row.add_child(spacer)
	var title := _offer_popup_title(text)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_offer_popup_close_button())
	return row


func _offer_popup_close_button() -> Button:
	var button := Button.new()
	button.name = "OfferPopupClose"
	button.text = "X"
	button.custom_minimum_size = Vector2(24, 24)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func() -> void:
		if is_instance_valid(_offer_popup):
			_offer_popup.hide()
	)
	var normal := _panel_style(Color(0.88, 0.82, 0.68), PANEL_BORDER, 1, 5)
	var hover := _panel_style(Color(0.94, 0.89, 0.76), PANEL_BORDER.darkened(0.08), 1, 5)
	var pressed := _panel_style(Color(0.78, 0.70, 0.56), PANEL_BORDER.darkened(0.16), 1, 5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_DARK)
	button.add_theme_font_size_override("font_size", 12)
	return button


func _offer_popup_text(text: String) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_DARK)
	return label


func _offer_popup_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "OfferActionRow"
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _offer_popup_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.custom_minimum_size = Vector2(0, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var normal := _panel_style(Color(0.88, 0.82, 0.68), PANEL_BORDER, 1, 6)
	var hover := _panel_style(Color(0.94, 0.89, 0.76), PANEL_BORDER.darkened(0.08), 1, 6)
	var pressed := _panel_style(Color(0.78, 0.70, 0.56), PANEL_BORDER.darkened(0.16), 1, 6)
	var disabled := _panel_style(Color(0.78, 0.76, 0.70), Color(0.54, 0.51, 0.45), 1, 6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_DARK)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	return button


func _offer_popup_compact_button(text: String, callback: Callable) -> Button:
	var button := _offer_popup_button(text, callback)
	button.custom_minimum_size = Vector2(0, 24)
	button.add_theme_font_size_override("font_size", 12)
	return button


func _popup_centered_tight(width: int, max_height: int, allow_scroll := false) -> void:
	_offer_popup.hide()
	_offer_popup_scroller.custom_minimum_size = Vector2(0, 0)
	_offer_popup_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if allow_scroll else ScrollContainer.SCROLL_MODE_DISABLED
	_offer_popup.size = Vector2i(0, 0)
	var content_height := int(ceil(_offer_popup_list.get_combined_minimum_size().y))
	var panel_padding := 18
	var min_height := 64
	var height := 0
	if allow_scroll:
		height = clampi(content_height + panel_padding, min_height, max_height)
	else:
		height = maxi(min_height, content_height + panel_padding + 2)
	_offer_popup_scroller.custom_minimum_size = Vector2(width - panel_padding, height - panel_padding)
	debug_stats["offerPopupHeight"] = height
	debug_stats["offerPopupScrollEnabled"] = allow_scroll
	_offer_popup.popup_centered(Vector2i(width, height))


func _offer_popup_panel_style() -> StyleBoxFlat:
	var style := _panel_style(PANEL_BG, PANEL_BORDER, 1, 8)
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style


func _basket_backdrop_style() -> StyleBoxFlat:
	var style := _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 42)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style


func _real_ingredient_slot_style() -> StyleBoxFlat:
	var style := _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _prepare_dish_style() -> StyleBoxFlat:
	var style := _panel_style(Color(0.98, 0.91, 0.70, 0.96), Color(0.58, 0.36, 0.14), 2, 18)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.34, 0.20, 0.08, 0.32)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _pulse_style(color: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(color.r, color.g, color.b, 0.12), Color(color.r, color.g, color.b, 0.88), 3, 10)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _row_message(text: String) -> Label:
	var label := _muted_label(text)
	label.custom_minimum_size = Vector2(150, 42)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
