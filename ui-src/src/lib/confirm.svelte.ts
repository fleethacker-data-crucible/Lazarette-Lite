// Promise-based confirmation dialogs rendered by <ConfirmHost/> (bits-ui AlertDialog).
export interface ConfirmRequest {
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  /** Require typing this word before confirming (for irreversible bulk actions). */
  typeToConfirm?: string;
  details?: string[];
}

interface Pending extends ConfirmRequest {
  resolve: (ok: boolean) => void;
}

class ConfirmState {
  current = $state<Pending | null>(null);
  ask(req: ConfirmRequest): Promise<boolean> {
    this.current?.resolve(false);
    return new Promise((resolve) => {
      this.current = { ...req, resolve };
    });
  }
  settle(ok: boolean) {
    const c = this.current;
    this.current = null;
    c?.resolve(ok);
  }
}

export const confirmState = new ConfirmState();
export const confirm = (req: ConfirmRequest) => confirmState.ask(req);
