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
    .SYNOPSIS  Writes the names, users and notes of your Lite credentials to a JSON file. Never the secrets.
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
    .SYNOPSIS  Creates a placeholder (no secret yet) for each name in an export file that you do not already have.
    .DESCRIPTION  Existing entries are left alone and their secrets are never read. Fill each placeholder in with
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
