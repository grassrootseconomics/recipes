import { activeParticipants } from "./game.js";
import type { GameStats, Table, TransactionAction, TransactionRecord } from "./types.js";

export function computeGameStats(table: Table): GameStats {
  const history = table.transactionHistory ?? [];
  const activePlayerCount = activeParticipants(table).length;
  const playerTurnCount = countAction(history, "Pass Turn");
  const cycleCount = activePlayerCount > 0 ? playerTurnCount / activePlayerCount : 0;
  const interactionCount = history.filter((transaction) => transaction.action !== "Pass Turn").length;
  const commonBasketSwapCount = countAction(history, "Swap");
  const directExchangeCount = countAction(history, "Exchange");
  const prepareCount = countAction(history, "Prepare");
  const settlementRows = history.filter((transaction) => transaction.action === "Settlement Swap");
  const settlementSwapCount = settlementRows.length;
  const assetLossCount = countConsumedRealIngredients(table);
  const productivityCount = countAction(history, "Eat");
  const totalTrades = commonBasketSwapCount + directExchangeCount + settlementSwapCount;
  return {
    activePlayerCount,
    mutationCount: table.turn,
    playerTurnCount,
    cycleCount: roundMetric(cycleCount),
    interactionCount,
    openingOfferingCount: countAction(history, "Deposit"),
    commonBasketSwapCount,
    directExchangeCount,
    redemptionCount: countAction(history, "Redeem"),
    prepareCount,
    settlementSwapCount,
    foodPieceSettlementSwapCount: settlementRows.filter(settlementSwapInvolvesFoodPiece).length,
    eatCount: productivityCount,
    assetLossCount,
    productivityCount,
    profitCount: productivityCount - assetLossCount,
    profitGainPercent: roundMetric(percentGain(productivityCount, assetLossCount)),
    averageTurnsPerDish: roundMetric(prepareCount > 0 ? playerTurnCount / prepareCount : 0),
    averageInteractionsPerDish: roundMetric(prepareCount > 0 ? interactionCount / prepareCount : 0),
    basketVelocity: roundMetric(cycleCount > 0 ? (commonBasketSwapCount + settlementSwapCount) / cycleCount : 0),
    directExchangeShare: roundMetric(totalTrades > 0 ? directExchangeCount / totalTrades : 0),
    settlementBurden: roundMetric(interactionCount > 0 ? settlementSwapCount / interactionCount : 0),
    scarcityPressureByIngredient: { ...(table.scarcityPressureByIngredient ?? {}) },
    ...computeHoardingIndex(table),
    liquidityDepth: roundMetric(computeLiquidityDepth(history)),
    settlementTimeTurns: computeSettlementTimeTurns(table, history),
    consumptionVariance: roundMetric(computeConsumptionVariance(table)),
    tradeBalanceByParticipant: computeTradeBalances(table, history)
  };
}

function countAction(history: TransactionRecord[], action: TransactionAction): number {
  return history.filter((transaction) => transaction.action === action).length;
}

function settlementSwapInvolvesFoodPiece(transaction: TransactionRecord): boolean {
  return transactionAssetIsFoodPiece(transaction.itemOut) || transactionAssetIsFoodPiece(transaction.itemBack);
}

function transactionAssetIsFoodPiece(label: string): boolean {
  const normalized = label.trim().toLowerCase();
  return normalized !== "" && normalized !== "none" && normalized !== "turn" && !normalized.includes("card");
}

function countConsumedRealIngredients(table: Table): number {
  return activeParticipants(table).reduce((total, participant) => {
    const remaining = participant.realIngredientStock ?? table.stockPerIngredient;
    return total + Math.max(0, table.stockPerIngredient - remaining);
  }, 0);
}

function percentGain(productivityCount: number, assetLossCount: number): number {
  if (assetLossCount <= 0) {
    return 0;
  }
  return ((productivityCount - assetLossCount) / assetLossCount) * 100;
}

function roundMetric(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function computeHoardingIndex(table: Table): { hoardingIndex: number; hoardingIndexLabel: string } {
  const counts = new Map<string, { holderId: string; ingredientId: string; count: number }>();
  for (const voucher of Object.values(table.vouchers ?? {})) {
    const location = voucher.location;
    if (location.type !== "hand" || !location.participantId || location.participantId === voucher.ownerParticipantId) {
      continue;
    }
    const key = `${location.participantId}:${voucher.ingredientId}`;
    const current = counts.get(key) ?? { holderId: location.participantId, ingredientId: voucher.ingredientId, count: 0 };
    current.count += 1;
    counts.set(key, current);
  }
  let best: { holderId: string; ingredientId: string; count: number } | undefined;
  for (const candidate of counts.values()) {
    if (!best || candidate.count > best.count) {
      best = candidate;
    }
  }
  if (!best) {
    return { hoardingIndex: 0, hoardingIndexLabel: "None" };
  }
  const holder = table.participants[best.holderId]?.name ?? best.holderId;
  return { hoardingIndex: best.count, hoardingIndexLabel: `${holder} holds ${best.ingredientId} x${best.count}` };
}

function computeLiquidityDepth(history: TransactionRecord[]): number {
  const basketCounts = new Map<string, number>();
  let sampleTotal = 0;
  let sampleCount = 0;
  for (const transaction of history) {
    if (transaction.action === "Deposit") {
      addBasketAsset(basketCounts, transaction.itemOut);
    } else if (transaction.action === "Swap" || transaction.action === "Settlement Swap") {
      addBasketAsset(basketCounts, transaction.itemOut);
      removeBasketAsset(basketCounts, transaction.itemBack);
    } else {
      continue;
    }
    sampleTotal += [...basketCounts.values()].filter((count) => count > 0).length;
    sampleCount += 1;
  }
  return sampleCount > 0 ? sampleTotal / sampleCount : 0;
}

function addBasketAsset(counts: Map<string, number>, label: string): void {
  const key = normalizeAssetLabel(label);
  if (!key) {
    return;
  }
  counts.set(key, (counts.get(key) ?? 0) + assetQuantity(label));
}

function removeBasketAsset(counts: Map<string, number>, label: string): void {
  const key = normalizeAssetLabel(label);
  if (!key) {
    return;
  }
  const next = (counts.get(key) ?? 0) - assetQuantity(label);
  if (next <= 0) {
    counts.delete(key);
  } else {
    counts.set(key, next);
  }
}

function normalizeAssetLabel(label: string): string {
  const normalized = label.trim().toLowerCase();
  if (!normalized || normalized === "none" || normalized === "turn" || normalized === "eaten") {
    return "";
  }
  return normalized.replace(/\s+x\d+$/u, "").replace(/\s+card\s+\d+$/u, " card");
}

function assetQuantity(label: string): number {
  const normalized = label.trim().toLowerCase();
  if (!normalized || normalized === "none" || normalized === "turn" || normalized === "eaten") {
    return 0;
  }
  const match = normalized.match(/\bx\s*(\d+)\b/u);
  return match ? Number(match[1]) : 1;
}

function computeSettlementTimeTurns(table: Table, history: TransactionRecord[]): number {
  let lastPrepareTurn: number | undefined;
  for (const transaction of history) {
    if (transaction.action === "Prepare") {
      lastPrepareTurn = transaction.turn;
    }
  }
  if (lastPrepareTurn === undefined) {
    return 0;
  }
  const firstEat = history.find((transaction) => transaction.action === "Eat" && transaction.turn >= lastPrepareTurn);
  if (firstEat) {
    return Math.max(0, firstEat.turn - lastPrepareTurn);
  }
  if (table.phase === "settlement" || table.phase === "eating" || table.phase === "complete") {
    return Math.max(0, table.turn - lastPrepareTurn);
  }
  return 0;
}

function computeConsumptionVariance(table: Table): number {
  const participants = activeParticipants(table);
  if (participants.length === 0) {
    return 0;
  }
  const totals = new Map<string, number>();
  for (const participant of participants) {
    totals.set(participant.id, 0);
  }
  for (const dish of Object.values(table.dishes ?? {})) {
    for (const [participantId, count] of Object.entries(dish.biteCounts ?? {})) {
      totals.set(participantId, (totals.get(participantId) ?? 0) + count);
    }
  }
  const values = participants.map((participant) => totals.get(participant.id) ?? 0);
  const mean = values.reduce((total, value) => total + value, 0) / values.length;
  return values.reduce((total, value) => total + (value - mean) ** 2, 0) / values.length;
}

function computeTradeBalances(table: Table, history: TransactionRecord[]): GameStats["tradeBalanceByParticipant"] {
  const balances: GameStats["tradeBalanceByParticipant"] = {};
  const mutable = new Map<string, { given: number; received: number }>();
  for (const participant of activeParticipants(table)) {
    mutable.set(participant.id, { given: 0, received: 0 });
  }
  for (const transaction of history) {
    if (transaction.action !== "Swap" && transaction.action !== "Settlement Swap" && transaction.action !== "Exchange") {
      continue;
    }
    const actor = mutable.get(transaction.participantId);
    if (actor) {
      actor.given += assetQuantity(transaction.itemOut);
      actor.received += assetQuantity(transaction.itemBack);
    }
    if (transaction.counterpartyParticipantId) {
      const counterparty = mutable.get(transaction.counterpartyParticipantId);
      if (counterparty) {
        counterparty.given += assetQuantity(transaction.itemBack);
        counterparty.received += assetQuantity(transaction.itemOut);
      }
    }
  }
  for (const [participantId, row] of mutable.entries()) {
    balances[participantId] = [row.given, row.received, row.received - row.given];
  }
  return balances;
}
