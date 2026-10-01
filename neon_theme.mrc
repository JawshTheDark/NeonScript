; ============================================================================
;  NeonScript 2026  ::  themes
;  Colour schemes (data\themes.ini), toolbar/switchbar backgrounds, the
;  Theme Gallery dialog and quick-switch menus.
; ============================================================================

alias ns.theme.file return $ns.data(themes.ini)
alias ns.theme.ids return $replace($readini($ns.theme.file,n,themes,order),$chr(44),$chr(32))
; your own themes (the theme editor) live in themes_user.ini with ids u_<name>
alias ns.theme.fileof return $iif($left($1,2) == u_,$+($scriptdir,themes_user.ini),$ns.theme.file)
alias ns.theme.name return $readini($ns.theme.fileof($1),n,$1,name)
alias ns.theme.desc return $readini($ns.theme.fileof($1),n,$1,desc)
alias ns.theme.mode return $readini($ns.theme.fileof($1),n,$1,mode)
alias ns.theme.current return $ns.get(theme,current,neonnight)
; names of mIRC's 31 colour items, in Colors-dialog order
alias ns.theme.items return Background,Action text,Ctcp text,Highlight text,Info text,Info2 text,Invite text,Join text,Kick text,Mode text,Nick text,Normal text,Notice text,Notify text,Other text,Own text,Part text,Quit text,Topic text,Wallops text,Whois text,Editbox,Editbox text,Listbox,Listbox text,Gray text,Title text,Inactive,Treebar,Treebar Text,MDI area

; accent colours as mIRC RGB integers (for picture-window drawing)
alias ns.acc1 return $ns.hex($ns.get(theme,acc1,#ff2e88))
alias ns.acc2 return $ns.hex($ns.get(theme,acc2,#2ee6ff))


; ---------------------------------------------------------------- palette helpers
; $ns.pal(N) -> mIRC RGB integer for palette index N (0-98) - used for drawing
alias ns.xcolors return 470000 472100 474700 324700 004700 00472c 004747 002747 000047 2e0047 470047 47002a 740000 743a00 747400 517400 007400 007449 007474 004074 000074 4b0074 740074 740045 b50000 b56300 b5b500 7db500 00b500 00b571 00b5b5 0063b5 0000b5 7500b5 b500b5 b5006b ff0000 ff8c00 ffff00 b2ff00 00ff00 00ffa0 00ffff 008cff 0000ff a500ff ff00ff ff0098 ff5959 ffb459 ffff71 cfff60 6fff6f 65ffc9 6dffff 59b4ff 5959ff c459ff ff66ff ff59bc ff9c9c ffd39c ffff9c e2ff9c 9cff9c 9cffdb 9cffff 9cd3ff 9c9cff dc9cff ff9cff ff94d3 000000 131313 282828 363636 4d4d4d 656565 818181 9f9f9f bcbcbc e2e2e2 ffffff
alias ns.pal {
  if ($1 < 16) return $color($1)
  var %h = $gettok($ns.xcolors,$calc($1 - 15),32)
  if (!%h) return $rgb(255,255,255)
  return $ns.hex(%h)
}
; RGB integer -> components, and a 0..1 mix of two RGB integers
alias ns.r8 return $calc($1 % 256)
alias ns.g8 return $calc($int($calc($1 / 256)) % 256)
alias ns.b8 return $calc($int($calc($1 / 65536)) % 256)
alias ns.mix {
  var %t = $3, %a = $1, %b = $2
  return $rgb($int($calc($ns.r8(%a) + ($ns.r8(%b) - $ns.r8(%a)) * %t)),$int($calc($ns.g8(%a) + ($ns.g8(%b) - $ns.g8(%a)) * %t)),$int($calc($ns.b8(%a) + ($ns.b8(%b) - $ns.b8(%a)) * %t)))
}

; ---------------------------------------------------------------- apply a theme
alias ns.theme.apply {
  if ($left($1,4) == mts:) {
    ns.mts.apply $mid($1,5)
    return
  }
  var %id = $iif($1,$1,$ns.theme.current), %f
  if ($left(%id,4) == mts:) %id = $ns.get(theme,lastbuiltin,neonnight)
  %f = $ns.theme.fileof(%id)
  var %cols = $readini(%f,n,%id,colors)
  if ($numtok(%cols,44) != 31) {
    ns.err unknown theme $qt(%id)
    return
  }
  var %items = $ns.theme.items, %i = 1
  while (%i <= 31) {
    color $gettok(%items,%i,44) $gettok(%cols,%i,44)
    inc %i
  }
  if ($isalias(ns.mts.off)) && ($ns.get(events,style) == mts) ns.mts.off
  ns.set theme lastbuiltin %id
  ns.set theme current %id
  ns.set theme accent $readini(%f,n,%id,accent)
  ns.set theme acc1 $readini(%f,n,%id,acc1)
  ns.set theme acc2 $readini(%f,n,%id,acc2)
  ns.set theme mode $readini(%f,n,%id,mode)
  ns.theme.storeev %id
  if ($ns.flag(theme,applybg,1)) ns.theme.bg
  signal -n ns.theme %id
  ns.say theme set to $+($chr(2),$ns.theme.name(%id),$chr(2),.)
}

; toolbar + switchbar strip matching the theme's light/dark mode
alias ns.theme.bg {
  var %m = $iif($ns.get(theme,mode,dark) == light,light,dark)
  background -l $qt($ns.asset(bg_ $+ %m $+ .bmp))
  background -h $qt($ns.asset(bg_ $+ %m $+ .bmp))
}
alias ns.theme.bgoff {
  background -lx
  background -hx
}


; ---------------------------------------------------------------- event palette
; Every built-in theme carries an "ev" palette (join, part, kick, per-rank colours ...)
; that NeonScript uses for its own event lines, independent of mIRC's colour scheme.
alias ns.theme.storeev {
  var %id = $1, %f = $ns.theme.fileof($1), %ev = $readini(%f,n,%id,ev), %i = 1, %kv
  while ($gettok(%ev,%i,44)) {
    %kv = $v1
    ns.set theme $+(ev_,$gettok(%kv,1,58)) $gettok(%kv,2,58)
    inc %i
  }
  ns.set theme nickcols $readini(%f,n,%id,nickcols)
}
; $ns.ecn(key) -> palette index; falls back to neon night (dark) / paper (light)
alias ns.ecn {
  var %v = $ns.get(theme,$+(ev_,$1))
  if (%v != $null) return %v
  var %light = $iif($ns.get(theme,mode,dark) == light,1,0)
  var %keys = join part quit kick mode topic nick invite label value dim hi q a o h v
  var %dark = 68 77 85 64 65 81 71 69 94 97 93 54 74 64 68 71 66
  var %lite = 32 34 38 40 29 33 48 45 94 88 93 41 50 40 32 47 41
  var %n = $findtok(%keys,$1,1,32)
  if (!%n) return 14
  return $gettok($iif(%light,%lite,%dark),%n,32)
}
; $ns.ec(key) -> mIRC colour-code string for that palette entry
alias ns.ec return $ns.cc($ns.ecn($1))
; $ns.nickcol(nick) -> a stable colour index for a nickname (hash of the nick)
alias ns.nickcol {
  var %l = $ns.get(theme,nickcols,64 65 66 68 69 70 71 73 74 75 77 80 84 85), %n = $numtok(%l,32)
  return $gettok(%l,$calc($crc($lower($1)) % %n + 1),32)
}

; ---------------------------------------------------------------- boot / commands
alias ns.theme.init {
  if ($ns.get(theme,current) == $null) ns.set theme current neonnight
  ; make sure the accent keys exist even if the user never picked a theme
  if ($ns.get(theme,accent) == $null) {
    var %id = $ns.theme.current, %f = $ns.theme.fileof($ns.theme.current)
    ns.set theme accent $readini(%f,n,%id,accent)
    ns.set theme acc1 $readini(%f,n,%id,acc1)
    ns.set theme acc2 $readini(%f,n,%id,acc2)
    ns.set theme mode $readini(%f,n,%id,mode)
    ns.theme.storeev %id
  }
}
on *:SIGNAL:ns.boot:{ ns.theme.init }
on *:LOAD:{ .timer.nsthinit -o 1 1 ns.theme.init }

alias neon.themes ns.dlg ns_theme ns_theme
; /neon theme <id>   - or with no id, open the gallery
alias neon.theme {
  if ($1 == $null) { neon.themes | return }
  ns.theme.apply $1
}

; ---------------------------------------------------------------- unified theme list
; entries: built-in ids first, then one "mts:<file.mts>" per imported MTS theme
alias ns.theme.entries {
  var %o = $ns.theme.ids $iif($isalias(ns.theme.uids),$ns.theme.uids), %i = 1
  if ($isalias(ns.mts.files)) {
    while ($gettok($ns.mts.files,%i,32)) {
      %o = %o $+(mts:,$v1)
      inc %i
    }
  }
  return %o
}
alias ns.theme.ismts return $iif($left($1,4) == mts:,1,0)
alias ns.theme.ename {
  if ($left($1,4) == mts:) return $+([MTS],$chr(32),$ns.mts.name($mid($1,5)))
  return $ns.theme.name($1)
}

; ---------------------------------------------------------------- quick menu
alias -l tsub {
  if ($1 !isnum) return
  var %id = $gettok($ns.theme.entries,$1,32)
  if (!%id) return
  return $iif(%id == $ns.theme.current,$style(1)) $ns.theme.ename(%id) $+ :ns.theme.apply %id
}
menu @nstb_theme {
  Theme gallery...:neon themes
  Import an MTS theme...:neon mts import
  -
  $submenu($tsub($1))
  -
  Toolbar && switchbar background
  .$iif($ns.flag(theme,applybg,1),$style(1)) Themed strip:ns.set theme applybg 1 | ns.theme.bg
  .$iif(!$ns.flag(theme,applybg,1),$style(1)) System default:ns.set theme applybg 0 | ns.theme.bgoff
}

; ---------------------------------------------------------------- Theme Gallery dialog
dialog ns_theme {
  title "NeonScript Themes"
  size -1 -1 262 198
  option dbu
  list 1, 6 6 82 122, size vsbar
  icon 2, 94 6 162 94, $mircexe, 0, noborder
  text "", 3, 94 104 162 9
  text "", 4, 94 114 162 20
  check "Also theme the toolbar and switchbar", 5, 6 134 140 9
  check "Use the theme's font (MTS themes)", 6, 6 146 140 9
  check "Restyle chat lines too (MTS themes)", 7, 6 158 140 9
  button "Apply", 10, 152 140 50 13, default
  button "Preview", 11, 206 140 50 13
  button "Import MTS...", 12, 152 156 50 13
  button "Close", 13, 206 156 50 13, ok cancel
  button "Theme editor...", 14, 152 174 104 13
}
on *:DIALOG:ns_theme:init:*:{
  tgfill
  if ($ns.flag(theme,applybg,1)) did -c ns_theme 5
  if ($ns.flag(mts,fonts,1)) did -c ns_theme 6
  if ($ns.flag(mts,chat,1)) did -c ns_theme 7
}
alias -l tgfill {
  var %i = 1, %cur = $ns.theme.current, %n
  did -r ns_theme 1
  while ($gettok($ns.theme.entries,%i,32)) {
    did -a ns_theme 1 $ns.theme.ename($v1)
    inc %i
  }
  %n = $findtok($ns.theme.entries,%cur,1,32)
  if (!%n) %n = 1
  did -c ns_theme 1 %n
  tgshow %n
}
on *:SIGNAL:ns.mtschanged:{
  if ($dialog(ns_theme)) tgfill
}
on *:DIALOG:ns_theme:sclick:1:{ tgshow $did(ns_theme,1).sel }
on *:DIALOG:ns_theme:dclick:1:{ tgapply }
on *:DIALOG:ns_theme:sclick:5:{ ns.set theme applybg $did(ns_theme,5).state }
on *:DIALOG:ns_theme:sclick:6:{ ns.set mts fonts $did(ns_theme,6).state }
on *:DIALOG:ns_theme:sclick:7:{ ns.set mts chat $did(ns_theme,7).state }
on *:DIALOG:ns_theme:sclick:10:{ tgapply }
on *:DIALOG:ns_theme:sclick:11:{
  var %id = $gettok($ns.theme.entries,$did(ns_theme,1).sel,32)
  if ($ns.theme.ismts(%id)) ns.mts.preview $mid(%id,5)
}
on *:DIALOG:ns_theme:sclick:12:{ ns.later ns.mts.import }
on *:DIALOG:ns_theme:sclick:14:{ ns.later neon themeedit }
alias -l tgapply {
  var %id = $gettok($ns.theme.entries,$did(ns_theme,1).sel,32)
  if (%id) ns.theme.apply %id
  tgshow $did(ns_theme,1).sel
}
alias -l tgshow {
  var %id = $gettok($ns.theme.entries,$1,32), %act = $iif(%id == $ns.theme.current,$chr(32) $+ $chr(40) $+ active $+ $chr(41))
  if (!%id) return
  if ($ns.theme.ismts(%id)) {
    var %f = $mid(%id,5), %by = $ns.mts.peek(%f,author), %d = $ns.mts.peek(%f,description)
    if (!%d) %d = Classic MTS theme - click Preview to see it rendered.
    if (%by) %d = by %by $+ . %d
    did -g ns_theme 2 $ns.asset(header_themes.png)
    did -ra ns_theme 3 $ns.theme.ename(%id) $+ %act
    did -ra ns_theme 4 %d
    did -e ns_theme 11
    did -e ns_theme 6,7
  }
  elseif ($left(%id,2) == u_) {
    did -g ns_theme 2 $ns.ted.thumb(%id)
    did -ra ns_theme 3 $ns.theme.name(%id) $+ %act
    did -ra ns_theme 4 $ns.theme.desc(%id)
    did -b ns_theme 11
    did -b ns_theme 6,7
  }
  else {
    did -g ns_theme 2 $ns.asset(theme_ $+ %id $+ .png)
    did -ra ns_theme 3 $ns.theme.name(%id) $+ %act
    did -ra ns_theme 4 $ns.theme.desc(%id)
    did -b ns_theme 11
    did -b ns_theme 6,7
  }
}
