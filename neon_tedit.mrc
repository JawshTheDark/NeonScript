; ============================================================================
;  NeonScript 2026  ::  theme editor   /neon themeedit
;  Build your own colour theme: every mIRC colour item and every NeonScript event colour, with a live preview,
;  saved next to the built-in ones (themes_user.ini, ids "u_<name>") and exportable as a classic .mts file.
;  Colours are palette indices 0-98 (mIRC's own 99 colours), which is what mIRC and NeonScript store.
; ============================================================================

alias ns.theme.ufile return $+($scriptdir,themes_user.ini)
alias ns.theme.uids return $replace($readini($ns.theme.ufile,n,themes,order),$chr(44),$chr(32))
alias ns.ted.evkeys return join part quit kick mode topic nick invite label value dim hi q a o h v
; one line per editable item:  "mirc 1 Background" / "ev join Join lines"
alias ns.ted.count return $calc(31 + $numtok($ns.ted.evkeys,32))
alias ns.ted.itemname {
  var %n = $1
  if (%n <= 31) return $gettok($ns.theme.items,%n,44)
  return NeonScript: $gettok($ns.ted.evnames,$calc(%n - 31),44)
}
alias ns.ted.evnames return join lines,part lines,quit lines,kick lines,mode lines,topic lines,nick changes,invites,labels,values,dim text,highlight,owner (~) names,admin (&) names,op (@) names,halfop (%) names,voice (+) names
; the working copy lives in the ns.ted hash:  c<N> = colour index of mIRC item N (1-31), e<N> = index of event key N
alias ns.ted.get return $hget(ns.ted,$1)
alias ns.ted.val {
  var %n = $1
  return $iif(%n <= 31,$ns.ted.get($+(c,%n)),$ns.ted.get($+(e,$calc(%n - 31))))
}
alias ns.ted.setval {
  var %n = $1
  if (%n <= 31) hadd -m ns.ted $+(c,%n) $2
  else hadd -m ns.ted $+(e,$calc(%n - 31)) $2
}
; palette index -> "#rrggbb" and back to RGB
alias ns.ted.hex {
  var %c = $ns.pal($1)
  return $+(#,$base($ns.r8(%c),10,16,2),$base($ns.g8(%c),10,16,2),$base($ns.b8(%c),10,16,2))
}
; the palette entry closest to a colour (RGB integer)
alias ns.ted.nearest {
  var %c = $1, %i = 0, %best = 0, %bd = 999999, %p, %d
  while (%i <= 98) {
    %p = $ns.pal(%i)
    %d = $calc(($ns.r8(%c) - $ns.r8(%p)) ^ 2 + ($ns.g8(%c) - $ns.g8(%p)) ^ 2 + ($ns.b8(%c) - $ns.b8(%p)) ^ 2)
    if (%d < %bd) {
      %bd = %d
      %best = %i
    }
    inc %i
  }
  return %best
}
; load a theme (built-in or "u_...") into the working copy
alias ns.ted.load {
  var %id = $1, %f = $ns.theme.fileof(%id), %cols = $readini(%f,n,%id,colors), %i = 1, %ev = $readini(%f,n,%id,ev), %k
  if ($hget(ns.ted)) hfree ns.ted
  hmake ns.ted 100
  while (%i <= 31) {
    hadd ns.ted $+(c,%i) $iif($gettok(%cols,%i,44) isnum,$gettok(%cols,%i,44),0)
    inc %i
  }
  %i = 1
  while ($gettok($ns.ted.evkeys,%i,32) != $null) {
    %k = $v1
    hadd ns.ted $+(e,%i) $iif($ns.ted.evof(%ev,%k) != $null,$ns.ted.evof(%ev,%k),$ns.ecn(%k))
    inc %i
  }
  hadd ns.ted name $iif($left(%id,2) == u_,$ns.theme.name(%id),$+($ns.theme.name(%id),$chr(32),copy))
  hadd ns.ted desc $iif($left(%id,2) == u_,$readini(%f,n,%id,desc),Based on $ns.theme.name(%id))
  hadd ns.ted mode $iif($readini(%f,n,%id,mode) != $null,$readini(%f,n,%id,mode),dark)
  hadd ns.ted accent $iif($readini(%f,n,%id,accent) isnum,$readini(%f,n,%id,accent),75)
  hadd ns.ted acc1 $iif($readini(%f,n,%id,acc1) != $null,$readini(%f,n,%id,acc1),#ff2e88)
  hadd ns.ted acc2 $iif($readini(%f,n,%id,acc2) != $null,$readini(%f,n,%id,acc2),#2ee6ff)
  hadd ns.ted nickcols $iif($readini(%f,n,%id,nickcols) != $null,$readini(%f,n,%id,nickcols),64 65 66 68 69 70 71 73 74 75 77 80 84 85)
  hadd ns.ted base %id
}
; "join:68,part:77,..." -> value for one key
alias ns.ted.evof {
  var %kv, %list = $1, %j = 1
  while ($gettok(%list,%j,44) != $null) {
    %kv = $v1
    inc %j
    if ($gettok(%kv,1,58) == $2) return $gettok(%kv,2,58)
  }
  return $null
}
; write the working copy into themes_user.ini under id "u_<slug>"; returns the id
alias ns.ted.save {
  var %name = $ns.trim($ns.ted.get(name)), %slug = $regsubex($lower(%name),/[^a-z0-9]/g,), %id, %i = 1, %cols, %ev, %k, %order
  if (%name == $null) || (%slug == $null) return $null
  %id = $+(u_,%slug)
  while (%i <= 31) {
    %cols = $+(%cols,$iif(%cols,$chr(44)),$ns.ted.get($+(c,%i)))
    inc %i
  }
  %i = 1
  while ($gettok($ns.ted.evkeys,%i,32) != $null) {
    %k = $gettok($ns.ted.evkeys,%i,32)
    %ev = $+(%ev,$iif(%ev,$chr(44)),%k,:,$ns.ted.get($+(e,%i)))
    inc %i
  }
  writeini -n $qt($ns.theme.ufile) %id name %name
  writeini -n $qt($ns.theme.ufile) %id desc $iif($ns.ted.get(desc) != $null,$ns.ted.get(desc),My theme)
  writeini -n $qt($ns.theme.ufile) %id mode $ns.ted.get(mode)
  writeini -n $qt($ns.theme.ufile) %id colors %cols
  writeini -n $qt($ns.theme.ufile) %id accent $ns.ted.get(accent)
  writeini -n $qt($ns.theme.ufile) %id acc1 $ns.ted.get(acc1)
  writeini -n $qt($ns.theme.ufile) %id acc2 $ns.ted.get(acc2)
  writeini -n $qt($ns.theme.ufile) %id ev %ev
  writeini -n $qt($ns.theme.ufile) %id nickcols $ns.ted.get(nickcols)
  %order = $ns.theme.uids
  if (!$istok(%order,%id,32)) writeini -n $qt($ns.theme.ufile) themes order $replace($ns.trim(%order %id),$chr(32),$chr(44))
  return %id
}
alias ns.ted.delete {
  var %id = $1
  if ($left(%id,2) != u_) return
  var %rest = $ns.trim($remtok($ns.theme.uids,%id,1,32))
  remini $qt($ns.theme.ufile) %id
  if (%rest == $null) remini $qt($ns.theme.ufile) themes order
  else writeini -n $qt($ns.theme.ufile) themes order $replace(%rest,$chr(32),$chr(44))
  if ($ns.theme.current == %id) ns.theme.apply neonnight
}

; ---------------------------------------------------------------- pictures (drawn into a hidden picture window)
; a sample of chat in the working copy's colours.  mIRC limits a picture window to the room available in its own
; window, so the real size is read back and everything is laid out relative to it.
alias ns.ted.preview {
  var %w = 600, %h = 170, %f = $ns.data(tmp\ted_preview.bmp), %lh = 15, %y = 6, %r = 1, %x, %tw, %lw, %bg, %fg, %col, %txt, %nick
  .mkdir $qt($ns.data(tmp))
  if ($window(@nstedpv)) window -c @nstedpv
  ; (a window's frame takes 16 x 39 pixels off the drawing area, so ask for that much more)
  window -hp @nstedpv 0 0 $calc(%w + 16) $calc(%h + 39)
  if ($window(@nstedpv).dw > 100) %w = $window(@nstedpv).dw
  if ($window(@nstedpv).dh > 60) %h = $window(@nstedpv).dh
  %bg = $ns.pal($ns.ted.get(c1))
  %fg = $ns.pal($ns.ted.get(c12))
  %tw = $int($calc(%w * 0.13))
  %lw = $int($calc(%w * 0.13))
  drawrect -rf @nstedpv %bg 1 0 0 %w %h
  ; treebar strip on the left, nick list on the right
  drawrect -rf @nstedpv $ns.pal($ns.ted.get(c29)) 1 0 0 %tw %h
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c30)) Tahoma 10 5 6 Status
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c30)) Tahoma 10 5 21 #neon
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c30)) Tahoma 10 5 36 Kira
  drawrect -rf @nstedpv $ns.pal($ns.ted.get(c24)) 1 $calc(%w - %lw) 0 %lw %h
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 6 @TestNick
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 21 $chr(37) $+ Half
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 36 +Zed
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 51 Nova
  %x = $calc(%tw + 8)
  var %lim = $calc(%h - 40)
  while (%r <= 10) && (%y < %lim) {
    %nick = $null
    if (%r == 1) { %col = $ns.pal($ns.ted.get(c8)) | %txt = -> Nova (nova@host.example) has joined #neon }
    elseif (%r == 2) { %nick = Nova | %col = %fg | %txt = hey everyone, nice to be here }
    elseif (%r == 3) { %nick = TestNick | %col = $ns.pal($ns.ted.get(c16)) | %txt = thanks, glad to be here }
    elseif (%r == 4) { %col = $ns.pal($ns.ted.get(c4)) | %txt = <Kira> TestNick: your build is ready }
    elseif (%r == 5) { %col = $ns.pal($ns.ted.get(c2)) | %txt = * Nova raises a glass }
    elseif (%r == 6) { %col = $ns.pal($ns.ted.get(c10)) | %txt = * Owner sets mode +o Nova }
    elseif (%r == 7) { %col = $ns.pal($ns.ted.get(c19)) | %txt = * Nova changed the topic to: Welcome }
    elseif (%r == 8) { %col = $ns.pal($ns.ted.get(c9)) | %txt = * Kira was kicked by Owner (behave) }
    elseif (%r == 9) { %col = $ns.pal($ns.ted.get(c13)) | %txt = -Admin:#neon- maintenance at midnight }
    else { %col = $ns.pal($ns.ted.get(c26)) | %txt = (gray text: timestamps and quiet bits) }
    drawtext -r @nstedpv $ns.pal($ns.ted.get(c26)) Consolas 10 %x %y 12:0 $+ %r
    if (%nick) {
      drawtext -r @nstedpv $ns.pal($ns.nickcol(%nick)) Consolas 10 $calc(%x + 40) %y < $+ %nick $+ >
      drawtext -r @nstedpv %col Consolas 10 $calc(%x + 40 + ($len(%nick) + 3) * 7) %y %txt
    }
    else drawtext -r @nstedpv %col Consolas 10 $calc(%x + 40) %y %txt
    inc %y %lh
    inc %r
  }
  ; edit box along the bottom
  drawrect -rf @nstedpv $ns.pal($ns.ted.get(c22)) 1 %tw $calc(%h - 20) $calc(%w - %tw - %lw) 20
  drawtext -r @nstedpv $ns.pal($ns.ted.get(c23)) Consolas 10 $calc(%tw + 8) $calc(%h - 16) /neon themeedit_
  drawsave @nstedpv %f
  window -c @nstedpv
  return %f
}
; all 99 palette colours with their numbers
alias ns.ted.palette {
  var %w = 600, %h = 126, %cols = 11, %i = 0, %x, %y, %cw, %rh, %f = $ns.data(tmp\ted_palette.bmp), %sel = $1
  .mkdir $qt($ns.data(tmp))
  if ($window(@nstedpal)) window -c @nstedpal
  window -hp @nstedpal 0 0 $calc(%w + 16) $calc(%h + 39)
  if ($window(@nstedpal).dw > 100) %w = $window(@nstedpal).dw
  if ($window(@nstedpal).dh > 60) %h = $window(@nstedpal).dh
  %cw = $calc(%w / %cols)
  %rh = $calc(%h / 9)
  drawrect -rf @nstedpal $rgb(30,31,44) 1 0 0 %w %h
  while (%i <= 98) {
    %x = $int($calc($int($calc(%i % %cols)) * %cw + 1))
    %y = $int($calc($int($calc(%i / %cols)) * %rh + 1))
    drawrect -rf @nstedpal $ns.pal(%i) 1 %x %y $int($calc(%cw - 2)) $int($calc(%rh - 2))
    drawtext -r @nstedpal $iif($calc($ns.r8($ns.pal(%i)) + $ns.g8($ns.pal(%i)) + $ns.b8($ns.pal(%i))) > 380,$rgb(10,10,20),$rgb(240,240,250)) Tahoma 9 $calc(%x + 3) $calc(%y + 2) %i
    if (%i == %sel) drawrect -r @nstedpal $rgb(255,255,255) 2 %x %y $int($calc(%cw - 2)) $int($calc(%rh - 2))
    inc %i
  }
  drawsave @nstedpal %f
  window -c @nstedpal
  return %f
}
; a small thumbnail for the gallery (a user theme has no shipped picture): the same sample, smaller
alias ns.ted.thumb {
  ns.ted.load $1
  return $ns.ted.preview
}

; ---------------------------------------------------------------- export as a classic .mts
; ns.ted.exportmts <file>   - Colors / RGBColors / BaseColors from the working copy, templates from the shipped example
alias ns.ted.exportmts {
  var %out = $1, %tpl = $ns.data(mts\irssi_night.mts), %i = 1, %n = $lines(%tpl), %l, %cols, %rgb, %k, %c, %base
  if ($exists(%out)) .remove $qt(%out)
  %k = 1
  while (%k <= 26) {
    %cols = $+(%cols,$iif(%cols,$chr(44)),$ns.ted.get($+(c,%k)))
    inc %k
  }
  %k = 0
  while (%k < 16) {
    %c = $color(%k)
    %rgb = $+(%rgb,$iif(%rgb,$chr(32)),$ns.r8(%c),$chr(44),$ns.g8(%c),$chr(44),$ns.b8(%c))
    inc %k
  }
  %base = $+($ns.ted.get(c12),$chr(44),$ns.ted.get(accent),$chr(44),$ns.ted.get(c4),$chr(44),$ns.ted.get(c26))
  write $qt(%out) [mts]
  write $qt(%out) MTSVersion 1.10
  write $qt(%out) Name $ns.ted.get(name)
  write $qt(%out) Author NeonScript theme editor
  write $qt(%out) Description $iif($ns.ted.get(desc) != $null,$ns.ted.get(desc),A theme made with the NeonScript theme editor.)
  write $qt(%out) Colors %cols
  write $qt(%out) RGBColors %rgb
  write $qt(%out) BaseColors %base
  write $qt(%out) FontDefault Consolas, 11
  write $qt(%out) Prefix -!-
  while (%i <= %n) {
    %l = $read(%tpl,n,%i)
    inc %i
    if ($left(%l,1) == $chr(59)) || ($regex(ns.tk,%l,/^(Textchan|ActionChan|NoticeChan|TextQuery|ActionQuery|Join|JoinSelf|Part|Quit|Kick|KickSelf|Nick|NickSelf|Mode|Topic|Invite|RAW\.)/i)) write $qt(%out) %l
  }
  return %out
}

; ---------------------------------------------------------------- the dialog
alias neon.themeedit {
  set -u120 %ns.ted.start $iif($1 != $null,$1,$ns.theme.current)
  ns.dlg ns_ted ns_ted
}
dialog ns_ted {
  title "Theme Editor"
  size -1 -1 410 282
  option dbu
  icon 1, 0 0 410 30, $mircexe, 0, noborder
  text "Start from:", 2, 6 37 36 9
  combo 3, 44 35 120 100, drop
  text "Name:", 4, 172 37 24 9
  edit "", 5, 198 35 110 11, autohs
  text "Mode:", 6, 314 37 22 9
  combo 7, 338 35 60 60, drop
  list 10, 6 50 124 168, size vsbar
  text "Colour (0-98):", 11, 138 52 42 9
  edit "", 12, 182 50 26 11, autohs limit 2
  button "<", 13, 212 49 14 12
  button ">", 14, 228 49 14 12
  text "", 15, 246 52 60 9
  text "Accent (NeonScript highlights):", 17, 138 66 100 9
  edit "", 18, 240 64 26 11, autohs limit 2
  text "", 19, 270 66 60 9
  icon 30, 138 80 266 80, $mircexe, 0, noborder
  icon 31, 138 164 266 54, $mircexe, 0, noborder
  text "Pick a line on the left, then type a number or use < and >.  The picture shows what chat will look like; the grid below it is every colour mIRC has.", 32, 6 222 398 18
  button "Save", 40, 6 244 50 13
  button "Apply", 41, 60 244 50 13
  button "Delete", 42, 114 244 50 13
  button "Export .mts...", 43, 168 244 60 13
  text "", 44, 6 262 300 9
  button "Close", 45, 356 262 48 13, ok cancel
}
on *:DIALOG:ns_ted:init:*:{
  did -g ns_ted 1 $ns.asset(header_tedit.png)
  var %i = 1, %id, %all = $ns.theme.ids $ns.theme.uids, %sel = 1
  while ($gettok(%all,%i,32) != $null) {
    %id = $v1
    inc %i
    did -a ns_ted 3 $iif($left(%id,2) == u_,$+(*,$chr(32)),$null) $+ $ns.theme.name(%id)
    if (%id == %ns.ted.start) %sel = $calc(%i - 1)
  }
  did -a ns_ted 7 dark
  did -a ns_ted 7 light
  did -c ns_ted 3 %sel
  edload $gettok(%all,%sel,32)
}
alias -l edall return $ns.theme.ids $ns.theme.uids
alias -l edload {
  ns.ted.load $1
  var %i = 1, %n = $ns.ted.count
  did -ra ns_ted 5 $ns.ted.get(name)
  did -c ns_ted 7 $iif($ns.ted.get(mode) == light,2,1)
  did -r ns_ted 10
  while (%i <= %n) {
    did -a ns_ted 10 $edrow(%i)
    inc %i
  }
  did -c ns_ted 10 1
  edpick 1
  did -ra ns_ted 18 $ns.ted.get(accent)
  edredraw
}
alias -l edrow return $+($ns.ted.itemname($1),$chr(32),$chr(32),$chr(8212),$chr(32),$chr(32),$ns.ted.val($1),$chr(32),$chr(40),$ns.ted.hex($ns.ted.val($1)),$chr(41))
alias -l edpick {
  var %n = $1
  if (!%n) return
  did -ra ns_ted 12 $ns.ted.val(%n)
  did -ra ns_ted 15 $ns.ted.hex($ns.ted.val(%n))
}
alias -l edredraw {
  did -g ns_ted 30 $ns.ted.preview
  did -g ns_ted 31 $ns.ted.palette($ns.ted.val($did(ns_ted,10).sel))
  did -ra ns_ted 19 $ns.ted.hex($ns.ted.get(accent))
}
alias -l edset {
  var %sel = $did(ns_ted,10).sel, %v = $1
  if (!%sel) return
  if (%v !isnum) || (%v < 0) || (%v > 98) return
  ns.ted.setval %sel %v
  did -o ns_ted 10 %sel $edrow(%sel)
  did -ra ns_ted 15 $ns.ted.hex(%v)
  edredraw
}
on *:DIALOG:ns_ted:sclick:3:{
  var %id = $gettok($edall,$did(ns_ted,3).sel,32)
  if (%id) edload %id
}
on *:DIALOG:ns_ted:sclick:10:{ edpick $did(ns_ted,10).sel | edredraw }
on *:DIALOG:ns_ted:edit:12:{ if ($did(ns_ted,12).text isnum) edset $did(ns_ted,12).text }
on *:DIALOG:ns_ted:sclick:13:{
  var %v = $calc($did(ns_ted,12).text - 1)
  if (%v < 0) %v = 98
  did -ra ns_ted 12 %v
  edset %v
}
on *:DIALOG:ns_ted:sclick:14:{
  var %v = $calc($did(ns_ted,12).text + 1)
  if (%v > 98) %v = 0
  did -ra ns_ted 12 %v
  edset %v
}
on *:DIALOG:ns_ted:edit:18:{
  var %v = $did(ns_ted,18).text
  if (%v isnum) && (%v >= 0) && (%v <= 98) {
    hadd -m ns.ted accent %v
    did -ra ns_ted 19 $ns.ted.hex(%v)
  }
}
on *:DIALOG:ns_ted:edit:5:{ hadd -m ns.ted name $did(ns_ted,5).text }
on *:DIALOG:ns_ted:sclick:7:{ hadd -m ns.ted mode $did(ns_ted,7).text }
; accents (the two hex colours used for gradients): the nearest palette colours' hex values
alias -l edaccents {
  var %a = $ns.ted.get(accent)
  hadd -m ns.ted acc1 $ns.ted.hex(%a)
  hadd -m ns.ted acc2 $ns.ted.hex($ns.ted.get(c26))
}
on *:DIALOG:ns_ted:sclick:40:{
  edaccents
  hadd -m ns.ted name $did(ns_ted,5).text
  var %id = $ns.ted.save
  if (!%id) {
    did -ra ns_ted 44 Give the theme a name first.
    return
  }
  did -ra ns_ted 44 Saved as %id $+ . It is in the gallery now.
  did -r ns_ted 3
  var %i = 1, %all = $edall, %n
  while ($gettok(%all,%i,32) != $null) {
    did -a ns_ted 3 $iif($left($gettok(%all,%i,32),2) == u_,$+(*,$chr(32)),$null) $+ $ns.theme.name($gettok(%all,%i,32))
    inc %i
  }
  did -c ns_ted 3 $findtok(%all,%id,1,32)
  hadd -m ns.ted base %id
  if ($dialog(ns_theme)) signal -n ns.mtschanged
}
on *:DIALOG:ns_ted:sclick:41:{
  edaccents
  hadd -m ns.ted name $did(ns_ted,5).text
  var %id = $ns.ted.save
  if (!%id) {
    did -ra ns_ted 44 Give the theme a name first.
    return
  }
  ns.theme.apply %id
  did -ra ns_ted 44 Applied $ns.ted.get(name) $+ .
}
on *:DIALOG:ns_ted:sclick:42:{
  var %id = $ns.ted.get(base)
  if ($left(%id,2) != u_) {
    did -ra ns_ted 44 Only your own themes (marked *) can be deleted.
    return
  }
  ns.ted.delete %id
  did -ra ns_ted 44 Deleted.
  dialog -x ns_ted
}
on *:DIALOG:ns_ted:sclick:43:{ ns.later ns.ted.exportask }
alias ns.ted.exportask {
  if (!$dialog(ns_ted)) return
  var %slug = $regsubex($lower($ns.ted.get(name)),/[^a-z0-9]/g,), %f = $sfile($+($ns.mts.dir,%slug,.mts),Export as an MTS theme,Save)
  if (!%f) return
  ns.ted.exportmts %f
  did -ra ns_ted 44 Exported $nopath(%f) - it is in the MTS list too.
  if ($isalias(ns.mts.changed)) ns.mts.changed
  signal -n ns.mtschanged
}
