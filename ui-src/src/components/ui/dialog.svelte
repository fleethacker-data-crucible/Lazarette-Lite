<script lang="ts">
  // Accessible modal dialog (bits-ui Dialog: focus trap, Escape, aria wiring, scroll lock).
  import { Dialog } from 'bits-ui';
  import X from '@lucide/svelte/icons/x';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';

  let {
    open = $bindable(false),
    title,
    description,
    size = 'md',
    class: className = '',
    children,
    footer,
    icon,
    dismissible = true,
    onOpenChange,
    onOpenAutoFocus,
    testid
  }: {
    open?: boolean;
    title: string;
    description?: string;
    size?: 'sm' | 'md' | 'lg' | 'xl';
    class?: string;
    children?: Snippet;
    footer?: Snippet;
    icon?: Snippet;
    dismissible?: boolean;
    onOpenChange?: (open: boolean) => void;
    onOpenAutoFocus?: (e: Event) => void;
    testid?: string;
  } = $props();

  const widths = { sm: 'max-w-[420px]', md: 'max-w-[560px]', lg: 'max-w-[720px]', xl: 'max-w-[960px]' };
</script>

<Dialog.Root bind:open {onOpenChange}>
  <Dialog.Portal>
    <Dialog.Overlay class="fixed inset-0 z-50 bg-overlay backdrop-blur-[2px] data-[state=open]:animate-fade-in" />
    <Dialog.Content
      data-testid={testid}
      {onOpenAutoFocus}
      onEscapeKeydown={(e) => {
        if (!dismissible) e.preventDefault();
      }}
      onInteractOutside={(e) => {
        if (!dismissible) e.preventDefault();
      }}
      class={cn(
        'fixed top-1/2 left-1/2 z-50 flex max-h-[min(88vh,900px)] w-[calc(100vw-32px)] -translate-x-1/2 -translate-y-1/2 flex-col rounded-xl border border-border-strong bg-popover text-popover-foreground shadow-[var(--shadow-pop)] outline-none data-[state=open]:animate-scale-in',
        widths[size],
        className
      )}
    >
      <div class="flex items-start gap-3 px-6 pt-5 pb-3">
        {#if icon}<div class="mt-0.5 grid size-9 shrink-0 place-items-center rounded-lg bg-primary-soft text-primary [&_svg]:size-[18px]">{@render icon()}</div>{/if}
        <div class="min-w-0 flex-1">
          <Dialog.Title class="text-[16px] leading-6 font-semibold tracking-[-0.01em]">{title}</Dialog.Title>
          {#if description}<Dialog.Description class="mt-1 text-[13px] leading-5 text-muted-foreground">{description}</Dialog.Description>{/if}
        </div>
        {#if dismissible}
          <Dialog.Close class="-mr-2 grid size-8 place-items-center rounded-md text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring" aria-label="Close">
            <X class="size-4" />
          </Dialog.Close>
        {/if}
      </div>
      <div class="min-h-0 flex-1 overflow-y-auto px-6 pb-5">{@render children?.()}</div>
      {#if footer}
        <div class="flex flex-wrap items-center justify-end gap-2 border-t border-border bg-surface-2/60 px-6 py-3.5 rounded-b-xl">{@render footer()}</div>
      {/if}
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
