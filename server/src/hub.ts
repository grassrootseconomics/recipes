import { buildSnapshot } from "./snapshots.js";
import type { Dish, PublicParticipant, Snapshot, SnapshotDelta, Table, TransactionRecord } from "./types.js";

export interface HubConnection {
  id: string;
  tableCode: string;
  participantId: string;
  connectionParticipantId: string;
  send: (payload: string) => void;
  lastVersion?: number;
  lastTransactionCursor?: number;
  lastSnapshot?: Snapshot;
}

export class ConnectionHub {
  private readonly tableConnections = new Map<string, Map<string, HubConnection>>();
  private nextId = 1;

  register(connection: Omit<HubConnection, "id" | "connectionParticipantId"> & { connectionParticipantId?: string }): HubConnection {
    const registered: HubConnection = {
      ...connection,
      tableCode: connection.tableCode.toUpperCase(),
      connectionParticipantId: connection.connectionParticipantId ?? connection.participantId,
      id: `conn_${this.nextId}`
    };
    this.nextId += 1;
    const connections = this.tableConnections.get(registered.tableCode) ?? new Map<string, HubConnection>();
    connections.set(registered.id, registered);
    this.tableConnections.set(registered.tableCode, connections);
    return registered;
  }

  unregister(tableCode: string, connectionId: string): void {
    const normalizedCode = tableCode.toUpperCase();
    const connections = this.tableConnections.get(normalizedCode);
    if (!connections) {
      return;
    }
    connections.delete(connectionId);
    if (connections.size === 0) {
      this.tableConnections.delete(normalizedCode);
    }
  }

  broadcastTable(table: Table): void {
    const connections = this.tableConnections.get(table.code.toUpperCase());
    if (!connections) {
      return;
    }
    for (const connection of connections.values()) {
      const snapshot = buildSnapshot(table, connection.participantId, connection.connectionParticipantId);
      if (shouldSendSnapshot(connection, table)) {
        connection.send(JSON.stringify({ type: "snapshot", snapshot }));
      } else {
        connection.send(JSON.stringify(buildDelta(table, connection, snapshot)));
      }
      connection.lastVersion = table.version;
      connection.lastTransactionCursor = table.transactionHistory?.length ?? 0;
      connection.lastSnapshot = snapshot;
    }
  }

  connectionCount(tableCode: string): number {
    return this.tableConnections.get(tableCode.toUpperCase())?.size ?? 0;
  }

  hasConnectionForParticipant(tableCode: string, connectionParticipantId: string): boolean {
    const connections = this.tableConnections.get(tableCode.toUpperCase());
    if (!connections) {
      return false;
    }
    for (const connection of connections.values()) {
      if (connection.connectionParticipantId === connectionParticipantId) {
        return true;
      }
    }
    return false;
  }

  sendSnapshot(table: Table, connection: HubConnection): void {
    const snapshot = buildSnapshot(table, connection.participantId, connection.connectionParticipantId);
    connection.send(JSON.stringify({ type: "snapshot", snapshot }));
    connection.lastVersion = table.version;
    connection.lastTransactionCursor = table.transactionHistory?.length ?? 0;
    connection.lastSnapshot = snapshot;
  }
}

function shouldSendSnapshot(connection: HubConnection, table: Table): boolean {
  const transactionCursor = table.transactionHistory?.length ?? 0;
  return (
    connection.lastVersion === undefined ||
    connection.lastSnapshot === undefined ||
    connection.lastVersion > table.version ||
    (connection.lastTransactionCursor ?? 0) > transactionCursor
  );
}

function buildDelta(table: Table, connection: HubConnection, snapshot: Snapshot): SnapshotDelta {
  const baseVersion = connection.lastVersion ?? table.version;
  const previousTransactionCursor = connection.lastTransactionCursor ?? 0;
  const appendedTransactions = (table.transactionHistory ?? []).slice(previousTransactionCursor).map(cloneTransaction);
  const changedDishes = changedDishRows(connection.lastSnapshot, snapshot);
  const changedParticipants = changedParticipantRows(connection.lastSnapshot, snapshot);
  const patch = diffSnapshot(connection.lastSnapshot, snapshot);
  compactDeltaPatch(patch, snapshot);

  return {
    type: "delta",
    tableCode: table.code,
    viewerParticipantId: connection.participantId,
    baseVersion,
    version: table.version,
    patch,
    append: {
      transactionHistory: appendedTransactions,
      dishes: changedDishes,
      participants: changedParticipants
    }
  };
}

function compactDeltaPatch(patch: Partial<Snapshot>, snapshot: Snapshot): void {
  delete patch.participants;
  delete patch.dishes;
  delete patch.dishParts;
  if (snapshot.phase !== "settlement") {
    delete patch.ownFoodParts;
    delete patch.platterFoodParts;
  }
}

function changedDishRows(previous: Snapshot | undefined, next: Snapshot): Dish[] {
  if (!previous) {
    return next.dishes.map(cloneDish);
  }
  const previousById = new Map(previous.dishes.map((dish) => [dish.id, JSON.stringify(dish)]));
  return next.dishes.filter((dish) => previousById.get(dish.id) !== JSON.stringify(dish)).map(cloneDish);
}

function changedParticipantRows(previous: Snapshot | undefined, next: Snapshot): PublicParticipant[] {
  if (!previous) {
    return next.participants.map(cloneParticipant);
  }
  const previousById = new Map(previous.participants.map((participant) => [participant.id, JSON.stringify(participant)]));
  return next.participants
    .filter((participant) => previousById.get(participant.id) !== JSON.stringify(participant))
    .map(cloneParticipant);
}

function diffSnapshot(previous: Snapshot | undefined, next: Snapshot): Partial<Snapshot> {
  if (!previous) {
    const fullPatch: Partial<Snapshot> = { ...next };
    delete fullPatch.transactionHistory;
    delete fullPatch.ingredients;
    return fullPatch;
  }

  const patch: Partial<Snapshot> = {};
  for (const [key, value] of Object.entries(next) as Array<[keyof Snapshot, Snapshot[keyof Snapshot]]>) {
    if (key === "transactionHistory" || key === "ingredients") {
      continue;
    }
    if (JSON.stringify(previous[key]) !== JSON.stringify(value)) {
      (patch as Record<string, unknown>)[key] = value;
    }
  }
  return patch;
}

function cloneTransaction(transaction: TransactionRecord): TransactionRecord {
  return { ...transaction };
}

function cloneDish(dish: Dish): Dish {
  return { ...dish, biteCounts: { ...dish.biteCounts } };
}

function cloneParticipant(participant: PublicParticipant): PublicParticipant {
  return { ...participant };
}
