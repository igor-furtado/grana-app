<script setup lang="ts">
import { computed, reactive } from "vue"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Kbd } from "@/components/ui/kbd"
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
import {
  createEmptyTransactionDraft,
  transactionCategories,
  transactionInstitutions,
  transactionKindOptions,
} from "./transaction-options"

const props = defineProps<{
  open: boolean
  transaction: TransactionListItem | null
}>()

const emit = defineEmits<{
  "update:open": [open: boolean]
  submit: [draft: TransactionDraft]
}>()

const draft = reactive<TransactionDraft>({
  ...(props.transaction ?? createEmptyTransactionDraft()),
})
const isEditing = computed(() => props.transaction !== null)
const amount = computed<string | number>({
  get: () => (draft.amountCents ? draft.amountCents / 100 : ""),
  set: (value) => {
    draft.amountCents = Math.round(Number(value) * 100)
  },
})
const canSubmit = computed(() =>
  Boolean(draft.description.trim() && draft.date && draft.amountCents > 0)
)

function submit() {
  if (!canSubmit.value) return

  emit("submit", { ...draft, description: draft.description.trim() })
  emit("update:open", false)
}
</script>

<template>
  <Dialog :open="open" @update:open="$emit('update:open', $event)">
    <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-xl">
      <form @submit.prevent="submit">
        <DialogHeader>
          <DialogTitle>
            {{ isEditing ? "Editar transação" : "Nova transação" }}
          </DialogTitle>
          <DialogDescription>
            {{
              isEditing
                ? "Atualize os dados visuais desta transação."
                : "Adicione uma transação aos dados desta sessão."
            }}
          </DialogDescription>
        </DialogHeader>

        <div class="grid gap-5 py-6">
          <div class="grid gap-2">
            <Label for="description">Descrição</Label>
            <Input
              id="description"
              v-model="draft.description"
              autofocus
              placeholder="Ex.: almoço no restaurante"
            />
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="grid gap-2">
              <Label for="amount">Valor</Label>
              <Input
                id="amount"
                v-model="amount"
                type="number"
                min="0.01"
                step="0.01"
                placeholder="0,00"
              />
            </div>
            <div class="grid gap-2">
              <Label for="date">Data</Label>
              <Input id="date" v-model="draft.date" type="date" required />
            </div>
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="grid gap-2">
              <Label for="kind">Tipo</Label>
              <Select
                :model-value="draft.kind"
                @update:model-value="
                  draft.kind = String($event) as TransactionKind
                "
              >
                <SelectTrigger id="kind" class="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem
                    v-for="option in transactionKindOptions"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="grid gap-2">
              <Label for="category">Categoria</Label>
              <Select v-model="draft.category">
                <SelectTrigger id="category" class="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem
                    v-for="category in transactionCategories"
                    :key="category"
                    :value="category"
                  >
                    {{ category }}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="grid gap-2">
              <Label for="institution">Instituição</Label>
              <Select v-model="draft.institution">
                <SelectTrigger id="institution" class="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem
                    v-for="institution in transactionInstitutions"
                    :key="institution"
                    :value="institution"
                  >
                    {{ institution }}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="grid gap-2">
              <Label for="account">Conta</Label>
              <Input id="account" v-model="draft.account" />
            </div>
          </div>

          <div class="grid gap-2">
            <Label for="notes">Notas</Label>
            <Textarea
              id="notes"
              v-model="draft.notes"
              placeholder="Contexto opcional para esta transação"
            />
          </div>
        </div>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            @click="$emit('update:open', false)"
          >
            Cancelar
            <Kbd>Esc</Kbd>
          </Button>
          <Button type="submit" :disabled="!canSubmit">
            {{ isEditing ? "Salvar alterações" : "Salvar transação" }}
            <Kbd>Enter</Kbd>
          </Button>
        </DialogFooter>
      </form>
    </DialogContent>
  </Dialog>
</template>
