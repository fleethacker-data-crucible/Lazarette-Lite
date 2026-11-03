<script lang="ts">
  // Revealed secret with digits/symbols coloured for legibility. Text nodes only.
  let { value, class: className = '' }: { value: string; class?: string } = $props();
  const parts = $derived(
    [...value].map((ch) => ({ ch, kind: /[0-9]/.test(ch) ? 'digit' : /[a-zA-Z\s]/.test(ch) ? '' : 'symbol' }))
  );
</script>

<span class={'arc-secret ' + className} data-testid="secret-text">{#each parts as p, i (i)}{#if p.kind === 'digit'}<span class="arc-ch-digit">{p.ch}</span>{:else if p.kind === 'symbol'}<span class="arc-ch-symbol">{p.ch}</span>{:else}{p.ch}{/if}{/each}</span>
