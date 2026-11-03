<script lang="ts">
  // Tooltip around any trigger (bits-ui Tooltip). Content is plain text.
  import { Tooltip } from 'bits-ui';
  import type { Snippet } from 'svelte';

  let { text, side = 'top', children }: { text: string; side?: 'top' | 'bottom' | 'left' | 'right'; children: Snippet<[Record<string, unknown>]> } = $props();
</script>

<Tooltip.Root delayDuration={350}>
  <Tooltip.Trigger>
    {#snippet child({ props })}{@render children(props)}{/snippet}
  </Tooltip.Trigger>
  <Tooltip.Portal>
    <Tooltip.Content {side} sideOffset={6} class="z-[70] rounded-md border border-border-strong bg-popover px-2 py-1 text-[11.5px] text-foreground shadow-[var(--shadow-pop)] data-[state=delayed-open]:animate-fade-in">
      {text}
    </Tooltip.Content>
  </Tooltip.Portal>
</Tooltip.Root>
