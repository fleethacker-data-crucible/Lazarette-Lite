<script lang="ts" module>
  import { cva, type VariantProps } from 'class-variance-authority';

  export const buttonVariants = cva(
    'inline-flex shrink-0 select-none items-center justify-center gap-2 whitespace-nowrap rounded-md text-[13px] font-medium transition-[background-color,border-color,color,box-shadow] duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-45 aria-disabled:pointer-events-none aria-disabled:opacity-45 [&_svg]:pointer-events-none [&_svg]:shrink-0',
    {
      variants: {
        variant: {
          default: 'bg-primary text-primary-foreground hover:bg-primary-hover',
          secondary: 'border border-input bg-transparent text-foreground hover:bg-muted',
          outline: 'border border-input bg-transparent text-foreground hover:bg-muted',
          ghost: 'text-foreground hover:bg-muted',
          subtle: 'text-muted-foreground hover:bg-muted hover:text-foreground',
          destructive: 'bg-destructive text-background hover:brightness-110',
          'destructive-outline': 'border border-destructive/40 text-destructive hover:bg-destructive-soft',
          link: 'h-auto px-0 text-primary underline-offset-4 hover:underline'
        },
        size: {
          default: 'h-8 px-3 [&_svg]:size-4',
          sm: 'h-8 px-2.5 text-xs [&_svg]:size-3.5',
          lg: 'h-9 px-4 text-sm [&_svg]:size-4',
          icon: 'size-8 [&_svg]:size-4',
          'icon-sm': 'size-8 [&_svg]:size-4',
          'icon-xs': 'size-7 rounded-md [&_svg]:size-3.5'
        }
      },
      defaultVariants: { variant: 'default', size: 'default' }
    }
  );

  export type ButtonVariant = VariantProps<typeof buttonVariants>['variant'];
  export type ButtonSize = VariantProps<typeof buttonVariants>['size'];
</script>

<script lang="ts">
  import type { HTMLButtonAttributes, HTMLAnchorAttributes } from 'svelte/elements';
  import type { Snippet } from 'svelte';
  import { cn } from '$lib/utils';

  type Props = HTMLButtonAttributes &
    Pick<HTMLAnchorAttributes, 'href' | 'target' | 'rel'> & {
      variant?: ButtonVariant;
      size?: ButtonSize;
      ref?: HTMLElement | null;
      children?: Snippet;
    };

  let { class: className, variant = 'default', size = 'default', href, target, rel, ref = $bindable(null), children, type = 'button', ...rest }: Props = $props();
</script>

{#if href}
  <a bind:this={ref} {href} {target} rel={rel ?? 'noopener noreferrer'} class={cn(buttonVariants({ variant, size }), className)} {...rest as HTMLAnchorAttributes}>
    {@render children?.()}
  </a>
{:else}
  <button bind:this={ref} {type} class={cn(buttonVariants({ variant, size }), className)} {...rest}>
    {@render children?.()}
  </button>
{/if}
