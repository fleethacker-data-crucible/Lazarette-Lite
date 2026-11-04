// Password / passphrase generator. Runs only in the browser (docs/API.md: there is no generate
// endpoint). Randomness: crypto.getRandomValues with rejection sampling, so every symbol of
// every set is exactly equally likely (no modulo bias).
import { WORDS } from './wordlist';

export type RandomSource = (buf: Uint32Array<ArrayBuffer>) => unknown;
const defaultSource: RandomSource = (buf) => crypto.getRandomValues(buf);

/** Uniform integer in [0, max) using rejection sampling over 32-bit values. */
export function randomInt(max: number, source: RandomSource = defaultSource): number {
  if (!Number.isInteger(max) || max <= 0 || max > 2 ** 32) throw new RangeError('max must be an integer in 1..2^32');
  const limit = Math.floor(2 ** 32 / max) * max; // values >= limit would bias the result
  const buf = new Uint32Array(1);
  for (;;) {
    source(buf);
    if (buf[0] < limit) return buf[0] % max;
  }
}

export const SETS = {
  lower: 'abcdefghijklmnopqrstuvwxyz',
  upper: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  digits: '0123456789',
  symbols: '!#$%&*+-=?@^_~.:,;/|()[]{}<>'
} as const;
export const AMBIGUOUS = new Set('Il1O0o|`\'";:,.{}[]()<>/\\'.split(''));

export interface PasswordOptions {
  length: number;
  lower: boolean;
  upper: boolean;
  digits: boolean;
  symbols: boolean;
  avoidAmbiguous: boolean;
}

export const DEFAULT_PASSWORD: PasswordOptions = { length: 24, lower: true, upper: true, digits: true, symbols: true, avoidAmbiguous: true };

export function charsetsFor(o: PasswordOptions): string[] {
  const sets: string[] = [];
  for (const key of ['lower', 'upper', 'digits', 'symbols'] as const) {
    if (!o[key]) continue;
    const chars = [...SETS[key]].filter((c) => !(o.avoidAmbiguous && AMBIGUOUS.has(c))).join('');
    if (chars) sets.push(chars);
  }
  return sets;
}

/** Shuffles in place with Fisher–Yates driven by randomInt. */
export function shuffle<T>(arr: T[], source: RandomSource = defaultSource): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = randomInt(i + 1, source);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/**
 * Every enabled set contributes at least one character; the rest are drawn from the union.
 * Entropy reported by `passwordEntropy` is the conservative log2(|union|) * length.
 */
export function generatePassword(o: PasswordOptions, source: RandomSource = defaultSource): string {
  const length = Math.max(4, Math.min(128, Math.floor(o.length)));
  const sets = charsetsFor(o);
  if (!sets.length) throw new Error('Choose at least one character set');
  const all = sets.join('');
  const out: string[] = sets.map((s) => s[randomInt(s.length, source)]);
  while (out.length < length) out.push(all[randomInt(all.length, source)]);
  return shuffle(out, source).slice(0, length).join('');
}

export function passwordEntropy(o: PasswordOptions): number {
  const n = charsetsFor(o).join('').length;
  return n ? Math.floor(Math.log2(n) * Math.max(4, Math.min(128, Math.floor(o.length)))) : 0;
}

export interface PassphraseOptions {
  words: number;
  separator: string;
  capitalize: boolean;
  includeNumber: boolean;
}

export const DEFAULT_PASSPHRASE: PassphraseOptions = { words: 6, separator: '-', capitalize: true, includeNumber: true };

export function generatePassphrase(o: PassphraseOptions, source: RandomSource = defaultSource): string {
  const count = Math.max(3, Math.min(20, Math.floor(o.words)));
  const words = Array.from({ length: count }, () => WORDS[randomInt(WORDS.length, source)]);
  const shaped = words.map((w) => (o.capitalize ? w[0].toUpperCase() + w.slice(1) : w));
  if (o.includeNumber) {
    const at = randomInt(shaped.length, source);
    shaped[at] = shaped[at] + String(randomInt(10, source));
  }
  return shaped.join(o.separator);
}

export function passphraseEntropy(o: PassphraseOptions): number {
  const count = Math.max(3, Math.min(20, Math.floor(o.words)));
  let bits = count * Math.log2(WORDS.length);
  if (o.includeNumber) bits += Math.log2(10) + Math.log2(count);
  return Math.floor(bits);
}
