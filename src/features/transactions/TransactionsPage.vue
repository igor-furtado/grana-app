<script setup lang="ts">
import { ArrowDownIcon, PlusIcon, RotateCcwIcon, SearchIcon } from "@lucide/vue"
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
import { storeToRefs } from "pinia"
import { computed, ref } from "vue"

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

import MultiSelectColumnFilter from "./MultiSelectColumnFilter.vue"
import TransactionFormDialog from "./TransactionFormDialog.vue"
import TransactionRow from "./TransactionRow.vue"
import {
  transactionCategories,
  transactionInstitutions,
} from "./transaction-options"
import type { TransactionDraft, TransactionListItem } from "./transaction"
import { useTransactionsStore } from "./transactions-store"

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

const store = useTransactionsStore()
const { items } = storeToRefs(store)
const table = useTable({
  features,
  columns,
  data: items,
  initialState: {
    sorting: [{ id: "date", desc: true }],
  },
})

const formOpen = ref(false)
const editing = ref<TransactionListItem | null>(null)
const deleting = ref<TransactionListItem | null>(null)
const visibleCount = computed(() => table.getRowModel().rows.length)
const countText = computed(
  () =>
    `${visibleCount.value} ${
      visibleCount.value === 1
        ? "transação encontrada"
        : "transações encontradas"
    }`
)
const hasFilters = computed(() => table.atoms.columnFilters.get().length > 0)

function openNewTransaction() {
  editing.value = null
  formOpen.value = true
}

function openTransaction(transaction: TransactionListItem) {
  editing.value = transaction
  formOpen.value = true
}

function saveTransaction(draft: TransactionDraft) {
  if (editing.value) {
    store.updateTransaction(editing.value.id, draft)
    return
  }
  store.addTransaction(draft)
}

function confirmRemoval() {
  if (deleting.value) store.removeTransaction(deleting.value.id)
  deleting.value = null
}

function handleRemovalDialog(open: boolean) {
  if (!open) queueMicrotask(() => (deleting.value = null))
}

function toggleSorting(columnId: string) {
  table.getColumn(columnId)?.toggleSorting()
}

function sortingLabel(columnId: string, label: string) {
  const direction = table.getColumn(columnId)?.getIsSorted()
  if (direction === "asc") return `${label}: ordem crescente. Alterar ordenação`
  if (direction === "desc")
    return `${label}: ordem decrescente. Alterar ordenação`
  return `Ordenar por ${label.toLocaleLowerCase("pt-BR")}`
}

type MultiFilterColumnId = "institution" | "category"

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
</script>

<template>
  <main class="min-h-svh bg-muted/30 px-4 py-6 sm:px-6 lg:px-10 lg:py-9">
    <div class="mx-auto flex w-full max-w-[1480px] flex-col gap-6">
      <header
        class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"
      >
        <div class="space-y-1">
          <p class="text-sm font-medium text-muted-foreground">
            Visão financeira
          </p>
          <h1 class="text-3xl font-semibold tracking-tight">Transações</h1>
          <p class="text-sm text-muted-foreground">{{ countText }}</p>
        </div>
        <Button size="lg" @click="openNewTransaction">
          <PlusIcon data-icon="inline-start" />
          Nova transação
        </Button>
      </header>

      <Card class="overflow-hidden py-0 shadow-sm">
        <CardContent class="p-0">
          <div class="overflow-x-auto">
            <Table class="min-w-[1120px]">
              <TableHeader>
                <TableRow class="hover:bg-transparent">
                  <TableHead class="min-w-56 pl-5">
                    <MultiSelectColumnFilter
                      label="Instituição"
                      column-label="instituição"
                      all-label="Todas as instituições"
                      :options="transactionInstitutions"
                      :selected="selectedFilterValues('institution')"
                      @clear="clearFilter('institution')"
                      @toggle="selectFilter('institution', $event)"
                    />
                  </TableHead>
                  <TableHead class="min-w-36">
                    <div class="flex items-center gap-1">
                      <Button
                        variant="ghost"
                        class="-ml-2 h-7 px-2"
                        :aria-label="sortingLabel('date', 'Data')"
                        @click="toggleSorting('date')"
                      >
                        Data
                        <ArrowDownIcon
                          :class="{
                            'rotate-180':
                              table.getColumn('date')?.getIsSorted() === 'asc',
                            'opacity-45': !table
                              .getColumn('date')
                              ?.getIsSorted(),
                          }"
                        />
                      </Button>
                    </div>
                  </TableHead>
                  <TableHead class="min-w-40">
                    <MultiSelectColumnFilter
                      label="Categoria"
                      column-label="categoria"
                      all-label="Todas as categorias"
                      :options="transactionCategories"
                      :selected="selectedFilterValues('category')"
                      @clear="clearFilter('category')"
                      @toggle="selectFilter('category', $event)"
                    />
                  </TableHead>
                  <TableHead class="min-w-64">
                    <div class="flex items-center gap-2">
                      <span class="shrink-0">Descrição</span>
                      <div class="relative">
                        <SearchIcon
                          aria-hidden="true"
                          class="pointer-events-none absolute top-1/2 left-2 size-3.5 -translate-y-1/2 text-muted-foreground"
                        />
                        <Input
                          :class="[
                            'h-7 w-40 pl-7 text-xs md:text-xs',
                            table.getColumn('description')?.getIsFiltered()
                              ? 'border-foreground/30 bg-secondary'
                              : '',
                          ]"
                          placeholder="Buscar..."
                          aria-label="Buscar descrição"
                          :model-value="
                            String(
                              table
                                .getColumn('description')
                                ?.getFilterValue() ?? ''
                            )
                          "
                          @update:model-value="
                            table
                              .getColumn('description')
                              ?.setFilterValue($event)
                          "
                        />
                      </div>
                    </div>
                  </TableHead>
                  <TableHead class="min-w-36 text-right">
                    <Button
                      variant="ghost"
                      class="-mr-2 h-7 px-2"
                      :aria-label="sortingLabel('amount', 'Valor')"
                      @click="toggleSorting('amount')"
                    >
                      Valor
                      <ArrowDownIcon
                        :class="{
                          'rotate-180':
                            table.getColumn('amount')?.getIsSorted() === 'asc',
                          'opacity-45': !table
                            .getColumn('amount')
                            ?.getIsSorted(),
                        }"
                      />
                    </Button>
                  </TableHead>
                  <TableHead class="w-24 pr-5 text-right">
                    <span>Ações</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TransactionRow
                  v-for="row in table.getRowModel().rows"
                  :key="row.id"
                  :transaction="row.original"
                  @edit="openTransaction(row.original)"
                  @remove="deleting = row.original"
                />
                <TableRow v-if="visibleCount === 0">
                  <TableCell :colspan="6" class="h-40 text-center">
                    <div class="space-y-1">
                      <p class="font-medium">Nenhuma transação encontrada</p>
                      <p class="text-sm text-muted-foreground">
                        Ajuste ou limpe os filtros das colunas.
                      </p>
                    </div>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
          <div
            class="flex items-center justify-between border-t px-5 py-3 text-xs text-muted-foreground"
          >
            <div class="flex items-center gap-3">
              <span>Dados de demonstração</span>
              <Button
                v-if="hasFilters"
                variant="ghost"
                size="xs"
                @click="table.resetColumnFilters()"
              >
                <RotateCcwIcon />
                Limpar filtros
              </Button>
            </div>
            <span>{{ countText }}</span>
          </div>
        </CardContent>
      </Card>
    </div>

    <TransactionFormDialog
      v-if="formOpen"
      :key="editing?.id ?? 'new-transaction'"
      v-model:open="formOpen"
      :transaction="editing"
      @submit="saveTransaction"
    />

    <AlertDialog :open="deleting !== null" @update:open="handleRemovalDialog">
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Excluir transação?</AlertDialogTitle>
          <AlertDialogDescription>
            {{
              deleting
                ? `“${deleting.description}” será removida dos dados desta sessão.`
                : "Esta transação será removida dos dados desta sessão."
            }}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction variant="destructive" @click="confirmRemoval">
            Excluir
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  </main>
</template>
