// Clipboard with auto-clear. Only a SHA-256 digest of what we copied is kept, so the value
// itself is not held in memory after the copy. On expiry (or lock) the clipboard is cleared
// with writeText('') — but only if it still holds our value when the browser lets us read it;
// if reading is not permitted we clear unconditionally.
import { onLock } from './lockbus';
import { toast } from './toast.svelte';

async function digest(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, '0')).join('');
}

class ClipboardGuard {
  label = $state('');
  remaining = $state(0);
  total = $state(0);
  clearSec = $state(30);
  status = $state<'idle' | 'counting' | 'clearing' | 'unconfirmed'>('idle');
  private ours = '';
  private generation = 0;
  private timer: ReturnType<typeof setInterval> | null = null;

  get active() {
    return this.status !== 'idle';
  }

  async copy(value: string, label: string, sensitive = true): Promise<boolean> {
    try {
      await navigator.clipboard.writeText(value);
    } catch {
      toast.error('Clipboard unavailable', 'This browser blocked clipboard access.');
      return false;
    }
    const generation = ++this.generation;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.ours = '';
    this.remaining = 0;
    this.status = 'idle';
    if (!sensitive || this.clearSec <= 0) {
      toast.success(`${label} copied`);
      return true;
    }
    const fingerprint = await digest(value);
    if (generation !== this.generation) return true;
    this.ours = fingerprint;
    this.label = label;
    this.total = this.clearSec;
    this.remaining = this.clearSec;
    this.status = 'counting';
    this.timer = setInterval(() => {
      this.remaining -= 1;
      if (this.remaining <= 0) void this.clear();
    }, 1000);
    return true;
  }

  async clear(): Promise<void> {
    if (this.status === 'clearing') return;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    const ours = this.ours;
    const generation = this.generation;
    this.remaining = 0;
    if (!ours) {
      this.status = 'idle';
      return;
    }
    this.status = 'clearing';
    let current: string | null = null;
    try {
      current = await navigator.clipboard.readText();
    } catch {
      current = null; // not readable (permission/focus): just clear
    }
    try {
      if (generation !== this.generation) return;
      const shouldClear = current === null || (await digest(current)) === ours;
      if (generation !== this.generation) return;
      if (shouldClear) await navigator.clipboard.writeText('');
      if (generation !== this.generation) return;
      // Either the write succeeded or a readable clipboard no longer contains our value.
      this.ours = '';
      this.status = 'idle';
    } catch {
      if (generation !== this.generation) return;
      // Keep the digest for a retry, and keep the warning visible after the timer expires.
      this.status = 'unconfirmed';
      toast.warning('Clipboard clearing unconfirmed', 'The copied value may remain. Return here and retry, or clear the clipboard yourself.');
    }
  }
}

export const clipboard = new ClipboardGuard();
onLock(() => clipboard.clear());
