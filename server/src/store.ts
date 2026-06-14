import { randomBytes, randomUUID } from "node:crypto";
import { runBots } from "./bots.js";
import { addHumanParticipant, applyIntent, createEmptyTable, disconnectParticipant, expireTimer, GameError } from "./game.js";
import { buildSnapshot } from "./snapshots.js";
import type { CreateTableResult, Intent, JoinTableResult, Participant, Snapshot, Table } from "./types.js";

export class TableStore {
  readonly tables = new Map<string, Table>();

  createTable(hostName: string, seed?: string): CreateTableResult {
    const code = this.nextCode();
    const seatToken = this.nextSeatToken();
    const table = createEmptyTable(code, seed ?? randomUUID(), hostName, seatToken);
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

  getSnapshotByToken(code: string, seatToken: string): Snapshot {
    const table = this.requireTable(code);
    const participant = this.connectParticipantByToken(code, seatToken);
    return buildSnapshot(table, participant.id);
  }

  getSnapshotForParticipantId(code: string, participantId: string): Snapshot {
    const table = this.requireTable(code);
    if (!table.participants[participantId]) {
      throw new GameError("Participant not found.", "missing_participant");
    }
    return buildSnapshot(table, participantId);
  }

  handleIntent(code: string, seatToken: string, intent: Intent, runBotTurns = true): Snapshot {
    const table = this.requireTable(code);
    const participant = this.connectParticipantByToken(code, seatToken);
    applyIntent(table, participant.id, intent);
    if (runBotTurns && !table.paused && shouldRunBotsAfterIntent(intent)) {
      runBots(table);
    }
    return buildSnapshot(table, participant.id);
  }

  connectParticipantByToken(code: string, seatToken: string): Participant {
    const table = this.requireTable(code);
    const participant = this.requireParticipantByToken(table, seatToken);
    if (participant.kind === "human") {
      participant.connected = true;
    }
    return participant;
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

  private nextCode(): string {
    for (let attempt = 0; attempt < 1000; attempt += 1) {
      const code = randomBytes(4).toString("base64url").replace(/[^A-Z0-9]/gi, "").slice(0, 6).toUpperCase();
      if (code.length >= 4 && !this.tables.has(code)) {
        return code;
      }
    }
    throw new GameError("Could not allocate invite code.", "code_allocation_failed");
  }

  private nextSeatToken(): string {
    return randomUUID();
  }
}

function shouldRunBotsAfterIntent(intent: Intent): boolean {
  if (intent.type === "leave_table" || intent.type === "close_table" || intent.type === "reset_table") {
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
