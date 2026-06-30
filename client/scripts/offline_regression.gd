extends SceneTree

const OfflineStore := preload("res://scripts/offline_store.gd")

var _last_error := ""


func _initialize() -> void:
	var store = OfflineStore.new()
	root.add_child(store)
	store.error_received.connect(func(error: Dictionary) -> void:
		_last_error = str(error.get("description", JSON.stringify(error)))
	)
	_regression_lobby_seat_editor(store)
	_regression_lobby_rename_then_start_from_controlled_view(store)
	_regression_public_recipe_summary(store)
	_regression_own_redeem_returns_card_for_swap(store)
	_regression_redeem_all_and_pass_turn(store)
	_regression_redeem_pass_auto_prepares(store)
	_regression_bot_batches_redeem_and_pass(store)
	_regression_bot_swaps_surplus_before_redeem(store)
	_regression_bot_spends_food_piece_for_platter_card(store)
	_regression_bot_offer_prefers_smallest_missing_group(store)
	_regression_bot_offers_food_piece_for_missing_card(store)
	_regression_goal_complete_bot_accepts_offer(store)
	_regression_asset_offered_voucher_snapshot_details(store)
	_regression_return_owner_card_for_food_piece_offer(store)
	_regression_same_card_offer_rejected(store)
	_regression_stock_depleted_cards_not_usable(store)
	_regression_lifecycle(store)
	_regression_auto_share_skips_manual_eating(store)
	_regression_settlement_requires_returned_promise_cards(store)
	_regression_bot_settlement_avoids_food_part_cycle(store)
	_regression_bot_settlement_shortfall_extra_own_card(store)
	_regression_bot_settlement_direct_offer_for_food_piece(store)
	_regression_round_robin_pass_turn_history(store)
	_regression_bot_budget_returns_to_human(store)
	await _regression_bot_run_is_deferred_after_pass(store)
	await _regression_renamed_bot_acts_after_pass(store)
	_regression_full_offline_transaction_export(store)
	print("offline regression ok")
	quit()


func _regression_lobby_seat_editor(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-seat-editor").is_empty(), "create seat editor table")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p1", "name": "Mara"}), "rename host seat: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p1", {}).get("name", "")) == "Mara", "offline host seat can be renamed")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p2", "name": "Zed"}), "rename bot seat: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "Zed_b", "offline bot seat keeps short _b name")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p2", "name": "Zed_bx"}), "rename edited bot seat: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "Zed_bx", "offline explicit bot name edit is preserved")
	_require(store.handle_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "Ted"}), "take bot seat as player: %s" % _last_error)
	var controlled: Dictionary = store.table.get("participants", {}).get("p2", {})
	_require(str(controlled.get("kind", "")) == "human", "offline taken seat becomes player")
	_require(str(controlled.get("controllerParticipantId", "")) == "p1", "offline taken seat is controlled by host")
	_require(str(controlled.get("name", "")) == "Ted", "offline taken seat keeps edited player name")
	_require(store.handle_host_intent({"type": "convert_to_bot", "participantId": "p2", "botType": "mixed"}), "return controlled seat to bot: %s" % _last_error)
	var bot: Dictionary = store.table.get("participants", {}).get("p2", {})
	_require(str(bot.get("kind", "")) == "bot", "offline seat can return to bot")
	_require(str(bot.get("name", "")) == "Ted_b", "offline returned bot uses short _b name")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p2", "name": "jjj_b_2"}), "rename accumulated bot suffix: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "jjj_b", "offline accumulated short bot suffix is normalized")
	_require(store.handle_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "jjj_b"}), "take suffixed bot seat as player: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "jjj_b", "offline controlled seat can keep typed suffixed name")
	_require(store.handle_host_intent({"type": "convert_to_bot", "participantId": "p2", "botType": "mixed"}), "return suffixed controlled seat to bot: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "jjj_b", "offline player-to-bot conversion does not create jjj_b_2")


func _regression_lobby_rename_then_start_from_controlled_view(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-lobby-rename-start").is_empty(), "create lobby rename-start table")
	_require(store.handle_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "Ted"}), "take controlled seat before rename-start: %s" % _last_error)
	_require(store.view_as("p2"), "view controlled seat before lobby rename-start")
	_require(
		not store.handle_intent({"type": "rename_participant", "participantId": "p3", "name": "Pip"}),
		"controlled non-host view cannot rename another bot directly"
	)
	_require(_last_error.contains("Only the host"), "direct controlled-seat rename reports host requirement")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p3", "name": "Pip"}), "host rename bot while viewing controlled seat: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p3", {}).get("name", "")) == "Pip_b", "host-edited bot name is committed before start")
	_require(store.handle_host_intent({"type": "start"}), "start after host-edited bot name: %s" % _last_error)
	_require(str(store.table.get("phase", "")) == "playing", "start succeeds after host-edited bot name")
	_require(str(store.table.get("participants", {}).get("p3", {}).get("name", "")) == "Pip_b", "host-edited bot name survives start")
	_require(bool(store.table.get("participants", {}).get("p3", {}).get("depositedInitial", false)), "renamed bot participates in automatic offering")
	_require(int(store.table.get("participants", {}).get("p3", {}).get("openingOfferingsCount", 0)) == 2, "renamed bot contributes two opening offerings")


func _regression_public_recipe_summary(store: Node) -> void:
	_setup_round_robin_table(store)
	_require(store.view_as("p1"), "view p1 for public recipe summary")
	var snapshot: Dictionary = store.latest_snapshot
	var public_other := _public_participant(snapshot, "p2")
	var recipe: Dictionary = store.table.get("recipes", {}).get("p2", {})
	var summary: Dictionary = public_other.get("currentRecipe", {})
	_require(not summary.is_empty(), "offline public participant includes current recipe summary")
	_require(str(summary.get("name", "")) == str(recipe.get("name", "")), "offline public recipe summary exposes recipe name")
	var held_useful_counts := {}
	for voucher in store._hand_vouchers("p2"):
		if not store._voucher_has_stock(voucher):
			continue
		var held_ingredient_id := str(voucher.get("ingredientId", ""))
		held_useful_counts[held_ingredient_id] = int(held_useful_counts.get(held_ingredient_id, 0)) + 1
	var expected_missing: Array = []
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		var ingredient_id := str(requirement.get("ingredientId", ""))
		var missing := maxi(
			0,
			int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - int(held_useful_counts.get(ingredient_id, 0))
		)
		if missing > 0:
			expected_missing.append({
				"ingredientId": ingredient_id,
				"missingQty": missing
			})
	_require(JSON.stringify(summary.get("missingRequirements", [])) == JSON.stringify(expected_missing), "offline public recipe summary exposes missing counters only")
	for raw_summary in summary.get("missingRequirements", []):
		var missing_requirement: Dictionary = raw_summary
		_require(str(missing_requirement.get("ingredientId", "")) != _participant_ingredient_id(store, "p2"), "offline public recipe summary omits useful cards already held by the other cook")
	_require(not snapshot.has("allHands"), "offline active snapshot does not expose all hands")
	_require(not snapshot.has("allRecipes"), "offline active snapshot does not expose all recipes")


func _regression_own_redeem_returns_card_for_swap(store: Node) -> void:
	_setup_round_robin_table(store)
	var participant_id := "p1"
	var main_ingredient_id := _participant_ingredient_id(store, participant_id)
	var requirement := _requirement_for_ingredient(store, participant_id, main_ingredient_id)
	_require(not requirement.is_empty(), "own ingredient is present in recipe")
	var voucher := _first_hand_voucher_by_ingredient(store, participant_id, main_ingredient_id)
	_require(not voucher.is_empty(), "own ingredient card starts in hand")
	_require(
		store.handle_intent({"type": "redeem_from_hand", "voucherId": voucher.get("id", ""), "requirementId": requirement.get("id", "")}, participant_id),
		"redeem own card from hand succeeds: %s" % _last_error
	)
	var returned := _first_hand_voucher_by_ingredient(store, participant_id, main_ingredient_id)
	_require(not returned.is_empty(), "redeemed own card returns to hand while stock remains")
	var take := _first_platter_voucher_not_ingredient(store, main_ingredient_id)
	_require(not take.is_empty(), "platter has a different card after deposits")
	_require(
		store.handle_intent({"type": "platter_swap", "giveVoucherId": returned.get("id", ""), "takeVoucherId": take.get("id", "")}, participant_id),
		"returned own card can be swapped from hand: %s" % _last_error
	)


func _regression_lifecycle(store: Node) -> void:
	_setup_round_robin_table(store)
	_assert_invalid_intent_rolls_back(store)
	_assert_platter_swap(store)
	_assert_offer_exchange(store)
	var maker_id := "p1"
	_complete_recipe(store, maker_id)
	_require(store.handle_intent({"type": "prepare"}, maker_id), "prepare dish: %s" % _last_error)
	var dish_id := _first_dish_id(store, maker_id)
	_require(dish_id != "", "prepared dish exists")
	_require(_inventory_dish_parts(store, maker_id).size() == 10, "prepared dish creates 10 food parts")
	_assert_settlement_and_eating(store, maker_id, dish_id)


func _regression_settlement_requires_returned_promise_cards(store: Node) -> void:
	_setup_round_robin_table(store)
	for participant_id in _active_ids(store.latest_snapshot):
		_complete_recipe(store, participant_id)
		_require(store.handle_intent({"type": "prepare"}, participant_id), "prepare settlement card-return dish: %s" % _last_error)
	var holder_id := "p1"
	var owner_id := "p2"
	_force_all_accounts_cleared(store)
	var owner_card := _first_hand_voucher_by_owner(store, owner_id, owner_id)
	_require(not owner_card.is_empty(), "owner has own card before foreign-card settlement setup")
	store.table["vouchers"][str(owner_card.get("id", ""))]["location"] = {"type": "hand", "participantId": holder_id}
	store._enter_settlement_phase()
	store._emit_snapshot()
	_require(str(store.table.get("phase", "")) == "settlement", "foreign card in hand blocks eating")
	var holder_public := _public_participant(store.latest_snapshot, holder_id)
	var owner_public := _public_participant(store.latest_snapshot, owner_id)
	_require(int(holder_public.get("foreignCardsInHand", 0)) == 1 and not bool(holder_public.get("cleared", true)), "holder is not settled while holding another cook's card")
	_require(int(owner_public.get("ownCardsInOtherHands", 0)) == 1 and not bool(owner_public.get("cleared", true)), "owner is not settled while their card is held elsewhere")

	var owner_part: Dictionary = _inventory_dish_parts(store, owner_id)[0]
	var owner_platter := _first_platter_voucher_by_owner(store, owner_id)
	_require(not owner_platter.is_empty(), "owner has a deposited card to pull from platter")
	store.table["currentTurnParticipantId"] = owner_id
	_require(
		store.handle_intent({"type": "platter_asset_swap", "give": {"kind": "dish_part", "id": owner_part.get("id", "")}, "take": {"kind": "voucher", "id": owner_platter.get("id", "")}}, owner_id),
		"owner creates food-piece liquidity: %s" % _last_error
	)
	_require(str(store.table.get("phase", "")) == "settlement", "owner shortfall still blocks eating")
	store.table["currentTurnParticipantId"] = holder_id
	_require(
		store.handle_intent({"type": "platter_asset_swap", "give": {"kind": "voucher", "id": owner_card.get("id", "")}, "take": {"kind": "dish_part", "id": owner_part.get("id", "")}}, holder_id),
		"holder returns foreign promise card for food piece: %s" % _last_error
	)
	holder_public = _public_participant(store.latest_snapshot, holder_id)
	owner_public = _public_participant(store.latest_snapshot, owner_id)
	_require(bool(holder_public.get("cleared", false)) and int(holder_public.get("foreignCardsInHand", 0)) == 0, "holder settles after returning foreign card")
	_require(bool(owner_public.get("cleared", false)) and int(owner_public.get("ownCardsInOtherHands", 0)) == 0, "owner settles after own card returns to basket")
	_require(str(store.table.get("phase", "")) == "complete", "offline settlement auto-shares food after cards are returned")
	_require(_inventory_dish_parts(store, holder_id).is_empty(), "holder food is shared automatically")


func _regression_auto_share_skips_manual_eating(store: Node) -> void:
	_setup_round_robin_table(store)
	for participant_id in ["p1", "p2"]:
		_complete_recipe(store, participant_id)
		store.table["currentTurnParticipantId"] = participant_id
		_require(store.handle_intent({"type": "prepare"}, participant_id), "prepare eating skip dish: %s" % _last_error)
	for participant_id in _active_ids(store.latest_snapshot):
		store.table["participants"][participant_id]["dishCount"] = 1
		store.table["recipes"].erase(participant_id)
	_force_all_accounts_cleared(store)
	store._enter_settlement_phase()
	store._advance_settlement_if_ready()
	_require(str(store.table.get("phase", "")) == "complete", "settlement auto-shares food instead of entering manual eating")
	_require(_inventory_dish_parts(store, "p1").is_empty(), "p1 food is shared automatically")
	_require(_inventory_dish_parts(store, "p2").is_empty(), "p2 food is shared automatically")
	_require(_inventory_dish_parts(store, "p3").is_empty(), "p3 still has no food")
	_require(str(store.table.get("currentTurnParticipantId", "")) == "", "complete offline table clears current turn")


func _regression_bot_settlement_avoids_food_part_cycle(store: Node) -> void:
	_setup_round_robin_table(store)
	var owner_id := "p2"
	var holder_id := "p3"
	store.table["participants"][holder_id]["kind"] = "bot"
	store.table["participants"][holder_id]["botType"] = "mixed"
	_complete_recipe(store, owner_id)
	_require(store.handle_intent({"type": "prepare"}, owner_id), "prepare owner dish for settlement cycle test: %s" % _last_error)
	_complete_recipe(store, holder_id)
	_require(store.handle_intent({"type": "prepare"}, holder_id), "prepare holder dish for settlement cycle test: %s" % _last_error)
	_force_all_accounts_cleared(store)

	var owner_card := _first_platter_voucher_by_owner(store, owner_id)
	_require(not owner_card.is_empty(), "owner has platter card before cycle setup")
	store.table["vouchers"][str(owner_card.get("id", ""))]["location"] = {"type": "hand", "participantId": holder_id}
	var holder_part: Dictionary = _inventory_dish_parts(store, holder_id)[0]
	var owner_part: Dictionary = _inventory_dish_parts(store, owner_id)[0]
	store.table["dishParts"][str(holder_part.get("id", ""))]["location"] = {"type": "platter"}
	store.table["phase"] = "settlement"
	store.table["currentTurnParticipantId"] = holder_id
	store.view_as(holder_id)

	var decision: Dictionary = store._decide_bot_settlement(holder_id, store.latest_snapshot)
	_require(str(decision.get("type", "")) == "create_offer", "bot prefers direct card return over reversible platter food swap")
	_require(str(decision.get("toParticipantId", "")) == owner_id, "direct settlement cycle guard offer goes to card owner")
	_require(str(decision.get("offeredVoucherIds", [])[0]) == str(owner_card.get("id", "")), "direct settlement cycle guard locks the foreign card")
	_require(store.handle_intent(decision, holder_id, false), "create direct settlement cycle guard offer: %s" % _last_error)
	var offer_id := _first_pending_offer_id(store)
	_require(offer_id != "", "direct settlement cycle guard offer is pending")
	store.table["currentTurnParticipantId"] = owner_id
	_require(
		store.handle_intent({"type": "respond_offer", "offerId": offer_id, "response": "accept", "assets": [{"kind": "dish_part", "id": owner_part.get("id", "")}]}, owner_id, false),
		"accept direct settlement cycle guard offer: %s" % _last_error
	)
	var holder_public := _public_participant(store.latest_snapshot, holder_id)
	var owner_public := _public_participant(store.latest_snapshot, owner_id)
	_require(int(holder_public.get("foreignCardsInHand", 0)) == 0, "bot no longer holds the foreign card")
	_require(int(owner_public.get("ownCardsInOtherHands", 0)) == 0, "owner card is no longer stranded in another hand")
	decision = store._decide_bot_settlement(holder_id, store.latest_snapshot)
	_require(str(decision.get("type", "")) == "pass_turn", "bot passes after one settlement swap instead of looping in the same turn")


func _regression_bot_settlement_shortfall_extra_own_card(store: Node) -> void:
	_setup_round_robin_table(store)
	var host_id := "p1"
	var bot_id := "p2"
	store.table["participants"][bot_id]["kind"] = "bot"
	store.table["participants"][bot_id]["botType"] = "mixed"
	for participant_id in _active_ids(store.latest_snapshot):
		_complete_recipe(store, participant_id)
		_require(store.handle_intent({"type": "prepare"}, participant_id), "prepare shortfall settlement dish: %s" % _last_error)
	_force_all_accounts_cleared(store)

	var bot_own_platter := _first_platter_voucher_by_owner(store, bot_id)
	var host_part: Dictionary = _inventory_dish_parts(store, host_id)[0]
	_require(not bot_own_platter.is_empty(), "bot has own platter card before shortfall setup")
	store.table["vouchers"][str(bot_own_platter.get("id", ""))]["location"] = {"type": "hand", "participantId": bot_id}
	store.table["dishParts"][str(host_part.get("id", ""))]["location"] = {"type": "platter"}
	store.table["phase"] = "settlement"
	store.table["currentTurnParticipantId"] = bot_id
	store.view_as(bot_id)

	var public_bot := _public_participant(store.latest_snapshot, bot_id)
	_require(int(public_bot.get("ownCardsInPlatter", 0)) == 1, "bot has one own card in the platter")
	_require(int(public_bot.get("ownCardsInHand", 0)) == 7, "bot has an extra own card in hand")
	_require(int(public_bot.get("platterShortfall", 0)) == 1, "bot has a one-card platter shortfall")

	var decision: Dictionary = store._decide_bot_settlement(bot_id, store.latest_snapshot)
	_require(str(decision.get("type", "")) == "platter_asset_swap", "bot fills shortfall with extra own card")
	_require(str(decision.get("give", {}).get("id", "")) == str(bot_own_platter.get("id", "")), "bot gives the extra own card")
	_require(str(decision.get("take", {}).get("kind", "")) == "dish_part", "bot takes a food piece")
	_require(str(decision.get("take", {}).get("id", "")) == str(host_part.get("id", "")), "bot takes the platter food piece")
	_require(store.handle_intent(decision, bot_id, false), "apply bot shortfall settlement swap: %s" % _last_error)
	public_bot = _public_participant(store.latest_snapshot, bot_id)
	_require(int(public_bot.get("ownCardsInPlatter", 0)) == 2, "bot restores two own cards in the platter")
	_require(int(public_bot.get("ownCardsInHand", 0)) == 6, "bot restores six own cards in hand")
	_require(bool(public_bot.get("cleared", false)), "bot clears after shortfall swap")


func _regression_bot_settlement_direct_offer_for_food_piece(store: Node) -> void:
	_setup_round_robin_table(store)
	var owner_id := "p2"
	var holder_id := "p3"
	store.table["participants"][holder_id]["kind"] = "bot"
	store.table["participants"][holder_id]["botType"] = "mixed"
	for participant_id in _active_ids(store.latest_snapshot):
		_complete_recipe(store, participant_id)
		_require(store.handle_intent({"type": "prepare"}, participant_id), "prepare direct-offer settlement dish: %s" % _last_error)
	_force_all_accounts_cleared(store)

	var owner_card := _first_hand_voucher_by_owner(store, owner_id, owner_id)
	var owner_part: Dictionary = _inventory_dish_parts(store, owner_id)[0]
	_require(not owner_card.is_empty(), "owner has own hand card before direct settlement offer")
	store.table["vouchers"][str(owner_card.get("id", ""))]["location"] = {"type": "hand", "participantId": holder_id}
	store.table["phase"] = "settlement"
	store.table["currentTurnParticipantId"] = holder_id
	store.view_as(holder_id)

	var decision: Dictionary = store._decide_bot_settlement(holder_id, store.latest_snapshot)
	_require(str(decision.get("type", "")) == "create_offer", "bot offers stranded foreign card directly when no platter food piece exists")
	_require(str(decision.get("toParticipantId", "")) == owner_id, "direct settlement offer goes to card owner")
	_require(str(decision.get("offeredVoucherIds", [])[0]) == str(owner_card.get("id", "")), "direct settlement offer locks the foreign card")
	_require(str(decision.get("requestedAsset", {}).get("kind", "")) == "dish_part", "direct settlement offer asks for a food piece")
	_require(str(decision.get("requestedAsset", {}).get("dishId", "")) == "", "direct settlement offer can accept any held food piece")
	_require(store.handle_intent(decision, holder_id, false), "create direct settlement offer: %s" % _last_error)
	var offer_id := _first_pending_offer_id(store)
	_require(offer_id != "", "direct settlement offer is pending")

	store.table["currentTurnParticipantId"] = owner_id
	_require(
		store.handle_intent({"type": "respond_offer", "offerId": offer_id, "response": "accept", "assets": [{"kind": "dish_part", "id": owner_part.get("id", "")}]}, owner_id, false),
		"accept direct settlement offer: %s" % _last_error
	)
	_require(bool(_public_participant(store.latest_snapshot, owner_id).get("cleared", false)), "owner clears after direct card return")
	_require(bool(_public_participant(store.latest_snapshot, holder_id).get("cleared", false)), "holder clears after direct card return")
	_require(str(store.table.get("phase", "")) == "complete", "direct settlement exchange auto-shares food after clearing")


func _regression_redeem_all_and_pass_turn(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-redeem-all-pass").is_empty(), "create redeem-all table")
	for _index in range(7):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add controlled seat: %s" % _last_error)
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 1}), "set one-dish goal")
	_require(store.handle_host_intent({"type": "start"}), "start redeem-all table: %s" % _last_error)
	_require(str(store.table.get("phase", "")) == "playing", "redeem-all table enters playing")
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p1", "redeem-all starts with p1")
	var ingredient_id := _participant_ingredient_id(store, "p1")
	var requirement := _requirement_for_ingredient(store, "p1", ingredient_id)
	_require(not requirement.is_empty(), "redeem-all recipe includes p1 ingredient")
	var before_redeemed := int(requirement.get("redeemedQty", 0))
	var placed_ids: Array = requirement.get("placedVoucherIds", [])
	var outstanding: int = int(requirement.get("requiredQty", 0)) - before_redeemed - placed_ids.size()
	var before_stock := int(store.table.get("participants", {}).get("p1", {}).get("realIngredientStock", 0))
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(voucher.get("ingredientId", "")) == ingredient_id and str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == "p1":
			voucher["location"] = {"type": "hand", "participantId": "p2"}
	_require(_hand_voucher_count_by_ingredient(store, "p1", ingredient_id) == 0, "redeem-all setup removes own ingredient hand cards")
	var expected_redeemed := mini(before_stock, outstanding)
	_require(store.handle_intent({"type": "redeem_all_and_pass_turn"}, "p1", false), "redeem-all pass succeeds: %s" % _last_error)
	requirement = _requirement_for_ingredient(store, "p1", ingredient_id)
	_require(int(requirement.get("redeemedQty", 0)) == before_redeemed + expected_redeemed, "redeem-all fills own ingredient slots from stock")
	_require(int(store.table.get("participants", {}).get("p1", {}).get("realIngredientStock", 0)) == before_stock - expected_redeemed, "redeem-all decrements stock once per own-stock redemption")
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p2", "redeem-all advances to p2")
	var history: Array = store.table.get("transactionHistory", [])
	var redeem_rows := history.filter(func(row: Dictionary) -> bool:
		return str(row.get("action", "")) == "Redeem" and str(row.get("participantId", "")) == "p1"
	)
	_require(not redeem_rows.is_empty() and str(redeem_rows[0].get("metadata", {}).get("redemptionSource", "")) == "own_stock", "redeem-all records own-stock redemption metadata")
	var last: Dictionary = history[history.size() - 1]
	_require(str(last.get("action", "")) == "Pass Turn", "redeem-all records final pass turn")


func _regression_redeem_pass_auto_prepares(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-redeem-pass-auto-prepare").is_empty(), "create redeem-pass auto-prepare table")
	_require(store.handle_host_intent({"type": "start"}), "start redeem-pass auto-prepare table: %s" % _last_error)
	var participant_id := "p1"
	var ingredient_id := _participant_ingredient_id(store, participant_id)
	var recipe: Dictionary = store.table.get("recipes", {}).get(participant_id, {})
	var final_requirement := _requirement_for_ingredient(store, participant_id, ingredient_id)
	_require(not recipe.is_empty() and not final_requirement.is_empty(), "auto-prepare recipe includes participant ingredient")
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		requirement["placedVoucherIds"] = []
		requirement["redeemedQty"] = int(requirement.get("requiredQty", 0)) - 1 if str(requirement.get("id", "")) == str(final_requirement.get("id", "")) else int(requirement.get("requiredQty", 0))
	var before_recipe_id := str(recipe.get("id", ""))
	var before_history_size: int = store.table.get("transactionHistory", []).size()
	_require(store.handle_intent({"type": "redeem_all_and_pass_turn"}, participant_id, false), "redeem-pass auto-prepares: %s" % _last_error)
	_require(int(store.table.get("participants", {}).get(participant_id, {}).get("dishCount", 0)) == 1, "redeem-pass increments dish count")
	_require(_inventory_dish_parts(store, participant_id).size() == 10, "redeem-pass creates prepared dish parts")
	_require(str(store.table.get("recipes", {}).get(participant_id, {}).get("id", "")) != before_recipe_id, "redeem-pass assigns next recipe")
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p2", "redeem-pass advances only after auto-prepare")
	var actions: Array = []
	var history: Array = store.table.get("transactionHistory", [])
	for index in range(before_history_size, history.size()):
		actions.append(str(history[index].get("action", "")))
	_require(JSON.stringify(actions) == JSON.stringify(["Redeem", "Prepare", "Pass Turn"]), "redeem-pass records redeem, prepare, pass in order")
	_require(str(history[before_history_size].get("metadata", {}).get("redemptionSource", "")) == "own_stock", "redeem-pass auto-prepare records own-stock redeem source")


func _regression_bot_batches_redeem_and_pass(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-batch-redeem").is_empty(), "create bot batch redeem table")
	_require(store.handle_host_intent({"type": "start"}), "start bot batch redeem table: %s" % _last_error)
	var bot_id := "p2"
	var bot: Dictionary = store.table.get("participants", {}).get(bot_id, {})
	bot["botType"] = "pool_only"
	store.table["currentTurnParticipantId"] = bot_id
	var recipe: Dictionary = store.table.get("recipes", {}).get(bot_id, {})
	recipe["requirements"] = [
		{"id": "bot-own-stock", "ingredientId": str(bot.get("ingredientId", "")), "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
	]
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(voucher.get("ingredientId", "")) == str(bot.get("ingredientId", "")) and str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == bot_id:
			voucher["location"] = {"type": "hand", "participantId": "p1"}
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	_require(str(decision.get("type", "")) == "redeem_all_and_pass_turn", "offline bot batches own-stock redemption into turn-ending intent")


func _regression_bot_swaps_surplus_before_redeem(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-surplus-before-redeem").is_empty(), "create bot surplus table")
	_require(store.handle_host_intent({"type": "start"}), "start bot surplus table: %s" % _last_error)
	var bot_id := "p2"
	store.table["currentTurnParticipantId"] = bot_id
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	_require(str(decision.get("type", "")) == "platter_swap", "offline bot swaps surplus duplicate card before redeem/pass")
	var give: Dictionary = store._voucher_by_id(str(decision.get("giveVoucherId", "")))
	var take: Dictionary = store._voucher_by_id(str(decision.get("takeVoucherId", "")))
	var give_location: Dictionary = give.get("location", {})
	var take_location: Dictionary = take.get("location", {})
	_require(str(give_location.get("type", "")) == "hand" and str(give_location.get("participantId", "")) == bot_id, "offline bot gives from its own hand")
	_require(str(take_location.get("type", "")) == "platter", "offline bot takes from the platter")
	_require(str(give.get("ingredientId", "")) != str(take.get("ingredientId", "")), "offline bot does not swap for the same ingredient")
	var recipe: Dictionary = store.table.get("recipes", {}).get(bot_id, {})
	var take_is_needed := false
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) == str(take.get("ingredientId", "")):
			take_is_needed = true
			break
	_require(take_is_needed, "offline bot takes a card needed by its recipe")


func _regression_bot_spends_food_piece_for_platter_card(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-food-piece-for-platter-card").is_empty(), "create bot food-piece platter table")
	_require(store.handle_host_intent({"type": "start"}), "start bot food-piece platter table: %s" % _last_error)
	var bot_id := _active_id_by_ingredient(store, "flour")
	var card_sink_id := _first_other_active_id(store, bot_id)
	var bot: Dictionary = store.table.get("participants", {}).get(bot_id, {})
	bot["kind"] = "bot"
	bot["botType"] = "mixed"
	store.table["currentTurnParticipantId"] = bot_id
	var recipe: Dictionary = store.table.get("recipes", {}).get(bot_id, {})
	recipe["requirements"] = [
		{"id": "flour-protected", "ingredientId": "flour", "requiredQty": 6, "redeemedQty": 0, "placedVoucherIds": []},
		{"id": "cheese-needed", "ingredientId": "cheese", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
	]
	store.table["dishParts"]["bot_food_piece"] = {
		"id": "bot_food_piece",
		"dishId": "bot_dish",
		"dishName": "Flatbread",
		"makerParticipantId": bot_id,
		"unitSingular": "slice",
		"unitPlural": "slices",
		"location": {"type": "inventory", "participantId": bot_id}
	}
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == bot_id:
			voucher["location"] = {"type": "hand", "participantId": card_sink_id}
	store.view_as(bot_id)
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	_require(str(decision.get("type", "")) == "platter_asset_swap", "offline bot spends food piece for useful platter card: %s" % JSON.stringify(decision))
	_require(str(decision.get("give", {}).get("kind", "")) == "dish_part", "offline bot gives a food piece: %s" % JSON.stringify(decision))
	_require(str(store._voucher_by_id(str(decision.get("take", {}).get("id", ""))).get("ingredientId", "")) == "cheese", "offline bot takes needed platter card: %s" % JSON.stringify(decision))


func _regression_bot_offer_prefers_smallest_missing_group(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-offer-smallest-missing").is_empty(), "create bot offer table")
	_require(store.handle_host_intent({"type": "start"}), "start bot offer table: %s" % _last_error)
	var bot_id := _active_id_by_ingredient(store, "flour")
	var card_sink_id := _first_other_active_id(store, bot_id)
	var bot: Dictionary = store.table.get("participants", {}).get(bot_id, {})
	bot["kind"] = "bot"
	bot["botType"] = "barter_only"
	store.table["currentTurnParticipantId"] = bot_id
	var recipe: Dictionary = store.table.get("recipes", {}).get(bot_id, {})
	recipe["name"] = "Herb Dumplings"
	recipe["requirements"] = [
		{"id": "flour-test", "ingredientId": "flour", "requiredQty": 2, "redeemedQty": 2, "placedVoucherIds": []},
		{"id": "herbs-test", "ingredientId": "herbs", "requiredQty": 2, "redeemedQty": 0, "placedVoucherIds": []},
		{"id": "vegetables-test", "ingredientId": "vegetables", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
		{"id": "eggs-test", "ingredientId": "eggs", "requiredQty": 1, "redeemedQty": 1, "placedVoucherIds": []}
	]
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == bot_id and str(voucher.get("ingredientId", "")) != str(bot.get("ingredientId", "")):
			voucher["location"] = {"type": "hand", "participantId": card_sink_id}
	store.view_as(bot_id)
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	var decision_context := "decision=%s phase=%s current=%s bot=%s" % [JSON.stringify(decision), str(store.table.get("phase", "")), str(store.table.get("currentTurnParticipantId", "")), bot_id]
	_require(str(decision.get("type", "")) == "create_offer", "offline bot creates offer for missing ingredient: %s" % decision_context)
	_require(str(decision.get("requestedAsset", {}).get("ingredientId", "")) == "vegetables", "offline bot requests singleton missing ingredient before duplicate group: %s" % JSON.stringify(decision))


func _regression_bot_offers_food_piece_for_missing_card(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-food-piece-offer").is_empty(), "create bot food-piece offer table")
	_require(store.handle_host_intent({"type": "start"}), "start bot food-piece offer table: %s" % _last_error)
	var bot_id := _active_id_by_ingredient(store, "flour")
	var vegetables_owner_id := _active_id_by_ingredient(store, "vegetables")
	var card_sink_id := _first_other_active_id(store, bot_id)
	var bot: Dictionary = store.table.get("participants", {}).get(bot_id, {})
	bot["kind"] = "bot"
	bot["botType"] = "barter_only"
	store.table["currentTurnParticipantId"] = bot_id
	var recipe: Dictionary = store.table.get("recipes", {}).get(bot_id, {})
	recipe["requirements"] = [
		{"id": "flour-protected", "ingredientId": "flour", "requiredQty": 6, "redeemedQty": 0, "placedVoucherIds": []},
		{"id": "vegetables-needed", "ingredientId": "vegetables", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
	]
	store.table["dishParts"]["bot_offer_piece"] = {
		"id": "bot_offer_piece",
		"dishId": "bot_dish",
		"dishName": "Flatbread",
		"makerParticipantId": bot_id,
		"unitSingular": "slice",
		"unitPlural": "slices",
		"location": {"type": "inventory", "participantId": bot_id}
	}
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == bot_id:
			voucher["location"] = {"type": "hand", "participantId": card_sink_id}
	store.view_as(bot_id)
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	var decision_context := "decision=%s phase=%s current=%s bot=%s" % [JSON.stringify(decision), str(store.table.get("phase", "")), str(store.table.get("currentTurnParticipantId", "")), bot_id]
	_require(str(decision.get("type", "")) == "create_offer", "offline bot creates food-piece offer: %s" % decision_context)
	var offered_assets: Array = decision.get("offeredAssets", [])
	_require(not offered_assets.is_empty() and str(offered_assets[0].get("kind", "")) == "dish_part", "offline bot offers a food piece: %s" % JSON.stringify(decision))
	_require(str(decision.get("requestedAsset", {}).get("ingredientId", "")) == "vegetables", "offline bot asks for missing card: %s" % JSON.stringify(decision))
	_require(str(decision.get("requestedAsset", {}).get("ownerParticipantId", "")) == vegetables_owner_id, "offline bot asks the ingredient owner: %s" % JSON.stringify(decision))


func _regression_goal_complete_bot_accepts_offer(store: Node) -> void:
	_setup_round_robin_table(store)
	var sender_id := "p1"
	var bot_id := "p2"
	var bot: Dictionary = store.table.get("participants", {}).get(bot_id, {})
	bot["kind"] = "bot"
	bot["botType"] = "mixed"
	bot["dishCount"] = int(store.table.get("targetDishCount", 1))
	store.table.get("recipes", {}).erase(bot_id)
	var offered := _first_hand_voucher(store, sender_id)
	_require(not offered.is_empty(), "sender has a card to offer")
	_require(
		store.handle_intent({
			"type": "create_offer",
			"toParticipantId": bot_id,
			"offeredVoucherIds": [offered.get("id", "")],
			"requested": {"ingredientId": _participant_ingredient_id(store, bot_id), "quantity": 1}
		}, sender_id, false),
		"create incoming offer for goal-complete bot: %s" % _last_error
		)
	store.table["currentTurnParticipantId"] = bot_id
	var decision: Dictionary = store._decide_bot_intent(bot_id)
	_require(str(decision.get("type", "")) == "respond_offer", "goal-complete bot still responds to incoming offers")
	_require(str(decision.get("response", "")) == "accept", "goal-complete bot accepts satisfiable offer")


func _regression_asset_offered_voucher_snapshot_details(store: Node) -> void:
	_setup_round_robin_table(store)
	var sender_id := "p1"
	var recipient_id := "p2"
	var offered := _first_hand_voucher(store, sender_id)
	_require(not offered.is_empty(), "asset-offered voucher regression has a card to offer")
	_require(
		store.handle_intent({
			"type": "create_offer",
			"toParticipantId": recipient_id,
			"offeredAssets": [{"kind": "voucher", "id": offered.get("id", "")}],
			"requestedAsset": {"kind": "voucher", "ingredientId": _participant_ingredient_id(store, recipient_id), "ownerParticipantId": recipient_id, "quantity": 1}
		}, sender_id, false),
		"create asset-offered voucher offer: %s" % _last_error
	)
	_require(store.view_as(recipient_id), "view recipient snapshot for asset-offered voucher")
	_require(store.latest_snapshot.get("offers", []).size() == 1, "recipient sees asset-offered voucher")
	var offer: Dictionary = store.latest_snapshot.get("offers", [])[0]
	_require(offer.get("offeredVouchers", []).size() == 1, "asset-offered voucher snapshot includes offered voucher details")
	var resolved: Dictionary = offer.get("offeredVouchers", [])[0]
	_require(str(resolved.get("ingredientId", "")) == str(offered.get("ingredientId", "")), "asset-offered voucher snapshot keeps ingredient id")


func _regression_return_owner_card_for_food_piece_offer(store: Node) -> void:
	_setup_round_robin_table(store)
	var sender_id := "p1"
	var owner_id := "p2"
	_complete_recipe(store, owner_id)
	_require(store.handle_intent({"type": "prepare"}, owner_id), "prepare owner dish for card-return offer: %s" % _last_error)
	var owner_card := _first_hand_voucher_by_owner(store, owner_id, owner_id)
	var owner_part: Dictionary = _inventory_dish_parts(store, owner_id)[0]
	_require(not owner_card.is_empty(), "owner has a card to return by offer")
	store.table["vouchers"][str(owner_card.get("id", ""))]["location"] = {"type": "hand", "participantId": sender_id}
	store.table["currentTurnParticipantId"] = sender_id
	_require(
		store.handle_intent({
			"type": "create_offer",
			"toParticipantId": owner_id,
			"offeredAssets": [{"kind": "voucher", "id": owner_card.get("id", "")}],
			"requestedAsset": {"kind": "dish_part", "quantity": 1}
		}, sender_id, false),
		"create card-return-for-food-piece offer: %s" % _last_error
	)
	var offer_id := _first_pending_offer_id(store)
	_require(offer_id != "", "card-return food-piece offer is pending")
	store.table["currentTurnParticipantId"] = owner_id
	_require(
		store.handle_intent({"type": "respond_offer", "offerId": offer_id, "response": "accept", "assets": [{"kind": "dish_part", "id": owner_part.get("id", "")}]}, owner_id, false),
		"accept card-return food-piece offer: %s" % _last_error
	)
	_require(str(_voucher(store, str(owner_card.get("id", ""))).get("location", {}).get("participantId", "")) == owner_id, "returned card moves back to owner")
	_require(str(store.table.get("dishParts", {}).get(str(owner_part.get("id", "")), {}).get("location", {}).get("participantId", "")) == sender_id, "food piece moves to offer sender")


func _regression_same_card_offer_rejected(store: Node) -> void:
	_setup_round_robin_table(store)
	var sender_id := "p1"
	var owner_id := "p2"
	var owner_card := _first_hand_voucher_by_owner(store, owner_id, owner_id)
	_require(not owner_card.is_empty(), "owner has a card for same-card rejection")
	store.table["vouchers"][str(owner_card.get("id", ""))]["location"] = {"type": "hand", "participantId": sender_id}
	store.table["currentTurnParticipantId"] = sender_id
	_require(
		not store.handle_intent({
			"type": "create_offer",
			"toParticipantId": owner_id,
			"offeredAssets": [{"kind": "voucher", "id": owner_card.get("id", "")}],
			"requestedAsset": {
				"kind": "voucher",
				"ingredientId": owner_card.get("ingredientId", ""),
				"ownerParticipantId": owner_id,
				"quantity": 1
			}
		}, sender_id, false),
		"same promise-card resource offer is rejected"
	)
	_require(str(_voucher(store, str(owner_card.get("id", ""))).get("location", {}).get("participantId", "")) == sender_id, "rejected same-card offer leaves card in sender hand")


func _regression_stock_depleted_cards_not_usable(store: Node) -> void:
	_setup_round_robin_table(store)
	var participant_id := "p1"
	var participant: Dictionary = store.table.get("participants", {}).get(participant_id, {})
	var ingredient_id := _participant_ingredient_id(store, participant_id)
	var own_voucher := _first_hand_voucher_by_owner(store, participant_id, participant_id)
	var take := _first_platter_voucher_not_ingredient(store, ingredient_id)
	var requirement := _requirement_for_ingredient(store, participant_id, ingredient_id)
	_require(not own_voucher.is_empty(), "depleted-card test has own card")
	_require(not take.is_empty(), "depleted-card test has platter card")
	_require(not requirement.is_empty(), "depleted-card test has matching requirement")
	participant["realIngredientStock"] = 0
	_require(
		not store.handle_intent({"type": "platter_swap", "giveVoucherId": own_voucher.get("id", ""), "takeVoucherId": take.get("id", "")}, participant_id),
		"stock-depleted card cannot be swapped"
	)
	_require(
		not store.handle_intent({"type": "place_voucher", "voucherId": own_voucher.get("id", ""), "requirementId": requirement.get("id", "")}, participant_id),
		"stock-depleted card cannot be placed on recipe"
	)
	_require(
		not store.handle_intent({
			"type": "create_offer",
			"toParticipantId": "p2",
			"offeredVoucherIds": [own_voucher.get("id", "")],
			"requested": {"ingredientId": _participant_ingredient_id(store, "p2"), "quantity": 1}
		}, participant_id),
		"stock-depleted card cannot be offered"
	)


func _setup_round_robin_table(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-regression").is_empty(), "create regression table")
	for _index in range(7):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add controlled seat: %s" % _last_error)
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 1}), "set one-dish goal")
	_require(store.handle_host_intent({"type": "start"}), "start regression table: %s" % _last_error)
	_require(str(store.latest_snapshot.get("phase", "")) == "playing", "table enters playing")


func _regression_round_robin_pass_turn_history(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-round-robin-pass").is_empty(), "create round robin table")
	for _index in range(7):
		_require(store.handle_host_intent({"type": "add_controlled_seat"}), "add controlled seat: %s" % _last_error)
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 1}), "set one-dish goal")
	_require(store.handle_host_intent({"type": "start"}), "start round robin table: %s" % _last_error)
	_require(str(store.table.get("phase", "")) == "playing", "round robin table enters playing")
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p1", "first turn starts with p1")
	_require(store.handle_intent({"type": "pass_turn"}, "p1", false), "pass turn succeeds: %s" % _last_error)
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p2", "pass turn advances to p2")
	var history: Array = store.table.get("transactionHistory", [])
	var last: Dictionary = history[history.size() - 1]
	_require(str(last.get("action", "")) == "Pass Turn", "pass turn is recorded")
	_require(str(last.get("name", "")) == "Amina", "pass turn records actor")
	_require(str(last.get("counterparty", "")) == "Ben", "pass turn records next participant")


func _regression_bot_budget_returns_to_human(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-bot-budget").is_empty(), "create bot budget table")
	_require(store.handle_host_intent({"type": "set_target_dish_count", "count": 3}), "set three-dish goal")
	_require(store.handle_intent({"type": "start"}, "p1", false), "start bot budget table: %s" % _last_error)
	store.table["currentTurnParticipantId"] = "p2"
	store._run_bots(0)
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p1", "bot budget fallback returns control to the human host")
	var history: Array = store.table.get("transactionHistory", [])
	var last: Dictionary = history[history.size() - 1]
	_require(str(last.get("action", "")) == "Pass Turn", "bot budget fallback records pass turn")
	_require(str(last.get("counterparty", "")) == "Amina", "bot budget fallback passes back to host")


func _regression_bot_run_is_deferred_after_pass(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-deferred-bots").is_empty(), "create deferred bot table")
	_require(store.handle_intent({"type": "start"}, "p1", false), "start deferred bot table: %s" % _last_error)
	var before_count: int = store.table.get("transactionHistory", []).size()
	_require(store.handle_intent({"type": "pass_turn"}, "p1"), "pass turn with deferred bots: %s" % _last_error)
	var immediate_count: int = store.table.get("transactionHistory", []).size()
	_require(immediate_count == before_count + 1, "bot turns are not applied synchronously before the pass animation can start")
	for _index in range(20):
		if int(store.table.get("transactionHistory", []).size()) > immediate_count:
			break
		await process_frame
	var later_count: int = store.table.get("transactionHistory", []).size()
	_require(later_count > immediate_count, "deferred bot turns continue after the pass snapshot is emitted")
	for _index in range(400):
		if str(store.table.get("currentTurnParticipantId", "")) == "p1":
			break
		await process_frame
	_require(str(store.table.get("currentTurnParticipantId", "")) == "p1", "deferred bot turns eventually return control to the human host")


func _regression_renamed_bot_acts_after_pass(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-renamed-bot-turn").is_empty(), "create renamed bot turn table")
	_require(store.handle_host_intent({"type": "rename_participant", "participantId": "p2", "name": "jjj_b_2"}), "rename p2 bot before turn test: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "jjj_b", "renamed bot starts test as jjj_b")
	_require(str(store.table.get("participants", {}).get("p2", {}).get("kind", "")) == "bot", "renamed bot remains a bot before start")
	_assert_named_bot_acts_after_pass(store, "direct renamed bot")

	_require(not store.create_table("Amina", "offline-toggled-renamed-bot-turn").is_empty(), "create toggled renamed bot turn table")
	_require(store.handle_host_intent({"type": "add_controlled_seat", "participantId": "p2", "name": "jjj_b"}), "take p2 before toggled bot test: %s" % _last_error)
	_require(store.handle_host_intent({"type": "convert_to_bot", "participantId": "p2", "botType": "mixed"}), "convert p2 back to bot before turn test: %s" % _last_error)
	_require(str(store.table.get("participants", {}).get("p2", {}).get("name", "")) == "jjj_b", "toggled bot starts test as jjj_b")
	_require(str(store.table.get("participants", {}).get("p2", {}).get("kind", "")) == "bot", "toggled renamed bot is a bot before start")
	_assert_named_bot_acts_after_pass(store, "toggled renamed bot")


func _assert_named_bot_acts_after_pass(store: Node, label: String) -> void:
	_require(store.handle_intent({"type": "start"}, "p1", false), "start renamed bot turn table: %s" % _last_error)
	_require(store.handle_intent({"type": "pass_turn"}, "p1"), "pass to renamed bot: %s" % _last_error)
	for _index in range(500):
		var saw_renamed_bot := false
		for raw_transaction in store.table.get("transactionHistory", []):
			var transaction: Dictionary = raw_transaction
			if str(transaction.get("name", "")) == "jjj_b":
				saw_renamed_bot = true
				break
		if saw_renamed_bot and str(store.table.get("currentTurnParticipantId", "")) == "p1":
			return
		await process_frame
	_require(false, "%s jjj_b should act and return turn control after Amina passes" % label)


func _regression_full_offline_transaction_export(store: Node) -> void:
	_require(not store.create_table("Amina", "offline-full-history").is_empty(), "create full history table")
	var history: Array = []
	for index in range(105):
		history.append({
			"id": "tx_%s" % (index + 1),
			"turn": index + 1,
			"participantId": "p1",
			"name": "Amina",
			"action": "Pass Turn",
			"counterpartyParticipantId": "p1",
			"counterparty": "Amina",
			"itemOut": "None",
			"itemBack": "None"
		})
	store.table["transactionHistory"] = history
	_require(store.view_as("p1"), "refresh full history snapshot")
	_require(int(store.latest_snapshot.get("transactionHistory", []).size()) == 100, "offline live snapshot keeps visible history bounded")
	_require(not bool(store.latest_snapshot.get("transactionHistoryComplete", true)), "offline live snapshot marks bounded history incomplete")
	_require(int(store.full_transaction_history().size()) == 105, "offline full export exposes complete local history")


func _assert_invalid_intent_rolls_back(store: Node) -> void:
	var before := JSON.stringify(store.table)
	_require(
		not store.handle_intent({"type": "platter_swap", "giveVoucherId": "missing", "takeVoucherId": "missing"}, "p1"),
		"invalid swap is rejected"
	)
	_require(JSON.stringify(store.table) == before, "invalid intent restores full offline table state")


func _assert_platter_swap(store: Node) -> void:
	var give := _first_hand_voucher(store, "p1")
	var take := _first_platter_voucher_not_ingredient(store, str(give.get("ingredientId", "")))
	_require(not give.is_empty(), "p1 has a card to swap")
	_require(not take.is_empty(), "platter has a different card to take")
	_require(
		store.handle_intent({"type": "platter_swap", "giveVoucherId": give.get("id", ""), "takeVoucherId": take.get("id", "")}, "p1"),
		"platter swap succeeds: %s" % _last_error
	)
	_require(str(_voucher(store, str(give.get("id", ""))).get("location", {}).get("type", "")) == "platter", "given card enters platter")
	_require(str(_voucher(store, str(take.get("id", ""))).get("location", {}).get("participantId", "")) == "p1", "taken card enters p1 hand")


func _assert_offer_exchange(store: Node) -> void:
	var recipient_id := "p2"
	var requested_ingredient := _participant_ingredient_id(store, recipient_id)
	var offered := _first_hand_voucher_not_ingredient(store, "p1", requested_ingredient)
	var requested := _first_hand_voucher_by_ingredient(store, recipient_id, requested_ingredient)
	_require(not offered.is_empty(), "p1 has a non-recipient card to offer")
	_require(not requested.is_empty(), "recipient has own card to exchange")
	_require(
		store.handle_intent({
			"type": "create_offer",
			"toParticipantId": recipient_id,
			"offeredVoucherIds": [offered.get("id", "")],
			"requested": {"ingredientId": requested_ingredient, "quantity": 1}
		}, "p1"),
		"create offer succeeds: %s" % _last_error
	)
	var offer_id := _first_pending_offer_id(store)
	_require(offer_id != "", "pending offer exists")
	_require(str(_voucher(store, str(offered.get("id", ""))).get("location", {}).get("type", "")) == "offer_lock", "offered card is locked")
	store.table["currentTurnParticipantId"] = recipient_id
	_require(
		store.handle_intent({"type": "respond_offer", "offerId": offer_id, "response": "accept", "voucherIds": [requested.get("id", "")]}, recipient_id),
		"accept offer succeeds: %s" % _last_error
	)
	_require(not store.table.get("offers", {}).has(offer_id), "accepted offer is removed")
	_require(str(_voucher(store, str(offered.get("id", ""))).get("location", {}).get("participantId", "")) == recipient_id, "offered card moves to recipient")
	_require(str(_voucher(store, str(requested.get("id", ""))).get("location", {}).get("participantId", "")) == "p1", "requested card moves to creator")


func _complete_recipe(store: Node, participant_id: String) -> void:
	var recipe: Dictionary = store.table.get("recipes", {}).get(participant_id, {})
	_require(not recipe.is_empty(), "participant has recipe")
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		while _outstanding_requirement_qty(requirement) > 0:
			var voucher: Dictionary = _ensure_hand_voucher_for_ingredient(store, participant_id, str(requirement.get("ingredientId", "")))
			_require(not voucher.is_empty(), "matching card available for requirement")
			store.table["currentTurnParticipantId"] = participant_id
			_require(
				store.handle_intent({"type": "redeem_from_hand", "voucherId": voucher.get("id", ""), "requirementId": requirement.get("id", "")}, participant_id),
				"redeem from hand succeeds: %s" % _last_error
			)
	_require(_recipe_ready(recipe), "recipe is ready after redemptions")


func _assert_settlement_and_eating(store: Node, maker_id: String, dish_id: String) -> void:
	for participant_id in _active_ids(store.latest_snapshot):
		store.table["participants"][participant_id]["dishCount"] = 1
		store.table["recipes"].erase(participant_id)
	_force_all_accounts_cleared(store)
	var extra_own: Dictionary = _first_hand_voucher_by_owner(store, maker_id, maker_id)
	_require(not extra_own.is_empty(), "maker has an extra own card for debt setup")
	store.table["vouchers"][str(extra_own.get("id", ""))]["location"] = {"type": "platter"}
	store._enter_settlement_phase()
	_require(str(store.table.get("phase", "")) == "settlement", "table enters settlement with maker debt")
	var part: Dictionary = _inventory_dish_parts(store, maker_id)[0]
	_require(
		store.handle_intent({"type": "platter_asset_swap", "give": {"kind": "dish_part", "id": part.get("id", "")}, "take": {"kind": "voucher", "id": extra_own.get("id", "")}}, maker_id),
		"settlement swap succeeds: %s" % _last_error
	)
	_require(int(_public_participant(store.latest_snapshot, maker_id).get("ownCardsInPlatter", 0)) == 2, "maker account is cleared")
	store.table["dishParts"][str(part.get("id", ""))]["location"] = {"type": "inventory", "participantId": maker_id}
	store._advance_settlement_if_ready()
	_require(str(store.table.get("phase", "")) == "complete", "cleared table auto-shares food")
	_require(_inventory_dish_parts(store, maker_id).is_empty(), "maker held pieces are shared automatically")
	_require(int(store.table["dishes"][dish_id].get("partsRemaining", 0)) == 0, "auto-share decrements dish parts once per held piece")


func _force_all_accounts_cleared(store: Node) -> void:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		voucher["location"] = {"type": "hand", "participantId": voucher.get("ownerParticipantId", "")}
	for participant_id in _active_ids(store.latest_snapshot):
		var moved := 0
		for raw_voucher_id in store.table.get("vouchers", {}).keys():
			if moved >= 2:
				break
			var voucher_id := str(raw_voucher_id)
			var voucher: Dictionary = store.table["vouchers"].get(voucher_id, {})
			if str(voucher.get("ownerParticipantId", "")) != participant_id:
				continue
			if str(voucher.get("location", {}).get("type", "")) != "hand":
				continue
			if str(voucher.get("location", {}).get("participantId", "")) != participant_id:
				continue
			store.table["vouchers"][voucher_id]["location"] = {"type": "platter"}
			moved += 1
		_require(moved == 2, "participant has two own cards for clearance")


func _ensure_hand_voucher_for_ingredient(store: Node, holder_id: String, ingredient_id: String) -> Dictionary:
	var in_hand := _first_hand_voucher_by_ingredient(store, holder_id, ingredient_id)
	if not in_hand.is_empty():
		return in_hand
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) != ingredient_id:
			continue
		if str(voucher.get("location", {}).get("type", "")) == "offer_lock":
			continue
		voucher["location"] = {"type": "hand", "participantId": holder_id}
		return voucher
	return {}


func _outstanding_requirement_qty(requirement: Dictionary) -> int:
	return int(requirement.get("requiredQty", 0)) - int(requirement.get("redeemedQty", 0)) - requirement.get("placedVoucherIds", []).size()


func _recipe_ready(recipe: Dictionary) -> bool:
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if int(requirement.get("redeemedQty", 0)) < int(requirement.get("requiredQty", 0)):
			return false
	return true


func _active_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for participant in snapshot.get("participants", []):
		if str(participant.get("role", "")) == "active":
			ids.append(str(participant.get("id", "")))
	return ids


func _participant_ingredient_id(store: Node, participant_id: String) -> String:
	return str(store.table.get("participants", {}).get(participant_id, {}).get("ingredientId", ""))


func _active_id_by_ingredient(store: Node, ingredient_id: String) -> String:
	for participant_id in _active_ids(store.latest_snapshot):
		if _participant_ingredient_id(store, str(participant_id)) == ingredient_id:
			return str(participant_id)
	_require(false, "expected active participant for %s" % ingredient_id)
	return ""


func _first_other_active_id(store: Node, participant_id: String) -> String:
	for candidate_id in _active_ids(store.latest_snapshot):
		if str(candidate_id) != participant_id:
			return str(candidate_id)
	_require(false, "expected another active participant")
	return ""


func _requirement_for_ingredient(store: Node, participant_id: String, ingredient_id: String) -> Dictionary:
	var recipe: Dictionary = store.table.get("recipes", {}).get(participant_id, {})
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) == ingredient_id:
			return requirement
	return {}


func _public_participant(snapshot: Dictionary, participant_id: String) -> Dictionary:
	for raw_participant in snapshot.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("id", "")) == participant_id:
			return participant
	return {}


func _first_dish_id(store: Node, owner_id: String) -> String:
	for raw_dish in store.table.get("dishes", {}).values():
		var dish: Dictionary = raw_dish
		if str(dish.get("ownerParticipantId", "")) == owner_id:
			return str(dish.get("id", ""))
	return ""


func _inventory_dish_parts(store: Node, participant_id: String) -> Array:
	var parts: Array = []
	for raw_part in store.table.get("dishParts", {}).values():
		var part: Dictionary = raw_part
		var location: Dictionary = part.get("location", {})
		if str(location.get("type", "")) == "inventory" and str(location.get("participantId", "")) == participant_id:
			parts.append(part)
	return parts


func _first_pending_offer_id(store: Node) -> String:
	for offer_id in store.table.get("offers", {}).keys():
		var offer: Dictionary = store.table["offers"][offer_id]
		if str(offer.get("status", "")) == "pending":
			return str(offer_id)
	return ""


func _first_hand_voucher(store: Node, participant_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id:
			return voucher
	return {}


func _first_hand_voucher_not_ingredient(store: Node, participant_id: String, ingredient_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id and str(voucher.get("ingredientId", "")) != ingredient_id:
			return voucher
	return {}


func _first_hand_voucher_by_ingredient(store: Node, participant_id: String, ingredient_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id and str(voucher.get("ingredientId", "")) == ingredient_id:
			return voucher
	return {}


func _hand_voucher_count_by_ingredient(store: Node, participant_id: String, ingredient_id: String) -> int:
	var count := 0
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id and str(voucher.get("ingredientId", "")) == ingredient_id:
			count += 1
	return count


func _first_hand_voucher_by_owner(store: Node, participant_id: String, owner_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		var location: Dictionary = voucher.get("location", {})
		if str(location.get("type", "")) == "hand" and str(location.get("participantId", "")) == participant_id and str(voucher.get("ownerParticipantId", "")) == owner_id:
			return voucher
	return {}


func _first_platter_voucher_not_ingredient(store: Node, ingredient_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("location", {}).get("type", "")) == "platter" and str(voucher.get("ingredientId", "")) != ingredient_id:
			return voucher
	return {}


func _first_platter_voucher_by_owner(store: Node, owner_id: String) -> Dictionary:
	for raw_voucher in store.table.get("vouchers", {}).values():
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("location", {}).get("type", "")) == "platter" and str(voucher.get("ownerParticipantId", "")) == owner_id:
			return voucher
	return {}


func _voucher(store: Node, voucher_id: String) -> Dictionary:
	return store.table.get("vouchers", {}).get(voucher_id, {})


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
