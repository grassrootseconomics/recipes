import { INGREDIENTS } from "./constants.js";
import {
  activeParticipants,
  handVoucherIds,
  inventoryDishPartIds,
  offerableUnreservedIngredientQty,
  platterAccountForParticipant,
  platterDishPartIds,
  platterVoucherIds
} from "./game.js";
import type {
  Dish,
  DishPartGroup,
  DishPart,
  FoodPartLocationSummary,
  Offer,
  OfferSnapshot,
  Participant,
  PublicParticipant,
  Recipe,
  Snapshot,
  Table,
  TableTimer,
  TransactionRecord,
  Voucher,
  VoucherGroup,
  VoucherLocationSummary
} from "./types.js";

const WITNESS_TRANSACTION_HISTORY_LIMIT = 100;
const TRANSACTION_HISTORY_LIMIT = 100;

export function buildSnapshot(table: Table, viewerParticipantId?: string): Snapshot {
  const viewer = viewerParticipantId ? table.participants[viewerParticipantId] : undefined;
  const isWitness = viewer?.role === "witness";
  const isKnownViewer = Boolean(viewer);

  const participants = table.participantOrder
    .map((participantId) => table.participants[participantId])
    .filter((participant): participant is Participant => Boolean(participant))
    .map((participant) => publicParticipant(table, participant));

  const ownHand = isKnownViewer ? handVoucherIds(table, viewerParticipantId as string).map((id) => cloneVoucher(table.vouchers[id])) : [];
  const ownFoodParts = isKnownViewer
    ? inventoryDishPartIds(table, viewerParticipantId as string).map((id) => cloneDishPart(table.dishParts[id]))
    : [];
  const platterFoodParts = platterDishPartIds(table).map((id) => cloneDishPart(table.dishParts[id]));
  const visibleDishParts = isWitness ? platterFoodParts : [...ownFoodParts, ...platterFoodParts];
  const transactionHistory = table.transactionHistory ?? [];
  const visibleTransactionHistory = transactionHistory.slice(-(isWitness ? WITNESS_TRANSACTION_HISTORY_LIMIT : TRANSACTION_HISTORY_LIMIT));
  const ownRecipe = isKnownViewer ? cloneRecipe(table.recipes[viewerParticipantId as string]) : undefined;
  const offers = Object.values(table.offers)
    .filter((offer) => offer.status === "pending")
    .filter((offer) => isWitness || offer.fromParticipantId === viewerParticipantId || offer.toParticipantId === viewerParticipantId)
    .map((offer) => cloneOffer(table, offer));

  const snapshot: Snapshot = {
    tableCode: table.code,
    seed: table.seed,
    version: table.version,
    phase: table.phase,
    paused: table.paused,
    viewerParticipantId,
    viewerRole: viewer?.role,
    hostParticipantId: table.hostParticipantId,
    turn: table.turn,
    participants,
    ingredients: INGREDIENTS,
    platter: platterVoucherIds(table).map((id) => cloneVoucher(table.vouchers[id])),
    platterFoodParts,
    ownHandGroups: groupVouchers(ownHand),
    platterVoucherGroups: groupVouchers(platterVoucherIds(table).map((id) => table.vouchers[id])),
    ownFoodPartGroups: groupDishParts(ownFoodParts),
    platterFoodPartGroups: groupDishParts(platterFoodParts),
    dishes: Object.values(table.dishes).map(cloneDish),
    dishParts: visibleDishParts,
    transactionHistory: visibleTransactionHistory.map(cloneTransaction),
    transactionCursor: transactionHistory.length,
    transactionHistoryComplete: visibleTransactionHistory.length === transactionHistory.length,
    transactionHistoryTotal: transactionHistory.length,
    dishCounts: Object.fromEntries(activeParticipants(table).map((participant) => [participant.id, participant.dishCount])),
    winners: [...table.winnerParticipantIds],
    targetDishCount: table.targetDishCount,
    stockPerIngredient: table.stockPerIngredient,
    timer: cloneTimer(table.timer),
    ownHand,
    ownFoodParts,
    ownRecipe,
    offers
  };

  if (isWitness) {
    snapshot.foodPartLocationSummary = summarizeFoodPartLocations(table);
    snapshot.voucherLocationSummary = summarizeVoucherLocations(table);
    snapshot.allRecipes = Object.fromEntries(
      Object.entries(table.recipes).map(([participantId, recipe]) => [participantId, cloneRecipe(recipe) as Recipe])
    );
  }

  return snapshot;
}

function publicParticipant(table: Table, participant: Participant): PublicParticipant {
  const account = platterAccountForParticipant(table, participant.id);
  return {
    id: participant.id,
    name: participant.name,
    kind: participant.kind,
    role: participant.role,
    isHost: participant.isHost,
    botType: participant.botType,
    ingredientId: participant.ingredientId,
    realIngredientStock: participant.realIngredientStock,
    offerableOwnIngredientQty: participant.ingredientId ? offerableUnreservedIngredientQty(table, participant.id, participant.ingredientId) : 0,
    ownCardsInPlatter: account.ownCardsInPlatter,
    platterDebt: account.platterDebt,
    platterShortfall: account.platterShortfall,
    cleared: account.cleared,
    dishCount: participant.dishCount,
    depositedInitial: participant.depositedInitial,
    connected: participant.connected
  };
}

function cloneVoucher(voucher: Voucher): Voucher {
  return {
    ...voucher,
    location: { ...voucher.location }
  };
}

function cloneRecipe(recipe?: Recipe): Recipe | undefined {
  if (!recipe) {
    return undefined;
  }
  return {
    ...recipe,
    unitSingular: recipe.unitSingular,
    unitPlural: recipe.unitPlural,
    realIngredientIds: [...recipe.realIngredientIds],
    matchedRealIngredientIds: [...recipe.matchedRealIngredientIds],
    fallbackIngredientIds: [...recipe.fallbackIngredientIds],
    requirements: recipe.requirements.map((requirement) => ({
      ...requirement,
      placedVoucherIds: [...requirement.placedVoucherIds]
    }))
  };
}

function cloneOffer(table: Table, offer: Offer): OfferSnapshot {
  return {
    ...offer,
    offeredVoucherIds: [...offer.offeredVoucherIds],
    offeredVouchers: offer.offeredVoucherIds
      .map((voucherId) => table.vouchers[voucherId])
      .filter((voucher): voucher is Voucher => Boolean(voucher))
      .map(cloneVoucher),
    acceptedVoucherIds: [...offer.acceptedVoucherIds],
    requested: { ...offer.requested }
  };
}

function cloneDish(dish: Dish): Dish {
  return { ...dish, biteCounts: { ...dish.biteCounts } };
}

function cloneDishPart(part: DishPart): DishPart {
  return {
    ...part,
    location: { ...part.location }
  };
}

function groupVouchers(vouchers: Voucher[]): VoucherGroup[] {
  const groups = new Map<string, VoucherGroup>();
  for (const voucher of vouchers) {
    const key = `${voucher.ingredientId}:${voucher.ownerParticipantId}`;
    const existing = groups.get(key);
    if (existing) {
      existing.count += 1;
      continue;
    }
    groups.set(key, {
      ingredientId: voucher.ingredientId,
      ownerParticipantId: voucher.ownerParticipantId,
      count: 1
    });
  }
  return [...groups.values()].sort((left, right) =>
    `${left.ingredientId}:${left.ownerParticipantId}`.localeCompare(`${right.ingredientId}:${right.ownerParticipantId}`)
  );
}

function groupDishParts(parts: DishPart[]): DishPartGroup[] {
  const groups = new Map<string, DishPartGroup>();
  for (const part of parts) {
    const key = `${part.dishId}:${part.makerParticipantId}`;
    const existing = groups.get(key);
    if (existing) {
      existing.count += 1;
      continue;
    }
    groups.set(key, {
      dishId: part.dishId,
      dishName: part.dishName,
      makerParticipantId: part.makerParticipantId,
      unitSingular: part.unitSingular,
      unitPlural: part.unitPlural,
      count: 1
    });
  }
  return [...groups.values()].sort((left, right) =>
    `${left.dishName}:${left.makerParticipantId}`.localeCompare(`${right.dishName}:${right.makerParticipantId}`)
  );
}

function summarizeFoodPartLocations(table: Table): FoodPartLocationSummary[] {
  const summaries = new Map<string, FoodPartLocationSummary>();
  for (const part of Object.values(table.dishParts ?? {})) {
    const participantId = part.location.participantId ?? "";
    const key = `${part.dishId}:${part.location.type}:${participantId}`;
    const existing = summaries.get(key);
    if (existing) {
      existing.count += 1;
      continue;
    }
    summaries.set(key, {
      dishId: part.dishId,
      dishName: part.dishName,
      unitSingular: part.unitSingular,
      unitPlural: part.unitPlural,
      location: { ...part.location },
      count: 1
    });
  }
  return [...summaries.values()].sort((left, right) => {
    const leftParticipant = left.location.participantId ?? "";
    const rightParticipant = right.location.participantId ?? "";
    return `${left.dishName}:${left.location.type}:${leftParticipant}`.localeCompare(
      `${right.dishName}:${right.location.type}:${rightParticipant}`
    );
  });
}

function summarizeVoucherLocations(table: Table): VoucherLocationSummary[] {
  const summaries = new Map<string, VoucherLocationSummary>();
  for (const voucher of Object.values(table.vouchers)) {
    const participantId = voucher.location.participantId ?? "";
    const recipeOwnerId = voucher.location.recipeOwnerId ?? "";
    const requirementId = voucher.location.requirementId ?? "";
    const offerId = voucher.location.offerId ?? "";
    const key = `${voucher.ingredientId}:${voucher.ownerParticipantId}:${voucher.location.type}:${participantId}:${recipeOwnerId}:${requirementId}:${offerId}`;
    const existing = summaries.get(key);
    if (existing) {
      existing.count += 1;
      continue;
    }
    summaries.set(key, {
      ingredientId: voucher.ingredientId,
      ownerParticipantId: voucher.ownerParticipantId,
      location: { ...voucher.location },
      count: 1
    });
  }
  return [...summaries.values()].sort((left, right) => {
    const leftParticipant = left.location.participantId ?? "";
    const rightParticipant = right.location.participantId ?? "";
    return `${left.ingredientId}:${left.ownerParticipantId}:${left.location.type}:${leftParticipant}`.localeCompare(
      `${right.ingredientId}:${right.ownerParticipantId}:${right.location.type}:${rightParticipant}`
    );
  });
}

function cloneTransaction(transaction: TransactionRecord): TransactionRecord {
  return { ...transaction };
}

function cloneTimer(timer?: TableTimer): TableTimer | undefined {
  return timer ? { ...timer } : undefined;
}
