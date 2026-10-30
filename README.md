# Lazarette Lite

**Your Windows credentials, without a new vault.** Lazarette Lite is a small front end to **Windows Credential Manager** for locked-down workstations. It lists, searches, adds, edits and removes the current user's generic credentials, and gives scripts one way to fetch a secret by name.

It is the deliberately small sibling of [Lazarette](https://github.com/fleethacker-data-crucible/Lazarette), the full-featured encrypted vault. Lite exists so a team can manage and share credentials with scripts **without bringing a new data store, new cryptography or a network service onto the workstation**. Whether that keeps it inside the workstation's existing authorization is for the ISSM to decide. The design below aims to make that an easy call.

> **Status: all four planned items are built and tested, in draft PRs that have not been merged or released.**
> They are tested against a fake credential backend, plus one smoke test against the real Credential Manager on a throwaway prefix. They have **not** been signed, run on a hardened target workstation, or reviewed by an ISSM. See [What is not done](#what-is-not-done).

## Quick start

Windows PowerShell 5.1, no admin rights, nothing to install.

```powershell
.\Lazarette-Lite.ps1                       # the console menu
.\Lazarette-Lite.ps1 -Prefix 'team-a/'     # use another prefix for this run
```

Or double-click `Launch-LazaretteLite.cmd`. It does not change the execution policy, so on an `AllSigned` machine the scripts must be signed (see [Signing](#signing)).

From a script:

```powershell
Import-Module .\LazaretteLite.psd1
$token = Get-LiteSecret -Service gitlab -User anthony
```

## What it does

| You want to | Menu | Command |
| --- | --- | --- |
| List or search | 1, 2 | `Get-LiteCredential [-Search text]` |
| Add | 3 | `Add-LiteCredential -Service s [-User u] -Secret <SecureString> [-Comment note]` |
| Edit or rename | 4 | `Set-LiteCredential -Service s [-User u] [-NewService] [-NewUser] [-Comment] [-Secret]` |
| Delete | 5 | `Remove-LiteCredential -Service s [-User u]` |
| Get a secret in a script | | `Get-LiteSecret -Service s [-User u]` (`-Name` is an alias of `-Service`) |
| Copy a secret, cleared after 20 s | 6 | `Copy-LiteSecret -Service s [-User u] [-ClearAfterSeconds 5..300]` |
| Save the list of names and notes | 7 | `Export-LiteMetadata -Path file.json` |
| Recreate the names on another machine | 8 | `Import-LiteMetadata -Path file.json` |

Names are not case sensitive. If a service has more than one user you must pass `-User`, as with Lazarette.

### Moving a script to the full vault

`Get-LiteSecret` mirrors `Get-ArcSecret` from Lazarette's `lib\cli\Console.ps1`: the same parameters (`-Service`, `-User`, `-Field`), a plain string back, and a thrown error when the item is missing or ambiguous. To move a script to Lazarette, change the command name. Differences, on purpose:

- There is no unlock step. Windows already unlocks Credential Manager with the user's session.
- Lite items have no custom fields, so `-Field` always fails the way Lazarette does for a field that does not exist.
- An item with no secret yet (an imported placeholder) throws instead of returning an empty string.

### Export and import never carry secrets

The export file holds `service`, `user` and `comment` for each item. Export reads only the list, never a secret. Import checks the whole file first, refuses any field other than those three (so a file with a `secret` or `password` in it is rejected, not half-read), and creates **placeholders with no secret** for names you do not already have. Existing items are left alone. Fill each placeholder in with Edit. `*-export.json` is in `.gitignore`.

## Design rules

These rules are the point of Lite. A change that breaks one belongs in Lazarette, not here. `tests\DesignRules.Tests.ps1` checks the obvious ways of breaking them (network, crypto, DLLs and installs, file writes, other accounts, size, encoding). These are blunt text checks and a review still matters.

| Rule | Why | Where it shows |
| --- | --- | --- |
| **No data store of its own.** Every secret lives in Windows Credential Manager. | No new file format to review, nothing extra to back up or protect. | No cache and no config file. The prefix is a session value or the `LAZARETTE_LITE_PREFIX` environment variable. Only `Export-LiteMetadata` writes a file, and only when asked. |
| **No custom cryptography.** Windows protects the secrets with DPAPI, under the user's account. | No crypto code for an assessor to evaluate. | The code never encrypts, hashes or derives anything. |
| **No network.** No outbound calls, no update channel, no telemetry. | Nothing leaves the machine. | No listener either (see the UI decision). |
| **No installs, no admin rights, no DLLs.** Windows PowerShell 5.1 only; any C# ships as source and is compiled with `Add-Type`. | Runs under application control the same way the rest of the Fleet does. | The one piece of C# is a here-string in `lib\Backend.Windows.ps1`, so the script signature covers it. |
| **Signed scripts.** Every script is Authenticode-signed for release. | It can run under an `AllSigned` execution policy. | See [Signing](#signing). **Not yet signed.** |
| **Current user only.** It never reads another account's credentials. | It stays inside what Windows already allows the user to do. | Generic credentials, this user's, persisted for this machine only. |
| **Small.** It should stay readable in one sitting. | Easy to review and to keep reviewed. | About 900 lines of script, comments included. A test fails above 1,500. |

## Answers to the open questions

### 1. User interface: Option B, built; Option A, not built

Anthony has not answered this yet, so the build went with the smaller footprint, a console UI with **no listener at all**: a menu in the console (`lib\Console.ps1`). There is no port, no browser and no local server. It is easy to revisit; the menu is a thin layer over the same functions scripts call.

For the record, I think B is the right call and I would not add A. A browser UI on `127.0.0.1` matches the rest of the Fleet and edits more nicely, but it adds a listener, and a listener is the first thing an assessor asks about; it also pulls in a web page, a session token and CSRF handling, which are exactly the new surface Lite exists to avoid. Anyone who wants that experience has Lazarette. B has a cost: no mouse, no table sorting, and secrets are typed at a hidden prompt.

### 2. Credential Manager limits

- **Size.** The documented maximum is 2,560 bytes per credential (`CRED_MAX_CREDENTIAL_BLOB_SIZE`, 5 x 512). Lazarette's bridge stores the secret as UTF-16, so that is **1,280 characters**. Lite checks this before writing and refuses with a clear error that writes nothing and points to Lazarette (which has attachments) for larger secrets. The smoke test confirmed that Windows on the build used here accepts exactly 2,560 bytes. Other builds and policies should still be checked.
- **Notes.** A credential's note is limited to 256 characters.
- **Roaming.** Lite persists with `CRED_PERSIST_LOCAL_MACHINE`, as Lazarette's bridge does, so entries do not roam with an enterprise profile. Enterprise policy can still restrict or disable Credential Manager; **confirm on the target workstation.** That has not been done.

### 3. Prefix and naming

Lazarette's Credential Manager bridge (`lib\integrations\WinCred.ps1`) writes `PM/<service>/<user>`, with the user name in the credential's user field and the secret as UTF-16 text in a generic credential persisted for this machine only. Lite uses the same shape and encoding under its own prefix:

| | Lazarette bridge | Lazarette Lite |
| --- | --- | --- |
| Stored name | `PM/<service>/<user>` | `<prefix><service>/<user>`, default `lazarette-lite/<service>/<user>` |
| Blank user | user = service | user = service |
| Secret | UTF-16 text, generic, local machine | the same |

So the two coexist on one machine without touching each other:

- Lite only ever lists, reads or writes names under its own prefix. Lazarette only looks at `PM/`.
- Lazarette **rewrites** the `PM/` entries from its vault, so Lite refuses `PM/` as a prefix. Pick another one if you want a different name (`Set-LitePrefix`, `-Prefix`, or `LAZARETTE_LITE_PREFIX`). A prefix must end in `/`, and `*` is not allowed.
- `/` separates service from user, so neither may contain one.
- There is no automatic move from Lite to Lazarette. Lite's export has no secrets, and Lazarette has no importer for it, so add the items there by hand.

## Not in Lite (use Lazarette)

These belong in Lazarette instead:
- the encrypted vault and its version history;
- attachments;
- the authenticator app and second factor;
- smart-card unlock;
- the PDF form filler;
- access packages;
- the assistant;
- sharing between users;
- signed self-updates.

There is also deliberately no "show secret on screen" action in Lite. Copy it, or call `Get-LiteSecret`.

## Signing

Every shipped script is meant to be Authenticode-signed for release. **This repository contains no certificate, and nothing here is signed.** The signing step is documented and scripted but has not been run against a real certificate:

```powershell
# On the release machine, with a code-signing certificate in Cert:\CurrentUser\My, after the final edit:
.\scripts\Sign-Release.ps1 -Thumbprint <thumbprint> -TimestampServer <your timestamp url>
.\scripts\Sign-Release.ps1 -Verify      # exit code 1 unless every script is validly signed
```

Notes:
- It signs the root and `lib\` scripts (`.ps1`, `.psm1`, `.psd1`), not `tests\` or `scripts\`. The `.cmd` launcher is not code that PowerShell policy checks, so it is not signed.
- Any edit after signing, even a line ending, breaks the signature. `.gitattributes` pins line endings so a checkout does not change the signed bytes. The scripts are plain ASCII, which a test enforces.
- The timestamp server is the only network use, it happens once on the release machine, and Lite never does it at run time.
- Only `-Verify` and the refusal paths are tested. The signing path itself is untested because there is no certificate to test with.

## Tests

```powershell
.\tests\Run-Tests.ps1           # Pester 5 or newer, Windows PowerShell 5.1, fake backend only
.\tests\Run-Tests.ps1 -Smoke    # also runs the one real Credential Manager test
```

The credential backend and the clipboard sit behind small interfaces (four members each), and the tests use in-memory fakes. The smoke test is the only one that touches Windows Credential Manager. It makes up a throwaway prefix, writes only under it, and deletes everything under it afterwards, so it never reads or changes a credential that was already there. All test data is synthetic. Pester 5 or newer has to be present already; Windows ships only 3.4 and Lite installs nothing.

## What is not done

- **Not merged or released.** The work is in stacked draft PRs.
- **Not signed.** No certificate was available; see above.
- **Not run on a hardened target workstation.** Credential Manager policy, application control and `AllSigned` behaviour are unconfirmed.
- **The real clipboard is untested.** The code sets the Windows opt-out formats for clipboard history and cloud sync, but nobody has checked on a real desktop that Win+V and cloud clipboard skip the secret.
- **The console look and feel** was tried only through piped input, not by a person at a window.
- **No ISSM review**, and no CI in this repository yet (so no Fleet Gate run).

## License

MIT. See [LICENSE](LICENSE).
