import { applyIntent, getUsefulRequirementIds, handVoucherIds, platterVoucherIds } from "./game.js";
import { MAX_PLAYER_BITES_PER_DISH } from "./constants.js";
import { hashString } from "./rng.js";
import { buildSnapshot } from "./snapshots.js";
import type { Dish, Intent, PublicParticipant, Snapshot, Table, Voucher } from "./types.js";

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
  const snapshot = buildSnapshot(table, botParticipantId);
  if (snapshot.allHands || snapshot.allRecipes || snapshot.allVouchers) {
    throw new Error("Bot snapshot contains hidden information.");
  }

  if (snapshot.phase === "deposit") {
    if (participant.depositedInitial) {
      return undefined;
    }
    const firstVoucher = snapshot.ownHand[0];
    return firstVoucher ? { intent: { type: "deposit", voucherId: firstVoucher.id }, reason: "required initial deposit" } : undefined;
  }

  if (snapshot.phase === "winner_bite" || snapshot.phase === "eating") {
    return decideBite(table, botParticipantId, snapshot);
  }

  if (snapshot.phase !== "playing") {
    return undefined;
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

  const acceptDecision = decideAcceptOffer(snapshot);
  if (acceptDecision) {
    return acceptDecision;
  }

  const poolDecision = participant.botType !== "barter_only" ? decidePoolSwap(table, botParticipantId, snapshot) : undefined;
  if (poolDecision) {
    return poolDecision;
  }

  if (participant.botType !== "pool_only") {
    return decideCreateOffer(table, botParticipantId, snapshot);
  }

  return undefined;
}

export function runBotTurn(table: Table, botParticipantId: string): BotDecision | undefined {
  const decision = decideBotIntent(table, botParticipantId);
  if (!decision) {
    return undefined;
  }
  applyIntent(table, botParticipantId, decision.intent);
  return decision;
}

export function runBots(table: Table, maxTurns = 50): BotDecision[] {
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
  return decisions;
}

function decidePrepare(snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const complete = snapshot.ownRecipe.requirements.every((requirement) => requirement.redeemedQty >= requirement.requiredQty);
  return complete ? { intent: { type: "prepare" }, reason: "recipe complete" } : undefined;
}

function decideBite(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  if (!bot) {
    return undefined;
  }
  const legalDishes = snapshot.dishes.filter((dish) => canBotBiteDish(snapshot, bot, dish));
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

function canBotBiteDish(snapshot: Snapshot, bot: PublicParticipant, dish: Dish): boolean {
  if (dish.bitesRemaining <= 0) {
    return false;
  }
  if (snapshot.phase === "winner_bite" && !snapshot.winners.includes(bot.id)) {
    return false;
  }
  if (bot.isHost) {
    return true;
  }
  const biteCounts = dish.biteCounts ?? {};
  const botBites = biteCounts[bot.id] ?? 0;
  if (botBites < MAX_PLAYER_BITES_PER_DISH) {
    return true;
  }
  const nonHostActiveIds = snapshot.participants
    .filter((participant) => participant.role === "active" && !participant.isHost)
    .map((participant) => participant.id);
  return nonHostActiveIds.includes(bot.id) && nonHostActiveIds.every((participantId) => {
    if (participantId === bot.id) {
      return true;
    }
    return (biteCounts[participantId] ?? 0) >= MAX_PLAYER_BITES_PER_DISH;
  });
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
  for (const voucher of snapshot.ownHand) {
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
  const take = snapshot.platter.find((voucher) => neededIngredients.includes(voucher.ingredientId));
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
  const useful = new Set(
    hand
      .flatMap((voucher) => getUsefulRequirementIds(table, participantId, voucher.ingredientId).map(() => voucher.id))
  );
  return hand.find((voucher) => !useful.has(voucher.id)) ?? hand[0];
}

export function botOnlyVisibleHandIds(table: Table, botParticipantId: string): string[] {
  return handVoucherIds(table, botParticipantId);
}

export function visiblePlatterIdsForBot(table: Table): string[] {
  return platterVoucherIds(table);
}
