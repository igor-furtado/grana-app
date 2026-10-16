<script setup lang="ts">
import type { HoverCardRootProps } from "reka-ui"
import { HoverCardRoot, useForwardProps } from "reka-ui"

const props = defineProps<HoverCardRootProps>()
const forwarded = useForwardProps(props)
</script>

<template>
  <HoverCardRoot data-slot="hover-card" v-bind="forwarded">
    <slot />
  </HoverCardRoot>
</template>
