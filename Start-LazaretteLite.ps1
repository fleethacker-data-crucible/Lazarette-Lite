#requires -Version 5.1
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Prefix,
    [switch]$ShowConsole,
    [switch]$NoBrowser,
    [switch]$Stay,
    [switch]$Replace,
    [switch]$CredentialConsole,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Options
)

$ErrorActionPreference = 'Stop'
foreach ($option in $Options) {
    switch ($option) {
        '--console' { $ShowConsole = $true }
        '--no-browser' { $NoBrowser = $true }
        '--stay' { $Stay = $true }
        '--replace' { $Replace = $true }
        '--credential-console' { $CredentialConsole = $true }
        default { throw "Unknown Lazarette Lite option: $option" }
    }
}

$instance = $null
$locked = $false
$runtime = $null
try {
    Import-Module (Join-Path $PSScriptRoot 'LazaretteLite.psd1')
    if ($Prefix) { Set-LitePrefix $Prefix | Out-Null }
    if ($CredentialConsole) { Start-LiteConsole; return }

    . (Join-Path $PSScriptRoot 'lib\server\Http.ps1')
    . (Join-Path $PSScriptRoot 'lib\server\Routes.ps1')
    . (Join-Path $PSScriptRoot 'lib\server\Instances.ps1')
    $dist = Join-Path $PSScriptRoot 'ui\dist'
    if (-not (Test-Path -LiteralPath (Join-Path $dist 'manifest.json') -PathType Leaf)) {
        throw 'Build the browser app with npm ci and npm run build in ui-src.'
    }
    $instance = New-LiteInstance
    $locked = Enter-LiteInstance $instance
    if (-not $locked) {
        if (-not $Replace) {
            $question = 'Lazarette Lite is already running. Stop it and start a new session?'
            if ($NoBrowser) { throw "$question Use --replace to confirm." }
            if ($ShowConsole) {
                $Replace = (Read-Host "$question [y/N]") -match '^y(es)?$'
            } else {
                Add-Type -AssemblyName System.Windows.Forms
                $Replace = [Windows.Forms.MessageBox]::Show($question, 'Lazarette Lite', 'YesNo', 'Question', 'Button2') -eq 'Yes'
            }
        }
        if (-not $Replace) { return }
        Stop-LiteInstance $instance
        $locked = $true
    }
    [void]$instance.Stop.Reset()
    Remove-LiteStaleRuntimeFiles
    $dir = Get-LiteRuntimeDirectory
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $runtime = Join-Path $dir "lazarette-lite-server-$PID.json"
    Start-ArcHttpServer -PreferredPort 0 -UiRoot $dist -StopSignal $instance.Stop -AutoStop (-not $Stay -and $env:LAZARETTE_LITE_AUTO_STOP -ne '0') -OnReady {
        param($Url)
        $base = ([uri]$Url).GetLeftPart([UriPartial]::Authority)
        @{ pid = $PID; port = ([uri]$base).Port; url = $base; started = [DateTime]::UtcNow.ToString('o') } |
            ConvertTo-Json -Compress | Set-Content -LiteralPath $runtime -Encoding UTF8
        if ($NoBrowser) { Write-Output $Url } else { Start-Process $Url }
    }
} catch {
    if (-not ($ShowConsole -or $NoBrowser -or $CredentialConsole)) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Lazarette Lite', 'OK', 'Error')
    }
    throw
} finally {
    if ($runtime) { Remove-Item -LiteralPath $runtime -ErrorAction SilentlyContinue }
    if ($instance) {
        if ($locked) { $instance.Mutex.ReleaseMutex() }
        $instance.Stop.Dispose()
        $instance.Mutex.Dispose()
    }
}
