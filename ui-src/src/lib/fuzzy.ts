// Small fuzzy matcher for vault search and the command palette. Scores contiguous and
// word-start matches higher; returns null when not every query character appears in order.

export interface FuzzyHit {
  score: number;
  /** Indexes into `text` that matched (for highlighting). */
  positions: number[];
}

export function fuzzyMatch(query: string, text: string): FuzzyHit | null {
  const q = query.toLowerCase().trim();
  if (!q) return { score: 0, positions: [] };
  const t = text.toLowerCase();
  const direct = t.indexOf(q);
  if (direct >= 0) {
    const atStart = direct === 0 || /[\s\-_./@]/.test(t[direct - 1]);
    return { score: 1000 - direct + (atStart ? 200 : 0) + q.length * 10, positions: Array.from({ length: q.length }, (_, i) => direct + i) };
  }
  let score = 0;
  let ti = 0;
  let prev = -2;
  const positions: number[] = [];
  for (const ch of q) {
    if (ch === ' ') continue;
    const found = t.indexOf(ch, ti);
    if (found < 0) return null;
    positions.push(found);
    score += found === prev + 1 ? 15 : 1;
    if (found === 0 || /[\s\-_./@]/.test(t[found - 1])) score += 10;
    score -= Math.min(found - ti, 10) * 0.5;
    prev = found;
    ti = found + 1;
  }
  return { score, positions };
}

/** Best score over several fields (first field weighted highest). */
export function fuzzyScore(query: string, fields: (string | undefined | null)[]): number | null {
  let best: number | null = null;
  fields.forEach((f, i) => {
    if (!f) return;
    const hit = fuzzyMatch(query, f);
    if (hit) {
      const s = hit.score * (i === 0 ? 1.5 : 1);
      if (best === null || s > best) best = s;
    }
  });
  return best;
}
