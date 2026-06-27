extends Control

const MODE_BACKGROUND := "background"
const MODE_TABLE_PANEL := "table_panel"

var mode := MODE_BACKGROUND
var base_color := Color(0.78, 0.70, 0.52)
var tile_size := Vector2(44, 44)
var stripe_color := Color(1.0, 0.94, 0.78, 0.10)
var cross_color := Color(0.45, 0.34, 0.20, 0.07)
var thread_color := Color(1.0, 0.96, 0.84, 0.10)
var shadow_color := Color(0.25, 0.17, 0.09, 0.06)


func configure_background() -> void:
	mode = MODE_BACKGROUND
	name = "AppTableclothBackground"
	base_color = Color(0.80, 0.72, 0.54)
	tile_size = Vector2(48, 48)
	stripe_color = Color(0.92, 0.84, 0.64, 0.14)
	cross_color = Color(0.50, 0.39, 0.23, 0.07)
	thread_color = Color(1.0, 0.95, 0.80, 0.08)
	shadow_color = Color(0.34, 0.24, 0.12, 0.045)
	queue_redraw()


func configure_table_panel() -> void:
	mode = MODE_TABLE_PANEL
	name = "MainTableclothPattern"
	base_color = Color(0.89, 0.85, 0.74)
	tile_size = Vector2(34, 34)
	stripe_color = Color(0.98, 0.92, 0.74, 0.13)
	cross_color = Color(0.48, 0.39, 0.25, 0.055)
	thread_color = Color(1.0, 0.96, 0.82, 0.10)
	shadow_color = Color(0.34, 0.24, 0.12, 0.035)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), base_color)
	_draw_tiles()
	_draw_threads()


func _draw_tiles() -> void:
	var tw := maxf(8.0, tile_size.x)
	var th := maxf(8.0, tile_size.y)
	var cols := int(ceil(size.x / tw)) + 1
	var rows := int(ceil(size.y / th)) + 1
	for col in range(cols):
		var x := float(col) * tw
		if col % 2 == 0:
			draw_rect(Rect2(Vector2(x, 0), Vector2(tw * 0.48, size.y)), stripe_color)
		draw_rect(Rect2(Vector2(x + tw - 1.0, 0), Vector2(1.0, size.y)), shadow_color)
	for row in range(rows):
		var y := float(row) * th
		if row % 2 == 0:
			draw_rect(Rect2(Vector2(0, y), Vector2(size.x, th * 0.44)), cross_color)
		draw_rect(Rect2(Vector2(0, y + th - 1.0), Vector2(size.x, 1.0)), shadow_color)


func _draw_threads() -> void:
	var tw := maxf(8.0, tile_size.x)
	var th := maxf(8.0, tile_size.y)
	var thread_step_x := tw * 0.5
	var thread_step_y := th * 0.5
	var x := thread_step_x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), thread_color, 1.0)
		x += thread_step_x
	var y := thread_step_y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), thread_color, 1.0)
		y += thread_step_y
