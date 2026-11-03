<script lang="ts">
  // Lazarette mark + wordmark (Fleet brand, docs/UNIFIED-UI.md section 8): the mark is the shared
  // emblem frame with the chest subject; the wordmark is the display serif in capitals with the
  // compass-star divider between brass rules. Colours come from tokens, so both themes are right.
  import { cn } from '$lib/utils';
  let { size = 36, class: className = '', withText = true, subtitle = true }: { size?: number; class?: string; withText?: boolean; subtitle?: boolean } = $props();
</script>

<div class={cn('flex items-center gap-3', className)}>
  <img src="./assets/lazarette-mark.svg" alt="" width={size} height={size} class="shrink-0" />
  {#if withText}
    <div class="min-w-0 leading-none">
      <div class="font-display text-[18px] tracking-[0.14em] text-foreground">LAZARETTE LITE</div>
      {#if subtitle}
        <div class="mt-1.5 flex items-center gap-1.5 text-brass" aria-hidden="true">
          <span class="h-px w-6 bg-current"></span>
          <svg viewBox="0 0 16 16" class="size-2.5 fill-current"><path d="M8 0 L9.6 6.4 L16 8 L9.6 9.6 L8 16 L6.4 9.6 L0 8 L6.4 6.4 Z" /></svg>
          <span class="h-px w-6 bg-current"></span>
        </div>
      {/if}
    </div>
  {/if}
</div>
