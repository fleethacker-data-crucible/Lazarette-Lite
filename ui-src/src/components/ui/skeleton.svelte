<script lang="ts">
  import { cn } from '$lib/utils';
  let { class: className = '' }: { class?: string } = $props();
</script>

<div class={cn('arc-skeleton h-4', className)} aria-hidden="true"></div>
