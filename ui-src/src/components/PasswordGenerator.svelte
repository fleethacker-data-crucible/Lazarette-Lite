<script lang="ts">
  // Password / passphrase generator (crypto.getRandomValues + rejection sampling).
  import { Tabs } from 'bits-ui';
  import {
    generatePassword, generatePassphrase, passwordEntropy, passphraseEntropy,
    DEFAULT_PASSWORD, DEFAULT_PASSPHRASE, type PasswordOptions, type PassphraseOptions
  } from '$lib/generator/generator';
  import { clipboard } from '$lib/clipboard.svelte';
  import SecretText from './SecretText.svelte';
  import Button from './ui/button.svelte';
  import Switch from './ui/switch.svelte';
  import RefreshCw from '@lucide/svelte/icons/refresh-cw';
  import Copy from '@lucide/svelte/icons/copy';
  import Check from '@lucide/svelte/icons/check';
  import { cn } from '$lib/utils';

  let { onuse, useLabel = 'Use this password' }: { onuse?: (value: string) => void; useLabel?: string } = $props();

  let mode = $state<'password' | 'passphrase'>('password');
  let pw = $state<PasswordOptions>({ ...DEFAULT_PASSWORD });
  let pp = $state<PassphraseOptions>({ ...DEFAULT_PASSPHRASE });
  let value = $state('');
  let error = $state('');

  const bits = $derived(mode === 'password' ? passwordEntropy(pw) : passphraseEntropy(pp));
  const quality = $derived(bits >= 100 ? 'Excellent' : bits >= 80 ? 'Very strong' : bits >= 60 ? 'Strong' : bits >= 40 ? 'Fair' : 'Weak');

  function regenerate() {
    try {
      error = '';
      value = mode === 'password' ? generatePassword(pw) : generatePassphrase(pp);
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
      value = '';
    }
  }

  $effect(() => {
    // Regenerate whenever an option changes.
    void [mode, pw.length, pw.lower, pw.upper, pw.digits, pw.symbols, pw.avoidAmbiguous, pp.words, pp.separator, pp.capitalize, pp.includeNumber];
    regenerate();
  });

  const toggles: { key: 'lower' | 'upper' | 'digits' | 'symbols'; label: string }[] = [
    { key: 'upper', label: 'A–Z' },
    { key: 'lower', label: 'a–z' },
    { key: 'digits', label: '0–9' },
    { key: 'symbols', label: '!#$%' }
  ];
  const range = 'h-1.5 w-full cursor-pointer appearance-none rounded-full bg-subtle accent-[var(--arc-primary)]';
</script>

<div class="grid gap-4" data-testid="password-generator">
  <Tabs.Root bind:value={mode}>
    <Tabs.List class="inline-grid grid-cols-2 rounded-lg border border-border bg-muted p-0.5 text-[12.5px]">
      <Tabs.Trigger value="password" class="rounded-md px-4 py-1.5 font-medium text-muted-foreground data-[state=active]:bg-card data-[state=active]:text-foreground data-[state=active]:shadow-sm">Password</Tabs.Trigger>
      <Tabs.Trigger value="passphrase" class="rounded-md px-4 py-1.5 font-medium text-muted-foreground data-[state=active]:bg-card data-[state=active]:text-foreground data-[state=active]:shadow-sm" data-testid="gen-passphrase">Passphrase</Tabs.Trigger>
    </Tabs.List>
  </Tabs.Root>

  <div class="rounded-xl border border-border bg-surface p-4">
    <div class="min-h-[52px] text-[17px] leading-7 break-all" aria-live="polite" data-testid="gen-output">
      {#if value}<SecretText {value} />{:else}<span class="text-[13px] text-destructive">{error}</span>{/if}
    </div>
    <div class="mt-3 flex items-center gap-2">
      <span class={cn('rounded-full px-2 py-0.5 text-[11.5px] font-medium', bits >= 60 ? 'bg-success-soft text-success' : bits >= 40 ? 'bg-warning-soft text-warning' : 'bg-destructive-soft text-destructive')}>{quality} · {bits} bits</span>
      <span class="ml-auto"></span>
      <Button variant="ghost" size="sm" onclick={regenerate} data-testid="gen-refresh"><RefreshCw /> New</Button>
      <Button variant="secondary" size="sm" onclick={() => clipboard.copy(value, mode === 'password' ? 'Password' : 'Passphrase')} disabled={!value}><Copy /> Copy</Button>
      {#if onuse}<Button size="sm" onclick={() => onuse(value)} disabled={!value} data-testid="gen-use"><Check /> {useLabel}</Button>{/if}
    </div>
  </div>

  {#if mode === 'password'}
    <div class="grid gap-4">
      <label class="grid gap-2 text-[12.5px]">
        <span class="flex justify-between"><span class="font-medium">Length</span><span class="tabular-nums text-muted-foreground">{pw.length}</span></span>
        <input type="range" min="8" max="64" bind:value={pw.length} class={range} aria-label="Password length" />
      </label>
      <div class="flex flex-wrap gap-2" role="group" aria-label="Character sets">
        {#each toggles as t (t.key)}
          <button
            class={cn('h-8 rounded-md border px-3 font-mono text-[12.5px] transition-colors', pw[t.key] ? 'border-primary bg-primary-soft text-foreground' : 'border-border text-muted-foreground hover:border-border-strong')}
            aria-pressed={pw[t.key]}
            onclick={() => (pw[t.key] = !pw[t.key])}>{t.label}</button
          >
        {/each}
      </div>
      <label class="flex items-center justify-between text-[12.5px]">
        <span><span class="font-medium">Avoid ambiguous characters</span> <span class="text-muted-foreground">(I l 1 O 0 o and brackets)</span></span>
        <Switch bind:checked={pw.avoidAmbiguous} aria-label="Avoid ambiguous characters" />
      </label>
    </div>
  {:else}
    <div class="grid gap-4">
      <label class="grid gap-2 text-[12.5px]">
        <span class="flex justify-between"><span class="font-medium">Words</span><span class="tabular-nums text-muted-foreground">{pp.words}</span></span>
        <input type="range" min="3" max="12" bind:value={pp.words} class={range} aria-label="Number of words" />
      </label>
      <div class="flex items-center justify-between text-[12.5px]">
        <span class="font-medium">Separator</span>
        <div class="flex gap-1" role="radiogroup" aria-label="Separator">
          {#each ['-', '.', '_', ' ', ','] as sep (sep)}
            <button role="radio" aria-checked={pp.separator === sep} aria-label={sep === ' ' ? 'Space' : sep} class={cn('size-8 rounded-md border font-mono', pp.separator === sep ? 'border-primary bg-primary-soft' : 'border-border text-muted-foreground')} onclick={() => (pp.separator = sep)}>{sep === ' ' ? '␣' : sep}</button>
          {/each}
        </div>
      </div>
      <label class="flex items-center justify-between text-[12.5px]"><span class="font-medium">Capitalise words</span><Switch bind:checked={pp.capitalize} aria-label="Capitalise words" /></label>
      <label class="flex items-center justify-between text-[12.5px]"><span class="font-medium">Add a number</span><Switch bind:checked={pp.includeNumber} aria-label="Add a number" /></label>
      <p class="text-[11.5px] text-muted-foreground">Words from the 2048-word BIP-0039 list (11 bits each), chosen with the browser's cryptographic random generator.</p>
    </div>
  {/if}
</div>
