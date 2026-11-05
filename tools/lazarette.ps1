#requires -Version 5.1
<#
.SYNOPSIS
  Lazarette's command line, answered by Lazarette Lite: status, items, get, check (see lib\Cli.ps1).
.EXAMPLE
  .\tools\lazarette.ps1 status -Json
  .\tools\lazarette.ps1 check ai-api-key gitlab      # names only; exit 3 if any is missing or ambiguous
  $pat = .\tools\lazarette.ps1 get gitlab -User you  # the secret on stdout
.NOTES
  Exit codes, the same as Lazarette: 0 ok, 1 usage or error, 2 store unreadable, 3 not found or ambiguous.
  Only get writes a secret to the output. totp, run, -Field, -Type and -Tag need the full Lazarette; the
  parameters are accepted so a Lazarette command line still parses, and answer exit code 1 with a message.
#>
param(
    [Parameter(Position = 0)][string]$Verb = 'help',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Name = @(),
    [string]$User = '', [string]$Field = '', [string]$Type = '', [string]$Tag = '',
    [string[]]$EnvMap = @(), [string]$Command = '', [string[]]$CommandArgs = @(),
    [switch]$Json, [switch]$NoPrompt
)
$ErrorActionPreference = 'Stop'
. ([IO.Path]::Combine((Split-Path -Parent $PSScriptRoot), 'lib', 'Cli.ps1'))
try { $r = Invoke-LiteCli -Verb $Verb -Name $Name -User $User -Field $Field -Type $Type -Tag $Tag -NoPrompt:$NoPrompt }
catch { $r = New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'error'; message = $_.Exception.Message }) -Text $_.Exception.Message }
if ($Json) { $r.Data | ConvertTo-Json -Depth 6 -Compress }
elseif ($r.Text) { if ($r.Code -eq 0) { $r.Text } else { [Console]::Error.WriteLine($r.Text) } }
exit $r.Code
