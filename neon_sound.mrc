; ============================================================================
;  NeonScript 2026  ::  sound system + do-not-disturb
;  Map events to .wav files (defaults come from C:\Windows\Media), mute with
;  one click, and honour mIRC's Do Not Disturb.
; ============================================================================

alias ns.snd.events return connect disconnect highlight pm kick invite join error
alias ns.snd.label {
  var %e = $1
  if (%e == connect) return Connected to a server
  if (%e == disconnect) return Disconnected
  if (%e == highlight) return Someone mentions my nick
  if (%e == pm) return Private message received
  if (%e == kick) return I was kicked
  if (%e == invite) return I was invited
  if (%e == join) return I joined a channel
  if (%e == error) return Error
  return %e
}
; built-in defaults (the first existing file wins; empty = silent)
alias ns.snd.default {
  ; a sound pack from Control Panel > Sounds (assets\sounds\<pack>\<event>.wav) wins over the Windows defaults
  var %pk = $ns.get(sound,pack,windows), %pf = $+($scriptdir,assets\sounds\,%pk,\,$1,.wav)
  if (%pk != windows) && ($exists(%pf)) return %pf
  var %d = $+($windir,\Media\), %n, %i = 1, %list
  if ($1 == connect) %list = Windows Logon.wav;Windows Notify System Generic.wav;Windows Ding.wav
  if ($1 == disconnect) %list = Windows Hardware Remove.wav;Windows Background.wav
  if ($1 == highlight) %list = Windows Notify Messaging.wav;Windows Notify System Generic.wav;Windows Ding.wav
  if ($1 == pm) %list = Windows Notify Email.wav;Windows Notify Messaging.wav;Windows Ding.wav
  if ($1 == kick) %list = Windows Exclamation.wav;Windows Critical Stop.wav
  if ($1 == invite) %list = Windows Notify Calendar.wav;Windows Ding.wav
  if ($1 == join) return $null
  if ($1 == error) %list = Windows Error.wav
  while ($gettok(%list,%i,59) != $null) {
    %n = $+(%d,$v1)
    if ($exists(%n)) return %n
    inc %i
  }
  return $null
}
alias ns.snd.file {
  var %v = $readini($ns.ini,n,sounds,$1)
  if (%v == $null) return $ns.snd.default($1)
  if (%v == -) return $null
  return %v
}
; play the sound for an event, unless muted / DND / disabled for that class
alias ns.snd {
  if (!$ns.flag(sound,enabled,1)) return
  if ($donotdisturb) return
  if ($isalias(ns.bnc.q)) && ($ns.bnc.q) return
  var %e = $1, %f = $ns.snd.file(%e)
  if (%e == highlight) && (!$ns.flag(sound,highlight,1)) return
  if (%e == pm) && (!$ns.flag(sound,pm,1)) return
  if (%e == connect) || (%e == disconnect) { if (!$ns.flag(sound,connect,1)) return }
  if (%f) && ($exists(%f)) splay -w $qt(%f)
}
on *:CONNECT:{ ns.snd connect }
on *:DISCONNECT:{ ns.snd disconnect }
on *:TEXT:*:#:{ if ($me isin $1-) && (!$ns.hl.muted($fulladdress)) ns.snd highlight }
on *:ACTION:*:#:{ if ($me isin $1-) && (!$ns.hl.muted($fulladdress)) ns.snd highlight }
on *:TEXT:*:?:{ ns.snd pm }
on *:INVITE:*:{ ns.snd invite }
on *:KICK:#:{ if ($knick == $me) ns.snd kick }
on *:JOIN:#:{ if ($nick == $me) ns.snd join }

; ---------------------------------------------------------------- mute / do-not-disturb
alias neon.mute {
  ns.toggle sound enabled 1
  ns.say sounds $iif($ns.flag(sound,enabled,1),enabled,muted) $+ .
  .signal -n ns.sync
}
alias neon.dnd {
  donotdisturb $iif($donotdisturb,off,on)
  ns.say do not disturb: $iif($donotdisturb,$+($ns.ec(kick),ON,$ns.o),off)
  .signal -n ns.sync
}
alias neon.testsound ns.snd.test highlight
alias ns.snd.test {
  var %f = $ns.snd.file($1)
  if (%f) && ($exists(%f)) splay -w $qt(%f)
  else ns.err no sound set for $1
}

; ---------------------------------------------------------------- Sound manager dialog
alias neon.sounds ns.dlg ns_snd ns_snd
dialog ns_snd {
  title "Sounds"
  size -1 -1 260 178
  option dbu
  icon 1, 0 0 260 30, $mircexe, 0, noborder
  list 2, 6 36 120 100, size vsbar
  text "Sound file for the selected event:", 3, 132 38 122 9
  edit "", 4, 132 48 122 11, autohs read
  button "Browse...", 5, 132 64 38 13
  button "Test", 6, 174 64 38 13
  button "Clear", 7, 216 64 38 13
  button "Defaults", 8, 132 82 40 13
  check "Sounds enabled", 9, 132 106 100 9
  check "Do not disturb", 10, 132 118 100 9
  text "Files can be .wav, .mp3 or .ogg. 'Do not disturb' silences every sound and flashing icon in mIRC.", 11, 6 142 190 18
  button "Close", 12, 206 158 48 13, ok cancel
}
alias -l sfill {
  var %i = 1, %sel = $did(ns_snd,2).sel, %e, %f
  did -r ns_snd 2
  while ($gettok($ns.snd.events,%i,32)) {
    %e = $v1
    %f = $ns.snd.file(%e)
    did -a ns_snd 2 $ns.snd.label(%e) $+ $chr(32) $+ $chr(40) $+ $iif(%f,$nopath(%f),none) $+ $chr(41)
    inc %i
  }
  if (%sel) did -c ns_snd 2 %sel
}
on *:DIALOG:ns_snd:init:*:{
  did -g ns_snd 1 $ns.asset(header_sounds.png)
  sfill
  did -c ns_snd 2 1
  did -ra ns_snd 4 $ns.snd.file(connect)
  if ($ns.flag(sound,enabled,1)) did -c ns_snd 9
  if ($donotdisturb) did -c ns_snd 10
}
on *:DIALOG:ns_snd:sclick:2:{ did -ra ns_snd 4 $ns.snd.file($gettok($ns.snd.events,$did(ns_snd,2).sel,32)) }
on *:DIALOG:ns_snd:sclick:5:{
  var %e = $gettok($ns.snd.events,$did(ns_snd,2).sel,32), %f = $sfile($+($windir,\Media\*.wav),Choose a sound,Use)
  if (%f) {
    ns.set sounds %e %f
    did -ra ns_snd 4 %f
    sfill
  }
}
on *:DIALOG:ns_snd:sclick:6:{ ns.snd.test $gettok($ns.snd.events,$did(ns_snd,2).sel,32) }
on *:DIALOG:ns_snd:sclick:7:{
  ns.set sounds $gettok($ns.snd.events,$did(ns_snd,2).sel,32) -
  did -r ns_snd 4
  sfill
}
on *:DIALOG:ns_snd:sclick:8:{
  ns.del sounds $gettok($ns.snd.events,$did(ns_snd,2).sel,32)
  did -ra ns_snd 4 $ns.snd.file($gettok($ns.snd.events,$did(ns_snd,2).sel,32))
  sfill
}
on *:DIALOG:ns_snd:sclick:9:{
  ns.set sound enabled $did(ns_snd,9).state
  .signal -n ns.sync
}
on *:DIALOG:ns_snd:sclick:10:{
  donotdisturb $iif($did(ns_snd,10).state,on,off)
  .signal -n ns.sync
}
