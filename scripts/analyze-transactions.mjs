#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const DEFAULT_CATALOG_PATH = "client/data/recipe_catalog.json";
const SLOT_ORDER = ["initial", "followup_1", "followup_2"];
const DEFAULT_VOUCHERS_PER_INGREDIENT = 7;

export function analyzeTransactionCsv(csvText, catalogJson, options = {}) {
  const rows = parseCsv(csvText);
  const catalog = typeof catalogJson === "string" ? JSON.parse(catalogJson) : catalogJson;
  const ingredientNames = ingredientNameMap(catalog);
  const recipesByOwner = recipesByOwnerIngredient(catalog);
  const state = {
    hand: new Map(),
    platter: new Map(),
    participantIngredient: new Map(),
    recipeProgress: new Map(),
    prepareCount: new Map()
  };
  const actionCounts = new Map();
  const exchangesByCook = new Map();
  const passTurnsByCook = new Map();
  const prepareTurnsByCook = new Map();
  const nearCompletePasses = [];
  const missingAbsentFromBasketCounts = new Map();
  const botMissedOfferCandidates = [];
  const vouchersPerIngredient = Number(options.vouchersPerIngredient ?? DEFAULT_VOUCHERS_PER_INGREDIENT);

  for (const row of rows) {
    const action = row.Action ?? "";
    addCount(actionCounts, action);
    if (action === "Deposit") {
      const ingredientId = ingredientIdForLabel(row["Item out"], ingredientNames);
      if (ingredientId) {
        ensureParticipant(state, row.Name, ingredientId, vouchersPerIngredient);
        moveIngredient(state, row.Name, "platter", ingredientId, 1);
      }
      continue;
    }
    if (action === "Swap" || action === "Settlement Swap") {
      for (const ingredientId of ingredientIdsForItems(row["Item out"], ingredientNames)) {
        moveIngredient(state, row.Name, "platter", ingredientId, 1);
      }
      for (const ingredientId of ingredientIdsForItems(row["Item back"], ingredientNames)) {
        moveIngredient(state, "platter", row.Name, ingredientId, 1);
      }
      continue;
    }
    if (action === "Exchange") {
      addCount(exchangesByCook, row.Name);
      for (const ingredientId of ingredientIdsForItems(row["Item out"], ingredientNames)) {
        moveIngredient(state, row.Name, row.Counterparty, ingredientId, 1);
      }
      for (const ingredientId of ingredientIdsForItems(row["Item back"], ingredientNames)) {
        moveIngredient(state, row.Counterparty, row.Name, ingredientId, 1);
      }
      continue;
    }
    if (action === "Redeem") {
      const ingredientId = ingredientIdForLabel(row["Item out"], ingredientNames);
      if (ingredientId) {
        decrementHolding(state.hand, row.Name, ingredientId, 1);
        addNestedCount(state.recipeProgress, row.Name, ingredientId, 1);
      }
      continue;
    }
    if (action === "Prepare") {
      const turn = numericTurn(row);
      const list = ensureList(prepareTurnsByCook, row.Name);
      list.push({ turn, item: row["Item out"] ?? "" });
      state.recipeProgress.set(row.Name, new Map());
      state.prepareCount.set(row.Name, (state.prepareCount.get(row.Name) ?? 0) + 1);
      continue;
    }
    if (action === "Pass Turn") {
      ensureList(passTurnsByCook, row.Name).push(numericTurn(row));
      const passSummary = nearCompletePassSummary(state, recipesByOwner, row.Name);
      if (passSummary) {
        nearCompletePasses.push({ turn: numericTurn(row), cook: row.Name, ...passSummary });
        for (const ingredientId of passSummary.missingAbsentFromBasket) {
          addCount(missingAbsentFromBasketCounts, ingredientId);
        }
        if (isBotName(row.Name) && passSummary.directOfferCandidates.length > 0) {
          botMissedOfferCandidates.push({ turn: numericTurn(row), cook: row.Name, ...passSummary });
        }
      }
    }
  }

  const firstTurn = rows.length > 0 ? numericTurn(rows[0]) : 0;
  const prepareTiming = prepareTimingSummary(prepareTurnsByCook, firstTurn);
  const exchangeTotal = [...exchangesByCook.values()].reduce((sum, count) => sum + count, 0);
  const botExchangeCount = [...exchangesByCook.entries()]
    .filter(([name]) => isBotName(name))
    .reduce((sum, [, count]) => sum + count, 0);

  return {
    rowCount: rows.length,
    firstTurn,
    lastTurn: rows.length > 0 ? numericTurn(rows[rows.length - 1]) : 0,
    actionCounts: Object.fromEntries(actionCounts),
    participantIngredients: Object.fromEntries(state.participantIngredient),
    prepareTiming,
    passTurnsByCook: objectFromMapOfArrays(passTurnsByCook),
    exchanges: {
      total: exchangeTotal,
      humanInitiated: exchangeTotal - botExchangeCount,
      botInitiated: botExchangeCount,
      byCook: Object.fromEntries(exchangesByCook)
    },
    nearCompletePasses,
    missingAbsentFromBasketCounts: Object.fromEntries(missingAbsentFromBasketCounts),
    botMissedOfferCandidates,
    limitation: "CSV exports completed transactions only; pending offer creation and ignored offer age are not present."
  };
}

export function formatTransactionAnalysis(analysis) {
  const lines = [];
  lines.push(`Rows: ${analysis.rowCount} turns ${analysis.firstTurn}-${analysis.lastTurn}`);
  lines.push("Actions:");
  for (const [action, count] of Object.entries(analysis.actionCounts)) {
    lines.push(`  ${action}: ${count}`);
  }
  lines.push("");
  lines.push(
    `Exchanges: ${analysis.exchanges.total} total, ${analysis.exchanges.humanInitiated} human-initiated, ${analysis.exchanges.botInitiated} bot-initiated`
  );
  lines.push("Prepare timing:");
  for (const [cook, turns] of Object.entries(analysis.prepareTiming.byCook)) {
    lines.push(`  ${cook}: ${turns.map((entry) => `${entry.turn} (+${entry.gap})`).join(", ")}`);
  }
  lines.push("");
  lines.push("Slow third dishes:");
  for (const entry of analysis.prepareTiming.slowThirdDishes) {
    lines.push(`  ${entry.cook}: turn ${entry.turn}, gap ${entry.gap}`);
  }
  lines.push("");
  lines.push("Missing ingredients absent from basket on near-complete passes:");
  for (const [ingredientId, count] of Object.entries(analysis.missingAbsentFromBasketCounts)) {
    lines.push(`  ${ingredientId}: ${count}`);
  }
  lines.push("");
  lines.push("Bot direct-offer candidates:");
  for (const candidate of analysis.botMissedOfferCandidates) {
    lines.push(
      `  turn ${candidate.turn} ${candidate.cook}: missing ${candidate.missingAbsentFromBasket.join(", ")}; targets ${candidate.directOfferCandidates.map((offer) => `${offer.ingredientId}->${offer.owner}`).join(", ")}`
    );
  }
  lines.push("");
  lines.push(`Limitation: ${analysis.limitation}`);
  return lines.join("\n");
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (inQuotes && char === "\"" && next === "\"") {
      field += "\"";
      index += 1;
      continue;
    }
    if (char === "\"") {
      inQuotes = !inQuotes;
      continue;
    }
    if (!inQuotes && char === ",") {
      row.push(field);
      field = "";
      continue;
    }
    if (!inQuotes && (char === "\n" || char === "\r")) {
      if (char === "\r" && next === "\n") {
        index += 1;
      }
      row.push(field);
      if (row.some((value) => value !== "")) {
        rows.push(row);
      }
      row = [];
      field = "";
      continue;
    }
    field += char;
  }
  if (field !== "" || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  if (rows.length === 0) {
    return [];
  }
  const header = rows[0];
  return rows.slice(1).map((values) => Object.fromEntries(header.map((key, index) => [key, values[index] ?? ""])));
}

function ingredientNameMap(catalog) {
  const result = new Map();
  for (const ingredient of catalog.ingredients ?? []) {
    result.set(normalizeLabel(ingredient.id), ingredient.id);
    result.set(normalizeLabel(ingredient.name), ingredient.id);
  }
  return result;
}

function recipesByOwnerIngredient(catalog) {
  const result = new Map();
  for (const recipe of catalog.recipes ?? []) {
    if (recipe.playerCount !== 8) {
      continue;
    }
    const entries = result.get(recipe.ownerIngredientId) ?? [];
    entries.push(recipe);
    entries.sort((left, right) => SLOT_ORDER.indexOf(left.slot) - SLOT_ORDER.indexOf(right.slot));
    result.set(recipe.ownerIngredientId, entries);
  }
  return result;
}

function prepareTimingSummary(prepareTurnsByCook, firstTurn) {
  const byCook = {};
  const slowThirdDishes = [];
  for (const [cook, turns] of prepareTurnsByCook.entries()) {
    let previousTurn = firstTurn;
    byCook[cook] = turns.map((entry) => {
      const gap = entry.turn - previousTurn;
      previousTurn = entry.turn;
      return { ...entry, gap };
    });
    if (byCook[cook][2]) {
      slowThirdDishes.push({ cook, ...byCook[cook][2] });
    }
  }
  slowThirdDishes.sort((left, right) => right.turn - left.turn || right.gap - left.gap || left.cook.localeCompare(right.cook));
  return { byCook, slowThirdDishes };
}

function nearCompletePassSummary(state, recipesByOwner, cook) {
  const ownerIngredientId = state.participantIngredient.get(cook);
  const recipeIndex = state.prepareCount.get(cook) ?? 0;
  const recipe = recipesByOwner.get(ownerIngredientId)?.[recipeIndex];
  if (!recipe) {
    return undefined;
  }
  const progress = state.recipeProgress.get(cook) ?? new Map();
  const hand = state.hand.get(cook) ?? new Map();
  const missingAfterHand = [];
  for (const requirement of recipe.requirements ?? []) {
    const redeemed = progress.get(requirement.ingredientId) ?? 0;
    const held = hand.get(requirement.ingredientId) ?? 0;
    const missing = requirement.requiredQty - redeemed - held;
    for (let count = 0; count < missing; count += 1) {
      missingAfterHand.push(requirement.ingredientId);
    }
  }
  if (missingAfterHand.length === 0 || missingAfterHand.length > 2) {
    return undefined;
  }
  const missingAbsentFromBasket = [...new Set(missingAfterHand.filter((ingredientId) => (state.platter.get(ingredientId) ?? 0) <= 0))].sort();
  const directOfferCandidates = missingAbsentFromBasket
    .map((ingredientId) => {
      const owner = participantForIngredient(state, ingredientId);
      return owner && (state.hand.get(owner)?.get(ingredientId) ?? 0) > 0 ? { ingredientId, owner } : undefined;
    })
    .filter(Boolean);
  return {
    recipeId: recipe.recipeId,
    recipeName: recipe.dishName,
    missingAfterHand,
    missingAbsentFromBasket,
    directOfferCandidates
  };
}

function participantForIngredient(state, ingredientId) {
  for (const [participant, ownedIngredientId] of state.participantIngredient.entries()) {
    if (ownedIngredientId === ingredientId) {
      return participant;
    }
  }
  return "";
}

function ensureParticipant(state, participant, ingredientId, vouchersPerIngredient) {
  if (!state.hand.has(participant)) {
    state.hand.set(participant, new Map());
  }
  if (!state.participantIngredient.has(participant)) {
    state.participantIngredient.set(participant, ingredientId);
    addNestedCount(state.hand, participant, ingredientId, vouchersPerIngredient);
  }
}

function moveIngredient(state, from, to, ingredientId, quantity) {
  decrementHolding(from === "platter" ? state.platter : state.hand, from, ingredientId, quantity);
  if (to === "platter") {
    state.platter.set(ingredientId, (state.platter.get(ingredientId) ?? 0) + quantity);
  } else {
    addNestedCount(state.hand, to, ingredientId, quantity);
  }
}

function decrementHolding(container, holder, ingredientId, quantity) {
  if (container instanceof Map && holder !== "platter") {
    const held = container.get(holder) ?? new Map();
    held.set(ingredientId, Math.max(0, (held.get(ingredientId) ?? 0) - quantity));
    container.set(holder, held);
    return;
  }
  container.set(ingredientId, Math.max(0, (container.get(ingredientId) ?? 0) - quantity));
}

function addNestedCount(container, holder, ingredientId, quantity) {
  const held = container.get(holder) ?? new Map();
  held.set(ingredientId, (held.get(ingredientId) ?? 0) + quantity);
  container.set(holder, held);
}

function addCount(container, key, quantity = 1) {
  container.set(key, (container.get(key) ?? 0) + quantity);
}

function ensureList(container, key) {
  const list = container.get(key) ?? [];
  container.set(key, list);
  return list;
}

function objectFromMapOfArrays(map) {
  return Object.fromEntries([...map.entries()].map(([key, value]) => [key, [...value]]));
}

function ingredientIdsForItems(value, ingredientNames) {
  return splitItemList(value).map((item) => ingredientIdForLabel(item, ingredientNames)).filter(Boolean);
}

function ingredientIdForLabel(value, ingredientNames) {
  return ingredientNames.get(normalizeLabel(value)) ?? "";
}

function splitItemList(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item !== "" && normalizeLabel(item) !== "none" && normalizeLabel(item) !== "turn");
}

function normalizeLabel(value) {
  return String(value ?? "").trim().toLowerCase();
}

function numericTurn(row) {
  return Number(row.Turn ?? 0);
}

function isBotName(name) {
  return /_b(?:$|_)/i.test(name);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const csvPath = process.argv[2];
  if (!csvPath) {
    console.error("Usage: node scripts/analyze-transactions.mjs <transactions.csv> [recipe_catalog.json]");
    process.exit(1);
  }
  const catalogPath = process.argv[3] ?? DEFAULT_CATALOG_PATH;
  const analysis = analyzeTransactionCsv(readFileSync(resolve(csvPath), "utf8"), readFileSync(resolve(catalogPath), "utf8"));
  console.log(formatTransactionAnalysis(analysis));
}
