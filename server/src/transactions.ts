import type { TransactionRecord } from "./types.js";

export function transactionsToCsv(transactions: TransactionRecord[]): string {
  const lines = [["Name", "Action", "Counterparty", "Item out", "Item back"].map(csvField).join(",")];
  for (const transaction of transactions) {
    lines.push(
      [
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

function csvField(value: string): string {
  const escaped = value.replace(/"/g, "\"\"");
  return /[",\n]/.test(escaped) ? `"${escaped}"` : escaped;
}
