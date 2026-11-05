<p align="center">
  <img src="assets/brand/emblem-transparent.png" width="280" alt="Lazarette Lite emblem">
</p>

# Lazarette Lite

Lazarette Lite brings Lazarette's browser experience to Windows Credential Manager. It manages the current Windows user's generic credentials and supplies named secrets to Fleet tools.

## Use it

Double-click `Launch-LazaretteLite.bat`. The browser opens on a private, temporary loopback session. The launcher runs Windows PowerShell 5.1 with a process-scoped `-ExecutionPolicy Bypass`, like the other Fleet launchers, so the default Windows policy does not refuse the hidden script; it changes no machine setting. Use `--console` to keep launch diagnostics visible, or `--credential-console` for the terminal credential menu, including metadata-only import and export. Use `--replace` to restart an existing session without a prompt, `--stay` or `LAZARETTE_LITE_AUTO_STOP=0` to keep it alive after the tab closes, and `Stop-LazaretteLite.ps1` to stop it from the shell.

The browser supports searching, favourites for the current session, adding and editing credentials, revealing and copying secrets, password and passphrase generation, and read-only PDF form extraction. PDF.js reads AcroForm and supported XFA fields inside a browser worker. Files and extracted values stay in that tab. Test the specific XFA forms needed for the demo.

## Fleet tools: Lite in place of Lazarette

Fleet tools (Halyard, Eight Bells, Semaphore, TalkForge and others) load Lazarette through one contract (Lazarette `docs/INTEGRATION.md`): the folder named by `LAZARETTE_PATH` (TalkForge: `ARC_PATH`), else a folder called `Lazarette` next to the tool, else `%USERPROFILE%\Projects\Lazarette`, must hold `lib\Lazarette.ps1`, which defines `Unlock-LazaretteVaultInteractive`, `Test-LazaretteVaultUnlocked`, `Get-LazaretteSecret`, `Get-LazaretteItemNames` and `Lock-LazaretteVault`. Lite's `lib\Lazarette.ps1` (and `lib\Arc.ps1` for the older names) answers all of them from Windows Credential Manager, so the tools work unchanged and without Lazarette installed. Register once per Windows user:

```powershell
.\Register-LazaretteLite.ps1          # or: Launch-LazaretteLite.bat --register
```

It sets `LAZARETTE_PATH`, `ARC_PATH` and `GANGPLANK_LAZARETTE_PATH` in your user environment to this folder (no admin, nothing installed). A variable that already points at a working full Lazarette is left alone unless you pass `-Force`; `-Unregister` undoes the registration; `-WhatIf` shows what would change. Tools already open keep their old environment, so start them again. For one launch only, without saving anything, `.\Start-LiteFleet.ps1 -Launcher C:\Demo\Start-Fleet.cmd` sets the same variables for that process and its children.

What a tool sees: there is no lock, so nothing prompts and the vault counts as unlocked whenever Credential Manager can be read; an item has one secret, so `-Field` fails the way Lazarette fails for a field an item does not have; an item with no secret yet throws instead of returning an empty string. Create the items the tools expect (the names in Lazarette's `docs/FLEET-ITEMS.md`, for example `ai-api-key` for Eight Bells or `talkforge-api` for TalkForge). Fairlead needs no registration: it reads Lite's items straight from Credential Manager under the `lazarette-lite/` prefix, so keep the default prefix for the names Fairlead asks for.

`tools\lazarette.ps1` answers the `status`, `items`, `get` and `check` verbs of Lazarette's command line with the same output shapes and exit codes. `totp`, `run`, custom fields and Lazarette's Fairlead peer API need the full Lazarette.

## Authorization boundary

- Secrets are generic Windows credentials in the current user's store. Windows handles storage and protection. Lite ships no vault engine, encrypted files, or custom vault cryptography.
- The loopback listener binds to `127.0.0.1` on a Windows-assigned port. It checks the process owner's Windows SID, the Host and Origin, a one-time launch token, and a browser session cookie. API responses use `Cache-Control: no-store`.
- Lite makes no outbound requests. The browser assets, PDF worker, fonts, and character maps are served locally. The server stops after Quit or when the browser session goes away.
- Windows PowerShell 5.1 and a browser run the prebuilt app. No admin install or Node runtime is needed on the demo workstation. Sign the PowerShell release files for workstations using `AllSigned`.

Workstation application control and the ISSM's authorization decision still apply.

## Signing

Release scripts are meant to be Authenticode-signed so they run under an `AllSigned` execution policy. This repository contains no certificate and nothing in it is signed. The signing step is scripted but has not been run against a real certificate:

```powershell
# On the release machine, with a code-signing certificate in Cert:\CurrentUser\My, after the final edit:
.\scripts\Sign-Release.ps1 -Thumbprint <thumbprint> -TimestampServer <your timestamp url>
.\scripts\Sign-Release.ps1 -Verify      # exit code 1 unless every script is validly signed
```

- It signs the root scripts (`.ps1`, `.psm1`, `.psd1`), `lib\` with `lib\server\`, and `tools\`, not `tests\` or `scripts\`. The `.cmd` and `.bat` launchers are not checked by PowerShell policy, so they are not signed.
- Any edit after signing, even a line ending, breaks the signature. `.gitattributes` pins line endings so a checkout does not change the signed bytes.
- The timestamp server is the only network use. It happens once on the release machine, never at run time.
- Only `-Verify` and the refusal paths are tested, because there is no certificate to test the signing path with.

## Build

From `ui-src`, run `npm ci`, `npm run check`, and `npm run build`. The runtime serves the generated files in `ui/dist`.

MIT. See [LICENSE](LICENSE).
