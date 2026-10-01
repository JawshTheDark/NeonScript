; ============================================================================
;  NeonScript 2026  ::  tools
;  Command reference, text effects, symbol map, message lists, hotkeys,
;  rank-aware kick & ban, and the clone scanner.
; ============================================================================

; ---------------------------------------------------------------- command reference
alias neonhelp neon.help
alias neon.help {
  var %w = @NeonHelp, %f = $ns.data(commands.txt), %i = 1, %n = $lines(%f), %l, %lab, %desc, %pad
  var %a = $ns.cc($ns.get(theme,accent,13)), %lc = $ns.ec(value), %vc = $ns.ec(label), %dc = $ns.ec(dim), %o = $ns.o, %col = 34
  if ($window(%w)) window -c %w
  window -Cz %w 100 60 820 560
  titlebar %w NeonScript command reference
  echo -c info %w $+(%a,$chr(2),$ns.tag,$chr(2),%o,$chr(32),%dc,- every command at a glance. Type them in any window.,%o)
  echo -c info %w $chr(160)
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    inc %i
    if (%l == $null) continue
    if ($left(%l,1) == $chr(35)) {
      echo -c info %w $chr(160)
      echo -c info %w $+(%a,$chr(2),$mid(%l,2),$chr(2),%o)
      continue
    }
    %lab = $gettok(%l,1,124)
    %desc = $gettok(%l,2-,124)
    ; short label: two columns, wrapped description hangs under the description column.
    ; long label: label on its own line, description indented below it.
    if ($len(%lab) < %col) {
      echo -ci $+ %col info %w $+(%lc,%lab,$str($+($chr(15),$chr(32),$chr(15)),$calc(%col - $len(%lab))),%o) $+ $+(%vc,%desc,%o)
    }
    else {
      echo -c info %w $+(%lc,$chr(2),%lab,$chr(2),%o)
      echo -ci4 info %w $+($str($chr(160),4),%vc,%desc,%o)
    }
  }
}

; ---------------------------------------------------------------- message lists
alias ns.msg.file return $ns.data($+(msg_,$1,.txt))
; $ns.msg(quit|part|kick|slap|away) -> a random line from that list
alias ns.msg {
  var %f = $ns.msg.file($1)
  if (!$exists(%f)) return $null
  return $read(%f,n)
}
alias neon.messages {
  set -u60 %ns.msgcat $iif($findtok(quit part kick slap away,$1,1,32),$1,quit)
  ns.dlg ns_msg ns_msg
}
dialog ns_msg {
  title "Messages"
  size -1 -1 248 178
  option dbu
  icon 1, 0 0 248 30, $mircexe, 0, noborder
  text "List:", 2, 6 37 30 9
  combo 3, 40 35 100 70, drop
  list 4, 6 50 236 70, size vsbar
  edit "", 5, 6 124 236 11, autohs
  button "Add", 6, 6 140 44 13
  button "Replace", 7, 54 140 44 13
  button "Remove", 8, 102 140 44 13
  button "Reset list", 9, 150 140 44 13
  text "Used when you /quit, /part, /kick, /slap or go /away without writing a message. Slap lines use %t for the target.", 10, 6 158 180 18
  button "Close", 11, 194 160 48 13, ok cancel
}
alias -l mcats return quit part kick slap away
alias -l mfill {
  var %cat = $gettok($mcats,$did(ns_msg,3).sel,32), %f = $ns.msg.file(%cat), %i = 1, %n = $lines(%f)
  did -r ns_msg 4
  while (%i <= %n) {
    did -a ns_msg 4 $read(%f,n,%i)
    inc %i
  }
}
alias -l msave {
  var %cat = $gettok($mcats,$did(ns_msg,3).sel,32), %f = $ns.msg.file(%cat), %i = 1, %n = $did(ns_msg,4).lines
  write -c $qt(%f)
  while (%i <= %n) {
    write $qt(%f) $did(ns_msg,4,%i)
    inc %i
  }
}
on *:DIALOG:ns_msg:init:*:{
  did -g ns_msg 1 $ns.asset(header_messages.png)
  did -a ns_msg 3 Quit messages
  did -a ns_msg 3 Part messages
  did -a ns_msg 3 Kick reasons
  did -a ns_msg 3 Slap lines
  did -a ns_msg 3 Away reasons
  var %c = $findtok($mcats,%ns.msgcat,1,32)
  did -c ns_msg 3 $iif(%c,%c,1)
  mfill
}
on *:DIALOG:ns_msg:sclick:3:{ mfill }
on *:DIALOG:ns_msg:sclick:4:{ did -ra ns_msg 5 $did(ns_msg,4,$did(ns_msg,4).sel) }
on *:DIALOG:ns_msg:sclick:6:{
  if ($did(ns_msg,5).text == $null) return
  did -a ns_msg 4 $did(ns_msg,5).text
  did -r ns_msg 5
  msave
}
on *:DIALOG:ns_msg:sclick:7:{
  var %n = $did(ns_msg,4).sel
  if (!%n) || ($did(ns_msg,5).text == $null) return
  did -o ns_msg 4 %n $did(ns_msg,5).text
  msave
}
on *:DIALOG:ns_msg:sclick:8:{
  var %n = $did(ns_msg,4).sel
  if (!%n) return
  did -d ns_msg 4 %n
  did -r ns_msg 5
  msave
}
on *:DIALOG:ns_msg:sclick:9:{
  var %cat = $gettok($mcats,$did(ns_msg,3).sel,32)
  .copy -o $qt($ns.data($+(defaults\msg_,%cat,.txt))) $qt($ns.msg.file(%cat))
  mfill
}

; ---------------------------------------------------------------- text effects
alias ns.fx.list return Rainbow Fire Ocean Neon Sunset Forest Ice Alternating Wide SmallCaps Spaced
alias -l pal {
  var %e = $1
  if (%e == rainbow) return 04 07 08 09 11 12 13 06
  if (%e == fire) return 52 53 54 66 65 53 52
  if (%e == ocean) return 59 70 71 72 84 72 71 70
  if (%e == neon) return 62 74 86 82 70 58 70 82 86 74
  if (%e == sunset) return 53 64 65 77 87 75 63
  if (%e == forest) return 44 56 68 80 69 80 68 56
  if (%e == ice) return 98 83 71 59 71 83
  return 04 12
}
; $ns.fx(effect) formats the text stored in ns.fxv/text
alias ns.fx {
  var %e = $lower($1), %t = $hget(ns.fxv,text), %n = $len(%t), %i = 1, %o = $chr(2), %c, %np, %p, %code
  if (%e == wide) {
    while (%i <= %n) {
      %c = $mid(%t,%i,1)
      %code = $asc(%c)
      if (%c == $chr(32)) %o = %o $+ $chr(12288)
      elseif (%code >= 33) && (%code <= 126) %o = %o $+ $chr($calc(65248 + %code))
      else %o = %o $+ %c
      inc %i
    }
    return $remove(%o,$chr(2))
  }
  if (%e == smallcaps) {
    var %tab = 7424 665 7428 7429 7431 42800 610 668 618 7434 7435 671 7437 628 7439 7448 491 640 115 7451 7452 7456 7457 120 655 7458
    while (%i <= %n) {
      %c = $mid(%t,%i,1)
      %code = $asc($lower(%c))
      if (%code >= 97) && (%code <= 122) %o = %o $+ $chr($gettok(%tab,$calc(%code - 96),32))
      elseif (%c == $chr(32)) %o = %o $+ $chr(1)
      else %o = %o $+ %c
      inc %i
    }
    return $replace($remove(%o,$chr(2)),$chr(1),$chr(32))
  }
  if (%e == spaced) {
    while (%i <= %n) {
      %c = $mid(%t,%i,1)
      %o = %o $+ $iif(%c == $chr(32),$chr(1),%c) $+ $chr(1)
      inc %i
    }
    return $replace($remove(%o,$chr(2)),$chr(1),$chr(32))
  }
  %o = $chr(2)
  %p = $pal(%e)
  %np = $numtok(%p,32)
  while (%i <= %n) {
    %c = $mid(%t,%i,1)
    if (%c == $chr(32)) %o = %o $+ $chr(1)
    else {
      if (%e == alternating) || (%e == rainbow) %code = $gettok(%p,$calc((%i - 1) % %np + 1),32)
      else %code = $gettok(%p,$calc($int($calc((%i - 1) * %np / %n)) + 1),32)
      %o = %o $+ $chr(3) $+ $base(%code,10,10,2) $+ %c
    }
    inc %i
  }
  return $replace($remove(%o,$chr(2)),$chr(1),$chr(32)) $+ $chr(15)
}
alias neon.fx ns.dlg ns_fx ns_fx
dialog ns_fx {
  title "Text Effects"
  size -1 -1 258 170
  option dbu
  icon 1, 0 0 258 30, $mircexe, 0, noborder
  text "Effect:", 2, 6 36 40 9
  list 3, 6 46 80 100, size vsbar
  text "Your text:", 4, 94 36 100 9
  edit "", 5, 94 46 158 36, multi return vsbar autovs
  check "Bold", 6, 94 88 40 9
  text "Preview shows in the @NeonFX window. Unicode effects (Wide, SmallCaps) need UTF-8 enabled under Options > IRC > Messages.", 7, 94 100 158 24
  button "Preview", 8, 94 128 50 13, default
  button "Say", 9, 148 128 50 13
  button "Action", 10, 202 128 50 13
  button "Copy", 11, 94 146 50 13
  button "Close", 12, 202 146 50 13, ok cancel
}
on *:DIALOG:ns_fx:init:*:{
  did -g ns_fx 1 $ns.asset(header_fx.png)
  var %i = 1
  while ($gettok($ns.fx.list,%i,32)) {
    did -a ns_fx 3 $v1
    inc %i
  }
  did -c ns_fx 3 1
  did -ra ns_fx 5 NeonScript 2026
  fxprev
}
alias -l fxout {
  hadd -m ns.fxv text $did(ns_fx,5,1)
  var %o = $ns.fx($gettok($ns.fx.list,$did(ns_fx,3).sel,32))
  if ($did(ns_fx,6).state) %o = $chr(2) $+ %o
  return %o
}
alias -l fxprev {
  var %w = @NeonFX, %o = $fxout
  if (!$window(%w)) window -pBf %w 40 40 560 70
  titlebar %w Text effect preview
  drawrect -rfn %w $rgb(10,8,24) 1 0 0 560 70
  drawtext -pn %w $rgb(255,255,255) "Segoe UI" 16 14 18 %o
  drawrect %w
}
on *:DIALOG:ns_fx:sclick:3,8:{ fxprev }
on *:DIALOG:ns_fx:edit:5:{ fxprev }
on *:DIALOG:ns_fx:sclick:9:{
  var %o = $fxout
  if ($ns.ischan($active)) || ($query($active)) msg $active %o
  else ns.err open a channel or query window first.
}
on *:DIALOG:ns_fx:sclick:10:{
  var %o = $fxout
  if ($ns.ischan($active)) || ($query($active)) describe $active %o
  else ns.err open a channel or query window first.
}
on *:DIALOG:ns_fx:sclick:11:{ clipboard $fxout }
on *:DIALOG:ns_fx:close:*:{ if ($window(@NeonFX)) window -c @NeonFX }

; ---------------------------------------------------------------- symbol map
; each category: name, first code point, last code point (pages of 60)
alias -l ccat {
  if ($1 == 1) return Arrows 8592 8703
  if ($1 == 2) return Math 8704 8959
  if ($1 == 3) return Shapes 9632 9727
  if ($1 == 4) return Box drawing 9472 9599
  if ($1 == 5) return Stars and misc 9728 9983
  if ($1 == 6) return Dingbats 9984 10175
  if ($1 == 7) return Greek 913 1023
  if ($1 == 8) return Latin symbols 161 255
  if ($1 == 9) return Currency 8352 8399
  if ($1 == 10) return Braille 10240 10495
  return $null
}
alias neon.chars ns.dlg ns_chars ns_chars
dialog ns_chars {
  title "Symbol Map"
  size -1 -1 248 202
  option dbu
  icon 1, 0 0 248 30, $mircexe, 0, noborder
  combo 3, 6 34 100 120, drop
  button "<", 4, 112 33 20 12
  button ">", 5, 136 33 20 12
  text "", 6, 162 35 80 9
  button "", 100, 6 50 20 16, flat
  button "", 101, 29 50 20 16, flat
  button "", 102, 52 50 20 16, flat
  button "", 103, 75 50 20 16, flat
  button "", 104, 98 50 20 16, flat
  button "", 105, 121 50 20 16, flat
  button "", 106, 144 50 20 16, flat
  button "", 107, 167 50 20 16, flat
  button "", 108, 190 50 20 16, flat
  button "", 109, 213 50 20 16, flat
  button "", 110, 6 68 20 16, flat
  button "", 111, 29 68 20 16, flat
  button "", 112, 52 68 20 16, flat
  button "", 113, 75 68 20 16, flat
  button "", 114, 98 68 20 16, flat
  button "", 115, 121 68 20 16, flat
  button "", 116, 144 68 20 16, flat
  button "", 117, 167 68 20 16, flat
  button "", 118, 190 68 20 16, flat
  button "", 119, 213 68 20 16, flat
  button "", 120, 6 86 20 16, flat
  button "", 121, 29 86 20 16, flat
  button "", 122, 52 86 20 16, flat
  button "", 123, 75 86 20 16, flat
  button "", 124, 98 86 20 16, flat
  button "", 125, 121 86 20 16, flat
  button "", 126, 144 86 20 16, flat
  button "", 127, 167 86 20 16, flat
  button "", 128, 190 86 20 16, flat
  button "", 129, 213 86 20 16, flat
  button "", 130, 6 104 20 16, flat
  button "", 131, 29 104 20 16, flat
  button "", 132, 52 104 20 16, flat
  button "", 133, 75 104 20 16, flat
  button "", 134, 98 104 20 16, flat
  button "", 135, 121 104 20 16, flat
  button "", 136, 144 104 20 16, flat
  button "", 137, 167 104 20 16, flat
  button "", 138, 190 104 20 16, flat
  button "", 139, 213 104 20 16, flat
  button "", 140, 6 122 20 16, flat
  button "", 141, 29 122 20 16, flat
  button "", 142, 52 122 20 16, flat
  button "", 143, 75 122 20 16, flat
  button "", 144, 98 122 20 16, flat
  button "", 145, 121 122 20 16, flat
  button "", 146, 144 122 20 16, flat
  button "", 147, 167 122 20 16, flat
  button "", 148, 190 122 20 16, flat
  button "", 149, 213 122 20 16, flat
  button "", 150, 6 140 20 16, flat
  button "", 151, 29 140 20 16, flat
  button "", 152, 52 140 20 16, flat
  button "", 153, 75 140 20 16, flat
  button "", 154, 98 140 20 16, flat
  button "", 155, 121 140 20 16, flat
  button "", 156, 144 140 20 16, flat
  button "", 157, 167 140 20 16, flat
  button "", 158, 190 140 20 16, flat
  button "", 159, 213 140 20 16, flat
  text "Click a symbol to type it into the active window's editbox.", 11, 6 162 236 9
  check "Copy to clipboard instead of typing", 7, 6 174 150 9
  text "", 8, 6 188 170 9
  button "Close", 9, 194 184 48 13, ok cancel
}
alias -l cname return $gettok($ccat($1),1- $+ $calc($numtok($ccat($1),32) - 2),32)
alias -l cfirst return $gettok($ccat($1),-2,32)
alias -l clast return $gettok($ccat($1),-1,32)
on *:DIALOG:ns_chars:init:*:{
  did -g ns_chars 1 $ns.asset(header_chars.png)
  var %i = 1
  while ($ccat(%i)) {
    did -a ns_chars 3 $cname(%i)
    inc %i
  }
  did -c ns_chars 3 1
  set -u3600 %ns.chars.page 0
  cfill
}
alias -l cfill {
  var %cat = $did(ns_chars,3).sel, %first = $cfirst(%cat), %last = $clast(%cat), %page = %ns.chars.page, %i = 0, %code
  while (%i < 60) {
    %code = $calc(%first + %page * 60 + %i)
    if (%code <= %last) {
      did -ra ns_chars $calc(100 + %i) $chr(%code)
      did -e ns_chars $calc(100 + %i)
    }
    else {
      did -ra ns_chars $calc(100 + %i) $chr(160)
      did -b ns_chars $calc(100 + %i)
    }
    inc %i
  }
  var %pages = $int($calc((%last - %first) / 60 + 1))
  did -ra ns_chars 6 page $calc(%page + 1) of %pages
}
on *:DIALOG:ns_chars:sclick:3:{
  set -u3600 %ns.chars.page 0
  cfill
}
on *:DIALOG:ns_chars:sclick:4:{
  if (%ns.chars.page > 0) {
    set -u3600 %ns.chars.page $calc(%ns.chars.page - 1)
    cfill
  }
}
on *:DIALOG:ns_chars:sclick:5:{
  var %cat = $did(ns_chars,3).sel
  if ($calc($cfirst(%cat) + (%ns.chars.page + 1) * 60) <= $clast(%cat)) {
    set -u3600 %ns.chars.page $calc(%ns.chars.page + 1)
    cfill
  }
}
on *:DIALOG:ns_chars:sclick:100-159:{
  var %cat = $did(ns_chars,3).sel, %code = $calc($cfirst(%cat) + %ns.chars.page * 60 + $did - 100)
  if ($did(ns_chars,7).state) clipboard $chr(%code)
  else editbox -a $editbox($active) $+ $chr(%code)
  did -ra ns_chars 8 U+ $+ $base(%code,10,16,4) $+ $chr(32) $+ $chr(40) $+ code %code $+ $chr(41)
}

; ---------------------------------------------------------------- hotkeys (F-keys)
alias ns.fk.keys return F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 sF1 sF2 sF3 sF4 sF5 sF6 sF7 sF8 sF9 sF10 sF11 sF12 cF1 cF2 cF3 cF4 cF5 cF6 cF7 cF8 cF9 cF10 cF11 cF12
alias ns.fk.default {
  var %k = $1
  if (%k == F1) return neonhelp
  if (%k == F2) return neon dash
  if (%k == F3) return neon themes
  if (%k == F4) return neon fx
  if (%k == F5) return clear
  if (%k == F6) return neon away
  if (%k == F7) return neon mute
  if (%k == F8) return neon kb
  if (%k == F9) return neon users
  if (%k == F11) return neon chars
  if (%k == F12) return neon options
  return $null
}
alias ns.fk.get {
  var %v = $readini($ns.ini,n,fkeys,$1)
  if (%v == $null) return $ns.fk.default($1)
  if (%v == -) return $null
  return %v
}
; executed by the F-key aliases in neon_alias.mrc;  $1 = key name, $2- = selected nick (if any)
alias ns.fk.run {
  var %c = $ns.fk.get($1)
  if (%c == $null) return
  %c = $replace(%c,<nick>,$2,<chan>,$chan)
  .timer -do 1 0 %c
}
alias neon.hotkeys ns.dlg ns_fk ns_fk
dialog ns_fk {
  title "Hotkeys"
  size -1 -1 236 170
  option dbu
  icon 1, 0 0 236 30, $mircexe, 0, noborder
  text "Pick a key, type the command it should run (use <nick> for the selected nickname and <chan> for the current channel).", 2, 6 34 224 18
  list 3, 6 54 90 98, size vsbar
  text "Runs:", 4, 102 56 40 9
  edit "", 5, 102 66 128 11, autohs
  button "Set", 6, 102 84 40 13, default
  button "Clear", 7, 146 84 40 13
  button "Defaults", 8, 190 84 40 13
  text "Key names: F2 = F2, sF2 = Shift+F2, cF2 = Ctrl+F2.", 9, 102 106 128 18
  button "Close", 10, 182 152 48 13, ok cancel
}
alias -l fklabel {
  var %k = $1, %n = $left(%k,1)
  if (%n == s) return Shift+ $+ $mid(%k,2)
  if (%n == c) return Ctrl+ $+ $mid(%k,2)
  return %k
}
alias -l fkfill {
  var %i = 1, %k, %sel = $did(ns_fk,3).sel, %cmd
  did -r ns_fk 3
  while ($gettok($ns.fk.keys,%i,32)) {
    %k = $v1
    %cmd = $ns.fk.get(%k)
    did -a ns_fk 3 $fklabel(%k) $iif(%cmd,- %cmd)
    inc %i
  }
  if (%sel) did -c ns_fk 3 %sel
}
on *:DIALOG:ns_fk:init:*:{
  did -g ns_fk 1 $ns.asset(header_hotkeys.png)
  fkfill
  did -c ns_fk 3 1
  did -ra ns_fk 5 $ns.fk.get(F1)
}
on *:DIALOG:ns_fk:sclick:3:{ did -ra ns_fk 5 $ns.fk.get($gettok($ns.fk.keys,$did(ns_fk,3).sel,32)) }
on *:DIALOG:ns_fk:sclick:6:{
  var %k = $gettok($ns.fk.keys,$did(ns_fk,3).sel,32), %t = $did(ns_fk,5).text
  if (!%k) return
  ns.set fkeys %k $iif(%t,%t,-)
  fkfill
}
on *:DIALOG:ns_fk:sclick:7:{
  var %k = $gettok($ns.fk.keys,$did(ns_fk,3).sel,32)
  if (!%k) return
  ns.set fkeys %k -
  did -r ns_fk 5
  fkfill
}
on *:DIALOG:ns_fk:sclick:8:{
  remini $qt($ns.ini) fkeys
  fkfill
  did -ra ns_fk 5 $ns.fk.get($gettok($ns.fk.keys,$did(ns_fk,3).sel,32))
}

; ---------------------------------------------------------------- kick & ban (rank aware)
alias neon.kb {
  var %c = $iif($1,$1,$active)
  set -u60 %ns.kb.chan $iif($ns.ischan(%c),%c,$null)
  set -u60 %ns.kb.nick $2
  ns.dlg ns_kb ns_kb
}
dialog ns_kb {
  title "Kick & Ban"
  size -1 -1 264 206
  option dbu
  icon 1, 0 0 264 30, $mircexe, 0, noborder
  text "Channel:", 2, 6 37 34 9
  combo 3, 42 35 100 80, drop
  list 4, 6 50 126 112, size extsel
  text "Reason:", 5, 138 52 40 9
  combo 6, 138 62 120 80, drop edit
  text "Ban type:", 7, 138 80 40 9
  combo 8, 138 90 120 100, drop
  text "", 9, 138 106 120 9
  text "", 10, 138 118 120 26
  button "Kick", 11, 138 150 36 13
  button "Ban", 12, 178 150 36 13
  button "Kick + ban", 13, 218 150 40 13
  text "Give:", 14, 6 170 20 9
  button "", 20, 28 168 22 12
  button "", 21, 52 168 22 12
  button "", 22, 76 168 22 12
  button "", 23, 100 168 22 12
  button "", 24, 124 168 22 12
  text "Take:", 15, 6 186 20 9
  button "", 25, 28 184 22 12
  button "", 26, 52 184 22 12
  button "", 27, 76 184 22 12
  button "", 28, 100 184 22 12
  button "", 29, 124 184 22 12
  button "Close", 16, 210 186 48 13, ok cancel
}
on *:DIALOG:ns_kb:init:*:{
  did -g ns_kb 1 $ns.asset(header_kb.png)
  var %i = 1, %n = $chan(0), %sel = 0, %f = $ns.msg.file(kick)
  while (%i <= %n) {
    did -a ns_kb 3 $chan(%i)
    if ($chan(%i) == %ns.kb.chan) %sel = %i
    inc %i
  }
  if (!%sel) && (%n) %sel = 1
  if (%sel) did -c ns_kb 3 %sel
  %i = 1
  while (%i <= $lines(%f)) {
    did -a ns_kb 6 $read(%f,n,%i)
    inc %i
  }
  %i = 0
  while (%i <= 9) {
    did -a ns_kb 8 %i $+ $chr(32) $+ $gettok(*!user@host *!*user@host *!*@host *!*user@*.host *!*@*.host nick!user@host nick!*user@host nick!*@host nick!*user@*.host nick!*@*.host,$calc(%i + 1),32)
    inc %i
  }
  did -c ns_kb 8 $calc($ns.get(kb,bantype,2) + 1)
  kbnicks
  kbpriv
}
; fill the nick list with rank prefixes
alias -l kbnicks {
  var %c = $did(ns_kb,3).text, %i = 1, %n = $nick(%c,0)
  did -r ns_kb 4
  while (%i <= %n) {
    did -a ns_kb 4 $nick(%c,%i).pnick
    if (%ns.kb.nick) && ($nick(%c,%i) == %ns.kb.nick) did -c ns_kb 4 %i
    inc %i
  }
  kbinfo
}
; the privilege buttons follow the server's PREFIX: label = +/- prefix char, hidden when unsupported
alias -l kbpriv {
  var %c = $did(ns_kb,3).text, %m = $ns.rk.modes, %i = 1, %l, %ch, %g, %t
  while (%i <= 5) {
    %l = $mid(qaohv,%i,1)
    %ch = $ns.rk.char(%l)
    %g = $calc(19 + %i)
    %t = $calc(24 + %i)
    if ($pos(%m,%l)) {
      did -ra ns_kb %g + $+ $ns.esc(%ch)
      did -ra ns_kb %t - $+ $ns.esc(%ch)
      did -v ns_kb %g
      did -v ns_kb %t
      if ($ns.rk.cangive(%c,%l)) did -e ns_kb %g
      else did -b ns_kb %g
      if ($ns.rk.cangive(%c,%l)) did -e ns_kb %t
      else did -b ns_kb %t
    }
    else {
      did -h ns_kb %g
      did -h ns_kb %t
    }
    inc %i
  }
}
alias -l kbinfo {
  var %c = $did(ns_kb,3).text, %s = $did(ns_kb,4).sel, %nk, %t = $did(ns_kb,8).sel, %addr, %note
  if (!%s) {
    did -ra ns_kb 9 $chr(160)
    did -ra ns_kb 10 Select one or more nicknames.
    return
  }
  %nk = $nick(%c,%s)
  %addr = $address(%nk,$calc(%t - 1))
  if (!%addr) %addr = %nk $+ !?@? (address not known yet - try /who %c $+ )
  did -ra ns_kb 9 %addr
  %note = $iif($ns.rk.cankick(%c),You can kick and ban here.,You need halfop or higher in %c $+ .)
  if ($ns.rk.outranks(%c,%nk,$me)) %note = %nk outranks you ( $+ $ns.rk.name($ns.rk.of(%c,%nk)) $+ ) - the server will refuse.
  did -ra ns_kb 10 %note
}
on *:DIALOG:ns_kb:sclick:3:{
  kbnicks
  kbpriv
}
on *:DIALOG:ns_kb:sclick:4:{ kbinfo }
on *:DIALOG:ns_kb:sclick:8:{
  ns.set kb bantype $calc($did(ns_kb,8).sel - 1)
  kbinfo
}
; run kick / ban / kickban on every selected nick, skipping anyone who outranks me
alias -l kbdo {
  var %c = $did(ns_kb,3).text, %reason = $did(ns_kb,6).text, %t = $calc($did(ns_kb,8).sel - 1), %sels = $ns.did.sels(ns_kb,4), %k = 1, %nk, %done = 0
  if (!%c) return
  if (!$ns.rk.cankick(%c)) {
    ns.err you need halfop or higher in %c
    return
  }
  if (%reason == $null) %reason = $ns.msg(kick)
  while ($gettok(%sels,%k,32)) {
    %nk = $nick(%c,$v1)
    if ($ns.rk.outranks(%c,%nk,$me)) ns.err skipped %nk - outranks you.
    elseif (%nk == $me) ns.err skipped yourself.
    else {
      if ($1 == kick) kick %c %nk %reason
      elseif ($1 == ban) ban %c %nk %t
      else ban -k %c %nk %t %reason
      inc %done
    }
    inc %k
  }
  if (!%done) ns.err nothing selected.
}
on *:DIALOG:ns_kb:sclick:11:{ kbdo kick }
on *:DIALOG:ns_kb:sclick:12:{ kbdo ban }
on *:DIALOG:ns_kb:sclick:13:{ kbdo kickban }
; privileges: ids 20-24 give (q a o h v), 25-29 take
on *:DIALOG:ns_kb:sclick:20-29:{
  var %c = $did(ns_kb,3).text, %id = $did, %sels = $ns.did.sels(ns_kb,4), %k = 1, %l, %sign
  %l = $mid(qaohv,$iif(%id <= 24,$calc(%id - 19),$calc(%id - 24)),1)
  %sign = $iif(%id <= 24,+,-)
  while ($gettok(%sels,%k,32)) {
    mode %c $+(%sign,%l) $nick(%c,$v1)
    inc %k
  }
}

; ---------------------------------------------------------------- clone scanner
; /neon clones [#channel]  - groups people by host and shows everyone's rank
alias neon.clones {
  var %c = $iif($1,$1,$active)
  if (!$ns.ischan(%c)) {
    ns.err usage: /neon clones [#channel]
    return
  }
  if (!$chan(%c).ial) {
    ns.say fetching addresses for %c ...
    who %c
    .timer.nsclones -o 1 4 ns.clones.run %c
    return
  }
  ns.clones.run %c
}
alias ns.clones.run {
  var %c = $1, %w = @Clones, %i = 1, %n = $nick(%c,0), %h, %nk, %k, %groups = 0, %line
  if ($hget(ns.clone)) hfree ns.clone
  hmake ns.clone 100
  while (%i <= %n) {
    %nk = $nick(%c,%i)
    %h = $gettok($address(%nk,2),2,64)
    if (%h) hadd -m ns.clone %h $hget(ns.clone,%h) $nick(%c,%i).pnick
    inc %i
  }
  if ($window(%w)) window -c %w
  window -Cz %w 140 100 640 340
  titlebar %w Clone scanner - %c
  echo -c info %w $+($ns.cc($ns.get(theme,accent,13)),$chr(2),Clone scanner,$chr(2),$ns.o,$chr(32),$ns.ec(dim),- %c $+ $chr(44) %n users,$ns.o)
  echo -c info %w $chr(160)
  %i = 1
  while ($hget(ns.clone,%i).item) {
    %h = $v1
    %line = $hget(ns.clone,%h)
    if ($numtok(%line,32) >= 2) {
      inc %groups
      echo -c info %w $+($ns.ec(kick),$chr(2),$numtok(%line,32),x,$chr(2),$ns.o,$chr(32),$ns.ec(topic),%h,$ns.o)
      %k = 1
      while ($gettok(%line,%k,32)) {
        %nk = $v1
        echo -c info %w $+($chr(32),$chr(32),$chr(32),$ns.rk.glyph($left(%nk,1)),$ns.o) $+ $ns.ec(value) $+ $iif($pos($ns.rk.chars,$left(%nk,1)),$mid(%nk,2),%nk) $+ $ns.o
        inc %k
      }
    }
    inc %i
  }
  if (!%groups) echo -c info %w $+($ns.ec(join),No clones found in %c $+ . All hosts are unique.,$ns.o)
  ns.say clone scan of %c done: %groups group(s).
}
