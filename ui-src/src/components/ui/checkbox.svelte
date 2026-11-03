<script lang="ts">
  import { Checkbox } from 'bits-ui';
  import Check from '@lucide/svelte/icons/check';
  import Minus from '@lucide/svelte/icons/minus';
  import { cn } from '$lib/utils';

  let { checked = $bindable(false), indeterminate = $bindable(false), disabled = false, class: className = '', id, onCheckedChange, ...rest }: {
    checked?: boolean;
    indeterminate?: boolean;
    disabled?: boolean;
    class?: string;
    id?: string;
    onCheckedChange?: (v: boolean) => void;
    'aria-label'?: string;
    'aria-labelledby'?: string;
    name?: string;
    [key: string]: unknown;
  } = $props();
</script>

<Checkbox.Root
  bind:checked
  bind:indeterminate
  {disabled}
  {id}
  {onCheckedChange}
  class={cn(
    'grid size-4 shrink-0 place-items-center rounded-[4px] border border-border-strong bg-surface text-primary-foreground transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:opacity-50',
    'data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[state=indeterminate]:border-primary data-[state=indeterminate]:bg-primary',
    className
  )}
  {...rest}
>
  {#snippet children({ checked: on, indeterminate: mixed })}
    {#if mixed}<Minus class="size-3" strokeWidth={3} />{:else if on}<Check class="size-3" strokeWidth={3} />{/if}
  {/snippet}
</Checkbox.Root>
