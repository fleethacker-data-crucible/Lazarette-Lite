<script lang="ts">
  // Side drawer built on the bits-ui Dialog primitive (same focus/escape/aria behaviour).
  import { Dialog } from 'bits-ui';
  import X from '@lucide/svelte/icons/x';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';

  let {
    open = $bindable(false),
    title,
    description,
    class: className = '',
    children,
    footer,
    testid
  }: { open?: boolean; title: string; description?: string; class?: string; children?: Snippet; footer?: Snippet; testid?: string } = $props();
</script>

<Dialog.Root bind:open>
  <Dialog.Portal>
    <Dialog.Overlay class="fixed inset-0 z-50 bg-overlay data-[state=open]:animate-fade-in" />
    <Dialog.Content
      data-testid={testid}
      class={cn(
        'fixed inset-y-0 right-0 z-50 flex w-[min(480px,calc(100vw-48px))] flex-col border-l border-border-strong bg-popover shadow-[var(--shadow-pop)] outline-none data-[state=open]:animate-slide-in-right',
        className
      )}
    >
      <div class="flex items-start gap-3 border-b border-border px-5 py-4">
        <div class="min-w-0 flex-1">
          <Dialog.Title class="text-[15px] font-semibold">{title}</Dialog.Title>
          {#if description}<Dialog.Description class="mt-0.5 text-[12.5px] text-muted-foreground">{description}</Dialog.Description>{/if}
        </div>
        <Dialog.Close class="-mr-1 grid size-8 place-items-center rounded-md text-muted-foreground hover:bg-muted hover:text-foreground" aria-label="Close"><X class="size-4" /></Dialog.Close>
      </div>
      <div class="min-h-0 flex-1 overflow-y-auto p-5">{@render children?.()}</div>
      {#if footer}<div class="flex justify-end gap-2 border-t border-border px-5 py-3">{@render footer()}</div>{/if}
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
