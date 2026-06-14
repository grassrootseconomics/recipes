## Recipes

Each active player receives a recipe goal. Recipes are based on common dishes from around the world where possible, using committed player-count ingredient sets generated once from the 20 common ingredients. Catalog dish targets are playable game targets, not exhaustive real-world recipe ingredient lists, so they always contain 3, 4, or 6 ingredients. A known dish name can only be used when the generated requirements match that dish target; otherwise the generated recipe must receive a distinct short name that reflects the actual required ingredients. Within each player-count catalog, both displayed recipe names and ingredient/quantity requirement signatures must be unique.

For each supported active participant count from 7 through 20, the catalog contains one fixed ingredient set with `N` unique ingredients. Runtime games use the committed set for their active participant count; they do not randomly choose ingredients at table start.

Every recipe requires exactly 6 total voucher items, because each ingredient has 7 fixed voucher cards and one voucher from each active participant starts in the central platter. Voucher cards are reusable claims on a finite real ingredient stock. The host can configure `Stock` before the game starts; the default is 30 real units per active ingredient owner.

Valid recipe quantity shapes are:

- 3 ingredients: 2 + 2 + 2.
- 4 ingredients: 2 + 2 + 1 + 1.
- 6 ingredients: 1 + 1 + 1 + 1 + 1 + 1.

The player’s own ingredient must appear in each of their recipes. Every required ingredient must belong to an active participant at the table, so requested recipe ingredients are physically available through that ingredient owner’s vouchers. The catalog contains four recipes per ingredient-set participant: one initial recipe and three followups. When a player prepares a dish, their next recipe must also be generated from ingredients currently active at the table.

A player places matching vouchers into recipe requirements. Placed vouchers are locked. The player then redeems placed vouchers one by one. Redeeming a voucher closes one needed unit of that recipe requirement, decrements the voucher issuer's real ingredient stock by one, and returns the voucher card to the issuer's hand while stock remains. A requirement group is complete when its delivered quantity equals its required quantity.

When every requirement group is complete, the player can click `Prepare`. The ingredients on their final plate transform into a finished dish. The dish moves to the center of the table, and the player’s dish count increases by one. The player then receives a new recipe while keeping the same ingredient identity.

The table should show each active player’s finished dish count and the names of the dishes they have prepared.

## Trading And The Central Platter

At the start of the game, every active participant must deposit exactly one active voucher into the central platter pool. The central platter is visible to everyone.

After depositing, a player may swap 1:1 with the platter by giving one card from their hand and taking one visible card from the platter.

Players can also trade directly with each other. A player zooms out to see the full table, clicks another player, and creates a structured exchange offer. There is no free chat in the MVP. Offers can be accepted, refused, or cancelled. Cards in pending offers are locked until the offer resolves.

Players can only be asked for their own ingredient while they still have at least one available voucher for that ingredient in hand and at least one real unit of stock remaining. If a pending offer asks for an ingredient that the recipient no longer has available, the server automatically refuses that offer and returns the offered card to the sender. Clients should not show players with zero available own-ingredient vouchers or zero real stock as offer targets.

Successful table transactions are public history entries with: player name, action, counterparty, item out, and item back. MVP transaction actions are `Deposit`, `Swap`, `Exchange`, and `Redeem`.

## Bots

The host can add bots before the game starts. Bots count as active participants.

Bot types are:

- `pool_only`: uses only the central platter.
- `barter_only`: trades only with players and bots.
- `mixed`: uses both direct trades and the central platter.

Bots see only legal player information: their own hand, their own recipe, the visible central platter, public dish counts, and offers involving them. Bots cannot inspect hidden hands.

Bots first place and redeem useful vouchers already in their own hand for their current recipe. For example, if a bot has rice in hand and its recipe needs rice x2, it should place and redeem two rice vouchers before pursuing swaps or offers. Bots then try to complete recipes, prepare dishes immediately when ready, protect useful cards, and trade away cards that do not help their current recipe. Bot behavior should be deterministic from the table seed.

If an active human player leaves an online table, their seat stays reserved for that same reconnect token so they can come back. No new player can claim an already-started active seat. The host may manually switch a connected or disconnected active player seat to a `mixed` bot at any time. This conversion should require an explicit confirmation in the client because the original player can no longer reclaim that seat after conversion.

## Offline Mode

The game should include an offline mode for Web and Android. Offline mode is single-device and bot-only: one local human player can play with bots, but cannot invite other human players, join hosted tables, use witnesses, or access online matchmaking.

Offline mode should preserve the same recipe, voucher, platter, redemption, preparation, scoring, and eating rules as online play where possible. Bots remain deterministic from the local table seed.

Because the Godot client must remain GDScript-only, offline mode cannot depend on running the Node TypeScript server locally on the device. Offline implementation should either share generated rule fixtures from the server or add a small GDScript rules runtime that mirrors the authoritative online server for bot-only play.

## Host-Controlled Seats

For hosted online tables, the host should be able to take the place of several active players before the game starts. This supports playtesting, local party facilitation, and filling seats without converting those seats into bots.

A host-controlled seat is still a normal active participant for ingredient identity, vouchers, recipe assignment, scoring, visibility, turn order, and eating. The implementation should track the seat/participant identity separately from the human controller, so one host connection can submit intents for multiple controlled seats while each action is validated as the selected seat.

Host-controlled seats must not weaken hidden-information rules. The host can act for seats they control, but active seats still receive filtered snapshots according to their own participant perspective. Witness visibility remains separate from active seat control.

## Turn Modes

The host should choose the table turn mode before the game starts.

- `round_robin`: active participants take turns in a circle using deterministic table order. Only the current active seat can perform turn-gated gameplay actions, then the turn passes to the next active seat or bot.
- `market`: active participants may act asynchronously whenever an action is legal. Offers, platter swaps, placement, redemption, preparation, bot turns, and eating are resolved by server validation without a strict active-seat turn gate.

Online multiplayer must keep turn mode, active turn, and turn advancement server-owned. Offline bot-only mode should mirror the same turn-mode semantics where feasible. The current MVP behavior is closest to `market` mode until explicit round-robin enforcement is implemented.

## Winning And Eating

The host can set a dish goal from 1 to 4 before the game starts; the default goal is 4 dishes per active player. The host can also set starting `Stock`; the server must reject game start if the configured stock is below the catalog demand for the active participant count and dish goal. When a player prepares a dish below the target, they receive a new recipe. When a player reaches the target, they stop receiving new recipes while the rest of the table finishes.

The host can set a timer and pause or resume the game for everyone. While paused, gameplay actions and bot turns stop, and a running timer is paused rather than expiring in the background. Only the host can stop the game for everyone. When the timer ends, or when the host stops the game, the player with the most prepared dishes wins.

Winning can also mean that all active players have reached the configured dish goal. Players that have made an equal number of dishes can tie as winners. The winner gets the first bite. After the first bite, everyone can click prepared dishes in the center of the table to eat. Each click removes a bite. Each player can take up to 3 bites from each dish. The host can take any remaining bites, and the final non-host player still biting a dish can clear that dish once all other active non-host players have reached their 3-bite limit. Bots should take legal bites from deterministic pseudo-random available dishes during the eating phase. The game is fully complete when all prepared dishes have been eaten.

## Visibility Rules

Active players and bots cannot see other active hands. They can see their own hand, their own recipe, the public platter, public dish counts, incoming and outgoing offers, and table status.

Witnesses can see everything. They can zoom in and out to inspect hands, recipes, the platter, and dishes, but they cannot trade, redeem, prepare, score, or eat before the eating phase.

## Software Architecture

The game will be built in a new repository:

`/home/wor/src/recipes`

The Godot client will be GDScript-only for Web and Android compatibility. The Android package id is:

`org.grassecon.recipes`

Online multiplayer uses one hosted authoritative Node TypeScript server. The server owns all online game state: tables, invite codes, roles, ingredient sets, card locations, recipes, trades, platter state, redemption, dish preparation, bots, timers, visibility filtering, scoring, and eating phase.

Online clients send intents only. The server validates every action and sends filtered snapshots back to each client. Offline mode is separate and local-only, with no human multiplayer or witness mode.

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

- 20 unique ingredients and one committed ingredient set per active participant count.
- 7 fixed vouchers per ingredient.
- start blocked below 7 active participants.
- start allowed from 7 to 20 active participants.
- running joins become witnesses.
- host active/witness toggle before start.
- recipe total required quantity equals 6.
- recipe quantity shape is 2+2+2, 2+2+1+1, or 1+1+1+1+1+1.
- own ingredient can appear in a player’s recipe.
- recipe quantities greater than one are supported.
- recipe requirement ingredients are owned by active table participants.
- new recipes after preparing a dish obey the same table-valid ingredient and quantity rules.
- all quantities must be redeemed before preparation.
- total vouchers per ingredient owner always equals 7.
- active vouchers match physical ingredient availability.
- default stock is 30 real ingredient units per active ingredient owner.
- host-configured stock is assigned to each active ingredient owner at start.
- full catalog demand for the configured dish goal never exceeds per-owner real stock.
- redeeming a voucher decrements issuer real stock.
- redeemed vouchers return to the issuer's hand while stock remains.
- the default dish goal is 4, configurable by the host from 1 to 4 before start.
- platter deposit and 1:1 swaps are atomic.
- structured offers lock cards and resolve correctly.
- players with no available own-ingredient vouchers cannot receive new offers for that ingredient, and impossible pending offers are auto-refused.
- successful deposits, swaps, exchanges, and redemptions are recorded in transaction history.
- host-controlled seats can submit valid actions for multiple active participants without changing those participant identities.
- `round_robin` mode enforces active-seat order and advances turns deterministically.
- `market` mode allows asynchronous legal actions without strict active-seat order.
- active players cannot see other hands.
- bots cannot see hidden hands.
- witnesses can see all hands.
- bot type restrictions are enforced.
- bots redeem useful vouchers already in their own hand before swaps or offers.
- only the host can stop the game for everyone.
- disconnected active humans stay reclaimable until the host manually converts them to `mixed` bots.
- host pause blocks gameplay actions and bot turns, and pauses running timers.
- winner(s) take first bite, then everyone can eat. (click to bite) say 10 bites per dish finish them
