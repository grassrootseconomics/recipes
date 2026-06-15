import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import { decideBotIntent, runBots } from "../src/bots.js";
import { DISH_PARTS_PER_DISH, INGREDIENTS, REAL_UNITS_PER_INGREDIENT, VOUCHERS_PER_INGREDIENT } from "../src/constants.js";
import {
  activeParticipants,
  applyIntent,
  GameError,
  handVoucherIds,
  inventoryDishPartIds,
  invariantVoucherCounts,
  platterAccountForParticipant,
  platterDishPartIds,
  platterVoucherIds,
  vouchersForIngredientOwner
} from "../src/game.js";
import { ConnectionHub } from "../src/hub.js";
import {
  catalogRecipeForIngredients,
  COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT,
  generateRecipeCatalog,
  ingredientsForPlayerCount,
  maxIngredientDemandForPlayerCount,
  MAX_TEMPLATE_INGREDIENTS,
  MIN_TEMPLATE_INGREDIENTS,
  RECIPE_DISTINCT_COUNTS,
  RECIPE_REQUIRED_ITEMS,
  RECIPE_SLOTS,
  RECIPE_VARIANT_COUNT
} from "../src/recipeCatalog.js";
import { buildSnapshot } from "../src/snapshots.js";
import { TableStore } from "../src/store.js";
import type { BotType, Participant, Table, Voucher } from "../src/types.js";

interface Harness {
  store: TableStore;
  table: Table;
  hostToken: string;
}

function makeHarness(activeCount: number, seed = "test-seed"): Harness {
  const store = new TableStore();
  const created = store.createTable("Host", seed);
  for (let index = 2; index <= activeCount; index += 1) {
    store.joinTable(created.table.code, `Player ${index}`);
  }
  return { store, table: created.table, hostToken: created.seatToken };
}

function startTable(activeCount: number, seed = "start-seed"): Harness {
  const harness = makeHarness(activeCount, seed);
  harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
  return harness;
}

function startAndDeposit(activeCount: number, seed = "deposit-seed"): Harness {
  const harness = startTable(activeCount, seed);
  for (const participant of activeParticipants(harness.table)) {
    const voucherId = handVoucherIds(harness.table, participant.id)[0] as string;
    applyIntent(harness.table, participant.id, { type: "deposit", voucherId });
  }
  expect(harness.table.phase).toBe("playing");
  return harness;
}

function addBots(table: Table, hostId: string, botTypes: BotType[]): Participant[] {
  const bots: Participant[] = [];
  for (const botType of botTypes) {
    applyIntent(table, hostId, { type: "add_bot", name: botType, botType });
    bots.push(table.participants[table.participantOrder.at(-1) as string]);
  }
  return bots;
}

function firstOtherActive(table: Table, participantId: string): Participant {
  const participant = activeParticipants(table).find((candidate) => candidate.id !== participantId);
  if (!participant) {
    throw new Error("Missing other participant");
  }
  return participant;
}

function moveVoucherToHand(table: Table, participantId: string, ingredientId: string): Voucher {
  const voucher = Object.values(table.vouchers).find(
    (candidate) => candidate.ingredientId === ingredientId && candidate.location.participantId !== participantId
  );
  if (!voucher) {
    throw new Error(`Missing voucher for ingredient ${ingredientId}`);
  }
  voucher.location = { type: "hand", participantId };
  return voucher;
}

function completeRecipeBySetup(table: Table, participantId: string): void {
  const recipe = table.recipes[participantId];
  if (!recipe) {
    throw new Error("Missing recipe");
  }
  for (const requirement of recipe.requirements) {
    requirement.placedVoucherIds = [];
    requirement.redeemedQty = requirement.requiredQty;
  }
}

function validQuantityShape(quantities: number[]): boolean {
  const sorted = [...quantities].sort((left, right) => right - left);
  return (
    sorted.join(",") === "2,2,2" ||
    sorted.join(",") === "2,2,1,1" ||
    sorted.join(",") === "1,1,1,1,1,1"
  );
}

function recipeRequirementSignature(recipe: { requirements: Array<{ ingredientId: string; requiredQty: number }> }): string {
  return recipe.requirements
    .map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    .sort()
    .join("|");
}

describe("catalog and startup", () => {
  it("defines 20 unique ingredient sets", () => {
    expect(INGREDIENTS).toHaveLength(20);
    expect(new Set(INGREDIENTS.map((ingredient) => ingredient.id)).size).toBe(20);
  });

  it("creates 7 fixed vouchers per active ingredient owner", () => {
    const { table } = startTable(7);
    for (const participant of activeParticipants(table)) {
      expect(vouchersForIngredientOwner(table, participant.id)).toHaveLength(VOUCHERS_PER_INGREDIENT);
      expect(participant.realIngredientStock).toBe(REAL_UNITS_PER_INGREDIENT);
    }
  });

  it("blocks start below 7 active participants", () => {
    const { store, table, hostToken } = makeHarness(6);
    expect(() => store.handleIntent(table.code, hostToken, { type: "start" }, false)).toThrow(GameError);
  });

  it("allows start from 7 to 20 active participants", () => {
    for (let activeCount = 7; activeCount <= 20; activeCount += 1) {
      const { table } = startTable(activeCount, `allowed-${activeCount}`);
      expect(table.phase).toBe("deposit");
      expect(activeParticipants(table)).toHaveLength(activeCount);
    }
  });

  it("makes running joins witnesses", () => {
    const { store, table } = startTable(7);
    const joined = store.joinTable(table.code, "Late");
    expect(joined.participant.role).toBe("witness");
  });

  it("lets the host toggle active/witness roles before start", () => {
    const { store, table, hostToken } = makeHarness(7);
    const hostId = table.hostParticipantId;
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: hostId, role: "witness" }, false);
    expect(table.participants[hostId].role).toBe("witness");
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: hostId, role: "active" }, false);
    expect(table.participants[hostId].role).toBe("active");
  });

  it("generates default participant names and bot names", () => {
    const store = new TableStore();
    const created = store.createTable("", "names");
    const joined = store.joinTable(created.table.code, "");
    store.handleIntent(created.table.code, created.seatToken, { type: "add_bot", name: "Mixed Bot", botType: "mixed" }, false);
    store.handleIntent(created.table.code, created.seatToken, { type: "add_bot", name: "Pool Bot", botType: "pool_only" }, false);
    store.handleIntent(created.table.code, created.seatToken, { type: "add_bot", name: "Barter Bot", botType: "barter_only" }, false);
    const bots = Object.values(created.table.participants).filter((participant) => participant.kind === "bot");

    expect(created.participant.name).toBe("Amina");
    expect(joined.participant.name).toBe("Ben");
    expect(bots.map((bot) => bot.name)).toEqual(["Clara_mix_bot", "Diego_pool_bot", "Esme_barter_bot"]);
  });

  it("starts a host plus bots through the store without repeat bot deposits", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "bot-start");
    for (let index = 0; index < 6; index += 1) {
      store.handleIntent(created.table.code, created.seatToken, { type: "add_bot", name: "Mixed Bot", botType: "mixed" });
    }

    const snapshot = store.handleIntent(created.table.code, created.seatToken, { type: "start" });
    const active = activeParticipants(created.table);
    const bots = active.filter((participant) => participant.kind === "bot");

    expect(created.table.phase).toBe("deposit");
    expect(active).toHaveLength(7);
    expect(bots.every((participant) => participant.depositedInitial)).toBe(true);
    expect(created.table.participants[created.table.hostParticipantId].depositedInitial).toBe(false);
    expect(snapshot.phase).toBe("deposit");
    expect(snapshot.ownHand).toHaveLength(VOUCHERS_PER_INGREDIENT);
    expect(snapshot.ownRecipe).toBeDefined();
  });

  it("continues bot turns into useful self-redemption after the host deposits", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "bot-start-self-redeem");
    for (let index = 0; index < 6; index += 1) {
      store.handleIntent(created.table.code, created.seatToken, { type: "add_bot", name: "Mixed Bot", botType: "mixed" });
    }
    store.handleIntent(created.table.code, created.seatToken, { type: "start" });
    const bot = activeParticipants(created.table).find((participant) => participant.kind === "bot") as Participant;
    const ownRequirement = created.table.recipes[bot.id]?.requirements.find(
      (requirement) => requirement.ingredientId === bot.ingredientId
    );
    expect(ownRequirement).toBeDefined();

    store.handleIntent(created.table.code, created.seatToken, {
      type: "deposit",
      voucherId: handVoucherIds(created.table, created.participant.id)[0] as string
    });

    expect(created.table.phase).toBe("playing");
    expect(ownRequirement?.redeemedQty).toBe(ownRequirement?.requiredQty);
    expect(ownRequirement?.placedVoucherIds).toHaveLength(0);
  });

  it("exposes lobby timer changes in filtered snapshots", () => {
    const { store, table, hostToken } = makeHarness(7, "timer-snapshot");

    const setSnapshot = store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 180 }, false);
    expect(setSnapshot.timer).toMatchObject({ seconds: 180 });

    const clearedSnapshot = store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: null }, false);
    expect(clearedSnapshot.timer).toBeUndefined();
  });

  it("lets the host set the dish goal from 1 to 4 before start", () => {
    const { store, table, hostToken } = makeHarness(7, "dish-goal");
    const snapshot = store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 2 }, false);

    expect(table.targetDishCount).toBe(2);
    expect(snapshot.targetDishCount).toBe(2);
    expect(() => store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 5 }, false)).toThrow(GameError);
    expect(table.targetDishCount).toBe(2);
  });

  it("lets the host set starting stock before start", () => {
    const { store, table, hostToken } = makeHarness(7, "stock-setting");
    const requiredStock = maxIngredientDemandForPlayerCount(7, table.targetDishCount);
    const snapshot = store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock }, false);

    expect(table.stockPerIngredient).toBe(requiredStock);
    expect(snapshot.stockPerIngredient).toBe(requiredStock);

    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(table)) {
      expect(participant.realIngredientStock).toBe(requiredStock);
    }
  });

  it("blocks start when configured stock is below catalog demand for the chosen goal", () => {
    const { store, table, hostToken } = makeHarness(7, "stock-too-low");
    const requiredStock = maxIngredientDemandForPlayerCount(7, table.targetDishCount);

    store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock - 1 }, false);

    expect(() => store.handleIntent(table.code, hostToken, { type: "start" }, false)).toThrow(GameError);
    expect(table.phase).toBe("lobby");
  });

  it("does not mutate the table or turn on invalid intents", () => {
    const { store, table, hostToken } = makeHarness(6);
    const before = structuredClone(table);

    expect(() => store.handleIntent(table.code, hostToken, { type: "start" }, false)).toThrow(GameError);

    expect(table).toEqual(before);
  });

  it("restores partial mutations when validation fails mid-action", () => {
    const { store, table, hostToken } = makeHarness(20);
    const extra = store.joinTable(table.code, "Extra");
    const extraId = extra.participant.id;
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: extraId, role: "witness" }, false);
    const before = structuredClone(table);

    expect(() => store.handleIntent(table.code, hostToken, { type: "set_role", participantId: extraId, role: "active" }, false)).toThrow(GameError);

    expect(table).toEqual(before);
  });
});

describe("recipe catalog generator", () => {
  it("defines one committed random ingredient set per supported player count", () => {
    const knownIngredientIds = new Set(INGREDIENTS.map((ingredient) => ingredient.id));

    for (let playerCount = 7; playerCount <= 20; playerCount += 1) {
      const committedIds = COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT[playerCount];
      const ingredients = ingredientsForPlayerCount(playerCount);

      expect(committedIds).toHaveLength(playerCount);
      expect(new Set(committedIds).size).toBe(playerCount);
      expect(committedIds.every((ingredientId) => knownIngredientIds.has(ingredientId))).toBe(true);
      expect(ingredients.map((ingredient) => ingredient.id)).toEqual(committedIds);
    }
  });

  it("generates four named recipes per ingredient for every 7-20 player configuration", () => {
    const catalog = generateRecipeCatalog();

    expect(catalog.configurations).toHaveLength(14);
    expect(catalog.dishTemplates).toHaveLength(INGREDIENTS.length * RECIPE_VARIANT_COUNT);

    const dishNames = catalog.dishTemplates.map((dish) => dish.dishName);
    expect(new Set(dishNames).size).toBe(dishNames.length);
    expect(
      catalog.dishTemplates.every(
        (dish) =>
          dish.realIngredientIds.length >= MIN_TEMPLATE_INGREDIENTS &&
          dish.realIngredientIds.length <= MAX_TEMPLATE_INGREDIENTS &&
          dish.partUnitSingular.length > 0 &&
          dish.partUnitPlural.length > 0
      )
    ).toBe(true);

    const chanaTemplates = catalog.dishTemplates.filter((dish) => dish.dishName === "Chana Masala");
    expect(chanaTemplates).toHaveLength(1);
    expect(chanaTemplates[0]?.realIngredientIds).toEqual([
      "chickpeas",
      "tomato",
      "onion",
      "garlic",
      "ginger",
      "pepper"
    ]);

    expect(catalog.recipes).toHaveLength(
      catalog.configurations.reduce((sum, configuration) => sum + configuration.playerCount * RECIPE_VARIANT_COUNT, 0)
    );

    for (const configuration of catalog.configurations) {
      const activeIngredientIds = new Set(configuration.ingredients.map((ingredient) => ingredient.id));
      const recipes = catalog.recipes.filter((recipe) => recipe.configurationId === configuration.configurationId);
      const recipeNames = recipes.map((recipe) => recipe.dishName);
      const recipeRequirementSignatures = recipes.map(recipeRequirementSignature);
      const demandByIngredient = new Map(configuration.ingredients.map((ingredient) => [ingredient.id, 0]));

      expect(recipes).toHaveLength(configuration.playerCount * RECIPE_VARIANT_COUNT);
      expect(new Set(recipeNames).size).toBe(recipeNames.length);
      expect(new Set(recipeRequirementSignatures).size).toBe(recipeRequirementSignatures.length);
      expect(configuration.requiredItemsPerRecipe).toBe(RECIPE_REQUIRED_ITEMS);
      expect(configuration.minDistinctIngredients).toBe(RECIPE_DISTINCT_COUNTS[0]);
      expect(configuration.maxDistinctIngredients).toBe(RECIPE_DISTINCT_COUNTS[RECIPE_DISTINCT_COUNTS.length - 1]);

      for (const ingredient of configuration.ingredients) {
        const ownerRecipes = recipes.filter((recipe) => recipe.ownerIngredientId === ingredient.id);
        expect(ownerRecipes.map((recipe) => recipe.slot).sort()).toEqual([...RECIPE_SLOTS].sort());
      }

      for (const recipe of recipes) {
        const template = catalog.dishTemplates.find((candidate) => candidate.templateId === recipe.templateId);
        if (!template) {
          throw new Error(`Missing template ${recipe.templateId}`);
        }
        const requirementIngredientIds = recipe.requirements.map((requirement) => requirement.ingredientId);
        const templateIngredientSet = new Set(template.realIngredientIds);
        const generatedFromExactTemplate =
          requirementIngredientIds.length === template.realIngredientIds.length &&
          requirementIngredientIds.every((ingredientId) => templateIngredientSet.has(ingredientId));

        expect(recipe.dishName.length).toBeGreaterThan(0);
        expect(recipe.partUnitSingular.length).toBeGreaterThan(0);
        expect(recipe.partUnitPlural.length).toBeGreaterThan(0);
        expect(recipe.realIngredientIds).toContain(recipe.ownerIngredientId);
        expect(recipe.matchedRealIngredientIds.length).toBeGreaterThan(0);
        expect(recipe.realIngredientIds).toEqual(requirementIngredientIds);
        if (!generatedFromExactTemplate) {
          expect(recipe.dishName).not.toBe(template.dishName);
        }
        expect(recipe.totalRequiredQty).toBe(RECIPE_REQUIRED_ITEMS);
        expect(RECIPE_DISTINCT_COUNTS.some((distinctCount) => distinctCount === recipe.distinctIngredientCount)).toBe(true);
        expect(validQuantityShape(recipe.requirements.map((requirement) => requirement.requiredQty))).toBe(true);
        expect(recipe.requirements.some((requirement) => requirement.ingredientId === recipe.ownerIngredientId)).toBe(true);
        expect(recipe.requirements.every((requirement) => activeIngredientIds.has(requirement.ingredientId))).toBe(true);
        expect(recipe.requirements.every((requirement) => requirement.requiredQty >= 1 && requirement.requiredQty <= 2)).toBe(true);
        for (const requirement of recipe.requirements) {
          demandByIngredient.set(requirement.ingredientId, (demandByIngredient.get(requirement.ingredientId) ?? 0) + requirement.requiredQty);
        }
      }

      for (const demand of demandByIngredient.values()) {
        expect(demand).toBeLessThanOrEqual(REAL_UNITS_PER_INGREDIENT);
      }
    }
  });

  it("uses real recipe ingredients before fallback ingredients", () => {
    const chanaIngredients = ["chickpeas", "tomato", "onion", "garlic", "ginger", "pepper", "salt"].map(
      (ingredientId) => INGREDIENTS.find((ingredient) => ingredient.id === ingredientId) as (typeof INGREDIENTS)[number]
    );
    const recipe = catalogRecipeForIngredients(chanaIngredients, "chickpeas", "initial", "chana_real_ingredients");

    expect(recipe.dishName).toBe("Chana Masala");
    expect(recipe.fallbackIngredientIds).toEqual([]);
    expect(recipe.requirements.map((requirement) => requirement.ingredientId)).toEqual([
      "chickpeas",
      "tomato",
      "onion",
      "garlic",
      "ginger",
      "pepper"
    ]);
  });

  it("uses the committed player-count ingredient set for runtime tables and catalog lookup rows", () => {
    const activeIngredientsForPlayerCount = ingredientsForPlayerCount(7);
    const { table } = startTable(7, "runtime-committed-set");
    const runtimeIngredientIds = activeParticipants(table).map((participant) => participant.ingredientId);

    expect(runtimeIngredientIds).toEqual(activeIngredientsForPlayerCount.map((ingredient) => ingredient.id));

    const participant = activeParticipants(table)[0] as Participant;
    const catalogRecipe = catalogRecipeForIngredients(
      activeIngredientsForPlayerCount,
      participant.ingredientId as string,
      "initial",
      "players_7"
    );
    expect(table.recipes[participant.id].requirements.map((requirement) => requirement.ingredientId)).toEqual(
      catalogRecipe.requirements.map((requirement) => requirement.ingredientId)
    );
  });

  it("does not reuse a named dish template when generated requirements omit template ingredients", () => {
    const catalog = generateRecipeCatalog();
    const sevenPlayerRice = catalog.recipes.find(
      (recipe) => recipe.playerCount === 7 && recipe.ownerIngredientId === "rice" && recipe.slot === "initial"
    );
    const twelvePlayerRice = catalog.recipes.find(
      (recipe) => recipe.playerCount === 12 && recipe.ownerIngredientId === "rice" && recipe.slot === "initial"
    );

    if (!sevenPlayerRice || !twelvePlayerRice) {
      throw new Error("Missing rice recipes.");
    }

    expect(sevenPlayerRice.templateId).toBe("rice_initial");
    expect(sevenPlayerRice.dishName).not.toBe("Jollof Rice");
    expect(sevenPlayerRice.realIngredientIds).toEqual(
      sevenPlayerRice.requirements.map((requirement) => requirement.ingredientId)
    );

    expect(twelvePlayerRice.dishName).toBe("Jollof Rice");
    expect(twelvePlayerRice.realIngredientIds).toEqual(["rice", "tomato", "onion", "garlic", "pepper", "ginger"]);
    expect(twelvePlayerRice.requirements.every((requirement) => requirement.requiredQty === 1)).toBe(true);
  });
});

describe("recipes and voucher lifecycle", () => {
  it("creates six-card recipes with valid quantity shapes and own ingredient", () => {
    for (let activeCount = 7; activeCount <= 20; activeCount += 1) {
      const { table } = startTable(activeCount, `recipe-total-${activeCount}`);
      const active = activeParticipants(table);
      const activeIngredientIds = new Set(active.map((participant) => participant.ingredientId));

      for (const participant of active) {
        const recipe = table.recipes[participant.id];
        const totalRequiredQty = recipe.requirements.reduce((sum, requirement) => sum + requirement.requiredQty, 0);

        expect(totalRequiredQty).toBe(RECIPE_REQUIRED_ITEMS);
        expect(RECIPE_DISTINCT_COUNTS.some((distinctCount) => distinctCount === recipe.requirements.length)).toBe(true);
        expect(validQuantityShape(recipe.requirements.map((requirement) => requirement.requiredQty))).toBe(true);
        expect(recipe.requirements.some((requirement) => requirement.ingredientId === participant.ingredientId)).toBe(true);
        expect(recipe.requirements.every((requirement) => activeIngredientIds.has(requirement.ingredientId))).toBe(true);
      }
    }
  });

  it("supports requirement quantities greater than one", () => {
    const { table } = startTable(7);
    const quantities = Object.values(table.recipes).flatMap((recipe) => recipe.requirements.map((requirement) => requirement.requiredQty));
    expect(quantities.some((quantity) => quantity > 1)).toBe(true);
  });

  it("uses generated catalog dish names in running tables", () => {
    const { table } = startTable(7, "runtime-catalog");
    const catalogDishNames = new Set(generateRecipeCatalog().recipes.map((recipe) => recipe.dishName));

    for (const recipe of Object.values(table.recipes)) {
      expect(catalogDishNames.has(recipe.name)).toBe(true);
    }
  });

  it("only asks for ingredients owned by active table participants", () => {
    const { table } = startTable(12);
    const active = activeParticipants(table);

    for (const recipe of Object.values(table.recipes)) {
      for (const requirement of recipe.requirements) {
        const owner = active.find((participant) => participant.ingredientId === requirement.ingredientId);
        expect(owner).toBeDefined();
        expect(vouchersForIngredientOwner(table, owner?.id as string)).toHaveLength(VOUCHERS_PER_INGREDIENT);
      }
    }
  });

  it("includes catalog target metadata in filtered own recipe snapshots", () => {
    const { table } = startTable(7, "snapshot-recipe-metadata");
    const participant = activeParticipants(table)[0] as Participant;
    const snapshot = buildSnapshot(table, participant.id);
    const recipe = snapshot.ownRecipe;

    if (!recipe) {
      throw new Error("Missing own recipe.");
    }
    expect(recipe.templateId).toBeTruthy();
    expect(recipe.unitSingular.length).toBeGreaterThan(0);
    expect(recipe.unitPlural.length).toBeGreaterThan(0);
    expect(recipe.realIngredientIds).toContain(participant.ingredientId);
    expect(recipe.matchedRealIngredientIds.length).toBeGreaterThan(0);
    expect(
      recipe.fallbackIngredientIds.every((ingredientId) =>
        recipe.requirements.some((requirement) => requirement.ingredientId === ingredientId)
      )
    ).toBe(true);
  });

  it("assigns a new table-valid recipe after preparing a dish", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const previousRecipeId = table.recipes[participant.id].id;

    completeRecipeBySetup(table, participant.id);
    applyIntent(table, participant.id, { type: "prepare" });

    const nextRecipe = table.recipes[participant.id];
    const activeIngredientIds = new Set(activeParticipants(table).map((activeParticipant) => activeParticipant.ingredientId));
    const totalRequiredQty = nextRecipe.requirements.reduce((sum, requirement) => sum + requirement.requiredQty, 0);

    expect(nextRecipe.id).not.toBe(previousRecipeId);
    expect(totalRequiredQty).toBe(RECIPE_REQUIRED_ITEMS);
    expect(validQuantityShape(nextRecipe.requirements.map((requirement) => requirement.requiredQty))).toBe(true);
    expect(nextRecipe.requirements.every((requirement) => activeIngredientIds.has(requirement.ingredientId))).toBe(true);
  });

  it("preparing a dish creates 10 named food parts in the maker inventory", () => {
    const { table } = startAndDeposit(7, "dish-parts");
    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];

    completeRecipeBySetup(table, participant.id);
    applyIntent(table, participant.id, { type: "prepare" });

    const dish = Object.values(table.dishes).find((candidate) => candidate.ownerParticipantId === participant.id);
    expect(dish).toMatchObject({
      name: recipe.name,
      unitSingular: recipe.unitSingular,
      unitPlural: recipe.unitPlural,
      totalParts: DISH_PARTS_PER_DISH,
      partsRemaining: DISH_PARTS_PER_DISH,
      partsEaten: 0
    });
    const parts = Object.values(table.dishParts).filter((part) => part.dishId === dish?.id);
    expect(parts).toHaveLength(DISH_PARTS_PER_DISH);
    expect(parts.every((part) => part.location.type === "inventory" && part.location.participantId === participant.id)).toBe(true);
    expect(table.transactionHistory.at(-1)).toMatchObject({ name: participant.name, action: "Prepare" });
  });

  it("requires all quantities to be redeemed before preparation", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, participant.id, requirement.ingredientId);

    applyIntent(table, participant.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    expect(() => applyIntent(table, participant.id, { type: "prepare" })).toThrow(GameError);

    const restoredRequirement = table.recipes[participant.id].requirements.find((candidate) => candidate.id === requirement.id);
    applyIntent(table, participant.id, { type: "redeem_voucher", voucherId: voucher.id });
    expect(restoredRequirement?.redeemedQty).toBe(1);
    if ((restoredRequirement?.requiredQty ?? 0) > 1) {
      expect(() => applyIntent(table, participant.id, { type: "prepare" })).toThrow(GameError);
    }
  });

  it("redeems a needed card directly from hand as one server-validated action", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, participant.id, requirement.ingredientId);
    const beforeRedeemed = requirement.redeemedQty;

    applyIntent(table, participant.id, { type: "redeem_from_hand", voucherId: voucher.id, requirementId: requirement.id });

    expect(requirement.redeemedQty).toBe(beforeRedeemed + 1);
    expect(requirement.placedVoucherIds).toHaveLength(0);
    expect(table.vouchers[voucher.id].location).toEqual({ type: "hand", participantId: voucher.ownerParticipantId });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: participant.name,
      action: "Redeem"
    });
  });

  it("keeps total vouchers per ingredient owner at 7", () => {
    const { table } = startAndDeposit(7);
    const before = invariantVoucherCounts(table);
    expect(Object.values(before)).toEqual(Array(7).fill(VOUCHERS_PER_INGREDIENT));

    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, participant.id, requirement.ingredientId);
    applyIntent(table, participant.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    applyIntent(table, participant.id, { type: "redeem_voucher", voucherId: voucher.id });

    expect(invariantVoucherCounts(table)).toEqual(before);
  });

  it("only creates vouchers for active physical ingredient owners", () => {
    const { table } = startTable(11);
    const activeOwnerIds = new Set(activeParticipants(table).map((participant) => participant.id));
    for (const voucher of Object.values(table.vouchers)) {
      expect(activeOwnerIds.has(voucher.ownerParticipantId)).toBe(true);
    }
  });

  it("decrements issuer stock and returns redeemed vouchers to the issuer hand", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];
    const requirement = recipe.requirements.find((candidate) => candidate.ingredientId !== participant.ingredientId) ?? recipe.requirements[0];
    const voucher = moveVoucherToHand(table, participant.id, requirement.ingredientId);
    const owner = table.participants[voucher.ownerParticipantId];
    const beforeStock = owner.realIngredientStock;

    applyIntent(table, participant.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    applyIntent(table, participant.id, { type: "redeem_voucher", voucherId: voucher.id });

    expect(owner.realIngredientStock).toBe((beforeStock ?? REAL_UNITS_PER_INGREDIENT) - 1);
    expect(table.vouchers[voucher.id].location).toEqual({ type: "hand", participantId: owner.id });
  });

  it("reconciles stock with redemption transactions, not deposits or swaps", () => {
    const { table } = startAndDeposit(7, "stock-reconciliation");
    const participant = activeParticipants(table)[0] as Participant;
    const beforeStock = participant.realIngredientStock;
    const giveVoucherId = handVoucherIds(table, participant.id)[0] as string;
    const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id) as string;

    applyIntent(table, participant.id, { type: "platter_swap", giveVoucherId, takeVoucherId });

    expect(participant.realIngredientStock).toBe(beforeStock);

    const recipe = table.recipes[participant.id];
    const ownRequirement = recipe.requirements.find((requirement) => requirement.ingredientId === participant.ingredientId);
    if (!ownRequirement) {
      throw new Error("Missing own ingredient requirement");
    }
    const ownVoucher = handVoucherIds(table, participant.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === participant.id
    ) as string;

    applyIntent(table, participant.id, { type: "redeem_from_hand", voucherId: ownVoucher, requirementId: ownRequirement.id });

    const redeemRowsForParticipant = table.transactionHistory.filter(
      (transaction) => transaction.action === "Redeem" && transaction.counterpartyParticipantId === participant.id
    );
    expect(participant.realIngredientStock).toBe((beforeStock ?? REAL_UNITS_PER_INGREDIENT) - redeemRowsForParticipant.length);
  });

  it("does not depend on owner preparation to make redeemed cards reusable", () => {
    const { table } = startAndDeposit(7);
    const redeemer = activeParticipants(table)[0] as Participant;
    const requirement = table.recipes[redeemer.id].requirements.find((candidate) => candidate.ingredientId !== redeemer.ingredientId);
    if (!requirement) {
      throw new Error("Missing non-own ingredient requirement");
    }
    const redeemedVoucher = moveVoucherToHand(table, redeemer.id, requirement.ingredientId);
    const owner = table.participants[redeemedVoucher.ownerParticipantId];

    applyIntent(table, redeemer.id, { type: "redeem_from_hand", voucherId: redeemedVoucher.id, requirementId: requirement.id });

    expect(table.vouchers[redeemedVoucher.id].location).toEqual({ type: "hand", participantId: owner.id });
    expect(buildSnapshot(table, redeemer.id).participants.find((participant) => participant.id === owner.id)?.offerableOwnIngredientQty).toBeGreaterThan(
      0
    );
  });

  it("keeps redeemed cards inactive only when issuer stock is exhausted", () => {
    const { table } = startAndDeposit(7);
    const redeemer = activeParticipants(table)[0] as Participant;
    const redeemerRecipe = table.recipes[redeemer.id];
    const requirement = redeemerRecipe.requirements.find((candidate) => candidate.ingredientId !== redeemer.ingredientId);
    if (!requirement) {
      throw new Error("Missing non-own ingredient requirement");
    }
    const redeemedVoucher = moveVoucherToHand(table, redeemer.id, requirement.ingredientId);
    const owner = table.participants[redeemedVoucher.ownerParticipantId];
    owner.realIngredientStock = 1;

    applyIntent(table, redeemer.id, { type: "place_voucher", voucherId: redeemedVoucher.id, requirementId: requirement.id });
    applyIntent(table, redeemer.id, { type: "redeem_voucher", voucherId: redeemedVoucher.id });

    expect(owner.realIngredientStock).toBe(0);
    expect(table.vouchers[redeemedVoucher.id].location).toMatchObject({ type: "holding", participantId: owner.id });
    expect(buildSnapshot(table, redeemer.id).participants.find((participant) => participant.id === owner.id)?.offerableOwnIngredientQty).toBe(0);
    expect(invariantVoucherCounts(table)[owner.id]).toBe(VOUCHERS_PER_INGREDIENT);
  });
});

describe("platter, offers, and visibility", () => {
  it("deposits and swaps with the central platter atomically", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const platterBefore = platterVoucherIds(table);
    const giveVoucherId = handVoucherIds(table, participant.id)[0] as string;
    const takeVoucherId = platterBefore.find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id) as string;

    applyIntent(table, participant.id, { type: "platter_swap", giveVoucherId, takeVoucherId });

    expect(platterVoucherIds(table)).toHaveLength(platterBefore.length);
    expect(table.vouchers[giveVoucherId].location.type).toBe("platter");
    expect(table.vouchers[takeVoucherId].location).toEqual({ type: "hand", participantId: participant.id });
  });

  it("locks structured offer cards and resolves an accepted exchange", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;
    const requestedVoucherId = handVoucherIds(table, to.id).find(
      (voucherId) => table.vouchers[voucherId].ingredientId === to.ingredientId
    ) as string;

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: table.vouchers[requestedVoucherId].ingredientId, quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "offer_lock", offerId: offer.id });

    applyIntent(table, to.id, { type: "respond_offer", offerId: offer.id, response: "accept", voucherIds: [requestedVoucherId] });

    expect(offer.status).toBe("accepted");
    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: to.id });
    expect(table.vouchers[requestedVoucherId].location).toEqual({ type: "hand", participantId: from.id });
  });

  it("records successful deposit, swap, exchange, and redemption transactions", () => {
    const { table } = startTable(7, "transactions");
    const [first, second] = activeParticipants(table);
    const firstDepositId = handVoucherIds(table, first.id)[0] as string;

    applyIntent(table, first.id, { type: "deposit", voucherId: firstDepositId });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Deposit",
      counterparty: "Platter",
      itemOut: table.vouchers[firstDepositId].ingredientId[0].toUpperCase() + table.vouchers[firstDepositId].ingredientId.slice(1),
      itemBack: "None"
    });

    for (const participant of activeParticipants(table).filter((participant) => !participant.depositedInitial)) {
      applyIntent(table, participant.id, { type: "deposit", voucherId: handVoucherIds(table, participant.id)[0] as string });
    }

    const giveVoucherId = handVoucherIds(table, first.id)[0] as string;
    const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== first.id) as string;
    applyIntent(table, first.id, { type: "platter_swap", giveVoucherId, takeVoucherId });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Swap",
      counterparty: "Platter",
      itemOut: table.vouchers[giveVoucherId].ingredientId[0].toUpperCase() + table.vouchers[giveVoucherId].ingredientId.slice(1),
      itemBack: table.vouchers[takeVoucherId].ingredientId[0].toUpperCase() + table.vouchers[takeVoucherId].ingredientId.slice(1)
    });

    const offeredVoucherId = handVoucherIds(table, first.id)[0] as string;
    const requestedVoucherId = handVoucherIds(table, second.id).find(
      (voucherId) => table.vouchers[voucherId].ingredientId === second.ingredientId
    ) as string;
    applyIntent(table, first.id, {
      type: "create_offer",
      toParticipantId: second.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: table.vouchers[requestedVoucherId].ingredientId, quantity: 1 }
    });
    const offer = Object.values(table.offers).find((candidate) => candidate.status === "pending");
    applyIntent(table, second.id, { type: "respond_offer", offerId: offer?.id ?? "", response: "accept", voucherIds: [requestedVoucherId] });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Exchange",
      counterparty: second.name
    });

    const recipe = table.recipes[first.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, first.id, requirement.ingredientId);
    const owner = table.participants[voucher.ownerParticipantId];
    applyIntent(table, first.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    applyIntent(table, first.id, { type: "redeem_voucher", voucherId: voucher.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Redeem",
      counterparty: owner.name,
      itemBack: `Real ${voucher.ingredientId[0].toUpperCase()}${voucher.ingredientId.slice(1)}`
    });

    const snapshot = buildSnapshot(table, first.id);
    expect(snapshot.transactionHistory).toEqual(table.transactionHistory);
  });

  it("includes offered card details in filtered offer snapshots", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });

    const snapshot = buildSnapshot(table, to.id);
    expect(snapshot.offers).toHaveLength(1);
    expect(snapshot.offers[0].offeredVouchers).toEqual([expect.objectContaining({ id: offeredVoucherId })]);
    expect(snapshot.allHands).toBeUndefined();
  });

  it("unlocks offered cards when offers are refused or cancelled", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });
    const refusedOffer = Object.values(table.offers)[0];
    applyIntent(table, to.id, { type: "respond_offer", offerId: refusedOffer.id, response: "refuse" });
    expect(table.offers[refusedOffer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });
    const pendingOffers = Object.values(table.offers).filter((offer) => offer.status === "pending");
    expect(pendingOffers).toHaveLength(1);
    applyIntent(table, from.id, { type: "cancel_offer", offerId: pendingOffers[0].id });
    expect(table.offers[pendingOffers[0].id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });
  });

  it("removes refused offers from both participants' snapshots", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];
    expect(buildSnapshot(table, from.id).offers).toHaveLength(1);
    expect(buildSnapshot(table, to.id).offers).toHaveLength(1);

    applyIntent(table, to.id, { type: "respond_offer", offerId: offer.id, response: "refuse" });

    expect(buildSnapshot(table, from.id).offers).toHaveLength(0);
    expect(buildSnapshot(table, to.id).offers).toHaveLength(0);
  });

  it("publishes only own-ingredient offer availability, not hidden hands", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;

    const snapshot = buildSnapshot(table, participant.id);
    const publicParticipant = snapshot.participants.find((candidate) => candidate.id === participant.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(publicParticipant?.offerableOwnIngredientQty).toBe(6);
  });

  it("blocks offers when the recipient has no remaining real stock", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    to.realIngredientStock = 0;
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    expect(() =>
      applyIntent(table, from.id, {
        type: "create_offer",
        toParticipantId: to.id,
        offeredVoucherIds: [offeredVoucherId],
        requested: { ingredientId: to.ingredientId as string, quantity: 1 }
      })
    ).toThrow(GameError);
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });
    expect(buildSnapshot(table, from.id).participants.find((participant) => participant.id === to.id)?.offerableOwnIngredientQty).toBe(0);
  });

  it("automatically refuses pending offers when the recipient runs out of real stock", () => {
    const { table } = startAndDeposit(7);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];
    expect(offer).toBeDefined();
    expect(table.vouchers[offeredVoucherId].location.type).toBe("offer_lock");

    to.realIngredientStock = 0;
    applyIntent(table, table.hostParticipantId, { type: "set_pause", paused: true });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });
  });

  it("automatically cancels incoming offers when requested cards leave the recipient hand", () => {
    const { table } = startAndDeposit(7);
    const recipient = activeParticipants(table)[0] as Participant;
    const sender = firstOtherActive(table, recipient.id);
    const recipientOwnHand = handVoucherIds(table, recipient.id).filter(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === recipient.id
    );
    const lastAvailableVoucherId = recipientOwnHand[0] as string;
    for (const voucherId of recipientOwnHand.slice(1)) {
      table.vouchers[voucherId].location = { type: "hand", participantId: sender.id };
    }
    const offeredVoucherId = handVoucherIds(table, sender.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === sender.id
    ) as string;

    applyIntent(table, sender.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];
    expect(offer).toBeDefined();

    const takeVoucherId = platterVoucherIds(table).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId !== recipient.id
    ) as string;
    applyIntent(table, recipient.id, {
      type: "platter_swap",
      giveVoucherId: lastAvailableVoucherId,
      takeVoucherId
    });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: sender.id });
    expect(buildSnapshot(table, sender.id).offers).toHaveLength(0);
    expect(buildSnapshot(table, recipient.id).offers).toHaveLength(0);
  });

  it("reserves requested cards across pending incoming offers", () => {
    const { table } = startAndDeposit(7);
    const [recipient, senderOne, senderTwo] = activeParticipants(table) as [Participant, Participant, Participant];
    const recipientOwnHand = handVoucherIds(table, recipient.id).filter(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === recipient.id
    );
    for (const voucherId of recipientOwnHand.slice(1)) {
      table.vouchers[voucherId].location = { type: "hand", participantId: senderOne.id };
    }
    const firstOfferedVoucherId = handVoucherIds(table, senderOne.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === senderOne.id
    ) as string;
    const secondOfferedVoucherId = handVoucherIds(table, senderTwo.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === senderTwo.id
    ) as string;

    applyIntent(table, senderOne.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredVoucherIds: [firstOfferedVoucherId],
      requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
    });

    expect(buildSnapshot(table, senderTwo.id).participants.find((participant) => participant.id === recipient.id)?.offerableOwnIngredientQty).toBe(0);
    expect(() =>
      applyIntent(table, senderTwo.id, {
        type: "create_offer",
        toParticipantId: recipient.id,
        offeredVoucherIds: [secondOfferedVoucherId],
        requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
      })
    ).toThrow(GameError);
    expect(Object.values(table.offers)).toHaveLength(1);
    expect(table.vouchers[secondOfferedVoucherId].location).toEqual({ type: "hand", participantId: senderTwo.id });
  });

  it("keeps other active hands hidden from active players", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    const snapshot = buildSnapshot(table, participant.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(snapshot.ownHand.every((voucher) => voucher.location.participantId === participant.id)).toBe(true);
  });

  it("filters food-part inventories while allowing witness audits", () => {
    const { store, table } = startAndDeposit(7, "food-part-visibility");
    const [owner, other] = activeParticipants(table);

    completeRecipeBySetup(table, owner.id);
    applyIntent(table, owner.id, { type: "prepare" });
    const partId = inventoryDishPartIds(table, owner.id)[0] as string;

    const ownerSnapshot = buildSnapshot(table, owner.id);
    const otherSnapshot = buildSnapshot(table, other.id);
    const witness = store.joinTable(table.code, "Observer");
    const witnessSnapshot = buildSnapshot(table, witness.participant.id);

    expect(ownerSnapshot.ownFoodParts.map((part) => part.id)).toContain(partId);
    expect(ownerSnapshot.dishParts.map((part) => part.id)).toContain(partId);
    expect(otherSnapshot.ownFoodParts.map((part) => part.id)).not.toContain(partId);
    expect(otherSnapshot.dishParts.map((part) => part.id)).not.toContain(partId);
    expect(witnessSnapshot.allFoodParts).toBeUndefined();
    expect(witnessSnapshot.dishParts.map((part) => part.id)).toContain(partId);
  });

  it("defaults missing transaction history to an empty snapshot list", () => {
    const { table } = startAndDeposit(7);
    const participant = activeParticipants(table)[0] as Participant;
    delete (table as Partial<Table>).transactionHistory;

    const snapshot = buildSnapshot(table, participant.id);

    expect(snapshot.transactionHistory).toEqual([]);
  });

  it("keeps hidden hands out of bot snapshots and decisions", () => {
    const { table } = makeHarness(6);
    const hostId = table.hostParticipantId;
    const [bot] = addBots(table, hostId, ["mixed"]);
    applyIntent(table, hostId, { type: "start" });
    const snapshot = buildSnapshot(table, bot.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allVouchers).toBeUndefined();
    expect(() => decideBotIntent(table, bot.id)).not.toThrow();
  });

  it("lets witnesses see all hands", () => {
    const { store, table } = startAndDeposit(7);
    const witness = store.joinTable(table.code, "Observer");
    const snapshot = buildSnapshot(table, witness.participant.id);

    expect(witness.participant.role).toBe("witness");
    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(snapshot.allVouchers).toBeDefined();
    expect(snapshot.allRecipes).toBeDefined();
    expect(snapshot.allVouchers?.filter((voucher) => voucher.location.type === "hand")).not.toHaveLength(0);
  });

  it("keeps running-game witness snapshots compact enough for Godot websocket frames", () => {
    const { store, table } = startAndDeposit(7, "compact-witness");
    const participants = activeParticipants(table);

    for (let index = 0; index < 180; index += 1) {
      const participant = participants[index % participants.length];
      const giveVoucherId = handVoucherIds(table, participant.id)[0];
      const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id);
      if (giveVoucherId && takeVoucherId) {
        applyIntent(table, participant.id, { type: "platter_swap", giveVoucherId, takeVoucherId });
      }
    }

    const witness = store.joinTable(table.code, "Observer");
    const snapshot = buildSnapshot(table, witness.participant.id);
    const payloadBytes = Buffer.byteLength(JSON.stringify({ type: "snapshot", snapshot }), "utf8");

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(payloadBytes).toBeLessThan(64 * 1024);
  });

  it("enforces bot channel restrictions", () => {
    const { table } = makeHarness(5);
    const hostId = table.hostParticipantId;
    const [poolOnly, barterOnly] = addBots(table, hostId, ["pool_only", "barter_only"]);
    applyIntent(table, hostId, { type: "start" });
    for (const participant of activeParticipants(table)) {
      applyIntent(table, participant.id, { type: "deposit", voucherId: handVoucherIds(table, participant.id)[0] as string });
    }

    const target = firstOtherActive(table, poolOnly.id);
    expect(() =>
      applyIntent(table, poolOnly.id, {
        type: "create_offer",
        toParticipantId: target.id,
        offeredVoucherIds: [handVoucherIds(table, poolOnly.id)[0] as string],
        requested: { ingredientId: target.ingredientId as string, quantity: 1 }
      })
    ).toThrow(GameError);

    expect(() =>
      applyIntent(table, barterOnly.id, {
        type: "platter_swap",
        giveVoucherId: handVoucherIds(table, barterOnly.id)[0] as string,
        takeVoucherId: platterVoucherIds(table)[0] as string
      })
    ).toThrow(GameError);
  });

  it("has bots place and redeem useful cards from their own hand before trading", () => {
    const { table } = makeHarness(6, "bot-self-redeem");
    const [bot] = addBots(table, table.hostParticipantId, ["mixed"]);
    applyIntent(table, table.hostParticipantId, { type: "start" });
    for (const participant of activeParticipants(table)) {
      applyIntent(table, participant.id, { type: "deposit", voucherId: handVoucherIds(table, participant.id)[0] as string });
    }
    expect(table.phase).toBe("playing");

    const ownRequirement = table.recipes[bot.id]?.requirements.find(
      (requirement) => requirement.ingredientId === bot.ingredientId
    );
    expect(ownRequirement).toBeDefined();
    expect(ownRequirement?.redeemedQty).toBe(0);

    runBots(table);

    expect(ownRequirement?.redeemedQty).toBe(ownRequirement?.requiredQty);
    expect(ownRequirement?.placedVoucherIds).toHaveLength(0);
  });

  it("does not let bots act while the table is paused", () => {
    const { table } = makeHarness(6, "bot-paused");
    const [bot] = addBots(table, table.hostParticipantId, ["mixed"]);
    applyIntent(table, table.hostParticipantId, { type: "start" });
    table.paused = true;

    expect(decideBotIntent(table, bot.id)).toBeUndefined();
  });

  it("broadcasts per-viewer filtered snapshots through the connection hub", () => {
    const { table } = startAndDeposit(7);
    const [first, second] = activeParticipants(table);
    const hub = new ConnectionHub();
    const firstMessages: unknown[] = [];
    const secondMessages: unknown[] = [];
    hub.register({
      tableCode: table.code,
      participantId: first.id,
      send: (payload) => firstMessages.push(JSON.parse(payload))
    });
    hub.register({
      tableCode: table.code,
      participantId: second.id,
      send: (payload) => secondMessages.push(JSON.parse(payload))
    });

    hub.broadcastTable(table);

    const firstSnapshot = (firstMessages[0] as { snapshot: ReturnType<typeof buildSnapshot> }).snapshot;
    const secondSnapshot = (secondMessages[0] as { snapshot: ReturnType<typeof buildSnapshot> }).snapshot;
    expect(firstSnapshot.viewerParticipantId).toBe(first.id);
    expect(secondSnapshot.viewerParticipantId).toBe(second.id);
    expect(firstSnapshot.ownHand.map((voucher) => voucher.location.participantId).every((id) => id === first.id)).toBe(true);
    expect(secondSnapshot.ownHand.map((voucher) => voucher.location.participantId).every((id) => id === second.id)).toBe(true);
    expect(firstSnapshot.allHands).toBeUndefined();
    expect(secondSnapshot.allHands).toBeUndefined();
  });

  it("keeps a disconnected active human seat reclaimable until the host converts it", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "disconnect-active");
    const joined = store.joinTable(created.table.code, "Ravi");

    store.disconnectParticipantByToken(created.table.code, joined.seatToken);

    const participant = created.table.participants[joined.participant.id];
    expect(participant.kind).toBe("human");
    expect(participant.connected).toBe(false);
    expect(store.connectParticipantByToken(created.table.code, joined.seatToken).id).toBe(participant.id);
    expect(participant.connected).toBe(true);
  });

  it("lets the host manually convert a connected or disconnected active player to a mixed bot", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "manual-bot");
    const connected = store.joinTable(created.table.code, "Ravi");
    const disconnected = store.joinTable(created.table.code, "Lina");
    store.disconnectParticipantByToken(created.table.code, disconnected.seatToken);

    store.handleIntent(created.table.code, created.seatToken, {
      type: "convert_to_bot",
      participantId: connected.participant.id
    });
    store.handleIntent(created.table.code, created.seatToken, {
      type: "convert_to_bot",
      participantId: disconnected.participant.id
    });

    expect(created.table.participants[connected.participant.id]).toMatchObject({
      kind: "bot",
      botType: "mixed",
      connected: false,
      name: "Ravi_mix_bot"
    });
    expect(created.table.participants[disconnected.participant.id]).toMatchObject({
      kind: "bot",
      botType: "mixed",
      connected: false,
      name: "Lina_mix_bot"
    });
    expect(() => store.connectParticipantByToken(created.table.code, connected.seatToken)).toThrow(GameError);
    expect(() => store.connectParticipantByToken(created.table.code, disconnected.seatToken)).toThrow(GameError);
  });

  it("blocks non-host and host-seat bot conversion", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "manual-bot-blocked");
    const joined = store.joinTable(created.table.code, "Ravi");

    expect(() =>
      store.handleIntent(created.table.code, joined.seatToken, {
        type: "convert_to_bot",
        participantId: created.participant.id
      })
    ).toThrow(GameError);
    expect(() =>
      store.handleIntent(created.table.code, created.seatToken, {
        type: "convert_to_bot",
        participantId: created.participant.id
      })
    ).toThrow(GameError);
  });

  it("keeps disconnected witnesses as offline humans", () => {
    const { store, table } = startAndDeposit(7);
    const witness = store.joinTable(table.code, "Observer");
    expect(witness.participant.role).toBe("witness");

    store.disconnectParticipantByToken(table.code, witness.seatToken);

    expect(table.participants[witness.participant.id].kind).toBe("human");
    expect(table.participants[witness.participant.id].connected).toBe(false);
  });
});

describe("winning and eating", () => {
  it("keeps cooking after everyone has one dish when the dish goal is the default 4", () => {
    const { table } = startAndDeposit(7, "default-four-dishes");

    for (const participant of activeParticipants(table)) {
      completeRecipeBySetup(table, participant.id);
      applyIntent(table, participant.id, { type: "prepare" });
    }

    expect(table.targetDishCount).toBe(4);
    expect(table.phase).toBe("playing");
    expect(table.winnerParticipantIds).toHaveLength(0);
    for (const participant of activeParticipants(table)) {
      expect(participant.dishCount).toBe(1);
      expect(table.recipes[participant.id]).toBeDefined();
    }
  });

  it("enters eating after everyone reaches the configured dish goal when accounts are clear", () => {
    const harness = makeHarness(7, "one-dish-goal");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      applyIntent(harness.table, participant.id, { type: "deposit", voucherId: handVoucherIds(harness.table, participant.id)[0] as string });
    }

    const participants = activeParticipants(harness.table);
    for (const participant of participants.slice(0, -1)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyIntent(harness.table, participant.id, { type: "prepare" });
      expect(harness.table.phase).toBe("playing");
    }

    const finalParticipant = participants.at(-1) as Participant;
    completeRecipeBySetup(harness.table, finalParticipant.id);
    applyIntent(harness.table, finalParticipant.id, { type: "prepare" });

    expect(harness.table.phase).toBe("eating");
    expect(harness.table.winnerParticipantIds).toHaveLength(7);
    for (const participant of participants) {
      expect(harness.table.recipes[participant.id]).toBeUndefined();
      expect(platterAccountForParticipant(harness.table, participant.id).cleared).toBe(true);
    }
  });

  it("lets the host pause and resume while blocking gameplay actions", () => {
    const { store, table, hostToken } = startAndDeposit(7);
    const [host, other] = activeParticipants(table);

    const pausedSnapshot = store.handleIntent(table.code, hostToken, { type: "set_pause", paused: true }, false);

    expect(table.paused).toBe(true);
    expect(pausedSnapshot.paused).toBe(true);
    expect(() =>
      applyIntent(table, other.id, {
        type: "platter_swap",
        giveVoucherId: handVoucherIds(table, other.id)[0] as string,
        takeVoucherId: platterVoucherIds(table)[0] as string
      })
    ).toThrow(GameError);

    applyIntent(table, host.id, { type: "set_pause", paused: false });
    expect(table.paused).toBe(false);
  });

  it("pauses a running timer instead of expiring while paused", () => {
    const { store, table, hostToken } = makeHarness(7, "pause-timer");
    store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 60 }, false);
    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    const originalEndsAt = table.timer?.endsAtMs ?? Date.now();

    store.handleIntent(table.code, hostToken, { type: "set_pause", paused: true }, false);

    expect(table.paused).toBe(true);
    expect(table.timer?.endsAtMs).toBeUndefined();
    expect(table.timer?.pausedRemainingMs).toBeGreaterThan(0);
    expect(store.expireTimer(table.code, originalEndsAt + 1000)).toBe(false);

    store.handleIntent(table.code, hostToken, { type: "set_pause", paused: false }, false);
    expect(table.paused).toBe(false);
    expect(table.timer?.endsAtMs).toBeDefined();
    expect(table.timer?.pausedRemainingMs).toBeUndefined();
  });

  it("only lets the host end the game for everyone", () => {
    const { table } = startAndDeposit(7);
    const nonHost = activeParticipants(table).find((participant) => participant.id !== table.hostParticipantId) as Participant;

    expect(() => applyIntent(table, nonHost.id, { type: "stop" })).toThrow(GameError);
    expect(table.phase).toBe("playing");
  });

  it("settles platter debt and shortfall with 1:1 card and food-part swaps", () => {
    const harness = makeHarness(7, "settlement-swaps");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      applyIntent(harness.table, participant.id, { type: "deposit", voucherId: handVoucherIds(harness.table, participant.id)[0] as string });
    }

    const [debtor, shortfall] = activeParticipants(harness.table);
    const extraDebtorVoucher = handVoucherIds(harness.table, debtor.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === debtor.id
    ) as string;
    const shortfallVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === shortfall.id
    ) as string;
    harness.table.vouchers[extraDebtorVoucher].location = { type: "platter" };
    harness.table.vouchers[shortfallVoucher].location = { type: "hand", participantId: shortfall.id };

    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyIntent(harness.table, participant.id, { type: "prepare" });
    }

    expect(harness.table.phase).toBe("settlement");
    expect(platterAccountForParticipant(harness.table, debtor.id)).toMatchObject({ ownCardsInPlatter: 2, platterDebt: 1, cleared: false });
    expect(platterAccountForParticipant(harness.table, shortfall.id)).toMatchObject({
      ownCardsInPlatter: 0,
      platterShortfall: 1,
      cleared: false
    });

    const debtorPartId = inventoryDishPartIds(harness.table, debtor.id)[0] as string;
    const debtorOwnPlatterVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === debtor.id
    ) as string;
    applyIntent(harness.table, debtor.id, {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: debtorPartId },
      take: { kind: "voucher", id: debtorOwnPlatterVoucher }
    });

    expect(platterAccountForParticipant(harness.table, debtor.id).cleared).toBe(true);
    expect(platterDishPartIds(harness.table)).toEqual([debtorPartId]);
    expect(harness.table.transactionHistory.at(-1)).toMatchObject({ name: debtor.name, action: "Settlement Swap" });

    applyIntent(harness.table, shortfall.id, {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: shortfallVoucher },
      take: { kind: "dish_part", id: debtorPartId }
    });

    expect(platterAccountForParticipant(harness.table, shortfall.id).cleared).toBe(true);
    expect(platterDishPartIds(harness.table)).toHaveLength(0);
    expect(harness.table.phase).toBe("eating");
    expect(harness.table.dishParts[debtorPartId].location).toEqual({ type: "inventory", participantId: shortfall.id });
  });

  it("blocks invalid settlement swaps without mutation", () => {
    const { table } = startAndDeposit(7, "invalid-settlement");
    const [participant] = activeParticipants(table);
    completeRecipeBySetup(table, participant.id);
    applyIntent(table, participant.id, { type: "prepare" });
    table.phase = "settlement";
    const partId = inventoryDishPartIds(table, participant.id)[0] as string;
    const platterVoucherId = platterVoucherIds(table)[0] as string;
    const before = structuredClone(table);

    expect(() =>
      applyIntent(table, participant.id, {
        type: "platter_asset_swap",
        give: { kind: "dish_part", id: partId },
        take: { kind: "dish_part", id: partId }
      })
    ).toThrow(GameError);
    expect(table).toEqual(before);

    expect(() =>
      applyIntent(table, participant.id, {
        type: "platter_asset_swap",
        give: { kind: "voucher", id: platterVoucherId },
        take: { kind: "dish_part", id: partId }
      })
    ).toThrow(GameError);
  });

  it("allows any held voucher card to be swapped for a platter food part", () => {
    const { table } = startAndDeposit(7, "any-card-for-food-part");
    const [participant, other] = activeParticipants(table);
    completeRecipeBySetup(table, participant.id);
    applyIntent(table, participant.id, { type: "prepare" });
    table.phase = "settlement";
    const partId = inventoryDishPartIds(table, participant.id)[0] as string;
    table.dishParts[partId].location = { type: "platter" };
    const nonOwnVoucher = moveVoucherToHand(table, participant.id, other.ingredientId as string);

    applyIntent(table, participant.id, {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: nonOwnVoucher.id },
      take: { kind: "dish_part", id: partId }
    });

    expect(table.vouchers[nonOwnVoucher.id].location).toEqual({ type: "platter" });
    expect(table.dishParts[partId].location).toEqual({ type: "inventory", participantId: participant.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({ name: participant.name, action: "Settlement Swap" });
  });

  it("only lets cleared players eat food parts they hold", () => {
    const harness = makeHarness(7, "eat-owned-parts");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      applyIntent(harness.table, participant.id, { type: "deposit", voucherId: handVoucherIds(harness.table, participant.id)[0] as string });
    }
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyIntent(harness.table, participant.id, { type: "prepare" });
    }

    const [owner, other] = activeParticipants(harness.table);
    const ownerDish = Object.values(harness.table.dishes).find((dish) => dish.ownerParticipantId === owner.id);
    if (!ownerDish) {
      throw new Error("Missing owner dish");
    }
    expect(() => applyIntent(harness.table, other.id, { type: "bite", dishId: ownerDish.id })).toThrow(GameError);

    applyIntent(harness.table, owner.id, { type: "bite", dishId: ownerDish.id });

    const updatedDish = harness.table.dishes[ownerDish.id];
    expect(updatedDish.partsRemaining).toBe(DISH_PARTS_PER_DISH - 1);
    expect(updatedDish.bitesRemaining).toBe(DISH_PARTS_PER_DISH - 1);
    expect(updatedDish.biteCounts[owner.id]).toBe(1);
    expect(harness.table.transactionHistory.at(-1)).toMatchObject({ name: owner.name, action: "Eat" });
  });

  it("has bots settle accounts and eat held food parts deterministically", () => {
    const harness = makeHarness(1, "bot-settlement-eating");
    addBots(harness.table, harness.table.hostParticipantId, ["mixed", "mixed", "mixed", "mixed", "mixed", "mixed"]);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      applyIntent(harness.table, participant.id, { type: "deposit", voucherId: handVoucherIds(harness.table, participant.id)[0] as string });
    }
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyIntent(harness.table, participant.id, { type: "prepare" });
    }

    const decisions = runBots(harness.table, 40).filter((decision) => decision.intent.type === "bite");

    expect(harness.table.phase).toBe("eating");
    expect(decisions.length).toBeGreaterThan(0);
    expect(Object.values(harness.table.dishes).some((dish) => dish.partsRemaining < DISH_PARTS_PER_DISH)).toBe(true);
  });

  it("expires a configured timer into settlement instead of bypassing accountability", () => {
    const { store, table, hostToken } = makeHarness(7);
    store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 1 }, false);
    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    const winner = activeParticipants(table)[0] as Participant;
    for (const participant of activeParticipants(table)) {
      applyIntent(table, participant.id, { type: "deposit", voucherId: handVoucherIds(table, participant.id)[0] as string });
    }
    completeRecipeBySetup(table, winner.id);
    applyIntent(table, winner.id, { type: "prepare" });

    const expired = store.expireTimer(table.code, (table.timer?.endsAtMs ?? Date.now()) + 1);

    expect(expired).toBe(true);
    expect(table.phase).toBe("eating");
    expect(table.winnerParticipantIds).toEqual([winner.id]);
    expect(table.timer?.expiredAtMs).toBeDefined();
  });

  it("allows a participant to join explicitly as a witness before start", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "witness-join");
    const joined = store.joinTable(created.table.code, "Observer", true);

    expect(joined.participant.role).toBe("witness");
    expect(activeParticipants(created.table)).toHaveLength(1);
  });

  it("lets a non-host leave and rejoin that table as a witness", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "leave-table");
    const joined = store.joinTable(created.table.code, "Ravi");

    store.handleIntent(created.table.code, joined.seatToken, { type: "leave_table" }, false);

    expect(joined.participant.role).toBe("witness");
    expect(joined.participant.connected).toBe(false);
    expect(() => store.handleIntent(created.table.code, joined.seatToken, { type: "set_pause", paused: true }, false)).toThrow(GameError);

    const witness = store.joinTable(created.table.code, "Ravi", true);
    expect(witness.participant.role).toBe("witness");
  });

  it("lets the host close and reset a table while keeping participants and rules", () => {
    const { store, table, hostToken } = makeHarness(7, "close-reset");
    const participantIds = [...table.participantOrder];
    const requiredStock = maxIngredientDemandForPlayerCount(7, 2);
    store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 60 }, false);
    store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 2 }, false);
    store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock }, false);
    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    expect(table.phase).toBe("deposit");

    store.handleIntent(table.code, hostToken, { type: "close_table" }, false);
    expect(table.phase).toBe("complete");
    expect(table.timer?.seconds).toBe(60);
    expect(table.timer?.endsAtMs).toBeUndefined();

    store.handleIntent(table.code, hostToken, { type: "reset_table" }, false);
    expect(table.phase).toBe("lobby");
    expect(table.participantOrder).toEqual(participantIds);
    expect(table.targetDishCount).toBe(2);
    expect(table.stockPerIngredient).toBe(requiredStock);
    expect(table.timer?.seconds).toBe(60);
    expect(Object.keys(table.vouchers)).toHaveLength(0);
    expect(Object.keys(table.recipes)).toHaveLength(0);
    expect(Object.keys(table.dishes)).toHaveLength(0);
    for (const participant of Object.values(table.participants)) {
      expect(participant.dishCount).toBe(0);
      expect(participant.depositedInitial).toBe(false);
      expect(participant.ingredientId).toBeUndefined();
    }
  });
});

describe("HTTP app", () => {
  it("creates and joins tables over HTTP", async () => {
    const app = await buildApp({ store: new TableStore() });
    const created = await app.inject({
      method: "POST",
      url: "/tables",
      payload: { hostName: "Ada", seed: "http" }
    });
    expect(created.statusCode).toBe(200);
    const createdBody = created.json();
    const joined = await app.inject({
      method: "POST",
      url: `/tables/${createdBody.result.tableCode}/join`,
      payload: { name: "Ben" }
    });

    expect(joined.statusCode).toBe(200);
    expect(joined.json().result.participantId).not.toBe(createdBody.result.participantId);
    await app.close();
  });

  it("broadcasts to existing sockets when a player joins over HTTP", async () => {
    const store = new TableStore();
    const hub = new ConnectionHub();
    const app = await buildApp({ store, hub });
    const created = store.createTable("Host", "join-broadcast");
    const messages: unknown[] = [];
    hub.register({
      tableCode: created.table.code,
      participantId: created.participant.id,
      send: (payload) => messages.push(JSON.parse(payload))
    });

    const joined = await app.inject({
      method: "POST",
      url: `/tables/${created.table.code}/join`,
      payload: { name: "Ben" }
    });

    expect(joined.statusCode).toBe(200);
    const snapshot = (messages.at(-1) as { snapshot: ReturnType<typeof buildSnapshot> }).snapshot;
    expect(snapshot.participants).toHaveLength(2);
    await app.close();
  });
});

describe("determinism", () => {
  it("generates repeatable recipes from the same seed", () => {
    const first = startTable(7, "same-seed").table;
    const second = startTable(7, "same-seed").table;
    const firstRecipes = Object.values(first.recipes).map((recipe) =>
      recipe.requirements.map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    );
    const secondRecipes = Object.values(second.recipes).map((recipe) =>
      recipe.requirements.map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    );

    expect(firstRecipes).toEqual(secondRecipes);
  });

  it("makes deterministic bot decisions from the same seed and state", () => {
    const first = makeHarness(6, "bot-seed");
    const second = makeHarness(6, "bot-seed");
    const firstBot = addBots(first.table, first.table.hostParticipantId, ["mixed"])[0];
    const secondBot = addBots(second.table, second.table.hostParticipantId, ["mixed"])[0];
    applyIntent(first.table, first.table.hostParticipantId, { type: "start" });
    applyIntent(second.table, second.table.hostParticipantId, { type: "start" });

    expect(decideBotIntent(first.table, firstBot.id)).toEqual(decideBotIntent(second.table, secondBot.id));
  });
});
