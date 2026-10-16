import { useState, type FormEvent } from "react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

import type {
  TransactionDraft,
  TransactionKind,
  TransactionListItem,
} from "./transaction"

type TransactionFormDialogProps = {
  open: boolean
  transaction: TransactionListItem | null
  onOpenChange: (open: boolean) => void
  onSubmit: (draft: TransactionDraft) => void
}

const emptyDraft: TransactionDraft = {
  institution: "Nubank",
  account: "Conta principal •• 7190",
  date: "2026-10-16",
  category: "Alimentação",
  description: "",
  amountCents: 0,
  kind: "expense",
  notes: "",
}

function draftFrom(transaction: TransactionListItem | null): TransactionDraft {
  if (!transaction) return emptyDraft
  return {
    institution: transaction.institution,
    account: transaction.account,
    date: transaction.date,
    category: transaction.category,
    description: transaction.description,
    amountCents: transaction.amountCents,
    kind: transaction.kind,
    notes: transaction.notes,
  }
}

export function TransactionFormDialog({
  open,
  transaction,
  onOpenChange,
  onSubmit,
}: TransactionFormDialogProps) {
  const [draft, setDraft] = useState<TransactionDraft>(() =>
    draftFrom(transaction)
  )
  const isEditing = transaction !== null

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!draft.description.trim() || !draft.date || draft.amountCents <= 0)
      return
    onSubmit({ ...draft, description: draft.description.trim() })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <form onSubmit={submit}>
          <DialogHeader>
            <DialogTitle>
              {isEditing ? "Editar transação" : "Nova transação"}
            </DialogTitle>
            <DialogDescription>
              {isEditing
                ? "Atualize os dados visuais desta transação."
                : "Adicione uma transação aos dados desta sessão."}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-5 py-6">
            <div className="grid gap-2">
              <Label htmlFor="description">Descrição</Label>
              <Input
                id="description"
                autoFocus
                value={draft.description}
                placeholder="Ex.: almoço no restaurante"
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    description: event.target.value,
                  }))
                }
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid gap-2">
                <Label htmlFor="amount">Valor</Label>
                <Input
                  id="amount"
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={draft.amountCents ? draft.amountCents / 100 : ""}
                  placeholder="0,00"
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      amountCents: Math.round(Number(event.target.value) * 100),
                    }))
                  }
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="date">Data</Label>
                <Input
                  id="date"
                  type="date"
                  required
                  value={draft.date}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      date: event.target.value,
                    }))
                  }
                />
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <FormSelect
                label="Tipo"
                value={draft.kind}
                options={[
                  ["expense", "Despesa"],
                  ["income", "Receita"],
                  ["transfer", "Transferência"],
                ]}
                onChange={(kind) =>
                  setDraft((current) => ({
                    ...current,
                    kind: kind as TransactionKind,
                  }))
                }
              />
              <FormSelect
                label="Categoria"
                value={draft.category}
                options={[
                  ["Alimentação", "Alimentação"],
                  ["Assinaturas", "Assinaturas"],
                  ["Moradia", "Moradia"],
                  ["Receitas", "Receitas"],
                  ["Saúde", "Saúde"],
                  ["Transferências", "Transferências"],
                  ["Transporte", "Transporte"],
                ]}
                onChange={(category) =>
                  setDraft((current) => ({ ...current, category }))
                }
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <FormSelect
                label="Instituição"
                value={draft.institution}
                options={[
                  ["Nubank", "Nubank"],
                  ["Itaú", "Itaú"],
                  ["Inter", "Inter"],
                  ["XP", "XP"],
                ]}
                onChange={(institution) =>
                  setDraft((current) => ({ ...current, institution }))
                }
              />
              <div className="grid gap-2">
                <Label htmlFor="account">Conta</Label>
                <Input
                  id="account"
                  value={draft.account}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      account: event.target.value,
                    }))
                  }
                />
              </div>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="notes">Notas</Label>
              <Textarea
                id="notes"
                value={draft.notes}
                placeholder="Contexto opcional para esta transação"
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    notes: event.target.value,
                  }))
                }
              />
            </div>
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button type="button" variant="outline">
                Cancelar
              </Button>
            </DialogClose>
            <Button
              type="submit"
              disabled={
                !draft.description.trim() ||
                !draft.date ||
                draft.amountCents <= 0
              }
            >
              {isEditing ? "Salvar alterações" : "Salvar transação"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

type FormSelectProps = {
  label: string
  value: string
  options: [string, string][]
  onChange: (value: string) => void
}

function FormSelect({ label, value, options, onChange }: FormSelectProps) {
  return (
    <div className="grid gap-2">
      <Label>{label}</Label>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className="w-full">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map(([optionValue, title]) => (
            <SelectItem key={optionValue} value={optionValue}>
              {title}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}
