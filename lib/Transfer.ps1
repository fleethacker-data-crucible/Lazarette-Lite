#requires -Version 5.1
# =============================================================================
# Export and import of NAMES AND NOTES ONLY, for moving a list of what you have
# between machines. Secrets never enter this file and never leave Credential
# Manager through it:
#   * Export only calls the list (Enumerate), which does not copy any secret out of Windows.
#   * Import only creates placeholders with an empty secret; you fill each one in with
#     Set-LiteCredential (or the console) on that machine.
#   * Import refuses a file that has any field other than service, user and comment, so a
#     file that somebody put a secret in is rejected, not half-read.
#
# File format (UTF-8 JSON, version 1):
#   { "format": "lazarette-lite-export", "version": 1, "exported": "...", "prefix": "...",
#     "note": "...", "items": [ { "service": "...", "user": "...", "comment": "..." } ] }
# =============================================================================

$script:LiteExportFormat = 'lazarette-lite-export'
$script:LiteExportMaxBytes = 1MB
$script:LiteExportMaxItems = 5000

function Resolve-LiteFilePath {
    param([string]$Path)
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Export-LiteMetadata {
    <#
    .SYNOPSIS
        Writes the names, users and notes of your Lite credentials to a JSON file. Never the secrets.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$Force)
    $full = Resolve-LiteFilePath $Path
    if ((Test-Path -LiteralPath $full) -and -not $Force) { throw "'$full' already exists. Pass -Force to overwrite it." }
    $items = @(Get-LiteCredential | ForEach-Object { [ordered]@{ service = $_.Service; user = $_.User; comment = $_.Comment } })
    $doc = [ordered]@{
        format   = $script:LiteExportFormat
        version  = 1
        exported = (Get-Date).ToUniversalTime().ToString('o')
        prefix   = Get-LitePrefix
        note     = 'Names and notes only. Secrets are never exported.'
        items    = $items
    }
    $json = ConvertTo-Json -InputObject $doc -Depth 4
    [IO.File]::WriteAllText($full, $json, (New-Object System.Text.UTF8Encoding($false)))
    [pscustomobject]@{ Path = $full; Count = $items.Count }
}

function Read-LiteExportFile {
    # Validates the whole file before anything is created. Returns the items.
    param([string]$Path)
    $full = Resolve-LiteFilePath $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "No export file at '$full'." }
    if ((Get-Item -LiteralPath $full).Length -gt $script:LiteExportMaxBytes) { throw "'$full' is larger than 1 MB, which is far more than a list of names needs. Not read." }
    try { $doc = [IO.File]::ReadAllText($full) | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "'$full' is not valid JSON." }
    if ($null -eq $doc -or $doc -isnot [pscustomobject]) { throw "'$full' is not a Lazarette Lite export file." }
    $top = @($doc.PSObject.Properties.Name)
    if ($top -notcontains 'format' -or $doc.format -ne $script:LiteExportFormat) { throw "'$full' is not a Lazarette Lite export file." }
    if ($top -notcontains 'version' -or $doc.version -ne 1) { throw "Export file version '$($doc.version)' is not supported (this build reads version 1)." }
    foreach ($k in $top) {
        if ($k -notin 'format', 'version', 'exported', 'prefix', 'note', 'items') { throw "The export file has an unexpected field '$k'. Export files carry names and notes only, so it was not imported." }
    }
    if ($top -notcontains 'items') { throw 'The export file has no items list.' }
    $items = @($doc.items)
    if ($items.Count -gt $script:LiteExportMaxItems) { throw "The export file lists $($items.Count) items; the limit is $script:LiteExportMaxItems." }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $out = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $items.Count; $i++) {
        $n = $i + 1
        $it = $items[$i]
        if ($it -isnot [pscustomobject]) { throw "Item $n is not an object." }
        foreach ($k in $it.PSObject.Properties.Name) {
            if ($k -notin 'service', 'user', 'comment') { throw "Item $n has a field '$k'. Export files carry names and notes only, so the file was not imported." }
        }
        $has = @($it.PSObject.Properties.Name)
        $svc = if ($has -contains 'service') { [string]$it.service } else { '' }
        $usr = if ($has -contains 'user') { [string]$it.user } else { '' }
        $cmt = if ($has -contains 'comment') { [string]$it.comment } else { '' }
        try { $target = Get-LiteTarget $svc $usr; Assert-LiteComment $cmt }
        catch { throw "Item $n is not valid: $($_.Exception.Message)" }
        if (-not $seen.Add($target)) { throw "Item $n repeats an earlier item ('$svc' / '$usr')." }
        if ([string]::IsNullOrEmpty($usr)) { $usr = $svc }
        $out.Add([pscustomobject]@{ Service = $svc; User = $usr; Comment = $cmt; Target = $target })
    }
    return $out.ToArray()
}

function Import-LiteMetadata {
    <#
    .SYNOPSIS
        Creates a placeholder (no secret yet) for each name in an export file that you do not already have.
    .DESCRIPTION
        Existing entries are left alone and their secrets are never read. Fill each placeholder in with
                  Set-LiteCredential -Secret. Get-LiteSecret refuses a placeholder until you do.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Path)
    $items = Read-LiteExportFile $Path
    $have = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    Get-LiteCredential | ForEach-Object { [void]$have.Add($_.Target) }
    $b = Get-LiteBackend
    $rows = foreach ($it in $items) {
        $status = 'Skipped'
        if (-not $have.Contains($it.Target)) {
            $status = 'Created'
            if ($PSCmdlet.ShouldProcess("$($it.Service) / $($it.User)", 'Create placeholder with no secret')) { [void](& $b.Write $it.Target $it.User $it.Comment '') }
            else { $status = 'WouldCreate' }
        }
        [pscustomobject]@{ Service = $it.Service; User = $it.User; Status = $status }
    }
    $rows = @($rows)
    [pscustomobject]@{
        Created = @($rows | Where-Object { $_.Status -eq 'Created' }).Count
        Skipped = @($rows | Where-Object { $_.Status -eq 'Skipped' }).Count
        Items   = $rows
    }
}

# --- Lazarette CSV migration -------------------------------------------------
# A user exports their unlocked Lazarette vault to CSV themselves
# (POST /api/export, format 'csv') and imports that file here. Lazarette writes
# the header: name,url,username,password,note,totp,folder,type,fields
# (Lazarette lib/vault/Interop.ps1, ConvertTo-LazaretteExportCsv). Only
# name/username/password are read, plus note as the comment; url, totp, folder,
# type and fields are ignored because Lite keeps one secret per item and has no
# fields, TOTP or attachments. CSV only: a lazarette-transfer-v1 file is
# encrypted and is refused, never decrypted. The per-item report carries
# service/user/status only â€” never a secret. The CSV file itself is plaintext
# by Lazarette's design; delete it after the import.
$script:LiteCsvMaxBytes = 5MB

function Get-LiteCsvValue {
    param($Row, [string]$Column)
    $p = $Row.PSObject.Properties | Where-Object { $_.Name -ieq $Column } | Select-Object -First 1
    if ($null -eq $p -or $null -eq $p.Value) { return '' }
    return [string]$p.Value
}

function Get-LiteCsvSkipReason {
    # Maps a validation failure to a skip status: size problems are oversize, the rest invalid.
    param([string]$Message)
    if ($Message -match 'bytes|limit|characters') { return 'skipped-oversize' }
    return 'skipped-invalid'
}

function Import-LiteFromLazaretteCsv {
    <#
    .SYNOPSIS
        Imports secrets from a Lazarette CSV export into Lazarette Lite.
    .DESCRIPTION
        You export from unlocked Lazarette yourself (POST /api/export, format 'csv').
        Only name/username/password (and note, as the comment) are imported; TOTP,
        folders, types and custom fields are left out. A lazarette-transfer-v1 file
        is encrypted and is refused, never decrypted. The per-item report carries
        service/user/status only â€” never a secret.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$ServiceColumn = 'name',
        [string]$UserColumn = 'username',
        [string]$SecretColumn = 'password',
        [string]$NoteColumn = 'note'
    )
    $full = Resolve-LiteFilePath $Path
    if ([IO.Path]::GetExtension($full) -ine '.csv') { throw "'$full' is not a .csv file. Export from Lazarette as CSV (format 'csv'); a lazarette-transfer file is encrypted and cannot be imported here." }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "No CSV file at '$full'." }
    if ((Get-Item -LiteralPath $full).Length -gt $script:LiteCsvMaxBytes) { throw "'$full' is larger than 5 MB. Split the export and import it in parts." }
    $first = Get-Content -LiteralPath $full -TotalCount 1 -ErrorAction Stop
    if ($null -eq $first -or $first.TrimStart().StartsWith('{')) { throw "'$full' does not look like a CSV file (no header row, or JSON â€” export as CSV, not Bitwarden JSON or lazarette-transfer)." }
    try { $rows = @(Import-Csv -LiteralPath $full -Encoding UTF8 -ErrorAction Stop) }
    catch { throw "The CSV file '$full' could not be read: $($_.Exception.Message)" }
    if ($rows.Count -eq 0) { throw "'$full' has a header row but no data rows." }
    $cols = @($rows[0].PSObject.Properties.Name)
    $missing = @()
    foreach ($c in @($ServiceColumn, $UserColumn, $SecretColumn)) { if ($cols -inotcontains $c) { $missing += $c } }
    if ($missing.Count -gt 0) { throw "The CSV has no column(s): $($missing -join ', '). Lazarette CSV exports use name, username, password (header: name,url,username,password,note,totp,folder,type,fields); pass -ServiceColumn/-UserColumn/-SecretColumn to map other headers. Found: $($cols -join ', ')." }
    $have = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    Get-LiteCredential | ForEach-Object { [void]$have.Add($_.Target) }
    $out = New-Object 'System.Collections.Generic.List[object]'
    foreach ($row in $rows) {
        $svc = Get-LiteCsvValue $row $ServiceColumn
        $usr = Get-LiteCsvValue $row $UserColumn
        $sec = Get-LiteCsvValue $row $SecretColumn
        $note = if ($cols -icontains $NoteColumn) { Get-LiteCsvValue $row $NoteColumn } else { '' }
        $status = 'imported'
        if ([string]::IsNullOrWhiteSpace($svc) -or [string]::IsNullOrWhiteSpace($sec)) { $status = 'skipped-empty' }
        else {
            $target = $null
            try { $target = Get-LiteTarget $svc $usr } catch { $status = Get-LiteCsvSkipReason $_.Exception.Message }
            if ($status -eq 'imported') {
                if ($have.Contains($target)) { $status = 'skipped-duplicate' }
                elseif ([Text.Encoding]::Unicode.GetByteCount($sec) -gt $script:LiteMaxSecretBytes) { $status = 'skipped-oversize' }
                elseif ($note.Length -gt $script:LiteMaxComment) { $status = 'skipped-invalid' }
                else {
                    $ss = $null
                    try {
                        $ss = ConvertTo-SecureString -String $sec -AsPlainText -Force
                        Add-LiteCredential -Service $svc -User $usr -Secret $ss -Comment $note | Out-Null
                        [void]$have.Add($target)
                    } catch { $status = Get-LiteCsvSkipReason $_.Exception.Message }
                    finally { if ($ss) { $ss.Dispose() } $sec = $null }
                }
            }
        }
        $out.Add([pscustomobject]@{ Service = $svc; User = $usr; Status = $status })
    }
    $items = @($out.ToArray())
    [pscustomobject]@{
        Imported         = @($items | Where-Object { $_.Status -eq 'imported' }).Count
        SkippedOversize  = @($items | Where-Object { $_.Status -eq 'skipped-oversize' }).Count
        SkippedEmpty     = @($items | Where-Object { $_.Status -eq 'skipped-empty' }).Count
        SkippedDuplicate = @($items | Where-Object { $_.Status -eq 'skipped-duplicate' }).Count
        SkippedInvalid   = @($items | Where-Object { $_.Status -eq 'skipped-invalid' }).Count
        Items            = $items
    }
}