<script setup lang="ts">
import type { HoverCardContentProps } from "reka-ui"
import type { HTMLAttributes } from "vue"
import { reactiveOmit } from "@vueuse/core"
import { cn } from "cn"
import { HoverCardContent, HoverCardPortal, useForwardProps } from "reka-ui"

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<HoverCardContentProps & { class?: HTMLAttributes["class"] }>(),
  {
    align: "center",
    sideOffset: 4,
  }
)
const delegatedProps = reactiveOmit(props, "class")
const forwarded = useForwardProps(delegatedProps)
</script>

<template>
  <HoverCardPortal>
    <HoverCardContent
      data-slot="hover-card-content"
      v-bind="{ ...$attrs, ...forwarded }"
      :class="
        cn(
          'z-50 w-64 origin-(--reka-hover-card-content-transform-origin) rounded-lg bg-popover p-2.5 text-sm text-popover-foreground shadow-md ring-1 ring-foreground/10 outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95',
          props.class
        )
      "
    >
      <slot />
    </HoverCardContent>
  </HoverCardPortal>
</template>
