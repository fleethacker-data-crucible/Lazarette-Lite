<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements';
  import { cn } from '$lib/utils';

  type Props = HTMLInputAttributes & { ref?: HTMLInputElement | null; invalid?: boolean };
  let { class: className, value = $bindable(), ref = $bindable(null), invalid = false, ...rest }: Props = $props();
</script>

<input
  bind:this={ref}
  bind:value
  aria-invalid={invalid || undefined}
  class={cn(
    'h-8 w-full min-w-0 rounded-md border border-input bg-surface px-3 text-[13px] text-foreground transition-[border-color,box-shadow] outline-none',
    'focus-visible:border-ring focus-visible:shadow-[0_0_0_3px_var(--arc-primary-soft)] focus-visible:outline-none',
    'disabled:cursor-not-allowed disabled:opacity-50 aria-[invalid=true]:border-destructive aria-[invalid=true]:focus-visible:shadow-[0_0_0_3px_var(--arc-destructive-soft)]',
    'file:mr-3 file:rounded file:border-0 file:bg-muted file:px-2 file:py-1 file:text-xs file:text-foreground',
    className
  )}
  {...rest}
/>
