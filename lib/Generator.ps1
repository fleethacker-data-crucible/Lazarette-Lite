#requires -Version 5.1
# =============================================================================
# Password generator. It writes nothing and stores nothing: it asks the Windows
# random number generator for numbers and builds a string. That is the operating
# system's own CSPRNG, not cryptography of Lite's own; there is no algorithm here
# beyond "pick uniformly" (rejection sampling, so no modulo bias).
# =============================================================================

$script:LiteRandom = $null

function Get-LiteRandomInt {
    # Uniform integer in [0, Max). Test seam: set $script:LiteRandom to a scriptblock { param($Max) ... }.
    param([Parameter(Mandatory)][ValidateRange(1, 65536)][int]$Max)
    if ($script:LiteRandom) { return [int](& $script:LiteRandom $Max) }
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    try {
        $buf = New-Object byte[] 4
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$Max)
        do { $rng.GetBytes($buf); $v = [BitConverter]::ToUInt32($buf, 0) } while ($v -ge $limit)
        return [int]($v % [uint32]$Max)
    } finally { $rng.Dispose() }
}

function Set-LiteRandomSource {
    # Test seam. No argument goes back to the Windows generator.
    param([scriptblock]$Source)
    $script:LiteRandom = $Source
}

function New-LitePassword {
    <#
    .SYNOPSIS  Makes a random password. Returns a SecureString unless -AsPlainText is given.
    .DESCRIPTION  Contains at least one of each class it uses. Length 8 to 128 (default 20); Credential Manager
                  holds up to 1,280 characters. -NoSymbols suits systems that reject punctuation; -NoAmbiguous
                  drops look-alikes (0 O o 1 l I |) for passwords that get read aloud or retyped.
    #>
    [CmdletBinding()]
    param([ValidateRange(8, 128)][int]$Length = 20, [switch]$NoSymbols, [switch]$NoAmbiguous, [switch]$AsPlainText)
    $classes = @('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789')
    if (-not $NoSymbols) { $classes += '!#$%&*+-=?@^_~' }
    if ($NoAmbiguous) { $classes = @($classes | ForEach-Object { $_ -replace '[0Oo1lI|]', '' }) }
    $all = -join $classes
    $chars = New-Object 'System.Collections.Generic.List[char]'
    foreach ($c in $classes) { $chars.Add($c[(Get-LiteRandomInt $c.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[(Get-LiteRandomInt $all.Length)]) }
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {      # Fisher-Yates, so the guaranteed ones are not always first
        $j = Get-LiteRandomInt ($i + 1)
        $t = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $t
    }
    $text = -join $chars
    if ($AsPlainText) { return $text }
    $s = New-Object System.Security.SecureString
    foreach ($ch in $text.ToCharArray()) { $s.AppendChar($ch) }
    $s.MakeReadOnly()
    return $s
}
