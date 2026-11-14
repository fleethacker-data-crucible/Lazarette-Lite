#requires -Version 5.1
# Lazarette loopback transport, adapted for the Lite credential provider.

$script:ArcHttp = @{
    Port = 0; Listener = $null; Stream = $null; Client = $null
    Nonce = $null; NonceExpires = [datetime]::MinValue
    SessionToken = $null
    StopRequested = $false
    UiRoot = ''; Manifest = @()
    Csp = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; frame-src blob:; worker-src 'self' blob:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    PeerCheck = 'unknown'   # unknown | enabled | disabled
    # Browser presence. Tabs: tab id -> @{ Seen; Leaving; Hidden }. BusyEnd: when the last slow
    # request finished (the server is sequential, so heartbeats queued behind it are not silence).
    Presence = @{ AutoStop = $false; TimeoutSec = 20; HiddenTimeoutSec = 120; GraceSec = 5; Tabs = @{}; BusyEnd = [datetime]::MinValue; EverSeen = $false }
}

function Get-ArcHttpState { return $script:ArcHttp }   # diagnostics and tests (same hashtable)

function ConvertTo-ArcBase64Url { param([byte[]]$Bytes) return ([Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')) }

function New-LiteSessionToken {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes); return (ConvertTo-ArcBase64Url $bytes) }
    finally { $rng.Dispose() }
}

function New-ArcLaunchNonce {
    $script:ArcHttp.Nonce = New-LiteSessionToken
    $script:ArcHttp.NonceExpires = (Get-Date).AddSeconds(120)
    return $script:ArcHttp.Nonce
}

function Get-ArcLaunchUrl { return ("http://127.0.0.1:{0}/#k={1}" -f $script:ArcHttp.Port, $script:ArcHttp.Nonce) }

function Test-ArcStringsEqual {
    param([string]$A, [string]$B)
    if ($null -eq $A -or $null -eq $B) { return $false }
    return [string]::Equals($A, $B, [StringComparison]::Ordinal)
}

function Exchange-ArcNonce {
    # One shot: a correct nonce mints the session token and burns the nonce.
    param([string]$Nonce)
    if ([string]::IsNullOrEmpty($script:ArcHttp.Nonce)) { return $null }
    if ((Get-Date) -gt $script:ArcHttp.NonceExpires) { $script:ArcHttp.Nonce = $null; return $null }
    if (-not (Test-ArcStringsEqual $Nonce $script:ArcHttp.Nonce)) { return $null }
    $script:ArcHttp.Nonce = $null
    $script:ArcHttp.SessionToken = New-LiteSessionToken
    return $script:ArcHttp.SessionToken
}

function Test-ArcSessionCookie {
    param($Req)
    $tok = $Req.Cookies["lazarette_lite_$($script:ArcHttp.Port)"]
    if ([string]::IsNullOrEmpty($tok) -or [string]::IsNullOrEmpty($script:ArcHttp.SessionToken)) { return $false }
    return (Test-ArcStringsEqual $tok $script:ArcHttp.SessionToken)
}

# ---------------------------------------------------------------------------
# Presence: the tab owns the server
# ---------------------------------------------------------------------------
function Initialize-ArcPresence {
    param([bool]$AutoStop = $true, [int]$TimeoutSec = 20, [int]$GraceSec = 5, [int]$HiddenTimeoutSec = 120)
    $script:ArcHttp.Presence = @{ AutoStop = $AutoStop; TimeoutSec = $TimeoutSec; HiddenTimeoutSec = $HiddenTimeoutSec; GraceSec = $GraceSec; Tabs = @{}; BusyEnd = [datetime]::MinValue; EverSeen = $false }
}

function Register-ArcPresence {
    # A heartbeat (Leaving = $false) or the leaving beacon of one tab. Hidden: the tab is in the
    # background, where browsers may slow its timers, so it gets HiddenTimeoutSec instead.
    param([string]$Tab = 'default', [bool]$Leaving = $false, [bool]$Hidden = $false, [datetime]$Now = (Get-Date))
    $p = $script:ArcHttp.Presence
    if (-not $p.Tabs.ContainsKey($Tab)) {
        # Forget tabs that are long gone so the table stays small (one entry per page load).
        foreach ($k in @($p.Tabs.Keys)) { if (($Now - $p.Tabs[$k].Seen).TotalSeconds -gt 600) { $p.Tabs.Remove($k) } }
        if ($p.Tabs.Count -ge 64) { return }
        $p.Tabs[$Tab] = @{ Seen = $Now; Leaving = $null; Hidden = $false }
    }
    $t = $p.Tabs[$Tab]
    if ($Leaving) { $t.Leaving = $Now }
    else { $t.Seen = $Now; $t.Leaving = $null; $t.Hidden = $Hidden; $p.EverSeen = $true }
}

function Register-ArcBusyEnd {
    # Called after a slow connection (unlock, update install, assistant stream, or an idle browser
    # preconnect that held the loop for 2 s): heartbeats waited in the listen queue meanwhile,
    # so the silence before now does not count.
    param([datetime]$Now = (Get-Date))
    $script:ArcHttp.Presence.BusyEnd = $Now
}

function Test-ArcBrowserGone {
    <#
      True when the server should stop itself: auto-stop is on and every tab that ever sent a
      heartbeat has either sent its leaving signal GraceSec ago (a reload sends a fresh heartbeat
      from the new page well inside that) or been silent for TimeoutSec. Silence is counted from
      the end of the last slow connection, so a long request never makes a live tab look gone.
      A server whose launch link expired before any session was opened can never be reached
      again, so it stops too. The loop calls this only between requests: nothing is ever
      written when it fires.
    #>
    param([datetime]$Now = (Get-Date))
    $p = $script:ArcHttp.Presence
    if (-not $p.AutoStop) { return $false }
    if (-not $p.EverSeen) {
        # No tab ever reported in. Before a session exists the launch link is the only way in, so
        # Stop after the bootstrap window if no browser ever sent a heartbeat.
        return ($Now -gt $script:ArcHttp.NonceExpires)
    }
    foreach ($t in $p.Tabs.Values) {
        $since = $t.Seen; if ($p.BusyEnd -gt $since) { $since = $p.BusyEnd }
        if ($null -ne $t.Leaving) {
            $left = $t.Leaving; if ($p.BusyEnd -gt $left) { $left = $p.BusyEnd }
            if (($Now - $left).TotalSeconds -ge $p.GraceSec) { continue }
        }
        $limit = $p.TimeoutSec; if ($t.Hidden) { $limit = $p.HiddenTimeoutSec }
        if (($Now - $since).TotalSeconds -lt $limit) { return $false }
    }
    return $true
}

function Invoke-ArcHeartbeat {
    <#
      POST /api/heartbeat { tab, leaving, hidden }. Needs the session cookie like every route.
      navigator.sendBeacon cannot set X-ARC-Client, so on this route only a request without that
      header is accepted, and only as a leaving signal that carries the page's own loopback Origin
      (Test-ArcLoopbackHost has already rejected any other Origin). The cookie is the session token:
      it is HttpOnly, so the page never sees it and the beacon carries it by itself. Bodies are
      never logged.
    #>
    param($Req)
    if (-not (Test-ArcSessionCookie $Req)) { Send-ArcError 401 'session' 'Session ended. Relaunch Lazarette Lite.'; return }
    $j = $Req.Json
    $tab = 'default'; $leaving = $false; $hidden = $false
    if ($null -ne $j) {
        $v = $j.PSObject.Properties['tab']; if ($null -ne $v -and $null -ne $v.Value) { $tab = [string]$v.Value }
        $v = $j.PSObject.Properties['leaving']; if ($null -ne $v -and $v.Value -eq $true) { $leaving = $true }
        $v = $j.PSObject.Properties['hidden']; if ($null -ne $v -and $v.Value -eq $true) { $hidden = $true }
    }
    if ($tab -notmatch '^[A-Za-z0-9_\-]{1,64}$') { Send-ArcError 400 'tab' 'Invalid tab id'; return }
    $client = ''; if ($Req.Headers.ContainsKey('X-ARC-Client')) { $client = $Req.Headers['X-ARC-Client'] }
    if ($client -ne 'arc-ui/1') {
        if (-not $leaving -or -not $Req.Headers.ContainsKey('Origin')) { Send-ArcError 401 'session' 'Missing client header'; return }
    }
    Register-ArcPresence -Tab $tab -Leaving $leaving -Hidden $hidden
    $p = $script:ArcHttp.Presence
    Send-ArcJson 200 ([ordered]@{ ok = $true; autoStop = [bool]$p.AutoStop; timeoutSec = [int]$p.TimeoutSec })
}

# ---------------------------------------------------------------------------
# Peer ownership check (Windows): refuse sockets owned by another user's process.
# ---------------------------------------------------------------------------
function Initialize-ArcPeerCheck {
    if ($script:ArcHttp.PeerCheck -ne 'unknown') { return ($script:ArcHttp.PeerCheck -eq 'enabled') }
    if ($env:OS -ne 'Windows_NT') { $script:ArcHttp.PeerCheck = 'disabled'; return $false }
    if ('ArcPeer' -as [type]) { $script:ArcHttp.PeerCheck = 'enabled'; return $true }
    $src = @'
using System;
using System.Runtime.InteropServices;
using System.Security.Principal;
public static class ArcPeer {
    [DllImport("iphlpapi.dll", SetLastError = true)]
    static extern uint GetExtendedTcpTable(IntPtr pTcpTable, ref int dwOutBufLen, bool sort, int ipVersion, int tableClass, uint reserved);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr h, uint access, out IntPtr tok);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [StructLayout(LayoutKind.Sequential)]
    struct MIB_TCPROW_OWNER_PID { public uint state; public uint localAddr; public uint localPort; public uint remoteAddr; public uint remotePort; public uint owningPid; }
    static int Port(uint networkOrderLow16) { return (int)(((networkOrderLow16 & 0xFF) << 8) | ((networkOrderLow16 >> 8) & 0xFF)); }
    public static int GetOwningPid(int peerLocalPort, int ourPort) {
        int len = 0;
        GetExtendedTcpTable(IntPtr.Zero, ref len, false, 2, 5, 0);
        if (len <= 0) return -1;
        IntPtr buf = Marshal.AllocHGlobal(len);
        try {
            if (GetExtendedTcpTable(buf, ref len, false, 2, 5, 0) != 0) return -1;
            int n = Marshal.ReadInt32(buf);
            IntPtr row = new IntPtr(buf.ToInt64() + 4);
            int size = Marshal.SizeOf(typeof(MIB_TCPROW_OWNER_PID));
            for (int i = 0; i < n; i++) {
                MIB_TCPROW_OWNER_PID r = (MIB_TCPROW_OWNER_PID)Marshal.PtrToStructure(row, typeof(MIB_TCPROW_OWNER_PID));
                if (Port(r.localPort) == peerLocalPort && Port(r.remotePort) == ourPort) return (int)r.owningPid;
                row = new IntPtr(row.ToInt64() + size);
            }
            return -1;
        } finally { Marshal.FreeHGlobal(buf); }
    }
    public static string GetProcessUserSid(int pid) {
        IntPtr h = OpenProcess(0x1000, false, pid);
        if (h == IntPtr.Zero) return null;
        try {
            IntPtr tok;
            if (!OpenProcessToken(h, 0x0008, out tok)) return null;
            try { using (WindowsIdentity wi = new WindowsIdentity(tok)) { return wi.User.Value; } }
            finally { CloseHandle(tok); }
        } finally { CloseHandle(h); }
    }
}
'@
    try {
        Add-Type -TypeDefinition $src -ErrorAction Stop
        $script:ArcHttp.PeerCheck = 'enabled'
        return $true
    } catch {
        $script:ArcHttp.PeerCheck = 'disabled'
        return $false
    }
}

function Test-ArcPeerIsCurrentUser {
    # Only a confirmed match may connect.
    param([System.Net.Sockets.TcpClient]$Client)
    if (-not (Initialize-ArcPeerCheck)) { return $null }
    try {
        $peerPort = ([Net.IPEndPoint]$Client.Client.RemoteEndPoint).Port
        $ownerPid = [ArcPeer]::GetOwningPid($peerPort, $script:ArcHttp.Port)
        if ($ownerPid -le 0) { return $null }
        $sid = [ArcPeer]::GetProcessUserSid($ownerPid)
        if ([string]::IsNullOrEmpty($sid)) { return $null }
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        return ($sid -eq $me)
    } catch { return $null }
}

# ---------------------------------------------------------------------------
# Response
# ---------------------------------------------------------------------------
function Get-ArcHttpReason { param([int]$Status)
    switch ($Status) { 200 { 'OK' } 201 { 'Created' } 204 { 'No Content' } 400 { 'Bad Request' } 401 { 'Unauthorized' } 403 { 'Forbidden' } 404 { 'Not Found' } 405 { 'Method Not Allowed' } 408 { 'Request Timeout' } 409 { 'Conflict' } 413 { 'Payload Too Large' } 423 { 'Locked' } 429 { 'Too Many Requests' } 500 { 'Internal Server Error' } 501 { 'Not Implemented' } default { 'Error' } }
}

function Get-ArcSecurityHeaders {
    return @(
        "Cache-Control: no-store",
        "X-Content-Type-Options: nosniff",
        "X-Frame-Options: DENY",
        "Referrer-Policy: no-referrer",
        "Cross-Origin-Resource-Policy: same-origin",
        "Cross-Origin-Opener-Policy: same-origin",
        "Permissions-Policy: camera=(), microphone=(), geolocation=()",
        ("Content-Security-Policy: " + $script:ArcHttp.Csp)
    )
}

function Send-ArcHttpBytes {
    param([int]$Status, [string]$ContentType, [byte[]]$Bytes, [string[]]$ExtraHeaders = @())
    $stream = $script:ArcHttp.Stream
    if ($null -eq $stream) { return }
    $lines = @("HTTP/1.1 $Status $(Get-ArcHttpReason $Status)", "Content-Type: $ContentType", "Content-Length: $($Bytes.Length)", "Connection: close") + (Get-ArcSecurityHeaders) + $ExtraHeaders
    $head = [Text.Encoding]::ASCII.GetBytes(($lines -join "`r`n") + "`r`n`r`n")
    $stream.Write($head, 0, $head.Length)
    if ($Bytes.Length -gt 0) { $stream.Write($Bytes, 0, $Bytes.Length) }
    $stream.Flush()
    $script:ArcHttp.Responded = $true
}

function Send-ArcJson {
    param([int]$Status, $Object, [string[]]$ExtraHeaders = @())
    $json = ($Object | ConvertTo-Json -Depth 14 -Compress)
    if ($null -eq $json) { $json = '{}' }
    Send-ArcHttpBytes -Status $Status -ContentType 'application/json; charset=utf-8' -Bytes ([Text.Encoding]::UTF8.GetBytes($json)) -ExtraHeaders $ExtraHeaders
}

function Send-ArcError { param([int]$Status, [string]$Code, [string]$Message = '') Send-ArcJson -Status $Status -Object @{ error = $Code; message = $Message } }

# ---------------------------------------------------------------------------
# Request parsing
# ---------------------------------------------------------------------------
function Read-ArcHttpRequest {
    # Returns a request object or throws @{ Status; Code }-style exceptions via Send + $null.
    param([System.Net.Sockets.TcpClient]$Client)
    $sock = $Client.Client
    if (-not $sock.Poll(2000000, [Net.Sockets.SelectMode]::SelectRead)) { return $null }   # 2 s: nothing sent (preconnect)
    if ($sock.Available -eq 0) { return $null }                                             # readable with 0 bytes = closed
    $Client.ReceiveTimeout = 5000
    $stream = $Client.GetStream()
    $script:ArcHttp.Stream = $stream
    $buf = New-Object System.Collections.Generic.List[byte]
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    $headerEnd = -1
    while ($headerEnd -lt 0) {
        if ($buf.Count -gt 32768) { Send-ArcError 413 'headers' 'Request headers too large'; return $null }
        if ($deadline.ElapsedMilliseconds -gt 5000) { Send-ArcError 408 'timeout' 'Request headers too slow'; return $null }
        $b = $stream.ReadByte()
        if ($b -lt 0) { return $null }
        $buf.Add([byte]$b)
        $n = $buf.Count
        if ($n -ge 4 -and $buf[$n - 4] -eq 13 -and $buf[$n - 3] -eq 10 -and $buf[$n - 2] -eq 13 -and $buf[$n - 1] -eq 10) { $headerEnd = $n }
    }
    $headText = [Text.Encoding]::ASCII.GetString($buf.ToArray(), 0, $headerEnd - 4)
    $lines = $headText -split "`r`n"
    if ($lines.Count -lt 1 -or $lines[0] -notmatch '^([A-Z]{3,7}) (\S+) HTTP/1\.[01]$') { Send-ArcError 400 'request' 'Malformed request line'; return $null }
    $method = $Matches[1]; $target = $Matches[2]
    $headers = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $contentLength = -1; $clCount = 0
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        if ($line -notmatch '^([^:\s]+):\s*(.*)$') { Send-ArcError 400 'request' 'Malformed header'; return $null }
        $name = $Matches[1]; $value = $Matches[2].Trim()
        if ($name -eq 'Content-Length') { $clCount++; if ($value -notmatch '^\d{1,9}$') { Send-ArcError 400 'request' 'Bad Content-Length'; return $null }; $contentLength = [int]$value }
        if ($name -eq 'Transfer-Encoding') { Send-ArcError 400 'request' 'Transfer-Encoding not supported'; return $null }
        if ($headers.ContainsKey($name)) { $headers[$name] = $headers[$name] + ', ' + $value } else { $headers[$name] = $value }
    }
    if ($clCount -gt 1) { Send-ArcError 400 'request' 'Duplicate Content-Length'; return $null }
    if ($contentLength -gt 16384) { Send-ArcError 413 'body' 'Payload too large'; return $null }
    $body = New-Object byte[] 0
    if ($contentLength -gt 0) {
        $body = New-Object byte[] $contentLength
        $read = 0
        while ($read -lt $contentLength) {
            if ($deadline.ElapsedMilliseconds -gt 30000) { Send-ArcError 408 'timeout' 'Request body too slow'; return $null }
            $c = $stream.Read($body, $read, $contentLength - $read)
            if ($c -le 0) { break }
            $read += $c
        }
        if ($read -ne $contentLength) { Send-ArcError 400 'request' 'Incomplete body'; return $null }
    }
    $path = $target; $query = ''
    $qi = $target.IndexOf('?'); if ($qi -ge 0) { $path = $target.Substring(0, $qi); $query = $target.Substring($qi + 1) }
    if ($path -notmatch '^/[A-Za-z0-9._~/\-]*$' -or $path -match '\.\.') { Send-ArcError 400 'request' 'Bad path'; return $null }
    $cookies = @{}
    if ($headers.ContainsKey('Cookie')) {
        foreach ($part in ($headers['Cookie'] -split ';')) { $kv = $part.Trim(); $eq = $kv.IndexOf('='); if ($eq -gt 0) { $cookies[$kv.Substring(0, $eq)] = $kv.Substring($eq + 1) } }
    }
    return @{ Method = $method; Path = $path; Query = $query; Headers = $headers; Cookies = $cookies; BodyBytes = $body; Json = $null; Client = $Client }
}


# ---------------------------------------------------------------------------
# Gate + dispatch
# ---------------------------------------------------------------------------
function Test-ArcLoopbackHost {
    param($Req)
    $h = ''; if ($Req.Headers.ContainsKey('Host')) { $h = $Req.Headers['Host'] }
    if ($h -ne "127.0.0.1:$($script:ArcHttp.Port)") { return $false }
    if ($Req.Headers.ContainsKey('Origin')) {
        $o = $Req.Headers['Origin']
        if ($o -ne "http://127.0.0.1:$($script:ArcHttp.Port)") { return $false }
    }
    return $true
}

function Invoke-ArcHttpRequest {
    param($Req)
    $script:ArcHttp.Responded = $false
    if (-not (Test-ArcLoopbackHost $Req)) { Send-ArcError 400 'origin' 'Invalid local origin'; return }

    $isApi = $Req.Path.StartsWith('/api/')
    if (-not $isApi) {
        if ($Req.Method -ne 'GET') { Send-ArcError 405 'method' 'Method not allowed'; return }
        Send-ArcStaticFile -Path $Req.Path
        return
    }
    # JSON body (any method with a body)
    if ($Req.BodyBytes.Length -gt 0) {
        try { $Req.Json = [Text.Encoding]::UTF8.GetString($Req.BodyBytes) | ConvertFrom-Json -ErrorAction Stop }
        catch { Send-ArcError 400 'json' 'Body is not valid JSON'; return }
    }
    if ($Req.Path -eq '/api/heartbeat') {
        if ($Req.Method -ne 'POST') { Send-ArcError 405 'method' 'Method not allowed'; return }
        Invoke-ArcHeartbeat -Req $Req
        return
    }
    if ($Req.Path -eq '/api/session' -and $Req.Method -eq 'POST') {
        if ($Req.Headers['X-ARC-Client'] -ne 'arc-ui/1') { Send-ArcError 401 'session' 'Missing client header'; return }
        $nonce = ''; try { $nonce = [string]$Req.Json.nonce } catch { }
        $tok = Exchange-ArcNonce -Nonce $nonce
        if ($null -eq $tok) { Send-ArcError 401 'session' 'Launch token invalid or expired. Relaunch Lazarette Lite.'; return }
        $cookie = "Set-Cookie: lazarette_lite_$($script:ArcHttp.Port)=$tok; HttpOnly; SameSite=Strict; Path=/"
        Send-ArcJson -Status 200 -Object @{ ok = $true } -ExtraHeaders @($cookie)
        return
    }
    if ($Req.Path -eq '/api/health' -and $Req.Method -eq 'GET') {
        # No auth, like Lazarette's GET /api/health (docs/API.md): the UI boot
        # probe (ui-src getHealth, no client header, no cookie) and Fairlead
        # discovery call it before any session exists. The loopback-Host check
        # above still applies, so this stays loopback-only.
        Invoke-ArcRoute -Req $Req
        return
    }
    # Everything else: cookie + client header
    $client = ''; if ($Req.Headers.ContainsKey('X-ARC-Client')) { $client = $Req.Headers['X-ARC-Client'] }
    if ($client -ne 'arc-ui/1') { Send-ArcError 401 'session' 'Missing client header'; return }
    if (-not (Test-ArcSessionCookie $Req)) { Send-ArcError 401 'session' 'Session ended. Relaunch Lazarette Lite.'; return }
    Invoke-ArcRoute -Req $Req
}

function Send-ArcStaticFile {
    param([string]$Path)
    $name = if ($Path -eq '/') { 'index.html' } else { $Path.TrimStart('/') }
    if ($name -notin $script:ArcHttp.Manifest) { Send-ArcError 404 'not-found' 'Not found'; return }
    $file = Join-Path $script:ArcHttp.UiRoot $name
    if (-not (Test-Path -LiteralPath $file)) { Send-ArcError 404 'not-found' 'Not found'; return }
    $mime = switch ([IO.Path]::GetExtension($name).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' } '.js' { 'application/javascript; charset=utf-8' } '.mjs' { 'application/javascript; charset=utf-8' } '.bcmap' { 'application/octet-stream' } '.pfb' { 'application/octet-stream' } '.ttf' { 'font/ttf' } '.css' { 'text/css; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' } '.png' { 'image/png' } '.webp' { 'image/webp' } '.svg' { 'image/svg+xml' }
        '.wasm' { 'application/wasm' } '.ico' { 'image/x-icon' } '.woff2' { 'font/woff2' } '.woff' { 'font/woff' } '.map' { 'application/json' } default { 'application/octet-stream' }
    }
    Send-ArcHttpBytes -Status 200 -ContentType $mime -Bytes ([IO.File]::ReadAllBytes($file))
}

function Initialize-ArcUiManifest {
    param([string]$UiRoot)
    $script:ArcHttp.UiRoot = $UiRoot
    $m = Join-Path $UiRoot 'manifest.json'
    if (Test-Path -LiteralPath $m) {
        $list = @((Get-Content -LiteralPath $m -Raw | ConvertFrom-Json) | ForEach-Object { [string]$_ })
        $script:ArcHttp.Manifest = @($list | Where-Object { $_ -match '^[A-Za-z0-9._\-]+(/[A-Za-z0-9._\-]+)*$' -and $_ -notmatch '\.\.' })
    } else {
        $script:ArcHttp.Manifest = @('index.html')
    }
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
function Start-ArcHttpServer {
    param(
        [int]$PreferredPort = 8765,
        [Parameter(Mandatory)][string]$UiRoot,
        [scriptblock]$OnReady = $null,
        [Threading.WaitHandle]$StopSignal,
        # The launcher enables auto-stop unless -Stay was supplied.
        [bool]$AutoStop = $false,
        [int]$HeartbeatTimeoutSec = 20,
        [int]$LeavingGraceSec = 5,
        [int]$HiddenTimeoutSec = 120
    )
    if (-not (Initialize-ArcPeerCheck)) { throw 'Lazarette Lite could not enable Windows process ownership checks.' }
    Initialize-ArcUiManifest -UiRoot $UiRoot
    $address = [Net.IPAddress]::Parse('127.0.0.1')
    $listener = $null
    foreach ($candidate in @($PreferredPort, 0)) {
        try {
            $l = [Net.Sockets.TcpListener]::new($address, [int]$candidate)
            $l.ExclusiveAddressUse = $true
            $l.Start()
            $listener = $l
            break
        } catch {
            if ($candidate -eq 0) { throw "Lazarette Lite could not bind any loopback port: $($_.Exception.Message)" }
        }
    }
    $script:ArcHttp.Listener = $listener
    $script:ArcHttp.Port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $script:ArcHttp.StopRequested = $false
    $script:ArcHttp.SessionToken = $null
    Initialize-ArcPresence -AutoStop $AutoStop -TimeoutSec $HeartbeatTimeoutSec -GraceSec $LeavingGraceSec -HiddenTimeoutSec $HiddenTimeoutSec
    New-ArcLaunchNonce | Out-Null
    $presenceClock = [Diagnostics.Stopwatch]::StartNew()
    try {
        if ($OnReady) { & $OnReady (Get-ArcLaunchUrl) }
        while (-not $script:ArcHttp.StopRequested -and -not ($StopSignal -and $StopSignal.WaitOne(0))) {
            if (-not $listener.Pending()) {
                Start-Sleep -Milliseconds 50
                # Presence: checked between requests only, so a stop never interrupts a write.
                if ($presenceClock.ElapsedMilliseconds -ge 1000) {
                    $presenceClock.Restart()
                    if (Test-ArcBrowserGone) {
                        $script:ArcHttp.StopRequested = $true
                    }
                }
                continue
            }
            $client = $null
            $took = [Diagnostics.Stopwatch]::StartNew()
            try {
                $client = $listener.AcceptTcpClient()
                $script:ArcHttp.Client = $client
                $script:ArcHttp.Stream = $null
                $client.NoDelay = $true
                $peer = Test-ArcPeerIsCurrentUser -Client $client
                if ($peer -ne $true) {
                    $script:ArcHttp.Stream = $client.GetStream()
                    Send-ArcError 403 'peer' 'Connection refused'
                    continue
                }
                $req = Read-ArcHttpRequest -Client $client
                if ($null -eq $req) { continue }
                try { Invoke-ArcHttpRequest -Req $req }
                catch {
                    if (-not $script:ArcHttp.Responded) { try { Send-ArcError 500 'internal' 'Internal server error' } catch { } }
                }
            } catch {
            } finally {
                if ($client) { try { $client.Close() } catch { } }
                $script:ArcHttp.Client = $null; $script:ArcHttp.Stream = $null
                if ($took.ElapsedMilliseconds -ge 500) { Register-ArcBusyEnd }
            }
        }
    } finally {
        try { $listener.Stop() } catch { }
    }
}

function Stop-ArcHttpServer { $script:ArcHttp.StopRequested = $true }
