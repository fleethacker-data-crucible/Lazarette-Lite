#requires -Version 5.1
# =============================================================================
# A read-only health check of the items under the prefix, for "will my scripts
# still work, and can I rebuild this machine's list?". It changes nothing and
# prints no secret: each secret is read into memory only to test its shape.
# =============================================================================

function Test-LiteStore {
    <#
    .SYNOPSIS
        Reports problems with the credentials under the prefix. Returns one row per problem; no rows means healthy.
    .OUTPUTS
        Severity (Warning or Error), Service, User, Problem.
    .DESCRIPTION
        Error    the item cannot be read, or the stored name is not <prefix><service>/<user>.
        Warning  no secret yet (an import placeholder); secret has leading or trailing whitespace or a line break
                 (a common paste mistake); stored user name differs from the name in the target; secret near the
                 2,560-byte limit.
    #>
    [CmdletBinding()]
    param()
    $b = Get-LiteBackend
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $add = { param($sev, $it, $msg) $rows.Add([pscustomobject]@{ Severity = $sev; Service = $it.Service; User = $it.User; Problem = $msg }) }
    foreach ($it in @(Get-LiteCredential)) {
        if ($it.User -eq '') { & $add 'Error' $it "The stored name '$($it.Target)' has no user part; scripts that pass -User cannot find it. Re-add it as service/user."; continue }
        try { $raw = & $b.Read $it.Target } catch { & $add 'Error' $it "Windows would not let it be read: $($_.Exception.Message)"; continue }
        if ($null -eq $raw) { & $add 'Error' $it 'It was listed but could not be read (removed or changed meanwhile).'; continue }
        $s = [string]$raw.Secret
        if ($s.Length -eq 0) { & $add 'Warning' $it 'No secret yet. Get-LiteSecret will refuse it until you set one.'; continue }
        if ($s -ne $s.Trim() -or $s -match '[\r\n]') { & $add 'Warning' $it 'The secret has leading or trailing whitespace or a line break, which is usually a paste mistake.' }
        if ([Text.Encoding]::Unicode.GetByteCount($s) -gt ($script:LiteMaxSecretBytes - 128)) { & $add 'Warning' $it 'The secret is close to the 2,560-byte limit.' }
        if ([string]$raw.UserName -ine $it.User) { & $add 'Warning' $it "The stored user name '$($raw.UserName)' differs from the name in the target ('$($it.User)')." }
        $s = $null
    }
    return $rows.ToArray()
}
