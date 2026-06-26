extends Node

signal snapshot_received(snapshot: Dictionary)
signal error_received(error: Dictionary)
signal connection_changed(status: String)

const VOUCHERS_PER_INGREDIENT := 8
const OPENING_OFFERINGS_PER_PLAYER := 2
const DISH_PARTS_PER_DISH := 10
const MIN_ACTIVE_PARTICIPANTS := 8
const MAX_ACTIVE_PARTICIPANTS := 8
const DEFAULT_STOCK := 40
const MIN_STOCK := 1
const MAX_STOCK := 999
const DEFAULT_DISH_GOAL := 3
const MIN_DISH_GOAL := 1
const MAX_DISH_GOAL := 3
const DEFAULT_BOT_RUN_BUDGET := 300
const RECIPE_SLOTS := ["initial", "followup_1", "followup_2"]
const GENERATED_NAMES := [
	"Amina", "Ben", "Clara", "Diego", "Esme", "Farah", "Gita", "Hugo", "Iris", "Jules",
	"Kofi", "Lina", "Mika", "Nora", "Omar", "Pia", "Quinn", "Ravi", "Sana", "Theo"
]
const GENERATED_BOT_NAMES := [
	"Jim", "Nia", "Luc", "Ava", "Leo", "Mia", "Yan", "Eli", "Noa", "Sam",
	"Zoe", "Kai", "Ivy", "Max", "Uma", "Ana", "Raj", "Taj", "Moe", "Ada"
]

var table: Dictionary = {}
var participant_id := ""
var acting_participant_id := ""
var latest_snapshot: Dictionary = {}

var _catalog: Dictionary = {}
var _game_config: Dictionary = {}
var _last_error := ""
var _bot_run_active := false
var _bot_run_generation := 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _expire_timer_if_ready():
		_emit_snapshot()


func create_table(host_name: String, seed: String) -> Dictionary:
	_cancel_bot_run()
	_load_catalog()
	var name := host_name.strip_edges()
	if name == "" or name.to_lower() == "host" or name.to_lower() == "player":
		name = GENERATED_NAMES[0]
	var resolved_seed := seed.strip_edges()
	if resolved_seed == "":
		resolved_seed = "offline:%s" % Time.get_ticks_usec()
	participant_id = "p1"
	acting_participant_id = "p1"
	table = {
		"code": "OFFLINE",
		"seed": resolved_seed,
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
		"scarcityPressureByIngredient": {},
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
	_assign_lobby_ingredients()
	_emit_snapshot()
	connection_changed.emit("open")
	return latest_snapshot


func disconnect_local() -> void:
	_cancel_bot_run()
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
	if str(table.get("phase", "")) == "settlement":
		_advance_settlement_if_ready()
	table["version"] = int(table.get("version", 0)) + 1
	if run_bot_turns and str(intent.get("type", "")) != "start" and not bool(table.get("paused", false)):
		_emit_snapshot()
		_schedule_bot_run(true)
	else:
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
			return _create_offer(
				actor,
				str(intent.get("toParticipantId", "")),
				intent.get("offeredVoucherIds", []),
				intent.get("requested", {}),
				intent.get("offeredAssets", []),
				intent.get("requestedAsset", {})
			)
		"respond_offer":
			return _respond_offer(actor, str(intent.get("offerId", "")), str(intent.get("response", "")), intent.get("voucherIds", []), intent.get("assets", []))
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
		"bite_all":
			return _bite_all(actor)
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
		"openingOfferingsCount": 0,
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


func _assign_lobby_ingredients() -> void:
	var active := _active_participants()
	var ingredients := _shuffled_ingredients_for_table(active.size())
	for index in range(active.size()):
		if index >= ingredients.size():
			break
		var participant: Dictionary = active[index]
		var ingredient: Dictionary = ingredients[index]
		participant["ingredientId"] = str(ingredient.get("id", ""))


func _ensure_lobby_ingredients() -> void:
	var active := _active_participants()
	var allowed := {}
	for ingredient in _ingredients_for_player_count(active.size()):
		allowed[str(ingredient.get("id", ""))] = true
	var assigned := {}
	for participant in active:
		var ingredient_id := str(participant.get("ingredientId", ""))
		if ingredient_id == "" or not allowed.has(ingredient_id) or assigned.has(ingredient_id):
			_assign_lobby_ingredients()
			return
		assigned[ingredient_id] = true


func _shuffled_ingredients_for_table(player_count: int) -> Array:
	var ingredients := _ingredients_for_player_count(player_count).duplicate(true)
	var seed := "%s:ingredient-assignment" % str(table.get("seed", "offline"))
	ingredients.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_id := str(left.get("id", ""))
		var right_id := str(right.get("id", ""))
		var left_rank := _stable_hash("%s:%s" % [seed, left_id])
		var right_rank := _stable_hash("%s:%s" % [seed, right_id])
		if left_rank == right_rank:
			return left_id < right_id
		return left_rank < right_rank
	)
	return ingredients


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
	participant["openingOfferingsCount"] = 0
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
	_ensure_lobby_ingredients()
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
	_ensure_lobby_ingredients()
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
	participant["name"] = _bot_name_excluding(str(participant.get("name", "")), bot_type, target_id)
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
	_ensure_lobby_ingredients()

	table["phase"] = "deposit"
	table["paused"] = false
	table["vouchers"] = {}
	table["recipes"] = {}
	table["offers"] = {}
	table["dishes"] = {}
	table["dishParts"] = {}
	table["transactionHistory"] = []
	table["scarcityPressureByIngredient"] = {}
	table["winnerParticipantIds"] = []
	_start_timer_if_configured()
	var allowed_ingredients := {}
	for ingredient in _ingredients_for_player_count(active.size()):
		allowed_ingredients[str(ingredient.get("id", ""))] = true
	for index in range(active.size()):
		var participant: Dictionary = active[index]
		if str(participant.get("ingredientId", "")) == "" or not allowed_ingredients.has(str(participant.get("ingredientId", ""))):
			return _fail("Missing ingredient assignment.")
		participant["realIngredientStock"] = int(table.get("stockPerIngredient", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK)))
		participant["dishCount"] = 0
		participant["depositedInitial"] = false
		participant["openingOfferingsCount"] = 0
		_create_vouchers(participant)
	for participant in active:
		table["recipes"][participant["id"]] = _generate_recipe(str(participant.get("id", "")))
	for participant in active:
		if not _deposit_initial_offer(participant):
			return false
	table["currentTurnParticipantId"] = str(active[0].get("id", ""))
	return true


func _deposit_initial_offer(participant: Dictionary) -> bool:
	var ingredient_id := str(participant.get("ingredientId", ""))
	while int(participant.get("openingOfferingsCount", 0)) < _rule_int("openingOfferingsPerPlayer", OPENING_OFFERINGS_PER_PLAYER):
		var next_voucher := {}
		for voucher in _hand_vouchers(str(participant.get("id", ""))):
			if str(voucher.get("ingredientId", "")) == ingredient_id:
				next_voucher = voucher
				break
		if next_voucher.is_empty():
			return _fail("No backed initial offering is available.")
		if not _deposit(participant, str(next_voucher.get("id", ""))):
			return false
	return true


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
	table["scarcityPressureByIngredient"] = {}
	table["winnerParticipantIds"] = []
	table["currentTurnParticipantId"] = ""
	_clear_timer_runtime()
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table["participants"][id]
		participant["dishCount"] = 0
		participant["depositedInitial"] = false
		participant["openingOfferingsCount"] = 0
		participant.erase("ingredientId")
		participant.erase("realIngredientStock")
	_assign_lobby_ingredients()


func _deposit(actor: Dictionary, voucher_id: String) -> bool:
	if not _require_phase("deposit") or not _require_active(actor):
		return false
	if int(actor.get("openingOfferingsCount", 0)) >= _rule_int("openingOfferingsPerPlayer", OPENING_OFFERINGS_PER_PLAYER):
		return _fail("Participant already deposited.")
	var voucher := _voucher_by_id(voucher_id)
	if voucher.is_empty() or not _voucher_in_hand(voucher, str(actor.get("id", ""))):
		return _fail("Voucher is not in this participant's hand.")
	if not _require_voucher_backed_by_stock(voucher):
		return false
	voucher["location"] = {"type": "platter"}
	actor["openingOfferingsCount"] = int(actor.get("openingOfferingsCount", 0)) + 1
	actor["depositedInitial"] = int(actor.get("openingOfferingsCount", 0)) >= _rule_int("openingOfferingsPerPlayer", OPENING_OFFERINGS_PER_PLAYER)
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


func _create_offer(actor: Dictionary, to_id: String, offered_ids: Array, requested: Dictionary, offered_assets := [], requested_asset := {}) -> bool:
	if not _require_phase_any(["playing", "settlement"]) or not _require_active(actor):
		return false
	if str(table.get("phase", "")) == "playing" and not _bot_can_use_barter(actor):
		return false
	if to_id == str(actor.get("id", "")):
		return _fail("Cannot trade with yourself.")
	var recipient := _participant_by_id(to_id)
	if recipient.is_empty() or str(recipient.get("role", "")) != "active":
		return _fail("Offer recipient is not active.")
	var normalized_offered_assets := _normalize_offer_assets(offered_ids, offered_assets)
	if normalized_offered_assets.is_empty():
		return _fail("Offer must include an asset.")
	var normalized_requested_asset: Dictionary = requested_asset.duplicate(true) if requested_asset is Dictionary and not requested_asset.is_empty() else _legacy_requested_asset(recipient, requested)
	if normalized_requested_asset.is_empty():
		return false
	if not _validate_offer_asset_request(to_id, normalized_requested_asset):
		return false
	if _offerable_unreserved_asset_qty(to_id, normalized_requested_asset) < int(normalized_requested_asset.get("quantity", 1)):
		return _fail("Recipient does not have enough available assets for that offer.")
	var resolved_offered_assets: Array = []
	for raw_ref in normalized_offered_assets:
		var asset := _resolve_asset(raw_ref)
		if asset.is_empty() or not _asset_in_inventory(asset, str(actor.get("id", ""))):
			return _fail("Offered asset is not held.")
		if not _require_asset_backed_by_stock(asset):
			return false
		resolved_offered_assets.append(asset)
	if _requests_offered_voucher_resource(resolved_offered_assets, normalized_requested_asset):
		return _fail("Offer must exchange different promise-card resources.")
	var offer_id := "offer_%s" % int(table.get("nextId", 2))
	table["nextId"] = int(table.get("nextId", 2)) + 1
	table["offers"][offer_id] = {
		"id": offer_id,
		"fromParticipantId": actor.get("id", ""),
		"toParticipantId": to_id,
		"offeredAssets": normalized_offered_assets.duplicate(true),
		"offeredVoucherIds": offered_ids.duplicate(),
		"requested": requested.duplicate(true),
		"requestedAsset": normalized_requested_asset.duplicate(true),
		"acceptedAssets": [],
		"acceptedVoucherIds": [],
		"status": "pending",
		"createdTurn": int(table.get("turn", 0))
	}
	for asset in resolved_offered_assets:
		_move_asset_to_offer_lock(asset, offer_id)
	return true


func _requests_offered_voucher_resource(offered_assets: Array, requested: Dictionary) -> bool:
	if str(requested.get("kind", "")) != "voucher":
		return false
	for raw_asset in offered_assets:
		var asset: Dictionary = raw_asset
		if str(asset.get("kind", "")) != "voucher":
			continue
		var voucher: Dictionary = asset.get("value", {})
		if str(voucher.get("ingredientId", "")) != str(requested.get("ingredientId", "")):
			continue
		if requested.has("ownerParticipantId") and str(voucher.get("ownerParticipantId", "")) != str(requested.get("ownerParticipantId", "")):
			continue
		return true
	return false


func _respond_offer(actor: Dictionary, offer_id: String, response: String, voucher_ids: Array, assets := []) -> bool:
	if not _require_phase_any(["playing", "settlement"]) or not _require_active(actor):
		return false
	if str(table.get("phase", "")) == "playing" and not _bot_can_use_barter(actor):
		return false
	var offer := _offer_by_id(offer_id)
	if offer.is_empty() or str(offer.get("status", "")) != "pending":
		return _fail("Offer is not pending.")
	if str(offer.get("toParticipantId", "")) != str(actor.get("id", "")):
		return _fail("Only the recipient can respond to this offer.")
	if response == "refuse":
		_release_offered_assets(offer)
		table["offers"].erase(offer_id)
		return true
	var requested_asset: Dictionary = offer.get("requestedAsset", {})
	if requested_asset.is_empty():
		requested_asset = _legacy_requested_asset(actor, offer.get("requested", {}))
	var accepted_asset_refs := _normalize_accepted_assets(voucher_ids, assets)
	if accepted_asset_refs.size() != int(requested_asset.get("quantity", 1)):
		return _fail("Accepted asset count does not match the request.")
	var resolved_accepted_assets: Array = []
	for raw_ref in accepted_asset_refs:
		var asset := _resolve_asset(raw_ref)
		if asset.is_empty() or not _asset_in_inventory(asset, str(actor.get("id", ""))):
			return _fail("Accepted asset is not held.")
		if not _require_asset_backed_by_stock(asset):
			return false
		if not _asset_matches_offer_request(asset, requested_asset):
			return _fail("Accepted asset does not match the request.")
		resolved_accepted_assets.append(asset)
	offer["acceptedAssets"] = accepted_asset_refs.duplicate(true)
	offer["acceptedVoucherIds"] = voucher_ids.duplicate()
	for raw_ref in offer.get("offeredAssets", []):
		var offered_asset := _resolve_asset(raw_ref)
		if not offered_asset.is_empty():
			_move_asset_to_inventory(offered_asset, str(actor.get("id", "")))
	for accepted_asset in resolved_accepted_assets:
		_move_asset_to_inventory(accepted_asset, str(offer.get("fromParticipantId", "")))
	var creator := _participant_by_id(str(offer.get("fromParticipantId", "")))
	_record_transaction(creator, "Exchange", str(actor.get("name", "")), _asset_list_label(offer.get("offeredAssets", [])), _asset_list_label(accepted_asset_refs), str(actor.get("id", "")))
	table["offers"].erase(offer_id)
	return true


func _cancel_offer(actor: Dictionary, offer_id: String) -> bool:
	if not _require_phase_any(["playing", "settlement"]):
		return false
	var offer := _offer_by_id(offer_id)
	if offer.is_empty() or str(offer.get("status", "")) != "pending":
		return _fail("Offer is not pending.")
	if str(offer.get("fromParticipantId", "")) != str(actor.get("id", "")):
		return _fail("Only the offer creator can cancel this offer.")
	_release_offered_assets(offer)
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
		var remaining_stock_by_owner := {}
		for raw_requirement in recipe.get("requirements", []):
			var requirement: Dictionary = raw_requirement
			var placed_ids: Array = requirement.get("placedVoucherIds", []).duplicate()
			for voucher_id in placed_ids:
				var placed_voucher_id := str(voucher_id)
				var voucher := _voucher_by_id(placed_voucher_id)
				var location: Dictionary = voucher.get("location", {})
				if voucher.is_empty() or str(location.get("type", "")) != "placed" or str(location.get("recipeOwnerId", "")) != actor_id or str(location.get("requirementId", "")) != str(requirement.get("id", "")):
					continue
				var owner_id := str(voucher.get("ownerParticipantId", ""))
				var owner := _participant_by_id(owner_id)
				var remaining_stock := int(remaining_stock_by_owner.get(owner_id, int(owner.get("realIngredientStock", 0))))
				if remaining_stock <= 0:
					continue
				remaining_stock_by_owner[owner_id] = remaining_stock - 1
				if not _redeem_voucher(actor, placed_voucher_id):
					return false
		var outstanding_by_requirement := {}
		for raw_requirement in recipe.get("requirements", []):
			var requirement: Dictionary = raw_requirement
			var placed_ids: Array = requirement.get("placedVoucherIds", [])
			outstanding_by_requirement[str(requirement.get("id", ""))] = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - placed_ids.size()
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
		if not _prepare_if_recipe_complete(actor):
			return false
	return _pass_turn(actor)


func _pass_turn(actor: Dictionary) -> bool:
	if not _require_phase_any(["playing", "settlement", "eating"]):
		return false
	if not _require_active(actor):
		return false
	var actor_id := str(actor.get("id", ""))
	var next_id := _next_turn_participant_id(actor_id)
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


func _prepare_if_recipe_complete(actor: Dictionary) -> bool:
	if str(table.get("phase", "")) != "playing":
		return true
	var actor_id := str(actor.get("id", ""))
	var recipe: Dictionary = table["recipes"].get(actor_id, {})
	if recipe.is_empty():
		return true
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return true
	return _prepare(actor)


func _bite(actor: Dictionary, dish_id: String) -> bool:
	if not _require_phase("eating") or not _require_active(actor):
		return false
	var account := _platter_account(str(actor.get("id", "")))
	if not bool(account.get("cleared", false)):
		return _fail("Return all promise cards before eating.")
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


func _bite_all(actor: Dictionary) -> bool:
	if not _require_phase("eating") or not _require_active(actor):
		return false
	if not bool(_platter_account(str(actor.get("id", ""))).get("cleared", false)):
		return _fail("Return all promise cards before eating.")
	var held_parts := _inventory_dish_parts(str(actor.get("id", "")))
	if held_parts.is_empty():
		return _fail("You do not hold any uneaten food parts.")
	for raw_part in held_parts:
		var part: Dictionary = raw_part
		var dish_id := str(part.get("dishId", ""))
		var dish: Dictionary = table.get("dishes", {}).get(dish_id, {})
		if dish.is_empty():
			return _fail("Dish not found.")
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
		table["currentTurnParticipantId"] = ""
	else:
		_advance_turn(str(actor.get("id", "")))
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
	var slots := _recipe_slots_for_participant(participant)
	var slot := str(slots[(recipe_number - 1) % slots.size()])
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


func _recipe_slots_for_participant(participant: Dictionary) -> Array:
	var slots := RECIPE_SLOTS.duplicate()
	var seed := "%s:recipe-order:%s:%s" % [str(table.get("seed", "offline")), str(participant.get("id", "")), str(participant.get("ingredientId", ""))]
	slots.sort_custom(func(left: String, right: String) -> bool:
		var left_rank := _stable_hash("%s:%s" % [seed, left])
		var right_rank := _stable_hash("%s:%s" % [seed, right])
		if left_rank == right_rank:
			return left < right
		return left_rank < right_rank
	)
	return slots


func _stable_hash(value: String) -> int:
	var hash := 2166136261
	for index in range(value.length()):
		hash = hash ^ value.unicode_at(index)
		hash = (hash * 16777619) & 0xFFFFFFFF
	return hash


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
			"gameStats": _game_stats(),
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


func _game_stats() -> Dictionary:
	var history: Array = table.get("transactionHistory", [])
	var pass_turns := _count_transactions(history, "Pass Turn")
	var active_participants := _active_participants()
	var active_count := active_participants.size()
	var cycle_count := float(pass_turns) / float(active_count) if active_count > 0 else 0.0
	var interaction_count := history.size() - pass_turns
	var common_basket_swaps := _count_transactions(history, "Swap")
	var direct_exchanges := _count_transactions(history, "Exchange")
	var prepare_count := _count_transactions(history, "Prepare")
	var settlement_swaps := 0
	var food_piece_settlement_swaps := 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) != "Settlement Swap":
			continue
		settlement_swaps += 1
		if _transaction_asset_is_food_piece(str(transaction.get("itemOut", ""))) or _transaction_asset_is_food_piece(str(transaction.get("itemBack", ""))):
			food_piece_settlement_swaps += 1
	var asset_loss_count := _asset_loss_count(active_participants)
	var productivity_count := _count_transactions(history, "Eat")
	var total_trades := common_basket_swaps + direct_exchanges + settlement_swaps
	var hoarding := _hoarding_index()
	return {
		"activePlayerCount": active_count,
		"mutationCount": int(table.get("turn", 0)),
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
		"scarcityPressureByIngredient": table.get("scarcityPressureByIngredient", {}).duplicate(true),
		"hoardingIndex": int(hoarding.get("hoardingIndex", 0)),
		"hoardingIndexLabel": str(hoarding.get("hoardingIndexLabel", "None")),
		"liquidityDepth": _liquidity_depth(history),
		"settlementTimeTurns": _settlement_time_turns(history),
		"consumptionVariance": _consumption_variance(active_participants),
		"tradeBalanceByParticipant": _trade_balances(active_participants, history)
	}


func _asset_loss_count(active_participants: Array) -> int:
	var starting_stock := int(table.get("stockPerIngredient", _rule_int("realUnitsPerIngredient", DEFAULT_STOCK)))
	var loss := 0
	for raw_participant in active_participants:
		var participant: Dictionary = raw_participant
		loss += maxi(0, starting_stock - int(participant.get("realIngredientStock", starting_stock)))
	return loss


func _profit_gain_percent(productivity_count: int, asset_loss_count: int) -> float:
	if asset_loss_count <= 0:
		return 0.0
	return (float(productivity_count - asset_loss_count) / float(asset_loss_count)) * 100.0


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


func _hoarding_index() -> Dictionary:
	var counts := {}
	for raw_voucher in table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		var holder_id := str(location.get("participantId", ""))
		if str(location.get("type", "")) != "hand" or holder_id == "" or holder_id == str(voucher.get("ownerParticipantId", "")):
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		var key := "%s:%s" % [holder_id, ingredient_id]
		var current: Dictionary = counts.get(key, {"holderId": holder_id, "ingredientId": ingredient_id, "count": 0})
		current["count"] = int(current.get("count", 0)) + 1
		counts[key] = current
	var best_count := 0
	var best_holder := ""
	var best_ingredient := ""
	for raw_candidate in counts.values():
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("count", 0)) > best_count:
			best_count = int(candidate.get("count", 0))
			best_holder = str(candidate.get("holderId", ""))
			best_ingredient = str(candidate.get("ingredientId", ""))
	if best_count <= 0:
		return {"hoardingIndex": 0, "hoardingIndexLabel": "None"}
	var holder := _participant_by_id(best_holder)
	var holder_name := str(holder.get("name", best_holder))
	return {"hoardingIndex": best_count, "hoardingIndexLabel": "%s holds %s x%s" % [holder_name, _ingredient_name(best_ingredient), best_count]}


func _liquidity_depth(history: Array) -> float:
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


func _settlement_time_turns(history: Array) -> int:
	var last_prepare_turn := -1
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == "Prepare":
			last_prepare_turn = int(transaction.get("turn", 0))
	if last_prepare_turn < 0:
		return 0
	for raw_transaction in history:
		var transaction: Dictionary = raw_transaction
		if str(transaction.get("action", "")) == "Eat" and int(transaction.get("turn", 0)) >= last_prepare_turn:
			return maxi(0, int(transaction.get("turn", 0)) - last_prepare_turn)
	var phase := str(table.get("phase", ""))
	if phase == "settlement" or phase == "eating" or phase == "complete":
		return maxi(0, int(table.get("turn", 0)) - last_prepare_turn)
	return 0


func _consumption_variance(active_participants: Array) -> float:
	if active_participants.is_empty():
		return 0.0
	var totals := {}
	for raw_participant in active_participants:
		var participant: Dictionary = raw_participant
		totals[str(participant.get("id", ""))] = 0
	for raw_dish in table.get("dishes", {}).values():
		var dish: Dictionary = raw_dish
		var bite_counts: Dictionary = dish.get("biteCounts", {})
		for participant_id in bite_counts.keys():
			var key := str(participant_id)
			totals[key] = int(totals.get(key, 0)) + int(bite_counts.get(participant_id, 0))
	var mean := 0.0
	for raw_participant in active_participants:
		var participant: Dictionary = raw_participant
		mean += float(totals.get(str(participant.get("id", "")), 0))
	mean = mean / float(active_participants.size())
	var variance := 0.0
	for raw_participant in active_participants:
		var participant: Dictionary = raw_participant
		var value := float(totals.get(str(participant.get("id", "")), 0))
		variance += pow(value - mean, 2.0)
	return variance / float(active_participants.size())


func _trade_balances(active_participants: Array, history: Array) -> Dictionary:
	var balances := {}
	for raw_participant in active_participants:
		var participant: Dictionary = raw_participant
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


func _public_participant(participant: Dictionary) -> Dictionary:
	var account := _platter_account(str(participant.get("id", "")))
	var held_vouchers := _hand_vouchers(str(participant.get("id", "")))
	var held_food_parts := _inventory_dish_parts(str(participant.get("id", "")))
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
		"ownCardsInHand": int(account.get("ownCardsInHand", 0)),
		"foreignCardsInHand": int(account.get("foreignCardsInHand", 0)),
		"ownCardsInOtherHands": int(account.get("ownCardsInOtherHands", 0)),
		"expectedOwnCardsInHand": int(account.get("expectedOwnCardsInHand", 0)),
		"platterDebt": int(account.get("platterDebt", 0)),
		"platterShortfall": int(account.get("platterShortfall", 0)),
		"cleared": bool(account.get("cleared", false)),
		"dishCount": int(participant.get("dishCount", 0)),
		"heldFoodPartCount": held_food_parts.size(),
		"heldVoucherGroups": _group_vouchers(held_vouchers),
		"heldFoodPartGroups": _group_dish_parts(held_food_parts),
		"depositedInitial": bool(participant.get("depositedInitial", false)),
		"openingOfferingsCount": int(participant.get("openingOfferingsCount", 0)),
		"connected": bool(participant.get("connected", true)),
		"currentRecipe": _public_recipe_summary(str(participant.get("id", "")), table.get("recipes", {}).get(str(participant.get("id", "")), {}))
	}
	if participant.has("controllerParticipantId"):
		result["controllerParticipantId"] = participant.get("controllerParticipantId", "")
	return result


func _public_recipe_summary(participant_id_for_summary: String, recipe: Dictionary) -> Dictionary:
	if recipe.is_empty():
		return {}
	var held_useful_counts := {}
	for voucher in _hand_vouchers(participant_id_for_summary):
		if not _voucher_has_stock(voucher):
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		held_useful_counts[ingredient_id] = int(held_useful_counts.get(ingredient_id, 0)) + 1
	var missing_requirements: Array = []
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var ingredient_id := str(requirement.get("ingredientId", ""))
		var recipe_missing := maxi(0, int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)))
		var missing := maxi(0, recipe_missing - int(held_useful_counts.get(ingredient_id, 0)))
		if missing <= 0:
			continue
		missing_requirements.append({
			"ingredientId": ingredient_id,
			"missingQty": missing
		})
	return {
		"name": str(recipe.get("name", "")),
		"missingRequirements": missing_requirements
	}


func _run_bots(emit_each_step := false, max_turns := DEFAULT_BOT_RUN_BUDGET) -> void:
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
				if str(table.get("phase", "")) == "settlement":
					_advance_settlement_if_ready()
				table["version"] = int(table.get("version", 0)) + 1
				progressed = true
				if emit_each_step:
					_emit_snapshot()
			else:
				table = before
		if not progressed:
			break
	_force_pass_current_bot_if_needed(emit_each_step)


func _schedule_bot_run(emit_each_step := false) -> void:
	if _bot_run_active:
		return
	_bot_run_active = true
	_bot_run_generation += 1
	call_deferred("_run_bots_deferred", emit_each_step, DEFAULT_BOT_RUN_BUDGET, _bot_run_generation)


func _cancel_bot_run() -> void:
	_bot_run_generation += 1
	_bot_run_active = false


func _run_bots_deferred(emit_each_step := false, max_turns := DEFAULT_BOT_RUN_BUDGET, generation := 0) -> void:
	if is_inside_tree():
		await get_tree().process_frame
	if generation != _bot_run_generation or table.is_empty() or bool(table.get("paused", false)):
		if generation == _bot_run_generation:
			_bot_run_active = false
		return
	for _turn_index in range(max_turns):
		var progressed := false
		for id in table.get("participantOrder", []):
			if generation != _bot_run_generation or table.is_empty() or bool(table.get("paused", false)):
				if generation == _bot_run_generation:
					_bot_run_active = false
				return
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
				if str(table.get("phase", "")) == "settlement":
					_advance_settlement_if_ready()
				table["version"] = int(table.get("version", 0)) + 1
				progressed = true
				if emit_each_step:
					_emit_snapshot()
				if is_inside_tree():
					await get_tree().process_frame
			else:
				table = before
		if not progressed:
			break
	await _force_pass_current_bot_if_needed_deferred(emit_each_step, generation)
	if generation == _bot_run_generation:
		_bot_run_active = false


func _force_pass_current_bot_if_needed_deferred(emit_each_step := false, generation := 0) -> void:
	for _index in range(table.get("participantOrder", []).size()):
		if generation != _bot_run_generation or table.is_empty() or bool(table.get("paused", false)):
			return
		var phase := str(table.get("phase", ""))
		if phase != "playing" and phase != "settlement":
			return
		var current_id := str(table.get("currentTurnParticipantId", ""))
		var current := _participant_by_id(current_id)
		if current.is_empty() or str(current.get("kind", "")) != "bot" or str(current.get("role", "")) != "active":
			return
		var before := table.duplicate(true)
		_last_error = ""
		if _apply_intent(current_id, {"type": "pass_turn"}):
			_auto_refuse_unavailable_offers()
			if str(table.get("phase", "")) == "settlement":
				_advance_settlement_if_ready()
			table["version"] = int(table.get("version", 0)) + 1
			if emit_each_step:
				_emit_snapshot()
			if is_inside_tree():
				await get_tree().process_frame
		else:
			table = before
			return


func _force_pass_current_bot_if_needed(emit_each_step := false) -> void:
	for _index in range(table.get("participantOrder", []).size()):
		var phase := str(table.get("phase", ""))
		if phase != "playing" and phase != "settlement":
			return
		var current_id := str(table.get("currentTurnParticipantId", ""))
		var current := _participant_by_id(current_id)
		if current.is_empty() or str(current.get("kind", "")) != "bot" or str(current.get("role", "")) != "active":
			return
		var before := table.duplicate(true)
		_last_error = ""
		if _apply_intent(current_id, {"type": "pass_turn"}):
			_auto_refuse_unavailable_offers()
			if str(table.get("phase", "")) == "settlement":
				_advance_settlement_if_ready()
			table["version"] = int(table.get("version", 0)) + 1
			if emit_each_step:
				_emit_snapshot()
		else:
			table = before
			return


func _decide_bot_intent(bot_id: String) -> Dictionary:
	var bot := _participant_by_id(bot_id)
	if bot.is_empty() or str(bot.get("role", "")) != "active" or bool(table.get("paused", false)):
		return {}
	if str(table.get("phase", "")) != "deposit" and str(table.get("phase", "")) != "eating" and str(table.get("currentTurnParticipantId", "")) != bot_id:
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
			var settlement_accept := _decide_bot_accept_offer(bot_id, snapshot)
			if not settlement_accept.is_empty():
				return settlement_accept
			return _decide_bot_settlement(bot_id, snapshot)
		"eating":
			if not bool(_public_participant(bot).get("cleared", false)):
				return {}
			var parts: Array = snapshot.get("ownFoodParts", [])
			return {"type": "bite_all"} if not parts.is_empty() else {}
		"playing":
			var recipe: Dictionary = snapshot.get("ownRecipe", {})
			if recipe.is_empty():
				var goal_complete_offer := _decide_bot_accept_offer(bot_id, snapshot)
				if not goal_complete_offer.is_empty():
					return goal_complete_offer
				return _round_robin_pass()
			if str(bot.get("botType", "mixed")) != "barter_only":
				var pool_intent := _decide_bot_pool_swap(bot_id, snapshot)
				if not pool_intent.is_empty():
					return pool_intent
			var accept_offer := _decide_bot_accept_offer(bot_id, snapshot)
			if not accept_offer.is_empty():
				return accept_offer
			if _recipe_ready(recipe):
				return {"type": "redeem_all_and_pass_turn"}
			if str(bot.get("botType", "mixed")) != "pool_only":
				var offer_intent := _decide_bot_create_offer(bot_id, snapshot)
				if not offer_intent.is_empty():
					return offer_intent
			if _bot_has_redeemable_cards(bot_id, snapshot, recipe):
				return {"type": "redeem_all_and_pass_turn"}
			return _round_robin_pass()
	return {}


func _decide_bot_accept_offer(bot_id: String, snapshot: Dictionary) -> Dictionary:
	for offer in snapshot.get("offers", []):
		if str(offer.get("status", "")) != "pending" or str(offer.get("toParticipantId", "")) != bot_id:
			continue
		var requested: Dictionary = offer.get("requestedAsset", {})
		if str(requested.get("kind", "")) == "voucher":
			var matches := _matching_hand_voucher_ids(bot_id, str(requested.get("ingredientId", "")), int(requested.get("quantity", 1)))
			if requested.has("ownerParticipantId"):
				matches = matches.filter(func(voucher_id: String) -> bool:
					return str(_voucher_by_id(voucher_id).get("ownerParticipantId", "")) == str(requested.get("ownerParticipantId", ""))
				)
			if matches.size() == int(requested.get("quantity", 1)):
				return {"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "voucherIds": matches}
		if str(requested.get("kind", "")) == "dish_part":
			var part_refs: Array = []
			for part in _inventory_dish_parts(bot_id):
				if str(requested.get("dishId", "")) != "" and str(part.get("dishId", "")) != str(requested.get("dishId", "")):
					continue
				if requested.has("makerParticipantId") and str(part.get("makerParticipantId", "")) != str(requested.get("makerParticipantId", "")):
					continue
				part_refs.append({"kind": "dish_part", "id": part.get("id", "")})
				if part_refs.size() >= int(requested.get("quantity", 1)):
					break
			if part_refs.size() == int(requested.get("quantity", 1)):
				return {"type": "respond_offer", "offerId": offer.get("id", ""), "response": "accept", "assets": part_refs}
	return {}


func _bot_has_redeemable_cards(bot_id: String, snapshot: Dictionary, recipe: Dictionary) -> bool:
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		for raw_voucher_id in requirement.get("placedVoucherIds", []):
			var voucher := _voucher_by_id(str(raw_voucher_id))
			if not voucher.is_empty() and _voucher_has_stock(voucher):
				return true
	for raw_voucher in snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		if not _voucher_has_stock(voucher):
			continue
		if _useful_requirement_id(recipe, str(voucher.get("ingredientId", ""))) != "":
			return true
	return false


func _decide_bot_settlement(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var public_bot := _public_participant(_participant_by_id(bot_id))
	if _last_transaction_is_bot_settlement_swap(bot_id):
		return _round_robin_pass()
	if int(public_bot.get("platterDebt", 0)) > 0:
		var own_platter := _first_platter_voucher_by_owner(bot_id)
		var give := _settlement_give_asset(bot_id, snapshot, false)
		if not own_platter.is_empty() and not give.is_empty():
			return {"type": "platter_asset_swap", "give": give, "take": {"kind": "voucher", "id": own_platter.get("id", "")}}
	var shortfall_swap := _settlement_shortfall_swap(bot_id, public_bot, true)
	if not shortfall_swap.is_empty():
		return shortfall_swap
	var direct_offer := _settlement_direct_offer(bot_id, snapshot)
	if not direct_offer.is_empty():
		return direct_offer
	if int(public_bot.get("foreignCardsInHand", 0)) > 0 and not _platter_dish_parts().is_empty():
		var return_candidate := _foreign_card_return_candidate(bot_id, snapshot)
		if not return_candidate.is_empty():
			return {
				"type": "platter_asset_swap",
				"give": {"kind": "voucher", "id": return_candidate.get("voucherId", "")},
				"take": {"kind": "dish_part", "id": return_candidate.get("partId", "")}
			}
	if int(public_bot.get("ownCardsInOtherHands", 0)) > 0 and not _platter_has_food_part_by_maker(bot_id):
		var take_asset := _settlement_seed_take_asset(bot_id)
		var own_food_parts := _inventory_dish_parts(bot_id)
		if not take_asset.is_empty() and not own_food_parts.is_empty():
			return {"type": "platter_asset_swap", "give": {"kind": "dish_part", "id": own_food_parts[0].get("id", "")}, "take": take_asset}
	if int(public_bot.get("platterShortfall", 0)) > 0:
		var fallback_shortfall_swap := _settlement_shortfall_swap(bot_id, public_bot, false)
		if not fallback_shortfall_swap.is_empty():
			return fallback_shortfall_swap
	if bool(public_bot.get("cleared", false)) and not _platter_dish_parts().is_empty():
		var give_other := _first_non_owner_hand_voucher(bot_id)
		if not give_other.is_empty():
			return {"type": "platter_asset_swap", "give": {"kind": "voucher", "id": give_other.get("id", "")}, "take": {"kind": "dish_part", "id": _platter_dish_parts()[0].get("id", "")}}
	return _round_robin_pass()


func _settlement_shortfall_swap(bot_id: String, public_bot: Dictionary, require_extra_own_card: bool) -> Dictionary:
	if int(public_bot.get("platterShortfall", 0)) <= 0:
		return {}
	if require_extra_own_card and int(public_bot.get("ownCardsInHand", 0)) <= int(public_bot.get("expectedOwnCardsInHand", 0)):
		return {}
	if not require_extra_own_card and int(public_bot.get("ownCardsInOtherHands", 0)) > 0:
		return {}
	var own_hand := _first_hand_voucher_by_owner(bot_id, bot_id)
	var take := _first_platter_asset_not_owner(bot_id)
	if own_hand.is_empty() or take.is_empty():
		return {}
	return {"type": "platter_asset_swap", "give": {"kind": "voucher", "id": own_hand.get("id", "")}, "take": take}


func _settlement_direct_offer(bot_id: String, snapshot: Dictionary) -> Dictionary:
	for offer in snapshot.get("offers", []):
		if str(offer.get("status", "")) == "pending" and str(offer.get("fromParticipantId", "")) == bot_id:
			return {}
	var public_bot := _snapshot_participant(snapshot, bot_id)
	var own_food_parts := _inventory_dish_parts(bot_id)
	var own_ingredient_id := str(public_bot.get("ingredientId", ""))
	if own_ingredient_id != "" and int(public_bot.get("ownCardsInOtherHands", 0)) > 0 and not own_food_parts.is_empty():
		for participant in snapshot.get("participants", []):
			if str(participant.get("id", "")) == bot_id:
				continue
			for raw_group in participant.get("heldVoucherGroups", []):
				var group: Dictionary = raw_group
				if (
					str(group.get("ingredientId", "")) == own_ingredient_id
					and str(group.get("ownerParticipantId", "")) == bot_id
					and int(group.get("count", 0)) > 0
				):
					return {
						"type": "create_offer",
						"toParticipantId": participant.get("id", ""),
						"offeredAssets": [{"kind": "dish_part", "id": own_food_parts[0].get("id", "")}],
						"requestedAsset": {"kind": "voucher", "ingredientId": own_ingredient_id, "ownerParticipantId": bot_id, "quantity": 1}
					}
	var candidates: Array = []
	for voucher in _hand_vouchers(bot_id):
		if not _voucher_has_stock(voucher):
			continue
		var owner_id := str(voucher.get("ownerParticipantId", ""))
		if owner_id == bot_id:
			continue
		var owner_public := _snapshot_participant(snapshot, owner_id)
		if owner_public.is_empty() or int(owner_public.get("heldFoodPartCount", 0)) <= 0:
			continue
		candidates.append({
			"voucherId": voucher.get("id", ""),
			"ownerId": owner_id,
			"rank": _settlement_foreign_card_rank(owner_public)
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rank := int(left.get("rank", 0))
		var right_rank := int(right.get("rank", 0))
		if left_rank == right_rank:
			return str(left.get("voucherId", "")) < str(right.get("voucherId", ""))
		return left_rank < right_rank
	)
	if candidates.is_empty():
		return {}
	var candidate: Dictionary = candidates[0]
	return {
		"type": "create_offer",
		"toParticipantId": candidate.get("ownerId", ""),
		"offeredVoucherIds": [candidate.get("voucherId", "")],
		"requestedAsset": {"kind": "dish_part", "quantity": 1}
	}


func _last_transaction_is_bot_settlement_swap(bot_id: String) -> bool:
	var history: Array = table.get("transactionHistory", [])
	if history.is_empty():
		return false
	var last: Dictionary = history[history.size() - 1]
	return str(last.get("participantId", "")) == bot_id and str(last.get("action", "")) == "Settlement Swap"


func _decide_bot_pool_swap(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var needed := _needed_ingredient_counts_after_hand(snapshot, recipe)
	for voucher in snapshot.get("platter", []):
		if int(needed.get(str(voucher.get("ingredientId", "")), 0)) <= 0 or not _voucher_has_stock(voucher):
			continue
		var give := _first_surplus_voucher(bot_id, snapshot.get("ownHand", []), recipe, str(voucher.get("ingredientId", "")))
		if not give.is_empty():
			return {"type": "platter_swap", "giveVoucherId": give.get("id", ""), "takeVoucherId": voucher.get("id", "")}
		var food_part := _first_spendable_food_part(bot_id)
		if not food_part.is_empty():
			return {"type": "platter_asset_swap", "give": {"kind": "dish_part", "id": food_part.get("id", "")}, "take": {"kind": "voucher", "id": voucher.get("id", "")}}
	return {}


func _decide_bot_create_offer(bot_id: String, snapshot: Dictionary) -> Dictionary:
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	var needed := _needed_ingredient_counts_after_hand(snapshot, recipe)
	var candidates := _offerable_needed_ingredients(bot_id, snapshot, needed)
	if candidates.is_empty():
		return {}
	var needed_ingredient := str(candidates[0].get("ingredientId", ""))
	var give := _offer_give_asset(bot_id, snapshot, recipe, needed_ingredient)
	if give.is_empty():
		return {}
	for offer in snapshot.get("offers", []):
		if str(offer.get("fromParticipantId", "")) == bot_id:
			return {}
	var target_id := str(candidates[0].get("targetParticipantId", ""))
	var intent := {
		"type": "create_offer",
		"toParticipantId": target_id,
		"requestedAsset": {"kind": "voucher", "ingredientId": needed_ingredient, "ownerParticipantId": target_id, "quantity": 1}
	}
	if str(give.get("kind", "")) == "voucher":
		intent["offeredVoucherIds"] = [give.get("id", "")]
	else:
		intent["offeredAssets"] = [give]
	return intent


func _first_spendable_food_part(holder_id: String) -> Dictionary:
	var parts := _inventory_dish_parts(holder_id)
	if parts.is_empty():
		return {}
	return parts[0]


func _offer_give_asset(bot_id: String, snapshot: Dictionary, recipe: Dictionary, needed_ingredient_id: String) -> Dictionary:
	var voucher := _first_surplus_voucher(bot_id, snapshot.get("ownHand", []), recipe, needed_ingredient_id)
	if not voucher.is_empty():
		return {"kind": "voucher", "id": voucher.get("id", "")}
	var food_part := _first_spendable_food_part(bot_id)
	if not food_part.is_empty():
		return {"kind": "dish_part", "id": food_part.get("id", "")}
	return {}


func _offerable_needed_ingredients(bot_id: String, snapshot: Dictionary, needed: Dictionary) -> Array:
	var candidates: Array = []
	for raw_ingredient_id in needed.keys():
		var ingredient_id := str(raw_ingredient_id)
		var missing_count := int(needed.get(raw_ingredient_id, 0))
		if missing_count <= 0:
			continue
		for participant in snapshot.get("participants", []):
			if str(participant.get("id", "")) == bot_id:
				continue
			if str(participant.get("role", "")) != "active":
				continue
			if str(participant.get("ingredientId", "")) != ingredient_id:
				continue
			if int(participant.get("offerableOwnIngredientQty", 0)) <= 0:
				continue
			candidates.append({
				"ingredientId": ingredient_id,
				"missingCount": missing_count,
				"targetParticipantId": participant.get("id", "")
			})
			break
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_count := int(left.get("missingCount", 0))
		var right_count := int(right.get("missingCount", 0))
		if left_count == right_count:
			return str(left.get("ingredientId", "")) < str(right.get("ingredientId", ""))
		return left_count < right_count
	)
	return candidates


func _needed_ingredient_counts_after_hand(snapshot: Dictionary, recipe: Dictionary) -> Dictionary:
	var needed := {}
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if outstanding > 0:
			var ingredient_id := str(requirement.get("ingredientId", ""))
			needed[ingredient_id] = int(needed.get(ingredient_id, 0)) + outstanding
	for raw_voucher in snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		if not _voucher_has_stock(voucher):
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		var remaining := int(needed.get(ingredient_id, 0))
		if remaining > 0:
			needed[ingredient_id] = remaining - 1
	return needed


func _round_robin_pass() -> Dictionary:
	return {"type": "pass_turn"}


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
	return str(intent.get("type", "")) in [
		"pass_turn", "redeem_all_and_pass_turn", "platter_swap", "platter_swap_ingredient", "platter_asset_swap", "platter_asset_swap_aggregate",
		"create_offer", "respond_offer", "cancel_offer", "place_voucher", "redeem_voucher", "redeem_from_hand", "prepare"
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
	var phase := str(table.get("phase", "lobby"))
	if phase == "lobby" or phase == "deposit" or phase == "complete":
		if phase == "complete":
			table["currentTurnParticipantId"] = ""
		return
	table["currentTurnParticipantId"] = _next_turn_participant_id(actor_id)


func _next_turn_participant_id(after_id: String) -> String:
	var order := _turn_order_participant_ids()
	if order.is_empty():
		return ""
	var start_index := order.find(after_id)
	for offset in range(1, order.size() + 1):
		var index := offset - 1 if after_id == "" else (start_index + offset) % order.size()
		var participant: Dictionary = table["participants"][order[index]]
		if _participant_can_receive_turn(participant):
			return str(participant.get("id", ""))
	return ""


func _participant_can_receive_turn(participant: Dictionary) -> bool:
	if str(participant.get("role", "")) != "active":
		return false
	var phase := str(table.get("phase", "lobby"))
	if phase == "playing" or phase == "settlement":
		return true
	if phase == "eating":
		return not _inventory_dish_parts(str(participant.get("id", ""))).is_empty()
	return false


func _turn_order_participant_ids() -> Array:
	var active_ids: Array = []
	for id in table.get("participantOrder", []):
		var participant: Dictionary = table.get("participants", {}).get(id, {})
		if str(participant.get("role", "")) == "active":
			active_ids.append(str(id))
	return active_ids


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
	var own_cards_in_hand := 0
	var foreign_cards_in_hand := 0
	var own_cards_in_other_hands := 0
	for voucher in _platter_vouchers():
		if str(voucher.get("ownerParticipantId", "")) == participant_id_for_account:
			own_cards += 1
	for raw_voucher in table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var owner_id := str(voucher.get("ownerParticipantId", ""))
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) != "hand":
			continue
		var holder_id := str(location.get("participantId", ""))
		if owner_id == participant_id_for_account and holder_id == participant_id_for_account:
			own_cards_in_hand += 1
		elif owner_id != participant_id_for_account and holder_id == participant_id_for_account:
			foreign_cards_in_hand += 1
		elif owner_id == participant_id_for_account and holder_id != participant_id_for_account:
			own_cards_in_other_hands += 1
	var opening_target := _rule_int("openingOfferingsPerPlayer", OPENING_OFFERINGS_PER_PLAYER)
	var expected_own_cards_in_hand := _rule_int("vouchersPerIngredient", VOUCHERS_PER_INGREDIENT) - opening_target
	return {
		"ownCardsInPlatter": own_cards,
		"ownCardsInHand": own_cards_in_hand,
		"foreignCardsInHand": foreign_cards_in_hand,
		"ownCardsInOtherHands": own_cards_in_other_hands,
		"expectedOwnCardsInHand": expected_own_cards_in_hand,
		"platterDebt": maxi(0, own_cards - opening_target),
		"platterShortfall": maxi(0, opening_target - own_cards),
		"cleared": own_cards == opening_target and own_cards_in_hand == expected_own_cards_in_hand and foreign_cards_in_hand == 0
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


func _normalize_offer_assets(offered_ids: Array, offered_assets) -> Array:
	if offered_assets is Array and not offered_assets.is_empty():
		return offered_assets.duplicate(true)
	var result: Array = []
	for raw_id in offered_ids:
		result.append({"kind": "voucher", "id": str(raw_id)})
	return result


func _normalize_accepted_assets(voucher_ids: Array, assets) -> Array:
	if assets is Array and not assets.is_empty():
		return assets.duplicate(true)
	var result: Array = []
	for raw_id in voucher_ids:
		result.append({"kind": "voucher", "id": str(raw_id)})
	return result


func _legacy_requested_asset(recipient: Dictionary, requested: Dictionary) -> Dictionary:
	var ingredient_id := str(requested.get("ingredientId", ""))
	var quantity := int(requested.get("quantity", 1))
	if quantity <= 0:
		_fail("Offer request quantity must be positive.")
		return {}
	if ingredient_id == "":
		_fail("Offer must request an asset.")
		return {}
	if ingredient_id != str(recipient.get("ingredientId", "")):
		_fail("Legacy ingredient offers can only ask for the recipient's own ingredient.")
		return {}
	return {"kind": "voucher", "ingredientId": ingredient_id, "ownerParticipantId": recipient.get("id", ""), "quantity": quantity}


func _validate_offer_asset_request(participant_id_for_offer: String, requested: Dictionary) -> bool:
	if int(requested.get("quantity", 1)) <= 0:
		return _fail("Offer request quantity must be positive.")
	match str(requested.get("kind", "")):
		"voucher":
			return true if str(requested.get("ingredientId", "")) != "" else _fail("Requested ingredient is unknown.")
		"dish_part":
			if str(requested.get("dishId", "")) != "" and not table.get("dishes", {}).has(str(requested.get("dishId", ""))):
				return _fail("Requested dish is unknown.")
			return true
	return _fail("Offer request asset is invalid.")


func _offerable_asset_qty(participant_id_for_offer: String, requested: Dictionary) -> int:
	match str(requested.get("kind", "")):
		"voucher":
			var count := 0
			for voucher in _hand_vouchers(participant_id_for_offer):
				if str(voucher.get("ingredientId", "")) != str(requested.get("ingredientId", "")):
					continue
				if requested.has("ownerParticipantId") and str(voucher.get("ownerParticipantId", "")) != str(requested.get("ownerParticipantId", "")):
					continue
				if not _voucher_has_stock(voucher):
					continue
				count += 1
			return count
		"dish_part":
			var count := 0
			for part in _inventory_dish_parts(participant_id_for_offer):
				if str(requested.get("dishId", "")) != "" and str(part.get("dishId", "")) != str(requested.get("dishId", "")):
					continue
				if requested.has("makerParticipantId") and str(part.get("makerParticipantId", "")) != str(requested.get("makerParticipantId", "")):
					continue
				count += 1
			return count
	return 0


func _offerable_unreserved_asset_qty(participant_id_for_offer: String, requested: Dictionary) -> int:
	var count := _offerable_asset_qty(participant_id_for_offer, requested)
	var key := _offer_asset_request_key(requested)
	for offer in table.get("offers", {}).values():
		if str(offer.get("status", "")) != "pending" or str(offer.get("toParticipantId", "")) != participant_id_for_offer:
			continue
		var offer_request: Dictionary = offer.get("requestedAsset", {})
		if _offer_asset_request_key(offer_request) == key:
			count -= int(offer_request.get("quantity", 1))
	return maxi(0, count)


func _offer_asset_request_key(requested: Dictionary) -> String:
	match str(requested.get("kind", "")):
		"voucher":
			return "voucher:%s:%s" % [requested.get("ingredientId", ""), requested.get("ownerParticipantId", "")]
		"dish_part":
			var dish_key := str(requested.get("dishId", ""))
			return "dish_part:%s:%s" % [dish_key if dish_key != "" else "*", requested.get("makerParticipantId", "")]
	return "invalid"


func _asset_matches_offer_request(asset: Dictionary, requested: Dictionary) -> bool:
	var value: Dictionary = asset.get("value", {})
	match str(requested.get("kind", "")):
		"voucher":
			return str(asset.get("kind", "")) == "voucher" and str(value.get("ingredientId", "")) == str(requested.get("ingredientId", "")) and (not requested.has("ownerParticipantId") or str(value.get("ownerParticipantId", "")) == str(requested.get("ownerParticipantId", "")))
		"dish_part":
			return str(asset.get("kind", "")) == "dish_part" and (str(requested.get("dishId", "")) == "" or str(value.get("dishId", "")) == str(requested.get("dishId", ""))) and (not requested.has("makerParticipantId") or str(value.get("makerParticipantId", "")) == str(requested.get("makerParticipantId", "")))
	return false


func _offerable_unreserved_qty(participant_id_for_offer: String, ingredient_id: String) -> int:
	if ingredient_id == "":
		return 0
	var count := _offerable_asset_qty(participant_id_for_offer, {"kind": "voucher", "ingredientId": ingredient_id})
	for offer in table.get("offers", {}).values():
		var requested: Dictionary = offer.get("requestedAsset", {})
		if str(offer.get("status", "")) == "pending" and str(offer.get("toParticipantId", "")) == participant_id_for_offer and str(requested.get("kind", "")) == "voucher" and str(requested.get("ingredientId", "")) == ingredient_id:
			count -= int(requested.get("quantity", 1))
	return maxi(0, count)


func _auto_refuse_unavailable_offers() -> void:
	var remaining := {}
	for offer_id in table.get("offers", {}).keys().duplicate():
		var offer: Dictionary = table["offers"][offer_id]
		if str(offer.get("status", "")) != "pending":
			continue
		if not _offered_assets_still_locked_and_backed(offer):
			_release_offered_assets(offer)
			table["offers"].erase(offer_id)
			continue
		var requested: Dictionary = offer.get("requestedAsset", {})
		if requested.is_empty():
			requested = _legacy_requested_asset(_participant_by_id(str(offer.get("toParticipantId", ""))), offer.get("requested", {}))
		var key := "%s:%s" % [offer.get("toParticipantId", ""), _offer_asset_request_key(requested)]
		if not remaining.has(key):
			remaining[key] = _offerable_asset_qty(str(offer.get("toParticipantId", "")), requested)
		if int(remaining[key]) >= int(requested.get("quantity", 1)):
			remaining[key] = int(remaining[key]) - int(requested.get("quantity", 1))
			continue
		_record_scarcity_pressure(requested, maxi(1, int(requested.get("quantity", 1)) - maxi(0, int(remaining[key]))))
		_release_offered_assets(offer)
		table["offers"].erase(offer_id)


func _record_scarcity_pressure(requested: Dictionary, missing_amount: int = 1) -> void:
	if str(requested.get("kind", "")) != "voucher":
		return
	var ingredient_id := str(requested.get("ingredientId", ""))
	if ingredient_id == "":
		return
	if not table.has("scarcityPressureByIngredient") or typeof(table.get("scarcityPressureByIngredient")) != TYPE_DICTIONARY:
		table["scarcityPressureByIngredient"] = {}
	var pressure: Dictionary = table["scarcityPressureByIngredient"]
	pressure[ingredient_id] = int(pressure.get(ingredient_id, 0)) + maxi(1, missing_amount)


func _offered_assets_still_locked_and_backed(offer: Dictionary) -> bool:
	for raw_ref in offer.get("offeredAssets", []):
		var asset := _resolve_asset(raw_ref)
		if asset.is_empty():
			return false
		var location: Dictionary = asset.get("value", {}).get("location", {})
		if str(location.get("type", "")) != "offer_lock" or str(location.get("offerId", "")) != str(offer.get("id", "")):
			return false
		if not _require_asset_backed_by_stock(asset):
			return false
	return true


func _release_offered_assets(offer: Dictionary) -> void:
	for raw_ref in offer.get("offeredAssets", []):
		var asset := _resolve_asset(raw_ref)
		if asset.is_empty():
			continue
		var value: Dictionary = asset.get("value", {})
		var location: Dictionary = value.get("location", {})
		if str(location.get("type", "")) != "offer_lock" or str(location.get("offerId", "")) != str(offer.get("id", "")):
			continue
		_move_asset_to_inventory(asset, str(offer.get("fromParticipantId", "")))


func _release_offered_vouchers(offer: Dictionary) -> void:
	_release_offered_assets(offer)


func _cancel_all_pending_offers() -> void:
	for offer_id in table.get("offers", {}).keys().duplicate():
		var offer: Dictionary = table["offers"][offer_id]
		_release_offered_assets(offer)
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


func _move_asset_to_offer_lock(asset: Dictionary, offer_id: String) -> void:
	var value: Dictionary = asset.get("value", {})
	value["location"] = {"type": "offer_lock", "offerId": offer_id}


func _asset_label(asset: Dictionary) -> String:
	var value: Dictionary = asset.get("value", {})
	if str(asset.get("kind", "")) == "voucher":
		return _ingredient_name(str(value.get("ingredientId", "")))
	return "%s %s" % [value.get("dishName", "Dish"), value.get("unitSingular", "part")]


func _asset_list_label(asset_refs: Array) -> String:
	var labels: Array[String] = []
	for raw_ref in asset_refs:
		var asset := _resolve_asset(raw_ref)
		if not asset.is_empty():
			labels.append(_asset_label(asset))
	return ", ".join(labels)


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
	for raw_id in _offer_voucher_ref_ids(offer, "offered"):
		var voucher := _voucher_by_id(str(raw_id))
		if not voucher.is_empty():
			offered.append(voucher.duplicate(true))
	result["offeredVouchers"] = offered
	var offered_parts: Array = []
	for raw_ref in offer.get("offeredAssets", []):
		if str(raw_ref.get("kind", "")) != "dish_part":
			continue
		var part: Dictionary = table.get("dishParts", {}).get(str(raw_ref.get("id", "")), {})
		if not part.is_empty():
			offered_parts.append(part.duplicate(true))
	result["offeredDishParts"] = offered_parts
	var accepted_vouchers: Array = []
	for raw_id in _offer_voucher_ref_ids(offer, "accepted"):
		var voucher := _voucher_by_id(str(raw_id))
		if not voucher.is_empty():
			accepted_vouchers.append(voucher.duplicate(true))
	result["acceptedVouchers"] = accepted_vouchers
	var accepted_parts: Array = []
	for raw_ref in offer.get("acceptedAssets", []):
		if str(raw_ref.get("kind", "")) != "dish_part":
			continue
		var part: Dictionary = table.get("dishParts", {}).get(str(raw_ref.get("id", "")), {})
		if not part.is_empty():
			accepted_parts.append(part.duplicate(true))
	result["acceptedDishParts"] = accepted_parts
	return result


func _offer_voucher_ref_ids(offer: Dictionary, prefix: String) -> Array:
	var ids: Array = []
	var id_key := "%sVoucherIds" % prefix
	for raw_id in offer.get(id_key, []):
		var id := str(raw_id)
		if id != "" and not ids.has(id):
			ids.append(id)
	var asset_key := "%sAssets" % prefix
	for raw_ref in offer.get(asset_key, []):
		var ref: Dictionary = raw_ref
		if str(ref.get("kind", "")) != "voucher":
			continue
		var id := str(ref.get("id", ""))
		if id != "" and not ids.has(id):
			ids.append(id)
	return ids


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


func _first_surplus_voucher(participant_id_for_bot: String, hand: Array, recipe: Dictionary, excluded_ingredient_id := "") -> Dictionary:
	var protected_by_ingredient := {}
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var outstanding: int = int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()
		if outstanding > 0:
			var ingredient_id := str(requirement.get("ingredientId", ""))
			protected_by_ingredient[ingredient_id] = int(protected_by_ingredient.get(ingredient_id, 0)) + outstanding
	var held_by_ingredient := {}
	for voucher in hand:
		if not _voucher_has_stock(voucher):
			continue
		var ingredient_id := str(voucher.get("ingredientId", ""))
		if ingredient_id == excluded_ingredient_id:
			continue
		var held_count := int(held_by_ingredient.get(ingredient_id, 0)) + 1
		held_by_ingredient[ingredient_id] = held_count
		if held_count > int(protected_by_ingredient.get(ingredient_id, 0)):
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


func _foreign_card_return_candidate(holder_id: String, snapshot: Dictionary) -> Dictionary:
	var candidates: Array = []
	for voucher in _hand_vouchers(holder_id):
		if not _voucher_has_stock(voucher):
			continue
		var owner_id := str(voucher.get("ownerParticipantId", ""))
		if owner_id == holder_id:
			continue
		var owner_public := _snapshot_participant(snapshot, owner_id)
		if int(owner_public.get("platterShortfall", 0)) <= 0:
			continue
		var take_part := _settlement_food_part_for_foreign_card(holder_id, owner_id)
		if take_part.is_empty():
			continue
		candidates.append({
			"voucherId": voucher.get("id", ""),
			"partId": take_part.get("id", ""),
			"rank": _settlement_foreign_card_rank(owner_public)
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rank := int(left.get("rank", 0))
		var right_rank := int(right.get("rank", 0))
		if left_rank == right_rank:
			return str(left.get("voucherId", "")) < str(right.get("voucherId", ""))
		return left_rank < right_rank
	)
	if not candidates.is_empty():
		return candidates[0]
	return {}


func _settlement_foreign_card_rank(owner_public: Dictionary) -> int:
	if owner_public.is_empty():
		return 3
	if int(owner_public.get("platterShortfall", 0)) > 0:
		return 0
	if int(owner_public.get("ownCardsInOtherHands", 0)) > 0:
		return 1
	return 2


func _settlement_food_part_for_foreign_card(holder_id: String, owner_id: String) -> Dictionary:
	var owner_part := _first_platter_food_part_by_maker(owner_id)
	if not owner_part.is_empty():
		return owner_part
	for part in _platter_dish_parts():
		if str(part.get("makerParticipantId", "")) != holder_id:
			return part
	var parts := _platter_dish_parts()
	if not parts.is_empty():
		return parts[0]
	return {}


func _snapshot_participant(snapshot: Dictionary, participant_id_for_lookup: String) -> Dictionary:
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("id", "")) == participant_id_for_lookup:
			return participant
	return {}


func _first_platter_food_part_by_maker(maker_id: String) -> Dictionary:
	for part in _platter_dish_parts():
		if str(part.get("makerParticipantId", "")) == maker_id:
			return part
	return {}


func _platter_has_food_part_by_maker(maker_id: String) -> bool:
	return not _first_platter_food_part_by_maker(maker_id).is_empty()


func _first_platter_voucher_not_owner(owner_id: String) -> Dictionary:
	for voucher in _platter_vouchers():
		if str(voucher.get("ownerParticipantId", "")) != owner_id and _voucher_has_stock(voucher):
			return voucher
	return {}


func _first_platter_voucher() -> Dictionary:
	for voucher in _platter_vouchers():
		if _voucher_has_stock(voucher):
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


func _settlement_give_asset(holder_id: String, snapshot: Dictionary, allow_own_voucher: bool) -> Dictionary:
	var parts := _inventory_dish_parts(holder_id)
	if not parts.is_empty():
		return {"kind": "dish_part", "id": parts[0].get("id", "")}
	for voucher in _hand_vouchers(holder_id):
		if not _voucher_has_stock(voucher):
			continue
		var owner_id := str(voucher.get("ownerParticipantId", ""))
		if owner_id == holder_id:
			continue
		var owner_public := _snapshot_participant(snapshot, owner_id)
		if int(owner_public.get("platterShortfall", 0)) > 0:
			return {"kind": "voucher", "id": voucher.get("id", "")}
	for voucher in _hand_vouchers(holder_id):
		if str(voucher.get("ownerParticipantId", "")) != holder_id and _voucher_has_stock(voucher):
			return {"kind": "voucher", "id": voucher.get("id", "")}
	for voucher in _hand_vouchers(holder_id):
		if (allow_own_voucher or str(voucher.get("ownerParticipantId", "")) != holder_id) and _voucher_has_stock(voucher):
			return {"kind": "voucher", "id": voucher.get("id", "")}
	return {}


func _settlement_seed_take_asset(holder_id: String) -> Dictionary:
	for part in _platter_dish_parts():
		if str(part.get("makerParticipantId", "")) != holder_id:
			return {"kind": "dish_part", "id": part.get("id", "")}
	var parts := _platter_dish_parts()
	if not parts.is_empty():
		return {"kind": "dish_part", "id": parts[0].get("id", "")}
	return {}


func _first_platter_asset_not_owner(owner_id: String) -> Dictionary:
	for part in _platter_dish_parts():
		return {"kind": "dish_part", "id": part.get("id", "")}
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
	return _strip_short_bot_suffix(clean)


func _strip_short_bot_suffix(base: String) -> String:
	var clean := base.strip_edges()
	var lower := clean.to_lower()
	if lower.ends_with("_b"):
		return clean.substr(0, clean.length() - 2).strip_edges()
	var marker := lower.rfind("_b_")
	if marker < 0:
		return clean
	var suffix := lower.substr(marker + 3)
	if not _is_all_digits(suffix):
		return clean
	return clean.substr(0, marker).strip_edges()


func _is_all_digits(value: String) -> bool:
	if value == "":
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


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
	clean = _strip_short_bot_suffix(clean)
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
