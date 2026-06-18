extends SceneTree

const OfflineStore := preload("res://scripts/offline_store.gd")

var _last_error := ""


func _initialize() -> void:
	var store = OfflineStore.new()
	root.add_child(store)
	store.error_received.connect(func(error: Dictionary) -> void:
		_last_error = str(error.get("description", JSON.stringify(error)))
	)
	_smoke_config_validation(store)
	_smoke_timer_expiry(store)
	_smoke_controlled_seats(store)
	_smoke_bots(store)
	print("offline smoke ok")
	quit()


func _smoke_config_validation(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-validation").is_empty(), "create validation table")
	_require(store.latest_snapshot.get("participants", []).size() == 8, "offline tables start with eight seats")
	_require(_bot_count(store.latest_snapshot) == 7, "offline tables start with seven bots")
	_require(not store.handle_host_intent({"type": "set_timer", "seconds": 0}), "reject zero timer")
	_require(_last_error.contains("positive"), "timer validation message")
	_require(not store.handle_host_intent({"type": "set_stock", "count": 1000}), "reject stock above generated max")
	_require(_last_error.contains("between"), "stock validation message")
	_require(store.handle_host_intent({"type": "set_stock", "count": 40}), "accept default stock")


func _smoke_timer_expiry(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-timer").is_empty(), "create timer table")
	for _index in range(7):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add timer controlled seat")
	_require(store.handle_host_intent({"type": "set_timer", "seconds": 1}), "set timer")
	_require(store.handle_host_intent({"type": "start"}), "start timer table")
	var timer: Dictionary = store.latest_snapshot.get("timer", {})
	_require(timer.has("endsAtMs"), "timer runtime starts")
	store.table["timer"]["endsAtMs"] = 0
	store._process(0.0)
	_require(str(store.latest_snapshot.get("phase", "")) == "complete", "timer expiry completes no-dish table")
	_require(store.latest_snapshot.get("timer", {}).has("expiredAtMs"), "timer expiry recorded")


func _smoke_controlled_seats(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-smoke").is_empty(), "create controlled table")
	for _index in range(7):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add controlled seat: %s" % _last_error)
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 1}), "set dish goal")
	_require(store.handle_host_intent({"type": "start"}), "start controlled table: %s" % _last_error)
	var start_snapshot: Dictionary = store.latest_snapshot
	_require(int(start_snapshot.get("targetDishCount", 0)) == 1, "dish goal reflected")
	_require(start_snapshot.get("participants", []).size() == 8, "eight participants")
	_require(start_snapshot.get("platter", []).is_empty(), "platter empty before deposits")
	_require(start_snapshot.get("ownHand", []).size() == 7, "host starts with seven cards")

	var active_ids := _active_ids(start_snapshot)
	for participant_id in active_ids:
		_require(store.view_as(participant_id), "view controlled participant %s" % participant_id)
		_require(store.handle_intent({"type": "deposit_ingredient"}, participant_id), "deposit for %s: %s" % [participant_id, _last_error])

	var playing_snapshot: Dictionary = store.latest_snapshot
	_require(str(playing_snapshot.get("phase", "")) == "playing", "phase enters playing after deposits")
	_require(playing_snapshot.get("platter", []).size() == 8, "platter has eight initial deposits")
	_require(playing_snapshot.get("ownHand", []).size() == 6, "selected seat has six remaining cards")
	_require(not playing_snapshot.has("allHands"), "controlled seat does not receive all hands")

	_require(store.view_as("p1"), "view p1 before pass")
	_require(store.handle_intent({"type": "pass_turn"}, "p1"), "pass p1 turn")
	_require(str(store.latest_snapshot.get("currentTurnParticipantId", "")) == "p2", "round robin advances to p2")


func _smoke_bots(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-smoke").is_empty(), "create bot table")
	for _index in range(3):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add local seat")
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 1}), "set bot dish goal")
	_require(store.handle_host_intent({"type": "start"}), "start bot table: %s" % _last_error)

	var snapshot: Dictionary = store.latest_snapshot
	for participant_id in _active_human_ids(snapshot):
		_require(store.view_as(participant_id), "view human %s" % participant_id)
		_require(store.handle_intent({"type": "deposit_ingredient"}, participant_id), "human deposit %s: %s" % [participant_id, _last_error])

	var after_deposit: Dictionary = store.latest_snapshot
	_require(str(after_deposit.get("phase", "")) == "playing", "bots deposit and table enters play")
	_require(after_deposit.get("platter", []).size() == 8, "bot table has eight deposits")
	var bot_names: Array[String] = []
	for participant in after_deposit.get("participants", []):
		if str(participant.get("kind", "")) == "bot":
			_require(bool(participant.get("depositedInitial", false)), "bot deposited")
			bot_names.append(str(participant.get("name", "")))
	_require(bot_names == ["Yan_b", "Mia_b", "Leo_b", "Ava_b"], "offline bot names use legit short _b names")


func _active_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active":
			ids.append(str(participant.get("id", "")))
	return ids


func _active_human_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active" and str(participant.get("kind", "")) == "human":
			ids.append(str(participant.get("id", "")))
	return ids


func _bot_count(snapshot: Dictionary) -> int:
	var count := 0
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active" and str(participant.get("kind", "")) == "bot":
			count += 1
	return count


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
