import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { buildApp } from "../src/app.js";
import { decideBotIntent, runBots } from "../src/bots.js";
import { computeGameStats } from "../src/gameStats.js";
import {
  BOT_TYPES,
  DEFAULT_TARGET_DISH_COUNT,
  DISH_PARTS_PER_DISH,
  INGREDIENTS,
  MAX_ACTIVE_PARTICIPANTS,
  MAX_STOCK_PER_INGREDIENT,
  MAX_TARGET_DISH_COUNT,
  MIN_ACTIVE_PARTICIPANTS,
  MIN_STOCK_PER_INGREDIENT,
  MIN_TARGET_DISH_COUNT,
  OPENING_OFFERINGS_PER_PLAYER,
  REAL_UNITS_PER_INGREDIENT,
  VOUCHERS_PER_INGREDIENT
} from "../src/constants.js";
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
  minimumBackedStockForPlayerCount,
  MAX_TEMPLATE_INGREDIENTS,
  MIN_TEMPLATE_INGREDIENTS,
  RECIPE_DISTINCT_COUNTS,
  RECIPE_REQUIRED_ITEMS,
  RECIPE_SLOTS,
  RECIPE_VARIANT_COUNT
} from "../src/recipeCatalog.js";
import { buildSnapshot } from "../src/snapshots.js";
import { TableStore } from "../src/store.js";
import type { BotType, Participant, Table, TurnMode, Voucher } from "../src/types.js";

interface Harness {
  store: TableStore;
  table: Table;
  hostToken: string;
}

function makeHarness(activeCount: number, seed = "test-seed", turnMode: TurnMode = "round_robin"): Harness {
  const store = new TableStore();
  const created = store.createTable("Host", seed);
  created.table.turnMode = turnMode;
  for (let index = 2; index <= activeCount; index += 1) {
    store.joinTable(created.table.code, `Player ${index}`);
  }
  return { store, table: created.table, hostToken: created.seatToken };
}

function startTable(activeCount: number, seed = "start-seed", turnMode: TurnMode = "round_robin"): Harness {
  const harness = makeHarness(activeCount, seed, turnMode);
  harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
  return harness;
}

function startAndDeposit(activeCount: number, seed = "deposit-seed", turnMode: TurnMode = "round_robin"): Harness {
  const harness = startTable(activeCount, seed, turnMode);
  expect(harness.table.phase).toBe("playing");
  return harness;
}

function addBots(table: Table, hostId: string, botTypes: BotType[]): Participant[] {
  const bots: Participant[] = [];
  for (const botType of botTypes) {
    const existingBot = activeParticipants(table).find(
      (participant) => participant.kind === "bot" && !bots.some((selected) => selected.id === participant.id)
    );
    if (existingBot) {
      existingBot.botType = botType;
      bots.push(existingBot);
      continue;
    }
    applyIntent(table, hostId, { type: "add_bot", name: botType, botType });
    bots.push(table.participants[table.participantOrder.at(-1) as string]);
  }
  return bots;
}

function activeParticipantByIngredient(table: Table, ingredientId: string): Participant {
  const participant = activeParticipants(table).find((candidate) => candidate.ingredientId === ingredientId);
  if (!participant) {
    throw new Error(`Expected active participant for ${ingredientId}`);
  }
  return participant;
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

function applyAsTurn(table: Table, participantId: string, intent: Parameters<typeof applyIntent>[2]) {
  table.currentTurnParticipantId = participantId;
  return applyIntent(table, participantId, intent);
}

function prepareAllDishesBySetup(table: Table): void {
  for (let round = 0; round < table.targetDishCount; round += 1) {
    for (const participant of activeParticipants(table)) {
      completeRecipeBySetup(table, participant.id);
      applyAsTurn(table, participant.id, { type: "prepare" });
    }
  }
}

function validQuantityShape(quantities: number[]): boolean {
  const sorted = [...quantities].sort((left, right) => right - left);
  return (
    sorted.join(",") === "2,2,1,1" ||
    sorted.join(",") === "2,1,1,1,1" ||
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
  it("defines 8 unique ingredient sets with visual metadata", () => {
    expect(INGREDIENTS).toHaveLength(8);
    expect(new Set(INGREDIENTS.map((ingredient) => ingredient.id)).size).toBe(8);
    expect(INGREDIENTS.every((ingredient) => ingredient.description && ingredient.imagePath)).toBe(true);
  });

  it("creates fixed vouchers per active ingredient owner", () => {
    const { table } = startTable(8);
    for (const participant of activeParticipants(table)) {
      expect(vouchersForIngredientOwner(table, participant.id)).toHaveLength(VOUCHERS_PER_INGREDIENT);
      expect(participant.realIngredientStock).toBe(REAL_UNITS_PER_INGREDIENT);
    }
  });

  it("creates a full 8-seat table that can start immediately", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "prefilled-8");

    expect(activeParticipants(created.table)).toHaveLength(8);
    expect(activeParticipants(created.table).filter((participant) => participant.kind === "bot")).toHaveLength(7);

    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);
    expect(created.table.phase).toBe("playing");
    expect(platterVoucherIds(created.table)).toHaveLength(8 * OPENING_OFFERINGS_PER_PLAYER);
    expect(created.table.transactionHistory.filter((row) => row.action === "Deposit")).toHaveLength(8 * OPENING_OFFERINGS_PER_PLAYER);
    for (const participant of activeParticipants(created.table)) {
      expect(participant.depositedInitial).toBe(true);
      expect(participant.openingOfferingsCount).toBe(OPENING_OFFERINGS_PER_PLAYER);
      expect(handVoucherIds(created.table, participant.id)).toHaveLength(VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER);
      expect(platterAccountForParticipant(created.table, participant.id)).toMatchObject({
        ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
        ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER,
        cleared: true
      });
    }
  });

  it("accepts unique requested table codes and rejects reused or invalid codes", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "requested-code", "cheese42");

    expect(created.table.code).toBe("CHEESE42");
    expect(() => store.createTable("Host", "duplicate-code", "CHEESE42")).toThrow(GameError);
    expect(() => store.createTable("Host", "invalid-code", "bad code")).toThrow(GameError);
  });

  it("reports table code availability and joinability case-insensitively", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "status-code", "beans77");

    expect(store.getTableStatus("BEANS77")).toMatchObject({ code: "BEANS77", valid: true, exists: true, joinable: true });
    expect(store.getTableStatus("beans78")).toMatchObject({ code: "BEANS78", valid: true, exists: false, joinable: false });
    expect(store.getTableStatus("bad code")).toMatchObject({ valid: false, exists: false, joinable: false, reason: "invalid" });

    for (let index = 0; index < 7; index += 1) {
      store.joinTable(created.table.code, `Human ${index}`);
    }
    expect(store.getTableStatus("beans77")).toMatchObject({ exists: true, joinable: false, reason: "full" });
  });

  it("reports started tables as existing but not joinable", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "status-started", "rice55");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    expect(store.getTableStatus("rice55")).toMatchObject({ code: "RICE55", valid: true, exists: true, joinable: false, reason: "started" });
  });

  it("lists only public joinable lobby tables", () => {
    const store = new TableStore();
    const publicTable = store.createTable("Public Host", "public-list", "public77");
    const privateTable = store.createTable("Private Host", "private-list", "private77");
    const startedTable = store.createTable("Started Host", "started-list", "started77");

    store.handleIntent(privateTable.table.code, privateTable.seatToken, { type: "set_table_visibility", isPublic: false }, false);
    store.handleIntent(startedTable.table.code, startedTable.seatToken, { type: "start" }, false);

    expect(store.listPublicJoinableTables()).toEqual([
      {
        code: "PUBLIC77",
        hostName: "Public Host",
        activeSeats: 8,
        humanSeats: 1,
        openSeats: 7
      }
    ]);

    expect(store.getTableStatus(privateTable.table.code)).toMatchObject({ exists: true, joinable: true });
    store.handleIntent(publicTable.table.code, publicTable.seatToken, { type: "set_table_visibility", isPublic: false }, false);
    expect(store.listPublicJoinableTables()).toEqual([]);
  });

  it("serves public joinable tables over HTTP", async () => {
    const store = new TableStore();
    store.createTable("Public Host", "http-public-list", "beans44");
    const privateTable = store.createTable("Private Host", "http-private-list", "eggs44");
    store.handleIntent(privateTable.table.code, privateTable.seatToken, { type: "set_table_visibility", isPublic: false }, false);
    const app = await buildApp({ store });

    const response = await app.inject({ method: "GET", url: "/tables" });
    await app.close();

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      ok: true,
      result: {
        tables: [
          {
            code: "BEANS44",
            hostName: "Public Host",
            openSeats: 7
          }
        ]
      }
    });
  });

  it("allows start with exactly 8 active participants", () => {
    const { table } = startTable(8, "allowed-8");
    expect(table.phase).toBe("playing");
    expect(activeParticipants(table)).toHaveLength(8);
    expect(platterVoucherIds(table)).toHaveLength(8 * OPENING_OFFERINGS_PER_PLAYER);
  });

  it("makes running joins witnesses", () => {
    const { store, table } = startTable(8);
    const joined = store.joinTable(table.code, "Late");
    expect(joined.participant.role).toBe("witness");
  });

  it("replaces lobby bot seats with joining humans before making later joins witnesses", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "join-claims-bots");

    for (let index = 0; index < 7; index += 1) {
      const joined = store.joinTable(created.table.code, `Human ${index + 1}`);
      expect(joined.participant.kind).toBe("human");
      expect(joined.participant.role).toBe("active");
    }

    const overflow = store.joinTable(created.table.code, "Observer");

    expect(activeParticipants(created.table).filter((participant) => participant.kind === "bot")).toHaveLength(0);
    expect(overflow.participant.role).toBe("witness");
  });

  it("lets the host rename human and bot seats before start", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "rename-seats");
    const hostId = created.table.hostParticipantId;
    const bot = activeParticipants(created.table).find((participant) => participant.kind === "bot") as Participant;

    store.handleIntent(created.table.code, created.seatToken, { type: "rename_participant", participantId: hostId, name: "Mara" }, false);
    store.handleIntent(created.table.code, created.seatToken, { type: "rename_participant", participantId: bot.id, name: "Zed" }, false);

    expect(created.table.participants[hostId].name).toBe("Mara");
    expect(created.table.participants[bot.id].name).toBe("Zed_b");

    store.handleIntent(created.table.code, created.seatToken, { type: "rename_participant", participantId: bot.id, name: "Zed_bx" }, false);
    expect(created.table.participants[bot.id].name).toBe("Zed_bx");

    store.handleIntent(created.table.code, created.seatToken, { type: "rename_participant", participantId: bot.id, name: "jjj_b_2" }, false);
    expect(created.table.participants[bot.id].name).toBe("jjj_b");

    store.handleIntent(created.table.code, created.seatToken, { type: "add_controlled_seat", participantId: bot.id, name: "jjj_b" }, false);
    expect(created.table.participants[bot.id]).toMatchObject({ kind: "human", name: "jjj_b" });

    store.handleIntent(created.table.code, created.seatToken, { type: "convert_to_bot", participantId: bot.id }, false);
    expect(created.table.participants[bot.id]).toMatchObject({ kind: "bot", name: "jjj_b" });

    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);
    expect(created.table.phase).toBe("playing");
    expect(created.table.participants[bot.id].name).toBe("jjj_b");
  });

  it("lets a joined player rename their own lobby seat but not other seats", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "self-rename");
    const joined = store.joinTable(created.table.code, "");

    store.handleIntent(created.table.code, joined.seatToken, {
      type: "rename_participant",
      participantId: joined.participant.id,
      name: "Lina"
    }, false);

    expect(joined.participant.name).toBe("Lina");
    expect(() =>
      store.handleIntent(created.table.code, joined.seatToken, {
        type: "rename_participant",
        participantId: created.participant.id,
        name: "Not Allowed"
      }, false)
    ).toThrow(GameError);
  });

  it("lets the host toggle active/witness roles before start", () => {
    const { store, table, hostToken } = makeHarness(8);
    const hostId = table.hostParticipantId;
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: hostId, role: "witness" }, false);
    expect(table.participants[hostId].role).toBe("witness");
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: hostId, role: "active" }, false);
    expect(table.participants[hostId].role).toBe("active");
  });

  it("uses round-robin as the only turn mode", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "turn-mode-default");

    expect(created.table.turnMode).toBe("round_robin");
    expect(created.snapshot.turnMode).toBe("round_robin");
  });

  it("lets the host add and act as controlled seats without changing participant identity", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "controlled-seat");

    const botToClaim = activeParticipants(created.table).find((participant) => participant.kind === "bot") as Participant;
    const controlledSnapshot = store.handleIntent(
      created.table.code,
      created.seatToken,
      { type: "add_controlled_seat", name: "Local Seat", participantId: botToClaim.id },
      false
    );
    const controlledId = controlledSnapshot.participants.find((participant) => participant.name === "Local Seat")?.id as string;

    expect(controlledId).toBeTruthy();
    expect(controlledId).toBe(botToClaim.id);
    expect(created.table.participants[controlledId]).toMatchObject({
      kind: "human",
      role: "active",
      controllerParticipantId: created.participant.id
    });

    for (let index = activeParticipants(created.table).length + 1; index <= 8; index += 1) {
      store.joinTable(created.table.code, `Player ${index}`);
    }
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    const actorSnapshot = buildSnapshot(created.table, controlledId, created.participant.id);
    expect(created.table.participants[controlledId].depositedInitial).toBe(true);
    expect(created.table.participants[controlledId].openingOfferingsCount).toBe(OPENING_OFFERINGS_PER_PLAYER);
    expect(actorSnapshot.viewerParticipantId).toBe(controlledId);
    expect(actorSnapshot.connectionParticipantId).toBe(created.participant.id);
  });

  it("blocks acting as an uncontrolled participant", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "controlled-blocked");
    const uncontrolled = store.joinTable(created.table.code, "Uncontrolled");

    expect(() =>
      store.handleIntent(created.table.code, created.seatToken, { type: "set_role", participantId: uncontrolled.participant.id, role: "witness" }, false, uncontrolled.participant.id)
    ).toThrow(GameError);
  });

  it("keeps controlled-seat snapshots filtered to the selected seat", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "controlled-filter");
    const controlledSnapshot = store.handleIntent(created.table.code, created.seatToken, { type: "add_controlled_seat", name: "Local Seat" }, false);
    const controlledId = controlledSnapshot.participants.find((participant) => participant.name === "Local Seat")?.id as string;
    for (let index = activeParticipants(created.table).length + 1; index <= 8; index += 1) {
      store.joinTable(created.table.code, `Player ${index}`);
    }
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    const snapshot = store.getSnapshotByToken(created.table.code, created.seatToken, controlledId);

    expect(snapshot.viewerParticipantId).toBe(controlledId);
    expect(snapshot.connectionParticipantId).toBe(created.participant.id);
    expect(snapshot.controlledParticipantIds).toContain(controlledId);
    expect(snapshot.viewerCanUseHostControls).toBe(true);
    expect(snapshot.ownHand.every((voucher) => voucher.location.participantId === controlledId)).toBe(true);
    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allVouchers).toBeUndefined();
  });

  it("enforces round-robin turns and allows current players to pass", () => {
    const { table } = startAndDeposit(8, "round-robin-turns", "round_robin");
    const [first, second] = activeParticipants(table);
    const firstVoucher = handVoucherIds(table, first.id)[0] as string;
    const secondVoucher = handVoucherIds(table, second.id)[0] as string;
    const platterVoucher = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ingredientId !== first.ingredientId) as string;

    expect(table.turnMode).toBe("round_robin");
    expect(table.currentTurnParticipantId).toBe(first.id);
    expect(() => applyIntent(table, second.id, { type: "platter_swap", giveVoucherId: secondVoucher, takeVoucherId: platterVoucher })).toThrow(GameError);

    applyIntent(table, first.id, { type: "platter_swap", giveVoucherId: firstVoucher, takeVoucherId: platterVoucher });
    expect(table.currentTurnParticipantId).toBe(first.id);
    expect(() => applyIntent(table, second.id, { type: "pass_turn" })).toThrow(GameError);

    applyIntent(table, first.id, { type: "pass_turn" });
    expect(table.currentTurnParticipantId).toBe(second.id);
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Pass Turn",
      counterparty: second.name,
      itemOut: "Turn",
      itemBack: "None"
    });
  });

  it("redeems useful held cards once before passing a round-robin turn", () => {
    const { table } = startAndDeposit(8, "round-robin-redeem-all-pass", "round_robin");
    const [first, second] = activeParticipants(table);
    const recipe = table.recipes[first.id];
    const ownRequirement = recipe?.requirements.find((requirement) => requirement.ingredientId === first.ingredientId);
    expect(recipe).toBeDefined();
    expect(ownRequirement).toBeDefined();
    const initialUsefulIds = handVoucherIds(table, first.id).filter(
      (voucherId) => table.vouchers[voucherId].ingredientId === first.ingredientId
    );
    const initialOutstanding =
      (ownRequirement?.requiredQty ?? 0) - (ownRequirement?.redeemedQty ?? 0) - (ownRequirement?.placedVoucherIds.length ?? 0);
    const expectedRedeemed = Math.min(initialUsefulIds.length, initialOutstanding);
    expect(expectedRedeemed).toBeGreaterThan(0);
    const startingStock = first.realIngredientStock;

    applyIntent(table, first.id, { type: "redeem_all_and_pass_turn" });

    expect(ownRequirement?.redeemedQty).toBe(expectedRedeemed);
    expect(first.realIngredientStock).toBe((startingStock ?? 0) - expectedRedeemed);
    expect(table.currentTurnParticipantId).toBe(second.id);
    expect(table.transactionHistory.filter((transaction) => transaction.action === "Redeem")).toHaveLength(expectedRedeemed);
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Pass Turn",
      counterparty: second.name
    });
  });

  it("automatically prepares a completed dish before redeem-pass advances the turn", () => {
    const { table } = startAndDeposit(8, "round-robin-redeem-pass-auto-prepare", "round_robin");
    const [first, second] = activeParticipants(table);
    const recipe = table.recipes[first.id];
    const finalRequirement = recipe?.requirements.find((requirement) => requirement.ingredientId === first.ingredientId);
    if (!recipe || !finalRequirement) {
      throw new Error("test setup expected first participant recipe to require their ingredient");
    }

    for (const requirement of recipe.requirements) {
      requirement.placedVoucherIds = [];
      requirement.redeemedQty = requirement.id === finalRequirement.id ? requirement.requiredQty - 1 : requirement.requiredQty;
    }
    const beforeDishCount = first.dishCount;
    const beforeRecipeId = recipe.id;
    const beforeHistoryLength = table.transactionHistory.length;

    applyIntent(table, first.id, { type: "redeem_all_and_pass_turn" });

    expect(first.dishCount).toBe(beforeDishCount + 1);
    expect(table.recipes[first.id]?.id).not.toBe(beforeRecipeId);
    expect(inventoryDishPartIds(table, first.id)).toHaveLength(DISH_PARTS_PER_DISH);
    expect(table.currentTurnParticipantId).toBe(second.id);
    expect(table.transactionHistory.slice(beforeHistoryLength).map((transaction) => transaction.action)).toEqual([
      "Redeem",
      "Prepare",
      "Pass Turn"
    ]);
  });

  it("keeps goal-reached active players in the playing turn order", () => {
    const { table } = startAndDeposit(8, "round-robin-goal-reached", "round_robin");
    const participants = activeParticipants(table);
    const first = participants[0] as (typeof participants)[number];
    const last = participants[participants.length - 1] as (typeof participants)[number];
    first.dishCount = table.targetDishCount;
    table.currentTurnParticipantId = last.id;

    applyIntent(table, last.id, { type: "pass_turn" });

    expect(table.currentTurnParticipantId).toBe(first.id);
  });

  it("does not run bot transactions during a human round-robin turn before pass", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "round-robin-human-turn");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" });
    expect(created.table.phase).toBe("playing");
    expect(created.table.currentTurnParticipantId).toBe(created.participant.id);

    const hostIngredientId = created.participant.ingredientId as string;
    const takeIngredientId = platterVoucherIds(created.table)
      .map((voucherId) => created.table.vouchers[voucherId].ingredientId)
      .find((ingredientId) => ingredientId !== hostIngredientId) as string;
    const beforeSwapCount = created.table.transactionHistory.length;
    store.handleIntent(created.table.code, created.seatToken, {
      type: "platter_swap_ingredient",
      giveIngredientId: hostIngredientId,
      takeIngredientId
    });

    const swapTransactions = created.table.transactionHistory.slice(beforeSwapCount);
    expect(swapTransactions).toHaveLength(1);
    expect(swapTransactions[0]).toMatchObject({ name: created.participant.name, action: "Swap" });
    expect(created.table.currentTurnParticipantId).toBe(created.participant.id);

    store.handleIntent(created.table.code, created.seatToken, { type: "pass_turn" });
    expect(created.table.transactionHistory.slice(beforeSwapCount + 1).some((transaction) => transaction.name !== created.participant.name)).toBe(true);
  });

  it("reports each bot mutation separately after a human round-robin pass", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "round-robin-bot-broadcasts");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    const mutationVersions: number[] = [];
    const mutationNames: string[] = [];
    store.handleIntent(created.table.code, created.seatToken, { type: "pass_turn" }, true, undefined, (table) => {
      mutationVersions.push(table.version);
      mutationNames.push(table.transactionHistory.at(-1)?.name ?? "");
    });

    expect(mutationVersions.length).toBeGreaterThan(1);
    expect(mutationNames[0]).toBe(created.participant.name);
    expect(mutationNames.slice(1).some((name) => name !== created.participant.name)).toBe(true);
    expect([...mutationVersions].sort((left, right) => left - right)).toEqual(mutationVersions);
  });

  it("does not leave round-robin control stranded on bots when the bot budget is exhausted", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "round-robin-bot-budget");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);
    const firstBot = activeParticipants(created.table).find((participant) => participant.kind === "bot") as Participant;
    created.table.currentTurnParticipantId = firstBot.id;

    runBots(created.table, 0);

    expect(created.table.currentTurnParticipantId).toBe(created.participant.id);
    expect(created.table.transactionHistory.at(-1)).toMatchObject({
      action: "Pass Turn",
      counterparty: created.participant.name
    });
  });

  it("generates default participant names and bot names", () => {
    const store = new TableStore();
    const created = store.createTable("", "names");
    const joined = store.joinTable(created.table.code, "");
    const bots = Object.values(created.table.participants).filter((participant) => participant.kind === "bot");

    expect(created.participant.name).toBe("Amina");
    expect(joined.participant.name).toBe("Ben");
    expect(bots.map((bot) => bot.name)).toEqual(["Nia_b", "Luc_b", "Ava_b", "Leo_b", "Mia_b", "Yan_b"]);

    const botOnlyStore = new TableStore();
    const botOnly = botOnlyStore.createTable("Host", "first-bot-name");
    const firstBot = activeParticipants(botOnly.table).find((participant) => participant.kind === "bot");
    expect(firstBot?.name).toBe("Jim_b");
  });

  it("starts a host plus bots through the store without repeat bot deposits", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "bot-start");

    const snapshot = store.handleIntent(created.table.code, created.seatToken, { type: "start" });
    const active = activeParticipants(created.table);
    const bots = active.filter((participant) => participant.kind === "bot");
    const historyAfterStart = created.table.transactionHistory.map((row) => row.action);

    expect(created.table.phase).toBe("playing");
    expect(active).toHaveLength(8);
    expect(bots.every((participant) => participant.depositedInitial)).toBe(true);
    expect(bots.every((participant) => participant.openingOfferingsCount === OPENING_OFFERINGS_PER_PLAYER)).toBe(true);
    expect(created.table.participants[created.table.hostParticipantId].depositedInitial).toBe(true);
    expect(created.table.participants[created.table.hostParticipantId].openingOfferingsCount).toBe(OPENING_OFFERINGS_PER_PLAYER);
    expect(historyAfterStart).toHaveLength(8 * OPENING_OFFERINGS_PER_PLAYER);
    expect(historyAfterStart.every((action) => action === "Deposit")).toBe(true);
    expect(snapshot.phase).toBe("playing");
    expect(snapshot.ownHand).toHaveLength(VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER);
    expect(snapshot.ownRecipe).toBeDefined();
  });

  it("continues bot turns into useful self-redemption after the host deposits", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "bot-start-self-redeem");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" });
    const bot = activeParticipants(created.table).find((participant) => participant.kind === "bot") as Participant;
    const ownRequirement = created.table.recipes[bot.id]?.requirements.find(
      (requirement) => requirement.ingredientId === bot.ingredientId
    );
    expect(ownRequirement).toBeDefined();

    applyIntent(created.table, created.table.hostParticipantId, { type: "pass_turn" });
    expect(created.table.currentTurnParticipantId).toBe(bot.id);
    runBots(created.table);

    expect(created.table.phase).toBe("playing");
    expect(ownRequirement?.redeemedQty).toBe(ownRequirement?.requiredQty);
    expect(ownRequirement?.placedVoucherIds).toHaveLength(0);
  });

  it("exposes lobby timer changes in filtered snapshots", () => {
    const { store, table, hostToken } = makeHarness(8, "timer-snapshot");

    const setSnapshot = store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 180 }, false);
    expect(setSnapshot.timer).toMatchObject({ seconds: 180 });

    const clearedSnapshot = store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: null }, false);
    expect(clearedSnapshot.timer).toBeUndefined();
  });

  it("lets the host set the dish goal from 1 to 4 before start", () => {
    const { store, table, hostToken } = makeHarness(8, "dish-goal");
    const snapshot = store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 2 }, false);

    expect(table.targetDishCount).toBe(2);
    expect(snapshot.targetDishCount).toBe(2);
    expect(() => store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 5 }, false)).toThrow(GameError);
    expect(table.targetDishCount).toBe(2);
  });

  it("lets the host set starting stock before start", () => {
    const { store, table, hostToken } = makeHarness(8, "stock-setting");
    const requiredStock = minimumBackedStockForPlayerCount(8, table.targetDishCount);
    const snapshot = store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock }, false);

    expect(table.stockPerIngredient).toBe(requiredStock);
    expect(snapshot.stockPerIngredient).toBe(requiredStock);

    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(table)) {
      expect(participant.realIngredientStock).toBe(requiredStock);
    }
  });

  it("blocks start when configured stock is below catalog demand plus voucher backing for the chosen goal", () => {
    const { store, table, hostToken } = makeHarness(8, "stock-too-low");
    const requiredStock = minimumBackedStockForPlayerCount(8, table.targetDishCount);

    store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock - 1 }, false);

    expect(() => store.handleIntent(table.code, hostToken, { type: "start" }, false)).toThrow(GameError);
    expect(table.phase).toBe("lobby");
  });

  it("does not mutate the table or turn on invalid intents", () => {
    const { store, table, hostToken } = makeHarness(8);
    const before = structuredClone(table);

    expect(() => store.handleIntent(table.code, hostToken, { type: "set_stock", count: MAX_STOCK_PER_INGREDIENT + 1 }, false)).toThrow(GameError);

    expect(table).toEqual(before);
  });

  it("restores partial mutations when validation fails mid-action", () => {
    const { store, table, hostToken } = makeHarness(8);
    const extra = store.joinTable(table.code, "Extra");
    const extraId = extra.participant.id;
    store.handleIntent(table.code, hostToken, { type: "set_role", participantId: extraId, role: "witness" }, false);
    const before = structuredClone(table);

    expect(() => store.handleIntent(table.code, hostToken, { type: "set_role", participantId: extraId, role: "active" }, false)).toThrow(GameError);

    expect(table).toEqual(before);
  });
});

describe("recipe catalog generator", () => {
  it("defines one committed 8-ingredient set", () => {
    const knownIngredientIds = new Set(INGREDIENTS.map((ingredient) => ingredient.id));
    const committedIds = COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT[8];
    const ingredients = ingredientsForPlayerCount(8);

    expect(Object.keys(COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT)).toEqual(["8"]);
    expect(committedIds).toHaveLength(8);
    expect(new Set(committedIds).size).toBe(8);
    expect(committedIds.every((ingredientId) => knownIngredientIds.has(ingredientId))).toBe(true);
    expect(ingredients.map((ingredient) => ingredient.id)).toEqual(committedIds);
  });

  it("generates four short named recipes per ingredient for the fixed 8-player configuration", () => {
    const catalog = generateRecipeCatalog();

    expect(catalog.configurations).toHaveLength(1);
    expect(catalog.configurations[0]?.playerCount).toBe(8);
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
    expect(dishNames).toEqual(expect.arrayContaining(["Cheese Frittata", "Bean Pupusa", "Fried Rice", "Breakfast Burrito"]));
    expect(dishNames.every((name) => name.length <= 24)).toBe(true);

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
        expect(generatedFromExactTemplate).toBe(true);
        expect(recipe.dishName).toBe(template.dishName);
        expect(recipe.fallbackIngredientIds).toEqual([]);
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
        expect(demand + VOUCHERS_PER_INGREDIENT).toBeLessThanOrEqual(REAL_UNITS_PER_INGREDIENT);
      }
    }
  });

  it("uses committed recipe ingredients without fallback ingredients", () => {
    const recipe = catalogRecipeForIngredients(ingredientsForPlayerCount(8), "cheese", "initial", "players_8");

    expect(recipe.dishName).toBe("Cheese Frittata");
    expect(recipe.fallbackIngredientIds).toEqual([]);
    expect(recipe.requirements.map((requirement) => requirement.ingredientId)).toEqual([
      "cheese",
      "eggs",
      "vegetables",
      "herbs",
      "spices",
      "flour"
    ]);
  });

  it("uses the committed player-count ingredient set for runtime tables and catalog lookup rows", () => {
    const activeIngredientsForPlayerCount = ingredientsForPlayerCount(8);
    const { table } = startTable(8, "runtime-committed-set");
    const runtimeIngredientIds = activeParticipants(table).map((participant) => participant.ingredientId);

    expect([...runtimeIngredientIds].sort()).toEqual(activeIngredientsForPlayerCount.map((ingredient) => ingredient.id).sort());
    expect(new Set(runtimeIngredientIds).size).toBe(activeIngredientsForPlayerCount.length);

    const participant = activeParticipants(table)[0] as Participant;
    const runtimeRecipe = table.recipes[participant.id];
    const matchingCatalogRecipe = RECIPE_SLOTS.map((slot) =>
      catalogRecipeForIngredients(activeIngredientsForPlayerCount, participant.ingredientId as string, slot, "players_8")
    ).find((recipe) => recipe.dishName === runtimeRecipe.name);
    expect(matchingCatalogRecipe).toBeDefined();
    expect(runtimeRecipe.requirements.map((requirement) => requirement.ingredientId)).toEqual(
      matchingCatalogRecipe?.requirements.map((requirement) => requirement.ingredientId)
    );
  });

  it("randomizes lobby ingredient seats per table seed while preserving the committed set", () => {
    const first = makeHarness(8, "lobby-random-a").table;
    const second = makeHarness(8, "lobby-random-b").table;
    const committedIds = ingredientsForPlayerCount(8).map((ingredient) => ingredient.id).sort();
    const firstOrder = activeParticipants(first).map((participant) => participant.ingredientId as string);
    const secondOrder = activeParticipants(second).map((participant) => participant.ingredientId as string);

    expect([...firstOrder].sort()).toEqual(committedIds);
    expect([...secondOrder].sort()).toEqual(committedIds);
    expect(new Set(firstOrder).size).toBe(8);
    expect(new Set(secondOrder).size).toBe(8);
    expect(firstOrder).not.toEqual(secondOrder);
  });

  it("writes a client recipe fixture matching the generated catalog", () => {
    const generated = generateRecipeCatalog();
    const fixture = JSON.parse(readFileSync(new URL("../../client/data/recipe_catalog.json", import.meta.url), "utf8")) as ReturnType<
      typeof generateRecipeCatalog
    >;

    expect(fixture.generatorVersion).toBe(generated.generatorVersion);
    expect(fixture.ingredients).toEqual(generated.ingredients);
    expect(fixture.configurations.map((configuration) => configuration.ingredients.map((ingredient) => ingredient.id))).toEqual(
      generated.configurations.map((configuration) => configuration.ingredients.map((ingredient) => ingredient.id))
    );
    expect(fixture.recipes.map((recipe) => [recipe.recipeId, recipe.dishName, recipe.requirements])).toEqual(
      generated.recipes.map((recipe) => [recipe.recipeId, recipe.dishName, recipe.requirements])
    );
  });

  it("writes a client game config fixture matching server rule constants", () => {
    const fixture = JSON.parse(readFileSync(new URL("../../client/data/game_config.json", import.meta.url), "utf8")) as Record<
      string,
      unknown
    >;

    expect(fixture).toMatchObject({
      schemaVersion: 1,
      minActiveParticipants: MIN_ACTIVE_PARTICIPANTS,
      maxActiveParticipants: MAX_ACTIVE_PARTICIPANTS,
      vouchersPerIngredient: VOUCHERS_PER_INGREDIENT,
      openingOfferingsPerPlayer: OPENING_OFFERINGS_PER_PLAYER,
      realUnitsPerIngredient: REAL_UNITS_PER_INGREDIENT,
      minStockPerIngredient: MIN_STOCK_PER_INGREDIENT,
      maxStockPerIngredient: MAX_STOCK_PER_INGREDIENT,
      dishPartsPerDish: DISH_PARTS_PER_DISH,
      minTargetDishCount: MIN_TARGET_DISH_COUNT,
      maxTargetDishCount: MAX_TARGET_DISH_COUNT,
      defaultTargetDishCount: DEFAULT_TARGET_DISH_COUNT,
      defaultTurnMode: "round_robin",
      turnModes: ["round_robin"],
      botTypes: BOT_TYPES
    });
    expect(fixture.intentTypes).toEqual(
      expect.arrayContaining([
        "start",
        "deposit_ingredient",
        "platter_swap_ingredient",
        "create_offer",
        "redeem_from_hand",
        "redeem_all_and_pass_turn",
        "prepare",
        "bite"
      ])
    );
  });

  it("never generates fallback names for the fixed catalog", () => {
    const catalog = generateRecipeCatalog();
    for (const recipe of catalog.recipes) {
      const template = catalog.dishTemplates.find((candidate) => candidate.templateId === recipe.templateId);
      expect(template).toBeDefined();
      expect(recipe.dishName).toBe(template?.dishName);
      expect(recipe.fallbackIngredientIds).toEqual([]);
      expect(recipe.realIngredientIds).toEqual(recipe.requirements.map((requirement) => requirement.ingredientId));
    }
  });
});

describe("recipes and voucher lifecycle", () => {
  it("creates six-card recipes with valid quantity shapes and own ingredient", () => {
    const { table } = startTable(8, "recipe-total-8");
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
  });

  it("supports requirement quantities greater than one", () => {
    const quantities = generateRecipeCatalog().recipes.flatMap((recipe) =>
      recipe.requirements.map((requirement) => requirement.requiredQty)
    );
    expect(quantities.some((quantity) => quantity > 1)).toBe(true);
  });

  it("uses generated catalog dish names in running tables", () => {
    const { table } = startTable(8, "runtime-catalog");
    const catalogDishNames = new Set(generateRecipeCatalog().recipes.map((recipe) => recipe.dishName));

    for (const recipe of Object.values(table.recipes)) {
      expect(catalogDishNames.has(recipe.name)).toBe(true);
    }
  });

  it("only asks for ingredients owned by active table participants", () => {
    const { table } = startTable(8);
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
    const { table } = startTable(8, "snapshot-recipe-metadata");
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

  it("includes public current-recipe help summaries for other active participants", () => {
    const { table } = startTable(8, "public-recipe-summary");
    const viewer = activeParticipants(table)[0] as Participant;
    const other = firstOtherActive(table, viewer.id);
    const snapshot = buildSnapshot(table, viewer.id);
    const publicOther = snapshot.participants.find((participant) => participant.id === other.id);
    const otherRecipe = table.recipes[other.id];

    if (!otherRecipe) {
      throw new Error("Missing other participant recipe.");
    }
    const heldUsefulCounts = new Map<string, number>();
    for (const voucherId of handVoucherIds(table, other.id)) {
      const voucher = table.vouchers[voucherId];
      const owner = table.participants[voucher.ownerParticipantId];
      if ((owner?.realIngredientStock ?? 0) <= 0) {
        continue;
      }
      heldUsefulCounts.set(voucher.ingredientId, (heldUsefulCounts.get(voucher.ingredientId) ?? 0) + 1);
    }
    expect(publicOther?.currentRecipe).toEqual({
      name: otherRecipe.name,
      missingRequirements: otherRecipe.requirements
        .map((requirement) => ({
          ingredientId: requirement.ingredientId,
          missingQty: Math.max(
            0,
            requirement.requiredQty - requirement.redeemedQty - (heldUsefulCounts.get(requirement.ingredientId) ?? 0)
          )
        }))
        .filter((requirement) => requirement.missingQty > 0)
    });
    expect(publicOther?.currentRecipe?.missingRequirements.some((requirement) => requirement.ingredientId === other.ingredientId)).toBe(false);
    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allRecipes).toBeUndefined();
  });

  it("assigns a new table-valid recipe after preparing a dish", () => {
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8, "dish-parts");
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
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8);
    const before = invariantVoucherCounts(table);
    expect(Object.values(before)).toEqual(Array(8).fill(VOUCHERS_PER_INGREDIENT));

    const participant = activeParticipants(table)[0] as Participant;
    const recipe = table.recipes[participant.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, participant.id, requirement.ingredientId);
    applyIntent(table, participant.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    applyIntent(table, participant.id, { type: "redeem_voucher", voucherId: voucher.id });

    expect(invariantVoucherCounts(table)).toEqual(before);
  });

  it("only creates vouchers for active physical ingredient owners", () => {
    const { table } = startTable(8);
    const activeOwnerIds = new Set(activeParticipants(table).map((participant) => participant.id));
    for (const voucher of Object.values(table.vouchers)) {
      expect(activeOwnerIds.has(voucher.ownerParticipantId)).toBe(true);
    }
  });

  it("decrements issuer stock and returns redeemed vouchers to the issuer hand", () => {
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8, "stock-reconciliation");
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
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8);
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

  it("blocks stock-depleted hand cards from being used as live vouchers", () => {
    const { table } = startAndDeposit(8, "stock-depleted-cards");
    const [participant, other] = activeParticipants(table);
    const ownVoucherId = handVoucherIds(table, participant.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === participant.id
    ) as string;
    const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ingredientId !== participant.ingredientId) as string;
    const ownRequirement = table.recipes[participant.id].requirements.find((requirement) => requirement.ingredientId === participant.ingredientId);
    participant.realIngredientStock = 0;

    expect(() =>
      applyIntent(table, participant.id, { type: "platter_swap", giveVoucherId: ownVoucherId, takeVoucherId })
    ).toThrow(GameError);
    expect(() =>
      applyIntent(table, participant.id, {
        type: "create_offer",
        toParticipantId: other.id,
        offeredVoucherIds: [ownVoucherId],
        requested: { ingredientId: other.ingredientId as string, quantity: 1 }
      })
    ).toThrow(GameError);
    expect(() =>
      applyIntent(table, participant.id, { type: "place_voucher", voucherId: ownVoucherId, requirementId: ownRequirement?.id as string })
    ).toThrow(GameError);
  });
});

describe("platter, offers, and visibility", () => {
  it("deposits and swaps with the central platter atomically", () => {
    const { table } = startAndDeposit(8);
    const participant = activeParticipants(table)[0] as Participant;
    const platterBefore = platterVoucherIds(table);
    const giveVoucherId = handVoucherIds(table, participant.id)[0] as string;
    const takeVoucherId = platterBefore.find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id) as string;

    applyIntent(table, participant.id, { type: "platter_swap", giveVoucherId, takeVoucherId });

    expect(platterVoucherIds(table)).toHaveLength(platterBefore.length);
    expect(table.vouchers[giveVoucherId].location.type).toBe("platter");
    expect(table.vouchers[takeVoucherId].location).toEqual({ type: "hand", participantId: participant.id });
  });

  it("exposes aggregate voucher groups and accepts aggregate deposit and platter swap intents", () => {
    const { table } = startTable(8, "aggregate-vouchers");
    const [first, second] = activeParticipants(table);
    const initialSnapshot = buildSnapshot(table, first.id);

    expect(initialSnapshot.ownHandGroups).toContainEqual({
      ingredientId: first.ingredientId,
      ownerParticipantId: first.id,
      count: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER
    });

    expect(table.phase).toBe("playing");
    expect(platterVoucherIds(table).filter((voucherId) => table.vouchers[voucherId].ownerParticipantId === first.id)).toHaveLength(OPENING_OFFERINGS_PER_PLAYER);

    applyIntent(table, first.id, {
      type: "platter_swap_ingredient",
      giveIngredientId: first.ingredientId as string,
      takeIngredientId: second.ingredientId as string
    });

    const snapshot = buildSnapshot(table, first.id);
    expect(snapshot.platterVoucherGroups.find((group) => group.ingredientId === first.ingredientId)?.count).toBe(OPENING_OFFERINGS_PER_PLAYER + 1);
    expect(snapshot.ownHandGroups.find((group) => group.ingredientId === second.ingredientId)?.count).toBe(1);
  });

  it("allows prepared food parts to be swapped through the platter during play", () => {
    const { table } = startAndDeposit(8, "playing-food-part-swap");
    const participant = activeParticipants(table)[0] as Participant;
    completeRecipeBySetup(table, participant.id);
    applyIntent(table, participant.id, { type: "prepare" });
    expect(table.phase).toBe("playing");

    const givePartId = inventoryDishPartIds(table, participant.id)[0] as string;
    const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id) as string;

    applyIntent(table, participant.id, {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: givePartId },
      take: { kind: "voucher", id: takeVoucherId }
    });

    expect(table.dishParts[givePartId].location).toEqual({ type: "platter" });
    expect(table.vouchers[takeVoucherId].location).toEqual({ type: "hand", participantId: participant.id });
  });

  it("locks structured offer cards and resolves an accepted exchange", () => {
    const { table } = startAndDeposit(8);
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

    applyAsTurn(table, to.id, { type: "respond_offer", offerId: offer.id, response: "accept", voucherIds: [requestedVoucherId] });

    expect(offer.status).toBe("accepted");
    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: to.id });
    expect(table.vouchers[requestedVoucherId].location).toEqual({ type: "hand", participantId: from.id });
  });

  it("locks and resolves doubled promise-card offers atomically", () => {
    const { table } = startAndDeposit(8, "doubled-card-offer");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherIds = handVoucherIds(table, from.id)
      .filter((voucherId) => table.vouchers[voucherId].ownerParticipantId === from.id)
      .slice(0, 2);
    const requestedVoucherIds = handVoucherIds(table, to.id)
      .filter((voucherId) => table.vouchers[voucherId].ownerParticipantId === to.id)
      .slice(0, 2);
    expect(offeredVoucherIds).toHaveLength(2);
    expect(requestedVoucherIds).toHaveLength(2);
    const requestedVoucher = table.vouchers[requestedVoucherIds[0] as string];

    applyIntent(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: offeredVoucherIds.map((id) => ({ kind: "voucher", id })),
      requestedAsset: {
        kind: "voucher",
        ingredientId: requestedVoucher.ingredientId,
        ownerParticipantId: requestedVoucher.ownerParticipantId,
        quantity: 2
      }
    });
    const offer = Object.values(table.offers)[0];
    expect(offer.offeredAssets).toHaveLength(2);
    for (const voucherId of offeredVoucherIds) {
      expect(table.vouchers[voucherId].location).toEqual({ type: "offer_lock", offerId: offer.id });
    }

    applyAsTurn(table, to.id, {
      type: "respond_offer",
      offerId: offer.id,
      response: "accept",
      voucherIds: requestedVoucherIds
    });

    expect(table.offers[offer.id]).toBeUndefined();
    for (const voucherId of offeredVoucherIds) {
      expect(table.vouchers[voucherId].location).toEqual({ type: "hand", participantId: to.id });
    }
    for (const voucherId of requestedVoucherIds) {
      expect(table.vouchers[voucherId].location).toEqual({ type: "hand", participantId: from.id });
    }
  });

  it("allows direct offers of food pieces for promise cards", () => {
    const { table } = startAndDeposit(8, "food-piece-for-card-offer");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    completeRecipeBySetup(table, from.id);
    applyAsTurn(table, from.id, { type: "prepare" });
    const offeredPartId = inventoryDishPartIds(table, from.id)[0] as string;
    const requestedVoucherId = handVoucherIds(table, to.id).find((voucherId) => table.vouchers[voucherId].ownerParticipantId === to.id) as string;
    const requestedVoucher = table.vouchers[requestedVoucherId];

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: [{ kind: "dish_part", id: offeredPartId }],
      requestedAsset: {
        kind: "voucher",
        ingredientId: requestedVoucher.ingredientId,
        ownerParticipantId: requestedVoucher.ownerParticipantId,
        quantity: 1
      }
    });
    const offer = Object.values(table.offers)[0];

    expect(table.dishParts[offeredPartId].location).toEqual({ type: "offer_lock", offerId: offer.id });
    expect(buildSnapshot(table, to.id).offers[0].offeredDishParts).toEqual([expect.objectContaining({ id: offeredPartId })]);

    applyAsTurn(table, to.id, {
      type: "respond_offer",
      offerId: offer.id,
      response: "accept",
      assets: [{ kind: "voucher", id: requestedVoucherId }]
    });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.dishParts[offeredPartId].location).toEqual({ type: "inventory", participantId: to.id });
    expect(table.vouchers[requestedVoucherId].location).toEqual({ type: "hand", participantId: from.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: from.name,
      action: "Exchange",
      counterparty: to.name,
      itemOut: expect.stringContaining(table.dishParts[offeredPartId].dishName),
      itemBack: requestedVoucher.ingredientId[0].toUpperCase() + requestedVoucher.ingredientId.slice(1)
    });
  });

  it("locks and resolves doubled food-piece offers for promise cards", () => {
    const { table } = startAndDeposit(8, "doubled-food-piece-offer");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    completeRecipeBySetup(table, from.id);
    applyAsTurn(table, from.id, { type: "prepare" });
    const offeredPartIds = inventoryDishPartIds(table, from.id).slice(0, 2);
    const requestedVoucherIds = handVoucherIds(table, to.id)
      .filter((voucherId) => table.vouchers[voucherId].ownerParticipantId === to.id)
      .slice(0, 2);
    expect(offeredPartIds).toHaveLength(2);
    expect(requestedVoucherIds).toHaveLength(2);
    const requestedVoucher = table.vouchers[requestedVoucherIds[0] as string];

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: offeredPartIds.map((id) => ({ kind: "dish_part", id })),
      requestedAsset: {
        kind: "voucher",
        ingredientId: requestedVoucher.ingredientId,
        ownerParticipantId: requestedVoucher.ownerParticipantId,
        quantity: 2
      }
    });
    const offer = Object.values(table.offers)[0];
    expect(offer.offeredAssets).toHaveLength(2);
    for (const partId of offeredPartIds) {
      expect(table.dishParts[partId].location).toEqual({ type: "offer_lock", offerId: offer.id });
    }

    applyAsTurn(table, to.id, {
      type: "respond_offer",
      offerId: offer.id,
      response: "accept",
      voucherIds: requestedVoucherIds
    });

    expect(table.offers[offer.id]).toBeUndefined();
    for (const partId of offeredPartIds) {
      expect(table.dishParts[partId].location).toEqual({ type: "inventory", participantId: to.id });
    }
    for (const voucherId of requestedVoucherIds) {
      expect(table.vouchers[voucherId].location).toEqual({ type: "hand", participantId: from.id });
    }
  });

  it("allows direct offers of promise cards for food pieces", () => {
    const { table } = startAndDeposit(8, "card-for-food-piece-offer");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    completeRecipeBySetup(table, to.id);
    applyAsTurn(table, to.id, { type: "prepare" });
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;
    const requestedPartId = inventoryDishPartIds(table, to.id)[0] as string;
    const requestedPart = table.dishParts[requestedPartId];

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: [{ kind: "voucher", id: offeredVoucherId }],
      requestedAsset: {
        kind: "dish_part",
        dishId: requestedPart.dishId,
        makerParticipantId: requestedPart.makerParticipantId,
        quantity: 1
      }
    });
    const offer = Object.values(table.offers)[0];

    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "offer_lock", offerId: offer.id });

    applyAsTurn(table, to.id, {
      type: "respond_offer",
      offerId: offer.id,
      response: "accept",
      assets: [{ kind: "dish_part", id: requestedPartId }]
    });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: to.id });
    expect(table.dishParts[requestedPartId].location).toEqual({ type: "inventory", participantId: from.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: from.name,
      action: "Exchange",
      counterparty: to.name,
      itemOut: table.vouchers[offeredVoucherId].ingredientId[0].toUpperCase() + table.vouchers[offeredVoucherId].ingredientId.slice(1),
      itemBack: expect.stringContaining(requestedPart.dishName)
    });
  });

  it("allows returning a participant's promise card for any food piece they hold", () => {
    const { table } = startAndDeposit(8, "return-owner-card-for-any-food-piece");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    completeRecipeBySetup(table, to.id);
    applyAsTurn(table, to.id, { type: "prepare" });
    const offeredVoucherId = handVoucherIds(table, to.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === to.id
    ) as string;
    const requestedPartId = inventoryDishPartIds(table, to.id)[0] as string;
    table.vouchers[offeredVoucherId].location = { type: "hand", participantId: from.id };

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: [{ kind: "voucher", id: offeredVoucherId }],
      requestedAsset: { kind: "dish_part", quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];

    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "offer_lock", offerId: offer.id });

    applyAsTurn(table, to.id, {
      type: "respond_offer",
      offerId: offer.id,
      response: "accept",
      assets: [{ kind: "dish_part", id: requestedPartId }]
    });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: to.id });
    expect(table.dishParts[requestedPartId].location).toEqual({ type: "inventory", participantId: from.id });
  });

  it("rejects direct offers that trade the same promise-card resource", () => {
    const { table } = startAndDeposit(8, "reject-same-card-offer");
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, to.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === to.id
    ) as string;
    table.vouchers[offeredVoucherId].location = { type: "hand", participantId: from.id };

    expect(() =>
      applyAsTurn(table, from.id, {
        type: "create_offer",
        toParticipantId: to.id,
        offeredAssets: [{ kind: "voucher", id: offeredVoucherId }],
        requestedAsset: {
          kind: "voucher",
          ingredientId: table.vouchers[offeredVoucherId].ingredientId,
          ownerParticipantId: to.id,
          quantity: 1
        }
      })
    ).toThrow(GameError);
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });
    expect(Object.values(table.offers)).toHaveLength(0);
  });

  it("records successful deposit, swap, exchange, and redemption transactions", () => {
    const { table } = startTable(8, "transactions");
    const [first, second] = activeParticipants(table);
    const firstDeposit = table.transactionHistory.find(
      (transaction) => transaction.participantId === first.id && transaction.action === "Deposit"
    );

    expect(firstDeposit).toMatchObject({
      name: first.name,
      action: "Deposit",
      counterparty: "Platter",
      itemOut: first.ingredientId?.[0].toUpperCase() + (first.ingredientId?.slice(1) ?? ""),
      itemBack: "None"
    });

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
    applyAsTurn(table, second.id, { type: "respond_offer", offerId: offer?.id ?? "", response: "accept", voucherIds: [requestedVoucherId] });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Exchange",
      counterparty: second.name
    });

    const recipe = table.recipes[first.id];
    const requirement = recipe.requirements[0];
    const voucher = moveVoucherToHand(table, first.id, requirement.ingredientId);
    const owner = table.participants[voucher.ownerParticipantId];
    applyAsTurn(table, first.id, { type: "place_voucher", voucherId: voucher.id, requirementId: requirement.id });
    applyAsTurn(table, first.id, { type: "redeem_voucher", voucherId: voucher.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({
      name: first.name,
      action: "Redeem",
      counterparty: owner.name,
      itemBack: `Real ${voucher.ingredientId[0].toUpperCase()}${voucher.ingredientId.slice(1)}`
    });

    const snapshot = buildSnapshot(table, first.id);
    expect(snapshot.transactionHistory).toEqual(table.transactionHistory);
  });

  it("summarizes player turns, cycles, and interaction categories", () => {
    const { table } = startTable(8, "stats");
    const [first] = activeParticipants(table);
    applyAsTurn(table, first.id, { type: "pass_turn" });
    first.realIngredientStock = (first.realIngredientStock ?? table.stockPerIngredient) - 2;
    table.scarcityPressureByIngredient = { cheese: 2 };
    table.transactionHistory.push({
      id: "tx_test_food_piece_settlement",
      turn: table.turn,
      participantId: first.id,
      name: first.name,
      action: "Settlement Swap",
      counterparty: "Platter",
      itemOut: "Flour card 1",
      itemBack: "Cheese Frittata slice"
    });
    for (let index = 0; index < 5; index += 1) {
      table.transactionHistory.push({
        id: `tx_test_eat_${index}`,
        turn: table.turn,
        participantId: first.id,
        name: first.name,
        action: "Eat",
        counterparty: first.name,
        itemOut: `Cheese Frittata slice ${index + 1}`,
        itemBack: "Eaten"
      });
    }

    const stats = computeGameStats(table);
    const snapshot = buildSnapshot(table, first.id);

    expect(stats).toMatchObject({
      activePlayerCount: 8,
      playerTurnCount: 1,
      cycleCount: 0.125,
      openingOfferingCount: 8 * OPENING_OFFERINGS_PER_PLAYER,
      settlementSwapCount: 1,
      foodPieceSettlementSwapCount: 1
    });
    expect(stats.assetLossCount).toBe(2);
    expect(stats.productivityCount).toBe(5);
    expect(stats.profitCount).toBe(3);
    expect(stats.profitGainPercent).toBe(150);
    expect(stats.interactionCount).toBe(table.transactionHistory.length - 1);
    expect(stats.averageTurnsPerDish).toBe(0);
    expect(stats.averageInteractionsPerDish).toBe(0);
    expect(stats.basketVelocity).toBe(8);
    expect(stats.directExchangeShare).toBe(0);
    expect(stats.settlementBurden).toBeCloseTo(1 / stats.interactionCount);
    expect(stats.scarcityPressureByIngredient).toEqual({ cheese: 2 });
    expect(stats.hoardingIndex).toBe(0);
    expect(stats.liquidityDepth).toBeGreaterThan(0);
    expect(stats.settlementTimeTurns).toBe(0);
    expect(stats.consumptionVariance).toBe(0);
    expect(stats.tradeBalanceByParticipant[first.id]).toEqual([1, 1, 0]);
    expect(snapshot.gameStats).toEqual(stats);
  });

  it("includes offered card details in filtered offer snapshots", () => {
    const { table } = startAndDeposit(8);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyAsTurn(table, from.id, {
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

  it("includes asset-offered card details in filtered offer snapshots", () => {
    const { table } = startAndDeposit(8);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredAssets: [{ kind: "voucher", id: offeredVoucherId }],
      requestedAsset: { kind: "voucher", ingredientId: to.ingredientId as string, ownerParticipantId: to.id, quantity: 1 }
    });

    const snapshot = buildSnapshot(table, to.id);
    expect(snapshot.offers).toHaveLength(1);
    expect(snapshot.offers[0].offeredVouchers).toEqual([
      expect.objectContaining({ id: offeredVoucherId, ingredientId: from.ingredientId })
    ]);
    expect(snapshot.offers[0].offeredAssets).toEqual([{ kind: "voucher", id: offeredVoucherId }]);
    expect(snapshot.allHands).toBeUndefined();
  });

  it("unlocks offered cards when offers are refused or cancelled", () => {
    const { table } = startAndDeposit(8);
    const from = activeParticipants(table)[0] as Participant;
    const to = firstOtherActive(table, from.id);
    const offeredVoucherId = handVoucherIds(table, from.id)[0] as string;

    applyAsTurn(table, from.id, {
      type: "create_offer",
      toParticipantId: to.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: to.ingredientId as string, quantity: 1 }
    });
    const refusedOffer = Object.values(table.offers)[0];
    applyAsTurn(table, to.id, { type: "respond_offer", offerId: refusedOffer.id, response: "refuse" });
    expect(table.offers[refusedOffer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: from.id });

    applyAsTurn(table, from.id, {
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
    const { table } = startAndDeposit(8);
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

    applyAsTurn(table, to.id, { type: "respond_offer", offerId: offer.id, response: "refuse" });

    expect(buildSnapshot(table, from.id).offers).toHaveLength(0);
    expect(buildSnapshot(table, to.id).offers).toHaveLength(0);
  });

  it("publishes only own-ingredient offer availability, not hidden hands", () => {
    const { table } = startAndDeposit(8);
    const participant = activeParticipants(table)[0] as Participant;

    const snapshot = buildSnapshot(table, participant.id);
    const publicParticipant = snapshot.participants.find((candidate) => candidate.id === participant.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(publicParticipant?.offerableOwnIngredientQty).toBe(6);
  });

  it("blocks offers when the recipient has no remaining real stock", () => {
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8);
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
    const { table } = startAndDeposit(8);
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

    applyAsTurn(table, sender.id, {
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
    applyAsTurn(table, recipient.id, {
      type: "platter_swap",
      giveVoucherId: lastAvailableVoucherId,
      takeVoucherId
    });

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: sender.id });
    expect(buildSnapshot(table, sender.id).offers).toHaveLength(0);
    expect(buildSnapshot(table, recipient.id).offers).toHaveLength(0);
  });

  it("invalidates a stale offer accepted after requested cards leave the recipient hand", () => {
    const { table } = startAndDeposit(8, "stale-requested-offer-accept");
    const recipient = activeParticipants(table)[0] as Participant;
    const sender = firstOtherActive(table, recipient.id);
    const recipientOwnHand = handVoucherIds(table, recipient.id).filter(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === recipient.id
    );
    const requestedVoucherId = recipientOwnHand[0] as string;
    const offeredVoucherId = handVoucherIds(table, sender.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === sender.id
    ) as string;

    applyAsTurn(table, sender.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
    });
    const offer = Object.values(table.offers)[0];
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "offer_lock", offerId: offer.id });

    const exchangeCountBefore = table.transactionHistory.filter((transaction) => transaction.action === "Exchange").length;
    table.vouchers[requestedVoucherId].location = { type: "platter" };

    expect(() =>
      applyAsTurn(table, recipient.id, {
        type: "respond_offer",
        offerId: offer.id,
        response: "accept",
        voucherIds: [requestedVoucherId]
      })
    ).not.toThrow();

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[offeredVoucherId].location).toEqual({ type: "hand", participantId: sender.id });
    expect(table.vouchers[requestedVoucherId].location).toEqual({ type: "platter" });
    expect(table.transactionHistory.filter((transaction) => transaction.action === "Exchange")).toHaveLength(exchangeCountBefore);
  });

  it("invalidates a stale offer when the offered food piece no longer exists", () => {
    const { table } = startAndDeposit(8, "missing-offered-food-piece");
    const sender = activeParticipants(table)[0] as Participant;
    const recipient = firstOtherActive(table, sender.id);
    completeRecipeBySetup(table, sender.id);
    applyAsTurn(table, sender.id, { type: "prepare" });
    const offeredPartId = inventoryDishPartIds(table, sender.id)[0] as string;
    const requestedVoucherId = handVoucherIds(table, recipient.id).find(
      (voucherId) => table.vouchers[voucherId].ownerParticipantId === recipient.id
    ) as string;
    const requestedVoucher = table.vouchers[requestedVoucherId];

    applyAsTurn(table, sender.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredAssets: [{ kind: "dish_part", id: offeredPartId }],
      requestedAsset: {
        kind: "voucher",
        ingredientId: requestedVoucher.ingredientId,
        ownerParticipantId: requestedVoucher.ownerParticipantId,
        quantity: 1
      }
    });
    const offer = Object.values(table.offers)[0];
    expect(table.dishParts[offeredPartId].location).toEqual({ type: "offer_lock", offerId: offer.id });

    const exchangeCountBefore = table.transactionHistory.filter((transaction) => transaction.action === "Exchange").length;
    delete table.dishParts[offeredPartId];

    expect(() =>
      applyAsTurn(table, recipient.id, {
        type: "respond_offer",
        offerId: offer.id,
        response: "accept",
        assets: [{ kind: "voucher", id: requestedVoucherId }]
      })
    ).not.toThrow();

    expect(table.offers[offer.id]).toBeUndefined();
    expect(table.vouchers[requestedVoucherId].location).toEqual({ type: "hand", participantId: recipient.id });
    expect(table.transactionHistory.filter((transaction) => transaction.action === "Exchange")).toHaveLength(exchangeCountBefore);
  });

  it("reserves requested cards across pending incoming offers", () => {
    const { table } = startAndDeposit(8);
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

    applyAsTurn(table, senderOne.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredVoucherIds: [firstOfferedVoucherId],
      requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
    });

    expect(buildSnapshot(table, senderTwo.id).participants.find((participant) => participant.id === recipient.id)?.offerableOwnIngredientQty).toBe(0);
    table.currentTurnParticipantId = senderTwo.id;
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
    const { table } = startAndDeposit(8);
    const participant = activeParticipants(table)[0] as Participant;
    const snapshot = buildSnapshot(table, participant.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(snapshot.ownHand.every((voucher) => voucher.location.participantId === participant.id)).toBe(true);
  });

  it("filters food-part inventories while allowing witness audits", () => {
    const { store, table } = startAndDeposit(8, "food-part-visibility");
    const [owner, other] = activeParticipants(table);

    completeRecipeBySetup(table, owner.id);
    applyIntent(table, owner.id, { type: "prepare" });
    const partId = inventoryDishPartIds(table, owner.id)[0] as string;

    const ownerSnapshot = buildSnapshot(table, owner.id);
    const otherSnapshot = buildSnapshot(table, other.id);
    const witness = store.joinTable(table.code, "Observer");
    const witnessSnapshot = buildSnapshot(table, witness.participant.id);
    const ownerPublic = ownerSnapshot.participants.find((participant) => participant.id === owner.id);
    const otherPublic = ownerSnapshot.participants.find((participant) => participant.id === other.id);

    expect(ownerSnapshot.ownFoodParts.map((part) => part.id)).toContain(partId);
    expect(ownerSnapshot.dishParts.map((part) => part.id)).toContain(partId);
    expect(otherSnapshot.ownFoodParts.map((part) => part.id)).not.toContain(partId);
    expect(otherSnapshot.dishParts.map((part) => part.id)).not.toContain(partId);
    expect(ownerPublic?.heldFoodPartCount).toBe(DISH_PARTS_PER_DISH);
    expect(otherPublic?.heldFoodPartCount).toBe(0);
    expect(witnessSnapshot.allFoodParts).toBeUndefined();
    expect(witnessSnapshot.dishParts.map((part) => part.id)).not.toContain(partId);
    expect(witnessSnapshot.foodPartLocationSummary).toContainEqual(
      expect.objectContaining({
        dishId: table.dishParts[partId].dishId,
        location: { type: "inventory", participantId: owner.id },
        count: DISH_PARTS_PER_DISH
      })
    );
  });

  it("defaults missing transaction history to an empty snapshot list", () => {
    const { table } = startAndDeposit(8);
    const participant = activeParticipants(table)[0] as Participant;
    delete (table as Partial<Table>).transactionHistory;

    const snapshot = buildSnapshot(table, participant.id);

    expect(snapshot.transactionHistory).toEqual([]);
  });

  it("keeps hidden hands out of bot snapshots and decisions", () => {
    const { table } = makeHarness(7);
    const hostId = table.hostParticipantId;
    const [bot] = addBots(table, hostId, ["mixed"]);
    applyIntent(table, hostId, { type: "start" });
    const snapshot = buildSnapshot(table, bot.id);

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allVouchers).toBeUndefined();
    expect(() => decideBotIntent(table, bot.id)).not.toThrow();
  });

  it("lets witnesses see all hands", () => {
    const { store, table } = startAndDeposit(8);
    const witness = store.joinTable(table.code, "Observer");
    const snapshot = buildSnapshot(table, witness.participant.id);

    expect(witness.participant.role).toBe("witness");
    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(snapshot.allVouchers).toBeUndefined();
    expect(snapshot.allRecipes).toBeDefined();
    expect(snapshot.foodPartLocationSummary).toBeDefined();
    expect(snapshot.voucherLocationSummary).toBeDefined();
    expect(snapshot.voucherLocationSummary?.filter((summary) => summary.location.type === "hand")).not.toHaveLength(0);
  });

  it("keeps running-game witness snapshots compact enough for Godot websocket frames", () => {
    const { store, table } = startAndDeposit(8, "compact-witness");
    const participants = activeParticipants(table);

    for (const participant of participants) {
      completeRecipeBySetup(table, participant.id);
      applyAsTurn(table, participant.id, { type: "prepare" });
    }

    for (let index = 0; index < 180; index += 1) {
      const participant = participants[index % participants.length];
      const giveVoucherId = handVoucherIds(table, participant.id)[0];
      const takeVoucherId = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ownerParticipantId !== participant.id);
      if (giveVoucherId && takeVoucherId) {
        applyAsTurn(table, participant.id, { type: "platter_swap", giveVoucherId, takeVoucherId });
      }
    }

    const witness = store.joinTable(table.code, "Observer");
    const snapshot = buildSnapshot(table, witness.participant.id);
    const payloadBytes = Buffer.byteLength(JSON.stringify({ type: "snapshot", snapshot }), "utf8");

    expect(snapshot.allHands).toBeUndefined();
    expect(snapshot.allFoodParts).toBeUndefined();
    expect(snapshot.dishParts.length).toBe(platterDishPartIds(table).length);
    expect(snapshot.foodPartLocationSummary).toBeDefined();
    expect(snapshot.transactionHistoryComplete).toBe(false);
    expect(snapshot.transactionHistoryTotal).toBe(table.transactionHistory.length);
    expect(snapshot.transactionHistory).toHaveLength(100);
    expect(payloadBytes).toBeLessThan(64 * 1024);
  });

  it("keeps mature reconnect snapshots and normal deltas within load-test budgets", () => {
    const { store, table } = startAndDeposit(8, "payload-budget");
    prepareAllDishesBySetup(table);
    expect(table.phase).toBe("eating");

    const witness = store.joinTable(table.code, "Observer", true);
    const witnessPayloadBytes = Buffer.byteLength(JSON.stringify({ type: "snapshot", snapshot: buildSnapshot(table, witness.participant.id) }), "utf8");
    const participant = activeParticipants(table)[0] as Participant;
    const activePayloadBytes = Buffer.byteLength(JSON.stringify({ type: "snapshot", snapshot: buildSnapshot(table, participant.id) }), "utf8");

    const hub = new ConnectionHub();
    const messages: string[] = [];
    hub.register({
      tableCode: table.code,
      participantId: participant.id,
      send: (payload) => messages.push(payload)
    });
    hub.broadcastTable(table);
    messages.length = 0;

    for (let index = 0; index < 20; index += 1) {
      const part = Object.values(table.dishParts).find(
        (candidate) => candidate.location.type === "inventory" && candidate.location.participantId === participant.id
      );
      if (!part) {
        break;
      }
      applyAsTurn(table, participant.id, { type: "bite", dishId: part.dishId });
      hub.broadcastTable(table);
    }

    const deltaSizes = messages
      .map((payload) => ({ payload, bytes: Buffer.byteLength(payload, "utf8") }))
      .filter(({ payload }) => JSON.parse(payload).type === "delta")
      .map(({ bytes }) => bytes)
      .sort((left, right) => left - right);
    const p95DeltaBytes = deltaSizes[Math.min(deltaSizes.length - 1, Math.ceil(deltaSizes.length * 0.95) - 1)] ?? 0;

    expect(activePayloadBytes).toBeLessThan(64 * 1024);
    expect(witnessPayloadBytes).toBeLessThan(28 * 1024);
    expect(Math.max(...deltaSizes)).toBeLessThan(16 * 1024);
    expect(p95DeltaBytes).toBeLessThan(4 * 1024);
  });

  it("enforces bot channel restrictions", () => {
    const { table } = makeHarness(6);
    const hostId = table.hostParticipantId;
    const [poolOnly, barterOnly] = addBots(table, hostId, ["pool_only", "barter_only"]);
    applyIntent(table, hostId, { type: "start" });

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

  it("has bots batch redeem useful cards from their own hand before ending a turn", () => {
    const { table } = makeHarness(7, "bot-self-redeem");
    const [bot] = addBots(table, table.hostParticipantId, ["mixed"]);
    applyIntent(table, table.hostParticipantId, { type: "start" });
    expect(table.phase).toBe("playing");

    const ownRequirement = table.recipes[bot.id]?.requirements.find(
      (requirement) => requirement.ingredientId === bot.ingredientId
    );
    expect(ownRequirement).toBeDefined();
    expect(ownRequirement?.redeemedQty).toBe(0);

    table.currentTurnParticipantId = bot.id;
    const decisions = runBots(table);

    expect(decisions.some((decision) => decision.intent.type === "redeem_all_and_pass_turn")).toBe(true);
    expect(decisions.some((decision) => decision.intent.type === "place_voucher" || decision.intent.type === "redeem_voucher")).toBe(
      false
    );
    expect(ownRequirement?.redeemedQty).toBe(ownRequirement?.requiredQty);
    expect(ownRequirement?.placedVoucherIds).toHaveLength(0);
  });

  it("has bots trade surplus duplicate cards before turn-ending redemption", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "bot-surplus-before-redeem");
    const table = created.table;
    table.turnMode = "round_robin";
    store.handleIntent(table.code, created.seatToken, { type: "start" }, false);
    const bot = activeParticipants(table).find((participant) => participant.kind === "bot");
    expect(bot).toBeDefined();
    if (!bot) {
      throw new Error("Expected a bot participant");
    }
    table.currentTurnParticipantId = bot.id;

    const decision = decideBotIntent(table, bot.id);
    expect(decision?.intent.type).toBe("platter_swap");
    if (decision?.intent.type !== "platter_swap") {
      throw new Error(`Expected platter_swap, got ${decision?.intent.type ?? "none"}`);
    }
    const give = table.vouchers[decision.intent.giveVoucherId];
    const take = table.vouchers[decision.intent.takeVoucherId];
    expect(give.location).toMatchObject({ type: "hand", participantId: bot.id });
    expect(take.location.type).toBe("platter");
    expect(give.ingredientId).not.toBe(take.ingredientId);
    expect(table.recipes[bot.id]?.requirements.some((requirement) => requirement.ingredientId === take.ingredientId)).toBe(true);
  });

  it("has bots spend dish pieces to take needed cards from the platter", () => {
    const { table } = startAndDeposit(8, "bot-food-piece-for-platter-card");
    const bot = activeParticipantByIngredient(table, "flour");
    bot.kind = "bot";
    bot.botType = "mixed";
    table.currentTurnParticipantId = bot.id;

    const recipe = table.recipes[bot.id];
    expect(recipe).toBeDefined();
    if (!recipe) {
      throw new Error("Expected bot recipe");
    }
    table.recipes[bot.id] = {
      ...recipe,
      requirements: [
        { id: "flour-protected", ingredientId: "flour", requiredQty: 6, redeemedQty: 0, placedVoucherIds: [] },
        { id: "cheese-needed", ingredientId: "cheese", requiredQty: 1, redeemedQty: 0, placedVoucherIds: [] }
      ]
    };
    table.dishParts.bot_food_piece = {
      id: "bot_food_piece",
      dishId: "bot_dish",
      dishName: "Flatbread",
      makerParticipantId: bot.id,
      unitSingular: "slice",
      unitPlural: "slices",
      location: { type: "inventory", participantId: bot.id }
    };

    const decision = decideBotIntent(table, bot.id);
    expect(decision?.intent.type).toBe("platter_asset_swap");
    if (decision?.intent.type !== "platter_asset_swap") {
      throw new Error(`Expected platter_asset_swap, got ${decision?.intent.type ?? "none"}`);
    }
    expect(decision.intent.give).toEqual({ kind: "dish_part", id: "bot_food_piece" });
    expect(decision.intent.take.kind).toBe("voucher");
    expect(table.vouchers[decision.intent.take.id].ingredientId).toBe("cheese");
  });

  it("has bots request the smallest missing ingredient group before duplicate groups", () => {
    const { table } = startAndDeposit(8, "bot-offer-smallest-missing");
    const bot = activeParticipantByIngredient(table, "flour");
    const vegetablesOwner = activeParticipantByIngredient(table, "vegetables");
    bot.kind = "bot";
    bot.botType = "barter_only";
    table.currentTurnParticipantId = bot.id;

    const recipe = table.recipes[bot.id];
    expect(recipe).toBeDefined();
    if (!recipe) {
      throw new Error("Expected bot recipe");
    }
    table.recipes[bot.id] = {
      ...recipe,
      name: "Herb Dumplings",
      requirements: [
        { id: "flour-test", ingredientId: "flour", requiredQty: 2, redeemedQty: 2, placedVoucherIds: [] },
        { id: "herbs-test", ingredientId: "herbs", requiredQty: 2, redeemedQty: 0, placedVoucherIds: [] },
        { id: "vegetables-test", ingredientId: "vegetables", requiredQty: 1, redeemedQty: 0, placedVoucherIds: [] },
        { id: "eggs-test", ingredientId: "eggs", requiredQty: 1, redeemedQty: 1, placedVoucherIds: [] }
      ]
    };

    const decision = decideBotIntent(table, bot.id);
    expect(decision?.intent.type).toBe("create_offer");
    if (decision?.intent.type !== "create_offer") {
      throw new Error(`Expected create_offer, got ${decision?.intent.type ?? "none"}`);
    }
    expect(decision.intent.requestedAsset).toEqual({
      kind: "voucher",
      ingredientId: "vegetables",
      ownerParticipantId: vegetablesOwner.id,
      quantity: 1
    });
  });

  it("has bots offer dish pieces for missing cards when no surplus promise card is available", () => {
    const { table } = startAndDeposit(8, "bot-food-piece-offer");
    const bot = activeParticipantByIngredient(table, "flour");
    const vegetablesOwner = activeParticipantByIngredient(table, "vegetables");
    bot.kind = "bot";
    bot.botType = "barter_only";
    table.currentTurnParticipantId = bot.id;

    const recipe = table.recipes[bot.id];
    expect(recipe).toBeDefined();
    if (!recipe) {
      throw new Error("Expected bot recipe");
    }
    table.recipes[bot.id] = {
      ...recipe,
      requirements: [
        { id: "flour-protected", ingredientId: "flour", requiredQty: 6, redeemedQty: 0, placedVoucherIds: [] },
        { id: "vegetables-needed", ingredientId: "vegetables", requiredQty: 1, redeemedQty: 0, placedVoucherIds: [] }
      ]
    };
    table.dishParts.bot_offer_piece = {
      id: "bot_offer_piece",
      dishId: "bot_dish",
      dishName: "Flatbread",
      makerParticipantId: bot.id,
      unitSingular: "slice",
      unitPlural: "slices",
      location: { type: "inventory", participantId: bot.id }
    };

    const decision = decideBotIntent(table, bot.id);
    expect(decision?.intent.type).toBe("create_offer");
    if (decision?.intent.type !== "create_offer") {
      throw new Error(`Expected create_offer, got ${decision?.intent.type ?? "none"}`);
    }
    expect(decision.intent.offeredAssets).toEqual([{ kind: "dish_part", id: "bot_offer_piece" }]);
    expect(decision.intent.requestedAsset).toEqual({
      kind: "voucher",
      ingredientId: "vegetables",
      ownerParticipantId: vegetablesOwner.id,
      quantity: 1
    });
  });

  it("has goal-complete bots accept incoming offers even without an active recipe", () => {
    const { table } = startAndDeposit(8, "goal-complete-bot-offer");
    const [sender, recipient] = activeParticipants(table);
    recipient.kind = "bot";
    recipient.botType = "mixed";
    recipient.dishCount = table.targetDishCount;
    delete table.recipes[recipient.id];
    const offeredVoucherId = handVoucherIds(table, sender.id)[0] as string;

    applyIntent(table, sender.id, {
      type: "create_offer",
      toParticipantId: recipient.id,
      offeredVoucherIds: [offeredVoucherId],
      requested: { ingredientId: recipient.ingredientId as string, quantity: 1 }
    });

    table.currentTurnParticipantId = recipient.id;
    const decision = decideBotIntent(table, recipient.id);
    expect(decision?.intent).toMatchObject({
      type: "respond_offer",
      response: "accept"
    });
  });

  it("does not let bots act while the table is paused", () => {
    const { table } = makeHarness(7, "bot-paused");
    const [bot] = addBots(table, table.hostParticipantId, ["mixed"]);
    applyIntent(table, table.hostParticipantId, { type: "start" });
    table.paused = true;

    expect(decideBotIntent(table, bot.id)).toBeUndefined();
  });

  it("broadcasts per-viewer filtered snapshots through the connection hub", () => {
    const { table } = startAndDeposit(8);
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

  it("sends a full snapshot first and dirty deltas after successful mutations", () => {
    const { table } = makeHarness(8, "delta-protocol");
    const host = table.participants[table.hostParticipantId];
    const hub = new ConnectionHub();
    const messages: Array<{
      type: string;
      snapshot?: ReturnType<typeof buildSnapshot>;
      patch?: Partial<ReturnType<typeof buildSnapshot>>;
      append?: { transactionHistory?: unknown[]; participants?: unknown[] };
    }> = [];
    hub.register({
      tableCode: table.code,
      participantId: host.id,
      send: (payload) => messages.push(JSON.parse(payload))
    });

    hub.broadcastTable(table);
    expect(messages.at(-1)?.type).toBe("snapshot");
    const firstVersion = messages.at(-1)?.snapshot?.version;

    applyIntent(table, host.id, { type: "set_target_dish_count", count: 2 });
    hub.broadcastTable(table);

    const delta = messages.at(-1);
    expect(delta?.type).toBe("delta");
    expect(delta?.patch?.version).toBe(table.version);
    expect(delta?.patch?.targetDishCount).toBe(2);
    expect(delta?.patch?.participants).toBeUndefined();
    expect(delta?.append?.transactionHistory).toEqual([]);
    expect(table.version).toBeGreaterThan(firstVersion ?? -1);

    applyIntent(table, host.id, { type: "set_role", participantId: host.id, role: "witness" });
    hub.broadcastTable(table);

    const participantDelta = messages.at(-1);
    expect(participantDelta?.type).toBe("delta");
    expect(participantDelta?.patch?.participants).toBeUndefined();
    expect(participantDelta?.append?.participants).toContainEqual(expect.objectContaining({ id: host.id, role: "witness" }));
  });

  it("includes prepared food parts in playing deltas", () => {
    const { table } = startAndDeposit(8, "playing-food-part-delta");
    const participant = activeParticipants(table)[0] as Participant;
    const hub = new ConnectionHub();
    const messages: Array<{
      type: string;
      snapshot?: ReturnType<typeof buildSnapshot>;
      patch?: Partial<ReturnType<typeof buildSnapshot>>;
      append?: { dishes?: unknown[]; transactionHistory?: unknown[] };
    }> = [];
    hub.register({
      tableCode: table.code,
      participantId: participant.id,
      send: (payload) => messages.push(JSON.parse(payload))
    });

    hub.broadcastTable(table);
    messages.length = 0;

    completeRecipeBySetup(table, participant.id);
    applyAsTurn(table, participant.id, { type: "prepare" });
    expect(table.phase).toBe("playing");

    hub.broadcastTable(table);

    const delta = messages.at(-1);
    expect(delta?.type).toBe("delta");
    expect(delta?.patch?.ownFoodParts).toHaveLength(DISH_PARTS_PER_DISH);
    expect(delta?.patch?.ownFoodPartGroups).toContainEqual(
      expect.objectContaining({
        makerParticipantId: participant.id,
        count: DISH_PARTS_PER_DISH
      })
    );
    expect(delta?.append?.dishes).toContainEqual(expect.objectContaining({ ownerParticipantId: participant.id }));
  });

  it("sends a full snapshot to a reconnected socket", () => {
    const { table } = makeHarness(8, "delta-reconnect");
    const host = table.participants[table.hostParticipantId];
    const hub = new ConnectionHub();
    const firstMessages: unknown[] = [];
    const firstConnection = hub.register({
      tableCode: table.code,
      participantId: host.id,
      send: (payload) => firstMessages.push(JSON.parse(payload))
    });
    hub.broadcastTable(table);
    hub.unregister(table.code, firstConnection.id);

    const reconnectMessages: Array<{ type: string }> = [];
    hub.register({
      tableCode: table.code,
      participantId: host.id,
      send: (payload) => reconnectMessages.push(JSON.parse(payload))
    });
    hub.broadcastTable(table);

    expect(reconnectMessages.at(-1)?.type).toBe("snapshot");
  });

  it("detects duplicate sockets by connection participant, not viewed participant", () => {
    const { table } = makeHarness(8, "duplicate-socket-seat");
    const host = table.participants[table.hostParticipantId];
    const viewed = activeParticipants(table).find((participant) => participant.id !== host.id) as Participant;
    const hub = new ConnectionHub();

    hub.register({
      tableCode: table.code,
      participantId: viewed.id,
      connectionParticipantId: host.id,
      send: () => undefined
    });

    expect(hub.hasConnectionForParticipant(table.code, host.id)).toBe(true);
    expect(hub.hasConnectionForParticipant(table.code, viewed.id)).toBe(false);
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

  it("reconnects a joined online player to the same active seat and hand", () => {
    const store = new TableStore();
    const created = store.createTable("Host", "online-rejoin-same-seat");
    const joined = store.joinTable(created.table.code, "Ravi");
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    const firstSnapshot = store.getSnapshotByToken(created.table.code, joined.seatToken);
    const firstHand = firstSnapshot.ownHand.map((voucher) => voucher.id).sort();

    store.disconnectParticipantByToken(created.table.code, joined.seatToken);
    expect(created.table.participants[joined.participant.id].connected).toBe(false);

    const rejoinedSnapshot = store.getSnapshotByToken(created.table.code, joined.seatToken);
    const rejoinedHand = rejoinedSnapshot.ownHand.map((voucher) => voucher.id).sort();

    expect(rejoinedSnapshot.viewerParticipantId).toBe(joined.participant.id);
    expect(rejoinedSnapshot.connectionParticipantId).toBe(joined.participant.id);
    expect(rejoinedSnapshot.viewerRole).toBe("active");
    expect(rejoinedSnapshot.participants.find((participant) => participant.id === joined.participant.id)).toMatchObject({
      id: joined.participant.id,
      name: "Ravi",
      kind: "human",
      role: "active",
      connected: true
    });
    expect(rejoinedHand).toEqual(firstHand);
    expect(rejoinedHand).toHaveLength(VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER);
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
      name: "Rav_b"
    });
    expect(created.table.participants[disconnected.participant.id]).toMatchObject({
      kind: "bot",
      botType: "mixed",
      connected: false,
      name: "Lin_b"
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
    const { store, table } = startAndDeposit(8);
    const witness = store.joinTable(table.code, "Observer");
    expect(witness.participant.role).toBe("witness");

    store.disconnectParticipantByToken(table.code, witness.seatToken);

    expect(table.participants[witness.participant.id].kind).toBe("human");
    expect(table.participants[witness.participant.id].connected).toBe(false);
  });
});

describe("winning and eating", () => {
  it("keeps cooking after everyone has one dish when the dish goal is the default 3", () => {
    const { table } = startAndDeposit(8, "default-three-dishes");

    for (const participant of activeParticipants(table)) {
      completeRecipeBySetup(table, participant.id);
      applyAsTurn(table, participant.id, { type: "prepare" });
    }

    expect(table.targetDishCount).toBe(DEFAULT_TARGET_DISH_COUNT);
    expect(table.phase).toBe("playing");
    expect(table.winnerParticipantIds).toHaveLength(0);
    for (const participant of activeParticipants(table)) {
      expect(participant.dishCount).toBe(1);
      expect(table.recipes[participant.id]).toBeDefined();
    }
  });

  it("enters eating after everyone reaches the configured dish goal when accounts are clear", () => {
    const harness = makeHarness(8, "one-dish-goal");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);

    const participants = activeParticipants(harness.table);
    for (const participant of participants.slice(0, -1)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
      expect(harness.table.phase).toBe("playing");
    }

    const finalParticipant = participants.at(-1) as Participant;
    completeRecipeBySetup(harness.table, finalParticipant.id);
    applyAsTurn(harness.table, finalParticipant.id, { type: "prepare" });

    expect(harness.table.phase).toBe("eating");
    expect(harness.table.winnerParticipantIds).toHaveLength(8);
    for (const participant of participants) {
      expect(harness.table.recipes[participant.id]).toBeUndefined();
      expect(platterAccountForParticipant(harness.table, participant.id).cleared).toBe(true);
    }
  });

  it("lets the host pause and resume while blocking gameplay actions", () => {
    const { store, table, hostToken } = startAndDeposit(8);
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
    const { store, table, hostToken } = makeHarness(8, "pause-timer");
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

  it("prompts idle lobby tables after thirty minutes and continues when a player answers yes", () => {
    const { store, table, hostToken } = makeHarness(8, "idle-lobby");
    table.idle.lastActivityAtMs = 1000;

    expect(store.advanceIdle(table.code, 1000 + 30 * 60 * 1000 - 1)).toBe(false);
    expect(store.advanceIdle(table.code, 1000 + 30 * 60 * 1000)).toBe(true);
    expect(table.idle.prompt).toMatchObject({
      message: "Are you still cooking?",
      phase: "lobby"
    });
    expect(table.idle.prompt?.expiresAtMs).toBe(1000 + 60 * 60 * 1000);
    const promptId = table.idle.prompt?.id as string;

    store.handleIntent(table.code, hostToken, { type: "idle_response", promptId, response: "yes" }, false);

    expect(table.phase).toBe("lobby");
    expect(table.idle.prompt).toBeUndefined();
    expect(table.idle.closure).toBeUndefined();
  });

  it("prompts idle running games after thirty minutes", () => {
    const { store, table } = startAndDeposit(8, "idle-running");
    table.idle.lastActivityAtMs = 2000;

    expect(store.advanceIdle(table.code, 2000 + 30 * 60 * 1000 - 1)).toBe(false);
    expect(store.advanceIdle(table.code, 2000 + 30 * 60 * 1000)).toBe(true);

    expect(table.idle.prompt).toMatchObject({
      message: "Are you still cooking?",
      phase: "running"
    });
    expect(table.idle.prompt?.expiresAtMs).toBe(2000 + 60 * 60 * 1000);
  });

  it("closes an idle table when someone answers no", () => {
    const { store, table, hostToken } = startAndDeposit(8, "idle-no");
    table.idle.lastActivityAtMs = 3000;
    store.advanceIdle(table.code, 3000 + 30 * 60 * 1000);
    const promptId = table.idle.prompt?.id as string;

    store.handleIntent(table.code, hostToken, { type: "idle_response", promptId, response: "no" }, false);

    expect(table.phase).toBe("complete");
    expect(table.idle.closure).toMatchObject({
      reason: "idle_declined",
      message: "The table closed because someone stopped cooking."
    });
    expect(buildSnapshot(table, table.hostParticipantId).tableClosure?.reason).toBe("idle_declined");
  });

  it("closes an idle table when no one answers the prompt", () => {
    const { store, table } = startAndDeposit(8, "idle-timeout");
    table.idle.lastActivityAtMs = 4000;
    store.advanceIdle(table.code, 4000 + 30 * 60 * 1000);
    const expiresAtMs = table.idle.prompt?.expiresAtMs as number;

    expect(store.advanceIdle(table.code, expiresAtMs - 1)).toBe(false);
    expect(store.advanceIdle(table.code, expiresAtMs)).toBe(true);

    expect(table.phase).toBe("complete");
    expect(table.idle.closure).toMatchObject({
      reason: "idle_timeout",
      message: "The table closed because no one answered."
    });
  });

  it("only lets the host end the game for everyone", () => {
    const { table } = startAndDeposit(8);
    const nonHost = activeParticipants(table).find((participant) => participant.id !== table.hostParticipantId) as Participant;

    expect(() => applyIntent(table, nonHost.id, { type: "stop" })).toThrow(GameError);
    expect(table.phase).toBe("playing");
  });

  it("settles platter debt and shortfall with 1:1 card and food-part swaps", () => {
    const harness = makeHarness(8, "settlement-swaps");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);

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
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    expect(harness.table.phase).toBe("settlement");
    expect(platterAccountForParticipant(harness.table, debtor.id)).toMatchObject({ ownCardsInPlatter: 3, platterDebt: 1, cleared: false });
    expect(platterAccountForParticipant(harness.table, shortfall.id)).toMatchObject({
      ownCardsInPlatter: 1,
      platterShortfall: 1,
      cleared: false
    });

    const debtorPartId = inventoryDishPartIds(harness.table, debtor.id)[0] as string;
    const debtorOwnPlatterVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === debtor.id
    ) as string;
    applyAsTurn(harness.table, debtor.id, {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: debtorPartId },
      take: { kind: "voucher", id: debtorOwnPlatterVoucher }
    });

    expect(platterAccountForParticipant(harness.table, debtor.id).cleared).toBe(true);
    expect(platterDishPartIds(harness.table)).toEqual([debtorPartId]);
    expect(harness.table.transactionHistory.at(-1)).toMatchObject({ name: debtor.name, action: "Settlement Swap" });

    applyAsTurn(harness.table, shortfall.id, {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: shortfallVoucher },
      take: { kind: "dish_part", id: debtorPartId }
    });

    expect(platterAccountForParticipant(harness.table, shortfall.id).cleared).toBe(true);
    expect(platterDishPartIds(harness.table)).toHaveLength(0);
    expect(harness.table.phase).toBe("eating");
    expect(harness.table.dishParts[debtorPartId].location).toEqual({ type: "inventory", participantId: shortfall.id });
  });

  it("requires every promise card to return to its owner before eating", () => {
    const harness = makeHarness(8, "settlement-card-return");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);

    const [holder, owner] = activeParticipants(harness.table);
    const ownerCardInOwnerHand = handVoucherIds(harness.table, owner.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === owner.id
    ) as string;
    harness.table.vouchers[ownerCardInOwnerHand].location = { type: "hand", participantId: holder.id };

    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    expect(harness.table.phase).toBe("settlement");
    expect(platterAccountForParticipant(harness.table, holder.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER,
      foreignCardsInHand: 1,
      cleared: false
    });
    expect(platterAccountForParticipant(harness.table, owner.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER - 1,
      ownCardsInOtherHands: 1,
      cleared: false
    });

    const ownerPartId = inventoryDishPartIds(harness.table, owner.id)[0] as string;
    const ownerPlatterVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === owner.id
    ) as string;
    applyAsTurn(harness.table, owner.id, {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: ownerPartId },
      take: { kind: "voucher", id: ownerPlatterVoucher }
    });

    expect(platterAccountForParticipant(harness.table, owner.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER - 1,
      platterShortfall: 1,
      ownCardsInOtherHands: 1,
      cleared: false
    });
    expect(platterDishPartIds(harness.table)).toEqual([ownerPartId]);

    applyAsTurn(harness.table, holder.id, {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: ownerCardInOwnerHand },
      take: { kind: "dish_part", id: ownerPartId }
    });

    expect(platterAccountForParticipant(harness.table, holder.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER,
      foreignCardsInHand: 0,
      cleared: true
    });
    expect(platterAccountForParticipant(harness.table, owner.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInOtherHands: 0,
      cleared: true
    });
    expect(platterDishPartIds(harness.table)).toHaveLength(0);
    expect(harness.table.phase).toBe("eating");
  });

  it("blocks invalid settlement swaps without mutation", () => {
    const { table } = startAndDeposit(8, "invalid-settlement");
    const [participant] = activeParticipants(table);
    completeRecipeBySetup(table, participant.id);
    applyAsTurn(table, participant.id, { type: "prepare" });
    table.phase = "settlement";
    const partId = inventoryDishPartIds(table, participant.id)[0] as string;
    const platterVoucherId = platterVoucherIds(table)[0] as string;
    table.currentTurnParticipantId = participant.id;
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
    const { table } = startAndDeposit(8, "any-card-for-food-part");
    const [participant, other] = activeParticipants(table);
    completeRecipeBySetup(table, participant.id);
    applyAsTurn(table, participant.id, { type: "prepare" });
    table.phase = "settlement";
    const partId = inventoryDishPartIds(table, participant.id)[0] as string;
    table.dishParts[partId].location = { type: "platter" };
    const nonOwnVoucher = moveVoucherToHand(table, participant.id, other.ingredientId as string);

    applyAsTurn(table, participant.id, {
      type: "platter_asset_swap",
      give: { kind: "voucher", id: nonOwnVoucher.id },
      take: { kind: "dish_part", id: partId }
    });

    expect(table.vouchers[nonOwnVoucher.id].location).toEqual({ type: "platter" });
    expect(table.dishParts[partId].location).toEqual({ type: "inventory", participantId: participant.id });
    expect(table.transactionHistory.at(-1)).toMatchObject({ name: participant.name, action: "Settlement Swap" });
  });

  it("only lets cleared players eat food parts they hold", () => {
    const harness = makeHarness(8, "eat-owned-parts");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const [owner, other] = activeParticipants(harness.table);
    const ownerDish = Object.values(harness.table.dishes).find((dish) => dish.ownerParticipantId === owner.id);
    if (!ownerDish) {
      throw new Error("Missing owner dish");
    }
    expect(() => applyAsTurn(harness.table, other.id, { type: "bite", dishId: ownerDish.id })).toThrow(GameError);

    applyAsTurn(harness.table, owner.id, { type: "bite", dishId: ownerDish.id });

    const updatedDish = harness.table.dishes[ownerDish.id];
    const snapshotAfterBite = buildSnapshot(harness.table, owner.id);
    const ownerPublicAfterBite = snapshotAfterBite.participants.find((participant) => participant.id === owner.id);
    expect(updatedDish.partsRemaining).toBe(DISH_PARTS_PER_DISH - 1);
    expect(updatedDish.bitesRemaining).toBe(DISH_PARTS_PER_DISH - 1);
    expect(updatedDish.biteCounts[owner.id]).toBe(1);
    expect(ownerPublicAfterBite?.heldFoodPartCount).toBe(DISH_PARTS_PER_DISH - 1);
    expect(harness.table.transactionHistory.at(-1)).toMatchObject({ name: owner.name, action: "Eat" });
  });

  it("lets a cleared player eat all held food parts at once without turn gating", () => {
    const harness = makeHarness(8, "eat-all-held-parts");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const [owner, other] = activeParticipants(harness.table);
    const heldBefore = inventoryDishPartIds(harness.table, owner.id);
    harness.table.currentTurnParticipantId = other.id;

    applyIntent(harness.table, owner.id, { type: "bite_all" });

    expect(heldBefore.length).toBe(DISH_PARTS_PER_DISH);
    expect(inventoryDishPartIds(harness.table, owner.id)).toHaveLength(0);
    for (const partId of heldBefore) {
      expect(harness.table.dishParts[partId].location).toEqual({ type: "eaten", participantId: owner.id });
    }
    const ownerBites = Object.values(harness.table.dishes).reduce((total, dish) => total + (dish.biteCounts[owner.id] ?? 0), 0);
    expect(ownerBites).toBe(DISH_PARTS_PER_DISH);
    expect(harness.table.transactionHistory.filter((row) => row.name === owner.name && row.action === "Eat")).toHaveLength(DISH_PARTS_PER_DISH);
    const nextEaterId = harness.table.currentTurnParticipantId;
    expect(nextEaterId).toBeDefined();
    expect(nextEaterId).not.toBe(owner.id);
    expect(inventoryDishPartIds(harness.table, nextEaterId ?? "")).not.toHaveLength(0);
  });

  it("has bots settle accounts and eat held food parts deterministically", () => {
    const harness = makeHarness(1, "bot-settlement-eating");
    addBots(harness.table, harness.table.hostParticipantId, ["mixed", "mixed", "mixed", "mixed", "mixed", "mixed", "mixed"]);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    harness.table.currentTurnParticipantId = activeParticipants(harness.table).find((participant) => participant.kind === "bot")?.id;
    const decisions = runBots(harness.table, 40).filter((decision) => decision.intent.type === "bite_all");

    expect(harness.table.phase).toBe("eating");
    expect(decisions.length).toBeGreaterThan(0);
    expect(Object.values(harness.table.dishes).some((dish) => dish.partsRemaining < DISH_PARTS_PER_DISH)).toBe(true);
  });

  it("has a settlement bot offer food for its own stranded promise card", () => {
    const harness = makeHarness(1, "bot-settlement-no-deposit-loop");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    const host = harness.table.participants[harness.table.hostParticipantId];
    const bot = activeParticipants(harness.table).find((participant) => participant.kind === "bot") as Participant;
    const botOwnHandVoucher = handVoucherIds(harness.table, bot.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === bot.id
    ) as string;
    harness.table.vouchers[botOwnHandVoucher].location = { type: "hand", participantId: host.id };

    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    harness.table.currentTurnParticipantId = bot.id;
    expect(platterAccountForParticipant(harness.table, bot.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInOtherHands: 1,
      cleared: false
    });

    const decision = decideBotIntent(harness.table, bot.id);

    expect(decision?.intent).toMatchObject({
      type: "create_offer",
      toParticipantId: host.id,
      offeredAssets: [{ kind: "dish_part" }],
      requestedAsset: { kind: "voucher", ingredientId: bot.ingredientId, ownerParticipantId: bot.id, quantity: 1 }
    });
    expect(platterDishPartIds(harness.table)).toHaveLength(0);
  });

  it("has settlement bots fill a platter shortfall with an extra own promise card", () => {
    const harness = makeHarness(1, "bot-settlement-shortfall-extra-own-card");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    const host = harness.table.participants[harness.table.hostParticipantId];
    const bot = activeParticipants(harness.table).find((participant) => participant.kind === "bot") as Participant;

    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const botOwnPlatterVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === bot.id
    ) as string;
    const hostFoodPart = inventoryDishPartIds(harness.table, host.id)[0] as string;
    harness.table.vouchers[botOwnPlatterVoucher].location = { type: "hand", participantId: bot.id };
    harness.table.dishParts[hostFoodPart].location = { type: "platter" };
    harness.table.phase = "settlement";
    harness.table.currentTurnParticipantId = bot.id;

    expect(platterAccountForParticipant(harness.table, bot.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER - 1,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER + 1,
      platterShortfall: 1,
      cleared: false
    });

    const decision = decideBotIntent(harness.table, bot.id);

    expect(decision?.intent).toEqual({
      type: "platter_asset_swap",
      give: { kind: "voucher", id: botOwnPlatterVoucher },
      take: { kind: "dish_part", id: hostFoodPart }
    });
    applyIntent(harness.table, bot.id, decision?.intent ?? { type: "pass_turn" });
    expect(platterAccountForParticipant(harness.table, bot.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInHand: VOUCHERS_PER_INGREDIENT - OPENING_OFFERINGS_PER_PLAYER,
      platterShortfall: 0,
      cleared: true
    });
  });

  it("has settlement bots prefer direct return over reversible platter food swaps", () => {
    const harness = makeHarness(1, "bot-settlement-return-foreign-any-piece");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    const [owner, holder, third] = activeParticipants(harness.table);
    holder.kind = "bot";
    holder.botType = "mixed";
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const ownerHandVoucher = handVoucherIds(harness.table, owner.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === owner.id
    ) as string;
    const thirdFoodPart = inventoryDishPartIds(harness.table, third.id)[0] as string;
    harness.table.vouchers[ownerHandVoucher].location = { type: "hand", participantId: holder.id };
    harness.table.dishParts[thirdFoodPart].location = { type: "platter" };
    harness.table.phase = "settlement";
    harness.table.currentTurnParticipantId = holder.id;

    expect(platterAccountForParticipant(harness.table, owner.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER,
      ownCardsInOtherHands: 1,
      cleared: false
    });
    expect(platterAccountForParticipant(harness.table, holder.id)).toMatchObject({
      foreignCardsInHand: 1,
      cleared: false
    });

    const decision = decideBotIntent(harness.table, holder.id);

    expect(decision?.intent).toEqual({
      type: "create_offer",
      toParticipantId: owner.id,
      offeredVoucherIds: [ownerHandVoucher],
      requestedAsset: { kind: "dish_part", quantity: 1 }
    });
    applyIntent(harness.table, holder.id, decision?.intent ?? { type: "pass_turn" });
    const offerId = Object.keys(harness.table.offers)[0] as string;
    const ownerFoodPart = inventoryDishPartIds(harness.table, owner.id)[0] as string;
    harness.table.currentTurnParticipantId = owner.id;
    applyIntent(harness.table, owner.id, {
      type: "respond_offer",
      offerId,
      response: "accept",
      assets: [{ kind: "dish_part", id: ownerFoodPart }]
    });
    expect(harness.table.dishParts[thirdFoodPart].location).toEqual({ type: "platter" });
    expect(platterAccountForParticipant(harness.table, holder.id)).toMatchObject({ foreignCardsInHand: 0, cleared: true });
    expect(platterAccountForParticipant(harness.table, owner.id)).toMatchObject({ ownCardsInOtherHands: 0, cleared: true });
  });

  it("has settlement bots offer a stranded foreign card directly for any held food piece", () => {
    const harness = makeHarness(1, "bot-settlement-direct-offer-food-piece");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    const [owner, holder] = activeParticipants(harness.table);
    holder.kind = "bot";
    holder.botType = "mixed";
    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const ownerHandVoucher = handVoucherIds(harness.table, owner.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === owner.id
    ) as string;
    const ownerFoodPart = inventoryDishPartIds(harness.table, owner.id)[0] as string;
    harness.table.vouchers[ownerHandVoucher].location = { type: "hand", participantId: holder.id };
    harness.table.phase = "settlement";
    harness.table.currentTurnParticipantId = holder.id;

    const decision = decideBotIntent(harness.table, holder.id);

    expect(decision?.intent).toEqual({
      type: "create_offer",
      toParticipantId: owner.id,
      offeredVoucherIds: [ownerHandVoucher],
      requestedAsset: { kind: "dish_part", quantity: 1 }
    });
    applyIntent(harness.table, holder.id, decision?.intent ?? { type: "pass_turn" });
    const offerId = Object.keys(harness.table.offers)[0] as string;
    expect(harness.table.vouchers[ownerHandVoucher].location).toEqual({ type: "offer_lock", offerId });

    harness.table.currentTurnParticipantId = owner.id;
    applyIntent(harness.table, owner.id, {
      type: "respond_offer",
      offerId,
      response: "accept",
      assets: [{ kind: "dish_part", id: ownerFoodPart }]
    });

    expect(harness.table.vouchers[ownerHandVoucher].location).toEqual({ type: "hand", participantId: owner.id });
    expect(harness.table.dishParts[ownerFoodPart].location).toEqual({ type: "inventory", participantId: holder.id });
    expect(platterAccountForParticipant(harness.table, owner.id).cleared).toBe(true);
    expect(platterAccountForParticipant(harness.table, holder.id).cleared).toBe(true);
    expect(harness.table.phase).toBe("eating");
  });

  it("has settlement bots recover own stranded cards before seeding basket food", () => {
    const harness = makeHarness(1, "bot-settlement-seed-food-for-food");
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "set_target_dish_count", count: 1 }, false);
    harness.store.handleIntent(harness.table.code, harness.hostToken, { type: "start" }, false);
    const host = harness.table.participants[harness.table.hostParticipantId];
    const bot = activeParticipants(harness.table).find((participant) => participant.kind === "bot") as Participant;

    for (const participant of activeParticipants(harness.table)) {
      completeRecipeBySetup(harness.table, participant.id);
      applyAsTurn(harness.table, participant.id, { type: "prepare" });
    }

    const botOwnHandVoucher = handVoucherIds(harness.table, bot.id).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === bot.id
    ) as string;
    const botOwnPlatterVoucher = platterVoucherIds(harness.table).find(
      (voucherId) => harness.table.vouchers[voucherId].ownerParticipantId === bot.id
    ) as string;
    const hostFoodPart = inventoryDishPartIds(harness.table, host.id)[0] as string;
    harness.table.vouchers[botOwnHandVoucher].location = { type: "hand", participantId: host.id };
    harness.table.vouchers[botOwnPlatterVoucher].location = { type: "hand", participantId: host.id };
    harness.table.dishParts[hostFoodPart].location = { type: "platter" };
    harness.table.phase = "settlement";
    harness.table.currentTurnParticipantId = bot.id;

    expect(platterAccountForParticipant(harness.table, bot.id)).toMatchObject({
      ownCardsInPlatter: OPENING_OFFERINGS_PER_PLAYER - 1,
      platterShortfall: 1,
      ownCardsInOtherHands: 2,
      cleared: false
    });

    const decision = decideBotIntent(harness.table, bot.id);

    expect(decision?.intent).toMatchObject({
      type: "create_offer",
      toParticipantId: host.id,
      offeredAssets: [{ kind: "dish_part" }],
      requestedAsset: { kind: "voucher", ingredientId: bot.ingredientId, ownerParticipantId: bot.id, quantity: 1 }
    });
    expect(platterDishPartIds(harness.table)).toEqual([hostFoodPart]);
  });

  it("expires a configured timer into settlement instead of bypassing accountability", () => {
    const { store, table, hostToken } = makeHarness(8);
    store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 1 }, false);
    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    const winner = activeParticipants(table)[0] as Participant;
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
    expect(activeParticipants(created.table)).toHaveLength(8);
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
    const { store, table, hostToken } = makeHarness(8, "close-reset");
    const participantIds = [...table.participantOrder];
    const requiredStock = minimumBackedStockForPlayerCount(8, 2);
    store.handleIntent(table.code, hostToken, { type: "set_timer", seconds: 60 }, false);
    store.handleIntent(table.code, hostToken, { type: "set_target_dish_count", count: 2 }, false);
    store.handleIntent(table.code, hostToken, { type: "set_stock", count: requiredStock }, false);
    store.handleIntent(table.code, hostToken, { type: "start" }, false);
    expect(table.phase).toBe("playing");

    store.handleIntent(table.code, hostToken, { type: "close_table" }, false);
    expect(table.phase).toBe("complete");
    expect(table.idle.closure).toMatchObject({
      reason: "host_stopped",
      message: "Host has stopped cooking."
    });
    expect(buildSnapshot(table, table.hostParticipantId).tableClosure?.reason).toBe("host_stopped");
    expect(table.timer?.seconds).toBe(60);
    expect(table.timer?.endsAtMs).toBeUndefined();

    store.handleIntent(table.code, hostToken, { type: "reset_table" }, false);
    expect(table.phase).toBe("lobby");
    expect(table.idle.closure).toBeUndefined();
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
      expect(participant.openingOfferingsCount).toBe(0);
      expect(participant.ingredientId).toBeDefined();
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
    expect(snapshot.participants).toHaveLength(8);
    expect(snapshot.participants.find((participant) => participant.name === "Ben")?.kind).toBe("human");
    await app.close();
  });

  it("rejects a second websocket for the same seat token", async () => {
    const store = new TableStore();
    const hub = new ConnectionHub();
    const app = await buildApp({ store, hub });
    const created = store.createTable("Host", "duplicate-host-socket");
    await app.ready();

    const firstSocket = await app.injectWS(`/tables/${created.table.code}/socket?seatToken=${created.seatToken}`);
    expect(hub.connectionCount(created.table.code)).toBe(1);
    expect(hub.hasConnectionForParticipant(created.table.code, created.participant.id)).toBe(true);

    const secondSocket = await app.injectWS(`/tables/${created.table.code}/socket?seatToken=${created.seatToken}`);
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(hub.connectionCount(created.table.code)).toBe(1);

    firstSocket.terminate();
    secondSocket.terminate();
    await app.close();
  });

  it("exports the full transaction history as authorized CSV", async () => {
    const store = new TableStore();
    const app = await buildApp({ store });
    const created = store.createTable("Host", "csv-export");
    for (let index = 0; index < 7; index += 1) {
      store.joinTable(created.table.code, `Player ${index + 2}`);
    }
    store.handleIntent(created.table.code, created.seatToken, { type: "start" }, false);

    const response = await app.inject({
      method: "GET",
      url: `/tables/${created.table.code}/transactions.csv?seatToken=${created.seatToken}`
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/csv");
    expect(response.body).toContain("Turn,Name,Action,Counterparty,Item out,Item back");
    expect(response.body).toContain("Deposit");

    const forbidden = await app.inject({
      method: "GET",
      url: `/tables/${created.table.code}/transactions.csv?seatToken=bad-token`
    });
    expect(forbidden.statusCode).toBe(400);
    await app.close();
  });

  it("periodically sweeps idle public and private tables that missed per-table scheduling", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(0);
    const store = new TableStore();
    const app = await buildApp({ store });
    try {
      const publicTable = store.createTable("Public Host", "idle-sweep-public", "sweep1", true);
      const privateTable = store.createTable("Private Host", "idle-sweep-private", "sweep2", false);
      publicTable.table.idle.lastActivityAtMs = 0;
      privateTable.table.idle.lastActivityAtMs = 0;

      expect(publicTable.table.idle.prompt).toBeUndefined();
      expect(privateTable.table.idle.prompt).toBeUndefined();

      vi.setSystemTime(30 * 60 * 1000);
      await vi.advanceTimersByTimeAsync(60 * 1000);

      expect(publicTable.table.idle.prompt).toMatchObject({ phase: "lobby" });
      expect(privateTable.table.idle.prompt).toMatchObject({ phase: "lobby" });
    } finally {
      await app.close();
      vi.useRealTimers();
    }
  });
});

describe("determinism", () => {
  it("generates repeatable recipes from the same seed", () => {
    const first = startTable(8, "same-seed").table;
    const second = startTable(8, "same-seed").table;
    const firstRecipes = Object.values(first.recipes).map((recipe) =>
      recipe.requirements.map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    );
    const secondRecipes = Object.values(second.recipes).map((recipe) =>
      recipe.requirements.map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    );

    expect(firstRecipes).toEqual(secondRecipes);
  });

  it("makes deterministic bot decisions from the same seed and state", () => {
    const first = makeHarness(1, "bot-seed");
    const second = makeHarness(1, "bot-seed");
    const firstBot = addBots(first.table, first.table.hostParticipantId, ["mixed"])[0];
    const secondBot = addBots(second.table, second.table.hostParticipantId, ["mixed"])[0];
    applyIntent(first.table, first.table.hostParticipantId, { type: "start" });
    applyIntent(second.table, second.table.hostParticipantId, { type: "start" });

    expect(decideBotIntent(first.table, firstBot.id)).toEqual(decideBotIntent(second.table, secondBot.id));
  });
});
