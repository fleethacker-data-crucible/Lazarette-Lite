<script lang="ts">
  import { Switch } from 'bits-ui';
  import { cn } from '$lib/utils';

  let { checked = $bindable(false), disabled = false, class: className = '', id, onCheckedChange, ...rest }: {
    checked?: boolean;
    disabled?: boolean;
    class?: string;
    id?: string;
    onCheckedChange?: (v: boolean) => void;
    'aria-label'?: string;
    'aria-describedby'?: string;
    name?: string;
    [key: string]: unknown;
  } = $props();
</script>

<Switch.Root
  bind:checked
  {disabled}
  {id}
  {onCheckedChange}
  class={cn(
    'peer inline-flex h-5 w-9 shrink-0 items-center rounded-full border border-transparent transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:opacity-50',
    'data-[state=checked]:bg-primary data-[state=unchecked]:bg-subtle',
    className
  )}
  {...rest}
>
  <Switch.Thumb class="pointer-events-none block size-4 rounded-full bg-white shadow-sm transition-transform data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0.5" />
</Switch.Root>
