<#
  NeonScript 2026 - Windows helper

  A small background helper for the things mIRC cannot do by itself: real Windows notifications (toasts),
  reading text aloud with the Windows voices, dictation (speech to text) and uploading a file to a host you choose.

    powershell -NoProfile -ExecutionPolicy Bypass -File win.ps1 -Dir <folder> [-Register 1] [-Icon <file>]

  It talks to mIRC through small files in <folder>:
    winq\*.cmd     commands from mIRC, one file each, processed in order (key=value lines, UTF-8)
    winout\*.evt   things that happened (a toast was clicked, an upload finished) for mIRC to pick up
    win.beat       mIRC touches this every few seconds; when it stops, mIRC has closed and this exits
    win.alive      this touches it every 2 seconds so mIRC knows the helper is running

  Nothing here talks to the internet except an upload you asked for, to the address you gave. The source is plain
  text - read it, change it. MIT licence, same as the rest of NeonScript.
#>
param(
    [Parameter(Mandatory = $true)][string]$Dir,
    [string]$Aumid = 'NeonScript.mIRC',
    [string]$Icon = '',
    [int]$Register = 0,
    [switch]$DryRun
)
$ErrorActionPreference = 'SilentlyContinue'
$fake = [bool]$env:NS_WIN_FAKE          # test mode: no Windows calls, everything is written to win.log instead

$qDir   = Join-Path $Dir 'winq'
$oDir   = Join-Path $Dir 'winout'
$beatF  = Join-Path $Dir 'win.beat'
$aliveF = Join-Path $Dir 'win.alive'
$logF   = Join-Path $Dir 'win.log'
New-Item -ItemType Directory -Force -Path $qDir, $oDir | Out-Null

$mutexName = 'Local\NeonScriptWin_' + (($Dir.ToLower() -replace '[^a-z0-9]', ''))
$created = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$created)
if (-not $created) { exit 0 }

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Atomic([string]$path, [string]$text) {
    $tmp = $path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $text, $utf8)
    Move-Item -LiteralPath $tmp -Destination $path -Force
}
function Log([string]$s) { if ($fake) { Add-Content -LiteralPath $logF -Value $s -Encoding UTF8 } }
function Emit([hashtable]$kv) {
    $o = ''
    foreach ($k in $kv.Keys) { $o += "$k=" + (([string]$kv[$k]) -replace '[\r\n]+', ' ') + "`n" }
    Write-Atomic (Join-Path $oDir (([DateTime]::UtcNow.Ticks).ToString() + '-' + (Get-Random -Maximum 9999) + '.evt')) $o
}
function Read-Cmd([string]$path) {
    $h = @{}
    foreach ($line in [System.IO.File]::ReadAllText($path, $utf8) -split "`n") {
        $line = $line.TrimEnd("`r")
        $p = $line.IndexOf('=')
        if ($p -gt 0) { $h[$line.Substring(0, $p).Trim().ToLower()] = $line.Substring($p + 1) }
    }
    return $h
}

# ---------------------------------------------------------------- toasts
$toasts = @{}
$winrt = $false
if (-not $fake) {
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $winrt = $true
    } catch { }
}
function Register-AppName {
    # gives the notifications a proper name and icon instead of "Windows PowerShell" (HKCU only, removable)
    $k = "HKCU:\Software\Classes\AppUserModelId\$Aumid"
    New-Item -Path $k -Force | Out-Null
    Set-ItemProperty -Path $k -Name DisplayName -Value 'NeonScript'
    Set-ItemProperty -Path $k -Name ShowInSettings -Value 1 -Type DWord
    if ($Icon -and (Test-Path -LiteralPath $Icon)) { Set-ItemProperty -Path $k -Name IconUri -Value $Icon }
}
function Unregister-AppName { Remove-Item -Path "HKCU:\Software\Classes\AppUserModelId\$Aumid" -Recurse -Force }
function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

function Show-Toast($c) {
    $id = if ($c.id) { $c.id } else { [string](Get-Random -Maximum 999999) }
    if ($fake) {
        Log ("toast|" + $c.title + "|" + $c.body + "|" + $c.key)
        $script:toasts[$id] = @{ key = $c.key; at = Get-Date }
        return
    }
    if (-not $script:winrt) { Emit @{ type = 'error'; what = 'toast'; msg = 'Windows notifications are not available' }; return }
    try {
        $x = '<toast launch="' + (Esc $c.key) + '"><visual><binding template="ToastGeneric"><text>' + (Esc $c.title) +
             '</text><text>' + (Esc $c.body) + '</text></binding></visual><audio silent="true"/></toast>'
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($x)
        $t = New-Object Windows.UI.Notifications.ToastNotification $xml
        $t.Tag = $id
        $t.Group = 'neonscript'
        Register-ObjectEvent -InputObject $t -EventName Activated -SourceIdentifier ('act_' + $id) | Out-Null
        $script:toasts[$id] = @{ key = $c.key; at = Get-Date; t = $t }
        if ($DryRun) { Emit @{ type = 'dryrun'; what = 'toast'; msg = 'built ok' }; return }
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($Aumid).Show($t)
    } catch {
        Emit @{ type = 'error'; what = 'toast'; msg = $_.Exception.Message }
    }
}
# toasts the user clicked: Activated events arrive in PowerShell's event queue
function Pump-Events {
    foreach ($e in @(Get-Event -ErrorAction SilentlyContinue)) {
        $sid = [string]$e.SourceIdentifier
        if ($sid -like 'act_*') {
            $id = $sid.Substring(4)
            $key = if ($script:toasts.ContainsKey($id)) { $script:toasts[$id].key } else { '' }
            Emit @{ type = 'click'; key = $key }
            Unregister-Event -SourceIdentifier $sid -ErrorAction SilentlyContinue
            $script:toasts.Remove($id)
        }
        elseif ($sid -eq 'stt_heard') {
            try {
                $r = $e.SourceEventArgs.Result
                if ($r -and $r.Confidence -ge 0.3 -and $r.Text) { Emit @{ type = 'heard'; text = $r.Text; conf = [Math]::Round($r.Confidence, 2) } }
            } catch { }
        }
        Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue
    }
    # forget toasts nobody clicked after ten minutes
    foreach ($id in @($script:toasts.Keys)) {
        if (((Get-Date) - $script:toasts[$id].at).TotalMinutes -gt 10) {
            Unregister-Event -SourceIdentifier ('act_' + $id) -ErrorAction SilentlyContinue
            $script:toasts.Remove($id)
        }
    }
}

# ---------------------------------------------------------------- speech
$synth = $null
function Speak($c) {
    $text = [string]$c.text
    if (-not $text) { return }
    if ($fake) { Log ("speak|" + $text + "|" + $c.voice + "|" + $c.rate); return }
    try {
        if ($null -eq $script:synth) {
            Add-Type -AssemblyName System.Speech
            $script:synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        }
        $s = $script:synth
        if ($c.voice) { try { $s.SelectVoice($c.voice) } catch { } }
        $r = 0; [void][int]::TryParse([string]$c.rate, [ref]$r); $s.Rate = [Math]::Max(-10, [Math]::Min(10, $r))
        $v = 100; if ([int]::TryParse([string]$c.volume, [ref]$v)) { $s.Volume = [Math]::Max(0, [Math]::Min(100, $v)) }
        if ($s.State -eq 'Speaking') { $s.SpeakAsyncCancelAll() }       # the newest message wins
        [void]$s.SpeakAsync($text)
    } catch { Emit @{ type = 'error'; what = 'speak'; msg = $_.Exception.Message } }
}
function List-Voices {
    if ($fake) { Emit @{ type = 'voices'; list = 'Fake Voice One|Fake Voice Two' }; return }
    try {
        Add-Type -AssemblyName System.Speech
        $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
        Emit @{ type = 'voices'; list = (($s.GetInstalledVoices() | Where-Object { $_.Enabled } | ForEach-Object { $_.VoiceInfo.Name }) -join '|') }
        $s.Dispose()
    } catch { Emit @{ type = 'error'; what = 'voices'; msg = $_.Exception.Message } }
}

# ---------------------------------------------------------------- dictation (speech to text) - only while mIRC has it switched on
# Uses the speech recogniser that ships with Windows (System.Speech, on this PC, no cloud service).  What it hears
# comes back as "heard" events; mIRC puts the text in your editbox - it is never sent for you.
$rec = $null
function Start-Listen($c) {
    if ($fake) { Log ("listen|" + $c.lang); Emit @{ type = 'listening'; state = 'on' }; return }
    try {
        Add-Type -AssemblyName System.Speech
        if ($null -eq $script:rec) {
            $ci = $null
            if ($c.lang) { try { $ci = New-Object System.Globalization.CultureInfo([string]$c.lang) } catch { } }
            $e = $null
            if ($ci) { try { $e = New-Object System.Speech.Recognition.SpeechRecognitionEngine($ci) } catch { } }
            if ($null -eq $e) {
                try { $e = New-Object System.Speech.Recognition.SpeechRecognitionEngine } catch { }
            }
            if ($null -eq $e) { Emit @{ type = 'error'; what = 'listen'; msg = 'no speech recogniser is installed (Windows Settings > Time & language > Speech)' }; return }
            $e.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
            $e.SetInputToDefaultAudioDevice()
            Register-ObjectEvent -InputObject $e -EventName SpeechRecognized -SourceIdentifier 'stt_heard' | Out-Null
            $script:rec = $e
        }
        $script:rec.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
        Emit @{ type = 'listening'; state = 'on' }
    } catch { Emit @{ type = 'error'; what = 'listen'; msg = $_.Exception.Message } }
}
function Stop-Listen {
    if (-not $fake) { try { if ($script:rec) { $script:rec.RecognizeAsyncCancel() } } catch { } }
    else { Log 'stoplisten' }
    Emit @{ type = 'listening'; state = 'off' }
}

# ---------------------------------------------------------------- uploads (only when mIRC asks, only to the address it gives)
function Upload-File($c) {
    $id = $c.id
    if ($fake) {
        Log ("upload|" + $c.file + "|" + $c.url + "|" + $c.method + "|" + $c.field)
        $leaf = 'file'
        try { $leaf = [IO.Path]::GetFileName($c.file) } catch { }
        Emit @{ type = 'upload'; id = $id; result = ('https://example.invalid/fake/' + $leaf) }
        return
    }
    try {
        if (-not (Test-Path -LiteralPath $c.file)) { throw 'file not found' }
        if ($c.url -notmatch '^https://') { throw 'only https:// addresses are used' }
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'NeonScript')
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        if ($c.method -eq 'PUT') {
            $bytes = $wc.UploadFile($c.url, 'PUT', $c.file)
        } else {
            # multipart/form-data with one file field
            $field = if ($c.field) { $c.field } else { 'file' }
            $boundary = [guid]::NewGuid().ToString('N')
            $wc.Headers.Add('Content-Type', "multipart/form-data; boundary=$boundary")
            $head = "--$boundary`r`nContent-Disposition: form-data; name=`"$field`"; filename=`"" + [IO.Path]::GetFileName($c.file) + "`"`r`nContent-Type: application/octet-stream`r`n`r`n"
            $tail = "`r`n--$boundary--`r`n"
            $ms = New-Object System.IO.MemoryStream
            $hb = [Text.Encoding]::UTF8.GetBytes($head); $ms.Write($hb, 0, $hb.Length)
            $fb = [IO.File]::ReadAllBytes($c.file); $ms.Write($fb, 0, $fb.Length)
            $tb = [Text.Encoding]::UTF8.GetBytes($tail); $ms.Write($tb, 0, $tb.Length)
            $bytes = $wc.UploadData($c.url, 'POST', $ms.ToArray())
        }
        $reply = ([Text.Encoding]::UTF8.GetString($bytes)).Trim()
        Emit @{ type = 'upload'; id = $id; result = ($reply -split "[\r\n]+")[0] }
    } catch { Emit @{ type = 'upload'; id = $id; error = $_.Exception.Message } }
}

# ---------------------------------------------------------------- clipboard picture -> PNG file (for /paste)
function Clip-Image($c) {
    if ($fake) { Emit @{ type = 'clipimage'; id = $c.id; path = $c.path }; return }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
            $img = [System.Windows.Forms.Clipboard]::GetImage()
            $img.Save($c.path, [System.Drawing.Imaging.ImageFormat]::Png)
            $img.Dispose()
            Emit @{ type = 'clipimage'; id = $c.id; path = $c.path }
        } else { Emit @{ type = 'clipimage'; id = $c.id; none = '1' } }
    } catch { Emit @{ type = 'clipimage'; id = $c.id; none = '1'; msg = $_.Exception.Message } }
}

# ---------------------------------------------------------------- main loop
if ($Register -eq 1 -and -not $fake) { Register-AppName }
$nextBeat = [DateTime]::MinValue
$started = Get-Date
$running = $true
try {
    while ($running) {
        $now = Get-Date
        if ($now -ge $nextBeat) {
            $nextBeat = $now.AddSeconds(2)
            Write-Atomic $aliveF ([string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            if (Test-Path -LiteralPath $beatF) {
                if (($now - (Get-Item -LiteralPath $beatF).LastWriteTime).TotalSeconds -gt 30) { break }
            } elseif (($now - $started).TotalSeconds -gt 30) { break }
        }
        foreach ($f in @(Get-ChildItem -LiteralPath $qDir -Filter '*.cmd' -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $c = $null
            try { $c = Read-Cmd $f.FullName } catch { }
            Remove-Item -LiteralPath $f.FullName -Force
            if ($null -eq $c) { continue }
            switch ($c.cmd) {
                'toast'      { Show-Toast $c }
                'speak'      { Speak $c }
                'stopspeak'  { if ($synth) { $synth.SpeakAsyncCancelAll() } }
                'voices'     { List-Voices }
                'upload'     { Upload-File $c }
                'clipimage'  { Clip-Image $c }
                'listen'     { Start-Listen $c }
                'stoplisten' { Stop-Listen }
                'simheard'   { if ($fake) { Emit @{ type = 'heard'; text = $c.text; conf = '0.9' } } }
                'register'   { if (-not $fake) { Register-AppName } }
                'unregister' { if (-not $fake) { Unregister-AppName } }
                'simclick'   { if ($fake) { Emit @{ type = 'click'; key = $c.key } } }
                'quit'       { $running = $false }
            }
        }
        Pump-Events
        Start-Sleep -Milliseconds 200
    }
} finally {
    Remove-Item -LiteralPath $aliveF -Force
    if ($synth) { $synth.Dispose() }
    if ($rec) { try { $rec.RecognizeAsyncCancel(); $rec.Dispose() } catch { } }
    $mutex.ReleaseMutex()
}
