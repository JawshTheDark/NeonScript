; ============================================================================
;  NeonScript 2026  ::  custom event templates   /neon templates
;  How each kind of line looks - a channel message, an action, a join, a kick ... - written with the same
;  <tokens> an MTS theme uses (<nick> <chan> <text> <c1>..<c4> ...).  Edit them here, see them in a preview
;  window, and apply: your set is saved as data\mts\my_templates.mts (an ordinary MTS theme), so it also shows
;  up in the theme gallery and can be shared.
; ============================================================================

alias ns.evt.keys return TextChan ActionChan NoticeChan TextQuery ActionQuery Join JoinSelf Part Quit Kick KickSelf Nick NickSelf Mode Topic Invite
alias ns.evt.label {
  var %k = $lower($1)
  if (%k == textchan) return Channel message
  if (%k == actionchan) return Channel action (/me)
  if (%k == noticechan) return Channel notice
  if (%k == textquery) return Private message
  if (%k == actionquery) return Private action
  if (%k == join) return Someone joins
  if (%k == joinself) return I join a channel
  if (%k == part) return Someone leaves
  if (%k == quit) return Someone quits
  if (%k == kick) return Someone is kicked
  if (%k == kickself) return I am kicked
  if (%k == nick) return Someone changes nick
  if (%k == nickself) return I change nick
  if (%k == mode) return Mode change
  if (%k == topic) return Topic change
  if (%k == invite) return I am invited
  return $1
}
alias ns.evt.file return $ns.mts.file(my_templates.mts)
alias ns.evt.default return $ns.data(mts\irssi_night.mts)
; every template in an .mts file into the ns.evt hash (key in lower case)
alias ns.evt.read {
  var %f = $1, %i = 1, %n = $lines(%f), %l, %k, %p
  if ($hget(ns.evt)) hfree ns.evt
  hmake ns.evt 40
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    inc %i
    if (%l == $null) || ($left(%l,1) == $chr(59)) || ($left(%l,1) == $chr(91)) continue
    %p = $pos(%l,$chr(32))
    if (!%p) continue
    %k = $lower($left(%l,$calc(%p - 1)))
    if ($istok($lower($ns.evt.keys),%k,32)) && ($hget(ns.evt,%k) == $null) hadd ns.evt %k $mid(%l,$calc(%p + 1))
  }
  hadd ns.evt __base $nopath(%f)
}
; write my_templates.mts: the base theme with the edited templates substituted in
alias ns.evt.write {
  var %base = $ns.mts.file($hget(ns.evt,__base)), %out = $ns.evt.file, %i = 1, %n, %l, %k, %p, %done
  if (!$exists(%base)) %base = $ns.evt.default
  if ($exists(%out)) .remove $qt(%out)
  %n = $lines(%base)
  while (%i <= %n) {
    %l = $read(%base,n,%i)
    inc %i
    %p = $pos(%l,$chr(32))
    %k = $iif(%p,$lower($left(%l,$calc(%p - 1))),$lower(%l))
    if ($lower($left(%l,5)) == $+(name,$chr(32))) {
      write $qt(%out) Name My templates
      continue
    }
    if ($lower($left(%l,7)) == $+(author,$chr(32))) {
      write $qt(%out) Author $+($me,$chr(44),$chr(32),NeonScript template editor)
      continue
    }
    if ($lower($left(%l,12)) == $+(description,$chr(32))) {
      write $qt(%out) Description Your own line templates, based on $ns.mts.name($hget(ns.evt,__base)) $+ .
      continue
    }
    if ($istok($lower($ns.evt.keys),%k,32)) {
      write $qt(%out) $+($gettok($ns.evt.keys,$findtok($lower($ns.evt.keys),%k,1,32),32),$chr(32),$hget(ns.evt,%k))
      %done = %done %k
      continue
    }
    write $qt(%out) %l
  }
  ; templates the base did not have
  %i = 1
  while ($gettok($ns.evt.keys,%i,32) != $null) {
    %k = $lower($gettok($ns.evt.keys,%i,32))
    inc %i
    if (!$istok(%done,%k,32)) && ($hget(ns.evt,%k) != $null) write $qt(%out) $+($gettok($ns.evt.keys,$calc(%i - 1),32),$chr(32),$hget(ns.evt,%k))
  }
  return %out
}

alias neon.templates {
  set -u120 %ns.evt.base $iif($1 != $null,$1,$iif($ns.mts.active != $null,$ns.mts.active,irssi_night.mts))
  ns.dlg ns_evt ns_evt
}
dialog ns_evt {
  title "Event Templates"
  size -1 -1 392 250
  option dbu
  icon 1, 0 0 392 30, $mircexe, 0, noborder
  text "Start from:", 2, 6 37 36 9
  combo 3, 44 35 140 100, drop
  button "Load", 4, 188 34 30 12
  list 10, 6 50 124 136, size vsbar
  text "Template for the selected line:", 11, 138 52 130 9
  edit "", 12, 138 62 248 11, autohs
  text "Tokens (type them inside < >):", 13, 138 78 130 9
  edit "", 14, 138 88 248 78, read multi vsbar
  button "Preview", 20, 138 172 50 13
  button "Apply", 21, 192 172 50 13
  button "Reset this line", 22, 246 172 60 13
  button "Reset all", 23, 310 172 50 13
  text "Preview opens a window that shows every line type with the colours of the base theme; Apply makes it the active theme (your templates are saved as my_templates.mts).", 24, 6 192 380 18
  text "", 25, 6 214 300 9
  button "Close", 26, 338 230 48 13, ok cancel
}
on *:DIALOG:ns_evt:init:*:{
  did -g ns_evt 1 $ns.asset(header_evt.png)
  var %i = 1, %f, %sel = 1
  while ($gettok($ns.mts.files,%i,32) != $null) {
    %f = $v1
    did -a ns_evt 3 $ns.mts.name(%f) $+ $chr(32) $+ $chr(40) $+ %f $+ $chr(41)
    if (%f == %ns.evt.base) %sel = %i
    inc %i
  }
  if (%i == 1) did -a ns_evt 3 Irssi Night (irssi_night.mts)
  did -c ns_evt 3 %sel
  ns.ml.new
  ns.ml.add <nick> <address> <chan> <cmode> <text> <newnick> <knick> <modes> <parentext> <pre>
  ns.ml.add <cmode> = the person's rank symbol (@ % + ...)      <pre> = the theme's event prefix
  ns.ml.add <c1> <c2> <c3> <c4> = the theme's four base colours (text, nick, highlight, dim)
  ns.ml.add <b> bold   <u> underline   <r> reverse   <o> reset all   <lt> <gt> literal < and >
  ns.ml.add $chr(160)
  ns.ml.add Example:   <c4><lt><o><c3><cmode><o><c2><nick><o><c4><gt><o> <text>
  ns.ml.set ns_evt 14
  evload $gettok($ns.mts.files,%sel,32)
}
alias -l evload {
  var %f = $iif($1 != $null,$ns.mts.file($1),$ns.evt.default), %i = 1
  if (!$exists(%f)) %f = $ns.evt.default
  ns.evt.read %f
  did -r ns_evt 10
  while ($gettok($ns.evt.keys,%i,32) != $null) {
    did -a ns_evt 10 $ns.evt.label($v1)
    inc %i
  }
  did -c ns_evt 10 1
  evpick 1
}
alias -l evpick {
  var %k = $lower($gettok($ns.evt.keys,$1,32))
  if (!%k) return
  did -ra ns_evt 12 $hget(ns.evt,%k)
}
on *:DIALOG:ns_evt:sclick:10:{ evpick $did(ns_evt,10).sel }
on *:DIALOG:ns_evt:edit:12:{
  var %k = $lower($gettok($ns.evt.keys,$did(ns_evt,10).sel,32))
  if (%k) hadd -m ns.evt %k $did(ns_evt,12).text
}
on *:DIALOG:ns_evt:sclick:4:{
  var %f = $gettok($ns.mts.files,$did(ns_evt,3).sel,32)
  if (%f) evload %f
  did -ra ns_evt 25 Loaded the templates of $ns.mts.name(%f) $+ .
}
on *:DIALOG:ns_evt:sclick:20:{
  var %f = $ns.evt.write
  ns.mts.preview $nopath(%f)
  did -ra ns_evt 25 Preview window opened.
}
on *:DIALOG:ns_evt:sclick:21:{
  var %f = $ns.evt.write
  ns.mts.apply $nopath(%f)
  .signal -n ns.mtschanged
  did -ra ns_evt 25 Applied - this is your active theme now.
}
on *:DIALOG:ns_evt:sclick:22:{
  var %k = $lower($gettok($ns.evt.keys,$did(ns_evt,10).sel,32)), %b = $ns.evt.default, %i = 1, %n = $lines(%b), %l, %p
  if (!%k) return
  while (%i <= %n) {
    %l = $read(%b,n,%i)
    inc %i
    %p = $pos(%l,$chr(32))
    if (%p) && ($lower($left(%l,$calc(%p - 1))) == %k) {
      hadd -m ns.evt %k $mid(%l,$calc(%p + 1))
      break
    }
  }
  evpick $did(ns_evt,10).sel
  did -ra ns_evt 25 Reset to the Irssi Night style.
}
on *:DIALOG:ns_evt:sclick:23:{
  evload $iif($exists($ns.evt.default),irssi_night.mts)
  did -ra ns_evt 25 Everything reset to the Irssi Night templates.
}
