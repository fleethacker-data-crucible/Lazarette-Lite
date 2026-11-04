<script lang="ts">
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';
  let { title, description = '', icon, actions, class: className = '' }: { title: string; description?: string; icon?: Snippet; actions?: Snippet; class?: string } = $props();
</script>

<div class={cn('mx-auto flex max-w-sm flex-col items-center px-6 py-12 text-center', className)}>
  {#if icon}
    <div class="mb-4 grid size-14 place-items-center rounded-2xl border border-border bg-muted text-muted-foreground [&_svg]:size-6">{@render icon()}</div>
  {/if}
  <h3 class="text-[15px] font-semibold">{title}</h3>
  {#if description}<p class="mt-1.5 text-[13px] leading-5 text-muted-foreground">{description}</p>{/if}
  {#if actions}<div class="mt-5 flex flex-wrap justify-center gap-2">{@render actions()}</div>{/if}
</div>
