import type { TransactionRecord } from "./types.js";

export function transactionsToCsv(transactions: TransactionRecord[]): string {
  const lines = [["Turn", "Name", "Action", "Counterparty", "Item out", "Item back"].map(csvField).join(",")];
  for (const transaction of transactions) {
    lines.push(
      [
        transaction.turn,
        transaction.name,
        transaction.action,
        transaction.counterparty,
        transaction.itemOut,
        transaction.itemBack
      ]
        .map(csvField)
        .join(",")
    );
  }
  return `${lines.join("\n")}\n`;
}

function csvField(value: string | number): string {
  const escaped = String(value).replace(/"/g, "\"\"");
  return /[",\n]/.test(escaped) ? `"${escaped}"` : escaped;
}
