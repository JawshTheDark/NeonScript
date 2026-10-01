; ============================================================================
;  NeonScript 2026  ::  media controls
;  Previous / play-pause / next buttons for the toolbar that control whatever Windows is playing
;  (Spotify, a browser tab, foobar2000, VLC ...) through the System Media Transport Controls - the
;  same thing the keyboard media keys use.  Plus /np to say what you are listening to.
;
;  mIRC cannot talk to Windows' media framework by itself, so a small PowerShell helper
;  (data\media.ps1 - plain text, read it) runs hidden in the background.  They talk through three
;  tiny files in data\tmp:   media.state (what is playing)   media.cmd (a command for the helper)
;  media.beat (mIRC touches it every 3 seconds; the helper quits when mIRC does).
;  Control Panel > Sounds & notifications > "Watch Windows media" switches it all off.
; ============================================================================

alias ns.md.dir return $ns.data(tmp\)
alias ns.md.f return $+($ns.md.dir,media.,$1)
alias ns.md.script return $ns.data(media.ps1)
alias ns.md.on return $ns.flag(media,watch,1)
; is the helper running?  It rewrites media.alive every 2 seconds.
alias ns.md.alive {
  var %f = $ns.md.f(alive)
  if (!$exists(%f)) return 0
  return $iif($calc($ctime - $file(%f).mtime) < 12,1,0)
}
alias ns.md.ps return $+($envvar(SystemRoot),\System32\WindowsPowerShell\v1.0\powershell.exe)
alias ns.md.beat write -c $qt($ns.md.f(beat)) $ctime

; ---------------------------------------------------------------- helper process
alias ns.md.start {
  if (!$ns.md.on) return
  if ($ns.md.alive) return
  if (!$exists($ns.md.script)) {
    ns.err the media helper is missing ( $+ data\media.ps1) - run /neon repair
    return
  }
  .mkdir $qt($ns.md.dir)
  ; a command left behind by an earlier run must never be replayed
  if ($exists($ns.md.f(cmd))) .remove $qt($ns.md.f(cmd))
  ns.md.beat
  var %ps = $ns.md.ps
  if (!$exists(%ps)) %ps = powershell.exe
  set -u40 %ns.md.launched $ctime
  ns.dbg media helper starting
  run -h $qt(%ps) -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File $qt($ns.md.script) -Dir $qt($left($ns.md.dir,-1))
}
alias ns.md.quit {
  if ($ns.md.alive) write -c $qt($ns.md.f(cmd)) quit
}
; start or stop to match the setting
alias ns.md.apply {
  if ($ns.md.on) ns.md.start
  else {
    ns.md.quit
    hdel -w ns.mdst *
    ns.tb.resync
  }
}

; ---------------------------------------------------------------- state
; $ns.md.get(field)  fields: status (playing/paused/stopped/none) app title artist album prev next pp
alias ns.md.get {
  var %v = $hget(ns.mdst,$1)
  return $iif(%v != $null,%v,$iif($1 == status,none))
}
alias ns.md.status return $ns.md.get(status)
alias ns.md.track {
  var %t = $ns.md.get(title), %a = $ns.md.get(artist)
  if (%t == $null) return $null
  if (%a == $null) return %t
  return %a - %t
}
alias ns.md.line {
  var %s = $ns.md.status, %t = $ns.md.track, %app = $ns.md.get(app)
  if (!$ns.md.on) return Windows media is switched off
  if (!$ns.md.alive) return Starting the media helper...
  if (%s == none) || (%t == $null) return Nothing is playing
  return $iif(%s == playing,Playing,$iif(%s == paused,Paused,Stopped)) $+ : %t $iif(%app,$+($chr(40),%app,$chr(41)))
}
; a short string that changes whenever the buttons would look different
alias ns.md.sig return $iif($ns.md.on,$ns.md.status $ns.md.track,off)

alias ns.md.load {
  var %f = $ns.md.f(state)
  if (!$exists(%f)) return
  var %sz = $file(%f).size
  if (!%sz) || (%sz > 6000) return
  bread $qt(%f) 0 %sz &ns.mdb
  var %t = $bvar(&ns.mdb,1,%sz).text, %i = 1, %line, %p, %k, %v
  if ($hget(ns.mdst)) hfree ns.mdst
  hmake ns.mdst 10
  while ($gettok(%t,%i,10) != $null) {
    %line = $remove($v1,$chr(13))
    inc %i
    %p = $pos(%line,=)
    if (!%p) continue
    %k = $left(%line,$calc(%p - 1))
    %v = $remove($strip($mid(%line,$calc(%p + 1))),$chr(34))
    if (%v != $null) hadd ns.mdst %k %v
  }
}
; every 3 seconds: heartbeat, restart a dead helper, pick up a changed state file
alias ns.md.tick {
  if (!$ns.md.on) return
  ns.md.beat
  if (!$ns.md.alive) {
    ; give a fresh launch time to come up; after that try again, but not forever
    if (%ns.md.launched) return
    inc %ns.md.tries
    if (%ns.md.tries > 3) {
      if (%ns.md.tries == 4) ns.err the media helper will not start - is PowerShell blocked? (Control Panel > Sounds: untick Watch Windows media to stop retrying)
      return
    }
    ns.md.start
    return
  }
  set %ns.md.tries 0
  var %m = $file($ns.md.f(state)).mtime
  if (%m != %ns.md.mtime) {
    set %ns.md.mtime %m
    ns.md.load
    ns.tb.sync
  }
}

; ---------------------------------------------------------------- commands
; ns.md.send toggle|play|pause|next|prev|stop|refresh
alias ns.md.send {
  if (!$ns.md.on) {
    ns.err the media buttons are switched off - tick "Watch Windows media" in Control Panel > Sounds & notifications.
    return
  }
  ns.md.start
  write -c $qt($ns.md.f(cmd)) $1
  ; look at the result quickly instead of waiting for the next 3-second tick
  .timer.nsmdq 5 1 ns.md.tick
}

; /neon media [on|off|play|pause|next|prev|stop|status|restart]
alias neon.media {
  var %c = $lower($1)
  if (%c == $null) || (%c == status) {
    if (!$ns.md.on) { ns.say media control is off - /neon media on | return }
    ns.say media: $ns.md.line $+ $iif($ns.md.alive,$null,$chr(32) $+ - helper not running)
    return
  }
  if (%c == on) { ns.set media watch 1 | ns.md.apply | ns.say media control on. | return }
  if (%c == off) { ns.set media watch 0 | ns.md.apply | ns.say media control off. | return }
  if (%c == restart) {
    ns.md.quit
    unset %ns.md.tries
    .timer.nsmdr -o 1 3 ns.md.start
    ns.say restarting the media helper...
    return
  }
  if (%c == play) || (%c == pause) || (%c == next) || (%c == prev) || (%c == stop) {
    ns.md.send %c
    return
  }
  if (%c == toggle) || (%c == playpause) { ns.md.send toggle | return }
  if (%c == previous) { ns.md.send prev | return }
  ns.err usage: /neon media on, off, play, pause, next, prev, stop, status or restart
}

; /np [text]  -  say what I am listening to in the current channel or query
alias np neon.np $1-
alias neon.np {
  if (!$ns.md.on) { ns.err media control is off - /neon media on | return }
  if ($window($active).type !isin channel query) {
    ns.err open a channel or private message first, then type /np
    return
  }
  if (!$ns.md.alive) {
    ns.md.start
    ns.say starting the media helper - try /np again in a few seconds.
    return
  }
  var %s = $ns.md.status
  if (%s == none) || ($ns.md.track == $null) {
    ns.say nothing is playing right now.
    return
  }
  var %t = $remove($ns.md.get(title),$chr(1),$chr(13),$chr(10)), %a = $remove($ns.md.get(artist),$chr(1),$chr(13),$chr(10))
  var %al = $remove($ns.md.get(album),$chr(1),$chr(13),$chr(10)), %app = $ns.md.get(app)
  var %fmt = $ns.get(media,format,is listening to <artist> - <title>)
  if (%a == $null) %fmt = $replace(%fmt,<artist> - ,,<artist> -,,<artist>,)
  describe $active $replace(%fmt,<artist>,%a,<title>,%t,<album>,%al,<app>,%app)
}

; ---------------------------------------------------------------- toolbar right-click menus
; (the three buttons share one set of items)
; text that came from outside (a track title) must never be able to look like menu syntax or a command:
; no colons, $, %, |, &, ;, braces, quotes or backslashes
alias ns.md.safe return $replace($remove($1-,$chr(36),$chr(37),$chr(124),$chr(38),$chr(59),$chr(123),$chr(125),$chr(34),$chr(92)),$chr(58),$chr(45))
alias ns.md.mitem {
  var %n = $1, %on = $ns.md.on, %st = $ns.md.status
  if (%n == 1) return $+($ns.md.safe($ns.md.line),:ns.md.send refresh)
  if (%n == 2) return -
  if (%n == 3) return $+($iif(%st == playing,Pause,Play),:ns.md.send toggle)
  if (%n == 4) return Previous track:ns.md.send prev
  if (%n == 5) return Next track:ns.md.send next
  if (%n == 6) return Stop:ns.md.send stop
  if (%n == 7) return -
  if (%n == 8) return Say what I'm listening to (/np):np
  if (%n == 9) return Copy the track name:clipboard $!ns.md.track
  if (%n == 10) return -
  if (%n == 11) return $+($iif(%on,Switch media control off,Switch media control on),:neon media,$chr(32),$iif(%on,off,on))
  if (%n == 12) return Restart the media helper:neon media restart
  return $null
}
menu @nstb_mprev {
  $submenu($ns.md.mitem($1))
}
menu @nstb_mplay {
  $submenu($ns.md.mitem($1))
}
menu @nstb_mnext {
  $submenu($ns.md.mitem($1))
}

; ---------------------------------------------------------------- lifecycle
on *:SIGNAL:ns.boot:{
  unset %ns.md.launched %ns.md.tries %ns.md.mtime
  if ($ns.md.on) .timer.nsmdb -o 1 3 ns.md.start
  .timer.nsmd 0 3 ns.md.tick
}
on *:SIGNAL:ns.exit:{ ns.md.quit }
on *:SIGNAL:ns.uninstall:{ ns.md.quit }
on *:SIGNAL:ns.opts:{ .timer.nsmda -o 1 1 ns.md.apply }
