import { applyIntent, getUsefulRequirementIds, handVoucherIds, platterVoucherIds } from "./game.js";
import { hashString } from "./rng.js";
import { buildSnapshot } from "./snapshots.js";
import type { Intent, PlatterAssetRef, PublicParticipant, Snapshot, Table, Voucher } from "./types.js";

const DEFAULT_BOT_RUN_BUDGET = 300;

export interface BotDecision {
  intent: Intent;
  reason: string;
}

export function decideBotIntent(table: Table, botParticipantId: string): BotDecision | undefined {
  const participant = table.participants[botParticipantId];
  if (!participant || participant.kind !== "bot" || participant.role !== "active") {
    return undefined;
  }
  if (table.paused) {
    return undefined;
  }
  if (table.turnMode === "round_robin" && table.phase !== "deposit" && table.currentTurnParticipantId !== botParticipantId) {
    return undefined;
  }
  const snapshot = buildSnapshot(table, botParticipantId);
  if (snapshot.allHands || snapshot.allRecipes || snapshot.allVouchers) {
    throw new Error("Bot snapshot contains hidden information.");
  }

  if (snapshot.phase === "deposit") {
    if (participant.depositedInitial) {
      return undefined;
    }
    const firstVoucher = snapshot.ownHand.find((voucher) => voucherHasStock(snapshot, voucher));
    return firstVoucher ? { intent: { type: "deposit", voucherId: firstVoucher.id }, reason: "required initial deposit" } : undefined;
  }

  if (snapshot.phase === "settlement") {
    return decideSettlementSwap(table, botParticipantId, snapshot) ?? roundRobinPass(table);
  }

  if (snapshot.phase === "eating") {
    return decideBite(table, botParticipantId, snapshot) ?? roundRobinPass(table);
  }

  if (snapshot.phase !== "playing") {
    return undefined;
  }

  const acceptDecision = decideAcceptOffer(snapshot);
  if (acceptDecision) {
    return acceptDecision;
  }

  const prepareDecision = decidePrepare(snapshot);
  if (prepareDecision) {
    return prepareDecision;
  }

  const redeemDecision = decideRedeem(snapshot);
  if (redeemDecision) {
    return redeemDecision;
  }

  const placeDecision = decidePlace(table, botParticipantId, snapshot);
  if (placeDecision) {
    return placeDecision;
  }

  const poolDecision = participant.botType !== "barter_only" ? decidePoolSwap(table, botParticipantId, snapshot) : undefined;
  if (poolDecision) {
    return poolDecision;
  }

  if (participant.botType !== "pool_only") {
    return decideCreateOffer(table, botParticipantId, snapshot) ?? roundRobinPass(table);
  }

  return roundRobinPass(table);
}

function roundRobinPass(table: Table): BotDecision | undefined {
  return table.turnMode === "round_robin" ? { intent: { type: "pass_turn" }, reason: "no useful turn action" } : undefined;
}

export function runBotTurn(table: Table, botParticipantId: string): BotDecision | undefined {
  const decision = decideBotIntent(table, botParticipantId);
  if (!decision) {
    return undefined;
  }
  applyIntent(table, botParticipantId, decision.intent);
  return decision;
}

export function runBots(table: Table, maxTurns = DEFAULT_BOT_RUN_BUDGET): BotDecision[] {
  const decisions: BotDecision[] = [];
  for (let turn = 0; turn < maxTurns; turn += 1) {
    let progressed = false;
    const botIds = table.participantOrder.filter((participantId) => table.participants[participantId]?.kind === "bot");
    for (const botId of botIds) {
      const decision = runBotTurn(table, botId);
      if (decision) {
        decisions.push(decision);
        progressed = true;
      }
    }
    if (!progressed) {
      break;
    }
  }
  for (let passCount = 0; passCount < table.participantOrder.length; passCount += 1) {
    const current = table.currentTurnParticipantId ? table.participants[table.currentTurnParticipantId] : undefined;
    if (
      table.turnMode !== "round_robin" ||
      (table.phase !== "playing" && table.phase !== "settlement" && table.phase !== "eating") ||
      current?.kind !== "bot" ||
      current.role !== "active"
    ) {
      break;
    }
    const passIntent: Intent = { type: "pass_turn" };
    applyIntent(table, current.id, passIntent);
    decisions.push({ intent: passIntent, reason: "bot run budget exhausted; pass turn to avoid stalling" });
  }
  return decisions;
}

function decidePrepare(snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const complete = snapshot.ownRecipe.requirements.every((requirement) => requirement.redeemedQty >= requirement.requiredQty);
  return complete ? { intent: { type: "prepare" }, reason: "recipe complete" } : undefined;
}

function decideSettlementSwap(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  if (!bot) {
    return undefined;
  }

  if (bot.platterDebt > 0) {
    const ownVoucher = snapshot.platter.find((voucher) => voucher.ownerParticipantId === botParticipantId && voucherHasStock(snapshot, voucher));
    const give = preferredSettlementGive(snapshot, botParticipantId, false);
    if (ownVoucher && give) {
      return {
        intent: {
          type: "platter_asset_swap",
          give,
          take: { kind: "voucher", id: ownVoucher.id }
        },
        reason: "settle platter debt"
      };
    }
  }

  if (bot.platterShortfall > 0) {
    const ownVoucher = snapshot.ownHand.find((voucher) => voucher.ownerParticipantId === botParticipantId && voucherHasStock(snapshot, voucher));
    const take = preferredSettlementTake(snapshot, botParticipantId);
    if (ownVoucher && take) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "voucher", id: ownVoucher.id },
          take
        },
        reason: "settle platter shortfall"
      };
    }
  }

  if (bot.cleared && snapshot.platterFoodParts.length > 0) {
    const give = snapshot.ownHand.find((voucher) => voucher.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, voucher));
    const take = deterministicFoodPartRef(table, botParticipantId, snapshot.platterFoodParts.map((part) => part.id));
    if (give && take) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "voucher", id: give.id },
          take
        },
        reason: "clear food part from platter"
      };
    }
  }

  return undefined;
}

function preferredSettlementGive(snapshot: Snapshot, botParticipantId: string, allowOwnVoucher: boolean): PlatterAssetRef | undefined {
  const foodPart = snapshot.ownFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  const voucher = snapshot.ownHand.find((candidate) => (allowOwnVoucher || candidate.ownerParticipantId !== botParticipantId) && voucherHasStock(snapshot, candidate));
  return voucher ? { kind: "voucher", id: voucher.id } : undefined;
}

function preferredSettlementTake(snapshot: Snapshot, botParticipantId: string): PlatterAssetRef | undefined {
  const foodPart = snapshot.platterFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  const voucher = snapshot.platter.find((candidate) => candidate.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, candidate));
  return voucher ? { kind: "voucher", id: voucher.id } : undefined;
}

function deterministicFoodPartRef(table: Table, botParticipantId: string, partIds: string[]): PlatterAssetRef | undefined {
  const [id] = [...partIds].sort(
    (left, right) =>
      hashString(`${table.seed}:settlement:${table.turn}:${botParticipantId}:${left}`) -
      hashString(`${table.seed}:settlement:${table.turn}:${botParticipantId}:${right}`)
  );
  return id ? { kind: "dish_part", id } : undefined;
}

function decideBite(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  if (!bot?.cleared) {
    return undefined;
  }
  const heldDishIds = new Set(snapshot.ownFoodParts.map((part) => part.dishId));
  const legalDishes = snapshot.dishes.filter((dish) => heldDishIds.has(dish.id));
  if (legalDishes.length === 0) {
    return undefined;
  }
  const [dish] = legalDishes.sort(
    (left, right) =>
      hashString(`${table.seed}:bite:${table.turn}:${botParticipantId}:${left.id}`) -
      hashString(`${table.seed}:bite:${table.turn}:${botParticipantId}:${right.id}`)
  );
  return { intent: { type: "bite", dishId: dish.id }, reason: "take a legal dish bite" };
}

function decideRedeem(snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  for (const requirement of snapshot.ownRecipe.requirements) {
    const voucherId = requirement.placedVoucherIds[0];
    if (voucherId) {
      return { intent: { type: "redeem_voucher", voucherId }, reason: "redeem placed voucher" };
    }
  }
  return undefined;
}

function decidePlace(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  for (const voucher of snapshot.ownHand.filter((candidate) => voucherHasStock(snapshot, candidate))) {
    const usefulRequirementIds = getUsefulRequirementIds(table, botParticipantId, voucher.ingredientId);
    const requirementId = usefulRequirementIds[0];
    if (requirementId) {
      return {
        intent: { type: "place_voucher", voucherId: voucher.id, requirementId },
        reason: "place useful voucher"
      };
    }
  }
  return undefined;
}

function decideAcceptOffer(snapshot: Snapshot): BotDecision | undefined {
  for (const offer of snapshot.offers) {
    if (offer.status !== "pending" || offer.toParticipantId !== snapshot.viewerParticipantId) {
      continue;
    }
    const matching = snapshot.ownHand
      .filter((voucher) => voucher.ingredientId === offer.requested.ingredientId)
      .filter((voucher) => voucherHasStock(snapshot, voucher))
      .slice(0, offer.requested.quantity);
    if (matching.length === offer.requested.quantity) {
      return {
        intent: {
          type: "respond_offer",
          offerId: offer.id,
          response: "accept",
          voucherIds: matching.map((voucher) => voucher.id)
        },
        reason: "can satisfy structured offer"
      };
    }
  }
  return undefined;
}

function decidePoolSwap(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const neededIngredients = snapshot.ownRecipe.requirements
    .filter((requirement) => requirement.requiredQty > requirement.redeemedQty + requirement.placedVoucherIds.length)
    .map((requirement) => requirement.ingredientId);
  const take = snapshot.platter.find((voucher) => neededIngredients.includes(voucher.ingredientId) && voucherHasStock(snapshot, voucher));
  if (!take) {
    return undefined;
  }
  const give = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand);
  if (!give) {
    return undefined;
  }
  return {
    intent: { type: "platter_swap", giveVoucherId: give.id, takeVoucherId: take.id },
    reason: "platter has useful voucher"
  };
}

function decideCreateOffer(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const give = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand);
  if (!give) {
    return undefined;
  }
  const needed = snapshot.ownRecipe.requirements.find(
    (requirement) => requirement.requiredQty > requirement.redeemedQty + requirement.placedVoucherIds.length
  );
  if (!needed) {
    return undefined;
  }
  const target = snapshot.participants.find(
    (participant) =>
      participant.id !== botParticipantId &&
      participant.role === "active" &&
      participant.ingredientId === needed.ingredientId &&
      participant.offerableOwnIngredientQty > 0
  );
  if (!target) {
    return undefined;
  }
  const existingPending = snapshot.offers.some((offer) => offer.status === "pending" && offer.fromParticipantId === botParticipantId);
  if (existingPending) {
    return undefined;
  }
  return {
    intent: {
      type: "create_offer",
      toParticipantId: target.id,
      offeredVoucherIds: [give.id],
      requested: { ingredientId: needed.ingredientId, quantity: 1 }
    },
    reason: "request needed ingredient by structured offer"
  };
}

function firstSurplusVoucher(table: Table, participantId: string, hand: Voucher[]): Voucher | undefined {
  const backedHand = hand.filter((voucher) => {
    const owner = table.participants[voucher.ownerParticipantId];
    return (owner?.realIngredientStock ?? 0) > 0;
  });
  const useful = new Set(
    backedHand
      .flatMap((voucher) => getUsefulRequirementIds(table, participantId, voucher.ingredientId).map(() => voucher.id))
  );
  return backedHand.find((voucher) => !useful.has(voucher.id)) ?? backedHand[0];
}

function voucherHasStock(snapshot: Snapshot, voucher: Voucher): boolean {
  const owner = snapshot.participants.find((participant) => participant.id === voucher.ownerParticipantId);
  return (owner?.realIngredientStock ?? 0) > 0;
}

export function botOnlyVisibleHandIds(table: Table, botParticipantId: string): string[] {
  return handVoucherIds(table, botParticipantId);
}

export function visiblePlatterIdsForBot(table: Table): string[] {
  return platterVoucherIds(table);
}
