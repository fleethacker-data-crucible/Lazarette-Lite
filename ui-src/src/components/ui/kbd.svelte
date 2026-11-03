<script lang="ts">
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';
  let { class: className = '', children }: { class?: string; children?: Snippet } = $props();
</script>

<kbd class={cn('inline-flex h-5 min-w-5 items-center justify-center rounded border border-border-strong bg-muted px-1 font-sans text-[10.5px] font-medium text-muted-foreground', className)}>{@render children?.()}</kbd>
