import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** shadcn-style class merge. */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

export function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n < 0) return '—';
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(n < 10240 ? 1 : 0)} KB`;
  if (n < 1024 ** 3) return `${(n / 1024 / 1024).toFixed(1)} MB`;
  return `${(n / 1024 ** 3).toFixed(1)} GB`;
}

export function formatDate(value: string | null | undefined, withTime = true): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return withTime ? d.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' }) : d.toLocaleDateString(undefined, { dateStyle: 'medium' });
}

const RTF = typeof Intl !== 'undefined' && 'RelativeTimeFormat' in Intl ? new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }) : null;
export function relativeTime(value: string | null | undefined, now = Date.now()): string {
  if (!value) return '—';
  const t = Date.parse(value);
  if (Number.isNaN(t)) return String(value);
  const diff = (t - now) / 1000;
  const abs = Math.abs(diff);
  const [n, unit]: [number, Intl.RelativeTimeFormatUnit] =
    abs < 60 ? [diff, 'second'] : abs < 3600 ? [diff / 60, 'minute'] : abs < 86400 ? [diff / 3600, 'hour'] : abs < 86400 * 30 ? [diff / 86400, 'day'] : abs < 86400 * 365 ? [diff / 86400 / 30, 'month'] : [diff / 86400 / 365, 'year'];
  return RTF ? RTF.format(Math.round(n), unit) : formatDate(value);
}

export function pluralize(n: number, one: string, many = `${one}s`): string {
  return `${n} ${n === 1 ? one : many}`;
}

export function splitTags(tags: string | undefined | null): string[] {
  return String(tags ?? '')
    .split(',')
    .map((t) => t.trim())
    .filter(Boolean);
}

/** Groups a TOTP secret in fours for manual entry. */
export function groupSecret(secret: string, size = 4): string {
  return (secret.replace(/\s+/g, '').match(new RegExp(`.{1,${size}}`, 'g')) ?? []).join(' ');
}

export function isGuid(v: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
}

/** Only http(s) URLs may be opened from item data. */
export function safeUrl(v: string | null | undefined): string | null {
  if (!v) return null;
  try {
    const u = new URL(v);
    return u.protocol === 'https:' || u.protocol === 'http:' ? u.href : null;
  } catch {
    return null;
  }
}

export function hostOf(v: string | null | undefined): string {
  const u = safeUrl(v);
  return u ? new URL(u).host : '';
}

export function initials(name: string): string {
  const words = name.replace(/[^\p{L}\p{N}\s]/gu, ' ').trim().split(/\s+/).filter(Boolean);
  return ((words[0]?.[0] ?? '?') + (words[1]?.[0] ?? '')).toUpperCase();
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
