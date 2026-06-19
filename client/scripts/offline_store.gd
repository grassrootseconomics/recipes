extends Node

signal snapshot_received(snapshot: Dictionary)
signal error_received(error: Dictionary)
signal connection_changed(status: String)

const VOUCHERS_PER_INGREDIENT := 7
const DISH_PARTS_PER_DISH := 10
const MIN_ACTIVE_PARTICIPANTS := 8
const MAX_ACTIVE_PARTICIPANTS := 8
const DEFAULT_STOCK := 40
const MIN_STOCK := 1
const MAX_STOCK := 999
const DEFAULT_DISH_GOAL := 4
const MIN_DISH_GOAL := 1
const MAX_DISH_GOAL := 4
const DEFAULT_BOT_RUN_BUDGET := 300
const RECIPE_SLOTS := ["initial", "followup_1", "followup_2", "followup_3"]
const GENERATED_NAMES := [
	"Amina", "Ben", "Clara", "Diego", "Esme", "Farah", "Gita", "Hugo", "Iris", "Jules",
	"Kofi", "Lina", "Mika", "Nora", "Omar", "Pia", "Quinn", "Ravi", "Sana", "Theo"
]
const GENERATED_BOT_NAMES := [
	"Ben", "Nia", "Luc", "Yan", "Mia", "Leo", "Ava", "Eli", "Noa", "Sam",
	"Zoe", "Kai", "Ivy", "Max", "Uma", "Ana", "Raj", "Taj", "Moe", "Ada"
]

var table: Dictionary = {}
var participant_id := ""
var acting_participant_id := ""
var latest_snapshot: Dictionary = {}

var _catalog: Dictionary = {}
var _game_config: Dictionary = {}
var _last_error := ""


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _expire_timer_if_ready():
		_emit_snapshot()


func create_table(host_name: String, seed: String) -> Dictionary:
	_load_catalog()
	var name := host_name.strip_edges()
	if name == "" or name.to_lower() == "host" or name.to_lower() == "player":
		name = GENERATED_NAMES[0]
	participant_id = "p1"
	acting_participant_id = "p1"
	table = {
		"code": "OFFLINE",
		"seed": seed.strip_edges() if seed.strip_edges() != "" else "offline",
		"version": 0,
		"phase": "lobby",
		"paused": false,
		"hostParticipantId": "p1",
		"participants": {
			"p1": _participant("p1", name, "human", "active", true, "", "")
		},
		"participantOrder": ["p1"],
		"vouchers": {},
		"recipes": {},
		"offers": {},
		"dishes": {},
		"dishParts": {},
		"transactionHistory": [],
		"winnerParticipantIds": [],
		"targetDishCount": _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL),
		"stockPerIngredient": _rule_int("realUnitsPerIngredient", DEFAULT_STOCK),
		"turnMode": _rule_string("defaultTurnMode", "round_robin"),
		"currentTurnParticipantId": "",
		"timer": {},
		"turn": 0,
		"nextId": 2
	}
	_fill_open_bot_seats()
	_emit_snapshot()
	connection_changed.emit("open")
	return latest_snapshot


func disconnect_local() -> void:
	table = {}
	participant_id = ""
	acting_participant_id = ""
	latest_snapshot = {}
	connection_changed.emit("closed")


func has_active_table() -> bool:
	return not table.is_empty()


func handle_intent(intent: Dictionary, actor_participant_id := "", run_bot_turns := true) -> bool:
	if table.is_empty():
		return _emit_error("No offline table is active.")
	var actor_id := actor_participant_id
	if actor_id == "":
		actor_id = acting_participant_id if acting_participant_id != "" else participant_id
	_last_error = ""
	var before := table.duplicate(true)
	if not _apply_intent(actor_id, intent):
		table = before
		return _emit_error(_last_error)
	_auto_refuse_unavailable_offers()
	table["version"] = int(table.get("version", 0)) + 1
	if run_bot_turns and str(intent.get("type", "")) != "start" and not bool(table.get("paused", false)):
		_run_bots()
	_emit_snapshot()
	return true


func handle_host_intent(intent: Dictionary) -> bool:
	return handle_intent(intent, participant_id)


func view_as(participant_id_to_view: String) -> bool:
	if table.is_empty():
		return false
	if not _can_control(participant_id, participant_id_to_view):
		return _emit_error("This offline controller cannot control that participant.")
	acting_participant_id = participant_id_to_view
	_emit_snapshot()
	return true


func _apply_intent(actor_id: String, intent: Dictionary) -> bool:
	var actor := _participant_by_id(actor_id)
	if actor.is_empty():
		return _fail("Participant not found.")
	if bool(table.get("paused", false)) and not str(intent.get("type", "")) in ["set_pause", "convert_to_bot", "close_table", "reset_table"]:
		return _fail("The table is paused.")
	table["turn"] = int(table.get("turn", 0)) + 1
	if _should_gate_turn(intent) and not _require_current_turn(actor_id):
		return false

	match str(intent.get("type", "")):
		"close_table":
			if not _require_host(actor):
				return false
			_cancel_all_pending_offers()
			table["phase"] = "complete"
			table["paused"] = false
		"reset_table":
			if not _require_host(actor):
				return false
			_reset_table()
		"set_role":
			return _set_role(actor, str(intent.get("participantId", "")), str(intent.get("role", "active")))
		"rename_participant":
			return _rename_participant(actor, str(intent.get("participantId", "")), str(intent.get("name", "")))
		"add_bot":
			return _add_bot(actor, str(intent.get("botType", "mixed")))
		"add_controlled_seat":
			return _add_controlled_seat(actor, str(intent.get("name", "")), str(intent.get("participantId", "")))
		"convert_to_bot":
			return _convert_to_bot(actor, str(intent.get("participantId", "")), str(intent.get("botType", "mixed")))
		"set_timer":
			if not _require_host(actor) or not _require_lobby():
				return false
			if intent.get("seconds", null) == null:
				table["timer"] = {}
			else:
				var seconds := int(intent.get("seconds", 0))
				if seconds <= 0:
					return _fail("Timer seconds must be a positive integer.")
				table["timer"] = {"seconds": seconds}
		"set_target_dish_count":
			if not _require_host(actor) or not _require_lobby():
				return false
			var count := int(intent.get("count", _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL)))
			var min_goal := _rule_int("minTargetDishCount", MIN_DISH_GOAL)
			var max_goal := _rule_int("maxTargetDishCount", MAX_DISH_GOAL)
			if count < min_goal or count > max_goal:
				return _fail("Dish goal must be between %s and %s." % [min_goal, max_goal])
			table["targetDishCount"] = count
		"set_stock":
			if not _require_host(actor) or not _require_lobby():
				return false
			var stock := int(intent.get("count", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK)))
			var min_stock := _rule_int("minStockPerIngredient", MIN_STOCK)
			var max_stock := _rule_int("maxStockPerIngredient", MAX_STOCK)
			if stock < min_stock or stock > max_stock:
				return _fail("Stock must be between %s and %s." % [min_stock, max_stock])
			table["stockPerIngredient"] = stock
		"set_turn_mode":
			if not _require_host(actor) or not _require_lobby():
				return false
			var mode := str(intent.get("mode", "round_robin"))
			if mode != "round_robin" and mode != "market":
				return _fail("Unknown turn mode.")
			table["turnMode"] = mode
			table["currentTurnParticipantId"] = ""
		"set_pause":
			if not _require_host(actor):
				return false
			if str(table.get("phase", "")) == "complete" and bool(intent.get("paused", false)):
				return _fail("A complete table cannot be paused.")
			_set_paused(bool(intent.get("paused", false)))
		"start":
			return _start_table(actor)
		"stop":
			if not _require_host(actor):
				return false
			if str(table.get("phase", "lobby")) == "lobby":
				return _fail("Only a running table can be stopped.")
			_enter_settlement_phase()
		"pass_turn":
			return _pass_turn(actor)
		"redeem_all_and_pass_turn":
			return _redeem_all_and_pass_turn(actor)
		"deposit":
			return _deposit(actor, str(intent.get("voucherId", "")))
		"deposit_ingredient":
			return _deposit_ingredient(actor, str(intent.get("ingredientId", "")))
		"platter_swap":
			return _swap_with_platter(actor, str(intent.get("giveVoucherId", "")), str(intent.get("takeVoucherId", "")))
		"platter_swap_ingredient":
			return _swap_ingredient_with_platter(actor, str(intent.get("giveIngredientId", "")), str(intent.get("takeIngredientId", "")))
		"platter_asset_swap":
			return _swap_platter_assets(actor, intent.get("give", {}), intent.get("take", {}))
		"platter_asset_swap_aggregate":
			return _swap_platter_assets(actor, _aggregate_asset_to_ref(actor_id, intent.get("give", {}), "inventory"), _aggregate_asset_to_ref(actor_id, intent.get("take", {}), "platter"))
		"create_offer":
			return _create_offer(actor, str(intent.get("toParticipantId", "")), intent.get("offeredVoucherIds", []), intent.get("requested", {}))
		"respond_offer":
			return _respond_offer(actor, str(intent.get("offerId", "")), str(intent.get("response", "")), intent.get("voucherIds", []))
		"cancel_offer":
			return _cancel_offer(actor, str(intent.get("offerId", "")))
		"place_voucher":
			return _place_voucher(actor, str(intent.get("voucherId", "")), str(intent.get("requirementId", "")))
		"redeem_voucher":
			return _redeem_voucher(actor, str(intent.get("voucherId", "")))
		"redeem_from_hand":
			if not _place_voucher(actor, str(intent.get("voucherId", "")), str(intent.get("requirementId", ""))):
				return false
			return _redeem_voucher(actor, str(intent.get("voucherId", "")))
		"prepare":
			return _prepare(actor)
		"bite":
			return _bite(actor, str(intent.get("dishId", "")))
		_:
			return _fail("Unknown offline intent: %s." % str(intent.get("type", "")))
	return true


func _participant(id: String, name: String, kind: String, role: String, is_host: bool, controller_id: String, bot_type: String) -> Dictionary:
	var participant := {
		"id": id,
		"name": name,
		"kind": kind,
		"role": role,
		"isHost": is_host,
		"seatToken": "offline:%s" % id,
		"dishCount": 0,
		"depositedInitial": false,
		"connected": kind == "human"
	}
	if controller_id != "":
		participant["controllerParticipantId"] = controller_id
	if bot_type != "":
		participant["botType"] = bot_type
	return participant


func _set_role(actor: Dictionary, target_id: String, role: String) -> bool:
	if not _require_host(actor) or not _require_lobby():
		return false
	if role != "active":
		return _fail("Offline mode does not support witness seats.")
	var participant := _participant_by_id(target_id)
	if participant.is_empty():
		return _fail("Participant not found.")
	participant["role"] = "active"
	return true


func _fill_open_bot_seats() -> void:
	while _active_participants().size() < _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS):
		var id := "p%s" % int(table.get("nextId", 2))
		table["nextId"] = int(table.get("nextId", 2)) + 1
		var name := _bot_name("Bot", "mixed")
		table["participants"][id] = _participant(id, name, "bot", "active", false, "", "mixed")
		table["participantOrder"].append(id)


func _first_available_bot_seat() -> Dictionary:
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table["participants"].get(id, {})
		if str(participant.get("kind", "")) == "bot" and str(participant.get("role", "")) == "active":
			return participant
	return {}


func _claimable_bot_seat(participant_id_to_claim: String) -> Dictionary:
	var participant := _participant_by_id(participant_id_to_claim)
	if participant.is_empty() or str(participant.get("kind", "")) != "bot" or str(participant.get("role", "")) != "active":
		_fail("That seat is not an available bot seat.")
		return {}
	return participant


func _claim_bot_seat(participant: Dictionary, requested_name: String, controller_id := "") -> void:
	var ordinal := maxi(1, table.get("participantOrder", []).find(str(participant.get("id", ""))) + 1)
	var name := requested_name.strip_edges()
	if name == "":
		name = _generated_name(ordinal - 1)
	participant["name"] = _unique_name_excluding(name, str(participant.get("id", "")))
	participant["kind"] = "human"
	participant["role"] = "active"
	participant["connected"] = true
	participant["dishCount"] = 0
	participant["depositedInitial"] = false
	participant.erase("botType")
	if controller_id != "":
		participant["controllerParticipantId"] = controller_id
		participant["seatToken"] = "controlled:%s:%s" % [controller_id, participant.get("id", "")]
	else:
		participant.erase("controllerParticipantId")
		participant["seatToken"] = "offline:%s" % participant.get("id", "")


func _add_bot(actor: Dictionary, bot_type: String) -> bool:
	if not _require_host(actor) or not _require_lobby():
		return false
	if _active_participants().size() >= _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS):
		return _fail("At most %s active participants are allowed." % _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS))
	if not bot_type in ["pool_only", "barter_only", "mixed"]:
		bot_type = "mixed"
	var id := "p%s" % int(table.get("nextId", 2))
	table["nextId"] = int(table.get("nextId", 2)) + 1
	var name := _bot_name("Bot", bot_type)
	table["participants"][id] = _participant(id, name, "bot", "active", false, "", bot_type)
	table["participantOrder"].append(id)
	return true


func _add_controlled_seat(actor: Dictionary, requested_name := "", participant_id_to_claim := "") -> bool:
	if not _require_host(actor) or not _require_lobby():
		return false
	var bot_seat := _claimable_bot_seat(participant_id_to_claim) if participant_id_to_claim != "" else _first_available_bot_seat()
	if not bot_seat.is_empty():
		_claim_bot_seat(bot_seat, requested_name, participant_id)
		return true
	if _active_participants().size() >= _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS):
		return _fail("At most %s active participants are allowed." % _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS))
	var id := "p%s" % int(table.get("nextId", 2))
	table["nextId"] = int(table.get("nextId", 2)) + 1
	var name := requested_name.strip_edges()
	if name == "":
		name = _generated_name(table["participantOrder"].size())
	name = _unique_name(name)
	table["participants"][id] = _participant(id, name, "human", "active", false, participant_id, "")
	table["participantOrder"].append(id)
	return true


func _convert_to_bot(actor: Dictionary, target_id: String, bot_type: String) -> bool:
	if not _require_host(actor):
		return false
	var participant := _participant_by_id(target_id)
	if participant.is_empty():
		return _fail("Participant not found.")
	if bool(participant.get("isHost", false)):
		return _fail("The host seat cannot be converted to a bot.")
	participant["kind"] = "bot"
	participant["botType"] = bot_type
	participant["connected"] = false
	participant.erase("controllerParticipantId")
	participant["name"] = _bot_name(str(participant.get("name", "")), bot_type)
	return true


func _rename_participant(actor: Dictionary, target_id: String, requested_name: String) -> bool:
	if not _require_lobby():
		return false
	var participant := _participant_by_id(target_id)
	if participant.is_empty():
		return _fail("Participant not found.")
	var actor_is_host := bool(actor.get("isHost", false))
	if not actor_is_host and str(actor.get("id", "")) != target_id:
		return _fail("Only the host can rename other seats.")
	if not actor_is_host and str(participant.get("kind", "")) != "human":
		return _fail("Only the host can rename bot seats.")
	var name := requested_name.strip_edges()
	var participant_id_for_name := str(participant.get("id", ""))
	if str(participant.get("kind", "")) == "bot":
		participant["name"] = _bot_name_excluding(name, str(participant.get("botType", "mixed")), participant_id_for_name)
		return true
	var ordinal := maxi(1, table.get("participantOrder", []).find(participant_id_for_name) + 1)
	if name == "":
		name = _generated_name(ordinal - 1)
	participant["name"] = _unique_name_excluding(name, participant_id_for_name)
	return true


func _start_table(actor: Dictionary) -> bool:
	if not _require_host(actor) or not _require_lobby():
		return false
	var active := _active_participants()
	var min_active := _rule_int("minActiveParticipants", MIN_ACTIVE_PARTICIPANTS)
	var max_active := _rule_int("maxActiveParticipants", MAX_ACTIVE_PARTICIPANTS)
	if active.size() < min_active:
		return _fail("Start requires at least %s active participants." % min_active)
	if active.size() > max_active:
		return _fail("Start allows at most %s active participants." % max_active)
	var required_stock := _min_backed_stock(active.size(), int(table.get("targetDishCount", _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL))))
	if int(table.get("stockPerIngredient", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK))) < required_stock:
		return _fail("Stock must be at least %s for this table, including voucher backing." % required_stock)

	table["phase"] = "deposit"
	table["paused"] = false
	table["vouchers"] = {}
	table["recipes"] = {}
	table["offers"] = {}
	table["dishes"] = {}
	table["dishParts"] = {}
	table["transactionHistory"] = []
	table["winnerParticipantIds"] = []
	_start_timer_if_configured()
	var ingredients := _ingredients_for_player_count(active.size())
	for index in range(active.size()):
		var participant: Dictionary = active[index]
		var ingredient: Dictionary = ingredients[index]
		participant["ingredientId"] = str(ingredient.get("id", ""))
		participant["realIngredientStock"] = int(table.get("stockPerIngredient", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK)))
		participant["dishCount"] = 0
		participant["depositedInitial"] = false
		_create_vouchers(participant)
	for participant in active:
		table["recipes"][participant["id"]] = _generate_recipe(str(participant.get("id", "")))
	for participant in active:
		if not _deposit_initial_offer(participant):
			return false
	table["currentTurnParticipantId"] = str(active[0].get("id", "")) if str(table.get("turnMode", "round_robin")) == "round_robin" else ""
	return true


func _deposit_initial_offer(participant: Dictionary) -> bool:
	var ingredient_id := str(participant.get("ingredientId", ""))
	for voucher in _hand_vouchers(str(participant.get("id", ""))):
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			return _deposit(participant, str(voucher.get("id", "")))
	return _fail("No backed initial offering is available.")


func _reset_table() -> void:
	_cancel_all_pending_offers()
	table["phase"] = "lobby"
	table["paused"] = false
	table["vouchers"] = {}
	table["recipes"] = {}
	table["offers"] = {}
	table["dishes"] = {}
	table["dishParts"] = {}
	table["transactionHistory"] = []
	table["winnerParticipantIds"] = []
	table["currentTurnParticipantId"] = ""
	_clear_timer_runtime()
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table["participants"][id]
		participant["dishCount"] = 0
		participant["depositedInitial"] = false
		participant.erase("ingredientId")
		participant.erase("realIngredientStock")


func _deposit(actor: Dictionary, voucher_id: String) -> bool:
	if not _require_phase("deposit") or not _require_active(actor):
		return false
	if bool(actor.get("depositedInitial", false)):
		return _fail("Participant already deposited.")
	var voucher := _voucher_by_id(voucher_id)
	if voucher.is_empty() or not _voucher_in_hand(voucher, str(actor.get("id", ""))):
		return _fail("Voucher is not in this participant's hand.")
	if not _require_voucher_backed_by_stock(voucher):
		return false
	voucher["location"] = {"type": "platter"}
	actor["depositedInitial"] = true
	_record_transaction(actor, "Deposit", "Platter", _ingredient_name(str(voucher.get("ingredientId", ""))), "None")
	if _active_participants().all(func(participant): return bool(participant.get("depositedInitial", false))):
		table["phase"] = "playing"
	return true


func _deposit_ingredient(actor: Dictionary, ingredient_id: String) -> bool:
	var target := ingredient_id if ingredient_id != "" else str(actor.get("ingredientId", ""))
	for voucher in _hand_vouchers(str(actor.get("id", ""))):
		if target == "" or str(voucher.get("ingredientId", "")) == target:
			return _deposit(actor, str(voucher.get("id", "")))
	return _fail("No matching voucher is available to deposit.")


func _swap_with_platter(actor: Dictionary, give_id: String, take_id: String) -> bool:
	if not _require_phase("playing") or not _require_active(actor):
		return false
	if not _bot_can_use_pool(actor):
		return false
	var give := _voucher_by_id(give_id)
	var take := _voucher_by_id(take_id)
	if give.is_empty() or not _voucher_in_hand(give, str(actor.get("id", ""))):
		return _fail("Given voucher is not in hand.")
	if take.is_empty() or str(take.get("location", {}).get("type", "")) != "platter":
		return _fail("Taken voucher is not in the platter.")
	if not _require_voucher_backed_by_stock(give) or not _require_voucher_backed_by_stock(take):
		return false
	give["location"] = {"type": "platter"}
	take["location"] = {"type": "hand", "participantId": actor.get("id", "")}
	_record_transaction(actor, "Swap", "Platter", _ingredient_name(str(give.get("ingredientId", ""))), _ingredient_name(str(take.get("ingredientId", ""))))
	return true


func _swap_ingredient_with_platter(actor: Dictionary, give_ingredient_id: String, take_ingredient_id: String) -> bool:
	var give_id := ""
	for voucher in _hand_vouchers(str(actor.get("id", ""))):
		if str(voucher.get("ingredientId", "")) == give_ingredient_id:
			give_id = str(voucher.get("id", ""))
			break
	var take_id := ""
	for voucher in _platter_vouchers():
		if str(voucher.get("ingredientId", "")) == take_ingredient_id:
			take_id = str(voucher.get("id", ""))
			break
	if give_id == "" or take_id == "":
		return _fail("Matching swap cards are not available.")
	return _swap_with_platter(actor, give_id, take_id)


func _swap_platter_assets(actor: Dictionary, give_ref: Dictionary, take_ref: Dictionary) -> bool:
	var phase := str(table.get("phase", "lobby"))
	if phase != "playing" and phase != "settlement":
		return _fail("Action requires playing or settlement.")
	if not _require_active(actor) or not _bot_can_use_pool(actor):
		return false
	var give := _resolve_asset(give_ref)
	var take := _resolve_asset(take_ref)
	if give.is_empty() or take.is_empty():
		return _fail("Selected asset is missing.")
	if not _asset_in_inventory(give, str(actor.get("id", ""))):
		return _fail("Given asset is not held by this participant.")
	if not _asset_in_platter(take):
		return _fail("Taken asset is not in the platter.")
	if not _require_asset_backed_by_stock(give) or not _require_asset_backed_by_stock(take):
		return false
	_move_asset_to_platter(give)
	_move_asset_to_inventory(take, str(actor.get("id", "")))
	_record_transaction(actor, "Settlement Swap", "Platter", _asset_label(give), _asset_label(take))
	if str(table.get("phase", "")) == "settlement":
		_advance_settlement_if_ready()
	return true


func _create_offer(actor: Dictionary, to_id: String, offered_ids: Array, requested: Dictionary) -> bool:
	if not _require_phase("playing") or not _require_active(actor) or not _bot_can_use_barter(actor):
		return false
	if to_id == str(actor.get("id", "")):
		return _fail("Cannot trade with yourself.")
	var recipient := _participant_by_id(to_id)
	if recipient.is_empty() or str(recipient.get("role", "")) != "active":
		return _fail("Offer recipient is not active.")
	var ingredient_id := str(requested.get("ingredientId", ""))
	var quantity := int(requested.get("quantity", 1))
	if ingredient_id != str(recipient.get("ingredientId", "")):
		return _fail("Offers can only ask for the recipient's own ingredient.")
	if _offerable_unreserved_qty(to_id, ingredient_id) < quantity:
		return _fail("Recipient has no available vouchers for that ingredient.")
	if offered_ids.is_empty():
		return _fail("Offer must include a voucher.")
	for raw_id in offered_ids:
		var voucher := _voucher_by_id(str(raw_id))
		if voucher.is_empty() or not _voucher_in_hand(voucher, str(actor.get("id", ""))):
			return _fail("Offered voucher is not in hand.")
		if not _require_voucher_backed_by_stock(voucher):
			return false
	var offer_id := "offer_%s" % int(table.get("nextId", 2))
	table["nextId"] = int(table.get("nextId", 2)) + 1
	table["offers"][offer_id] = {
		"id": offer_id,
		"fromParticipantId": actor.get("id", ""),
		"toParticipantId": to_id,
		"offeredVoucherIds": offered_ids.duplicate(),
		"requested": {"ingredientId": ingredient_id, "quantity": quantity},
		"acceptedVoucherIds": [],
		"status": "pending",
		"createdTurn": int(table.get("turn", 0))
	}
	for raw_id in offered_ids:
		table["vouchers"][str(raw_id)]["location"] = {"type": "offer_lock", "offerId": offer_id}
	return true


func _respond_offer(actor: Dictionary, offer_id: String, response: String, voucher_ids: Array) -> bool:
	if not _require_phase("playing") or not _require_active(actor) or not _bot_can_use_barter(actor):
		return false
	var offer := _offer_by_id(offer_id)
	if offer.is_empty() or str(offer.get("status", "")) != "pending":
		return _fail("Offer is not pending.")
	if str(offer.get("toParticipantId", "")) != str(actor.get("id", "")):
		return _fail("Only the recipient can respond to this offer.")
	if response == "refuse":
		_release_offered_vouchers(offer)
		table["offers"].erase(offer_id)
		return true
	var requested: Dictionary = offer.get("requested", {})
	if voucher_ids.size() != int(requested.get("quantity", 1)):
		return _fail("Accepted voucher count does not match the request.")
	for raw_id in voucher_ids:
		var voucher := _voucher_by_id(str(raw_id))
		if voucher.is_empty() or not _voucher_in_hand(voucher, str(actor.get("id", ""))):
			return _fail("Accepted voucher is not in hand.")
		if not _require_voucher_backed_by_stock(voucher):
			return false
		if str(voucher.get("ingredientId", "")) != str(requested.get("ingredientId", "")):
			return _fail("Accepted voucher ingredient does not match the request.")
	for raw_id in offer.get("offeredVoucherIds", []):
		table["vouchers"][str(raw_id)]["location"] = {"type": "hand", "participantId": actor.get("id", "")}
	for raw_id in voucher_ids:
		table["vouchers"][str(raw_id)]["location"] = {"type": "hand", "participantId": offer.get("fromParticipantId", "")}
	var creator := _participant_by_id(str(offer.get("fromParticipantId", "")))
	_record_transaction(creator, "Exchange", str(actor.get("name", "")), _ingredient_list_label(offer.get("offeredVoucherIds", [])), _ingredient_list_label(voucher_ids), str(actor.get("id", "")))
	table["offers"].erase(offer_id)
	return true


func _cancel_offer(actor: Dictionary, offer_id: String) -> bool:
	if not _require_phase("playing"):
		return false
	var offer := _offer_by_id(offer_id)
	if offer.is_empty() or str(offer.get("status", "")) != "pending":
		return _fail("Offer is not pending.")
	if str(offer.get("fromParticipantId", "")) != str(actor.get("id", "")):
		return _fail("Only the offer creator can cancel this offer.")
	_release_offered_vouchers(offer)
	table["offers"].erase(offer_id)
	return true


func _place_voucher(actor: Dictionary, voucher_id: String, requirement_id: String) -> bool:
	if not _require_phase("playing") or not _require_active(actor):
		return false
	var recipe: Dictionary = table["recipes"].get(str(actor.get("id", "")), {})
	if recipe.is_empty():
		return _fail("Participant has no recipe.")
	var requirement := _requirement_by_id(recipe, requirement_id)
	if requirement.is_empty():
		return _fail("Requirement not found.")
	var voucher := _voucher_by_id(voucher_id)
	if voucher.is_empty() or not _voucher_in_hand(voucher, str(actor.get("id", ""))):
		return _fail("Voucher is not in hand.")
	if not _require_voucher_backed_by_stock(voucher):
		return false
	if str(voucher.get("ingredientId", "")) != str(requirement.get("ingredientId", "")):
		return _fail("Voucher ingredient does not match requirement.")
	var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
	if outstanding <= 0:
		return _fail("Requirement already has enough vouchers.")
	requirement["placedVoucherIds"].append(voucher_id)
	voucher["location"] = {"type": "placed", "participantId": actor.get("id", ""), "recipeOwnerId": actor.get("id", ""), "requirementId": requirement_id}
	return true


func _redeem_voucher(actor: Dictionary, voucher_id: String) -> bool:
	if not _require_phase("playing") or not _require_active(actor):
		return false
	var recipe: Dictionary = table["recipes"].get(str(actor.get("id", "")), {})
	var voucher := _voucher_by_id(voucher_id)
	var location: Dictionary = voucher.get("location", {})
	if voucher.is_empty() or str(location.get("type", "")) != "placed" or str(location.get("recipeOwnerId", "")) != str(actor.get("id", "")):
		return _fail("Voucher is not placed on this recipe.")
	var requirement := _requirement_by_id(recipe, str(location.get("requirementId", "")))
	if requirement.is_empty():
		return _fail("Requirement not found.")
	var placed: Array = requirement.get("placedVoucherIds", [])
	var index := placed.find(voucher_id)
	if index < 0:
		return _fail("Voucher is not tracked by requirement.")
	var owner := _participant_by_id(str(voucher.get("ownerParticipantId", "")))
	if int(owner.get("realIngredientStock", 0)) <= 0:
		return _fail("Ingredient owner has no real stock remaining.")
	placed.remove_at(index)
	requirement["redeemedQty"] = int(requirement.get("redeemedQty", 0)) + 1
	owner["realIngredientStock"] = int(owner.get("realIngredientStock", 0)) - 1
	if int(owner.get("realIngredientStock", 0)) > 0:
		voucher["location"] = {"type": "hand", "participantId": owner.get("id", "")}
	else:
		voucher["location"] = {"type": "holding", "participantId": owner.get("id", ""), "recipeOwnerId": actor.get("id", ""), "requirementId": requirement.get("id", "")}
	_record_transaction(actor, "Redeem", str(owner.get("name", "")), _ingredient_name(str(voucher.get("ingredientId", ""))), "Real %s" % _ingredient_name(str(voucher.get("ingredientId", ""))), str(owner.get("id", "")))
	return true


func _redeem_all_and_pass_turn(actor: Dictionary) -> bool:
	if not _require_phase("playing") or not _require_active(actor):
		return false
	var actor_id := str(actor.get("id", ""))
	var recipe: Dictionary = table["recipes"].get(actor_id, {})
	if not recipe.is_empty():
		var outstanding_by_requirement := {}
		for raw_requirement in recipe.get("requirements", []):
			var requirement: Dictionary = raw_requirement
			var placed_ids: Array = requirement.get("placedVoucherIds", [])
			outstanding_by_requirement[str(requirement.get("id", ""))] = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - placed_ids.size()
		var remaining_stock_by_owner := {}
		var planned_redemptions: Array = []
		var initial_hand_ids: Array = []
		for voucher in _hand_vouchers(actor_id):
			initial_hand_ids.append(str(voucher.get("id", "")))
		for voucher_id in initial_hand_ids:
			var voucher := _voucher_by_id(voucher_id)
			if voucher.is_empty() or not _voucher_in_hand(voucher, actor_id):
				continue
			var requirement_id := _planned_useful_requirement_id(recipe, str(voucher.get("ingredientId", "")), outstanding_by_requirement)
			if requirement_id == "":
				continue
			var owner_id := str(voucher.get("ownerParticipantId", ""))
			var owner := _participant_by_id(owner_id)
			var remaining_stock := int(remaining_stock_by_owner.get(owner_id, int(owner.get("realIngredientStock", 0))))
			if remaining_stock <= 0:
				continue
			remaining_stock_by_owner[owner_id] = remaining_stock - 1
			outstanding_by_requirement[requirement_id] = int(outstanding_by_requirement.get(requirement_id, 0)) - 1
			planned_redemptions.append({"voucherId": voucher_id, "requirementId": requirement_id})
		for planned in planned_redemptions:
			var planned_voucher_id := str(planned.get("voucherId", ""))
			var planned_requirement_id := str(planned.get("requirementId", ""))
			if not _place_voucher(actor, planned_voucher_id, planned_requirement_id):
				return false
			if not _redeem_voucher(actor, planned_voucher_id):
				return false
	return _pass_turn(actor)


func _pass_turn(actor: Dictionary) -> bool:
	if not _require_phase_any(["playing", "settlement", "eating"]):
		return false
	if not _require_active(actor):
		return false
	var actor_id := str(actor.get("id", ""))
	var next_id := _next_turn_participant_id(actor_id) if str(table.get("turnMode", "round_robin")) == "round_robin" else ""
	var next_participant := _participant_by_id(next_id)
	_record_transaction(
		actor,
		"Pass Turn",
		str(next_participant.get("name", "Table")) if not next_participant.is_empty() else "Table",
		"Turn",
		"None",
		next_id
	)
	_advance_turn(actor_id)
	return true


func _prepare(actor: Dictionary) -> bool:
	if not _require_phase("playing") or not _require_active(actor):
		return false
	var actor_id := str(actor.get("id", ""))
	var recipe: Dictionary = table["recipes"].get(actor_id, {})
	if recipe.is_empty():
		return _fail("Participant has no recipe.")
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return _fail("All recipe quantities must be redeemed before preparation.")
	var part_count := _rule_int("dishPartsPerDish", DISH_PARTS_PER_DISH)
	var dish_id := "dish_%s" % int(table.get("nextId", 2))
	table["nextId"] = int(table.get("nextId", 2)) + 1
	table["dishes"][dish_id] = {
		"id": dish_id,
		"ownerParticipantId": actor_id,
		"name": recipe.get("name", "Dish"),
		"unitSingular": recipe.get("unitSingular", "part"),
		"unitPlural": recipe.get("unitPlural", "parts"),
		"totalParts": part_count,
		"partsRemaining": part_count,
		"partsEaten": 0,
		"totalBites": part_count,
		"bitesRemaining": part_count,
		"biteCounts": {}
	}
	for index in range(1, part_count + 1):
		var part_id := "%s_part_%s" % [dish_id, index]
		table["dishParts"][part_id] = {
			"id": part_id,
			"dishId": dish_id,
			"dishName": recipe.get("name", "Dish"),
			"makerParticipantId": actor_id,
			"unitSingular": recipe.get("unitSingular", "part"),
			"unitPlural": recipe.get("unitPlural", "parts"),
			"location": {"type": "inventory", "participantId": actor_id}
		}
	_record_transaction(actor, "Prepare", "Table", "Recipe ingredients", "%s %s of %s" % [part_count, recipe.get("unitPlural", "parts"), recipe.get("name", "Dish")])
	actor["dishCount"] = int(actor.get("dishCount", 0)) + 1
	if int(actor.get("dishCount", 0)) < int(table.get("targetDishCount", _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL))):
		table["recipes"][actor_id] = _generate_recipe(actor_id)
	else:
		table["recipes"].erase(actor_id)
	if _active_participants().all(func(participant): return int(participant.get("dishCount", 0)) >= int(table.get("targetDishCount", _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL)))):
		_enter_settlement_phase()
	return true


func _bite(actor: Dictionary, dish_id: String) -> bool:
	if not _require_phase("eating") or not _require_active(actor):
		return false
	var account := _platter_account(str(actor.get("id", "")))
	if not bool(account.get("cleared", false)):
		return _fail("Clear your central platter account before eating.")
	var dish: Dictionary = table["dishes"].get(dish_id, {})
	if dish.is_empty():
		return _fail("Dish not found.")
	var part := _first_dish_part_in_inventory(dish_id, str(actor.get("id", "")))
	if part.is_empty():
		return _fail("You do not hold any uneaten parts of this dish.")
	part["location"] = {"type": "eaten", "participantId": actor.get("id", "")}
	dish["partsEaten"] = int(dish.get("partsEaten", 0)) + 1
	dish["partsRemaining"] = maxi(0, int(dish.get("partsRemaining", 0)) - 1)
	dish["bitesRemaining"] = int(dish.get("partsRemaining", 0))
	var bites: Dictionary = dish.get("biteCounts", {})
	bites[str(actor.get("id", ""))] = int(bites.get(str(actor.get("id", "")), 0)) + 1
	dish["biteCounts"] = bites
	_record_transaction(actor, "Eat", str(actor.get("name", "")), _asset_label({"kind": "dish_part", "value": part}), "Eaten")
	if _all_dish_parts_eaten():
		table["phase"] = "complete"
	return true


func _create_vouchers(participant: Dictionary) -> void:
	for index in range(1, _rule_int("vouchersPerIngredient", VOUCHERS_PER_INGREDIENT) + 1):
		var voucher_id := "%s_%s_%s" % [participant.get("ingredientId", ""), participant.get("id", ""), index]
		table["vouchers"][voucher_id] = {
			"id": voucher_id,
			"ingredientId": participant.get("ingredientId", ""),
			"ownerParticipantId": participant.get("id", ""),
			"location": {"type": "hand", "participantId": participant.get("id", "")}
		}


func _generate_recipe(owner_id: String) -> Dictionary:
	var participant := _participant_by_id(owner_id)
	var recipe_number := int(participant.get("dishCount", 0)) + 1
	var slot := str(RECIPE_SLOTS[(recipe_number - 1) % RECIPE_SLOTS.size()])
	var catalog_recipe := _catalog_recipe(_active_participants().size(), str(participant.get("ingredientId", "")), slot)
	var recipe_id := "recipe_%s_%s_%s" % [owner_id, recipe_number, int(table.get("turn", 0))]
	var requirements: Array = []
	for index in range(catalog_recipe.get("requirements", []).size()):
		var source: Dictionary = catalog_recipe.get("requirements", [])[index]
		requirements.append({
			"id": "%s:req:%s" % [recipe_id, index + 1],
			"ingredientId": source.get("ingredientId", ""),
			"requiredQty": int(source.get("requiredQty", 0)),
			"redeemedQty": 0,
			"placedVoucherIds": []
		})
	var requirement_ids := {}
	for requirement in requirements:
		requirement_ids[requirement["ingredientId"]] = true
	var omitted := ""
	for ingredient in _ingredients_for_player_count(_active_participants().size()):
		if not requirement_ids.has(str(ingredient.get("id", ""))):
			omitted = str(ingredient.get("id", ""))
			break
	return {
		"id": recipe_id,
		"ownerParticipantId": owner_id,
		"name": catalog_recipe.get("dishName", "Dish"),
		"templateId": catalog_recipe.get("templateId", ""),
		"dishFamily": catalog_recipe.get("dishFamily", ""),
		"unitSingular": catalog_recipe.get("partUnitSingular", "part"),
		"unitPlural": catalog_recipe.get("partUnitPlural", "parts"),
		"realIngredientIds": catalog_recipe.get("realIngredientIds", []),
		"matchedRealIngredientIds": catalog_recipe.get("matchedRealIngredientIds", []),
		"fallbackIngredientIds": catalog_recipe.get("fallbackIngredientIds", []),
		"requirements": requirements,
		"omittedIngredientId": omitted
	}


func _emit_snapshot() -> void:
	latest_snapshot = _build_snapshot(acting_participant_id if acting_participant_id != "" else participant_id)
	snapshot_received.emit(latest_snapshot)


func _build_snapshot(viewer_id: String) -> Dictionary:
	var viewer := _participant_by_id(viewer_id)
	var participants: Array = []
	for id in table.get("participantOrder", []):
		participants.append(_public_participant(table["participants"][id]))
	var own_hand := _hand_vouchers(viewer_id)
	var own_food_parts := _inventory_dish_parts(viewer_id)
	var platter_food_parts := _platter_dish_parts()
	var transaction_history: Array = table.get("transactionHistory", [])
	var visible_transaction_history := transaction_history.slice(maxi(0, transaction_history.size() - 100), transaction_history.size())
	var offers: Array = []
	for offer in table.get("offers", {}).values():
		if str(offer.get("status", "")) != "pending":
			continue
		if str(offer.get("fromParticipantId", "")) == viewer_id or str(offer.get("toParticipantId", "")) == viewer_id:
			offers.append(_clone_offer(offer))
	return {
		"tableCode": table.get("code", "OFFLINE"),
		"seed": table.get("seed", ""),
		"version": int(table.get("version", 0)),
		"offline": true,
		"phase": table.get("phase", "lobby"),
		"paused": bool(table.get("paused", false)),
		"viewerParticipantId": viewer_id,
		"connectionParticipantId": participant_id,
		"viewerRole": viewer.get("role", "active"),
		"controlledParticipantIds": _controlled_ids(),
		"viewerCanUseHostControls": true,
		"hostParticipantId": table.get("hostParticipantId", "p1"),
		"turn": int(table.get("turn", 0)),
		"turnMode": table.get("turnMode", "round_robin"),
		"currentTurnParticipantId": table.get("currentTurnParticipantId", ""),
		"participants": participants,
		"ingredients": _catalog.get("ingredients", []),
		"platter": _platter_vouchers(),
		"platterFoodParts": platter_food_parts,
		"ownHandGroups": _group_vouchers(own_hand),
		"platterVoucherGroups": _group_vouchers(_platter_vouchers()),
		"ownFoodPartGroups": _group_dish_parts(own_food_parts),
		"platterFoodPartGroups": _group_dish_parts(platter_food_parts),
		"dishes": _dictionary_values(table.get("dishes", {})),
		"dishParts": own_food_parts + platter_food_parts,
		"transactionHistory": visible_transaction_history,
		"transactionCursor": transaction_history.size(),
		"transactionHistoryComplete": visible_transaction_history.size() == transaction_history.size(),
		"transactionHistoryTotal": transaction_history.size(),
		"dishCounts": _dish_counts(),
		"winners": table.get("winnerParticipantIds", []),
			"targetDishCount": int(table.get("targetDishCount", _rule_int("defaultTargetDishCount", DEFAULT_DISH_GOAL))),
			"stockPerIngredient": int(table.get("stockPerIngredient", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK))),
		"timer": table.get("timer", {}),
		"ownHand": own_hand,
		"ownFoodParts": own_food_parts,
		"ownRecipe": table.get("recipes", {}).get(viewer_id, {}),
		"offers": offers
	}


func full_transaction_history() -> Array:
	return table.get("transactionHistory", []).duplicate(true)


func _public_participant(participant: Dictionary) -> Dictionary:
	var account := _platter_account(str(participant.get("id", "")))
	var result := {
		"id": participant.get("id", ""),
		"name": participant.get("name", ""),
		"kind": participant.get("kind", "human"),
		"role": participant.get("role", "active"),
		"isHost": bool(participant.get("isHost", false)),
		"botType": participant.get("botType", ""),
		"ingredientId": participant.get("ingredientId", ""),
		"realIngredientStock": int(participant.get("realIngredientStock", 0)),
		"offerableOwnIngredientQty": _offerable_unreserved_qty(str(participant.get("id", "")), str(participant.get("ingredientId", ""))),
		"ownCardsInPlatter": int(account.get("ownCardsInPlatter", 0)),
		"platterDebt": int(account.get("platterDebt", 0)),
		"platterShortfall": int(account.get("platterShortfall", 0)),
		"cleared": bool(account.get("cleared", false)),
		"dishCount": int(participant.get("dishCount", 0)),
		"heldFoodPartCount": _inventory_dish_parts(str(participant.get("id", ""))).size(),
		"depositedInitial": bool(participant.get("depositedInitial", false)),
		"connected": bool(participant.get("connected", true))
	}
	if participant.has("controllerParticipantId"):
		result["controllerParticipantId"] = participant.get("controllerParticipantId", "")
	return result


func _run_bots(max_turns := DEFAULT_BOT_RUN_BUDGET) -> void:
	for _turn_index in range(max_turns):
		var progressed := false
		for id in table.get("participantOrder", []):
			var participant: Dictionary = table["participants"][id]
			if str(participant.get("kind", "")) != "bot":
				continue
			var intent := _decide_bot_intent(str(id))
			if intent.is_empty():
				continue
			var before := table.duplicate(true)
			_last_error = ""
			if _apply_intent(str(id), intent):
				_auto_refuse_unavailable_offers()
				table["version"] = int(table.get("version", 0)) + 1
				progressed = true
			else:
				table = before
		if not progressed:
			break
	_force_pass_current_bot_if_needed()


func _force_pass_current_bot_if_needed() -> void:
	if str(table.get("turnMode", "round_robin")) != "round_robin":
		return
	for _index in range(table.get("participantOrder", []).size()):
		var phase := str(table.get("phase", ""))
		if phase != "playing" and phase != "settlement" and phase != "eating":
			return
		var current_id := str(table.get("currentTurnParticipantId", ""))
		var current := _participant_by_id(current_id)
		if current.is_empty() or str(current.get("kind", "")) != "bot" or str(current.get("role", "")) != "active":
			return
		var before := table.duplicate(true)
		_last_error = ""
		if _apply_intent(current_id, {"type": "pass_turn"}):
			_auto_refuse_unavailable_offers()
			table["version"] = int(table.get("version", 0)) + 1
		else:
			table = before
			return


func _decide_bot_intent(bot_id: String) -> Dictionary:
	var bot := _participant_by_id(bot_id)
	if bot.is_empty() or str(bot.get("role", "")) != "active" or bool(table.get("paused", false)):
		return {}
	if str(table.get("turnMode", "round_robin")) == "round_robin" and str(table.get("phase", "")) != "deposit" and str(table.get("currentTurnParticipantId", "")) != bot_id:
		return {}
	var snapshot := _build_snapshot(bot_id)
	match str(table.get("phase", "")):
		"deposit":
			if bool(bot.get("depositedInitial", false)):
				return {}
			var hand: Array = snapshot.get("ownHand", [])
			for voucher in hand:
				if _voucher_has_stock(voucher):
					return {"type": "deposit", "voucherId": voucher.get("id", "")}
			return {}
		"settlement":
			return _decide_bot_settlement(bot_id, snapshot)
		"eating":
			if not bool(_public_participant(bot).get("cleared", false)):
				return _round_robin_pass()
			var parts: Array = snapshot.get("ownFoodParts", [])
			return {"type": "bite", "dishId": parts[0].get("dishId", "")} if not parts.is_empty() else _round_robin_pass()
		"playing":
			var recipe: Dictionary = snapshot.get("ownRecipe", {})
			var accept_offer := _decide_bot_accept_offer(bot_id, snapshot)
			if not accept_offer.is_empty():
				return accept_offer
			if recipe.is_empty():
				return _round_robin_pass()
			if _recipe_ready(recipe):
				return {"type": "prepare"}
			for requirement in recipe.get("requirements", []):
				var placed: Array = requirement.get("placedVoucherIds", [])
				if not placed.is_empty():
					return {"type": "redeem_voucher", "voucherId": placed[0]}
			for voucher in snapshot.get("ownHand", []):
				if not _voucher_has_stock(voucher):
					continue
				var req_id := _useful_requirement_id(recipe, str(voucher.get("ingredientId", "")))
				if req_id != "":
					return {"type": "place_voucher", "voucherId": voucher.get("id", ""), "requirementId": req_id}
			if str(bot.get("botType", "mixed")) != "barter_only":
				var pool_intent := _decide_bot_pool_swap(bot_id, snapshot)
				if not pool_intent.is_empty():
					return pool_intent
			if str(bot.get("botType", "mixed")) != "pool_only":
				var offer_intent := _decide_bot_create_offer(bot_id, snapshot)
				if not offer_intent.is_empty():
					return offer_intent
			return _round_robin_pass()
	return {}


func _decide_bot_accept_offer(bot_id: String, snapshot: Dictionary) -> Dictionary:
	for offer in snapshot.get("offers", []):
		if str(offer.get("status", "")) != "pending" or str(offer.get("toParticipantId", "")) != bot_id:
			continue
		var requested: Dictionary = offer.get("requested", {})
		var matches := _matching_hand_voucher_ids(bot_id, str(requested.get("ingredientId", "")), int(requested.get("quantity", 1)))
		if matches.size() == int(requested.get("quantity", 1)):
			return {"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "voucherIds": matches}
	return {}


func _decide_bot_settlement(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var public_bot := _public_participant(_participant_by_id(bot_id))
	if int(public_bot.get("platterDebt", 0)) > 0:
		var own_platter := _first_platter_voucher_by_owner(bot_id)
		var give := _first_inventory_asset(bot_id, false)
		if not own_platter.is_empty() and not give.is_empty():
			return {"type": "platter_asset_swap", "give": give, "take": {"kind": "voucher", "id": own_platter.get("id", "")}}
	if int(public_bot.get("platterShortfall", 0)) > 0:
		var own_hand := _first_hand_voucher_by_owner(bot_id, bot_id)
		var take := _first_platter_asset_not_owner(bot_id)
		if not own_hand.is_empty() and not take.is_empty():
			return {"type": "platter_asset_swap", "give": {"kind": "voucher", "id": own_hand.get("id", "")}, "take": take}
	if bool(public_bot.get("cleared", false)) and not _platter_dish_parts().is_empty():
		var give_other := _first_non_owner_hand_voucher(bot_id)
		if not give_other.is_empty():
			return {"type": "platter_asset_swap", "give": {"kind": "voucher", "id": give_other.get("id", "")}, "take": {"kind": "dish_part", "id": _platter_dish_parts()[0].get("id", "")}}
	return _round_robin_pass()


func _decide_bot_pool_swap(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var needed: Array = []
	for requirement in recipe.get("requirements", []):
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if outstanding > 0:
			needed.append(str(requirement.get("ingredientId", "")))
	var take := {}
	for voucher in snapshot.get("platter", []):
		if needed.has(str(voucher.get("ingredientId", ""))) and _voucher_has_stock(voucher):
			take = voucher
			break
	if take.is_empty():
		return {}
	var give := _first_surplus_voucher(bot_id, snapshot.get("ownHand", []), recipe)
	if give.is_empty():
		return {}
	return {"type": "platter_swap", "giveVoucherId": give.get("id", ""), "takeVoucherId": take.get("id", "")}


func _decide_bot_create_offer(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var give := _first_surplus_voucher(bot_id, snapshot.get("ownHand", []), recipe)
	if give.is_empty():
		return {}
	var needed_ingredient := ""
	for requirement in recipe.get("requirements", []):
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if outstanding > 0:
			needed_ingredient = str(requirement.get("ingredientId", ""))
			break
	if needed_ingredient == "":
		return {}
	for offer in snapshot.get("offers", []):
		if str(offer.get("fromParticipantId", "")) == bot_id:
			return {}
	for participant in snapshot.get("participants", []):
		if str(participant.get("id", "")) != bot_id and str(participant.get("role", "")) == "active" and str(participant.get("ingredientId", "")) == needed_ingredient and int(participant.get("offerableOwnIngredientQty", 0)) > 0:
			return {"type": "create_offer", "toParticipantId": participant.get("id", ""), "offeredVoucherIds": [give.get("id", "")], "requested": {"ingredientId": needed_ingredient, "quantity": 1}}
	return {}


func _round_robin_pass() -> Dictionary:
	return {"type": "pass_turn"} if str(table.get("turnMode", "round_robin")) == "round_robin" else {}


func _enter_settlement_phase() -> void:
	_cancel_all_pending_offers()
	var active := _active_participants()
	var high_score := 0
	for participant in active:
		high_score = maxi(high_score, int(participant.get("dishCount", 0)))
	var winners: Array = []
	for participant in active:
		if int(participant.get("dishCount", 0)) == high_score:
			winners.append(str(participant.get("id", "")))
	table["winnerParticipantIds"] = winners
	table["phase"] = "settlement" if not table.get("dishes", {}).is_empty() else "complete"
	_advance_settlement_if_ready()


func _advance_settlement_if_ready() -> void:
	if str(table.get("phase", "")) != "settlement":
		return
	for participant in _active_participants():
		if not bool(_platter_account(str(participant.get("id", ""))).get("cleared", false)):
			return
	if not _platter_dish_parts().is_empty():
		return
	table["phase"] = "eating" if not _all_dish_parts_eaten() else "complete"


func _set_paused(paused: bool) -> void:
	if bool(table.get("paused", false)) == paused:
		return
	table["paused"] = paused
	if paused:
		_pause_timer()
	else:
		_resume_timer()


func _start_timer_if_configured() -> void:
	var timer: Dictionary = table.get("timer", {})
	if timer.is_empty():
		return
	var seconds := int(timer.get("seconds", 0))
	if seconds <= 0:
		return
	var now_ms := _now_ms()
	timer["startedAtTurn"] = int(table.get("turn", 0))
	timer["startedAtMs"] = now_ms
	timer["endsAtMs"] = now_ms + seconds * 1000
	timer.erase("expiredAtMs")
	timer.erase("pausedRemainingMs")
	table["timer"] = timer


func _pause_timer() -> void:
	var timer: Dictionary = table.get("timer", {})
	if timer.is_empty() or not timer.has("endsAtMs") or timer.has("expiredAtMs"):
		return
	timer["pausedRemainingMs"] = maxi(0, int(timer.get("endsAtMs", 0)) - _now_ms())
	timer.erase("endsAtMs")
	table["timer"] = timer


func _resume_timer() -> void:
	var timer: Dictionary = table.get("timer", {})
	if timer.is_empty() or not timer.has("pausedRemainingMs") or timer.has("expiredAtMs"):
		return
	timer["endsAtMs"] = _now_ms() + int(timer.get("pausedRemainingMs", 0))
	timer.erase("pausedRemainingMs")
	table["timer"] = timer


func _clear_timer_runtime() -> void:
	var timer: Dictionary = table.get("timer", {})
	if timer.is_empty():
		return
	timer.erase("startedAtTurn")
	timer.erase("startedAtMs")
	timer.erase("endsAtMs")
	timer.erase("expiredAtMs")
	timer.erase("pausedRemainingMs")
	table["timer"] = timer


func _expire_timer_if_ready() -> bool:
	if table.is_empty():
		return false
	var timer: Dictionary = table.get("timer", {})
	if timer.is_empty() or not timer.has("endsAtMs") or timer.has("expiredAtMs"):
		return false
	if bool(table.get("paused", false)):
		return false
	var phase := str(table.get("phase", "lobby"))
	if phase != "deposit" and phase != "playing":
		return false
	var now_ms := _now_ms()
	if int(timer.get("endsAtMs", 0)) > now_ms:
		return false
	table["turn"] = int(table.get("turn", 0)) + 1
	timer["expiredAtMs"] = now_ms
	table["timer"] = timer
	_enter_settlement_phase()
	table["version"] = int(table.get("version", 0)) + 1
	return true


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _should_gate_turn(intent: Dictionary) -> bool:
	if str(table.get("turnMode", "round_robin")) != "round_robin":
		return false
	return str(intent.get("type", "")) in [
		"pass_turn", "redeem_all_and_pass_turn", "platter_swap", "platter_swap_ingredient", "platter_asset_swap", "platter_asset_swap_aggregate",
		"create_offer", "respond_offer", "cancel_offer", "place_voucher", "redeem_voucher", "redeem_from_hand", "prepare", "bite"
	]


func _require_current_turn(actor_id: String) -> bool:
	var current := str(table.get("currentTurnParticipantId", ""))
	if current == "":
		current = _next_turn_participant_id("")
		table["currentTurnParticipantId"] = current
	if current != "" and current != actor_id:
		return _fail("It is %s's turn." % _participant_by_id(current).get("name", "another participant"))
	return true


func _advance_turn(actor_id: String) -> void:
	if str(table.get("turnMode", "round_robin")) != "round_robin":
		table["currentTurnParticipantId"] = ""
		return
	var phase := str(table.get("phase", "lobby"))
	if phase == "lobby" or phase == "deposit" or phase == "complete":
		if phase == "complete":
			table["currentTurnParticipantId"] = ""
		return
	table["currentTurnParticipantId"] = _next_turn_participant_id(actor_id)


func _next_turn_participant_id(after_id: String) -> String:
	var order: Array = table.get("participantOrder", [])
	if order.is_empty():
		return ""
	var start_index := order.find(after_id)
	for offset in range(1, order.size() + 1):
		var index := offset - 1 if after_id == "" else (start_index + offset) % order.size()
		var participant: Dictionary = table["participants"][order[index]]
		if str(participant.get("role", "")) == "active":
			return str(participant.get("id", ""))
	return ""


func _require_host(actor: Dictionary) -> bool:
	return true if bool(actor.get("isHost", false)) else _fail("Host action required.")


func _require_lobby() -> bool:
	return true if str(table.get("phase", "lobby")) == "lobby" else _fail("Action requires lobby.")


func _require_phase(phase: String) -> bool:
	return true if str(table.get("phase", "")) == phase else _fail("Action requires phase %s." % phase)


func _require_phase_any(phases: Array) -> bool:
	return true if phases.has(str(table.get("phase", ""))) else _fail("Action is not legal in this phase.")


func _require_active(actor: Dictionary) -> bool:
	return true if str(actor.get("role", "")) == "active" else _fail("Active participant required.")


func _require_voucher_backed_by_stock(voucher: Dictionary) -> bool:
	if not _voucher_has_stock(voucher):
		return _fail("Voucher owner has no real stock remaining.")
	return true


func _voucher_has_stock(voucher: Dictionary) -> bool:
	var owner := _participant_by_id(str(voucher.get("ownerParticipantId", "")))
	return int(owner.get("realIngredientStock", 0)) > 0


func _require_asset_backed_by_stock(asset: Dictionary) -> bool:
	if str(asset.get("kind", "")) != "voucher":
		return true
	return _require_voucher_backed_by_stock(asset.get("value", {}))


func _bot_can_use_pool(actor: Dictionary) -> bool:
	return false if str(actor.get("kind", "")) == "bot" and str(actor.get("botType", "mixed")) == "barter_only" and _fail("This bot cannot use the platter.") else true


func _bot_can_use_barter(actor: Dictionary) -> bool:
	return false if str(actor.get("kind", "")) == "bot" and str(actor.get("botType", "mixed")) == "pool_only" and _fail("This bot cannot barter.") else true


func _participant_by_id(id: String) -> Dictionary:
	if table.is_empty():
		return {}
	return table.get("participants", {}).get(id, {})


func _voucher_by_id(id: String) -> Dictionary:
	return table.get("vouchers", {}).get(id, {})


func _offer_by_id(id: String) -> Dictionary:
	return table.get("offers", {}).get(id, {})


func _requirement_by_id(recipe: Dictionary, requirement_id: String) -> Dictionary:
	for requirement in recipe.get("requirements", []):
		if str(requirement.get("id", "")) == requirement_id:
			return requirement
	return {}


func _active_participants() -> Array:
	var active: Array = []
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table["participants"][id]
		if str(participant.get("role", "")) == "active":
			active.append(participant)
	return active


func _controlled_ids() -> Array:
	var ids: Array = []
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table["participants"][id]
		if str(participant.get("controllerParticipantId", "")) == participant_id:
			ids.append(str(id))
	return ids


func _can_control(controller_id: String, target_id: String) -> bool:
	return target_id == controller_id or _controlled_ids().has(target_id)


func _hand_vouchers(holder_id: String) -> Array:
	var vouchers: Array = []
	for voucher in table.get("vouchers", {}).values():
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == holder_id:
			vouchers.append(voucher)
	return vouchers


func _platter_vouchers() -> Array:
	var vouchers: Array = []
	for voucher in table.get("vouchers", {}).values():
		if str(voucher.get("location", {}).get("type", "")) == "platter":
			vouchers.append(voucher)
	return vouchers


func _inventory_dish_parts(holder_id: String) -> Array:
	var parts: Array = []
	for part in table.get("dishParts", {}).values():
		var location: Dictionary = part.get("location", {})
		if str(location.get("type", "")) == "inventory" and str(location.get("participantId", "")) == holder_id:
			parts.append(part)
	return parts


func _platter_dish_parts() -> Array:
	var parts: Array = []
	for part in table.get("dishParts", {}).values():
		if str(part.get("location", {}).get("type", "")) == "platter":
			parts.append(part)
	return parts


func _voucher_in_hand(voucher: Dictionary, holder_id: String) -> bool:
	var location: Dictionary = voucher.get("location", {})
	return str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == holder_id


func _platter_account(participant_id_for_account: String) -> Dictionary:
	var own_cards := 0
	for voucher in _platter_vouchers():
		if str(voucher.get("ownerParticipantId", "")) == participant_id_for_account:
			own_cards += 1
	return {
		"ownCardsInPlatter": own_cards,
		"platterDebt": maxi(0, own_cards - 1),
		"platterShortfall": maxi(0, 1 - own_cards),
		"cleared": own_cards == 1
	}


func _offerable_qty(participant_id_for_offer: String, ingredient_id: String) -> int:
	var participant := _participant_by_id(participant_id_for_offer)
	if int(participant.get("realIngredientStock", 0)) <= 0:
		return 0
	var count := 0
	for voucher in _hand_vouchers(participant_id_for_offer):
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			count += 1
	return count


func _offerable_unreserved_qty(participant_id_for_offer: String, ingredient_id: String) -> int:
	if ingredient_id == "":
		return 0
	var count := _offerable_qty(participant_id_for_offer, ingredient_id)
	for offer in table.get("offers", {}).values():
		if str(offer.get("status", "")) == "pending" and str(offer.get("toParticipantId", "")) == participant_id_for_offer and str(offer.get("requested", {}).get("ingredientId", "")) == ingredient_id:
			count -= int(offer.get("requested", {}).get("quantity", 1))
	return maxi(0, count)


func _auto_refuse_unavailable_offers() -> void:
	var remaining := {}
	for offer_id in table.get("offers", {}).keys().duplicate():
		var offer: Dictionary = table["offers"][offer_id]
		if str(offer.get("status", "")) != "pending":
			continue
		if _offer_has_unbacked_voucher(offer):
			_release_offered_vouchers(offer)
			table["offers"].erase(offer_id)
			continue
		var requested: Dictionary = offer.get("requested", {})
		var key := "%s:%s" % [offer.get("toParticipantId", ""), requested.get("ingredientId", "")]
		if not remaining.has(key):
			remaining[key] = _offerable_qty(str(offer.get("toParticipantId", "")), str(requested.get("ingredientId", "")))
		if int(remaining[key]) >= int(requested.get("quantity", 1)):
			remaining[key] = int(remaining[key]) - int(requested.get("quantity", 1))
			continue
		_release_offered_vouchers(offer)
		table["offers"].erase(offer_id)


func _offer_has_unbacked_voucher(offer: Dictionary) -> bool:
	for raw_id in offer.get("offeredVoucherIds", []):
		var voucher := _voucher_by_id(str(raw_id))
		if not _voucher_has_stock(voucher):
			return true
	return false


func _release_offered_vouchers(offer: Dictionary) -> void:
	for raw_id in offer.get("offeredVoucherIds", []):
		var voucher := _voucher_by_id(str(raw_id))
		if not voucher.is_empty() and str(voucher.get("location", {}).get("type", "")) == "offer_lock":
			voucher["location"] = {"type": "hand", "participantId": offer.get("fromParticipantId", "")}


func _cancel_all_pending_offers() -> void:
	for offer_id in table.get("offers", {}).keys().duplicate():
		var offer: Dictionary = table["offers"][offer_id]
		_release_offered_vouchers(offer)
		table["offers"].erase(offer_id)


func _resolve_asset(ref: Dictionary) -> Dictionary:
	match str(ref.get("kind", "")):
		"voucher":
			var voucher := _voucher_by_id(str(ref.get("id", "")))
			return {"kind": "voucher", "value": voucher} if not voucher.is_empty() else {}
		"dish_part":
			var part: Dictionary = table.get("dishParts", {}).get(str(ref.get("id", "")), {})
			return {"kind": "dish_part", "value": part} if not part.is_empty() else {}
	return {}


func _aggregate_asset_to_ref(actor_id: String, ref: Dictionary, source: String) -> Dictionary:
	if str(ref.get("kind", "")) == "voucher":
		var vouchers := _hand_vouchers(actor_id) if source == "inventory" else _platter_vouchers()
		for voucher in vouchers:
			if str(voucher.get("ingredientId", "")) == str(ref.get("ingredientId", "")):
				if not ref.has("ownerParticipantId") or str(voucher.get("ownerParticipantId", "")) == str(ref.get("ownerParticipantId", "")):
					return {"kind": "voucher", "id": voucher.get("id", "")}
	if str(ref.get("kind", "")) == "dish_part":
		var parts := _inventory_dish_parts(actor_id) if source == "inventory" else _platter_dish_parts()
		for part in parts:
			if str(part.get("dishId", "")) == str(ref.get("dishId", "")):
				return {"kind": "dish_part", "id": part.get("id", "")}
	return {}


func _asset_in_inventory(asset: Dictionary, holder_id: String) -> bool:
	var value: Dictionary = asset.get("value", {})
	var location: Dictionary = value.get("location", {})
	if str(asset.get("kind", "")) == "voucher":
		return str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == holder_id
	return str(location.get("type", "")) == "inventory" and str(location.get("participantId", "")) == holder_id


func _asset_in_platter(asset: Dictionary) -> bool:
	return str(asset.get("value", {}).get("location", {}).get("type", "")) == "platter"


func _move_asset_to_platter(asset: Dictionary) -> void:
	var value: Dictionary = asset.get("value", {})
	value["location"] = {"type": "platter"}


func _move_asset_to_inventory(asset: Dictionary, holder_id: String) -> void:
	var value: Dictionary = asset.get("value", {})
	value["location"] = {"type": "hand", "participantId": holder_id} if str(asset.get("kind", "")) == "voucher" else {"type": "inventory", "participantId": holder_id}


func _asset_label(asset: Dictionary) -> String:
	var value: Dictionary = asset.get("value", {})
	if str(asset.get("kind", "")) == "voucher":
		return _ingredient_name(str(value.get("ingredientId", "")))
	return "%s %s" % [value.get("dishName", "Dish"), value.get("unitSingular", "part")]


func _first_dish_part_in_inventory(dish_id: String, holder_id: String) -> Dictionary:
	for part in _inventory_dish_parts(holder_id):
		if str(part.get("dishId", "")) == dish_id:
			return part
	return {}


func _all_dish_parts_eaten() -> bool:
	if table.get("dishParts", {}).is_empty():
		return true
	for part in table.get("dishParts", {}).values():
		if str(part.get("location", {}).get("type", "")) != "eaten":
			return false
	return true


func _record_transaction(actor: Dictionary, action: String, counterparty: String, item_out: String, item_back: String, counterparty_id := "") -> void:
	var history: Array = table.get("transactionHistory", [])
	history.append({
		"id": "tx_%s" % (history.size() + 1),
		"turn": int(table.get("turn", 0)),
		"participantId": actor.get("id", ""),
		"name": actor.get("name", ""),
		"action": action,
		"counterpartyParticipantId": counterparty_id,
		"counterparty": counterparty,
		"itemOut": item_out,
		"itemBack": item_back
	})
	table["transactionHistory"] = history


func _ingredient_list_label(voucher_ids: Array) -> String:
	var labels: Array[String] = []
	for raw_id in voucher_ids:
		var voucher := _voucher_by_id(str(raw_id))
		labels.append(_ingredient_name(str(voucher.get("ingredientId", ""))))
	return ", ".join(labels)


func _clone_offer(offer: Dictionary) -> Dictionary:
	var result := offer.duplicate(true)
	var offered: Array = []
	for raw_id in offer.get("offeredVoucherIds", []):
		var voucher := _voucher_by_id(str(raw_id))
		if not voucher.is_empty():
			offered.append(voucher.duplicate(true))
	result["offeredVouchers"] = offered
	return result


func _group_vouchers(vouchers: Array) -> Array:
	var groups := {}
	var order: Array = []
	for voucher in vouchers:
		var key := "%s:%s" % [voucher.get("ingredientId", ""), voucher.get("ownerParticipantId", "")]
		if not groups.has(key):
			groups[key] = {"ingredientId": voucher.get("ingredientId", ""), "ownerParticipantId": voucher.get("ownerParticipantId", ""), "count": 0}
			order.append(key)
		groups[key]["count"] = int(groups[key]["count"]) + 1
	var result: Array = []
	for key in order:
		result.append(groups[key])
	return result


func _group_dish_parts(parts: Array) -> Array:
	var groups := {}
	var order: Array = []
	for part in parts:
		var key := "%s:%s" % [part.get("dishId", ""), part.get("makerParticipantId", "")]
		if not groups.has(key):
			groups[key] = {
				"dishId": part.get("dishId", ""),
				"dishName": part.get("dishName", ""),
				"makerParticipantId": part.get("makerParticipantId", ""),
				"unitSingular": part.get("unitSingular", "part"),
				"unitPlural": part.get("unitPlural", "parts"),
				"count": 0
			}
			order.append(key)
		groups[key]["count"] = int(groups[key]["count"]) + 1
	var result: Array = []
	for key in order:
		result.append(groups[key])
	return result


func _dish_counts() -> Dictionary:
	var counts := {}
	for participant in _active_participants():
		counts[str(participant.get("id", ""))] = int(participant.get("dishCount", 0))
	return counts


func _dictionary_values(dict: Dictionary) -> Array:
	var values: Array = []
	for value in dict.values():
		values.append(value)
	return values


func _ingredients_for_player_count(player_count: int) -> Array:
	for configuration in _catalog.get("configurations", []):
		if int(configuration.get("playerCount", 0)) == player_count:
			return configuration.get("ingredients", [])
	return []


func _catalog_recipe(player_count: int, owner_ingredient_id: String, slot: String) -> Dictionary:
	for recipe in _catalog.get("recipes", []):
		if int(recipe.get("playerCount", 0)) == player_count and str(recipe.get("ownerIngredientId", "")) == owner_ingredient_id and str(recipe.get("slot", "")) == slot:
			return recipe
	return {}


func _max_catalog_demand(player_count: int, dish_goal: int) -> int:
	var demand := {}
	for recipe in _catalog.get("recipes", []):
		if int(recipe.get("playerCount", 0)) != player_count:
			continue
		if RECIPE_SLOTS.find(str(recipe.get("slot", ""))) >= dish_goal:
			continue
		for requirement in recipe.get("requirements", []):
			var ingredient_id := str(requirement.get("ingredientId", ""))
			demand[ingredient_id] = int(demand.get(ingredient_id, 0)) + int(requirement.get("requiredQty", 0))
	var max_demand := 0
	for value in demand.values():
		max_demand = maxi(max_demand, int(value))
	return max_demand


func _min_backed_stock(player_count: int, dish_goal: int) -> int:
	return _max_catalog_demand(player_count, dish_goal) + _rule_int("vouchersPerIngredient", VOUCHERS_PER_INGREDIENT)


func _recipe_ready(recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return false
	for requirement in recipe.get("requirements", []):
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return false
	return true


func _useful_requirement_id(recipe: Dictionary, ingredient_id: String) -> String:
	for requirement in recipe.get("requirements", []):
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if str(requirement.get("ingredientId", "")) == ingredient_id and outstanding > 0:
			return str(requirement.get("id", ""))
	return ""


func _planned_useful_requirement_id(recipe: Dictionary, ingredient_id: String, outstanding_by_requirement: Dictionary) -> String:
	for requirement in recipe.get("requirements", []):
		var requirement_id := str(requirement.get("id", ""))
		if str(requirement.get("ingredientId", "")) == ingredient_id and int(outstanding_by_requirement.get(requirement_id, 0)) > 0:
			return requirement_id
	return ""


func _matching_hand_voucher_ids(holder_id: String, ingredient_id: String, quantity: int) -> Array:
	var ids: Array = []
	for voucher in _hand_vouchers(holder_id):
		if str(voucher.get("ingredientId", "")) == ingredient_id and _voucher_has_stock(voucher):
			ids.append(str(voucher.get("id", "")))
		if ids.size() >= quantity:
			break
	return ids


func _first_surplus_voucher(participant_id_for_bot: String, hand: Array, recipe: Dictionary) -> Dictionary:
	for voucher in hand:
		if not _voucher_has_stock(voucher):
			continue
		if _useful_requirement_id(recipe, str(voucher.get("ingredientId", ""))) == "":
			return voucher
	for voucher in hand:
		if _voucher_has_stock(voucher):
			return voucher
	return {}


func _first_platter_voucher_by_owner(owner_id: String) -> Dictionary:
	for voucher in _platter_vouchers():
		if str(voucher.get("ownerParticipantId", "")) == owner_id and _voucher_has_stock(voucher):
			return voucher
	return {}


func _first_hand_voucher_by_owner(holder_id: String, owner_id: String) -> Dictionary:
	for voucher in _hand_vouchers(holder_id):
		if str(voucher.get("ownerParticipantId", "")) == owner_id and _voucher_has_stock(voucher):
			return voucher
	return {}


func _first_non_owner_hand_voucher(holder_id: String) -> Dictionary:
	for voucher in _hand_vouchers(holder_id):
		if str(voucher.get("ownerParticipantId", "")) != holder_id and _voucher_has_stock(voucher):
			return voucher
	return {}


func _first_inventory_asset(holder_id: String, allow_own_voucher: bool) -> Dictionary:
	var parts := _inventory_dish_parts(holder_id)
	if not parts.is_empty():
		return {"kind": "dish_part", "id": parts[0].get("id", "")}
	for voucher in _hand_vouchers(holder_id):
		if (allow_own_voucher or str(voucher.get("ownerParticipantId", "")) != holder_id) and _voucher_has_stock(voucher):
			return {"kind": "voucher", "id": voucher.get("id", "")}
	return {}


func _first_platter_asset_not_owner(owner_id: String) -> Dictionary:
	for part in _platter_dish_parts():
		return {"kind": "dish_part", "id": part.get("id", "")}
	for voucher in _platter_vouchers():
		if str(voucher.get("ownerParticipantId", "")) != owner_id and _voucher_has_stock(voucher):
			return {"kind": "voucher", "id": voucher.get("id", "")}
	return {}


func _load_catalog() -> void:
	if not _catalog.is_empty() and not _game_config.is_empty():
		return
	var catalog := _load_json_resource("res://data/recipe_catalog.json")
	if catalog.is_empty():
		_catalog = {"ingredients": [], "configurations": [], "recipes": []}
	else:
		_catalog = catalog

	var game_config := _load_json_resource("res://data/game_config.json")
	if game_config.is_empty():
		_game_config = {}
	else:
		_game_config = game_config


func _load_json_resource(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _rule_int(key: String, fallback: int) -> int:
	return int(_game_config.get(key, fallback))


func _rule_string(key: String, fallback: String) -> String:
	return str(_game_config.get(key, fallback))


func _ingredient_name(ingredient_id: String) -> String:
	for ingredient in _catalog.get("ingredients", []):
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.capitalize()


func _generated_name(index: int) -> String:
	return GENERATED_NAMES[index % GENERATED_NAMES.size()]


func _unique_name(base: String) -> String:
	var existing := {}
	for participant in table.get("participants", {}).values():
		existing[str(participant.get("name", ""))] = true
	if not existing.has(base):
		return base
	for suffix in range(2, 100):
		var candidate := "%s_%s" % [base, suffix]
		if not existing.has(candidate):
			return candidate
	return "%s_%s" % [base, table.get("nextId", 0)]


func _unique_name_excluding(base: String, excluded_participant_id: String) -> String:
	var existing := {}
	for participant in table.get("participants", {}).values():
		if str(participant.get("id", "")) == excluded_participant_id:
			continue
		existing[str(participant.get("name", ""))] = true
	if not existing.has(base):
		return base
	for suffix in range(2, 100):
		var candidate := "%s_%s" % [base, suffix]
		if not existing.has(candidate):
			return candidate
	return "%s_%s" % [base, table.get("nextId", 0)]


func _bot_name(base: String, bot_type: String) -> String:
	var clean := base.strip_edges()
	if _is_generic_bot_name(base):
		return _unique_generated_bot_name(bot_type)
	clean = _explicit_bot_name(clean)
	if clean.findn("_b") >= 0:
		return _unique_name(clean)
	return _unique_bot_name(clean, bot_type)


func _bot_name_excluding(base: String, bot_type: String, excluded_participant_id: String) -> String:
	var clean := base.strip_edges()
	if _is_generic_bot_name(base):
		return _unique_generated_bot_name_excluding(bot_type, excluded_participant_id)
	clean = _explicit_bot_name(clean)
	if clean.findn("_b") >= 0:
		return _unique_name_excluding(clean, excluded_participant_id)
	return _unique_bot_name_excluding(clean, bot_type, excluded_participant_id)


func _explicit_bot_name(base: String) -> String:
	var clean := base.strip_edges()
	clean = clean.replace("_pool_bot", "")
	clean = clean.replace("_barter_bot", "")
	clean = clean.replace("_mix_bot", "")
	clean = clean.replace("_mixed_bot", "")
	clean = clean.replace("_bot", "")
	return clean


func _is_generic_bot_name(base: String) -> bool:
	var cleaned := base.strip_edges().to_lower()
	return ["", "bot", "pool bot", "barter bot", "mixed bot", "pool_only", "barter_only", "mixed"].has(cleaned)


func _unique_generated_bot_name(bot_type: String) -> String:
	var suffix := _bot_suffix(bot_type)
	var existing := {}
	var used_bases := {}
	for participant in table.get("participants", {}).values():
		var name := str(participant.get("name", ""))
		existing[name] = true
		used_bases[_bot_base_key(name)] = true
	for base in GENERATED_BOT_NAMES:
		var candidate := "%s%s" % [base, suffix]
		if not existing.has(candidate) and not used_bases.has(_bot_base_key(base)):
			return candidate
	for base in GENERATED_BOT_NAMES:
		var candidate := _unique_bot_name(base, bot_type)
		if not existing.has(candidate):
			return candidate
	return _unique_bot_name("Bot", bot_type)


func _unique_generated_bot_name_excluding(bot_type: String, excluded_participant_id: String) -> String:
	var suffix := _bot_suffix(bot_type)
	var existing := {}
	var used_bases := {}
	for participant in table.get("participants", {}).values():
		if str(participant.get("id", "")) == excluded_participant_id:
			continue
		var name := str(participant.get("name", ""))
		existing[name] = true
		used_bases[_bot_base_key(name)] = true
	for base in GENERATED_BOT_NAMES:
		var candidate := "%s%s" % [base, suffix]
		if not existing.has(candidate) and not used_bases.has(_bot_base_key(base)):
			return candidate
	for base in GENERATED_BOT_NAMES:
		var candidate := _unique_bot_name_excluding(base, bot_type, excluded_participant_id)
		if not existing.has(candidate):
			return candidate
	return _unique_bot_name_excluding("Bot", bot_type, excluded_participant_id)


func _unique_bot_name(base: String, bot_type: String) -> String:
	var short_base := _short_bot_base(base)
	var suffix := _bot_suffix(bot_type)
	var existing := {}
	for participant in table.get("participants", {}).values():
		existing[str(participant.get("name", ""))] = true
	var first := "%s%s" % [short_base, suffix]
	if not existing.has(first):
		return first
	for index in range(2, 100):
		var marker := str(index)
		var prefix_length := maxi(1, 3 - marker.length())
		var candidate := "%s%s%s" % [short_base.substr(0, prefix_length), marker, suffix]
		if not existing.has(candidate):
			return candidate
	return "B%s%s" % [table.get("nextId", 0), suffix]


func _unique_bot_name_excluding(base: String, bot_type: String, excluded_participant_id: String) -> String:
	var short_base := _short_bot_base(base)
	var suffix := _bot_suffix(bot_type)
	var existing := {}
	for participant in table.get("participants", {}).values():
		if str(participant.get("id", "")) == excluded_participant_id:
			continue
		existing[str(participant.get("name", ""))] = true
	var first := "%s%s" % [short_base, suffix]
	if not existing.has(first):
		return first
	for index in range(2, 100):
		var marker := str(index)
		var prefix_length := maxi(1, 3 - marker.length())
		var candidate := "%s%s%s" % [short_base.substr(0, prefix_length), marker, suffix]
		if not existing.has(candidate):
			return candidate
	return "B%s%s" % [table.get("nextId", 0), suffix]


func _bot_base_key(base: String) -> String:
	var clean := base.strip_edges()
	clean = clean.replace("_pool_bot", "")
	clean = clean.replace("_barter_bot", "")
	clean = clean.replace("_mix_bot", "")
	clean = clean.replace("_mixed_bot", "")
	clean = clean.replace("_bot", "")
	clean = clean.replace("_b", "")
	var out := ""
	for index in range(clean.length()):
		var character := clean.substr(index, 1)
		var code := character.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			out += character.to_lower()
	return out


func _short_bot_base(base: String) -> String:
	var out := ""
	for index in range(base.length()):
		var character := base.substr(index, 1)
		var code := character.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			out += character
		if out.length() >= 3:
			break
	if out == "":
		return "Bot"
	return out


func _bot_suffix(bot_type: String) -> String:
	return "_b"


func _fail(message: String) -> bool:
	_last_error = message
	return false


func _emit_error(message: String) -> bool:
	error_received.emit({"description": message if message != "" else "Offline action failed."})
	return false
