<script lang="ts">
  import { toasts } from '$lib/toast.svelte';
  import { motionIn } from '$lib/motion';
  import CircleCheck from '@lucide/svelte/icons/circle-check';
  import CircleX from '@lucide/svelte/icons/circle-x';
  import Info from '@lucide/svelte/icons/info';
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert';
  import X from '@lucide/svelte/icons/x';
  import { cn } from '$lib/utils';
</script>

<section class="pointer-events-none fixed right-4 bottom-4 z-[80] flex w-[min(380px,calc(100vw-32px))] flex-col gap-2" aria-label="Notifications">
  <div role="status" aria-live="polite" class="contents">
    {#each toasts.items as t (t.id)}
      <div
        {@attach motionIn({ y: 10, duration: 0.18 })}
        data-testid="toast"
        data-kind={t.kind}
        class="pointer-events-auto flex items-start gap-3 rounded-lg border border-border-strong bg-popover p-3 pr-2 shadow-[var(--shadow-pop)]"
      >
        <div class={cn('mt-0.5 shrink-0 [&_svg]:size-4', t.kind === 'success' && 'text-success', t.kind === 'error' && 'text-destructive', t.kind === 'warning' && 'text-warning', t.kind === 'info' && 'text-sky')}>
          {#if t.kind === 'success'}<CircleCheck />{:else if t.kind === 'error'}<CircleX />{:else if t.kind === 'warning'}<TriangleAlert />{:else}<Info />{/if}
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-[13px] leading-5 font-medium">{t.title}</p>
          {#if t.detail}<p class="mt-0.5 text-[12px] leading-[18px] break-words text-muted-foreground">{t.detail}</p>{/if}
          {#if t.action}<button class="mt-1.5 text-[12px] font-medium text-primary hover:underline" onclick={() => { t.action?.run(); toasts.dismiss(t.id); }}>{t.action.label}</button>{/if}
        </div>
        <button class="grid size-6 shrink-0 place-items-center rounded text-muted-foreground hover:bg-muted hover:text-foreground" aria-label="Dismiss notification" onclick={() => toasts.dismiss(t.id)}><X class="size-3.5" /></button>
      </div>
    {/each}
  </div>
</section>
