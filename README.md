<p align="center">
  <img src="assets/brand/emblem-transparent.png" width="280" alt="Lazarette Lite fleet emblem: a compact sailor lockbox and key, in navy, brass and ivory">
</p>

# Lazarette Lite

**Your Windows credentials, without a new vault.** Lazarette Lite is a small front end to **Windows Credential Manager** for locked-down workstations. It reads, adds, updates and removes the current user's generic credentials, and gives scripts one way to fetch a secret by name.

It is the deliberately small sibling of [Lazarette](https://github.com/fleethacker-data-crucible/Lazarette), the full-featured encrypted vault. Lite exists so a team can manage and share credentials with scripts **without bringing a new data store, new cryptography or a network service onto the workstation**. Whether that keeps it inside the workstation's existing authorization is for the ISSM to decide. The design below aims to make that an easy call.

> **Status:** empty scaffold. Nothing is built yet.

## Design rules

These rules are the point of Lite. A change that breaks one belongs in Lazarette, not here.

| Rule | Why |
| --- | --- |
| **No data store of its own.** Every secret lives in Windows Credential Manager. | No new file format to review, nothing extra to back up or protect. |
| **No custom cryptography.** Windows protects the secrets with DPAPI, under the user's account. | No crypto code for an assessor to evaluate. |
| **No network.** No outbound calls, no update channel, no telemetry. | Nothing leaves the machine. |
| **No installs, no admin rights, no DLLs.** Windows PowerShell 5.1 only; any C# ships as source and is compiled with `Add-Type`. | Runs under application control the same way the rest of the Fleet does. |
| **Signed scripts.** Every script is Authenticode-signed for release. | It can run under an `AllSigned` execution policy. |
| **Current user only.** It never reads another account's credentials. | It stays inside what Windows already allows the user to do. |
| **Small.** It should stay readable in one sitting. | Easy to review and to keep reviewed. |

## Planned scope

- List, search, add, edit and delete the current user's **generic** credentials, under a configurable target prefix (for example `lazarette-lite/`).
- `Get-LiteSecret -Name <name>` for scripts, mirroring Lazarette's `Get-ArcSecret` so a script can later move to the full vault unchanged.
- Copy a secret to the clipboard, cleared automatically after a short time.
- An export and import file for moving names and metadata between machines, **never** the secrets themselves.

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

## Open questions

1. **User interface.**
   - Option A, the Fleet pattern: a browser UI on `127.0.0.1`.
   - Option B, the smaller footprint: a console or WinForms UI with **no listener at all**.
   - B is easier to defend for authorization; A matches the rest of the Fleet.
2. **Credential Manager limits.** Each secret is limited to about 2.5 KB, and enterprise policy may restrict roaming. Confirm both on the target workstation.
3. **Prefix and naming.** These need to match Lazarette's Credential Manager bridge, so the two can coexist on one machine.

## License

MIT. See [LICENSE](LICENSE).
