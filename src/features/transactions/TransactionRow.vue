<script setup lang="ts">
import { PencilIcon, Trash2Icon } from "@lucide/vue"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { TableCell, TableRow } from "@/components/ui/table"

import type { TransactionListItem } from "./transaction"
import {
  formatTransactionAmount,
  formatTransactionDate,
  transactionAmountTone,
} from "./transaction-formatters"

defineProps<{
  transaction: TransactionListItem
}>()

defineEmits<{
  edit: []
  remove: []
}>()
</script>

<template>
  <TableRow>
    <TableCell class="pl-5">
      <div class="flex items-center gap-3">
        <div
          class="flex size-9 shrink-0 items-center justify-center rounded-lg border bg-muted text-[11px] font-semibold"
        >
          {{ transaction.institution.slice(0, 2) }}
        </div>
        <div class="min-w-0">
          <p class="truncate font-medium">{{ transaction.institution }}</p>
          <p class="truncate text-xs text-muted-foreground">
            {{ transaction.account }}
          </p>
        </div>
      </div>
    </TableCell>
    <TableCell class="text-sm text-muted-foreground">
      {{ formatTransactionDate(transaction.date) }}
    </TableCell>
    <TableCell>
      <Badge variant="secondary" class="font-normal">
        {{ transaction.category }}
      </Badge>
    </TableCell>
    <TableCell>
      <p class="font-medium">{{ transaction.description }}</p>
      <p
        v-if="transaction.notes"
        class="mt-0.5 line-clamp-1 text-xs text-muted-foreground"
      >
        {{ transaction.notes }}
      </p>
    </TableCell>
    <TableCell
      class="text-right font-mono text-sm font-medium tabular-nums"
      :class="transactionAmountTone(transaction.kind)"
    >
      {{ formatTransactionAmount(transaction.amountCents, transaction.kind) }}
    </TableCell>
    <TableCell class="pr-5">
      <div class="flex justify-end gap-1">
        <Button
          variant="ghost"
          size="icon-sm"
          :aria-label="`Editar ${transaction.description}`"
          @click="$emit('edit')"
        >
          <PencilIcon />
        </Button>
        <Button
          variant="ghost"
          size="icon-sm"
          :aria-label="`Excluir ${transaction.description}`"
          @click="$emit('remove')"
        >
          <Trash2Icon />
        </Button>
      </div>
    </TableCell>
  </TableRow>
</template>
