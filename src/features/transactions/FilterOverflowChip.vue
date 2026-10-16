<script setup lang="ts">
import { XIcon } from "@lucide/vue"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  HoverCard,
  HoverCardContent,
  HoverCardTrigger,
} from "@/components/ui/hover-card"

defineProps<{
  columnLabel: string
  items: { id: string; label: string }[]
}>()

defineEmits<{
  remove: [id: string]
  show: []
}>()
</script>

<template>
  <HoverCard :open-delay="100" :close-delay="150">
    <HoverCardTrigger as-child>
      <Badge
        as="button"
        type="button"
        variant="secondary"
        class="cursor-default font-normal"
        :aria-label="`Mostrar ${items.length} ${items.length === 1 ? 'filtro adicional' : 'filtros adicionais'} de ${columnLabel}`"
        @pointerenter="$emit('show')"
      >
        +{{ items.length }}
      </Badge>
    </HoverCardTrigger>
    <HoverCardContent align="start" class="grid w-auto min-w-48 gap-1 p-1.5">
      <div
        v-for="item in items"
        :key="item.id"
        class="flex min-h-8 items-center justify-between gap-3 rounded-md px-2"
      >
        <span>{{ item.label }}</span>
        <Button
          variant="ghost"
          size="icon-xs"
          :aria-label="`Remover filtro de ${columnLabel}: ${item.label}`"
          @click="$emit('remove', item.id)"
        >
          <XIcon />
        </Button>
      </div>
    </HoverCardContent>
  </HoverCard>
</template>
