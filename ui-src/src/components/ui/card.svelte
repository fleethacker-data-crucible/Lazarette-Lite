<script lang="ts">
  import type { HTMLAttributes } from 'svelte/elements';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';

  type Props = HTMLAttributes<HTMLElement> & {
    title?: string;
    description?: string;
    icon?: Snippet;
    actions?: Snippet;
    children?: Snippet;
    padded?: boolean;
    as?: 'section' | 'div' | 'article';
  };
  let { class: className, title, description, icon, actions, children, padded = true, as = 'section', ...rest }: Props = $props();
</script>

<svelte:element this={as} class={cn('rounded-lg border border-border bg-card text-card-foreground', className)} {...rest}>
  {#if title || actions}
    <header class="flex items-start gap-3 border-b border-border px-5 py-4">
      {#if icon}<div class="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-primary-soft text-primary [&_svg]:size-4">{@render icon()}</div>{/if}
      <div class="min-w-0 flex-1">
        {#if title}<h2 class="text-[14px] leading-5 font-semibold tracking-[-0.01em]">{title}</h2>{/if}
        {#if description}<p class="mt-0.5 text-[12.5px] leading-5 text-muted-foreground">{description}</p>{/if}
      </div>
      {#if actions}<div class="flex shrink-0 items-center gap-2">{@render actions()}</div>{/if}
    </header>
  {/if}
  <div class={padded ? 'p-5' : ''}>{@render children?.()}</div>
</svelte:element>
