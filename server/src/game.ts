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
  OPENING_OFFERINGS_PER_PLAYER,
  REAL_UNITS_PER_INGREDIENT,
  VOUCHERS_PER_INGREDIENT
} from "./constants.js";
import { ingredientsForPlayerCount, minimumBackedStockForPlayerCount } from "./recipeCatalog.js";
import { generateRecipe } from "./recipes.js";
import type {
  AggregatePlatterAssetRef,
  BotType,
  Dish,
  DishPart,
  Intent,
  Offer,
  OfferRequest,
  OfferAssetRequest,
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

const GENERATED_BOT_NAMES = [
  "Jim",
  "Nia",
  "Luc",
  "Ava",
  "Leo",
  "Mia",
  "Yan",
  "Eli",
  "Noa",
  "Sam",
  "Zoe",
  "Kai",
  "Ivy",
  "Max",
  "Uma",
  "Ana",
  "Raj",
  "Taj",
  "Moe",
  "Ada"
] as const;

const GENERIC_HUMAN_NAMES = new Set(["", "host", "player"]);
const GENERIC_BOT_NAMES = new Set(["", "bot", "pool bot", "barter bot", "mixed bot", "pool_only", "barter_only", "mixed"]);

type ResolvedPlatterAsset = { kind: "voucher"; value: Voucher } | { kind: "dish_part"; value: DishPart };

export class GameError extends Error {
  constructor(message: string, public readonly code = "game_error") {
    super(message);
  }
}

export function createEmptyTable(code: string, seed: string, hostName: string, seatToken: string, isPublic = true): Table {
  const host: Participant = {
    id: "p1",
    name: resolveHumanName([], hostName, 1),
    kind: "human",
    role: "active",
    isHost: true,
    seatToken,
    dishCount: 0,
    depositedInitial: false,
    openingOfferingsCount: 0,
    connected: true
  };

  const table: Table = {
    code,
    seed,
    isPublic,
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
    scarcityPressureByIngredient: {},
    winnerParticipantIds: [],
    targetDishCount: DEFAULT_TARGET_DISH_COUNT,
    stockPerIngredient: REAL_UNITS_PER_INGREDIENT,
    turnMode: "round_robin",
    turn: 0,
    nextId: 2
  };
  fillOpenBotSeats(table);
  assignRandomLobbyIngredients(table);
  return table;
}

export function addHumanParticipant(table: Table, name: string, seatToken: string, asWitness = false): Participant {
  if (table.phase === "lobby" && !asWitness) {
    const openBot = firstAvailableBotSeat(table);
    if (openBot) {
      claimBotSeat(table, openBot, name, seatToken);
      table.turn += 1;
      table.version += 1;
      return openBot;
    }
  }
  const canJoinActive = table.phase === "lobby" && !asWitness && activeParticipants(table).length < MAX_ACTIVE_PARTICIPANTS;
  const role: ParticipantRole = canJoinActive ? "active" : "witness";
  const participant = createParticipant(table, resolveHumanName(existingNames(table), name, table.participantOrder.length + 1), "human", role, seatToken);
  table.participants[participant.id] = participant;
  table.participantOrder.push(participant.id);
  table.turn += 1;
  table.version += 1;
  return participant;
}

function fillOpenBotSeats(table: Table): void {
  while (activeParticipants(table).length < MAX_ACTIVE_PARTICIPANTS) {
    const participant = createParticipant(
      table,
      resolveBotName(existingNames(table), "Bot", table.participantOrder.length + 1, "mixed"),
      "bot",
      "active",
      `bot:${table.nextId}`,
      "mixed"
    );
    table.participants[participant.id] = participant;
    table.participantOrder.push(participant.id);
  }
}

function assignRandomLobbyIngredients(table: Table): void {
  const active = activeParticipants(table);
  const ingredientOrder = shuffledIngredientsForTable(table, active.length);
  active.forEach((participant, index) => {
    const ingredient = ingredientOrder[index];
    if (ingredient) {
      participant.ingredientId = ingredient.id;
    }
  });
}

function ensureLobbyIngredientAssignments(table: Table): void {
  const active = activeParticipants(table);
  if (active.length < MIN_ACTIVE_PARTICIPANTS || active.length > MAX_ACTIVE_PARTICIPANTS) {
    return;
  }
  const allowedIngredientIds = new Set(ingredientsForPlayerCount(active.length).map((ingredient) => ingredient.id));
  const assignedIngredientIds = new Set<string>();
  for (const participant of active) {
    if (!participant.ingredientId || !allowedIngredientIds.has(participant.ingredientId) || assignedIngredientIds.has(participant.ingredientId)) {
      assignRandomLobbyIngredients(table);
      return;
    }
    assignedIngredientIds.add(participant.ingredientId);
  }
}

function shuffledIngredientsForTable(table: Table, activeCount: number) {
  return deterministicShuffle(ingredientsForPlayerCount(activeCount), `${table.seed}:ingredient-assignment`, (ingredient) => ingredient.id);
}

function deterministicShuffle<T>(items: readonly T[], seed: string, keyForItem: (item: T) => string = (item) => String(item)): T[] {
  return [...items].sort((left, right) => {
    const leftKey = keyForItem(left);
    const rightKey = keyForItem(right);
    const rank = hashString(`${seed}:${leftKey}`) - hashString(`${seed}:${rightKey}`);
    return rank === 0 ? leftKey.localeCompare(rightKey) : rank;
  });
}

function hashString(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function firstAvailableBotSeat(table: Table): Participant | undefined {
  return table.participantOrder
    .map((participantId) => table.participants[participantId])
    .find((participant) => participant?.kind === "bot" && participant.role === "active");
}

function requireClaimableBotSeat(table: Table, participantId: string): Participant {
  const participant = requireParticipant(table, participantId);
  if (participant.kind !== "bot" || participant.role !== "active") {
    throw new GameError("That seat is not an available bot seat.", "bot_seat_unavailable");
  }
  return participant;
}

function claimBotSeat(table: Table, participant: Participant, name: string, seatToken: string, controllerParticipantId?: string): void {
  const existing = existingNames(table).filter((candidate) => candidate !== participant.name);
  const ordinal = Math.max(1, table.participantOrder.indexOf(participant.id) + 1);
  participant.name = resolveHumanName(existing, name, ordinal);
  participant.kind = "human";
  participant.role = "active";
  participant.seatToken = seatToken;
  participant.connected = true;
  participant.dishCount = 0;
  participant.depositedInitial = false;
  participant.openingOfferingsCount = 0;
  delete participant.botType;
  if (controllerParticipantId) {
    participant.controllerParticipantId = controllerParticipantId;
  } else {
    delete participant.controllerParticipantId;
  }
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
    const turnGated = shouldGateTurn(table, intent);
    if (turnGated) {
      requireCurrentTurn(table, actor);
    }

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
      case "set_table_visibility":
        setTableVisibility(table, actor, intent.isPublic);
        break;
      case "set_role":
        setRole(table, actor, intent.participantId, intent.role);
        break;
      case "rename_participant":
        renameParticipant(table, actor, intent.participantId, intent.name);
        break;
      case "add_bot":
        addBot(table, actor, intent.name, intent.botType);
        break;
      case "add_controlled_seat":
        addControlledSeat(table, actor, intent.name, intent.participantId);
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
      case "pass_turn":
        passTurn(table, actor);
        break;
      case "redeem_all_and_pass_turn":
        redeemUsefulHandVouchersAndPassTurn(table, actor);
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
        createOffer(table, actor, intent.toParticipantId, intent.offeredVoucherIds ?? [], intent.requested, intent.offeredAssets, intent.requestedAsset);
        break;
      case "respond_offer":
        respondOffer(table, actor, intent.offerId, intent.response, intent.voucherIds ?? [], intent.assets);
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
      case "bite_all":
        biteAllHeldFoodParts(table, actor);
        break;
      default:
        assertNever(intent);
    }
    autoRefuseUnavailableOffers(table);
    if (table.phase === "settlement") {
      advanceSettlementIfReady(table);
    }
    if (shouldAdvanceTurnAfterIntent(table, intent)) {
      advanceTurn(table, actor.id);
    }
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
  ownCardsInHand: number;
  foreignCardsInHand: number;
  ownCardsInOtherHands: number;
  expectedOwnCardsInHand: number;
  platterDebt: number;
  platterShortfall: number;
  cleared: boolean;
}

export function platterAccountForParticipant(table: Table, participantId: string): PlatterAccount {
  const ownCardsInPlatter = Object.values(table.vouchers).filter(
    (voucher) => voucher.ownerParticipantId === participantId && voucher.location.type === "platter"
  ).length;
  const ownCardsInHand = Object.values(table.vouchers).filter(
    (voucher) =>
      voucher.ownerParticipantId === participantId &&
      voucher.location.type === "hand" &&
      voucher.location.participantId === participantId
  ).length;
  const foreignCardsInHand = Object.values(table.vouchers).filter(
    (voucher) =>
      voucher.ownerParticipantId !== participantId &&
      voucher.location.type === "hand" &&
      voucher.location.participantId === participantId
  ).length;
  const ownCardsInOtherHands = Object.values(table.vouchers).filter(
    (voucher) =>
      voucher.ownerParticipantId === participantId &&
      voucher.location.type === "hand" &&
      voucher.location.participantId !== participantId
  ).length;
  const expectedOwnCardsInHand = VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER;
  return {
    participantId,
    ownCardsInPlatter,
    ownCardsInHand,
    foreignCardsInHand,
    ownCardsInOtherHands,
    expectedOwnCardsInHand,
    platterDebt: Math.max(0, ownCardsInPlatter - OPENING_OFFERINGS_PER_PLAYER),
    platterShortfall: Math.max(0, OPENING_OFFERINGS_PER_PLAYER - ownCardsInPlatter),
    cleared: ownCardsInPlatter === OPENING_OFFERINGS_PER_PLAYER && ownCardsInHand === expectedOwnCardsInHand && foreignCardsInHand === 0
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

function resolveBotName(existing: string[], requestedName: string, _ordinal: number, botType: BotType): string {
  const trimmed = requestedName.trim();
  const lower = trimmed.toLowerCase();
  if (GENERIC_BOT_NAMES.has(lower)) {
    return uniqueGeneratedBotName(existing, botType);
  }
  const explicit = explicitBotName(trimmed);
  if (/_b/i.test(explicit)) {
    return uniqueName(existing, explicit);
  }
  return uniqueBotName(existing, explicit, botType);
}

function explicitBotName(requestedName: string): string {
  return requestedName
    .replace(/_(pool|barter|mix|mixed)_bot$/i, "")
    .replace(/_?bot$/i, "")
    .replace(/_b(?:_\d+)?$/i, "");
}

function botNameSuffix(botType: BotType): string {
  switch (botType) {
    case "pool_only":
    case "barter_only":
    case "mixed":
      return "_b";
    default:
      assertNever(botType);
  }
}

function shortBotBase(base: string): string {
  const letters = base.replace(/[^A-Za-z0-9]/g, "");
  if (letters.length === 0) {
    return "Bot";
  }
  return letters.slice(0, 3);
}

function uniqueBotName(existing: string[], rawBase: string, botType: BotType): string {
  const suffix = botNameSuffix(botType);
  const base = shortBotBase(rawBase);
  const first = `${base}${suffix}`;
  if (!existing.includes(first)) {
    return first;
  }
  for (let index = 2; index < 100; index += 1) {
    const marker = String(index);
    const prefixLength = Math.max(1, 3 - marker.length);
    const candidate = `${base.slice(0, prefixLength)}${marker}${suffix}`;
    if (!existing.includes(candidate)) {
      return candidate;
    }
  }
  return `B${existing.length % 100}${suffix}`;
}

function uniqueGeneratedBotName(existing: string[], botType: BotType): string {
  const suffix = botNameSuffix(botType);
  const usedBases = new Set(existing.map((name) => botBaseKey(name)));
  for (const base of GENERATED_BOT_NAMES) {
    const candidate = `${base}${suffix}`;
    if (!existing.includes(candidate) && !usedBases.has(botBaseKey(base))) {
      return candidate;
    }
  }
  for (const base of GENERATED_BOT_NAMES) {
    const candidate = uniqueBotName(existing, base, botType);
    if (!existing.includes(candidate)) {
      return candidate;
    }
  }
  return uniqueBotName(existing, "Bot", botType);
}

function botBaseKey(name: string): string {
  return name
    .replace(/_(pool|barter|mix|mixed)_bot$/i, "")
    .replace(/_?bot$/i, "")
    .replace(/_b(?:_\d+)?$/i, "")
    .replace(/[^A-Za-z0-9]/g, "")
    .toLowerCase();
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
    openingOfferingsCount: 0,
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
  table.scarcityPressureByIngredient = {};
  table.winnerParticipantIds = [];
  table.currentTurnParticipantId = undefined;
  clearTimerRuntime(table);
  for (const participant of Object.values(table.participants)) {
    participant.dishCount = 0;
    participant.depositedInitial = false;
    participant.openingOfferingsCount = 0;
    delete participant.ingredientId;
    delete participant.realIngredientStock;
  }
  assignRandomLobbyIngredients(table);
}

function setTableVisibility(table: Table, actor: Participant, isPublic: boolean): void {
  requireHost(actor);
  requireLobby(table);
  table.isPublic = isPublic;
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
  ensureLobbyIngredientAssignments(table);
}

function renameParticipant(table: Table, actor: Participant, participantId: string, name: string): void {
  requireLobby(table);
  const participant = requireParticipant(table, participantId);
  if (!actor.isHost && actor.id !== participant.id) {
    throw new GameError("Only the host can rename other seats.", "host_required");
  }
  if (!actor.isHost && participant.kind !== "human") {
    throw new GameError("Only the host can rename bot seats.", "host_required");
  }
  const existing = existingNames(table).filter((candidate) => candidate !== participant.name);
  const ordinal = Math.max(1, table.participantOrder.indexOf(participant.id) + 1);
  if (participant.kind === "bot") {
    participant.name = resolveBotName(existing, name, ordinal, participant.botType ?? "mixed");
    return;
  }
  participant.name = resolveHumanName(existing, name, ordinal);
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
  ensureLobbyIngredientAssignments(table);
  return participant;
}

function addControlledSeat(table: Table, actor: Participant, name = "Player", participantId?: string): Participant {
  requireHost(actor);
  requireLobby(table);
  const botSeat = participantId ? requireClaimableBotSeat(table, participantId) : firstAvailableBotSeat(table);
  if (botSeat) {
    claimBotSeat(table, botSeat, name, `controlled:${actor.id}:${botSeat.id}`, actor.id);
    return botSeat;
  }
  if (activeParticipants(table).length >= MAX_ACTIVE_PARTICIPANTS) {
    throw new GameError(`At most ${MAX_ACTIVE_PARTICIPANTS} active participants are allowed.`, "too_many_active");
  }
  const participant = createParticipant(
    table,
    resolveHumanName(existingNames(table), name, table.participantOrder.length + 1),
    "human",
    "active",
    `controlled:${actor.id}:${table.nextId}`
  );
  participant.controllerParticipantId = actor.id;
  participant.connected = true;
  table.participants[participant.id] = participant;
  table.participantOrder.push(participant.id);
  ensureLobbyIngredientAssignments(table);
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
  delete participant.controllerParticipantId;
  participant.name = resolveBotName(
    existingNames(table).filter((candidate) => candidate !== participant.name),
    participant.name,
    table.participantOrder.indexOf(participant.id) + 1,
    botType
  );
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
  const requiredStock = minimumBackedStockForPlayerCount(active.length, table.targetDishCount);
  if (table.stockPerIngredient < requiredStock) {
    throw new GameError(
      `Stock must be at least ${requiredStock} for ${active.length} active participants, ${table.targetDishCount} dishes, and voucher backing.`,
      "stock_too_low"
    );
  }
  ensureLobbyIngredientAssignments(table);

  table.phase = "deposit";
  table.paused = false;
  table.vouchers = {};
  table.recipes = {};
  table.offers = {};
  table.dishes = {};
  table.dishParts = {};
  table.transactionHistory = [];
  table.scarcityPressureByIngredient = {};
  table.winnerParticipantIds = [];
  if (table.timer) {
    const nowMs = Date.now();
    table.timer.startedAtTurn = table.turn;
    table.timer.startedAtMs = nowMs;
    table.timer.endsAtMs = nowMs + table.timer.seconds * 1000;
    delete table.timer.expiredAtMs;
  }

  const allowedIngredientIds = new Set(ingredientsForPlayerCount(active.length).map((ingredient) => ingredient.id));
  active.forEach((participant) => {
    if (!participant.ingredientId || !allowedIngredientIds.has(participant.ingredientId)) {
      throw new GameError("Missing ingredient assignment.", "ingredient_assignment_failed");
    }
    participant.realIngredientStock = table.stockPerIngredient;
    participant.dishCount = 0;
    participant.depositedInitial = false;
    participant.openingOfferingsCount = 0;
    createParticipantVouchers(table, participant);
  });

  for (const participant of active) {
    table.recipes[participant.id] = generateRecipe(table, participant.id);
  }
  for (const participant of active) {
    depositInitialOffer(table, participant);
  }
  table.currentTurnParticipantId = active[0]?.id;
}

function depositInitialOffer(table: Table, participant: Participant): void {
  for (let count = participant.openingOfferingsCount; count < OPENING_OFFERINGS_PER_PLAYER; count += 1) {
    const voucher = Object.values(table.vouchers)
      .filter((candidate) => candidate.location.type === "hand" && candidate.location.participantId === participant.id)
      .filter((candidate) => candidate.ingredientId === participant.ingredientId)
      .sort((left, right) => left.id.localeCompare(right.id))[0];
    if (!voucher) {
      throw new GameError("No backed initial offering is available.", "voucher_not_in_hand");
    }
    depositToPlatter(table, participant, voucher.id);
  }
}

function stopTable(table: Table, actor: Participant): void {
  requireHost(actor);
  if (table.phase === "lobby" || table.phase === "complete") {
    throw new GameError("Only a running table can be stopped.", "invalid_phase");
  }
  enterSettlementPhase(table);
}

function passTurn(table: Table, actor: Participant): void {
  if (table.phase !== "playing" && table.phase !== "settlement" && table.phase !== "eating") {
    throw new GameError("Only a running turn can be passed.", "invalid_phase");
  }
  requireActive(actor);
  const nextParticipantId = nextTurnParticipantId(table, actor.id);
  const nextParticipant = nextParticipantId ? table.participants[nextParticipantId] : undefined;
  recordTransaction(table, actor, "Pass Turn", nextParticipant?.name ?? "Table", "Turn", "None", nextParticipant?.id);
}

function redeemUsefulHandVouchersAndPassTurn(table: Table, actor: Participant): void {
  requirePhase(table, "playing");
  requireActive(actor);
  const recipe = table.recipes[actor.id];
  if (recipe) {
    const remainingStockByOwner = new Map<string, number>();
    for (const requirement of recipe.requirements) {
      for (const voucherId of [...requirement.placedVoucherIds]) {
        const voucher = table.vouchers[voucherId];
        if (
          !voucher ||
          voucher.location.type !== "placed" ||
          voucher.location.recipeOwnerId !== actor.id ||
          voucher.location.requirementId !== requirement.id
        ) {
          continue;
        }
        const owner = requireParticipant(table, voucher.ownerParticipantId);
        const remainingStock = remainingStockByOwner.get(owner.id) ?? owner.realIngredientStock ?? 0;
        if (remainingStock <= 0) {
          continue;
        }
        remainingStockByOwner.set(owner.id, remainingStock - 1);
        redeemVoucher(table, actor, voucherId);
      }
    }
    const outstandingByRequirement = new Map(
      recipe.requirements.map((requirement) => [
        requirement.id,
        requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length
      ])
    );
    const plannedRedemptions: Array<{ voucherId: string; requirementId: string }> = [];
    const initialHandIds = handVoucherIds(table, actor.id);
    for (const voucherId of initialHandIds) {
      const voucher = table.vouchers[voucherId];
      if (!voucher || voucher.location.type !== "hand" || voucher.location.participantId !== actor.id) {
        continue;
      }
      const requirement = recipe.requirements.find(
        (candidate) => candidate.ingredientId === voucher.ingredientId && (outstandingByRequirement.get(candidate.id) ?? 0) > 0
      );
      if (!requirement) {
        continue;
      }
      const owner = requireParticipant(table, voucher.ownerParticipantId);
      const remainingStock = remainingStockByOwner.get(owner.id) ?? owner.realIngredientStock ?? 0;
      if (remainingStock <= 0) {
        continue;
      }
      remainingStockByOwner.set(owner.id, remainingStock - 1);
      outstandingByRequirement.set(requirement.id, (outstandingByRequirement.get(requirement.id) ?? 0) - 1);
      plannedRedemptions.push({ voucherId, requirementId: requirement.id });
    }
    for (const planned of plannedRedemptions) {
      redeemVoucherFromHand(table, actor, planned.voucherId, planned.requirementId);
    }
    prepareDishIfRecipeComplete(table, actor);
  }
  passTurn(table, actor);
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
  if (actor.openingOfferingsCount >= OPENING_OFFERINGS_PER_PLAYER) {
    throw new GameError("Participant already deposited.", "already_deposited");
  }
  const voucher = requireVoucher(table, voucherId);
  requireVoucherInHand(voucher, actor.id);
  requireVoucherBackedByStock(table, voucher);
  voucher.location = { type: "platter" };
  actor.openingOfferingsCount += 1;
  actor.depositedInitial = actor.openingOfferingsCount >= OPENING_OFFERINGS_PER_PLAYER;
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
  requireVoucherBackedByStock(table, giveVoucher);
  if (takeVoucher.location.type !== "platter") {
    throw new GameError("Taken voucher is not in the platter.", "voucher_not_in_platter");
  }
  requireVoucherBackedByStock(table, takeVoucher);
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
  requireResolvedVoucherBackedByStock(table, giveAsset);
  requireResolvedVoucherBackedByStock(table, takeAsset);

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
  requested?: { ingredientId: string; quantity: number },
  offeredAssets?: PlatterAssetRef[],
  requestedAsset?: OfferAssetRequest
): Offer {
  if (table.phase !== "playing" && table.phase !== "settlement") {
    throw new GameError("Action requires phase playing or settlement.", "invalid_phase");
  }
  requireActive(actor);
  if (table.phase === "playing") {
    ensureBotCanUseBarter(actor);
  }
  if (toParticipantId === actor.id) {
    throw new GameError("Cannot trade with yourself.", "invalid_offer");
  }
  const recipient = requireParticipant(table, toParticipantId);
  requireActive(recipient);

  const normalizedOfferedAssets = normalizeOfferedAssets(offeredVoucherIds, offeredAssets);
  if (normalizedOfferedAssets.length === 0) {
    throw new GameError("Offer must include at least one asset.", "invalid_offer");
  }

  const normalizedRequestedAsset = requestedAsset ?? legacyRequestedAsset(recipient, requested);
  validateOfferAssetRequest(table, recipient, normalizedRequestedAsset);
  if (offerableUnreservedAssetQty(table, recipient.id, normalizedRequestedAsset) < normalizedRequestedAsset.quantity) {
    throw new GameError("Recipient does not have enough available assets for that offer.", "offer_unavailable");
  }

  const resolvedOfferedAssets = normalizedOfferedAssets.map((asset) => requirePlatterAsset(table, asset));
  for (const asset of resolvedOfferedAssets) {
    requireAssetInInventory(asset, actor.id);
    requireResolvedVoucherBackedByStock(table, asset);
  }
  if (requestsOfferedVoucherResource(resolvedOfferedAssets, normalizedRequestedAsset)) {
    throw new GameError("Offer must exchange different promise-card resources.", "invalid_offer");
  }

  const offerId = `offer_${table.nextId}`;
  table.nextId += 1;
  const offer: Offer = {
    id: offerId,
    fromParticipantId: actor.id,
    toParticipantId,
    offeredAssets: normalizedOfferedAssets.map((asset) => ({ ...asset })),
    offeredVoucherIds: [...offeredVoucherIds],
    requested: requested ? { ...requested } : undefined,
    requestedAsset: { ...normalizedRequestedAsset },
    acceptedAssets: [],
    acceptedVoucherIds: [],
    status: "pending",
    createdTurn: table.turn
  };
  table.offers[offer.id] = offer;
  for (const asset of resolvedOfferedAssets) {
    moveAssetToOfferLock(asset, offerId);
  }
  return offer;
}

function requestsOfferedVoucherResource(offeredAssets: ResolvedPlatterAsset[], requested: OfferAssetRequest): boolean {
  if (requested.kind !== "voucher") {
    return false;
  }
  return offeredAssets.some(
    (asset) =>
      asset.kind === "voucher" &&
      asset.value.ingredientId === requested.ingredientId &&
      (!requested.ownerParticipantId || asset.value.ownerParticipantId === requested.ownerParticipantId)
  );
}

function respondOffer(
  table: Table,
  actor: Participant,
  offerId: string,
  response: "accept" | "refuse",
  voucherIds: string[],
  acceptedAssets?: PlatterAssetRef[]
): void {
  if (table.phase !== "playing" && table.phase !== "settlement") {
    throw new GameError("Action requires phase playing or settlement.", "invalid_phase");
  }
  requireActive(actor);
  if (table.phase === "playing") {
    ensureBotCanUseBarter(actor);
  }
  const offer = requireOffer(table, offerId);
  if (offer.status !== "pending") {
    throw new GameError("Offer is not pending.", "offer_not_pending");
  }
  if (offer.toParticipantId !== actor.id) {
    throw new GameError("Only the recipient can respond to this offer.", "not_offer_recipient");
  }

  if (response === "refuse") {
    offer.status = "refused";
    releaseOfferedAssets(table, offer);
    delete table.offers[offer.id];
    return;
  }

  const requestedAsset = offer.requestedAsset ?? legacyRequestedAsset(actor, offer.requested);
  const acceptedAssetRefs = normalizeAcceptedAssets(voucherIds, acceptedAssets);
  if (acceptedAssetRefs.length !== requestedAsset.quantity) {
    throw new GameError("Accepted asset count does not match the request.", "invalid_offer_response");
  }
  const resolvedAcceptedAssets = acceptedAssetRefs.map((asset) => requirePlatterAsset(table, asset));
  for (const asset of resolvedAcceptedAssets) {
    requireAssetInInventory(asset, actor.id);
    requireResolvedVoucherBackedByStock(table, asset);
    if (!assetMatchesOfferRequest(asset, requestedAsset)) {
      throw new GameError("Accepted asset does not match the request.", "invalid_offer_response");
    }
  }

  offer.status = "accepted";
  offer.acceptedAssets = acceptedAssetRefs.map((asset) => ({ ...asset }));
  offer.acceptedVoucherIds = [...voucherIds];
  for (const asset of offer.offeredAssets.map((ref) => requirePlatterAsset(table, ref))) {
    moveAssetToInventory(asset, offer.toParticipantId);
  }
  for (const asset of resolvedAcceptedAssets) {
    moveAssetToInventory(asset, offer.fromParticipantId);
  }
  const creator = requireParticipant(table, offer.fromParticipantId);
  recordTransaction(
    table,
    creator,
    "Exchange",
    actor.name,
    assetListLabel(table, offer.offeredAssets),
    assetListLabel(table, acceptedAssetRefs),
    actor.id
  );
  delete table.offers[offer.id];
}

function cancelOffer(table: Table, actor: Participant, offerId: string): void {
  if (table.phase !== "playing" && table.phase !== "settlement") {
    throw new GameError("Action requires phase playing or settlement.", "invalid_phase");
  }
  const offer = requireOffer(table, offerId);
  if (offer.status !== "pending") {
    throw new GameError("Offer is not pending.", "offer_not_pending");
  }
  if (offer.fromParticipantId !== actor.id) {
    throw new GameError("Only the offer creator can cancel this offer.", "not_offer_creator");
  }
  offer.status = "cancelled";
  releaseOfferedAssets(table, offer);
  delete table.offers[offer.id];
}

function normalizeOfferedAssets(offeredVoucherIds: string[], offeredAssets?: PlatterAssetRef[]): PlatterAssetRef[] {
  if (offeredAssets && offeredAssets.length > 0) {
    return offeredAssets.map((asset) => ({ ...asset }));
  }
  return offeredVoucherIds.map((voucherId) => ({ kind: "voucher", id: voucherId }));
}

function normalizeAcceptedAssets(voucherIds: string[], acceptedAssets?: PlatterAssetRef[]): PlatterAssetRef[] {
  if (acceptedAssets && acceptedAssets.length > 0) {
    return acceptedAssets.map((asset) => ({ ...asset }));
  }
  return voucherIds.map((voucherId) => ({ kind: "voucher", id: voucherId }));
}

function legacyRequestedAsset(recipient: Participant, requested?: OfferRequest): OfferAssetRequest {
  if (!requested) {
    throw new GameError("Offer must request an asset.", "invalid_offer");
  }
  if (!Number.isInteger(requested.quantity) || requested.quantity <= 0) {
    throw new GameError("Offer request quantity must be positive.", "invalid_offer");
  }
  if (!INGREDIENTS.some((ingredient) => ingredient.id === requested.ingredientId)) {
    throw new GameError("Requested ingredient is unknown.", "invalid_offer");
  }
  if (!recipient.ingredientId || requested.ingredientId !== recipient.ingredientId) {
    throw new GameError("Legacy ingredient offers can only ask for the recipient's own ingredient.", "invalid_offer");
  }
  return { kind: "voucher", ingredientId: requested.ingredientId, ownerParticipantId: recipient.id, quantity: requested.quantity };
}

function validateOfferAssetRequest(table: Table, recipient: Participant, requested: OfferAssetRequest): void {
  if (!Number.isInteger(requested.quantity) || requested.quantity <= 0) {
    throw new GameError("Offer request quantity must be positive.", "invalid_offer");
  }
  if (requested.kind === "voucher") {
    if (!INGREDIENTS.some((ingredient) => ingredient.id === requested.ingredientId)) {
      throw new GameError("Requested ingredient is unknown.", "invalid_offer");
    }
    if (requested.ownerParticipantId) {
      requireParticipant(table, requested.ownerParticipantId);
    }
    return;
  }
  if (requested.dishId && !table.dishes[requested.dishId]) {
    throw new GameError("Requested dish is unknown.", "invalid_offer");
  }
  if (requested.makerParticipantId) {
    requireParticipant(table, requested.makerParticipantId);
  }
  if (offerableAssetQty(table, recipient.id, requested) < requested.quantity) {
    throw new GameError("Recipient does not hold enough requested assets.", "offer_unavailable");
  }
}

function offerableAssetQty(table: Table, participantId: string, requested: OfferAssetRequest): number {
  if (requested.kind === "voucher") {
    const participant = table.participants[participantId];
    if ((participant?.realIngredientStock ?? 0) <= 0) {
      return 0;
    }
    return Object.values(table.vouchers).filter(
      (voucher) =>
        voucher.ingredientId === requested.ingredientId &&
        (!requested.ownerParticipantId || voucher.ownerParticipantId === requested.ownerParticipantId) &&
        voucher.location.type === "hand" &&
        voucher.location.participantId === participantId &&
        voucherIsBackedByStock(table, voucher)
    ).length;
  }
  return Object.values(table.dishParts ?? {}).filter(
    (part) =>
      (!requested.dishId || part.dishId === requested.dishId) &&
      (!requested.makerParticipantId || part.makerParticipantId === requested.makerParticipantId) &&
      part.location.type === "inventory" &&
      part.location.participantId === participantId
  ).length;
}

function offerableUnreservedAssetQty(table: Table, participantId: string, requested: OfferAssetRequest): number {
  const rawAvailable = offerableAssetQty(table, participantId, requested);
  const pendingRequested = Object.values(table.offers)
    .filter((offer) => offer.status === "pending" && offer.toParticipantId === participantId)
    .filter((offer) => offer.requestedAsset && offerAssetRequestKey(offer.requestedAsset) === offerAssetRequestKey(requested))
    .reduce((total, offer) => total + (offer.requestedAsset?.quantity ?? 0), 0);
  return Math.max(0, rawAvailable - pendingRequested);
}

function offerAssetRequestKey(requested: OfferAssetRequest): string {
  if (requested.kind === "voucher") {
    return `voucher:${requested.ingredientId}:${requested.ownerParticipantId ?? ""}`;
  }
  return `dish_part:${requested.dishId ?? "*"}:${requested.makerParticipantId ?? ""}`;
}

function assetMatchesOfferRequest(asset: ResolvedPlatterAsset, requested: OfferAssetRequest): boolean {
  if (requested.kind === "voucher") {
    return (
      asset.kind === "voucher" &&
      asset.value.ingredientId === requested.ingredientId &&
      (!requested.ownerParticipantId || asset.value.ownerParticipantId === requested.ownerParticipantId)
    );
  }
  return (
    asset.kind === "dish_part" &&
    (!requested.dishId || asset.value.dishId === requested.dishId) &&
    (!requested.makerParticipantId || asset.value.makerParticipantId === requested.makerParticipantId)
  );
}

function autoRefuseUnavailableOffers(table: Table): void {
  const remainingByRequest = new Map<string, number>();
  for (const offer of Object.values(table.offers)) {
    if (offer.status !== "pending") {
      continue;
    }
    const recipient = table.participants[offer.toParticipantId];
    if (!recipient) {
      offer.status = "refused";
      releaseOfferedAssets(table, offer);
      delete table.offers[offer.id];
      continue;
    }
    if (!offeredAssetsStillLockedAndBacked(table, offer)) {
      offer.status = "refused";
      releaseOfferedAssets(table, offer);
      delete table.offers[offer.id];
      continue;
    }
    const requestedAsset = offer.requestedAsset ?? legacyRequestedAsset(recipient, offer.requested);
    const key = `${recipient.id}:${offerAssetRequestKey(requestedAsset)}`;
    const remaining = remainingByRequest.get(key) ?? offerableAssetQty(table, recipient.id, requestedAsset);
    if (remaining >= requestedAsset.quantity) {
      remainingByRequest.set(key, remaining - requestedAsset.quantity);
      continue;
    }
    recordScarcityPressure(table, requestedAsset, Math.max(1, requestedAsset.quantity - Math.max(0, remaining)));
    offer.status = "refused";
    releaseOfferedAssets(table, offer);
    delete table.offers[offer.id];
  }
}

function recordScarcityPressure(table: Table, requested: OfferAssetRequest, amount: number): void {
  if (requested.kind !== "voucher" || !requested.ingredientId) {
    return;
  }
  table.scarcityPressureByIngredient ??= {};
  table.scarcityPressureByIngredient[requested.ingredientId] =
    (table.scarcityPressureByIngredient[requested.ingredientId] ?? 0) + Math.max(1, amount);
}

function cancelAllPendingOffers(table: Table): void {
  for (const offer of Object.values(table.offers)) {
    if (offer.status === "pending") {
      offer.status = "cancelled";
      releaseOfferedAssets(table, offer);
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
    releaseOfferedAssets(table, offer);
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
  requireVoucherBackedByStock(table, voucher);
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

function prepareDishIfRecipeComplete(table: Table, actor: Participant): void {
  if (table.phase !== "playing") {
    return;
  }
  const recipe = table.recipes[actor.id];
  if (!recipe) {
    return;
  }
  if (recipe.requirements.every((requirement) => requirement.redeemedQty >= requirement.requiredQty)) {
    prepareDish(table, actor);
  }
}

function biteDish(table: Table, actor: Participant, dishId: string): void {
  requirePhase(table, "eating");
  requireActive(actor);
  const account = platterAccountForParticipant(table, actor.id);
  if (!account.cleared) {
    throw new GameError("Return all promise cards before eating.", "account_not_cleared");
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
  eatDishPart(table, actor, dish, part);
  completeIfAllFoodPartsEaten(table);
}

function biteAllHeldFoodParts(table: Table, actor: Participant): void {
  requirePhase(table, "eating");
  requireActive(actor);
  const account = platterAccountForParticipant(table, actor.id);
  if (!account.cleared) {
    throw new GameError("Return all promise cards before eating.", "account_not_cleared");
  }
  const heldParts = Object.values(table.dishParts ?? {})
    .filter((part) => part.location.type === "inventory" && part.location.participantId === actor.id)
    .sort((left, right) => left.id.localeCompare(right.id));
  if (heldParts.length === 0) {
    throw new GameError("You do not hold any uneaten food parts.", "dish_part_not_held");
  }
  for (const part of heldParts) {
    const dish = table.dishes[part.dishId];
    if (!dish) {
      throw new GameError("Dish not found.", "missing_dish");
    }
    eatDishPart(table, actor, dish, part);
  }
  completeIfAllFoodPartsEaten(table);
}

function eatDishPart(table: Table, actor: Participant, dish: Dish, part: DishPart): void {
  const biteCounts = dish.biteCounts ?? {};
  dish.biteCounts = biteCounts;
  const actorBites = biteCounts[actor.id] ?? 0;
  part.location = { type: "eaten", participantId: actor.id };
  dish.partsEaten = (dish.partsEaten ?? 0) + 1;
  dish.partsRemaining = Math.max(0, (dish.partsRemaining ?? dish.bitesRemaining ?? 0) - 1);
  dish.bitesRemaining = dish.partsRemaining;
  biteCounts[actor.id] = actorBites + 1;
  recordTransaction(table, actor, "Eat", actor.name, platterAssetLabel({ kind: "dish_part", value: part }), "Eaten");
}

function completeIfAllFoodPartsEaten(table: Table): void {
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

function moveAssetToOfferLock(asset: ResolvedPlatterAsset, offerId: string): void {
  if (asset.kind === "voucher") {
    asset.value.location = { type: "offer_lock", offerId };
    return;
  }
  asset.value.location = { type: "offer_lock", offerId };
}

function platterAssetLabel(asset: ResolvedPlatterAsset): string {
  if (asset.kind === "voucher") {
    return voucherCardLabel(asset.value);
  }
  return dishPartLabel(asset.value);
}

function assetListLabel(table: Table, assetRefs: PlatterAssetRef[]): string {
  return assetRefs.map((assetRef) => platterAssetLabel(requirePlatterAsset(table, assetRef))).join(", ");
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
        offer.requestedAsset?.kind === "voucher" &&
        offer.requestedAsset.ingredientId === ingredientId
    )
    .reduce((total, offer) => total + (offer.requestedAsset?.quantity ?? 0), 0);
  return Math.max(0, rawAvailable - pendingRequested);
}

function offeredAssetsStillLockedAndBacked(table: Table, offer: Offer): boolean {
  for (const assetRef of offer.offeredAssets) {
    const asset = requirePlatterAsset(table, assetRef);
    if (asset.kind === "voucher") {
      if (asset.value.location.type !== "offer_lock" || asset.value.location.offerId !== offer.id || !voucherIsBackedByStock(table, asset.value)) {
        return false;
      }
      continue;
    }
    if (asset.value.location.type !== "offer_lock" || asset.value.location.offerId !== offer.id) {
      return false;
    }
  }
  return true;
}

function releaseOfferedAssets(table: Table, offer: Offer): void {
  for (const assetRef of offer.offeredAssets) {
    const asset = requirePlatterAsset(table, assetRef);
    if (asset.kind === "voucher") {
      if (asset.value.location.type === "offer_lock" && asset.value.location.offerId === offer.id) {
        asset.value.location = { type: "hand", participantId: offer.fromParticipantId };
      }
      continue;
    }
    if (asset.value.location.type === "offer_lock" && asset.value.location.offerId === offer.id) {
      asset.value.location = { type: "inventory", participantId: offer.fromParticipantId };
    }
  }
}

function releaseOfferedVouchers(table: Table, offer: Offer): void {
  releaseOfferedAssets(table, offer);
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

function shouldGateTurn(table: Table, intent: Intent): boolean {
  switch (intent.type) {
    case "pass_turn":
    case "redeem_all_and_pass_turn":
      return true;
    case "platter_swap":
    case "platter_swap_ingredient":
    case "platter_asset_swap":
    case "platter_asset_swap_aggregate":
    case "create_offer":
    case "respond_offer":
    case "cancel_offer":
    case "place_voucher":
    case "redeem_voucher":
    case "redeem_from_hand":
    case "prepare":
    case "bite":
      return table.phase !== "eating";
    case "bite_all":
      return false;
    default:
      return false;
  }
}

function shouldAdvanceTurnAfterIntent(table: Table, intent: Intent): boolean {
  return intent.type === "pass_turn" || intent.type === "redeem_all_and_pass_turn";
}

function requireCurrentTurn(table: Table, actor: Participant): void {
  if (table.currentTurnParticipantId && table.currentTurnParticipantId !== actor.id) {
    const current = table.participants[table.currentTurnParticipantId];
    throw new GameError(`It is ${current?.name ?? "another participant"}'s turn.`, "not_current_turn");
  }
  if (!table.currentTurnParticipantId) {
    table.currentTurnParticipantId = nextTurnParticipantId(table);
  }
  if (table.currentTurnParticipantId && table.currentTurnParticipantId !== actor.id) {
    throw new GameError("It is not this participant's turn.", "not_current_turn");
  }
}

function advanceTurn(table: Table, actorParticipantId: string): void {
  if (table.phase === "lobby" || table.phase === "deposit" || table.phase === "complete") {
    table.currentTurnParticipantId = table.phase === "complete" ? undefined : table.currentTurnParticipantId;
    return;
  }
  table.currentTurnParticipantId = nextTurnParticipantId(table, actorParticipantId);
}

function nextTurnParticipantId(table: Table, afterParticipantId?: string): string | undefined {
  const turnOrderIds = table.participantOrder.filter((participantId) => table.participants[participantId]?.role === "active");
  const candidates = turnOrderIds
    .map((participantId) => table.participants[participantId])
    .filter((participant): participant is Participant => Boolean(participant) && participantCanReceiveTurn(table, participant));
  if (candidates.length === 0) {
    return undefined;
  }
  if (!afterParticipantId) {
    return candidates[0]?.id;
  }
  const afterIndex = turnOrderIds.indexOf(afterParticipantId);
  const sorted = [...candidates].sort((left, right) => {
    const leftIndex = turnOrderIds.indexOf(left.id);
    const rightIndex = turnOrderIds.indexOf(right.id);
    const normalizedLeft = leftIndex > afterIndex ? leftIndex : leftIndex + turnOrderIds.length;
    const normalizedRight = rightIndex > afterIndex ? rightIndex : rightIndex + turnOrderIds.length;
    return normalizedLeft - normalizedRight;
  });
  return sorted[0]?.id;
}

function participantCanReceiveTurn(table: Table, participant: Participant): boolean {
  if (participant.role !== "active") {
    return false;
  }
  if (table.phase === "playing") {
    return true;
  }
  return table.phase === "settlement" || table.phase === "eating";
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

function requireVoucherBackedByStock(table: Table, voucher: Voucher): void {
  if (!voucherIsBackedByStock(table, voucher)) {
    throw new GameError("Voucher owner has no real stock remaining.", "voucher_stock_depleted");
  }
}

function voucherIsBackedByStock(table: Table, voucher?: Voucher): boolean {
  if (!voucher) {
    return false;
  }
  const owner = table.participants[voucher.ownerParticipantId];
  return (owner?.realIngredientStock ?? 0) > 0;
}

function requireResolvedVoucherBackedByStock(table: Table, asset: ResolvedPlatterAsset): void {
  if (asset.kind === "voucher") {
    requireVoucherBackedByStock(table, asset.value);
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
