<script setup lang="ts">
import type { HTMLAttributes } from "vue"
import { cn } from "cn"

const props = defineProps<{
  class?: HTMLAttributes["class"]
}>()
</script>

<template>
  <kbd
    data-slot="kbd"
    :class="
      cn(
        'pointer-events-none inline-flex min-w-5 items-center justify-center rounded border border-current/15 bg-background/45 px-1 font-sans text-[0.625rem] leading-4 font-medium text-current/65 shadow-xs',
        props.class
      )
    "
  >
    <slot />
  </kbd>
</template>
