import { INGREDIENTS } from "./constants.js";
import { activeParticipants, handVoucherIds, platterVoucherIds } from "./game.js";
import type { Dish, Offer, OfferSnapshot, Participant, PublicParticipant, Recipe, Snapshot, Table, TableTimer, TransactionRecord, Voucher } from "./types.js";

export function buildSnapshot(table: Table, viewerParticipantId?: string): Snapshot {
  const viewer = viewerParticipantId ? table.participants[viewerParticipantId] : undefined;
  const isWitness = viewer?.role === "witness";
  const isKnownViewer = Boolean(viewer);

  const participants = table.participantOrder
    .map((participantId) => table.participants[participantId])
    .filter((participant): participant is Participant => Boolean(participant))
    .map((participant) => publicParticipant(table, participant));

  const ownHand = isKnownViewer ? handVoucherIds(table, viewerParticipantId as string).map((id) => cloneVoucher(table.vouchers[id])) : [];
  const ownRecipe = isKnownViewer ? cloneRecipe(table.recipes[viewerParticipantId as string]) : undefined;
  const offers = Object.values(table.offers)
    .filter((offer) => offer.status === "pending")
    .filter((offer) => isWitness || offer.fromParticipantId === viewerParticipantId || offer.toParticipantId === viewerParticipantId)
    .map((offer) => cloneOffer(table, offer));

  const snapshot: Snapshot = {
    tableCode: table.code,
    seed: table.seed,
    phase: table.phase,
    paused: table.paused,
    viewerParticipantId,
    viewerRole: viewer?.role,
    hostParticipantId: table.hostParticipantId,
    turn: table.turn,
    participants,
    ingredients: INGREDIENTS,
    platter: platterVoucherIds(table).map((id) => cloneVoucher(table.vouchers[id])),
    dishes: Object.values(table.dishes).map(cloneDish),
    transactionHistory: (table.transactionHistory ?? []).map(cloneTransaction),
    dishCounts: Object.fromEntries(activeParticipants(table).map((participant) => [participant.id, participant.dishCount])),
    winners: [...table.winnerParticipantIds],
    targetDishCount: table.targetDishCount,
    stockPerIngredient: table.stockPerIngredient,
    timer: cloneTimer(table.timer),
    ownHand,
    ownRecipe,
    offers
  };

  if (isWitness) {
    snapshot.allHands = Object.fromEntries(
      table.participantOrder.map((participantId) => [participantId, handVoucherIds(table, participantId).map((id) => cloneVoucher(table.vouchers[id]))])
    );
    snapshot.allRecipes = Object.fromEntries(
      Object.entries(table.recipes).map(([participantId, recipe]) => [participantId, cloneRecipe(recipe) as Recipe])
    );
    snapshot.allVouchers = Object.values(table.vouchers).map(cloneVoucher);
  }

  return snapshot;
}

function publicParticipant(table: Table, participant: Participant): PublicParticipant {
  return {
    id: participant.id,
    name: participant.name,
    kind: participant.kind,
    role: participant.role,
    isHost: participant.isHost,
    botType: participant.botType,
    ingredientId: participant.ingredientId,
    realIngredientStock: participant.realIngredientStock,
    offerableOwnIngredientQty: participant.ingredientId ? offerableIngredientQty(table, participant.id, participant.ingredientId) : 0,
    dishCount: participant.dishCount,
    depositedInitial: participant.depositedInitial,
    connected: participant.connected
  };
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

function cloneTransaction(transaction: TransactionRecord): TransactionRecord {
  return { ...transaction };
}

function cloneTimer(timer?: TableTimer): TableTimer | undefined {
  return timer ? { ...timer } : undefined;
}
