<script setup lang="ts">
import { CheckIcon, ListFilterIcon, XIcon } from "@lucide/vue"
import { computed, ref } from "vue"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"

import FilterOverflowChip from "./FilterOverflowChip.vue"

const props = defineProps<{
  allLabel: string
  columnLabel: string
  label: string
  options: readonly string[]
  selected: string[]
}>()

const emit = defineEmits<{
  clear: []
  toggle: [value: string]
}>()

const open = ref(false)
const primaryFilter = computed(() => props.selected.slice(0, 1))
const additionalFilters = computed(() =>
  props.selected.slice(1).map((value) => ({ id: value, label: value }))
)
const filterButtonLabel = computed(() =>
  props.selected.length > 0
    ? `Alterar filtro de ${props.columnLabel}: ${props.selected.join(", ")}`
    : `Filtrar ${props.columnLabel}`
)
</script>

<template>
  <div class="flex items-center gap-1">
    <span>{{ label }}</span>
    <Popover v-model:open="open">
      <PopoverTrigger as-child>
        <Button
          :variant="selected.length > 0 ? 'secondary' : 'ghost'"
          size="icon-xs"
          :aria-label="filterButtonLabel"
        >
          <ListFilterIcon />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="start" class="w-64">
        <div class="grid gap-1">
          <Button
            variant="ghost"
            class="justify-between"
            @click="emit('clear')"
          >
            {{ allLabel }}
            <CheckIcon v-if="selected.length === 0" />
          </Button>
          <Button
            v-for="option in options"
            :key="option"
            variant="ghost"
            class="justify-between"
            @click="emit('toggle', option)"
          >
            {{ option }}
            <CheckIcon v-if="selected.includes(option)" />
          </Button>
        </div>
      </PopoverContent>
    </Popover>
    <Badge
      v-for="value in primaryFilter"
      :key="value"
      as="button"
      type="button"
      variant="secondary"
      class="max-w-28 cursor-pointer gap-1 pr-1 font-normal hover:bg-secondary/80"
      :aria-label="`Remover filtro de ${columnLabel}: ${value}`"
      @click="emit('toggle', value)"
    >
      <span class="truncate">{{ value }}</span>
      <XIcon aria-hidden="true" />
    </Badge>
    <FilterOverflowChip
      v-if="additionalFilters.length > 0"
      :column-label="columnLabel"
      :items="additionalFilters"
      @show="open = false"
      @remove="emit('toggle', $event)"
    />
  </div>
</template>
