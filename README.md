<p align="center">
  <img src="assets/brand/emblem-transparent.png" width="280" alt="Lazarette Lite emblem">
</p>

# Lazarette Lite

Lazarette Lite brings Lazarette's browser experience to Windows Credential Manager. It manages the current Windows user's generic credentials and supplies named secrets to Fleet tools.

## Use it

Double-click `Launch-LazaretteLite.bat`. The browser opens on a private, temporary loopback session. Use `--console` to keep launch diagnostics visible, or `--credential-console` for the terminal credential menu, including metadata-only import and export. Use `--replace` to restart an existing session without a prompt, `--stay` or `LAZARETTE_LITE_AUTO_STOP=0` to keep it alive after the tab closes, and `Stop-LazaretteLite.ps1` to stop it from the shell.

The browser supports searching, favourites for the current session, adding and editing credentials, revealing and copying secrets, password and passphrase generation, and read-only PDF form extraction. PDF.js reads AcroForm and supported XFA fields inside a browser worker. Files and extracted values stay in that tab. Test the specific XFA forms needed for the demo.

## Fleet demo setup

Create the services the demo tools already expect, then wrap your usual Fleet launcher:

```powershell
.\Start-LiteFleet.ps1 -Launcher C:\Demo\Start-Fleet.cmd
```

The wrapper sets `LAZARETTE_PATH` and `ARC_PATH` for the launch and its children. The `lib\Lazarette.ps1` and `lib\Arc.ps1` loaders support both generations of secret lookup with `-Service` and optional `-User`. The compatibility unlock calls check provider access under the current Windows session. The Lite-specific module exports `Get-LiteSecret` directly.

Custom vault fields and full Lazarette's Fairlead peer API require separate integration.

## Authorization boundary

- Secrets are generic Windows credentials in the current user's store. Windows handles storage and protection. Lite ships no vault engine, encrypted files, or custom vault cryptography.
- The loopback listener binds to `127.0.0.1` on a Windows-assigned port. It checks the process owner's Windows SID, the Host and Origin, a one-time launch token, and a browser session cookie. API responses use `Cache-Control: no-store`.
- Lite makes no outbound requests. The browser assets, PDF worker, fonts, and character maps are served locally. The server stops after Quit or when the browser session goes away.
- Windows PowerShell 5.1 and a browser run the prebuilt app. No admin install or Node runtime is needed on the demo workstation. Sign the PowerShell release files for workstations using `AllSigned`.

Workstation application control and the ISSM's authorization decision still apply.

## Build

From `ui-src`, run `npm ci`, `npm run check`, and `npm run build`. The runtime serves the generated files in `ui/dist`.

MIT. See [LICENSE](LICENSE).
