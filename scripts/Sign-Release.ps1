#requires -Version 5.1
<#
.SYNOPSIS  Authenticode-signs the Lazarette Lite scripts for release, or checks that they are signed.
.DESCRIPTION
    Release scripts are meant to run under an AllSigned execution policy. This script signs every shipped
    .ps1, .psm1 and .psd1 (the root files and lib\; not tests\ or scripts\) with a code-signing certificate
    that YOU hold. The repository contains no certificate and no private key, and this script never
    exports or copies one: it only asks Windows to sign with the certificate in your own store.

    Sign:    .\scripts\Sign-Release.ps1 -Thumbprint <thumbprint of a code-signing cert in Cert:\CurrentUser\My>
             Add -TimestampServer <url> so the signature outlives the certificate. That is the only step that
             contacts a network, it runs once on the release machine, and Lazarette Lite itself never does.
    Verify:  .\scripts\Sign-Release.ps1 -Verify        (exit code 1 if any file is not validly signed)

    Sign the files LAST, after the final edit: any change to a signed file, even a line ending, breaks its
    signature. .gitattributes pins line endings so a checkout does not change the signed bytes.
.PARAMETER Root  The folder to sign or check. Defaults to the repository root; tests point it elsewhere.
#>
[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(ParameterSetName = 'Sign', Mandatory)][string]$Thumbprint,
    [Parameter(ParameterSetName = 'Sign')][string]$TimestampServer,
    [Parameter(ParameterSetName = 'Verify')][switch]$Verify,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$files = @(
    Get-ChildItem -LiteralPath $Root -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' }
    $lib = Join-Path $Root 'lib'
    if (Test-Path -LiteralPath $lib) { Get-ChildItem -LiteralPath $lib -File -Filter '*.ps1' }
)
if ($files.Count -eq 0) { throw "No scripts found under '$Root'." }

if ($PSCmdlet.ParameterSetName -eq 'Sign') {
    $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq ($Thumbprint -replace '\s', '').ToUpperInvariant() } | Select-Object -First 1
    if (-not $cert) { throw "No certificate with thumbprint $Thumbprint in Cert:\CurrentUser\My." }
    if (-not $cert.HasPrivateKey) { throw 'That certificate has no private key on this machine, so it cannot sign.' }
    if ($cert.EnhancedKeyUsageList.ObjectId -notcontains '1.3.6.1.5.5.7.3.3') { throw 'That certificate is not a code-signing certificate.' }
    foreach ($f in $files) {
        $sign = @{ FilePath = $f.FullName; Certificate = $cert; HashAlgorithm = 'SHA256' }
        if ($TimestampServer) { $sign.TimestampServer = $TimestampServer }
        $r = Set-AuthenticodeSignature @sign
        '{0,-12} {1}' -f $r.Status, $f.FullName.Substring($Root.Length).TrimStart('\')
    }
}

# Always finish by checking, so a signing run proves its own result.
$results = foreach ($f in $files) {
    $s = Get-AuthenticodeSignature -LiteralPath $f.FullName
    [pscustomobject]@{ File = $f.FullName.Substring($Root.Length).TrimStart('\'); Status = [string]$s.Status; Signer = $(if ($s.SignerCertificate) { $s.SignerCertificate.Subject } else { '' }) }
}
$results | Format-Table -AutoSize | Out-String | Write-Host
$notValid = @($results | Where-Object { $_.Status -ne 'Valid' })
if ($notValid.Count -gt 0) { Write-Host ("{0} of {1} files are not validly signed." -f $notValid.Count, $results.Count); exit 1 }
Write-Host ("All {0} files are validly signed." -f $results.Count)
exit 0
