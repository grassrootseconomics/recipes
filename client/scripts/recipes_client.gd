extends Node

signal snapshot_received(snapshot: Dictionary)
signal error_received(error: Dictionary)
signal connection_changed(status: String)
signal server_debug_received(debug: Dictionary)

const RECONNECT_DELAY_SECONDS := 1.5
const SOCKET_WATCHDOG_FRESH_SNAPSHOT_MS := 20000
const SOCKET_WATCHDOG_RECONNECT_MS := 8000
const SOCKET_WATCHDOG_CHECK_MS := 1000
const SOCKET_WATCHDOG_VISUAL_BUSY_GRACE_MS := 3000
const OfflineStore := preload("res://scripts/offline_store.gd")

var server_url := "http://127.0.0.1:3000"
var table_code := ""
var participant_id := ""
var seat_token := ""
var acting_participant_id := ""
var latest_snapshot: Dictionary = {}
var last_close_description := ""
var offline_mode := false
var ignored_stale_snapshot_count := 0
var auto_fresh_snapshot_count := 0
var manual_fresh_snapshot_count := 0
var watchdog_fresh_snapshot_count := 0
var watchdog_reconnect_count := 0
var last_socket_message_type := ""
var last_socket_error_description := ""
var last_heartbeat_msec := 0
var last_heartbeat: Dictionary = {}
var last_server_debug: Dictionary = {}
var last_server_debug_msec := 0
var last_server_debug_error := ""
var visual_busy := false

var _http_request: HTTPRequest
var _debug_http_request: HTTPRequest
var _offline_store: Node
var _websocket := WebSocketPeer.new()
var _socket_open := false
var _reported_open := false
var _should_reconnect := false
var _reconnect_delay := -1.0
var _reconnect_attempt := 0
var _next_client_intent_id := 1
var _last_socket_message_msec := 0
var _fresh_snapshot_request_started_msec := 0
var _fresh_snapshot_request_in_flight := false
var _next_socket_watchdog_check_msec := 0
var _last_visual_busy_msec := 0


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 10.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)
	_debug_http_request = HTTPRequest.new()
	_debug_http_request.timeout = 10.0
	add_child(_debug_http_request)
	_debug_http_request.request_completed.connect(_on_debug_http_request_completed)
	_offline_store = OfflineStore.new()
	add_child(_offline_store)
	_offline_store.snapshot_received.connect(_on_offline_snapshot_received)
	_offline_store.error_received.connect(func(error: Dictionary) -> void:
		error_received.emit(error)
	)
	_offline_store.connection_changed.connect(func(status: String) -> void:
		connection_changed.emit(status)
	)


func _process(_delta: float) -> void:
	if not _socket_open:
		if _should_reconnect and table_code != "" and seat_token != "" and _reconnect_delay >= 0.0:
			_reconnect_delay -= _delta
			if _reconnect_delay <= 0.0:
				connect_socket()
		return
	_websocket.poll()
	var state := _websocket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _reported_open:
			_reported_open = true
			_reconnect_attempt = 0
			last_close_description = ""
			_last_socket_message_msec = Time.get_ticks_msec()
			connection_changed.emit("open")
		while _websocket.get_available_packet_count() > 0:
			var text := _websocket.get_packet().get_string_from_utf8()
			_handle_socket_message(text)
		_watch_socket_freshness()
	elif state == WebSocketPeer.STATE_CLOSED:
		_socket_open = false
		_reported_open = false
		_fresh_snapshot_request_in_flight = false
		last_close_description = _close_description()
		if _should_reconnect and table_code != "" and seat_token != "":
			_reconnect_attempt += 1
			_reconnect_delay = RECONNECT_DELAY_SECONDS
			connection_changed.emit("reconnecting")
		else:
			connection_changed.emit("closed")


func create_table(host_name: String, seed: String = "", requested_code: String = "") -> void:
	offline_mode = false
	var body := {"hostName": host_name}
	if seed.strip_edges() != "":
		body["seed"] = seed.strip_edges()
	if requested_code.strip_edges() != "":
		body["requestedCode"] = requested_code.strip_edges().to_upper()
	_post_json("%s/tables" % server_url, body)


func join_table(code: String, player_name: String, as_witness := false) -> void:
	offline_mode = false
	_post_json("%s/tables/%s/join" % [server_url, code.strip_edges().to_upper()], {"name": player_name, "asWitness": as_witness})


func resume_online_session(resume_server_url: String, code: String, stored_participant_id: String, stored_seat_token: String) -> bool:
	var normalized_code := code.strip_edges().to_upper()
	if resume_server_url.strip_edges() == "" or normalized_code == "" or stored_seat_token.strip_edges() == "":
		error_received.emit({"description": "Saved table session is incomplete."})
		return false
	if _socket_open:
		_websocket.close()
	_socket_open = false
	_reported_open = false
	_should_reconnect = false
	_reconnect_delay = -1.0
	offline_mode = false
	server_url = resume_server_url.strip_edges().trim_suffix("/")
	table_code = normalized_code
	participant_id = stored_participant_id
	acting_participant_id = stored_participant_id
	seat_token = stored_seat_token
	latest_snapshot = {}
	connect_socket()
	return true


func start_offline_table(host_name: String, seed: String = "") -> void:
	if _socket_open:
		_websocket.close()
	_socket_open = false
	_reported_open = false
	_should_reconnect = false
	_reconnect_delay = -1.0
	offline_mode = true
	table_code = "OFFLINE"
	participant_id = "p1"
	acting_participant_id = "p1"
	seat_token = "offline:p1"
	_offline_store.create_table(host_name, seed)


func send_intent(intent: Dictionary, actor_participant_id := "") -> bool:
	if offline_mode:
		var selected_actor := actor_participant_id
		if selected_actor == "":
			selected_actor = acting_participant_id
		if selected_actor == "":
			selected_actor = participant_id
		return _offline_store.handle_intent(intent, selected_actor)
	if not _socket_open or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_received.emit({"description": "WebSocket is not connected."})
		return false
	var client_intent_id := "%s:%s" % [participant_id, _next_client_intent_id]
	_next_client_intent_id += 1
	var envelope := {
		"type": "intent",
		"clientIntentId": client_intent_id,
		"intent": intent
	}
	var selected_actor := actor_participant_id
	if selected_actor == "":
		selected_actor = acting_participant_id
	if selected_actor != "" and selected_actor != participant_id:
		envelope["actorParticipantId"] = selected_actor
	var err := _websocket.send_text(JSON.stringify(envelope))
	if err != OK:
		error_received.emit({"description": "WebSocket send failed: %s" % err})
		return false
	return true


func send_host_intent(intent: Dictionary) -> bool:
	return send_intent(intent, participant_id)


func view_as(participant_id_to_view: String) -> bool:
	if participant_id_to_view == "":
		return false
	acting_participant_id = participant_id_to_view
	if offline_mode:
		return _offline_store.view_as(participant_id_to_view)
	if not _socket_open or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var err := _websocket.send_text(JSON.stringify({"type": "view", "participantId": participant_id_to_view}))
	if err != OK:
		error_received.emit({"description": "View switch failed: %s" % err})
		return false
	return true


func request_fresh_snapshot(count_as_manual := true) -> bool:
	if offline_mode:
		return false
	if not _socket_open or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_socket()
		return false
	var viewer_id := acting_participant_id
	if viewer_id == "":
		viewer_id = participant_id
	if viewer_id == "":
		connect_socket()
		return false
	var err := _websocket.send_text(JSON.stringify({"type": "view", "participantId": viewer_id}))
	if err != OK:
		connect_socket()
		return false
	if count_as_manual:
		manual_fresh_snapshot_count += 1
	_fresh_snapshot_request_started_msec = Time.get_ticks_msec()
	_fresh_snapshot_request_in_flight = true
	return true


func request_server_debug() -> bool:
	if offline_mode or table_code == "" or seat_token == "":
		return false
	if _debug_http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false
	var url := "%s/tables/%s/debug?seatToken=%s" % [server_url, table_code, seat_token]
	var err := _debug_http_request.request(url)
	if err != OK:
		last_server_debug_error = "Debug request failed to start: %s" % err
		return false
	return true


func is_socket_connected() -> bool:
	if offline_mode:
		return bool(_offline_store.call("has_active_table"))
	return _socket_open and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN


func full_transaction_history() -> Array:
	if offline_mode and _offline_store and _offline_store.has_method("full_transaction_history"):
		return _offline_store.call("full_transaction_history")
	return latest_snapshot.get("transactionHistory", []).duplicate(true)


func reconnect_attempt() -> int:
	return _reconnect_attempt


func last_heartbeat_age_ms() -> int:
	if last_heartbeat_msec <= 0:
		return -1
	return maxi(0, Time.get_ticks_msec() - last_heartbeat_msec)


func fresh_snapshot_request_age_ms() -> int:
	if not _fresh_snapshot_request_in_flight or _fresh_snapshot_request_started_msec <= 0:
		return -1
	return maxi(0, Time.get_ticks_msec() - _fresh_snapshot_request_started_msec)


func has_table_session(code: String = "") -> bool:
	if offline_mode:
		return table_code != ""
	if table_code == "" or seat_token == "":
		return false
	if code.strip_edges() == "":
		return true
	return table_code == code.strip_edges().to_upper()


func leave_table() -> void:
	if offline_mode:
		disconnect_local()
		return
	if _socket_open and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_websocket.send_text(JSON.stringify({"type": "leave_table"}))
		_websocket.poll()
	disconnect_local()


func disconnect_local() -> void:
	if offline_mode and _offline_store:
		_offline_store.disconnect_local()
	if _socket_open:
		_websocket.close()
	_socket_open = false
	_reported_open = false
	_should_reconnect = false
	_reconnect_delay = -1.0
	offline_mode = false
	table_code = ""
	participant_id = ""
	acting_participant_id = ""
	seat_token = ""
	latest_snapshot = {}
	connection_changed.emit("closed")


func connect_socket() -> void:
	if table_code == "" or seat_token == "":
		return
	if _socket_open:
		_websocket.close()
	_websocket = WebSocketPeer.new()
	_reported_open = false
	_should_reconnect = true
	_reconnect_delay = -1.0
	_last_socket_message_msec = Time.get_ticks_msec()
	last_heartbeat_msec = 0
	last_heartbeat = {}
	_fresh_snapshot_request_in_flight = false
	_fresh_snapshot_request_started_msec = 0
	var ws_url := server_url.replace("https://", "wss://").replace("http://", "ws://")
	var err := _websocket.connect_to_url("%s/tables/%s/socket?seatToken=%s" % [ws_url, table_code, seat_token])
	if err != OK:
		error_received.emit({"description": "Could not connect WebSocket: %s" % err})
		_reconnect_delay = RECONNECT_DELAY_SECONDS
		return
	_socket_open = true
	connection_changed.emit("connecting")


func _close_description() -> String:
	var code := 0
	var reason := ""
	if _websocket.has_method("get_close_code"):
		code = int(_websocket.call("get_close_code"))
	if _websocket.has_method("get_close_reason"):
		reason = str(_websocket.call("get_close_reason"))
	if code == 0 and reason == "":
		return "no close code"
	if reason == "":
		return "close code %s" % code
	return "close code %s: %s" % [code, reason]


func _post_json(url: String, body: Dictionary) -> void:
	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_request.cancel_request()
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		error_received.emit({"description": "HTTP request failed to start: %s" % err})


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		error_received.emit({"description": _http_request_failure_message(result)})
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		error_received.emit({"description": "Server returned invalid JSON."})
		return
	if response_code < 200 or response_code >= 300 or not parsed.get("ok", false):
		error_received.emit(parsed)
		return
	var response: Dictionary = parsed.get("result", {})
	offline_mode = false
	table_code = str(response.get("tableCode", ""))
	participant_id = str(response.get("participantId", ""))
	acting_participant_id = participant_id
	seat_token = str(response.get("seatToken", ""))
	latest_snapshot = response.get("snapshot", {})
	snapshot_received.emit(latest_snapshot)
	connect_socket()


func _http_request_failure_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "The server is not found.\nPlease try another server or Offline Mode."
		_:
			return "The server could not be reached.\nPlease try another server or Offline Mode."


func _on_offline_snapshot_received(snapshot: Dictionary) -> void:
	offline_mode = true
	table_code = str(snapshot.get("tableCode", "OFFLINE"))
	participant_id = str(snapshot.get("connectionParticipantId", "p1"))
	acting_participant_id = str(snapshot.get("viewerParticipantId", participant_id))
	seat_token = "offline:%s" % participant_id
	latest_snapshot = snapshot
	snapshot_received.emit(latest_snapshot)


func _handle_socket_message(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_mark_socket_message("invalid")
		error_received.emit({"description": "Invalid WebSocket JSON."})
		return
	_mark_socket_message(str(parsed.get("type", "message")))
	if parsed.get("type", "") == "snapshot":
		var incoming_snapshot: Dictionary = parsed.get("snapshot", {})
		if not _should_accept_full_snapshot(incoming_snapshot):
			ignored_stale_snapshot_count += 1
			return
		latest_snapshot = incoming_snapshot
		_fresh_snapshot_request_in_flight = false
		snapshot_received.emit(latest_snapshot)
	elif parsed.get("type", "") == "delta":
		_handle_delta_message(parsed)
	elif parsed.get("type", "") == "ack":
		if not bool(parsed.get("ok", false)):
			last_socket_error_description = str(parsed.get("description", "Socket ack failed."))
			error_received.emit(parsed)
	elif parsed.get("type", "") == "heartbeat":
		_handle_heartbeat_message(parsed)
	elif parsed.get("type", "") == "error":
		var error_code := str(parsed.get("errorCode", ""))
		if error_code == "invalid_seat_token" or error_code == "missing_table" or error_code == "seat_already_connected":
			_should_reconnect = false
			_reconnect_delay = -1.0
		last_socket_error_description = str(parsed.get("description", "Socket error."))
		error_received.emit(parsed)


func _handle_heartbeat_message(message: Dictionary) -> void:
	var heartbeat_table := str(message.get("tableCode", ""))
	if heartbeat_table != "" and table_code != "" and heartbeat_table != table_code:
		return
	last_heartbeat = message.duplicate(true)
	last_heartbeat_msec = Time.get_ticks_msec()


func _should_accept_full_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or latest_snapshot.is_empty():
		return true
	var incoming_table := str(snapshot.get("tableCode", ""))
	var current_table := str(latest_snapshot.get("tableCode", ""))
	if incoming_table == "" or current_table == "" or incoming_table != current_table:
		return true
	var incoming_version := int(snapshot.get("version", -1))
	var current_version := int(latest_snapshot.get("version", -1))
	if incoming_version >= 0 and current_version >= 0:
		if incoming_version < current_version:
			return false
		if incoming_version > current_version:
			return true
	var incoming_cursor := _snapshot_cursor(snapshot)
	var current_cursor := _snapshot_cursor(latest_snapshot)
	if incoming_cursor >= 0 and current_cursor >= 0 and incoming_cursor < current_cursor:
		return false
	return true


func _snapshot_cursor(snapshot: Dictionary) -> int:
	if snapshot.has("transactionCursor"):
		return int(snapshot.get("transactionCursor", -1))
	return int(snapshot.get("transactionHistoryTotal", snapshot.get("transactionTotal", -1)))


func _handle_delta_message(message: Dictionary) -> void:
	var base_version := int(message.get("baseVersion", -1))
	var current_version := int(latest_snapshot.get("version", -1))
	if latest_snapshot.is_empty() or current_version != base_version:
		error_received.emit({"description": "Delta was based on version %s, but cached version is %s. Reconnecting for a fresh snapshot." % [base_version, current_version]})
		connect_socket()
		return
	var patch: Dictionary = message.get("patch", {})
	var append: Dictionary = message.get("append", {})
	if _delta_missing_viewer_prepare_food_parts(latest_snapshot, patch, append):
		auto_fresh_snapshot_count += 1
		call_deferred("connect_socket")
		return
	for key in patch.keys():
		if patch[key] == null:
			latest_snapshot.erase(key)
		else:
			latest_snapshot[key] = patch[key]
	if append.has("transactionHistory"):
		var history: Array = latest_snapshot.get("transactionHistory", [])
		for raw_transaction in append.get("transactionHistory", []):
			history.append(raw_transaction)
		while history.size() > 100:
			history.remove_at(0)
		latest_snapshot["transactionHistory"] = history
	if append.has("dishes"):
		_merge_dish_rows(append.get("dishes", []))
	if append.has("participants"):
		_merge_participant_rows(append.get("participants", []))
	latest_snapshot["version"] = int(message.get("version", latest_snapshot.get("version", 0)))
	_fresh_snapshot_request_in_flight = false
	snapshot_received.emit(latest_snapshot)


func _mark_socket_message(message_type: String) -> void:
	_last_socket_message_msec = Time.get_ticks_msec()
	last_socket_message_type = message_type


func _on_debug_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		last_server_debug_error = _http_request_failure_message(result)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		last_server_debug_error = "Server debug endpoint returned invalid JSON."
		return
	if response_code < 200 or response_code >= 300 or not parsed.get("ok", false):
		last_server_debug_error = str(parsed.get("description", "Server debug request failed."))
		return
	last_server_debug = parsed.get("result", {})
	last_server_debug_msec = Time.get_ticks_msec()
	last_server_debug_error = ""
	server_debug_received.emit(last_server_debug)


func set_visual_busy(is_busy: bool) -> void:
	visual_busy = is_busy
	if is_busy:
		_last_visual_busy_msec = Time.get_ticks_msec()


func _watch_socket_freshness() -> void:
	if offline_mode or table_code == "" or seat_token == "":
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms < _next_socket_watchdog_check_msec:
		return
	_next_socket_watchdog_check_msec = now_ms + SOCKET_WATCHDOG_CHECK_MS
	var visual_busy_recent := visual_busy or (_last_visual_busy_msec > 0 and now_ms - _last_visual_busy_msec <= SOCKET_WATCHDOG_VISUAL_BUSY_GRACE_MS)
	var action := _socket_watchdog_action_for_state(
		latest_snapshot,
		is_socket_connected(),
		now_ms - _last_socket_message_msec,
		_fresh_snapshot_request_in_flight,
		now_ms - _fresh_snapshot_request_started_msec,
		visual_busy_recent
	)
	if action == "fresh_snapshot":
		watchdog_fresh_snapshot_count += 1
		request_fresh_snapshot(false)
	elif action == "reconnect":
		watchdog_reconnect_count += 1
		connect_socket()


func _socket_watchdog_action_for_state(snapshot: Dictionary, socket_connected: bool, last_message_age_ms: int, request_in_flight: bool, request_age_ms: int, visual_busy_active := false) -> String:
	if not socket_connected or snapshot.is_empty():
		return "none"
	if not _phase_needs_socket_watchdog(str(snapshot.get("phase", ""))):
		return "none"
	if visual_busy_active:
		return "none"
	if request_in_flight:
		return "reconnect" if request_age_ms >= SOCKET_WATCHDOG_RECONNECT_MS else "none"
	return "fresh_snapshot" if last_message_age_ms >= SOCKET_WATCHDOG_FRESH_SNAPSHOT_MS else "none"


func _phase_needs_socket_watchdog(phase: String) -> bool:
	return phase == "playing" or phase == "settlement" or phase == "eating"


func debug_socket_watchdog_action(snapshot: Dictionary, socket_connected: bool, last_message_age_ms: int, request_in_flight: bool, request_age_ms: int, visual_busy_active := false) -> String:
	return _socket_watchdog_action_for_state(snapshot, socket_connected, last_message_age_ms, request_in_flight, request_age_ms, visual_busy_active)


func debug_delta_missing_viewer_prepare_food_parts(previous_snapshot: Dictionary, patch: Dictionary, append: Dictionary) -> bool:
	return _delta_missing_viewer_prepare_food_parts(previous_snapshot, patch, append)


func _delta_missing_viewer_prepare_food_parts(previous_snapshot: Dictionary, patch: Dictionary, append: Dictionary) -> bool:
	var viewer_id := str(previous_snapshot.get("viewerParticipantId", ""))
	if viewer_id == "":
		return false
	var prepared_for_viewer := false
	for raw_transaction in append.get("transactionHistory", []):
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == "Prepare" and str(transaction.get("participantId", "")) == viewer_id:
			prepared_for_viewer = true
			break
	if not prepared_for_viewer:
		return false
	var previous_parts: Array = previous_snapshot.get("ownFoodParts", [])
	if not patch.has("ownFoodParts"):
		return true
	var next_parts: Array = patch.get("ownFoodParts", [])
	return next_parts.size() <= previous_parts.size()


func _merge_dish_rows(rows: Array) -> void:
	var dishes: Array = latest_snapshot.get("dishes", [])
	for raw_row in rows:
		var row: Dictionary = raw_row
		var row_id := str(row.get("id", ""))
		var replaced := false
		for index in range(dishes.size()):
			var existing: Dictionary = dishes[index]
			if str(existing.get("id", "")) == row_id:
				dishes[index] = row
				replaced = true
				break
		if not replaced:
			dishes.append(row)
	latest_snapshot["dishes"] = dishes


func _merge_participant_rows(rows: Array) -> void:
	var participants: Array = latest_snapshot.get("participants", [])
	for raw_row in rows:
		var row: Dictionary = raw_row
		var row_id := str(row.get("id", ""))
		var replaced := false
		for index in range(participants.size()):
			var existing: Dictionary = participants[index]
			if str(existing.get("id", "")) == row_id:
				participants[index] = row
				replaced = true
				break
		if not replaced:
			participants.append(row)
	latest_snapshot["participants"] = participants
