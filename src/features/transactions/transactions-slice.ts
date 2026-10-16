import { createSlice, type PayloadAction } from "@reduxjs/toolkit"

import { transactionFixtures } from "./transaction-fixtures"
import type {
  TransactionDraft,
  TransactionFilters,
  TransactionListItem,
} from "./transaction"

type TransactionsState = {
  items: TransactionListItem[]
  filters: TransactionFilters
}

const initialState: TransactionsState = {
  items: transactionFixtures,
  filters: {
    search: "",
    institution: "all",
    category: "all",
    period: "all",
    kind: "all",
  },
}

const transactionsSlice = createSlice({
  name: "transactions",
  initialState,
  reducers: {
    filterChanged: <K extends keyof TransactionFilters>(
      state: TransactionsState,
      action: PayloadAction<{ key: K; value: TransactionFilters[K] }>
    ) => {
      state.filters[action.payload.key] = action.payload.value
    },
    transactionAdded: (state, action: PayloadAction<TransactionDraft>) => {
      state.items.unshift({
        ...action.payload,
        id: globalThis.crypto?.randomUUID?.() ?? `tx-${Date.now()}`,
        institutionInitials: action.payload.institution.slice(0, 2),
      })
    },
    transactionUpdated: (
      state,
      action: PayloadAction<{ id: string; draft: TransactionDraft }>
    ) => {
      const index = state.items.findIndex(
        (item) => item.id === action.payload.id
      )
      if (index === -1) return

      state.items[index] = {
        ...state.items[index],
        ...action.payload.draft,
        institutionInitials: action.payload.draft.institution.slice(0, 2),
      }
    },
    transactionRemoved: (state, action: PayloadAction<string>) => {
      state.items = state.items.filter((item) => item.id !== action.payload)
    },
  },
})

export const {
  filterChanged,
  transactionAdded,
  transactionRemoved,
  transactionUpdated,
} = transactionsSlice.actions

export default transactionsSlice.reducer
