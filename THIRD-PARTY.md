# Third-party components

Everything Lazarette ships is bundled into `ui/dist` or `pdf-engine/pkg` at build time; nothing is fetched at run time.

| Component | Version | Licence | Used for |
| --- | --- | --- | --- |
| Svelte | 5.57.2 | MIT | UI framework |
| Tailwind CSS | 4.3.3 | MIT | Styling |
| bits-ui | 2.19.5 | MIT | Accessible primitives (dialogs, menus) |
| Lucide | 1.54.0 | ISC | Icons |
| Apache ECharts / ZRender | 6.1.0 | Apache-2.0 | Charts |
| Svelte Flow (@xyflow/svelte) | 1.7.0 | MIT | Requirement graph |
| Motion | 12.42.0 | MIT | Animation |
| pdf.js (pdfjs-dist) | 4.10.38 | Apache-2.0 | In-app PDF preview, including XFA forms. `ui-src/src/lib/pdf/pdfjs-xfa.css` is copied from its `web/viewer.css`. |
| pdf-lib | 1.17.1 | MIT | Fallback PDF form engine when WebAssembly is unavailable |
| SecLists common passwords | — | MIT | `lib/data/common-passwords.txt` (weak-passphrase check) |
| Nayuki QR Code generator | 1.8.0 | MIT | `ui-src/src/vendor/qrcodegen.ts` (2FA QR code) |

The Rust PDF engine (`pdf-engine/`) has no dependencies.
