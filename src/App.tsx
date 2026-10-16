import { useState } from "react"
import { Provider } from "react-redux"

import { TransactionsPage } from "@/features/transactions/transactions-page"
import { createAppStore } from "@/store"

export function App() {
  const [store] = useState(createAppStore)

  return (
    <Provider store={store}>
      <TransactionsPage />
    </Provider>
  )
}

export default App
