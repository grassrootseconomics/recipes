import { randomBytes, randomUUID } from "node:crypto";
import { runBots } from "./bots.js";
import { addHumanParticipant, applyIntent, createEmptyTable, disconnectParticipant, expireTimer, GameError } from "./game.js";
import { buildSnapshot } from "./snapshots.js";
import type { CreateTableResult, Intent, JoinTableResult, Participant, PublicTableSummary, Snapshot, Table, TransactionRecord } from "./types.js";

export class TableStore {
  readonly tables = new Map<string, Table>();

  createTable(hostName: string, seed?: string, requestedCode?: string, isPublic = true): CreateTableResult {
    const code = requestedCode ? this.reserveRequestedCode(requestedCode) : this.nextCode();
    const seatToken = this.nextSeatToken();
    const table = createEmptyTable(code, seed ?? randomUUID(), hostName, seatToken, isPublic);
    this.tables.set(code, table);
    const participant = table.participants[table.hostParticipantId];
    return {
      table,
      participant,
      seatToken,
      snapshot: buildSnapshot(table, participant.id)
    };
  }

  joinTable(code: string, name: string, asWitness = false): JoinTableResult {
    const table = this.requireTable(code);
    const seatToken = this.nextSeatToken();
    const participant = addHumanParticipant(table, name, seatToken, asWitness);
    return {
      table,
      participant,
      seatToken,
      snapshot: buildSnapshot(table, participant.id)
    };
  }

  getTableStatus(code: string): { code: string; valid: boolean; exists: boolean; joinable: boolean; reason?: "invalid" | "started" | "full" } {
    const normalized = code.trim().toUpperCase();
    if (!/^[A-Z0-9-]{4,24}$/.test(normalized)) {
      return { code: normalized, valid: false, exists: false, joinable: false, reason: "invalid" };
    }
    const table = this.tables.get(normalized);
    if (!table) {
      return { code: normalized, valid: true, exists: false, joinable: false };
    }
    const openBotSeat = Object.values(table.participants).some(
      (participant) => participant.role === "active" && participant.kind === "bot"
    );
    const joinable = table.phase === "lobby" && openBotSeat;
    return {
      code: normalized,
      valid: true,
      exists: true,
      joinable,
      reason: joinable ? undefined : table.phase === "lobby" ? "full" : "started"
    };
  }

  listPublicJoinableTables(): PublicTableSummary[] {
    return [...this.tables.values()]
      .filter((table) => table.isPublic && table.phase === "lobby" && openBotSeatCount(table) > 0)
      .sort((left, right) => left.code.localeCompare(right.code))
      .map((table) => {
        const participants = Object.values(table.participants);
        const activeParticipants = participants.filter((participant) => participant.role === "active");
        return {
          code: table.code,
          hostName: table.participants[table.hostParticipantId]?.name ?? "Host",
          activeSeats: activeParticipants.length,
          humanSeats: activeParticipants.filter((participant) => participant.kind === "human").length,
          openSeats: openBotSeatCount(table)
        };
      });
  }

  getSnapshotByToken(code: string, seatToken: string, viewerParticipantId?: string): Snapshot {
    const table = this.requireTable(code);
    const participant = this.connectParticipantByToken(code, seatToken);
    const viewer = viewerParticipantId ? this.requireControlledParticipant(table, participant.id, viewerParticipantId) : participant;
    return buildSnapshot(table, viewer.id, participant.id);
  }

  getTransactionsByToken(code: string, seatToken: string): TransactionRecord[] {
    const table = this.requireTable(code);
    this.requireParticipantByToken(table, seatToken);
    return [...(table.transactionHistory ?? [])];
  }

  getSnapshotForParticipantId(code: string, participantId: string): Snapshot {
    const table = this.requireTable(code);
    if (!table.participants[participantId]) {
      throw new GameError("Participant not found.", "missing_participant");
    }
    return buildSnapshot(table, participantId);
  }

  handleIntent(
    code: string,
    seatToken: string,
    intent: Intent,
    runBotTurns = true,
    actorParticipantId?: string,
    onMutation?: (table: Table) => void
  ): Snapshot {
    const table = this.requireTable(code);
    const connectionParticipant = this.connectParticipantByToken(code, seatToken);
    const actor = actorParticipantId
      ? this.requireControlledParticipant(table, connectionParticipant.id, actorParticipantId)
      : connectionParticipant;
    applyIntent(table, actor.id, intent);
    onMutation?.(table);
    if (runBotTurns && !table.paused && shouldRunBotsAfterIntent(intent)) {
      runBots(table, undefined, () => onMutation?.(table));
    }
    return buildSnapshot(table, actor.id, connectionParticipant.id);
  }

  connectParticipantByToken(code: string, seatToken: string): Participant {
    const table = this.requireTable(code);
    const participant = this.requireParticipantByToken(table, seatToken);
    if (participant.kind === "human") {
      const wasConnected = participant.connected;
      participant.connected = true;
      if (!wasConnected) {
        table.version += 1;
      }
    }
    return participant;
  }

  controlledParticipantIds(table: Table, controllerParticipantId: string): string[] {
    return table.participantOrder.filter((participantId) => table.participants[participantId]?.controllerParticipantId === controllerParticipantId);
  }

  canControlParticipant(table: Table, controllerParticipantId: string, actorParticipantId: string): boolean {
    return actorParticipantId === controllerParticipantId || table.participants[actorParticipantId]?.controllerParticipantId === controllerParticipantId;
  }

  disconnectParticipantByToken(code: string, seatToken: string): Participant | undefined {
    const table = this.requireTable(code);
    const participant = Object.values(table.participants).find((candidate) => candidate.seatToken === seatToken);
    if (!participant) {
      return undefined;
    }
    disconnectParticipant(table, participant);
    return participant;
  }

  expireTimer(code: string, nowMs = Date.now()): boolean {
    return expireTimer(this.requireTable(code), nowMs);
  }

  requireTable(code: string): Table {
    const table = this.tables.get(code.toUpperCase());
    if (!table) {
      throw new GameError("Table not found.", "missing_table");
    }
    return table;
  }

  private requireParticipantByToken(table: Table, seatToken: string) {
    const participant = Object.values(table.participants).find((candidate) => candidate.seatToken === seatToken);
    if (!participant) {
      throw new GameError("Invalid seat token.", "invalid_seat_token");
    }
    return participant;
  }

  private requireControlledParticipant(table: Table, controllerParticipantId: string, actorParticipantId: string): Participant {
    const actor = table.participants[actorParticipantId];
    if (!actor) {
      throw new GameError("Participant not found.", "missing_participant");
    }
    if (!this.canControlParticipant(table, controllerParticipantId, actorParticipantId)) {
      throw new GameError("This connection cannot control that participant.", "not_controller");
    }
    return actor;
  }

  private nextCode(): string {
    for (let attempt = 0; attempt < 1000; attempt += 1) {
      const code = randomBytes(4).toString("base64url").replace(/[^A-Z0-9]/gi, "").slice(0, 6).toUpperCase();
      if (code.length >= 4 && !this.tables.has(code)) {
        return code;
      }
    }
    throw new GameError("Could not allocate invite code.", "code_allocation_failed");
  }

  private reserveRequestedCode(requestedCode: string): string {
    const code = requestedCode.trim().toUpperCase();
    if (!/^[A-Z0-9-]{4,24}$/.test(code)) {
      throw new GameError("Invite code must be 4-24 characters using letters, numbers, or hyphens.", "invalid_table_code");
    }
    if (this.tables.has(code)) {
      throw new GameError("Invite code is already in use. Generate another code or type a different one.", "table_code_in_use");
    }
    return code;
  }

  private nextSeatToken(): string {
    return randomUUID();
  }
}

function openBotSeatCount(table: Table): number {
  return Object.values(table.participants).filter((participant) => participant.role === "active" && participant.kind === "bot").length;
}

function shouldRunBotsAfterIntent(intent: Intent): boolean {
  if (intent.type === "start" || intent.type === "leave_table" || intent.type === "close_table" || intent.type === "reset_table") {
    return false;
  }
  if (intent.type === "respond_offer" && intent.response === "refuse") {
    return false;
  }
  if (intent.type === "cancel_offer") {
    return false;
  }
  return true;
}
