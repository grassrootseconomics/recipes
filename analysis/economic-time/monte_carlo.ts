import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  activeParticipants,
  applyIntent,
  createEmptyTable,
  handVoucherIds,
  inventoryDishPartIds,
  platterAccountForParticipant,
  platterDishPartIds,
  platterVoucherIds
} from "../../server/src/game.js";
import { computeGameStats } from "../../server/src/gameStats.js";
import type { Intent, Offer, Participant, Recipe, Table, TransactionRecord, Voucher } from "../../server/src/types.js";

type FactorKey = "coordination_delay" | "hoarding" | "last_ingredient" | "basket_thinness";

interface FactorDefinition {
  key: FactorKey;
  label: string;
  xLabel: string;
  interpretation: string;
}

interface Options {
  runsPerCell: number;
  levels: number[];
  factors: FactorKey[];
  seed: string;
  maxPlayerTurns: number;
  outputDir: string;
}

interface Scenario {
  factor: FactorDefinition;
  x: number;
  coordinationDelayProbability: number;
  hoardingProbability: number;
  lastIngredientDelayProbability: number;
  lastIngredientThreshold: number;
  basketSkipProbability: number;
}

interface TimelineRow {
  runId: string;
  factor: FactorKey;
  factorLabel: string;
  x: number;
  runIndex: number;
  eventIndex: number;
  playerTurns: number;
  mutationTurn: number;
  phase: string;
  preparedDishes: number;
  redeemedUnits: number;
  platterVoucherCount: number;
  platterDistinctIngredients: number;
  platterFoodParts: number;
  foreignCardsInHands: number;
  maxForeignIngredientPile: number;
  unsettledAccounts: number;
  totalPlatterDebt: number;
  totalPlatterShortfall: number;
  scarcityPressureTotal: number;
}

interface RunResult {
  runId: string;
  factor: FactorKey;
  factorLabel: string;
  x: number;
  runIndex: number;
  seed: string;
  ok: boolean;
  failureReason: string;
  phase: string;
  productionTurns: number;
  settlementTurns: number;
  successTurns: number;
  completionTurns: number;
  mutationTurns: number;
  preparedDishes: number;
  totalDishesRequired: number;
  redemptions: number;
  commonBasketSwaps: number;
  directExchanges: number;
  settlementSwaps: number;
  foodPieceSettlementSwaps: number;
  interactions: number;
  basketVelocity: number;
  directExchangeShare: number;
  settlementBurden: number;
  liquidityDepth: number;
  finalHoardingIndex: number;
  maxObservedHoardingIndex: number;
  scarcityPressureTotal: number;
  localScarcityEvents: number;
  localHoardingSkips: number;
  localDelayPasses: number;
  localBasketSkips: number;
}

interface MutableRunCounters {
  localScarcityEvents: number;
  localHoardingSkips: number;
  localDelayPasses: number;
  localBasketSkips: number;
}

const FACTORS: Record<FactorKey, FactorDefinition> = {
  coordination_delay: {
    key: "coordination_delay",
    label: "Coordination delay",
    xLabel: "probability of an unproductive pass",
    interpretation: "Missed turns, slow responses, or players not seeing an available useful move."
  },
  hoarding: {
    key: "hoarding",
    label: "Hoarding surplus",
    xLabel: "probability of holding surplus foreign cards",
    interpretation: "Players keep resources they do not need, reducing circulation and slowing later settlement."
  },
  last_ingredient: {
    key: "last_ingredient",
    label: "Last-ingredient reluctance",
    xLabel: "probability of withholding scarce own vouchers",
    interpretation: "Owners hesitate to release the last visible or low-count ingredient cards even when another cook needs them."
  },
  basket_thinness: {
    key: "basket_thinness",
    label: "Common Basket thinness",
    xLabel: "probability of skipping a useful basket swap",
    interpretation: "The public pool is visible but underused, forcing slower bilateral coordination."
  }
};

const DEFAULT_LEVELS = [0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75];
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

function parseOptions(args: string[]): Options {
  const getValue = (name: string, fallback: string) => {
    const prefix = `--${name}=`;
    return args.find((arg) => arg.startsWith(prefix))?.slice(prefix.length) ?? fallback;
  };
  const factorText = getValue("factors", process.env.ECON_FACTORS ?? Object.keys(FACTORS).join(","));
  const factors = factorText
    .split(",")
    .map((factor) => factor.trim())
    .filter(Boolean) as FactorKey[];
  for (const factor of factors) {
    if (!FACTORS[factor]) {
      throw new Error(`Unknown factor '${factor}'. Expected one of: ${Object.keys(FACTORS).join(", ")}.`);
    }
  }
  const levels = getValue("levels", process.env.ECON_LEVELS ?? DEFAULT_LEVELS.join(","))
    .split(",")
    .map((level) => Number.parseFloat(level.trim()))
    .filter((level) => Number.isFinite(level));
  if (levels.length === 0 || levels.some((level) => level < 0 || level > 1)) {
    throw new Error("Levels must be comma-separated numbers from 0 to 1.");
  }
  return {
    runsPerCell: positiveInt(getValue("runs", process.env.ECON_RUNS ?? "12"), "runs"),
    levels,
    factors,
    seed: getValue("seed", process.env.ECON_SEED ?? "economic-time"),
    maxPlayerTurns: positiveInt(getValue("max-player-turns", process.env.ECON_MAX_PLAYER_TURNS ?? "650"), "max-player-turns"),
    outputDir: path.resolve(REPO_ROOT, getValue("out", process.env.ECON_OUT ?? "analysis/economic-time/outputs/latest"))
  };
}

function positiveInt(value: string, label: string): number {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${label} must be a positive integer.`);
  }
  return parsed;
}

function scenarioFor(factor: FactorDefinition, x: number): Scenario {
  return {
    factor,
    x,
    coordinationDelayProbability: factor.key === "coordination_delay" ? x * 0.55 : 0,
    hoardingProbability: factor.key === "hoarding" ? x : 0,
    lastIngredientDelayProbability: factor.key === "last_ingredient" ? x : 0,
    lastIngredientThreshold: factor.key === "last_ingredient" ? 1 + Math.ceil(x * 5) : 1,
    basketSkipProbability: factor.key === "basket_thinness" ? x : 0
  };
}

function seededRng(seed: string): () => number {
  let state = 2166136261;
  for (const char of seed) {
    state ^= char.charCodeAt(0);
    state = Math.imul(state, 16777619);
  }
  return () => {
    state += 0x6d2b79f5;
    let next = state;
    next = Math.imul(next ^ (next >>> 15), next | 1);
    next ^= next + Math.imul(next ^ (next >>> 7), next | 61);
    return ((next ^ (next >>> 14)) >>> 0) / 4294967296;
  };
}

function runOne(scenario: Scenario, runIndex: number, seed: string, maxPlayerTurns: number): { result: RunResult; timeline: TimelineRow[] } {
  const runId = `${scenario.factor.key}-x${formatX(scenario.x)}-r${String(runIndex + 1).padStart(3, "0")}`;
  const rng = seededRng(`${seed}:${runId}`);
  const table = createEmptyTable("ANALYSIS", `${seed}:${runId}`, "Host", `seat:${runId}`, false);
  const counters: MutableRunCounters = {
    localScarcityEvents: 0,
    localHoardingSkips: 0,
    localDelayPasses: 0,
    localBasketSkips: 0
  };
  const timeline: TimelineRow[] = [];
  let eventIndex = 0;
  let failureReason = "";
  let maxObservedHoardingIndex = 0;

  const record = () => {
    const row = timelineSnapshot(table, runId, scenario, runIndex, eventIndex);
    maxObservedHoardingIndex = Math.max(maxObservedHoardingIndex, row.maxForeignIngredientPile);
    timeline.push(row);
    eventIndex += 1;
  };

  const actor = table.participants[table.hostParticipantId] as Participant;
  applyIntentAndRecord(table, actor.id, { type: "start" }, record);

  try {
    while (table.phase !== "complete" && playerTurnCount(table) < maxPlayerTurns) {
      if (table.phase === "playing") {
        playCurrentProductionTurn(table, scenario, rng, counters, record);
      } else if (table.phase === "settlement") {
        playCurrentSettlementTurn(table, scenario, rng, counters, record);
      } else if (table.phase === "eating") {
        eatAvailableFood(table, record);
      } else {
        failureReason = `Unexpected phase ${table.phase}`;
        break;
      }
    }
    if (table.phase !== "complete" && !failureReason) {
      failureReason = `Exceeded ${maxPlayerTurns} player turns`;
    }
  } catch (error) {
    failureReason = error instanceof Error ? error.message : String(error);
  }

  const stats = computeGameStats(table);
  const milestones = computeMilestones(table.transactionHistory);
  const scarcityPressureTotal = Object.values(table.scarcityPressureByIngredient ?? {}).reduce((total, value) => total + value, 0);
  const totalDishesRequired = activeParticipants(table).length * table.targetDishCount;
  const result: RunResult = {
    runId,
    factor: scenario.factor.key,
    factorLabel: scenario.factor.label,
    x: scenario.x,
    runIndex: runIndex + 1,
    seed: `${seed}:${runId}`,
    ok: table.phase === "complete",
    failureReason,
    phase: table.phase,
    productionTurns: milestones.productionTurns,
    settlementTurns: milestones.settlementTurns,
    successTurns: milestones.successTurns,
    completionTurns: stats.playerTurnCount,
    mutationTurns: table.turn,
    preparedDishes: stats.prepareCount,
    totalDishesRequired,
    redemptions: stats.redemptionCount,
    commonBasketSwaps: stats.commonBasketSwapCount,
    directExchanges: stats.directExchangeCount,
    settlementSwaps: stats.settlementSwapCount,
    foodPieceSettlementSwaps: stats.foodPieceSettlementSwapCount,
    interactions: stats.interactionCount,
    basketVelocity: stats.basketVelocity,
    directExchangeShare: stats.directExchangeShare,
    settlementBurden: stats.settlementBurden,
    liquidityDepth: stats.liquidityDepth,
    finalHoardingIndex: stats.hoardingIndex,
    maxObservedHoardingIndex,
    scarcityPressureTotal,
    localScarcityEvents: counters.localScarcityEvents,
    localHoardingSkips: counters.localHoardingSkips,
    localDelayPasses: counters.localDelayPasses,
    localBasketSkips: counters.localBasketSkips
  };
  return { result, timeline };
}

function playCurrentProductionTurn(
  table: Table,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): void {
  const actor = currentActor(table);
  if (!actor) {
    throw new Error("No current production actor.");
  }

  if (respondToIncomingOffer(table, actor, scenario, rng, counters, record)) {
    redeemAndPass(table, actor.id, record);
    return;
  }

  if (rng() < scenario.coordinationDelayProbability) {
    counters.localDelayPasses += 1;
    pass(table, actor.id, record);
    return;
  }

  const recipe = table.recipes[actor.id];
  if (!recipe) {
    pass(table, actor.id, record);
    return;
  }

  let moved = false;
  for (let guard = 0; guard < 3; guard += 1) {
    const needed = firstOutstandingIngredientNotCoveredByHand(table, actor.id, recipe);
    if (!needed) {
      break;
    }
    const platterCount = platterVoucherIds(table).filter((voucherId) => table.vouchers[voucherId].ingredientId === needed).length;
    if (platterCount > 0) {
      if (rng() < scenario.basketSkipProbability || (platterCount === 1 && rng() < scenario.lastIngredientDelayProbability)) {
        counters.localBasketSkips += 1;
        break;
      }
      const giveIngredientId = spendableIngredientForTrade(table, actor.id, scenario, rng, counters, needed);
      if (giveIngredientId) {
        applyIntentAndRecord(
          table,
          actor.id,
          { type: "platter_swap_ingredient", giveIngredientId, takeIngredientId: needed },
          record
        );
        moved = true;
        continue;
      }
      const givePartId = inventoryDishPartIds(table, actor.id)[0];
      const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ingredientId === needed);
      if (!givePartId || !takeVoucherId) {
        break;
      }
      applyIntentAndRecord(
        table,
        actor.id,
        {
          type: "platter_asset_swap",
          give: { kind: "dish_part", id: givePartId },
          take: { kind: "voucher", id: takeVoucherId }
        },
        record
      );
      moved = true;
      continue;
    }

    if (createIngredientRequest(table, actor, needed, scenario, rng, counters, record)) {
      moved = true;
    }
    break;
  }

  if (!moved && !hasUsefulHandVoucher(table, actor.id)) {
    pass(table, actor.id, record);
    return;
  }
  redeemAndPass(table, actor.id, record);
}

function playCurrentSettlementTurn(
  table: Table,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): void {
  const actor = currentActor(table);
  if (!actor) {
    throw new Error("No current settlement actor.");
  }

  if (respondToIncomingOffer(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }

  if (rng() < scenario.coordinationDelayProbability) {
    counters.localDelayPasses += 1;
    pass(table, actor.id, record);
    return;
  }

  if (returnForeignCardViaOffer(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }
  if (returnForeignCardViaPlatter(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }
  if (resolvePlatterDebt(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }
  if (seedOwnFoodPartForReturns(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }
  if (resolvePlatterShortfall(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }
  if (clearLoosePlatterFoodPart(table, actor, scenario, rng, counters, record)) {
    passIfStillCurrent(table, actor.id, record);
    return;
  }

  pass(table, actor.id, record);
}

function eatAvailableFood(table: Table, record: () => void): void {
  for (const participant of activeParticipants(table)) {
    if (inventoryDishPartIds(table, participant.id).length > 0) {
      applyIntentAndRecord(table, participant.id, { type: "bite_all" }, record);
      return;
    }
  }
  throw new Error("Eating phase has no held food parts.");
}

function respondToIncomingOffer(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const offer = Object.values(table.offers).find((candidate) => candidate.status === "pending" && candidate.toParticipantId === actor.id);
  if (!offer) {
    return false;
  }
  const requested = offer.requestedAsset;
  if (!requested) {
    applyIntentAndRecord(table, actor.id, { type: "respond_offer", offerId: offer.id, response: "refuse" }, record);
    return true;
  }

  if (requested.kind === "voucher") {
    if (shouldWithholdRequestedVoucher(table, actor.id, requested.ingredientId, scenario, rng)) {
      counters.localScarcityEvents += 1;
      applyIntentAndRecord(table, actor.id, { type: "respond_offer", offerId: offer.id, response: "refuse" }, record);
      return true;
    }
    const voucherIds = matchingHandVoucherIds(table, actor.id, requested.ingredientId, requested.ownerParticipantId).slice(0, requested.quantity);
    applyIntentAndRecord(
      table,
      actor.id,
      {
        type: "respond_offer",
        offerId: offer.id,
        response: voucherIds.length === requested.quantity ? "accept" : "refuse",
        voucherIds
      },
      record
    );
    if (voucherIds.length !== requested.quantity) {
      counters.localScarcityEvents += 1;
    }
    return true;
  }

  const parts = Object.values(table.dishParts ?? {})
    .filter(
      (part) =>
        part.location.type === "inventory" &&
        part.location.participantId === actor.id &&
        (!requested.dishId || part.dishId === requested.dishId) &&
        (!requested.makerParticipantId || part.makerParticipantId === requested.makerParticipantId)
    )
    .sort((left, right) => left.id.localeCompare(right.id))
    .slice(0, requested.quantity)
    .map((part) => ({ kind: "dish_part" as const, id: part.id }));
  applyIntentAndRecord(
    table,
    actor.id,
    {
      type: "respond_offer",
      offerId: offer.id,
      response: parts.length === requested.quantity ? "accept" : "refuse",
      assets: parts
    },
    record
  );
  return true;
}

function createIngredientRequest(
  table: Table,
  actor: Participant,
  ingredientId: string,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  if (Object.values(table.offers).some((offer) => offer.status === "pending" && offer.fromParticipantId === actor.id)) {
    return false;
  }
  const desiredVoucher = holderVoucherForIngredient(table, actor.id, ingredientId);
  if (!desiredVoucher?.location.participantId || desiredVoucher.location.participantId === actor.id) {
    counters.localScarcityEvents += 1;
    return false;
  }
  const holder = table.participants[desiredVoucher.location.participantId];
  if (!holder) {
    counters.localScarcityEvents += 1;
    return false;
  }
  const offeredVoucherId = spendableVoucherIdForTrade(table, actor.id, scenario, rng, counters, ingredientId);
  const offeredPartId = offeredVoucherId ? undefined : inventoryDishPartIds(table, actor.id)[0];
  if (!offeredVoucherId && !offeredPartId) {
    return false;
  }
  try {
    applyIntentAndRecord(
      table,
      actor.id,
      {
        type: "create_offer",
        toParticipantId: holder.id,
        offeredVoucherIds: offeredVoucherId ? [offeredVoucherId] : undefined,
        offeredAssets: offeredPartId ? [{ kind: "dish_part", id: offeredPartId }] : undefined,
        requestedAsset: { kind: "voucher", ingredientId, ownerParticipantId: desiredVoucher.ownerParticipantId, quantity: 1 }
      },
      record
    );
    return true;
  } catch (error) {
    counters.localScarcityEvents += 1;
    return false;
  }
}

function returnForeignCardViaOffer(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  if (Object.values(table.offers).some((offer) => offer.status === "pending" && offer.fromParticipantId === actor.id)) {
    return false;
  }
  const foreignVoucher = handVoucherIds(table, actor.id)
    .map((voucherId) => table.vouchers[voucherId])
    .filter((voucher) => voucher.ownerParticipantId !== actor.id)
    .filter((voucher) => {
      if (rng() >= scenario.hoardingProbability) {
        return true;
      }
      counters.localHoardingSkips += 1;
      return false;
    })
    .sort((left, right) => ownerSettlementRank(table, right.ownerParticipantId) - ownerSettlementRank(table, left.ownerParticipantId))[0];
  if (!foreignVoucher) {
    return false;
  }
  const owner = table.participants[foreignVoucher.ownerParticipantId];
  if (!owner || inventoryDishPartIds(table, owner.id).length === 0) {
    return false;
  }
  try {
    applyIntentAndRecord(
      table,
      actor.id,
      {
        type: "create_offer",
        toParticipantId: owner.id,
        offeredVoucherIds: [foreignVoucher.id],
        requestedAsset: { kind: "dish_part", makerParticipantId: owner.id, quantity: 1 }
      },
      record
    );
    return true;
  } catch {
    return false;
  }
}

function returnForeignCardViaPlatter(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const voucher = handVoucherIds(table, actor.id)
    .map((voucherId) => table.vouchers[voucherId])
    .filter((candidate) => candidate.ownerParticipantId !== actor.id)
    .filter((candidate) => {
      const account = platterAccountForParticipant(table, candidate.ownerParticipantId);
      return account.platterShortfall > 0;
    })
    .filter(() => {
      if (rng() >= scenario.hoardingProbability) {
        return true;
      }
      counters.localHoardingSkips += 1;
      return false;
    })
    .sort((left, right) => ownerSettlementRank(table, right.ownerParticipantId) - ownerSettlementRank(table, left.ownerParticipantId))[0];
  if (!voucher) {
    return false;
  }
  if (shouldWithholdSettlementVoucher(table, actor.id, voucher, scenario, rng)) {
    counters.localScarcityEvents += 1;
    return false;
  }
  if (shouldSkipBasketMove(scenario, rng, counters)) {
    return false;
  }
  const takePartId = platterDishPartIds(table).find((partId) => table.dishParts[partId].makerParticipantId === voucher.ownerParticipantId);
  if (!takePartId) {
    return false;
  }
  try {
    applyIntentAndRecord(
      table,
      actor.id,
      {
        type: "platter_asset_swap",
        give: { kind: "voucher", id: voucher.id },
        take: { kind: "dish_part", id: takePartId }
      },
      record
    );
    return true;
  } catch {
    return false;
  }
}

function resolvePlatterDebt(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const account = platterAccountForParticipant(table, actor.id);
  if (account.platterDebt <= 0) {
    return false;
  }
  const ownPlatterVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId === actor.id);
  const givePartId = inventoryDishPartIds(table, actor.id)[0];
  if (!ownPlatterVoucherId || !givePartId) {
    return false;
  }
  if (shouldSkipBasketMove(scenario, rng, counters)) {
    return false;
  }
  applyIntentAndRecord(
    table,
    actor.id,
    {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: givePartId },
      take: { kind: "voucher", id: ownPlatterVoucherId }
    },
    record
  );
  return true;
}

function seedOwnFoodPartForReturns(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const account = platterAccountForParticipant(table, actor.id);
  if (account.ownCardsInOtherHands <= 0) {
    return false;
  }
  if (platterDishPartIds(table).some((partId) => table.dishParts[partId].makerParticipantId === actor.id)) {
    return false;
  }
  const ownHeldPartId = inventoryDishPartIds(table, actor.id).find((partId) => table.dishParts[partId].makerParticipantId === actor.id);
  const takePartId = platterDishPartIds(table).find((partId) => table.dishParts[partId].makerParticipantId !== actor.id);
  if (!ownHeldPartId || !takePartId) {
    return false;
  }
  if (shouldSkipBasketMove(scenario, rng, counters)) {
    return false;
  }
  applyIntentAndRecord(
    table,
    actor.id,
    {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: ownHeldPartId },
      take: { kind: "dish_part", id: takePartId }
    },
    record
  );
  return true;
}

function resolvePlatterShortfall(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const account = platterAccountForParticipant(table, actor.id);
  if (account.platterShortfall <= 0 || account.ownCardsInOtherHands > 0) {
    return false;
  }
  const ownHandVoucherId = handVoucherIds(table, actor.id).find((voucherId) => table.vouchers[voucherId].ownerParticipantId === actor.id);
  const takePartId = platterDishPartIds(table)[0];
  if (!ownHandVoucherId || !takePartId) {
    return false;
  }
  const voucher = table.vouchers[ownHandVoucherId];
  if (shouldWithholdSettlementVoucher(table, actor.id, voucher, scenario, rng)) {
    counters.localScarcityEvents += 1;
    return false;
  }
  if (shouldSkipBasketMove(scenario, rng, counters)) {
    return false;
  }
  applyIntentAndRecord(
    table,
    actor.id,
    {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: ownHandVoucherId },
      take: { kind: "dish_part", id: takePartId }
    },
    record
  );
  return true;
}

function clearLoosePlatterFoodPart(
  table: Table,
  actor: Participant,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  record: () => void
): boolean {
  const account = platterAccountForParticipant(table, actor.id);
  if (!account.cleared) {
    return false;
  }
  const foreignVoucherId = handVoucherIds(table, actor.id).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== actor.id);
  const takePartId = platterDishPartIds(table)[0];
  if (!foreignVoucherId || !takePartId) {
    return false;
  }
  const voucher = table.vouchers[foreignVoucherId];
  if (shouldWithholdSettlementVoucher(table, actor.id, voucher, scenario, rng)) {
    counters.localScarcityEvents += 1;
    return false;
  }
  if (shouldSkipBasketMove(scenario, rng, counters)) {
    return false;
  }
  applyIntentAndRecord(
    table,
    actor.id,
    {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: foreignVoucherId },
      take: { kind: "dish_part", id: takePartId }
    },
    record
  );
  return true;
}

function shouldSkipBasketMove(scenario: Scenario, rng: () => number, counters: MutableRunCounters): boolean {
  if (rng() >= scenario.basketSkipProbability) {
    return false;
  }
  counters.localBasketSkips += 1;
  return true;
}

function shouldWithholdSettlementVoucher(
  table: Table,
  holderParticipantId: string,
  voucher: Voucher,
  scenario: Scenario,
  rng: () => number
): boolean {
  if (rng() >= scenario.lastIngredientDelayProbability) {
    return false;
  }
  const heldCount = matchingHandVoucherIds(table, holderParticipantId, voucher.ingredientId, voucher.ownerParticipantId).length;
  const platterCount = platterVoucherIds(table).filter((voucherId) => {
    const platterVoucher = table.vouchers[voucherId];
    return platterVoucher.ingredientId === voucher.ingredientId && platterVoucher.ownerParticipantId === voucher.ownerParticipantId;
  }).length;
  return heldCount + platterCount <= scenario.lastIngredientThreshold;
}

function firstOutstandingIngredientNotCoveredByHand(table: Table, participantId: string, recipe: Recipe): string | undefined {
  const usefulHandCounts = new Map<string, number>();
  for (const voucherId of handVoucherIds(table, participantId)) {
    const ingredientId = table.vouchers[voucherId].ingredientId;
    usefulHandCounts.set(ingredientId, (usefulHandCounts.get(ingredientId) ?? 0) + 1);
  }
  return recipe.requirements
    .map((requirement) => ({
      ingredientId: requirement.ingredientId,
      outstanding: Math.max(0, requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length)
    }))
    .filter((requirement) => requirement.outstanding > 0)
    .sort((left, right) => right.outstanding - left.outstanding || left.ingredientId.localeCompare(right.ingredientId))
    .find((requirement) => (usefulHandCounts.get(requirement.ingredientId) ?? 0) < requirement.outstanding)?.ingredientId;
}

function hasUsefulHandVoucher(table: Table, participantId: string): boolean {
  const recipe = table.recipes[participantId];
  if (!recipe) {
    return false;
  }
  return handVoucherIds(table, participantId).some((voucherId) => {
    const voucher = table.vouchers[voucherId];
    return recipe.requirements.some(
      (requirement) =>
        requirement.ingredientId === voucher.ingredientId &&
        requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length > 0
    );
  });
}

function spendableIngredientForTrade(
  table: Table,
  participantId: string,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  desiredIngredientId: string
): string | undefined {
  const voucherId = spendableVoucherIdForTrade(table, participantId, scenario, rng, counters, desiredIngredientId);
  return voucherId ? table.vouchers[voucherId].ingredientId : undefined;
}

function spendableVoucherIdForTrade(
  table: Table,
  participantId: string,
  scenario: Scenario,
  rng: () => number,
  counters: MutableRunCounters,
  desiredIngredientId: string
): string | undefined {
  const protectedCounts = protectedUsefulHandCounts(table, participantId);
  const hand = handVoucherIds(table, participantId)
    .map((voucherId) => table.vouchers[voucherId])
    .filter((voucher) => voucher.ingredientId !== desiredIngredientId)
    .sort((left, right) => voucherSpendRank(table, participantId, left) - voucherSpendRank(table, participantId, right));

  for (const voucher of hand) {
    const remainingProtected = protectedCounts.get(voucher.ingredientId) ?? 0;
    if (remainingProtected > 0) {
      protectedCounts.set(voucher.ingredientId, remainingProtected - 1);
      continue;
    }
    if (voucher.ownerParticipantId !== participantId && rng() < scenario.hoardingProbability) {
      counters.localHoardingSkips += 1;
      continue;
    }
    return voucher.id;
  }
  return undefined;
}

function protectedUsefulHandCounts(table: Table, participantId: string): Map<string, number> {
  const recipe = table.recipes[participantId];
  const protectedCounts = new Map<string, number>();
  if (!recipe) {
    return protectedCounts;
  }
  const heldCounts = new Map<string, number>();
  for (const voucherId of handVoucherIds(table, participantId)) {
    const ingredientId = table.vouchers[voucherId].ingredientId;
    heldCounts.set(ingredientId, (heldCounts.get(ingredientId) ?? 0) + 1);
  }
  for (const requirement of recipe.requirements) {
    const outstanding = Math.max(0, requirement.requiredQty - requirement.redeemedQty - requirement.placedVoucherIds.length);
    protectedCounts.set(requirement.ingredientId, Math.min(outstanding, heldCounts.get(requirement.ingredientId) ?? 0));
  }
  return protectedCounts;
}

function voucherSpendRank(table: Table, participantId: string, voucher: Voucher): number {
  if (voucher.ownerParticipantId === participantId) {
    return 0;
  }
  const ownerAccount = platterAccountForParticipant(table, voucher.ownerParticipantId);
  return 10 - ownerAccount.platterShortfall;
}

function matchingHandVoucherIds(table: Table, participantId: string, ingredientId: string, ownerParticipantId?: string): string[] {
  return handVoucherIds(table, participantId)
    .filter((voucherId) => {
      const voucher = table.vouchers[voucherId];
      return voucher.ingredientId === ingredientId && (!ownerParticipantId || voucher.ownerParticipantId === ownerParticipantId);
    })
    .sort();
}

function shouldWithholdRequestedVoucher(
  table: Table,
  participantId: string,
  ingredientId: string,
  scenario: Scenario,
  rng: () => number
): boolean {
  if (rng() >= scenario.lastIngredientDelayProbability) {
    return false;
  }
  const owner = ownerForIngredient(table, ingredientId);
  if (!owner || owner.id !== participantId) {
    return false;
  }
  const ownHandCount = matchingHandVoucherIds(table, participantId, ingredientId, owner.id).length;
  const platterCount = platterVoucherIds(table).filter((voucherId) => table.vouchers[voucherId].ingredientId === ingredientId).length;
  return ownHandCount <= scenario.lastIngredientThreshold || platterCount <= 1;
}

function ownerForIngredient(table: Table, ingredientId: string): Participant | undefined {
  return activeParticipants(table).find((participant) => participant.ingredientId === ingredientId);
}

function holderVoucherForIngredient(table: Table, requesterParticipantId: string, ingredientId: string): Voucher | undefined {
  return Object.values(table.vouchers)
    .filter(
      (voucher) =>
        voucher.ingredientId === ingredientId &&
        voucher.location.type === "hand" &&
        voucher.location.participantId &&
        voucher.location.participantId !== requesterParticipantId
    )
    .sort((left, right) => {
      const leftHolder = left.location.participantId as string;
      const rightHolder = right.location.participantId as string;
      const leftOwnerFirst = left.ownerParticipantId === leftHolder ? 0 : 1;
      const rightOwnerFirst = right.ownerParticipantId === rightHolder ? 0 : 1;
      return leftOwnerFirst - rightOwnerFirst || left.id.localeCompare(right.id);
    })[0];
}

function ownerSettlementRank(table: Table, participantId: string): number {
  const account = platterAccountForParticipant(table, participantId);
  return account.ownCardsInOtherHands * 10 + account.platterShortfall * 3 + account.platterDebt;
}

function currentActor(table: Table): Participant | undefined {
  const participantId = table.currentTurnParticipantId;
  return participantId ? table.participants[participantId] : undefined;
}

function pass(table: Table, participantId: string, record: () => void): void {
  applyIntentAndRecord(table, participantId, { type: "pass_turn" }, record);
}

function passIfStillCurrent(table: Table, participantId: string, record: () => void): void {
  if (table.currentTurnParticipantId === participantId && (table.phase === "playing" || table.phase === "settlement")) {
    pass(table, participantId, record);
  }
}

function redeemAndPass(table: Table, participantId: string, record: () => void): void {
  if (table.currentTurnParticipantId === participantId && table.phase === "playing") {
    applyIntentAndRecord(table, participantId, { type: "redeem_all_and_pass_turn" }, record);
  } else if (table.currentTurnParticipantId === participantId && table.phase === "settlement") {
    pass(table, participantId, record);
  }
}

function applyIntentAndRecord(table: Table, participantId: string, intent: Intent, record: () => void): void {
  applyIntent(table, participantId, intent);
  record();
}

function playerTurnCount(table: Table): number {
  return table.transactionHistory.filter((transaction) => transaction.action === "Pass Turn").length;
}

function timelineSnapshot(
  table: Table,
  runId: string,
  scenario: Scenario,
  runIndex: number,
  eventIndex: number
): TimelineRow {
  const accounts = activeParticipants(table).map((participant) => platterAccountForParticipant(table, participant.id));
  const platterIngredientIds = platterVoucherIds(table).map((voucherId) => table.vouchers[voucherId].ingredientId);
  const scarcityPressureTotal = Object.values(table.scarcityPressureByIngredient ?? {}).reduce((total, value) => total + value, 0);
  return {
    runId,
    factor: scenario.factor.key,
    factorLabel: scenario.factor.label,
    x: scenario.x,
    runIndex: runIndex + 1,
    eventIndex,
    playerTurns: playerTurnCount(table),
    mutationTurn: table.turn,
    phase: table.phase,
    preparedDishes: table.transactionHistory.filter((transaction) => transaction.action === "Prepare").length,
    redeemedUnits: table.transactionHistory.filter((transaction) => transaction.action === "Redeem").length,
    platterVoucherCount: platterIngredientIds.length,
    platterDistinctIngredients: new Set(platterIngredientIds).size,
    platterFoodParts: platterDishPartIds(table).length,
    foreignCardsInHands: accounts.reduce((total, account) => total + account.foreignCardsInHand, 0),
    maxForeignIngredientPile: maxForeignIngredientPile(table),
    unsettledAccounts: accounts.filter((account) => !account.cleared).length,
    totalPlatterDebt: accounts.reduce((total, account) => total + account.platterDebt, 0),
    totalPlatterShortfall: accounts.reduce((total, account) => total + account.platterShortfall, 0),
    scarcityPressureTotal
  };
}

function maxForeignIngredientPile(table: Table): number {
  const counts = new Map<string, number>();
  for (const voucher of Object.values(table.vouchers)) {
    if (voucher.location.type !== "hand" || !voucher.location.participantId || voucher.location.participantId === voucher.ownerParticipantId) {
      continue;
    }
    const key = `${voucher.location.participantId}:${voucher.ingredientId}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return Math.max(0, ...counts.values());
}

function computeMilestones(history: TransactionRecord[]): { productionTurns: number; settlementTurns: number; successTurns: number } {
  let passCount = 0;
  let productionTurns = 0;
  let successTurns = 0;
  for (const transaction of history) {
    if (transaction.action === "Pass Turn") {
      passCount += 1;
    }
    if (transaction.action === "Prepare") {
      productionTurns = passCount;
    }
    if (transaction.action === "Eat" && successTurns === 0) {
      successTurns = passCount;
    }
  }
  if (successTurns === 0) {
    successTurns = passCount;
  }
  return {
    productionTurns,
    settlementTurns: Math.max(0, successTurns - productionTurns),
    successTurns
  };
}

function summarize(results: RunResult[]): SummaryRow[] {
  const grouped = new Map<string, RunResult[]>();
  for (const result of results) {
    const key = `${result.factor}:${result.x}`;
    grouped.set(key, [...(grouped.get(key) ?? []), result]);
  }
  const rows: SummaryRow[] = [];
  for (const group of grouped.values()) {
    const successes = group.filter((result) => result.ok);
    const reference = group[0] as RunResult;
    rows.push({
      factor: reference.factor,
      factorLabel: reference.factorLabel,
      x: reference.x,
      runs: group.length,
      successes: successes.length,
      successRate: successes.length / group.length,
      medianSuccessTurns: median(successes.map((result) => result.successTurns)),
      p25SuccessTurns: percentile(successes.map((result) => result.successTurns), 25),
      p75SuccessTurns: percentile(successes.map((result) => result.successTurns), 75),
      meanProductionTurns: mean(successes.map((result) => result.productionTurns)),
      meanSettlementTurns: mean(successes.map((result) => result.settlementTurns)),
      meanInteractions: mean(successes.map((result) => result.interactions)),
      meanMaxHoardingIndex: mean(successes.map((result) => result.maxObservedHoardingIndex)),
      meanScarcityEvents: mean(successes.map((result) => result.localScarcityEvents + result.scarcityPressureTotal))
    });
  }
  return rows.sort((left, right) => left.factor.localeCompare(right.factor) || left.x - right.x);
}

interface SummaryRow {
  factor: FactorKey;
  factorLabel: string;
  x: number;
  runs: number;
  successes: number;
  successRate: number;
  medianSuccessTurns: number;
  p25SuccessTurns: number;
  p75SuccessTurns: number;
  meanProductionTurns: number;
  meanSettlementTurns: number;
  meanInteractions: number;
  meanMaxHoardingIndex: number;
  meanScarcityEvents: number;
}

function mean(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }
  return values.reduce((total, value) => total + value, 0) / values.length;
}

function median(values: number[]): number {
  return percentile(values, 50);
}

function percentile(values: number[], pct: number): number {
  if (values.length === 0) {
    return 0;
  }
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil((pct / 100) * sorted.length) - 1));
  return sorted[index] as number;
}

function csvEscape(value: unknown): string {
  if (typeof value === "number") {
    return Number.isInteger(value) ? String(value) : String(Math.round(value * 1000) / 1000);
  }
  const text = String(value ?? "");
  return /[",\n]/u.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function rowsToCsv<T extends Record<string, unknown>>(rows: T[], columns: Array<keyof T>): string {
  const header = columns.map(String).join(",");
  const body = rows.map((row) => columns.map((column) => csvEscape(row[column])).join(",")).join("\n");
  return `${header}\n${body}\n`;
}

function formatX(value: number): string {
  return String(Math.round(value * 100)).padStart(2, "0");
}

async function writeOutputs(options: Options, results: RunResult[], timeline: TimelineRow[], summaries: SummaryRow[]): Promise<void> {
  const figuresDir = path.join(options.outputDir, "figures");
  await mkdir(figuresDir, { recursive: true });
  await writeFile(
    path.join(options.outputDir, "simulation_runs.csv"),
    rowsToCsv(results, [
      "runId",
      "factor",
      "factorLabel",
      "x",
      "runIndex",
      "seed",
      "ok",
      "failureReason",
      "phase",
      "productionTurns",
      "settlementTurns",
      "successTurns",
      "completionTurns",
      "mutationTurns",
      "preparedDishes",
      "totalDishesRequired",
      "redemptions",
      "commonBasketSwaps",
      "directExchanges",
      "settlementSwaps",
      "foodPieceSettlementSwaps",
      "interactions",
      "basketVelocity",
      "directExchangeShare",
      "settlementBurden",
      "liquidityDepth",
      "finalHoardingIndex",
      "maxObservedHoardingIndex",
      "scarcityPressureTotal",
      "localScarcityEvents",
      "localHoardingSkips",
      "localDelayPasses",
      "localBasketSkips"
    ]),
    "utf8"
  );
  await writeFile(
    path.join(options.outputDir, "summary_by_factor.csv"),
    rowsToCsv(summaries, [
      "factor",
      "factorLabel",
      "x",
      "runs",
      "successes",
      "successRate",
      "medianSuccessTurns",
      "p25SuccessTurns",
      "p75SuccessTurns",
      "meanProductionTurns",
      "meanSettlementTurns",
      "meanInteractions",
      "meanMaxHoardingIndex",
      "meanScarcityEvents"
    ]),
    "utf8"
  );
  await writeFile(
    path.join(options.outputDir, "turn_timeline.csv"),
    rowsToCsv(timeline, [
      "runId",
      "factor",
      "factorLabel",
      "x",
      "runIndex",
      "eventIndex",
      "playerTurns",
      "mutationTurn",
      "phase",
      "preparedDishes",
      "redeemedUnits",
      "platterVoucherCount",
      "platterDistinctIngredients",
      "platterFoodParts",
      "foreignCardsInHands",
      "maxForeignIngredientPile",
      "unsettledAccounts",
      "totalPlatterDebt",
      "totalPlatterShortfall",
      "scarcityPressureTotal"
    ]),
    "utf8"
  );
  await writeFile(
    path.join(options.outputDir, "manifest.json"),
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        seed: options.seed,
        runsPerCell: options.runsPerCell,
        levels: options.levels,
        maxPlayerTurns: options.maxPlayerTurns,
        factors: options.factors.map((factor) => FACTORS[factor]),
        files: {
          runs: "simulation_runs.csv",
          summary: "summary_by_factor.csv",
          timeline: "turn_timeline.csv",
          figures: ["figures/time_to_success.svg", "figures/production_vs_settlement.svg", "figures/success_rate.svg"]
        }
      },
      null,
      2
    )}\n`,
    "utf8"
  );
  await writeFile(path.join(figuresDir, "time_to_success.svg"), renderTimeToSuccessSvg(summaries), "utf8");
  await writeFile(path.join(figuresDir, "production_vs_settlement.svg"), renderProductionSettlementSvg(summaries), "utf8");
  await writeFile(path.join(figuresDir, "success_rate.svg"), renderSuccessRateSvg(summaries), "utf8");
  await writeFile(path.join(options.outputDir, "REPORT.md"), renderReport(options, summaries), "utf8");
}

function renderReport(options: Options, summaries: SummaryRow[]): string {
  const finalRows = summaries.filter((row) => row.x === Math.max(...options.levels));
  const xMin = Math.min(...options.levels);
  const xMax = Math.max(...options.levels);
  const sampled = (mapper: (x: number) => number | string) => options.levels.map((level) => mapper(level)).join(", ");
  const lines = finalRows
    .map(
      (row) =>
        `- ${row.factorLabel}: median time to clearance ${round(row.medianSuccessTurns)} turns, clearance rate ${round(row.successRate * 100)}%, mean production ${round(
          row.meanProductionTurns
        )}, mean settlement ${round(row.meanSettlementTurns)}.`
    )
    .join("\n");
  return `# Economic Time To Clearance Monte Carlo

This output is generated by \`npm run analyze:economics\`.

The primary term is **production-to-clearance cycle**. The metric is **time to clearance**: turns from start until all products are produced and all obligations are cleared back to the starting settlement condition. The simulator measures clearance at the first eating event, then continues through eating to verify that the table reaches \`complete\`; consumption turns are not counted as part of time to clearance.

## Scenario Definitions

Scenario intensity \`x\` is the independent variable on the charts. This run sampled \`${options.levels.join(", ")}\`, so the plotted range is \`${xMin}\` to \`${xMax}\`. Each scenario changes one friction parameter at a time while the other friction parameters remain at zero. Each scenario can affect the production stage and the settlement stage of the production-to-clearance cycle.

- **Coordination delay:** \`x\` increases the chance that the current player sees no useful production or settlement move and simply passes. The applied pass probability is \`0.55 * x\`, ranging from \`${formatParameter(0.55 * xMin)}\` to \`${formatParameter(0.55 * xMax)}\` in this run.
- **Hoarding surplus:** \`x\` is the chance that a player refuses to spend or return a surplus foreign voucher they do not currently need for their own recipe. During settlement this delays promise-card return. The applied hoarding probability is \`x\`, ranging from \`${xMin}\` to \`${xMax}\`.
- **Last-ingredient reluctance:** \`x\` is the chance that a player withholds a scarce voucher when another player requests it, when it is the last visible basket copy, or when settlement would move a scarce promise card back toward clearance. The applied refusal probability is \`x\`, ranging from \`${xMin}\` to \`${xMax}\`; the low-stock threshold is \`1 + ceil(5 * x)\`, which is \`${1 + Math.ceil(5 * xMin)}\` to \`${1 + Math.ceil(5 * xMax)}\` held/platter vouchers in this run.
- **Common Basket thinness:** \`x\` is the chance that a player skips an otherwise useful Common Basket swap, during either production or settlement, forcing the game toward slower direct coordination. The applied basket-skip probability is \`x\`, ranging from \`${xMin}\` to \`${xMax}\`.

## Parameter Values Used

| Scenario | Parameter changed by \`x\` | Values at sampled \`x\` levels |
| --- | --- | --- |
| Coordination delay | Production/settlement unproductive-pass probability = \`0.55 * x\` | \`${sampled((x) => formatParameter(0.55 * x))}\` |
| Hoarding surplus | Surplus foreign-card hoarding probability = \`x\` | \`${sampled(formatParameter)}\` |
| Last-ingredient reluctance | Scarce-voucher refusal probability = \`x\`; low-stock threshold = \`1 + ceil(5 * x)\` | probability: \`${sampled(formatParameter)}\`; threshold: \`${sampled((x) => 1 + Math.ceil(5 * x))}\` |
| Common Basket thinness | Useful production/settlement basket-swap skip probability = \`x\` | \`${sampled(formatParameter)}\` |

## Highest x Results

${lines}

## Files

- \`simulation_runs.csv\`: one row per Monte Carlo run.
- \`summary_by_factor.csv\`: factor/x quantiles and means for charting.
- \`turn_timeline.csv\`: per-event state snapshots for later animation.
- \`figures/time_to_success.svg\`: median time to clearance.
- \`figures/production_vs_settlement.svg\`: mean production and settlement components of the production-to-clearance cycle.
- \`figures/success_rate.svg\`: clearance rate by x.
`;
}

function round(value: number): number {
  return Math.round(value * 10) / 10;
}

function formatParameter(value: number): string {
  return value.toFixed(4).replace(/0+$/u, "").replace(/\.$/u, "");
}

function renderTimeToSuccessSvg(rows: SummaryRow[]): string {
  return renderLineChart({
    title: "Time To Clearance",
    subtitle: "Median player turns in the production-to-clearance cycle; bands show p25-p75 across cleared runs",
    yLabel: "turns to clearance",
    series: Object.values(FACTORS).map((factor) => ({
      label: factor.label,
      color: colorForFactor(factor.key),
      points: rows
        .filter((row) => row.factor === factor.key)
        .map((row) => ({ x: row.x, y: row.medianSuccessTurns, low: row.p25SuccessTurns, high: row.p75SuccessTurns }))
    }))
  });
}

function renderSuccessRateSvg(rows: SummaryRow[]): string {
  return renderLineChart({
    title: "Clearance Rate Under Economic Friction",
    subtitle: "Share of runs that cleared all products and obligations within the turn cap",
    yLabel: "clearance rate",
    yMaxOverride: 1,
    yFormat: (value) => `${Math.round(value * 100)}%`,
    series: Object.values(FACTORS).map((factor) => ({
      label: factor.label,
      color: colorForFactor(factor.key),
      points: rows.filter((row) => row.factor === factor.key).map((row) => ({ x: row.x, y: row.successRate }))
    }))
  });
}

function renderProductionSettlementSvg(rows: SummaryRow[]): string {
  const width = 1200;
  const height = 760;
  const margin = { left: 76, right: 210, top: 82, bottom: 82 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const maxY = niceMax(Math.max(...rows.map((row) => row.meanProductionTurns + row.meanSettlementTurns), 1));
  const xValues = [...new Set(rows.map((row) => row.x))].sort((left, right) => left - right);
  const groupWidth = plotWidth / Object.keys(FACTORS).length;
  const barGap = 4;
  const barWidth = Math.max(4, (groupWidth - 22) / xValues.length - barGap);
  const scaleY = (value: number) => margin.top + plotHeight - (value / maxY) * plotHeight;

  const bars: string[] = [];
  Object.values(FACTORS).forEach((factor, factorIndex) => {
    const factorRows = rows.filter((row) => row.factor === factor.key).sort((left, right) => left.x - right.x);
    const groupX = margin.left + factorIndex * groupWidth + 10;
    factorRows.forEach((row, xIndex) => {
      const x = groupX + xIndex * (barWidth + barGap);
      const showXLabel = xValues.length <= 10 || xIndex % 3 === 0 || xIndex === factorRows.length - 1;
      const productionY = scaleY(row.meanProductionTurns);
      const settlementY = scaleY(row.meanProductionTurns + row.meanSettlementTurns);
      const totalHeight = margin.top + plotHeight - settlementY;
      const productionHeight = margin.top + plotHeight - productionY;
      const settlementHeight = Math.max(0, productionY - settlementY);
      bars.push(
        `<rect x="${x}" y="${settlementY}" width="${barWidth}" height="${totalHeight}" fill="#d8dee9"/>`,
        `<rect x="${x}" y="${productionY}" width="${barWidth}" height="${productionHeight}" fill="${colorForFactor(factor.key)}"/>`,
        `<rect x="${x}" y="${settlementY}" width="${barWidth}" height="${settlementHeight}" fill="#111827" opacity="0.82"/>`,
        showXLabel
          ? `<text x="${x + barWidth / 2}" y="${height - 46}" text-anchor="middle" font-size="10" fill="#4b5563">${Math.round(row.x * 100)}</text>`
          : ""
      );
    });
    bars.push(
      `<text x="${groupX + groupWidth / 2 - 8}" y="${height - 22}" text-anchor="middle" font-size="13" fill="#111827">${escapeXml(
        factor.label
      )}</text>`
    );
  });

  return svgFrame(
    width,
    height,
    [
      chartTitle("Production-To-Clearance Cycle Components", "Mean player turns by factor and x; dark segment is settlement"),
      ...axisGrid(width, height, margin, maxY, (value) => String(Math.round(value))),
      `<text x="${margin.left + plotWidth / 2}" y="${height - 8}" text-anchor="middle" font-size="13" fill="#374151">x level, grouped by factor</text>`,
      `<text x="20" y="${margin.top + plotHeight / 2}" transform="rotate(-90 20 ${margin.top + plotHeight / 2})" text-anchor="middle" font-size="13" fill="#374151">mean player turns</text>`,
      ...bars,
      `<rect x="${width - 188}" y="126" width="14" height="14" fill="#111827" opacity="0.82"/><text x="${width - 166}" y="138" font-size="13" fill="#111827">settlement turns</text>`,
      `<rect x="${width - 188}" y="150" width="14" height="14" fill="#5b8def"/><text x="${width - 166}" y="162" font-size="13" fill="#111827">production turns</text>`
    ].join("\n")
  );
}

interface LineChartPoint {
  x: number;
  y: number;
  low?: number;
  high?: number;
}

interface LineChartSeries {
  label: string;
  color: string;
  points: LineChartPoint[];
}

function renderLineChart(config: {
  title: string;
  subtitle: string;
  yLabel: string;
  yMaxOverride?: number;
  yFormat?: (value: number) => string;
  series: LineChartSeries[];
}): string {
  const width = 1200;
  const height = 760;
  const margin = { left: 76, right: 250, top: 88, bottom: 74 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const allPoints = config.series.flatMap((series) => series.points);
    const maxX = Math.max(...allPoints.map((point) => point.x), 0.75);
  const maxY = config.yMaxOverride ?? niceMax(Math.max(...allPoints.flatMap((point) => [point.y, point.high ?? point.y]), 1));
  const yFormat = config.yFormat ?? ((value: number) => String(Math.round(value)));
  const scaleX = (value: number) => margin.left + (value / maxX) * plotWidth;
  const scaleY = (value: number) => margin.top + plotHeight - (value / maxY) * plotHeight;
  const parts: string[] = [chartTitle(config.title, config.subtitle), ...axisGrid(width, height, margin, maxY, yFormat)];

  for (const series of config.series) {
    const points = series.points.sort((left, right) => left.x - right.x);
    const bandPoints = points.filter((point) => point.low !== undefined && point.high !== undefined);
    if (bandPoints.length > 0) {
      const upper = bandPoints.map((point) => `${scaleX(point.x)},${scaleY(point.high as number)}`).join(" ");
      const lower = [...bandPoints]
        .reverse()
        .map((point) => `${scaleX(point.x)},${scaleY(point.low as number)}`)
        .join(" ");
      parts.push(`<polygon points="${upper} ${lower}" fill="${series.color}" opacity="0.14"/>`);
    }
    const path = points
      .map((point, index) => `${index === 0 ? "M" : "L"} ${scaleX(point.x).toFixed(1)} ${scaleY(point.y).toFixed(1)}`)
      .join(" ");
    parts.push(`<path d="${path}" fill="none" stroke="${series.color}" stroke-width="3" stroke-linejoin="round"/>`);
    for (const point of points) {
      parts.push(`<circle cx="${scaleX(point.x)}" cy="${scaleY(point.y)}" r="4.5" fill="${series.color}" stroke="#ffffff" stroke-width="1.5"/>`);
    }
  }

  parts.push(
    `<text x="${margin.left + plotWidth / 2}" y="${height - 20}" text-anchor="middle" font-size="13" fill="#374151">x: scenario intensity</text>`,
    `<text x="20" y="${margin.top + plotHeight / 2}" transform="rotate(-90 20 ${margin.top + plotHeight / 2})" text-anchor="middle" font-size="13" fill="#374151">${escapeXml(
      config.yLabel
    )}</text>`,
    ...legend(config.series, width - margin.right + 34, margin.top + 4)
  );
  return svgFrame(width, height, parts.join("\n"));
}

function axisGrid(
  width: number,
  height: number,
  margin: { left: number; right: number; top: number; bottom: number },
  maxY: number,
  yFormat: (value: number) => string
): string[] {
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const parts: string[] = [
    `<rect x="${margin.left}" y="${margin.top}" width="${plotWidth}" height="${plotHeight}" fill="#ffffff"/>`,
    `<line x1="${margin.left}" y1="${margin.top + plotHeight}" x2="${margin.left + plotWidth}" y2="${margin.top + plotHeight}" stroke="#111827" stroke-width="1"/>`,
    `<line x1="${margin.left}" y1="${margin.top}" x2="${margin.left}" y2="${margin.top + plotHeight}" stroke="#111827" stroke-width="1"/>`
  ];
  for (let i = 0; i <= 5; i += 1) {
    const value = (maxY / 5) * i;
    const y = margin.top + plotHeight - (value / maxY) * plotHeight;
    parts.push(
      `<line x1="${margin.left}" y1="${y}" x2="${margin.left + plotWidth}" y2="${y}" stroke="#e5e7eb" stroke-width="1"/>`,
      `<text x="${margin.left - 10}" y="${y + 4}" text-anchor="end" font-size="12" fill="#4b5563">${escapeXml(yFormat(value))}</text>`
    );
  }
  for (const value of [0, 0.15, 0.3, 0.45, 0.6, 0.75]) {
    const x = margin.left + (value / 0.75) * plotWidth;
    parts.push(
      `<line x1="${x}" y1="${margin.top}" x2="${x}" y2="${margin.top + plotHeight}" stroke="#f3f4f6" stroke-width="1"/>`,
      `<text x="${x}" y="${margin.top + plotHeight + 22}" text-anchor="middle" font-size="12" fill="#4b5563">${value.toFixed(2)}</text>`
    );
  }
  return parts;
}

function chartTitle(title: string, subtitle: string): string {
  return `<text x="76" y="38" font-size="25" font-weight="700" fill="#111827">${escapeXml(title)}</text>
<text x="76" y="62" font-size="14" fill="#4b5563">${escapeXml(subtitle)}</text>`;
}

function legend(series: LineChartSeries[], x: number, y: number): string[] {
  return series.flatMap((item, index) => {
    const itemY = y + index * 28;
    return [
      `<line x1="${x}" y1="${itemY}" x2="${x + 22}" y2="${itemY}" stroke="${item.color}" stroke-width="4"/>`,
      `<circle cx="${x + 11}" cy="${itemY}" r="4" fill="${item.color}" stroke="#ffffff" stroke-width="1"/>`,
      `<text x="${x + 32}" y="${itemY + 5}" font-size="13" fill="#111827">${escapeXml(item.label)}</text>`
    ];
  });
}

function svgFrame(width: number, height: number, body: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img">
<rect width="${width}" height="${height}" fill="#f8fafc"/>
${body}
</svg>
`;
}

function niceMax(value: number): number {
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const normalized = value / magnitude;
  const nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return nice * magnitude;
}

function colorForFactor(factor: FactorKey): string {
  switch (factor) {
    case "coordination_delay":
      return "#2563eb";
    case "hoarding":
      return "#dc2626";
    case "last_ingredient":
      return "#ca8a04";
    case "basket_thinness":
      return "#059669";
    default:
      return "#111827";
  }
}

function escapeXml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const results: RunResult[] = [];
  const timeline: TimelineRow[] = [];
  for (const factorKey of options.factors) {
    for (const x of options.levels) {
      const scenario = scenarioFor(FACTORS[factorKey], x);
      for (let runIndex = 0; runIndex < options.runsPerCell; runIndex += 1) {
        const run = runOne(scenario, runIndex, options.seed, options.maxPlayerTurns);
        results.push(run.result);
        timeline.push(...run.timeline);
      }
    }
  }
  const summaries = summarize(results);
  await writeOutputs(options, results, timeline, summaries);
  const failed = results.filter((result) => !result.ok).length;
  console.log(
    JSON.stringify(
      {
        ok: true,
        allRunsCompleted: failed === 0,
        outputDir: options.outputDir,
        runs: results.length,
        incompleteRuns: failed,
        summaryCsv: path.join(options.outputDir, "summary_by_factor.csv"),
        timelineCsv: path.join(options.outputDir, "turn_timeline.csv"),
        figuresDir: path.join(options.outputDir, "figures")
      },
      null,
      2
    )
  );
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
