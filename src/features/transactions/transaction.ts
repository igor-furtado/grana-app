export type TransactionKind = "income" | "expense" | "transfer"

export type TransactionListItem = {
  id: string
  institution: string
  institutionInitials: string
  account: string
  date: string
  category: string
  description: string
  amountCents: number
  kind: TransactionKind
  notes?: string
}

export type TransactionDraft = Omit<
  TransactionListItem,
  "id" | "institutionInitials"
>

export type TransactionFilters = {
  search: string
  institution: string
  category: string
  period: string
  kind: "all" | TransactionKind
}
