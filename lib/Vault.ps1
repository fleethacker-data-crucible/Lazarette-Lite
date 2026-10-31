#requires -Version 5.1
# =============================================================================
# Names, limits and CRUD over the credential backend. There is no state here
# beyond the backend itself: no cache, no file, no config store.
#
# Target layout (the same shape as Lazarette's bridge, PM/<service>/<user>):
#     <prefix><service>/<user>        e.g.  lazarette-lite/gitlab/anthony
# Secret blob: UTF-16LE text, generic credential, persisted for this machine
# only, exactly as Lazarette's Write-ArcWinCred stores it.
# =============================================================================

$script:LiteDefaultPrefix = 'lazarette-lite/'
$script:LitePrefixOverride = $null
$script:LiteBackend = $null
$script:LiteMaxSecretBytes = 2560      # CRED_MAX_CREDENTIAL_BLOB_SIZE (5 * 512)
$script:LiteMaxComment = 256           # CRED_MAX_STRING_LENGTH
$script:LiteMaxName = 100
$script:LiteMaxTarget = 450            # same ceiling as Lazarette's Test-ArcWinCredTarget

function Get-LiteBackend {
    if (-not $script:LiteBackend) { $script:LiteBackend = New-LiteWindowsBackend }
    return $script:LiteBackend
}

function Set-LiteBackend {
    # Test seam. Pass $null to go back to Windows Credential Manager.
    param($Backend)
    $script:LiteBackend = $Backend
}

# --- prefix -----------------------------------------------------------------

function Test-LitePrefix {
    # Returns an error message, or $null when the prefix is acceptable.
    param([string]$Prefix)
    if ([string]::IsNullOrEmpty($Prefix)) { return 'The prefix is empty.' }
    if ($Prefix.Length -lt 2 -or $Prefix.Length -gt 100) { return 'The prefix must be 2 to 100 characters.' }
    if (-not $Prefix.EndsWith('/')) { return "The prefix must end with '/'." }
    if ($Prefix -match '[*\x00-\x1f]') { return "The prefix cannot contain '*' or control characters." }
    if ($Prefix -match '^(?i:PM/)') { return "The prefix 'PM/' belongs to Lazarette's bridge, which rewrites those entries from its vault. Pick another prefix." }
    return $null
}

function Get-LitePrefix {
    <#
    .SYNOPSIS
        Shows the target prefix in use: the session value, then LAZARETTE_LITE_PREFIX, then lazarette-lite/.
    #>
    # Session override, then the LAZARETTE_LITE_PREFIX environment variable, then the default.
    $p = if ($script:LitePrefixOverride) { $script:LitePrefixOverride }
         elseif ($env:LAZARETTE_LITE_PREFIX) { $env:LAZARETTE_LITE_PREFIX }
         else { $script:LiteDefaultPrefix }
    $err = Test-LitePrefix $p
    if ($err) { throw "Lazarette Lite prefix '$p' is not usable. $err" }
    return $p
}

function Set-LitePrefix {
    <#
    .SYNOPSIS
        Sets the target prefix for this session (-Reset to undo). PM/ is refused: it belongs to Lazarette.
    #>
    [CmdletBinding()]
    param([string]$Prefix, [switch]$Reset)
    if ($Reset -or [string]::IsNullOrEmpty($Prefix)) { $script:LitePrefixOverride = $null; return }
    $err = Test-LitePrefix $Prefix
    if ($err) { throw $err }
    $script:LitePrefixOverride = $Prefix
    return $Prefix
}

# --- validation -------------------------------------------------------------

function Assert-LiteName {
    param([string]$Value, [string]$What)
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "$What cannot be empty." }
    if ($Value.Trim() -ne $Value) { throw "$What cannot start or end with a space." }
    if ($Value -match '[/*\x00-\x1f]') { throw "$What cannot contain '/', '*' or control characters ('/' separates the service from the user in the stored name)." }
    if ($Value.Length -gt $script:LiteMaxName) { throw "$What is $($Value.Length) characters; the limit is $script:LiteMaxName." }
}

function Assert-LiteComment {
    param([string]$Comment)
    if ($null -eq $Comment) { return }
    if ($Comment.Length -gt $script:LiteMaxComment) { throw "The note is $($Comment.Length) characters; Windows Credential Manager allows $script:LiteMaxComment." }
    if ($Comment -match '[\x00-\x08\x0b\x0c\x0e-\x1f]') { throw 'The note cannot contain control characters.' }
}

function Assert-LiteSecretSize {
    param([string]$Secret)
    $bytes = [Text.Encoding]::Unicode.GetByteCount($Secret)
    if ($bytes -gt $script:LiteMaxSecretBytes) {
        throw ("The secret is {0:N0} bytes. Windows Credential Manager stores at most {1:N0} bytes per credential ({2:N0} characters, kept as UTF-16). " -f $bytes, $script:LiteMaxSecretBytes, ($script:LiteMaxSecretBytes / 2)) +
              'Nothing was written. Keep large secrets (certificates, key files) in Lazarette, which has attachments.'
    }
}

function Get-LiteTarget {
    param([string]$Service, [string]$User)
    Assert-LiteName $Service 'The service'
    if ([string]::IsNullOrEmpty($User)) { $User = $Service }     # Lazarette's default: user = service
    Assert-LiteName $User 'The user'
    $t = (Get-LitePrefix) + $Service + '/' + $User
    if ($t.Length -gt $script:LiteMaxTarget) { throw "The stored name would be $($t.Length) characters; the limit is $script:LiteMaxTarget." }
    return $t
}

function ConvertFrom-LiteSecureString {
    param([Parameter(Mandatory)][securestring]$Secret)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# --- read side --------------------------------------------------------------

function ConvertTo-LiteItem {
    param($Raw, [string]$Prefix)
    $rest = $Raw.Target.Substring($Prefix.Length)
    $i = $rest.IndexOf('/')
    $svc = if ($i -ge 0) { $rest.Substring(0, $i) } else { $rest }
    $usr = if ($i -ge 0) { $rest.Substring($i + 1) } else { '' }
    [pscustomobject]@{
        PSTypeName  = 'Lite.Credential'
        Service     = $svc
        User        = $usr
        Comment     = [string]$Raw.Comment
        LastWritten = $Raw.LastWritten
        HasSecret   = ([int]$Raw.SecretBytes -gt 0)
        Target      = [string]$Raw.Target
    }
}

function Get-LiteCredential {
    <#
    .SYNOPSIS
        Lists the current user's credentials under the Lite prefix. Never returns secrets.
    .PARAMETER Search   Case-insensitive text found in the service, user or note.
    #>
    [CmdletBinding()]
    param([string]$Search, [string]$Service, [string]$User)
    $prefix = Get-LitePrefix
    $raw = @(& (Get-LiteBackend).Enumerate "$prefix*") | Where-Object { $_.Target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and $_.Target.Length -gt $prefix.Length }
    $items = @($raw | ForEach-Object { ConvertTo-LiteItem $_ $prefix })
    if ($Service) { $items = @($items | Where-Object { $_.Service -ieq $Service }) }
    if ($User) { $items = @($items | Where-Object { $_.User -ieq $User }) }
    if ($Search) {
        $items = @($items | Where-Object {
            ($_.Service.IndexOf($Search, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            ($_.User.IndexOf($Search, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            ($_.Comment.IndexOf($Search, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        })
    }
    return @($items | Sort-Object Service, User)
}

function Resolve-LiteCredential {
    # Exactly one item or a throw. Wording follows Lazarette's Find-ArcItem.
    param([Parameter(Mandatory)][string]$Service, [string]$User = '')
    $hits = @(Get-LiteCredential -Service $Service -User $User)
    if ($hits.Count -eq 0) { throw "Lazarette Lite has no item '$Service'$(if ($User) { " for user '$User'" })." }
    if ($hits.Count -gt 1) { throw "Lazarette Lite has $($hits.Count) items named '$Service'; pass -User to choose one." }
    return $hits[0]
}

# --- write side -------------------------------------------------------------

function Add-LiteCredential {
    <#
    .SYNOPSIS
        Adds a generic credential. Fails if one with the same service and user exists, unless -Force.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Service,
        [string]$User = '',
        [Parameter(Mandatory)][securestring]$Secret,
        [string]$Comment = '',
        [switch]$Force
    )
    $target = Get-LiteTarget $Service $User
    if ([string]::IsNullOrEmpty($User)) { $User = $Service }
    Assert-LiteComment $Comment
    $plain = ConvertFrom-LiteSecureString $Secret
    try {
        if ($plain.Length -eq 0) { throw 'The secret is empty. Use Set-LiteCredential later to fill one in.' }
        Assert-LiteSecretSize $plain
        $b = Get-LiteBackend
        if ((& $b.Read $target) -and -not $Force) { throw "Lazarette Lite already has '$Service' for user '$User'. Use Set-LiteCredential to change it, or pass -Force to replace it." }
        & $b.Write $target $User $Comment $plain
    } finally { $plain = $null }
    return Resolve-LiteCredential $Service $User
}

function Set-LiteCredential {
    <#
    .SYNOPSIS
        Edits one credential. Only the parts you pass change; the secret is kept unless -Secret is given.
    .PARAMETER NewService  Rename the service (this moves the stored name).
    .PARAMETER NewUser     Rename the user (this moves the stored name).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Service,
        [string]$User = '',
        [string]$NewService,
        [string]$NewUser,
        [string]$Comment,
        [securestring]$Secret
    )
    $cur = Resolve-LiteCredential $Service $User
    $svc = if ($PSBoundParameters.ContainsKey('NewService')) { $NewService } else { $cur.Service }
    $usr = if ($PSBoundParameters.ContainsKey('NewUser')) { $NewUser } else { $cur.User }
    $note = if ($PSBoundParameters.ContainsKey('Comment')) { $Comment } else { $cur.Comment }
    $target = Get-LiteTarget $svc $usr
    if ([string]::IsNullOrEmpty($usr)) { $usr = $svc }
    Assert-LiteComment $note
    $b = Get-LiteBackend
    $moving = -not ($target -ieq $cur.Target)
    if ($moving -and (& $b.Read $target)) { throw "Lazarette Lite already has '$svc' for user '$usr'; nothing was changed." }
    $plain = $null
    try {
        if ($PSBoundParameters.ContainsKey('Secret')) {
            $plain = ConvertFrom-LiteSecureString $Secret
            if ($plain.Length -eq 0) { throw 'The secret is empty.' }
        } else {
            $old = & $b.Read $cur.Target
            $plain = if ($old) { [string]$old.Secret } else { '' }
        }
        Assert-LiteSecretSize $plain
        & $b.Write $target $usr $note $plain
        if ($moving) { [void](& $b.Delete $cur.Target) }
    } finally { $plain = $null }
    return Resolve-LiteCredential $svc $usr
}

function Remove-LiteCredential {
    <#
    .SYNOPSIS
        Deletes one credential from Windows Credential Manager. Asks first; -Confirm:$false skips the question.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][string]$Service, [string]$User = '')
    $cur = Resolve-LiteCredential $Service $User
    if ($PSCmdlet.ShouldProcess("$($cur.Service) / $($cur.User)", 'Delete credential from Windows Credential Manager')) {
        [void](& (Get-LiteBackend).Delete $cur.Target)
    }
}
