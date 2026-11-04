// Toast notifications. Messages are plain text (server text is never rendered as HTML).
export type ToastKind = 'info' | 'success' | 'error' | 'warning';
export interface Toast {
  id: number;
  kind: ToastKind;
  title: string;
  detail?: string;
  action?: { label: string; run: () => void };
}

let next = 1;
class Toasts {
  items = $state<Toast[]>([]);

  push(kind: ToastKind, title: string, detail?: string, opts: { timeout?: number; action?: Toast['action'] } = {}) {
    const id = next++;
    this.items = [...this.items.slice(-4), { id, kind, title, detail, action: opts.action }];
    const timeout = opts.timeout ?? (kind === 'error' ? 7000 : 4000);
    if (timeout > 0) setTimeout(() => this.dismiss(id), timeout);
    return id;
  }
  dismiss(id: number) {
    this.items = this.items.filter((t) => t.id !== id);
  }
  clear() {
    this.items = [];
  }
}

export const toasts = new Toasts();
export const toast = {
  info: (t: string, d?: string) => toasts.push('info', t, d),
  success: (t: string, d?: string) => toasts.push('success', t, d),
  warning: (t: string, d?: string) => toasts.push('warning', t, d),
  error: (t: string, d?: string) => toasts.push('error', t, d)
};
