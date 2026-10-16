export type TransactionKind = "income" | "expense" | "transfer"

export type TransactionListItem = {
  id: string
  institution: string
  account: string
  date: string
  category: string
  description: string
  amountCents: number
  kind: TransactionKind
  notes?: string
}

export type TransactionDraft = Omit<TransactionListItem, "id">
