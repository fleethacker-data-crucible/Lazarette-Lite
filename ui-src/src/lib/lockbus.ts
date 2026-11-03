// Everything that holds revealed values or decrypted caches registers here and is wiped on
// lock / session end. Handlers must be synchronous-safe; async work is awaited by `runLock`.
type Handler = () => void | Promise<void>;
const handlers = new Set<Handler>();

export function onLock(fn: Handler): () => void {
  handlers.add(fn);
  return () => handlers.delete(fn);
}

export async function runLock(): Promise<void> {
  await Promise.allSettled([...handlers].map((h) => Promise.resolve().then(h)));
}
