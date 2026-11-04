<script lang="ts">
  import { clipboard } from '$lib/clipboard.svelte';
  import ClipboardCheck from '@lucide/svelte/icons/clipboard-check';
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert';
  import { motionIn } from '$lib/motion';
</script>

{#if clipboard.active}
  <div
    {@attach motionIn({ y: 12 })}
    class="fixed bottom-4 left-1/2 z-[75] flex -translate-x-1/2 items-center gap-3 rounded-full border border-border-strong bg-popover py-1.5 pr-1.5 pl-3 text-[12.5px] shadow-[var(--shadow-pop)]"
    role={clipboard.status === 'unconfirmed' ? 'alert' : 'status'}
    aria-live="polite"
    data-testid="clipboard-pill"
  >
    {#if clipboard.status === 'unconfirmed'}
      <TriangleAlert class="size-4 shrink-0 text-warning" />
      <span>Clipboard clearing unconfirmed. The copied value may remain; retry or clear it yourself.</span>
    {:else}
      <ClipboardCheck class="size-4 text-success" />
      {#if clipboard.status === 'clearing'}
        <span>Clearing clipboard…</span>
      {:else}
        <span><span class="font-medium">{clipboard.label}</span> copied · clears in <span class="tabular-nums" data-testid="clipboard-remaining">{clipboard.remaining}</span> s</span>
        <span class="h-1 w-16 overflow-hidden rounded-full bg-subtle" aria-hidden="true">
          <span class="block h-full rounded-full bg-success transition-[width] duration-1000 ease-linear" style:width="{(clipboard.remaining / Math.max(1, clipboard.total)) * 100}%"></span>
        </span>
      {/if}
    {/if}
    <button class="rounded-full bg-muted px-2.5 py-1 text-[12px] font-medium hover:bg-subtle" disabled={clipboard.status === 'clearing'} onclick={() => clipboard.clear()}>{clipboard.status === 'unconfirmed' ? 'Retry clear' : 'Clear now'}</button>
  </div>
{/if}
