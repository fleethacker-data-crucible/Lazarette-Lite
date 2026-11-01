#requires -Version 5.1
# =============================================================================
# Copy a secret to the clipboard and clear it again after a short time.
#
# No background process, no scheduled task, no timer that could outlive the
# console: Copy-LiteSecret waits in the foreground and clears when the time is
# up, or when you press Ctrl+C. It only clears if the clipboard still holds the
# secret, so it never wipes something you copied in the meantime.
#
# The clipboard is behind a four-member interface like the credential backend:
#   Set $text    Get -> text or $null    Clear    Wait $seconds
# =============================================================================

$script:LiteClipboard = $null

function Get-LiteClipboard {
    if (-not $script:LiteClipboard) { $script:LiteClipboard = New-LiteWindowsClipboard }
    return $script:LiteClipboard
}

function Set-LiteClipboardBackend {
    # Test seam. Pass $null to go back to the Windows clipboard.
    param($Clipboard)
    $script:LiteClipboard = $Clipboard
}

function New-LiteWindowsClipboard {
    if ($env:OS -ne 'Windows_NT') { throw 'Lazarette Lite uses the Windows clipboard and only runs on Windows.' }
    Add-Type -AssemblyName System.Windows.Forms
    [pscustomobject]@{
        Name  = 'windows-forms'
        Set   = {
            param($Text)
            if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
                throw 'The clipboard needs a single-threaded apartment. Start Windows PowerShell without -MTA.'
            }
            $d = New-Object System.Windows.Forms.DataObject
            $d.SetText($Text, [System.Windows.Forms.TextDataFormat]::UnicodeText)
            # Documented opt-outs: keep the secret out of Windows clipboard history (Win+V),
            # cloud clipboard sync and clipboard-monitoring tools that honour these formats.
            $no = { New-Object System.IO.MemoryStream -ArgumentList (, [byte[]](0, 0, 0, 0)) }
            $d.SetData('ExcludeClipboardContentFromMonitorProcessing', (& $no))
            $d.SetData('CanIncludeInClipboardHistory', (& $no))
            $d.SetData('CanUploadToCloudClipboard', (& $no))
            [System.Windows.Forms.Clipboard]::SetDataObject($d, $true, 10, 100)
        }
        Get   = {
            try { if ([System.Windows.Forms.Clipboard]::ContainsText()) { [System.Windows.Forms.Clipboard]::GetText() } else { $null } }
            catch { $null }
        }
        Clear = { [System.Windows.Forms.Clipboard]::Clear() }
        Wait  = { param($Seconds) Start-Sleep -Seconds $Seconds }
    }
}

function Copy-LiteSecret {
    <#
    .SYNOPSIS
        Puts one secret on the clipboard, waits, then clears it. Press Ctrl+C to clear it early.
    .PARAMETER ClearAfterSeconds  How long the secret stays on the clipboard. 5 to 300, default 20.
    .OUTPUTS
        Service, User, Seconds and Outcome (Cleared, ClipboardChanged or AlreadyEmpty). Never the secret.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Name')][string]$Service,
        [string]$User = '',
        [ValidateRange(5, 300)][int]$ClearAfterSeconds = 20
    )
    $item = Resolve-LiteCredential -Service $Service -User $User
    $secret = Get-LiteSecret -Service $item.Service -User $item.User
    $cb = Get-LiteClipboard
    $outcome = 'Cleared'
    try {
        & $cb.Set $secret
        for ($left = $ClearAfterSeconds; $left -gt 0; $left--) {
            Write-Progress -Activity 'Secret is on the clipboard' -Status ("Clears in {0} s. Press Ctrl+C to clear it now." -f $left) `
                -PercentComplete ([int](100 * ($ClearAfterSeconds - $left) / $ClearAfterSeconds))
            & $cb.Wait 1
        }
    } finally {
        Write-Progress -Activity 'Secret is on the clipboard' -Completed
        $now = & $cb.Get
        if ($now -ceq $secret) { & $cb.Clear }
        elseif ([string]::IsNullOrEmpty($now)) { $outcome = 'AlreadyEmpty' }
        else { $outcome = 'ClipboardChanged' }
        $secret = $null; $now = $null
    }
    [pscustomobject]@{ Service = $item.Service; User = $item.User; Seconds = $ClearAfterSeconds; Outcome = $outcome }
}
