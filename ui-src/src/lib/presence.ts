// Presence (TechStack "Lifecycle rules"): this tab owns the local server. A heartbeat every 5 s
// says "still here"; a sendBeacon "leaving" signal on pagehide lets the server stop within
// seconds instead of waiting for its 20 s timeout. A reload sends a fresh heartbeat from the new
// page inside the 5 s grace, so nothing stops. Every open tab has its own id; the server stops
// only when none of them is alive. Heartbeats are not vault activity: they never postpone the
// idle lock (see session.svelte.ts and lib/server/Http.ps1).
import { CLIENT_HEADER } from './api/client';

export const HEARTBEAT_PATH = '/api/heartbeat';
export const HEARTBEAT_MS = 5000;

export interface PresenceEnv {
  fetch: typeof fetch;
  sendBeacon?: (url: string, data: Blob) => boolean;
  setInterval: (fn: () => void, ms: number) => unknown;
  clearInterval: (id: unknown) => void;
  addEventListener: (target: 'window' | 'document', type: string, fn: () => void) => void;
  removeEventListener: (target: 'window' | 'document', type: string, fn: () => void) => void;
  isHidden: () => boolean;
}

export function newTabId(): string {
  const b = new Uint8Array(12);
  crypto.getRandomValues(b);
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
}

export function heartbeatBody(tab: string, leaving: boolean, hidden: boolean): string {
  return JSON.stringify({ tab, leaving, hidden });
}

function browserEnv(): PresenceEnv {
  const targetOf = (t: 'window' | 'document') => (t === 'window' ? window : document);
  return {
    fetch: (...a) => fetch(...a),
    sendBeacon: typeof navigator.sendBeacon === 'function' ? (u, d) => navigator.sendBeacon(u, d) : undefined,
    setInterval: (fn, ms) => window.setInterval(fn, ms),
    clearInterval: (id) => window.clearInterval(id as number),
    addEventListener: (t, type, fn) => targetOf(t).addEventListener(type, fn),
    removeEventListener: (t, type, fn) => targetOf(t).removeEventListener(type, fn),
    isHidden: () => document.visibilityState === 'hidden'
  };
}

/**
 * Starts the heartbeat for this tab and returns a function that stops it (after Quit, or when the
 * session has ended). The session itself is the HttpOnly `arc_session` cookie: normal heartbeats
 * also send X-ARC-Client like every API call; the beacon cannot set headers, so the server accepts
 * it on this one route with the cookie and the page's own Origin, as a leaving signal only.
 */
export function startHeartbeat(env: PresenceEnv = browserEnv(), intervalMs = HEARTBEAT_MS, tab = newTabId()): () => void {
  let stopped = false;
  // Set on pagehide, cleared on pageshow. While set, nothing but the leaving signal goes out: on close
  // the browser fires visibilitychange (hidden) after pagehide, and a heartbeat then would cancel it.
  let leftPage = false;
  const send = (leaving: boolean) => {
    if (stopped || (leftPage && !leaving)) return;
    try {
      void env
        .fetch(HEARTBEAT_PATH, {
          method: 'POST',
          headers: { ...CLIENT_HEADER, 'Content-Type': 'application/json' },
          body: heartbeatBody(tab, leaving, env.isHidden()),
          credentials: 'same-origin',
          cache: 'no-store',
          keepalive: true,
          referrerPolicy: 'no-referrer'
        })
        .catch(() => undefined);
    } catch {
      /* the server is gone; nothing to do */
    }
  };
  const onHide = () => {
    if (stopped) return;
    leftPage = true;
    // sendBeacon is what browsers reliably deliver during unload; a keepalive fetch is the fallback.
    let sent = false;
    try {
      if (env.sendBeacon) sent = env.sendBeacon(HEARTBEAT_PATH, new Blob([heartbeatBody(tab, true, true)], { type: 'application/json' }));
    } catch {
      sent = false;
    }
    if (!sent) send(true);
  };
  const onShow = () => {
    leftPage = false;
    send(false);
  };
  const onVisibility = () => send(false); // tell the server at once when the tab goes to/comes back from the background
  send(false);
  const timer = env.setInterval(() => send(false), intervalMs);
  env.addEventListener('window', 'pagehide', onHide);
  env.addEventListener('window', 'pageshow', onShow);
  env.addEventListener('document', 'visibilitychange', onVisibility);
  return () => {
    if (stopped) return;
    stopped = true;
    env.clearInterval(timer);
    env.removeEventListener('window', 'pagehide', onHide);
    env.removeEventListener('window', 'pageshow', onShow);
    env.removeEventListener('document', 'visibilitychange', onVisibility);
  };
}
