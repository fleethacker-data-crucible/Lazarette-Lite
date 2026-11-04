// Fetch wrapper for the Lazarette local API (docs/API.md v5.1).
// - same-origin cookie + `X-ARC-Client: arc-ui/1` on every request
// - errors become ApiError with the server's `error` code; 401 session / 403 locked /
//   409 setup-required are also reported to the session state machine (no retry loops).

export const CLIENT_HEADER = { 'X-ARC-Client': 'arc-ui/1' } as const;

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly retryAfter?: number;
  constructor(status: number, code: string, message: string, retryAfter?: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

const FRIENDLY: Record<string, string> = {
  session: 'Session ended — relaunch Lazarette.',
  locked: 'The vault is locked.',
  'setup-required': 'Create your vault first.',
  origin: 'This page is not allowed to talk to Lazarette.',
  'bad-credentials': 'That passphrase is not correct.',
  'bad-pin': 'The smart card PIN was not accepted.',
  'no-card': 'No smart card was found. Insert your card and try again.',
  'wrong-cert': 'This card does not hold the certificate this vault was created with.',
  'card-locked': 'The smart card is locked. Contact your card administrator.',
  'totp-invalid': 'That code is not valid. Check the time on this PC and try again.',
  'totp-required': 'Enter the code from your authenticator app.',
  'rate-limited': 'Too many attempts.',
  'weak-passphrase': 'Choose a stronger passphrase.',
  duplicate: 'An item with this name and account already exists.',
  version: 'This item changed since you opened it. Reload it and try again.',
  network: 'Lazarette is not responding. If it has stopped, start it again from Launch-LazaretteLite.bat.',
  'no-legacy': 'No previous-version (3/4) vault was found.',
  unsupported: 'Not available on this computer.',
  signature: 'The release is not signed by the pinned publisher.',
  checksum: 'The release files do not match SHA256SUMS.',
  manifest: 'This is not a valid Lazarette release zip.',
  'too-large': 'That file is too large.'
};

/** Message to show a person for any thrown value. Server text is shown as plain text only. */
export function describeError(e: unknown): string {
  if (e instanceof ApiError) {
    if (e.code === 'rate-limited' && e.retryAfter) return `Too many attempts. Try again in ${formatWait(e.retryAfter)}.`;
    return e.message && e.message !== e.code ? e.message : FRIENDLY[e.code] || `Request failed (${e.status}).`;
  }
  if (e instanceof Error) return e.message;
  return String(e);
}

export function formatWait(seconds: number): string {
  if (seconds < 60) return `${Math.max(1, Math.round(seconds))} s`;
  const m = Math.ceil(seconds / 60);
  return `${m} min`;
}

export interface ApiHooks {
  onSession?: () => void;
  onLocked?: () => void;
  onSetupRequired?: () => void;
  onSuccess?: () => void;
}

let hooks: ApiHooks = {};
export function configureApi(next: ApiHooks): void {
  hooks = next;
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: unknown;
  signal?: AbortSignal;
  accept?: string;
  /** Don't notify the session machine about 401/403/409 (used by the boot probe). */
  quiet?: boolean;
}

/** Parses an error response into an ApiError (never throws while doing so). */
export async function toApiError(res: Response): Promise<ApiError> {
  let code = `http-${res.status}`;
  let message = '';
  let retryAfter: number | undefined;
  try {
    const data = (await res.json()) as { error?: unknown; message?: unknown; retryAfter?: unknown };
    if (typeof data.error === 'string') code = data.error;
    if (typeof data.message === 'string') message = data.message;
    if (typeof data.retryAfter === 'number' && Number.isFinite(data.retryAfter)) retryAfter = data.retryAfter;
  } catch {
    /* not JSON */
  }
  if (retryAfter === undefined) {
    const h = Number(res.headers.get('Retry-After'));
    if (Number.isFinite(h) && h > 0) retryAfter = h;
  }
  return new ApiError(res.status, code, message || FRIENDLY[code] || `Request failed (${res.status}).`, retryAfter);
}

function notify(err: ApiError, quiet?: boolean): void {
  if (quiet) return;
  if (err.status === 401 && err.code === 'session') hooks.onSession?.();
  else if (err.status === 403 && err.code === 'locked') hooks.onLocked?.();
  else if (err.status === 409 && err.code === 'setup-required') hooks.onSetupRequired?.();
}

export async function rawRequest(path: string, opts: RequestOptions = {}): Promise<Response> {
  if (!path.startsWith('/api/')) throw new Error('Lazarette UI only talks to /api/ on this origin');
  const headers: Record<string, string> = { ...CLIENT_HEADER, Accept: opts.accept ?? 'application/json' };
  let body: string | undefined;
  if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(opts.body);
  }
  let res: Response;
  try {
    res = await fetch(path, {
      method: opts.method ?? (body === undefined ? 'GET' : 'POST'),
      headers,
      body,
      credentials: 'same-origin',
      cache: 'no-store',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
      signal: opts.signal
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new ApiError(0, 'network', FRIENDLY.network);
  }
  if (!res.ok) {
    const err = await toApiError(res);
    notify(err, opts.quiet);
    throw err;
  }
  hooks.onSuccess?.();
  return res;
}

export async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const res = await rawRequest(path, opts);
  if (res.status === 204) return undefined as T;
  try {
    return (await res.json()) as T;
  } catch {
    throw new ApiError(res.status, 'bad-response', 'Lazarette sent a response this page could not read.');
  }
}

/** Unauthenticated GET /api/health (no cookie needed, never returns a token). */
export async function getHealth<T>(): Promise<T> {
  let res: Response;
  try {
    res = await fetch('/api/health', { credentials: 'same-origin', cache: 'no-store', headers: { Accept: 'application/json' } });
  } catch {
    throw new ApiError(0, 'network', FRIENDLY.network);
  }
  if (!res.ok) throw await toApiError(res);
  return (await res.json()) as T;
}
