import websocket from "@fastify/websocket";
import Fastify, { type FastifyInstance } from "fastify";
import { z } from "zod";
import { MAX_STOCK_PER_INGREDIENT, MAX_TARGET_DISH_COUNT, MIN_STOCK_PER_INGREDIENT, MIN_TARGET_DISH_COUNT } from "./constants.js";
import { GameError } from "./game.js";
import { ConnectionHub, type HubConnection } from "./hub.js";
import { TableStore } from "./store.js";
import { transactionsToCsv } from "./transactions.js";
import type { Intent } from "./types.js";

const createTableSchema = z.object({
  hostName: z.string().max(40).default(""),
  seed: z.string().min(1).max(120).optional(),
  requestedCode: z.string().min(4).max(24).optional(),
  isPublic: z.boolean().default(true)
});

const joinTableSchema = z.object({
  name: z.string().max(40).default(""),
  asWitness: z.boolean().default(false)
});

const aggregateAssetRefSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("voucher"), ingredientId: z.string(), ownerParticipantId: z.string().optional() }),
  z.object({ kind: z.literal("dish_part"), dishId: z.string(), makerParticipantId: z.string().optional() })
]);

const exactAssetRefSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("voucher"), id: z.string() }),
  z.object({ kind: z.literal("dish_part"), id: z.string() })
]);

const offerAssetRequestSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("voucher"),
    ingredientId: z.string(),
    ownerParticipantId: z.string().optional(),
    quantity: z.number().int().positive()
  }),
  z.object({
    kind: z.literal("dish_part"),
    dishId: z.string().optional(),
    makerParticipantId: z.string().optional(),
    quantity: z.number().int().positive()
  })
]);

const intentSchema: z.ZodType<Intent> = z.discriminatedUnion("type", [
  z.object({ type: z.literal("leave_table") }),
  z.object({ type: z.literal("close_table") }),
  z.object({ type: z.literal("reset_table") }),
  z.object({ type: z.literal("idle_response"), promptId: z.string().min(1).max(120), response: z.enum(["yes", "no"]) }),
  z.object({ type: z.literal("set_table_visibility"), isPublic: z.boolean() }),
  z.object({ type: z.literal("set_role"), participantId: z.string(), role: z.enum(["active", "witness"]) }),
  z.object({ type: z.literal("rename_participant"), participantId: z.string(), name: z.string().max(40) }),
  z.object({ type: z.literal("add_bot"), name: z.string().optional(), botType: z.enum(["pool_only", "barter_only", "mixed"]) }),
  z.object({ type: z.literal("add_controlled_seat"), name: z.string().optional(), participantId: z.string().optional() }),
  z.object({ type: z.literal("convert_to_bot"), participantId: z.string(), botType: z.enum(["pool_only", "barter_only", "mixed"]).optional() }),
  z.object({ type: z.literal("set_timer"), seconds: z.number().int().positive().nullable() }),
  z.object({ type: z.literal("set_target_dish_count"), count: z.number().int().min(MIN_TARGET_DISH_COUNT).max(MAX_TARGET_DISH_COUNT) }),
  z.object({ type: z.literal("set_stock"), count: z.number().int().min(MIN_STOCK_PER_INGREDIENT).max(MAX_STOCK_PER_INGREDIENT) }),
  z.object({ type: z.literal("set_pause"), paused: z.boolean() }),
  z.object({ type: z.literal("start") }),
  z.object({ type: z.literal("stop") }),
  z.object({ type: z.literal("pass_turn") }),
  z.object({ type: z.literal("redeem_all_and_pass_turn") }),
  z.object({ type: z.literal("deposit"), voucherId: z.string() }),
  z.object({ type: z.literal("deposit_ingredient"), ingredientId: z.string().optional() }),
  z.object({ type: z.literal("platter_swap"), giveVoucherId: z.string(), takeVoucherId: z.string() }),
  z.object({
    type: z.literal("platter_swap_ingredient"),
    giveIngredientId: z.string(),
    takeIngredientId: z.string(),
    quantity: z.number().int().positive().optional()
  }),
  z.object({
    type: z.literal("platter_asset_swap"),
    give: exactAssetRefSchema,
    take: exactAssetRefSchema
  }),
  z.object({
    type: z.literal("platter_asset_swap_aggregate"),
    give: aggregateAssetRefSchema,
    take: aggregateAssetRefSchema,
    quantity: z.number().int().positive().optional()
  }),
  z.object({
    type: z.literal("create_offer"),
    toParticipantId: z.string(),
    offeredVoucherIds: z.array(z.string()).min(1).optional(),
    offeredAssets: z.array(exactAssetRefSchema).min(1).optional(),
    requested: z.object({ ingredientId: z.string(), quantity: z.number().int().positive() }).optional(),
    requestedAsset: offerAssetRequestSchema.optional()
  }),
  z.object({
    type: z.literal("respond_offer"),
    offerId: z.string(),
    response: z.enum(["accept", "refuse"]),
    voucherIds: z.array(z.string()).optional(),
    assets: z.array(exactAssetRefSchema).optional()
  }),
  z.object({ type: z.literal("cancel_offer"), offerId: z.string() }),
  z.object({ type: z.literal("place_voucher"), voucherId: z.string(), requirementId: z.string() }),
  z.object({ type: z.literal("redeem_voucher"), voucherId: z.string() }),
  z.object({ type: z.literal("redeem_from_hand"), voucherId: z.string(), requirementId: z.string() }),
  z.object({ type: z.literal("prepare") }),
  z.object({ type: z.literal("bite"), dishId: z.string() }),
  z.object({ type: z.literal("bite_all") })
]);

const intentEnvelopeSchema = z.object({
  type: z.literal("intent"),
  clientIntentId: z.string().min(1).max(120),
  actorParticipantId: z.string().optional(),
  intent: intentSchema
});

const viewEnvelopeSchema = z.object({
  type: z.literal("view"),
  participantId: z.string().min(1)
});

const IDLE_SWEEP_INTERVAL_MS = 60 * 1000;

export interface AppOptions {
  store?: TableStore;
  hub?: ConnectionHub;
  logger?: boolean;
}

export async function buildApp(options: AppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({ logger: options.logger ?? false });
  const store = options.store ?? new TableStore();
  const hub = options.hub ?? new ConnectionHub();
  const timerHandles = new Map<string, ReturnType<typeof setTimeout>>();
  const idleHandles = new Map<string, ReturnType<typeof setTimeout>>();
  const closedTableCleanupHandles = new Map<string, ReturnType<typeof setTimeout>>();
  let idleSweepHandle: ReturnType<typeof setInterval> | undefined;

  app.addHook("onRequest", (request, reply, done) => {
    const origin = request.headers.origin;
    reply
      .header("Access-Control-Allow-Origin", typeof origin === "string" ? origin : "*")
      .header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .header("Access-Control-Allow-Headers", "Content-Type, Authorization")
      .header("Access-Control-Max-Age", "86400")
      .header("Vary", "Origin");

    if (request.method === "OPTIONS") {
      reply.status(204).send();
      return;
    }

    done();
  });

  await app.register(websocket);

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof GameError) {
      reply.status(400).send({ ok: false, errorCode: error.code, description: error.message });
      return;
    }
    if (error instanceof z.ZodError) {
      reply.status(400).send({ ok: false, errorCode: "invalid_request", description: z.prettifyError(error) });
      return;
    }
    const description = error instanceof Error ? error.message : "Unknown error";
    reply.status(500).send({ ok: false, errorCode: "internal_error", description });
  });

  app.get("/health", async () => ({
    ok: true,
    result: {
      service: "recipes-server",
      features: [
        "pause",
        "manual_bot_conversion",
        "transaction_history",
        "dish_part_settlement",
        "host_controlled_seats",
        "turn_modes",
        "public_tables",
        "idle_table_cleanup"
      ]
    }
  }));

  app.get("/tables", async () => ({
    ok: true,
    result: {
      tables: store.listPublicJoinableTables()
    }
  }));

  app.post("/tables", async (request) => {
    const body = createTableSchema.parse(request.body ?? {});
    const result = store.createTable(body.hostName, body.seed, body.requestedCode, body.isPublic);
    scheduleIdle(result.table.code);
    return {
      ok: true,
      result: {
        tableCode: result.table.code,
        participantId: result.participant.id,
        seatToken: result.seatToken,
        snapshot: result.snapshot
      }
    };
  });

  app.post("/tables/:code/join", async (request) => {
    const params = z.object({ code: z.string() }).parse(request.params);
    const body = joinTableSchema.parse(request.body ?? {});
    const result = store.joinTable(params.code, body.name, body.asWitness);
    hub.broadcastTable(result.table);
    scheduleIdle(result.table.code);
    return {
      ok: true,
      result: {
        tableCode: result.table.code,
        participantId: result.participant.id,
        seatToken: result.seatToken,
        snapshot: result.snapshot
      }
    };
  });

  app.get("/tables/:code/status", async (request) => {
    const params = z.object({ code: z.string() }).parse(request.params);
    return {
      ok: true,
      result: store.getTableStatus(params.code)
    };
  });

  app.get("/tables/:code/transactions.csv", async (request, reply) => {
    const params = z.object({ code: z.string() }).parse(request.params);
    const query = z.object({ seatToken: z.string() }).parse(request.query);
    const transactions = store.getTransactionsByToken(params.code, query.seatToken);
    const filename = `recipes-transactions-${params.code.toLowerCase()}.csv`;
    reply
      .header("Content-Type", "text/csv; charset=utf-8")
      .header("Content-Disposition", `attachment; filename="${filename}"`)
      .send(transactionsToCsv(transactions));
  });

  app.get("/tables/:code/socket", { websocket: true }, (socket, request) => {
    const params = z.object({ code: z.string() }).parse(request.params);
    const query = z.object({ seatToken: z.string() }).parse(request.query);
    const tableCode = params.code.toUpperCase();
    let connectionId = "";
    let connection: HubConnection | undefined;

    try {
      const participant = store.connectParticipantByToken(tableCode, query.seatToken);
      if (hub.hasConnectionForParticipant(tableCode, participant.id)) {
        throw new GameError("That seat is already connected.", "seat_already_connected");
      }
      connection = hub.register({
        tableCode,
        participantId: participant.id,
        connectionParticipantId: participant.id,
        send: (payload) => socket.send(payload)
      });
      connectionId = connection.id;
      hub.broadcastTable(store.requireTable(tableCode));
      scheduleIdle(tableCode);
    } catch (error) {
      socket.send(JSON.stringify(errorPayload(error)));
      socket.close();
      return;
    }

    socket.on("message", (message: Buffer) => {
      let clientIntentId: string | undefined;
      try {
        const parsed = JSON.parse(message.toString()) as unknown;
        const envelope = parseSocketIntent(parsed);
        clientIntentId = "clientIntentId" in envelope ? envelope.clientIntentId : undefined;
        if ("viewParticipantId" in envelope) {
          const snapshot = store.getSnapshotByToken(tableCode, query.seatToken, envelope.viewParticipantId);
          const table = store.requireTable(tableCode);
          if (connection) {
            connection.participantId = envelope.viewParticipantId;
            hub.sendSnapshot(table, connection);
          } else {
            socket.send(JSON.stringify({ type: "snapshot", snapshot }));
          }
          return;
        }
        const intent = envelope.intent;
        let broadcastedMutation = false;
        store.handleIntent(tableCode, query.seatToken, intent, true, envelope.actorParticipantId, (table) => {
          broadcastedMutation = true;
          hub.broadcastTable(table);
        });
        scheduleTimer(tableCode);
        scheduleIdle(tableCode);
        scheduleClosedTableCleanup(tableCode);
        if (clientIntentId) {
          socket.send(JSON.stringify({ type: "ack", clientIntentId, ok: true, version: store.requireTable(tableCode).version }));
        }
        if (!broadcastedMutation) {
          hub.broadcastTable(store.requireTable(tableCode));
        }
      } catch (error) {
        const payload = errorPayload(error);
        if (clientIntentId) {
          socket.send(
            JSON.stringify({
              type: "ack",
              clientIntentId,
              ok: false,
              errorCode: payload.errorCode,
              description: payload.description
            })
          );
        } else {
          socket.send(JSON.stringify(payload));
        }
      }
    });

    socket.on("close", () => {
      if (connectionId !== "") {
        hub.unregister(tableCode, connectionId);
      }
      try {
        store.disconnectParticipantByToken(tableCode, query.seatToken);
        hub.broadcastTable(store.requireTable(tableCode));
      } catch {
        // The socket is already closed; no useful error can be returned here.
      }
    });
  });

  app.addHook("onClose", async () => {
    for (const handle of timerHandles.values()) {
      clearTimeout(handle);
    }
    timerHandles.clear();
    for (const handle of idleHandles.values()) {
      clearTimeout(handle);
    }
    idleHandles.clear();
    for (const handle of closedTableCleanupHandles.values()) {
      clearTimeout(handle);
    }
    closedTableCleanupHandles.clear();
    if (idleSweepHandle) {
      clearInterval(idleSweepHandle);
      idleSweepHandle = undefined;
    }
  });

  startIdleSweep();
  scheduleAllTableMaintenance();

  function scheduleTimer(tableCode: string): void {
    const normalizedCode = tableCode.toUpperCase();
    const existing = timerHandles.get(normalizedCode);
    if (existing) {
      clearTimeout(existing);
      timerHandles.delete(normalizedCode);
    }

    const table = store.requireTable(normalizedCode);
    if (table.paused || !table.timer?.endsAtMs || table.timer.expiredAtMs) {
      return;
    }
    if (table.phase !== "deposit" && table.phase !== "playing") {
      return;
    }

    const delayMs = Math.max(0, table.timer.endsAtMs - Date.now());
    const handle = setTimeout(() => {
      timerHandles.delete(normalizedCode);
      try {
        const expired = store.expireTimer(normalizedCode);
        if (expired) {
          hub.broadcastTable(store.requireTable(normalizedCode));
          scheduleIdle(normalizedCode);
          scheduleClosedTableCleanup(normalizedCode);
        }
      } catch {
        // Timer callbacks cannot report to a specific client.
      }
    }, delayMs);
    timerHandles.set(normalizedCode, handle);
  }

  function scheduleIdle(tableCode: string): void {
    const normalizedCode = tableCode.toUpperCase();
    const existing = idleHandles.get(normalizedCode);
    if (existing) {
      clearTimeout(existing);
      idleHandles.delete(normalizedCode);
    }

    let deadlineMs: number | undefined;
    try {
      deadlineMs = store.nextIdleDeadlineMs(normalizedCode);
    } catch {
      return;
    }
    if (deadlineMs === undefined) {
      return;
    }

    const delayMs = Math.max(0, deadlineMs - Date.now());
    const handle = setTimeout(() => {
      idleHandles.delete(normalizedCode);
      try {
        const changed = store.advanceIdle(normalizedCode);
        if (changed) {
          hub.broadcastTable(store.requireTable(normalizedCode));
        }
        scheduleIdle(normalizedCode);
        scheduleClosedTableCleanup(normalizedCode);
      } catch {
        // Idle callbacks cannot report to a specific client.
      }
    }, delayMs);
    idleHandles.set(normalizedCode, handle);
  }

  function scheduleClosedTableCleanup(tableCode: string): void {
    const normalizedCode = tableCode.toUpperCase();
    const existing = closedTableCleanupHandles.get(normalizedCode);
    if (existing) {
      clearTimeout(existing);
      closedTableCleanupHandles.delete(normalizedCode);
    }

    let returnToMenuAtMs = 0;
    try {
      const table = store.requireTable(normalizedCode);
      returnToMenuAtMs = table.idle?.closure?.returnToMenuAtMs ?? 0;
    } catch {
      return;
    }
    if (returnToMenuAtMs <= 0) {
      return;
    }

    const delayMs = Math.max(5000, returnToMenuAtMs + 5000 - Date.now());
    const handle = setTimeout(() => {
      closedTableCleanupHandles.delete(normalizedCode);
      store.deleteTable(normalizedCode);
    }, delayMs);
    closedTableCleanupHandles.set(normalizedCode, handle);
  }

  function startIdleSweep(): void {
    idleSweepHandle = setInterval(() => {
      sweepIdleTables();
    }, IDLE_SWEEP_INTERVAL_MS);
    (idleSweepHandle as { unref?: () => void }).unref?.();
  }

  function scheduleAllTableMaintenance(): void {
    for (const tableCode of store.tables.keys()) {
      scheduleTimer(tableCode);
      scheduleIdle(tableCode);
      scheduleClosedTableCleanup(tableCode);
    }
  }

  function sweepIdleTables(): void {
    for (const tableCode of [...store.tables.keys()]) {
      try {
        const changed = store.advanceIdle(tableCode);
        if (changed) {
          hub.broadcastTable(store.requireTable(tableCode));
        }
        scheduleTimer(tableCode);
        scheduleIdle(tableCode);
        scheduleClosedTableCleanup(tableCode);
      } catch {
        // Periodic maintenance must not fail the server because one table is malformed or gone.
      }
    }
  }

  return app;
}

function errorPayload(error: unknown) {
  if (error instanceof GameError) {
    return { type: "error", ok: false, errorCode: error.code, description: error.message };
  }
  if (error instanceof z.ZodError) {
    return { type: "error", ok: false, errorCode: "invalid_request", description: z.prettifyError(error) };
  }
  if (error instanceof Error) {
    return { type: "error", ok: false, errorCode: "internal_error", description: error.message };
  }
  return { type: "error", ok: false, errorCode: "internal_error", description: "Unknown error" };
}

function parseSocketIntent(parsed: unknown): { intent: Intent; clientIntentId?: string; actorParticipantId?: string } | { viewParticipantId: string } {
  if (
    typeof parsed === "object" &&
    parsed !== null &&
    "type" in parsed &&
    (parsed as { type?: unknown }).type === "intent"
  ) {
    const envelope = intentEnvelopeSchema.parse(parsed);
    return { intent: envelope.intent, clientIntentId: envelope.clientIntentId, actorParticipantId: envelope.actorParticipantId };
  }
  if (
    typeof parsed === "object" &&
    parsed !== null &&
    "type" in parsed &&
    (parsed as { type?: unknown }).type === "view"
  ) {
    const envelope = viewEnvelopeSchema.parse(parsed);
    return { viewParticipantId: envelope.participantId };
  }
  return { intent: intentSchema.parse(parsed) };
}
