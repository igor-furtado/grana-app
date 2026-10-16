import { configureStore } from "@reduxjs/toolkit"
import { useDispatch, useSelector } from "react-redux"

import transactionsReducer from "@/features/transactions/transactions-slice"

export function createAppStore() {
  return configureStore({
    reducer: {
      transactions: transactionsReducer,
    },
  })
}

export type AppStore = ReturnType<typeof createAppStore>
export type RootState = ReturnType<AppStore["getState"]>
export type AppDispatch = AppStore["dispatch"]

export const useAppDispatch = useDispatch.withTypes<AppDispatch>()
export const useAppSelector = useSelector.withTypes<RootState>()
