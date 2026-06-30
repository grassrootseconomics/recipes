import { applyIntent, getUsefulRequirementIds, handVoucherIds, offerableUnreservedAssetQty, platterVoucherIds } from "./game.js";
import { hashString } from "./rng.js";
import { buildSnapshot } from "./snapshots.js";
import type { AutomationDiagnostic, DishPart, Intent, OfferAssetRequest, PlatterAssetRef, PublicParticipant, Snapshot, Table, Voucher } from "./types.js";

const DEFAULT_BOT_RUN_BUDGET = 300;
const MAX_AUTOMATION_DIAGNOSTICS = 32;

export interface BotDecision {
  intent: Intent;
  reason: string;
  diagnostic?: BotDecisionDiagnostic;
}

interface BotDecisionDiagnostic {
  missingIngredientIds?: string[];
  platterAvailableIngredientIds?: string[];
  offerTargetParticipantId?: string;
  offerTargetName?: string;
  targetOfferableQty?: number;
  noOfferReason?: string;
}

export function decideBotIntent(table: Table, botParticipantId: string): BotDecision | undefined {
  const participant = table.participants[botParticipantId];
  if (!participant || participant.kind !== "bot" || participant.role !== "active") {
    return undefined;
  }
  if (table.paused) {
    return undefined;
  }
  if (table.phase !== "deposit" && table.phase !== "eating" && table.currentTurnParticipantId !== botParticipantId) {
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
    const acceptDecision = decideAcceptOffer(snapshot);
    if (acceptDecision) {
      return acceptDecision;
    }
    return decideSettlementSwap(table, botParticipantId, snapshot) ?? roundRobinPass();
  }

  if (snapshot.phase === "eating") {
    return decideBite(table, botParticipantId, snapshot);
  }

  if (snapshot.phase !== "playing") {
    return undefined;
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
    const offerDecision = decideCreateOffer(table, botParticipantId, snapshot);
    if (offerDecision) {
      return offerDecision;
    }
  }

  const redeemAndPassDecision = decideRedeemAllAndPass(table, botParticipantId, snapshot);
  if (redeemAndPassDecision) {
    return redeemAndPassDecision;
  }

  return roundRobinPass(passMissingRecipeDiagnostic(table, botParticipantId, snapshot));
}

function roundRobinPass(diagnostic?: BotDecisionDiagnostic): BotDecision {
  return { intent: { type: "pass_turn" }, reason: "no useful turn action", diagnostic };
}

export function runBotTurn(table: Table, botParticipantId: string): BotDecision | undefined {
  const decision = decideBotIntent(table, botParticipantId);
  if (!decision) {
    return undefined;
  }
  applyIntent(table, botParticipantId, decision.intent);
  return decision;
}

export function runBots(
  table: Table,
  maxTurns = DEFAULT_BOT_RUN_BUDGET,
  onStep?: (decision: BotDecision) => void,
  onDiagnostic?: (diagnostic: AutomationDiagnostic) => void
): BotDecision[] {
  const decisions: BotDecision[] = [];
  for (let turn = 0; turn < maxTurns; turn += 1) {
    let progressed = false;
    const botIds = table.participantOrder.filter((participantId) => table.participants[participantId]?.kind === "bot");
    for (const botId of botIds) {
      const decision = runBotTurnSafely(table, botId, onDiagnostic);
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
      (table.phase !== "playing" && table.phase !== "settlement") ||
      current?.kind !== "bot" ||
      current.role !== "active"
    ) {
      break;
    }
    const passIntent: Intent = { type: "pass_turn" };
    try {
      applyIntent(table, current.id, passIntent);
      const decision = { intent: passIntent, reason: "bot run budget exhausted; pass turn to avoid stalling" };
      decisions.push(decision);
      recordAutomationDiagnostic(table, current.id, "budget_pass", decision, undefined, onDiagnostic);
      onStep?.(decision);
    } catch (error) {
      recordAutomationDiagnostic(table, current.id, "fallback_failed", { intent: passIntent, reason: "budget fallback pass failed" }, error, onDiagnostic);
      break;
    }
  }
  return decisions;
}

function runBotTurnSafely(table: Table, botParticipantId: string, onDiagnostic?: (diagnostic: AutomationDiagnostic) => void): BotDecision | undefined {
  let decision: BotDecision | undefined;
  try {
    decision = decideBotIntent(table, botParticipantId);
    if (!decision) {
      return undefined;
    }
    if (decision.intent.type === "pass_turn" && decision.diagnostic?.missingIngredientIds?.length) {
      recordAutomationDiagnostic(table, botParticipantId, "pass_missing_ingredients", decision, undefined, onDiagnostic);
    }
    applyIntent(table, botParticipantId, decision.intent);
    return decision;
  } catch (error) {
    recordAutomationDiagnostic(table, botParticipantId, "error", decision, error, onDiagnostic);
    return fallbackPassCurrentBot(table, botParticipantId, decision, error, onDiagnostic);
  }
}

function fallbackPassCurrentBot(
  table: Table,
  botParticipantId: string,
  failedDecision: BotDecision | undefined,
  cause: unknown,
  onDiagnostic?: (diagnostic: AutomationDiagnostic) => void
): BotDecision | undefined {
  const current = table.currentTurnParticipantId ? table.participants[table.currentTurnParticipantId] : undefined;
  if (
    (table.phase !== "playing" && table.phase !== "settlement") ||
    !current ||
    current.id !== botParticipantId ||
    current.kind !== "bot" ||
    current.role !== "active"
  ) {
    return undefined;
  }
  const fallbackDecision: BotDecision = {
    intent: { type: "pass_turn" },
    reason: failedDecision ? `fallback after failed ${failedDecision.intent.type}` : "fallback after bot decision failure"
  };
  try {
    applyIntent(table, botParticipantId, fallbackDecision.intent);
    recordAutomationDiagnostic(table, botParticipantId, "fallback_pass", fallbackDecision, cause, onDiagnostic);
    return fallbackDecision;
  } catch (fallbackError) {
    recordAutomationDiagnostic(table, botParticipantId, "fallback_failed", fallbackDecision, fallbackError, onDiagnostic);
    return undefined;
  }
}

function recordAutomationDiagnostic(
  table: Table,
  botParticipantId: string,
  status: AutomationDiagnostic["status"],
  decision?: BotDecision,
  error?: unknown,
  onDiagnostic?: (diagnostic: AutomationDiagnostic) => void
): void {
  const participant = table.participants[botParticipantId];
  const diagnostic: AutomationDiagnostic = {
    atMs: Date.now(),
    tableCode: table.code,
    phase: table.phase,
    turn: table.turn,
    version: table.version,
    botParticipantId,
    botName: participant?.name ?? botParticipantId,
    botType: participant?.botType,
    status,
    reason: decision?.reason,
    intentType: decision?.intent.type,
    missingIngredientIds: decision?.diagnostic?.missingIngredientIds,
    platterAvailableIngredientIds: decision?.diagnostic?.platterAvailableIngredientIds,
    offerTargetParticipantId: decision?.diagnostic?.offerTargetParticipantId,
    offerTargetName: decision?.diagnostic?.offerTargetName,
    targetOfferableQty: decision?.diagnostic?.targetOfferableQty,
    noOfferReason: decision?.diagnostic?.noOfferReason,
    ...automationErrorFields(error)
  };
  table.automationDiagnostics ??= [];
  table.automationDiagnostics.push(diagnostic);
  while (table.automationDiagnostics.length > MAX_AUTOMATION_DIAGNOSTICS) {
    table.automationDiagnostics.shift();
  }
  onDiagnostic?.(diagnostic);
}

function automationErrorFields(error: unknown): Pick<AutomationDiagnostic, "errorCode" | "message"> {
  if (!error) {
    return {};
  }
  if (typeof error === "object" && error !== null) {
    const maybeError = error as { code?: unknown; message?: unknown };
    return {
      errorCode: typeof maybeError.code === "string" ? maybeError.code : undefined,
      message: typeof maybeError.message === "string" ? maybeError.message : "Unknown bot automation error."
    };
  }
  return { message: String(error) };
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

  const shortfallSwap = decideSettlementShortfallSwap(bot, botParticipantId, snapshot, true);
  if (shortfallSwap) {
    return shortfallSwap;
  }

  const directSettlementOffer = decideSettlementDirectOffer(table, botParticipantId, snapshot);
  if (directSettlementOffer) {
    return directSettlementOffer;
  }

  if (bot.foreignCardsInHand > 0 && snapshot.platterFoodParts.length > 0) {
    const returnCandidate = snapshot.ownHand
      .filter((voucher) => voucher.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, voucher))
      .map((voucher) => {
        const owner = snapshot.participants.find((participant) => participant.id === voucher.ownerParticipantId);
        const takePart = settlementFoodPartForForeignCard(table, botParticipantId, voucher.ownerParticipantId, snapshot.platterFoodParts);
        return { voucher, owner, takePart };
      })
      .filter(({ owner }) => (owner?.platterShortfall ?? 0) > 0)
      .sort((left, right) => settlementForeignCardRank(left.owner) - settlementForeignCardRank(right.owner))
      .find(({ takePart }) => Boolean(takePart));
    if (returnCandidate?.takePart) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "voucher", id: returnCandidate.voucher.id },
          take: { kind: "dish_part", id: returnCandidate.takePart.id }
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
    const fallbackShortfallSwap = decideSettlementShortfallSwap(bot, botParticipantId, snapshot, false);
    if (fallbackShortfallSwap) {
      return fallbackShortfallSwap;
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

function decideSettlementShortfallSwap(
  bot: PublicParticipant,
  botParticipantId: string,
  snapshot: Snapshot,
  requireExtraOwnCard: boolean
): BotDecision | undefined {
  if (bot.platterShortfall <= 0) {
    return undefined;
  }
  if (requireExtraOwnCard && bot.ownCardsInHand <= bot.expectedOwnCardsInHand) {
    return undefined;
  }
  if (!requireExtraOwnCard && bot.ownCardsInOtherHands > 0) {
    return undefined;
  }
  const ownVoucher = snapshot.ownHand.find((voucher) => voucher.ownerParticipantId === botParticipantId && voucherHasStock(snapshot, voucher));
  const take = preferredSettlementTake(snapshot, botParticipantId);
  if (!ownVoucher || !take) {
    return undefined;
  }
  return {
    intent: {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: ownVoucher.id },
      take
    },
    reason: requireExtraOwnCard ? "settle platter shortfall with extra own promise card" : "settle platter shortfall"
  };
}

function botJustMadeSettlementSwap(table: Table, botParticipantId: string): boolean {
  const last = table.transactionHistory.at(-1);
  return last?.participantId === botParticipantId && last.action === "Settlement Swap";
}

function settlementForeignCardRank(owner?: PublicParticipant): number {
  if (!owner) {
    return 3;
  }
  if (owner.platterShortfall > 0) {
    return 0;
  }
  if (owner.ownCardsInOtherHands > 0) {
    return 1;
  }
  return 2;
}

function settlementFoodPartForForeignCard(
  table: Table,
  botParticipantId: string,
  ownerParticipantId: string,
  platterFoodParts: DishPart[]
): DishPart | undefined {
  const ownerPart = platterFoodParts.find((part) => part.makerParticipantId === ownerParticipantId);
  if (ownerPart) {
    return ownerPart;
  }
  const nonSelfPartIds = platterFoodParts.filter((part) => part.makerParticipantId !== botParticipantId).map((part) => part.id);
  const nonSelfPart = deterministicFoodPartRef(table, botParticipantId, nonSelfPartIds);
  if (nonSelfPart) {
    return platterFoodParts.find((part) => part.id === nonSelfPart.id);
  }
  const anyPart = deterministicFoodPartRef(table, botParticipantId, platterFoodParts.map((part) => part.id));
  return anyPart ? platterFoodParts.find((part) => part.id === anyPart.id) : undefined;
}

function decideSettlementDirectOffer(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (snapshot.offers.some((offer) => offer.status === "pending" && offer.fromParticipantId === botParticipantId)) {
    return undefined;
  }
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  const ownFoodPart = snapshot.ownFoodParts[0];
  if (bot?.ingredientId && (bot.ownCardsInOtherHands ?? 0) > 0 && ownFoodPart) {
    const holder = snapshot.participants.find(
      (participant) =>
        participant.id !== botParticipantId &&
        participant.heldVoucherGroups.some(
          (group) => group.ingredientId === bot.ingredientId && group.ownerParticipantId === botParticipantId && group.count > 0
        )
    );
    if (holder) {
      const requestedAsset: OfferAssetRequest = { kind: "voucher", ingredientId: bot.ingredientId, ownerParticipantId: botParticipantId, quantity: 1 };
      if (offerableUnreservedAssetQty(table, holder.id, requestedAsset) < requestedAsset.quantity) {
        return undefined;
      }
      return {
        intent: {
          type: "create_offer",
          toParticipantId: holder.id,
          offeredAssets: [{ kind: "dish_part", id: ownFoodPart.id }],
          requestedAsset
        },
        reason: "offer food piece directly for own stranded promise card"
      };
    }
  }
  const returnCandidate = snapshot.ownHand
    .filter((voucher) => voucher.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, voucher))
    .map((voucher) => {
      const owner = snapshot.participants.find((participant) => participant.id === voucher.ownerParticipantId);
      return { voucher, owner };
    })
    .filter(({ owner }) => Boolean(owner && (owner.heldFoodPartCount ?? 0) > 0))
    .sort((left, right) => settlementForeignCardRank(left.owner) - settlementForeignCardRank(right.owner))[0];
  if (!returnCandidate?.owner) {
    return undefined;
  }
  const requestedAsset: OfferAssetRequest = { kind: "dish_part", quantity: 1 };
  if (offerableUnreservedAssetQty(table, returnCandidate.owner.id, requestedAsset) < requestedAsset.quantity) {
    return undefined;
  }
  return {
    intent: {
      type: "create_offer",
      toParticipantId: returnCandidate.owner.id,
      offeredVoucherIds: [returnCandidate.voucher.id],
      requestedAsset
    },
    reason: "offer foreign promise card directly for any food piece during settlement"
  };
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
  const foreignVoucher = snapshot.ownHand.find((candidate) => candidate.ownerParticipantId !== botParticipantId && voucherHasStock(snapshot, candidate));
  if (foreignVoucher) {
    return { kind: "voucher", id: foreignVoucher.id };
  }
  const voucher = snapshot.ownHand.find((candidate) => (allowOwnVoucher || candidate.ownerParticipantId !== botParticipantId) && voucherHasStock(snapshot, candidate));
  return voucher ? { kind: "voucher", id: voucher.id } : undefined;
}

function preferredSettlementTake(snapshot: Snapshot, botParticipantId: string): PlatterAssetRef | undefined {
  const foodPart = snapshot.platterFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  return undefined;
}

function preferredFoodPartSeedTake(snapshot: Snapshot, botParticipantId: string): PlatterAssetRef | undefined {
  const otherFoodPart = snapshot.platterFoodParts.find((part) => part.makerParticipantId !== botParticipantId);
  if (otherFoodPart) {
    return { kind: "dish_part", id: otherFoodPart.id };
  }
  const foodPart = snapshot.platterFoodParts[0];
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  return undefined;
}

function deterministicFoodPartRef(table: Table, botParticipantId: string, partIds: string[]): PlatterAssetRef | undefined {
  const [id] = [...partIds].sort(
    (left, right) =>
      hashString(`${table.seed}:settlement:${table.turn}:${botParticipantId}:${left}`) -
      hashString(`${table.seed}:settlement:${table.turn}:${botParticipantId}:${right}`)
  );
  return id ? { kind: "dish_part", id } : undefined;
}

function decideBite(_table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  const bot = snapshot.participants.find((participant) => participant.id === botParticipantId);
  if (!bot?.cleared) {
    return undefined;
  }
  if (snapshot.ownFoodParts.length === 0) {
    return undefined;
  }
  return { intent: { type: "bite_all" }, reason: "eat all held food parts" };
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
      .filter((part) => !requested.dishId || part.dishId === requested.dishId)
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
    if (give) {
      return {
        intent: { type: "platter_swap", giveVoucherId: give.id, takeVoucherId: take.id },
        reason: "platter has useful voucher"
      };
    }
    const foodPart = firstSpendableFoodPart(snapshot);
    if (foodPart) {
      return {
        intent: {
          type: "platter_asset_swap",
          give: { kind: "dish_part", id: foodPart.id },
          take: { kind: "voucher", id: take.id }
        },
        reason: "spend dish piece for useful platter voucher"
      };
    }
  }
  return undefined;
}

function firstSpendableFoodPart(snapshot: Snapshot): DishPart | undefined {
  return [...snapshot.ownFoodParts].sort((left, right) => left.id.localeCompare(right.id))[0];
}

function offerGiveAsset(table: Table, botParticipantId: string, snapshot: Snapshot, neededIngredientId: string): PlatterAssetRef | undefined {
  const ownSurplusVoucher = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand, neededIngredientId, botParticipantId);
  if (ownSurplusVoucher) {
    return { kind: "voucher", id: ownSurplusVoucher.id };
  }
  const foodPart = firstSpendableFoodPart(snapshot);
  if (foodPart) {
    return { kind: "dish_part", id: foodPart.id };
  }
  const giveVoucher = firstSurplusVoucher(table, botParticipantId, snapshot.ownHand, neededIngredientId);
  if (giveVoucher) {
    return { kind: "voucher", id: giveVoucher.id };
  }
  return undefined;
}

function offerIntentForAsset(give: PlatterAssetRef, target: PublicParticipant, neededIngredientId: string): Intent {
  const base = {
    type: "create_offer" as const,
    toParticipantId: target.id,
    requestedAsset: { kind: "voucher" as const, ingredientId: neededIngredientId, ownerParticipantId: target.id, quantity: 1 }
  };
  if (give.kind === "voucher") {
    return {
      ...base,
      offeredVoucherIds: [give.id]
    };
  }
  return {
    ...base,
    offeredAssets: [give]
  };
}

function decideCreateOffer(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecision | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const neededIngredients = neededIngredientCountsAfterHand(snapshot);
  const needed = offerableNeededIngredients(botParticipantId, snapshot, neededIngredients)[0];
  if (!needed) {
    return undefined;
  }
  const { ingredientId: neededIngredientId, target } = needed;
  const give = offerGiveAsset(table, botParticipantId, snapshot, neededIngredientId);
  if (!give) {
    return undefined;
  }
  const existingPending = snapshot.offers.some((offer) => offer.status === "pending" && offer.fromParticipantId === botParticipantId);
  if (existingPending) {
    return undefined;
  }
  return {
    intent: offerIntentForAsset(give, target, neededIngredientId),
    reason: "request needed ingredient by structured offer"
  };
}

function passMissingRecipeDiagnostic(table: Table, botParticipantId: string, snapshot: Snapshot): BotDecisionDiagnostic | undefined {
  if (!snapshot.ownRecipe) {
    return undefined;
  }
  const neededIngredients = neededIngredientCountsAfterHand(snapshot);
  const missingIngredientIds = [...neededIngredients.entries()]
    .filter(([, missingCount]) => missingCount > 0)
    .map(([ingredientId]) => ingredientId)
    .sort();
  if (missingIngredientIds.length === 0) {
    return undefined;
  }
  const platterAvailableIngredientIds = missingIngredientIds
    .filter((ingredientId) =>
      snapshot.platter.some((voucher) => voucher.ingredientId === ingredientId && voucherHasStock(snapshot, voucher))
    )
    .sort();
  const existingPending = snapshot.offers.some((offer) => offer.status === "pending" && offer.fromParticipantId === botParticipantId);
  const candidates = offerableNeededIngredients(botParticipantId, snapshot, neededIngredients);
  const candidate = candidates[0];
  const give = candidate ? offerGiveAsset(table, botParticipantId, snapshot, candidate.ingredientId) : undefined;
  let noOfferReason = "no_offerable_target";
  if (table.participants[botParticipantId]?.botType === "pool_only") {
    noOfferReason = "bot_type_pool_only";
  } else if (existingPending) {
    noOfferReason = "existing_pending_offer";
  } else if (candidate && !give) {
    noOfferReason = "no_offerable_give_asset";
  } else if (candidate && give) {
    noOfferReason = "offer_available_but_not_chosen";
  }
  return {
    missingIngredientIds,
    platterAvailableIngredientIds,
    offerTargetParticipantId: candidate?.target.id,
    offerTargetName: candidate?.target.name,
    targetOfferableQty: candidate?.target.offerableOwnIngredientQty,
    noOfferReason
  };
}

function offerableNeededIngredients(
  botParticipantId: string,
  snapshot: Snapshot,
  neededIngredients: Map<string, number>
): Array<{ ingredientId: string; missingCount: number; target: PublicParticipant }> {
  return [...neededIngredients.entries()]
    .filter(([, missingCount]) => missingCount > 0)
    .flatMap(([ingredientId, missingCount]) => {
      const target = snapshot.participants.find(
        (participant) =>
          participant.id !== botParticipantId &&
          participant.role === "active" &&
          participant.ingredientId === ingredientId &&
          participant.offerableOwnIngredientQty > 0
      );
      return target ? [{ ingredientId, missingCount, target }] : [];
    })
    .sort((left, right) => left.missingCount - right.missingCount || left.ingredientId.localeCompare(right.ingredientId));
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

function firstSurplusVoucher(
  table: Table,
  participantId: string,
  hand: Voucher[],
  excludedIngredientId = "",
  preferredOwnerParticipantId = ""
): Voucher | undefined {
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
  const candidates =
    preferredOwnerParticipantId === ""
      ? backedHand
      : backedHand.filter((voucher) => voucher.ownerParticipantId === preferredOwnerParticipantId);
  for (const voucher of candidates) {
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
