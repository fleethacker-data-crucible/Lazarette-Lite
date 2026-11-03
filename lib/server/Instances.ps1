#requires -Version 5.1

function New-LiteInstance {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $name = "Local\Lazarette-Lite-$sid"
    $mutex = [Threading.Mutex]::new($false, "$name-instance")
    try {
        $stop = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, "$name-stop")
    } catch {
        $mutex.Dispose()
        throw
    }
    [pscustomobject]@{ Mutex = $mutex; Stop = $stop }
}

function Enter-LiteInstance {
    param($Instance, [int]$Timeout = 0)
    try { return $Instance.Mutex.WaitOne($Timeout) }
    catch [Threading.AbandonedMutexException] { return $true }
}

function Stop-LiteInstance {
    param($Instance)
    [void]$Instance.Stop.Set()
    if (-not (Enter-LiteInstance $Instance 35000)) {
        throw 'Lazarette Lite did not stop. It may still be finishing an operation.'
    }
}

function Get-LiteRuntimeDirectory {
    Join-Path $env:LOCALAPPDATA 'Lazarette-Lite\logs'
}

function Remove-LiteStaleRuntimeFiles {
    $dir = Get-LiteRuntimeDirectory
    Get-ChildItem -LiteralPath $dir -Filter 'lazarette-lite-server-*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match '^lazarette-lite-server-(\d+)\.json$' -and -not (Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        }
    }
}
