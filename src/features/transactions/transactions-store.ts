import { ref } from "vue"
import { defineStore } from "pinia"

import { transactionFixtures } from "./transaction-fixtures"
import type { TransactionDraft, TransactionListItem } from "./transaction"

export const useTransactionsStore = defineStore("transactions", () => {
  const items = ref<TransactionListItem[]>(
    transactionFixtures.map((transaction) => ({ ...transaction }))
  )
  function addTransaction(draft: TransactionDraft) {
    items.value = [
      {
        ...draft,
        id: globalThis.crypto?.randomUUID?.() ?? `tx-${Date.now()}`,
      },
      ...items.value,
    ]
  }

  function updateTransaction(id: string, draft: TransactionDraft) {
    const index = items.value.findIndex((item) => item.id === id)
    if (index === -1) return

    items.value = items.value.map((item, itemIndex) =>
      itemIndex === index ? { ...item, ...draft } : item
    )
  }

  function removeTransaction(id: string) {
    items.value = items.value.filter((item) => item.id !== id)
  }

  return {
    items,
    addTransaction,
    updateTransaction,
    removeTransaction,
  }
})
