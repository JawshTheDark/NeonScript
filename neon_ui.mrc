; ============================================================================
;  NeonScript 2026  ::  native UI helper (optional)       /neon ui ...
;  Uses neonui.dll (source in native\, 32-bit, MIT) for what plain mIRC script cannot do:
;    * rank icons and coloured initials ("avatars") in the nick list
;    * an unread-mentions badge on mIRC's taskbar button
;  The DLL is only called when you switched it on AND its SHA-256 matches data\neonui.sha256.
;  Without it (or with it off) NeonScript works exactly as before.
; ============================================================================

alias ns.ui.dll return $+($scriptdir,neonui.dll)
alias ns.ui.on return $ns.flag(ui,on,0)

; is the helper present, and is it the exact build we published?  (cached for the session)
alias ns.ui.ready {
  if (!$exists($ns.ui.dll)) return 0
  if ($hget(ns.uis,ok) != $null) return $hget(ns.uis,ok)
  var %want = $read($ns.data(neonui.sha256),n,1), %have = $sha256($ns.ui.dll,2), %ok = 0
  if (%want != $null) && (%have == %want) %ok = 1
  hadd -m ns.uis ok %ok
  if (!%ok) ns.log ui neonui.dll does not match data\neonui.sha256 - not used
  return %ok
}
; the helper is wanted and usable
alias ns.ui.active return $iif($ns.ui.on && $ns.ui.ready,1,0)
; one call into the DLL:  $ns.ui.cmd(verb<TAB>arg<TAB>arg)
alias ns.ui.cmd return $dll($qt($ns.ui.dll),Cmd,$1-)
alias ns.ui.tab return $chr(9)

; settings -> DLL
alias ns.ui.apply {
  if (!$ns.ui.active) return
  var %t = $ns.ui.tab, %r = $ns.flag(ui,nlrank,1), %a = $ns.flag(ui,nlavatar,1)
  var %res = $ns.ui.cmd($+(nlcfg,%t,rank=,%r,%t,avatar=,%a,%t,auto=,$ns.flag(ui,nladapt,0),%t,size=,$ns.get(ui,nlsize,auto),%t,min=,$ns.get(ui,nlmin,110),%t,max=,$ns.get(ui,nlmax,240),%t,fixed=,$ns.get(ui,nlfixed,150)))
  if (%res != ok) ns.log ui nlcfg: %res
  ns.ui.badge
  ns.ui.chrome
  ns.tbc.push
  ns.ui.tick
}
; hook channel windows that appeared since the last look, refresh the badge
alias ns.ui.tick {
  if (!$ns.ui.active) return
  var %n = $ns.ui.cmd($+(nlscan))
  ns.tbc.tick
}
; the number on the taskbar button
alias ns.ui.badge {
  if (!$ns.ui.active) return
  var %n = $iif($ns.flag(ui,badge,1),$ns.mi.unread,0)
  if (%n == $hget(ns.uis,badge)) return
  hadd -m ns.uis badge %n
  var %t = $ns.ui.tab
  var %res = $ns.ui.cmd($+(badge,%t,%n,%t,%n,$chr(32),unread mention,$iif(%n != 1,s)))
  if (%res != ok) ns.log ui badge: %res
}
; ---- window frame colours (title bar, border, scroll bars) taken from the theme
alias ns.ui.hex {
  var %h = $remove($1,$chr(35))
  return $iif($regex(ns.hx,%h,/^[0-9a-fA-F]{6}$/),%h,$2)
}
alias ns.ui.chrome {
  if (!$ns.ui.active) return
  var %t = $ns.ui.tab, %d = $ns.ui.isdark, %on = $ns.flag(ui,chrome,1), %cap, %txt, %bd
  %cap = $iif(%d,181824,ffffff)
  %txt = $iif(%d,e8e8f2,1d1d28)
  %bd = $ns.ui.hex($ns.get(theme,acc1,ff2e88),ff2e88)
  var %r = $ns.ui.cmd($+(chrome,%t,on=,%on,%t,dark=,%d,%t,caption=,%cap,%t,text=,%txt,%t,border=,%bd,%t,scroll=,%d))
  if (%r != ok) ns.log ui chrome: %r
}

; ---- unread and mention counts on the tree bar entries
; ns.tbc: "<cid>.<window>" = "<unread messages> <mentions>"; the numbers are drawn by the DLL next to the entry
alias ns.tbc.on return $iif($ns.ui.active && $ns.flag(ui,treebadge,1),1,0)
alias ns.tbc.inc {
  ; ns.tbc.inc <window> <1|2>   (1 = a message, 2 = a mention)
  if (!$ns.tbc.on) return
  var %k = $+($cid,.,$1), %v = $hget(ns.tbc,%k), %m = $gettok(%v,1,32), %h = $gettok(%v,2,32)
  if (%m == $null) %m = 0
  if (%h == $null) %h = 0
  if ($2 == 1) inc %m
  else inc %h
  hadd -m ns.tbc %k %m %h
  .timer.nstbc -o 1 1 ns.tbc.push
}
alias ns.tbc.add {
  if ($nick == $me) return
  if ($ns.ur.seen($1)) return
  ns.tbc.inc $1 1
}
alias ns.tbc.ment ns.tbc.inc $1 2
on *:TEXT:*:#:{ ns.tbc.add $chan }
on *:ACTION:*:#:{ ns.tbc.add $chan }
on *:TEXT:*:?:{ ns.tbc.add $nick }
on *:ACTION:*:?:{ ns.tbc.add $nick }
; looking at a window clears its numbers
alias ns.tbc.clear {
  var %k = $+($cid,.,$1)
  if ($hget(ns.tbc,%k) != $null) {
    hdel ns.tbc %k
    .timer.nstbc -o 1 1 ns.tbc.push
  }
}
on *:ACTIVE:*:{ if ($appactive) ns.tbc.clear $active }
alias ns.tbc.tick { if ($appactive) && ($hget(ns.tbc)) ns.tbc.clear $active }
; 1 when mIRC itself shows this window in its highlight colour (its own highlight rules matched, not only NeonScript's mention words)
alias ns.tbc.sb hadd -m ns.tbhl $+($cid,.,$1) $iif($window($1).sbcolor == highlight,1,0)
alias ns.tbc.push {
  var %t = $ns.ui.tab, %on = $ns.tbc.on, %n, %i = 1, %k, %cid, %win, %v, %j, %lab, %list, %c = 0
  if (!$ns.ui.active) return
  if (%on) && ($hget(ns.tbc)) {
    %n = $hget(ns.tbc,0).item
    while (%i <= %n) && (%c < 50) {
      %k = $hget(ns.tbc,%i).item
      inc %i
      %cid = $gettok(%k,1,46)
      %win = $gettok(%k,2-,46)
      %v = $hget(ns.tbc,%k)
      %lab = $null
      %j = 1
      while (%j <= $scon(0)) {
        if ($scon(%j).cid == %cid) %lab = $+($iif($scon(%j).network,$scon(%j).network,$scon(%j).server),$chr(32),$scon(%j).me)
        inc %j
      }
      if (%lab == $null) continue
      scid %cid ns.tbc.sb %win
      %list = $+(%list,%t,%lab,$chr(31),%win,$chr(31),$gettok(%v,1,32),$chr(31),$gettok(%v,2,32),$chr(31),$hget(ns.tbhl,$+(%cid,.,%win)))
      inc %c
    }
  }
  var %r = $ns.ui.cmd($+(treebadge,%t,%on,%t,4F6BED,%t,E5484D,%list))
  if (%r != ok) ns.log ui treebadge: %r
}
; switch everything the DLL did off again (before it is unloaded, or when the helper is turned off)
alias ns.ui.stop {
  .timer.nsui off
  .timer.nsuipoll off
  if ($hget(ns.uis,wv) == 1) var %x = $ns.ui.cmd(wvcloseall)
  if ($hget(ns.uis,ok) == 1) {
    %x = $ns.ui.cmd($+(treebadge,$chr(9),0))
    %x = $ns.ui.cmd($+(chrome,$chr(9),on=0))
  }
  if ($hget(ns.uis)) hdel ns.uis panels
  if ($exists($ns.ui.dll)) && ($hget(ns.uis,ok) == 1) {
    var %r = $ns.ui.cmd(nlunhook)
    var %t = $ns.ui.tab
    %r = $ns.ui.cmd($+(badge,%t,0))
  }
  if ($hget(ns.uis)) hdel ns.uis badge
}
alias ns.ui.start {
  .timer.nsui off
  if (!$ns.ui.active) return
  ns.ui.apply
  .timer.nsui 0 2 ns.ui.tick
}
on *:SIGNAL:ns.boot:{ .timer.nsuiboot -o 1 3 ns.ui.refresh | .timer.nsuiclean -o 1 20 ns.ui.cleanup }
on *:SIGNAL:ns.opts:{ .timer.nsuiboot -o 1 1 ns.ui.refresh }
on *:SIGNAL:ns.uninstall:{ ns.ui.stop | if ($exists($ns.ui.dll)) .dll -u $qt($ns.ui.dll) }
on *:EXIT:{ if ($hget(ns.uis,ok) == 1) ns.ui.stop }
; let go of neonui.dll (it can then be replaced) and forget that it was verified
alias ns.ui.unload {
  if ($exists($ns.ui.dll)) .dll -u $qt($ns.ui.dll)
  if ($hget(ns.uis)) hdel -w ns.uis ok
  if ($hget(ns.uis)) hdel -w ns.uis wv*
  if ($hget(ns.uis)) hdel -w ns.uis badge
}
; leftovers of a replaced neonui.dll (renamed while it was loaded)
alias ns.ui.cleanup {
  var %n = $findfile($scriptdir,neonui.*.old,0,0), %i = 1
  while (%i <= %n) {
    .remove $qt($findfile($scriptdir,neonui.*.old,%i,0))
    inc %i
  }
}
alias ns.ui.refresh {
  if ($ns.ui.active) ns.ui.start
  else ns.ui.stop
}

; text for the Control Panel page
alias ns.ui.statustext {
  if (!$exists($ns.ui.dll)) return neonui.dll is not in the NeonScript folder - everything works without it.
  if (!$ns.ui.ready) return neonui.dll is here but does not match the published SHA-256 - it will not be used.
  if (!$ns.ui.on) return neonui.dll is verified (SHA-256 matches) and switched off.
  return neonui.dll is verified and on: $ns.ui.cmd(ver) $+ .
}

; /neon ui [status|on|off|test]
alias neon.ui {
  var %c = $lower($1), %v
  if (%c == on) {
    if (!$exists($ns.ui.dll)) { ns.err neonui.dll is not in the NeonScript folder. | return }
    if (!$ns.ui.ready) { ns.err neonui.dll is different from the published build (SHA-256 mismatch) - not used. | return }
    ns.set ui on 1
    ns.ui.refresh
    ns.say native UI helper on.
    return
  }
  if (%c == off) {
    ns.set ui on 0
    ns.ui.refresh
    ns.ui.unload
    ns.say native UI helper off (neonui.dll unloaded).
    return
  }
  ns.say native UI helper: $iif($ns.ui.on,$+($ns.ec(join),ON,$ns.o),$+($ns.ec(kick),off,$ns.o))
  ns.say file neonui.dll: $iif(!$exists($ns.ui.dll),not installed (optional),$iif($ns.ui.ready,verified (SHA-256 matches),does NOT match the published hash - not used))
  if ($ns.ui.ready) {
    %v = $ns.ui.cmd(ver)
    ns.say version: %v $+ , nick list icons $iif($ns.flag(ui,nlrank,1),on,off) $+ , avatars $iif($ns.flag(ui,nlavatar,1),on,off) $+ , taskbar badge $iif($ns.flag(ui,badge,1),on,off)
  }
}

; ============================================================================
;  HTML panels (WebView2): small windows of their own, pages from data\ui
;    ns.ui.panel.open <name> <page.html> <width> <height> <title...>      ns.ui.panel.post <name> <text>
;    ns.ui.panel.close <name>
;  What a page sends back arrives as  ns.ui.h.<name> <kind> <text>  (kind: msg link loaded loadfailed error closed),
;  and is always untrusted text.  Needs the WebView2 runtime that ships with Windows 11 / Edge.
; ============================================================================
alias ns.ui.wv.ready {
  if (!$ns.ui.active) return 0
  if ($hget(ns.uis,wv) == $null) {
    .mkdir $qt($ns.data(ui))
    .mkdir $qt($ns.data(ui\profile))
    var %t = $ns.ui.tab, %r = $ns.ui.cmd($+(wvinit,%t,$ns.data(ui\profile),%t,$ns.data(ui)))
    hadd -m ns.uis wv $iif($left(%r,2) == ok,1,0)
    hadd -m ns.uis wvinfo %r
    if ($left(%r,2) != ok) ns.log ui wvinit: %r
  }
  return $hget(ns.uis,wv)
}
alias ns.ui.panel.open {
  var %name = $1, %page = $2, %w = $3, %h = $4, %title = $5-, %t = $ns.ui.tab, %fl, %bg
  if (!$ns.ui.wv.ready) { ns.err HTML panels need the native helper switched on and the WebView2 runtime ( $+ $hget(ns.uis,wvinfo) $+ ). | return 0 }
  %bg = $ns.ui.bg
  %fl = $+($iif($ns.ui.isdark,dark),$chr(44),bg=,%bg)
  var %r = $ns.ui.cmd($+(wvopen,%t,%name,%t,%page,%t,%w,%t,%h,%t,%title,%t,%fl))
  if (%r != ok) { ns.err could not open the panel: %r | return 0 }
  hinc -m ns.uis panels
  .timer.nsuipoll -m 0 150 ns.ui.poll
  return 1
}
alias ns.ui.panel.post {
  var %t = $ns.ui.tab
  if ($ns.ui.wv.ready) var %r = $ns.ui.cmd($+(wvpost,%t,$1,%t,$2-))
}
alias ns.ui.panel.close {
  var %t = $ns.ui.tab
  if ($ns.ui.wv.ready) var %r = $ns.ui.cmd($+(wvclose,%t,$1))
}
; the theme's background as RRGGBB, and whether it is dark
alias ns.ui.isdark return $iif($ns.get(theme,mode,dark) != light,1,0)
alias ns.ui.bg return $iif($ns.ui.isdark,101018,f6f4ee)
; the colours a panel should use, as the JSON message common.js understands
alias ns.ui.themejson {
  var %a1 = $ns.get(theme,acc1,#ff2e88), %a2 = $ns.get(theme,acc2,#2ee6ff), %t
  if (!$regex(ns.tj,%a1,/^#[0-9a-fA-F]{6}$/)) %a1 = #ff2e88
  if (!$regex(ns.tj,%a2,/^#[0-9a-fA-F]{6}$/)) %a2 = #2ee6ff
  if ($ns.ui.isdark) %t = bg:#101018 panel:#181824 fg:#e8e8f2 dim:#8a8aa4 border:#2a2a3c hover:#24243a
  else %t = bg:#f6f4ee panel:#ffffff fg:#1d1d28 dim:#6a6a7a border:#d6d3c8 hover:#ebe8dd
  %t = %t accent: $+ %a1 accent2: $+ %a2
  var %i = 1, %j, %kv
  while ($gettok(%t,%i,32) != $null) {
    %kv = $gettok(%t,%i,32)
    %j = $+(%j,$iif(%j != $null,$chr(44)),$chr(34),$gettok(%kv,1,58),$chr(34),:,$chr(34),$gettok(%kv,2,58),$chr(34))
    inc %i
  }
  var %q = $chr(34), %o = $chr(123), %c = $chr(125), %m = $chr(44)
  return $+(%o,%q,type,%q,:,%q,theme,%q,%m,%q,vars,%q,:,%o,%j,%c,%c)
}
; collect what the panels said
alias ns.ui.poll {
  var %i = 0, %e, %p, %k, %x
  if (!$ns.ui.active) { .timer.nsuipoll off | return }
  while (%i < 20) {
    %e = $ns.ui.cmd(wvpoll)
    if (%e == $null) break
    inc %i
    %p = $gettok(%e,1,9)
    %k = $gettok(%e,2,9)
    %x = $gettok(%e,3-,9)
    if (%k == closed) && ($hget(ns.uis,panels) > 0) hdec ns.uis panels
    if (%k == loaded) ns.ui.panel.post %p $ns.ui.themejson
    .signal -n ns.ui.event %p %k %x
    if ($isalias($+(ns.ui.h.,%p))) $+(ns.ui.h.,%p) %k %x
    elseif (%k == error) ns.log ui panel %p error: %x
  }
  if (!$hget(ns.uis,panels)) .timer.nsuipoll off
}

; ---- the panels NeonScript ships ------------------------------------------------------------------------------------------
; /emoji  - the emoji picker (falls back to the Symbol map when the native helper is off)
alias emoji {
  if (!$ns.ui.wv.ready) {
    ns.say the emoji picker needs the native helper (Control Panel > Native UI) - opening the symbol map instead.
    neon chars
    return
  }
  set -u86400 %ns.ui.emoji.win $active
  set -u86400 %ns.ui.emoji.cid $cid
  var %r = $ns.ui.panel.open(emoji,emoji.html,440,430,Emoji)
}
alias ns.ui.h.emoji {
  if ($1 != msg) return
  var %m = $2-
  if (%m == close) { ns.ui.panel.close emoji | return }
  if ($gettok(%m,1,32) == insert) ns.ui.emoji.insert $gettok(%m,2-,32)
}
alias ns.ui.emoji.insert {
  var %ch = $1-, %cid = %ns.ui.emoji.cid
  if (%ch == $null) || ($len(%ch) > 8) return
  if ($regex(ns.eu,%ch,/[\x00-\x7F]/)) return
  if (%cid) scid %cid ns.ui.emoji.put %ns.ui.emoji.win %ch
  else ns.ui.emoji.put %ns.ui.emoji.win %ch
}
; put the emoji in the text box of the window the picker was opened from, at the cursor
alias ns.ui.emoji.put {
  var %w = $1, %ch = $2, %t, %s, %e, %n
  if (!$window(%w)) %w = $active
  %t = $editbox(%w)
  %s = $editbox(%w).selstart
  %e = $editbox(%w).selend
  if (%s !isnum) || (%e !isnum) || (%s < 1) { %s = $calc($len(%t) + 1) | %e = %s }
  %n = $+($left(%t,$calc(%s - 1)),%ch,$mid(%t,%e))
  var %pos = $calc(%s + $len(%ch))
  editbox $+(-a,b,%pos,e,%pos) %n
  window -a %w
}
; a card in a panel:  ns.ui.card <title> <text with chr(10) line breaks>      (returns 1 when the panel took it)
alias ns.ui.card {
  if (!$ns.ui.wv.ready) return 0
  var %q = $chr(34), %o = $chr(123), %c = $chr(125), %m = $chr(44), %title = $ns.json.enc($1), %text = $ns.json.enc($left($2-,2800))
  var %j = $+(%o,%q,type,%q,:,%q,card,%q,%m,%q,title,%q,:,%q,%title,%q,%m,%q,text,%q,:,%q,%text,%q,%c)
  if (!$ns.ui.panel.open(card,card.html,580,480,NeonScript)) return 0
  ns.ui.panel.post card %j
  return 1
}
alias ns.ui.h.card {
  if ($1 == msg) && ($2- == close) ns.ui.panel.close card
  elseif ($1 == link) ns.ui.link $2-
}
; a link from a panel: only plain http(s), always asked first
alias ns.ui.link {
  var %u = $1-
  if ($len(%u) > 500) || (!$regex(ns.ul,%u,/^https?:\/\/[A-Za-z0-9._~:\/?\x23\x5B\x5D\x40!\x24\x26\x27\x28\x29\x2A\x2B\x3B\x3D\x25-]+$/)) return
  hadd -m ns.uis link %u
  ns.later ns.ui.link.ask
}
alias ns.ui.link.ask {
  var %u = $hget(ns.uis,link)
  if (%u == $null) return
  if ($input(Open this link in your browser? $+ $crlf $+ $crlf $+ $left(%u,200),yq,Open link)) run %u
}
