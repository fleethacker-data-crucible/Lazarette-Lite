#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\server\Instances.ps1')

$instance = New-LiteInstance
$locked = $false
try {
    $locked = Enter-LiteInstance $instance
    if (-not $locked) {
        Stop-LiteInstance $instance
        $locked = $true
        Write-Output 'Stopped Lazarette Lite.'
    }
    Remove-LiteStaleRuntimeFiles
} finally {
    if ($locked) { $instance.Mutex.ReleaseMutex() }
    $instance.Stop.Dispose()
    $instance.Mutex.Dispose()
}
