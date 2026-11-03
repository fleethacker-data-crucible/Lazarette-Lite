<script lang="ts">
  import type { ItemType } from '$lib/api/types';
  import KeyRound from '@lucide/svelte/icons/key-round';
  import SlidersHorizontal from '@lucide/svelte/icons/sliders-horizontal';
  import Braces from '@lucide/svelte/icons/braces';
  import StickyNote from '@lucide/svelte/icons/sticky-note';
  import Server from '@lucide/svelte/icons/server';
  import { cn, initials } from '$lib/utils';

  let { type, name = '', size = 'md', class: className = '' }: { type: ItemType; name?: string; size?: 'sm' | 'md' | 'lg'; class?: string } = $props();
  const tone: Record<ItemType, string> = {
    login: 'text-type-login bg-[color-mix(in_oklab,var(--color-type-login)_14%,transparent)] border-[color-mix(in_oklab,var(--color-type-login)_28%,transparent)]',
    parameter: 'text-type-parameter bg-[color-mix(in_oklab,var(--color-type-parameter)_14%,transparent)] border-[color-mix(in_oklab,var(--color-type-parameter)_28%,transparent)]',
    api: 'text-type-api bg-[color-mix(in_oklab,var(--color-type-api)_14%,transparent)] border-[color-mix(in_oklab,var(--color-type-api)_28%,transparent)]',
    note: 'text-type-note bg-[color-mix(in_oklab,var(--color-type-note)_14%,transparent)] border-[color-mix(in_oklab,var(--color-type-note)_28%,transparent)]',
    infrastructure: 'text-type-infrastructure bg-[color-mix(in_oklab,var(--color-type-infrastructure)_14%,transparent)] border-[color-mix(in_oklab,var(--color-type-infrastructure)_28%,transparent)]'
  };
  const dims = { sm: 'size-8 rounded-lg [&_svg]:size-4 text-[11px]', md: 'size-10 rounded-[10px] [&_svg]:size-[18px] text-[13px]', lg: 'size-14 rounded-2xl [&_svg]:size-6 text-[17px]' };
</script>

<div class={cn('relative grid shrink-0 place-items-center border font-semibold', tone[type], dims[size], className)} aria-hidden="true">
  {#if type === 'login' && name}
    <span class="tracking-tight">{initials(name)}</span>
  {:else if type === 'login'}<KeyRound />
  {:else if type === 'parameter'}<SlidersHorizontal />
  {:else if type === 'api'}<Braces />
  {:else if type === 'note'}<StickyNote />
  {:else}<Server />{/if}
</div>
