/** Match Field's visible error/hint, so controls never reference hidden or absent text. */
export function fieldDescriptionId(id: string | undefined, hasError: boolean, hasHint = false): string | undefined {
  if (!id) return undefined;
  return hasError ? `${id}-error` : hasHint ? `${id}-hint` : undefined;
}
