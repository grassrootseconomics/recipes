## Recipes

Each active player receives a recipe goal. The current MVP is fixed at exactly 8 active seats and exactly 8 generalized ingredients: Cheese, Flour, Herbs, Vegetables, Rice, Beans, Spices, and Eggs. Recipes are based on short, recognizable real-life dish names using those generalized ingredients. The catalog is committed game data, not runtime-random data. Within the catalog, both displayed recipe names and ingredient/quantity requirement signatures must be unique.

Every active participant brings one of the 8 ingredients. Runtime games use the committed 8-player set; they do not randomly choose ingredients at table start.

Every recipe requires exactly 6 total voucher items, because each ingredient has 7 fixed voucher cards and one voucher from each active participant starts in the central platter. Voucher cards are reusable claims on a finite real ingredient stock. The MVP uses a fixed stock of 40 real units per active ingredient owner, enough for full 4-dish catalog demand plus backing for the 7 voucher cards.

Every recipe has 6 item slots and uses 4, 5, or 6 distinct ingredients. Valid recipe quantity shapes are:

- 4 ingredients: 2 + 2 + 1 + 1.
- 5 ingredients: 2 + 1 + 1 + 1 + 1.
- 6 ingredients: 1 + 1 + 1 + 1 + 1 + 1.

The player’s own ingredient must appear in each of their recipes. Every required ingredient must belong to an active participant at the table, so requested recipe ingredients are physically available through that ingredient owner’s vouchers. The catalog contains four recipes per ingredient-set participant: one initial recipe and three followups. When a player prepares a dish, their next recipe must also be generated from ingredients currently active at the table.

A player places matching vouchers into recipe requirements. Placed vouchers are locked. The player then redeems placed vouchers. Redeeming a voucher closes one needed unit of that recipe requirement, decrements the voucher issuer's real ingredient stock by one, and returns the voucher card to the issuer's hand while stock remains. In normal player UI, cooking turns use `Redeem / Pass`: the authoritative rules redeem every useful voucher that was in the acting player's hand when clicked, at most once per voucher. If those redemptions complete the recipe, the dish is prepared automatically before the turn passes. A requirement group is complete when its delivered quantity equals its required quantity.

When every requirement group is complete through `Redeem / Pass`, the ingredients on the final plate transform into a finished dish with exactly 10 food parts. The part name comes from the recipe catalog, such as slices, cups, scoops, pieces, portions, or servings. These parts begin in the maker's inventory, and the player’s dish count increases by one. If the player is still below the dish goal, they receive a new recipe while keeping the same ingredient identity.

The table should show each active player’s finished dish count and the names of the dishes they have prepared.

## Trading And The Central Platter

At the start of the game, every active participant automatically contributes exactly one active voucher into the central platter pool. The client should show this as the opening offering animation, not as a manual per-player button flow. The central platter is visible to everyone.

After depositing, a player may swap 1:1 with the platter by giving one card from their hand and taking one visible card from the platter.

Players can also trade directly with each other. A player zooms out to see the full table, clicks another player, and creates a structured exchange offer. The offer panel shows the offered and requested ingredient cards, plus a public recipe-help summary for the other player: their current recipe name and the ingredient counts still missing after counting recipe progress and useful promise cards already in that player’s hand. There is no free chat in the MVP. Offers can be accepted, refused, or cancelled. Cards in pending offers are locked until the offer resolves.

Players can only be asked for their own ingredient while they still have at least one available voucher for that ingredient in hand and at least one real unit of stock remaining. If a pending offer asks for an ingredient that the recipient no longer has available, the server automatically refuses that offer and returns the offered card to the sender. Clients should not show players with zero available own-ingredient vouchers or zero real stock as offer targets.

After all active players reach the dish goal, the table enters settlement unless everyone is already clear. During settlement, voucher cards and finished dish parts are both 1:1 value assets. A player may give any held card or food part to the platter and take any visible card or food part from the platter. Final clearance requires each active player to have exactly one of their own voucher cards in the central platter, exactly six of their own voucher cards in their own hand, and zero other players' voucher cards in their hand. This also means none of that player's cards can remain in another player's hand. A player with more than one own card in the platter has platter debt; a player with zero own cards in the platter has platter shortfall. Only own cards in the platter count toward platter debt and shortfall, but eating remains locked until all promise cards are fully returned to their owners.

Successful table transactions are public history entries with: turn number, player name, action, counterparty, item out, and item back. MVP transaction actions are `Deposit`, `Swap`, `Settlement Swap`, `Exchange`, `Redeem`, `Prepare`, `Eat`, and `Pass Turn`.

## Bots

New tables start with exactly 8 active seats: the creator plus 7 mixed bot seats. The pre-start lobby shows all 8 seats in a grid with the seat's ingredient image, editable name, and Player/Bot state. Bots count as active participants. Before start, offline local players, online joiners, and host-controlled seats replace available bot seats instead of increasing the active seat count. If all bot seats are already taken, later online joiners become witnesses.

Bot types are:

- `pool_only`: uses only the central platter.
- `barter_only`: trades only with players and bots.
- `mixed`: uses both direct trades and the central platter.

Bots see only legal player information: their own hand, their own recipe, public current-recipe help summaries for other players, the visible central platter, public dish counts, and offers involving them. Bots cannot inspect hidden hands or full hidden recipe state.

During a cooking turn, bots may make useful non-ending moves first: swap with the central platter when it helps their current recipe, respond to offers, and create a legal structured offer. Bots must protect only the number of useful cards still needed for the current recipe, so duplicate cards beyond outstanding recipe demand are true surplus and can be traded before redemption. When a bot reaches the redemption step, it uses the same batch `Redeem / Pass` behavior as a human: every currently redeemable useful card is redeemed with the authoritative rules, a completed recipe is prepared automatically, and then the bot's turn ends. Bot behavior should be deterministic from the table seed.

If an active human player leaves an online table, their seat stays reserved for that same reconnect token so they can come back. No new player can claim an already-started active seat. The host may manually switch a connected or disconnected active player seat to a `mixed` bot at any time. This conversion should require an explicit confirmation in the client because the original player can no longer reclaim that seat after conversion.

## Offline Mode

The game should include an offline mode for Web and Android. Offline mode is single-device pass-and-play: one local controller starts with one human seat and 7 bot seats, can take over bot seats with custom names, and can pass the device between people. Offline mode cannot invite remote players, join hosted tables, use witnesses, or access online matchmaking.

Offline mode should preserve the same recipe, voucher, platter, redemption, preparation, scoring, and eating rules as online play where possible. Bots remain deterministic from the local table seed.

Because the Godot client must remain GDScript-only, offline mode cannot depend on running the Node TypeScript server locally on the device. Offline implementation should either share generated rule fixtures from the server or add a small GDScript rules runtime that mirrors the authoritative online server for local controlled seats and bot play.

Gameplay semantics must stay aligned between online and offline modes. When a rule changes, the online TypeScript implementation, the offline GDScript mirror, generated client fixtures, and parity tests should be updated together.

## Host-Controlled Seats

For hosted online tables, the host should be able to take the place of several active players before the game starts. This supports playtesting, local party facilitation, and filling seats without converting those seats into bots.

A host-controlled seat is still a normal active participant for ingredient identity, vouchers, recipe assignment, scoring, visibility, turn order, and eating. The implementation should track the seat/participant identity separately from the human controller, so one host connection can submit intents for multiple controlled seats while each action is validated as the selected seat.

Host-controlled seats must not weaken hidden-information rules. The host can act for seats they control, but active seats still receive filtered snapshots according to their own participant perspective. Witness visibility remains separate from active seat control.

## Turns

Recipes uses one turn model for both online and offline play: active participants take turns in a circle using deterministic table order.

Only the current active seat can perform turn-gated gameplay actions. The current seat keeps the turn across swaps, offers, settlement, and eating until they explicitly pass. During cooking, `Redeem / Pass` redeems all useful held cards first, automatically prepares the dish if the recipe becomes complete, plays those animations, and then advances to the next active seat.

Online multiplayer must keep active turn and turn advancement server-owned. Offline mode mirrors the same turn semantics locally.

## Winning And Eating

The MVP dish goal is fixed at 4 dishes per active player. Starting stock is fixed at 40 real units per active ingredient owner. The current MVP active participant count is fixed at 8. When a player prepares a dish below the target, they receive a new recipe. When a player reaches the target, they stop receiving new recipes while the rest of the table finishes.

The MVP does not expose a timer in the normal client setup flow. The host can pause or resume the game for everyone. While paused, gameplay actions and bot turns stop. Only the host can stop the game for everyone. When the host stops the game, the player with the most prepared dishes wins.

Winning can also mean that all active players have reached the configured dish goal. Players that have made an equal number of dishes can tie as winners. Before eating, the table must settle the central platter accounts and all outstanding promise-card debts. Eating begins only when every active player has exactly one own card in the platter, exactly six own cards in their own hand, no other players' cards in their hand, and no food parts remain in the platter. A cleared player may eat food parts they hold in their own inventory. Bots should settle accounts, return outstanding promise cards through food-piece swaps, and eat held food parts deterministically. The game is fully complete when all prepared food parts have been eaten.

## Visibility Rules

Active players and bots cannot see other active hands or full hidden recipe state. They can see their own hand, their own recipe, the public platter, public dish counts, incoming and outgoing offers, table status, and public current-recipe help summaries for other players. A recipe-help summary contains only the recipe name and the net ingredient counts still missing after counting recipe progress and useful promise cards already in that player’s hand.

Witnesses can see everything. They can zoom in and out to inspect hands, recipes, the platter, and dishes, but they cannot trade, redeem, prepare, score, or eat before the eating phase.

## Software Architecture

The game will be built in a new repository:

`/home/wor/src/recipes`

The Godot client will be GDScript-only for Web and Android compatibility. The Android package id is:

`org.grassecon.recipes`

Online multiplayer uses one hosted authoritative Node TypeScript server. The server owns all online game state: tables, invite codes, roles, ingredient sets, card locations, recipes, trades, platter state, redemption, dish preparation, bots, timers, visibility filtering, scoring, and eating phase.

Online clients send intents only. The server validates every action and sends filtered snapshots back to each client. Offline mode is separate and local-only, with no remote multiplayer or witness mode.

The design should draw from:

- `/home/wor/src/mycofig` for visual and social-table inspiration.
- `/home/wor/src/cellular` for Web and Android export lessons.
- `/home/wor/src/ge/clc` conceptually for voucher, pool, redemption, receipt, and settlement semantics.

The MVP does not include blockchain, wallets, accounts, free chat, borrowing, or a global leaderboard.

## Required Project Docs

The repo should include:

- `AGENTS.md`: durable implementation rules for future agents and contributors.
- `PLAN.md`: a progress checklist for implementation phases.
- `DESCRIPTION.md`: this narrative design description.

## Testing Expectations

The server should include focused unit and integration tests for:

- 8 unique generalized ingredients with descriptions and image paths.
- one committed 8-player ingredient set.
- 7 fixed vouchers per ingredient.
- new tables start with exactly 8 active participants by default.
- start allowed immediately with exactly 8 active participants.
- joining before start replaces available bot seats; joining after all bot seats are claimed makes a witness.
- running joins become witnesses.
- host-controlled seats can claim available bot seats before start.
- recipe total required quantity equals 6.
- recipe quantity shape is 2+2+1+1, 2+1+1+1+1, or 1+1+1+1+1+1.
- own ingredient can appear in a player’s recipe.
- recipe quantities greater than one are supported.
- recipe requirement ingredients are owned by active table participants.
- new recipes after preparing a dish obey the same table-valid ingredient and quantity rules.
- all quantities must be redeemed before preparation.
- `Redeem / Pass` redeems each useful initially held voucher at most once, records redemptions, automatically prepares a completed recipe, then advances the round-robin turn.
- total vouchers per ingredient owner always equals 7.
- active vouchers match physical ingredient availability.
- default stock is 40 real ingredient units per active ingredient owner.
- fixed stock is assigned to each active ingredient owner at start.
- full catalog demand plus 7 voucher-backing units for the fixed 4-dish goal never exceeds per-owner real stock.
- redeeming a voucher decrements issuer real stock.
- redeemed vouchers return to the issuer's hand while stock remains.
- zero-stock vouchers remain visible for accounting but cannot be used as live claims for recipe placement, exchange, deposit, or platter swaps.
- the fixed dish goal is 4.
- platter deposit and 1:1 swaps are atomic.
- structured offers lock cards and resolve correctly.
- offer popups show ingredient cards plus public current-recipe help summaries without exposing hidden hands or full hidden recipe state.
- players with no available own-ingredient vouchers cannot receive new offers for that ingredient, and impossible pending offers are auto-refused.
- successful deposits, swaps, exchanges, and redemptions are recorded in transaction history.
- host-controlled seats can submit valid actions for multiple active participants without changing those participant identities.
- round-robin turns enforce active-seat order and advance deterministically.
- active players cannot see other hands.
- bots cannot see hidden hands.
- witnesses can see all hands.
- bot type restrictions are enforced.
- bots use one batch redemption/pass intent at the end of a cooking turn, protect only useful cards still needed by count, and may trade duplicate surplus cards before redemption.
- only the host can stop the game for everyone.
- disconnected active humans stay reclaimable until the host manually converts them to `mixed` bots.
- host pause blocks gameplay actions and bot turns.
- prepared dishes create exactly 10 named food parts from the recipe catalog.
- settlement swaps allow any held card or food part to be swapped 1:1 with any platter card or food part.
- platter clearance requires exactly one own card in the platter for every active player.
- full settlement clearance also requires each active player to hold exactly six own cards, hold zero foreign cards, and have zero own cards held by other players before eating.
- players cannot eat until cleared, and can only eat food parts they hold.
- generated client fixtures match the server recipe catalog and shared rule constants.
- offline smoke/parity coverage exercises the same intent names, fixture data, hidden-information boundaries, turn mode defaults, bot-seat takeover, deposits, swaps, offers, redemption, preparation, settlement, eating, and fixed stock/dish-goal assumptions as online play.
