<script lang="ts">
  // Styled native <select>: fully keyboard/screen-reader accessible with no popup positioning.
  import ChevronDown from '@lucide/svelte/icons/chevron-down';
  import type { HTMLSelectAttributes } from 'svelte/elements';
  import { cn } from '$lib/utils';

  type Option = { value: string; label: string; disabled?: boolean };
  type Props = HTMLSelectAttributes & { options: Option[]; placeholder?: string; invalid?: boolean; ref?: HTMLSelectElement | null };
  let { value = $bindable(), options, placeholder, invalid = false, class: className = '', ref = $bindable(null), ...rest }: Props = $props();
</script>

<div class={cn('relative', className)}>
  <select
    bind:this={ref}
    bind:value
    aria-invalid={invalid || undefined}
    class="h-8 w-full appearance-none rounded-md border border-input bg-surface pr-8 pl-3 text-[13px] text-foreground outline-none focus-visible:border-ring focus-visible:shadow-[0_0_0_3px_var(--arc-primary-soft)] disabled:opacity-50 aria-[invalid=true]:border-destructive"
    {...rest}
  >
    {#if placeholder !== undefined}<option value="">{placeholder}</option>{/if}
    {#each options as o (o.value)}<option value={o.value} disabled={o.disabled}>{o.label}</option>{/each}
  </select>
  <ChevronDown class="pointer-events-none absolute top-1/2 right-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
</div>
