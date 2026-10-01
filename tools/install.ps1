<#
  NeonScript installer

  Copies the pack into <mIRC settings folder>\scripts\neonscript and adds it to mIRC's autoload list
  (mirc.ini, [rfiles]) so it starts with mIRC.  mIRC must be closed.

    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -MircDir "C:\Users\me\AppData\Roaming\mIRC"

  "mIRC settings folder" = the folder that contains mirc.ini (the program folder for a portable
  install, %APPDATA%\mIRC for a normal one).  mirc.ini is backed up first as mirc.ini.before-neonscript.
  Nothing is downloaded and nothing outside that folder is touched.
#>
param([string]$MircDir = "")

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $here "neonscript"
if (-not (Test-Path (Join-Path $source "neon.mrc"))) { throw "neonscript\neon.mrc not found next to install.ps1 - run this from the unzipped release." }

if (-not $MircDir) {
  $guess = Join-Path $env:APPDATA "mIRC"
  $answer = Read-Host "Folder that contains mirc.ini [$guess]"
  $MircDir = if ($answer) { $answer } else { $guess }
}
$MircDir = $MircDir.Trim('"').TrimEnd('\')
$ini = Join-Path $MircDir "mirc.ini"
if (-not (Test-Path $ini)) { throw "mirc.ini not found in $MircDir - start mIRC once so it creates its settings, or give the right folder." }

if (Get-Process -Name mirc -ErrorAction SilentlyContinue) { throw "mIRC is running. Close it first so it does not overwrite mirc.ini on exit." }

$target = Join-Path $MircDir "scripts\neonscript"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Write-Host "Copying NeonScript to $target ..."
Copy-Item -Path (Join-Path $source "*") -Destination $target -Recurse -Force

# keep a copy of mirc.ini the first time only
$backup = Join-Path $MircDir "mirc.ini.before-neonscript"
if (-not (Test-Path $backup)) { Copy-Item $ini $backup }

# add  n<k>=scripts\neonscript\neon.mrc  to [rfiles], preserving the file's encoding and line endings
$enc = [System.Text.Encoding]::GetEncoding(1252)
$raw = $enc.GetString([System.IO.File]::ReadAllBytes($ini))
$nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$entry = "scripts\neonscript\neon.mrc"
if ($raw -match [regex]::Escape($entry)) {
  Write-Host "NeonScript is already in mIRC's autoload list."
} else {
  $lines = [System.Collections.Generic.List[string]]($raw -split "`r?`n")
  $start = $lines.IndexOf("[rfiles]")
  if ($start -lt 0) {
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") { $lines.RemoveAt($lines.Count - 1) }
    $lines.Add(""); $lines.Add("[rfiles]"); $lines.Add("n0=$entry"); $lines.Add("")
  } else {
    $last = $start; $max = -1
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\[') { break }
      if ($lines[$i] -match '^n(\d+)=') { $last = $i; if ([int]$Matches[1] -gt $max) { $max = [int]$Matches[1] } }
    }
    $lines.Insert($last + 1, "n$($max + 1)=$entry")
  }
  [System.IO.File]::WriteAllBytes($ini, $enc.GetBytes(($lines -join $nl)))
  Write-Host "Added NeonScript to mIRC's autoload list."
}

Write-Host ""
Write-Host "Done. Start mIRC - the splash and the setup wizard appear on first run."
Write-Host "Type /neon for the Control Panel and /neonhelp for every command. /neon selftest checks the install."
