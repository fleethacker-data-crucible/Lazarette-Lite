import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwind from '@tailwindcss/vite';
import { cpSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const outDir = resolve('../ui/dist');
export default defineConfig({
  base: './',
  resolve: { alias: { $lib: resolve('src/lib'), $components: resolve('src/components') } },
  plugins: [tailwind(), svelte(), {
    name: 'lite-assets',
    apply: 'build',
    buildStart() {
      if (process.platform === 'win32') {
        execFileSync('powershell.exe', ['-NoLogo', '-NoProfile', '-File', resolve('../Stop-LazaretteLite.ps1')], { stdio: 'inherit' });
      }
    },
    closeBundle() {
      for (const dir of ['standard_fonts', 'cmaps']) {
        cpSync(resolve('node_modules/pdfjs-dist', dir), resolve(outDir, 'pdfjs', dir), { recursive: true });
      }
      const files = readdirSync(outDir, { recursive: true, withFileTypes: true })
        .filter((entry) => entry.isFile() && entry.name !== 'manifest.json')
        .map((entry) => resolve(entry.parentPath, entry.name).slice(outDir.length + 1).replaceAll('\\', '/'))
        .sort();
      writeFileSync(resolve(outDir, 'manifest.json'), JSON.stringify(files, null, 2) + '\n');
    }
  }],
  build: { outDir, emptyOutDir: true, assetsInlineLimit: 0, target: ['chrome120', 'edge120', 'firefox121'] }
});
