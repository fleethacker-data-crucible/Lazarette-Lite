<script lang="ts">
  // Form row: label, control (children), hint and error (announced to screen readers).
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';
  import { fieldDescriptionId } from '$lib/field-description';
  import Label from './label.svelte';

  let { label, for: htmlFor, hint, error, class: className = '', children, aside }: {
    label: string;
    for?: string;
    hint?: string;
    error?: string | null;
    class?: string;
    children?: Snippet;
    aside?: Snippet;
  } = $props();
</script>

<div class={cn('grid gap-1.5', className)}>
  <div class="flex items-center justify-between gap-2">
    <Label for={htmlFor}>{label}</Label>
    {#if aside}{@render aside()}{/if}
  </div>
  {@render children?.()}
  {#if error}
    <p class="text-[12px] text-destructive" role="alert" id={fieldDescriptionId(htmlFor, true)}>{error}</p>
  {:else if hint}
    <p class="text-[12px] text-muted-foreground" id={fieldDescriptionId(htmlFor, false, true)}>{hint}</p>
  {/if}
</div>
