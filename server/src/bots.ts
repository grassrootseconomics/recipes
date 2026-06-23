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
  if (table.phase !== "deposit" && table.currentTurnParticipantId !== botParticipantId) {
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
    return decideSettlementSwap(table, botParticipantId, snapshot) ?? roundRobinPass();
  }

  if (snapshot.phase === "eating") {
    return decideBite(table, botParticipantId, snapshot) ?? roundRobinPass();
  }

  if (snapshot.phase !== "playing") {
    return undefined;
  }

  const poolDecision = participant.botType !== "barter_only" ? decidePoolSwap(table, botParticipantId, snapshot) : undefined;
  if (poolDecision) {
    return poolDecision;
  }

  const acceptDecision = decideAcceptOffer(snapshot);
  if (acceptDecision) {
    return acceptDecision;
  }

  if (participant.botType !== "pool_only") {
    const offerDecision = decideCreateOffer(table, botParticipantId, snapshot);
    if (offerDecision) {
      return offerDecision;
    }
  }

  const redeemAndPassDecision = decideRedeemAllAndPass(table, botParticipantId, snapshot);
  if (redeemAndPassDecision) {
    return redeemAndPassDecision;
  }

  return roundRobinPass();
}

function roundRobinPass(): BotDecision {
  return { intent: { type: "pass_turn" }, reason: "no useful turn action" };
}

export function runBotTurn(table: Table, botParticipantId: string): BotDecision | undefined {
  const decision = decideBotIntent(table, botParticipantId);
  if (!decision) {
    return undefined;
  }
  applyIntent(table, botParticipantId, decision.intent);
  return decision;
}

export function runBots(table: Table, maxTurns = DEFAULT_BOT_RUN_BUDGET, onStep?: (decision: BotDecision) => void): BotDecision[] {
  const decisions: BotDecision[] = [];
  for (let turn = 0; turn < maxTurns; turn += 1) {
    let progressed = false;
    const botIds = table.participantOrder.filter((participantId) => table.participants[participantId]?.kind === "bot");
    for (const botId of botIds) {
      const decision = runBotTurn(table, botId);
      if (decision) {
        decisions.push(decision);
        onStep?.(decision);
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
      (table.phase !== "playing" && table.phase !== "settlement" && table.phase !== "eating") ||
      current?.kind !== "bot" ||
      current.role !== "active"
    ) {
      break;
    }
    const passIntent: Intent = { type: "pass_turn" };
    applyIntent(table, current.id, passIntent);
    const decision = { intent: passIntent, reason: "bot run budget exhausted; pass turn to avoid stalling" };
    decisions.push(decision);
    onStep?.(decision);
  }
  return decisions;
}

function decideSettlementSwap(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  if (!bot) {
    return undefined;
  }
  if (botJustMadeSettlementSwap(table, botParticipantId)) {
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

  if (bot.foreignCardsInHand > 0 && snapshot.platterFoodParts.length > 0) {
    const returnCandidate = snapshot.ownHand
      .filter((voucher) => voucher.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, voucher))
      .map((voucher) => {
        const owner = snapshot.participants.find((participant) => participant.id === voucher.ownerParticipantId);
        const matchingPart = snapshot.platterFoodParts.find((part) => part.makerParticipantId === voucher.ownerParticipantId);
        return { voucher, owner, matchingPart };
      })
      .find(({ owner, matchingPart }) => (owner?.platterShortfall ?? 0) > 0 && matchingPart);
    if (returnCandidate?.matchingPart) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "voucher", id: returnCandidate.voucher.id },
          take: { kind: "dish_part", id: returnCandidate.matchingPart.id }
        },
        reason: "return a foreign promise card during settlement"
      };
    }
  }

  if (
    bot.ownCardsInOtherHands > 0 &&
    !snapshot.platterFoodParts.some((part) => part.makerParticipantId === botParticipantId)
  ) {
    const takeAsset = preferredFoodPartSeedTake(snapshot, botParticipantId);
    const foodPart = snapshot.ownFoodParts.find((part) => part.makerParticipantId === botParticipantId);
    if (takeAsset && foodPart) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "dish_part", id: foodPart.id },
          take: takeAsset
        },
        reason: "seed a food part so another player can return an own promise card"
      };
    }
  }

  if (bot.platterShortfall > 0) {
    if (bot.ownCardsInOtherHands > 0 && snapshot.platterFoodParts.length > 0) {
      return undefined;
    }
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

function botJustMadeSettlementSwap(table: Table, botParticipantId: string): boolean {
  const last = table.transactionHistory.at(-1);
  return last?.participantId === botParticipantId && last.action === "Settlement Swap";
}

function preferredSettlementGive(snapshot: Snapshot, botParticipantId: string, allowOwnVoucher: boolean): PlatterAssetRef | undefined {
  const foodPart = snapshot.ownFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  const usefulForeignVoucher = snapshot.ownHand.find((candidate) => {
    if (candidate.ownerParticipantId === botParticipantId || !voucherHasStock(snapshot, candidate)) {
      return false;
    }
    const owner = snapshot.participants.find((participant) => participant.id === candidate.ownerParticipantId);
    return (owner?.platterShortfall ?? 0) > 0;
  });
  if (usefulForeignVoucher) {
    return { kind: "voucher", id: usefulForeignVoucher.id };
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

function preferredFoodPartSeedTake(snapshot: Snapshot, botParticipantId: string): PlatterAssetRef | undefined {
  const ownVoucher = snapshot.platter.find((voucher) => voucher.ownerParticipantId === botParticipantId && voucherHasStock(snapshot, voucher));
  if (ownVoucher) {
    return { kind: "voucher", id: ownVoucher.id };
  }
  const otherFoodPart = snapshot.platterFoodParts.find((part) => part.makerParticipantId !== botParticipantId);
  if (otherFoodPart) {
    return { kind: "dish_part", id: otherFoodPart.id };
  }
  const foodPart = snapshot.platterFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  const foreignVoucher = snapshot.platter.find((voucher) => voucher.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, voucher));
  if (foreignVoucher) {
    return { kind: "voucher", id: foreignVoucher.id };
  }
  const voucher = snapshot.platter.find((candidate) => voucherHasStock(snapshot, candidate));
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

function decideAcceptOffer(snapshot: Snapshot): BotDecision | undefined {
  for (const offer of snapshot.offers) {
    if (offer.status !== "pending" || offer.toParticipantId !== snapshot.viewerParticipantId) {
      continue;
    }
    const requested = offer.requestedAsset;
    if (!requested) {
      continue;
    }
    if (requested.kind === "voucher") {
      const matching = snapshot.ownHand
        .filter((voucher) => voucher.ingredientId === requested.ingredientId)
        .filter((voucher) => !requested.ownerParticipantId || voucher.ownerParticipantId === requested.ownerParticipantId)
        .filter((voucher) => voucherHasStock(snapshot, voucher))
        .slice(0, requested.quantity);
      if (matching.length === requested.quantity) {
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
      continue;
    }

    const matchingParts = snapshot.ownFoodParts
      .filter((part) => part.dishId === requested.dishId)
      .filter((part) => !requested.makerParticipantId || part.makerParticipantId === requested.makerParticipantId)
      .slice(0, requested.quantity);
    if (matchingParts.length === requested.quantity) {
      return {
        intent: {
          type: "respond_offer",
          offerId: offer.id,
          response: "accept",
          assets: matchingParts.map((part) => ({ kind: "dish_part", id: part.id }))
        },
        reason: "can satisfy food-piece offer"
      };
    }
  }
  return undefined;
}

function decideRedeemAllAndPass(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const recipeComplete = snapshot.ownRecipe.requirements.every((requirement) => requirement.redeemedQty >= requirement.requiredQty);
  const hasPlacedRedeemable = snapshot.ownRecipe.requirements.some((requirement) =>
    requirement.placedVoucherIds.some((voucherId) => {
      const voucher = table.vouchers[voucherId];
      return voucher ? voucherHasStock(snapshot, voucher) : false;
    })
  );
  const hasUsefulHandVoucher = snapshot.ownHand.some(
    (voucher) => voucherHasStock(snapshot, voucher) && getUsefulRequirementIds(table, botParticipantId, voucher.ingredientId).length > 0
  );
  if (!recipeComplete && !hasPlacedRedeemable && !hasUsefulHandVoucher) {
    return undefined;
  }
  return {
    intent: { type: "redeem_all_and_pass_turn" },
    reason: recipeComplete ? "prepare complete recipe and pass turn" : "redeem useful cards and pass turn"
  };
}

function decidePoolSwap(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const neededIngredients = neededIngredientCountsAfterHand(snapshot);
  for (const take of snapshot.platter) {
    if ((neededIngredients.get(take.ingredientId) ?? 0) <= 0 || !voucherHasStock(snapshot, take)) {
      continue;
    }
    const give = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand, take.ingredientId);
    if (!give) {
      continue;
    }
    return {
      intent: { type: "platter_swap", giveVoucherId: give.id, takeVoucherId: take.id },
      reason: "platter has useful voucher"
    };
  }
  return undefined;
}

function decideCreateOffer(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const neededIngredients = neededIngredientCountsAfterHand(snapshot);
  const needed = [...neededIngredients.entries()].find(([, count]) => count > 0);
  if (!needed) {
    return undefined;
  }
  const [neededIngredientId] = needed;
  const give = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand, neededIngredientId);
  if (!give) {
    return undefined;
  }
  const target = snapshot.participants.find(
    (participant) =>
      participant.id !== botParticipantId &&
      participant.role === "active" &&
      participant.ingredientId === neededIngredientId &&
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
      requested: { ingredientId: neededIngredientId, quantity: 1 }
    },
    reason: "request needed ingredient by structured offer"
  };
}

function neededIngredientCountsAfterHand(snapshot: Snapshot): Map<string, number> {
  const needed = new Map<string, number>();
  for (const requirement of snapshot.ownRecipe?.requirements ?? []) {
    const outstanding = requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length;
    if (outstanding > 0) {
      needed.set(requirement.ingredientId, (needed.get(requirement.ingredientId) ?? 0) + outstanding);
    }
  }
  for (const voucher of snapshot.ownHand) {
    if (!voucherHasStock(snapshot, voucher)) {
      continue;
    }
    const remaining = needed.get(voucher.ingredientId) ?? 0;
    if (remaining > 0) {
      needed.set(voucher.ingredientId, remaining - 1);
    }
  }
  return needed;
}

function firstSurplusVoucher(table: Table, participantId: string, hand: Voucher[], excludedIngredientId = ""): Voucher | undefined {
  const backedHand = hand.filter((voucher) => {
    const owner = table.participants[voucher.ownerParticipantId];
    return (owner?.realIngredientStock ?? 0) > 0;
  });
  const recipe = table.recipes[participantId];
  const protectedByIngredient = new Map<string, number>();
  for (const requirement of recipe?.requirements ?? []) {
    const outstanding = requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length;
    if (outstanding > 0) {
      protectedByIngredient.set(
        requirement.ingredientId,
        (protectedByIngredient.get(requirement.ingredientId) ?? 0) + outstanding
      );
    }
  }
  const heldByIngredient = new Map<string, number>();
  for (const voucher of backedHand) {
    if (voucher.ingredientId === excludedIngredientId) {
      continue;
    }
    const heldCount = (heldByIngredient.get(voucher.ingredientId) ?? 0) + 1;
    heldByIngredient.set(voucher.ingredientId, heldCount);
    if (heldCount > (protectedByIngredient.get(voucher.ingredientId) ?? 0)) {
      return voucher;
    }
  }
  return undefined;
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
