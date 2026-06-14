import { buildSnapshot } from "./snapshots.js";
import type { Table } from "./types.js";

export interface HubConnection {
  id: string;
  tableCode: string;
  participantId: string;
  send: (payload: string) => void;
}

export class ConnectionHub {
  private readonly tableConnections = new Map<string, Map<string, HubConnection>>();
  private nextId = 1;

  register(connection: Omit<HubConnection, "id">): HubConnection {
    const registered: HubConnection = {
      ...connection,
      tableCode: connection.tableCode.toUpperCase(),
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
      const snapshot = buildSnapshot(table, connection.participantId);
      connection.send(JSON.stringify({ type: "snapshot", snapshot }));
    }
  }

  connectionCount(tableCode: string): number {
    return this.tableConnections.get(tableCode.toUpperCase())?.size ?? 0;
  }
}
