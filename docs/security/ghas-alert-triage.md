# GHAS alert triage (sprint 2026-11)

Open Dependabot alerts on `ui-src/package-lock.json` as of this sprint. Alerts were not dismissed from here. For the accepted alert, the recommended Dependabot dismissal reason is in the reason column.

| Alert | Rule / package | Path | Disposition | Reason |
| --- | --- | --- | --- | --- |
| dependabot #1 | vite (npm), GHSA-698v-4r3x-3vcv | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #2 | vite (npm), GHSA-587h-7wmj-h5pm | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #3 | vite (npm), GHSA-r825-w8mm-5pxw | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #4 | vite (npm), GHSA-vfpm-58rq-9qcg | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #5 | vite (npm), GHSA-rq7h-c2jc-7f22 | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #6 | vite (npm), GHSA-9jrq-w75r-8gcw | ui-src/package-lock.json | fixed | DevDependency `vite` moved from 8.3.0 to 8.3.8 (same major; first patched release for the 8.3.0–8.3.2 advisories is 8.3.3) and `ui/dist` was rebuilt. |
| dependabot #7 | deepmerge (npm), GHSA-gcqx-w48m-w2h4 | ui-src/package-lock.json | accept: false positive | Transitive devDependency of `@sveltejs/vite-plugin-svelte@7.3.1` (`dev: true`); it only deep-merges local Svelte/Vite config and is absent from `ui/dist`. npm’s latest release is 4.3.1, inside `>=4.2.0, <=4.3.1`, and `npm audit` reports `fixAvailable: false`. No published version above 4.3.1 exists; 4.1.2 sits outside the advisory range and outside the plugin’s `^4.3.1` requirement, and 4.2.0 changed which properties are overwritten, so it is not a safe override. CVE-2026-93753 was rejected by its CNA (VulnCheck) on 2026-11-02 because it does not describe a security vulnerability; the GHSA is still open (`withdrawn_at` null as of 2026-11-13). Recommend Dependabot dismissal: inaccurate. |

## deepmerge

`deepmerge@4.3.1` is pulled in only by `@sveltejs/vite-plugin-svelte@7.3.1` (`deepmerge: ^4.3.1`), which is a devDependency. The lockfile marks the package `dev: true`. The plugin calls it from `options.js` to merge its own config objects, starting from `{}`, with arrays replaced by the source. Those objects are the local build configuration. The production bundle in `ui/dist` does not contain `deepmerge`.

The GitHub advisory lists no patched version. The npm registry’s newest `deepmerge` release is 4.3.1 (published 2023-03-16). `npm audit` after the Vite bump reports this advisory only (the package and its parent), with `fixAvailable: false`.

## vite

`vite` is a devDependency used by `npm run build`. 8.3.3 is the first release that patches the six open advisories (bundled `launch-editor` 2.14.2, plus the `server.fs` / custom-middleware fixes). This repo pins 8.3.8, the current 8.3 patch, which stays on major 8 and also includes the 8.3.7 fix for GHSA-p4f5-76q4-ffq7 (dev-server code execution when the server is exposed to the network). The workstation runtime serves the rebuilt files in `ui/dist` and does not run the Vite dev server.
