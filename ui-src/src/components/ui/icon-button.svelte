<script lang="ts">
  // Square icon button with an accessible name and a tooltip.
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';
  import Tip from './tip.svelte';
  import { buttonVariants, type ButtonVariant } from './button.svelte';
  import { cn } from '$lib/utils';

  type Props = HTMLButtonAttributes & { label: string; variant?: ButtonVariant; size?: 'icon' | 'icon-sm' | 'icon-xs'; children: Snippet; tooltip?: boolean };
  let { label, variant = 'subtle', size = 'icon-sm', class: className = '', children, tooltip = true, ...rest }: Props = $props();
</script>

{#if tooltip}
  <Tip text={label}>
    {#snippet children(props)}
      <button type="button" aria-label={label} {...props} {...rest} class={cn(buttonVariants({ variant, size }), className)}>{@render children_()}</button>
    {/snippet}
  </Tip>
{:else}
  <button type="button" aria-label={label} {...rest} class={cn(buttonVariants({ variant, size }), className)}>{@render children_()}</button>
{/if}

{#snippet children_()}{@render children()}{/snippet}
