import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/vite-plugin-svelte').SvelteConfig} */
export default {
  preprocess: vitePreprocess({ script: true, style: false }),
  // CSS is always emitted as files, never injected at runtime: required by the CSP.
  vitePlugin: { emitCss: true },
  compilerOptions: {
    css: 'external',
    discloseVersion: false
  }
};
