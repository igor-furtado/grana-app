import { useMemo, useState, type ReactNode } from "react"
import {
  ArrowDownUp,
  CalendarDays,
  Landmark,
  Pencil,
  Plus,
  Search,
  Shapes,
  Trash2,
} from "lucide-react"

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
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { useAppDispatch, useAppSelector } from "@/store"

import { TransactionFormDialog } from "./transaction-form-dialog"
import type { TransactionDraft, TransactionListItem } from "./transaction"
import {
  filterChanged,
  transactionAdded,
  transactionRemoved,
  transactionUpdated,
} from "./transactions-slice"

const moneyFormatter = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
})

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
})

export function TransactionsPage() {
  const dispatch = useAppDispatch()
  const { items, filters } = useAppSelector((state) => state.transactions)
  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<TransactionListItem | null>(null)
  const [deleting, setDeleting] = useState<TransactionListItem | null>(null)

  const institutions = useMemo(
    () => [...new Set(items.map((item) => item.institution))].sort(),
    [items]
  )
  const categories = useMemo(
    () => [...new Set(items.map((item) => item.category))].sort(),
    [items]
  )
  const visibleItems = useMemo(() => {
    const query = filters.search.trim().toLocaleLowerCase("pt-BR")

    return items
      .filter((item) => {
        const searchable = [
          item.description,
          item.category,
          item.account,
          item.institution,
        ]
          .join(" ")
          .toLocaleLowerCase("pt-BR")

        return (
          (!query || searchable.includes(query)) &&
          (filters.institution === "all" ||
            item.institution === filters.institution) &&
          (filters.category === "all" || item.category === filters.category) &&
          (filters.kind === "all" || item.kind === filters.kind) &&
          (filters.period === "all" || item.date.startsWith(filters.period))
        )
      })
      .sort((left, right) => right.date.localeCompare(left.date))
  }, [filters, items])

  const countText = `${visibleItems.length} ${
    visibleItems.length === 1
      ? "transação encontrada"
      : "transações encontradas"
  }`

  function openNewTransaction() {
    setEditing(null)
    setFormOpen(true)
  }

  function openTransaction(transaction: TransactionListItem) {
    setEditing(transaction)
    setFormOpen(true)
  }

  function saveTransaction(draft: TransactionDraft) {
    if (editing) {
      dispatch(transactionUpdated({ id: editing.id, draft }))
      return
    }
    dispatch(transactionAdded(draft))
  }

  return (
    <main className="min-h-svh bg-muted/30 px-4 py-6 sm:px-6 lg:px-10 lg:py-9">
      <div className="mx-auto flex w-full max-w-[1480px] flex-col gap-6">
        <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div className="space-y-1">
            <p className="text-sm font-medium text-muted-foreground">
              Visão financeira
            </p>
            <h1 className="text-3xl font-semibold tracking-tight">
              Transações
            </h1>
            <p className="text-sm text-muted-foreground">{countText}</p>
          </div>
          <Button size="lg" onClick={openNewTransaction}>
            <Plus data-icon="inline-start" />
            Nova transação
          </Button>
        </header>

        <Card className="overflow-hidden py-0 shadow-sm">
          <div className="border-b bg-card p-4 lg:p-5">
            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-[minmax(260px,1.7fr)_repeat(4,minmax(150px,1fr))]">
              <div className="relative">
                <Search className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  className="pl-9"
                  value={filters.search}
                  placeholder="Descrição, categoria ou conta"
                  onChange={(event) =>
                    dispatch(
                      filterChanged({
                        key: "search",
                        value: event.target.value,
                      })
                    )
                  }
                />
              </div>
              <FilterSelect
                icon={<Landmark />}
                value={filters.institution}
                placeholder="Instituição"
                options={institutions.map((institution) => [
                  institution,
                  institution,
                ])}
                allLabel="Todas instituições"
                onValueChange={(value) =>
                  dispatch(filterChanged({ key: "institution", value }))
                }
              />
              <FilterSelect
                icon={<Shapes />}
                value={filters.category}
                placeholder="Categoria"
                options={categories.map((category) => [category, category])}
                allLabel="Todas categorias"
                onValueChange={(value) =>
                  dispatch(filterChanged({ key: "category", value }))
                }
              />
              <FilterSelect
                icon={<CalendarDays />}
                value={filters.period}
                placeholder="Período"
                options={[
                  ["2026-10", "Outubro de 2026"],
                  ["2026", "Ano de 2026"],
                ]}
                allLabel="Todo período"
                onValueChange={(value) =>
                  dispatch(filterChanged({ key: "period", value }))
                }
              />
              <FilterSelect
                icon={<ArrowDownUp />}
                value={filters.kind}
                placeholder="Tipo"
                options={[
                  ["expense", "Despesas"],
                  ["income", "Receitas"],
                  ["transfer", "Transferências"],
                ]}
                allLabel="Todos os tipos"
                onValueChange={(value) =>
                  dispatch(
                    filterChanged({
                      key: "kind",
                      value: value as "all" | "expense" | "income" | "transfer",
                    })
                  )
                }
              />
            </div>
          </div>

          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="min-w-56 pl-5">Instituição</TableHead>
                    <TableHead className="min-w-36">Data</TableHead>
                    <TableHead className="min-w-40">Categoria</TableHead>
                    <TableHead className="min-w-64">Descrição</TableHead>
                    <TableHead className="min-w-36 text-right">Valor</TableHead>
                    <TableHead className="w-24 pr-5 text-right">
                      Ações
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {visibleItems.length ? (
                    visibleItems.map((transaction) => (
                      <TransactionRow
                        key={transaction.id}
                        transaction={transaction}
                        onEdit={() => openTransaction(transaction)}
                        onDelete={() => setDeleting(transaction)}
                      />
                    ))
                  ) : (
                    <TableRow>
                      <TableCell colSpan={6} className="h-40 text-center">
                        <div className="space-y-1">
                          <p className="font-medium">
                            Nenhuma transação encontrada
                          </p>
                          <p className="text-sm text-muted-foreground">
                            Ajuste os filtros ou adicione uma nova transação.
                          </p>
                        </div>
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </div>
            <div className="flex items-center justify-between border-t px-5 py-3 text-xs text-muted-foreground">
              <span>Dados de demonstração</span>
              <span>{countText}</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {formOpen ? (
        <TransactionFormDialog
          key={editing?.id ?? "new-transaction"}
          open
          transaction={editing}
          onOpenChange={setFormOpen}
          onSubmit={saveTransaction}
        />
      ) : null}

      <AlertDialog
        open={deleting !== null}
        onOpenChange={(open) => !open && setDeleting(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir transação?</AlertDialogTitle>
            <AlertDialogDescription>
              {deleting
                ? `“${deleting.description}” será removida dos dados desta sessão.`
                : "Esta transação será removida dos dados desta sessão."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              variant="destructive"
              onClick={() => {
                if (deleting) dispatch(transactionRemoved(deleting.id))
                setDeleting(null)
              }}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </main>
  )
}

type FilterSelectProps = {
  icon: ReactNode
  value: string
  placeholder: string
  options: [string, string][]
  allLabel: string
  onValueChange: (value: string) => void
}

function FilterSelect({
  icon,
  value,
  placeholder,
  options,
  allLabel,
  onValueChange,
}: FilterSelectProps) {
  return (
    <Select value={value} onValueChange={onValueChange}>
      <SelectTrigger className="w-full" aria-label={placeholder}>
        <span className="flex min-w-0 items-center gap-2 [&_svg]:size-4 [&_svg]:shrink-0 [&_svg]:text-muted-foreground">
          {icon}
          <SelectValue placeholder={placeholder} />
        </span>
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="all">{allLabel}</SelectItem>
        {options.map(([optionValue, title]) => (
          <SelectItem key={optionValue} value={optionValue}>
            {title}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

type TransactionRowProps = {
  transaction: TransactionListItem
  onEdit: () => void
  onDelete: () => void
}

function TransactionRow({
  transaction,
  onEdit,
  onDelete,
}: TransactionRowProps) {
  const amountPrefix =
    transaction.kind === "expense"
      ? "−"
      : transaction.kind === "income"
        ? "+"
        : ""
  const amountTone =
    transaction.kind === "income"
      ? "text-emerald-700"
      : transaction.kind === "expense"
        ? "text-foreground"
        : "text-blue-700"

  return (
    <TableRow>
      <TableCell className="pl-5">
        <div className="flex items-center gap-3">
          <div className="flex size-9 shrink-0 items-center justify-center rounded-lg border bg-muted text-[11px] font-semibold">
            {transaction.institutionInitials}
          </div>
          <div className="min-w-0">
            <p className="truncate font-medium">{transaction.institution}</p>
            <p className="truncate text-xs text-muted-foreground">
              {transaction.account}
            </p>
          </div>
        </div>
      </TableCell>
      <TableCell className="text-sm text-muted-foreground">
        {dateFormatter.format(new Date(`${transaction.date}T12:00:00`))}
      </TableCell>
      <TableCell>
        <Badge variant="secondary" className="font-normal">
          {transaction.category}
        </Badge>
      </TableCell>
      <TableCell>
        <p className="font-medium">{transaction.description}</p>
        {transaction.notes ? (
          <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground">
            {transaction.notes}
          </p>
        ) : null}
      </TableCell>
      <TableCell
        className={`text-right font-mono text-sm font-medium tabular-nums ${amountTone}`}
      >
        {amountPrefix}
        {moneyFormatter.format(transaction.amountCents / 100)}
      </TableCell>
      <TableCell className="pr-5">
        <div className="flex justify-end gap-1">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={`Editar ${transaction.description}`}
            onClick={onEdit}
          >
            <Pencil />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={`Excluir ${transaction.description}`}
            onClick={onDelete}
          >
            <Trash2 />
          </Button>
        </div>
      </TableCell>
    </TableRow>
  )
}
