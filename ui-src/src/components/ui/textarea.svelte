<script lang="ts">
  import type { HTMLTextareaAttributes } from 'svelte/elements';
  import { cn } from '$lib/utils';

  type Props = HTMLTextareaAttributes & { ref?: HTMLTextAreaElement | null; invalid?: boolean };
  let { class: className, value = $bindable(), ref = $bindable(null), invalid = false, ...rest }: Props = $props();
</script>

<textarea
  bind:this={ref}
  bind:value
  aria-invalid={invalid || undefined}
  class={cn(
    'min-h-20 w-full rounded-md border border-input bg-surface px-3 py-2 text-[13px] text-foreground outline-none transition-[border-color,box-shadow]',
    'focus-visible:border-ring focus-visible:shadow-[0_0_0_3px_var(--arc-primary-soft)] focus-visible:outline-none disabled:opacity-50 aria-[invalid=true]:border-destructive',
    className
  )}
  {...rest}
></textarea>
