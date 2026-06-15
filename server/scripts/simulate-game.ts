import { mkdir, writeFile } from "node:fs/promises";
import { AddressInfo } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildApp } from "../src/app.js";
import {
  activeParticipants,
  handVoucherIds,
  inventoryDishPartIds,
  platterAccountForParticipant,
  platterDishPartIds,
  platterVoucherIds
} from "../src/game.js";
import { TableStore } from "../src/store.js";
import type { Intent, Snapshot, SnapshotDelta, Table } from "../src/types.js";

type NetworkProfile = "local" | "jitter" | "disconnect" | "bad";

interface ClientMetrics {
  participantId: string;
  name: string;
  bytesReceived: number;
  httpBytesReceived: number;
  messageCount: number;
  reconnectCount: number;
  rejectedIntents: number;
  ackedIntents: number;
  failedAcks: number;
  intentTimeouts: number;
  lastAckError?: string;
  frameSizes: number[];
  snapshotFrameSizes: number[];
  deltaFrameSizes: number[];
}

interface SimulationOptions {
  profile: NetworkProfile;
  playerCount: number;
  playerMin: number;
  playerMax: number;
  gameCount: number;
  concurrency: number;
  dishGoal: number;
  maxIntents: number;
  maxDurationMs: number;
  suiteMaxDurationMs: number;
  seed: string;
}

interface AckMessage {
  type: "ack";
  clientIntentId: string;
  ok: boolean;
  version?: number;
  errorCode?: string;
  description?: string;
}

type SendResult = "ok" | "failed" | "timeout";

interface CreateOrJoinResponse {
  ok: boolean;
  result: {
    tableCode: string;
    participantId: string;
    seatToken: string;
    snapshot: Snapshot;
  };
}

class SimulationTimeoutError extends Error {}

const store = new TableStore();
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

async function runSimulation(baseUrl: string, simulationOptions: SimulationOptions) {
  const startedAt = Date.now();
  const rng = seededRng(simulationOptions.seed);
  const clients: SimClient[] = [];
  let totalIntents = 0;
  let lastStage = "starting";
  let table: Table | undefined;

  try {
    const host = await SimClient.createHost(baseUrl, "Host", simulationOptions.seed);
    clients.push(host);
    for (let index = 2; index <= simulationOptions.playerCount; index += 1) {
      clients.push(await SimClient.join(baseUrl, host.tableCode, `Player ${index}`));
    }

    table = store.requireTable(host.tableCode);
    await Promise.all(clients.map((client) => client.connect()));

    if (simulationOptions.dishGoal !== table.targetDishCount) {
      await sendIntent(host, { type: "set_target_dish_count", count: simulationOptions.dishGoal });
    }
    await sendIntent(host, { type: "start" });
    for (const participant of activeParticipants(table)) {
      await sendIntent(clientFor(clients, participant.id), { type: "deposit_ingredient" });
    }

    while (table.phase === "playing") {
      for (const participant of activeParticipants(table)) {
        if (table.phase !== "playing") {
          break;
        }
        await completeOneRecipe(table, clients, participant.id);
      }
    }

    await settleTable(table, clients);
    await eatAllFoodParts(table, clients);

    return buildReport();
  } catch (error) {
    return buildReport(error);
  }

  function buildReport(error?: unknown) {
    const completionMs = Date.now() - startedAt;
    const metrics = clients.map((client) => client.metrics());
    const frameSizes = metrics.flatMap((metric) => metric.frameSizes);
    return {
      ok: !error,
      error: error instanceof Error ? error.message : error ? String(error) : undefined,
      timedOut: error instanceof SimulationTimeoutError,
      lastStage,
      tableCode: table?.code ?? clients[0]?.tableCode ?? "unknown",
      profile: simulationOptions.profile,
      playerCount: simulationOptions.playerCount,
      dishGoal: simulationOptions.dishGoal,
      phase: table?.phase ?? "unknown",
      totalIntents,
      totalTurns: table?.turn ?? 0,
      completionMs,
      maxDurationMs: simulationOptions.maxDurationMs,
      totalBytesReceived: metrics.reduce((total, metric) => total + metric.bytesReceived + metric.httpBytesReceived, 0),
      maxFrameBytes: Math.max(0, ...frameSizes),
      p50FrameBytes: percentile(frameSizes, 50),
      p95FrameBytes: percentile(frameSizes, 95),
      maxDeltaFrameBytes: Math.max(0, ...metrics.flatMap((metric) => metric.deltaFrameSizes)),
      p95DeltaFrameBytes: percentile(metrics.flatMap((metric) => metric.deltaFrameSizes), 95),
      clients: metrics
    };
  }

  async function sendIntent(client: SimClient, intent: Intent, allowFailure = false): Promise<void> {
    lastStage = `${client.name} ${intent.type}`;
    checkDeadline(lastStage);
    totalIntents += 1;
    if (totalIntents > simulationOptions.maxIntents) {
      throw new Error(`Simulation exceeded max intents (${simulationOptions.maxIntents}).`);
    }
    await maybeDelay(simulationOptions.profile, rng);
    await maybeReconnect(clients, simulationOptions.profile, totalIntents, rng);
    if (simulationOptions.profile === "bad" && totalIntents % 31 === 0) {
      await client.send({ type: "platter_swap_ingredient", giveIngredientId: "missing", takeIngredientId: "missing" }, true);
    }
    const beforeTableVersion = currentTable().version;
    const result = await client.send(intent, allowFailure);
    if (result === "ok") {
      return;
    }
    if (result === "failed") {
      throw new Error(`Intent was rejected for ${client.name}: ${JSON.stringify(intent)} (${client.lastAckError})`);
    }
    const versionAfterTimeout = currentTable().version;
    await client.reconnect();
    if (versionAfterTimeout > beforeTableVersion) {
      return;
    }
    const retryResult = await client.send(intent, false);
    if (retryResult !== "ok") {
      throw new Error(`Intent failed for ${client.name}: ${JSON.stringify(intent)} (${retryResult}; ${client.lastAckError})`);
    }
  }

  function currentTable(): Table {
    if (!table) {
      throw new Error("Simulation table is not initialized.");
    }
    return table;
  }

  function checkDeadline(stage: string): void {
    if (Date.now() - startedAt > simulationOptions.maxDurationMs) {
      throw new SimulationTimeoutError(`Simulation exceeded max duration ${simulationOptions.maxDurationMs}ms at ${stage}.`);
    }
  }

  async function completeOneRecipe(table: Table, clients: SimClient[], participantId: string): Promise<void> {
    while (true) {
      const recipe = table.recipes[participantId];
      if (!recipe) {
        return;
      }
      const requirement = recipe.requirements.find((candidate) => candidate.redeemedQty < candidate.requiredQty);
      if (!requirement) {
        break;
      }
      await ensureIngredientInHand(table, clients, participantId, requirement.ingredientId);
      const refreshedRecipe = table.recipes[participantId];
      const refreshedRequirement = refreshedRecipe?.requirements.find((candidate) => candidate.id === requirement.id);
      if (!refreshedRequirement || refreshedRequirement.redeemedQty >= refreshedRequirement.requiredQty) {
        continue;
      }
      const voucherId = handVoucherIds(table, participantId).find((id) => table.vouchers[id].ingredientId === refreshedRequirement.ingredientId);
      if (!voucherId) {
        throw new Error(`Could not move ${refreshedRequirement.ingredientId} to ${participantId}.`);
      }
      await sendIntent(clientFor(clients, participantId), {
        type: "redeem_from_hand",
        voucherId,
        requirementId: refreshedRequirement.id
      });
    }
    await sendIntent(clientFor(clients, participantId), { type: "prepare" });
  }

  async function ensureIngredientInHand(table: Table, clients: SimClient[], participantId: string, ingredientId: string): Promise<void> {
    if (handVoucherIds(table, participantId).some((id) => table.vouchers[id].ingredientId === ingredientId)) {
      return;
    }
    if (!platterVoucherIds(table).some((id) => table.vouchers[id].ingredientId === ingredientId)) {
      const holderId = participantHoldingIngredient(table, ingredientId);
      if (!holderId) {
        throw new Error(`No holder found for ingredient ${ingredientId}.`);
      }
      const takeIngredientId = firstPlatterIngredient(table, ingredientId);
      await sendIntent(clientFor(clients, holderId), {
        type: "platter_swap_ingredient",
        giveIngredientId: ingredientId,
        takeIngredientId
      });
    }
    const handIngredientId = firstHandIngredient(table, participantId);
    if (handIngredientId) {
      await sendIntent(clientFor(clients, participantId), {
        type: "platter_swap_ingredient",
        giveIngredientId: handIngredientId,
        takeIngredientId: ingredientId
      });
      return;
    }
    const givePartId = inventoryDishPartIds(table, participantId)[0];
    const takeVoucherId = platterVoucherIds(table).find((id) => table.vouchers[id].ingredientId === ingredientId);
    if (!givePartId || !takeVoucherId) {
      throw new Error(`Participant ${participantId} has no voucher or food part to trade for ${ingredientId}.`);
    }
    await sendIntent(clientFor(clients, participantId), {
      type: "platter_asset_swap",
      give: { kind: "dish_part", id: givePartId },
      take: { kind: "voucher", id: takeVoucherId }
    });
  }

  async function settleTable(table: Table, clients: SimClient[]): Promise<void> {
    let loops = 0;
    while (table.phase === "settlement") {
      loops += 1;
      if (loops > simulationOptions.maxIntents) {
        throw new Error("Settlement did not converge.");
      }
      const debtor = activeParticipants(table).find((participant) => platterAccountForParticipant(table, participant.id).platterDebt > 0);
      if (debtor) {
        const ownPlatterVoucherId = platterVoucherIds(table).find((id) => table.vouchers[id].ownerParticipantId === debtor.id);
        const givePartId = inventoryDishPartIds(table, debtor.id)[0];
        if (ownPlatterVoucherId && givePartId) {
          await sendIntent(clientFor(clients, debtor.id), {
            type: "platter_asset_swap",
            give: { kind: "dish_part", id: givePartId },
            take: { kind: "voucher", id: ownPlatterVoucherId }
          });
          continue;
        }
      }

      const shortfall = activeParticipants(table).find((participant) => platterAccountForParticipant(table, participant.id).platterShortfall > 0);
      if (shortfall) {
        const ownHandVoucherId = handVoucherIds(table, shortfall.id).find((id) => table.vouchers[id].ownerParticipantId === shortfall.id);
        const takePartId = platterDishPartIds(table)[0];
        const takeVoucherId = platterVoucherIds(table).find((id) => table.vouchers[id].ownerParticipantId !== shortfall.id);
        if (ownHandVoucherId && takePartId) {
          await sendIntent(clientFor(clients, shortfall.id), {
            type: "platter_asset_swap",
            give: { kind: "voucher", id: ownHandVoucherId },
            take: { kind: "dish_part", id: takePartId }
          });
          continue;
        }
        if (ownHandVoucherId && takeVoucherId) {
          await sendIntent(clientFor(clients, shortfall.id), {
            type: "platter_asset_swap",
            give: { kind: "voucher", id: ownHandVoucherId },
            take: { kind: "voucher", id: takeVoucherId }
          });
          continue;
        }
      }

      const platterPartId = platterDishPartIds(table)[0];
      if (platterPartId) {
        const clearer = activeParticipants(table).find((participant) =>
          handVoucherIds(table, participant.id).some((id) => table.vouchers[id].ownerParticipantId !== participant.id)
        );
        if (clearer) {
          const giveVoucherId = handVoucherIds(table, clearer.id).find((id) => table.vouchers[id].ownerParticipantId !== clearer.id) as string;
          await sendIntent(clientFor(clients, clearer.id), {
            type: "platter_asset_swap",
            give: { kind: "voucher", id: giveVoucherId },
            take: { kind: "dish_part", id: platterPartId }
          });
          continue;
        }
      }

      throw new Error("No legal settlement move found.");
    }
  }

  async function eatAllFoodParts(table: Table, clients: SimClient[]): Promise<void> {
    let loops = 0;
    while (table.phase === "eating") {
      loops += 1;
      if (loops > simulationOptions.maxIntents) {
        throw new Error("Eating did not converge.");
      }
      const part = Object.values(table.dishParts).find((candidate) => candidate.location.type === "inventory" && candidate.location.participantId);
      if (!part?.location.participantId) {
        throw new Error("No held food part found while table is eating.");
      }
      await sendIntent(clientFor(clients, part.location.participantId), { type: "bite", dishId: part.dishId });
    }
  }
}

type SimulationReport = Awaited<ReturnType<typeof runSimulation>>;

interface CompactGameReport {
  index: number;
  ok: boolean;
  error?: string;
  timedOut: boolean;
  lastStage: string;
  tableCode: string;
  profile: NetworkProfile;
  playerCount: number;
  dishGoal: number;
  phase: string;
  totalIntents: number;
  totalTurns: number;
  completionMs: number;
  totalBytesReceived: number;
  maxFrameBytes: number;
  p95FrameBytes: number;
  maxDeltaFrameBytes: number;
  p95DeltaFrameBytes: number;
  reconnects: number;
  rejectedIntents: number;
  intentTimeouts: number;
}

async function runSimulationSuite(baseUrl: string, options: SimulationOptions) {
  const startedAt = Date.now();
  const reports: Array<{ index: number; report: SimulationReport }> = [];
  let nextIndex = 0;
  let suiteTimedOut = false;
  const workerCount = Math.min(options.concurrency, options.gameCount);

  async function runWorker(): Promise<void> {
    while (nextIndex < options.gameCount) {
      const elapsedMs = Date.now() - startedAt;
      const remainingMs = options.suiteMaxDurationMs - elapsedMs;
      if (remainingMs <= 0) {
        suiteTimedOut = true;
        return;
      }
      const index = nextIndex;
      nextIndex += 1;
      const playerCount = playerCountForGame(options, index);
      const report = await runSimulation(baseUrl, {
        ...options,
        playerCount,
        maxDurationMs: Math.min(options.maxDurationMs, remainingMs),
        seed: `${options.seed}-game-${index + 1}-players-${playerCount}`
      });
      reports.push({ index, report });
      if (Date.now() - startedAt > options.suiteMaxDurationMs) {
        suiteTimedOut = true;
      }
    }
  }

  await Promise.all(Array.from({ length: workerCount }, () => runWorker()));

  reports.sort((left, right) => left.index - right.index);
  const compactGames = reports.map(({ index, report }) => compactGameReport(index, report));
  const allFrameSizes = reports.flatMap(({ report }) => report.clients.flatMap((client) => client.frameSizes));
  const allDeltaFrameSizes = reports.flatMap(({ report }) => report.clients.flatMap((client) => client.deltaFrameSizes));
  const failedGames = compactGames.filter((game) => !game.ok);
  const incompleteGames = options.gameCount - compactGames.length;
  return {
    ok: failedGames.length === 0 && incompleteGames === 0 && !suiteTimedOut,
    profile: options.profile,
    gameCount: options.gameCount,
    concurrency: options.concurrency,
    playerMin: options.playerMin,
    playerMax: options.playerMax,
    dishGoal: options.dishGoal,
    maxDurationMs: options.maxDurationMs,
    suiteMaxDurationMs: options.suiteMaxDurationMs,
    suiteTimedOut: suiteTimedOut || incompleteGames > 0,
    completionMs: Date.now() - startedAt,
    completedGames: compactGames.length - failedGames.length,
    failedGames: failedGames.length,
    reportedGames: compactGames.length,
    incompleteGames,
    totalPlayers: compactGames.reduce((total, game) => total + game.playerCount, 0),
    totalIntents: compactGames.reduce((total, game) => total + game.totalIntents, 0),
    totalTurns: compactGames.reduce((total, game) => total + game.totalTurns, 0),
    totalBytesReceived: compactGames.reduce((total, game) => total + game.totalBytesReceived, 0),
    maxFrameBytes: Math.max(0, ...allFrameSizes),
    p50FrameBytes: percentile(allFrameSizes, 50),
    p95FrameBytes: percentile(allFrameSizes, 95),
    maxDeltaFrameBytes: Math.max(0, ...allDeltaFrameSizes),
    p95DeltaFrameBytes: percentile(allDeltaFrameSizes, 95),
    reconnects: compactGames.reduce((total, game) => total + game.reconnects, 0),
    rejectedIntents: compactGames.reduce((total, game) => total + game.rejectedIntents, 0),
    intentTimeouts: compactGames.reduce((total, game) => total + game.intentTimeouts, 0),
    games: compactGames
  };
}

function compactGameReport(index: number, report: SimulationReport): CompactGameReport {
  return {
    index: index + 1,
    ok: report.ok,
    error: report.error,
    timedOut: report.timedOut,
    lastStage: report.lastStage,
    tableCode: report.tableCode,
    profile: report.profile,
    playerCount: report.playerCount,
    dishGoal: report.dishGoal,
    phase: report.phase,
    totalIntents: report.totalIntents,
    totalTurns: report.totalTurns,
    completionMs: report.completionMs,
    totalBytesReceived: report.totalBytesReceived,
    maxFrameBytes: report.maxFrameBytes,
    p95FrameBytes: report.p95FrameBytes,
    maxDeltaFrameBytes: report.maxDeltaFrameBytes,
    p95DeltaFrameBytes: report.p95DeltaFrameBytes,
    reconnects: report.clients.reduce((total, client) => total + client.reconnectCount, 0),
    rejectedIntents: report.clients.reduce((total, client) => total + client.rejectedIntents, 0),
    intentTimeouts: report.clients.reduce((total, client) => total + client.intentTimeouts, 0)
  };
}

function playerCountForGame(options: SimulationOptions, index: number): number {
  if (options.playerMin === options.playerMax) {
    return options.playerMin;
  }
  const width = options.playerMax - options.playerMin + 1;
  return options.playerMin + (index % width);
}

class SimClient {
  snapshot?: Snapshot;
  readonly frameSizes: number[] = [];
  readonly snapshotFrameSizes: number[] = [];
  readonly deltaFrameSizes: number[] = [];
  bytesReceived = 0;
  httpBytesReceived = 0;
  messageCount = 0;
  reconnectCount = 0;
  rejectedIntents = 0;
  ackedIntents = 0;
  failedAcks = 0;
  intentTimeouts = 0;
  lastAckError = "";
  private nextIntentId = 1;
  private readonly pendingAcks = new Map<string, (ack: AckMessage) => void>();
  private ws?: WebSocket;

  private constructor(
    readonly baseUrl: string,
    readonly tableCode: string,
    readonly participantId: string,
    readonly seatToken: string,
    readonly name: string
  ) {}

  static async createHost(baseUrl: string, name: string, seed: string): Promise<SimClient> {
    const response = await postJson(`${baseUrl}/tables`, { hostName: name, seed });
    return clientFromResponse(baseUrl, response, name);
  }

  static async join(baseUrl: string, tableCode: string, name: string): Promise<SimClient> {
    const response = await postJson(`${baseUrl}/tables/${tableCode}/join`, { name });
    return clientFromResponse(baseUrl, response, name);
  }

  async connect(): Promise<void> {
    if (this.ws?.readyState === WebSocket.OPEN) {
      return;
    }
    const wsUrl = `${this.baseUrl.replace("http://", "ws://").replace("https://", "wss://")}/tables/${this.tableCode}/socket?seatToken=${encodeURIComponent(
      this.seatToken
    )}`;
    await new Promise<void>((resolve, reject) => {
      const ws = new WebSocket(wsUrl);
      this.ws = ws;
      const timeout = setTimeout(() => reject(new Error(`Timed out connecting ${this.name}.`)), 3000);
      ws.addEventListener("open", () => {
        clearTimeout(timeout);
        resolve();
      });
      ws.addEventListener("message", (event) => this.handleMessage(String(event.data)));
      ws.addEventListener("error", () => {
        clearTimeout(timeout);
        reject(new Error(`WebSocket failed for ${this.name}.`));
      });
    });
    await this.waitForSnapshot();
  }

  async reconnect(): Promise<void> {
    this.reconnectCount += 1;
    this.ws?.close();
    this.ws = undefined;
    await delay(25);
    await this.connect();
  }

  async send(intent: Intent, allowFailure = false): Promise<SendResult> {
    await this.connect();
    const clientIntentId = `${this.participantId}:${this.nextIntentId}`;
    this.nextIntentId += 1;
    const ackPromise = this.waitForAck(clientIntentId, 4000);
    this.ws?.send(JSON.stringify({ type: "intent", clientIntentId, intent }));
    const ack = await ackPromise;
    if (!ack) {
      this.intentTimeouts += 1;
      return "timeout";
    }
    if (!ack.ok) {
      this.failedAcks += 1;
      this.rejectedIntents += 1;
      this.lastAckError = `${ack.errorCode ?? "error"}: ${ack.description ?? "Intent failed"}`;
      return allowFailure ? "ok" : "failed";
    }
    this.ackedIntents += 1;
    return "ok";
  }

  metrics(): ClientMetrics {
    return {
      participantId: this.participantId,
      name: this.name,
      bytesReceived: this.bytesReceived,
      httpBytesReceived: this.httpBytesReceived,
      messageCount: this.messageCount,
      reconnectCount: this.reconnectCount,
      rejectedIntents: this.rejectedIntents,
      ackedIntents: this.ackedIntents,
      failedAcks: this.failedAcks,
      intentTimeouts: this.intentTimeouts,
      lastAckError: this.lastAckError || undefined,
      frameSizes: this.frameSizes,
      snapshotFrameSizes: this.snapshotFrameSizes,
      deltaFrameSizes: this.deltaFrameSizes
    };
  }

  private async waitForSnapshot(): Promise<void> {
    await waitUntil(() => Boolean(this.snapshot), 3000);
  }

  private handleMessage(text: string): void {
    const bytes = Buffer.byteLength(text, "utf8");
    this.bytesReceived += bytes;
    this.frameSizes.push(bytes);
    this.messageCount += 1;
    const message = JSON.parse(text) as { type: string; snapshot?: Snapshot } | SnapshotDelta | AckMessage | { type: "error" };
    if (message.type === "snapshot") {
      this.snapshotFrameSizes.push(bytes);
      this.snapshot = (message as { snapshot: Snapshot }).snapshot;
      return;
    }
    if (message.type === "delta") {
      this.deltaFrameSizes.push(bytes);
      this.applyDelta(message as SnapshotDelta);
      return;
    }
    if (message.type === "ack") {
      this.resolveAck(message as AckMessage);
      return;
    }
    if (message.type === "error") {
      this.rejectedIntents += 1;
    }
  }

  private waitForAck(clientIntentId: string, timeoutMs: number): Promise<AckMessage | undefined> {
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        this.pendingAcks.delete(clientIntentId);
        resolve(undefined);
      }, timeoutMs);
      this.pendingAcks.set(clientIntentId, (ack) => {
        clearTimeout(timeout);
        resolve(ack);
      });
    });
  }

  private resolveAck(ack: AckMessage): void {
    const resolve = this.pendingAcks.get(ack.clientIntentId);
    if (!resolve) {
      return;
    }
    this.pendingAcks.delete(ack.clientIntentId);
    resolve(ack);
  }

  private applyDelta(delta: SnapshotDelta): void {
    if (!this.snapshot || this.snapshot.version !== delta.baseVersion) {
      this.snapshot = undefined;
      void this.reconnect();
      return;
    }
    this.snapshot = { ...this.snapshot, ...delta.patch, version: delta.version };
    if (delta.append.transactionHistory) {
      const history = [...(this.snapshot.transactionHistory ?? []), ...delta.append.transactionHistory];
      this.snapshot.transactionHistory = history.slice(-100);
    }
    if (delta.append.dishes) {
      this.mergeSnapshotRows("dishes", delta.append.dishes, "id");
    }
    if (delta.append.participants) {
      this.mergeSnapshotRows("participants", delta.append.participants, "id");
    }
  }

  private mergeSnapshotRows(key: "dishes" | "participants", rows: Array<{ id: string }>, idKey: "id"): void {
    if (!this.snapshot) {
      return;
    }
    const existingRows = [...(this.snapshot[key] as Array<Record<string, unknown>>)];
    for (const row of rows) {
      const rowId = String(row[idKey]);
      const index = existingRows.findIndex((candidate) => String(candidate[idKey]) === rowId);
      if (index >= 0) {
        existingRows[index] = row;
      } else {
        existingRows.push(row);
      }
    }
    (this.snapshot as unknown as Record<string, unknown>)[key] = existingRows;
  }
}

async function postJson(url: string, body: unknown): Promise<{ parsed: CreateOrJoinResponse; bytes: number }> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text}`);
  }
  return { parsed: JSON.parse(text) as CreateOrJoinResponse, bytes: Buffer.byteLength(text, "utf8") };
}

function clientFromResponse(baseUrl: string, response: { parsed: CreateOrJoinResponse; bytes: number }, name: string): SimClient {
  const client = new SimClient(
    baseUrl,
    response.parsed.result.tableCode,
    response.parsed.result.participantId,
    response.parsed.result.seatToken,
    name
  );
  client.snapshot = response.parsed.result.snapshot;
  client.httpBytesReceived = response.bytes;
  return client;
}

function clientFor(clients: SimClient[], participantId: string): SimClient {
  const client = clients.find((candidate) => candidate.participantId === participantId);
  if (!client) {
    throw new Error(`No client for participant ${participantId}.`);
  }
  return client;
}

function participantHoldingIngredient(table: Table, ingredientId: string): string | undefined {
  return Object.values(table.vouchers)
    .filter((voucher) => voucher.ingredientId === ingredientId && voucher.location.type === "hand" && voucher.location.participantId)
    .sort((left, right) => left.id.localeCompare(right.id))[0]?.location.participantId;
}

function firstHandIngredient(table: Table, participantId: string): string | undefined {
  const voucherId = handVoucherIds(table, participantId)[0];
  if (!voucherId) {
    return undefined;
  }
  return table.vouchers[voucherId].ingredientId;
}

function firstPlatterIngredient(table: Table, avoidIngredientId: string): string {
  const preferred = platterVoucherIds(table).find((voucherId) => table.vouchers[voucherId].ingredientId !== avoidIngredientId);
  const fallback = preferred ?? platterVoucherIds(table)[0];
  if (!fallback) {
    throw new Error("Platter has no voucher to take.");
  }
  return table.vouchers[fallback].ingredientId;
}

async function maybeDelay(profile: NetworkProfile, rng: () => number): Promise<void> {
  if (profile !== "jitter" && profile !== "bad") {
    return;
  }
  await delay(100 + Math.floor(rng() * 700));
}

async function maybeReconnect(clients: SimClient[], profile: NetworkProfile, intentCount: number, rng: () => number): Promise<void> {
  if ((profile !== "disconnect" && profile !== "bad") || intentCount % 25 !== 0) {
    return;
  }
  const client = clients[Math.floor(rng() * clients.length)];
  await client.reconnect();
}

function parseOptions(args: string[]): SimulationOptions {
  const getValue = (name: string, fallback: string) => {
    const prefix = `--${name}=`;
    return args.find((arg) => arg.startsWith(prefix))?.slice(prefix.length) ?? fallback;
  };
  const hasValue = (name: string) => {
    const prefix = `--${name}=`;
    return args.some((arg) => arg.startsWith(prefix));
  };
  const profile = getValue("profile", process.env.SIM_PROFILE ?? "local") as NetworkProfile;
  if (!["local", "jitter", "disconnect", "bad"].includes(profile)) {
    throw new Error(`Unknown profile ${profile}.`);
  }
  const gameCount = parsePositiveInt(getValue("games", process.env.SIM_GAMES ?? "1"), "Simulation game count");
  const explicitPlayers = hasValue("players") || Boolean(process.env.SIM_PLAYERS);
  const playerCount = parsePlayerCount(getValue("players", process.env.SIM_PLAYERS ?? "7"));
  const defaultPlayerMin = explicitPlayers ? String(playerCount) : gameCount > 1 ? "7" : String(playerCount);
  const defaultPlayerMax = explicitPlayers ? String(playerCount) : gameCount > 1 ? "20" : String(playerCount);
  const playerMin = parsePlayerCount(getValue("player-min", process.env.SIM_PLAYER_MIN ?? defaultPlayerMin));
  const playerMax = parsePlayerCount(getValue("player-max", process.env.SIM_PLAYER_MAX ?? defaultPlayerMax));
  if (playerMin > playerMax) {
    throw new Error("Simulation player-min must be less than or equal to player-max.");
  }
  const maxDurationMs = Number.parseInt(getValue("max-duration-ms", process.env.SIM_MAX_DURATION_MS ?? "120000"), 10);
  const suiteMaxDurationMs = parsePositiveInt(
    getValue(
      "suite-max-duration-ms",
      process.env.SIM_SUITE_MAX_DURATION_MS ?? (gameCount === 1 ? String(maxDurationMs) : String(Math.max(maxDurationMs, 300000)))
    ),
    "Simulation suite max duration"
  );
  return {
    profile,
    playerCount,
    playerMin,
    playerMax,
    gameCount,
    concurrency: Math.min(gameCount, parsePositiveInt(getValue("concurrency", process.env.SIM_CONCURRENCY ?? "4"), "Simulation concurrency")),
    dishGoal: Number.parseInt(getValue("dish-goal", process.env.SIM_DISH_GOAL ?? "4"), 10),
    maxIntents: Number.parseInt(getValue("max-intents", process.env.SIM_MAX_INTENTS ?? "5000"), 10),
    maxDurationMs,
    suiteMaxDurationMs,
    seed: getValue("seed", process.env.SIM_SEED ?? "simulation")
  };
}

function parsePlayerCount(value: string): number {
  const playerCount = Number.parseInt(value, 10);
  if (!Number.isInteger(playerCount) || playerCount < 7 || playerCount > 20) {
    throw new Error("Simulation player count must be between 7 and 20.");
  }
  return playerCount;
}

function parsePositiveInt(value: string, label: string): number {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${label} must be a positive integer.`);
  }
  return parsed;
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

function percentile(values: number[], percentileValue: number): number {
  if (values.length === 0) {
    return 0;
  }
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.ceil((percentileValue / 100) * sorted.length) - 1);
  return sorted[index];
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitUntil(predicate: () => boolean, timeoutMs: number): Promise<boolean> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (predicate()) {
      return true;
    }
    await delay(10);
  }
  return predicate();
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const app = await buildApp({ store });
  await app.listen({ host: "127.0.0.1", port: 0 });

  try {
    const address = app.server.address() as AddressInfo;
    const baseUrl = `http://127.0.0.1:${address.port}`;
    const reportDir = path.join(REPO_ROOT, "tmp", "simulations");
    await mkdir(reportDir, { recursive: true });

    if (options.gameCount === 1) {
      const report = await runSimulation(baseUrl, {
        ...options,
        playerCount: playerCountForGame(options, 0)
      });
      const reportPath = path.join(reportDir, `simulation-${report.tableCode.toLowerCase()}-${options.profile}.json`);
      await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
      console.log(`${report.ok ? "Simulation complete" : "Simulation failed"}: ${reportPath}`);
      console.log(JSON.stringify(singleSummary(report), null, 2));
      if (!report.ok) {
        process.exitCode = 1;
      }
    } else {
      const suite = await runSimulationSuite(baseUrl, options);
      const reportPath = path.join(reportDir, `simulation-suite-${options.seed.toLowerCase().replace(/[^a-z0-9-]+/g, "-")}-${options.profile}.json`);
      await writeFile(reportPath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
      console.log(`${suite.ok ? "Simulation suite complete" : "Simulation suite failed"}: ${reportPath}`);
      console.log(JSON.stringify(suiteSummary(suite), null, 2));
      if (!suite.ok) {
        process.exitCode = 1;
      }
    }
  } finally {
    await app.close();
  }
}

await main();

function singleSummary(report: SimulationReport): Record<string, unknown> {
  return {
    ok: report.ok,
    error: report.error,
    timedOut: report.timedOut,
    lastStage: report.lastStage,
    tableCode: report.tableCode,
    profile: report.profile,
    playerCount: report.playerCount,
    phase: report.phase,
    totalIntents: report.totalIntents,
    totalBytesReceived: report.totalBytesReceived,
    maxFrameBytes: report.maxFrameBytes,
    p95FrameBytes: report.p95FrameBytes,
    maxDeltaFrameBytes: report.maxDeltaFrameBytes,
    p95DeltaFrameBytes: report.p95DeltaFrameBytes,
    completionMs: report.completionMs
  };
}

function suiteSummary(suite: Awaited<ReturnType<typeof runSimulationSuite>>): Record<string, unknown> {
  return {
    ok: suite.ok,
    profile: suite.profile,
    gameCount: suite.gameCount,
    concurrency: suite.concurrency,
    playerMin: suite.playerMin,
    playerMax: suite.playerMax,
    dishGoal: suite.dishGoal,
    suiteMaxDurationMs: suite.suiteMaxDurationMs,
    suiteTimedOut: suite.suiteTimedOut,
    completedGames: suite.completedGames,
    failedGames: suite.failedGames,
    reportedGames: suite.reportedGames,
    incompleteGames: suite.incompleteGames,
    totalPlayers: suite.totalPlayers,
    totalIntents: suite.totalIntents,
    totalBytesReceived: suite.totalBytesReceived,
    maxFrameBytes: suite.maxFrameBytes,
    p95FrameBytes: suite.p95FrameBytes,
    maxDeltaFrameBytes: suite.maxDeltaFrameBytes,
    p95DeltaFrameBytes: suite.p95DeltaFrameBytes,
    reconnects: suite.reconnects,
    rejectedIntents: suite.rejectedIntents,
    intentTimeouts: suite.intentTimeouts,
    completionMs: suite.completionMs
  };
}
