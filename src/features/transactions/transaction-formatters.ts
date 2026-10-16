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

const amountPresentation: Record<
  TransactionKind,
  { prefix: string; tone: string }
> = {
  expense: { prefix: "−", tone: "text-foreground" },
  income: { prefix: "+", tone: "text-emerald-700" },
  transfer: { prefix: "", tone: "text-blue-700" },
}

export function formatTransactionDate(date: string) {
  return dateFormatter.format(new Date(`${date}T12:00:00`))
}

export function formatTransactionAmount(
  amountCents: number,
  kind: TransactionKind
) {
  return `${amountPresentation[kind].prefix}${moneyFormatter.format(amountCents / 100)}`
}

export function transactionAmountTone(kind: TransactionKind) {
  return amountPresentation[kind].tone
}
