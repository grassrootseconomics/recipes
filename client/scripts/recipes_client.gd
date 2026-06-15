extends Node

signal snapshot_received(snapshot: Dictionary)
signal error_received(error: Dictionary)
signal connection_changed(status: String)

const RECONNECT_DELAY_SECONDS := 1.5

var server_url := "http://127.0.0.1:3000"
var table_code := ""
var participant_id := ""
var seat_token := ""
var latest_snapshot: Dictionary = {}
var last_close_description := ""

var _http_request: HTTPRequest
var _websocket := WebSocketPeer.new()
var _socket_open := false
var _reported_open := false
var _should_reconnect := false
var _reconnect_delay := -1.0
var _reconnect_attempt := 0
var _next_client_intent_id := 1


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)


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
			connection_changed.emit("open")
		while _websocket.get_available_packet_count() > 0:
			var text := _websocket.get_packet().get_string_from_utf8()
			_handle_socket_message(text)
	elif state == WebSocketPeer.STATE_CLOSED:
		_socket_open = false
		_reported_open = false
		last_close_description = _close_description()
		if _should_reconnect and table_code != "" and seat_token != "":
			_reconnect_attempt += 1
			_reconnect_delay = RECONNECT_DELAY_SECONDS
			connection_changed.emit("reconnecting")
		else:
			connection_changed.emit("closed")


func create_table(host_name: String, seed: String = "") -> void:
	var body := {"hostName": host_name}
	if seed.strip_edges() != "":
		body["seed"] = seed.strip_edges()
	_post_json("%s/tables" % server_url, body)


func join_table(code: String, player_name: String, as_witness := false) -> void:
	_post_json("%s/tables/%s/join" % [server_url, code.strip_edges().to_upper()], {"name": player_name, "asWitness": as_witness})


func send_intent(intent: Dictionary) -> bool:
	if not _socket_open or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_received.emit({"description": "WebSocket is not connected."})
		return false
	var client_intent_id := "%s:%s" % [participant_id, _next_client_intent_id]
	_next_client_intent_id += 1
	var err := _websocket.send_text(JSON.stringify({
		"type": "intent",
		"clientIntentId": client_intent_id,
		"intent": intent
	}))
	if err != OK:
		error_received.emit({"description": "WebSocket send failed: %s" % err})
		return false
	return true


func is_socket_connected() -> bool:
	return _socket_open and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN


func reconnect_attempt() -> int:
	return _reconnect_attempt


func has_table_session(code: String = "") -> bool:
	if table_code == "" or seat_token == "":
		return false
	if code.strip_edges() == "":
		return true
	return table_code == code.strip_edges().to_upper()


func leave_table() -> void:
	if _socket_open and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_websocket.send_text(JSON.stringify({"type": "leave_table"}))
		_websocket.poll()
	disconnect_local()


func disconnect_local() -> void:
	if _socket_open:
		_websocket.close()
	_socket_open = false
	_reported_open = false
	_should_reconnect = false
	_reconnect_delay = -1.0
	table_code = ""
	participant_id = ""
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
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		error_received.emit({"description": "HTTP request failed to start: %s" % err})


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		error_received.emit({"description": "HTTP request failed with result %s." % result})
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		error_received.emit({"description": "Server returned invalid JSON."})
		return
	if response_code < 200 or response_code >= 300 or not parsed.get("ok", false):
		error_received.emit(parsed)
		return
	var response: Dictionary = parsed.get("result", {})
	table_code = str(response.get("tableCode", ""))
	participant_id = str(response.get("participantId", ""))
	seat_token = str(response.get("seatToken", ""))
	latest_snapshot = response.get("snapshot", {})
	snapshot_received.emit(latest_snapshot)
	connect_socket()


func _handle_socket_message(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		error_received.emit({"description": "Invalid WebSocket JSON."})
		return
	if parsed.get("type", "") == "snapshot":
		latest_snapshot = parsed.get("snapshot", {})
		snapshot_received.emit(latest_snapshot)
	elif parsed.get("type", "") == "delta":
		_handle_delta_message(parsed)
	elif parsed.get("type", "") == "ack":
		if not bool(parsed.get("ok", false)):
			error_received.emit(parsed)
	elif parsed.get("type", "") == "error":
		error_received.emit(parsed)


func _handle_delta_message(message: Dictionary) -> void:
	var base_version := int(message.get("baseVersion", -1))
	var current_version := int(latest_snapshot.get("version", -1))
	if latest_snapshot.is_empty() or current_version != base_version:
		error_received.emit({"description": "Delta was based on version %s, but cached version is %s. Reconnecting for a fresh snapshot." % [base_version, current_version]})
		connect_socket()
		return
	var patch: Dictionary = message.get("patch", {})
	for key in patch.keys():
		latest_snapshot[key] = patch[key]
	var append: Dictionary = message.get("append", {})
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
	snapshot_received.emit(latest_snapshot)


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
