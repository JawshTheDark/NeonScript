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
  var %res = $ns.ui.cmd($+(nlcfg,%t,rank=,%r,%t,avatar=,%a))
  if (%res != ok) ns.log ui nlcfg: %res
  ns.ui.badge
  ns.ui.tick
}
; hook channel windows that appeared since the last look, refresh the badge
alias ns.ui.tick {
  if (!$ns.ui.active) return
  if ($ns.flag(ui,nlrank,1)) || ($ns.flag(ui,nlavatar,1)) var %n = $ns.ui.cmd($+(nlscan))
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
; switch everything the DLL did off again (before it is unloaded, or when the helper is turned off)
alias ns.ui.stop {
  .timer.nsui off
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
on *:SIGNAL:ns.boot:{ .timer.nsuiboot -o 1 3 ns.ui.refresh }
on *:SIGNAL:ns.opts:{ .timer.nsuiboot -o 1 1 ns.ui.refresh }
on *:SIGNAL:ns.uninstall:{ ns.ui.stop | if ($exists($ns.ui.dll)) .dll -u $qt($ns.ui.dll) }
on *:EXIT:{ if ($hget(ns.uis,ok) == 1) ns.ui.stop }
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
    ns.say native UI helper off.
    return
  }
  ns.say native UI helper: $iif($ns.ui.on,$+($ns.ec(join),ON,$ns.o),$+($ns.ec(kick),off,$ns.o))
  ns.say file neonui.dll: $iif(!$exists($ns.ui.dll),not installed (optional),$iif($ns.ui.ready,verified (SHA-256 matches),does NOT match the published hash - not used))
  if ($ns.ui.ready) {
    %v = $ns.ui.cmd(ver)
    ns.say version: %v $+ , nick list icons $iif($ns.flag(ui,nlrank,1),on,off) $+ , avatars $iif($ns.flag(ui,nlavatar,1),on,off) $+ , taskbar badge $iif($ns.flag(ui,badge,1),on,off)
  }
}
