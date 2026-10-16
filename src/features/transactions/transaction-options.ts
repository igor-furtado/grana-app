import type { TransactionDraft, TransactionKind } from "./transaction"

export const transactionInstitutions = [
  "Inter",
  "Itaú",
  "Nubank",
  "XP",
] as const

export const transactionCategories = [
  "Alimentação",
  "Assinaturas",
  "Moradia",
  "Receitas",
  "Saúde",
  "Transferências",
  "Transporte",
] as const

export const transactionKindOptions = [
  { value: "expense", label: "Despesa" },
  { value: "income", label: "Receita" },
  { value: "transfer", label: "Transferência" },
] as const satisfies readonly { value: TransactionKind; label: string }[]

function currentCivilDate() {
  const today = new Date()
  const year = today.getFullYear()
  const month = String(today.getMonth() + 1).padStart(2, "0")
  const day = String(today.getDate()).padStart(2, "0")
  return `${year}-${month}-${day}`
}

export function createEmptyTransactionDraft(): TransactionDraft {
  return {
    institution: "Nubank",
    account: "Conta principal •• 7190",
    date: currentCivilDate(),
    category: "Alimentação",
    description: "",
    amountCents: 0,
    kind: "expense",
    notes: "",
  }
}
