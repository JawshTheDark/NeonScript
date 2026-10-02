; ============================================================================
;  NeonScript 2026  ::  Windows integration
;    Toast notifications   a real Windows notification for a mention or private message (click = jump there)
;    Speech                mentions and private messages read aloud with the Windows voices
;    /paste                upload a file, the clipboard text or the clipboard picture to an https:// address
;                          YOU choose (nothing is configured by default) and get the link in the editbox
;
;  mIRC cannot do any of that itself, so a small PowerShell helper (data\win.ps1 - plain text, read it)
;  runs hidden in the background and quits with mIRC.  It talks to mIRC through small files in data\tmp:
;     winq\*.cmd    commands for the helper       winout\*.evt   things that happened (a click, an upload)
;     win.beat      mIRC touches it every 2 s     win.alive      the helper touches it every 2 s
;  Switches live in Control Panel > Windows integration.  Nothing is sent anywhere except an upload you ask for.
; ============================================================================

alias ns.win.dir return $ns.data(tmp\)
alias ns.win.q return $+($ns.win.dir,winq\)
alias ns.win.o return $+($ns.win.dir,winout\)
alias ns.win.f return $+($ns.win.dir,win.,$1)
alias ns.win.script return $ns.data(win.ps1)
; any feature that needs the helper switched on?
alias ns.win.wanted return $iif($ns.flag(toast,on,0) || $ns.flag(speak,on,0) || %ns.dict.on,1,0)
alias ns.win.alive {
  var %f = $ns.win.f(alive)
  if (!$exists(%f)) return 0
  return $iif($calc($ctime - $file(%f).mtime) < 12,1,0)
}
alias ns.win.beat write -c $qt($ns.win.f(beat)) $ctime

; ---------------------------------------------------------------- helper process
alias ns.win.start {
  if ($ns.win.alive) return
  if (%ns.win.launched) return
  set -u15 %ns.win.launched 1
  if (!$exists($ns.win.script)) {
    ns.err the Windows helper is missing ( $+ data\win.ps1) - run /neon repair
    return
  }
  .mkdir $qt($ns.win.dir)
  .mkdir $qt($ns.win.q)
  .mkdir $qt($ns.win.o)
  ; commands left over from an earlier run must never be replayed
  var %n = $findfile($ns.win.q,*.cmd,0,0,.remove $qt($1-))
  ns.win.beat
  var %ps = $ns.md.ps
  if (!$exists(%ps)) %ps = powershell.exe
  ns.dbg windows helper starting
  run -h $qt(%ps) -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $qt($ns.win.script) -Dir $qt($left($ns.win.dir,-1)) -Register $iif($ns.flag(toast,on,0),1,0) -Icon $qt($ns.asset(neon.ico))
}
alias ns.win.quit {
  if ($ns.win.alive) ns.win.send quit
}
; start / stop to match the switches (the helper also quits by itself when mIRC does)
alias ns.win.apply {
  var %t = $ns.flag(toast,on,0)
  if (%t) && (%ns.win.lasttoast != 1) {
    ns.win.start
    ns.win.send register
  }
  if (!%t) && (%ns.win.lasttoast == 1) && ($ns.win.alive) ns.win.send unregister
  set %ns.win.lasttoast %t
  if ($ns.win.wanted) ns.win.start
}

; ---------------------------------------------------------------- talking to the helper
; a command is built key by key and written as one UTF-8 file:   ns.win.new  |  ns.win.set key text  |  ns.win.go command
alias ns.win.new {
  if ($hget(ns.wsend)) hfree ns.wsend
  hmake ns.wsend 5
}
alias ns.win.set hadd ns.wsend $1 $remove($2-,$cr,$lf,$chr(0))
alias ns.win.go {
  var %i = 1, %n = $hget(ns.wsend,0).item, %k, %t = $+(cmd=,$1,$lf), %tmp, %fin
  while (%i <= %n) {
    %k = $hget(ns.wsend,%i).item
    inc %i
    if (%k == cmd) continue
    %t = $+(%t,%k,=,$hget(ns.wsend,%k),$lf)
  }
  inc %ns.win.seq
  %tmp = $+($ns.win.q,$ticks,-,%ns.win.seq,.tmp)
  %fin = $+($left(%tmp,-4),.cmd)
  ; (bset -t already writes UTF-8 for Unicode text - $utfencode on top would encode twice)
  bset -t &ns.winb 1 %t
  bwrite $qt(%tmp) -1 -1 &ns.winb
  .rename $qt(%tmp) $qt(%fin)
}
; no-argument commands
alias ns.win.send {
  ns.win.new
  ns.win.go $1
}

; ---------------------------------------------------------------- what the helper reports
alias ns.win.readfile {
  var %f = $1, %sz = $file(%f).size
  if (!%sz) || (%sz > 20000) return $null
  bread $qt(%f) 0 %sz &ns.winr
  return $bvar(&ns.winr,1,%sz).text
}
alias ns.win.tick {
  if ($ns.win.wanted) || ($ns.win.alive) ns.win.beat
  if (!$exists($ns.win.o)) return
  var %n = $findfile($ns.win.o,*.evt,0,0), %i = 1, %files, %t, %f, %j, %line, %p
  if (!%n) return
  while (%i <= %n) {
    %files = %files $+ $iif(%files,$chr(124)) $+ $findfile($ns.win.o,*.evt,%i,0)
    inc %i
  }
  %i = 1
  while ($gettok(%files,%i,124) != $null) {
    %f = $gettok(%files,%i,124)
    inc %i
    %t = $ns.win.readfile(%f)
    .remove $qt(%f)
    if (%t == $null) continue
    if ($hget(ns.wevt)) hfree ns.wevt
    hmake ns.wevt 5
    %j = 1
    while ($gettok(%t,%j,10) != $null) {
      %line = $remove($v1,$cr)
      inc %j
      %p = $pos(%line,=)
      if (%p) hadd ns.wevt $left(%line,$calc(%p - 1)) $mid(%line,$calc(%p + 1))
    }
    ns.win.evt $hget(ns.wevt,type)
  }
}
alias ns.win.evt {
  var %t = $1
  if (%t == click) { ns.win.click $hget(ns.wevt,key) | return }
  if (%t == heard) { ns.dict.heard $hget(ns.wevt,text) | return }
  if (%t == listening) { ns.dict.state $hget(ns.wevt,state) | return }
  if (%t == error) { ns.err Windows helper ( $+ $hget(ns.wevt,what) $+ ): $hget(ns.wevt,msg) | return }
  if (%t == voices) { ns.say installed voices: $replace($hget(ns.wevt,list),$chr(124),$chr(44) $+ $chr(32)) | return }
  if (%t == upload) { ns.paste.done $hget(ns.wevt,id) $hget(ns.wevt,result) $+ $iif($hget(ns.wevt,error) != $null,$chr(1) $+ $hget(ns.wevt,error)) | return }
  if (%t == clipimage) { ns.paste.clip $hget(ns.wevt,id) $hget(ns.wevt,path) $hget(ns.wevt,none) | return }
  ns.dbg windows helper event %t
}
; a toast was clicked: bring mIRC forward and show that conversation
alias ns.win.click {
  .showmirc -s
  if ($1 isnum) && ($1 > 0) ns.mi.jump $1
}

; ---------------------------------------------------------------- toasts and speech for mentions and private messages
; called by the mentions inbox for every new mention / private message:
;   ns.win.notify <inbox key> <kind c|a|p|q> <window> <nick> <seen 0|1> <text...>
alias ns.win.notify {
  var %k = $1, %kind = $2, %tgt = $3, %nick = $4, %seen = $5, %txt = $left($remove($strip($6-),$chr(9)),300)
  if ($donotdisturb) return
  if (%seen) return
  ; "only while mIRC is in the background" switches: with one on, nothing happens while mIRC is the active program
  var %fg = $appactive
  if ($ns.flag(toast,on,0)) {
    if (!%fg) ns.win.toast %k %kind %tgt %nick %txt
    elseif (!$ns.flag(toast,bg,1)) ns.win.toast %k %kind %tgt %nick %txt
  }
  if ($ns.flag(speak,on,0)) {
    if (!%fg) ns.win.say %kind %tgt %nick %txt
    elseif (!$ns.flag(speak,bg,1)) ns.win.say %kind %tgt %nick %txt
  }
}
alias ns.win.toast {
  var %k = $1, %kind = $2, %tgt = $3, %nick = $4, %txt = $5-, %title, %w = $+($cid,.,$3)
  ; at most one toast per conversation every 6 seconds, and 8 a minute overall
  if ($hget(ns.wtoast,%w)) return
  hadd -mu6 ns.wtoast %w 1
  hinc -mu60 ns.wtoastn all
  if ($hget(ns.wtoastn,all) > 8) return
  %title = $iif(%kind isin cq,%nick in %tgt,%nick $+ $chr(32) $+ $chr(40) $+ private message $+ $chr(41))
  ns.win.start
  ns.win.new
  ns.win.set id $r(1000,999999)
  ns.win.set title %title
  ns.win.set body $iif($ns.flag(toast,text,1),%txt,New message)
  ns.win.set key %k
  ns.win.go toast
}
alias ns.win.say {
  var %kind = $1, %tgt = $2, %nick = $3, %txt = $regsubex($4-,/https?:\/\/\S+/gi,link)
  if ($hget(ns.wspoke,$+($cid,.,%tgt))) return
  hadd -mu4 ns.wspoke $+($cid,.,%tgt) 1
  ns.win.start
  ns.win.new
  ns.win.set text $+(%nick,$iif(%kind isin cq,$chr(32) $+ in $remove(%tgt,$chr(35))),$chr(32),says,$chr(58),$chr(32),$left(%txt,160))
  ns.win.set voice $ns.get(speak,voice)
  ns.win.set rate $ns.get(speak,rate,0)
  ns.win.go speak
}

; /neon toast [on|off|test]
alias neon.toast {
  var %c = $lower($1)
  if (%c == on) {
    ns.set toast on 1
    ns.win.apply
    ns.say Windows notifications on - mentions and private messages show as toasts while mIRC is in the background.
    return
  }
  if (%c == off) {
    ns.set toast on 0
    ns.win.apply
    ns.say Windows notifications off.
    return
  }
  if (%c == test) {
    ns.win.start
    ns.win.new
    ns.win.set id $r(1000,999999)
    ns.win.set title NeonScript
    ns.win.set body This is a test notification. Click it to bring mIRC forward.
    ns.win.set key 0
    ns.win.go toast
    ns.say test notification sent (Windows' Do not disturb / Focus assist may hide it).
    return
  }
  ns.say Windows notifications are $iif($ns.flag(toast,on,0),on,off) $+ . /neon toast on, off or test.
}
; /neon speak [on|off|test|voices|stop]
alias neon.speak {
  var %c = $lower($1)
  if (%c == on) { ns.set speak on 1 | ns.win.apply | ns.say reading mentions and private messages aloud. | return }
  if (%c == off) { ns.set speak on 0 | ns.win.apply | ns.win.send stopspeak | ns.say speech off. | return }
  if (%c == stop) { ns.win.send stopspeak | return }
  if (%c == voices) { ns.win.start | ns.win.send voices | return }
  if (%c == test) {
    ns.win.start
    ns.win.new
    ns.win.set text Nova says: this is how a mention sounds.
    ns.win.set voice $ns.get(speak,voice)
    ns.win.set rate $ns.get(speak,rate,0)
    ns.win.go speak
    return
  }
  ns.say speech is $iif($ns.flag(speak,on,0),on,off) $+ . /neon speak on, off, test, voices or stop.
}

; ============================================================================
;  Dictation (speech to text):  /dictate  or  /neon dictate [on|off|status]
;  The microphone is only listened to while it is on (it never starts by itself, not even after a restart).  Windows' own
;  speech recogniser on this PC turns it into text and NeonScript puts the text in the editbox of the window you started in -
;  you read it and press Enter; nothing is ever sent for you.
; ============================================================================
alias dictate neon.dictate $1-
alias neon.dictate {
  var %c = $lower($1)
  if (%c == status) { ns.say dictation is $iif(%ns.dict.on,ON,off) $+ . /dictate toggles it. | return }
  if (%c == off) || (%c == $null && %ns.dict.on) {
    unset %ns.dict.on
    ns.win.send stoplisten
    ns.dict.state off
    return
  }
  if (%c == on) || (%c == $null) {
    set %ns.dict.on 1
    set %ns.dict.win $active
    set %ns.dict.cid $cid
    ns.win.start
    ns.win.new
    ns.win.set lang $ns.get(dictate,lang)
    ns.win.go listen
    ns.say dictation starting - speak, then check the text in the editbox and press Enter. /dictate stops it.
    return
  }
  ns.err usage: /dictate [on|off|status]
}
alias ns.dict.state {
  ; the helper says it is (not) listening: mirror it on the taskbar button when the native helper is on
  if ($1 == on) && ($isalias(ns.ui.cmd)) && ($ns.ui.active) var %r = $ns.ui.cmd($+(progress,$chr(9),indeterminate,$chr(9),0))
  if ($1 == off) {
    unset %ns.dict.on
    if ($isalias(ns.ui.cmd)) && ($ns.ui.active) var %r = $ns.ui.cmd($+(progress,$chr(9),none,$chr(9),0))
    ns.say dictation is off.
  }
}
alias ns.dict.heard {
  var %t = $remove($strip($1-),$chr(9),$cr,$lf), %w = %ns.dict.win, %cid = %ns.dict.cid
  if (!%ns.dict.on) || (%t == $null) return
  %t = $left(%t,300)
  if (%cid) scid %cid ns.dict.put %w %t
  else ns.dict.put %w %t
}
; add the words at the cursor (with a space when needed) in the editbox of window $1
alias ns.dict.put {
  var %w = $1, %add = $2-, %t, %s, %e, %pre, %n
  if (!$window(%w)) %w = $active
  %t = $editbox(%w)
  %s = $editbox(%w).selstart
  %e = $editbox(%w).selend
  if (%s !isnum) || (%e !isnum) || (%s < 1) { %s = $calc($len(%t) + 1) | %e = %s }
  %pre = $left(%t,$calc(%s - 1))
  if (%pre != $null) && ($right(%pre,1) != $chr(32)) %add = $chr(32) $+ %add
  %n = $+(%pre,%add,$mid(%t,%e))
  var %pos = $calc($len(%pre) + $len(%add) + 1)
  editbox $+(-a,b,%pos,e,%pos) %n
}

; ============================================================================
;  /paste  -  upload to an address you configured
; ============================================================================
; /paste [file | text...]    no argument: the clipboard (text, else a picture)
alias paste neon.paste $1-
alias neon.paste {
  var %url = $ns.get(paste,url)
  if (%url == $null) {
    ns.err no upload address yet - set one in Control Panel > Windows integration (an https:// address that takes a file).
    return
  }
  if ($left(%url,8) != https://) {
    ns.err the upload address must start with https://
    return
  }
  var %f, %id = $r(1000,999999), %t = $1-
  if (%t != $null) && ($exists(%t)) %f = %t
  elseif (%t != $null) {
    %f = $+($ns.win.dir,paste_,%id,.txt)
    write -c $qt(%f) %t
  }
  elseif ($cb(0) > 0) {
    %f = $+($ns.win.dir,paste_,%id,.txt)
    var %i = 1
    write -c $qt(%f) $cb(1)
    while (%i < $cb(0)) {
      inc %i
      write $qt(%f) $cb(%i)
    }
  }
  else {
    ; maybe a picture on the clipboard - ask the helper
    ns.win.start
    ns.win.new
    ns.win.set id %id
    ns.win.set path $+($ns.win.dir,paste_,%id,.png)
    ns.win.go clipimage
    ns.say looking for a picture on the clipboard...
    return
  }
  ns.paste.go %f %id
}
alias ns.paste.clip {
  ; $1 id  $2 path  $3 none
  if ($3) || (!$exists($2)) {
    ns.err nothing to paste - the clipboard holds neither text nor a picture.
    return
  }
  ns.paste.go $2 $1
}
alias ns.paste.go {
  var %f = $1, %id = $2, %url = $ns.get(paste,url), %host = $gettok($mid(%url,9),1,47), %size = $file(%f).size
  if (!%size) {
    ns.err that file is empty or missing.
    return
  }
  if (%size > 20971520) {
    ns.err $nopath(%f) is $bytes(%size,b).suf - the limit is 20 MB.
    return
  }
  if ($ns.flag(paste,confirm,1)) && (!$input(Upload $nopath(%f) $+ $chr(32) $+ $chr(40) $+ $bytes(%size,b).suf $+ $chr(41) to %host $+ $chr(63) $+ $crlf $+ Anyone with the link can open it.,yq,Upload)) return
  ns.win.start
  ns.win.new
  ns.win.set id %id
  ns.win.set file %f
  ns.win.set url %url
  ns.win.set method $ns.get(paste,method,POST)
  ns.win.set field $ns.get(paste,field,file)
  ns.win.go upload
  ns.say uploading $nopath(%f) to %host $+ ...
}
; $1 = id, $2- = the link, or "<anything>" + chr(1) + error
alias ns.paste.done {
  var %r = $2-, %p = $pos(%r,$chr(1))
  if (%p) {
    ns.err upload failed: $mid(%r,$calc(%p + 1))
    return
  }
  if ($left(%r,8) != https://) && ($left(%r,7) != http://) {
    ns.err upload finished but the host did not answer with a link: $left(%r,100)
    return
  }
  clipboard %r
  editbox -a %r
  ns.say uploaded: $+($ns.cc($ns.get(theme,accent,13)),%r,$ns.o) (copied, and placed in your editbox)
}

; ---------------------------------------------------------------- lifecycle
on *:SIGNAL:ns.boot:{
  unset %ns.win.lasttoast %ns.dict.on
  if ($ns.win.wanted) .timer.nswb -o 1 5 ns.win.apply
  .timer.nswt 0 2 ns.win.tick
}
on *:SIGNAL:ns.exit:{ unset %ns.dict.on | ns.win.quit }
on *:SIGNAL:ns.uninstall:{
  if ($ns.flag(toast,on,0)) && ($ns.win.alive) ns.win.send unregister
  ns.win.quit
}
on *:SIGNAL:ns.opts:{ .timer.nswa -o 1 1 ns.win.apply }
