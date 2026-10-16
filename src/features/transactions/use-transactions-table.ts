import {
  columnFilteringFeature,
  constructFilterFn,
  createFilteredRowModel,
  createSortedRowModel,
  filterFn_includesString,
  rowSortingFeature,
  sortFn_basic,
  sortFn_text,
  tableFeatures,
  useTable,
  type ColumnDef,
} from "@tanstack/vue-table"
import { computed, type Ref } from "vue"

import type { TransactionListItem } from "./transaction"

const filterFn_isAnyOf = constructFilterFn({
  filter: (dataValue, filterValue) =>
    Array.isArray(filterValue) && filterValue.includes(String(dataValue)),
  autoRemove: (value) => !Array.isArray(value) || value.length === 0,
})

const features = tableFeatures({
  columnFilteringFeature,
  rowSortingFeature,
  filteredRowModel: createFilteredRowModel(),
  sortedRowModel: createSortedRowModel(),
  filterFns: {
    isAnyOf: filterFn_isAnyOf,
    includesString: filterFn_includesString,
  },
  sortFns: {
    basic: sortFn_basic,
    text: sortFn_text,
  },
})

type TransactionTableFeatures = typeof features
type MultiFilterColumnId = "institution" | "category"

const columns: ColumnDef<
  TransactionTableFeatures,
  TransactionListItem,
  unknown
>[] = [
  {
    accessorKey: "institution",
    header: "Instituição",
    filterFn: "isAnyOf",
    enableSorting: false,
  },
  {
    accessorKey: "date",
    header: "Data",
    enableColumnFilter: false,
    sortFn: "text",
    sortDescFirst: false,
  },
  {
    accessorKey: "category",
    header: "Categoria",
    filterFn: "isAnyOf",
    enableSorting: false,
  },
  {
    accessorKey: "description",
    header: "Descrição",
    filterFn: "includesString",
    enableSorting: false,
  },
  {
    id: "amount",
    accessorFn: (transaction) => transaction.amountCents / 100,
    header: "Valor",
    enableColumnFilter: false,
    sortFn: "basic",
    sortDescFirst: false,
  },
]

export function useTransactionsTable(items: Ref<TransactionListItem[]>) {
  const table = useTable({
    features,
    columns,
    data: items,
    initialState: {
      sorting: [{ id: "date", desc: true }],
    },
  })

  const visibleCount = computed(() => table.getRowModel().rows.length)
  const hasFilters = computed(() => table.atoms.columnFilters.get().length > 0)

  function toggleSorting(columnId: "date" | "amount") {
    table.getColumn(columnId)?.toggleSorting()
  }

  function sortingLabel(columnId: "date" | "amount", label: string) {
    const direction = table.getColumn(columnId)?.getIsSorted()
    if (direction === "asc")
      return `${label}: ordem crescente. Alterar ordenação`
    if (direction === "desc")
      return `${label}: ordem decrescente. Alterar ordenação`
    return `Ordenar por ${label.toLocaleLowerCase("pt-BR")}`
  }

  function selectedFilterValues(columnId: MultiFilterColumnId) {
    const value = table.getColumn(columnId)?.getFilterValue()
    return Array.isArray(value)
      ? value.filter((item): item is string => typeof item === "string")
      : []
  }

  function selectFilter(columnId: MultiFilterColumnId, value: string) {
    const column = table.getColumn(columnId)
    const current = selectedFilterValues(columnId)
    const next = current.includes(value)
      ? current.filter((item) => item !== value)
      : [...current, value]

    column?.setFilterValue(next.length > 0 ? next : undefined)
  }

  function clearFilter(columnId: MultiFilterColumnId) {
    table.getColumn(columnId)?.setFilterValue(undefined)
  }

  return {
    clearFilter,
    hasFilters,
    selectFilter,
    selectedFilterValues,
    sortingLabel,
    table,
    toggleSorting,
    visibleCount,
  }
}
