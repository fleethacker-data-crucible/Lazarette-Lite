// Motion (vanilla API, `motion/mini`: hardware-accelerated WAAPI animations, ~3 KB) as Svelte
// attachments. Everything is skipped when the person prefers reduced motion. WAAPI is allowed by
// the CSP (no inline styles are written).
import { animate } from 'motion/mini';
const motionReduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

const EASE: [number, number, number, number] = [0.2, 0.9, 0.25, 1];

function transform(x = 0, y = 0, scale = 1) {
  return `translate(${x}px, ${y}px) scale(${scale})`;
}

export function motionIn(opts: { y?: number; x?: number; scale?: number; duration?: number; delay?: number } = {}) {
  return (el: HTMLElement) => {
    if (motionReduced()) return;
    const keyframes: Record<string, string[] | number[]> = { opacity: [0, 1] };
    if (opts.x || opts.y || opts.scale) keyframes.transform = [transform(opts.x, opts.y, opts.scale ?? 1), transform()];
    const a = animate(el, keyframes, { duration: opts.duration ?? 0.2, delay: opts.delay ?? 0, ease: EASE });
    return () => a.stop();
  };
}

/** Staggers the direct children of a container when it first mounts. */
export function staggerChildren(opts: { y?: number; each?: number } = {}) {
  return (el: HTMLElement) => {
    if (motionReduced() || !el.children.length) return;
    const kids = Array.from(el.children).slice(0, 24) as HTMLElement[];
    const anims = kids.map((k, i) =>
      animate(k, { opacity: [0, 1], transform: [transform(0, opts.y ?? 6), transform()] }, { duration: 0.22, delay: i * (opts.each ?? 0.018), ease: EASE })
    );
    return () => anims.forEach((a) => a.stop());
  };
}

/** Counts a number up into an element's text (requestAnimationFrame, ease-out). */
export function countUp(el: HTMLElement, to: number, duration = 0.8) {
  if (motionReduced()) {
    el.textContent = String(Math.round(to));
    return;
  }
  const start = performance.now();
  const step = (t: number) => {
    const p = Math.min(1, (t - start) / (duration * 1000));
    el.textContent = String(Math.round(to * (1 - Math.pow(1 - p, 3))));
    if (p < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
