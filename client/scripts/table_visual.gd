extends PanelContainer

signal intent_requested(intent: Dictionary)
signal view_requested(participant_id: String)
signal status_requested(message: String)
signal menu_requested(action: String)

const VisualAssets := preload("res://scripts/visual_asset_registry.gd")
const TableclothPattern := preload("res://scripts/tablecloth_pattern.gd")

const TEXT_DARK := Color(0.16, 0.14, 0.11)
const TEXT_MUTED := Color(0.38, 0.35, 0.29)
const TABLE_BG := Color(0.91, 0.88, 0.80)
const PANEL_BG := Color(0.94, 0.92, 0.84)
const BOARD_PANEL_BG := Color(0.90, 0.86, 0.76)
const INVENTORY_UPPER_PANEL_BG := Color(0.76, 0.64, 0.46)
const INVENTORY_LOWER_PANEL_BG := Color(0.62, 0.49, 0.31)
const ACTION_PANEL_BG := Color(0.94, 0.89, 0.75)
const PANEL_BORDER := Color(0.42, 0.36, 0.27)
const DEFAULT_INGREDIENT_ORDER := ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
const OPENING_OFFERINGS_PER_PLAYER := 2
# Deposit order on a 4x2 grid:
# [8] [3] [4] [7]
# [5] [1] [2] [6]
const BASKET_CENTER_OUT_SLOTS := [5, 6, 1, 2, 4, 7, 3, 0]
const TABLE_CONTENT_WIDTH := 680
const TABLE_CONTENT_HEIGHT := 960
const TABLE_PORTRAIT_SIZE := Vector2(TABLE_CONTENT_WIDTH + 20.0, TABLE_CONTENT_HEIGHT)
const TABLE_LANDSCAPE_COLUMN_GAP := 14
const TABLE_LANDSCAPE_OUTER_MARGIN_X := 18
const TABLE_LANDSCAPE_CONTENT_WIDTH := TABLE_CONTENT_WIDTH * 2 + TABLE_LANDSCAPE_COLUMN_GAP
const TABLE_LANDSCAPE_MARGIN_WIDTH := TABLE_LANDSCAPE_CONTENT_WIDTH + TABLE_LANDSCAPE_OUTER_MARGIN_X * 2
const TABLE_LANDSCAPE_WIDTH := TABLE_LANDSCAPE_MARGIN_WIDTH + 16
const TABLE_LANDSCAPE_HEIGHT := 560
const TABLE_LANDSCAPE_SIZE := Vector2(TABLE_LANDSCAPE_WIDTH, TABLE_LANDSCAPE_HEIGHT)
const BOARD_PANEL_MARGIN_X := 6
const BOARD_PANEL_MARGIN_Y := 4
const INVENTORY_SECTION_MARGIN_X := 6
const INVENTORY_SECTION_MARGIN_Y := 3
const INVENTORY_HAND_PANEL_WIDTH := TABLE_CONTENT_WIDTH - INVENTORY_SECTION_MARGIN_X * 2.0
const INVENTORY_UPPER_PANEL_MIN_HEIGHT := 220
# Promise Cards title plus the fixed hand scroller height.
const INVENTORY_LOWER_PANEL_MIN_HEIGHT := 232
const INVENTORY_SURFACE_MIN_HEIGHT := INVENTORY_UPPER_PANEL_MIN_HEIGHT + INVENTORY_LOWER_PANEL_MIN_HEIGHT + 6
const ACTION_PANEL_MIN_WIDTH := 286
const ACTION_PANEL_FIXED_HEIGHT := INVENTORY_UPPER_PANEL_MIN_HEIGHT - INVENTORY_SECTION_MARGIN_Y * 2
const ACTION_LABEL_SHORT_HEIGHT := 44
const ACTION_LABEL_MEDIUM_HEIGHT := 78
const ACTION_LABEL_LONG_HEIGHT := 94
const COMPLETE_ACTION_FIREWORKS_SIZE := Vector2(210, 68)
const LANDSCAPE_MIN_AVAILABLE_WIDTH := 1060.0
const LANDSCAPE_MIN_ASPECT := 1.25
const BASKET_BACKDROP_SIZE := Vector2(668, 230)
const CARD_TILE_SIZE := Vector2(96, 90)
const BASKET_SLOT_SIZE := CARD_TILE_SIZE
const ANIMATED_CARD_TILE_SIZE := BASKET_SLOT_SIZE
const PREPARE_DISH_PANEL_SIZE := Vector2(122, 134)
const PREPARE_DISH_ICON_SIZE := Vector2(82, 82)
const PREPARE_DISH_POP_SCALE := Vector2(1.08, 1.08)
const PREPARE_DISH_LAND_SCALE := Vector2(0.30, 0.30)
const BASKET_COMPACT_SLOT_SIZE := Vector2(92, 52)
const BASKET_GRID_GAP := 7
const BASKET_COMPACT_GRID_GAP := 5
const BASKET_GRID_SIZE := Vector2(BASKET_SLOT_SIZE.x * 4.0 + BASKET_GRID_GAP * 3.0, BASKET_SLOT_SIZE.y * 2.0 + BASKET_GRID_GAP)
const RECIPE_SLOT_SIZE := Vector2(110, 76)
const RECIPE_GRID_GAP := 5
const RECIPE_GRID_SIZE := Vector2(RECIPE_SLOT_SIZE.x * 3.0 + RECIPE_GRID_GAP * 2.0, RECIPE_SLOT_SIZE.y * 2.0 + RECIPE_GRID_GAP)
const RECIPE_SLOT_CONTENT_MARGIN := 2
const RECIPE_SLOT_RADIUS := 6
const RECIPE_SLOT_ICON_SIZE := Vector2(62, 44)
const RECIPE_SLOT_REDEEMED_ICON_SIZE := Vector2(58, 40)
const RECIPE_SLOT_LABEL_FONT_SIZE := 17
const COOK_TILE_SIZE := Vector2(128, 96)
const BASKET_TABLE_AREA_SIZE := Vector2(TABLE_CONTENT_WIDTH, 454)
const BASKET_BACKDROP_POSITION := Vector2(6, 120)
const COOK_RING_POSITIONS := [
	Vector2(10, 48),
	Vector2(182, 20),
	Vector2(346, 20),
	Vector2(542, 48),
	Vector2(542, 326),
	Vector2(346, 356),
	Vector2(182, 356),
	Vector2(4, 326)
]
const HAND_CARD_SIZE := CARD_TILE_SIZE
const HAND_FOOD_SIZE := Vector2(96, 92)
const HAND_SCROLL_HEIGHT := 202
const CARD_TILE_FADE_IN_SECONDS := 0.03
const CARD_TILE_MOVE_SECONDS := 0.52
const CARD_TILE_PULSE_SECONDS := 0.08
const CARD_TILE_FADE_OUT_SECONDS := 0.08
const CARD_TILE_LANDING_SECONDS := CARD_TILE_FADE_IN_SECONDS + CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS
const CARD_TILE_VISIBLE_START_LANDING_SECONDS := CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS
const TEXTURE_FADE_IN_SECONDS := 0.03
const TEXTURE_MOVE_SECONDS := 0.48
const TEXTURE_PULSE_SECONDS := 0.08
const TEXTURE_FADE_OUT_SECONDS := 0.08
const TEXTURE_LANDING_SECONDS := TEXTURE_FADE_IN_SECONDS + TEXTURE_MOVE_SECONDS + TEXTURE_PULSE_SECONDS
const SWAP_RETURN_DELAY_SECONDS := CARD_TILE_LANDING_SECONDS + 0.10
const SWAP_MID_SNAPSHOT_SECONDS := CARD_TILE_LANDING_SECONDS
const SWAP_TAKE_START_SECONDS := SWAP_RETURN_DELAY_SECONDS + CARD_TILE_FADE_IN_SECONDS
const SWAP_FINISH_SECONDS := SWAP_TAKE_START_SECONDS + CARD_TILE_VISIBLE_START_LANDING_SECONDS
const REDEEM_INGREDIENT_DELAY_SECONDS := CARD_TILE_LANDING_SECONDS + 0.10
const REDEEM_FINISH_SECONDS := REDEEM_INGREDIENT_DELAY_SECONDS + TEXTURE_LANDING_SECONDS
const CARD_TILE_START_SCALE := Vector2.ONE
const CARD_TILE_LAND_SCALE := Vector2(1.015, 1.015)
const TEXTURE_LAND_SCALE := Vector2(1.025, 1.025)
const FAST_BOT_ANIMATION_SCALE := 0.25
const VIEWER_ANIMATION_SCALE := 1.35
const BASKET_SWAP_QUEUE_TIMEOUT_MS := 5000
const VISUAL_TURN_LAG_FLUSH_MS := 3000
const MAX_PENDING_VISUAL_SNAPSHOTS := 32
const MAX_ANIMATION_QUEUE_ESTIMATED_SECONDS := 12.0
const PREPARE_ANNOUNCEMENT_HOLD_SECONDS := 2.05
const COMPLETE_FOOD_ORBIT_MIN_ITEMS := 8
const COMPLETE_FOOD_ORBIT_MAX_ITEMS := 16
const COMPLETE_ORBIT_LAUNCH_MOVE_SECONDS := 0.42
const COMPLETE_ORBIT_LAUNCH_SETTLE_SECONDS := 0.05
const COMPLETE_ORBIT_LAUNCH_FADE_SECONDS := 0.07
const COMPLETE_ORBIT_LAUNCH_EVENT_SECONDS := 0.58
const ANIMATION_POINT_BOUNDS_PADDING := 96.0
const ANIMATION_POINT_ORIGIN_EPSILON := 1.0


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


class StarPip:
	extends Control

	var filled := false
	var glowing := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(16, 16)

	func set_state(should_fill: bool, should_glow := false) -> void:
		filled = should_fill
		glowing = should_glow
		queue_redraw()

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.42
		var center := size * 0.5
		if glowing and filled:
			draw_circle(center, radius * 1.45, Color(1.0, 0.62, 0.06, 0.26))
		var points := _star_points(center, radius, radius * 0.48)
		var shadow := PackedVector2Array()
		for point in points:
			shadow.append(point + Vector2(1.0, 1.0))
		if filled:
			draw_colored_polygon(shadow, Color(0.25, 0.16, 0.06, 0.24))
			draw_colored_polygon(points, Color(1.0, 0.70, 0.12))
		else:
			draw_colored_polygon(points, Color(1.0, 0.98, 0.88, 0.18))
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, Color(0.38, 0.21, 0.04) if filled else Color(0.66, 0.55, 0.35, 0.86), 1.8, true)

	func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for point_index in range(10):
			var radius := outer_radius if point_index % 2 == 0 else inner_radius
			var angle := -PI * 0.5 + float(point_index) * PI / 5.0
			points.append(Vector2(center.x + cos(angle) * radius, center.y + sin(angle) * radius))
		return points


class ProgressStars:
	extends HBoxContainer

	var filled_count := 0
	var total_count := 3
	var glowing := false
	var star_size := 16.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 1)
		custom_minimum_size = Vector2(52, 18)

	func set_star_size(value: float) -> void:
		star_size = maxf(10.0, value)
		_update_minimum_size()
		_rebuild()

	func set_progress(filled: int, total: int, should_glow := false) -> void:
		total_count = maxi(1, total)
		filled_count = clampi(filled, 0, total_count)
		glowing = should_glow
		_update_minimum_size()
		_rebuild()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_READY:
			_rebuild()

	func _update_minimum_size() -> void:
		var width := float(total_count) * star_size + float(maxi(0, total_count - 1))
		custom_minimum_size = Vector2(width, star_size)

	func _rebuild() -> void:
		if not is_inside_tree():
			return
		for child in get_children():
			remove_child(child)
			child.queue_free()
		for index in range(total_count):
			var pip := StarPip.new()
			pip.name = "StarPip_%s" % index
			pip.custom_minimum_size = Vector2(star_size, star_size)
			pip.set_state(index < filled_count, glowing and index < filled_count)
			add_child(pip)


class CheckmarkBadge:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(20, 20)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var p1 := Vector2(size.x * 0.22, size.y * 0.54)
		var p2 := Vector2(size.x * 0.43, size.y * 0.74)
		var p3 := Vector2(size.x * 0.78, size.y * 0.28)
		draw_line(p1, p2, Color(0.96, 0.94, 0.82), 5.0, true)
		draw_line(p2, p3, Color(0.96, 0.94, 0.82), 5.0, true)
		draw_line(p1, p2, Color(0.08, 0.55, 0.18), 2.8, true)
		draw_line(p2, p3, Color(0.08, 0.55, 0.18), 2.8, true)


class FixedBasketSlot:
	extends Control

	var fixed_size := Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		return fixed_size


class FixedScrollContainer:
	extends ScrollContainer

	var fixed_minimum_size := Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		return fixed_minimum_size


class FixedPanelContainer:
	extends PanelContainer

	var fixed_minimum_size := Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		return fixed_minimum_size


class FixedVBoxContainer:
	extends VBoxContainer

	var fixed_minimum_size := Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		return fixed_minimum_size


class FixedLabel:
	extends Label

	var fixed_minimum_size := Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		return fixed_minimum_size


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


class FireworksShow:
	extends Control

	const COLORS := [
		Color(0.95, 0.34, 0.24),
		Color(1.00, 0.72, 0.20),
		Color(0.28, 0.66, 0.35),
		Color(0.35, 0.52, 0.95),
		Color(0.72, 0.35, 0.85)
	]

	var elapsed := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _draw() -> void:
		if size.x <= 8.0 or size.y <= 8.0:
			return
		var centers := [
			Vector2(size.x * 0.28, size.y * 0.42),
			Vector2(size.x * 0.66, size.y * 0.34),
			Vector2(size.x * 0.48, size.y * 0.66)
		]
		for index in range(centers.size()):
			var phase := fmod(elapsed * 0.52 + float(index) * 0.29, 1.0)
			_draw_burst(centers[index], phase, COLORS[index % COLORS.size()], 10 + index * 2)

	func _draw_burst(center: Vector2, phase: float, color: Color, ray_count: int) -> void:
		var radius := lerpf(7.0, minf(size.x, size.y) * 0.33, phase)
		var alpha := clampf(1.0 - phase, 0.0, 1.0)
		var stroke := Color(color.r, color.g, color.b, alpha)
		var core := Color(1.0, 0.92, 0.60, alpha)
		draw_circle(center, 2.0 + 4.0 * (1.0 - phase), core)
		for ray_index in range(ray_count):
			var angle := TAU * float(ray_index) / float(ray_count) + phase * 0.45
			var direction := Vector2(cos(angle), sin(angle))
			var start := center + direction * radius * 0.35
			var finish := center + direction * radius
			draw_line(start, finish, stroke, 2.0, true)
			draw_circle(finish, 2.0, stroke)


class CompleteFoodOrbit:
	extends Control

	const ITEM_SIZE := Vector2(34, 34)
	const ORBIT_EDGE_GUTTER := 8.0
	const ORBIT_EDGE_INSET := ITEM_SIZE.x * 0.5 + ORBIT_EDGE_GUTTER
	const ORBIT_LEFT_INSET := ORBIT_EDGE_INSET
	const ORBIT_TOP_INSET := ORBIT_EDGE_INSET
	const ORBIT_RIGHT_INSET := ORBIT_EDGE_INSET
	const ORBIT_BOTTOM_INSET := ITEM_SIZE.y * 0.5 + ORBIT_EDGE_GUTTER
	const ORBIT_INSET := ORBIT_BOTTOM_INSET
	const SECONDS_PER_LAP := 18.0
	const BOB_PIXELS := 4.0

	var _items: Array = []
	var _elapsed := 0.0

	func configure(food_items: Array, visible_count := -1) -> void:
		name = "CompleteFoodOrbit"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false
		set_anchors_preset(Control.PRESET_FULL_RECT)
		for child in get_children():
			child.queue_free()
		_items.clear()
		var index := 0
		for raw_item in food_items:
			var item: Dictionary = raw_item
			var texture = item.get("texture", null)
			if not texture is Texture2D:
				continue
			var icon := TextureRect.new()
			icon.name = "OrbitFood_%s" % index
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = texture
			icon.size = ITEM_SIZE
			icon.custom_minimum_size = ITEM_SIZE
			icon.pivot_offset = ITEM_SIZE * 0.5
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.visible = visible_count < 0 or index < visible_count
			icon.modulate = Color(1.0, 1.0, 1.0, 0.94 if icon.visible else 0.0)
			add_child(icon)
			var phase := float(item.get("orbitPhase", -1.0))
			if phase < 0.0 or phase >= 1.0:
				phase = float(index) / maxf(1.0, float(food_items.size()))
			_items.append({
				"node": icon,
				"phase": phase
			})
			index += 1
		set_meta("orbit_item_count", _items.size())
		set_visible_item_count(visible_count)
		set_meta("orbit_margin", ORBIT_BOTTOM_INSET)
		set_meta("orbit_left_margin", ORBIT_LEFT_INSET)
		set_meta("orbit_top_margin", ORBIT_TOP_INSET)
		set_meta("orbit_right_margin", ORBIT_RIGHT_INSET)
		set_meta("orbit_bottom_margin", ORBIT_BOTTOM_INSET)
		set_process(_items.size() > 0)
		_position_items()

	func set_visible_item_count(visible_count := -1) -> void:
		var normalized := _items.size() if visible_count < 0 else clampi(visible_count, 0, _items.size())
		for index in range(_items.size()):
			var item: Dictionary = _items[index]
			var icon := item.get("node", null) as TextureRect
			if not is_instance_valid(icon):
				continue
			var should_show := index < normalized
			icon.visible = should_show
			icon.modulate = Color(1.0, 1.0, 1.0, 0.94 if should_show else 0.0)
		set_meta("visible_orbit_item_count", normalized)

	func _ready() -> void:
		_position_items()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_position_items()

	func _process(delta: float) -> void:
		_elapsed += delta
		_position_items()

	func _position_items() -> void:
		if size.x <= 1.0 or size.y <= 1.0:
			return
		var rect := _orbit_rect_for_size(size)
		var perimeter := maxf(1.0, (rect.size.x + rect.size.y) * 2.0)
		for raw_item in _items:
			var item: Dictionary = raw_item
			var icon := item.get("node", null) as TextureRect
			if not is_instance_valid(icon):
				continue
			var phase := fposmod(float(item.get("phase", 0.0)) + _elapsed / SECONDS_PER_LAP, 1.0)
			var point := _point_on_perimeter(rect, phase * perimeter)
			var bob := Vector2(0.0, sin(_elapsed * TAU * 1.2 + phase * TAU) * BOB_PIXELS)
			icon.position = point - ITEM_SIZE * 0.5 + bob
			icon.rotation_degrees = sin(_elapsed * TAU * 0.9 + phase * TAU) * 7.0

	func _orbit_rect_for_size(container_size: Vector2) -> Rect2:
		var max_inset := minf(container_size.x, container_size.y) * 0.22
		var left := minf(ORBIT_LEFT_INSET, max_inset)
		var top := minf(ORBIT_TOP_INSET, max_inset)
		var right := minf(ORBIT_RIGHT_INSET, max_inset)
		var bottom := minf(ORBIT_BOTTOM_INSET, max_inset)
		return Rect2(
			Vector2(left, top),
			Vector2(maxf(1.0, container_size.x - left - right), maxf(1.0, container_size.y - top - bottom))
		)

	func _point_on_perimeter(rect: Rect2, distance: float) -> Vector2:
		var width := maxf(1.0, rect.size.x)
		var height := maxf(1.0, rect.size.y)
		var remaining := fposmod(distance, (width + height) * 2.0)
		if remaining <= width:
			return rect.position + Vector2(remaining, 0.0)
		remaining -= width
		if remaining <= height:
			return rect.position + Vector2(width, remaining)
		remaining -= height
		if remaining <= width:
			return rect.position + Vector2(width - remaining, height)
		remaining -= width
		return rect.position + Vector2(0.0, height - remaining)

var debug_stats := {}

var _snapshot: Dictionary = {}
var _selected_hand_voucher_id := ""
var _selected_hand_ingredient_id := ""
var _selected_inventory_asset_key := ""
var _selected_platter_asset_key := ""
var _create_offer_quantity := 1
var _animation_queue: Array = []
var _animation_running := false
var _animation_deadline_msec := 0
var _current_animation_event: Dictionary = {}
var _animation_actor_participant_id := ""
var _last_animation_types: Array[String] = []
var _pending_visual_snapshot: Dictionary = {}
var _has_pending_visual_snapshot := false
var _pending_visual_snapshots: Array = []
var _pending_visual_compaction_count := 0
var _animation_queue_compaction_count := 0
var _visual_turn_lag_started_msec := 0
var _visual_turn_lag_key := ""
var _last_visual_turn_lag_flush := ""
var _queued_basket_swap_requests: Array = []
var _basket_swap_intent_in_flight := false
var _basket_swap_in_flight_snapshot_key := ""
var _basket_swap_in_flight_started_msec := 0

var _root: VBoxContainer
var _margin_container: MarginContainer
var _tablecloth_pattern: Control
var _board_panel: PanelContainer
var _inventory_surface: PanelContainer
var _inventory_surface_content: VBoxContainer
var _inventory_upper_panel: PanelContainer
var _inventory_lower_panel: PanelContainer
var _basket_table_area: Control
var _middle_row: HBoxContainer
var _bottom_tray: VBoxContainer
var _hand_panel: Control
var _landscape_row: HBoxContainer
var _landscape_left: VBoxContainer
var _landscape_right: VBoxContainer
var _layout_mode := "portrait"
var _participant_row: Control
var _inventory_title_label: Label
var _basket_grid: GridContainer
var _redeem_box: VBoxContainer
var _recipe_title_row: HBoxContainer
var _recipe_title_prefix_label: Label
var _recipe_title_stars: ProgressStars
var _recipe_name_label: Label
var _recipe_grid: GridContainer
var _hand_row: GridContainer
var _hand_scroll: ScrollContainer
var _inventory_row: HBoxContainer
var _animation_layer: Control
var _offer_popup: PopupPanel
var _offer_popup_scroller: ScrollContainer
var _offer_popup_list: VBoxContainer
var _overlay_layer: Control
var _menu_canvas: CanvasLayer
var _menu_button: Button
var _main_menu_overlay_button: Button
var _menu_popup: PopupPanel
var _menu_popup_list: VBoxContainer
var _basket_slot_by_ingredient := {}
var _basket_slot_table_key := ""
var _fast_bots_enabled := true
var _active_popup_kind := ""
var _food_piece_info_key := ""
var _food_piece_info_location := ""
var _food_piece_info_last_text := ""
var _recipe_title_pulse_tween: Tween
var _animation_static_assets_warmed := false
var _complete_avatar_tweens: Array = []
var _complete_food_orbit: Control
var _complete_food_orbit_key := ""
var _complete_orbit_transition_active := false
var _shared_food_orbit_items: Array = []


func _ready() -> void:
	texture_filter = VisualAssets.preferred_texture_filter()
	_build()
	set_process_input(true)
	set_process(true)


func _exit_tree() -> void:
	_clear_complete_celebration_effects()
	VisualAssets.clear_cache()


func _get_minimum_size() -> Vector2:
	return _layout_minimum_size()


func render(snapshot: Dictionary) -> void:
	var previous_snapshot := _snapshot.duplicate(true)
	if _visual_update_waiting():
		if _snapshot_identity_key(snapshot) != _snapshot_identity_key(_snapshot):
			_queue_pending_visual_snapshot(snapshot)
		if not _animation_running and _animation_queue.is_empty():
			_apply_pending_visual_snapshot_after_layout()
		return
	if _snapshot_viewer_changed(previous_snapshot, snapshot):
		_clear_selections()
		_record_animation_debug([])
		_apply_snapshot(snapshot)
		return
	if _is_start_setup_transition(previous_snapshot, snapshot):
		_apply_start_setup_transition(snapshot)
		return
	if _should_hold_snapshot_for_animation(previous_snapshot, snapshot):
		var events := _animation_events(previous_snapshot, snapshot)
		if not events.is_empty():
			if _events_are_turn_only(events):
				_record_animation_debug([])
				_apply_snapshot(snapshot)
				return
			events = _events_with_visual_milestones(previous_snapshot, snapshot, events)
			_queue_pending_visual_snapshot(snapshot)
			_record_animation_debug(events)
			_animation_queue.append_array(events)
			_compact_animation_queue_if_needed()
			_request_animation_start()
			return

	_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var previous_snapshot := _snapshot.duplicate(true)
	_snapshot = snapshot.duplicate(true)
	snapshot = _snapshot
	_sync_basket_swap_queue_for_snapshot(previous_snapshot, snapshot)
	if not is_instance_valid(_root):
		return

	var has_table := str(snapshot.get("tableCode", "")) != ""
	if not has_table:
		_clear_complete_celebration_effects()
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
		"completeFireworks": false,
		"completeAvatarDanceCount": 0,
		"completeFoodOrbitCount": 0,
		"completeFoodOrbitVisibleCount": 0,
		"completeBiteSummaryCount": 0,
		"completeTurnCount": 0,
		"fastBotsEnabled": _fast_bots_enabled,
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
	debug_stats["basketSwapQueueSize"] = _queued_basket_swap_requests.size()
	debug_stats["basketSwapInFlight"] = _basket_swap_intent_in_flight
	var phase := str(snapshot.get("phase", ""))
	if phase != "complete":
		_clear_complete_avatar_dance()
	if phase != "complete" and phase != "eating" and not _should_preserve_complete_orbit_transition():
		_clear_complete_food_orbit()

	_render_menu()
	_render_turn_action()
	_render_participants()
	_render_basket()
	_render_redeem_box()
	_render_recipe()
	_render_hand()
	_render_inventory()
	_refresh_food_piece_info_popup()
	_record_layout_debug()
	_sync_complete_celebration_effects()
	_warm_static_animation_assets()


func _warm_static_animation_assets() -> void:
	if _animation_static_assets_warmed:
		return
	_animation_static_assets_warmed = true
	for ingredient_id in DEFAULT_INGREDIENT_ORDER:
		VisualAssets.ingredient_meta(str(ingredient_id))
	for avatar_index in range(8):
		VisualAssets.avatar_texture(avatar_index)
	for unit_name in ["piece", "pieces", "slice", "slices", "cup", "cups", "scoop", "scoops", "portion", "portions", "serving", "servings"]:
		VisualAssets.unit_meta(str(unit_name))


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


func debug_press_offer_hand_voucher(ingredient_id: String, owner_participant_id: String) -> void:
	var button := find_child("OfferHandVoucher_%s_%s" % [ingredient_id, owner_participant_id], true, false) as Button
	if button != null and not button.disabled:
		button.pressed.emit()


func highlight_incoming_offers_for_viewer() -> void:
	var viewer_id := _viewer_id()
	var first_sender_id := ""
	for raw_offer in _snapshot.get("offers", []):
		var offer: Dictionary = raw_offer
		if str(offer.get("status", "")) != "pending" or str(offer.get("toParticipantId", "")) != viewer_id:
			continue
		var sender_id := str(offer.get("fromParticipantId", ""))
		if sender_id == "":
			continue
		if first_sender_id == "":
			first_sender_id = sender_id
		var participant_node := find_child("Participant_%s" % sender_id, true, false) as Control
		if is_instance_valid(participant_node):
			_pulse_control(participant_node, Color(1.0, 0.74, 0.18))
			_animate_offer_badge_arrival(participant_node, "!", Color(0.82, 0.12, 0.10))
	if first_sender_id != "":
		_open_offer_popup(first_sender_id)


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


func debug_press_platter_food_part(dish_name: String) -> void:
	for raw_group in _food_part_group_options(_snapshot.get("platterFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) == dish_name:
			_on_platter_food_group_pressed(group)
			return


func debug_open_own_food_part_info(dish_name: String) -> void:
	for raw_group in _food_part_group_options(_snapshot.get("ownFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) == dish_name:
			_open_food_piece_info_popup(group, "hand")
			return


func debug_open_platter_food_part_info(dish_name: String) -> void:
	for raw_group in _food_part_group_options(_snapshot.get("platterFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishName", "")) == dish_name:
			_open_food_piece_info_popup(group, "basket")
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


func debug_fast_bots_enabled() -> bool:
	return _fast_bots_enabled


func debug_toggle_bot_animation_speed() -> void:
	_toggle_bot_animation_speed()


func debug_animation_speed_scale_for_type(type: String) -> float:
	return _animation_speed_scale({"type": type})


func debug_animation_speed_scale_for_event(event: Dictionary) -> float:
	return _animation_speed_scale(event)


func debug_force_visual_turn_lag_flush() -> void:
	var pending_snapshot := _latest_pending_visual_snapshot()
	if pending_snapshot.is_empty():
		return
	var visual_turn := current_visual_turn_id()
	var pending_turn := str(pending_snapshot.get("currentTurnParticipantId", ""))
	if visual_turn == "" or pending_turn == "" or visual_turn == pending_turn:
		return
	_last_visual_turn_lag_flush = "%s:%s:%s" % [
		str(_snapshot.get("tableCode", "")),
		str(pending_snapshot.get("phase", "")),
		pending_turn
	]
	_flush_visual_updates()


func debug_press_offer_selected_to_common_basket() -> void:
	_offer_selected_to_common_basket()


func debug_play_animation_event(event: Dictionary) -> void:
	_play_animation_event(event)


func flush_visual_updates() -> void:
	_flush_visual_updates()


func debug_flush_animations() -> void:
	_flush_visual_updates()


func _flush_visual_updates() -> void:
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
	_reset_visual_turn_lag_watch()
	if not final_pending_snapshot.is_empty():
		_apply_snapshot(final_pending_snapshot)
		_clear_basket_swap_in_flight()
	_process_queued_basket_swaps()


func debug_apply_snapshot(snapshot: Dictionary) -> void:
	_animation_queue.clear()
	_animation_running = false
	_animation_deadline_msec = 0
	_current_animation_event = {}
	_animation_actor_participant_id = ""
	_pending_visual_snapshot = {}
	_has_pending_visual_snapshot = false
	_pending_visual_snapshots.clear()
	_reset_visual_turn_lag_watch()
	_clear_basket_swap_queue()
	_apply_snapshot(snapshot)


func debug_basket_swap_queue_size() -> int:
	return _queued_basket_swap_requests.size()


func debug_basket_swap_queue_state() -> Dictionary:
	return {
		"queueSize": _queued_basket_swap_requests.size(),
		"inFlight": _basket_swap_intent_in_flight,
		"inFlightKey": _basket_swap_in_flight_snapshot_key,
		"snapshotKey": _snapshot_identity_key(_snapshot),
		"phase": str(_snapshot.get("phase", "")),
		"currentTurnParticipantId": str(_snapshot.get("currentTurnParticipantId", "")),
		"viewerParticipantId": _viewer_id(),
		"visualWaiting": _visual_update_waiting(),
		"selectedInventoryAssetKey": _selected_inventory_asset_key,
		"selectedPlatterAssetKey": _selected_platter_asset_key
	}


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
	var scale := _animation_speed_scale({"type": "swap"})
	var redeem_scale := _animation_speed_scale({"type": "redeem"})
	return {
		"cardLanding": _card_tile_landing_seconds(scale),
		"cardFadeOutEnd": _card_tile_landing_seconds(scale) + _scaled(CARD_TILE_FADE_OUT_SECONDS, scale),
		"swapMid": _swap_mid_snapshot_seconds(scale),
		"swapTakeStart": _swap_take_start_seconds(scale),
		"swapReturnVisible": _swap_take_start_seconds(scale),
		"swapFinish": _swap_finish_seconds(scale),
		"swapReturnFadeOutEnd": _swap_finish_seconds(scale) + _scaled(CARD_TILE_FADE_OUT_SECONDS, scale),
		"redeemFinish": _redeem_finish_seconds(redeem_scale),
		"redeemIngredientFadeOutEnd": _redeem_finish_seconds(redeem_scale) + _scaled(TEXTURE_FADE_OUT_SECONDS, redeem_scale)
	}


func debug_animation_actor_for_event(event: Dictionary) -> String:
	return _animation_actor_id(event)


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
	return TABLE_PORTRAIT_SIZE


func preferred_visual_size_for_area(area: Vector2) -> Vector2:
	if _should_use_landscape_layout(area):
		return TABLE_LANDSCAPE_SIZE
	return TABLE_PORTRAIT_SIZE


func _layout_minimum_size() -> Vector2:
	return TABLE_LANDSCAPE_SIZE if _layout_mode == "landscape" else TABLE_PORTRAIT_SIZE


func set_visual_layout_area(area: Vector2) -> void:
	var next_mode := "landscape" if _should_use_landscape_layout(area) else "portrait"
	_apply_visual_layout_mode(next_mode)


func _set_fixed_panel_minimum(panel: PanelContainer, minimum_size: Vector2) -> void:
	if panel is FixedPanelContainer:
		(panel as FixedPanelContainer).fixed_minimum_size = minimum_size
	panel.custom_minimum_size = minimum_size


func debug_layout_mode() -> String:
	return _layout_mode


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
		var start := _event_point_or_fallback(event.get("startPoint", Vector2.INF), _participant_or_hand_center(str(event.get("participantId", "")), ingredient_id))
		var end_fallback := _platter_voucher_center(ingredient_id)
		if end_fallback == Vector2.INF:
			end_fallback = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
		if end_fallback == Vector2.INF:
			end_fallback = _control_global_center(_basket_grid)
		var end := _event_point_or_fallback(event.get("endPoint", Vector2.INF), end_fallback)
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
		"deposit":
			var deposit_ingredient_id := str(event.get("ingredientId", ""))
			var deposit_end := _platter_voucher_center(deposit_ingredient_id)
			if deposit_end == Vector2.INF:
				deposit_end = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
			if deposit_end == Vector2.INF:
				deposit_end = _control_global_center(_basket_grid)
			return {
				"start": _event_point_or_fallback(event.get("startPoint", Vector2.INF), _participant_or_hand_center(str(event.get("participantId", "")), deposit_ingredient_id)),
				"end": _event_point_or_fallback(event.get("endPoint", Vector2.INF), deposit_end)
			}
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
		"eat":
			var eat_total := maxi(1, int(event.get("completeOrbitTotal", 1)))
			return {
				"start": _eat_start_center(event),
				"end": _complete_orbit_global_point_for_event(event, eat_total)
			}
		"exchange":
			return _exchange_debug_path_points(event)
		"prepare":
			return {
				"start": _control_global_center(_recipe_grid),
				"end": _prepare_dish_end_center(event)
			}
		"public_prepare":
			var public_center := _participant_tile_center(str(event.get("participantId", "")))
			if public_center == Vector2.INF:
				public_center = _control_global_center(_participant_row)
			return {
				"start": public_center,
				"end": public_center + Vector2(0, -8) if public_center != Vector2.INF else Vector2.INF
			}
		_:
			return {}


func _build() -> void:
	add_theme_stylebox_override("panel", _panel_style(TABLE_BG, PANEL_BORDER, 2, 8))
	clip_contents = false
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = TABLE_PORTRAIT_SIZE

	_tablecloth_pattern = TableclothPattern.new()
	_tablecloth_pattern.configure_table_panel()
	_tablecloth_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tablecloth_pattern.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tablecloth_pattern.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tablecloth_pattern)

	_margin_container = MarginContainer.new()
	_margin_container.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, 0)
	_margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_margin_container.add_theme_constant_override("margin_left", 6)
	_margin_container.add_theme_constant_override("margin_top", 4)
	_margin_container.add_theme_constant_override("margin_right", 6)
	_margin_container.add_theme_constant_override("margin_bottom", 4)
	add_child(_margin_container)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 6)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin_container.add_child(_root)

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
	_main_menu_overlay_button = _top_menu_button("Main Menu", func() -> void:
		menu_requested.emit("Main Menu")
	)
	_menu_canvas.add_child(_main_menu_overlay_button)
	_position_menu_button()

	var board_panel := FixedPanelContainer.new()
	board_panel.fixed_minimum_size = BASKET_TABLE_AREA_SIZE
	_board_panel = board_panel
	_board_panel.name = "BoardPanel"
	_board_panel.custom_minimum_size = BASKET_TABLE_AREA_SIZE
	_board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_board_panel.clip_contents = true
	_board_panel.add_theme_stylebox_override("panel", _board_surface_style())
	_root.add_child(_board_panel)

	_basket_table_area = Control.new()
	_basket_table_area.name = "BasketTableArea"
	_basket_table_area.custom_minimum_size = BASKET_TABLE_AREA_SIZE
	_basket_table_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_basket_table_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_basket_table_area.clip_contents = false
	_board_panel.add_child(_basket_table_area)

	var basket_backdrop := BasketBackdrop.new()
	basket_backdrop.name = "BasketBackdrop"
	basket_backdrop.custom_minimum_size = BASKET_BACKDROP_SIZE
	basket_backdrop.position = BASKET_BACKDROP_POSITION
	basket_backdrop.size = BASKET_BACKDROP_SIZE
	basket_backdrop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	basket_backdrop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	basket_backdrop.clip_contents = true
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
	_basket_grid.name = "BasketGrid"
	_basket_grid.columns = 4
	_basket_grid.custom_minimum_size = BASKET_GRID_SIZE
	_basket_grid.clip_contents = true
	_basket_grid.add_theme_constant_override("h_separation", BASKET_GRID_GAP)
	_basket_grid.add_theme_constant_override("v_separation", BASKET_GRID_GAP)
	_basket_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_basket_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	basket_center.add_child(_basket_grid)
	basket_margin.add_child(basket_center)
	basket_backdrop.add_child(basket_margin)
	_basket_table_area.add_child(basket_backdrop)

	_participant_row = Control.new()
	_participant_row.name = "CookRing"
	_participant_row.custom_minimum_size = BASKET_TABLE_AREA_SIZE
	_participant_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_participant_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_basket_table_area.add_child(_participant_row)

	var inventory_surface := FixedPanelContainer.new()
	inventory_surface.fixed_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_SURFACE_MIN_HEIGHT)
	_inventory_surface = inventory_surface
	_inventory_surface.name = "InventorySurface"
	_inventory_surface.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_SURFACE_MIN_HEIGHT)
	_inventory_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_surface.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inventory_surface.add_theme_stylebox_override("panel", _inventory_surface_style())
	_root.add_child(_inventory_surface)
	_inventory_surface_content = VBoxContainer.new()
	_inventory_surface_content.name = "InventorySurfaceContent"
	_inventory_surface_content.add_theme_constant_override("separation", 4)
	_inventory_surface_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_surface.add_child(_inventory_surface_content)

	var inventory_upper_panel := FixedPanelContainer.new()
	inventory_upper_panel.fixed_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_UPPER_PANEL_MIN_HEIGHT)
	_inventory_upper_panel = inventory_upper_panel
	_inventory_upper_panel.name = "InventoryUpperPanel"
	_inventory_upper_panel.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_UPPER_PANEL_MIN_HEIGHT)
	_inventory_upper_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_upper_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inventory_upper_panel.clip_contents = true
	_inventory_upper_panel.add_theme_stylebox_override("panel", _inventory_upper_panel_style())
	_inventory_surface_content.add_child(_inventory_upper_panel)

	_middle_row = HBoxContainer.new()
	_middle_row.name = "MiddleRow"
	_middle_row.add_theme_constant_override("separation", 10)
	_middle_row.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, ACTION_PANEL_FIXED_HEIGHT)
	_middle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_middle_row.clip_contents = true
	_inventory_upper_panel.add_child(_middle_row)

	_redeem_box = VBoxContainer.new()
	_redeem_box.custom_minimum_size = Vector2(0, ACTION_PANEL_FIXED_HEIGHT - 12)
	_redeem_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redeem_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_redeem_box.clip_contents = true
	_redeem_box.add_theme_constant_override("separation", 5)
	var action_panel := _framed_box(_redeem_box)
	action_panel.name = "ActionPanel"
	action_panel.custom_minimum_size = Vector2(ACTION_PANEL_MIN_WIDTH, ACTION_PANEL_FIXED_HEIGHT)
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_panel.clip_contents = true
	_middle_row.add_child(action_panel)

	var recipe_panel := FixedVBoxContainer.new()
	recipe_panel.name = "RecipePanel"
	recipe_panel.add_theme_constant_override("separation", 4)
	recipe_panel.fixed_minimum_size = Vector2(RECIPE_GRID_SIZE.x, ACTION_PANEL_FIXED_HEIGHT)
	recipe_panel.custom_minimum_size = recipe_panel.fixed_minimum_size
	recipe_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_panel.clip_contents = true
	_middle_row.add_child(recipe_panel)
	var recipe_title_center := CenterContainer.new()
	recipe_title_center.custom_minimum_size = Vector2(RECIPE_GRID_SIZE.x, 22)
	recipe_title_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_title_row = HBoxContainer.new()
	_recipe_title_row.name = "RecipeTitleRow"
	_recipe_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_recipe_title_row.add_theme_constant_override("separation", 4)
	_recipe_title_prefix_label = _label("")
	_recipe_title_prefix_label.name = "RecipeTitlePrefixLabel"
	_recipe_title_prefix_label.add_theme_font_size_override("font_size", 16)
	_recipe_title_prefix_label.add_theme_color_override("font_color", TEXT_DARK)
	_recipe_title_prefix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_recipe_title_prefix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recipe_title_prefix_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_recipe_title_prefix_label.clip_text = true
	_recipe_title_prefix_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_recipe_title_prefix_label.custom_minimum_size = Vector2(112, 20)
	_recipe_title_prefix_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_recipe_title_stars = ProgressStars.new()
	_recipe_title_stars.name = "RecipeTitleStars"
	_recipe_title_stars.set_star_size(13.0)
	_recipe_name_label = _label("")
	_recipe_name_label.name = "RecipeTitleLabel"
	_recipe_name_label.add_theme_font_size_override("font_size", 16)
	_recipe_name_label.add_theme_color_override("font_color", TEXT_DARK)
	_recipe_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_recipe_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recipe_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_recipe_name_label.clip_text = true
	_recipe_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_recipe_name_label.custom_minimum_size = Vector2(178, 20)
	_recipe_name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_recipe_title_row.add_child(_recipe_title_prefix_label)
	_recipe_title_row.add_child(_recipe_title_stars)
	_recipe_title_row.add_child(_recipe_name_label)
	recipe_title_center.add_child(_recipe_title_row)
	recipe_panel.add_child(recipe_title_center)
	_recipe_grid = GridContainer.new()
	_recipe_grid.columns = 3
	_recipe_grid.custom_minimum_size = RECIPE_GRID_SIZE
	_recipe_grid.add_theme_constant_override("h_separation", RECIPE_GRID_GAP)
	_recipe_grid.add_theme_constant_override("v_separation", RECIPE_GRID_GAP)
	_recipe_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recipe_panel.add_child(_recipe_grid)

	var inventory_lower_panel := FixedPanelContainer.new()
	inventory_lower_panel.fixed_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_LOWER_PANEL_MIN_HEIGHT)
	_inventory_lower_panel = inventory_lower_panel
	_inventory_lower_panel.name = "InventoryLowerPanel"
	_inventory_lower_panel.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, INVENTORY_LOWER_PANEL_MIN_HEIGHT)
	_inventory_lower_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_lower_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inventory_lower_panel.clip_contents = true
	_inventory_lower_panel.add_theme_stylebox_override("panel", _inventory_lower_panel_style())
	_inventory_surface_content.add_child(_inventory_lower_panel)

	_bottom_tray = VBoxContainer.new()
	_bottom_tray.name = "BottomTray"
	_bottom_tray.add_theme_constant_override("separation", 4)
	_bottom_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_lower_panel.add_child(_bottom_tray)

	var inventory_panel := _titled_panel("Inventory")
	inventory_panel.name = "InventoryPanel"
	inventory_panel.visible = false
	_inventory_title_label = inventory_panel.get_child(0) as Label
	inventory_panel.custom_minimum_size = Vector2(150, 0)
	inventory_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_overlay_layer.add_child(inventory_panel)
	_inventory_row = HBoxContainer.new()
	_inventory_row.name = "InventoryRow"
	_inventory_row.add_theme_constant_override("separation", 6)
	inventory_panel.add_child(_scroll_wrap(_inventory_row, 104))

	_hand_panel = _titled_panel("Promise Cards", true)
	_hand_panel.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, 0)
	_hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_tray.add_child(_hand_panel)
	_hand_row = GridContainer.new()
	_hand_row.name = "HandRow"
	_hand_row.columns = 6
	_hand_row.add_theme_constant_override("h_separation", 7)
	_hand_row.add_theme_constant_override("v_separation", 6)
	_hand_scroll = _scroll_wrap(_hand_row, HAND_SCROLL_HEIGHT)
	_hand_scroll.name = "HandScroll"
	if _hand_scroll is FixedScrollContainer:
		(_hand_scroll as FixedScrollContainer).fixed_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, HAND_SCROLL_HEIGHT)
	_hand_scroll.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, HAND_SCROLL_HEIGHT)
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_panel.add_child(_hand_scroll)

	_offer_popup = PopupPanel.new()
	_offer_popup.name = "OfferPopup"
	_configure_persistent_popup(_offer_popup)
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


func _should_use_landscape_layout(area: Vector2) -> bool:
	if area.x < LANDSCAPE_MIN_AVAILABLE_WIDTH:
		return false
	if area.y <= 1.0:
		return true
	return area.x / area.y >= LANDSCAPE_MIN_ASPECT


func _apply_visual_layout_mode(mode: String) -> void:
	if not is_instance_valid(_root) \
			or not is_instance_valid(_board_panel) \
			or not is_instance_valid(_inventory_surface) \
			or not is_instance_valid(_inventory_surface_content) \
			or not is_instance_valid(_inventory_upper_panel) \
			or not is_instance_valid(_inventory_lower_panel):
		_layout_mode = mode
		return
	var normalized := "landscape" if mode == "landscape" else "portrait"
	if normalized == "landscape":
		_ensure_landscape_containers()
		custom_minimum_size = TABLE_LANDSCAPE_SIZE
		if is_instance_valid(_margin_container):
			_margin_container.custom_minimum_size = Vector2(TABLE_LANDSCAPE_MARGIN_WIDTH, 0)
			_margin_container.add_theme_constant_override("margin_left", TABLE_LANDSCAPE_OUTER_MARGIN_X)
			_margin_container.add_theme_constant_override("margin_right", TABLE_LANDSCAPE_OUTER_MARGIN_X)
		_root.add_theme_constant_override("separation", 0)
		_inventory_surface_content.add_theme_constant_override("separation", 6)
		_move_control_to_parent(_landscape_row, _root)
		_move_control_to_parent(_board_panel, _landscape_left)
		_move_control_to_parent(_inventory_surface, _landscape_right)
		_basket_table_area.custom_minimum_size = BASKET_TABLE_AREA_SIZE
		_set_fixed_panel_minimum(_board_panel, BASKET_TABLE_AREA_SIZE)
		_set_fixed_panel_minimum(_inventory_surface, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_SURFACE_MIN_HEIGHT))
		_set_fixed_panel_minimum(_inventory_upper_panel, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_UPPER_PANEL_MIN_HEIGHT))
		_set_fixed_panel_minimum(_inventory_lower_panel, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_LOWER_PANEL_MIN_HEIGHT))
		_middle_row.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, ACTION_PANEL_FIXED_HEIGHT)
		_bottom_tray.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, 0)
		if is_instance_valid(_hand_panel):
			_hand_panel.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, 0)
	else:
		custom_minimum_size = TABLE_PORTRAIT_SIZE
		if is_instance_valid(_margin_container):
			_margin_container.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, 0)
			_margin_container.add_theme_constant_override("margin_left", 6)
			_margin_container.add_theme_constant_override("margin_right", 6)
		_root.add_theme_constant_override("separation", 6)
		_inventory_surface_content.add_theme_constant_override("separation", 4)
		_move_control_to_parent(_board_panel, _root)
		_move_control_to_parent(_inventory_surface, _root)
		if is_instance_valid(_landscape_row) and _landscape_row.get_parent() == _root:
			_root.remove_child(_landscape_row)
		_basket_table_area.custom_minimum_size = BASKET_TABLE_AREA_SIZE
		_set_fixed_panel_minimum(_board_panel, BASKET_TABLE_AREA_SIZE)
		_set_fixed_panel_minimum(_inventory_surface, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_SURFACE_MIN_HEIGHT))
		_set_fixed_panel_minimum(_inventory_upper_panel, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_UPPER_PANEL_MIN_HEIGHT))
		_set_fixed_panel_minimum(_inventory_lower_panel, Vector2(TABLE_CONTENT_WIDTH, INVENTORY_LOWER_PANEL_MIN_HEIGHT))
		_middle_row.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, ACTION_PANEL_FIXED_HEIGHT)
		_bottom_tray.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, 0)
		if is_instance_valid(_hand_panel):
			_hand_panel.custom_minimum_size = Vector2(INVENTORY_HAND_PANEL_WIDTH, 0)
	_layout_mode = normalized
	debug_stats["layoutMode"] = _layout_mode


func _ensure_landscape_containers() -> void:
	if is_instance_valid(_landscape_row):
		return
	_landscape_row = HBoxContainer.new()
	_landscape_row.name = "LandscapeRow"
	_landscape_row.add_theme_constant_override("separation", TABLE_LANDSCAPE_COLUMN_GAP)
	_landscape_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_landscape_row.custom_minimum_size = Vector2(TABLE_LANDSCAPE_CONTENT_WIDTH, 0)
	_landscape_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_landscape_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_landscape_left = VBoxContainer.new()
	_landscape_left.name = "LandscapeBasketColumn"
	_landscape_left.custom_minimum_size = BASKET_TABLE_AREA_SIZE
	_landscape_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_landscape_left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_landscape_right = VBoxContainer.new()
	_landscape_right.name = "LandscapePlayColumn"
	_landscape_right.add_theme_constant_override("separation", 6)
	_landscape_right.custom_minimum_size = Vector2(TABLE_CONTENT_WIDTH, 0)
	_landscape_right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_landscape_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_landscape_row.add_child(_landscape_left)
	_landscape_row.add_child(_landscape_right)


func _move_control_to_parent(control: Control, new_parent: Node) -> void:
	if not is_instance_valid(control) or not is_instance_valid(new_parent):
		return
	if control.get_parent() == new_parent:
		return
	var old_parent := control.get_parent()
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)


func _render_menu() -> void:
	if not is_instance_valid(_menu_button):
		return
	_sync_menu_visibility()
	debug_stats["menuActions"] = _table_menu_actions()


func _process(_delta: float) -> void:
	_finish_stalled_animation_if_needed()
	_flush_stale_visual_turn_if_needed()
	_sync_menu_visibility(false)
	_process_queued_basket_swaps()


func _menu_should_be_visible() -> bool:
	var has_table := str(_snapshot.get("tableCode", "")) != ""
	var phase := str(_snapshot.get("phase", ""))
	return has_table and phase != "lobby" and is_visible_in_tree()


func _sync_menu_visibility(update_debug := true) -> void:
	if not is_instance_valid(_menu_button):
		return
	_position_menu_button()
	var should_show := _menu_should_be_visible()
	var phase := str(_snapshot.get("phase", ""))
	_menu_button.visible = should_show
	if is_instance_valid(_main_menu_overlay_button):
		_main_menu_overlay_button.visible = should_show and phase == "complete"
	if is_instance_valid(_menu_canvas):
		_menu_canvas.visible = should_show
	if not should_show and is_instance_valid(_menu_popup):
		_menu_popup.hide()
	if update_debug:
		debug_stats["menuButtonVisible"] = should_show


func _position_menu_button() -> void:
	if not is_instance_valid(_menu_button):
		return
	var rect := get_global_rect()
	_menu_button.position = rect.position + Vector2(10, 10)
	if is_instance_valid(_main_menu_overlay_button):
		var button_width := _main_menu_overlay_button.size.x
		if button_width <= 1.0:
			button_width = _main_menu_overlay_button.custom_minimum_size.x
		var button_height := _main_menu_overlay_button.size.y
		if button_height <= 1.0:
			button_height = _main_menu_overlay_button.custom_minimum_size.y
		_main_menu_overlay_button.position = Vector2(rect.end.x - button_width - 10.0, rect.end.y - button_height - 10.0)


func _table_menu_actions() -> Array[String]:
	var actions: Array[String] = ["View History", "Debug Sync", "Catch Up", _bot_speed_menu_label()]
	var phase := str(_snapshot.get("phase", ""))
	if bool(_snapshot.get("viewerCanUseHostControls", false)) and phase != "complete" and phase != "lobby":
		actions.append("End Game")
	actions.append("Main Menu")
	return actions


func _bot_speed_menu_label() -> String:
	return "Fast Bots" if _fast_bots_enabled else "Slow Bots"


func _toggle_bot_animation_speed() -> void:
	_fast_bots_enabled = not _fast_bots_enabled
	debug_stats["fastBotsEnabled"] = _fast_bots_enabled
	debug_stats["menuActions"] = _table_menu_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_menu_if_click_outside(mouse_event.position)
			_close_offer_popup_if_click_outside(mouse_event.position)


func _close_menu_if_click_outside(global_point: Vector2) -> void:
	if not is_instance_valid(_menu_popup) or not _menu_popup.visible:
		return
	if is_instance_valid(_menu_button) and _menu_button.get_global_rect().has_point(global_point):
		return
	var popup_rect := Rect2(Vector2(_menu_popup.position), Vector2(_menu_popup.size))
	if popup_rect.has_point(global_point):
		return
	_menu_popup.hide()


func _close_offer_popup_if_click_outside(global_point: Vector2) -> void:
	if not is_instance_valid(_offer_popup) or not _offer_popup.visible:
		return
	var popup_rect := Rect2(Vector2(_offer_popup.position), Vector2(_offer_popup.size))
	if popup_rect.has_point(global_point):
		return
	_offer_popup.hide()


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
		if selected_action == "Fast Bots" or selected_action == "Slow Bots":
			_toggle_bot_animation_speed()
			return
		menu_requested.emit(selected_action)
		)
	button.custom_minimum_size = Vector2(196, 38)
	button.add_theme_font_size_override("font_size", 15)
	if action == "End Game":
		_apply_button_style(button, Color(0.62, 0.24, 0.14), Color(0.34, 0.12, 0.06), 2)
	elif action == "Fast Bots" or action == "Slow Bots":
		_apply_button_style(button, Color(0.82, 0.58, 0.23), Color(0.42, 0.25, 0.08), 2)
	elif action == "Main Menu":
		_apply_button_style(button, Color(0.76, 0.62, 0.36), Color(0.40, 0.27, 0.13), 2)
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
		if str(participant.get("role", "")) != "active":
			continue
		visible_participants.append(participant)
	debug_stats["viewerCookMuted"] = false
	debug_stats["viewerCookVisible"] = false

	for index in range(visible_participants.size()):
		var participant: Dictionary = visible_participants[index]
		var participant_id := str(participant.get("id", ""))
		var indicator := _offer_indicator_for_participant(participant_id)
		var name := _participant_display_name(participant)
		var ingredient_id := str(participant.get("ingredientId", ""))
		var meta := VisualAssets.ingredient_meta(ingredient_id)
		var completed := int(participant.get("dishCount", 0))
		var target := int(_snapshot.get("targetDishCount", 0))
		var bottom_label := ""
		if ingredient_id != "":
			bottom_label = _ingredient_display(ingredient_id)
			if participant.has("realIngredientStock"):
				bottom_label = "%s x%s" % [bottom_label, int(participant.get("realIngredientStock", 0))]
		var is_viewer_tile := participant_id == viewer_id
		var is_visually_acting := participant_id == visual_actor_id
		var avatar_texture := VisualAssets.avatar_texture(index)
		var button := _player_tile(name, bottom_label, meta, avatar_texture, indicator, is_visually_acting, completed, target, COOK_TILE_SIZE, func(id := participant_id) -> void:
			_on_participant_pressed(id)
		)
		button.name = "Participant_%s" % participant_id
		button.position = _cook_ring_position(index)
		button.size = COOK_TILE_SIZE
		if is_viewer_tile:
			debug_stats["viewerCookVisible"] = true
		if is_visually_acting:
			button.modulate = Color(1.05, 1.0, 0.86)
		_participant_row.add_child(button)

	if _participant_row.get_child_count() == 0:
		var message := _row_message("Other players appear here.")
		message.position = Vector2(0, 24)
		message.size = Vector2(TABLE_CONTENT_WIDTH, 36)
		_participant_row.add_child(message)
	debug_stats["participantCount"] = visible_participants.size()


func _cook_ring_position(index: int) -> Vector2:
	if index >= 0 and index < COOK_RING_POSITIONS.size():
		return COOK_RING_POSITIONS[index]
	var column := index % 4
	var row := index / 4
	return Vector2(18 + column * 164, 24 + row * 294)


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
	var food_groups := _food_part_group_options(_snapshot.get("platterFoodParts", []))
	var total_visible_groups := voucher_groups_by_ingredient.size() + food_groups.size()
	var compact := total_visible_groups > BASKET_CENTER_OUT_SLOTS.size()
	var rendered_slots := 12 if compact else BASKET_CENTER_OUT_SLOTS.size()
	debug_stats["basketVisualOrder"] = visual_order.duplicate()

	_basket_grid.columns = 4
	_basket_grid.custom_minimum_size = BASKET_GRID_SIZE
	_basket_grid.add_theme_constant_override("h_separation", BASKET_COMPACT_GRID_GAP if compact else BASKET_GRID_GAP)
	_basket_grid.add_theme_constant_override("v_separation", BASKET_COMPACT_GRID_GAP if compact else BASKET_GRID_GAP)

	if compact:
		var compact_items: Array = []
		for ingredient_id in visual_order:
			var compact_group: Dictionary = voucher_groups_by_ingredient.get(ingredient_id, {})
			if not compact_group.is_empty():
				compact_items.append({"kind": "voucher", "ingredientId": ingredient_id, "group": compact_group})
		for raw_food_group in food_groups:
			var food_group: Dictionary = raw_food_group
			compact_items.append({"kind": "food", "group": food_group})
		for index in range(rendered_slots):
			if index >= compact_items.size():
				_basket_grid.add_child(_basket_empty_slot(index, BASKET_COMPACT_SLOT_SIZE))
				continue
			var item: Dictionary = compact_items[index]
			if str(item.get("kind", "")) == "voucher":
				count += 1
				_basket_grid.add_child(_basket_ingredient_slot(str(item.get("ingredientId", "")), item.get("group", {}), index, BASKET_COMPACT_SLOT_SIZE))
			else:
				count += 1
				_basket_grid.add_child(_basket_food_slot(item.get("group", {}), index, BASKET_COMPACT_SLOT_SIZE))
	else:
		var food_by_slot := _basket_food_groups_by_visual_slot(food_groups, ingredient_by_slot, voucher_groups_by_ingredient)
		for visual_slot_index in range(BASKET_CENTER_OUT_SLOTS.size()):
			var ingredient_id := str(ingredient_by_slot.get(visual_slot_index, ""))
			if ingredient_id != "":
				var group: Dictionary = voucher_groups_by_ingredient.get(ingredient_id, {})
				if not group.is_empty():
					count += 1
					_basket_grid.add_child(_basket_ingredient_slot(ingredient_id, group, visual_slot_index, BASKET_SLOT_SIZE))
				elif food_by_slot.has(visual_slot_index):
					count += 1
					_basket_grid.add_child(_basket_food_slot(food_by_slot[visual_slot_index], visual_slot_index, BASKET_SLOT_SIZE, "BasketSlot_%s" % ingredient_id))
				else:
					_basket_grid.add_child(_basket_ingredient_slot(ingredient_id, group, visual_slot_index, BASKET_SLOT_SIZE))
			elif food_by_slot.has(visual_slot_index):
				count += 1
				_basket_grid.add_child(_basket_food_slot(food_by_slot[visual_slot_index], visual_slot_index, BASKET_SLOT_SIZE))
			else:
				_basket_grid.add_child(_basket_empty_slot(visual_slot_index, BASKET_SLOT_SIZE))

	debug_stats["platterGroupCount"] = count
	debug_stats["basketRenderedSlotCount"] = rendered_slots
	debug_stats["basketCompact"] = compact


func _basket_food_groups_by_visual_slot(food_groups: Array, ingredient_by_slot: Dictionary, voucher_groups_by_ingredient: Dictionary) -> Dictionary:
	var food_by_slot := {}
	var food_index := 0
	for raw_visual_slot in BASKET_CENTER_OUT_SLOTS:
		var visual_slot_index := int(raw_visual_slot)
		var ingredient_id := str(ingredient_by_slot.get(visual_slot_index, ""))
		if ingredient_id != "":
			var voucher_group: Dictionary = voucher_groups_by_ingredient.get(ingredient_id, {})
			if not voucher_group.is_empty():
				continue
		if food_index >= food_groups.size():
			break
		food_by_slot[visual_slot_index] = food_groups[food_index]
		food_index += 1
	return food_by_slot


func _basket_food_slot(group: Dictionary, visual_slot_index: int, slot_size: Vector2 = BASKET_SLOT_SIZE, slot_name: String = "") -> Control:
	var slot := FixedBasketSlot.new()
	slot.fixed_size = slot_size
	slot.name = slot_name if slot_name != "" else "BasketFoodSlot_%s" % str(group.get("dishId", "dish"))
	slot.set_meta("basket_slot_index", visual_slot_index)
	slot.custom_minimum_size = slot_size
	slot.size = slot_size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	if group.is_empty():
		return slot

	var unit := str(group.get("unitSingular", "part"))
	var dish_name := str(group.get("dishName", "Dish"))
	var meta := VisualAssets.dish_meta(dish_name, unit)
	var label := "%s x%s" % [VisualAssets.short_dish_name(dish_name), int(group.get("count", 0))]
	var button := _visual_card("", label, meta, slot_size, func(g := group) -> void:
		_on_platter_food_group_pressed(g)
	)
	button.tooltip_text = _dish_piece_tooltip(group)
	_connect_food_piece_info_double_tap(button, group, "basket")
	_fit_basket_child_to_slot(button, slot_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.name = "PlatterFood_%s" % str(group.get("dishId", "dish"))
	if _selected_platter_asset_key == "dish_part:%s" % str(group.get("partId", "")):
		_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.08, 0.28, 0.60), 3)
	slot.add_child(button)
	return slot


func _basket_empty_slot(visual_slot_index: int, slot_size: Vector2 = BASKET_SLOT_SIZE) -> Control:
	var slot := FixedBasketSlot.new()
	slot.fixed_size = slot_size
	slot.name = "BasketSlot_empty_%s" % visual_slot_index
	slot.set_meta("basket_slot_index", visual_slot_index)
	slot.custom_minimum_size = slot_size
	slot.size = slot_size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	return slot


func _basket_ingredient_slot(ingredient_id: String, group: Dictionary, visual_slot_index: int, slot_size: Vector2 = BASKET_SLOT_SIZE) -> Control:
	var slot := FixedBasketSlot.new()
	slot.fixed_size = slot_size
	slot.name = "BasketSlot_%s" % ingredient_id
	slot.set_meta("basket_slot_index", visual_slot_index)
	slot.custom_minimum_size = slot_size
	slot.size = slot_size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	if group.is_empty():
		return slot

	var card_count := int(group.get("count", 0))
	var meta := _card_meta_with_stack(VisualAssets.ingredient_meta(ingredient_id), card_count)
	var label := _counted_ingredient_card_label(ingredient_id, card_count)
	var button := _visual_card("", label, meta, slot_size, func(g := group) -> void:
		_on_platter_voucher_group_pressed(g)
	)
	button.name = "PlatterVoucher_%s" % ingredient_id
	_fit_basket_child_to_slot(button, slot_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _selected_platter_asset_key == "voucher:%s" % str(group.get("voucherId", "")):
		_apply_button_style(button, meta.get("color", Color(0.8, 0.8, 0.8)), Color(0.08, 0.28, 0.60), 3)
	slot.add_child(button)
	return slot


func _fit_basket_child_to_slot(child: Control, slot_size: Vector2) -> void:
	child.anchor_left = 0.0
	child.anchor_top = 0.0
	child.anchor_right = 0.0
	child.anchor_bottom = 0.0
	child.offset_left = 0.0
	child.offset_top = 0.0
	child.offset_right = slot_size.x
	child.offset_bottom = slot_size.y
	child.position = Vector2.ZERO
	child.size = slot_size


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
	var title := FixedLabel.new()
	var viewer_name := _participant_name(_viewer_id()).strip_edges()
	title.text = "Actions" if viewer_name == "" or viewer_name == "Someone" else "%s's Actions" % viewer_name
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.fixed_minimum_size = Vector2(206, 20)
	title.custom_minimum_size = Vector2(206, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEXT_DARK)
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
		_render_complete_action_controls()
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
	if _viewer_has_finished_dish_goal():
		_redeem_box.add_child(_finished_dishes_help_label())
		return
	if _is_round_robin_off_turn("playing"):
		_redeem_box.add_child(_action_label("Wait while other cooks take their turns."))
		return
	if _selected_hand_voucher_id == "" and _selected_inventory_asset_key == "":
		_redeem_box.add_child(_action_label("Tap a promise card to select it."))
	else:
		_redeem_box.add_child(_action_label("Choose a needed card in basket or from another player."))


func _render_settlement_action_controls() -> void:
	if _all_active_dish_goals_complete() and not _all_active_players_cleared():
		_redeem_box.add_child(_settlement_debt_label())
		return
	var give_label := _asset_label_from_key(_selected_inventory_asset_key)
	var take_label := _asset_label_from_key(_selected_platter_asset_key)
	if give_label == "" and take_label == "":
		_redeem_box.add_child(_action_label("Choose a card or dish piece to settle."))
	else:
		_redeem_box.add_child(_action_label("Choose an item in the basket to settle."))


func _render_eating_action_controls() -> void:
	debug_stats["takeBiteEnabled"] = false
	var viewer := _participant_by_id(_viewer_id())
	if not bool(viewer.get("cleared", false)):
		_redeem_box.add_child(_action_label("Return promise cards before sharing food."))
		return
	var groups := _food_part_group_options(_snapshot.get("ownFoodParts", []))
	if groups.is_empty():
		if _held_food_part_total() > 0:
			_redeem_box.add_child(_action_label("You have shared all your food. Waiting for other cooks."))
		else:
			_redeem_box.add_child(_action_label("All food is shared. Finishing the table."))
		return
	_redeem_box.add_child(_action_label("Food is being shared automatically."))


func _render_complete_action_controls() -> void:
	_redeem_box.add_child(_action_label("All food is shared."))
	_redeem_box.add_child(_action_button("Game Stats", _open_game_stats_popup))
	var fireworks := FireworksShow.new()
	fireworks.name = "ActionFireworks"
	fireworks.custom_minimum_size = COMPLETE_ACTION_FIREWORKS_SIZE
	fireworks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redeem_box.add_child(fireworks)
	debug_stats["completeFireworks"] = true


func _viewer_has_finished_dish_goal() -> bool:
	if str(_snapshot.get("phase", "")) != "playing":
		return false
	var viewer := _participant_by_id(_viewer_id())
	var target := int(_snapshot.get("targetDishCount", 0))
	if target > 0 and int(viewer.get("dishCount", 0)) >= target:
		return true
	return _snapshot.get("ownRecipe", {}).is_empty() and int(viewer.get("dishCount", 0)) > 0


func _finished_dishes_help_label() -> Label:
	var label := _action_label("Help the other cooks make their dishes.")
	label.fixed_minimum_size = Vector2(206, ACTION_LABEL_MEDIUM_HEIGHT)
	label.custom_minimum_size = Vector2(206, ACTION_LABEL_MEDIUM_HEIGHT)
	return label


func _settlement_debt_label() -> Label:
	var label := _action_label("Everyone has to settle and return to how the game started (2 cards in the common basket, and 6 cards in their hand)")
	label.add_theme_font_size_override("font_size", 12)
	label.fixed_minimum_size = Vector2(206, 132)
	label.custom_minimum_size = Vector2(206, 132)
	return label


func _all_active_dish_goals_complete() -> bool:
	var target := int(_snapshot.get("targetDishCount", 0))
	if target <= 0:
		return false
	var saw_active := false
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		saw_active = true
		if int(participant.get("dishCount", 0)) < target:
			return false
	return saw_active


func _all_active_players_cleared() -> bool:
	var saw_active := false
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		saw_active = true
		if not bool(participant.get("cleared", false)):
			return false
	return saw_active


func _render_recipe() -> void:
	_clear(_recipe_grid)
	_set_plain_recipe_title("")
	if str(_snapshot.get("phase", "lobby")) == "complete":
		_set_plain_recipe_title(_complete_title())
		debug_stats["recipeName"] = "Congratulations!"
		debug_stats["recipeTitle"] = _complete_title()
		debug_stats["recipeSlotCount"] = 0
		debug_stats["completeCelebration"] = true
		_render_complete_summary()
		return
	var recipe: Dictionary = _snapshot.get("ownRecipe", {})
	var recipe_name := _recipe_name(recipe)
	debug_stats["recipeName"] = recipe_name
	if recipe_name != "":
		_set_active_recipe_title(recipe_name)
		debug_stats["recipeTitle"] = _recipe_title(recipe_name)
	else:
		_set_plain_recipe_title(_empty_recipe_title())
		debug_stats["recipeTitle"] = _empty_recipe_title()
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


func _empty_recipe_title() -> String:
	match str(_snapshot.get("phase", "")):
		"settlement":
			return "Dish Pieces Held"
		"eating":
			return "Food to Share"
		_:
			return "Dishes Made"


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
		var completed := int(participant.get("dishCount", 0))
		var cell := _dish_progress_cell(_participant_display_name(participant), completed, target)
		_recipe_grid.add_child(cell)
		count += 1
	if count == 0:
		_recipe_grid.add_child(_muted_label("No dishes made yet."))
	debug_stats["dishSummaryCount"] = count


func _render_held_piece_summary() -> void:
	var phase := str(_snapshot.get("phase", ""))
	var bite_totals := _bite_totals_by_participant()
	var count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		var pieces := _held_food_part_count(participant)
		if phase == "eating":
			_recipe_grid.add_child(_food_summary_cell("%s\n%s left\n%s shared" % [
				_participant_display_name(participant),
				pieces,
				int(bite_totals.get(participant_id, 0))
			]))
		else:
			var unit := "piece" if pieces == 1 else "pieces"
			_recipe_grid.add_child(_dish_summary_cell("%s\n%s %s" % [
				_participant_display_name(participant),
				pieces,
				unit
			]))
		count += 1
	if count == 0:
		_recipe_grid.add_child(_muted_label("No pieces available."))
	debug_stats["dishSummaryCount"] = count
	debug_stats["pieceSummaryCount"] = count
	debug_stats["pieceSummaryTotal"] = _held_food_part_total()
	debug_stats["pieceSummaryEatenTotal"] = _bite_total()


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


func _bite_total() -> int:
	var total := 0
	for value in _bite_totals_by_participant().values():
		total += int(value)
	return total


func _render_complete_summary() -> void:
	_recipe_grid.columns = 2
	debug_stats["dishSummaryColumns"] = _recipe_grid.columns

	var bite_totals := _bite_totals_by_participant()
	var count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		var shared := int(bite_totals.get(participant_id, 0))
		var ingredient_id := str(participant.get("ingredientId", ""))
		var stock := int(participant.get("realIngredientStock", 0))
		_recipe_grid.add_child(_complete_summary_cell("%s\n%s: %s Shared: %s" % [
			_participant_display_name(participant),
			_ingredient_display(ingredient_id),
			stock,
			shared
		]))
		count += 1
	debug_stats["completeBiteSummaryCount"] = count


func _complete_title() -> String:
	var stats := _game_stats()
	var player_turns := int(stats.get("playerTurnCount", 0))
	debug_stats["completeTurnCount"] = player_turns
	debug_stats["completePlayerTurnCount"] = player_turns
	debug_stats["completeCycleCount"] = float(stats.get("cycleCount", 0.0))
	if player_turns <= 0:
		return "Congratulations!"
	return "Congratulations! %s player turns" % player_turns


func _sync_complete_celebration_effects() -> void:
	var phase := str(_snapshot.get("phase", ""))
	if phase == "eating":
		_clear_complete_avatar_dance()
		var eating_items := _complete_food_orbit_items()
		var eating_visible := _shared_food_orbit_items.size() if not _shared_food_orbit_items.is_empty() else _shared_food_orbit_visible_count_for_snapshot(_snapshot, eating_items)
		if eating_visible > 0:
			_ensure_complete_food_orbit_for_items(eating_items, eating_visible)
		elif not _should_preserve_complete_orbit_transition():
			_clear_complete_food_orbit()
		return
	if phase != "complete":
		_clear_complete_avatar_dance()
		if not _should_preserve_complete_orbit_transition():
			_clear_complete_food_orbit()
		elif is_instance_valid(_complete_food_orbit):
			debug_stats["completeFoodOrbitCount"] = int(_complete_food_orbit.get_meta("orbit_item_count", 0))
			debug_stats["completeFoodOrbitVisibleCount"] = int(_complete_food_orbit.get_meta("visible_orbit_item_count", 0))
		return
	_start_complete_avatar_dance()
	_ensure_complete_food_orbit()
	_complete_orbit_transition_active = false


func _clear_complete_celebration_effects() -> void:
	_clear_complete_avatar_dance()
	_clear_complete_food_orbit()


func _should_preserve_complete_orbit_transition() -> bool:
	return _complete_orbit_transition_active \
		and (_animation_running or not _animation_queue.is_empty() or _has_pending_visual_snapshot or not _pending_visual_snapshots.is_empty())


func _clear_complete_avatar_dance() -> void:
	for raw_tween in _complete_avatar_tweens:
		var tween := raw_tween as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_complete_avatar_tweens.clear()
	for raw_avatar in find_children("CookAvatar", "TextureRect", true, false):
		var avatar := raw_avatar as TextureRect
		if not is_instance_valid(avatar):
			continue
		if avatar.has_meta("complete_dance"):
			avatar.rotation_degrees = 0.0
			avatar.scale = Vector2.ONE
			avatar.remove_meta("complete_dance")
	if debug_stats.has("completeAvatarDanceCount"):
		debug_stats["completeAvatarDanceCount"] = 0


func _start_complete_avatar_dance() -> void:
	_clear_complete_avatar_dance()
	var count := 0
	for raw_avatar in find_children("CookAvatar", "TextureRect", true, false):
		var avatar := raw_avatar as TextureRect
		if not is_instance_valid(avatar):
			continue
		avatar.pivot_offset = avatar.size * 0.5 if avatar.size.x > 0.0 and avatar.size.y > 0.0 else Vector2(16, 16)
		avatar.set_meta("complete_dance", true)
		var tween := create_tween()
		tween.set_loops()
		var delay := float(count % 4) * 0.07
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(avatar, "rotation_degrees", -10.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(avatar, "rotation_degrees", 10.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(avatar, "rotation_degrees", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_complete_avatar_tweens.append(tween)
		count += 1
	debug_stats["completeAvatarDanceCount"] = count


func _ensure_complete_food_orbit() -> void:
	_ensure_complete_food_orbit_for_items(_complete_food_orbit_items(), -1)


func _ensure_complete_food_orbit_for_items(items: Array, visible_count := -1) -> void:
	if not is_instance_valid(_overlay_layer):
		return
	if items.is_empty():
		_clear_complete_food_orbit()
		debug_stats["completeFoodOrbitCount"] = 0
		return
	var key := _complete_food_orbit_key_for_items(items)
	if is_instance_valid(_complete_food_orbit) and _complete_food_orbit_key == key:
		if _complete_food_orbit.has_method("set_visible_item_count"):
			_complete_food_orbit.call("set_visible_item_count", visible_count)
		debug_stats["completeFoodOrbitCount"] = int(_complete_food_orbit.get_meta("orbit_item_count", items.size()))
		debug_stats["completeFoodOrbitVisibleCount"] = int(_complete_food_orbit.get_meta("visible_orbit_item_count", debug_stats["completeFoodOrbitCount"]))
		return
	_clear_complete_food_orbit(false)
	var orbit := CompleteFoodOrbit.new()
	orbit.configure(items, visible_count)
	_overlay_layer.add_child(orbit)
	_overlay_layer.move_child(orbit, 0)
	_complete_food_orbit = orbit
	_complete_food_orbit_key = key
	debug_stats["completeFoodOrbitCount"] = items.size()
	debug_stats["completeFoodOrbitVisibleCount"] = int(orbit.get_meta("visible_orbit_item_count", items.size()))


func _clear_complete_food_orbit(clear_shared_items := true) -> void:
	if is_instance_valid(_complete_food_orbit):
		_complete_food_orbit.queue_free()
	_complete_food_orbit = null
	_complete_food_orbit_key = ""
	_complete_orbit_transition_active = false
	if clear_shared_items:
		_shared_food_orbit_items.clear()
	if debug_stats.has("completeFoodOrbitCount"):
		debug_stats["completeFoodOrbitCount"] = 0
	if debug_stats.has("completeFoodOrbitVisibleCount"):
		debug_stats["completeFoodOrbitVisibleCount"] = 0


func _complete_food_orbit_items() -> Array:
	if str(_snapshot.get("phase", "")) == "complete":
		var snapshot_items := _complete_food_orbit_items_for_snapshot(_snapshot)
		if not snapshot_items.is_empty():
			return snapshot_items
	if not _shared_food_orbit_items.is_empty():
		return _shared_food_orbit_items.duplicate(true)
	return _complete_food_orbit_items_for_snapshot(_snapshot)


func _complete_food_orbit_items_for_snapshot(snapshot: Dictionary) -> Array:
	var items: Array = []
	for raw_dish in snapshot.get("dishes", []):
		if not raw_dish is Dictionary:
			continue
		var dish: Dictionary = raw_dish
		var dish_name := str(dish.get("name", dish.get("dishName", "Dish"))).strip_edges()
		if dish_name == "":
			dish_name = "Dish"
		var unit := str(dish.get("unitSingular", dish.get("unit", "piece"))).strip_edges()
		if unit == "":
			unit = "piece"
		var piece_count := int(dish.get("partsEaten", 0)) + int(dish.get("partsRemaining", 0))
		_append_complete_orbit_item(items, dish_name, unit, maxi(1, piece_count))
		if items.size() >= COMPLETE_FOOD_ORBIT_MAX_ITEMS:
			return items
	if items.is_empty():
		_append_complete_food_groups(items, _food_part_group_options(snapshot.get("ownFoodParts", [])))
		_append_complete_food_groups(items, _food_part_group_options(snapshot.get("platterFoodParts", [])))
	if items.is_empty():
		for ingredient_id in DEFAULT_INGREDIENT_ORDER:
			var meta := VisualAssets.ingredient_meta(str(ingredient_id))
			_append_complete_orbit_meta(items, _ingredient_display(str(ingredient_id)), "ingredient", meta, 1)
			if items.size() >= COMPLETE_FOOD_ORBIT_MIN_ITEMS:
				break
	return items


func _append_complete_food_groups(items: Array, groups: Array) -> void:
	for raw_group in groups:
		var group: Dictionary = raw_group
		var dish_name := str(group.get("dishName", "Dish")).strip_edges()
		var unit := str(group.get("unitSingular", "piece")).strip_edges()
		_append_complete_orbit_item(items, dish_name, unit, int(group.get("count", 1)))
		if items.size() >= COMPLETE_FOOD_ORBIT_MAX_ITEMS:
			return


func _append_complete_orbit_item(items: Array, dish_name: String, unit: String, quantity := 1) -> void:
	var clean_dish := dish_name.strip_edges()
	if clean_dish == "":
		clean_dish = "Dish"
	var clean_unit := unit.strip_edges()
	if clean_unit == "":
		clean_unit = "piece"
	_append_complete_orbit_meta(items, clean_dish, clean_unit, VisualAssets.dish_meta(clean_dish, clean_unit), maxi(1, quantity))


func _append_complete_orbit_meta(items: Array, name: String, unit: String, meta: Dictionary, quantity := 1) -> void:
	var texture = meta.get("texture", null)
	if not texture is Texture2D:
		return
	items.append({
		"name": name,
		"unit": unit,
		"quantity": maxi(1, quantity),
		"texture": texture
	})


func _complete_food_orbit_key_for_items(items: Array) -> String:
	var parts: Array[String] = []
	for raw_item in items:
		var item: Dictionary = raw_item
		parts.append("%s:%s:%s:%s:%.6f" % [
			str(item.get("sourceParticipantId", "")),
			str(item.get("name", "")),
			str(item.get("unit", "")),
			int(item.get("quantity", 1)),
			float(item.get("orbitPhase", -1.0))
		])
	return "|".join(parts)


func _complete_orbit_item_for_eat_event(event: Dictionary) -> Dictionary:
	var dish_name := str(event.get("dishName", "Dish")).strip_edges()
	if dish_name == "":
		dish_name = "Dish"
	var unit := str(event.get("unit", "part")).strip_edges()
	if unit == "":
		unit = "part"
	var meta := VisualAssets.dish_meta(dish_name, unit)
	var texture = meta.get("texture", null)
	if not texture is Texture2D:
		return {}
	return {
		"name": dish_name,
		"unit": unit,
		"quantity": maxi(1, int(event.get("quantity", 1))),
		"sourceParticipantId": str(event.get("participantId", "")),
		"dishId": str(event.get("dishId", "")),
		"texture": texture
	}


func _complete_orbit_phase_for_eat_event(event: Dictionary, reveal_index: int) -> float:
	var key := "%s|%s|%s|%s|%s|%s|%s" % [
		str(event.get("_transactionId", "")),
		str(event.get("participantId", "")),
		str(event.get("dishId", "")),
		str(event.get("dishName", "")),
		str(event.get("unit", "")),
		int(event.get("quantity", 1)),
		int(event.get("eatSequence", reveal_index))
	]
	var base := float(_stable_visual_hash(key) % 1000000) / 1000000.0
	return fposmod(base + float(maxi(0, reveal_index)) * 0.38196601125, 1.0)


func _stable_visual_hash(value: String) -> int:
	var result := 2166136261
	for index in range(value.length()):
		result = result ^ value.unicode_at(index)
		result = (result * 16777619) & 0xFFFFFFFF
	return result


func _shared_food_orbit_visible_count_for_snapshot(snapshot: Dictionary, items: Array) -> int:
	if items.is_empty():
		return 0
	if str(snapshot.get("phase", "")) == "complete":
		return items.size()
	return clampi(_shared_food_eaten_count_for_snapshot(snapshot), 0, items.size())


func _shared_food_eaten_count_for_snapshot(snapshot: Dictionary) -> int:
	var eaten := 0
	for raw_dish in snapshot.get("dishes", []):
		if not raw_dish is Dictionary:
			continue
		var dish: Dictionary = raw_dish
		eaten += max(0, int(dish.get("partsEaten", dish.get("totalBites", 0) - dish.get("bitesRemaining", 0))))
		var bite_counts = dish.get("biteCounts", {})
		if typeof(bite_counts) == TYPE_DICTIONARY:
			var bite_sum := 0
			for raw_key in bite_counts.keys():
				bite_sum += int(bite_counts.get(raw_key, 0))
			eaten = max(eaten, bite_sum)
	var stats = snapshot.get("gameStats", {})
	if typeof(stats) == TYPE_DICTIONARY:
		eaten = max(eaten, int(stats.get("eatCount", eaten)))
	return eaten


func _open_game_stats_popup() -> void:
	_clear(_offer_popup_list)
	var viewport_size := get_viewport_rect().size
	var popup_width := _safe_popup_width(TABLE_CONTENT_WIDTH - 80, 320, 48)
	var content_width := maxi(260, popup_width - 34)
	_prepare_offer_popup_content(content_width)
	_offer_popup_list.add_child(_offer_popup_header("Game Stats"))
	var use_two_columns := popup_width >= 560 and viewport_size.x >= 760
	var columns: BoxContainer
	if use_two_columns:
		columns = HBoxContainer.new()
	else:
		columns = VBoxContainer.new()
	columns.name = "GameStatsColumns"
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column_width: int = maxi(150, int((content_width - 12) / 2)) if use_two_columns else content_width
	var core_column := VBoxContainer.new()
	core_column.name = "CoreStatsColumn"
	core_column.custom_minimum_size = Vector2(column_width, 0)
	core_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var economics_column := VBoxContainer.new()
	economics_column.name = "EconomicsStatsColumn"
	economics_column.custom_minimum_size = Vector2(column_width, 0)
	economics_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_column.add_child(_offer_popup_text("Game flow"))
	for line in _core_game_stats_lines():
		core_column.add_child(_offer_popup_wrapped_text(line, column_width))
	economics_column.add_child(_offer_popup_text("Economics"))
	for line in _economics_game_stats_lines():
		economics_column.add_child(_offer_popup_wrapped_text(line, column_width))
	columns.add_child(core_column)
	columns.add_child(economics_column)
	_offer_popup_list.add_child(columns)
	debug_stats["gameStatsColumnMode"] = "two" if use_two_columns else "one"
	_offer_popup_list.add_child(_offer_popup_button("View Transaction History", func() -> void:
		_offer_popup.hide()
		menu_requested.emit("View History")
	))
	var max_height := clampi(int(viewport_size.y) - 48, 420, 620)
	_popup_centered_tight(popup_width, max_height, true)


func _game_stats_lines() -> Array[String]:
	var lines := _core_game_stats_lines()
	lines.append_array(_economics_game_stats_lines())
	return lines


func _core_game_stats_lines() -> Array[String]:
	var stats := _game_stats()
	return [
		"Player turns: %s" % int(stats.get("playerTurnCount", 0)),
		"Cycles: %s" % _format_cycles(float(stats.get("cycleCount", 0.0))),
		"Interactions: %s" % int(stats.get("interactionCount", 0)),
		"Opening offerings: %s" % int(stats.get("openingOfferingCount", 0)),
		"Common Basket swaps: %s" % int(stats.get("commonBasketSwapCount", 0)),
		"Direct exchanges: %s" % int(stats.get("directExchangeCount", 0)),
		"Redemptions: %s" % int(stats.get("redemptionCount", 0)),
		"Dishes prepared: %s" % int(stats.get("prepareCount", 0)),
		"Settlement swaps: %s" % int(stats.get("settlementSwapCount", 0)),
		"Food-piece settlement swaps: %s" % int(stats.get("foodPieceSettlementSwapCount", 0)),
		"Food shared: %s" % int(stats.get("eatCount", 0)),
		"Assets lost: %s" % int(stats.get("assetLossCount", 0)),
		"Productivity: %s" % int(stats.get("productivityCount", 0)),
		"Profit: %s" % int(stats.get("profitCount", 0)),
		"Gain: %s" % _format_percent(float(stats.get("profitGainPercent", 0.0)))
	]


func _economics_game_stats_lines() -> Array[String]:
	var stats := _game_stats()
	return [
		"Avg turns/dish: %s" % _format_decimal(float(stats.get("averageTurnsPerDish", 0.0))),
		"Avg interactions/dish: %s" % _format_decimal(float(stats.get("averageInteractionsPerDish", 0.0))),
			"Basket velocity: %s swaps/cycle" % _format_decimal(float(stats.get("basketVelocity", 0.0))),
			"Direct exchange share: %s" % _format_percent(float(stats.get("directExchangeShare", 0.0)) * 100.0),
			"Settlement burden: %s" % _format_percent(float(stats.get("settlementBurden", 0.0)) * 100.0),
			"Liquidity depth: %s assets" % _format_decimal(float(stats.get("liquidityDepth", 0.0))),
			"Settlement time: %s turns" % int(stats.get("settlementTimeTurns", 0)),
			"Consumption variance: %s" % _format_decimal(float(stats.get("consumptionVariance", 0.0)))
		]


func _game_stats() -> Dictionary:
	var raw_stats = _snapshot.get("gameStats", {})
	var derived := _derive_game_stats()
	if typeof(raw_stats) == TYPE_DICTIONARY and not raw_stats.is_empty():
		var merged: Dictionary = raw_stats.duplicate(true)
		for key in derived.keys():
			if not merged.has(key):
				merged[key] = derived[key]
		return merged
	return derived


func _derive_game_stats() -> Dictionary:
	var history: Array = _snapshot.get("transactionHistory", [])
	var pass_turns := _count_transactions(history, "Pass Turn")
	var active_count := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) == "active":
			active_count += 1
	var settlement_swaps := 0
	var food_piece_settlement_swaps := 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Settlement Swap":
			continue
		settlement_swaps += 1
		if _transaction_asset_is_food_piece(str(transaction.get("itemOut", ""))) or _transaction_asset_is_food_piece(str(transaction.get("itemBack", ""))):
			food_piece_settlement_swaps += 1
	var asset_loss_count := _derive_asset_loss_count()
	var productivity_count := _count_transactions(history, "Share") + _count_transactions(history, "Eat")
	var interaction_count := history.size() - pass_turns
	var common_basket_swaps := _count_transactions(history, "Swap")
	var direct_exchanges := _count_transactions(history, "Exchange")
	var prepare_count := _count_transactions(history, "Prepare")
	var total_trades := common_basket_swaps + direct_exchanges + settlement_swaps
	var cycle_count := float(pass_turns) / float(active_count) if active_count > 0 else 0.0
	var hoarding := _derive_hoarding_index()
	return {
		"activePlayerCount": active_count,
		"mutationCount": int(_snapshot.get("turn", 0)),
		"playerTurnCount": pass_turns,
		"cycleCount": cycle_count,
		"interactionCount": interaction_count,
		"openingOfferingCount": _count_transactions(history, "Deposit"),
		"commonBasketSwapCount": common_basket_swaps,
		"directExchangeCount": direct_exchanges,
		"redemptionCount": _count_transactions(history, "Redeem"),
		"prepareCount": prepare_count,
		"settlementSwapCount": settlement_swaps,
		"foodPieceSettlementSwapCount": food_piece_settlement_swaps,
		"eatCount": productivity_count,
		"assetLossCount": asset_loss_count,
		"productivityCount": productivity_count,
		"profitCount": productivity_count - asset_loss_count,
		"profitGainPercent": _profit_gain_percent(productivity_count, asset_loss_count),
		"averageTurnsPerDish": float(pass_turns) / float(prepare_count) if prepare_count > 0 else 0.0,
		"averageInteractionsPerDish": float(interaction_count) / float(prepare_count) if prepare_count > 0 else 0.0,
		"basketVelocity": float(common_basket_swaps + settlement_swaps) / cycle_count if cycle_count > 0.0 else 0.0,
		"directExchangeShare": float(direct_exchanges) / float(total_trades) if total_trades > 0 else 0.0,
		"settlementBurden": float(settlement_swaps) / float(interaction_count) if interaction_count > 0 else 0.0,
		"scarcityPressureByIngredient": {},
		"hoardingIndex": int(hoarding.get("hoardingIndex", 0)),
		"hoardingIndexLabel": str(hoarding.get("hoardingIndexLabel", "None")),
		"liquidityDepth": _derive_liquidity_depth(history),
		"settlementTimeTurns": _derive_settlement_time_turns(history),
		"consumptionVariance": _derive_consumption_variance(),
		"tradeBalanceByParticipant": _derive_trade_balances(history)
	}


func _count_transactions(history: Array, action: String) -> int:
	var count := 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == action:
			count += 1
	return count


func _transaction_asset_is_food_piece(label: String) -> bool:
	var normalized := label.strip_edges().to_lower()
	return normalized != "" and normalized != "none" and normalized != "turn" and normalized.find("card") < 0


func _derive_asset_loss_count() -> int:
	var starting_stock := int(_snapshot.get("stockPerIngredient", 0))
	if starting_stock <= 0:
		return 0
	var loss := 0
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		loss += maxi(0, starting_stock - int(participant.get("realIngredientStock", starting_stock)))
	return loss


func _derive_hoarding_index() -> Dictionary:
	var best_count := 0
	var best_name := ""
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var count := int(participant.get("foreignCardsInHand", 0))
		if count > best_count:
			best_count = count
			best_name = _participant_display_name(participant)
	if best_count <= 0:
		return {"hoardingIndex": 0, "hoardingIndexLabel": "None"}
	return {"hoardingIndex": best_count, "hoardingIndexLabel": "%s holds foreign cards x%s" % [best_name, best_count]}


func _derive_liquidity_depth(history: Array) -> float:
	var basket_counts := {}
	var sample_total := 0
	var sample_count := 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		var action := str(transaction.get("action", ""))
		if action == "Deposit":
			_add_basket_asset_count(basket_counts, str(transaction.get("itemOut", "")))
		elif action == "Swap" or action == "Settlement Swap":
			_add_basket_asset_count(basket_counts, str(transaction.get("itemOut", "")))
			_remove_basket_asset_count(basket_counts, str(transaction.get("itemBack", "")))
		else:
			continue
		var distinct := 0
		for value in basket_counts.values():
			if int(value) > 0:
				distinct += 1
		sample_total += distinct
		sample_count += 1
	return float(sample_total) / float(sample_count) if sample_count > 0 else 0.0


func _add_basket_asset_count(counts: Dictionary, label: String) -> void:
	var key := _normalized_asset_label(label)
	if key == "":
		return
	counts[key] = int(counts.get(key, 0)) + _asset_quantity_from_label(label)


func _remove_basket_asset_count(counts: Dictionary, label: String) -> void:
	var key := _normalized_asset_label(label)
	if key == "":
		return
	var next := int(counts.get(key, 0)) - _asset_quantity_from_label(label)
	if next <= 0:
		counts.erase(key)
	else:
		counts[key] = next


func _normalized_asset_label(label: String) -> String:
	var normalized := label.strip_edges().to_lower()
	if normalized == "" or normalized == "none" or normalized == "turn" or normalized == "eaten":
		return ""
	var x_index := normalized.rfind(" x")
	if x_index >= 0:
		var suffix := normalized.substr(x_index + 2)
		if suffix.is_valid_int():
			normalized = normalized.substr(0, x_index)
	var card_index := normalized.rfind(" card ")
	if card_index >= 0:
		var suffix_card := normalized.substr(card_index + 6)
		if suffix_card.is_valid_int():
			normalized = normalized.substr(0, card_index + 5)
	return normalized


func _asset_quantity_from_label(label: String) -> int:
	var normalized := label.strip_edges().to_lower()
	if normalized == "" or normalized == "none" or normalized == "turn" or normalized == "eaten":
		return 0
	var x_index := normalized.rfind(" x")
	if x_index >= 0:
		var suffix := normalized.substr(x_index + 2)
		if suffix.is_valid_int():
			return int(suffix)
	return 1


func _derive_settlement_time_turns(history: Array) -> int:
	var last_prepare_turn := -1
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == "Prepare":
			last_prepare_turn = int(transaction.get("turn", 0))
	if last_prepare_turn < 0:
		return 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if ["Share", "Eat"].has(str(transaction.get("action", ""))) and int(transaction.get("turn", 0)) >= last_prepare_turn:
			return maxi(0, int(transaction.get("turn", 0)) - last_prepare_turn)
	var phase := str(_snapshot.get("phase", ""))
	if phase == "settlement" or phase == "eating" or phase == "complete":
		return maxi(0, int(_snapshot.get("turn", 0)) - last_prepare_turn)
	return 0


func _derive_consumption_variance() -> float:
	var active_ids: Array[String] = []
	var totals := {}
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		active_ids.append(participant_id)
		totals[participant_id] = 0
	if active_ids.is_empty():
		return 0.0
	for raw_dish in _snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		var bite_counts: Dictionary = dish.get("biteCounts", {})
		for participant_id in bite_counts.keys():
			var key := str(participant_id)
			totals[key] = int(totals.get(key, 0)) + int(bite_counts.get(participant_id, 0))
	var mean := 0.0
	for participant_id in active_ids:
		mean += float(totals.get(participant_id, 0))
	mean = mean / float(active_ids.size())
	var variance := 0.0
	for participant_id in active_ids:
		var value := float(totals.get(participant_id, 0))
		variance += pow(value - mean, 2.0)
	return variance / float(active_ids.size())


func _derive_trade_balances(history: Array) -> Dictionary:
	var balances := {}
	for raw_participant in _snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("role", "")) != "active":
			continue
		var participant_id := str(participant.get("id", ""))
		balances[participant_id] = [0, 0, 0]
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		var action := str(transaction.get("action", ""))
		if action != "Swap" and action != "Settlement Swap" and action != "Exchange":
			continue
		var actor_id := str(transaction.get("participantId", ""))
		if balances.has(actor_id):
			var actor: Array = balances[actor_id]
			actor[0] = int(actor[0]) + _asset_quantity_from_label(str(transaction.get("itemOut", "")))
			actor[1] = int(actor[1]) + _asset_quantity_from_label(str(transaction.get("itemBack", "")))
			actor[2] = int(actor[1]) - int(actor[0])
		var counterparty_id := str(transaction.get("counterpartyParticipantId", ""))
		if counterparty_id != "" and balances.has(counterparty_id):
			var counterparty: Array = balances[counterparty_id]
			counterparty[0] = int(counterparty[0]) + _asset_quantity_from_label(str(transaction.get("itemBack", "")))
			counterparty[1] = int(counterparty[1]) + _asset_quantity_from_label(str(transaction.get("itemOut", "")))
			counterparty[2] = int(counterparty[1]) - int(counterparty[0])
	return balances


func _profit_gain_percent(productivity_count: int, asset_loss_count: int) -> float:
	if asset_loss_count <= 0:
		return 0.0
	return (float(productivity_count - asset_loss_count) / float(asset_loss_count)) * 100.0


func _format_cycles(cycles: float) -> String:
	var rounded: float = round(cycles)
	if abs(cycles - rounded) < 0.05:
		return str(int(rounded))
	return "%.1f" % cycles


func _format_percent(percent: float) -> String:
	var rounded: float = round(percent)
	if abs(percent - rounded) < 0.05:
		return "%s%%" % int(rounded)
	return "%.1f%%" % percent


func _format_decimal(value: float) -> String:
	var rounded: float = round(value)
	if abs(value - rounded) < 0.05:
		return str(int(rounded))
	return "%.1f" % value


func _scarcity_pressure_summary(stats: Dictionary) -> String:
	var pressure_raw = stats.get("scarcityPressureByIngredient", {})
	if typeof(pressure_raw) != TYPE_DICTIONARY or pressure_raw.is_empty():
		return "none recorded"
	var parts: Array[String] = []
	for ingredient_id in pressure_raw.keys():
		var amount := int(pressure_raw.get(ingredient_id, 0))
		if amount <= 0:
			continue
		parts.append("%s %s" % [_ingredient_display(str(ingredient_id)), amount])
	if parts.is_empty():
		return "none recorded"
	parts.sort()
	return ", ".join(parts)


func _hoarding_summary(stats: Dictionary) -> String:
	var amount := int(stats.get("hoardingIndex", 0))
	if amount <= 0:
		return "none"
	var label := str(stats.get("hoardingIndexLabel", ""))
	return label if label.strip_edges() != "" else "max foreign cards x%s" % amount


func _trade_balance_summary(stats: Dictionary) -> String:
	var balances_raw = stats.get("tradeBalanceByParticipant", {})
	if typeof(balances_raw) != TYPE_DICTIONARY or balances_raw.is_empty():
		return "none"
	var parts: Array[String] = []
	for participant_id in balances_raw.keys():
		var row_raw = balances_raw.get(participant_id, {})
		var name := _participant_name(str(participant_id))
		var net := 0
		if typeof(row_raw) == TYPE_ARRAY:
			var row_array: Array = row_raw
			if row_array.size() < 3:
				continue
			net = int(row_array[2])
		elif typeof(row_raw) == TYPE_DICTIONARY:
			var row: Dictionary = row_raw
			name = str(row.get("name", name))
			net = int(row.get("net", 0))
		else:
			continue
		parts.append("%s %s" % [name, _signed_int(net)])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)


func _signed_int(value: int) -> String:
	if value > 0:
		return "+%s" % value
	return str(value)


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


func _dish_progress_cell(name_text: String, completed: int, target: int) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(178, 30)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	var name := _muted_label(name_text)
	name.name = "DishProgressName"
	name.custom_minimum_size = Vector2(104, 26)
	name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	box.add_child(name)
	if target > 0:
		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(44, 18)
		center.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var stars := ProgressStars.new()
		stars.name = "DishProgressStars"
		stars.set_star_size(12.0)
		stars.set_progress(completed, target, completed >= target)
		if completed >= target:
			_start_star_pulse(stars)
		center.add_child(stars)
		box.add_child(center)
	else:
		var progress := _muted_label("%s" % completed)
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(progress)
	return box


func _progress_stars(progress: int, target: int) -> String:
	var total := maxi(1, target)
	var filled := clampi(progress, 0, total)
	return "%s/%s" % [filled, total]


func _cook_progress_name(participant: Dictionary) -> String:
	var name := _participant_display_name(participant)
	var target := int(_snapshot.get("targetDishCount", 0))
	if target <= 0:
		return name
	var completed := int(participant.get("dishCount", 0))
	return "%s %s" % [name, _progress_stars(completed, target)]


func _cook_label_is_complete(text: String) -> bool:
	var target := int(_snapshot.get("targetDishCount", 0))
	if target <= 0:
		return false
	return text.ends_with(_progress_stars(target, target))


func _apply_star_completion_style(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(0.38, 0.22, 0.04))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.74, 0.16, 0.9))
	label.add_theme_constant_override("outline_size", 2)


func _start_star_pulse(control: Control) -> Tween:
	control.modulate = Color(1.0, 0.92, 0.68, 1.0)
	var tween := control.create_tween()
	tween.set_loops()
	tween.tween_property(control, "modulate", Color(1.0, 0.72, 0.18, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "modulate", Color(1.0, 0.98, 0.78, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _food_summary_cell(text: String) -> Label:
	var label := _dish_summary_cell(text)
	label.custom_minimum_size = Vector2(112, 52)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _complete_summary_cell(text: String) -> Label:
	var label := _dish_summary_cell(text)
	label.custom_minimum_size = Vector2(170, 34)
	label.add_theme_font_size_override("font_size", 11)
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
		var card_count := int(group.get("count", 0))
		var meta := _card_meta_with_stack(VisualAssets.ingredient_meta(ingredient_id), card_count)
		var has_stock := _voucher_group_has_stock(group)
		var label := _counted_ingredient_card_label(ingredient_id, card_count)
		if not has_stock:
			label += "\nNo stock"
		var button := _visual_card("", label, meta, HAND_CARD_SIZE, func(g := group) -> void:
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
		var button := _plain_asset_item(label, meta, HAND_FOOD_SIZE, func(g := group) -> void:
			_on_inventory_food_group_pressed(g)
		)
		button.tooltip_text = _dish_piece_tooltip(group)
		_connect_food_piece_info_double_tap(button, group, "hand")
		button.name = "HandFood_%s" % str(group.get("dishId", "dish"))
		if _selected_inventory_asset_key == "dish_part:%s" % str(group.get("partId", "")):
			_apply_plain_item_highlight(button, Color(0.08, 0.28, 0.60), 2)
		_hand_row.add_child(button)
	debug_stats["handGroupCount"] = count
	if _hand_row.get_child_count() == 0:
		_hand_row.add_child(_row_message("No cards in hand."))
	_hand_row.columns = 6
	if is_instance_valid(_hand_scroll):
		_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		debug_stats["handScrollVerticalMode"] = _hand_scroll.vertical_scroll_mode
	debug_stats["handGridColumns"] = _hand_row.columns


func _record_layout_debug() -> void:
	var preferred := _layout_minimum_size()
	var combined := get_combined_minimum_size()
	debug_stats["layoutMode"] = _layout_mode
	debug_stats["preferredVisualSize"] = preferred_visual_size()
	debug_stats["activePreferredVisualSize"] = preferred
	debug_stats["preferredLandscapeSize"] = TABLE_LANDSCAPE_SIZE
	debug_stats["combinedMinimumSize"] = combined
	debug_stats["combinedMinimumOverflowY"] = maxf(0.0, combined.y - preferred.y)
	var direct_child_minimums: Array = []
	for child in get_children():
		if child is Control:
			var control := child as Control
			direct_child_minimums.append("%s:%s:%s" % [control.name, control.visible, control.get_combined_minimum_size()])
	debug_stats["directChildMinimums"] = direct_child_minimums
	var root_child_minimums: Array = []
	if is_instance_valid(_root):
		for child in _root.get_children():
			if child is Control:
				var control := child as Control
				root_child_minimums.append("%s:%s:%s" % [control.name, control.visible, control.get_combined_minimum_size()])
	debug_stats["rootChildMinimums"] = root_child_minimums
	var middle_child_minimums: Array = []
	var middle := find_child("MiddleRow", true, false)
	if middle is Control:
		for child in middle.get_children():
			if child is Control:
				var control := child as Control
				middle_child_minimums.append("%s:%s:%s" % [control.name, control.visible, control.get_combined_minimum_size()])
	debug_stats["middleChildMinimums"] = middle_child_minimums
	var action_child_minimums: Array = []
	var action_panel := find_child("ActionPanel", true, false)
	if action_panel is Control:
		for child in action_panel.get_children():
			if child is Control:
				var control := child as Control
				action_child_minimums.append("%s:%s:%s" % [control.name, control.visible, control.get_combined_minimum_size()])
				for grandchild in control.get_children():
					if grandchild is Control:
						var grand_control := grandchild as Control
						action_child_minimums.append("  %s:%s:%s" % [grand_control.name, grand_control.visible, grand_control.get_combined_minimum_size()])
	debug_stats["actionChildMinimums"] = action_child_minimums
	if is_instance_valid(_hand_scroll):
		debug_stats["handScrollMinimumSize"] = _hand_scroll.get_combined_minimum_size()
	if is_instance_valid(_hand_row):
		debug_stats["handRowMinimumSize"] = _hand_row.get_combined_minimum_size()


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
		if _should_queue_basket_swap_click("playing"):
			_queue_basket_swap_request({"phase": "playing", "kind": "voucher", "ingredientId": take_ingredient_id})
			return
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
		if _should_queue_basket_swap_click("settlement"):
			_queue_basket_swap_request({"phase": "settlement", "kind": "voucher", "ingredientId": take_ingredient_id})
			return
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
	if _should_queue_basket_swap_click(phase):
		_queue_basket_swap_request({"phase": phase, "kind": "dish_part", "dishId": str(group.get("dishId", ""))})
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
	_clear_basket_swap_queue()
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
	_emit_basket_swap_intent({"type": "platter_swap_ingredient", "giveIngredientId": _selected_hand_ingredient_id, "takeIngredientId": take_ingredient_id})
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
		status_requested.emit(_dish_piece_tooltip(group))


func _take_bite_action() -> void:
	status_requested.emit("Food is shared automatically.")


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
	var give_ref := _aggregate_asset_ref_from_key(_selected_inventory_asset_key)
	var take_ref := _aggregate_asset_ref_from_key(_selected_platter_asset_key)
	if give_ref.is_empty() or take_ref.is_empty():
		status_requested.emit("The basket changed. Choose again.")
		_clear_selections()
		render(_snapshot)
		return
	_emit_basket_swap_intent({
		"type": "platter_asset_swap_aggregate",
		"give": give_ref,
		"take": take_ref
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
	var phase := str(_snapshot.get("phase", ""))
	if participant_id != _viewer_id() \
			and _offer_phase_allows_creation(phase) \
			and _can_act_now(phase) \
			and _participant_can_receive_offer(_participant_by_id(participant_id)):
		if _selected_inventory_asset_key == "":
			var target_ingredient_id := str(_participant_by_id(participant_id).get("ingredientId", ""))
			_auto_select_give_asset(target_ingredient_id, phase)
		if _selected_inventory_asset_key != "":
			_open_create_offer_popup(participant_id)
			return
	_open_cook_info_popup(participant_id)


func _create_offer_to_participant(participant_id: String, requested_asset_override: Dictionary = {}, quantity := 1) -> void:
	var phase := str(_snapshot.get("phase", ""))
	if not _offer_phase_allows_creation(phase) or not _can_act_now(phase):
		status_requested.emit("This is not your turn.")
		return
	var target := _participant_by_id(participant_id)
	if target.is_empty() or not _participant_can_receive_offer(target):
		status_requested.emit("That player cannot receive an offer right now.")
		return
	var requested_asset := requested_asset_override.duplicate(true) if not requested_asset_override.is_empty() else _offer_requested_asset_for_participant(participant_id)
	var offer_quantity := clampi(quantity, 1, 2)
	if offer_quantity > 1 and not _offer_can_use_quantity(participant_id, requested_asset, offer_quantity):
		offer_quantity = 1
	if not requested_asset.is_empty():
		requested_asset["quantity"] = offer_quantity
	if requested_asset.is_empty() or _selected_inventory_asset_key == "":
		status_requested.emit("Choose different items for the offer.")
		return
	var offered_asset_refs := _asset_refs_from_selected_key(offer_quantity)
	if offered_asset_refs.size() < offer_quantity:
		status_requested.emit("You do not have enough to offer %s:%s." % [offer_quantity, offer_quantity])
		return
	intent_requested.emit({
		"type": "create_offer",
		"toParticipantId": participant_id,
		"offeredAssets": offered_asset_refs,
		"requestedAsset": requested_asset
	})
	status_requested.emit("Offering %s to %s for %s." % [
		_asset_label_from_key(_selected_inventory_asset_key, offer_quantity),
		_participant_name(participant_id),
		_offer_requested_asset_label(requested_asset, participant_id)
	])
	_clear_selections()


func _open_create_offer_popup(participant_id: String, requested_asset_override: Dictionary = {}, quantity := 1) -> void:
	_clear(_offer_popup_list)
	_prepare_offer_popup_content(276)
	var target := _participant_by_id(participant_id)
	if target.is_empty() or not _participant_can_receive_offer(target):
		_offer_popup_list.add_child(_offer_popup_header("Offer"))
		var unavailable := _offer_popup_text("That player cannot receive an offer right now.")
		_offer_popup_list.add_child(unavailable)
		_popup_centered_tight(228, 120)
		return
	var requested_asset := requested_asset_override.duplicate(true) if not requested_asset_override.is_empty() else _offer_requested_asset_for_participant(participant_id)
	_create_offer_quantity = clampi(quantity, 1, 2)
	var can_double := _offer_can_use_quantity(participant_id, requested_asset, 2)
	if _create_offer_quantity > 1 and not can_double:
		_create_offer_quantity = 1
	if not requested_asset.is_empty():
		requested_asset["quantity"] = _create_offer_quantity
	var row := _offer_popup_button_row()
	var quantity_toggle: Button = null
	if can_double:
		var toggle_label := "2:2" if _create_offer_quantity == 2 else "1:1"
		var next_offer_quantity := 1 if _create_offer_quantity == 2 else 2
		quantity_toggle = _offer_quantity_toggle_button(toggle_label, func(id := participant_id, request := requested_asset.duplicate(true), next_quantity := next_offer_quantity) -> void:
			_open_create_offer_popup(id, request, next_quantity)
		)
	var create_button := _offer_popup_compact_button("Create", func(id := participant_id, request := requested_asset.duplicate(true), offer_quantity := _create_offer_quantity) -> void:
		_create_offer_to_participant(id, request, offer_quantity)
		_offer_popup.hide()
	)
	create_button.disabled = not _offer_can_use_quantity(participant_id, requested_asset, _create_offer_quantity)
	row.add_child(create_button)
	row.add_child(_offer_popup_compact_button("Cancel", func() -> void:
		_offer_popup.hide()
	))
	if requested_asset.is_empty():
		_offer_popup_list.add_child(_offer_popup_text("Choose different items for the offer."))
	_offer_popup_list.add_child(_offer_popup_component_from_summaries(
		"Offer",
		participant_id,
		_offer_asset_summary_from_key(_selected_inventory_asset_key, _create_offer_quantity),
		_offer_summary_for_requested_asset({"requestedAsset": requested_asset}, participant_id),
		_offer_create_detail_text(participant_id, requested_asset),
		row,
		quantity_toggle
	))
	_popup_centered_tight(430, 620, true)


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
	_active_popup_kind = ""
	_offer_popup_list.custom_minimum_size = Vector2(maxi(200, width), 0)
	_offer_popup_list.add_theme_constant_override("separation", 6)


func _offer_popup_component(title_text: String, participant_id: String, give_ingredient_id: String, give_qty: int, get_ingredient_id: String, get_qty: int, detail_text: String, action_row: Control = null, card_pair_middle_control: Control = null) -> Control:
	return _offer_popup_component_from_summaries(
		title_text,
		participant_id,
		_offer_asset_summary_for_ingredient(give_ingredient_id, give_qty),
		_offer_asset_summary_for_ingredient(get_ingredient_id, get_qty),
		detail_text,
		action_row,
		card_pair_middle_control
	)


func _offer_popup_component_from_summaries(title_text: String, participant_id: String, give_summary: Dictionary, get_summary: Dictionary, detail_text: String, action_row: Control = null, card_pair_middle_control: Control = null) -> Control:
	var box := VBoxContainer.new()
	box.name = "OfferPanel"
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_offer_popup_header(title_text))
	if detail_text != "":
		box.add_child(_offer_popup_text(detail_text))
	box.add_child(_offer_card_pair_from_summaries(give_summary, get_summary, card_pair_middle_control))
	if action_row != null:
		box.add_child(action_row)
	box.add_child(_offer_recipe_context(participant_id))
	box.add_child(_offer_participant_hand_context(participant_id))
	return box


func _offer_selected_give_ingredient_id() -> String:
	if _selected_inventory_asset_key.begins_with("voucher:"):
		return _selected_hand_ingredient_id
	return ""


func _offer_card_pair(give_ingredient_id: String, give_qty: int, get_ingredient_id: String, get_qty: int) -> Control:
	return _offer_card_pair_from_summaries(
		_offer_asset_summary_for_ingredient(give_ingredient_id, give_qty),
		_offer_asset_summary_for_ingredient(get_ingredient_id, get_qty)
	)


func _offer_card_pair_from_summaries(give_summary: Dictionary, get_summary: Dictionary, middle_control: Control = null) -> Control:
	var center := CenterContainer.new()
	center.name = "OfferCardPair"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	row.add_child(_offer_asset_card("Give", give_summary, "OfferGiveCard"))
	var middle := VBoxContainer.new()
	middle.name = "OfferPairMiddle"
	middle.custom_minimum_size = Vector2(38, 88)
	middle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 3)
	var arrow := _offer_popup_text("<->")
	arrow.custom_minimum_size = Vector2(38, 20)
	middle.add_child(arrow)
	if middle_control != null:
		middle_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		middle_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		middle.add_child(middle_control)
	row.add_child(middle)
	row.add_child(_offer_asset_card("Get", get_summary, "OfferGetCard"))
	return center


func _offer_ingredient_card(title_text: String, ingredient_id: String, quantity: int, node_prefix: String) -> Control:
	return _offer_asset_card(title_text, _offer_asset_summary_for_ingredient(ingredient_id, quantity), node_prefix)


func _offer_asset_card(title_text: String, summary: Dictionary, node_prefix: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := _offer_popup_text(title_text)
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	box.add_child(_offer_asset_visual(summary, node_prefix, HAND_CARD_SIZE, Callable()))
	return box


func _offer_asset_visual(summary: Dictionary, node_prefix: String, minimum: Vector2, callback: Callable) -> Button:
	var meta: Dictionary = summary.get("meta", VisualAssets.dish_meta("Food piece", "piece"))
	var label := str(summary.get("label", "Food piece x1"))
	var card: Button
	if str(summary.get("kind", "")) == "dish_part":
		card = _plain_asset_item(label, meta, minimum, callback)
		card.set_meta("offer_asset_kind", "dish_part")
	else:
		card = _visual_card("", label, meta, minimum, callback)
		card.set_meta("offer_asset_kind", "voucher")
	card.name = "%s_%s" % [node_prefix, str(summary.get("key", "food_piece"))]
	card.tooltip_text = str(summary.get("tooltip", summary.get("sentenceLabel", label)))
	if not callback.is_valid():
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
	return card


func _offer_asset_summary_for_ingredient(ingredient_id: String, quantity: int) -> Dictionary:
	var qty := maxi(1, quantity)
	if ingredient_id == "":
		return _generic_food_piece_summary(qty)
	return {
		"kind": "voucher",
		"key": ingredient_id,
		"label": _counted_ingredient_card_label(ingredient_id, qty),
		"sentenceLabel": "%s x%s" % [_ingredient_display(ingredient_id), qty],
		"tooltip": "%s x%s" % [_ingredient_display(ingredient_id), qty],
		"meta": _card_meta_with_stack(VisualAssets.ingredient_meta(ingredient_id), qty),
		"quantity": qty
	}


func _generic_food_piece_summary(quantity: int) -> Dictionary:
	var qty := maxi(1, quantity)
	return {
		"kind": "dish_part",
		"key": "dish_piece",
		"label": "Dish piece x%s" % qty,
		"sentenceLabel": "Dish piece x%s" % qty,
		"tooltip": "Dish piece x%s" % qty,
		"meta": VisualAssets.dish_meta("Dish piece", "piece"),
		"quantity": qty
	}


func _offer_dish_part_summary_from_part(part: Dictionary, quantity: int) -> Dictionary:
	var qty := maxi(1, quantity)
	var dish_name := str(part.get("dishName", "Food")).strip_edges()
	if dish_name == "":
		dish_name = "Food"
	var unit := str(part.get("unitSingular" if qty == 1 else "unitPlural", "piece" if qty == 1 else "pieces")).strip_edges()
	if unit == "":
		unit = "piece" if qty == 1 else "pieces"
	var short_label := "%s %s x%s" % [VisualAssets.short_dish_name(dish_name), unit, qty]
	var full_label := "%s %s x%s" % [dish_name, unit, qty]
	var key := str(part.get("dishId", ""))
	if key == "":
		key = "food_piece"
	return {
		"kind": "dish_part",
		"key": key,
		"label": short_label,
		"sentenceLabel": full_label,
		"tooltip": _dish_piece_tooltip({
			"dishName": dish_name,
			"unitSingular": str(part.get("unitSingular", "piece")),
			"unitPlural": str(part.get("unitPlural", "pieces")),
			"makerParticipantId": str(part.get("makerParticipantId", "")),
			"count": qty
		}),
		"meta": VisualAssets.dish_meta(dish_name, unit),
		"quantity": qty
	}


func _offer_summary_for_requested_asset(offer: Dictionary, provider_participant_id: String) -> Dictionary:
	var requested_asset: Dictionary = offer.get("requestedAsset", {})
	if requested_asset.is_empty():
		var requested: Dictionary = offer.get("requested", {})
		return _offer_asset_summary_for_ingredient(str(requested.get("ingredientId", "")), int(requested.get("quantity", 1)))
	var quantity := int(requested_asset.get("quantity", 1))
	if str(requested_asset.get("kind", "")) == "voucher":
		return _offer_asset_summary_for_ingredient(str(requested_asset.get("ingredientId", "")), quantity)
	if str(requested_asset.get("kind", "")) == "dish_part":
		var group := _food_part_group_for_request(requested_asset, provider_participant_id)
		if not group.is_empty():
			return _offer_dish_part_summary_from_part({
				"dishId": str(group.get("dishId", "")),
				"dishName": str(group.get("dishName", "")),
				"unitSingular": str(group.get("unitSingular", "piece")),
				"unitPlural": str(group.get("unitPlural", "pieces")),
					"makerParticipantId": str(group.get("makerParticipantId", ""))
				}, quantity)
		if str(requested_asset.get("dishName", "")) != "":
			return _offer_dish_part_summary_from_part({
				"dishId": str(requested_asset.get("dishId", "")),
				"dishName": str(requested_asset.get("dishName", "")),
				"unitSingular": str(requested_asset.get("unitSingular", "piece")),
				"unitPlural": str(requested_asset.get("unitPlural", "pieces")),
				"makerParticipantId": str(requested_asset.get("makerParticipantId", ""))
			}, quantity)
		return _generic_food_piece_summary(quantity)
	return _generic_food_piece_summary(quantity)


func _offer_summary_for_offered_assets(offer: Dictionary) -> Dictionary:
	var offered_parts: Array = offer.get("offeredDishParts", [])
	if not offered_parts.is_empty():
		var first_part: Dictionary = offered_parts[0]
		return _offer_dish_part_summary_from_part(first_part, offered_parts.size())
	var offered_vouchers: Array = offer.get("offeredVouchers", [])
	if not offered_vouchers.is_empty():
		var first_voucher: Dictionary = offered_vouchers[0]
		return _offer_asset_summary_for_ingredient(str(first_voucher.get("ingredientId", "")), offered_vouchers.size())
	for raw_ref in offer.get("offeredAssets", []):
		var ref: Dictionary = raw_ref
		if str(ref.get("kind", "")) == "dish_part":
			var part := _dish_part_by_id(str(ref.get("id", "")))
			if not part.is_empty():
				return _offer_dish_part_summary_from_part(part, offer.get("offeredAssets", []).size())
		if str(ref.get("kind", "")) == "voucher":
			var ingredient_id := _ingredient_id_for_voucher(str(ref.get("id", "")))
			if ingredient_id != "":
				return _offer_asset_summary_for_ingredient(ingredient_id, offer.get("offeredAssets", []).size())
	return _generic_food_piece_summary(1)


func _food_part_group_for_request(requested_asset: Dictionary, provider_participant_id: String) -> Dictionary:
	var parts: Array = []
	if provider_participant_id == _viewer_id():
		parts = _snapshot.get("ownFoodParts", [])
	elif provider_participant_id == "platter":
		parts = _snapshot.get("platterFoodParts", [])
	else:
		for raw_group in _participant_by_id(provider_participant_id).get("heldFoodPartGroups", []):
			var participant_group: Dictionary = raw_group
			if _food_part_group_matches_request(participant_group, requested_asset):
				return participant_group
		return {}
	for raw_group in _food_part_group_options(parts):
		var group: Dictionary = raw_group
		if _food_part_group_matches_request(group, requested_asset):
			return group
	return {}


func _food_part_group_matches_request(group: Dictionary, requested_asset: Dictionary) -> bool:
	var requested_dish_id := str(requested_asset.get("dishId", ""))
	if requested_dish_id != "" and str(group.get("dishId", "")) != requested_dish_id:
		return false
	var requested_maker_id := str(requested_asset.get("makerParticipantId", ""))
	if requested_maker_id != "" and str(group.get("makerParticipantId", "")) != requested_maker_id:
		return false
	return true


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
		box.add_child(_offer_popup_text("Ready to cook on next turn."))
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
		var card := _offer_missing_ingredient_card(ingredient_id, quantity)
		card.name = "OfferMissing_%s" % ingredient_id
		grid.add_child(card)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(grid)
	box.add_child(center)
	return box


func _offer_participant_hand_context(participant_id: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "OfferHandContext_%s" % participant_id
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if participant_id == _viewer_id():
		return box
	var participant := _participant_by_id(participant_id)
	var voucher_groups: Array = participant.get("heldVoucherGroups", [])
	var food_groups: Array = participant.get("heldFoodPartGroups", [])
	box.add_child(_offer_popup_text("%s's hand" % _participant_name(participant_id)))
	if voucher_groups.is_empty() and food_groups.is_empty():
		box.add_child(_offer_popup_text("No cards or dish pieces visible."))
		return box
	var grid := GridContainer.new()
	grid.name = "OfferHandAssets"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for raw_group in voucher_groups:
		var group: Dictionary = raw_group
		if int(group.get("count", 0)) <= 0:
			continue
		grid.add_child(_offer_hand_voucher_card(participant_id, group))
	for raw_group in food_groups:
		var group: Dictionary = raw_group
		if int(group.get("count", 0)) <= 0:
			continue
		grid.add_child(_offer_hand_food_part_card(participant_id, group))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(grid)
	box.add_child(center)
	return box


func _offer_hand_voucher_card(participant_id: String, group: Dictionary) -> Button:
	var ingredient_id := str(group.get("ingredientId", ""))
	var owner_participant_id := str(group.get("ownerParticipantId", ""))
	var request := {
		"kind": "voucher",
		"ingredientId": ingredient_id,
		"ownerParticipantId": owner_participant_id,
		"quantity": 1
	}
	var summary := _offer_asset_summary_for_ingredient(ingredient_id, int(group.get("count", 1)))
	return _offer_hand_asset_card(
		"OfferHandVoucher_%s_%s" % [ingredient_id, owner_participant_id],
		summary,
		participant_id,
		request
	)


func _offer_hand_food_part_card(participant_id: String, group: Dictionary) -> Button:
	var request := {
		"kind": "dish_part",
		"quantity": 1,
		"dishId": str(group.get("dishId", "")),
		"dishName": str(group.get("dishName", "")),
		"unitSingular": str(group.get("unitSingular", "piece")),
		"unitPlural": str(group.get("unitPlural", "pieces")),
		"makerParticipantId": str(group.get("makerParticipantId", ""))
	}
	var summary := _offer_dish_part_summary_from_part(group, int(group.get("count", 1)))
	return _offer_hand_asset_card(
		"OfferHandFood_%s_%s" % [str(group.get("dishId", "")), str(group.get("makerParticipantId", ""))],
		summary,
		participant_id,
		request
	)


func _offer_hand_asset_card(node_name: String, summary: Dictionary, participant_id: String, requested_asset: Dictionary) -> Button:
	var card := _offer_asset_visual(summary, "OfferHandAsset", HAND_CARD_SIZE, func(id := participant_id, request := requested_asset.duplicate(true)) -> void:
		_open_create_offer_popup_for_requested_asset(id, request)
	)
	card.name = node_name
	card.tooltip_text = str(summary.get("tooltip", summary.get("sentenceLabel", summary.get("label", "Item x1"))))
	card.add_theme_font_size_override("font_size", 11)
	return card


func _open_create_offer_popup_for_requested_asset(participant_id: String, requested_asset: Dictionary) -> void:
	var phase := str(_snapshot.get("phase", ""))
	if participant_id == _viewer_id() or not _offer_phase_allows_creation(phase):
		return
	if not _can_act_now(phase):
		status_requested.emit("This is not your turn.")
		return
	var forbidden_ingredient_id := ""
	if str(requested_asset.get("kind", "")) == "voucher":
		forbidden_ingredient_id = str(requested_asset.get("ingredientId", ""))
	if _selected_inventory_asset_key == "":
		_auto_select_give_asset(forbidden_ingredient_id, phase)
	if _selected_inventory_asset_key == "":
		status_requested.emit("Choose something to give first.")
		return
	if _requested_asset_matches_selected_voucher_resource(requested_asset):
		status_requested.emit("Choose a different promise-card resource.")
		return
	_open_create_offer_popup(participant_id, requested_asset)


func _requested_asset_matches_selected_voucher_resource(requested_asset: Dictionary) -> bool:
	if str(requested_asset.get("kind", "")) != "voucher":
		return false
	return _selected_is_same_voucher_resource(
		str(requested_asset.get("ingredientId", "")),
		str(requested_asset.get("ownerParticipantId", ""))
	)


func _offer_missing_ingredient_card(ingredient_id: String, quantity: int) -> Control:
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = Vector2(88, 76)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	var style := _panel_style(Color(0.76, 0.76, 0.70), Color(0.46, 0.46, 0.42), 1, 7)
	style.content_margin_left = 3
	style.content_margin_top = 3
	style.content_margin_right = 3
	style.content_margin_bottom = 3
	wrapper.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(40, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.55, 0.55, 0.55, 0.72)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	var label := _label(_counted_ingredient_card_label(ingredient_id, quantity))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size = Vector2(76, 22)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.30, 0.30, 0.28))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	wrapper.add_child(box)
	return wrapper


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
		var give_summary := _offer_summary_for_offered_assets(offer)
		var get_summary := _offer_summary_for_requested_asset(offer, to_id)
		if to_id == _viewer_id():
			give_summary = _offer_summary_for_requested_asset(offer, _viewer_id())
			get_summary = _offer_summary_for_offered_assets(offer)
		_offer_popup_list.add_child(_offer_popup_component_from_summaries(
			"Offers with %s" % _participant_name(participant_id),
			participant_id,
			give_summary,
			get_summary,
			_offer_sentence(offer),
			action_row
		))
	if not added:
		var title := _offer_popup_header("Offers with %s" % _participant_name(participant_id))
		_offer_popup_list.add_child(title)
		var none_label := _offer_popup_text("No visible offers.")
		_offer_popup_list.add_child(none_label)
	if _selected_inventory_asset_key != "" and participant_id != _viewer_id() and _offer_phase_allows_creation(str(_snapshot.get("phase", ""))) and _participant_can_receive_offer(_participant_by_id(participant_id)):
		_offer_popup_list.add_child(_offer_popup_button("Create New Offer", func(id := participant_id) -> void:
			_offer_popup.hide()
			_open_create_offer_popup(id)
		))

	_popup_centered_tight(430, 620, true)


func _open_cook_info_popup(participant_id: String) -> void:
	_clear(_offer_popup_list)
	_prepare_offer_popup_content(292)
	_offer_popup_list.add_child(_offer_popup_header("%s's Kitchen" % _participant_name(participant_id)))
	_offer_popup_list.add_child(_offer_recipe_context(participant_id))
	_offer_popup_list.add_child(_offer_participant_hand_context(participant_id))
	if participant_id == _viewer_id():
		_offer_popup_list.add_child(_offer_popup_text("Your cards and dish pieces are shown in Promise Cards."))
	_popup_centered_tight(430, 620, true)


func _accept_offer(offer: Dictionary) -> void:
	var requested: Dictionary = offer.get("requestedAsset", {})
	if requested.is_empty():
		requested = {"kind": "voucher", "ingredientId": str(offer.get("requested", {}).get("ingredientId", "")), "quantity": int(offer.get("requested", {}).get("quantity", 1))}
	var quantity := int(requested.get("quantity", 1))
	if str(requested.get("kind", "")) == "dish_part":
		var matching_parts := _matching_own_food_part_refs(str(requested.get("dishId", "")), str(requested.get("makerParticipantId", "")), quantity)
		if matching_parts.size() < quantity:
			status_requested.emit("You do not have enough food pieces to accept.")
			return
		intent_requested.emit({"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "assets": matching_parts})
		return
	var ingredient_id := str(requested.get("ingredientId", ""))
	var matching := _matching_hand_voucher_ids(ingredient_id, quantity, str(requested.get("ownerParticipantId", "")))
	if matching.size() < quantity:
		status_requested.emit("You do not have enough %s to accept." % _ingredient_display(ingredient_id))
		return
	intent_requested.emit({"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "voucherIds": matching})


func _offer_requested_ingredient_id(offer: Dictionary) -> String:
	var requested_asset: Dictionary = offer.get("requestedAsset", {})
	if str(requested_asset.get("kind", "")) == "voucher":
		return str(requested_asset.get("ingredientId", ""))
	var requested: Dictionary = offer.get("requested", {})
	return str(requested.get("ingredientId", ""))


func _offer_requested_quantity(offer: Dictionary) -> int:
	var requested_asset: Dictionary = offer.get("requestedAsset", {})
	if not requested_asset.is_empty():
		return int(requested_asset.get("quantity", 1))
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
	var offered_parts: Array = offer.get("offeredDishParts", [])
	if not offered_parts.is_empty():
		return offered_parts.size()
	var offered: Array = offer.get("offeredVouchers", [])
	if not offered.is_empty():
		return offered.size()
	var assets: Array = offer.get("offeredAssets", [])
	if not assets.is_empty():
		return assets.size()
	var ids: Array = offer.get("offeredVoucherIds", [])
	return maxi(1, ids.size())


func _offer_sentence(offer: Dictionary) -> String:
	return "%s offers %s to %s for %s." % [
		_participant_name(str(offer.get("fromParticipantId", ""))),
		_offer_assets_label(offer),
		_participant_name(str(offer.get("toParticipantId", ""))),
		_offer_requested_label(offer)
	]


func _offer_assets_label(offer: Dictionary) -> String:
	var summary := _offer_summary_for_offered_assets(offer)
	var label := str(summary.get("sentenceLabel", summary.get("label", ""))).strip_edges()
	return "nothing" if label == "" else label


func _offer_requested_label(offer: Dictionary) -> String:
	var provider_id := str(offer.get("toParticipantId", ""))
	var summary := _offer_summary_for_requested_asset(offer, provider_id)
	return str(summary.get("sentenceLabel", summary.get("label", "Food piece x1")))


func _asset_label_from_ref(ref: Dictionary) -> String:
	if str(ref.get("kind", "")) == "voucher":
		var ingredient_id := _ingredient_id_for_voucher(str(ref.get("id", "")))
		return "%s x1" % (_ingredient_display(ingredient_id) if ingredient_id != "" else "Card")
	if str(ref.get("kind", "")) == "dish_part":
		var part := _dish_part_by_id(str(ref.get("id", "")))
		if not part.is_empty():
			return str(_offer_dish_part_summary_from_part(part, 1).get("sentenceLabel", "Food piece x1"))
		return "Food piece x1"
	return "Asset"


func _dish_name_for_request(requested: Dictionary) -> String:
	var dish_id := str(requested.get("dishId", ""))
	for raw_part in _snapshot.get("ownFoodParts", []) + _snapshot.get("platterFoodParts", []):
		var part: Dictionary = raw_part
		if str(part.get("dishId", "")) == dish_id:
			return str(_offer_dish_part_summary_from_part(part, int(requested.get("quantity", 1))).get("sentenceLabel", "Food piece x1"))
	return "Food piece"


func _dish_part_by_id(part_id: String) -> Dictionary:
	for raw_part in _snapshot.get("ownFoodParts", []) + _snapshot.get("platterFoodParts", []):
		var part: Dictionary = raw_part
		if str(part.get("id", "")) == part_id:
			return part
	return {}


func _offer_label(offer: Dictionary) -> Label:
	var text := "%s offers %s to %s for %s." % [
		_participant_name(str(offer.get("fromParticipantId", ""))),
		_offer_assets_label(offer),
		_participant_name(str(offer.get("toParticipantId", ""))),
		_offer_requested_label(offer)
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


func _clear_basket_swap_queue(clear_in_flight := true) -> void:
	_queued_basket_swap_requests.clear()
	if clear_in_flight:
		_clear_basket_swap_in_flight()
	debug_stats["basketSwapQueueSize"] = 0
	debug_stats["basketSwapInFlight"] = _basket_swap_intent_in_flight


func _clear_basket_swap_in_flight() -> void:
	_basket_swap_intent_in_flight = false
	_basket_swap_in_flight_snapshot_key = ""
	_basket_swap_in_flight_started_msec = 0
	debug_stats["basketSwapInFlight"] = false


func _sync_basket_swap_queue_for_snapshot(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> void:
	if current_snapshot.is_empty():
		_clear_basket_swap_queue()
		return
	if not previous_snapshot.is_empty():
		var context_changed := str(previous_snapshot.get("tableCode", "")) != str(current_snapshot.get("tableCode", ""))
		context_changed = context_changed or str(previous_snapshot.get("viewerParticipantId", "")) != str(current_snapshot.get("viewerParticipantId", ""))
		context_changed = context_changed or str(previous_snapshot.get("phase", "")) != str(current_snapshot.get("phase", ""))
		context_changed = context_changed or str(previous_snapshot.get("currentTurnParticipantId", "")) != str(current_snapshot.get("currentTurnParticipantId", ""))
		if context_changed:
			_clear_basket_swap_queue()
			return
	var materially_changed := not previous_snapshot.is_empty() and JSON.stringify(previous_snapshot) != JSON.stringify(current_snapshot)
	var final_snapshot_applied := materially_changed and not _visual_update_waiting()
	if _basket_swap_intent_in_flight and (_snapshot_identity_key(current_snapshot) != _basket_swap_in_flight_snapshot_key or final_snapshot_applied):
		_clear_basket_swap_in_flight()


func _emit_basket_swap_intent(intent: Dictionary) -> void:
	_basket_swap_intent_in_flight = true
	_basket_swap_in_flight_snapshot_key = _snapshot_identity_key(_snapshot)
	_basket_swap_in_flight_started_msec = Time.get_ticks_msec()
	debug_stats["basketSwapInFlight"] = true
	intent_requested.emit(intent)


func _queue_basket_swap_request(request: Dictionary) -> void:
	_queued_basket_swap_requests.append(request.duplicate(true))
	debug_stats["basketSwapQueueSize"] = _queued_basket_swap_requests.size()
	status_requested.emit("Queued basket swap.")


func _should_queue_basket_swap_click(phase: String) -> bool:
	if not _basket_swap_intent_in_flight and not _visual_update_waiting():
		return false
	return _can_act_now_without_visual_wait(phase)


func _process_queued_basket_swaps() -> void:
	if _queued_basket_swap_requests.is_empty():
		return
	if _visual_update_waiting():
		return
	if _basket_swap_intent_in_flight:
		if _basket_swap_in_flight_started_msec > 0 and Time.get_ticks_msec() - _basket_swap_in_flight_started_msec > BASKET_SWAP_QUEUE_TIMEOUT_MS:
			_clear_basket_swap_queue()
			status_requested.emit("Basket swap queue cleared.")
		return
	var phase := str(_snapshot.get("phase", ""))
	if not _can_act_now_without_visual_wait(phase):
		_clear_basket_swap_queue()
		return
	var request: Dictionary = _queued_basket_swap_requests[0]
	if str(request.get("phase", "")) != phase:
		_clear_basket_swap_queue()
		return
	if not _try_emit_queued_basket_swap(request):
		_clear_basket_swap_queue()
		status_requested.emit("Basket swap queue cleared.")
		return
	_queued_basket_swap_requests.pop_front()
	debug_stats["basketSwapQueueSize"] = _queued_basket_swap_requests.size()


func _try_emit_queued_basket_swap(request: Dictionary) -> bool:
	_clear_selections()
	var phase := str(request.get("phase", ""))
	var kind := str(request.get("kind", ""))
	if kind == "voucher":
		var take_ingredient_id := str(request.get("ingredientId", ""))
		var group := _voucher_group_for_ingredient(_snapshot.get("platter", []), take_ingredient_id)
		if group.is_empty():
			return false
		if not _auto_select_give_asset(take_ingredient_id, phase):
			return false
		_selected_platter_asset_key = "voucher:%s" % str(group.get("voucherId", ""))
		if _selected_inventory_asset_key.begins_with("voucher:") and _selected_hand_ingredient_id == take_ingredient_id:
			return false
	elif kind == "dish_part":
		var food_group := _platter_food_group_for_dish_id(str(request.get("dishId", "")))
		if food_group.is_empty():
			return false
		if not _auto_select_give_asset("", phase):
			return false
		_selected_platter_asset_key = "dish_part:%s" % str(food_group.get("partId", ""))
	else:
		return false
	var was_in_flight := _basket_swap_intent_in_flight
	if phase == "settlement":
		_try_settlement_swap()
	else:
		_swap_selected_playing_asset()
	return _basket_swap_intent_in_flight and not was_in_flight


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
	return str(viewer.get("role", "")) == "active" and str(viewer.get("kind", "human")) == "human" and _participant_opening_count(viewer) < OPENING_OFFERINGS_PER_PLAYER


func _can_act_now(phase: String) -> bool:
	if _visual_update_waiting():
		return false
	return _can_act_now_without_visual_wait(phase)


func _can_act_now_without_visual_wait(phase: String) -> bool:
	if bool(_snapshot.get("paused", false)):
		return false
	if _viewer_is_witness():
		return false
	var viewer := _participant_by_id(_viewer_id())
	if str(viewer.get("role", "")) != "active" or str(viewer.get("kind", "human")) != "human":
		return false
	if phase != "" and str(_snapshot.get("phase", "")) != phase:
		return false
	if phase == "deposit" or phase == "lobby" or phase == "eating" or phase == "complete":
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
	return str(participant.get("role", "")) == "active" and str(participant.get("ingredientId", "")) != ""


func _offer_phase_allows_creation(phase: String) -> bool:
	return phase == "playing" or phase == "settlement"


func _offer_requested_asset_for_participant(participant_id: String) -> Dictionary:
	var target := _participant_by_id(participant_id)
	if target.is_empty():
		return {}
	if _selected_voucher_owner_id() == participant_id and int(target.get("heldFoodPartCount", 0)) > 0:
		var food_group := _participant_food_part_group_for_offer(target)
		if food_group.is_empty():
			return {"kind": "dish_part", "quantity": 1}
		return {
			"kind": "dish_part",
			"quantity": 1,
			"dishId": str(food_group.get("dishId", "")),
			"dishName": str(food_group.get("dishName", "")),
			"unitSingular": str(food_group.get("unitSingular", "piece")),
			"unitPlural": str(food_group.get("unitPlural", "pieces")),
			"makerParticipantId": str(food_group.get("makerParticipantId", ""))
		}
	var requested_ingredient_id := str(target.get("ingredientId", ""))
	if requested_ingredient_id == "":
		return {}
	if _selected_is_same_voucher_resource(requested_ingredient_id, participant_id):
		return {}
	if int(target.get("offerableOwnIngredientQty", 0)) <= 0:
		return {}
	return {"kind": "voucher", "ingredientId": requested_ingredient_id, "ownerParticipantId": participant_id, "quantity": 1}


func _participant_food_part_group_for_offer(participant: Dictionary) -> Dictionary:
	for raw_group in participant.get("heldFoodPartGroups", []):
		var group: Dictionary = raw_group
		if int(group.get("count", 0)) > 0:
			return group
	return {}


func _selected_voucher_owner_id() -> String:
	if not _selected_inventory_asset_key.begins_with("voucher:"):
		return ""
	var voucher := _voucher_for_key(_selected_inventory_asset_key)
	return str(voucher.get("ownerParticipantId", ""))


func _selected_is_same_voucher_resource(ingredient_id: String, owner_participant_id: String) -> bool:
	if not _selected_inventory_asset_key.begins_with("voucher:"):
		return false
	var voucher := _voucher_for_key(_selected_inventory_asset_key)
	return (
		str(voucher.get("ingredientId", "")) == ingredient_id and
		str(voucher.get("ownerParticipantId", "")) == owner_participant_id
	)


func _voucher_for_key(key: String) -> Dictionary:
	if not key.begins_with("voucher:"):
		return {}
	var voucher_id := key.substr("voucher:".length())
	for raw_voucher in _snapshot.get("ownHand", []) + _snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("id", "")) == voucher_id:
			return voucher
	return {}


func _offer_requested_display_ingredient_id(requested_asset: Dictionary) -> String:
	if str(requested_asset.get("kind", "")) == "voucher":
		return str(requested_asset.get("ingredientId", ""))
	return ""


func _offer_requested_asset_label(requested_asset: Dictionary, provider_participant_id := "") -> String:
	if str(requested_asset.get("kind", "")) == "dish_part":
		var summary := _offer_summary_for_requested_asset({"requestedAsset": requested_asset}, provider_participant_id)
		var label := str(summary.get("sentenceLabel", summary.get("label", "dish piece"))).strip_edges()
		if label.ends_with(" x1"):
			label = label.substr(0, label.length() - 3)
		if label == "":
			label = "dish piece"
		return label
	if str(requested_asset.get("kind", "")) == "voucher":
		var quantity := maxi(1, int(requested_asset.get("quantity", 1)))
		var label := _ingredient_display(str(requested_asset.get("ingredientId", "")))
		return "%s x%s" % [label, quantity] if quantity > 1 else label
	return "something else"


func _offer_create_detail_text(participant_id: String, requested_asset: Dictionary) -> String:
	if str(requested_asset.get("kind", "")) == "dish_part":
		return "Redeem %s's card for %s" % [
			_participant_name(participant_id),
			_offer_requested_asset_label(requested_asset, participant_id)
		]
	return "with %s" % _participant_name(participant_id)


func _asset_ref_from_key(key: String) -> Dictionary:
	var separator := key.find(":")
	if separator <= 0:
		return {}
	return {"kind": key.substr(0, separator), "id": key.substr(separator + 1)}


func _aggregate_asset_ref_from_key(key: String) -> Dictionary:
	if key.begins_with("voucher:"):
		var voucher := _voucher_for_key(key)
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id == "":
			return {}
		return {
			"kind": "voucher",
			"ingredientId": ingredient_id
		}
	if key.begins_with("dish_part:"):
		var part := _dish_part_by_id(key.substr("dish_part:".length()))
		var dish_id := str(part.get("dishId", ""))
		if dish_id == "":
			return {}
		return {
			"kind": "dish_part",
			"dishId": dish_id
		}
	return {}


func _asset_refs_from_selected_key(quantity: int) -> Array:
	var refs: Array = []
	var qty := maxi(1, quantity)
	if _selected_inventory_asset_key.begins_with("voucher:"):
		var selected := _voucher_for_key(_selected_inventory_asset_key)
		if selected.is_empty():
			return refs
		var selected_ingredient_id := str(selected.get("ingredientId", ""))
		var selected_owner_id := str(selected.get("ownerParticipantId", ""))
		for raw_voucher in _snapshot.get("ownHand", []):
			var voucher: Dictionary = raw_voucher
			if str(voucher.get("ingredientId", "")) != selected_ingredient_id:
				continue
			if str(voucher.get("ownerParticipantId", "")) != selected_owner_id:
				continue
			if not _voucher_has_stock(voucher):
				continue
			refs.append({"kind": "voucher", "id": str(voucher.get("id", ""))})
			if refs.size() >= qty:
				return refs
	if _selected_inventory_asset_key.begins_with("dish_part:"):
		var selected_part := _dish_part_by_id(_selected_inventory_asset_key.substr("dish_part:".length()))
		if selected_part.is_empty():
			return refs
		var selected_dish_id := str(selected_part.get("dishId", ""))
		var selected_maker_id := str(selected_part.get("makerParticipantId", ""))
		for raw_part in _snapshot.get("ownFoodParts", []):
			var part: Dictionary = raw_part
			if str(part.get("dishId", "")) != selected_dish_id:
				continue
			if str(part.get("makerParticipantId", "")) != selected_maker_id:
				continue
			refs.append({"kind": "dish_part", "id": str(part.get("id", ""))})
			if refs.size() >= qty:
				return refs
	return refs


func _offer_can_use_quantity(participant_id: String, requested_asset: Dictionary, quantity: int) -> bool:
	var qty := maxi(1, quantity)
	if requested_asset.is_empty() or _selected_inventory_asset_key == "":
		return false
	if _asset_refs_from_selected_key(qty).size() < qty:
		return false
	if _requested_asset_available_count(participant_id, requested_asset) < qty:
		return false
	if _requested_asset_matches_selected_voucher_resource(requested_asset):
		return false
	return true


func _requested_asset_available_count(participant_id: String, requested_asset: Dictionary) -> int:
	var participant := _participant_by_id(participant_id)
	if participant.is_empty():
		return 0
	if str(requested_asset.get("kind", "")) == "voucher":
		var requested_ingredient_id := str(requested_asset.get("ingredientId", ""))
		var requested_owner_id := str(requested_asset.get("ownerParticipantId", ""))
		var total := 0
		for raw_group in participant.get("heldVoucherGroups", []):
			var group: Dictionary = raw_group
			if str(group.get("ingredientId", "")) != requested_ingredient_id:
				continue
			if requested_owner_id != "" and str(group.get("ownerParticipantId", "")) != requested_owner_id:
				continue
			total += int(group.get("count", 0))
		return total
	if str(requested_asset.get("kind", "")) == "dish_part":
		var food_total := 0
		for raw_group in participant.get("heldFoodPartGroups", []):
			var group: Dictionary = raw_group
			if _food_part_group_matches_request(group, requested_asset):
				food_total += int(group.get("count", 0))
		return food_total
	return 0


func _offer_asset_summary_from_key(key: String, quantity := 1) -> Dictionary:
	var qty := maxi(1, quantity)
	if key.begins_with("voucher:"):
		var voucher_id := key.substr("voucher:".length())
		var ingredient_id := _ingredient_id_for_voucher(voucher_id)
		if ingredient_id == "":
			ingredient_id = _ingredient_id_for_platter_voucher(voucher_id)
		return _offer_asset_summary_for_ingredient(ingredient_id, qty)
	if key.begins_with("dish_part:"):
		var part_id := key.substr("dish_part:".length())
		var part := _dish_part_by_id(part_id)
		if not part.is_empty():
			return _offer_dish_part_summary_from_part(part, qty)
		return _generic_food_piece_summary(qty)
	return _generic_food_piece_summary(qty)


func _asset_label_from_key(key: String, quantity := 1) -> String:
	var qty := maxi(1, quantity)
	if key == "":
		return ""
	if key.begins_with("voucher:"):
		var voucher_id := key.substr("voucher:".length())
		var ingredient_id := _ingredient_id_for_voucher(voucher_id)
		if ingredient_id == "":
			ingredient_id = _ingredient_id_for_platter_voucher(voucher_id)
		var label := _ingredient_display(ingredient_id) if ingredient_id != "" else "Card"
		return "%s x%s" % [label, qty] if qty > 1 else label
	if key.begins_with("dish_part:"):
		var part_id := key.substr("dish_part:".length())
		for raw_part in _snapshot.get("ownFoodParts", []) + _snapshot.get("platterFoodParts", []):
			var part: Dictionary = raw_part
			if str(part.get("id", "")) == part_id:
				return str(_offer_dish_part_summary_from_part(part, qty).get("sentenceLabel", "Food piece x%s" % qty))
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


func visual_update_waiting() -> bool:
	return _visual_update_waiting()


func current_visual_turn_id() -> String:
	return str(debug_stats.get("currentTurnParticipantId", str(_snapshot.get("currentTurnParticipantId", ""))))


func pending_visual_debug_state() -> Dictionary:
	var latest_pending := _latest_pending_visual_snapshot()
	return {
		"animationRunning": _animation_running,
		"queueSize": _animation_queue.size(),
		"hasPending": _has_pending_visual_snapshot,
		"pendingCount": _pending_visual_snapshots.size(),
		"snapshotTurn": str(_snapshot.get("currentTurnParticipantId", "")),
		"pendingTurn": str(_pending_visual_snapshot.get("currentTurnParticipantId", "")),
		"latestPendingTurn": str(latest_pending.get("currentTurnParticipantId", "")),
		"pendingViewer": str(_pending_visual_snapshot.get("viewerParticipantId", "")),
		"pendingCompactions": _pending_visual_compaction_count,
		"queueEstimatedSeconds": _animation_queue_estimated_seconds(),
		"animationQueueCompactions": _animation_queue_compaction_count,
		"visualTurnLagMs": _visual_turn_lag_elapsed_msec(),
		"lastVisualTurnLagFlush": _last_visual_turn_lag_flush
	}


func _flush_stale_visual_turn_if_needed() -> void:
	if not _visual_update_waiting():
		_reset_visual_turn_lag_watch()
		return
	if _animation_running or not _animation_queue.is_empty():
		_reset_visual_turn_lag_watch()
		return
	var pending_snapshot := _latest_pending_visual_snapshot()
	if pending_snapshot.is_empty():
		_reset_visual_turn_lag_watch()
		return
	var visual_turn := current_visual_turn_id()
	var pending_turn := str(pending_snapshot.get("currentTurnParticipantId", ""))
	if visual_turn == "" or pending_turn == "" or visual_turn == pending_turn:
		_reset_visual_turn_lag_watch()
		return
	var key := "%s:%s:%s" % [
		str(_snapshot.get("tableCode", "")),
		str(pending_snapshot.get("phase", "")),
		pending_turn
	]
	if _visual_turn_lag_key != key:
		_visual_turn_lag_key = key
		_visual_turn_lag_started_msec = Time.get_ticks_msec()
		return
	if _visual_turn_lag_elapsed_msec() < VISUAL_TURN_LAG_FLUSH_MS:
		return
	_last_visual_turn_lag_flush = key
	_flush_visual_updates()


func _latest_pending_visual_snapshot() -> Dictionary:
	if not _pending_visual_snapshots.is_empty():
		return (_pending_visual_snapshots[_pending_visual_snapshots.size() - 1] as Dictionary).duplicate(true)
	if _has_pending_visual_snapshot:
		return _pending_visual_snapshot.duplicate(true)
	return {}


func _visual_turn_lag_elapsed_msec() -> int:
	if _visual_turn_lag_started_msec <= 0:
		return 0
	return maxi(0, Time.get_ticks_msec() - _visual_turn_lag_started_msec)


func _reset_visual_turn_lag_watch() -> void:
	_visual_turn_lag_started_msec = 0
	_visual_turn_lag_key = ""


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
	_compact_animation_queue_if_needed()
	call_deferred("_play_next_animation_after_layout")


func _request_animation_start() -> void:
	if _animation_queue.is_empty() or _animation_running:
		return
	var next_event: Dictionary = _animation_queue[0]
	if _animation_event_can_start_immediately(next_event):
		_play_next_animation()
	else:
		call_deferred("_play_next_animation")


func _animation_event_can_start_immediately(event: Dictionary) -> bool:
	var event_type := str(event.get("type", ""))
	if not ["redeem", "prepare", "eat"].has(event_type):
		return false
	return _animation_actor_id(event) == _viewer_id()


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
			participant["openingOfferingsCount"] = 0
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
	return "%s:%s:%s:%s:%s:%s:%s" % [
		str(snapshot.get("tableCode", "")),
		str(snapshot.get("viewerParticipantId", "")),
		str(snapshot.get("version", "")),
		str(snapshot.get("turn", "")),
		str(snapshot.get("phase", "")),
		str(snapshot.get("currentTurnParticipantId", "")),
		str(snapshot.get("transactionCursor", snapshot.get("transactionHistoryTotal", snapshot.get("transactionTotal", ""))))
	]


func _snapshot_viewer_changed(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> bool:
	if previous_snapshot.is_empty() or current_snapshot.is_empty():
		return false
	if str(previous_snapshot.get("tableCode", "")) == "" or str(previous_snapshot.get("tableCode", "")) != str(current_snapshot.get("tableCode", "")):
		return false
	return str(previous_snapshot.get("viewerParticipantId", "")) != str(current_snapshot.get("viewerParticipantId", ""))


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


func _events_are_turn_only(events: Array) -> bool:
	if events.is_empty():
		return false
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) != "turn":
			return false
	return true


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
		"public_prepare":
			return _transaction_order_by_action(rows, ["Prepare"], str(event.get("participantId", "")), "")
		"eat":
			return _transaction_order_by_action(rows, ["Share", "Eat", "Bite"], str(event.get("participantId", _viewer_id())), "")
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
	var orbit_items := _shared_food_orbit_items.duplicate(true)
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
			var take_end := _future_inventory_target_center(milestone, working)
			if take_end != Vector2.INF:
				milestone["takeEndPoint"] = take_end
		elif event_type == "turn":
			working = _snapshot_after_turn_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "prepare" or event_type == "public_prepare":
			working = _snapshot_after_prepare_step(working, current_snapshot, event)
			milestone["_snapshotAfter"] = working.duplicate(true)
		elif event_type == "eat":
			var bundle_item := _complete_orbit_item_for_eat_event(event)
			if not bundle_item.is_empty():
				var reveal_index := orbit_items.size()
				var orbit_phase := _complete_orbit_phase_for_eat_event(event, reveal_index)
				bundle_item["orbitPhase"] = orbit_phase
				orbit_items.append(bundle_item)
				milestone["completeOrbit"] = true
				milestone["completeOrbitItems"] = orbit_items.duplicate(true)
				milestone["completeOrbitIndex"] = reveal_index
				milestone["completeOrbitPhase"] = orbit_phase
				milestone["completeOrbitTotal"] = orbit_items.size()
				milestone["completeOrbitRevealCount"] = orbit_items.size()
			working = _snapshot_after_eat_step(working, current_snapshot, event)
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
	if not _step_recipe_redeemed_count_toward_final(next, final_snapshot, ingredient_id):
		_step_recipe_redeemed_count_for_event(next, ingredient_id, int(event.get("slotIndex", -1)))
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


func _snapshot_after_prepare_step(working_snapshot: Dictionary, final_snapshot: Dictionary, _event: Dictionary) -> Dictionary:
	var next := final_snapshot.duplicate(true)
	if working_snapshot.has("currentTurnParticipantId"):
		next["currentTurnParticipantId"] = str(working_snapshot.get("currentTurnParticipantId", ""))
	return next


func _snapshot_after_eat_step(working_snapshot: Dictionary, final_snapshot: Dictionary, event: Dictionary) -> Dictionary:
	var next := working_snapshot.duplicate(true)
	_copy_transaction_state(next, final_snapshot)
	var participant_id := str(event.get("participantId", ""))
	var quantity := maxi(1, int(event.get("quantity", 1)))
	for _index in range(quantity):
		if participant_id == "" or participant_id == _viewer_id():
			_step_own_food_part_count_toward_final(next, final_snapshot, str(event.get("dishName", "")))
		else:
			_step_participant_food_part_count_toward_final(next, final_snapshot, participant_id, str(event.get("dishId", "")), str(event.get("dishName", "")))
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
		var current_count := _participant_opening_count(participant)
		var final_count := _participant_opening_count(final_participant)
		if current_count < final_count:
			current_count += 1
		elif current_count > final_count:
			current_count -= 1
		participant["openingOfferingsCount"] = current_count
		participant["depositedInitial"] = current_count >= OPENING_OFFERINGS_PER_PLAYER if final_count >= OPENING_OFFERINGS_PER_PLAYER else bool(final_participant.get("depositedInitial", participant.get("depositedInitial", false)))
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


func _step_participant_food_part_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, participant_id: String, dish_id: String, dish_name: String) -> void:
	if participant_id == "":
		return
	var final_participant := _participant_from_snapshot(final_snapshot, participant_id)
	var participants: Array = snapshot.get("participants", [])
	for index in range(participants.size()):
		var participant: Dictionary = participants[index]
		if str(participant.get("id", "")) != participant_id:
			continue
		if participant.has("heldFoodPartCount") and not final_participant.is_empty() and final_participant.has("heldFoodPartCount"):
			var current_total := int(participant.get("heldFoodPartCount", 0))
			var final_total := int(final_participant.get("heldFoodPartCount", current_total))
			if current_total > final_total:
				participant["heldFoodPartCount"] = current_total - 1
		var groups: Array = participant.get("heldFoodPartGroups", [])
		var final_groups := _food_group_counts(final_participant.get("heldFoodPartGroups", []) if not final_participant.is_empty() else [])
		for group_index in range(groups.size()):
			var group: Dictionary = groups[group_index]
			var group_dish_id := str(group.get("dishId", ""))
			var matches := (dish_id != "" and group_dish_id == dish_id) \
				or (dish_id == "" and str(group.get("dishName", "")) == dish_name)
			if not matches:
				continue
			var final_key := group_dish_id if group_dish_id != "" else "%s:%s" % [str(group.get("makerParticipantId", "")), str(group.get("dishName", ""))]
			var final_count := 0
			if final_groups.has(final_key):
				var final_group: Dictionary = final_groups[final_key]
				final_count = int(final_group.get("count", 0))
			var current_count := int(group.get("count", 0))
			if current_count <= final_count:
				break
			current_count -= 1
			if current_count <= 0:
				groups.remove_at(group_index)
			else:
				group["count"] = current_count
				groups[group_index] = group
			participant["heldFoodPartGroups"] = groups
			break
		participants[index] = participant
		snapshot["participants"] = participants
		return


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


func _step_recipe_redeemed_count_toward_final(snapshot: Dictionary, final_snapshot: Dictionary, ingredient_id: String) -> bool:
	if not snapshot.has("ownRecipe") or not final_snapshot.has("ownRecipe"):
		return false
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
			return true
	return false


func _step_recipe_redeemed_count_for_event(snapshot: Dictionary, ingredient_id: String, slot_index: int) -> bool:
	if not snapshot.has("ownRecipe"):
		return false
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var requirements: Array = recipe.get("requirements", [])
	var first_matching_index := -1
	var slot_cursor := 0
	for index in range(requirements.size()):
		var requirement: Dictionary = requirements[index]
		var required_qty := int(requirement.get("requiredQty", 0))
		if str(requirement.get("ingredientId", "")) != ingredient_id:
			slot_cursor += required_qty
			continue
		var redeemed_qty := int(requirement.get("redeemedQty", 0))
		if redeemed_qty >= required_qty:
			slot_cursor += required_qty
			continue
		if first_matching_index < 0:
			first_matching_index = index
		if slot_index >= slot_cursor and slot_index < slot_cursor + required_qty:
			requirement["redeemedQty"] = redeemed_qty + 1
			requirements[index] = requirement
			recipe["requirements"] = requirements
			snapshot["ownRecipe"] = recipe
			return true
		slot_cursor += required_qty
	if first_matching_index >= 0:
		var requirement: Dictionary = requirements[first_matching_index]
		requirement["redeemedQty"] = int(requirement.get("redeemedQty", 0)) + 1
		requirements[first_matching_index] = requirement
		recipe["requirements"] = requirements
		snapshot["ownRecipe"] = recipe
		return true
	return false


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
		var summary := event.duplicate(true)
		if summary.has("completeOrbitItems"):
			var orbit_items: Array = summary.get("completeOrbitItems", [])
			summary["completeOrbitItemCount"] = orbit_items.size()
			summary.erase("completeOrbitItems")
		event_summaries.append(summary)
		if str(event.get("type", "")) == "deposit":
			deposit_slots.append(int(event.get("basketSlotIndex", -1)))
	debug_stats["animationEventCount"] = events.size()
	debug_stats["lastAnimationTypes"] = _last_animation_types.duplicate()
	debug_stats["lastAnimationEvents"] = event_summaries
	debug_stats["lastDepositBasketSlots"] = deposit_slots
	debug_stats["animationQueueEstimatedSeconds"] = _animation_queue_estimated_seconds()
	debug_stats["animationQueueCompactions"] = _animation_queue_compaction_count


func _compact_animation_queue_if_needed() -> void:
	var estimated := _animation_queue_estimated_seconds()
	debug_stats["animationQueueEstimatedSeconds"] = estimated
	debug_stats["animationQueueCompactions"] = _animation_queue_compaction_count
	if estimated <= MAX_ANIMATION_QUEUE_ESTIMATED_SECONDS:
		return
	var compacted: Array = []
	var removed := 0
	for raw_event in _animation_queue:
		var event: Dictionary = raw_event
		if _should_preserve_queued_animation_event(event):
			compacted.append(event)
		else:
			removed += 1
	if removed <= 0:
		return
	_animation_queue = compacted
	_animation_queue_compaction_count += 1
	debug_stats["animationQueueEstimatedSeconds"] = _animation_queue_estimated_seconds()
	debug_stats["animationQueueCompactions"] = _animation_queue_compaction_count
	debug_stats["animationQueueCompactedEvents"] = removed


func _should_preserve_queued_animation_event(event: Dictionary) -> bool:
	if _event_involves_viewer(event):
		return true
	match str(event.get("type", "")):
		"prepare", "public_prepare", "complete", "turn":
			return true
		_:
			return false


func _animation_queue_estimated_seconds() -> float:
	var total := 0.0
	if _animation_running and _animation_deadline_msec > 0:
		total += maxf(0.0, float(_animation_deadline_msec - Time.get_ticks_msec()) / 1000.0)
	for raw_event in _animation_queue:
		var event: Dictionary = raw_event
		total += _estimated_animation_event_seconds(event)
	return snappedf(total, 0.01)


func _estimated_animation_event_seconds(event: Dictionary) -> float:
	var speed_scale := _animation_speed_scale(event)
	match str(event.get("type", "")):
		"deposit":
			return CARD_TILE_LANDING_SECONDS
		"swap", "settlement_swap":
			return _swap_finish_seconds(speed_scale)
		"exchange":
			return _swap_finish_seconds(speed_scale)
		"redeem", "public_redeem":
			return _redeem_finish_seconds(speed_scale)
		"prepare":
			return 2.20
		"public_prepare":
			return 1.72
		"offer":
			return 0.36
		"eat":
			return COMPLETE_ORBIT_LAUNCH_EVENT_SECONDS if bool(event.get("completeOrbit", false)) else CARD_TILE_LANDING_SECONDS
		"turn":
			return 0.36
		"complete":
			return 0.85
		_:
			return 0.0


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
	_compact_animation_queue_if_needed()
	_request_animation_start()


func _detect_deposit_events(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events_by_participant := {}
	var previous_by_id := _participant_map(previous_snapshot)
	var deposit_sequence := _deposit_participant_sequence_from_transactions(current_snapshot)
	var deposit_order := _deposit_participant_order_from_transactions(current_snapshot)
	var fallback_rank := 0
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if participant_id == "" or not previous_by_id.has(participant_id):
			continue
		var previous: Dictionary = previous_by_id[participant_id]
		var previous_count := _participant_opening_count(previous)
		var current_count := _participant_opening_count(participant)
		var added_count := maxi(0, current_count - previous_count)
		if added_count <= 0:
			continue
		var ingredient_id := str(participant.get("ingredientId", ""))
		var slot_index := _basket_slot_index_for_deposit_participant(participant_id, deposit_order, fallback_rank)
		fallback_rank += 1
		var participant_events: Array = []
		for offset in range(added_count):
			participant_events.append({
				"type": "deposit",
				"ingredientId": ingredient_id,
				"participantId": participant_id,
				"basketSlotIndex": slot_index,
				"depositNumber": previous_count + offset + 1
			})
		events_by_participant[participant_id] = participant_events
	var events: Array = []
	for participant_id in deposit_sequence:
		if not events_by_participant.has(participant_id):
			continue
		var ordered_events: Array = events_by_participant[participant_id]
		if ordered_events.is_empty():
			events_by_participant.erase(participant_id)
			continue
		events.append(ordered_events.pop_front())
		if ordered_events.is_empty():
			events_by_participant.erase(participant_id)
		else:
			events_by_participant[participant_id] = ordered_events
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if events_by_participant.has(participant_id):
			var remaining_events: Array = events_by_participant[participant_id]
			while not remaining_events.is_empty():
				events.append(remaining_events.pop_front())
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
	var cleaned_label := _label_without_quantity_suffix(label)
	var normalized := cleaned_label.to_lower()
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
				"dishName": cleaned_label.substr(0, cleaned_label.length() - suffix.length()).strip_edges(),
				"unitSingular": unit
			}
	return {}


func _label_without_quantity_suffix(label: String) -> String:
	var trimmed := label.strip_edges()
	var marker := trimmed.to_lower().rfind(" x")
	if marker < 0:
		return trimmed
	var suffix := trimmed.substr(marker + 2).strip_edges()
	if not _is_ascii_digits(suffix):
		return trimmed
	return trimmed.substr(0, marker).strip_edges()


func _is_ascii_digits(value: String) -> bool:
	if value == "":
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


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


func _swap_event_with_points(event: Dictionary, previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Dictionary:
	var enriched := event.duplicate(true)
	if not enriched.has("actorParticipantId"):
		enriched["actorParticipantId"] = _viewer_id()
	var visible_snapshot := _snapshot
	_snapshot = previous_snapshot
	enriched["giveStartPoint"] = _swap_give_start_center(enriched)
	enriched["takeStartPoint"] = _swap_take_start_center(enriched)
	_snapshot = current_snapshot
	enriched["giveEndPoint"] = _swap_give_end_center(enriched)
	enriched["takeEndPoint"] = _swap_take_end_center(enriched)
	_snapshot = visible_snapshot
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
	if _recipe_id(previous_snapshot.get("ownRecipe", {})) != _recipe_id(current_snapshot.get("ownRecipe", {})):
		var transaction_events := _viewer_redeem_events_from_transactions(previous_snapshot, current_snapshot)
		if transaction_events.size() > events.size():
			events = transaction_events
	var public_redeems := _public_redeem_events_from_transactions(previous_snapshot, current_snapshot)
	events.append_array(public_redeems)
	return events


func _viewer_redeem_events_from_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var viewer_id := _viewer_id()
	if viewer_id == "":
		return events
	var working_recipe: Dictionary = previous_snapshot.get("ownRecipe", {}).duplicate(true)
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Redeem" or str(transaction.get("participantId", "")) != viewer_id:
			continue
		var ingredient_id := _ingredient_id_from_label(str(transaction.get("itemOut", "")))
		if ingredient_id == "":
			continue
		var slot_index := _first_unredeemed_recipe_slot_index(working_recipe, ingredient_id)
		if slot_index < 0:
			continue
		var owner_id := str(transaction.get("counterpartyParticipantId", ""))
		if owner_id == "":
			owner_id = _participant_id_for_ingredient_in_snapshot(previous_snapshot, ingredient_id)
		var event := {
			"type": "redeem",
			"ingredientId": ingredient_id,
			"ownerParticipantId": owner_id,
			"slotIndex": slot_index,
			"_transactionId": str(transaction.get("id", ""))
		}
		event["cardStartPoint"] = _redeem_card_start_center(ingredient_id)
		event["ownerPoint"] = _redeem_owner_center(event)
		event["recipeSlotPoint"] = _redeem_recipe_slot_center(ingredient_id, slot_index)
		events.append(event)
		var recipe_wrapper := {"ownRecipe": working_recipe}
		_step_recipe_redeemed_count_for_event(recipe_wrapper, ingredient_id, slot_index)
		working_recipe = recipe_wrapper.get("ownRecipe", {}).duplicate(true)
	return events


func _recipe_id(recipe: Dictionary) -> String:
	return str(recipe.get("id", ""))


func _first_unredeemed_recipe_slot_index(recipe: Dictionary, ingredient_id: String) -> int:
	var slots := _recipe_slots(recipe)
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if str(slot.get("ingredientId", "")) == ingredient_id and str(slot.get("status", "empty")) != "redeemed":
			return index
	return -1


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
	var events := _prepare_events_from_transactions(previous_snapshot, current_snapshot)
	var event_keys := {}
	for raw_event in events:
		var event: Dictionary = raw_event
		event_keys[str(event.get("type", "")) + ":" + str(event.get("participantId", ""))] = true
	var viewer_id := str(current_snapshot.get("viewerParticipantId", ""))
	var previous_viewer := _participant_from_snapshot(previous_snapshot, viewer_id)
	var current_viewer := _participant_from_snapshot(current_snapshot, viewer_id)
	if not previous_viewer.is_empty() and not current_viewer.is_empty() \
			and not event_keys.has("prepare:%s" % viewer_id) \
			and int(current_viewer.get("dishCount", 0)) > int(previous_viewer.get("dishCount", 0)):
		var participant_name := str(current_viewer.get("name", "")).strip_edges()
		if participant_name == "":
			participant_name = _participant_name(viewer_id)
		var food_info := _new_food_part_info(previous_snapshot.get("ownFoodParts", []), current_snapshot.get("ownFoodParts", []))
		var dish_name := str(food_info.get("dishName", "")).strip_edges()
		if dish_name == "":
			dish_name = _recipe_dish_name(previous_snapshot.get("ownRecipe", {})).strip_edges()
		if dish_name == "":
			dish_name = _dish_name_from_prepare_transaction(_prepare_transaction_for_participant(previous_snapshot, current_snapshot, viewer_id)).strip_edges()
		if dish_name == "":
			dish_name = "Dish"
		events.append({
			"type": "prepare",
			"participantId": viewer_id,
			"participantName": participant_name,
			"dishName": dish_name,
			"unit": str(food_info.get("unitSingular", "piece"))
		})
		event_keys["prepare:%s" % viewer_id] = true
	for raw_participant in current_snapshot.get("participants", []):
		var current_participant: Dictionary = raw_participant
		var participant_id := str(current_participant.get("id", ""))
		if participant_id == "" or participant_id == viewer_id:
			continue
		if event_keys.has("public_prepare:%s" % participant_id):
			continue
		var previous_participant := _participant_from_snapshot(previous_snapshot, participant_id)
		if previous_participant.is_empty():
			continue
		if int(current_participant.get("dishCount", 0)) <= int(previous_participant.get("dishCount", 0)):
			continue
		var prepare_info := _public_prepare_info(previous_snapshot, current_snapshot, participant_id)
		var participant_name := _participant_display_name(current_participant, "").strip_edges()
		if participant_name == "":
			participant_name = _participant_name(participant_id)
		events.append({
			"type": "public_prepare",
			"participantId": participant_id,
			"participantName": participant_name,
			"dishName": str(prepare_info.get("dishName", "Dish")),
			"unit": str(prepare_info.get("unit", "piece"))
		})
		event_keys["public_prepare:%s" % participant_id] = true
	return events


func _prepare_events_from_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> Array:
	var events: Array = []
	var viewer_id := str(current_snapshot.get("viewerParticipantId", ""))
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Prepare":
			continue
		var participant_id := str(transaction.get("participantId", ""))
		if participant_id == "":
			continue
		var participant := _participant_from_snapshot(current_snapshot, participant_id)
		if participant.is_empty():
			participant = _participant_from_snapshot(previous_snapshot, participant_id)
		var participant_name := str(transaction.get("name", "")).strip_edges()
		if participant_name == "":
			participant_name = _participant_display_name(participant, "").strip_edges()
		if participant_name == "":
			participant_name = _participant_name(participant_id)
		var dish_name := _dish_name_from_prepare_transaction(transaction).strip_edges()
		var unit := _unit_from_prepare_transaction(transaction).strip_edges()
		if participant_id == viewer_id:
			var food_info := _new_food_part_info(previous_snapshot.get("ownFoodParts", []), current_snapshot.get("ownFoodParts", []))
			if dish_name == "":
				dish_name = str(food_info.get("dishName", "")).strip_edges()
			if dish_name == "":
				dish_name = _recipe_dish_name(previous_snapshot.get("ownRecipe", {})).strip_edges()
			if unit == "":
				unit = str(food_info.get("unitSingular", "")).strip_edges()
			events.append({
				"type": "prepare",
				"participantId": participant_id,
				"participantName": participant_name,
				"dishName": dish_name if dish_name != "" else "Dish",
				"unit": unit if unit != "" else "piece",
				"_transactionId": str(transaction.get("id", ""))
			})
		else:
			if dish_name == "":
				dish_name = _recipe_dish_name(_participant_from_snapshot(previous_snapshot, participant_id).get("currentRecipe", {})).strip_edges()
			if dish_name == "":
				dish_name = _new_public_dish_name_for_participant(previous_snapshot, current_snapshot, participant_id).strip_edges()
			events.append({
				"type": "public_prepare",
				"participantId": participant_id,
				"participantName": participant_name,
				"dishName": dish_name if dish_name != "" else "Dish",
				"unit": unit if unit != "" else "piece",
				"_transactionId": str(transaction.get("id", ""))
			})
	return events


func _public_prepare_info(previous_snapshot: Dictionary, current_snapshot: Dictionary, participant_id: String) -> Dictionary:
	var prepare_transaction := _prepare_transaction_for_participant(previous_snapshot, current_snapshot, participant_id)
	var dish_name := _dish_name_from_prepare_transaction(prepare_transaction)
	var unit := _unit_from_prepare_transaction(prepare_transaction)
	if dish_name == "":
		var previous_participant := _participant_from_snapshot(previous_snapshot, participant_id)
		dish_name = _recipe_dish_name(previous_participant.get("currentRecipe", {}))
	if dish_name == "":
		dish_name = _new_public_dish_name_for_participant(previous_snapshot, current_snapshot, participant_id)
	if dish_name == "":
		dish_name = "Dish"
	if unit == "":
		unit = "piece"
	return {"dishName": dish_name, "unit": unit}


func _prepare_transaction_for_participant(previous_snapshot: Dictionary, current_snapshot: Dictionary, participant_id: String) -> Dictionary:
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Prepare":
			continue
		if str(transaction.get("participantId", "")) == participant_id:
			return transaction
	return {}


func _dish_name_from_prepare_transaction(transaction: Dictionary) -> String:
	if transaction.is_empty():
		return ""
	var item_out := str(transaction.get("itemOut", "")).strip_edges()
	if item_out != "" and not _is_generic_recipe_label(item_out):
		return item_out
	var item_back := str(transaction.get("itemBack", "")).strip_edges()
	var of_index := item_back.to_lower().find(" of ")
	if of_index >= 0:
		var dish_name_from_quantity := item_back.substr(of_index + 4).strip_edges()
		if dish_name_from_quantity != "" and not _is_generic_recipe_label(dish_name_from_quantity):
			return dish_name_from_quantity
	for unit in ["slice", "slices", "cup", "cups", "scoop", "scoops", "piece", "pieces", "portion", "portions", "serving", "servings", "bowl", "bowls"]:
		var suffix: String = " " + unit
		if item_back.ends_with(suffix):
			var dish_name := item_back.substr(0, item_back.length() - suffix.length()).strip_edges()
			return dish_name if not _is_generic_recipe_label(dish_name) else ""
	return item_back if not _is_generic_recipe_label(item_back) else ""


func _unit_from_prepare_transaction(transaction: Dictionary) -> String:
	if transaction.is_empty():
		return ""
	var item_back := str(transaction.get("itemBack", "")).strip_edges()
	var of_index := item_back.to_lower().find(" of ")
	if of_index >= 0:
		var prefix := item_back.substr(0, of_index).strip_edges()
		var words := prefix.split(" ", false)
		if words.size() > 0:
			var parsed_unit := _singular_prepare_unit(str(words[words.size() - 1]))
			if parsed_unit != "":
				return parsed_unit
	for unit in ["slice", "cup", "scoop", "piece", "portion", "serving", "bowl"]:
		if item_back.ends_with(" " + unit) or item_back.ends_with(" " + unit + "s"):
			return unit
	return ""


func _singular_prepare_unit(unit_text: String) -> String:
	var normalized := unit_text.strip_edges().to_lower()
	match normalized:
		"slice", "slices":
			return "slice"
		"cup", "cups":
			return "cup"
		"scoop", "scoops":
			return "scoop"
		"piece", "pieces":
			return "piece"
		"portion", "portions":
			return "portion"
		"serving", "servings":
			return "serving"
		"bowl", "bowls":
			return "bowl"
		_:
			return ""


func _new_public_dish_name_for_participant(previous_snapshot: Dictionary, current_snapshot: Dictionary, participant_id: String) -> String:
	var previous_ids := {}
	for raw_dish in previous_snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		var dish_id := str(dish.get("id", ""))
		if dish_id != "":
			previous_ids[dish_id] = true
	for raw_dish in current_snapshot.get("dishes", []):
		var dish: Dictionary = raw_dish
		var dish_id := str(dish.get("id", ""))
		if dish_id != "" and previous_ids.has(dish_id):
			continue
		var maker_id := str(dish.get("makerParticipantId", ""))
		if maker_id == "":
			maker_id = str(dish.get("ownerParticipantId", ""))
		if maker_id == participant_id:
			return str(dish.get("name", dish.get("dishName", "Dish")))
	return ""


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
	var viewer_id := str(current_snapshot.get("viewerParticipantId", _viewer_id()))
	var sequence := 0
	for participant_id in _share_food_participant_order(previous_snapshot, current_snapshot, viewer_id):
		var previous_food := _food_group_counts_for_participant(previous_snapshot, participant_id, viewer_id)
		var current_food := _food_group_counts_for_participant(current_snapshot, participant_id, viewer_id)
		var delta := _count_delta(_count_only(previous_food), _count_only(current_food))
		for dish_id in _negative_keys(delta):
			var food: Dictionary = previous_food.get(dish_id, {})
			var removed_count := absi(int(delta.get(dish_id, 0)))
			if removed_count <= 0:
				continue
			events.append({
				"type": "eat",
				"participantId": participant_id,
				"dishId": str(food.get("dishId", dish_id)),
				"dishName": str(food.get("dishName", "Dish")),
				"unit": str(food.get("unitSingular", "part")),
				"quantity": removed_count,
				"startPoint": _share_food_bundle_start_point(participant_id, food, viewer_id),
				"eatSequence": sequence
			})
			sequence += 1
	if events.is_empty():
		events = _grouped_share_events_from_transactions(previous_snapshot, current_snapshot, viewer_id, sequence)
	return events


func _share_food_participant_order(previous_snapshot: Dictionary, current_snapshot: Dictionary, viewer_id: String) -> Array[String]:
	var ids: Array[String] = []
	if viewer_id != "":
		ids.append(viewer_id)
	for snapshot in [previous_snapshot, current_snapshot]:
		for raw_participant in snapshot.get("participants", []):
			if not raw_participant is Dictionary:
				continue
			var participant: Dictionary = raw_participant
			var participant_id := str(participant.get("id", ""))
			if participant_id == "" or ids.has(participant_id):
				continue
			ids.append(participant_id)
	return ids


func _food_group_counts_for_participant(snapshot: Dictionary, participant_id: String, viewer_id: String) -> Dictionary:
	if participant_id == viewer_id:
		return _food_part_counts(snapshot.get("ownFoodParts", []))
	var participant := _participant_from_snapshot(snapshot, participant_id)
	var groups: Array = participant.get("heldFoodPartGroups", []) if not participant.is_empty() else []
	if not groups.is_empty():
		return _food_group_counts(groups)
	return _visible_food_part_counts_for_participant(snapshot, participant_id)


func _food_group_counts(groups: Array) -> Dictionary:
	var counts := {}
	for raw_group in groups:
		if not raw_group is Dictionary:
			continue
		var group: Dictionary = raw_group
		var dish_id := str(group.get("dishId", ""))
		var dish_name := str(group.get("dishName", "Dish"))
		if dish_id == "":
			dish_id = "%s:%s" % [str(group.get("makerParticipantId", "")), dish_name]
		if dish_id == "":
			continue
		if not counts.has(dish_id):
			counts[dish_id] = {
				"count": 0,
				"dishId": str(group.get("dishId", dish_id)),
				"dishName": dish_name,
				"unitSingular": str(group.get("unitSingular", "part")),
				"unitPlural": str(group.get("unitPlural", "parts")),
				"makerParticipantId": str(group.get("makerParticipantId", ""))
			}
		var row: Dictionary = counts[dish_id]
		row["count"] = int(row.get("count", 0)) + maxi(1, int(group.get("count", 1)))
	return counts


func _visible_food_part_counts_for_participant(snapshot: Dictionary, participant_id: String) -> Dictionary:
	var parts: Array = []
	for raw_part in snapshot.get("dishParts", []):
		if not raw_part is Dictionary:
			continue
		var part: Dictionary = raw_part
		var location = part.get("location", {})
		if typeof(location) != TYPE_DICTIONARY:
			continue
		if str(location.get("type", "")) != "inventory" or str(location.get("participantId", "")) != participant_id:
			continue
		parts.append(part)
	return _food_part_counts(parts)


func _share_food_bundle_start_point(participant_id: String, food: Dictionary, viewer_id: String) -> Vector2:
	if participant_id != "" and participant_id != viewer_id:
		return _participant_avatar_center(participant_id)
	var start_point := _hand_food_center_by_dish_id(str(food.get("dishId", "")))
	if start_point != Vector2.INF:
		return start_point
	start_point = _hand_food_center_by_name(str(food.get("dishName", "")))
	if start_point != Vector2.INF:
		return start_point
	start_point = _control_global_center(_hand_row)
	return start_point if _is_usable_animation_point(start_point) else Vector2.INF


func _grouped_share_events_from_transactions(previous_snapshot: Dictionary, current_snapshot: Dictionary, viewer_id: String, sequence_start: int) -> Array:
	var grouped := {}
	var order: Array[String] = []
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if not ["Share", "Eat", "Bite"].has(str(transaction.get("action", ""))):
			continue
		var participant_id := str(transaction.get("participantId", ""))
		if participant_id == "":
			continue
		var dish_info := _dish_part_info_from_label(str(transaction.get("itemOut", "")), previous_snapshot, current_snapshot)
		var dish_name := str(dish_info.get("dishName", "Dish"))
		var dish_id := str(dish_info.get("dishId", ""))
		if dish_id == "":
			dish_id = "%s:%s" % [participant_id, dish_name]
		var key := "%s|%s" % [participant_id, dish_id]
		if not grouped.has(key):
			grouped[key] = {
				"participantId": participant_id,
				"dishId": dish_id,
				"dishName": dish_name,
				"unitSingular": str(dish_info.get("unitSingular", "part")),
				"count": 0
			}
			order.append(key)
		var row: Dictionary = grouped[key]
		row["count"] = int(row.get("count", 0)) + 1
	var events: Array = []
	var sequence := sequence_start
	for key in order:
		var row: Dictionary = grouped[key]
		var participant_id := str(row.get("participantId", ""))
		events.append({
			"type": "eat",
			"participantId": participant_id,
			"dishId": str(row.get("dishId", "")),
			"dishName": str(row.get("dishName", "Dish")),
			"unit": str(row.get("unitSingular", "part")),
			"quantity": maxi(1, int(row.get("count", 1))),
			"startPoint": _share_food_bundle_start_point(participant_id, row, viewer_id),
			"eatSequence": sequence
		})
		sequence += 1
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
		if _snapshot_has_eating_transition(previous_snapshot, current_snapshot):
			return []
		return [{"type": "complete"}]
	return []


func _snapshot_has_eating_transition(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> bool:
	for raw_transaction in _new_transactions(previous_snapshot, current_snapshot):
		var transaction: Dictionary = raw_transaction
		if ["Share", "Eat", "Bite"].has(str(transaction.get("action", ""))):
			return true
	if previous_snapshot.get("ownFoodParts", []).size() > current_snapshot.get("ownFoodParts", []).size():
		return true
	var previous_participants := _participant_map(previous_snapshot)
	for raw_participant in current_snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		var participant_id := str(participant.get("id", ""))
		if not previous_participants.has(participant_id):
			continue
		var previous: Dictionary = previous_participants[participant_id]
		if int(previous.get("heldFoodPartCount", 0)) > int(participant.get("heldFoodPartCount", 0)):
			return true
	return false


func _play_next_animation() -> void:
	if _animation_running or _animation_queue.is_empty() or not is_inside_tree():
		return
	var previous_visual_actor_id := _current_visual_actor_id()
	_animation_running = true
	_animation_deadline_msec = 0
	var event: Dictionary = _animation_queue.pop_front()
	_current_animation_event = event
	_animation_actor_participant_id = _animation_actor_id(event)
	var needs_actor_rerender := _animation_actor_participant_id != "" and _animation_actor_participant_id != previous_visual_actor_id
	if needs_actor_rerender:
		_apply_snapshot(_snapshot)
		call_deferred("_start_current_animation_after_layout", event.duplicate(true))
	else:
		_start_current_animation_now(event.duplicate(true))


func _start_current_animation_after_layout(expected_event: Dictionary) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_start_current_animation_now(expected_event)


func _start_current_animation_now(expected_event: Dictionary) -> void:
	if not _animation_running or _current_animation_event.is_empty() or not _same_animation_event(_current_animation_event, expected_event):
		return
	var event := _current_animation_event
	var duration := _play_animation_event(event)
	if duration <= 0.0:
		_finish_animation_event()
		return
	_animation_deadline_msec = Time.get_ticks_msec() + int(ceil((duration + 0.25) * 1000.0))
	expected_event = event.duplicate(true)
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
		_request_animation_start()


func _apply_pending_visual_snapshot_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_apply_pending_visual_snapshot()


func _apply_animation_event_snapshot(event: Dictionary) -> void:
	if bool(event.get("completeOrbit", false)) and event.has("completeOrbitItems"):
		var orbit_items: Array = event.get("completeOrbitItems", [])
		_remember_shared_food_orbit_items(orbit_items, int(event.get("completeOrbitRevealCount", orbit_items.size())))
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
	_compact_pending_visual_snapshots()
	var latest_pending := _latest_pending_visual_snapshot()
	_pending_visual_snapshot = latest_pending.duplicate(true)
	_has_pending_visual_snapshot = not latest_pending.is_empty()


func _compact_pending_visual_snapshots() -> void:
	if _pending_visual_snapshots.size() <= MAX_PENDING_VISUAL_SNAPSHOTS:
		return
	var compacted: Array = []
	var first_snapshot: Dictionary = _pending_visual_snapshots[0]
	compacted.append(first_snapshot.duplicate(true))
	var start_index := maxi(1, _pending_visual_snapshots.size() - (MAX_PENDING_VISUAL_SNAPSHOTS - 1))
	for index in range(start_index, _pending_visual_snapshots.size()):
		var snapshot: Dictionary = _pending_visual_snapshots[index]
		var last_snapshot: Dictionary = compacted[compacted.size() - 1]
		if _snapshot_identity_key(snapshot) == _snapshot_identity_key(last_snapshot):
			continue
		compacted.append(snapshot.duplicate(true))
	_pending_visual_snapshots = compacted
	_pending_visual_compaction_count += 1


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
	if _snapshot_identity_key(snapshot) == _snapshot_identity_key(_snapshot):
		_apply_snapshot(snapshot)
	else:
		render(snapshot)
	_clear_basket_swap_in_flight()
	for raw_remaining in remaining_snapshots:
		var remaining: Dictionary = raw_remaining
		_queue_pending_visual_snapshot(remaining)
	if not _animation_running and _animation_queue.is_empty() and (_has_pending_visual_snapshot or not _pending_visual_snapshots.is_empty()):
		if defer_remaining:
			_apply_pending_visual_snapshot_after_layout()
		else:
			_apply_pending_visual_snapshot(false)
	elif not _visual_update_waiting():
		_process_queued_basket_swaps()


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
		"public_prepare":
			return str(event.get("participantId", ""))
		"eat":
			return str(event.get("participantId", _viewer_id()))
		"redeem", "prepare":
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
		"public_prepare":
			return _animate_public_prepare_event(event)
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


func _animation_speed_scale(event: Dictionary) -> float:
	if _event_involves_viewer(event):
		return VIEWER_ANIMATION_SCALE
	if not _fast_bots_enabled:
		return 1.0
	match str(event.get("type", "")):
		"swap", "settlement_swap", "exchange", "redeem", "public_redeem":
			return FAST_BOT_ANIMATION_SCALE if _event_is_bot_only_and_not_viewer_involved(event) else 1.0
		_:
			return 1.0


func _event_is_bot_only_and_not_viewer_involved(event: Dictionary) -> bool:
	if _event_involves_viewer(event):
		return false
	var participant_ids := _animation_event_participant_ids(event)
	if participant_ids.is_empty():
		return false
	for participant_id in participant_ids:
		if not _participant_is_bot(participant_id):
			return false
	return true


func _event_involves_viewer(event: Dictionary) -> bool:
	var viewer_id := _viewer_id()
	if viewer_id == "":
		return true
	if _animation_event_participant_ids(event).has(viewer_id):
		return true
	var viewer_ingredient := _viewer_ingredient_id()
	if viewer_ingredient == "":
		return false
	for key in ["ingredientId", "giveIngredientId", "takeIngredientId"]:
		if str(event.get(key, "")) == viewer_ingredient:
			return true
	for raw_ingredient_id in event.get("offeredIngredientIds", []):
		if str(raw_ingredient_id) == viewer_ingredient:
			return true
	for raw_ingredient_id in event.get("requestedIngredientIds", []):
		if str(raw_ingredient_id) == viewer_ingredient:
			return true
	return false


func _animation_event_participant_ids(event: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var type := str(event.get("type", ""))
	if type == "redeem" or (type == "swap" and not event.has("actorParticipantId")) or (type == "settlement_swap" and not event.has("actorParticipantId")):
		_add_unique_id(ids, _viewer_id())
	for key in ["participantId", "actorParticipantId", "fromParticipantId", "toParticipantId", "ownerParticipantId", "counterpartyParticipantId"]:
		_add_unique_id(ids, str(event.get(key, "")))
	return ids


func _add_unique_id(ids: Array[String], participant_id: String) -> void:
	if participant_id != "" and not ids.has(participant_id):
		ids.append(participant_id)


func _participant_is_bot(participant_id: String) -> bool:
	var participant := _participant_by_id(participant_id)
	return str(participant.get("kind", "")) == "bot"


func _viewer_ingredient_id() -> String:
	var viewer := _participant_by_id(_viewer_id())
	return str(viewer.get("ingredientId", ""))


func _scaled(seconds: float, scale: float) -> float:
	return maxf(0.01, seconds * scale)


func _card_tile_landing_seconds(scale: float) -> float:
	return _scaled(CARD_TILE_FADE_IN_SECONDS + CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS, scale)


func _card_tile_visible_start_landing_seconds(scale: float) -> float:
	return _scaled(CARD_TILE_MOVE_SECONDS + CARD_TILE_PULSE_SECONDS, scale)


func _texture_landing_seconds(scale: float) -> float:
	return _scaled(TEXTURE_FADE_IN_SECONDS + TEXTURE_MOVE_SECONDS + TEXTURE_PULSE_SECONDS, scale)


func _swap_mid_snapshot_seconds(scale: float) -> float:
	return _card_tile_landing_seconds(scale)


func _swap_take_start_seconds(scale: float) -> float:
	return _card_tile_landing_seconds(scale) + _scaled(0.10 + CARD_TILE_FADE_IN_SECONDS, scale)


func _swap_finish_seconds(scale: float) -> float:
	return _swap_take_start_seconds(scale) + _card_tile_visible_start_landing_seconds(scale)


func _redeem_ingredient_delay_seconds(scale: float) -> float:
	return _card_tile_landing_seconds(scale) + _scaled(0.10, scale)


func _redeem_finish_seconds(scale: float) -> float:
	return _redeem_ingredient_delay_seconds(scale) + _texture_landing_seconds(scale)


func _animate_deposit_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var start := _event_point_or_fallback(event.get("startPoint", Vector2.INF), _participant_or_hand_center(str(event.get("participantId", "")), ingredient_id))
	var end_fallback := _platter_voucher_center(ingredient_id)
	if end_fallback == Vector2.INF:
		end_fallback = _basket_slot_center_for_visual_slot(int(event.get("basketSlotIndex", -1)))
	if end_fallback == Vector2.INF:
		end_fallback = _control_global_center(_basket_grid)
	var end := _event_point_or_fallback(event.get("endPoint", Vector2.INF), end_fallback)
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
	var speed_scale := _animation_speed_scale(event)
	var give_start := _swap_point(event, "giveStartPoint", _swap_give_start_center(event))
	var give_end := _swap_point(event, "giveEndPoint", _swap_give_end_center(event))
	if give_end == Vector2.INF:
		give_end = _control_global_center(_basket_grid)
	_apply_swap_stage_snapshot(event, "_snapshotStart")
	_animate_event_asset_tile_path(event, "give", _valid_points([give_start, give_end]), 0.0, true, speed_scale)
	if event.has("_snapshotMid") and is_inside_tree():
		get_tree().create_timer(_swap_mid_snapshot_seconds(speed_scale)).timeout.connect(func() -> void:
			_apply_swap_stage_snapshot(event, "_snapshotMid")
		)
	if is_inside_tree():
		get_tree().create_timer(_swap_take_start_seconds(speed_scale)).timeout.connect(func() -> void:
			var return_start := _swap_point(event, "takeStartPoint", _swap_take_start_center(event))
			_apply_swap_stage_snapshot(event, "_snapshotTakeStart")
			var return_end := _swap_point(event, "takeEndPoint", _swap_take_end_center(event))
			event["takeEndPoint"] = return_end
			_animate_event_asset_tile_path(event, "take", _valid_points([return_start, return_end]), 0.0, true, speed_scale)
		)
	return _swap_finish_seconds(speed_scale)


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
	match str(left.get("type", "")):
		"redeem":
			return str(right.get("type", "")) == "redeem" \
				and str(left.get("ingredientId", "")) == str(right.get("ingredientId", "")) \
				and str(left.get("ownerParticipantId", "")) == str(right.get("ownerParticipantId", "")) \
				and int(left.get("slotIndex", -1)) == int(right.get("slotIndex", -1))
		"public_redeem":
			return str(right.get("type", "")) == "public_redeem" \
				and str(left.get("participantId", "")) == str(right.get("participantId", "")) \
				and str(left.get("ingredientId", "")) == str(right.get("ingredientId", "")) \
				and str(left.get("ownerParticipantId", "")) == str(right.get("ownerParticipantId", ""))
		"prepare":
			return str(right.get("type", "")) == "prepare" \
				and str(left.get("dishName", "")) == str(right.get("dishName", "")) \
				and str(left.get("unit", "")) == str(right.get("unit", ""))
		"public_prepare":
			return str(right.get("type", "")) == "public_prepare" \
				and str(left.get("participantId", "")) == str(right.get("participantId", "")) \
				and str(left.get("dishName", "")) == str(right.get("dishName", "")) \
				and str(left.get("unit", "")) == str(right.get("unit", ""))
		"eat":
			return str(right.get("type", "")) == "eat" \
				and str(left.get("participantId", "")) == str(right.get("participantId", "")) \
				and str(left.get("dishId", "")) == str(right.get("dishId", "")) \
				and str(left.get("dishName", "")) == str(right.get("dishName", "")) \
				and int(left.get("eatSequence", -1)) == int(right.get("eatSequence", -1))
		"offer":
			return str(right.get("type", "")) == "offer" \
				and str(left.get("participantId", "")) == str(right.get("participantId", "")) \
				and str(left.get("indicator", "")) == str(right.get("indicator", ""))
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
	var speed_scale := _animation_speed_scale(event)
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
		var offered_start := _exchange_leg_point(leg, "startPoint", _exchange_endpoint(from_id, ingredient_id, true))
		var offered_end := _exchange_leg_point(leg, "endPoint", _exchange_endpoint(to_id, ingredient_id, false))
		_animate_voucher_card_path(
			ingredient_id,
			_valid_points([
				offered_start,
				offered_end
			]),
			delay,
			true,
			speed_scale
		)
		last_start_delay = delay
		delay += _scaled(0.08, speed_scale)
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
		var requested_start := _exchange_leg_point(leg, "startPoint", _exchange_endpoint(to_id, ingredient_id, true))
		var requested_end := _exchange_leg_point(leg, "endPoint", _exchange_endpoint(from_id, ingredient_id, false))
		_animate_voucher_card_path(
			ingredient_id,
			_valid_points([
				requested_start,
				requested_end
			]),
			delay,
			true,
			speed_scale
		)
		last_start_delay = delay
		delay += _scaled(0.08, speed_scale)
	return last_start_delay + _card_tile_landing_seconds(speed_scale)


func _animate_redeem_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var speed_scale := _animation_speed_scale(event)
	var texture := _ingredient_texture(ingredient_id)
	var start := _redeem_point(event, "cardStartPoint", _redeem_card_start_center(ingredient_id))
	var owner_target := _redeem_point(event, "ownerPoint", _redeem_owner_center(event))
	var end := _redeem_point(event, "recipeSlotPoint", _redeem_recipe_slot_center(ingredient_id, int(event.get("slotIndex", 0))))
	_animate_voucher_card_path(ingredient_id, _valid_points([start, owner_target]), 0.0, true, speed_scale)
	_animate_texture_path(texture, _valid_points([owner_target, end]), _redeem_ingredient_delay_seconds(speed_scale), Vector2(58, 58), speed_scale)
	return _redeem_finish_seconds(speed_scale)


func _animate_public_redeem_event(event: Dictionary) -> float:
	var ingredient_id := str(event.get("ingredientId", ""))
	var speed_scale := _animation_speed_scale(event)
	var texture := _ingredient_texture(ingredient_id)
	var actor_center := _redeem_point(event, "cardStartPoint", _public_redeem_actor_center(event))
	var owner_center := _redeem_point(event, "ownerPoint", _redeem_owner_center(event))
	var ingredient_end := _redeem_point(event, "ingredientEndPoint", _public_redeem_actor_center(event))
	_animate_voucher_card_path(ingredient_id, _valid_points([actor_center, owner_center]), 0.0, true, speed_scale)
	_animate_texture_path(texture, _valid_points([owner_center, ingredient_end]), _redeem_ingredient_delay_seconds(speed_scale), Vector2(58, 58), speed_scale)
	return _redeem_finish_seconds(speed_scale)


func _redeem_point(event: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _event_point_or_fallback(event.get(key, Vector2.INF), fallback, true)


func _redeem_card_start_center(ingredient_id: String) -> Vector2:
	return _hand_card_or_row_center(ingredient_id)


func _redeem_owner_center(event: Dictionary) -> Vector2:
	var ingredient_id := str(event.get("ingredientId", ""))
	var owner_id := str(event.get("ownerParticipantId", ""))
	if owner_id != "":
		var participant_center := _participant_tile_center(owner_id)
		if participant_center != Vector2.INF:
			return participant_center
	if owner_id == _viewer_id():
		return _inventory_stock_or_row_center(ingredient_id)
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
	var end := _prepare_dish_end_center(event)
	var speed_scale := _animation_speed_scale(event)
	var landing_delay := _scaled(0.28, speed_scale)
	var landing_seconds := landing_delay + _card_tile_landing_seconds(speed_scale)
	debug_stats["lastPrepareDishStartPoint"] = center
	debug_stats["lastPrepareDishEndPoint"] = end
	debug_stats["lastPrepareDishGenericHandCenter"] = _control_global_center(_hand_row)
	debug_stats["lastPrepareDishLandingSeconds"] = landing_seconds
	_glow_recipe_slots()
	_animate_prepare_ingredient_swirl(center)
	_animate_poof_burst(center, 0.86)
	_animate_prepare_announcement(_prepare_participant_name(event), dish_name, center, 0.78)
	_animate_dish_part_card_path(dish_name, unit, _valid_points([center, end]), landing_delay, true, speed_scale)
	_animate_large_dish(texture, dish_name, center, end, 0.34)
	_schedule_prepare_landing_snapshot(event, landing_seconds)
	_emit_sparkles(center, 24, Color(1.0, 0.76, 0.28), 0.82)
	_emit_steam_wisps(center, 1.06)
	return 2.20


func _schedule_prepare_landing_snapshot(event: Dictionary, landing_seconds: float) -> void:
	if not is_inside_tree() or not event.has("_snapshotAfter"):
		return
	var event_copy := event.duplicate(true)
	get_tree().create_timer(maxf(0.01, landing_seconds)).timeout.connect(func() -> void:
		if _current_animation_event.is_empty() or not _same_animation_event(_current_animation_event, event_copy):
			return
		var snapshot: Dictionary = event_copy.get("_snapshotAfter", {})
		if snapshot.is_empty():
			return
		_apply_snapshot(snapshot)
		debug_stats["lastPrepareLandingSnapshotApplied"] = true
	)


func _prepare_dish_end_center(event: Dictionary) -> Vector2:
	var explicit := _event_point_or_fallback(event.get("dishEndPoint", Vector2.INF), Vector2.INF)
	if explicit != Vector2.INF:
		return explicit
	var future_snapshot: Dictionary = event.get("_snapshotAfter", {})
	var future_center := _future_hand_food_center(future_snapshot, str(event.get("dishName", "")))
	if future_center != Vector2.INF:
		return future_center
	return _control_global_center(_hand_row)


func _future_hand_food_center(future_snapshot: Dictionary, dish_name: String) -> Vector2:
	if future_snapshot.is_empty():
		return Vector2.INF
	var food_info := _new_food_part_info(_snapshot.get("ownFoodParts", []), future_snapshot.get("ownFoodParts", []))
	var target_dish_id := str(food_info.get("dishId", ""))
	var target_dish_name := str(food_info.get("dishName", "")).strip_edges()
	if target_dish_name == "":
		target_dish_name = dish_name.strip_edges()
	var voucher_count := _voucher_group_options(future_snapshot.get("ownHand", [])).size()
	var food_groups := _food_part_group_options(future_snapshot.get("ownFoodParts", []))
	for index in range(food_groups.size()):
		var group: Dictionary = food_groups[index]
		var group_dish_id := str(group.get("dishId", ""))
		var group_dish_name := str(group.get("dishName", "")).strip_edges()
		var matches_id := target_dish_id != "" and group_dish_id == target_dish_id
		var matches_name := target_dish_id == "" and target_dish_name != "" and group_dish_name == target_dish_name
		if matches_id or matches_name:
			return _hand_grid_cell_center(voucher_count + index)
	return Vector2.INF


func _hand_grid_cell_center(index: int) -> Vector2:
	if index < 0 or not is_instance_valid(_hand_row):
		return Vector2.INF
	var rect := _hand_row.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.INF
	var columns := maxi(1, _hand_row.columns)
	var row := index / columns
	var column := index % columns
	var cell_size := Vector2(
		maxf(HAND_CARD_SIZE.x, HAND_FOOD_SIZE.x),
		maxf(HAND_CARD_SIZE.y, HAND_FOOD_SIZE.y)
	)
	var h_gap := float(_hand_row.get_theme_constant("h_separation"))
	var v_gap := float(_hand_row.get_theme_constant("v_separation"))
	return Vector2(
		rect.position.x + float(column) * (cell_size.x + h_gap) + cell_size.x * 0.5,
		rect.position.y + float(row) * (cell_size.y + v_gap) + cell_size.y * 0.5
	)


func _future_inventory_target_center(event: Dictionary, future_snapshot: Dictionary) -> Vector2:
	var actor_id := _swap_actor_id(event)
	if actor_id != "" and actor_id != _viewer_id():
		return Vector2.INF
	var kind := str(event.get("takeKind", ""))
	if kind == "voucher":
		return _future_hand_voucher_center(future_snapshot, str(event.get("takeIngredientId", "")))
	if kind == "dish_part":
		return _future_hand_food_center(future_snapshot, str(event.get("takeDishName", "")))
	return Vector2.INF


func _future_hand_voucher_center(future_snapshot: Dictionary, ingredient_id: String) -> Vector2:
	if future_snapshot.is_empty() or ingredient_id == "":
		return Vector2.INF
	var voucher_groups := _voucher_group_options(future_snapshot.get("ownHand", []))
	voucher_groups.reverse()
	for index in range(voucher_groups.size()):
		var group: Dictionary = voucher_groups[index]
		if str(group.get("ingredientId", "")) == ingredient_id:
			return _hand_grid_cell_center(index)
	return Vector2.INF


func _animate_public_prepare_event(event: Dictionary) -> float:
	var participant_id := str(event.get("participantId", ""))
	var dish_name := str(event.get("dishName", "Dish"))
	var unit := str(event.get("unit", "piece"))
	var texture = VisualAssets.dish_meta(dish_name, unit).get("texture", null)
	if not texture is Texture2D:
		texture = VisualAssets.unit_meta(unit).get("texture", null)
	var center := _participant_tile_center(participant_id)
	if center == Vector2.INF:
		center = _control_global_center(_participant_row)
	if center == Vector2.INF:
		return 0.0
	var finish := center + Vector2(0, -8)
	_animate_poof_burst(center, 0.20)
	_animate_prepare_announcement(_prepare_participant_name(event), dish_name, center, 0.18)
	_animate_large_dish(texture, dish_name, center, finish, 0.36)
	_emit_sparkles(center, 22, Color(1.0, 0.76, 0.28), 0.16)
	_emit_steam_wisps(center, 0.42)
	return 1.72


func _animate_offer_event(event: Dictionary) -> float:
	var participant_node := find_child("Participant_%s" % str(event.get("participantId", "")), true, false) as Control
	var indicator := str(event.get("indicator", ""))
	if indicator.find("!") >= 0:
		_animate_offer_badge_arrival(participant_node, "!", Color(0.82, 0.12, 0.10))
	if indicator.find("?") >= 0:
		_animate_offer_badge_arrival(participant_node, "?", Color(0.06, 0.55, 0.22))
	return 0.36


func _animate_eat_event(event: Dictionary) -> float:
	if bool(event.get("completeOrbit", false)):
		return _animate_eat_to_complete_orbit(event)
	var orbit_event := event.duplicate(true)
	var items := _complete_food_orbit_items()
	if items.is_empty():
		_append_complete_orbit_item(items, str(event.get("dishName", "Dish")), str(event.get("unit", "part")), int(event.get("quantity", 1)))
	orbit_event["completeOrbit"] = true
	orbit_event["completeOrbitItems"] = items
	var reveal_index := clampi(_shared_food_orbit_visible_count_for_snapshot(_snapshot, items), 0, maxi(0, items.size() - 1))
	orbit_event["completeOrbitIndex"] = reveal_index
	if not orbit_event.has("completeOrbitPhase"):
		var orbit_phase := _complete_orbit_phase_for_eat_event(orbit_event, reveal_index)
		orbit_event["completeOrbitPhase"] = orbit_phase
		if reveal_index >= 0 and reveal_index < items.size():
			var orbit_item: Dictionary = items[reveal_index]
			if not orbit_item.has("orbitPhase"):
				orbit_item["orbitPhase"] = orbit_phase
				items[reveal_index] = orbit_item
	orbit_event["completeOrbitTotal"] = maxi(1, items.size())
	orbit_event["completeOrbitRevealCount"] = clampi(int(orbit_event.get("completeOrbitIndex", 0)) + 1, 0, items.size())
	return _animate_eat_to_complete_orbit(orbit_event)


func _animate_eat_to_complete_orbit(event: Dictionary) -> float:
	var items: Array = event.get("completeOrbitItems", [])
	if items.is_empty():
		_append_complete_orbit_item(items, str(event.get("dishName", "Dish")), str(event.get("unit", "part")), int(event.get("quantity", 1)))
	if items.is_empty():
		return 0.0
	_complete_orbit_transition_active = true
	var existing_visible := 0
	if is_instance_valid(_complete_food_orbit):
		existing_visible = int(_complete_food_orbit.get_meta("visible_orbit_item_count", 0))
	_ensure_complete_food_orbit_for_items(items, existing_visible)
	_complete_orbit_transition_active = true

	var dish_name := str(event.get("dishName", "Dish"))
	var unit := str(event.get("unit", "part"))
	var texture = VisualAssets.dish_meta(dish_name, unit).get("texture", null)
	if not texture is Texture2D:
		var item_index := clampi(int(event.get("completeOrbitIndex", 0)), 0, maxi(0, items.size() - 1))
		var fallback_item: Dictionary = items[item_index]
		texture = fallback_item.get("texture", null)
	var start := _eat_start_center(event)
	var total := maxi(1, int(event.get("completeOrbitTotal", items.size())))
	var target := _complete_orbit_global_point_for_event(event, total)
	debug_stats["lastEatAnimationStartPoint"] = start
	debug_stats["lastCompleteOrbitStartPoint"] = start
	debug_stats["lastCompleteOrbitTargetPoint"] = target
	debug_stats["lastCompleteOrbitPhase"] = float(event.get("completeOrbitPhase", -1.0))
	debug_stats["completeFoodOrbitTransition"] = true
	_animate_texture_to_complete_orbit(texture, start, target, int(event.get("completeOrbitRevealCount", items.size())), items)
	if _is_usable_animation_point(start):
		_emit_sparkles(start, 8, Color(0.95, 0.62, 0.34))
	return COMPLETE_ORBIT_LAUNCH_EVENT_SECONDS


func _animate_texture_to_complete_orbit(texture: Texture2D, global_start: Vector2, global_end: Vector2, reveal_count: int, orbit_items: Array) -> void:
	if not is_instance_valid(_animation_layer) or not texture is Texture2D:
		_reveal_complete_orbit_items(reveal_count, orbit_items)
		return
	var icon_size := CompleteFoodOrbit.ITEM_SIZE
	debug_stats["lastCompleteOrbitFlyingFoodSize"] = icon_size
	var start := global_start
	var finish := global_end
	if not _is_usable_animation_point(start) or not _is_usable_animation_point(finish):
		_reveal_complete_orbit_items(reveal_count, orbit_items)
		return
	var icon := TextureRect.new()
	icon.name = "CompleteOrbitFlyingFood"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.size = icon_size
	icon.custom_minimum_size = icon_size
	icon.pivot_offset = icon_size * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 1.0, 1.0, 0.98)
	icon.scale = Vector2(0.9, 0.9)
	_animation_layer.add_child(icon)
	icon.position = _animation_local(start) - icon_size * 0.5

	var tween := create_tween()
	tween.tween_property(icon, "position", _animation_local(finish) - icon_size * 0.5, COMPLETE_ORBIT_LAUNCH_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2(1.12, 1.12), COMPLETE_ORBIT_LAUNCH_MOVE_SECONDS * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2(0.96, 0.96), COMPLETE_ORBIT_LAUNCH_SETTLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 0.0), COMPLETE_ORBIT_LAUNCH_FADE_SECONDS)
	tween.tween_callback(func() -> void:
		_reveal_complete_orbit_items(reveal_count, orbit_items)
		if is_instance_valid(icon):
			icon.queue_free()
	)


func _reveal_complete_orbit_items(visible_count: int, orbit_items: Array = []) -> void:
	_remember_shared_food_orbit_items(orbit_items, visible_count)
	if not is_instance_valid(_complete_food_orbit):
		return
	if _complete_food_orbit.has_method("set_visible_item_count"):
		_complete_food_orbit.call("set_visible_item_count", visible_count)
	debug_stats["completeFoodOrbitCount"] = int(_complete_food_orbit.get_meta("orbit_item_count", 0))
	debug_stats["completeFoodOrbitVisibleCount"] = int(_complete_food_orbit.get_meta("visible_orbit_item_count", 0))


func _remember_shared_food_orbit_items(orbit_items: Array, visible_count: int) -> void:
	if orbit_items.is_empty() or visible_count <= 0:
		return
	_shared_food_orbit_items.clear()
	var limit := clampi(visible_count, 0, orbit_items.size())
	for index in range(limit):
		var item: Dictionary = orbit_items[index]
		_shared_food_orbit_items.append(item.duplicate(true))


func _complete_orbit_global_point(index: int, total: int) -> Vector2:
	return _complete_orbit_global_point_for_phase(float(posmod(index, maxi(1, total))) / float(maxi(1, total)))


func _complete_orbit_global_point_for_event(event: Dictionary, total: int) -> Vector2:
	var phase := float(event.get("completeOrbitPhase", -1.0))
	if phase < 0.0 or phase >= 1.0:
		phase = float(posmod(int(event.get("completeOrbitIndex", 0)), maxi(1, total))) / float(maxi(1, total))
	return _complete_orbit_global_point_for_phase(phase)


func _complete_orbit_global_point_for_phase(phase: float) -> Vector2:
	var rect := get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Vector2.INF
	var max_inset := minf(rect.size.x, rect.size.y) * 0.22
	var left := minf(CompleteFoodOrbit.ORBIT_LEFT_INSET, max_inset)
	var top := minf(CompleteFoodOrbit.ORBIT_TOP_INSET, max_inset)
	var right := minf(CompleteFoodOrbit.ORBIT_RIGHT_INSET, max_inset)
	var bottom := minf(CompleteFoodOrbit.ORBIT_BOTTOM_INSET, max_inset)
	var orbit_rect := Rect2(
		rect.position + Vector2(left, top),
		Vector2(maxf(1.0, rect.size.x - left - right), maxf(1.0, rect.size.y - top - bottom))
	)
	var perimeter := maxf(1.0, (orbit_rect.size.x + orbit_rect.size.y) * 2.0)
	return _point_on_rect_perimeter(orbit_rect, fposmod(phase, 1.0) * perimeter)


func _point_on_rect_perimeter(rect: Rect2, distance: float) -> Vector2:
	var width := maxf(1.0, rect.size.x)
	var height := maxf(1.0, rect.size.y)
	var remaining := fposmod(distance, (width + height) * 2.0)
	if remaining <= width:
		return rect.position + Vector2(remaining, 0.0)
	remaining -= width
	if remaining <= height:
		return rect.position + Vector2(width, remaining)
	remaining -= height
	if remaining <= width:
		return rect.position + Vector2(width - remaining, height)
	remaining -= width
	return rect.position + Vector2(0.0, height - remaining)


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
	var from_id := str(event.get("fromParticipantId", ""))
	var to_id := str(event.get("toParticipantId", ""))
	var points := {}
	if not offered.is_empty():
		var leg: Dictionary = offered[0]
		var ingredient_id := str(leg.get("ingredientId", ""))
		points["offeredStart"] = _exchange_leg_point(leg, "startPoint", _exchange_endpoint(from_id, ingredient_id, true))
		points["offeredEnd"] = _exchange_leg_point(leg, "endPoint", _exchange_endpoint(to_id, ingredient_id, false))
	if not requested.is_empty():
		var leg: Dictionary = requested[0]
		var ingredient_id := str(leg.get("ingredientId", ""))
		points["requestedStart"] = _exchange_leg_point(leg, "startPoint", _exchange_endpoint(to_id, ingredient_id, true))
		points["requestedEnd"] = _exchange_leg_point(leg, "endPoint", _exchange_endpoint(from_id, ingredient_id, false))
	return points


func _exchange_leg_point(leg: Dictionary, key: String, fallback := Vector2.INF) -> Vector2:
	return _event_point_or_fallback(leg.get(key, Vector2.INF), fallback, true)


func _exchange_endpoint(participant_id: String, ingredient_id: String, is_source: bool) -> Vector2:
	if participant_id == _viewer_id():
		if is_source:
			return _hand_card_or_row_center(ingredient_id)
		return _hand_card_or_row_center(ingredient_id)
	return _participant_trade_anchor_center(participant_id, ingredient_id)


func _control_for_participant_or_viewer(participant_id: String) -> Control:
	return find_child("Participant_%s" % participant_id, true, false) as Control


func _participant_tile_center(participant_id: String) -> Vector2:
	if participant_id == "":
		return Vector2.INF
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


func _participant_avatar_center(participant_id: String) -> Vector2:
	var participant_node := _control_for_participant_or_viewer(participant_id)
	if is_instance_valid(participant_node):
		var avatar := participant_node.find_child("CookAvatar", true, false) as Control
		var avatar_center := _control_global_center(avatar)
		if avatar_center != Vector2.INF:
			return avatar_center
	return _participant_tile_center(participant_id)


func _participant_trade_anchor_center(participant_id: String, ingredient_id := "") -> Vector2:
	var participant_node := _control_for_participant_or_viewer(participant_id)
	if is_instance_valid(participant_node):
		var participant := _participant_from_snapshot(_snapshot, participant_id)
		if ingredient_id != "" and str(participant.get("ingredientId", "")) == ingredient_id:
			var ingredient_icon := participant_node.find_child("CookIngredientIcon", true, false) as Control
			var ingredient_center := _control_global_center(ingredient_icon)
			if ingredient_center != Vector2.INF:
				return ingredient_center
		var avatar := participant_node.find_child("CookAvatar", true, false) as Control
		var avatar_center := _control_global_center(avatar)
		if avatar_center != Vector2.INF:
			return avatar_center
		var fallback_icon := participant_node.find_child("CookIngredientIcon", true, false) as Control
		var fallback_icon_center := _control_global_center(fallback_icon)
		if fallback_icon_center != Vector2.INF:
			return fallback_icon_center
	return _participant_tile_center(participant_id)


func _hand_card_or_row_center(ingredient_id: String) -> Vector2:
	var hand_card := find_child("HandCard_%s" % ingredient_id, true, false) as Control
	var hand_center := _control_global_center(hand_card)
	if hand_center != Vector2.INF:
		return hand_center
	var hand_area := _control_global_center(_hand_row)
	if hand_area != Vector2.INF:
		return hand_area
	return _participant_tile_center(_viewer_id())


func _inventory_stock_or_row_center(ingredient_id: String) -> Vector2:
	var stock_item := find_child("InventoryStock_%s" % ingredient_id, true, false) as Control
	var stock_center := _control_global_center(stock_item)
	if stock_center != Vector2.INF:
		return stock_center
	var owner_center := _ingredient_owner_global_center(ingredient_id)
	if owner_center != Vector2.INF:
		return owner_center
	var inventory_center := _control_global_center(_inventory_row)
	if inventory_center != Vector2.INF:
		return inventory_center
	return _control_global_center(_hand_row)


func _public_redeem_actor_center(event: Dictionary) -> Vector2:
	return _participant_tile_center(str(event.get("participantId", "")))


func _swap_point(event: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _event_point_or_fallback(event.get(key, Vector2.INF), fallback)


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
				return _participant_trade_anchor_center(actor_id, ingredient_id)
			return _hand_card_or_row_center(ingredient_id)
		return _platter_voucher_center(ingredient_id)
	if kind == "dish_part":
		var dish_name := str(event.get("%sDishName" % prefix, "Dish"))
		if prefix == "give":
			if actor_id != "" and actor_id != _viewer_id():
				return _participant_trade_anchor_center(actor_id)
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
	var kind := str(event.get("%sKind" % prefix, ""))
	if participant_id != "" and participant_id != _viewer_id():
		if kind == "voucher":
			return _participant_trade_anchor_center(participant_id, str(event.get("%sIngredientId" % prefix, "")))
		return _participant_trade_anchor_center(participant_id)
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
		var platter_center := _control_global_center(platter_node)
		if platter_center != Vector2.INF:
			return platter_center
		return _basket_food_slot_center_by_name(dish_name)
	return _basket_food_slot_center_by_name(dish_name)


func _basket_food_slot_center_by_name(dish_name: String) -> Vector2:
	if not is_instance_valid(_basket_grid):
		return Vector2.INF
	var food_groups := _food_part_group_options(_snapshot.get("platterFoodParts", []))
	var food_rank := -1
	for index in range(food_groups.size()):
		var group: Dictionary = food_groups[index]
		if str(group.get("dishName", "")) == dish_name:
			food_rank = index
			break
	var hypothetical_food_groups := food_groups.duplicate(true)
	if food_rank < 0:
		food_rank = hypothetical_food_groups.size()
		hypothetical_food_groups.append({
			"dishId": "__future_%s" % dish_name,
			"dishName": dish_name,
			"unitSingular": "piece",
			"count": 1
		})
	var voucher_groups_by_ingredient := _voucher_groups_by_ingredient(_snapshot.get("platter", []))
	var total_visible_groups := voucher_groups_by_ingredient.size() + hypothetical_food_groups.size()
	if total_visible_groups <= BASKET_CENTER_OUT_SLOTS.size():
		var food_by_slot := _basket_food_groups_by_visual_slot(hypothetical_food_groups, _basket_ingredient_by_visual_slot(), voucher_groups_by_ingredient)
		for raw_slot_index in food_by_slot.keys():
			var slot_index := int(raw_slot_index)
			var group: Dictionary = food_by_slot[raw_slot_index]
			if str(group.get("dishName", "")) == dish_name:
				return _basket_slot_center_for_visual_slot(slot_index)
	return _basket_grid_index_center(food_rank)


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


func _hand_food_center_by_dish_id(dish_id: String) -> Vector2:
	if dish_id == "":
		return Vector2.INF
	var food_node := find_child("HandFood_%s" % dish_id, true, false) as Control
	return _control_global_center(food_node)


func _eat_start_center(event: Dictionary) -> Vector2:
	var participant_id := str(event.get("participantId", ""))
	if participant_id != "" and participant_id != _viewer_id():
		var avatar_center := _participant_avatar_center(participant_id)
		if avatar_center != Vector2.INF:
			return avatar_center
		var public_start := _event_point_or_fallback(event.get("startPoint", Vector2.INF), Vector2.INF)
		if public_start != Vector2.INF:
			return public_start
	var center := _hand_food_center_by_dish_id(str(event.get("dishId", "")))
	if center != Vector2.INF:
		return center
	center = _hand_food_center_by_name(str(event.get("dishName", "")))
	if center != Vector2.INF:
		return center
	var recorded_start := _event_point_or_fallback(event.get("startPoint", Vector2.INF), Vector2.INF)
	if recorded_start != Vector2.INF:
		return recorded_start
	var hand_row_center := _control_global_center(_hand_row)
	return hand_row_center if _is_usable_animation_point(hand_row_center) else Vector2.INF


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


func _event_point_or_fallback(value, fallback: Vector2, prefer_fallback := false) -> Vector2:
	if prefer_fallback and _is_usable_animation_point(fallback):
		return fallback
	if typeof(value) == TYPE_VECTOR2:
		var point: Vector2 = value
		if _is_usable_animation_point(point):
			return point
	if _is_usable_animation_point(fallback):
		return fallback
	return Vector2.INF


func _is_usable_animation_point(point: Vector2) -> bool:
	if point == Vector2.INF:
		return false
	if is_nan(point.x) or is_nan(point.y) or is_inf(point.x) or is_inf(point.y):
		return false
	if absf(point.x) <= ANIMATION_POINT_ORIGIN_EPSILON and absf(point.y) <= ANIMATION_POINT_ORIGIN_EPSILON:
		return false
	var bounds := _animation_point_bounds()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and not bounds.has_point(point):
		return false
	return true


func _animation_point_bounds() -> Rect2:
	var rect := get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	return rect.grow(ANIMATION_POINT_BOUNDS_PADDING)


func _animation_local(global_point: Vector2) -> Vector2:
	if not is_instance_valid(_animation_layer):
		return global_point
	return _animation_layer.get_global_transform_with_canvas().affine_inverse() * global_point


func _valid_points(points: Array) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	for raw_point in points:
		if typeof(raw_point) != TYPE_VECTOR2:
			continue
		var point: Vector2 = raw_point
		if _is_usable_animation_point(point):
			valid.append(point)
	return valid


func _animate_event_asset_tile_path(event: Dictionary, prefix: String, global_points: Array[Vector2], delay := 0.0, start_visible := true, duration_scale := 1.0) -> void:
	var kind := str(event.get("%sKind" % prefix, ""))
	if kind == "voucher":
		_animate_voucher_card_path(str(event.get("%sIngredientId" % prefix, "")), global_points, delay, start_visible, duration_scale)
	elif kind == "dish_part":
		_animate_dish_part_card_path(
			str(event.get("%sDishName" % prefix, "Dish")),
			str(event.get("%sUnit" % prefix, "part")),
			global_points,
			delay,
			start_visible,
			duration_scale
		)


func _animate_voucher_card_path(ingredient_id: String, global_points: Array[Vector2], delay := 0.0, start_visible := true, duration_scale := 1.0) -> void:
	var meta := VisualAssets.ingredient_meta(ingredient_id)
	_animate_visual_tile_path(meta, _ingredient_display(ingredient_id), global_points, delay, start_visible, duration_scale)


func _animate_dish_part_card_path(dish_name: String, unit: String, global_points: Array[Vector2], delay := 0.0, start_visible := true, duration_scale := 1.0) -> void:
	var meta := VisualAssets.dish_meta(dish_name, unit)
	_animate_visual_tile_path(meta, VisualAssets.short_dish_name(dish_name), global_points, delay, start_visible, duration_scale)


func _animate_visual_tile_path(meta: Dictionary, label: String, global_points: Array[Vector2], delay := 0.0, start_visible := true, duration_scale := 1.0) -> void:
	if global_points.size() < 2 or not is_instance_valid(_animation_layer):
		return
	var tile_size := ANIMATED_CARD_TILE_SIZE
	var tile := Button.new()
	tile.name = "AnimatedCard_%s" % label.replace(" ", "_")
	debug_stats["lastAnimatedCardSize"] = tile_size
	debug_stats["lastAnimatedCardPeakSize"] = tile_size * CARD_TILE_LAND_SCALE
	tile.text = ""
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_contents = true
	tile.size = tile_size
	tile.custom_minimum_size = tile_size
	tile.pivot_offset = tile_size * 0.5
	tile.scale = CARD_TILE_START_SCALE
	tile.modulate = Color(1, 1, 1, 0.98) if start_visible else Color(1, 1, 1, 0)
	var bg: Color = meta.get("color", Color(0.86, 0.78, 0.58))
	_apply_button_style(tile, bg, Color(0.30, 0.35, 0.42), 1)
	_add_visual_content(tile, "", label, meta, tile_size, _contrast_ink(bg), true)
	_add_card_inset_outline(tile, Color(0.30, 0.35, 0.42), 1)
	_animation_layer.add_child(tile)

	var local_points: Array[Vector2] = []
	for point in global_points:
		local_points.append(_animation_local(point))
	tile.position = local_points[0] - tile_size * 0.5

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	if not start_visible:
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 0.98), _scaled(CARD_TILE_FADE_IN_SECONDS, duration_scale))
	for index in range(1, local_points.size()):
		tween.tween_property(tile, "position", local_points[index] - tile_size * 0.5, _scaled(CARD_TILE_MOVE_SECONDS, duration_scale)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(tile, "scale", CARD_TILE_LAND_SCALE, _scaled(CARD_TILE_PULSE_SECONDS * 0.5, duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", CARD_TILE_START_SCALE, _scaled(CARD_TILE_PULSE_SECONDS * 0.5, duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), _scaled(CARD_TILE_FADE_OUT_SECONDS, duration_scale))
	tween.tween_callback(tile.queue_free)


func _animate_texture_path(texture: Texture2D, global_points: Array[Vector2], delay := 0.0, icon_size := Vector2(46, 46), duration_scale := 1.0) -> void:
	if global_points.size() < 2 or not is_instance_valid(_animation_layer) or not texture is Texture2D:
		return
	debug_stats["lastAnimatedTextureSize"] = icon_size
	debug_stats["lastAnimatedTexturePeakSize"] = icon_size * TEXTURE_LAND_SCALE
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
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), _scaled(TEXTURE_FADE_IN_SECONDS, duration_scale))
	for index in range(1, local_points.size()):
		tween.tween_property(icon, "position", local_points[index] - icon_size * 0.5, _scaled(TEXTURE_MOVE_SECONDS, duration_scale)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "scale", TEXTURE_LAND_SCALE, _scaled(TEXTURE_PULSE_SECONDS * 0.5, duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "scale", Vector2.ONE, _scaled(TEXTURE_PULSE_SECONDS * 0.5, duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 0), _scaled(TEXTURE_FADE_OUT_SECONDS, duration_scale))
	tween.tween_callback(icon.queue_free)


func _animate_large_dish(texture: Texture2D, dish_name: String, global_start: Vector2, global_end: Vector2, delay := 0.0) -> void:
	if not is_instance_valid(_animation_layer) or not _is_usable_animation_point(global_start) or not _is_usable_animation_point(global_end):
		return
	var wrapper := PanelContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = PREPARE_DISH_PANEL_SIZE
	wrapper.pivot_offset = wrapper.size * 0.5
	wrapper.modulate = Color(1, 1, 1, 0)
	wrapper.scale = Vector2(0.45, 0.45)
	wrapper.add_theme_stylebox_override("panel", _prepare_dish_style())
	_animation_layer.add_child(wrapper)
	wrapper.position = _animation_local(global_start) - wrapper.size * 0.5
	debug_stats["lastPrepareLargeDishSize"] = PREPARE_DISH_PANEL_SIZE
	debug_stats["lastPrepareLargeDishPeakSize"] = PREPARE_DISH_PANEL_SIZE * PREPARE_DISH_POP_SCALE
	debug_stats["lastPrepareLargeDishIconSize"] = PREPARE_DISH_ICON_SIZE

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(box)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		icon.custom_minimum_size = PREPARE_DISH_ICON_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
	var label := _card_label(VisualAssets.short_dish_name(dish_name), TEXT_DARK, 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(wrapper, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.parallel().tween_property(wrapper, "scale", PREPARE_DISH_POP_SCALE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.44)
	tween.tween_property(wrapper, "position", _animation_local(global_end) - wrapper.size * 0.5, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(wrapper, "scale", PREPARE_DISH_LAND_SCALE, 0.28)
	tween.parallel().tween_property(wrapper, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(wrapper.queue_free)


func _prepare_participant_name(event: Dictionary) -> String:
	var name := str(event.get("participantName", "")).strip_edges()
	if name != "":
		return name
	var participant_id := str(event.get("participantId", "")).strip_edges()
	if participant_id == "":
		participant_id = _viewer_id()
	return _participant_name(participant_id)


func _animate_prepare_announcement(participant_name: String, dish_name: String, _global_anchor: Vector2, delay := 0.0) -> void:
	if not is_instance_valid(_animation_layer):
		return
	var clean_name := participant_name.strip_edges()
	if clean_name == "":
		clean_name = "Someone"
	var clean_dish := dish_name.strip_edges()
	if clean_dish == "":
		clean_dish = "dish"
	var text := "%s prepared %s!" % [clean_name, clean_dish]
	debug_stats["lastPrepareAnnouncement"] = text

	var table_rect := get_global_rect()
	if table_rect.size.x <= 0.0 or table_rect.size.y <= 0.0:
		return
	var max_width := maxf(220.0, minf(640.0, table_rect.size.x - 32.0))
	var min_width := minf(300.0, max_width)
	var width := clampf(float(text.length()) * 14.5 + 54.0, min_width, max_width)
	var chars_per_line := maxi(12, int(floor((width - 50.0) / 14.5)))
	var line_count := maxi(1, int(ceil(float(text.length()) / float(chars_per_line))))
	var height := clampf(58.0 + float(line_count) * 28.0, 86.0, 142.0)
	var target := table_rect.get_center()
	target.x = clampf(target.x, table_rect.position.x + width * 0.5 + 16.0, table_rect.end.x - width * 0.5 - 16.0)
	target.y = clampf(target.y, table_rect.position.y + height * 0.5 + 16.0, table_rect.end.y - height * 0.5 - 16.0)
	debug_stats["lastPrepareAnnouncementGlobalCenter"] = target
	debug_stats["lastPrepareAnnouncementTableCenter"] = table_rect.get_center()
	debug_stats["lastPrepareAnnouncementSize"] = Vector2(width, height)
	debug_stats["lastPrepareAnnouncementCharacterCount"] = text.length()
	debug_stats["lastPrepareAnnouncementHoldSeconds"] = PREPARE_ANNOUNCEMENT_HOLD_SECONDS

	var card := PanelContainer.new()
	card.name = "PrepareAnnouncement"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(width, height)
	card.pivot_offset = card.size * 0.5
	card.position = _animation_local(target) - card.size * 0.5
	card.scale = Vector2(0.82, 0.82)
	card.modulate = Color(1, 1, 1, 0)
	card.add_theme_stylebox_override("panel", _prepare_announcement_style())
	_animation_layer.add_child(card)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.32, 0.16, 0.05))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.66))
	label.add_theme_constant_override("outline_size", 3)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(label)

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(PREPARE_ANNOUNCEMENT_HOLD_SECONDS)
	tween.tween_property(card, "position", card.position + Vector2(0, -12), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "modulate", Color(1, 1, 1, 0), 0.22)
	tween.tween_callback(card.queue_free)


func _animate_prepare_ingredient_swirl(global_center: Vector2) -> void:
	if not _is_usable_animation_point(global_center) or not is_instance_valid(_animation_layer):
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
	if not texture is Texture2D or not _is_usable_animation_point(global_start) or not _is_usable_animation_point(global_center):
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
	if not texture is Texture2D or not _is_usable_animation_point(global_center) or not is_instance_valid(_animation_layer):
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
	if not _is_usable_animation_point(center):
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
	panel.name = "AnimationPulse"
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
	if not _is_usable_animation_point(global_center) or not is_instance_valid(_animation_layer):
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
	if not _is_usable_animation_point(global_center) or not is_instance_valid(_animation_layer):
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
	if not _is_usable_animation_point(global_center) or not is_instance_valid(_animation_layer):
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


func _participant_opening_count(participant: Dictionary) -> int:
	if participant.has("openingOfferingsCount"):
		return int(participant.get("openingOfferingsCount", 0))
	return OPENING_OFFERINGS_PER_PLAYER if bool(participant.get("depositedInitial", false)) else 0


func _deposit_participant_sequence_from_transactions(snapshot: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_transaction in snapshot.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Deposit":
			continue
		var participant_id := str(transaction.get("participantId", ""))
		if participant_id != "":
			ids.append(participant_id)
	return ids


func _deposit_participant_order_from_transactions(snapshot: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for participant_id in _deposit_participant_sequence_from_transactions(snapshot):
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
				"unitSingular": str(part.get("unitSingular", "part")),
				"unitPlural": str(part.get("unitPlural", "parts")),
				"makerParticipantId": str(part.get("makerParticipantId", ""))
			}
		var row: Dictionary = counts[dish_id]
		row["count"] = int(row.get("count", 0)) + maxi(1, int(part.get("count", 1)))
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


func _recipe_dish_name(recipe: Dictionary) -> String:
	if recipe.is_empty():
		return ""
	var dish_name := str(recipe.get("dishName", "")).strip_edges()
	if dish_name != "" and not _is_generic_recipe_label(dish_name):
		return dish_name
	var name := str(recipe.get("name", "")).strip_edges()
	if name != "" and not _is_generic_recipe_label(name):
		return name
	return ""


func _is_generic_recipe_label(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized == "recipe" \
		or normalized == "recipe ingredients" \
		or normalized == "ingredients" \
		or normalized == "food to share" \
		or normalized == "dish pieces held" \
		or normalized == "dishes made"


func _recipe_title(recipe_name: String) -> String:
	var target := int(_snapshot.get("targetDishCount", 0))
	var viewer := _participant_by_id(_viewer_id())
	var viewer_name := str(viewer.get("name", "")).strip_edges() if not viewer.is_empty() else ""
	var owner_prefix := "%s's " % viewer_name if viewer_name != "" else ""
	if target <= 0:
		return "%sRecipe: %s" % [owner_prefix, recipe_name]
	var completed := int(viewer.get("dishCount", 0)) if not viewer.is_empty() else 0
	return "%sRecipe %s/%s: %s" % [owner_prefix, completed, target, recipe_name]


func _set_plain_recipe_title(text: String) -> void:
	if not is_instance_valid(_recipe_title_row):
		return
	if _recipe_title_pulse_tween != null and _recipe_title_pulse_tween.is_valid():
		_recipe_title_pulse_tween.kill()
	_recipe_title_pulse_tween = null
	_recipe_title_row.visible = text.strip_edges() != ""
	_recipe_title_row.custom_minimum_size = Vector2(RECIPE_GRID_SIZE.x, 22)
	_recipe_title_prefix_label.text = ""
	_recipe_title_prefix_label.visible = false
	_recipe_title_stars.visible = false
	_recipe_title_stars.modulate = Color(1, 1, 1, 1)
	_recipe_name_label.visible = true
	_recipe_name_label.text = text
	_recipe_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_name_label.add_theme_color_override("font_color", TEXT_DARK)
	_recipe_name_label.add_theme_constant_override("outline_size", 0)
	_recipe_name_label.custom_minimum_size = Vector2(RECIPE_GRID_SIZE.x, 20)
	_recipe_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _set_active_recipe_title(recipe_name: String) -> void:
	if not is_instance_valid(_recipe_title_row):
		return
	if _recipe_title_pulse_tween != null and _recipe_title_pulse_tween.is_valid():
		_recipe_title_pulse_tween.kill()
	_recipe_title_pulse_tween = null
	_recipe_title_row.visible = true
	_recipe_title_row.custom_minimum_size = Vector2(0, 0)
	_recipe_title_prefix_label.visible = true
	_recipe_title_prefix_label.custom_minimum_size = Vector2(112, 20)
	_recipe_title_prefix_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_recipe_title_stars.visible = true
	_recipe_title_stars.modulate = Color(1, 1, 1, 1)
	_recipe_name_label.visible = true
	_recipe_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_recipe_name_label.add_theme_color_override("font_color", TEXT_DARK)
	_recipe_name_label.add_theme_constant_override("outline_size", 0)
	_recipe_name_label.custom_minimum_size = Vector2(178, 20)
	_recipe_name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var target := int(_snapshot.get("targetDishCount", 0))
	var viewer := _participant_by_id(_viewer_id())
	var viewer_name := str(viewer.get("name", "")).strip_edges() if not viewer.is_empty() else ""
	var owner_prefix := "%s's " % viewer_name if viewer_name != "" else ""
	_recipe_title_prefix_label.text = "%sRecipe" % owner_prefix
	_recipe_name_label.text = ": %s" % recipe_name
	if target <= 0:
		_recipe_title_stars.visible = false
		return
	var completed := int(viewer.get("dishCount", 0)) if not viewer.is_empty() else 0
	_recipe_title_stars.set_progress(completed, target, completed >= target)
	if completed >= target:
		_recipe_title_pulse_tween = _start_star_pulse(_recipe_title_stars)


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
	wrapper.clip_contents = true
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _real_ingredient_slot_style() if status == "redeemed" else _recipe_slot_panel_style(bg, border))
	wrapper.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0 if status == "redeemed" else 1)
	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = RECIPE_SLOT_REDEEMED_ICON_SIZE if status == "redeemed" else RECIPE_SLOT_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1, 1, 1, 1) if status == "redeemed" else Color(0.55, 0.55, 0.55, 0.72)
		box.add_child(icon)
	var label := _label(_recipe_ingredient_display(ingredient_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 23)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", RECIPE_SLOT_LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_DARK if status == "redeemed" else Color(0.30, 0.30, 0.28))
	box.add_child(label)
	panel.add_child(box)
	if status == "redeemed":
		wrapper.add_child(_recipe_checkmark_overlay(ingredient_id, index))
	return wrapper


func _recipe_checkmark_overlay(ingredient_id: String, index: int) -> CheckmarkBadge:
	var check := CheckmarkBadge.new()
	check.name = "RecipeCheck_%s_%s" % [ingredient_id, index]
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _platter_food_group_for_dish_id(dish_id: String) -> Dictionary:
	if dish_id == "":
		return {}
	for raw_group in _food_part_group_options(_snapshot.get("platterFoodParts", [])):
		var group: Dictionary = raw_group
		if str(group.get("dishId", "")) == dish_id:
			return group
	return {}


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
				"makerParticipantId": str(part.get("makerParticipantId", "")),
				"count": 0
			}
			order.append(dish_id)
		var group: Dictionary = by_dish[dish_id]
		group["count"] = int(group.get("count", 0)) + 1
	var options: Array = []
	for dish_id in order:
		options.append(by_dish[dish_id])
	return options


func _dish_piece_tooltip(group: Dictionary) -> String:
	var dish_name := str(group.get("dishName", "Dish")).strip_edges()
	if dish_name == "":
		dish_name = "Dish"
	var count := int(group.get("count", 0))
	var unit := str(group.get("unitPlural" if count != 1 else "unitSingular", "parts" if count != 1 else "part")).strip_edges()
	if unit == "":
		unit = "parts" if count != 1 else "part"
	var maker_id := str(group.get("makerParticipantId", "")).strip_edges()
	var maker_name := _participant_name(maker_id).strip_edges() if maker_id != "" else ""
	if maker_name != "" and maker_name != "Someone":
		return "%s's %s - %s %s" % [maker_name, dish_name, count, unit]
	return "%s - %s %s" % [dish_name, count, unit]


func _food_piece_info_key_for_group(group: Dictionary) -> String:
	var dish_id := str(group.get("dishId", "")).strip_edges()
	var maker_id := str(group.get("makerParticipantId", "")).strip_edges()
	var dish_name := str(group.get("dishName", "")).strip_edges()
	if dish_id == "":
		dish_id = dish_name
	return "%s|%s" % [maker_id, dish_id]


func _food_piece_info_group_for_key(location: String, key: String) -> Dictionary:
	if key == "":
		return {}
	var parts: Array = []
	if location == "hand":
		parts = _snapshot.get("ownFoodParts", [])
	else:
		parts = _snapshot.get("platterFoodParts", [])
	for raw_group in _food_part_group_options(parts):
		var group: Dictionary = raw_group
		if _food_piece_info_key_for_group(group) == key:
			return group
	return {}


func _open_food_piece_info_popup(group: Dictionary, location: String) -> void:
	_food_piece_info_key = _food_piece_info_key_for_group(group)
	_food_piece_info_location = location
	_render_food_piece_info_popup(group)


func _connect_food_piece_info_double_tap(button: Control, group: Dictionary, location: String) -> void:
	if not is_instance_valid(button):
		return
	button.gui_input.connect(func(event: InputEvent, g := group, loc := location) -> void:
		_on_food_piece_info_input(event, g, loc)
	)


func _on_food_piece_info_input(event: InputEvent, group: Dictionary, location: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			_open_food_piece_info_popup(group, location)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and touch_event.double_tap:
			_open_food_piece_info_popup(group, location)
			get_viewport().set_input_as_handled()


func _refresh_food_piece_info_popup() -> void:
	if _active_popup_kind != "food_piece" or not is_instance_valid(_offer_popup) or not _offer_popup.visible:
		return
	var group := _food_piece_info_group_for_key(_food_piece_info_location, _food_piece_info_key)
	if group.is_empty():
		_offer_popup.hide()
		_active_popup_kind = ""
		_food_piece_info_key = ""
		_food_piece_info_location = ""
		_food_piece_info_last_text = ""
		return
	var next_text := _dish_piece_tooltip(group)
	if next_text == _food_piece_info_last_text:
		return
	_render_food_piece_info_popup(group)


func _render_food_piece_info_popup(group: Dictionary) -> void:
	var info_text := _dish_piece_tooltip(group)
	_food_piece_info_last_text = info_text
	_clear(_offer_popup_list)
	_prepare_offer_popup_content(292)
	_active_popup_kind = "food_piece"
	_offer_popup_list.add_child(_offer_popup_header("Food Piece"))
	_offer_popup_list.add_child(_offer_popup_text(info_text))
	var summary := _offer_dish_part_summary_from_part({
		"dishId": str(group.get("dishId", "")),
		"dishName": str(group.get("dishName", "Dish")),
		"unitSingular": str(group.get("unitSingular", "piece")),
		"unitPlural": str(group.get("unitPlural", "pieces")),
		"makerParticipantId": str(group.get("makerParticipantId", ""))
	}, int(group.get("count", 1)))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_offer_asset_card("", summary, "FoodPieceInfoCard"))
	_offer_popup_list.add_child(center)
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_offer_popup_list.add_child(bottom_spacer)
	_popup_centered_tight(324, 220, false)


func _hand_group_for_ingredient(ingredient_id: String) -> Dictionary:
	return _voucher_group_for_ingredient(_snapshot.get("ownHand", []), ingredient_id)


func _voucher_group_for_ingredient(vouchers: Array, ingredient_id: String) -> Dictionary:
	for raw_group in _voucher_group_options(vouchers):
		var group: Dictionary = raw_group
		if str(group.get("ingredientId", "")) == ingredient_id:
			return group
	return {}


func _matching_hand_voucher_ids(ingredient_id: String, quantity: int, owner_participant_id := "") -> Array:
	var ids: Array = []
	for raw_voucher in _snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) != ingredient_id:
			continue
		if owner_participant_id != "" and str(voucher.get("ownerParticipantId", "")) != owner_participant_id:
			continue
		if not _voucher_has_stock(voucher):
			continue
		ids.append(str(voucher.get("id", "")))
		if ids.size() >= quantity:
			break
	return ids


func _matching_own_food_part_refs(dish_id: String, maker_participant_id: String, quantity: int) -> Array:
	var refs: Array = []
	for raw_part in _snapshot.get("ownFoodParts", []):
		var part: Dictionary = raw_part
		if dish_id != "" and str(part.get("dishId", "")) != dish_id:
			continue
		if maker_participant_id != "" and str(part.get("makerParticipantId", "")) != maker_participant_id:
			continue
		refs.append({"kind": "dish_part", "id": part.get("id", "")})
		if refs.size() >= quantity:
			break
	return refs


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


func _participant_display_name(participant: Dictionary, fallback := "Player") -> String:
	var name := str(participant.get("name", "")).strip_edges()
	if str(participant.get("kind", "")) == "bot":
		name = _strip_bot_display_suffix(name)
	if name == "":
		return fallback
	return name


func _strip_bot_display_suffix(name: String) -> String:
	var trimmed := name.strip_edges()
	for suffix in ["_pool_bot", "_barter_bot", "_mixed_bot", "_mix_bot", "_bot", "_b"]:
		if trimmed.ends_with(suffix) and trimmed.length() > suffix.length():
			return trimmed.substr(0, trimmed.length() - suffix.length()).strip_edges()
	var numbered_suffix_marker := "_b_"
	var marker_index := trimmed.rfind(numbered_suffix_marker)
	if marker_index > 0:
		var suffix_number := trimmed.substr(marker_index + numbered_suffix_marker.length())
		if suffix_number.is_valid_int():
			return trimmed.substr(0, marker_index).strip_edges()
	return trimmed


func _viewer_id() -> String:
	return str(_snapshot.get("viewerParticipantId", ""))


func _participant_name(participant_id: String) -> String:
	var participant := _participant_by_id(participant_id)
	return _participant_display_name(participant, "Someone") if not participant.is_empty() else "Someone"


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
	var active_phase := phase == "playing" or phase == "settlement"
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


func _ingredient_card_display(ingredient_id: String) -> String:
	if ingredient_id == "vegetables":
		return "Veg."
	return _ingredient_display(ingredient_id)


func _counted_ingredient_card_label(ingredient_id: String, count: int) -> String:
	return "%s x%s" % [_ingredient_card_display(ingredient_id), count]


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
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)
	return box


func _framed_box(content: Control) -> PanelContainer:
	var panel := FixedPanelContainer.new()
	panel.fixed_minimum_size = Vector2(ACTION_PANEL_MIN_WIDTH, ACTION_PANEL_FIXED_HEIGHT)
	panel.custom_minimum_size = panel.fixed_minimum_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _action_panel_style())
	panel.add_child(content)
	return panel


func _scroll_wrap(child: Control, min_height: int) -> ScrollContainer:
	var scroll := FixedScrollContainer.new()
	scroll.fixed_minimum_size = Vector2(0, min_height)
	scroll.custom_minimum_size = Vector2(0, min_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.clip_contents = true
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
	_add_card_stack_layers(button, meta)
	_add_visual_content(button, top_text, bottom_text, meta, minimum, _contrast_ink(meta.get("color", Color(0.8, 0.8, 0.8))), true)
	_add_card_inset_outline(button, Color(0.30, 0.35, 0.42), 1)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _card_meta_with_stack(meta: Dictionary, count: int) -> Dictionary:
	var stacked := meta.duplicate(true)
	stacked["stacked_card"] = count > 1
	stacked["stack_count"] = count
	return stacked


func _add_card_stack_layers(button: Button, meta: Dictionary) -> void:
	if not bool(meta.get("stacked_card", false)):
		return
	var stack_count := clampi(int(meta.get("stack_count", 0)), 1, 3)
	var layers := stack_count - 1
	if layers <= 0:
		return
	var base_color: Color = meta.get("color", Color(0.8, 0.8, 0.8))
	var border_color := Color(1.0, 0.98, 0.88, 0.80)
	for layer_index in range(layers, 0, -1):
		var layer := PanelContainer.new()
		layer.name = "CardStackLayer_%s" % layer_index
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		var offset := layer_index * 3
		layer.offset_left = offset
		layer.offset_top = 0
		layer.offset_right = 0
		layer.offset_bottom = -offset
		var style := _panel_style(Color(base_color.r, base_color.g, base_color.b, 0.08), border_color, 1, 8)
		style.content_margin_left = 0
		style.content_margin_top = 0
		style.content_margin_right = 0
		style.content_margin_bottom = 0
		layer.add_theme_stylebox_override("panel", style)
		button.add_child(layer)


func _player_tile(top_text: String, bottom_text: String, meta: Dictionary, avatar_texture: Texture2D, offer_indicator: String, is_turn: bool, completed_dishes: int, target_dishes: int, minimum: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	_apply_plain_item_style(button)
	if is_turn:
		_add_turn_circle(button)
	_add_player_tile_content(button, top_text, bottom_text, meta, avatar_texture, offer_indicator, is_turn, completed_dishes, target_dishes)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _add_player_tile_content(button: Button, top_text: String, bottom_text: String, meta: Dictionary, avatar_texture: Texture2D, offer_indicator: String, is_turn: bool, completed_dishes: int, target_dishes: int) -> void:
	var turn_ink := Color(0.34, 0.18, 0.04)
	var turn_outline := Color(1.0, 0.78, 0.18, 0.92)
	var name := _card_label(top_text, turn_ink if is_turn else TEXT_DARK, 13)
	name.name = "CookNameLabel"
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.clip_text = true
	name.add_theme_color_override("font_outline_color", turn_outline if is_turn else Color(0.96, 0.90, 0.72, 0.88))
	name.add_theme_constant_override("outline_size", 2 if is_turn else 1)
	if target_dishes > 0 and completed_dishes >= target_dishes:
		_apply_star_completion_style(name)
	_place_overlay(name, 2, 0, -40, 22)
	button.add_child(name)
	if target_dishes > 0:
		var stars := ProgressStars.new()
		stars.name = "CookProgressStars"
		stars.set_star_size(10.0)
		stars.set_progress(completed_dishes, target_dishes, completed_dishes >= target_dishes)
		if completed_dishes >= target_dishes:
			_start_star_pulse(stars)
		_place_overlay(stars, 88, 5, -2, 17)
		button.add_child(stars)

	var texture = meta.get("texture", null)
	if texture is Texture2D:
		var icon := TextureRect.new()
		icon.name = "CookIngredientIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_place_center_fixed_overlay(icon, -44, 18, 50, 50)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
	else:
		var mark := _card_label(str(meta.get("mark", "??")), TEXT_DARK, 13)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_center_fixed_overlay(mark, -44, 22, 50, 42)
		button.add_child(mark)

	if avatar_texture is Texture2D:
		var avatar := TextureRect.new()
		avatar.name = "CookAvatar"
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.texture = avatar_texture
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_place_center_fixed_overlay(avatar, 12, 27, 32, 32)
		button.add_child(avatar)

	var ingredient := _card_label(bottom_text, turn_ink if is_turn else TEXT_DARK, 14)
	ingredient.name = "CookIngredientLabel"
	ingredient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ingredient.autowrap_mode = TextServer.AUTOWRAP_OFF
	ingredient.add_theme_color_override("font_outline_color", turn_outline if is_turn else Color(0.96, 0.90, 0.72, 0.92))
	ingredient.add_theme_constant_override("outline_size", 2 if is_turn else 1)
	_place_overlay(ingredient, 0, -25, 0, -2)
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
	var stack_gap := 5 if bool(meta.get("stacked_card", false)) else 0

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
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_place_overlay(icon, pad, pad + top_band, -pad, -(bottom_band + pad + stack_gap))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
	else:
		var mark := _visual_text_label(str(meta.get("mark", "??")), ink)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_overlay(mark, pad, pad + top_band, -pad, -(bottom_band + pad + stack_gap))
		button.add_child(mark)

	var bottom := _visual_text_label(bottom_text, ink)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_overlay(bottom, pad, -(bottom_band + stack_gap), -pad, -(pad + stack_gap))
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


func _place_center_fixed_overlay(control: Control, left_from_center: int, top: int, width: int, height: int) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0
	control.anchor_bottom = 0
	control.offset_left = left_from_center
	control.offset_top = top
	control.offset_right = left_from_center + width
	control.offset_bottom = top + height


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


func _add_card_inset_outline(button: Button, border: Color, border_width: int) -> void:
	var outline := PanelContainer.new()
	outline.name = "CardInsetOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = 1
	outline.offset_top = 1
	outline.offset_right = -1
	outline.offset_bottom = -1
	button.add_child(outline)
	_update_card_inset_outline(button, border, border_width)


func _update_card_inset_outline(button: Button, border: Color, border_width: int) -> void:
	var outline := button.get_node_or_null("CardInsetOutline") as PanelContainer
	if outline == null:
		return
	var style := _panel_style(Color(0, 0, 0, 0), border, clampi(border_width, 1, 2), 7)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	outline.add_theme_stylebox_override("panel", style)


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
	_update_card_inset_outline(button, border, border_width)


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


func _top_menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = "TableMainMenuButton"
	button.text = text
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(108, 32)
	button.size = Vector2(108, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_DARK)
	button.add_theme_color_override("font_focus_color", TEXT_DARK)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	_apply_button_style(button, Color(0.91, 0.80, 0.58), Color(0.46, 0.32, 0.18), 1)
	button.pressed.connect(callback)
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


func _action_label(text: String) -> FixedLabel:
	var label := FixedLabel.new()
	label.name = "ActionStatusLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_height := _action_label_height(text)
	label.fixed_minimum_size = Vector2(206, label_height)
	label.custom_minimum_size = Vector2(206, label_height)
	label.clip_text = true
	return label


func _action_label_height(text: String) -> int:
	var length := text.strip_edges().length()
	if length <= 24:
		return ACTION_LABEL_SHORT_HEIGHT
	if length <= 42:
		return ACTION_LABEL_MEDIUM_HEIGHT
	return ACTION_LABEL_LONG_HEIGHT


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


func _offer_popup_wrapped_text(text: String, width: int) -> Label:
	var label := _offer_popup_text(text)
	label.custom_minimum_size = Vector2(width, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _offer_quantity_toggle_button(text: String, callback: Callable) -> Button:
	var button := _offer_popup_compact_button(text, callback)
	button.name = "OfferQuantityToggle"
	button.custom_minimum_size = Vector2(42, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 11)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, style)
	return button


func _popup_centered_tight(width: int, max_height: int, allow_scroll := false) -> void:
	_offer_popup.hide()
	_offer_popup_scroller.custom_minimum_size = Vector2(0, 0)
	_offer_popup.size = Vector2i(0, 0)
	width = _safe_popup_width(width, mini(300, width), 28)
	var content_height := int(ceil(_offer_popup_list.get_combined_minimum_size().y))
	var panel_padding := 18
	var min_height := 64
	var needs_scroll := allow_scroll and content_height + panel_padding > max_height
	_offer_popup_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED
	var height := 0
	if allow_scroll:
		height = clampi(content_height + panel_padding, min_height, max_height)
	else:
		height = maxi(min_height, content_height + panel_padding + 2)
	var content_width := maxi(180, width - panel_padding)
	_offer_popup_list.custom_minimum_size = Vector2(minf(_offer_popup_list.custom_minimum_size.x, content_width), 0)
	_offer_popup_scroller.custom_minimum_size = Vector2(content_width, height - panel_padding)
	debug_stats["offerPopupWidth"] = width
	debug_stats["offerPopupHeight"] = height
	debug_stats["offerPopupContentHeight"] = content_height
	debug_stats["offerPopupScrollEnabled"] = needs_scroll
	_offer_popup.popup_centered(Vector2i(width, height))


func _safe_popup_width(preferred_width: int, min_width: int, horizontal_margin: int) -> int:
	var viewport_width := int(get_viewport_rect().size.x)
	var available := preferred_width
	if viewport_width > 0:
		available = mini(preferred_width, maxi(220, viewport_width - horizontal_margin))
	return clampi(available, mini(min_width, available), preferred_width)


func _board_surface_style() -> StyleBoxFlat:
	var style := _panel_style(BOARD_PANEL_BG, Color(0.46, 0.38, 0.25), 1, 8)
	_apply_surface_panel_metrics(style, BOARD_PANEL_MARGIN_X, BOARD_PANEL_MARGIN_Y)
	style.shadow_color = Color(0.18, 0.12, 0.06, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _inventory_surface_style() -> StyleBoxFlat:
	var style := _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	_apply_surface_panel_metrics(style, 0, 0)
	return style


func _inventory_upper_panel_style() -> StyleBoxFlat:
	var style := _panel_style(INVENTORY_UPPER_PANEL_BG, Color(0.43, 0.31, 0.17), 1, 6)
	_apply_surface_panel_metrics(style, INVENTORY_SECTION_MARGIN_X, INVENTORY_SECTION_MARGIN_Y)
	style.shadow_color = Color(0.18, 0.11, 0.05, 0.16)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _inventory_lower_panel_style() -> StyleBoxFlat:
	var style := _panel_style(INVENTORY_LOWER_PANEL_BG, Color(0.35, 0.23, 0.12), 1, 6)
	_apply_surface_panel_metrics(style, INVENTORY_SECTION_MARGIN_X, INVENTORY_SECTION_MARGIN_Y)
	style.shadow_color = Color(0.14, 0.08, 0.03, 0.18)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _action_panel_style() -> StyleBoxFlat:
	var style := _panel_style(ACTION_PANEL_BG, Color(0.55, 0.44, 0.28), 1, 8)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _apply_surface_panel_metrics(style: StyleBoxFlat, horizontal_margin: int, vertical_margin: int) -> void:
	style.content_margin_left = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_bottom = vertical_margin


func _offer_popup_panel_style() -> StyleBoxFlat:
	var style := _panel_style(PANEL_BG, PANEL_BORDER, 1, 10)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 10
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


func _recipe_slot_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(bg, border, 1, RECIPE_SLOT_RADIUS)
	style.content_margin_left = RECIPE_SLOT_CONTENT_MARGIN
	style.content_margin_top = RECIPE_SLOT_CONTENT_MARGIN
	style.content_margin_right = RECIPE_SLOT_CONTENT_MARGIN
	style.content_margin_bottom = RECIPE_SLOT_CONTENT_MARGIN
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


func _prepare_announcement_style() -> StyleBoxFlat:
	var style := _panel_style(Color(1.0, 0.88, 0.48, 0.98), Color(0.58, 0.31, 0.08), 2, 16)
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.34, 0.18, 0.04, 0.36)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
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
