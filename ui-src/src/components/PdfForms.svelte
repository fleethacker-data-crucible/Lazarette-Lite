<script lang="ts">
  import { onDestroy } from 'svelte';
  import { getDocument, GlobalWorkerOptions } from 'pdfjs-dist';
  import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';
  import PageHeader from './PageHeader.svelte';
  import Button from './ui/button.svelte';

  GlobalWorkerOptions.workerSrc = workerUrl;
  type Row = { name: string; value: string; source: 'AcroForm' | 'XFA' };
  interface XfaNode { name?: string; value?: string; attributes?: Record<string, unknown>; children?: XfaNode[] }
  let rows = $state<Row[]>([]);
  let name = $state('');
  let error = $state('');
  let busy = $state(false);
  let generation = 0;
  let task: ReturnType<typeof getDocument> | undefined;

  function clear() {
    generation++;
    const current = task;
    task = undefined;
    if (current) void current.destroy().catch(() => {});
    rows = [];
    name = '';
    error = '';
    busy = false;
  }
  onDestroy(clear);

  function xfaRows(root: XfaNode): Row[] {
    const fields = new Map<string, Row>();
    const pending = [root];
    while (pending.length) {
      const node = pending.pop()!;
      const attr = node.attributes ?? {};
      const id = String(attr.dataId ?? attr.id ?? '');
      if (id && ['input', 'textarea', 'select'].includes(node.name ?? '')) {
        const chosen = node.children?.filter((child) => child.attributes?.selected !== undefined).map((child) => child.attributes?.value ?? child.value);
        const value = attr.type === 'checkbox' || attr.type === 'radio'
          ? (attr.checked === undefined ? '' : attr.xfaOn ?? attr.value ?? 'Yes')
          : attr.value ?? (chosen?.length ? chosen.join(', ') : node.value ?? node.children?.map((child) => child.value ?? '').join('') ?? '');
        if (!fields.has(id) || value !== '') fields.set(id, { name: String(attr['aria-label'] || attr.title || attr.name || id), value: String(value), source: 'XFA' });
      }
      for (const child of node.children ?? []) pending.push(child);
    }
    return [...fields.values()];
  }

  async function inspect(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    clear();
    if (file.size > 25 * 1024 * 1024) { error = 'PDFs are limited to 25 MB.'; return; }
    name = file.name;
    busy = true;
    const run = generation;
    let data: Uint8Array;
    try { data = new Uint8Array(await file.arrayBuffer()); }
    catch { if (run === generation) { error = 'Could not read this file.'; busy = false; } return; }
    if (run !== generation) return;
    const base = new URL('./pdfjs/', location.href).href;
    const current = getDocument({
      data,
      enableXfa: true,
      isEvalSupported: false,
      cMapUrl: base + 'cmaps/',
      cMapPacked: true,
      standardFontDataUrl: base + 'standard_fonts/'
    });
    task = current;
    current.onPassword = () => {
      if (task !== current) return;
      error = 'This PDF requires a password. Open an unprotected copy to extract its fields.';
      busy = false;
      task = undefined;
      void current.destroy().catch(() => {});
    };
    try {
      const pdf = await current.promise;
      const fields = await pdf.getFieldObjects();
      const acro: Row[] = Object.entries(fields ?? {}).map(([fieldName, widgets]) => ({
        name: fieldName,
        value: [...new Set(widgets.flatMap((widget) => (widget as { value?: unknown }).value ?? []).map(String))].join(', '),
        source: 'AcroForm'
      }));
      const xfa = pdf.allXfaHtml as XfaNode | null;
      if (task === current) rows = [...acro, ...(xfa ? xfaRows(xfa) : [])];
    } catch (e) {
      if (task === current) error = e instanceof Error ? e.message : 'Could not inspect this PDF.';
    } finally {
      if (task === current) {
        task = undefined;
        busy = false;
        await current.destroy().catch(() => {});
      }
    }
  }
</script>

<div class="mx-auto max-w-4xl p-8">
  <PageHeader title="PDF forms" description="Read AcroForm and supported XFA fields locally. The file and extracted values stay in this browser tab." />
  <div class="mt-6 flex flex-wrap items-center gap-4 rounded-xl border border-border bg-card p-5">
    <label class="grid gap-2 text-sm font-medium">Choose a PDF<input type="file" accept=".pdf,application/pdf" onchange={inspect} disabled={busy} /></label>
    {#if name}<Button variant="outline" onclick={clear}>Clear</Button>{/if}
  </div>
  {#if busy}<p class="mt-4 text-sm" role="status">Inspecting {name}…</p>
  {:else if error}<p class="mt-4 text-sm text-destructive" role="alert">{error}</p>
  {:else if name}
    <h2 class="mt-6 break-all font-display text-xl">{name}</h2>
    {#if rows.length}
      <div class="mt-3 overflow-x-auto rounded-xl border border-border">
        <table class="w-full text-left text-sm"><thead class="bg-surface"><tr><th class="p-3">Field</th><th class="p-3">Value</th><th class="p-3">Source</th></tr></thead>
        <tbody>{#each rows as row}<tr class="border-t border-border"><th scope="row" class="p-3 font-medium break-all">{row.name}</th><td class="p-3 whitespace-pre-wrap break-all">{row.value}</td><td class="p-3">{row.source}</td></tr>{/each}</tbody></table>
      </div>
    {:else}<p class="mt-3 text-sm text-muted-foreground">No supported form fields found.</p>{/if}
  {/if}
</div>
