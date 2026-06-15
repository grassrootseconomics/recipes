import websocket from "@fastify/websocket";
import Fastify, { type FastifyInstance } from "fastify";
import { z } from "zod";
import { MAX_STOCK_PER_INGREDIENT, MIN_STOCK_PER_INGREDIENT } from "./constants.js";
import { GameError } from "./game.js";
import { ConnectionHub } from "./hub.js";
import { TableStore } from "./store.js";
import { transactionsToCsv } from "./transactions.js";
import type { Intent } from "./types.js";

const createTableSchema = z.object({
  hostName: z.string().max(40).default(""),
  seed: z.string().min(1).max(120).optional()
});

const joinTableSchema = z.object({
  name: z.string().max(40).default(""),
  asWitness: z.boolean().default(false)
});

const aggregateAssetRefSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("voucher"), ingredientId: z.string(), ownerParticipantId: z.string().optional() }),
  z.object({ kind: z.literal("dish_part"), dishId: z.string(), makerParticipantId: z.string().optional() })
]);

const intentSchema: z.ZodType<Intent> = z.discriminatedUnion("type", [
  z.object({ type: z.literal("leave_table") }),
  z.object({ type: z.literal("close_table") }),
  z.object({ type: z.literal("reset_table") }),
  z.object({ type: z.literal("set_role"), participantId: z.string(), role: z.enum(["active", "witness"]) }),
  z.object({ type: z.literal("add_bot"), name: z.string().optional(), botType: z.enum(["pool_only", "barter_only", "mixed"]) }),
  z.object({ type: z.literal("convert_to_bot"), participantId: z.string(), botType: z.enum(["pool_only", "barter_only", "mixed"]).optional() }),
  z.object({ type: z.literal("set_timer"), seconds: z.number().int().positive().nullable() }),
  z.object({ type: z.literal("set_target_dish_count"), count: z.number().int().min(1).max(4) }),
  z.object({ type: z.literal("set_stock"), count: z.number().int().min(MIN_STOCK_PER_INGREDIENT).max(MAX_STOCK_PER_INGREDIENT) }),
  z.object({ type: z.literal("set_pause"), paused: z.boolean() }),
  z.object({ type: z.literal("start") }),
  z.object({ type: z.literal("stop") }),
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
    give: z.object({ kind: z.enum(["voucher", "dish_part"]), id: z.string() }),
    take: z.object({ kind: z.enum(["voucher", "dish_part"]), id: z.string() })
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
    offeredVoucherIds: z.array(z.string()).min(1),
    requested: z.object({ ingredientId: z.string(), quantity: z.number().int().positive() })
  }),
  z.object({
    type: z.literal("respond_offer"),
    offerId: z.string(),
    response: z.enum(["accept", "refuse"]),
    voucherIds: z.array(z.string()).optional()
  }),
  z.object({ type: z.literal("cancel_offer"), offerId: z.string() }),
  z.object({ type: z.literal("place_voucher"), voucherId: z.string(), requirementId: z.string() }),
  z.object({ type: z.literal("redeem_voucher"), voucherId: z.string() }),
  z.object({ type: z.literal("redeem_from_hand"), voucherId: z.string(), requirementId: z.string() }),
  z.object({ type: z.literal("prepare") }),
  z.object({ type: z.literal("bite"), dishId: z.string() })
]);

const intentEnvelopeSchema = z.object({
  type: z.literal("intent"),
  clientIntentId: z.string().min(1).max(120),
  intent: intentSchema
});

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
      features: ["pause", "manual_bot_conversion", "transaction_history", "dish_part_settlement"]
    }
  }));

  app.post("/tables", async (request) => {
    const body = createTableSchema.parse(request.body ?? {});
    const result = store.createTable(body.hostName, body.seed);
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

    try {
      const participant = store.connectParticipantByToken(tableCode, query.seatToken);
      const connection = hub.register({
        tableCode,
        participantId: participant.id,
        send: (payload) => socket.send(payload)
      });
      connectionId = connection.id;
      hub.broadcastTable(store.requireTable(tableCode));
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
        clientIntentId = envelope.clientIntentId;
        const intent = envelope.intent;
        store.handleIntent(tableCode, query.seatToken, intent);
        scheduleTimer(tableCode);
        if (clientIntentId) {
          socket.send(JSON.stringify({ type: "ack", clientIntentId, ok: true, version: store.requireTable(tableCode).version }));
        }
        hub.broadcastTable(store.requireTable(tableCode));
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
  });

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
        }
      } catch {
        // Timer callbacks cannot report to a specific client.
      }
    }, delayMs);
    timerHandles.set(normalizedCode, handle);
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

function parseSocketIntent(parsed: unknown): { intent: Intent; clientIntentId?: string } {
  if (
    typeof parsed === "object" &&
    parsed !== null &&
    "type" in parsed &&
    (parsed as { type?: unknown }).type === "intent"
  ) {
    const envelope = intentEnvelopeSchema.parse(parsed);
    return { intent: envelope.intent, clientIntentId: envelope.clientIntentId };
  }
  return { intent: intentSchema.parse(parsed) };
}
