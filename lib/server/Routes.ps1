#requires -Version 5.1

function Invoke-ArcRoute {
    param($Req)
    switch ("$($Req.Method) $($Req.Path)") {
        'GET /api/credentials' {
            Send-ArcJson 200 @{ items = @(Get-LiteCredential) }
            return
        }
        'POST /api/session/quit' {
            Send-ArcJson 200 @{ ok = $true }
            Stop-ArcHttpServer
            return
        }
        'POST /api/session/ping' {
            Send-ArcJson 200 @{ ok = $true }
            return
        }
    }

    if ($Req.Method -ne 'POST' -or $Req.Path -notin @('/api/credentials/add', '/api/credentials/edit', '/api/credentials/delete', '/api/credentials/reveal')) {
        Send-ArcError 404 'not-found' 'Not found'
        return
    }
    $body = $Req.Json
    if ($body -isnot [pscustomobject] -or $body.service -isnot [string] -or [string]::IsNullOrWhiteSpace($body.service)) {
        Send-ArcError 400 'credential' 'Enter a service name.'
        return
    }
    if ($Req.Path -ne '/api/credentials/add' -and ($body.user -isnot [string] -or [string]::IsNullOrWhiteSpace($body.user))) {
        Send-ArcError 400 'credential' 'A user name is required.'
        return
    }

    $identity = @{ Service = $body.service; User = [string]$body.user }
    $secret = $null
    try {
        if ($body.secret -is [string] -and $body.secret.Length -gt 0) {
            $secret = ConvertTo-SecureString -String $body.secret -AsPlainText -Force
        }
        switch ($Req.Path) {
            '/api/credentials/add' {
                if (-not $secret) { throw 'Enter a secret.' }
                $item = Add-LiteCredential @identity -Comment ([string]$body.comment) -Secret $secret
                Send-ArcJson 201 @{ item = $item }
            }
            '/api/credentials/edit' {
                if ($body.newService -isnot [string] -or [string]::IsNullOrWhiteSpace($body.newService)) { throw 'Enter a service name.' }
                $changes = @{ NewService = $body.newService; NewUser = [string]$body.newUser; Comment = [string]$body.comment }
                if ($secret) { $changes.Secret = $secret }
                $item = Set-LiteCredential @identity @changes
                Send-ArcJson 200 @{ item = $item }
            }
            '/api/credentials/delete' {
                Remove-LiteCredential @identity -Confirm:$false
                Send-ArcJson 200 @{ ok = $true }
            }
            '/api/credentials/reveal' {
                Send-ArcJson 200 @{ secret = (Get-LiteSecret @identity) }
            }
        }
    } catch {
        Send-ArcError 400 'credential' $_.Exception.Message
    } finally {
        if ($secret) { $secret.Dispose() }
    }
}
