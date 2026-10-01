; ============================================================================
;  NeonScript 2026  ::  aliases and popup-menu editor     /neon aliases
;
;  Your own aliases (typed commands) and your own right-click / menubar items, kept in usercode.ini and
;  written out as two ordinary script files, user_alias.mrc and user_menu.mrc, which mIRC loads like any other.
;  Nothing here runs by itself - these are things YOU defined, and what they do is exactly what you typed.
;
;  Guard rails: alias names are checked (letters, digits and . _ -, not already an alias or command, not
;  ns.* or neon*), braces must balance, and a menu label cannot contain a colon.
; ============================================================================

alias ns.usr.ini return $+($scriptdir,usercode.ini)
alias ns.usr.afile return $+($scriptdir,user_alias.mrc)
alias ns.usr.mfile return $+($scriptdir,user_menu.mrc)
alias ns.usr.rd return $readini($ns.usr.ini,n,$1,$2)
alias ns.usr.wr {
  if ($3- == $null) writeini -nz $qt($ns.usr.ini) $1 $2
  else writeini -n $qt($ns.usr.ini) $1 $2 $3-
}
; names of mIRC's own commands an alias must never replace
alias ns.usr.reserved return msg notice me describe say join part quit query kick ban mode topic nick away whois whowas who list names ctcp ctcpreply dcc chat send get server connect disconnect exit run load unload reload script echo set unset var inc dec if elseif else while return halt haltdef break continue timer write read remove rename copy mkdir rmdir window dialog did hadd hdel hmake hfree hload hsave hinc hdec ignore notify unnotify invite flood raw perform sock sockopen sockwrite sockclose signal scid scon beep splay sound speak url browse clipboard editbox input color font tray flash log logview finger ping ver time raw uwho uotify ruser auser ulist rlevel guser google alias menu on ctcp events sreq fsend fserve
alias ns.usr.names {
  var %i = 1, %o, %s
  while ($ini($ns.usr.ini,%i)) {
    %s = $v1
    inc %i
    if ($left(%s,2) == a:) %o = %o $mid(%s,3)
  }
  return %o
}
alias ns.usr.mids {
  var %i = 1, %o, %s
  while ($ini($ns.usr.ini,%i)) {
    %s = $v1
    inc %i
    if ($left(%s,2) == m:) %o = %o $mid(%s,3)
  }
  return %o
}
alias ns.usr.menutypes return nicklist channel query status menubar
; is this a usable new alias name?  returns "" when fine, else the reason
alias ns.usr.checkname {
  var %n = $1
  if (%n == $null) return give it a name
  if (!$regex(ns.un,%n,/^[A-Za-z][A-Za-z0-9_.-]*$/)) || ($len(%n) > 31) return use letters, digits and . _ - only (it must start with a letter, 31 characters at most)
  if ($left(%n,3) == ns.) || ($left(%n,4) == neon) return that name is reserved for NeonScript
  if ($istok($ns.usr.reserved,$lower(%n),32)) return $qt(%n) is a built-in mIRC command
  if (!$istok($ns.usr.names,%n,32)) && ($isalias(%n)) return an alias called %n already exists in another script
  return $null
}
; { and } must balance in the body
alias ns.usr.balanced {
  var %t = $1-, %o = $regsubex(%t,/[^\x7B]/g,), %c = $regsubex(%t,/[^\x7D]/g,)
  return $iif($len(%o) == $len(%c),1,0)
}

; ---------------------------------------------------------------- writing the two script files
alias ns.usr.build {
  var %af = $ns.usr.afile, %mf = $ns.usr.mfile, %i = 1, %n, %k, %l, %m, %t, %mt, %any = 0
  if ($exists(%af)) .remove $qt(%af)
  if ($exists(%mf)) .remove $qt(%mf)
  ; ---- aliases
  while ($gettok($ns.usr.names,%i,32) != $null) {
    %n = $v1
    inc %i
    if (!%any) write $qt(%af) ; Written by NeonScript's alias editor (/neon aliases) - edit them there, changes here are overwritten.
    %any = 1
    if ($ns.usr.rd($+(a:,%n),desc) != $null) write $qt(%af) $+(;,$chr(32),$ns.usr.rd($+(a:,%n),desc))
    write $qt(%af) $+(alias,$chr(32),%n,$chr(32),$chr(123))
    %k = 1
    %l = $ns.usr.rd($+(a:,%n),l1)
    while (%l != $null) {
      write $qt(%af) $+($chr(32),$chr(32),%l)
      inc %k
      %l = $ns.usr.rd($+(a:,%n),$+(l,%k))
    }
    write $qt(%af) $chr(125)
  }
  ; ---- menu items, grouped by menu; "Fun>Dice" becomes  Fun  /  .Dice
  %any = 0
  %t = 1
  while ($gettok($ns.usr.menutypes,%t,32) != $null) {
    %mt = $v1
    inc %t
    %i = 1
    var %lines = 0, %hdr1, %hdr2
    while ($gettok($ns.usr.mids,%i,32) != $null) {
      %m = $v1
      inc %i
      if ($ns.usr.rd($+(m:,%m),menu) != %mt) continue
      if (!%lines) {
        if (!%any) write $qt(%mf) ; Written by NeonScript's alias editor (/neon aliases) - edit your menu items there, changes here are overwritten.
        %any = 1
        write $qt(%mf) $+(menu,$chr(32),%mt,$chr(32),$chr(123))
      }
      inc %lines
      ns.usr.menuline %m
    }
    if (%lines) write $qt(%mf) $chr(125)
  }
}
; one menu item as one or more lines (submenu headers are written the first time they appear)
alias ns.usr.menuline {
  var %m = $1, %lab = $ns.usr.rd($+(m:,%m),label), %cmd = $ns.usr.rd($+(m:,%m),cmd), %mf = $ns.usr.mfile, %a, %b
  %a = $gettok(%lab,1,62)
  %b = $gettok(%lab,2,62)
  ; a separator above an item inside a submenu is ".-", at the top level just "-"
  if ($ns.usr.rd($+(m:,%m),sep) == 1) && (%b == $null) write $qt(%mf) $chr(45)
  if (%b == $null) {
    write $qt(%mf) $+($chr(32),$chr(32),%a,:,%cmd)
    return
  }
  if ($hget(ns.usrhdr,$+(%mf,|,%a)) != $ns.usr.gen) {
    write $qt(%mf) $+($chr(32),$chr(32),%a)
    hadd -m ns.usrhdr $+(%mf,|,%a) $ns.usr.gen
  }
  if ($ns.usr.rd($+(m:,%m),sep) == 1) write $qt(%mf) $+(.,-)
  write $qt(%mf) $+(.,%b,:,%cmd)
}
alias ns.usr.gen return %ns.usr.gen
; write the files and (re)load them
alias ns.usr.apply {
  inc %ns.usr.gen
  ns.usr.build
  ns.usr.loadone $ns.usr.afile
  ns.usr.loadone $ns.usr.mfile
}
alias ns.usr.loadone {
  var %f = $1
  if ($exists(%f)) {
    if ($ns.isloaded(%f)) .reload -rs $qt(%f)
    else .load -rs $qt(%f)
  }
  elseif ($ns.isloaded(%f)) .unload -rs $qt(%f)
}
on *:SIGNAL:ns.boot:{
  var %f
  %f = $ns.usr.afile
  if ($exists(%f)) && (!$ns.isloaded(%f)) .load -rs $qt(%f)
  %f = $ns.usr.mfile
  if ($exists(%f)) && (!$ns.isloaded(%f)) .load -rs $qt(%f)
}

; ---------------------------------------------------------------- the editor
alias neon.aliases ns.dlg ns_usr ns_usr
dialog ns_usr {
  title "Aliases and Popup Menus"
  size -1 -1 372 256
  option dbu
  icon 1, 0 0 372 30, $mircexe, 0, noborder
  tab "Aliases", 10, 6 34 360 196
  tab "Menu items", 11
  tab "Help", 12

  ; ---- aliases
  list 21, 14 52 100 150, size vsbar tab 10
  text "Name:", 22, 122 54 24 9, tab 10
  edit "", 23, 148 52 100 11, autohs tab 10
  text "(what you type after the slash, e.g. hi  ->  /hi)", 24, 252 54 110 18, tab 10
  text "Note:", 25, 122 70 24 9, tab 10
  edit "", 26, 148 68 214 11, autohs tab 10
  text "Commands, one per line.  $1 is the first word you type after the alias, $1- everything:", 27, 122 84 240 9, tab 10
  edit "", 28, 122 94 240 98, multi return vsbar tab 10
  button "New", 29, 14 206 32 12, tab 10
  button "Delete", 30, 50 206 36 12, tab 10
  button "Save", 31, 122 206 44 13, tab 10
  button "Try it...", 32, 170 206 44 13, tab 10
  text "", 33, 220 208 142 18, tab 10

  ; ---- menu items
  list 41, 14 52 120 150, size vsbar tab 11
  text "Menu:", 42, 142 54 24 9, tab 11
  combo 43, 168 52 80 70, drop tab 11
  text "Label:", 44, 142 70 24 9, tab 11
  edit "", 45, 168 68 194 11, autohs tab 11
  text "Use > for a submenu:  Fun>Roll a die", 46, 168 81 194 9, tab 11
  text "Command:", 47, 142 96 30 9, tab 11
  edit "", 48, 174 94 188 11, autohs tab 11
  text "In the nick-list and query menus $1 is the nick you clicked; in a channel menu $chan is the channel.", 49, 142 109 220 18, tab 11
  check "Draw a separator line above this item", 50, 142 130 200 9, tab 11
  button "New", 51, 14 206 32 12, tab 11
  button "Delete", 52, 50 206 36 12, tab 11
  button "Up", 53, 90 206 22 12, tab 11
  button "Down", 54, 116 206 26 12, tab 11
  button "Save", 55, 168 206 44 13, tab 11
  text "", 56, 220 208 142 18, tab 11

  ; ---- help
  edit "", 60, 14 52 348 168, read multi vsbar tab 12

  button "Close", 99, 318 236 48 13, ok cancel
}
on *:DIALOG:ns_usr:init:*:{
  did -g ns_usr 1 $ns.asset(header_alias.png)
  var %i = 1
  while ($gettok($ns.usr.menutypes,%i,32) != $null) {
    did -a ns_usr 43 $v1
    inc %i
  }
  did -c ns_usr 43 1
  ns.ml.new
  ns.ml.add Aliases are your own commands.  An alias called hi that contains   msg $chan hello $1   turns /hi Nova into a message "hello Nova".
  ns.ml.add $chr(160)
  ns.ml.add Menu items add entries to the right-click menus (nick list, channel, query, status) or the menu bar.
  ns.ml.add $chr(160)
  ns.ml.add Everything you save here is written to two plain script files next to NeonScript's: user_alias.mrc and user_menu.mrc. mIRC loads them like any other script, so they keep working even without this editor. Edit things here, not in those files - the editor rewrites them on every Save.
  ns.ml.add $chr(160)
  ns.ml.add NeonScript refuses alias names that are already commands or aliases, and bodies whose { } do not match. Beyond that, what an alias does is up to you - it runs with your permissions, so only paste code you understand.
  ns.ml.set ns_usr 60
  afill
  mfill
  if ($did(ns_usr,21).lines) apick 1
  else ablank
  if ($did(ns_usr,41).lines) mpick 1
  else mblank
}
; ---- aliases tab
alias -l afill {
  var %i = 1
  did -r ns_usr 21
  while ($gettok($ns.usr.names,%i,32) != $null) {
    did -a ns_usr 21 $v1
    inc %i
  }
}
alias -l ablank {
  did -r ns_usr 23
  did -r ns_usr 26
  did -r ns_usr 28
  did -ra ns_usr 33 $chr(160)
}
alias -l apick {
  var %n = $gettok($ns.usr.names,$1,32), %k = 1, %l
  if (!%n) return
  did -c ns_usr 21 $1
  did -ra ns_usr 23 %n
  did -ra ns_usr 26 $ns.usr.rd($+(a:,%n),desc)
  ns.ml.new
  %l = $ns.usr.rd($+(a:,%n),l1)
  while (%l != $null) {
    ns.ml.add %l
    inc %k
    %l = $ns.usr.rd($+(a:,%n),$+(l,%k))
  }
  ns.ml.set ns_usr 28
}
on *:DIALOG:ns_usr:sclick:21:{ if ($did(ns_usr,21).sel) apick $did(ns_usr,21).sel }
on *:DIALOG:ns_usr:sclick:29:{
  did -r ns_usr 21
  afill
  ablank
  did -ra ns_usr 33 New alias - name it, type its commands, press Save.
}
on *:DIALOG:ns_usr:sclick:30:{
  var %n = $gettok($ns.usr.names,$did(ns_usr,21).sel,32)
  if (!%n) return
  remini $qt($ns.usr.ini) $+(a:,%n)
  ns.usr.apply
  afill
  ablank
  did -ra ns_usr 33 Deleted.
}
on *:DIALOG:ns_usr:sclick:31:{
  var %n = $ns.trim($did(ns_usr,23).text), %why = $ns.usr.checkname(%n), %k = 1, %cnt = 0, %line, %body
  if (%why) {
    did -ra ns_usr 33 %why
    return
  }
  while (%k <= $did(ns_usr,28).lines) {
    %line = $did(ns_usr,28,%k)
    inc %k
    if (%line == $null) continue
    %body = %body $+ %line
    inc %cnt
  }
  if (!%cnt) {
    did -ra ns_usr 33 Type at least one command.
    return
  }
  if (!$ns.usr.balanced(%body)) {
    did -ra ns_usr 33 The { and } in the commands do not match.
    return
  }
  if ($ini($ns.usr.ini,$+(a:,%n))) remini $qt($ns.usr.ini) $+(a:,%n)
  ns.usr.wr $+(a:,%n) desc $did(ns_usr,26).text
  %k = 1
  %cnt = 0
  while (%k <= $did(ns_usr,28).lines) {
    %line = $did(ns_usr,28,%k)
    inc %k
    if (%line == $null) continue
    inc %cnt
    ns.usr.wr $+(a:,%n) $+(l,%cnt) %line
  }
  ns.usr.apply
  afill
  did -c ns_usr 21 $findtok($ns.usr.names,%n,1,32)
  did -ra ns_usr 33 Saved - / %n is ready.
}
on *:DIALOG:ns_usr:sclick:32:{ ns.later ns.usr.try }
alias ns.usr.try {
  if (!$dialog(ns_usr)) return
  var %n = $ns.trim($did(ns_usr,23).text), %a
  if (!$istok($ns.usr.names,%n,32)) {
    did -ra ns_usr 33 Save it first.
    return
  }
  %a = $input(Run /%n with what after it? (leave empty for nothing),eo,Try an alias)
  .timer -o 1 0 $+(/,%n) %a
}

; ---- menu items tab
alias -l mfill {
  var %i = 1, %m
  did -r ns_usr 41
  while ($gettok($ns.usr.mids,%i,32) != $null) {
    %m = $v1
    inc %i
    did -a ns_usr 41 $+($ns.usr.rd($+(m:,%m),menu),$chr(32),$chr(183),$chr(32),$ns.usr.rd($+(m:,%m),label))
  }
}
alias -l mblank {
  did -r ns_usr 45
  did -r ns_usr 48
  did -u ns_usr 50
  did -ra ns_usr 56 $chr(160)
}
alias -l mpick {
  var %m = $gettok($ns.usr.mids,$1,32), %t
  if (!%m) return
  did -c ns_usr 41 $1
  %t = $findtok($ns.usr.menutypes,$ns.usr.rd($+(m:,%m),menu),1,32)
  did -c ns_usr 43 $iif(%t,%t,1)
  did -ra ns_usr 45 $ns.usr.rd($+(m:,%m),label)
  did -ra ns_usr 48 $ns.usr.rd($+(m:,%m),cmd)
  did $iif($ns.usr.rd($+(m:,%m),sep) == 1,-c,-u) ns_usr 50
}
on *:DIALOG:ns_usr:sclick:41:{ if ($did(ns_usr,41).sel) mpick $did(ns_usr,41).sel }
on *:DIALOG:ns_usr:sclick:51:{
  set -u600 %ns.usr.newm 1
  mfill
  mblank
  did -ra ns_usr 56 New item - choose the menu, give it a label and a command, press Save.
}
on *:DIALOG:ns_usr:sclick:52:{
  var %m = $gettok($ns.usr.mids,$did(ns_usr,41).sel,32)
  if (!%m) return
  remini $qt($ns.usr.ini) $+(m:,%m)
  ns.usr.apply
  mfill
  mblank
  did -ra ns_usr 56 Deleted.
}
; move an item up or down by swapping its contents with its neighbour
on *:DIALOG:ns_usr:sclick:53,54:{
  var %sel = $did(ns_usr,41).sel, %other = $iif($did == 53,$calc(%sel - 1),$calc(%sel + 1)), %a = $gettok($ns.usr.mids,%sel,32), %b = $gettok($ns.usr.mids,%other,32), %f, %k = 1, %va, %vb
  if (!%a) || (!%b) return
  while ($gettok(menu label cmd sep,%k,32) != $null) {
    %f = $v1
    inc %k
    %va = $ns.usr.rd($+(m:,%a),%f)
    %vb = $ns.usr.rd($+(m:,%b),%f)
    ns.usr.wr $+(m:,%a) %f %vb
    ns.usr.wr $+(m:,%b) %f %va
  }
  ns.usr.apply
  mfill
  did -c ns_usr 41 %other
}
on *:DIALOG:ns_usr:sclick:55:{
  var %lab = $ns.trim($did(ns_usr,45).text), %cmd = $ns.trim($did(ns_usr,48).text), %m = $gettok($ns.usr.mids,$did(ns_usr,41).sel,32), %mt = $did(ns_usr,43).text
  if (%ns.usr.newm) %m = $null
  unset %ns.usr.newm
  if (%lab == $null) || (%cmd == $null) {
    did -ra ns_usr 56 A menu item needs a label and a command.
    return
  }
  if ($pos(%lab,:)) {
    did -ra ns_usr 56 The label cannot contain a colon.
    return
  }
  if (!%m) {
    var %n = 1
    while ($ini($ns.usr.ini,$+(m:,%n))) inc %n
    %m = %n
  }
  ns.usr.wr $+(m:,%m) menu %mt
  ns.usr.wr $+(m:,%m) label %lab
  ns.usr.wr $+(m:,%m) cmd %cmd
  ns.usr.wr $+(m:,%m) sep $did(ns_usr,50).state
  ns.usr.apply
  mfill
  did -c ns_usr 41 $findtok($ns.usr.mids,%m,1,32)
  did -ra ns_usr 56 Saved - it appears in the %mt menu.
}
