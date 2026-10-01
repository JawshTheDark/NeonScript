<#
  NeonScript 2026 - media helper

  A small background helper that talks to Windows' System Media Transport Controls (the same thing the
  keyboard media keys and the Windows volume flyout use), so the toolbar buttons can control whatever is
  playing - Spotify, a browser tab, foobar2000, VLC ... - and show what it is.

    powershell -NoProfile -ExecutionPolicy Bypass -File media.ps1 -Dir <folder>

  It talks to mIRC only through three small files in <folder>:
    media.state   what is playing (status / app / title / artist / album / which buttons the player allows)
    media.cmd     a command from mIRC: toggle, play, pause, next, prev, stop, refresh, quit
    media.beat    mIRC touches this every few seconds; when it stops being touched, mIRC has closed and this exits

  Nothing is sent anywhere. It only reads the media session and sends the command you clicked. Source is
  plain text - read it, change it. MIT licence, same as the rest of NeonScript.
#>
param(
    [Parameter(Mandatory = $true)][string]$Dir
)
$ErrorActionPreference = 'SilentlyContinue'
$fake = [bool]$env:NS_MEDIA_FAKE            # test mode: no Windows calls, a pretend player and a command log

$stateF = Join-Path $Dir 'media.state'
$cmdF   = Join-Path $Dir 'media.cmd'
$beatF  = Join-Path $Dir 'media.beat'
$aliveF = Join-Path $Dir 'media.alive'
$logF   = Join-Path $Dir 'media.log'

# one helper per folder
$mutexName = 'Local\NeonScriptMedia_' + (($Dir.ToLower() -replace '[^a-z0-9]', ''))
$created = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$created)
if (-not $created) { exit 0 }

function Write-Atomic([string]$path, [string]$text) {
    $tmp = $path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $path -Force
}
function Clean([string]$s) { if ($null -eq $s) { return '' } ($s -replace '[\r\n\t]+', ' ').Trim() }

# ---------------------------------------------------------------- Windows media session access
$mgr = $null
if (-not $fake) {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
        [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
    } catch { }
}
function Await($op, $type) {
    $t = $script:asTask.MakeGenericMethod($type).Invoke($null, @($op))
    if ($t.Wait(4000)) { return $t.Result }
    return $null
}
function Get-Manager {
    if ($null -eq $script:mgr) {
        $script:mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) `
            ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    }
    return $script:mgr
}
# prefer something that is playing; otherwise whatever Windows treats as the current session
function Get-Session {
    $m = Get-Manager
    if ($null -eq $m) { return $null }
    $best = $null
    foreach ($s in $m.GetSessions()) {
        if ($s.GetPlaybackInfo().PlaybackStatus -eq 4) { return $s }     # 4 = Playing
    }
    $best = $m.GetCurrentSession()
    if ($null -eq $best) { $best = ($m.GetSessions() | Select-Object -First 1) }
    return $best
}
function Pretty-App([string]$id) {
    if (-not $id) { return '' }
    $n = ($id -split '[\\!]')[-1]
    $n = $n -replace '\.exe$', ''
    if ($n -match '^[A-Za-z0-9]+\.[A-Za-z0-9.]+_') { $n = ($n -split '\.')[1] }   # Package.Family_xxxx!App
    return $n
}

# the pretend player used by the test mode
$fk = @{ status = 'playing'; title = 'Neon Drive'; artist = 'Synthwave Test'; album = 'Mock Album'; app = 'FakePlayer' }
if ($env:NS_MEDIA_FAKE_TITLE) { $fk.title = $env:NS_MEDIA_FAKE_TITLE }

function Read-State {
    if ($fake) {
        return [ordered]@{ status = $fk.status; app = $fk.app; title = $fk.title; artist = $fk.artist; album = $fk.album
                           prev = 1; next = 1; pp = 1 }
    }
    $st = [ordered]@{ status = 'none'; app = ''; title = ''; artist = ''; album = ''; prev = 0; next = 0; pp = 0 }
    try {
        $s = Get-Session
        if ($null -eq $s) { return $st }
        $info = $s.GetPlaybackInfo()
        $st.status = switch ([int]$info.PlaybackStatus) { 4 { 'playing' } 5 { 'paused' } 3 { 'stopped' } default { 'stopped' } }
        $st.app = Pretty-App $s.SourceAppUserModelId
        $p = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        if ($p) { $st.title = Clean $p.Title; $st.artist = Clean $p.Artist; $st.album = Clean $p.AlbumTitle }
        $c = $info.Controls
        if ($c) { $st.prev = [int]$c.IsPreviousEnabled; $st.next = [int]$c.IsNextEnabled; $st.pp = [int]($c.IsPlayPauseToggleEnabled -or $c.IsPlayEnabled -or $c.IsPauseEnabled) }
    } catch { }
    return $st
}
function Format-State($st) {
    $o = "v=1`n"
    foreach ($k in $st.Keys) { $o += "$k=" + (Clean ([string]$st[$k])) + "`n" }
    return $o
}

# ---------------------------------------------------------------- commands
function Press-MediaKey([int]$vk) {
    if ($fake) { return }
    if (-not ([System.Management.Automation.PSTypeName]'NS.Keys').Type) {
        Add-Type -Namespace NS -Name Keys -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, int flags, int extra);'
    }
    [NS.Keys]::keybd_event([byte]$vk, 0, 0, 0)
    [NS.Keys]::keybd_event([byte]$vk, 0, 2, 0)
}
function Run-Command([string]$cmd) {
    if ($fake) {
        Add-Content -LiteralPath $logF -Value $cmd
        switch ($cmd) {
            'toggle' { $fk.status = if ($fk.status -eq 'playing') { 'paused' } else { 'playing' } }
            'play'   { $fk.status = 'playing' }
            'pause'  { $fk.status = 'paused' }
            'stop'   { $fk.status = 'stopped' }
            'next'   { $fk.title = 'Next Track'; $fk.status = 'playing' }
            'prev'   { $fk.title = 'Previous Track'; $fk.status = 'playing' }
        }
        return
    }
    $s = $null
    try { $s = Get-Session } catch { }
    $ok = $false
    if ($null -ne $s) {
        try {
            $r = $null
            switch ($cmd) {
                'toggle' { $r = Await ($s.TryTogglePlayPauseAsync()) ([bool]) }
                'play'   { $r = Await ($s.TryPlayAsync()) ([bool]) }
                'pause'  { $r = Await ($s.TryPauseAsync()) ([bool]) }
                'next'   { $r = Await ($s.TrySkipNextAsync()) ([bool]) }
                'prev'   { $r = Await ($s.TrySkipPreviousAsync()) ([bool]) }
                'stop'   { $r = Await ($s.TryStopAsync()) ([bool]) }
            }
            $ok = [bool]$r
        } catch { }
    }
    if (-not $ok) {
        # nothing registered a session (or the player refused): send the real media key, as the keyboard would
        switch ($cmd) {
            'toggle' { Press-MediaKey 0xB3 }
            'play'   { Press-MediaKey 0xB3 }
            'pause'  { Press-MediaKey 0xB3 }
            'next'   { Press-MediaKey 0xB0 }
            'prev'   { Press-MediaKey 0xB1 }
            'stop'   { Press-MediaKey 0xB2 }
        }
    }
}

# ---------------------------------------------------------------- main loop
$last = ''
$nextRead = [DateTime]::MinValue
$nextBeat = [DateTime]::MinValue
$started = Get-Date
try {
    while ($true) {
        $now = Get-Date
        if ($now -ge $nextBeat) {
            $nextBeat = $now.AddSeconds(2)
            Write-Atomic $aliveF ([string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            # mIRC has gone (the beat file stopped being touched)?
            if (Test-Path -LiteralPath $beatF) {
                if (($now - (Get-Item -LiteralPath $beatF).LastWriteTime).TotalSeconds -gt 30) { break }
            } elseif (($now - $started).TotalSeconds -gt 30) { break }
        }
        if (Test-Path -LiteralPath $cmdF) {
            $cmd = ''
            try { $cmd = (Get-Content -LiteralPath $cmdF -TotalCount 1).Trim().ToLower() } catch { }
            Remove-Item -LiteralPath $cmdF -Force
            if ($cmd -eq 'quit') { break }
            if ($cmd -and $cmd -ne 'refresh') {
                Run-Command $cmd
                Start-Sleep -Milliseconds 450          # let the player update before reading it back
            }
            $nextRead = [DateTime]::MinValue
        }
        if ($now -ge $nextRead) {
            $nextRead = $now.AddMilliseconds(1500)
            $text = Format-State (Read-State)
            if ($text -ne $last) {
                Write-Atomic $stateF $text
                $last = $text
            }
        }
        Start-Sleep -Milliseconds 200
    }
} finally {
    Remove-Item -LiteralPath $aliveF -Force
    $mutex.ReleaseMutex()
}
