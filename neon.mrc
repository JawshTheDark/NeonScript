; ============================================================================
;  NeonScript 2026  ::  core
;  Loader, settings API, boot sequence, signals, /neon dispatcher, menubar.
;  Requires mIRC 7.85 or newer.  Everything is plain mIRC script - no DLLs.
; ============================================================================

alias ns.name return NeonScript
alias ns.ver return 2026.3.1
alias ns.tag return $+($ns.name,$chr(32),$ns.ver)
alias ns.ini return $+($scriptdir,neon.ini)
alias ns.profini return $+($scriptdir,profiles.ini)
alias ns.asset return $+($scriptdir,assets\,$1)
alias ns.data return $+($scriptdir,data\,$1)
alias ns.modules return neon_system neon_secure neon_chat neon_web neon_theme neon_toolbar neon_events neon_mts neon_dialogs neon_servers neon_bnc neon_chan neon_hud neon_tools neon_protect neon_away neon_sound neon_media neon_fun neon_alias

; ---------------------------------------------------------------- settings API
; $ns.get(section,item,default)  /ns.set section item value
alias ns.get {
  var %v = $readini($ns.ini,n,$1,$2)
  if ($len(%v) == 0) return $3-
  return %v
}
alias ns.set {
  if ($3- == $null) writeini -nz $qt($ns.ini) $1 $2
  else writeini -n $qt($ns.ini) $1 $2 $3-
}
alias ns.del remini $qt($ns.ini) $1 $2
alias ns.flag return $iif($ns.get($1,$2,$3) == 1,1,0)
alias ns.toggle {
  ns.set $1 $2 $iif($ns.flag($1,$2,$3),0,1)
  return $ns.flag($1,$2,$3)
}

; ---------------------------------------------------------------- tiny helpers
; mIRC colour code for palette index N (0-98), always two digits
alias ns.cc return $+($chr(3),$base($1,10,10,2))
alias ns.b return $chr(2)
alias ns.o return $chr(15)
; "#rrggbb" -> mIRC RGB integer
alias ns.hex {
  var %h = $remove($1,$chr(35))
  return $rgb($base($mid(%h,1,2),16,10),$base($mid(%h,3,2),16,10),$base($mid(%h,5,2),16,10))
}
; is a script file already loaded?
alias ns.isloaded {
  var %i = $script(0)
  while (%i) {
    if ($nopath($script(%i)) == $nopath($1-)) return $true
    dec %i
  }
  return $false
}
; open a dialog, or focus it if it is already open
alias ns.dlg {
  if ($dialog($1)) dialog -v $1
  else dialog -m $1 $2
}
; run a command a moment later (after the current script/dialog event ends) - needed for $input etc.
alias ns.later .timer -do 1 0 $1-
; apply a /did switch to every EXISTING id in lo..hi:  ns.didr <switch> <dialog> <lo> <hi>
alias ns.didr {
  var %i = $3
  while (%i <= $4) {
    if ($did($2,%i).isid) did $1 $2 %i
    inc %i
  }
}
; $ischan() is not an mIRC identifier (ischan is only an if-operator) - this wraps it
alias ns.ischan {
  if ($1 ischan) return 1
  return 0
}
; mIRC has no $trim: strip leading/trailing/duplicate spaces
alias ns.trim return $gettok($1-,1-,32)
; multi-line edit controls: did -a glues lines together, so collect them first and set them in one go
;   ns.ml.new   ns.ml.add <line...>  (repeat)   ns.ml.set <dialog> <id>
alias ns.ml.new {
  if ($hget(ns.ml)) hfree ns.ml
  hmake ns.ml 10
  hadd ns.ml n 0
}
alias ns.ml.add {
  hinc ns.ml n
  hadd ns.ml $hget(ns.ml,n) $1-
}
alias ns.ml.set {
  var %n = $hget(ns.ml,n), %i = 1, %t = $chr(2)
  while (%i <= %n) {
    if (%i > 1) %t = %t $+ $crlf
    %t = %t $+ $hget(ns.ml,%i)
    inc %i
  }
  did -ra $1 $2 $remove(%t,$chr(2))
}
; escape & for dialog captions (an unescaped & is eaten as an accelerator)
alias ns.esc return $replace($1-,$chr(38),$+($chr(38),$chr(38)))
; *!*@host mask for a nick, or nick!*@* when its address is not known yet
alias ns.mask {
  var %a = $address($1,2)
  if (%a) return %a
  return $+($1,!*@*)
}
; space-separated line numbers selected in a listbox:  $ns.did.sels(dialog,id)
alias ns.did.sels {
  var %n = $did($1,$2,0).sel, %k = 1, %o
  while (%k <= %n) {
    %o = %o $did($1,$2,%k).sel
    inc %k
  }
  return $ns.trim(%o)
}
; prefix used on every NeonScript message
alias ns.pfx return $+($ns.cc($ns.get(theme,accent,13)),$chr(2),NEON,$chr(2),$ns.o,$chr(32),$chr(183))
; pretty messages: ns.say -> active window, ns.sys -> status window
alias ns.say echo -cat info $ns.pfx $1-
alias ns.sys echo -cst info $ns.pfx $1-
alias ns.err { ns.log err $1- | echo -cat info $+($ns.pfx,$chr(32),$ns.cc(04),error:,$ns.o) $1- }
alias ns.dbg { ns.log dbg $1- | if ($ns.flag(advanced,debug,0)) write $qt($+($scriptdir,neon.log)) $+([,$asctime(HH:nn:ss),]) $1- }
; debug ring: the last 400 internal messages, shown by /neon debug.  Never log secrets here.
alias ns.log {
  var %n = $calc($hget(ns.dbglog,n) + 1)
  hadd -m ns.dbglog n %n
  hadd ns.dbglog %n $+($asctime(HH:nn:ss),$chr(9),$1,$chr(9),$strip($2-))
  if (%n > 400) hdel ns.dbglog $calc(%n - 400)
}
; a themed one-line rule for status headers
alias ns.rule return $+($ns.cc($ns.get(theme,accent,13)),$str($chr(9472),$iif($1,$1,44)),$ns.o)

; ---------------------------------------------------------------- channel ranks: ~ & @ % +
; The server's PREFIX token looks like "(qaohv)~&@%+" (mIRC's default is "(ohv)@%+").
; Everything rank-related in NeonScript goes through these helpers so owner (~),
; admin (&), op (@), halfop (%) and voice (+) are all handled wherever they matter.
alias ns.rk.std return $+($chr(126),$chr(38),$chr(64),$chr(37),$chr(43))
alias ns.rk.chars {
  ; $prefix is the symbols only ("~&@%+"); strip any "(qaohv)" / "PREFIX=" decoration just in case
  var %c = $regsubex($prefix,/[A-Za-z()=]/g,)
  return $iif(%c,%c,$+($chr(64),$chr(37),$chr(43)))
}
alias ns.rk.modes {
  var %m = $regsubex($nickmode,/[^A-Za-z]/g,)
  return $iif(%m,%m,ohv)
}
; mode letter (q a o h v) for a prefix character, and the plain-English rank name
alias ns.rk.letter {
  var %p = $pos($ns.rk.std,$1)
  if (!%p) return $null
  return $mid(qaohv,%p,1)
}
alias ns.rk.name {
  var %p = $pos($ns.rk.std,$1)
  if (!%p) return $null
  return $gettok(owner admin op halfop voice,%p,32)
}
alias ns.rk.lname {
  var %p = $pos(qaohv,$1)
  if (!%p) return $null
  return $gettok(owner admin op halfop voice,%p,32)
}
alias ns.rk.char {
  var %p = $pos(qaohv,$1)
  if (!%p) return $null
  return $mid($ns.rk.std,%p,1)
}
; highest prefix a nick holds on a channel ("" if none)
alias ns.rk.of {
  var %f = $left($nick($1,$2).pnick,1)
  if (%f != $null) && ($pos($ns.rk.chars,%f)) return %f
  return $null
}
; 1 = highest rank on this server, 99 = no prefix
alias ns.rk.num {
  var %f = $ns.rk.of($1,$2)
  if (!%f) return 99
  return $pos($ns.rk.chars,%f)
}
; 1 if <nick> holds at least privilege <letter> on <chan>:  $ns.rk.atleast(#,nick,o)
alias ns.rk.atleast {
  var %need = $pos($ns.rk.modes,$3)
  if (!%need) return 0
  return $iif($ns.rk.num($1,$2) <= %need,1,0)
}
; can I grant/remove privilege <letter> on <chan>?
alias ns.rk.cangive {
  var %l = $2
  if (%l == v) return $ns.rk.atleast($1,$me,h)
  if (%l == h) || (%l == o) return $ns.rk.atleast($1,$me,o)
  if (%l == a) return $ns.rk.atleast($1,$me,a)
  if (%l == q) return $ns.rk.atleast($1,$me,q)
  return 0
}
; can I kick or ban on <chan>? halfop and above
alias ns.rk.cankick return $iif($pos($ns.rk.modes,h),$ns.rk.atleast($1,$me,h),$ns.rk.atleast($1,$me,o))
; 1 if <nick> currently holds the prefix for mode <letter> (works with multi-prefix servers: @+nick)
alias ns.rk.has {
  var %pn = $nick($1,$2).pnick, %pre = $left(%pn,$calc($len(%pn) - $len($2)))
  return $iif($pos(%pre,$ns.rk.char($3)),1,0)
}
; 1 if <a> outranks <b> on the channel
alias ns.rk.outranks return $iif($ns.rk.num($1,$2) < $ns.rk.num($1,$3),1,0)
; coloured prefix glyph for a prefix character
alias ns.rk.glyph {
  if (!$1) return $null
  return $+($ns.ec($ns.rk.letter($1)),$1,$ns.o)
}

; ---------------------------------------------------------------- module loader
alias ns.loadall {
  var %i = 1, %m, %f
  while ($gettok($ns.modules,%i,32)) {
    %m = $v1
    %f = $+($scriptdir,%m,.mrc)
    if ($exists(%f)) && (!$ns.isloaded(%f)) .load -rs $qt(%f)
    inc %i
  }
}
alias ns.reloadall {
  var %i = 1, %m, %f
  while ($gettok($ns.modules,%i,32)) {
    %m = $v1
    %f = $+($scriptdir,%m,.mrc)
    if ($ns.isloaded(%f)) reload -rs $qt(%f)
    inc %i
  }
  .timer.nsboot -o 1 1 ns.boot 1
}

; ---------------------------------------------------------------- events
on *:LOAD:{
  ns.loadall
  .timer.nsfirst -o 1 2 ns.firstrun
}
on *:START:{
  unset %ns.booted %ns.autodone
  ns.loadall
  .timer.nsboot -o 1 1 ns.boot
}
on *:EXIT:{
  .signal -n ns.exit
  flushini $ns.ini
}

; ns.boot [force] - fan out the boot signal to every module
alias ns.boot {
  if (%ns.booted) && (!$1) return
  set %ns.booted 1
  titlebar $+($ns.tag,$chr(32),::,$chr(32),mIRC,$chr(32),$version)
  .signal -n ns.boot
  .signal -n ns.ready
  ns.welcome
  if ($ns.get(general,wizard,0) != 1) .timer.nsfirst -o 1 4 ns.firstrun
}

; one-time setup the first time the script is ever loaded
alias ns.firstrun {
  if ($ns.get(general,wizard,0) == 1) return
  neon wizard
}

; Status-window greeting
alias ns.welcome {
  if (!$ns.flag(general,welcome,1)) return
  var %a = $ns.cc($ns.get(theme,accent,13)), %g = $ns.cc(14), %w = $ns.cc(11), %o = $ns.o
  echo -cst info $ns.rule(52)
  echo -cst info $+(%a,$chr(2),$ns.name,$chr(2),%o,$chr(32),$ns.ver,%g,$chr(32),$chr(183),$chr(32),mIRC,$chr(32),$version,$chr(32),$chr(183),$chr(32),Windows,$chr(32),$os,%o)
  echo -cst info $+(%g,Type,%o,$chr(32),%w,/neon,%o,$chr(32),%g,for the control panel,$chr(44),%o,$chr(32),%w,/neonhelp,%o,$chr(32),%g,for every command.,%o)
  echo -cst info $ns.rule(52)
}

; ---------------------------------------------------------------- /neon dispatcher
; /neon              control panel
; /neon <command>    runs alias neon.<command> (modules add their own)
alias neon {
  var %c = $lower($1)
  if (%c == $null) { neon.options | return }
  if ($isalias($+(neon.,%c))) { $+(neon.,%c) $2- | return }
  ns.err unknown command $qt(%c) $+ . Try $+($ns.cc(11),/neonhelp,$ns.o) for a list.
}
; /neon options [page]   pages: general connection display sounds protection away commands advanced
alias neon.options {
  set -u30 %ns.optpage $1
  ns.dlg ns_opt ns_opt
}
alias neon.version ns.say $ns.tag running on mIRC $version $+ , Windows $os
alias neon.reload {
  ns.reloadall
  ns.say scripts reloaded.
}
alias neon.boot ns.boot 1
alias neon.uninstall {
  if (!$input(This removes NeonScript from mIRC. Your NeonScript settings are kept in this folder. $+ $crlf $+ Continue?,yq,Uninstall NeonScript)) return
  var %restore = $input(Also put mIRC's original colours$chr(44) toolbar and stock aliases back? $+ $crlf $+ (Choose No to keep the NeonScript colours.),yq,Restore the original look)
  .signal -n ns.uninstall
  if (%restore) ns.stock.restore
  else toolbar -r
  .timer.ns* off
  var %i = 1
  while ($gettok($ns.modules,%i,32)) {
    var %f = $+($scriptdir,$v1,.mrc)
    if ($ns.isloaded(%f)) unload -rs $qt(%f)
    inc %i
  }
  echo -a NeonScript removed. Delete the scripts\neonscript folder to finish.
  .timer 1 1 unload -rs $qt($script)
}

; ---------------------------------------------------------------- menubar
menu menubar {
  -
  NeonScript control panel...:neon
  Servers && Networks...:neon servers
  Themes...:neon themes
  -
  Dashboard:neon dash
  Set away...:neon away
  Do not disturb:neon dnd
  -
  Text effects...:neon fx
  Symbol map...:neon chars
  Kick && ban...:neon kb
  Clone scanner:neon clones
  Userlist...:neon users
  Messages...:neon messages
  Hotkeys...:neon hotkeys
  Sounds...:neon sounds
  -
  Command reference:neonhelp
  About NeonScript:neon about
  Self-test:neon selftest
  Debug console:neon debug
  Backup && restore...:neon backup
  Reload NeonScript:neon reload
}
