# Demo walkthrough (about 6 minutes)

A script for a screen recording. Everything uses a throwaway prefix and **made-up secrets**: never type a real password on camera. The prefix `lazarette-lite-demo/` keeps the demo apart from anything you already have in Credential Manager, and the last step removes it.

Needs Windows PowerShell 5.1 (not PowerShell 7), no admin, nothing installed.

## 0. Setup (off camera)

```powershell
cd <the Lazarette-Lite folder>
$env:LAZARETTE_LITE_PREFIX = 'lazarette-lite-demo/'
```

## 1. The pitch (30 s)

Say: Lite is a front end to the Windows Credential Manager you already have. No new vault, no new crypto, no network, no installs. Show `Control Panel > Credential Manager > Windows Credentials` and leave it open on the side; entries will appear there live.

## 2. The menu (60 s)

```powershell
.\Lazarette-Lite.ps1
```

Type `h`. Point out that there is no "show secret" action on purpose.

## 3. Add, generate, list (90 s)

- Choose `3` Add: service `gitlab`, user `demo.user`, note `build server`, secret `not-a-real-secret-1` (twice). It is hidden as you type.
- Choose `g` Generate: service `wiki`, user `demo.user`, length `24`, answer `n` to letters-only and `n` to copy.
- Choose `1`. The list shows names and notes, never secrets. Switch to Credential Manager and show both entries named `lazarette-lite-demo/gitlab/demo.user` and `lazarette-lite-demo/wiki/demo.user`. Say: that is the whole data store; Windows protects it with DPAPI under your account.

## 4. Copy and auto-clear (45 s)

Choose `6`, pick `gitlab`. Paste into Notepad to show it landed, then wait: the clipboard clears in 20 seconds (or press Ctrl+C to clear it now). Paste again to show it is empty.

## 5. The limit, with a clear error (30 s)

Choose `3`, service `big`, paste a fake secret over 1,280 characters (for example `'x' * 1300` copied from a prompt). It is refused with "Nothing was written". Say: Credential Manager holds about 2.5 KB per secret; bigger secrets belong in Lazarette.

## 6. Export, import, check (60 s)

- Choose `7`, accept the default file name. Open the JSON in Notepad: names and notes only, no secrets.
- Choose `5`, pick `wiki`, type `wiki` to delete it. Choose `8` and import the file. `wiki` comes back as a placeholder, flagged `[no secret yet]`.
- Choose `c`. The check reports the placeholder as a warning. Choose `4` to give it a fake secret and run `c` again: no problems.
- Quit with `q`.

## 7. Scripts (60 s)

```powershell
Import-Module .\LazaretteLite.psd1
Get-LiteSecret -Service gitlab -User demo.user      # prints the fake secret: only do this for a made-up one
Get-LiteSecret -Name gitlab -User demo.user         # -Name is the same as -Service
Get-LiteSecret -Service nope                        # a clear error
```

Say: the signature mirrors Lazarette's `Get-ArcSecret`, so a script moves to the full vault by changing the command name.

## 8. Clean up (off camera)

```powershell
Import-Module .\LazaretteLite.psd1 -Force
Get-LiteCredential | ForEach-Object { Remove-LiteCredential -Service $_.Service -User $_.User -Confirm:$false }
Remove-Item .\lazarette-lite-export.json -ErrorAction SilentlyContinue
$env:LAZARETTE_LITE_PREFIX = $null
```

Check Credential Manager: no `lazarette-lite-demo/` entries remain.

## Things not to claim

- It is not signed yet and has not been reviewed by an ISSM; say "designed so the ISSM's call is easy", not "approved".
- The clipboard's exclusion from Win+V history is set in code but has not been verified on a real desktop.
