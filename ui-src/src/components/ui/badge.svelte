<script lang="ts" module>
  import { cva, type VariantProps } from 'class-variance-authority';
  export const badgeVariants = cva('inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium leading-4 whitespace-nowrap [&_svg]:size-3', {
    variants: {
      variant: {
        default: 'border-transparent bg-primary-soft text-primary',
        secondary: 'border-border bg-muted text-muted-foreground',
        outline: 'border-border-strong text-foreground',
        success: 'border-transparent bg-success-soft text-success',
        warning: 'border-transparent bg-warning-soft text-warning',
        destructive: 'border-transparent bg-destructive-soft text-destructive'
      }
    },
    defaultVariants: { variant: 'default' }
  });
  export type BadgeVariant = VariantProps<typeof badgeVariants>['variant'];
</script>

<script lang="ts">
  import type { HTMLAttributes } from 'svelte/elements';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';
  type Props = HTMLAttributes<HTMLSpanElement> & { variant?: BadgeVariant; children?: Snippet };
  let { class: className, variant = 'default', children, ...rest }: Props = $props();
</script>

<span class={cn(badgeVariants({ variant }), className)} {...rest}>{@render children?.()}</span>
