import {
  DEFAULT_TARGET_DISH_COUNT,
  DISH_PARTS_PER_DISH,
  INGREDIENTS,
  MAX_TARGET_DISH_COUNT,
  MAX_ACTIVE_PARTICIPANTS,
  MAX_STOCK_PER_INGREDIENT,
  MIN_TARGET_DISH_COUNT,
  MIN_ACTIVE_PARTICIPANTS,
  MIN_STOCK_PER_INGREDIENT,
  REAL_UNITS_PER_INGREDIENT,
  VOUCHERS_PER_INGREDIENT
} from "./constants.js";
import { ingredientsForPlayerCount, maxIngredientDemandForPlayerCount } from "./recipeCatalog.js";
import { generateRecipe } from "./recipes.js";
import type {
  AggregatePlatterAssetRef,
  BotType,
  DishPart,
  Intent,
  Offer,
  Participant,
  ParticipantRole,
  PlatterAssetRef,
  Table,
  TransactionAction,
  Voucher
} from "./types.js";

const GENERATED_NAMES = [
  "Amina",
  "Ben",
  "Clara",
  "Diego",
  "Esme",
  "Farah",
  "Gita",
  "Hugo",
  "Iris",
  "Jules",
  "Kofi",
  "Lina",
  "Mika",
  "Nora",
  "Omar",
  "Pia",
  "Quinn",
  "Ravi",
  "Sana",
  "Theo"
] as const;

const GENERIC_HUMAN_NAMES = new Set(["", "host", "player"]);
const GENERIC_BOT_NAMES = new Set(["", "bot", "pool bot", "barter bot", "mixed bot", "pool_only", "barter_only", "mixed"]);

type ResolvedPlatterAsset = { kind: "voucher"; value: Voucher } | { kind: "dish_part"; value: DishPart };

export class GameError extends Error {
  constructor(message: string, public readonly code = "game_error") {
    super(message);
  }
}

export function createEmptyTable(code: string, seed: string, hostName: string, seatToken: string): Table {
  const host: Participant = {
    id: "p1",
    name: resolveHumanName([], hostName, 1),
    kind: "human",
    role: "active",
    isHost: true,
    seatToken,
    dishCount: 0,
    depositedInitial: false,
    connected: true
  };

  return {
    code,
    seed,
    version: 0,
    phase: "lobby",
    paused: false,
    hostParticipantId: host.id,
    participants: { [host.id]: host },
    participantOrder: [host.id],
    vouchers: {},
    recipes: {},
    offers: {},
    dishes: {},
    dishParts: {},
    transactionHistory: [],
    winnerParticipantIds: [],
    targetDishCount: DEFAULT_TARGET_DISH_COUNT,
    stockPerIngredient: REAL_UNITS_PER_INGREDIENT,
    turn: 0,
    nextId: 2
  };
}

export function addHumanParticipant(table: Table, name: string, seatToken: string, asWitness = false): Participant {
  const role: ParticipantRole = table.phase === "lobby" && !asWitness ? "active" : "witness";
  const participant = createParticipant(table, resolveHumanName(existingNames(table), name, table.participantOrder.length + 1), "human", role, seatToken);
  table.participants[participant.id] = participant;
  table.participantOrder.push(participant.id);
  table.turn += 1;
  table.version += 1;
  return participant;
}

export function disconnectParticipant(table: Table, participant: Participant): boolean {
  if (participant.kind !== "human") {
    return false;
  }

  const wasConnected = participant.connected;
  participant.connected = false;
  if (wasConnected) {
    table.version += 1;
  }
  return wasConnected;
}

export function applyIntent(table: Table, actorParticipantId: string, intent: Intent): void {
  const before = cloneTable(table);
  const actor = requireParticipant(table, actorParticipantId);
  try {
    if (
      table.paused &&
      intent.type !== "set_pause" &&
      intent.type !== "convert_to_bot" &&
      intent.type !== "leave_table" &&
      intent.type !== "close_table" &&
      intent.type !== "reset_table"
    ) {
      throw new GameError("The table is paused.", "table_paused");
    }
    table.turn += 1;

    switch (intent.type) {
      case "leave_table":
        leaveTable(table, actor);
        break;
      case "close_table":
        closeTable(table, actor);
        break;
      case "reset_table":
        resetTable(table, actor);
        break;
      case "set_role":
        setRole(table, actor, intent.participantId, intent.role);
        break;
      case "add_bot":
        addBot(table, actor, intent.name, intent.botType);
        break;
      case "convert_to_bot":
        convertParticipantToBot(table, actor, intent.participantId, intent.botType ?? "mixed");
        break;
      case "set_timer":
        setTimer(table, actor, intent.seconds);
        break;
      case "set_target_dish_count":
        setTargetDishCount(table, actor, intent.count);
        break;
      case "set_stock":
        setStock(table, actor, intent.count);
        break;
      case "set_pause":
        setPaused(table, actor, intent.paused);
        break;
      case "start":
        startTable(table, actor);
        break;
      case "stop":
        stopTable(table, actor);
        break;
      case "deposit":
        depositToPlatter(table, actor, intent.voucherId);
        break;
      case "deposit_ingredient":
        depositIngredientToPlatter(table, actor, intent.ingredientId);
        break;
      case "platter_swap":
        swapWithPlatter(table, actor, intent.giveVoucherId, intent.takeVoucherId);
        break;
      case "platter_swap_ingredient":
        swapIngredientWithPlatter(table, actor, intent.giveIngredientId, intent.takeIngredientId, intent.quantity ?? 1);
        break;
      case "platter_asset_swap":
        swapPlatterAssets(table, actor, intent.give, intent.take);
        break;
      case "platter_asset_swap_aggregate":
        swapAggregatePlatterAssets(table, actor, intent.give, intent.take, intent.quantity ?? 1);
        break;
      case "create_offer":
        createOffer(table, actor, intent.toParticipantId, intent.offeredVoucherIds, intent.requested);
        break;
      case "respond_offer":
        respondOffer(table, actor, intent.offerId, intent.response, intent.voucherIds ?? []);
        break;
      case "cancel_offer":
        cancelOffer(table, actor, intent.offerId);
        break;
      case "place_voucher":
        placeVoucher(table, actor, intent.voucherId, intent.requirementId);
        break;
      case "redeem_voucher":
        redeemVoucher(table, actor, intent.voucherId);
        break;
      case "redeem_from_hand":
        redeemVoucherFromHand(table, actor, intent.voucherId, intent.requirementId);
        break;
      case "prepare":
        prepareDish(table, actor);
        break;
      case "bite":
        biteDish(table, actor, intent.dishId);
        break;
      default:
        assertNever(intent);
    }
    autoRefuseUnavailableOffers(table);
    table.version += 1;
  } catch (error) {
    restoreTable(table, before);
    throw error;
  }
}

export function expireTimer(table: Table, nowMs = Date.now()): boolean {
  if (!table.timer?.endsAtMs || table.timer.expiredAtMs) {
    return false;
  }
  if (table.paused) {
    return false;
  }
  if (table.phase !== "deposit" && table.phase !== "playing") {
    return false;
  }
  if (table.timer.endsAtMs > nowMs) {
    return false;
  }
  table.turn += 1;
  table.timer.expiredAtMs = nowMs;
  enterEndgamePhase(table);
  table.version += 1;
  return true;
}

export function activeParticipants(table: Table): Participant[] {
  return table.participantOrder
    .map((participantId) => table.participants[participantId])
    .filter((participant): participant is Participant => Boolean(participant) && participant.role === "active");
}

export function handVoucherIds(table: Table, participantId: string): string[] {
  return Object.values(table.vouchers)
    .filter((voucher) => voucher.location.type === "hand" && voucher.location.participantId === participantId)
    .map((voucher) => voucher.id)
    .sort();
}

export function platterVoucherIds(table: Table): string[] {
  return Object.values(table.vouchers)
    .filter((voucher) => voucher.location.type === "platter")
    .map((voucher) => voucher.id)
    .sort();
}

export function platterDishPartIds(table: Table): string[] {
  return Object.values(table.dishParts ?? {})
    .filter((part) => part.location.type === "platter")
    .map((part) => part.id)
    .sort();
}

export function inventoryDishPartIds(table: Table, participantId: string): string[] {
  return Object.values(table.dishParts ?? {})
    .filter((part) => part.location.type === "inventory" && part.location.participantId === participantId)
    .map((part) => part.id)
    .sort();
}

export interface PlatterAccount {
  participantId: string;
  ownCardsInPlatter: number;
  platterDebt: number;
  platterShortfall: number;
  cleared: boolean;
}

export function platterAccountForParticipant(table: Table, participantId: string): PlatterAccount {
  const ownCardsInPlatter = Object.values(table.vouchers).filter(
    (voucher) => voucher.ownerParticipantId === participantId && voucher.location.type === "platter"
  ).length;
  return {
    participantId,
    ownCardsInPlatter,
    platterDebt: Math.max(0, ownCardsInPlatter - 1),
    platterShortfall: Math.max(0, 1 - ownCardsInPlatter),
    cleared: ownCardsInPlatter === 1
  };
}

export function allActiveParticipantsCleared(table: Table): boolean {
  return activeParticipants(table).every((participant) => platterAccountForParticipant(table, participant.id).cleared);
}

export function holdingVoucherIdsForIngredientOwner(table: Table, ownerParticipantId: string): string[] {
  return Object.values(table.vouchers)
    .filter((voucher) => voucher.ownerParticipantId === ownerParticipantId && voucher.location.type === "holding")
    .map((voucher) => voucher.id)
    .sort();
}

export function vouchersForIngredientOwner(table: Table, ownerParticipantId: string): Voucher[] {
  return Object.values(table.vouchers).filter((voucher) => voucher.ownerParticipantId === ownerParticipantId);
}

export function getUsefulRequirementIds(table: Table, participantId: string, ingredientId: string): string[] {
  const recipe = table.recipes[participantId];
  if (!recipe) {
    return [];
  }
  return recipe.requirements
    .filter((requirement) => {
      const outstanding = requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length;
      return requirement.ingredientId === ingredientId && outstanding > 0;
    })
    .map((requirement) => requirement.id);
}

export function invariantVoucherCounts(table: Table): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const voucher of Object.values(table.vouchers)) {
    counts[voucher.ownerParticipantId] = (counts[voucher.ownerParticipantId] ?? 0) + 1;
  }
  return counts;
}

function existingNames(table: Table): string[] {
  return Object.values(table.participants).map((participant) => participant.name);
}

function resolveHumanName(existing: string[], requestedName: string, ordinal: number): string {
  const trimmed = requestedName.trim();
  const base = GENERIC_HUMAN_NAMES.has(trimmed.toLowerCase()) ? generatedBaseName(ordinal) : trimmed;
  return uniqueName(existing, base);
}

function resolveBotName(existing: string[], requestedName: string, ordinal: number, botType: BotType): string {
  const trimmed = requestedName.trim();
  const lower = trimmed.toLowerCase();
  const base = GENERIC_BOT_NAMES.has(lower) ? generatedBaseName(ordinal) : trimmed.replace(/_(pool|barter|mix|mixed)_bot$/i, "").replace(/_?bot$/i, "");
  return uniqueName(existing, `${base}${botNameSuffix(botType)}`);
}

function botNameSuffix(botType: BotType): string {
  switch (botType) {
    case "pool_only":
      return "_pool_bot";
    case "barter_only":
      return "_barter_bot";
    case "mixed":
      return "_mix_bot";
    default:
      assertNever(botType);
  }
}

function generatedBaseName(ordinal: number): string {
  return GENERATED_NAMES[(Math.max(1, ordinal) - 1) % GENERATED_NAMES.length];
}

function uniqueName(existing: string[], baseName: string): string {
  const existingSet = new Set(existing);
  if (!existingSet.has(baseName)) {
    return baseName;
  }
  for (let suffix = 2; suffix < 100; suffix += 1) {
    const candidate = `${baseName}_${suffix}`;
    if (!existingSet.has(candidate)) {
      return candidate;
    }
  }
  throw new GameError("Could not allocate participant name.", "name_allocation_failed");
}

function createParticipant(
  table: Table,
  name: string,
  kind: "human" | "bot",
  role: ParticipantRole,
  seatToken: string,
  botType?: BotType
): Participant {
  const id = `p${table.nextId}`;
  table.nextId += 1;
  return {
    id,
    name,
    kind,
    role,
    isHost: false,
    seatToken,
    botType,
    dishCount: 0,
    depositedInitial: false,
    connected: kind === "human"
  };
}

function leaveTable(table: Table, actor: Participant): void {
  if (actor.isHost) {
    throw new GameError("The host must close the table instead of leaving.", "host_only");
  }
  if (actor.kind !== "human") {
    throw new GameError("Only human participants can leave a table.", "human_only");
  }
  cancelPendingOffersForParticipant(table, actor.id);
  actor.role = "witness";
  actor.connected = false;
  actor.seatToken = `left:${actor.id}:${table.turn}`;
}

function closeTable(table: Table, actor: Participant): void {
  requireHost(actor);
  cancelAllPendingOffers(table);
  table.phase = "complete";
  table.paused = false;
  clearTimerRuntime(table);
}

function resetTable(table: Table, actor: Participant): void {
  requireHost(actor);
  cancelAllPendingOffers(table);
  table.phase = "lobby";
  table.paused = false;
  table.vouchers = {};
  table.recipes = {};
  table.offers = {};
  table.dishes = {};
  table.dishParts = {};
  table.transactionHistory = [];
  table.winnerParticipantIds = [];
  clearTimerRuntime(table);
  for (const participant of Object.values(table.participants)) {
    participant.dishCount = 0;
    participant.depositedInitial = false;
    delete participant.ingredientId;
    delete participant.realIngredientStock;
  }
}

function setRole(table: Table, actor: Participant, participantId: string, role: ParticipantRole): void {
  requireHost(actor);
  requireLobby(table);
  const participant = requireParticipant(table, participantId);
  if (participant.isHost && role !== "active" && activeParticipants(table).length <= 1) {
    participant.role = role;
    return;
  }
  participant.role = role;
  if (activeParticipants(table).length > MAX_ACTIVE_PARTICIPANTS) {
    participant.role = "witness";
    throw new GameError(`At most ${MAX_ACTIVE_PARTICIPANTS} active participants are allowed.`, "too_many_active");
  }
}

function addBot(table: Table, actor: Participant, name = "Bot", botType: BotType): Participant {
  requireHost(actor);
  requireLobby(table);
  if (activeParticipants(table).length >= MAX_ACTIVE_PARTICIPANTS) {
    throw new GameError(`At most ${MAX_ACTIVE_PARTICIPANTS} active participants are allowed.`, "too_many_active");
  }
  const participant = createParticipant(
    table,
    resolveBotName(existingNames(table), name, table.participantOrder.length + 1, botType),
    "bot",
    "active",
    `bot:${table.nextId}`,
    botType
  );
  table.participants[participant.id] = participant;
  table.participantOrder.push(participant.id);
  return participant;
}

function convertParticipantToBot(table: Table, actor: Participant, participantId: string, botType: BotType): Participant {
  requireHost(actor);
  const participant = requireParticipant(table, participantId);
  if (participant.isHost) {
    throw new GameError("The host seat cannot be converted to a bot.", "host_required");
  }
  if (participant.kind === "bot") {
    throw new GameError("Participant is already a bot.", "already_bot");
  }
  if (participant.role !== "active") {
    throw new GameError("Only active player seats can become bots.", "active_only");
  }
  participant.kind = "bot";
  participant.botType = botType;
  participant.connected = false;
  participant.name = resolveBotName(existingNames(table), participant.name, table.participantOrder.indexOf(participant.id) + 1, botType);
  participant.seatToken = `bot:${participant.id}:converted`;
  return participant;
}

function setTimer(table: Table, actor: Participant, seconds: number | null): void {
  requireHost(actor);
  requireLobby(table);
  if (seconds === null) {
    delete table.timer;
    return;
  }
  if (!Number.isInteger(seconds) || seconds <= 0) {
    throw new GameError("Timer seconds must be a positive integer.", "invalid_timer");
  }
  table.timer = { seconds };
}

function setTargetDishCount(table: Table, actor: Participant, count: number): void {
  requireHost(actor);
  requireLobby(table);
  if (!Number.isInteger(count) || count < MIN_TARGET_DISH_COUNT || count > MAX_TARGET_DISH_COUNT) {
    throw new GameError(
      `Target dish count must be between ${MIN_TARGET_DISH_COUNT} and ${MAX_TARGET_DISH_COUNT}.`,
      "invalid_target_dish_count"
    );
  }
  table.targetDishCount = count;
}

function setStock(table: Table, actor: Participant, count: number): void {
  requireHost(actor);
  requireLobby(table);
  if (!Number.isInteger(count) || count < MIN_STOCK_PER_INGREDIENT || count > MAX_STOCK_PER_INGREDIENT) {
    throw new GameError(
      `Stock must be between ${MIN_STOCK_PER_INGREDIENT} and ${MAX_STOCK_PER_INGREDIENT}.`,
      "invalid_stock"
    );
  }
  table.stockPerIngredient = count;
}

function setPaused(table: Table, actor: Participant, paused: boolean): void {
  requireHost(actor);
  if (table.phase === "complete" && paused) {
    throw new GameError("A complete table cannot be paused.", "invalid_phase");
  }
  if (table.paused === paused) {
    return;
  }
  table.paused = paused;
  if (paused) {
    pauseTimer(table);
  } else {
    resumeTimer(table);
  }
}

function startTable(table: Table, actor: Participant): void {
  requireHost(actor);
  requireLobby(table);
  const active = activeParticipants(table);
  if (active.length < MIN_ACTIVE_PARTICIPANTS) {
    throw new GameError(`Start requires at least ${MIN_ACTIVE_PARTICIPANTS} active participants.`, "too_few_active");
  }
  if (active.length > MAX_ACTIVE_PARTICIPANTS) {
    throw new GameError(`Start allows at most ${MAX_ACTIVE_PARTICIPANTS} active participants.`, "too_many_active");
  }
  const requiredStock = maxIngredientDemandForPlayerCount(active.length, table.targetDishCount);
  if (table.stockPerIngredient < requiredStock) {
    throw new GameError(
      `Stock must be at least ${requiredStock} for ${active.length} active participants and ${table.targetDishCount} dishes.`,
      "stock_too_low"
    );
  }

  table.phase = "deposit";
  table.paused = false;
  table.vouchers = {};
  table.recipes = {};
  table.offers = {};
  table.dishes = {};
  table.dishParts = {};
  table.transactionHistory = [];
  table.winnerParticipantIds = [];
  if (table.timer) {
    const nowMs = Date.now();
    table.timer.startedAtTurn = table.turn;
    table.timer.startedAtMs = nowMs;
    table.timer.endsAtMs = nowMs + table.timer.seconds * 1000;
    delete table.timer.expiredAtMs;
  }

  const ingredientOrder = ingredientsForPlayerCount(active.length);
  active.forEach((participant, index) => {
    const ingredient = ingredientOrder[index];
    if (!ingredient) {
      throw new GameError("Missing ingredient assignment.", "ingredient_assignment_failed");
    }
    participant.ingredientId = ingredient.id;
    participant.realIngredientStock = table.stockPerIngredient;
    participant.dishCount = 0;
    participant.depositedInitial = false;
    createParticipantVouchers(table, participant);
  });

  for (const participant of active) {
    table.recipes[participant.id] = generateRecipe(table, participant.id);
  }
}

function stopTable(table: Table, actor: Participant): void {
  requireHost(actor);
  if (table.phase === "lobby" || table.phase === "complete") {
    throw new GameError("Only a running table can be stopped.", "invalid_phase");
  }
  enterSettlementPhase(table);
}

function pauseTimer(table: Table, nowMs = Date.now()): void {
  if (!table.timer?.endsAtMs || table.timer.expiredAtMs) {
    return;
  }
  table.timer.pausedRemainingMs = Math.max(0, table.timer.endsAtMs - nowMs);
  delete table.timer.endsAtMs;
}

function resumeTimer(table: Table, nowMs = Date.now()): void {
  if (!table.timer || table.timer.pausedRemainingMs === undefined || table.timer.expiredAtMs) {
    return;
  }
  table.timer.endsAtMs = nowMs + table.timer.pausedRemainingMs;
  delete table.timer.pausedRemainingMs;
}

function clearTimerRuntime(table: Table): void {
  if (!table.timer) {
    return;
  }
  delete table.timer.startedAtTurn;
  delete table.timer.startedAtMs;
  delete table.timer.endsAtMs;
  delete table.timer.expiredAtMs;
  delete table.timer.pausedRemainingMs;
}

function depositToPlatter(table: Table, actor: Participant, voucherId: string): void {
  requirePhase(table, "deposit");
  requireActive(actor);
  if (actor.depositedInitial) {
    throw new GameError("Participant already deposited.", "already_deposited");
  }
  const voucher = requireVoucher(table, voucherId);
  requireVoucherInHand(voucher, actor.id);
  voucher.location = { type: "platter" };
  actor.depositedInitial = true;
  recordTransaction(table, actor, "Deposit", "Platter", ingredientName(voucher.ingredientId), "None");
  if (activeParticipants(table).every((participant) => participant.depositedInitial)) {
    table.phase = "playing";
  }
}

function depositIngredientToPlatter(table: Table, actor: Participant, ingredientId?: string): void {
  const requestedIngredientId = ingredientId ?? actor.ingredientId;
  const voucher = Object.values(table.vouchers)
    .filter((candidate) => candidate.location.type === "hand" && candidate.location.participantId === actor.id)
    .filter((candidate) => !requestedIngredientId || candidate.ingredientId === requestedIngredientId)
    .sort((left, right) => left.id.localeCompare(right.id))[0];
  if (!voucher) {
    throw new GameError("No matching voucher is available to deposit.", "voucher_not_in_hand");
  }
  depositToPlatter(table, actor, voucher.id);
}

function swapWithPlatter(table: Table, actor: Participant, giveVoucherId: string, takeVoucherId: string): void {
  requirePhase(table, "playing");
  requireActive(actor);
  ensureBotCanUsePool(actor);
  const giveVoucher = requireVoucher(table, giveVoucherId);
  const takeVoucher = requireVoucher(table, takeVoucherId);
  requireVoucherInHand(giveVoucher, actor.id);
  if (takeVoucher.location.type !== "platter") {
    throw new GameError("Taken voucher is not in the platter.", "voucher_not_in_platter");
  }
  giveVoucher.location = { type: "platter" };
  takeVoucher.location = { type: "hand", participantId: actor.id };
  recordTransaction(table, actor, "Swap", "Platter", ingredientName(giveVoucher.ingredientId), ingredientName(takeVoucher.ingredientId));
}

function swapIngredientWithPlatter(table: Table, actor: Participant, giveIngredientId: string, takeIngredientId: string, quantity: number): void {
  if (quantity !== 1) {
    throw new GameError("Aggregate platter swaps currently support quantity 1.", "invalid_quantity");
  }
  const giveVoucher = Object.values(table.vouchers)
    .filter(
      (candidate) =>
        candidate.location.type === "hand" &&
        candidate.location.participantId === actor.id &&
        candidate.ingredientId === giveIngredientId
    )
    .sort((left, right) => left.id.localeCompare(right.id))[0];
  if (!giveVoucher) {
    throw new GameError("No matching held voucher is available to give.", "voucher_not_in_hand");
  }
  const takeVoucher = Object.values(table.vouchers)
    .filter((candidate) => candidate.location.type === "platter" && candidate.ingredientId === takeIngredientId)
    .sort((left, right) => left.id.localeCompare(right.id))[0];
  if (!takeVoucher) {
    throw new GameError("No matching platter voucher is available to take.", "voucher_not_in_platter");
  }
  swapWithPlatter(table, actor, giveVoucher.id, takeVoucher.id);
}

function swapPlatterAssets(table: Table, actor: Participant, give: PlatterAssetRef, take: PlatterAssetRef): void {
  if (table.phase !== "playing" && table.phase !== "settlement") {
    throw new GameError("Action requires phase playing or settlement.", "invalid_phase");
  }
  requireActive(actor);
  ensureBotCanUsePool(actor);
  if (give.kind === take.kind && give.id === take.id) {
    throw new GameError("Cannot swap an asset for itself.", "invalid_platter_swap");
  }
  const giveAsset = requirePlatterAsset(table, give);
  const takeAsset = requirePlatterAsset(table, take);
  requireAssetInInventory(giveAsset, actor.id);
  requireAssetInPlatter(takeAsset);

  moveAssetToPlatter(giveAsset);
  moveAssetToInventory(takeAsset, actor.id);
  recordTransaction(table, actor, "Settlement Swap", "Platter", platterAssetLabel(giveAsset), platterAssetLabel(takeAsset));
  if (table.phase === "settlement") {
    advanceSettlementIfReady(table);
  }
}

function swapAggregatePlatterAssets(
  table: Table,
  actor: Participant,
  give: AggregatePlatterAssetRef,
  take: AggregatePlatterAssetRef,
  quantity: number
): void {
  if (quantity !== 1) {
    throw new GameError("Aggregate settlement swaps currently support quantity 1.", "invalid_quantity");
  }
  swapPlatterAssets(table, actor, aggregateAssetToExactRef(table, actor.id, give, "inventory"), aggregateAssetToExactRef(table, actor.id, take, "platter"));
}

function createOffer(
  table: Table,
  actor: Participant,
  toParticipantId: string,
  offeredVoucherIds: string[],
  requested: { ingredientId: string; quantity: number }
): Offer {
  requirePhase(table, "playing");
  requireActive(actor);
  ensureBotCanUseBarter(actor);
  if (toParticipantId === actor.id) {
    throw new GameError("Cannot trade with yourself.", "invalid_offer");
  }
  const recipient = requireParticipant(table, toParticipantId);
  requireActive(recipient);
  if (!Number.isInteger(requested.quantity) || requested.quantity <= 0) {
    throw new GameError("Offer request quantity must be positive.", "invalid_offer");
  }
  if (!INGREDIENTS.some((ingredient) => ingredient.id === requested.ingredientId)) {
    throw new GameError("Requested ingredient is unknown.", "invalid_offer");
  }
  if (offeredVoucherIds.length === 0) {
    throw new GameError("Offer must include at least one voucher.", "invalid_offer");
  }
  if (!recipient.ingredientId || requested.ingredientId !== recipient.ingredientId) {
    throw new GameError("Offers can only ask for the recipient's own ingredient.", "invalid_offer");
  }
  if (offerableUnreservedIngredientQty(table, recipient.id, requested.ingredientId) < requested.quantity) {
    throw new GameError("Recipient has no available vouchers for that ingredient.", "offer_unavailable");
  }
  for (const voucherId of offeredVoucherIds) {
    const voucher = requireVoucher(table, voucherId);
    requireVoucherInHand(voucher, actor.id);
  }

  const offerId = `offer_${table.nextId}`;
  table.nextId += 1;
  const offer: Offer = {
    id: offerId,
    fromParticipantId: actor.id,
    toParticipantId,
    offeredVoucherIds: [...offeredVoucherIds],
    requested: { ...requested },
    acceptedVoucherIds: [],
    status: "pending",
    createdTurn: table.turn
  };
  table.offers[offer.id] = offer;
  for (const voucherId of offeredVoucherIds) {
    table.vouchers[voucherId].location = { type: "offer_lock", offerId };
  }
  return offer;
}

function respondOffer(
  table: Table,
  actor: Participant,
  offerId: string,
  response: "accept" | "refuse",
  voucherIds: string[]
): void {
  requirePhase(table, "playing");
  requireActive(actor);
  ensureBotCanUseBarter(actor);
  const offer = requireOffer(table, offerId);
  if (offer.status !== "pending") {
    throw new GameError("Offer is not pending.", "offer_not_pending");
  }
  if (offer.toParticipantId !== actor.id) {
    throw new GameError("Only the recipient can respond to this offer.", "not_offer_recipient");
  }

  if (response === "refuse") {
    offer.status = "refused";
    releaseOfferedVouchers(table, offer);
    delete table.offers[offer.id];
    return;
  }

  if (voucherIds.length !== offer.requested.quantity) {
    throw new GameError("Accepted voucher count does not match the request.", "invalid_offer_response");
  }
  for (const voucherId of voucherIds) {
    const voucher = requireVoucher(table, voucherId);
    requireVoucherInHand(voucher, actor.id);
    if (voucher.ingredientId !== offer.requested.ingredientId) {
      throw new GameError("Accepted voucher ingredient does not match the request.", "invalid_offer_response");
    }
  }

  offer.status = "accepted";
  offer.acceptedVoucherIds = [...voucherIds];
  for (const voucherId of offer.offeredVoucherIds) {
    table.vouchers[voucherId].location = { type: "hand", participantId: offer.toParticipantId };
  }
  for (const voucherId of voucherIds) {
    table.vouchers[voucherId].location = { type: "hand", participantId: offer.fromParticipantId };
  }
  const creator = requireParticipant(table, offer.fromParticipantId);
  recordTransaction(
    table,
    creator,
    "Exchange",
    actor.name,
    ingredientListLabel(table, offer.offeredVoucherIds),
    ingredientListLabel(table, voucherIds),
    actor.id
  );
  delete table.offers[offer.id];
}

function cancelOffer(table: Table, actor: Participant, offerId: string): void {
  requirePhase(table, "playing");
  const offer = requireOffer(table, offerId);
  if (offer.status !== "pending") {
    throw new GameError("Offer is not pending.", "offer_not_pending");
  }
  if (offer.fromParticipantId !== actor.id) {
    throw new GameError("Only the offer creator can cancel this offer.", "not_offer_creator");
  }
  offer.status = "cancelled";
  releaseOfferedVouchers(table, offer);
  delete table.offers[offer.id];
}

function autoRefuseUnavailableOffers(table: Table): void {
  const remainingByParticipantIngredient = new Map<string, number>();
  for (const offer of Object.values(table.offers)) {
    if (offer.status !== "pending") {
      continue;
    }
    const recipient = table.participants[offer.toParticipantId];
    if (!recipient) {
      offer.status = "refused";
      releaseOfferedVouchers(table, offer);
      delete table.offers[offer.id];
      continue;
    }
    const key = `${recipient.id}:${offer.requested.ingredientId}`;
    const remaining =
      remainingByParticipantIngredient.get(key) ?? offerableIngredientQty(table, recipient.id, offer.requested.ingredientId);
    if (remaining >= offer.requested.quantity) {
      remainingByParticipantIngredient.set(key, remaining - offer.requested.quantity);
      continue;
    }
    offer.status = "refused";
    releaseOfferedVouchers(table, offer);
    delete table.offers[offer.id];
  }
}

function cancelAllPendingOffers(table: Table): void {
  for (const offer of Object.values(table.offers)) {
    if (offer.status === "pending") {
      offer.status = "cancelled";
      releaseOfferedVouchers(table, offer);
    }
    delete table.offers[offer.id];
  }
}

function cancelPendingOffersForParticipant(table: Table, participantId: string): void {
  for (const offer of Object.values(table.offers)) {
    if (offer.status !== "pending") {
      continue;
    }
    if (offer.fromParticipantId !== participantId && offer.toParticipantId !== participantId) {
      continue;
    }
    offer.status = "cancelled";
    releaseOfferedVouchers(table, offer);
    delete table.offers[offer.id];
  }
}

function placeVoucher(table: Table, actor: Participant, voucherId: string, requirementId: string): void {
  requirePhase(table, "playing");
  requireActive(actor);
  const recipe = table.recipes[actor.id];
  if (!recipe) {
    throw new GameError("Participant has no recipe.", "missing_recipe");
  }
  const requirement = recipe.requirements.find((candidate) => candidate.id === requirementId);
  if (!requirement) {
    throw new GameError("Requirement not found.", "missing_requirement");
  }
  const voucher = requireVoucher(table, voucherId);
  requireVoucherInHand(voucher, actor.id);
  if (voucher.ingredientId !== requirement.ingredientId) {
    throw new GameError("Voucher ingredient does not match requirement.", "ingredient_mismatch");
  }
  const outstanding = requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length;
  if (outstanding <= 0) {
    throw new GameError("Requirement already has enough placed or redeemed vouchers.", "requirement_full");
  }
  requirement.placedVoucherIds.push(voucherId);
  voucher.location = {
    type: "placed",
    participantId: actor.id,
    recipeOwnerId: actor.id,
    requirementId
  };
}

function redeemVoucher(table: Table, actor: Participant, voucherId: string): void {
  requirePhase(table, "playing");
  requireActive(actor);
  const recipe = table.recipes[actor.id];
  if (!recipe) {
    throw new GameError("Participant has no recipe.", "missing_recipe");
  }
  const voucher = requireVoucher(table, voucherId);
  if (
    voucher.location.type !== "placed" ||
    voucher.location.recipeOwnerId !== actor.id ||
    !voucher.location.requirementId
  ) {
    throw new GameError("Voucher is not placed on this participant's recipe.", "voucher_not_placed");
  }
  const requirement = recipe.requirements.find((candidate) => candidate.id === voucher.location.requirementId);
  if (!requirement) {
    throw new GameError("Requirement not found.", "missing_requirement");
  }
  const index = requirement.placedVoucherIds.indexOf(voucherId);
  if (index < 0) {
    throw new GameError("Voucher is not tracked by requirement.", "voucher_not_placed");
  }
  const owner = requireParticipant(table, voucher.ownerParticipantId);
  if ((owner.realIngredientStock ?? 0) <= 0) {
    throw new GameError("Ingredient owner has no real stock remaining.", "ingredient_stock_depleted");
  }
  requirement.placedVoucherIds.splice(index, 1);
  requirement.redeemedQty += 1;
  owner.realIngredientStock = (owner.realIngredientStock ?? 0) - 1;
  voucher.location =
    owner.realIngredientStock > 0
      ? { type: "hand", participantId: owner.id }
      : {
          type: "holding",
          participantId: owner.id,
          recipeOwnerId: actor.id,
          requirementId: requirement.id
        };
  recordTransaction(
    table,
    actor,
    "Redeem",
    owner.name,
    voucherCardLabel(voucher),
    `Real ${ingredientName(voucher.ingredientId)}`,
    owner.id
  );
}

function redeemVoucherFromHand(table: Table, actor: Participant, voucherId: string, requirementId: string): void {
  placeVoucher(table, actor, voucherId, requirementId);
  redeemVoucher(table, actor, voucherId);
}

function prepareDish(table: Table, actor: Participant): void {
  requirePhase(table, "playing");
  requireActive(actor);
  const recipe = table.recipes[actor.id];
  if (!recipe) {
    throw new GameError("Participant has no recipe.", "missing_recipe");
  }
  const complete = recipe.requirements.every((requirement) => requirement.redeemedQty >= requirement.requiredQty);
  if (!complete) {
    throw new GameError("All recipe quantities must be redeemed before preparation.", "recipe_incomplete");
  }
  const dishId = `dish_${table.nextId}`;
  table.nextId += 1;
  table.dishes[dishId] = {
    id: dishId,
    ownerParticipantId: actor.id,
    name: recipe.name,
    unitSingular: recipe.unitSingular,
    unitPlural: recipe.unitPlural,
    totalParts: DISH_PARTS_PER_DISH,
    partsRemaining: DISH_PARTS_PER_DISH,
    partsEaten: 0,
    totalBites: DISH_PARTS_PER_DISH,
    bitesRemaining: DISH_PARTS_PER_DISH,
    biteCounts: {}
  };
  table.dishParts ??= {};
  for (let index = 1; index <= DISH_PARTS_PER_DISH; index += 1) {
    const partId = `${dishId}_part_${index}`;
    table.dishParts[partId] = {
      id: partId,
      dishId,
      dishName: recipe.name,
      makerParticipantId: actor.id,
      unitSingular: recipe.unitSingular,
      unitPlural: recipe.unitPlural,
      location: { type: "inventory", participantId: actor.id }
    };
  }
  recordTransaction(table, actor, "Prepare", "Table", "Recipe ingredients", `${DISH_PARTS_PER_DISH} ${recipe.unitPlural} of ${recipe.name}`);
  actor.dishCount += 1;
  if (actor.dishCount < table.targetDishCount) {
    table.recipes[actor.id] = generateRecipe(table, actor.id);
  } else {
    delete table.recipes[actor.id];
  }

  if (activeParticipants(table).every((participant) => participant.dishCount >= table.targetDishCount)) {
    enterSettlementPhase(table);
  }
}

function biteDish(table: Table, actor: Participant, dishId: string): void {
  requirePhase(table, "eating");
  requireActive(actor);
  const account = platterAccountForParticipant(table, actor.id);
  if (!account.cleared) {
    throw new GameError("Clear your central platter account before eating.", "account_not_cleared");
  }
  const dish = table.dishes[dishId];
  if (!dish) {
    throw new GameError("Dish not found.", "missing_dish");
  }
  const part = Object.values(table.dishParts ?? {}).find(
    (candidate) =>
      candidate.dishId === dishId &&
      candidate.location.type === "inventory" &&
      candidate.location.participantId === actor.id
  );
  if (!part) {
    throw new GameError("You do not hold any uneaten parts of this dish.", "dish_part_not_held");
  }
  const biteCounts = dish.biteCounts ?? {};
  dish.biteCounts = biteCounts;
  const actorBites = biteCounts[actor.id] ?? 0;
  part.location = { type: "eaten", participantId: actor.id };
  dish.partsEaten = (dish.partsEaten ?? 0) + 1;
  dish.partsRemaining = Math.max(0, (dish.partsRemaining ?? dish.bitesRemaining ?? 0) - 1);
  dish.bitesRemaining = dish.partsRemaining;
  biteCounts[actor.id] = actorBites + 1;
  recordTransaction(table, actor, "Eat", actor.name, platterAssetLabel({ kind: "dish_part", value: part }), "Eaten");
  if (Object.values(table.dishParts ?? {}).every((candidate) => candidate.location.type === "eaten")) {
    table.phase = "complete";
  }
}

function createParticipantVouchers(table: Table, participant: Participant): void {
  if (!participant.ingredientId) {
    throw new GameError("Cannot create vouchers without ingredient assignment.", "missing_ingredient");
  }
  for (let index = 1; index <= VOUCHERS_PER_INGREDIENT; index += 1) {
    const voucherId = `${participant.ingredientId}_${participant.id}_${index}`;
    table.vouchers[voucherId] = {
      id: voucherId,
      ingredientId: participant.ingredientId,
      ownerParticipantId: participant.id,
      location: { type: "hand", participantId: participant.id }
    };
  }
}

function recordTransaction(
  table: Table,
  participant: Participant,
  action: TransactionAction,
  counterparty: string,
  itemOut: string,
  itemBack: string,
  counterpartyParticipantId?: string
): void {
  table.transactionHistory ??= [];
  table.transactionHistory.push({
    id: `tx_${table.transactionHistory.length + 1}`,
    turn: table.turn,
    participantId: participant.id,
    name: participant.name,
    action,
    counterpartyParticipantId,
    counterparty,
    itemOut,
    itemBack
  });
}

function ingredientListLabel(table: Table, voucherIds: string[]): string {
  return voucherIds.map((voucherId) => ingredientName(table.vouchers[voucherId]?.ingredientId ?? "")).join(", ");
}

function requirePlatterAsset(table: Table, ref: PlatterAssetRef): ResolvedPlatterAsset {
  switch (ref.kind) {
    case "voucher":
      return { kind: "voucher", value: requireVoucher(table, ref.id) };
    case "dish_part":
      return { kind: "dish_part", value: requireDishPart(table, ref.id) };
    default:
      assertNever(ref.kind);
  }
}

function aggregateAssetToExactRef(
  table: Table,
  participantId: string,
  ref: AggregatePlatterAssetRef,
  source: "inventory" | "platter"
): PlatterAssetRef {
  if (ref.kind === "voucher") {
    const voucher = Object.values(table.vouchers)
      .filter((candidate) => candidate.ingredientId === ref.ingredientId)
      .filter((candidate) => !ref.ownerParticipantId || candidate.ownerParticipantId === ref.ownerParticipantId)
      .filter((candidate) => {
        if (source === "inventory") {
          return candidate.location.type === "hand" && candidate.location.participantId === participantId;
        }
        return candidate.location.type === "platter";
      })
      .sort((left, right) => left.id.localeCompare(right.id))[0];
    if (!voucher) {
      throw new GameError(
        source === "inventory" ? "No matching held voucher is available to give." : "No matching platter voucher is available to take.",
        source === "inventory" ? "voucher_not_in_hand" : "voucher_not_in_platter"
      );
    }
    return { kind: "voucher", id: voucher.id };
  }

  const part = Object.values(table.dishParts ?? {})
    .filter((candidate) => candidate.dishId === ref.dishId)
    .filter((candidate) => !ref.makerParticipantId || candidate.makerParticipantId === ref.makerParticipantId)
    .filter((candidate) => {
      if (source === "inventory") {
        return candidate.location.type === "inventory" && candidate.location.participantId === participantId;
      }
      return candidate.location.type === "platter";
    })
    .sort((left, right) => left.id.localeCompare(right.id))[0];
  if (!part) {
    throw new GameError(
      source === "inventory" ? "No matching held dish part is available to give." : "No matching platter dish part is available to take.",
      source === "inventory" ? "dish_part_not_held" : "dish_part_not_in_platter"
    );
  }
  return { kind: "dish_part", id: part.id };
}

function requireDishPart(table: Table, dishPartId: string): DishPart {
  const part = table.dishParts?.[dishPartId];
  if (!part) {
    throw new GameError("Dish part not found.", "missing_dish_part");
  }
  return part;
}

function requireAssetInInventory(asset: ResolvedPlatterAsset, participantId: string): void {
  if (asset.kind === "voucher") {
    requireVoucherInHand(asset.value, participantId);
    return;
  }
  if (asset.value.location.type !== "inventory" || asset.value.location.participantId !== participantId) {
    throw new GameError("Dish part is not in participant inventory.", "dish_part_not_held");
  }
}

function requireAssetInPlatter(asset: ResolvedPlatterAsset): void {
  if (asset.kind === "voucher") {
    if (asset.value.location.type !== "platter") {
      throw new GameError("Taken voucher is not in the platter.", "voucher_not_in_platter");
    }
    return;
  }
  if (asset.value.location.type !== "platter") {
    throw new GameError("Taken dish part is not in the platter.", "dish_part_not_in_platter");
  }
}

function moveAssetToPlatter(asset: ResolvedPlatterAsset): void {
  if (asset.kind === "voucher") {
    asset.value.location = { type: "platter" };
    return;
  }
  asset.value.location = { type: "platter" };
}

function moveAssetToInventory(asset: ResolvedPlatterAsset, participantId: string): void {
  if (asset.kind === "voucher") {
    asset.value.location = { type: "hand", participantId };
    return;
  }
  asset.value.location = { type: "inventory", participantId };
}

function platterAssetLabel(asset: ResolvedPlatterAsset): string {
  if (asset.kind === "voucher") {
    return voucherCardLabel(asset.value);
  }
  return dishPartLabel(asset.value);
}

function dishPartLabel(part: DishPart): string {
  return `${part.dishName} ${part.unitSingular}`;
}

function voucherCardLabel(voucher: Voucher): string {
  return ingredientName(voucher.ingredientId);
}

function ingredientName(ingredientId: string): string {
  return INGREDIENTS.find((ingredient) => ingredient.id === ingredientId)?.name ?? ingredientId;
}

function offerableIngredientQty(table: Table, participantId: string, ingredientId: string): number {
  const participant = table.participants[participantId];
  if ((participant?.realIngredientStock ?? 0) <= 0) {
    return 0;
  }
  return Object.values(table.vouchers).filter(
    (voucher) => voucher.ingredientId === ingredientId && voucher.location.type === "hand" && voucher.location.participantId === participantId
  ).length;
}

export function offerableUnreservedIngredientQty(table: Table, participantId: string, ingredientId: string): number {
  const rawAvailable = offerableIngredientQty(table, participantId, ingredientId);
  const pendingRequested = Object.values(table.offers)
    .filter(
      (offer) =>
        offer.status === "pending" &&
        offer.toParticipantId === participantId &&
        offer.requested.ingredientId === ingredientId
    )
    .reduce((total, offer) => total + offer.requested.quantity, 0);
  return Math.max(0, rawAvailable - pendingRequested);
}

function releaseOfferedVouchers(table: Table, offer: Offer): void {
  for (const voucherId of offer.offeredVoucherIds) {
    const voucher = table.vouchers[voucherId];
    if (voucher?.location.type === "offer_lock" && voucher.location.offerId === offer.id) {
      voucher.location = { type: "hand", participantId: offer.fromParticipantId };
    }
  }
}

function enterSettlementPhase(table: Table): void {
  cancelAllPendingOffers(table);
  const active = activeParticipants(table);
  const highScore = Math.max(...active.map((participant) => participant.dishCount), 0);
  table.winnerParticipantIds = active
    .filter((participant) => participant.dishCount === highScore)
    .map((participant) => participant.id);
  table.phase = Object.keys(table.dishes).length > 0 ? "settlement" : "complete";
  advanceSettlementIfReady(table);
}

function advanceSettlementIfReady(table: Table): void {
  if (table.phase !== "settlement") {
    return;
  }
  if (!allActiveParticipantsCleared(table)) {
    return;
  }
  if (platterDishPartIds(table).length > 0) {
    return;
  }
  table.phase = Object.values(table.dishParts ?? {}).some((part) => part.location.type !== "eaten") ? "eating" : "complete";
}

function enterEndgamePhase(table: Table): void {
  enterSettlementPhase(table);
}

function requireParticipant(table: Table, participantId: string): Participant {
  const participant = table.participants[participantId];
  if (!participant) {
    throw new GameError("Participant not found.", "missing_participant");
  }
  return participant;
}

function requireVoucher(table: Table, voucherId: string): Voucher {
  const voucher = table.vouchers[voucherId];
  if (!voucher) {
    throw new GameError("Voucher not found.", "missing_voucher");
  }
  return voucher;
}

function requireOffer(table: Table, offerId: string): Offer {
  const offer = table.offers[offerId];
  if (!offer) {
    throw new GameError("Offer not found.", "missing_offer");
  }
  return offer;
}

function requireVoucherInHand(voucher: Voucher, participantId: string): void {
  if (voucher.location.type !== "hand" || voucher.location.participantId !== participantId) {
    throw new GameError("Voucher is not in participant hand.", "voucher_not_in_hand");
  }
}

function requireHost(participant: Participant): void {
  if (!participant.isHost) {
    throw new GameError("Only the host can perform this action.", "host_only");
  }
}

function requireActive(participant: Participant): void {
  if (participant.role !== "active") {
    throw new GameError("Only active participants can perform this action.", "active_only");
  }
}

function requireLobby(table: Table): void {
  requirePhase(table, "lobby");
}

function requirePhase(table: Table, phase: Table["phase"]): void {
  if (table.phase !== phase) {
    throw new GameError(`Action requires phase ${phase}.`, "invalid_phase");
  }
}

function ensureBotCanUsePool(participant: Participant): void {
  if (participant.kind === "bot" && participant.botType === "barter_only") {
    throw new GameError("This bot type cannot use the platter pool.", "bot_channel_restricted");
  }
}

function ensureBotCanUseBarter(participant: Participant): void {
  if (participant.kind === "bot" && participant.botType === "pool_only") {
    throw new GameError("This bot type cannot use direct barter.", "bot_channel_restricted");
  }
}

function assertNever(value: never): never {
  throw new Error(`Unhandled intent: ${JSON.stringify(value)}`);
}

function cloneTable(table: Table): Table {
  return structuredClone(table) as Table;
}

function restoreTable(table: Table, snapshot: Table): void {
  for (const key of Object.keys(table)) {
    delete (table as unknown as Record<string, unknown>)[key];
  }
  Object.assign(table, snapshot);
}
