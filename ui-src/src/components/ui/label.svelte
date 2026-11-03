<script lang="ts">
  import type { HTMLLabelAttributes } from 'svelte/elements';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';

  type Props = HTMLLabelAttributes & { children?: Snippet };
  let { class: className, children, ...rest }: Props = $props();
</script>

<label class={cn('text-[12.5px] font-medium text-foreground/90 select-none', className)} {...rest}>{@render children?.()}</label>
