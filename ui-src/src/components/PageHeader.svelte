<script lang="ts">
  import type { Snippet } from 'svelte';
  let { title, description = '', eyebrow = '', actions }: { title: string; description?: string; eyebrow?: string; actions?: Snippet } = $props();
</script>

<header class="flex flex-wrap items-end justify-between gap-4">
  <div class="min-w-0">
    {#if eyebrow}<p class="arc-eyebrow mb-1.5">{eyebrow}</p>{/if}
    <h1 class="text-[22px] leading-8 font-semibold tracking-[-0.02em]" data-testid="page-title">{title}</h1>
    {#if description}<p class="mt-1 max-w-[72ch] text-[13.5px] leading-6 text-muted-foreground">{description}</p>{/if}
  </div>
  {#if actions}<div class="flex flex-wrap items-center gap-2">{@render actions()}</div>{/if}
</header>
