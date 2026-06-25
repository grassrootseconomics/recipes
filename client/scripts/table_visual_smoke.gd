extends SceneTree

const TableVisual := preload("res://scripts/table_visual.gd")
const VisualAssets := preload("res://scripts/visual_asset_registry.gd")

var _intents: Array = []
var _views: Array = []
var _statuses: Array = []
var _menu_actions: Array = []
var _failed := false


func _initialize() -> void:
	var visual = TableVisual.new()
	root.add_child(visual)
	await process_frame
	visual.intent_requested.connect(func(intent: Dictionary) -> void:
		_intents.append(intent)
	)
	visual.view_requested.connect(func(participant_id: String) -> void:
		_views.append(participant_id)
	)
	visual.status_requested.connect(func(message: String) -> void:
		_statuses.append(message)
	)
	visual.menu_requested.connect(func(action: String) -> void:
		_menu_actions.append(action)
	)

	var snapshot := _snapshot_fixture()
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	visual.debug_play_animation_event({"type": "deposit", "ingredientId": "rice", "participantId": "p2"})
	await process_frame
	_require(visual.debug_stats.get("lastAnimatedCardSize", Vector2.ZERO) == Vector2(118, 82), "animated promise cards use the same size as basket cards")
	visual.debug_flush_animations()
	await process_frame
	_require(_popup_panels_have_expected_dismissal(visual), "visual table popups use expected dismissal behavior")
	_require(visual.get_combined_minimum_size().x <= 720.0, "visual table minimum width fits a 720px portrait window with app margins")
	visual.debug_apply_snapshot(_eight_seat_snapshot())
	visual.size = Vector2(720, 1100)
	await process_frame
	_require(int(visual.debug_stats.get("participantCount", 0)) == 8, "renders all 8 cooks in the Cooks grid")
	var cook_ring := visual.find_child("CookRing", true, false) as Control
	_require(cook_ring != null and cook_ring.get_child_count() == 8, "renders the 8 cooks around the basket")
	if cook_ring != null and cook_ring.get_child_count() == 8:
		var p5 := visual.find_child("Participant_p5", true, false) as Control
		var p8 := visual.find_child("Participant_p8", true, false) as Control
		_require(p5 != null and p8 != null and p5.position.x > p8.position.x, "lower cooks are positioned clockwise around the basket")
	_require(visual.find_child("Participant_p1", true, false) != null, "keeps the viewing cook visible in the 8-cook grid")
	_require(bool(visual.debug_stats.get("viewerCookVisible", false)), "shows the viewing cook in the 8-cook grid")
	_assert_key_visuals_fit_assigned_width(visual, 720.0)
	var fixed_basket := visual.find_child("BasketBackdrop", true, false) as Control
	_require(fixed_basket != null and fixed_basket.size.x <= 680.0, "basket backdrop does not expand wider than the portrait design lane")
	var fixed_cook := visual.find_child("Participant_p5", true, false) as Control
	_require(fixed_cook != null and fixed_cook.size.x <= 152.0, "cook tiles do not stretch horizontally inside wide rows")
	var promise_title := visual.find_child("Title_Promise_Cards", true, false) as Label
	_require(promise_title != null and promise_title.size.x >= 150.0, "Promise Cards title has enough width and does not wrap vertically")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	var hand_card := visual.find_child("HandCard_rice", true, false) as Button
	_require(hand_card != null and hand_card.custom_minimum_size == Vector2(96, 90), "Promise card keeps its fixed tile size")
	_require(hand_card != null and hand_card.find_child("CardInsetOutline", true, false) != null, "Promise card draws an inset outline so borders are not clipped")
	_require(visual.find_child("Title_Cooks", true, false) == null, "visual table removes the separate Cooks title")
	_require(_has_label_containing(visual, "Amina's Actions"), "Actions panel title includes the viewing cook name")
	var table_menu_button := visual.find_child("TableMenuButton", true, false) as Button
	_require(table_menu_button != null and table_menu_button.visible, "renders a table menu button")
	_require(table_menu_button != null and table_menu_button.size.x <= 48.0 and table_menu_button.size.y <= 40.0, "table menu button stays compact")
	var overlay_layer := visual.find_child("TableOverlayLayer", true, false) as Control
	_require(overlay_layer != null and overlay_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "table overlay does not intercept gameplay clicks")
	var animation_layer := visual.find_child("AnimationLayer", true, false) as Control
	_require(animation_layer != null and animation_layer.get_parent() == overlay_layer, "animation layer shares the table canvas instead of using a detached CanvasLayer")
	visual.debug_open_table_menu()
	await process_frame
	_require(visual.debug_table_menu_visible(), "table menu opens")
	visual.debug_open_table_menu()
	await process_frame
	_require(not visual.debug_table_menu_visible(), "table menu closes when the hamburger is clicked again")
	visual.debug_open_table_menu()
	await process_frame
	_require(visual.debug_table_menu_visible(), "table menu reopens after toggling closed")
	visual.debug_close_table_menu_at(visual.get_global_rect().position + Vector2(600, 1000))
	await process_frame
	_require(not visual.debug_table_menu_visible(), "table menu closes when clicking away")
	var menu_actions: Array = visual.debug_stats.get("menuActions", [])
	_require(menu_actions.has("View History"), "table menu exposes transaction history")
	_require(menu_actions.has("Fast Bots"), "table menu exposes Fast Bots toggle by default")
	_require(menu_actions.has("End Game"), "host table menu exposes End Game")
	_require(menu_actions.has("Main Menu"), "table menu exposes Main Menu")
	var main_menu_overlay := visual.find_child("TableMainMenuButton", true, false) as Button
	_require(main_menu_overlay != null and not main_menu_overlay.visible, "visual table hides top Main Menu button before the game is over")
	_require(visual.debug_fast_bots_enabled(), "Fast Bots mode is enabled by default")
	_require(absf(float(visual.debug_animation_speed_scale_for_type("swap")) - 1.35) <= 0.001, "viewer swap animations stay slower and smoother in Fast Bots mode")
	_require(absf(float(visual.debug_animation_speed_scale_for_type("redeem")) - 1.35) <= 0.001, "viewer redemption animations stay slower and smoother in Fast Bots mode")
	_require(absf(float(visual.debug_animation_speed_scale_for_event({"type": "exchange", "fromParticipantId": "p2", "toParticipantId": "p4"})) - 1.0) <= 0.001, "non-viewer human exchanges stay slow in Fast Bots mode")
	var bot_speed_snapshot := snapshot.duplicate(true)
	bot_speed_snapshot["participants"][1]["kind"] = "bot"
	bot_speed_snapshot["participants"][2]["kind"] = "bot"
	visual.debug_apply_snapshot(bot_speed_snapshot)
	await process_frame
	_require(absf(float(visual.debug_animation_speed_scale_for_event({"type": "exchange", "fromParticipantId": "p2", "toParticipantId": "p3"})) - 0.25) <= 0.001, "bot-only exchanges run four times faster in Fast Bots mode")
	_require(absf(float(visual.debug_animation_speed_scale_for_event({"type": "public_redeem", "participantId": "p2", "ownerParticipantId": "p3", "ingredientId": "cheese"})) - 0.25) <= 0.001, "bot-only redemptions run four times faster in Fast Bots mode")
	_require(absf(float(visual.debug_animation_speed_scale_for_event({"type": "public_redeem", "participantId": "p2", "ownerParticipantId": "p1", "ingredientId": "rice"})) - 1.35) <= 0.001, "redemptions involving the viewer stay slower and smoother in Fast Bots mode")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	var controlled_view := _controlled_nia_view_snapshot()
	visual.render(controlled_view)
	await process_frame
	_require(str(visual.debug_stats.get("inventoryTitle", "")) == "Nia Inv.", "view switch renders the controlled seat inventory")
	_require(int(visual.debug_stats.get("animationEventCount", -1)) == 0, "view switch does not create fake gameplay animations")
	_require(not visual.debug_stats.get("lastAnimationTypes", []).has("redeem"), "view switch does not look like repeated redemption")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	visual.debug_toggle_bot_animation_speed()
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	menu_actions = visual.debug_stats.get("menuActions", [])
	_require(not visual.debug_fast_bots_enabled(), "bot speed toggle switches to Slow Bots")
	_require(menu_actions.has("Slow Bots"), "table menu label updates after switching to Slow Bots")
	_require(absf(float(visual.debug_animation_speed_scale_for_type("swap")) - 1.35) <= 0.001, "Slow Bots keeps viewer animations slower and smoother")
	visual.debug_toggle_bot_animation_speed()
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	_require(visual.find_child("Title_Cooks", true, false) == null, "keeps the separate Cooks title removed after rerender")
	_require(visual.find_child("BasketBackdrop", true, false) != null, "renders a basket backdrop behind platter cards")
	_require(visual.find_child("BasketSlot_rice", true, false) != null, "keeps a stable basket slot for an ingredient before it appears")
	_require(visual.find_child("BasketSlot_cheese", true, false) != null, "keeps all ingredient basket slots available for animation anchors")
	var basket_order: Array = visual.debug_stats.get("basketVisualOrder", [])
	_require(basket_order == ["eggs", "cheese", "vegetables", "spices", "flour", "rice", "beans", "herbs"], "basket slots use the center-first deposit order")
	_require(int(visual.debug_stats.get("participantCount", 0)) == 4, "renders all cooks in the top player list")
	var viewer_tile := visual.find_child("Participant_p1", true, false) as Control
	_require(viewer_tile != null, "renders the viewer cook tile for a stable 4x2 grid")
	_require(bool(visual.debug_stats.get("viewerCookVisible", false)), "keeps the viewer cook tile visible instead of removing it")
	var participant_tile := visual.find_child("Participant_p2", true, false)
	_require(participant_tile != null, "renders non-viewer cook tile")
	var cook_name := participant_tile.find_child("CookNameLabel", true, false) as Label
	var cook_ingredient := participant_tile.find_child("CookIngredientLabel", true, false) as Label
	var cook_icon := participant_tile.find_child("CookIngredientIcon", true, false) as TextureRect
	var cook_avatar := participant_tile.find_child("CookAvatar", true, false) as TextureRect
	_require(cook_name != null and cook_name.text == "Ben", "cook tile keeps participant name text separate from progress glyphs")
	_require(_progress_node_matches(participant_tile.find_child("CookProgressStars", true, false), 0, 3), "cook tile shows empty dish progress stars")
	_require(cook_ingredient != null and cook_ingredient.text.find("Beans x28") >= 0, "cook tile shows ingredient stock label")
	_require(cook_icon != null and cook_avatar != null and cook_avatar.position.x > cook_icon.position.x, "cook tile places avatar slightly to the right of the ingredient")
	_require(cook_icon != null and cook_avatar != null and cook_avatar.position.x >= cook_icon.position.x + cook_icon.size.x - 2.0, "cook tile keeps avatar side-by-side instead of on top of the ingredient")
	_require(cook_icon != null and cook_icon.position.y - cook_name.position.y <= 24.0, "cook tile keeps name close to ingredient and avatar")
	var cook_progress := snapshot.duplicate(true)
	cook_progress["participants"][1]["dishCount"] = 1
	cook_progress["participants"][2]["dishCount"] = 2
	cook_progress["participants"][3]["dishCount"] = 3
	visual.debug_apply_snapshot(cook_progress)
	await process_frame
	var one_star_tile := visual.find_child("Participant_p2", true, false) as Control
	var two_star_tile := visual.find_child("Participant_p3", true, false) as Control
	var three_star_tile := visual.find_child("Participant_p4", true, false) as Control
	_require(_progress_node_matches(one_star_tile.find_child("CookProgressStars", true, false), 1, 3), "cook tile shows one filled star after one dish")
	_require(_progress_node_matches(two_star_tile.find_child("CookProgressStars", true, false), 2, 3), "cook tile shows two filled stars after two dishes")
	_require(_progress_node_matches(three_star_tile.find_child("CookProgressStars", true, false), 3, 3), "cook tile shows three filled stars after completion")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	participant_tile = visual.find_child("Participant_p2", true, false)
	_require(participant_tile.find_child("OfferBadgeIncoming", true, false) != null, "incoming offers render a visible pulsing badge")
	var outgoing_tile := visual.find_child("Participant_p3", true, false)
	_require(outgoing_tile != null and outgoing_tile.find_child("OfferBadgeOutgoing", true, false) != null, "outgoing offers render a visible pulsing badge")
	var viewer_tile_for_turn := visual.find_child("Participant_p1", true, false)
	_require(viewer_tile_for_turn != null and viewer_tile_for_turn.find_child("TurnCircle", true, false) != null, "viewer turn highlights the viewer's cook tile")
	var inventory_panel := visual.find_child("InventoryPanel", true, false) as Control
	_require(inventory_panel != null and not inventory_panel.visible, "viewer inventory block is hidden because the viewer appears in Cooks")
	_require(int(visual.debug_stats.get("handGroupCount", 0)) == 2, "renders grouped hand cards")
	var two_row_hand := snapshot.duplicate(true)
	two_row_hand["ownHand"].append_array([
		{"id": "beans_extra", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "vegetables_extra", "ingredientId": "vegetables", "ownerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "flour_extra", "ingredientId": "flour", "ownerParticipantId": "p5", "location": {"type": "hand", "participantId": "p1"}}
	])
	visual.debug_apply_snapshot(two_row_hand)
	await process_frame
	_require(int(visual.debug_stats.get("handGroupCount", 0)) == 5 and int(visual.debug_stats.get("handGridColumns", 0)) == 6, "Promise Cards tray uses a fixed six-column grid")
	var hand_scroll := visual.find_child("HandScroll", true, false) as ScrollContainer
	_require(hand_scroll != null and hand_scroll.custom_minimum_size.y >= 202.0, "Promise Cards tray reserves enough height for two rows with labels")
	_require(hand_scroll != null and hand_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Promise Cards tray does not require horizontal scrolling for 12 items")
	var mixed_hand := snapshot.duplicate(true)
	mixed_hand["ownFoodParts"] = [
		{"id": "dish_a_part_1", "dishId": "dish_a", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "dish_b_part_1", "dishId": "dish_b", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}}
	]
	visual.debug_apply_snapshot(mixed_hand)
	await process_frame
	var second_row_piece := visual.find_child("HandFood_dish_b", true, false) as Control
	_require(second_row_piece != null and second_row_piece.size.y >= 92.0, "second-row finished dish pieces keep enough height for their text labels")
	_require(second_row_piece != null and second_row_piece.tooltip_text == "Ben's Bean Dip - 1 scoop", "held finished dish piece tooltip shows maker, full recipe name, unit, and quantity")
	visual.debug_press_own_food_part("Bean Dip")
	await process_frame
	var food_popup := visual.find_child("OfferPopup", true, false) as PopupPanel
	_require(food_popup != null and not food_popup.visible, "single-tapping a held finished dish piece selects it without opening its info popup")
	visual.debug_open_own_food_part_info("Bean Dip")
	await process_frame
	_require(food_popup != null and food_popup.visible, "double-tapping a held finished dish piece opens its food-piece info popup")
	_require(_has_text_containing(visual, "Ben's Bean Dip - 1 scoop"), "food-piece info popup shows maker, full recipe name, unit, and quantity")
	visual.debug_apply_snapshot(mixed_hand)
	await process_frame
	_require(food_popup != null and food_popup.visible, "food-piece info popup stays open across table refreshes")
	food_popup.hide()
	_require(visual.preferred_visual_size() == Vector2(700, 960), "visual table reports a stable preferred size")
	var full_tray := snapshot.duplicate(true)
	full_tray["ownHand"] = [
		{"id": "rice_1", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "beans_1", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_1", "ingredientId": "cheese", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "flour_1", "ingredientId": "flour", "ownerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "herbs_1", "ingredientId": "herbs", "ownerParticipantId": "p5", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "eggs_1", "ingredientId": "eggs", "ownerParticipantId": "p6", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "spices_1", "ingredientId": "spices", "ownerParticipantId": "p7", "location": {"type": "hand", "participantId": "p1"}}
	]
	full_tray["ownFoodParts"] = [
		{"id": "dish_a_part_1", "dishId": "dish_a", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "dish_b_part_1", "dishId": "dish_b", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "dish_c_part_1", "dishId": "dish_c", "dishName": "Cheesy Rice Bake", "unitSingular": "piece", "unitPlural": "pieces", "makerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "dish_d_part_1", "dishId": "dish_d", "dishName": "Vegetable Chili", "unitSingular": "cup", "unitPlural": "cups", "makerParticipantId": "p3", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "dish_e_part_1", "dishId": "dish_e", "dishName": "Herb Rice Bowl", "unitSingular": "bowl", "unitPlural": "bowls", "makerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}}
	]
	visual.debug_apply_snapshot(full_tray)
	await process_frame
	_require(int(visual.debug_stats.get("handGroupCount", 0)) == 7, "Promise Cards tray supports seven ingredient groups")
	_require(int(visual.debug_stats.get("handGridColumns", 0)) == 6, "Promise Cards tray keeps 12 items in two rows of six")
	var hand_row := visual.find_child("HandRow", true, false) as GridContainer
	_require(hand_row != null and hand_row.get_child_count() == 12, "Promise Cards tray can show 7 ingredient groups and 5 dish pieces")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	_require(int(visual.debug_stats.get("recipeSlotCount", 0)) == 6, "renders six recipe slots with duplicate ingredients")
	_require(visual.find_child("RecipeCheck_rice_0", true, false) != null, "redeemed recipe slot shows a green checkmark")
	_require(visual.find_child("RecipeCheck_rice_1", true, false) == null, "unredeemed duplicate recipe slot does not show a checkmark")
	_require(str(visual.debug_stats.get("recipeName", "")) == "Rice Bean Bowl", "renders the recipe name")
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Amina's Recipe 0/3: Rice Bean Bowl", "active first recipe starts with empty drawn progress stars and viewer name")
	_require(_progress_node_matches(visual.find_child("RecipeTitleStars", true, false), 0, 3), "active first recipe title renders empty progress stars")
	var recipe_title := visual.find_child("RecipeTitleLabel", true, false) as Label
	var recipe_title_row := visual.find_child("RecipeTitleRow", true, false) as HBoxContainer
	_require(recipe_title != null and recipe_title_row != null and recipe_title_row.alignment == BoxContainer.ALIGNMENT_CENTER, "recipe title is centered above the recipe grid")
	var second_recipe := snapshot.duplicate(true)
	second_recipe["participants"][0]["dishCount"] = 1
	second_recipe["ownRecipe"]["name"] = "Cheese Frittata"
	visual.debug_apply_snapshot(second_recipe)
	await process_frame
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Amina's Recipe 1/3: Cheese Frittata", "updates recipe progress after one dish is completed")
	_require(_progress_node_matches(visual.find_child("RecipeTitleStars", true, false), 1, 3), "active second recipe title renders one filled star")
	var third_recipe := snapshot.duplicate(true)
	third_recipe["participants"][0]["dishCount"] = 2
	third_recipe["ownRecipe"]["name"] = "Masala Omelet"
	visual.debug_apply_snapshot(third_recipe)
	await process_frame
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Amina's Recipe 2/3: Masala Omelet", "active third recipe shows two completed dishes")
	_require(_progress_node_matches(visual.find_child("RecipeTitleStars", true, false), 2, 3), "active third recipe title renders two filled stars")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	_require(int(visual.debug_stats.get("platterGroupCount", 0)) == 3, "renders platter card and food-part groups")
	_require(int(visual.debug_stats.get("basketRenderedSlotCount", 0)) == 8, "platter food parts use the fixed two-row basket slots before compact mode")
	_require(not bool(visual.debug_stats.get("basketCompact", true)), "single platter food part does not force compact or expanded basket layout")
	var basket_grid := visual.find_child("BasketGrid", true, false) as GridContainer
	_require(basket_grid != null and basket_grid.get_child_count() == 8, "food pieces in the basket do not add a third layout row")
	_require(visual.find_child("PlatterFood_dish_1", true, false) != null, "platter food piece remains visible inside a fixed basket slot")
	var platter_food := visual.find_child("PlatterFood_dish_1", true, false) as Control
	_require(platter_food != null and platter_food.tooltip_text == "Diego's Vegetable Chili - 2 cups", "basket finished dish piece tooltip shows maker, full recipe name, unit, and quantity")
	if food_popup != null:
		food_popup.hide()
	visual.debug_press_platter_food_part("Vegetable Chili")
	await process_frame
	_require(food_popup != null and not food_popup.visible, "single-tapping a basket finished dish piece does not open its info popup")
	visual.debug_open_platter_food_part_info("Vegetable Chili")
	await process_frame
	_require(food_popup != null and food_popup.visible, "double-tapping a basket finished dish piece opens its food-piece info popup")
	food_popup.hide()
	_require(int(visual.debug_stats.get("incomingOfferCount", 0)) == 1, "counts incoming offer indicators")
	_require(int(visual.debug_stats.get("outgoingOfferCount", 0)) == 1, "counts outgoing offer indicators")
	var initial_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(not initial_actions.has("Clear"), "Actions panel does not show a Clear button")
	_require(not initial_actions.has("Prepare Dish"), "incomplete recipe does not show Prepare Dish action")
	var finished_waiting := snapshot.duplicate(true)
	finished_waiting["ownRecipe"] = {}
	finished_waiting["participants"][0]["dishCount"] = int(finished_waiting.get("targetDishCount", 3))
	finished_waiting["currentTurnParticipantId"] = "p2"
	visual.debug_apply_snapshot(finished_waiting)
	await process_frame
	_require(_has_label_containing(visual, "Help the other cooks make their dishes."), "finished cook Actions panel tells the player to help others")
	_require(not _has_label_containing(visual, "settle their debts"), "finished cook Actions panel does not show settlement text before everyone is done")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	visual.debug_flush_animations()
	await process_frame
	_intents.clear()
	visual.debug_press_hand_ingredient("rice")
	await process_frame
	var selected_swap_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	for action in selected_swap_actions:
		_require(not str(action).begins_with("Swap"), "Actions panel does not show a Swap button after selecting a card")
	visual.debug_press_platter_ingredient("beans")
	await process_frame
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "platter_swap", "basket click immediately emits a platter swap")
	_require(str(_intents[0].get("giveVoucherId", "")) == "rice_1" and str(_intents[0].get("takeVoucherId", "")) == "beans_1", "immediate swap uses selected hand card and clicked basket card")
	_intents.clear()
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	visual.debug_apply_snapshot(_prepare_before())
	await process_frame
	var ready_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(not ready_actions.has("Prepare Dish"), "complete recipe does not show manual Prepare Dish action")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	_require(VisualAssets.dish_meta("Vegetable Chili", "cup").has("texture"), "loads recipe-specific dish piece art")
	_require(VisualAssets.short_dish_name("Cheese Frittata") == "Frittata", "shortens finished dish part names")
	var other_turn := _snapshot_fixture()
	other_turn["currentTurnParticipantId"] = "p2"
	visual.debug_apply_snapshot(other_turn)
	await process_frame
	var turn_tile := visual.find_child("Participant_p2", true, false)
	_require(turn_tile != null and turn_tile.find_child("TurnCircle", true, false) != null, "non-viewer turn highlights that cook tile")
	var turn_cook_name := turn_tile.find_child("CookNameLabel", true, false) as Label
	_require(turn_cook_name != null and int(turn_cook_name.get_theme_constant("outline_size")) >= 2, "non-viewer turn glows that cook name")
	var off_turn_viewer := visual.find_child("Participant_p1", true, false)
	_require(off_turn_viewer != null and off_turn_viewer.find_child("TurnCircle", true, false) == null, "off-turn viewer cook tile has no turn circle")
	_require(_has_label_containing(visual, "Wait while other cooks take their turns."), "off-turn round-robin Actions panel tells the viewer to wait")
	visual.debug_apply_snapshot(snapshot)
	await process_frame
	await _assert_start_snapshot_animates_offerings_from_empty_basket(visual)
	await _assert_eight_start_snapshot_animates_offerings_from_cooks_to_fixed_basket(visual)
	_assert_turn_update_waits_for_animation(visual)
	_assert_turn_handoff_does_not_preempt_animation_actor(visual)
	_assert_batch_redeem_updates_counts_one_by_one(visual)
	_assert_redeem_pass_auto_prepare_waits_for_redeem_animations(visual)
	_assert_in_place_delta_redeem_pass_waits_for_animation(visual)
	_assert_redeem_pass_and_public_turns_apply_in_order(visual)
	_assert_deposits_update_basket_one_by_one(visual)
	_assert_animation_event(visual, _deposit_before(), _deposit_after(), "deposit", "deposit confirmation queues animation")
	_assert_animation_event(visual, _snapshot_fixture(), _swap_after(), "swap", "swap confirmation queues animation")
	_assert_animation_event(visual, _snapshot_fixture(), _public_swap_after(), "swap", "off-turn public swap queues animation")
	_assert_swap_paths_are_specific(visual)
	await _assert_public_settlement_food_part_uses_future_basket_slot(visual)
	_assert_swap_updates_basket_before_returning_card(visual)
	_assert_swap_return_targets_existing_hand_group_after_layout_shift(visual)
	_assert_public_swap_return_uses_recorded_actor_after_staged_layout(visual)
	_assert_animation_handoffs_before_fade_out(visual)
	_assert_public_swap_transactions_animate_separately(visual)
	_assert_pending_public_swaps_render_in_sequence(visual)
	_assert_unknown_actor_basket_delta_does_not_animate_from_wrong_cook(visual)
	await _assert_public_action_temporarily_highlights_actor(visual)
	_assert_animation_event(visual, _snapshot_fixture(), _exchange_after(), "exchange", "accepted exchange queues bidirectional animation")
	_assert_exchange_paths_are_specific(visual)
	_assert_animation_event(visual, _snapshot_fixture(), _redeem_after(), "redeem", "redeem confirmation queues animation")
	_assert_animation_count(visual, _snapshot_fixture(), _redeem_all_after(), "redeem", 2, "batch redeem queues one animation per redeemed card")
	await _assert_redeem_animation_has_no_dialog_artifacts(visual)
	_assert_animation_event(visual, _snapshot_fixture(), _public_redeem_after(), "public_redeem", "off-turn public redeem queues animation")
	_assert_public_redeem_paths_card_to_owner_and_ingredient_back(visual)
	_assert_animation_event(visual, _prepare_before(), _prepare_after(), "prepare", "prepare confirmation queues animation")
	_assert_animation_event(visual, _offer_before(), _snapshot_fixture(), "offer", "offer badge change queues animation")
	_assert_animation_event(visual, _settlement_before(), _settlement_after(), "settlement_swap", "settlement swap queues animation")
	_assert_animation_event(visual, _eating_before(), _eating_after(), "eat", "bite confirmation queues animation")
	_assert_animation_count(visual, _eating_many_before(), _eating_many_after(), "eat", 3, "bite-all queues one animation per held dish piece")
	await _assert_eat_animation_starts_at_held_food_part(visual)
	await _assert_eat_animation_reanchors_after_food_group_reflow(visual)
	_assert_animation_event(visual, _complete_before(), _complete_after(), "complete", "complete confirmation queues animation")
	visual.render(snapshot)
	visual.debug_play_animation_event({"type": "deposit", "ingredientId": "rice", "participantId": "p1"})
	visual.debug_play_animation_event({"type": "swap", "giveKind": "voucher", "giveIngredientId": "rice", "takeKind": "voucher", "takeIngredientId": "beans"})
	visual.debug_play_animation_event({"type": "exchange", "fromParticipantId": "p2", "toParticipantId": "p1", "offeredIngredientIds": ["beans"], "requestedIngredientIds": ["rice"]})
	visual.debug_play_animation_event({"type": "redeem", "ingredientId": "rice", "slotIndex": 0})
	visual.debug_play_animation_event({"type": "public_redeem", "participantId": "p2", "ownerParticipantId": "p1", "ingredientId": "rice"})
	visual.debug_play_animation_event({"type": "prepare", "dishName": "Cheese Frittata", "unit": "slice"})
	visual.debug_play_animation_event({"type": "offer", "participantId": "p2", "indicator": "!"})
	visual.debug_play_animation_event({"type": "settlement_swap", "giveKind": "dish_part", "giveDishName": "Bean Dip", "giveUnit": "scoop", "takeKind": "voucher", "takeIngredientId": "beans"})
	visual.debug_play_animation_event({"type": "eat", "dishName": "Cheese Frittata", "unit": "slice"})
	visual.debug_play_animation_event({"type": "complete"})

	_intents.clear()
	visual.debug_press_hand_ingredient("cheese")
	_require(_intents.is_empty(), "needed hand card selection does not immediately mutate")
	visual.debug_press_pass_turn_action()
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "redeem_all_and_pass_turn", "redeem-and-pass action emits batch redeem intent")

	_intents.clear()
	var off_turn := _snapshot_fixture()
	off_turn["currentTurnParticipantId"] = "p2"
	visual.debug_apply_snapshot(off_turn)
	visual.debug_press_hand_ingredient("cheese")
	_require(_intents.is_empty(), "off-turn hand card does not emit gameplay intent")

	_intents.clear()
	_statuses.clear()
	var depleted := _snapshot_fixture()
	depleted["participants"][0]["realIngredientStock"] = 0
	visual.debug_clear_selections()
	visual.debug_apply_snapshot(depleted)
	visual.debug_press_hand_ingredient("rice")
	_require(visual.debug_selected_hand_ingredient() == "", "stock-depleted hand card is not selected")
	_require(not _statuses.is_empty() and str(_statuses[_statuses.size() - 1]).find("no stock") >= 0, "stock-depleted hand card explains why it is disabled")

	_intents.clear()
	var deposit := _snapshot_fixture()
	deposit["phase"] = "deposit"
	deposit["currentTurnParticipantId"] = "p1"
	deposit["participants"][0]["depositedInitial"] = false
	visual.debug_apply_snapshot(deposit)
	visual.debug_press_hand_ingredient("rice")
	_require(_intents.is_empty(), "deposit card selection does not immediately mutate")
	visual.debug_press_offer_selected_to_common_basket()
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "deposit", "offer to common basket emits deposit intent")

	_intents.clear()
	var swap := _snapshot_fixture()
	swap["ownRecipe"]["requirements"][0]["redeemedQty"] = 1
	visual.debug_apply_snapshot(swap)
	visual.debug_press_hand_ingredient("rice")
	visual.debug_press_platter_ingredient("beans")
	var selected_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(not selected_actions.has("Clear"), "selected-card Actions panel still does not show a Clear button")
	for action in selected_actions:
		_require(not str(action).begins_with("Swap"), "selected-card Actions panel does not show a Swap button")
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "platter_swap", "selected hand and platter cards emit swap intent immediately")

	_intents.clear()
	var auto_swap := _snapshot_fixture()
	visual.debug_apply_snapshot(auto_swap)
	visual.debug_press_platter_ingredient("beans")
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "platter_swap", "auto-selected basket swap emits swap intent")
	_require(str(_intents[0].get("giveVoucherId", "")) == "rice_1", "auto-selected swap gives viewer main card")

	_intents.clear()
	var queued_swap := _snapshot_fixture()
	visual.debug_apply_snapshot(queued_swap)
	visual.debug_press_platter_ingredient("beans")
	visual.debug_press_platter_ingredient("vegetables")
	_require(_intents.size() == 1, "second basket click waits while first swap is in flight")
	_require(visual.debug_basket_swap_queue_size() == 1, "second basket click queues a later swap")
	var queued_swap_confirmed := _swap_after()
	queued_swap_confirmed["turn"] = 15
	queued_swap_confirmed["transactionTotal"] = 1
	visual.render(queued_swap_confirmed)
	visual.debug_flush_animations()
	await process_frame
	_require(_intents.size() == 2 and str(_intents[1].get("type", "")) == "platter_swap", "queued basket click emits after confirmed swap animation; state=%s intents=%s" % [JSON.stringify(visual.debug_basket_swap_queue_state()), JSON.stringify(_intents)])
	_require(str(_intents[1].get("giveVoucherId", "")) == "rice_2" and str(_intents[1].get("takeVoucherId", "")) == "vegetables_1", "queued swap uses the latest legal hand and basket cards")

	_intents.clear()
	var queued_turn_change := _snapshot_fixture()
	visual.debug_apply_snapshot(queued_turn_change)
	visual.debug_press_platter_ingredient("beans")
	visual.debug_press_platter_ingredient("vegetables")
	var queued_turn_after := _swap_after()
	queued_turn_after["turn"] = 15
	queued_turn_after["transactionTotal"] = 1
	queued_turn_after["currentTurnParticipantId"] = "p2"
	visual.render(queued_turn_after)
	visual.debug_flush_animations()
	await process_frame
	_require(_intents.size() == 1, "queued basket swap clears when the turn changes before it can run")
	_require(visual.debug_basket_swap_queue_size() == 0, "turn change removes queued basket swaps")

	_intents.clear()
	var same_resource_swap := _snapshot_fixture()
	same_resource_swap["platter"].append({"id": "rice_9", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "platter"}})
	visual.debug_apply_snapshot(same_resource_swap)
	visual.debug_press_platter_ingredient("rice")
	_require(_intents.size() == 1 and str(_intents[0].get("giveVoucherId", "")) == "cheese_1", "same-resource basket tap swaps another held card by default")

	_intents.clear()
	var no_main_card_swap := _snapshot_fixture()
	no_main_card_swap["ownHand"] = [
		{"id": "spices_1", "ingredientId": "spices", "ownerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "beans_3", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "rice_2", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "vegetables_2", "ingredientId": "vegetables", "ownerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "herbs_1", "ingredientId": "herbs", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p1"}}
	]
	no_main_card_swap["participants"][1]["realIngredientStock"] = 38
	no_main_card_swap["participants"].append({"id": "p5", "name": "Ava", "role": "active", "kind": "human", "ingredientId": "eggs", "connected": true, "depositedInitial": true, "realIngredientStock": 38, "dishCount": 0})
	no_main_card_swap["platter"] = [
		{"id": "eggs_1", "ingredientId": "eggs", "ownerParticipantId": "p5", "location": {"type": "platter"}},
		{"id": "spices_2", "ingredientId": "spices", "ownerParticipantId": "p4", "location": {"type": "platter"}}
	]
	visual.debug_apply_snapshot(no_main_card_swap)
	await process_frame
	visual.debug_press_hand_ingredient("beans")
	await process_frame
	_require(visual.debug_selected_hand_ingredient() == "beans", "non-main hand cards remain selectable when the viewer has no main card")
	visual.debug_press_platter_ingredient("eggs")
	await process_frame
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "platter_swap", "selected non-main card can swap with a different basket card")
	_require(str(_intents[0].get("giveVoucherId", "")) == "beans_3" and str(_intents[0].get("takeVoucherId", "")) == "eggs_1", "beans-for-eggs swap uses the selected non-main card")

	_intents.clear()
	visual.debug_clear_selections()
	visual.debug_apply_snapshot(same_resource_swap)
	visual.debug_press_hand_ingredient("rice")
	visual.debug_press_platter_ingredient("rice")
	var same_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	for action in same_actions:
		_require(not str(action).begins_with("Swap"), "same-ingredient voucher swap has no Action-panel Swap button")
	_require(_intents.is_empty(), "same-ingredient voucher swap does not emit an intent")

	_intents.clear()
	var offer_shortcut := _snapshot_fixture()
	visual.debug_apply_snapshot(offer_shortcut)
	visual.debug_press_participant("p4")
	_require(visual.debug_selected_hand_ingredient() == "rice", "player tap defaults offer-card to viewer main ingredient")
	var create_offer_height := int(visual.debug_stats.get("offerPopupHeight", 0))
	_require(create_offer_height > 0 and create_offer_height <= 620, "create-offer popup stays within portrait bounds with recipe and hand context, height=%s" % create_offer_height)
	_require(not bool(visual.debug_stats.get("offerPopupScrollEnabled", true)), "create-offer popup is tall enough to avoid a scrollbar")
	_require(visual.find_child("OfferGiveCard_rice", true, false) != null, "create-offer popup shows the offered card")
	_require(visual.find_child("OfferGetCard_vegetables", true, false) != null, "create-offer popup shows the requested card")
	_require(visual.find_child("OfferRecipeContext_p4", true, false) != null, "create-offer popup shows target recipe context")
	_require(visual.find_child("OfferMissing_beans", true, false) != null, "create-offer popup shows target missing ingredients")
	_require(visual.find_child("OfferMissing_vegetables", true, false) == null, "create-offer popup omits cards the target already has")
	_require(not (visual.find_child("OfferMissing_beans", true, false) is Button), "offer missing ingredients use grey recipe-slot style instead of colored cards")
	_require(visual.find_child("OfferHandContext_p4", true, false) != null, "create-offer popup shows target hand context")
	_require(visual.find_child("OfferHandVoucher_beans_p2", true, false) != null, "create-offer popup shows grouped non-viewing promise cards")
	var target_hand_food := visual.find_child("OfferHandFood_dish_1_p4", true, false)
	_require(target_hand_food != null, "create-offer popup shows grouped non-viewing dish pieces")
	_require(str(target_hand_food.get_meta("offer_asset_kind", "")) == "dish_part", "create-offer popup marks non-viewing dish pieces as dish-part assets")
	_require(target_hand_food.find_child("CardInsetOutline", true, false) == null, "create-offer popup renders non-viewing dish pieces without card frames")
	_require(visual.find_child("OfferPopupClose", true, false) != null, "offer popup has a top-right close button")
	_assert_offer_actions_below_cards(visual)

	_intents.clear()
	visual.debug_press_offer_hand_voucher("beans", "p2")
	_require(visual.find_child("OfferGetCard_beans", true, false) != null, "clicking a target hand card makes it the requested offer asset")
	_require(_press_button_containing(visual, "Create"), "specific hand-asset offer has a Create button")
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "create_offer", "specific hand-asset offer emits create_offer")
	_require(str(_intents[0].get("requestedAsset", {}).get("ingredientId", "")) == "beans", "specific hand-asset offer requests the clicked ingredient")
	_require(str(_intents[0].get("requestedAsset", {}).get("ownerParticipantId", "")) == "p2", "specific hand-asset offer requests the clicked card owner")

	var incoming_offer_popup := _snapshot_fixture()
	visual.debug_apply_snapshot(incoming_offer_popup)
	visual.debug_press_participant("p2")
	_require(int(visual.debug_stats.get("offerPopupHeight", 0)) > 0 and int(visual.debug_stats.get("offerPopupHeight", 0)) <= 620, "accept/refuse offer popup stays within portrait bounds with recipe and hand context")
	_require(visual.find_child("OfferGiveCard_rice", true, false) != null, "incoming-offer popup shows what the viewer gives")
	_require(visual.find_child("OfferGetCard_beans", true, false) != null, "incoming-offer popup shows what the viewer gets")
	_require(visual.find_child("OfferRecipeContext_p2", true, false) != null, "incoming-offer popup shows other player's recipe context")
	_require(visual.find_child("OfferMissing_cheese", true, false) != null, "incoming-offer popup shows other player's missing ingredients")
	_require(visual.find_child("OfferMissing_beans", true, false) == null, "incoming-offer popup omits cards the sender already has")
	_assert_offer_actions_below_cards(visual)

	var incoming_food_piece_offer := _snapshot_fixture()
	incoming_food_piece_offer["offers"] = [
		{
			"id": "offer_food_piece_incoming",
			"status": "pending",
			"fromParticipantId": "p2",
			"toParticipantId": "p1",
			"offeredAssets": [{"kind": "voucher", "id": "beans_1"}],
			"offeredVoucherIds": [],
			"offeredVouchers": [{"id": "beans_1", "ingredientId": "beans"}],
			"requestedAsset": {"kind": "dish_part", "quantity": 1}
		}
	]
	incoming_food_piece_offer["ownFoodParts"] = [
		{"id": "dish_a_part_1", "dishId": "dish_a", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}}
	]
	visual.debug_apply_snapshot(incoming_food_piece_offer)
	visual.debug_press_participant("p2")
	_require(_has_text_containing(visual, "Cheese Frittata slice x1"), "incoming generic food-piece offer names the actual dish piece in the sentence")
	_require(_has_text_containing(visual, "Frittata slice x1"), "incoming generic food-piece offer names the actual dish piece on the asset")
	var incoming_food_asset := visual.find_child("OfferGiveCard_dish_a", true, false)
	_require(incoming_food_asset != null, "incoming generic food-piece offer uses the actual dish-piece asset")
	_require(str(incoming_food_asset.get_meta("offer_asset_kind", "")) == "dish_part", "incoming generic food-piece offer marks the give asset as a dish piece")
	_require(incoming_food_asset.find_child("CardInsetOutline", true, false) == null, "incoming generic food-piece offer renders the dish piece without a card frame")
	_require(not _has_text_containing(visual, "Food piece x1"), "incoming generic food-piece offer does not show placeholder food-piece text when a concrete piece is available")

	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.debug_press_participant("p3")
	_require(_has_text_containing(visual, "Cancel Offer"), "outgoing-offer popup uses explicit Cancel Offer button text")

	var asset_offer_popup := _snapshot_fixture()
	asset_offer_popup["offers"] = [
		{
			"id": "offer_asset_out",
			"status": "pending",
			"fromParticipantId": "p1",
			"toParticipantId": "p3",
			"offeredAssets": [{"kind": "voucher", "id": "rice_4"}],
			"offeredVoucherIds": [],
			"offeredVouchers": [{"id": "rice_4", "ingredientId": "rice"}],
			"requestedAsset": {"kind": "voucher", "ingredientId": "cheese", "ownerParticipantId": "p3", "quantity": 1}
		}
	]
	visual.debug_apply_snapshot(asset_offer_popup)
	visual.debug_press_participant("p3")
	_require(visual.find_child("OfferGiveCard_rice", true, false) != null, "asset-offer popup resolves the locked offered voucher ingredient")
	_require(not _has_text_containing(visual, "Unknown"), "asset-offer popup does not render unknown offered cards")

	_intents.clear()
	var card_return_offer := _snapshot_fixture()
	card_return_offer["offers"] = []
	for raw_participant in card_return_offer.get("participants", []):
		var participant: Dictionary = raw_participant
		if str(participant.get("id", "")) == "p3":
			participant["heldFoodPartCount"] = 2
			participant["heldFoodPartGroups"] = [{
				"dishId": "dish_clara_frittata",
				"dishName": "Cheese Frittata",
				"makerParticipantId": "p3",
				"unitSingular": "slice",
				"unitPlural": "slices",
				"count": 2
			}]
	visual.debug_apply_snapshot(card_return_offer)
	visual.debug_press_hand_ingredient("cheese")
	visual.debug_press_participant("p3")
	_require(visual.find_child("OfferGiveCard_cheese", true, false) != null, "card-return offer shows the target-owned card being returned")
	var requested_food_piece := visual.find_child("OfferGetCard_dish_clara_frittata", true, false)
	_require(requested_food_piece != null, "card-return offer asks for a named dish piece")
	_require(_card_has_texture(requested_food_piece), "card-return dish-piece request renders a finished-dish sprite")
	_require(str(requested_food_piece.get_meta("offer_asset_kind", "")) == "dish_part", "card-return offer marks requested food as a dish-piece asset")
	_require(requested_food_piece.find_child("CardInsetOutline", true, false) == null, "card-return offer renders requested food without a card frame")
	_require(_has_text_containing(visual, "Redeem Clara's card for Cheese Frittata slice"), "card-return offer explains the named dish-piece settlement")
	_require(_has_text_containing(visual, "Frittata slice x1"), "card-return offer food asset uses the short dish name")
	_require(_press_button_containing(visual, "Create"), "card-return offer can be created")
	_require(_intents.size() == 1, "card-return offer emits one intent")
	_require(str(_intents[0].get("type", "")) == "create_offer", "card-return offer emits create_offer")
	_require(str(_intents[0].get("toParticipantId", "")) == "p3", "card-return offer targets the card owner")
	_require(str(_intents[0].get("requestedAsset", {}).get("kind", "")) == "dish_part", "card-return offer requests a food piece")
	_require(str(_intents[0].get("requestedAsset", {}).get("dishName", "")) == "Cheese Frittata", "card-return offer requests the named dish piece")

	_intents.clear()
	var food_swap := _snapshot_fixture()
	food_swap["ownFoodParts"] = [
		{"id": "dish_2_part_1", "dishId": "dish_2", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}}
	]
	visual.debug_apply_snapshot(food_swap)
	visual.debug_press_own_food_part("Bean Dip")
	visual.debug_press_platter_ingredient("beans")
	visual.debug_press_swap_selected()
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "platter_asset_swap", "held food part can swap with basket asset during play")

	_intents.clear()
	var eating := _snapshot_fixture()
	eating["phase"] = "eating"
	eating["currentTurnParticipantId"] = "p1"
	eating["ownRecipe"] = {}
	eating["participants"][0]["cleared"] = true
	eating["participants"][0]["heldFoodPartCount"] = 2
	eating["participants"][1]["heldFoodPartCount"] = 0
	eating["dishes"] = [
		{"id": "dish_3", "ownerParticipantId": "p1", "name": "Cheese Frittata", "partsRemaining": 2, "partsEaten": 8, "bitesRemaining": 2, "biteCounts": {"p1": 3, "p2": 5}}
	]
	eating["ownFoodParts"] = [
		{"id": "dish_3_part_1", "dishId": "dish_3", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}}
	]
	visual.debug_apply_snapshot(eating)
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Food to Eat", "eating phase labels held food as food to eat")
	_require(_has_text_containing(visual, "2 left"), "eating phase shows held pieces still left")
	_require(_has_text_containing(visual, "3 eaten"), "eating phase shows bites already eaten")
	var eating_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(eating_actions.has("Share food."), "eating phase labels the eat-all action as Share food")
	_require(bool(visual.debug_stats.get("takeBiteEnabled", false)), "eating phase enables Share food for cleared player with held food parts")
	visual.debug_press_take_bite_action()
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "bite_all", "Share food emits bite-all intent")

	_intents.clear()
	visual.debug_apply_snapshot(snapshot)
	visual.debug_press_first_incoming_offer_accept()
	_require(_intents.size() == 1 and str(_intents[0].get("type", "")) == "respond_offer", "incoming offer accept emits response intent")

	var offline := _snapshot_fixture()
	offline["offline"] = true
	visual.debug_apply_snapshot(offline)
	_require(int(visual.debug_stats.get("recipeSlotCount", 0)) == 6, "offline-shaped snapshot renders through same path")

	var completed := _snapshot_fixture()
	completed["ownRecipe"] = {}
	completed["targetDishCount"] = 3
	completed["participants"][0]["dishCount"] = 4
	visual.debug_apply_snapshot(completed)
	_require(int(visual.debug_stats.get("dishSummaryCount", 0)) == 4, "empty recipe area renders active player dish counts")
	_require(int(visual.debug_stats.get("dishSummaryColumns", 0)) == 2, "dish summary renders as a two-column grid")
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Dishes Made", "dish summary title stays centered as Dishes Made")
	_require(_has_progress_node_matching(visual, 3, 3), "completed dish summary uses filled drawn progress stars")
	_require(_has_progress_node_matching(visual, 0, 3), "unfinished dish summary uses empty drawn progress stars")
	_require(not _has_label_containing(visual, "3/3"), "dish summary hides numeric slash progress")

	var settlement := _snapshot_fixture()
	settlement["phase"] = "settlement"
	settlement["ownRecipe"] = {}
	settlement["participants"][0]["heldFoodPartCount"] = 40
	settlement["participants"][1]["heldFoodPartCount"] = 39
	settlement["participants"][2]["heldFoodPartCount"] = 20
	settlement["participants"][3]["heldFoodPartCount"] = 0
	for participant in settlement["participants"]:
		participant["dishCount"] = int(settlement.get("targetDishCount", 3))
		participant["cleared"] = false
	visual.debug_apply_snapshot(settlement)
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Dish Pieces Held", "settlement summary title is Dish Pieces Held")
	_require(int(visual.debug_stats.get("pieceSummaryCount", 0)) == 4, "settlement summary renders active player held pieces")
	_require(int(visual.debug_stats.get("pieceSummaryTotal", 0)) == 99, "settlement summary totals held pieces that can still be eaten")
	_require(_has_label_containing(visual, "Everyone has to settle and return"), "settlement Actions panel explains common-basket debt goal")
	_require(_has_label_containing(visual, "2 cards in the common basket"), "settlement Actions panel explains two-card basket target")

	var crowded_settlement := settlement.duplicate(true)
	crowded_settlement["ownHand"] = [
		{"id": "rice_1", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "beans_1", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_1", "ingredientId": "cheese", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "flour_1", "ingredientId": "flour", "ownerParticipantId": "p4", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "herbs_1", "ingredientId": "herbs", "ownerParticipantId": "p5", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "eggs_1", "ingredientId": "eggs", "ownerParticipantId": "p6", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "spices_1", "ingredientId": "spices", "ownerParticipantId": "p7", "location": {"type": "hand", "participantId": "p1"}}
	]
	crowded_settlement["ownFoodParts"] = []
	var crowded_dish_names := [
		"Cheese Frittata",
		"Bean Dip",
		"Cheesy Rice Bake",
		"Vegetable Chili",
		"Herb Rice Bowl",
		"Cheese Quesadilla",
		"Breakfast Burrito",
		"Fried Rice",
		"Spiced Pancakes",
		"Rice Casserole"
	]
	for index in range(10):
		crowded_settlement["ownFoodParts"].append({
			"id": "crowded_part_%s" % index,
			"dishId": "crowded_dish_%s" % index,
			"dishName": crowded_dish_names[index],
			"unitSingular": "piece",
			"unitPlural": "pieces",
			"makerParticipantId": "p%s" % ((index % 4) + 1),
			"location": {"type": "hand", "participantId": "p1"}
		})
	visual.debug_apply_snapshot(crowded_settlement)
	await process_frame
	_require(float(visual.debug_stats.get("combinedMinimumOverflowY", 999.0)) <= 0.1, "crowded settlement hand assets do not increase table minimum height; stats=%s" % JSON.stringify(visual.debug_stats))
	_require(int(visual.debug_stats.get("handScrollVerticalMode", -1)) == ScrollContainer.SCROLL_MODE_AUTO, "crowded settlement uses internal hand scrolling instead of stretching the table")

	var complete := _snapshot_fixture()
	complete["phase"] = "complete"
	complete["turn"] = 88
	complete["gameStats"] = {
		"activePlayerCount": 4,
		"mutationCount": 88,
		"playerTurnCount": 32,
		"cycleCount": 8.0,
		"interactionCount": 74,
		"openingOfferingCount": 8,
		"commonBasketSwapCount": 9,
		"directExchangeCount": 7,
		"redemptionCount": 24,
		"prepareCount": 12,
		"settlementSwapCount": 5,
		"foodPieceSettlementSwapCount": 3,
		"eatCount": 20,
		"assetLossCount": 8,
		"productivityCount": 20,
		"profitCount": 12,
		"profitGainPercent": 150.0,
		"averageTurnsPerDish": 2.67,
		"averageInteractionsPerDish": 6.17,
		"basketVelocity": 1.75,
		"directExchangeShare": 0.333,
		"settlementBurden": 0.067,
		"scarcityPressureByIngredient": {"cheese": 2, "eggs": 1},
		"hoardingIndex": 3,
		"hoardingIndexLabel": "Amina holds Eggs x3",
		"liquidityDepth": 4.2,
		"settlementTimeTurns": 6,
		"consumptionVariance": 1.5,
		"tradeBalanceByParticipant": {
			"p1": {"participantId": "p1", "name": "Amina", "given": 4, "received": 5, "net": 1},
			"p2": {"participantId": "p2", "name": "Ben", "given": 5, "received": 4, "net": -1}
		}
	}
	complete["ownRecipe"] = {}
	complete["participants"][0]["realIngredientStock"] = 10
	complete["participants"][1]["realIngredientStock"] = 11
	complete["participants"][2]["realIngredientStock"] = 12
	complete["participants"][3]["realIngredientStock"] = 13
	complete["dishes"] = [
		{"id": "dish_1", "ownerParticipantId": "p1", "name": "Cheese Frittata", "partsRemaining": 0, "partsEaten": 10, "bitesRemaining": 0, "biteCounts": {"p1": 3, "p2": 2}},
		{"id": "dish_2", "ownerParticipantId": "p2", "name": "Bean Dip", "partsRemaining": 0, "partsEaten": 10, "bitesRemaining": 0, "biteCounts": {"p1": 1, "p3": 4}}
	]
	visual.debug_apply_snapshot(complete)
	_require(bool(visual.debug_stats.get("completeCelebration", false)), "complete phase renders congratulations state")
	_require(bool(visual.debug_stats.get("completeFireworks", false)), "complete phase renders animated fireworks in Actions")
	_require(str(visual.debug_stats.get("recipeName", "")) == "Congratulations!", "complete phase replaces recipe title")
	_require(str(visual.debug_stats.get("recipeTitle", "")) == "Congratulations! 32 player turns", "complete phase shows player turn count in title")
	_require(main_menu_overlay != null and main_menu_overlay.visible, "complete phase exposes the top Main Menu button")
	var complete_actions: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(complete_actions.has("Game Stats"), "complete phase exposes detailed game stats")
	_require(visual.find_child("ActionFireworks", true, false) != null, "complete phase has a fireworks control")
	_require(not _has_text_containing(visual, "Party fireworks"), "complete phase removes static Party fireworks text")
	_require(_has_text_containing(visual, "Rice: 10"), "complete phase summarizes raw ingredient stock")
	_require(_has_text_containing(visual, "Bites: 4"), "complete phase summarizes bites with label")
	_require(int(visual.debug_stats.get("completeBiteSummaryCount", 0)) == 4, "complete phase summarizes bites for active players")
	_require(visual.preferred_visual_size() == Vector2(700, 960), "complete phase keeps the same preferred table size")
	visual.call("_open_game_stats_popup")
	await process_frame
	_require(int(visual.debug_stats.get("offerPopupWidth", 0)) > 0 and int(visual.debug_stats.get("offerPopupWidth", 0)) <= 600, "game stats popup keeps a safe responsive width")
	_require(_has_text_containing(visual, "Assets lost: 8"), "game stats popup includes asset loss")
	_require(_has_text_containing(visual, "Productivity: 20"), "game stats popup includes productivity")
	_require(_has_text_containing(visual, "Profit: 12"), "game stats popup includes profit")
	_require(_has_text_containing(visual, "Gain: 150%"), "game stats popup includes percent gain")
	_require(_has_text_containing(visual, "Avg turns/dish: 2.7"), "game stats popup includes average turns per dish")
	_require(_has_text_containing(visual, "Basket velocity: 1.8 swaps/cycle"), "game stats popup includes basket velocity")
	_require(_has_text_containing(visual, "Direct exchange share: 33.3%"), "game stats popup includes direct exchange share")
	_require(not _has_text_containing(visual, "Scarcity pressure"), "game stats popup omits low-signal scarcity pressure")
	_require(not _has_text_containing(visual, "Hoarding index"), "game stats popup omits low-signal hoarding index")
	_require(not _has_text_containing(visual, "Trade balance"), "game stats popup omits neutral trade balance")
	_require(visual.find_child("Button_View Transaction History", true, false) != null or _has_button_text(visual, "View Transaction History"), "game stats popup includes transaction history button")

	if _failed:
		quit(1)
	else:
		print("table visual smoke ok")
		quit()


func _assert_animation_event(visual: Node, before_snapshot: Dictionary, after_snapshot: Dictionary, expected_type: String, message: String) -> void:
	visual.debug_apply_snapshot(before_snapshot)
	visual.render(after_snapshot)
	var types: Array = visual.debug_stats.get("lastAnimationTypes", [])
	_require(types.has(expected_type), message)
	visual.debug_flush_animations()


func _assert_offer_actions_below_cards(visual: Node) -> void:
	var panel := visual.find_child("OfferPanel", true, false)
	_require(panel != null, "offer panel exists")
	var card_pair := panel.find_child("OfferCardPair", true, false)
	var action_row := panel.find_child("OfferActionRow", true, false)
	var context := panel.find_child("OfferRecipeContext_*", true, false)
	_require(card_pair != null and action_row != null and context != null, "offer panel has cards, actions, and recipe context")
	_require(card_pair.get_index() < action_row.get_index(), "offer action buttons appear below the offer cards")
	_require(action_row.get_index() < context.get_index(), "offer recipe context appears below the action buttons")


func _assert_animation_count(visual: Node, before_snapshot: Dictionary, after_snapshot: Dictionary, expected_type: String, expected_minimum: int, message: String) -> void:
	visual.debug_apply_snapshot(before_snapshot)
	visual.render(after_snapshot)
	var count := 0
	for raw_type in visual.debug_stats.get("lastAnimationTypes", []):
		if str(raw_type) == expected_type:
			count += 1
	_require(count >= expected_minimum, message)
	visual.debug_flush_animations()


func _assert_eat_animation_starts_at_held_food_part(visual: Node) -> void:
	visual.debug_apply_snapshot(_eating_before())
	await process_frame
	visual.render(_eating_after())
	var event := _first_animation_event_of_type(visual, "eat")
	_require(not event.is_empty(), "eat animation event is queued")
	_require(str(event.get("dishId", "")) == "dish_3", "eat animation records the held dish id")
	_require(typeof(event.get("startPoint", null)) == TYPE_VECTOR2, "eat animation records the concrete held food-piece anchor")
	var points: Dictionary = visual.debug_animation_path_points(event)
	var held_piece_center := _node_center(visual.find_child("HandFood_dish_3", true, false))
	var rice_card_center := _node_center(visual.find_child("HandCard_rice", true, false))
	_require(_points_close(points.get("start", Vector2.INF), held_piece_center), "bite animation starts on the completed dish piece in the viewer hand")
	_require(_points_differ(points.get("start", Vector2.INF), rice_card_center), "bite animation does not fall back to the first ingredient promise card")
	var stale_event := event.duplicate(true)
	stale_event["startPoint"] = rice_card_center
	points = visual.debug_animation_path_points(stale_event)
	_require(_points_close(points.get("start", Vector2.INF), held_piece_center), "bite animation prefers the visible held food-piece tile over a stale recorded point")
	visual.debug_apply_next_animation_milestone()
	await process_frame
	_require(visual.find_child("HandFood_dish_3", true, false) == null, "bite milestone removes the eaten food-piece tile")
	points = visual.debug_animation_path_points(event)
	_require(_points_close(points.get("start", Vector2.INF), held_piece_center), "bite animation keeps the recorded food-piece anchor after the hand grid updates")
	visual.debug_flush_animations()


func _assert_eat_animation_reanchors_after_food_group_reflow(visual: Node) -> void:
	visual.debug_apply_snapshot(_eating_many_before())
	await process_frame
	visual.render(_eating_many_after())
	visual.debug_apply_next_animation_milestone()
	visual.debug_apply_next_animation_milestone()
	await process_frame
	var bean_piece_center := _node_center(visual.find_child("HandFood_dish_4", true, false))
	var rice_card_center := _node_center(visual.find_child("HandCard_rice", true, false))
	var points: Dictionary = visual.debug_animation_path_points({
		"type": "eat",
		"dishId": "dish_4",
		"dishName": "Bean Dip",
		"unit": "scoop"
	})
	_require(_points_close(points.get("start", Vector2.INF), bean_piece_center), "next bite animation re-anchors to the current food-piece position after hand reflow")
	_require(_points_differ(points.get("start", Vector2.INF), rice_card_center), "next bite animation still avoids ingredient-card fallback after hand reflow")
	visual.debug_flush_animations()


func _assert_public_swap_transactions_animate_separately(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_multi_swap_after())
	var events: Array = visual.debug_stats.get("lastAnimationEvents", [])
	var swaps: Array = []
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "swap":
			swaps.append(event)
	_require(swaps.size() == 2, "two public swap transactions queue two visible swap animations")
	_require(str(swaps[0].get("actorParticipantId", "")) == "p2", "first public swap belongs to Ben")
	_require(str(swaps[0].get("giveIngredientId", "")) == "beans" and str(swaps[0].get("takeIngredientId", "")) == "vegetables", "first public swap animates Beans to basket and Veggies back")
	_require(str(swaps[1].get("actorParticipantId", "")) == "p4", "second public swap belongs to Diego")
	_require(str(swaps[1].get("giveIngredientId", "")) == "vegetables" and str(swaps[1].get("takeIngredientId", "")) == "beans", "second public swap animates Veggies to basket and Beans back")
	for raw_event in swaps:
		var points: Dictionary = visual.debug_animation_path_points(raw_event)
		_require(_all_points_valid(points), "public swap has visible player and basket endpoints")
		_require(_points_differ(points.get("giveStart", Vector2.INF), points.get("giveEnd", Vector2.INF)), "public swap give leg moves from player to basket")
		_require(_points_differ(points.get("takeStart", Vector2.INF), points.get("takeEnd", Vector2.INF)), "public swap take leg moves from basket to player")
	visual.debug_flush_animations()


func _assert_pending_public_swaps_render_in_sequence(visual: Node) -> void:
	var first := _public_swap_after()
	first["version"] = 2
	first["turn"] = 15
	first["transactionTotal"] = 1
	var second := _public_second_swap_after()
	second["version"] = 3
	second["turn"] = 16
	second["transactionTotal"] = 2
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(first)
	visual.render(second)
	var first_type: String = visual.debug_apply_next_animation_milestone()
	_require(first_type == "swap", "first pending public basket swap animates before later snapshots apply")
	var second_type: String = visual.debug_apply_next_animation_milestone()
	_require(second_type == "swap", "second pending public basket swap animates after the first completes")
	visual.debug_flush_animations()


func _assert_unknown_actor_basket_delta_does_not_animate_from_wrong_cook(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_swap_without_transaction_after())
	var events: Array = visual.debug_stats.get("lastAnimationEvents", [])
	for raw_event in events:
		var event: Dictionary = raw_event
		_require(str(event.get("type", "")) != "swap", "basket delta without actor does not invent a public swap animation")
	visual.debug_flush_animations()


func _assert_swap_paths_are_specific(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_swap_after())
	var local_swap := _first_animation_event_of_type(visual, "swap")
	var local_points: Dictionary = visual.debug_animation_path_points(local_swap)
	_require(_all_points_valid(local_points), "local swap has all path endpoints")
	_require(_points_close(local_points.get("giveStart", Vector2.INF), _node_center(visual.find_child("HandCard_rice", true, false))), "local swap starts at the selected hand card")
	_require(_points_close(local_points.get("giveEnd", Vector2.INF), _node_center(visual.find_child("BasketSlot_rice", true, false))), "local swap gives card to its specific basket slot")
	_require(_points_close(local_points.get("takeStart", Vector2.INF), _node_center(visual.find_child("PlatterVoucher_beans", true, false))), "local swap takes from the specific basket card")
	_require(_points_differ(local_points.get("takeStart", Vector2.INF), local_points.get("takeEnd", Vector2.INF)), "local swap returns basket card toward the hand")
	visual.debug_flush_animations()

	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_multi_swap_after())
	var swaps: Array = []
	for raw_event in visual.debug_stats.get("lastAnimationEvents", []):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "swap":
			swaps.append(event)
	_require(swaps.size() == 2, "public swap path check has both public swaps")
	for raw_event in swaps:
		var event: Dictionary = raw_event
		var actor_id := str(event.get("actorParticipantId", ""))
		var give_ingredient := str(event.get("giveIngredientId", ""))
		var take_ingredient := str(event.get("takeIngredientId", ""))
		var points: Dictionary = visual.debug_animation_path_points(event)
		var actor_center := _node_center(visual.find_child("Participant_%s" % actor_id, true, false))
		_require(_points_close(points.get("giveStart", Vector2.INF), actor_center), "public swap give leg starts at acting cook %s" % actor_id)
		_require(_points_close(points.get("giveEnd", Vector2.INF), _node_center(visual.find_child("BasketSlot_%s" % give_ingredient, true, false))), "public swap give leg ends at %s basket slot" % give_ingredient)
		_require(_points_close(points.get("takeStart", Vector2.INF), _node_center(visual.find_child("PlatterVoucher_%s" % take_ingredient, true, false))), "public swap take leg starts at %s basket card" % take_ingredient)
		_require(_points_close(points.get("takeEnd", Vector2.INF), actor_center), "public swap take leg returns to acting cook %s" % actor_id)
	visual.debug_flush_animations()


func _assert_public_settlement_food_part_uses_future_basket_slot(visual: Node) -> void:
	visual.debug_apply_snapshot(_public_settlement_food_part_before())
	await process_frame
	visual.render(_public_settlement_food_part_after())
	var event := _first_animation_event_of_type(visual, "settlement_swap")
	_require(not event.is_empty(), "public settlement food-part swap queues an animation")
	var points: Dictionary = visual.debug_animation_path_points(event)
	_require(_all_points_valid(points), "public settlement food-part swap has visible endpoints")
	var actor_center := _node_center(visual.find_child("Participant_p2", true, false))
	var basket_center := _node_center(visual.find_child("BasketSlot_beans", true, false))
	_require(_points_close(points.get("giveStart", Vector2.INF), actor_center), "public settlement food part starts at the acting cook")
	_require(not _points_close(points.get("giveEnd", Vector2.INF), basket_center), "public settlement food part does not fall back to a voucher slot or broad basket center")
	_require(_points_close(points.get("takeStart", Vector2.INF), _node_center(visual.find_child("PlatterVoucher_beans", true, false))), "public settlement return starts at the basket voucher")
	_require(_points_close(points.get("takeEnd", Vector2.INF), actor_center), "public settlement return lands on the acting cook")
	visual.debug_flush_animations()
	visual.debug_apply_snapshot(_public_settlement_food_part_after())
	await process_frame
	var platter_food := visual.find_child("PlatterFood_dish_9", true, false)
	_require(platter_food != null, "public settlement final render shows the new basket food part")
	var give_end: Vector2 = points.get("giveEnd", Vector2.INF)
	var food_center := _node_center(platter_food)
	_require(
		give_end != Vector2.INF and food_center != Vector2.INF and give_end.distance_to(food_center) <= 4.0,
		"public settlement food part lands at its future basket card: %s vs %s" % [give_end, food_center]
	)
	visual.debug_flush_animations()


func _assert_exchange_paths_are_specific(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_exchange_after())
	var exchange := _first_animation_event_of_type(visual, "exchange")
	var points: Dictionary = visual.debug_animation_path_points(exchange)
	_require(_all_points_valid(points), "viewer exchange has explicit endpoints")
	_require(_points_close(points.get("offeredStart", Vector2.INF), _node_center(visual.find_child("Participant_p2", true, false))), "exchange offered card starts at the offering cook")
	_require(_points_close(points.get("offeredEnd", Vector2.INF), _node_center(visual.find_child("HandRow", true, false))), "exchange offered card lands in the viewer hand tray when no grouped card exists yet")
	_require(_points_close(points.get("requestedStart", Vector2.INF), _node_center(visual.find_child("HandCard_rice", true, false))), "exchange requested card starts at viewer hand card")
	_require(_points_close(points.get("requestedEnd", Vector2.INF), _node_center(visual.find_child("Participant_p2", true, false))), "exchange requested card returns to offering cook")
	visual.debug_flush_animations()

	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_exchange_after())
	exchange = _first_animation_event_of_type(visual, "exchange")
	points = visual.debug_animation_path_points(exchange)
	_require(_all_points_valid(points), "public exchange has explicit cook endpoints")
	_require(_points_close(points.get("offeredStart", Vector2.INF), _node_center(visual.find_child("Participant_p2", true, false))), "public exchange offered card starts at source cook")
	_require(_points_close(points.get("offeredEnd", Vector2.INF), _node_center(visual.find_child("Participant_p4", true, false))), "public exchange offered card goes to target cook")
	_require(_points_close(points.get("requestedStart", Vector2.INF), _node_center(visual.find_child("Participant_p4", true, false))), "public exchange requested card starts at counterparty cook")
	_require(_points_close(points.get("requestedEnd", Vector2.INF), _node_center(visual.find_child("Participant_p2", true, false))), "public exchange requested card returns to source cook")
	visual.debug_flush_animations()


func _assert_swap_updates_basket_before_returning_card(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_swap_after())
	_require(_visible_hand_count(visual, "rice") == 2, "swap starts with both rice cards still in hand")
	_require(_visible_platter_count(visual, "rice") == 0, "swap starts before rice is added to basket")
	_require(_visible_hand_count(visual, "beans") == 0, "swap starts before beans returns to hand")
	_require(_visible_platter_count(visual, "beans") == 2, "swap starts with both beans cards in basket")

	var start: String = visual.debug_apply_current_animation_start()
	_require(start == "swap", "swap source-start stage is available")
	_require(_visible_hand_count(visual, "rice") == 1, "swap source-start removes the moving rice card from hand")
	_require(_visible_platter_count(visual, "rice") == 0, "swap source-start does not add rice to basket before it lands")
	_require(_visible_platter_count(visual, "beans") == 2, "swap source-start keeps taken beans in basket")

	var mid: String = visual.debug_apply_current_animation_midpoint()
	_require(mid == "swap", "swap midpoint is available")
	_require(_visible_hand_count(visual, "rice") == 1, "swap midpoint removes the given rice card from hand")
	_require(_visible_platter_count(visual, "rice") == 1, "swap midpoint increments the rice count in basket")
	_require(_visible_hand_count(visual, "beans") == 0, "swap midpoint has not returned beans to hand yet")
	_require(_visible_platter_count(visual, "beans") == 2, "swap midpoint keeps the taken beans card in basket until the return leg")

	var take_start: String = visual.debug_apply_current_animation_take_start()
	_require(take_start == "swap", "swap take-start stage is available")
	_require(_visible_hand_count(visual, "beans") == 0, "swap take-start has not added beans to hand yet")
	_require(_visible_platter_count(visual, "beans") == 1, "swap take-start removes the moving beans card from basket")

	var final: String = visual.debug_apply_next_animation_milestone()
	_require(final == "swap", "swap final milestone applies after return leg")
	_require(_visible_hand_count(visual, "rice") == 1, "swap final keeps the given rice in basket")
	_require(_visible_platter_count(visual, "rice") == 1, "swap final keeps rice basket count incremented")
	_require(_visible_hand_count(visual, "beans") == 1, "swap final returns one beans card to hand")
	_require(_visible_platter_count(visual, "beans") == 1, "swap final decrements the taken beans card from basket")
	visual.debug_flush_animations()

	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_swap_last_visible_cards_after())
	_require(_visible_hand_count(visual, "cheese") == 1, "last-card swap starts with one cheese card in hand")
	_require(_visible_platter_count(visual, "vegetables") == 1, "last-card swap starts with one veggies card in basket")
	start = visual.debug_apply_current_animation_start()
	_require(start == "swap", "last-card swap source-start stage is available")
	_require(_visible_hand_count(visual, "cheese") == 0, "last-card swap removes the only cheese card from hand as it moves")
	_require(_visible_platter_count(visual, "cheese") == 0, "last-card swap does not leave a landed cheese copy before arrival")
	mid = visual.debug_apply_current_animation_midpoint()
	_require(mid == "swap", "last-card swap midpoint is available")
	_require(_visible_platter_count(visual, "cheese") == 1, "last-card swap adds cheese to basket only after it lands")
	take_start = visual.debug_apply_current_animation_take_start()
	_require(take_start == "swap", "last-card swap take-start stage is available")
	_require(_visible_platter_count(visual, "vegetables") == 0, "last-card swap removes the only veggies card from basket as it moves")
	_require(_visible_hand_count(visual, "vegetables") == 0, "last-card swap does not add veggies to hand before return lands")
	final = visual.debug_apply_next_animation_milestone()
	_require(final == "swap", "last-card swap final milestone applies")
	_require(_visible_hand_count(visual, "vegetables") == 1, "last-card swap adds veggies to hand only after return lands")
	visual.debug_flush_animations()


func _assert_animation_handoffs_before_fade_out(visual: Node) -> void:
	var timings: Dictionary = visual.debug_animation_handoff_timings()
	var card_landing := float(timings.get("cardLanding", 0.0))
	var card_fade_end := float(timings.get("cardFadeOutEnd", 0.0))
	var swap_mid := float(timings.get("swapMid", 0.0))
	var swap_take_start := float(timings.get("swapTakeStart", 0.0))
	var swap_return_visible := float(timings.get("swapReturnVisible", 0.0))
	var swap_finish := float(timings.get("swapFinish", 0.0))
	var swap_return_fade_end := float(timings.get("swapReturnFadeOutEnd", 0.0))
	var redeem_finish := float(timings.get("redeemFinish", 0.0))
	var redeem_ingredient_fade_end := float(timings.get("redeemIngredientFadeOutEnd", 0.0))
	_require(swap_mid <= card_landing + 0.001, "swap gives appear in the basket before the moving card fades out")
	_require(card_landing < card_fade_end, "card animation has a visible fade-out window after landing")
	_require(swap_take_start >= swap_return_visible - 0.001, "swap take source stays visible until the return card is visible")
	_require(swap_finish <= swap_return_fade_end + 0.001, "swap final hand state appears before the return card fades out")
	_require(redeem_finish <= redeem_ingredient_fade_end + 0.001, "redeem final recipe state appears before the ingredient fades out")


func _assert_swap_return_targets_existing_hand_group_after_layout_shift(visual: Node) -> void:
	visual.debug_apply_snapshot(_swap_existing_return_before())
	visual.render(_swap_existing_return_after())
	var start: String = visual.debug_apply_current_animation_start()
	_require(start == "swap", "existing-card swap source-start stage is available")
	var mid: String = visual.debug_apply_current_animation_midpoint()
	_require(mid == "swap", "existing-card swap midpoint is available")
	var take_start: String = visual.debug_apply_current_animation_take_start()
	_require(take_start == "swap", "existing-card swap take-start stage is available")
	var target: Vector2 = visual.debug_current_swap_take_end_point()
	var existing_card := visual.find_child("HandCard_beans", true, false)
	_require(existing_card != null, "existing-card swap keeps a visible grouped target")
	_require(_points_close(target, _node_center(existing_card)), "swap return lands on the existing grouped hand item after the hand row shifts")
	visual.debug_flush_animations()


func _assert_public_swap_return_uses_recorded_actor_after_staged_layout(visual: Node) -> void:
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_swap_after())
	var event := _first_animation_event_of_type(visual, "swap")
	_require(not event.is_empty(), "public swap event is available for staged return path check")
	var actor_id := str(event.get("actorParticipantId", ""))
	var actor_center := _node_center(visual.find_child("Participant_%s" % actor_id, true, false))
	_require(actor_center != Vector2.INF, "public swap actor tile is visible before staged playback")
	var start: String = visual.debug_apply_current_animation_start()
	_require(start == "swap", "public swap source-start stage is available")
	var mid: String = visual.debug_apply_current_animation_midpoint()
	_require(mid == "swap", "public swap midpoint stage is available")
	var take_start: String = visual.debug_apply_current_animation_take_start()
	_require(take_start == "swap", "public swap take-start stage is available")
	var target: Vector2 = visual.debug_current_swap_take_end_point()
	_require(_points_close(target, actor_center), "public swap return keeps the recorded acting cook target after staged basket layout changes")
	visual.debug_flush_animations()


func _first_animation_event_of_type(visual: Node, event_type: String) -> Dictionary:
	for raw_event in visual.debug_stats.get("lastAnimationEvents", []):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _assert_public_redeem_paths_card_to_owner_and_ingredient_back(visual: Node) -> void:
	_statuses.clear()
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_public_redeem_after())
	var events: Array = visual.debug_stats.get("lastAnimationEvents", [])
	var redeem_event: Dictionary = {}
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "public_redeem":
			redeem_event = event
			break
	_require(not redeem_event.is_empty(), "public redeem event is queued")
	_require(str(redeem_event.get("participantId", "")) == "p2" and str(redeem_event.get("ownerParticipantId", "")) == "p1", "public redeem records redeemer and card owner")
	var points: Dictionary = visual.debug_animation_path_points(redeem_event)
	_require(_all_points_valid(points), "public redeem has visible card and ingredient endpoints")
	var actor_center := _node_center(visual.find_child("Participant_p2", true, false))
	var owner_stock_center := _node_center(visual.find_child("Participant_p1", true, false))
	_require(_points_close(points.get("cardStart", Vector2.INF), actor_center), "public redeem card starts at the acting cook")
	_require(_points_close(points.get("cardEnd", Vector2.INF), owner_stock_center), "public redeem card lands on the owner cook tile when the owner is the viewer")
	_require(_points_close(points.get("ingredientStart", Vector2.INF), owner_stock_center), "public redeem ingredient starts from the owner cook tile")
	_require(_points_close(points.get("ingredientEnd", Vector2.INF), actor_center), "public redeem ingredient returns to the acting cook")
	visual.debug_apply_next_animation_milestone()
	_require(_statuses.is_empty(), "public redeem animation does not show status/dialog text")
	visual.debug_flush_animations()


func _assert_redeem_animation_has_no_dialog_artifacts(visual: Node) -> void:
	_statuses.clear()
	visual.debug_apply_snapshot(_snapshot_fixture())
	visual.render(_redeem_all_after())
	await process_frame
	await process_frame
	_require(_statuses.is_empty(), "redeem animation playback does not emit transient status text")
	_require(not _has_label_containing(visual, "Redeeming"), "redeem animation playback does not create a transient caption panel")
	visual.debug_flush_animations()


func _has_text_containing(node: Node, needle: String) -> bool:
	for raw_child in node.find_children("*", "Button", true, false):
		var button := raw_child as Button
		if button != null and button.text.find(needle) >= 0:
			return true
	for raw_child in node.find_children("*", "Label", true, false):
		var label := raw_child as Label
		if label != null and label.text.find(needle) >= 0:
			return true
	return false


func _press_button_containing(node: Node, needle: String) -> bool:
	for raw_child in node.find_children("*", "Button", true, false):
		var button := raw_child as Button
		if button != null and not button.disabled and button.text.find(needle) >= 0:
			button.pressed.emit()
			return true
	return false


func _has_label_containing(node: Node, needle: String) -> bool:
	for raw_child in node.find_children("*", "Label", true, false):
		var label := raw_child as Label
		if label != null and label.text.find(needle) >= 0:
			return true
	return false


func _progress_node_matches(node: Node, filled: int, total: int) -> bool:
	if node == null:
		return false
	return int(node.get("filled_count")) == filled and int(node.get("total_count")) == total


func _has_progress_node_matching(node: Node, filled: int, total: int) -> bool:
	for raw_child in node.find_children("*", "Control", true, false):
		if str(raw_child.name).find("ProgressStars") >= 0 and _progress_node_matches(raw_child, filled, total):
			return true
	return false


func _assert_public_action_temporarily_highlights_actor(visual: Node) -> void:
	var before := _snapshot_fixture()
	before["turnMode"] = "round_robin"
	before["currentTurnParticipantId"] = "p4"
	var after := _public_swap_after()
	after["turnMode"] = "round_robin"
	after["currentTurnParticipantId"] = "p4"
	visual.debug_apply_snapshot(before)
	visual.render(after)
	await process_frame
	_require(str(visual.debug_stats.get("animationActorParticipantId", "")) == "p2", "public swap records the acting cook while the animation runs")
	var actor_tile := visual.find_child("Participant_p2", true, false)
	_require(actor_tile != null and actor_tile.find_child("TurnCircle", true, false) != null, "public swap highlights acting cook during animation")
	var turn_tile := visual.find_child("Participant_p4", true, false)
	_require(turn_tile != null and turn_tile.find_child("TurnCircle", true, false) == null, "public swap suppresses the snapshot turn highlight while another cook's animation is running")
	_require(_turn_circle_count(visual) == 1, "only one cook or viewer has a turn circle while a public action animation runs")
	visual.debug_flush_animations()


func _turn_circle_count(node: Node) -> int:
	var count := 0
	for raw_child in node.find_children("TurnCircle", "Control", true, false):
		var child := raw_child as Control
		if child != null and child.visible:
			count += 1
	return count


func _all_points_valid(points: Dictionary) -> bool:
	if points.is_empty():
		return false
	for key in points.keys():
		if points.get(key, Vector2.INF) == Vector2.INF:
			return false
	return true


func _points_differ(left: Vector2, right: Vector2) -> bool:
	return left != Vector2.INF and right != Vector2.INF and left.distance_to(right) > 2.0


func _points_close(left: Vector2, right: Vector2) -> bool:
	return left != Vector2.INF and right != Vector2.INF and left.distance_to(right) <= 2.0


func _node_center(node: Node) -> Vector2:
	var control := node as Control
	return control.get_global_rect().get_center() if control != null else Vector2.INF


func _assert_turn_update_waits_for_animation(visual: Node) -> void:
	var before := _snapshot_fixture()
	var after := _snapshot_fixture()
	after["currentTurnParticipantId"] = "p2"
	visual.debug_apply_snapshot(before)
	visual.render(after)
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "turn-only handoff applies immediately")
	var types: Array = visual.debug_stats.get("lastAnimationTypes", [])
	_require(not types.has("turn"), "turn-only handoff does not queue a visual animation")
	visual.debug_flush_animations()
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "turn-only handoff remains on the next cook")


func _assert_turn_handoff_does_not_preempt_animation_actor(visual: Node) -> void:
	_require(visual.debug_animation_actor_for_event({"type": "turn", "participantId": "p2"}) == "", "turn handoff event does not temporarily steal the turn circle")
	_require(visual.debug_animation_actor_for_event({"type": "public_redeem", "participantId": "p2"}) == "p2", "public actions still highlight the acting cook during animation")


func _assert_batch_redeem_updates_counts_one_by_one(visual: Node) -> void:
	var before := _snapshot_fixture()
	var after := _redeem_all_after()
	after["currentTurnParticipantId"] = "p2"
	after["turn"] = 15
	visual.debug_apply_snapshot(before)
	visual.render(after)
	var animation_state: Dictionary = visual.pending_visual_debug_state()
	_require(bool(animation_state.get("animationRunning", false)), "batch redeem starts the first animation immediately after confirmation")
	_require(_visible_hand_count(visual, "rice") == 2, "batch redeem keeps initial rice count before first animation finishes")
	_require(_visible_hand_count(visual, "cheese") == 1, "batch redeem keeps initial cheese count before first animation finishes")
	_require(_visible_redeemed_count(visual, "rice") == 1, "batch redeem keeps initial recipe count before first animation finishes")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "batch redeem keeps current turn before redeem animations finish")
	_assert_batch_redeem_paths_are_specific(visual)

	var first: String = visual.debug_apply_next_animation_milestone()
	_require(first == "redeem", "batch redeem first milestone is a redeem")
	_require(_visible_hand_count(visual, "rice") == 1, "first redeem milestone removes one rice card visually")
	_require(_visible_hand_count(visual, "cheese") == 1, "first redeem milestone leaves later cheese card in hand")
	_require(_visible_redeemed_count(visual, "rice") == 2, "first redeem milestone fills one rice recipe slot")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "first redeem milestone does not pass the turn")

	var second: String = visual.debug_apply_next_animation_milestone()
	_require(second == "redeem", "batch redeem second milestone is a redeem")
	_require(_visible_hand_count(visual, "cheese") == 0, "second redeem milestone removes one cheese card visually")
	_require(_visible_redeemed_count(visual, "cheese") == 1, "second redeem milestone fills the cheese recipe slot")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "second redeem milestone still does not pass the turn")

	var third: String = visual.debug_apply_next_animation_milestone()
	_require(third == "turn", "batch redeem passes turn only after redeem milestones")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "batch redeem updates turn after the turn milestone")
	visual.debug_flush_animations()


func _assert_redeem_pass_auto_prepare_waits_for_redeem_animations(visual: Node) -> void:
	var before := _redeem_pass_auto_prepare_before()
	var after := _redeem_pass_auto_prepare_after()
	visual.debug_apply_snapshot(before)
	visual.render(after)
	_require(str(visual.debug_stats.get("recipeName", "")) == "Rice Bean Bowl", "auto-prepare redeem/pass keeps the current recipe visible before animations")
	_require(_visible_redeemed_count(visual, "cheese") == 0, "auto-prepare redeem/pass keeps final slot empty before the redeem animation")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "auto-prepare redeem/pass keeps turn on viewer before animations")
	var types: Array = visual.debug_stats.get("lastAnimationTypes", [])
	_require(types.size() >= 3 and types[0] == "redeem" and types[1] == "prepare" and types[2] == "turn", "auto-prepare redeem/pass queues redeem, prepare, then turn: %s" % JSON.stringify(types))

	var first: String = visual.debug_apply_next_animation_milestone()
	_require(first == "redeem", "auto-prepare first milestone is the final redemption")
	_require(_visible_redeemed_count(visual, "cheese") == 1, "auto-prepare final redemption fills the old recipe slot")
	_require(str(visual.debug_stats.get("recipeName", "")) == "Rice Bean Bowl", "auto-prepare keeps old recipe through final redemption")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "auto-prepare keeps turn before prepare animation")

	var second: String = visual.debug_apply_next_animation_milestone()
	_require(second == "prepare", "auto-prepare second milestone is dish preparation")
	_require(str(visual.debug_stats.get("recipeName", "")) == "Cheese Frittata", "auto-prepare shows the new recipe after the prepare animation")
	_require(_visible_food_part_count(visual, "Rice Bean Bowl") == 1, "auto-prepare shows prepared dish pieces after prepare animation")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "auto-prepare keeps turn until the later pass-turn milestone")

	var third: String = visual.debug_apply_next_animation_milestone()
	_require(third == "turn", "auto-prepare third milestone is pass turn")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "auto-prepare passes turn only after redemption and preparation animations")
	visual.debug_flush_animations()


func _assert_batch_redeem_paths_are_specific(visual: Node) -> void:
	var redeem_events: Array = []
	for raw_event in visual.debug_stats.get("lastAnimationEvents", []):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "redeem":
			redeem_events.append(event)
	_require(redeem_events.size() >= 2, "batch redeem has one animation event per redeemed card")

	var rice_event: Dictionary = redeem_events[0]
	var cheese_event: Dictionary = redeem_events[1]
	_require(str(rice_event.get("ingredientId", "")) == "rice" and str(rice_event.get("ownerParticipantId", "")) == "p1", "rice redeem targets Amina as card owner")
	_require(str(cheese_event.get("ingredientId", "")) == "cheese" and str(cheese_event.get("ownerParticipantId", "")) == "p3", "cheese redeem targets Clara as card owner")

	for raw_event in [rice_event, cheese_event]:
		var event: Dictionary = raw_event
		var points: Dictionary = visual.debug_animation_path_points(event)
		_require(_all_points_valid(points), "redeem event has visible card owner and recipe endpoints")
		_require(_points_differ(points.get("cardStart", Vector2.INF), points.get("cardEnd", Vector2.INF)), "redeem card moves from hand to exact owner")
		_require(_points_differ(points.get("ingredientStart", Vector2.INF), points.get("ingredientEnd", Vector2.INF)), "redeem ingredient moves from exact owner to recipe slot")
		_require(points.get("cardEnd", Vector2.INF) == points.get("ingredientStart", Vector2.INF), "redeem ingredient starts exactly where card was delivered")
		if str(event.get("ingredientId", "")) == "rice":
			_require(_points_close(points.get("cardStart", Vector2.INF), _node_center(visual.find_child("HandCard_rice", true, false))), "own redeem starts from exact rice hand card")
			_require(_points_close(points.get("cardEnd", Vector2.INF), _node_center(visual.find_child("Participant_p1", true, false))), "own redeem returns card to the viewer cook tile")
			_require(_points_close(points.get("ingredientEnd", Vector2.INF), _node_center(visual.find_child("RecipeSlot_rice_1", true, false))), "own redeem sends ingredient to exact open recipe slot")
		if str(event.get("ingredientId", "")) == "cheese":
			_require(_points_close(points.get("cardStart", Vector2.INF), _node_center(visual.find_child("HandCard_cheese", true, false))), "other-owner redeem starts from exact cheese hand card")
			_require(_points_close(points.get("cardEnd", Vector2.INF), _node_center(visual.find_child("Participant_p3", true, false))), "other-owner redeem sends card to exact owner cook")
			_require(_points_close(points.get("ingredientEnd", Vector2.INF), _node_center(visual.find_child("RecipeSlot_cheese_5", true, false))), "other-owner redeem sends ingredient to exact recipe slot")


func _assert_in_place_delta_redeem_pass_waits_for_animation(visual: Node) -> void:
	var live_snapshot := _snapshot_fixture()
	visual.debug_apply_snapshot(live_snapshot)
	var after := _redeem_all_after()
	after["currentTurnParticipantId"] = "p2"
	after["turn"] = 15
	live_snapshot.clear()
	for key in after.keys():
		live_snapshot[key] = after[key]
	visual.render(live_snapshot)
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "in-place delta keeps current turn while redeem/pass animations are staged")
	var types: Array = visual.debug_stats.get("lastAnimationTypes", [])
	_require(types.has("redeem") and types.has("turn"), "in-place delta queues redeem animations before turn handoff")
	var first: String = visual.debug_apply_next_animation_milestone()
	_require(first == "redeem", "in-place delta first milestone is a redemption")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "in-place delta first redemption keeps turn on actor")
	var second: String = visual.debug_apply_next_animation_milestone()
	_require(second == "redeem", "in-place delta second milestone is a redemption")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "in-place delta second redemption keeps turn on actor")
	var third: String = visual.debug_apply_next_animation_milestone()
	_require(third == "turn", "in-place delta changes turn only after redemptions")
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "in-place delta applies next turn after redemption animations")
	visual.debug_flush_animations()


func _assert_redeem_pass_and_public_turns_apply_in_order(visual: Node) -> void:
	var before := _snapshot_fixture()
	var after := _redeem_pass_with_public_turn_after()
	visual.debug_apply_snapshot(before)
	visual.render(after)
	_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "combined update keeps turn on viewer before animations")
	var expected := ["redeem", "redeem", "turn", "public_redeem", "turn"]
	for index in range(expected.size()):
		var next_type: String = visual.debug_apply_next_animation_milestone()
		_require(next_type == expected[index], "combined update milestone %s is %s, got %s" % [index + 1, expected[index], next_type])
		if index < 2:
			_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p1", "combined update keeps viewer turn through own redemption %s" % (index + 1))
		elif index < 4:
			_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p2", "combined update advances only to the next cook before later public animations")
		else:
			_require(str(visual.debug_stats.get("currentTurnParticipantId", "")) == "p3", "combined update advances to later cook only after that turn animation")
	visual.debug_flush_animations()


func _assert_deposits_update_basket_one_by_one(visual: Node) -> void:
	var before := _deposit_all_before()
	var after := _deposit_all_after()
	visual.debug_apply_snapshot(before)
	visual.render(after)
	_require(_visible_platter_count(visual, "rice") == 0, "opening deposits keep basket empty before the first animation finishes")
	_require(visual.debug_stats.get("lastDepositBasketSlots", []) == [5, 5, 6, 6, 1, 1, 2, 2], "opening deposits target fixed center-first basket slots")

	var first: String = visual.debug_apply_next_animation_milestone()
	_require(first == "deposit", "opening deposits first milestone is a deposit")
	_require(_visible_platter_count(visual, "cheese") == 1, "first opening deposit follows the first Deposit transaction")
	_require(_visible_platter_total(visual) == 1, "first opening deposit only reveals one basket card")

	var second: String = visual.debug_apply_next_animation_milestone()
	_require(second == "deposit", "opening deposits second milestone is a deposit")
	_require(_visible_platter_count(visual, "cheese") == 2, "second opening deposit follows the second Deposit transaction")
	_require(_visible_platter_total(visual) == 2, "second opening deposit reveals exactly two basket cards")

	var third: String = visual.debug_apply_next_animation_milestone()
	_require(third == "deposit", "opening deposits third milestone is a deposit")
	_require(_visible_platter_count(visual, "rice") == 1, "third opening deposit follows the third Deposit transaction")
	_require(_visible_platter_total(visual) == 3, "third opening deposit reveals exactly three basket cards")

	var fourth: String = visual.debug_apply_next_animation_milestone()
	_require(fourth == "deposit", "opening deposits fourth milestone is a deposit")
	_require(_visible_platter_count(visual, "rice") == 2, "fourth opening deposit follows the fourth Deposit transaction")
	_require(_visible_platter_total(visual) == 4, "fourth opening deposit reveals four fixture basket cards")
	visual.debug_flush_animations()


func _assert_start_snapshot_animates_offerings_from_empty_basket(visual: Node) -> void:
	var before := _lobby_before_start()
	var after := _deposit_all_after()
	visual.debug_apply_snapshot(before)
	var min_width_before: float = visual.get_combined_minimum_size().x
	visual.render(after)
	_require(str(visual.debug_stats.get("phase", "")) == "deposit", "start snapshot applies the deposit phase immediately")
	_require(str(visual.debug_stats.get("recipeName", "")) == "Rice Bean Bowl", "start snapshot shows the recipe before animations")
	_require(int(visual.debug_stats.get("recipeSlotCount", 0)) == 6, "start snapshot shows the six recipe slots")
	_require(int(visual.debug_stats.get("handGroupCount", 0)) == 2, "start snapshot shows viewer promise cards")
	_require(_visible_hand_count(visual, "rice") == 2, "start snapshot shows the viewer's offered card before it animates")
	_require(_visible_platter_total(visual) == 0, "start snapshot begins with an empty Common Basket")
	_require(int(visual.debug_stats.get("animationEventCount", 0)) == 8, "start snapshot queues offering animations from the setup baseline")
	_require(visual.debug_stats.get("lastDepositBasketSlots", []) == [5, 5, 6, 6, 1, 1, 2, 2], "start snapshot offering animations target fixed center-first basket slots")
	_require(visual.debug_stats.get("basketVisualOrder", []) == ["eggs", "vegetables", "beans", "spices", "flour", "cheese", "rice", "herbs"], "start snapshot basket order follows fixed screen slots while deposits animate in transaction order")
	await process_frame
	var backdrop := visual.find_child("BasketBackdrop", true, false) as Control
	_require(backdrop != null, "start snapshot renders the fixed basket backdrop")
	var basket_size_before := backdrop.get_global_rect().size if backdrop != null else Vector2.ZERO
	_require(visual.get_combined_minimum_size().x <= min_width_before + 1.0, "start snapshot offering animations do not widen the visual table")
	var anchors: Array = visual.debug_deposit_animation_anchors()
	_require(anchors.size() == 8, "start snapshot keeps all deposit animation anchors queued or running")
	_require(_valid_unique_anchor_count(anchors, "start") >= 4, "start snapshot deposits originate from distinct cooks or hand cards")
	_require(_valid_unique_anchor_count(anchors, "end") >= 4, "start snapshot deposits target distinct final basket cells")
	var participant_tile := visual.find_child("Participant_p2", true, false)
	_require(participant_tile != null, "start snapshot renders cook tiles")
	if participant_tile != null:
		var cook_ingredient := participant_tile.find_child("CookIngredientLabel", true, false) as Label
		_require(cook_ingredient != null and cook_ingredient.text.find("Beans x28") >= 0, "start snapshot shows cook ingredient stock labels")
	var first: String = visual.debug_apply_next_animation_milestone()
	await process_frame
	_require(first == "deposit", "start snapshot first animation is an offering")
	_require(_same_size(backdrop.get_global_rect().size, basket_size_before), "first offering does not resize the basket backdrop: %s -> %s" % [basket_size_before, backdrop.get_global_rect().size])
	_require(_visible_platter_total(visual) == 1, "first offering animation adds one basket card")
	_require(_visible_platter_count(visual, "cheese") == 1, "first offering animation follows the first Deposit transaction")
	var second: String = visual.debug_apply_next_animation_milestone()
	await process_frame
	_require(second == "deposit", "start snapshot second animation is an offering")
	_require(_same_size(backdrop.get_global_rect().size, basket_size_before), "second offering does not resize the basket backdrop: %s -> %s" % [basket_size_before, backdrop.get_global_rect().size])
	var third: String = visual.debug_apply_next_animation_milestone()
	await process_frame
	_require(third == "deposit", "start snapshot third animation is an offering")
	_require(_same_size(backdrop.get_global_rect().size, basket_size_before), "third offering does not resize the basket backdrop: %s -> %s" % [basket_size_before, backdrop.get_global_rect().size])
	var fourth: String = visual.debug_apply_next_animation_milestone()
	await process_frame
	_require(fourth == "deposit", "start snapshot fourth animation is an offering")
	_require(_same_size(backdrop.get_global_rect().size, basket_size_before), "fourth offering does not resize the basket backdrop: %s -> %s" % [basket_size_before, backdrop.get_global_rect().size])
	visual.debug_flush_animations()
	_require(_visible_platter_total(visual) == 8, "start snapshot ends with confirmed basket contents after animations")
	var action_texts: Array = visual.debug_stats.get("actionButtonTexts", [])
	_require(not action_texts.has("Offer"), "start snapshot does not show a manual Offer action after opening animations finish")
	_require(str(visual.debug_stats.get("phase", "")) == "playing", "start snapshot ends in normal play after opening animations finish")


func _assert_eight_start_snapshot_animates_offerings_from_cooks_to_fixed_basket(visual: Node) -> void:
	var before := _eight_lobby_before_start()
	var after := _eight_start_after()
	visual.debug_apply_snapshot(before)
	visual.render(after)
	_require(_visible_platter_total(visual) == 0, "8-seat start keeps basket empty before offering animations")
	_require(visual.debug_stats.get("lastDepositBasketSlots", []) == [5, 5, 6, 6, 1, 1, 2, 2, 4, 4, 7, 7, 3, 3, 0, 0], "8-seat offerings target center-out basket slots")
	await process_frame
	var anchors: Array = visual.debug_deposit_animation_anchors()
	_require(anchors.size() == 16, "8-seat start queues every opening offering")
	_require(_valid_unique_anchor_count(anchors, "start") >= 8, "8-seat offerings originate from each cook or viewer hand")
	_require(_valid_unique_anchor_count(anchors, "end") >= 8, "8-seat offerings fly to eight distinct final basket cells")
	var expected_ingredients := ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
	for ingredient_id in expected_ingredients:
		for expected_count in range(1, 3):
			var next_type: String = visual.debug_apply_next_animation_milestone()
			_require(next_type == "deposit", "8-seat opening milestone is a deposit for %s" % ingredient_id)
			_require(_visible_platter_count(visual, ingredient_id) == expected_count, "8-seat opening reveals %s directly in its final basket cell" % ingredient_id)
	visual.debug_flush_animations()
	_require(_visible_platter_total(visual) == 16, "8-seat opening ends with all sixteen offerings in the basket")


func _valid_unique_anchor_count(anchors: Array, key: String) -> int:
	var seen := {}
	for raw_anchor in anchors:
		var anchor: Dictionary = raw_anchor
		var point: Vector2 = anchor.get(key, Vector2.INF)
		if point == Vector2.INF:
			continue
		var point_key := "%s,%s" % [roundi(point.x), roundi(point.y)]
		seen[point_key] = true
	return seen.size()


func _same_size(left: Vector2, right: Vector2) -> bool:
	return absf(left.x - right.x) <= 1.0 and absf(left.y - right.y) <= 1.0


func _visible_hand_count(visual: Node, ingredient_id: String) -> int:
	var snapshot: Dictionary = visual.debug_visible_snapshot()
	var count := 0
	for raw_voucher in snapshot.get("ownHand", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			count += 1
	return count


func _visible_platter_count(visual: Node, ingredient_id: String) -> int:
	var snapshot: Dictionary = visual.debug_visible_snapshot()
	var count := 0
	for raw_voucher in snapshot.get("platter", []):
		var voucher: Dictionary = raw_voucher
		if str(voucher.get("ingredientId", "")) == ingredient_id:
			count += 1
	return count


func _visible_platter_total(visual: Node) -> int:
	var snapshot: Dictionary = visual.debug_visible_snapshot()
	return snapshot.get("platter", []).size()


func _visible_redeemed_count(visual: Node, ingredient_id: String) -> int:
	var snapshot: Dictionary = visual.debug_visible_snapshot()
	var recipe: Dictionary = snapshot.get("ownRecipe", {})
	for raw_requirement in recipe.get("requirements", []):
		var requirement: Dictionary = raw_requirement
		if str(requirement.get("ingredientId", "")) == ingredient_id:
			return int(requirement.get("redeemedQty", 0))
	return 0


func _visible_food_part_count(visual: Node, dish_name: String) -> int:
	var snapshot: Dictionary = visual.debug_visible_snapshot()
	var count := 0
	for raw_part in snapshot.get("ownFoodParts", []):
		var part: Dictionary = raw_part
		if str(part.get("dishName", "")) == dish_name:
			count += 1
	return count


func _deposit_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "deposit"
	snapshot["participants"][0]["depositedInitial"] = false
	snapshot["participants"][0]["openingOfferingsCount"] = 0
	return snapshot


func _deposit_after() -> Dictionary:
	var snapshot := _deposit_before()
	snapshot["participants"][0]["depositedInitial"] = false
	snapshot["participants"][0]["openingOfferingsCount"] = 1
	_move_voucher(snapshot, "rice_1", "ownHand", "platter")
	return snapshot


func _deposit_all_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "deposit"
	snapshot["platter"] = []
	for index in range(snapshot["participants"].size()):
		snapshot["participants"][index]["depositedInitial"] = false
		snapshot["participants"][index]["openingOfferingsCount"] = 0
	return snapshot


func _deposit_all_after() -> Dictionary:
	var snapshot := _deposit_all_before()
	snapshot["phase"] = "playing"
	for index in range(snapshot["participants"].size()):
		snapshot["participants"][index]["depositedInitial"] = true
		snapshot["participants"][index]["openingOfferingsCount"] = 2
	_remove_voucher(snapshot, "rice_1", "ownHand")
	_remove_voucher(snapshot, "rice_2", "ownHand")
	snapshot["platter"] = [
		{"id": "rice_1", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "platter"}},
		{"id": "rice_2", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "platter"}},
		{"id": "beans_1", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}},
		{"id": "beans_2", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}},
		{"id": "cheese_7", "ingredientId": "cheese", "ownerParticipantId": "p3", "location": {"type": "platter"}},
		{"id": "cheese_8", "ingredientId": "cheese", "ownerParticipantId": "p3", "location": {"type": "platter"}},
		{"id": "vegetables_1", "ingredientId": "vegetables", "ownerParticipantId": "p4", "location": {"type": "platter"}},
		{"id": "vegetables_2", "ingredientId": "vegetables", "ownerParticipantId": "p4", "location": {"type": "platter"}}
	]
	snapshot["transactionHistory"] = [
		{"id": "tx_1", "turn": 14, "participantId": "p3", "name": "Clara", "action": "Deposit", "counterparty": "Platter", "itemOut": "Cheese", "itemBack": "None"},
		{"id": "tx_2", "turn": 14, "participantId": "p3", "name": "Clara", "action": "Deposit", "counterparty": "Platter", "itemOut": "Cheese", "itemBack": "None"},
		{"id": "tx_3", "turn": 14, "participantId": "p1", "name": "Amina", "action": "Deposit", "counterparty": "Platter", "itemOut": "Rice", "itemBack": "None"},
		{"id": "tx_4", "turn": 14, "participantId": "p1", "name": "Amina", "action": "Deposit", "counterparty": "Platter", "itemOut": "Rice", "itemBack": "None"},
		{"id": "tx_5", "turn": 14, "participantId": "p4", "name": "Diego", "action": "Deposit", "counterparty": "Platter", "itemOut": "Veggies", "itemBack": "None"},
		{"id": "tx_6", "turn": 14, "participantId": "p4", "name": "Diego", "action": "Deposit", "counterparty": "Platter", "itemOut": "Veggies", "itemBack": "None"},
		{"id": "tx_7", "turn": 14, "participantId": "p2", "name": "Ben", "action": "Deposit", "counterparty": "Platter", "itemOut": "Beans", "itemBack": "None"},
		{"id": "tx_8", "turn": 14, "participantId": "p2", "name": "Ben", "action": "Deposit", "counterparty": "Platter", "itemOut": "Beans", "itemBack": "None"}
	]
	return snapshot


func _lobby_before_start() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "lobby"
	snapshot["currentTurnParticipantId"] = ""
	snapshot["platter"] = []
	snapshot["platterFoodParts"] = []
	snapshot["ownHand"] = []
	snapshot["ownFoodParts"] = []
	snapshot["ownRecipe"] = {}
	snapshot["offers"] = []
	for index in range(snapshot["participants"].size()):
		var participant: Dictionary = snapshot["participants"][index]
		participant.erase("ingredientId")
		participant.erase("realIngredientStock")
		participant["depositedInitial"] = false
		participant["openingOfferingsCount"] = 0
		participant["dishCount"] = 0
		snapshot["participants"][index] = participant
	return snapshot


func _eight_lobby_before_start() -> Dictionary:
	var snapshot := _eight_seat_snapshot()
	snapshot["phase"] = "lobby"
	snapshot["currentTurnParticipantId"] = ""
	snapshot["platter"] = []
	snapshot["platterFoodParts"] = []
	snapshot["ownHand"] = []
	snapshot["ownFoodParts"] = []
	snapshot["ownRecipe"] = {}
	snapshot["transactionHistory"] = []
	snapshot["offers"] = []
	for index in range(snapshot["participants"].size()):
		var participant: Dictionary = snapshot["participants"][index]
		participant["depositedInitial"] = false
		participant["openingOfferingsCount"] = 0
		participant["dishCount"] = 0
		snapshot["participants"][index] = participant
	return snapshot


func _eight_start_after() -> Dictionary:
	var snapshot := _eight_seat_snapshot()
	snapshot["phase"] = "playing"
	snapshot["transactionHistory"] = []
	for index in range(snapshot["participants"].size()):
		var participant: Dictionary = snapshot["participants"][index]
		participant["depositedInitial"] = true
		participant["openingOfferingsCount"] = 2
		snapshot["participants"][index] = participant
		var ingredient_id := str(participant.get("ingredientId", ""))
		for offering_index in range(2):
			snapshot["transactionHistory"].append({
				"id": "tx_open_%s_%s" % [index + 1, offering_index + 1],
				"turn": 1,
				"participantId": str(participant.get("id", "")),
				"name": str(participant.get("name", "")),
				"action": "Deposit",
				"counterparty": "Platter",
				"itemOut": _display_for_test_ingredient(ingredient_id),
				"itemBack": "None"
			})
	return snapshot


func _display_for_test_ingredient(ingredient_id: String) -> String:
	if ingredient_id == "vegetables":
		return "Veggies"
	return ingredient_id.capitalize()


func _swap_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	_move_voucher(snapshot, "rice_1", "ownHand", "platter")
	_move_voucher(snapshot, "beans_1", "platter", "ownHand")
	return snapshot


func _swap_existing_return_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	var hand: Array = snapshot.get("ownHand", [])
	hand.append({"id": "beans_3", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}})
	snapshot["ownHand"] = hand
	return snapshot


func _swap_existing_return_after() -> Dictionary:
	var snapshot := _swap_existing_return_before()
	_move_voucher(snapshot, "rice_1", "ownHand", "platter")
	_move_voucher(snapshot, "beans_1", "platter", "ownHand")
	return snapshot


func _swap_last_visible_cards_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	_move_voucher(snapshot, "cheese_1", "ownHand", "platter")
	_move_voucher(snapshot, "vegetables_1", "platter", "ownHand")
	return snapshot


func _public_swap_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	_remove_voucher(snapshot, "vegetables_1", "platter")
	snapshot["platter"].append({"id": "beans_9", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}})
	snapshot["transactionHistory"] = [
		{"id": "tx_1", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Swap", "counterparty": "Platter", "itemOut": "Beans card 7", "itemBack": "Veggies x1"}
	]
	return snapshot


func _public_swap_without_transaction_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	_remove_voucher(snapshot, "vegetables_1", "platter")
	snapshot["platter"].append({"id": "beans_9", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}})
	snapshot["transactionHistory"] = []
	return snapshot


func _public_multi_swap_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["transactionHistory"] = [
		{"id": "tx_1", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Swap", "counterparty": "Platter", "itemOut": "Beans", "itemBack": "Veggies"},
		{"id": "tx_2", "turn": 16, "participantId": "p4", "name": "Diego", "action": "Swap", "counterparty": "Platter", "itemOut": "Veggies", "itemBack": "Beans"}
	]
	return snapshot


func _public_second_swap_after() -> Dictionary:
	var snapshot := _public_swap_after()
	snapshot["transactionHistory"] = [
		{"id": "tx_1", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Swap", "counterparty": "Platter", "itemOut": "Beans", "itemBack": "Veggies"},
		{"id": "tx_2", "turn": 16, "participantId": "p4", "name": "Diego", "action": "Swap", "counterparty": "Platter", "itemOut": "Veggies", "itemBack": "Beans"}
	]
	return snapshot


func _public_exchange_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["transactionHistory"] = [
		{"id": "tx_9", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Exchange", "counterpartyParticipantId": "p4", "counterparty": "Diego", "itemOut": "Beans", "itemBack": "Veggies"}
	]
	return snapshot


func _exchange_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["currentTurnParticipantId"] = "p3"
	_remove_voucher(snapshot, "rice_1", "ownHand")
	snapshot["ownHand"].append({"id": "beans_3", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "hand", "participantId": "p1"}})
	snapshot["offers"] = [snapshot["offers"][1]]
	snapshot["transactionHistory"] = [
		{"id": "tx_3", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Exchange", "counterpartyParticipantId": "p1", "counterparty": "Amina", "itemOut": "Beans", "itemBack": "Rice"}
	]
	return snapshot


func _redeem_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["ownRecipe"]["requirements"][0]["redeemedQty"] = 2
	_remove_voucher(snapshot, "rice_1", "ownHand")
	return snapshot


func _redeem_all_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["ownRecipe"]["requirements"][0]["redeemedQty"] = 2
	snapshot["ownRecipe"]["requirements"][4]["redeemedQty"] = 1
	_remove_voucher(snapshot, "rice_1", "ownHand")
	_remove_voucher(snapshot, "cheese_1", "ownHand")
	snapshot["transactionHistory"] = [
		{"id": "tx_4", "turn": 15, "participantId": "p1", "name": "Amina", "action": "Redeem", "counterpartyParticipantId": "p1", "counterparty": "Amina", "itemOut": "Rice", "itemBack": "Real Rice"},
		{"id": "tx_5", "turn": 15, "participantId": "p1", "name": "Amina", "action": "Redeem", "counterpartyParticipantId": "p3", "counterparty": "Clara", "itemOut": "Cheese", "itemBack": "Real Cheese"}
	]
	return snapshot


func _redeem_pass_with_public_turn_after() -> Dictionary:
	var snapshot := _redeem_all_after()
	snapshot["currentTurnParticipantId"] = "p3"
	snapshot["participants"][0]["realIngredientStock"] = 27
	snapshot["transactionHistory"].append({
		"id": "tx_6",
		"turn": 15,
		"participantId": "p1",
		"name": "Amina",
		"action": "Pass Turn",
		"counterpartyParticipantId": "p2",
		"counterparty": "Ben",
		"itemOut": "None",
		"itemBack": "None"
	})
	snapshot["transactionHistory"].append({
		"id": "tx_7",
		"turn": 16,
		"participantId": "p2",
		"name": "Ben",
		"action": "Redeem",
		"counterpartyParticipantId": "p1",
		"counterparty": "Amina",
		"itemOut": "Rice",
		"itemBack": "Real Rice"
	})
	snapshot["transactionHistory"].append({
		"id": "tx_8",
		"turn": 16,
		"participantId": "p2",
		"name": "Ben",
		"action": "Pass Turn",
		"counterpartyParticipantId": "p3",
		"counterparty": "Clara",
		"itemOut": "None",
		"itemBack": "None"
	})
	return snapshot


func _redeem_pass_auto_prepare_before() -> Dictionary:
	var snapshot := _prepare_before()
	var requirements: Array = snapshot["ownRecipe"]["requirements"]
	for index in range(requirements.size()):
		var requirement: Dictionary = requirements[index]
		if str(requirement.get("ingredientId", "")) == "cheese":
			requirement["redeemedQty"] = 0
			requirements[index] = requirement
			break
	snapshot["ownRecipe"]["requirements"] = requirements
	snapshot["transactionHistory"] = []
	return snapshot


func _redeem_pass_auto_prepare_after() -> Dictionary:
	var snapshot := _prepare_after()
	_remove_voucher(snapshot, "cheese_1", "ownHand")
	snapshot["currentTurnParticipantId"] = "p2"
	snapshot["turn"] = 15
	snapshot["transactionHistory"] = [
		{"id": "tx_auto_redeem", "turn": 15, "participantId": "p1", "name": "Amina", "action": "Redeem", "counterpartyParticipantId": "p3", "counterparty": "Clara", "itemOut": "Cheese", "itemBack": "Real Cheese"},
		{"id": "tx_auto_prepare", "turn": 15, "participantId": "p1", "name": "Amina", "action": "Prepare", "counterparty": "Table", "itemOut": "Rice Bean Bowl", "itemBack": "Rice Bean Bowl bowl"},
		{"id": "tx_auto_pass", "turn": 15, "participantId": "p1", "name": "Amina", "action": "Pass Turn", "counterpartyParticipantId": "p2", "counterparty": "Ben", "itemOut": "None", "itemBack": "None"}
	]
	return snapshot


func _public_redeem_after() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["participants"][0]["realIngredientStock"] = 27
	snapshot["transactionHistory"] = [
		{"id": "tx_2", "turn": 15, "participantId": "p2", "name": "Ben", "action": "Redeem", "counterpartyParticipantId": "p1", "counterparty": "Amina", "itemOut": "Rice", "itemBack": "Real Rice"}
	]
	return snapshot


func _prepare_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	for raw_requirement in snapshot["ownRecipe"]["requirements"]:
		var requirement: Dictionary = raw_requirement
		requirement["redeemedQty"] = int(requirement.get("requiredQty", 0))
	return snapshot


func _prepare_after() -> Dictionary:
	var snapshot := _prepare_before()
	snapshot["participants"][0]["dishCount"] = 1
	snapshot["ownRecipe"] = {
		"id": "recipe_2",
		"name": "Cheese Frittata",
		"requirements": [
			{"id": "req_cheese", "ingredientId": "cheese", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_eggs", "ingredientId": "eggs", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_rice", "ingredientId": "rice", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_beans", "ingredientId": "beans", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_spices", "ingredientId": "spices", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_flour", "ingredientId": "flour", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
		]
	}
	snapshot["ownFoodParts"] = [
		{"id": "dish_3_part_1", "dishId": "dish_3", "dishName": "Rice Bean Bowl", "unitSingular": "bowl", "unitPlural": "bowls", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}}
	]
	return snapshot


func _offer_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["offers"] = []
	return snapshot


func _settlement_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "settlement"
	snapshot["ownRecipe"] = {}
	snapshot["ownFoodParts"] = [
		{"id": "dish_2_part_1", "dishId": "dish_2", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}}
	]
	return snapshot


func _settlement_after() -> Dictionary:
	var snapshot := _settlement_before()
	var food_part: Dictionary = snapshot["ownFoodParts"][0]
	snapshot["ownFoodParts"] = []
	snapshot["platterFoodParts"].append(food_part)
	_move_voucher(snapshot, "beans_1", "platter", "ownHand")
	return snapshot


func _public_settlement_food_part_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "settlement"
	snapshot["ownRecipe"] = {}
	snapshot["platterFoodParts"] = []
	snapshot["transactionHistory"] = []
	return snapshot


func _public_settlement_food_part_after() -> Dictionary:
	var snapshot := _public_settlement_food_part_before()
	snapshot["platterFoodParts"] = [
		{"id": "dish_9_part_1", "dishId": "dish_9", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p2", "location": {"type": "platter"}}
	]
	_remove_voucher(snapshot, "beans_1", "platter")
	snapshot["transactionHistory"] = [
		{"id": "tx_settle_food", "turn": 22, "participantId": "p2", "name": "Ben", "action": "Settlement Swap", "counterparty": "Platter", "itemOut": "Bean Dip scoop", "itemBack": "Beans"}
	]
	return snapshot


func _eating_before() -> Dictionary:
	var snapshot := _snapshot_fixture()
	snapshot["phase"] = "eating"
	snapshot["participants"][0]["cleared"] = true
	snapshot["ownFoodParts"] = [
		{"id": "dish_3_part_1", "dishId": "dish_3", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}}
	]
	return snapshot


func _eating_after() -> Dictionary:
	var snapshot := _eating_before()
	snapshot["ownFoodParts"] = []
	return snapshot


func _eating_many_before() -> Dictionary:
	var snapshot := _eating_before()
	snapshot["ownFoodParts"] = [
		{"id": "dish_3_part_1", "dishId": "dish_3", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}},
		{"id": "dish_3_part_2", "dishId": "dish_3", "dishName": "Cheese Frittata", "unitSingular": "slice", "unitPlural": "slices", "makerParticipantId": "p1", "location": {"type": "inventory", "participantId": "p1"}},
		{"id": "dish_4_part_1", "dishId": "dish_4", "dishName": "Bean Dip", "unitSingular": "scoop", "unitPlural": "scoops", "makerParticipantId": "p2", "location": {"type": "inventory", "participantId": "p1"}}
	]
	return snapshot


func _eating_many_after() -> Dictionary:
	var snapshot := _eating_many_before()
	snapshot["ownFoodParts"] = []
	return snapshot


func _complete_before() -> Dictionary:
	var snapshot := _eating_after()
	snapshot["phase"] = "eating"
	return snapshot


func _complete_after() -> Dictionary:
	var snapshot := _complete_before()
	snapshot["phase"] = "complete"
	return snapshot


func _move_voucher(snapshot: Dictionary, voucher_id: String, from_key: String, to_key: String) -> void:
	var from_array: Array = snapshot.get(from_key, [])
	for index in range(from_array.size()):
		var voucher: Dictionary = from_array[index]
		if str(voucher.get("id", "")) == voucher_id:
			from_array.remove_at(index)
			var moved := voucher.duplicate(true)
			moved["location"] = {"type": "hand", "participantId": "p1"} if to_key == "ownHand" else {"type": "platter"}
			var to_array: Array = snapshot.get(to_key, [])
			to_array.append(moved)
			snapshot[to_key] = to_array
			return


func _remove_voucher(snapshot: Dictionary, voucher_id: String, from_key: String) -> void:
	var from_array: Array = snapshot.get(from_key, [])
	for index in range(from_array.size()):
		var voucher: Dictionary = from_array[index]
		if str(voucher.get("id", "")) == voucher_id:
			from_array.remove_at(index)
			snapshot[from_key] = from_array
			return


func _snapshot_fixture() -> Dictionary:
	return {
		"tableCode": "VISUAL",
		"phase": "playing",
		"turn": 14,
		"targetDishCount": 3,
		"turnMode": "round_robin",
		"currentTurnParticipantId": "p1",
		"viewerParticipantId": "p1",
		"connectionParticipantId": "p1",
		"viewerRole": "active",
		"viewerCanUseHostControls": true,
		"controlledParticipantIds": ["p1", "p4"],
		"ingredients": [
			{"id": "cheese", "name": "Cheese"},
			{"id": "flour", "name": "Flour"},
			{"id": "herbs", "name": "Herbs"},
			{"id": "vegetables", "name": "Vegetables"},
			{"id": "rice", "name": "Rice"},
			{"id": "beans", "name": "Beans"},
			{"id": "spices", "name": "Spices"},
			{"id": "eggs", "name": "Eggs"}
		],
		"participants": [
			{"id": "p1", "name": "Amina", "role": "active", "kind": "human", "ingredientId": "rice", "connected": true, "depositedInitial": true, "realIngredientStock": 28, "dishCount": 0, "heldFoodPartCount": 0, "currentRecipe": {"name": "Rice Bean Bowl", "missingRequirements": [{"ingredientId": "beans", "missingQty": 1}, {"ingredientId": "vegetables", "missingQty": 1}, {"ingredientId": "spices", "missingQty": 1}, {"ingredientId": "cheese", "missingQty": 1}]}},
			{"id": "p2", "name": "Ben", "role": "active", "kind": "human", "ingredientId": "beans", "connected": true, "depositedInitial": true, "realIngredientStock": 28, "offerableOwnIngredientQty": 2, "dishCount": 0, "heldFoodPartCount": 0, "heldVoucherGroups": [{"ingredientId": "beans", "ownerParticipantId": "p2", "count": 2}, {"ingredientId": "cheese", "ownerParticipantId": "p3", "count": 1}], "currentRecipe": {"name": "Bean Tacos", "missingRequirements": [{"ingredientId": "cheese", "missingQty": 1}, {"ingredientId": "rice", "missingQty": 1}]}},
			{"id": "p3", "name": "Clara", "role": "active", "kind": "human", "ingredientId": "cheese", "connected": true, "depositedInitial": true, "realIngredientStock": 28, "offerableOwnIngredientQty": 2, "dishCount": 0, "heldFoodPartCount": 0, "currentRecipe": {"name": "Cheese Frittata", "missingRequirements": [{"ingredientId": "eggs", "missingQty": 1}]}},
			{"id": "p4", "name": "Diego", "role": "active", "kind": "human", "ingredientId": "vegetables", "connected": true, "depositedInitial": true, "realIngredientStock": 28, "offerableOwnIngredientQty": 2, "dishCount": 0, "heldFoodPartCount": 1, "heldVoucherGroups": [{"ingredientId": "vegetables", "ownerParticipantId": "p4", "count": 2}, {"ingredientId": "beans", "ownerParticipantId": "p2", "count": 1}], "heldFoodPartGroups": [{"dishId": "dish_1", "dishName": "Vegetable Chili", "makerParticipantId": "p4", "unitSingular": "cup", "unitPlural": "cups", "count": 1}], "currentRecipe": {"name": "Veggie Chili", "missingRequirements": [{"ingredientId": "beans", "missingQty": 1}, {"ingredientId": "spices", "missingQty": 1}]}}
		],
		"ownHand": [
			{"id": "rice_1", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
			{"id": "rice_2", "ingredientId": "rice", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
			{"id": "cheese_1", "ingredientId": "cheese", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p1"}}
		],
		"platter": [
			{"id": "beans_1", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}},
			{"id": "beans_2", "ingredientId": "beans", "ownerParticipantId": "p2", "location": {"type": "platter"}},
			{"id": "vegetables_1", "ingredientId": "vegetables", "ownerParticipantId": "p4", "location": {"type": "platter"}}
		],
		"platterFoodParts": [
			{"id": "dish_1_part_1", "dishId": "dish_1", "dishName": "Vegetable Chili", "unitSingular": "cup", "unitPlural": "cups", "makerParticipantId": "p4", "location": {"type": "platter"}},
			{"id": "dish_1_part_2", "dishId": "dish_1", "dishName": "Vegetable Chili", "unitSingular": "cup", "unitPlural": "cups", "makerParticipantId": "p4", "location": {"type": "platter"}}
		],
		"ownFoodParts": [],
		"ownRecipe": {
			"id": "recipe_1",
			"name": "Rice Bean Bowl",
			"requirements": [
				{"id": "req_rice", "ingredientId": "rice", "requiredQty": 2, "redeemedQty": 1, "placedVoucherIds": []},
				{"id": "req_beans", "ingredientId": "beans", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
				{"id": "req_vegetables", "ingredientId": "vegetables", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
				{"id": "req_spices", "ingredientId": "spices", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
				{"id": "req_cheese", "ingredientId": "cheese", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
			]
		},
		"offers": [
			{
				"id": "offer_in",
				"status": "pending",
				"fromParticipantId": "p2",
				"toParticipantId": "p1",
				"offeredVoucherIds": ["beans_3"],
				"offeredVouchers": [{"id": "beans_3", "ingredientId": "beans"}],
				"requested": {"ingredientId": "rice", "quantity": 1}
			},
			{
				"id": "offer_out",
				"status": "pending",
				"fromParticipantId": "p1",
				"toParticipantId": "p3",
				"offeredVoucherIds": ["rice_4"],
				"offeredVouchers": [{"id": "rice_4", "ingredientId": "rice"}],
				"requested": {"ingredientId": "cheese", "quantity": 1}
			}
		]
	}


func _eight_seat_snapshot() -> Dictionary:
	var snapshot := _snapshot_fixture()
	var ingredients := ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
	var names := ["Amina", "Jim_b", "Nia_b", "Luc_b", "Ava_b", "Leo_b", "Mia_b", "Yan_b"]
	var participants: Array = []
	for index in range(ingredients.size()):
		participants.append({
			"id": "p%s" % (index + 1),
			"name": names[index],
			"role": "active",
			"kind": "human" if index == 0 else "bot",
			"ingredientId": ingredients[index],
			"connected": true,
			"depositedInitial": true,
			"openingOfferingsCount": 2,
			"realIngredientStock": 40,
			"offerableOwnIngredientQty": 6,
			"dishCount": 0,
			"heldFoodPartCount": 0
		})
	snapshot["participants"] = participants
	snapshot["viewerParticipantId"] = "p1"
	snapshot["connectionParticipantId"] = "p1"
	snapshot["controlledParticipantIds"] = ["p1"]
	snapshot["currentTurnParticipantId"] = "p1"
	snapshot["ownHand"] = [
		{"id": "cheese_3", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_4", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_5", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_6", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_7", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}},
		{"id": "cheese_8", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p1"}}
	]
	var platter: Array = []
	for index in range(ingredients.size()):
		for card_index in range(1, 3):
			platter.append({
				"id": "%s_%s" % [ingredients[index], card_index],
				"ingredientId": ingredients[index],
				"ownerParticipantId": "p%s" % (index + 1),
				"location": {"type": "platter"}
			})
	snapshot["platter"] = platter
	snapshot["platterFoodParts"] = []
	snapshot["ownRecipe"] = {
		"id": "recipe_cheese_1",
		"name": "Cheese Frittata",
		"requirements": [
			{"id": "req_cheese", "ingredientId": "cheese", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_eggs", "ingredientId": "eggs", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_vegetables", "ingredientId": "vegetables", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_herbs", "ingredientId": "herbs", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_spices", "ingredientId": "spices", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_flour", "ingredientId": "flour", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
		]
	}
	return snapshot


func _controlled_nia_view_snapshot() -> Dictionary:
	var snapshot := _eight_seat_snapshot()
	snapshot["viewerParticipantId"] = "p3"
	snapshot["connectionParticipantId"] = "p1"
	snapshot["controlledParticipantIds"] = ["p3"]
	snapshot["currentTurnParticipantId"] = "p3"
	var participants: Array = snapshot.get("participants", [])
	if participants.size() >= 3:
		var nia: Dictionary = participants[2]
		nia["name"] = "Nia"
		nia["kind"] = "human"
		participants[2] = nia
		snapshot["participants"] = participants
	snapshot["ownHand"] = [
		{"id": "herbs_3", "ingredientId": "herbs", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p3"}},
		{"id": "herbs_4", "ingredientId": "herbs", "ownerParticipantId": "p3", "location": {"type": "hand", "participantId": "p3"}},
		{"id": "cheese_3", "ingredientId": "cheese", "ownerParticipantId": "p1", "location": {"type": "hand", "participantId": "p3"}}
	]
	snapshot["ownFoodParts"] = []
	snapshot["ownRecipe"] = {
		"id": "recipe_herbs_1",
		"name": "Herb Rice Bowl",
		"requirements": [
			{"id": "req_herbs", "ingredientId": "herbs", "requiredQty": 2, "redeemedQty": 1, "placedVoucherIds": []},
			{"id": "req_rice", "ingredientId": "rice", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_eggs", "ingredientId": "eggs", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_cheese", "ingredientId": "cheese", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []},
			{"id": "req_spices", "ingredientId": "spices", "requiredQty": 1, "redeemedQty": 0, "placedVoucherIds": []}
		]
	}
	return snapshot


func _assert_key_visuals_fit_assigned_width(visual: Control, width: float) -> void:
	var visual_rect := visual.get_global_rect()
	_require(visual_rect.size.x <= width + 1.0, "visual table assigned width stays within portrait content width")
	for raw_child in visual.find_children("*", "Control", true, false):
		var child := raw_child as Control
		if child == null or not child.visible:
			continue
		var name := child.name
		if not _is_width_sensitive_visual_node(name):
			continue
		var rect := child.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		_require(rect.position.x >= visual_rect.position.x - 1.0 and rect.end.x <= visual_rect.end.x + 1.0, "%s stays inside visual table width: %s inside %s" % [name, rect, visual_rect])


func _is_width_sensitive_visual_node(name: String) -> bool:
	return name == "BasketBackdrop" \
		or name.begins_with("Participant_") \
		or name.begins_with("BasketSlot_") \
		or name.begins_with("PlatterVoucher_") \
		or name.begins_with("RecipeSlot_")


func _popup_panels_have_expected_dismissal(node: Node) -> bool:
	if node is PopupPanel:
		if bool(node.get("popup_window")):
			return false
	for child in node.get_children():
		if not _popup_panels_have_expected_dismissal(child):
			return false
	return true


func _card_has_texture(node: Node) -> bool:
	if node == null:
		return false
	for raw_child in node.find_children("*", "TextureRect", true, false):
		var texture_rect := raw_child as TextureRect
		if texture_rect != null and texture_rect.texture is Texture2D:
			return true
	return false


func _has_button_text(node: Node, text: String) -> bool:
	for raw_child in node.find_children("*", "Button", true, false):
		var button := raw_child as Button
		if button != null and button.text == text:
			return true
	return false


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
