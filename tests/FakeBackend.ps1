# An in-memory stand-in for Windows Credential Manager, behind the same four-member
# interface as the real backend (see lib\Backend.Windows.ps1). Synthetic data only.
# It keeps the real service's rules that matter here: names compare case-insensitively,
# 'prefix*' enumeration, the 2,560-byte blob limit, and Enumerate never returns secrets.

function New-LiteFakeBackend {
    $store = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $calls = New-Object 'System.Collections.Generic.List[string]'
    $toItem = {
        param($e, $withSecret)
        $o = [pscustomobject]@{
            Target = $e.Target; UserName = $e.UserName; Comment = $e.Comment
            LastWritten = $e.LastWritten; SecretBytes = [Text.Encoding]::Unicode.GetByteCount($e.Secret); Secret = $null
        }
        if ($withSecret) { $o.Secret = $e.Secret }
        $o
    }
    $b = [pscustomobject]@{
        Name  = 'fake'
        Store = $store
        Calls = $calls
    }
    $b | Add-Member -MemberType NoteProperty -Name Enumerate -Value ({
        param($Filter)
        $calls.Add("Enumerate $Filter")
        if (-not $Filter.EndsWith('*')) { throw 'fake: only prefix* filters are supported' }
        $p = $Filter.TrimEnd('*')
        @($store.Values | Where-Object { $_.Target.StartsWith($p, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { & $toItem $_ $false })
    }.GetNewClosure())
    $b | Add-Member -MemberType NoteProperty -Name Read -Value ({
        param($Target)
        $calls.Add("Read $Target")
        if ($store.ContainsKey($Target)) { & $toItem $store[$Target] $true } else { $null }
    }.GetNewClosure())
    $b | Add-Member -MemberType NoteProperty -Name Write -Value ({
        param($Target, $UserName, $Comment, $Secret)
        $calls.Add("Write $Target")
        if ([Text.Encoding]::Unicode.GetByteCount($Secret) -gt 2560) { throw 'fake: ERROR_BAD_LENGTH (1306)' }
        $store[$Target] = [pscustomobject]@{ Target = $Target; UserName = $UserName; Comment = $Comment; Secret = $Secret; LastWritten = [datetime]'2026-10-30T09:00:00Z' }
    }.GetNewClosure())
    $b | Add-Member -MemberType NoteProperty -Name Delete -Value ({
        param($Target)
        $calls.Add("Delete $Target")
        if ($store.ContainsKey($Target)) { $store.Remove($Target); $true } else { $false }
    }.GetNewClosure())
    return $b
}

function ConvertTo-LiteTestSecure {
    param([string]$Text)
    ConvertTo-SecureString -String $Text -AsPlainText -Force
}
