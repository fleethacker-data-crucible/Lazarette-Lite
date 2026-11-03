<script lang="ts">
  import { onMount } from 'svelte';
  import { Tooltip } from 'bits-ui';
  import { describeError, request, configureApi } from '$lib/api/client';
  import { startHeartbeat } from '$lib/presence';
  import { clipboard } from '$lib/clipboard.svelte';
  import { confirm } from '$lib/confirm.svelte';
  import { toast } from '$lib/toast.svelte';
  import { fuzzyScore } from '$lib/fuzzy';
  import BrandMark from '$components/BrandMark.svelte';
  import ItemIcon from '$components/ItemIcon.svelte';
  import SecretText from '$components/SecretText.svelte';
  import PageHeader from '$components/PageHeader.svelte';
  import PasswordGenerator from '$components/PasswordGenerator.svelte';
  import PdfForms from '$components/PdfForms.svelte';
  import Toaster from '$components/Toaster.svelte';
  import ClipboardPill from '$components/ClipboardPill.svelte';
  import ConfirmHost from '$components/ui/confirm-host.svelte';
  import Button from '$components/ui/button.svelte';
  import Dialog from '$components/ui/dialog.svelte';
  import Input from '$components/ui/input.svelte';
  import Plus from '@lucide/svelte/icons/plus';
  import Search from '@lucide/svelte/icons/search';
  import KeyRound from '@lucide/svelte/icons/key-round';
  import Star from '@lucide/svelte/icons/star';
  import WandSparkles from '@lucide/svelte/icons/wand-sparkles';
  import FileText from '@lucide/svelte/icons/file-text';
  import RefreshCw from '@lucide/svelte/icons/refresh-cw';
  import Copy from '@lucide/svelte/icons/copy';
  import Eye from '@lucide/svelte/icons/eye';
  import Pencil from '@lucide/svelte/icons/pencil';
  import Trash from '@lucide/svelte/icons/trash';
  import Power from '@lucide/svelte/icons/power';

  interface Credential { Service: string; User: string; Comment: string; HasSecret: boolean; Target: string }
  type Theme = 'system' | 'light' | 'dark';

  let items = $state<Credential[]>([]);
  let selected = $state('');
  let favourites = $state<string[]>([]);
  let view = $state<'all' | 'favourites' | 'generator' | 'pdf'>('all');
  let query = $state('');
  let search = $state<HTMLInputElement | null>(null);
  let session = $state<'boot' | 'ready' | 'ended'>('boot');
  let error = $state('');
  let theme = $state<Theme>('system');
  let editing = $state<Credential | null>(null);
  let open = $state(false);
  let busy = $state(false);
  let formError = $state('');
  let form = $state({ service: '', user: '', comment: '', secret: '' });
  let revealed = $state('');
  let revealTimer: ReturnType<typeof setTimeout> | undefined;
  let stopHeartbeat: (() => void) | undefined;

  const credential = $derived(items.find((item) => item.Target === selected));
  const shown = $derived(items.flatMap((item) => {
    if (view === 'favourites' && !favourites.includes(item.Target)) return [];
    const score = query.trim() ? fuzzyScore(query.trim(), [item.Service, item.User, item.Comment]) : 0;
    return score === null ? [] : [{ item, score }];
  }).sort((a, b) => b.score - a.score).map(({ item }) => item));
  const identity = (item: Credential) => ({ service: item.Service, user: item.User });

  function hide() {
    clearTimeout(revealTimer);
    revealed = '';
  }

  function end() {
    stopHeartbeat?.();
    hide();
    form.secret = '';
    open = false;
    items = [];
    selected = '';
    session = 'ended';
  }

  async function refresh() {
    error = '';
    try {
      items = (await request<{ items: Credential[] }>('/api/credentials')).items;
      if (!items.some((item) => item.Target === selected)) { selected = ''; hide(); }
    } catch (e) { error = describeError(e); }
  }

  async function boot() {
    const nonce = new URLSearchParams(location.hash.slice(1)).get('k');
    try {
      if (nonce) {
        history.replaceState(null, '', location.pathname + location.search);
        await request('/api/session', { method: 'POST', body: { nonce } });
      } else {
        await request('/api/session/ping', { method: 'POST', body: {} });
      }
      session = 'ready';
      stopHeartbeat = startHeartbeat();
      await refresh();
    } catch (e) { end(); error = describeError(e); }
  }

  onMount(() => {
    const media = matchMedia('(prefers-color-scheme: dark)');
    const updateTheme = () => {
      document.documentElement.dataset.theme = theme === 'system' ? (media.matches ? 'dark' : 'light') : theme;
    };
    media.addEventListener('change', updateTheme);
    updateTheme();
    configureApi({ onSession: end });
    void boot();
    return () => { stopHeartbeat?.(); hide(); media.removeEventListener('change', updateTheme); };
  });

  $effect(() => {
    document.documentElement.dataset.theme = theme === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : theme;
  });

  function go(next: typeof view) { hide(); view = next; }
  function select(item: Credential) { hide(); selected = item.Target; }
  function favourite(item: Credential) {
    favourites = favourites.includes(item.Target) ? favourites.filter((target) => target !== item.Target) : [...favourites, item.Target];
  }
  function edit(item: Credential | null = null, secret = '') {
    hide();
    editing = item;
    form = { service: item?.Service ?? '', user: item?.User ?? '', comment: item?.Comment ?? '', secret };
    formError = '';
    open = true;
  }
  async function save(event: SubmitEvent) {
    event.preventDefault();
    busy = true;
    formError = '';
    try {
      const body = editing ? { ...identity(editing), newService: form.service.trim(), newUser: form.user.trim(), comment: form.comment, secret: form.secret }
        : { ...form, service: form.service.trim(), user: form.user.trim() };
      const { item } = await request<{ item: Credential }>(editing ? '/api/credentials/edit' : '/api/credentials/add', { body });
      if (editing && favourites.includes(editing.Target)) favourites = favourites.map((target) => target === editing?.Target ? item.Target : target);
      open = false;
      form.secret = '';
      query = '';
      go('all');
      await refresh();
      select(item);
      toast.success('Credential saved');
    } catch (e) { formError = describeError(e); }
    finally { busy = false; }
  }
  async function remove(item: Credential) {
    if (!(await confirm({ title: `Delete ${item.Service}?`, description: 'This removes the credential from Windows Credential Manager.', confirmLabel: 'Delete', destructive: true }))) return;
    try {
      await request('/api/credentials/delete', { body: identity(item) });
      favourites = favourites.filter((target) => target !== item.Target);
      await refresh();
      toast.success('Credential deleted');
    } catch (e) { toast.error('Could not delete credential', describeError(e)); }
  }
  async function read(item: Credential, copy: boolean) {
    if (!copy && revealed) { hide(); return; }
    try {
      const result = await request<{ secret: string }>('/api/credentials/reveal', { body: identity(item) });
      if (selected !== item.Target || (view !== 'all' && view !== 'favourites')) return;
      if (copy) await clipboard.copy(result.secret, 'Secret');
      else { hide(); revealed = result.secret; revealTimer = setTimeout(hide, 15000); }
    } catch (e) { toast.error('Could not read credential', describeError(e)); }
  }
  async function quit() {
    try { await clipboard.clear(); await request('/api/session/quit', { body: {} }); end(); }
    catch (e) { toast.error('Could not quit', describeError(e)); }
  }
  function shortcuts(e: KeyboardEvent) {
    if (e.key === 'Escape') hide();
    if (session !== 'ready' || open || (!e.ctrlKey && !e.metaKey) || e.key.toLowerCase() !== 'k') return;
    e.preventDefault();
    go('all');
    requestAnimationFrame(() => search?.focus());
  }
</script>

<svelte:window onkeydown={shortcuts} />

<Tooltip.Provider delayDuration={350}>
  {#if session !== 'ready'}
    <main class="grid h-full place-items-center bg-background">
      <div class="grid justify-items-center gap-5 text-center">
        <BrandMark size={58} />
        <p>{session === 'boot' ? 'Connecting to Windows Credential Manager…' : 'Session ended. Reopen Launch-LazaretteLite.bat.'}</p>
        {#if error}<p class="text-destructive">{error}</p>{/if}
      </div>
    </main>
  {:else}
    <div class="flex h-full min-h-0 flex-col bg-background text-foreground">
      <header class="flex min-h-16 items-center gap-4 border-b border-border bg-surface px-5">
        <BrandMark size={38} />
        <span class="ml-auto text-xs text-muted-foreground">Windows Credential Manager</span>
        <select aria-label="Theme" bind:value={theme} class="rounded-md border border-border bg-card px-2 py-1 text-xs">
          <option value="system">System theme</option><option value="dark">Night watch</option><option value="light">Chart room</option>
        </select>
        <Button variant="ghost" size="sm" onclick={quit}><Power /> Quit</Button>
      </header>
      <div class="flex min-h-0 flex-1">
        <nav aria-label="Lazarette" class="flex w-48 shrink-0 flex-col gap-1 border-r border-border bg-sidebar p-3">
          <Button class="mb-3" onclick={() => edit()}><Plus /> New item</Button>
          <div class="arc-eyebrow px-2 py-2">Credentials</div>
          {#each [{ id: 'all', label: 'All items', icon: KeyRound }, { id: 'favourites', label: 'Favourites', icon: Star }, { id: 'generator', label: 'Generator', icon: WandSparkles }, { id: 'pdf', label: 'PDF forms', icon: FileText }] as entry}
            <button type="button" class="flex items-center gap-3 rounded-md px-3 py-2.5 text-left text-sm hover:bg-sidebar-active" class:bg-sidebar-active={view === entry.id} aria-current={view === entry.id ? 'page' : undefined} onclick={() => go(entry.id as typeof view)}>
              <entry.icon class="size-4 text-brass" /> {entry.label}
            </button>
          {/each}
        </nav>
        {#if view === 'generator'}
          <main class="min-w-0 flex-1 overflow-auto"><div class="mx-auto max-w-[720px] p-8">
            <PageHeader title="Password generator" description="Generate passwords and passphrases locally in this browser." />
            <div class="mt-6 rounded-xl border border-border bg-card p-6"><PasswordGenerator onuse={(value) => edit(null, value)} useLabel="Save as new item" /></div>
          </div></main>
        {:else if view === 'pdf'}
          <main class="min-w-0 flex-1 overflow-auto"><PdfForms /></main>
        {:else}
          <section aria-label="Credential list" class="flex w-[min(34%,370px)] min-w-56 shrink-0 flex-col border-r border-border bg-surface">
            <div class="flex items-center gap-2 border-b border-border p-3">
              <Search class="size-4 shrink-0 text-muted-foreground" />
              <Input bind:ref={search} bind:value={query} placeholder="Search credentials…" aria-label="Search credentials" />
              <button title="Refresh" aria-label="Refresh" onclick={refresh} class="rounded-md p-2 hover:bg-muted"><RefreshCw class="size-4" /></button>
            </div>
            {#if error}<p class="p-3 text-sm text-destructive" role="alert">{error}</p>{/if}
            <div class="min-h-0 flex-1 overflow-auto p-2">
              {#each shown as item (item.Target)}
                <button type="button" class="flex w-full items-center gap-3 rounded-lg p-3 text-left hover:bg-muted" class:bg-sidebar-active={item.Target === selected} aria-pressed={item.Target === selected} onclick={() => select(item)}>
                  <ItemIcon type="login" name={item.Service} />
                  <span class="min-w-0 flex-1"><span class="block truncate text-sm font-semibold">{item.Service}</span><span class="block truncate text-xs text-muted-foreground">{item.User}</span></span>
                  {#if favourites.includes(item.Target)}<Star class="size-4 shrink-0 fill-brass text-brass" />{/if}
                </button>
              {:else}<p class="px-3 py-4 text-sm text-muted-foreground">No matching credentials.</p>{/each}
            </div>
          </section>
          <main class="min-w-0 flex-1 overflow-auto">
            {#if credential}
              {@const item = credential}
              <div class="mx-auto max-w-3xl p-8">
                <div class="flex items-center gap-4">
                  <ItemIcon type="login" name={item.Service} size="lg" />
                  <div class="min-w-0 flex-1"><div class="arc-eyebrow">Windows credential</div><h1 class="break-all font-display text-3xl">{item.Service}</h1></div>
                  <Button variant="ghost" onclick={() => favourite(item)} aria-label={favourites.includes(item.Target) ? 'Remove favourite' : 'Add favourite'}><Star class={favourites.includes(item.Target) ? 'fill-brass text-brass' : ''} /></Button>
                  <Button variant="outline" onclick={() => edit(item)}><Pencil /> Edit</Button>
                  <Button variant="ghost" onclick={() => remove(item)} aria-label="Delete credential"><Trash /></Button>
                </div>
                <dl class="mt-8 divide-y divide-border rounded-xl border border-border bg-card">
                  <div class="p-4"><dt class="arc-eyebrow">User</dt><dd class="mt-2 break-all">{item.User}</dd></div>
                  <div class="p-4">
                    <dt class="arc-eyebrow">Secret</dt>
                    <dd class="mt-2 flex flex-wrap items-center gap-2">
                      <span class="min-w-0 flex-1 break-all">{#if revealed}<SecretText value={revealed} />{:else if item.HasSecret}••••••••••••{:else}No secret yet{/if}</span>
                      <Button variant="ghost" size="sm" disabled={!item.HasSecret} onclick={() => read(item, false)}><Eye /> {revealed ? 'Hide' : 'Reveal'}</Button>
                      <Button variant="outline" size="sm" disabled={!item.HasSecret} onclick={() => read(item, true)}><Copy /> Copy</Button>
                    </dd>
                  </div>
                  <div class="p-4"><dt class="arc-eyebrow">Note</dt><dd class="mt-2 whitespace-pre-wrap break-words">{item.Comment || 'No note'}</dd></div>
                </dl>
              </div>
            {:else}
              <div class="grid h-full place-items-center p-6 text-center">
                <div class="max-w-[420px]">
                  <img src="./assets/lazarette-emblem-light.png" alt="" width="240" height="240" class="mx-auto mb-6 rounded-xl dark:hidden" />
                  <img src="./assets/lazarette-emblem-dark.png" alt="" width="240" height="240" class="mx-auto mb-6 hidden rounded-xl dark:block" />
                  <p class="arc-eyebrow">Windows Credential Manager</p>
                  <h1 class="mt-2 font-display text-[28px]">Your credentials, aboard this computer.</h1>
                  <p class="mt-2 text-sm text-muted-foreground">Select a credential or add one for your Fleet tools.</p>
                  <Button class="mt-5" onclick={() => edit()}><Plus /> New item</Button>
                </div>
              </div>
            {/if}
          </main>
        {/if}
      </div>
      <footer class="flex items-center justify-between border-t border-border bg-surface px-4 py-2 text-xs text-muted-foreground"><span>{items.length} credentials</span><span>Lazarette Lite · Local session</span></footer>
    </div>
  {/if}

  <Dialog bind:open title={editing ? 'Edit credential' : 'New credential'} description="Stored under your Windows account." dismissible={!busy} onOpenChange={(isOpen) => { if (!isOpen) form.secret = ''; }}>
    <form class="grid gap-4" onsubmit={save}>
      <label class="grid gap-1 text-sm">Service<Input bind:value={form.service} maxlength={100} required /></label>
      <label class="grid gap-1 text-sm">User<Input bind:value={form.user} maxlength={100} placeholder="Defaults to the service name" /></label>
      <label class="grid gap-1 text-sm">Secret<Input type="password" bind:value={form.secret} maxlength={1280} autocomplete="off" required={!editing} placeholder={editing ? 'Leave blank to keep current secret' : ''} /></label>
      <label class="grid gap-1 text-sm">Note<Input bind:value={form.comment} maxlength={256} /></label>
      {#if formError}<p class="text-sm text-destructive" role="alert">{formError}</p>{/if}
      <div class="flex justify-end gap-2"><Button variant="outline" type="button" disabled={busy} onclick={() => { open = false; form.secret = ''; }}>Cancel</Button><Button type="submit" disabled={busy}>Save credential</Button></div>
    </form>
  </Dialog>
  <ConfirmHost /><Toaster /><ClipboardPill />
</Tooltip.Provider>
