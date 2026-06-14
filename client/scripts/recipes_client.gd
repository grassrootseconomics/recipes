extends Node

signal snapshot_received(snapshot: Dictionary)
signal error_received(error: Dictionary)
signal connection_changed(status: String)

var server_url := "http://127.0.0.1:3000"
var table_code := ""
var participant_id := ""
var seat_token := ""
var latest_snapshot: Dictionary = {}

var _http_request: HTTPRequest
var _websocket := WebSocketPeer.new()
var _socket_open := false
var _reported_open := false


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)


func _process(_delta: float) -> void:
	if not _socket_open:
		return
	_websocket.poll()
	var state := _websocket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _reported_open:
			_reported_open = true
			connection_changed.emit("open")
		while _websocket.get_available_packet_count() > 0:
			var text := _websocket.get_packet().get_string_from_utf8()
			_handle_socket_message(text)
	elif state == WebSocketPeer.STATE_CLOSED:
		_socket_open = false
		_reported_open = false
		connection_changed.emit("closed")


func create_table(host_name: String, seed: String = "") -> void:
	var body := {"hostName": host_name}
	if seed.strip_edges() != "":
		body["seed"] = seed.strip_edges()
	_post_json("%s/tables" % server_url, body)


func join_table(code: String, player_name: String, as_witness := false) -> void:
	_post_json("%s/tables/%s/join" % [server_url, code.strip_edges().to_upper()], {"name": player_name, "asWitness": as_witness})


func send_intent(intent: Dictionary) -> void:
	if not _socket_open or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_received.emit({"description": "WebSocket is not connected."})
		return
	_websocket.send_text(JSON.stringify(intent))


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
	var ws_url := server_url.replace("https://", "wss://").replace("http://", "ws://")
	var err := _websocket.connect_to_url("%s/tables/%s/socket?seatToken=%s" % [ws_url, table_code, seat_token])
	if err != OK:
		error_received.emit({"description": "Could not connect WebSocket: %s" % err})
		return
	_socket_open = true
	connection_changed.emit("connecting")


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
	elif parsed.get("type", "") == "error":
		error_received.emit(parsed)
