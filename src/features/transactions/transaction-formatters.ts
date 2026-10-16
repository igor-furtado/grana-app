import type { TransactionKind } from "./transaction"

const moneyFormatter = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
})

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
})

export function formatTransactionDate(date: string) {
  return dateFormatter.format(new Date(`${date}T12:00:00`))
}

export function formatTransactionAmount(
  amountCents: number,
  kind: TransactionKind
) {
  const prefix = kind === "expense" ? "−" : kind === "income" ? "+" : ""
  return `${prefix}${moneyFormatter.format(amountCents / 100)}`
}

export function transactionAmountTone(kind: TransactionKind) {
  if (kind === "income") return "text-emerald-700"
  if (kind === "transfer") return "text-blue-700"
  return "text-foreground"
}
