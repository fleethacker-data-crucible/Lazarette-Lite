<script lang="ts">
  import { AlertDialog } from 'bits-ui';
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert';
  import CircleHelp from '@lucide/svelte/icons/circle-question-mark';
  import { confirmState } from '$lib/confirm.svelte';
  import { buttonVariants } from './button.svelte';
  import Input from './input.svelte';
  import { cn } from '$lib/utils';

  let typed = $state('');
  const req = $derived(confirmState.current);
  let open = $derived(!!req);
  const blocked = $derived(!!req?.typeToConfirm && typed.trim() !== req.typeToConfirm);

  $effect(() => {
    if (req) typed = '';
  });
</script>

<AlertDialog.Root
  {open}
  onOpenChange={(v) => {
    if (!v) confirmState.settle(false);
  }}
>
  <AlertDialog.Portal>
    <AlertDialog.Overlay class="fixed inset-0 z-[60] bg-overlay data-[state=open]:animate-fade-in" />
    <AlertDialog.Content
      data-testid="confirm-dialog"
      class="fixed top-1/2 left-1/2 z-[60] w-[calc(100vw-32px)] max-w-[440px] -translate-x-1/2 -translate-y-1/2 rounded-xl border border-border-strong bg-popover p-6 shadow-[var(--shadow-pop)] outline-none data-[state=open]:animate-scale-in"
    >
      {#if req}
        <div class="flex gap-3.5">
          <div class={cn('grid size-10 shrink-0 place-items-center rounded-full', req.destructive ? 'bg-destructive-soft text-destructive' : 'bg-primary-soft text-primary')}>
            {#if req.destructive}<TriangleAlert class="size-5" />{:else}<CircleHelp class="size-5" />{/if}
          </div>
          <div class="min-w-0 flex-1">
            <AlertDialog.Title class="text-[15px] leading-6 font-semibold">{req.title}</AlertDialog.Title>
            {#if req.description}<AlertDialog.Description class="mt-1 text-[13px] leading-5 text-muted-foreground">{req.description}</AlertDialog.Description>{/if}
            {#if req.details?.length}
              <ul class="mt-3 max-h-40 space-y-1 overflow-y-auto rounded-md border border-border bg-surface p-2.5 text-[12.5px]">
                {#each req.details as d (d)}<li class="truncate">{d}</li>{/each}
              </ul>
            {/if}
            {#if req.typeToConfirm}
              <label class="mt-4 block text-[12.5px] text-muted-foreground" for="confirm-type">Type <span class="font-mono font-semibold text-foreground">{req.typeToConfirm}</span> to confirm</label>
              <Input id="confirm-type" class="mt-1.5" bind:value={typed} autocomplete="off" />
            {/if}
          </div>
        </div>
        <div class="mt-6 flex justify-end gap-2">
          <AlertDialog.Cancel class={buttonVariants({ variant: 'outline' })}>{req.cancelLabel ?? 'Cancel'}</AlertDialog.Cancel>
          <AlertDialog.Action
            data-testid="confirm-ok"
            disabled={blocked}
            class={buttonVariants({ variant: req.destructive ? 'destructive' : 'default' })}
            onclick={() => confirmState.settle(true)}>{req.confirmLabel ?? 'Confirm'}</AlertDialog.Action
          >
        </div>
      {/if}
    </AlertDialog.Content>
  </AlertDialog.Portal>
</AlertDialog.Root>
